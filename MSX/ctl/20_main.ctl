# 20_main.ctl -- zona 76F0-8FFF: datos graficos compartidos, cargador de nivel,
# ganchos de sonido, bucle principal, maquina de estados de la partida, efectos
# de pantalla (fundido / mensajes) y paisaje lateral.
#
# Nota: 8014-83B1 y 83B5-83CC son, en la version Spectrum 128K, sustituidos por
# codigo copiado de F220 y E876 (entrada E816, vA139=1). En MSX vA139=0 y lo que
# hay aqui es la version "48K": cinta, sonido por clic de teclado (OUT #AA bit 7)
# y ganchos de musica vacios (todos acaban en el RET de @8A56).

# ================================================================ datos 76F0-7FFF
L 76F0 tHudTurboIcon
> 76F0 Icono de turbo del marcador: 3 fotogramas de 0x38 bytes (14 lineas x 2 columnas,
> 76F0 pares mascara/dato leidos con POP DE: E=mascara, D=dato). Lo dibuja @9E11
> 76F0 (fotograma 1-2 animado mientras el turbo esta activo).
D 76F0 7797 b
L 7798 tMonitorTexts
> 7798 Textos de la pantalla "monitor" de inicio de nivel: 4 registros de texto sin
> 7798 byte de estilo (atributo, dir. buffer, dir. atributos, texto con bit 7 final),
> 7798 impresos por @86E8 con estilo 4 (inverso): "CHASE H.Q. MONITORING SYSTEM",
> 7798 "TUNE", "VOLUME", "SIGNAL".
D 7798 77D7 t
L 77D8 tMonitorLayout
> 77D8 Flujo de composicion de la pantalla monitor (lo interpreta @865A):
> 77D8   00            fin
> 77D8   F0-FF lo      posicion: DE = (byte, lo) direccion en el buffer F000
> 77D8   E0-EF         modo de avance (n-E0): 1 = a la derecha, otro = hacia abajo
> 77D8   D0-DF         atributo: (n-D0)*8 (0 = no escribir atributo)
> 77D8   01-1E t       repetir n veces el tile t
> 77D8   1F-CF         un tile (indice n-1F en @78A7, 8 bytes por tile)
D 77D8 78A6 b
L 78A7 tMonitorTiles
> 78A7 Tiles 8x8 de la pantalla monitor (45 tiles, 8 bytes = 8 lineas).
D 78A7 7A0E g 1
L 7A0F tLvlSharedA
> 7A0F Datos sin referencia desde el codigo; los apuntan bloques de nivel (5C00-76EF)
> 7A0F (p.ej. punteros a 7AFA, 7B00, 7B25). Probablemente graficos de sprites
> 7A0F compartidos por todos los niveles (?).
D 7A0F 7B34 b
L 7B35 tPortraitBase
> 7B35 Retratos de la radio (Nancy, etc.): el retrato n (n>=1) esta en
> 7B35 tPortraitBase + n*0xB4 (ver @9A0C); el n=0 lo da el nivel (puntero en 5CF2).
> 7B35 Cada retrato: 0xA0 bytes de bitmap (4 columnas x 40 lineas) + 0x14 bytes de
> 7B35 atributos (4x5). El hueco 7B35-7BE8 (slot 0) tiene otros datos, apuntados
> 7B35 desde bloques de nivel (?).
D 7B35 7BE8 b
L 7BE9 tPortrait1
D 7BE9 7C88 g 4
L 7C89 tPortrait1Attr
D 7C89 7C9C b
L 7C9D tPortrait2
D 7C9D 7D3C g 4
L 7D3D tPortrait2Attr
D 7D3D 7D50 b
L 7D51 tPortrait3
D 7D51 7DF0 g 4
L 7DF1 tPortrait3Attr
D 7DF1 7E04 b
L 7E05 tLvlSharedB
> 7E05 Tablas apuntadas solo desde los bloques de nivel (muchos punteros a 7E05-7F88
> 7E05 en 5C00-76EF). Contienen a su vez punteros a 7Exx/7Fxx: descriptores de
> 7E05 objetos/sprites comunes a todos los niveles (?).
D 7E05 7F8C b
D 7F8D 7FFF z

