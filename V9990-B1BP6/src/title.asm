; title.asm -- portada de la ROM normal (ORIG_INPUT = 0), en vez de Title_Loop.
;
; El original juega una demo detras e imprime los textos en su pantalla con un efecto de
; aparicion (y el port los mandaba celda a celda). Aqui no hay demo: el marcador del juego
; arriba, la ventana en negro y los textos de golpe, cada letra una copia del V9990 desde
; su hoja ya pintada en la VRAM (assets/editable/title_font.png, x 0-255, y 443-466;
; tools/mktitle.py). "PRESS GEAR TO PLAY" parpadea y los creditos se alternan con el
; copyright; vuelve en cuanto se pulsa el boton de marcha, como el original.
;
; Va en codigo muerto de la ROM normal: los restos de LD-BYTES del Spectrum y los textos
; de la cinta (80C3-81DC: la carga ya no los usa), el resto de Lvl_Load (8029-80B8) y el
; Title_Loop original (8258-831F).
TL_FONT_Y       equ 443                 ; primera linea de title_font.png en la VRAM

        code ! Title_Loop
        jp      V9_TitleLoop
; textos (build/title.inc)
        include "../build/title.inc"
TIntroWin:      dw      0,64,256,128
; Espera al siguiente retrazado vertical del V9990.
V9_TlWait:
        in      a,(65h)
        and     40h
        jr      nz,V9_TlWait
.b:     in      a,(65h)
        and     40h
        jr      z,.b
        ret
; Pantalla "monitor" del aviso de inicio de nivel (assets/editable/monitor.png, hoja 16). Como la
; portada: el marcador del juego como al empezar una carrera (V9_HudRedraw, con vV9Race, para
; que las letras de la radio, las caras y los digitos salgan de copias), y la imagen del monitor
; subida a la ventana B y copiada de golpe a la A. No hay volcado de la pantalla Spectrum: de
; ella (vV9Mon) solo se mandan las celdas de las barras de SIGNAL.
V9_TlHud:                               ; marcador del juego como al empezar una carrera (y las sirenas:
        xor     a                       ; V9_LoadSheetA deja pendiente su paleta)
        ld      (vShowHi),a
        inc     a
        ld      (vV9Race),a
        jp      V9_HudRedraw
        if CHEAT_ENDING
V9_CheatEnding:                         ; (cheats.asm: la partida empieza por el final)
        ld      a,6
        ld      (vLevel),a
        jp      Lvl_PlayLoad
        endif
V9_TlEnd2:                              ; (por debajo de 8320h: tMsgCopyright, que usa el nivel 6)

        code ! Lvl_LoadRetry+4          ; (resto de Lvl_Load, muerto: ver port.asm)
; rellenos (DX, DY, NX, NY)
TTlWin:         dw      0,64,256,148    ; ventana entera
TTlPress:       dw      56,96,144,8     ; "PRESS GEAR TO PLAY"
        include "../build/title2.inc"      ; (el copyright)
TTlMsg:         dw      0,120,256,56    ; creditos / copyright
TTlBlk:         dw      0,192,512,20    ; las ultimas lineas de la pantalla (negras)
; R#32-R#52 de una letra: SX, SY, DX, DY, NX, NY, ARG, LOP (copia), mascara, FC, BC, LMMM
TTlRegs:        dw      0,TL_FONT_Y,0,0,8,8
                db      0,1Ch,0FFh,0FFh,0,0,0,0,40h
TTlFillEnd:     db      0,0Ch,0FFh,0FFh,0,0,0,0,20h     ; ARG...: relleno (LMMV) de color 0
V9_TlEnd3:                              ; (por debajo de 80B9h: Lvl_LoadBlock)

        code ! 80C3h
V9_TitleLoop:
        call    V9_IntOn
        call    V9_Dark
        call    V9_TlHud
        ld      a,1
        ld      (.blink+1),a
        ld      (.which+1),a
        ld      a,16
        ld      (.bcnt+1),a
        xor     a
        ld      (.msg+1),a
        call    V9_TlBg                 ; el fondo, a la ventana B
        ld      hl,TTlWin
        call    V9_TlFill
        ld      hl,TTlHead
        call    V9_TlText
        ld      hl,TTlCred
        call    V9_TlText
        call    V9_Lit                  ; ya esta toda la portada
.frame: call    V9_TlWait
        call    Inp_Read
        and     10h                     ; boton de marcha
        jr      nz,.out
