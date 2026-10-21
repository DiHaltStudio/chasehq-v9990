#!/usr/bin/env python3
"""Genera crash.vgm (efecto3 + 500 ms) y SOS Morse en bucle para Nancy.

Fuentes editables: los VGM resultantes. Ejecutar solo para regenerarlos.
"""
import struct
from pathlib import Path
from beepsfx import write_vgm
from mksound import parse, frames, SRC, MSX_CLOCK


def main():
    root = Path(SRC)
    events, total, loop, clock = parse(root / 'efecto3.vgm')
    original, _ = frames(events, total, loop, clock)
    # Conserva el ataque del crash existente; cola de ruido grave de 25 frames.
    state = {}
    for regs in original:
        state.update(regs)
    period, volume = state.get(6, 31), state.get(10, 12) & 15
    crash = [('ruido', period, volume)] * len(original)
    crash += [('ruido', min(31, period + i // 5),
               max(1, round(volume * (25 - i) / 26))) for i in range(25)]
    write_vgm(root / 'crash.vgm', crash)

    # Unidad = 100 ms; punto 1, raya 3, entre signos 1, letras 3,
    # entre repeticiones 7. Tono C de 750 Hz; A/B callados.
    period = round(MSX_CLOCK / (16 * 750))
    sequence = []
    for letter in ('...', '---', '...'):
        for i, symbol in enumerate(letter):
            sequence += [11] * (5 if symbol == '.' else 15)
            sequence += [0] * (5 if i < 2 else 15)
    sequence += [0] * 20  # completa las 7 unidades entre repeticiones
    data = bytearray()
    for r, v in ((4, period & 255), (5, period >> 8), (7, 0x3B), (8, 0), (9, 0)):
        data += bytes((0xA0, r, v))
    for volume in sequence:
        data += bytes((0xA0, 10, volume, 0x63))
    data.append(0x66)
    header = bytearray(0x80)
    header[:4] = b'Vgm '
    for offset, value in ((4, len(header) + len(data) - 4), (8, 0x151),
                          (0x18, len(sequence) * 882), (0x1C, 0x80 - 0x1C),
                          (0x20, len(sequence) * 882), (0x24, 50),
                          (0x34, 0x80 - 0x34), (0x74, MSX_CLOCK)):
        struct.pack_into('<I', header, offset, value)
    (root / 'sos.vgm').write_bytes(header + data)
    print(f'crash: {len(crash) / 50:.2f} s; SOS: {len(sequence) / 50:.2f} s en bucle')


if __name__ == '__main__':
    main()
