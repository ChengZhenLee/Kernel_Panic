"""Pixel-art FX sheets for the four evolution weapons (RAILGUN, SCORCHED EARTH, TESLA GRID, ABSOLUTE ZERO).
Usage: python tools/gen_weapon_fx.py <outdir>
Same rules as gen_ability_fx.py: transparent background, hard-edged pixels only (fades use ordered dither), 5-colour ramps, horizontal strips,
12 fps, nearest filtering. Writes <outdir>/*.png and <outdir>/manifest.json."""
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

    def ellipse(s, cx, cy, rx, ry, col, a=1.0, checker=True):
        for j in range(-int(ry) - 1, int(ry) + 2):
            for i in range(-int(rx) - 1, int(rx) + 2):
                if (i / max(rx, .01)) ** 2 + (j / max(ry, .01)) ** 2 <= 1 and (not checker or (i + j) % 2 == 0):
                    s.set(cx + i, cy + j, col, a)


def ease(k): return 1 - (1 - k) ** 3
def lerp(a, b, k): return a + (b - a) * k
def pol(cx, cy, ang, d): return (cx + math.cos(ang) * d, cy + math.sin(ang) * d)
def clamp(v, a=0.0, b=1.0): return max(a, min(b, v))


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


def strip(frames, name):
    w, h = frames[0].w, frames[0].h
    im = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.paste(f.im, (i * w, 0))
    im.save(os.path.join(OUT, name))
    return (w, h, len(frames))


MANIFEST = {}


def reg(name, kind, size, desc, loop=False, fps=12, **extra):
    MANIFEST[name] = dict({"file": name + ".png", "type": kind, "frame_w": size[0], "frame_h": size[1], "frames": size[2],
                           "fps": fps, "loop": loop, "notes": desc}, **extra)


# palettes, dark -> light
FIRE = [(90, 12, 6), (215, 50, 10), (255, 130, 25), (255, 208, 80), (255, 248, 200)]
ICE = [(30, 70, 130), (90, 170, 235), (170, 225, 255), (225, 247, 255), WHITE]
RAIL = [(110, 60, 0), (230, 150, 20), (255, 215, 90), (255, 244, 180), WHITE]
ELEC = [(18, 30, 110), (55, 105, 235), (95, 225, 255), (195, 248, 255), WHITE]
VIO = [(50, 18, 110), (120, 60, 220), (185, 120, 255)]   # Tesla Grid accent


# ====================================================================================================================
# RAILGUN: 384x96, 8 frames. Beam fires left->right along y=48. Muzzle origin x=48, end point x=336.
#   left cap  = x 0..96   (muzzle bloom, world -48..+48 around the player)
#   body tile = x 96..288 (192 px, tiles seamlessly: every periodic term has a period dividing 192)
#   right cap = x 288..384 (impact flare, world end-48..end+48)
# ====================================================================================================================
def railgun_beam():
    W, H, n = 384, 96, 8
    ox, ex, y = 48, 336, 48
    fr = []
    for i in range(n):
        k = i / (n - 1)
        life = 1.0 - clamp((k - 0.3) / 0.7)         # full strength for the first third, then thins out
        c = C(W, H)
        sh = max(2, round(15 * (0.3 + 0.7 * life)))         # sheath half-height
        cw = max(1, round(5 * (0.25 + 0.75 * life)))        # white core half-height
        a = 1.0   # no dither anywhere in this sheet: the beam is rotated in-engine and a rotated dither turns to noise; the fade is done with the draw colour's alpha
        c.rect(ox, y - sh - 2, W - ox, (sh + 2) * 2, RAIL[0], 1.0)             # dark amber edge
        c.rect(ox, y - sh, W - ox, sh * 2, RAIL[1], a)
        c.rect(ox, y - sh + 3, W - ox, max(1, sh * 2 - 6), RAIL[2], a)
        c.rect(ox, y - cw - 1, W - ox, cw * 2 + 2, RAIL[3], 1.0)
        c.rect(ox, y - cw, W - ox, cw * 2, WHITE, 1.0)
        # one clean helix strand pair scrolling down the beam (period 48 divides the 192 px tile)
        for x in range(ox, W):
            ph = (x - i * 24) / 48.0 * math.tau
            amp = sh * 0.75
            yy = y + math.sin(ph) * amp
            c.dot(x, yy, 2, WHITE, a)
            c.dot(x, 2 * y - yy, 2, RAIL[0], a * 0.9)
        # chevrons racing down the beam (period 48, drift 12 px/frame): the speed cue
        for q in range(-1, W // 48 + 1):
            xx = q * 48 + (i * 12) % 48
            if xx < ox + 8: continue
            hh = round(sh * 0.9)
            c.line((xx - 5, y - hh), (xx + 3, y), 2, WHITE, a)
            c.line((xx - 5, y + hh), (xx + 3, y), 2, WHITE, a)
        # --- muzzle cap (inside x<96) ---
        mk = ease(min(1, k * 2.5))
        flash = 1 - clamp(k * 1.6)
        c.disc(ox, y, round(8 + 12 * flash), RAIL[3], 1.0, False)
        c.disc(ox, y, round(5 + 8 * flash), WHITE, 1.0, False)
        c.ring(ox, y, 10 + 34 * mk, 3, WHITE, 1.0)
        c.ring(ox, y, 6 + 20 * mk, 2, RAIL[2], 1.0)
        rnd = random.Random(5)
        for j in range(12):
            ang = (rnd.random() - 0.5) * 2.6 + (math.pi if j % 2 else 0)
            d = 14 + 32 * mk * (0.4 + rnd.random())
            p = pol(ox, y, ang, d)
            c.dot(p[0], p[1], 3 if j % 3 == 0 else 2, WHITE if j % 3 == 0 else RAIL[2], 1.0)
        # --- impact cap (inside x>288) ---
        c.disc(ex, y, round(8 + 26 * mk), RAIL[1], 1.0, False)
        c.disc(ex, y, round(4 + 14 * flash + 8 * mk), RAIL[3], 1.0, False)
        c.disc(ex, y, round(2 + 10 * flash), WHITE, 1.0, False)
        c.ring(ex, y, 8 + 38 * mk, 3, WHITE, 1.0)
        c.ring(ex, y, 4 + 24 * mk, 2, RAIL[3], 1.0)
        rnd = random.Random(9)
        for j in range(20):
            ang = (rnd.random() - 0.5) * 3.2 + (math.pi if j % 2 else 0)
            d = 42 * mk * (0.3 + rnd.random())
            p = pol(ex, y, ang, d)
            c.dot(p[0], p[1] + k * 7 * (j % 3), 4 if j % 4 == 0 else 3, WHITE if j % 3 == 0 else RAIL[2], 1.0)
        outline(c, RAIL[0], 1.0)
        fr.append(c)
    reg("evo_railgun_beam", "one_shot", strip(fr, "evo_railgun_beam.png"),
        "RAILGUN beam, rotate to aim. 3 parts: left cap x0-96 (muzzle at x=48,y=48), body tile x96-288 (tile it, seamless), right cap x288-384 (impact point at x=336). "
        "Frames 0-7, play once over ~0.6 s; thins out from frame 3.", cap_l=96, tile_x=96, tile_w=192, cap_r=288, origin_x=48, end_x=336, origin_y=48)


def railgun_hit():
    n, S = 6, 64
    fr = []
    for i in range(n):
        k = i / (n - 1); a = 1 - k * k
        c = C(S, S); rnd = random.Random(12)
        if i < 2: c.disc(32, 32, 14 - i * 5, WHITE, 1.0, False)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):   # cross flash
            L = round(26 * ease(min(1, k * 2.2)) * (1 - k * 0.5))
            c.line((32, 32), (32 + dx * L, 32 + dy * L), 3 if k < .5 else 2, WHITE if k < .6 else RAIL[3], a)
        c.ring(32, 32, 4 + 24 * ease(k), 3, RAIL[2], a)
        for j in range(12):
            ang = rnd.random() * math.tau; d = 26 * ease(k) * (0.35 + rnd.random() * .65)
            p = pol(32, 32, ang, d)
            c.dot(p[0], p[1] + k * 6, 3 if j % 3 == 0 else 2, WHITE if j % 3 == 0 else RAIL[1 + j % 3], a)
        outline(c, RAIL[0], a)
        fr.append(c)
    reg("evo_railgun_hit", "one_shot", strip(fr, "evo_railgun_hit.png"),
        "Spark burst on every enemy the beam pierces. Centre = (32,32). Frames 0-5, play once.")


