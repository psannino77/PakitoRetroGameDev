; ---------------------------------------------------------------------------
; Pakito Retro Game Dev - Ocean-style pre-game loader (64tass syntax).
;
; Visual reference: assets/loader/mockup/Screenshot_*.png
;   - All-black screen + black background.
;   - Top and bottom border filled with rainbow horizontal bars (raster IRQ).
;   - Mid-screen single text strip:
;
;         <TITLE> ............................. NOW LOADING
;
;     framed by a thin yellow horizontal line above and below.
;   - Music starts immediately (with the screen still empty).
;   - After a short silent intro the strip appears; the title cycles every
;     LOADER_CYCLE_FRAMES frames through the entries declared in
;     assets/loader/loader_texts.txt (e.g. OCEAN -> CODE: ... -> MUSIC: ...).
;
; The text table and timing are generated at build time by
; scripts/tools/loader_texts_compile.py and consumed below as
; LOADER_ENTRIES_COUNT / LOADER_CYCLE_FRAMES / LOADER_INITIAL_SILENCE /
; LOADER_TOTAL_FRAMES.
;
; Public API:
;   loader_set_progress  (A = 0..100)  -- accepted, currently advisory only;
;                                          the strip is time-driven.
;
; Memory map:
;   $0801          BASIC stub (SYS 2061)
;   $080D          start (loader code + data)
;   $1000+         (optional) SID payload, when present
;   $0400-$07E7    screen RAM
;   $D800-$DBE7    color RAM
;   $D018 = $14    charset = ROM uppercase
;
; Build (64tass):
;   ./scripts/build_loader.sh
; ---------------------------------------------------------------------------

; ---- Generated configuration (texts + timings) -----------------------------
        .include "build/loader/loader_texts.inc"

; ---- Visual constants ------------------------------------------------------
; Strip is 3 text rows centered vertically in the display (yellow
; separators on rows STRIP_ROW-1 and STRIP_ROW+1). The strip carries
; "NOW LOADING", the first title, and the soft-scrolling intro text.
; Once the scroll has played one full pass the loader switches to
; bitmap mode and the strip is no longer visible.
STRIP_ROW       = 12                    ; text row (vertical centre)
SEP_TOP_ROW     = STRIP_ROW - 1
SEP_BOT_ROW     = STRIP_ROW + 1
STRIP_RASTER_ON = 48 + (STRIP_ROW * 8) ; just before the text row begins
STRIP_RASTER_OFF = STRIP_RASTER_ON + 12 ; after the strip visual area
SPLASH_ROWS     = 25
SPLASH_COLS     = 40
; Reveal pacing: 1000 tiles * SPLASH_STEP_FRAMES frames at 50 Hz = total
; reveal time in seconds * 50. With 3 frames/tile the full reveal takes
; ~60 s; combined with the ~64 s spent on silence + intros + one full
; scroll pass, the splash settles roughly a minute before the music
; tape ends (LOADER_TOTAL_FRAMES = 9000 frames = 180 s), giving the
; finished image a quiet hold before auto-transitioning to GAME.
SPLASH_STEP_FRAMES = 3
PREGAME_BLACK_FRAMES = 750
PREGAME_BLACK_START = LOADER_TOTAL_FRAMES - PREGAME_BLACK_FRAMES

SEP_CHAR        = $40                   ; horizontal line in upper charset
SEP_COL         = $07                   ; yellow
TEXT_COL        = $01                   ; white
BG_COL          = $00                   ; black
STRIP_PAD       = 2                     ; blank columns left/right of strip

; ---- Zero-page workspace ---------------------------------------------------
ZP_TMP          = $02
ZP_TMP2         = $03
ZP_BARSCROLL    = $04
ZP_BAND_IDX     = $0C                   ; index into band_lengths
ZP_BAND_RUN     = $0D                   ; remaining lines in current run
ZP_BAND_COL     = $0E                   ; current band color
ZP_FRAME_LO     = $05
ZP_FRAME_HI     = $06
ZP_CYC_LO       = $07
ZP_CYC_HI       = $08
ZP_ENTRY        = $09                   ; intro phase: 0=NOW LOADING, 1=title
ZP_STRIP_ON     = $0A                   ; non-zero once strip is visible
ZP_PROGRESS     = $0B                   ; advisory progress (0..100)
ZP_SCROLL_ON    = $0F                   ; non-zero once scroll mode active
ZP_FX           = $10                   ; soft-scroll fine X (0..7)
ZP_SRCP         = $11                   ; scroll source ptr (lo/hi)  uses $11/$12
ZP_IRQSTATE     = $13                   ; 0=top split, 1=bottom split
ZP_SPLASH_PENDING = $14                 ; init bitmap reveal in main loop
ZP_SPLASH_ON    = $15                   ; non-zero while splash mode is live
ZP_SPLASH_COL   = $16                   ; next splash column to reveal (0..39)
ZP_SPLASH_WAIT  = $17                   ; frame countdown between columns
ZP_SPLASH_CHRSRC = $18                  ; linear src ptr into splash_chars (+8/tile)
ZP_SPLASH_BMP   = $1A                   ; bitmap dst ptr (lo/hi)
ZP_SPLASH_SCR   = $1C                   ; splash screen RAM ptr (lo/hi)
ZP_SPLASH_L1SRC = $1E                   ; linear src ptr into splash_l1 (+1/tile)
ZP_SPLASH_COLPTR = $20                  ; color RAM ptr (lo/hi)
ZP_INPUT_ARMED  = $22                   ; fresh-press gate for skip input
ZP_PREGAME_BLACK = $23                  ; blackout phase before final GAME screen
ZP_SRC          = $FB                   ; copy ptr (lo/hi)
ZP_DST          = $FD                   ; copy ptr (lo/hi)

