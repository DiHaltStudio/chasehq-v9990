#!/usr/bin/env python3
# Pistas de sonido del port: assets/sound/*.vgm -> bancos de ROM para el reproductor
# (src/sound.asm).
#
#   build/sound.bin      las pistas seguidas, desde el banco SND_BANK (4000h de cada banco)
#   build/sound_rom.inc  las paginas de la ROM que las llevan (src/rom.asm)
#   build/sound.inc      SND_<NOMBRE> y la tabla TSnd: pista, banco, puntero, banco y puntero
#                        del bucle (banco 0 = sin bucle)
#   build/sound_logo.bin la musica del logo de arranque (logo.vgm), en el mismo formato y sin
#                        bucle: la toca Intro (src/rom.asm) desde el banco 0 de la ROM
#
# Lee VGM de un AY-3-8910 (un solo chip): A0 rr dd, esperas 61/62/63/7n y fin 66, con el
# bucle de la cabecera. Rehace el estado de los registros frame a frame (50 Hz), pasa los
# periodos de tono, ruido y envolvente al reloj del PSG del MSX y escribe solo lo que cambia:
#   A0 rr dd ... 63 (fin del frame) ... 66
# En el frame del bucle se reescriben todos los registros de la pista.
import os, struct
HERE = os.path.dirname(os.path.abspath(__file__))
V9 = os.path.abspath(os.path.join(HERE, '..'))
SRC = os.path.join(V9, 'assets', 'editable', 'sound')
BUILD = os.path.join(V9, 'build')
SND_BANK = 53                   # 46-47 libres; 48-52 son las montanas (tools/mkmountains.py)
MSX_CLOCK = 1789772
FRAME = 882
# nombre, pista del reproductor (0 musica, 1 sirena, 2 turbo, 3 efecto); efectoN = id N de
# Snd_Request (tools/beepsfx.py), seguidos
SOUNDS = [('titulo', 0), ('sirena', 1), ('turbo', 2)] + [('efecto%d' % k, 3) for k in range(1, 10)] + [('crash', 3), ('sos', 0)]
LOGO = 'logo'
# corte de una pista: segundos desde el principio y fundido de salida (s) a partir de ahi; lo que
# sigue se descarta. logo: tras tres vueltas del arpegio del acorde final (empieza en 5,76 s y
# cada vuelta dura 0,48 s), que si no se va apagando hasta 9,3 s, y a 9,76 s vuelve a empezar
# la cancion (el bucle del PT3 que quedo en la exportacion a VGM). El logo dura lo que la pista.
CUT = {'logo': (7.20, 0.5)}


def parse(path):
    d = open(path, 'rb').read()
    assert d[:4] == b'Vgm ', '%s no es un VGM' % path
    ver = struct.unpack_from('<I', d, 8)[0]
    start = 0x34 + struct.unpack_from('<I', d, 0x34)[0] if ver >= 0x150 else 0x40
    loop = struct.unpack_from('<I', d, 0x1C)[0]
    loop = 0x1C + loop if loop else None
    clock = struct.unpack_from('<I', d, 0x74)[0] & 0x3FFFFFFF if len(d) > 0x78 else 0
    assert clock, '%s: no lleva un AY-3-8910' % path
    events, t, i, loop_t = [], 0, start, None     # (muestra, registro, valor)
    while True:
        if i == loop:
            loop_t = t
        c = d[i]
        if c == 0xA0:
            events.append((t, d[i + 1] & 0x7F, d[i + 2]))
            i += 3
        elif c == 0x61:
            t += struct.unpack_from('<H', d, i + 1)[0]
            i += 3
        elif c == 0x62:
            t += 735
            i += 1
        elif c == 0x63:
            t += FRAME
            i += 1
        elif 0x70 <= c <= 0x7F:
            t += (c & 15) + 1
            i += 1
        elif c == 0x66:
            break
        else:
            raise SystemExit('%s: orden VGM %02X no soportada (offset %X)' % (path, c, i))
    return events, t, loop_t, clock


