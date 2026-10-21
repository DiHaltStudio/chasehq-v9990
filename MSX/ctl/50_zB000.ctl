# 50_zB000.ctl -- zona B000-BFFF
# Coche del jugador (fisica, salto, dibujo por piezas), rutinas de sprite
# enmascarado (normal / espejado / volteado vertical), interprete de pista
# (anillo de segmentos en EE00), geometria de carretera por scanline y copia
# del buffer trasero F000 -> pantalla 4000.

# ---------------------------------------------------------------- cola de rutina de AFF1
L B01B Obj_DrawLinkedIdx
> B01B (?) Final de la rutina @AFF1 (zona A000): dibuja un sprite secundario
> B01B ligado al objeto actual (humo / danos del coche perseguido).
> B01B Entrada B01B: HL = base, DE = indice (HL += DE). Entrada B01C: HL = descriptor.
> B01B B = desplazamiento Y, C = desplazamiento X. Lee la posicion del objeto de
> B01B los operandos automodificados de @B023/@B029/@B02C y salta al dibujador
> B01B escalado (@929A / @9309). Ejecutado desde el primer golpe al criminal (humo, replay t=269,8 s).
L B01C Obj_DrawLinked
; B01D nibbles de (HL) intercambiados (rlc x3 = rota 3 bits)

# ---------------------------------------------------------------- tablas de salto
L B045 Car_JumpCurve
> B045 Curva del "salto" del coche al pasar un cambio de rasante: 10 pares
> B045 (fotograma de cabeceo -> @B5AF+1, incremento de altura -> @B5AA+1).
> B045 Subida +13,+10,+7,+4,+2 y bajada -2,-4,-7,-10,-13 (simetrica).
D B045 B058 b
L B059 Car_JumpIndex
> B059 Indice de saltos por intensidad k=1..5 (se accede como B057+2k):
> B059 (desplazamiento en @B045, numero de pasos). k=1 bote pequeno (2 pasos)
> B059 ... k=5 salto completo (10 pasos).
D B059 B062 b

# ---------------------------------------------------------------- fisica del jugador
L B063 Car_Update
> B063 Fisica del coche del jugador, una vez por frame de juego (bucle @8444).
> B063 1) Salto: el operando de B063 es el contador de pasos que quedan; @B079+1
> B063    apunta al par actual de @B045. Mientras dura, se anula @A23E (terreno) y
> B063    los bits de direccion de la entrada (A0D5 &= F0). Al acabar: sonido 3
> B063    (@A24F=3, @88F2 con BC=0203, aterrizaje).
> B063 2) Temporizadores: @A24E (turbo?) al llegar a 0 decrementa @A170; @A24F--.
> B063 3) Entrada A0D5 (bits tipo Kempston: 0 der, 1 izq, 2 abajo=freno,
> B063    3 arriba=acelerar, 4 disparo=cambio de marcha). Si @B325 (trompo)
> B063    activo solo queda el bit 4. Disparo con antirrebote @A252 alterna la
> B063    marcha @A253 (0 baja / 1 alta) y pide sonido 4.
> B063 4) Velocidad @A24A (0..1FF): aceleracion segun marcha y velocidad,
> B063    freno -20, sin pedal -10; fuera de carretera (@A23E) frena hasta 78h/6Eh;
> B063    pendiente (@B5AF+1) la modifica cada 3 frames (@A24C). Aviso de velocidad
> B063    baja cada 100 frames (@A16E) con mensaje @9945.
> B063 5) Direccion: velocidades de giro @A263 (der) / @A264 (izq), +4 hasta 24h,
> B063    decaen 9 por frame, limitadas a ~3/16 de la velocidad.
> B063 6) Deriva por curva (@A25C, tabla @B828) -> @A262/@A261, @A25F.
> B063 7) Posicion lateral @A26C += (@A264-@A263)/2 + deriva. Salidas: @A250 giro
> B063    (0..2), @A251 sentido (1 = espejar sprites), @A24D derrape.
L B079 Car_JumpNext
; B079 puntero al siguiente par de @B045 (automodificado)
; B089 fotograma de cabeceo durante el salto
; B090 altura del coche += incremento
; B0BF bit 4 = disparo (cambio de marcha)
; B0E4 velocidad < 78h: aviso periodico
L B12D Car_Accel
> B12D Aceleracion segun marcha (@A253) y turbo (@A24E): BC = incremento (positivo)
> B12D o negativo si se supera la velocidad maxima de esa marcha.
L B19A Car_ApplyPedals
; B19A A = bits de entrada guardados
; B19F bit 2: freno
; B1A6 bit 3: acelerador; sin el, BC = -10
; B1B7 cada 3 frames la pendiente afecta a la velocidad
; B1E7 limite 1FFh
L B1F2 Car_Steer
; B1F2 H = bits de entrada
; B202 bit 0: derecha
; B206 bit 1: izquierda
L B23C Car_SteerClamp
; B23C limite de giro = velocidad*3/16
L B253 Car_CurveDrift
; B258 @A25C = curva del segmento actual
; B265 tabla 255/n
L B29A Car_ApplyLateral
; B2A1 consume la deriva @A25F
; B2E8 @A26C = posicion lateral del coche
; B2FA @A250 = 0/1/2 segun |giro|
; B30A @A251 = sentido del giro (espejado)

