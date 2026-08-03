## ADDED Requirements

### Requirement: Docs name the canonical loader
Root and loader README files SHALL document that the default PRG is produced
from `src/loader/ocean_style_loader_bottom.asm` via `./scripts/build_loader.sh`
and is named `OCNTOKI`, and SHALL note that `ocean_style_loader.asm` is a
legacy no-splash reference only.

#### Scenario: README build section matches scripts
- **WHEN** a contributor follows the Build section in `README.md` or
  `src/loader/README.md`
- **THEN** the commands and output names match `scripts/build_loader.sh` and
  `scripts/run_vice.sh` without mentioning removed entrypoints
  (`build_loader_bottom.sh`, `OCNLOAD`, `OCNBOT`)

### Requirement: Milestone status reflects splash loader delivery
`MILESTONE.md` SHALL mark the delivered loader/splash items complete and
point to OpenSpec main specs as the living requirements source for further
work.

#### Scenario: Milestone points at OpenSpec
- **WHEN** a reader opens `MILESTONE.md`
- **THEN** they are directed to `openspec/specs/` for current normative
  behavior of ocean-loader, splash-assets, and build-pipeline
