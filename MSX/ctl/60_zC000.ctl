# 60_zC000.ctl -- zona C000-CFFF: carretera (relleno por scanline), bifurcacion,
# tunel, montanas, geometria/DDA de bordes y tablas de sprites.
#
# Buffer trasero F000-FFFF: 256x128, 8 filas de caracter de 16 lineas:
#   direccion = (F0 + (y & 15)) * 256 + (y >> 4) * 32 + columna   (columnas 1-30 visibles)
# Tablas por linea de carretera (fuera de zona): paginas E8..ED, una palabra (x de 16 bits,
# con signo) por linea; indice L = 2*y+1 apunta al byte alto, L-1 al bajo. y = 127 en xxFE.
# Tablas por rodaja (slice, 21-22 rodajas de profundidad): E300 (y), E320 (dx), E336 (y
# recortada), E34F (lineas). Anillo de pista EE00-EEFF indexado por (A240 + 0x20*campo).

# ---------------------------------------------------------------- estructura de rodaja
S Slc 0x00 y ; y relativa de la rodaja, y_pant = y+32 (0x60 = linea 128, justo bajo el buffer), tabla E301..
S Slc 0x01 y1 ; y de la rodaja siguiente (mas lejana)
S Slc 0x02 y2 ; y dos rodajas mas alla
S Slc 0x1F dx ; desplazamiento x por rodaja (E320+i), lo calcula @CBDC
S Slc 0x35 yclip ; y recortada por colinas (minimo acumulado, E336+i), la calcula @CD3A
S Slc 0x4E lines ; numero de lineas de la rodaja (>=1, E34F+i), lo escribe @CCB3
I C15B C2E6 iy Slc
I C2E7 C450 iy Slc
I CCA8 CD37 iy Slc

# ---------------------------------------------------------------- C000-C0E0 lector de pista (cola)
> C001 (C000 es el desplazamiento del JR Z de BFFF.) Cola del interprete de la secuencia de
> C001 pista que empieza en la zona B000: comandos de las sub-secuencias y escritura del
> C001 valor actual de cada campo en el anillo EE00 (campos separados 0x20 bytes).
L C02C Trk_SetFieldVal
; C02C fija el valor que @C058 escribe en el anillo
L C031 Trk_CmdNewSub
> C031 Comando 0 (?): lee dos punteros de la secuencia hacia @BB8A+1 y @BBB7+1 y
> C031 continua con la sub-secuencia de E2B8.
L C045 Trk_CmdRestart
; C045 HL lo parchea BBE0 (puntero de reinicio de la sub-secuencia)
L C04A Trk_CmdJump
; C04A salto: HL = (HL)
L C04E Trk_StreamSet
L C050 Trk_StreamSave
L C055 Trk_SetRunLen
L C058 Trk_WriteField
L C059 Trk_smcFieldVal
; C058 escribe el valor del campo en la posicion del anillo (operando parcheado)
L C05C Trk_ObjTimers
> C05C Recorre las 6 entradas de objetos de A188 (0x14 bytes cada una): baja sus
> C05C temporizadores (+1), y cuenta cuantas expiran con bit 7 de +15 -> A22B.
L C0BB Trk_ShiftTbl
L C0BC Trk_smcShiftFlag
; C0BB si el operando (flag puesto en A977/A9A0) <> 0, desplaza 4 bytes hacia arriba la tabla ED4D-ED76 (objetos laterales, ver A97E) (?)
L C0D7 Trk_Advance1
L C0D9 Trk_AdvanceA
; C0D9 A254 += A y sigue en AD0D

