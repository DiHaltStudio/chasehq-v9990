# 00_map.ctl -- mapa de memoria general y ficheros fuente
#
# La imagen (MSX/orig/image.bin) es la memoria justo tras la carga de cinta.
# Coincide con la memoria en ejecucion salvo en: la pantalla 4000-5AFF, el bloque
# de nivel 5C00-76EF (se recarga por nivel) y las zonas E834-FFFF, donde el codigo
# de inicializacion (se ejecuta una vez desde E810) queda despues machacado por
# tablas y por el buffer trasero F000-FFFF.

F 3300 3FFF msx
F 4000 5BFF screen
F 5C00 76EF level
F 76F0 FFFF game

# ---------------------------------------------------------------- capa MSX
L 3300 RoadEdge_MSX
> 3300 Rutina de bordes de carretera por linea (copiada por el cargador CM desde 868C).
> 3300 Vuelve siempre a la rutina de relleno de carretera (@C666 / @C686).
L 3400 TapeLoader
> 3400 Cargador de cinta "a la Spectrum" (LD-BYTES) sobre TAPION/TAPIN de la BIOS.
L 3500 Start
> 3500 Punto de entrada tras la carga (el cargador CM hace JP aqui).
> 3500 Salta por la tabla de @5B85 a la inicializacion en @E810.
L 3527 VDP_SetBorder
L 3C15 VDP_DumpScreen
> 3C15 Volcado completo de la pantalla Spectrum (4000) a SCREEN 2: 6144 bytes de
> 3C15 patrones + atributos traducidos y repetidos x8 (12288 OUT). Se usa en carrera.
L 370C VDP_DumpWindow
> 370C Volcado de la ventana de juego (16x30 caracteres). No se usa en carrera.
L 3BDE VDP_WinRowTable
L 3C6A VDP_SetColors
L 357F ReadAnyKey
L 3590 ReadJoystick

# ---------------------------------------------------------------- pantalla y restos Spectrum
L 4000 ZXScreen
> 4000 Pantalla con formato Spectrum: 6144 bytes de bitmap + 768 de atributos.
> 4000 Al cargar contiene la pantalla de presentacion.
D 4000 57FF g 32
L 5800 ZXAttrs
D 5800 5AFF b
L 5B00 ZX_Relocator
> 5B00 Restos del cargador de la version Spectrum 128K (reubicacion con LDDR y
> 5B00 paginacion por 7FFD). En MSX no se ejecuta: la imagen ya viene reubicada.
D 5B00 5B74 b
L 5B75 JumpViaTable
L 5B85 StartVector
D 5B85 5B86 a

# ---------------------------------------------------------------- nivel
L 5C00 LevelData
> 5C00 Bloque de nivel: 0x1AF0 bytes, se recargan de cinta en cada nivel (rutina @8030).
D 5C00 76EF b

# ---------------------------------------------------------------- arranque
L E810 Init
> E810 Inicializacion (se ejecuta una vez). Todo E834-FFFF se reutiliza despues como
> E810 tablas de carretera (E9FE...) y buffer trasero (F000-FFFF).
