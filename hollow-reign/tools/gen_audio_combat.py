#!/usr/bin/env python3
"""Hollow Reign - synthesised combat and footstep effects (no samples; original; nobody has listened to them).

Metal as inharmonic modal partials (free-free bar ratios from two slightly different blades, frequency-dependent
decay, beating partner partials) over a noisy few-millisecond attack; whooshes as band-swept noise whose centre
frequency rises and then falls (a Doppler-like arc); footsteps per surface built from heel thud, scuff and
surface texture. Every file is mono 44.1 kHz 16-bit with 4 ms of leading silence (the engine uses it for a
sample-accurate start offset, see src/core/sfx.gd PREROLL) and is level-matched inside its family to a target
momentary loudness (BS.1770 K-weighting, 400 ms window) so a variant swap does not change the mix.
Deterministic: each sound seeds its generator from its own name.
Usage: tools/gen_audio_combat.py            (run after gen_audio.py and gen_audio_extra.py; gen_audio.py calls it)
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_audio import (SR, ROOT, rng, tt, lp, hp, bp, sweep_bp, modal, sine_drop, noise_burst, clicks, smooth, lufs)
from scipy.io import wavfile

PREROLL = 0.004
PEAK_CAP = 10 ** (-2.0 / 20)
LOG = []

def momentary_max(x):
    n = max(len(x), SR)
    y = np.zeros(n); y[:len(x)] = x
    w = int(.4 * SR)
    best = -99.0
    for s in range(0, n - w + 1, int(.1 * SR)):
        best = max(best, lufs(y[s:s + w]))
    return best

def finish(name, x, target, fade_out_ms=30, lead_trim=0.02):
    """trim the lead, fade the tail, scale to the family loudness target (peak capped at -2 dBFS), prepend PREROLL"""
    x = np.asarray(x, dtype=float); x = x - x.mean()
    pk = np.abs(x).max(); x = x[int(np.argmax(np.abs(x) > lead_trim * pk)):]
    fo = int(fade_out_ms * SR / 1000); x[-fo:] *= np.linspace(1, 0, fo) ** 1.5
    x[:int(.0005 * SR)] *= np.linspace(0, 1, int(.0005 * SR))
    x = x / np.abs(x).max()
    g = 10 ** ((target - momentary_max(x)) / 20)
    capped = np.abs(x).max() * g > PEAK_CAP
    if capped: g = PEAK_CAP / np.abs(x).max()
    x = np.concatenate([np.zeros(int(PREROLL * SR)), x * g])
    wavfile.write(os.path.join(ROOT, "sfx", name + ".wav"), SR, np.round(x * 32767).astype(np.int16))
    LOG.append((name, capped))

# ------------------------------------------------------------------ metal
BAR = np.array([1.0, 2.757, 5.404, 8.933, 13.34, 18.64, 25.0])          # free-free bar mode ratios (a blade)
PLATE = np.array([1.0, 1.59, 2.14, 2.76, 3.54, 4.31, 5.40, 6.70])       # plate / guard / shield-like ratios

def modes(r, n, f0, ratios, tau0, tilt, stiff, amp=1.0, partner=True):
    """inharmonic partials: amplitude falls with ratio**-tilt, decay shortens with frequency, beating partners"""
    rt = ratios * (1 + r.uniform(-.025, .025, len(ratios)))
    f = f0 * rt
    keep = f < 16000
    f, rt = f[keep], rt[keep]
    a = amp * rt ** (-tilt) * r.uniform(.6, 1.0, len(f))
    tau = tau0 / (1 + (f / 1800.0) ** 1.3 * stiff) * r.uniform(.8, 1.2, len(f))
    y = modal(n, f, a, tau, r)
    if partner:
        k = min(5, len(f))
        y += modal(n, f[:k] + r.uniform(.8, 5, k), a[:k] * .6, tau[:k], r)
    return y

def attack(r, n, bright, lo=1800):
    """noisy few-millisecond contact transient plus a faint broadband smear"""
    y = 2.0 * noise_burst(r, n, .003 / bright ** .5, lo * 0.8)
    y += 0.8 * noise_burst(r, n, .012, 900, 7000 * bright)
    return y

def clash(idx, f0, tau0, dur, nm, bright, grind, ratio_b, target=-20.0):
    name = f"clash_{idx}"; r = rng(name); n = int(dur * SR); t = tt(n)
    y = modes(r, n, f0, BAR[:nm], tau0, .45 / bright, 1.0 + .3 * (2 - bright))
    y += .75 * modes(r, n, f0 * ratio_b, BAR[:nm - 1], tau0 * .8, .5 / bright, 1.2)                # the other blade
    y += .35 * modes(r, n, f0 * .5 * ratio_b, PLATE[:5], tau0 * .5, .6, 1.5, partner=False)       # guard / forte
    y += attack(r, n, bright)
    y += 1.0 * sweep_bp(r.standard_normal(n), f0 * 1.5 + 6000 * bright * (1 - np.exp(-t / .03)), 1.5) * np.exp(-t / .045)
    if grind > 0:                                                                                    # blades sliding, shing
        m = int(.09 * SR); u = np.linspace(0, 1, m)
        g = sweep_bp(r.standard_normal(m), 2800 * (2.4 ** u), 3.0) * np.sin(np.pi * u) ** 1.3
        y[:m] += grind * 1.6 * g / (np.abs(g).max() + 1e-9)
    finish(name, y, target, fade_out_ms=60)

def block(idx, wf, mf, dur, tau, wood, target=-21.0):
    name = f"block_{idx}"; r = rng(name); n = int(dur * SR)
    y = modal(n, wf * np.array([1, 2.4, 3.9]), [1, .6, .4], tau * np.array([1, .6, .4]), r)
    y += 1.3 * sine_drop(n, wf * 1.5, wf * .55, .02, tau * 1.1)
    y += (.5 - .2 * wood) * modes(r, n, mf, PLATE[:5], tau * 1.4, .7, 1.8, partner=False)
    y += .9 * noise_burst(r, n, .008, 400, 4200) + wood * .7 * noise_burst(r, n, .02, 150, 900)
    finish(name, lp(y, 5500), target, fade_out_ms=40)

def parry(idx, f0, tau0, dur, target=-17.0):
    name = f"parry_{idx}"; r = rng(name); n = int(dur * SR); t = tt(n)
    y = modes(r, n, f0, BAR[:7], tau0, .3, .55)
    y += .7 * modes(r, n, f0 * 1.31, BAR[:5], tau0 * .8, .35, .6)
    for f in r.uniform(5200, 11000, 6):                                                              # air shimmer
        am = .5 + .5 * np.sin(2 * np.pi * r.uniform(6, 14) * t + r.uniform(0, 6.3))
        y += .25 * np.sin(2 * np.pi * f * t) * np.exp(-t / r.uniform(.4, .9) / (dur / 1.0)) * am
    y += .9 * sweep_bp(r.standard_normal(n), 2500 * 4 ** np.clip(t / .1, 0, 1), 2) * np.exp(-t / .05)
    y += 1.6 * noise_burst(r, n, .0025, 3500)
    finish(name, y, target, fade_out_ms=220)

def guard_break(idx, f0, dur, tau, target=-17.0):
    name = f"guard_break_{idx}"; r = rng(name); n = int(dur * SR)
    y = 1.6 * sine_drop(n, f0, 30, .12, tau) + .6 * noise_burst(r, n, tau * .6, None, 240)
    y += .7 * modal(n, [f0 * 1.4, f0 * 3.2, f0 * 6.0], [1, .6, .35], [.12, .08, .05], r)           # dull body
    times = np.sort(r.uniform(.04, .45, 12)); amps = np.linspace(1.0, .25, 12) * r.uniform(.5, 1, 12)
    y += .5 * clicks(r, n, times, amps, .004, 1500, 8000)                                           # splinters
    y += .9 * noise_burst(r, n, .02, 250, 3500)
    finish(name, y, target, fade_out_ms=140)

def hit_armor(idx, f, cb, dur, tau, target=-21.0):
    name = f"hit_armor_{idx}"; r = rng(name); n = int(dur * SR)
    y = 1.3 * sine_drop(n, f * 1.9, f * .6, .025, tau)
    y += .9 * modes(r, n, cb, np.array([1, 2.31, 3.72, 5.13, 7.4]), tau * 1.4, .5, 1.2)
    y += .8 * noise_burst(r, n, .012, 800, 5000) + .4 * noise_burst(r, n, .05, None, 500)
    y += .5 * noise_burst(r, n, .003, 2500)
    finish(name, y, target, fade_out_ms=40)

def hit_flesh(idx, f, tau, wet, dur=.35, target=-17.5):
    name = f"hit_flesh_{idx}"; r = rng(name); n = int(dur * SR); t = tt(n)
    y = 1.4 * sine_drop(n, f * 1.6, f * .55, .05, tau)
    y += .9 * noise_burst(r, n, .045, None, 650) + .35 * noise_burst(r, n, .02, 200, 900)
    y += (.25 - .12 * wet) * noise_burst(r, n, .01, 1500, 3500)
    if wet > 0:                                                                                     # wet give of tissue
        y += wet * .6 * sweep_bp(r.standard_normal(n), 900 - 500 * np.clip(t / .12, 0, 1), 1.2) * np.exp(-t / .05)
    else:                                                                                           # padding: cloth creak
        y += .25 * noise_burst(r, n, .09, 250, 1400) * (t > .01)
    finish(name, y, target, fade_out_ms=40)

# ---------------------------------------------------------- layer components
def thump(idx, f, target=-23.0):
    name = f"thump_{idx}"; r = rng(name); n = int(.3 * SR)
    y = 1.4 * sine_drop(n, f * 1.8, f * .5, .03, .1) + .6 * noise_burst(r, n, .05, None, 260)
    finish(name, y, target, fade_out_ms=60)

def crack(idx, f0, target=-22.0):
    name = f"crack_{idx}"; r = rng(name); n = int(.22 * SR)
    y = 2.0 * noise_burst(r, n, .004, 1200) + 1.0 * modes(r, n, f0, BAR[:5], .07, .5, 1.5, partner=False)
    y += .8 * clicks(r, n, np.sort(r.uniform(0, .06, 6)), r.uniform(.4, 1, 6), .002, 1500, 9000)
    finish(name, y, target, fade_out_ms=40)

def rattle(idx, f0, target=-24.0):
    name = f"rattle_{idx}"; r = rng(name); n = int(.55 * SR)
    k = 9 + idx * 2
    times = np.sort(r.uniform(0, .38, k)) ** 1.1; amps = np.linspace(1, .2, k) * r.uniform(.5, 1, k)
    y = clicks(r, n, times, amps, .005, 900, 6500)
    y += .5 * modes(r, n, f0, PLATE[:4], .12, .6, 1.5, partner=False) * np.exp(-tt(n) / .25)
    finish(name, y, target, fade_out_ms=90)

def swell(idx, f0, target=-24.0):
    name = f"swell_{idx}"; r = rng(name); n = int(.24 * SR)
    ring = modes(r, n, f0, BAR[:6], .09, .3, .3) + .5 * sweep_bp(r.standard_normal(n), 5000 * np.ones(n), 1.0) * np.exp(-tt(n) / .08)
    y = ring[::-1] * smooth(np.linspace(0, 1, n) * 1.1)
    finish(name, y, target, fade_out_ms=22)

def jingle(idx, f0, target=-28.0):
    name = f"jingle_{idx}"; r = rng(name); n = int(.26 * SR)
    k = 6 + idx
    y = clicks(r, n, np.sort(r.uniform(0, .14, k)), r.uniform(.3, 1, k), .004, 2600, 9000)
    y += .6 * modes(r, n, f0, np.array([1, 1.51, 2.37, 3.3]), .05, .3, .8, partner=False) * (tt(n) < .2)
    finish(name, y, target, fade_out_ms=50)

# ---------------------------------------------------------------- whooshes
def whoosh(name, dur, fa, fp, fe, q, pk, low, whistle, target):
    """band-swept noise: centre frequency rises to fp at pk then falls to fe faster (Doppler-like arc),
    asymmetric amplitude arc, turbulence ripple, an air band an octave up, a faint edge whistle, optional low push"""
    r = rng(name); n = int(dur * SR); u = np.linspace(0, 1, n)
    rise = fa * (fp / fa) ** smooth(u / pk)
    fall = fp * (fe / fp) ** (np.clip((u - pk) / (1 - pk), 0, 1) ** .75)
    fcv = np.where(u < pk, rise, fall)
    a = np.log(.5) / np.log(pk); env = np.sin(np.pi * u ** a) ** 1.4
    turb = lp(r.standard_normal(n), 45); turb = 1 + .3 * turb / (turb.std() + 1e-9)
    y = sweep_bp(r.standard_normal(n), fcv, q) * env * np.clip(turb, .3, 1.8)
    y = y / np.abs(y).max()
    y += .45 * sweep_bp(r.standard_normal(n), np.clip(fcv * 2.3, 100, 16000), q * 1.4) * env ** 1.5 * .5
    y += whistle * sweep_bp(r.standard_normal(n), np.clip(fcv * 3.1, 100, 16000), 14) * env ** 2
    if low: y += low * lp(r.standard_normal(n), 240) * env * .6 * (1 - .4 * u)
    finish(name, y, target, fade_out_ms=25, lead_trim=0.01)

# ------------------------------------------------------------------ footsteps
def _thud(r, n, f, tau):
    return 1.1 * sine_drop(n, f * 1.7, f * .6, .02, tau) + .8 * noise_burst(r, n, tau * .8, None, 240)

def _put(dst, src, at):
    i = int(at * SR); m = min(len(src), len(dst) - i)
    if m > 0: dst[i:i + m] += src[:m]

def step(surface, i, target):
    name = f"step_{surface}_{i}"; r = rng(name)
    dur = {"stone": .26, "metal": .38, "grass": .28, "snow": .32, "water": .42}[surface]
    n = int(dur * SR); t = tt(n); toe_at = r.uniform(.065, .11); toe_g = r.uniform(.4, .6)
    f = r.uniform(80, 125); y = np.zeros(n)
    def heel_toe(fn):
        _put(y, fn(1.0), 0.0); _put(y, fn(toe_g * .75), toe_at)
    if surface == "stone":
        res = r.uniform(520, 1100)
        def hit(g):
            m = int(.2 * SR); s = g * _thud(r, m, f * (1.1 if g < 1 else 1), .05)
            s += g * .9 * noise_burst(r, m, .005, 1500, 5500) + g * .35 * modes(r, m, res, np.array([1, 2.3, 3.7]), .05, .5, 1.0, partner=False)
            return s
        heel_toe(hit)
        m = int(.07 * SR); u = np.linspace(0, 1, m)
        _put(y, r.uniform(.25, .5) * bp(r.standard_normal(m), 900, 4200) * np.sin(np.pi * u) ** 1.5, r.uniform(.015, .04))   # scuff
    elif surface == "metal":
        fb = r.uniform(170, 330)
        def hit(g):
            m = int(.3 * SR)
            s = g * 1.0 * _thud(r, m, f * 1.15, .06)
            s += g * .9 * modes(r, m, fb, PLATE[:6], r.uniform(.1, .2), .35, .6, partner=False)
            s += g * .8 * noise_burst(r, m, .004, 2000, 7000) + g * .35 * modes(r, m, r.uniform(2000, 3600), np.array([1, 1.6, 2.5]), .03, .3, 1.0, partner=False)
            return s
        heel_toe(hit)
        m = int(.05 * SR); _put(y, .3 * bp(r.standard_normal(m), 1500, 6000) * np.exp(-tt(m) / .02), r.uniform(.015, .03))
    elif surface == "grass":
        def hit(g):
            m = int(.2 * SR)
            s = g * 1.0 * (.8 * sine_drop(m, f * 1.3, f * .6, .02, .04) + 1.0 * noise_burst(r, m, .05, 60, 320))
            u = np.linspace(0, 1, m); rus = bp(r.standard_normal(m), 2200, 7000) * np.sin(np.pi * np.clip(u * 2.2, 0, 1)) ** 2 * np.exp(-tt(m) / .07)
            return s + g * r.uniform(.35, .7) * rus + g * .35 * clicks(r, m, r.uniform(.005, .08, 6), r.uniform(.3, 1, 6), .002, 2500, 8000)
        heel_toe(hit)
    elif surface == "snow":
        def hit(g):
            m = int(.22 * SR); k = int(r.integers(28, 46))
            times = r.uniform(0, .11, k) ** 1.2; amps = r.uniform(.2, 1, k) * np.exp(-times / .06)
            s = g * 1.4 * clicks(r, m, times, amps, .0025, 1800, 7500)
            s += g * .9 * (.6 * sine_drop(m, f * 1.1, f * .6, .02, .04) + noise_burst(r, m, .05, 80, 500))
            sq = bp(r.standard_normal(m), 2600, 3300) * np.sin(np.pi * np.linspace(0, 1, m)) ** 2 * np.exp(-tt(m) / .06)
            return s + g * r.uniform(0, .5) * sq
        heel_toe(hit)
    else:  # water, shallow: splash plus droplets
        _put(y, 1.0 * _thud(r, int(.25 * SR), f * .9, .05), 0.0)
        m = int(.3 * SR); u = np.linspace(0, 1, m); tm = tt(m)
        sp = sweep_bp(r.standard_normal(m), 600 * (6 ** np.clip(u / .25, 0, 1)), 1.0) * np.exp(-tm / r.uniform(.07, .11))
        _put(y, 1.3 * sp / (np.abs(sp).max() + 1e-9), 0.0)
        for _ in range(int(r.integers(4, 9))):
            at = r.uniform(.03, .28); m2 = int(.05 * SR); f0 = r.uniform(700, 3000); tm2 = tt(m2)
            drop = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 1.5 * tm2 / .05)) / SR) * np.exp(-tm2 / .012)
            _put(y, r.uniform(.15, .5) * drop, at)
        _put(y, .6 * _thud(r, int(.2 * SR), f * .9, .04), toe_at + .03)
    finish(name, y, target, fade_out_ms=60)

# --------------------------------------------------------------------- build
def build():
    for i, p in enumerate([(1050, .30, .60, 6, 1.0, 0.0, 1.19), (1380, .22, .45, 6, 1.3, .3, 1.12), (880, .40, .80, 6, .8, 0.0, 1.27),
                           (1220, .55, .95, 7, 1.1, .15, 1.07), (760, .26, .55, 5, .7, 0.0, 1.34), (1600, .16, .38, 7, 1.5, .5, 1.16)], 1):
        clash(i, *p)
    for i, p in enumerate([(260, 1500, .30, .06, .5), (200, 1900, .38, .09, .3), (330, 1300, .26, .05, .8), (230, 2200, .34, .08, 0.0)], 1):
        block(i, *p)
    for i, p in enumerate([(1900, .75, 1.0), (2300, .95, 1.25), (2700, 1.1, 1.5)], 1):
        parry(i, *p)
    for i, p in enumerate([(125, 1.0, .40), (150, .9, .32), (105, 1.25, .5)], 1):
        guard_break(i, *p)
    for i, p in enumerate([(105, 620, .45, .10), (88, 480, .45, .12), (120, 820, .38, .08), (96, 540, .5, .15)], 1):
        hit_armor(i, *p)
    for i, p in enumerate([(80, .14, 1.0), (68, .17, .7), (92, .10, 0.0), (74, .13, 0.0)], 1):
        hit_flesh(i, *p)
    for i, f in enumerate([85, 70, 100], 1): thump(i, f)
    for i, f in enumerate([2100, 1700, 2600], 1): crack(i, f)
    for i, f in enumerate([420, 560, 700], 1): rattle(i, f)
    for i, f in enumerate([3200, 4200, 5200], 1): swell(i, f)
    for i, f in enumerate([3300, 4100, 5000, 3700], 1): jingle(i, f)
    for tier, tg, rows in [("light", -17.0, [(.24, 1100, 4200, 1500, 2.4, .42), (.28, 900, 3600, 1200, 2.0, .45), (.22, 1400, 5000, 1800, 2.8, .40)]),
                           ("med", -16.5, [(.36, 600, 2800, 800, 1.8, .45), (.42, 500, 2400, 650, 1.5, .50), (.33, 750, 3100, 1000, 2.0, .42)]),
                           ("heavy", -16.3, [(.62, 180, 1300, 240, 1.2, .52), (.74, 150, 1000, 200, 1.0, .55), (.55, 220, 1500, 300, 1.3, .50)])]:
        for i, (d, fa, fp, fe, q, pk) in enumerate(rows, 1):
            whoosh(f"whoosh_{tier}_{i}", d, fa, fp, fe, q, pk, {"light": 0.0, "med": .3, "heavy": 1.0}[tier],
                   {"light": .10, "med": .08, "heavy": .05}[tier], tg)
    for surface, tg in [("stone", -21.0), ("metal", -20.0), ("grass", -24.0), ("snow", -23.5), ("water", -22.0)]:
        for i in range(1, 7): step(surface, i, tg)
    print(f"combat effects written: {len(LOG)} files, {sum(1 for _, c in LOG if c)} peak-capped at -2 dBFS")

if __name__ == "__main__":
    os.makedirs(os.path.join(ROOT, "sfx"), exist_ok=True)
    build()
