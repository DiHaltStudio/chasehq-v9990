# Decodificador Z80 orientado a re-ensamblado exacto con Sjasm 0.42.
#
# decode(mem, pc) -> Ins
#   Ins.len    longitud en bytes
#   Ins.fmt    plantilla de texto con marcadores:
#                {n}  inmediato de 8 bits
#                {w}  inmediato de 16 bits (valor, p.ej. LD HL,nn)
#                {a}  direccion de memoria (nn) (p.ej. LD A,(nn))
#                {j}  destino de salto/llamada absoluto
#                {d}  desplazamiento con signo de (ix+d)/(iy+d)  -> "+5" / "-3"
#   Ins.ops    lista de (marcador, valor) en orden de aparicion
#   Ins.flow   None | 'jp' | 'jr' | 'jpcc' | 'jrcc' | 'djnz' | 'call' | 'callcc'
#              | 'ret' | 'retcc' | 'jpreg' | 'rst' | 'halt'
#   Ins.target destino para saltos/llamadas
#   Ins.raw    True si hay que emitirla como DB (no documentada / ambigua)
#   Ins.idx    'ix' | 'iy' | None  (registro indice usado con desplazamiento)

R = ['b', 'c', 'd', 'e', 'h', 'l', '(hl)', 'a']
RP = ['bc', 'de', 'hl', 'sp']
RP2 = ['bc', 'de', 'hl', 'af']
CC = ['nz', 'z', 'nc', 'c', 'po', 'pe', 'p', 'm']
ALU = ['add a,', 'adc a,', 'sub ', 'sbc a,', 'and ', 'xor ', 'or ', 'cp ']
ROT = ['rlc', 'rrc', 'rl', 'rr', 'sla', 'sra', 'sll', 'srl']


class Ins:
    __slots__ = ('len', 'fmt', 'ops', 'flow', 'target', 'raw', 'idx')

    def __init__(self, ln, fmt, ops=(), flow=None, target=None, raw=False, idx=None):
        self.len = ln
        self.fmt = fmt
        self.ops = list(ops)
        self.flow = flow
        self.target = target
        self.raw = raw
        self.idx = idx


def _s8(v):
    return v - 256 if v & 0x80 else v


