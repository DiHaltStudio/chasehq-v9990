# Editable assets

`editable/` contains the assets used by the ROM build: 64-colour indexed PNGs, the palette, title and opening images, and PSG VGM tracks. Edit these sources, then run `make` from the repository root.

The main groups are `editable/sheets/` for cars and objects, `editable/ending/` for the final sequence, `editable/intro/` for the logo and cover, and `editable/sound/` for music and effects. `crash.vgm` is the extended criminal-car impact; `sos.vgm` plays during Nancy's briefing. `tools/mkextrasfx.py` can regenerate those two tracks from their programmed patterns.

`noneditable/` contains sprite layout indexes used by the converter. They describe where sprites are packed in the editable PNGs. Build intermediates go in `build/` and are ignored by Git.
