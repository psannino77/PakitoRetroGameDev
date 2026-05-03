#!/usr/bin/env python3
"""Convert the Pakito logo to a C64 hi-res bitmap-compatible PNG.

Hi-res spec:
- 320x200, palette limited to 16 C64 colors (Pepto).
- 2 colors per 8x8 cell (one of which we keep as black background where possible).
"""
from __future__ import annotations

from collections import Counter
from pathlib import Path

from PIL import Image

C64_PALETTE = [
    (0, 0, 0), (255, 255, 255), (136, 0, 0), (170, 255, 238),
    (204, 68, 204), (0, 204, 85), (0, 0, 170), (238, 238, 119),
    (221, 136, 85), (102, 68, 0), (255, 119, 119), (51, 51, 51),
    (119, 119, 119), (170, 255, 102), (0, 136, 255), (187, 187, 187),
]


def nearest_index(rgb, allowed=None):
    if allowed is None:
        allowed = range(len(C64_PALETTE))
    best_i, best_d = 0, 1 << 30
    r, g, b = rgb[:3]
    for i in allowed:
        pr, pg, pb = C64_PALETTE[i]
        d = 2 * (pr - r) ** 2 + 4 * (pg - g) ** 2 + 3 * (pb - b) ** 2
        if d < best_d:
            best_d = d
            best_i = i
    return best_i


def convert(src_path: Path, dst_path: Path) -> None:
    src = Image.open(src_path).convert("RGB")
    target_w, target_h = 320, 200
    sw, sh = src.size
    scale = min(target_w / sw, target_h / sh)
    rw, rh = max(1, int(round(sw * scale))), max(1, int(round(sh * scale)))
    resized = src.resize((rw, rh), Image.LANCZOS)
    canvas = Image.new("RGB", (target_w, target_h), (0, 0, 0))
    canvas.paste(resized, ((target_w - rw) // 2, (target_h - rh) // 2))

    px = canvas.load()
    indexed = [[nearest_index(px[x, y]) for x in range(320)] for y in range(200)]

    out = [[0] * 320 for _ in range(200)]
    for cy in range(0, 200, 8):
        for cx in range(0, 320, 8):
            cnt: Counter = Counter()
            for yy in range(cy, cy + 8):
                for xx in range(cx, cx + 8):
                    cnt[indexed[yy][xx]] += 1
            top = [c for c, _ in cnt.most_common(2)]
            if len(top) == 1:
                top.append(0 if top[0] != 0 else 1)
            allowed = set(top)
            for yy in range(cy, cy + 8):
                for xx in range(cx, cx + 8):
                    src_rgb = canvas.getpixel((xx, yy))
                    idx = indexed[yy][xx]
                    if idx in allowed:
                        out[yy][xx] = idx
                    else:
                        out[yy][xx] = nearest_index(src_rgb, allowed)

    final = Image.new("RGB", (320, 200))
    fpx = final.load()
    for y in range(200):
        for x in range(320):
            fpx[x, y] = C64_PALETTE[out[y][x]]
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    final.save(dst_path)
    final.resize((640, 400), Image.NEAREST).save(
        dst_path.with_name(dst_path.stem + "_x2.png")
    )


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    src = root / "assets" / "loader" / "mockup" / "Logo Pakito.png"
    dst = root / "assets" / "loader" / "mockup" / "Logo_Pakito_c64_hires.png"
    convert(src, dst)
    print(f"Wrote {dst}")