# ---------------------------------------------------------------- C0E1 ganchos de tunel
L C0E1 Tun_SetupHooks
> C0E1 Llamada en cada frame de juego (bucle principal). Si no hay tunel (@C161 = 0 y
> C0E1 @C890 = 0) pone NOP NOP NOP en 8F82 y 8FA7 (ganchos del bucle de sprites, que
> C0E1 recorre las rodajas de lejos a cerca) y A23B = 0. Si hay boca de tunel visible
> C0E1 (@C161 <> 0) escribe CALL @C15B en ambos ganchos para que la boca se dibuje en
> C0E1 su profundidad, mezclada con los sprites. Si estamos dentro (@C890 <> 0, @C161 = 0)
> C0E1 busca en E9F3/EAF1.. (lineas cercanas) la rodaja donde los bordes dejan de abrirse
> C0E1 y coloca ahi una boca en modo 2 (salida del tunel) (?). Ejecutado en los replays:
> C0E1 tuneles en los niveles 1, 2, 4 y 5 (docs/img/replay/chq_tunnel.png).
L C100 Tun_FindInside
L C139 Tun_FoundSlice
L C144 Tun_EnableHooks
; C144 operando de @C2B8: 0 si modo 1 (relleno sup. en blanco), 1 si modo 2 (negro)

# ---------------------------------------------------------------- C15B boca del tunel
C C15B
C C223
C C238
L C15B Tun_DrawMouth
> C15B Dibuja la boca del tunel (pared + dintel) cuando IY (rodaja actual del bucle de
> C15B sprites) coincide con la rodaja guardada en @C15E. Modo @C161: 1 = trama EEEE
> C15B (pared en gris), 2 = FFFF (negro). Por cada linea desde la y de la rodaja hacia
> C15B arriba: rellena con PUSH DE a la izquierda del borde E8 y a la derecha del borde
> C15B EB (entradas en las cadenas @C221/@C236), y luego el dintel por encima a ancho
> C15B completo, y el resto hacia arriba con 0000/FFFF segun @C2B9. Altura de la pared
> C15B proporcional a la escala de la rodaja (tabla E6xx). Restaura SP desde @C2E4.
> C15B Ejecutado en los replays (boca del tunel del nivel 1, t=208 s).
L C15E Tun_smcSlice
L C161 Tun_smcMode
L C21D Tun_smcPattern
N C21C
L C21F Tun_WallLine
L C221 Tun_JrLeft
L C222 Tun_smcJrLeft
L C236 Tun_JrRight
L C237 Tun_smcJrRight
L C287 Tun_LintelLine
L C2B9 Tun_smcTopFill
L C2C1 Tun_TopLine
L C2E3 Tun_Exit
L C2E4 Tun_smcSavedSP

# ---------------------------------------------------------------- C2E7 transicion de carriles
L C2E7 Lane_Transition
> C2E7 Llamada desde @C4DF en cada rodaja con (flags & 3) <> 0. Si la rodaja es cercana
> C2E7 (IYL < 0x13) y el byte de flags (IX) tiene bits 2-3 <> 0, regenera por DDA el
> C2E7 tramo de una tabla de borde de carril (pagina EB, o EC si bit 7; o la de @C4C1 si
> C2E7 bit 5 = 0) para que un carril aparezca/desaparezca: interpola desde la x de la tabla
> C2E7 vecina en la linea cercana hasta la x propia 1 o 2 rodajas mas lejos (bit 4 elige
> C2E7 sentido, (IY+1)/(IY+2) la longitud), mas un ajuste por subposicion A23F (?).
> C2E7 Misma tecnica que @CCB3: SP apunta a la tabla y se hace PUSH DE por linea.
> C2E7 Entrada: IX = flags de la rodaja, IY = rodaja, H = pagina, A' guardado. Sale por
> C2E7 @C54D con HL = @C534.
L C345 Lane_AddOfsA
L C346 Lane_smcOfsA
L C351 Lane_LoadPtrA
L C352 Lane_smcPtrA
L C357 Lane_Close2
L C37E Lane_Open
L C3BD Lane_AddOfsB
L C3BE Lane_smcOfsB
L C3C3 Lane_SwapPtr
L C3C4 Lane_LoadPtrB
L C3C5 Lane_smcPtrB
L C3CA Lane_Open2
L C3EE Lane_DDA
> C3EE DDA: HL = x_destino - DE, A = delta (saturado a +-127), C = lineas. Si |delta| <
> C3EE lineas: un paso de +-1 cada cierto numero de lineas (@C435); si no: varios pasos
> C3EE por linea (@C445). Un PUSH DE por linea.
L C426 Lane_DDAShallowP
L C42B Lane_DDAShallow
L C435 Lane_smcStep1
; C435 INC DE (13) o DEC DE (1B) segun el signo, escrito en @C42B
L C439 Lane_Done
L C43B Lane_Exit
L C441 Lane_DDASteep
L C445 Lane_smcStep2
; C445 INC DE / DEC DE escrito en @C441

