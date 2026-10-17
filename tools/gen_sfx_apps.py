#!/usr/bin/env python3
"""Kernel Panic: the smartphone secret room (A2) sounds, built with the helpers of gen_sfx.py.

usage: python3 tools/gen_sfx_apps.py [out_dir]     (default: assets/audio/sfx)
Renders: app_open, app_close, app_tick, pw_deny, pw_grant, glitch_wave, switch_on, switch_off, spot_enter, spot_tick, spot_done,
         cp_ok, cp_bad, dig_tick, dig_done, key_press, mg_ok, mg_bad, shutter, app_done, piano_0..piano_4
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np

import gen_sfx as g
from gen_sfx import (SR, clicks, expd, fm_bell, haas_pair, mix, n_of, noise, opts, place, room, svf, swell, sweep, tone, tt)


@opts(drive=1.05, peak=0.85)
def app_open(r):
    """An icon pops open: a soft glassy tap, a quick rising air swoosh and a two-note chime that settles."""
    d = 0.7
    tap = mix(fm_bell(880, d, 0.05, 3.0, 1.4, 0.02, 0.001) * 0.6, clicks(d, [0.0], r, 0.5, 0.0015))
    swoosh = svf(noise(d, r), np.geomspace(600, 6000, n_of(d)), 0.8, "bp") * swell(d, 0.22, 0.4) * 0.5
    chime = np.zeros(n_of(d))
    chime = place(chime, fm_bell(1318.5, 0.5, 0.16, 2.0, 0.8, 0.05, 0.002) * 0.35, 0.12, 1.0)
    chime = place(chime, fm_bell(1760.0, 0.5, 0.2, 2.0, 0.8, 0.05, 0.002) * 0.3, 0.2, 1.0)
    s = mix(tap, swoosh, chime, d=d)
    return room(s, r, 0.35, 0.18, 0.8, 0.006)


@opts(drive=1.05, peak=0.8)
def app_close(r):
    """The app shuts: a falling air swoosh, a dull tap and a low settling note."""
    d = 0.5
    swoosh = svf(noise(d, r), np.geomspace(5000, 500, n_of(d)), 0.8, "bp") * swell(d, 0.05, 0.35) * 0.5
    tap = mix(fm_bell(330, d, 0.05, 2.0, 1.0, 0.02, 0.001) * 0.7, clicks(d, [0.14], r, 0.4, 0.002))
    tap = place(np.zeros(n_of(d)), tap, 0.1, 1.0)[: n_of(d)]
    low = fm_bell(196, d, 0.18, 1.5, 0.6, 0.06, 0.003) * 0.4
    s = mix(swoosh, tap, low, d=d)
    return room(s, r, 0.25, 0.14, 0.6, 0.006)


@opts(drive=1.0, peak=0.5)
def app_tick(r):
    """One tick of the opening ring (the game pitches it up as the ring fills)."""
    d = 0.12
    s = mix(fm_bell(1200, d, 0.03, 2.0, 0.8, 0.01, 0.001) * 0.7, clicks(d, [0.0], r, 0.3, 0.001))
    return s, haas_pair(s, r, 0.003)[1]


@opts(drive=1.3, peak=0.8)
def pw_deny(r):
    """Wrong password: two low, rough buzzes."""
    d = 0.45
    out = np.zeros(n_of(d))
    for at in (0.0, 0.18):
        b = sweep(150, 110, 0.15, "exp", "saw") * 0.5 + sweep(152, 111, 0.15, "exp", "square") * 0.25
        b = svf(b, 900, 0.9, "lp") * expd(0.15, 0.09, 0.002)
        out = place(out, b, at, 1.0)
    out = out + clicks(d, [0.0, 0.18], r, 0.35, 0.002)[: len(out)]
    return room(out, r, 0.2, 0.1, 0.5, 0.004)


@opts(drive=1.05, peak=0.85)
def pw_grant(r):
    """Access granted: a bright rising three-note chime over a short shimmer of data motes."""
    d = 1.0
    out = np.zeros(n_of(d))
    for i, f in enumerate((784.0, 1046.5, 1568.0)):
        out = place(out, fm_bell(f, 0.8, 0.22, 2.0, 0.9, 0.07, 0.002) * 0.5, i * 0.09, 1.0)
    shimmer = svf(noise(d, r), np.geomspace(3000, 9000, n_of(d)), 0.9, "bp") * swell(d, 0.2, 0.6) * 0.18
    return room(mix(out, shimmer, d=d), r, 0.7, 0.25, 0.9)


@opts(drive=1.3, peak=0.85)
def glitch_wave(r):
    """A glitch wave arrives: stuttering bit-crushed noise, a falling digital zap and a low corrupted pulse."""
    d = 1.0
    stut = np.zeros(n_of(d))
    for i in range(9):
        at = i * 0.07 + (0.02 if i % 3 == 0 else 0.0)
        burst = svf(noise(0.05, r), 2500 + 1800 * (i % 4), 1.2, "bp") * expd(0.05, 0.02, 0.001)
        stut = place(stut, burst, at, 0.8)
    crushed = np.round(stut * 6.0) / 6.0   # coarse amplitude steps = the bit-crushed crunch
    zap = sweep(2400, 140, 0.55, "exp", "square") * expd(0.55, 0.22, 0.002) * 0.3
    pulse = sweep(70, 52, 0.7, "exp", "sine") * expd(0.7, 0.3, 0.004) * 0.7
    s = mix(crushed, zap, pulse, d=d)
    return room(s, r, 0.35, 0.12, 0.7, 0.005)


@opts(drive=1.1, peak=0.8)
def switch_on(r):
    """A settings toggle flicked ON: a hard plastic clack (clicks + short band-passed noise), then a bright rising 'ding' of two quick FM ticks (1500 / 2250 Hz)."""
    d = 0.22
    clack = mix(clicks(d, [0.0, 0.018], r, 0.9, 0.0012), svf(noise(d, r), 3200, 1.1, "bp") * expd(d, 0.012, 0.0005) * 0.6)
    ding = np.zeros(n_of(d))
    ding = place(ding, fm_bell(1500, 0.12, 0.03, 2.0, 0.8, 0.01, 0.001) * 0.4, 0.02, 1.0)
    ding = place(ding, fm_bell(2250, 0.12, 0.04, 2.0, 0.8, 0.01, 0.001) * 0.35, 0.05, 1.0)
    s = mix(clack, ding, d=d)
    return room(s, r, 0.12, 0.1, 0.8, 0.003)


@opts(drive=1.1, peak=0.8)
def switch_off(r):
    """A settings toggle flicked OFF: the same clack but duller and lower, with a falling two-tick tone (900 / 600 Hz)."""
    d = 0.22
    clack = mix(clicks(d, [0.0, 0.022], r, 0.8, 0.0016), svf(noise(d, r), 1800, 1.0, "bp") * expd(d, 0.015, 0.0005) * 0.6)
    ding = np.zeros(n_of(d))
    ding = place(ding, fm_bell(900, 0.12, 0.03, 2.0, 0.8, 0.01, 0.001) * 0.4, 0.02, 1.0)
    ding = place(ding, fm_bell(600, 0.14, 0.05, 2.0, 0.8, 0.01, 0.001) * 0.35, 0.05, 1.0)
    s = mix(clack, ding, d=d)
    return room(s, r, 0.12, 0.1, 0.5, 0.003)


def _arp(d, freqs, step, bell=(0.18, 2.0, 0.8, 0.05), gain=0.4):
    """A little run of bell notes, one every `step` seconds."""
    out = np.zeros(n_of(d))
    for i, f in enumerate(freqs):
        out = place(out, fm_bell(f, 0.5, bell[0], bell[1], bell[2], bell[3], 0.002) * gain, i * step, 1.0)
    return out


@opts(drive=1.05, peak=0.75)
def spot_enter(r):
    """Stepping onto a minigame spot: a soft rising glassy pad (400 -> 800 Hz sweep) and one bell at 1046 Hz."""
    d = 0.4
    pad = sweep(400, 800, d, "exp", "sine") * swell(d, 0.15, 0.2) * 0.35
    s = mix(pad, fm_bell(1046.5, d, 0.1, 2.0, 0.8, 0.05, 0.004) * 0.3, d=d)
    return room(s, r, 0.2, 0.12, 0.7, 0.005)


@opts(drive=1.1, peak=0.7)
def spot_tick(r):
    """One tick while you stand on a spot (the game raises the pitch as the bar fills): a short glass ping plus a dry click."""
    d = 0.14
    s = mix(fm_bell(1500, d, 0.025, 2.0, 0.6, 0.01, 0.001) * 0.6, clicks(d, [0.0], r, 0.25, 0.001), d=d)
    return room(s, r, 0.1, 0.08, 0.8, 0.003)


@opts(drive=1.1, peak=0.85)
def spot_done(r):
    """A spot completes: a bright four-note arpeggio (C5 E5 G5 C6) with a shimmer on top."""
    d = 1.0
    s = mix(_arp(d, [523.25, 659.25, 783.99, 1046.5], 0.08), noise(d, r) * 0.0, d=d)
    shimmer = svf(noise(d, r), np.geomspace(5000, 9000, n_of(d)), 0.8, "bp") * expd(d, 0.18, 0.02) * 0.08
    return room(mix(s, shimmer, d=d), r, 0.5, 0.22, 0.8, 0.008)


@opts(drive=1.1, peak=0.8)
def cp_ok(r):
    """A checkpoint lit green: a two-note rising chime (880 / 1320 Hz); the game raises the pitch with each checkpoint."""
    d = 0.5
    s = mix(fm_bell(880, d, 0.12, 2.0, 0.8, 0.04, 0.002) * 0.45, place(np.zeros(n_of(d)), fm_bell(1320, 0.4, 0.14, 2.0, 0.8, 0.04, 0.002) * 0.4, 0.07, 1.0), d=d)
    return room(s, r, 0.3, 0.15, 0.8, 0.006)


@opts(drive=1.3, peak=0.85)
def cp_bad(r):
    """The wrong checkpoint: a harsh falling square-wave buzz (320 -> 110 Hz) with a low thud, nothing pleasant."""
    d = 0.5
    buzz = sweep(320, 110, 0.4, "exp", "square") * expd(0.4, 0.2, 0.002) * 0.35
    thud = sweep(90, 50, 0.4, "exp", "sine") * expd(0.4, 0.15, 0.002) * 0.7
    return room(mix(buzz, thud, d=d), r, 0.15, 0.08, 0.3, 0.004)


@opts(drive=1.1, peak=0.75)
def dig_tick(r):
    """A shovel scrape while digging: band-passed noise with a dull thump (~120 Hz)."""
    d = 0.18
    scrape = svf(noise(d, r), 900, 0.9, "bp") * expd(d, 0.06, 0.003) * 0.7
    thump = sweep(140, 80, d, "exp", "sine") * expd(d, 0.05, 0.002) * 0.6
    return room(mix(scrape, thump, d=d), r, 0.12, 0.08, 0.3, 0.003)


@opts(drive=1.1, peak=0.9)
def dig_done(r):
    """Something is dug up: a chest-like low knock then a rising six-note sparkle (C5 ... A6)."""
    d = 1.3
    knock = sweep(180, 90, 0.25, "exp", "sine") * expd(0.25, 0.08, 0.002) * 0.8
    sp = _arp(d, [523.25, 659.25, 783.99, 1046.5, 1318.5, 1760.0], 0.07, gain=0.35)
    return room(mix(knock, place(np.zeros(n_of(d)), sp, 0.18, 1.0), d=d), r, 0.6, 0.25, 0.8, 0.008)


@opts(drive=1.05, peak=0.7)
def key_press(r):
    """A phone keypad button: a short soft beep (880 Hz) with a plastic click; the game pitches it per digit."""
    d = 0.16
    s = mix(tone(880, d) * expd(d, 0.04, 0.002) * 0.4, clicks(d, [0.0], r, 0.35, 0.0015), d=d)
    return room(s, r, 0.1, 0.06, 0.6, 0.003)


@opts(drive=1.1, peak=0.8)
def mg_ok(r):
    """A right answer in a paused minigame (photo part restored, right reply, shift tick): one warm bell (1046 Hz) over a tick."""
    d = 0.4
    s = mix(fm_bell(1046.5, d, 0.1, 2.0, 0.7, 0.04, 0.002) * 0.5, clicks(d, [0.0], r, 0.2, 0.001), d=d)
    return room(s, r, 0.25, 0.12, 0.7, 0.005)


@opts(drive=1.3, peak=0.85)
def mg_bad(r):
    """A wrong answer in a paused minigame: a dull falling thud (220 -> 100 Hz) with a short noise slap."""
    d = 0.45
    s = mix(sweep(220, 100, d, "exp", "sine") * expd(d, 0.14, 0.002) * 0.8, svf(noise(d, r), 700, 0.8, "bp") * expd(d, 0.04, 0.001) * 0.5, d=d)
    return room(s, r, 0.15, 0.08, 0.3, 0.004)


@opts(drive=1.1, peak=0.9)
def shutter(r):
    """A camera shutter: two mechanical clicks 55 ms apart (band-passed noise bursts at 3.5 kHz) over a small low clunk."""
    d = 0.3
    c1 = svf(noise(0.04, r), 3500, 1.0, "bp") * expd(0.04, 0.01, 0.0005)
    c2 = svf(noise(0.05, r), 2600, 1.0, "bp") * expd(0.05, 0.015, 0.0005)
    s = np.zeros(n_of(d))
    s = place(s, c1, 0.0, 0.9)
    s = place(s, c2, 0.055, 0.7)
    s = place(s, sweep(160, 90, 0.1, "exp", "sine") * expd(0.1, 0.04, 0.002), 0.0, 0.5)
    return room(s, r, 0.15, 0.08, 0.6, 0.003)


@opts(drive=1.05, peak=0.9)
def app_done(r):
    """An app's reward unlocks: a low pad swell (196 Hz) under a seven-note rising arpeggio and a long shimmering tail."""
    d = 1.8
    pad = tone(196, d) * swell(d, 0.4, 0.8) * 0.3 + tone(293.66, d) * swell(d, 0.4, 0.8) * 0.2
    arp = _arp(d, [392.0, 493.88, 587.33, 783.99, 987.77, 1174.7, 1567.98], 0.09, bell=(0.25, 2.0, 0.8, 0.06), gain=0.35)
    return room(mix(pad, arp, d=d), r, 0.9, 0.3, 0.8, 0.01)


