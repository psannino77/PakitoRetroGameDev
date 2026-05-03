#!/usr/bin/env python3
"""Convert the Pakito logo to a C64 multicolor bitmap-compatible PNG.

Output spec:
- 320x200, palette limited to 16 C64 colors (Pepto).
- Multicolor bitmap constraint: shared background (black) + up to 3 unique
  colors per 4x8 cell. Horizontal pixels are 2x wide (logical 160x200).
"""
from __future__ import annotations

from collections import Counter
from pathlib import Path

from PIL import Image

# Pepto C64 palette (R,G,B)
C64_PALETTE = [
    (0, 0, 0),        # 0  black
    (255, 255, 255),  # 1  white
    (136, 0, 0),      # 2  red
    (170, 255, 238),  # 3  cyan
    (204, 68, 204),   # 4  purple
    (0, 204, 85),     # 5  green
    (0, 0, 170),      # 6  blue
    (238, 238, 119),  # 7  yellow
    (221, 136, 85),   # 8  orange
    (102, 68, 0),     # 9  brown
    (255, 119, 119),  # 10 light red
    (51, 51, 51),     # 11 dark grey
    (119, 119, 119),  # 12 grey
    (170, 255, 102),  # 13 light green
    (0, 136, 255),    # 14 light blue
    (187, 187, 187),  # 15 light grey
]

BG_INDEX = 0  # shared background color (black)


def nearest_index(rgb, allowed=None):
    if allowed is None:
        allowed = range(len(C64_PALETTE))
    best_i, best_d = 0, 1 << 30
    r, g, b = rgb[:3]
    for i in allowed:
        pr, pg, pb = C64_PALETTE[i]
        # weighted Euclidean (perceptual-ish)
        d = 2 * (pr - r) ** 2 + 4 * (pg - g) ** 2 + 3 * (pb - b) ** 2
        if d < best_d:
            best_d = d
            best_i = i
    return best_i


def convert(src_path: Path, dst_path: Path) -> None:
    src = Image.open(src_path).convert("RGB")
    # Fit source into 320x200 frame, centered, on black background
    target_w, target_h = 320, 200
    sw, sh = src.size
    scale = min(target_w / sw, target_h / sh)
    rw, rh = max(1, int(round(sw * scale))), max(1, int(round(sh * scale)))
    resized = src.resize((rw, rh), Image.LANCZOS)
    canvas = Image.new("RGB", (target_w, target_h), (0, 0, 0))
    canvas.paste(resized, ((target_w - rw) // 2, (target_h - rh) // 2))

    # Down-sample to multicolor logical resolution 160x200
    logical = canvas.resize((160, 200), Image.LANCZOS)
    px = logical.load()

    # Step 1: per-pixel nearest palette index
    indexed = [[nearest_index(px[x, y]) for x in range(160)] for y in range(200)]

    # Step 2: enforce per-cell constraint (4x8 logical => 4 wide x 8 tall)
    out = [[0] * 160 for _ in range(200)]
    for cy in range(0, 200, 8):
        for cx in range(0, 160, 4):
            cnt: Counter = Counter()
            for yy in range(cy, cy + 8):
                for xx in range(cx, cx + 4):
                    idx = indexed[yy][xx]
                    if idx != BG_INDEX:
                        cnt[idx] += 1
            # Up to 3 non-bg colors
            chosen = [c for c, _ in cnt.most_common(3)]
            allowed = {BG_INDEX, *chosen}
            for yy in range(cy, cy + 8):
                for xx in range(cx, cx + 4):
                    src_rgb = logical.getpixel((xx, yy))
                    idx = indexed[yy][xx]
                    if idx in allowed:
                        out[yy][xx] = idx
                    else:
                        # remap to nearest among allowed
                        out[yy][xx] = nearest_index(src_rgb, allowed)

    # Step 3: render back to 320x200 (double horizontal pixels)
    final = Image.new("RGB", (320, 200))
    fpx = final.load()
    for y in range(200):
        for x in range(160):
            rgb = C64_PALETTE[out[y][x]]
            fpx[2 * x, y] = rgb
            fpx[2 * x + 1, y] = rgb

    dst_path.parent.mkdir(parents=True, exist_ok=True)
    final.save(dst_path)

    # Also export a 2x scaled preview for easier viewing
    preview = final.resize((640, 400), Image.NEAREST)
    preview.save(dst_path.with_name(dst_path.stem + "_x2.png"))


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    src = root / "assets" / "loader" / "mockup" / "Logo Pakito.png"
    dst = root / "assets" / "loader" / "mockup" / "Logo_Pakito_c64.png"
    convert(src, dst)
    print(f"Wrote {dst}")
