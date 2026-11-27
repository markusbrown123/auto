#!/usr/bin/env python3
"""Hollow Reign - fully procedural audio generator (no samples, 100% original).

Argument-free, deterministic (every sound seeds its RNG from its own name).
Output: ../assets/audio/{sfx,amb,music}.   Needs numpy, scipy, ffmpeg (OGG).
"""
import os, json, zlib, subprocess, tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio"))
PEAK_SFX = 10 ** (-3 / 20)


# ----------------------------------------------------------------- basics
def rng(name): return np.random.default_rng(zlib.crc32(name.encode()))
def mtof(m): return 440.0 * 2 ** ((np.asarray(m, dtype=float) - 69) / 12)
def tt(n): return np.arange(n) / SR

def bf(x, kind, f, order=2):
    f = np.atleast_1d(np.asarray(f, dtype=float))
    f = np.clip(f, 15, 20000)
    sos = signal.butter(order, f if len(f) > 1 else f[0], btype=kind, fs=SR, output="sos")
    return signal.sosfilt(sos, x)
def lp(x, f, o=2): return bf(x, "lowpass", f, o)
def hp(x, f, o=2): return bf(x, "highpass", f, o)
def bp(x, lo, hi, o=2): return bf(x, "bandpass", [lo, hi], o)

def circ(fn, x):
    """apply a causal filter fn to a periodic signal without a seam"""
    n = len(x)
    return fn(np.concatenate([x, x, x]))[n:2 * n]

def circ_conv(x, k):
    L = len(x)
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(k[:L], n=L), n=L)

def place(buf, seg, start):
    L = len(buf); start = int(start) % L
    m = min(len(seg), L - start)
    buf[start:start + m] += seg[:m]
    rest = seg[m:]
    while len(rest):
        k = min(len(rest), L); buf[:k] += rest[:k]; rest = rest[k:]

