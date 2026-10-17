#!/usr/bin/env python3
"""Kernel Panic: pixel-art replacements for the secret rooms' code-drawn visuals (circles, washes, lines).

  art/secret/fx_halo.png           32x32   white dithered glow disc (tinted in game; 1 art px = 4 screen px)
  art/secret/smartphone_secret_room_exit_portal.png   128x32   exit portal, 4 frames of 32x32 (dark disc, red rim running round it, white X)
  art/secret/smartphone_secret_room_dot.png            16x16   a typing dot (messages floor)
  art/secret/office_server_secret_room_locker.png 40x30  the office intern's locker, 2 frames of 20x30 (closed, open)
  art/secret/gaming_laptop_secret_room_port_frame.png 128x32  the laptop ports: a USB-style slot with a running rim, 4 frames of 32x32
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


def port_frame():
    """The laptop's port portal: a USB-style slot 28x28 art px: dark opening, a rim whose bright dashes run round it (4 frames), corner studs. The peripheral's plug icon is drawn on top in game."""
    sheet = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    for f in range(4):
        im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        for y in range(2, 30):
            for x in range(2, 30):
                inner = 4 <= x < 28 and 4 <= y < 28
                cut = min(x - 2, 29 - x) + min(y - 2, 29 - y) < 3   # rounded corners
                if cut:
                    continue
                px(im, x, y, (22, 26, 48, 255) if inner else O)
                if not inner:
                    run = ((x + y) // 3 + f) % 4
                    px(im, x, y, (120, 230, 255, 255) if run < 2 else (50, 110, 150, 255))
        for sx, sy in ((6, 6), (25, 6), (6, 25), (25, 25)):
            px(im, sx, sy, (90, 110, 160, 255))
        sheet.paste(im, (f * 32, 0))
    return sheet


def locker():
    """The intern's locker, two frames of 20x30 art px (closed, open): a grey-blue metal door with vents, a handle and a name tag; open shows the dark inside and a badge on a hook."""
    sheet = Image.new("RGBA", (40, 30), (0, 0, 0, 0))
    for f in range(2):
        im = Image.new("RGBA", (20, 30), (0, 0, 0, 0))
        for y in range(30):
            for x in range(20):
                px(im, x, y, O)
        for y in range(1, 29):
            for x in range(1, 19):
                px(im, x, y, (90, 110, 150, 255) if f == 0 else (14, 18, 36, 255))
        if f == 0:
            for y in (4, 6, 8):
                for x in range(4, 16):
                    px(im, x, y, (50, 66, 100, 255))                     # vent slats
            for y in range(1, 29):
                px(im, 1, y, (130, 150, 190, 255))                       # light edge
            for y in range(13, 17):
                px(im, 15, y, (230, 230, 240, 255))                      # handle
            for x in range(5, 13):
                for y in range(20, 24):
                    px(im, x, y, (240, 240, 220, 255))                   # name tag
            for x in range(6, 12, 2):
                px(im, x, 22, O)
        else:
            for y in range(1, 29):
                px(im, 18, y, (60, 76, 110, 255))                        # the open door edge
            px(im, 9, 5, (200, 200, 220, 255)); px(im, 9, 6, (200, 200, 220, 255))
            for x in range(6, 13):
                for y in range(7, 14):
                    px(im, x, y, (240, 200, 60, 255) if (x + y) % 5 else (255, 240, 140, 255))   # the badge on its hook
            for x in range(4, 16):
                px(im, x, 24, (40, 50, 80, 255))                         # a shelf
        sheet.paste(im, (f * 20, 0))
    return sheet


def paper():
    """A sheet of printer paper, 8x10 art px: white with grey text lines and a curled corner."""
    im = Image.new("RGBA", (8, 10), (0, 0, 0, 0))
    for y in range(10):
        for x in range(8):
            px(im, x, y, O)
    for y in range(1, 9):
        for x in range(1, 7):
            px(im, x, y, (245, 245, 235, 255))
    for y in (3, 5, 7):
        for x in range(2, 6 if y != 7 else 4):
            px(im, x, y, (110, 120, 150, 255))
    px(im, 6, 8, (190, 190, 180, 255)); px(im, 6, 7, (210, 210, 200, 255))
    return im


def manager():
    """THE MANAGER: the game's own INTERN sprite (office_server_secret_room_intern.png, 2 frames of 40x40) recoloured, so it matches the style exactly:
    white shirt -> grey suit, blue tie -> red tie, brown hair -> grey hair. Same outline, shading, glasses and the mug in the hand."""
    src = Image.open(os.path.join(OUT, "office_server_secret_room_intern.png")).convert("RGBA")
    m = {(244, 248, 255): (78, 84, 104), (168, 180, 208): (110, 118, 142), (106, 114, 144): (54, 60, 82), (86, 106, 144): (46, 52, 74),
         (42, 90, 208): (206, 58, 58), (26, 58, 144): (138, 34, 44), (106, 68, 40): (132, 132, 146), (160, 106, 60): (176, 176, 188), (138, 90, 48): (96, 96, 110)}
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    for y in range(src.height):
        for x in range(src.width):
            c = src.getpixel((x, y))
            if c[3]:
                out.putpixel((x, y), m.get(c[:3], c[:3]) + (255,))
    return out