L B318 Car_UpdateDraw
> B318 Segunda parte del jugador (llamada al final del frame, tras los objetos,
> B318 para que el coche quede encima):
> B318 - Trompo/choque (@B325 != 0): frena hasta @B32E+1, empuje lateral decreciente
> B318   (@B356+1, se resta 1/16 por frame) en el sentido @B36E+1, efecto temporal
> B318   @B384/@B38D -> @B3DB+1. Estos operandos los escribe la zona A4xx.
> B318 - Limita @A26C a [@B395+1, @B3A3+1] (48h..1D8h por defecto, automodificables).
> B318 - Sonido de derrape (@88F2 BC=0105) si @A24D o @A24F.
> B318 - Dibuja: chispas de golpe (@B549), sprite de efecto @B3DB, brazo con la
> B318   sirena (@B457), el coche (@B58E), sirena en el techo (@B67C si @A228) y nubes de polvo a
> B318   ambos lados (@B648 dos veces) si derrapa, @A252/@A253 o @A23E=2.
L B325 Car_SpinState
L B32E Car_SpinSpeed
L B356 Car_KnockVel
L B36E Car_KnockDir
L B384 Car_FxTimer
L B38D Car_FxValue
L B392 Car_ClampX
L B395 Car_MinX
L B3A3 Car_MaxX
L B3DB Car_FxSprite
; B3DB indice de sprite de efecto (0 = nada); sprite = 3*n+18h (+giro)

L B457 Car_SirenFx
> B457 Sprite del brazo que pone la sirena en el techo, segun vSirenState (@A22F):
> B457 0 nada; 1 animacion de colocarla (@B476: 7 pasos con retardo @B478+1 entre
> B457 pasos), que activa vSirenOn (@A228) y al acabar vuelve a 0; 2 (durante la
> B457 captura) sprite fijo 24h, o 25h+sentido si el coche gira.
> B457 Comprobado con el replay chasehq_firststage.omr: solo se ejecuta tras
> B457 @B4CC (avistamiento, t=266,9 s; captura docs/img/replay/chq_turbo.png); la
> B457 animacion dura ~1,5 s y nunca se ejecuta al usar el turbo (t=205 s).
L B476 Car_SirenRaise
L B478 Car_SirenDelay

