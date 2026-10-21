#!/usr/bin/env python3
# La secuencia final (bloque del nivel 6) para el port.
#
#   mkending.py            assets/editable/ending/*.png -> build/ending_img.bin (hoja 17: 4 bancos de ROM),
#                          build/ending_tones.inc (tablas de los 4 tonos oscuros), y el bloque del nivel 6
#                          parcheado con src/ending.asm -> build/level6_v9.bin
#   mkending.py --reset    vuelve a sacar los PNG editables del bloque original (pierde lo editado)
#
# El bloque original es el del Spectrum sin tocar (docs/10_nivel.md, "Nivel 6"): instala su propia tabla
# IM 2, toca musica por el altavoz del Spectrum (OUT (FE)) y pinta las fotos en su pantalla con fundidos de
# atributos. Aqui se le quitan esas cosas y en su lugar llama a las rutinas de src/ending.asm, que se
# ensamblan en el sitio de las fotos, las manos y el reproductor (60E1-76EE) con las direcciones del port sacadas de
# build/port.lst (por eso va despues de ensamblar port.asm).
#
# Imagenes editables (assets/editable/ending/, paleta del port, 64 colores):
#   photo1.png .. photo4.png   las cuatro fotos (104x64): en el guion, las 01/02 con datos en 60E1, 6489,
#                              6831 y 6BD9
#   hands.png                  el apreton de manos: 6 fotogramas de 64x40 seguidos (384x40), los de la tabla
#                              5FA5 (37, 35, 34, 32, 34 y 35 lineas; el resto negro, como el original, que
#                              borra 3 lineas debajo de cada uno)
# Salen del bloque con los colores que el port da a cada atributo (tAttrToTMS, paleta 32-47). Al empezar el
# final se suben a la VRAM (hoja 17, y 468-675: la zona de las tiras de carretera, que se repintan al salir)
# y la CPU genera alli los 4 tonos oscuros de cada una con las tablas de build/ending_tones.inc (cada color
# de la paleta al mas parecido de su version al 20, 40, 60 y 80 %). Los fundidos del guion pasan a ser copias
# de esos tonos. Los textos se escriben con la fuente de la portada (title_font.png, hoja 14), con sus 4 tonos
# tambien, y bajo la linea de Taito se anade DIHALT STUDIO 2026.
import os, re, subprocess, sys
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import v9pal
V9 = v9pal.V9
ROOT = os.path.abspath(os.path.join(V9, '..'))
SJASM = os.environ.get('SJASM', 'sjasm')
ED = os.path.join(V9, 'assets', 'editable', 'ending')
BASE = 0x5C00
LEN = 0x1AF0
CODE = 0x60E1                   # desde aqui hasta 76EE: fotos, manos y reproductor del original, ya sin uso
GLUE = CODE                     # tabla de saltos de src/ending.asm: jp V9_EndInit / V9_EndFrame / V9_EndExit / ...
PHOTOS = (0x60E1, 0x6489, 0x6831, 0x6BD9)       # 64 lineas de 13 bytes + 8 filas de 13 atributos
PW, PH = 104, 64
HANDS = 0x5FA5                  # 6 entradas: lineas, dw datos (8 bytes por linea)
HW, HH = 64, 40
HAND_ATTR = 0x07                # (el original pone 07 en las 5 filas de 8 celdas)
LINES = 2 * PH + 2 * HH         # hoja: 2 filas de 2 fotos y 2 de manos (4 + 2)
TONES = (0.2, 0.4, 0.6, 0.8)
SYMS = ('V9_SndPlay', 'V9_Lit', 'V9_Dark', 'V9_IntOn', 'V9_SendB', 'V9_WaitCE', 'V9_LoadSheetA', 'V9_StripsUp',
        'V9_CACHE', 'vV9RegB', 'tAttrToTMS', 'vV9Mon', 'vShowHi', 'vV9FlipPend', 'vV9Race', 'SND_TITULO')
