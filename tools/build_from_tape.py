#!/usr/bin/env python3
"""Extract the user's MSX cassette and reconstruct the image used by the V9990 port."""
from pathlib import Path
import argparse
import hashlib
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(*args, cwd=ROOT):
    subprocess.run([str(a) for a in args], cwd=cwd, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--side-a', type=Path, required=True, help='original MSX Side A CAS')
    parser.add_argument('--side-b', type=Path, required=True, help='original MSX Side B CAS')
    parser.add_argument('--sjasm', default='sjasm')
    args = parser.parse_args()
    if not args.side_a.is_file():
        parser.error(f'Side A CAS missing: {args.side_a}')
    if not args.side_b.is_file():
        parser.error(f'Side B CAS missing: {args.side_b}')
    a = args.side_a.resolve()
    b = args.side_b.resolve()
    (ROOT/'MSX/orig').mkdir(parents=True, exist_ok=True)
    (ROOT/'MSX/work').mkdir(parents=True, exist_ok=True)
    (ROOT/'MSX/build').mkdir(parents=True, exist_ok=True)
    run(sys.executable, ROOT/'tools/cas.py', a, ROOT/'msx/a')
    run(sys.executable, ROOT/'tools/cas.py', b, ROOT/'msx/b')
    run(sys.executable, ROOT/'tools/dasm/dasm.py', 'image')
    run(sys.executable, ROOT/'tools/dasm/dasm.py', 'emit')
    game = ROOT/'MSX/work/game.bin'
    game.unlink(missing_ok=True)
    run(args.sjasm, 'main.asm', cwd=ROOT/'MSX/src')
    if not game.is_file() or game.stat().st_size != 65536:
        raise SystemExit('SjAsm did not produce the 64 KiB reconstructed game image')
    img = (ROOT/'MSX/orig/image.bin').read_bytes()
    have = (ROOT/'MSX/orig/have.bin').read_bytes()
    built = game.read_bytes()
    mismatch = [p for p in range(0x3300, 0x10000) if have[p] and img[p] != built[p]]
    if mismatch:
        raise SystemExit(f'Reconstruction differs from tape at {len(mismatch)} bytes, first {mismatch[0]:04X}')
    run(args.sjasm, 'ramfind.asm', cwd=ROOT/'MSX/rom')
    ram = ROOT/'MSX/build/ramfind.bin'
    if not ram.is_file():
        raise SystemExit('SjAsm did not produce MSX/build/ramfind.bin')
    print('Reconstructed game image:', hashlib.sha256(built).hexdigest())


if __name__ == '__main__':
    main()
