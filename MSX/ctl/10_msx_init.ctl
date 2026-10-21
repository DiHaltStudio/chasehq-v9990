# 10_msx_init.ctl -- capa MSX (3300-3FFF) e inicializacion/menu (E810-FFFF)
#
# Etiquetas ya definidas en 00_map.ctl (no se redefinen aqui): 3300 3400 3500 3527
# 370C 3BDE 3C15 3C6A 357F 3590 E810.

# ======================================================================== 3300 bordes de carretera
> 3300 Hay 9 variantes (3 tramos de relleno x 3 tipos). Todas reciben DE = destino en el
> 3300 buffer trasero (F000-FFFF) y HL = entrada de tabla de mascara/dato, y saltan de vuelta
> 3300 a una direccion fija del bucle de relleno. El codigo Spectrum original estaba en linea
> 3300 (quedan restos en @C65F); el port MSX lo saco aqui para anadir una guarda: si DE >= FFFE
> 3300 no se escribe nada (evita que LDI/INC E desborden de FFFF a 0000, que en MSX es RAM (?)).
> 3300 Tipo MaskSolid: (DE) = (DE) AND (HL) OR (HL+1); luego LDI desde HL+3 (byte macizo).
; 3305 guarda: DE >= FFFE -> no escribir
L 3316 RoadEdge1_Solid2
> 3316 Tipo Solid2: LDI y repite el byte siguiente: dos bytes macizos. Vuelve a @C686.
L 3326 RoadEdge1_SolidMask
> 3326 Tipo SolidMask: LDI (macizo) y despues byte enmascarado AND/OR. Vuelve a @C6AA.
L 3339 RoadEdge2_MaskSolid
> 3339 Igual que @RoadEdge_MSX para el segundo tramo de relleno (vuelve a @CA8F).
L 334F RoadEdge2_Solid2
> 334F Igual que @RoadEdge1_Solid2, segundo tramo (vuelve a @CAAC).
L 335F RoadEdge2_SolidMask
> 335F Igual que @RoadEdge1_SolidMask, segundo tramo (vuelve a @CACD).
L 3372 RoadEdge3_MaskSolid
> 3372 Igual que @RoadEdge_MSX, tercer tramo (vuelve a @CAF1).
L 3388 RoadEdge3_Solid2
> 3388 Igual que @RoadEdge1_Solid2, tercer tramo (vuelve a @CB0E).
L 3398 RoadEdge3_SolidMask
> 3398 Igual que @RoadEdge1_SolidMask, tercer tramo (vuelve a @CB2E).

