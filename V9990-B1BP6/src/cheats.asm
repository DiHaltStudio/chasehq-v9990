; Trucos del port. 1 = activado; despues, make.
; Con cualquiera activado el juego ya no coincide con las partidas grabadas: las pruebas
; se pasan con todos a 0.
CHEAT_TURBOS            equ 0           ; turbos infinitos
CHEAT_TIME              equ 0           ; tiempo infinito

        if CHEAT_TURBOS
        code ! 0B0A5h                   ; "dec a": el turbo gastado no se descuenta
        nop
        endif
        if CHEAT_TIME
        code ! 9BCFh                    ; Time_Tick: el tiempo no corre
        ret
        endif
; CHEAT_ENDING (build/config.inc, lo escribe el Makefile: make ending / make ending-rom): al dar al boton de
; marcha en la portada va derecho a la secuencia final (V9_CheatEnding, src/title.asm). Solo en la ROM normal.
        if CHEAT_ENDING
        if ORIG_INPUT = 0
        code ! 83F2h                    ; Game_Start: "call Lvl_Play"
        call    V9_CheatEnding
        endif
        endif
