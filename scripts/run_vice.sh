#!/usr/bin/env bash
# Run VICE x64sc with a project-local configuration so this project never
# touches (nor is touched by) your global ~/.config/vice/vicerc.
#
# Usage:
#   ./scripts/run_vice.sh                   # autostarts build/OCNLOAD.PRG
#   ./scripts/run_vice.sh path/to/file.prg  # autostarts a specific PRG
#   ./scripts/run_vice.sh --help            # show help
#
# Implementation notes:
#   * VICE has no single "use this config and ignore the user one" CLI flag.
#     We work around it by setting XDG_CONFIG_HOME to a project-local dir
#     containing only our vice/vicerc, so all reads/writes are scoped here.
#   * +saveres prevents VICE from persisting any runtime change back to the
#     project rc on exit; -default forces a clean defaults+rc load order.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

print_help() {
    cat <<EOF
Pakito Retro Game Dev - VICE launcher (isolated config)

Usage:
  $0                 Run with build/OCNLOAD.PRG (the loader)
  $0 <file.prg>      Run with a specific PRG (path relative to project root
                     or absolute)
  $0 --help          Show this help

Environment:
  X64SC              Override the x64sc binary path (default: 'x64sc' from PATH)
EOF
}

case "${1:-}" in
    -h|--help) print_help; exit 0 ;;
esac

PRG="${1:-build/OCNLOAD.PRG}"
if [[ "$PRG" != /* ]]; then
    PRG="$ROOT/$PRG"
fi
if [[ ! -f "$PRG" ]]; then
    echo "[run_vice] PRG not found: $PRG" >&2
    echo "[run_vice] Build it first with: ./scripts/build_loader.sh" >&2
    exit 1
fi

X64SC_BIN="${X64SC:-x64sc}"
if ! command -v "$X64SC_BIN" >/dev/null 2>&1; then
    echo "[run_vice] '$X64SC_BIN' not found in PATH." >&2
    echo "[run_vice] Install VICE (e.g. 'brew install vice') or set X64SC=/path/to/x64sc" >&2
    exit 1
fi

# Project-local XDG_CONFIG_HOME -> vice/ subdir holds our vicerc.
ISOLATED_HOME="$ROOT/scripts/vice/.xdg"
mkdir -p "$ISOLATED_HOME/vice"
cp -f "$ROOT/scripts/vice/vicerc" "$ISOLATED_HOME/vice/vicerc"

echo "[run_vice] using isolated config:  $ISOLATED_HOME/vice/vicerc"
echo "[run_vice] launching x64sc with:   $PRG"

# `-default`  : start from built-in defaults, then load our rc on top.
# `+saveres`  : do NOT save resources back on exit (keeps rc pristine).
# `-warp`     : speed up autostart; the loader disables warp itself.
# `-autostart`: inject + RUN via kernal LOAD trap (no .d64 needed).
exec env XDG_CONFIG_HOME="$ISOLATED_HOME" \
    "$X64SC_BIN" \
        -default \
        +saveres \
        +confirmonexit \
        -autostart "$PRG"