# ======================================================================== 3400 cargador de cinta
> 3400 Entrada: IX = destino, DE = longitud. Espera bloque con byte de bandera FF.
> 3400 Salida: CF=1 si la carga fue correcta (convenio LD-BYTES del Spectrum).
> 3400 Al terminar apaga el motor (PPI puerto C bit 4 = 1) y pone el borde negro (R#7=0).
> 3400 Lo usa el juego para cargar cada nivel (@80C0: IX=5C00, DE=1AF0).
; 3407 PPI: bit 4 de puerto C a 1 = motor del cassette parado
; 340B R#7 = 0 (color de borde)
L 3415 Tape_LdBytes
> 3415 Nucleo de carga. Guarda en la pila los 24 bytes FC8E-FCA5 (zona del buffer trasero
> 3415 que se va a usar como pila de la BIOS, trampolin y LOWLIM/WINWID) y construye en
> 3415 FC9A un trampolin: OUT (C),L (pagina 0 -> slot de BIOS) / EXX / CALL 00E1 / EXX /
> 3415 OUT (C),H (restaura slots) / RET. El byte FC9E (bajo de la direccion del CALL) se
> 3415 cambia a E4 (TAPIN) y al final a F3 (STMOTR con A=0, parar motor).
> 3415 Los bytes que caen en FC8E-FCA5 se escriben en la copia guardada en la pila.
; 341B copia de seguridad de FC8E-FCA5 (12 palabras) en la pila
; 342E codigo del trampolin, apilado de abajo arriba en FC9A-FCA3
; 3446 H = valor actual del registro de slots (puerto A8)
; 3448 A = FC AND H: pagina 0 al slot 0 (BIOS); resto igual
; 344A CALL 00E1 = TAPION (leer cabecera)
; 344F a partir de aqui el trampolin llama a TAPIN (00E4)
; 3459 primer byte = bandera, debe coincidir con A' (FF)
L 3461 Tape_StoreByte
> 3461 Guarda el byte leido en (IX). Si IX cae en FC8E-FCA5 lo escribe en la copia
> 3461 apilada (se restaura al final).
L 347D Tape_NextByte
; 3483 B = XOR acumulado (paridad)
; 3485 borde = byte bajo del contador DE (rayas de carga)
; 3488 Z si DE = 0 (OR D; OUT/LD no tocan los flags)
L 3490 Tape_End
; 3490 A = FF si error de TAPIN, OR paridad: 0 = correcto
; 3493 STMOTR (00F3) con A=0: motor parado
; 349F restaura FC8E-FCA5
; 34B0 CF=1 si A=0 (todo bien)
D 34B3 34B7 b
> 34B3 Bytes sobrantes (resto de una version anterior: ADD A,A / OUT (99),A / SCF / RET).
L 34B8 Tape_Boot
C 34B8
> 34B8 Arranque del cargador CM (no aparece en las trazas: se ejecuta antes de la imagen).
> 34B8 Carga 3500 (2600 bytes, incluye la pantalla de presentacion 4000-5AFF), la vuelca al
> 34B8 TMS, carga 5B00 (5280) y AD80 (527F) y salta a @Start.
D 34DB 34E5 b
> 34DB Relleno.

# ======================================================================== 3500 arranque y utilidades
L 350A Util_Delay
> 350A Retardo fijo: 256 x 6 x EX (SP),IX ~ 38.700 T (~10,8 ms a 3,58 MHz). Destruye B.
L 351B VDP_Dump9965
C 351B
> 351B Sin referencias: CALL @9965 y volcado completo. Igual @VDP_Dump99D3 con @99D3.
> 351B Parecen pensadas para el final (bloque del nivel 6, en 5C00), que llama a 9965 (en
> 351B 5C3B) y a 99D3 (en 5C58 y 5C69). Pero ese bloque es el del Spectrum sin tocar (identico
> 351B byte a byte a zx/x48/12 y zx/x128/07): nunca llama a estas rutinas, y en MSX el final se
> 351B cuelga (ver docs/10_nivel.md, "Nivel 6").
L 3521 VDP_Dump99D3
C 3521
> 3527 Sustituye al OUT (FE) del Spectrum. Ignora A: siempre pone R#7 = 01 (borde negro).
> 3527 El IN (99) previo reinicia el biestable de direccion del VDP. Sale con A=0.
L 3533 vVDPWinMode
> 3533 0 = el proximo @VDP_Present hara volcado completo; 1 = solo ventana de juego.
D 3533 3533 b
L 3534 VDP_PresentFull
> 3534 Copia el buffer trasero a la pantalla Spectrum (@BC3E: F000 -> 4000) y vuelca la
> 3534 pantalla entera al TMS. Pone @vVDPWinMode = 0. Se usa en transiciones (@85B7, bucle
> 3534 de fundido) y en @80A5/@82A0.
L 353E VDP_Present
> 353E Presentacion de un frame de juego (llamada desde el bucle principal @84BC).
> 353E Si @vVDPWinMode = 1: volcado de la ventana directamente desde el buffer F000
> 353E (@VDP_DumpWindow, que acaba en @VDP_SetColors) y despues @BD5A.
> 353E Si es 0: primer frame tras una pantalla completa: copia F000->4000, volcado completo
> 353E y calcula el estado inicial del seguimiento del horizonte para @VDP_SetColors.
L 354B VDP_PresentFirst
; 3556 D = 67: byte alto de la direccion VRAM de la tabla de color (fila 7) con bit 6
; 3558 atributo de fila 8, columna 1 (primera linea de la ventana)
; 3564 baja mientras el papel (bits 5-3) sea el mismo que el de la fila 8 (cielo)
; 356E atributo completo de la primera fila distinta (suelo) -> @VDP_GroundAttr
; 3572 papel del cielo (tinta 0) -> @VDP_SkyAttr
; 3577 C=08, B=67+n: direccion VRAM 2x08 de la ultima fila de cielo
; 357B HL = atributo de la ultima fila de cielo

> 357F Lee las filas 8..0 de la matriz de teclado. Sale con NZ (A = bits pulsados a 1) si
> 357F hay alguna tecla pulsada, Z si ninguna. OUT (AA) escribe tambien bits 4-7 = 0
> 357F (motor de cassette ON, LED CAPS encendido, clic a 0): efecto lateral de todo el juego.
> 3590 Lee el joystick del puerto 1 por el PSG y lo devuelve en formato Kempston (1 = pulsado):
> 3590 bit0 derecha, bit1 izquierda, bit2 abajo, bit3 arriba, bit4 disparo A, bits 5-7 = 0.
> 3590 R15: puerto 1, pines 6/7 a 1. El boton B (bit 5 de R14) se ignora.
; 35A6 bits 4-5 = disparos A/B; fuerza 1 en bits 5-7 (B no cuenta)
; 35AE la tabla invierte el orden de los 4 bits de direccion
L 35BE tJoyBitRev
D 35BE 35CD b
> 35BE Inversion de 4 bits: arriba/abajo/izq/der (bits 0-3 de R14) -> orden Kempston.

# ======================================================================== 35CE redefinir teclas (MSX)
L 35CE Kbd_RedefineKeys
> 35CE Redefinicion de las 8 teclas (opcion 2 del menu; ejecutada en el replay
> 35CE chasehq_firststage, t=72-81 s).
> 35CE Lee 8 teclas en orden GEAR, ACCELERATE, BRAKE, LEFT, RIGHT, QUIT, PAUSE, TURBO y
> 35CE guarda sus codigos en @tKeyDefs. Tras cada tecla escribe su nombre en la pantalla
> 35CE Spectrum (@MenuTxt_Print con @tKeyNameRec) y hace volcado completo.
> 35CE Codigo de tecla: bits 7-4 = bit+1, bits 3-0 = fila de la matriz.
; 35D7 borra la marca "ya usada" (bit 7) de las 72 teclas
L 35E3 Kbd_RedefLoop
; 35E4 posicion de pantalla del nombre (de @tRedefKeyPos)
; 35F9 >= 19: caracter imprimible directo
; 3602 < 19: nombre de dos letras de @tKeySpecialNames
L 3627 Kbd_WaitNewKey
> 3627 Espera una tecla no usada (mientras no hay ninguna, toca la musica @Mus_Tick).
> 3627 Guarda su codigo en (@vRedefPtr), avanza el puntero, la marca como usada y deja en
> 3627 @vKeyCharIdx su caracter/indice.
; 362C D = fila, E = indice fila*8+bit
L 3653 Kbd_GotKey
; 3653 9-B = numero de bit + 1
; 366D tecla ya usada: volver a esperar
L 367A vRedefPtr
D 367A 367B w
> 367A Puntero de escritura en @tKeyDefs durante la redefinicion.
L 367C tKeyMatrixChars
D 367C 36C2 t
> 367C 72 entradas (9 filas x 8 bits) de la matriz MSX: caracter ASCII, o 01-17 = indice
> 367C en @tKeySpecialNames. El bit 7 marca tecla ya asignada.
L 36C3 tKeySpecialNames
D 36C3 36F3 t
> 36C3 Nombres de 2 letras (castellano) de las teclas especiales, indexados por 1..17:
> 36C3 SH CT GR CA CO F1-F5 ES TA ST BS SE RE SP HO IN DE IZ AR AB DE. El primer byte no se usa.
L 36F4 vKeyCharIdx
D 36F4 36F4 b
L 36F5 tKeyNameRec
D 36F5 36FB b
> 36F5 Registro de texto (formato @MenuTxt_Print) que se rellena con la posicion y el nombre.
L 36FC tRedefKeyPos
D 36FC 370B w
> 36FC Direcciones de pantalla Spectrum donde se escribe el nombre de cada una de las 8 teclas.

# ======================================================================== 370C volcados al TMS
> 370C 16 filas de caracter x 30 columnas x 8 bytes = 3840 OUT (solo patrones), leidos
> 370C DIRECTAMENTE del buffer trasero F000 (no de 4000) mediante la tabla @VDP_WinRowTable
> 370C (via SP). Destino VRAM 0808 + n*100 (filas de caracter 8..23, columnas 1..30).
> 370C Termina saltando a @VDP_SetColors. Usa @BDBE para guardar SP. Si se usa en carrera:
> 370C @VDP_Present la llama en todos los frames salvo el primero tras una pantalla completa.
; 3713 lee el estado del VDP: reinicia el biestable de direccion
; 3717 D se incrementa antes de cada fila: primera fila en VRAM 0808
> 3BDE Direccion de origen en el buffer para cada fila de pantalla (columna 1): F001, F801,
> 3BDE F021, F821... -> las filas pares de pantalla vienen de F0xx y las impares de F8xx.
D 3BDE 3BFD w
L 3BFE VDP_DumpScreenSafe
C 3BFE
> 3BFE Sin referencias reales (la de @7273 es dato). Volcado completo guardando todos los
> 3BFE registros, con pila temporal en 0400.
> 3C15 Patrones: VRAM 0000, recorre 4000-57FF en orden TMS (8 lineas de una celda y celda
> 3C15 siguiente). Colores: VRAM 2000, cada atributo traducido por @tAttrToTMS y repetido 8 veces.
> 3C15 Tambien se usa en el menu y al cargar (@Tape_Boot).
; 3C1D R#1 de escritura en VRAM 0000 (40 = bit de escritura)
; 3C55 VRAM 2000: tabla de colores
> 3C6A Actualizacion parcial tras @VDP_DumpWindow (todo lo que no es la ventana):
> 3C6A 1) si el bit BRIGHT de los atributos 5820 y 583B difiere, recolorea los bloques de 4x4
> 3C6A    celdas de filas 1-4, columnas 0-3 y 27-30 (luces de sirena (?)).
> 3C6A 2) horizonte: sigue la frontera entre papel 5 (cielo, 28) y papel 6 (suelo, 30) en la
> 3C6A    ventana; si se movio una fila, reescribe los 240 colores de esa fila (maximo 1 por frame).
> 3C6A 3) @VDP_UpdateHUD: patrones de filas 6-7 y partes del marcador por turnos.
; 3C6C D = 3F: pagina de @tAttrToTMS (B=3F para LD A,(BC))
; 3C7B VRAM 2100: color fila 1, columna 0
; 3C86 VRAM 21D8: color fila 1, columna 27
L 3C8E VDP_Horizon
L 3C91 VDP_HorizonVram
; 3C91 C,B = direccion VRAM (con bit 6) de la fila de color del horizonte (automodificado)
L 3C94 VDP_HorizonAttr
; 3C94 atributo (columna 1) de la ultima fila de cielo (automodificado)
; 3C9A sigue siendo cielo?
; 3C9E no: el horizonte subio una fila -> pintar esta fila con color de suelo
L 3CAB VDP_GroundAttr
; 3CAB atributo de suelo (lo pone @VDP_PresentFirst)
L 3CB0 VDP_HorizonDown
; 3CB4 la fila siguiente es suelo: sin cambios
L 3CC1 VDP_SkyAttr
; 3CC1 atributo de cielo (lo pone @VDP_PresentFirst)
L 3CC3 VDP_FillColorRow
> 3CC3 Escribe 30 x 8 bytes del color traducido de E en la fila de color BC.
L 3CF5 VDP_UpdateHUD
> 3CF5 Patrones de pantalla fuera de la ventana: siempre filas 6-7 (60 celdas desde 40C1 a
> 3CF5 VRAM 0608). Bloque filas 1-5, columnas 22-25 (icono del marcador (?)) si su atributo 5836
> 3CF5 es distinto de 0 o lo fue en el frame anterior (@vHUDIconShown). Y por turnos de 4
> 3CF5 frames (@vHUDPhase): fase 0 filas 4-5 col 14-20; fase 1 filas 1-2 col 6-20.
; 3D0D VRAM 21B0: color fila 1, columna 22 (5 filas)
L 3D48 VDP_HUDPhase
L 3D6C VDP_HUDPhase0
L 3D7C VDP_CopyCells
> 3D7C Copia B celdas de patrones (8 bytes cada una, lineas Spectrum H..H+7) desde HL (pantalla
> 3D7C 4000) a la VRAM DE (con bit 6 de escritura). Avanza L.
L 3DAF vHUDPhase
D 3DAF 3DAF b
L 3DB0 vHUDIconShown
D 3DB0 3DB0 b
L 3DB1 VDP_CopyColors5
L 3DB3 VDP_CopyColors
> 3DB3 A filas x 4 celdas de color: traduce los atributos desde HL (B = 3F, tabla
> 3DB3 @tAttrToTMS) y escribe 32 bytes en la VRAM DE; D++ y L+=32 por fila.
> 3DB3 Los INC L intercalados son relleno de tiempo pero cuentan: 32 por fila.
D 3E63 3EFF b
> 3E63 Sin uso: contenido de RAM sin inicializar (patron 00/FF).
L 3F00 tAttrToTMS
D 3F00 3FFF b
> 3F00 Traduccion atributo Spectrum -> byte de color TMS (tinta<<4 | papel), indexada por el
> 3F00 atributo completo; FLASH se ignora (80-FF = 00-7F). Colores (normal / BRIGHT):
> 3F00 0 negro 1/1, 1 azul 4/5, 2 rojo 6/8, 3 magenta D/D, 4 verde C/3, 5 cian 7/7,
> 3F00 6 amarillo A/B, 7 blanco E/F.

