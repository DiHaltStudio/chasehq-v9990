#!/usr/bin/env python3
# Digitos grandes del marcador: assets/editable/hud_digits.png -> una hoja que el juego sube
# a la VRAM al arrancar (x 424-503, y 392-451; hoja 13 de V9_LoadSheetA). Cada digito que
# cambia en el marcador es una copia de 8x15 de su imagen ya pintada (V9_DigCopy).
#
#   mkdigits.py            assets/editable/hud_digits.png -> build/digits.bin (un banco de ROM)
#   mkdigits.py --reset    vuelve a sacar el PNG de la fuente del original con los colores
#                          de cada marcador (pierde lo editado)
#
# hud_digits.png (80x60): cuatro filas de 10 digitos (0-9) de 8x15, con su fondo (la copia
# es opaca): puntos (SCORE), tiempo (TIME), velocidad (SPEED) y distancia (DISTANCE).
# Paleta de 64 colores del port (assets/editable/palette.gpl).
#
# Ojo: assets/editable/hud_panel.png trae dibujados los digitos con que empieza una partida;
# el juego los tapa con estos en cuanto escribe cada marcador.
import os, sys
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import v9pal
V9 = v9pal.V9
PNG = os.path.join(V9, 'assets', 'editable', 'hud_digits.png')
FNT_BIG = 0xDF62                # Fnt_BigDigits: 10 digitos de 8x15, 1 bpp
ROWS = (('puntos', 0x45), ('tiempo', 0x46), ('velocidad', 0x45), ('distancia', 0x04))   # atributo Spectrum
DW, DH = 8, 15
SHEET_X = 424 - 256             # V9_PIC_DIG_X, en la mitad derecha de la VRAM
LINES = DH * len(ROWS)


def generate():
    img = open(os.path.join(V9, '..', 'MSX', 'orig', 'image.bin'), 'rb').read()
    font = img[FNT_BIG - v9pal.IMG_BASE:FNT_BIG - v9pal.IMG_BASE + 150]
    tab = v9pal.attr_table()
    w = DW * 10
    idx = [0] * (w * LINES)
    for r, (name, att) in enumerate(ROWS):
        t = tab[att]
        ink, paper = 32 + (t >> 4), 32 + (t & 15)
        for d in range(10):
            for y in range(DH):
                b = font[d * DH + y]
                for x in range(DW):
                    idx[(r * DH + y) * w + d * DW + x] = ink if b & (0x80 >> x) else paper
    return idx


def main():
    pal = v9pal.load()
    if '--reset' in sys.argv or not os.path.exists(PNG):
        v9pal.save_png(PNG, DW * 10, LINES, generate(), pal)
        print('assets/editable/hud_digits.png generado de la fuente del original')
    im = Image.open(PNG)
    assert im.size == (DW * 10, LINES), 'hud_digits.png tiene que medir %dx%d (4 filas de 10 digitos de %dx%d)' % (
        DW * 10, LINES, DW, DH)
    idx = v9pal.to_indices(im, pal)
    sheet = bytearray(256 * LINES)
    for y in range(LINES):
        sheet[y * 256 + SHEET_X:y * 256 + SHEET_X + DW * 10] = bytes(idx[y * DW * 10:(y + 1) * DW * 10])
    os.makedirs(os.path.join(V9, 'build'), exist_ok=True)
    open(os.path.join(V9, 'build', 'digits.bin'), 'wb').write(sheet)
    print('digits.bin: digitos del marcador, %d bytes' % len(sheet))


if __name__ == '__main__':
    main()
