; rom.asm -- MegaROM ASCII16 del port V9990 (B1/BP6) de Chase H.Q.
;
; Misma estructura que la MegaROM MSX1 (MSX/rom/rom.asm, docs/14_megarom.md), con:
;   - la imagen parcheada del port (build/port.bin) en vez de la original;
;   - la pagina 0 del port (codigo del V9990) copiada a RAM;
;   - el puente en su variante V9990 (no toca el TMS9918 y llama a V9_Init);
;   - el TMS9918 apagado al arrancar: pantalla e interrupcion desactivadas. Es la unica
;     escritura al TMS; el juego no vuelve a tocarlo.
;
; Bancos (16K): 0 arranque + pagina 0 | 1-3 imagen 4000-FFFE | 4-6 niveles | 7 tiras de
; carretera | 8-25 hoja comun y hojas de los niveles (build/sheets_rom.inc) | 26 panel del
; marcador | 27-30 logo de arranque | 32-45 portada | 46 digitos del marcador | 47 letras de la
; portada del juego | 48-52 montanas | 53- sonido. 1 MB.
;
; Requisitos: 64K de RAM y un V9990 (GFX9000) en los puertos 60h-6Fh. Al arrancar (Boot) se
; comprueba que el V9990 contesta; si no, se queda parado con "V9990 NOT found!!!".

        output  "../build/chasehq_v9990.rom"
        defpage 0,4000h,4000h
        defpage 1..63,4000h,4000h

MSXVER  equ     002Dh                   ; version de MSX: 3 = turbo R
CHGCPU  equ     0180h                   ; (turbo R) cambia de CPU: A = 81h R800 con la BIOS en ROM
        include "../build/config.inc"   ; ORIG_INPUT
ENASLT  equ     0024h
WRTVDP  equ     0047h
INITXT  equ     006Ch
CHGET   equ     009Fh
CHPUT   equ     00A2h
CHGCLR  equ     0062h
ENASCR  equ     0044h
LINL40  equ     0F3AEh
FORCLR  equ     0F3E9h
BAKCLR  equ     0F3EAh
BDRCLR  equ     0F3EBh
RG1SAV  equ     0F3E0h
EXPTBL  equ     0FCC1h

BRIDGE          equ 3400h
vA8Ram          equ 3403h
V9_TURBO        equ 13A1h               ; (v9.asm) turbo R: VI minimos entre dos presentaciones
V9_CHEAT        equ 13A3h               ; (v9.asm) <> 0: turbos infinitos
CHEAT_TMP       equ 0C000h              ; F1 al salir de la portada (pagina 3: la RAM del juego aun no esta)
LOGO_PTR        equ 0C001h              ; (Intro) musica del logo: siguiente orden (0 = acabada)
V9_TURBOFR      equ 4                   ; 15 cuadros por segundo como maximo
vA8C1           equ 3404h
vA8C2           equ 3405h
vA8C12          equ 3406h
vSlotCur        equ 33ABh               ; (v9.asm, SlotSet) cambio de slots por subslot tambien
vSSFlag         equ 33ACh
vA8P3           equ 33ADh
TSS             equ 33AEh
Boot2Vec        equ 3407h
RAMFIND         equ 8500h
P0_LO           equ 0038h               ; zona de la pagina 0 que usa el port (0000-00FF la pisa el original)
P0_LEN          equ 2000h-P0_LO         ; (hasta 1FFFh; ampliar si v9.asm crece)

        page    0
        code @ 4000h
        db      "AB"
        dw      Init
        dw      0,0,0
        ds      6

