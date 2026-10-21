#!/usr/bin/env python3
# Desensamblador dirigido por fichero de control para Chase H.Q. (MSX).
#
#   dasm.py image            -> escribe MSX/orig/image.bin (imagen de 64K tal como queda tras cargar la cinta)
#   dasm.py list [ini fin]   -> listado crudo con referencias cruzadas (para analizar)
#   dasm.py emit             -> genera MSX/src/*.asm a partir de MSX/ctl/*.ctl
#   dasm.py stats            -> resumen del analisis
#
# Formato de los ficheros de control (MSX/ctl/*.ctl), una orden por linea:
#   # comentario del propio ctl
#   F ini fin fichero            trozo de la imagen [ini,fin] que va al fichero MSX/src/<fichero>.asm
#   C dir                        punto de entrada de codigo adicional
#   D ini fin tipo [n]           datos: b=bytes  w=palabras  a=palabras-direccion  t=texto  z=ceros(ds)
#                                       g=grafico 1bpp (n bytes por fila)  i=incbin (n = nombre fichero)
#   L dir Nombre                 etiqueta
#   E Nombre valor               constante (equ) que no es una direccion de la imagen
#   N dir [k]                    el operando k (0 por defecto) de la instruccion en dir es un numero, no etiqueta
#   A dir [k]                    el operando k de la instruccion en dir SI es una direccion (fuerza etiqueta)
#   X dir k texto                sustituye el operando k por la expresion dada
#   S Estruct desp campo [; comentario]   campo de estructura (se emite Estruct_campo equ desp)
#   I ini fin reg Estruct        en [ini,fin] los (reg+d) se resuelven con los campos de Estruct (reg = ix|iy)
#   > dir texto                  linea de comentario de bloque antes de dir (repetible; ">" solo = linea en blanco)
#   ; dir texto                  comentario en la linea de la instruccion/dato de dir
#   En los comentarios, @XXXX se sustituye por la etiqueta de la direccion XXXX.
import sys, os, re, glob, pickle, collections

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
from z80tab import decode

IMG_LO = 0x3300
ORIG = os.path.join(ROOT, 'MSX', 'orig')
CTL = os.path.join(ROOT, 'MSX', 'ctl')
SRC = os.path.join(ROOT, 'MSX', 'src')


# ---------------------------------------------------------------- imagen
def build_image():
    """Reconstruye la memoria tal como la deja el cargador de cinta 'CM'."""
    mem = bytearray(65536)
    have = bytearray(65536)
    A = os.path.join(ROOT, 'msx', 'a')
    cm = open(os.path.join(A, '01_CM_8500.bin'), 'rb').read()

    def put(addr, data):
        mem[addr:addr + len(data)] = data
        have[addr:addr + len(data)] = b'\x01' * len(data)
    put(0x3300, cm[0x18c:0x18c + 0xab])       # rutina de bordes de carretera
    put(0x3400, cm[0x98:0x98 + 0xe6])         # rutina de cinta
    put(0x3500, open(os.path.join(A, '02_raw.bin'), 'rb').read()[1:1 + 0x2600])
    put(0x5B00, open(os.path.join(A, '03_raw.bin'), 'rb').read()[1:1 + 0x5280])
    put(0xAD80, open(os.path.join(A, '04_raw.bin'), 'rb').read()[1:1 + 0x527f])
    return mem, have


