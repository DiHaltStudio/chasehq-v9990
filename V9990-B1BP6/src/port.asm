; port.asm -- imagen de 64K del port V9990 (B1/BP6) de Chase H.Q.
;
; Parte de la imagen reconstruida del original (MSX/work/game.bin, identica a la cinta) y
; le superpone:
;   - el codigo nuevo del V9990 en la pagina 0 (0038-32FF), que el original no usa;
;   - parches en las rutinas del juego (cada uno con su comentario).
; Salida: build/port.bin. src/rom.asm la reparte en los bancos de la MegaROM.
;
; Estado: hito 3. El juego corre entero con su logica original; no se toca el TMS9918;
; el V9990 muestra cielo, carretera y los objetos y coches escalados. Coche del jugador,
; marcador, montanas, menus, bifurcacion y tunel estan pendientes (ver doc/04_port.md).

        output  "../build/port.bin"
        defpage 0,0,10000h
        page    0
        code @ 0
        incbin  "../../MSX/work/game.bin"

; ------------------------------------------------------------ direcciones del original
Start                   equ 3500h
VDP_SetBorder           equ 3527h
VDP_Present             equ 353Eh
VDP_DumpWindow          equ 370Ch
VDP_SetColors           equ 3C6Ah
VDP_DumpScreen          equ 3C15h
VDP_UpdateHUD           equ 3CF5h
VDP_FillColorRow        equ 3CC3h
VDP_CopyCells           equ 3D7Ch       ; HL = pantalla (linea 0 de la celda), B = celdas
VDP_CopyColors          equ 3DB3h       ; HL = atributos, A = filas de 4 celdas
tAttrToTMS              equ 3F00h       ; atributo Spectrum -> color TMS (tinta*16 + papel)
Road_Draw               equ 0C452h
Road_LinePlainGo        equ 0C565h      ; una linea de carretera, banda clara
Road_LineBandGo         equ 0C5A7h      ; una linea de carretera, banda oscura
Road_NextLine           equ 0C6ABh
Road_smcEdgePageL       equ 0C643h      ; pagina de la tabla de x del borde izquierdo (E8..)
Road_smcEdgePageR       equ 0C68Bh      ; idem, borde derecho (EC..)
Mnt_SelectGfx           equ 0C7E7h      ; ld a,scroll (0-19, pasos de 4 px) / rra / ...
Mnt_smcRows             equ 0C80Ch      ; operando: filas de montana visibles (0-24)
Sky_Fill                equ 0C887h
Road_smcTunnel          equ 0C890h      ; operando: <> 0 dentro del tunel (cielo negro)
Tun_smcMode             equ 0C161h      ; operando: <> 0 con la boca del tunel a la vista
Road_smcSavedSP         equ 0C8A4h      ; operando: SP guardado al entrar en Road_Draw
LevelData               equ 5C00h
Spr_DrawAtRightX        equ 929Ah       ; dibuja un fotograma dado su borde derecho (HL = descriptor)
Spr_DrawAtX             equ 9309h       ; idem, dado su borde izquierdo
Spr_ShiftSel            equ 9395h       ; operando: bit 0 = datos desplazados 4 px
Spr_CheckMask           equ 9333h
Spr_YOffset             equ 933Dh       ; "ld d,n": desplazamiento vertical del fotograma
Spr_Mode                equ 93C0h       ; despacho a los blitters: ld a,modo / and a / jp z,...
Spr_TileLeft            equ 9404h       ; operando: lineas que quedan por cubrir (mosaico)
Spr_TileHeight          equ 9415h       ; operando: alto del fotograma del mosaico
Spr_DrawMasked          equ 0B6DDh      ; sprite con mascara sin escalar
Car_CallOpaque          equ 0B5F1h      ; Car_DrawBody: "call Spr_DrawOpaque" (carroceria)
VDP_PresentFull         equ 3534h
vVDPWinMode             equ 3533h
vFxState                equ 0A231h
Scr_CopyBuffer          equ 0BC3Eh
Scr_ClearWindow         equ 0BDC1h
Game_StFadeOut          equ 8A7Eh
Fx_StartDissolve        equ 8DF9h
Txt_PutChar             equ 9FB4h
Txt_MapChar             equ 9FBDh
Lvl_PlayLoad            equ 8401h       ; Lvl_Play: "call Lvl_Load"
Lvl_Load                equ 8014h
Lvl_BeginIntro          equ 841Bh       ; Lvl_Begin: "call Lvl_Intro"
Lvl_Intro               equ 858Ch
Lvl_IntroClear          equ 859Ah       ; Lvl_Intro: "call Scr_ClearWindow"
Lvl_IntroPresent        equ 85B7h       ;            "call VDP_PresentFull" (final del bucle)
Lvl_IntroMap            equ 85E4h       ; coche del criminal en el monitor del aviso (una llamada por cuadro)
Lvl_IntroMapCnt         equ 85EBh       ; su contador de lineas (operando de "ld a,n"; Lvl_Intro lo pone a 0)
Lvl_IntroMapDraw        equ 8609h       ; Lvl_IntroMap: "ld hl,tCode128K+2ADh / jp Spr_DrawOpaque"
Spr_DrawOpaque          equ 949Ch       ; blitters opacos (949C-9617): solo los llamaban Lvl_IntroMap y Car_DrawBody
tCode128K               equ 0F220h
Car_CallOpqMirror       equ 0B5F8h      ; Car_DrawBody: "call Spr_DrawOpqMirror"
vLevel                  equ 8007h
vSpeed                  equ 0A24Ah      ; velocidad (palabra, 0-511 aprox.)
        include "../build/config.inc"   ; ORIG_INPUT (lo escribe el Makefile)
        include "../build/radio.inc"    ; RADIO_PAPER (tools/mkradio.py)