# ======================================================================== E810 inicializacion
> E810 Entrada MSX/48K: A=0 (hay menu), B=3 entradas de la tabla de copia.
L E816 Init_128K
C E816
> E816 Entrada alternativa (version Spectrum 128K, sin uso en MSX): borra pantalla (@88D5),
> E816 A=1 (sin menu, @A139=1) y copia las 5 entradas de @tInitCopy.
L E81D Init_Common
; E81D A=0 en MSX: desactiva los caminos exclusivos del 128K (@8193/@81AA)
; E820 pila temporal en lo alto de la memoria
; E824 pantalla de titulo (logo): 0x800 bytes -> tercio superior 4000-47FF
; E82F y 0x100 atributos -> 5800-58FF
L E83D Init_CopyLoop
; E852 pila definitiva del juego
L E858 tInitCopy
D E858 E875 w
> E858 Tabla de copia: (origen, destino, longitud). En MSX solo se usan las 3 primeras:
> E858 E88E->EC00 (18), E8A6->EB00 (28), E8CE->EA00 (30). Las 2 ultimas (F220->8014 39E,
> E858 E876->83B5 18) son de la version 128K.
L E876 tJump128K
D E876 E88D b
> E876 8 JP (8045 805D 8091 8096 80E5 80EE 8136 820F) que el 128K copiaba en 83B5.
L E88E tFxTable
D E88E E8A5 b
> E88E Se copia a EC00. Efectos de fundido (rutina @8DF9/@8D8F): 8 entradas de 3 bytes
> E88E (numero de pasos, direccion de la trama - 8). EC00: 4 efectos con paso +8; EC0C: los
> E88E mismos 4 recorridos al reves (paso -8). Tramas en EB00, E35C, E3B4 y EA00.
L E8A6 tFxBlobs
D E8A6 E8CD g 1
> E8A6 Se copia a EB00: 5 tramas 8x8 de cuadrados crecientes para el fundido.
L E8CE tFxCross
D E8CE E8FD g 1
> E8CE Se copia a EA00: 6 tramas 8x8 en forma de X cada vez mas gruesas para el fundido.

