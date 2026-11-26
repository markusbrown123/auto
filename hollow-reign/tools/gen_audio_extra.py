#!/usr/bin/env python3
"""Extra synthesised effects that the sound design bible lists as missing: armour movement, the roll,
a heavy shield impact, a shield recoil scrape and more footstep variants. Original, made from noise and
decaying partials like the rest (tools/gen_audio.py). Nobody has listened to them.
Usage: tools/gen_audio_extra.py"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_audio import SR, rng, tt, lp, hp, bp, modal, sine_drop, noise_burst, clicks, sweep_bp, save_sfx

def armor(i):
    # plates shifting against each other: a few small bright ticks over a soft leather creak
    r = rng("armor%d" % i); n = int(.16 * SR)
    times = np.sort(r.uniform(0.0, 0.09, 4)); amps = r.uniform(0.4, 1.0, 4)
    y = clicks(r, n, times, amps, 0.006, 1800, 7000)
    y += 0.5 * modal(n, [1900 + 300 * i, 3300 + 200 * i, 5200], [0.5, 0.3, 0.2], [0.02, 0.015, 0.01], r) * (tt(n) < 0.08)
    y += 0.25 * noise_burst(r, n, 0.05, 250, 900)
    save_sfx("armor_%d" % i, y, fade_in_ms=1, fade_out_ms=25)

def roll():
    # body going over: cloth and plate rush, shoulder landing, feet coming back under
    r = rng("roll"); n = int(.62 * SR); u = np.linspace(0, 1, n)
    y = sweep_bp(r.standard_normal(n), 500 * (1800 / 500) ** np.sin(np.pi * u), 1.0) * np.sin(np.pi * u) ** 1.2 * 0.6
    for at, f in [(0.16, 95.0), (0.44, 120.0)]:
        m = int(.14 * SR); i0 = int(at * SR)
        y[i0:i0 + m] += 0.9 * sine_drop(m, f * 1.8, f, 0.02, 0.05) + 0.4 * noise_burst(r, m, 0.03, 200, 1400)
    y += 0.35 * clicks(r, n, [0.17, 0.2, 0.45, 0.5], [1.0, 0.6, 0.8, 0.5], 0.006, 1800, 6500)
    save_sfx("roll", y, fade_in_ms=5, fade_out_ms=40)

def shield_heavy():
    # a great blade landing on a shield: low thud, a wide dull ring, a rattle of the straps
    r = rng("shield_heavy"); n = int(.55 * SR)
    y = 1.0 * sine_drop(n, 190, 78, 0.03, 0.09)
    y += 0.7 * modal(n, [212, 468, 905, 1490, 2350], [1.0, 0.7, 0.5, 0.3, 0.2], [0.16, 0.11, 0.07, 0.05, 0.03], r)
    y += 0.8 * noise_burst(r, n, 0.02, 300, 5000)
    y += 0.25 * clicks(r, n, [0.07, 0.11, 0.16], [0.8, 0.5, 0.3], 0.005, 2000, 7000)
    save_sfx("shield_heavy", y, fade_in_ms=0.5, fade_out_ms=40)

def shield_scrape():
    # the blade sliding off the shield face after the blow
    r = rng("shield_scrape"); n = int(.32 * SR); u = np.linspace(0, 1, n)
    y = sweep_bp(r.standard_normal(n), 2600 * (5200 / 2600) ** u, 3.0) * (1 - u) ** 1.5
    y += 0.3 * modal(n, [3100, 4700], [0.6, 0.4], [0.08, 0.05], r)
    save_sfx("shield_scrape", hp(y, 900), fade_in_ms=2, fade_out_ms=40)

def footstep(i):
    # an armoured boot on stone: heel thud, grit, a small plate tick
    r = rng("footstep%d" % i); n = int(.2 * SR)
    y = 0.9 * sine_drop(n, 150 + 12 * i, 62 + 4 * i, 0.012, 0.035)
    y += 0.6 * noise_burst(r, n, 0.018, 500, 3200)
    y += 0.3 * clicks(r, n, [0.035 + 0.004 * i], [1.0], 0.004, 2500, 7000)
    y += 0.2 * noise_burst(r, n, 0.06, 1500, 5000) * (tt(n) > 0.03)
    save_sfx("footstep_%d" % i, y, fade_in_ms=0.5, fade_out_ms=30)

if __name__ == "__main__":
    for i in (1, 2, 3):
        armor(i)
    roll(); shield_heavy(); shield_scrape()
    for i in (3, 4):
        footstep(i)
    print("extra effects written: armor_1..3, roll, shield_heavy, shield_scrape, footstep_3..4")