SCREEN          = $0400
SPLASH_SCREEN   = $4400
SPLASH_BITMAP   = $6000
COLRAM          = $D800

; ---- Hardware registers ----------------------------------------------------
VIC_BORDER      = $D020
VIC_BG          = $D021
VIC_CTRL1       = $D011
VIC_RASTER      = $D012
VIC_CTRL2       = $D016
VIC_MEMPTR      = $D018
VIC_IRQ         = $D019
VIC_IMR         = $D01A
CIA1_ICR        = $DC0D
CIA2_ICR        = $DD0D
CIA2_PRA        = $DD00
CPU_IRQVEC      = $0314

; ===========================================================================
* = $0801
        .byte $0B,$08,$0A,$00,$9E,$32,$30,$36,$31,$00,$00,$00 ; 10 SYS 2061

* = $080D
start:
        sei
        lda #$7F
        sta CIA1_ICR
        sta CIA2_ICR
        lda CIA1_ICR
        lda CIA2_ICR

        lda CIA2_PRA                    ; VIC bank 0
        and #$FC
        ora #$03
        sta CIA2_PRA

        ; --- CPU memory map: BASIC OFF, KERNAL ON, I/O on -----------------
        ; The Ocean Loader 5 SID lives at $B43E-$C72B, i.e. *under* the
        ; BASIC ROM ($A000-$BFFF). With the default $01 = $37 BASIC ROM is
        ; mapped there and `JSR SID_PLAY` would JAM on ROM bytes.
        ; $01 = $36 banks: LORAM=0 (BASIC out), HIRAM=1 (KERNAL in),
        ; CHAREN=1 (I/O at $D000-$DFFF in). KERNAL must stay mapped because
        ; the IRQ vector at $FFFE-$FFFF is fetched from KERNAL ROM and the
        ; default IRQ handler chain goes through ($0314).
        lda #$36
        sta $01

        lda #$14                        ; screen $0400, charset ROM upper $1000
        sta VIC_MEMPTR

        lda #$1B
        sta VIC_CTRL1
        lda #$08
        sta VIC_CTRL2

        lda #BG_COL
        sta VIC_BORDER
        sta VIC_BG

        jsr clear_screen                ; full black, no decorations yet

        ; --- Stage SID payload from inline copy to its native load addr ---
        jsr sid_stage

        ; --- Reset state ---
        lda #0
        sta ZP_BARSCROLL
        sta ZP_FRAME_LO
        sta ZP_FRAME_HI
        sta ZP_ENTRY
        sta ZP_STRIP_ON
        sta ZP_PROGRESS
        sta ZP_SCROLL_ON
        sta done_flag
        sta skip_prompt_flag
        sta ZP_SPLASH_PENDING
        sta ZP_SPLASH_ON
        sta ZP_SPLASH_COL
        sta ZP_SPLASH_WAIT
        sta ZP_INPUT_ARMED
        sta ZP_PREGAME_BLACK
        lda #0
        sta ZP_FX
        lda #<scroll_text
        sta ZP_SRCP
        lda #>scroll_text
        sta ZP_SRCP+1
        lda #<LOADER_CYCLE_FRAMES
        sta ZP_CYC_LO
        lda #>LOADER_CYCLE_FRAMES
        sta ZP_CYC_HI

        jsr music_init
        jsr install_irq
        jsr install_nmi                 ; CIA2 timer drives border toggle

        cli

main_loop:
        jsr poll_any_input
        beq ml_arm_input
        lda ZP_INPUT_ARMED
        beq ml_post_input
        ; Block input-driven exit until the splash reveal has fully
        ; completed. Two cases would otherwise leak through:
        ;   - before splash starts (ZP_SPLASH_ON=0): autostart's lingering
        ;     RETURN key could fire main_skip_intro during the scroll
        ;     phase.
        ;   - during the reveal (ZP_SPLASH_ON=1, ZP_BARSCROLL<SPLASH_ROWS):
        ;     any keypress would cut the reveal short.
        ; Only after the reveal completes (ZP_SPLASH_ON=1 and BARSCROLL
        ; has reached SPLASH_ROWS) does input transfer control to GAME.
        lda ZP_SPLASH_ON
        beq ml_post_input
        lda ZP_BARSCROLL
        cmp #SPLASH_ROWS
        bcc ml_post_input
        jmp main_skip_intro
ml_arm_input:
        lda #1
        sta ZP_INPUT_ARMED
ml_post_input:
        lda ZP_SPLASH_PENDING
        beq ml_wait
        jsr splash_init
ml_wait:
        lda done_flag
        beq main_loop
main_skip_intro:

        ; Music + raster IRQ keep running while game_stub either shows the
        ; final prompt or immediately hands off after an early skip input.
        jmp game_stub

; ===========================================================================
; Public API
; ===========================================================================

; loader_set_progress: A = 0..100. Stored for external observers; the
; on-screen strip is currently driven by the frame timer (intro mode).
loader_set_progress:
        cmp #101
        bcc lsp_ok
        lda #100
