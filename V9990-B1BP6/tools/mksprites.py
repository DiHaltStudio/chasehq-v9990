#!/usr/bin/env python3
# Prepara los sprites de los niveles para el port:
#   build/common.bin      hoja comun a todos los niveles (256 px de ancho, 8 bpp)
#   build/levelN.bin      hoja del nivel N; en VRAM va debajo de la comun
#   build/levelN_v9.bin   bloque del nivel N con los descriptores parcheados
#   build/port.bin        (se modifica) descriptores comunes y bloque del nivel 1 parcheados
#   build/sheets.inc      tablas para src/v9.asm;  build/sheets_rom.inc  bancos para src/rom.asm
#   assets/sheets/*.png   vista previa
#
# Ademas de los fotogramas con descriptor (objetos y coches escalados) entran los sprites
# sin escalar (piezas del coche del jugador, sombra, polvo, chispas, sirena...): no tienen
# descriptor, asi que el port los busca por su puntero original (build/unscaled.inc).
# Su lista sale de assets/unscaled_seen.json (tools/unsstats.py).
#
# Descriptor de fotograma del original (7 bytes): ancho en bytes, flags (bit 0 = con
# mascara, bits 1-7 = espejado), alto, puntero a los datos, puntero a los datos + 4 px.
# En el port los datos estan en la VRAM, asi que los dos punteros se sustituyen por la
# posicion del bitmap en la hoja:  T = (x/8)*512 + lado*256 + (y - 212)  (siempre < 4000h; un puntero real es
# >= 5C00h, y asi V9_Sprite distingue los descriptores que no se han convertido).
# El segundo lleva ademas el bit 14 cuando el original tenia datos desplazados propios y
# el bit 15 cuando el bitmap esta apilado para el mosaico vertical.
# Los bitmaps espejados se guardan ya volteados.
#
# Fuente de la lista de descriptores: assets/sprites_seen.json (los que el juego dibujo en
# una partida grabada). Los que falten se quedan sin parchear y el port no los dibuja.
# Colores provisionales: 0 transparente, tinta = 1 (negro), papel = 8 (como la arena).
import sys, os, json
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
V9 = os.path.abspath(os.path.join(HERE, '..'))
ROOT = os.path.abspath(os.path.join(V9, '..'))
sys.path.insert(0, HERE)
from sprextract import decode, LEVELS
import v9pal
BUILD = os.path.join(V9, 'build')
UNS_BASE = 0x1C00      # direccion de las entradas de sprites sin escalar (v9.asm)
INK, PAPER = 1, 8       # el papel tiene color propio (igual que la arena) para que no se apague en el tunel
STACK = 32                              # altura de las pilas de mosaico (ver V9_Sprite)
SHEET_Y = 212                           # primera linea de VRAM de las hojas (src/v9.asm)
COMMON_MAX, LEVEL_MAX = 180, 164        # lineas: hasta el panel (392) y hasta las montanas (376)
TEXT_FIXES = [(1, 'VEHICLE IS A WHITE BRITISH SPORTS CAR... OVER.', 'VEHICLE IS A PURPLE BRITISH SPORTS CAR... OVER')]
RESET = '--reset' in sys.argv            # volver a sacar las hojas del original
# descriptores que llevan copia propia del bitmap (clave 'c'): el original los compartia con otro coche
# de otro color (nivel 2: el trafico rojo con el azul; nivel 4: el trafico amarillo con el criminal azul,
# en las dos escalas mas lejanas)
COPIES = {2: (0x6553 + 28, 0x6553 + 35), 4: (0x641C + 28, 0x641C + 35)}
# descriptores que toman el tamano de otro (y una copia propia de su bitmap, clave 'c'): el criminal del
# nivel 4 tenia la escala intermedia de 16 px y saltaba de golpe a la de 32; ahora mide 24x15 como el trafico
REDIRECT = {4: {0x63F2 + 14: 0x641C + 14, 0x63F2 + 21: 0x641C + 21}}
LVL_LO, LVL_HI = 0x5C00, 0x76F0


def decode_raw(m, ptr, w, h, masked, mirror):
    """Bitmap sin descriptor: filas de abajo arriba, w bytes (o w pares mascara/dato)."""
    rows, p = [], ptr
    for _ in range(h):
        row = []
        for _ in range(w):
            if masked:
                mk, dt = m[p], m[p + 1]
                p += 2
            else:
                mk, dt = 0, m[p]
                p += 1
            for b in range(7, -1, -1):
                row.append(2 if dt >> b & 1 else (0 if mk >> b & 1 else 1))
        rows.append(row[::-1] if mirror else row)
    return rows[::-1]