# ---------------------------------------------------------------- ctl
class Ctl:
    def __init__(self):
        self.files = []            # (ini, fin, nombre)
        self.entries = set()
        self.data = []             # (ini, fin, tipo, arg)
        self.labels = {}
        self.equs = collections.OrderedDict()
        self.numeric = set()       # (dir, k)
        self.isaddr = set()
        self.xop = {}              # (dir, k) -> texto
        self.structs = collections.OrderedDict()   # nombre -> {desp: (campo, comentario)}
        self.idx = []              # (ini, fin, reg, estruct)
        self.block = collections.defaultdict(list)
        self.inline = {}
        self.errors = []

    def load(self, path):
        self.cur = os.path.basename(path)
        for ln, line in enumerate(open(path, encoding='utf-8'), 1):
            line = line.rstrip('\n')
            if not line.strip() or line.startswith('#'):
                continue
            try:
                self._line(line)
            except Exception as ex:
                self.errors.append('%s:%d: %s  [%s]' % (os.path.basename(path), ln, ex, line))

    def _line(self, line):
        if re.search(r'[\x00-\x08\x0b-\x1f\x7f]', line):
            raise ValueError('caracteres de control en la linea')
        k = line[0]
        rest = line[1:].strip()
        h = lambda s: int(s, 16)
        if k == 'F':
            a, b, n = rest.split()
            self.files.append((h(a), h(b), n))
        elif k == 'C':
            self.entries.add(h(rest.split()[0]))
        elif k == 'D':
            t = rest.split(None, 3)
            self.data.append((h(t[0]), h(t[1]), t[2], t[3] if len(t) > 3 else None))
        elif k == 'L':
            a, n = rest.split()[:2]
            if not re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', n):
                raise ValueError('nombre de etiqueta no valido')
            if h(a) in self.labels and self.labels[h(a)] != n:
                raise ValueError('la direccion ya tiene etiqueta %s' % self.labels[h(a)])
            if n in self.labels.values() and self.labels.get(h(a)) != n:
                raise ValueError('nombre de etiqueta repetido')
            self.labels[h(a)] = n
        elif k == 'E':
            n, v = rest.split()[:2]
            self.equs[n] = v
        elif k == 'N':
            t = rest.split()
            self.numeric.add((h(t[0]), int(t[1]) if len(t) > 1 else 0))
        elif k == 'A':
            t = rest.split()
            self.isaddr.add((h(t[0]), int(t[1]) if len(t) > 1 else 0))
        elif k == 'X':
            a, kk, txt = rest.split(None, 2)
            self.xop[(h(a), int(kk))] = txt
        elif k == 'S':
            cm = ''
            if ';' in rest:
                rest, cm = rest.split(';', 1)
            n, off, fld = rest.split()[:3]
            self.structs.setdefault(n, collections.OrderedDict())[int(off, 0)] = (fld, cm.strip())
        elif k == 'I':
            a, b, reg, st = rest.split()[:4]
            self.idx.append((h(a), h(b), reg.lower(), st))
        elif k == '>':
            t = rest.split(None, 1)
            if not t:
                raise ValueError('falta direccion')
            self.block[h(t[0])].append(t[1] if len(t) > 1 else '')
        elif k == ';':
            a, txt = rest.split(None, 1)
            self.inline[h(a)] = txt
        else:
            raise ValueError('orden desconocida')


def load_ctl():
    c = Ctl()
    for f in sorted(glob.glob(os.path.join(CTL, '*.ctl'))):
        c.load(f)
    return c


