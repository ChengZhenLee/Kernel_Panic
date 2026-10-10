#!/usr/bin/env python3
"""Kernel Panic: renders the ability + item sound effects as stereo 16-bit 44.1 kHz WAVs.

Pure numpy (no scipy). Each sound is built from layered, properly enveloped parts (FM bells, resonant filtered
noise, inharmonic metal partials, pitch sweeps, transient clicks) and finished with a short synthetic-room reverb
and soft clipping, so they are far richer than the in-engine tone synth in scripts/sfx.gd.

usage: python3 tools/gen_sfx.py [out_dir]     (default: assets/audio/sfx)
"""
import os
import sys
import wave

import numpy as np

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "sfx")


# ---------------------------------------------------------------- primitives
def n_of(d):
    return int(round(d * SR))


def tt(d):
    return np.arange(n_of(d)) / SR


def rng_for(name):
    return np.random.default_rng(abs(hash(name)) % (2 ** 32) if False else sum(ord(c) * (i + 7) for i, c in enumerate(name)))


def expd(d, tau, attack=0.002):
    """Exponential decay envelope with a short linear attack."""
    t = tt(d)
    e = np.exp(-t / tau)
    a = max(1, n_of(attack))
    e[:a] *= np.linspace(0, 1, a)
    return e


def swell(d, rise=0.5, fall=0.3):
    t = tt(d)
    e = np.minimum(1.0, t / max(rise, 1e-4)) * np.minimum(1.0, (d - t) / max(fall, 1e-4))
    return np.clip(e, 0, 1) ** 1.5


def sweep(f0, f1, d, curve="exp", shape="sine", vib=0.0, vib_hz=6.0):
    """Oscillator whose frequency glides f0 -> f1 over d seconds."""
    t = tt(d)
    k = t / d
    if curve == "exp":
        f = f0 * (f1 / f0) ** k
    else:
        f = f0 + (f1 - f0) * k
    if vib:
        f = f * (1 + vib * np.sin(2 * np.pi * vib_hz * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return osc(ph, shape)


def osc(ph, shape="sine"):
    if shape == "sine":
        return np.sin(ph)
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if shape == "square":
        return np.sign(np.sin(ph))
    if shape == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1.0) - 1) - 1
    raise ValueError(shape)


def tone(f, d, shape="sine"):
    return osc(2 * np.pi * f * tt(d), shape)


def fm_bell(f, d, tau, ratio=3.5, index=3.0, itau=None, attack=0.002, amp=1.0):
    """FM bell: modulation index decays faster than the carrier, giving a bright strike that settles into a pure ring."""
    t = tt(d)
    itau = itau or tau * 0.4
    idx = index * np.exp(-t / itau)
    s = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * ratio * t))
    return amp * s * expd(d, tau, attack)


def metal(f0, d, tau, ratios=(1.0, 2.76, 5.40, 8.93, 13.34), amps=(1.0, 0.7, 0.5, 0.3, 0.18), taus=None, attack=0.001):
    """Inharmonic partials = struck metal / glass."""
    out = np.zeros(n_of(d))
    t = tt(d)
    for i, (r, a) in enumerate(zip(ratios, amps)):
        tau_i = tau * (taus[i] if taus else 1.0 / (1 + 0.55 * i))
        out += a * np.sin(2 * np.pi * f0 * r * t + i * 1.3) * np.exp(-t / tau_i)
    a = max(1, n_of(attack))
    out[:a] *= np.linspace(0, 1, a)
    return out


def noise(d, rng):
    return rng.uniform(-1, 1, n_of(d))


def svf(x, fc, q=0.7, mode="lp"):
    """Trapezoidal (TPT) state-variable filter: unconditionally stable, cutoff may vary per sample.
    q ~ resonance (higher = narrower); the band-pass output is peak-normalised."""
    n = len(x)
    fc = np.broadcast_to(np.asarray(fc, dtype=float), (n,))
    g = np.tan(np.pi * np.clip(fc, 20, 16000) / SR)
    k = 1.0 / q
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    ic1 = ic2 = 0.0
    out = np.empty(n)
    xs = x.tolist()
    a1l, a2l, a3l = a1.tolist(), a2.tolist(), a3.tolist()
    for i in range(n):
        v3 = xs[i] - ic2
        v1 = a1l[i] * ic1 + a2l[i] * v3
        v2 = ic2 + a2l[i] * ic1 + a3l[i] * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        if mode == "lp":
            out[i] = v2
        elif mode == "bp":
            out[i] = v1 * k
        elif mode == "hp":
            out[i] = xs[i] - k * v1 - v2
        else:
            out[i] = xs[i] - k * v1
    return out


def clicks(d, times, rng, amp=1.0, tau=0.0025, hp=True):
    """Short transient ticks at the given times (seconds)."""
    out = np.zeros(n_of(d))
    for tm in times:
        i = n_of(tm)
        L = n_of(tau * 6)
        if i >= len(out):
            continue
        seg = rng.uniform(-1, 1, L) * np.exp(-np.arange(L) / (tau * SR))
        if hp:
            seg = np.diff(seg, prepend=0)
        L = min(L, len(out) - i)
        out[i:i + L] += amp * seg[:L]
    return out


def place(buf, x, at, gain=1.0):
    """Mix x into buf starting at `at` seconds (buf grows if needed)."""
    i = n_of(at)
    need = i + len(x)
    if need > len(buf):
        buf = np.concatenate([buf, np.zeros(need - len(buf))])
    buf[i:i + len(x)] += gain * x
    return buf


def pad(x, d):
    n = n_of(d)
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n] if len(x) < n else x


def mix(*parts, d=None):
    n = max(len(p) for p in parts) if d is None else n_of(d)
    out = np.zeros(n)
    for p in parts:
        out[:min(n, len(p))] += p[:n]
    return out


def delay_taps(x, taps, lp=None):
    """Echo: [(seconds, gain), ...] each repeat optionally darker."""
    n = len(x) + n_of(max(t for t, _ in taps))
    out = np.zeros(n)
    out[:len(x)] += x
    for k, (tm, g) in enumerate(taps):
        y = x
        if lp:
            y = svf(x, lp / (1 + 0.5 * k), 0.7, "lp")
        out = place(out, y, tm, g)
    return out


def haas_pair(x, rng, width=0.012):
    return x, np.concatenate([np.zeros(n_of(width)), x])[:len(x)]


