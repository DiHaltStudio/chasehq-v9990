#!/usr/bin/env python3
# Fondo de la portada: assets/editable/menu_bg.png -> bancos de ROM que el juego sube a la
# VRAM al llegar a la portada (hoja 15 de V9_LoadSheetA; x 256-511, y 64-211, la ventana B,
# que la portada no usa). src/title.asm lo copia a la ventana A y, cada vez que borra un
# texto, repone de ahi lo que habia debajo.
#
#   mkmenubg.py            assets/editable/menu_bg.png -> build/menubg.bin y build/menubg_rom.inc
#   mkmenubg.py --reset    vuelve a sacar el PNG de assets/noneditable/menu_background.jpeg
#                          (pierde lo editado)
#
# menu_bg.png (256x148, de la linea 64 a la 211 de la pantalla): paleta de 64 colores del
# port. Al sacarlo de la foto se usan los grises que ya habia (1 negro, 31, 21, 4, 20, 19 y
# 5 blanco) y los dos del fondo del menu (25 y 29).
import os, sys
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import v9pal
V9 = v9pal.V9
PNG = os.path.join(V9, 'assets', 'editable', 'menu_bg.png')
JPG = os.path.join(V9, 'assets', 'noneditable', 'menu_background.jpeg')
BUILD = os.path.join(V9, 'build')
MENU_BANK = 55                  # 3 bancos: 55-57
W, H = 256, 148
GREYS = (1, 25, 31, 21, 29, 4, 20, 19, 5)


def generate(pal):
    import numpy as np
    im = Image.open(JPG).convert('RGB').resize((W, H), Image.LANCZOS)
    a = np.asarray(im, float).reshape(-1, 3)
    rgb = v9pal.rgb8(pal)
    c = np.array([rgb[i] for i in GREYS], float)
    near = ((a[:, None, :] - c[None]) ** 2).sum(2).argmin(1)
    return [GREYS[k] for k in near]


def main():
    pal = v9pal.load()
    if '--reset' in sys.argv or not os.path.exists(PNG):
        v9pal.save_png(PNG, W, H, generate(pal), pal)
        print('assets/editable/menu_bg.png generado de menu_background.jpeg')
    im = Image.open(PNG)
    assert im.size == (W, H), 'menu_bg.png tiene que medir %dx%d' % (W, H)
    idx = v9pal.to_indices(im, pal)
    os.makedirs(BUILD, exist_ok=True)
    blob = bytes(idx) + bytes(3 * 0x4000 - len(idx))
    open(os.path.join(BUILD, 'menubg.bin'), 'wb').write(blob)
    with open(os.path.join(BUILD, 'menubg_rom.inc'), 'w') as f:
        f.write('; generado por tools/mkmenubg.py: fondo de la portada (bancos %d-%d)\n' % (MENU_BANK, MENU_BANK + 2))
        for b in range(3):
            f.write('        page    %d\n        code @ 4000h\n        incbin  "../build/menubg.bin",%d,16384\n' % (MENU_BANK + b, b * 0x4000))
    print('menubg.bin: fondo de la portada, %d bytes en 3 bancos (%d-%d)' % (len(idx), MENU_BANK, MENU_BANK + 2))


if __name__ == '__main__':
    main()