.bcnt:  ld      a,0                     ; parpadeo: cada 16 frames
        dec     a
        ld      (.bcnt+1),a
        jr      nz,.msg
        ld      a,16
        ld      (.bcnt+1),a
.blink: ld      a,0
        xor     1
        ld      (.blink+1),a
        ld      hl,TTlHead              ; (su segundo registro es "PRESS GEAR TO PLAY")
        jr      z,.hide
        call    V9_TlPress
        jr      .msg
.hide:  ld      hl,TTlPress
        call    V9_TlFill
.msg:   ld      a,0                     ; creditos / copyright: cada 256 frames (unos 5 s)
        dec     a
        ld      (.msg+1),a
        jr      nz,.frame
        ld      hl,TTlMsg
        call    V9_TlFill
.which: ld      a,0
        xor     1
        ld      (.which+1),a
        ld      hl,TTlCred
        jr      nz,.txt
        ld      hl,TTlCopy
.txt:   call    V9_TlText
        jr      .frame
.out:   call    V9_Dark                 ; (hasta que este el aviso del nivel)
        call    V9_TlBlack              ; (el fondo llega hasta la linea 211)
        xor     a                       ; la pantalla siguiente se vuelca entera: la de la
        ld      (vV9Race),a             ; ventana se ha pintado por encima de sus celdas
        inc     a
        ld      (vWinDirty),a
        ret

; Solo "PRESS GEAR TO PLAY": el segundo registro de TTlHead.
V9_TlPress:
        inc     hl
        inc     hl
        inc     hl
.skip:  bit     7,(hl)
        inc     hl
        jr      z,.skip
        call    V9_TlRec
        ret

; Registros de texto desde HL hasta FFh.
V9_TlText:
        ld      a,(hl)
        inc     a
        ret     z
        call    V9_TlRec
        jr      V9_TlText

; Un registro: columna, linea, alto y casillas. Vuelve con HL tras el registro.
V9_TlRec:
        push    hl
        ld      hl,TTlRegs
        ld      de,vV9RegB
        ld      bc,21
        ldir
        pop     hl
        ld      a,(hl)                  ; DX = columna * 8
        add     a,a
        add     a,a
        add     a,a
        ld      (vV9RegB+4),a
        inc     hl
        ld      a,(hl)
        ld      (vV9RegB+6),a           ; DY
        inc     hl
        ld      a,(hl)
        ld      (vV9RegB+10),a          ; NY
        inc     hl
.ch:    ld      a,(hl)
        and     7Fh
        cp      7Fh
        jr      z,.next                 ; espacio: nada
        ld      e,a
        and     31
        add     a,a
        add     a,a
        add     a,a
        ld      (vV9RegB+0),a           ; SX = (casilla & 31) * 8
        ld      a,e
        and     0E0h
        rrca
        rrca                            ; (casilla >> 5) * 8
        add     a,TL_FONT_Y-256
        ld      (vV9RegB+2),a           ; SY (byte alto: 1)
        push    hl
        call    V9_SendB
        pop     hl
.next:  ld      a,(vV9RegB+4)
        add     a,8
        ld      (vV9RegB+4),a
        bit     7,(hl)
        inc     hl
        jr      z,.ch
        ret

; Relleno de color 0: HL -> DX, DY, NX, NY.
V9_TlFill:
        ld      de,vV9RegB+4
        ld      bc,8
        ldir
        ld      hl,TTlFillEnd
        ld      bc,9
        ldir
        jp      V9_TlSrc

V9_TlEnd:                               ; (por debajo de 81DDh: tNancyStartMsg)

; Fondo de la portada: en el cuerpo de VDP_CopyColors, tras el codigo del marcador (hueco de
; V9_PicEnd).
        code ! V9_PicEnd
; Fondo (hoja 15) a la ventana B: el maestro del que se repone la ventana A.
V9_TlBg:
        ld      a,15
V9_TlLd:                                ; sube la hoja A (con interrupciones fuera)
        push    af
        call    V9_WaitCE
        di
        pop     af
        call    V9_LoadSheetA
        ei
        ret
; Relleno de V9_TlFill como copia desde el maestro (ventana B, misma linea): SX = DX + 256.
V9_TlSrc:
        ld      a,(vV9RegB+4)
        ld      (vV9RegB+0),a
        ld      a,1
        ld      (vV9RegB+1),a
        ld      a,(vV9RegB+6)
        ld      (vV9RegB+2),a
        xor     a
        ld      (vV9RegB+3),a
        ld      a,40h                   ; LMMM
        ld      (vV9RegB+20),a
        jp      V9_SendB
