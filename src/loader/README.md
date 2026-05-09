# Ocean-style Loader

Original 6502 implementation, inspired by the **visual style** of classic Ocean
Software tape loaders. No third-party / copyrighted code is committed in this
repo.

> The iconic "Ocean Loader" is a tape loader (Bill Allen / Martin Galway). It
> is **not** present in Ocean cartridge dumps (`.crt`), and its code/music are
> protected works. This loader re-creates only the look from scratch.

## What you see (matches the mockups)
1. **Black screen, music starts immediately.**
2. After a short silent intro, a single **mid-screen text strip** appears,
   framed by a thin yellow horizontal line above and below:

   ```
   <TITLE> ............................. NOW LOADING
   ```
3. The **title cycles** every few seconds through entries declared in
   [assets/loader/loader_texts.txt](../../assets/loader/loader_texts.txt) —
   e.g. `OCEAN`, `CODE: PASQUALE SANNINO`, `MUSIC: ALDO CHIUMMO`, ...
4. Throughout, **rainbow horizontal raster bars** scroll in the top and
   bottom border (stable, no jitter — they're drawn with a polled raster
   IRQ in border-only territory).
5. When the total intro time elapses the loader hands off to `game_stub`.

Visual reference: [assets/loader/mockup/](../../assets/loader/mockup/).

## Configurable text file (reusable across games)

[assets/loader/loader_texts.txt](../../assets/loader/loader_texts.txt) is a
plain text file that drives both the rotating titles and the timings:

```text
!RIGHT=NOW LOADING
!CYCLE_FRAMES=200
!INITIAL_SILENCE=100
!TOTAL_FRAMES=9000
!DOT_CHAR=.

OCEAN
PAKITO RETRO GAME DEV
CODE: PASQUALE SANNINO
MUSIC: ALDO CHIUMMO
GREETINGS TO THE SCENE
```

| Directive          | Meaning                                       | Default       |
|--------------------|-----------------------------------------------|---------------|
| `!RIGHT=...`       | Right-side fixed label                        | `NOW LOADING` |
| `!CYCLE_FRAMES=N`  | Frames per entry (PAL = 50/s)                 | `200` (~4s)   |
| `!INITIAL_SILENCE` | Frames of pure-black before the strip appears | `100` (~2s)   |
| `!TOTAL_FRAMES=N`  | Total intro length, then `game_stub` runs     | `9000` (3:00) |
| `!DOT_CHAR=c`      | Single character used to fill the gap         | `.`           |

To reuse the loader for another game, just edit this file (or supply your
own copy) and rebuild — no ASM changes needed.

## Files
- [src/loader/ocean_style_loader.asm](../../src/loader/ocean_style_loader.asm)
- [scripts/build_loader.sh](../../scripts/build_loader.sh)
- [scripts/tools/loader_texts_compile.py](../../scripts/tools/loader_texts_compile.py)
- [scripts/tools/sid_extract.py](../../scripts/tools/sid_extract.py)
- [assets/loader/loader_texts.txt](../../assets/loader/loader_texts.txt)

## Build
```sh
./scripts/build_loader.sh
```
Output: `build/OCNLOAD.PRG` (a symlink `build/ocean_loader.prg` is also kept
for back-compat). The short uppercase ASCII name is needed because PETSCII
has no `_` on the C64 keyboard, and disk filenames are limited to 16
characters — so loading from BASIC works as:

```basic
LOAD"OCNLOAD",8
RUN
```

The build script:
1. compiles `loader_texts.txt` into `build/loader/loader_texts.{bin,inc}`,
2. picks the first SID found from a list of candidate paths (see below),
   extracting it into `build/sid/loader_sid.{bin,inc}` (or generating a
   silent stub if none is present),
3. assembles the loader with 64tass.

## Run in VICE

Use the project-local launcher (recommended): it runs `x64sc` in an
**isolated VICE config** so it can't be broken by — or break — your global
`~/.config/vice/vicerc` (e.g. True Drive Emulation left on by another
project, which causes `?FILE NOT FOUND  ERROR` on autostart).

```sh
./scripts/run_vice.sh                    # autostarts build/OCNLOAD.PRG
./scripts/run_vice.sh build/foo.prg      # any other PRG
```

Or, manually:
```sh
x64sc build/OCNLOAD.PRG
```

## Music
The build script searches these paths and uses the first match:
```
assets/music/loader.sid
assets/music/Ocean_Loader_5.sid
assets/loader/sid/Ocean_Loader_5.sid
assets/loader/sid/Ocean_Loader_3.sid
assets/loader/sid/Ocean_Loader_2.sid
assets/loader/sid/Ocean_Loader_1.sid
```
Drop a `.sid` at any of those locations and rebuild. To match the strip
duration to the SID length, adjust `!TOTAL_FRAMES` (PAL: `seconds * 50`).

## Memory map
| Range          | Use                              |
|----------------|----------------------------------|
| `$0801-$080C`  | BASIC stub `SYS 2061`            |
| `$080D-...`    | Loader code + data               |
| `$1000+`       | SID payload (when present)       |
| `$0400-$07E7`  | Screen RAM                       |
| `$D800-$DBE7`  | Color RAM                        |
| `$D018 = $14`  | Charset = ROM uppercase          |

## Zero-page usage
`$02-$0B` (timers, counters, scroll, entry index, progress),
`$FB-$FE` (copy pointers — local to drawing helpers).

## Integration into a game
```asm
; Boot path: control reaches `start` from the BASIC stub.
;   - During the loader, you may report progress from a fastloader:
;
;       lda #percent
;       jsr loader_set_progress     ; advisory, 0..100
;
;   - When LOADER_TOTAL_FRAMES elapses, `game_stub` is invoked. Replace
;     `game_stub` with a JMP to your real game entry point.
```