lsp_ok:
        sta ZP_PROGRESS
        rts

; poll_any_input:
;   A = 1 if any keyboard key is pressed, or if any joystick direction/fire
;   is active on port 2. The keyboard probe also sees joystick port 1 lines,
;   so either joystick can be used to skip/continue.
poll_any_input:
        lda CIA1_PRA
        sta ZP_TMP2
        and #$1F
        cmp #$1F
        bne pai_pressed

        lda #$00
        sta CIA1_PRA
        lda CIA1_PRB
        cmp #$FF
        bne pai_pressed_restore

        lda ZP_TMP2
        sta CIA1_PRA
        lda #$00
        rts

pai_pressed_restore:
        lda ZP_TMP2
        sta CIA1_PRA
pai_pressed:
        lda #$01
        rts

set_text_mode:
        lda CIA2_PRA
        and #$FC
        ora #$03                        ; VIC bank 0
        sta CIA2_PRA
        lda #$14                        ; screen $0400, ROM uppercase charset
        sta VIC_MEMPTR
        lda #$1B
        sta VIC_CTRL1
        lda #$08
        sta VIC_CTRL2
        rts

set_splash_mode:
        lda CIA2_PRA
        and #$FC
        ora #$02                        ; VIC bank 1 ($4000-$7FFF)
        sta CIA2_PRA
        lda #$18                        ; screen $4400, bitmap $6000
        sta VIC_MEMPTR
        lda #$18                        ; multicolor + CSEL
        sta VIC_CTRL2
        lda #$3B                        ; bitmap mode, DEN, RSEL
        sta VIC_CTRL1
        rts

clear_splash_buffers:
        lda #$00
        sta ZP_SPLASH_BMP
        lda #>SPLASH_BITMAP
        sta ZP_SPLASH_BMP+1
        ldy #$00
        tya
csb_bm:
        sta (ZP_SPLASH_BMP),y
        iny
        bne csb_bm
        inc ZP_SPLASH_BMP+1
        lda ZP_SPLASH_BMP+1
        cmp #$80
        bne csb_bm

        ldx #$00
        lda #$00
csb_sc:
        sta SPLASH_SCREEN+$000,x
        sta SPLASH_SCREEN+$100,x
        sta SPLASH_SCREEN+$200,x
        sta SPLASH_SCREEN+$2E8,x
        inx
        bne csb_sc

        ldx #$00
csb_cr:
        sta COLRAM+$000,x
        sta COLRAM+$100,x
        sta COLRAM+$200,x
        sta COLRAM+$2E8,x
        inx
        bne csb_cr
        rts

splash_init:
        lda #$0B                        ; blank display while buffers clear
        sta VIC_CTRL1
        jsr clear_splash_buffers
        jsr set_splash_mode
        lda #$00
        sta ZP_BARSCROLL
        sta ZP_SPLASH_PENDING
        sta ZP_SPLASH_COL
        sta ZP_SPLASH_WAIT
        sta ZP_SCROLL_ON
        lda #<splash_chars
        sta ZP_SPLASH_CHRSRC
        lda #>splash_chars
        sta ZP_SPLASH_CHRSRC+1
        lda #<splash_l1
        sta ZP_SPLASH_L1SRC
        lda #>splash_l1
        sta ZP_SPLASH_L1SRC+1
        ; L2 source is accessed via self-modified absolute load instructions
        ; (st_l2_load_op + 1/+2). Seed them here.
        lda #<splash_l2
        sta st_l2_load_op + 1
        lda #>splash_l2
        sta st_l2_load_op + 2
        lda #<SPLASH_BITMAP
        sta ZP_SPLASH_BMP
        lda #>SPLASH_BITMAP
        sta ZP_SPLASH_BMP+1
        lda #<SPLASH_SCREEN
        sta ZP_SPLASH_SCR
        lda #>SPLASH_SCREEN
        sta ZP_SPLASH_SCR+1
        lda #<COLRAM
        sta ZP_SPLASH_COLPTR
        lda #>COLRAM
        sta ZP_SPLASH_COLPTR+1
        lda #$01
        sta ZP_SPLASH_ON
        rts

splash_tick:
        lda ZP_BARSCROLL
        cmp #SPLASH_ROWS
        bcs st_done
        lda ZP_SPLASH_WAIT
        beq st_render
        sec
        sbc #1
        sta ZP_SPLASH_WAIT
        rts
st_render:
        jsr splash_render_tile
        jsr splash_advance_tile
        lda #SPLASH_STEP_FRAMES - 1
        sta ZP_SPLASH_WAIT
st_done:
        rts

; splash_render_tile: linear renderer for the TokiFinal asset set.
; splash_chars holds one unique 8-byte cell per screen position (1000 cells
; total). splash_l1 / splash_l2 hold one color RAM / screen RAM byte per
; cell. No map indirection: each pointer just walks linearly through its
; own source buffer. L2 is read via a self-modified absolute load
; (st_l2_load_op) so we keep the IRQ-time ZP footprint at the same slots
; the original splash code used and avoid any chance of clashing with
; the SID player on extra zero-page bytes.
splash_render_tile:
        ldy #$07
src_cp:
        lda (ZP_SPLASH_CHRSRC),y
        sta (ZP_SPLASH_BMP),y
        dey
        bpl src_cp

        ldy #$00