def room(x, rng, tail=0.5, wet=0.25, bright=0.5, pre=0.012):
    """Stereo synthetic room: convolve with decaying noise impulse responses (different per ear)."""
    x = x.copy()
    f = min(len(x) // 2, n_of(0.05))   # the dry part always fades out, so nothing is cut off with a click
    x[-f:] *= np.linspace(1, 0, f) ** 2
    n_ir = n_of(tail)
    outs = []
    for ch in range(2):
        ir = rng.normal(0, 1, n_ir) * np.exp(-np.arange(n_ir) / (tail * SR / 5.5))
        ir = svf(ir, 1500 + bright * 6000, 0.6, "lp")
        ir[:n_of(pre)] = 0
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
        total = len(x) + n_ir
        nfft = 1 << (total - 1).bit_length()
        y = np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[:total]
        outs.append(y)
    L = np.zeros(len(outs[0]))
    L[:len(x)] += x
    R = L.copy()
    L += wet * outs[0] * 3.0
    R += wet * outs[1] * 3.0
    return L, R


def finish(L, R, peak=0.82, drive=1.0, fade=0.012, tail_trim=True):
    """Soft-clip, trim silence, fade, normalise and return int16 stereo array."""
    st = np.stack([L, R], axis=1)
    if drive != 1.0:
        st = np.tanh(st * drive)
    env = np.max(np.abs(st), axis=1)
    if tail_trim:
        idx = np.where(env > 0.006 * max(env.max(), 1e-9))[0]
        st = st[: (idx[-1] + n_of(0.03)) if len(idx) else len(st)]
    f = min(n_of(fade), len(st) // 2)
    st[-f:] *= np.linspace(1, 0, f)[:, None]
    st[:n_of(0.0006)] *= np.linspace(0, 1, n_of(0.0006))[:, None]
    st = st / (np.max(np.abs(st)) + 1e-9) * peak
    return (st * 32767).astype(np.int16)


def save(name, st):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(st.tobytes())
    print("  %-26s %5.2fs  %4d KB" % (name, len(st) / SR, os.path.getsize(path) // 1024))


def render(name, builder):
    r = rng_for(name)
    L, R = builder(r)
    save(name, finish(L, R, **getattr(builder, "opts", {})))


def opts(**kw):
    def deco(fn):
        fn.opts = kw
        return fn
    return deco


# ---------------------------------------------------------------- ABILITIES
@opts(drive=1.4, peak=0.9)
def ab_railstrike(r):
    """Charged coil discharge: rail snap + ringing steel + a deep sub thump, then the beam's descending whine."""
    d = 1.1
    snap = clicks(d, [0.0], r, 2.2, 0.0018) * 0.9
    crack = svf(noise(0.09, r), 5200, 1.2, "hp") * expd(0.09, 0.02, 0.0005)
    beam = sweep(5200, 240, 0.34, "exp", "saw") * expd(0.34, 0.11, 0.001)
    beam = svf(beam, np.linspace(7000, 800, len(beam)), 1.8, "bp") * 1.6
    zap = sweep(2400, 620, 0.2, "exp", "square") * expd(0.2, 0.05) * 0.18
    steel = metal(880, d, 0.5, (1, 2.32, 4.25, 6.63, 9.38), (1, .55, .4, .22, .12)) * 0.45
    sub = sweep(150, 40, 0.5, "exp") * expd(0.5, 0.17, 0.003) * 1.4
    body = svf(noise(0.35, r), np.linspace(1800, 160, n_of(0.35)), 0.8, "lp") * expd(0.35, 0.1) * 1.3
    dry = mix(snap, crack, beam, zap, steel, sub, body, d=d)
    return room(dry, r, 0.55, 0.22, 0.7)


@opts(drive=1.3)
def ab_wildfire(r):
    """Gas-ignition fwoomph, a roaring flame bed and popping embers."""
    d = 1.7
    n = n_of(d)
    swoosh = svf(noise(d, r), np.linspace(250, 3200, n) * (1 - 0.6 * np.minimum(1, tt(d) / 1.2)) + 300, 1.1, "bp")
    swoosh *= (np.minimum(1, tt(d) / 0.07) * np.exp(-tt(d) / 0.55)) * 2.0
    roar = svf(noise(d, r), 700 + 500 * np.sin(2 * np.pi * 3.1 * tt(d)), 0.9, "lp")
    flick = 0.65 + 0.35 * svf(noise(d, r), 22, 1.2, "lp") * 40
    roar *= np.clip(flick, 0.2, 1.3) * (np.minimum(1, tt(d) / 0.1) * np.exp(-tt(d) / 0.8)) * 1.2
    boom = sweep(95, 34, 0.7, "exp") * expd(0.7, 0.22, 0.004) * 1.6
    boom_n = svf(noise(0.5, r), np.linspace(1400, 90, n_of(0.5)), 0.7, "lp") * expd(0.5, 0.12) * 1.6
    pops = np.zeros(n)
    for _ in range(46):
        tm = r.exponential(0.5) + 0.05
        if tm > d - 0.15:
            continue
        L = n_of(r.uniform(0.004, 0.012))
        pop = svf(r.uniform(-1, 1, L), r.uniform(900, 4800), 3.0, "bp") * np.exp(-np.arange(L) / (L * 0.25))
        pops = place(pops, pop, tm, r.uniform(0.3, 1.0) * np.exp(-tm / 0.9) * 1.5)
    dry = mix(swoosh, roar, boom, boom_n, pops[:n], d=d)
    return room(dry, r, 0.6, 0.17, 0.45)


@opts(drive=1.1)
def ab_deepfreeze(r):
    """Flash-freeze: a glassy crack, cascading crystal growth pings, an airy shimmer and a cold sub drop."""
    d = 1.6
    n = n_of(d)
    crack = svf(noise(0.12, r), 3800, 1.4, "hp") * expd(0.12, 0.018, 0.0004) * 1.2
    low_crack = svf(noise(0.18, r), np.linspace(2200, 200, n_of(0.18)), 0.8, "lp") * expd(0.18, 0.045) * 1.4
    pings = np.zeros(n)
    base = [1568, 1760, 2093, 2349, 2637, 3136, 3520, 4186]
    for i in range(26):
        tm = 0.015 + (i / 26) ** 1.5 * 0.55 + r.uniform(0, 0.02)
        f = r.choice(base) * r.choice([1, 1, 2, 0.5, 1.498])
        ping = metal(f, 0.9, r.uniform(0.18, 0.5), (1, 2.41, 4.07), (1, .35, .15)) * 0.34
        pings = place(pings, ping, tm, r.uniform(0.45, 1.0) * (1 - i / 60))
    shimmer = svf(noise(d, r), 6800, 6.0, "bp") * (1 + 0.8 * np.sin(2 * np.pi * 11 * tt(d))) * 0.5
    shimmer *= np.minimum(1, tt(d) / 0.25) * np.exp(-tt(d) / 0.55) * 1.3
    drop = sweep(210, 52, 0.8, "exp") * expd(0.8, 0.28, 0.004) * 1.1
    chill = (fm_bell(523, 1.4, 0.7, 2.0, 1.4, 0.2) + fm_bell(784, 1.4, 0.6, 2.0, 1.4, 0.2) * 0.8) * 0.42
    dry = mix(crack, low_crack, pings[:n], shimmer, drop, chill, d=d)
    return room(dry, r, 1.0, 0.3, 0.9, 0.02)


def _thunder(seed_name, size):
    @opts(drive=1.5, peak=0.88)
    def build(r):
        d = 0.75 + 0.35 * size
        n = n_of(d)
        crack = clicks(d, [0.0], r, 2.0, 0.0012) * 0.8
        arc = svf(noise(0.14, r), np.linspace(9000, 1800, n_of(0.14)), 1.2, "hp") * expd(0.14, 0.032, 0.0004) * 1.4
        zap = sweep(r.uniform(5200, 7200), r.uniform(240, 420), 0.1, "exp", "saw") * expd(0.1, 0.035, 0.0005) * 0.5
        rumble = svf(noise(d, r), 170 + 130 * size, 0.8, "lp")
        rumble *= (1 + 0.6 * np.sin(2 * np.pi * r.uniform(6, 11) * tt(d))) * expd(d, 0.2 + 0.17 * size, 0.006) * 1.9
        sub = sweep(95, 38, 0.45, "exp") * expd(0.45, 0.15, 0.004) * (0.9 + 0.6 * size)
        crackle = clicks(d, np.sort(r.exponential(0.12, 12) + 0.04), r, 0.7, 0.002) * np.exp(-tt(d) / 0.3)
        dry = mix(crack, arc, zap, rumble, sub, crackle, d=d)
        return room(dry, r, 0.7, 0.22, 0.45)
    build.sound_name = "ab_" + seed_name
    return build


ab_thunder_0 = _thunder("thunder_0", 0.0)
ab_thunder_1 = _thunder("thunder_1", 0.5)
ab_thunder_2 = _thunder("thunder_2", 1.0)


@opts(drive=1.25)
def ab_thunderstorm(r):
    """The cast: a huge rolling clap and a wash of rain-on-metal static as the storm gathers."""
    d = 1.5
    n = n_of(d)
    clap = clicks(d, [0.0, 0.035], r, 2.0, 0.0015) * 0.7
    arc = svf(noise(0.25, r), np.linspace(8000, 1500, n_of(0.25)), 1.0, "hp") * expd(0.25, 0.06, 0.0004) * 1.5
    roll = svf(noise(d, r), 220, 0.8, "lp") * (1 + 0.55 * np.sin(2 * np.pi * 5.5 * tt(d))) * expd(d, 0.55, 0.01) * 2.0
    sub = sweep(90, 32, 0.9, "exp") * expd(0.9, 0.3, 0.006) * 1.4
    rain = svf(noise(d, r), 5200, 1.5, "bp") * np.minimum(1, tt(d) / 0.3) * np.exp(-tt(d) / 0.9) * 0.28
    sparks = clicks(d, np.sort(r.uniform(0.05, 1.2, 38)), r, 0.8, 0.0018) * np.exp(-tt(d) / 0.7)
    hum = sweep(120, 440, 1.2, "exp", "saw") * swell(1.2, 0.9, 0.3) * 0.07
    hum = svf(hum, 1500, 0.8, "lp")
    dry = mix(clap, arc, roll, sub, rain[:n], sparks, pad(hum, d), d=d)
    return room(dry, r, 0.9, 0.24, 0.5)


@opts(drive=1.15)
def ab_pause(r):
    """Time stops: a descending record-stop whirr, a deep bronze clock-bell and two muffled ticks."""
    d = 1.9
    n = n_of(d)
    whirr = sweep(1700, 50, 0.7, "exp", "saw") * expd(0.7, 0.28, 0.003) * 0.3
    whirr = svf(whirr, np.linspace(5200, 160, len(whirr)), 1.5, "lp")
    wind = svf(noise(0.6, r), np.linspace(4800, 300, n_of(0.6)), 2.2, "bp") * expd(0.6, 0.2) * 1.3
    thud = sweep(120, 48, 0.4, "exp") * expd(0.4, 0.13, 0.003) * 1.3
    bell = metal(146.8, d, 1.1, (1, 2.0, 2.98, 4.16, 5.43, 6.8), (1, .8, .55, .4, .22, .12), (1, .8, .7, .55, .4, .3)) * 0.5
    ring = fm_bell(587, d, 0.9, 2.76, 1.6, 0.25) * 0.28
    ticks = np.zeros(n)
    for tm, f, g in ((0.55, 1100, 0.55), (0.85, 880, 0.4)):
        tk = (fm_bell(f, 0.12, 0.03, 4.2, 2.0, 0.01) + clicks(0.12, [0.0], r, 1.0, 0.002) * 0.5)
        ticks = place(ticks, tk, tm, g)
    dry = mix(whirr, wind, thud, bell, ring, ticks[:n], d=d)
    return room(dry, r, 1.2, 0.3, 0.4, 0.02)


@opts(drive=1.05)
def ab_restore(r):
    """System restore: a warm swelling pad, a rising harp-like arpeggio and a sparkle of data motes."""
    d = 1.9
    n = n_of(d)
    notes = [392.0, 493.9, 587.3, 784.0, 987.8, 1174.7]
    arp = np.zeros(n)
    for i, f in enumerate(notes):
        tm = 0.02 + i * 0.075
        pl = (fm_bell(f, 1.2, 0.5, 2.0, 1.1, 0.12) * 0.55 + tone(f * 2, 1.2) * expd(1.2, 0.2) * 0.18)
        arp = place(arp, pl, tm, 0.7 + 0.06 * i)
    padw = np.zeros(n)
    for f, g in ((196, 0.5), (293.7, 0.4), (392, 0.45), (493.9, 0.3)):
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * tt(d) + f)
        padw += g * np.sin(2 * np.pi * f * np.cumsum(vib) / SR) * swell(d, 0.35, 1.3)
    padw = svf(padw, 1800, 0.8, "lp") * 0.22
    sparkle = np.zeros(n)
    for _ in range(18):
        tm = r.uniform(0.1, 1.2)
        f = r.choice([2093, 2349, 2637, 3136, 3951])
        sparkle = place(sparkle, fm_bell(f, 0.4, 0.09, 3.0, 1.0, 0.03) * 0.2, tm, r.uniform(0.3, 0.8) * np.exp(-tm / 1.0))
    heartbeat = (sweep(95, 55, 0.18, "exp") * expd(0.18, 0.06)) * 0.8
    dry = mix(arp, padw, sparkle[:n], pad(heartbeat, d), d=d)
    return room(dry, r, 1.3, 0.32, 0.8, 0.02)


@opts(drive=1.35)
def ab_overclock(r):
    """Overclock: a heavy relay clunk, a gear/turbine spin-up with accelerating ratchet and a high stable whine."""
    d = 1.4
    n = n_of(d)
    clunk = mix(sweep(190, 60, 0.18, "exp", "square") * expd(0.18, 0.05) * 0.4, sweep(110, 42, 0.3, "exp") * expd(0.3, 0.1) * 1.1, clicks(0.1, [0.0], r, 1.8, 0.002), d=0.3)
    spin = sweep(160, 2100, 0.75, "exp", "saw") * np.minimum(1, tt(0.75) / 0.05) * expd(0.75, 1.5, 0.01) * 0.4
    spin = svf(spin, np.linspace(500, 5600, len(spin)), 1.6, "lp")
    whine = sweep(2100, 2350, 0.8, "lin", "sine", 0.01, 17) * np.concatenate([np.zeros(n_of(0.5)), expd(0.8, 0.3, 0.1)])[:n_of(0.8)] * 0.12
    # ratchet: tooth ticks whose spacing shrinks as the rotor speeds up
    tm, gap, times = 0.02, 0.07, []
    while tm < 0.8:
        times.append(tm)
        tm += gap
        gap = max(0.012, gap * 0.85)
    ratchet = clicks(d, times, r, 1.0, 0.0022)
    ratchet = svf(ratchet, 3400, 1.0, "bp") * 1.8
    gear = metal(520, 0.4, 0.12, (1, 2.8, 5.1), (1, .5, .3)) * expd(0.4, 0.1) * 0.3
    dry = mix(pad(clunk, d), pad(spin, d), pad(whine, d), ratchet, pad(gear, d), d=d)
    return room(dry, r, 0.4, 0.14, 0.7)


@opts(drive=1.1)
def ab_phase(r):
    """Phase shift: a quick up-then-down 'zwoop' dematerialise, a ghostly swept noise veil and a hollow ping."""
    d = 1.2
    n = n_of(d)
    up = sweep(240, 2800, 0.14, "exp") * expd(0.14, 0.2) * 0.4
    down = sweep(2800, 150, 0.32, "exp") * expd(0.32, 0.14, 0.004) * 0.7
    z = np.concatenate([up, down])
    veil = svf(noise(0.7, r), np.concatenate([np.geomspace(600, 6500, n_of(0.25)), np.geomspace(6500, 280, n_of(0.45))]), 4.0, "bp") * 1.7
    veil *= swell(0.7, 0.2, 0.4)
    # flanged copy: a slowly modulated short delay gives the "smeared through walls" feel
    zf = pad(z, d)
    mod = (0.0025 + 0.002 * np.sin(2 * np.pi * 7 * tt(d))) * SR
    idx = np.clip(np.arange(n) - mod, 0, n - 1)
    flange = np.interp(idx, np.arange(n), zf)
    ghost = (fm_bell(1568, 1.0, 0.45, 1.5, 2.0, 0.1) * 0.22) * np.sin(2 * np.pi * 4.5 * tt(1.0)) ** 2
    ghost2 = fm_bell(2349, 0.9, 0.3, 1.5, 1.5, 0.1) * 0.12
    sub = sweep(130, 70, 0.25, "exp") * expd(0.25, 0.09) * 0.6
    dry = mix(zf * 0.8 + flange * 0.6, pad(veil, d), pad(ghost, d), pad(ghost2, d), pad(sub, d), d=d)
    return room(dry, r, 1.0, 0.34, 0.8, 0.015)


@opts(drive=1.6, peak=0.92)
def ab_purge(r):
    """System purge: the biggest sound in the game. Sub drop, a white-hot noise detonation sweeping down, a metal-shatter
    crack and a bright gold shockwave shimmer."""
    d = 2.2
    n = n_of(d)
    sub = sweep(130, 24, 1.1, "exp") * expd(1.1, 0.4, 0.004) * 1.8
    sub2 = sweep(65, 30, 1.0, "exp", "tri") * expd(1.0, 0.35, 0.006) * 0.8
    blast = svf(noise(0.9, r), np.geomspace(9000, 120, n_of(0.9)), 0.8, "lp") * expd(0.9, 0.22, 0.0015) * 2.4
    crack = clicks(d, [0.0], r, 3.0, 0.0015)
    shatter = svf(noise(0.5, r), 4200, 1.3, "hp") * expd(0.5, 0.09, 0.0005) * 1.0
    metalhit = metal(310, 1.2, 0.5, (1, 2.4, 3.9, 6.2, 9.1), (1, .7, .55, .35, .2)) * 0.5
    shock = sweep(180, 2400, 0.55, "exp", "saw") * expd(0.55, 0.22, 0.002) * 0.13
    shock = svf(shock, 2800, 0.9, "lp")
    gold = np.zeros(n)
    for i, f in enumerate([523.3, 659.3, 784.0, 1046.5, 1568.0]):
        gold = place(gold, fm_bell(f, 1.6, 0.8, 2.0, 1.4, 0.25) * 0.33, 0.12 + i * 0.045, 0.9)
    debris = clicks(d, np.sort(r.exponential(0.3, 60) + 0.08), r, 0.8, 0.002) * np.exp(-tt(d) / 0.5)
    dry = mix(sub, sub2, blast, crack, shatter, pad(metalhit, d), pad(shock, d), gold, debris, d=d)
    return room(dry, r, 1.4, 0.3, 0.6, 0.02)


@opts(drive=1.3)
def ab_lockdown(r):
    """Containment: servo clamp down-sweep, three massive bolt slams with a metallic ring and an electromagnetic hum."""
    d = 1.5
    n = n_of(d)
    servo = sweep(900, 95, 0.35, "exp", "saw") * expd(0.35, 0.16, 0.004) * 0.35
    servo = svf(servo, np.linspace(3200, 220, len(servo)), 2.0, "lp")
    out = pad(servo, d)
    for i, (tm, f, g) in enumerate(((0.04, 170, 1.0), (0.16, 145, 0.85), (0.29, 118, 1.0))):
        slam = metal(f, 0.9, 0.38, (1, 1.59, 2.14, 2.65, 3.51, 4.8), (1, .8, .7, .45, .3, .2)) * 0.45
        thud = sweep(120, 38, 0.3, "exp") * expd(0.3, 0.09, 0.002) * 1.1
        tk = clicks(0.08, [0.0], r, 2.2, 0.0015)
        out = place(out, mix(slam, thud, pad(tk, 0.9), d=0.9), tm, g)
    hum = (tone(60, d) * 0.4 + tone(120, d) * 0.5 + tone(180, d, "tri") * 0.2) * swell(d, 0.25, 0.9) * 0.22 * np.exp(-tt(d) / 0.9)
    buzz = svf(noise(0.5, r), 1800, 3.0, "bp") * (1 + np.sin(2 * np.pi * 100 * tt(0.5))) * swell(0.5, 0.05, 0.4) * 0.22
    lock = fm_bell(740, 0.6, 0.12, 5.0, 3.0, 0.03) * 0.3
    out = place(out, lock, 0.42, 0.8)
    dry = mix(out[:n], hum, pad(buzz, d), d=d)
    return room(dry, r, 0.7, 0.22, 0.55)


@opts(drive=1.1)
def ab_deepscan(r):
    """Sonar sweep: a swelling radar sweep, a crisp round ping with fading echoes and a digital 'target acquired' trill."""
    d = 2.0
    n = n_of(d)
    sweep_up = sweep(300, 2600, 0.5, "exp") * swell(0.5, 0.35, 0.12) * 0.22
    ping = (np.sin(2 * np.pi * 1320 * tt(0.9) + 0.6 * np.sin(2 * np.pi * 1320 * 2 * tt(0.9)) * np.exp(-tt(0.9) / 0.06))
            * expd(0.9, 0.22, 0.003)) * 0.8
    ping = mix(ping, fm_bell(2640, 0.6, 0.12, 1.0, 0.8, 0.03) * 0.3, d=0.9)
    echo = delay_taps(ping, [(0.22, 0.5), (0.46, 0.28), (0.72, 0.15)], lp=4200)
    out = place(np.zeros(n), echo, 0.45, 1.0)
    out = place(out, sweep_up, 0.0, 1.0)
    for i, f in enumerate((1760, 2349, 3136, 2349, 3520)):
        blip = tone(f, 0.05, "square") * expd(0.05, 0.02, 0.002)
        blip = svf(blip, 5200, 0.9, "lp") * 0.18
        out = place(out, blip, 1.05 + i * 0.065, 1.0)
    base = mix(fm_bell(262, 1.0, 0.3, 2.0, 1.0, 0.1) * 0.3, sweep(120, 55, 0.3, "exp") * expd(0.3, 0.1) * 0.5)
    out = place(out, base, 0.42, 1.0)
    dry = out[:n]
    return room(dry, r, 1.3, 0.34, 0.75, 0.02)


@opts(drive=1.05)
def super_sting(r):
    """Gold sparkle layered on a SUPER cast: a bright rising fifth stack with glitter and an airy whoosh."""
    d = 1.5
    n = n_of(d)
    out = np.zeros(n)
    for i, f in enumerate([1046.5, 1568.0, 2093.0, 3136.0, 4186.0]):
        out = place(out, fm_bell(f, 1.2, 0.5, 3.5, 1.5, 0.15) * 0.28, 0.02 + i * 0.05, 1.0 - i * 0.08)
    for _ in range(26):
        tm = r.uniform(0.05, 1.0)
        out = place(out, fm_bell(r.choice([2637, 3136, 3951, 4699, 5588]), 0.3, 0.07, 3.0, 1.0, 0.03) * 0.16, tm, np.exp(-tm / 0.8))
    wh = svf(noise(0.5, r), np.geomspace(500, 7000, n_of(0.5)), 3.0, "bp") * swell(0.5, 0.35, 0.15) * 0.8
    out = place(out, wh, 0.0, 0.5)
    return room(out[:n], r, 1.1, 0.3, 0.9, 0.015)


# ---------------------------------------------------------------- ITEMS
@opts(drive=1.15)
def item_totem(r):
    """Totem plants: a heavy wooden-stone thump, a resonant marimba tone and a low chanting hum swelling on top."""
    d = 1.4
    n = n_of(d)
    thump = sweep(190, 62, 0.28, "exp") * expd(0.28, 0.09, 0.002) * 1.4
    knock = svf(noise(0.08, r), 800, 2.0, "bp") * expd(0.08, 0.02) * 1.2
    marimba = mix(fm_bell(392, 1.0, 0.45, 4.0, 1.2, 0.06) * 0.5, fm_bell(588, 0.9, 0.3, 4.0, 1.0, 0.05) * 0.25)
    hum = np.zeros(n_of(1.2))
    for f, g in ((98, 0.5), (147, 0.35), (196, 0.3)):
        vib = 1 + 0.006 * np.sin(2 * np.pi * 4.5 * tt(1.2))
        hum += g * np.sin(2 * np.pi * f * np.cumsum(vib) / SR) * swell(1.2, 0.3, 0.7)
    hum = svf(hum, 900, 0.8, "lp") * 0.5
    rune = fm_bell(1568, 0.6, 0.14, 2.0, 1.5, 0.04) * 0.14
    dry = mix(thump, knock, pad(marimba, d), pad(hum, d), pad(rune, d), d=d)
    return room(dry, r, 0.8, 0.22, 0.4)


@opts(drive=1.05)
def item_beacon(r):
    """Repair beacon deploys: a soft sonar pulse with a rising two-note healing chime."""
    d = 1.3
    ping = fm_bell(659, d, 0.35, 2.0, 1.2, 0.1) * 0.55
    chime = fm_bell(988, 1.0, 0.35, 2.0, 1.0, 0.1) * 0.4
    out = place(ping, chime, 0.13, 1.0)
    out = place(out, fm_bell(1319, 0.8, 0.3, 2.0, 0.9, 0.08) * 0.3, 0.26, 1.0)
    pulse = sweep(100, 60, 0.3, "exp") * expd(0.3, 0.1) * 0.7
    out = place(out, pulse, 0.0, 1.0)
    return room(out, r, 0.9, 0.3, 0.8)


@opts(drive=1.1)
def item_decoy(r):
    """Decoy beacon drops: a rapid descending-then-rising bleep triplet with a hollow thunk."""
    d = 0.7
    out = np.zeros(n_of(d))
    for i, f in enumerate((1568, 1175, 880, 1319)):
        b = tone(f, 0.07, "tri") * expd(0.07, 0.03, 0.002)
        out = place(out, mix(svf(b, 4200, 0.9, "lp") * 0.5, fm_bell(f * 2, 0.08, 0.02, 3.0, 2.0, 0.003) * 0.15), i * 0.075, 1.0)
    thunk = sweep(200, 70, 0.14, "exp") * expd(0.14, 0.05) * 0.9
    out = place(out, thunk, 0.0, 1.0)
    return room(out, r, 0.4, 0.2, 0.6)


@opts(drive=1.2)
def item_striker(r):
    """Striker dart: a fast airy whoosh into a bright steel slice."""
    d = 0.5
    whoosh = svf(noise(0.18, r), np.geomspace(1100, 5600, n_of(0.18)), 2.5, "bp") * swell(0.18, 0.12, 0.05) * 1.6
    shing = metal(2900, 0.4, 0.14, (1, 2.4, 4.1, 6.3), (1, .6, .35, .2)) * 0.45
    tick = clicks(0.04, [0.0], r, 1.4, 0.0012)
    out = place(pad(whoosh, d), shing, 0.12, 1.0)
    out = place(out, tick, 0.12, 0.9)
    return room(out, r, 0.4, 0.14, 0.9)


@opts(drive=1.4)
def item_chain(r):
    """Chain reaction: an arcing electric zip that jumps between targets with a snap each hop."""
    d = 0.5
    zip_ = np.zeros(n_of(d))
    for i, tm in enumerate((0.0, 0.07, 0.14)):
        z = sweep(r.uniform(3000, 4800), r.uniform(700, 1100), 0.09, "exp", "saw") * expd(0.09, 0.03, 0.001) * 0.45
        z = svf(z, 7000, 1.5, "bp") + svf(noise(0.09, r), 4800, 1.5, "hp") * expd(0.09, 0.015) * 0.7
        zip_ = place(zip_, z, tm, 1.0 - i * 0.2)
    zip_ = mix(zip_, clicks(d, [0.0, 0.07, 0.14], r, 1.0, 0.0015), d=d)
    return room(zip_, r, 0.4, 0.15, 0.9)


@opts(drive=1.15)
def item_shatter(r):
    """Cold snap: a cracking freeze-shatter, a spray of glass shards and a low ice thud."""
    d = 1.1
    n = n_of(d)
    crack = svf(noise(0.1, r), 4200, 1.3, "hp") * expd(0.1, 0.02, 0.0004) * 1.4
    thud = sweep(150, 55, 0.25, "exp") * expd(0.25, 0.08) * 0.8
    shards = np.zeros(n)
    for _ in range(24):
        tm = r.exponential(0.12) + 0.01
        f = r.uniform(2600, 7800)
        shards = place(shards, metal(f, 0.5, r.uniform(0.04, 0.16), (1, 1.82, 3.1), (1, .4, .2)) * 0.28, tm, r.uniform(0.3, 1.0) * np.exp(-tm / 0.3))
    dry = mix(crack, pad(thud, d), shards[:n], d=d)
    return room(dry, r, 0.8, 0.25, 0.95)


@opts(drive=1.3)
def item_flashpoint(r):
    """Flashpoint: a sharp fuel-ignition pop, a short whoosh of flame and a flurry of embers."""
    d = 0.9
    n = n_of(d)
    pop = svf(noise(0.18, r), np.geomspace(5200, 400, n_of(0.18)), 0.9, "lp") * expd(0.18, 0.05, 0.0008) * 2.0
    thump = sweep(180, 52, 0.25, "exp") * expd(0.25, 0.08) * 1.2
    whoosh = svf(noise(0.5, r), np.geomspace(300, 2600, n_of(0.5)), 1.2, "bp") * swell(0.5, 0.04, 0.4) * 1.1
    embers = clicks(d, np.sort(r.exponential(0.2, 16) + 0.03), r, 1.0, 0.003) * np.exp(-tt(d) / 0.4)
    embers = svf(embers, 3600, 1.5, "bp") * 1.6
    dry = mix(pad(pop, d), pad(thump, d), pad(whoosh, d), embers, d=d)
    return room(dry, r, 0.5, 0.18, 0.5)


@opts(drive=1.5)
def item_overvolt(r):
    """Overvolt: a buzzing mains-hum zap, the shock hopping to a new target with a bright arc."""
    d = 0.6
    n = n_of(d)
    buzz = sweep(160, 90, d, "exp", "saw") * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 120 * tt(d)))) * expd(d, 0.14, 0.001) * 0.4
    buzz = svf(buzz, np.linspace(5200, 900, n), 1.4, "lp")
    arc = svf(noise(0.12, r), 6200, 1.6, "hp") * expd(0.12, 0.025) * 1.0
    z = sweep(4800, 520, 0.16, "exp", "saw") * expd(0.16, 0.05) * 0.4
    dry = mix(buzz, pad(arc, d), pad(z, d), pad(clicks(0.04, [0.0], r, 1.5, 0.0012), d), d=d)
    return room(dry, r, 0.4, 0.14, 0.8)


