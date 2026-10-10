#!/usr/bin/env python3
"""Kernel Panic: renders the weapon, enemy-attack, explosion and event sound effects (the ones sfx.gd used to synthesize or leave silent).

Reuses the helpers in gen_sfx.py. usage: python3 tools/gen_sfx_combat.py [out_dir] [name ...]   (default out_dir: assets/audio/sfx)
Prints each file's active RMS in dB so SAMPLE_GAIN in scripts/sfx.gd can be set (gain = 10^((target_db - rms_db)/20)).
"""
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sfx as g
from gen_sfx import (expd, swell, sweep, tone, fm_bell, metal, noise, svf, clicks, place, pad, mix, room, dry, n_of, opts, rng_for, haas_pair)


# ---------------------------------------------------------------- WEAPONS
@opts(drive=1.1, peak=0.8)
def weapon_packet(r):
    """PACKET GUN: a soft digital 'pip' with a tiny air tick, short and clean because it repeats constantly."""
    d = 0.14
    body = sweep(1500, 620, 0.09, "exp", "tri") * expd(0.09, 0.03, 0.0008) * 0.7
    top = fm_bell(2400, d, 0.025, 2.0, 1.2, 0.01, 0.0005) * 0.25
    tick = clicks(d, [0.0], r, 0.9, 0.0008)
    return dry(mix(pad(body, d), top, tick, d=d), r, 0.003)


@opts(drive=1.2)
def weapon_firewall(r):
    """FIREWALL: a brick slams down, a heavy low thud with a dull stone clack and a short crackle of heat."""
    d = 0.6
    thud = sweep(150, 50, 0.3, "exp") * expd(0.3, 0.1, 0.002) * 1.2
    clack = metal(520, 0.25, 0.05, (1, 2.3, 3.7), (1, .5, .3)) * 0.35
    heat = svf(noise(0.35, r), np.geomspace(3500, 700, n_of(0.35)), 0.8, "bp") * expd(0.35, 0.1, 0.004) * 0.7
    crack = clicks(d, [0.0, 0.05, 0.09, 0.17], r, 0.5, 0.002)
    return room(mix(pad(thud, d), pad(clack, d), pad(heat, d), crack, d=d), r, 0.4, 0.15, 0.4)


@opts(drive=1.1, peak=0.75)
def weapon_keys(r):
    """ENCRYPTION KEYS: a small bright key-jingle ting when an orbiting key strikes."""
    d = 0.3
    s = mix(metal(2100, d, 0.07, (1, 2.76, 5.4), (1, .6, .3)) * 0.5, fm_bell(3150, d, 0.05, 3.0, 1.5, 0.02, 0.0005) * 0.3, clicks(d, [0.0], r, 0.6, 0.001), d=d)
    return dry(s, r, 0.004)


@opts(drive=1.15, peak=0.8)
def weapon_scanner(r):
    """SCANNER: a short radar ping that swells outward, round and clean, with a faint echo."""
    d = 0.9
    ping = fm_bell(880, 0.5, 0.18, 1.0, 0.6, 0.06, 0.002) * 0.7
    sw = svf(noise(0.3, r), np.geomspace(500, 3200, n_of(0.3)), 2.5, "bp") * swell(0.3, 0.22, 0.08) * 0.8
    out = mix(pad(ping, d), pad(sw, d), d=d)
    out = place(out, ping, 0.22, 0.28)
    return room(out, r, 0.7, 0.2, 0.7)


@opts(drive=1.25, peak=0.8)
def weapon_ping(r):
    """PING.EXE: a quick sonar blip that bounces: two short ticks and a rising chirp."""
    d = 0.3
    chirp = sweep(700, 2200, 0.08, "exp", "sine") * expd(0.08, 0.04, 0.001) * 0.7
    out = place(np.zeros(n_of(d)), chirp, 0.0, 1.0)
    out = place(out, chirp, 0.1, 0.45)
    out = mix(out, clicks(d, [0.0, 0.1], r, 0.5, 0.001), d=d)
    return dry(out, r, 0.004)


