; main.asm -- ensambla la imagen 64K de Chase H.Q. (MSX) para comparar con MSX/orig/image.bin
        output  "../work/game.bin"
        defpage 0, 0000h, 10000h
        include "symbols.asm"
        include "msx.asm"
        include "screen.asm"
        include "level.asm"
        include "game.asm"
