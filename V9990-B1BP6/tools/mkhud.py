#!/usr/bin/env python3
# Panel del marcador: bitmap de 256x64 a 8 bpp que se copia a las dos paginas al empezar
# una carrera (V9_HudRedraw).
#
#   mkhud.py            assets/hud_panel.png -> build/hud.bin (un banco de ROM)
#   mkhud.py --reset    vuelve a generar el PNG a partir del panel del original
#
# assets/hud_panel.png es la FUENTE y se puede editar: PNG indexado con la paleta del
# port (assets/palette.gpl). Si no existe se genera de assets/hud_panel.bin (el panel
# del original, sacado con tools/hudgrab.py), con los colores del port MSX1 en los
# indices 32-47. Las cupulas de las sirenas van en los indices 48-55 (la izquierda) y
# 56-63 (la derecha), que el juego reescribe para hacerlas parpadear: si se pintan con
# otros indices, dejan de parpadear.
import sys, os
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import v9pal
V9 = v9pal.V9
PNG = os.path.join(V9, 'assets', 'editable', 'hud_panel.png')


def generate():
    d = open(os.path.join(V9, 'assets', 'noneditable', 'hud_panel.bin'), 'rb').read()
    bmp, att = d[:2048], d[2048:2304]
    tab = v9pal.attr_table()
    out = bytearray(256 * 64)
    for r in range(8):
        for c in range(32):
            a = att[r * 32 + c]
            siren = 1 <= r <= 4 and (c < 5 or c >= 27)
            if siren:
                base = 48 if c < 5 else 56
                a &= 0xBF
            t = tab[a]
            for line in range(8):
                b = bmp[line * 256 + r * 32 + c]
                for bit in range(8):
                    col = (t >> 4) if b & (0x80 >> bit) else (t & 15)
                    if siren:   # negro fuera de la cupula; blanco el reflejo; el resto, tono medio
                        col = 33 if col < 2 else base + 7 if col == 15 else base + 4
                    else:
                        col += 32
                    out[(r * 8 + line) * 256 + c * 8 + bit] = col
    return out


def main():
    pal = v9pal.load()
    if '--reset' in sys.argv or not os.path.exists(PNG):
        v9pal.save_png(PNG, 256, 64, generate(), pal)
        print('assets/editable/hud_panel.png generado del original')
    im = Image.open(PNG)
    assert im.size == (256, 64), 'hud_panel.png tiene que medir 256x64'
    idx = v9pal.to_indices(im, pal)
    os.makedirs(os.path.join(V9, 'build'), exist_ok=True)
    open(os.path.join(V9, 'build', 'hud.bin'), 'wb').write(bytes(idx))
    print('hud.bin: %d bytes' % len(idx))


if __name__ == '__main__':
    main()
