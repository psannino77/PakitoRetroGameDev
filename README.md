# PakitoRetroGameDev

Commodore 64 (PAL) retro game development workspace.

## Goals

- Reusable **Ocean-style pre-game loader** with config-driven strip text.
- Full-screen **Toki splash reveal** after the intro scroll.
- Both written in 6502 assembly (64tass), integrable into C64 games in this repo.

## Status

Milestone 1 loader/splash delivered. Living requirements live under
[openspec/specs/](openspec/specs/). See [MILESTONE.md](MILESTONE.md).

## Quick start

    ./scripts/build_loader.sh          # -> build/OCNTOKI.PRG (+ .D64 if c1541 present)
    ./scripts/run_vice.sh              # autostarts build/OCNTOKI.PRG in isolated VICE

Optional SID: drop a HVSC file at one of the paths listed in
scripts/build_loader.sh (e.g. assets/loader/sid/Ocean_Loader_5.sid).
SID files are gitignored.

## Layout

    assets/
      loader/           strip config (loader_texts.txt), mockups, local SIDs
      logos/            mini logo CharPad exports (optional compose)
      splash/
        Toki Splash/    runtime TokiFinal bins (Chars + L1 + L2)
        mockup/         reference images
    openspec/
      specs/            main specs (ocean-loader, splash-assets, build-pipeline)
      changes/          active OpenSpec changes
    scripts/
      build_loader.sh   default build entrypoint
      run_vice.sh       isolated x64sc launcher
      tools/            loader_texts_compile, sid_extract, compose_toki_splash
    src/loader/
      ocean_style_loader_bottom.asm   canonical loader (built by default)
      ocean_style_loader.asm          legacy plain-strip reference (not built)
      README.md                       loader details

## Runtime flow (PAL 50 Hz)

1. Black screen + music
2. Short silence (INITIAL_SILENCE)
3. Centered strip: NOW LOADING then first title
4. Soft-scroll intro text (one full pass)
5. Full-screen multicolor splash reveal (tile-by-tile)
6. Hold until TOTAL_FRAMES, then game_stub

Strip texts/timings: [assets/loader/loader_texts.txt](assets/loader/loader_texts.txt).

## OpenSpec

AI-assisted changes use OpenSpec (spec-driven schema). Skills/commands are
under .augment/. Typical flow:

1. /opsx:propose - proposal + specs + design + tasks
2. /opsx:apply - implement tasks
3. /opsx:archive - merge delta specs into main specs

## Author

[psannino77](https://github.com/psannino77)
