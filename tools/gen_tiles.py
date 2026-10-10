#!/usr/bin/env python3
"""Kernel Panic: pixel floor and wall tiles per device (art/tiles). Floor PNGs are 64x64 world px (32x32 art drawn 2x); wall PNGs are 128x128 (drawn 4x).
floor_<tier>_<0..3>.png : one 64 px floor cell (four variants, picked by cell hash); walls: wall_<tier>.png, tiled over each wall rect.
Floors stay dark and low-contrast so pickups, bullets and enemies read on top. Only tier 0 (SMART FRIDGE) exists so far.
usage: python3 tools/gen_tiles.py"""
import os
import random
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "tiles")


def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


class T:
    def __init__(self, bg, n=32):
        self.n = n
        self.im = Image.new("RGBA", (n, n), hx(bg) if bg else (0, 0, 0, 0))

    def p(self, x, y, c):
        if 0 <= x < self.n and 0 <= y < self.n:
            self.im.putpixel((x, y), hx(c))

    def r(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.p(xx, yy, c)

    def save(self, name, scale=2):
        os.makedirs(OUT, exist_ok=True)
        self.im.resize((self.n * scale, self.n * scale), Image.NEAREST).save(os.path.join(OUT, name + ".png"))


def fridge_floor(v):
    rnd = random.Random(100 + v)
    t = T("#0c1c24")
    t.r(0, 0, 32, 1, "#143240"); t.r(0, 0, 1, 32, "#143240")          # frosted tile seams (top and left edges, so tiles join)
    t.r(1, 1, 30, 1, "#10272f"); t.r(1, 1, 1, 30, "#10272f")
    for _ in range(26):                                                   # frost speckle
        t.p(rnd.randrange(2, 31), rnd.randrange(2, 31), rnd.choice(["#122b35", "#163541", "#0f2630"]))
    for _ in range(3):
        t.p(rnd.randrange(3, 30), rnd.randrange(3, 30), "#2b5a68")
    if v == 1:                                                            # hairline crack
        x, y = 6, 8
        for _ in range(14):
            t.p(x, y, "#07131a"); t.p(x + 1, y, "#1e4452")
            x += rnd.choice([1, 1, 2]); y += rnd.choice([0, 1, 1])
    if v == 2:                                                            # ice glint
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2)):
            t.p(16 + dx, 14 + dy, "#5c93a3" if dx == 0 and dy == 0 else "#2f6070")
    if v == 3:                                                            # frost crystal
        for k in range(1, 4):
            for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k), (k, k), (-k, -k), (k, -k), (-k, k)):
                t.p(20 + dx, 20 + dy, "#23505d" if k < 3 else "#1a3d49")
        t.p(20, 20, "#4f8898")
    return t


def fridge_wall():
    """Chunky brushed-steel shelf wall, much lighter than the dark floor: 32x32 art pixels drawn 4x (a 128 px world tile)."""
    t = T("#4f7184")
    t.r(0, 0, 32, 2, "#9fc4d4")                                           # lit top edge of the tile
    for y in (16,):                                                       # wire-shelf rail
        t.r(0, y, 32, 2, "#a9ccdb"); t.r(0, y + 2, 32, 2, "#2c4856")
    t.r(0, 0, 2, 32, "#2c4856"); t.r(2, 0, 1, 32, "#6f95a8")              # one strut per tile
    for x, y in ((9, 7), (24, 23)):                                       # rivets
        t.r(x, y, 3, 3, "#d6eef7"); t.r(x + 1, y + 1, 2, 2, "#2c4856")
    rnd = random.Random(7)
    for _ in range(8):
        t.p(rnd.randrange(4, 32), rnd.randrange(2, 32), rnd.choice(["#5f8497", "#436172"]))
    return t