# ======================================================================== E8FE menu
L E8FE Menu
> E8FE Menu (se ejecuta una vez, desde @Init). Instala IM 2, inicia la musica del titulo,
> E8FE muestra "STOP THE TAPE / PRESS ANY KEY" y espera pulsar y soltar una tecla.
> E8FE Menu principal: tecla 0 = teclado, 1 = joystick puerto 1, 2 = redefinir teclas.
> E8FE Tras elegir 0/1 pide confirmacion (Y/N). Las interrupciones quedan deshabilitadas.
; E905 aqui el Spectrum tendria EI (anulado)
L E912 Menu_WaitPress
L E91A Menu_WaitRelease
; E920 NOPs: codigo Spectrum anulado
L E925 Menu_Main
L E931 Menu_MainLoop
; E934 fila 0 de la matriz: teclas 0,1,2 en bits 0-2
; E944 NOPs: codigo Spectrum anulado
D E94B E95A b
> E94B Restos Spectrum (no se ejecutan): LD HL,EE26 / LD HL,EE2B / LD DE,EE38 / LD BC,5 /
> E94B LDIR = cargar las teclas predefinidas de @tSpecKeyPresets.
L E95B Menu_SelKeyboard
L E95C Menu_SetControl
> E95C A = tipo de control (0 teclado, 1 joystick) -> A0CC. Copia las teclas: A0CD-A0CF <-
> E95C QUIT, PAUSE, TURBO (@tKeyDefs+5) y A0D0-A0D4 <- GEAR, ACCEL, BRAKE, LEFT, RIGHT.
L E97C Menu_Confirm
; E97F fila 4 bit 3 = N: volver al menu
; E989 fila 5 bit 6 = Y: aceptar
D E998 E99A b
L E99B Menu_Exit
L E99F Menu_SelJoystick
; E99F NOPs: deteccion Kempston del Spectrum anulada
L E9B4 tTxtStopTape
D E9B4 EBF6 t
> E9B4 Textos. Formato de registro (@MenuTxt_Print): byte de atributo (bit 7 = 1: altura simple;
> E9B4 0: doble altura), direccion de pantalla Spectrum (2 bytes), texto con bit 7 en el
> E9B4 ultimo caracter. Una lista termina con 00.
L E9E1 tTxtMainMenu
L EA52 tTxtRedefine
L EADC tTxtSpecKeyRec
> EADC Registro usado por el codigo Spectrum muerto (@ED02).
L EAE1 tTxtTestMode
> EAE1 Menu de trucos "TEST MODE" (RESTART LEVEL, NEXT LEVEL, END SCREEN, EXTRA CREDIT):
> EAE1 solo accesible desde el codigo Spectrum muerto. EB00-EB27 queda machacado por @tFxBlobs.
L EB78 tTxtConfirm

