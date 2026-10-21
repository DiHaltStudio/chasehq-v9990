# 01_vars.ctl -- variables globales (unico fichero donde se etiquetan)
#
# Consolidado de los informes de analisis (MSX/analysis/*.md). Las direcciones se han
# comprobado contra los bytes de las instrucciones. "(?)" = significado no confirmado.
#
# Bloques:
#   8000-8013  partida (puntos, nivel) + tabla de servicio para el bloque del nivel 6
#   A0CC-A0D5  controles
#   A139-A13D  sueltas (sobreviven entre niveles)
#   A13E-A16C  plantilla que Lvl_InitVars copia a A16D-A19B al empezar cada nivel
#   A16D-A19B  variables de carrera con valor inicial (copia de la plantilla)
#   A19C-A26B  variables de carrera puestas a 0 al empezar cada nivel
#   A26C-A279  parametros del nivel (copiados de LevelData+#11D, 14 bytes)
#   A27A-A398  fuente 8x7 (41 glifos de 7 bytes)

# ---------------------------------------------------------------- 8000-8013
L 8000 vDebug
> 8000 Truco/depuracion del Spectrum (tecla por IN FE en @84C2). Nunca se activa en MSX.
D 8000 8001 b
L 8002 vScore
> 8002 Puntuacion: 8 digitos BCD en 4 bytes, little endian (8002 = digitos menos
> 8002 significativos). Score_Add suma; el HUD la compara con vHudScore.
D 8002 8005 b
L 8006 vContinuesUsed
> 8006 Continuaciones usadas en la partida (reduce los premios: @A7C5, @8AF2).
D 8006 8006 b
L 8007 vLevel
> 8007 Nivel actual (1..5; 6 = secuencia final, codigo cargado en LevelData).
D 8007 8007 b
L 8008 tLvl6Services
> 8008 (?) Tabla de servicio para el codigo del bloque del nivel 6: dw @A0CC, dw #834E,
> 8008 dw @A27A, jp @A0D6, jp @9C79. Nadie la usa en los niveles 1-5.
D 8008 800D a
D 800E 8013 b

# ---------------------------------------------------------------- controles A0CC-A0D5
L A0CC vCtrlType
> A0CC Tipo de control elegido en el menu: 0 teclado, distinto de 0 joystick (puerto 1).
L A0CD tKeys
> A0CD Codigos de las 8 teclas: QUIT, PAUSE, TURBO, GEAR, ACCEL, BRAKE, LEFT, RIGHT.
> A0CD Codigo MSX: nibble bajo = fila de la matriz, nibble alto = bit+1 (Inp_TestKey).
> A0CD Con joystick solo se usan las 3 primeras (bits 7-5 de vInput).
L A0D5 vInput
> A0D5 Entrada del frame (Inp_Read), activa a 1: b0 derecha, b1 izquierda, b2 freno,
> A0D5 b3 acelerar, b4 marcha (disparo), b5 turbo, b6 pausa, b7 abandonar.
D A0CC A0D5 b

# ---------------------------------------------------------------- sueltas A139-A13D
L A139 vIs128K
> A139 0 en MSX (lo pone Init). Distinto de 0 activaria rutas solo del Spectrum 128K.
L A13A vLoadedLevel
> A13A Nivel cuyo bloque esta cargado en LevelData (evita recargar de cinta).
L A13B vTuneSel
> A13B Melodia de carrera 1..3 (rota en cada nivel; Snd_HookTune no hace nada en MSX).
L A13C vOvertakeBonus
> A13C Bonificacion por adelantamientos, BCD: +2 por coche, tope #80; a 0 al chocar.
L A13D vCredits
> A13D Continuaciones que quedan (2 al empezar la partida).
D A139 A13D b

