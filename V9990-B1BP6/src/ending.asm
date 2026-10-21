; ending.asm -- la secuencia final (bloque del nivel 6) en el port.
;
; El bloque del nivel 6 es el del Spectrum sin tocar (docs/10_nivel.md): un guion (5E0A) que pinta cuatro
; fotos y el apreton de manos en la pantalla Spectrum (4000), con fundidos de sus atributos (5900) hacia los
; que deja en F000, escribe los textos, habla por la radio (Radio_Say / Radio_Update) y suma los 5.000.000
; al marcador; va a un frame por tic de su propia interrupcion (tabla IM 2 en 73D1) y toca musica por el
; altavoz del Spectrum (73EF, copiado a F300, OUT (FE)). Nada de eso vale aqui: el V9990 pide que se acuse
; su interrupcion, OUT (FE) en un MSX2 con mapper cambia la pagina 2, y los fundidos de atributos pasan por
; rojo, magenta y cian.
;
; tools/mkending.py parchea el bloque (build/level6_v9.bin): fuera la copia a F300, la tabla IM 2 y el
; beeper, y las ordenes del guion que pintan o funden pasan por estas rutinas, que van en el sitio de las
; fotos, las manos y el reproductor (60E1-76EE, ya sin uso: las imagenes vienen de la ROM). Entradas (tabla
; de saltos en 60E1):
;   5C1E  V9_EndInit      musica, hoja 17 a la VRAM, los 4 tonos oscuros de cada imagen y pantalla encendida
;   5C26  V9_EndFrame     un frame: espera al retrazado y manda al V9990 las celdas cambiadas de la ventana
;                         (el bucle del guion vuelve a 5C26)
;   5C64  V9_EndExit      pantalla en negro y las tiras de carretera repintadas; sigue Radio_Stop y la vuelta
;                         a la portada (Lvl_Play recarga el nivel 1)
;   5E17  V9_EndFadeIn    orden 3: fundido de entrada (16 frames)
;   5E20  V9_EndFadeOut   orden 4: fundido de salida (16)
;   5E27  V9_EndFadeAnim  orden 5: fundido de salida de las fotos con las manos moviendose (16)
;   5E30  V9_EndFadeSlow  orden 6: fundido de salida lento (32)
;   5EC3  V9_EndHands     ordenes 8/9: las manos, un fotograma cada 4 frames
;   5EDA  V9_EndClear     orden 1: fotos fuera (el original borra los atributos destino)
;   5EE8  V9_EndPlace     ordenes 1/2: colocar una foto (el original la pintaba en negro sobre negro)
;   5EF1  V9_EndClearWin  orden 0B: ventana borrada antes de un texto
;   5F0E  V9_EndChar      una letra de un texto: con la fuente de la portada (y DIHALT STUDIO 2026 bajo Taito)
; Los textos van con la fuente de la portada (title_font.png, hoja 14, con 4 tonos suyos en la ventana B); el
; marcador (los 5.000.000: Hud_BigDigit) y la radio van por el V9990 con los ganchos del port (vV9Race a 1).
;
; Imagenes (assets/editable/ending/, tools/mkending.py): las 4 fotos de 104x64 y los 6 fotogramas de las
; manos de 64x40 van en la hoja 17 (4 bancos de ROM), que V9_EndInit sube a la zona de las tiras de
; carretera: y 468-595 las fotos (dos por fila, x 0-103 y 104-207) y 596-675 las manos (cuatro por fila).
; Luego V9_EndGen hace alli los 4 tonos oscuros (20, 40, 60 y 80 %) de las fotos y del primer fotograma de
; las manos, byte a byte por las tablas de build/ending_tones.inc (lee la VRAM por su puerto y la vuelve a
; escribir). Un fundido son 5 pasos de 3 frames (6 en el lento): tono 1 (el mas oscuro) a 5 (la imagen), o al
; reves hasta el negro; cada paso, una copia por foto colocada. Las tiras se repintan al salir (V9_StripsUp).
;
; Celdas: como V9_CellN (resumen de los 8 bytes + atributo en V9_CACHE; CMMC con tinta y papel de la
; paleta 32-47), pero solo a la pagina A, que es la que se ve, y mirando un cuarto de la ventana en cada
; frame (4 filas de celdas): repasar las 512 celdas lleva mas de un frame de Z80.
        include "../build/ending_syms.inc"      ; direcciones del port (de build/port.lst)
        output  "../build/ending.bin"

