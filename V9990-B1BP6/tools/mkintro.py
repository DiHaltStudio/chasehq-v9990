#!/usr/bin/env python3
# Pantallas de arranque: logo (4 s) y portada (hasta pulsar una tecla). Las dos van en
# BD8, el modo de color directo del V9990: cada byte es un pixel GGG RRR BB (RGB332).
#
#   mkintro.py             assets/editable/intro/*.png -> build/logo.bin, build/opening.bin
#   mkintro.py --convert   vuelve a sacar opening-b3.png de opening.png (pierde retoques)
#
# Fuentes (assets/intro/):
#   dihalt_logo-b1.png   256x212, PNG indexado cuyos indices ya son el color RGB332
#                        (modo B1). Viene de pinballdreams_v9990/pdmsx_b2pb6/ref.
#   opening.png          la portada original, a cualquier tamano.
#   opening-b3.png       la portada lista para el V9990: 512x424 (modo B3, entrelazado),
#                        con los 256 colores RGB332. Se genera de opening.png la primera
#                        vez (centrada, a 424 lineas, con tramado) y luego es la FUENTE:
#                        se puede retocar a mano.
import sys, os
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
V9 = os.path.abspath(os.path.join(HERE, '..'))
SRC = os.path.join(V9, 'assets', 'editable', 'intro')        # logo y portada lista para el V9990
ORIG = os.path.join(V9, 'assets', 'noneditable', 'intro')   # portada original (solo para --convert)
BUILD = os.path.join(V9, 'build')


def pal332():
    out = []
    for c in range(256):
        out += [((c >> 2) & 7) * 255 // 7, ((c >> 5) & 7) * 255 // 7, (c & 3) * 255 // 3]
    return out


def code332(r, g, b):
    return ((g * 7 + 127) // 255) << 5 | ((r * 7 + 127) // 255) << 2 | (b * 3 + 127) // 255


def to332(im):
    """Imagen -> bytes RGB332. Si es indexada con la paleta RGB332, los indices tal cual."""
    if im.mode == 'P' and im.getpalette()[:768] == pal332():
        return bytes(im.getdata())
    return bytes(code332(r, g, b) for r, g, b in im.convert('RGB').getdata())


def convert_opening():
    src = Image.open(os.path.join(ORIG, 'opening.png')).convert('RGB')
    w = min(512, round(src.width * 424 / src.height))
    small = src.resize((w, 424), Image.LANCZOS)
    canvas = Image.new('RGB', (512, 424), (0, 0, 0))
    canvas.paste(small, ((512 - w) // 2, 0))
    palim = Image.new('P', (1, 1))
    palim.putpalette(pal332())
    out = canvas.quantize(palette=palim, dither=Image.FLOYDSTEINBERG)
    out.save(os.path.join(SRC, 'opening-b3.png'), optimize=True)
    print('opening-b3.png: opening.png %dx%d -> %dx424, centrada' % (src.width, src.height, w))


def main():
    os.makedirs(BUILD, exist_ok=True)
    logo = Image.open(os.path.join(SRC, 'dihalt_logo-b1.png'))
    assert logo.size == (256, 212), 'el logo tiene que medir 256x212'
    data = to332(logo)
    open(os.path.join(BUILD, 'logo.bin'), 'wb').write(data + bytes(-len(data) % 0x4000))
    b3 = os.path.join(SRC, 'opening-b3.png')
    if '--convert' in sys.argv or not os.path.exists(b3):
        convert_opening()
    op = Image.open(b3)
    assert op.size == (512, 424), 'opening-b3.png tiene que medir 512x424'
    data = to332(op)
    open(os.path.join(BUILD, 'opening.bin'), 'wb').write(data + bytes(-len(data) % 0x4000))
    nb = (len(data) + 0x3FFF) // 0x4000
    with open(os.path.join(BUILD, 'intro_rom.inc'), 'w') as f:
        f.write('; generado por tools/mkintro.py: bancos del logo y de la portada\n')
        for name, first, n in (('logo', 27, 4), ('opening', 32, nb)):
            for k in range(n):
                f.write('        page    %d\n        code @ 4000h\n        incbin  "../build/%s.bin",%d,4000h\n'
                        % (first + k, name, k * 0x4000))
    print('logo.bin: 4 bancos (27-30); opening.bin: %d bancos (32-%d)' % (nb, 31 + nb))


if __name__ == '__main__':
    main()
