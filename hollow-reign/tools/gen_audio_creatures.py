#!/usr/bin/env python3
"""Creature sound libraries: what monsters say instead of words. Synthesised (noise, sawtooth through moving
formants, decaying partials), original, layered the same way as tools/gen_audio.py. Nobody has listened to them.
Families: dragon_* (three dragons share the set, pitched per dragon in game), beast_* (Cathedral Beast and
other engineered creatures), guardian_* (armoured ancient knights: breath through a helm, effort, pain).
Usage: tools/gen_audio_creatures.py"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_audio import SR, rng, tt, lp, hp, bp, modal, sine_drop, noise_burst, clicks, sweep_bp, save_sfx, roar, smooth

def breath(name, dur, lo, hi, wet=0.0, pitch=0.0):
    # one slow breath in and out: shaped noise, with an optional wet rattle and a low body tone
    r = rng(name); n = int(dur * SR); u = np.linspace(0, 1, n)
    env = np.sin(np.pi * np.clip(u / 0.42, 0, 1)) ** 1.5 * 0.7 + np.sin(np.pi * np.clip((u - 0.5) / 0.5, 0, 1)) ** 1.2
    y = bp(r.standard_normal(n), lo, hi) * env
    if wet > 0:
        y += wet * clicks(r, n, np.sort(r.uniform(0.5 * dur, 0.95 * dur, 14)), r.uniform(0.3, 1.0, 14), 0.004, 600, 2600)
    if pitch > 0:
        y += 0.5 * np.sin(2 * np.pi * pitch * tt(n) * (1 + 0.02 * np.sin(2 * np.pi * 3 * tt(n)))) * env
    save_sfx(name, y, fade_in_ms=40, fade_out_ms=120)

def wing(name, dur, weight):
    # a wing beat: a low push of air and the snap of membrane
    r = rng(name); n = int(dur * SR); u = np.linspace(0, 1, n)
    y = lp(r.standard_normal(n), 420) * np.sin(np.pi * u) ** 2 * weight
    y += 0.5 * sweep_bp(r.standard_normal(n), 300 * (1400 / 300) ** u, 1.2) * np.exp(-u * 5)
    m = int(0.05 * SR); i0 = int(0.12 * dur * SR)
    y[i0:i0 + m] += 0.6 * noise_burst(r, m, 0.012, 900, 4200)
    save_sfx(name, y, fade_in_ms=20, fade_out_ms=80)

def jet(name, dur, lo, hi, crackle, hiss):
    # breath weapon: a roar of turbulent air that builds, holds and falls away; crackle for fire, glassy hiss for frost
    r = rng(name); n = int(dur * SR); u = np.linspace(0, 1, n)
    env = smooth(u / 0.12) * (1 - smooth((u - 0.8) / 0.2))
    y = bp(r.standard_normal(n), lo, hi) * env * (1 + 0.25 * lp(r.standard_normal(n), 14))
    y += 0.6 * lp(r.standard_normal(n), 160) * env
    if crackle > 0:
        y += crackle * clicks(r, n, np.sort(r.uniform(0.05 * dur, 0.9 * dur, 60)), r.uniform(0.2, 1.0, 60), 0.003, 1500, 7000)
    if hiss > 0:
        y += hiss * hp(r.standard_normal(n), 5000) * env + 0.2 * modal(n, [3100, 4300, 6100], [0.4, 0.3, 0.2], [0.5, 0.4, 0.3], r) * env
    save_sfx(name, y, fade_in_ms=30, fade_out_ms=200)

def thud(name, f, weight, grit):
    # a great weight landing: claw, tail or body on stone
    r = rng(name); n = int(0.6 * SR)
    y = weight * sine_drop(n, f * 2.2, f, 0.03, 0.14) + grit * noise_burst(r, n, 0.05, 200, 3000)
    y += 0.3 * clicks(r, n, [0.08, 0.14, 0.21, 0.3], [0.9, 0.6, 0.4, 0.25], 0.006, 800, 5000)
    save_sfx(name, y, fade_in_ms=0.5, fade_out_ms=60)

if __name__ == "__main__":
    # --- dragons
    roar("dragon_roar_far", 2.6, 95, 52, "mB", "mD", 19, 1.6, .05)
    roar("dragon_roar_1", 2.2, 82, 40, "mC", "mB", 23, 3.2, .22)
    roar("dragon_roar_2", 2.8, 70, 36, "mA", "mB", 17, 3.6, .25)
    roar("dragon_growl_1", 1.4, 58, 46, "mB", "mB", 31, 2.2, .10)
    roar("dragon_growl_2", 1.7, 52, 40, "mD", "mB", 26, 2.4, .12)
    roar("dragon_pain_1", 0.9, 150, 70, "mC", "mA", 37, 3.4, .30)
    roar("dragon_pain_2", 1.1, 135, 60, "mA", "mC", 43, 3.2, .28)
    roar("dragon_death", 3.4, 110, 30, "mA", "mB", 13, 2.8, .20)
    breath("dragon_breath", 2.4, 90, 900, wet=0.25, pitch=44)
    breath("dragon_exhausted", 1.6, 120, 1400, wet=0.5, pitch=50)
    wing("dragon_wing_1", 0.7, 1.0); wing("dragon_wing_2", 0.85, 1.2)
    jet("dragon_fire", 2.2, 180, 2400, crackle=0.5, hiss=0.0)
    jet("dragon_frost", 2.2, 400, 5200, crackle=0.0, hiss=0.5)
    thud("dragon_claw", 62, 1.0, 0.7); thud("dragon_tail", 48, 1.1, 0.9); thud("dragon_land", 36, 1.3, 1.0)
    # --- the Cathedral Beast and other engineered creatures
    roar("beast_growl_1", 1.2, 88, 66, "mB", "mD", 47, 2.6, .16)
    roar("beast_growl_2", 1.5, 76, 58, "mD", "mB", 39, 2.9, .18)
    roar("beast_threat", 1.9, 120, 64, "mC", "mB", 29, 3.4, .22)
    roar("beast_lunge", 0.7, 160, 95, "mA", "mC", 53, 3.0, .26)
    roar("beast_pain", 0.8, 190, 90, "mC", "mA", 61, 3.2, .30)
    roar("beast_death", 2.6, 130, 42, "mA", "mB", 21, 2.6, .20)
    breath("beast_breath", 1.8, 150, 1800, wet=0.6, pitch=62)
    thud("beast_claw", 90, 0.8, 0.8)
    # --- armoured guardians: no words, only what leaks out of the helm
    breath("guardian_breath", 2.2, 250, 1500, wet=0.0, pitch=0)
    roar("guardian_effort_1", 0.45, 130, 95, "mB", "mB", 71, 1.8, .06)
    roar("guardian_effort_2", 0.55, 115, 85, "mD", "mB", 67, 1.9, .07)
    roar("guardian_pain", 0.6, 150, 100, "mC", "mB", 59, 2.2, .10)
    roar("guardian_death", 1.8, 120, 55, "mB", "mB", 33, 1.8, .08)
    print("creature library written: 17 dragon, 8 beast, 5 guardian sounds")
