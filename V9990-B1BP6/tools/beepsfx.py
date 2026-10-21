#!/usr/bin/env python3
# Efectos del beeper del original (clic del teclado) -> VGM del PSG.
#
#   beepsfx.py capture   (desde la raiz del repositorio) ejecuta la MegaROM MSX1 en
#                        openMSX (sin ventana ni sonido), llega a la carrera con la partida
#                        grabada, llama a cada uno de los 9 efectos (tabla tSfxTable, 893C)
#                        y registra los cambios del bit 7 del puerto AAh con su instante:
#                        build/beep.json
#   beepsfx.py vgm       de esa medida, assets/sound/efectoN.vgm (N = 1-9) para el canal C
#                        del PSG, y en build/beepsfx/ un WAV del original y otro del PSG
#                        de cada efecto, para compararlos de oido
#
# Conversion, por frame de 50 Hz (20 ms): si los cambios del clic son regulares es un
# tono (su frecuencia); si no, ruido (el ritmo de los clics da el periodo del ruido). El
# volumen sale de la densidad de clics. Los efectos duran entre 17 y 112 ms (1-6 frames);
# el juego los vuelve a pedir en cada frame mientras dura la situacion (cuneta, derrape).
#
# Efectos (id: rutina, uso en el juego):
#   1 ruido 100x1 (la mitad de las veces): derrape / chirrido
#   2 pulsos (8): aterrizaje de un salto       5 pulsos (3): obstaculo que sale despedido
#   3 muestra de 1 bit (8): choque, embestir   4 muestra (12): choque con un obstaculo
#   6 ruido 26x4: rozar una valla               7 ruido 4x120: por la cuneta
#   8, 9 barrido: pitidos de la cuenta atras (alternan)
import os, sys, json, struct, statistics, math, wave
HERE = os.path.dirname(os.path.abspath(__file__))
V9 = os.path.abspath(os.path.join(HERE, '..'))
ROOT = os.path.abspath(os.path.join(V9, '..'))
JSON = os.path.join(V9, 'build', 'beep.json')
OUT = os.path.join(V9, 'assets', 'editable', 'sound')
WAVS = os.path.join(V9, 'build', 'beepsfx')
MSX_CLOCK = 1789772
FRAME_US = 20000.0


def capture():
    import time, pickle, tempfile
    sys.path.insert(0, HERE)
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    import romreplay
    from v9shot import Headless
    ref = pickle.load(open(os.path.join(ROOT, 'MSX', 'build', 'ref_firststage.pkl'), 'rb'))
    tmp = tempfile.mktemp()
    open(tmp, 'wb').write(ref['ev'])
    o = Headless('Sony_HB-10P', os.path.join(ROOT, 'MSX', 'build', 'chasehq_msx1.rom'), romtype='ASCII16')

    def wait():
        while o.cmd('debug breaked') != '1':
            time.sleep(0.1)
    try:
        o.cmd(romreplay.TCL_COMMON)
        o.cmd(romreplay.TCL_PLAY)
        o.cmd('rr_load {%s}' % tmp)
        o.cmd('debug breakpoint create -address 0x3500 -condition {[pc_in_slot 3]} -once true')
        wait()
        romreplay.arm(o, [])
        o.cmd('set ::rr_stop 40000')
        o.cmd('debug cont')
        wait()
        for line in o.cmd('debug breakpoint list').replace('} {', '}\n{').split('\n'):
            n = line.strip('{}').split()[0] if line.strip() else ''
            if n.startswith('bp#'):
                o.cmd('debug breakpoint remove %s' % n)
        o.cmd('set ::rec 0; set ::E {}; set ::last -1')
        o.cmd('debug watchpoint create -type write_io -address 0xAA -command {if {$::rec} {set v [expr {$::wp_last_value & 0x80}]; '
              'if {$v != $::last} {set ::last $v; lappend ::E [format "%.1f %d" [expr {([machine_info time]-$::t0)*1e6}] [expr {$v>>7}]]}}}')
        tab = bytes.fromhex(o.cmd('binary encode hex [debug read_block memory 0x893C 36]'))
        out = {}
        for eff in range(1, 10):
            d, e, lo, hi = tab[(eff - 1) * 4:eff * 4]
            rt = 0x8A17 if eff == 1 else lo | hi << 8       # 1: la vez que si suena
            sp = int(o.cmd('reg sp')) - 2
            o.cmd('poke16 %d 0x8A56' % sp)                    # vuelve a Snd_Nop (ret)
            o.cmd('reg sp %d; reg pc %d; reg d %d; reg e %d; reg iff 0' % (sp, rt, d, e))
            o.cmd('set ::E {}; set ::last -1; set ::t0 [machine_info time]; set ::rec 1')
            o.cmd('debug breakpoint create -address 0x8A56 -once true')
            o.cmd('debug cont')
            wait()
            o.cmd('set ::rec 0')
            dur = (float(o.cmd('machine_info time')) - float(o.cmd('set ::t0'))) * 1e6
            ev = [tuple(map(float, x.split())) for x in o.cmd('join $::E "\n"').split('\n') if x]
            out[eff] = {'d': d, 'e': e, 'rutina': '%04X' % rt, 'dur_us': dur, 'cambios': ev}
            print('efecto %d: %.1f ms, %d cambios' % (eff, dur / 1000, len(ev)))
    finally:
        o.close()
        os.unlink(tmp)
    os.makedirs(os.path.dirname(JSON), exist_ok=True)
    json.dump(out, open(JSON, 'w'))