; el bloque original
ZX_FadeIn       equ 602Eh               ; un paso del fundido de atributos hacia los destino (frames alternos)
ZX_FadeOut      equ 6072h               ; un paso hacia el negro (frames alternos)
ZX_FadeSlow     equ 606Dh               ; lo mismo, uno de cada cuatro frames
ZX_ClearTargets equ 609Ch               ; atributos destino (F000-F1FF) a 0
ZX_ClearWin     equ 6099h               ; Scr_ClearWindow y lo anterior
ZX_Flag2        equ 5C6Dh               ; byte que rota ZX_FadeSlow y la animacion de las manos (88h)
vEndCnt         equ 0A170h              ; frames que quedan de la orden
vEndAnim        equ 0A172h              ; fotograma de las manos (0-5)

SHEET_END       equ 17                  ; hoja de las imagenes del final (build/ending_img.bin)
SHEET_Y         equ 468                 ; donde se sube (zona de las tiras: x 0-255)
PHOTO_W         equ 104
PHOTO_H         equ 64
HAND_W          equ 64
HAND_H          equ 40
HANDS_Y         equ SHEET_Y+2*PHOTO_H   ; fotogramas de las manos: (f&3)*64, HANDS_Y + (f>>2)*40
HANDS_DX        equ 96                  ; donde se ven (celda 12, fila 13 de la pantalla Spectrum)
HANDS_DY        equ 104
WIN_Y           equ 64                  ; ventana A: x 0-255, y 64-191
WIN_H           equ 128
TONES           equ 4
FONT_Y          equ 443                 ; letras de la portada (title_font.png, hoja 14): x 0-255, y 443-466
TXT_MAX         equ 80                  ; letras en pantalla a la vez

        code @ 60E1h
        jp      V9_EndInit              ; +0
        jp      V9_EndFrame             ; +3
        jp      V9_EndExit              ; +6
        jp      V9_EndFadeIn            ; +9
        jp      V9_EndFadeOut           ; +12
        jp      V9_EndFadeAnim          ; +15
        jp      V9_EndFadeSlow          ; +18
        jp      V9_EndHands             ; +21
        jp      V9_EndClear             ; +24
        jp      V9_EndPlace             ; +27
        jp      V9_EndClearWin          ; +30
        jp      V9_EndChar              ; +33

; Donde esta cada tono de las fotos (bloque de 2x2 fotos, 208x128): X, Y del tono 1 (el mas oscuro) al 5
; (la hoja). Los 4 tonos se generan en la mitad derecha (x 256-511) y debajo de las manos.
TEndTone:
        dw      0,SHEET_Y+208           ; tono 1 (y 676-803)
        dw      256,SHEET_Y             ; tono 2 (y 468-595)
        dw      256,SHEET_Y+128         ; tono 3
        dw      256,SHEET_Y+256         ; tono 4 (y 724-851)
        dw      0,SHEET_Y               ; tono 5: la hoja
; Los tonos del primer fotograma de las manos (64x40), 1 a 4
TEndHand:
        dw      128,HANDS_Y+HAND_H      ; (al lado de los fotogramas 4 y 5)
        dw      192,HANDS_Y+HAND_H
        dw      256,SHEET_Y+384         ; (y 852-891, bajo el tono 4)
        dw      320,SHEET_Y+384
; Fotos colocadas: hasta 4 (x, y, foto, tono) y las manos (la quinta)
TEndSlot:
        ds      16,0
        db      HANDS_DX,HANDS_DY,4,0
vEndSlots:      db      0               ; fotos colocadas
vEndHands:      db      0               ; <> 0: las manos estan en pantalla
vEndHalf:       db      0               ; cuarto de la ventana que toca repasar
; Los 4 tonos de la fuente (256x24 cada uno), en la ventana B
TEndFont:
        dw      256,WIN_Y
        dw      256,WIN_Y+24
        dw      256,WIN_Y+48
        dw      256,WIN_Y+72
; Letras en pantalla (columna, y, letra, tono)
TEndTxt:        ds      TXT_MAX*4,0
vEndTxtN:       db      0
TEndDihalt:     db      "DIHALT STUDIO 2026",0