def sweep_bp(x, fc, q=2.0, block=256):
    out = np.zeros_like(x); zi = None
    for i in range(0, len(x), block):
        f = float(fc[min(i + block // 2, len(x) - 1)])
        lo = max(f * (1 - 0.5 / q), 20); hi = min(f * (1 + 0.5 / q), 20000)
        sos = signal.butter(2, [lo, hi], btype="bandpass", fs=SR, output="sos")
        if zi is None: zi = np.zeros((sos.shape[0], 2))
        out[i:i + block], zi = signal.sosfilt(sos, x[i:i + block], zi=zi)
    return out

def modal(n, freqs, amps, decays, r=None):
    t = tt(n); y = np.zeros(n)
    for i, (f, a, d) in enumerate(zip(freqs, amps, decays)):
        if f >= 20000: continue
        ph = r.uniform(0, 6.283) if r is not None else 0.0
        y += a * np.exp(-t / d) * np.sin(2 * np.pi * f * t + ph)
    return y

def sine_drop(n, f0, f1, tau_f, tau_a):
    t = tt(n); f = f1 + (f0 - f1) * np.exp(-t / tau_f)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / tau_a)

def noise_burst(r, n, tau, lo=None, hi=None):
    y = r.standard_normal(n) * np.exp(-tt(n) / tau)
    if lo and hi: y = bp(y, lo, hi)
    elif lo: y = hp(y, lo)
    elif hi: y = lp(y, hi)
    return y

def clicks(r, n, times, amps, tau, lo, hi):
    buf = np.zeros(n)
    for tm, a in zip(times, amps):
        i = int(tm * SR); m = min(int(tau * 8 * SR), n - i)
        if m > 8: buf[i:i + m] += a * r.standard_normal(m) * np.exp(-tt(m) / tau)
    return bp(buf, lo, hi)

def add(dst, src, at):
    i = int(at * SR)
    if i + len(src) > len(dst): dst = np.concatenate([dst, np.zeros(i + len(src) - len(dst))])
    dst[i:i + len(src)] += src
    return dst

def smooth(x): x = np.clip(x, 0, 1); return x * x * (3 - 2 * x)

def saw(f, phase0=0.0):
    f = np.broadcast_to(np.asarray(f, dtype=float), np.shape(f)) if np.ndim(f) else f
    dt = np.asarray(f)
    ph = (phase0 + np.cumsum(dt / SR)) % 1.0
    dt = dt / SR
    bl = np.zeros_like(ph)
    m = ph < dt; x = ph[m] / dt[m]; bl[m] = 2 * x - x * x - 1
    m = ph > 1 - dt; x = (ph[m] - 1) / dt[m]; bl[m] = x * x + 2 * x + 1
    return 2 * ph - 1 - bl

def reverb_ir(rt60, r, pre=0.012):
    n = int(rt60 * 1.3 * SR); t = tt(n)
    lo = lp(r.standard_normal(n), 700) * 3.0 * np.exp(-3 * np.log(10) * t / (rt60 * 1.15))
    hi = hp(lp(r.standard_normal(n), 6500), 700) * np.exp(-3 * np.log(10) * t / (rt60 * 0.6))
    ir = (lo + hi) * (1 - np.exp(-t / 0.012))
    ir = np.concatenate([np.zeros(int(pre * SR)), ir])
    return ir / np.sqrt(np.sum(ir ** 2))

def rev(x, rt60, wet, r, n_out=None):
    ir = reverb_ir(rt60, r)
    w = signal.fftconvolve(x, ir)
    n = n_out or len(x)
    out = np.zeros(max(n, len(w)));  out[:len(x)] += x;  out += wet * np.pad(w, (0, len(out) - len(w)))
    return out[:n]


# --------------------------------------------------------------- loudness
def lufs(x):
    """BS.1770 K-weighted integrated loudness (ungated). x: (n,) or (n,2)"""
    x = np.atleast_2d(x.T if x.ndim == 2 else x)
    f0, G, Q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    K = np.tan(np.pi * f0 / SR); Vh = 10 ** (G / 20); Vb = Vh ** 0.4996667741545416; a0 = 1 + K / Q + K * K
    b = [(Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a = [1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = np.tan(np.pi * f0 / SR); a0 = 1 + K / Q + K * K
    b2 = [1, -2, 1]; a2 = [1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    s = 0.0
    for ch in x:
        y = signal.lfilter(b2, a2, signal.lfilter(b, a, ch)); s += np.mean(y ** 2)
    return -0.691 + 10 * np.log10(s + 1e-12)

def master_loop(x, target):
    """x (n,2) -> loudness-normalised with soft-clip ceiling at 0.8 (-1.9 dBFS)"""
    x = x - x.mean(axis=0); g = 1.0
    for _ in range(8):
        y = 0.8 * np.tanh(x * g / 0.8)
        g *= 10 ** ((target - lufs(y)) / 20)
    return 0.8 * np.tanh(x * g / 0.8)


# ------------------------------------------------------------------ output
def save_sfx(name, x, fade_in_ms=1.0, fade_out_ms=15.0, lead_trim=0.03):
    x = np.asarray(x, dtype=float); x = x - x.mean()
    pk = np.abs(x).max(); idx = int(np.argmax(np.abs(x) > lead_trim * pk)); x = x[idx:]
    fi = int(fade_in_ms * SR / 1000); fo = int(fade_out_ms * SR / 1000)
    if fi: x[:fi] *= np.linspace(0, 1, fi)
    if fo: x[-fo:] *= np.linspace(1, 0, fo) ** 1.5
    x = x / np.abs(x).max() * PEAK_SFX
    path = os.path.join(ROOT, "sfx", name + ".wav")
    wavfile.write(path, SR, np.round(x * 32767).astype(np.int16))

def save_ogg(group, name, x):
    path = os.path.join(ROOT, group, name + ".ogg")
    with tempfile.TemporaryDirectory() as td:
        tmp = os.path.join(td, "t.wav"); wavfile.write(tmp, SR, x.astype(np.float32))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-ar", str(SR), "-ac", "2",
                        "-c:a", "libvorbis", "-q:a", "5", path], check=True)


# ================================================================== SFX
def swing(name, dur, fa, fb, fc, q, peak, low=0.0):
    r = rng(name); n = int(dur * SR); u = np.linspace(0, 1, n)
    fcv = np.where(u < peak, fa * (fb / fa) ** (u / peak), fb * (fc / fb) ** ((u - peak) / (1 - peak)))
    a = np.log(0.5) / np.log(peak)
    env = np.sin(np.pi * u ** a) ** 1.4
    y = sweep_bp(r.standard_normal(n), fcv, q) * env
    y = y / np.abs(y).max() + low * lp(r.standard_normal(n), 260) * env
    y += 0.25 * hp(r.standard_normal(n), 5000) * env ** 2 * (1 - low * .5)
    save_sfx(name, y, fade_out_ms=25)

def clash(name, base, dur, ring, nparts=9, bright=1.0):
    r = rng(name); n = int(dur * SR); t = tt(n)
    ratios = np.array([1, 1.59, 2.14, 2.76, 3.54, 4.31, 5.40, 6.70, 8.93, 11.3])[:nparts]
    ratios = ratios * (1 + r.uniform(-.03, .03, nparts))
    fr = base * ratios
    amps = r.uniform(.6, 1, nparts) / (1 + ratios * .3 / bright)
    dec = ring * r.uniform(.5, 1.2, nparts) / ratios ** .3
    y = modal(n, fr, amps, dec, r)
    y += modal(n, fr[:5] + r.uniform(1.2, 4, 5), amps[:5] * .6, dec[:5], r)       # beating partners
    y += 2.2 * noise_burst(r, n, .006, 2500)
    y += 1.0 * noise_burst(r, n, .03, 700, 4500)
    y += 0.9 * sine_drop(n, 330, 150, .01, .05)
    y += 0.5 * sweep_bp(r.standard_normal(n), 800 + 6000 * (1 - np.exp(-t / .03)), 1.5) * np.exp(-t / .05)
    return y

def sfx_parry():
    r = rng("parry_perfect"); n = int(1.2 * SR); t = tt(n)
    y = clash("parry_perfect", 1750, 1.2, .55, nparts=10, bright=2.5)
    for i, f in enumerate(r.uniform(5200, 10500, 7)):
        am = 0.5 + 0.5 * np.sin(2 * np.pi * r.uniform(7, 15) * t + r.uniform(0, 6.3))
        y += 0.28 * np.sin(2 * np.pi * f * t) * np.exp(-t / r.uniform(.5, .9)) * am
    for f, a in [(2637, .45), (3951, .35), (5274, .22)]:
        vib = 1 + .002 * np.sin(2 * np.pi * 5.5 * t)
        y += a * np.sin(2 * np.pi * np.cumsum(f * vib) / SR) * np.exp(-t / .6)
    y += 0.8 * sweep_bp(r.standard_normal(n), 2500 * 4 ** np.clip(t / .12, 0, 1), 2) * np.exp(-t / .07)
    save_sfx("parry_perfect", y, fade_out_ms=200)

def sfx_guard_break():
    r = rng("guard_break"); n = int(1.1 * SR)
    times = np.sort(r.uniform(0, .38, 16)); amps = np.linspace(1.3, .3, 16) * r.uniform(.6, 1, 16)
    y = 1.0 * clicks(r, n, times, amps, .004, 1800, 9000)
    y += 1.6 * noise_burst(r, n, .02, 300, 6000)
    y += 1.5 * sine_drop(n, 130, 30, .14, .45) + .5 * noise_burst(r, n, .3, None, 220)
    y += .5 * modal(n, 1900 * np.array([1, 1.59, 2.76, 4.1]), [1, .7, .5, .4], [.25, .18, .12, .08], r)
    save_sfx("guard_break", y, fade_out_ms=120)

def sfx_dodge():
    r = rng("dodge"); n = int(.3 * SR); u = np.linspace(0, 1, n)
    y = sweep_bp(r.standard_normal(n), 700 * (2400 / 700) ** u, 1.0) * np.sin(np.pi * u ** .8) ** 1.5
    y = lp(y, 4200) + .3 * lp(r.standard_normal(n), 400) * np.sin(np.pi * u)
    save_sfx("dodge", y * .8, fade_in_ms=6, fade_out_ms=30)

def roar(name, dur, f0, f1, fa, fb, grate, drive, rasp):
    r = rng(name); n = int(dur * SR); t = tt(n); u = t / dur
    jit = lp(r.standard_normal(n), 25); jit /= jit.std()
    f = (f0 + (f1 - f0) * u ** .8) * (1 + .25 * np.exp(-t / .08)) * (1 + .035 * jit)
    f = f * (1 + .006 * np.sin(2 * np.pi * 6.3 * t))
    src = (saw(f) + .6 * saw(f * 1.012, .3) + .35 * lp(r.standard_normal(n), 4500)) * (1 + .5 * (jit > 0))
    w = smooth(u * 1.2)
    y = (1 - w) * formants(src, fa) + w * formants(src, fb)
    y *= 1 - .65 * (.5 + .5 * np.sin(2 * np.pi * grate * t + .5 * jit))
    y += rasp * bp(r.standard_normal(n), 1800, 5500) * (.4 + .6 * (1 - u))
    env = smooth(t / .07) * (1 - smooth((u - .55) / .45) ** 1.3) * (1 + .3 * np.exp(-t / .2))
    y = np.tanh(drive * y / (np.abs(y).max())) * env
    save_sfx(name, lp(y, 6500), fade_in_ms=3, fade_out_ms=40)

VOWELS = {
    "ah": [(800, 90, 1.0), (1150, 100, .5), (2900, 150, .2), (3900, 200, .1)],
    "oh": [(450, 70, 1.0), (800, 80, .5), (2830, 150, .15), (3800, 200, .08)],
    "ooh": [(300, 60, 1.0), (870, 80, .3), (2240, 150, .1)],
    "mA": [(650, 90, 1.0), (1050, 100, .8), (2450, 160, .35), (3300, 200, .15)],
    "mB": [(380, 70, 1.0), (720, 90, .7), (2150, 160, .3), (3100, 200, .1)],
    "mC": [(850, 110, 1.0), (1500, 130, .6), (2700, 170, .3)],
    "mD": [(520, 80, 1.0), (950, 100, .7), (2350, 170, .25)],
}
def formants(x, v, body=.5):
    out = body * lp(x, 300)
    for f, bw, g in VOWELS[v]: out = out + g * bf(x, "bandpass", [max(f - bw / 2, 30), f + bw / 2], 1)
    return out

def sfx_roars():
    roar("roar_1", 1.3, 125, 62, "mA", "mB", 33, 2.4, .12)
    roar("roar_2", 1.6, 98, 48, "mC", "mB", 27, 3.0, .18)
    roar("roar_3", 1.8, 150, 80, "mD", "mA", 41, 2.0, .10)

def sfx_telegraph():
    r = rng("telegraph_unblockable"); n = int(.5 * SR); t = tt(n); u = t / .5
    f = 220 * 4 ** u
    y = saw(f) + .7 * saw(f * 1.4142, .4) + .5 * np.sin(2 * np.pi * np.cumsum(f * 2) / SR)
    y = lp(y, 3200)
    rate = 6 + 18 * u; trem = 1 - .4 * (.5 + .5 * np.sin(2 * np.pi * np.cumsum(rate) / SR))
    y *= trem * (.25 + .75 * smooth(u * 1.4))
    y += .25 * modal(n, [880, 1250, 2090], [1, .6, .4], [.4, .3, .2], r) * u
    save_sfx("telegraph_unblockable", y, fade_in_ms=4, fade_out_ms=12)

def sfx_stagger():
    r = rng("stagger"); n = int(.7 * SR)
    y = 1.4 * sine_drop(n, 150, 55, .04, .16)
    y += .7 * np.roll(sine_drop(n, 130, 50, .04, .12), int(.14 * SR))
    for tm in np.sort(r.uniform(0, .38, 10)):
        i = int(tm * SR); m = n - i; fb = r.uniform(700, 3200)
        c = modal(m, fb * np.array([1, 2.4, 3.9]), [1, .6, .4], [.09, .06, .04], r)
        y[i:] += r.uniform(.3, .8) * c
    y += .9 * noise_burst(r, n, .05, 600, 5000) + .4 * lp(r.standard_normal(n), 3000) * np.exp(-tt(n) / .2)
    save_sfx("stagger", y, fade_out_ms=70)

def sfx_finisher():
    r = rng("finisher"); n = int(1.5 * SR); t = tt(n)
    ns = int(.28 * SR); us = np.linspace(0, 1, ns)
    sw = sweep_bp(r.standard_normal(ns), 400 * 10 ** us, 1.6) * (.15 + us ** 2)
    y = np.zeros(n); y[:ns] += 1.4 * sw / np.abs(sw).max()
    imp = 2.0 * sine_drop(n - ns, 90, 26, .12, .7) + 1.5 * noise_burst(r, n - ns, .03, 300, 6000)
    imp += .9 * clash("finisher_c", 1000, (n - ns) / SR, .55)[:n - ns] + .6 * noise_burst(r, n - ns, .25, None, 250)
    imp += .3 * modal(n - ns, [196, 293.7, 392], [1, .8, .6], [1.1, 1.0, .9], r)
    y[ns:] += imp
    save_sfx("finisher", rev(y, 1.2, .25, r), fade_out_ms=300)

def sfx_frost():
    r = rng("frost"); n = int(1.1 * SR); t = tt(n)
    times = r.uniform(0, 1, 70) ** 1.7 * .95
    y = 1.0 * clicks(r, n, times, r.uniform(.3, 1, 70), .0015, 4500, 14000)
    for f in [3136, 3951, 4699, 5919, 7040, 8372]:
        f *= r.uniform(.99, 1.01); am = .5 + .5 * np.sin(2 * np.pi * r.uniform(6, 20) * t + r.uniform(0, 6.3))
        st = r.uniform(0, .2)
        y += .3 * np.sin(2 * np.pi * f * t) * smooth((t - st) / .02) * np.exp(-(t - st).clip(0) / .45) * am
    y += .8 * noise_burst(r, n, .12, 6500) + .5 * modal(n, [1568, 2349], [1, .6], [.5, .4], r)
    save_sfx("frost", y, fade_out_ms=150)

def sfx_ember():
    r = rng("ember_burst"); n = int(.9 * SR); t = tt(n); u = t / .9
    fc = 150 * (1200 / 150) ** np.clip(u / .25, 0, 1) * np.where(u > .25, (400 / 1200) ** ((u - .25) / .75), 1)
    y = 2.0 * sweep_bp(r.standard_normal(n), fc, .8) * smooth(t / .03) * np.exp(-t / .45)
    y += 1.4 * sine_drop(n, 110, 38, .1, .35)
    y += .9 * clicks(r, n, r.uniform(.15, .8, 25), r.uniform(.3, 1, 25), .003, 900, 5000)
    save_sfx("ember_burst", lp(y, 6000), fade_in_ms=3, fade_out_ms=120)

def bell_tone(base, dur, r, hit=True):
    n = int(dur * SR); t = tt(n)
    rat = [.5, 1, 1.183, 1.506, 2.0, 2.514, 2.662, 3.01, 4.166, 5.433]
    amp = [.55, 1, .7, .5, .8, .3, .35, .25, .15, .1]
    y = np.zeros(n)
    for i, (k, a) in enumerate(zip(rat, amp)):
        tau = dur * .42 / (k ** .55) * (1.3 if k < 1 else 1)
        y += a * np.exp(-t / tau) * np.sin(2 * np.pi * base * k * t + r.uniform(0, 6.3))
        if i < 5: y += .5 * a * np.exp(-t / tau) * np.sin(2 * np.pi * base * k * 1.004 * t + r.uniform(0, 6.3))
    if hit:
        y += .9 * noise_burst(r, n, .012, 300, 3500) + .5 * sine_drop(n, base * 2, base, .02, .06)
    return y

def sfx_bell():
    r = rng("bell"); y = bell_tone(110, 4.0, r)
    save_sfx("bell", rev(y, 2.2, .35, r), fade_out_ms=400)

def sfx_footsteps():
    for i, (f, cb) in enumerate([(95, 1100), (110, 1400)], 1):
        name = f"footstep_{i}"; r = rng(name); n = int(.25 * SR)
        y = 1.3 * sine_drop(n, f * 1.5, f * .7, .02, .05) + .9 * noise_burst(r, n, .035, None, 220)
        y += .5 * noise_burst(r, n, .008, 1500, 6000)
        y = add(y, .45 * modal(n, cb * np.array([1, 2.4, 3.6]), [1, .6, .4], [.06, .04, .03], r), .008)[:n]
        y = add(y, .22 * modal(n, cb * 1.7 * np.array([1, 2.1]), [1, .5], [.04, .03], r), .06)[:n]
        save_sfx(name, y, fade_out_ms=40)

def sfx_ui():
    r = rng("ui_tap"); n = int(.12 * SR)
    y = modal(n, [430, 1150, 2350], [1, .5, .25], [.035, .02, .012], r) + .5 * noise_burst(r, n, .004, 500, 3000)
    save_sfx("ui_tap", lp(y, 4000), fade_out_ms=15)
    r = rng("ui_confirm"); n = int(.35 * SR)
    def note(f, d): return modal(n, [f, f * 2.76, f * 4.2], [1, .25, .1], [d, d * .35, d * .2], r)
    y = note(330, .16) + add(np.zeros(n), note(495, .18), .08)[:n] + .4 * noise_burst(r, n, .004, 500, 3000)
    save_sfx("ui_confirm", lp(y, 4500), fade_out_ms=40)
    r = rng("ui_back"); n = int(.28 * SR)
    def note2(f, d): return modal(n, [f, f * 2.76, f * 4.2], [1, .25, .1], [d, d * .35, d * .2], r)
    y = note2(392, .1) + add(np.zeros(n), note2(262, .14), .07)[:n] + .4 * noise_burst(r, n, .004, 400, 2500)
    save_sfx("ui_back", lp(y, 3500), fade_out_ms=35)

def string_note(freq, dur, r, att=.4, rel=.6, det=(-9, 0, 9), vib=.004):
    n = int((dur + rel) * SR); t = tt(n)
    vr = 1 + vib * np.sin(2 * np.pi * (4.8 + r.uniform(-.5, .5)) * t + r.uniform(0, 6.28)) * np.minimum(t / .8, 1)
    y = sum(saw(freq * 2 ** (d / 1200) * vr, r.uniform()) for d in det) / len(det)
    env = smooth(t / att) * np.where(t > dur, np.exp(-(t - dur) / (rel / 4)), 1.0)
    env[-int(.02 * SR):] *= np.linspace(1, 0, int(.02 * SR))
    return y * env

def chord_pad(notes, starts, durs, att, vowel, r, n, rel=.5, gain=1.0):
    buf = np.zeros(n + 3 * SR)
    for m, s, d in zip(notes, starts, durs):
        place(buf, string_note(float(mtof(m)), d, r, att, rel), int(s * SR))
    buf = buf[:n]
    return formants(buf, vowel, .6) * gain

def sfx_levelup():
    r = rng("levelup"); n = int(1.5 * SR)
    notes = [50, 57, 62, 65, 69, 74]
    y = chord_pad(notes, [i * .09 for i in range(6)], [1.0 - i * .05 for i in range(6)], .45, "ah", r, n, rel=.45)
    y += .5 * chord_pad([81], [.5], [.6], .3, "oh", r, n, rel=.4)
    save_sfx("levelup", rev(y, 1.8, .45, r, n), fade_in_ms=3, fade_out_ms=350, lead_trim=.01)

def sfx_death():
    r = rng("death"); n = int(2.5 * SR); t = tt(n)
    y = 2.0 * sine_drop(n, 130, 24, .6, .9) + 1.0 * noise_burst(r, n, .4, None, 200)
    y += 1.0 * noise_burst(r, n, .02, 200, 3000) + .5 * lp(saw(60 * np.exp(-t / 1.2) + 20), 200) * np.exp(-t / 1.0)
    seg = chord_pad([38, 45, 50, 53], [0] * 4, [.9] * 4, .05, "oh", r, int(1.8 * SR), rel=.8) * np.exp(-tt(int(1.8 * SR)) / .5)
    sw = rev(seg, 1.6, 1.0, r, int(1.8 * SR))[::-1]
    y = add(y, .5 * sw / np.abs(sw).max() * np.abs(y).max() * .5, .65)[:n]
    save_sfx("death", y, fade_out_ms=120)

def sfx_victory():
    r = rng("victory"); n = int(3.0 * SR)
    y = chord_pad([38, 50, 57, 62, 66, 69, 74], [0, .05, .12, .2, .28, .36, .44], [1.9] * 7, .9, "ah", r, n, rel=.9)
    y += .8 * bell_tone(146.8, 3.0, r)[:n] + 1.2 * sine_drop(n, 80, 36.7, .05, 1.6)
    save_sfx("victory", rev(y, 2.2, .45, r, n), fade_in_ms=2, fade_out_ms=700, lead_trim=.01)

def sfx_loot():
    r = rng("loot"); n = int(.6 * SR)
    def ch(f, d): return modal(n, f * np.array([1, 2.76, 5.4]), [1, .35, .12], [d, d * .4, d * .2], r)
    y = ch(1760, .3) + .7 * add(np.zeros(n), ch(2349, .3), .07)[:n] + .3 * noise_burst(r, n, .003, 4000)
    save_sfx("loot", lp(y, 9000), fade_out_ms=60)

def build_sfx():
    for n_, a in [("swing_1", (.33, 500, 2800, 900, 2.2, .45)), ("swing_2", (.37, 400, 2400, 700, 1.8, .5)),
                  ("swing_3", (.30, 700, 3500, 1100, 2.5, .4))]: swing(n_, *a)
    swing("swing_heavy", .68, 150, 1100, 200, 1.2, .55, low=1.0)
    sfx_parry(); sfx_guard_break(); sfx_dodge(); sfx_roars()      # clash/block/hit/whoosh/step families: gen_audio_combat.py
    sfx_telegraph(); sfx_stagger(); sfx_finisher(); sfx_frost(); sfx_ember(); sfx_bell(); sfx_footsteps()
    sfx_ui(); sfx_levelup(); sfx_death(); sfx_victory(); sfx_loot()
    import gen_audio_combat; gen_audio_combat.build()      # clash_1-6, block_1-4, hit_*, parry_1-3, guard_break_1-3, whoosh_*, step_*, layers


# =============================================================== AMBIENCE
AL = 20 * SR
def lfo_c(cycles, ph=0.0): return np.sin(2 * np.pi * cycles * tt(AL) / 20 + ph)
def slow(r, cut, L=AL):
    x = circ(lambda z: lp(z, cut), r.standard_normal(L)); return x / x.std()
def amb_finish(name, ch):
    save_ogg("amb", name, master_loop(np.stack(ch, 1), -18.0))

def amb_wind():
    ch = []
    for c in range(2):
        r = rng(f"wind{c}")
        rumble = circ(lambda z: lp(z, 260), r.standard_normal(AL)) * (.6 + .3 * slow(r, .3))
        gust = np.clip(.5 + .6 * slow(r, .22), 0, 1) ** 2
        mid = circ(lambda z: bp(z, 450, 1500), r.standard_normal(AL)) * gust
        high = circ(lambda z: bp(z, 1800, 4500), r.standard_normal(AL)) * gust ** 2 * .6
        whistle = circ(lambda z: bp(z, 900, 960, 2), r.standard_normal(AL)) * np.clip(.4 + .7 * slow(r, .15), 0, 1) * 3
        ch.append(rumble * 2.2 + mid * 1.2 + high + whistle)
    amb_finish("wind", ch)

def amb_rain():
    ch = []
    for c in range(2):
        r = rng(f"rain{c}")
        body = circ(lambda z: bp(z, 1200, 9000, 1), r.standard_normal(AL))
        soft = circ(lambda z: lp(z, 500), r.standard_normal(AL)) * .35
        imp = np.zeros(AL); idx = r.integers(0, AL, 5500); imp[idx] = r.exponential(1.0, 5500) * r.choice([-1, 1], 5500)
        k = np.exp(-tt(300) / .0018)
        drops = circ(lambda z: bp(z, 2500, 8500), circ_conv(imp, k)) * 6
        ch.append(body * (.7 + .15 * slow(r, .5)) + soft + drops)
    amb_finish("rain", ch)

def amb_crypt():
    r = rng("crypt"); ch = [np.zeros(AL), np.zeros(AL)]; t = tt(AL)
    for c in range(2):
        rc = rng(f"crypt{c}")
        rum = circ(lambda z: lp(z, 75), rc.standard_normal(AL)) * (.7 + .3 * slow(rc, .2)) * 3.0
        dr = sum(a * np.sin(2 * np.pi * f * t + p) for f, a, p in [(41.2, 1, c), (41.25, .8, 2 * c), (82.4, .35, 1), (123.6, .12, 0)])
        air = circ(lambda z: bp(z, 150, 420), rc.standard_normal(AL)) * np.clip(.35 + .5 * slow(rc, .1), 0, 1) * 1.2
        ch[c] = rum * 1.0 + dr * .5 + air
    drips = np.zeros(AL)
    for tm in r.uniform(0, 20, 11):
        f = r.uniform(1300, 2900); m = int(.35 * SR); u = tt(m)
        d = np.sin(2 * np.pi * np.cumsum(f * (1 + .8 * np.exp(-u / .012))) / SR) * np.exp(-u / .045) * r.uniform(.4, 1)
        d += .4 * np.sin(2 * np.pi * f * 2.3 * u) * np.exp(-u / .02)
        place(drips, d, int(tm * SR))
    for c in range(2):
        ir = reverb_ir(3.0, rng(f"cryptrev{c}"))
        ch[c] = ch[c] + .35 * drips + 1.4 * circ_conv(drips, ir) * .6
    amb_finish("crypt", ch)

def amb_fire():
    ch = [None, None]; r = rng("fire")
    small = np.zeros(AL); big = np.zeros(AL)
    small[r.integers(0, AL, 1600)] = r.exponential(1, 1600) ** 1.6 * r.choice([-1, 1], 1600)
    big[r.integers(0, AL, 130)] = r.exponential(1, 130) * r.choice([-1, 1], 130) * 3
    pops = circ(lambda z: bp(z, 800, 6500), circ_conv(small, np.exp(-tt(120) / .0007))) * 3
    bigs = circ(lambda z: bp(z, 300, 3200), circ_conv(big, np.exp(-tt(400) / .003))) * 2
    for c in range(2):
        rc = rng(f"fire{c}")
        flick = np.clip(.55 + .5 * slow(rc, 7), .05, 1.2)
        body = circ(lambda z: lp(z, 480), rc.standard_normal(AL)) * flick * 2.2
        hiss = circ(lambda z: hp(z, 4000), rc.standard_normal(AL)) * .06 * flick
        pan = .75 if c == 0 else .5
        sh = int((.0006 if c else 0) * SR)
        ch[c] = body + hiss + np.roll(pops, sh) * pan + np.roll(bigs, sh) * pan * .8
    amb_finish("fire", ch)


# ================================================================== MUSIC
class Mix:
    def __init__(self, L): self.L = L; self.dry = np.zeros((2, L)); self.wet = np.zeros(L)
    def add(self, x, pan=0.0, wet=.3, dry=1.0, haas=0.0):
        a = (pan + 1) * np.pi / 4
        l = x; rr = np.roll(x, int(haas * SR)) if haas else x
        self.dry[0] += l * np.cos(a) * dry * 1.414; self.dry[1] += rr * np.sin(a) * dry * 1.414
        self.wet += x * wet
    def render(self, rt60, wetgain, seed):
        out = self.dry.copy()
        for c in range(2):
            out[c] += wetgain * circ_conv(self.wet, reverb_ir(rt60, rng(f"{seed}{c}"), .02))
        return out.T

def melt(L, notes, fn):
    buf = np.zeros(L)
    for s, d, m, *rest in notes: place(buf, fn(float(mtof(m)), d, *rest), int(s * SR))
    return buf

def taiko(r, f=72, amp=1.0, dur=1.1):
    n = int(dur * SR)
    y = 1.5 * sine_drop(n, f * 2.2, f, .035, .3) + .6 * sine_drop(n, f * 3.1, f * 1.5, .02, .12)
    y += .7 * noise_burst(r, n, .012, 100, 2500) + .25 * noise_burst(r, n, .08, None, 300)
    return y * amp * np.minimum(1, (n - np.arange(n)) / (.05 * SR))

def timp(r, f, amp=1.0, dur=1.6):
    n = int(dur * SR); t = tt(n); y = np.zeros(n)
    for k, a, d in [(1, 1, .9), (1.5, .6, .6), (1.99, .5, .45), (2.44, .3, .3), (2.9, .2, .22)]:
        ff = f * k * (1 + .06 * np.exp(-t / .06))
        y += a * np.exp(-t / d) * np.sin(2 * np.pi * np.cumsum(ff) / SR + r.uniform(0, 6))
    y += .8 * noise_burst(r, n, .02, 80, 1800)
    return y * amp * np.minimum(1, (n - np.arange(n)) / (.08 * SR))

def snare(r, amp=1.0):
    n = int(.5 * SR); y = noise_burst(r, n, .07, 1200, 7000) + .5 * sine_drop(n, 260, 180, .02, .06)
    return y * amp

def organ_note(f, dur, r, att=.06, rel=.4):
    n = int((dur + rel) * SR); t = tt(n); y = np.zeros(n)
    for k, a in [(1, 1), (2, .7), (3, .5), (4, .35), (6, .2), (8, .1)]:
        if f * k < 12000: y += a * np.sin(2 * np.pi * f * k * t + r.uniform(0, 6))
    env = smooth(t / att) * np.where(t > dur, np.exp(-(t - dur) / (rel / 4)), 1.0)
    env[-int(.02 * SR):] *= np.linspace(1, 0, int(.02 * SR))
    return y * env

def lead(f, dur, r, att=.12, rel=.5):
    n = int((dur + rel) * SR); t = tt(n)
    vib = 1 + .006 * np.sin(2 * np.pi * 5.2 * t) * smooth((t - .4) / .5)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    y = np.sin(ph) + .25 * np.sin(2 * ph) + .08 * np.sin(3 * ph)
    env = smooth(t / att) * np.where(t > dur, np.exp(-(t - dur) / (rel / 4)), 1.0)
    env[-int(.02 * SR):] *= np.linspace(1, 0, int(.02 * SR))
    return y * env

def pluck(f, dur, r):
    n = int(dur * SR); return modal(n, [f, 2 * f, 3 * f], [1, .3, .1], [1.2, .5, .25], r) * smooth(tt(n) / .003)

def merge(chords):
    """merge consecutive identical entries -> [(start_bar, n_bars, name)]"""
    out = []
    for i, c in enumerate(chords):
        if out and out[-1][2] == c: out[-1][1] += 1
        else: out.append([i, 1, c])
    return out

def lp_layer(x, f, o=2): return circ(lambda z: lp(z, f, o), x)

def music_combat(name, bpm, bars, chords, roots, tones, key_drum, b=False):
    beat = 60 / bpm; bar = 4 * beat; L = int(round(bars * bar * SR)); r = rng(name)
    mix = Mix(L)
    # low string ostinato (8ths)
    pat = [0, 0, 12, 0, 0, 7, 0, 12]; acc = [1, .6, .8, .6, .9, .6, .8, .6]
    ost = []
    for i, c in enumerate(chords):
        for k in range(8):
            ost.append((i * bar + k * beat / 2, beat / 2 * .75, roots[c] + pat[k] + 12, acc[k]))
    o = melt(L, [(s, d, m) for s, d, m, a in ost], lambda f, d: string_note(f, d, r, .012, .09, (-10, 0, 10), .002))
    mix.add(lp_layer(o, 1500) * .9, pan=-.15, wet=.25, dry=.9)
    # sustained pads
    pads = [(s * bar, n_ * bar, tones[c]) for s, n_, c in merge(chords)]
    pad = np.zeros(L)
    for s, d, ns in pads:
        for m in ns: place(pad, string_note(float(mtof(m)), d + .2, r, .7, .9, (-12, 0, 12), .005), int(s * SR))
    mix.add(lp_layer(pad, 1100) * .55, wet=.5, dry=.8, haas=.012)
    # sub
    sub = melt(L, [(s * bar, n_ * bar, roots[c] - 12 + 12) for s, n_, c in merge(chords)],
               lambda f, d: np.sin(2 * np.pi * f * tt(int((d + .3) * SR))) * smooth(tt(int((d + .3) * SR)) / .3) * np.where(tt(int((d + .3) * SR)) > d, np.exp(-(tt(int((d + .3) * SR)) - d) / .08), 1))
    mix.add(sub * .5, wet=0.0)
    # drums
    hits = [(0, 1.0), (1.5, .55), (2, .8), (3.5, .5)]
    if b: hits += [(.5, .45), (1, .6), (2.5, .6), (3, .7)]
    dr = np.zeros(L)
    for i in range(bars):
        for hb, a in hits: place(dr, taiko(r, key_drum, a * (1.1 if hb == 0 else 1)), int((i * bar + hb * beat) * SR))
        if i % 4 == 3 or i == bars - 1:
            for k in range(4 if not b else 6):
                hb = 3 + k * (1 / (4 if not b else 6)); place(dr, taiko(r, key_drum * 1.2, .35 + .12 * k), int((i * bar + hb * beat) * SR))
    mix.add(dr * .85, wet=.4, dry=1.0)
    if b:
        sn = np.zeros(L)
        for i in range(bars):
            for hb in (1, 3): place(sn, snare(r, .55), int((i * bar + hb * beat) * SR))
        mix.add(sn, pan=.2, wet=.35, dry=.7)
        fast = []
        for i, c in enumerate(chords):
            for k in range(16):
                fast.append((i * bar + k * beat / 4, beat / 4 * .7, roots[c] + 24 + [0, 7, 12, 7, 3, 7, 12, 15][k % 8]))
        fo = melt(L, fast, lambda f, d: string_note(f, d, r, .006, .05, (-8, 0, 8), .002))
        mix.add(lp_layer(fo, 2600) * .38, pan=.25, wet=.25, dry=.8)
        ch = np.zeros(L)
        for s, n_, c in merge(chords):
            for m in tones[c][1:]: place(ch, string_note(float(mtof(m + 12)), n_ * bar + .2, r, .9, 1.0, (-14, 0, 14), .006), int(s * bar * SR))
        mix.add(circ(lambda z: formants(z, "ah", .5), ch) * .5, wet=.6, dry=.7, haas=.015)
    return np.roll(mix.render(2.8, .5, name), int(.025 * SR), axis=0)

def music_combat_pair():
    chords = ['Em', 'Em', 'C', 'D', 'Em', 'Em', 'C', 'B', 'Am', 'Am', 'C', 'D', 'Em', 'B']
    roots = {'Em': 40, 'C': 36, 'D': 38, 'B': 35, 'Am': 33}
    tones = {'Em': [52, 55, 59, 64], 'C': [48, 52, 55, 60], 'D': [50, 54, 57, 62], 'B': [47, 51, 54, 59], 'Am': [45, 52, 57, 60]}
    for name, b in [("combat_a", False), ("combat_b", True)]:
        x = music_combat(name, 100, 14, chords, roots, tones, 78, b)
        save_ogg("music", name, master_loop(x, -14.0))

def music_menu():
    L = 48 * SR; r = rng("menu"); mix = Mix(L); t = tt(L)
    f1 = round(73.42 * 48) / 48; f36 = round(36.71 * 48) / 48; f2 = round(110.0 * 48) / 48
    dr = np.sin(2 * np.pi * f1 * t) + .6 * np.sin(2 * np.pi * f2 * t) + .3 * np.sin(2 * np.pi * f1 * 2 * t)
    dr *= 1 + .15 * np.sin(2 * np.pi * 4 * t / 48 * 2 * np.pi / (2 * np.pi))
    saws = (saw(np.full(L, f36)) + saw(np.full(L, round(36.71 * 1.003 * 48) / 48), .5) + .6 * saw(np.full(L, 55.0), .2))
    mix.add(dr * .5 + lp_layer(saws, 200) * .6, wet=.3, dry=.9)
    ch = [[50, 57, 62, 65], [46, 53, 58, 62], [43, 50, 55, 58], [45, 52, 57, 61]]
    pad = np.zeros(L)
    for i, ns in enumerate(ch):
        for j, m in enumerate(ns): place(pad, string_note(float(mtof(m)), 11, r, 3.0, 4.0, (-12, 0, 12), .005), int((i * 12 + j * .8) * SR))
    mix.add(lp_layer(pad, 900) * .8, wet=.6, dry=.8, haas=.015)
    hi = np.zeros(L)
    for s, m, d in [(8, 69, 6), (20, 65, 6), (32, 67, 7), (41, 64, 6)]:
        place(hi, string_note(float(mtof(m)), d, r, 2.5, 3.0, (-8, 0, 8), .006), int(s * SR))
    mix.add(lp_layer(hi, 1800) * .4, pan=.2, wet=.7, dry=.5)
    bl = np.zeros(L)
    for s, base in [(3, 146.8), (15, 110.0), (27, 130.8), (39, 98.0)]: place(bl, bell_tone(base, 8.0, r), int(s * SR))
    mix.add(lp_layer(bl, 3000) * .6, pan=-.3, wet=1.0, dry=.2)
    wind = circ(lambda z: bp(z, 250, 800), r.standard_normal(L)) * np.clip(.4 + .5 * circ(lambda z: lp(z, .15), r.standard_normal(L)) * 30, 0, 1)
    mix.add(wind * .15, wet=.2, dry=.6)
    save_ogg("music", "menu", master_loop(mix.render(4.0, .55, "menu"), -14.0))

def music_sanctuary():
    bpm = 60; beat = 1.0; L = 48 * SR; r = rng("sanctuary"); mix = Mix(L)
    chords = [[57, 60, 64, 67], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 67], [57, 60, 64, 67], [57, 60, 64, 67],
              [53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [55, 59, 62, 67], [53, 57, 60, 64], [52, 57, 59, 64]]
    bass = [45, 45, 41, 43, 45, 45, 41, 40, 38, 43, 41, 40]
    pad = np.zeros(L); bs = np.zeros(L)
    for i, ns in enumerate(chords):
        for m in ns: place(pad, string_note(float(mtof(m)), 4.0, r, 1.4, 1.6, (-7, 0, 7), .004), int(i * 4 * SR))
        n_ = int(5 * SR); tb = tt(n_)
        place(bs, (np.sin(2 * np.pi * mtof(bass[i]) * tb) + .3 * np.sin(4 * np.pi * mtof(bass[i]) * tb)) * smooth(tb / .5) * np.exp(-tb / 2.5), int(i * 4 * SR))
    mix.add(lp_layer(pad, 800) * .7, wet=.55, dry=.9, haas=.014)
    mix.add(bs * .5, wet=.1)
    mel = [(0, 3, 76), (3, 1, 74), (4, 2, 72), (6, 2, 71), (8, 3, 69), (11, 1, 72), (12, 2, 71), (14, 2, 67), (16, 3, 69), (19, 1, 71),
           (20, 2, 72), (22, 2, 76), (24, 3, 77), (27, 1, 76), (28, 2, 74), (30, 2, 71), (32, 2, 74), (34, 2, 77), (36, 2, 74),
           (38, 2, 71), (40, 3, 69), (43, 1, 67), (44, 2, 71), (46, 2, 68)]
    ml = melt(L, [(s * beat, d * beat * .95, m) for s, d, m in mel], lambda f, d: lead(f, d, r))
    mix.add(ml * .55, pan=.1, wet=.55, dry=.8)
    ar = []
    for i, ns in enumerate(chords):
        for k in range(4): ar.append((i * 4 + k + .5, 2.0, ns[[0, 2, 1, 3][k]] + 12))
    mix.add(melt(L, ar, lambda f, d: pluck(f, d, r)) * .12, pan=-.25, wet=.6, dry=.7)
    save_ogg("music", "sanctuary", master_loop(mix.render(3.4, .5, "sanctuary"), -14.0))

def music_final():
    bpm = 72; beat = 60 / bpm; bar = 4 * beat; bars = 12; L = int(round(bars * bar * SR)); r = rng("final"); mix = Mix(L)
    chords = ['Dm', 'Dm', 'Bb', 'F', 'Gm', 'Gm', 'A', 'A', 'Bb', 'C', 'A', 'A']
    roots = {'Dm': 38, 'Bb': 34, 'F': 41, 'Gm': 31, 'A': 33, 'C': 36}
    tones = {'Dm': [50, 57, 62, 65], 'Bb': [46, 53, 58, 62], 'F': [53, 57, 60, 65], 'Gm': [50, 55, 58, 62],
             'A': [52, 57, 61, 64], 'C': [48, 55, 60, 64]}
    mg = [(s, n_ * bar, tones[c]) for s, n_, c in merge(chords)]
    org = np.zeros(L); ped = np.zeros(L); str_ = np.zeros(L); cho = np.zeros(L)
    for s, d, ns in mg:
        for m in ns: place(org, organ_note(float(mtof(m)), d * 1.0, r, .1, .5), int(s * bar * SR))
        for m in ns: place(str_, string_note(float(mtof(m)), d * 1.0 + .2, r, 1.0, 1.0, (-12, 0, 12), .005), int(s * bar * SR))
        for m in ns[1:]: place(cho, string_note(float(mtof(m + 12)), d + .2, r, 1.3, 1.2, (-14, 0, 14), .006), int(s * bar * SR))
    for i, c in enumerate(chords):
        place(ped, organ_note(float(mtof(roots[c])), bar, r, .08, .4) , int(i * bar * SR))
    t = tt(L); cyc = round(5.3 * L / SR); trem = 1 + .06 * np.sin(2 * np.pi * cyc * t / (L / SR))
    mix.add(org * .22 * trem, wet=.5, dry=.8, haas=.01)
    mix.add(ped * .35, wet=.2)
    mix.add(lp_layer(str_, 1000) * .5, wet=.5, dry=.8, haas=.013)
    mix.add(circ(lambda z: formants(z, "ah", .5), cho) * .65, wet=.6, dry=.7, haas=.016)
    mel = [(0, 2, 74), (2, 1, 77), (3, 1, 76), (4, 2, 77), (6, 2, 69), (8, 2, 70), (10, 1, 74), (11, 1, 72), (12, 2, 72), (14, 2, 69),
           (16, 2, 70), (18, 2, 74), (20, 2, 79), (22, 2, 77), (24, 2, 76), (26, 2, 73), (28, 4, 69), (32, 2, 77), (34, 2, 74),
           (36, 2, 79), (38, 2, 76), (40, 2, 76), (42, 2, 81), (44, 4, 73)]
    ml = melt(L, [(s * beat, d * beat * .97, m) for s, d, m in mel], lambda f, d: organ_note(f, d, r, .04, .3))
    mix.add(ml * .2, pan=.1, wet=.5, dry=.8)
    ml2 = melt(L, [(s * beat, d * beat * .97, m - 12) for s, d, m in mel], lambda f, d: string_note(f, d, r, .3, .5, (-10, 0, 10), .005))
    mix.add(circ(lambda z: formants(z, "oh", .6), ml2) * .45, pan=-.1, wet=.6, dry=.7)
    tm = np.zeros(L)
    for i in range(bars):
        place(tm, timp(r, 73.4, 1.0), int(i * bar * SR)); place(tm, timp(r, 55, .5), int((i * bar + 2 * beat) * SR))
        if i in (7, 11):
            for k in range(8): place(tm, timp(r, 73.4, .25 + .09 * k, .7), int((i * bar + 3 * beat + k * beat / 8) * SR))
        if i == 3: place(tm, timp(r, 65.4, .7), int((i * bar + 3 * beat) * SR))
    mix.add(tm * .75, wet=.5, dry=1.0)
    save_ogg("music", "final", master_loop(np.roll(mix.render(4.2, .55, "final"), int(.025 * SR), axis=0), -14.0))

def build_loops():
    amb_wind(); amb_rain(); amb_crypt(); amb_fire()
    music_menu(); music_sanctuary(); music_combat_pair(); music_final()


# ================================================================== VERIFY
def probe(path):
    o = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=sample_rate,channels",
                        "-of", "json", path], capture_output=True, text=True, check=True).stdout
    s = json.loads(o)["streams"][0]; return int(s["sample_rate"]), int(s["channels"])

def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(float)

SFX_NAMES = ("swing_1 swing_2 swing_3 swing_heavy clash_1 clash_2 clash_3 parry_perfect hit_armor_1 hit_armor_2 hit_flesh_1 "
             "hit_flesh_2 block_1 block_2 guard_break dodge roar_1 roar_2 roar_3 telegraph_unblockable stagger finisher frost "
             "ember_burst bell footstep_1 footstep_2 ui_tap ui_confirm ui_back levelup death victory loot").split()
LOOPS = [("amb", n) for n in "wind rain crypt fire".split()] + [("music", n) for n in "menu sanctuary combat_a combat_b final".split()]

def verify():
    total = 0; ok = True
    print(f"{'file':28s}{'dur':>7s}{'size':>9s}  info")
    for n in SFX_NAMES:
        p = os.path.join(ROOT, "sfx", n + ".wav")
        if not os.path.exists(p): print("MISSING", p); ok = False; continue
        sr, x = wavfile.read(p); sz = os.path.getsize(p); total += sz
        pk = np.abs(x).max(); xf = x / 32768.0; lead = int(np.argmax(np.abs(xf) > .01 * np.abs(xf).max()))
        bad = (sr != SR or x.ndim != 1 or pk >= 32767 or pk < 1000 or lead > int(.01 * SR)); ok &= not bad
        print(f"sfx/{n + '.wav':24s}{len(x) / SR:6.2f}s{sz / 1024:8.0f}K  sr={sr} ch=1 peak={20 * np.log10(pk / 32768):.1f}dB "
              f"rms={20 * np.log10(np.sqrt(np.mean(xf ** 2))):.1f}dB lead={lead / SR * 1000:.1f}ms {'BAD' if bad else ''}")
    for g, n in LOOPS:
        p = os.path.join(ROOT, g, n + ".ogg")
        if not os.path.exists(p): print("MISSING", p); ok = False; continue
        sr, ch = probe(p); x = decode(p); sz = os.path.getsize(p); total += sz
        pk = np.abs(x).max(); rms = np.sqrt(np.mean(x ** 2)); step = np.sqrt(np.mean(np.diff(x, axis=0) ** 2))
        jump = np.sqrt(np.mean((x[0] - x[-1]) ** 2))
        w = int(.02 * SR); seam = np.concatenate([x[-w:], x[:w]]); seam_rms = np.sqrt(np.mean(seam ** 2))
        seam_step = np.sqrt(np.mean(np.diff(seam, axis=0) ** 2))
        bad = (sr != SR or ch != 2 or pk >= .999 or rms < .01); ok &= not bad
        print(f"{g}/{n + '.ogg':23s}{len(x) / SR:6.2f}s{sz / 1024:8.0f}K  sr={sr} ch={ch} peak={20 * np.log10(pk):.1f}dB "
              f"LUFS={lufs(x):.1f} | seam jump rms={jump:.4f} vs avg step rms={step:.4f} (x{jump / step:.2f}); "
              f"20ms-around-seam rms/avg rms={seam_rms / rms:.2f}, step ratio={seam_step / step:.2f} {'BAD' if bad else ''}")
    print(f"total {total / 1e6:.2f} MB   {'ALL OK' if ok else 'PROBLEMS FOUND'}")

if __name__ == "__main__":
    for d in ("sfx", "amb", "music"): os.makedirs(os.path.join(ROOT, d), exist_ok=True)
    build_sfx(); build_loops(); verify()
