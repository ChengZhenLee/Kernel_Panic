#!/usr/bin/env python3
"""Kernel Panic: pixel-art replacements for the secret rooms' code-drawn visuals (circles, washes, lines).

  art/secret/fx_halo.png           32x32   white dithered glow disc (tinted in game; 1 art px = 4 screen px)
  art/secret/smartphone_secret_room_exit_portal.png   128x32   exit portal, 4 frames of 32x32 (dark disc, red rim running round it, white X)
  art/secret/smartphone_secret_room_dot.png            16x16   a typing dot (messages floor)
  art/secret/smartphone_secret_room_rain.png            4x12   a rain streak (weather floor)
  art/secret/smartphone_secret_room_eq_cell.png        16x8    one equaliser cell (stacked in game as bars; music floor)

All drawn on the pixel grid with Pillow, no anti-aliasing; the dithers use a fixed 4x4 Bayer matrix so a re-run gives identical files.
usage: python3 tools/gen_secret_fx_art.py
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "secret")
O = (10, 14, 36, 255)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def dither(x, y, k):
    """True when pixel (x, y) is lit at density k (0..1)."""
    return k * 16.0 > BAYER[y % 4][x % 4] + 0.5


def halo():
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for y in range(32):
        for x in range(32):
            d = math.hypot(x + 0.5 - 16, y + 0.5 - 16) / 16.0
            if d < 1 and dither(x, y, (1 - d) ** 1.3):
                px(im, x, y, (255, 255, 255, 255))
    return im


def exit_portal():
    sheet = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    for f in range(4):
        im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        for y in range(32):
            for x in range(32):
                d = math.hypot(x + 0.5 - 16, y + 0.5 - 16)
                if d <= 13.5:
                    px(im, x, y, O)
                if d <= 12.5:
                    px(im, x, y, (16, 18, 32, 255))
                if 11.0 <= d <= 12.5:                       # the rim: bright dashes that run round the disc, 4 frames
                    a = (math.atan2(y + 0.5 - 16, x + 0.5 - 16) / math.tau * 8 + f * 0.5) % 1.0
                    px(im, x, y, (255, 115, 115, 255) if a < 0.6 else (150, 55, 70, 255))
        xs = set()                                          # the white X: 2 px thick, mirror-symmetric about the tile centre (15.5, 15.5)
        for k in range(12):
            for x in (10 + k, 11 + k, 21 - k, 20 - k):
                xs.add((x, 10 + k))
        edge = {(x + ox, y + oy) for x, y in xs for ox in (-1, 0, 1) for oy in (-1, 0, 1)} - xs
        for x, y in edge:
            px(im, x, y, O)
        for x, y in xs:
            px(im, x, y, (255, 255, 255, 255))
        sheet.paste(im, (f * 32, 0))
    return sheet


def cold_wash():
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y in range(16):
        for x in range(16):
            if BAYER[y % 4][x % 4] in (0, 5, 10):
                px(im, x, y, (150, 205, 255, 150))
    px(im, 3, 9, (235, 250, 255, 220)); px(im, 11, 2, (235, 250, 255, 220)); px(im, 13, 13, (235, 250, 255, 220))
    return im


def frost_band():
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y in range(16):
        k = (1 - y / 15.0) ** 1.4
        for x in range(16):
            if dither(x, y, k):
                px(im, x, y, (225, 247, 255, 255) if y < 4 else (160, 215, 250, 255))
    for x in (2, 7, 12):                                    # a few icicle tips
        for y in (9, 10):
            px(im, x, y, (225, 247, 255, 255))
    return im


def dot():
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y in range(16):
        for x in range(16):
            d = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
            if d <= 5.5:
                px(im, x, y, O)
            if d <= 4.5:
                px(im, x, y, (255, 255, 255, 255))
    px(im, 6, 5, (190, 255, 225, 255)); px(im, 7, 5, (190, 255, 225, 255))
    return im


def rain():
    im = Image.new("RGBA", (4, 12), (0, 0, 0, 0))
    for i in range(10):                                     # a slanted streak, brighter at the head
        px(im, 3 - i // 3, i, (255, 255, 255, 255) if i > 6 else (255, 255, 255, 140))
    return im


def eq_cell():
    im = Image.new("RGBA", (16, 8), (0, 0, 0, 0))
    for y in range(1, 7):
        for x in range(1, 15):
            px(im, x, y, (255, 255, 255, 255))
    for x in range(1, 15):
        px(im, x, 6, (200, 200, 200, 255))                  # a darker bottom row so stacked cells read as segments
        px(im, x, 7, O)
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, im, scale in (("fx_halo", halo(), 1), ("smartphone_secret_room_exit_portal", exit_portal(), 1),
                            ("smartphone_secret_room_dot", dot(), 1), ("smartphone_secret_room_rain", rain(), 1), ("smartphone_secret_room_eq_cell", eq_cell(), 1)):
        im.save(os.path.join(OUT, name + ".png"))
    print("done")


if __name__ == "__main__":
    main()
