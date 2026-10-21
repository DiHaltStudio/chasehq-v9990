; bridge.asm -- puente ROM -> RAM residente en 3400-34FF (pagina 0, RAM).
;
; Sustituye a la rutina de cinta del original (3400-34E5, copiada alli por el cargador
; CM). Es la UNICA zona de la imagen de 64K que la MegaROM cambia. Hace dos cosas:
;
;   1. Boot2: termina el arranque. Copia de la ROM a la RAM las zonas 4000-FFFE de la
;      imagen (las que el cargador de cinta dejaba en memoria) y salta a Start (3500).
;   2. TapeLoader (3400): mismo contrato que la rutina de cinta para Lvl_Load (8014):
;      IX = destino, DE = longitud, vuelve con CF=1 = correcto. Sirve la cabecera de
;      nivel (2 bytes) y el bloque de nivel (1AF0h bytes en 5C00) desde la ROM.
;
; Mapper ASCII16: bancos de 16K; escribir en 6000h elige el banco visible en
; 4000-7FFF y en 7000h el de 8000-BFFF. Los registros estan en la pagina 1, asi que
; para escribirlos el cartucho tiene que estar seleccionado en la pagina 1.
; El codigo corre en la pagina 0 (RAM) y la pila esta en la pagina 3 (RAM), de modo
; que puede conmutar las paginas 1 y 2 entre RAM y cartucho con el puerto A8.
; Interrupciones: deshabilitadas siempre (como todo el juego).

; Con V9990 definido (lo incluye V9990-B1BP6/src/bridge_v9.asm) se ensambla la variante
; del port: no toca el TMS9918 y, antes de saltar a Start, llama a V9_Init con el banco
; de datos del V9990 en 4000-7FFF.
        ifdef   V9990
        output  "../build/bridge_v9.bin"
        else
        output  "../build/bridge.bin"
        endif
        defpage 0,3400h,100h
        page    0
        code @ 3400h

vLevel          equ 8007h               ; nivel pedido (1..6)
Start           equ 3500h
VDP_DumpScreen  equ 3C15h
LEVEL_LEN       equ 1AF0h
BANK_P1         equ 1                   ; imagen 4000-7FFF
BANK_P2         equ 2                   ; imagen 8000-BFFF
BANK_P3         equ 3                   ; imagen C000-FFFE
BANK_LEVELS     equ 4                   ; niveles 1-2, 3-4 y 5-6 en los bancos 4, 5 y 6
BANK_V9         equ 7                   ; (solo port V9990) tablas para V9_Init
V9_Init         equ 0100h               ; (solo port V9990) arranque del V9990, en la pagina 0
V9_LoadSheet    equ 0103h               ; (solo port V9990) sube a la VRAM los sprites del nivel
SlotSet         equ 33B2h               ; (solo port V9990) cartucho/RAM en las paginas 1 y 2, tambien por
                                        ; subslot (src/v9.asm): A = 0 todo RAM, 1 cartucho en la pagina 1,
                                        ; 2 en la 2, 3 en las dos
; Cambio de slots: el port lo hace con SlotSet (A8 y, si hace falta, el registro de subslots); la
; ROM MSX1 solo con A8.
        macro   SLOTS n, var
        ifdef   V9990
        ld      a,n
        call    SlotSet
        else
        ld      a,(var)
        out     (0A8h),a
        endif
        endm

TapeLoader:                             ; 3400: misma entrada que la rutina de cinta
        jp      LoadLevel
; Valores del registro de slots (A8). Los escribe el arranque de la ROM (rom.asm).
vA8Ram:   db    0                       ; 3403: RAM en las 4 paginas
vA8C1:    db    0                       ; 3404: cartucho en la pagina 1, RAM en el resto
vA8C2:    db    0                       ; 3405: cartucho en la pagina 2, RAM en el resto
vA8C12:   db    0                       ; 3406: cartucho en las paginas 1 y 2
Boot2Vec:                               ; 3407: entrada desde la ROM
        jp      Boot2

; Carga de nivel. Lvl_Load (8014) la llama dos veces:
;   IX = A19C, DE = 2      cabecera: dos bytes iguales con el numero de nivel
;   IX = 5C00, DE = 1AF0h  bloque de nivel
; En la cinta la cabecera leida podia ser de otro nivel y el juego seguia buscando;
; aqui siempre se contesta con el nivel pedido (vLevel).
; Salida como la rutina de cinta cuando va bien: CF=1, A=0, DE=0, IX = fin del destino,
; R#7 del TMS9918 = 0 (borde) y motor del cassette parado.
; Destruye BC y HL. Conserva BC', DE', HL'.
LoadLevel:
        ld      a,(vLevel)
        ld      c,a
        ld      a,d
        or      a
        jr      nz,.block
        ld      (ix+0),c                ; cabecera: NN NN
        ld      (ix+1),c
        inc     ix
        inc     ix
        ld      e,d                     ; DE = 0
        jr      .done
