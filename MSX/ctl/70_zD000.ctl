# 70_zD000.ctl -- zona D000-E80F: graficos (sprites, fuentes), descriptores, guiones
# de recorrido por defecto, buffers de carretera y tablas de perspectiva/bordes.
# NO hay codigo en esta zona: todo lo que el analisis estatico decodificaba como
# codigo (D027-D08F, D3FF-D79A, DF00-E3A0, E451-E7A6) son datos (verificado con
# trazas de lectura de memoria y con los punteros de las rutinas de sprites).
#
# Formato comun de sprites (rutinas @B6DD/@B716 enmascarado, @B770 espejo, @949C/@9542 opaco):
#  - enmascarado: por fila, w pares (mascara, dato): POP DE -> E=mascara D=dato; pantalla = (pant AND E) OR D
#  - opaco: por fila, w bytes que se escriben tal cual
#  - las filas se guardan DE ABAJO A ARRIBA (la rutina hace DEC H): la primera fila es la inferior

> D000 Final de la tabla de @CFB2 (empieza fuera de esta zona): entradas de 3 bytes
> D000 (dy, dx, desplazamiento en @D027) usadas por @B69E para dibujar restos/chispas.
> D000 Nota: la instruccion de C483 (ld hl,#D010) usa #D0/#10 como constantes, no es puntero.
D D000 D026 b
L D027 tSprDebrisDesc
> D027 Descriptores de los 6 sprites de restos/chispas (?) usados por @B69E (indice 0,4..20
> D027 sacado de la tabla @CFB2). Entrada de 4 bytes: alto (filas), ancho (bytes), puntero.
D D027 D028 b
D D029 D02A a
D D02B D02C b
D D02D D02E a
D D02F D030 b
D D031 D032 a
D D033 D034 b
D D035 D036 a
D D037 D038 b
D D039 D03A a
D D03B D03C b
D D03D D03E a
L D03F Spr_HereArrow
D D03F D0E6 g 6
> D03F Flecha "HERE!" que senala al coche del criminal: 3 bytes x 28 filas, enmascarado.
> D03F Filas 0-20 = flecha (descriptores @E1DF/@E1E4, 21 filas), filas 21-27 = texto "HERE!"
> D03F (descriptor @E1D8, 28 filas).
L D0E7 Spr_Debris0
D D0E7 D0F4 g 2
> D0E7 Sprite enmascarado 8x7 (cuadradito 8x7) (?)
L D0F5 Spr_DebrisStar
D D0F5 D148 g 6
> D0F5 Sprite enmascarado 24x14 (estrella/destello 24x14) (?)
L D149 Spr_DebrisDust
D D149 D1C0 g 6
> D149 Sprite enmascarado 24x20 (nube de polvo tramada 24x20) (?)
L D1C1 Spr_Debris3
D D1C1 D1D0 g 4
> D1C1 Sprite enmascarado 16x4 (trozo curvo 16x4) (?)
L D1D1 Spr_Debris4
D D1D1 D1F4 g 4
> D1D1 Sprite enmascarado 16x9 (trozo curvo 16x9) (?)
L D1F5 Spr_Debris5
D D1F5 D20C g 2
> D1F5 Sprite enmascarado 8x12 (circulo 8x12) (?)
L D20D Spr_Smoke0
D D20D D28C g 8
L D28D Spr_Smoke1
D D28D D30C g 8
L D30D Spr_Smoke2
D D30D D38C g 8
L D38D Spr_Smoke3
D D38D D40C g 8
> D20D 4 fotogramas de humo/polvo de ruedas, 32x16 enmascarados (dibujados desde @B450,
> D20D @8271, @84A4; tambien en espejo).
> D40D Coche del jugador (Porsche, vista trasera). 9 fotogramas descritos en la tabla @CEDA
> D40D (20 bytes por fotograma: [dy,filas,ptr] de la pieza opaca + 4x[dy,filas,ptr] enmascaradas).
> D40D Aqui: las 9 piezas opacas centrales (40 px de ancho: luces, matricula, parachoques).
L D40D Spr_CarBody0
D D40D D452 g 5
L D453 Spr_CarBody1
D D453 D4A7 g 5
L D4A8 Spr_CarBody2
D D4A8 D4F7 g 5
L D4F8 Spr_CarBody3
D D4F8 D53D g 5
L D53E Spr_CarBody4
D D53E D592 g 5
L D593 Spr_CarBody5
D D593 D5DD g 5
L D5DE Spr_CarBody6
D D5DE D623 g 5
L D624 Spr_CarBody7
D D624 D673 g 5
L D674 Spr_CarBody8
D D674 D6C3 g 5
> D6C4 Piezas enmascaradas del coche del jugador, 4 por fotograma (9 fotogramas):
> D6C4 Roof = luneta/techo 40 px (dy #14), Low = bajos/ruedas 40 px (dy 0),
> D6C4 SideL/SideR = laterales de 8 px en x=#60 y x=#90.
L D6C4 Spr_CarRoof0
D D6C4 D71D g 10
L D71E Spr_CarLow0
D D71E D759 g 10
L D75A Spr_CarSideL0
D D75A D775 g 2
L D776 Spr_CarSideR0
D D776 D791 g 2
L D792 Spr_CarRoof1
D D792 D7E1 g 10
L D7E2 Spr_CarLow1
D D7E2 D809 g 10
L D80A Spr_CarSideL1
D D80A D823 g 2
L D824 Spr_CarSideR1
D D824 D83D g 2
L D83E Spr_CarRoof2
D D83E D897 g 10
L D898 Spr_CarLow2
D D898 D8BF g 10
L D8C0 Spr_CarSideL2
D D8C0 D8D7 g 2
L D8D8 Spr_CarSideR2
D D8D8 D8F5 g 2
L D8F6 Spr_CarRoof3
D D8F6 D959 g 10
L D95A Spr_CarLow3
D D95A D995 g 10
L D996 Spr_CarSideL3
D D996 D9AF g 2
L D9B0 Spr_CarSideR3
D D9B0 D9CB g 2
L D9CC Spr_CarRoof4
D D9CC DA25 g 10
L DA26 Spr_CarLow4
D DA26 DA4D g 10
L DA4E Spr_CarSideL4
D DA4E DA65 g 2
L DA66 Spr_CarSideR4
D DA66 DA81 g 2
L DA82 Spr_CarRoof5
D DA82 DADB g 10
L DADC Spr_CarLow5
D DADC DB17 g 10
L DB18 Spr_CarSideL5
D DB18 DB2D g 2
L DB2E Spr_CarSideR5
D DB2E DB4B g 2
L DB4C Spr_CarRoof6
D DB4C DB9B g 10
L DB9C Spr_CarLow6
D DB9C DBD7 g 10
L DBD8 Spr_CarSideL6
D DBD8 DBF1 g 2
L DBF2 Spr_CarSideR6
D DBF2 DC0D g 2
L DC0E Spr_CarRoof7
D DC0E DC5D g 10
L DC5E Spr_CarLow7
D DC5E DC85 g 10
L DC86 Spr_CarSideL7
D DC86 DC9F g 2
L DCA0 Spr_CarSideR7
D DCA0 DCB9 g 2
L DCBA Spr_CarRoof8
D DCBA DD09 g 10
L DD0A Spr_CarLow8
D DD0A DD31 g 10
L DD32 Spr_CarSideL8
D DD32 DD4B g 2
L DD4C Spr_CarSideR8
D DD4C DD69 g 2
L DD6A Spr_CarShadow0
D DD6A DE11 g 14
L DE12 Spr_CarShadow1
D DE12 DEB9 g 14
L DEBA Spr_CarShadow2
D DEBA DF61 g 14
> DD6A 3 sombras del coche del jugador, 56x12 enmascaradas (tabla @CF8E, se dibujan antes
> DD6A del coche desde @B5A4).
L DF62 Fnt_BigDigits
D DF62 DFF7 g 1
> DF62 Digitos grandes 0-9 para el marcador: 8x15, 15 bytes por digito, opacos, filas de
> DF62 arriba a abajo (rutina @9F47: indice*15, LDI por linea).
L DFF8 Fnt_Small
D DFF8 E0B1 g 1
> DFF8 Fuente pequena 8x6 (6 bytes por caracter) usada por @9B58: A-Z, ".", ",", "!",
> DFF8 espacio y apostrofo (31 caracteres). Los digitos (indices 31-40) no estan aqui: la rama
> DFF8 de @9B48 que los calcula no se ejecuta y apuntaria a @E0B2 (datos ajenos).
> E0B2 Listas de descriptores de 7 bytes: ancho (bytes), flags (bit0=1 enmascarado,
> E0B2 0 opaco), alto (filas), puntero fotograma A, puntero fotograma B. Cada lista son 6 escalas
> E0B2 (de cerca a lejos). Graficos en 7A0F-7BE5. Las 6 primeras listas se eligen por la tabla
> E0B2 de punteros @CDF4 (A232-4)*4+(A236&1)*2 desde @AFBA; la de @E1AE desde @B018.
> E0B2 El codigo que las usa (humo del criminal, @AF50-@B044) se ejecuta en los replays tras el primer golpe.
L E0B2 tSprCloudA0
D E0B2 E0B4 b
D E0B5 E0B8 a
D E0B9 E0BB b
D E0BC E0BF a
D E0C0 E0C2 b
D E0C3 E0C6 a
D E0C7 E0C9 b
D E0CA E0CD a
D E0CE E0D0 b
D E0D1 E0D4 a
D E0D5 E0D7 b
D E0D8 E0DB a
L E0DC tSprCloudA1
D E0DC E0DE b
D E0DF E0E2 a
D E0E3 E0E5 b
D E0E6 E0E9 a
D E0EA E0EC b
D E0ED E0F0 a
D E0F1 E0F3 b
D E0F4 E0F7 a
D E0F8 E0FA b
D E0FB E0FE a
D E0FF E101 b
D E102 E105 a
L E106 tSprCloudB0
D E106 E108 b
D E109 E10C a
D E10D E10F b
D E110 E113 a
D E114 E116 b
D E117 E11A a
D E11B E11D b
D E11E E121 a
D E122 E124 b
D E125 E128 a
D E129 E12B b
D E12C E12F a
L E130 tSprCloudB1
D E130 E132 b
D E133 E136 a
D E137 E139 b
D E13A E13D a
D E13E E140 b
D E141 E144 a
D E145 E147 b
D E148 E14B a
D E14C E14E b
D E14F E152 a
D E153 E155 b
D E156 E159 a
L E15A tSprCloudC0
D E15A E15C b
D E15D E160 a
D E161 E163 b
D E164 E167 a
D E168 E16A b
D E16B E16E a
D E16F E171 b
D E172 E175 a
D E176 E178 b
D E179 E17C a
D E17D E17F b
D E180 E183 a
L E184 tSprCloudC1
D E184 E186 b
D E187 E18A a
D E18B E18D b
D E18E E191 a
D E192 E194 b
D E195 E198 a
D E199 E19B b
D E19C E19F a
D E1A0 E1A2 b
D E1A3 E1A6 a
D E1A7 E1A9 b
D E1AA E1AD a
L E1AE tSprPuff
D E1AE E1B0 b
D E1B1 E1B4 a
D E1B5 E1B7 b
D E1B8 E1BB a
D E1BC E1BE b
D E1BF E1C2 a
D E1C3 E1C5 b
D E1C6 E1C9 a
D E1CA E1CC b
D E1CD E1D0 a
D E1D1 E1D3 b
D E1D4 E1D7 a
L E1D8 tSprHereFull
D E1D8 E1DA b
D E1DB E1DE a
; E1D8 flecha+texto HERE! (28 filas), usado por @AF98
> E1DF Descriptores de 5 bytes para @8FE0: ancho, flags (bit0 enmascarado, bit1 espejo (?)),
> E1DF alto, puntero. Elegidos por la variable A227 (1 o 2): la flecha HERE! sola (21 filas).
L E1DF tSprHereArrowR
D E1DF E1E1 b
D E1E2 E1E3 a
L E1E4 tSprHereArrowL
D E1E4 E1E6 b
D E1E7 E1E8 a
L E1E9 tObjBurstDef
D E1E9 E1EA a
D E1EB E1FE b
> E1E9 Definicion de un tipo de objeto lateral (?) referenciado por los datos del nivel 1 (5E49,
> E1E9 5E88, con manejador 924D/9252, ejecutado en los replays desde t=208 s). Formato: puntero a la lista de descriptores,
> E1E9 y 10 pares (?, desplazamiento en la lista) por nivel de distancia (0,7,14.. = registro 0..5).
L E1FF tSprBurst
D E1FF E201 b
D E202 E205 a
D E206 E208 b
D E209 E20C a
D E20D E20F b
D E210 E213 a
D E214 E216 b
D E217 E21A a
D E21B E21D b
D E21E E221 a
D E222 E224 b
D E225 E228 a
; E222 ultimo registro: 2 fotogramas alternos (@E274/@E28C); tambien referenciado desde 77F8
L E229 Spr_Burst0
D E229 E248 g 2
L E249 Spr_Burst1
D E249 E260 g 2
L E261 Spr_Burst2
D E261 E268 g 1
L E269 Spr_Burst3
D E269 E26E g 1
L E26F Spr_Burst4
D E26F E273 g 1
> E229 Destello blanco sobre fondo negro (opaco) en 5 escalas (luz de tunel / farola (?)).
L E274 Spr_RingA
D E274 E28B g 4
L E28C Spr_RingB
D E28C E2A3 g 4
> E274 Pequeno anillo 16x6 enmascarado, 2 fotogramas alternos (?).
> E2A4 Guiones de recorrido por defecto para los interpretes @BE45/@BEE9/@BF14/@BF62/@BFF3...
> E2A4 (curvas, cuestas, carril...). Formato general: pares (cuenta, valor); cuenta 0 = orden:
> E2A4 0 -> salto a puntero (2 bytes), 1 -> retorno al puntero guardado, 2 -> parametros + salto a @E2B8,
> E2A4 >=3 -> fija variables (A2F0, A2F1, A2F2/A2F3 = flecha HERE!). Algunos interpretes usan
> E2A4 entradas de un solo byte. Aqui hay bucles infinitos (valor constante + salto a si mismos).
D E2A4 E2A9 b
L E2AA Crs_LoopF0
D E2AA E2AC b
D E2AD E2AE a
L E2AF Crs_LoopF8
D E2AF E2B1 b
D E2B2 E2B3 a
D E2B4 E2B7 b
; E2B4 (?) sin referencias
L E2B8 Crs_Straight
D E2B8 E2BD b
D E2BE E2BF a
; E2B8 (12,0) (10,-1) y vuelve a empezar; usado tras la orden 2 (@C040)
L E2C0 Crs_LoopC0
D E2C0 E2C0 b
L E2C1 Crs_LoopF3
D E2C1 E2C3 b
D E2C4 E2C5 a
L E2C6 Crs_LoopC6
D E2C6 E2C9 b
D E2CA E2CB a
L E2CC Crs_LoopCC
D E2CC E2CE b
D E2CF E2D0 a
L E2D1 Crs_LoopD1
D E2D1 E2D1 b
> E2D2 Guiones iniciales que @BB69 carga en los punteros A13A..A144 al (re)arrancar el recorrido.
L E2D2 Crs_Init44
D E2D2 E2D4 b
L E2D5 Crs_Init40
D E2D5 E2D8 b
L E2D9 Crs_Init42
D E2D9 E2DC b
L E2DD Crs_Init3A
D E2DD E2E1 b
L E2E2 Crs_Init3C
D E2E2 E2E6 b
L E2E7 Crs_Init3E
D E2E7 E2F2 b
L E2F3 Crs_Init3E_Alt
D E2F3 E2FF b
> E300 Buffers de carretera escritos en ejecucion (en la imagen valen 0). 21-22 tramos de carretera.
L E300 tRoadSegY
D E300 E316 b
; E300 Y en pantalla de cada tramo (E301-E315, 21 tramos) (?); IY de @CCA8/@C465/@BA55
D E317 E31F b
L E320 tRoadSegX
D E320 E335 b
; E320 22 valores por tramo (desplazamiento lateral/curva (?)), @CC14/@CC8E
L E336 tRoadSegClipY
D E336 E34A b
; E336 minimo acumulado de tRoadSegY (oclusion por cuestas) (?), @CDB7
L E34B vRoadE34B
D E34B E34B b
; E34B se pone a 8 en @880A (?)
L E34C vRoadE34C
D E34C E34E b
; E34C par desplazado cada fotograma en @BD60 (?)
L E34F tRoadSegAcc
D E34F E363 b
; E34F 21 valores acumulados (suma prefija) en @A579 (?)
L E364 tFxWipePat
D E364 E3FB g 1
> E364 Patrones 8x8 (8 bytes) de la transicion de @8D8F/@8DF9 (rellena con OR bloques del buffer
> E364 trasero en FFxx). Punteros de inicio en la tabla EC00 (copiada desde E88E): E35C/E3B4 hacia
> E364 delante, E3BC/E3F4 hacia atras. E364-E3BB marcos crecientes, E3BC-E3F3 circulos crecientes.
D E3FC E3FF b
L E400 tRoadEdgeMask
D E400 E4FF b
> E400 Tabla de bordes de carretera (H=#E4, L=indice*4) para @3300 (RoadEdge_MSX) y el relleno
> E400 @C63F/@CA68: 64 entradas de 4 bytes (mascara AND, patron OR, bytes de relleno).
L E500 tRoadCurveW
D E500 E5FF w
> E500 128 palabras con signo (0 en E540, crecientes hasta 14DE en E5FE; E502-E53E negativas).
> E500 Leida por @CC20 con IX=E5xx, ixl=(#80-a)&#FE (curvatura/desplazamiento lateral (?)).
L E600 tRoadPerspA
D E600 E6AF b
> E600 Tablas de perspectiva por tramo: 8 variantes x 22 bytes (cuesta (?)).
> E600 A: decrecientes (60 4A 3C ... 0A), leida por @918C/@CD5A (H=#E6).
L E6B0 tRoadPerspB
D E6B0 E75F b
; E6B0 8x22, leida por @CC00 (IY=E6B0+n)
L E760 tRoadPerspC
D E760 E80F b
; E760 8x22, leida por @CC89 (HL=E760+n); E800 cae dentro (falsa ref. de @BA27/@BB2D)