SND_RND_EXACT           equ ORIG_INPUT  ; 1: los efectos mudos avanzan Rnd como el original
Menu_Exit               equ 0E99Bh
Inp_Read                equ 0A0D6h
vInput                  equ 0A0D5h

Geo_DDASaveSP           equ 0CCAEh
Geo_DDAExit             equ 0CCF4h
Geo_DDASlice            equ 0CCB3h
Road_GeomInit           equ 0BA12h
Road_ForkLines          equ 0BB0Ch      ; B = lineas con bifurcacion (desde la 30h)
Hud_FlashBlock          equ 9DF4h
Tun_smcJrLeft           equ 0C222h      ; salto dentro de la cadena de la pared derecha (16 palabras)
Tun_smcJrRight          equ 0C237h      ; idem, pared izquierda
Tun_smcTopFill          equ 0C2B9h      ; 0: resto hasta arriba en color de papel, 1: negro, otro: nada
vInTunnel               equ 0A23Bh
vCatchState             equ 0A230h      ; captura: 0 persecucion ... 3 parado en el arcen, 6 nivel siguiente
vRoadsideR              equ 0A23Ch
vRoadsideL              equ 0A23Dh
vSndReq                 equ 0A237h      ; efecto pedido (Snd_Request); A238 su prioridad
vGear                   equ 0A253h
Snd_Request             equ 88F2h
Snd_Update              equ 8903h
Snd_Nop                 equ 8A56h
Snd_Hooks               equ 83B5h       ; 8 x "jp": Target, EngineTick, Stop, Frame, Turbo, Engine, Tune, Title
Title_Loop              equ 8258h
Rnd                     equ 961Bh
ReadJoystick            equ 3590h       ; (solo la ROM de pruebas: Inp_Read del original)
Fork_NextLine           equ 0CB2Fh
Lvl_LoadRetry           equ 8025h       ; Lvl_Load, tras apuntar el nivel: pantalla de la cinta
Lvl_LoadBlock           equ 80B9h       ; bloque del nivel (1AF0h bytes en 5C00) por TapeLoader
vForkBranch             equ 0A249h      ; rama tomada en la bifurcacion (1 = izquierda)
vForkActive             equ 0A265h
vForkSep                equ 0A267h      ; separacion de las dos carreteras (16..240, de 16 en 16)
vForkState              equ 0A269h      ; 1: rama ya decidida
Scn_SideA               equ 8FF8h       ; Scn_DrawLeft: objeto del borde, lado A
Scn_SideAGo             equ 8FFFh       ;   (tras su prueba de visibilidad)
Scn_SideANext           equ 8FB2h       ;   (siguiente: lado B de la fila)
Scn_SideB               equ 9023h       ; Obj_SideB
Scn_SideBGo             equ 902Eh
Scn_SideBNext           equ 8FBDh       ;   (siguiente fila)
Obj_SpanJump            equ 9115h       ; "jr n": entra en la cadena de 30 bytes; n = 3Ch - 2 * columnas
Radio_DrawPortrait      equ 9AABh
Radio_PortraitAttr      equ 9A98h
Radio_PutCharGo         equ 9AF4h
tPortraitBase           equ 7B35h       ; retratos: 0B4h bytes cada uno (el 0 no es un retrato)
Fnt_Small               equ 0DFF8h      ; fuente de la radio: 41 glifos de 6 bytes
Hud_TxtStage            equ 9D5Bh
Hud_TxtLo               equ 9D59h
Hud_TxtHi               equ 9D57h
vHudScore               equ 0A175h      ; digitos dibujados del marcador (8), del tiempo (2) y
vHudTime                equ 0A17Fh      ; de la distancia (4): el de la izquierda, en la direccion
vHudDist                equ 0A181h      ; mas alta
vCrimHits               equ 0A233h
Lane_TransitionGo       equ 0C2EBh      ; tras "ld a,iyl / cp 13h"
Road_SetupDefault       equ 0C534h
Road_SetupStore         equ 0C54Dh
Hud_Turbos              equ 9E11h
Hud_BigDigit            equ 9F47h
Hud_BigDigitGo          equ 9F4Bh       ; tras "exx / ld c,a / ld b,0"
Txt_GlyphPlain          equ 0A0ADh
Txt_GlyphPlainGo        equ 0A0B0h      ; tras "push de / ld b,7"
Txt_Print               equ 9FA3h
Hud_PopupPtr            equ 9D9Bh       ; "ld hl,texto" del texto emergente
Hud_PopupAttrSet        equ 9DBAh
Hud_Gear                equ 9DC3h
vHudGear                equ 0A174h
tFont                   equ 0A27Ah      ; 41 glifos de 7 bytes
Fnt_BigDigits           equ 0DF62h      ; 10 digitos de 15 bytes
ZXAttrs                 equ 5800h
Hud_TurboAnim           equ 9E21h       ; "ld a,n": fotograma de la animacion del turbo
Hud_Speed               equ 9E7Bh
Hud_SpeedGo             equ 9E7Eh       ; tras "ld de,ZXScreen+132h"
Hud_SpeedEnd            equ 9EC1h       ; tras los tres digitos de la velocidad
Road_GeomExit           equ 0BA4Dh
tHudTurboIcon           equ 76F0h
vTurbos                 equ 0A170h
vTurboTimer             equ 0A24Eh
Game_BonusUnits         equ 8B38h       ; Game_StBonus: "ld a,c / and 0Fh" (unidades del tiempo)
Game_BonusDone          equ 8B4Eh       ; ... donde sigue tras escribir el digito de las unidades
tMsgBonusUnits          equ 8C8Bh       ; digito de las unidades en el texto del bonus
Score_Add               equ 9D17h       ; suma BCD al marcador: A, E, D (de menos a mas peso)
vA8Ram                  equ 3403h       ; (puente) registro de slots con todo RAM
vA8C1                   equ 3404h       ; (puente) cartucho en la pagina 1

        include "v9.asm"

