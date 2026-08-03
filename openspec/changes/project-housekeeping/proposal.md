## Why

The repo accumulated provisional ASM experiments, WIP Python tools, throwaway
screenshots, and duplicate build entrypoints while the Toki splash loader
stabilized. Baseline behavior is now fixed, but docs and tree layout still
describe the old OCNLOAD/plain-strip world. Housekeeping locks the canonical
structure under OpenSpec so future work starts from a clean source of truth.

## What Changes

- Remove provisional loader probes (`pakito_loader`, `smoke_test`, `step1_*`,
  `step2_*`), unused Pakito_final bins, obsolete logo converters, and the
  duplicate `build_loader_bottom.sh` entrypoint.
- Drop throwaway root diagnostics and WIP badge/simplify scripts that are not
  on the build path.
- Make `./scripts/build_loader.sh` the single default entrypoint assembling
  `ocean_style_loader_bottom.asm` → `build/OCNTOKI.PRG`.
- Refresh root `README.md` / `MILESTONE.md` / `src/loader/README.md` to match
  the centered-scroll + full-screen splash flow.
- Add OpenSpec `config.yaml` context and main specs
  (`ocean-loader`, `splash-assets`, `build-pipeline`).
- Tighten `.gitignore` for tmp/screenshots and keep logos/compose assets that
  the optional compose pipeline needs.

Non-goals:
- No gameplay / disk-loader I/O work beyond the intro PRG.
- No change to reveal timing, strip row, or TokiFinal pixels in this change
  beyond documenting current behavior.
- No redistribution of third-party SIDs.

## Capabilities

### New Capabilities
- _(none — baseline main specs already capture current behavior)_

### Modified Capabilities
- `build-pipeline`: document single entrypoint and OCNTOKI outputs (delta only
  if residual wording drifts during README refresh)
- `ocean-loader`: no requirement change expected; docs must match existing
  SHALL behaviors already in main specs

## Impact

- Deleted dead paths under `src/loader/`, `scripts/tools/`, `assets/splash/bin/`
- Default build/run scripts and loader README
- OpenSpec tree under `openspec/`
- Contributors follow `/opsx:propose` for subsequent feature work
