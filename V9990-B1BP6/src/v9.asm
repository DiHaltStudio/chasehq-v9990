; v9.asm -- codigo del V9990 del port, en la pagina 0 de RAM (libre en el original).
;
; Modo B1 con espacio de imagen de 512x1024 a 8 bpp y paleta de 64 colores (BP6):
;   x   0-255, y   0-63   marcador (uno solo)    x 256-511, y 0-63    imagenes del marcador ya
;                                                  pintadas (retratos, letras de la radio, turbos)
;   x   0-255, y  64-191  ventana de juego A      x 256-511, y 64-191  ventana B
;   x   0-511, y 192-211  negro (la pantalla muestra 212 lineas)
;   x 256-511, y 212-391  hoja de sprites comun    x 0-255, y 212-375  hoja del nivel
;   x 256-423, y 392-455  medidor de danos: sus 21 estados ya pintados
;   x 424-503, y 392-451  digitos del marcador ya pintados (hoja 13)
;   x   0-255, y 443-466  letras de la portada ya pintadas (hoja 14)
;   x 256-511, y  64-211  (portada) fondo de la portada, hoja 15 (assets/editable/menu_bg.png)
;   x 256-511, y  64-191  (aviso de nivel) imagen del monitor, hoja 16 (assets/editable/monitor.png)
;                                                  x 0-255, y 376-399  montanas del nivel
;                                                  x 0-255, y 400-442  fuentes, patrones,
;                                                                      retratos y ruido
;   x   0-511, y 468-1023 tiras de carretera (tools/mkstrips.py)
; La pantalla se parte con la interrupcion de linea del V9990 (V9_Isr): arriba el marcador
; (scroll 0,0) y desde la linea 64 la ventana que toca, cambiando solo el scroll horizontal
; (0 o 256) en el borrado horizontal de la linea 63: las ventanas empiezan en la fila 64 y
; la cuenta de lineas llega sola. El cambio de pagina es cambiar ese scroll horizontal
; (V9_Present); V9_FlipWait espera a que la interrupcion lo haya aplicado.
;
; Interrupciones: solo las del V9990 (retrazado vertical y linea 63), por IM 2 al vector
; de 18FF. La rutina (V9_Isr) usa pila propia y escribe registros del V9990, asi que el
; programa principal pone DI/EI alrededor de cada secuencia de escritura de registros.
; En el retrazado se aplican tambien los cambios de paleta pendientes.
V9_PAGE_B       equ 256                 ; x de la ventana B (la A esta en x 0)
V9_WIN_Y        equ 64                  ; la ventana de juego empieza en la linea 64 de la pagina
V9_STRIP_Y      equ 468
V9_STRIP_END    equ 1024                ; 556 filas: 278 tiras x 2 fases
V9_WMAX         equ 300                 ; anchuras de carretera con tira: 0..299 (de 256 en adelante, solo las pares)
V9_SKY          equ 6                   ; color del cielo
V9_WALL         equ 7                   ; color de la pared del tunel

; --- variables (1340-13BF). La zona 0000-00FF se deja libre: el original escribe ahi
;     (textos y sprites que se salen de su bufer por abajo; en el MSX1 era ROM de la BIOS)
vV9Draw         equ 1340h               ; ventana en la que se dibuja: byte alto de su x (0 o 1)
vV9FlipPend     equ 1342h               ; <> 0: cambio de pagina pedido y aun no aplicado
vV9Lop          equ 1341h               ; operacion logica (R#45) que tiene ahora el V9990
vV9Frames       equ 1343h               ; frames presentados (palabra)
vV9Desc         equ 1345h               ; descriptor del sprite en curso (palabra)
vV9Bank         equ 1347h               ; banco de ROM durante la subida de una hoja
vSpCw           equ 1348h               ; sprite: columnas (bytes) a dibujar
vSpMir          equ 1349h               ;         <> 0 espejado
vSpY            equ 134Ah               ;         linea de la ventana de su fila inferior
vSpCol          equ 134Bh               ;         columna (byte) de destino
vSpRows         equ 134Ch               ;         filas a dibujar
vSpK            equ 134Dh               ;         filas del bitmap ocultas por abajo
vSpSy           equ 134Eh               ;         y del bitmap en la hoja (palabra)
vSpLeft         equ 1350h               ;         mosaico: lineas que quedan por cubrir
vSpShift        equ 1351h               ;         <> 0: datos desplazados 4 px
vSpTile         equ 1358h               ;         <> 0: bitmap apilado (mosaico)
vSpH            equ 1359h               ;         alto del bitmap en la hoja
vSpDelta        equ 135Ah               ;         puntero recortado - T (palabra)
vSpStride       equ 135Ch               ;         bytes por fila en los datos del original
vV9Race         equ 135Fh               ; <> 0: en carrera (marcador por CMMM); 0 tras un volcado completo
vV9Popup        equ 1360h               ; <> 0: el texto emergente ha cambiado de color
vV9GeoSP        equ 1363h               ; SP guardado durante el trazado de bordes (palabra)
vV9GeoTop       equ 1365h               ; SP al acabar el trazado: su byte bajo es el indice de la linea mas alta escrita (palabra)
vTunY           equ 1367h               ; boca del tunel: linea de la ventana mas baja que queda por pintar
vTunCol         equ 1368h               ;                 color del relleno
vV9TunPal       equ 1369h               ; <> 0: paleta de dentro del tunel (arena en negro)
vFkPh           equ 136Ah               ; bifurcacion: fase de la banda (0/1)
vFkY            equ 136Bh               ;              linea de la pagina
vFkMid          equ 136Ch               ;              x de pantalla donde se pasa de una carretera a la otra
vFkSkip         equ 1361h               ; bifurcacion con la rama decidida: 0 se dibuja todo; 1 solo la carretera E8-EA y los objetos del lado B; 2 solo la EB-ED y los del lado A
vFkNX           equ 136Dh               ;              ancho del trozo
vV9PalPend      equ 136Eh               ; cambios de paleta pendientes del retrazado: bit 0 sirenas, bit 1 tunel
vV9IsrSP        equ 136Fh               ; SP del programa durante la interrupcion (palabra)
vShowHi         equ 137Fh               ; ventana que se muestra: byte alto de su x (0 o 1)
vHudZero        equ 1380h               ; <> 0: permitir dibujar el digito de las unidades del marcador
vV9Spd          equ 1371h               ; digitos de la velocidad dibujados en cada pagina, + 1 (2 x 3 bytes)
vSpSrc          equ 1377h               ; sprite: primera columna del bitmap a copiar
vRoadY          equ 137Eh               ; carretera: linea de la ventana de la ultima linea dibujada
vLaneTab        equ 13B0h               ; transicion de carril: direccion de la tabla del tope (palabra)
vLaneTop        equ 13B2h               ;                        tope del bufer de paso (palabra)
V9_LANEBUF      equ 00FEh               ; bufer de paso de los PUSH (hacia abajo; 0000-00FF no se usa)
vV9Lines        equ 1352h               ; subida de hojas: lineas que quedan (palabra)
vMtScroll       equ 1354h               ; montanas: scroll en pixeles
vHorY           equ 1355h               ; horizonte: primera linea de la ventana sin cielo
vV9Mon          equ 1362h               ; <> 0: monitor del aviso de nivel: de su ventana solo se mandan las barras de SIGNAL
vV9Dark         equ 135Eh               ; <> 0: pantalla en negro (paleta a 0) y sin sonido hasta que este lista la siguiente
V9_MSGP         equ 139Eh               ; puntero de la lista de letras de los mensajes (palabra, V9_PutLog)
V9_TURBO        equ 13A1h               ; turbo R: VI minimos entre dos presentaciones (0 = sin limite; lo pone rom.asm)
V9_TICK         equ 13A2h               ; VI desde la ultima presentacion (V9_Isr)
V9_CHEAT        equ 13A3h               ; <> 0: turbos infinitos (F1 pulsada al salir de la portada grande; lo pone rom.asm)
V9_MSGF         equ 13A0h               ; <> 0: ya se mando la primera letra del cuadro (V9_MsgChar)
V9_MSGL         equ 4800h               ; lista de letras: caracter, columna, fila (+ 80h si es de doble altura)
vV9MsgOn        equ 1381h               ; <> 0: el mensaje de la ventana lleva al menos un cuadro (V9_Msg)
vV9Pic          equ 1357h               ; <> 0: el monitor del aviso de nivel espera su imagen (V9_IntroPresent)
vWinDirty       equ 1356h               ; <> 0: el juego ha dibujado en la ventana desde el ultimo volcado completo
V9_CACHE        equ 1F00h               ; por celda de la pantalla Spectrum: resumen de sus 8 bytes y atributo (768 x 2)
V9_STACK        equ 18FEh               ; pila propia de la interrupcion (18C0-18FD)
V9_IVEC         equ 18FFh               ; vector IM 2: I = 18h, el bus da FFh -> 18FF-1900
V9_LANES        equ 2500h               ; codigo generado al arrancar: carriles, 104 lineas x 34 bytes (2500-32D2)
V9_FONT_Y       equ 400                 ; fuentes a 1 bpp en VRAM (x 0-255): digitos grandes en la
                                        ; linea 400, letras en la 401 (glifos 0-35) y la 402 (36-40)
V9_FONT_A       equ 20h                 ; su direccion de VRAM es 32000h: byte medio
V9_PAT_A        equ 26h                 ; patrones de byte repetido: desde la linea 403 (32600h)
V9_MTN_Y        equ 376                 ; tira de montanas del nivel: x 0-255, y 376-399 (hojas 8-12, assets/editable/mountains.png)
V9_SHEET_Y      equ 212                 ; primera linea de las hojas de sprites (T lleva y - 212)
; --- imagenes ya pintadas en VRAM (se copian con un solo LMMM en vez de varios comandos)
V9_PIC_PORT_X   equ 256                 ; caras de la radio, 32x40: x 256 + 32 * n, y 0-39 (hoja 7)
V9_PIC_RAD_X    equ 422                 ; letras de la radio, 9x6 con su papel (hoja 7): x 422-511, rejilla
                                        ; de 10 x 5 celdas; y 0-29 sin cursor, y 30-59 con cursor
V9_PIC_TURBO_Y  equ 40                  ; iconos de turbo: 3 tiras de 48x14 (x 256 + 48 * fotograma)
V9_METER_COL    equ 36                  ; color del contorno del medidor (palette.gpl: turquesa)
V9_PIC_METER_Y  equ 392                 ; medidor de danos: 21 estados de 8x64 (x 256 + 8 * golpes)
V9_PIC_DIG_X    equ 424                 ; digitos del marcador, 8x15 con su fondo (hoja 13): x 424 + 8 * digito,
V9_PIC_DIG_Y    equ 392                 ; y 392 + 15 * fila (puntos, tiempo, velocidad, distancia)
V9_NOISE_A      equ 72h                 ; ruido para el retrato: lineas 441-442
V9_FONT_HI      equ 3                   ; byte alto de la direccion de VRAM de todo lo anterior (3xxxxh)
; --- bloque de registros R#32-R#52 (byte bajo AND 3Fh = 32)
vV9RegB         equ 13E0h
; --- bloque de las copias de objetos: R#32-R#43 y, en +12, la operacion logica. Sus bytes
;     altos constantes (SX = 1xx; DX, NX y NY < 256) se ponen una vez, al arrancar.
vV9RegO         equ 13C0h
; --- bloque de las copias de imagenes ya pintadas (V9_SendH): R#32-R#45 (SX, SY, DX, DY,
;     NX, NY, ARG = 0 y operacion logica); R#52 = LMMM lo pone V9_SendH.
vV9RegH         equ 1390h

        code ! 0038h
        jp      V9_Isr                  ; (por si acaso; el juego va en IM 2 con el vector en 18FF)

        code ! 0100h
V9_Init:        jp      V9_DoInit       ; 0100: lo llama el puente al arrancar
V9_LoadSheet:   jp      V9_DoLoadSheet  ; 0103: lo llama el puente tras cargar un nivel


; ------------------------------------------------------------ carretera
; Entrada (desde Road_Draw, con su juego de registros principal): L = 2*y + 1, indice de
; la linea y (0-127) en las tablas de x por linea. Las paginas de las tablas de los
; bordes estan en los operandos Road_smcEdgePageL/R del original.
; Emite la linea y sigue en Road_NextLine. Conserva el juego principal y AF'. No usa la
; pila. Destruye AF y el juego alternativo (el original lo recarga en cada linea).
; El cuerpo va dos veces (macro), una por fase, para no pasar la fase como dato.
        macro   V9LINE phase
        ld      a,l
        exx
        ld      l,a                     ; L = indice de las tablas de bordes
        ld      a,(vRoadY)              ; la linea de pantalla NO sale del indice: en los
        dec     a                       ; cambios de rasante el original se salta entradas
        ld      (vRoadY),a              ; de las tablas, pero dibuja siempre la linea de
        add     a,V9_WIN_Y              ; encima de la anterior
        ld      b,a                     ; B = linea de la pagina
        ld      a,(Road_smcEdgePageL)
        ld      h,a
        ld      d,(hl)
        dec     l
        ld      e,(hl)                  ; DE = x del borde izquierdo (con signo)
        inc     l
        ld      a,(Road_smcEdgePageR)
        ld      h,a
        ld      a,(hl)
        dec     l
        ld      l,(hl)
        ld      h,a                     ; HL = x del borde derecho
        or      a
        sbc     hl,de                   ; HL = anchura W = xR - xL
        jp      m,.neg
        ld      a,h
        or      a
        jr      nz,.big
.wok:   add     hl,hl                   ; tabla por anchura (alineada a 256): SX base, fila
        add     hl,hl
        ld      a,h
        add     a,TV9W/256
        ld      h,a
        ld      a,(hl)
        inc     l
        sub     e
        ld      c,a                     ; SX = 264 - W/2 - xL (la columna 8 de pantalla)...
        ld      a,(hl)
        inc     l
        sbc     a,d
        and     1                       ; ...modulo 512
        ld      d,a
.wce:   in      a,(65h)
        rra
        jr      c,.wce
        ld      a,(hl)
        inc     l
        if phase
        inc     a                       ; fase 1: la fila siguiente (la base es par)
        endif
        ld      e,a                     ; E = SY bajo = fila de la tira + fase
        ld      a,(hl)                  ; A = SY alto
        call    V9_LineRegs
        exx
        dec     l                       ; como el original al dibujar el borde derecho
        jp      Road_NextLine
.neg:   ld      hl,0                    ; bordes cruzados: sin carretera
        jp      .wok
.big:   dec     a
        jr      nz,.max
        ld      a,l
        cp      V9_WMAX-256
        jr      nc,.max
        rra                             ; anchura impar: usa la tira de W - 1; si el borde
        jr      nc,.wok                 ; izquierdo queda fuera de pantalla, se ajusta al derecho
        bit     7,d
        jr      z,.wok
        inc     de
        jp      .wok
.max:   ld      hl,V9_WMAX-1
        jp      .wok
        endm

; Registros y orden de una linea: B = DY, C/D = SX, E/A = SY. DX, NX y NY se reescriben en cada
; linea: el V9990 real los deja alterados al acabar una orden (doc/06_openmsx_vs_real.md).
V9_LineRegs:
        di
        ld      h,a
        ld      a,32
        out     (64h),a
        ld      a,c
        out     (63h),a
        ld      a,d
        out     (63h),a                 ; R#32-33: SX
        ld      d,b
        ld      a,e
        out     (63h),a
        ld      a,h
        out     (63h),a                 ; R#34-35: SY
        ld      hl,TV9RoadRegs
        ld      c,63h
        outi
        outi                            ; R#36-37: DX (el byte alto, la ventana, lo deja V9_RoadSetup)
        ld      a,d
        out     (63h),a
        xor     a
        out     (63h),a                 ; R#38-39: DY
        inc     hl
        inc     hl
        ld      b,4
        otir                            ; R#40-43: NX = 240, NY = 1
        ld      a,52
        out     (64h),a
        ld      a,40h
        out     (63h),a                 ; LMMM
        ei
        ret
V9_LineBand:                            ; banda oscura: fase 1
        V9LINE  1
V9_LinePlain:                           ; banda clara: fase 0
        V9LINE  0