; ------------------------------------------------------------ arranque, frame y salida
V9_EndInit:
        call    V9_Dark                 ; (ya lo esta si se viene del fundido del nivel 5)
        ld      a,SHEET_END
        call    V9_LoadSheetA           ; las imagenes, de la ROM
        call    V9_EndGen               ; sus tonos oscuros
        ld      a,SND_TITULO            ; (empieza cuando V9_Lit quite el silencio)
        call    V9_SndPlay
        xor     a
        ld      (vV9Mon),a
        ld      (vShowHi),a             ; se ve la pagina A (el marcador solo esta en ella)
        ld      (vV9FlipPend),a
        ld      (vEndHalf),a
        ld      (vEndSlots),a
        ld      (vEndHands),a
        ld      (vEndTxtN),a
        inc     a
        ld      (vV9Race),a             ; radio y marcador por el V9990
        ld      hl,V9_CACHE+512         ; las celdas de la ventana, todas por mandar
        ld      de,V9_CACHE+513
        ld      bc,1023
        ld      (hl),0FFh
        ldir
        ld      b,4                     ; (el guion la ha borrado: negra)
.dump:  push    bc
        call    V9_EndDump
        pop     bc
        djnz    .dump
        jp      V9_Lit

V9_EndFrame:
        call    V9_IntOn
.a:     in      a,(65h)                 ; principio del siguiente retrazado
        and     40h
        jr      nz,.a
.b:     in      a,(65h)
        and     40h
        jr      z,.b
V9_EndDump:
        ld      hl,vEndHalf             ; un cuarto de la ventana por frame (4 filas de celdas)
        ld      a,(hl)
        inc     a
        and     3
        ld      (hl),a
        rrca                            ; B = tercio (1 o 2), C = primera celda (0 o 128)
        and     1
        inc     a
        ld      b,a
        ld      a,(hl)
        rrca
        and     80h
        ld      c,a
        ld      a,128
.cell:  push    af
        push    bc
        call    V9_EndCell
        pop     bc
        pop     af
        inc     c
        dec     a
        jr      nz,.cell
        ret

V9_EndExit:
        call    V9_Dark
        jp      V9_StripsUp             ; las tiras de carretera, donde estaban las imagenes

; ------------------------------------------------------------ el guion: fotos y fundidos
; Orden 1/2: una foto. HL = sus datos en el bloque (60E1, 6489, 6831 o 6BD9: la foto 0-3), DE = donde
; (direccion de la pantalla Spectrum). Solo se anota: la foto esta en negro hasta su fundido de entrada.
V9_EndPlace:
        ld      a,h
        sub     5Fh
        rrca
        rrca
        and     3
        ld      c,a                     ; C = foto
        ld      a,e
        and     31
        add     a,a
        add     a,a
        add     a,a
        ld      b,a                     ; B = x
        ld      a,d
        and     18h
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      a,e
        and     0E0h
        rrca
        rrca
        or      l
        ld      l,a
        ld      a,d
        and     7
        or      l                       ; A = y (la de la pantalla Spectrum es la de la VRAM)
        ld      hl,vEndSlots
        ld      e,(hl)
        inc     (hl)
        ld      d,0
        ex      de,hl
        add     hl,hl
        add     hl,hl
        ld      de,TEndSlot
        add     hl,de
        ld      (hl),b
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),c
        inc     hl
        ld      (hl),0
        ret

; Orden 1: fotos fuera (y lo que hacia el original)
V9_EndClear:
        call    ZX_ClearTargets
V9_EndForget:
        xor     a
        ld      (vEndSlots),a
        ld      (vEndHands),a
        ld      (vEndTxtN),a
        ret

; Orden 0B: la ventana borrada (el original) y en negro en la VRAM: las fotos y las manos no son celdas
V9_EndClearWin:
        call    ZX_ClearWin
        call    V9_EndForget
        ld      hl,0
        ld      (vV9RegB+4),hl          ; DX
        ld      hl,WIN_Y
        ld      (vV9RegB+6),hl
        ld      hl,256
        ld      (vV9RegB+8),hl
        ld      hl,WIN_H
        ld      (vV9RegB+10),hl
        jp      V9_EndFillGo

