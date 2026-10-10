#!/usr/bin/env python3
"""Kernel Panic: draws the 16x16 pixel icons that used to be vector-only: the 8 device icons (art/devices) and 12 UI icons (art/ui).
usage: python3 tools/gen_icons.py      (writes into ../art; run from anywhere)"""
import math
import os
from PIL import Image

ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")


def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


class Icon:
    def __init__(self):
        self.im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))

    def p(self, x, y, c):
        if 0 <= x < 16 and 0 <= y < 16:
            self.im.putpixel((x, y), hx(c) if isinstance(c, str) else c)

    def r(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.p(xx, yy, c)

    def box(self, x, y, w, h, outline, fill):
        self.r(x, y, w, h, outline)
        self.r(x + 1, y + 1, w - 2, h - 2, fill)

    def disc(self, cx, cy, rad, c):
        for y in range(16):
            for x in range(16):
                if (x - cx) ** 2 + (y - cy) ** 2 <= rad * rad:
                    self.p(x, y, c)

    def ring(self, cx, cy, ro, ri, c):
        for y in range(16):
            for x in range(16):
                d = (x - cx) ** 2 + (y - cy) ** 2
                if ri * ri < d <= ro * ro:
                    self.p(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            self.p(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


def fridge():
    i = Icon()
    i.box(3, 1, 10, 13, "#10414a", "#2fb3b8")
    i.r(4, 2, 1, 11, "#9ff0ef")
    i.r(4, 6, 8, 1, "#10414a")
    i.r(10, 3, 1, 2, "#e8ffff"); i.r(10, 8, 1, 3, "#e8ffff")
    i.r(6, 2, 3, 1, "#7fe0e0")
    i.r(4, 14, 2, 1, "#10414a"); i.r(10, 14, 2, 1, "#10414a")
    return i


def phone():
    i = Icon()
    i.box(4, 1, 8, 14, "#12285a", "#2a52b8")
    i.r(5, 2, 6, 10, "#5ea0ff")
    for x, y in ((6, 3), (9, 3), (6, 6), (9, 6)):
        i.r(x, y, 2, 2, "#e8f2ff")
    i.r(5, 9, 6, 1, "#3f78e0")
    i.r(7, 13, 2, 1, "#e8f2ff")
    return i


def laptop():
    i = Icon()
    i.box(2, 2, 12, 8, "#2a2f4a", "#7a86a8")
    i.r(3, 3, 10, 6, "#16203a")
    i.r(4, 4, 5, 1, "#8affc8"); i.r(4, 6, 7, 1, "#8affc8"); i.r(4, 8, 3, 1, "#e8fff4")
    i.r(1, 11, 14, 1, "#c9d2ea")
    i.r(0, 12, 16, 2, "#7a86a8")
    i.r(0, 14, 16, 1, "#2a2f4a")
    i.r(6, 12, 4, 1, "#2a2f4a")
    return i


def server():
    i = Icon()
    for y in (1, 6, 11):
        i.box(1, y, 14, 4, "#123a22", "#2a8f50")
        i.p(3, y + 1, "#8affb0"); i.p(3, y + 2, "#e8ffe8")
        i.r(6, y + 1, 7, 1, "#6fe09a"); i.r(6, y + 2, 5, 1, "#1d6a3a")
    return i


def datacenter():
    i = Icon()
    for x in (1, 6, 11):
        i.box(x, 1, 4, 14, "#5a2a08", "#e0801c")
        for y in (3, 5, 7, 9):
            i.r(x + 1, y, 2, 1, "#ffe0a0")
        i.p(x + 1, 12, "#fff4d8"); i.p(x + 2, 12, "#8a3a08")
    i.r(0, 15, 16, 1, "#5a2a08")
    return i


def satellite():
    i = Icon()
    for x in (0, 11):
        i.box(x, 5, 5, 6, "#5a1010", "#d83a3a")
        i.r(x + 2, 5, 1, 6, "#ffb0a0"); i.r(x, 8, 5, 1, "#ffb0a0")
    i.r(5, 6, 6, 5, "#5a1010"); i.r(6, 7, 4, 3, "#c0c8d8"); i.r(6, 7, 4, 1, "#f2f6ff")
    i.r(5, 5, 1, 1, "#5a1010")
    i.r(7, 3, 2, 2, "#f2f6ff")
    i.p(5, 1, "#f2f6ff"); i.p(10, 1, "#f2f6ff"); i.r(6, 2, 4, 1, "#f2f6ff")
    i.r(7, 1, 2, 1, "#ffd84a")
    i.r(7, 11, 2, 1, "#5a1010"); i.r(7, 12, 2, 1, "#ff6a5a")
    return i


def mainframe():
    i = Icon()
    i.box(1, 1, 14, 14, "#0a3a4a", "#1b8aa8")
    for cx in (5, 10):
        i.disc(cx, 6, 3, "#06222c"); i.ring(cx, 6, 3, 1, "#8af0ff"); i.p(cx, 6, "#ffffff")
        i.p(cx - 2, 4, "#e8ffff")
    i.r(3, 11, 10, 1, "#06222c")
    for x, c in ((3, "#ffd84a"), (12, "#ffd84a"), (5, "#a07a10"), (10, "#a07a10"), (7, "#ffd84a"), (8, "#ffd84a")):
        i.p(x, 12, c)
    i.r(3, 13, 10, 1, "#0a3a4a")
    return i


def quantum():
    i = Icon()
    for k, ang in enumerate((0.0, math.pi / 3, 2 * math.pi / 3)):
        for s in range(64):
            u = 2 * math.pi * s / 64
            x, y = math.cos(u) * 7.0, math.sin(u) * 2.6
            xr = x * math.cos(ang) - y * math.sin(ang)
            yr = x * math.sin(ang) + y * math.cos(ang)
            i.p(round(7.5 + xr), round(7.5 + yr), ("#b0a0ff", "#9ad0ff", "#d0b0ff")[k])
    i.disc(7.5, 7.5, 1.6, "#ffffff")
    for x, y in ((14, 8), (2, 5), (3, 11)):
        i.p(x, y, "#ffffff")
    return i


def bomb():
    i = Icon()
    i.disc(7, 9, 5, "#14141c"); i.disc(7, 9, 4, "#2a2a3a")
    i.r(4, 7, 2, 2, "#6a6a88"); i.p(4, 7, "#aab0d0")
    i.r(8, 4, 2, 2, "#8a6a30")
    i.line(10, 4, 12, 2, "#c8a050")
    i.p(13, 1, "#ffd84a"); i.p(12, 1, "#ff8a2a"); i.p(14, 2, "#ff8a2a"); i.p(13, 2, "#fff0a0"); i.p(13, 0, "#ff8a2a")
    return i


def thorns():
    """Symmetric about the centre of the 16x16 grid: every pixel is mirrored left-right and top-bottom."""
    i = Icon()

    def q(x, y, c):
        for xx, yy in ((x, y), (15 - x, y), (x, 15 - y), (15 - x, 15 - y)):
            i.p(xx, yy, c)
    i.disc(7.5, 7.5, 3.2, "#6a1a1a"); i.disc(7.5, 7.5, 2.2, "#d83a3a")
    q(6, 6, "#ffb0a0")
    for k in range(0, 5):
        q(7, k, "#d0d6e8" if k > 0 else "#ffffff")
        q(k, 7, "#d0d6e8" if k > 0 else "#ffffff")
    for k in range(2, 5):
        q(k, k, "#d0d6e8" if k > 2 else "#ffffff")
    return i


def data():
    i = Icon()
    i.disc(7.5, 7.5, 6.3, "#8a5a10"); i.disc(7.5, 7.5, 5.3, "#ffc83a")
    i.ring(7.5, 7.5, 4.4, 3.4, "#ffe08a")
    i.r(6, 5, 1, 1, "#fff4c8")
    i.r(6, 6, 4, 4, "#8a5a10"); i.r(7, 7, 2, 2, "#ffe08a")
    return i


def slot():
    i = Icon()
    for x in (1, 3, 5, 7, 8, 10, 12, 14):
        i.p(x, 1, "#5a7a9a"); i.p(x, 14, "#5a7a9a")
    for y in (1, 3, 5, 7, 8, 10, 12, 14):
        i.p(1, y, "#5a7a9a"); i.p(14, y, "#5a7a9a")
    i.r(7, 4, 2, 8, "#4af0ff"); i.r(4, 7, 8, 2, "#4af0ff")
    i.r(7, 7, 2, 2, "#e8ffff")
    return i


def choice():
    i = Icon()
    i.box(1, 4, 6, 9, "#14304a", "#3a78b8")
    i.box(9, 4, 6, 9, "#14304a", "#3a78b8")
    i.box(5, 1, 6, 10, "#5a3a08", "#ffc83a")
    i.r(7, 4, 2, 4, "#fff4c8"); i.r(6, 5, 4, 2, "#fff4c8")
    return i


def boss():
    i = Icon()
    i.disc(7.5, 7, 5.2, "#d8dce8"); i.r(5, 11, 6, 3, "#d8dce8")
    i.r(5, 14, 6, 1, "#8a90a8")
    i.r(4, 6, 3, 3, "#14141c"); i.r(9, 6, 3, 3, "#14141c")
    i.p(5, 7, "#ff3a3a"); i.p(10, 7, "#ff3a3a")
    i.r(7, 9, 2, 2, "#14141c")
    for x in (6, 8, 10):
        i.p(x, 12, "#14141c"); i.p(x, 13, "#14141c")
    i.p(5, 3, "#f2f4ff"); i.p(6, 2, "#f2f4ff")
    return i


def elite():
    i = Icon()
    i.r(2, 5, 12, 8, "#8a5a10"); i.r(3, 6, 10, 6, "#ffc83a")
    for x in (2, 7, 12):
        i.r(x, 2, 2, 4, "#8a5a10"); i.r(x, 2, 2, 3, "#ffc83a"); i.p(x, 2, "#fff4c8")
    i.r(3, 10, 10, 1, "#d89a1a")
    for x, c in ((4, "#ff4a4a"), (11, "#ff4a4a"), (7, "#4af0ff"), (8, "#4af0ff")):
        i.p(x, 8, c)
    i.r(2, 13, 12, 1, "#5a3a08")
    return i


def start():
    i = Icon()
    i.disc(7.5, 7.5, 7.2, "#0f4a22"); i.disc(7.5, 7.5, 6.2, "#2ab858")
    for k, w in enumerate((1, 2, 3, 4, 5, 5, 4, 3, 2, 1)):
        i.r(6, 3 + k, w, 1, "#eafff0")
    return i


def iframe():
    i = Icon()
    for y, (x0, x1) in enumerate(((3, 12), (2, 13), (2, 13), (2, 13), (2, 13), (3, 12), (3, 12), (4, 11), (5, 10), (6, 9), (7, 8))):
        yy = y + 2
        i.p(x0, yy, "#14304a"); i.p(x1, yy, "#14304a")
        for x in range(x0 + 1, x1):
            i.p(x, yy, "#6ac0ff" if x < 8 else "#3a88d8")
    i.r(3, 2, 10, 1, "#14304a")
    i.r(4, 3, 3, 3, "#e8f6ff")
    i.p(11, 10, "#ffffff"); i.p(12, 11, "#ffffff")
    for x, y in ((13, 3), (1, 9)):
        i.p(x, y, "#ffffff"); i.p(x - 1, y, "#9ad8ff"); i.p(x + 1, y, "#9ad8ff"); i.p(x, y - 1, "#9ad8ff"); i.p(x, y + 1, "#9ad8ff")
    return i


def key():
    i = Icon()
    i.disc(4, 8, 3, "#8a5a10"); i.disc(4, 8, 2, "#ffc83a"); i.p(4, 8, "#14141c"); i.p(3, 7, "#fff4c8")
    i.r(6, 7, 9, 2, "#ffc83a"); i.r(6, 7, 9, 1, "#ffe08a"); i.r(6, 9, 9, 1, "#8a5a10")
    i.r(11, 9, 2, 3, "#ffc83a"); i.r(14, 9, 1, 2, "#ffc83a")
    i.r(11, 11, 2, 1, "#8a5a10")
    return i


def infinity():
    i = Icon()
    for cx in (4, 11):
        i.ring(cx, 8, 4.2, 2.0, "#4af0ff")
    i.r(7, 7, 2, 2, "#4af0ff")
    for cx in (4, 11):
        i.ring(cx, 8, 4.2, 3.4, "#9ff8ff")
    i.r(7, 7, 2, 2, "#e8ffff")
    return i


def internet():
    """A globe: deep-blue sphere, two green continents, a faint graticule, a bright rim and three linked gold nodes."""
    i = Icon()
    i.disc(7.5, 7.5, 7.3, "#08283a"); i.disc(7.5, 7.5, 6.4, "#1a6a9a")
    i.r(2, 7, 12, 1, "#2c88b8")                                           # equator
    for y in range(16):
        for x in range(16):
            d = ((x - 7.5) / 3.0) ** 2 + ((y - 7.5) / 6.2) ** 2
            if 0.85 < d < 1.1 and (x - 7.5) ** 2 + (y - 7.5) ** 2 <= 6.4 ** 2:
                i.p(x, y, "#2c88b8")                                      # meridian
    for x, y, w, h in ((3, 3, 4, 3), (3, 6, 2, 2), (9, 4, 3, 2), (10, 6, 3, 4), (6, 10, 3, 3)):
        i.r(x, y, w, h, "#3fcf7a")
    for x, y, w, h in ((3, 3, 4, 1), (9, 4, 3, 1), (10, 6, 3, 1), (6, 10, 3, 1)):
        i.r(x, y, w, h, "#8affb0")                                        # sunlit tops
    i.ring(7.5, 7.5, 7.3, 6.5, "#9ae8ff")
    i.line(5, 5, 11, 7, "#ffffff"); i.line(11, 7, 8, 11, "#ffffff"); i.line(8, 11, 5, 5, "#ffffff")
    for x, y in ((5, 5), (11, 7), (8, 11)):
        i.r(x - 1, y - 1, 2, 2, "#ffd84a")
    return i


def core():
    i = Icon()
    i.ring(7.5, 7.5, 7.2, 6.0, "#7a6aff")
    i.disc(7.5, 7.5, 5.2, "#2a1a6a"); i.disc(7.5, 7.5, 4.2, "#9a8aff"); i.disc(7.5, 7.5, 2.2, "#ffffff")
    i.p(6, 5, "#e8e0ff"); i.p(5, 6, "#e8e0ff")
    for x, y in ((7, 0), (8, 0), (7, 15), (8, 15), (0, 7), (0, 8), (15, 7), (15, 8)):
        i.p(x, y, "#ffffff")
    return i


DEVICES = {"fridge": fridge, "phone": phone, "laptop": laptop, "server": server, "datacenter": datacenter,
           "satellite": satellite, "mainframe": mainframe, "quantum": quantum}
UI = {"bomb": bomb, "thorns": thorns, "data": data, "slot": slot, "choice": choice, "boss": boss, "elite": elite,
      "start": start, "iframe": iframe, "internet": internet, "key": key, "infinity": infinity, "core": core}

if __name__ == "__main__":
    for sub, table in (("devices", DEVICES), ("ui", UI)):
        os.makedirs(os.path.join(ART, sub), exist_ok=True)
        for name, fn in table.items():
            fn().im.save(os.path.join(ART, sub, name + ".png"))
            print(sub, name)
    sheet = Image.new("RGBA", (10 * 136, 2 * 136), (20, 24, 40, 255))
    for n, (sub, name, fn) in enumerate([("devices", k, v) for k, v in DEVICES.items()] + [("ui", k, v) for k, v in UI.items()]):
        sheet.alpha_composite(fn().im.resize((128, 128), Image.NEAREST), ((n % 10) * 136 + 4, (n // 10) * 136 + 4))
    sheet.save(os.path.join(ART, "..", "..", "icon_preview.png"))
