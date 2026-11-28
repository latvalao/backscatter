#!/usr/bin/env python3
"""Synthesises Backscatter's sound effects (original, CC0) into
presentation/audio/sfx/*.wav. Rerun after changing a recipe:
    python3 tools/gen_sfx.py

Recipes are layered: a sharp transient, a body, a low thump, then an outdoor
reverb tail and a late slap echo, so shots sound like they happen in a valley
instead of in a box. Loops (engines, rotor, wind, rain) are built to be exactly
periodic: noise is shaped in the frequency domain (circular, so the end flows
into the start) and every tone and modulation has a whole number of cycles in
the loop, so there is no seam to click. Godot imports them with loop_mode =
forward (see the .import files), which is what the game relies on."""
import os
import wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "presentation", "audio", "sfx")
rng = np.random.default_rng(1234)


def t_of(n):
    return np.arange(n) / SR


def noise(n):
    return rng.standard_normal(n)


def band(x, lo, hi, circular=False, slope=0.25):
    """Band-pass in the frequency domain with soft (log-gaussian) skirts.
    circular=True keeps the signal periodic (for loops); otherwise it is
    zero-padded so the tail doesn't wrap onto the start."""
    n = len(x)
    m = n if circular else 1 << int(np.ceil(np.log2(2 * n)))
    X = np.fft.rfft(x, m)
    f = np.fft.rfftfreq(m, 1.0 / SR)
    f[0] = 1e-3
    lf = np.log2(f)
    g = np.ones_like(f)
    if lo > 0:
        g *= np.where(f < lo, np.exp(-((lf - np.log2(lo)) ** 2) / (2 * slope)), 1.0)
    if hi > 0:
        g *= np.where(f > hi, np.exp(-((lf - np.log2(hi)) ** 2) / (2 * slope)), 1.0)
    return np.fft.irfft(X * g, m)[:n]


def decay(n, tau, attack=0.0005):
    t = t_of(n)
    return np.minimum(t / attack, 1.0) * np.exp(-t / tau)


def pad(x, n):
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n]


def convolve(x, ir):
    m = 1 << int(np.ceil(np.log2(len(x) + len(ir))))
    return np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(ir, m), m)[:len(x) + len(ir) - 1]


def reverb(x, tau, mix, lo=120, hi=5000, predelay=0.012):
    """Outdoor tail: diffuse noise IR, darker as it decays."""
    n = int(SR * tau * 5)
    ir = band(noise(n), lo, hi) * decay(n, tau, 0.004)
    dark = band(noise(n), lo, hi * 0.3) * decay(n, tau * 1.4, 0.01)
    ir = ir * np.exp(-t_of(n) / (tau * 0.6)) + dark * 0.8
    ir = np.concatenate([np.zeros(int(SR * predelay)), ir])
    wet = convolve(x, ir)
    wet /= np.max(np.abs(wet)) + 1e-9
    out = pad(x, len(wet)) / (np.max(np.abs(x)) + 1e-9)
    return out + wet * mix


def echo(x, delay, gain, hi=1800):
    d = int(SR * delay)
    e = band(np.concatenate([np.zeros(d), x]), 80, hi)
    return pad(x, len(e)) + e * gain


def trim(x, seconds):
    n = int(SR * seconds)
    x = pad(x, n)
    f = int(SR * 0.08)
    x[-f:] *= np.linspace(1, 0, f) ** 2
    return x


def write(name, x, gain=0.9, drive=1.0):
    x = x / (np.max(np.abs(x)) + 1e-9)
    if drive != 1.0:
        x = np.tanh(x * drive) / np.tanh(drive)
    x = x * gain
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ------------------------------------------------------------ one-shots

def report(n, crack_tau, body_lo, body_hi, body_tau, thump_hz, thump_tau, thump):
    t = t_of(n)
    crack = band(noise(n), 2500, 14000) * decay(n, crack_tau, 0.0002)
    body = band(noise(n), body_lo, body_hi) * decay(n, body_tau, 0.0008)
    low = np.sin(2 * np.pi * thump_hz * t * (1 - 0.25 * t)) * decay(n, thump_tau, 0.002)
    return crack * 0.9 + body + low * thump