def pack(order, bitmaps, y0):
    """Coloca los bitmaps en filas de 256 px a partir de la linea y0. -> posiciones, fin."""
    x, y, rowh, place = 0, y0, 0, {}
    for k in order:
        w, h = len(bitmaps[k][0]), len(bitmaps[k])
        if x + w > 256:
            x, y, rowh = 0, y + rowh, 0
        place[k] = (x, y)
        x += w
        rowh = max(rowh, h)
    return place, y + rowh


def render(order, bitmaps, place, y0, y1):
    sheet = bytearray(256 * (y1 - y0))
    for k in order:
        px, py = place[k]
        for j, row in enumerate(bitmaps[k]):
            for i, v in enumerate(row):
                sheet[(py - y0 + j) * 256 + px + i] = (0, PAPER, INK)[v]
    return sheet


def trim(rows, sides_only=False):
    """Fotograma sin mascara: el papel que toca el borde (el recuadro que rodea a la figura)
    pasa a transparente. El papel encerrado por la tinta se queda."""
    h, w = len(rows), len(rows[0])
    rows = [list(r) for r in rows]
    todo = [(x, y) for y in range(h) for x in (0, w - 1)]
    if not sides_only:
        todo += [(x, y) for x in range(w) for y in (0, h - 1)]
    while todo:
        x, y = todo.pop()
        if 0 <= x < w and 0 <= y < h and rows[y][x] == 1:
            rows[y][x] = 0
            todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return rows


def kstr(k):
    return '%s:%04X:%d:%d:%d:%d' % (k[0], k[1], k[2], len_h(k), k[4], k[5])


def len_h(k):
    return k[3]


def build_sheet(name, order, bitmaps, place, y0, y1, pal):
    """Hoja de sprites: indices de paleta, 256 x (y1 - y0).
    assets/editable/sheets/NAME.png es la FUENTE editable (PNG indexado con la paleta del port) y
    NAME.json dice donde esta cada bitmap. Si no existen (o con --reset) se generan del
    original. Si la colocacion cambia (sprites nuevos), cada bitmap se lleva de su sitio
    antiguo al nuevo. Los bitmaps espejados cuyo original tambien esta en la hoja se
    regeneran siempre volteando ese: solo hay que editar el normal."""
    h = y1 - y0
    sheet = render(order, bitmaps, place, y0, y1)
    layout = {}
    for k in order:
        x, y = place[k]
        layout[kstr(k)] = {'x': x, 'y': y - y0, 'w': len(bitmaps[k][0]), 'h': len(bitmaps[k]),
                           'tipo': {'d': 'descriptor', 'c': 'copia'}.get(k[0], 'sin escalar'),
                           'datos': '%04X' % k[1], 'mascara': k[4], 'espejado': k[5]}
    png = os.path.join(V9, 'assets', 'editable', 'sheets', name + '.png')
    js = os.path.join(V9, 'assets', 'noneditable', 'sheets', name + '.json')
    kept = 0
    if not RESET and os.path.exists(png) and os.path.exists(js):
        old = json.load(open(js))['sprites']
        im = Image.open(png)
        ow, oh = im.size
        oidx = v9pal.to_indices(im, pal)
        for ks, e in layout.items():
            o = old.get(ks)
            if o and o['w'] == e['w'] and o['h'] == e['h'] and o['x'] + o['w'] <= ow and o['y'] + o['h'] <= oh:
                for j in range(e['h']):
                    a = (o['y'] + j) * ow + o['x']
                    sheet[(e['y'] + j) * 256 + e['x']:(e['y'] + j) * 256 + e['x'] + e['w']] = bytes(oidx[a:a + e['w']])
                kept += 1
    for k in order:
        twin = k[:5] + (0,)
        if k[5] and twin in bitmaps:
            e, t = layout[kstr(k)], layout[kstr(twin)]
            e['espejo_de'] = kstr(twin)
            for j in range(e['h']):
                a = (t['y'] + j) * 256 + t['x']
                sheet[(e['y'] + j) * 256 + e['x']:(e['y'] + j) * 256 + e['x'] + e['w']] = sheet[a:a + e['w']][::-1]
    v9pal.save_png(png, 256, h, sheet, pal)
    json.dump({'nota': 'generado por tools/mksprites.py; la fuente editable es el PNG', 'y_vram': y0,
               'sprites': layout}, open(js, 'w'), indent=0, sort_keys=True)
    data = bytes(sheet) + bytes(-len(sheet) % 0x4000)
    open(os.path.join(BUILD, name + '.bin'), 'wb').write(data)
    return len(data) // 0x4000, kept