# ---------------------------------------------------------------- plantilla A13E-A16C
L A13E tLevelVarsInit
> A13E Plantilla (#2F bytes) que Lvl_InitVars copia a A16D-A19B en cada nivel.
D A13E A16C b

# ---------------------------------------------------------------- A16D-A187
L A16D vForkSubCnt
> A16D (?) Subcontador de la bifurcacion (@BAB7, @BC36).
L A16E vSlowNagTimer
> A16E Frames por debajo de velocidad #78; a los 100 la radio regana (@B0F1).
L A16F vInputMask
> A16F Mascara aplicada a vInput (#93 / #FF segun el estado: TIME UP, captura).
L A170 vTurbos
> A170 Turbos que quedan (3 al empezar y al continuar).
L A171 vHorizonY
> A171 (?) Desplazamiento vertical del fondo por las colinas (palabra; @B8C3, @C7B2).
L A173 vCatchTimer
> A173 Temporizador del piloto automatico al detener al criminal (@8BC6).
L A174 vHudGear
> A174 Cache de la marcha dibujada en el HUD.
L A175 vHudScore
> A175 Cache de los 8 digitos del marcador dibujados (solo se redibujan los cambiados).
L A17D vSecFrames
> A17D Prescaler: frames por "segundo" del reloj (#0F).
L A17E vTimeBCD
> A17E Tiempo restante en BCD.
L A17F vHudTime
L A181 vHudDist
L A185 vTrackAux
> A185 (?) Estado auxiliar de un flujo de pista (@BC33, @C05C).
L A186 vHorizonAttrPtr
> A186 (?) Puntero/estado de los atributos del horizonte (@BD70).
D A16D A187 b

# ---------------------------------------------------------------- objetos A188-A1FF
L A188 tObjects
> A188 Tabla de 6 objetos de 20 bytes (estructura Obj, ver 40_zA000.ctl).
> A188 Objeto 0 = coche del criminal; objetos 1-5 (desde tTrafficObjs) = trafico y
> A188 obstaculos. Durante la carga de nivel A19C.. sirve de bufer de la cabecera.
L A19C tTrafficObjs
D A188 A1FF b

# ---------------------------------------------------------------- A200-A23F
L A200 vAYDriver
> A200 A200-A21F y A239/A23A: variables del driver AY de la version 128K (codigo F2xx,
> A200 machacado en MSX). Sin uso en MSX.
L A220 vA220
> A220 (?) Doble uso: driver AY y bandera escrita en Lvl_Load / @8594, leida en @BD5A.
L A221 vCutscene
> A221 FF durante la escena de fin de partida.
L A222 vDrawListCnt
> A222 Numero de entradas de la lista de dibujo tDrawList (E900).
L A223 vHudStageShown
L A224 vHeliState
> A224 Estado del helicoptero (Heli_Control). Replay chasehq_secondstage (nivel 2): 5 mientras
> A224 esta en pantalla (t=612,9-647 s), 2 al marcharse (Heli_Leave), 0 sin helicoptero.
L A225 vNoTraffic
> A225 (?) Lo fija el guion de pista: inhibe la generacion de trafico.
L A226 vForkCorrect
> A226 Rama correcta de la bifurcacion actual.
L A227 vHereArrow
> A227 Flecha "HERE!": 0 no, 1 derecha, 2 izquierda (guion de pista; leida en @8FCE).
L A228 vSirenOn
> A228 1 = sirena puesta en el techo del coche (la dibuja @B67C). La pone la animacion
> A228 de @B457; Lvl_InitVars la borra.
L A229 vTimeUpState
> A229 Maquina del reloj: 0 corre, 1 TIME UP, 2 creditos, 3 CONTINUE (cuenta atras), 4 fin.
L A22A vShakeY
> A22A Vibracion vertical del coche/pantalla (@B5C5, @B6D6).
L A22B vOvertaken
> A22B Coches adelantados en este paso (para vOvertakeBonus).
L A22C vHudPopupDirty
L A22D vHudPopupBlink
L A22E vTargetSighted
> A22E 1 cuando se ha avistado el coche del criminal (Crim_Sighted).
L A22F vSirenState
> A22F Brazo de la sirena (@B457): 0 nada, 1 colocandola (tras el avistamiento, ~1,5 s),
> A22F 2 durante la captura (vCatchState >= 1).
L A230 vCatchState
> A230 Maquina de captura: 0 persecucion, 1 PULL OVER (piloto automatico), 2 al arcen,
> A230 3 espera, 4 mensaje, 5 resultados/bonus, 6 siguiente nivel.
L A231 vFxState
> A231 Efecto de pantalla (Fx_Step): 0 nada, 1 retratos+mensaje, 2 mensaje progresivo,
> A231 3 borrar colores, 4 fundido. Distinto de 0 repite el bucle sin terminar el frame.
L A232 vCrimDmgLvl
> A232 Nivel de dano del criminal 0..6 (humo).
L A233 vCrimHits
> A233 Golpes al criminal 0..#14; con #14 se produce la captura.
L A234 vAnim4
L A235 vAnim2
L A236 vAnim4b
L A237 vSndReq
> A237 Efecto de sonido pedido (Snd_Request).
L A238 vSndPrio
L A23B vInTunnel
> A23B 5 dentro de un tunel, 0 fuera (lo pone Tun_FindInside). Confirmado en los replays:
> A23B nivel 1 t=211,9-223,4 s; nivel 2 t=650,9-653,9 y 677,4-685,9 s. Con 5 no suena el
> A23B traqueteo de la cuneta (@8903) y cambia el motor (@8204).
L A23C vRoadsideR
L A23D vRoadsideL
> A23C Banderas de objetos de cuneta acumuladas por tramo (campos 3/1 del anillo).
L A23E vOffroad
> A23E 0 en la calzada, 1/2 fuera de pista (Car_CheckRoadside).
L A23F vSegFrac
> A23F Fraccion de avance dentro del tramo; bits 7-5 = subposicion f (0..7).
D A200 A23F b

# ---------------------------------------------------------------- A240-A279
L A240 vTrackPos
> A240 Puntero al tramo actual en el anillo de pista (EE00 + byte bajo).
L A242 vStreamCnt
> A242 6 contadores de repeticion RLE de los flujos de pista.
L A248 vDecoEnable
L A249 vForkBranch
> A249 Rama tomada en la bifurcacion (1 = izquierda).
L A24A vSpeed
> A24A Velocidad (palabra). Maximos: marcha LO #E6, HI #168; con turbo #1D6/#2B7.
> A24A El HUD muestra km/h = vSpeed*82/100.
L A24C vHillCnt
L A24D vSkid
L A24E vTurboTimer
> A24E Duracion del turbo en curso (#3C al activarlo).
L A24F vScreechTimer
L A250 vCarTurnFrame
> A250 Fotograma de giro del coche 0..2.
L A251 vCarTurnDir
> A251 Espejado del coche (sentido del giro).
L A252 vGearDebounce
L A253 vGear
> A253 Marcha: 0 LO, 1 HI.
L A254 vSegsThisFrame
> A254 Tramos avanzados en este frame.
L A255 vCrimDistBCD
L A258 vSlope
L A259 vSlopePrev
L A25A vHillAcc
L A25C vCurve
L A25D vCurveIdx
L A25E vCurveTimer
L A25F vCentrifugal
L A261 vCurveAcc
L A263 vSteerL
L A264 vSteerR
> A263 Giro acumulado 0..#24 (+4 por frame pulsado, -9 al soltar).
L A265 vForkActive
L A266 vForkRow
L A267 vForkSep
L A269 vForkState
L A26A vGameOverState
> A26A Fin de partida: 1 fundido, 2 GAME OVER.
L A26B vPendingTune
D A240 A26B b
L A26C vPlayerX
> A26C Posicion lateral del jugador (palabra, #48..#1D8). Es la x del borde derecho de la
> A26C carretera en la linea 127; Geo_RoadX parte de ella.
> A26C Al girar a la
> A26C derecha la reduce (0112h -> 00E6h) y a la izquierda la aumenta (-> 013Eh): la
> A26C carretera se desplaza en pantalla al lado contrario del giro.
L A26E vStreamPtr
> A26E 6 punteros de los flujos de pista (curva, pendiente, flags, 3 de objetos).
D A26C A279 b

# ---------------------------------------------------------------- fuente
L A27A tFont
> A27A Fuente 8x7: 41 glifos de 7 bytes. Orden: ! ( ) , . 0-9 A-Z.
