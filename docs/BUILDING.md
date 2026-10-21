# Building Chase H.Q. for V9990

The build starts from the two original MSX cassette sides in CAS format. The CAS files are not included in this repository. The repository provides the extraction tools, reconstruction controls, bridge ASM, V9990 port ASM, graphics, sounds and manual sources.

## Requirements

| Tool or input | Purpose |
|---|---|
| Side A and Side B of the MSX Chase H.Q. cassette, CAS format | Original code and level data |
| Classic SjAsm 0.42c (`sjasm`) | Assemble the reconstructed image and port |
| Python 3 with Pillow | Extract data and build the graphics |
| `zip` | Package the release |
| `pdflatex` | Rebuild the English and Spanish manuals |
| openMSX with GFX9000 extension | Play the ROM with `make run` |

Put the two CAS files at `original/side-a.cas` and `original/side-b.cas`. Alternatively, pass `SIDE_A=/path/to/side-a.cas SIDE_B=/path/to/side-b.cas` to `make`. The public source assumes the cassette layout used by the Ocean MSX release: the `CM` loader and program blocks on Side A, and level data on both sides.

```sh
make
make release
```

`make` writes `V9990-B1BP6/build/chasehq_v9990.rom`. `make release` also rebuilds the manuals and writes `release/chasehq_v9990.rom`, both PDF manuals and `release/chasehq-v9990-1.0.zip`.

The first build extracts both CAS files to ignored `msx/a/` and `msx/b/` folders. The control files in `MSX/ctl/` guide the reconstruction of the original 64 KiB image, which is assembled locally to `MSX/work/game.bin`. The build compares the assembled bytes with the data from the cassette, then assembles the RAM finder and V9990 bridge, converts editable PNG/VGM sources, patches the level blocks, and assembles the ASCII16 MegaROM. Generated original data and build intermediates remain ignored by Git.

The source for the port is in `V9990-B1BP6/src/`. The original game's disassembly is generated locally from the user's tape and is not part of the repository. The build is tied to this cassette layout; other editions may need changes to the reconstruction controls.

| Target | Result |
|---|---|
| `make` or `make build` | Extract tape and assemble the ROM |
| `make manual` | Build both PDF manuals |
| `make release` | Build ROM, manuals and release ZIP |
| `make run` | Play the release ROM if present; otherwise build it |
| `make run-turbor` | Play with a turbo R configuration |
| `make clean` | Remove V9990 build intermediates |
| `make help` | Show the common targets |

The downloadable release ROM can be played without the original cassette files: `make run` uses `release/chasehq_v9990.rom` when present.
