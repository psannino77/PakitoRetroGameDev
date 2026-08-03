# Milestone 1 - C64 Intro Splash Screen and Pre-Game Loader

## Target Platform
**Commodore 64** (PAL, 6502, VIC-II).

## Goal
Deliver a reusable Ocean-style pre-game loader and full-screen splash reveal
in 6502 assembly, shown before each game in this repository.

## Status: delivered (baseline)

Normative behavior is maintained in OpenSpec main specs:

| Spec | Path |
|------|------|
| Loader runtime | [openspec/specs/ocean-loader/spec.md](openspec/specs/ocean-loader/spec.md) |
| Splash assets | [openspec/specs/splash-assets/spec.md](openspec/specs/splash-assets/spec.md) |
| Build / VICE | [openspec/specs/build-pipeline/spec.md](openspec/specs/build-pipeline/spec.md) |

## Delivered

- [x] Assembler toolchain: **64tass**
- [x] Ocean-style loader with border bands + centered strip + soft-scroll
- [x] TokiFinal full-screen multicolor splash (tile-by-tile reveal)
- [x] Config file assets/loader/loader_texts.txt for titles/timings
- [x] Optional SID extract + play (local HVSC file)
- [x] Build to build/OCNTOKI.PRG / .D64
- [x] VICE launcher scripts/run_vice.sh
- [x] OpenSpec project setup + baseline specs

## Acceptance (met)

- Demo PRG runs on VICE: silence -> strip -> scroll -> splash -> game stub.
- Auto hand-off at LOADER_TOTAL_FRAMES after splash completes.
- Input skip gated while splash reveal is active.
- Timings/colors/texts driven by named constants / config file.

## Follow-ups (out of this milestone)

- [ ] Real tape/disk load progress hooked to loader_set_progress
- [ ] Integration into a full game binary (beyond game_stub)
- [ ] Optional fade / concurrent raster split scroll+bitmap (if desired)
- [ ] Hardware verification on real C64 / SD2IEC

## Tag

Suggested release tag once docs are frozen: m1-intro-loader.