# ====================================================================================================================
# SCORCHED EARTH
# ====================================================================================================================
def flame(c, x, y, w, h, ph, a=1.0, lean=0.0):
    """Layered upright flame tongue with its base at (x,y): wavy tip, ramp dark red -> orange -> yellow -> white by heat."""
    for dx in range(-int(w / 2), int(w / 2) + 1):
        f = 1 - abs(dx) / (w / 2 + 0.01)
        ch = h * (f ** 0.75) * (0.80 + 0.20 * math.sin(ph + dx * 0.8))
        sway = math.sin(ph * 1.0 + dx * 0.15) * 2.0 + lean * ch * 0.4
        for j in range(int(ch)):
            fr_ = j / max(1, ch)
            heat = f * (1 - fr_ * 0.55) + (1 - fr_) * 0.45
            idx = int(min(4, max(0, heat * 3.4)))
            if fr_ > 0.82 and heat < 0.9: idx = max(0, idx - 1)
            c.set(x + dx + sway * fr_, y - j, FIRE[idx], a)


def inferno_flame():
    n, W, H = 8, 48, 80
    fr = []
    for i in range(n):
        c = C(W, H)
        ph = i / n * math.tau
        # three tongues of different height, phases offset so the ring never pulses in unison
        flame(c, 24, 76, 24, 54 + 4 * math.sin(ph), ph, 1.0)
        flame(c, 12, 76, 14, 34 + 5 * math.sin(ph + 2.1), ph + 2.1, 1.0, -0.15)
        flame(c, 37, 76, 14, 38 + 5 * math.sin(ph + 4.2), ph + 4.2, 1.0, 0.15)
        # embers rising (looping: each ember travels one full cycle over the 8 frames)
        rnd = random.Random(3)
        for j in range(5):
            x = 8 + rnd.random() * 32; sp = 1 + j % 2
            q = ((i * sp / n) + rnd.random()) % 1.0
            c.dot(x + math.sin(q * 6 + j) * 2, 70 - q * 66, 2 if j % 2 else 3, FIRE[3] if j % 2 else FIRE[4], 1.0 - q * 0.8)
        # glowing coals at the base
        c.rect(6, 76, 36, 3, FIRE[0]); c.rect(10, 76, 28, 2, FIRE[1]); c.rect(16, 76, 16, 1, FIRE[3])
        outline(c, FIRE[0])
        fr.append(c)
    reg("evo_inferno_flame", "loop", strip(fr, "evo_inferno_flame.png"),
        "One flame cluster for the SCORCHED EARTH ring. Upright (fire rises, never rotate). Base centre = (24,76). Stand them along the ring every ~26 px, "
        "each with its own frame offset and an optional horizontal flip. Loop frames 0-7.", loop=True, base_x=24, base_y=76)


def inferno_pillar():
    n, W, H = 10, 64, 144
    fr = []
    for i in range(n):
        k = i / (n - 1)
        grow = ease(min(1, k * 2.6))
        die = clamp((k - 0.55) / 0.45)            # the last frames burn down: the tongue shrinks, no dither (a dithered dark flame goes grey)
        c = C(W, H)
        h = 130 * grow * (1 - 0.8 * die)
        wd = 30 * (1 - 0.55 * die)
        foot = min(1, k * 3) * (1 - die * 0.7)
        c.ellipse(32, 139, 30 * foot, 7 * foot, FIRE[1], 1.0, False)       # blast scorch at the foot (solid)
        c.ellipse(32, 139, 22 * foot, 5 * foot, FIRE[2], 1.0, False)
        c.ellipse(32, 139, 12 * foot, 3 * foot, FIRE[4] if i < 5 else FIRE[3], 1.0, False)
        flame(c, 32, 138, wd, h, i * 1.3, 1.0)
        flame(c, 32, 138, wd * 0.55, h * 0.75, i * 1.3 + 1.7, 1.0)
        rnd = random.Random(21)
        for j in range(10 if i > 0 else 0):
            x = 32 + (rnd.random() - 0.5) * 36; rise = k * (30 + 100 * rnd.random())
            c.dot(x, 130 - rise, 3 if j % 3 else 2, FIRE[4] if j % 4 == 0 else FIRE[3], 1.0 - die * 0.8)
        outline(c, FIRE[0], 1.0)
        fr.append(c)
    reg("evo_inferno_pillar", "one_shot", strip(fr, "evo_inferno_pillar.png"),
        "Fire geyser for the SCORCHED EARTH eruption. Base centre = (32,138). Spawn them in an expanding wave (delay by distance from the player). Frames 0-9, play once.",
        base_x=32, base_y=138)


