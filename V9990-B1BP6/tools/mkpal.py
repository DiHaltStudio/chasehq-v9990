#!/usr/bin/env python3
# Sincroniza la paleta del port (assets/editable/palette.gpl, 64 colores; ver tools/v9pal.py) con
# todos los PNG editables (hojas de sprites assets/sheets/*.png, panel assets/hud_panel.png y
# tiras de carretera assets/strips.png).
#
#   mkpal.py                 palette.gpl -> build/palette.inc (tablas para v9.asm),
#                            assets/noneditable/palette.png (muestra) y la paleta de todos los PNG
#                            editables: solo se cambia el bloque de paleta, los indices de
#                            los pixeles se quedan como estan (sin recuantizar). Un PNG que
#                            no sea indexado se convierte al color mas parecido.
#   mkpal.py --check         comprueba que cada PNG editable es indexado y su paleta (64
#                            colores) es exactamente la de palette.gpl. Lista los que no y
#                            sale con error. No escribe nada.
#   mkpal.py --build         lo que hace el build: --check (si falla, falla el build) y
#                            despues palette.inc y palette.png. No toca los PNG.
#   mkpal.py --import X      la paleta de X -> palette.gpl (los nombres se conservan) y
#                            despues lo mismo que sin argumentos. X es un PNG indexado
#                            editable (cuentan sus 64 colores) o una paleta .gpl de 64
#                            colores (cuentan los 64).
#   mkpal.py --sync          busca el PNG editable cuya paleta ya no coincide con
#                            palette.gpl (el que se acaba de editar; si hay varios, el
#                            modificado mas tarde), lo importa y lo lleva a todos los demas
#
# Se importan los 64 colores (48-63 son las cupulas de las sirenas, encendidas). Al
# importar solo se cambian en palette.gpl los colores que de verdad son distintos una vez
# redondeados a 5 bits por canal.
#
# Los ficheros solo se reescriben si su contenido cambia (asi git no ve ruido).
#
# Tablas: TV9Pal (colores 0-31), TV9PalTms (32-47) y, para el parpadeo de las sirenas,
# TV9Sir0 / TV9Sir1 (colores 48-63: izquierda apagada y derecha encendida, y al reves).
import sys, os, glob, io
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import v9pal
V9 = v9pal.V9


def pngs():
    """Todos los PNG editables que consume el build (fuentes, no salidas)."""
    out = sorted(glob.glob(os.path.join(V9, 'assets', 'editable', 'sheets', '*.png'))) + \
        [os.path.join(V9, 'assets', 'editable', n) for n in ('hud_panel.png', 'strips.png', 'radio_portraits.png', 'radio_font.png', 'mountains.png', 'hud_digits.png', 'title_font.png', 'menu_bg.png', 'monitor.png')] + \
        sorted(glob.glob(os.path.join(V9, 'assets', 'editable', 'ending', '*.png')))
    return [p for p in out if os.path.exists(p)]


def rel(path):
    return os.path.relpath(path, V9)


def write_if_changed(path, data):
    """-> True si ha escrito (el contenido era distinto o el fichero no existia)."""
    if os.path.exists(path) and open(path, 'rb').read() == data:
        return False
    with open(path, 'wb') as f:
        f.write(data)
    return True


def png_bytes(im):
    buf = io.BytesIO()
    im.save(buf, format='PNG', transparency=0)
    return buf.getvalue()


def changed(path, pal):
    """Colores del PNG que no coinciden con la paleta: {indice: (r, g, b)}."""
    im = Image.open(path)
    if im.mode != 'P':
        return {}
    raw = (im.getpalette() or []) + [0] * 192
    cols = v9pal.rgb8(pal)
    out = {}
    for i in range(64):
        c = tuple(raw[i * 3:i * 3 + 3])
        if tuple(v9pal.q5(v) for v in c) != tuple(v9pal.q5(v) for v in cols[i]):
            out[i] = c
    return out


def mismatch(path, pal):
    """Por que el PNG no cuadra con la paleta ('' si cuadra): no indexado, o la lista de
    indices 0-63 cuya entrada de paleta no es exactamente la de palette.gpl."""
    im = Image.open(path)
    if im.mode != 'P':
        return 'no es un PNG indexado (modo %s)' % im.mode
    raw = (im.getpalette() or []) + [0] * 192
    want = v9pal.flat(pal)
    bad = [i for i in range(64) if raw[i * 3:i * 3 + 3] != want[i * 3:i * 3 + 3]]
    if not bad:
        return ''
    if len(bad) > 8:
        return 'paleta distinta en %d colores (%s ...)' % (len(bad), ' '.join(map(str, bad[:8])))
    return 'paleta distinta en los colores ' + ' '.join(map(str, bad))