; Lineas de la bifurcacion (sustituyen a Fork_LinePlainGo / Fork_LineBandGo). Las tablas
; E8 y EA son los bordes de la carretera izquierda, y EB y ED los de la derecha. Cada una
; se dibuja con su tira por anchura (que es de 4 carriles: las de la bifurcacion tienen 2,
; asi que sale alguna linea de carril de mas), partiendo la pantalla en el punto medio
; entre las dos. Cambian DX y NX: en ese frame ya no hay mas lineas normales.
V9_ForkBand:
        ld      a,1
        jr      V9_Fork
V9_ForkPlain:
        xor     a
V9_Fork:
        ld      sp,(Road_smcSavedSP)    ; (SP no es de fiar dentro de Road_Draw)
        ld      (vFkPh),a
        ld      a,l
        exx
        ld      l,a
        ld      a,(vRoadY)
        dec     a
        ld      (vRoadY),a
        add     a,V9_WIN_Y
        ld      (vFkY),a
        push    hl
        ld      h,0EAh
        ld      d,(hl)
        dec     l
        ld      e,(hl)
        inc     l
        ld      h,0EBh
        ld      b,(hl)
        dec     l
        ld      c,(hl)
        ld      a,(vFkSkip)             ; rama decidida: solo la propia
        dec     a
        jr      z,.onlyL
        dec     a
        jr      z,.onlyR
        ld      a,b                     ; una de las dos entera fuera de la pantalla (16 px de
        or      a                       ; margen para el bordillo): una sola copia, la de la otra
        jp      m,.cl
        jr      nz,.onlyL               ; borde izquierdo de la derecha >= 256
.cl:    ld      hl,16
        add     hl,de
        bit     7,h
        jr      nz,.onlyR               ; borde derecho de la izquierda < -16
        ld      h,d
        ld      l,e
        add     hl,bc
        sra     h
        rr      l                       ; punto medio entre las dos carreteras
        ld      a,h
        or      a
        jp      m,.m0
        jr      nz,.m240
        ld      a,l
        cp      241
        jr      c,.mok
.m240:  ld      a,240
        jr      .mok
.m0:    xor     a
.mok:   add     a,8
        ld      (vFkMid),a
        pop     hl
        push    hl
        ld      h,0E8h
        ld      d,(hl)
        dec     l
        ld      e,(hl)
        inc     l
        ld      h,0EAh
        ld      a,(hl)
        dec     l
        ld      l,(hl)
        ld      h,a
        ld      b,8
        ld      a,(vFkMid)
        ld      c,a
        call    V9_ForkStrip
        pop     hl
        push    hl
        ld      h,0EBh
        ld      d,(hl)
        dec     l
        ld      e,(hl)
        inc     l
        ld      h,0EDh
        ld      a,(hl)
        dec     l
        ld      l,(hl)
        ld      h,a
        ld      a,(vFkMid)
        ld      b,a
        ld      c,248
        call    V9_ForkStrip
        pop     hl
        exx
        dec     l
        jp      Fork_NextLine
.onlyR: ld      a,0EBh
        jp      V9_ForkOne
.onlyL: ld      a,0E8h
        jp      V9_ForkOne

; Entrada de Road_Draw: guarda SP como hacia el original y deja en el V9990 lo comun a
; todas las lineas (ARG, LOP, mascara). Cada linea escribe SX, SY, DX, DY, NX y NY.
V9_RoadSetup:
        pop     hl
        ld      (Road_smcSavedSP),sp
        push    hl
        ld      a,128
        ld      (vRoadY),a              ; la primera linea que se dibuja es la 127
        call    V9_FlipWait
        call    V9_WaitCE
        ld      a,(vV9Draw)
        ld      (TV9RoadRegs+1),a       ; byte alto de DX = ventana
        di
        ld      a,36
        out     (64h),a
        ld      hl,TV9RoadRegs
        ld      bc,0C63h
        otir                            ; R#36-R#47
        ld      a,0Ch
        ld      (vV9Lop),a
        ei
        ret

; ------------------------------------------------------------ horizonte
; Montanas. Entrada (desde Mnt_SelectGfx, tras "ld a,scroll"): A = scroll (0-19, en pasos
; de 4 px sobre un dibujo ciclico de 80), D/E = direccion en el bufer del original de la
; linea siguiente a dibujar hacia arriba, Mnt_smcRows = filas visibles (las de arriba del
; dibujo; una colina tapa las de abajo). Dibuja las montanas y el cielo y sale de
; Road_Draw. La tira de montanas del nivel esta en VRAM (x 256-511, y V9_MTN_Y).
V9_Mountains:
        ld      sp,(Road_smcSavedSP)    ; pila normal (el original aun la tiene desviada)
        add     a,a
        add     a,a
        ld      (vMtScroll),a           ; scroll en pixeles: 0-76
        call    V9_HorizonY
        ld      a,(Mnt_smcRows)
        or      a
        jr      z,V9_SkyGo
        ld      c,a
        ld      a,(vHorY)
        sub     c
        jr      nc,.fit
        add     a,c                     ; no caben todas: solo las que hay hasta arriba
        ld      c,a
        xor     a
.fit:   ld      (vHorY),a               ; linea donde empiezan las montanas = fin del cielo
        ld      hl,TV9Mtn
        ld      de,vV9RegB
        push    bc
        ld      bc,21
        ldir
        pop     bc
        ld      a,c
        ld      (vV9RegB+10),a          ; NY
        ld      a,(vHorY)
        add     a,V9_WIN_Y
        ld      l,a
        ld      h,0
        ld      (vV9RegB+6),hl          ; DY
        ld      a,(vV9Draw)
        ld      (vV9RegB+5),a           ; DX: ventana
        ld      a,(vMtScroll)
        ld      (vV9RegB+0),a           ; SX = scroll
        cp      17
        jr      c,.one
        neg                             ; la tira mide 256: del scroll al final...
        ld      (vV9RegB+8),a           ; NX = 256 - scroll
        call    V9_SendB
        ld      a,(vMtScroll)
        neg
        add     a,8                     ; (256 - scroll) + 8
        ld      (vV9RegB+4),a           ; ...y el resto desde la posicion 16 (256 mod 80)
        ld      a,16
        ld      (vV9RegB+0),a
        ld      a,(vMtScroll)
        sub     16
        ld      (vV9RegB+8),a
.one:   call    V9_SendB
        jr      V9_SkyGo

; Cielo. Entrada (desde Sky_Fill): D/E = direccion en el bufer de la linea siguiente.
; Rellena desde arriba de la ventana hasta esa linea (negro dentro del tunel) y sale de
; Road_Draw.
V9_Sky: ld      sp,(Road_smcSavedSP)
        ld      a,(vRoadY)              ; sin montanas: el cielo llega justo hasta la linea
        ld      (vHorY),a               ; mas alta de carretera (ni la pisa ni deja hueco)
V9_SkyGo:
        ld      hl,Tun_smcMode
        ld      a,(Road_smcTunnel)
        or      (hl)
        rra
        ld      c,V9_SKY
        jr      nc,.col
        ld      c,1                     ; tunel: negro
.col:   ld      a,(vHorY)
        or      a
        ret     z
        ld      e,0
; Relleno del cielo: A lineas desde la linea E de la ventana, color C.
V9_SkyFill:
        ld      (vV9RegB+10),a          ; NY
        push    bc
        push    de
        ld      hl,TV9Sky
        ld      de,vV9RegB
        ld      bc,10
        ldir
        pop     de
        pop     bc
        ld      hl,vV9RegB+12
        ld      (hl),0                  ; ARG
        inc     hl
        ld      (hl),0Ch                ; copia
        ld      a,e
        add     a,V9_WIN_Y
        ld      (vV9RegB+6),a           ; DY
        xor     a
        ld      (vV9RegB+7),a
        ld      a,(vV9Draw)
        ld      (vV9RegB+5),a           ; DX: ventana
        ld      a,c
        ld      (vV9RegB+16),a
        ld      (vV9RegB+17),a
        ld      a,20h
        ld      (vV9RegB+20),a
        jp      V9_SendB

; vHorY = linea de la ventana (0-128) siguiente a la ultima dibujada hacia arriba, a
; partir de la direccion del bufer del original: D = F0 + (y AND 15), E = (y / 16) * 32.
V9_HorizonY:
        ld      a,e
        rlca
        rlca
        rlca
        and     7
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      c,a
        ld      a,d
        and     15
        add     a,c
        ld      (vHorY),a
        ret

; ------------------------------------------------------------ sprites escalados
; Sustituye al dibujador del original desde Spr_CheckMask, con el recorte horizontal ya
; hecho. Entrada: A = columnas a dibujar; F: C = con mascara, NZ = espejado; B = columna
; (byte) de destino; C = columnas del fotograma que se saltan (por la izquierda, o por la
; derecha si va espejado); E = ancho del fotograma en bytes; HL -> descriptor + 1;
; IY -> tablas de Y de la fila (IY+0 = Y base, IY+53 = Y limite); Spr_YOffset+1,
; Spr_Mode+1 y Spr_ShiftSel+1 como en el original.
; El recorte vertical es el del original (Spr_ClipY), linea por linea; en vez de punteros
; a datos se saca la posicion del bitmap en la hoja (T) y se emite una copia.
; Sale como el original: sin dibujar, con el juego de registros de entrada; si dibuja,
; con el otro.
V9_Sprite:
        ld      (vSpCw),a
        ld      a,1Ch                   ; copia sin el color 0: tambien los fotogramas sin
        ld      (vV9RegO+12),a          ; mascara llevan transparente lo de fuera de su silueta
        ld      a,b
        ld      (vSpCol),a
        ld      a,c
        jr      z,.src
        ld      a,(vSpCw)               ; espejado: en la hoja (ya volteada) es ancho - saltadas - dibujadas
        add     a,c
        ld      d,a
        ld      a,e
        sub     d
        ld      (vSpSrc),a
        ld      a,1
        jr      .mir
.src:   ld      (vSpSrc),a
        xor     a
.mir:   ld      (vSpMir),a
        inc     hl                      ; -> alto
.yoff:  ld      a,(Spr_YOffset+1)
        ld      d,a
        ld      a,(iy+0)
        sub     (iy+53)
        jr      nz,.adj
.base:  ld      a,(iy+53)
        add     a,d
        ret     m
        ld      (vSpY),a
        inc     a
        ld      d,(hl)
        sub     d
        jr      c,.b1
        xor     a
.b1:    add     a,d                     ; filas = min(alto, y + 1)
        ld      (vSpRows),a
        xor     a
        ld      (vSpK),a
        jr      .desc
.adj:   bit     7,d
        jr      nz,.a1
        sub     d
        jp      .a2
.a1:    add     a,d
.a2:    ld      d,a                     ; lineas del fotograma ocultas por abajo
        jp      z,.base
        jp      m,.base
        ld      a,(iy+53)
        ld      (vSpY),a
        ld      a,(hl)
        dec     a
        sub     d
        jp      nc,.top
        ld      a,(Spr_Mode+1)          ; oculto entero: solo sigue el mosaico, con el
        and     a                       ; siguiente trozo hacia arriba
        ret     z
        ld      a,(Spr_YOffset+1)
        ld      d,(hl)
        sub     d
        ret     p
        ld      (Spr_YOffset+1),a
        ld      a,(Spr_TileLeft+1)
        sub     d
        ret     c
        ret     z
        ld      (Spr_TileLeft+1),a
        jr      .yoff
.top:   inc     a
        ld      (vSpRows),a             ; filas = alto - ocultas
        ld      a,d
        ld      (vSpK),a
.desc:  ld      a,(vSpCw)               ; 0 columnas: recortado del todo (y NX = 0 seria
        or      a                       ; un comando de ancho maximo)
        ret     z
        ld      b,(hl)                  ; alto del fotograma
        inc     hl
        inc     hl
        ld      a,(hl)                  ; +4: byte alto de T
        cp      40h
        ret     nc                      ; descriptor sin convertir: no se dibuja
        ld      d,a
        ld      a,(Spr_ShiftSel+1)      ; el original elegiria los datos desplazados 4 px:
        rra                             ; el segundo T (+5), que lleva el bit 14 si existen
        jr      c,.t2
        dec     hl
        ld      e,(hl)
        inc     hl
        inc     hl
        inc     hl
        ld      a,(hl)                  ; +6: solo interesa el bit 7 (apilado)
        and     80h
        ld      c,a
        jr      .t
.t2:    inc     hl
        ld      e,(hl)
        inc     hl
        ld      a,(hl)
        ld      c,a
        and     3Fh
        ld      d,a
.t:     ld      a,c
        and     40h
        ld      (vSpShift),a            ; <> 0: el bitmap va 4 px desplazado
        bit     7,c
        ld      a,0
        jr      z,.h
        ld      a,b                     ; apilado para el mosaico: alto de la pila
        add     a,TV9Stack-(TV9Stack/256*256)
        ld      l,a
        ld      a,TV9Stack/256
        adc     a,0
        ld      h,a
        ld      b,(hl)
        ld      a,1
.h:     ld      (vSpTile),a
        ld      a,b
        ld      (vSpH),a
        ld      a,(Spr_Mode+1)
        dec     a
        jp      z,.exitT                ; (modo 1, volteo vertical: pendiente)
        ld      a,(vSpSrc)
        push    de
        exx
        pop     de                      ; DE = T
        ld      l,a
        ld      a,(Spr_Mode+1)
        cp      2
        ld      a,l
        jp      z,.sx                   ; mosaico vertical: camino general
        ; --- camino directo (una copia): todo en registros y a los puertos
        ld      a,(vSpMir)              ; el blitter espejado escribe una columna mas a la derecha
        ld      h,a
        ld      a,(vSpCol)
        add     a,h
        ld      h,a                     ; H = columna de destino
        ld      a,(vSpCw)
        ld      c,a                     ; C = columnas
        ld      a,h
        or      a                       ; las columnas 0 y 31 no se ven
        jr      nz,.fr
        inc     l
        inc     h
        dec     c
        ret     z
        ld      a,h
.fr:    cp      31
        ret     nc
        ld      a,31
        sub     h
        cp      c
        jr      nc,.ff
        ld      c,a
.ff:    ld      a,d                     ; SX = 256 + (x de la hoja + columna) * 8
        and     3Eh
        rrca
        add     a,l
        add     a,a
        add     a,a
        add     a,a
        ld      l,a                     ; L = SX (byte bajo)
        ld      a,c
        add     a,a
        add     a,a
        add     a,a
        ld      b,a                     ; B = NX
        ld      a,h
        add     a,a
        add     a,a
        add     a,a
        ld      c,a                     ; C = DX
        ld      a,(vSpShift)            ; datos desplazados: +4 px (-4 si va espejado)
        or      a
        jr      z,.fd
        ld      a,(vSpMir)
        or      a
        jr      nz,.fsl
        ld      a,c
        add     a,4
        ld      c,a
        add     a,b
        jr      c,.fcut
        cp      249
        jr      c,.fd
.fcut:  ld      a,b
        sub     4
        ld      b,a
        jr      .fd
.fsl:   ld      a,c
        sub     4
        ld      c,a
        cp      8
        jr      nc,.fd
        ld      c,8
        ld      a,l
        add     a,4
        ld      l,a
        ld      a,b
        sub     4
        ld      b,a
.fd:    ld      a,(vSpRows)
        ld      h,a
        ld      a,(vSpY)                ; no salirse por arriba de la ventana
        inc     a
        cp      h
        jr      nc,.fy
        ld      h,a
.fy:    inc     h
        dec     h
        ret     z                       ; H = filas
        call    V9_FlipWait
.fw:    in      a,(65h)
        rra
        jr      c,.fw
        di
        ld      a,32
        out     (64h),a
        ld      a,l
        out     (63h),a
        ld      a,d
        and     1
        out     (63h),a                 ; SX (byte alto = lado de la hoja)
        ld      a,(vSpK)
        add     a,h
        ld      l,a
        ld      a,(vSpH)
        sub     l                       ; alto - ocultas - filas
        add     a,e                     ; + byte bajo de T
        ld      l,a
        ld      a,0
        adc     a,0
        ld      e,a
        ld      a,l
        add     a,V9_SHEET_Y-(V9_SHEET_Y/256*256)
        out     (63h),a
        ld      a,e
        adc     a,V9_SHEET_Y/256
        out     (63h),a                 ; SY = 212 + lo anterior
        ld      a,c
        out     (63h),a
        ld      a,(vV9Draw)
        out     (63h),a                 ; DX (byte alto = ventana)
        ld      a,(vSpY)
        sub     h
        add     a,V9_WIN_Y+1
        out     (63h),a
        xor     a
        out     (63h),a                 ; DY = 64 + linea inferior - filas + 1
        ld      a,b
        out     (63h),a
        xor     a
        out     (63h),a                 ; NX
        ld      a,h
        out     (63h),a
        xor     a
        out     (63h),a                 ; NY
        ld      a,(vV9RegO+12)          ; operacion logica: solo si cambia
        ld      hl,vV9Lop
        cp      (hl)
        jr      z,.fo
        ld      (hl),a
        ld      b,a
        ld      a,45
        out     (64h),a
        ld      a,b
        out     (63h),a