@opts(drive=1.1)
def item_guardian(r):
    """Guardian orb blocks a shot: a crisp metallic tink with a small energy hum."""
    d = 0.4
    tink = metal(2300, d, 0.1, (1, 2.57, 4.4, 6.9), (1, .5, .3, .15)) * 0.6
    hum = sweep(420, 640, 0.2, "lin") * expd(0.2, 0.06) * 0.25
    dry = mix(tink, pad(hum, d), pad(clicks(0.03, [0.0], r, 1.0, 0.001), d), d=d)
    return room(dry, r, 0.3, 0.12, 0.9)


# ---------------------------------------------------------------- PICKUPS
@opts(drive=1.05, peak=0.7)
def pickup_gem(r):
    """Data bit: a bright crystal 'tink' with a tiny octave sparkle (pitched up by the game as the chain grows)."""
    d = 0.35
    s = mix(fm_bell(1568, d, 0.07, 3.0, 2.0, 0.015, 0.001) * 0.7, fm_bell(3136, d, 0.04, 2.0, 1.0, 0.01, 0.001) * 0.25, clicks(d, [0.0], r, 0.3, 0.001))
    return room(s, r, 0.2, 0.07, 0.9, 0.004)


@opts(drive=1.05)
def pickup_heal(r):
    """PATCH: a warm rising three-note bell with a soft glowing pad."""
    d = 1.0
    out = np.zeros(n_of(d))
    for i, f in enumerate((523.3, 659.3, 784.0)):
        out = place(out, fm_bell(f, 0.8, 0.28, 2.0, 1.0, 0.1) * 0.55, i * 0.08, 1.0)
    out = place(out, fm_bell(1568, 0.7, 0.25, 2.0, 0.8, 0.08) * 0.3, 0.24, 1.0)
    glow = (tone(261.6, d) + tone(392, d) * 0.7) * swell(d, 0.15, 0.7) * 0.15
    return room(mix(out, glow, d=d), r, 0.9, 0.3, 0.8)


