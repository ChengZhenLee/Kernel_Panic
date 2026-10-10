#!/usr/bin/env python3
"""Kernel Panic: draws the white, hard-edged pixel sprites that replace the per-frame circles / rings / arcs on enemies
(status rings, modifier ring + studs, slow ring, elite aura). Each is a 64x64 image centred on (31.5, 31.5) with its outer edge at
the image border; the game scales one textured quad to the wanted radius and tints it (modulate), so every effect is one draw call.
usage: python tools/gen_enemy_fx.py      (writes art/fx/enemy_*.png; run from anywhere. pure Python, no dependencies)"""
import math
import os
import struct
import zlib


class Image:
    NEAREST = 0

    def __init__(self, size):
        self.w, self.h = size
        self.px = [(0, 0, 0, 0)] * (self.w * self.h)

    @staticmethod
    def new(mode, size, col):
        im = Image(size)
        im.px = [col] * (size[0] * size[1])
        return im

    def putpixel(self, xy, c):
        self.px[xy[1] * self.w + xy[0]] = c

    def resize(self, size, _m=0):
        out = Image(size)
        for y in range(size[1]):
            for x in range(size[0]):
                out.px[y * size[0] + x] = self.px[(y * self.h // size[1]) * self.w + x * self.w // size[0]]
        return out

    def alpha_composite(self, tile, dest):
        for y in range(tile.h):
            for x in range(tile.w):
                r, g, b, a = tile.px[y * tile.w + x]
                if a:
                    k = a / 255.0
                    o = self.px[(y + dest[1]) * self.w + x + dest[0]]
                    self.px[(y + dest[1]) * self.w + x + dest[0]] = (round(r * k + o[0] * (1 - k)), round(g * k + o[1] * (1 - k)), round(b * k + o[2] * (1 - k)), 255)

    def save(self, path):
        raw = b''.join(b'\x00' + b''.join(bytes(self.px[y * self.w + x]) for x in range(self.w)) for y in range(self.h))
        def chunk(t, d):
            c = struct.pack('>I', len(d)) + t + d
            return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
        with open(path, 'wb') as f:
            f.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', self.w, self.h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))

ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "fx")
N = 64
C = (N - 1) / 2.0
W = (255, 255, 255, 255)


def new():
    return Image((N, N))


def polar(x, y):
    dx, dy = x + 0.0 - C, y + 0.0 - C
    return math.hypot(dx, dy), math.atan2(dy, dx)


def ring_img(thick, keep=lambda a, d: True):
    im = new()
    for y in range(N):
        for x in range(N):
            d, a = polar(x, y)
            if 31.6 - thick < d <= 31.6 and keep(a, d):
                im.putpixel((x, y), W)
    return im


def blob(im, cx, cy, rad):
    for y in range(N):
        for x in range(N):
            if (x - cx) ** 2 + (y - cy) ** 2 <= rad * rad:
                im.putpixel((x, y), W)


def slow():   # thin dotted ring (2 on, 2 off)
    return ring_img(3, lambda a, d: int((a + math.pi) / (2 * math.pi) * 64) % 2 == 0)


def ice():   # solid ring with eight frost nubs on the outside edge
    im = ring_img(3)
    for k in range(8):
        a = k * math.tau / 8 + math.tau / 16
        for r in range(21, 29):
            w = 0.4 + (r - 21) * 0.3
            for s in (-1, 0, 1):
                x = C + math.cos(a) * r + math.sin(a) * s * w * 0.6
                y = C + math.sin(a) * r - math.cos(a) * s * w * 0.6
                im.putpixel((min(N - 1, max(0, round(x))), min(N - 1, max(0, round(y)))), W)
    return im


def stun():   # dashed ring: eight arcs with gaps
    return ring_img(5, lambda a, d: int((a + math.pi) / (2 * math.pi) * 16) % 2 == 0)


def affix():   # solid ring with a square stud at each quarter (the game turns the whole sprite, so the studs orbit)
    im = ring_img(4)
    for k in range(4):
        a = k * math.tau / 4
        blob(im, C + math.cos(a) * 26.0, C + math.sin(a) * 26.0, 5.2)
    return im


def glow():   # stepped soft disc: three flat alpha bands, ordered-dithered at each border
    im = new()
    bands = [(31.6, 70), (24.0, 130), (15.0, 210)]
    for y in range(N):
        for x in range(N):
            d, _ = polar(x, y)
            al = 0
            for r, a in bands:
                if d <= r - (1.5 if (x + y) & 1 else 0.0):
                    al = a
            if al:
                im.putpixel((x, y), (255, 255, 255, al))
    return im


def spikes():   # ten triangles, tips at the border (the game turns them)
    im = new()
    for y in range(N):
        for x in range(N):
            d, a = polar(x, y)
            if d < 22.5 or d > 31.6:
                continue
            u = (31.6 - d) / (31.6 - 22.5)   # 1 at the base, 0 at the tip
            seg = math.tau / 10
            off = abs(((a % seg) - seg / 2.0)) / (seg / 2.0)   # 0 at the middle of a spike's base
            # spike centred on a multiple of seg: halfwidth shrinks to the tip
            c = ((a + seg / 2.0) % seg) - seg / 2.0
            if abs(c) <= (seg * 0.46) * u:
                im.putpixel((x, y), W)
    return im


def armor():   # six arcs, a little over half a segment each
    return ring_img(5, lambda a, d: ((a + math.pi) % (math.tau / 6)) < math.tau / 6 * 0.6)


def flame():   # 8x8 teardrop for a burn ember
    im = Image((8, 8))
    rows = ["...##...", "..####..", "..####..", ".######.", ".######.", ".######.", "..####..", "...##..."]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                im.putpixel((x, y), W)
    return im


SPRITES = {"enemy_slow": slow, "enemy_ice": ice, "enemy_stun": stun, "enemy_affix": affix, "enemy_glow": glow,
           "enemy_spikes": spikes, "enemy_armor": armor, "enemy_ring": lambda: ring_img(5), "enemy_ember": flame}


def main():
    os.makedirs(ART, exist_ok=True)
    made = []
    for name, fn in SPRITES.items():
        im = fn()
        im.save(os.path.join(ART, name + ".png"))
        made.append((name, im))
    sheet = Image.new("RGBA", (len(made) * 140, 140), (20, 20, 40, 255))
    for i, (name, im) in enumerate(made):
        tile = im.resize((128, 128), Image.NEAREST)
        sheet.alpha_composite(tile, (i * 140 + 6, 6))
    sheet.save(os.path.join(ART, "..", "..", "enemy_fx_preview.png"))
    print("wrote", len(made), "sprites to", os.path.normpath(ART))


if __name__ == "__main__":
    main()


