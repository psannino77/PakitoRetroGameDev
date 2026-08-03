# build-pipeline Specification

## Purpose

Define how the loader is compiled, packaged, and launched for VICE / real
hardware testing.

## Requirements

### Requirement: Single default build script
The repository SHALL expose exactly one default loader build entrypoint:
`./scripts/build_loader.sh`. That script MUST:

1. compile `assets/loader/loader_texts.txt` via
   `scripts/tools/loader_texts_compile.py` into `build/loader/`
2. optionally extract a SID via `scripts/tools/sid_extract.py` into
   `build/sid/` (first candidate found), or emit a silent stub include
3. assemble `src/loader/ocean_style_loader_bottom.asm` with 64tass into
   `build/OCNTOKI.PRG`
4. package `build/OCNTOKI.D64` when `c1541` is available

#### Scenario: Clean rebuild succeeds
- **WHEN** a developer runs `./scripts/build_loader.sh` with 64tass installed
- **THEN** the command exits 0 and prints the built PRG path and byte size

### Requirement: SID candidate search order
SID discovery SHALL try candidates in this order and use the first existing
file:

1. `assets/music/loader.sid`
2. `assets/music/Ocean_Loader_5.sid`
3. `assets/loader/sid/Ocean_Loader_5.sid`
4. `assets/loader/sid/Ocean_Loader_3.sid`
5. `assets/loader/sid/Ocean_Loader_2.sid`
6. `assets/loader/sid/Ocean_Loader_1.sid`

`*.sid` paths remain gitignored for redistribution safety; local HVSC copies
are developer-provided.

#### Scenario: Missing SID builds silent stub
- **WHEN** no candidate SID file exists
- **THEN** the build writes a `SID_PRESENT = 0` stub include and still
  produces a runnable PRG

### Requirement: Isolated VICE launcher
`./scripts/run_vice.sh` SHALL launch `x64sc` with the project-local
`scripts/vice/` config sandbox and default autostart target
`build/OCNTOKI.PRG` when no path argument is given.

#### Scenario: Default run autostarts OCNTOKI
- **WHEN** a developer runs `./scripts/run_vice.sh` after a successful build
- **THEN** VICE starts with `build/OCNTOKI.PRG` (or the packaged disk flow)
  without reading the user's global vice config for project overrides

### Requirement: Generated artifacts stay out of git
Build outputs under `build/` and local SID files MUST remain gitignored.
Committed sources are limited to ASM, scripts, config texts, and C64-ready
bin assets required at assemble time.

#### Scenario: Fresh clone builds after local SID drop-in
- **WHEN** a contributor clones the repo, optionally drops a SID into a
  candidate path, and runs `./scripts/build_loader.sh`
- **THEN** a PRG is produced without requiring committed `build/` trees