.fo:    ld      a,52
        out     (64h),a
        ld      a,40h
        out     (63h),a
        ei
        ret
.sx:    ld      l,a                     ; L = primera columna del bitmap a copiar
        ld      a,(vSpMir)              ; el blitter espejado escribe una columna mas a la derecha
        ld      h,a
        ld      a,(vSpCol)
        add     a,h
        ld      h,a                     ; H = columna de destino
        ld      a,(vSpCw)
        ld      c,a                     ; C = columnas
        ld      a,h                     ; las columnas 0 y 31 del bufer no se ven:
        or      a                       ; se recorta a las columnas 1-30
        jr      nz,.right
        inc     l
        inc     h
        dec     c
        ret     z
.right: cp      31
        ret     nc
        ld      a,31
        sub     h                       ; columnas que caben
        cp      c
        jr      nc,.fits
        ld      c,a
.fits:  ld      a,d                     ; SX = lado * 256 + (x de la hoja + columna) * 8
        and     3Eh
        rrca
        add     a,l
        add     a,a
        add     a,a
        add     a,a
        ld      (vV9RegO+0),a
        ld      a,d
        and     1
        ld      (vV9RegO+1),a           ; lado de la hoja (bit 8 de T)
        ld      a,c                     ; NX = columnas * 8
        add     a,a
        add     a,a
        add     a,a
        ld      b,a                     ; B = NX
        ld      a,h                     ; DX = columna * 8; +4 (o -4 si va espejado) con datos desplazados
        add     a,a
        add     a,a
        add     a,a
        ld      c,a
        ld      a,(vSpShift)
        or      a
        jr      z,.dx
        ld      a,(vSpMir)
        or      a
        jr      nz,.shl
        ld      a,c                     ; +4: no pasar de la columna 247
        add     a,4
        ld      c,a
        add     a,b
        jr      c,.cut
        cp      249
        jr      c,.dx
.cut:   ld      a,b
        sub     4
        ld      b,a
        jr      .dx
.shl:   ld      a,c                     ; -4: no bajar de la columna 8
        sub     4
        ld      c,a
        cp      8
        jr      nc,.dx
        ld      c,8
        ld      a,(vV9RegO+0)
        add     a,4
        ld      (vV9RegO+0),a
        ld      a,b
        sub     4
        ld      b,a
.dx:    ld      a,c
        ld      (vV9RegO+4),a
        ld      a,(vV9Draw)
        ld      (vV9RegO+5),a           ; DX: ventana
        ld      a,b
        ld      (vV9RegO+8),a
        ld      a,e                     ; y de la hoja = 212 + byte bajo de T
        add     a,V9_SHEET_Y-(V9_SHEET_Y/256*256)
        ld      l,a
        ld      a,V9_SHEET_Y/256
        adc     a,0
        ld      h,a
        ld      (vSpSy),hl
        ld      a,(Spr_Mode+1)
        cp      2
        jr      nz,.blit                ; modo 0: una copia y vuelve
        ; modo 2, mosaico vertical: el fotograma se repite hacia arriba hasta cubrir
        ; Spr_TileLeft lineas; el primer trozo empieza en la fila ya recortada
        ld      a,(Spr_TileLeft+1)
        ld      (vSpLeft),a
        ld      a,(vSpTile)             ; apilado: el primer trozo llega hasta arriba de la pila
        or      a
        jr      z,.tile
        ld      a,(vSpK)
        ld      c,a
        ld      a,(vSpH)
        sub     c
        ld      (vSpRows),a
.tile:  ld      a,(vSpLeft)
        ld      c,a
        ld      a,(vSpRows)
        cp      c
        jr      c,.tgo
        ld      a,c
        ld      (vSpRows),a
.tgo:   call    .blit
        ld      hl,vSpRows
        ld      a,(vSpLeft)
        sub     (hl)
        ret     z
        ld      (vSpLeft),a
        ld      a,(vSpY)
        sub     (hl)
        ret     c                       ; se sale por arriba de la ventana
        ld      (vSpY),a
        xor     a
        ld      (vSpK),a
        ld      a,(vSpTile)
        or      a
        ld      a,(Spr_TileHeight+1)
        jr      z,.th
        ld      a,(vSpH)                ; apilado: trozos de la pila entera
.th:    ld      (vSpRows),a
        jr      .tile
; Copia vSpRows filas del bitmap (saltando vSpK por abajo) con la inferior en vSpY.
.blit:  ld      a,(vSpRows)
        ld      c,a
        ld      a,(vSpY)                ; no salirse por arriba de la ventana
        inc     a
        cp      c
        jr      nc,.rows
        ld      c,a
.rows:  ld      a,c
        or      a
        ret     z
        ld      (vV9RegO+10),a          ; NY
        ld      a,(vSpK)
        add     a,c
        ld      b,a
        ld      a,(vSpH)
        sub     b                       ; SY = y de la hoja + alto - saltadas - filas
        ld      e,a
        ld      d,0
        ld      hl,(vSpSy)
        add     hl,de
        ld      (vV9RegO+2),hl
        ld      a,(vSpY)                ; DY = 64 + linea inferior - filas + 1
        sub     c
        add     a,V9_WIN_Y+1
        ld      l,a
        ld      h,0
        ld      (vV9RegO+6),hl
        jp      V9_SendObj
.exitT: exx
        ret

; ------------------------------------------------------------ hojas de sprites
; Sube a la VRAM (x 256-511, desde y = 0) la hoja del nivel vLevel (1-5), desde sus 3
; bancos de ROM. La CPU escribe la VRAM: solo al cargar un nivel, nunca durante el juego.
; Entrada: todo RAM. Conserva DE e IX. Deja todo RAM.
V9_DoLoadSheet:
        di                              ; (las subidas escriben registros; EI en la siguiente
        ld      a,(vLevel)              ; presentacion o volcado)
        cp      6
        ret     nc
        ld      a,(vLevel)
        add     a,7                     ; hojas 8-12: las montanas del nivel
        call    V9_LoadSheetA
        ld      a,(vLevel)
; A = hoja: 0 la comun, 1-5 la del nivel, 6 el panel, 7 la radio, 8-12 las montanas de los
; niveles 1-5. Tabla TV9Sheets (build/sheets.inc, build/mountains.inc).
V9_LoadSheetA:
        push    de
        ld      e,a
        add     a,a
        add     a,a
        add     a,e                     ; 5 bytes por hoja
        ld      e,a
        ld      d,0
        ld      hl,TV9Sheets
        add     hl,de
        ld      a,(hl)
        ld      (vV9Bank),a
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; DE = primera linea
        inc     hl
        ld      c,(hl)
        inc     hl
        ld      b,(hl)                  ; BC = lineas
        ld      (vV9Lines),bc
        call    V9_WaitCE
        ld      a,(vV9Dark)
        or      a
        push    af
        call    z,V9_Dark               ; pantalla en negro y sin sonido mientras sube (salvo que ya lo este
                                        ; todo el cambio de pantalla): no se ve cargar
        ld      a,SLOT_C1
        call    SlotSet                 ; cartucho en la pagina 1
.bank:  ld      a,(vV9Bank)
        ld      (6000h),a
        inc     a
        ld      (vV9Bank),a
        ld      hl,4000h
.line:  xor     a                       ; direccion de escritura = y*512 + lado*256
        out     (64h),a
        out     (63h),a                 ; R#0
        ld      a,d
        rlca                            ; bit 15 de y0: mitad derecha
        and     1
        ld      c,a
        ld      a,e
        add     a,a
        or      c
        out     (63h),a                 ; R#1
        ld      a,e
        rlca
        and     1
        ld      c,a
        ld      a,d
        and     7Fh
        add     a,a
        or      c
        out     (63h),a                 ; R#2
        ld      bc,0060h
        otir                            ; 256 bytes al puerto de VRAM
        inc     de
        ld      bc,(vV9Lines)
        dec     bc
        ld      (vV9Lines),bc
        ld      a,b
        or      c
        jr      z,.end
        ld      a,h
        cp      80h
        jr      nz,.line
        jr      .bank
.end:   ld      a,SLOT_RAM
        call    SlotSet
        pop     af
        call    z,V9_Lit                ; (con la interrupcion de retrazado pendiente: la atiende el
        pop     de                      ; llamador al hacer EI, dentro del retrazado)
        ret

; ------------------------------------------------------------ sprites sin escalar
; Sustituye a Spr_DrawMasked. Entrada: E = X en pixeles (se redondea a 8), D = linea de la
; ventana de la fila inferior, HL = datos del original, B = alto, C = ancho en bytes;
; B' bit 0 = espejado. Sin recorte, como el original. Vuelve con el mismo juego de
; registros activo.
V9_Unscaled:
        ld      a,e
        and     0F8h
        ld      (vV9RegO+4),a           ; DX
        ld      a,c
        add     a,a
        add     a,a
        add     a,a
        ld      (vV9RegO+8),a           ; NX
        ld      a,d
        ld      (vSpY),a
        ld      a,b
        ld      (vSpRows),a
        exx
        ld      a,b
        exx
        and     1
        ld      (vSpMir),a
        ld      a,1Ch                   ; con mascara
; HL = datos del original, A = operacion logica; DX, NX, vSpY, vSpRows y vSpMir puestos.
V9_UnsGo:
        ld      (vV9RegO+12),a
        ex      de,hl                   ; DE = puntero original
        ld      h,TV9UnsIdx/256         ; cadena de las entradas con su byte bajo
        ld      l,e
        ld      a,(hl)
        inc     h
        ld      h,(hl)
        ld      l,a
        ld      a,h
        or      a
        ret     z                       ; sprite no convertido: no se dibuja
.srch:  ld      a,(hl)
        cp      e
        ret     nz
        inc     hl
        ld      a,(hl)
        inc     hl
        cp      d
        jr      z,.found
        inc     hl
        inc     hl
        inc     hl
        inc     hl
        jr      .srch
.found: ld      a,(vSpMir)
        or      a
        jr      z,.tn
        inc     hl
        inc     hl
.tn:    ld      e,(hl)
        inc     hl
        ld      d,(hl)
.t:     ld      a,d
        cp      40h
        ret     nc
        and     3Eh                     ; SX = lado * 256 + x de la hoja
        add     a,a
        add     a,a
        ld      (vV9RegO+0),a
        ld      a,d
        and     1
        ld      (vV9RegO+1),a
        ld      a,e                     ; SY = 212 + byte bajo de T
        add     a,V9_SHEET_Y-(V9_SHEET_Y/256*256)
        ld      l,a
        ld      a,V9_SHEET_Y/256
        adc     a,0
        ld      h,a
        ld      (vV9RegO+2),hl
        ld      a,(vV9Draw)
        ld      (vV9RegO+5),a           ; DX: ventana
        ld      a,(vSpRows)
        ld      (vV9RegO+10),a          ; NY
        ld      c,a
        ld      a,(vSpY)                ; DY = 64 + linea inferior - filas + 1
        sub     c
        add     a,V9_WIN_Y+1
        ld      l,a
        ld      h,0
        ld      (vV9RegO+6),hl
        jp      V9_SendObj

; Carroceria del coche del jugador (opaca, 5 bytes de ancho). Sustituyen a las llamadas
; de Car_DrawBody a los blitters opacos. Juego activo: HL = direccion de destino en el
; bufer del original (H = F0 + (y AND 15), L = (y / 16) * 32 + columna; la variante
; espejada llega con L - 1). El otro juego: HL = datos, B = alto. Salen como los
; blitters: con el otro juego activo.
V9_CarBodyM:
        inc     l
        ld      a,1
        jr      V9_CarBodyGo
V9_CarBody:
        xor     a
V9_CarBodyGo:
        ld      (vSpMir),a
        ld      a,l
        and     31
        add     a,a
        add     a,a
        add     a,a
        ld      (vV9RegO+4),a           ; DX = columna * 8
        ld      a,l
        rlca
        rlca
        rlca
        and     7
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      c,a
        ld      a,h
        and     15
        or      c
        ld      (vSpY),a
        ld      a,40
        ld      (vV9RegO+8),a           ; NX
        exx
        ld      a,b
        ld      (vSpRows),a
        ld      a,0Ch                   ; opaca
        jp      V9_UnsGo

; ReadJoystick del original (la ROM de pruebas lo usa) sin interrupciones: lee el PSG.
V9_JoyRead:
        call    V9_Iff
        di
        push    af
        push    bc
        push    ix
        jp      ReadJoystick+3
V9_JoyEnd:
        pop     ix
        pop     bc
        ld      (VGM_END),a             ; (byte libre tras las variables del sonido)
        pop     af
        ld      a,(VGM_END)
        ret     po
        ei
        ret

; ------------------------------------------------------------ frame
; Presentacion (sustituye a VDP_Present): pide mostrar la ventana recien dibujada y pasa
; a dibujar en la otra. No espera: la interrupcion de la linea 63 (V9_Isr) pone el scroll
; horizontal de la ventana que toque (vShowHi). Antes de volver a dibujar en la ventana
; que aun se ve hay que esperar a que lo haya hecho (V9_FlipWait); con la logica del
; juego por medio, casi nunca hay que parar.
V9_Present:
        call    V9_IntOn
        if ORIG_INPUT = 0
        ld      a,(vFxState)            ; un mensaje en la ventana (TIME UP, CONTINUE...)
        or      a
        jr      z,.nomsg
        call    V9_Msg
        jr      .msgd
.nomsg: ld      (vV9MsgOn),a            ; (A = 0)
.msgd:
        endif
        call    V9_FlipWait             ; (dos presentaciones seguidas)
        ; marcador (antes de pedir el cambio de pagina, para no esperarlo)
        xor     a
        ld      (vV9Mon),a              ; (ya no hay monitor)
        ld      a,(vV9Dark)
        dec     a
        call    z,V9_Lit                ; primer cuadro de la carrera (tras el aviso, o sin el); 2 = fundido final
        call    V9_HudRace
        call    V9_TunPal
        call    V9_WaitCE
        ld      a,(vV9Draw)
        ld      (vShowHi),a
        ld      a,1
        ld      (vV9FlipPend),a
        ld      a,(vV9Draw)
        xor     1
        ld      (vV9Draw),a
        ld      hl,(vV9Frames)
        inc     hl
        ld      (vV9Frames),hl
        ld      a,1
        ld      (vWinDirty),a
        if ORIG_INPUT = 0
        ld      a,(V9_TURBO)            ; turbo R: no mas de un paso del juego cada V9_TURBO retrazados
        or      a
        jp      nz,V9_Limit
        endif
        ret

; Iconos de turbo (sustituye a Hud_Turbos): vTurbos iconos de 16x14 desde la columna 8,
; con la base en la linea 126 de la ventana; el ultimo se anima mientras dura el turbo. Una
; sola copia del final de la tira de su fotograma (V9_TurboPre), que tiene 3 iconos.
V9_Turbos:
        ld      a,(vTurbos)
        and     a
        jp      z,Hud_Speed
        cp      4
        jr      c,.n
        ld      a,3
.n:     ld      c,a                     ; C = iconos (1-3)
        ld      a,(vTurboTimer)
        and     a
        jr      z,.fr                   ; sin turbo: icono quieto (fotograma 0)
        ld      a,(Hud_TurboAnim+1)     ; (el contador del original)
        inc     a
        cp      3
        jr      c,.st
        xor     a
.st:    ld      (Hud_TurboAnim+1),a
.fr:    ld      b,a
        add     a,a
        add     a,b
        add     a,3
        sub     c
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      h,1
        ld      (vV9RegH+0),hl          ; SX = 256 + 48 * fotograma + 48 - 16 * iconos
        ld      hl,V9_PIC_TURBO_Y
        ld      (vV9RegH+2),hl
        ld      a,(vV9Draw)
        ld      h,a
        ld      l,8
        ld      (vV9RegH+4),hl          ; DX = 8 en la ventana
        ld      hl,V9_WIN_Y+126-14+1
        ld      (vV9RegH+6),hl
        ld      a,c
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      h,0
        ld      (vV9RegH+8),hl          ; NX = 16 * iconos
        ld      l,14
        ld      (vV9RegH+10),hl
        ld      a,1Ch
        ld      (vV9RegH+13),a
        call    V9_SendH
        jp      Hud_Speed

