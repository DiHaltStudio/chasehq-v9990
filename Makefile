# Chase H.Q. for MSX + V9990. The original game inputs are supplied separately.
PYTHON ?= python3
SJASM ?= sjasm
OPENMSX ?= openmsx
MACHINE ?= Sony_HB-10P
SIDE_A ?= original/side-a.cas
SIDE_B ?= original/side-b.cas
VERSION := $(strip $(shell cat VERSION))
ROM := V9990-B1BP6/build/chasehq_v9990.rom
RELEASE_ROM := release/chasehq_v9990.rom
PLAY_ROM = $(firstword $(wildcard $(RELEASE_ROM)) $(wildcard $(ROM)))
MANUAL_LANGS ?= en es
.DEFAULT_GOAL := build
.PHONY: all build inputs release manual run run-turbor help clean

all: build

inputs:
	$(PYTHON) tools/build_from_tape.py --side-a "$(SIDE_A)" --side-b "$(SIDE_B)" --sjasm "$(SJASM)"

build: inputs
	$(MAKE) -C V9990-B1BP6 SJASM=$(SJASM) build/chasehq_v9990.rom

manual:
	$(PYTHON) V9990-B1BP6/tools/manual_images.py docs/manual .
	cd docs/manual && for lang in $(MANUAL_LANGS); do \
	  for pass in 1 2; do pdflatex -interaction=nonstopmode -halt-on-error -jobname=manual-$$lang "\def\manlang{$$lang}\input{manual}" >/dev/null || exit 1; done; done

release: build manual
	mkdir -p release
	cp $(ROM) $(RELEASE_ROM)
	cp docs/manual/manual-en.pdf docs/manual/manual-es.pdf release/
	cd release && zip -q -j "chasehq-v9990-$(VERSION).zip" chasehq_v9990.rom manual-en.pdf manual-es.pdf

run:
	@rom="$(PLAY_ROM)"; if [ -z "$$rom" ]; then $(MAKE) --no-print-directory build || exit $$?; rom="$(ROM)"; fi; \
	$(OPENMSX) -machine $(MACHINE) -ext gfx9000 -carta "$$rom" -romtype ASCII16 -command "after boot {set videosource GFX9000}"

run-turbor:
	@$(MAKE) --no-print-directory run MACHINE=Panasonic_FS-A1GT

clean:
	rm -rf V9990-B1BP6/build

help:
	@echo 'make                 build from the original Side A CAS (SIDE_A=path)'
	@echo 'make release         prepare ROM, English/Spanish manuals and release ZIP'
	@echo 'make manual          rebuild both manuals from the LaTeX sources'
	@echo 'make run             play release ROM (or build it if missing) in openMSX'
	@echo 'make run-turbor      play on a turbo R configuration'
	@echo 'make clean           remove generated build intermediates'