# ---------------------------------------------------------------- analisis
class Analysis:
    def __init__(self, mem, have, ctl):
        self.mem = mem
        self.have = have
        self.ctl = ctl
        self.ins = {}                      # dir -> Ins
        self.owner = [None] * 65536        # dir -> dir de inicio de instruccion que la contiene
        self.dtype = [None] * 65536        # dir -> indice en ctl.data
        self.xref_code = collections.defaultdict(set)   # destino -> {origen}
        self.xref_data = collections.defaultdict(set)   # dir -> {origen}
        self.conflicts = []
        self.cov = bytearray(65536)
        self.indirect = {}
        for i, (a, b, t, arg) in enumerate(ctl.data):
            for x in range(a, b + 1):
                self.dtype[x] = i

    def load_cov(self):
        for f in glob.glob(os.path.join(ROOT, 'msx', 'trace*.pkl')):
            cov, ind = pickle.load(open(f, 'rb'))[:2]
            for i in range(IMG_LO, 0x10000):
                if cov[i]:
                    self.cov[i] = 1
            for k, v in ind.items():
                self.indirect.setdefault(k, set()).update(v)

    def in_image(self, a):
        return 0 <= a < 0x10000 and self.have[a]

    def trace(self, seeds):
        work = list(seeds)
        while work:
            pc = work.pop()
            while True:
                if not self.in_image(pc) or self.dtype[pc] is not None:
                    break
                if pc in self.ins:
                    break
                if self.owner[pc] is not None:
                    self.conflicts.append((pc, self.owner[pc]))
                    break
                i = decode(self.mem, pc)
                clash = [x for x in range(pc, pc + i.len) if self.owner[x & 0xffff] is not None]
                if clash:
                    self.conflicts.append((pc, self.owner[clash[0] & 0xffff]))
                    break
                self.ins[pc] = i
                for x in range(pc, pc + i.len):
                    self.owner[x & 0xffff] = pc
                f = i.flow
                if f in ('jr', 'jrcc', 'djnz') and abs(i.target - (pc + i.len)) > 128:
                    # salto relativo que da la vuelta a 64K: casi seguro datos; sjasm no lo acepta
                    i.raw = True
                    i.flow = f = 'jpreg'
                if f in ('jp', 'jr'):
                    work.append(i.target)
                    break
                if f in ('jpcc', 'jrcc', 'djnz', 'call', 'callcc'):
                    work.append(i.target)
                if f in ('ret', 'jpreg', 'halt'):
                    break
                pc = (pc + i.len) & 0xffff

    def run(self):
        seeds = set(self.ctl.entries)
        seeds |= {a for a in range(IMG_LO, 0x10000) if self.cov[a]}
        for v in self.indirect.values():
            seeds |= v
        # las semillas de cobertura primero en orden, para que manden sobre el analisis estatico
        self.trace(sorted(seeds, reverse=True))
        for pc, i in self.ins.items():
            if i.flow in ('jp', 'jr', 'jpcc', 'jrcc', 'djnz', 'call', 'callcc'):
                self.xref_code[i.target].add(pc)
            for kind, v in i.ops:
                if kind in ('a', 'w'):
                    self.xref_data[v].add(pc)


# ---------------------------------------------------------------- nombres
class Namer:
    def __init__(self, an):
        self.an = an
        self.ctl = an.ctl
        self.auto = {}
        self.ext = {}       # etiquetas de direcciones fuera de la imagen -> equ

    def label_at(self, a):
        if a in self.ctl.labels:
            return self.ctl.labels[a]
        return self.auto.get(a)

    def want(self, a):
        """Asegura que la direccion a (inicio de instruccion o de dato) tiene etiqueta."""
        if a in self.ctl.labels or a in self.auto:
            return
        an = self.an
        if a in an.ins:
            self.auto[a] = 'L_%04X' % a
        else:
            self.auto[a] = 'D_%04X' % a

    def data_base(self, a):
        """Etiqueta base mas cercana por debajo dentro del mismo bloque de datos."""
        an = self.an
        di = an.dtype[a]
        b = a
        lo = an.ctl.data[di][0] if di is not None else None
        while True:
            if b in self.ctl.labels or b in self.auto:
                return b
            if lo is not None and b == lo:
                return b
            if lo is None and (b == IMG_LO or an.owner[b - 1] is not None or an.dtype[b - 1] is not None
                               or not an.have[b - 1]):
                return b
            b -= 1

    def resolve(self, a, define=False):
        """Devuelve la expresion simbolica de la direccion a (o None si no procede)."""
        an = self.an
        if not (0 <= a < 0x10000):
            return None
        if not an.have[a]:
            n = self.ctl.labels.get(a)
            if n:
                self.ext[a] = n
            return n
        own = an.owner[a]
        if own is not None:
            if own == a:
                if define:
                    self.want(a)
                return self.label_at(a)
            n = self.ctl.labels.get(a)      # etiqueta de operando automodificable
            if n:
                return n
            if define:
                self.want(own)
            base = self.label_at(own)
            return None if base is None else '%s+%d' % (base, a - own)
        b = self.data_base(a)
        if define:
            self.want(b)
        base = self.label_at(b)
        if base is None:
            return None
        return base if b == a else '%s+#%X' % (base, a - b)