@opts(drive=1.4, peak=0.85)
def weapon_quarantine(r):
    """QUARANTINE: a pylon drop: a hard metal plant and a low electric hum that sweeps up as the field closes."""
    d = 0.8
    plant = metal(180, 0.4, 0.12, (1, 2.4, 3.9, 6.2), (1, .7, .5, .3)) * 0.55
    thump = sweep(120, 45, 0.3, "exp") * expd(0.3, 0.09, 0.002) * 1.0
    hum = sweep(110, 330, 0.7, "exp", "saw") * swell(0.7, 0.35, 0.3) * 0.12
    hum = svf(hum, 1400, 0.8, "lp")
    return room(mix(pad(plant, d), pad(thump, d), hum, clicks(d, [0.0], r, 0.9, 0.0015), d=d), r, 0.5, 0.18, 0.5)


@opts(drive=1.3, peak=0.85)
def weapon_tesla(r):
    """TESLA GRID / ZAP: a crisp electric crack with a short buzz tail."""
    d = 0.35
    z = sweep(4200, 900, 0.15, "exp", "saw") * expd(0.15, 0.05, 0.001) * 0.4
    z = svf(z, 8000, 1.2, "bp") + svf(noise(0.15, r), 5200, 1.2, "hp") * expd(0.15, 0.04) * 0.6
    buzz = sweep(120, 110, 0.3, "lin", "saw") * expd(0.3, 0.09, 0.002) * 0.18
    return room(mix(pad(z, d), pad(svf(buzz, 900, 0.8, "lp"), d), clicks(d, [0.0, 0.03], r, 1.0, 0.0012), d=d), r, 0.35, 0.12, 0.8)


# ---------------------------------------------------------------- BLASTS
@opts(drive=1.35, peak=0.9)
def explosion(r):
    """A mid-size blast: sharp crack, a falling noise burst, a deep sub boom and a few scattering bits. Pitched 0.5 to 1.6 by the game."""
    d = 1.3
    crack = clicks(d, [0.0], r, 2.2, 0.0015)
    burst = svf(noise(0.55, r), np.geomspace(7000, 160, n_of(0.55)), 0.8, "lp") * expd(0.55, 0.14, 0.001) * 2.0
    sub = sweep(110, 32, 0.8, "exp") * expd(0.8, 0.22, 0.003) * 1.6
    body = sweep(220, 70, 0.4, "exp", "tri") * expd(0.4, 0.1, 0.002) * 0.5
    bits = clicks(d, np.sort(r.exponential(0.18, 14) + 0.05), r, 0.5, 0.002) * np.exp(-g.tt(d) / 0.35)
    return room(mix(crack, pad(burst, d), pad(sub, d), pad(body, d), bits, d=d), r, 0.9, 0.22, 0.45)


@opts(drive=1.2, peak=0.8)
def alert_siren(r):
    """Warning klaxon: two descending hollow tones, firm but not shrill."""
    d = 0.75
    out = np.zeros(n_of(d))
    for i, f in enumerate((740.0, 555.0)):
        tn = svf(tone(f, 0.3, "saw") * 0.4 + tone(f * 2, 0.3, "sine") * 0.2, 2200, 0.8, "lp") * swell(0.3, 0.02, 0.1)
        out = place(out, tn, i * 0.34, 1.0)
    return room(out, r, 0.4, 0.12, 0.4)


@opts(drive=1.1, peak=0.7)
def regen_tick(r):
    """Regeneration heal: a soft warm two-note chime."""
    d = 0.5
    s = mix(fm_bell(1047, d, 0.14, 1.0, 0.5, 0.05, 0.003) * 0.5, place(np.zeros(n_of(d)), fm_bell(1568, 0.4, 0.12, 1.0, 0.4, 0.05, 0.003) * 0.4, 0.07, 1.0), d=d)
    return dry(s, r, 0.005)