def rrect(t, x0, y0, x1, y1, outline, fill):
    """Rounded-corner rectangle, inclusive coordinates."""
    t.r(x0, y0, x1 - x0 + 1, y1 - y0 + 1, outline)
    t.r(x0 + 1, y0 + 1, x1 - x0 - 1, y1 - y0 - 1, fill)
    for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        t.p(x, y, BG[0])


BG = ["#000000"]


# ---- device 1: SMARTPHONE (blue) ----
def phone_floor(v):
    BG[0] = "#0a1230"
    t = T("#0a1230")
    rrect(t, 3, 3, 28, 28, "#17306e", "#0d1a45")
    t.r(5, 4, 22, 1, "#1f3f8a")
    if v == 1:
        rrect(t, 11, 11, 20, 20, "#27509e", "#1b3a80"); t.p(13, 13, "#4a7ad8")
    if v == 2:
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            t.p(15 + dx, 15 + dy, "#2f5cb8")
    if v == 3:
        t.r(9, 20, 3, 3, "#1b3a80"); t.r(14, 20, 3, 3, "#1b3a80"); t.r(19, 20, 3, 3, "#1b3a80")
    return t


def phone_wall():
    t = T("#cfd8ee")
    t.r(0, 0, 32, 1, "#f2f6ff"); t.r(0, 31, 32, 1, "#8d9cc4")
    for x in (0, 16):
        t.r(x, 0, 1, 32, "#aab6d6")
    for y in (0, 16):
        t.r(0, y, 32, 1, "#aab6d6")
    cols = ["#ff6a7a", "#ffc23a", "#4ad8a0", "#5a8cff"]
    for k, (x, y) in enumerate(((2, 2), (18, 2), (2, 18), (18, 18))):
        rrect(t, x, y, x + 11, y + 11, "#3a4a7a", cols[k])
        t.r(x + 2, y + 2, 3, 2, "#ffffff"); t.r(x + 2, y + 10, 8, 1, "#00000030"[:7])
    return t


# ---- device 2: GAMING LAPTOP (violet floor, gunmetal and neon wall) ----
def laptop_floor(v):
    BG[0] = "#140a26"
    t = T("#140a26")
    t.r(2, 3, 28, 26, "#0a0516"); t.r(2, 3, 28, 25, "#1c1136"); t.r(3, 3, 26, 1, "#33205c")
    t.r(2, 27, 28, 2, "#0a0516")
    if v == 1:
        t.r(12, 12, 8, 2, "#5a3aa0"); t.r(15, 12, 2, 8, "#5a3aa0")
    if v == 2:
        t.r(9, 10, 3, 9, "#4a2e86"); t.r(9, 10, 8, 2, "#4a2e86"); t.r(9, 14, 6, 2, "#4a2e86")
    if v == 3:
        t.r(8, 22, 16, 2, "#7a2fb8"); t.r(8, 23, 16, 1, "#3a1470")
    return t


def laptop_wall():
    t = T("#656a80")
    t.r(0, 0, 32, 2, "#9aa0b8"); t.r(0, 2, 32, 1, "#7e84a0")
    for y in (6, 10, 14):
        t.r(5, y, 22, 2, "#14141f"); t.r(5, y + 2, 22, 1, "#3a3d52")
    t.r(0, 21, 32, 3, "#1e8a58"); t.r(0, 22, 32, 1, "#3dff9a"); t.r(0, 24, 32, 1, "#0f4a30")
    for x, y in ((2, 28), (28, 28)):
        t.r(x, y, 2, 2, "#c8cde0")
    t.r(0, 27, 32, 1, "#454960")
    return t