def hx8(v):
    return '#%02X' % (v & 0xff)


def hx16(v):
    return '#%04X' % (v & 0xffff)


class Emitter:
    def __init__(self, an):
        self.an = an
        self.ctl = an.ctl
        self.nm = Namer(an)
        self.pass_define = True

    # ---- operandos
    def struct_for(self, pc, reg):
        for a, b, r, st in self.ctl.idx:
            if a <= pc <= b and r == reg:
                return st
        return None

    def operand(self, pc, ins, k, kind, v, define):
        ctl = self.ctl
        if (pc, k) in ctl.xop:
            return ctl.xop[(pc, k)]
        if kind == 'n':
            return hx8(v)
        if kind == 'd':
            st = self.struct_for(pc, ins.idx)
            if st and v in ctl.structs.get(st, {}):
                return '+%s_%s' % (st, ctl.structs[st][v][0])
            return '%+d' % v if v else '+0'
        if kind in ('j', 'a'):
            if (pc, k) in ctl.numeric:
                return hx16(v)
            s = self.nm.resolve(v, define)
            return s if s else hx16(v)
        if kind == 'w':
            if (pc, k) in ctl.numeric:
                return hx16(v)
            force = (pc, k) in ctl.isaddr
            reg = ins.fmt.split(' ', 1)[1].split(',')[0] if ' ' in ins.fmt else ''
            if not force and reg == 'bc':
                return hx16(v)
            if not force and not self.an.in_image(v):
                s = self.ctl.labels.get(v)
                if s:
                    self.nm.ext[v] = s
                    return s
                return hx16(v)
            s = self.nm.resolve(v, define)
            return s if s else hx16(v)
        return str(v)

    def text(self, pc, ins, define=False):
        out = ins.fmt
        for k, (kind, v) in enumerate(ins.ops):
            out = out.replace('{%s}' % kind, self.operand(pc, ins, k, kind, v, define), 1)
        return out

    # ---- comentarios
    def subst(self, txt):
        def rep(m):
            a = int(m.group(1), 16)
            s = self.nm.resolve(a, False)
            return s if s else '#%04X' % a
        return re.sub(r'@([0-9A-Fa-f]{4})\b', rep, txt)

    # ---- recorrido de la imagen en elementos
    def items(self, lo, hi):
        """Genera (dir, 'code', Ins) o (dir, 'data', (fin, tipo, arg))."""
        an = self.an
        a = lo
        while a <= hi:
            if not an.have[a]:
                b = a
                while b + 1 <= hi and not an.have[b + 1]:
                    b += 1
                yield a, 'gap', b
                a = b + 1
                continue
            if a in an.ins:
                yield a, 'code', an.ins[a]
                a += an.ins[a].len
                continue
            di = an.dtype[a]
            b = a
            while (b + 1 <= hi and an.have[b + 1] and (b + 1) not in an.ins
                   and an.owner[b + 1] is None and an.dtype[b + 1] == di):
                b += 1
            if di is None:
                yield a, 'data', (b, 'b', None)
            else:
                _, _, t, arg = an.ctl.data[di]
                yield a, 'data', (b, t, arg)
            a = b + 1

    def prepass(self):
        """Define todas las etiquetas automaticas necesarias."""
        an = self.an
        for pc, ins in an.ins.items():
            self.text(pc, ins, define=True)
        for a, b, t, arg in an.ctl.data:
            if t == 'a':
                for x in range(a, b, 2):
                    v = an.mem[x] | (an.mem[x + 1] << 8)
                    self.nm.resolve(v, True)
        for a in an.ctl.labels:
            pass

    # ---- emision
    def emit_file(self, lo, hi, name, fh):
        an, ctl, nm, mem = self.an, self.ctl, self.nm, self.an.mem
        W = fh.write
        cur_page = None
        need_org = True
        col = 40

        def org(a):
            nonlocal cur_page
            pg = 0                         # una sola pagina de 64K (ver MSX/src/main.asm)
            if pg != cur_page:
                W('\n        page    %d\n' % pg)
                cur_page = pg
            W('        code @ %s\n\n' % hx16(a))

        def line(code, cm=None):
            if cm:
                s = '        %s' % code
                W('%s%s; %s\n' % (s, ' ' * max(1, col - len(s)), cm))
            else:
                W('        %s\n' % code)

        def head(a):
            for t in ctl.block.get(a, []):
                W((';' + (' ' + self.subst(t) if t else '')).rstrip() + '\n')
            n = nm.label_at(a)
            if n:
                W('%s:%s; %s\n' % (n, ' ' * max(1, col - len(n) - 1), hx16(a)))

        def midlabels(a, ln):
            # etiquetas definidas dentro de la instruccion (operandos automodificables)
            for x in range(a + 1, a + ln):
                if x in ctl.labels:
                    W('%s equ $+%d\n' % (ctl.labels[x], x - a))

        for a, kind, info in self.items(lo, hi):
            if kind == 'gap':
                need_org = True
                continue
            if need_org:
                org(a)
                need_org = False
            if kind == 'code':
                ins = info
                # una instruccion no puede cruzar frontera de pagina de 16K sin partirla
                head(a)
                midlabels(a, ins.len)
                cm = ctl.inline.get(a)
                cm = self.subst(cm) if cm else None
                if ins.raw:
                    bs = ','.join(hx8(mem[a + i]) for i in range(ins.len))
                    line('db      ' + bs, ((cm + ' ') if cm else '') + '(' + ins.fmt + ')')
                else:
                    t = self.text(a, ins)
                    mn, _, args = t.partition(' ')
                    line(('%-7s %s' % (mn, args)).rstrip(), cm)
                if ins.flow in ('ret', 'jp', 'jr', 'jpreg', 'halt'):
                    W('\n')
                continue
            # ---- datos
            b, t, arg = info
            self.emit_data(a, b, t, arg, W, head, line, org)

    def emit_data(self, a, b, t, arg, W, head, line, org):
        an, ctl, nm, mem = self.an, self.ctl, self.nm, self.an.mem
        x = a
        if t == 'i':
            head(a)
            cm = ctl.inline.get(a)
            # un incbin no puede cruzar frontera de 16K: se parte
            while x <= b:
                e = min(b, (x | 0x3fff))
                if x != a and (x & 0x3fff) == 0:
                    org(x)
                line('incbin  "%s",%d,%d' % (arg, x - a, e - x + 1), self.subst(cm) if cm and x == a else None)
                x = e + 1
            W('\n')
            return
        step = {'b': 16, 'w': 2, 'a': 2, 't': 32, 'z': 1 << 16, 'g': int(arg) if (t == 'g' and arg) else 1}[t]
        per_line = {'w': 8, 'a': 4}.get(t, 1)
        while x <= b:
            if x != a and (x & 0x3fff) == 0:
                org(x)
            head(x)
            # fin del trozo: siguiente etiqueta / comentario / frontera
            e = x
            lim = b
            while e + 1 <= lim and (e + 1) not in ctl.labels and (e + 1) not in nm.auto \
                    and (e + 1) not in ctl.block and (e + 1) not in ctl.inline and ((e + 1) & 0x3fff):
                e += 1
            cm = ctl.inline.get(x)
            cm = self.subst(cm) if cm else None
            if t == 'z' and all(mem[i] == 0 for i in range(x, e + 1)):
                line('ds      %d' % (e - x + 1), cm)
                x = e + 1
                continue
            if t in ('w', 'a') and (e - x + 1) % 2 == 0:
                while x <= e:
                    n = min(per_line * 2, e - x + 1)
                    vals = []
                    for i in range(x, x + n, 2):
                        v = mem[i] | (mem[i + 1] << 8)
                        s = nm.resolve(v, False) if t == 'a' else None
                        vals.append(s if s else hx16(v))
                    line('dw      ' + ','.join(vals), cm)
                    cm = None
                    x += n
                continue
            if t == 't':
                while x <= e:
                    n = min(32, e - x + 1)
                    line('db      ' + self.textbytes(mem[x:x + n]), cm)
                    cm = None
                    x += n
                continue
            if t == 'g':
                while x <= e:
                    n = min(step, e - x + 1)
                    bits = ''.join(format(mem[i], '08b') for i in range(x, x + n)).replace('0', '.').replace('1', '#')
                    line('db      ' + ','.join(hx8(mem[i]) for i in range(x, x + n)), (cm + ' ' if cm else '') + bits)
                    cm = None
                    x += n
                continue
            while x <= e:
                n = min(16, e - x + 1)
                line('db      ' + ','.join(hx8(mem[i]) for i in range(x, x + n)), cm)
                cm = None
                x += n
        W('\n')

    @staticmethod
    def textbytes(bs):
        out = []
        run = ''
        for c in bs:
            if 32 <= c < 127 and c not in (34, 92):
                run += chr(c)
            else:
                if run:
                    out.append('"%s"' % run)
                    run = ''
                out.append(hx8(c))
        if run:
            out.append('"%s"' % run)
        return ','.join(out)