def convert(eff):
    """Lista de frames: ('tono', periodo, vol) / ('ruido', periodo, vol) / None (silencio).
    Se mide entre flancos de subida (el clic hace pulsos estrechos: el periodo real es de
    subida a subida)."""
    up = [c[0] for c in eff['cambios'] if c[1] == 1]
    nfr = max(1, math.ceil(eff['dur_us'] / FRAME_US))
    frames = []
    for f in range(nfr):
        a, b = f * FRAME_US, min((f + 1) * FRAME_US, eff['dur_us'])
        iv = [y - x for x, y in zip(up, up[1:]) if a <= x < b]
        if not iv:
            frames.append(None if not any(a <= x < b for x in up) else ('ruido', 31, 9))
            continue
        m = statistics.mean(iv)
        cv = statistics.pstdev(iv) / m if len(iv) > 1 else 0
        rate = len(iv) / ((b - a) / 1e6)                      # pulsos por segundo
        if cv < 0.25 and len(iv) >= 3:                        # regular: tono de periodo m
            per = max(1, min(4095, round(MSX_CLOCK / (16 * 1e6 / m))))
            frames.append(('tono', per, 12))
        else:                                                 # irregular: ruido
            per = max(1, min(31, round(MSX_CLOCK / (16 * rate))))
            vol = max(9, min(14, round(8 + math.log2(max(rate, 1) / 500) * 2)))
            frames.append(('ruido', per, vol))
    return frames


def write_vgm(path, frames):
    data = bytearray()
    for fr in frames:
        if fr is None:
            data += bytes([0xA0, 10, 0])
        elif fr[0] == 'tono':
            data += bytes([0xA0, 4, fr[1] & 255, 0xA0, 5, fr[1] >> 8, 0xA0, 10, fr[2], 0xA0, 7, 0x3B])
        else:
            data += bytes([0xA0, 6, fr[1], 0xA0, 10, fr[2], 0xA0, 7, 0x1F])
        data.append(0x63)
    data.append(0x66)
    hdr = bytearray(0x80)
    hdr[0:4] = b'Vgm '
    struct.pack_into('<I', hdr, 0x08, 0x151)
    struct.pack_into('<I', hdr, 0x18, len(frames) * 882)
    struct.pack_into('<I', hdr, 0x24, 50)
    struct.pack_into('<I', hdr, 0x34, 0x80 - 0x34)
    struct.pack_into('<I', hdr, 0x74, MSX_CLOCK)
    out = hdr + data
    struct.pack_into('<I', out, 0x04, len(out) - 4)
    open(path, 'wb').write(out)


def wav(path, samples):
    w = wave.open(path, 'wb')
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(44100)
    w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 12000)) for s in samples))
    w.close()


def render_beeper(eff, pad=0.3):
    n = int((eff['dur_us'] / 1e6 + pad) * 44100)
    s, lvl, j, ev = [], 0, 0, eff['cambios']
    for i in range(n):
        t = i / 44100 * 1e6
        while j < len(ev) and ev[j][0] <= t:
            lvl = ev[j][1]
            j += 1
        s.append(1.0 if lvl and t < eff['dur_us'] else -1.0 if t < eff['dur_us'] else 0.0)
    return s


def render_psg(frames, pad=0.3):
    s, ph, lfsr, nz, nacc = [], 0.0, 1, 1, 0.0
    for fr in frames + [None] * int(pad * 50):
        for i in range(882):
            if fr is None:
                s.append(0.0)
                continue
            amp = 10 ** ((fr[2] - 15) * 1.5 / 20)
            if fr[0] == 'tono':
                ph += MSX_CLOCK / (16 * fr[1]) / 44100
                s.append(amp if (ph % 1) < 0.5 else -amp)
            else:
                nacc += MSX_CLOCK / (16 * fr[1]) / 44100
                while nacc >= 1:
                    nacc -= 1
                    bit = (lfsr ^ (lfsr >> 3)) & 1
                    lfsr = (lfsr >> 1) | (bit << 16)
                    nz = lfsr & 1
                s.append(amp if nz else -amp)
    return s


def vgm():
    d = json.load(open(JSON))
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(WAVS, exist_ok=True)
    for k in sorted(d, key=int):
        fr = convert(d[k])
        write_vgm(os.path.join(OUT, 'efecto%s.vgm' % k), fr)
        wav(os.path.join(WAVS, 'efecto%s_beeper.wav' % k), render_beeper(d[k]))
        wav(os.path.join(WAVS, 'efecto%s_psg.wav' % k), render_psg(fr))
        print('efecto%s.vgm: %s' % (k, ' '.join('-' if f is None else '%s %d v%d' % f for f in fr)))


if __name__ == '__main__':
    {'capture': capture, 'vgm': vgm}[sys.argv[1]]()