# ======================================================================== EBF7 impresion de texto
L EBF7 MenuTxt_Print
> EBF7 Imprime una lista de registros de texto (ver @tTxtStopTape) en la pantalla Spectrum
> EBF7 4000 hasta encontrar 00. Entrada HL. Usa los registros alternativos.
L EBFF MenuTxt_PrintRec
> EBFF Un registro. Atributo con bit 7 = 0: letras de 8x16 (cada linea de la fuente se repite
> EBFF dos veces; celda superior con BRIGHT, inferior sin BRIGHT). Bit 7 = 1: letras 8x7.
; EC02 F' (carry) = modo altura simple
; EC0B direccion de atributos a partir de la de pantalla
L EC2C MenuTxt_Char
> EC2C Fuente de 7 bytes por caracter en A27A: indice 0 '!', 1 '(', 2 ')', 3 ',', 4 otros
> EC2C (p.ej. '.'), 5-14 '0'-'9', 15-40 'A'-'Z'. El espacio solo avanza.
L EC57 MenuTxt_CharIdx
L EC59 MenuTxt_CharAddr
L ECBA MenuTxt_CharSmall

L ECDA Scr_ClearLower
> ECDA Borra los dos tercios inferiores de la pantalla Spectrum (4800-57FF y atributos
> ECDA 5900-5AFF a 0). El tercio superior (logo del titulo) se conserva.
L ECF3 Menu_Redefine
> ECF3 Opcion 2: pantalla REDEFINE KEYS y @Kbd_RedefineKeys.