# ---- device 3: OFFICE SERVER (green floor, steel-blue rack wall) ----
def server_floor(v):
    BG[0] = "#08140e"
    t = T("#08140e")
    for y in range(2, 32, 4):
        t.r(4, y, 26, 1, "#0f2a1c")
    t.r(0, 0, 2, 32, "#1c4a30"); t.r(2, 0, 1, 32, "#0c2016")
    if v == 1:
        t.r(25, 4, 3, 3, "#1a6a3a"); t.r(26, 5, 1, 1, "#7affaa")
    if v == 2:
        t.r(25, 4, 3, 3, "#8a5a10"); t.r(26, 5, 1, 1, "#ffc84a")
    if v == 3:
        t.r(8, 12, 18, 6, "#0a1c14"); t.r(8, 12, 18, 1, "#1c4a30")
    return t


def server_wall():
    t = T("#46536e")
    t.r(0, 0, 4, 32, "#aab4c8"); t.r(4, 0, 1, 32, "#2a3348")
    t.r(0, 0, 32, 1, "#7a88a8")
    for y in (3, 17):
        t.r(7, y, 22, 11, "#141a26"); t.r(8, y + 1, 20, 9, "#1c2434")
        for k in range(4):
            t.r(10 + k * 5, y + 2, 3, 5, "#2e3a54")
        t.r(10, y + 8, 2, 1, "#4aff8a" if y == 3 else "#ffb43a"); t.r(14, y + 8, 2, 1, "#4aff8a")
    t.r(0, 31, 32, 1, "#2a3348")
    return t


# ---- device 4: DATA CENTER (orange floor, concrete hazard wall) ----
def datacenter_floor(v):
    BG[0] = "#1a0e06"
    t = T("#1a0e06")
    t.r(0, 0, 32, 1, "#3c2210"); t.r(0, 0, 1, 32, "#3c2210")
    for i in range(3):
        for j in range(3):
            x, y = 5 + i * 9, 5 + j * 9
            t.r(x, y, 4, 4, "#2c1a0c"); t.r(x + 1, y + 1, 2, 2, "#080402")
    if v == 1:
        for k in range(0, 32, 8):
            t.r(k, 29, 4, 2, "#5a3c10"); t.r(k + 4, 29, 4, 2, "#12090a")
    if v == 2:
        t.r(14, 0, 4, 32, "#241408")
    if v == 3:
        t.r(0, 14, 32, 4, "#241408")
    return t


def datacenter_wall():
    t = T("#8d9299")
    t.r(0, 0, 32, 1, "#c4c9d0"); t.r(0, 31, 32, 1, "#5a5f66"); t.r(0, 0, 1, 32, "#6a6f76")
    for x in range(-16, 48, 8):                                           # hazard band
        for k in range(8):
            for y in range(12, 20):
                if (x + k + (y - 12)) % 16 < 8:
                    t.p(x + k, y, "#ffc21a")
    for x in range(32):
        for y in range(12, 20):
            if t.im.getpixel((x, y)) == hx("#8d9299") or ((x + (y - 12)) % 16 >= 8):
                t.p(x, y, "#1a1a1a")
    t.r(0, 11, 32, 1, "#14141a"); t.r(0, 20, 32, 1, "#14141a")
    for x, y in ((4, 4), (26, 4), (4, 25), (26, 25)):
        t.r(x, y, 3, 3, "#d4d8de"); t.p(x + 1, y + 1, "#4a4f56")
    return t


# ---- device 5: SATELLITE UPLINK (red; black space floor, blue solar-panel wall) ----
def satellite_floor(v):
    BG[0] = "#05050c"
    t = T("#05050c")
    rnd = random.Random(500 + v)
    if v == 1:
        for _ in range(5):
            cx, cy = rnd.randrange(6, 26), rnd.randrange(6, 26)
            for dx in range(-5, 6):
                for dy in range(-5, 6):
                    if dx * dx + dy * dy <= 25 and rnd.random() < 0.5:
                        t.p(cx + dx, cy + dy, "#120a1e")
    for _ in range(14 + v * 2):
        t.p(rnd.randrange(32), rnd.randrange(32), rnd.choice(["#2a2a44", "#3a3a5a", "#5a5a80"]))
    if v == 2:
        pts = [(5, 24), (12, 18), (20, 21), (27, 10)]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            n = max(abs(x1 - x0), abs(y1 - y0))
            for k in range(0, n + 1, 2):
                t.p(round(x0 + (x1 - x0) * k / n), round(y0 + (y1 - y0) * k / n), "#1a1a30")
        for x, y in pts:
            t.p(x, y, "#a0a0d0")
    if v == 3:
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2)):
            t.p(22 + dx, 11 + dy, "#e8e8ff" if dx == 0 and dy == 0 else "#5a5a90")
    return t