# ---------------------------------------------------------------- C452 carretera
L C452 Road_Draw
> C452 Dibuja la carretera, la hierba, bordillos, lineas de carril, montanas y cielo en
> C452 el buffer F000, de abajo (y=127) hacia arriba. Una vez por frame.
> C452 Entradas: E301.. y de cada rodaja (de @CD3A), tablas de x por linea E8..ED (de
> C452 BA0B/@CBD6), anillo de flags EE00+(A240+0x40+i), A240 (fase de bandas).
> C452 Por rodaja i (IY = E301+i, IX = flags): elige que tablas son borde izquierdo,
> C452 derecho y separadores (bits 0-1 y 7 de flags), y para cada linea de la rodaja:
> C452  1) relleno de 15 palabras (cols 1-30) con cadenas PUSH auto-modificadas:
> C452     banda clara -> todo 0000 (@C62E); banda oscura -> trama 55/AA alternada por
> C452     linea en la hierba y 0000 en el asfalto (@C60A, tres cadenas: hierba der.,
> C452     asfalto, hierba izq.; x redondeada a 16 pixeles).
> C452  2) bordes finos via capa MSX 33xx (AND/OR/LDI con patrones de E400):
> C452     bordillo izq. (@C63D), lineas de carril (@C667), bordillo der. (@C68A).
> C452 Cada 2 rodajas cambia de banda (trama, fase del bordillo xor 0x20, linea de carril
> C452 xor D0/E0/F0); tras 3 y luego cada 5 rodajas estrecha patrones (@C6D8).
> C452 Al llegar al horizonte (@C79A) dibuja montanas y rellena el cielo (@C887).
> C452 Usa SP como puntero de escritura (guardado en @C8A4). Destruye todo.
> C452 Nota: la primera linea (y=128, DE inicial 0100) cae en 0000-001E (ROM en Spectrum).
N C483
; C483 H = D0 (linea de carril), L = 10 (bordillo); si no hay banda oscura HL = 0030
L C4AD Road_SliceLoop
L C4B2 Road_SetupJp
L C4B3 Road_smcSetupJp
; C4B2 @C534 (configurar tablas por defecto) o @C551 (ya configuradas)
L C4D5 Road_SetRight
L C4E2 Road_FlagTunnel
> C4E2 Flags bit 6 = 1, bit 7 = 0: tunnel. Bits 3/4 = boca en esta rodaja (@C15E = IYL,
> C4E2 @C161 = 1, o 2 si bit 5); @C890 = 1 (o 0 si bit 5) = cielo negro. Borde derecho EB,
> C4E2 sin lineas de carril; banda = C (FF = trama siempre). Ejecutado en los replays.
L C519 Road_FlagFork
> C519 Flags bits 7 y 6 = 1: si bit 5 -> bifurcacion (@C8E3). Si no, sin lineas de
> C519 carril y A248 = 1 si bits 3-4 = 0 (?).
L C534 Road_SetupDefault
> C534 Configuracion por defecto: borde izq. E8, der. EC, 3 separadores E9-EB (4 carriles).
L C54D Road_SetupStore
L C551 Road_SliceStart
> C551 B = 0: banda clara (@C55F), B <> 0: banda oscura (@C5A1, B = trama 55/AA en A').
L C55F Road_LinePlain
L C565 Road_LinePlainGo
L C56C Road_LoadLineP
L C56D Road_smcLineAddrP
L C57C Road_BandRowUp
L C58A Road_PlainRowUp
L C598 Road_SliceBand
L C5A1 Road_LineBand
L C5A7 Road_LineBandGo
L C5AC Road_LoadLaneCnt
L C5AD Road_smcLaneCnt
; C5AC FC/FD/FE = 3/2/1 separadores (INC B hasta 0), FF = ninguno
L C5B3 Road_LeftEdgeX
L C5B4 Road_smcLeftPage
> C5B3 Palabra (0-15) del borde izquierdo: x/16 redondeado; x<0 -> 0, x>=256 -> 15.
L C5D3 Road_LeftDone
L C5D9 Road_RightEdgeX
L C5DA Road_smcRightPage
L C5F0 Road_RightDone
L C5F9 Road_LoadLineB
L C5FA Road_smcLineAddrB
C C60C
L C60A Road_FillChains
L C60B Road_smcJrGrassR
> C60A Tres cadenas de PUSH (SP = linea + 0x1F, escriben hacia la izquierda):
> C60A  15 x PUSH HL (hierba derecha, entra en C60C + xder), 15 x PUSH BC (asfalto = 0),
> C60A  15 x PUSH HL (hierba izquierda). Cada JR salta las PUSH que no tocan.
L C61B Road_JrRoad
L C61C Road_smcJrRoad
L C62C Road_JrGrassL
L C62D Road_smcJrGrassL
L C62E Road_FillPlain
; C62E con HL = 0 y entrando al principio: 15 palabras a 0 (banda clara)
L C63D Road_Edges
> C63D Bordes. En el juego alternativo: H = pagina de la tabla de x, L = linea.
> C63D Bordillo izquierdo: patron E400 + C652 + (x&7)*4 -> @3300 (AND/OR byte 0, byte 1
> C63D opaco). Si el byte alto de x <> 0 (fuera de pantalla) se salta.
L C642 Road_LoadEdgePageL
L C643 Road_smcEdgePageL
L C651 Road_AddKerbPat
L C652 Road_smcKerbPat
; C651 10/30 (bordillo ancho, contorno/solido), 50/70, 90/B0 (mas lejos, mas estrecho)
D C65F C665 b
; C65F restos del codigo Spectrum original (sustituido por JP 3300 en el port MSX)
L C666 Road_EdgeRetL
L C667 Road_LaneLoop
> C667 Lineas de carril en las tablas intermedias (INC H) hasta que B llega a 0.
> C667 Patron de 2 bytes E400 + C678 + (x&7)*2, escritos opacos por @3316.
L C677 Road_AddLinePat
L C678 Road_smcLinePat
; C677 00 = sin linea (hueco), D0/E0/F0 = linea de 3/2/1 pixeles
D C685 C685 b
; C685 resto Spectrum (ver @C65F)
L C686 Road_LaneRet
L C68A Road_EdgeRight
L C68B Road_smcEdgePageR
> C68A Bordillo derecho: patron E400 + C699 + (x&7)*4 (= base izq. + 1) -> @3326
> C68A (byte 0 opaco, AND/OR byte 1).
L C698 Road_AddKerbPatR
L C699 Road_smcKerbPatR
D C6A6 C6A9 b
; C6A6 resto Spectrum (ver @C65F)
L C6AA Road_EdgeRetR
L C6AB Road_NextLine
L C6AD Road_LineLoopJp
L C6AE Road_smcLineLoop
; C6AD vuelve a @C55F o @C5A1 mientras queden lineas en la rodaja (C)
L C6B2 Road_SliceEnd
L C6B3 Road_smcBandPhase
> C6B2 Fin de rodaja. Cada 2 rodajas (fase en C6B3, inicial = bit 0 de A240+0x40)
> C6B2 cambia de banda: trama xor 55, bordillo xor 20, linea de carril xor C6D4.
L C6BC Road_ToggleDither
L C6BD Road_smcDither
L C6C4 Road_TogglePats
L C6D3 Road_XorLinePat
L C6D4 Road_smcLineXor
L C6D8 Road_PerspStep
L C6D9 Road_smcPerspCnt
> C6D8 Contador de rodajas (3 y luego 5): estrecha la linea de carril (C6D4 += 10,
> C6D8 hasta F0) y el bordillo (C652 += 40).
L C703 Road_NextSlice
> C703 Lineas de la siguiente rodaja = y(i) - y(i+1). 0 -> @C715; negativa (oculta tras
> C703 una colina) -> @C746 (se acumula hasta volver a ser visible); terminador A0 -> @C79A.
L C715 Road_EmptySlice
L C746 Road_HiddenSlice
L C774 Road_HiddenNext
L C794 Road_NextVisible

# ---------------------------------------------------------------- C79A montanas y cielo
L C79A Road_Horizon
> C79A Horizonte alcanzado (DE = linea). Si hay tunel (@C890 o @C161 bit 0) salta al
> C79A cielo. Si no, montanas: numero de lineas visibles = min(24, A171 - (127-y)),
> C79A hasta 24 filas del grafico de montanas, dibujadas de abajo arriba desde el
> C79A horizonte. Grafico: 24 filas x 10 bytes ciclicos (80 pixeles) en 5C00 (bloque de
> C79A nivel) o su copia desplazada 4 pixeles en 5B00 (@C8BE), elegida por el bit 0 de
> C79A @C7E8 (scroll 0-19 en pasos de 4 px, lo mueve B879 con las curvas = paralaje).
L C7CA Mnt_Rows
L C7DB Mnt_SrcRow
L C7E7 Mnt_SelectGfx
L C7E8 Mnt_smcScroll
> C7F4 Copia en @C82D 18 bytes de la plantilla 86F6: k x (INC L / NOP) + (9-k) x LDI,
> C7F4 k = scroll/2 (byte de inicio en la fila ciclica); el JR de @C86C salta 9-k LDI.
> C7F4 Total por linea: 30 LDI; LD L,A vuelve al principio de la fila cada 10 bytes.
N C7EA
L C80A Mnt_LoadCount
L C80C Mnt_smcRows
L C813 Mnt_RowUp
L C821 Mnt_LineLoop
L C824 Mnt_LineStep
L C82D Mnt_Prelude
; C82D 18 bytes reescritos en cada frame desde 86F6 (en la imagen: NOP)
L C83F Mnt_LdiChain
L C86C Mnt_JrTail
L C86D Mnt_smcJrTail
L C887 Sky_Fill
> C887 Rellena desde la linea encima del horizonte/montanas hasta y=0 con DE por
> C887 PUSH (0000 cielo blanco; FFFF negro si @C890 <> 0, tunel).
L C88F Road_TunnelFlag
L C890 Road_smcTunnel
L C898 Sky_LineLoop
L C8A3 Road_Exit
L C8A4 Road_smcSavedSP
L C8AB Sky_PushLine

L C8BE Mnt_BuildShifted
> C8BE Al empezar nivel (8807): copia el grafico de montanas 5C00 (0xF0 bytes = 24
> C8BE filas x 10) a 5B00 y lo rota 4 bits (RRD) para tener la version desplazada media
> C8BE celda. El nibble entrante se toma de 5C09 + 24*k cada 24 bytes, no de cada fila (?).
N C8C1

# ---------------------------------------------------------------- C8E3 bifurcacion
L C8E3 Fork_Start
> C8E3 Bifurcacion: copia el estado de bandas/patrones de la rutina normal (C6xx) a sus
> C8E3 copias (CAxx/CBxx) y dibuja el resto de rodajas con dos carreteras:
> C8E3 carretera 1 = E8 (bordillo izq.) / E9 (linea) / EA (bordillo der.),
> C8E3 carretera 2 = EB / EC / ED. Cinco cadenas PUSH (@CA11): hierba | asfalto 2 |
> C8E3 hierba entre ambas | asfalto 1 | hierba. Bordes via 3339/334F/335F/3372/3388/3398.
> C8E3 Termina igual que la normal en @C79A.
L C915 Fork_SliceStart
L C923 Fork_LinePlain
L C929 Fork_LinePlainGo
L C92E Fork_LoadLineP
L C92F Fork_smcLineAddrP
L C93E Fork_BandRowUp
L C94C Fork_PlainRowUp
L C95A Fork_SliceBand
L C963 Fork_LineBand
L C969 Fork_LineBandGo
L CA00 Fork_LoadLineB
L CA01 Fork_smcLineAddrB
C CA13
C CA24
C CA35
C CA46
L CA11 Fork_FillChains
L CA12 Fork_smcJr1
L CA22 Fork_Jr2
L CA23 Fork_smcJr2
L CA33 Fork_Jr3
L CA34 Fork_smcJr3
L CA44 Fork_Jr4
L CA45 Fork_smcJr4
L CA55 Fork_Jr5
L CA56 Fork_smcJr5
L CA57 Fork_FillPlain
L CA7A Fork_AddKerbPat1
L CA7B Fork_smcKerbPat1
D CA88 CA8E b
; CA88 resto Spectrum (ver @C65F)
L CA8F Fork_EdgeRet1
L CA9D Fork_AddLinePat1
L CA9E Fork_smcLinePat1
D CAAB CAAB b
L CAAC Fork_EdgeRet2
L CABB Fork_AddKerbPatR1
L CABC Fork_smcKerbPatR1
D CAC9 CACC b
L CACD Fork_EdgeRet3
L CADC Fork_AddKerbPat2
L CADD Fork_smcKerbPat2
D CAEA CAF0 b
L CAF1 Fork_EdgeRet4
L CAFF Fork_AddLinePat2
L CB00 Fork_smcLinePat2
D CB0D CB0D b
L CB0E Fork_EdgeRet5
L CB1C Fork_AddKerbPatR2
L CB1D Fork_smcKerbPatR2
D CB2A CB2D b
L CB2E Fork_EdgeRet6
L CB2F Fork_NextLine
L CB31 Fork_LineLoopJp
L CB32 Fork_smcLineLoop
L CB36 Fork_SliceEnd
L CB37 Fork_smcBandPhase
L CB40 Fork_ToggleDither
L CB41 Fork_smcDither
L CB5D Fork_XorLinePat
L CB5E Fork_smcLineXor
L CB65 Fork_PerspStep
L CB66 Fork_smcPerspCnt
L CB90 Fork_NextSlice
C CBA4
L CBA4 Fork_DeadHidden
> CBA4 Codigo muerto (sin referencias): equivalente de @C774 para la bifurcacion.
L CBC5 Fork_NextVisible

# ---------------------------------------------------------------- CBCE geometria de bordes
L CBCE Geo_RoadXFork
> CBCE Como @CBD6 pero para la segunda carretera de la bifurcacion: curva espejada
> CBCE (NEG en @CC21) y escribe las tablas ED (borde derecho) y EB (izquierdo).
X CBD1 0 #44ED
; CBD1 bytes ED 44 = NEG, se escriben en @CC21
L CBD6 Geo_RoadX
> CBD6 Calcula las tablas de x por linea de los bordes de la carretera (llamada desde
> CBD6 BA0B, que luego interpola E9/EA/EB = 1/4, 1/2, 3/4 entre E8 y EC).
> CBD6 1) Por rodaja (22): punto de fuga lateral T = palabra de E500 indexada por
> CBD6    0x80 - curva(pos)*f/8 + suma de curvas EE00+pos+i; x avanza hacia T con el
> CBD6    factor de escala E6B0+22*f (x += (T-x)*k/64 aprox.); el incremento se guarda
> CBD6    en E320+i (dx). f = subposicion A23F>>5, x inicial = A26C.
> CBD6 2) DDA @CCA8 con x0 = A26C -> tabla EC (borde derecho).
> CBD6 3) dx += anchura E760+22*f (estrechamiento) y DDA con x0 = A26C-0x127 -> tabla E8.
L CBDC Geo_RoadXCommon
L CC20 Geo_CurveLoop
L CC21 Geo_smcNeg
; CC21 NOP NOP (carretera normal) o NEG (espejo, bifurcacion)
L CC70 Geo_DDARight
L CC72 Geo_smcPage1
; CC70 SP inicial = pagina+1 (ED00 -> tabla EC, o EE00 -> tabla ED)
L CC8E Geo_AddWidth
N CC9D
; CC9D -0x127: anchura de la carretera en la linea 127
L CCA5 Geo_DDALeft
L CCA7 Geo_smcPage2
; CCA5 E900 -> tabla E8, o EC00 -> tabla EB
L CCA8 Geo_DDA
> CCA8 DDA de escalado: genera x(y) para cada linea entre rodajas.
> CCA8 Entradas: HL = fin de la tabla destino (SP), juego alternativo: DE = x inicial
> CCA8 (16 bits), B = deuda de lineas (0). IY = E300, rodajas Slc_y (E301..) y Slc_dx.
> CCA8 Por rodaja: n = y(i)-y(i+1)+deuda; Slc_lines = max(n,1); reparte dx en n lineas
> CCA8 (Bresenham: @CCE8 si |dx|<n, @CCF8 si no) haciendo PUSH DE por linea, de abajo
> CCA8 arriba. Rodajas de 0 o menos lineas (ocultas): un PUSH con x+dx y la deuda pasa a
> CCA8 la siguiente (@CD0C). 21 rodajas.
L CCB3 Geo_DDASlice
L CCDE Geo_DDAPos
L CCE3 Geo_DDAShallowSet
L CCE8 Geo_DDAShallow
L CCED Geo_smcStep1
; CCED INC DE / DEC DE escrito en @CCE3
L CCEE Geo_DDAPush
L CCF4 Geo_DDAExit
L CCF5 Geo_smcSavedSP
L CCF8 Geo_DDASteep
L CCFC Geo_smcStep2
; CCFC INC DE / DEC DE escrito en @CCF8
L CD0C Geo_DDAShort
L CD27 Geo_DDAOne