def frames(events, total, loop_t, clock):
    """Registros escritos en cada frame, ya al reloj del MSX."""
    n = (total + FRAME - 1) // FRAME
    per = [dict() for _ in range(max(n, 1))]
    for t, r, v in events:
        if r < 14:
            per[min(t // FRAME, n - 1)][r] = v
    k = MSX_CLOCK / clock
    st, out = {}, []
    for regs in per:
        st.update(regs)
        sc = dict(regs)
        for lo, hi in ((0, 1), (2, 3), (4, 5)):
            if lo in regs or hi in regs:
                p = st.get(lo, 0) | (st.get(hi, 0) & 15) << 8
                p = min(4095, max(1, round(p * k))) if p else 0
                sc[lo], sc[hi] = p & 255, p >> 8
        if 6 in regs:
            sc[6] = min(31, round((st[6] & 31) * k))
        if 11 in regs or 12 in regs:
            p = min(65535, round((st.get(11, 0) | st.get(12, 0) << 8) * k))
            sc[11], sc[12] = p & 255, p >> 8
        out.append(sc)
    return out, (loop_t // FRAME if loop_t is not None else None)


def cut(fr, at, fade):
    """Corta la pista en el frame del segundo AT, con un fundido de FADE s (volumenes R8-R10;
    los que van con envolvente, a 0 al final)."""
    a, n = round(at * 50), round(fade * 50)
    fr, st = [dict(r) for r in fr[:a + n]], {}
    for i, regs in enumerate(fr):
        st.update(regs)
        if i >= a:
            k = (a + n - i - 1) / (n + 1)
            for r in (8, 9, 10):
                v = st.get(r, 0)
                regs[r] = round((v & 15) * k) if v < 16 else 0
    return fr


def encode(fr, loop_f):
    data, shadow, loop_ofs, st = bytearray(), {}, None, {}
    for i, regs in enumerate(fr):
        st.update(regs)
        if i == loop_f:
            loop_ofs = len(data)
            regs, shadow = dict(st), {}
        for r in sorted(regs):
            v = regs[r]
            if r == 13 or shadow.get(r) != v:
                data += bytes([0xA0, r, v])
                shadow[r] = v
        data.append(0x63)
    data.append(0x66)
    return data, loop_ofs


def convert(name):
    events, total, loop_t, clock = parse(os.path.join(SRC, name + '.vgm'))
    fr, loop_f = frames(events, total, loop_t, clock)
    if name in CUT:
        fr, loop_f = cut(fr, *CUT[name]), None
    data, loop_ofs = encode(fr, loop_f)
    print('%s: %d frames (%.1f s), %d bytes%s' % (name, len(fr), len(fr) / 50, len(data),
                                                  ', bucle' if loop_ofs is not None else ''))
    return data, loop_ofs


def main():
    blob, table, inc = bytearray(), [], []
    for idx, (name, stream) in enumerate(SOUNDS):
        data, loop_ofs = convert(name)
        pos = len(blob)
        blob += data
        where = lambda o: (SND_BANK + o // 0x4000, 0x4000 + o % 0x4000)
        b, a = where(pos)
        lb, la = where(pos + loop_ofs) if loop_ofs is not None else (0, 0)
        table.append('        db      %d,%d\n        dw      %04Xh\n        db      %d\n        dw      %04Xh'
                     % (stream, b, a, lb, la))
        if name in ('crash', 'sos'):
            table[-1] = '        if ORIG_INPUT = 0\n' + table[-1] + '\n        endif'
        inc.append('SND_%s equ %d' % (name.upper(), idx))
    nb = (len(blob) + 0x3FFF) // 0x4000
    assert SND_BANK + nb <= 63, 'las pistas no caben en la ROM'
    os.makedirs(BUILD, exist_ok=True)
    open(os.path.join(BUILD, 'sound.bin'), 'wb').write(blob)
    with open(os.path.join(BUILD, 'sound.inc'), 'w') as f:
        f.write('; generado por tools/mksound.py\n' + '\n'.join(inc) + '\n')
        f.write('; por sonido: pista, banco, puntero, banco del bucle (0 = sin bucle), puntero del bucle\nTSnd:\n')
        f.write('\n'.join(table) + '\n')
    with open(os.path.join(BUILD, 'sound_rom.inc'), 'w') as f:
        f.write('; generado por tools/mksound.py: pistas de sonido (bancos %d-%d)\n' % (SND_BANK, SND_BANK + nb - 1))
        for k in range(nb):
            n = min(0x4000, len(blob) - k * 0x4000)
            f.write('        page    %d\n        code @ 4000h\n        incbin  "../build/sound.bin",%d,%d\n'
                    % (SND_BANK + k, k * 0x4000, n))
    logo, _ = convert(LOGO)
    open(os.path.join(BUILD, 'sound_logo.bin'), 'wb').write(logo)
    print('sound.bin: %d bytes en %d bancos (%d-%d)' % (len(blob), nb, SND_BANK, SND_BANK + nb - 1))


if __name__ == '__main__':
    main()
