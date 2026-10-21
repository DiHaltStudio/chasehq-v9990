# Paleta del port: 64 colores (V9990, BP6). La fuente es assets/palette.gpl (paleta de
# GIMP, 8 bits por canal; el V9990 tiene 5, asi que se redondea).
#
# Reparto de indices:
#    0      transparente en las copias (y color del borde)
#    1-8    los que usa el codigo: 1 tinta, 2 y 3 arena (el tunel los apaga), 4 asfalto,
#           5 blanco, 6 cielo, 7 pared del tunel, 8 papel de los sprites
#    9-31   libres para los graficos
#   32-47   los 16 colores del marcador y los menus (orden del TMS9918)
#   48-63   cupulas de las sirenas del marcador, encendidas: 48-55 la izquierda (roja) y
#           56-63 la derecha (azul). El juego las hace parpadear apagando una y encendiendo
#           la otra: apagada = estos colores oscurecidos (DIM)
import os
HERE = os.path.dirname(os.path.abspath(__file__))
V9 = os.path.abspath(os.path.join(HERE, '..'))
GPL = os.path.join(V9, 'assets', 'editable', 'palette.gpl')
BRIGHT = {4: 5, 6: 8, 10: 11, 12: 3, 14: 15}       # color del TMS -> su version con brillo
DIM = 0.5                                           # sirena apagada: sus colores por este factor


def load(path=GPL):
    """-> lista de 64 (r, g, b, nombre), 8 bits por canal."""
    out = []
    for line in open(path, encoding='utf-8'):
        p = line.split(None, 3)
        if len(p) >= 3 and p[0].isdigit():
            out.append((int(p[0]), int(p[1]), int(p[2]), p[3].strip() if len(p) > 3 else ''))
    assert len(out) == 64, 'la paleta tiene que tener 64 colores (tiene %d)' % len(out)
    return out


def save(pal, path=GPL):
    with open(path, 'w', encoding='utf-8') as f:
        f.write('GIMP Palette\nName: Chase HQ V9990\nColumns: 16\n#\n')
        for r, g, b, name in pal:
            f.write('%3d %3d %3d\t%s\n' % (r, g, b, name))


def q5(v):
    return (v * 31 + 127) // 255


def rgb8(pal):
    """Colores tal como los vera el V9990 (5 bits por canal), en 8 bits."""
    return [tuple(q5(c) * 255 // 31 for c in e[:3]) for e in pal]


def shown(pal):
    """Colores para los PNG: los de rgb8 (las sirenas, encendidas)."""
    return rgb8(pal)


def dim5(e):
    """Color de sirena apagada, en 5 bits por canal."""
    return tuple(q5(int(c * DIM)) for c in e[:3])


def flat(pal):
    """Paleta para un PNG indexado (256 x 3)."""
    out = []
    for c in shown(pal):
        out += c
    return out + [0] * (768 - len(out))


def siren_slots():
    """Colores del TMS (sin brillo) que usan las celdas de las sirenas -> hueco 0-7."""
    d = open(os.path.join(V9, 'assets', 'noneditable', 'hud_panel.bin'), 'rb').read()
    att = d[2048:2304]
    tab = attr_table()
    used = set()
    for r in range(1, 5):
        for c in list(range(5)) + list(range(27, 32)):
            t = tab[att[r * 32 + c] & 0xBF]
            used |= {t >> 4, t & 15}
    used = sorted(used)
    assert len(used) <= 8
    return {c: i for i, c in enumerate(used)}


def attr_table():
    """Tabla atributo Spectrum -> tinta/papel del TMS, de la imagen original (3F00)."""
    return open(os.path.join(V9, '..', 'MSX', 'orig', 'image.bin'), 'rb').read()[0x3F00 - IMG_BASE:0x4000 - IMG_BASE]


IMG_BASE = 0x10000 - os.path.getsize(os.path.join(V9, '..', 'MSX', 'orig', 'image.bin')) \
    if os.path.getsize(os.path.join(V9, '..', 'MSX', 'orig', 'image.bin')) < 0x10000 else 0


def to_indices(im, pal):
    """Imagen PIL -> lista de indices 0-63. Indexada: tal cual; si no, el color mas parecido
    (y transparente -> 0)."""
    if im.mode == 'P':
        return [v & 63 for v in im.getdata()]
    cols = rgb8(pal)
    cache = {}
    out = []
    for px in im.convert('RGBA').getdata():
        if px[3] < 128:
            out.append(0)
            continue
        k = px[:3]
        if k not in cache:
            cache[k] = min(range(1, 64), key=lambda i: sum((a - b) ** 2 for a, b in zip(cols[i], k)))
        out.append(cache[k])
    return out


def save_png(path, w, h, idx, pal):
    from PIL import Image
    im = Image.new('P', (w, h))
    im.putpalette(flat(pal))
    im.putdata(list(idx))
    im.save(path, transparency=0)
