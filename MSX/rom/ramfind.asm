; ramfind.asm -- busqueda de la RAM de la pagina 1, ejecutada desde RAM en 8500h.
;
; La ROM esta en la pagina 1, asi que la RAM de esa pagina hay que buscarla desde otro
; sitio: la ROM copia este bloque a 8500h (pagina 2, ya RAM) y lo llama. Es temporal:
; la imagen del juego lo machaca despues.
;
; Entrada: pagina 0 y 2 = RAM, pagina 1 = cartucho, pila en la pagina 3, DI.
; Salida:  CF=0 y L = valor de A8 con RAM en las 4 paginas; CF=1 si no hay RAM en la
;          pagina 1 o si las 4 paginas no son RAM distinta (espejos).
;          H = 80h | subslot si esa RAM esta en un subslot del mismo slot primario que
;          el cartucho (el mapper de un MegaFlashROM SCC+ SD, por ejemplo); 0 si no.
;          Vuelve con el cartucho otra vez en la pagina 1: por A8 y, en ese caso, con el
;          registro de subslots de su primario (FFFF) apuntando otra vez al cartucho en
;          la pagina 1 (si no, el codigo de la ROM que sigue no estaria ahi).

        output  "../build/ramfind.bin"
        defpage 0,8500h,200h
        page    0
        code @ 8500h

RamFind1:
        in      a,(0A8h)
        push    af                      ; A8 con el cartucho en la pagina 1
        ld      b,a
        and     0Ch
        rrca
        rrca
        ld      c,a                     ; C = slot primario del cartucho (P)
        rrca
        rrca
        ld      e,a
        ld      a,b
        and     3Fh
        or      e
        ld      d,a                     ; D = A8 con la pagina 3 en P (para llegar a su FFFF)
        out     (0A8h),a                ; (sin pila mientras tanto)
        ld      a,(0FFFFh)
        cpl
        and     0Ch
        ld      e,a                     ; E = subslot del cartucho en la pagina 1 (si P esta expandido)
        ld      a,b
        out     (0A8h),a
        push    bc
        push    de
        ld      b,1
        call    FindRAM
        pop     de
        pop     bc
        jr      c,.back
        ld      (8700h),hl              ; (H: 80h | subslot de la RAM si esta en uno)
        ld      (8702h),de              ; (D y E: la comprobacion de espejos los pisa)
        ; Comprobar que las 4 paginas son RAM distinta: se marca xx10h de cada una con
        ; su numero y se relee. Se restauran los 4 bytes.
        ld      hl,0C010h
        ld      de,4
.save:  ld      a,(hl)
        push    af
        ld      (hl),d
        ld      a,h
        sub     40h
        ld      h,a
        inc     d
        dec     e
        jr      nz,.save                ; C010=0, 8010=1, 4010=2, 0010=3
        ld      hl,0010h
        ld      de,0304h                ; D = valor esperado, E = contador
        ld      c,0                     ; C = 0 si todo coincide
.chk:   ld      a,(hl)
        xor     d
        or      c
        ld      c,a
        pop     af
        ld      (hl),a
        ld      a,h
        add     a,40h
        ld      h,a
        dec     d
        dec     e
        jr      nz,.chk
        ld      a,c
        sub     1                       ; CF=1 si C=0 (bien) ...
        ccf                             ; ... CF=0 bien, CF=1 espejo
        jr      c,.back
        pop     bc
        push    bc                      ; B = A8 con el cartucho en la pagina 1
        ld      a,b
        and     0Ch
        rrca
        rrca
        ld      c,a                     ; C = P
        ld      a,(8701h)
        ld      h,a
        bit     7,a                     ; la RAM de la pagina 1, ¿en un subslot...
        jr      z,.ok
        in      a,(0A8h)
        and     0Ch
        rrca
        rrca
        cp      c                       ; ... del primario del cartucho?
        jr      nz,.ok
        in      a,(0A8h)
        ld      l,a
        ld      a,(8703h)               ; (D) pagina 3 en P y su registro de subslots: la pagina 1 otra
        out     (0A8h),a                ; vez al cartucho (sin pila mientras tanto)
        ld      a,(0FFFFh)
        cpl
        and     0F3h
        ld      d,a
        ld      a,(8702h)               ; (E)
        or      d
        ld      (0FFFFh),a
        ld      a,l
        out     (0A8h),a
        or      a                       ; CF=0
        jr      .back2
.ok:    ld      h,0
        or      a
.back:
.back2: in      a,(0A8h)
        ld      l,a
        pop     bc
        ld      a,b
        out     (0A8h),a
        ret

        include "findram.inc"
