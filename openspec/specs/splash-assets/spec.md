# splash-assets Specification

## Purpose

Define the TokiFinal splash asset set and optional compose pipeline used by
the Ocean-style loader splash reveal.

## Requirements

### Requirement: Linear TokiFinal runtime set
The runtime loader SHALL consume a linear 40×25 multicolor cell set with one
unique 8-byte character cell per screen position (no map indirection at IRQ
time):

- `assets/splash/Toki Splash/TokiFinal - Chars.bin` — 8000 bytes
- `assets/splash/Toki Splash/TokiFinal - CharAttribs_L1.bin` — 1000 bytes
  (color RAM nybble source)
- `assets/splash/Toki Splash/TokiFinal - CharAttribs_L2.bin` — 1000 bytes
  (screen RAM attribute source)

#### Scenario: Build embeds the three binaries
- **WHEN** `ocean_style_loader_bottom.asm` is assembled
- **THEN** the three TokiFinal binaries above are `.binary`-included and the
  PRG data section grows by 10000 bytes for splash payload

### Requirement: Optional identity map and CharPad source
The repository MAY keep `TokiFinal - Map (40x25), 8bpc.bin` and
`TokiFinal.ctm` for re-export / tooling, but the runtime reveal MUST NOT
depend on map indirection.

#### Scenario: Map file is unused at runtime
- **WHEN** splash tiles are rendered
- **THEN** tile pixels are read linearly from `Chars.bin` and attributes from
  L1/L2 only

### Requirement: Optional logo compose tool
`scripts/tools/compose_toki_splash.py` MAY rewrite the TokiFinal linear set
by blitting mini logos from `assets/logos/bin/` onto the splash. Running the
tool MUST leave the three runtime binaries valid 40×25 linear assets.

#### Scenario: Compose preserves dimensions
- **WHEN** `compose_toki_splash.py` completes successfully
- **THEN** `Chars.bin` is 8000 bytes and each L1/L2 file is 1000 bytes

### Requirement: Logo bin layout for compose
Mini logo exports under `assets/logos/bin/` SHALL follow the CharPad export
naming pattern `<Name> - Chars.bin`, `<Name> - Map (WxH), 8bpc.bin`, and
matching `CharAttribs_L1` / `L2` (or `M`) files expected by the compose tool.

#### Scenario: Dave / Ocean / Pakito mini logos present
- **WHEN** a developer runs the compose tool with the stock layout
- **THEN** it locates Dave's Retro Forge_mini, Ocean_mini, and Pakito mini
  bins under `assets/logos/bin/`