# ================================================================ cargador de nivel
L 8014 Lvl_Load
> 8014 Asegura que el nivel vLevel (8007) esta en memoria. Si coincide con el ultimo
> 8014 cargado (A13A) no hace nada. Si no: borra pantalla, pide la cinta y busca el
> 8014 bloque del nivel: cabecera de 2 bytes en A19C (n.nivel, n.nivel) y despues
> 8014 0x1AF0 bytes en 5C00 (@80B9). Si la cabecera no es del nivel buscado sigue
> 8014 buscando ("FOUND n" y vuelta a empezar). Al final "STOP THE TAPE / PRESS GEAR"
> 8014 y espera a que se pulse y suelte el boton (bit 4 de @A0D6).
> 8014 Efectos: A13A, A220, digitos de los mensajes en @81AE y @81BA.
; 801D A220 = nivel (luego se reutiliza)
; 8022 digito del mensaje "SEARCHING FOR n"
L 8025 Lvl_LoadRetry
L 8032 Lvl_SearchLoop
L 8035 Lvl_ReadHeader
; 8035 cabecera de 2 bytes en A19C (zona de objetos, aun libre)
; 804B digito del mensaje "FOUND n"
; 805C error de carga: se vuelve a empezar
L 806A Lvl_WaitGear
; 8070 espera a que se pulse el boton...
; 8077 ...y a que se suelte
; 807E fundido de salida mientras se reimprimen los mensajes
L 8088 Lvl_PrintTapeMsgs
> 8088 Imprime B registros de @818C (B+1 desde @8169 en el nivel 1, que antes pide
> 8088 rebobinar la cinta).
L 8098 Txt_PrintRecsWaitFx
> 8098 Imprime B registros de texto consecutivos desde HL (estilo 5, sin byte de
> 8098 estilo en los datos), avanza el efecto de pantalla (@8D8F), vuelca la pantalla
> 8098 entera al TMS (@3534) y repite (con espera) mientras dure el efecto (vA231).
> 8098 Conserva HL y B.
L 80B9 Lvl_LoadBlock
L 80C0 Lvl_TapeLoad
; 80C0 IX = destino, DE = longitud; CF=1 si va bien
L 80C3 ZX_LdBytesRemnant
> 80C3 Restos de la rutina LD-BYTES de la ROM del Spectrum (puerto #FE). Codigo
> 80C3 muerto en MSX: la carga la hace @3400.
D 80C3 8168 b

L 8169 tTapeMsgs
> 8169 Registros de texto de la carga (sin byte de estilo; los imprime @8098):
> 8169   atributo, dir. buffer (w), dir. atributo (w), texto con bit 7 en el ultimo.
> 8169 8169 "REWIND TAPE TO START OF SIDE 2" (solo nivel 1), 818C "START TAPE",
> 8169 819B "SEARCHING FOR n", 81AF "FOUND n", 81BB "STOP THE TAPE", 81CD "PRESS  GEAR".
D 8169 81DC t
L 818C tTapeMsgStart
L 81AE tTapeSearchDigit
L 81AF tTapeMsgFound
L 81BA tTapeFoundDigit
L 81BB tTapeMsgStop
L 8193 ZX128_Hook8193
> 8193 Destino de llamadas que solo se hacen con vA139<>0 (version 128K, donde aqui
> 8193 hay otro codigo). En MSX es texto y nunca se llama.
L 81AA ZX128_Hook81AA
L 81DD tNancyStartMsg
> 81DD Guion de radio al empezar la carrera (lo arranca @843E via @9945):
> 81DD FC p1 p2 p3 = salto aleatorio a uno de 3 guiones; cada guion: hablante
> 81DD (retrato n), puntero al texto, ... FF fin.
D 81DD 81E3 b
L 81E4 tNancyGiddyUp
D 81E4 81E4 b
D 81E5 81E6 a
D 81E7 81E7 b
L 81E8 tNancyHoldOn
D 81E8 81E8 b
D 81E9 81EA a
D 81EB 81EB b
L 81EC txtGiddyUp
D 81EC 81F8 t
L 81F9 txtHoldOn
D 81F9 8203 t

# ================================================================ sonido del motor
L 8204 Snd_EngineSetup
> 8204 Calcula los parametros del ruido del motor a partir de la velocidad (A24A) y
> 8204 de la marcha (A253: en marcha corta el periodo se divide por 2). Con A23B<>0
> 8204 (?) el pulso es mas corto. Escribe los operandos de @8243, @8248 y @8250 y cae
> 8204 en @8234.
L 8234 Snd_EngineTick
> 8234 Ruido del motor por el clic de teclado (PPI puerto #AA bit 7). Se llama ~11
> 8234 veces por frame (gancho @83B8); suena una de cada 4 llamadas: C pulsos con
> 8234 tiempos alto/bajo fijados por @8204. Calla si vGameState (A230) >= 3.
; 8243 numero de pulsos
; 8248 duracion de la parte baja
; 8250 duracion de la parte alta

# ================================================================ titulo / demo
L 8258 Title_Loop
> 8258 Pantalla de titulo con demo (gancho @83CA). Inicializa las variables de
> 8258 carrera con el bloque de demo del nivel (5D2B), velocidad 400, y en cada frame:
> 8258 juega un frame de demo (@852A), imprime "CHASE H.Q." y "PRESS GEAR TO PLAY"
> 8258 (parpadeando) y alterna los mensajes de creditos y copyright. Vuelve en cuanto
> 8258 se pulsa el boton de marcha (bit 4).
L 8268 Title_Frame
; 8276 mascara rotatoria: 1 o 2 registros (parpadeo de "PRESS GEAR TO PLAY")
L 82A6 tTitleTexts
> 82A6 Registros con byte de estilo: "CHASE H.Q." (estilo 3) y "PRESS GEAR TO PLAY"
> 82A6 (estilo 2). Formato del registro: estilo, atributo, dir. buffer (w), dir.
> 82A6 atributo (w), texto con bit 7 en el ultimo caracter.
D 82A6 82CB t
L 82CC tMsgCredits
> 82CC Mensaje (formato @8E7E): PROGRAM / GRAPHICS / MUSIC.
D 82CC 831F t
L 8320 tMsgCopyright
D 8320 837B t
D 837C 83B4 z

# ================================================================ ganchos
> 83B5 Tabla de ganchos (en el Spectrum 128K se sustituye por la de E876, que llama
> 83B5 al reproductor de musica AY). En MSX solo hay sonido de motor y titulo.
L 83B5 Snd_HookTarget
C 83B5
; 83B5 musica: coche objetivo a la vista (vacio)
L 83B8 Snd_HookEngineTick
L 83BB Snd_HookStop
; 83BB parar musica (vacio)
L 83BE Snd_HookFrame
; 83BE musica: paso por frame (vacio)
L 83C1 Snd_HookTurbo
; 83C1 efecto de turbo (vacio)
L 83C4 Snd_HookEngine
L 83C7 Snd_HookTune
; 83C7 tocar melodia A (vacio)
L 83CA Snd_HookTitle

# ================================================================ partida
L 83CD Game_Start
> 83CD Bucle externo del juego (se llega desde @E810 tras el menu). Construye en EF00
> 83CD la tabla de inversion de bits (para sprites espejados), pasa por el titulo,
> 83CD pone a cero puntos (8002-8005) y continues usados (8006), nivel 1, A13C=0,
> 83CD 2 creditos (A13D) y juega (@8401) hasta el fin de partida.
; 83D0 EF00+n = n con los bits invertidos
; 83F5 version 128K: tabla de records (?)
L 8401 Lvl_Play
> 8401 Juega desde el nivel vLevel: carga el nivel y entra en el bucle principal.
> 8401 Solo vuelve al acabar la partida. Nivel 6 = final: ejecuta el codigo del
> 8401 bloque cargado en 5C00, recarga el nivel 1 y vuelve.
; 840B nivel 6: el bloque cargado es codigo (secuencia final)
L 841B Lvl_Begin
; 8424 A13B: pista musical, rota 3,2,1
; 8430 A26B: (pista*4)|2, se toca 2 frames despues (@8502)
; 843B objeto 0 (coche objetivo) activo
L 8444 Main_Loop
> 8444 Bucle principal: un frame de juego. Entre los pasos se llama al gancho
> 8444 @83B8 para mantener el ruido del motor.
; 8444 sonido: efectos y motor
; 8447 lee controles -> A0D5
; 844A cronometro, TIME UP y continue
; 844D teclas especiales (abortar, pausa, turbo)
; 8450 avance de la carretera segun la velocidad
; 8453 maquina de estados de la partida
; 84BC presentar el buffer en la pantalla MSX
L 84C2 Main_Cheats
> 84C2 Trucos (con 8000<>0): teclas 1-5 del Spectrum (IN #FE fila F7). En MSX el
> 84C2 puerto #FE no es el teclado y 8000 nunca se activa: codigo muerto.
; 84DD tecla 1: reiniciar nivel
; 84E6 tecla 2: nivel siguiente
; 84ED tecla 3: secuencia final (nivel 6)
; 84F2 tecla 4: un credito mas (max 9)
L 84FB Main_EndFrame
; 84FB con un efecto de pantalla en curso no se mira nada mas
; 8505 A26B: tocar la musica de la carrera con 2 frames de retraso
L 8512 Main_CheckGameOver
; 8512 A26A: 0 = jugando, 1 = fin -> fundido, 2 = secuencia de GAME OVER
L 852A Demo_Frame
> 852A Un frame de la demo del titulo: piloto automatico que genera la entrada
> 852A (A0D5) segun la posicion lateral (A26C): bit 3 acelerar, bits 0/1 girar,
> 852A bit 4 cambio de marcha segun la velocidad. Despues ejecuta los pasos de
> 852A logica y dibujo del bucle principal (sin sonido, cronometro ni marcador).

# ================================================================ presentacion de nivel
L 858C Lvl_Intro
> 858C Pantalla "monitor" de inicio de nivel: Nancy da el aviso por radio (guion en
> 858C (5D04)), coche del criminal en la pantalla del monitor y medidores. Termina al acabar el guion o al
> 858C pulsar el boton (salta el mensaje y toca la melodia 5).
L 85A8 Lvl_IntroLoop
L 85D6 Lvl_IntroFadeOut
C 85DD
> 85DD Fragmento muerto (no lo referencia nadie).
L 85E4 Lvl_IntroMap
> 85E4 Dibuja el coche del criminal en la pantalla del monitor, descubriendolo de abajo
> 85E4 arriba una linea por frame (hasta 49): el fotograma de la escala 0 (la mas cercana)
> 85E4 de su lista (5D10), en la columna 13 con la ultima linea en la 100 de la ventana.
> 85E4 No se hace en el nivel 5.
L 8613 Lvl_IntroMeterA
L 860F Lvl_IntroMeters
> 860F Dos barras de 8 celdas en atributos (5A17 y 5A57) con paseo aleatorio:
> 860F "VOLUME" y "SIGNAL" del monitor.
L 8646 Lvl_IntroMeterBar
L 865A Lvl_IntroDrawMonitor
> 865A Interpreta el flujo @77D8 (tiles @78A7) sobre el buffer F000 y los atributos
> 865A y luego imprime los textos @7798.
L 86E8 Lvl_IntroMonitorTexts
L 86F6 tMtnChainTpl
> 86F6 Plantilla de instrucciones que copia @C7FE a @C82D: 9 x "INC L / NOP"
> 86F6 seguidos de 9 x "LDI" (cadena del fondo de montanas).
D 86F6 8719 b
L 871A tGameOverParams
> 871A Parametros de carrera (14 bytes, ver @87DC) para la secuencia de GAME OVER:
> 871A posicion lateral 0x134 y punteros de recorrido a tablas fijas (E2A3-E2B3).
D 871A 871B w
D 871C 8727 a
L 8728 tGameOverCar
> 8728 Estado inicial (20 bytes) del objeto 0 (coche objetivo, A188) en GAME OVER:
> 8728 activo, fila 1, lat 4Ch, anchura 2Ch, velocidad relativa 00FAh y comportamiento
> 8728 Obj_NoUpdate (no hace nada). Replay chasehq_secondstage: GAME OVER a t=866,6 s.
D 8728 8732 b
D 8733 8734 a
; 8733 Obj_hndlo/hi
D 8735 873B b
L 873C Game_OverSeq
> 873C Secuencia de GAME OVER: carretera recta, el coche objetivo escapa, mensaje de
> 873C radio (992A) y "GAME OVER"; termina con un fundido. Vuelve a @83F5.
L 8767 Game_OverLoop
L 87BB Game_OverCheck

L 87DC Lvl_InitVars
> 87DC Inicializa las variables de carrera. HL = bloque de 14 bytes que se copia a
> 87DC A26C-A279 (A26C posicion lateral + 6 punteros de recorrido). Borra el anillo
> 87DC de segmentos EE00, copia la plantilla A13E-A16C a A16D-A19B, pone a cero
> 87DC A19C-A26B (objetos y estado), prepara el fondo (@C8BE), vacia los ganchos
> 87DC de @8F5F, rellena 32 segmentos de carretera, borra la pantalla con fundido
> 87DC de entrada y dibuja el marcador (@9D62).
; 87ED copia (no borra) la plantilla de variables
; 8813 vacia los ganchos de @8F5F
; 8857 paneles del marcador sin brillo

# ================================================================ entrada
L 8876 Input_Special
> 8876 Filtra la entrada A0D5 con la mascara A16F y atiende los bits altos:
> 8876 bit 7 abortar (@88A9), bit 6 pausa (@88BC), bit 5 turbo (si quedan, A170, y
> 8876 no hay uno activo: A24E = 60 frames, mensaje de radio y gancho de turbo).
> 8876 Durante el fundido (vA231=4) anula la entrada.
L 88A9 Game_Abort
> 88A9 Fin de partida (abortar o sin creditos): corta la radio, borra la ventana,
> 88A9 mascara de entrada 0 y A26A=1.
L 88BC Game_Pause
> 88BC Pausa: espera a soltar la tecla de pausa y a pulsar y soltar cualquier otra.
L 88D5 Scr_ClearAttrsLow
> 88D5 Atributos 5900-5AFF (filas 8-23) a 0.
L 88E2 Scr_ClearLow
> 88E2 Filas 8-23 de la pantalla (bitmap 4800-57FF y atributos) a 0.

# ================================================================ efectos de sonido
L 88F2 Snd_Request
> 88F2 Pide el efecto B con prioridad C: se acepta si no hay ninguno pendiente o si
> 88F2 la prioridad C es >= la del pendiente. Se toca en el siguiente @8903.
L 8903 Snd_Update
> 8903 Sonido por frame: si se pisa fuera de la carretera (A23C|A23D) pide el
> 8903 efecto 7; prepara y emite el motor; toca el efecto pendiente (A237) via la
> 8903 tabla @893C: D,E = parametros, salto a la rutina.
L 8938 Snd_SfxDispatch
L 893C tSfxTable
> 893C Tabla de efectos 1-9: D, E, rutina. Todos van por el clic de teclado (#AA).
D 893C 893D b
D 893E 893F a
D 8940 8941 b
D 8942 8943 a
D 8944 8945 b
D 8946 8947 a
D 8948 8949 b
D 894A 894B a
D 894C 894D b
D 894E 894F a
D 8950 8951 b
D 8952 8953 a
D 8954 8955 b
D 8956 8957 a
D 8958 8959 b
D 895A 895B a
D 895C 895D b
D 895E 895F a
; 893C 1: ruido aleatorio
; 8940 2: secuencia de pulsos
; 8944 3: muestra de 1 bit
; 8948 4: muestra de 1 bit mas lenta
; 894C 5: secuencia de pulsos rapida
; 8950 6: ruido
; 8954 7: ruido (fuera de pista)
; 8958 8: barrido
; 895C 9: barrido
L 8960 Snd_SfxSample
> 8960 Reproduce la muestra de 1 bit @897C (0x5D bytes), D = retardo por bit.
L 897C tSfxSample
D 897C 89D8 b
L 89D9 Snd_SfxPulses
> 89D9 Tren de pulsos: 32 duraciones de @89EF, D = escala de tiempo.
L 89EF tSfxPulses
D 89EF 8A0E b
L 8A0F Snd_SfxNoiseAlt
> 8A0F Como @8A17 pero solo en frames alternos.
L 8A17 Snd_SfxNoise
> 8A17 Ruido: D x E clics con presencia aleatoria y anchura decreciente.
C 8A36
L 8A36 Snd_SfxSweep
> 8A36 Barrido de tono (efectos 8 y 9). No se ha visto ejecutarse.
L 8A56 Snd_Nop

# ================================================================ maquina de estados
L 8A57 Game_StateStep
> 8A57 Maquina de estados de la carrera, vGameState (A230):
> 8A57   0 persecucion normal (no hace nada)
> 8A57   1 @8B8D "PULL OVER": piloto automatico, ambos coches se apartan y frenan
> 8A57   2 @8A88 detencion: el coche se desplaza al arcen
> 8A57   3 @8ABE espera 4 frames y lanza el mensaje de captura del nivel (5D06)
> 8A57   4 @8AD2 (sin mensaje en curso) calcula e imprime los bonus
> 8A57   5 @8A7E (sin mensaje) fundido de salida
> 8A57   6 (fundido acabado) nivel siguiente: descarta el retorno y salta a @8401
L 8A7E Game_StFadeOut
L 8A88 Game_StArrest
L 8AB2 Game_StArrestEnd
L 8ABE Game_StWait
L 8AD2 Game_StBonus
> 8AD2 Bonus de fin de nivel: CLEAR BONUS = nivel x 100.000 (x 10.000 si se ha usado
> 8AD2 algun continue, 8006<>0); TIME BONUS = tiempo restante (A17E, BCD) x 5.000.
> 8AD2 Suma al marcador (@9D17), escribe los digitos en @8C58 y lo muestra.
> 8AD2 BUG DEL ORIGINAL (mismo codigo en el ZX 48K y 128K): la parte de unidades del
> 8AD2 TIME BONUS no repite "unidades" veces sino A' veces. Los EX AF,AF' de @8B24/@8B2A,
> 8AD2 @8B34 y @8B3D intercambian de mas: en @8B3E A = el A' que traia la rutina
> 8AD2 (14h/15h en el replay), no el digito, que vuelve a A en @8B48 solo para
> 8AD2 imprimirse. Medido en chasehq_firststage.omr (t=561,4 s): TIME 04 con un
> 8AD2 continue usado -> +10.000 de nivel y +100.000 (20 x 5.000) en vez de +20.000.
> 8AD2 El texto en pantalla es correcto; solo el marcador recibe la cifra erronea.
> 8AD2 Replay chasehq_5 (4 capturas): A' = 00h, 15h, 03h, 14h -> nivel 1 con TIME 15: +1.430.000
> 8AD2 en vez de +175.000 (B=0 da 256 vueltas); nivel 2 TIME 03: +305.000 (bien: 215.000);
> 8AD2 nivel 3 TIME 11 con continue: +95.000 (85.000); nivel 4 TIME 08: +140.000 (80.000).
; 8B3E BUG: A es el A' de entrada a la rutina, no las unidades del tiempo (ver @8AD2)
; 8B4E puntuacion BCD 8005..8002 -> 8 digitos sin ceros a la izquierda
L 8B8D Game_StPullOver
> 8B8D El coche objetivo (A18D) se lleva a X=0x23; la entrada del jugador se genera
> 8B8D como en la demo; al agotar A173 se para todo y se pasa al estado 2.
L 8BE5 Game_PullOverSpeed
L 8C35 Game_SetTargetSpeed
C 8C3A
L 8C3A Game_CatchTarget
> 8C3A Coche objetivo inutilizado (danos A233 >= 20, desde B50C): estado 1, mascara de
> 8C3A entrada C0 (solo pausa/abortar) y mensaje "OK! PULL OVER CREEP!".
L 8C58 tMsgBonus
> 8C58 Mensajes (formato de @8E7E): retardo inicial, y por cada linea: retardo, registro
> 8C58 con estilo (estilo, atributo, dir. buffer, dir. atributo, texto|80); final:
> 8C58 nuevo valor de vA231, 00.
D 8C58 8D8E t
L 8C6F tMsgBonusClearDigits
L 8C8A tMsgBonusTimeDigits
L 8CA8 tMsgScoreDigits
L 8CB2 tMsgSighting
L 8CD6 tMsgPullOver
L 8CF4 tMsgGameOver
L 8D07 tMsgTimeUp
L 8D18 tMsgContinue
L 8D7C tMsgContinueTimer
L 8D8C tMsgCreditDigit

# ================================================================ efectos de pantalla
L 8D8F Fx_Step
> 8D8F Paso por frame del efecto de pantalla vA231:
> 8D8F   0 nada, 1 retratos + mensaje (@8E91), 2 mensaje maquina de escribir (@8E42),
> 8D8F   3 borrar colores de la ventana (@8E29), 4 fundido (@8DA0).
L 8DA0 Fx_DissolveStep
> 8DA0 Fundido: OR de 8 bytes de trama (uno por linea de caracter) sobre todo el
> 8DA0 buffer F000; la trama avanza 8 bytes (o retrocede) por frame. Al agotar el
> 8DA0 contador vA231 = 0.
L 8DD8 Fx_OrLine
> 8DD8 OR de E sobre la linea H del buffer: 8 filas de caracter x 30 columnas.
L 8DF9 Fx_StartDissolve
> 8DF9 Inicia un fundido. A=+8: hacia tinta (salida); A<0 (#F8): entrada. Elige al azar
> 8DF9 una de 4 tramas de la tabla EC00 (salida) o EC0C (entrada): contador, puntero.
L 8E29 Fx_ClearWinAttrs
> 8E29 Copia el atributo de la columna 1 a las columnas 2-29 de las filas 8-23
> 8E29 (borra el color de los textos) y vA231 = 0.
L 8E42 Msg_Typewriter
> 8E42 Mensaje progresivo: cada frame reimprime las lineas ya mostradas; al agotar
> 8E42 el retardo anade la siguiente. Al llegar al 00 final, vA231 = byte anterior.
L 8E6C Msg_PrintRec
> 8E6C Imprime un registro de texto en HL+1: A = estilo (1 normal, 2 con linea en
> 8E6C blanco arriba, 3 con marco, 4 inverso, 5 inverso doble altura, 6+ doble altura),
> 8E6C atributo, dir. en buffer, dir. de atributos y texto. Sale con HL tras el texto.
L 8E7E Msg_Start
> 8E7E Arranca el mensaje de HL (vA231 = 2).
L 8E80 Msg_StartMode
> 8E80 Arranca el mensaje de HL con vA231 = A (1 = con retratos).
L 8E91 Msg_PortraitsStep
> 8E91 Modo 1: dibuja tres retratos (el del nivel (5CF0), @7DF1 y @7D3D) copiados
> 8E91 al reves en el buffer y luego sigue con el mensaje. Usado tras la captura.
L 8EB7 Gfx_PortraitReversed

# ================================================================ HUD / paisaje
L 8EE7 Hud_DamageMeter
> 8EE7 Medidor vertical de danos del coche objetivo (A233 segmentos) en el buffer
> 8EE7 (F7A2), solo cuando el objetivo esta localizado (A22E) y en estados < 3.
L 8F13 Hud_MeterSegments
L 8F47 Hud_MeterLines
> 8F47 B lineas de #FF hacia arriba en el buffer (H decreciente con salto de fila).
L 8F5F Scn_DrawRoadside
> 8F5F Objetos de paisaje a los lados de la carretera: recorre 20 filas de
> 8F5F profundidad del anillo de segmentos (EE73+) y para cada tipo no nulo llama a
> 8F5F la rutina de la tabla del nivel (5CF8 izquierda, 5CFE derecha; entradas de 7
> 8F5F bytes). Al final dibuja un sprite extra (E1DF/E1E4) si A227<>0 (?).
> 8F5F Tiene tres huecos de 3 bytes que otras rutinas parchean con CALL.
L 8F82 Scn_HookPre
; 8F82 hueco: CALL @C15B o NOPs (lo escribe @C0E1)
L 8F96 Scn_RowLoop
L 8FA4 Scn_HookRowA
; 8FA4 hueco: CALL (lo escribe AB8E)
L 8FA7 Scn_HookRowB
; 8FA7 hueco: CALL @C15B o NOPs (lo escribe @C0E1)
L 8FF8 Scn_DrawLeft
