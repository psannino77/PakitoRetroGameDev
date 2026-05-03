; ---------------------------------------------------------------------------
; Pakito Retro Game Dev — splash PRG (64tass), Multicolor BITMAP mode.
;
; CharPad export interpreted as MC-bitmap-via-charset:
;   Chars.bin  (1600B = 200 blocks * 8 bytes)         : MC bitmap blocks
;   Map.bin    (1000B = 40x25)                        : per-cell block index
;   CharAttribs_L1.bin (200B per block)               : color RAM byte
;   CharAttribs_L2.bin (200B per block, nibble-pack)  : screen RAM (MC1|MC2)
;   CharAttribs_M.bin (200B): material, unused.
;
; VIC: bank 0; bitmap @ $2000-$3F3F; screen @ $0400; D018=$18; D016=$18;
;      D011=$3B (BMM=1, DEN=1, RSEL=1); $DD00 -> bank 0.
; ---------------------------------------------------------------------------

BG      = $00          ; $D021 background  (0 black)
BORDER  = $00          ; $D020 border

; Zero-page workspace
ZP_MAP   = $02
ZP_DST   = $04
ZP_IDX   = $06
ZP_CTR   = $08
ZP_SRC   = $FB

SCREEN   = $0400
BITMAP   = $2000
COLRAM   = $D800

* = $0801
        ; BASIC stub: 10 SYS 2061
        .byte $0B,$08,$0A,$00,$9E,$32,$30,$36,$31,$00,$00,$00

* = $080D
start:
        sei
        lda #$0B                ; blank display while building
        sta $D011

        lda $DD00               ; VIC bank 0
        and #$FC
        ora #$03
        sta $DD00

        lda #BORDER
        sta $D020
        lda #BG
        sta $D021

        lda #$18                ; screen $0400, bitmap $2000
        sta $D018
        lda #$18                ; multicolor + CSEL
        sta $D016

        ; Clear bitmap $2000-$3FFF (32 pages)
        lda #$00
        sta ZP_DST
        lda #$20
        sta ZP_DST+1
        ldy #$00
        tya
clr_bm:
        sta (ZP_DST),y
        iny
        bne clr_bm
        inc ZP_DST+1
        ldx ZP_DST+1
        cpx #$40
        bne clr_bm

        ; Build bitmap: for each cell 0..999 copy 8 bytes from
        ;   chars_src + map[cell]*8  ->  $2000 + cell*8
        lda #<map_src
        sta ZP_MAP
        lda #>map_src
        sta ZP_MAP+1
        lda #$00
        sta ZP_DST
        lda #$20
        sta ZP_DST+1
        lda #<1000
        sta ZP_CTR
        lda #>1000
        sta ZP_CTR+1
bm_loop:
        ldy #$00
        lda (ZP_MAP),y
        sta ZP_IDX
        lda #$00
        sta ZP_IDX+1
        asl ZP_IDX
        rol ZP_IDX+1
        asl ZP_IDX
        rol ZP_IDX+1
        asl ZP_IDX
        rol ZP_IDX+1
        clc
        lda ZP_IDX
        adc #<chars_src
        sta ZP_SRC
        lda ZP_IDX+1
        adc #>chars_src
        sta ZP_SRC+1
        ldy #$07
bm_cp:
        lda (ZP_SRC),y
        sta (ZP_DST),y
        dey
        bpl bm_cp
        inc ZP_MAP
        bne bm_m1
        inc ZP_MAP+1
bm_m1:
        clc
        lda ZP_DST
        adc #$08
        sta ZP_DST
        bcc bm_d1
        inc ZP_DST+1
bm_d1:
        lda ZP_CTR
        bne bm_dec_lo
        dec ZP_CTR+1
bm_dec_lo:
        dec ZP_CTR
        lda ZP_CTR
        ora ZP_CTR+1
        bne bm_loop

        ; Build screen RAM (L2[map[i]]) and color RAM (L1[map[i]]).
        ldx #$00
sc_p0:
        lda map_src+$000,x
        tay
        lda l2_src,y
        sta SCREEN+$000,x
        lda l1_src,y
        sta COLRAM+$000,x
        lda map_src+$100,x
        tay
        lda l2_src,y
        sta SCREEN+$100,x
        lda l1_src,y
        sta COLRAM+$100,x
        lda map_src+$200,x
        tay
        lda l2_src,y
        sta SCREEN+$200,x
        lda l1_src,y
        sta COLRAM+$200,x
        inx
        bne sc_p0
        ldx #$00
sc_p3:
        lda map_src+$300,x
        tay
        lda l2_src,y
        sta SCREEN+$300,x
        lda l1_src,y
        sta COLRAM+$300,x
        inx
        cpx #$E8                ; 232 -> 768+232 = 1000
        bne sc_p3

        lda #$3B                ; MC bitmap, DEN, RSEL, raster $1B
        sta $D011

        cli
forever:
        jmp forever

; ----- Embedded data --------------------------------------------------------
chars_src:
        .binary "../../assets/splash/bin/Pakito_final - Chars.bin"
map_src:
        .binary "../../assets/splash/bin/Pakito_final - Map (40x25), 8bpc.bin"
l1_src:
        .binary "../../assets/splash/bin/Pakito_final - CharAttribs_L1.bin"
l2_src:
        .binary "../../assets/splash/bin/Pakito_final - CharAttribs_L2.bin"
