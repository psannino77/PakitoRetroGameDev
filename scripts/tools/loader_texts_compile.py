#!/usr/bin/env python3
"""
loader_texts_compile.py - Build the rotating-strip data for the C64 loader.

Reads a plain-text configuration file (default:
``assets/loader/loader_texts.txt``) and emits two artefacts:

  * <out>/loader_texts.bin  : concatenation of N x 40 screen-code bytes
                              ready to be poked into screen RAM.
  * <out>/loader_texts.inc  : 64tass include with constants
                              (LOADER_ENTRIES_COUNT, LOADER_CYCLE_FRAMES,
                              LOADER_INITIAL_SILENCE, LOADER_TOTAL_FRAMES).

Usage:
  python3 scripts/tools/loader_texts_compile.py <input.txt> <output_dir>

The on-screen line layout is:

    <TITLE>_<dots>_<RIGHT>

(``_`` is a single space). Total length is exactly 40 characters, padded
with the configured DOT_CHAR.
"""
from __future__ import annotations

import os
import sys
from typing import List, Tuple

ROW_WIDTH = 40
SIDE_PAD  = 2                            # blank cells reserved on each side
INNER_W   = ROW_WIDTH - 2 * SIDE_PAD

DEFAULTS = {
    "RIGHT":           "NOW LOADING",
    "CYCLE_FRAMES":    "200",
    "INITIAL_SILENCE": "100",
    "TOTAL_FRAMES":    "9000",
    "DOT_CHAR":        ".",
    "BAND_COLOR_A":    "3",
    "BAND_COLOR_B":    "6",
    "BAND_HEIGHT":     "4",
}


def die(msg: str) -> None:
    print(f"loader_texts_compile: {msg}", file=sys.stderr)
    sys.exit(1)


def warn(msg: str) -> None:
    print(f"loader_texts_compile: warning: {msg}", file=sys.stderr)


def to_screen_codes(s: str) -> bytes:
    """ASCII (upper-cased) -> C64 screen codes (uppercase charset)."""
    out = bytearray()
    for ch in s:
        b = ord(ch)
        if 0x40 <= b <= 0x5F:        # @ A-Z [ \ ] ^ _
            out.append(b - 0x40)
        elif 0x20 <= b <= 0x3F:      # space, digits, punctuation
            out.append(b)
        else:
            out.append(0x20)         # unknown -> space
    return bytes(out)


def parse(path: str) -> Tuple[dict, List[str]]:
    cfg = dict(DEFAULTS)
    entries: List[str] = []
    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\r\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if stripped.startswith("!"):
                kv = stripped[1:].split("=", 1)
                if len(kv) != 2:
                    die(f"bad config directive: {stripped!r}")
                key, val = kv[0].strip().upper(), kv[1].strip()
                if key not in DEFAULTS:
                    die(f"unknown config key: {key}")
                cfg[key] = val
                continue
            entries.append(stripped.upper())
    if not entries:
        die("no title entries found")
    if len(entries) > 255:
        die(f"too many entries ({len(entries)}); max 255")
    return cfg, entries


def compose(title: str, right: str, dot: str) -> bytes:
    if len(dot) != 1:
        die(f"DOT_CHAR must be exactly 1 character (got {dot!r})")
    # Layout inside INNER_W cols: TITLE + ' ' + dots + ' ' + RIGHT.
    # Then pad SIDE_PAD blanks on each side to reach ROW_WIDTH.
    fixed = len(title) + 1 + 1 + len(right)
    if fixed > INNER_W:
        excess = fixed - INNER_W
        warn(f"title {title!r} too long, trimming {excess} chars")
        title = title[: max(0, len(title) - excess)]
        fixed = len(title) + 1 + 1 + len(right)
    gap = INNER_W - len(title) - 1 - len(right) - 1
    if gap < 0:
        gap = 0
    inner = f"{title} {dot * gap} {right}"
    if len(inner) > INNER_W:
        inner = inner[:INNER_W]
    elif len(inner) < INNER_W:
        inner = inner + " " * (INNER_W - len(inner))
    line = " " * SIDE_PAD + inner + " " * SIDE_PAD
    return to_screen_codes(line)