; Las lineas 192-211 de las dos paginas, a negro (la portada las pinta con el fondo).
V9_TlBlack:
        ld      hl,TTlBlk
        ld      de,vV9RegB+4
        ld      bc,8
        ldir
        ld      hl,TTlFillEnd
        ld      bc,9
        ldir
        jp      V9_SendB
V9_TlEnd4:                              ; (por debajo de 3F00h: tAttrToTMS)

; Aviso de nivel y cambios de pantalla en negro (V9_Dark / V9_Lit, src/dark.asm), a continuacion de
; esas rutinas en el codigo muerto de la redefinicion de teclas (35CE-370B).
        code ! V9_DarkEnd
; Lvl_Play: "call Lvl_Load". Empieza el cambio de fase (o la partida): pantalla en negro hasta el aviso.
V9_PlayLoad:
        ld      a,(vLevel)
        cp      6                       ; (la secuencia final no pasa por el aviso)
        call    nz,V9_Dark
        jp      Lvl_Load
; Lvl_Begin: "call Lvl_Intro". La carrera se prepara (marcador, carretera, musica) con la pantalla en negro
; y sin sonido; V9_Present la enciende con el primer cuadro completo.
V9_IntroDone:
        call    Lvl_Intro
        jp      V9_BriefStop
V9_FadeOut:
        ld      a,6
        ld      (vCatchState),a
        call    V9_Dark
        ld      a,2                     ; vV9Dark = 2: en negro y que V9_Present no lo encienda (la
        ld      (vV9Dark),a             ; disolucion sigue dando cuadros hasta que sale del nivel)
        ld      a,8
        jp      Fx_StartDissolve
V9_IntroEnter:                          ; Lvl_IntroClear: "call Scr_ClearWindow"
        call    Scr_ClearWindow
        call    V9_TlHud
        ld      a,1
        ld      (vV9Mon),a
        ld      a,24
        ld      (vV9Pic),a              ; frames sin barras (disolucion del original)
        ld      a,16
        call    V9_TlLd
        ld      hl,TIntroWin            ; la imagen, de golpe
        call    V9_TlFill
        jp      V9_BriefSound           ; ya esta el aviso
; Una letra de un mensaje: B = caracter, C = columna, D = fila (+ 80h si es de doble altura). Tabla de la fuente de
; la portada (title_font.png): pequenas 0-40 en el orden de la fuente del original, grandes en TTlBigIdx.
V9_MsgChar:
        ld      a,c                     ; DX = ventana en la que se dibuja * 256 + columna * 8
        add     a,a
        add     a,a
        add     a,a
        ld      (vV9RegB+4),a
        ld      a,(vV9Draw)
        ld      (vV9RegB+5),a
        ld      a,d                     ; DY = 64 + fila * 8
        and     0Fh
        add     a,a
        add     a,a
        add     a,a
        add     a,V9_WIN_Y
        ld      (vV9RegB+6),a
        xor     a
        ld      (vV9RegB+7),a
        ld      a,d
        and     80h
        ld      c,a                     ; C = 80h si es grande
        ld      a,b
        cp      'A'
        jr      c,.pun
        cp      5Bh
        ret     nc
        sub     'A'
        bit     7,c
        jr      z,.sl
        ld      e,a                     ; letra grande: casilla de TTlBigIdx
        ld      d,0
        ld      hl,TTlBigIdx
        add     hl,de
        ld      a,(hl)
        cp      0FFh
        jr      z,.sl2                  ; (sin letra grande: la pequena)
        add     a,a
        add     a,a
        add     a,a
        add     a,72                    ; SX = 72 + 8 * casilla; SY = 451
        ld      (vV9RegB+0),a
        ld      a,0C3h
        ld      (vV9RegB+2),a
        ld      a,16
        jp      V9_MsgGo
.sl2:   ld      a,e
.sl:    add     a,15                    ; A-Z = casillas 15-40
.t:     ld      e,a
        and     1Fh
        add     a,a
        add     a,a
        add     a,a
        ld      (vV9RegB+0),a           ; SX = (casilla & 31) * 8
        ld      a,e
        cp      32
        ld      a,TL_FONT_Y-256
        jr      c,.y
        add     a,8