; ------------------------------------------------------------ parches
; Sin TMS9918: las rutinas de la capa MSX que escribian en el no hacen nada.
        code ! VDP_SetBorder
        xor     a                       ; el original salia con A = 0
        ret
        code ! VDP_DumpWindow
        ret
; Pantalla Spectrum (4000, con sus atributos) -> V9990. El original la usa para todo lo
; que no es la ventana de juego: marcador, radio, menus y pantallas. Provisional: cada
; celda de 8x8 que cambia se manda con un comando CMMC (la CPU da los 8 bytes de la
; celda y el V9990 los pinta con su tinta y su papel), a las dos paginas.
;   - volcado completo (menus, cambios de pantalla): las 768 celdas;
;   - en carrera: el planificador del original (VDP_SetColors / VDP_UpdateHUD) sigue
;     decidiendo que celdas del marcador se refrescan en cada frame; solo se cambian sus
;     rutinas de copia al TMS.
        code ! VDP_DumpScreen
        jp      V9_DumpScreen
        code ! VDP_CopyCells
        jp      V9_CopyCells
        code ! VDP_CopyColors
        jp      V9_CopyColors
        code ! VDP_FillColorRow         ; color de la fila del horizonte: no aplica
        jp      VDP_UpdateHUD
; Sonido del motor: el original lo hacia con rafagas de clics por el altavoz del PPI en
; bucles de espera (9 llamadas por frame, ~4,6 ms). En el port es un tono del PSG que
; V9_Present ajusta una vez por frame segun la velocidad.
; Iconos de turbo: por el blitter (el original los pintaba en el bufer).
        code ! Hud_Turbos
        jp      V9_Turbos

