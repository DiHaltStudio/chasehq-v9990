#!/usr/bin/env python3
# Genera docs/09_variables.md a partir de MSX/ctl/01_vars.ctl (no editar el .md a mano).
import os, re
R = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
lab, com, sec, order = {}, {}, {}, []
cur = None
head = []
for l in open(os.path.join(R, 'MSX/ctl/01_vars.ctl'), encoding='utf-8'):
    l = l.rstrip('\n')
    m = re.match(r'^# -+ (.*)$', l)
    if m:
        cur = m.group(1); continue
    if l.startswith('#') and cur is None:
        head.append(l[1:].strip()); continue
    if l.startswith('L '):
        a, n = l.split()[1:3]; a = int(a, 16)
        lab[a] = n; sec[a] = cur; order.append(a)
    elif l.startswith('> '):
        a, t = l[2:].split(None, 1)
        com.setdefault(int(a, 16), []).append(t)
addrs = sorted(order)
out = ['# 9. Variables globales', '',
       'Generado por `tools/dasm/vardoc.py` desde `MSX/ctl/01_vars.ctl`.', '']
out += ['    ' + h for h in head if h] + ['']
last = None
for i, a in enumerate(addrs):
    if sec[a] != last:
        last = sec[a]
        out += ['', '## ' + last, '', '| Dir. | Nombre | Bytes | Significado |', '|---|---|---|---|']
    nxt = addrs[i + 1] if i + 1 < len(addrs) else None
    size = (nxt - a) if nxt and sec.get(nxt) == sec[a] else ''
    txt = ' '.join(com.get(a, [])).replace('|', '/')
    txt = re.sub(r'@([0-9A-F]{4})', lambda m: lab.get(int(m.group(1), 16), m.group(1)), txt)
    out.append('| %04X | `%s` | %s | %s |' % (a, lab[a], size, txt))
open(os.path.join(R, 'docs/09_variables.md'), 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('docs/09_variables.md:', len(addrs), 'variables')