; ------------------------------------------------------------ portico
; Banda horizontal del portico (continua Obj_DrawSpan desde 90FC). El original escribe, en
; cada linea y de abajo arriba, un mismo byte de patron en todas las columnas de la banda.
; En VRAM hay, para cada valor de byte, 30 bytes iguales (lineas 215-246, 8 valores por
; linea): cada linea de la banda es una expansion (CMMM) de NX x 1.
; Entrada: HL -> altura, puntero al patron; C = columna izquierda; B = lineas; en la pila,
; AF con A = linea inferior de la ventana.
V9_Span:
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; DE = patron (un byte por linea)
        pop     af
        ld      (vTunY),a
        ld      a,(Obj_SpanJump+1)
        neg
        add     a,3Ch
        srl     a                       ; columnas
        ret     z
        add     a,a
        add     a,a
        add     a,a
        ld      (vV9RegB+8),a           ; NX
        ld      a,c
        add     a,a
        add     a,a
        add     a,a
        ld      (vV9RegB+4),a           ; DX
        ld      a,(vV9Draw)
        ld      (vV9RegB+5),a           ; ventana
        xor     a
        ld      (vV9RegB+7),a
        ld      (vV9RegB+9),a
        ld      (vV9RegB+11),a
        inc     a
        ld      (vV9RegB+10),a          ; NY = 1
        ld      (vV9RegB+16),a          ; tinta: negro
        ld      (vV9RegB+17),a
        ld      a,V9_FONT_HI
        ld      (vV9RegB+3),a           ; direccion del patron: byte alto
        ld      a,8                     ; papel: el de los sprites
        ld      (vV9RegB+18),a
        ld      (vV9RegB+19),a
        ld      hl,0C00h
        ld      (vV9RegB+12),hl
        ld      hl,0FFFFh
        ld      (vV9RegB+14),hl
        ld      a,70h                   ; CMMM
        ld      (vV9RegB+20),a
.line:  ld      a,(de)
        and     7
        rrca
        rrca
        rrca                            ; (valor AND 7) * 32
        ld      (vV9RegB+0),a
        ld      a,(de)
        rrca
        rrca
        and     3Eh                     ; (valor / 8) * 2
        add     a,V9_PAT_A
        ld      (vV9RegB+2),a
        ld      a,(vTunY)
        add     a,V9_WIN_Y
        ld      (vV9RegB+6),a
        push    bc
        push    de
        call    V9_SendB
        pop     de
        pop     bc
        inc     de
        ld      hl,vTunY
        dec     (hl)
        ret     m                       ; (no pasar de la linea 0)
        djnz    .line
        ret