def _piano(freq):
    @opts(drive=1.05, peak=0.8)
    def build(r):
        d = 1.0
        s = mix(fm_bell(freq, d, 0.28, 2.0, 0.55, 0.12, 0.002) * 0.6, fm_bell(freq * 2, d, 0.12, 1.0, 0.2, 0.05, 0.002) * 0.2, clicks(d, [0.0], r, 0.12, 0.001), d=d)
        return room(s, r, 0.35, 0.15, 0.6, 0.006)
    return build


PIANO_NOTES = {"piano_0": 523.25, "piano_1": 587.33, "piano_2": 659.26, "piano_3": 783.99, "piano_4": 880.0, "piano_5": 1046.5}   # C D E G A C', the six keys of the music app
PIANO = []
for _n, _f in PIANO_NOTES.items():
    _b = _piano(_f)
    _b.__name__ = _n
    PIANO.append(_b)

@opts(drive=1.1, peak=0.8)
def printer_feed(r):
    """A printer pulling in a sheet: a low motor whirr (95 Hz saw, slightly wobbling), a dry paper-roller hiss and four stepper clicks."""
    d = 0.9
    motor = tone(95, d, "saw") * swell(d, 0.1, 0.25) * 0.25
    hiss = svf(noise(d, r), 4200, 0.7, "bp") * swell(d, 0.15, 0.3) * 0.25
    clk = clicks(d, [0.1, 0.3, 0.5, 0.7], r, 0.35, 0.0015)
    return room(mix(motor, hiss, clk, d=d), r, 0.15, 0.08, 0.5, 0.004)


