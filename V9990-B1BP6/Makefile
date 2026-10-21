# Chase H.Q. para V9990 (B1/BP6). Ejecutar desde esta carpeta.
#
#   make            igual que "make build"
#   make build      ensambla las ROM de esta carpeta en build/
#   make run        abre la ROM en openMSX: MSX1 Sony HB-10P + GFX9000
#   make run-turbor igual en un MSX turbo R (Panasonic FS-A1GT) + GFX9000
#   make clean      borra build/
#
# "run" abre la ROM del port (build/chasehq_v9990.rom), aun incompleta: ver doc/04_port.md.
# Prototipos: make run GAME=build/road.rom (nucleo de dibujo) o GAME=build/split.rom
# Otros: make port-test (juega el port con una partida grabada), make road-test (fps y
# estabilidad del prototipo), make bench (medidas del blitter),
# make split-test (estabilidad de la particion sola).
# Variables: SJASM, OPENMSX, MACHINE, TURBOR, GAME.

SJASM   ?= sjasm
OPENMSX ?= openmsx
MACHINE ?= Sony_HB-10P
TURBOR  ?= Panasonic_FS-A1GT
GAME    ?= build/chasehq_v9990.rom

ROMS     = build/chasehq_v9990.rom build/road.rom build/split.rom build/bench.rom
# La fuente de video GFX9000 aun no existe cuando openMSX procesa -command: se elige
# al arrancar la maquina ("after boot").
V9FLAGS  = -ext gfx9000 -command "after boot {set videosource GFX9000}"

.PHONY: all build clean run run-turbor bench split-test road-test port-test \
        palette palette-sync palette-import palette-check test-rom ending-rom ending ending-reset diag-rom manual FORCE sheets-reset hud-reset strips-reset radio-reset mountains-reset digits-reset title-reset menubg-reset monitor-reset preview frames

all: build

build: $(ROMS)