# ---------------------------------------------------------------- ordenes
def setup():
    mem, have = build_image()
    ctl = load_ctl()
    for e in ctl.errors:
        print('CTL ERROR', e)
    an = Analysis(mem, have, ctl)
    an.load_cov()
    an.run()
    return an


def cmd_image():
    mem, have = build_image()
    os.makedirs(ORIG, exist_ok=True)
    open(os.path.join(ORIG, 'image.bin'), 'wb').write(mem)
    open(os.path.join(ORIG, 'have.bin'), 'wb').write(have)
    print('image.bin escrito; bytes definidos:', sum(have))


def cmd_stats():
    an = setup()
    code = sum(i.len for i in an.ins.values())
    tot = sum(an.have)
    print('instrucciones: %d   bytes de codigo: %d   bytes de datos: %d' % (len(an.ins), code, tot - code))
    print('conflictos (codigo solapado):', len(an.conflicts))
    for pc, own in sorted(set(an.conflicts))[:60]:
        print('   %04X cae dentro de la instruccion de %04X  (cov=%d)' % (pc, own, an.cov[pc]))
    raw = [(pc, i) for pc, i in sorted(an.ins.items()) if i.raw]
    print('instrucciones emitidas como DB:', len(raw))
    for pc, i in raw[:40]:
        print('   %04X %s' % (pc, i.fmt))
    # regiones
    a = IMG_LO
    reg = []
    while a < 0x10000:
        if not an.have[a]:
            a += 1
            continue
        k = 'C' if an.owner[a] is not None else 'D'
        b = a
        while b + 1 < 0x10000 and an.have[b + 1] and ('C' if an.owner[b + 1] is not None else 'D') == k:
            b += 1
        reg.append((a, b, k))
        a = b + 1
    print('regiones:', len(reg))
    for a, b, k in reg:
        if b - a >= 24:
            print('   %04X-%04X %s %5d' % (a, b, k, b - a + 1))