; Marcador en carrera: digitos y letras por expansion de la fuente que esta en VRAM (CMMM).
        code ! Hud_BigDigit
        jp      V9_BigDigit
        code ! Txt_GlyphPlain
        jp      V9_GlyphPlain
        code ! Hud_PopupAttrSet         ; sustituye a "ld hl,ZXAttrs+68h"
        call    V9_PopupAttr
        code ! Hud_Gear                 ; sustituye a "ld hl,vHudGear"
        call    V9_PopupRedraw

; Geometria: los carriles solo se interpolan en las lineas que el trazado de bordes ha
; escrito en este frame (de la mas alta hacia abajo), no en las 104.
        code ! Geo_DDASaveSP            ; sustituye a "ld (Geo_smcSavedSP),sp"
        ld      (vV9GeoSP),sp
        code ! Geo_DDAExit              ; sustituye a "ld sp,nn / ret"
        jp      V9_DDAExit
        code ! Road_GeomInit            ; sustituye a "ld sp,EC30h / ld a,30h"
        call    V9_GeomStart
        nop
        nop
; Lo mismo con bifurcacion: su bucle tambien lee el borde derecho con POP y luego sigue en
; el bucle normal con SP en la tabla (lineas verdes sueltas al aparecer la bifurcacion).
        code ! Road_ForkLines           ; sustituye a "ld (Road_GeomExit+1),sp"
        jp      V9_FkCalc

; Luces de las sirenas: tras invertir el brillo del segundo bloque, cambio de paleta.
        code ! 9DEFh
        call    V9_Flash2

; Boca del tunel: los bucles de relleno (pared, dintel y resto hasta arriba) son rellenos
; del V9990. Enganche tras calcular columnas y lineas (L_C21A).
        code ! 0C21Ah
        jp      V9_TunWall

; Bifurcacion: dos carreteras por linea (bordes E8-EA y EB-ED), cada una con su tira.
        code ! 0C929h                   ; Fork_LinePlainGo
        jp      V9_ForkPlain
        code ! 0C969h                   ; Fork_LineBandGo
        jp      V9_ForkBand

; Bifurcacion con la rama ya decidida y las carreteras separadas: los objetos del borde de
; la otra carretera no se dibujan (vFkSkip, V9_FkCalc).
        code ! Scn_SideA
        jp      V9_SideA
        code ! Scn_SideB
        jp      V9_SideB

; Portico (Obj_DrawSpan): la banda horizontal, por expansion de patron (CMMM) linea a linea.
        code ! 90FCh
        jp      V9_Span

; Velocidad del marcador: dos frames si, dos no.
        code ! Hud_Speed                ; sustituye a "ld de,ZXScreen+132h"
        jp      V9_SpeedGate

; Trazado de bordes, tramos con mas de 1 px por linea: sin el bucle de un paso por pixel.
        code ! 0CCF8h                   ; Geo_DDASteep
        jp      V9_Steep

; Retrato, ruido y mensajes de la radio, y medidor de danos: por comandos del V9990.
        code ! 9A20h                    ; "call Radio_DrawPortrait"
        call    V9_Portrait
        code ! 997Ch                    ; "call Radio_PortraitAttr" (retrato en negro)
        call    V9_PortraitOff
        code ! 9A6Bh                    ; Radio_NoiseFill: "ld de,ZXScreen+36h"
        call    V9_Noise
        code ! 9AECh                    ; Radio_PutChar
        jp      V9_RadioPut
        code ! 9AF1h                    ; Radio_PutCharCursor: "ld bc,0780h"
        jp      V9_RadioPutC
        code ! 9BA7h                    ; Radio_ClearLine: "ld hl,ZXScreen+5C1h"
        call    V9_RadioClear
        code ! 8EF2h                    ; Hud_DamageMeter, tras sus dos comprobaciones
        jp      V9_Meter

; Pantalla en negro mientras se prepara la siguiente (todas las ROM).
        include "dark.asm"
; Trucos: constantes y parches en cheats.asm.
        include "cheats.asm"

; Controles fijos y arranque sin menus (salvo en la ROM de pruebas, ORIG_INPUT = 1, que
; conserva los del original para poder reproducir las partidas grabadas).
        if ORIG_INPUT = 0
        code ! 0E906h                   ; Menu, tras Int_Setup / Mus_Init / di: nada de
        jp      Menu_Exit               ; "press any key", eleccion de control ni confirmacion
        code ! Inp_Read
        jp      V9_InpRead