; Paso de un fundido: A170 / B (B frames por paso). Sale con CF si en este frame toca paso, y entonces
; A = pasos que quedan (5 en el primero, 1 en el ultimo).
V9_EndStep:
        ld      a,(vEndCnt)
        ld      c,0
.d:     sub     b
        jr      c,.r
        inc     c
        jr      .d
.r:     add     a,b
        or      a
        ret     nz                      ; (sin acarreo)
        ld      a,c
        or      a
        ret     z
        scf
        ret

; Orden 3: fundido de entrada. Las fotos que estan por debajo del tono que toca suben a el.
V9_EndFadeIn:
        call    ZX_FadeIn               ; (los textos)
        ld      b,3
        call    V9_EndStep
        ret     nc
        neg
        add     a,6                     ; tono 1..5
        ld      c,a
        ld      hl,TEndSlot
        ld      a,(vEndSlots)
        or      a
        ret     z
        ld      b,a
.s:     push    bc
        push    hl
        inc     hl
        inc     hl
        inc     hl
        ld      a,(hl)
        cp      c
        pop     hl
        push    hl
        call    c,V9_EndDraw            ; (tono < C)
        pop     hl
        pop     bc
        ld      de,4
        add     hl,de
        djnz    .s
        ret

; Ordenes 4 y 6: fundido de salida (B = frames por paso): fotos y manos hacia el negro
V9_EndFadeSlow:
        call    ZX_FadeSlow
        ld      b,6
        jr      V9_EndFadeOutB
V9_EndFadeOut:
        call    ZX_FadeOut
        ld      b,3
V9_EndFadeOutB:
        call    V9_EndStep
        ret     nc
        dec     a                       ; tono 4..0
        ld      c,a
        call    V9_EndDown
        push    bc
        call    V9_EndTxtDown
        pop     bc
        ld      a,(vEndHands)
        or      a
        ret     z
        ld      hl,TEndSlot+16
        jr      V9_EndDownOne

; Orden 5: fundido de salida de las fotos mientras las manos siguen
V9_EndFadeAnim:
        call    ZX_FadeOut
        ld      b,3
        call    V9_EndStep
        jr      nc,V9_EndHands
        dec     a
        ld      c,a
        call    V9_EndDown
        ld      a,(vEndAnim)            ; las fotos han tapado el recuadro de las manos: el ultimo fotograma
        dec     a                       ; otra vez, en este mismo cuadro (si no, parpadea)
        jp      p,.f
        ld      a,5
.f:     ld      c,a
        call    V9_EndHandsDraw
        jr      V9_EndHands

; Las fotos colocadas que estan por encima del tono C bajan a el
V9_EndDown:
        ld      hl,TEndSlot
        ld      a,(vEndSlots)
        or      a
        ret     z
        ld      b,a
.s:     push    bc
        push    hl
        call    V9_EndDownOne
        pop     hl
        pop     bc
        ld      de,4
        add     hl,de
        djnz    .s
        ret
V9_EndDownOne:
        push    hl
        inc     hl
        inc     hl
        inc     hl
        ld      a,c
        cp      (hl)
        pop     hl
        jp      c,V9_EndDraw            ; (tono > C)
        ret

; Ordenes 8/9 (y la 5): las manos. Un fotograma cada 4 frames (el byte 5C6D rota, como en el original).
V9_EndHands:
        ld      hl,ZX_Flag2
        rlc     (hl)
        ret     nc
        ld      hl,vEndAnim
        ld      a,(hl)
        ld      c,a                     ; C = fotograma que toca
        inc     a
        cp      6
        jr      nz,.k
        xor     a
.k:     ld      (hl),a
; El fotograma C de las manos (64x40, con su fondo negro), entero
V9_EndHandsDraw:
        ld      a,1
        ld      (vEndHands),a
        ld      a,5
        ld      (TEndSlot+16+3),a       ; (enteras)
        ld      a,c
        and     3
        add     a,a                     ; SX = (f & 3) * 64
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      h,0
        ld      (vV9RegB),hl
        ld      hl,HANDS_Y
        ld      a,c
        cp      4
        jr      c,.y
        ld      hl,HANDS_Y+HAND_H
.y:     ld      (vV9RegB+2),hl          ; SY
        ld      hl,TEndSlot+16
        jp      V9_EndCopyAt