st_l2_load_op:
        lda $FFFF                       ; operand patched: splash_l2 + tile
        sta (ZP_SPLASH_SCR),y
        lda (ZP_SPLASH_L1SRC),y
        sta (ZP_SPLASH_COLPTR),y
        rts

; splash_advance_tile: post-render advance.
; Walks cursors forward by one tile: CHRSRC +8, BMP +8, SCR +1, COLPTR +1,
; L1SRC +1, and the self-modified L2 load operand +1. On wrap from col 39
; the cursors already point at row N+1 col 0 so no extra "advance row" is
; needed for the normal flow.
splash_advance_tile:
        clc
        lda ZP_SPLASH_CHRSRC
        adc #8
        sta ZP_SPLASH_CHRSRC
        lda ZP_SPLASH_CHRSRC+1
        adc #0
        sta ZP_SPLASH_CHRSRC+1

        clc
        lda ZP_SPLASH_BMP
        adc #8
        sta ZP_SPLASH_BMP
        lda ZP_SPLASH_BMP+1
        adc #0
        sta ZP_SPLASH_BMP+1

        inc ZP_SPLASH_SCR
        bne sat_scr_ok
        inc ZP_SPLASH_SCR+1
sat_scr_ok:
        inc ZP_SPLASH_COLPTR
        bne sat_col_ok
        inc ZP_SPLASH_COLPTR+1
sat_col_ok:
        inc ZP_SPLASH_L1SRC
        bne sat_l1_ok
        inc ZP_SPLASH_L1SRC+1
sat_l1_ok:
        inc st_l2_load_op + 1
        bne sat_l2_ok
        inc st_l2_load_op + 2
sat_l2_ok:
        inc ZP_SPLASH_COL
        lda ZP_SPLASH_COL
        cmp #SPLASH_COLS
        bcc sat_done
        lda #0
        sta ZP_SPLASH_COL
        inc ZP_BARSCROLL
sat_done:
        rts

; splash_advance_row: skip-mode helper. Advances only the destination
; cursors by one full row (bmp +320, scr +40, colptr +40). The source
; pointers (CHRSRC / L1SRC / L2 self-mod operand) are intentionally NOT
; advanced so the rows that resume after the strip continue drawing from
; the same source row that was next in line, instead of skipping 3 source
; rows. The bottom 3 source rows of the image end up clipped off-screen.
splash_advance_row:
        clc
        lda ZP_SPLASH_BMP
        adc #<320
        sta ZP_SPLASH_BMP
        lda ZP_SPLASH_BMP+1
        adc #>320
        sta ZP_SPLASH_BMP+1

        clc
        lda ZP_SPLASH_SCR
        adc #40
        sta ZP_SPLASH_SCR
        lda ZP_SPLASH_SCR+1
        adc #0
        sta ZP_SPLASH_SCR+1

        clc
        lda ZP_SPLASH_COLPTR
        adc #40
        sta ZP_SPLASH_COLPTR
        lda ZP_SPLASH_COLPTR+1
        adc #0
        sta ZP_SPLASH_COLPTR+1

        rts

splash_skip_strip_rows:
        lda ZP_SPLASH_COL
        bne ssr_done
ssr_check:
        lda ZP_BARSCROLL
        cmp #SEP_TOP_ROW
        beq ssr_skip
        cmp #STRIP_ROW
        beq ssr_skip
        cmp #SEP_BOT_ROW
        beq ssr_skip
        rts
ssr_skip:
        inc ZP_BARSCROLL
        jsr splash_advance_row
        lda ZP_BARSCROLL
        cmp #SPLASH_ROWS
        bcc ssr_check
ssr_done:
        rts

; ===========================================================================
; Drawing helpers
; ===========================================================================

clear_screen:
        ldx #0
        lda #$20                        ; space
cs_loop:
        sta SCREEN+$000,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$2E8,x
        inx
        bne cs_loop
        ldx #0
        lda #BG_COL                     ; color RAM = black initially
ccol_loop:
        sta COLRAM+$000,x
        sta COLRAM+$100,x
        sta COLRAM+$200,x
        sta COLRAM+$2E8,x
        inx
        bne ccol_loop
        rts

; show_strip: draw both yellow separator rows. Called once when the silent
; intro elapses.
show_strip:
        ldx #40
        lda #SEP_CHAR
ss_t:   dex
        sta SCREEN + SEP_TOP_ROW*40, x
        sta SCREEN + SEP_BOT_ROW*40, x
        bne ss_t
        ldx #40
        lda #$20                        ; clear strip text row with spaces
ss_tx:  dex
        sta SCREEN + STRIP_ROW*40, x
        bne ss_tx
        ldx #40
        lda #SEP_COL
ss_c:   dex
        sta COLRAM + SEP_TOP_ROW*40, x
        sta COLRAM + SEP_BOT_ROW*40, x
        bne ss_c
        ; Text row color: white in middle, BLACK in side padding cells so
        ; the soft-scroll buffer columns stay invisible behind the border.
        ldx #40
        lda #TEXT_COL
ss_tc:  dex
        sta COLRAM + STRIP_ROW*40, x
        bne ss_tc
        ldx #STRIP_PAD
        lda #BG_COL
ss_pc:  dex
        sta COLRAM + STRIP_ROW*40, x
        sta COLRAM + STRIP_ROW*40 + (40-STRIP_PAD), x
        bne ss_pc
        rts