def cmd_list(lo=IMG_LO, hi=0xffff, out=sys.stdout):
    an = setup()
    em = Emitter(an)
    em.prepass()
    nm = em.nm
    mem = an.mem
    W = out.write
    for a, kind, info in em.items(lo, hi):
        if kind == 'gap':
            W('\n; ---- hueco %04X-%04X (no cargado)\n\n' % (a, info))
            continue
        xr = sorted(an.xref_code.get(a, ()))
        xd = sorted(an.xref_data.get(a, ()))
        n = nm.label_at(a)
        if n or xr or xd:
            s = '%s:' % (n or '')
            if xr:
                s += '   ; <- codigo: ' + ' '.join('%04X' % x for x in xr[:14]) + (' ...' if len(xr) > 14 else '')
            if xd:
                s += '   ; <- datos: ' + ' '.join('%04X' % x for x in xd[:14]) + (' ...' if len(xd) > 14 else '')
            W(s + '\n')
        if kind == 'code':
            ins = info
            for x in range(a + 1, a + ins.len):
                xs = sorted(an.xref_data.get(x, ()))
                if xs:
                    W('          ; (operando en %04X automodificado/leido desde: %s)\n' % (x, ' '.join('%04X' % y for y in xs[:12])))
            W('%04X %-9s%s %s\n' % (a, bytes(mem[a:a + ins.len]).hex(), '*' if an.cov[a] else ' ', em.text(a, ins)))
            if ins.flow in ('ret', 'jp', 'jr', 'jpreg', 'halt'):
                W('\n')
        else:
            b, t, arg = info
            x = a
            while x <= b:
                n = min(16, b - x + 1)
                # cortar en referencias
                for y in range(x + 1, x + n):
                    if an.xref_data.get(y) or an.xref_code.get(y) or nm.label_at(y):
                        n = y - x
                        break
                if x != a:
                    xd = sorted(an.xref_data.get(x, ()))
                    lab = nm.label_at(x)
                    if xd or lab:
                        W('%s:   ; <- datos: %s\n' % (lab or '', ' '.join('%04X' % q for q in xd[:14])))
                bs = bytes(mem[x:x + n])
                asc = ''.join(chr(c) if 32 <= c < 127 else '.' for c in bs)
                W('%04X  db %-48s ; %s\n' % (x, ' '.join('%02x' % c for c in bs), asc))
                x += n
            W('\n')