# ---------------------------------------------------------------- ENEMY ATTACKS
@opts(drive=1.2, peak=0.75)
def en_spy_shot(r):
    """SPYWARE shot: a thin dry 'tsk' with a tiny falling blip."""
    d = 0.2
    s = mix(sweep(1900, 800, 0.08, "exp", "tri") * expd(0.08, 0.03, 0.001) * 0.5, svf(noise(0.06, r), 4200, 1.2, "bp") * expd(0.06, 0.02) * 0.7, d=d)
    return dry(s, r, 0.004)


@opts(drive=1.25, peak=0.8)
def en_sentry_fan(r):
    """SENTRY three-shot fan: a rapid triple thump-and-zip."""
    d = 0.5
    out = np.zeros(n_of(d))
    for i, tm in enumerate((0.0, 0.07, 0.14)):
        s = mix(sweep(1400, 420, 0.1, "exp", "saw") * expd(0.1, 0.035, 0.001) * 0.3, sweep(190, 80, 0.12, "exp") * expd(0.12, 0.05, 0.001) * 0.8, clicks(0.1, [0.0], r, 0.6, 0.001), d=0.12)
        out = place(out, svf(s, 5000, 0.8, "lp"), tm, 1.0 - 0.1 * i)
    return room(out, r, 0.35, 0.12, 0.5)


@opts(drive=1.15, peak=0.8)
def en_sentry_warp(r):
    """SENTRY warp tell: a swelling rising whine into a soft pop at arrival (the game plays this at the start of the warp)."""
    d = 0.8
    wh = sweep(300, 1800, 0.75, "exp", "sine") * swell(0.75, 0.6, 0.12) * 0.5
    pop = place(np.zeros(n_of(d)), sweep(600, 120, 0.1, "exp") * expd(0.1, 0.04, 0.001) * 0.8, 0.72, 1.0)
    return room(mix(pad(wh, d), pop, d=d), r, 0.45, 0.14, 0.7)


@opts(drive=1.15, peak=0.8)
def en_nano_lock(r):
    """NANOBOT sight line: a narrow rising targeting tone that quickens (lock-on)."""
    d = 0.95
    t = g.tt(d)
    f = 900 + 900 * (t / d) ** 2
    ph = 2 * np.pi * np.cumsum(f) / g.SR
    gate = (np.sin(2 * np.pi * (4 + 10 * (t / d) ** 2) * t) > 0).astype(float)
    s = np.sin(ph) * gate * swell(d, 0.1, 0.1) * 0.5
    return dry(svf(s, 3500, 0.8, "lp"), r, 0.004)


@opts(drive=1.4, peak=0.9)
def en_nano_beam(r):
    """NANOBOT beam: a sharp bright laser discharge with a sustained hum for the beam's length."""
    d = 0.6
    ch = sweep(3600, 500, 0.12, "exp", "saw") * expd(0.12, 0.045, 0.001) * 0.5
    beam = svf(tone(540, 0.4, "saw") * 0.3 + tone(1080, 0.4, "square") * 0.1, 2600, 0.9, "lp") * swell(0.4, 0.01, 0.25)
    hiss = svf(noise(0.4, r), 6000, 0.8, "hp") * swell(0.4, 0.01, 0.25) * 0.25
    return room(mix(pad(ch, d), pad(beam, d), pad(hiss, d), clicks(d, [0.0], r, 1.2, 0.0015), d=d), r, 0.35, 0.12, 0.8)


