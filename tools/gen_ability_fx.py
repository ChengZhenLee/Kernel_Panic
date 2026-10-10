import math, random, json, os, sys
from PIL import Image

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
WHITE = (255, 255, 255)


class C:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        s.p = s.im.load()

    def set(s, x, y, col, a=1.0):
        x, y = int(math.floor(x)), int(math.floor(y))
        if 0 <= x < s.w and 0 <= y < s.h and a > 0 and (a >= 1.0 or a > (BAYER[y & 3][x & 3] + 0.5) / 16.0):
            s.p[x, y] = col + (255,)

    def rect(s, x, y, w, h, col, a=1.0):
        for j in range(int(h)):
            for i in range(int(w)):
                s.set(x + i, y + j, col, a)

    def dot(s, x, y, sz, col, a=1.0):
        s.rect(round(x - sz / 2), round(y - sz / 2), sz, sz, col, a)

    def line(s, p0, p1, th, col, a=1.0):
        n = max(1, int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1]))))
        for i in range(n + 1):
            f = i / n
            s.dot(p0[0] + (p1[0] - p0[0]) * f, p0[1] + (p1[1] - p0[1]) * f, th, col, a)

    def ring(s, cx, cy, r, th, col, a=1.0):
        R = int(r + th + 1)
        for j in range(-R, R + 1):
            for i in range(-R, R + 1):
                d = math.hypot(i, j)
                if r - th < d <= r:
                    s.set(cx + i, cy + j, col, a)

    def disc(s, cx, cy, r, col, a=1.0, checker=True):
        R = int(r) + 1
        for j in range(-R, R + 1):
            for i in range(-R, R + 1):
                if i * i + j * j <= r * r and (not checker or (i + j) % 2 == 0):
                    s.set(cx + i, cy + j, col, a)

    def plus(s, x, y, arm, col, a=1.0):
        s.rect(x - arm, y, arm * 2 + 1, 1, col, a)
        s.rect(x, y - arm, 1, arm * 2 + 1, col, a)

    def bits(s, x, y, rows, pal, a=1.0, sc=1):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in pal:
                    s.rect(x + i * sc, y + j * sc, sc, sc, pal[ch], a)


def ease(k): return 1 - (1 - k) ** 3
def lerp(a, b, k): return a + (b - a) * k
def pol(cx, cy, ang, d): return (cx + math.cos(ang) * d, cy + math.sin(ang) * d)


def strip(frames, name):
    w, h = frames[0].w, frames[0].h
    im = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.paste(f.im, (i * w, 0))
    im.save(os.path.join(OUT, name))
    return (w, h, len(frames))


MANIFEST = {}


def reg(name, kind, size, ref_radius, desc, loop=False, fps=12):
    MANIFEST[name] = {"file": name + ".png", "type": kind, "frame_w": size[0], "frame_h": size[1], "frames": size[2],
                      "fps": fps, "loop": loop, "reference_radius_px": ref_radius, "notes": desc}


# Palettes (dark -> light)
GOLD = [(120, 70, 0), (200, 140, 10), (255, 209, 51), (255, 240, 150), WHITE]
BLUE = [(20, 40, 120), (50, 90, 220), (89, 140, 255), (160, 195, 255), WHITE]
TEAL = [(5, 80, 80), (20, 150, 140), (51, 230, 204), (150, 250, 235), WHITE]
GREEN = [(10, 90, 40), (30, 170, 70), (89, 255, 115), (180, 255, 190), WHITE]
AMBER = [(110, 55, 0), (200, 110, 10), (255, 191, 51), (255, 232, 140), WHITE]
VIOLET = [(60, 20, 110), (120, 50, 200), (179, 77, 255), (215, 170, 255), WHITE]
FIRE = [(110, 15, 5), (230, 60, 10), (255, 140, 30), (255, 215, 90), (255, 250, 200)]
ICE = [(40, 90, 150), (110, 190, 245), (190, 235, 255), (230, 250, 255), WHITE]
PALE = [(70, 100, 140), (140, 190, 235), (191, 230, 255), (225, 245, 255), WHITE]
STORM = [(30, 70, 140), (80, 160, 235), (153, 230, 255), (215, 245, 255), WHITE]
RAIL = [(120, 70, 0), (230, 160, 20), (255, 230, 102), (255, 247, 190), WHITE]

S = 192
CX = CY = 96
RR = 88  # reference radius for square impact sheets


# ---------------- PHASE ----------------
def phase():
    fr = []
    n = 10
    W, H = 192, 64
    a0, a1 = (22, 32), (170, 32)
    for i in range(n):
        k = i / (n - 1)
        c = C(W, H)
        a = 1 - k
        for g in range(6):
            f = g / 5
            kk = max(0, min(1, (k - f * 0.35) / (1 - f * 0.35)))
            if kk >= 1: continue
            x = lerp(a0[0], a1[0], f)
            h = round(13 - kk * 4)
            ga = (1 - kk) * 0.9
            col = VIOLET[3] if g % 2 else VIOLET[2]
            c.rect(x - h, 32 - h, h * 2, 2, col, ga); c.rect(x - h, 32 + h - 2, h * 2, 2, col, ga)
            c.rect(x - h, 32 - h, 2, h * 2, col, ga); c.rect(x + h - 2, 32 - h, 2, h * 2, col, ga)
            c.rect(x - h + 2, 32 - h + 2, h * 2 - 4, h * 2 - 4, VIOLET[0], ga * 0.5)
        for j in (-1, 0, 1):
            yy = 32 + j * 8
            xs = lerp(a0[0], a1[0], max(0, k * 1.6 - 0.6)) if k > 0.35 else a0[0]
            c.line((xs, yy), (a1[0], yy), 2, WHITE if j == 0 else VIOLET[2], a * 0.8)
        # speed dashes trailing
        random.seed(i * 7)
        for d in range(8):
            x = random.randint(30, 160); y = 32 + random.randint(-20, 20)
            c.rect(x, y, random.randint(6, 14), 1, VIOLET[3], a * 0.7)
        # landing chevron + sparks
        lx = a1[0]
        for s_ in (-1, 1):
            c.line((lx - 6, 32 + s_ * 13), (lx + 8, 32), 3, WHITE, a)
        c.ring(lx, 32, 6 + 22 * ease(k), 3, VIOLET[3], a)
        for d in range(8):
            ang = d / 8 * math.tau + 0.3
            r = 8 + 24 * ease(k) * (0.5 + (d % 3) / 3)
            p = pol(lx, 32, ang, r)
            c.dot(p[0], p[1], 3 if d % 2 else 2, VIOLET[3] if d % 2 else WHITE, a)
        fr.append(c)
    reg("phase_impact", "one_shot", strip(fr, "phase_impact.png"), 0,
        "Dash trail, left=start -> right=landing. Stretch/rotate the strip so x=22 is the origin and x=170 the destination (scale X by distance/148). Frames 0-9, play once.")


# ---------------- PURGE ----------------
def purge():
    fr = []; n = 12
    for i in range(n):
        k = i / (n - 1); o = ease(k); a = 1 - k
        c = C(S, S); r = RR * o
        c.disc(CX, CY, r, GOLD[1], 0.55 * (1 - k * 0.8))
        c.disc(CX, CY, r * 0.6, GOLD[3], 0.5 * (1 - k))
        if i < 3: c.disc(CX, CY, 30 - i * 8, WHITE, 1.0, False)
        c.ring(CX, CY, r, 5, WHITE, a); c.ring(CX, CY, r - 5, 3, GOLD[2], a)
        for j in range(8):
            ang = math.tau * j / 8 + k * 0.8
            c.line(pol(CX, CY, ang, r * 0.55), pol(CX, CY, ang, r), 3, GOLD[3] if j % 2 else GOLD[2], a)
        random.seed(11)
        for j in range(26):
            ang = random.random() * math.tau; sp = 0.4 + 0.6 * random.random()
            p = pol(CX, CY, ang, r * sp * 1.05)
            c.dot(p[0], p[1], 3 if j % 3 else 4, WHITE if j % 4 == 0 else GOLD[2], a)
        fr.append(c)
    reg("purge_impact", "one_shot", strip(fr, "purge_impact.png"), RR, "Gold dithered flood + white rim + 8 rays + sparks. Frames 0-2 are the white core flash. Scale by game radius / 88.")


# ---------------- LOCKDOWN ----------------
PADLOCK = ["..XXXX..", ".XX..XX.", ".X....X.", "XXXXXXXX", "XYYYYYYX", "XYYZZYYX", "XYYZZYYX", "XXXXXXXX"]
PADLOCK_PAL = None


def lockdown():
    fr = []; n = 12
    for i in range(n):
        k = i / (n - 1); a = 1 - k * k
        close = min(1, k * 2.2) ** 2
        h = round(RR * (1 - 0.7 * close)); w = 3
        c = C(S, S)
        x0, y0 = CX - h, CY - h
        c.rect(x0, y0, h * 2, w, BLUE[2], a); c.rect(x0, CY + h - w, h * 2, w, BLUE[2], a)
        c.rect(x0, y0, w, h * 2, BLUE[2], a); c.rect(CX + h - w, y0, w, h * 2, BLUE[2], a)
        c.rect(x0 + w, y0 + w, h * 2 - w * 2, 1, BLUE[0], a); c.rect(x0 + w, CY + h - w - 1, h * 2 - w * 2, 1, BLUE[0], a)
        bl = min(round(h * 0.35), 30)
        for sx in (-1, 1):
            for sy in (-1, 1):
                px_, py_ = CX + sx * h, CY + sy * h
                c.rect(px_ - (bl if sx > 0 else 0), py_ - (2 if sy > 0 else 0), bl, 3, WHITE, a)
                c.rect(px_ - (1 if sx > 0 else 0), py_ - (bl if sy > 0 else 0), 3, bl, WHITE, a)
        for t in range(8):
            f = (t + 0.5) / 8 * 2 - 1; tk = CX + h * f
            c.rect(tk, y0 + w, 2, 8, BLUE[3], a * 0.8); c.rect(tk, CY + h - w - 8, 2, 8, BLUE[3], a * 0.8)
            tk2 = CY + h * f
            c.rect(x0 + w, tk2, 8, 2, BLUE[3], a * 0.8); c.rect(CX + h - w - 8, tk2, 8, 2, BLUE[3], a * 0.8)
        if close > 0.9:
            c.disc(CX, CY, h * 1.25, BLUE[1], 0.5 * a)
            pal = {"X": BLUE[0], "Y": BLUE[3], "Z": BLUE[0]}
            for sx in (-1, 1):
                for sy in (-1, 1):
                    c.bits(CX + sx * (h - 20) - 8, CY + sy * (h - 20) - 8, PADLOCK, pal, 1.0 if k < 0.85 else a * 3, 2)
            c.ring(CX, CY, h * 1.1 + (k - .45) * 70, 3, WHITE, a * 0.8)
        fr.append(c)
    reg("lockdown_impact", "one_shot", strip(fr, "lockdown_impact.png"), RR,
        "Square cage slams shut (frames 0-5), padlocks stamp on the corners + shock ring (6-11). Scale by game radius / 88.")