# (direccion, bytes originales, bytes nuevos)
def jp(a): return bytes((a & 255, a >> 8))
PATCHES = (
    (0x5C03, b'\x21\xEF\x73\x11\x00\xF3\x01\xFF\x02\xED\xB0', b'\x0E\x00' + b'\x00' * 9),   # copia a F300: fuera (ld c,0: el ldir
                                                                                        # dejaba C a 0 y 5C17 lo guarda en A16F)
    (0x5C1E, b'\xCD\xD1\x73', b'\xCD' + jp(GLUE)),                          # call 73D1 (tabla IM 2) -> V9_EndInit
    (0x5C21, b'\xCD\x00\xF3', b'\x00\x00\x00'),                             # call F300 (musica): fuera
    (0x5C24, b'\xFB\x76\xCD\x40\xF3', b'\x00\x00\xCD' + jp(GLUE + 3)),      # ei/halt, y el beeper (5C26, donde vuelve el
                                                                            # bucle) -> V9_EndFrame
    (0x5C64, b'\xF3\x3E\x80\xED\x47', b'\xCD' + jp(GLUE + 6) + b'\x00\x00'),  # di/ld i,80h -> V9_EndExit
    (0x5E65, b'\x11\x02\x02\xCD\x36\x8A', b'\x00' * 6),                      # ld de,202h / call Snd_SfxSweep (8A36) por cada
                                                                            # 5.000 de los 5.000.000: el port quito ese codigo
                                                                            # (ahi va el reproductor de VGM) y se rompia el bucle
    # fotos y fundidos (src/ending.asm, tabla de saltos en GLUE+9...)
    (0x5E17, b'\x11\x2E\x60', b'\x11' + jp(GLUE + 9)),      # orden 3: fundido de entrada (602E) -> V9_EndFadeIn
    (0x5E20, b'\x11\x72\x60', b'\x11' + jp(GLUE + 12)),     # orden 4: fundido de salida (6072) -> V9_EndFadeOut
    (0x5E27, b'\x11\xB7\x5F', b'\x11' + jp(GLUE + 15)),     # orden 5: fundido de salida con las manos (5FB7) -> V9_EndFadeAnim
    (0x5E30, b'\x11\x6D\x60', b'\x11' + jp(GLUE + 18)),     # orden 6: fundido de salida lento (606D) -> V9_EndFadeSlow
    (0x5EC3, b'\x11\xBA\x5F', b'\x11' + jp(GLUE + 21)),     # ordenes 8/9: las manos (5FBA) -> V9_EndHands
    (0x5EDA, b'\xCD\x9C\x60', b'\xCD' + jp(GLUE + 24)),     # orden 1: borrar los atributos destino (609C) -> V9_EndClear
    (0x5EE8, b'\xCD\xA9\x60', b'\xCD' + jp(GLUE + 27)),     # ordenes 1/2: pintar la foto (60A9) -> V9_EndPlace
    (0x5EF1, b'\xCD\x99\x60', b'\xCD' + jp(GLUE + 30)),     # orden 0B: borrar la ventana (6099) -> V9_EndClearWin
    (0x5F0E, b'\xCD\x1F\x5F', b'\xCD' + jp(GLUE + 33)),     # una letra de un texto (5F1F) -> V9_EndChar (fuente de la portada)
)


def block():
    blk = open(os.path.join(ROOT, 'msx', 'a', '14_raw.bin'), 'rb').read()[1:1 + LEN]
    assert len(blk) == LEN
    return blk


