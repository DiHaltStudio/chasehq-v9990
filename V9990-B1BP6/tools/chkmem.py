#!/usr/bin/env python3
# Comprueba que el codigo del port cabe en los huecos de RAM donde va (build/port.lst).
# Si uno se pasa, pisaria codigo o datos del original sin que el ensamblador avise.
import os, re, sys
V9 = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
HUECOS = [('V9_End', 0x1340, 'pagina 0 hasta las variables (1340)'),
          ('V9_SlotEnd', 0x33E0, 'cambio de slot (SlotSet) tras los bordes de carretera (33AB-33DF): rom.asm copia hasta ahi'),
          ('V9_HudEnd', 0x3BFE, 'hueco de VDP_DumpWindow (370D-3BFD)'),
          ('V9_PicEnd', 0x3F00, 'cuerpo de VDP_CopyColors (3DB6-3EFF), antes de tAttrToTMS'),
          ('V9_SndEnd', 0x8A56, 'sonido del original (8903-8A55), antes de Snd_Nop'),
          ('V9_SndEnd2', 0x8258, 'motor del original (8204-8257), antes de Title_Loop'),
          ('V9_SndEnd3', 0x3C15, 'tras el marcador: VDP_DumpWindow y VDP_DumpScreenSafe (hasta 3C14)'),
          ('V9_SndEnd4', 0x3C6A, 'cuerpo de VDP_DumpScreen (3C18-3C69)'),
          ('V9_SndEnd5', 0x84FB, 'trucos del Spectrum (84C4-84FA), antes de Main_EndFrame'),
          ('V9_UnsEnd', 0x1E80, 'sprites sin escalar (1A00-), antes de las variables del sonido'),
          ('V9_TlEnd', 0x81DD, 'portada (ROM normal): LD-BYTES y textos de la cinta (80C3-81DC)'),
          ('V9_TlEnd2', 0x8320, 'portada (ROM normal): Title_Loop del original (8258-831F)'),
          ('V9_TlEnd3', 0x80B9, 'portada (ROM normal): resto de Lvl_Load (8029-80B8)'),
          ('V9_TlEnd6', 0x370C, 'portada y cambios de pantalla (ROM normal): codigo muerto de la redefinicion de teclas (35CE-370B)'),
          ('V9_MsgEnd', 0x1A00, 'mensajes de la carrera (ROM normal): tras el vector de interrupcion (1901-19FF)'),
          ('V9_FxEnd1', 0x8DF9, 'aviso del nivel (ROM normal): codigo del fundido que se quito (8DA5-8DF8)'),
          ('V9_FxEnd2', 0x8E29, 'fin de nivel y aviso (ROM normal): codigo del fundido que se quito (8DFC-8E28)'),
          ('V9_TlEnd4', 0x3F00, 'portada (ROM normal): fondo, tras el codigo de V9_PicEnd (3DB6-3EFF)'),
          ('V9_IntroCarEnd', 0x9618, 'coche del criminal en el aviso (ROM normal): blitters opacos del original (949C-9617)')]
OPCIONAL = ('V9_TlEnd', 'V9_TlEnd2', 'V9_TlEnd3', 'V9_TlEnd4', 'V9_TlEnd6', 'V9_MsgEnd', 'V9_FxEnd1', 'V9_FxEnd2', 'V9_IntroCarEnd')    # solo en la ROM normal
lst = open(os.path.join(V9, 'build', 'port.lst')).read()
mal = False
if re.search(r'^00:0000[0-9A-F]{4}\s+(?:X\s+)?V9_TlEnd\s*$', lst, re.M) is None:      # ROM de pruebas: sin portada,
    HUECOS.append(('V9_DarkEnd', 0x3F00, 'ROM de pruebas: V9_Dark/V9_Lit en el cuerpo de VDP_CopyColors (3DB6-3EFF)'))  # dark.asm va en V9_PicEnd
for name, lim, desc in HUECOS:
    m = re.search(r'^00:0000([0-9A-F]{4})\s+(?:X\s+)?' + name + r'\s*$', lst, re.M)
    if m is None and name in OPCIONAL:
        continue
    if m is None:
        print('ERROR: falta %s en build/port.lst (%s)' % (name, desc))
        mal = True
        continue
    end = int(m.group(1), 16)
    if end > lim:
        print('ERROR: %s acaba en %04X y no puede pasar de %04X (%s): sobran %d bytes'
              % (name, end, lim, desc, end - lim))
        mal = True
    else:
        print('%s: %d bytes libres (%s)' % (name, lim - end, desc))
sys.exit(1 if mal else 0)
