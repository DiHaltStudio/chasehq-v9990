#!/usr/bin/env python3
# Tiras de carretera del port.
#
#   mkstrips.py           assets/editable/strips.png -> build/strips.bin (tabla de rellenos que
#                         V9_Init pinta al arrancar) y build/wtab.inc (tabla por anchura).
#                         Si el PNG no existe, lo genera primero por programa.
#   mkstrips.py --reset   vuelve a generar assets/editable/strips.png por programa (PIERDE lo
#                         editado) y despues lo mismo que sin argumentos.
#
# assets/editable/strips.png es un PNG INDEXADO EDITABLE (512 x 556) con la paleta del port
# (assets/palette.gpl, 64 colores; make palette-check lo comprueba, como las hojas de
# sprites). Una fila por tira: una tira es una linea de carretera completa de 512 px
# (hierba, bordillos, arcen, asfalto y lineas de carril) con la carretera centrada en
# x = 256. Hay una por anchura W (distancia entre el borde izquierdo y el derecho) y por
# fase:
#   fase 0  banda clara:  hierba clara, bordillo macizo, sin lineas de carril
#   fase 1  banda oscura: hierba oscura, bordillo hueco, con lineas de carril
# (en el original bordillo, linea y trama cambian a la vez cada 2 rodajas).
# La fila 2*n + f del PNG es la tira numero n en fase f, y en VRAM va a la fila
# 468 + 2*n + f (src/v9.asm). Hasta W = 255 hay una tira por anchura (n = W); de 256 a
# 299 solo las pares (n = 256 + (W - 256) / 2), porque no caben mas filas: las impares
# usan la de W - 1. WIDTHS[n] es la anchura de la tira n.
#
# El generador por programa usa los indices 1-5 de la paleta (BLACK, SAND, SAND_D, ASPH,
# WHITE) y simplifica respecto al original, que habra que revisar contra capturas:
#   - la hierba es un color liso en vez de trama;
#   - el grosor de bordillo y linea se elige por la anchura (en el original va por rodaja);
#   - siempre 3 lineas de carril (4 carriles).
# Al editar el PNG vale cualquiera de los 64 colores (2 y 3 son los que el tunel apaga).
#
# Formato de strips.bin: por fila, [n] y n rellenos de 3 bytes, que el juego pinta en ese
# orden (un relleno tapa a los anteriores):
#   [x bajo] [ancho bajo] [color*4 + bit 8 del ancho*2 + bit 8 de x]   (ancho 0 = 512)
# Cada fila del PNG se codifica con el MINIMO de rellenos que la reproducen (se permiten
# solapados: primero la hierba de 512, encima el asfalto, encima lo demas). El fichero
# tiene que caber en un banco de 16 KB menos 16 bytes (LIMIT); si al editar el PNG se
# pasa, el build se para diciendo cuanto sobra y que filas son las mas caras.
import sys, os
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import v9pal
V9 = v9pal.V9
PNG = os.path.join(V9, 'assets', 'editable', 'strips.png')
BIN = os.path.join(V9, 'build', 'strips.bin')
WMAX = 300
WIDTHS = list(range(256)) + list(range(256, WMAX, 2))      # anchuras con tira propia
ROWS = len(WIDTHS) * 2
LIMIT = 0x4000 - 16                                        # un banco de 16 KB menos 16 bytes
# indices de la paleta (assets/palette.gpl) que usa el generador por programa
BLACK, SAND, SAND_D, ASPH, WHITE = 1, 2, 3, 4, 5
# filas con mas rellenos que esto se codifican sin solapar (RLE simple): el buscador del
# minimo es cubico y una fila con ruido no gana nada con el
DP_MAX = 64