.y:     ld      (vV9RegB+2),a           ; SY = 443 (+ 8 en la segunda fila de casillas)
        ld      a,8
        jp      V9_MsgGo
.pun:   cp      '0'
        jr      c,.sym
        cp      ':'
        ret     nc
        sub     '0'-5                   ; 0-9 = casillas 5-14
        jr      .t
.sym:   ld      e,0                     ; ! ( ) , = casillas 0-3; los demas signos, el punto (4)
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
        inc     e
.te:    ld      a,e
        jr      .t
; Turbo R: espera a que hayan pasado A retrazados desde la presentacion anterior.
V9_Limit:
        ld      b,a
        ei
.lim:   ld      a,(V9_TICK)
        cp      b
        jr      c,.lim
        xor     a
        ld      (V9_TICK),a
        ret
V9_TlEnd6:                              ; (por debajo de 370Ch: VDP_DumpWindow)

; Registro de filas y dibujo de los mensajes de la carrera: tras el vector de interrupcion (1901-19FF).
        code ! 1901h
; Mensajes de la carrera (TIME UP, CONTINUE, GAME OVER, captura...): el original los escribe cada cuadro
; mientras dura un efecto (vFxState) en su bufer de ventana, que el port ya no vuelca. Txt_PutChar
; (V9_PutLog) anota cada letra (caracter, columna, fila y si es de doble altura) en una lista en
; 4800h (la parte de la pantalla Spectrum que la carrera no usa) y V9_Msg, que llama V9_Present con un
; efecto en marcha, la dibuja encima de la carretera ya pintada con la fuente de la portada
; (assets/editable/title_font.png: letras pequenas y las grandes de doble altura): una copia LMMM
; sin el color 0 por letra. El primer cuadro de un mensaje solo vacia la lista.
V9_PutLog:                              ; Txt_PutChar: "sub 20h / jr nz,Txt_MapChar..."
        push    af
        push    bc
        push    hl
        ld      b,a                     ; B = caracter
        ld      a,d
        cp      0F0h
        jr      c,.pp                   ; (solo el bufer de la ventana; el marcador va a 40xx)
        ld      a,b
        cp      20h
        jr      z,.pp                   ; (el espacio no se dibuja)
        ex      af,af'                  ; modo del texto (A'): 3 o mas = doble altura
        ld      c,a
        ex      af,af'
        ld      a,e
        rlca
        rlca
        rlca
        and     7
        add     a,a
        ld      l,a
        ld      a,d
        and     8
        rrca
        rrca
        rrca
        add     a,l                     ; fila de celdas de la ventana: (E >> 5) * 2 + (D & 8) / 8
        ld      l,a
        ld      a,c
        cp      3
        ld      a,l
        jr      c,.s
        or      80h                     ; doble altura
.s:     ld      c,a
        cp      8Ah                     ; la linea "SCORE" del bonus: se corta la sirena
        jr      nz,.ns
        ld      a,(VGM_S0+6)
        or      a
        jr      z,.ns
        push    bc
        push    de
        ld      a,1
        call    V9_SndStop
        pop     de
        pop     bc
.ns:    ld      hl,(V9_MSGP)
        ld      a,h
        cp      48h
        jr      nc,.ok
        ld      hl,V9_MSGL              ; (aun sin iniciar)
        ld      a,h
.ok:    cp      4Bh
        jr      nc,.pp                  ; (lista llena)
        ld      a,e
        and     1Fh
        ld      (hl),b
        inc     hl
        ld      (hl),a                  ; columna
        inc     hl
        ld      (hl),c                  ; fila (+ bit 7 si es grande)
        inc     hl
        ld      (V9_MSGP),hl
.pp:    pop     hl
        pop     bc
        pop     af
        sub     20h
        jp      nz,Txt_MapChar
        inc     e
        exx
        inc     l
        exx
        ret
V9_Msg:
        ld      a,(vV9MsgOn)
        or      a
        jr      nz,.go
        inc     a
        ld      (vV9MsgOn),a
        jr      .end                    ; primer cuadro: la lista trae lo que se escribio fuera del mensaje
.go:    xor     a
        ld      (V9_MSGF),a
        ld      hl,V9_MSGL
.lp:    ld      de,(V9_MSGP)
        ld      a,l
        sub     e
        ld      a,h
        sbc     a,d
        jr      nc,.end
        ld      b,(hl)
        inc     hl
        ld      c,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        push    hl
        call    V9_MsgChar
        pop     hl
        jr      .lp
