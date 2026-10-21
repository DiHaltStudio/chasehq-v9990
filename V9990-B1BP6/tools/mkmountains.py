#!/usr/bin/env python3
# Montanas del horizonte: assets/editable/mountains.png -> bancos de ROM que el juego sube
# a la VRAM al cargar cada nivel (hojas 8-12 de V9_LoadSheetA; x 0-255, y 376-399).
#
#   mkmountains.py            assets/editable/mountains.png -> build/mountains.bin,
#                             build/mountains.inc (tabla de hojas), build/mountains_rom.inc
#   mkmountains.py --reset    vuelve a sacar el PNG de los datos de los niveles (pierde lo
#                             editado)
#
# mountains.png (80x120): cinco bandas de 80x24, una por nivel (nivel 1 arriba). Cada
# banda es ciclica: en pantalla se repite cada 80 px, como en el original (que las tiene a
# 1 bpp, 10 bytes por fila). Paleta de 64 colores del port; el fondo es el color del cielo
# (indice 6) y vale cualquier otro indice para el dibujo. En la VRAM la banda se escribe
# 3,2 veces (256 px) para que el scroll (0-76 px) tenga de donde copiar.
import os, sys
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
V9 = os.path.abspath(os.path.join(HERE, '..'))
sys.path.insert(0, HERE)
import v9pal
PNG = os.path.join(V9, 'assets', 'editable', 'mountains.png')
BUILD = os.path.join(V9, 'build')
MTN_BANK = 48                   # un banco por nivel: 48-52
CYCLE, ROWS, LEVELS = 80, 24, 5
MTN_Y = 376                     # V9_MTN_Y
SKY, INK = 6, 1


def generate():
    """Las montanas del original: LevelData = 24 filas de 10 bytes a 1 bpp, de abajo arriba."""
    idx = [SKY] * (CYCLE * ROWS * LEVELS)
    for lvl in range(1, LEVELS + 1):
        blk = open(os.path.join(BUILD, 'level%d_v9.bin' % lvl), 'rb').read()
        for row in range(ROWS):
            y = (lvl - 1) * ROWS + (ROWS - 1 - row)         # la primera fila de los datos es la de abajo
            for x in range(CYCLE):
                if blk[row * 10 + x // 8] & (0x80 >> (x % 8)):
                    idx[y * CYCLE + x] = INK
    return idx


def main():
    pal = v9pal.load()
    if '--reset' in sys.argv or not os.path.exists(PNG):
        v9pal.save_png(PNG, CYCLE, ROWS * LEVELS, generate(), pal)
        print('assets/editable/mountains.png generado de los niveles del original')
    im = Image.open(PNG)
    assert im.size == (CYCLE, ROWS * LEVELS), 'mountains.png tiene que medir %dx%d (5 bandas de %dx%d)' % (
        CYCLE, ROWS * LEVELS, CYCLE, ROWS)
    idx = v9pal.to_indices(im, pal)
    os.makedirs(BUILD, exist_ok=True)
    blob = bytearray()
    for lvl in range(LEVELS):
        for row in range(ROWS):
            line = idx[(lvl * ROWS + row) * CYCLE:(lvl * ROWS + row + 1) * CYCLE]
            blob += bytes(line[x % CYCLE] for x in range(256))
        blob += bytes(0x4000 - 256 * ROWS)                   # relleno hasta el banco siguiente
    open(os.path.join(BUILD, 'mountains.bin'), 'wb').write(blob)
    with open(os.path.join(BUILD, 'mountains.inc'), 'w') as f:
        f.write('; generado por tools/mkmountains.py: hojas 8-12, montanas de los niveles 1-5\n')
        for lvl in range(LEVELS):
            f.write('        db      %d\n        dw      %d,%d\n' % (MTN_BANK + lvl, MTN_Y, ROWS))
    with open(os.path.join(BUILD, 'mountains_rom.inc'), 'w') as f:
        f.write('; generado por tools/mkmountains.py: montanas (bancos %d-%d, una por nivel)\n'
                % (MTN_BANK, MTN_BANK + LEVELS - 1))
        for lvl in range(LEVELS):
            f.write('        page    %d\n        code @ 4000h\n        incbin  "../build/mountains.bin",%d,%d\n'
                    % (MTN_BANK + lvl, lvl * 0x4000, 256 * ROWS))
    print('mountains.bin: %d niveles, bancos %d-%d' % (LEVELS, MTN_BANK, MTN_BANK + LEVELS - 1))


if __name__ == '__main__':
    main()