def row(w, phase):
    """Tira generada por programa: lista de rellenos (x, ancho, color) en orden de pintado."""
    runs = [(0, 512, SAND_D if phase else SAND)]
    if w <= 0:
        return runs
    x0 = 256 - w // 2
    runs.append((x0, w, ASPH))
    if w >= 160:
        bar, gap, sh, lw = 8, 2, 6, 3
    elif w >= 70:
        bar, gap, sh, lw = 7, 1, 7, 2
    elif w >= 40:
        bar, gap, sh, lw = 5, 2, 6, 1
    else:                                   # muy lejos: todo proporcional a la anchura
        bar, gap, sh, lw = max(1, w // 8), 0, max(1, w // 8), (1 if w >= 12 else 0)
    for side in (0, 1):
        def span(off, n, c):
            if n > 0:
                runs.append((x0 + off if side == 0 else x0 + w - off - n, n, c))
        if phase:                           # bordillo hueco: blanco con borde negro
            span(0, bar, WHITE)
            span(0, 1, BLACK)
        else:
            span(0, bar, BLACK)
        span(bar + gap, sh, BLACK)          # arcen
    if phase and lw:
        for k in (1, 2, 3):
            runs.append((x0 + w * k // 4 - lw // 2, lw, WHITE))
    return runs


def paint(runs, width=512):
    """Rellenos -> fila de pixeles (indices)."""
    px = [0] * width
    for x, n, c in runs:
        for i in range(max(x, 0), min(x + n, width)):
            px[i] = c
    return px


def generate():
    """Las ROWS filas de pixeles del generador por programa."""
    return [paint(row(w, phase)) for w in WIDTHS for phase in (0, 1)]


def rows():
    """Las ROWS filas de pixeles (listas de 512 indices) de assets/editable/strips.png. Si el PNG
    no existe lo genera. Lo usan el build y la vista previa (tools/mkpreview.py)."""
    if not os.path.exists(PNG):
        reset()
    pal = v9pal.load()
    im = Image.open(PNG)
    if im.size != (512, ROWS):
        sys.exit('ERROR: assets/editable/strips.png tiene que medir 512x%d (una fila por tira: fila '
                 '2n+f = tira n, fase f) y mide %dx%d' % ((ROWS,) + im.size))
    idx = v9pal.to_indices(im, pal)
    return [idx[y * 512:(y + 1) * 512] for y in range(ROWS)]


def reset():
    """Regenera assets/editable/strips.png por programa (pierde lo editado)."""
    pal = v9pal.load()
    idx = []
    for r in generate():
        idx += r
    v9pal.save_png(PNG, 512, ROWS, idx, pal)
    print('assets/editable/strips.png generado por programa (%d filas)' % ROWS)


def encode(px):
    """Fila de pixeles -> lista minima de rellenos (x, ancho, color) en orden de pintado.
    Es el problema de la "impresora extrana": programacion dinamica sobre los tramos de
    color seguido, dejando que un relleno se extienda por debajo de los que van encima."""
    seg = []                                # tramos (x, ancho, color) sin solapar
    for x, c in enumerate(px):
        if seg and seg[-1][2] == c:
            seg[-1][1] += 1
        else:
            seg.append([x, 1, c])
    m = len(seg)
    if m > DP_MAX:
        return [tuple(s) for s in seg]
    col = [s[2] for s in seg]
    f = [[0] * m for _ in range(m)]         # f[i][j]: minimo de rellenos para seg[i..j]
    via = [[-1] * m for _ in range(m)]      # k con col[k] == col[j] que lo consigue, o -1
    for i in range(m - 1, -1, -1):
        f[i][i] = 1
        for j in range(i + 1, m):
            best, k0 = f[i][j - 1] + 1, -1
            for k in range(i, j):
                if col[k] == col[j]:
                    v = f[i][k] + (f[k + 1][j - 1] if k + 1 <= j - 1 else 0)
                    if v < best:
                        best, k0 = v, k
            f[i][j], via[i][j] = best, k0

    def rec(i, j, end):
        # pinta seg[i..j]; el relleno que da color a seg[j] llega hasta el final de seg[end]
        if i == j:
            return [(i, end)]
        k = via[i][j]
        if k < 0:
            return rec(i, j - 1, j - 1) + [(j, end)]
        return rec(i, k, end) + (rec(k + 1, j - 1, j - 1) if k + 1 <= j - 1 else [])

    out = []
    for a, b in rec(0, m - 1, m - 1):
        x = seg[a][0]
        out.append((x, seg[b][0] + seg[b][1] - x, col[a]))
    return out


def pack(runs):
    out = bytearray([len(runs)])
    for x, n, c in runs:
        assert 0 <= x < 512 and 0 < n <= 512 and x + n <= 512 and 0 <= c < 64
        out += bytes([x & 255, n & 255, c << 2 | ((n & 511) >> 8) << 1 | x >> 8])
    return out


def desc(y):
    return 'fila %d (tira %d, W=%d, fase %d)' % (y, y // 2, WIDTHS[y // 2], y % 2)


def main():
    if '--reset' in sys.argv:
        reset()
    rows_ = rows()
    out = bytearray()
    cost = []
    toomany = []
    for y, px in enumerate(rows_):
        runs = encode(px)
        assert paint(runs) == px, 'la codificacion de la %s no reproduce sus pixeles' % desc(y)
        cost.append((len(runs), y))
        if len(runs) > 255:                 # la cuenta de rellenos de la fila es un byte
            toomany.append((y, len(runs)))
            continue
        out += pack(runs)
    if toomany:
        print('ERROR: assets/editable/strips.png tiene filas con mas de 255 tramos de color (el maximo '
              'de rellenos por fila):', file=sys.stderr)
        for y, n in toomany[:10]:
            print('  %-36s %3d tramos' % (desc(y), n), file=sys.stderr)
        if len(toomany) > 10:
            print('  ... y %d filas mas' % (len(toomany) - 10), file=sys.stderr)
        print('Simplifica esas filas (menos cambios de color por linea) o make strips-reset '
              '(regenera el PNG por programa y PIERDE lo editado).', file=sys.stderr)
        if os.path.exists(BIN):
            os.remove(BIN)
        sys.exit(1)
    os.makedirs(os.path.join(V9, 'build'), exist_ok=True)
    # tabla por anchura para V9_Line: fila de la tira (fase 0) y SX con el borde
    # izquierdo en la columna 8 de pantalla cuando xL = 0
    with open(os.path.join(V9, 'build', 'wtab.inc'), 'w') as f:
        f.write('; generado por tools/mkstrips.py: por anchura W, dw 264 - W/2, dw fila de su tira\n')
        for w in range(WMAX):
            n_ = w if w < 256 else 256 + (w - 256) // 2
            f.write('        dw      %d,%d\n' % (264 - w // 2, 468 + 2 * n_))
    print('strips.bin: %d bytes de %d (%d filas, %d rellenos; quedan %d bytes libres)'
          % (len(out), LIMIT, ROWS, sum(c for c, _ in cost), LIMIT - len(out)), flush=True)
    if len(out) > LIMIT:
        cost.sort(reverse=True)
        print('ERROR: assets/editable/strips.png no cabe en strips.bin: %d bytes, el limite es %d '
              '(un banco de 16 KB menos 16 bytes): sobran %d bytes.' % (len(out), LIMIT, len(out) - LIMIT),
              file=sys.stderr)
        print('Cada relleno (tramo de un color, con solapados) son 3 bytes; sobran %d rellenos. '
              'Las filas mas caras:' % -(-(len(out) - LIMIT) // 3), file=sys.stderr)
        for c, y in cost[:10]:
            print('  %-36s %3d rellenos = %4d bytes' % (desc(y), c, 1 + 3 * c), file=sys.stderr)
        print('Simplifica esas filas (menos cambios de color por linea) o make strips-reset '
              '(regenera el PNG por programa y PIERDE lo editado).', file=sys.stderr)
        if os.path.exists(BIN):
            os.remove(BIN)
        sys.exit(1)
    open(BIN, 'wb').write(out)


if __name__ == '__main__':
    main()