def rifle():
    n = int(SR * 0.2)
    dry = report(n, 0.003, 200, 3500, 0.03, 95, 0.025, 0.5)
    return trim(echo(reverb(dry, 0.32, 0.45), 0.24, 0.22), 1.3)


def burst(single, rounds, gap, jitter=0.006):
    n = int(SR * (gap * rounds + 0.4))
    out = np.zeros(n)
    for i in range(rounds):
        at = int(SR * (i * gap + rng.uniform(-jitter, jitter) + jitter))
        s = single * rng.uniform(0.85, 1.0)
        out[at:at + len(s)] += s[:n - at]
    return out


def mg():
    n = int(SR * 0.14)
    one = report(n, 0.0025, 250, 3800, 0.022, 110, 0.02, 0.45)
    dry = burst(one, 4, 0.085)
    return trim(echo(reverb(dry, 0.3, 0.4), 0.26, 0.2), 1.5)


def autocannon():
    n = int(SR * 0.25)
    one = report(n, 0.004, 120, 2200, 0.05, 70, 0.06, 0.9)
    dry = burst(one, 2, 0.32)
    return trim(echo(reverb(dry, 0.5, 0.5), 0.3, 0.25), 2.0)


def cannon():
    n = int(SR * 0.9)
    t = t_of(n)
    dry = report(n, 0.006, 60, 1800, 0.12, 42, 0.25, 1.4)
    dry += band(noise(n), 25, 120) * decay(n, 0.3, 0.004) * 0.8
    return trim(echo(reverb(dry, 1.0, 0.6, 60, 2500), 0.55, 0.35, 900), 3.5)


def artillery_fire():
    n = int(SR * 1.2)
    dry = report(n, 0.008, 40, 1200, 0.2, 34, 0.35, 1.6)
    dry += band(noise(n), 20, 90) * decay(n, 0.5, 0.006)
    return trim(echo(reverb(dry, 1.5, 0.7, 40, 1800), 0.8, 0.4, 700), 4.5)


def explosion(size):
    n = int(SR * (0.8 + size))
    t = t_of(n)
    blast = band(noise(n), 30, 1600 / (1 + size)) * decay(n, 0.12 + size * 0.25, 0.002)
    sub = np.sin(2 * np.pi * (48 - size * 8) * t * (1 - 0.35 * t / t[-1])) * decay(n, 0.18 + size * 0.2, 0.003)
    crack = band(noise(n), 1500, 9000) * decay(n, 0.008, 0.0003)
    debris = np.zeros(n)
    for _ in range(int(40 + size * 60)):
        at = int(SR * rng.uniform(0.15, 0.6 + size * 0.9))
        ln = int(SR * 0.02)
        if at + ln < n:
            debris[at:at + ln] += band(noise(ln), 800, 6000) * decay(ln, 0.004) * rng.uniform(0.05, 0.3) * np.exp(-at / SR / (0.5 + size))
    dry = blast * 1.2 + sub * 1.3 + crack * 0.8 + debris
    return trim(echo(reverb(dry, 0.9 + size * 0.7, 0.55, 40, 2200), 0.5 + size * 0.3, 0.3, 800), 2.2 + size * 2.0)


def missile():
    n = int(SR * 2.4)
    t = t_of(n)
    pop = report(int(SR * 0.3), 0.004, 150, 3000, 0.04, 80, 0.04, 0.6)
    roar_env = np.minimum(t / 0.06, 1.0) * np.exp(-np.maximum(t - 0.4, 0) / 0.7)
    roar = band(noise(n), 400, 5000) * roar_env * (1 + 0.2 * np.sin(2 * np.pi * 23 * t))
    whistle = np.sin(2 * np.pi * (1900 - 500 * t / t[-1]) * t) * roar_env * 0.08
    dry = pad(pop, n) + roar * 0.7 + whistle
    return trim(reverb(dry, 0.6, 0.35), 2.6)


# ------------------------------------------------------------ loops

def cyc(freq, dur):
    """Nearest frequency with a whole number of cycles in the loop."""
    return max(1, round(freq * dur)) / dur