show_centered_now_loading:
        lda #<loader_right_center
        sta ZP_SRC
        lda #>loader_right_center
        sta ZP_SRC+1
        jmp show_buffer_row

show_centered_first_title:
        lda #<loader_first_center
        sta ZP_SRC
        lda #>loader_first_center
        sta ZP_SRC+1
        jmp show_buffer_row

show_centered_final_title:
        lda #<loader_final_center
        sta ZP_SRC
        lda #>loader_final_center
        sta ZP_SRC+1
        jmp show_buffer_row

show_buffer_row:
        ldy #39
sbr_cp:
        lda (ZP_SRC),y
        sta SCREEN + STRIP_ROW*40, y
        dey
        bpl sbr_cp
        rts

; show_entry: copy entry ZP_ENTRY (0..N-1) into the strip text row.
show_entry:
        lda ZP_ENTRY
        ; src = loader_entries + entry*40
        ; entry*40 = entry*32 + entry*8
        sta ZP_TMP
        lda #0
        sta ZP_SRC+1
        lda ZP_TMP
        asl a                           ; *2
        rol ZP_SRC+1
        asl a                           ; *4
        rol ZP_SRC+1
        asl a                           ; *8
        rol ZP_SRC+1
        sta ZP_SRC                      ; ZP_SRC = entry*8
        ; add entry*32  (= entry shifted left 5)
        lda ZP_TMP
        asl a
        sta ZP_DST                      ; *2
        lda #0
        rol a
        sta ZP_DST+1
        asl ZP_DST                      ; *4
        rol ZP_DST+1
        asl ZP_DST                      ; *8
        rol ZP_DST+1
        asl ZP_DST                      ; *16
        rol ZP_DST+1
        asl ZP_DST                      ; *32
        rol ZP_DST+1
        clc
        lda ZP_SRC
        adc ZP_DST
        sta ZP_SRC
        lda ZP_SRC+1
        adc ZP_DST+1
        sta ZP_SRC+1
        ; now add base address of loader_entries
        clc
        lda ZP_SRC
        adc #<loader_entries
        sta ZP_SRC
        lda ZP_SRC+1
        adc #>loader_entries
        sta ZP_SRC+1
        ; copy 40 bytes -> SCREEN + STRIP_ROW*40
        ldy #39
se_cp:
        lda (ZP_SRC),y
        sta SCREEN + STRIP_ROW*40, y
        dey
        bpl se_cp
        ; Blank padded columns at both ends so text never touches border.
        ldy #STRIP_PAD
        lda #$20
se_pad: dey
        sta SCREEN + STRIP_ROW*40, y
        sta SCREEN + STRIP_ROW*40 + (40-STRIP_PAD), y
        bne se_pad
        rts

; ===========================================================================
; IRQ: stable rainbow bars in TOP and BOTTOM border, frame tick, music play,
; and strip cycling.
; ===========================================================================

install_irq:
        lda #<irq_handler
        sta CPU_IRQVEC
        lda #>irq_handler
        sta CPU_IRQVEC+1
        lda #$01
        sta VIC_IMR
        lda #0
        sta ZP_IRQSTATE
        lda #STRIP_RASTER_ON
        sta VIC_RASTER
        lda VIC_CTRL1
        and #$7F
        sta VIC_CTRL1
        lda #$01
        sta VIC_IRQ
        rts

uninstall_irq:
        lda #$00
        sta VIC_IMR
        lda #$31
        sta CPU_IRQVEC
        lda #$EA
        sta CPU_IRQVEC+1
        lda #$81
        sta CIA1_ICR
        lda CIA1_ICR
        rts

; ---------------------------------------------------------------------------
; NMI from CIA2 Timer A: drives the Ocean-style border colour toggle.
; A small period (~256 cycles) is used so the timer fires several times
; per raster line; the VIC steals cycles from the CPU during the display
; area, which jitters the actual NMI rate and produces irregular bands
; just like the original tape loader. Cost per NMI: ~25 cycles.
; ---------------------------------------------------------------------------
NMI_PERIOD      = 600

install_nmi:
        ; KERNAL NMI handler at $FE43 dispatches through ($0318); install
        ; our NMI there.
        sei
        lda #<nmi_handler
        sta $0318
        lda #>nmi_handler
        sta $0319
        ; Stop CIA2 timer A, clear pending IRQ flags
        lda #$00
        sta $DD0E                       ; CIA2 CRA: timer stopped
        lda #$7F
        sta $DD0D                       ; mask all CIA2 IRQ sources
        lda $DD0D                       ; ack any pending
        ; Program timer A latch
        lda #<NMI_PERIOD
        sta $DD04
        lda #>NMI_PERIOD
        sta $DD05
        ; Enable timer A underflow as NMI source
        lda #$81                        ; bit7=set, bit0=TA
        sta $DD0D
        ; Start timer A in continuous mode
        lda #$11                        ; bit0=start, bit4=force load
        sta $DD0E
        cli
        rts

uninstall_nmi:
        sei
        lda #$00
        sta $DD0E                       ; stop timer
        lda #$7F
        sta $DD0D                       ; mask
        lda $DD0D                       ; ack
        ; Restore default KERNAL NMI vector (RTI at $FE72 typically; safer:
        ; point to a tiny RTI we provide).
        lda #<nmi_rti
        sta $0318
        lda #>nmi_rti
        sta $0319
        cli
        rts