def satellite_wall():
    t = T("#173a7a")
    for y in range(32):
        for x in range(32):
            if (x // 8 + y // 8) % 2 == 0:
                t.p(x, y, "#1c4690")
    for k in range(0, 32, 8):
        t.r(k, 0, 1, 32, "#c4cee0"); t.r(0, k, 32, 1, "#c4cee0")
    for k in range(0, 32, 8):                                              # cell bus bars
        t.r(k + 4, 1, 1, 7, "#2a5aa8") if False else None
    for x in range(32):
        t.p(x, 7 + (x // 8) * 0, "#0e2a5a") if False else None
    t.r(1, 1, 3, 1, "#6a9ae8"); t.r(9, 9, 3, 1, "#6a9ae8"); t.r(17, 1, 3, 1, "#6a9ae8"); t.r(25, 9, 3, 1, "#6a9ae8")
    t.r(1, 17, 3, 1, "#6a9ae8"); t.r(9, 25, 3, 1, "#6a9ae8"); t.r(17, 17, 3, 1, "#6a9ae8"); t.r(25, 25, 3, 1, "#6a9ae8")
    return t


# ---- device 6: MAINFRAME (cyan; green-black code floor, cream retro cabinet wall) ----
def mainframe_floor(v):
    BG[0] = "#041416"
    t = T("#041416")
    rnd = random.Random(600 + v)
    for col in range(2, 32, 6):
        y = rnd.randrange(0, 12)
        while y < 30:
            h = rnd.choice([2, 3, 4])
            t.r(col, y, 2, h, rnd.choice(["#0a3a3a", "#0c4646", "#082c2e"]))
            y += h + rnd.randrange(2, 6)
    if v == 1:
        t.r(0, 0, 32, 1, "#0f4a4c"); t.r(0, 31, 32, 1, "#0f4a4c"); t.r(0, 0, 1, 32, "#0f4a4c"); t.r(31, 0, 1, 32, "#0f4a4c")
    if v == 2:
        t.r(0, 15, 32, 1, "#0c3a3c")
    if v == 3:
        t.r(14, 6, 2, 3, "#2ad8d0"); t.r(14, 7, 2, 1, "#c8ffff")
    return t


def mainframe_wall():
    t = T("#cdc5a6")
    t.r(0, 0, 32, 1, "#ebe4c8"); t.r(0, 31, 32, 1, "#8a8468"); t.r(0, 0, 1, 32, "#aaa386"); t.r(31, 0, 1, 32, "#aaa386")
    for cy in (9,):
        for cx in (9, 23):
            for dx in range(-6, 7):
                for dy in range(-6, 7):
                    d = dx * dx + dy * dy
                    if 25 < d <= 36:
                        t.p(cx + dx, cy + dy, "#3a3626")
                    elif 4 < d <= 25:
                        t.p(cx + dx, cy + dy, "#8a8468")
            t.r(cx - 1, cy - 1, 3, 3, "#3a3626")
    for k, c in enumerate(("#d83a3a", "#ffb43a", "#4ad86a", "#ffb43a", "#d83a3a")):
        t.r(4 + k * 5, 23, 3, 3, c)
    for k in range(10):
        t.p(3 + k * 3, 29, "#3a3626")
    return t


# ---- device 7: QUANTUM CORE (white; indigo lattice floor, crystal wall) ----
def quantum_floor(v):
    BG[0] = "#0a0a1c"
    t = T("#0a0a1c")
    for x in range(4, 32, 8):
        for y in range(4, 32, 8):
            t.p(x, y, "#22225a")
    rnd = random.Random(700 + v)
    if v == 1:
        for deg in range(0, 360, 9):
            import math
            t.p(round(15.5 + 11 * math.cos(math.radians(deg))), round(15.5 + 11 * math.sin(math.radians(deg))), "#1c1c4a")
    if v == 2:
        import math
        for r_ in (5, 11):
            for deg in range(0, 360, 12):
                t.p(round(15.5 + r_ * math.cos(math.radians(deg))), round(15.5 + r_ * math.sin(math.radians(deg))), "#181840")
        t.p(15, 15, "#6a6ac0"); t.p(16, 16, "#6a6ac0")
    if v == 3:
        for _ in range(9):
            t.p(rnd.randrange(32), rnd.randrange(32), rnd.choice(["#2c2c6a", "#44449a"]))
    return t


def quantum_wall():
    t = T("#b9a8ff")
    bands = ["#b9a8ff", "#d6cbff", "#9a86f0", "#e8e0ff"]
    for y in range(32):
        for x in range(32):
            t.p(x, y, bands[((x + y) // 4) % 4])
    for y in range(32):
        for x in range(32):
            if (x + y) % 16 == 0:
                t.p(x, y, "#ffffff")
    for x, y in ((6, 4), (22, 20), (12, 26)):
        t.p(x, y, "#ffffff"); t.p(x - 1, y, "#f4f0ff"); t.p(x + 1, y, "#f4f0ff"); t.p(x, y - 1, "#f4f0ff"); t.p(x, y + 1, "#f4f0ff")
    t.r(0, 0, 32, 1, "#7a64d8"); t.r(0, 0, 1, 32, "#7a64d8")
    return t


# ---- device 1 (new): every wall block is an app icon, 64x64 art, drawn stretched over the block ----
from PIL import ImageDraw


def _icon_base(c_top, c_bot, glyph):
    t = T(None, 64)
    d = ImageDraw.Draw(t.im)
    mask = Image.new("L", (64, 64), 0)
    ImageDraw.Draw(mask).rounded_rectangle((1, 1, 62, 62), radius=14, fill=255)
    top, bot = hx(c_top), hx(c_bot)
    for y in range(64):
        k = y / 63.0
        col = tuple(int(top[i] + (bot[i] - top[i]) * k) for i in range(3)) + (255,)
        for x in range(64):
            if mask.getpixel((x, y)):
                t.im.putpixel((x, y), col)
    for y in range(3, 9):                                                 # soft top gloss: a gentle lightening inside the icon, no hard line
        k = 0.22 * (1 - (y - 3) / 6.0)
        for x in range(64):
            if mask.getpixel((x, y)) and t.im.getpixel((x, y))[3] == 255:
                r_, g_, b_, _ = t.im.getpixel((x, y))
                t.im.putpixel((x, y), (int(r_ + (255 - r_) * k), int(g_ + (255 - g_) * k), int(b_ + (255 - b_) * k), 255))
    ImageDraw.Draw(t.im).rounded_rectangle((1, 1, 62, 62), radius=14, outline=hx("#0a0e24"), width=2)
    glyph(d)
    return t


W = hx("#ffffff")
K = hx("#14183a")


def g_phone(d):
    d.line((20, 44, 44, 20), fill=W, width=9)
    d.ellipse((13, 38, 27, 52), fill=W); d.ellipse((37, 12, 51, 26), fill=W)


def g_msg(d):
    d.rounded_rectangle((12, 14, 52, 40), radius=7, fill=W)
    d.polygon([(18, 38), (18, 51), (30, 38)], fill=W)
    for x in (23, 32, 41):
        d.rectangle((x, 25, x + 3, 28), fill=hx("#2a7a52"))


def g_cam(d):
    d.rounded_rectangle((11, 22, 53, 48), radius=5, fill=W)
    d.rectangle((24, 15, 38, 22), fill=W)
    d.ellipse((22, 26, 42, 46), fill=K); d.ellipse((26, 30, 38, 42), fill=hx("#4a7aff")); d.rectangle((29, 32, 31, 34), fill=W)


def g_music(d):
    d.ellipse((17, 38, 31, 51), fill=W)
    d.rectangle((28, 14, 32, 44), fill=W)
    d.polygon([(32, 14), (46, 20), (46, 28), (32, 22)], fill=W)


def g_mail(d):
    d.rounded_rectangle((11, 17, 53, 47), radius=4, fill=W)
    d.line((13, 20, 32, 35), fill=hx("#3a6ad8"), width=3); d.line((51, 20, 32, 35), fill=hx("#3a6ad8"), width=3)


def g_maps(d):
    d.polygon([(32, 54), (19, 31), (45, 31)], fill=hx("#e83a3a"))
    d.ellipse((19, 14, 45, 40), fill=hx("#e83a3a")); d.ellipse((27, 22, 37, 32), fill=W)


def g_clock(d):
    d.ellipse((12, 12, 52, 52), fill=W, outline=K, width=2)
    d.line((32, 32, 32, 18), fill=K, width=3); d.line((32, 32, 43, 38), fill=hx("#e83a3a"), width=3)


def g_calc(d):
    d.rounded_rectangle((14, 11, 50, 53), radius=5, fill=hx("#2a2a34"))
    d.rectangle((18, 15, 46, 24), fill=hx("#9affb0"))
    for r in range(3):
        for c in range(3):
            d.rectangle((18 + c * 10, 29 + r * 8, 25 + c * 10, 34 + r * 8), fill=hx("#ffb43a") if c == 2 else hx("#c8ccd8"))


def g_gear(d):
    import math
    for k in range(8):
        a = math.pi * k / 4
        x, y = 32 + 17 * math.cos(a), 32 + 17 * math.sin(a)
        d.rectangle((x - 4, y - 4, x + 4, y + 4), fill=W)
    d.ellipse((17, 17, 47, 47), fill=W); d.ellipse((26, 26, 38, 38), fill=hx("#6a7088"))


def g_photos(d):
    import math
    cols = ["#ff5a5a", "#ffb43a", "#ffe03a", "#4ad86a", "#4a8aff", "#c05aff"]
    for k, c in enumerate(cols):
        a = math.pi * k / 3
        x, y = 32 + 11 * math.cos(a), 32 + 11 * math.sin(a)
        d.ellipse((x - 8, y - 8, x + 8, y + 8), fill=hx(c))
    d.ellipse((27, 27, 37, 37), fill=W)


def g_weather(d):
    d.ellipse((12, 10, 36, 34), fill=hx("#ffd83a"))
    d.ellipse((22, 28, 40, 46), fill=W); d.ellipse((32, 24, 52, 46), fill=W); d.rectangle((28, 36, 46, 46), fill=W)


def g_notes(d):
    d.rounded_rectangle((13, 10, 51, 54), radius=4, fill=W)
    d.rectangle((13, 10, 51, 19), fill=hx("#ffc83a"))
    for y in (26, 33, 40, 47):
        d.line((19, y, 45, y), fill=hx("#6a8ad8"), width=2)


ICONS = [("#5ae88a", "#1a9a4a", g_phone), ("#6ae8a8", "#18a070", g_msg), ("#8a90a8", "#3a3e56", g_cam), ("#ff7aa0", "#d82a5a", g_music),
         ("#6aa8ff", "#2a5ad8", g_mail), ("#7ad8a0", "#2a9a6a", g_maps), ("#3a3e56", "#14162a", g_clock), ("#ffa84a", "#d86a1a", g_calc),
         ("#a0a6b8", "#5a6078", g_gear), ("#f2f4ff", "#c0c8e0", g_photos), ("#6ac8ff", "#2a82d8", g_weather), ("#ffe05a", "#e8a81a", g_notes)]


# ---- device 2 (new): a wide variety of keys ----
FONT = {
    "A": " ### |#   #|#####|#   #|#   #", "S": " ####|#    | ### |    #|#### ", "D": "#### |#   #|#   #|#   #|#### ",
    "W": "#   #|#   #|# # #|## ##|#   #", "Q": " ### |#   #|# # #|#  # | ## #", "E": "#####|#    |#### |#    |#####",
    "R": "#### |#   #|#### |#  # |#   #", "F": "#####|#    |#### |#    |#    ", "Z": "#####|   # |  #  | #   |#####",
    "X": "#   #| # # |  #  | # # |#   #", "C": " ####|#    |#    |#    | ####", "V": "#   #|#   #|#   #| # # |  #  ",
    "UP": "  #  | ### |#####|  #  |  #  ", "DN": "  #  |  #  |#####| ### |  #  ", "LT": "  #  | ##  |#####| ##  |  #  ", "RT": "  #  |  ## |#####|  ## |  #  ",
    "1": "  #  | ##  |  #  |  #  | ### ", "2": " ### |#   #|  ## | #   |#####", "3": "#### |    #| ### |    #|#### ", "4": "#  # |#  # |#####|   # |   # ",
    "SH": "  #  | # # |#   #|## ##| ### ",
}
KEYS = ["A", "S", "D", "W", "Q", "E", "R", "F", "Z", "X", "C", "V", "UP", "DN", "LT", "RT", "1", "2", "3", "4", "SH", None]
KEY_COL = ["#7a4ad8", "#3ad8ff", "#ff4ad0", "#d8c8ff"]


def laptop_floor_v(v):
    BG[0] = "#140a26"
    t = T("#140a26")
    t.r(2, 3, 28, 26, "#0a0516"); t.r(2, 3, 28, 25, "#1c1136"); t.r(3, 3, 26, 1, "#33205c")
    t.r(2, 27, 28, 2, "#0a0516")
    key = KEYS[v % len(KEYS)]
    col = KEY_COL[v % len(KEY_COL)]
    if key is None:
        t.r(8, 22, 16, 2, "#7a2fb8"); t.r(8, 23, 16, 1, "#3a1470")
    else:
        rows = FONT[key].split("|")
        for ry, row in enumerate(rows):
            for rx, ch in enumerate(row):
                if ch == "#":
                    t.r(11 + rx * 2, 10 + ry * 2, 2, 2, col)
    return t


# ---- THE INTERNET: teal circuit-trace floor, red firewall-brick wall ----
def internet_floor(v):
    BG[0] = "#051a1c"
    t = T("#051a1c")
    rnd = random.Random(800 + v)
    tr, tr2 = "#0b3a3c", "#0f5254"
    for _ in range(3):
        x, y = rnd.randrange(2, 30), rnd.randrange(2, 30)
        for _ in range(3):
            if rnd.random() < 0.5:
                n = rnd.randrange(4, 12); t.r(x, y, n, 1, tr); x = min(31, x + n)
            else:
                n = rnd.randrange(4, 12); t.r(x, y, 1, n, tr); y = min(31, y + n)
        t.r(max(0, x - 1), max(0, y - 1), 3, 3, tr2); t.p(x, y, "#051a1c")
    if v == 1:
        for k in range(6):
            t.r(4 + k * 4, 14, 2, 4, tr2)
    if v == 2:
        for _ in range(10):
            t.p(rnd.randrange(32), rnd.randrange(32), rnd.choice(["#1a6a6a", "#25a0a0"]))
    if v == 3:
        for i, ch in enumerate("1011"):
            if ch == "1":
                t.r(10 + i * 4, 12, 1, 5, "#1f8a8a")
            else:
                t.r(10 + i * 4, 12, 2, 1, "#1f8a8a"); t.r(10 + i * 4, 16, 2, 1, "#1f8a8a"); t.r(10 + i * 4, 13, 1, 3, "#1f8a8a"); t.r(11 + i * 4, 13, 1, 3, "#1f8a8a")
    return t


def internet_wall():
    t = T("#a8321c")
    rnd = random.Random(9)
    for row in range(4):
        y = row * 8
        off = 0 if row % 2 == 0 else 8
        for bx in range(-8, 40, 16):
            x0 = bx + off
            base = rnd.choice(["#d8481f", "#c93d1a", "#e0562a"])
            t.r(x0 + 1, y + 1, 14, 6, base)
            t.r(x0 + 1, y + 1, 14, 1, "#ff9a5a")
            t.r(x0 + 1, y + 6, 14, 1, "#8a2410")
            if rnd.random() < 0.5:
                t.p(x0 + rnd.randrange(3, 13), y + rnd.randrange(2, 5), "#ffd0a0")
    for y in range(0, 32, 8):
        t.r(0, y, 32, 1, "#3a0e0a")
    for row in range(4):
        off = 0 if row % 2 == 0 else 8
        for bx in range(-8, 40, 16):
            x = bx + off
            if 0 <= x < 32:
                t.r(x, row * 8, 1, 8, "#3a0e0a")
    return t


SETS = {1: (phone_floor, phone_wall), 2: (laptop_floor_v, laptop_wall), 3: (server_floor, server_wall), 4: (datacenter_floor, datacenter_wall),
        5: (satellite_floor, satellite_wall), 6: (mainframe_floor, mainframe_wall), 7: (quantum_floor, quantum_wall), 8: (internet_floor, internet_wall)}


def clear(prefix):
    if os.path.isdir(OUT):
        for f in os.listdir(OUT):
            if f.startswith(prefix) and f.endswith(".png"):
                os.remove(os.path.join(OUT, f))


if __name__ == "__main__":
    SETS[0] = (fridge_floor, lambda: fridge_wall())
    clear("floor_"); clear("wall_"); clear("icon_")
    for tier, (ff, fw) in sorted(SETS.items()):
        nvar = len(KEYS) if tier == 2 else 4
        for v in range(nvar):
            ff(v).save("floor_%d_%d" % (tier, v))
        if tier == 1:
            for i, (c1, c2, gl) in enumerate(ICONS):
                _icon_base(c1, c2, gl).save("icon_1_%d" % i, 1)
            continue
        wall = fw()
        wall.save("wall_%d" % tier, 4)
        if tier == 4:   # vertical data-center walls use the tile turned 90 degrees
            wall.im = wall.im.rotate(90)
            wall.save("wall_%d_v" % tier, 4)
    pv = Image.new("RGBA", (8 * 64 * 2 + 40, 5 * 130), (0, 0, 0, 255))
    rnd = random.Random(3)
    for tier in range(9):
        ox, oy = (tier % 2) * (64 * 8 + 20), (tier // 2) * 130
        nvar = len(KEYS) if tier == 2 else 4
        for cy in range(2):
            for cx in range(6):
                pv.paste(Image.open(os.path.join(OUT, "floor_%d_%d.png" % (tier, rnd.randrange(nvar)))), (ox + cx * 64, oy + cy * 64))
        if tier == 1:
            for k in range(2):
                pv.paste(Image.open(os.path.join(OUT, "icon_1_%d.png" % (k * 5))).convert("RGBA"), (ox + 6 * 64 + 4 + k * 64, oy))
        else:
            w = Image.open(os.path.join(OUT, "wall_%d.png" % tier)).resize((128, 128), Image.NEAREST)
            pv.paste(w, (ox + 6 * 64 + 4, oy))
    pv.save(os.path.join(OUT, "..", "..", "..", "tiles_preview.png"))