L B4CC Crim_Sighted
> B4CC Avistamiento del coche del criminal (primera vez que es visible, desde @A637
> B4CC con CALL Z): mensaje @8CB2 "SIGHTING OF TARGET VEHICLE" (@8E7E), reloj a 60
> B4CC (@A17D), sirena (@A22F=1, @B476/@B478) y @A22E=1. Sigue en @83B5 (gancho de sonido).
L B4F0 Crim_Hit
> B4F0 (?) Golpe al coche perseguido. A7B1 hace PUSH de esta direccion como
> B4F0 retorno. Elige uno de 4 juegos de chispas (tabla CE33+6n -> @B55B+1),
> B4F0 arranca la animacion @B549 (9 frames), incrementa el contador de golpes
> B4F0 @A233 (13h -> mensaje @9945; 14h -> @8C3A, coche detenido) y calcula el
> B4F0 nivel de dano @A232 (0..6; umbrales 1,4,7,0Bh,0Eh,11h).
L B549 Crim_HitSparks
> B549 Animacion de chispas: el operando es el contador de frames (9..0). Dibuja 3
> B549 sprites desde una lista de 3 punteros (@B55B+1); cada uno apunta a
> B549 [fase][y][x] y la fase (0..3) selecciona el grafico en CEAA+12*fase.
L B55B Crim_HitSparkList
L B570 Crim_HitSparkStep

# ---------------------------------------------------------------- dibujo del coche
L B58E Car_DrawBody
> B58E Dibuja el coche del jugador. Entrada: A = giro (@A250 0..2), B = extra de
> B58E fotograma (3 = traqueteo fuera de carretera).
> B58E 1) Sombra/base: tabla CF8E + 4*giro, ancho 7 bytes, en X=60h, Y=78h.
> B58E 2) Fotograma = (giro + B + @B5AF+1) mod 9 -> entrada de 20 bytes en CEDA:
> B58E    5 piezas de 4 bytes [dy][alto][puntero]. La primera es la carroceria SIN
> B58E    mascara (5 bytes de ancho, columna 13 fija, @949C o espejada @9542); las
> B58E    otras 4 son enmascaradas via @B627: 2 de ancho 5 en X=68h y 2 de ancho 1
> B58E    en X=60h y X=90h (se intercambian si @A251=1, espejado).
> B58E Y base = 75h - @B5AA+1 (altura del salto) - @A22A (vibracion).
L B5AA Car_BounceY
; B5AA operando: altura del coche (salto)
L B5AF Car_PitchFrame
; B5AF operando: cabeceo 0 llano / 3 / 6 (pendiente) o del salto
; B5CD Y -> direccion del buffer: H=F0+(y&15), L=(y&70h)*2+columna
L B627 Spr_DrawPart
> B627 Dibuja una pieza descrita por 4 bytes en (HL): [dy][alto][puntero sprite].
> B627 Entrada: D = Y de la linea inferior, E = X en pixeles, C = ancho en bytes.
> B627 Espejado segun @A251. Devuelve HL apuntando a la entrada siguiente, DE intacto.
L B648 Car_DrawSidePuff
> B648 Nube de polvo/humo a un lado del coche. A = indice en tabla CF9A (6 bytes:
> B648 [ancho][alto][x sin espejo][x espejado][puntero]); A' = espejado. X = x+7Fh,
> B648 Y = 77h. No dibuja durante un salto (@B063+1 != 0).
L B67C Car_DrawSiren
> B67C Sirena ya colocada en el techo (si vSirenOn, @A228), con parpadeo por vAnim4b.
> B67C Entrada: A = fotograma base, B/C = ajuste por giro. Se ve en chq_catch.png.
L B699 Car_DrawFxNoMirror
L B69E Car_DrawFx
> B69E Dibuja un sprite de efecto relativo al coche. A = indice en tabla CFB2
> B69E (3 bytes: [dy][dx][indice en D027]); D027+n = [alto][ancho][puntero].
> B69E Y = dy+79h - altura salto (@B5AA) + cabeceo, X = dx+80h. Espejado en
> B69E registros alternativos (B' = flag, C' = ancho-1 si espejado).