@opts(drive=1.1)
def pickup_magnet(r):
    """DEFRAG: a vacuum inhale sweeping up, a magnetic hum and a sparkle burst as the data is pulled in."""
    d = 1.2
    n = n_of(d)
    inhale = svf(noise(0.7, r), np.geomspace(250, 4200, n_of(0.7)), 2.0, "bp") * swell(0.7, 0.6, 0.1) * 1.6
    hum = sweep(110, 330, 0.7, "exp", "saw") * swell(0.7, 0.5, 0.15) * 0.18
    hum = svf(hum, 1400, 0.9, "lp")
    out = mix(pad(inhale, d), pad(hum, d), d=d)
    for i, f in enumerate((1318, 1760, 2349, 3136)):
        out = place(out, fm_bell(f, 0.5, 0.12, 3.0, 1.0, 0.04) * 0.3, 0.55 + i * 0.05, 1.0)
    out = place(out, sweep(160, 60, 0.3, "exp") * expd(0.3, 0.1) * 0.9, 0.62, 1.0)
    return room(out[:n], r, 0.8, 0.26, 0.8)


@opts(drive=1.1)
def pickup_cache(r):
    """Encrypted cache: lock-pick clicks, a heavy latch clunk and a golden unlock sparkle fanfare."""
    d = 1.6
    n = n_of(d)
    out = clicks(d, [0.0, 0.07, 0.15], r, 1.3, 0.002)
    out = svf(out, 3800, 1.2, "bp") * 1.5
    latch = mix(metal(260, 0.6, 0.2, (1, 2.6, 4.7, 7.0), (1, .6, .4, .2)) * 0.5, sweep(130, 48, 0.2, "exp") * expd(0.2, 0.07) * 0.9)
    out = place(out, latch, 0.22, 1.0)
    for i, f in enumerate((784, 988, 1175, 1568, 1976)):
        out = place(out, fm_bell(f, 1.2, 0.5, 2.0, 1.3, 0.14) * 0.38, 0.4 + i * 0.07, 1.0)
    for _ in range(14):
        tm = r.uniform(0.45, 1.2)
        out = place(out, fm_bell(r.choice([2637, 3136, 3951]), 0.3, 0.08, 3.0, 1.0, 0.03) * 0.16, tm, np.exp(-(tm - 0.4) / 0.6))
    return room(out[:n], r, 1.1, 0.3, 0.85)


