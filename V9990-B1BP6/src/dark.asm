; dark.asm -- pantalla en negro mientras se prepara la siguiente.
;
; Subir una imagen a la VRAM tarda decenas de ms con las interrupciones fuera, y lo que el original
; dibuja entre pantallas se veria a medias (marcador viejo, luces sin color, cuadros cortados). Asi que
; la paleta se pone a negro, al principio de un retrazado para no dejar un cuadro a medias, y se
; devuelve cuando la pantalla nueva esta lista; mientras tanto el sonido calla. V9_LoadSheetA hace lo
; mismo por su cuenta con cada subida (salvo que todo el cambio ya este en negro: vV9Dark).
;
; En la ROM normal va en el codigo muerto de la redefinicion de teclas del original (35CE-370B:
; Kbd_RedefineKeys, sus tablas y sus variables; solo la llama el menu de arranque, que la ROM normal no
; tiene). La ROM de pruebas conserva ese menu: alli V9_Dark y V9_Lit no hacen nada.
        if ORIG_INPUT = 0
        code ! 35CEh
; Espera al principio del siguiente retrazado vertical (V9990).
V9_RetWait:
.a:     in      a,(65h)
        and     40h
        jr      nz,.a
.b:     in      a,(65h)
        and     40h
        jr      z,.b
        ret
; Colores a negro / de vuelta (siempre al principio de un retrazado, con las interrupciones fuera
; porque la de retrazado tambien escribe la paleta). Dejan las interrupciones como estaban.
V9_PalBlack:
        call    V9_RetWait
        ld      a,14
        out     (64h),a
        xor     a
        out     (63h),a
        ld      b,192
.b:     out     (61h),a
        djnz    .b
        ret
V9_PalBack:
        call    V9_RetWait
        call    V9_PalLoad              ; los colores 0-47; las sirenas (48-63) las pone la interrupcion pendiente
        ld      hl,vV9PalPend
        set     0,(hl)
        ret
; Todo el cambio de pantalla en negro y sin sonido (hasta V9_Lit). Destruyen A, B y HL.
V9_Dark:
        ld      a,(vV9Dark)
        or      a
        ret     nz
        ld      a,i
        push    af
        di
        call    V9_PalBlack
        ld      a,1
        ld      (vV9Dark),a
        ld      (VGM_MUTE),a
        jr      V9_Ints
V9_Lit:
        ld      a,(vV9Dark)
        or      a
        ret     z
        ld      a,i
        push    af
        di
        call    V9_PalBack
        xor     a
        ld      (vV9Dark),a
        ld      (VGM_MUTE),a
V9_Ints:
        pop     af
        ret     po
        ei
        ret
; Arranque (V9_Init): en negro y sin sonido desde el principio, asi las hojas que sube no encienden
; nada entre una y otra; la portada lo enciende todo cuando esta completa (V9_Lit en V9_TitleLoop).
V9_InitDark:
        call    V9_PalBlack
        ld      a,1
        ld      (vV9Dark),a
        ld      (VGM_MUTE),a
        ret
V9_DarkEnd:
        else
        code ! V9_PicEnd                ; (la ROM de pruebas: en el cuerpo de VDP_CopyColors, que la portada no usa)
V9_Dark:
V9_Lit:
        ret
V9_InitDark:                            ; (la ROM de pruebas no se pone en negro: carga la paleta y ya,
        xor     a                       ; al principio de un retrazado)
        ld      (vV9Dark),a
        ld      (VGM_MUTE),a
.a:     in      a,(65h)
        and     40h
        jr      nz,.a
.b:     in      a,(65h)
        and     40h
        jr      z,.b
        jp      V9_PalLoad
V9_LoadSheetC:                          ; (como en src/v9.asm, ROM normal)
        call    V9_LoadSheetA
        ld      a,SLOT_C1
        call    SlotSet
        ret
V9_DarkEnd:
        endif
