# 40_zA000.ctl -- zona A000-AFFF (salvo el bloque de variables A0CC-A2FF, que va en 01_vars.ctl)
#
# Contenido: final de la impresion de texto 8x8 (A001-A0CB), lectura de controles (A0D6),
# colision del jugador con los bordes/objetos de la cuneta (A399), choque (A4B8),
# bordes de carretera por fila de profundidad (A579), contadores de animacion (A60E),
# coche del criminal (A637), trafico (A7F3/A8CD), objetos sobre la calzada (A955..AA37),
# objeto volador (AA38..AB99), obstaculos que salen despedidos (AB9A..AD0C) y gestion
# comun de la tabla de objetos de 20 bytes en A188 (AD0D..AFFF).

# ---------------------------------------------------------------- estructura de objeto
# Tabla de 6 objetos de 20 bytes en A188 (slot 0 = criminal, 1..5 = trafico/obstaculos).
S Obj 0 act      ; 0xFF activo, 0 libre (se prueba con RLC: bit 7 -> acarreo, el valor no cambia)
S Obj 1 row      ; fila de profundidad (parte entera): 0-1 junto al jugador, >=0x14 no visible
S Obj 2 xlo      ; X de pantalla del objeto (16 bits con signo, calculada en @AE24)
S Obj 3 xhi
S Obj 4 frac     ; fraccion de la distancia (row:frac = distancia de 16 bits)
S Obj 5 lat      ; posicion lateral en la calzada: 0 = borde izquierdo .. 0xFF = borde derecho
S Obj 6 scry     ; Y de pantalla (interpolada entre filas)
S Obj 7 hit      ; codigo de colision con el jugador (0 = ninguna; ver @AD51). Criminal: <0 = espera tras golpe
S Obj 8 width    ; anchura para la colision (obstaculo: + datos de sprite de LevelData+F6)
S Obj 9 sprlo    ; puntero a la tabla de sprites por escala (7 bytes por escala)
S Obj 10 sprhi
S Obj 11 hndlo   ; rutina de comportamiento (JP (HL)): @A8CD trafico, @A637 criminal, @AC3C obstaculo
S Obj 12 hndhi
S Obj 13 spdlo   ; velocidad relativa (16 bits): se resta de frac cada frame (@ADBE)
S Obj 14 spdhi
S Obj 15 kind    ; 0x80 trafico, 0xFF criminal; obstaculo: 0 intacto, 2 volando, 1 caido
S Obj 16 height  ; altura sobre el suelo (rebote del obstaculo); se resta de scry al dibujar
S Obj 17 lane    ; trafico/criminal: carril actual (1-4); obstaculo: indice en @ACDB; criminal en @C096: parte alta de la distancia
S Obj 18 tlane   ; trafico/criminal: carril destino; obstaculo: frames de vuelo restantes
S Obj 19 mirror  ; 1 = dibujar espejado (el obstaculo lo alterna al volar)
I A637 AFFF ix Obj
I A650 A68D iy Obj

# ---------------------------------------------------------------- texto 8x8 (cola de @9FB4)
# La rutina de caracter (zona 9xxx) salta aqui segun el modo de impresion (C):
# 1 @A0AD normal, 2 @A083 con lineas en blanco arriba/abajo + atributo, 3 @A03D doble altura,
# 4 @A031 inverso, 5 @A023 doble altura inverso, >=6 @A001 doble altura partido en dos filas.
# HL = glifo (7 bytes, fuente en A27A), DE = destino en pantalla; en EXX: HL' = atributo, C' = color.
> A001 Modo >=6: doble altura en dos filas de caracter (4 lineas dobles + 3 lineas dobles en la fila siguiente).
L A023 Txt_GlyphInvDbl
> A023 Modo 5: glifo en video inverso y doble altura (14 lineas seguidas).
L A031 Txt_GlyphInv
> A031 Modo 4: glifo en video inverso (7 lineas), un atributo.
L A03D Txt_GlyphDbl
> A03D Modo 3: doble altura (linea en blanco + 7 lineas duplicadas + linea en blanco), dos atributos.
L A074 Txt_Attr2
> A074 Final comun: avanza la columna (E) y pone el color C' en dos celdas de atributo (HL' y HL'+DE').
L A083 Txt_GlyphFramed
> A083 Modo 2: linea en blanco, 7 lineas del glifo y linea en blanco; un atributo.
L A0A4 Txt_Attr1
L A0AD Txt_GlyphPlain
> A0AD Modo 1: copia 7 lineas del glifo; si cruza el limite de fila de caracter, salta a la siguiente
> A0AD fila (formato Spectrum). Sin atributo.