L CD3A Geo_SliceY
> CD3A Calcula la y de cada rodaja con colinas: y(i) = yplana(i) + yplana(i)*2*h/256
> CD3A (aprox.), con yplana = E600+22*f+1 (f = A23F>>5) y h = suma acumulada de la
> CD3A pendiente del anillo EE00+A240+0x20+i menos interp(pendiente actual, f).
> CD3A Escribe E301..E315, E316 = A0 (terminador), E336.. = minimo acumulado (empieza en
> CD3A 0x60, recorte por cresta), E34B = horizonte redondeado a 8, E34C = su variacion.
L CD69 Geo_SliceYLoop
L CDAA Geo_SliceYStore
L CDC0 Geo_ClipLoop
L CDD6 Geo_InterpFrac
> CDD6 A = round(C * (A>>5) / 8) con signo: interpola un valor C del anillo por la
> CDD6 subposicion f (bits 7-5 de A). Destruye B, E.

# ---------------------------------------------------------------- CDEC-CFFF tablas (sprites)
L CDEC tSmokeOfs4
> CDEC Tablas del humo del coche danado (A232 = 1..3 columnas animadas) usadas por AF81-AFFF
> CDEC (ejecutado en los replays tras golpear al criminal): pares (dy,dx), punteros a graficos E0B2-E184 (?).
D CDEC CDF3 b
L CDF4 tSmokeGfxPtr
D CDF4 CDFF a
L CE00 tSmokeOfs6
D CE00 CE0B b
L CE0C tSmokeAnim1
> CE0C Registros de 13 bytes: contador (5..0) + 6 pares (dy,dx) (?).
D CE0C CE18 b
L CE19 tSmokeAnim2
D CE19 CE25 b
L CE26 tSmokeAnim3
D CE26 CE32 b
L CE33 tSmokePathPtrs
D CE33 CE4A a
L CE4B tSmokePaths
> CE4B 5 registros de 19 bytes (contador + 9 pares) apuntados desde @CE33 (?).
D CE4B CE5D b
D CE5E CE70 b
D CE71 CE83 b
D CE84 CE96 b
D CE97 CEA9 b
L CEAA tCarGfx12
> CEAA 4 registros de 12 bytes indexados desde B578 (fase & 3) (?).
D CEAA CEB5 b
D CEB6 CEC1 b
D CEC2 CECD b
D CECE CED9 b
L CEDA tCarFrames
> CEDA 9 cuadros de 20 bytes (B5B7): 5 piezas de 4 bytes (dy, altura, puntero a grafico).
D CEDA CEDD b
D CEDE CEE1 b
D CEE2 CEE5 b
D CEE6 CEE9 b
D CEEA CEED b
D CEEE CEF1 b
D CEF2 CEF5 b
D CEF6 CEF9 b
D CEFA CEFD b
D CEFE CF01 b
D CF02 CF05 b
D CF06 CF09 b
D CF0A CF0D b
D CF0E CF11 b
D CF12 CF15 b
D CF16 CF19 b
D CF1A CF1D b
D CF1E CF21 b
D CF22 CF25 b
D CF26 CF29 b
D CF2A CF2D b
D CF2E CF31 b
D CF32 CF35 b
D CF36 CF39 b
D CF3A CF3D b
D CF3E CF41 b
D CF42 CF45 b
D CF46 CF49 b
D CF4A CF4D b
D CF4E CF51 b
D CF52 CF55 b
D CF56 CF59 b
D CF5A CF5D b
D CF5E CF61 b
D CF62 CF65 b
D CF66 CF69 b
D CF6A CF6D b
D CF6E CF71 b
D CF72 CF75 b
D CF76 CF79 b
D CF7A CF7D b
D CF7E CF81 b
D CF82 CF85 b
D CF86 CF89 b
D CF8A CF8D b
L CF8E tCarFramesB
D CF8E CF91 b
D CF92 CF95 b
D CF96 CF99 b
L CF9A tSprParts6
> CF9A 4 entradas de 6 bytes (B64F): C, B, D, E, puntero.
D CF9A CF9F b
D CFA0 CFA5 b
D CFA6 CFAB b
D CFAC CFB1 b
L CFB2 tSprOfs3
> CFB2 26 entradas de 3 bytes (B6A6): dy (+79), dx, indice en la tabla D027.
D CFB2 CFB4 b
D CFB5 CFB7 b
D CFB8 CFBA b
D CFBB CFBD b
D CFBE CFC0 b
D CFC1 CFC3 b
D CFC4 CFC6 b
D CFC7 CFC9 b
D CFCA CFCC b
D CFCD CFCF b
D CFD0 CFD2 b
D CFD3 CFD5 b
D CFD6 CFD8 b
D CFD9 CFDB b
D CFDC CFDE b
D CFDF CFE1 b
D CFE2 CFE4 b
D CFE5 CFE7 b
D CFE8 CFEA b
D CFEB CFED b
D CFEE CFF0 b
D CFF1 CFF3 b
D CFF4 CFF6 b
D CFF7 CFF9 b
D CFFA CFFC b
D CFFD CFFF b