@opts(drive=1.25, peak=0.9)
def printer_jam(r):
    """The printer jams: a grinding chew (band-passed noise gating at 18 Hz), a falling motor whine (220 -> 60 Hz) and a hard clunk at the end."""
    d = 1.1
    t_ = tt(d)
    chew = svf(noise(d, r), 1400, 1.0, "bp") * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 18 * t_))) * expd(d, 0.5, 0.005) * 0.5
    whine = sweep(220, 60, 0.8, "exp", "saw") * expd(0.8, 0.35, 0.005) * 0.3
    s = mix(chew, whine, d=d)
    s = place(s, sweep(130, 60, 0.15, "exp", "sine") * expd(0.15, 0.05, 0.002), 0.8, 1.0)
    s = place(s, svf(noise(0.08, r), 900, 0.9, "bp") * expd(0.08, 0.03, 0.001), 0.8, 0.7)
    return room(s, r, 0.25, 0.1, 0.4, 0.004)


def _creak(d, r, f0, f1, vib=14.0):
    """A hinge creak: band-passed noise whose centre sweeps f0 -> f1 with a fast wobble, so it squeals and shudders like a dry hinge."""
    t_ = tt(d)
    fc = np.geomspace(f0, f1, n_of(d)) * (1.0 + 0.06 * np.sin(2 * np.pi * vib * t_))
    return svf(noise(d, r), fc, 6.0, "bp") * swell(d, 0.1, 0.35)