; Copia a la foto/manos HL (x, y, foto, tono) el tono C y lo anota. Tono 0: negro.
V9_EndDraw:
        inc     hl
        inc     hl
        inc     hl
        ld      (hl),c
        dec     hl
        dec     hl
        dec     hl
        ld      a,c
        or      a
        jp      z,V9_EndFillAt
        inc     hl
        inc     hl
        ld      a,(hl)                  ; foto 0-3, o 4 las manos
        dec     hl
        dec     hl
        cp      4
        jr      z,.hand
        ld      e,a
        dec     c                       ; tono - 1
        ld      a,c
        add     a,a
        add     a,a
        ld      c,a
        ld      b,0
        push    hl
        ld      hl,TEndTone
        add     hl,bc
        ld      c,(hl)
        inc     hl
        ld      b,(hl)                  ; BC = X del tono
        inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a                     ; HL = Y del tono
        bit     1,e                     ; fotos 2 y 3: la segunda fila del bloque
        jr      z,.r0
        ld      a,l
        add     a,PHOTO_H
        ld      l,a
        jr      nc,.r0
        inc     h
.r0:    ld      (vV9RegB+2),hl          ; SY
        bit     0,e                     ; fotos 1 y 3: la segunda columna
        jr      z,.c0
        ld      hl,PHOTO_W
        add     hl,bc
        ld      b,h
        ld      c,l
.c0:    ld      (vV9RegB),bc            ; SX
        pop     hl
        jr      V9_EndCopyAt
.hand:  dec     c
        ld      a,c
        add     a,a
        add     a,a
        ld      c,a
        ld      b,0
        push    hl
        ld      hl,TEndHand
        add     hl,bc
        ld      a,(hl)
        inc     hl
        ld      (vV9RegB),a
        ld      a,(hl)
        inc     hl
        ld      (vV9RegB+1),a
        ld      a,(hl)
        inc     hl
        ld      (vV9RegB+2),a
        ld      a,(hl)
        ld      (vV9RegB+3),a
        pop     hl
; Copia (SX, SY ya puestos) a la foto/manos HL, con su tamano
V9_EndCopyAt:
        call    V9_EndRect
        ld      hl,0C00h                ; ARG = 0, copia
        ld      (vV9RegB+12),hl
        ld      hl,0FFFFh
        ld      (vV9RegB+14),hl
        ld      a,40h                   ; LMMM
        ld      (vV9RegB+20),a
        jp      V9_SendB
; Relleno negro de la foto/manos HL
V9_EndFillAt:
        call    V9_EndRect
V9_EndFillGo:
        ld      hl,0C00h
        ld      (vV9RegB+12),hl
        ld      hl,0FFFFh
        ld      (vV9RegB+14),hl
        ld      hl,0
        ld      (vV9RegB+16),hl         ; color 0
        ld      a,20h                   ; LMMV
        ld      (vV9RegB+20),a
        jp      V9_SendB
; DX, DY, NX y NY de la foto/manos HL
V9_EndRect:
        ld      a,(hl)
        ld      (vV9RegB+4),a
        inc     hl
        ld      a,(hl)
        ld      (vV9RegB+6),a
        inc     hl
        xor     a
        ld      (vV9RegB+5),a
        ld      (vV9RegB+7),a
        ld      (vV9RegB+9),a
        ld      (vV9RegB+11),a
        ld      a,(hl)
        cp      4
        ld      hl,PHOTO_H*256+PHOTO_W
        jr      nz,.p
        ld      hl,HAND_H*256+HAND_W
.p:     ld      a,l
        ld      (vV9RegB+8),a           ; NX
        ld      a,h
        ld      (vV9RegB+10),a          ; NY
        ret