# ====================================================================================================================
# TESLA GRID
# ====================================================================================================================
def bolt(c, p0, p1, th, cols, a, jit=7, seed=0, seg=12):
    rnd = random.Random(seed)
    n = max(3, int(math.hypot(p1[0] - p0[0], p1[1] - p0[1]) / seg))
    pts = [p0]
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]; m = math.hypot(dx, dy) or 1; px_, py_ = -dy / m, dx / m
    for j in range(1, n):
        f = j / n; o = (rnd.random() - 0.5) * 2 * jit
        pts.append((p0[0] + dx * f + px_ * o, p0[1] + dy * f + py_ * o))
    pts.append(p1)
    for q in range(len(pts) - 1): c.line(pts[q], pts[q + 1], th + 3, cols[2], a * 0.35)
    for q in range(len(pts) - 1): c.line(pts[q], pts[q + 1], th + 1, cols[1], a)
    for q in range(len(pts) - 1): c.line(pts[q], pts[q + 1], max(1, th - 1), cols[0], a)
    return pts


def tesla_strike():
    n, W, H = 10, 112, 208
    x, yb = 56, 160
    fr = []
    for i in range(n):
        k = i / (n - 1); a = 1 - clamp((k - 0.45) / 0.55)
        c = C(W, H)
        # ground lattice: the "grid" - a 5x5 node lattice with glowing links, flashes in then fades (squashed top-down view)
        gk = ease(min(1, k * 2.2))
        for gx in range(-2, 3):
            for gy in range(-2, 3):
                px, py = x + gx * 18 * gk, yb + gy * 8 * gk
                c.dot(px, py, 4 if (gx + gy) % 2 == 0 else 3, VIO[2] if (gx + gy) % 2 == 0 else ELEC[2], a)
        for gy in range(-2, 3):
            c.line((x - 36 * gk, yb + gy * 8 * gk), (x + 36 * gk, yb + gy * 8 * gk), 1, ELEC[1], a * 0.8)
        for gx in range(-2, 3):
            c.line((x + gx * 18 * gk, yb - 16 * gk), (x + gx * 18 * gk, yb + 16 * gk), 1, ELEC[1], a * 0.8)
        c.ellipse(x, yb, 40 * gk, 18 * gk, ELEC[0], 0.5 * a)
        # the bolt: main fork + two branches, a fresh shape every 2 frames
        if i < 6:
            sd = 40 + i // 2
            bolt(c, (x + (i % 2 - .5) * 3, 0), (x, yb), 4 if i < 4 else 3, (WHITE, ELEC[3], ELEC[1]), 1.0 if i < 4 else a * 1.4, 11, sd, 11)
            for b_ in range(3):
                sy = 30 + b_ * 38; sx = x + (b_ - 1) * 5
                bolt(c, (sx, sy), (sx + (-1) ** b_ * (22 + 8 * b_), sy + 40), 2, (WHITE, VIO[2], VIO[1]), 1.0 if i < 4 else a, 6, 70 + b_ + i // 2, 9)
        if i < 3: c.disc(x, yb, 20 - i * 5, WHITE, 1.0, False)
        c.ring(x, yb, 4 + 40 * ease(k), 4 if i < 3 else 3, WHITE if i < 3 else ELEC[3], a)
        c.ring(x, yb, 2 + 26 * ease(k), 2, ELEC[2], a)
        rnd = random.Random(33)
        for j in range(16):
            ang = rnd.random() * math.tau; d = 38 * ease(k) * (0.3 + rnd.random())
            p = pol(x, yb, ang, d)
            c.dot(p[0], p[1] - k * 10, 3 if j % 2 else 2, WHITE if j % 3 == 0 else (VIO[2] if j % 3 == 1 else ELEC[2]), a)
        outline(c, ELEC[0], a)
        fr.append(c)
    reg("evo_tesla_strike", "one_shot", strip(fr, "evo_tesla_strike.png"),
        "TESLA GRID hit: forked bolt falls from the top (0-5), a glowing 5x5 node lattice flashes on the ground, double shock ring + sparks. Origin = point of impact (56,160). "
        "Play once on every target the grid strikes. Frames 0-9.", base_x=56, base_y=160)


def tesla_coil():
    n, S = 8, 96
    fr = []
    for i in range(n):
        c = C(S, S); cx = cy = 48
        # footprint: dithered ground plate + diamond lattice
        c.ellipse(cx, cy, 42, 30, ELEC[0], 0.35)
        c.ring(cx, cy, 30, 2, ELEC[1], 0.55)
        # four pylons at the corners that arc to their neighbours and to the centre
        pyl = [(cx - 30, cy - 4), (cx + 30, cy - 4), (cx - 14, cy + 22), (cx + 14, cy + 22)]
        ring_order = [0, 1, 3, 2]
        for q in range(4):
            a_, b_ = pyl[ring_order[q]], pyl[ring_order[(q + 1) % 4]]
            if (i + q) % 2 == 0:
                bolt(c, (a_[0], a_[1] - 8), (b_[0], b_[1] - 8), 1, (WHITE, ELEC[2], ELEC[1]), 1.0, 4, 100 + i * 4 + q, 8)
        for q in range(4):
            px, py = pyl[q]
            c.rect(px - 2, py - 10, 5, 12, ELEC[1]); c.rect(px - 1, py - 10, 3, 10, ELEC[2]); c.dot(px, py - 12, 5, WHITE if (i + q) % 2 == 0 else VIO[2])
        # centre emitter pulsing
        pr = 5 + (i % 4)
        c.disc(cx, cy - 2, pr, ELEC[2], 0.8, False); c.disc(cx, cy - 2, pr - 3, WHITE, 1.0, False)
        for j in range(4):
            ang = i / n * math.tau * 0.25 + j * math.pi / 2
            p = pol(cx, cy - 2, ang, pr + 5); c.dot(p[0], p[1], 2, WHITE)
        outline(c, ELEC[0], 0.9)
        fr.append(c)
    reg("evo_tesla_coil", "loop", strip(fr, "evo_tesla_coil.png"),
        "Emitter glyph under the player while TESLA GRID is equipped: four pylons arcing round a pulsing core. Centre = (48,48); draw it a few px below the player's feet. Loop frames 0-7.",
        loop=True)


# ====================================================================================================================
# ABSOLUTE ZERO
# ====================================================================================================================
def snowflake(c, cx, cy, arm, col, hi, a=1.0, th=1):
    for t in range(3):
        ang = math.pi * t / 3 + math.pi / 6; d = (math.cos(ang), math.sin(ang))
        c.line((cx - d[0] * arm, cy - d[1] * arm), (cx + d[0] * arm, cy + d[1] * arm), th, col, a)
        for sg in (-1, 1):
            tip = (cx + d[0] * arm * 0.62 * sg, cy + d[1] * arm * 0.62 * sg)
            for so in (-1, 1):
                v = (-d[0] * sg + (-d[1]) * so, -d[1] * sg + d[0] * so); m = math.hypot(*v)
                c.line(tip, (tip[0] + v[0] / m * arm * 0.38, tip[1] + v[1] / m * arm * 0.38), th, hi, a)


def blizzard_flake():
    n, S = 8, 24
    fr = []
    for i in range(n):
        c = C(S, S)
        rot = i / n * math.pi / 3   # 6-fold symmetry: 8 frames turn it 60 degrees, a seamless loop
        # arms drawn rotated by hand so pixels stay square
        for t in range(6):
            ang = rot + t * math.pi / 3
            c.line((12, 12), pol(12, 12, ang, 9), 1, ICE[3])
            for sg in (-1, 1):
                tip = pol(12, 12, ang, 5.5)
                c.line(tip, pol(tip[0], tip[1], ang + sg * 0.9, 3.5), 1, ICE[2])
        c.dot(12, 12, 3, WHITE)
        outline(c, ICE[0], 0.6)
        fr.append(c)
    reg("evo_blizzard_flake", "loop", strip(fr, "evo_blizzard_flake.png"),
        "A drifting snowflake, 24x24, centre (12,12). Scatter many inside the ABSOLUTE ZERO area, fall + sway them in code, each with its own frame offset; draw at 1x or 2x. Loop frames 0-7.",
        loop=True)


def blizzard_crystal():
    n, W, H = 6, 64, 88
    fr = []
    X = 32
    spikes = [(X, 84, 74, 8, 0.0), (X - 14, 84, 44, 6, -0.3), (X + 14, 84, 52, 6, 0.3), (X - 7, 84, 30, 4, -0.1), (X + 8, 84, 34, 4, 0.1),
              (X - 22, 84, 22, 4, -0.35), (X + 22, 84, 26, 4, 0.35)]
    for i in range(n):
        c = C(W, H)
        for (bx, by, L, wd, lean) in spikes:
            for j in range(L):
                f = j / L
                w2 = wd * (1 - f ** 1.5) * (0.55 + 0.45 * min(1, f * 5))
                x0 = bx + lean * j
                for dx in range(-int(w2), int(w2) + 1):
                    col = ICE[4] if dx == 0 and j % 3 else (ICE[3] if dx < 0 else (ICE[1] if dx > 0 else ICE[2]))
                    if abs(dx) >= int(w2) and w2 > 1: col = ICE[0]
                    c.set(x0 + dx, by - j, col)
        # a sparkle climbs the tallest spike: bigger star at the peak of its trip, none on the last frame
        gy = 78 - round(i / (n - 1) * 56)
        arm = 5 if i in (2, 3) else (3 if i in (1, 4) else 1)
        c.rect(X - arm, gy, arm * 2 + 1, 1, WHITE); c.rect(X, gy - arm, 1, arm * 2 + 1, WHITE)
        c.rect(X - 1, gy - 1, 3, 3, WHITE)
        # frost pool at the base
        c.rect(4, 84, 56, 2, ICE[2]); c.rect(10, 86, 44, 1, ICE[1]); c.rect(18, 82, 28, 2, ICE[3])
        outline(c, ICE[0])
        fr.append(c)
    reg("evo_blizzard_crystal", "loop", strip(fr, "evo_blizzard_crystal.png"),
        "Ice crystal cluster standing on the rim of the ABSOLUTE ZERO area. Upright (never rotate). Base centre = (32,84). Loop frames 0-5 (a sparkle climbs the tallest spike).",
        loop=True, base_x=32, base_y=84)


def blizzard_glyph():
    n, S = 8, 224
    fr = []
    cx = cy = S // 2
    for i in range(n):
        c = C(S, S)
        rot = i / n * math.pi / 3     # 6-fold symmetric: 8 frames = 60 degrees = seamless
        a = 0.9
        c.ring(cx, cy, 108, 2, ICE[1], 0.9)
        c.ring(cx, cy, 90, 1, ICE[2], 0.7)
        # tick marks on the outer ring, turning
        for t in range(36):
            ang = -rot + t / 36 * math.tau
            L = 8 if t % 3 == 0 else 4
            c.line(pol(cx, cy, ang, 108 - L), pol(cx, cy, ang, 108), 2 if t % 3 == 0 else 1, ICE[3] if t % 3 == 0 else ICE[1])
        # hexagram of two triangles
        for tri in range(2):
            pts = [pol(cx, cy, rot + tri * math.pi / 3 + q * 2 * math.pi / 3, 92) for q in range(3)]
            for q in range(3):
                c.line(pts[q], pts[(q + 1) % 3], 2, ICE[2], 0.9)
        # big snowflake in the middle
        snowflake_big(c, cx, cy, 70, rot)
        c.disc(cx, cy, 8, ICE[3], 0.9, False); c.disc(cx, cy, 4, WHITE, 1.0, False)
        fr.append(c)
    reg("evo_blizzard_glyph", "loop", strip(fr, "evo_blizzard_glyph.png"),
        "Frost rune under the player (hexagram + snowflake + tick ring), 224x224, centre (112,112). Draw at ~50% alpha at 1x, below the player. Loop frames 0-7 (6-fold symmetric, seamless).",
        loop=True)


def snowflake_big(c, cx, cy, arm, rot):
    for t in range(6):
        ang = rot + t * math.pi / 3
        c.line((cx, cy), pol(cx, cy, ang, arm), 3, ICE[1])
        c.line((cx, cy), pol(cx, cy, ang, arm), 1, ICE[3])
        for f_, L in ((0.38, 0.30), (0.62, 0.22), (0.82, 0.14)):
            b = pol(cx, cy, ang, arm * f_)
            for sg in (-1, 1):
                e = pol(b[0], b[1], ang + sg * 0.85, arm * L)
                c.line(b, e, 2, ICE[2]); c.dot(e[0], e[1], 3, WHITE)
        c.dot(*pol(cx, cy, ang, arm), 5, WHITE)



# ====================================================================================================================
# BASE WEAPONS
# ====================================================================================================================
CYAN = [(8, 50, 90), (20, 140, 200), (70, 225, 255), (190, 250, 255), WHITE]
BRICK = [(60, 14, 10), (120, 34, 20), (170, 56, 30), (214, 92, 44), (255, 150, 70)]
KEYG = [(10, 70, 40), (30, 150, 80), (93, 240, 138), (168, 255, 196), WHITE]
PURP = [(40, 14, 90), (100, 50, 200), (180, 108, 255), (224, 194, 255), WHITE]
GOLDY = [(120, 80, 0), (210, 150, 10), (255, 210, 58), (255, 240, 150), WHITE]
STEEL = [(24, 30, 46), (74, 82, 112), (138, 147, 172), (190, 198, 220), WHITE]
RADAR = [(6, 70, 36), (20, 160, 80), (64, 255, 138), (180, 255, 210), WHITE]


def packet_bolt():
    n, W, H = 4, 64, 24
    fr = []
    for i in range(n):
        c = C(W, H); rnd = random.Random(i + 40)
        hx = 46
        for t in range(7):        # fading pixel trail, squares shrink with distance, shimmer per frame
            x = hx - 18 - t * 5 - (i % 2)
            sz = max(1, 5 - t // 2)
            y = 12 + rnd.choice((-3, -1, 0, 1, 3)) if t > 1 else 12
            c.dot(x, y, sz, CYAN[2] if t % 2 == 0 else CYAN[1])
        c.rect(hx - 16, 5, 18, 14, CYAN[0])                 # packet body: dark rim, cyan fill, header bar
        c.rect(hx - 15, 6, 16, 12, CYAN[1])
        c.rect(hx - 15, 6, 16, 3, CYAN[3])
        for r_ in range(3):                                 # three rows of "bits" that flip per frame
            for b in range(5):
                if rnd.random() > 0.45:
                    c.rect(hx - 13 + b * 3, 10 + r_ * 3, 2, 2, WHITE if (b + r_ + i) % 2 else CYAN[3])
        for k in range(6):                                  # arrow head
            c.rect(hx + 2 + k, 12 - (6 - k), 1, (6 - k) * 2, CYAN[3] if k < 4 else WHITE)
        c.rect(hx + 2, 11, 7, 2, WHITE)
        outline(c, CYAN[0])
        fr.append(c)
    reg("packet_bolt", "loop", strip(fr, "packet_bolt.png"),
        "PACKET GUN bolt: a data packet (header bar, flipping bits) with an arrow head and a shrinking pixel trail. Points right; rotate to the travel direction. Anchor = the packet centre (44,12). Loop frames 0-3.",
        loop=True)


def packet_hit():
    n, S = 5, 48
    fr = []
    for i in range(n):
        k = i / (n - 1); a = 1 - k * k
        c = C(S, S); rnd = random.Random(7)
        if i < 2: c.disc(24, 24, 9 - i * 3, WHITE, 1.0, False)
        h = 4 + round(16 * ease(k))
        c.rect(24 - h, 24 - h, h * 2, 2, CYAN[3], a); c.rect(24 - h, 24 + h - 2, h * 2, 2, CYAN[3], a)   # square shock frame
        c.rect(24 - h, 24 - h, 2, h * 2, CYAN[3], a); c.rect(24 + h - 2, 24 - h, 2, h * 2, CYAN[3], a)
        for j in range(10):                                  # flying bit-squares
            ang = j / 10 * math.tau + 0.3; d = (6 + 17 * ease(k)) * (0.6 + 0.4 * rnd.random())
            p = pol(24, 24, ang, d)
            c.rect(p[0] - 1, p[1] - 1, 3 if j % 2 else 2, 3 if j % 2 else 2, WHITE if j % 3 == 0 else CYAN[2], a)
        outline(c, CYAN[0], a)
        fr.append(c)
    reg("packet_hit", "one_shot", strip(fr, "packet_hit.png"),
        "PACKET GUN impact: square shock frame + flying bits. Centre (24,24). Frames 0-4, once.")


def brick_wall(c, cx, base_y, w, rows, phase, hot):
    """Courses of red bricks with glowing mortar; the top course is hottest."""
    bh = 7
    for r_ in range(rows):
        y = base_y - (r_ + 1) * bh
        off = 0 if r_ % 2 == 0 else 5
        heat = r_ / max(1, rows - 1)
        for bx in range(cx - w // 2 - off, cx + w // 2, 10):
            x0 = max(bx, cx - w // 2); x1 = min(bx + 10, cx + w // 2)
            if x1 - x0 < 2: continue
            body = BRICK[min(4, 1 + int(heat * 2 + hot))]
            c.rect(x0, y, x1 - x0, bh, body)
            c.rect(x0, y, x1 - x0, 1, BRICK[min(4, 2 + int(heat * 2 + hot))])
            c.rect(x0 + 2, y + 2, 2, 1, BRICK[0]); c.rect(x0 + 6, y + 4, 2, 1, BRICK[0])
            c.rect(x1 - 1, y, 1, bh, FIRE[1 + int((phase + bx) % 2)] if heat > 0.2 else BRICK[0])   # glowing mortar
        c.rect(cx - w // 2, y + bh - 1, w, 1, FIRE[2] if (phase + r_) % 2 else FIRE[1])


def firewall_brick():
    n, W, H = 8, 56, 72
    fr = []
    for i in range(n):
        c = C(W, H); ph = i / n * math.tau
        brick_wall(c, 28, 68, 44, 3, i, 0.4)
        flame(c, 28, 48, 34, 20 + 4 * math.sin(ph), ph, 1.0)
        flame(c, 14, 48, 14, 13 + 3 * math.sin(ph + 2), ph + 2, 1.0)
        flame(c, 43, 48, 14, 14 + 3 * math.sin(ph + 4), ph + 4, 1.0)
        rnd = random.Random(8)
        for j in range(4):
            q = ((i / n) + rnd.random()) % 1.0
            c.dot(10 + rnd.random() * 36, 44 - q * 40, 2, FIRE[3] if j % 2 else FIRE[4], 1.0 - q * 0.8)
        outline(c, FIRE[0])
        fr.append(c)
    reg("firewall_brick", "loop", strip(fr, "firewall_brick.png"),
        "FIREWALL wall segment: three courses of glowing red brick topped with flames. Upright; base centre (28,68). Stand them along the ring every ~34 px. Loop frames 0-7.",
        loop=True, base_x=28, base_y=68)


def key_head():
    n, S = 8, 48
    fr = []
    for i in range(n):
        c = C(S, S); cx = cy = 24
        pulse = 0.5 + 0.5 * math.sin(i / n * math.tau)
        c.disc(cx - 8, cy, 12 + round(2 * pulse), KEYG[0], 1.0)                  # glow halo (checker)
        c.ring(cx - 11, cy, 6, 3, KEYG[2]); c.ring(cx - 11, cy, 3, 1, KEYG[0])   # bow (ring head)
        c.rect(cx - 5, cy - 1, 20, 3, KEYG[2]); c.rect(cx - 5, cy - 1, 20, 1, KEYG[3])   # shaft
        for t, (tx, th) in enumerate(((cx + 6, 5), (cx + 10, 7), (cx + 14, 4))):   # teeth
            c.rect(tx, cy + 2, 3, th, KEYG[2]); c.rect(tx, cy + 2, 1, th, KEYG[3])
        c.rect(cx + 16, cy - 2, 3, 5, KEYG[3])
        gx = cx - 6 + (i * 3) % 24                                             # glint running along the shaft
        c.rect(gx - 1, cy - 1, 3, 1, WHITE); c.rect(gx, cy - 2, 1, 3, WHITE)
        for j in range(3):                                                      # hex bits drifting off the bow
            q = (i / n + j / 3) % 1.0
            c.rect(cx - 14 - q * 8, cy - 8 + j * 8 + math.sin(q * 6) * 2, 2, 2, KEYG[3], 1.0 - q)
        outline(c, KEYG[0])
        fr.append(c)
    reg("key_head", "loop", strip(fr, "key_head.png"),
        "ENCRYPTION KEYS: a glowing key (ring bow left, toothed shaft right). Points right; rotate to the orbit tangent. Anchor = middle of the shaft (24,24). Loop frames 0-7.",
        loop=True)


def quarantine_emblem():
    n, S = 8, 80
    fr = []
    for i in range(n):
        c = C(S, S); cx = cy = 40
        rot = i / n * (2 * math.pi / 3)                 # 3-fold symmetric: 8 frames = 120 degrees, a seamless turn
        c.ring(cx, cy, 36, 2, ICE[1]); c.ring(cx, cy, 30, 1, ICE[2])
        for q in range(3):                              # biohazard-style trefoil: three open rings
            ang = rot + q * 2 * math.pi / 3
            p = pol(cx, cy, ang, 14)
            c.ring(p[0], p[1], 11, 3, ICE[3]); c.ring(p[0], p[1], 8, 1, ICE[1])
            c.line(pol(cx, cy, ang + math.pi / 3, 6), pol(cx, cy, ang + math.pi / 3, 30), 2, ICE[2])
        c.disc(cx, cy, 4, WHITE, 1.0, False); c.ring(cx, cy, 6, 1, ICE[3])
        for t in range(24):                              # tick ring
            a_ = -rot + t / 24 * math.tau
            c.line(pol(cx, cy, a_, 33), pol(cx, cy, a_, 36), 1, ICE[3] if t % 3 == 0 else ICE[1])
        fr.append(c)
    reg("quarantine_emblem", "loop", strip(fr, "quarantine_emblem.png"),
        "QUARANTINE zone centre emblem: a turning trefoil in a tick ring (3-fold symmetric, seamless). 80x80, centre (40,40). Draw at 1x or 2x, ~80% alpha. Loop frames 0-7.",
        loop=True)


def quarantine_pylon():
    n, W, H = 6, 28, 56
    fr = []
    for i in range(n):
        c = C(W, H)
        c.rect(4, 48, 20, 6, STEEL[1]); c.rect(4, 48, 20, 1, STEEL[3]); c.rect(8, 44, 12, 4, STEEL[2])    # base
        c.rect(10, 12, 8, 32, STEEL[1]); c.rect(10, 12, 2, 32, STEEL[3]); c.rect(16, 12, 2, 32, STEEL[0])   # column
        ly = 40 - (i * 6) % 30                                                                           # light climbs the column
        c.rect(12, ly, 4, 4, ICE[3]); c.rect(13, ly + 1, 2, 2, WHITE)
        c.rect(6, 6, 16, 6, STEEL[2]); c.rect(6, 6, 16, 1, STEEL[3])                                       # cap
        lit = i % 3 != 2
        c.dot(14, 4, 6, ICE[3] if lit else ICE[1]); 
        if lit: c.dot(14, 4, 2, WHITE)
        outline(c, STEEL[0])
        fr.append(c)
    reg("quarantine_pylon", "loop", strip(fr, "quarantine_pylon.png"),
        "QUARANTINE containment pylon, stood on each of the 8 corners of the zone. Base centre (14,52). Loop frames 0-5.", loop=True, base_x=14, base_y=52)


def quarantine_drop():
    n, S = 8, 160
    fr = []
    for i in range(n):
        k = i / (n - 1); a = 1 - clamp((k - 0.5) / 0.5)
        c = C(S, S); cx = cy = 80
        h = round(60 * (1 - 0.8 * (1 - ease(min(1, k * 1.8)))))           # cage closes down onto the spot
        cl = ICE[3] if i < 5 else ICE[2]
        for bx in range(-h, h + 1, 12):
            c.rect(cx + bx, cy - h, 2, h * 2, cl, a)
        c.rect(cx - h, cy - h, h * 2 + 2, 3, WHITE, a); c.rect(cx - h, cy + h - 1, h * 2 + 2, 3, WHITE, a)
        c.rect(cx - h, cy - h, 3, h * 2, WHITE, a); c.rect(cx + h - 1, cy - h, 3, h * 2, WHITE, a)
        c.disc(cx, cy, round(h * 0.9), ICE[1], 0.5 * a)
        if i < 3: c.disc(cx, cy, 24 - i * 7, WHITE, 1.0, False)
        c.ring(cx, cy, 8 + 66 * ease(k), 3, ICE[3], a)
        outline(c, ICE[0], a)
        fr.append(c)
    reg("quarantine_drop", "one_shot", strip(fr, "quarantine_drop.png"),
        "QUARANTINE drop-in: a square cage slams down over the target spot with a flash and shock ring. 160x160, centre (80,80). Play once when a zone is placed. Frames 0-7.")


def mine_idle():
    n, S = 8, 40
    fr = []
    for i in range(n):
        c = C(S, S); cx, cy = 20, 22
        armed = i >= 4
        c.ellipse(cx, cy + 6, 14, 5, STEEL[0], 1.0, False)                      # shadow
        c.ellipse(cx, cy + 2, 13, 8, STEEL[1], 1.0, False); c.ellipse(cx, cy, 13, 8, STEEL[2], 1.0, False)
        c.ellipse(cx, cy, 10, 6, STEEL[1], 1.0, False); c.ellipse(cx, cy, 6, 4, STEEL[0], 1.0, False)
        c.rect(cx - 12, cy - 1, 24, 1, STEEL[3])
        for x in (-5, 0, 5):                                                    # pressure prongs
            c.rect(cx + x - 1, cy - 10, 3, 6, STEEL[2]); c.rect(cx + x - 1, cy - 12, 3, 3, GOLDY[2] if armed else GOLDY[0])
        on = (i % 2 == 0) if armed else (i == 0)
        c.dot(cx, cy, 5, (255, 59, 59) if on else (106, 26, 26)); 
        if on: c.dot(cx, cy, 2, WHITE)
        for sx in (-9, 9): c.rect(cx + sx - 1, cy + 2, 3, 3, STEEL[3])
        outline(c, STEEL[0])
        fr.append(c)
    reg("mine_idle", "loop", strip(fr, "mine_idle.png"),
        "LOGIC MINE. Frames 0-3 = arming (slow dim light), frames 4-7 = armed (fast red blink, lit prongs). Centre (20,22). Loop the half that matches the mine's state.", loop=True)


def mine_blast():
    n, S = 10, 192
    fr = []
    for i in range(n):
        k = i / (n - 1); a = 1 - clamp((k - 0.55) / 0.45); o = ease(min(1, k * 1.7))
        c = C(S, S); cx = cy = 96; rnd = random.Random(14)
        if i < 2: c.disc(cx, cy, 36 - i * 14, WHITE, 1.0, False)
        r = 76 * o
        c.disc(cx, cy, r, FIRE[0], 0.7 * a); c.disc(cx, cy, r * 0.8, FIRE[1], 0.85 * a)
        c.disc(cx, cy, r * 0.58, FIRE[2], 1.0 * a, False); c.disc(cx, cy, r * 0.34, FIRE[3], 1.0 * a, False)
        if i < 6: c.disc(cx, cy, r * 0.16, WHITE, 1.0, False)
        c.ring(cx, cy, r, 4, FIRE[4], a); c.ring(cx, cy, r + 5, 2, FIRE[2], a * 0.8)
        for j in range(16):                                               # debris chunks + sparks
            ang = j / 16 * math.tau + rnd.random() * 0.3; d = (20 + 70 * rnd.random()) * o
            p = pol(cx, cy, ang, d); sz = 4 if j % 3 == 0 else 3
            c.rect(p[0] - sz // 2, p[1] - sz // 2 + k * 6, sz, sz, STEEL[2] if j % 3 == 0 else (FIRE[4] if j % 2 else FIRE[3]), a)
        outline(c, FIRE[0], a)
        fr.append(c)
    reg("mine_blast", "one_shot", strip(fr, "mine_blast.png"),
        "LOGIC MINE explosion: white flash, layered fireball, ring, debris and late smoke. 192x192, centre (96,96), fireball radius ~76 at full size. Play once; scale 1x or 2x to the blast radius. Frames 0-9.")


def scanner_hub():
    n, S = 8, 64
    fr = []
    for i in range(n):
        c = C(S, S); cx = cy = 32
        c.ellipse(cx, cy, 30, 28, RADAR[0], 0.55)                                  # ground plate (dithered)
        c.ring(cx, cy, 28, 2, RADAR[1]); c.ring(cx, cy, 20, 1, RADAR[1], 0.8)
        for t in range(16):
            a_ = t / 16 * math.tau
            c.line(pol(cx, cy, a_, 25), pol(cx, cy, a_, 28), 1, RADAR[3] if t % 4 == 0 else RADAR[1])
        c.disc(cx, cy, 8, STEEL[1], 1.0, False); c.disc(cx, cy, 6, STEEL[2], 1.0, False); c.disc(cx, cy, 2, STEEL[0], 1.0, False)
        c.rect(cx + 6, cy - 2, 12, 5, STEEL[2]); c.rect(cx + 6, cy - 2, 12, 1, STEEL[3]); c.rect(cx + 17, cy - 4, 3, 9, STEEL[3])   # antenna arm (+x)
        led = i % 4 < 2
        c.dot(cx, cy, 3, (255, 70, 70) if led else (120, 30, 30))
        outline(c, RADAR[0])
        fr.append(c)
    reg("scanner_hub", "loop", strip(fr, "scanner_hub.png"),
        "SCANNER base: radar plate with an antenna arm pointing right (+x). Rotate to the sweep angle. Centre (32,32), blinking LED. Loop frames 0-7.", loop=True)


def scanner_blip():
    n, S = 6, 48
    fr = []
    for i in range(n):
        k = i / (n - 1); a = 1 - k * k
        c = C(S, S); cx = cy = 24
        c.ring(cx, cy, 4 + 18 * ease(k), 3, RADAR[2], a); c.ring(cx, cy, 2 + 9 * ease(k), 2, RADAR[3], a)
        d = 5 + 4 * k
        c.line((cx - d, cy - d), (cx + d, cy + d), 1, WHITE, a); c.line((cx - d, cy + d), (cx + d, cy - d), 1, WHITE, a)
        if i < 2: c.disc(cx, cy, 6 - i * 2, WHITE, 1.0, False)
        outline(c, RADAR[0], a)
        fr.append(c)
    reg("scanner_blip", "one_shot", strip(fr, "scanner_blip.png"),
        "SCANNER hit: a radar blip - expanding green ring + X lock. Centre (24,24). Frames 0-5, once.")


def backdoor_door():
    n, W, H = 8, 56, 80
    fr = []
    for i in range(n):
        c = C(W, H); cx = 28
        op = ease(min(1, (i + 1) / 4))                       # frames 0-3: the door swings open, 4-7: idle
        w = max(4, round(40 * op)); h = 64
        c.rect(cx - w // 2 - 3, 80 - 4 - h - 3, w + 6, h + 6, PURP[0])               # frame
        c.rect(cx - w // 2, 80 - 4 - h, w, h, (14, 6, 34))                           # dark void
        rnd = random.Random(i + 77)
        for y in range(80 - 4 - h, 80 - 4):                                            # glitch scanlines inside
            if rnd.random() > 0.72:
                c.rect(cx - w // 2, y, w, 1, PURP[2] if rnd.random() > 0.4 else PURP[1])
        for j in range(5):
            gx = cx - w // 2 + rnd.randrange(max(1, w - 6)); gy = 80 - 4 - h + rnd.randrange(h - 4)
            c.rect(gx, gy, 5, 2, GOLDY[2] if j % 2 else WHITE)
        c.rect(cx - w // 2 - 2, 80 - 4 - h - 2, w + 4, 2, PURP[3]); c.rect(cx - w // 2 - 2, 80 - 6, w + 4, 2, PURP[3])
        c.rect(cx - w // 2 - 2, 80 - 4 - h - 2, 2, h + 4, PURP[3]); c.rect(cx + w // 2, 80 - 4 - h - 2, 2, h + 4, PURP[3])
        if w > 20: c.dot(cx + w // 2 - 6, 48, 4, GOLDY[2]); c.dot(cx + w // 2 - 6, 48, 2, WHITE)
        c.ellipse(cx, 78, w // 2 + 4, 3, PURP[1], 1.0)                                  # threshold glow on the floor
        outline(c, PURP[0])
        fr.append(c)
    reg("backdoor_door", "loop", strip(fr, "backdoor_door.png"),
        "BACKDOOR: a glitching purple door. Frames 0-3 open (play once during the 0.25 s opening), 4-7 idle glitch loop. Base centre (28,76).", base_x=28, base_y=76)


def backdoor_boomerang():
    n, S = 8, 48
    fr = []
    for i in range(n):
        c = C(S, S); cx = cy = 24
        rot = i / n * math.pi                              # 2-fold symmetric: 8 frames = 180 degrees, seamless
        for blade in range(2):
            base = rot + blade * math.pi
            for s_ in range(0, 19):
                f = s_ / 18
                ang = base + 0.9 * f                       # curved blade
                p = pol(cx, cy, ang, 3 + 18 * f)
                wd = round(5 * (1 - f) + 1)
                c.dot(p[0], p[1], wd + 2, PURP[1]); 
            for s_ in range(0, 19):
                f = s_ / 18; ang = base + 0.9 * f
                p = pol(cx, cy, ang, 3 + 18 * f); wd = round(5 * (1 - f) + 1)
                c.dot(p[0], p[1], max(1, wd - 1), PURP[3] if s_ % 3 else WHITE)
            tip = pol(cx, cy, base + 0.9, 21); c.dot(tip[0], tip[1], 3, GOLDY[2])
        c.disc(cx, cy, 4, GOLDY[2], 1.0, False); c.dot(cx, cy, 2, WHITE)
        outline(c, PURP[0])
        fr.append(c)
    reg("backdoor_boomerang", "loop", strip(fr, "backdoor_boomerang.png"),
        "BACKDOOR boomerang: two curved purple blades with gold tips, spinning (2-fold symmetric, seamless). Centre (24,24). Loop frames 0-7 (play ~2 loops per 0.67 s for the fast spin).", loop=True)


def backdoor_slash():
    n, S = 5, 56
    fr = []
    for i in range(n):
        k = i / (n - 1); a = 1 - k * k
        c = C(S, S); cx = cy = 28; rnd = random.Random(3)
        L = 6 + round(20 * ease(min(1, k * 2)))
        for sgn in (-1, 1):
            c.line((cx - L, cy - sgn * L), (cx + L, cy + sgn * L), 4 if k < .5 else 3, PURP[2], a)
            c.line((cx - L, cy - sgn * L), (cx + L, cy + sgn * L), 2, WHITE, a)
        for j in range(6):                                  # glitch slices: offset horizontal bars
            y = cy - 14 + rnd.randrange(28); x = cx - 14 + rnd.randrange(8)
            c.rect(x, y, 10 + rnd.randrange(10), 2, GOLDY[2] if j % 2 else PURP[3], a)
        outline(c, PURP[0], a)
        fr.append(c)
    reg("backdoor_slash", "one_shot", strip(fr, "backdoor_slash.png"),
        "BACKDOOR hit: a glitching X-slash with offset slice bars. Centre (28,28). Frames 0-4, once.")


def ping_hit():
    n, S = 6, 64
    fr = []
    for i in range(n):
        k = i / (n - 1); a = 1 - k * k
        c = C(S, S); cx = cy = 32
        for q in range(3):                                   # echo rings: nested squares rippling out (ICMP echo)
            kk = clamp(k * 1.5 - q * 0.2)
            if kk <= 0: continue
            h = 3 + round(26 * ease(kk))
            col = WHITE if q == 0 else (CYAN[3] if q == 1 else CYAN[2])
            aa = a * (1 - q * 0.25)
            c.rect(cx - h, cy - h, h * 2, 2, col, aa); c.rect(cx - h, cy + h - 2, h * 2, 2, col, aa)
            c.rect(cx - h, cy - h, 2, h * 2, col, aa); c.rect(cx + h - 2, cy - h, 2, h * 2, col, aa)
        if i < 3: c.disc(cx, cy, 8 - i * 2, WHITE, 1.0, False)
        c.rect(cx - 1, cy - 8, 3, 10, CYAN[3], a); c.rect(cx - 1, cy + 4, 3, 3, CYAN[3], a)       # "!" glyph
        outline(c, CYAN[0], a)
        fr.append(c)
    reg("ping_hit", "one_shot", strip(fr, "ping_hit.png"),
        "PING.EXE hit: nested square echo rings with a '!' flash. Centre (32,32). Frames 0-5, once.")


for f in (packet_bolt, packet_hit, firewall_brick, key_head, quarantine_emblem, quarantine_pylon, quarantine_drop, mine_idle, mine_blast, scanner_hub,
          scanner_blip, backdoor_door, backdoor_boomerang, backdoor_slash, ping_hit, railgun_beam, railgun_hit, inferno_flame, inferno_pillar, tesla_strike, tesla_coil, blizzard_flake, blizzard_crystal, blizzard_glyph):
    f()

json.dump(MANIFEST, open(os.path.join(OUT, "manifest.json"), "w"), indent=2)

# contact sheet (dark bg, first frames) for review
from PIL import ImageDraw
rows = [(nm, Image.open(os.path.join(OUT, m["file"]))) for nm, m in MANIFEST.items()]
sheet = Image.new("RGBA", (1700, sum(im.height + 16 for _, im in rows)), (14, 16, 24, 255))
y = 0
for nm, im in rows:
    d = ImageDraw.Draw(sheet); d.text((2, y), nm.upper(), fill=(255, 255, 255, 255)); y += 12
    sheet.alpha_composite(im, (0, y)); y += im.height + 4
sheet.save(os.path.join(OUT, "_contact_sheet.png"))
print("ok", len(MANIFEST))