@opts(drive=1.1, peak=0.85)
def door_unlock(r):
    """The lounge door unlocks: a key turning (two metallic clicks 90 ms apart), a latch clunk and a short hinge creak as it gives."""
    d = 1.0
    s = clicks(d, [0.0, 0.09], r, 0.9, 0.0012)
    s = s + svf(noise(d, r), 2400, 1.0, "bp") * expd(d, 0.02, 0.0005) * 0.4
    s = place(s, sweep(150, 70, 0.12, "exp", "sine") * expd(0.12, 0.04, 0.002) * 0.7, 0.2, 1.0)
    s = place(s, _creak(0.5, r, 500, 900) * 0.18, 0.3, 1.0)
    return room(s, r, 0.35, 0.15, 0.5, 0.005)


@opts(drive=1.1, peak=0.85)
def door_open(r):
    """A heavy office door opening: a long hinge creak (400 -> 1100 Hz squeal), a rubber seal pop at the start and a soft thud against the wall at the end."""
    d = 1.3
    s = _creak(1.0, r, 400, 1100) * 0.3
    s = np.concatenate([s, np.zeros(n_of(d) - len(s))])
    s = place(s, svf(noise(0.06, r), 1200, 0.8, "bp") * expd(0.06, 0.02, 0.001) * 0.6, 0.0, 1.0)
    s = place(s, sweep(110, 55, 0.2, "exp", "sine") * expd(0.2, 0.07, 0.002) * 0.6, 1.0, 1.0)
    return room(s, r, 0.4, 0.15, 0.4, 0.006)