@opts(drive=1.3, peak=0.85)
def en_ram_charge(r):
    """RAM charge: a heavy engine rev-up and a battering whoosh."""
    d = 0.9
    rev = sweep(55, 200, 0.7, "exp", "saw") * swell(0.7, 0.5, 0.2) * 0.45
    rev = svf(rev, 700, 0.9, "lp")
    wind = svf(noise(0.7, r), np.geomspace(300, 1800, n_of(0.7)), 0.9, "bp") * swell(0.7, 0.55, 0.15) * 1.0
    hit = place(np.zeros(n_of(d)), sweep(110, 40, 0.25, "exp") * expd(0.25, 0.08, 0.002) * 1.0, 0.6, 1.0)
    return room(mix(pad(rev, d), pad(wind, d), hit, d=d), r, 0.5, 0.15, 0.4)


@opts(drive=1.1, peak=0.75)
def en_zip_arm(r):
    """ZIP BOMB arming: an accelerating digital beep train that ends on a long tone (1.1 s fuse)."""
    d = 1.15
    out = np.zeros(n_of(d))
    tm, gap, i = 0.0, 0.22, 0
    while tm < 0.95:
        out = place(out, tone(1500 + 70 * i, 0.05, "sine") * expd(0.05, 0.03, 0.001), tm, 0.55)
        tm += gap
        gap = max(0.05, gap * 0.8)
        i += 1
    out = place(out, tone(2200, 0.15, "tri") * swell(0.15, 0.01, 0.05), 0.98, 0.5)
    return dry(out, r, 0.004)


@opts(drive=1.15, peak=0.75)
def en_mite_lunge(r):
    """MITE/LEECH lunge: a tiny quick chitter-whoosh."""
    d = 0.25
    w = svf(noise(0.14, r), np.geomspace(1800, 5200, n_of(0.14)), 1.5, "bp") * swell(0.14, 0.09, 0.04) * 1.0
    chit = clicks(d, [0.0, 0.03, 0.06, 0.09], r, 0.6, 0.0012)
    return dry(mix(pad(w, d), chit, d=d), r, 0.004)


@opts(drive=1.2, peak=0.8)
def en_botnet_dash(r):
    """BOTNET/PHISHER dash: a fast digital whoosh with a bit-crushed zip."""
    d = 0.4
    w = svf(noise(0.28, r), np.geomspace(500, 3800, n_of(0.28)), 1.0, "bp") * swell(0.28, 0.14, 0.1) * 1.1
    z = sweep(300, 2400, 0.22, "exp", "square") * expd(0.22, 0.09, 0.002) * 0.14
    return room(mix(pad(w, d), pad(svf(z, 3200, 0.8, "lp"), d), d=d), r, 0.3, 0.1, 0.7)


@opts(drive=1.2, peak=0.8)
def en_rootkit_blink(r):
    """ROOTKIT teleport: a hollow reverse-swell into a dull click, ghostly."""
    d = 0.5
    sw = svf(noise(0.3, r), np.geomspace(4000, 400, n_of(0.3)), 1.3, "bp") * swell(0.3, 0.25, 0.04) * 0.9
    hol = fm_bell(330, 0.4, 0.15, 1.4, 0.8, 0.06, 0.004) * 0.35
    out = place(pad(sw, d), hol, 0.28, 1.0)
    out = place(out, clicks(0.03, [0.0], r, 1.0, 0.001), 0.28, 0.8)
    return room(out, r, 0.55, 0.2, 0.4)


@opts(drive=1.3, peak=0.85)
def en_boss_attack(r):
    """Boss attack release: a low heavy 'whump' with a metallic edge (used for slams, spirals, fans)."""
    d = 0.7
    wh = sweep(140, 50, 0.4, "exp") * expd(0.4, 0.13, 0.003) * 1.2
    edge = metal(240, 0.4, 0.09, (1, 2.4, 3.9, 6.2), (1, .6, .4, .2)) * 0.35
    air = svf(noise(0.3, r), np.geomspace(2500, 400, n_of(0.3)), 0.9, "bp") * expd(0.3, 0.1, 0.004) * 0.6
    return room(mix(pad(wh, d), pad(edge, d), pad(air, d), clicks(d, [0.0], r, 0.8, 0.002), d=d), r, 0.5, 0.18, 0.4)