def lounge_door_open():
    """The lounge door once the intern has unlocked it (16x16): the same frame as the closed door, a warm dark room behind, and the wooden leaf swung open to the left, seen at an angle."""
    src = Image.open(os.path.join(OUT, "office_server_secret_room_lounge_door.png")).convert("RGBA")
    im = src.copy()
    wood = src.getpixel((4, 9))
    glass = src.getpixel((8, 4))
    for y in range(2, 14):
        for x in range(2, 14):
            k = (y - 2) / 11.0
            px(im, x, y, (int(40 + 70 * k), int(28 + 46 * k), int(22 + 30 * k), 255))   # the dark room, lighter towards the floor
    for y in range(11, 14):
        for x in range(2, 14):
            px(im, x, y, (150, 110, 80, 255) if (x + y) % 2 else (130, 96, 70, 255))    # a strip of floor
    for y in range(2, 14):
        w = 4 - (y - 2) // 5                                          # the leaf narrows downwards: seen at an angle
        for x in range(2, 2 + w):
            px(im, x, y, wood)
        px(im, 2 + w, y, (10, 14, 36, 255))
    px(im, 3, 5, glass); px(im, 3, 6, glass)
    return im


def cold_aisle_door_open():
    """The data stream door once the pads were touched in order (16x16): the closed door's frame, a deep blue-black passage with a bright data line at the far end, and the door leaf swung open to the left."""
    src = Image.open(os.path.join(OUT, "data_center_secret_room_cold_aisle_door.png")).convert("RGBA")
    im = src.copy()
    leaf = src.getpixel((4, 8))
    glass = src.getpixel((8, 4))
    for y in range(2, 14):
        for x in range(2, 14):
            k = abs(x - 8) / 6.0
            px(im, x, y, (int(6 + 10 * k), int(14 + 28 * (1 - k)), int(30 + 60 * (1 - k)), 255))   # a dark passage, bluer at the centre
    for x in range(3, 13):
        px(im, x, 7, (120, 255, 240, 255))                           # the data line far down the passage
        px(im, x, 8, (30, 140, 160, 255))
    for y in range(2, 14):
        w = 4 - (y - 2) // 5
        for x in range(2, 2 + w):
            px(im, x, y, leaf)
        px(im, 2 + w, y, (10, 14, 36, 255))
    px(im, 3, 5, glass); px(im, 3, 6, glass)
    return im


def led_pad():
    """A square LED pad, 2 frames of 16x16 art px (dim, lit): a dark bevelled slab with a round white lens (tinted by colour in game); lit adds a bright core and a pixel glow ring."""
    sheet = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    for f in range(2):
        im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        for y in range(1, 15):
            for x in range(1, 15):
                px(im, x, y, O)
        for y in range(2, 14):
            for x in range(2, 14):
                px(im, x, y, (70, 76, 100, 255))
        for x in range(2, 14):
            px(im, x, 2, (120, 128, 160, 255)); px(im, x, 13, (40, 44, 64, 255))
        for y in range(2, 14):
            px(im, 2, y, (120, 128, 160, 255)); px(im, 13, y, (40, 44, 64, 255))
        for y in range(16):
            for x in range(16):
                d = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
                if d <= 4.5:
                    px(im, x, y, O)
                if d <= 3.7:
                    px(im, x, y, (255, 255, 255, 255) if f else (200, 200, 210, 255))
                if f and d <= 1.8:
                    px(im, x, y, (255, 255, 255, 255))
                if f and 3.7 < d <= 5.6 and (x + y) % 2 == 0:
                    px(im, x, y, (255, 255, 255, 255))
        sheet.paste(im, (f * 16, 0))
    return sheet


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, im, scale in (("fx_halo", halo(), 1), ("smartphone_secret_room_exit_portal", exit_portal(), 1),
                            ("smartphone_secret_room_dot", dot(), 1), ("gaming_laptop_secret_room_port_frame", port_frame(), 1), ("office_server_secret_room_locker", locker(), 1), ("data_center_secret_room_cold_aisle_door_open", cold_aisle_door_open(), 1), ("data_center_secret_room_led_pad", led_pad(), 1), ("office_server_secret_room_lounge_door_open", lounge_door_open(), 1), ("office_server_secret_room_paper", paper(), 1), ("office_server_secret_room_manager", manager(), 1), ("smartphone_secret_room_rain", rain(), 1), ("smartphone_secret_room_eq_cell", eq_cell(), 1)):
        im.save(os.path.join(OUT, name + ".png"))
    print("done")


if __name__ == "__main__":
    main()