# --- ROM del port: imagen del original (../MSX) + parches + codigo del V9990
# Graficos y sonidos: assets/editable/ son las fuentes que se retocan (las lee el build);
# assets/noneditable/ lo generado, capturado o intermedio (no se toca a mano).
ED      = assets/editable
NE      = assets/noneditable
PORT_SRC = src/port.asm src/cheats.asm src/v9.asm src/rom.asm src/bridge_v9.asm ../MSX/rom/bridge.asm \
           ../MSX/rom/findram.inc tools/mkstrips.py tools/mksprites.py tools/sprextract.py tools/mkhud.py tools/mkpal.py tools/v9pal.py tools/mkintro.py tools/chkmem.py tools/mksound.py tools/mkradio.py tools/mkmountains.py tools/mkdigits.py tools/mktitle.py tools/mkmenubg.py tools/mkmonitor.py tools/mkending.py src/sound.asm src/title.asm src/ending.asm src/dark.asm $(wildcard $(ED)/sound/*.vgm $(ED)/radio_*.png $(ED)/mountains.png $(ED)/hud_digits.png $(ED)/title_font.png $(ED)/menu_bg.png $(ED)/monitor.png $(ED)/ending/*.png) \
           $(ED)/intro/dihalt_logo-b1.png $(wildcard $(ED)/intro/opening-b3.png) \
           $(NE)/sprites_seen.json $(NE)/unscaled_seen.json \
           $(ED)/palette.gpl $(wildcard $(ED)/sheets/*.png $(ED)/hud_panel.png $(ED)/strips.png)

# ORIG_INPUT=1: ROM de pruebas, con el menu y la lectura de controles del original (las
# partidas grabadas se reproducen inyectando esas lecturas). Por defecto, 0.
ORIG_INPUT ?= 0
# CHEAT_ENDING=1: al dar a marcha en la portada, la secuencia final (make ending). Por defecto, 0.
CHEAT_ENDING ?= 0
# DIAG=1: ROM de diagnostico para la maquina real (make diag-rom): el color 0 de la paleta (el fondo) cambia
# en etapas del arranque de la carrera (src/v9.asm, DIAGCOL); el ultimo color que se ve dice donde se queda.
DIAG ?= 0
CONFIG = ORIG_INPUT equ $(ORIG_INPUT)\nCHEAT_ENDING equ $(CHEAT_ENDING)\nDIAG equ $(DIAG)
build/config.inc: FORCE
	@mkdir -p build
	@printf '$(CONFIG)\n' | cmp -s - $@ || printf '$(CONFIG)\n' > $@
FORCE:

# ROM que va derecha al final -> build/chasehq_v9990_ending.rom (y deja otra vez la normal); make ending la
# construye y la arranca en openMSX: en la portada, boton de marcha y empieza la secuencia final.
ending-rom:
	$(MAKE) CHEAT_ENDING=1 build/chasehq_v9990.rom
	cp build/chasehq_v9990.rom build/chasehq_v9990_ending.rom
	$(MAKE) CHEAT_ENDING=0 build/chasehq_v9990.rom

# Manual de usuario en PDF (doc/manual/manual-en.pdf y manual-es.pdf): imagenes de doc/img y de la portada
MANUAL_LANGS ?= en es
manual:
	python3 tools/manual_images.py ../docs/manual ..
	cd ../docs/manual && for l in $(MANUAL_LANGS); do \
	  for i in 1 2; do pdflatex -interaction=nonstopmode -jobname=manual-$$l "\def\manlang{$$l}\input{manual}" >/dev/null || exit 1; done; done

diag-rom:
	$(MAKE) DIAG=1 build/chasehq_v9990.rom
	cp build/chasehq_v9990.rom build/chasehq_v9990_diag.rom
	$(MAKE) DIAG=0 build/chasehq_v9990.rom

ending: ending-rom
	$(OPENMSX) -machine $(MACHINE) $(V9FLAGS) -carta build/chasehq_v9990_ending.rom $(ROMTYPE)

# ROM de pruebas -> build/chasehq_v9990_test.rom (y deja otra vez la normal)
test-rom:
	$(MAKE) ORIG_INPUT=1 build/chasehq_v9990.rom
	cp build/chasehq_v9990.rom build/chasehq_v9990_test.rom
	$(MAKE) ORIG_INPUT=0 build/chasehq_v9990.rom

build/chasehq_v9990.rom: $(PORT_SRC) build/config.inc
	@mkdir -p build
	python3 tools/mkpal.py --build
	python3 tools/mkstrips.py
	python3 tools/mksound.py
	python3 tools/mkradio.py
	python3 tools/mkmountains.py
	python3 tools/mkdigits.py
	python3 tools/mktitle.py
	python3 tools/mkmenubg.py
	python3 tools/mkmonitor.py
	@test -f build/sheets.inc || printf 'TV9Sheets:\n' > build/sheets.inc
	@test -s build/unscaled.inc || echo '; (se genera con tools/mksprites.py)' > build/unscaled.inc
	cd src && $(SJASM) bridge_v9.asm && $(SJASM) port.asm
	python3 tools/mksprites.py
	cd src && $(SJASM) port.asm
	python3 tools/mksprites.py
	python3 tools/mkending.py
	python3 tools/mkhud.py
	python3 tools/mkintro.py
	cd src && $(SJASM) rom.asm && mv -f *.lst ../build/
	python3 tools/chkmem.py || { rm -f $@; exit 1; }

# --- graficos editables (ver doc/05_graficos_editables.md)
# Todos los PNG editables (assets/editable/sheets/*.png, hud_panel.png y strips.png)
# llevan la misma paleta indexada de 64 colores, la de assets/editable/palette.gpl. El build la
# comprueba y falla si alguno no cuadra (make palette-check lo dice sin construir nada).
palette-check:
	python3 tools/mkpal.py --check

# palette.gpl manda: regenera las tablas del juego, la muestra assets/noneditable/palette.png y el
# bloque de paleta de todos los PNG editables (los indices de los pixeles no se tocan).
palette:
	python3 tools/mkpal.py

# Has cambiado colores en la paleta de UN PNG (hoja o panel) con el programa de dibujo:
# la lleva a palette.gpl, al juego y al resto de PNG. Encuentra solo cual es.
palette-sync:
	python3 tools/mkpal.py --sync

# Lo mismo diciendo de donde se coge: un PNG editable o una paleta .gpl de 64 colores
#   make palette-import SRC=assets/editable/sheets/common.png
palette-import:
	@test -n "$(or $(SRC),$(PNG))" || { echo 'uso: make palette-import SRC=assets/editable/sheets/common.png (o un .gpl)'; exit 1; }
	python3 tools/mkpal.py --import $(or $(SRC),$(PNG))

# Vuelve a sacar las hojas de sprites / el panel del original (PIERDE lo editado)
sheets-reset:
	python3 tools/mksprites.py --reset
hud-reset:
	python3 tools/mkhud.py --reset
# Vuelve a sacar las caras y las letras de la radio del original (PIERDE lo editado)
radio-reset:
	python3 tools/mkradio.py --reset

# Vuelve a sacar las montanas de los niveles del original (PIERDE lo editado)
mountains-reset:
	python3 tools/mkmountains.py --reset

# Vuelve a sacar los digitos del marcador de la fuente del original (PIERDE lo editado)
digits-reset:
	python3 tools/mkdigits.py --reset

# Vuelve a la captura original del monitor del aviso de nivel (PIERDE lo editado)
monitor-reset:
	python3 tools/mkmonitor.py --reset

ending-reset:
	python3 tools/mkending.py --reset

# Vuelve a sacar el fondo de la portada de la foto original (PIERDE lo editado)
menubg-reset:
	python3 tools/mkmenubg.py --reset

# Vuelve a sacar las letras de la portada de la fuente del original (PIERDE lo editado)
title-reset:
	python3 tools/mktitle.py --reset

# Vuelve a generar por programa las tiras de carretera assets/editable/strips.png (PIERDE lo editado)
strips-reset:
	python3 tools/mkstrips.py --reset

# Vista previa: compone frames reales del juego con los graficos de assets/editable/ y deja en
# assets/noneditable/preview/ un PNG y un TMX de solo lectura (Tiled) por frame, y una galeria de
# sprites por hoja sobre los fondos del juego (sprites_HOJA.tmx)
preview:
	python3 tools/mkpreview.py
	python3 tools/mkactors.py

# Vuelve a capturar del juego los frames de la vista previa (necesita openMSX y las
# partidas grabadas en ../MSX/build/ref_*.pkl)
frames: test-rom
	cd .. && python3 V9990-B1BP6/tools/framecap.py

build/road.rom: proto/road.asm proto/road_tab.inc ../MSX/rom/findram.inc
	@mkdir -p build
	cd proto && $(SJASM) road.asm && mv -f road.lst ../build/

proto/road_tab.inc: tools/roadtab.py
	python3 tools/roadtab.py

build/split.rom: proto/split.asm ../MSX/rom/findram.inc
	@mkdir -p build
	cd proto && $(SJASM) split.asm && mv -f split.lst ../build/

build/bench.rom: bench/bench.asm
	@mkdir -p build
	cd bench && $(SJASM) bench.asm && mv -f bench.lst ../build/

# la ROM del port es ASCII16; los prototipos (16K) no necesitan tipo
ROMTYPE  = $(if $(findstring chasehq_v9990,$(GAME)),-romtype ASCII16,)

run: $(GAME)
	$(OPENMSX) -machine $(MACHINE) $(V9FLAGS) -carta $(GAME) $(ROMTYPE)

run-turbor: $(GAME)
	$(OPENMSX) -machine $(TURBOR) $(V9FLAGS) -carta $(GAME) $(ROMTYPE)

bench: build/bench.rom
	python3 tools/v9bench.py

# Juega el port con la entrada grabada del original, captura el V9990 y vigila el TMS.
# Necesita ../MSX/build/ref_firststage.pkl (python3 ../tools/romreplay.py record ...).
port-test: test-rom
	cd .. && V9ROM=$(CURDIR)/build/chasehq_v9990_test.rom python3 V9990-B1BP6/tools/v9play.py MSX/build/ref_firststage.pkl V9990-B1BP6/build/port 24576 62000 150000 339000

road-test: build/road.rom
	python3 tools/v9road.py Sony_HB-10P 20 17

split-test: build/split.rom
	python3 tools/v9split.py

clean:
	rm -rf build