; ------------------------------------------------------------ los textos, con la fuente de la portada
; Una letra de un texto del guion (en lugar de 5F1F): A = letra (sin el bit 7), DE' = su direccion en la
; pantalla Spectrum (filas de 16: la letra de 8 va 4 lineas mas abajo), HL' = sus atributos. Se anota y se
; pinta entera (el original tampoco la fundia: los atributos con brillo se saltan el fundido de entrada);
; el fundido de salida la va oscureciendo como a las fotos. Bajo la linea de Taito se anade la de DiHalt.
V9_EndChar:
        cp      20h
        jr      z,.adv
        push    af
        exx
        push    de
        exx
        pop     de
        ld      a,e
        and     31
        ld      c,a                     ; C = columna
        ld      a,d
        and     18h
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      a,e
        and     0E0h
        rrca
        rrca
        or      l
        ld      l,a
        ld      a,d
        and     7
        or      l
        add     a,4
        ld      b,a                     ; B = y
        pop     af
        push    bc
        push    af
        call    V9_EndTxtLog
        pop     af
        pop     bc
        cp      '('                     ; "(C) 1988 TAITO CORPORATION": columna 3, fila 144
        jr      nz,.adv
        ld      a,b
        cp      144+4
        jr      nz,.adv
        ld      a,c
        cp      3
        call    z,V9_EndDihalt
.adv:   exx
        inc     e
        inc     l
        exx
        ret
; "DIHALT STUDIO 2026", centrado, dos filas por debajo
V9_EndDihalt:
        ld      hl,TEndDihalt
        ld      bc,(176+4)*256+7
.l:     ld      a,(hl)
        or      a
        ret     z
        cp      20h
        jr      z,.sp
        push    hl
        push    bc
        call    V9_EndTxtLog
        pop     bc
        pop     hl
.sp:    inc     c
        inc     hl
        jr      .l
; Anota la letra A en (columna C, y B) y la pinta entera
V9_EndTxtLog:
        push    af
        ld      hl,vEndTxtN
        ld      a,(hl)
        cp      TXT_MAX
        jr      c,.ok
        pop     af
        ret
.ok:    inc     (hl)
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        ld      de,TEndTxt
        add     hl,de
        ld      (hl),c
        inc     hl
        ld      (hl),b
        inc     hl
        pop     af
        ld      (hl),a
        dec     hl
        dec     hl
        ld      c,5
; La letra HL (columna, y, letra, tono) al tono C y lo anota. Tono 0: negro.
V9_EndTxtDraw:
        ld      a,(hl)
        add     a,a
        add     a,a
        add     a,a
        ld      (vV9RegB+4),a           ; DX = columna * 8
        inc     hl
        ld      a,(hl)
        ld      (vV9RegB+6),a           ; DY
        inc     hl
        ld      a,(hl)                  ; letra
        inc     hl
        ld      (hl),c
        push    af
        xor     a
        ld      (vV9RegB+5),a           ; (DX y DY altos a 0)
        ld      (vV9RegB+7),a
        ld      (vV9RegB+9),a
        ld      (vV9RegB+11),a
        ld      a,8
        ld      (vV9RegB+8),a           ; NX
        ld      (vV9RegB+10),a          ; NY
        pop     af
        inc     c
        dec     c
        jp      z,V9_EndFillGo
        call    V9_EndGlyph
        ld      hl,0C00h                ; ARG = 0, copia opaca (la letra va sobre negro; con transparencia, los
        ld      (vV9RegB+12),hl         ; pixeles negros del tono no tapaban la letra mas clara de antes)
        ld      hl,0FFFFh
        ld      (vV9RegB+14),hl
        ld      a,40h                   ; LMMM
        ld      (vV9RegB+20),a
        jp      V9_SendB
; SX y SY de la letra A en la fuente, al tono C (5: la fuente; 1-4: sus copias oscuras en la ventana B).
; Casillas como en V9_MsgChar: ! ( ) , 0-3, el punto y los demas signos 4, 0-9 5-14, A-Z 15-40.
V9_EndGlyph:
        cp      'A'
        jr      c,.pun
        cp      5Bh
        jr      nc,.dot
        sub     'A'-15
        jr      .t
.pun:   cp      '0'
        jr      c,.sym
        cp      ':'
        jr      nc,.dot
        sub     '0'-5
        jr      .t
.sym:   ld      e,0
        cp      21h
        jr      z,.te
        inc     e
        cp      28h
        jr      z,.te
        inc     e
        cp      29h
        jr      z,.te
        inc     e
        cp      2Ch
        jr      z,.te
.dot:   ld      e,4
.te:    ld      a,e
.t:     ld      b,a                     ; B = casilla
        and     1Fh
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      h,0
        ld      a,c
        cp      5
        jr      z,.sx
        inc     h                       ; tonos 1-4: x + 256
