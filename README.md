# PakitoRetroGameDev

Commodore 64 retro game development workspace.

## Goals
- Reusable **intro splash screen** (PAKITO logo + "retro game dev").
- Generic **pre-game loader** with progress bar.
- Both written in 6502 assembly, integrable into any C64 game in this repo.

## Status
Milestone 1 in progress — see [MILESTONE.md](MILESTONE.md).

## Layout
```
assets/
  splash/         C64-ready splash assets (charset/screen/color)
    mockup/       original PNG mockups
  loader/         C64-ready loader assets
    mockup/       original PNG mockups
src/              6502 assembly sources (TBD)
tools/            asset conversion scripts (TBD)
docs/             English documentation (TBD)
```

## Target Platform
Commodore 64 (PAL, VIC-II), tested on VICE.

## Author
[psannino77](https://github.com/psannino77)
