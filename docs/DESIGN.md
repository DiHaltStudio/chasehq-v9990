# Port design

The cartridge is a 1 MiB ASCII16 MegaROM. The build reconstructs the MSX program from the user's cassette and places the V9990 port's patches over that image. The original driving logic, road geometry, traffic and scoring stay in Z80 code; the display and sound paths are adapted for the new hardware.

`V9990-B1BP6/src/rom.asm` lays out the banks. `src/bridge_v9.asm` joins the ROM loader to the game's RAM image. `src/port.asm` patches calls into `src/v9.asm` for the V9990 renderer, `src/title.asm` for the title and briefing, `src/sound.asm` for PSG audio, and `src/ending.asm` for the ending.

The V9990 draws the playfield and HUD. Editable PNG assets supply sprite sheets, road strips, the HUD, portraits, title graphics, backgrounds and ending scenes. The palette is held in `assets/editable/palette.gpl`; conversion scripts compile these sources into ROM banks. The sound sources are AY/PSG VGM files under `assets/editable/sound/`.

The sound player advances at 50 Hz. The music, siren, turbo and effects have separate playback slots. Nancy's briefing starts an SOS Morse loop and stops it before the chase begins. A criminal-car impact uses a 520 ms crash effect whose tail is protected from routine roadside noise.

The reconstruction controls in `MSX/ctl/` describe the cassette memory image. The generated original game ASM is a local build product; the V9990 ASM and patch sources are kept in the repository.
