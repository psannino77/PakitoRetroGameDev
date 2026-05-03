#!/usr/bin/env python3
"""Hi-res C64 logo + crisp 8x8 pixel-font subtitle.

Replaces the unreadable "retro game dev" tagline with hand-pixeled 8x8 glyphs
so it is sharp under hi-res bitmap constraints.
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

# Compact 8x8 uppercase pixel font. Each glyph: 8 rows x 8 cols, '#'=on '.'=off.
GLYPHS = {
    " ": [
        "........",
        "........",
        "........",
        "........",
        "........",
        "........",
        "........",
        "........",
    ],
    "A": [
        "..####..",
        ".##..##.",
        "##....##",
        "##....##",
        "########",
        "##....##",
        "##....##",
        "........",
    ],
    "D": [
        "######..",
        "##...##.",
        "##....##",
        "##....##",
        "##....##",
        "##...##.",
        "######..",
        "........",
    ],
    "E": [
        "########",
        "##......",
        "##......",
        "######..",
        "##......",
        "##......",
        "########",
        "........",
    ],
    "G": [
        ".######.",
        "##....##",
        "##......",
        "##..####",
        "##....##",
        "##....##",
        ".######.",
        "........",
    ],
    "M": [
        "##....##",
        "###..###",
        "########",
        "##.##.##",
        "##....##",
        "##....##",
        "##....##",
        "........",
    ],
    "O": [
        ".######.",
        "##....##",
        "##....##",
        "##....##",
        "##....##",
        "##....##",
        ".######.",
        "........",
    ],
    "R": [
        "######..",
        "##...##.",
        "##....##",
        "##...##.",
        "######..",
        "##..##..",
        "##...##.",
        "........",
    ],
    "T": [
        "########",
        "...##...",
        "...##...",
        "...##...",
        "...##...",
        "...##...",
        "...##...",
        "........",
    ],
    "V": [
        "##....##",
        "##....##",
        "##....##",
        "##....##",
        "##....##",
        ".##..##.",
        "..####..",
        "........",
    ],
}


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


def convert_hires(canvas: Image.Image) -> Image.Image:
    px = canvas.load()
    w, h = canvas.size
    indexed = [[nearest_index(px[x, y]) for x in range(w)] for y in range(h)]
    out = [[0] * w for _ in range(h)]
    for cy in range(0, h, 8):
        for cx in range(0, w, 8):
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
                    idx = indexed[yy][xx]
                    if idx in allowed:
                        out[yy][xx] = idx
                    else:
                        out[yy][xx] = nearest_index(canvas.getpixel((xx, yy)), allowed)
    final = Image.new("RGB", (w, h))
    fpx = final.load()
    for y in range(h):
        for x in range(w):
            fpx[x, y] = C64_PALETTE[out[y][x]]
    return final


def stamp_text(img: Image.Image, text: str, x0: int, y0: int, color_idx: int,
               bg_idx: int = 0, spacing: int = 0) -> None:
    """Stamp 8x8 glyphs at (x0,y0). Aligns to 8-pixel grid for hi-res cells."""
    px = img.load()
    color = C64_PALETTE[color_idx]
    bg = C64_PALETTE[bg_idx]
    cx = x0
    for ch in text.upper():
        glyph = GLYPHS.get(ch, GLYPHS[" "])
        for ry, row in enumerate(glyph):
            for rx, cell in enumerate(row):
                px[cx + rx, y0 + ry] = color if cell == "#" else bg
        cx += 8 + spacing


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    src = root / "assets" / "loader" / "mockup" / "Logo Pakito.png"
    dst = root / "assets" / "loader" / "mockup" / "Logo_Pakito_c64_hires_v2.png"

    source = Image.open(src).convert("RGB")
    target_w, target_h = 320, 200
    sw, sh = source.size
    scale = min(target_w / sw, target_h / sh)
    rw, rh = int(round(sw * scale)), int(round(sh * scale))
    resized = source.resize((rw, rh), Image.LANCZOS)
    canvas = Image.new("RGB", (target_w, target_h), (0, 0, 0))
    canvas.paste(resized, ((target_w - rw) // 2, (target_h - rh) // 2))

    # Black-out the subtitle band before hi-res quantization so we redraw it crisp.
    # The original tagline sits just below "PAKITO" around y=88..104.
    sub_band = (0, 88, 320, 112)
    for y in range(sub_band[1], sub_band[3]):
        for x in range(sub_band[0], sub_band[2]):
            canvas.putpixel((x, y), (0, 0, 0))

    final = convert_hires(canvas)

    # Stamp "RETRO GAME DEV" centered, aligned to 8px grid, in light grey
    text = "RETRO GAME DEV"
    text_w = len(text) * 8
    x0 = ((320 - text_w) // 2) & ~7  # snap to 8px boundary
    y0 = 96                            # 8px boundary right below PAKITO
    stamp_text(final, text, x0, y0, color_idx=15)  # 15 = light grey

    dst.parent.mkdir(parents=True, exist_ok=True)
    final.save(dst)
    final.resize((640, 400), Image.NEAREST).save(
        dst.with_name(dst.stem + "_x2.png")
    )
    print(f"Wrote {dst}")


if __name__ == "__main__":
    main()