def _base(mem, pc):
    """Decodifica una instruccion sin prefijo DD/FD (si CB/ED)."""
    op = mem[pc]
    b1 = mem[(pc + 1) & 0xffff]
    b2 = mem[(pc + 2) & 0xffff]
    nn = b1 | (b2 << 8)
    x, y, z = op >> 6, (op >> 3) & 7, op & 7
    p, q = y >> 1, y & 1

    if op == 0xCB:
        o = b1
        x, y, z = o >> 6, (o >> 3) & 7, o & 7
        if x == 0:
            return Ins(2, '%s %s' % (ROT[y], R[z]))
        return Ins(2, '%s %d,%s' % (['', 'bit', 'res', 'set'][x], y, R[z]))

    if op == 0xED:
        o = b1
        n2 = mem[(pc + 2) & 0xffff] | (mem[(pc + 3) & 0xffff] << 8)
        x, y, z = o >> 6, (o >> 3) & 7, o & 7
        p, q = y >> 1, y & 1
        if x == 1:
            if z == 0:
                if y == 6:
                    return Ins(2, 'in f,(c)', raw=True)
                return Ins(2, 'in %s,(c)' % R[y])
            if z == 1:
                if y == 6:
                    return Ins(2, 'out (c),0', raw=True)
                return Ins(2, 'out (c),%s' % R[y])
            if z == 2:
                return Ins(2, '%s hl,%s' % ('adc' if q else 'sbc', RP[p]))
            if z == 3:
                if p == 2:      # ED63 / ED6B: duplicados de 22 / 2A
                    return Ins(4, 'ld (nn),hl / ld hl,(nn) [ED]', raw=True)
                if q == 0:
                    return Ins(4, 'ld ({a}),%s' % RP[p], [('a', n2)])
                return Ins(4, 'ld %s,({a})' % RP[p], [('a', n2)])
            if z == 4:
                return Ins(2, 'neg', raw=(o != 0x44))
            if z == 5:
                if o == 0x45:
                    return Ins(2, 'retn', flow='ret')
                if o == 0x4D:
                    return Ins(2, 'reti', flow='ret')
                return Ins(2, 'retn*', flow='ret', raw=True)
            if z == 6:
                if o in (0x46, 0x56, 0x5E):
                    return Ins(2, 'im %d' % {0x46: 0, 0x56: 1, 0x5E: 2}[o])
                return Ins(2, 'im*', raw=True)
            if z == 7:
                t = ['ld i,a', 'ld r,a', 'ld a,i', 'ld a,r', 'rrd', 'rld', None, None][y]
                if t is None:
                    return Ins(2, 'nop*', raw=True)
                return Ins(2, t)
        if x == 2 and z <= 3 and y >= 4:
            t = [['ldi', 'cpi', 'ini', 'outi'], ['ldd', 'cpd', 'ind', 'outd'],
                 ['ldir', 'cpir', 'inir', 'otir'], ['lddr', 'cpdr', 'indr', 'otdr']][y - 4][z]
            return Ins(2, t)
        return Ins(2, 'ed*', raw=True)

    if x == 0:
        if z == 0:
            if y == 0:
                return Ins(1, 'nop')
            if y == 1:
                return Ins(1, "ex af,af'")
            tgt = (pc + 2 + _s8(b1)) & 0xffff
            if y == 2:
                return Ins(2, 'djnz {j}', [('j', tgt)], 'djnz', tgt)
            if y == 3:
                return Ins(2, 'jr {j}', [('j', tgt)], 'jr', tgt)
            return Ins(2, 'jr %s,{j}' % CC[y - 4], [('j', tgt)], 'jrcc', tgt)
        if z == 1:
            if q == 0:
                return Ins(3, 'ld %s,{w}' % RP[p], [('w', nn)])
            return Ins(1, 'add hl,%s' % RP[p])
        if z == 2:
            if y == 0:
                return Ins(1, 'ld (bc),a')
            if y == 1:
                return Ins(1, 'ld a,(bc)')
            if y == 2:
                return Ins(1, 'ld (de),a')
            if y == 3:
                return Ins(1, 'ld a,(de)')
            if y == 4:
                return Ins(3, 'ld ({a}),hl', [('a', nn)])
            if y == 5:
                return Ins(3, 'ld hl,({a})', [('a', nn)])
            if y == 6:
                return Ins(3, 'ld ({a}),a', [('a', nn)])
            return Ins(3, 'ld a,({a})', [('a', nn)])
        if z == 3:
            return Ins(1, '%s %s' % ('dec' if q else 'inc', RP[p]))
        if z == 4:
            return Ins(1, 'inc %s' % R[y])
        if z == 5:
            return Ins(1, 'dec %s' % R[y])
        if z == 6:
            return Ins(2, 'ld %s,{n}' % R[y], [('n', b1)])
        return Ins(1, ['rlca', 'rrca', 'rla', 'rra', 'daa', 'cpl', 'scf', 'ccf'][y])
    if x == 1:
        if op == 0x76:
            return Ins(1, 'halt', flow='halt')
        return Ins(1, 'ld %s,%s' % (R[y], R[z]))
    if x == 2:
        return Ins(1, '%s%s' % (ALU[y], R[z]))
    # x == 3
    if z == 0:
        return Ins(1, 'ret %s' % CC[y], flow='retcc')
    if z == 1:
        if q == 0:
            return Ins(1, 'pop %s' % RP2[p])
        if p == 0:
            return Ins(1, 'ret', flow='ret')
        if p == 1:
            return Ins(1, 'exx')
        if p == 2:
            return Ins(1, 'jp (hl)', flow='jpreg')
        return Ins(1, 'ld sp,hl')
    if z == 2:
        return Ins(3, 'jp %s,{j}' % CC[y], [('j', nn)], 'jpcc', nn)
    if z == 3:
        if y == 0:
            return Ins(3, 'jp {j}', [('j', nn)], 'jp', nn)
        if y == 2:
            return Ins(2, 'out ({n}),a', [('n', b1)])
        if y == 3:
            return Ins(2, 'in a,({n})', [('n', b1)])
        if y == 4:
            return Ins(1, 'ex (sp),hl')
        if y == 5:
            return Ins(1, 'ex de,hl')
        if y == 6:
            return Ins(1, 'di')
        return Ins(1, 'ei')
    if z == 4:
        return Ins(3, 'call %s,{j}' % CC[y], [('j', nn)], 'callcc', nn)
    if z == 5:
        if q == 0:
            return Ins(1, 'push %s' % RP2[p])
        if p == 0:
            return Ins(3, 'call {j}', [('j', nn)], 'call', nn)
        return None     # DD / ED / FD se tratan fuera
    if z == 6:
        return Ins(2, '%s{n}' % ALU[y], [('n', b1)])
    return Ins(1, 'rst {n}', [('n', y * 8)], 'rst', y * 8)