.sx:    ld      (vV9RegB),hl            ; SX
        ld      hl,FONT_Y
        ld      a,c
        cp      5
        jr      z,.row
        ld      hl,WIN_Y
        dec     a
        jr      z,.row
        ld      de,24
.m:     add     hl,de
        dec     a
        jr      nz,.m
.row:   ld      a,b
        cp      32
        jr      c,.sy
        ld      de,8                    ; (la segunda fila de casillas)
        add     hl,de
.sy:    ld      (vV9RegB+2),hl          ; SY
        ret
; Las letras que estan por encima del tono C bajan a el
V9_EndTxtDown:
        ld      a,(vEndTxtN)
        or      a
        ret     z
        ld      b,a
        ld      hl,TEndTxt
.s:     push    bc
        push    hl
        inc     hl
        inc     hl
        inc     hl
        ld      a,c
        cp      (hl)
        pop     hl
        push    hl
        call    c,V9_EndTxtDraw         ; (tono > C)
        pop     hl
        pop     bc
        ld      de,4
        add     hl,de
        djnz    .s
        ret

; ------------------------------------------------------------ los tonos oscuros, en la VRAM
; Las tablas: 4 de 64 (tono 1 a 4), en una pagina: indice | (tono - 1) << 6
        code @ 6900h
TEndTab:
        include "../build/ending_tones.inc"

vEndSy:         dw      0               ; linea origen
vEndDy:         dw      0               ; linea destino
vEndDx:         dw      0               ; x destino
vEndTab:        db      0               ; (tono - 1) << 6
vEndW:          db      0               ; bytes por linea / 4

V9_EndGen:
        di
        ld      a,52                    ; 208 bytes por linea: los dos bloques de 2 fotos
        ld      (vEndW),a
        xor     a
        ld      (vEndTab),a
        ld      ix,TEndTone
.tone:  ld      hl,SHEET_Y
        ld      (vEndSy),hl
        ld      l,(ix+0)
        ld      h,(ix+1)
        ld      (vEndDx),hl
        ld      l,(ix+2)
        ld      h,(ix+3)
        ld      (vEndDy),hl
        ld      b,2*PHOTO_H
        call    V9_EndLines
        inc     ix
        inc     ix
        inc     ix
        inc     ix
        ld      a,(vEndTab)
        add     a,40h
        ld      (vEndTab),a
        jr      nz,.tone
        ld      a,16                    ; las manos: su primer fotograma, 64 bytes por linea
        ld      (vEndW),a
        ld      ix,TEndHand
.hand:  ld      hl,HANDS_Y
        ld      (vEndSy),hl
        ld      l,(ix+0)
        ld      h,(ix+1)
        ld      (vEndDx),hl
        ld      l,(ix+2)
        ld      h,(ix+3)
        ld      (vEndDy),hl
        ld      b,HAND_H
        call    V9_EndLines
        inc     ix
        inc     ix
        inc     ix
        inc     ix
        ld      a,(vEndTab)
        add     a,40h
        ld      (vEndTab),a
        jr      nz,.hand
        ld      a,64                    ; la fuente de la portada: 256 bytes por linea, 24 lineas
        ld      (vEndW),a
        ld      ix,TEndFont
.font:  ld      hl,FONT_Y
        ld      (vEndSy),hl
        ld      l,(ix+0)
        ld      h,(ix+1)
        ld      (vEndDx),hl
        ld      l,(ix+2)
        ld      h,(ix+3)
        ld      (vEndDy),hl
        ld      b,24
        call    V9_EndLines
        inc     ix
        inc     ix
        inc     ix
        inc     ix
        ld      a,(vEndTab)
        add     a,40h
        ld      (vEndTab),a
        jr      nz,.font
        ret
; B lineas de (0, vEndSy) a (vEndDx, vEndDy), vEndW * 4 bytes cada una, por la tabla vEndTab
V9_EndLines:
        push    bc
        ld      hl,(vEndSy)
        ld      de,0
        ld      a,3                     ; R#3-5: direccion de lectura
        call    V9_EndAddr
        inc     hl
        ld      (vEndSy),hl
        ld      hl,(vEndDy)
        ld      de,(vEndDx)
        xor     a                       ; R#0-2: direccion de escritura
        call    V9_EndAddr
        inc     hl
        ld      (vEndDy),hl
        ld      a,(vEndTab)
        ld      c,a
        ld      h,TEndTab/256
        ld      a,(vEndW)
        ld      b,a