# ---------------------------------------------------------------- sprites enmascarados
L B6D6 Spr_DrawShake
; B6D6 Y -= @A22A (vibracion de la pantalla)
L B6DD Spr_DrawMasked
> B6DD Sprite enmascarado sin escalado, alineado a byte (X se redondea a 8 px).
> B6DD Entrada: E = X (pixeles), D = Y de la linea INFERIOR (0..127),
> B6DD   HL = datos del sprite, B = alto (lineas), C = ancho (bytes, 1..8);
> B6DD   alternativos: E' = ancho, B' bit0 = espejado, C' = ancho-1 si espejado.
> B6DD Formato: filas de abajo arriba; cada fila = ancho pares [mascara][dato]:
> B6DD   pantalla = (pantalla AND mascara) OR dato. Paso de fila = 2*ancho.
> B6DD Buffer F000: direccion = F000 + (y&15)*256 + (y>>4)*32 + columna.
> B6DD Sin recorte: el llamador garantiza que cabe. Si se sube por encima de la
> B6DD linea 0 se escribiria en EFxx (tabla de espejo).
; B6E9 H = F0 + (y & 15)
; B6ED L = (y & 70h)*2 + columna
; B6F3 E = 2*ancho = paso de fila en el origen
; B6F9 C = espejado
; B6FC destino += C' (columna derecha si espejado)
L B701 Spr_MaskedRows
> B701 Entrada con HL' = destino. IX = @B729 + 6*(8-ancho): se entra en la
> B701 cadena desenrollada de 8 bloques de 6 bytes y se ejecutan "ancho" bloques.
> B701 B' = 0Fh (mascara de linea dentro del bloque de 16), DE = paso de fila.
L B716 Spr_MaskedLoop
; B716 guarda SP: el sprite se lee con POP DE
L B71C Spr_MaskedNextRow
; B71D B = lineas restantes
L B71F Spr_MaskedExit
L B724 Spr_MaskedRow
; B726 C' = columna inicial
L B729 Spr_MaskedChain
; B729 E = mascara, D = dato
; B758 linea siguiente hacia ARRIBA: H-1 dentro del bloque de 16 lineas
; B75F linea 0 del bloque: L -= 32 y H = linea 15 del bloque anterior
L B76C Spr_MirrorAdj
; B76C entrada desde @93D9: HL' += A (columna derecha)
L B770 Spr_DrawMirror
> B770 Variante espejada horizontalmente. DE' = destino (columna derecha, se
> B770 avanza con DEC E). IX = @B79C + 8*(8-ancho), bloques de 8 bytes:
> B770 POP BC (C = mascara, B = dato); L=C: AND (HL); L=B: OR (HL) con H=EFh:
> B770 EF00-EFFF es la tabla de inversion de bits (EF00+n = n con bits invertidos).
> B770 A' guarda la columna inicial de la fila.
L B78B Spr_MirrorNextRowA
L B78D Spr_MirrorNextRow
L B791 Spr_MirrorExit
L B796 Spr_MirrorRow
L B79C Spr_MaskMirrorChain
> B79C Cadena desenrollada del espejado (8 bloques de 8 bytes).
; B7DB linea siguiente hacia arriba (igual que @B758)
L B7EF Spr_DrawVFlip
> B7EF (?) Variante volteada verticalmente (desde @93CA): igual que @B701 pero
> B7EF empieza en la ultima fila del origen (HL += (alto-1)*2*ancho por
> B7EF multiplicacion de 5 bits) y usa paso negativo DE = -2*ancho. Solo se ha visto en
> B7EF la secuencia de GAME OVER (replay chasehq_secondstage, t=874,3 s; captura
> B7EF docs/img/replay/chq2_vflip.png): probablemente el cartel "GAME OVER" o su reflejo (?).
L B825 Spr_VFlipJump
X B265 0 Car_RateTab-1
X B898 0 Car_RateTab-1

L B828 Car_RateTab
> B828 Tabla compartida:
> B828 - B828..B82F se accede como (B827+n), n=1..8: 255/n (FF,7F,55,3F,33,2A,24,1F),
> B828   tamano del paso de distancia para repartir curva (@A25C) y pendiente (@A258)
> B828   a lo largo del segmento.
> B828 - indice 4*|curva| + 2*(velocidad>>7), |curva| en {2,4,6}: pares
> B828   [recarga del temporizador @A25E][paso] del scroll de montanas.
D B828 B847 b

