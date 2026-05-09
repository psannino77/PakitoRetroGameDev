; Minimal smoke-test: BASIC stub + SYS 2061 + infinite loop that toggles
; the border color. If you see the border flickering rapidly between colors,
; the BASIC stub + autostart path works; if the screen stays the default
; light blue, the PRG isn't being executed at all.
* = $0801
        .byte $0B,$08,$0A,$00,$9E,$32,$30,$36,$31,$00,$00,$00 ; 10 SYS 2061

* = $080D
start:
        sei
        ldx #$00
loop:
        stx $D020       ; border
        stx $D021       ; bg
        inx
        jmp loop