# ---------------- DEEP SCAN ----------------
def deepscan():
    fr = []; n = 12
    for i in range(n):
        k = i / (n - 1); a = 1 - k * 0.7
        c = C(S, S); y = lerp(CY - RR, CY + RR, min(1, k * 1.15))
        for gx in range(13):
            x = CX - RR + gx * (RR * 2 / 12)
            c.rect(x, CY - RR, 1, max(0, y - (CY - RR)), TEAL[1], 0.35 * a)
        for r_ in range(22):
            ry = y - 8 - r_ * 4
            if ry < CY - RR: break
            c.rect(CX - RR, ry, RR * 2, 1, TEAL[2], a * 0.4 * (1 - r_ / 22))
        c.rect(CX - RR, y - 1, RR * 2, 3, WHITE, a); c.rect(CX - RR, y - 4, RR * 2, 3, TEAL[2], a * 0.8)
        c.dot(CX - RR, y, 7, WHITE); c.dot(CX + RR, y, 7, WHITE)
        random.seed(5)
        for m in range(7):
            mx, my = random.randint(CX - RR + 12, CX + RR - 12), random.randint(CY - RR + 12, CY + RR - 12)
            if my < y - 6 and k > 0.15:
                age = min(1, (y - my) / 30) * (1 - max(0, k - 0.7) * 2)
                if age > 0:
                    for sx in (-1, 1):
                        for sy in (-1, 1):
                            c.rect(mx + sx * 7 - (0 if sx < 0 else 3), my + sy * 7, 4, 1, WHITE, age)
                            c.rect(mx + sx * 7, my + sy * 7 - (0 if sy < 0 else 3), 1, 4, WHITE, age)
                    c.dot(mx, my, 2, TEAL[3], age)
        c.ring(CX, CY, RR, 2, TEAL[2], 0.5 * a)
        fr.append(c)
    reg("deepscan_impact", "one_shot", strip(fr, "deepscan_impact.png"), RR, "Scan line sweeps top->bottom (frames 0-10) leaving scanlines + grid; target reticles lock on behind it. Scale by game radius / 88.")


# ---------------- RESTORE ----------------
def restore():
    fr = []; n = 12
    for i in range(n):
        k = i / (n - 1); a = 1 - k
        c = C(S, S)
        c.ring(CX, CY, RR * 0.7 * ease(k), 3, GREEN[2], a)
        c.disc(CX, CY, RR * 0.7 * ease(k), GREEN[1], 0.35 * a)
        random.seed(3)
        for j in range(16):
            ang = math.tau * j / 16 + random.random() * 0.6; rr = RR * (0.25 + 0.7 * random.random())
            bx, by = pol(CX, CY, ang, rr); rise = k * (30 + 50 * random.random())
            x, y = round(bx), round(by - rise); arm = 3 if j % 3 else 5
            col = WHITE if j % 4 == 0 else GREEN[2]
            c.rect(x - arm, y - 1, arm * 2 + 1, 3, GREEN[0], a); c.rect(x - 1, y - arm, 3, arm * 2 + 1, GREEN[0], a)
            c.rect(x - arm + 1, y, arm * 2 - 1, 1, col, a); c.rect(x, y - arm + 1, 1, arm * 2 - 1, col, a)
            c.rect(x - 1, y - 1, 3, 3, col, a)
        for j in range(10):
            if (i + j) % 3 == 0:
                p = pol(CX, CY, j * 1.9, RR * 0.6 * ((j * 37 % 10) / 10 + .2))
                c.plus(round(p[0]), round(p[1] - k * 20), 2, WHITE, a)
        fr.append(c)
    reg("restore_impact", "one_shot", strip(fr, "restore_impact.png"), RR, "Pixel plus-signs drift up with a soft green ring + dithered wash. Frames 0-11, play once.")


# ---------------- OVERCLOCK ----------------
def overclock():
    fr = []; n = 10
    for i in range(n):
        k = i / (n - 1); a = 1 - k; r = RR * ease(k)
        c = C(S, S)
        if i < 2: c.disc(CX, CY, 22 - i * 8, WHITE, 1.0, False)
        for t in range(20):
            ang = math.tau * t / 20 + k * 2.5
            L = 12 if t % 2 == 0 else 6
            c.line(pol(CX, CY, ang, max(0, r - L)), pol(CX, CY, ang, r), 3, AMBER[2] if t % 2 == 0 else AMBER[1], a)
        c.ring(CX, CY, r, 2, WHITE, a * 0.8); c.ring(CX, CY, max(0, r - 14), 2, AMBER[1], a * 0.7)
        for t in range(8):
            ang = math.tau * t / 8 - k * 4
            c.line(pol(CX, CY, ang, r * 0.3), pol(CX, CY, ang, r * 0.3 + 26 * a), 2, WHITE if t % 2 else AMBER[3], a)
        fr.append(c)
    reg("overclock_impact", "one_shot", strip(fr, "overclock_impact.png"), RR, "Spinning gear-tooth ring with radial speed dashes; frames 0-1 core flash. Scale by game radius / 88.")