# ---------------------------------------------------------------- controles
L A0D6 Inp_Read
> A0D6 Lee los controles y deja en A y en (A0D5) un byte activo-a-1:
> A0D6 bit0 derecha, bit1 izquierda, bit2 abajo (freno), bit3 arriba (acelerar), bit4 disparo (cambio de marcha),
> A0D6 bit5 turbo, bit6 pausa, bit7 abandonar.
> A0D6 Si (A0CC) <> 0 los bits 0-4 vienen del joystick (@ReadJoystick) y los bits 7..5 de las 3 primeras
> A0D6 teclas de la tabla A0CD; si (A0CC) = 0 los 8 bits salen de las 8 teclas de A0CD (bit7 = primera).
> A0D6 Al final anula pares opuestos pulsados a la vez (izq+der, arriba+abajo).
; A0DF el NOP sustituye probablemente a un byte del original Spectrum
; A0E1 centinela: 3 teclas
L A0F3 Inp_ReadKbdOnly
; A0F3 centinela: 8 teclas
L A0FB Inp_CancelOpposite
L A112 Inp_ReadKeyList
> A112 Lee teclas de la tabla HL (un byte por tecla) metiendolas por la derecha en E (1 = pulsada)
> A112 hasta que el bit centinela inicial de E sale por el acarreo. Devuelve A = E.
L A11E Inp_TestKey
> A11E Prueba una tecla de la matriz MSX. A = codigo: nibble bajo = fila (OUT #AA), nibble alto =
> A11E bit+1. Sale con CF = estado del bit (0 = pulsada).

# ---------------------------------------------------------------- colision con la cuneta
L A399 Car_CheckRoadside
> A399 Colision del coche del jugador con los bordes de la carretera y con los objetos de la cuneta.
> A399 Usa los bordes de la fila mas cercana que deja @A579: (EAFE) = borde izquierdo y (EAFC) = borde
> A399 derecho, en X de pantalla (el coche ocupa aprox. X 0x6A..0x8E).
> A399 Calcula (A23E) = salida de pista: 0 en la calzada, 1 con media rueda fuera, 2 fuera del todo.
> A399 Fuera de pista mira el byte de tramo EE(A240+0x40): bit6 = hay muro/valla; si ademas bit3 -> choque
> A399 (@A4B8); si no, rebote suave y limites laterales estrechos (0xD1..0x195).
> A399 En la calzada mira los objetos de cuneta del tramo: EE(A240+0x60) lado derecho (tabla LevelData+FA)
> A399 y EE(A240+0x20) lado izquierdo (tabla LevelData+100), registros de 7 bytes (min, max, velocidad
> A399 tras el choque, ...): si el borde cae en [min,max) hay choque.
> A399 Salidas: (A23E), (A23C)/(A23D) se borran si se esta lejos del borde, operandos automodificados de
> A399 la fisica: @B3DB+1 (rebote), @B395+1/@B3A3+1 (limites de X del jugador).
> A399 Con bifurcacion activa ((A265) <> 0) usa la variante @A4F6.
; A399 limites normales de la X del jugador (se pasan a @B395/@B3A3)
L A3D5 Car_CheckRightEdge
L A3FD Car_SetOffroad
L A426 Car_HitFence
> A426 Fuera de pista junto a una valla sin choque: limites estrechos y rebote (C = 1 o 2 segun lado).
L A43B Car_StoreBump
L A449 Car_CheckObstRight
L A480 Car_CheckObstLeft
L A4B0 Car_ObstCrash
L A4B8 Car_StartCrash
> A4B8 Inicia un choque del jugador (si no hay ya uno en curso, @B325+1 = 0).
> A4B8 Entradas: A = lado/tipo (0 o 1, +1 = sprite), A' = velocidad maxima tras el choque.
> A4B8 Programa la fisica de @B318: duracion 5, empuje lateral proporcional a la velocidad
> A4B8 (minimo 0x18, decae 1/16 por frame) y velocidad final = min(velocidad actual, A').
L A4F6 Car_CheckRoadsideFork
> A4F6 Variante de @A399 durante una bifurcacion: bordes en (E8FE) y (EDFC); despues comprueba el
> A4F6 separador central de la bifurcacion (LevelData+FC o +102 segun la rama elegida (A249)).
L A55C Car_CheckForkDividerR

# ---------------------------------------------------------------- bordes por fila
L A579 Road_BuildRowEdges
> A579 Convierte en sumas acumuladas los 21 incrementos de E34F (-> linea de pantalla V de cada fila
> A579 de profundidad) y construye con PUSH, desde EB00 hacia abajo, 21 pares de palabras
> A579 (borde izquierdo, borde derecho) = X de pantalla de los bordes de cada fila: EAFE/EAFC = fila 0.
> A579 Las X salen de tablas de palabras indexadas por V (pagina+0xFE-2V): E8xx-EAxx segun los bits 0-1
> A579 del byte de tramo EE(A240+0x40+fila) (configuracion de carriles) y ECxx/EBxx-EDxx segun los bits 6-7.
> A579 Con bifurcacion ((A265) <> 0) las filas a partir de (A266) salen de las tablas EAxx/EBxx (@A5EB).
L A5BB Road_RowEdgeEC
L A5DA Road_RowEdgePush
L A5EB Road_BuildRowEdgesFork
L A60A Road_BuildRowEdgesEnd

# ---------------------------------------------------------------- contadores de animacion
L A60E Anim_Tick
> A60E Contadores globales de animacion: (A234) = 0..3 cada frame, (A235) alterna 0/1,
> A60E (A236) = 0..3 cada dos frames.

# ---------------------------------------------------------------- criminal
L A623 tTrafficTemplate
> A623 Plantilla de 20 bytes (estructura Obj) para un coche de trafico nuevo: activo, fila 0x15,
> A623 anchura 0x28, rutina @A8CD, tipo 0x80.
D A623 A636 b
C A637
L A637 Crim_Update
> A637 Comportamiento del coche del criminal (slot 0, Obj_kind = 0xFF; se llama via Obj_hndlo).
> A637 La primera vez ((A22E) = 0) llama a @B4CC: avistamiento ("SIGHTING OF TARGET VEHICLE": reloj a 60, sirena, (A22E) = 1).
> A637 Si el jugador le golpea (Obj_hit > 0) va a @A78A. Si no:
> A637 - si hay un coche de trafico delante en su mismo carril destino, cambia de carril (@A6D8);
> A637 - cerca del jugador (fila < 7) a veces cambia de carril para cerrarle el paso, segun la X del
> A637 jugador (A26C) (temporizador aleatorio con base LevelData+11B);
> A637 - limita el carril a los permitidos por la carretera (@A89C) y desplaza Obj_lat 10 por frame hacia
> A637 la X del carril (@A7E7);
> A637 - velocidad: 0xE6 base + 0x1E por fila de cercania en rafagas aleatorias (base LevelData+11C),
> A637 y mas lento si esta muy cerca (fila < 6).
L A650 Crim_CheckTraffic
L A68F Crim_LaneAI
; A68F operando = 1 mientras se esta desplazando lateralmente hacia el carril destino
L A69B Crim_LaneTimer
L A6D8 Crim_PickLane
L A6F6 Crim_ClampLane
L A711 Crim_SteerToLane
X A714 0 tLaneX-1
L A73E Crim_SetSpeed
; A73E operando = frames que quedan de acelerón (0 = normal)
L A749 Crim_BoostTimer
L A78A Crim_Rammed
> A78A El jugador ha golpeado al criminal (Obj_hit = codigo de @AD51). Espera 4 frames antes de
> A78A admitir otro golpe, inicia un choque del jugador (velocidad tras choque 0xC8, 0xE6 con turbo),
> A78A alarga la frenada (@B32E+1 += 0x28), suma (nivel[+4 si es golpe doble])*10000 puntos (/10 si (8006) <> 0) y
> A78A deja en la pila @B4F0 (una o dos veces) para sumar dano al criminal al retornar.
L A7E4 Crim_RammedSnd
> A7E4 El byte alto del operando (A7E6 = 0x88) hace de indice 0 de la tabla de carriles que sigue.
L A7E7 tLaneX
> A7E7 Tablas por carril (1-4), indexadas desde A7E6: X lateral del carril (Obj_lat),
> A7E7 velocidad del trafico normal (@A7EB) y con el criminal avistado (@A7EF, mas lenta).
D A7E7 A7F2 b
L A7EB tLaneSpeed
L A7EF tLaneSpeedSlow

# ---------------------------------------------------------------- trafico
L A7F3 Traf_Spawn
> A7F3 Genera coches de trafico. No actua si (A230) <> 0 (captura) o (A225) <> 0, ni si no se ha
> A7F3 avanzado ningun tramo este frame ((A254) = 0). Un temporizador (operando de @A803) se decrementa
> A7F3 en (A254) por frame; al agotarse se recarga con LevelData+11A + rnd(0..15) (+0x19 con el criminal
> A7F3 avistado) y se busca un slot libre en los 5 de A19C (maximo 3 coches de trafico activos).
L A803 Traf_SpawnTimer
L A83C Traf_InitSlot
> A83C Inicializa el slot IX con @A623, elige carril aleatorio dentro de los permitidos en la fila
> A83C 0x14, fija lat/velocidad segun el carril (@A7E7) y el tipo de coche (LevelData+112 + rnd par).
X A85F 0 tLaneX-1
L A89C Road_GetLaneRange
> A89C Carriles permitidos en la fila C: segun el byte de tramo EE(A240+0x42+C) devuelve
> A89C B = primer carril y C = ultimo (1..4): 0 -> 1-4, 0xC1 -> 1-4, 0x41 -> 1-3, bit7+bit1 -> 2-4,
> A89C bit7 -> 1-3, bit1 -> 3-4, otro -> 1-2.
L A8C5 Road_GetLaneRangeB
L A8CD Traf_Update
> A8CD Comportamiento de un coche de trafico (Obj_hndlo). Con (A230) o (A225) activos se aleja
> A8CD (velocidad 0x1FF). Mantiene el carril destino dentro de los permitidos y desplaza Obj_lat 5 por
> A8CD frame hasta la X del carril. Si ha chocado con el jugador (Obj_hit <> 0) y no hay choque en curso:
> A8CD desactiva el coche, borra (A13C), choque del jugador (@A4B8, velocidad 0x96) y mensaje de radio (@9945).
X A902 0 tLaneX-1
L A926 Traf_CheckHit

# ---------------------------------------------------------------- objetos sobre la calzada (?)
L A955 Deco_Spawn
> A955 (?) Crea un objeto en la tabla de tramos ED28 (20 entradas de 4 bytes: tipo 1/2, posicion
> A955 lateral 0..255, X de pantalla de 16 bits) cuando (A248) <> 0 y se ha avanzado tramo. La entrada
> A955 nueva va en ED28 (lado y posicion aleatorios). La tabla se desplaza una entrada por tramo en @C0BB.
> A955 Activa los flags automodificados @A97E+1, @C0BB+1 y @A9DE+1. Ejecutado en los replays
> A955 (entrada ya en el titulo; ramas interiores en partida).
L A97E Deco_Project
> A97E (?) Para cada entrada activa de ED28 calcula su X de pantalla interpolando entre los bordes
> A97E izquierdo (E8xx) y derecho (ECxx) de su fila. Si no queda ninguna, apaga los flags.
L A996 Deco_ProjectNext
L A9A7 Deco_ProjectOne
L A9DE Deco_DrawRow
> A9DE (?) Llamada por fila desde el bucle de dibujo @8F5F: dibuja la entrada de ED28 de la fila
> A9DE (sprite de LevelData+10C o +10E segun el tipo, escala segun la fila B) con @929A/@9309.
L A9E2 Deco_DrawPtr
L A9F1 Deco_DrawOne
L AA33 Deco_DrawLeft

# ---------------------------------------------------------------- objeto volador (?)
C AA38
L AA38 Heli_Draw
> AA38 (?) Dibuja el objeto volador (probable helicoptero: 2 fotogramas alternos segun (A234) bit0,
> AA38 sprites de LevelData+108 / +10A, 5 piezas + 1). Se instala como CALL en @8FA4 dentro del bucle de
> AA38 dibujo y solo dibuja en la fila 3. Escala con la fraccion de tramo (A23F).
> AA38 Operandos automodificados: AA5B = Y (de @AAC6), AA77 y AA8D = desplazamientos, AA95 = X (16 bits).
L AA94 Heli_DrawPart
> AA94 Dibuja una pieza: X = (AA95) + desplazamiento con signo de (DE); clipping y salto a
> AA94 @929A/@9309. El operando de LD BC (AA95/AA96) es la X del objeto.
L AAC1 Heli_DrawPartL
L AAC6 Heli_Move
> AAC6 (?) Movimiento del objeto volador mientras (A224) <> 0: baja la Y (operando de @AACB) de 2 en 2
> AAC6 hasta 0x61, oscilacion vertical (+-1 cada 4 frames), y acerca su X (AA95) 8 pixeles por frame al
> AAC6 destino (operando de @AB06), compensando el desplazamiento lateral del jugador (A26C).
L AACB Heli_Y
L AAD7 Heli_BobCnt
L AADF Heli_BobDir
L AAE8 Heli_BobAcc
L AAF6 Heli_PrevPlayerX
L AB06 Heli_TargetX
L AB2F Heli_StoreX
L AB33 Heli_Control
> AB33 (?) Maquina de estados del objeto volador ((A224), lo fija el guion de la carretera en @C013):
> AB33 1 -> sale hacia la izquierda (destino X = -0x38) y pasa a 2; 2 -> al salir de pantalla quita el
> AB33 CALL de @8FA4 y vuelve a 0; 3/4 -> entra (X inicial -0x18, Y 0x85, destino 0x70), voz/sonido
> AB33 (98A9 / 98B3) y pasa a 5 (en vuelo). Instala/quita CALL @AA38 en @8FA4.
N AB4A
N AB64
L AB4A Heli_Leave
L AB51 Heli_Enter
L AB85 Heli_SetTarget
L AB8E Heli_Patch

# ---------------------------------------------------------------- obstaculos
L AB9A Obst_Spawn
> AB9A Crea obstaculos en la calzada al entrar un tramo nuevo por el fondo: lee el codigo
> AB9A EE(A240+0xA0+0x14-(A254)) (0 = nada; >=4 usa el segundo juego de sprites, codigo-3):
> AB9A 1 -> uno en lat 0x32; 2 -> uno en 0xDC; 3 -> varios (0x46/0xB4, 0x50/0xA0, o 0x20/0x56/0x8C).
L ABF2 Obst_SpawnLast
L ABF6 Obst_New
> ABF6 Busca un slot libre en los 6 objetos de A188, lo borra y lo inicializa como obstaculo:
> ABF6 rutina @AC3C, Obj_width/sprite de LevelData+F6 (+E), Obj_lat = B, Obj_row = C (en EXX).
> ABF6 Sin slot libre descarta el retorno (aborta el resto de @AB9A).
L AC08 Obst_Init
L AC3C Obst_Update
> AC3C Comportamiento de un obstaculo. Intacto (Obj_kind = 0): si el jugador lo golpea sale
> AC3C despedido: velocidad = 2*velocidad del jugador (max 0x15E) y secuencia de rebotes de @AD03 segun
> AC3C la velocidad; Obj_kind = 2. Volando: altura de @ACDB, la velocidad decae 1/32 por frame y alterna
> AC3C el espejado; al acabar Obj_kind = 1 (caido, quieto).
L AC92 Obst_Fly
L ACDB tBounceHeight
> ACDB Alturas de rebote del obstaculo: 5 arcos encadenados (10, 10, 8, 6 y 6 valores).
D ACDB AD02 b
L AD03 tBounceSeq
> AD03 Pares (inicio en @ACDB, numero de frames) segun la velocidad del golpe: a mas velocidad mas rebotes.
D AD03 AD0C b

# ---------------------------------------------------------------- tabla de objetos
L AD0D Obj_StepCollide
> AD0D Al avanzar un tramo (desde @C0DE): comprueba la colision de cada objeto visible con el jugador
> AD0D (@AD51) y si hay golpe llama a su rutina de comportamiento. No actua si (A221) <> 0.
> AD0D El criminal solo cuando su distancia alta (Obj_lane) es 0.
L AD4B Obj_StepNext
L AD51 Obj_CheckHitPlayer
> AD51 Colision objeto IX / coche del jugador. Solo si Obj_hit = 0, Obj_xhi = 0 y fila < 3 (< 2 para
> AD51 el criminal); en la fila 1 depende ademas de la fraccion del jugador (A23F). Hay solape si
> AD51 X..X+anchura cubre 0x70..0x90. Deja Obj_hit = base (4 detras, 1 si va por delante) -1/0/+1 segun
> AD51 el lado (X < 0x68 izquierda, X >= 0x78 derecha) y D = 1.
L AD80 Obj_CheckHitX
L AD9A Obj_SetHit
L ADA0 Obj_UpdateAll
> ADA0 Actualiza los 6 objetos de A188 cada frame: mueve, proyecta a pantalla, comprueba colision,
> ADA0 los inserta en la lista de dibujo ordenada E900 ((A222) = numero) y llama a su comportamiento.
L ADBE Obj_Update
> ADBE Un objeto: distancia (row:frac) += velocidad relativa (frac -= spdlo, row += spdhi + acarreo).
> ADBE Trafico/obstaculos: fila >= 0x17 -> se libera. Criminal: Obj_lane hace de parte alta (0..3).
> ADBE Si la fila < 0x14: en la fila 1 comprueba si el jugador lo ha adelantado (se libera; si es trafico
> ADBE suma (A22B) = adelantamientos), y sigue en @AE24.
L ADE5 Obj_CrimDistHi
L ADF0 Obj_CheckFar
L ADF9 Obj_NoUpdate
> ADF9 Este RET es tambien un comportamiento vacio (Obj_hndlo/hi): lo usa la plantilla
> ADF9 @8728 del GAME OVER (destino de @AECE visto en el replay chasehq_secondstage).
L ADFA Obj_SetRow
L AE20 Obj_ClampFrac
L AE24 Obj_Project
> AE24 Proyeccion: Obj_scry = interpolacion de la linea de pantalla entre las filas (tabla E34E+fila)
> AE24 con Obj_frac; X = borde izq + (borde der - borde izq)*Obj_lat/256 con las tablas E8xx/ECxx.
L AE70 Obj_ProjectLeft
L AEAB Obj_SortInsert
> AEAB Inserta el objeto en la lista E900 (entradas de 4 bytes: fila, fraccion, puntero IX),
> AEAB ordenada por distancia, desplazando con LDDR.
L AEC8 Obj_CallHandler
L AECF Obj_DrawRow
> AECF Llamada por fila (B) desde el bucle de dibujo @8F5F: dibuja los objetos de la lista E900 que
> AECF estan en esa fila (el operando apunta a la siguiente entrada pendiente). Escala = (fila-1)/2
> AECF (0..5, guardada en @AFFB+1); Y = scry - height, espejado = Obj_mirror (@93C0+1); dibuja con
> AECF @929A / @9309 segun la X. El criminal (Obj_kind = 0xFF) va por @AF50.
L AEE9 Obj_DrawOne
L AF2F Obj_DrawLeft
L AF38 Obj_DrawRight
L AF3B Obj_DrawNext
L AF50 Obj_DrawCriminal
> AF50 Dibuja el coche del criminal y sus extras (?): una pieza con (A232) < 5 y escala < 4 (tablas CDEC),
> AF50 otra animada con (A236) si (A232) >= 4, y humo segun el nivel de dano (A232) (1..3 columnas animadas, tablas de CDEC).
L AFF1 Crim_DrawSmoke

# ---------------------------------------------------------------- fuente (cola)
> A300 Continuacion de la fuente 8x7 que empieza en A27A (bloque de variables): 41 glifos de 7 bytes
> A300 en el orden ! ( ) , . 0-9 A-Z (indice calculado en @9FB4). Termina en A398.
D A27A A398 b