@opts(drive=1.1, peak=0.85)
def door_close(r):
    """The door closing behind you: a short descending creak (900 -> 500 Hz), then a wood thud, a latch click and a settling rattle."""
    d = 1.0
    s = _creak(0.45, r, 900, 500) * 0.25
    s = np.concatenate([s, np.zeros(n_of(d) - len(s))])
    s = place(s, sweep(130, 50, 0.22, "exp", "sine") * expd(0.22, 0.08, 0.002) * 0.9, 0.4, 1.0)
    s = place(s, svf(noise(0.1, r), 700, 0.8, "bp") * expd(0.1, 0.03, 0.001) * 0.6, 0.4, 1.0)
    s = place(s, clicks(0.1, [0.0], r, 0.8, 0.0012), 0.55, 1.0)
    return room(s, r, 0.35, 0.15, 0.4, 0.006)


@opts(drive=1.15, peak=0.9)
def locker_open(r):
    """A metal locker flung open: an inharmonic clang (FM bell at 260 Hz, ratio 2.76), a hinge squeal and a rattle of the loose door."""
    d = 1.4
    clang = fm_bell(260, 1.0, 0.25, 2.76, 2.5, 0.12, 0.001) * 0.6
    s = np.concatenate([clang, np.zeros(n_of(d) - len(clang))])
    s = place(s, _creak(0.4, r, 1800, 2600, 20.0) * 0.12, 0.0, 1.0)
    s = place(s, clicks(0.5, [0.0, 0.07, 0.15, 0.26], r, 0.5, 0.002), 0.3, 1.0)
    return room(s, r, 0.5, 0.2, 0.7, 0.006)


@opts(drive=1.05, peak=0.8)
def badge_get(r):
    """An ID badge: a card-swipe whoosh (band-passed noise rising 1.5 -> 4 kHz) and the reader's two-note confirm beep (1800 / 2400 Hz)."""
    d = 0.6
    swipe = svf(noise(0.18, r), np.geomspace(1500, 4000, n_of(0.18)), 1.0, "bp") * swell(0.18, 0.08, 0.08) * 0.4
    s = np.concatenate([swipe, np.zeros(n_of(d) - len(swipe))])
    s = place(s, tone(1800, 0.1) * expd(0.1, 0.05, 0.002) * 0.4, 0.2, 1.0)
    s = place(s, tone(2400, 0.16) * expd(0.16, 0.08, 0.002) * 0.4, 0.31, 1.0)
    return room(s, r, 0.2, 0.1, 0.8, 0.004)