nmi_handler:
        pha
        lda ZP_PREGAME_BLACK
        bne nmi_blackout
        ; Music-driven bands: SID voice-3 oscillator output ($D41B) varies
        ; with the melody. Use bit 2 (mid frequency) as the toggle source so
        ; band thickness loosely follows the music.
        lda $D41B
        and #$05
        eor VIC_BORDER
        sta VIC_BORDER
        jmp nmi_done
nmi_blackout:
        lda #0
        sta VIC_BORDER
nmi_done:
        lda $DD0D                       ; ack CIA2 NMI
        pla
        rti

nmi_rti:
        rti

; ===========================================================================
; Soft-scroll: pixel-smooth right-to-left scroll on the strip text row.
; The whole screen is shifted by VIC_CTRL2 X-scroll; only the strip row has
; visible content, all other rows are spaces or uniform separator chars,
; so the visual effect is restricted to the strip text.
; ===========================================================================

; scroll_init: enter scroll mode and arm scroll state. The current strip
; text stays visible and keeps scrolling until the full scroll pass ends.
scroll_init:
        lda #7
        sta ZP_FX
        lda #0
        sta final_scroll_hold
        sta final_hold
        lda #<scroll_text
        sta ZP_SRCP
        lda #>scroll_text
        sta ZP_SRCP+1
        lda #1
        sta ZP_SCROLL_ON
        rts

; scroll_step: called every frame in scroll mode.
;   * Decrement fine X (0..7); when it wraps, shift strip row left by one
;     character and load the next char from scroll_text into the rightmost
;     visible column. When the source reaches the end of the scroll text,
;     wait a bit, then show the final centered prompt and hold it a little
;     longer before arming the splash reveal.
scroll_step:
        lda final_scroll_hold
        beq ss_no_prehold
        dec final_scroll_hold
        bne sst_done
        jsr show_centered_final_title
        lda #100
        sta final_hold
        rts
ss_no_prehold:
        lda final_hold
        beq ss_no_hold
        dec final_hold
        bne sst_done
        ; Hold elapsed: arm splash reveal in main loop.
        lda #1
        sta ZP_SPLASH_PENDING
        rts
ss_no_hold:
        lda ZP_FX
        sec
        sbc #2                          ; speed: 2 px / frame
        bpl ss_storefx
        clc
        adc #8                          ; wrap into 0..7
        sta ZP_FX
        jmp ss_shift
ss_storefx:
        sta ZP_FX
        rts
ss_shift:
        ; --- shift strip row: cols [SIDE_PAD .. 40-SIDE_PAD-1] ---
        ldx #STRIP_PAD
ss_sh:  lda SCREEN + STRIP_ROW*40 + 1, x
        sta SCREEN + STRIP_ROW*40, x
        inx
        cpx #(40 - STRIP_PAD)
        bcc ss_sh
        ; --- new char from source -> buffer column (one past visible inner)
        ldy #0
        lda (ZP_SRCP),y
        sta SCREEN + STRIP_ROW*40 + (40 - STRIP_PAD)
        ; --- advance source pointer ---
        inc ZP_SRCP
        bne ss_chk_end
        inc ZP_SRCP+1
ss_chk_end:
        ; --- end-of-scroll source check: one full pass ---
        sec
        lda ZP_SRCP
        sbc #<(scroll_text + LOADER_SCROLL_LEN)
        lda ZP_SRCP+1
        sbc #>(scroll_text + LOADER_SCROLL_LEN)
        bcc sst_done
        ; End of scroll text reached: stop scrolling, lock fine-X to 0,
        ; wait a beat, then show the final centered prompt and hold it.
        lda #0
        sta ZP_FX
        lda #50
        sta final_scroll_hold
sst_done:
        rts

final_scroll_hold .byte 0
final_hold      .byte 0

done_flag       .byte 0

irq_handler:
        ; Dual raster split:
        ;   state=0 @ STRIP_RASTER_ON: turn ON soft-scroll fine-X just
        ;     before the strip text row. Reprogram for STRIP_RASTER_OFF.
        ;   state=1 @ STRIP_RASTER_OFF: lock back to fixed fine-X=0 after
        ;     the strip ends. Run all bookkeeping. Reprogram for
        ;     STRIP_RASTER_ON.
        lda ZP_IRQSTATE
        bne ih_bot

        lda ZP_SPLASH_ON
        beq ih_top_scroll
        lda #$18
        sta VIC_CTRL2
        lda #1
        sta ZP_IRQSTATE
        lda #STRIP_RASTER_OFF
        sta VIC_RASTER
        lda #$01
        sta VIC_IRQ
        jmp $EA81

ih_top_scroll:
        lda ZP_FX
        ora #$08
        sta VIC_CTRL2
        lda #1
        sta ZP_IRQSTATE
        lda #STRIP_RASTER_OFF
        sta VIC_RASTER
        lda #$01
        sta VIC_IRQ
        jmp $EA81

ih_bot:
        lda ZP_SPLASH_ON
        beq ih_bot_scroll
        lda #$18
        sta VIC_CTRL2
        jmp ih_bot_tick

ih_bot_scroll:
        lda #$08
        sta VIC_CTRL2

ih_bot_tick:

        ; --- Frame tick (16-bit) ---
        inc ZP_FRAME_LO
        bne ft_nohi
        inc ZP_FRAME_HI