def cells(blk, addr, cols, lines, attrs, tab):
    """Bitmap Spectrum (cols bytes por linea, lines lineas, seguido de sus atributos si attrs es None;
    si no, el atributo de todas las celdas) -> indices de la paleta (32 + color del TMS)."""
    o = addr - BASE
    out = []
    for y in range(lines):
        for c in range(cols):
            b = blk[o + y * cols + c]
            a = attrs if attrs is not None else blk[o + lines * cols + (y // 8) * cols + c]
            t = tab[a]
            ink, paper = 32 + (t >> 4), 32 + (t & 15)
            for k in range(8):
                out.append(ink if b & (0x80 >> k) else paper)
    return out


def extract(pal):
    """Los PNG editables, del bloque original."""
    blk = block()
    tab = v9pal.attr_table()
    os.makedirs(ED, exist_ok=True)
    for i, a in enumerate(PHOTOS):
        v9pal.save_png(os.path.join(ED, 'photo%d.png' % (i + 1)), PW, PH, cells(blk, a, PW // 8, PH, None, tab), pal)
    idx = [33] * (HW * 6 * HH)
    for f in range(6):
        o = HANDS - BASE + 3 * f
        n, p = blk[o], blk[o + 1] | (blk[o + 2] << 8)
        fr = cells(blk, p, HW // 8, n, HAND_ATTR, tab)
        for y in range(n):
            idx[y * HW * 6 + f * HW:y * HW * 6 + f * HW + HW] = fr[y * HW:y * HW + HW]
    v9pal.save_png(os.path.join(ED, 'hands.png'), HW * 6, HH, idx, pal)
    print('assets/editable/ending/: photo1-4.png y hands.png sacados del bloque original')


def tone_tables(pal):
    """4 tablas de 64: cada color al mas parecido de la paleta de su version oscurecida."""
    cols = v9pal.rgb8(pal)
    out = []
    for f in TONES:
        tab = []
        for i in range(64):
            want = tuple(c * f for c in cols[i])
            # (el 0 solo para el 0: es el transparente de las copias)
            tab.append(0 if i == 0 else min(range(1, 64), key=lambda j: sum(w * (a - b) ** 2 for w, a, b in zip((3, 6, 1), cols[j], want))))
        out.append(tab)
    return out


def preview(pal, sheet, tabs):
    """build/ending_preview.png: las imagenes y sus tonos (para mirar, no la usa el juego)."""
    w = 256
    im = Image.new('P', (w * 5, LINES))
    im.putpalette(v9pal.flat(pal))
    data = []
    for y in range(LINES):
        row = sheet[y * w:(y + 1) * w]
        for t in range(5):
            data += row if t == 4 else [tabs[t][c] for c in row]
    im.putdata(data)
    im.save(os.path.join(V9, 'build', 'ending_preview.png'))


def symbols():
    lst = os.path.join(V9, 'src', 'port.lst')        # recien ensamblado (el Makefile lo mueve a build/ al final)
    if not os.path.exists(lst):
        lst = os.path.join(V9, 'build', 'port.lst')
    lst = open(lst).read()
    out = {}
    for m in re.finditer(r'^00:0000([0-9A-F]{4})\s+(?:X\s+)?(\w+)\s*$', lst, re.M):
        out[m.group(2)] = int(m.group(1), 16)
    return out


def main():
    pal = v9pal.load()
    if '--reset' in sys.argv or not all(os.path.exists(os.path.join(ED, n)) for n in ('photo1.png', 'photo2.png', 'photo3.png', 'photo4.png', 'hands.png')):
        extract(pal)
    # la hoja: 256 de ancho; fotos de dos en dos (x 0-103 y 104-207) y manos de cuatro en cuatro
    sheet = [0] * (256 * LINES)
    for i in range(4):
        im = Image.open(os.path.join(ED, 'photo%d.png' % (i + 1)))
        assert im.size == (PW, PH), 'photo%d.png tiene que medir %dx%d' % (i + 1, PW, PH)
        idx = v9pal.to_indices(im, pal)
        x0, y0 = (i & 1) * PW, (i >> 1) * PH
        for y in range(PH):
            sheet[(y0 + y) * 256 + x0:(y0 + y) * 256 + x0 + PW] = idx[y * PW:(y + 1) * PW]
    im = Image.open(os.path.join(ED, 'hands.png'))
    assert im.size == (HW * 6, HH), 'hands.png tiene que medir %dx%d' % (HW * 6, HH)
    idx = v9pal.to_indices(im, pal)
    for f in range(6):
        x0, y0 = (f & 3) * HW, 2 * PH + (f >> 2) * HH
        for y in range(HH):
            sheet[(y0 + y) * 256 + x0:(y0 + y) * 256 + x0 + HW] = idx[y * HW * 6 + f * HW:y * HW * 6 + f * HW + HW]
    os.makedirs(os.path.join(V9, 'build'), exist_ok=True)
    open(os.path.join(V9, 'build', 'ending_img.bin'), 'wb').write(bytes(sheet))
    tabs = tone_tables(pal)
    with open(os.path.join(V9, 'build', 'ending_tones.inc'), 'w') as f:
        f.write('; generado por tools/mkending.py: color de la paleta -> el mas parecido de su version al %s\n'
                % ', '.join('%d %%' % int(t * 100) for t in TONES))
        for t, tab in enumerate(tabs):
            f.write('        db      %s\n' % ','.join(str(c) for c in tab))
    preview(pal, sheet, tabs)
    syms = symbols()
    inc = ['; direcciones del port para src/ending.asm (tools/mkending.py, de build/port.lst)']
    for s in SYMS:
        if s not in syms:
            sys.exit('mkending.py: falta %s en build/port.lst' % s)
        inc.append('%-16s equ %04Xh' % (s, syms[s]))
    open(os.path.join(V9, 'build', 'ending_syms.inc'), 'w').write('\n'.join(inc) + '\n')
    subprocess.run([SJASM, 'ending.asm'], cwd=os.path.join(V9, 'src'), check=True, stdout=subprocess.DEVNULL)
    glue = open(os.path.join(V9, 'build', 'ending.bin'), 'rb').read()[CODE:]      # (sjasm rellena desde 0)
    blk = bytearray(block())
    for a, old, new in PATCHES:
        o = a - BASE
        assert blk[o:o + len(old)] == old, 'nivel 6: en %04X no esta lo esperado' % a
        blk[o:o + len(new)] = new
    assert CODE + len(glue) <= BASE + LEN, 'ending.asm no cabe en el bloque'
    blk[CODE - BASE:CODE - BASE + len(glue)] = glue
    open(os.path.join(V9, 'build', 'level6_v9.bin'), 'wb').write(blk)
    print('level6_v9.bin: final parcheado, %d bytes de codigo en %04X; ending_img.bin: %d lineas (hoja 17)' % (len(glue), CODE, LINES))


if __name__ == '__main__':
    main()
