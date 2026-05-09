#!/usr/bin/env bash
# Build the Ocean-style loader PRG with 64tass.
#   * Compiles the rotating-strip text table (assets/loader/loader_texts.txt)
#     into build/loader/loader_texts.{bin,inc}.
#   * Optionally extracts a SID into build/sid/ if a local file is present.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build" "$ROOT/build/sid" "$ROOT/build/loader"

# --- Strip-text table ----------------------------------------------------
TEXTS_SRC="$ROOT/assets/loader/loader_texts.txt"
if [[ ! -f "$TEXTS_SRC" ]]; then
    echo "[loader] missing $TEXTS_SRC" >&2
    exit 1
fi
python3 "$ROOT/scripts/tools/loader_texts_compile.py" \
    "$TEXTS_SRC" "$ROOT/build/loader"

# --- Optional SID step ---------------------------------------------------
# Place your SID at one of these paths; the first one found is used.
# Repo-committed SIDs under assets/loader/sid/ are picked up automatically.
SID_CANDIDATES=(
    "$ROOT/assets/music/loader.sid"
    "$ROOT/assets/music/Ocean_Loader_5.sid"
    "$ROOT/assets/loader/sid/Ocean_Loader_5.sid"
    "$ROOT/assets/loader/sid/Ocean_Loader_3.sid"
    "$ROOT/assets/loader/sid/Ocean_Loader_2.sid"
    "$ROOT/assets/loader/sid/Ocean_Loader_1.sid"
)
SID_FOUND=""
for s in "${SID_CANDIDATES[@]}"; do
    if [[ -f "$s" ]]; then SID_FOUND="$s"; break; fi
done

if [[ -n "$SID_FOUND" ]]; then
    echo "[loader] using SID: $SID_FOUND"
    python3 "$ROOT/scripts/tools/sid_extract.py" "$SID_FOUND" "$ROOT/build/sid"
else
    echo "[loader] no SID found (searched: ${SID_CANDIDATES[*]}) - building silent"
    cat > "$ROOT/build/sid/loader_sid.inc" <<'EOF'
; Auto-generated stub: no SID present.
SID_PRESENT = 0
SID_LOAD = 0
SID_INIT = 0
SID_PLAY = 0
EOF
fi

# --- Assemble ------------------------------------------------------------
# Output name kept short, uppercase, ASCII-only so it loads cleanly from a
# C64 BASIC LOAD"NAME",8 prompt (PETSCII has no '_' on the keyboard, and disk
# filenames are limited to 16 chars).
OUT_PRG="$ROOT/build/OCNLOAD.PRG"
# Clean up any stale alias from older builds.
rm -f "$ROOT/build/ocean_loader.prg"
64tass -a -I "$ROOT" -o "$OUT_PRG" \
    "$ROOT/src/loader/ocean_style_loader.asm"

echo "[loader] built: build/OCNLOAD.PRG ($(wc -c <"$OUT_PRG") bytes)"