ft_nohi:

        ; --- Strip on/off ---
        lda ZP_SPLASH_ON
        beq sc_pending
        jsr splash_tick
        jmp strip_skip
sc_pending:
        lda ZP_SPLASH_PENDING
        beq sc_scroll
        jmp strip_skip
sc_scroll:
        lda ZP_SCROLL_ON
        beq sc_pre
        jsr scroll_step
        lda ZP_SPLASH_PENDING
        beq sc_scroll_skip
        lda #0
        sta ZP_SCROLL_ON
sc_scroll_skip:
        jmp strip_skip
sc_pre:
        lda ZP_STRIP_ON
        bne strip_cycle

        ; Not yet visible: wait for INITIAL_SILENCE to elapse.
        lda ZP_FRAME_HI
        cmp #>LOADER_INITIAL_SILENCE
        bcs strip_chk_lo
        jmp strip_skip
strip_chk_lo:
        bne strip_show
        lda ZP_FRAME_LO
        cmp #<LOADER_INITIAL_SILENCE
        bcs strip_show
        jmp strip_skip
strip_show:
        jsr show_strip
        jsr show_centered_now_loading
        lda #1
        sta ZP_STRIP_ON
        jmp strip_skip

strip_cycle:
        ; Decrement 16-bit cycle countdown.
        sec
        lda ZP_CYC_LO
        sbc #1
        sta ZP_CYC_LO
        lda ZP_CYC_HI
        sbc #0
        sta ZP_CYC_HI
        ora ZP_CYC_LO
        beq strip_cyc_end
        jmp strip_skip
strip_cyc_end:
        ; First cycle: replace centered NOW LOADING with the first title.
        lda ZP_ENTRY
        bne strip_start_scroll
strip_show_first:
        jsr show_centered_first_title
        lda #1
        sta ZP_ENTRY
        lda #<LOADER_CYCLE_FRAMES
        sta ZP_CYC_LO
        lda #>LOADER_CYCLE_FRAMES
        sta ZP_CYC_HI
        jmp strip_skip
strip_start_scroll:
        ; Clear the strip text row so the centered first title disappears
        ; before the scroll begins (otherwise it would be shifted left).
        ldx #40
        lda #$20
strip_clr:
        dex
        sta SCREEN + STRIP_ROW*40, x
        bne strip_clr
        ; Start the scrolling text phase; the final centered line is shown
        ; later when the loader finishes.
        jsr scroll_init
        lda #2
        sta ZP_ENTRY
        jmp strip_skip
strip_skip:

        ; --- Music play ---
        jsr music_play

        ; --- Early blackout before the music ends ---
        ; Fade the display to black a few seconds before the final handoff so
        ; the end of the music feels intentional instead of cutting directly
        ; from the picture to the game.
        lda ZP_PREGAME_BLACK
        bne done_check
        lda ZP_FRAME_HI
        cmp #>PREGAME_BLACK_START
        bcc done_check
        bne start_blackout
        lda ZP_FRAME_LO
        cmp #<PREGAME_BLACK_START
        bcc done_check
start_blackout:
        lda #1
        sta ZP_PREGAME_BLACK
        lda #0
        sta ZP_SPLASH_PENDING
        sta ZP_SPLASH_ON
        sta ZP_SCROLL_ON
        jsr set_text_mode
        jsr clear_screen
        lda #$00
        sta VIC_BORDER
        sta VIC_BG

        ; --- Done check: auto-transition when music ends ---
        ; Once the frame counter reaches LOADER_TOTAL_FRAMES AND the splash
        ; reveal has finished (ZP_BARSCROLL >= SPLASH_ROWS), set done_flag so
        ; main_loop exits to game_stub automatically.
done_check:
        lda ZP_FRAME_HI
        cmp #>LOADER_TOTAL_FRAMES
        bne irq_ack
        lda ZP_FRAME_LO
        cmp #<LOADER_TOTAL_FRAMES
        bne irq_ack
        ; Music finished. Only transition if splash is fully revealed.
        lda ZP_BARSCROLL
        cmp #SPLASH_ROWS
        bcc irq_ack                     ; reveal still in progress, wait
        lda #1
        sta done_flag
irq_ack:
        lda #0
        sta ZP_IRQSTATE
        lda #STRIP_RASTER_ON
        sta VIC_RASTER
        lda #$01
        sta VIC_IRQ
        ; Exit through KERNAL IRQ epilogue ($EA81 = pla/tay/pla/tax/pla/rti)
        ; so the A/X/Y pushed by the KERNAL on entry are properly restored.
        jmp $EA81

; ===========================================================================
; Music: a small generated include is always present (stub or real). It
; defines SID_PRESENT (0/1) and, when 1, SID_INIT / SID_PLAY plus the SID
; payload. Generated by scripts/tools/sid_extract.py via build_loader.sh.
; ===========================================================================

        .include "build/sid/loader_sid.inc"

music_init:
        .if SID_PRESENT != 0
        lda #0
        jmp SID_INIT
        .else
        rts
        .endif

music_play:
        .if SID_PRESENT != 0
        jmp SID_PLAY
        .else
        rts
        .endif

music_stop:
        ldx #$18
        lda #0
ms_l:   sta $D400,x
        dex
        bpl ms_l
        rts