.end:   ld      hl,V9_MSGL
        ld      (V9_MSGP),hl
        ret
V9_MsgGo:                               ; NY en A: lo demas ya esta en vV9RegB
        ld      (vV9RegB+10),a          ; NY (8 o 16)
        ld      hl,8
        ld      (vV9RegB+8),hl          ; NX
        xor     a
        ld      (vV9RegB+1),a
        ld      (vV9RegB+11),a
        inc     a
        ld      (vV9RegB+3),a           ; SX < 256, SY >= 256
        ld      a,(V9_MSGF)
        or      a
        jr      nz,.fast
        inc     a
        ld      (V9_MSGF),a             ; la primera letra del cuadro: todos los registros
        ld      hl,1C00h                ; ARG = 0, copia sin el color 0
        ld      (vV9RegB+12),hl
        ld      hl,0FFFFh
        ld      (vV9RegB+14),hl
        ld      a,40h                   ; LMMM
        ld      (vV9RegB+20),a
        jp      V9_SendB
.fast:  call    V9_WaitCE               ; las siguientes: SX, SY, DX, DY, NX, NY y la orden (ARG, LOP y
        di                              ; mascara se conservan; NX y NY no: el V9990 real los altera al
        ld      a,32                    ; acabar cada orden, doc/06_openmsx_vs_real.md)
        out     (64h),a
        ld      hl,vV9RegB
        ld      bc,0C63h
        otir                            ; R#32-R#43
        ld      a,52
        out     (64h),a
        ld      a,40h
        out     (63h),a
        ei
        ret
; Al acabarse un turbo el original descuenta uno (B0A5); con el truco, no.
V9_TurboDec:
        ld      a,(vTurbos)
        ld      b,a
        ld      a,(V9_CHEAT)
        or      a
        ld      a,b
        ret     nz
        dec     a
        ld      (vTurbos),a
        ret
V9_MsgEnd:                              ; (por debajo de 1A00h: TV9UnsIdx)

; Aviso del nivel (imagen del monitor) y fin de nivel: en el codigo del fundido de pantalla que se quito (Fx_DissolveStep,
; Fx_StartDissolve y sus tablas).
        code ! 8DA5h
V9_IntroPresent:                        ; Lvl_IntroPresent: "call VDP_PresentFull"
        call    V9_IntOn                ; (el original va con DI: se reactivan en cada cuadro, como V9_Present)
        ld      a,(V9_TURBO)            ; turbo R: tambien el aviso (la maquina de escribir de la radio) al ritmo del Z80
        or      a
        call    nz,V9_Limit
        ld      hl,vV9Pic               ; (con la disolucion en marcha el original aun no tiene
        ld      a,(hl)                  ; las barras: se ven las de la imagen)
        or      a
        jr      z,.bars
        dec     (hl)
        ret     nz
        ld      hl,V9_CACHE+(16*32+23)*2+1      ; ultimo cuadro de espera: las 14 celdas de las barras, por
        call    .inv                            ; mandar todas. La cache trae las del aviso anterior y la
        ld      hl,V9_CACHE+(18*32+23)*2+1      ; imagen tiene las suyas: la celda que coincidiera con la cache
.inv:   ld      b,7                             ; no se mandaba y se quedaba con el color de la imagen
.i:     ld      (hl),0FFh                       ; (atributo imposible)
        inc     hl
        inc     hl
        djnz    .i
        ret
.bars:  ld      bc,0217h                ; filas 16 y 18, columnas 23-29: los 7 LED (la 30 es el remate de la
        call    .row                    ; barra del dibujo original: lo pone monitor.png)
        ld      bc,0257h
.row:   ld      d,7
.cel:   push    de
        push    bc
        call    V9_BufCell
        pop     bc
        push    bc
        call    V9_CellN
        pop     bc
        pop     de
        inc     c
        dec     d
        jr      nz,.cel
        ret
V9_FxStart:
        ld      a,4
        ld      (vFxState),a
        ret
V9_FxEnd1:                              ; (por debajo de 8DF9h: Fx_StartDissolve)
        code ! 8DFCh
