#!/usr/bin/env python3
# Portada (ROM normal): las letras de "CHASE H.Q.", "PRESS GEAR TO PLAY", creditos y
# copyright salen de una hoja de letras ya pintadas que el juego sube a la VRAM al arrancar
# (x 0-255, y 443-466; hoja 14 de V9_LoadSheetA). Cada letra en pantalla es una copia del
# V9990 desde esa hoja (src/title.asm); la CPU no da pixeles.
#
#   mktitle.py            assets/editable/title_font.png -> build/titlefont.bin (un banco de ROM)
#                         y build/title.inc (los textos, como indices de letra)
#   mktitle.py --reset    vuelve a sacar el PNG de la fuente del original (pierde lo editado)
#
# title_font.png (256x24), paleta de 64 colores del port (assets/editable/palette.gpl), en
# casillas de 8x8 (32 por fila): 0-40 las letras pequenas (8x8) en el orden de la fuente del
# original: ! ( ) , . 0-9 A-Z; 41-47, en x 72-127 y 8-23, las grandes (8x16) de "CHASE H.Q.":
# C H A S E . Q G I M N O P R T U V B D L W Y (casillas 41-63; las usa la portada y los mensajes de la carrera:
# GAME OVER, TIME UP, CONTINUE THIS MISSION...). Se copian sin el color 0 (el fondo de la portada se ve entre las letras).
import os, sys
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import v9pal
V9 = v9pal.V9
PNG = os.path.join(V9, 'assets', 'editable', 'title_font.png')
TFONT = 0xA27A                  # tFont: 41 glifos de 8x7
W, H = 256, 24
BIG = 'CHASE.QGIMNOPRTUVBDLWY'  # letras grandes (8x16), casillas 41-: las de la portada y las de los mensajes de la carrera
# Letras de color con sombra negra (abajo a la derecha): cada glifo sube una linea para que
# la sombra quepa en la casilla. Las pequenas, blancas arriba y azul claro abajo; las grandes,
# amarillo arriba y naranja abajo.
SHADOW = 1
SMALL_TOP, SMALL_BOT, SMALL_SPLIT = 5, 30, 3        # blanco / amarillo palido; lineas de blanco
BIG_TOP, BIG_BOT, BIG_SPLIT = 11, 12, 7             # amarillo / naranja
# columna (0-31), linea de la pagina, grande; texto
HEAD = [(11, 72, 1, 'CHASE H.Q.'), (7, 96, 0, 'PRESS GEAR TO PLAY')]
CRED = [(6, 120, 0, 'PROGRAM      JOBBEE'), (6, 136, 0, 'GRAPHICS        BILL'),
        (6, 152, 0, 'MUSIC       JON DUNN'), (4, 168, 0, 'MSX V9990 BY DIHALT 2026')]
COPY = [(4, 120, 0, '(C) 1989 OCEAN SOFTWARE'), (3, 136, 0, '(C) 1988 TAITO CORPORATION'),
        (6, 152, 0, 'ALL RIGHTS RESERVED')]


def glyph(ch):
    """Indice en la fuente del original (Txt_MapChar)."""
    if ch in '!(),.':
        return '!(),.'.index(ch)
    if ch.isdigit():
        return 5 + int(ch)
    if 'A' <= ch <= 'Z':
        return 15 + ord(ch) - 65
    raise ValueError('letra sin glifo: %r' % ch)


def tile_xy(n):
    return (n % 32) * 8, (n // 32) * 8


def generate():
    img = open(os.path.join(V9, '..', 'MSX', 'orig', 'image.bin'), 'rb').read()
    font = img[TFONT - v9pal.IMG_BASE:TFONT - v9pal.IMG_BASE + 41 * 7]
    idx = [0] * (W * H)

    def put(x, y, c):
        idx[y * W + x] = c
    def draw(x0, y0, rows, top, bot, split):
        # rows: lineas del glifo (bit 7 = columna 0), ya con su altura final (sin la linea en blanco de arriba)
        for y, b in enumerate(rows):
            for x in range(8):
                if b & (0x80 >> x):
                    if x + 1 < 8:
                        put(x0 + x + 1, y0 + y + 1, SHADOW)
        for y, b in enumerate(rows):
            for x in range(8):
                if b & (0x80 >> x):
                    put(x0 + x, y0 + y, top if y < split else bot)
    for g in range(41):
        x0, y0 = tile_xy(g)
        draw(x0, y0, list(font[g * 7:g * 7 + 7]), SMALL_TOP, SMALL_BOT, SMALL_SPLIT)
    for k, ch in enumerate(BIG):
        g = glyph(ch)
        x0, y0 = tile_xy(41 + k)
        draw(x0, y0, [b for b in font[g * 7:g * 7 + 7] for _ in (0, 1)], BIG_TOP, BIG_BOT, BIG_SPLIT)
    return idx


def records(label, recs):
    out = ['%s:' % label]
    for col, y, big, text in recs:
        assert col + len(text) <= 32
        codes = []
        for ch in text:
            if ch == ' ':
                codes.append(0x7F)
            elif big:
                codes.append(41 + BIG.index(ch))
            else:
                codes.append(glyph(ch))
        codes[-1] |= 0x80
        out.append('        db      %d,%d,%d                ; %s' % (col, y, 16 if big else 8, text))
        out.append('        db      ' + ','.join('%d' % c for c in codes))
    out.append('        db      0FFh')
    return out


def main():
    pal = v9pal.load()
    if '--reset' in sys.argv or not os.path.exists(PNG):
        v9pal.save_png(PNG, W, H, generate(), pal)
        print('assets/editable/title_font.png generado de la fuente del original')
    im = Image.open(PNG)
    assert im.size == (W, H), 'title_font.png tiene que medir %dx%d' % (W, H)
    idx = v9pal.to_indices(im, pal)
    os.makedirs(os.path.join(V9, 'build'), exist_ok=True)
    open(os.path.join(V9, 'build', 'titlefont.bin'), 'wb').write(bytes(idx))
    lines = ['; generado por tools/mktitle.py: textos de la portada. Registro: columna, linea,',
             '; alto (8 o 16) y casillas de title_font.png (7Fh = espacio; bit 7 = la ultima).']
    lines += records('TTlHead', HEAD) + records('TTlCred', CRED)
    lines.append('TTlBigIdx:                              ; letra A-Z -> casilla grande (0 = la 41), FFh = no hay')
    lines.append('        db      ' + ','.join(str(BIG.index(c)) if c in BIG else '255' for c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'))
    open(os.path.join(V9, 'build', 'title.inc'), 'w').write('\n'.join(lines) + '\n')
    open(os.path.join(V9, 'build', 'title2.inc'), 'w').write('\n'.join(lines[:2] + records('TTlCopy', COPY)) + '\n')
    print('titlefont.bin: letras de la portada, %d bytes' % len(idx))


if __name__ == '__main__':
    main()
