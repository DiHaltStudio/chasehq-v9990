#!/usr/bin/env python3
# Caras y letras de la radio: dos PNG editables -> una hoja de 256x60 a 8 bpp que el juego
# sube a la VRAM al arrancar (x 256-511, y 0-59; hoja 7 de V9_LoadSheetA).
#
#   mkradio.py            assets/editable/radio_portraits.png y radio_font.png
#                         -> build/radio.bin (un banco de ROM) y build/radio.inc
#   mkradio.py --reset    vuelve a sacar los dos PNG de los datos del original (pierde lo
#                         editado)
#
# radio_portraits.png (160x40): 5 caras de 32x40, en este orden: las tres fijas de la radio
#   (Nancy y las otras dos; el original las tiene en tPortraitBase + n * B4h, n = 1-3) y los
#   criminales de los niveles 2 y 4 (los unicos niveles cuyo bloque trae retrato).
# radio_font.png (90x30): las letras de la linea de radio, en una rejilla de 10 x 5 celdas
#   de 9x6 (cada letra con su papel; la columna 8 es el espacio hasta la siguiente):
#     celdas 0-25 A-Z, 26 '.', 27 ',', 28 '!', 29 (sin uso), 30 ''', 31-40 0-9,
#     41 espacio, 42 el cursor (las columnas 5-8 de esta celda son el cursor), 43-49 sin uso.
#   La version con cursor de cada letra (la que se ve mientras se escribe) la hace este
#   programa: la letra con las columnas 5-8 de la celda del cursor encima.
# Los dos llevan la paleta de 64 colores del port (assets/editable/palette.gpl).
#
# En la hoja (x relativa a 256): caras en x 0-159, y 0-39; letras en x 166-255, y 0-29 sin
# cursor y y 30-59 con cursor. Las tiras de los iconos de turbo (y 40-53) las pinta el
# juego despues, desde la hoja comun.
import sys, os
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import v9pal
V9 = v9pal.V9
ED = os.path.join(V9, 'assets', 'editable')
PORTRAITS = os.path.join(ED, 'radio_portraits.png')
FONT = os.path.join(ED, 'radio_font.png')
T_PORTRAIT = 0x7B35             # tPortraitBase
FNT_SMALL = 0xDFF8              # Fnt_Small: 41 glifos de 6 bytes
CELL_W, CELL_H, COLS, ROWS = 9, 6, 10, 5
FONT_X = 166                    # x de la rejilla de letras en la hoja (V9_PIC_RAD_X - 256)
CURSOR = 42


def image():
    return open(os.path.join(V9, '..', 'MSX', 'orig', 'image.bin'), 'rb').read()


def peek(img, a, n):
    return img[a - v9pal.IMG_BASE:a - v9pal.IMG_BASE + n]


def portrait(data, tab):
    """Retrato del original (A0h bytes: 4 x 40 lineas, y 20 atributos 4x5) -> 32x40 indices."""
    out = []
    for y in range(40):
        for x in range(32):
            b = data[y * 4 + x // 8]
            t = tab[data[0xA0 + (y // 8) * 4 + x // 8]]
            out.append(32 + ((t >> 4) if b & (0x80 >> (x % 8)) else (t & 15)))
    return out


def generate():
    img, tab = image(), v9pal.attr_table()
    faces = [portrait(peek(img, T_PORTRAIT + n * 0xB4, 0xB4), tab) for n in (1, 2, 3)]
    for lvl in (2, 4):
        blk = open(os.path.join(V9, 'build', 'level%d_v9.bin' % lvl), 'rb').read()
        p = blk[0xF2] | blk[0xF3] << 8
        faces.append(portrait(blk[p - 0x5C00:p - 0x5C00 + 0xB4], tab))
    pic = [0] * (160 * 40)
    for k, f in enumerate(faces):
        for y in range(40):
            pic[y * 160 + k * 32:y * 160 + k * 32 + 32] = f[y * 32:y * 32 + 32]
    # letras: tinta y papel del atributo de la linea de radio del marcador original (celda C1h)
    att = open(os.path.join(V9, 'assets', 'noneditable', 'hud_panel.bin'), 'rb').read()[2048 + 0xC1]
    t = tab[att]
    ink, paper = 32 + (t >> 4), 32 + (t & 15)
    font = [paper] * (COLS * CELL_W * ROWS * CELL_H)
    glyphs = peek(img, FNT_SMALL, 41 * 6)
    for g in range(43):
        cx, cy = (g % COLS) * CELL_W, (g // COLS) * CELL_H
        for y in range(CELL_H):
            for x in range(8):
                if g < 41:
                    on = glyphs[g * 6 + y] & (0x80 >> x)
                else:
                    on = g == CURSOR and 5 <= x
                if on:
                    font[(cy + y) * COLS * CELL_W + cx + x] = ink
            if g == CURSOR:
                font[(cy + y) * COLS * CELL_W + cx + 8] = ink
    return pic, font


def main():
    pal = v9pal.load()
    if '--reset' in sys.argv or not (os.path.exists(PORTRAITS) and os.path.exists(FONT)):
        pic, font = generate()
        v9pal.save_png(PORTRAITS, 160, 40, pic, pal)
        v9pal.save_png(FONT, COLS * CELL_W, ROWS * CELL_H, font, pal)
        print('radio_portraits.png y radio_font.png generados del original')
    ip, ifn = Image.open(PORTRAITS), Image.open(FONT)
    assert ip.size == (160, 40), 'radio_portraits.png tiene que medir 160x40 (5 caras de 32x40)'
    assert ifn.size == (COLS * CELL_W, ROWS * CELL_H), 'radio_font.png tiene que medir 90x30'
    pic, font = v9pal.to_indices(ip, pal), v9pal.to_indices(ifn, pal)
    fw = COLS * CELL_W
    sheet = bytearray(256 * 60)
    for y in range(40):
        sheet[y * 256:y * 256 + 160] = bytes(pic[y * 160:y * 160 + 160])
    cur = (CURSOR % COLS) * CELL_W, (CURSOR // COLS) * CELL_H
    for y in range(ROWS * CELL_H):
        row = font[y * fw:(y + 1) * fw]
        sheet[y * 256 + FONT_X:y * 256 + FONT_X + fw] = bytes(row)
        withc = list(row)
        for c in range(COLS):
            for x in range(5, 9):
                withc[c * CELL_W + x] = font[(cur[1] + y % CELL_H) * fw + cur[0] + x]
        sheet[(30 + y) * 256 + FONT_X:(30 + y) * 256 + FONT_X + fw] = bytes(withc)
    paper = font[(41 // COLS) * CELL_H * fw + (41 % COLS) * CELL_W]       # el de la celda del espacio
    os.makedirs(os.path.join(V9, 'build'), exist_ok=True)
    open(os.path.join(V9, 'build', 'radio.bin'), 'wb').write(sheet)
    open(os.path.join(V9, 'build', 'radio.inc'), 'w').write(
        '; generado por tools/mkradio.py\nRADIO_PAPER equ %d            ; papel de la linea de radio (celda del espacio)\n' % paper)
    print('radio.bin: caras y letras de la radio, %d bytes (papel %d)' % (len(sheet), paper))


if __name__ == '__main__':
    main()
