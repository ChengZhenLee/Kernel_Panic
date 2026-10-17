#!/usr/bin/env python3
"""Kernel Panic: pixel art of the smartphone secret room (A2), drawn on small grids and scaled with nearest-neighbour.

  art/secret/smartphone_secret_room_wall_<app>.png     192x32 art x4 = 768x128 (clock 12 tiles: 1536x128)  strip of wall-tile variants (32x32 art x4); the game picks one per wall block
  art/secret/smartphone_secret_room_floor_<app>.png     64x64   floor tile (16x16 art x4)
  art/secret/smartphone_secret_room_digit_<0..9>.png   128x128  bevelled keypad buttons of the phone room
  art/secret/smartphone_secret_room_spot.png           256x64   floor spot ring, 4 frames of 64x64 (white, tinted in game)
  art/secret/smartphone_secret_room_glyph_<kind>.png    64x64   spot glyphs (16x16 art x4, white, tinted in game)
  art/secret/smartphone_secret_room_clock_face.png     256x256  the big clock decal of the clock room
  art/secret/smartphone_secret_room_photo_*.png        384x288  the photos of the camera and photos apps (64x48 art x6)
  art/hazards/thunder.png         1280x64   THUNDER STRIKE hazard sheet, 20 frames like strike.png

usage: python3 tools/gen_app_art.py
"""
import math
import os
import random

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "art", "secret")
HAZ = os.path.join(HERE, "..", "art", "hazards")
O = "#0a0e24"   # the outline colour of the whole game's art


def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


