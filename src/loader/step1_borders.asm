; Step1: just set border to green and loop. If you see a green border with
; default light blue inner area, the basic execution + memory map setup
; works.
        .include "build/loader/loader_texts.inc"
        .if 0
        .include "build/sid/loader_sid.inc"
        .endif

* = $0801
        .byte $0B,$08,$0A,$00,$9E,$32,$30,$36,$31,$00,$00,$00 ; 10 SYS 2061

* = $080D
start:
        sei
        lda #$7F
        sta $DC0D       ; CIA1 ICR off
        sta $DD0D       ; CIA2 ICR off
        lda $DC0D
        lda $DD0D

        lda $DD00       ; VIC bank 0
        and #$FC
        ora #$03
        sta $DD00

        lda #$36        ; BASIC out, KERNAL+I/O in
        sta $01

        lda #$05        ; green border
        sta $D020
        lda #$00        ; black bg
        sta $D021

        lda #$1B        ; default screen on
        sta $D011
        lda #$08
        sta $D016

forever:
        jmp forever