def main() -> None:
    if len(sys.argv) != 3:
        die("usage: loader_texts_compile.py <input.txt> <output_dir>")
    src, outdir = sys.argv[1], sys.argv[2]
    if not os.path.isfile(src):
        die(f"input not found: {src}")

    cfg, entries = parse(src)

    try:
        cycle  = int(cfg["CYCLE_FRAMES"], 0)
        silent = int(cfg["INITIAL_SILENCE"], 0)
        total  = int(cfg["TOTAL_FRAMES"], 0)
        col_a  = int(cfg["BAND_COLOR_A"], 0)
        col_b  = int(cfg["BAND_COLOR_B"], 0)
        bh     = int(cfg["BAND_HEIGHT"], 0)
    except ValueError as e:
        die(f"non-integer numeric config: {e}")

    if not (1 <= cycle <= 0xFFFF):
        die(f"CYCLE_FRAMES out of range: {cycle}")
    if not (0 <= silent <= 0xFFFF):
        die(f"INITIAL_SILENCE out of range: {silent}")
    if not (1 <= total <= 0xFFFF):
        die(f"TOTAL_FRAMES out of range: {total}")
    if not (0 <= col_a <= 15) or not (0 <= col_b <= 15):
        die(f"BAND_COLOR_A/B must be 0..15")
    if not (1 <= bh <= 32):
        die(f"BAND_HEIGHT must be 1..32")

    blob = bytearray()
    for t in entries:
        row = compose(t, cfg["RIGHT"], cfg["DOT_CHAR"])
        assert len(row) == ROW_WIDTH
        blob.extend(row)

    # Soft-scroll source: titles[1:] joined with a separator, looped.
    # If only one entry exists, fall back to that entry alone.
    SEP = "   *   "
    scroll_titles = entries[1:] if len(entries) > 1 else entries
    scroll_str = SEP.join(scroll_titles)
    # Trailing gap so that loop wrap is visually clean.
    scroll_str = scroll_str + SEP
    scroll_blob = to_screen_codes(scroll_str)
    if len(scroll_blob) > 0xFFFF:
        die("scroll text too long")

    os.makedirs(outdir, exist_ok=True)
    bin_path = os.path.join(outdir, "loader_texts.bin")
    inc_path = os.path.join(outdir, "loader_texts.inc")
    scroll_path = os.path.join(outdir, "loader_scroll.bin")
    with open(bin_path, "wb") as f:
        f.write(blob)
    with open(scroll_path, "wb") as f:
        f.write(scroll_blob)

    rel_bin = os.path.relpath(bin_path, start=os.path.dirname(inc_path)) \
        if os.path.dirname(inc_path) else bin_path

    with open(inc_path, "w", encoding="utf-8") as f:
        f.write(
            "; Auto-generated by scripts/tools/loader_texts_compile.py\n"
            f"; Source: {os.path.basename(src)}\n"
            f"; Entries: {len(entries)} (right=\"{cfg['RIGHT']}\")\n"
            f"LOADER_ENTRIES_COUNT    = {len(entries)}\n"
            f"LOADER_CYCLE_FRAMES     = {cycle}\n"
            f"LOADER_INITIAL_SILENCE  = {silent}\n"
            f"LOADER_TOTAL_FRAMES     = {total}\n"
            f"LOADER_BAND_COLOR_A     = {col_a}\n"
            f"LOADER_BAND_COLOR_B     = {col_b}\n"
            f"LOADER_BAND_HEIGHT      = {bh}\n"
            f"LOADER_SCROLL_LEN       = {len(scroll_blob)}\n"
        )

    print(f"loader_texts_compile: {len(entries)} entries, "
          f"cycle={cycle}f silence={silent}f total={total}f "
          f"-> {bin_path} ({len(blob)} bytes)")


if __name__ == "__main__":
    main()