def engine(dur, f0, harmonics, whine_hz, clank_hz, clank, rumble_hi):
    n = int(SR * dur)
    t = t_of(n)
    f = cyc(f0, dur)
    x = np.zeros(n)
    for h in range(1, harmonics + 1):
        x += np.sin(2 * np.pi * f * h * t + h * 1.7) * (0.9 / h ** 1.1)
    # cylinder firing: a lumpy pulse train at the firing rate
    fire = cyc(f0 * 0.5, dur)
    x *= 0.75 + 0.25 * np.sin(2 * np.pi * fire * t) ** 8
    x += band(noise(n), 25, rumble_hi, circular=True) * 1.2
    x += np.sin(2 * np.pi * cyc(whine_hz, dur) * t) * 0.03 * (1 + 0.3 * np.sin(2 * np.pi * cyc(0.5, dur) * t))
    if clank > 0:
        period = cyc(clank_hz, dur)
        count = int(round(period * dur))
        ln = int(SR * 0.03)
        for i in range(count):
            at = int(i * n / count + rng.integers(-200, 200)) % n
            hit = band(noise(ln), 700, 3800) * decay(ln, 0.006) * rng.uniform(0.4, 1.0)
            idx = (at + np.arange(ln)) % n
            x[idx] += hit * clank
    return x


def rotor(dur):
    n = int(SR * dur)
    t = t_of(n)
    blade = cyc(11.0, dur)
    count = int(round(blade * dur))
    x = band(noise(n), 40, 400, circular=True) * 0.6
    ln = int(SR * 0.06)
    for i in range(count):
        at = int(i * n / count)
        idx = (at + np.arange(ln)) % n
        x[idx] += band(noise(ln), 60, 900) * decay(ln, 0.018, 0.002) * 1.6
    x += np.sin(2 * np.pi * cyc(2400, dur) * t) * 0.025
    return x


def wind(dur):
    n = int(SR * dur)
    t = t_of(n)
    gust = 0.55 + 0.25 * np.sin(2 * np.pi * cyc(0.17, dur) * t) + 0.2 * np.sin(2 * np.pi * cyc(0.41, dur) * t + 1.3)
    x = band(noise(n), 60, 500, circular=True) * gust
    x += band(noise(n), 700, 1400, circular=True) * 0.12 * gust ** 3
    return x


def rain(dur):
    n = int(SR * dur)
    x = band(noise(n), 1200, 10000, circular=True) * 0.45
    x += band(noise(n), 150, 900, circular=True) * 0.35
    ln = int(SR * 0.012)
    for _ in range(int(dur * 120)):
        at = int(rng.integers(0, n))
        idx = (at + np.arange(ln)) % n
        x[idx] += band(noise(ln), 2000, 9000) * decay(ln, 0.002) * rng.uniform(0.2, 0.9)
    return x


os.makedirs(OUT, exist_ok=True)
write("rifle", rifle(), 0.9, 1.6)
write("mg", mg(), 0.85, 1.6)
write("autocannon", autocannon(), 0.9, 1.8)
write("cannon", cannon(), 0.95, 2.0)
write("artillery_fire", artillery_fire(), 0.95, 2.0)
write("explosion_small", explosion(0.5), 0.95, 2.0)
write("explosion_big", explosion(1.6), 0.95, 2.4)
write("missile", missile(), 0.8, 1.4)
write("engine_tracked", engine(6.0, 30, 9, 1350, 9.0, 0.5, 180), 0.6, 1.3)
write("engine_wheeled", engine(6.0, 42, 7, 620, 0.0, 0.0, 260), 0.55, 1.2)
write("rotor", rotor(4.0), 0.75, 1.4)
write("wind", wind(12.0), 0.5)
write("rain", rain(8.0), 0.5)
n = int(SR * 0.32)
t = t_of(n)
squelch = band(noise(n), 500, 3200) * 0.5 * decay(n, 0.12, 0.002) + 0.25 * np.sin(2 * np.pi * 1150 * t) * (t < 0.05)
write("radio", squelch, 0.55)
n = int(SR * 0.06)
write("click", np.sin(2 * np.pi * 1800 * t_of(n)) * decay(n, 0.012, 0.001), 0.4)
# loops import with loop_mode = forward (whole file)
for name in ("engine_tracked", "engine_wheeled", "rotor", "wind", "rain"):
    p = os.path.join(OUT, name + ".wav.import")
    if os.path.exists(p):
        s = open(p).read().replace("edit/loop_mode=0", "edit/loop_mode=2")
        open(p, "w").write(s)
print("written to", os.path.abspath(OUT))