; B = tercio (1-2), C = celda: las 8 lineas de esa celda, del bufer de la ventana a la pantalla Spectrum
V9_BufCell:
        ld      a,c
        and     1Fh
        ld      l,a
        ld      a,c
        and     0C0h
        rrca
        or      l
        ld      l,a
        ld      a,b
        dec     a
        rrca
        or      l
        ld      l,a
        ld      a,c
        and     20h
        rrca
        rrca
        or      0F0h
        ld      h,a
        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        add     a,40h
        ld      d,a
        ld      e,c
        ld      b,8
.cp:    ld      a,(hl)
        ld      (de),a
        inc     h
        inc     d
        djnz    .cp
        ret
V9_FxEnd2:                              ; (por debajo de 8E29h: Fx_ClearWinAttrs)

; Coche del criminal en la pantalla del monitor (Lvl_IntroMap, una llamada por cuadro del aviso). El original lo
; descubre de abajo arriba, una linea por cuadro, con el blitter opaco en su bufer: el fotograma de la escala 0
; (la mas cercana) de la lista del criminal (LevelData+110), en la columna 13 y con la ultima linea en la 100 de
; la ventana. Aqui cada cuadro es una copia de una linea de la hoja del nivel (ya en la VRAM, bajo las ventanas)
; a la ventana A, sin el color 0, en ese mismo sitio. El contador es el del original (Lvl_IntroMapCnt, que
; Lvl_Intro pone a 0). El original se lo saltaba en el nivel 5; aqui se ve en los cinco.
; Va en los blitters opacos del original (Spr_DrawOpaque y Spr_DrawOpqMirror, 949C-9617), que solo llamaban
; Lvl_IntroMap y Car_DrawBody, los dos sustituidos.
        code ! Spr_DrawOpaque
V9_IntroCar:
        ld      hl,(LevelData+110h)     ; descriptor de la escala 0: ancho en bytes, flags, alto, T
        ld      a,(hl)
        add     a,a
        add     a,a
        add     a,a
        ld      (vV9RegB+8),a           ; NX = ancho
        inc     hl
        inc     hl
        ld      b,(hl)                  ; B = alto
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; T = (x/8)*512 + y, en la hoja del nivel (x 0-255, desde la linea 212)
        ld      hl,Lvl_IntroMapCnt
        ld      a,(hl)
        cp      b
        ret     nc                      ; ya esta entero
        inc     (hl)
        ld      c,a                     ; C = lineas ya descubiertas
        ld      a,d
        add     a,a
        add     a,a
        and     0F8h
        ld      (vV9RegB),a             ; SX = x
        xor     a
        ld      (vV9RegB+1),a
        ld      (vV9RegB+5),a           ; (ventana A)
        ld      (vV9RegB+7),a
        ld      (vV9RegB+9),a
        ld      (vV9RegB+11),a
        inc     a
        ld      (vV9RegB+10),a          ; NY = 1
        ld      a,d
        and     1
        ld      d,a                     ; DE = y en la hoja
        ld      a,b                     ; la linea alto - 1 - C del fotograma (de abajo arriba)
        dec     a
        sub     c
        ld      l,a
        ld      h,0
        add     hl,de
        ld      de,212
        add     hl,de
        ld      (vV9RegB+2),hl          ; SY
        ld      a,164                   ; DY = 64 + 100 - C
        sub     c
        ld      (vV9RegB+6),a
        ld      a,104                   ; DX = columna 13
        ld      (vV9RegB+4),a
        ld      hl,1C00h                ; ARG = 0, copia sin el color 0
        ld      (vV9RegB+12),hl
        ld      hl,0FFFFh
        ld      (vV9RegB+14),hl
        ld      a,40h                   ; LMMM
        ld      (vV9RegB+20),a
        jp      V9_SendB
        if DIAG                         ; (make diag-rom)
; Vigilante para la maquina real, desde la interrupcion de retrazado (BC, DE y HL apilados). En la carrera
; lee R#6, R#7, R#16, R#18 y R#19 (el V9990 deja leerlos): al empezar se guardan; si luego cambian, se
; reponen y el color 0 (fondo y negro) se queda de un color: magenta R#6/R#7 (modo de pantalla), rojo
; R#18/R#19 (scroll), amarillo R#16 (ajuste). Cian: una orden lleva 4 retrazados sin acabar (copia
; desbocada que machaca la VRAM). Sin color: los registros estan bien.
V9_DiagVb:
        ld      a,(vV9Race)
        or      a
        jr      nz,.race
        ld      (V9_DiagRef),a          ; fuera de la carrera: sin referencia (el modo cambia en la portada)
        ret