# ======================================================================== ED02 restos Spectrum
D ED02 EDD6 b
> ED02 Codigo Spectrum muerto (lee el teclado por el puerto FE): redefinicion de teclas
> ED02 original y truco: compara las teclas definidas con @tCheatCode y, si coinciden, pone
> ED02 (8000)=1 y muestra @tTxtTestMode. En ejecucion ED28 es la cima de la pila y gran
> ED02 parte de EDxx/EExx se reutiliza como tablas.
L ED28 StackTop
> ED28 Cima de la pila del juego (@Init, y recargada por @8F5F/@A95F/@A9E2); crece hacia
> ED28 abajo sobre codigo muerto (ED0C-ED27 cambia en las trazas).
L EDD7 tSpecKeyNames
D EDD7 EE25 t
> EDD7 Nombres de teclas del Spectrum (2 caracteres por tecla, orden de semifilas). Muerto.
L EE26 tSpecKeyPresets
D EE26 EE2F b
> EE26 Dos juegos de 5 teclas predefinidas (codificacion Spectrum). Muerto.
L EE30 tCheatCode
D EE30 EE37 b
> EE30 Secuencia de 8 teclas (codificacion Spectrum) del truco TEST MODE. Muerto en MSX.
L EE38 tKeyDefs
D EE38 EE3F b
> EE38 Teclas definidas (codigo MSX: bits 7-4 = bit+1, 3-0 = fila). Por defecto:
> EE38 GEAR N, ACCELERATE A, BRAKE Z, LEFT K, RIGHT L, QUIT Q, PAUSE P, TURBO espacio.