def check(pal):
    """-> lista de (ruta, motivo) de los PNG que no cuadran. Imprime el resultado."""
    bad = [(p, mismatch(p, pal)) for p in pngs()]
    bad = [(p, m) for p, m in bad if m]
    if not bad:
        print('paleta: los %d PNG editables llevan la paleta de assets/editable/palette.gpl' % len(pngs()))
        return bad
    print('ERROR: PNG editables cuya paleta NO es la de assets/editable/palette.gpl:', file=sys.stderr)
    for p, m in bad:
        print('  %-28s %s' % (rel(p), m), file=sys.stderr)
    print('Si has cambiado la paleta en uno de ellos a proposito:\n'
          '    make palette-sync                    (coge la del editado y la lleva a todos)\n'
          '    make palette-import SRC=ese.png      (igual, diciendo cual)\n'
          'Si no (manda palette.gpl):\n'
          '    make palette                         (la de palette.gpl a todos los PNG)',
          file=sys.stderr)
    return bad


def import_from(src):
    pal = v9pal.load()
    if src.lower().endswith('.gpl'):
        new = v9pal.load(src)
        ch = {}
        for i in range(64):
            if tuple(v9pal.q5(v) for v in new[i][:3]) != tuple(v9pal.q5(v) for v in pal[i][:3]):
                ch[i] = new[i][:3]
    else:
        im = Image.open(src)
        assert im.mode == 'P', '%s no es un PNG indexado' % src
        ch = changed(src, pal)
    for i, c in ch.items():
        pal[i] = tuple(c) + (pal[i][3],)
        print('  color %2d (%s): %d,%d,%d' % ((i, pal[i][3]) + tuple(c)))
    v9pal.save(pal)
    print('palette.gpl <- %s (%d colores cambiados)' % (rel(os.path.abspath(src)), len(ch)))


def tables(pal):
    """build/palette.inc y assets/noneditable/palette.png."""
    q = [tuple(v9pal.q5(c) for c in e[:3]) for e in pal]
    os.makedirs(os.path.join(V9, 'build'), exist_ok=True)
    f = io.StringIO()
    f.write('; generado por tools/mkpal.py a partir de assets/editable/palette.gpl (R, G, B de 5 bits)\n')
    f.write('TV9Pal:\n')
    for i in range(32):
        f.write('        db      %2d,%2d,%2d         ; %d %s\n' % (q[i] + (i, pal[i][3])))
    f.write('TV9PalEnd:\nTV9PalTms:\n')
    for i in range(32, 48):
        f.write('        db      %2d,%2d,%2d         ; %d %s\n' % (q[i] + (i, pal[i][3])))
    f.write('TV9PalTmsEnd:\n')
    dim = [v9pal.dim5(e) for e in pal]
    for label, left in (('TV9Sir0', 0), ('TV9Sir1', 1)):
        f.write('%s:                                ; sirenas: %s\n'
                % (label, 'izquierda encendida, derecha apagada' if left else 'izquierda apagada, derecha encendida'))
        for i in range(48, 64):
            f.write('        db      %2d,%2d,%2d\n' % (q[i] if (i < 56) == bool(left) else dim[i]))
    write_if_changed(os.path.join(V9, 'build', 'palette.inc'), f.getvalue().encode('utf-8'))
    sw = Image.new('RGB', (16 * 16, 4 * 16))
    cols = v9pal.rgb8(pal)
    for i in range(64):
        sw.paste(cols[i], ((i % 16) * 16, (i // 16) * 16, (i % 16) * 16 + 16, (i // 16) * 16 + 16))
    buf = io.BytesIO()
    sw.save(buf, format='PNG')
    write_if_changed(os.path.join(V9, 'assets', 'noneditable', 'palette.png'), buf.getvalue())


def sync_pngs(pal):
    """La paleta de palette.gpl a todos los PNG editables, sin tocar los indices. -> cuantos
    se han reescrito."""
    flat = v9pal.flat(pal)
    n = 0
    for path in pngs():
        im = Image.open(path)
        if im.mode == 'P':
            if (im.getpalette() or [])[:192] == flat[:192]:
                continue
            im.putpalette(flat)
        else:
            print('  %s no era indexado: se convierte al color mas parecido' % rel(path))
            idx = v9pal.to_indices(im, pal)
            im = Image.new('P', im.size)
            im.putpalette(flat)
            im.putdata(idx)
        if write_if_changed(path, png_bytes(im)):
            n += 1
    return n


def main():
    if '--check' in sys.argv:
        sys.exit(1 if check(v9pal.load()) else 0)
    if '--build' in sys.argv:
        pal = v9pal.load()
        if check(pal):
            sys.exit(1)
        tables(pal)
        return
    if '--import' in sys.argv:
        import_from(sys.argv[sys.argv.index('--import') + 1])
    if '--sync' in sys.argv:
        pal = v9pal.load()
        cand = [p for p in pngs() if changed(p, pal)]
        if not cand:
            print('ningun PNG tiene una paleta distinta de palette.gpl')
        else:
            cand.sort(key=os.path.getmtime)
            if len(cand) > 1:
                print('varios PNG con paleta distinta; se toma el modificado mas tarde:')
                for p in cand:
                    print('  ' + rel(p))
            import_from(cand[-1])
    pal = v9pal.load()
    tables(pal)
    n = sync_pngs(pal)
    print('palette.inc, palette.png; %d PNG con la paleta nueva' % n)


if __name__ == '__main__':
    main()
