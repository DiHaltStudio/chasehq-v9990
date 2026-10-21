#!/usr/bin/env python3
# Extrae a PNG los fotogramas de sprite que el juego dibuja en cada nivel.
#
#   sprextract.py [--from-stats MSX/build/sprstats_5.pkl]
#
# Entrada: assets/sprites_seen.json (lista de descriptores vistos en una partida grabada:
# nivel, direccion, modo y numero de dibujos). Con --from-stats se regenera esa lista a
# partir de la salida de tools/sprstats.py.
# Datos: la imagen de 64K (MSX/orig/image.bin) con el bloque de cada nivel en 5C00.
#
# Descriptor (7 bytes): ancho en bytes, flags (bit 0 = con mascara, bits 1-7 = espejado),
# alto, puntero a los datos, puntero a los datos desplazados 4 px.
# Datos: filas de abajo arriba. Con mascara: por fila, 'ancho' pares [mascara][dato]
# (pantalla = pantalla AND mascara OR dato). Opaco: 'ancho' bytes por fila.
#
# Salida, por nivel: assets/sprites/levelN.png (hoja indexada: 0 transparente, 1 papel,
# 2 tinta) y assets/sprites/levelN.json (rectangulo de cada bitmap y descriptores que lo
# usan). Los bitmaps espejados se guardan ya volteados, como se ven.
import sys, os, json, pickle
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
V9 = os.path.abspath(os.path.join(HERE, '..'))
ROOT = os.path.abspath(os.path.join(V9, '..'))
LEVELS = ['b/01', 'a/06', 'a/08', 'a/10', 'a/12']
SEEN = os.path.join(V9, 'assets', 'noneditable', 'sprites_seen.json')
OUT = os.path.join(V9, 'assets', 'noneditable', 'sprites')
PAL = [255, 0, 255, 230, 206, 128, 0, 0, 0]       # transparente (magenta), papel, tinta


def memory(level):
    m = bytearray(open(os.path.join(ROOT, 'MSX/orig/image.bin'), 'rb').read())
    blk = open(os.path.join(ROOT, 'msx', LEVELS[level - 1] + '_raw.bin'), 'rb').read()[1:1 + 0x1AF0]
    m[0x5C00:0x5C00 + len(blk)] = blk
    return m


def decode(m, a):
    """Descriptor en a -> (clave del bitmap, filas de indices de arriba abajo)."""
    w, fl, h = m[a], m[a + 1], m[a + 2]
    ptr = m[a + 3] | m[a + 4] << 8
    masked, mirror = fl & 1, 1 if fl >> 1 else 0
    rows = []
    p = ptr
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
    return (ptr, w, h, masked, mirror), rows[::-1]


def main():
    if '--from-stats' in sys.argv:
        d = pickle.load(open(sys.argv[sys.argv.index('--from-stats') + 1], 'rb'))
        seen = sorted([lvl, hl, mode, n] for (lvl, hl, mode), (n, _, _) in d['spr'].items() if 1 <= lvl <= 5)
        os.makedirs(os.path.dirname(SEEN), exist_ok=True)
        json.dump({'source': os.path.basename(d['replay']), 'fields': ['level', 'descriptor', 'mode', 'draws'],
                   'seen': seen}, open(SEEN, 'w'), separators=(',', ':'))
    seen = json.load(open(SEEN))['seen']
    os.makedirs(OUT, exist_ok=True)
    for level in range(1, 6):
        m = memory(level)
        bitmaps = {}
        for lvl, a, mode, n in seen:
            if lvl != level:
                continue
            key, rows = decode(m, a)
            e = bitmaps.setdefault(key, {'rows': rows, 'desc': [], 'draws': 0})
            e['desc'].append('%04X' % a)
            e['draws'] += n
        # empaquetado simple por filas, ordenado por alto y direccion
        order = sorted(bitmaps, key=lambda k: (-k[2], k[0], k[4]))
        W, x, y, rowh, place = 256, 0, 0, 0, {}
        for k in order:
            w, h = k[1] * 8, k[2]
            if x + w > W:
                x, y, rowh = 0, y + rowh + 1, 0
            place[k] = (x, y)
            x += w + 1
            rowh = max(rowh, h)
        H = y + rowh
        im = Image.new('P', (W, H), 0)
        im.putpalette(PAL)
        px = im.load()
        meta = []
        for k in order:
            x0, y0 = place[k]
            for j, row in enumerate(bitmaps[k]['rows']):
                for i, v in enumerate(row):
                    px[x0 + i, y0 + j] = v
            meta.append({'data': '%04X' % k[0], 'x': x0, 'y': y0, 'w': k[1] * 8, 'h': k[2],
                         'masked': k[3], 'mirrored': k[4], 'draws': bitmaps[k]['draws'],
                         'descriptors': sorted(set(bitmaps[k]['desc']))})
        im.save(os.path.join(OUT, 'level%d.png' % level), transparency=0)
        json.dump(meta, open(os.path.join(OUT, 'level%d.json' % level), 'w'), indent=0)
        print('nivel %d: %d bitmaps, hoja %dx%d, %d px' % (level, len(meta), W, H, sum(e['w'] * e['h'] for e in meta)))


if __name__ == '__main__':
    main()
