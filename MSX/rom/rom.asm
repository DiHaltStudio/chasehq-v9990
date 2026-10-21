; rom.asm -- Chase H.Q. (MSX, Ocean 1989) como MegaROM ASCII16 de 128K para MSX1.
;
; Contiene la imagen de 64K reconstruida (MSX/src -> MSX/work/game.bin, identica byte a
; byte a la que deja el cargador de cinta) y los 6 bloques de nivel de la cinta, sin
; cambios. Lo unico que no es del original:
;   - este arranque (sustituye al BASIC "CHASE" y al cargador "CM" de la cinta);
;   - el puente de 3400-34FF (bridge.asm), en el sitio de la rutina de cinta.
; Ver docs/14_megarom.md.
;
; Bancos (16K, mapper ASCII16: 6000h -> 4000-7FFF, 7000h -> 8000-BFFF):
;   0  cabecera, arranque, FindRAM, y las zonas de la pagina 0: 3300, puente, 3500-3FFF
;   1  imagen 4000-7FFF        2  imagen 8000-BFFF        3  imagen C000-FFFE
;   4  niveles 1 y 2           5  niveles 3 y 4           6  niveles 5 y 6
;   7  libre (FF)
;
; Requisitos: 64K de RAM. Como en la cinta, el juego escribe en FFFF (ultimo byte del
; buffer trasero): si la RAM esta en un slot expandido eso cambia sus subslots y el
; juego falla. Es una limitacion del original que se conserva.

        output  "../build/chasehq_msx1.rom"
        defpage 0,4000h,4000h
        defpage 1..7,4000h,4000h

; BIOS y variables de sistema (solo durante el arranque)
ENASLT  equ     0024h
CHGMOD  equ     005Fh
INITXT  equ     006Ch
CHGET   equ     009Fh
CHPUT   equ     00A2h
FORCLR  equ     0F3E9h
BAKCLR  equ     0F3EAh
BDRCLR  equ     0F3EBh
EXPTBL  equ     0FCC1h
SLTTBL  equ     0FCC5h

; puente (bridge.asm)
BRIDGE          equ 3400h
vA8Ram          equ 3403h
vA8C1           equ 3404h
vA8C2           equ 3405h
vA8C12          equ 3406h
Boot2Vec        equ 3407h
RAMFIND         equ 8500h

        page    0
        code @ 4000h
        db      "AB"
        dw      Init
        dw      0,0,0
        ds      6

; INIT del cartucho. La BIOS lo llama con la ROM en la pagina 1 y las interrupciones
; habilitadas. No vuelve si hay 64K de RAM.
Init:
        ; lo que hacia el BASIC de la cinta: SCREEN 2:COLOR 15,1,1:CLS
        ld      a,15
        ld      (FORCLR),a
        ld      a,1
        ld      (BAKCLR),a
        ld      (BDRCLR),a
        ld      a,2
        call    CHGMOD
        di
        ; identificador de slot de este cartucho (pagina 1) y cartucho tambien en la
        ; pagina 2, con ENASLT: asi quedan bien sus subslots si el slot esta expandido
        in      a,(0A8h)
        rrca
        rrca
        and     3
        ld      c,a
        ld      b,0
        ld      hl,EXPTBL
        add     hl,bc
        ld      a,(hl)
        and     80h
        or      c
        ld      c,a
        inc     hl
        inc     hl
        inc     hl
        inc     hl                      ; SLTTBL del mismo primario
        ld      a,(hl)
        and     0Ch                     ; subslot de la pagina 1
        or      c
        ld      h,80h
        call    ENASLT
        di
        in      a,(0A8h)
        push    af                      ; A8 base: BIOS, cartucho, cartucho, RAM
        ; RAM para las paginas 2 y 0 (este codigo corre en la pagina 1)
        ; un mapper de RAM (el del propio cartucho, en un MSX1 sin 64K) puede arrancar con sus 4
        ; paginas en el mismo segmento (espejos): los registros del mapper (FC-FF) a 3,2,1,0, lo
        ; que deja la BIOS de un MSX2 (y en un MSX2 ya estan asi: no cambia nada)
        ld      a,3
        out     (0FCh),a
        dec     a
        out     (0FDh),a
        dec     a
        out     (0FEh),a
        dec     a
        out     (0FFh),a
        ld      b,2
        call    FindRAM
        jr      c,.noram
        ld      b,0
        call    FindRAM
        jr      c,.noram
        ; y para la pagina 1, desde RAM en 8500h
        ld      hl,RamFindBin
        ld      de,RAMFIND
        ld      bc,RamFindEnd-RamFindBin
        ldir
        call    RAMFIND                 ; CF=0: L = A8 con RAM en todo
        jr      c,.noram
        pop     af                      ; A8 base, ya no hace falta
        ; zonas de la pagina 0: bordes de carretera (3300), puente (3400), 3500-3FFF
        push    hl
        ld      hl,Img3300
        ld      de,3300h
        ld      bc,Img3300End-Img3300
        ldir
        ld      hl,BridgeBin
        ld      de,BRIDGE
        ld      bc,100h
        ldir
        ld      hl,Img3500
        ld      de,3500h
        ld      bc,0B00h
        ldir
        pop     hl
        ; valores de A8 para el puente. L = todo RAM; el slot primario del cartucho
        ; esta en el campo de la pagina 1 del A8 actual.
        ld      a,l
        ld      (vA8Ram),a
        in      a,(0A8h)
        ld      (vA8C1),a
        and     0Ch
        ld      b,a                     ; B = cartucho en el campo de la pagina 1
        add     a,a
        add     a,a
        ld      c,a                     ; C = cartucho en el campo de la pagina 2
        ld      a,l
        and     0CFh
        or      c
        ld      (vA8C2),a
        and     0F3h
        or      b
        ld      (vA8C12),a
        jp      Boot2Vec

.noram: pop     af
        out     (0A8h),a                ; BIOS otra vez en la pagina 0
        call    INITXT
        ld      hl,.msg
.pr:    ld      a,(hl)
        or      a
        jr      z,.key
        call    CHPUT
        inc     hl
        jr      .pr
.key:   ei
        call    CHGET
        ret
.msg:   db      "CHASE H.Q. needs 64K RAM",13,10,0

        include "findram.inc"

RamFindBin:
        incbin  "../build/ramfind.bin"
RamFindEnd:
BridgeBin:
        incbin  "../build/bridge.bin"
Img3300:
        incbin  "../work/game.bin",3300h,0ABh
Img3300End:
Img3500:
        incbin  "../work/game.bin",3500h,0B00h

        page    1
        code @ 4000h
        incbin  "../work/game.bin",4000h,4000h
        page    2
        code @ 4000h
        incbin  "../work/game.bin",8000h,4000h
        page    3
        code @ 4000h
        incbin  "../work/game.bin",0C000h,3FFFh
        db      0FFh
        page    4
        code @ 4000h
        incbin  "../../msx/b/01_raw.bin",1,1AF0h         ; nivel 1
        incbin  "../../msx/a/06_raw.bin",1,1AF0h         ; nivel 2
        page    5
        code @ 4000h
        incbin  "../../msx/a/08_raw.bin",1,1AF0h         ; nivel 3
        incbin  "../../msx/a/10_raw.bin",1,1AF0h         ; nivel 4
        page    6
        code @ 4000h
        incbin  "../../msx/a/12_raw.bin",1,1AF0h         ; nivel 5
        incbin  "../../msx/a/14_raw.bin",1,1AF0h         ; nivel 6 (final)
        page    7
        code @ 4000h
        ds      4000h,0FFh