.g:     in      a,(60h)
        or      c
        ld      l,a
        ld      a,(hl)
        out     (60h),a
        in      a,(60h)
        or      c
        ld      l,a
        ld      a,(hl)
        out     (60h),a
        in      a,(60h)
        or      c
        ld      l,a
        ld      a,(hl)
        out     (60h),a
        in      a,(60h)
        or      c
        ld      l,a
        ld      a,(hl)
        out     (60h),a
        djnz    .g
        pop     bc
        djnz    V9_EndLines
        ret
; Direccion de VRAM y * 512 + x (HL = y, DE = x) en los registros A, A+1 y A+2 (0: escritura, 3: lectura).
; Conserva HL y DE.
V9_EndAddr:
        out     (64h),a
        ld      a,e
        out     (63h),a                 ; A7-A0
        ld      a,l
        add     a,a
        or      d
        out     (63h),a                 ; A15-A8 = y * 2 | x / 256
        ld      a,l
        rlca
        and     1
        ld      c,a
        ld      a,h
        add     a,a
        or      c
        and     7
        out     (63h),a                 ; A18-A16 = y / 128 (sin inhibir el incremento)
        ret

; Celda C del tercio B (1-2) de la pantalla Spectrum a la pagina A del V9990, si ha cambiado (V9_CellN).
V9_EndCell:
        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        add     a,40h
        ld      h,a
        ld      l,c                     ; HL = linea 0 de la celda
        xor     a                       ; resumen de los 8 bytes
        xor     (hl)
        rlca
        inc     h
        xor     (hl)
        rlca
        inc     h
        xor     (hl)
        rlca
        inc     h
        xor     (hl)
        rlca
        inc     h
        xor     (hl)
        rlca
        inc     h
        xor     (hl)
        rlca
        inc     h
        xor     (hl)
        rlca
        inc     h
        xor     (hl)
        ld      e,a
        ld      a,b
        add     a,58h
        ld      h,a
        ld      d,(hl)                  ; D = atributo
        ld      h,b
        ld      l,c
        add     hl,hl
        ld      a,h
        add     a,V9_CACHE/256
        ld      h,a
        ld      a,(hl)
        cp      e
        jr      nz,.chg
        inc     hl
        ld      a,(hl)
        cp      d
        ret     z                       ; igual que lo que hay en pantalla
        dec     hl
.chg:   ld      (hl),e
        inc     hl
        ld      (hl),d
        push    bc
        ld      e,32                    ; colores: los del port MSX1, en la paleta 32-47
        ld      h,tAttrToTMS/256
        ld      l,d
        ld      a,(hl)
        ld      d,a
        and     15
        add     a,e
        ld      (vV9RegB+18),a          ; BC = papel
        ld      (vV9RegB+19),a
        ld      a,d
        rrca
        rrca
        rrca
        rrca
        and     15
        add     a,e
        ld      (vV9RegB+16),a          ; FC = tinta
        ld      (vV9RegB+17),a
        ld      a,c
        and     31
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      h,0
        ld      (vV9RegB+4),hl          ; DX = columna * 8 (pagina A)
        ld      a,c                     ; DY = fila * 8
        rlca
        rlca
        rlca
        and     7
        ld      l,a
        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        or      l
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      (vV9RegB+6),hl
        ld      hl,8
        ld      (vV9RegB+8),hl          ; NX
        ld      (vV9RegB+10),hl         ; NY
        ld      hl,0C00h
        ld      (vV9RegB+12),hl         ; ARG = 0, copia
        ld      a,50h                   ; CMMC
        ld      (vV9RegB+20),a
        call    V9_SendB
        pop     bc
        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        add     a,40h
        ld      h,a
        ld      l,c
        ld      b,8
.data:  in      a,(65h)                 ; espera a que el V9990 pida el dato (TR)
        rla
        jr      nc,.data
        ld      a,(hl)
        out     (62h),a
        inc     h
        djnz    .data
        ret
V9_EndEnd:                              ; (por debajo de 76EFh)
