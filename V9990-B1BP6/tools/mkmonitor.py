#!/usr/bin/env python3
# Monitor del aviso de inicio de nivel ("CHASE H.Q. MONITORING SYSTEM", TUNE, VOLUME, SIGNAL y
# el altavoz): assets/editable/monitor.png -> dos bancos de ROM (58-59) que el juego sube a la
# VRAM al empezar el aviso (hoja 16 de V9_LoadSheetA; x 256-511, y 64-191, la ventana B) y copia
# de golpe a la ventana A (V9_IntroPresent, src/v9.asm).
#
#   mkmonitor.py            assets/editable/monitor.png -> build/monitor.bin
#   mkmonitor.py --reset    vuelve a la captura del original (assets/noneditable/monitor_capture.png;
#                           pierde lo editado), con los textos (CHASE H.Q. MONITORING SYSTEM, TUNE,
#                           VOLUME, SIGNAL) vueltos a escribir con la letra de la portada
#                           (assets/editable/title_font.png)
#
# monitor.png (256x128, lineas 64-191 de la pantalla): paleta de 64 colores del port. Lo unico
# que se mueve encima son las barras de SIGNAL y los puntos de VOLUME (celdas del original).
import os, sys
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import v9pal
V9 = v9pal.V9
PNG = os.path.join(V9, 'assets', 'editable', 'monitor.png')
ORIG = os.path.join(V9, 'assets', 'noneditable', 'monitor_capture.png')
W, H = 256, 128
BG = 33                         # negro del monitor
# textos del original (Lvl_IntroMonitorTexts): columna, linea de la imagen (pantalla - 64), texto
TEXTS = [(2, 8, 'CHASE H.Q. MONITORING SYSTEM'), (3, 56, 'TUNE'), (2, 88, 'VOLUME'), (23, 48, 'SIGNAL')]


def retext(idx, pal):
    """Borra los textos de la captura y los escribe con las letras de title_font.png."""
    import mktitle
    font = v9pal.to_indices(Image.open(mktitle.PNG), pal)
    idx = list(idx)
    for col, y0, text in TEXTS:
        for k, ch in enumerate(text):
            x0 = (col + k) * 8
            tx, ty = mktitle.tile_xy(mktitle.glyph(ch)) if ch != ' ' else (None, None)
            for y in range(8):
                for x in range(8):
                    c = font[(ty + y) * mktitle.W + tx + x] if tx is not None else 0
                    idx[(y0 + y) * W + x0 + x] = c or BG
    for x, y in [(x, 89) for x in range(171, 176)] + [(x, 62) for x in (193, 198, 199)]:
        idx[y * W + x] = BG     # restos sueltos de la captura (puntos de las barras y del altavoz)
    return idx


def main():
    pal = v9pal.load()
    if '--reset' in sys.argv or not os.path.exists(PNG):
        v9pal.save_png(PNG, W, H, retext(v9pal.to_indices(Image.open(ORIG), pal), pal), pal)
        print('assets/editable/monitor.png vuelto a la captura del original, con la letra de la portada')
    im = Image.open(PNG)
    assert im.size == (W, H), 'monitor.png tiene que medir %dx%d' % (W, H)
    idx = v9pal.to_indices(im, pal)
    os.makedirs(os.path.join(V9, 'build'), exist_ok=True)
    open(os.path.join(V9, 'build', 'monitor.bin'), 'wb').write(bytes(idx))
    print('monitor.bin: monitor del aviso de nivel, %d bytes en 2 bancos (58-59)' % len(idx))


if __name__ == '__main__':
    main()