class T:
    def __init__(self, bg, n=32, m=None):
        self.w = n
        self.h = m or n
        self.im = Image.new("RGBA", (self.w, self.h), hx(bg) if bg else (0, 0, 0, 0))

    def p(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.im.putpixel((int(x), int(y)), hx(c) if isinstance(c, str) else c)

    def r(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.p(xx, yy, c)

    def box(self, x, y, w, h, c):
        self.r(x, y, w, 1, c)
        self.r(x, y + h - 1, w, 1, c)
        self.r(x, y, 1, h, c)
        self.r(x + w - 1, y, 1, h, c)

    def disc(self, cx, cy, rad, c):
        for yy in range(int(cy - rad - 1), int(cy + rad + 2)):
            for xx in range(int(cx - rad - 1), int(cx + rad + 2)):
                if (xx + 0.5 - cx) ** 2 + (yy + 0.5 - cy) ** 2 <= rad * rad:
                    self.p(xx, yy, c)

    def ring(self, cx, cy, rad, c, th=1.0):
        for yy in range(int(cy - rad - 2), int(cy + rad + 3)):
            for xx in range(int(cx - rad - 2), int(cx + rad + 3)):
                d = math.hypot(xx + 0.5 - cx, yy + 0.5 - cy)
                if rad - th < d <= rad:
                    self.p(xx, yy, c)

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            k = i / max(n, 1)
            self.p(round(x0 + (x1 - x0) * k), round(y0 + (y1 - y0) * k), c)

    def save(self, path, scale):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.im.resize((self.w * scale, self.h * scale), Image.NEAREST).save(path)


def secret(name, t, scale):
    t.save(os.path.join(OUT, name + ".png"), scale)


# ------------------------------------------------------------------ wall tiles (32x32 -> 128), SIX variants per app
# Every app's wall is a strip of NV tiles (NV*32 x 32, saved x4); the game picks one per wall block, so a wall is never one repeated picture.
NV = 6


def wall_notes(v):
    """Legal-pad paper (rules, margin, binding holes) with a different thing on each variant: ink, checklist, doodle star, coffee ring, torn corner, sticky note."""
    rnd = random.Random(100 + v)
    t = T("#f3e2a0")
    t.box(0, 0, 32, 32, "#b8962c")
    for y in range(6, 31, 4):
        t.r(1, y, 30, 1, "#6a85d4")
    t.r(7, 1, 1, 30, "#e0594a")
    for y in (4, 14, 24):
        t.disc(3, y, 1.4, "#6b5a2a")
    ink = "#2b3a78"
    if v == 0:
        for y in (5, 9, 13, 17, 21, 25):
            w = rnd.randrange(7, 17)
            t.r(10, y, w, 1, ink)
            t.r(10 + w // 3, y - 1, 1, 1, ink)
    elif v == 1:                                                         # a checklist
        for i, y in enumerate((6, 10, 14, 18, 22)):
            t.box(10, y - 2, 3, 3, ink)
            if i < 3:
                t.p(11, y - 1, "#d9503e")
            t.r(15, y - 1, rnd.randrange(6, 13), 1, ink)
    elif v == 2:                                                         # a doodled star and arrow
        for dx, dy in ((0, -6), (2, -1), (7, -1), (3, 2), (5, 7), (0, 3), (-5, 7), (-3, 2), (-7, -1), (-2, -1)):
            t.p(19 + dx, 15 + dy, "#e0594a")
        t.line(10, 26, 24, 26, ink); t.line(24, 26, 21, 24, ink); t.line(24, 26, 21, 28, ink)
        t.r(10, 5, 12, 1, ink)
    elif v == 3:                                                         # a coffee ring
        t.ring(20, 18, 8, "#a8742c", 1.2); t.ring(20, 18, 6.5, "#c8964a", 1.0)
        t.r(10, 5, 14, 1, ink); t.r(10, 9, 9, 1, ink); t.r(10, 26, 12, 1, ink)
    elif v == 4:                                                         # a torn corner
        for y in range(22, 32):
            for x in range(22, 32):
                if x + y > 53:
                    t.p(x, y, "#1a1f30")
        t.line(22, 31, 31, 22, "#d8c47a")
        t.r(10, 5, 15, 1, ink); t.r(10, 9, 10, 1, ink); t.r(10, 13, 14, 1, ink)
    else:                                                                # a sticky note
        t.r(12, 8, 14, 14, "#ffd84a"); t.box(12, 8, 14, 14, O); t.r(13, 9, 12, 2, "#e8b830")
        t.r(14, 13, 10, 1, "#7a5a10"); t.r(14, 16, 7, 1, "#7a5a10"); t.r(14, 19, 9, 1, "#7a5a10")
    return t


def wall_camera(v):
    """A strip of film (sprocket holes both sides); each variant's frame holds a different scene."""
    t = T("#0f1220")
    t.box(0, 0, 32, 32, "#2a3050")
    for y in range(1, 31, 4):
        t.r(2, y, 3, 2, "#e6e9f5"); t.r(27, y, 3, 2, "#e6e9f5")
    t.r(7, 3, 18, 26, O)
    sky = [("#4f8cff", "#8fc4ff"), ("#d9503e", "#f2b36a"), ("#0a0e24", "#1c2a5a"), ("#6fb8f0", "#bfe6ff"), ("#8a9cc0", "#c0c9e0"), ("#2a1f4a", "#6a4aa0")][v]
    for y in range(4, 28):
        t.r(8, y, 16, 1, sky[0] if y < 12 else (sky[1] if y < 18 else "#1d3a2a"))
    if v == 0:
        t.disc(18, 10, 2.6, "#fff0b0")
        for x0, h in ((9, 5), (13, 7), (17, 4)):
            for dx in range(5):
                hh = max(0, h - abs(dx - 2) * 2)
                t.r(x0 + dx, 18 - hh, 1, hh, "#2e7a4a")
    elif v == 1:                                                         # sunset over the sea
        t.disc(16, 17, 4, "#ffd06a"); t.r(8, 18, 16, 10, "#2f6fd8")
        for x in (10, 14, 18, 21):
            t.r(x, 21, 3, 1, "#f2b36a")
    elif v == 2:                                                         # night sky with stars and a moon
        for x, y in ((10, 6), (14, 9), (20, 7), (22, 14), (12, 14), (18, 5)):
            t.p(x, y, "#ffffff")
        t.disc(20, 10, 3, "#e8e4c8"); t.disc(21, 9, 2.4, "#0a0e24")
    elif v == 3:                                                         # a city skyline
        for x, h in ((9, 8), (12, 12), (15, 6), (18, 10), (21, 7)):
            t.r(x, 25 - h, 3, h, "#2a3050")
            for yy in range(25 - h + 1, 24, 2):
                t.p(x + 1, yy, "#ffe06a")
    elif v == 4:                                                         # a portrait: head and shoulders
        t.r(8, 12, 16, 16, "#8a9cc0"); t.disc(16, 14, 4, "#f0c8a0"); t.r(11, 20, 10, 8, "#3a5cc8"); t.r(14, 11, 5, 2, "#4a3020")
    else:                                                                # a ghostly double exposure
        t.disc(14, 16, 5, "#8a6ac0"); t.disc(18, 17, 5, "#6a4aa0")
        t.p(15, 15, "#ffffff"); t.p(18, 15, "#ffffff")
    return t


def wall_store(v):
    """Shop shelving, two planks per tile with different stock on each variant."""
    rnd = random.Random(300 + v)
    t = T("#5a3818")
    t.box(0, 0, 32, 32, "#3a2410")
    for y0 in (1, 17):
        t.r(1, y0 + 12, 30, 3, "#b07a42"); t.r(1, y0 + 14, 30, 1, "#6e4520")
    kinds = ["box", "jar", "crate", "tag", "can", "bag"]
    for row, y0 in enumerate((1, 17)):
        x = 2
        while x < 26:
            k = kinds[(v + row * 2 + rnd.randrange(6)) % 6]
            w = rnd.randrange(6, 10)
            base = y0 + 12
            if k == "box":
                col = rnd.choice(["#f2a33a", "#4f8cff", "#d9503e", "#8fd0a8"])
                h = rnd.randrange(7, 10)
                t.r(x, base - h, w, h, col); t.box(x, base - h, w, h, O); t.r(x + w // 2, base - h, 1, h, "#e8d9a8")
            elif k == "jar":
                t.disc(x + w // 2, base - 4, 3.6, O); t.disc(x + w // 2, base - 4, 2.8, rnd.choice(["#8fd0a8", "#f2a33a", "#f0c8e0"]))
                t.r(x + w // 2 - 2, base - 9, 5, 2, "#c0c9e6")
            elif k == "crate":
                t.r(x, base - 6, w, 6, "#8a5a2b"); t.box(x, base - 6, w, 6, O); t.r(x + 1, base - 4, w - 2, 1, "#6e4520")
            elif k == "tag":
                t.r(x, base - 8, w, 8, "#f5f1e4"); t.box(x, base - 8, w, 8, O); t.r(x + 1, base - 6, w - 2, 1, O); t.r(x + 1, base - 4, w - 4, 1, "#d9503e")
            elif k == "can":
                t.r(x + 1, base - 8, w - 2, 8, "#c0c9e6"); t.box(x + 1, base - 8, w - 2, 8, O); t.r(x + 2, base - 5, w - 4, 2, "#d9503e")
            else:
                t.r(x, base - 9, w, 9, "#d8b878"); t.box(x, base - 9, w, 9, O); t.r(x + 1, base - 9, w - 2, 2, "#b08a48")
            x += w + 2
    return t


def wall_mail(v):
    """A pigeonhole sorting wall: four cubbies whose contents change per variant (letters, a parcel, empty, stamped stacks)."""
    rnd = random.Random(400 + v)
    t = T("#3a4260")
    t.box(0, 0, 32, 32, "#8d9bc4")
    cols = ["#ffffff", "#ffe9a8", "#c9e4ff", "#ffd0d0", "#d8f0d0"]
    for i, (ox, oy) in enumerate(((1, 1), (17, 1), (1, 17), (17, 17))):
        t.r(ox, oy, 14, 14, "#1a1f30")
        mode = (v + i) % 5
        if mode == 4:                                                    # empty cubby, a cobweb corner
            t.line(ox, oy, ox + 4, oy + 4, "#4a5478"); t.line(ox + 4, oy, ox, oy + 4, "#4a5478")
        elif mode == 3:                                                  # a parcel tied with string
            t.r(ox + 2, oy + 4, 10, 9, "#b08a48"); t.box(ox + 2, oy + 4, 10, 9, O); t.r(ox + 6, oy + 4, 2, 9, "#e8d9a8")
        else:
            for k in range(1 + rnd.randrange(3)):
                y = oy + 9 - k * 3
                c = rnd.choice(cols)
                t.r(ox + 2 + k, y, 10, 5, O); t.r(ox + 3 + k, y + 1, 8, 3, c)
                t.line(ox + 3 + k, y + 1, ox + 7 + k, y + 3, "#9aa6cc"); t.line(ox + 10 + k, y + 1, ox + 7 + k, y + 3, "#9aa6cc")
            if mode != 2:
                t.r(ox + 11, oy + 2, 2, 2, "#d9503e")
    return t


def wall_messages(v):
    """A chat log: bubbles on both sides; per variant different layouts (two bubbles, one long message, three short replies, a heart, an unread badge, typing dots)."""
    rnd = random.Random(500 + v)
    t = T("#102a22")
    t.box(0, 0, 32, 32, "#0b1d17")

    def bubble(x, y, w, h, c, hi, tl, right):
        t.r(x, y, w, h, O); t.r(x + 1, y + 1, w - 2, h - 2, c); t.r(x + 1, y + 1, w - 2, 1, hi)
        tx = x + w - 4 if right else x + 1
        t.r(tx, y + h, 3, 2, O); t.r(tx + 1, y + h - 1, 2, 2, c)
        for k in range(tl):
            t.r(x + 3, y + 3 + k * 2, rnd.randint(max(2, w // 2), max(2, w // 2, w - 5)), 1, "#1c3a8a" if right else "#1c5a42")
    g, b = ("#6fe3a0", "#9af0be"), ("#4f8cff", "#8db4ff")
    if v == 0:
        bubble(2, 2, 20, 11, g[0], g[1], 2, False); bubble(10, 17, 20, 10, b[0], b[1], 2, True)
    elif v == 1:                                                         # one long message
        bubble(2, 3, 26, 17, g[0], g[1], 4, False)
        for x in (3, 6, 9):
            t.p(x, 26, "#3f8f6c")
    elif v == 2:                                                         # three short replies
        bubble(2, 2, 12, 7, g[0], g[1], 1, False); bubble(16, 12, 14, 7, b[0], b[1], 1, True); bubble(2, 21, 10, 7, g[0], g[1], 1, False)
    elif v == 3:                                                         # a heart reaction
        bubble(2, 3, 22, 11, b[0], b[1], 2, True)
        for x, y in ((18, 19), (20, 19), (22, 19), (17, 20), (18, 20), (19, 20), (20, 20), (21, 20), (22, 20), (23, 20),
                     (18, 21), (19, 21), (20, 21), (21, 21), (22, 21), (19, 22), (20, 22), (21, 22), (20, 23)):
            t.p(x, y, "#ff5f7f")
    elif v == 4:                                                         # an unread badge
        bubble(2, 4, 20, 11, g[0], g[1], 2, False); t.disc(26, 5, 3, O); t.disc(26, 5, 2.2, "#d9503e")
        bubble(12, 20, 17, 8, b[0], b[1], 1, True)
    else:                                                                # typing dots bubble
        t.r(2, 6, 20, 10, O); t.r(3, 7, 18, 8, "#2a4a3c")
        for x in (7, 12, 17):
            t.disc(x, 11, 1.5, "#9af0be")
        bubble(12, 21, 16, 7, b[0], b[1], 1, True)
    return t


def wall_maps(v):
    """Survey-map paper; each variant is a different terrain: hills with a river, a lake, forest, a road grid, a coast, mountains."""
    rnd = random.Random(600 + v)
    t = T("#d9c48a")
    t.box(0, 0, 32, 32, "#8a7440")
    for q in (8, 16, 24):
        for k in range(1, 31, 3):
            t.p(q, k, "#b9a46a"); t.p(k, q, "#b9a46a")
    if v == 0:
        for (cx, cy), rads in (((10, 11), (3.5, 6.5, 9.5)), ((24, 24), (2.5, 5.0, 7.5))):
            for r_ in rads:
                for a in range(0, 360, 4):
                    t.p(round(cx + math.cos(math.radians(a)) * r_ * 1.15), round(cy + math.sin(math.radians(a)) * r_ * 0.85), "#8a5a2b")
        for x in range(1, 31):
            t.p(x, round(20 + 4 * math.sin(x / 5.0)), "#4f9be0")
    elif v == 1:                                                         # a lake
        t.disc(16, 16, 11, "#5a7a40"); t.disc(16, 16, 10, "#6aa8d8"); t.disc(16, 16, 7, "#8fd0e8"); t.disc(16, 16, 4, "#a8e0f0")
        t.line(1, 4, 8, 10, "#8a5a2b")
    elif v == 2:                                                         # forest
        for _ in range(22):
            x, y = rnd.randrange(2, 28), rnd.randrange(2, 27)
            t.r(x, y, 3, 3, "#4a9a50"); t.p(x, y, "#6ac070"); t.p(x + 1, y + 3, "#6e4520")
    elif v == 3:                                                         # a road grid
        for q in (7, 15, 23):
            t.r(1, q, 30, 2, "#f6f1e0"); t.r(q, 1, 2, 30, "#f6f1e0")
        t.r(15, 15, 2, 2, "#d9503e")
    elif v == 4:                                                         # a coast
        t.r(1, 1, 30, 30, "#8fd0e8")
        for x in range(1, 31):
            h = 12 + round(5 * math.sin(x / 4.0))
            t.r(x, 1, 1, h, "#d9c48a"); t.p(x, h + 1, "#f6f1e0")
    else:                                                                # mountains
        for cx in (9, 20, 26):
            for k in range(7):
                t.r(cx - k, 15 + k, 2 * k + 1, 1, "#8a7a6a" if k > 1 else "#f6f1e0")
        t.line(2, 28, 28, 28, "#8a5a2b")
    t.r(25, 3, 3, 3, O); t.r(26, 4, 1, 1, "#e04040")
    return t


def wall_music(v):
    """Speaker cabinet (variant 0, the original); then a vinyl record, headphones, a cassette, piano keys and an equaliser."""
    t = T("#241b3a")
    t.box(0, 0, 32, 32, "#3b2c5e")
    if v == 0:
        t.disc(16, 19, 11.5, O); t.disc(16, 19, 10.5, "#41386a"); t.ring(16, 19, 10.5, "#6a5aa8", 1.0)
        t.disc(16, 19, 7.5, "#241b45"); t.ring(16, 19, 7.5, "#5a4a96", 1.0)
        t.disc(16, 19, 3, "#150f26"); t.p(15, 18, "#7a6ac0")
        t.disc(16, 6, 3.2, O); t.disc(16, 6, 2.2, "#6a5aa8"); t.p(15, 5, "#c9b8ff")
        t.r(3, 3, 3, 3, "#ff5fb0"); t.r(26, 3, 3, 3, "#ff5fb0")
    elif v == 1:                                                         # vinyl record
        t.disc(16, 16, 13, O); t.disc(16, 16, 12, "#14101f")
        for r_ in (4, 6, 8, 10):
            t.ring(16, 16, r_ + 2, "#241b45", 1.0)
        t.disc(16, 16, 4, "#ff5fb0"); t.disc(16, 16, 1, O)
    elif v == 2:                                                         # headphones
        for a in range(200, 341, 3):
            t.disc(16 + math.cos(math.radians(a)) * 11, 18 + math.sin(math.radians(a)) * 11, 1.6, "#ff5fb0")
        t.r(2, 14, 6, 11, O); t.r(3, 15, 4, 9, "#6a5aa8"); t.r(24, 14, 6, 11, O); t.r(25, 15, 4, 9, "#6a5aa8")
    elif v == 3:                                                         # a cassette
        t.r(3, 7, 26, 18, O); t.r(4, 8, 24, 16, "#d8c8a8"); t.r(7, 10, 18, 7, "#241b45")
        t.disc(11, 14, 2.5, "#f6f0e0"); t.disc(21, 14, 2.5, "#f6f0e0"); t.disc(11, 14, 1, O); t.disc(21, 14, 1, O)
        t.r(9, 20, 14, 3, "#8a7a5a"); t.r(14, 22, 4, 1, O)
    elif v == 4:                                                         # piano keys
        t.r(2, 6, 28, 20, O)
        for x in range(3, 29, 4):
            t.r(x, 7, 3, 18, "#f6f0ff")
        for x in (6, 10, 18, 22, 26):
            t.r(x - 1, 7, 3, 10, "#15102a")
    else:                                                                # equaliser
        for i, h in enumerate((6, 12, 18, 9, 15, 20, 8)):
            t.r(3 + i * 4, 27 - h, 3, h, "#ff5fb0" if h > 14 else "#a06ae0"); t.r(3 + i * 4, 27 - h, 3, 1, "#ffd0ec")
    return t


def wall_settings(v):
    """A control panel; each variant a different widget: sliders, toggles, a dial, checkboxes, a battery bar, a gear."""
    t = T("#2c3346")
    t.box(0, 0, 32, 32, "#4a5478")
    for x, y in ((2, 2), (29, 2), (2, 29), (29, 29)):
        t.p(x, y, "#8a94b8")
    if v == 0:
        for y, k in ((7, 20), (16, 9), (25, 15)):
            t.r(4, y, 24, 3, O); t.r(5, y + 1, 22, 1, "#1a1f30"); t.r(5, y + 1, k - 4, 1, "#4f8cff")
            t.r(k - 1, y - 2, 5, 7, O); t.r(k, y - 1, 3, 5, "#c0c9e6"); t.r(k, y - 1, 3, 1, "#f0f4ff")
    elif v == 1:                                                         # toggles
        for y, on in ((6, True), (14, False), (22, True)):
            t.r(6, y, 20, 7, O); t.r(7, y + 1, 18, 5, "#4f8cff" if on else "#1a1f30")
            t.r(19 if on else 8, y + 1, 5, 5, "#f0f4ff")
    elif v == 2:                                                         # a dial
        t.disc(16, 16, 11, O); t.disc(16, 16, 9.5, "#5a6490"); t.disc(16, 16, 6, "#2c3346"); t.line(16, 16, 22, 10, "#ffe06a")
        for a in range(-135, 136, 30):
            t.p(round(16 + math.sin(math.radians(a)) * 12), round(16 - math.cos(math.radians(a)) * 12), "#c0c9e6")
    elif v == 3:                                                         # checkboxes
        for y, c in ((6, True), (13, True), (20, False)):
            t.r(5, y, 7, 7, O); t.r(6, y + 1, 5, 5, "#1a1f30")
            if c:
                t.line(7, y + 3, 8, y + 5, "#6fe3a0"); t.line(8, y + 5, 11, y + 1, "#6fe3a0")
            t.r(15, y + 2, 12, 2, "#8a94b8")
    elif v == 4:                                                         # a battery
        t.r(4, 10, 22, 12, O); t.r(26, 13, 3, 6, O); t.r(5, 11, 20, 10, "#1a1f30")
        for x in (6, 11, 16):
            t.r(x, 12, 4, 8, "#6fe3a0")
        t.r(21, 12, 3, 8, "#d9503e")
    else:                                                                # a gear
        for a in range(0, 360, 45):
            t.disc(16 + math.cos(math.radians(a)) * 10, 16 + math.sin(math.radians(a)) * 10, 2.4, "#8a94b8")
        t.disc(16, 16, 9, O); t.disc(16, 16, 8, "#8a94b8"); t.disc(16, 16, 3.5, O); t.disc(16, 16, 2.5, "#2c3346")
    return t


def wall_photos(v):
    """A gallery wall; each variant frames four different photos (dusk, sea, forest, night, desert, snow, city, flowers)."""
    t = T("#3a3158")
    t.box(0, 0, 32, 32, "#6a5aa8")
    scenes = [("#3a5cc8", "#f2b36a", "#1c3a2a"), ("#6fb8f0", "#bfe6ff", "#2f6fd8"), ("#8fd0a8", "#c9efd0", "#1f5a34"), ("#10163a", "#2a3a7a", "#0a0e24"),
              ("#f2c06a", "#f8dca0", "#c88a40"), ("#bcd0e8", "#e8f0fa", "#f6f8ff"), ("#4a3a6a", "#8a6a9a", "#2a2a3a"), ("#8fd0f0", "#c0e8ff", "#d9503e")]
    if v % 2 == 0:
        boxes = [(2, 2, 13, 13), (17, 2, 13, 13), (2, 17, 13, 13), (17, 17, 13, 13)]
    else:
        boxes = [(2, 2, 13, 9), (17, 2, 13, 17), (2, 13, 13, 17), (17, 21, 13, 9)]
    for i, (ox, oy, w, h) in enumerate(boxes):
        a, b, g = scenes[(v * 3 + i) % 8]
        t.r(ox, oy, w, h, "#f6f3ea"); t.box(ox, oy, w, h, O)
        ih = h - 4
        for y in range(ih):
            t.r(ox + 2, oy + 2 + y, w - 4, 1, a if y < ih * 0.5 else b)
        t.r(ox + 2, oy + h - 5, w - 4, 3, g)
        t.p(ox + w - 4, oy + 4, "#fff0b0")
    return t


def wall_weather(v):
    """A sky window, a different weather per variant: storm, sun, snow, rain, fog, wind."""
    t = T("#27385c")
    t.box(0, 0, 32, 32, "#1a2745")

    def cloud(y0, c, hi):
        for x in range(1, 31):
            top = y0 - round(2.4 * math.sin(x / 16.0 * math.tau))
            t.r(x, top - 1, 1, 1, O); t.r(x, top, 1, 9, c); t.r(x, top, 1, 1, hi)
    if v == 0:
        cloud(7, "#9fb0d4", "#d6e0f5")
        for y in range(18, 31):
            for x in range(1, 31):
                if (x + y) % 8 == 0:
                    t.p(x, y, "#7fb4ff")
        for dx, dy in ((15, 17), (14, 18), (13, 19), (14, 20), (15, 21), (14, 22), (13, 23), (12, 25)):
            t.r(dx, dy, 2, 1, "#ffe45a")
    elif v == 1:                                                         # sunny
        t.r(1, 1, 30, 30, "#5aa8e8"); t.disc(16, 14, 6, O); t.disc(16, 14, 5, "#ffe06a"); t.disc(16, 14, 3.4, "#fff2a8")
        for a in range(0, 360, 45):
            t.p(round(16 + math.cos(math.radians(a)) * 9), round(14 + math.sin(math.radians(a)) * 9), "#ffe06a")
        cloud(25, "#f6f8ff", "#ffffff")
    elif v == 2:                                                         # snow
        t.r(1, 1, 30, 30, "#6c7ea6")
        cloud(6, "#c0c9e6", "#f0f4ff")
        rnd = random.Random(7)
        for _ in range(26):
            t.p(rnd.randrange(2, 30), rnd.randrange(14, 30), "#ffffff")
    elif v == 3:                                                         # steady rain
        t.r(1, 1, 30, 30, "#3a4a6a")
        cloud(6, "#8a9cc0", "#c0cce8")
        for y in range(14, 31):
            for x in range(1, 31):
                if (x * 3 + y) % 7 == 0:
                    t.p(x, y, "#8fc4ff")
    elif v == 4:                                                         # fog
        t.r(1, 1, 30, 30, "#8a9cb8")
        for y in (6, 11, 16, 21, 26):
            t.r(1 + (y % 3) * 3, y, 22, 2, "#c0cce0"); t.r(8, y + 2, 20, 1, "#a8b8d0")
    else:                                                                # wind
        t.r(1, 1, 30, 30, "#7ab8e0")
        for y, x0 in ((8, 3), (15, 7), (22, 2)):
            for x in range(x0, x0 + 20):
                t.p(x, y + round(1.6 * math.sin(x / 3.0)), "#f6f8ff")
            t.p(x0 + 20, y + 2, "#f6f8ff"); t.p(x0 + 21, y + 3, "#f6f8ff")
    return t


def wall_phone(v):
    """Phone casing parts, a different one per variant: speaker grille, camera lenses, side buttons, fingerprint sensor, charging port, notch with sensors."""
    t = T("#1a1f30")
    t.box(0, 0, 32, 32, "#4a5478"); t.box(1, 1, 30, 30, "#2a3050")
    if v == 0:
        for y in range(11, 28, 3):
            for x in range(5, 28, 3):
                t.p(x, y, "#4a5478"); t.p(x, y + 1, O)
        t.r(10, 4, 12, 2, O); t.r(11, 4, 10, 1, "#3a4260"); t.disc(26, 5, 1.6, O); t.p(26, 5, "#2f6fd8")
    elif v == 1:                                                         # camera lenses
        t.r(5, 5, 22, 22, "#1a1f30"); t.box(5, 5, 22, 22, "#4a5478")
        for (x, y, r_) in ((12, 12, 4.5), (21, 12, 3.5), (12, 21, 3.5)):
            t.disc(x, y, r_ + 1, O); t.disc(x, y, r_, "#2d63e0"); t.disc(x, y, r_ - 2, "#0d1d52"); t.p(int(x) - 1, int(y) - 1, "#cfe3ff")
        t.disc(23, 22, 2, "#ffe06a")
    elif v == 2:                                                         # side buttons
        for y, h in ((6, 5), (14, 8), (25, 5)):
            t.r(1, y, 3, h, "#8a94b8"); t.r(1, y, 3, 1, "#c0c9e6"); t.r(28, y, 3, h, "#6a7498")
        t.r(8, 10, 16, 12, "#1a1f30"); t.box(8, 10, 16, 12, "#3a4260")
    elif v == 3:                                                         # fingerprint sensor
        t.disc(16, 16, 9, O); t.disc(16, 16, 8, "#222842")
        for r_ in (2, 4, 6):
            t.ring(16, 16, r_ + 0.5, "#6a7498", 1.0)
    elif v == 4:                                                         # charging port
        t.r(8, 22, 16, 5, O); t.r(9, 23, 14, 3, "#3a4260"); t.r(11, 24, 10, 1, "#c0a040")
        for x in (6, 25):
            t.disc(x, 24, 1.5, "#8a94b8")
        t.r(10, 8, 12, 2, O)
    else:                                                                # notch with sensors
        t.r(6, 1, 20, 7, O); t.r(7, 1, 18, 6, "#1a1f30")
        t.disc(21, 4, 2, "#222842"); t.p(21, 4, "#2f6fd8"); t.r(10, 3, 7, 2, "#3a4260")
        for y in range(12, 28, 4):
            t.r(6, y, 20, 1, "#3a4260")
    return t


def wall_clock(v):
    """Twelve times on one clock face (variant = hour, minutes vary)."""
    m = (v * 25) % 60 // 5 * 5
    t = T("#101a38")
    t.box(0, 0, 32, 32, "#222f5c")
    t.disc(16, 16, 13, O); t.disc(16, 16, 12, "#f2f0e6"); t.ring(16, 16, 12, "#b9b4a2", 1.0)
    for i in range(12):
        a = i / 12.0 * math.tau
        t.p(round(16 + math.sin(a) * 10), round(16 - math.cos(a) * 10), O)
    ah = (v + m / 60.0) / 12.0 * math.tau
    am = m / 60.0 * math.tau
    t.line(16, 16, round(16 + math.sin(ah) * 6), round(16 - math.cos(ah) * 6), O)
    t.line(16, 16, round(16 + math.sin(am) * 9), round(16 - math.cos(am) * 9), "#d9503e")
    t.disc(16, 16, 1.5, O)
    return t


def strip(fn, n):
    """n variants of fn side by side (an n*32 x 32 strip)."""
    s = T("#000000", 32 * n, 32)
    for v in range(n):
        s.im.paste(fn(v).im, (v * 32, 0))
    return s


# ------------------------------------------------------------------ corrupted app (hand-placed pixel glitches, fixed seed)
def wall_corrupt(v=0):
    """32x32 block: dark violet slab, magenta/cyan torn rows, stray dead pixels, a cracked bevel."""
    rnd = random.Random(404 + v)
    t = T("#1c1030")
    t.box(0, 0, 32, 32, "#4a1a5c")
    t.r(4, 4, 24, 24, "#12081f"); t.box(4, 4, 24, 24, "#8a2a78")
    for y in (7, 11, 15, 19, 23):                      # rows of the icon grid, each torn sideways by a different amount
        dx = rnd.choice([-3, -2, 2, 3, 4])
        for x in range(6, 26, 4):
            t.r(x + dx, y, 3, 2, rnd.choice(["#ff4fb8", "#2ff0e0", "#ff4fb8", "#7a2ab0"]))
    for _ in range(26):                                # dead / stuck pixels
        t.p(rnd.randrange(32), rnd.randrange(32), rnd.choice(["#ff4fb8", "#2ff0e0", "#fff0ff", "#0a0e24"]))
    t.line(2, 29, 9, 22, "#0a0e24"); t.line(24, 3, 29, 9, "#0a0e24")   # cracks across the bevel
    return t


def floor_corrupt():
    """16x16 floor: near-black violet with a faint grid, torn bars and stuck pixels."""
    rnd = random.Random(808)
    t = T("#150b22")
    t.r(0, 0, 16, 1, "#1f1032"); t.r(0, 0, 1, 16, "#1f1032")
    t.r(0, 5, 11, 1, "#3a1050"); t.r(4, 6, 12, 1, "#102a3a")          # one torn bar: the lower half is shifted
    t.r(2, 12, 7, 1, "#ff4fb8"); t.r(8, 13, 7, 1, "#2ff0e0")
    for _ in range(7):
        t.p(rnd.randrange(16), rnd.randrange(16), rnd.choice(["#ff4fb8", "#2ff0e0", "#4a1a5c"]))
    return t


# ------------------------------------------------------------------ A3 peripheral rooms (gaming laptop): one wall strip + one floor per peripheral
# gaming_laptop_secret_room_<peripheral>_wall.png (six 32x32 variants x4) and gaming_laptop_secret_room_<peripheral>_floor.png (16x16 x4)
LETTERS = {   # 5x5 pixel letters for the keycaps (each pixel drawn 2x2)
    "Q": [" ### ", "#   #", "# # #", "#  # ", " ## #"], "W": ["#   #", "#   #", "# # #", "## ##", "#   #"], "E": ["#####", "#    ", "#### ", "#    ", "#####"],
    "R": ["#### ", "#   #", "#### ", "#  # ", "#   #"], "T": ["#####", "  #  ", "  #  ", "  #  ", "  #  "], "A": [" ### ", "#   #", "#####", "#   #", "#   #"],
    "S": [" ####", "#    ", " ### ", "    #", "#### "], "D": ["#### ", "#   #", "#   #", "#   #", "#### "], "F": ["#####", "#    ", "#### ", "#    ", "#    "],
    "G": [" ####", "#    ", "# ###", "#   #", " ####"], "Z": ["#####", "   # ", "  #  ", " #   ", "#####"], "X": ["#   #", " # # ", "  #  ", " # # ", "#   #"],
    "C": [" ####", "#    ", "#    ", "#    ", " ####"], "V": ["#   #", "#   #", "#   #", " # # ", "  #  "], "B": ["#### ", "#   #", "#### ", "#   #", "#### "],
}
KEY_ORDER = "QWERTASDFGZXCVB"   # the layout's rows, left to right, top to bottom; variant 15 is the space bar
KEY_GLOWS = ["#ff4ad0", "#3ad8ff", "#7a4ad8", "#ffe03a", "#4ad86a", "#ff7a3a"]


def wall_keyboard(v):
    """A keycap: bevelled plastic key with its own letter (Q W E R T / A S D F G / Z X C V B) and an RGB edge; variant 15 is the space bar. Every block of the keyboard room is a different key."""
    glow = KEY_GLOWS[v % len(KEY_GLOWS)]
    t = T("#14162a")
    t.box(0, 0, 32, 32, glow)
    t.box(1, 1, 30, 30, "#0a0e24")
    t.r(3, 3, 26, 26, "#4a5070"); t.r(3, 3, 26, 2, "#8890b8"); t.r(3, 3, 2, 26, "#8890b8")      # the bevel: light top-left, dark bottom-right
    t.r(3, 27, 26, 2, "#2a2e48"); t.r(27, 3, 2, 26, "#2a2e48")
    t.r(6, 6, 20, 20, "#3a4060"); t.r(6, 6, 20, 1, "#5a628a")
    if v < 15:
        for y, row in enumerate(LETTERS[KEY_ORDER[v]]):
            for x, ch in enumerate(row):
                if ch == "#":
                    t.r(11 + x * 2, 11 + y * 2, 2, 2, "#f0f4ff")
    else:                                                                # the space bar: a long underscore bracket
        t.r(8, 14, 16, 2, "#f0f4ff"); t.r(8, 11, 2, 5, "#f0f4ff"); t.r(22, 11, 2, 5, "#f0f4ff")
    return t


def wall_mouse(v):
    """A mouse seen from above: buttons, scroll wheel, a sensor light, the cable and a DPI switch (one per variant)."""
    t = T("#2a2e48")
    t.box(0, 0, 32, 32, "#14162a")
    t.r(5, 2, 22, 28, "#0a0e24"); t.r(6, 3, 20, 26, "#56608a"); t.r(6, 3, 20, 2, "#8890b8")
    if v == 0:                                                           # left and right buttons with the split line
        t.r(6, 15, 20, 1, "#0a0e24"); t.r(15, 3, 2, 12, "#0a0e24"); t.r(7, 6, 7, 6, "#6a74a0"); t.r(18, 6, 7, 6, "#6a74a0")
    elif v == 1:                                                         # scroll wheel
        t.r(14, 6, 4, 10, "#0a0e24"); t.r(15, 7, 2, 8, "#ff4ad0")
        for y in (8, 10, 12, 14):
            t.p(14, y, "#3a4060"); t.p(17, y, "#3a4060")
    elif v == 2:                                                         # sensor light underneath: a red glow on the table
        t.disc(16, 22, 5, "#3a0a14"); t.disc(16, 22, 3.4, "#ff3a3a"); t.disc(16, 22, 1.6, "#ffd0d0")
    elif v == 3:                                                         # the cable
        t.r(14, 0, 4, 8, "#1a1e34")
        for y in range(8, 26):
            t.r(14 + round(3 * math.sin(y / 3.0)), y, 3, 1, "#c0c9e6")
    elif v == 4:                                                         # DPI switch with led dots
        t.r(11, 10, 10, 6, "#0a0e24")
        for i, c in enumerate(("#4ad86a", "#ffe03a", "#ff4a4a")):
            t.r(12 + i * 3, 11, 2, 4, c)
    else:                                                                # side buttons
        t.r(2, 10, 4, 6, "#ff4ad0"); t.box(2, 10, 4, 6, O); t.r(2, 18, 4, 6, "#3ad8ff"); t.box(2, 18, 4, 6, O)
    return t


def wall_webcam(v):
    """A webcam: lens, record light, privacy shutter, tripod clip, microphone holes and a status ring (one per variant)."""
    t = T("#1a2038")
    t.box(0, 0, 32, 32, "#0a0e24")
    t.r(2, 2, 28, 28, "#2a3050"); t.r(2, 2, 28, 2, "#4a5478")
    if v == 0:                                                           # the lens
        t.disc(16, 16, 11, O); t.disc(16, 16, 10, "#1a2038"); t.disc(16, 16, 7, "#2d63e0"); t.disc(16, 16, 4.5, "#0d1d52"); t.p(13, 13, "#cfe3ff"); t.p(14, 13, "#cfe3ff")
    elif v == 1:                                                         # the record light
        t.disc(16, 16, 6, O); t.disc(16, 16, 5, "#d9503e"); t.disc(16, 16, 2.6, "#ffb0a0"); t.ring(16, 16, 9, "#6a74a0", 1.2)
    elif v == 2:                                                         # privacy shutter half closed
        t.disc(16, 16, 11, O); t.disc(16, 16, 10, "#1a2038"); t.r(5, 16, 22, 11, "#4a5478")
        for x in range(5, 27, 3):
            t.r(x, 16, 1, 11, "#2a3050")
    elif v == 3:                                                         # the clip that hooks over a monitor
        t.r(8, 4, 16, 8, "#0a0e24"); t.r(9, 5, 14, 6, "#56608a"); t.r(12, 12, 8, 12, "#0a0e24"); t.r(13, 13, 6, 10, "#4a5478"); t.r(10, 24, 12, 4, "#0a0e24")
    elif v == 4:                                                         # microphone holes
        for y in range(8, 25, 4):
            for x in range(8, 25, 4):
                t.p(x, y, "#0a0e24"); t.p(x + 1, y, "#4a5478")
    else:                                                                # a status ring that is lit green
        t.ring(16, 16, 10, "#4ad86a", 2.0); t.ring(16, 16, 6, "#1a5a30", 1.0); t.disc(16, 16, 3, O)
    return t


def wall_headset(v):
    """A headset: ear cup, cushion, mic boom, volume dial, equaliser lights and the cable jack (one per variant)."""
    t = T("#241b3a")
    t.box(0, 0, 32, 32, "#0b0818")
    if v == 0:                                                           # the ear cup
        t.disc(16, 16, 13, O); t.disc(16, 16, 12, "#3b2c5e"); t.disc(16, 16, 8, "#14101f"); t.ring(16, 16, 8, "#ff5fb0", 1.2); t.disc(16, 16, 4, "#3b2c5e")
    elif v == 1:                                                         # the soft cushion
        t.disc(16, 16, 13, O); t.disc(16, 16, 12, "#8a6ac0"); t.disc(16, 16, 9, "#6a4aa0"); t.disc(16, 16, 6, "#14101f")
        t.ring(16, 16, 10, "#a98ae0", 1.0)
    elif v == 2:                                                         # the microphone boom
        t.r(3, 20, 22, 3, "#0b0818"); t.r(4, 21, 20, 1, "#6a5aa8"); t.disc(26, 21, 4, O); t.disc(26, 21, 3, "#ff5fb0"); t.p(25, 20, "#ffd0ec")
    elif v == 3:                                                         # volume dial
        t.disc(16, 16, 11, O); t.disc(16, 16, 9.5, "#56608a"); t.line(16, 16, 22, 9, "#ffe03a")
        for a in range(-135, 136, 30):
            t.p(round(16 + math.sin(math.radians(a)) * 12), round(16 - math.cos(math.radians(a)) * 12), "#c9b8ff")
    elif v == 4:                                                         # equaliser lights
        for i, h in enumerate((6, 12, 18, 9, 14, 20)):
            for k in range(h // 3):
                t.r(4 + i * 4, 28 - k * 3, 3, 2, "#ff5fb0" if k > 3 else "#a06ae0")
    else:                                                                # the cable jack
        t.r(14, 2, 4, 10, "#1a1e34"); t.r(12, 12, 8, 4, "#c0c9e6"); t.r(14, 16, 4, 10, "#a0a8c8"); t.r(15, 26, 2, 4, "#e8d878")
    return t


def floor_keyboard():
    """Dark circuit board under the keys: a faint trace grid, solder dots and a few lit RGB pixels."""
    t = T("#0e1022")
    t.r(0, 0, 16, 1, "#161a34"); t.r(0, 0, 1, 16, "#161a34")
    t.r(4, 4, 8, 1, "#1d2a52"); t.r(4, 4, 1, 6, "#1d2a52"); t.p(4, 10, "#3ad8ff"); t.p(11, 4, "#ff4ad0"); t.p(8, 12, "#7a4ad8")
    return t


def floor_mouse():
    """A cloth mousepad: dark grey weave with a stitched border line."""
    t = T("#1a1c28")
    for y in range(0, 16, 2):
        t.r(0, y, 16, 1, "#202436")
    for x in range(0, 16, 4):
        t.r(x, 0, 1, 16, "#161826")
    t.p(5, 5, "#3a4060"); t.p(12, 10, "#3a4060")
    return t


def floor_webcam():
    """Matte black with a faint scan grid and a tiny red 'REC' dot now and then."""
    t = T("#0c1022")
    t.r(0, 8, 16, 1, "#141a34"); t.r(8, 0, 1, 16, "#141a34")
    t.p(3, 3, "#3a0a14"); t.p(12, 12, "#2d63e0")
    return t


def floor_headset():
    """Sound waves in the floor: purple concentric bands and a few pink pixels."""
    t = T("#14101f")
    for y in range(16):
        k = round(2.5 * math.sin(y / 2.5))
        t.p(8 + k, y, "#2a1f4a"); t.p(4 + k, y, "#1f1838")
    t.p(10, 4, "#ff5fb0"); t.p(3, 12, "#a06ae0")
    return t


PERIPH_WALLS = {"keyboard": wall_keyboard, "mouse": wall_mouse, "webcam": wall_webcam, "headset": wall_headset}
PERIPH_FLOORS = {"keyboard": floor_keyboard, "mouse": floor_mouse, "webcam": floor_webcam, "headset": floor_headset}


WALLS = {"notes": wall_notes, "camera": wall_camera, "store": wall_store, "mail": wall_mail, "messages": wall_messages, "maps": wall_maps,
         "clock": wall_clock, "music": wall_music, "settings": wall_settings, "photos": wall_photos, "weather": wall_weather, "phone": wall_phone,
         "corrupt": wall_corrupt}
WALL_VARIANTS = {"clock": 12}   # everything else has NV


# ------------------------------------------------------------------ floor tiles (16x16 -> 64)
def floor_notes():
    t = T("#f1e6bb")
    t.r(0, 7, 16, 1, "#9db4e8")
    t.r(0, 15, 16, 1, "#9db4e8")
    t.p(3, 3, "#e6d9a8"); t.p(11, 11, "#e6d9a8")
    return t


def floor_camera():
    t = T("#11131f")
    t.r(1, 1, 3, 1, "#232844"); t.r(1, 1, 1, 3, "#232844")
    t.r(12, 14, 3, 1, "#232844"); t.r(14, 12, 1, 3, "#232844")
    t.p(8, 8, "#1a1e30")
    return t


def floor_store():
    t = T("#2d4259")
    t.r(0, 0, 8, 8, "#27394f"); t.r(8, 8, 8, 8, "#27394f")
    t.r(0, 0, 16, 1, "#355070"); t.r(0, 0, 1, 16, "#355070")
    return t


def floor_mail():
    t = T("#c3cfea")
    t.r(0, 0, 16, 1, "#aab8dc"); t.r(0, 0, 1, 16, "#aab8dc")
    t.r(5, 5, 6, 5, "#d6dff4"); t.box(5, 5, 6, 5, "#b3c0e0")
    t.line(5, 5, 8, 8, "#b3c0e0"); t.line(10, 5, 8, 8, "#b3c0e0")
    return t


def floor_messages():
    t = T("#112720")
    t.r(0, 0, 16, 1, "#183428"); t.r(0, 0, 1, 16, "#183428")
    t.p(8, 8, "#1f4a38"); t.p(4, 12, "#18382c"); t.p(12, 4, "#18382c")
    return t


def floor_maps():
    t = T("#dac68f")
    for rad, c in ((7, "#c9b277"), (4.5, "#bfa66a")):                    # contour lines
        t.ring(8, 8, rad, c, 1.0)
    t.r(0, 0, 16, 1, "#cdb87e"); t.r(0, 0, 1, 16, "#cdb87e")             # the map grid
    t.p(8, 8, "#a98f55")
    return t


def floor_clock():
    t = T("#0d1531")
    t.r(0, 0, 16, 1, "#141f45"); t.r(0, 0, 1, 16, "#141f45")
    t.p(8, 8, "#233266"); t.p(8, 7, "#233266")
    return t


def floor_music():
    t = T("#1a1230")
    for y in (3, 5, 7, 9, 11):                                          # a staff
        t.r(0, y, 16, 1, "#2c2050")
    t.disc(5, 9, 1.6, "#3b2c6a"); t.r(6, 4, 1, 5, "#3b2c6a")
    return t


def floor_phone():
    t = T("#151927")
    t.r(0, 0, 16, 1, "#1d2335"); t.r(0, 0, 1, 16, "#1d2335")
    t.p(8, 8, "#262d44")
    return t


def floor_settings():
    t = T("#394055")
    t.r(0, 7, 16, 2, "#2c3245"); t.r(0, 7, 16, 1, "#262b3c")
    t.r(7, 4, 2, 8, "#454d66")
    return t


def floor_photos():
    t = T("#0d0b14")
    t.r(0, 0, 16, 2, "#171322"); t.r(0, 14, 16, 2, "#171322")           # a film strip's margins and holes
    for x in (2, 10):
        t.r(x, 0, 3, 2, "#2a2440"); t.r(x, 14, 3, 2, "#2a2440")
    t.p(8, 8, "#171322")
    return t


def floor_weather():
    t = T("#3c7fc4")
    t.r(0, 0, 16, 1, "#4a8fd4"); t.r(0, 0, 1, 16, "#4a8fd4")
    t.r(4, 5, 3, 1, "#5fa0e0"); t.r(10, 11, 3, 1, "#5fa0e0"); t.r(11, 3, 2, 1, "#5fa0e0")
    return t


FLOORS = {"notes": floor_notes, "camera": floor_camera, "store": floor_store, "mail": floor_mail, "messages": floor_messages, "maps": floor_maps,
          "clock": floor_clock, "music": floor_music, "settings": floor_settings, "photos": floor_photos, "weather": floor_weather, "phone": floor_phone}


# ------------------------------------------------------------------ keypad buttons
FONT = {   # 3x5 digits
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"], "2": ["111", "001", "111", "100", "111"],
    "3": ["111", "001", "111", "001", "111"], "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"], "8": ["111", "101", "111", "101", "111"],
    "9": ["111", "101", "111", "001", "111"],
}


def digit_button(d):
    t = T(None)
    t.r(1, 1, 30, 30, O)
    t.r(2, 2, 28, 28, "#e9eeff")                                        # light bevel (top and left)
    t.r(4, 4, 26, 26, "#5c6890")                                        # dark bevel (bottom and right)
    t.r(4, 4, 24, 24, "#b3bedd")                                        # the face
    t.r(4, 4, 24, 1, "#d3dcf2")
    glyph = FONT[d]
    for y, row in enumerate(glyph):
        for x, ch in enumerate(row):
            if ch == "1":
                t.r(10 + x * 4, 8 + y * 3 + y, 4, 4, "#1c2440")
    return t


# ------------------------------------------------------------------ spot ring and glyphs
def spot_frames():
    sheet = Image.new("RGBA", (256, 64), (0, 0, 0, 0))
    for f in range(4):
        t = T(None, 16)
        pulse = [0, 0.5, 1, 0.5][f]
        rad = 6.0 + pulse * 0.8
        t.ring(8, 8, rad + 0.9, "#ffffff", 1.1)
        for i in range(8):                                               # eight tick dashes round the ring
            a = i / 8.0 * math.tau + f * 0.1
            t.p(round(8 + math.sin(a) * (rad + 2.0)), round(8 - math.cos(a) * (rad + 2.0)), "#ffffff")
        t.ring(8, 8, rad - 1.6, hx("#ffffff")[:3] + (150,), 1.0)
        for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):             # corner brackets
            x = 8 + dx * 7
            y = 8 + dy * 7
            t.p(x, y, "#ffffff"); t.p(x - dx, y, "#ffffff"); t.p(x, y - dy, "#ffffff")
        sheet.paste(t.im.resize((64, 64), Image.NEAREST), (f * 64, 0))
    sheet.save(os.path.join(OUT, "smartphone_secret_room_spot.png"))


GLYPHS = {
    "snap": ["................", "................", "....######......", "...########.....", "..##########....", "..#..####..#....", "..#.#....#.#....", "..#.#.##.#.#....", "..#.#.##.#.#....", "..#.#....#.#....", "..#..####..#....", "..##########....", "................", "................", "................", "................"],
    "eye": ["................", "................", "................", "....########....", "..###......###..", ".##...####...##.", ".#...######...#.", ".#...##..##...#.", ".#...######...#.", ".##...####...##.", "..###......###..", "....########....", "................", "................", "................", "................"],
    "key": ["................", "................", "...####.........", "..#....#........", "..#....#........", "..#....#........", "...####.........", "....##..........", "....##..........", "....###.........", "....##..........", "....###.........", "................", "................", "................", "................"],
    "bubble": ["................", "................", "..############..", "..############..", "..############..", "..#..##..##..#..", "..############..", "..############..", "..############..", "....####........", "....###.........", "....##..........", "................", "................", "................", "................"],
    "pin": ["................", "......####......", ".....######.....", "....########....", "....###..###....", "....###..###....", "....########....", ".....######.....", ".....######.....", "......####......", "......####......", ".......##.......", ".......##.......", "................", "................", "................"],
    "clock": ["................", "....########....", "..##########....", ".####.##.####...", ".###..##..###...", ".###..##..###...", ".###..####.###..", ".###......###...", ".####....####...", "..##########....", "....########....", "................", "................", "................", "................", "................"],
    "note": ["................", "........####....", "........#..##...", "........#...##..", "........#.......", "........#.......", "........#.......", "....#####.......", "...######.......", "...######.......", "....####........", "................", "................", "................", "................", "................"],
    "phone": ["................", "...##########...", "...#........#...", "...#.######.#...", "...#.#....#.#...", "...#.######.#...", "...#........#...", "...#.#.#.#..#...", "...#........#...", "...#.#.#.#..#...", "...#........#...", "...#.#.#.#..#...", "...##########...", "................", "................", "................"],
    "flag": ["................", "....#...........", "....######......", "....#######.....", "....######......", "....#...........", "....#...........", "....#...........", "....#...........", "....#...........", "...###..........", "................", "................", "................", "................", "................"],
    "x": ["................", "..###......###..", "..###......###..", "...###....###...", "....###..###....", ".....######.....", "......####......", "......####......", ".....######.....", "....###..###....", "...###....###...", "..###......###..", "..###......###..", "................", "................", "................"],
    "bolt": ["................", ".......####.....", "......####......", ".....####.......", "....#####.......", "...########.....", ".......###......", "......###.......", ".....###........", "....###.........", "....##..........", "...#............", "................", "................", "................", "................"],
}


def glyph(name):
    t = T(None, 16)
    for y, row in enumerate(GLYPHS[name]):
        for x, ch in enumerate(row):
            if ch == "#":
                t.p(x, y, "#ffffff")
    t.save(os.path.join(OUT, "smartphone_secret_room_glyph_%s.png" % name), 4)


# ------------------------------------------------------------------ the clock decal (64x64 -> 256)
def clock_face():
    t = T(None, 64)
    t.disc(32, 32, 31.5, O)
    t.disc(32, 32, 30, "#2a3a78"); t.disc(32, 32, 28, "#eae7da"); t.ring(32, 32, 28, "#b8b4a0", 1.5)
    for i in range(60):
        a = i / 60.0 * math.tau
        big = i % 5 == 0
        r0, r1 = (22, 26) if big else (24.5, 26)
        for k in range(int(r1 - r0) + 1):
            rr = r0 + k
            t.p(round(32 + math.sin(a) * rr), round(32 - math.cos(a) * rr), O if big else "#8a8672")
    t.disc(32, 32, 3, O)
    return t


# ------------------------------------------------------------------ photos (64x48 -> 384x288)
def photo_base(sky_top, sky_bot, ground):
    t = T(sky_bot, 64, 48)
    for y in range(0, 28):
        k = y / 28.0
        a = hx(sky_top)
        b = hx(sky_bot)
        c = tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3)) + (255,)
        t.r(0, y, 64, 1, c)
    t.r(0, 28, 64, 20, ground)
    return t


def person(t, x, y, shirt, skin="#f0c8a0", hair="#4a3020", h=15):
    t.r(x + 2, y, 5, 5, skin); t.r(x + 2, y, 5, 2, hair)               # head
    t.r(x, y + 5, 9, h - 5, shirt)                                     # body
    t.r(x + 1, y + h, 3, 5, "#2b3350"); t.r(x + 5, y + h, 3, 5, "#2b3350")


def photo_innocent():
    """A family photo. The three people are far apart on purpose (they are the corrupted spots the player taps): the man at the left edge,
    the woman at the right edge, the child high up in a treehouse at the top centre."""
    t = photo_base("#6aa8f0", "#cfe8ff", "#6cb05a")
    t.disc(52, 6, 4, "#ffe46a"); t.disc(52, 6, 2.8, "#fff6b0")           # the sun
    t.r(25, 28, 14, 12, "#b5503e"); t.r(23, 26, 18, 4, "#7a3024")        # the house, centre
    t.r(30, 33, 4, 7, "#f2d8a0"); t.r(26, 32, 3, 3, "#cfe8ff")
    t.r(30, 15, 4, 13, "#6a4a2a"); t.r(24, 13, 16, 3, "#8a6a3a"); t.r(24, 15, 16, 1, "#5a3a1a")   # the treehouse platform on a trunk
    t.disc(32, 20, 7, "#3f8a3a")
    person(t, 28, 4, "#6fe3a0", hair="#3a2a1a", h=8)                     # the child (x 28-37, y 4-17)
    person(t, 4, 24, "#d9503e")                                         # the man (x 4-13, y 24-44)
    person(t, 51, 24, "#4f8cff", hair="#b86a2a", h=14)                   # the woman (x 51-60)
    t.r(0, 44, 64, 4, "#4f9a44")
    return t


def photo_truth():
    """The same frame, true: the man alone at his terminal (left), an empty chair and a blinking server (right), a ceiling camera watching (top centre)."""
    t = T("#0d1224", 64, 48)
    t.r(0, 0, 64, 6, "#1a2140")                                          # a server room ceiling
    for i in range(8):
        t.r(i * 9 + 1, 0, 1, 6, "#2a3560")
    t.r(24, 14, 16, 30, "#1c2342"); t.box(24, 14, 16, 30, O)             # a server rack in the middle
    for y in range(17, 42, 5):
        t.r(26, y, 12, 3, "#10152c"); t.p(36, y + 1, "#ff5a5a"); t.p(34, y + 1, "#5affb0")
    t.r(0, 44, 64, 4, "#161c36")
    # left: the man alone at a terminal, head in his hands
    t.r(2, 22, 16, 11, "#10152c"); t.box(2, 22, 16, 11, "#4a5890")       # monitor
    t.r(4, 24, 12, 7, "#0c2a1c"); t.r(5, 26, 8, 1, "#5affb0"); t.r(5, 28, 5, 1, "#5affb0")
    t.r(4, 34, 12, 2, "#2a3560")
    t.r(5, 38, 10, 7, "#d9503e"); t.r(7, 33, 7, 6, "#f0c8a0"); t.r(7, 33, 7, 2, "#4a3020"); t.r(5, 34, 3, 5, "#f0c8a0"); t.r(13, 34, 3, 5, "#f0c8a0")
    # right: the empty chair and the small blinking server
    t.r(48, 36, 6, 9, "#3a4570"); t.r(50, 30, 3, 7, "#3a4570"); t.r(48, 30, 1, 1, "#3a4570")
    t.r(55, 32, 7, 12, "#2a3560"); t.box(55, 32, 7, 12, O); t.p(57, 35, "#ff5a5a"); t.p(60, 35, "#5affb0"); t.p(57, 38, "#5affb0")
    # top centre: a security camera on the ceiling, looking down at the viewer
    t.r(31, 6, 2, 3, "#4a5890"); t.r(27, 8, 10, 6, "#2a3560"); t.box(27, 8, 10, 6, O)
    t.disc(32, 11, 2.2, "#0a0e24"); t.disc(32, 11, 1.4, "#ff5a5a"); t.p(31, 10, "#ffffff")
    return t


PHOTO_REGIONS = [(2, 20, 14, 26), (48, 20, 14, 26), (26, 3, 12, 12)]   # (x, y, w, h) of the man (left), the woman (right) and the child (top centre) in the photos


def snap_empty():
    t = photo_base("#0d1224", "#18224a", "#161c36")
    t.r(0, 0, 64, 6, "#1a2140")
    t.r(18, 22, 28, 14, "#10152c"); t.box(18, 22, 28, 14, "#4a5890")
    t.r(20, 24, 24, 10, "#0c2a1c"); t.r(22, 27, 12, 1, "#5affb0"); t.r(22, 29, 8, 1, "#5affb0")
    t.r(26, 36, 12, 2, "#2a3560")
    t.r(27, 40, 10, 6, "#3a4570")                                        # an empty chair
    return t


def snap_figure():
    t = snap_empty()
    t.r(27, 30, 10, 14, "#05070f")                                       # a dark figure at the desk
    t.disc(32, 28, 4, "#05070f")
    t.r(22, 33, 4, 8, "#05070f"); t.r(38, 33, 4, 8, "#05070f")
    return t


def snap_facing():
    t = snap_figure()
    t.r(24, 16, 16, 18, "#05070f")                                       # the figure has turned
    t.r(27, 21, 4, 2, "#ffffff"); t.r(34, 21, 4, 2, "#ffffff")          # eyes
    t.p(29, 21, "#ff3030"); t.p(36, 21, "#ff3030")
    t.r(28, 27, 8, 1, "#3a3a4a")
    return t


# ------------------------------------------------------------------ THUNDER STRIKE hazard (20 frames of 64x64, like strike.png)
def thunder_sheet():
    sheet = Image.new("RGBA", (1280, 64), (0, 0, 0, 0))
    rnd = random.Random(7)
    for f in range(20):
        t = T(None, 32)
        if f < 12:   # a gathering charge: a pale yellow ring that closes in, with crackling arcs and a spark in the middle
            k = f / 11.0
            rad = 14.0 - k * 6.0
            t.disc(16, 16, 14, hx("#222a55")[:3] + (110,))
            t.ring(16, 16, rad + 1, "#ffe86a", 1.2)
            t.ring(16, 16, 14, hx("#7aa8ff")[:3] + (180,), 1.0)
            for i in range(6):
                a = i / 6.0 * math.tau + k * 1.5
                r0, r1 = 14, 14 - 2 - k * 4
                t.line(round(16 + math.sin(a) * r0), round(16 - math.cos(a) * r0), round(16 + math.sin(a) * r1), round(16 - math.cos(a) * r1), "#ffe86a")
            t.disc(16, 16, 0.6 + k * 1.6, "#ffffff")
        elif f < 16:   # the strike: a flash that fills the ring, then fades to yellow
            k = (f - 12) / 3.0
            t.disc(16, 16, 15, "#fffbe0" if k < 0.5 else "#ffe9a0")
            t.ring(16, 16, 15, "#7aa8ff", 1.3)
            t.disc(16, 16, 9 - k * 3, "#ffffff")
            for i in range(8):
                a = i / 8.0 * math.tau + 0.3
                t.line(16, 16, round(16 + math.sin(a) * 15), round(16 - math.cos(a) * 15), "#ffffff" if k < 0.5 else "#ffe86a")
        else:   # a scorch mark with blue-white cracks that cool
            k = (f - 16) / 3.0
            t.disc(16, 16, 13, hx("#0c0e1c")[:3] + (230,))
            t.ring(16, 16, 13, "#3a3f66", 1.2)
            rnd2 = random.Random(3)
            for i in range(7):
                a = rnd2.random() * math.tau
                ln = 6 + rnd2.random() * 6
                x0, y0 = 16, 16
                for s in range(int(ln)):
                    x0 += math.sin(a + rnd2.uniform(-0.5, 0.5)); y0 -= math.cos(a + rnd2.uniform(-0.5, 0.5))
                    t.p(round(x0), round(y0), "#bfe0ff" if k < 1.5 else "#6a8ad0")
            t.disc(16, 16, 1.6 - k * 0.3, "#ffe86a" if k < 2 else "#8a6a30")
        sheet.paste(t.im.resize((64, 64), Image.NEAREST), (f * 64, 0))
    os.makedirs(HAZ, exist_ok=True)
    sheet.save(os.path.join(HAZ, "thunder.png"))


# ------------------------------------------------------------------ run
def main():
    for k, fn in PERIPH_WALLS.items():
        secret("gaming_laptop_secret_room_%s_wall" % k, strip(fn, 16 if k == "keyboard" else NV), 4)
    for k, fn in PERIPH_FLOORS.items():
        secret("gaming_laptop_secret_room_%s_floor" % k, fn(), 4)
    secret("smartphone_secret_room_floor_corrupt", floor_corrupt(), 4)
    for k, fn in WALLS.items():
        secret("smartphone_secret_room_wall_" + k, strip(fn, WALL_VARIANTS.get(k, NV)), 4)
    for k, fn in FLOORS.items():
        secret("smartphone_secret_room_floor_" + k, fn(), 4)
    for d in "0123456789":
        secret("smartphone_secret_room_digit_" + d, digit_button(d), 4)
    spot_frames()
    for g in GLYPHS:
        glyph(g)
    secret("smartphone_secret_room_clock_face", clock_face(), 4)
    secret("smartphone_secret_room_photo_innocent", photo_innocent(), 6)
    secret("smartphone_secret_room_photo_truth", photo_truth(), 6)
    secret("smartphone_secret_room_snap_1", snap_empty(), 6)
    secret("smartphone_secret_room_snap_2", snap_figure(), 6)
    secret("smartphone_secret_room_snap_3", snap_facing(), 6)
    thunder_sheet()
    print("done")


if __name__ == "__main__":
    main()