; Carga de nivel sin los mensajes de la cinta (START TAPE, SEARCHING FOR n, FOUND n, STOP
; THE TAPE / PRESS GEAR) ni la espera al boton: el bloque viene de la ROM (TapeLoader del
; puente) y Lvl_Load vuelve en cuanto esta.
        code ! Lvl_LoadRetry-3         ; "ld (tTapeSearchDigit),a": escribia el digito del nivel en 81AE, que
        nop                             ; ahora es codigo de la portada (rompia el relleno de V9_TlFill)
        nop
        nop
        code ! Lvl_LoadRetry            ; tras apuntar el nivel cargado
        call    Lvl_LoadBlock
        ret
; Portada sin demo, textos por copias desde la VRAM.
        code ! 0B0A5h                   ; "dec a / ld (vTurbos),a" al acabarse un turbo: V9_TurboDec
        call    V9_TurboDec
        nop
        include "title.asm"
        endif

; Transiciones de carril: el original escribe el tramo de tabla con PUSH (SP apunta a la
; tabla), y una interrupcion ahi pisaria la tabla. Los PUSH van a un bufer de paso (SP a
; 00FE) y al salir se copia el tramo a su sitio; SP vuelve a la pila.
        code ! 0C2E7h                   ; Lane_Transition: "ld a,iyl / cp 13h"
        jp      V9_LaneIn
        code ! 0C336h                   ; "ld sp,hl / ld d,(hl) / dec l" (x2)
        jp      V9_LaneSP1a
        code ! 0C374h
        jp      V9_LaneSP1b
        code ! 0C3AAh                   ; "ld sp,hl / dec h / ld d,(hl)" (x2)
        jp      V9_LaneSP2a
        code ! 0C3E6h
        jp      V9_LaneSP2b
        code ! 0C407h                   ; "inc sp / bit 5,(ix+0) / jr z / ld hl,FF00h / add hl,sp / ld sp,hl"
        jp      V9_LaneAdj
        code ! 0C43Bh                   ; Lane_Exit: "ld hl,Road_SetupDefault"
        jp      V9_LaneOut

; Bonus de tiempo: correccion del bug del original (docs/12_replay.md). Las unidades del
; tiempo se sumaban A' veces en vez de "unidades" veces, con A' un residuo del codigo de
; dibujo. Aqui: unidades x 500 puntos, que es lo que anuncia el texto.
        code ! Game_BonusUnits
        jp      V9_BonusUnits
; Presentacion de un frame de juego: cambio de pagina del V9990.
        code ! VDP_Present
        jp      V9_Present
; Al entrar en Road_Draw (sustituye a su "ld (Road_smcSavedSP),sp", 4 bytes): registros
; del V9990 comunes a todas las lineas de carretera.
        code ! Road_Draw
        call    V9_RoadSetup
        nop
; Cada linea de carretera se emite como una copia del V9990 en vez de rellenar el bufer.
        code ! Road_LinePlainGo
        jp      V9_LinePlain
        code ! Road_LineBandGo
        jp      V9_LineBand
; Horizonte: montanas (una o dos copias desde su tira en VRAM) y cielo (un relleno) en
; vez de dibujarlos linea a linea en el bufer. Mnt_SelectGfx empieza con "ld a,scroll"
; (operando automodificado, se conserva); Sky_Fill es tambien la salida de Road_Draw.
        code ! Mnt_SelectGfx+2
        jp      V9_Mountains
        code ! Sky_Fill
        jp      V9_Sky
; Sprites escalados: se conserva el recorte horizontal del original (columna, columnas
; visibles, bytes saltados, eleccion de los datos desplazados) y, a partir de ahi
; (Spr_CheckMask), todo lo hace V9_Sprite: recorte vertical, posicion en la hoja y comando.
        code ! Spr_CheckMask
        jp      V9_Sprite
; Sprites sin escalar (piezas del coche, sombra, polvo, chispas, sirena): entrada unica
; Spr_DrawMasked. La carroceria opaca del coche la dibujaba Car_DrawBody llamando
; directamente a los blitters opacos.
        code ! Spr_DrawMasked
        jp      V9_Unscaled
        code ! Car_CallOpaque
        call    V9_CarBody
        code ! Car_CallOpqMirror
        call    V9_CarBodyM
