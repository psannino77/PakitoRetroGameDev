; Step2: clear_screen + raster IRQ that toggles border color on each frame.
; Expected: black inner area, border that pulses through colors rapidly.
        .include "build/loader/loader_texts.inc"

SCREEN  = $0400
COLRAM  = $D800
CPU_IRQVEC = $0314

* = $0801
        .byte $0B,$08,$0A,$00,$9E,$32,$30,$36,$31,$00,$00,$00 ; 10 SYS 2061

* = $080D
start:
        sei
        lda #$7F
        sta $DC0D
        sta $DD0D
        lda $DC0D
        lda $DD0D

        lda $DD00
        and #$FC
        ora #$03
        sta $DD00

        lda #$36
        sta $01

        lda #$14            ; screen $0400, charset rom upper $1000
        sta $D018
        lda #$1B
        sta $D011
        lda #$08
        sta $D016

        lda #$00            ; black border + bg
        sta $D020
        sta $D021

        jsr clear_screen

        ; Install raster IRQ on line 0
        lda #<irq
        sta CPU_IRQVEC
        lda #>irq
        sta CPU_IRQVEC+1
        lda #$01
        sta $D01A           ; enable raster IRQ
        lda #0
        sta $D012
        lda $D011
        and #$7F
        sta $D011
        lda #$01
        sta $D019           ; ack
        cli

forever:
        jmp forever

clear_screen:
        ldx #0
        lda #$20
cs:     sta SCREEN+$000,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$2E8,x
        inx
        bne cs
        ldx #0
        lda #$01            ; white in color RAM (visible if any chars appear)
ccol:   sta COLRAM+$000,x
        sta COLRAM+$100,x
        sta COLRAM+$200,x
        sta COLRAM+$2E8,x
        inx
        bne ccol
        rts

frame_ctr .byte 0

irq:
        inc frame_ctr
        lda frame_ctr
        sta $D020           ; cycle border color each frame
        lda #$01
        sta $D019           ; ack raster IRQ
        jmp $EA31           ; back through KERNAL IRQ epilogue
