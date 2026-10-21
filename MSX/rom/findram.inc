; findram.inc -- busqueda de RAM para una pagina (se ensambla en cada sitio donde se incluye).
;
; FindRAM
;   Entrada: B = pagina (0..2) para la que se busca RAM. Interrupciones deshabilitadas. La
;            pagina 1 tiene que estar en el slot primario del cartucho (campo de A8).
;   Salida:  CF=0  hay RAM: el registro de slots (A8) y, si hizo falta, el de subslots
;                  (FFFF del slot primario) quedan seleccionandola en esa pagina.
;                  H = 80h | subslot si esta en un subslot (slot expandido); 0 si no.
;            CF=1  no hay RAM: A8 y los registros de subslots quedan como estaban.
;   Los primarios se prueban empezando por el siguiente al del cartucho, y el del cartucho
;   el ultimo: asi la RAM interna del MSX va antes que la del mapper que pueda llevar el
;   propio cartucho (MegaFlashROM SCC+ SD), que esta en otro subslot del mismo primario.
;   Destruye AF, BC, DE, HL, IX, IY, AF', BC'.
;   No debe ejecutarse desde la pagina B ni desde la pagina 3. La pila tiene que estar
;   en la pagina 3 (RAM de sistema): no se usa mientras la pagina 3 esta conmutada.
;   Lee EXPTBL (FCC1-FCC4, bit 7 = slot expandido), que tiene que seguir intacta.
;
; Es el mismo metodo del cargador CM de la cinta (8518): probar cada slot primario
; y, si esta expandido, cada subslot, escribiendo el complemento de un byte y
; comprobando que se lee. Aqui se restaura el byte y se consulta EXPTBL en vez de
; escribir a ciegas en FFFF.

; Z = hay RAM en (IX). Restaura el byte probado. LD y CPL no tocan Z.
        macro   RAMTEST
        ld      a,(ix+0)
        cpl
        ld      (ix+0),a
        cp      (ix+0)
        cpl
        ld      (ix+0),a
        endmacro

FindRAM:
        ld      a,b
        rrca
        rrca
        ld      ixh,a                   ; IX = pagina * 4000h: direccion de prueba
        ld      ixl,0
        ld      c,3                     ; C = mascara de la pagina en A8 / FFFF
        inc     b
        jr      .m1
.m0:    sla     c
        sla     c
.m1:    djnz    .m0
        in      a,(0A8h)
        ld      d,a                     ; D = A8 original
        rrca
        rrca
        inc     a
        and     3                       ; primero el primario siguiente al del cartucho
        add     a,0C1h
        ld      iyl,a
        ld      iyh,0FCh                ; IY -> EXPTBL del slot primario en curso
.prim:  ld      a,iyl
        sub     0C1h
        ld      e,a
        add     a,a
        add     a,a
        add     a,e
        ld      e,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        add     a,e
        ld      e,a                     ; E = slot primario repetido en los 4 campos (00,55,AA,FF)
        ld      a,c
        cpl
        and     d
        ld      b,a
        ld      a,e
        and     c
        or      b
        out     (0A8h),a                ; pagina -> slot primario E
        ld      b,a                     ; B = A8 con la pagina en este primario
        RAMTEST
        jr      z,.found
        bit     7,(iy+0)
        jr      z,.next                 ; no expandido
        ; slot expandido: probar sus 4 subslots. Para llegar a su registro FFFF hay que
        ; poner la pagina 3 en ese primario: H = A8 para eso. Sin pila en esas ventanas.
        ld      a,b
        and     3Fh
        ld      h,a
        ld      a,e
        and     0C0h
        or      h
        ld      h,a
        out     (0A8h),a
        ld      a,(0FFFFh)
        cpl                             ; A = registro de subslots original
        ld      l,a
        ld      a,b
        out     (0A8h),a
        ld      a,l
        push    af                      ; se guarda para restaurarlo si no hay RAM
        ld      l,0                     ; L = subslot repetido (00,55,AA,FF)
.sub:   ld      a,h
        out     (0A8h),a
        ld      a,(0FFFFh)
        cpl
        exx
        ld      b,a                     ; B' = registro actual
        exx
        xor     l
        and     c
        exx
        xor     b                       ; (actual & ~mascara) | (L & mascara)
        exx
        ld      (0FFFFh),a
        ld      a,b
        out     (0A8h),a
        RAMTEST
        jr      z,.foundsub
        ld      a,l
        add     a,55h
        ld      l,a
        jr      nc,.sub
        pop     af                      ; ningun subslot: restaurar el registro
        ex      af,af'
        ld      a,h
        out     (0A8h),a
        ex      af,af'
        ld      (0FFFFh),a
        ld      a,b
        out     (0A8h),a
.next:  ld      a,iyl
        inc     a
        cp      0C5h
        jr      nz,.n1
        ld      a,0C1h
.n1:    ld      iyl,a
        ld      b,a
        ld      a,d                     ; (de vuelta al primero: ninguno)
        rrca
        rrca
        inc     a
        and     3
        add     a,0C1h
        cp      b
        jp      nz,.prim                ; (JP: cada copia se ensambla en su sitio)
        ld      a,d
        out     (0A8h),a                ; no hay RAM: A8 original
        scf
        ret
.foundsub:
        pop     af
        ld      a,l
        and     3
        or      80h
        ld      h,a                     ; H = 80h | subslot
        or      a                       ; CF=0
        ret
.found: ld      h,0
        or      a                       ; CF=0
        ret
