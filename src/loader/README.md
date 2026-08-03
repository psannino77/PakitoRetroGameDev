# Ocean-style Loader

Original 6502 implementation inspired by the **visual style** of classic Ocean
Software tape loaders. No third-party / copyrighted code is committed.

> The iconic Ocean Loader is a tape loader (Bill Allen / Martin Galway). It is
> not present in Ocean cartridge dumps, and its code/music are protected works.
> This loader re-creates only the look from scratch.

## Canonical source

| Role | Path |
|------|------|
| Built by default | [ocean_style_loader_bottom.asm](ocean_style_loader_bottom.asm) |
| Legacy plain strip (reference only) | [ocean_style_loader.asm](ocean_style_loader.asm) |

Do not point the default build at the legacy file without an OpenSpec change.

## What you see

1. Black screen, music starts immediately (if a local SID is present).
2. After INITIAL_SILENCE, a **centered** text strip appears (row 12), framed
   by thin yellow horizontal lines:

       <TITLE or NOW LOADING>

3. Soft-scroll of the full intro text for **one complete pass**.
4. Full-screen multicolor **Toki splash** reveal (tile-by-tile, all 25 rows).
5. Hold finished image until TOTAL_FRAMES, then auto hand-off to game_stub.
   Input skip is blocked while the splash reveal is still in progress.

Visual reference: [assets/loader/mockup/](../../assets/loader/mockup/).

## Configurable text file

[assets/loader/loader_texts.txt](../../assets/loader/loader_texts.txt) drives
titles and timings. Rebuild after edits - no ASM changes needed.

Key directives: RIGHT, CYCLE_FRAMES, INITIAL_SILENCE, TOTAL_FRAMES, DOT_CHAR,
BAND_COLOR_A/B, BAND_HEIGHT.

## Files

- ocean_style_loader_bottom.asm - canonical loader + splash
- ocean_style_loader.asm - legacy strip-only reference
- scripts/build_loader.sh - default build
- scripts/tools/loader_texts_compile.py
- scripts/tools/sid_extract.py
- scripts/tools/compose_toki_splash.py (optional logo compose)
- assets/loader/loader_texts.txt
- assets/splash/Toki Splash/TokiFinal - {Chars,CharAttribs_L1,CharAttribs_L2}.bin

## Build

    ./scripts/build_loader.sh

Output: build/OCNTOKI.PRG and build/OCNTOKI.D64 (when c1541 is available).

From BASIC on the C64:

    LOAD"OCNTOKI",8
    RUN

## Run in VICE

    ./scripts/run_vice.sh                    # autostarts build/OCNTOKI.PRG
    ./scripts/run_vice.sh build/foo.prg      # any other PRG

## Music

SID discovery order is listed in scripts/build_loader.sh. Typical local paths:

- assets/music/loader.sid
- assets/loader/sid/Ocean_Loader_5.sid
(and other Ocean_Loader_*.sid candidates)

SID files are gitignored. Obtain copies from HVSC and place them locally.