def _rack(freq):
    @opts(drive=1.1, peak=0.8)
    def build(r):
        d = 0.7
        beep = tone(freq, d, "square") * expd(d, 0.18, 0.003) * 0.22 + tone(freq * 2, d) * expd(d, 0.1, 0.003) * 0.15
        hum = tone(120, d) * swell(d, 0.05, 0.5) * 0.1
        return room(mix(beep, hum, clicks(d, [0.0], r, 0.2, 0.001), d=d), r, 0.25, 0.12, 0.6, 0.004)
    return build


RACK_NOTES = {"rack_tone_0": 392.0, "rack_tone_1": 493.88, "rack_tone_2": 622.25, "rack_tone_3": 783.99}   # the four LED tiles: G4 B4 D#5 G5 (an augmented-feeling server chord)
RACK = []
for _n, _f in RACK_NOTES.items():
    _b = _rack(_f)
    _b.__name__ = _n
    RACK.append(_b)


@opts(drive=1.25, peak=0.85)
def rack_wrong(r):
    """The wrong tile of the LED rack: two falling square-wave beeps (330 -> 220 Hz) and a short low buzz."""
    d = 0.7
    s = tone(330, 0.18, "square") * expd(0.18, 0.1, 0.002) * 0.3
    s = np.concatenate([s, np.zeros(n_of(d) - len(s))])
    s = place(s, tone(220, 0.3, "square") * expd(0.3, 0.15, 0.002) * 0.3, 0.2, 1.0)
    s = place(s, sweep(90, 60, 0.3, "exp", "saw") * expd(0.3, 0.12, 0.003) * 0.25, 0.2, 1.0)
    return room(s, r, 0.2, 0.1, 0.4, 0.004)


@opts(drive=1.05, peak=0.9)
def rack_solved(r):
    """The rack accepts the sequence: the four tile notes played upward as a quick arpeggio, then a rising data-chirp sweep (600 -> 3000 Hz)."""
    d = 1.4
    s = _arp(d, [392.0, 493.88, 622.25, 783.99, 987.77], 0.07, bell=(0.2, 2.0, 0.8, 0.05), gain=0.4)
    s = place(s, sweep(600, 3000, 0.4, "exp", "square") * expd(0.4, 0.2, 0.002) * 0.12, 0.35, 1.0)
    return room(s, r, 0.5, 0.2, 0.8, 0.008)


@opts(drive=1.1, peak=0.9)
def aisle_open(r):
    """The cold aisle door opens: a hydraulic hiss (high-passed noise fading over 0.8 s), a heavy clunk and a low rising fan hum (70 -> 110 Hz)."""
    d = 1.6
    hiss = svf(noise(0.9, r), 5200, 0.6, "bp") * expd(0.9, 0.4, 0.01) * 0.25
    s = np.concatenate([hiss, np.zeros(n_of(d) - len(hiss))])
    s = place(s, sweep(120, 50, 0.25, "exp", "sine") * expd(0.25, 0.09, 0.002) * 0.9, 0.0, 1.0)
    s = place(s, sweep(70, 110, 1.2, "exp", "saw") * swell(1.2, 0.3, 0.6) * 0.12, 0.3, 1.0)
    return room(s, r, 0.5, 0.2, 0.4, 0.006)


@opts(drive=1.2, peak=0.85)
def stream_warn(r):
    """A new wave in the upload stream: a rising two-tone alarm blip (500 / 750 Hz, square) over a short data-burst of noise."""
    d = 0.6
    s = tone(500, 0.12, "square") * expd(0.12, 0.08, 0.002) * 0.25
    s = np.concatenate([s, np.zeros(n_of(d) - len(s))])
    s = place(s, tone(750, 0.16, "square") * expd(0.16, 0.1, 0.002) * 0.25, 0.14, 1.0)
    s = place(s, svf(noise(0.25, r), 3000, 0.8, "bp") * expd(0.25, 0.1, 0.002) * 0.15, 0.3, 1.0)
    return room(s, r, 0.2, 0.1, 0.6, 0.004)


def _rack(freq):
    @opts(drive=1.1, peak=0.8)
    def build(r):
        d = 0.7
        beep = tone(freq, d, "square") * expd(d, 0.18, 0.003) * 0.22 + tone(freq * 2, d) * expd(d, 0.1, 0.003) * 0.15
        hum = tone(120, d) * swell(d, 0.05, 0.5) * 0.1
        return room(mix(beep, hum, clicks(d, [0.0], r, 0.2, 0.001), d=d), r, 0.25, 0.12, 0.6, 0.004)
    return build