.race:  ld      a,6
        out     (64h),a
        in      a,(63h)
        ld      b,a                     ; R#6
        in      a,(63h)
        ld      c,a                     ; R#7
        ld      a,16
        out     (64h),a
        in      a,(63h)
        ld      d,a                     ; R#16
        in      a,(63h)                 ; (R#17)
        in      a,(63h)
        ld      e,a                     ; R#18
        in      a,(63h)
        or      e
        ld      e,a                     ; R#18 | R#19: 0
        ld      hl,V9_DiagRef
        ld      a,(hl)
        or      a
        jr      nz,.cmp
        inc     (hl)                    ; primera vez: referencia
        inc     hl
        ld      (hl),b
        inc     hl
        ld      (hl),c
        inc     hl
        ld      (hl),d
        jr      .ce
.cmp:   inc     hl
        ld      a,(hl)
        cp      b
        jr      nz,.mode
        inc     hl
        ld      a,(hl)
        cp      c
        jr      nz,.mode
        inc     hl
        ld      a,(hl)
        cp      d
        jr      nz,.adj
        ld      a,e
        or      a
        jr      z,.ce
        ld      a,18                    ; scroll: R#18 = R#19 = 0
        out     (64h),a
        xor     a
        out     (63h),a
        out     (63h),a
        ld      e,0
        jr      .mark
.adj:   ld      a,16
        out     (64h),a
        ld      a,(hl)
        out     (63h),a
        ld      e,3
        jr      .mark
.mode:  ld      a,6
        out     (64h),a
        ld      a,(V9_DiagRef+1)
        out     (63h),a
        ld      a,(V9_DiagRef+2)
        out     (63h),a
        ld      e,5
        jr      .mark
.ce:    in      a,(65h)                 ; orden en marcha en 4 retrazados seguidos
        rra
        ld      a,0
        jr      nc,.cz
        ld      a,(V9_DiagCE)
        inc     a
        cp      4
        jr      c,.cz
        ld      e,4
        ld      (V9_DiagCE),a
        jr      .mark
.cz:    ld      (V9_DiagCE),a
        ld      a,(V9_DiagRes)
        cp      0FFh
        ret     z
        ld      e,a                     ; ya marcado: el color se repone en cada retrazado
        jr      .col
.mark:  ld      a,(V9_DiagRes)
        cp      0FFh
        jr      nz,.col2                ; se queda el primero
        ld      a,e
        ld      (V9_DiagRes),a
.col2:  ld      a,(V9_DiagRes)
        ld      e,a
.col:   ld      a,e
        add     a,a
        add     a,e
        ld      e,a
        ld      d,0
        ld      hl,TDiag
        add     hl,de
        ld      a,14
        out     (64h),a
        xor     a
        out     (63h),a                 ; color 0
        ld      bc,0361h
        otir
        ret
V9_DiagRef:     db      0,0,0,0         ; hay referencia, R#6, R#7, R#16
V9_DiagCE:      db      0
V9_DiagRes:     db      0FFh
;               0 rojo   1 verde  2 azul   3 amar.  4 cian   5 magenta 6 blanco 7 naranja
TDiag:          db      31,0,0,  0,31,0,  0,0,31,  31,31,0, 0,31,31, 31,0,31,  31,31,31, 31,16,0
        endif
; El SOS usa la pista de musica durante el aviso, con A/B silenciados.
; Se corta antes de preparar el primer cuadro de carretera, tambien al saltar el texto.
        if ORIG_INPUT = 0
; Mantiene la cola del impacto frente a cuneta/derrape. Otra embestida lo
; reinicia. La peticion ya se ha consumido para que no quede pendiente.
; Entrada/salida A = id pedido; Z = no tocar otro efecto este frame.
V9_ImpactGuard:
        or      a
        ret     z
        cp      10
        jr      nz,.check
        or      a                       ; una nueva embestida reinicia la pista
        ret
.check:
        push    af
        ld      a,(VGM_S0+18)
        or      a
        jr      z,.allow
        ld      a,(VGM_EFFECT)
        cp      10
        jr      nz,.allow
        pop     af
        xor     a
        ret
.allow: pop     af
        or      a
        ret

V9_BriefSound:
        ld      a,SND_SOS
        call    V9_SndPlay
        jp      V9_Lit
V9_BriefStop:
        xor     a
        call    V9_SndStop
        jp      V9_Dark
        endif
V9_IntroCarEnd:                         ; (por debajo de 9618h: vRndSeed)