; ---------------------------------------------------------------------------
; sid_stage: copy SID_SIZE bytes from `sid_payload` (inline data, in PRG)
; to SID_LOAD (typically $A000-$D000 area). Done once at boot so the PRG
; itself stays compact (no huge zero-fill gap up to SID_LOAD).
; ---------------------------------------------------------------------------
sid_stage:
        .if SID_PRESENT == 0
        rts
        .else
        lda #<sid_payload
        sta ZP_SRC
        lda #>sid_payload
        sta ZP_SRC+1
        lda #<SID_LOAD
        sta ZP_DST
        lda #>SID_LOAD
        sta ZP_DST+1
        ; 16-bit byte counter
        lda #<SID_SIZE
        sta ZP_TMP
        lda #>SID_SIZE
        sta ZP_TMP+1
ss_loop:
        lda ZP_TMP
        ora ZP_TMP+1
        beq ss_done
        ldy #0
        lda (ZP_SRC),y
        sta (ZP_DST),y
        inc ZP_SRC
        bne ss_s1
        inc ZP_SRC+1
ss_s1:
        inc ZP_DST
        bne ss_d1
        inc ZP_DST+1
ss_d1:
        sec
        lda ZP_TMP
        sbc #1
        sta ZP_TMP
        lda ZP_TMP+1
        sbc #0
        sta ZP_TMP+1
        jmp ss_loop
ss_done:
        rts
        .endif

; ===========================================================================
; Game stub
;
; When the loader timer elapses, we DON'T jump straight to the game: instead
; we replace the rotating strip with "PRESS FIRE OR ANY KEY" and wait for the
; user to acknowledge (so the user can actually read the credits and enjoy
; the music). Music + raster bars keep running until any key or joystick
; input is pressed.
; ===========================================================================

CIA1_PRA        = $DC00      ; joystick port 2 + keyboard rows
CIA1_PRB        = $DC01      ; keyboard columns

skip_prompt_flag .byte 0
game_hold_lo    .byte 0
game_hold_hi    .byte 0
game_frame      .byte 0
game_black_hold .byte 0

game_stub:
        lda done_flag
        bne gs_go
        lda #1
        sta skip_prompt_flag
        jmp gs_go

gs_go:
        lda #0
        sta skip_prompt_flag
        sta game_hold_lo
        sta game_hold_hi
        sta ZP_SPLASH_ON
        sta ZP_SCROLL_ON
        sta ZP_PREGAME_BLACK
        sei
        jsr music_stop
        jsr uninstall_irq
        jsr uninstall_nmi
        jsr set_text_mode
        cli
        ; --- Final placeholder: clear screen and show "GAME" ---
        lda #$00
        sta VIC_BORDER
        sta VIC_BG
        jsr clear_screen
        ldx #0
gs_p:   lda txt_game,x
        beq gs_d
        sta SCREEN + STRIP_ROW*40 + 18, x
        lda #$01
        sta COLRAM + STRIP_ROW*40 + 18, x
        inx
        bne gs_p
gs_d:
gs_h:   jmp gs_h
; ===========================================================================
; Data
; ===========================================================================

; "PRESS FIRE OR SPACE" in screen codes (uppercase charset).
txt_press:    .byte 16,18,5,19,5,32,6,9,18,5,32,15,18,32,19,16,1,3,5,0
txt_game:     .byte 7,1,13,5,0          ; "GAME"

band_palette:
        .byte LOADER_BAND_COLOR_A, LOADER_BAND_COLOR_B

; 64-entry pseudo-random run-length table. Values 1..7 keep band changes
; visible inside the small (50-line) top border, mimicking the irregular
; cadence of the Ocean tape loader bit-stream NMI handler.
band_lengths:
        .byte 2,5,1,7,3,4,2,6
        .byte 1,4,3,5,2,7,3,1
        .byte 6,2,4,1,5,3,2,7
        .byte 3,1,4,6,2,5,3,1
        .byte 7,2,4,3,1,5,2,6
        .byte 4,1,3,7,2,5,1,4
        .byte 6,3,2,5,1,7,3,4
        .byte 2,1,5,3,6,2,4,1

loader_first_center:
        .binary "build/loader/loader_first_center.bin"

loader_right_center:
        .binary "build/loader/loader_right_center.bin"

loader_final_center:
        .binary "build/loader/loader_final_center.bin"

; Strip text table: LOADER_ENTRIES_COUNT * 40 screen-codes.
loader_entries:
        .binary "build/loader/loader_texts.bin"

; Soft-scroll source: LOADER_SCROLL_LEN screen-codes, looped at runtime.
scroll_text:
        .binary "build/loader/loader_scroll.bin"

; SID payload (inline, copied to SID_LOAD at boot by sid_stage). Empty
; when no SID is configured.
        .if SID_PRESENT != 0
sid_payload:
        .binary "build/sid/loader_sid.bin"
        .endif

* = $8000
; TokiFinal asset set (40x25). Each cell uses one unique 8-byte chunk
; from splash_chars (8000 B = 1000*8); splash_l1 / splash_l2 hold the
; per-cell color RAM / screen RAM bytes (1000 B each). The map file is
; an identity table and is not needed by the linear renderer.
splash_chars:
        .binary "assets/splash/Toki Splash/TokiFinal - Chars.bin"
splash_l1:
        .binary "assets/splash/Toki Splash/TokiFinal - CharAttribs_L1.bin"
splash_l2:
        .binary "assets/splash/Toki Splash/TokiFinal - CharAttribs_L2.bin"