# ---------------------------------------------------------------- EVENTS
@opts(drive=1.35, peak=0.9)
def player_death(r):
    """Player destroyed: a descending power-down sweep, a crunching low boom and a dying electrical fizzle."""
    d = 2.0
    down = sweep(900, 40, 1.4, "exp", "saw") * expd(1.4, 0.5, 0.004) * 0.35
    down = svf(down, np.geomspace(5000, 200, n_of(1.4)), 0.9, "lp")
    boom = sweep(120, 28, 1.0, "exp") * expd(1.0, 0.3, 0.003) * 1.5
    crunch = svf(noise(0.5, r), np.geomspace(5000, 200, n_of(0.5)), 0.9, "lp") * expd(0.5, 0.12, 0.001) * 1.6
    fizz = clicks(d, np.sort(r.exponential(0.5, 30) + 0.25), r, 0.6, 0.0018) * np.exp(-g.tt(d) / 0.7)
    return room(mix(pad(down, d), pad(boom, d), pad(crunch, d), fizz, clicks(d, [0.0], r, 1.5, 0.0015), d=d), r, 1.1, 0.25, 0.4)


@opts(drive=1.15, peak=0.88)
def device_cure(r):
    """Device cured: a deep resolving boom, a clean rising chord of bells and a wide shimmer. Bigger than a level-up, shorter than a boss defeat."""
    d = 3.0
    boom = sweep(90, 35, 1.0, "exp") * expd(1.0, 0.3, 0.004) * 1.0
    out = pad(boom, d)
    for i, f in enumerate((261.6, 329.6, 392.0, 523.3, 659.3, 784.0)):
        out = place(out, fm_bell(f, 2.4, 0.9, 2.0, 1.2, 0.35) * 0.3, 0.1 + i * 0.12, 1.0)
    sh = svf(noise(1.8, r), 6500, 0.8, "hp") * swell(1.8, 0.7, 1.0) * 0.12
    out = place(out, sh, 0.3, 1.0)
    return room(out, r, 1.6, 0.3, 0.7)


@opts(drive=1.1, peak=0.8)
def achievement(r):
    """Achievement unlocked: a bright three-note trophy chime with a sparkle."""
    d = 1.4
    out = np.zeros(n_of(d))
    for i, f in enumerate((784.0, 988.0, 1318.5)):
        out = place(out, fm_bell(f, 1.1, 0.4, 2.0, 1.0, 0.12) * 0.45, i * 0.11, 1.0)
    out = place(out, clicks(0.2, np.arange(0.0, 0.2, 0.025), r, 0.3, 0.0008), 0.3, 1.0)
    return room(out, r, 0.8, 0.2, 0.8)


BUILDERS = [weapon_packet, weapon_firewall, weapon_keys, weapon_scanner, weapon_ping, weapon_quarantine, weapon_tesla,
            explosion, alert_siren, regen_tick,
            en_spy_shot, en_sentry_fan, en_sentry_warp, en_nano_lock, en_nano_beam, en_ram_charge, en_zip_arm, en_mite_lunge,
            en_botnet_dash, en_rootkit_blink, en_boss_attack,
            player_death, device_cure, achievement]


def active_rms_db(st):
    x = st.astype(float) / 32768.0
    m = np.abs(x).max()
    e = np.abs(x) > 0.05 * m
    return 20 * np.log10(np.sqrt(np.mean(x[e] ** 2)) + 1e-9)


if __name__ == "__main__":
    only = set(sys.argv[2:])
    print("writing to", os.path.abspath(g.OUT))
    for b in BUILDERS:
        name = b.__name__
        if only and name not in only:
            continue
        r = rng_for(name)
        L, R = b(r)
        st = g.finish(L, R, **getattr(b, "opts", {}))
        g.save(name, st)
        print("      active RMS %.1f dB" % active_rms_db(st))