RACK_NOTES = {"rack_tone_0": 392.0, "rack_tone_1": 493.88, "rack_tone_2": 622.25, "rack_tone_3": 783.99}   # the four LED tiles: G4 B4 D#5 G5 (an augmented-feeling server chord)
RACK = []
for _n, _f in RACK_NOTES.items():
    _b = _rack(_f)
    _b.__name__ = _n
    RACK.append(_b)


@opts(drive=1.25, peak=0.85)
def rack_wrong(r):
    """The wrong tile of the LED rack: two falling square-wave beeps (330 -> 220 Hz) and a short low buzz."""
    d = 0.7
    s = tone(330, 0.18, "square") * expd(0.18, 0.1, 0.002) * 0.3
    s = np.concatenate([s, np.zeros(n_of(d) - len(s))])
    s = place(s, tone(220, 0.3, "square") * expd(0.3, 0.15, 0.002) * 0.3, 0.2, 1.0)
    s = place(s, sweep(90, 60, 0.3, "exp", "saw") * expd(0.3, 0.12, 0.003) * 0.25, 0.2, 1.0)
    return room(s, r, 0.2, 0.1, 0.4, 0.004)


@opts(drive=1.05, peak=0.9)
def rack_solved(r):
    """The rack accepts the sequence: the four tile notes played upward as a quick arpeggio, then a rising data-chirp sweep (600 -> 3000 Hz)."""
    d = 1.4
    s = _arp(d, [392.0, 493.88, 622.25, 783.99, 987.77], 0.07, bell=(0.2, 2.0, 0.8, 0.05), gain=0.4)
    s = place(s, sweep(600, 3000, 0.4, "exp", "square") * expd(0.4, 0.2, 0.002) * 0.12, 0.35, 1.0)
    return room(s, r, 0.5, 0.2, 0.8, 0.008)


@opts(drive=1.1, peak=0.9)
def aisle_open(r):
    """The cold aisle door opens: a hydraulic hiss (high-passed noise fading over 0.8 s), a heavy clunk and a low rising fan hum (70 -> 110 Hz)."""
    d = 1.6
    hiss = svf(noise(0.9, r), 5200, 0.6, "bp") * expd(0.9, 0.4, 0.01) * 0.25
    s = np.concatenate([hiss, np.zeros(n_of(d) - len(hiss))])
    s = place(s, sweep(120, 50, 0.25, "exp", "sine") * expd(0.25, 0.09, 0.002) * 0.9, 0.0, 1.0)
    s = place(s, sweep(70, 110, 1.2, "exp", "saw") * swell(1.2, 0.3, 0.6) * 0.12, 0.3, 1.0)
    return room(s, r, 0.5, 0.2, 0.4, 0.006)


@opts(drive=1.2, peak=0.85)
def stream_warn(r):
    """A new wave in the upload stream: a rising two-tone alarm blip (500 / 750 Hz, square) over a short data-burst of noise."""
    d = 0.6
    s = tone(500, 0.12, "square") * expd(0.12, 0.08, 0.002) * 0.25
    s = np.concatenate([s, np.zeros(n_of(d) - len(s))])
    s = place(s, tone(750, 0.16, "square") * expd(0.16, 0.1, 0.002) * 0.25, 0.14, 1.0)
    s = place(s, svf(noise(0.25, r), 3000, 0.8, "bp") * expd(0.25, 0.1, 0.002) * 0.15, 0.3, 1.0)
    return room(s, r, 0.2, 0.1, 0.6, 0.004)


BUILDERS = [app_open, app_close, app_tick, pw_deny, pw_grant, glitch_wave, switch_on, switch_off,
            spot_enter, spot_tick, spot_done, cp_ok, cp_bad, dig_tick, dig_done, key_press, mg_ok, mg_bad, shutter, app_done, printer_feed, printer_jam,
            door_unlock, door_open, door_close, locker_open, badge_get,
            rack_wrong, rack_solved, aisle_open, stream_warn] + PIANO + RACK

if __name__ == "__main__":
    print("writing to", os.path.abspath(g.OUT))
    only = sys.argv[2:]   # optional: names to render, so the other sounds are left alone
    for b in BUILDERS:
        if not only or b.__name__ in only:
            g.render(b.__name__, b)