# ---------------------------------------------------------------- curva / pendiente
L B848 Road_CurveScroll
> B848 Por frame (si velocidad != 0):
> B848 - Curva @A25C: cada @A25E frames desplaza el scroll horizontal del fondo
> B848   (operando @C7E7+1, modulo 20) en +-paso (tabla @B828).
> B848 - Pendiente @A258: reparte la pendiente en pasos de 255/|@A258| de la
> B848   distancia @A23F (acumulado en @A25A/@A25B) y mueve la palabra @A171 (altura
> B848   del horizonte?) en +-1 por paso.
L B8D2 Road_NewSegment
> B8D2 Llamada desde @C05F al entrar en un segmento nuevo:
> B8D2 - Termina de aplicar la pendiente pendiente a @A171.
> B8D2 - @A258 = pendiente (campo 1) del segmento +2, /2 redondeado.
> B8D2 - Cabeceo del coche @B5AF+1 = 0 (|p|<3), 6 (p>0), 3 (p<0) con p = campo 1
> B8D2   del segmento actual.
> B8D2 - Cambio de rasante: si la pendiente anterior @A259 era negativa y la nueva
> B8D2   no, y la intensidad supera un umbral que baja con la velocidad, arranca
> B8D2   un salto (@B063+1 y @B079+1 desde @B059).
> B8D2 - @A25C = curva (campo 0), negada si se ha tomado el otro ramal de un
> B8D2   desvio (@A265 y @A269 y @A249). @A25D = 4*|curva|, @A25E temporizador.
> B8D2 - Fuerza centrifuga: @A25F = (|curva|-@A262)*4.5 con signo.
; B8F6 campo 1 (pendiente) del segmento actual+2
; B905 / B906 no es dato: la xref de E0EB es falsa

# ---------------------------------------------------------------- geometria de carretera
L B9F4 Road_Geometry
> B9F4 Calcula los bordes de la carretera por scanline. Busca en el campo 2
> B9F4 (EE40+i, 22 segmentos por delante) un marcador de desvio (bits E1h todos a 1).
> B9F4 Si lo hay -> @BA51 (dos carreteras). Si no, sigue en @BA0B.
L BA01 Road_FindFork
L BA0B Road_GeomNormal
> BA0B Carretera simple. @CBD6 (zona C000) rellena E800 (borde izquierdo) y
> BA0B EC00 (borde derecho) en perspectiva. Aqui, para cada linea con indice
> BA0B a = 30h,32h..FEh (linea y = a/2 = 24..127, palabras con signo, X en pixeles):
> BA0B   L = (E800+a), R = (EC00+a) (leido con POP, SP = EC30)
> BA0B   EA00+a = (L+R)/2                centro
> BA0B   EB00+a = centro + (R-L)/4       linea de carril derecha
> BA0B   E900+a = centro - (R-L)/4       linea de carril izquierda
> BA0B Los cuatro operandos bajos se automodifican en cada iteracion (A = indice).
L BA17 Road_GeomLoop
L BA20 Road_GeomLine
L BA27 Road_GeomLeft
L BA35 Road_GeomStoreC
L BA3F Road_GeomStoreR
; BA44 E900+a (operando bajo en BA45)
; BA4A sale cuando A pasa por 0 (104 lineas)
L BA4D Road_GeomExit
L BA51 Road_ForkGeom
> BA51 (?) Tramo con desvio: guarda el segmento (@A266), activa @A265, decide el
> BA51 ramal (@A269/@A249 segun la posicion lateral @A26C y el lado del desvio,
> BA51 mensaje @9945), calcula la separacion (@A267, @A16D) y llama a @CBD6 y @CBCE
> BA51 (curva negada) con @A26C desplazado, para dos carreteras. Despues, durante
> BA51 B lineas (desde la linea 30h/2):
> BA51   EA = (E8+EC)/2, E9 = (EA+E8)/2, EB = (EB+ED)/2, EC = (EB+ED)/2 (con EB ya
> BA51   nuevo), es decir: centro/carril de la carretera 1 y de la 2 (ED = borde
> BA51   derecho de la 2). El resto de lineas sigue con el bucle normal @BA17.
L BB0C Road_ForkLines
L BB1B Road_ForkLoop
L BB2D Road_ForkLeft
L BB37 Road_ForkStoreA
L BB3F Road_ForkStoreB
L BB42 Road_ForkRight2
L BB46 Road_ForkLoadB
L BB4E Road_ForkStoreC
L BB56 Road_ForkStoreD

