# 30_z9000.ctl -- zona 9000-9FFF
#   9001-904F  despacho de objetos laterales (continuacion del bucle @8F5F)
#   9052-961A  objetos de borde de carretera escalados y blitter de sprites al buffer F000
#   961B       generador pseudoaleatorio
#   962E-9BCE  sistema de mensajes de radio (retrato + texto con cursor) y sus textos/guiones
#   9BCF-9D2D  tiempo restante, continuacion, puntuacion
#   9D62-9FFF  HUD (stage, LO/HI, turbos, velocidad, tiempo, distancia, marcador) e impresion de texto

# ---------------------------------------------------------------- despacho de objetos laterales
> 9001 (Continuacion de @8FF8, dentro del bucle de filas de @8F5F.) Objeto del lado A:
> 9001 E = tipo de objeto (fila de la tabla de terreno EExx). Busca la entrada E (7 bytes)
> 9001 en la tabla del nivel apuntada por (LevelData+#F8): +0 DE = descriptor grafico,
> 9001 +2 rutina de dibujo, +4..+6 no usados aqui. Salta a la rutina con IX/IY/B (fila) intactos
> 9001 y vuelve por @901C. Entradas: IX = fila de @E9B0 (+0 = X de referencia en pixels
> 9001 del buffer, +1 = 0 si visible), IY = fila de las tablas E2E0/E315 (Y), B = fila 1..20.
; 900B direccion de vuelta para la rutina de dibujo
; 900F tabla del lado A (7 bytes por tipo)
L 901C Obj_SideARet
L 9023 Obj_SideB
> 9023 Objeto del lado B (igual que el lado A pero con la tabla (LevelData+#FE)).
> 9023 A = tipo. El tipo 2 se dibuja aunque (IX+1) <> 0 (objeto que cruza la carretera, @9052).
L 902E Obj_SideBCall
; 903E tabla del lado B (7 bytes por tipo)
L 904B Obj_SideBRet

C 9052
L 9052 Obj_DrawSpan
> 9052 Rutina de dibujo de objeto "portico" (tipo 2 en algunos niveles, p.ej. 08_raw): dibuja
> 9052 primero el poste con @916C (si visible) y luego una banda horizontal que cruza la
> 9052 carretera entre la X de esta fila (IX) y la de la fila del otro lado (IX-2), recortada a
> 9052 las columnas 1..30. DE = descriptor: +0 objeto compuesto (para @916C), +2 palabra -> tabla
> 9052 de banda: alturas por escala (1 byte, 10 escalas) en +2.., y en +#14+3*s: altura, puntero
> 9052 al patron (1 byte por linea). Escribe en el buffer F000 de abajo arriba.
> 9052 Confirmado en el replay chasehq_5 (nivel 3, t=1208 s, bloque de cinta a/08 = b/05): es el
> 9052 portico de celosia metalica que cruza la carretera (docs/img/replay/chq5_obj_span.png).
> 9052 Llega por la tabla del lado B (@904A -> 9052). Los niveles 1, 2, 4 y 5 no lo usan en el replay.
; 9067 escala de perspectiva: E6xx indexada por (vA23F & #E0)*11/16 + fila
; 90C8 E = columna derecha por defecto (31)
; 90EB salto calculado dentro de la cadena de LD (HL),A / INC L
C 910F
L 910F Obj_SpanNextLine
L 9113 Obj_SpanLine
C 9117
L 9117 Obj_SpanFill
> 9117 Cadena desenrollada LD (HL),A / INC L (hasta 30 bytes); se entra por el JR automodificado.
L 9152 Obj_SpanLineUp

# ---------------------------------------------------------------- objetos compuestos
L 916C Obj_DrawCompositeB
> 916C Dibuja un objeto compuesto (poste + partes apiladas) en el lado B: posicion X = (IX+0)+16-desp.
L 9171 Obj_DrawCompositeA
> 9171 Igual, lado A: posicion X = (IX+0)+desp.
> 9171 Entradas: DE = descriptor compuesto, B = fila 1..20 (escala = min(B,10)), IX/IY = fila.
> 9171 Descriptor compuesto: lista de [n][puntero a parte], n=1 termina.
> 9171   n=2: parte de tamano fijo; n=3..10: parte "estirable" que se repite (mosaico) hasta una
> 9171   altura = factor(n) * escala de perspectiva (E6xx): 3:x1.5 4:x0.5 5:x1.125 6:x0.375
> 9171   7:x0.75 8:x0.25 9:x1 >=10:x2.
> 9171 Parte: +0 palabra base, +2*s (s=1..10) par [desp X][desp desde base] -> fotograma.
> 9171 Las partes se apilan hacia arriba: @933D+1 = -(altura acumulada).
L 9174 Obj_DrawComposite
; 918C tabla de escala por fila (E600 + 22*(vA23F>>5) + fila)
; 918F escala para las partes estirables
; 91A0 desplazamiento 2*escala-1 en las tablas de parte
L 91A4 Obj_CompPartLoop
; 91A7 desplazamiento vertical = -(altura ya apilada)
; 91AC n=1: fin de la lista
L 91BA Obj_CompOffset
L 91CD Obj_CompCallFixed
; 91CD destino automodificado: @9293 (lado B) o @92FC (lado A)
L 91D0 Obj_CompNext
L 91DA Obj_CompStretch
> 91DA Parte estirable: calcula la altura con el factor segun n. Las ramas de @91DB y
> 91DA @921F (estiramiento y mosaico vertical) solo se han visto en el nivel 3 (replay
> 91DA chasehq_5, t=1124 s: edificios de la ciudad, docs/img/replay/chq5_compscale.png).
L 91DB Obj_CompScale
L 921F Obj_CompStretchH
; 9228 recorta la altura contra la linea limite de la fila (IY+53)
; 9233 altura total a rellenar
; 9239 altura del fotograma (periodo del mosaico)
; 923C modo 2 = mosaico vertical
L 9243 Obj_CompCallTiled

C 924D
L 924D Obj_DrawRaisedB
> 924D Objeto simple elevado (lado B / lado A en @9252): solo filas < 16; desplazamiento
> 924D vertical = -(t - t/4), t = escala de perspectiva de la fila. Continua en @9279 / @92E2
> 924D via PUSH HL + RET con A = desplazamiento.
C 9252
L 9252 Obj_DrawRaisedA
L 9255 Obj_DrawRaised
L 9278 Obj_DrawSimpleB
> 9278 Objeto simple (un fotograma por escala), lado B. DE = descriptor: +0 base,
> 9278 +2*s par [desp X][desp fotograma]. B = fila. Sigue en @9293.
L 9279 Obj_DrawSimpleBOff
L 9293 Obj_PlaceB
> 9293 Lado B: X derecha = (IX+0)+16-B (B = desplazamiento X de la escala). HL = fotograma.

# ---------------------------------------------------------------- recorte y blitter de sprites
L 929A Spr_DrawAtRightX
> 929A Dibuja un fotograma en el buffer F000 dado su borde DERECHO.
> 929A A = X del borde derecho (pixels del buffer; zona visible 8..#F7), HL = fotograma,
> 929A IY = tablas de Y (IY+0 = Y base, IY+53 = Y limite), @933D+1 = desplazamiento vertical,
> 929A @93C0+1 = modo (0 normal, 1 volteo vertical (?), 2 mosaico vertical).
> 929A Recorta por la izquierda si hace falta. Tambien lo usan los coches (@AA30, @AF32, @B03A).
> 929A Formato de fotograma: +0 anchura en bytes, +1 bit0 = con mascara (pares mascara/dato,
> 929A el doble de bytes por linea) y bits1-7 <> 0 = espejado (se dibuja de derecha a izquierda),
> 929A +2 altura en lineas, +3 puntero a datos (desplazamiento 0), +5 puntero a datos
> 929A desplazados 4 pixels (la X se ajusta a multiplos de 4).
; 92A9 totalmente visible por la izquierda: camino normal
L 92BB Spr_ClipLeft
L 92D2 Spr_ClipLeftFlags
L 92E1 Obj_DrawSimpleA
> 92E1 Objeto simple, lado A (igual que @9278). Sigue en @92FC.
L 92E2 Obj_DrawSimpleAOff
L 92FC Obj_PlaceA
> 92FC Lado A: X izquierda = (IX+0)+B.
L 9309 Spr_DrawAtX
> 9309 Dibuja un fotograma dado su borde IZQUIERDO: A = X (invisible si >= #F7).
> 9309 Resto de entradas como @929A. Recorta por la derecha.
L 930E Spr_ClipRight
; 9312 bit0 = (X/4) impar -> usar los datos desplazados 4 pixels
L 931F Spr_ClipRightFlags
L 932B Spr_OpqMirrorShift
; 932B espejado: se invierte la eleccion de desplazamiento
L 9333 Spr_CheckMask
L 933B Spr_ClipY
L 933D Spr_YOffset
; 933D D = desplazamiento vertical (automodificado)
L 9347 Spr_ClipYBase
L 9359 Spr_ClipYAdj
L 938D Spr_ClipYTop
L 9390 Spr_SetupBlit
> 9390 Elige los datos (desplazamiento 0 o 4 px), salta bytes recortados y lineas ocultas y
> 9390 calcula la direccion en el buffer: H = #F0 + (Y & #0F), L = (Y & #70)*2 + columna.
L 9395 Spr_ShiftSel
L 939C Spr_DataPtr
L 93A9 Spr_SkipLines
L 93AE Spr_BufAddr
L 93C0 Spr_Mode
> 93C0 Despacho segun modo (@93C0+1) y banderas en F' (C = con mascara, NZ = espejado):
> 93C0 modo 0: @B701 mascara / @949C opaco; espejado @B76C / @9542.
> 93C0 modo 1: @B7EF mascara / @9479 opaco. modo 2 (mosaico): @9436 mascara / @93DF opaco.
L 93D0 Spr_Mode0
L 93D9 Spr_Mode0Mirror
L 93DF Spr_TileOpaque
> 93DF Mosaico vertical opaco: repite el fotograma (altura @9415+1) hasta cubrir @9404+1 lineas.
L 93FB Spr_TileSetup
L 9404 Spr_TileLeft
L 940F Spr_TileCall
L 9412 Spr_TileData
L 9415 Spr_TileHeight
L 941A Spr_TileLast
L 941D Spr_TileJump
L 9420 Spr_TileOpaqueOdd
L 9436 Spr_TileMasked
> 9436 Mosaico vertical con mascara (usa la cadena de @B729 / @B716).
L 945F Spr_TileMLeft
L 946C Spr_TileMData
L 946F Spr_TileMHeight
L 9474 Spr_TileMLast
L 9479 Spr_FlipVOpaque
> 9479 Modo 1, opaco: apunta a la ultima linea de datos y usa paso negativo (volteo vertical (?)).
L 9487 Spr_FlipVMul
L 9492 Spr_FlipVGo
L 949C Spr_DrawOpaque
> 949C Sprite opaco (sin mascara), de abajo arriba. A = anchura en bytes, HL = buffer,
> 949C HL' = datos, DE' = bytes por linea, B' = lineas. Entra por JP (IX) en la cadena
> 949C POP DE / LD (HL),E / LD (HL),D (SP = datos). Anchura par en @94C8, impar en @951A.
L 94B1 Spr_OpaqueLines
L 94BB Spr_OpaqueNext
L 94BE Spr_OpaqueRestSP
L 94C2 Spr_OpaqueAdv
L 94C3 Spr_OpaqueLine
L 94C8 Spr_OpaqueChain
L 94F2 Spr_DrawOpaqueOdd
L 9503 Spr_OpaqueOddLines
L 950D Spr_OpaqueOddNext
L 9510 Spr_OpaqueOddRestSP
L 9514 Spr_OpaqueOddAdv
L 9515 Spr_OpaqueOddLine
L 951A Spr_OpaqueOddChain
L 9542 Spr_DrawOpqMirror
> 9542 Sprite opaco espejado: escribe de derecha a izquierda (DEC L) invirtiendo cada byte
> 9542 con la tabla de espejo en EF00 (LD A,(DE) con D=#EF). Impar en @95B3.
L 9567 Spr_OpqMirrorNext
L 956A Spr_OpqMirrorRestSP
L 956E Spr_OpqMirrorAdv
L 956F Spr_OpqMirrorLine
C 9575
L 9575 Spr_OpqMirrorChain
L 95B3 Spr_DrawOpqMirrorOdd
L 95D0 Spr_OpqMirrorOddNext
L 95D3 Spr_OpqMirrorOddRestSP
L 95D7 Spr_OpqMirrorOddAdv
L 95D8 Spr_OpqMirrorOddLine
C 95DE
L 95DE Spr_OpqMirrorOddChain

# ---------------------------------------------------------------- aleatorio
L 9618 vRndSeed
D 9618 961A b
L 961B Rnd
> 961B Generador pseudoaleatorio: s0 -= #8D, s1 += 3, A = ((s0+s1) >> 1 rot) + rrc(s2);
> 961B devuelve A = nuevo s2. Estado de 3 bytes en @9618. Modifica HL.

# ---------------------------------------------------------------- radio: variables
L 962E vRadioCharPtr
D 962E 9631 w
; 962E puntero al siguiente caracter del texto
L 9630 vRadioScriptPtr
; 9630 puntero al guion en curso
L 9632 vRadioCol
D 9632 963E b
; 9632 posicion (en caracteres) del siguiente caracter en la linea
L 9633 vRadioPause
; 9633 pausa tras fin de texto (10 cuadros, cursor parpadeando)
L 9634 vRadioNoise
; 9634 4 pares de bytes del ruido de "sintonizacion" del retrato
L 963C vRadioTimer
; 963C cuadros restantes de ruido (apertura/cierre)
L 963D vRadioState
; 963D 0 reposo, 1 mensaje pedido, 2 hablando, 3 cerrando
L 963E vRadioPrio
; 963E prioridad del mensaje actual
L 963F Radio_TxtNancyHQ
L 965A Radio_TxtSpecialInv
L 9681 Radio_TxtTargetTurned
L 969E Radio_TxtRightAhead
L 96B5 Radio_TxtLeftAhead
L 96CB Radio_TxtLoudClear
L 96E8 Radio_TxtRoger
L 96EE Radio_TxtGotcha
L 9701 Radio_TxtWhatDoing
L 9718 Radio_TxtBadGuys
L 973D Radio_TxtKeepMessin
L 9761 Radio_TxtTimeRunOut
L 9787 Radio_TxtGetMovin
L 979C Radio_TxtOhNo
L 97A3 Radio_TxtPlease
L 97AA Radio_TxtGreat
L 97B0 Radio_TxtOuch
L 97B5 Radio_TxtLetsGo
L 97CA Radio_TxtYaooow
L 97D3 Radio_TxtBearDown
L 97DD Radio_TxtPushMore
L 97F0 Radio_TxtOneMoreTime
L 97FE Radio_TxtOhMan
L 9805 Radio_TxtWhoa
L 980E Radio_TxtHarder
L 9815 Radio_TxtWrongJob
L 9837 Radio_TxtClassified
L 9857 Radio_TxtGoodBoy
L 9879 Radio_TxtMediocre
L 989B Radio_TxtSeeYou
D 963F 98A8 t

> 963F Textos de la radio: ASCII, el ultimo caracter con el bit 7 a 1. Fuente propia
> 963F de 5 px (@DFF8): A-Z . , ! espacio ' 0-9.
> 98A9 Guiones de radio. Formato: [retrato][punteros a texto...] y luego FF = fin o
> 98A9 FE dw = continuar con otro guion. Si el primer byte es FC le siguen 3 punteros a guiones
> 98A9 y se elige uno al azar (@961B: <#55, <#AA, resto). Retrato 0 = el del nivel
> 98A9 ((LevelData+#F2)), n>0 = #7B35 + n*#B4 (160 bytes de bitmap 4x40 + 20 de atributos).
> 98A9 Se lanzan con @9945 (A = prioridad). El nivel tiene su propio guion en (LevelData+#104).
L 98A9 Radio_ScrTurnLeft
D 98A9 98A9 b
; 98A9 retrato 0
D 98AA 98AB a
; 98AA "THIS IS SPECIAL INVESTIGATION AIRBORNE."
D 98AC 98AD a
; 98AC "THE TARGET VEHICLE HAS TURNED"
D 98AE 98AF a
; 98AE "LEFT UP AHEAD... OVER."
D 98B0 98B0 b
; 98B0 FE = continuar en otro guion
D 98B1 98B2 a
L 98B3 Radio_ScrTurnRight
D 98B3 98B3 b
; 98B3 retrato 0
D 98B4 98B5 a
; 98B4 "THIS IS SPECIAL INVESTIGATION AIRBORNE."
D 98B6 98B7 a
; 98B6 "THE TARGET VEHICLE HAS TURNED"
D 98B8 98B9 a
; 98B8 "RIGHT UP AHEAD... OVER."
D 98BA 98BA b
; 98BA FE = continuar en otro guion
D 98BB 98BC a
L 98BD Radio_ScrReplyRnd
D 98BD 98BD b
D 98BE 98C3 a
; 98BD FC = eleccion aleatoria entre 3 guiones
L 98C4 Radio_ScrLoudClear
D 98C4 98C4 b
; 98C4 retrato 3
D 98C5 98C6 a
; 98C5 "WE READ LOUD AND CLEAR! OVER."
D 98C7 98C7 b
; 98C7 fin
L 98C8 Radio_ScrRoger
D 98C8 98C8 b
; 98C8 retrato 2
D 98C9 98CA a
; 98C9 "ROGER!"
D 98CB 98CB b
; 98CB fin
L 98CC Radio_ScrGotcha
D 98CC 98CC b
; 98CC retrato 3
D 98CD 98CE a
; 98CD "GOTCHA, NANCY BABY!"
D 98CF 98CF b
; 98CF fin
L 98D0 Radio_ScrWrongWay
D 98D0 98D0 b
; 98D0 retrato 2
D 98D1 98D2 a
; 98D1 "WHAT ARE YOU DOING MAN!"
D 98D3 98D4 a
; 98D3 "THE BAD GUYS ARE GOING THE OTHER WAY."
D 98D5 98D5 b
; 98D5 fin
L 98D6 Radio_ScrEncourageRnd
D 98D6 98D6 b
D 98D7 98DC a
; 98D6 FC = eleccion aleatoria entre 3 guiones
L 98DD Radio_ScrBearDown
D 98DD 98DD b
; 98DD retrato 2
D 98DE 98DF a
; 98DE "BEAR DOWN."
D 98E0 98E0 b
; 98E0 fin
L 98E1 Radio_ScrPushMore
D 98E1 98E1 b
; 98E1 retrato 2
D 98E2 98E3 a
; 98E2 "MORE, PUSH IT MORE!"
D 98E4 98E4 b
; 98E4 fin
L 98E5 Radio_ScrHarder
D 98E5 98E5 b
; 98E5 retrato 2
D 98E6 98E7 a
; 98E6 "HARDER!"
D 98E8 98E8 b
; 98E8 fin
L 98E9 Radio_ScrOhMan
D 98E9 98E9 b
; 98E9 retrato 2
D 98EA 98EA b
; 98EA FE = continuar en otro guion
D 98EB 98EC a
L 98ED Radio_ScrEncourageRnd2
D 98ED 98ED b
D 98EE 98F3 a
; 98ED FC = eleccion aleatoria entre 3 guiones
L 98F4 Radio_ScrPlease
D 98F4 98F4 b
; 98F4 retrato 2
D 98F5 98F6 a
; 98F5 "PLEASE!"
D 98F7 98F7 b
; 98F7 fin
L 98F8 Radio_ScrGetMovin
D 98F8 98F8 b
; 98F8 retrato 2
D 98F9 98FA a
; 98F9 "LET'S GET MOVIN' MAN!"
D 98FB 98FB b
; 98FB fin
L 98FC Radio_ScrHurryUp
D 98FC 98FC b
; 98FC retrato 1
D 98FD 98FE a
; 98FD "THIS IS NANCY AT CHASE H.Q."
D 98FF 9900 a
; 98FF "IF YOU KEEP MESSIN' AROUND LIKE THAT"
D 9901 9902 a
; 9901 "YOUR TIME IS GOING TO RUN OUT... OVER."
D 9903 9903 b
; 9903 fin
L 9903 Radio_ScrEmpty
D 9903 9903 b
; 9903 retrato 255
D 9904 9905 a
; 9904 (puntero, no es texto)
D 9906 9907 a
; 9906 (puntero, no es texto)
D 9908 9909 a
; 9908 (puntero, no es texto)
D 990A 990B a
; 990A (puntero, no es texto)
D 990C 990D a
; 990C "OH, NO!"
D 990E 990E b
; 990E fin
L 9904 Radio_ScrCrashRnd
D 9904 9904 b
D 9905 990A a
; 9904 FC = eleccion aleatoria entre 3 guiones
L 990B Radio_ScrOhNo
D 990B 990B b
; 990B retrato 2
D 990C 990D a
; 990C "OH, NO!"
D 990E 990E b
; 990E fin
L 990F Radio_ScrOuch
D 990F 990F b
; 990F retrato 2
D 9910 9911 a
; 9910 "OUCH!"
D 9912 9912 b
; 9912 fin
L 9913 Radio_ScrYaooow
D 9913 9913 b
; 9913 retrato 2
D 9914 9915 a
; 9914 "YAOOOOOW!"
D 9916 9916 b
; 9916 fin
L 9917 Radio_ScrPraiseRnd
D 9917 9917 b
D 9918 991D a
; 9917 FC = eleccion aleatoria entre 3 guiones
L 991E Radio_ScrWhoa
D 991E 991E b
; 991E retrato 3
D 991F 9920 a
; 991F "WHOAAAAA!"
D 9921 9921 b
; 9921 fin
L 9922 Radio_ScrGreat
D 9922 9922 b
; 9922 retrato 3
D 9923 9924 a
; 9923 "GREAT!"
D 9925 9925 b
; 9925 fin
L 9926 Radio_ScrOneMoreTime
D 9926 9926 b
; 9926 retrato 2
D 9927 9928 a
; 9927 "ONE MORE TIME."
D 9929 9929 b
; 9929 fin
L 992A Radio_ScrGameOverRnd
D 992A 992A b
D 992B 9930 a
; 992A FC = eleccion aleatoria entre 3 guiones
L 9931 Radio_ScrWrongJob
D 9931 9931 b
; 9931 retrato 1
D 9932 9933 a
; 9932 "WE THINK YOU PICKED THE WRONG JOB."
D 9934 9935 a
; 9934 "BETTER CHECK THE CLASSIFIED ADS."
D 9936 9936 b
; 9936 fin
L 9937 Radio_ScrGoodBoy
D 9937 9937 b
; 9937 retrato 1
D 9938 9939 a
; 9938 "ONE MORE TRY FOR BEING A GOOD BOY!"
D 993A 993A b
; 993A fin
L 993B Radio_ScrMediocre
D 993B 993B b
; 993B retrato 1
D 993C 993D a
; 993C "YOU'RE A MEDIOCRE DRIVER, BROTHER!"
D 993E 993F a
; 993E "SEE YOU LATER."
D 9940 9940 b
; 9940 fin
L 9941 Radio_ScrLetsGo
D 9941 9941 b
; 9941 retrato 3
D 9942 9943 a
; 9942 "LET'S GO. MR. DRIVER."
D 9944 9944 b
; 9944 fin

# ---------------------------------------------------------------- radio: rutinas
L 9945 Radio_Say
> 9945 Pide un mensaje de radio. HL = guion, A = prioridad. Si hay un mensaje pedido o
> 9945 hablando (estado 1-2) con prioridad >= A, se ignora. Pone estado 1 y la pausa a 0.
L 9955 Radio_SayNow
L 9965 Radio_Update
> 9965 Maquina de estados de la radio (una vez por cuadro, bucle principal y bucles de
> 9965 presentacion). Estado (@963D):
> 9965  0 reposo: cursor parpadeando al inicio de la linea de texto.
> 9965  1 pedido: borra la linea, 4 cuadros de ruido en el retrato y pasa a 2.
> 9965  2 hablando: tras el ruido dibuja el retrato y escribe 1 caracter por cuadro con cursor;
> 9965    al final del texto 10 cuadros de cursor parpadeando y sigue con el siguiente texto
> 9965    del guion (FF -> estado 3, FE -> salto con nuevo ruido).
> 9965  3 cerrando: 4 cuadros de ruido y apaga los atributos del retrato; vuelve a 0.
> 9965 Pantalla (formato Spectrum 4000): retrato en fila 1 col 22 (4x5 caracteres),
> 9965 texto en la linea de pixels que empieza en #45C1 (fila 6 linea 5, 30 bytes x 6 lineas).
; 997C retrato en negro
L 997F Radio_IdleCursor
L 9981 Radio_BlinkPhase
; 9981 patron de parpadeo (#AA rotado cada cuadro)
L 998F Radio_Talking
; 99A3 durante la pausa: redibuja el ultimo caracter con/sin cursor
L 99B6 Radio_TypeOrNext
L 99BD Radio_NextText
; 99C5 FE dw: continuar en otro guion
L 99D3 Radio_Stop
> 99D3 Termina el mensaje: estado 3 (cierre con 4 cuadros de ruido) y borra la linea de texto.
L 99DF Radio_Start
L 99E4 Radio_Retune
L 99EC Radio_OpenScript
> 99EC Inicio de guion: resuelve FC (eleccion aleatoria), dibuja el retrato y toma el primer texto.
L 99EF Radio_ScriptByte
L 9A06 Radio_ScriptJump
L 9A0C Radio_Portrait
; 9A14 banco de retratos: #7B35 + n*#B4
L 9A1A Radio_PortraitMul
L 9A1D Radio_PortraitDraw
L 9A24 Radio_SetText
L 9A30 Radio_TypeChar
> 9A30 Escribe el caracter actual en la columna A (con cursor detras); A=0 borra antes la linea.
> 9A30 Si el caracter lleva el bit 7 (fin de texto) arma la pausa de 10 cuadros.
L 9A4C Radio_TypeAdvance
L 9A55 Radio_NoiseTimer
L 9A5C Radio_Noise
> 9A5C Cuadro de "ruido" en el retrato: cursor alternando y 40 lineas x 4 bytes pseudoaleatorias
> 9A5C (generador de 4 pares en @9634); luego atributos del retrato = #47.
L 9A6B Radio_NoiseFill
L 9A70 Radio_NoiseLine
L 9A76 Radio_NoiseByte
L 9A92 Radio_NoiseNext
L 9A98 Radio_PortraitAttr
> 9A98 Rellena los 4x5 atributos del retrato (#5836) con A.
L 9AA0 Radio_PortraitAttrRow
L 9AAB Radio_DrawPortrait
> 9AAB Copia un bloque de 4 columnas x 40 lineas (160 bytes, HL) a la pantalla Spectrum en DE
> 9AAB y despues sus 20 atributos (4x5) con @9ACE.
L 9AAF Radio_DrawPortraitLine
L 9ACE Radio_CopyAttr4x5
> 9ACE Copia 20 bytes de atributos (4 de ancho x 5 filas) desde HL a los atributos que
> 9ACE corresponden a la direccion de pantalla en la pila. Tambien desde @8EE4.
L 9ADA Radio_CopyAttrRow
L 9AEC Radio_PutChar
> 9AEC Dibuja el caracter D (ASCII) en la columna A de la linea de radio, sin cursor.
L 9AF1 Radio_PutCharCursor
> 9AF1 Igual pero dibuja ademas un bloque de cursor detras del caracter.
> 9AF1 Columna A: X = 5*A+2 pixels desde la columna 1; A=#FF = posicion de reposo.
> 9AF1 Fuente de 5x6 en @DFF8 (6 bytes por caracter): A-Z=0-25 .=26 ,=27 !=28 espacio=29
> 9AF1 '=30 0-9=31-40. Se desplaza con una cadena SRL B / RR C (JR automodificado).
L 9AF4 Radio_PutCharGo
L 9B08 Radio_PutCharX
L 9B10 Radio_PutCharCol
L 9B12 Radio_PutCharDiv8
L 9B4C Radio_PutCharSym
L 9B4F Radio_PutCharGlyph
L 9B5F Radio_PutCharLine
L 9B60 Radio_PutCharFill
L 9B63 Radio_PutCharOr
L 9B66 Radio_PutCharShift
; 9B66 JR automodificado dentro de la cadena de desplazamiento
C 9B68
L 9B68 Radio_ShiftChain
; 9B68 nunca se usa el desplazamiento 8 (B >= 1)
L 9B88 Radio_PutCharMask
L 9BA1 Radio_PutCharNext
L 9BA7 Radio_ClearLine
> 9BA7 Borra la linea de texto de la radio: 6 lineas x 30 bytes desde #45C1.
L 9BAE Radio_ClearLineLoop
L 9BC9 Radio_ClearLineNext

# ---------------------------------------------------------------- tiempo y continuacion
L 9BCF Time_Tick
> 9BCF Cuenta atras del tiempo (cada cuadro de juego). No hace nada si vA230 <> 0 o vA231 = 4.
> 9BCF Estado en vA229: 0 normal: cada 15 cuadros (prescaler vA17D) resta 1 al tiempo BCD vA17E;
> 9BCF con 15 lanza el aviso @Radio_ScrHurryUp; con 0 pasa a 1 (vA16F = #93).
> 9BCF 1 tiempo agotado: si se ha recuperado tiempo vuelve a 0; si no muestra el texto @8D07
> 9BCF   y cuando la velocidad vA24A llega a 0 pasa a 2 y sale por @83C7 (A=4).
> 9BCF 2 si quedan continuaciones (vA13D) ofrece continuar (@9C31) -> 3; si no, fin @88A9.
> 9BCF 3 cuenta 10..0 de continuacion (@9C7E); con el boton (bit 4 de vA0D5) continua (@9C57).
> 9BCF 4 nada.
> 9BCF Medido en el replay chasehq_firststage.omr: una unidad del reloj (15 cuadros)
> 9BCF dura 2,3-2,4 s reales en MSX1, es decir, ~6,2-6,6 cuadros de juego por segundo en
> 9BCF partida; un nivel de 60 "segundos" dura ~145 s. Secuencia vista dos veces
> 9BCF (t=245,9 y 401,4): 1 -> 2 a los ~4,5 s (coche parado) -> 3 a los ~3 s -> 0 al pulsar.
L 9BF9 Time_Count
L 9C0D Time_StOver
L 9C1B Time_WaitStop
L 9C31 Time_StOffer
; 9C3F digito de continuaciones en el texto @8D8B
; 9C49 cuenta atras: H = 1 (cuadros por paso), L = #15 (21 medios pasos)
L 9C50 Time_StCountdown
; 9C53 bit 4 = GEAR (tecla de marcha o disparo)
; 9C5B CONTINUE borra vCrimDmgLvl y vCrimHits: el criminal recupera toda la vida
; 9C5B Al continuar, el contador de golpes vuelve a cero
; 9C72 tiempo = 60 (BCD)
; 9C75 vContinuesUsed++ (afecta al CLEAR BONUS de @8AD2)
L 9C79 Time_Continue
L 9C7E Time_CountdownTick
L 9C84 Time_CountdownVar
; 9C84 H = cuadros hasta el siguiente paso, L = pasos (automodificado)
L 9C95 Time_CountdownBeep
L 9CA5 Time_CountdownDigits
L 9CB8 Time_CountdownOne
L 9CBB Time_CountdownPut

# ---------------------------------------------------------------- puntuacion
L 9CC2 Score_AddSpeed
> 9CC2 Suma al marcador (8002-8005, 8 digitos BCD) un valor derivado de la velocidad vA24A
> 9CC2 (aprox. velocidad/2, ajustado con DAA). Cada cuadro de juego.
L 9CD6 Score_Award
> 9CD6 Concede puntos con texto emergente: A = BCD unidades/decenas, E = centenas/millares,
> 9CD6 D = decenas/centenas de millar. Construye el texto en @9D51 (de derecha a izquierda,
> 9CD6 corta en el primer cero tras un digito no nulo), arma vA22C y suma al marcador.
L 9CF8 Score_DigitHi
L 9CFC Score_Digit
L 9D07 Score_DigitNZ
L 9D09 Score_DigitPut
L 9D0E Score_AwardDone
L 9D17 Score_Add
> 9D17 Suma BCD al marcador: A (byte bajo), E, D. Marcador = 4 bytes BCD en 8002-8005
> 9D17 (8002 el menos significativo).
L 9D2E Score_HitBonus
> 9D2E Bonificaciones pendientes (vA22B veces): vA13C += 2 (BCD, max 80) y concede
> 9D2E vA13C*100 puntos con @9CD6 (bonus por adelantamientos; ejecutado en los replays).
L 9D37 Score_HitLoop
L 9D41 Score_HitCap
L 9D51 Hud_TxtPopup
D 9D51 9D56 t
; 9D51 texto de puntos emergente (5 caracteres + fin)
L 9D57 Hud_TxtHi
D 9D57 9D58 t
L 9D59 Hud_TxtLo
D 9D59 9D5A t
L 9D5B Hud_TxtStage
D 9D5B 9D61 t
L 9D61 Hud_TxtStageNum

# ---------------------------------------------------------------- HUD
L 9D62 Hud_Update
> 9D62 Actualiza el marcador en la pantalla Spectrum (4000), cada cuadro de juego:
> 9D62  - "STAGE n" en #4486 (una sola vez, vA223 = cache).
> 9D62  - texto de puntos emergente en #4168 (5x7) si vA22C; parpadeo de sus atributos #5868
> 9D62    con vA22D (8 cuadros, colores #42/#46).
> 9D62  - marcha "LO"/"HI" en #448E cuando cambia vA253 (cache vA174).
> 9D62  - si vA22E & vA235: parpadeo de atributos en #5820 y #583B (5x4).
> 9D62  - iconos de turbo (vA170) en el buffer trasero, con animacion si vA24E.
> 9D62  - velocidad (3 digitos grandes, #4132), tiempo (2, #412F), distancia (4, #4191) y
> 9D62    marcador (8, #4126); estos tres ultimos solo redibujan los digitos que cambian.
L 9D7C Hud_Popup
L 9D8D Hud_PopupClear
L 9D9B Hud_PopupPtr
L 9DA5 Hud_PopupBlink
L 9DAC Hud_PopupAttr
L 9DBA Hud_PopupAttrSet
L 9DBF Hud_PopupAttrLoop
L 9DC3 Hud_Gear
L 9DD9 Hud_GearPrint
L 9DDC Hud_Flash
L 9DF4 Hud_FlashBlock
> 9DF4 Invierte el bit de brillo (#40) de un bloque de atributos de 5x4 en HL.
L 9DF7 Hud_FlashLoop
L 9E11 Hud_Turbos
> 9E11 Dibuja vA170 iconos de turbo (14 lineas x 2 bytes, pares mascara/dato, #38 bytes por
> 9E11 icono en #76F0) en el buffer F000 desde #FEE1 hacia arriba, cada uno 2 columnas a la
> 9E11 derecha. El ultimo se anima (3 fotogramas) mientras vA24E <> 0 (turbo activo (?)).
L 9E21 Hud_TurboAnim
L 9E29 Hud_TurboFrame
L 9E32 Hud_TurboMul
L 9E35 Hud_TurboDraw
L 9E3E Hud_TurboIcon
L 9E44 Hud_TurboLast
L 9E47 Hud_TurboIconGo
L 9E4E Hud_TurboLine
L 9E70 Hud_TurboNext
L 9E78 Hud_TurboRestSP
L 9E7B Hud_Speed
> 9E7B Velocidad: HL = vA24A * 82; imprime HL/10000, (HL/1000)%10, (HL/100)%10 con digitos
> 9E7B grandes, es decir km/h = velocidad * 0.82.
L 9E8A Hud_SpeedMul
L 9E8E Hud_SpeedMulNext
L 9E98 Hud_Speed10000
L 9EA2 Hud_Speed1000
L 9EAC Hud_Speed100
; 9EC5 tiempo restante BCD
; 9ED3 distancia (?) = vA189 + 256*vA199
; 9EE0 #10 = digito de millar a 1
L 9EE6 Hud_Dist100
L 9EE9 Hud_Dist100Loop
L 9EF7 Hud_Dist10
; 9F01 vA255 = decenas/unidades BCD, vA256 = millar/centenas
; 9F16 marcador
L 9F1E Hud_DrawBCD
> 9F1E Dibuja B bytes BCD (DE = byte mas significativo, bajando) con digitos grandes en DE'
> 9F1E solo donde el digito difiere de la cache (HL, un byte por digito, bajando).
L 9F2C Hud_DrawBCDLo
L 9F36 Hud_DrawBCDNext
L 9F3B Hud_DrawBCDHiPut
L 9F41 Hud_DrawBCDLoPut
L 9F47 Hud_BigDigit
> 9F47 Digito grande (8x15) A = 0..9 en la pantalla Spectrum en DE' (7 lineas en la fila de
> 9F47 DE' + 8 en la siguiente). Fuente en #DF62, 15 bytes por digito. Avanza E'.

# ---------------------------------------------------------------- impresion de texto
L 9F99 Txt_PrintAttr
> 9F99 Imprime texto con atributos: HL = texto (fin con bit 7), DE = pantalla, BC = direccion
> 9F99 de atributos, A = color, A' = modo. Se usa desde @8E6C (registros de texto de menus).
L 9FA3 Txt_Print
> 9FA3 Imprime texto en modo 1 (7 lineas, sin atributos). HL = texto, DE = pantalla 4000.
L 9FA6 Txt_PrintLoop
L 9FB4 Txt_PutChar
> 9FB4 Imprime un caracter (A, ASCII). Espacio = avanzar. Fuente 8x7 en #A27A (7 bytes por
> 9FB4 caracter): ! ( ) , .=0-4 (otros 21-2F tambien 4), 0-9=5-14, A-Z=15-40.
> 9FB4 Modo (A'): 1 normal (@A0AD), 2 9 lineas con lineas vacias arriba/abajo + atributo (@A083),
> 9FB4 3 doble altura + atributos en 2 filas (@A03D), 4 inverso (@A031), 5/6 en A001-A030.
L 9FBD Txt_MapChar
L 9FDF Txt_MapSub
L 9FE1 Txt_Glyph
L 90F1 Obj_SpanClipY
L 9115 Obj_SpanJump
; 9115 JR automodificado a la cadena @9117 (anchura de la banda)
