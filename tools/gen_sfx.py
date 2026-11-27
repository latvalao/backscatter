#!/usr/bin/env python3
"""Synthesises Backscatter's sound effects (original, CC0) into
presentation/audio/sfx/*.wav. Rerun after changing a recipe:
    python3 tools/gen_sfx.py
Everything is filtered noise, decaying tones and simple envelopes."""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "presentation", "audio", "sfx")
rng = np.random.default_rng(1234)


def noise(n):
    return rng.uniform(-1.0, 1.0, n)


def lowpass(x, cutoff):
    a = np.exp(-2.0 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        y[i] = acc
    return y


def env(n, attack, decay):
    t = np.arange(n) / SR
    e = np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-t / decay)
    return e


def write(name, x, gain=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def shot(dur, cutoff, decay, body_hz=0.0, body=0.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = lowpass(noise(n), cutoff) * env(n, 0.001, decay)
    if body_hz:
        x += body * np.sin(2 * np.pi * body_hz * t * (1 - 0.4 * t / dur)) * env(n, 0.002, decay * 1.5)
    return x


def boom(dur, cutoff, decay, sub_hz):
    n = int(SR * dur)
    t = np.arange(n) / SR
    rumble = lowpass(noise(n), cutoff) * env(n, 0.004, decay)
    sub = np.sin(2 * np.pi * sub_hz * t * (1.0 - 0.5 * t / dur)) * env(n, 0.003, decay * 0.7)
    crack = lowpass(noise(n), 4000) * env(n, 0.0005, 0.02) * 0.6
    return rumble + 0.8 * sub + crack


def loop(dur, fn):
    n = int(SR * dur)
    x = fn(n)
    # crossfade the ends so it loops without a click
    f = int(SR * 0.05)
    ramp = np.linspace(0, 1, f)
    x[:f] = x[:f] * ramp + x[-f:] * (1 - ramp)
    return x[:-f]


os.makedirs(OUT, exist_ok=True)
write("rifle", shot(0.35, 3200, 0.05, 220, 0.4))
write("mg", shot(0.18, 3600, 0.035, 260, 0.3))
write("autocannon", shot(0.5, 1800, 0.09, 110, 0.8))
write("cannon", boom(1.6, 700, 0.35, 48))
write("artillery_fire", boom(2.2, 500, 0.6, 38))
write("explosion_small", boom(1.2, 1200, 0.25, 60))
write("explosion_big", boom(2.8, 450, 0.8, 32))
n = int(SR * 1.2)
t = np.arange(n) / SR
whoosh = lowpass(noise(n), 1600) * np.minimum(t / 0.05, 1.0) * np.exp(-t / 0.6)
write("missile", whoosh)
write("engine_tracked", loop(2.5, lambda n: lowpass(noise(n), 160) * 0.7
      + 0.35 * np.sin(2 * np.pi * 31 * np.arange(n) / SR) * (1 + 0.3 * np.sin(2 * np.pi * 7 * np.arange(n) / SR))
      + 0.2 * lowpass(noise(n), 900) * (np.sin(2 * np.pi * 9 * np.arange(n) / SR) > 0.6)), 0.7)
write("engine_wheeled", loop(2.5, lambda n: lowpass(noise(n), 220) * 0.6
      + 0.4 * np.sin(2 * np.pi * 52 * np.arange(n) / SR)), 0.6)
write("rotor", loop(2.0, lambda n: lowpass(noise(n), 400) * (0.4 + 0.6 * (np.sin(2 * np.pi * 9.5 * np.arange(n) / SR) > 0.3))), 0.8)
write("rain", loop(4.0, lambda n: lowpass(noise(n), 5000) * 0.5 + lowpass(noise(n), 700) * 0.5), 0.5)
write("wind", loop(5.0, lambda n: lowpass(noise(n), 260) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.3 * np.arange(n) / SR))), 0.5)
n = int(SR * 0.28)
t = np.arange(n) / SR
squelch = lowpass(noise(n), 3500) * 0.5 * env(n, 0.002, 0.12) + 0.3 * np.sin(2 * np.pi * 1150 * t) * (t < 0.06)
write("radio", squelch, 0.6)
n = int(SR * 0.06)
t = np.arange(n) / SR
write("click", np.sin(2 * np.pi * 1800 * t) * env(n, 0.001, 0.012), 0.4)
print("written to", os.path.abspath(OUT))