def main():
    pal = v9pal.load()
    seen = json.load(open(os.path.join(V9, 'assets', 'noneditable', 'sprites_seen.json')))['seen']
    unseen = json.load(open(os.path.join(V9, 'assets', 'noneditable', 'unscaled_seen.json')))['seen']
    port = bytearray(open(os.path.join(BUILD, 'port.bin'), 'rb').read())
    blocks = {n: bytearray(open(os.path.join(ROOT, 'msx', LEVELS[n - 1] + '_raw.bin'), 'rb').read()[1:1 + 0x1AF0])
              for n in range(1, 6)}

    # textos del aviso de la radio que dicen el color del coche del criminal: el del port es el de
    # los PNG editables (nivel 1: morado, no blanco). Mismo largo: los textos van pegados
    # (el ultimo caracter lleva el bit 7).
    for lvl, old_t, new_t in TEXT_FIXES:
        enc = lambda t: t[:-1].encode() + bytes([ord(t[-1]) | 0x80])
        assert len(old_t) == len(new_t), 'el texto nuevo tiene que medir lo mismo'
        assert blocks[lvl].count(enc(old_t)) == 1, 'texto no encontrado en el nivel %d' % lvl
        blocks[lvl] = bytearray(bytes(blocks[lvl]).replace(enc(old_t), enc(new_t)))

    def mem(level):
        m = bytearray(port)
        m[LVL_LO:LVL_HI] = blocks[level]
        return m

    # --- bitmaps. Clave ('d', ptr, w, h, masked, mirror) con descriptor; ('u', ...) sin el.
    common, per_level, descs = {}, {n: {} for n in blocks}, {n: {} for n in blocks}
    # los fotogramas que se dibujan en mosaico vertical (modo 2: troncos, postes) y miden
    # hasta 16 lineas se guardan apilados hasta 32 lineas: asi una copia cubre varias
    # repeticiones. La fila inferior de la pila es la del fotograma.
    tiled = set()
    for lvl, a, mode, n in seen:
        key, rows = decode(mem(lvl), a)
        if mode == 2 and key[2] <= 16:
            tiled.add(('d',) + key)
    for lvl, a, mode, n in seen:
        red = REDIRECT.get(lvl, {})
        key, rows = decode(mem(lvl), red.get(a, a))
        key = ('c' if a in COPIES.get(lvl, ()) or a in red else 'd',) + key
        if not key[4]:
            rows = trim(rows, key in tiled)
        if key in tiled:
            rows = rows * (STACK // key[3])
        (per_level[lvl] if LVL_LO <= key[1] < LVL_HI else common)[key] = rows
        descs[lvl][a] = key
    unscaled = {}
    # los 3 fotogramas del icono de turbo (76F0, 38h bytes cada uno): el original los
    # pintaba en el bufer a mano (Hud_Turbos); el port, como sprites sin escalar
    unseen = unseen + [[1, 0x76F0 + 0x38 * i, 2, 14, 1, 0, 0] for i in range(3)]
    for lvl, ptr, w, h, masked, mirror, n in unseen:
        assert not LVL_LO <= ptr < LVL_HI, 'sprite sin escalar en un bloque de nivel'
        key = ('u', ptr, w, h, masked, mirror)
        common[key] = decode_raw(port, ptr, w, h, masked, mirror)
        unscaled.setdefault(ptr, {})[mirror] = key
    os.makedirs(os.path.join(V9, 'assets', 'editable', 'sheets'), exist_ok=True)
    os.makedirs(os.path.join(V9, 'assets', 'noneditable', 'sheets'), exist_ok=True)
    srt = lambda d: sorted(d, key=lambda k: (-len(d[k]), k[1], k[5], k[0]))
    # --- hoja comun (se sube una vez, al arrancar) y, debajo, la de cada nivel
    # la hoja comun va en la mitad derecha de la VRAM (x 256-511) y la del nivel en la
    # izquierda, las dos desde la linea SHEET_Y. T = (x/8)*512 + lado*256 + (y - SHEET_Y)
    place_c, hc = pack(srt(common), common, 0)
    assert hc <= COMMON_MAX, 'la hoja comun no cabe: %d lineas' % hc
    banks = [build_sheet('common', srt(common), common, place_c, 0, hc, pal)[0]]
    tab = [(SHEET_Y | 0x8000, hc)]
    for lvl in sorted(blocks):
        order = srt(per_level[lvl])
        place, y1 = pack(order, per_level[lvl], 0)
        assert y1 <= LEVEL_MAX, 'la hoja del nivel %d no cabe: %d lineas' % (lvl, y1)
        banks.append(build_sheet('level%d' % lvl, order, per_level[lvl], place, 0, y1, pal)[0])
        tab.append((SHEET_Y, y1))
        side = {k: 0 for k in place}
        side.update({k: 1 for k in place_c})
        place.update(place_c)
        for a, k in descs[lvl].items():
            x0, y0 = place[k]
            t = (x0 // 8) << 9 | side[k] << 8 | y0
            tgt = blocks[lvl] if LVL_LO <= a < LVL_HI else port
            off = a - LVL_LO if LVL_LO <= a < LVL_HI else a
            # el segundo puntero lleva el bit 14 si el original tenia datos propios
            # desplazados 4 px (si los dos punteros eran iguales no hay desplazamiento)
            m = mem(lvl)
            src = REDIRECT.get(lvl, {}).get(a, a)
            if src != a:                    # ancho, flags y alto del descriptor del que toma el tamano
                tgt[off:off + 3] = m[src:src + 3]
            t4 = t | (0x4000 if m[src + 3:src + 5] != m[src + 5:src + 7] else 0) | (0x8000 if k in tiled else 0)
            tgt[off + 3:off + 7] = bytes([t & 255, t >> 8, t4 & 255, t4 >> 8])
        open(os.path.join(BUILD, 'level%d_v9.bin' % lvl), 'wb').write(blocks[lvl])
        print('nivel %d: %d lineas (%d bancos), %d bitmaps, %d descriptores'
              % (lvl, y1, banks[-1], len(order), len(descs[lvl])))
    print('comun: %d lineas (%d bancos), %d bitmaps (%d sin escalar)'
          % (hc, banks[0], len(common), sum(len(v) for v in unscaled.values())))
    port[LVL_LO:LVL_HI] = blocks[1]
    open(os.path.join(BUILD, 'port.bin'), 'wb').write(port)
    with open(os.path.join(BUILD, 'sheets.inc'), 'w') as f:
        f.write('; generado por tools/mksprites.py\n')
        f.write('; hojas de sprites: banco de ROM, primera linea de VRAM (bit 15 = mitad derecha) y lineas.\n; 0 = comun, 1-5 = niveles\n')
        f.write('TV9Sheets:\n')
        b = 8
        for i, (y0, h) in enumerate(tab):
            f.write('        db      %d\n        dw      %d,%d\n' % (b, y0, h))
            b += banks[i]
    # sprites sin escalar: se buscan por el byte bajo de su puntero original. Dos tablas
    # de 256 bytes (byte bajo y alto de la direccion de la primera entrada con ese byte
    # bajo; alto 0 = ninguna) y las entradas, ordenadas por byte bajo:
    # db bajo, alto; dw T normal, T espejado (FFFF = no hay). Direcciones fijas (v9.asm).
    with open(os.path.join(BUILD, 'unscaled.inc'), 'w') as f:
        ptrs = sorted(unscaled, key=lambda q: (q & 255, q))
        assert len(ptrs) <= 127
        first = {}
        for n, ptr in enumerate(ptrs):
            first.setdefault(ptr & 255, UNS_BASE + 6 * n)
        f.write('; generado por tools/mksprites.py\n')
        for sh in (0, 8):
            f.write('        db      ' + ','.join(str(first.get(i, 0) >> sh & 255) for i in range(256)) + '\n')
        for ptr in ptrs:
            ts = []
            for mir in (0, 1):
                k = unscaled[ptr].get(mir)
                ts.append((place_c[k][0] // 8) << 9 | 0x100 | place_c[k][1] if k else 0xFFFF)
            f.write('        db      %d,%d\n        dw      %d,%d\n' % (ptr & 255, ptr >> 8, ts[0], ts[1]))
        f.write('        db      %d,0\n' % ((ptrs[-1] + 1) & 255))      # fin de la ultima cadena
    with open(os.path.join(BUILD, 'sheets_rom.inc'), 'w') as f:
        f.write('; generado por tools/mksprites.py: bancos de las hojas de sprites\n')
        b = 8
        for i, name in enumerate(['common'] + ['level%d' % n for n in sorted(blocks)]):
            for k in range(banks[i]):
                f.write('        page    %d\n        code @ 4000h\n        incbin  "../build/%s.bin",%d,4000h\n'
                        % (b, name, k * 0x4000))
                b += 1
        assert b <= 31
    return 0


if __name__ == '__main__':
    sys.exit(main())
