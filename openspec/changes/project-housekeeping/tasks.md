## 1. Tree cleanup

- [x] 1.1 Remove provisional ASM probes (`pakito_loader`, `smoke_test`, `step1_borders`, `step2_irq`)
- [x] 1.2 Remove unused Pakito_final bins and obsolete logo converter scripts
- [x] 1.3 Remove duplicate `scripts/build_loader_bottom.sh` and throwaway root diagnostics / WIP tools
- [x] 1.4 Keep `assets/logos/` + `compose_toki_splash.py` for optional splash recompose

## 2. OpenSpec baseline

- [x] 2.1 Initialize OpenSpec (`openspec init --tools auggie`) and fill `openspec/config.yaml` context/rules
- [x] 2.2 Write main specs: `ocean-loader`, `splash-assets`, `build-pipeline`
- [x] 2.3 Create change `project-housekeeping` with proposal/design/delta specs/tasks

## 3. Docs and ignore rules

- [x] 3.1 Refresh root `README.md` layout, build/run, and OpenSpec pointer
- [x] 3.2 Refresh `MILESTONE.md` status against delivered loader/splash
- [x] 3.3 Align `src/loader/README.md` with centered strip + full-screen splash flow and OCNTOKI
- [x] 3.4 Tighten `.gitignore` (`tmp/`, diagnostics already listed)

## 4. Verify and publish

- [x] 4.1 `openspec validate --all` passes
- [x] 4.2 `./scripts/build_loader.sh` succeeds
- [ ] 4.3 Commit cleanup + OpenSpec tree and push `main`
