; sound.asm -- sonido del port: reproductor de VGM para el PSG.
;
; Sustituye al sonido del original (beeper por el clic del teclado: motor, efectos y
; musica del titulo) por el de la version ZX Spectrum 128K, que usaba un AY-3-8910 (el
; mismo chip que el PSG del MSX):
;   - pistas VGM (assets/editable/sound/*.vgm, convertidas por tools/mksound.py al reloj del PSG y
;     guardadas en bancos de ROM): musica del titulo, sirena y turbo del 128K, y los 9
;     efectos del original (que en el 128K seguian en el beeper) pasados al PSG
;     (tools/beepsfx.py);
;   - el motor, que depende de la velocidad, se calcula como en el 128K (80AA).
;
; Cuatro pistas a la vez: musica (todos los registros), sirena (canales A y B), turbo y
; efecto (canal C y ruido, cada una en su propia copia de los registros). El canal C sale
; del efecto si suena, si no del turbo, y si no del motor; la musica (solo en el titulo)
; lo tiene todo. La interrupcion del retrazado (V9_Isr, 50 Hz) avanza las pistas hasta su
; siguiente espera y vuelca los registros al PSG. Formato de las pistas (VGM): A0 rr dd
; (escribe dd en el registro rr), 63 (espera un frame), 66 (fin: bucle o parar).
;
; El PSG tambien da la palanca (R14/R15): quien lo lea lo hace con DI (V9_InpRead,
; V9_JoyRead) para que la interrupcion no cambie el registro seleccionado en medio.

; --- variables (1E80-1EC9; tools/chkmem.py comprueba que los sprites sin escalar acaban antes)
VGM_S0          equ 1E80h               ; 4 pistas x 6 bytes: banco (0 = parada), puntero,
                                        ; banco del bucle (0 = sin bucle), puntero del bucle
VGM_REG         equ 1E98h               ; copia de R0-R13 (musica y sirena)
VGM_R13         equ 1EA6h               ; <> 0: R13 escrito (reinicia la envolvente)
VGM_ENG         equ 1EA7h               ; motor: periodo del tono C (palabra) y volumen
VGM_OWN         equ 1EAAh               ; registros de la pista en curso (palabra)
VGM_ALT         equ 1EACh               ; efecto 1 del original: solo suena una vez de cada dos
VGM_C2          equ 1EADh               ; R0-R13 del turbo (solo cuentan R4-R7 y R10)
VGM_C3          equ 1EBBh               ; R0-R13 del efecto (idem)
VGM_ATT         equ 1EC9h               ; fundido de salida de la sirena: pasos de volumen que se restan (0 = no)
VGM_FCNT        equ 1ECAh               ;   frames hasta el siguiente paso
VGM_MUTE        equ 1ECBh               ; <> 0: en pausa (todo callado y las pistas quietas)
VGM_EFFECT      equ 1ECCh               ; ultimo id de efecto; solo valido con pista 3 activa
VGM_END         equ 1ECDh

; Un frame de 50 Hz (desde la interrupcion del retrazado, con todo RAM): avanza las pistas
; y vuelca R0-R12 (y R13 si alguna lo ha escrito) al PSG. Destruye AF, BC, DE, HL; conserva IX.
V9_SndTick:
        ld      a,(VGM_MUTE)
        or      a
        jp      nz,V9_SndMuted
        push    ix
        ld      a,SLOT_C1
        call    SlotSet                 ; cartucho en la pagina 1: las pistas estan en la ROM
        ld      ix,VGM_S0
        ld      hl,TVgmOwn
        ld      b,4
.str:   push    bc
        push    hl
        ld      a,(ix+0)
        or      a
        call    nz,V9_SndStep
        pop     hl
        pop     bc
        inc     hl
        inc     hl
        inc     hl
        inc     hl
        ld      de,6
        add     ix,de
        djnz    .str
        ld      a,SLOT_RAM
        call    SlotSet
        pop     ix
        call    V9_SndFade
        ld      a,(VGM_S0)              ; con musica, todo es suyo
        or      a
        jr      nz,.out
        ld      hl,VGM_C3               ; canal C: el efecto, el turbo o el motor
        ld      a,(VGM_S0+18)
        or      a
        jr      nz,.c
        ld      hl,VGM_C2
        ld      a,(VGM_S0+12)
        or      a
        jr      nz,.c
        ld      hl,(VGM_ENG)
        ld      (VGM_REG+4),hl
        ld      a,(VGM_ENG+2)
        ld      (VGM_REG+10),a
        ld      a,(VGM_REG+7)
        and     0FBh                    ; tono C activo
        or      20h                     ; ruido C apagado
        ld      (VGM_REG+7),a
        jr      .out
.c:     ld      de,4
        add     hl,de
        ld      de,VGM_REG+4
        ldi
        ldi
        ldi                             ; R4-R6
        ld      a,(hl)
        and     24h                     ; R7: tono y ruido de C
        ld      c,a
        ld      a,(VGM_REG+7)
        and     0DBh
        or      c
        ld      (VGM_REG+7),a
        inc     hl
        inc     hl
        inc     hl
        ld      a,(hl)
        ld      (VGM_REG+10),a          ; R10
.out:   ld      hl,VGM_REG
        xor     a
.reg:   out     (0A0h),a
        ld      c,a
        ld      a,(hl)
        inc     hl
        bit     3,c                     ; (R7: con los bits 6-7 del puerto de la palanca)
        jr      nz,.w
        bit     2,c
        jr      z,.w
        bit     1,c
        jr      z,.w
        bit     0,c
        jr      z,.w
        and     3Fh
        or      80h
.w:     ld      b,a                     ; R8-R9 (sirena): menos el fundido de salida
        ld      a,c
        and     0FEh
        cp      8
        ld      a,b
        jr      nz,.o
        ld      a,(VGM_ATT)
        ld      e,a
        ld      a,b
        sub     e
        jr      nc,.o
        xor     a
.o:     out     (0A1h),a
        ld      a,c
        inc     a
        cp      13
        jr      c,.reg
        ld      a,(VGM_R13)
        or      a
        ret     z
        xor     a
        ld      (VGM_R13),a
        ld      a,13
        out     (0A0h),a
        ld      a,(hl)
        out     (0A1h),a
        ret

; Pista IX (HL -> sus registros en TVgmOwn): ordenes hasta la siguiente espera o el fin.
V9_SndStep:
        ld      (VGM_OWN),hl
        ld      e,(ix+1)
        ld      d,(ix+2)
        ld      a,(ix+0)
        ld      (6000h),a
.cmd:   call    .rd
        cp      63h
        jr      z,.wait
        cp      0A0h
        jr      nz,.end
        call    .rd
        ld      c,a                     ; registro
        call    .rd
        ld      b,a                     ; valor
        call    V9_SndWr
        jr      .cmd
.wait:  ld      (ix+1),e
        ld      (ix+2),d
        ret
.end:   cp      66h
        jr      nz,.stop
        ld      a,(ix+3)                ; fin: vuelve al bucle o se para
        or      a
        jr      z,.stop
        ld      (ix+0),a
        ld      (6000h),a
        ld      e,(ix+4)
        ld      d,(ix+5)
        jr      .cmd
.stop:  ld      (ix+0),0
        ld      hl,(VGM_OWN)
        jp      V9_SndRelease
; siguiente byte de la pista (DE en 4000-7FFF; al llegar a 8000h, el banco siguiente)
.rd:    ld      a,(de)
        inc     de
        bit     7,d
        ret     z
        ld      d,40h
        push    af
        ld      a,(ix+0)
        inc     a
        ld      (ix+0),a
        ld      (6000h),a
        pop     af
        ret
; Para la pista A (0 musica, 1 sirena, 2 turbo, 3 efecto) y silencia lo suyo.
V9_SndStop:
        push    af
        call    V9_SndSlot
        pop     bc
        call    V9_Iff
        di
        push    af
        ld      (hl),0
        ld      a,b
        add     a,a
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,TVgmOwn
        add     hl,de
        jp      V9_SndRelStop           ; (sigue en el hueco de Main_Cheats)

V9_SndEnd:                              ; (por debajo de Snd_Nop, 8A56h)

; ------------------------------------------------------------ en el hueco del motor del original
        code ! 8204h
; Motor (gancho Snd_HookEngine, una vez por frame del juego), como el 128K (80AA):
; periodo del tono C = (~(velocidad / 2) and FFh) * 4 (* 8 en marcha larga) + 400
; (+ 600 y volumen 12 en un tunel, en vez de 15). Callado con vCatchState >= 3.
V9_Engine:
        ld      hl,(vSpeed)
        or      a
        rr      h
        ld      a,l
        rra
        cpl
        ld      l,a
        ld      a,(vGear)
        and     a
        jr      z,.g
        add     hl,hl
.g:     add     hl,hl
        add     hl,hl
        ld      a,(vInTunnel)
        and     a
        ld      de,0190h
        ld      a,0Fh
        jr      z,.t
        ld      de,0258h
        ld      a,0Ch
.t:     add     hl,de
        ld      (VGM_ENG),hl
        ld      e,a
        ld      a,(vCatchState)         ; como el original (8234): callado desde que el
        cp      3                       ; coche se ha parado en el arcen
        ld      a,e
        jr      c,.v
        xor     a
.v:     ld      (VGM_ENG+2),a
        ret


; Ganchos de sonido del original (83B5-83CC; en el 128K llamaban a su driver AY).
V9_SirenOn:                             ; Snd_HookTarget: coche objetivo a la vista
        xor     a
        ld      (VGM_ATT),a             ; (si se estaba apagando, vuelve a empezar)
        ld      a,SND_SIRENA
        jp      V9_SndPlay
V9_TurboOn:                             ; Snd_HookTurbo
        ld      a,SND_TURBO
        jp      V9_SndPlay
V9_Title:                               ; Snd_HookTitle: titulo con la demo, con su musica
        ld      a,SND_TITULO
        call    V9_SndPlay
        call    Title_Loop
        xor     a
        jp      V9_SndStop
V9_SndEnd2:                             ; (por debajo de Title_Loop, 8258h)

; ------------------------------------------------------------ tras el marcador (370D-3C14: VDP_DumpWindow y
; VDP_DumpScreenSafe, que el port no usa)
        code ! V9_HudEnd
; --- desde el juego (con o sin interrupciones)

; Toca el sonido A (SND_*, build/sound.inc) en su pista, desde el principio.
V9_SndPlay:
        ld      l,a
        add     a,a
        add     a,a
        add     a,a
        sub     l                       ; 7 bytes por sonido
        ld      e,a
        ld      d,0
        ld      hl,TSnd
        add     hl,de
        ld      a,(hl)                  ; pista
        inc     hl
        push    hl
        call    V9_SndSlot
        ex      de,hl
        pop     hl
        call    V9_Iff
        di
        push    af
        ld      bc,6
        ldir
        pop     af
        ret     po
        ei
        ret

; Sustituye a Snd_Update (una vez por frame del juego). Como el original: pide el ruido de
; la cuneta (efecto 7) si se pisa fuera de la carretera; el motor; y toca el efecto pedido
; (Snd_Request: id 1-9, el de mas prioridad del frame; el 1 solo una vez de cada dos,
; como el original) en la pista de efectos. En la ROM de pruebas (SND_RND_EXACT) avanza el
; generador aleatorio del juego como lo hacian los efectos de ruido (una llamada a Rnd
; por cada clic: efecto 1, 100 de cada dos veces; 6, 104; 7, 480), para que la partida
; siga siendo la del original; en la ROM final no hace falta y ahorra hasta ~10 ms.
V9_SndUpdate:
        ld      a,(vInTunnel)
        and     a
        jr      nz,.t
        ld      a,(vRoadsideR)
        ld      hl,vRoadsideL
        or      (hl)
        ld      bc,0704h
        call    nz,Snd_Request
.t:     call    V9_Engine
        ld      hl,vSndReq
        ld      a,(hl)
        ld      (hl),0
        inc     hl
        ld      (hl),0                  ; vSndPrio
        if ORIG_INPUT = 0
        call    V9_ImpactGuard
        else
        or      a
        endif
        ret     z
        cp      1
        jr      nz,.go
        ld      a,(VGM_ALT)
        xor     1
        ld      (VGM_ALT),a
        ret     nz
        inc     a
.go:
        if ORIG_INPUT = 0
        ld      (VGM_EFFECT),a
        endif
        push    af
        add     a,SND_EFECTO1-1
        call    V9_SndPlay
        pop     af
        if SND_RND_EXACT
        ld      bc,104
        cp      6
        jr      z,.rnd
        ld      bc,480
        cp      7
        jr      z,.rnd
        cp      1
        ret     nz
        ld      bc,100
.rnd:   push    bc
        call    Rnd
        pop     bc
        dec     bc
        ld      a,b
        or      c
        jr      nz,.rnd
        endif
        ret

; Snd_HookStop: captura, fin de partida y cambio de escena. Calla el motor (hasta
; que la carrera lo vuelva a calcular, V9_Engine) y el turbo; la sirena se apaga con un fundido.
V9_SndHush:
        xor     a
        ld      (VGM_ENG+2),a
        ld      a,2
        call    V9_SndStop
        jp      V9_SirenFadeOut

        include "../build/sound.inc"
V9_SndEnd3:                             ; (por debajo de 3C15h: VDP_DumpScreen, parcheada)

; ------------------------------------------------------------ cuerpo de VDP_DumpScreen (3C18-3C69)
; El port sustituye su entrada (jp V9_DumpScreen) y nada salta dentro.
        code ! 3C18h
; B al registro C, si es de la pista (en su copia propia si la tiene)
V9_SndWr:
        ld      hl,(VGM_OWN)
        inc     hl
        inc     hl
        inc     hl
        ld      a,(hl)
        or      a
        jr      z,.com
        add     a,c
        ld      l,a
        ld      h,VGM_S0/256
        ld      (hl),b
        ret
.com:   ld      hl,(VGM_OWN)
        ld      a,c
        cp      7
        jr      z,.mix
        cp      14
        ret     nc
        cp      8
        jr      c,.bit
        inc     hl
        sub     8
.bit:   push    bc
        ld      b,a
        inc     b
        ld      a,(hl)
.sh:    rrca
        djnz    .sh
        pop     bc
        ret     nc
        ld      hl,VGM_REG
        ld      a,l
        add     a,c
        ld      l,a
        ld      (hl),b
        ld      a,c
        cp      13
        ret     nz
        ld      (VGM_R13),a
        ret
.mix:   inc     hl
        inc     hl
        ld      c,(hl)                  ; bits del mezclador de la pista
        ld      hl,VGM_REG+7
        ld      a,c
        cpl
        and     (hl)
        ld      (hl),a
        ld      a,b
        and     c
        or      (hl)
        ld      (hl),a
        ret

V9_SndEnd4:                             ; (por debajo de 3C6Ah: VDP_SetColors)

; ------------------------------------------------------------ trucos del Spectrum (84C4-84FA)
; Main_Cheats solo hace algo con vDebug (8000h) <> 0, que en MSX nunca pasa: el port salta
; directamente a Main_EndFrame (src/port.asm) y su cuerpo queda libre.
        code ! 84C4h
; Registros de cada pista: mascara de R0-R13 (palabra), bits del mezclador (R7) que son
; suyos y byte bajo de su copia propia (0 = la comun, VGM_REG).
TVgmOwn:        dw      3F7Fh           ; musica: todos
                db      3Fh,0
                dw      030Fh           ; sirena: R0-R3 (tonos A y B), R8-R9 (volumenes)
                db      1Bh,0           ;         tonos y ruidos de A y B
                dw      0470h           ; turbo: R4-R5 (tono C), R6 (ruido), R10
                db      24h,VGM_C2-(VGM_C2/256*256)
                dw      0470h           ; efecto: igual
                db      24h,VGM_C3-(VGM_C3/256*256)


; Silencia lo de una pista parada (HL -> sus registros en TVgmOwn): sus volumenes a 0 y
; sus bits del mezclador a 1 (apagados).
V9_SndRelease:
        push    hl
        inc     hl
        ld      a,(hl)                  ; R8-R13
        ld      hl,VGM_REG+8
        ld      b,3
.vol:   rrca
        jr      nc,.nv
        ld      (hl),0
.nv:    inc     hl
        djnz    .vol
        pop     hl
        inc     hl
        inc     hl
        ld      a,(hl)
        ld      hl,VGM_REG+7
        or      (hl)
        ld      (hl),a
        ret
; Final de V9_SndStop: silencia la pista y repone las interrupciones (estado en la pila).
V9_SndRelStop:
        call    V9_SndRelease
        pop     af
        ret     po
        ei
        ret

V9_SndEnd5:                             ; (por debajo de 84FBh: Main_EndFrame)
