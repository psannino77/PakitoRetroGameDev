# Milestone 1 — C64 Intro Splash Screen & Pre-Game Loader

## Target Platform
**Commodore 64** (PAL, 6502, VIC-II).

## Goal
Deliver a reusable intro splash screen (studio/author identity) and a generic
pre-game loader, written in 6502 assembly, to be displayed before each game
in this repository.

## Scope
- Static splash screen shown at boot.
- Loader screen with progress feedback shown before any game starts.
- Both routines must be reusable across multiple C64 games.

## Deliverables
- Splash screen bitmap/charset asset(s) + display routine (ASM).
- Loader screen asset(s) + display routine with progress API (ASM).
- Build pipeline (e.g. KickAssembler / ACME / cc65 + exomizer) producing a
  runnable `.prg` / `.d64`.
- Asset conversion scripts (PNG/Koala -> C64 binary).
- Minimal English documentation describing integration and customization.

## Acceptance Criteria
- Splash displays for a configurable number of frames, then transitions to the loader.
- Loader shows progress (bar/percentage/animation) and completes cleanly.
- A demo `.prg` runs on VICE (and ideally on real hardware) showing:
  splash -> loader -> stub game.
- No hard-coded magic numbers without a named constant; timings/colors configurable.

---

## TODO

### Planning & Setup
- [ ] Decide assembler toolchain (KickAssembler / ACME / cc65).
- [ ] Decide display mode for splash: hires bitmap, multicolor bitmap, or charset.
- [ ] Decide display mode for loader (likely charset + sprite for the bar).
- [ ] Add base folder layout: `src/`, `assets/`, `build/`, `docs/`, `tools/`, `examples/`.
- [ ] Add `README.md` (English) with project overview and build instructions.
- [ ] Add a `Makefile` (or equivalent) to build splash + loader + demo.

### Assets - Splash
- [ ] Drop original mockup in `assets/splash/mockup/`.
- [ ] Convert mockup to C64 format (Koala `.kla` / hires `.bin` / charset).
- [ ] Generate color RAM and screen RAM dumps.
- [ ] Optional: crunch with exomizer.

### Assets - Loader
- [ ] Drop original mockup in `assets/loader/mockup/`.
- [ ] Convert mockup to C64 format.
- [ ] Design progress bar (sprite-based or charset-based).
- [ ] Define color scheme for "empty" vs "filled" bar.

### Code - Splash (ASM)
- [ ] Routine `splash_init` - set VIC-II mode, copy bitmap/screen/color, set border/bg.
- [ ] Routine `splash_run` - wait N frames or until key/joystick press.
- [ ] Routine `splash_done` - restore VIC-II to text/charset mode.
- [ ] Optional: fade-in via color cycling.

### Code - Loader (ASM)
- [ ] Routine `loader_init` - display loader screen.
- [ ] API `loader_set_progress` (A = 0..100 or 0..255) - update bar.
- [ ] API `loader_set_message` (XY = ptr to PETSCII string) - update label line.
- [ ] Routine `loader_done` - clear screen and hand off to game.
- [ ] Hook progress to a sample loader task (fake delay or real file load).

### Integration
- [ ] Single entry point (e.g. `intro_run`) chaining splash -> loader.
- [ ] Document the calling convention (registers / ZP usage) for game code.
- [ ] Build a minimal demo game that calls `intro_run` then displays "GAME".

### Tooling
- [ ] PNG -> C64 bitmap converter script (Python) in `tools/`.
- [ ] Build script producing `.prg` and `.d64`.
- [ ] VICE launch helper (`make run`).

### Documentation (English)
- [ ] `docs/splash.md` - splash usage, memory layout, customization.
- [ ] `docs/loader.md` - loader usage, progress API, memory layout.
- [ ] `docs/integration.md` - how to plug intro into a new C64 game.
- [ ] `docs/build.md` - toolchain setup and build commands.

### Release
- [ ] Tag milestone `m1-intro-loader`.
- [ ] Update changelog.
- [ ] Verify on real hardware (or at least VICE + warp off).
