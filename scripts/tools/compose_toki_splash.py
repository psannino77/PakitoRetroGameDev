#!/usr/bin/env python3
"""Compose the Toki splash assets with the three mini logos.

This rewrites the linear 40x25 TokiFinal asset set used by the Ocean-style
loader, placing Dave's Retro Forge on the lower-left, Ocean in the lower
centre, and Pakito retro game dev on the lower-right.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "assets" / "splash" / "Toki Splash"
LOGOS = ROOT / "assets" / "logos" / "bin"
SCREEN_W = 40
SCREEN_H = 25
 
DAVE_PNG = ROOT / "assets" / "logos" / "Dave's Retro Forge_mini.png"
DAVE_X = 1
DAVE_Y = 18
DAVE_W = 9
DAVE_H = 7
DAVE_WHITE = 1
DAVE_AZURE = 14


class Logo:
    def __init__(self, name: str, width: int, height: int, fallback_l1: int | None = None, fallback_l2: int | None = None) -> None:
        self.name = name
        self.width = width
        self.height = height
        self.fallback_l1 = fallback_l1
        self.fallback_l2 = fallback_l2
        self.chars = (LOGOS / f"{name} - Chars.bin").read_bytes()
        self.map = (LOGOS / f"{name} - Map ({width}x{height}), 8bpc.bin").read_bytes()
        self.attr1 = (LOGOS / f"{name} - CharAttribs_L1.bin").read_bytes()
        attr2_path = LOGOS / f"{name} - CharAttribs_L2.bin"
        self.attr2 = attr2_path.read_bytes() if attr2_path.exists() else b""

    def tile_at(self, cell_index: int) -> int:
        return self.map[cell_index]

    def char_bytes(self, tile_index: int) -> bytes:
        start = tile_index * 8
        return self.chars[start:start + 8]

    def attr_value(self, attrs: bytes, cell_index: int, tile_index: int) -> int:
        if len(attrs) == self.width * self.height:
            return attrs[cell_index]
        return attrs[tile_index]

    def l1_value(self, cell_index: int, tile_index: int) -> int:
        value = self.attr_value(self.attr1, cell_index, tile_index)
        if value == 0 and self.fallback_l1 is not None:
            return self.fallback_l1
        return value

    def l2_value(self, cell_index: int, tile_index: int) -> int:
        if self.attr2:
            return self.attr_value(self.attr2, cell_index, tile_index)
        if self.fallback_l2 is not None:
            return self.fallback_l2
        return 0


def blit(target_chars: bytearray, target_l1: bytearray, target_l2: bytearray, logo: Logo, x0: int, y0: int) -> None:
    for cell_index in range(logo.width * logo.height):
        sx = cell_index % logo.width
        sy = cell_index // logo.width
        dx = x0 + sx
        dy = y0 + sy
        if not (0 <= dx < SCREEN_W and 0 <= dy < SCREEN_H):
            continue

        tile_index = logo.tile_at(cell_index)
        dst_cell = dy * SCREEN_W + dx
        dst_off = dst_cell * 8
        target_chars[dst_off:dst_off + 8] = logo.char_bytes(tile_index)
        target_l1[dst_cell] = logo.l1_value(cell_index, tile_index)
        target_l2[dst_cell] = logo.l2_value(cell_index, tile_index)


def remap_dave_colors(target_l1: bytearray, target_l2: bytearray) -> None:
    source = Image.open(DAVE_PNG).convert("RGB")
    resized = source.resize((DAVE_W, DAVE_H), Image.LANCZOS)
    for cy in range(DAVE_H):
        for cx in range(DAVE_W):
            r, g, b = resized.getpixel((cx, cy))
            dst_cell = (DAVE_Y + cy) * SCREEN_W + (DAVE_X + cx)
            if r + g + b < 24:
                continue
            if b > r + 30 and b > g + 10:
                target_l1[dst_cell] = DAVE_AZURE
            else:
                target_l1[dst_cell] = DAVE_WHITE
            target_l2[dst_cell] = 0


def main() -> None:
    chars_path = TARGET / "TokiFinal - Chars.bin"
    l1_path = TARGET / "TokiFinal - CharAttribs_L1.bin"
    l2_path = TARGET / "TokiFinal - CharAttribs_L2.bin"

    target_chars = bytearray(chars_path.read_bytes())
    target_l1 = bytearray(l1_path.read_bytes())
    target_l2 = bytearray(l2_path.read_bytes())

    blit(target_chars, target_l1, target_l2, Logo("Dave's Retro Forge_mini", 9, 7, fallback_l1=1, fallback_l2=14), 1, 18)
    remap_dave_colors(target_l1, target_l2)
    blit(target_chars, target_l1, target_l2, Logo("Ocean_mini", 12, 4), 14, 21)
    blit(target_chars, target_l1, target_l2, Logo("Pakito retro game dev_mini", 12, 3), 27, 22)

    chars_path.write_bytes(target_chars)
    l1_path.write_bytes(target_l1)
    l2_path.write_bytes(target_l2)

    print(f"Updated {chars_path}")
    print(f"Updated {l1_path}")
    print(f"Updated {l2_path}")


if __name__ == "__main__":
    main()