.block: ld      a,c                     ; nivel n: banco 4 + (n-1)/2, mitad (n-1) & 1
        dec     a
        srl     a
        ld      hl,8000h
        jr      nc,.even
        ld      hl,8000h+LEVEL_LEN
.even:  add     a,BANK_LEVELS
        ld      b,a
        SLOTS   3,vA8C12                ; cartucho en la pagina 1 para llegar al mapper
        ld      a,b
        ld      (7000h),a               ; banco del nivel en 8000-BFFF
        SLOTS   2,vA8C2                ; pagina 1 = RAM (destino), pagina 2 = cartucho
        ld      b,d
        ld      c,e
        push    ix
        pop     de
        ldir
        push    de
        pop     ix
        ld      d,b                     ; DE = 0 (BC = 0 tras LDIR)
        ld      e,b
        SLOTS   0,vA8Ram
        ifdef   V9990
        call    V9_LoadSheet            ; conserva DE e IX
        endif
.done:  ld      a,9                     ; como TapeLoader: motor parado (PPI, bit 4 de C a 1)
        out     (0ABh),a
        ifndef  V9990
        xor     a                       ; ... y R#7 = 0
        out     (99h),a
        ld      a,87h
        out     (99h),a
        endif
        xor     a
        scf
        ret

; Final del arranque. Entrada: pagina 0 = RAM (3300-3FFF ya copiados), pagina 1 =
; cartucho, pagina 2 = RAM, pagina 3 = RAM; interrupciones deshabilitadas.
; Deja la memoria como el cargador de cinta al saltar a Start: imagen completa,
; pantalla de carga volcada al TMS9918 (VDP_DumpScreen, como Tape_Boot), R#7 = 0,
; motor parado y SP = 3300h.
Boot2:
        ld      sp,3300h
        SLOTS   3,vA8C12
        ld      a,BANK_P1
        ld      (7000h),a
        SLOTS   2,vA8C2                ; pagina 1 = RAM, pagina 2 = cartucho (banco 1)
        ld      hl,8000h
        ld      de,4000h
        ld      bc,4000h
        ldir
        SLOTS   3,vA8C12
        ld      a,BANK_P3
        ld      (7000h),a
        ld      hl,8000h
        ld      de,0C000h
        ld      bc,3FFFh                ; hasta FFFE: FFFF no esta en la imagen
        ldir
        ld      a,BANK_P2
        ld      (6000h),a               ; banco 2 en 4000-7FFF
        SLOTS   1,vA8C1                ; pagina 2 = RAM
        ld      hl,4000h
        ld      de,8000h
        ld      bc,4000h
        ldir
        ifdef   V9990
        ld      a,BANK_V9
        ld      (6000h),a               ; tablas del V9990 en 4000-7FFF (pagina 1 = cartucho)
        call    V9_Init
        SLOTS   0,vA8Ram                ; todo RAM
        ld      a,9
        out     (0ABh),a
        else
        SLOTS   0,vA8Ram                ; todo RAM
        call    VDP_DumpScreen          ; pantalla de carga -> VRAM
        ld      a,9
        out     (0ABh),a
        xor     a
        out     (99h),a
        ld      a,87h
        out     (99h),a
        endif
        ; Registros como los deja el cargador de cinta al saltar a Start (medidos en un
        ; Sony HB-10P con el replay de la cinta). El juego no depende de ellos, pero
        ; Init apila algunos: asi la memoria evoluciona byte a byte igual que con la cinta.
        ld      bc,0FFFFh
        ld      d,b
        ld      e,c
        ld      h,b
        ld      l,c
        push    bc
        pop     ix
        push    bc
        pop     iy
        exx                             ; BC' = DE' = HL' = IX = IY = FFFF
        ld      hl,0954h
        push    hl
        pop     af
        ex      af,af'                  ; AF' = 0954
        ld      hl,0A882h
        push    hl
        pop     af                      ; AF = A882
        ld      bc,0A8A8h
        ld      de,0
        ld      hl,3F3Ch
        jp      Start
        ds      3500h-$,0FFh            ; relleno hasta Start