@opts(drive=1.15)
def pickup_purge(r):
    """PURGE charge dropped: a charged bell ping, a rising power-up whine and a ready blip."""
    d = 1.2
    n = n_of(d)
    whine = sweep(300, 2200, 0.5, "exp", "saw") * swell(0.5, 0.4, 0.08) * 0.14
    whine = svf(whine, 3000, 0.9, "lp")
    out = pad(whine, d)
    out = place(out, fm_bell(784, 1.0, 0.45, 2.0, 1.5, 0.12) * 0.5, 0.35, 1.0)
    out = place(out, fm_bell(1568, 0.9, 0.4, 2.0, 1.2, 0.1) * 0.35, 0.4, 1.0)
    out = place(out, sweep(150, 55, 0.3, "exp") * expd(0.3, 0.1) * 0.9, 0.35, 1.0)
    return room(out[:n], r, 0.9, 0.28, 0.85)


def dry(x, r, width=0.006):
    """No reverb at all: a short fade-out and a tiny Haas delay on one side for stereo width (the upgrade / menu sounds are kept dry and direct)."""
    x = x.copy()
    f = min(len(x) // 2, n_of(0.04))
    x[-f:] *= np.linspace(1, 0, f)
    return x, np.concatenate([np.zeros(n_of(width)), x])[:len(x)]


# ---------------------------------------------------------------- UPGRADE STINGS
# Recorded-quality versions of the stings that used to be the bare tone synth in scripts/sfx.gd, so they match level_up / combo_tier.
@opts(drive=1.1, peak=0.82)
def legendary(r):
    """A legendary card is revealed: a deep swell, a rising gold bell stack and a long shimmering tail."""
    d = 1.9
    n = n_of(d)
    out = np.zeros(n)
    out = place(out, sweep(70, 140, 0.9, "exp") * swell(0.9, 0.5, 0.35) * 0.55, 0.0, 1.0)
    for i, f in enumerate([523.3, 659.3, 784.0, 1046.5, 1568.0]):
        out = place(out, fm_bell(f, 1.5, 0.6, 3.5, 1.8, 0.2) * 0.42, 0.12 + i * 0.09, 1.0 - i * 0.06)
    out = place(out, fm_bell(2093.0, 1.4, 0.7, 2.0, 1.0, 0.2) * 0.35, 0.6, 1.0)
    for _ in range(22):
        tm = r.uniform(0.3, 1.5)
        out = place(out, fm_bell(r.choice([2637, 3136, 3951, 4699]), 0.3, 0.07, 3.0, 1.0, 0.03) * 0.14, tm, np.exp(-tm / 0.9))
    wh = svf(noise(0.7, r), np.geomspace(400, 6500, n_of(0.7)), 3.0, "bp") * swell(0.7, 0.5, 0.2)
    out = place(out, wh, 0.0, 0.35)
    return dry(out[:n], r)


@opts(drive=1.1, peak=0.82)
def legendary_pick(r):
    """A legendary card is picked: a big gold strike on a full chord with a bright sparkle tail."""
    d = 1.5
    n = n_of(d)
    out = np.zeros(n)
    out = place(out, sweep(160, 50, 0.35, "exp") * expd(0.35, 0.12) * 0.9, 0.0, 1.0)
    for f in [392.0, 523.3, 659.3, 784.0, 1046.5, 1318.5]:
        out = place(out, fm_bell(f, 1.3, 0.55, 3.5, 1.6, 0.18) * 0.34, 0.0, 1.0)
    out = place(out, clicks(0.1, [0.0], r, 1.2, 0.002), 0.0, 0.7)
    for _ in range(18):
        tm = r.uniform(0.05, 1.0)
        out = place(out, fm_bell(r.choice([2093, 2637, 3136, 3951, 4699]), 0.3, 0.06, 3.0, 1.0, 0.03) * 0.14, tm, np.exp(-tm / 0.7))
    return dry(out[:n], r)


@opts(drive=1.1, peak=0.82)
def epic(r):
    """An epic card: a rising three-bell arpeggio ending on a bright ring."""
    d = 1.2
    n = n_of(d)
    out = np.zeros(n)
    for i, f in enumerate([392.0, 523.3, 659.3, 784.0]):
        out = place(out, fm_bell(f, 1.0, 0.4, 3.0, 1.5, 0.15) * 0.5, i * 0.07, 1.0)
    out = place(out, fm_bell(1046.5, 1.0, 0.5, 2.0, 1.2, 0.15) * 0.45, 0.28, 1.0)
    out = place(out, sweep(120, 70, 0.25, "exp") * expd(0.25, 0.09) * 0.6, 0.0, 1.0)
    return dry(out[:n], r)


@opts(drive=1.05, peak=0.82)
def buy(r):
    """A node is researched: a short bright two-note chime."""
    d = 0.45
    s = mix(fm_bell(660, d, 0.1, 3.0, 2.0, 0.03, 0.001) * 0.6, place(np.zeros(n_of(d)), fm_bell(990, 0.35, 0.12, 3.0, 2.0, 0.03, 0.001) * 0.6, 0.05, 1.0),
            clicks(d, [0.0], r, 0.25, 0.001))
    return dry(s, r)


@opts(drive=1.0, peak=0.8)
def level_up(r):
    """Level up: a clean rising bell arpeggio and a warm ring (no saturation: the old recording was clipped)."""
    d = 1.5
    n = n_of(d)
    out = np.zeros(n)
    for i, f in enumerate([523.3, 659.3, 784.0, 1046.5]):
        out = place(out, fm_bell(f, 1.2, 0.35, 3.0, 1.4, 0.12) * 0.55, i * 0.075, 1.0)
    out = place(out, fm_bell(1568.0, 1.0, 0.4, 2.0, 1.0, 0.12) * 0.3, 0.3, 1.0)
    for _ in range(10):
        tm = r.uniform(0.25, 0.9)
        out = place(out, fm_bell(r.choice([2093, 2637, 3136, 3951]), 0.25, 0.06, 3.0, 1.0, 0.03) * 0.1, tm, np.exp(-tm / 0.6))
    return dry(out[:n], r)


@opts(drive=1.0, peak=0.8)
def combo_tier(r):
    """Combo tier up: a short bright two-note rising chime."""
    d = 0.6
    n = n_of(d)
    out = np.zeros(n)
    out = place(out, fm_bell(784.0, 0.5, 0.12, 3.0, 1.6, 0.04, 0.001) * 0.6, 0.0, 1.0)
    out = place(out, fm_bell(1175.0, 0.5, 0.18, 3.0, 1.6, 0.05, 0.001) * 0.6, 0.07, 1.0)
    out = place(out, fm_bell(2349.0, 0.3, 0.08, 2.0, 1.0, 0.03, 0.001) * 0.18, 0.07, 1.0)
    return dry(out[:n], r)


@opts(drive=1.0, peak=0.8)
def start_run(r):
    """Run start: a rising power-up sweep that resolves into a bright two-bell chord (clean; the old recording was clipped)."""
    d = 1.7
    n = n_of(d)
    out = np.zeros(n)
    sw = svf(sweep(180, 1400, 0.7, "exp", "saw"), np.geomspace(500, 5000, n_of(0.7)), 0.9, "lp") * swell(0.7, 0.55, 0.12) * 0.22
    out = place(out, sw, 0.0, 1.0)
    out = place(out, sweep(60, 110, 0.7, "exp") * swell(0.7, 0.5, 0.15) * 0.35, 0.0, 1.0)
    for f in [392.0, 587.3, 784.0, 1174.7]:
        out = place(out, fm_bell(f, 1.1, 0.4, 3.0, 1.3, 0.12) * 0.4, 0.62, 1.0)
    out = place(out, clicks(0.05, [0.0], r, 0.5, 0.002), 0.62, 0.5)
    return dry(out[:n], r)


# ---------------------------------------------------------------- MENU / UI
# Soft, dry, short: rendered with the same toolkit as everything else instead of the in-engine tone synth.
@opts(drive=1.0, peak=0.7)
def ui_hover(r):
    d = 0.12
    s = mix(fm_bell(2200, d, 0.025, 2.0, 0.6, 0.01, 0.001) * 0.5, svf(noise(0.02, r), 3500, 0.8, "bp") * expd(0.02, 0.006, 0.0005) * 0.15)
    return s, haas_pair(s, r, 0.004)[1]


@opts(drive=1.0, peak=0.7)
def ui_select(r):
    d = 0.2
    s = mix(fm_bell(880, d, 0.05, 2.0, 0.8, 0.02, 0.001) * 0.55, place(np.zeros(n_of(d)), fm_bell(1320, 0.15, 0.05, 2.0, 0.8, 0.02, 0.001) * 0.4, 0.035, 1.0),
            svf(noise(0.015, r), 2500, 0.8, "bp") * expd(0.015, 0.005, 0.0005) * 0.2)
    return s, haas_pair(s, r, 0.005)[1]


@opts(drive=1.0, peak=0.7)
def ui_tick(r):
    d = 0.08
    s = mix(fm_bell(1700, d, 0.015, 2.0, 0.5, 0.008, 0.0008) * 0.5, svf(noise(0.012, r), 4000, 0.8, "bp") * expd(0.012, 0.004, 0.0005) * 0.12)
    return s, haas_pair(s, r, 0.003)[1]


@opts(drive=1.0, peak=0.7)
def ui_card(r):
    d = 0.14
    s = svf(noise(d, r), np.geomspace(1500, 5000, n_of(d)), 0.9, "bp") * expd(d, 0.035, 0.002) * 0.7
    return s, haas_pair(s, r, 0.006)[1]


@opts(drive=1.0, peak=0.7)
def ui_deny(r):
    d = 0.2
    s = mix(fm_bell(240, d, 0.06, 1.5, 0.8, 0.03, 0.001) * 0.6, place(np.zeros(n_of(d)), fm_bell(190, 0.14, 0.05, 1.5, 0.8, 0.03, 0.001) * 0.5, 0.05, 1.0))
    return s, haas_pair(s, r, 0.004)[1]


@opts(drive=1.0, peak=0.7)
def ui_start(r):
    """The START RUN button: a soft, short rising two-note confirm, nothing dramatic."""
    d = 0.5
    s = mix(fm_bell(660, d, 0.12, 2.0, 0.9, 0.04, 0.002) * 0.5, place(np.zeros(n_of(d)), fm_bell(990, 0.4, 0.14, 2.0, 0.9, 0.05, 0.002) * 0.45, 0.07, 1.0),
            place(np.zeros(n_of(d)), fm_bell(1320, 0.3, 0.1, 2.0, 0.6, 0.04, 0.002) * 0.2, 0.14, 1.0))
    return dry(s, r)


BUILDERS = [
    ab_railstrike, ab_wildfire, ab_deepfreeze, ab_thunder_0, ab_thunder_1, ab_thunder_2, ab_thunderstorm, ab_pause,
    ab_restore, ab_overclock, ab_phase, ab_purge, ab_lockdown, ab_deepscan, super_sting,
    item_totem, item_beacon, item_decoy, item_striker, item_chain, item_shatter, item_flashpoint, item_overvolt, item_guardian,
    pickup_gem, pickup_heal, pickup_magnet, pickup_cache, pickup_purge,
    legendary, legendary_pick, epic, buy, level_up, combo_tier, start_run,
    ui_hover, ui_select, ui_tick, ui_card, ui_deny, ui_start,
]
NAMES = {
    "ab_thunder_0": "ab_thunder_0", "ab_thunder_1": "ab_thunder_1", "ab_thunder_2": "ab_thunder_2",
}

if __name__ == "__main__":
    only = set(sys.argv[2:])
    print("writing to", os.path.abspath(OUT))
    for b in BUILDERS:
        name = getattr(b, "sound_name", b.__name__)
        if only and name not in only:
            continue
        render(name, b)