# ---------------- RAIL STRIKE ----------------
def railstrike():
    fr = []; n = 8
    W, H = 256, 64; ox, ex, y = 24, 232, 32
    for i in range(n):
        k = i / (n - 1); a = 1 - k
        c = C(W, H)
        sh = max(2, round(12 * (1 - k * 0.8)))
        c.rect(ox, y - sh, ex - ox, sh * 2, RAIL[1], 0.45 * a)
        c.rect(ox, y - sh // 2 - 1, ex - ox, sh + 2, RAIL[2], 0.9 * a)
        cw = max(2, round(5 * (1 - k * 0.6)))
        c.rect(ox, y - cw // 2, ex - ox, cw, WHITE, a)
        reach = min(1, k * 3)
        for t in range(10):
            f = (t + .5) / 10
            if f > reach: break
            x = lerp(ox, ex, f); hh = round(22 * (1 - k))
            c.rect(x, y - hh, 2, hh * 2, WHITE if t % 3 == 0 else RAIL[2], a * 0.9)
        c.ring(ox, y, 10 + 22 * ease(k), 3, WHITE, a)
        c.dot(ox, y, max(2, round(14 * (1 - k))), WHITE)
        random.seed(2)
        for j in range(12):
            ang = (random.random() - 0.5) * 2.6 + math.pi
            d = 24 * ease(k) * (0.4 + random.random()) + 4
            p = pol(ex, y, ang + math.pi, d) if j % 2 else pol(ex, y, ang, d)
            c.dot(p[0], p[1], 3, RAIL[2] if j % 3 else WHITE, a)
        c.ring(ex, y, 4 + 18 * ease(k), 3, WHITE, a)
        fr.append(c)
    reg("railstrike_impact", "one_shot", strip(fr, "railstrike_impact.png"), 0,
        "Beam from muzzle (x=24) to impact (x=232). For a longer beam, 3-slice: keep x<40 and x>216 fixed, stretch the middle. Rotate to aim. Frames 0-7, play once.")


# ---------------- PAUSE ----------------
def pause_():
    fr = []; n = 12
    for i in range(n):
        k = i / (n - 1); a = 1 - k
        c = C(S, S)
        for g in range(3):
            kk = max(0, min(1, (k - 0.12 * g) / (1 - 0.12 * g)))
            r = RR * (0.6 + 0.4 * g) * ease(kk) * 0.9 + 2
            c.ring(CX, CY, r, 4 - g, PALE[3] if g == 0 else PALE[2], (1 - kk) * (1 - 0.2 * g))
        tr = RR * 0.5
        for t in range(12):
            ang = math.tau * t / 12 - math.pi / 2; hot = t == int(k * 12) % 12
            L = 12 if t % 3 == 0 else 7
            c.line(pol(CX, CY, ang, tr - L), pol(CX, CY, ang, tr), 3 if t % 3 == 0 else 2, WHITE if hot else PALE[1], a)
        gy = round(CY - 20 - k * 8)
        c.rect(CX - 11, gy - 12, 8, 24, PALE[0], a); c.rect(CX + 3, gy - 12, 8, 24, PALE[0], a)
        c.rect(CX - 10, gy - 11, 6, 22, WHITE, a); c.rect(CX + 4, gy - 11, 6, 22, WHITE, a)
        for j in range(10):
            if (i + j) % 2 == 0:
                p = pol(CX, CY, j * 2.4 + 0.5, RR * (0.3 + (j * 13 % 7) / 10))
                c.plus(round(p[0]), round(p[1]), 2, PALE[3], a)
        fr.append(c)
    reg("pause_impact", "one_shot", strip(fr, "pause_impact.png"), RR, "Three pale rings, 12 clock ticks (second hand lights one per frame), PAUSE glyph. Frames 0-11, play once.")


# ---------------- WILDFIRE ----------------
def flame(c, bx, by, lx, ly, h, k_, a, flick):
    # tapered tongue: 3 nested lines (red base -> orange -> yellow core)
    for L, col, th in ((1.0, FIRE[1], 7), (0.72, FIRE[2], 5), (0.42, FIRE[3], 3)):
        c.line((bx, by), (bx + lx * h * L, by + ly * h * L), th, col, a)
    c.dot(bx + lx * h * 1.05, by + ly * h * 1.05, 2, FIRE[4], a * flick)


def wildfire():
    fr = []; n = 12
    for i in range(n):
        k = i / (n - 1); o = ease(k); a = 1 - k * k; r = RR * o
        c = C(S, S)
        c.disc(CX, CY, r, FIRE[1], 0.45 * a); c.disc(CX, CY, r * 0.6, FIRE[2], 0.4 * a)
        c.ring(CX, CY, r, 6, FIRE[1], a); c.ring(CX, CY, r - 3, 3, FIRE[3], a)
        random.seed(8)
        for t in range(40):
            ang = math.tau * t / 40; u = (math.cos(ang), math.sin(ang))
            fl = 0.6 + 0.4 * math.sin(i * 1.7 + t * 1.7)
            h = (14 + 26 * random.random()) * fl * (1 - k * 0.5)
            lx, ly = u[0] * 0.45, u[1] * 0.45 - 1; m = math.hypot(lx, ly); lx, ly = lx / m, ly / m
            flame(c, CX + u[0] * r, CY + u[1] * r, lx, ly, h, k, a, 1)
        for j in range(22):
            rr_ = r * random.random() * 0.95; ang = random.random() * math.tau
            p = pol(CX, CY, ang, rr_); rise = k * (25 + 50 * random.random())
            c.dot(p[0], p[1] - rise, 3 if j % 3 else 2, FIRE[3] if j % 2 else FIRE[2], a)
        fr.append(c)
    reg("wildfire_impact", "one_shot", strip(fr, "wildfire_impact.png"), RR, "Ring of flame tongues sweeps outward over a dithered orange wash, embers lift off. Frames 0-11, play once.")


# ---------------- DEEP FREEZE ----------------
def snowflake(c, cx, cy, arm, col, a):
    for t in range(3):
        ang = math.pi * t / 3 + math.pi / 6; d = (math.cos(ang), math.sin(ang))
        c.line((cx - d[0] * arm, cy - d[1] * arm), (cx + d[0] * arm, cy + d[1] * arm), 3, col, a)
        for sg in (-1, 1):
            tip = (cx + d[0] * arm * 0.65 * sg, cy + d[1] * arm * 0.65 * sg)
            for so in (-1, 1):
                v = (-d[0] * sg + (-d[1]) * so * 1.0, -d[1] * sg + d[0] * so * 1.0)
                m = math.hypot(*v)
                c.line(tip, (tip[0] + v[0] / m * 12, tip[1] + v[1] / m * 12), 2, WHITE, a * 0.9)


def deepfreeze():
    fr = []; n = 12
    for i in range(n):
        k = i / (n - 1); o = ease(k); a = 1 - k * k; r = RR * o
        c = C(S, S)
        c.disc(CX, CY, r, ICE[1], 0.5 * a)
        c.ring(CX, CY, r, 5, ICE[3], a); c.ring(CX, CY, r - 6, 3, ICE[1], a * 0.8)
        random.seed(4)
        for t in range(24):
            ang = math.tau * t / 24 + random.random() * 0.1; u = (math.cos(ang), math.sin(ang))
            ln = (8 + 20 * random.random()) * min(1, k * 5 + 0.3)
            c.line((CX + u[0] * r, CY + u[1] * r), (CX + u[0] * (r + ln), CY + u[1] * (r + ln)), 3, WHITE, a)
            c.line((CX + u[0] * (r - 4), CY + u[1] * (r - 4)), (CX + u[0] * (r - ln * 0.6), CY + u[1] * (r - ln * 0.6)), 2, ICE[2], a * 0.8)
        snowflake(c, CX, CY, r * 0.42 * min(1, o * 1.3), ICE[3], a)
        for j in range(16):
            if ((i // 1) + j) % 4 < 2:
                p = pol(CX, CY, random.random() * math.tau, r * random.random())
                c.plus(round(p[0]), round(p[1]), 3, WHITE, a)
        fr.append(c)
    reg("deepfreeze_impact", "one_shot", strip(fr, "deepfreeze_impact.png"), RR, "Frost rim with crystal spikes, six-armed snowflake stamped at centre, twinkling sparkles. Frames 0-11, play once.")


# ---------------- THUNDERSTORM ----------------
def bolt(c, p0, p1, th, cols, a, jit=7, seed=0):
    rnd = random.Random(seed)
    n = max(3, int(math.hypot(p1[0] - p0[0], p1[1] - p0[1]) / 12))
    pts = [p0]
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]; m = math.hypot(dx, dy) or 1; px_, py_ = -dy / m, dx / m
    for j in range(1, n):
        f = j / n; o = (rnd.random() - 0.5) * 2 * jit
        pts.append((p0[0] + dx * f + px_ * o, p0[1] + dy * f + py_ * o))
    pts.append(p1)
    for q in range(len(pts) - 1):
        c.line(pts[q], pts[q + 1], th + 2, cols[1], a * 0.6)
    for q in range(len(pts) - 1):
        c.line(pts[q], pts[q + 1], th, cols[0], a)


def thunder_cast():
    fr = []; n = 8
    for i in range(n):
        k = i / (n - 1); a = 1 - k; o = ease(k)
        c = C(S, S)
        if i < 2: c.disc(CX, CY, 24 - i * 8, WHITE, 1.0, False)
        c.ring(CX, CY, RR * o, 4, STORM[2], a); c.ring(CX, CY, RR * o * 0.88, 2, STORM[3], a * 0.5)
        for t in range(6):
            ang = math.tau * t / 6 + 0.4
            if (i + t) % 2 == 0 or i < 3:
                bolt(c, pol(CX, CY, ang, 8), pol(CX, CY, ang, RR * (0.55 + 0.4 * o)), 2, (WHITE, STORM[2]), a, 6, seed=i * 10 + t)
        random.seed(6)
        for j in range(18):
            p = pol(CX, CY, random.random() * math.tau, RR * o * (0.4 + random.random() * 0.6))
            c.dot(p[0], p[1], 3 if j % 3 else 2, WHITE if j % 2 else STORM[2], a)
        fr.append(c)
    reg("thunderstorm_impact", "one_shot", strip(fr, "thunderstorm_impact.png"), RR, "Cast moment: shock ring + six forked bolts crackling out of the caster. Frames 0-7, play once.")


def thunder_strike():
    fr = []; n = 6
    W, H = 64, 112; x, yb = 32, 96
    for i in range(n):
        k = i / (n - 1); a = 1 - k
        c = C(W, H)
        if i < 4:
            bolt(c, (x, 0), (x, yb), 3 if i < 2 else 2, (WHITE, STORM[2]), 1.0 if i < 3 else a * 1.5, 9, seed=100 + i // 2)
        c.ring(x, yb, 4 + 24 * ease(k), 3, WHITE if i < 3 else STORM[3], a)
        c.disc(x, yb, 22 * ease(k), STORM[1], 0.5 * a)
        if i < 2: c.disc(x, yb, 10, WHITE, 1.0, False)
        random.seed(9)
        for j in range(10):
            ang = random.random() * math.tau; d = 28 * ease(k) * (0.4 + random.random())
            p = pol(x, yb, ang, d)
            c.dot(p[0], p[1] - k * 6, 3 if j % 2 else 2, WHITE if j % 3 == 0 else STORM[2], a)
        fr.append(c)
    reg("thunderstorm_strike", "one_shot", strip(fr, "thunderstorm_strike.png"), 0,
        "Per-strike hit (every 0.35s while the storm runs): bolt falls from the top onto the target, flash ring + sparks. Origin = (32, 96), the point of impact. Frames 0-5, play once.")


# ---------------- AURAS (64x64, 8-frame loops) ----------------
def aura_overclock():
    fr = []; n = 8; c0 = 32
    for i in range(n):
        c = C(64, 64)
        k = i / n
        # 5-fold symmetric: one loop = 72 deg rotation
        for s_ in range(5):
            ang = -math.pi / 2 + (s_ + k) * math.tau / 5
            for tr in (3, 2, 1):
                p = pol(c0, c0, ang - tr * 0.2, 22)
                c.dot(p[0], p[1], 4 - tr + 1 if tr == 3 else 2, AMBER[3] if tr == 3 else AMBER[1], 1.0 if tr == 3 else 0.7)
            p = pol(c0, c0, ang, 22)
            c.dot(p[0], p[1], 4, AMBER[2]); c.dot(p[0], p[1], 2, WHITE)
        if i % 4 < 2:
            c.ring(c0, c0, 26 + (i % 4), 1, AMBER[1], 0.6)
        if i in (1, 5):
            for s_ in range(3):
                ang = s_ * 2.1 + i
                c.line(pol(c0, c0, ang, 12), pol(c0, c0, ang + 0.3, 19), 1, WHITE)
        fr.append(c)
    reg("overclock_aura", "aura_loop", strip(fr, "overclock_aura.png"), 22, "Orbiting amber sparks with trails + flickering ring, around the player. Loop frames 0-7 while OVERCLOCK is active (6 s). Centre = (32,32).", loop=True)


def aura_scan():
    fr = []; n = 8
    for i in range(n):
        c = C(64, 64); k = i / n
        h = round(26 + math.sin(k * math.tau) * 2)
        for sx in (-1, 1):
            for sy in (-1, 1):
                x, y = 32 + sx * h, 32 + sy * h
                c.rect(x - (8 if sx > 0 else 0), y, 9, 2, TEAL[2]); c.rect(x - (1 if sx > 0 else 0), y - (8 if sy > 0 else 0) + (0 if sy < 0 else 0), 2, 9, TEAL[2])
                c.rect(x - (8 if sx > 0 else 0), y, 3, 2, WHITE)
        y = round(32 + math.sin(k * math.tau) * (h - 2))
        c.rect(32 - h, y, h * 2, 1, TEAL[2], 0.7)
        c.rect(32 - h, y + 1, h * 2, 1, TEAL[1], 0.4)
        c.dot(32 - h, y, 3, WHITE); c.dot(32 + h, y, 3, WHITE)
        if i % 4 < 2:
            c.plus(32, 32, 2, TEAL[3], 0.8)
        fr.append(c)
    reg("deepscan_aura", "aura_loop", strip(fr, "deepscan_aura.png"), 26, "Four bracket corners + a scan line bobbing top/bottom around the player. Loop frames 0-7 while DEEP SCAN is active (8 s). Centre = (32,32).", loop=True)


def aura_storm():
    fr = []; n = 8
    for i in range(n):
        c = C(64, 64); rnd = random.Random(40 + i * 3)
        for s_ in range(3):
            ang = rnd.random() * math.tau; p = pol(32, 32, ang, 14); pts = [p]
            for j in range(3):
                nx = pol(p[0], p[1], ang + (rnd.random() - 0.5) * 1.6, 8)
                c.line(p, nx, 2, WHITE if j == 1 else STORM[2]); p = nx
        c.dot(32, 6 + round(math.sin(i / n * math.tau) * 2), 3, STORM[2]); c.dot(32, 6 + round(math.sin(i / n * math.tau) * 2), 1, WHITE)
        for j in range(2):
            q = pol(32, 32, rnd.random() * math.tau, 24)
            c.plus(round(q[0]), round(q[1]), 1, STORM[3], 0.9)
        fr.append(c)
    reg("thunderstorm_aura", "aura_loop", strip(fr, "thunderstorm_aura.png"), 24, "Zig-zag sparks crackle round the player + a charged spark floating overhead. Loop frames 0-7 while THUNDERSTORM is active (6 s). Centre = (32,32).", loop=True)


def aura_pause():
    fr = []; n = 8
    for i in range(n):
        c = C(64, 64); k = i / n
        for t in range(12):
            ang = math.tau * t / 12 - math.pi / 2; hot = t == (i * 12 // n) % 12
            L = 5 if t % 3 == 0 else 3
            c.line(pol(32, 32, ang, 25 - L), pol(32, 32, ang, 25), 2 if t % 3 == 0 else 1, WHITE if hot else PALE[1])
        c.ring(32, 32, 28, 1, PALE[2], 0.5)
        hand = pol(32, 32, -math.pi / 2 + k * math.tau, 18)
        c.line((32, 32), hand, 1, PALE[3], 0.9)
        c.dot(hand[0], hand[1], 3, WHITE)
        c.rect(28, 2, 3, 9, WHITE); c.rect(34, 2, 3, 9, WHITE)  # tiny pause glyph above head
        for j in range(3):
            q = pol(32, 32, j * 2.1 + 0.4, 21); c.plus(round(q[0]), round(q[1]), 1, PALE[3], 1.0 if (i + j) % 3 else 0.4)
        fr.append(c)
    reg("pause_aura", "aura_loop", strip(fr, "pause_aura.png"), 25, "Frozen clock face (12 ticks, second hand lights one tick per frame) with a small pause glyph overhead. Loop frames 0-7 while PAUSE is active (4 s). Centre = (32,32).", loop=True)


BRONZE = [(70, 40, 12), (140, 88, 30), (205, 140, 45), (255, 205, 80), (255, 240, 170)]


def gear(c, cx, cy, r, teeth, rot, col_body, col_edge, col_hi, hole=0.35, a=1.0):
    ti = r * 0.78
    for j in range(-int(r) - 3, int(r) + 4):
        for i in range(-int(r) - 3, int(r) + 4):
            d = math.hypot(i, j)
            if d > r + 1: continue
            ang = (math.atan2(j, i) - rot) % math.tau
            tooth = (ang / math.tau * teeth * 2) % 2 < 1
            lim = r if tooth else ti
            if d <= lim and d >= r * hole:
                col = col_edge if d > lim - 2 else (col_hi if (i - j) % 7 == 0 and d < ti else col_body)
                c.set(cx + i, cy + j, col, a)
    for s_ in range(4):  # spokes
        ang = rot + math.pi / 2 * s_ + math.pi / 4
        c.line(pol(cx, cy, ang, r * hole), pol(cx, cy, ang, ti - 1), 2, col_edge, a)
    c.ring(cx, cy, r * hole, 2, col_hi, a)


def pause_():
    fr = []; n = 12
    for i in range(n):
        k = i / (n - 1); a = 1.0 if k < 0.7 else max(0.0, 1 - (k - 0.7) / 0.3)
        c = C(S, S); o = ease(min(1, k * 2.5))
        R = RR * (0.35 + 0.65 * o)
        # outer shockwave ring (pale gold) rolls out
        c.ring(CX, CY, RR * 1.05 * ease(k), 3, BRONZE[4], (1 - k) )
        # clock face: dithered cream disc, bronze rim in layers
        c.disc(CX, CY, R, BRONZE[3], 0.28 * a)
        c.ring(CX, CY, R, 7, BRONZE[0], a); c.ring(CX, CY, R - 1, 5, BRONZE[2], a); c.ring(CX, CY, R - 2, 1, BRONZE[4], a)
        c.ring(CX, CY, R - 8, 2, BRONZE[1], a)
        # hour ticks: 12 chunky, 48 minute pins
        for t in range(60):
            ang = math.tau * t / 60 - math.pi / 2
            big = t % 5 == 0
            L = 11 if big else 4
            c.line(pol(CX, CY, ang, R - 10 - L), pol(CX, CY, ang, R - 10), 3 if big else 1, BRONZE[4] if big else BRONZE[3], a)
        # inner gear train: big gear + two meshing small ones, counter-rotating
        rot = k * math.pi * 0.9
        gear(c, CX, CY, R * 0.42, 16, rot, BRONZE[1], BRONZE[0], BRONZE[3], 0.3, a)
        gear(c, CX - round(R * 0.42 + R * 0.19), CY + round(R * 0.1), R * 0.2, 9, -rot * 1.8 + 0.3, BRONZE[2], BRONZE[0], BRONZE[4], 0.3, a)
        gear(c, CX + round(R * 0.4 + R * 0.17), CY - round(R * 0.2), R * 0.17, 8, -rot * 2.1, BRONZE[2], BRONZE[0], BRONZE[4], 0.3, a)
        # hands: minute hand spins quickly then stops at 12 (time stops), hour hand
        mh = -math.pi / 2 + (1 - ease(min(1, k * 1.4))) * math.tau * 1.5
        hh = -math.pi / 2 + (1 - ease(min(1, k * 1.4))) * math.tau * 0.25 + 0.5
        for L, th, ang, colr in ((R * 0.78, 4, mh, BRONZE[4]), (R * 0.5, 5, hh, BRONZE[3])):
            c.line(pol(CX, CY, ang, -8), pol(CX, CY, ang, L), th + 2, BRONZE[0], a)
            c.line(pol(CX, CY, ang, -6), pol(CX, CY, ang, L), th, colr, a)
        c.dot(CX, CY, 9, BRONZE[0], a); c.dot(CX, CY, 6, BRONZE[3], a); c.dot(CX, CY, 2, WHITE, a)
        # flashing sparks off the rim
        random.seed(21)
        for j in range(14):
            ang = random.random() * math.tau; d = R + 4 + 22 * ease(k) * random.random()
            p = pol(CX, CY, ang, d)
            c.dot(p[0], p[1], 3 if j % 2 else 2, BRONZE[4] if j % 3 else BRONZE[3], (1 - k))
        if i < 2: c.disc(CX, CY, 16, WHITE, 1.0, False)
        fr.append(c)
    reg("pause_impact", "one_shot", strip(fr, "pause_impact.png"), RR, "Giant bronze/gold clockwork face: rim, 60 ticks, three meshing gears, hands that spin then lock at 12. Frames 0-11, play once (fades from frame 8). Scale by game radius / 88.")


def aura_pause():
    fr = []; n = 8
    for i in range(n):
        c = C(64, 64); k = i / n
        c.ring(32, 32, 29, 3, BRONZE[0]); c.ring(32, 32, 28, 2, BRONZE[2]); c.ring(32, 32, 27, 1, BRONZE[4])
        for t in range(12):
            ang = math.tau * t / 12 - math.pi / 2
            L = 5 if t % 3 == 0 else 3
            c.line(pol(32, 32, ang, 24 - L), pol(32, 32, ang, 24), 2 if t % 3 == 0 else 1, BRONZE[4] if t % 3 == 0 else BRONZE[3])
        gear(c, 32, 32, 11, 10, k * math.tau / 10, BRONZE[1], BRONZE[0], BRONZE[3], 0.3)
        hand = pol(32, 32, -math.pi / 2 + k * math.tau, 21)
        c.line((32, 32), hand, 2, BRONZE[4]); c.dot(32, 32, 4, BRONZE[3]); c.dot(32, 32, 2, BRONZE[0])
        c.rect(28, 1, 3, 8, BRONZE[4]); c.rect(34, 1, 3, 8, BRONZE[4])
        fr.append(c)
    reg("pause_aura", "aura_loop", strip(fr, "pause_aura.png"), 29, "Small bronze clock with a turning gear and a second hand + pause glyph overhead. Loop frames 0-7 while PAUSE is active (4 s). Centre = (32,32).", loop=True)


BIGLOCK = ["...XXXXXX...", "..XXYYYYXX..", "..XY....YX..", "..XY....YX..", "..XY....YX..", "XXXXXXXXXXXX", "XYYYYYYYYYYX", "XYYYYZZYYYYX", "XYYYZZZZYYYX", "XYYYYZZYYYYX", "XYYYYZZYYYYX", "XXXXXXXXXXXX"]


def lockdown():
    fr = []; n = 12
    for i in range(n):
        k = i / (n - 1); a = 1.0 if k < 0.75 else max(0.0, 1 - (k - 0.75) / 0.25)
        c = C(S, S)
        close = min(1, k * 2.4) ** 2
        h = round(RR * (1 - 0.3 * close)); w = 4
        x0, y0 = CX - h, CY - h
        # wash + bars that slam in from the left/right/top/bottom to form a grille
        c.rect(x0, y0, h * 2, h * 2, BLUE[0], 0.25 * a * close)
        nb = 7
        for b in range(nb):
            f = (b + 0.5) / nb * 2 - 1; p = CX + h * f * 0.92
            ext = min(1, max(0, close * 1.4 - abs(f) * 0.3))
            c.rect(p - 1, y0 + w, 3, round((h * 2 - w * 2) * ext), BLUE[2], a)
            c.rect(p - 1, y0 + w, 1, round((h * 2 - w * 2) * ext), BLUE[3], a)
            q = CY + h * f * 0.92
            c.rect(x0 + w, q - 1, round((h * 2 - w * 2) * ext), 3, BLUE[1], a * 0.8)
        # frame
        c.rect(x0, y0, h * 2, w, BLUE[2], a); c.rect(x0, CY + h - w, h * 2, w, BLUE[2], a)
        c.rect(x0, y0, w, h * 2, BLUE[2], a); c.rect(CX + h - w, y0, w, h * 2, BLUE[2], a)
        c.rect(x0, y0, h * 2, 1, WHITE, a); c.rect(x0, y0, 1, h * 2, WHITE, a)
        bl = 26
        for sx in (-1, 1):
            for sy in (-1, 1):
                px_, py_ = CX + sx * h, CY + sy * h
                c.rect(px_ - (bl if sx > 0 else 0), py_ - (3 if sy > 0 else 0), bl, 4, WHITE, a)
                c.rect(px_ - (3 if sx > 0 else 0), py_ - (bl if sy > 0 else 0), 4, bl, WHITE, a)
        # big padlock clamps on in the second half
        if k > 0.35:
            drop = min(1, (k - 0.35) / 0.2); dy = round((1 - ease(drop)) * -30)
            pal = {"X": BLUE[0], "Y": BLUE[3], "Z": BLUE[0]}
            c.rect(CX - 28, CY - 32 + dy, 56, 66, BLUE[0], a)
            c.bits(CX - 24, CY - 28 + dy, BIGLOCK, pal, a, 4)
            if drop >= 1 and k < 0.6:
                c.ring(CX, CY, 20 + (k - 0.5) * 300, 3, WHITE, 1.0)
        if i < 2: c.disc(CX, CY, 26 - i * 8, WHITE, 1.0, False)
        fr.append(c)
    reg("lockdown_impact", "one_shot", strip(fr, "lockdown_impact.png"), RR,
        "Blue cage frame closes in (frames 0-4) while grille bars slam across, then a big padlock drops in the middle and clamps with a white shock ring (5-8), fading out (9-11). Scale by game radius / 88.")


# =============== PREMIUM TIER (evolution-class abilities): 256px frames, 16 frames, multi-stage, outlined ===============
P = 256; PC = 128; PR = 116


def outline(c, col, a=1.0):
    pts = []
    for y in range(c.h):
        for x in range(c.w):
            if c.p[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < c.w and 0 <= ny < c.h and c.p[nx, ny][3] and c.p[nx, ny][:3] != col:
                        pts.append((x, y)); break
    for x, y in pts: c.set(x, y, col, a)


def flame_col(c, x, y, w, h, ph, a=1.0, lean=0.0):
    # layered flame tongue: wavy tip, ramp red->orange->yellow->white by height
    for dx in range(-int(w / 2), int(w / 2) + 1):
        f = 1 - abs(dx) / (w / 2 + 0.01)
        ch = h * (f ** 0.7) * (0.82 + 0.18 * math.sin(ph + dx * 0.9))
        sway = math.sin(ph * 1.3 + dx * 0.2) * 2 + lean * ch * 0.5
        for j in range(int(ch)):
            fr_ = j / max(1, ch)
            inner = f * (1 - fr_ * 0.6)
            idx = 0 if fr_ > 0.8 and inner < 0.2 else int(min(4, max(0, (inner * 3.2) + (1 - fr_) * 0.9)))
            c.set(x + dx + sway * fr_, y - j, FIRE[min(4, idx)], a)


def wildfire():
    fr = []; n = 16
    for i in range(n):
        k = i / (n - 1); o = ease(min(1, k * 1.5)); a = 1.0 if k < 0.7 else max(0.0, 1 - (k - 0.7) / 0.3)
        c = C(P, P); r = PR * o
        c.disc(PC, PC, r, FIRE[0], 0.55 * a); c.disc(PC, PC, r * 0.72, FIRE[1], 0.5 * a); c.disc(PC, PC, r * 0.4, FIRE[2], 0.5 * a)
        if i < 3: c.disc(PC, PC, 44 - i * 12, FIRE[4], 1.0, False); c.disc(PC, PC, 56 - i * 14, FIRE[3], 0.9)
        rnd = random.Random(31)
        n_f = 36
        for t in range(n_f):
            ang = math.tau * t / n_f + rnd.random() * 0.05; u = (math.cos(ang), math.sin(ang))
            bx, by = PC + u[0] * r, PC + u[1] * r
            hh = (22 + 30 * rnd.random()) * (0.5 + 0.5 * min(1, k * 3)) * (1 - max(0, k - 0.6) * 1.4)
            flame_col(c, round(bx), round(by), 12 + rnd.random() * 6, hh, i * 1.4 + t * 2.1, a, u[0] * 0.5)
        # inner second flame ring (offset) for depth
        for t in range(18):
            ang = math.tau * (t + 0.5) / 18; u = (math.cos(ang), math.sin(ang))
            flame_col(c, round(PC + u[0] * r * 0.62), round(PC + u[1] * r * 0.62), 14, 18 * (1 - k * 0.6) * min(1, k * 4), i * 1.7 + t * 3, a * 0.9)
        c.ring(PC, PC, r, 4, FIRE[3], a); c.ring(PC, PC, r + 3, 2, FIRE[4], a * 0.9)
        for j in range(40):
            ang = rnd.random() * math.tau; rr_ = r * rnd.random(); p = pol(PC, PC, ang, rr_)
            rise = k * (30 + 90 * rnd.random())
            c.dot(p[0] + math.sin(rise * 0.2 + j) * 3, p[1] - rise, 3 if j % 3 else 2, FIRE[4] if j % 4 == 0 else FIRE[3 if j % 2 else 2], a)
        outline(c, FIRE[0], a)
        fr.append(c)
    reg("wildfire_impact", "one_shot", strip(fr, "wildfire_impact.png"), PR,
        "PREMIUM. 256x256, 16 frames. White-hot core flash (0-2), shockwave ring, two walls of shaded flame tongues (red->orange->yellow->white), embers and smoke; fades from frame 11. Scale by game radius / 116.")


def crystal(c, x, y, L, W, ang, a=1.0):
    ux, uy = math.cos(ang), math.sin(ang); vx, vy = -uy, ux
    for s_ in range(int(L) + 1):
        f = s_ / max(1, L); wd = W * (1 - f ** 1.6) * (0.5 + 0.5 * min(1, f * 6))
        for t in range(-int(wd), int(wd) + 1):
            col = ICE[4] if abs(t) <= 0 else (ICE[3] if t < 0 else ICE[1])
            if abs(t) >= int(wd): col = ICE[0]
            c.set(x + ux * s_ + vx * t, y + uy * s_ + vy * t, col, a)


def deepfreeze():
    fr = []; n = 16
    for i in range(n):
        k = i / (n - 1); a = 1.0
        c = C(P, P); rnd = random.Random(15)
        grow = ease(min(1, k * 1.7)); r = PR * grow
        shat = max(0, (k - 0.6) / 0.4)  # frames 10+: shatter
        fade = 1 - shat * shat
        if i < 3: c.disc(PC, PC, 40 - i * 12, WHITE, 1.0, False)
        c.disc(PC, PC, r, ICE[0], 0.4 * fade); c.disc(PC, PC, r * 0.8, ICE[1], 0.45 * fade); c.disc(PC, PC, r * 0.5, ICE[2], 0.45 * fade)
        # frost rim + facet segments
        c.ring(PC, PC, r, 6, ICE[2], fade); c.ring(PC, PC, r - 1, 3, ICE[4], fade); c.ring(PC, PC, r - 7, 2, ICE[1], fade * 0.8)
        # big crystals thrusting out of the rim (outward) and in
        for t in range(14):
            ang = math.tau * t / 14 + 0.12
            L = (16 + 26 * rnd.random()) * min(1, k * 4 + 0.2)
            ex, ey = pol(PC, PC, ang, r - 2)
            ox_ = shat * (30 + 50 * rnd.random())
            crystal(c, ex + math.cos(ang) * ox_, ey + math.sin(ang) * ox_, L, 5, ang, fade)
            if t % 2 == 0:
                crystal(c, ex, ey, L * 0.6, 3, ang + math.pi, fade * 0.9)
        for t in range(28):
            ang = math.tau * t / 28 + 0.05; ex, ey = pol(PC, PC, ang, r)
            crystal(c, ex, ey, 6 + 8 * rnd.random(), 2, ang, fade)
        # snowflake, rotating slowly, spawns shards when it breaks
        arm = r * 0.5 * min(1, grow * 1.2)
        snowflake(c, PC, PC, arm, ICE[4], fade)
        snowflake(c, PC, PC, arm * 0.45, ICE[3], fade)
        if shat > 0:
            for j in range(26):
                ang = rnd.random() * math.tau; d = 20 + shat * (60 + 70 * rnd.random())
                p = pol(PC, PC, ang, d)
                crystal(c, p[0], p[1], 6 + 8 * rnd.random(), 3, ang + shat * 3, fade)
        for j in range(24):
            if (i + j) % 4 < 2:
                p = pol(PC, PC, rnd.random() * math.tau, r * rnd.random())
                c.plus(round(p[0]), round(p[1]), 4 if j % 3 == 0 else 2, WHITE, fade)
        outline(c, ICE[0], fade)
        fr.append(c)
    reg("deepfreeze_impact", "one_shot", strip(fr, "deepfreeze_impact.png"), PR,
        "PREMIUM. 256x256, 16 frames. Frost bursts out (0-4) with faceted crystal spikes and a layered snowflake, holds (5-9), then SHATTERS: crystals fly out and fade (10-15). Frame 10 is the shatter moment: sync the bonus-damage pop to it. Scale by game radius / 116.")


def storm_cloud(c, cx, cy, rad, t, a):
    c.disc(cx, cy, rad, (40, 45, 80), 0.85 * a)
    c.disc(cx, cy, rad * 0.75, (70, 80, 130), 0.8 * a)
    for q in range(7):
        ang = t * 0.5 + q * 0.9
        p = pol(cx, cy, ang, rad * 0.55); c.disc(p[0], p[1], rad * 0.28, (95, 105, 160), 0.7 * a)
    c.ring(cx, cy, rad, 2, (150, 160, 210), 0.6 * a)


def thunder_cast():
    fr = []; n = 16
    for i in range(n):
        k = i / (n - 1); a = 1.0 if k < 0.7 else max(0, 1 - (k - 0.7) / 0.3)
        c = C(P, P); o = ease(min(1, k * 2))
        rnd = random.Random(i // 2 + 50)
        # ground charge: dithered disc + double ring, arcs crawling on the rim
        c.disc(PC, PC, PR * o, STORM[0], 0.45 * a); c.disc(PC, PC, PR * o * 0.6, STORM[1], 0.35 * a)
        c.ring(PC, PC, PR * o, 4, STORM[3], a); c.ring(PC, PC, PR * o - 5, 2, STORM[2], a * 0.8)
        for t in range(12):
            ang = math.tau * t / 12 + i * 0.5
            p0 = pol(PC, PC, ang, PR * o); p1 = pol(PC, PC, ang + 0.3, PR * o)
            bolt(c, p0, p1, 2, (WHITE, STORM[2]), a, 4, seed=i * 13 + t)
        # cloud forms overhead and discharges
        storm_cloud(c, PC, 34, 30 * min(1, k * 4 + 0.3), k * 6, a)
        if i % 2 == 0 or i < 4:
            for t in range(4):
                ang = math.radians(60 + t * 70)
                tgt = pol(PC, PC, ang, PR * o * (0.5 + 0.4 * rnd.random()))
                bolt(c, (PC + (t - 1.5) * 12, 50), tgt, 3, (WHITE, STORM[2]), a, 9, seed=i * 5 + t)
        for t in range(6):
            ang = math.tau * t / 6 + 0.4
            bolt(c, pol(PC, PC, ang, 10), pol(PC, PC, ang, PR * o * 0.9), 2, (WHITE, STORM[2]), a, 7, seed=i * 7 + t)
        if i < 3: c.disc(PC, PC, 36 - i * 10, WHITE, 1.0, False)
        for j in range(30):
            p = pol(PC, PC, rnd.random() * math.tau, PR * o * rnd.random())
            c.dot(p[0], p[1], 3 if j % 3 else 2, WHITE if j % 2 else STORM[2], a)
        outline(c, STORM[0], a)
        fr.append(c)
    reg("thunderstorm_impact", "one_shot", strip(fr, "thunderstorm_impact.png"), PR,
        "PREMIUM. 256x256, 16 frames. Charged ground ring with crawling arcs, a storm cloud forms overhead (cloud centre is y=34, above the caster) and discharges forked bolts onto the zone, plus bolts radiating from the caster. Scale by game radius / 116.")


def thunder_strike():
    fr = []; n = 10
    W, H = 96, 176; x, yb = 48, 150
    for i in range(n):
        k = i / (n - 1); a = 1 - max(0, k - 0.5) * 2
        c = C(W, H); rnd = random.Random(70)
        if i < 6:
            main = (x, 0); bolt(c, main, (x, yb), 4 if i < 3 else 3, (WHITE, STORM[2]), 1.0 if i < 4 else a * 1.6, 11, seed=100 + i // 2)
            for b_ in range(3):
                sy = 30 + b_ * 35; sx = x + (b_ - 1) * 4
                bolt(c, (sx, sy), (sx + (-1) ** b_ * (20 + 8 * b_), sy + 38), 2, (WHITE, STORM[2]), 1.0 if i < 4 else a, 6, seed=200 + b_ + i // 2)
        c.disc(x, yb, 28 * ease(k), STORM[0], 0.5 * a)   # scorch
        c.disc(x, yb, 20 * ease(k), STORM[1], 0.5 * a)
        c.ring(x, yb, 4 + 38 * ease(k), 4, WHITE if i < 5 else STORM[3], a)
        c.ring(x, yb, 2 + 24 * ease(k), 2, STORM[2], a)
        if i < 3: c.disc(x, yb, 18 - i * 4, WHITE, 1.0, False)
        for j in range(16):
            ang = rnd.random() * math.tau; d = 34 * ease(k) * (0.3 + rnd.random())
            p = pol(x, yb, ang, d)
            c.dot(p[0], p[1] - k * 10, 3 if j % 2 else 2, WHITE if j % 3 == 0 else STORM[2], a)
        outline(c, STORM[0], a)
        fr.append(c)
    reg("thunderstorm_strike", "one_shot", strip(fr, "thunderstorm_strike.png"), 0,
        "PREMIUM. 96x176, 10 frames. Per-strike hit: forked bolt with side branches falls from the top (0-5), scorch + double shock ring + sparks (3-9). Origin = (48, 150), the point of impact. Play once.")


def aura_storm():
    fr = []; n = 8
    for i in range(n):
        c = C(80, 80); rnd = random.Random(90 + i * 3); k = i / n
        storm_cloud(c, 40, 10, 12, k * math.tau, 1.0)
        for s_ in range(3):
            ang = rnd.random() * math.tau; p = pol(40, 46, ang, 16)
            for j in range(3):
                nx = pol(p[0], p[1], ang + (rnd.random() - 0.5) * 1.6, 9)
                c.line(p, nx, 2, WHITE if j == 1 else STORM[2]); p = nx
        if i % 2 == 0:
            bolt(c, (40 + rnd.randint(-5, 5), 20), (40 + rnd.randint(-10, 10), 34), 2, (WHITE, STORM[2]), 1.0, 3, seed=i)
        for j in range(3):
            q = pol(40, 46, rnd.random() * math.tau, 30); c.plus(round(q[0]), round(q[1]), 1, STORM[3])
        outline(c, STORM[0])
        fr.append(c)
    reg("thunderstorm_aura", "aura_loop", strip(fr, "thunderstorm_aura.png"), 30,
        "PREMIUM. 80x80, 8-frame loop. A small swirling storm cloud floats above the player (cloud centre y=10) dropping little bolts, with arcs crackling round the body. Loop frames 0-7 while THUNDERSTORM is active (6 s). Player centre = (40,46).", loop=True)


def railstrike():
    fr = []; n = 14
    W, H = 384, 112; ox, ex, y = 40, 344, 56
    for i in range(n):
        k = i / (n - 1); c = C(W, H); rnd = random.Random(60)
        if i < 3:   # charge: rings converge on the muzzle, thin pre-beam
            q = 1 - i / 2
            c.ring(ox, y, 8 + 34 * q, 3, RAIL[2], 1.0); c.ring(ox, y, 4 + 20 * q, 2, WHITE, 1.0)
            c.dot(ox, y, 6 + (2 - i) * 2, WHITE)
            c.rect(ox, y - 1, (ex - ox) * (i / 2) ** 2, 2, RAIL[3], 0.8)
            for j in range(10):
                ang = j / 10 * math.tau + i; p = pol(ox, y, ang, 40 * q + 10); c.dot(p[0], p[1], 2, RAIL[3])
        else:
            kk = (i - 3) / (n - 4); a = 1 - kk
            sh = max(3, round(18 * (1 - kk * 0.85)))
            c.rect(ox, y - sh - 6, ex - ox, (sh + 6) * 2, RAIL[0], 0.3 * a)
            c.rect(ox, y - sh, ex - ox, sh * 2, RAIL[1], 0.8 * a)
            c.rect(ox, y - sh // 2, ex - ox, max(2, sh), RAIL[2], a)
            cw = max(2, round(8 * (1 - kk * 0.7)))
            c.rect(ox, y - cw // 2, ex - ox, cw, WHITE, a)
            # helical shock ripple around the beam
            for xx in range(ox, ex, 2):
                ph = (xx - ox) * 0.09 - kk * 14
                yy = y + math.sin(ph) * (sh + 5) * (1 - kk)
                c.dot(xx, yy, 2, RAIL[3], a); c.dot(xx, 2 * y - yy, 2, RAIL[2], a * 0.7)
            for t in range(14):
                f = (t + .5) / 14
                if f > min(1, kk * 4 + 0.15): break
                x = ox + (ex - ox) * f; hh = round(34 * (1 - kk) * (0.6 + 0.4 * (t % 2)))
                c.rect(x, y - hh, 2, hh * 2, WHITE if t % 3 == 0 else RAIL[2], a * 0.9)
            for q_ in range(3):   # shockwave rings sliding down the beam
                x = ox + (ex - ox) * min(1, kk * 1.3 + q_ * 0.15 - 0.15)
                if kk * 1.3 + q_ * 0.15 - 0.15 > 0:
                    c.ring(x, y, 12 + q_ * 3, 2, WHITE, a * 0.7)
            c.ring(ox, y, 12 + 40 * ease(kk), 4, WHITE, a); c.ring(ox, y, 6 + 24 * ease(kk), 2, RAIL[2], a)
            c.dot(ox, y, max(2, round(22 * (1 - kk))), WHITE)
            # impact: bloom + debris
            c.disc(ex, y, 30 * ease(kk), RAIL[1], 0.5 * a)
            c.ring(ex, y, 6 + 40 * ease(kk), 4, WHITE, a); c.ring(ex, y, 3 + 26 * ease(kk), 2, RAIL[3], a)
            for j in range(22):
                ang = (rnd.random() - 0.5) * 3.0; d = 50 * ease(kk) * (0.3 + rnd.random())
                p = pol(ex, y, ang if j % 2 else ang + math.pi, d)
                c.dot(p[0], p[1] + kk * 8 * (j % 3), 4 if j % 4 == 0 else 3, WHITE if j % 3 == 0 else RAIL[2], a)
        outline(c, RAIL[0])
        fr.append(c)
    reg("railstrike_impact", "one_shot", strip(fr, "railstrike_impact.png"), 0,
        "PREMIUM. 384x112, 14 frames. Charge-up rings converge on the muzzle (0-2), then the beam fires from x=40 to x=344 with a white core, gold sheath, helical ripple, grid ticks, shockwave rings down the beam and an impact bloom with debris (3-13). For other lengths 3-slice: keep x<72 and x>312 fixed and stretch the middle. Rotate to aim, origin = muzzle (40,56).")


# =============== FLAGSHIP TIER: Rail Strike / Wildfire / Deep Freeze / Thunderstorm. 384px frames, 24 frames, layered ===============
FS = 384; FC = 192; FRR = 170


def bolt2(c, p0, p1, th, cols, a, jit, seed, glow=True):
    rnd = random.Random(seed)
    n = max(3, int(math.hypot(p1[0] - p0[0], p1[1] - p0[1]) / 10))
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]; m = math.hypot(dx, dy) or 1; px_, py_ = -dy / m, dx / m
    pts = [p0]
    for j in range(1, n):
        f = j / n; o = (rnd.random() - 0.5) * 2 * jit
        pts.append((p0[0] + dx * f + px_ * o, p0[1] + dy * f + py_ * o))
    pts.append(p1)
    if glow:
        for q in range(len(pts) - 1): c.line(pts[q], pts[q + 1], th + 4, cols[2] if len(cols) > 2 else cols[1], a * 0.35)
    for q in range(len(pts) - 1): c.line(pts[q], pts[q + 1], th + 2, cols[1], a * 0.8)
    for q in range(len(pts) - 1): c.line(pts[q], pts[q + 1], th, cols[0], a)
    return pts


def bolt_tree(c, p0, p1, th, cols, a, jit, seed, depth=2):
    pts = bolt2(c, p0, p1, th, cols, a, jit, seed)
    if depth <= 0: return
    rnd = random.Random(seed + 999)
    for j in range(2, len(pts) - 2):
        if rnd.random() < 0.35:
            ang = math.atan2(p1[1] - p0[1], p1[0] - p0[0]) + (rnd.random() - 0.5) * 2.0
            L = math.hypot(p1[0] - p0[0], p1[1] - p0[1]) * (0.2 + 0.2 * rnd.random())
            bolt_tree(c, pts[j], pol(pts[j][0], pts[j][1], ang, L), max(1, th - 1), cols, a * 0.9, jit * 0.6, seed + j * 17, depth - 1)


def fadef(k, start):
    return 1.0 if k < start else max(0.0, 1 - (k - start) / (1 - start))


def wildfire():
    fr = []; n = 24
    for i in range(n):
        k = i / (n - 1); a = fadef(k, 0.72); o = ease(min(1, k * 1.8)); r = FRR * o
        c = C(FS, FS); rnd = random.Random(31)
        c.disc(FC, FC, r, (50, 8, 4), 0.7 * a); c.disc(FC, FC, r * 0.85, FIRE[0], 0.6 * a); c.disc(FC, FC, r * 0.6, FIRE[1], 0.55 * a); c.disc(FC, FC, r * 0.32, FIRE[2], 0.6 * a)
        # lava cracks radiating over the scorched ground
        for t in range(11):
            ang = math.tau * t / 11 + 0.2; pts = [pol(FC, FC, ang, 8)]
            L = r * (0.55 + 0.45 * ((t * 7) % 5) / 5)
            for j in range(1, 9):
                pts.append(pol(FC, FC, ang + (rnd.random() - 0.5) * 0.25, L * j / 8))
            for q in range(len(pts) - 1):
                c.line(pts[q], pts[q + 1], 4, FIRE[0], a); c.line(pts[q], pts[q + 1], 2, FIRE[2] if (q + i) % 3 else FIRE[3], a)
        if i < 4:
            c.disc(FC, FC, 70 - i * 14, FIRE[4], 1.0, False); c.disc(FC, FC, 90 - i * 16, FIRE[3], 0.9); c.disc(FC, FC, 110 - i * 18, FIRE[2], 0.6)
        # vortex: three spiral arms of flame
        rot = k * 5.0
        for arm in range(3):
            for t in range(22):
                f = t / 21; ang = arm * math.tau / 3 + rot + f * 2.4; rad = r * (0.12 + 0.82 * f)
                p = pol(FC, FC, ang, rad)
                flame_col(c, round(p[0]), round(p[1]), 10 + 8 * f, (10 + 22 * f) * min(1, k * 4) * (1 - max(0, k - 0.7) * 2.5), i * 1.3 + t * 1.9 + arm, a, math.cos(ang) * 0.4)
        # three nested rings of flame tongues, outer ring the tallest
        for ri, (rf, nf, hh, wd) in enumerate(((1.0, 44, 52, 16), (0.72, 28, 38, 15), (0.45, 16, 30, 14))):
            for t in range(nf):
                ang = math.tau * (t + 0.5 * ri) / nf + rnd.random() * 0.05; u = (math.cos(ang), math.sin(ang))
                h_ = (hh * (0.6 + 0.6 * rnd.random())) * min(1, k * 3 + 0.1 * ri) * (1 - max(0, k - 0.65) * 2.2)
                flame_col(c, round(FC + u[0] * r * rf), round(FC + u[1] * r * rf), wd + rnd.random() * 6, h_, i * 1.5 + t * 2.3 + ri, a, u[0] * 0.5)
        # central fire pillar
        pk = min(1, max(0, (k - 0.08) / 0.3)) * (1 - max(0, k - 0.6) * 2.5)
        if pk > 0:
            for q, (wd, hh) in enumerate(((54, 190), (36, 160), (20, 120))):
                flame_col(c, FC, FC + 24, wd, hh * pk, i * 1.9 + q * 2, a)
        c.ring(FC, FC, r, 6, FIRE[2], a); c.ring(FC, FC, r + 4, 3, FIRE[4], a); c.ring(FC, FC, r * 0.7, 3, FIRE[3], a * 0.6)
        # heat-haze rings
        for q in range(3):
            kk = (k * 1.4 - q * 0.18) % 1.0
            c.ring(FC, FC, FRR * 1.08 * ease(kk), 2, FIRE[3], 0.5 * (1 - kk) * a)
        for j in range(90):
            ang = rnd.random() * math.tau; rr_ = r * rnd.random(); p = pol(FC, FC, ang, rr_); rise = k * (40 + 140 * rnd.random())
            c.dot(p[0] + math.sin(rise * 0.15 + j) * 4, p[1] - rise, 4 if j % 5 == 0 else (3 if j % 2 else 2), FIRE[4] if j % 4 == 0 else FIRE[3 if j % 2 else 2], a)
        outline(c, (40, 6, 3), a)
        fr.append(c)
    reg("wildfire_impact", "one_shot", strip(fr, "wildfire_impact.png"), FRR,
        "FLAGSHIP. 384x384, 24 frames. White-hot ignition flash (0-3), shockwave + haze rings, glowing lava cracks, 3 spiral flame arms, 3 nested rings of tongues, a central fire pillar (frames 2-14), 90 embers; fades from frame 17. Scale by game radius / 170.")


def hexfloor(c, cx, cy, r, s, col, a):
    ap = s * 0.866
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 > r * r: continue
            q = (math.sqrt(3) / 3 * (x - cx) - (y - cy) / 3) / s; rr = (2 / 3 * (y - cy)) / s
            xx, zz = q, rr; yy = -xx - zz
            rx, ry, rz = round(xx), round(yy), round(zz)
            dxx, dyy, dzz = abs(rx - xx), abs(ry - yy), abs(rz - zz)
            if dxx > dyy and dxx > dzz: rx = -ry - rz
            elif dyy > dzz: ry = -rx - rz
            else: rz = -rx - ry
            hx = cx + s * math.sqrt(3) * (rx + rz / 2); hy = cy + s * 1.5 * rz
            vx, vy = x - hx, y - hy
            if max(abs(vy), abs(vx) * 0.866 + abs(vy) * 0.5) > ap - 1.0 and max(abs(vy), abs(vx) * 0.866 + abs(vy) * 0.5) <= ap + 0.5:
                c.set(x, y, col, a)


def deepfreeze():
    fr = []; n = 24
    for i in range(n):
        k = i / (n - 1); grow = ease(min(1, k * 1.8)); r = FRR * grow
        shat = max(0, (k - 0.58) / 0.42); fade = 1 - shat ** 2.2
        c = C(FS, FS); rnd = random.Random(15)
        if i < 4: c.disc(FC, FC, 70 - i * 15, WHITE, 1.0, False); c.disc(FC, FC, 100 - i * 20, ICE[3], 0.8)
        c.disc(FC, FC, r, (20, 50, 100), 0.7 * fade); c.disc(FC, FC, r * 0.82, ICE[0], 0.65 * fade); c.disc(FC, FC, r * 0.56, ICE[1], 0.55 * fade); c.disc(FC, FC, r * 0.3, ICE[2], 0.6 * fade)
        hexfloor(c, FC, FC, r * 0.96, 20, ICE[3], 0.7 * fade * min(1, k * 4))
        # light rays turning slowly
        for q in range(8):
            ang = q * math.tau / 8 + k * 0.8
            c.line(pol(FC, FC, ang, r * 0.1), pol(FC, FC, ang, r * 0.92), 2, WHITE, 0.45 * fade * min(1, k * 3))
        c.ring(FC, FC, r, 8, ICE[2], fade); c.ring(FC, FC, r - 1, 4, ICE[4], fade); c.ring(FC, FC, r - 11, 3, ICE[1], 0.8 * fade); c.ring(FC, FC, r * 0.55, 2, ICE[3], 0.6 * fade)
        # glacier crystal clusters on the rim (big, mid, small)
        for t in range(18):
            ang = math.tau * t / 18 + 0.1; ex, ey = pol(FC, FC, ang, r - 3)
            L = (30 + 44 * rnd.random()) * min(1, k * 4 + 0.15); off = shat * (40 + 90 * rnd.random())
            bx, by = ex + math.cos(ang) * off, ey + math.sin(ang) * off
            crystal(c, bx, by, L, 8, ang, fade)
            crystal(c, bx, by, L * 0.65, 5, ang + 0.4, fade); crystal(c, bx, by, L * 0.65, 5, ang - 0.4, fade)
            crystal(c, ex, ey, L * 0.5, 4, ang + math.pi, fade * 0.9)
        for t in range(40):
            ang = math.tau * t / 40 + 0.07; ex, ey = pol(FC, FC, ang, r)
            crystal(c, ex, ey, 8 + 12 * rnd.random(), 3, ang, fade)
        # huge snowflake core
        arm = r * 0.62 * min(1, grow * 1.15)
        snowflake(c, FC, FC, arm, ICE[4], fade); snowflake(c, FC, FC, arm * 0.6, ICE[3], fade); snowflake(c, FC, FC, arm * 0.3, WHITE, fade)
        c.disc(FC, FC, 12, ICE[4], fade, False); c.ring(FC, FC, 16, 2, WHITE, fade)
        # falling snow
        for j in range(70):
            ang = rnd.random() * math.tau; rr_ = r * rnd.random(); p = pol(FC, FC, ang, rr_); fall = (k * 90 * (0.5 + rnd.random())) % 120
            c.dot(p[0] + math.sin(fall * 0.2 + j) * 5, p[1] - 40 + fall, 3 if j % 4 == 0 else 2, WHITE, fade)
        # shatter: shards of three sizes + frost mist
        if shat > 0:
            for j in range(60):
                ang = rnd.random() * math.tau; d = 30 + shat * (90 + 120 * rnd.random())
                p = pol(FC, FC, ang, d)
                crystal(c, p[0], p[1], 8 + 18 * rnd.random(), 3 + (j % 3), ang + shat * 4, fade)
            c.ring(FC, FC, r * (1 + shat * 0.3), 4, WHITE, (1 - shat) * 0.9)
            for j in range(24):
                p = pol(FC, FC, rnd.random() * math.tau, r * (0.6 + 0.6 * shat * rnd.random()))
                c.disc(p[0], p[1], 10 + 8 * rnd.random(), ICE[3], 0.5 * (1 - shat))
        for j in range(40):
            if (i + j) % 4 < 2:
                p = pol(FC, FC, rnd.random() * math.tau, r * rnd.random()); c.plus(round(p[0]), round(p[1]), 5 if j % 4 == 0 else 3, WHITE, fade)
        outline(c, (10, 25, 60), fade)
        fr.append(c)
    reg("deepfreeze_impact", "one_shot", strip(fr, "deepfreeze_impact.png"), FRR,
        "FLAGSHIP. 384x384, 24 frames. Ignition flash (0-3), frost floods out over a hex-ice floor with turning light rays, glacier crystal clusters, triple snowflake core and falling snow (4-13), then SHATTERS from frame 14 (shards of 3 sizes + frost mist). Sync the bonus-damage pop to frame 14. Scale by game radius / 170.")


def thunder_cast():
    fr = []; n = 24
    for i in range(n):
        k = i / (n - 1); a = fadef(k, 0.75); o = ease(min(1, k * 1.8)); r = FRR * o
        c = C(FS, FS); rnd = random.Random(i // 2 + 80); flash = (i % 6 in (0, 1)) or i < 4
        c.disc(FC, FC, r, (10, 25, 60), 0.7 * a); c.disc(FC, FC, r * 0.8, STORM[0], 0.55 * a); c.disc(FC, FC, r * 0.5, STORM[1], 0.5 * a)
        if flash: c.disc(FC, FC, r, STORM[3], 0.28 * a)
        for q in range(14):  # rain streaks
            x = rnd.randint(FC - 150, FC + 150); y = rnd.randint(FC - 140, FC + 140)
            if (x - FC) ** 2 + (y - FC) ** 2 < r * r: c.line((x, y), (x - 5, y + 14), 1, STORM[2], 0.8 * a)
        c.ring(FC, FC, r, 7, STORM[3], a); c.ring(FC, FC, r - 1, 3, WHITE, a); c.ring(FC, FC, r - 10, 3, STORM[2], 0.7 * a)
        for t in range(22):  # crawling arcs round the rim
            ang = math.tau * t / 22 + i * 0.4
            bolt2(c, pol(FC, FC, ang, r), pol(FC, FC, ang + 0.22, r), 2, (WHITE, STORM[2]), a, 6, i * 31 + t, False)
        # towering storm cloud
        cy_ = 58; cr = 60 * min(1, k * 3 + 0.3)
        for layer, (rf, col, al) in enumerate(((1.0, (25, 28, 60), 0.9), (0.8, (50, 58, 105), 0.85), (0.55, (85, 95, 150), 0.8))):
            c.disc(FC, cy_, cr * rf, col, al * a)
        for q in range(11):
            ang = k * 4 + q * 0.57; p = pol(FC, cy_, ang, cr * 0.7); c.disc(p[0], p[1], cr * 0.26, (100, 110, 165), 0.7 * a)
        c.ring(FC, cy_, cr, 3, STORM[2], 0.8 * a)
        if flash: c.disc(FC, cy_, cr * 0.7, STORM[3], 0.5 * a)
        # forked bolts cloud -> ground zone; big bolt trees
        if i % 2 == 0 or i < 6:
            for t in range(5):
                ang = math.radians(25 + t * 32 + rnd.random() * 10)
                tgt = pol(FC, FC, ang, r * (0.45 + 0.5 * rnd.random()))
                bolt_tree(c, (FC + (t - 2) * 18, cy_ + cr * 0.5), tgt, 3, (WHITE, STORM[2], STORM[1]), a, 12, i * 9 + t, 2)
        # bolts radiating from the caster
        for t in range(8):
            ang = math.tau * t / 8 + i * 0.12
            bolt2(c, pol(FC, FC, ang, 12), pol(FC, FC, ang, r * (0.45 + 0.4 * rnd.random())), 2, (WHITE, STORM[2]), a * 0.9, 9, i * 3 + t)
        if i < 4:
            c.disc(FC, FC, 64 - i * 14, WHITE, 1.0, False); c.ring(FC, FC, 40 + i * 30, 5, WHITE, 1.0)
        for j in range(70):
            p = pol(FC, FC, rnd.random() * math.tau, r * rnd.random())
            c.dot(p[0], p[1], 4 if j % 6 == 0 else (3 if j % 2 else 2), WHITE if j % 2 else STORM[2], a)
        outline(c, (10, 25, 60), a)
        fr.append(c)
    reg("thunderstorm_impact", "one_shot", strip(fr, "thunderstorm_impact.png"), FRR,
        "FLAGSHIP. 384x384, 24 frames. Ignition flash (0-3), rain-lashed charged ground zone with crawling rim arcs and strobe flashes every 6 frames, towering storm cloud overhead (centre y=58, above the caster) throwing branching bolt trees onto the zone, 8 bolts radiating from the caster. Scale by game radius / 170.")


def thunder_strike():
    fr = []; n = 14
    W, H = 160, 288; x, yb = 80, 250
    for i in range(n):
        k = i / (n - 1); a = fadef(k, 0.45)
        c = C(W, H); rnd = random.Random(70)
        if i < 9:
            al = 1.0 if i < 6 else a * 1.8
            bolt_tree(c, (x + rnd.randint(-6, 6), 0), (x, yb), 6 if i < 4 else 4, (WHITE, STORM[2], STORM[1]), al, 16, 300 + i // 2, 3)
            if i < 3: c.rect(x - 14, 0, 28, yb, STORM[3], 0.3)
        c.disc(x, yb, 46 * ease(k), (10, 25, 60), 0.7 * a); c.disc(x, yb, 32 * ease(k), STORM[1], 0.6 * a)
        for q in range(8):   # scorch cracks
            ang = q * math.tau / 8 + 0.2; c.line(pol(x, yb, ang, 6), pol(x, yb, ang, 36 * ease(k)), 2, STORM[0], a)
        c.ring(x, yb, 6 + 64 * ease(k), 6, WHITE if i < 7 else STORM[3], a); c.ring(x, yb, 3 + 40 * ease(k), 3, STORM[2], a)
        if i < 4: c.disc(x, yb, 30 - i * 6, WHITE, 1.0, False)
        for j in range(30):
            ang = rnd.random() * math.tau; d = 60 * ease(k) * (0.3 + rnd.random()); p = pol(x, yb, ang, d)
            c.dot(p[0], p[1] - k * 16, 4 if j % 4 == 0 else (3 if j % 2 else 2), WHITE if j % 3 == 0 else STORM[2], a)
        outline(c, (10, 25, 60), a)
        fr.append(c)
    reg("thunderstorm_strike", "one_shot", strip(fr, "thunderstorm_strike.png"), 0,
        "FLAGSHIP. 160x288, 14 frames. Per-strike hit: a thick bolt tree with 3 levels of branches crashes down (0-8) with a column flash, scorch cracks, double shock ring and sparks (3-13). Origin = (80, 250), the point of impact. Play once.")


def aura_storm():
    fr = []; n = 8
    for i in range(n):
        c = C(96, 96); rnd = random.Random(90 + i * 3); k = i / n
        cy_ = 14
        for rf, col in ((1.0, (25, 28, 60)), (0.78, (50, 58, 105)), (0.5, (85, 95, 150))): c.disc(48, cy_, 17 * rf, col, 0.95)
        for q in range(5):
            p = pol(48, cy_, k * math.tau + q * 1.25, 10); c.disc(p[0], p[1], 5, (100, 110, 165), 0.8)
        c.ring(48, cy_, 17, 2, STORM[2], 0.8)
        if i % 2 == 0: c.disc(48, cy_, 12, STORM[3], 0.5)
        for s_ in range(4):
            ang = rnd.random() * math.tau; p = pol(48, 56, ang, 20)
            for j in range(3):
                nx = pol(p[0], p[1], ang + (rnd.random() - 0.5) * 1.6, 10); c.line(p, nx, 2, WHITE if j == 1 else STORM[2]); p = nx
        if i % 2 == 0: bolt2(c, (48 + rnd.randint(-5, 5), 26), (48 + rnd.randint(-10, 10), 44), 2, (WHITE, STORM[2]), 1.0, 4, i)
        for j in range(4):
            q = pol(48, 56, rnd.random() * math.tau, 38); c.plus(round(q[0]), round(q[1]), 2, STORM[3])
        for q in range(5): c.line((rnd.randint(8, 88), rnd.randint(30, 80)), (rnd.randint(4, 84), rnd.randint(34, 90)), 1, STORM[2], 0.5) if False else None
        outline(c, (10, 25, 60))
        fr.append(c)
    reg("thunderstorm_aura", "aura_loop", strip(fr, "thunderstorm_aura.png"), 38,
        "FLAGSHIP. 96x96, 8-frame loop. A turning storm cloud floats over the player (cloud centre y=14) dropping bolts, with arcs crackling round the body. Loop frames 0-7 while THUNDERSTORM is active (6 s). Player centre = (48,56).", loop=True)


def railstrike():
    fr = []; n = 20
    W, H = 640, 160; ox, ex, y = 64, 576, 80
    for i in range(n):
        k = i / (n - 1); c = C(W, H); rnd = random.Random(60 + i)
        if i < 5:   # charge: rotating ring segments converge, vents, whine lines
            q = 1 - i / 4
            for ri, (rr_, th, segs) in enumerate(((54, 4, 6), (36, 3, 5), (20, 2, 4))):
                rad = 12 + (rr_ - 12) * q
                for sgm in range(segs):
                    a0 = sgm * math.tau / segs + i * (1.1 if ri % 2 else -1.1)
                    for st in range(14): c.dot(*pol(ox, y, a0 + st * 0.03, rad), th, RAIL[3] if ri != 1 else WHITE)
            c.dot(ox, y, 8 + i * 3, WHITE); c.ring(ox, y, 4 + i * 4, 3, RAIL[2], 1.0)
            c.rect(ox, y - 1, round((ex - ox) * (i / 4) ** 3), 2, RAIL[3], 0.9)
            for j in range(18): c.dot(*pol(ox, y, j / 18 * math.tau + i, 60 * q + 14), 2, RAIL[3])
        else:
            kk = (i - 5) / (n - 6); a = fadef(kk, 0.5)
            pk = 1 - kk * 0.9
            sh = max(4, round(30 * pk))
            c.rect(ox, y - sh - 14, ex - ox, (sh + 14) * 2, RAIL[0], 0.3 * a)
            c.rect(ox, y - sh - 6, ex - ox, (sh + 6) * 2, RAIL[1], 0.55 * a)
            c.rect(ox, y - sh, ex - ox, sh * 2, RAIL[2], 0.85 * a)
            c.rect(ox, y - sh // 2, ex - ox, max(2, sh), RAIL[3], a)
            cw = max(3, round(12 * pk)); c.rect(ox, y - cw // 2, ex - ox, cw, WHITE, a)
            for sgn in (-1, 1):   # double helix
                for xx in range(ox, ex, 2):
                    ph = (xx - ox) * 0.07 - kk * 22
                    yy = y + sgn * math.sin(ph) * (sh + 10) * (1 - kk * 0.7)
                    c.dot(xx, yy, 3, RAIL[3] if sgn > 0 else WHITE, a)
            for sgn in (-1, 1):   # electric arcing along the sheath edges
                for q in range(9):
                    x0 = ox + rnd.randint(0, ex - ox - 50)
                    bolt2(c, (x0, y + sgn * (sh + 4)), (x0 + 45, y + sgn * (sh + 4 + rnd.randint(8, 26))), 2, (WHITE, RAIL[3]), a * 0.9, 5, i * 17 + q * 3 + sgn, False)
            for t in range(24):   # grid ticks light up
                f = (t + .5) / 24
                if f > min(1, kk * 4 + 0.2): break
                x = ox + (ex - ox) * f; hh = round(50 * (1 - kk) * (0.55 + 0.45 * (t % 2)))
                c.rect(x, y - hh, 2, hh * 2, WHITE if t % 3 == 0 else RAIL[2], a * 0.9)
            for q_ in range(6):   # sonic chevrons chasing down the beam
                pos = (kk * 1.5 + q_ * 0.14) % 1.0; x = ox + (ex - ox) * pos
                if kk < 0.85:
                    for sgn in (-1, 1): c.line((x, y), (x - 26, y + sgn * 34), 3, WHITE, 0.7 * a)
            # muzzle starburst
            for q in range(12):
                ang = q * math.tau / 12; c.line(pol(ox, y, ang, 8), pol(ox, y, ang, (30 + 40 * (q % 2)) * (1 - kk) + 6), 3, WHITE if q % 2 else RAIL[3], a)
            c.ring(ox, y, 16 + 70 * ease(kk), 6, WHITE, a); c.ring(ox, y, 8 + 44 * ease(kk), 3, RAIL[2], a)
            c.dot(ox, y, max(3, round(36 * (1 - kk))), WHITE)
            # impact: crater, bloom, starburst, debris, plasma pillar
            c.disc(ex, y, 52 * ease(kk), (60, 40, 10), 0.8 * a); c.disc(ex, y, 40 * ease(kk), RAIL[1], 0.7 * a); c.disc(ex, y, 24 * ease(kk), RAIL[3], 0.8 * a)
            c.ring(ex, y, 8 + 66 * ease(kk), 6, WHITE, a); c.ring(ex, y, 4 + 42 * ease(kk), 3, RAIL[3], a)
            for q in range(14):
                ang = q * math.tau / 14 + 0.1; c.line(pol(ex, y, ang, 10), pol(ex, y, ang, 20 + (50 if q % 2 else 30) * ease(kk)), 3, WHITE if q % 2 else RAIL[2], a)
            for j in range(40):
                ang = (rnd.random() - 0.5) * 3.2 + (math.pi if j % 2 else 0); d = 90 * ease(kk) * (0.3 + rnd.random())
                p = pol(ex, y, ang, d); c.dot(p[0], p[1] + kk * 16 * (j % 4), 5 if j % 5 == 0 else 3, WHITE if j % 3 == 0 else RAIL[2], a)
        outline(c, RAIL[0])
        fr.append(c)
    reg("railstrike_impact", "one_shot", strip(fr, "railstrike_impact.png"), 0,
        "FLAGSHIP. 640x160, 20 frames. Charge-up: three counter-rotating ring segments converge on the muzzle while a hairline beam draws in (0-4). Fire (5-19): white-core beam with gold sheath, double helix, edge arcing, grid ticks, sonic chevrons racing down the beam, muzzle starburst and a crater + bloom + starburst + debris at the far end. For other beam lengths 3-slice: keep x<110 and x>530 fixed, stretch the middle. Rotate to aim; origin = muzzle (64,80).")


for f in (phase, purge, lockdown, deepscan, restore, overclock, railstrike, pause_, wildfire, deepfreeze, thunder_cast, thunder_strike,
          aura_overclock, aura_scan, aura_storm, aura_pause):
    f()

json.dump(MANIFEST, open(os.path.join(OUT, "manifest.json"), "w"), indent=2)

# contact sheet preview (dark bg, 2x, first row per effect)
rows = []
for name, m in MANIFEST.items():
    im = Image.open(os.path.join(OUT, m["file"]))
    rows.append((name, im))
PW = 12 * 96
sheet_h = sum(max(60, im.height // 2) + 6 for _, im in rows)
sheet = Image.new("RGBA", (max(im.width // 2 for _, im in rows), sheet_h), (14, 16, 24, 255))
y = 0
for name, im in rows:
    half = im.resize((im.width // 2, im.height // 2), Image.NEAREST)
    sheet.alpha_composite(half, (0, y))
    from PIL import ImageDraw
    d = ImageDraw.Draw(sheet); d.rectangle((0, y, 150, y + 11), fill=(0, 0, 0, 255)); d.text((2, y), name.upper().replace("_", " "), fill=(255, 255, 255, 255))
    y += max(60, half.height) + 6
sheet.save(os.path.join(os.path.dirname(OUT.rstrip("/")), "abilities_contact_sheet.png"))
print("ok", len(MANIFEST))
