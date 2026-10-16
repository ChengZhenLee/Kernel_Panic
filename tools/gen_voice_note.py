#!/usr/bin/env python3
"""Kernel Panic: the phone app's VOICE NOTE (assets/audio/announcer/voice_note.wav), a synthesized voice like the Announcer's.

Pipeline: Windows speech synthesis (System.Speech, voice "Microsoft Zira Desktop", slow rate) renders the line to a mono WAV, then numpy makes it a
degraded voicemail: band-limited 300-3400 Hz (phone line), 12-bit-ish crush, a faint 90 Hz-wobble ring modulation for the "not quite a person" edge,
a noise floor with a few line crackles, a short echo, then 44.1 kHz stereo and normalised hot (the Announcer clips are ~12 dB hotter
than effects; Sfx.ANNOUNCER_GAIN brings them down).
usage: python tools/gen_voice_note.py        (Windows only; needs numpy)
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "announcer", "voice_note.wav")
TEXT = "It's me again. I know you cannot answer. I just wanted someone to hear it ring."


def speak(path):
    ps = ("Add-Type -AssemblyName System.Speech; $s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
          "$s.SelectVoice('Microsoft Zira Desktop'); $s.Rate = -3; $s.SetOutputToWaveFile('%s'); $s.Speak(\"%s\"); $s.Dispose()" % (path, TEXT.replace("'", "''")))
    subprocess.run(["powershell", "-NoProfile", "-Command", ps], check=True)


def read(path):
    with wave.open(path) as w:
        sr, n, ch = w.getframerate(), w.getnframes(), w.getnchannels()
        x = np.frombuffer(w.readframes(n), dtype="<i2").astype(np.float64) / 32768.0
    return (x.reshape(-1, ch).mean(axis=1) if ch > 1 else x), sr


def bandpass(x, sr, lo, hi):
    f = np.fft.rfftfreq(len(x), 1.0 / sr)
    X = np.fft.rfft(x)
    X *= np.clip((f - lo) / 100.0, 0, 1) * np.clip((hi - f) / 300.0, 0, 1)
    return np.fft.irfft(X, len(x))


def main():
    rng = np.random.default_rng(7)
    tmp = os.path.join(tempfile.gettempdir(), "kp_voice_raw.wav")
    speak(tmp)
    x, sr = read(tmp)
    x = bandpass(x, sr, 300, 3400)
    x = np.round(x * 2048) / 2048                                         # crush
    t = np.arange(len(x)) / sr
    x = x * (0.82 + 0.18 * np.sin(2 * np.pi * 90 * t))                    # ring-mod wobble
    x = np.tanh(x * 2.2)
    x += bandpass(rng.normal(0, 0.012, len(x)), sr, 300, 3400)            # line noise
    for _ in range(6):                                                    # crackles
        i = int(rng.integers(0, len(x) - 200))
        n = int(rng.integers(20, 90))
        x[i:i + n] += rng.normal(0, 0.18, n)
    echo = np.zeros(len(x) + int(0.35 * sr))
    echo[:len(x)] += x
    echo[int(0.18 * sr):int(0.18 * sr) + len(x)] += 0.22 * x
    echo[int(0.35 * sr):int(0.35 * sr) + len(x)] += 0.08 * x
    y = np.concatenate([np.zeros(int(0.2 * sr)), echo])
    n_out = int(len(y) * 44100 / sr)                                      # to 44.1 kHz
    y = np.interp(np.linspace(0, len(y) - 1, n_out), np.arange(len(y)), y)
    y = y / np.max(np.abs(y)) * 0.95
    st = np.repeat(np.round(y * 32767).astype("<i2")[:, None], 2, axis=1)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with wave.open(OUT, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(44100); w.writeframes(st.tobytes())
    print("wrote", OUT, "%.1f s" % (len(y) / 44100))


if __name__ == "__main__":
    main()
