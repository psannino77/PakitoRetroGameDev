## Context

Canonical runtime is already implemented in
`src/loader/ocean_style_loader_bottom.asm` (centered strip row 12, linear
TokiFinal reveal, auto `done_flag` at `LOADER_TOTAL_FRAMES`). Build scripts
were partially pointed at this file; a parallel `build_loader_bottom.sh` and
legacy probes remained. OpenSpec was just initialized (`spec-driven` schema)
with main specs written for current behavior.

## Goals / Non-Goals

**Goals:**
- One obvious build/run path for new contributors
- Docs and OpenSpec specs describe the same system
- Dead experiments out of the default tree
- Keep optional compose/logo assets needed to regenerate splash

**Non-Goals:**
- Refactor ASM IRQ/split or SID staging
- Replace 64tass / introduce Make unless requested later
- Archive the change into main specs beyond aligning docs (main specs already
  baseline-correct)

## Decisions

1. **Single build script name** — keep `scripts/build_loader.sh` as the public
   name (muscle memory / README links). Internally it assembles
   `ocean_style_loader_bottom.asm`. Delete `build_loader_bottom.sh` rather
   than the opposite rename to avoid breaking half-updated docs.
2. **Keep legacy `ocean_style_loader.asm`** — still useful as a no-splash
   reference; not built by default. Document that fact instead of deleting.
3. **Keep `assets/logos/` + `compose_toki_splash.py`** — optional offline
   pipeline for re-exporting TokiFinal with logo badges; not required at
   runtime assemble unless invoked manually.
4. **Main specs first** — write `openspec/specs/*` as the living baseline, then
   use this change's artifacts to drive the remaining file/docs cleanup tasks.
5. **Ignore patterns** — `build/`, `*.sid`, ocean demo dumps already ignored;
   add `tmp/` and root diagnostic names if still listed.

VIC / ZP notes (for future changes, not modified here):
- Text strip: VIC bank 0, charset ROM, fine X-scroll via `VIC_CTRL2`
- Splash: VIC bank 1 (`$4000-$7FFF`), bitmap `$6000`, screen `$4400`
- IRQ-time splash pointers stay on the historical ZP slots to avoid SID player
  collisions; L2 uses self-mod absolute load

## Risks / Trade-offs

- **Deleting probes** loses stepwise educational samples — accepted; git
  history retains them.
- **Keeping logos (~800 KB+)** slightly bloated vs pure runtime — accepted for
  regenerate capability.
- **Legacy ASM still in tree** may confuse greps — mitigated by README and
  OpenSpec "canonical entrypoint" requirement.