def cmd_emit():
    an = setup()
    em = Emitter(an)
    em.prepass()
    ctl = an.ctl
    os.makedirs(SRC, exist_ok=True)
    files = sorted(ctl.files)
    if not files:
        files = [(IMG_LO, 0xffff, 'game')]
    names = []
    for lo, hi, name in files:
        path = os.path.join(SRC, name + '.asm')
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write('; %s.asm  --  Chase H.Q. (MSX)  %s-%s\n' % (name, hx16(lo), hx16(hi)))
            fh.write('; Generado por tools/dasm/dasm.py a partir de MSX/ctl/*.ctl. NO EDITAR A MANO:\n')
            fh.write('; los comentarios y etiquetas se cambian en los .ctl y se regenera.\n\n')
            em.emit_file(lo, hi, name, fh)
        names.append(name)
    # constantes: equ externos y estructuras
    with open(os.path.join(SRC, 'symbols.asm'), 'w', encoding='utf-8') as fh:
        fh.write('; symbols.asm -- constantes, direcciones externas y campos de estructura\n')
        fh.write('; Generado por tools/dasm/dasm.py. NO EDITAR A MANO.\n\n')
        for n, v in ctl.equs.items():
            fh.write('%-23s equ %s\n' % (n, v))
        fh.write('\n; --- direcciones fuera de la imagen cargada\n')
        for a, n in sorted(em.nm.ext.items()):
            fh.write('%-23s equ %s\n' % (n, hx16(a)))
        for st, flds in ctl.structs.items():
            fh.write('\n; --- estructura %s\n' % st)
            for off, (fld, cm) in sorted(flds.items()):
                fh.write('%-23s equ %-6d%s\n' % ('%s_%s' % (st, fld), off, ('; ' + cm) if cm else ''))
    with open(os.path.join(SRC, 'files.txt'), 'w') as fh:
        fh.write('\n'.join(names) + '\n')
    print('emitidos %d ficheros en %s' % (len(names), SRC))


if __name__ == '__main__':
    c = sys.argv[1] if len(sys.argv) > 1 else 'stats'
    if c == 'image':
        cmd_image()
    elif c == 'stats':
        cmd_stats()
    elif c == 'list':
        lo = int(sys.argv[2], 16) if len(sys.argv) > 2 else IMG_LO
        hi = int(sys.argv[3], 16) if len(sys.argv) > 3 else 0xffff
        cmd_list(lo, hi)
    elif c == 'emit':
        cmd_emit()