# ======================================================================== EE40 interrupciones y musica
L EE40 Int_Setup
> EE40 DI, tabla de vectores IM 2 en FD00-FE00 (todo FE), I = FD, IM 2, y en FEFE un
> EE40 JP @Int_Handler. El juego nunca ejecuta EI: las
> EE40 interrupciones estan siempre deshabilitadas y esto no tiene efecto. La tabla queda
> EE40 dentro del buffer trasero y se machaca en carrera.
L EE5E Mus_Init
> EE5E Inicia la musica del titulo (bateria por beeper) en @tMusSeq.
L EE6E Mus_SeqNext
> EE6E Fin de patron: decrementa las repeticiones; al llegar a 0 lee la siguiente entrada.
L EE75 Mus_SeqPtr
L EE78 Mus_SeqRead
> EE78 Entrada de secuencia: (repeticiones, desplazamiento de patron en @tMusPatterns);
> EE78 FF lo,hi = saltar (bucle). El primer byte del patron es el tempo (ticks por fila).
L EE98 Mus_SeqJump
L EE9E Mus_Tick
> EE9E Un tick de musica (se llama en todos los bucles de espera del menu). Cuando vence el
> EE9E tempo procesa la fila siguiente del patron; siempre termina con @Util_Delay.
> EE9E Byte de fila: 01 = fin de patron; bit 7 = fila de 1 tick (?); bits 6-3 = parametro;
> EE9E bits 2-0 = instrumento: 0 silencio, 1 muestra B, 2 muestra A, 3 ruido (@Mus_Noise).
> EE9E Sale con A=FF, NZ.
L EEA2 Mus_FirstFlag
L EEAD Mus_TickCount
L EEB9 Mus_Tempo
L EEBE Mus_RowPtr
L EEC9 Mus_PatStart
L EED2 Mus_Row
L EF00 Mus_Short
L EF0D Mus_SampleActive
L EF13 Mus_Wait
L EF14 vMusBreak
> EF14 Instruccion NOP usada como bandera de corte de la musica (siempre 0 en MSX). En el
> EF14 Spectrum la pondria a FF la interrupcion (ver bytes en EF1D) (?).
L EF19 Int_Handler
> EF19 Destino del vector IM 2 y final de @Mus_Tick: A=FF, NZ, RET (sin EI).
D EF1D EF21 b
> EF1D Restos: LD (EF14),A / POP AF / EI / RET (antigua rutina de interrupcion (?)).
L EF22 Mus_SampleB
L EF29 Mus_SampleA
L EF39 Mus_PlaySample
> EF39 Reproduce una muestra de 1 bit por el clic de teclado (PPI puerto C bit 7, OUT AA).
> EF39 HL = muestra, D = bytes, el parametro de la fila (bits 6-3) = bits por byte (8 normal);
> EF39 RLC (HL) rota los datos (con menos de 8 bits la muestra queda rotada).
L EF57 Mus_SampleEnd
L EF5E tSampleA
D EF5E F059 b
> EF5E Muestra A (FC bytes, 1 bit por muestra).
L F05A tSampleB
D F05A F0C5 b
> F05A Muestra B (6C bytes).
L F0C6 Mus_Noise
> F0C6 Ruido por el clic de teclado con el generador aleatorio de 9618: E pasadas (E = parametro)
> F0C6 de 50 pulsos, anchura de pulso E, que decrece.
L F0FE tMusSeq
D F0FE F110 b
> F0FE Secuencia: (01,29) intro, (01,2C), (04,00), (04,71), (04,91), (04,AD), (07,CD), (01,ED),
> F0FE FF -> F100 (bucle sin la intro).
L F111 tMusPatterns
D F111 F21F b

# ======================================================================== F220 datos de inicializacion
L F220 tCode128K
D F220 F5BD b
> F220 Codigo de la version 128K para 8014-83B1 (39E bytes). No se copia en MSX.
L F5BE tTitleBitmap
D F5BE FDBD g 32
> F5BE Logo del titulo: tercio superior de pantalla Spectrum (copiado a 4000).
L FDBE tTitleAttrs
D FDBE FEBD b
> FDBE Atributos del logo (copiados a 5800).
D FEBE FFFF b
> FEBE Basura: ceros, JP 0019 en FEFE (se reescribe con el vector IM 2) y restos de una fuente.