Init:
        if ORIG_INPUT = 0               ; (la ROM de pruebas arranca directa: sus partidas grabadas van a tiempo)
        call    Boot                    ; creditos y "V9990 found" en SCREEN 0, con la BIOS
        endif
        ; TMS9918: pantalla e interrupcion apagadas (R#1 bits 6 y 5 a 0)
        ld      a,(RG1SAV)
        and     9Fh
        ld      b,a
        ld      c,1
        call    WRTVDP
        ; MSX turbo R: CPU R800 (modo ROM; el juego no usa la BIOS)
        ld      a,(MSXVER)
        cp      3
        jr      c,.z80
        ld      a,81h
        call    CHGCPU
.z80:   di
        ; cartucho tambien en la pagina 2 (ver MSX/rom/rom.asm)
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
        inc     hl
        ld      a,(hl)
        and     0Ch
        or      c
        ld      h,80h
        call    ENASLT
        di
        if ORIG_INPUT = 0               ; (la ROM de pruebas arranca directa: nadie pulsa teclas)
        call    Intro                   ; logo y portada (con el cartucho en las paginas 1 y 2)
        endif
        in      a,(0A8h)
        push    af
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
        jp      c,.noram
        ld      b,0
        call    FindRAM
        jp      c,.noram
        ld      hl,RamFindBin
        ld      de,RAMFIND
        ld      bc,RamFindEnd-RamFindBin
        ldir
        call    RAMFIND
        jp      c,.noram
        pop     af
        push    hl
        ld      hl,ImgP0                ; pagina 0 del port: codigo del V9990
        ld      de,P0_LO
        ld      bc,P0_LEN
        ldir
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
        push    hl                      ; R800 (turbo R): es mucho mas rapido que el Z80 y se frena el
        ld      hl,0                    ; juego. MULUB A,B (ED C1) es un NOP en el Z80: HL sigue en 0
        ld      a,V9_TURBOFR
        ld      b,1
        db      0EDh,0C1h
        ld      a,l
        ld      (V9_TURBO),a            ; VI minimos entre dos presentaciones (0 = sin limite)
        if ORIG_INPUT = 0
        ld      a,(CHEAT_TMP)           ; truco de la portada (Intro)
        ld      (V9_CHEAT),a
        endif
        pop     hl
        ld      a,l
        ld      (vA8Ram),a
        in      a,(0A8h)
        ld      (vA8C1),a
        and     0Ch
        ld      b,a
        add     a,a
        add     a,a
        ld      c,a
        ld      a,l
        and     0CFh
        or      c
        ld      (vA8C2),a
        and     0F3h
        or      b
        ld      (vA8C12),a
        ; subslots (SlotSet, src/v9.asm): si el primario del cartucho (P) esta expandido, el registro de
        ; subslots de P para cada configuracion. H (de RAMFIND) = 80h | subslot si la RAM de la pagina 1
        ; esta en un subslot de P; la de las paginas 0 y 2, si lo esta, ya la dejo FindRAM en ese registro.
        ld      a,(vA8C1)
        and     0Ch
        rrca
        rrca
        ld      c,a                     ; C = P
        ld      b,0
        push    hl
        ld      hl,EXPTBL
        add     hl,bc
        ld      a,(hl)
        pop     hl
        and     80h
        ld      (vSSFlag),a
        jr      z,.slots
        ld      a,c
        rrca
        rrca                            ; P en el campo de la pagina 3
        ld      b,a
        ld      a,l
        and     3Fh
        or      b
        ld      (vA8P3),a               ; (para SlotSet) todo RAM salvo la pagina 3, en P
        ld      a,(vA8C1)               ; aqui, con el cartucho en la pagina 1: este codigo esta en el
        and     3Fh
        or      b
        out     (0A8h),a                ; (sin pila): F = registro de subslots de P
        ld      a,(0FFFFh)
        cpl
        ld      e,a                     ; E = F: pagina 1 = cartucho; 0 y 2 = su RAM si esta en P
        ld      a,(vA8C1)
        out     (0A8h),a
        ld      a,e
        and     0Ch
        add     a,a
        add     a,a
        ld      d,a                     ; D = subslot del cartucho, en el campo de la pagina 2
        ld      a,e
        ld      (TSS+1),a               ; cartucho en la pagina 1
        and     0CFh
        or      d
        ld      (TSS+3),a               ; cartucho en las dos
        ld      a,e
        bit     7,h
        jr      z,.r1
        and     0F3h                    ; RAM de la pagina 1 en un subslot de P
        ld      c,a
        ld      a,h
        and     3
        add     a,a
        add     a,a
        or      c
.r1:    ld      (TSS),a                 ; todo RAM
        and     0CFh
        or      d
        ld      (TSS+2),a               ; cartucho en la pagina 2
.slots: jp      Boot2Vec

.noram: pop     af
        out     (0A8h),a
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
.msg:   db      "CHASE H.Q. V9990 needs 64K RAM",13,10,0

; ------------------------------------------------------------ arranque: creditos y V9990
; Como en el port de Sol Negro: en SCREEN 0 (la unica vez que se usa el TMS9918, antes de apagarlo),
; la empresa y el ano del original y los de DiHalt, medio segundo para que se asiente el V7040 del
; GFX9000 (sin superposicion), y la sonda del V9990: dos bytes escritos en su VRAM que vuelven iguales.
; Con V9990, "V9990 found !" durante 1,4 s; sin el, "V9990 NOT found!!!" y se queda parado.
Boot:   di
        xor     a
        out     (6Fh),a                 ; V7040: sin superposicion (el manual pide esperar un cuadro)
        ld      a,40
        ld      (LINL40),a
        ld      a,15
        ld      (FORCLR),a              ; blanco sobre azul oscuro
        ld      a,4
        ld      (BAKCLR),a
        ld      (BDRCLR),a
        call    INITXT
        call    CHGCLR
        call    ENASCR
        ld      hl,.credits
        call    .print
        ld      de,0                    ; ~0,5 s
.settle:dec     de
        ld      a,d
        or      e
        jr      nz,.settle
        ld      a,2                     ; reinicio del V9990
        out     (67h),a
        xor     a
        out     (67h),a
        call    .probe
        jr      nc,.missing
        ld      hl,.found
        call    .print
        ld      b,3                     ; ~1,4 s para leerlo
.pause: ld      de,0
.tick:  dec     de
        ld      a,d
        or      e
        jr      nz,.tick
        djnz    .pause
        ret
.missing:
        ld      hl,.notfound
        call    .print
.halt:  jr      .halt
.print: ld      a,(hl)
        or      a
        ret     z
        call    CHPUT
        inc     hl
        jr      .print
; CF si contesta un V9990: dos bytes a su VRAM (puntero de escritura 0) y de vuelta (puntero de lectura 0)
.probe: xor     a
        out     (64h),a
        out     (63h),a
        out     (63h),a
        out     (63h),a
        ld      a,0A5h
        out     (60h),a
        ld      a,5Ah
        out     (60h),a
        ld      a,3
        out     (64h),a
        xor     a
        out     (63h),a
        out     (63h),a
        out     (63h),a
        in      a,(60h)
        cp      0A5h
        jr      nz,.no
        in      a,(60h)
        cp      5Ah
        jr      nz,.no
        scf
        ret
.no:    or      a
        ret
.credits:
        db      "OCEAN SOFTWARE 1989",13,10,"DIHALT STUDIO 2026",13,10,13,10,0
.found: db      "V9990 found !",0
.notfound:
        db      "V9990 NOT found!!!",0

        include "../../MSX/rom/findram.inc"

; ------------------------------------------------------------ pantallas de arranque
; Logo (lo que dura su musica, no se puede saltar) y portada (hasta que se pulse una tecla o un boton
; del joystick). Las dos en BD8 (color directo RGB332): el logo en B1 (256x212) y la
; portada en B3 (512x424 entrelazado). Los datos estan en bancos de ROM que se van poniendo
; en 8000-BFFF (registro 7000h del mapper); el codigo corre en 4000-7FFF. Sin BIOS.
; Al aparecer el logo empieza su musica (assets/editable/sound/logo.vgm, en el formato de las
; pistas de src/sound.asm, sin bucle): un paso por retrazado; el logo se quita al acabar.
BANK_LOGO       equ 27                  ; 4 bancos (build/logo.bin)
BANK_OPENING    equ 32                  ; 14 bancos (build/opening.bin)
Intro:  ld      hl,.b1
        call    .mode
        ld      a,31                    ; borde = color 0 de la paleta: blanco, como el fondo del logo
        call    .border
        ld      a,BANK_LOGO
        ld      de,212                  ; 256 x 212 bytes
        call    .upload
        ld      a,82h
        call    .disp
        ld      hl,LogoMusic
        ld      (LOGO_PTR),hl
.sec:   call    .frame                  ; un frame de 50 Hz por paso, hasta el fin de la pista
        call    .tick
        ld      a,(LOGO_PTR+1)
        or      a
        jr      nz,.sec
        ld      hl,.b3
        call    .mode
        xor     a
        call    .border
        ld      a,BANK_OPENING
        ld      de,848                  ; 512 x 424 bytes
        call    .upload
        ld      a,82h
        call    .disp
.rel0:  call    .keys                   ; que no venga ya pulsada
        jr      nz,.rel0
.press: call    .keys
        jr      z,.press
        in      a,(0AAh)                ; truco: con F1 pulsada al dar la tecla o el boton, turbos
        and     0F0h                    ; infinitos en todas las partidas (V9_TurboDec)
        or      6                       ; fila 6 del teclado: F1 es el bit 5
        out     (0AAh),a
        in      a,(0A9h)
        cpl
        and     20h
        ld      (CHEAT_TMP),a
.rel1:  call    .keys                   ; y que la suelten, para que no llegue al juego
        jr      nz,.rel1
        ld      a,2
.disp:  push    af                      ; R#8 = A (82h pantalla encendida, 02h apagada)
        ld      a,8
        out     (64h),a
        pop     af
        out     (63h),a
        ret
; Reinicia el V9990 y pone los registros de la lista HL (registro, valor; FFh = fin), con
; la pantalla apagada y el puntero de escritura de VRAM a 0.
.mode:  ld      a,2
        out     (67h),a
        xor     a
        out     (67h),a
.reg:   ld      a,(hl)
        inc     hl
        cp      0FFh
        jr      z,.ptr
        out     (64h),a
        ld      a,(hl)
        inc     hl
        out     (63h),a
        jr      .reg
.ptr:   xor     a
        out     (64h),a
        out     (63h),a
        out     (63h),a
        out     (63h),a
        ret
.border:
        push    af                      ; color 0 de la paleta = gris de nivel A (0-31)
.bw:    in      a,(65h)                 ; (al principio de un retrazado, como toda escritura de paleta)
        and     40h
        jr      nz,.bw
.bv:    in      a,(65h)
        and     40h
        jr      z,.bv
        ld      a,14
        out     (64h),a
        xor     a
        out     (63h),a
        pop     af
        out     (61h),a
        out     (61h),a
        out     (61h),a
        ret
; Sube DE bloques de 256 bytes a la VRAM desde el banco A en adelante.
.upload:
        ld      (7000h),a
        inc     a
        push    af
        ld      hl,8000h
        ld      c,60h
.blk:   ld      b,0
        otir
        dec     de
        ld      a,d
        or      e
        jr      z,.updone
        ld      a,h
        cp      0C0h
        jr      nz,.blk
        pop     af
        jr      .upload
.updone:
        pop     af
        ret
; Un frame de la musica del logo: ordenes hasta la siguiente espera (63) o el fin (66, que
; calla el PSG y deja LOGO_PTR a 0).
.tick:  ld      hl,(LOGO_PTR)
.tkc:   ld      a,(hl)
        inc     hl
        cp      0A0h
        jr      nz,.tke
        ld      a,(hl)                  ; A0 rr dd
        inc     hl
        out     (0A0h),a
        cp      7
        ld      a,(hl)
        inc     hl
        jr      nz,.tkw
        and     3Fh                     ; R7: puerto A de entrada y B de salida (la palanca)
        or      80h
.tkw:   out     (0A1h),a
        jr      .tkc
.tke:   cp      63h
        jr      z,.tks
        ld      hl,0                    ; 66: fin
        ld      a,8                     ; volumenes a 0
.mt:    out     (0A0h),a
        push    af
        xor     a
        out     (0A1h),a
        pop     af
        inc     a
        cp      11
        jr      nz,.mt
.tks:   ld      (LOGO_PTR),hl
        ret
.frame: in      a,(65h)                 ; espera un frame entero (retrazado vertical del V9990)
        and     40h
        jr      nz,.frame
.fr2:   in      a,(65h)
        and     40h
        jr      z,.fr2
        ret
; NZ si hay alguna tecla o algun boton de joystick pulsado. F1 sola no cuenta: es la del truco.
.keys:  ld      b,11
.row:   in      a,(0AAh)
        and     0F0h
        or      b
        dec     a
        out     (0AAh),a
        in      a,(0A9h)
        cpl
        ld      c,a
        ld      a,b
        cp      7                       ; fila 6
        ld      a,c
        jr      nz,.nf1
        and     0DFh
.nf1:   or      a
        ret     nz
        djnz    .row
        ld      a,15
        out     (0A0h),a
        in      a,(0A2h)
        and     0BFh                    ; joystick 1
        out     (0A1h),a
        call    .trig
        ret     nz
        ld      a,15
        out     (0A0h),a
        in      a,(0A2h)
        or      40h                     ; joystick 2
        out     (0A1h),a
.trig:  ld      a,14
        out     (0A0h),a
        in      a,(0A2h)
        cpl
        and     30h
        ret
.b1:    db      6,82h                   ; B1, espacio de imagen de 256 px, 8 bpp
        db      7,08h                   ; PAL
        db      8,02h                   ; pantalla apagada
        db      9,0
        db      13,40h                  ; BD8
        db      15,0
        db      0FFh
.b3:    db      6,96h                   ; B3, 512 px, 8 bpp
        db      7,0Eh                   ; PAL, entrelazado con campos distintos: 424 lineas
        db      8,02h
        db      9,0
        db      13,40h
        db      15,0
        db      0FFh

RamFindBin:
        incbin  "../../MSX/build/ramfind.bin"
RamFindEnd:
BridgeBin:
        incbin  "../build/bridge_v9.bin"
ImgP0:  incbin  "../build/port.bin",P0_LO,P0_LEN
Img3300:
        incbin  "../build/port.bin",3300h,0E0h   ; bordes de carretera y SlotSet (33AB-33DF)
Img3300End:
Img3500:
        incbin  "../build/port.bin",3500h,0B00h
LogoMusic:
        incbin  "../build/sound_logo.bin" ; musica del logo (Intro), tools/mksound.py
        assert  $ <= 8000h              ; (el banco 0 acaba en 7FFFh)

        page    1
        code @ 4000h
        incbin  "../build/port.bin",4000h,4000h
        page    2
        code @ 4000h
        incbin  "../build/port.bin",8000h,4000h
        page    3
        code @ 4000h
        incbin  "../build/port.bin",0C000h,3FFFh
        db      0FFh
        page    4
        code @ 4000h
        ; niveles 1-5: bloques de la cinta con los descriptores de sprite convertidos
        incbin  "../build/level1_v9.bin"
        incbin  "../build/level2_v9.bin"
        page    5
        code @ 4000h
        incbin  "../build/level3_v9.bin"
        incbin  "../build/level4_v9.bin"
        page    6
        code @ 4000h
        incbin  "../build/level5_v9.bin"
        incbin  "../build/level6_v9.bin"  ; nivel 6 (final), parcheado para el port (tools/mkending.py)
        page    7
        code @ 4000h
        incbin  "../build/strips.bin"
        include "../build/sheets_rom.inc"
        page    26
        code @ 4000h
        incbin  "../build/hud.bin"       ; panel del marcador, 256x64 a 8 bpp (tools/mkhud.py)
        include "../build/intro_rom.inc" ; logo (bancos 27-30) y portada (32-45), tools/mkintro.py
        page    46
        code @ 4000h
        incbin  "../build/digits.bin"    ; digitos del marcador, 256x60 (tools/mkdigits.py)
        page    47
        code @ 4000h
        incbin  "../build/titlefont.bin" ; letras de la portada, 256x24 (tools/mktitle.py)
        include "../build/menubg_rom.inc" ; fondo de la portada (bancos 55-57), tools/mkmenubg.py
        page    58
        code @ 4000h
        incbin  "../build/monitor.bin",0,16384   ; imagen del monitor del aviso de nivel (58-59), tools/mkmonitor.py
        page    59
        code @ 4000h
        incbin  "../build/monitor.bin",16384,16384
        page    31
        code @ 4000h
        incbin  "../build/radio.bin"     ; caras y letras de la radio, 256x60 (tools/mkradio.py)
        include "../build/mountains_rom.inc" ; montanas de los niveles (bancos 48-52), tools/mkmountains.py
        include "../build/sound_rom.inc" ; pistas de sonido (bancos 53-), tools/mksound.py
        page    60
        code @ 4000h
        incbin  "../build/ending_img.bin",0,16384       ; fotos y manos de la secuencia final (60-63),
        page    61                                      ; tools/mkending.py
        code @ 4000h
        incbin  "../build/ending_img.bin",16384,16384
        page    62
        code @ 4000h
        incbin  "../build/ending_img.bin",32768,16384
        page    63
        code @ 4000h
        incbin  "../build/ending_img.bin",49152
        ds      3000h,0FFh