# ---------------------------------------------------------------- desvios
L BB69 Road_ForkResolve
> BB69 Si @A268 != 0 (desvio resuelto): segun el ramal (@A249) carga las
> BB69 "direcciones de continuacion" que dejaron los flujos de pista (operandos
> BB69 BB8B..BB9B para un ramal, BBB8..BBC8 para el otro) en los operandos de
> BB69 retorno de @BDFB (BE6D, BEBF, BF0A, BFCD, BF84, C046), apunta los 6 flujos a
> BB69 secuencias fijas cortas en E2D2..E2F3 y rellena 32 segmentos del anillo:
> BB69 campo 0 (curva) = FCh o 04h, campo 2 = 01h o 03h, campo 4 o 3 = 0.
> BB69 Pone a 0 los contadores RLE @A242..@A247 y @A249/@A265/@A269; A151(?)=1, @A16D=1.
L BB8A Road_ContA0
L BB8D Road_ContA1
L BB90 Road_ContA2
L BB94 Road_ContA3
L BB97 Road_ContA4
L BB9A Road_ContA5
L BBA1 Road_ForkResolveB
L BBB7 Road_ContB0
L BBBA Road_ContB1
L BBBD Road_ContB2
L BBC1 Road_ContB3
L BBC4 Road_ContB4
L BBC7 Road_ContB5
L BBCC Road_ForkResolveCommon
N BB74
N BBA1

# ---------------------------------------------------------------- copia del buffer
L BC3E Scr_CopyBuffer
> BC3E Copia el buffer trasero F000 (256x128, 1 bpp) a la pantalla Spectrum
> BC3E 4000, filas de caracter 8..23, columnas 1..30 (las columnas 0 y 31 del
> BC3E buffer no se copian: margen para sprites). Llamada desde la capa MSX
> BC3E (@3534/@353E) antes del volcado al TMS. Necesita interrupciones
> BC3E deshabilitadas: usa SP como puntero de lectura y escritura.
> BC3E HL = origen, HL' = destino. Por linea: 16 bytes (cols 1-16) con
> BC3E POP AF',DE',BC',AF,DE,BC,IX,IY y PUSH en orden inverso al destino +17;
> BC3E luego 14 bytes (cols 17-30) sin IY. Un bloque de 16 lineas del buffer
> BC3E (F0xx..FFxx) son 2 filas de caracter de pantalla (H del destino +1 por linea).
> BC3E Al terminar sigue en @BD5A.
N BCBE
N BCC3
N BD3D
N BD4E
L BC49 Scr_CopyLeft
; BCB9 8 lineas (H origen F0..F7 o F8..FF)
; BCBE origen: H-8, L+16 (mitad derecha); destino al final de la mitad derecha
L BCC8 Scr_CopyRight
; BD2D bit 3: falta la segunda fila de caracter del bloque
; BD31 siguiente bloque de 16 lineas: L += 20h
; BD39 overflow: cambio de tercio de pantalla
L BD45 Scr_CopyNextThird
L BD4D Scr_CopySecondRow
L BD5A Scr_PostCopyAttrs
> BD5A Tras la copia (o tras @370C, desde @3547): si @A220 == 0
> BD5A - E34C/E34D: si hay movimiento, rellena 32 bytes de atributos en (@A186)
> BD5A   con 6868h (cielo) o el color del nivel (LevelData+F4) y mueve el puntero
> BD5A   @A186 4*n bytes: linea del horizonte en atributos (?).
> BD5A - Tras el avistamiento (@A22E) y con @A230 < 3: colores fijos en la columna 2, filas
> BD5A   11..18 de atributos (50,50,58,58,60,60,78,78): la barra vertical del medidor de
> BD5A   danos del criminal a la izquierda de la ventana (replay, chq_crim_sighted.png).
> BD5A Termina restaurando SP desde @BDBD+1.
L BDBD Scr_RestoreSP
L BDC1 Scr_ClearWindow
> BDC1 Prepara la ventana de juego: llama a @88E2, llena 4800-57FF con FFh,
> BDC1 atributos 5900: 41h x 28h, 60h x 68h, 15Fh x color de nivel
> BDC1 (LevelData+F4) y pone a 0 las columnas 0 y 31 de las filas 8..23.

