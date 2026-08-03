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
; Strip is just 3 text rows around row 12 (yellow separators on rows 11
; and 13). The whole display area stays solid black; the Ocean bands
; appear only in the top and bottom screen *border*.
STRIP_ROW       = 12                    ; text row (mid screen)
SEP_TOP_ROW     = STRIP_ROW - 1
SEP_BOT_ROW     = STRIP_ROW + 1

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
ZP_SRCP         = $11                   ; scroll source ptr (lo/hi)
ZP_IRQSTATE     = $13                   ; 0=top split, 1=bottom split
ZP_SRC          = $FB                   ; copy ptr (lo/hi)
ZP_DST          = $FD                   ; copy ptr (lo/hi)

SCREEN          = $0400
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
        bne main_skip_intro
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
        lda #144                        ; just before strip text row 12
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
        ; Music-driven bands: SID voice-3 oscillator output ($D41B) varies
        ; with the melody. Use bit 2 (mid frequency) as the toggle source so
        ; band thickness loosely follows the music.
        lda $D41B
        and #$05
        eor VIC_BORDER
        sta VIC_BORDER
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

; scroll_init: enter scroll mode. Clear the text row to spaces (so the
; static OCEAN ... NOW LOADING entry disappears) and arm scroll state.
scroll_init:
        ldx #40
        lda #$20
si_l:   dex
        sta SCREEN + STRIP_ROW*40, x
        bne si_l
        lda #7
        sta ZP_FX
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
;     visible column. Wrap source pointer at scroll_text+LOADER_SCROLL_LEN.
;   * Always rewrite VIC_CTRL2 with the current fine value.
scroll_step:
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
        ; --- advance source pointer with wrap ---
        inc ZP_SRCP
        bne ss_chk
        inc ZP_SRCP+1
ss_chk:
        sec
        lda ZP_SRCP
        sbc #<(scroll_text + LOADER_SCROLL_LEN)
        lda ZP_SRCP+1
        sbc #>(scroll_text + LOADER_SCROLL_LEN)
        bcc sst_done
        lda #<scroll_text
        sta ZP_SRCP
        lda #>scroll_text
        sta ZP_SRCP+1
sst_done:
        rts

done_flag       .byte 0

irq_handler:
        ; Dual raster split:
        ;   state=0 @ 144: turn ON soft-scroll fine-X just before strip
        ;                   text row 12. Reprogram for line 156.
        ;   state=1 @ 156: lock back to fixed fine-X=0 after strip ends.
        ;                   Run all bookkeeping. Reprogram for 144.
        lda ZP_IRQSTATE
        bne ih_bot

        lda ZP_FX
        ora #$08
        sta VIC_CTRL2
        lda #1
        sta ZP_IRQSTATE
        lda #156
        sta VIC_RASTER
        lda #$01
        sta VIC_IRQ
        jmp $EA81

ih_bot:
        lda #$08
        sta VIC_CTRL2

        ; --- Frame tick (16-bit) ---
        inc ZP_FRAME_LO
        bne ft_nohi
        inc ZP_FRAME_HI
ft_nohi:

        ; --- Strip on/off ---
        lda ZP_SCROLL_ON
        beq sc_pre
        jsr scroll_step
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
        jsr show_centered_first_title
        lda #1
        sta ZP_ENTRY
        lda #<LOADER_CYCLE_FRAMES
        sta ZP_CYC_LO
        lda #>LOADER_CYCLE_FRAMES
        sta ZP_CYC_HI
        jmp strip_skip
strip_start_scroll:
        ; Second cycle elapsed: switch into soft-scroll mode.
        jsr scroll_init
strip_skip:

        ; --- Music play ---
        jsr music_play

        ; --- Done check ---
        lda ZP_FRAME_HI
        cmp #>LOADER_TOTAL_FRAMES
        bcc irq_ack
        bne irq_set_done
        lda ZP_FRAME_LO
        cmp #<LOADER_TOTAL_FRAMES
        bcc irq_ack
irq_set_done:
        lda #1
        sta done_flag
irq_ack:
        lda #0
        sta ZP_IRQSTATE
        lda #144
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

game_stub:
        lda done_flag
        bne gs_show_prompt
        lda #1
        sta skip_prompt_flag

gs_show_prompt:
        lda skip_prompt_flag
        bne gs_go

        ; Overwrite the strip with the prompt; keep IRQ + music alive.
        ldy #39
gs_clr: lda #$20
        sta SCREEN + STRIP_ROW*40, y
        lda #SEP_COL                    ; yellow, like the strip frame
        sta COLRAM + STRIP_ROW*40, y
        dey
        bpl gs_clr

        ldx #0
gs_msg: lda txt_press,x
        beq gs_wait
        sta SCREEN + STRIP_ROW*40 + 10, x
        inx
        bne gs_msg

gs_wait:
        jsr poll_any_input
        bne gs_go
        jmp gs_wait

gs_go:
        lda #0
        sta skip_prompt_flag
        sei
        jsr music_stop
        jsr uninstall_irq
        jsr uninstall_nmi
        cli
        ; --- Final placeholder: clear screen and show "GAME" ---
        lda #$00
        sta VIC_BORDER
        sta VIC_BG
        jsr clear_screen
        ldx #0
gs_p:   lda txt_game,x
        beq gs_d
        sta SCREEN + 12*40 + 18, x
        lda #$01
        sta COLRAM + 12*40 + 18, x
        inx
        bne gs_p
gs_d:
gs_h:   jmp gs_h

; ===========================================================================
; Data
; ===========================================================================

txt_game:     .byte 7,1,13,5,0          ; "GAME"
; "PRESS FIRE OR SPACE" in screen codes (uppercase charset).
txt_press:    .byte 16,18,5,19,5,32,6,9,18,5,32,15,18,32,19,16,1,3,5,0

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