; Coche del criminal en el monitor de la pantalla de presentacion (Lvl_IntroMap): el
; original lo pinta con el blitter opaco, que usa SP como puntero a los datos... y en el
; port el descriptor ya no lleva un puntero a datos sino la posicion en la hoja (1820h en
; el nivel 3: ROM de la BIOS en el MSX1, y aqui la tabla de anchuras TV9W, donde cada
; interrupcion que llegaba apilaba su retorno, estropeando lineas de carretera para el
; resto de la partida). En la ROM normal lo copia de la hoja V9_IntroCar (src/title.asm);
; en la de pruebas no se dibuja.
        code ! Lvl_IntroMapDraw
        ret
        if ORIG_INPUT = 0
        code ! Lvl_IntroMap
        jp      V9_IntroCar
        endif

; Pantalla "monitor" del aviso de inicio de nivel: el fondo (marco, TUNE, VOLUME, SIGNAL, rejilla)
; es una imagen (assets/editable/monitor.png) que aparece de golpe con una copia.
        if ORIG_INPUT = 0               ; (solo en la ROM normal: la de pruebas no tiene hueco)
; Sin fundidos de pantalla (la "cortinilla" de puntos): el original los hacia con un OR de tramas sobre el
; bufer de ventana, que ya no se ve. Fx_StartDissolve no arranca nada (vFxState no pasa a 4) y su codigo
; y el del paso (Fx_DissolveStep: 8DA5-8DF8 y 8DFC-8E28) quedan libres.
        code ! Fx_StartDissolve         ; (el estado 4 se queda: las secuencias esperan a que acabe, p. ej. GAME OVER)
        jp      V9_FxStart
        code ! 8DA0h                    ; Fx_DissolveStep: acaba en el acto
        xor     a
        ld      (vFxState),a
        ret
        code ! Game_StFadeOut           ; fin de nivel: el fundido de salida se hace con la pantalla en negro
        jp      V9_FadeOut
        code ! Lvl_PlayLoad
        call    V9_PlayLoad
        code ! Lvl_BeginIntro           ; al salir del monitor, pantalla en negro y sin sonido hasta el primer cuadro
        call    V9_IntroDone
        code ! Txt_PutChar              ; registra las filas de la ventana en las que escribe (V9_Msg)
        jp      V9_PutLog
        code ! Lvl_IntroClear
        call    V9_IntroEnter
        code ! Lvl_IntroPresent
        call    V9_IntroPresent
        endif

; ------------------------------------------------------------ sonido (src/sound.asm)
; Fuera el sonido del original por el clic del teclado: Snd_Update y sus efectos
; (8903-8A55) y el motor (8204-8257) se sustituyen por el reproductor de VGM, que va en su
; sitio. Los ganchos 83B5-83CC (en el Spectrum 128K, su driver AY) van al reproductor.
; Pausa: con el sonido en pausa (la interrupcion no avanza las pistas y calla el PSG).
        code ! 88BCh                    ; Game_Pause: "call Snd_HookStop / ..."
        jp      V9_Pause
        code ! Snd_Hooks
        jp      V9_SirenOn              ; Target: coche objetivo a la vista -> sirena
        jp      Snd_Nop                 ; EngineTick (~11 por frame): nada
        jp      V9_SndHush              ; Stop: calla sirena y turbo
        jp      Snd_Nop                 ; Frame: el PSG lo escribe la interrupcion
        jp      V9_TurboOn              ; Turbo
        jp      V9_Engine               ; Engine: periodo del motor
        jp      Snd_Nop                 ; Tune: voces del 128K (aun no)
        jp      V9_Title                ; Title: demo del titulo con su musica
; Trucos del Spectrum (teclas 1-5 por el puerto FEh, con vDebug <> 0): nunca se activan en
; MSX. Se saltan y su sitio (84C4-84FA) lo usa el sonido.
        code ! 84C2h                    ; Main_Cheats: "ld a,(vDebug) / and a / jr z,Main_EndFrame"
        jr      84FBh                   ; Main_EndFrame
; Solo la embestida al criminal pide el nuevo efecto 10. Prioridad 0 para que
; la cuneta/derrape de este mismo frame no sustituya el impacto. No tocar A7E6:
; el byte alto del JP Snd_Request es tambien el indice 0 de tLaneX.
        if ORIG_INPUT = 0
        code ! 0A7E1h
        ld      bc,0A00h
        endif
        code ! Snd_Update
        jp      V9_SndUpdate
        include "sound.asm"
; La palanca va por el PSG (R14/R15): sin interrupciones mientras se lee, para que la del
; retrazado no cambie el registro seleccionado en medio.
        code ! ReadJoystick             ; "push bc / push ix"
        jp      V9_JoyRead
        code ! ReadJoystick+2Ah         ; "pop ix / pop bc / ret"
        jp      V9_JoyEnd