; ------------------------------------------------------------ tunel
; Boca del tunel (continua Tun_DrawMouth desde L_C21A). El original rellena por lineas, de
; abajo arriba y en palabras de 16 px: D lineas de pared a los lados del hueco, luego el
; dintel a todo lo ancho y, segun Tun_smcTopFill, el resto hasta arriba. Aqui cada bloque
; es un relleno. Se conserva su aritmetica de lineas (A' = cuenta hasta el borde superior,
; B' = escala de la rodaja) y con que juego de registros sale.
; Entrada: A = cuenta, D = lineas de pared, HL = fin de la linea inferior en el bufer del
; original, C = bytes entre el fin de linea y el fin de la pared izquierda.
V9_TunWall:
        ex      af,af'
        ld      a,l
        dec     a
        ld      e,a
        rlca
        rlca
        rlca
        and     7
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      b,a
        ld      a,h
        and     15
        add     a,b
        ld      (vTunY),a               ; linea inferior de la pared
        ld      a,e
        and     31
        inc     a
        ld      e,a                     ; E = columna (byte) siguiente a la ultima: 31 o 32
        ld      a,(Tun_smcMode)
        dec     a
        ld      a,V9_WALL               ; modo 1: pared vista desde fuera
        jr      z,.col
        ld      a,1                     ; modo 2: negro (la salida vista desde dentro)
.col:   ld      (vTunCol),a
        ld      b,d                     ; B = lineas de pared
        ld      a,(Tun_smcJrLeft)
        cp      16h
        jr      nz,.two
        ld      hl,011Fh                ; pared entera: columnas 1-30
        call    .rect
        jr      .lint
.two:   neg
        add     a,16
        add     a,a                     ; bytes de la pared derecha
        ld      d,a
        ld      a,e
        sub     d
        ld      h,a
        ld      l,e
        call    .rect
        ld      a,e
        sub     c
        ld      l,a                     ; fin de la pared izquierda
        ld      a,(Tun_smcJrRight)
        neg
        add     a,16
        add     a,a
        ld      d,a
        ld      a,l
        sub     d
        ld      h,a
        call    .rect
.lint:  call    .up
        exx
        srl     b
        ld      a,b
        srl     b
        srl     b
        sub     b
        ld      b,a                     ; lineas de dintel
        ex      af,af'
        and     a
        ret     m                       ; la pared llego arriba
        add     a,b
        jp      p,.l1
        ld      e,a
        sub     81h
        neg
        add     a,b
        ld      b,a
        ld      a,e
.l1:    ex      af,af'
        ld      a,b
        exx
        ld      b,a
        ld      hl,011Fh
        call    .rect
        call    .up
        ex      af,af'
        and     a
        ret     m
        cpl
        add     a,82h
        ld      b,a                     ; lineas que quedan hasta arriba
        ld      a,(Tun_smcTopFill)
        and     a
        ld      c,V9_SKY
        jr      z,.top
        dec     a
        ret     nz
        ld      c,1
.top:   ld      a,c
        ld      (vTunCol),a
        ld      hl,011Fh
; Relleno de las columnas H..L-1 (bytes; se recorta a 1-30), B lineas hacia arriba desde
; vTunY. Conserva BC y DE.
.rect:  ld      a,b
        or      a
        ret     z
        ld      a,h
        dec     a
        cp      30
        jr      c,.r1
        ld      h,1                     ; (0 o negativo)
.r1:    ld      a,l
        cp      32
        jr      c,.r2
        ld      l,31
.r2:    ld      a,l
        sub     h
        ret     z
        ret     c
        add     a,a
        add     a,a
        add     a,a
        ld      (vV9RegB+8),a           ; NX
        ld      a,h
        add     a,a
        add     a,a
        add     a,a
        ld      (vV9RegB+4),a           ; DX
        ld      a,(vV9Draw)
        ld      (vV9RegB+5),a           ; ventana
        xor     a
        ld      (vV9RegB+9),a
        ld      (vV9RegB+11),a
        ld      a,(vTunY)
        inc     a
        sub     b
        ld      h,b
        jr      nc,.r3
        add     a,h                     ; no pasar de la linea 0
        ld      h,a
        ret     z
        xor     a
.r3:    add     a,V9_WIN_Y
        ld      (vV9RegB+6),a           ; DY
        ld      a,h
        ld      (vV9RegB+10),a          ; NY
        xor     a
        ld      (vV9RegB+7),a
        ld      hl,0C00h
        ld      (vV9RegB+12),hl
        ld      hl,0FFFFh
        ld      (vV9RegB+14),hl
        ld      a,(vTunCol)
        ld      (vV9RegB+16),a
        ld      (vV9RegB+17),a
        ld      a,20h                   ; LMMV
        ld      (vV9RegB+20),a
        push    bc
        push    de
        call    V9_SendB
        pop     de
        pop     bc
        ret
.up:    ld      a,(vTunY)               ; las B lineas pintadas quedan por debajo
        sub     b
        ld      (vTunY),a
        ret

; Dentro del tunel lo que no es carretera va en negro: se cambian los dos colores de la
; arena en la paleta (las tiras y los sprites no cambian). Una vez por frame.
V9_TunPal:
        ld      a,(vInTunnel)
        or      a
        jr      z,.st
        ld      a,1
.st:    ld      hl,vV9TunPal
        cp      (hl)
        ret     z
        ld      (hl),a
        ld      hl,vV9PalPend
        set     1,(hl)
        ret
V9_TunPalSet:
        ld      a,(vV9TunPal)
        or      a
        ld      a,14
        out     (64h),a
        ld      a,2*4
        out     (63h),a
        ld      hl,TV9Pal+6
        ld      bc,0661h
        jr      nz,.in
        otir
        ret
.in:    xor     a
.z:     out     (61h),a
        djnz    .z
        ret

; ------------------------------------------------------------ interrupcion
; Solo llegan las del V9990 (IM 2, vector en 18FF): retrazado vertical (VI) y linea 63 (HI).
; Pila propia desde la primera instruccion: la del juego es de 40 bytes y, dentro de la
; geometria del original, SP puede apuntar a una tabla (el retorno de la interrupcion,
; 2 bytes, cae en una entrada que se va a escribir despues; ver doc/04_port.md).
; Escribe registros del V9990, asi que el programa principal lleva DI/EI alrededor de cada
; secuencia de escritura de registros.
; Habilita las interrupciones del V9990 en IM 2 (vector en V9_IVEC: la BIOS y las
; variables del juego ocupan todo lo demas). Lo llaman la presentacion y el volcado
; completo: el menu del original pone IM 2 (Int_Setup) y el juego hace DI en varios
; sitios, asi que se repone cada vez. Hasta aqui R#9 esta a 0: ninguna interrupcion.
V9_IntOn:
        di
        ld      a,V9_IVEC/256
        ld      i,a
        im      2
        ld      a,9
        out     (64h),a
        ld      a,3                     ; R#9: interrupciones de linea y de retrazado
        out     (63h),a
        ei
        ret

V9_Isr: ld      (vV9IsrSP),sp
        ld      sp,V9_STACK
        push    af
        in      a,(66h)
        rra
        jr      nc,.hi
        ; --- retrazado vertical: arriba el marcador, y los cambios de paleta pendientes
        push    bc
        push    de
        push    hl
        ld      a,17
        out     (64h),a
        xor     a
        out     (63h),a                 ; R#17: scroll vertical 0
        ld      a,20
        out     (64h),a
        xor     a
        out     (63h),a                 ; R#20: scroll horizontal 0
        if DIAG
        ld      a,(vSlotCur)            ; (make diag-rom) vigila los registros de pantalla (esta en la
        or      a                       ; pagina 2: no mientras el puente tiene ahi el cartucho)
        call    z,V9_DiagVb
        endif
        if ORIG_INPUT = 0
        ld      hl,V9_TICK
        inc     (hl)
        endif
        ld      hl,vV9PalPend
        ld      a,(vV9Dark)             ; en negro (src/dark.asm) nada se escribe en la paleta: las sirenas
        or      a                       ; siguen parpadeando (Hud_FlashBlock) y se verian; los cambios
        jr      nz,.snd                 ; quedan pendientes para cuando V9_Lit la reponga
        ld      a,(hl)
        ld      (hl),0
        rra
        push    af
        call    c,V9_SirenPal
        pop     af
        rra
        call    c,V9_TunPalSet
.snd:   ld      a,(vSlotCur)            ; sonido (src/sound.asm), si las paginas estan como
        or      a                       ; siempre (no a media carga de un nivel)
        call    z,V9_SndTick
        pop     hl
        pop     de
        pop     bc
        ld      a,1
        out     (66h),a
        jr      .x
        ; --- linea 63: en su borrado horizontal, el scroll horizontal de la ventana que
        ; se muestra. El vertical no se toca: la cuenta sigue sola (linea 64 = fila 64,
        ; donde empiezan las ventanas). Escribir R#17 aqui reiniciaba la cuenta en la
        ; linea en que se escribia, y cuando la interrupcion llegaba tarde (un tramo DI
        ; del programa principal dura hasta 2 lineas) la ventana entera bajaba 1 o 2
        ; lineas. Si el scroll horizontal llega tarde solo cambia de pagina 1 o 2 filas
        ; de cielo, iguales en las dos.
.hi:    in      a,(65h)
        bit     6,a
        jr      nz,.ha                  ; ya en el retrazado: llega tarde, no se toca el scroll
        and     20h
        jr      nz,.hi
.hb:    in      a,(65h)
        and     20h
        jr      z,.hb
        ld      a,(vV9Race)
        or      a
        jr      z,.hx                   ; fuera de la carrera se ve la pagina A entera
        ld      a,20
        out     (64h),a
        ld      a,(vShowHi)
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a                     ; R#20 = x / 8: 0 o 32
        out     (63h),a
.hx:    xor     a
        ld      (vV9FlipPend),a         ; el cambio de pagina ya se ve (o ya no hay carrera)
.ha:    ld      a,2
        out     (66h),a
.x:     pop     af
        ld      sp,(vV9IsrSP)
        ei
        ret

; ------------------------------------------------------------ geometria
; Fin de Geo_DDA: como el original, y anota hasta donde ha escrito la tabla.
V9_DDAExit:
        ld      (vV9GeoTop),sp
        ld      sp,(vV9GeoSP)
        ret

; Sustituye a Geo_DDASteep: rodaja en la que x avanza mas de 1 px por linea. El original
; da los pasos de uno en uno (por linea: sumar C al error hasta llegar a L, y restar L).
; Es lo mismo que avanzar q = L / C pixeles por linea, y uno mas cuando el error es menor
; que el resto r = L mod C; el error pasa a ser error - r (+ C si hubo paso de mas).
; Entrada: A = 13h (x crece) o 1Bh (decrece), B = C = lineas, L = |dx| > C, DE = x; SP
; apunta a la tabla (un PUSH por linea). Sale como el original: DE = x, B = 0.
V9_Steep:
        ld      h,a
        ld      a,c
        dec     a
        jr      nz,.gen
        ; una sola linea: x +- |dx|
        ld      a,h
        cp      1Bh
        ld      h,0
        jr      nz,.one
        xor     a
        sub     l
        ld      l,a
        dec     h
.one:   add     hl,de
        ex      de,hl
        push    de
        jr      .next
.gen:   ld      a,h
        cp      1Bh
        ld      a,23h                   ; inc hl
        jr      nz,.sg
        ld      a,2Bh                   ; dec hl
.sg:    ld      (.step),a
        ld      a,l
        ld      l,0
.div:   sub     c
        inc     l
        cp      c
        jr      nc,.div                 ; L = q, A = r
        ld      h,a
        ld      a,c
        sub     h
        ld      (.cr+1),a               ; C - r
        ld      c,h                     ; C = r
        ld      a,(.step)
        cp      2Bh
        ld      h,0
        jr      nz,.q
        xor     a
        sub     l
        ld      l,a
        dec     h                       ; HL = -q
.q:     ex      de,hl                   ; HL = x, DE = paso por linea
        xor     a
.ln:    add     hl,de
        cp      c
        jr      nc,.nq
.step:  inc     hl
.cr:    add     a,0
        push    hl
        djnz    .ln
        jr      .end
.nq:    sub     c
        push    hl
        djnz    .ln
.end:   ex      de,hl
        ld      b,0
.next:  exx
        dec     b
        jp      nz,Geo_DDASlice
        jp      V9_DDAExit

; Transiciones de carril del original (Lane_Transition): regeneran un tramo de una tabla
; de bordes con un DDA que escribe con PUSH (SP = direccion en la tabla). Con las
; interrupciones activas eso pisaria la tabla, asi que los PUSH van a un bufer de paso en
; 0000-00FE (zona que no se usa para nada mas) y al salir el tramo se copia a su sitio.
; vLaneTab = direccion de la tabla que corresponde a vLaneTop (el tope del bufer).
V9_LaneIn:
        xor     a                       ; (sin tocar HL: el original entra con H = pagina
        ld      (vLaneTab),a            ;  de la tabla, que usa cuando bit 5 de flags = 0)
        ld      (vLaneTab+1),a          ; 0: no ha habido DDA
        ld      a,iyl
        cp      13h
        jp      Lane_TransitionGo
V9_LaneSP1a:
        call    V9_LaneSP
        ld      d,(hl)
        dec     l
        jp      0C339h
V9_LaneSP1b:
        call    V9_LaneSP
        ld      d,(hl)
        dec     l
        jp      0C377h
V9_LaneSP2a:
        call    V9_LaneSP
        dec     h
        ld      d,(hl)
        jp      0C3ADh
V9_LaneSP2b:
        call    V9_LaneSP
        dec     h
        ld      d,(hl)
        jp      0C3E9h
; Sin tocar AF: el original sigue usando A despues del "ld sp,hl" (sub b).
V9_LaneSP:
        ld      (vLaneTab),hl           ; (la pila es la del juego: la llamada es valida)
        ex      (sp),hl                 ; HL = direccion de vuelta
        ld      sp,V9_LANEBUF
        ld      (vLaneTop),sp
        push    hl
        ld      hl,(vLaneTab)
        ret
V9_LaneAdj:
        inc     sp                      ; (asi lo hace el original: direcciones impares)
        ld      hl,vLaneTop
        inc     (hl)                    ; (00FE -> 00FF, sin acarreo)
        ld      hl,(vLaneTab)
        inc     hl                      ; en 16 bits: con L = FF el original pasa de pagina
        bit     5,(ix+0)
        jr      z,.k
        dec     h                       ; tabla de la otra pagina (- 256)
.k:     ld      (vLaneTab),hl
        jp      0C413h
V9_LaneOut:
        ld      hl,(vLaneTab)
        ld      a,h
        or      l
        jr      z,.x
        ld      hl,0
        add     hl,sp                   ; HL = SP: principio del tramo en el bufer
        ex      de,hl
        ld      hl,(vLaneTop)
        or      a
        sbc     hl,de                   ; HL = bytes escritos
        ld      b,h
        ld      c,l
        ld      hl,(vLaneTab)
        sbc     hl,bc                   ; (CF = 0) destino = tabla - bytes
        ex      de,hl                   ; HL = bufer, DE = tabla
        ld      a,b
        or      c
        jr      z,.x
        ldir
.x:     ld      sp,(Road_smcSavedSP)
        ld      hl,Road_SetupDefault
        jp      Road_SetupStore

; Principio del bucle de carriles de Road_GeomNormal (ya ha guardado SP). El original
; recorre los indices 30h..FEh (lineas 24-127); aqui se empieza una linea por encima de
; la mas alta que ha escrito el trazado del borde izquierdo (una mas, para que el acarreo
; que cada linea pasa a la siguiente sea el del original). Las de arriba conservan los
; carriles de cuando se trazaron.
V9_GeomStart:
        pop     hl                      ; (no se vuelve al bucle del original)
        ld      a,(vV9GeoTop)
        sub     2                       ; (ninguna linea escrita: 0 - 2 = FEh, solo la ultima)
        cp      30h
        jr      nc,V9_LaneGo
        ld      a,30h
V9_LaneGo:                              ; A = indice (>= 30h) de la primera linea
        sub     30h
        ld      l,a
        ld      h,0
        ld      e,a
        ld      d,h
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,de                   ; 34 bytes por linea (el indice va de 2 en 2)
        ld      bc,V9_LANES
        add     hl,bc
        jp      (hl)

; Una linea del bucle de carriles del original (Road_GeomLine), con direcciones fijas en
; vez de operandos automodificados: mismas operaciones y mismo acarreo de una linea a la
; siguiente. V9_DoInit la copia 104 veces en V9_LANES (indices 30h..FEh), cambiando el
; byte bajo de las cuatro direcciones, y pone detras "jp Road_GeomExit".
TV9Lane:
        ld      de,(0E800h)             ; +2: borde izquierdo
        ld      hl,(0EC00h)             ; +5: borde derecho (sin POP: puede llegar una interrupcion)
        sbc     hl,de
        sra     h
        rr      l
        ld      b,h
        ld      c,l
        add     hl,de
        ld      (0EA00h),hl             ; +17: centro
        ld      d,b
        ld      e,c
        sra     b
        rr      c
        add     hl,bc
        ld      (0EB00h),hl             ; +27: carril derecho
        sbc     hl,de
        ld      (0E900h),hl             ; +32: carril izquierdo
TV9LaneEnd:

; ------------------------------------------------------------ marcador en carrera
; El original escribe digitos y letras en su pantalla Spectrum; en carrera el port los
; dibuja ademas en las dos paginas con CMMM: el V9990 expande el glifo (1 bpp, subido a la
; VRAM al arrancar) con la tinta y el papel del atributo de la celda. La CPU no da pixeles.
; No se refrescan la linea de radio ni las luces de las sirenas.
V9_HudRace:
        ld      a,(vV9Race)
        or      a
        ret     nz
        inc     a
        ld      (vV9Race),a
        jp      V9_HudRedraw            ; primer frame tras un volcado completo

; Luces de las sirenas. El original las hace parpadear invirtiendo el brillo de los
; atributos de dos bloques de 5x4 celdas (Hud_FlashBlock). En el panel pregenerado
; (assets/editable/hud_panel.png) las cupulas van en los colores 48-55 (la izquierda) y
; 56-63 (la derecha). El parpadeo es solo reescribir esos 16 colores: con brillo en la
; primera celda del bloque izquierdo, la izquierda encendida y la derecha apagada
; (TV9Sir1), y si no al reves (TV9Sir0). La paleta solo se escribe durante el retrazado
; vertical (V9_PalPoll).
V9_Flash2:
        call    Hud_FlashBlock          ; (el segundo bloque)
        ld      hl,vV9PalPend
        set     0,(hl)
        ret
V9_SirenPal:
        ld      a,(ZXAttrs+20h)
        and     40h
        ld      hl,TV9Sir0
        jr      z,.set
        ld      hl,TV9Sir1
.set:   ld      a,14
        out     (64h),a
        ld      a,48*4
        out     (63h),a
        ld      bc,3061h                ; colores 48-63
        otir
        ret

; A = atributo Spectrum -> tinta (FC) y papel (BC) en vV9RegB. Conserva BC y DE.
V9_AttrCol:
        ld      h,tAttrToTMS/256
        ld      l,a
        ld      a,(hl)
        ld      l,a
        and     15
        add     a,32
        ld      (vV9RegB+18),a
        ld      (vV9RegB+19),a
        ld      a,l
        rrca
        rrca
        rrca
        rrca
        and     15
        add     a,32
        ld      (vV9RegB+16),a
        ld      (vV9RegB+17),a
        ret

; Prepara en vV9RegB la expansion de un glifo de 8 x A lineas en la pagina A. DE = direccion de su primera linea
; en la pantalla Spectrum (tercio superior). La direccion del glifo en VRAM (19 bits) ya
; esta en vV9RegB: byte bajo en +0 (R#32), medio en +2 (R#34) y alto en +3 (R#35).
V9_GlyphSetup:
        ld      (vV9RegB+10),a
        ld      h,ZXAttrs/256
        ld      l,e
        ld      a,(hl)
        call    V9_AttrCol
        ld      a,e
        and     31
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      h,0
        ld      (vV9RegB+4),hl          ; DX = columna * 8
        ld      a,e
        rlca
        rlca
        rlca
        and     7
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      a,d
        and     7
        add     a,l
        ld      l,a
        ld      (vV9RegB+6),hl          ; DY = fila * 8 + linea
        ld      hl,8
        ld      (vV9RegB+8),hl          ; NX
        xor     a
        ld      (vV9RegB+11),a
        ld      hl,0C00h
        ld      (vV9RegB+12),hl         ; ARG = 0, copia
        ld      hl,0FFFFh
        ld      (vV9RegB+14),hl
        ld      a,70h                   ; CMMM
        ld      (vV9RegB+20),a
        ret

; Entrada de Hud_Speed: la velocidad solo se recalcula y se dibuja un frame de cada dos.
V9_SpeedGate:
        ld      a,(vV9Frames)
        and     1
        jr      nz,.skip
        ld      de,4132h
        jp      Hud_SpeedGo
.skip:  exx                             ; como deja los juegos de registros el original
        jp      Hud_SpeedEnd

; Sustituye a la entrada de Hud_BigDigit: A = digito, DE' = pantalla. Cada digito es una copia
; de su imagen ya pintada (V9_DigCopy, assets/editable/hud_digits.png). En carrera no hace
; nada si ese digito ya esta dibujado ahi.
V9_BigDigit:
        exx
        ld      c,a
        ld      a,(vV9Race)
        or      a
        jr      z,.out
        ld      a,e
        sub     32h
        cp      3
        jr      nc,.both
        ; velocidad (4132-4134): el original la redibuja en cada frame; solo si cambia
        ld      l,a                     ; A = 0-2
        ld      h,0
        push    de
        ld      de,vV9Spd
        add     hl,de
        pop     de
        ld      a,(hl)
        dec     a
        cp      c
        jr      z,.skip
        ld      a,c
        inc     a
        ld      (hl),a
        jr      .draw
        ; resto (marcador, tiempo, distancia): el original solo llama cuando cambia
.both:  ld      a,e
        cp      2Dh                     ; unidades del marcador: siempre 0 (se dibuja una vez)
        jr      nz,.draw
        ld      a,(vHudZero)
        or      a
        jr      z,.skip
        ld      c,0
.draw:  push    bc
        push    de
        call    V9_DigCopy
        pop     de
        pop     bc
.orig:  ld      a,c
        ld      b,0
        jp      Hud_BigDigitGo
.skip:  inc     e
        exx
        ret
; fuera de la carrera la pantalla Spectrum se ve por celdas: dibuja el original, sus dos
; celdas pasan a la cache (para que no se vuelvan a mandar) y encima va la copia
.out:   push    bc
        call    .orig                   ; (vuelve con el EXX del original hecho)
        exx
        pop     bc
        push    de
        dec     e
        push    bc
        push    de
        call    V9_DigCells
        pop     de
        pop     bc
        call    V9_DigCopy
        pop     de
        exx
        ret

; Sustituye a la entrada de Txt_GlyphPlain: HL = glifo en tFont, DE = pantalla.
V9_GlyphPlain:
        ld      a,(vV9Race)
        or      a
        jr      z,.orig
        ld      a,d
        and     0F8h
        cp      40h
        jr      nz,.orig
        push    hl
        push    de
        ld      bc,10000h-tFont
        add     hl,bc                   ; desplazamiento en la fuente
        ld      a,h
        or      a
        jr      nz,.hi
        ld      a,l
        cp      252
        jr      c,.lo
.hi:    ld      bc,512-252              ; del glifo 36 en adelante: linea siguiente
        add     hl,bc
.lo:    ld      a,h
        add     a,V9_FONT_A+2
        ld      h,V9_FONT_HI
        ld      (vV9RegB+0),hl          ; (R#33 no cuenta)
        ld      l,a
        ld      (vV9RegB+2),hl
        ld      a,7
        call    V9_GlyphSetup
        call    V9_SendB
        pop     de
        pop     hl
.orig:  push    de
        ld      b,7
        jp      Txt_GlyphPlainGo

; Texto de puntos emergente (fila 3, columnas 8-12): cuando el original le cambia el
; color, se borra y se vuelve a escribir (el color sale del atributo).
V9_PopupAttr:
        ld      a,1
        ld      (vV9Popup),a
        ld      hl,ZXAttrs+68h
        ret
V9_PopupRedraw:
        ld      a,(vV9Popup)
        or      a
        jr      z,.no
        xor     a
        ld      (vV9Popup),a
        ld      a,(vV9Race)
        or      a
        jr      z,.no
        ld      a,(ZXAttrs+68h)
        call    V9_AttrCol
        ld      a,(vV9RegB+18)
        ld      (vV9RegB+16),a
        ld      (vV9RegB+17),a
        ld      hl,64
        ld      (vV9RegB+4),hl          ; DX
        ld      l,25
        ld      (vV9RegB+6),hl          ; DY
        ld      l,40
        ld      (vV9RegB+8),hl          ; NX
        ld      l,7
        ld      (vV9RegB+10),hl         ; NY
        ld      hl,0C00h
        ld      (vV9RegB+12),hl
        ld      hl,0FFFFh
        ld      (vV9RegB+14),hl
        ld      a,20h                   ; LMMV
        ld      (vV9RegB+20),a
        call    V9_SendB
        ld      hl,(Hud_PopupPtr+1)
        ld      de,4168h
        call    Txt_Print
.no:    ld      hl,vHudGear
        ret

; Unidades del bonus de tiempo (sustituye al tramo con el bug de Game_StBonus).
; Entrada: C = tiempo restante en BCD. Suma unidades x 500 y escribe el digito.
V9_BonusUnits:
        ld      a,c
        and     0Fh
        jr      z,.digit
        ld      b,a
        push    af
        ld      de,0050h                ; 500 puntos
.add:   xor     a
        call    Score_Add
        djnz    .add
        pop     af
.digit: add     a,30h
        ld      (tMsgBonusUnits),a
        jp      Game_BonusDone

V9_WaitCE:
        in      a,(65h)
        rra
        jr      c,V9_WaitCE
        ret

; Si hay un cambio de pagina pedido, espera a que la interrupcion de la linea 63 lo haya
; aplicado (si las interrupciones estan inhibidas, no espera).
V9_FlipWait:
        ld      a,(vV9FlipPend)
        or      a
        ret     z
        call    V9_Iff
        ret     po
.w:     ld      a,(vV9FlipPend)
        or      a
        jr      nz,.w
        ret

; Envia el bloque vV9RegB (21 registros) cuando el blitter queda libre.
V9_SendB:
        call    V9_FlipWait
        call    V9_WaitCE
        di
        ld      hl,vV9RegB
        ld      a,32
        out     (64h),a
        ld      bc,1563h
        otir
        ei
        ld      a,(vV9RegB+13)
        ld      (vV9Lop),a
        ret

; Envia una copia (LMMM) con SX, SY, DX, DY, NX y NY de vV9RegB y la operacion logica de
; vV9RegB+13, que solo se escribe si cambia. El resto de registros no se toca.
V9_SendObj:
        call    V9_FlipWait
        ld      hl,vV9RegO
        ld      c,63h
.wce:   in      a,(65h)
        rra
        jr      c,.wce
        di
        ld      a,32
        out     (64h),a
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        ld      a,(vV9Lop)
        ld      b,a
        ld      a,(vV9RegO+12)
        cp      b
        jr      z,.op
        ld      (vV9Lop),a
        ld      b,a
        ld      a,45
        out     (64h),a
        ld      a,b
        out     (63h),a
.op:    ld      a,52
        out     (64h),a
        ld      a,40h
        out     (63h),a
        ei
        ret

; ------------------------------------------------------------ pantalla Spectrum
; Emite la celda BC (0-767; fila*32 + columna) en las dos paginas si han cambiado sus 8
; bytes o su atributo desde la ultima vez. Conserva BC.
V9_CellN:
        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        add     a,40h
        ld      h,a
        ld      l,c                     ; HL = linea 0 de la celda en la pantalla Spectrum
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
        ld      a,(vV9Mon)              ; monitor del aviso de nivel: la ventana es la imagen; solo
        or      a                       ; se mandan las barras de SIGNAL (filas 16 y 18, columnas 23-30)
        jr      z,.draw
        ld      a,b
        or      a
        jr      z,.draw
        cp      2
        ret     nz
        ld      a,c
        and     0A0h
        ret     nz
        ld      a,c
        and     31
        cp      23
        ret     c
        cp      31                      ; (la columna 31 es el borde del marco)
        ret     nc
.draw:  push    bc
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
        ld      (vV9RegB+4),hl          ; DX = columna * 8
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
        call    .send                   ; pagina A
        pop     bc
        ld      a,b                     ; las filas 0-7 (marcador; celdas 0-255) solo estan
        or      a                       ; en la A
        ret     z
        push    bc
        ld      a,1
        ld      (vV9RegB+5),a           ; ventana B: x + 256
        call    .send
        xor     a
        ld      (vV9RegB+5),a
        pop     bc
        ret
.send:  push    bc
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

; Volcado completo de la pantalla Spectrum (sustituye a VDP_DumpScreen).
V9_DumpScreen:
        ld      a,8                     ; fuera de la carrera: motor callado
        out     (0A0h),a
        xor     a
        out     (0A1h),a
        ld      (vV9Race),a
        ld      (vV9FlipPend),a         ; (fuera de la carrera se ve siempre la pagina A)
        ld      hl,vV9PalPend
        set     0,(hl)                  ; (lo aplica la interrupcion)
        call    V9_IntOn
        xor     a
        ld      hl,vV9Spd               ; velocidad: ningun digito dibujado
        ld      b,6
.dig:   ld      (hl),a
        inc     hl
        djnz    .dig
        ld      a,(vWinDirty)
        or      a
        jr      z,.go
        xor     a                       ; el juego dibujo en la ventana: sus celdas, a refrescar
        ld      (vWinDirty),a
        ld      hl,V9_CACHE+512+1
        ld      bc,512
.inv:   ld      (hl),0FFh               ; atributo imposible
        inc     hl
        inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,.inv
.go:    ld      bc,0
.cell:  call    V9_CellN
        inc     bc
        ld      a,b
        cp      3
        jr      nz,.cell
        ret

; Sustituye a VDP_CopyCells: B celdas desde la de HL (linea 0 en la pantalla Spectrum).
; Sale con L avanzado y H igual, como la original.
V9_CopyCells:
        push    hl
        push    de
        ld      d,b
        ld      a,b
        cp      60                      ; las 60 celdas de la linea de radio: la mitad en
        jr      nz,.all                 ; cada refresco del marcador (frames alternos)
        ld      d,30
        ld      a,(vV9Frames)
        and     2
        jr      z,.all
        ld      a,l
        add     a,30
        ld      l,a
.all:
        ld      a,h
        sub     40h
        rrca
        rrca
        rrca
        and     3
        ld      b,a
        ld      c,l
.cell:  push    de
        call    V9_CellN
        pop     de
        inc     bc
        dec     d
        jr      nz,.cell
        pop     de
        pop     hl
        ld      l,c
        ret

; Sustituye a VDP_CopyColors: A filas de 4 celdas desde la del atributo HL.
V9_CopyColors:
        ld      d,a
        ld      a,h
        sub     58h
        ld      b,a
        ld      c,l
.row:   push    de
        push    bc
        call    V9_CellN
        inc     bc
        call    V9_CellN
        inc     bc
        call    V9_CellN
        inc     bc
        call    V9_CellN
        pop     bc
        ld      a,c
        add     a,32
        ld      c,a
        jr      nc,.next
        inc     b
.next:  pop     de
        dec     d
        jr      nz,.row
        ret

; Sube E bytes de HL a la VRAM, direccion 30000h + D*256 (lineas de fuentes). Avanza HL.
V9_FontUp:
        xor     a
        out     (64h),a
        out     (63h),a                 ; R#0
        ld      a,d
        out     (63h),a                 ; R#1
        ld      a,V9_FONT_HI
        out     (63h),a                 ; R#2
        ld      b,e
        ld      c,60h
        otir
        ret

; ------------------------------------------------------------ arranque
; Lo llama el puente con el banco de tablas del V9990 en 4000-7FFF y DI.
V9_PalLoad:                             ; colores 0-47 (las sirenas, 48-63, las pone V9_SirenPal)
        ld      a,14
        out     (64h),a
        xor     a
        out     (63h),a
        ld      hl,TV9Pal
        ld      b,TV9PalEnd-TV9Pal
.palo:  ld      a,(hl)
        inc     hl
        out     (61h),a
        djnz    .palo
        ld      a,14                    ; colores 32-47: la paleta del TMS9918
        out     (64h),a
        ld      a,32*4
        out     (63h),a
        ld      b,TV9PalTmsEnd-TV9PalTms
.palt:  ld      a,(hl)
        inc     hl
        out     (61h),a
        djnz    .palt
        ret

V9_DoInit:
        ld      a,2                     ; reinicio del V9990
        out     (67h),a
        xor     a
        out     (67h),a
        ld      hl,TV9Regs
.regs:  ld      a,(hl)
        inc     hl
        cp      0FFh
        jr      z,.pal
        out     (64h),a
        ld      a,(hl)
        inc     hl
        out     (63h),a
        jr      .regs
.pal:   call    V9_InitDark             ; (ROM normal: en negro y sin sonido hasta que este la portada)
        ld      hl,V9_CACHE             ; cache de celdas: todo por pintar
        ld      de,V9_CACHE+1
        ld      bc,768*2-1
        ld      (hl),0FFh
        ldir
        xor     a
        ld      (vWinDirty),a
        ; toda la VRAM a 0
        ld      hl,TV9Clear
        ld      de,vV9RegB
        ld      bc,21
        ldir
        call    V9_SendB
        call    V9_StripsLoop           ; tiras de carretera (tambien tras la secuencia final)
        call    V9_WaitCE
        xor     a                       ; hoja comun y sprites del nivel 1
        call    V9_LoadSheetC
        ld      a,1
        call    V9_LoadSheetC
        ld      a,6                     ; panel del marcador
        call    V9_LoadSheetC
        ld      a,7                     ; caras y letras de la radio (antes que las tiras de
        call    V9_LoadSheetC           ; los turbos, que van debajo, en y 40-53)
        ld      a,8                     ; montanas del nivel 1
        call    V9_LoadSheetC
        ld      a,13                    ; digitos del marcador (antes que los estados del
        call    V9_LoadSheetC           ; medidor, que van al lado, en x 256-423)
        ld      a,14                    ; letras de la portada
        call    V9_LoadSheetA
        call    V9_HudInit
        ld      a,SLOT_C1
        call    SlotSet
        ; estado inicial: se ve la pagina A, se dibuja en la B
        ; fuentes a 1 bpp (la imagen del juego ya esta en RAM)
        ld      hl,Fnt_BigDigits
        ld      de,V9_FONT_A*256+150
        call    V9_FontUp
        ld      hl,tFont
        ld      de,(V9_FONT_A+2)*256+252
        call    V9_FontUp
        ld      de,(V9_FONT_A+4)*256+35
        call    V9_FontUp
        ; patrones de byte repetido (para el portico): 32 bytes por valor
        ld      d,V9_PAT_A
        ld      c,0                     ; valor
.pat:   xor     a
        out     (64h),a
        out     (63h),a
        ld      a,d
        out     (63h),a
        ld      a,V9_FONT_HI
        out     (63h),a
        ld      e,8
.pat8:  ld      b,32
        ld      a,c
.pat1:  out     (60h),a
        djnz    .pat1
        inc     c
        dec     e
        jr      nz,.pat8
        inc     d
        inc     d
        ld      a,c
        or      a
        jr      nz,.pat
        ; codigo de carriles desenrollado
        ld      de,V9_LANES
        ld      a,30h
.lane:  ld      hl,TV9Lane
        ld      bc,TV9LaneEnd-TV9Lane
        push    de
        ldir
        pop     ix
        ld      (ix+2),a
        ld      (ix+5),a
        ld      (ix+17),a
        ld      (ix+27),a
        ld      (ix+32),a
        add     a,2
        jr      nz,.lane
        ex      de,hl
        ld      (hl),0C3h
        inc     hl
        ld      (hl),Road_GeomExit-(Road_GeomExit/256*256)
        inc     hl
        ld      (hl),Road_GeomExit/256
        xor     a
        ld      (vV9RegO+5),a
        ld      (vV9RegO+9),a
        ld      (vV9RegO+11),a
        inc     a
        ld      (vV9RegO+1),a
        xor     a
        ld      (vV9PalPend),a
        ld      (vShowHi),a
        ld      (vHudZero),a
        ld      (vV9TunPal),a
        ld      (vV9Race),a
        ld      (vV9Mon),a
        ld      (vV9Popup),a
        ld      (vV9RegH+12),a          ; ARG de las copias de V9_SendH
        ld      hl,VGM_S0               ; sonido: pistas paradas, volumenes a 0
        ld      de,VGM_S0+1
        ld      bc,VGM_MUTE-VGM_S0-1    ; (hasta VGM_FCNT; VGM_MUTE lo ha puesto V9_InitDark)
        ld      (hl),a
        ldir
        ld      a,3Fh
        ld      (VGM_REG+7),a
        call    V9_TurboPre
        call    V9_MeterPre
        ld      a,1
        ld      (vV9Draw),a
        xor     a
        ld      (vV9FlipPend),a
        ld      hl,0
        ld      (vV9Frames),hl
        ld      a,10
        out     (64h),a
        ld      a,63                    ; R#10-12: interrupcion de linea en la 63 (el scroll
        out     (63h),a                 ; se escribe en su borrado horizontal y vale desde
        xor     a                       ; la 64)
        out     (63h),a
        out     (63h),a
        ld      a,7
        out     (66h),a                 ; borra avisos pendientes (V9_IntOn las habilita)
        ld      a,8                     ; pantalla activa, sin cursor
        out     (64h),a
        ld      a,0C2h
        out     (63h),a
        ret
; Las tiras de carretera: 556 filas de rellenos (formato en tools/mkstrips.py), con su tabla en 4000h (el
; cartucho en la pagina 1 con el banco BANK_V9 del puente). Desde V9_DoInit y desde V9_StripsUp, que las
; repinta tras la secuencia final (sus imagenes van en esa zona de la VRAM).
V9_StripsLoop:
        ld      hl,TV9Fill
        ld      de,vV9RegB
        ld      bc,21
        ldir
        ld      ix,4000h                ; tabla de rellenos (banco de datos)
        ld      de,V9_STRIP_Y           ; fila
.row:   ld      a,(ix+0)
        inc     ix
        ld      b,a
.run:   push    bc
        ld      a,(ix+0)
        ld      (vV9RegB+4),a           ; DX bajo
        ld      a,(ix+2)
        and     1
        ld      (vV9RegB+5),a
        ld      a,(ix+1)
        ld      (vV9RegB+8),a           ; NX bajo
        ld      c,a
        ld      a,(ix+2)
        rrca
        and     1
        ld      (vV9RegB+9),a
        or      c
        jr      nz,.nx
        ld      a,2
        ld      (vV9RegB+9),a           ; ancho 0 = 512
.nx:    ld      a,(ix+2)
        rrca
        rrca
        and     3Fh
        ld      (vV9RegB+16),a          ; color
        ld      (vV9RegB+17),a
        ld      (vV9RegB+6),de          ; DY
        push    de
        call    V9_SendB
        pop     de
        inc     ix
        inc     ix
        inc     ix
        pop     bc
        djnz    .run
        inc     de
        ld      a,d
        cp      V9_STRIP_END/256
        jr      nz,.row
        ld      a,e
        cp      V9_STRIP_END-(V9_STRIP_END/256*256)
        jr      nz,.row
        ld      a,SLOT_RAM              ; (V9_DoInit vuelve a poner el cartucho con cada hoja)
        call    SlotSet
        ret
; Las tiras otra vez (src/ending.asm: la secuencia final pone sus imagenes en esa zona de la VRAM): el
; cartucho en la pagina 1 con el banco de las tablas del V9990, como lo deja el puente para V9_DoInit.
; Solo desde codigo que no este en la pagina 1.
V9_StripsUp:
        ld      a,SLOT_C1
        call    SlotSet
        ld      a,7                     ; BANK_V9 (MSX/rom/bridge.asm)
        ld      (6000h),a
        jp      V9_StripsLoop

; registro, valor
TV9Regs:        db      6,86h           ; B1, 512 px de espacio de imagen, 8 bpp
                db      7,08h           ; PAL
                db      8,02h           ; pantalla apagada; los bits 2-0 son fijos "010" (manual: R#8). Con el
                                        ; bit 1 a 0 (lo que deja el reinicio) el V9990 real solo direcciona la
                                        ; mitad de la VRAM: las tiras (y 512-1023) caian encima de los digitos,
                                        ; las letras y la radio que se suben al arrancar. openMSX no lo emula.
                db      9,0             ; sin interrupciones
                db      13,0            ; paleta de 64 colores (BP6)
                db      15,0            ; borde: color 0
                db      17,0
                db      18,0
                db      19,0
                db      20,0
                db      0FFh
; paleta (assets/editable/palette.gpl, tools/mkpal.py): TV9Pal = colores 0-31, TV9PalTms = 32-47
; (marcador y menus), TV9Sir0 / TV9Sir1 = los 16 de las sirenas (48-63), en cada fase del parpadeo
        include "../build/palette.inc"
;                       SX   SY   DX   DY   NX   NY     ARG LOP  mascara  FC   BC   codigo
TV9Clear:       dw      0,   0,   0,   0,   512, 1024
                db      0,0Ch,0FFh,0FFh, 0,0, 0,0, 20h
TV9Fill:        dw      0,   0,   0,   0,   0,   1
                db      0,0Ch,0FFh,0FFh, 0,0, 0,0, 20h
TV9Sky:         dw      0,   0,   8,   0,   240, 128
                db      0,0Ch,0FFh,0FFh, V9_SKY,V9_SKY, 0,0, 20h
; R#36-R#47 para las lineas de carretera: DX, DY, NX, NY, ARG, LOP, mascara
TV9RoadRegs:    db      8,0, 64,0, 240,0, 1,0, 0,0Ch,0FFh,0FFh
TV9Mtn:         dw      0,   V9_MTN_Y, 8, 0, 240, 24
                db      0,0Ch,0FFh,0FFh, 0,0, 0,0, 40h
; alto de la pila de mosaico segun el alto del fotograma: (32 / h) * h
TV9Stack:       db      0,32,32,30,32,30,30,28,32,27,30,22,24,26,28,30,32
        include "../build/sheets.inc"
        db      26                      ; hoja 6: panel del marcador (build/hud.bin), a su sitio
        dw      0,64                    ; (y 0-63, mitad izquierda)
        db      31                      ; hoja 7: caras y letras de la radio (build/radio.bin)
        dw      8000h,60                ; (y 0-59, mitad derecha)
        include "../build/mountains.inc" ; hojas 8-12: montanas de los niveles (tools/mkmountains.py)
        db      46                      ; hoja 13: digitos del marcador (build/digits.bin), en
        dw      8000h+V9_PIC_DIG_Y,60   ; x 424-503 (y 392-451, mitad derecha)
        db      47                      ; hoja 14: letras de la portada (build/titlefont.bin),
        dw      443,24                  ; x 0-255, y 443-466 (src/title.asm)
        db      55                      ; hoja 15: fondo de la portada (build/menubg.bin), en la ventana B
        dw      8000h+64,148            ; (x 256-511, y 64-211; la portada no la usa, src/title.asm)
        db      58                      ; hoja 16: imagen del monitor del aviso de nivel (build/monitor.bin),
        dw      8000h+64,128            ; en la ventana B (x 256-511, y 64-191)
        db      60                      ; hoja 17: fotos y manos de la secuencia final (build/ending_img.bin,
        dw      V9_STRIP_Y,208          ; tools/mkending.py), en la zona de las tiras (x 0-255, y 468-675)
V9_End:                                 ; (tiene que quedar por debajo de TV9W)

; ------------------------------------------------------------ cartucho / RAM en las paginas 1 y 2
; Las paginas 1 y 2 van cambiando entre la RAM (el juego) y el cartucho (hojas, pistas de sonido,
; niveles). Con el registro de slots primarios (A8) no basta cuando el cartucho esta en un slot
; expandido y la RAM que se encontro al arrancar esta en otro subslot del mismo primario (el mapper
; de un MegaFlashROM SCC+ SD, o un MSX sin 64K propios): hay que cambiar tambien el registro de
; subslots de ese primario (FFFF), que solo se ve con la pagina 3 en el. SlotSet lo hace todo:
; A = configuracion (SLOT_*), con los valores que calculo el arranque (rom.asm). Sin pila mientras la
; pagina 3 esta cambiada; con las interrupciones fuera, porque la del V9990 tambien lo llama (sonido).
; Va en 33AB-33FF, tras los bordes de carretera (3300), copiado de la ROM con ellos.
SLOT_RAM        equ 0                   ; RAM en las 4 paginas
SLOT_C1         equ 1                   ; cartucho en la pagina 1
SLOT_C2         equ 2                   ; cartucho en la pagina 2
SLOT_C12        equ 3                   ; cartucho en las paginas 1 y 2
        code ! 33ABh
vSlotCur:       db      0               ; 33AB: configuracion en curso (la interrupcion solo toca el sonido con 0)
vSSFlag:        db      0               ; 33AC: <> 0: el primario del cartucho esta expandido: tambien FFFF
vA8P3:          db      0               ; 33AD: A8 de vA8Ram con la pagina 3 en el primario del cartucho
TSS:            ds      4,0             ; 33AE: registro de subslots de ese primario por configuracion
SlotSet:                                ; 33B2. Conserva BC, DE y HL (el puente lleva el banco en B).
        push    hl
        push    bc
        ld      c,a
        ld      b,0
        call    V9_Iff                  ; (lectura doble: en el Z80, LD A,I con una interrupcion a la vez
        push    af                      ; dice que estaban inhibidas)
        di
        ld      a,c                     ; vSlotCur ya con DI: si no, al volver de "cartucho en la pagina 2"
        ld      (vSlotCur),a            ; la interrupcion veia 0 con el cartucho aun ahi y llamaba al sonido
        ld      a,(vSSFlag)
        or      a
        jr      z,.a8
        ld      hl,TSS
        add     hl,bc
        ld      a,(vA8P3)
        out     (0A8h),a                ; pagina 3 = el primario del cartucho: su registro de subslots
        ld      a,(hl)
        ld      (0FFFFh),a
.a8:    ld      hl,vA8Ram
        add     hl,bc
        ld      a,(hl)
        out     (0A8h),a
        pop     af
        pop     bc
        pop     hl
        ret     po
        ei
        ret
V9_SlotEnd:                             ; (por debajo de 3400h: el puente)

; tabla por anchura de carretera, alineada a 256 para indexarla sumando al byte alto
        code ! 1400h
TV9W:
        include "../build/wtab.inc"

        code ! V9_IVEC
        dw      V9_Isr                  ; vector IM 2

; sprites sin escalar: indice por el byte bajo del puntero original (2 x 256 bytes) y
; entradas (a partir de 1C00h, direccion que conoce tools/mksprites.py)
        code ! 1A00h
TV9UnsIdx:
        include "../build/unscaled.inc"
; Trozo de tira en la linea vFkY: DE = x del borde izquierdo, HL = x del derecho, de la
; columna de pantalla B a la C (sin incluirla).
V9_ForkStrip:
        ld      a,c
        sub     b
        ret     z
        ret     c
        ld      (vFkNX),a
        or      a
        sbc     hl,de
        jp      p,.w1
        ld      hl,0
.w1:    ld      a,h
        cp      2
        jr      nc,.wmax
        or      a
        jr      z,.wok
        ld      a,l
        cp      V9_WMAX-256
        jr      c,.wok
.wmax:  ld      hl,V9_WMAX-1
.wok:   add     hl,hl
        add     hl,hl
        ld      a,h
        add     a,TV9W/256
        ld      h,a
        ld      a,(hl)
        inc     l
        sub     e
        ld      e,a
        ld      a,(hl)
        inc     l
        sbc     a,d
        ld      d,a                     ; DE = SX de la columna 8
        ld      a,b
        sub     8
        add     a,e
        ld      e,a
        jr      nc,.wce
        inc     d
.wce:   in      a,(65h)
        rra
        jr      c,.wce
        di
        ld      a,32
        out     (64h),a
        ld      a,e
        out     (63h),a
        ld      a,d
        and     1
        out     (63h),a                 ; SX
        ld      a,(vFkPh)
        add     a,(hl)
        inc     l
        out     (63h),a
        ld      a,(hl)
        out     (63h),a                 ; SY
        ld      a,b
        out     (63h),a
        ld      a,(vV9Draw)
        out     (63h),a                 ; DX (byte alto = ventana)
        ld      a,(vFkY)
        out     (63h),a
        xor     a
        out     (63h),a                 ; DY
        ld      a,(vFkNX)
        out     (63h),a
        xor     a
        out     (63h),a                 ; NX
        inc     a
        out     (63h),a
        dec     a
        out     (63h),a                 ; NY = 1 (el V9990 real lo altera al acabar una orden)
        ld      a,52
        out     (64h),a
        ld      a,40h
        out     (63h),a
        ei
        ret

; Una vez por frame de bifurcacion: con la rama decidida (vForkState = 1) y las carreteras
; ya separadas (vForkSep >= FK_SEP) la otra no se dibuja, ni sus objetos del borde: es la
; mitad del trabajo de la linea y de los objetos de esas filas. Entrada de Road_ForkLines:
; sigue en V9_ForkLines (B = lineas, que se conserva).
FK_SEP          equ 64
V9_FkCalc:
        ld      d,0
        ld      a,(vForkState)
        dec     a
        jr      nz,.st
        ld      a,(vForkSep+1)
        or      a
        jr      nz,.st
        ld      a,(vForkSep)
        cp      FK_SEP
        jr      c,.st
        ld      a,(vForkBranch)         ; (con la rama 1 el jugador va por la carretera de
        cp      1                       ; las tablas EB-ED, como se ve en pantalla)
        ld      d,1
        jr      nz,.st
        inc     d
.st:    ld      a,d
        ld      (vFkSkip),a
        jp      V9_ForkLines

; Objetos del borde (Scn_DrawLeft / Obj_SideB, A = tipo): en las filas de la bifurcacion
; el lado A va en el borde de la carretera EB-ED y el B en el de la E8-EA (visto en pantalla).
V9_SideA:
        ld      e,a
        ld      a,(vForkActive)
        or      a
        jr      z,.v
        ld      a,(vFkSkip)
        dec     a
        jp      z,Scn_SideANext
.v:     ld      a,(ix+1)
        or      a
        jp      nz,Scn_SideANext
        jp      Scn_SideAGo
V9_SideB:
        ld      e,a
        ld      a,(vForkActive)
        or      a
        jr      z,.v
        ld      a,(vFkSkip)
        cp      2
        jp      z,Scn_SideBNext
.v:     ld      a,e
        cp      2                       ; (el tipo 2 cruza la carretera: aunque no se vea su borde)
        jp      z,Scn_SideBGo
        ld      a,(ix+1)
        or      a
        jp      nz,Scn_SideBNext
        jp      Scn_SideBGo

; Linea de la bifurcacion en la que solo se ve una carretera: una copia de su tira de
; lado a lado, como una linea normal. A = tabla de su borde izquierdo (E8 o EB; el derecho
; esta 2 tablas mas alla). En la pila, HL de V9_Fork (L = indice de la linea).
V9_ForkOne:
        pop     hl
        push    hl
        ld      h,a
        ld      d,(hl)
        dec     l
        ld      e,(hl)
        inc     l
        inc     h
        inc     h
        ld      a,(hl)
        dec     l
        ld      l,(hl)
        ld      h,a
        ld      bc,08F8h                ; columnas 8 a 248
        call    V9_ForkStrip
        pop     hl
        exx
        dec     l
        jp      Fork_NextLine

V9_UnsEnd:                              ; (por debajo de 1E80h: variables del sonido)

; ============================================================ marcador (2)
; En el hueco de VDP_DumpWindow del original (370D-3BFD), que el port no usa.
        code ! 370Dh

; Al arrancar (todo RAM salvo la pagina 1): sube a la VRAM el "ruido" del retrato (bytes
; cualesquiera a 1 bpp, que se expanden en blanco y negro). Las caras y las letras de la
; radio son la hoja 7 (tools/mkradio.py).
V9_HudInit:
        ld      hl,0C000h               ; "ruido": 512 bytes de codigo del juego
        ld      de,V9_NOISE_A*256
        call    V9_FontUp
        ld      d,V9_NOISE_A+2
        call    V9_FontUp
        ret

; Primer frame de carrera tras un volcado completo: el panel se vuelve a subir desde la ROM
; (hoja 6, 16 KB, unos 80 ms con la CPU; no hay copia en VRAM), y encima lo que cambia:
; digitos (segun las caches del original), STAGE n y la marcha. La velocidad se redibuja
; sola. Con DI porque la subida escribe registros; mientras tanto se ve la pagina A entera.
V9_HudRedraw:
        call    V9_WaitCE
        di
        ld      a,6
        call    V9_LoadSheetA
        ei
        ld      hl,V9_CACHE             ; las celdas de esas 8 filas ya no son las de la cache
        ld      de,V9_CACHE+1
        ld      bc,511
        ld      (hl),0FFh
        ldir
        exx
        ld      de,4126h
        exx
        ld      hl,vHudScore+7
        ld      b,7
        call    .digs
        ld      a,1                     ; unidades del marcador: un 0 fijo
        ld      (vHudZero),a
        xor     a
        call    Hud_BigDigit
        xor     a
        ld      (vHudZero),a
        exx
        ld      de,412Fh
        exx
        ld      hl,vHudTime+1
        ld      b,2
        call    .digs
        exx
        ld      de,4191h
        exx
        ld      hl,vHudDist+3
        ld      b,4
        call    .digs
        ld      de,4486h
        ld      hl,Hud_TxtStage
        call    Txt_Print
        ld      a,(vHudGear)
        or      a
        ld      hl,Hud_TxtLo
        jr      z,.gear
        ld      hl,Hud_TxtHi
.gear:  ld      de,448Eh
        jp      Txt_Print
.digs:  ld      a,(hl)
        cp      10
        jr      nc,.skip                ; (cache sin digito)
        push    hl
        push    bc
        call    Hud_BigDigit
        pop     bc
        pop     hl
        jr      .next
.skip:  exx
        inc     e
        exx
.next:  dec     hl
        djnz    .digs
        ret
; Relleno en el marcador. vV9RegB+4, +6, +8 y +10 (DX, DY, NX, NY: bytes) y +16 (color)
; ya puestos.
V9_BoxBoth:
        xor     a
        ld      (vV9RegB+5),a
        ld      (vV9RegB+7),a
        ld      (vV9RegB+9),a
        ld      (vV9RegB+11),a
        ld      a,(vV9RegB+16)
        ld      (vV9RegB+17),a
        ld      hl,0C00h
        ld      (vV9RegB+12),hl
        ld      hl,0FFFFh
        ld      (vV9RegB+14),hl
        ld      a,20h                   ; LMMV
        ld      (vV9RegB+20),a
        jp      V9_SendB

; --- retrato (filas 1-5, columnas 22-25 del marcador)
; Sustituye a la llamada a Radio_DrawPortrait: HL = retrato del original, DE = pantalla.
; El original lo copia a su pantalla (y sus atributos); el port lo dibuja ademas con una
; copia de su cara de la hoja 7 (assets/editable/radio_portraits.png). Fuera de la carrera
; (el aviso de la radio antes de empezar) se ve la pantalla Spectrum por celdas: antes de la
; copia se mandan sus 20 celdas, para que la cache las de por dibujadas y no la tapen.
V9_Portrait:
        push    hl
        call    Radio_DrawPortrait
        pop     hl
        ld      a,(vV9Race)
        or      a
        call    z,V9_PortCells
        ld      de,tPortraitBase+0B4h   ; las tres fijas: caras 0-2
        xor     a
        ld      b,3
.find:  push    hl
        or      a
        sbc     hl,de
        pop     hl
        jr      z,V9_PortDraw
        push    hl
        ld      hl,0B4h
        add     hl,de
        ex      de,hl
        pop     hl
        inc     a
        djnz    .find
        ld      a,(vLevel)              ; la del criminal: solo los niveles 2 (cara 3) y 4
        cp      2                       ; (cara 4) la tienen
        ld      a,3
        jr      z,V9_PortDraw
        ld      a,(vLevel)
        cp      4
        ld      a,4
        ret     nz
; Cara A (0-4) de la hoja 7 al recuadro del retrato (x 176, y 8).
V9_PortDraw:
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a                     ; 32 * n
        ld      l,a
        ld      h,1
        ld      (vV9RegH+0),hl          ; SX = 256 + 32 * n
        ld      hl,0
        ld      (vV9RegH+2),hl
        ld      l,176
        ld      (vV9RegH+4),hl
        ld      l,8
        ld      (vV9RegH+6),hl
        ld      l,32
        ld      (vV9RegH+8),hl
        ld      l,40
        ld      (vV9RegH+10),hl
        ld      a,0Ch
        ld      (vV9RegH+13),a
        jp      V9_SendH

; Sustituye a la llamada que apaga el retrato (atributos a 0): en carrera, caja negra.
V9_PortraitOff:
        push    af
        ld      a,(vV9Race)
        or      a
        jr      z,.x
        ld      a,33                    ; negro de la paleta del marcador
        ld      (vV9RegB+16),a
        ld      a,176
        ld      (vV9RegB+4),a
        ld      a,8
        ld      (vV9RegB+6),a
        ld      a,32
        ld      (vV9RegB+8),a
        ld      a,40
        ld      (vV9RegB+10),a
        call    V9_BoxBoth
.x:     pop     af
        jp      Radio_PortraitAttr

; Entrada de Radio_NoiseFill (sustituye a "ld de,ZXScreen+36h"): en carrera, el ruido del
; retrato es una expansion de 32x40 de un trozo de la zona de ruido, distinto cada frame.
V9_Noise:
        ld      a,(vV9Race)
        or      a
        jr      z,.x
        ld      a,47h
        call    V9_AttrCol
        ld      a,(vV9Frames)
        add     a,a
        add     a,a
        add     a,a
        and     58h
        ld      l,a
        ld      a,(vV9Frames)
        and     1
        add     a,a
        add     a,V9_NOISE_A
        ld      h,a
        ld      a,l
        ld      (vV9RegB+0),a
        ld      l,h
        ld      h,V9_FONT_HI
        ld      (vV9RegB+2),hl
        ld      hl,176
        ld      (vV9RegB+4),hl
        ld      l,8
        ld      (vV9RegB+6),hl
        ld      l,32
        ld      (vV9RegB+8),hl
        ld      l,40
        ld      (vV9RegB+10),hl
        ld      hl,0C00h
        ld      (vV9RegB+12),hl
        ld      hl,0FFFFh
        ld      (vV9RegB+14),hl
        ld      a,70h
        ld      (vV9RegB+20),a
        call    V9_SendB
.x:     ld      de,4036h
        ret

; --- linea de radio (y 53-58 de la pantalla)
; Sustituyen a las entradas de Radio_PutChar / Radio_PutCharCursor: A = columna (FFh =
; posicion de reposo), D = caracter. x = 10 + 5 * columna (5 en reposo). En carrera, una
; copia de 9x6 de la letra de la hoja 7 con su papel (y su cursor si lo lleva).
V9_RadioPut:
        ld      bc,0
        call    V9_RadioDraw
        jp      Radio_PutCharGo
V9_RadioPutC:
        ld      bc,0780h
        call    V9_RadioDraw
        jp      Radio_PutCharGo
V9_RadioDraw:
        push    af
        push    bc
        push    de
        ld      e,a
        ld      a,(vV9Race)
        or      a
        jr      z,.x
        ld      a,e
        cp      0FFh
        ld      a,5
        jr      z,.xs
        ld      a,e
        add     a,a
        add     a,a
        add     a,e
        add     a,10
.xs:    ld      l,a
        ld      h,0
        ld      (vV9RegH+4),hl          ; DX
        ld      a,d                     ; celda: A-Z 0-25, . , ! espacio ' 26-30, 0-9 31-40,
        ld      c,41                    ; espacio 41
        cp      20h
        jr      z,.g
        ld      c,26
        cp      2Eh
        jr      z,.g
        inc     c
        cp      2Ch
        jr      z,.g
        inc     c
        cp      21h
        jr      z,.g
        ld      c,30
        cp      27h
        jr      z,.g
        sub     30h-31
        ld      c,a
        cp      41
        jr      c,.g
        sub     41h-30h+31
        ld      c,a
.g:     ld      a,c
        ld      c,0
.div:   inc     c
        sub     10
        jr      nc,.div
        add     a,10                    ; A = columna de la rejilla, C = fila + 1
        ld      e,a
        add     a,a
        add     a,a
        add     a,a
        add     a,e
        add     a,V9_PIC_RAD_X-256
        ld      l,a
        ld      h,1
        ld      (vV9RegH+0),hl          ; SX = 422 + 9 * columna
        ld      a,c
        add     a,a
        add     a,c
        add     a,a
        sub     6
        inc     b
        djnz    .cur
        jr      .sy
.cur:   add     a,30                    ; con cursor: la otra mitad
.sy:    ld      l,a
        ld      h,0
        ld      (vV9RegH+2),hl          ; SY = 6 * fila (+ 30)
        ld      l,53
        ld      (vV9RegH+6),hl
        ld      l,9
        ld      (vV9RegH+8),hl
        ld      l,6
        ld      (vV9RegH+10),hl
        ld      a,0Ch
        ld      (vV9RegH+13),a
        call    V9_SendH
.x:     pop     de
        pop     bc
        pop     af
        ret

; Entrada de Radio_ClearLine (sustituye a "ld hl,ZXScreen+5C1h"): en carrera, caja de papel.
V9_RadioClear:
        ld      a,(vV9Race)
        or      a
        jr      z,.x
        ld      a,RADIO_PAPER           ; (el papel de assets/editable/radio_font.png)
        ld      (vV9RegB+16),a
        ld      a,8
        ld      (vV9RegB+4),a
        ld      a,53
        ld      (vV9RegB+6),a
        ld      a,240
        ld      (vV9RegB+8),a
        ld      a,6
        ld      (vV9RegB+10),a
        call    V9_BoxBoth
.x:     ld      hl,45C1h
        ret

; --- medidor de danos del coche perseguido (continua Hud_DamageMeter)
; Columna de 8x64 en x = 16, lineas 24-87 de la ventana: de abajo arriba, 2 lineas llenas,
; un segmento hueco de 3 lineas por golpe (vCrimHits, hasta 20) y el resto lleno. Una copia
; con transparencia de su estado ya pintado (V9_MeterPre).
V9_Meter:
        ld      a,(vCrimHits)
        cp      21
        jr      c,.h
        ld      a,20
.h:     add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      h,1
        ld      (vV9RegH+0),hl          ; SX = 256 + 8 * golpes
        ld      hl,V9_PIC_METER_Y
        ld      (vV9RegH+2),hl
        ld      a,(vV9Draw)
        ld      h,a
        ld      l,16
        ld      (vV9RegH+4),hl
        ld      hl,V9_WIN_Y+24
        ld      (vV9RegH+6),hl
        ld      hl,8
        ld      (vV9RegH+8),hl
        ld      l,64
        ld      (vV9RegH+10),hl
        ld      a,1Ch
        ld      (vV9RegH+13),a
        jp      V9_SendH

; --- controles (sustituye a Inp_Read)
; Teclado y joystick del puerto 1 a la vez, sin configuracion:
;   cursores o palanca: izquierda / derecha, arriba = acelerar, abajo = frenar
;   ESPACIO o boton 1: cambio de marcha       M o boton 2: turbo
;   P: pausa                                  Q: abandonar
; Devuelve en A y en vInput, a 1 lo pulsado: bit 0 derecha, 1 izquierda, 2 freno,
; 3 acelerar, 4 marcha, 5 turbo, 6 pausa, 7 abandonar. Como el original, si llegan dos
; direcciones opuestas a la vez se anulan.
V9_InpRead:
        call    V9_Iff                  ; (sin interrupciones mientras se usa el PSG: la del
        di                              ;  retrazado tambien lo escribe, src/sound.asm)
        push    af
        ld      a,15                    ; PSG R15: palanca del puerto 1
        out     (0A0h),a
        in      a,(0A2h)
        and     0AFh
        or      3
        out     (0A1h),a
        ld      a,14
        out     (0A0h),a
        in      a,(0A2h)
        cpl
        ld      c,a                     ; C: b0 arriba, b1 abajo, b2 izq., b3 der., b4 boton 1, b5 boton 2
        pop     af
        jp      po,.di
        ei
.di:
        ld      a,8
        call    .row
        ld      b,a                     ; B (fila 8): b7 der., b6 abajo, b5 arriba, b4 izq., b0 espacio
        ld      e,0
        ld      a,c
        and     8
        ld      d,a
        ld      a,b
        and     80h
        or      d
        jr      z,.r
        set     0,e                     ; derecha
.r:     ld      a,c
        and     4
        ld      d,a
        ld      a,b
        and     10h
        or      d
        jr      z,.l
        set     1,e                     ; izquierda
.l:     ld      a,c
        and     2
        ld      d,a
        ld      a,b
        and     40h
        or      d
        jr      z,.d
        set     2,e                     ; freno
.d:     ld      a,c
        and     1
        ld      d,a
        ld      a,b
        and     20h
        or      d
        jr      z,.u
        set     3,e                     ; acelerar
.u:     ld      a,c
        and     10h
        ld      d,a
        ld      a,b
        and     1
        or      d
        jr      z,.g
        set     4,e                     ; marcha
.g:     ld      a,4
        call    .row                    ; fila 4: b6 Q, b5 P, b2 M
        ld      b,a
        and     4
        ld      d,a
        ld      a,c
        and     20h
        or      d
        jr      z,.t
        set     5,e                     ; turbo
.t:     bit     5,b
        jr      z,.p
        set     6,e                     ; pausa
.p:     bit     6,b
        jr      z,.q
        set     7,e                     ; abandonar
.q:     ld      a,e
        and     3
        cp      3
        ld      a,e
        jr      nz,.h
        and     0FCh
        ld      e,a
.h:     and     0Ch
        cp      0Ch
        ld      a,e
        jr      nz,.v
        and     0F3h
.v:     ld      (vInput),a
        ret
.row:   ld      d,a                     ; fila de la matriz del teclado -> A, a 1 lo pulsado
        in      a,(0AAh)
        and     0F0h
        or      d
        out     (0AAh),a
        in      a,(0A9h)
        cpl
        ret
; Iconos de turbo (al arrancar): 3 tiras de 48x14 en y 40, una por fotograma de la
; animacion: dos iconos quietos y el del fotograma. Con V9_UnsGo, como en carrera, en la
; "ventana" de x 256 y con la base en la linea 245 (64 + 245 - 14 + 1 = 40, modulo 256).
V9_TurboPre:
        ld      a,1
        ld      (vV9Draw),a
        ld      a,245
        ld      (vSpY),a
        ld      a,14
        ld      (vSpRows),a
        ld      a,16
        ld      (vV9RegO+8),a
        xor     a
        ld      (vSpMir),a
        ld      de,tHudTurboIcon        ; fotograma del tercer icono
        ld      c,0                     ; x
.strip: ld      b,3
.icon:  push    bc
        push    de
        ld      a,c
        ld      (vV9RegO+4),a
        ld      hl,tHudTurboIcon
        dec     b
        jr      nz,.st
        ex      de,hl
.st:    ld      a,0Ch
        call    V9_UnsGo
        pop     de
        pop     bc
        ld      a,c
        add     a,16
        ld      c,a
        djnz    .icon
        ld      hl,38h
        add     hl,de
        ex      de,hl
        cp      144
        jr      nz,.strip
        ret

; Medidor de danos (al arrancar): los 21 estados (golpes 0-20) en y 392, x 256 + 8 * golpes.
; Todo en turquesa (color 36) y, por cada golpe, el hueco de su segmento (6x2 en color 0,
; transparente): filas 62 - 3 * golpes + 3 * k + 1 y + 2 de la columna.
V9_MeterPre:
        call    V9_PreRegs
        ld      hl,256
        ld      (vV9RegB+4),hl
        ld      hl,V9_PIC_METER_Y
        ld      (vV9RegB+6),hl
        ld      hl,21*8
        ld      (vV9RegB+8),hl
        ld      l,64
        ld      (vV9RegB+10),hl
        ld      hl,V9_METER_COL*257
        ld      (vV9RegB+16),hl
        ld      a,20h
        ld      (vV9RegB+20),a
        call    V9_SendB
        ld      hl,6
        ld      (vV9RegB+8),hl
        ld      l,2
        ld      (vV9RegB+10),hl
        ld      l,h
        ld      (vV9RegB+16),hl         ; color 0
        ld      c,1                     ; golpes
.h:     ld      a,c
        add     a,a
        add     a,a
        add     a,a
        inc     a
        ld      (vV9RegB+4),a           ; x - 256 = 8 * golpes + 1
        ld      a,c
        add     a,a
        add     a,c
        neg
        add     a,V9_PIC_METER_Y+62+1-256
        ld      b,c
.k:     ld      (vV9RegB+6),a           ; y - 256 = 392 + 62 - 3 * golpes + 3 * k + 1 - 256
        push    af
        push    bc
        call    V9_SendB
        pop     bc
        pop     af
        add     a,3
        djnz    .k
        inc     c
        ld      a,c
        cp      21
        jr      nz,.h
        ret

; Bucle de la bifurcacion del original (Road_ForkLines, B lineas desde la 30h) sin POP: el
; original lee EC con SP y una interrupcion apilaba su retorno en la entrada recien leida
; (o recien escrita), que luego es el borde derecho de esa linea. Mismas operaciones:
;   EA = (E8+EC)/2, E9 = (EA+E8)/2, EB = (EB+ED)/2, EC = (EB+ED)/2 (con EB ya nuevo)
; Va aqui porque no cabe antes de las variables (1340). Las lineas que quedan siguen en
; V9_LANES (el original saltaba a Road_GeomLoop con SP en EC).
V9_ForkLines:                           ; (se entra por V9_FkCalc)
        ld      (Road_GeomExit+1),sp
        ld      a,30h
.ln:    exx
        ld      l,a
        ld      h,0E8h
        ld      e,(hl)
        inc     l
        ld      d,(hl)                  ; DE = E8
        ld      h,0ECh
        ld      c,(hl)
        dec     l
        ld      l,(hl)
        ld      h,c                     ; HL = EC
        add     hl,de
        sra     h
        rr      l
        ld      b,h
        ld      c,l
        ld      l,a
        ld      h,0EAh
        ld      (hl),c
        inc     l
        ld      (hl),b                  ; EA
        ld      h,b
        ld      l,c
        add     hl,de
        sra     h
        rr      l
        ld      b,h
        ld      c,l
        ld      l,a
        ld      h,0E9h
        ld      (hl),c
        inc     l
        ld      (hl),b                  ; E9
        ld      h,0EDh
        ld      d,(hl)
        dec     l
        ld      e,(hl)                  ; DE = ED
        ld      h,0EBh
        ld      c,(hl)
        inc     l
        ld      b,(hl)
        ld      h,b
        ld      l,c                     ; HL = EB
        add     hl,de
        sra     h
        rr      l
        ld      b,h
        ld      c,l
        ld      l,a
        ld      h,0EBh
        ld      (hl),c
        inc     l
        ld      (hl),b                  ; EB
        ld      h,b
        ld      l,c
        add     hl,de
        sra     h
        rr      l
        ld      b,h
        ld      c,l
        ld      l,a
        ld      h,0ECh
        ld      (hl),c
        inc     l
        ld      (hl),b                  ; EC
        exx
        inc     a
        inc     a
        djnz    .ln
        and     a
        jp      z,Road_GeomExit
        jp      V9_LaneGo               ; A = primera linea que queda

        if ORIG_INPUT = 0               ; (en la ROM de pruebas va en src/dark.asm: aqui no cabe)
; Una hoja y el cartucho otra vez en la pagina 1 (V9_DoInit sube varias seguidas; por debajo
; de 4000h, que en el arranque la pagina 1 es el cartucho)
V9_LoadSheetC:
        call    V9_LoadSheetA
        ld      a,SLOT_C1
        call    SlotSet
        ret
        endif
V9_HudEnd:                              ; (tiene que quedar por debajo de 3BFEh)

; ============================================================ imagenes ya pintadas
; En el cuerpo de VDP_CopyColors del original (3DB6-3EFF): el port sustituye su entrada y
; no lo usa. Lo que el marcador y la ventana dibujaban con varios comandos (cajas,
; expansiones de 1 bpp por celda, segmentos) se pinta una vez en VRAM con sus colores y en
; carrera es una sola copia (V9_SendH).
        code ! 3DB6h

; Copia (LMMM) con SX, SY, DX, DY, NX, NY y la operacion logica de vV9RegH (ARG = 0).
V9_SendH:
        call    V9_FlipWait
        call    V9_WaitCE
        di
        ld      a,32
        out     (64h),a
        ld      hl,vV9RegH
        ld      bc,0E63h
        otir                            ; R#32-R#45
        ld      a,52
        out     (64h),a
        ld      a,40h
        out     (63h),a
        ei
        ld      a,(vV9RegH+13)
        ld      (vV9Lop),a
        ret

; Comun a las expansiones y rellenos de lo que sigue: ARG 0, copia, mascara entera.
; Conserva HL.
V9_PreRegs:
        push    hl
        ld      hl,0C00h
        ld      (vV9RegB+12),hl
        ld      hl,0FFFFh
        ld      (vV9RegB+14),hl
        pop     hl
        ret

; HL = pista A
V9_SndSlot:
        ld      l,a
        add     a,a
        add     a,l
        add     a,a                     ; 6 bytes por pista
        add     a,VGM_S0-(VGM_S0/256*256)
        ld      l,a
        ld      h,VGM_S0/256
        ret



; Sirena: fundido de salida (desde V9_SndHush). La interrupcion resta VGM_ATT al volumen de
; R8-R9 y V9_SndFade lo sube un paso cada 7 frames: unos 2 s hasta el silencio.
V9_SirenFadeOut:
        ld      a,(vCatchState)         ; en la captura la sirena sigue hasta la linea SCORE del
        cp      3                       ; bonus (V9_PutLog la corta)
        ret     z
        ld      a,(VGM_S0+6)            ; (si suena y no se esta apagando ya)
        or      a
        ret     z
        ld      a,(VGM_ATT)
        or      a
        ret     nz
        inc     a
        ld      (VGM_ATT),a
        ld      a,7
        ld      (VGM_FCNT),a
        ret
; Desde la interrupcion: un paso del fundido; al acabar, para la sirena.
V9_SndFade:
        ld      a,(VGM_ATT)
        or      a
        ret     z
        ld      hl,VGM_FCNT
        dec     (hl)
        ret     nz
        ld      (hl),7
        ld      hl,VGM_ATT
        inc     (hl)
        ld      a,(hl)
        cp      16
        ret     c
        ld      (hl),0
        xor     a
        ld      (VGM_S0+6),a            ; sirena parada
        ld      hl,TVgmOwn+4
        jp      V9_SndRelease
; En pausa (desde la interrupcion): volumenes a 0; las pistas no avanzan.
V9_SndMuted:
        ld      b,8
.v:     ld      a,b
        out     (0A0h),a
        xor     a
        out     (0A1h),a
        inc     b
        ld      a,b
        cp      11
        jr      c,.v
        ret
; Pausa (sustituye a Game_Pause): todo callado mientras dura; al seguir, cada pista sigue
; donde estaba (la sirena incluida, como en el 128K).
V9_Pause:
        ld      a,1
        ld      (VGM_MUTE),a
.l1:    call    Inp_Read                ; que suelten la tecla de pausa,
        and     40h
        jr      nz,.l1
.l2:    call    Inp_Read                ; que pulsen otra
        and     7Fh
        jr      z,.l2
.l3:    call    Inp_Read                ; y que la suelten
        and     7Fh
        jr      nz,.l3
        xor     a
        ld      (VGM_MUTE),a
        ret

; Las celdas del retrato (filas 1-5, columnas 22-25) al V9990 y a la cache. Conserva HL.
V9_PortCells:
        push    hl
        ld      c,36h
.cel:   ld      b,0
        push    bc
        call    V9_CellN
        pop     bc
        inc     c
        ld      a,c
        and     1Fh
        cp      26
        jr      c,.cel
        ld      a,c
        add     a,32-4
        ld      c,a
        cp      0D6h
        jr      nz,.cel
        pop     hl
        ret

; Digito C del marcador (8x15, de la hoja 13) a su sitio en la pantalla Spectrum DE (linea 1
; de la celda de arriba). La fila de la hoja sale de la columna: puntos, tiempo, velocidad
; o distancia.
V9_DigCopy:
        ld      a,c
        add     a,a
        add     a,a
        add     a,a
        add     a,V9_PIC_DIG_X-256
        ld      l,a
        ld      h,1
        ld      (vV9RegB+0),hl          ; SX
        ld      a,e
        ld      l,V9_PIC_DIG_Y-256
        cp      2Fh
        jr      c,.r
        ld      l,V9_PIC_DIG_Y+15-256   ; tiempo (2F-30)
        cp      32h
        jr      c,.r
        ld      l,V9_PIC_DIG_Y+30-256   ; velocidad (32-34)
        cp      91h
        jr      c,.r
        ld      l,V9_PIC_DIG_Y+45-256   ; distancia (91-94)
.r:     ld      (vV9RegB+2),hl          ; SY
        ld      a,15
        call    V9_GlyphSetup           ; DX, DY, NX, NY, ARG, LOP
        ld      a,40h                   ; LMMM
        ld      (vV9RegB+20),a
        jp      V9_SendB

; Las dos celdas del digito de la pantalla Spectrum xxE (tercio de arriba) al V9990 y a la cache.
V9_DigCells:
        ld      b,0
        ld      c,e
        push    bc
        call    V9_CellN
        pop     bc
        ld      a,c
        add     a,32
        ld      c,a
        jp      V9_CellN

; Como "ld a,i": P/V = 1 (PE) si las interrupciones estan habilitadas. Si se acepta una
; interrupcion justo durante "ld a,i", el Z80 deja P/V a 0 aunque esten habilitadas (y
; quien las restaura despues ya no hace EI: hasta 20 ms sin interrupciones, y la del
; retrazado y la de la linea 63 se atendian al reves). Al volver de esa interrupcion
; (con EI) una segunda lectura ya es buena.
V9_Iff: ld      a,i
        ret     pe
        ld      a,i
        ret

V9_PicEnd:                              ; (tiene que quedar por debajo de 3F00h: tAttrToTMS)