# ---------------------------------------------------------------- interprete de pista
L BDFB Road_Advance
> BDFB Avance por la pista (por frame). @A23F += velocidad/2 (@A24A de 9 bits);
> BDFB por cada desbordamiento se entra en un segmento nuevo (@BE1F). Si no hay
> BDFB desbordamiento salta a @C0D9.
> BDFB Anillo de segmentos en la pagina EE00: 8 campos x 32 segmentos,
> BDFB direccion = EE00 + ((s + 20h*campo) & FFh), s = numero de segmento mod 256.
> BDFB @A240 = segmento actual (@A240/@A241 forman el puntero EExx). Ventana valida:
> BDFB s = @A240 .. @A240+1Fh; el segmento nuevo es @A240+1Fh.
L BE1F Road_NextSegment
> BE1F Entra en un segmento: @A240++. Antes de escribir, @A23C |= campo 3 y
> BE1F @A23D |= campo 4 del segmento que se acaba de dejar.
> BE1F Decodifica 6 flujos de pista (punteros @A26E, @A270, @A272, @A274, @A276, @A278;
> BE1F contadores @A242, @A243, @A247, @A245, @A244, @A246) y escribe el segmento nuevo:
> BE1F   campo 0 (curva):    flujo @A26E, byte (n<<4)|v, n+1 segmentos; v de 4 bits con
> BE1F                       signo-magnitud (bit3 = negativo) x2
> BE1F   campo 1 (pendiente): flujo @A270, (n<<4)|v, valor v-8
> BE1F   campo 2 (marcas):   flujo @A272, pares [contador][valor]; se guarda valor&F7;
> BE1F                       los bits 2-3 solo en el primer segmento (@BF2C)
> BE1F   campo 3:            flujo @A274, (n<<4)|v (si A151(?) != 1 se ponen a 0
> BE1F   campo 4:            flujo @A276, (n<<4)|v  los campos 3,4,5)
> BE1F   campo 5:            flujo @A278, sigue en zona C000 (@C05C)
> BE1F Byte 00 en un flujo = orden: 00 lo,hi = saltar a direccion; 01 = saltar a la
> BE1F direccion de continuacion (operandos BE6D... cargados por @BB69); >=02 lo,hi,
> BE1F lo,hi = guardar las dos continuaciones del desvio (@BB94+1 / @BBC1+1, etc.) y
> BE1F seguir en una secuencia fija E2C6.. (tramo de desvio).
L BE6C Road_Cont0
L BE71 Road_Jump0
L BE75 Road_Seq0
L BE7D Road_Field0
; BE8A campo 0: curva
L BEBE Road_Cont1
L BECF Road_Field1
; BED6 campo 1: pendiente
L BF09 Road_Cont2
L BF29 Road_Field2Rep
L BF2C Road_Field2Val
; BF20 campo 2 (marcas)
L BF55 Road_Field3
; BF46 campos 3,4,5 a 0
L BF83 Road_Cont3
L BF94 Road_Field3Put
L BFCC Road_Cont4
L BFDD Road_Field4Put

# ---------------------------------------------------------------- puntos de entrada no cubiertos
C B4CC
C B4F0
C B79C