def decode(mem, pc):
    op = mem[pc]
    if op not in (0xDD, 0xFD):
        return _base(mem, pc)
    ir = 'ix' if op == 0xDD else 'iy'
    o = mem[(pc + 1) & 0xffff]
    if o in (0xDD, 0xFD, 0xED):
        return Ins(1, 'prefijo %s suelto' % ir, raw=True)
    if o == 0xCB:
        d = _s8(mem[(pc + 2) & 0xffff])
        c = mem[(pc + 3) & 0xffff]
        x, y, z = c >> 6, (c >> 3) & 7, c & 7
        if z != 6:
            return Ins(4, '%scb no documentada' % ir, raw=True)
        if x == 0:
            return Ins(4, '%s (%s{d})' % (ROT[y], ir), [('d', d)], idx=ir)
        return Ins(4, '%s %d,(%s{d})' % (['', 'bit', 'res', 'set'][x], y, ir), [('d', d)], idx=ir)
    b = _base(mem, (pc + 1) & 0xffff)
    if b is None or b.raw:
        return Ins(1, 'prefijo %s suelto' % ir, raw=True)
    f = b.fmt
    if o == 0xEB or o == 0xD9 or o == 0x08:        # EX DE,HL / EXX / EX AF no cambian
        return Ins(1, 'prefijo %s suelto' % ir, raw=True)
    if '(hl)' in f and o != 0xE9:
        # (hl) -> (ix+d); el byte de desplazamiento va justo tras el opcode
        d = _s8(mem[(pc + 2) & 0xffff])
        nf = f.replace('(hl)', '(%s{d})' % ir)
        ops = [('d', d)]
        ln = b.len + 2
        if b.ops:   # LD (ix+d),n : el inmediato va despues del desplazamiento
            ops.append(('n', mem[(pc + 3) & 0xffff]))
        return Ins(ln, nf, ops, idx=ir)
    if o == 0xE9:
        return Ins(2, 'jp (%s)' % ir, flow='jpreg')
    # sustituir hl/h/l por ix/ixh/ixl
    toks = f.split(' ', 1)
    if len(toks) == 1:
        return Ins(1, 'prefijo %s suelto' % ir, raw=True)
    mn, args = toks
    parts = args.split(',')
    changed = False
    newp = []
    for a in parts:
        if a == 'hl':
            a = ir
            changed = True
        elif a == 'h':
            a = ir + 'h'
            changed = True
        elif a == 'l':
            a = ir + 'l'
            changed = True
        elif a == '(sp)':
            pass
        newp.append(a)
    if not changed:
        return Ins(1, 'prefijo %s suelto' % ir, raw=True)
    undocumented = any(a in (ir + 'h', ir + 'l') for a in newp)
    ins = Ins(b.len + 1, mn + ' ' + ','.join(newp), b.ops, b.flow, b.target)
    # las formas con ixh/ixl se ensamblan bien en Sjasm, se dejan como texto
    ins.raw = False
    return ins


if __name__ == '__main__':
    import sys
    mem = open(sys.argv[1], 'rb').read()
    pc = int(sys.argv[2], 0)
    for _ in range(int(sys.argv[3]) if len(sys.argv) > 3 else 30):
        i = decode(mem, pc)
        print('%04X %-10s %s %s' % (pc, mem[pc:pc + i.len].hex(), i.fmt, i.ops))
        pc += i.len
