# ocean-loader Specification

## Purpose

Define the reusable Commodore 64 PAL Ocean-style pre-game loader that chains
a centered text intro into a full-screen Toki splash reveal and hands off to
a game stub when the configured duration ends.

## Requirements

### Requirement: Canonical entrypoint is the centered splash loader
The project SHALL treat `src/loader/ocean_style_loader_bottom.asm` as the
canonical loader implementation built by default. The legacy file
`src/loader/ocean_style_loader.asm` MAY remain in the tree for reference but
MUST NOT be the default build target.

#### Scenario: Default build produces the splash loader PRG
- **WHEN** a developer runs `./scripts/build_loader.sh`
- **THEN** 64tass assembles `src/loader/ocean_style_loader_bottom.asm` into
  `build/OCNTOKI.PRG` (and packages `build/OCNTOKI.D64` when `c1541` is available)

### Requirement: Sequential intro phases on PAL 50 Hz
The loader SHALL run the following phases in order, driven by the frame
counter and strip state machine:
1. black screen with music started
2. `LOADER_INITIAL_SILENCE` frames of silence (black screen)
3. centered strip showing "NOW LOADING"
4. centered strip showing the first configured title for `LOADER_CYCLE_FRAMES`
5. soft-scroll of the intro text for exactly one full pass of `scroll_text`
6. full-screen splash tile reveal
7. hold of the finished splash until `LOADER_TOTAL_FRAMES`, then hand-off

#### Scenario: Scroll arms splash only after one full text pass
- **WHEN** the scroll source pointer wraps past `scroll_text + LOADER_SCROLL_LEN`
- **THEN** the loader sets `ZP_SPLASH_PENDING`, stops feeding scroll text, and
  begins the splash reveal on a subsequent IRQ tick

### Requirement: Centered strip geometry
While in text mode the loader SHALL draw the strip on `STRIP_ROW = 12` with
yellow separator characters on `SEP_TOP_ROW` and `SEP_BOT_ROW`, and MUST
program the raster IRQ split from the derived `STRIP_RASTER_ON` /
`STRIP_RASTER_OFF` constants.

#### Scenario: Strip appears mid-screen
- **WHEN** the initial silence elapses and `show_strip` runs
- **THEN** the visible text row is row 12 of the 25-row display (vertical centre)

### Requirement: Full-screen splash reveal
Once splash mode is active the loader SHALL switch VIC to multicolor bitmap
mode (bank 1, screen `$4400`, bitmap `$6000`) and reveal the TokiFinal image
tile-by-tile left-to-right, top-to-bottom across all 25 rows and 40 columns
without skipping strip rows. Reveal pacing SHALL be `SPLASH_STEP_FRAMES`
frames per tile.

#### Scenario: No strip gap in the bitmap
- **WHEN** splash mode is revealing tiles
- **THEN** every screen row 0..24 receives tiles from the linear source and
  no row is skipped for the former bottom strip

#### Scenario: Reveal pace is configurable
- **WHEN** `SPLASH_STEP_FRAMES` is 3
- **THEN** the 1000-tile image completes in approximately 60 s at PAL 50 Hz

### Requirement: Auto hand-off at end of configured duration
When `ZP_FRAME_HI:LO` reaches `LOADER_TOTAL_FRAMES` AND the splash row
counter `ZP_BARSCROLL` is greater than or equal to `SPLASH_ROWS`, the IRQ
SHALL set `done_flag` so the main loop exits to `game_stub`.

#### Scenario: Music end triggers game after splash finished
- **WHEN** the frame counter hits `LOADER_TOTAL_FRAMES` and splash reveal is
  complete
- **THEN** the loader transitions to `game_stub` without requiring input

#### Scenario: Incomplete splash blocks auto end
- **WHEN** the frame counter hits `LOADER_TOTAL_FRAMES` but reveal is still
  in progress
- **THEN** `done_flag` remains clear until the reveal finishes

### Requirement: Input gating during splash
Keyboard/joystick skip MUST be ignored while splash is active and incomplete.
After the reveal finishes, input MAY skip the remaining hold.

#### Scenario: Key press during reveal is ignored
- **WHEN** the user presses a key while `ZP_SPLASH_ON` is set and
  `ZP_BARSCROLL < SPLASH_ROWS`
- **THEN** the loader continues the reveal and does not jump to `game_stub`

### Requirement: Config-driven strip text and timings
Strip labels, cycle timing, initial silence, and total frames SHALL be
sourced from `assets/loader/loader_texts.txt` via
`scripts/tools/loader_texts_compile.py` and the generated
`build/loader/loader_texts.inc` constants (`LOADER_*`).

#### Scenario: Rebuild picks up text edits
- **WHEN** a developer edits `assets/loader/loader_texts.txt` and rebuilds
- **THEN** the PRG reflects the new titles and `!TOTAL_FRAMES` / related
  directives without ASM source edits
