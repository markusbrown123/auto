#!/usr/bin/env python3
"""Measures sound-effect families: duration, peak, loudness and spectral centroid, so that variants can be
shown to differ and to be level-matched. Loudness is the maximum EBU R128 momentary value (400 ms window)
reported by ffmpeg's ebur128 filter after padding each short file with silence to 1 s (ffmpeg reports nothing
for files shorter than 400 ms otherwise); `LUFS-M` below means that. The centroid is the power-weighted mean
frequency over the whole file. Nobody has listened to any of this: these are numbers, not quality.
Usage: tools/gen_audio_measure.py [prefix ...]      (default: the combat and footstep families)
"""
import os, re, subprocess, sys
import numpy as np
from scipy.io import wavfile

SFX = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "sfx"))
DEFAULT = ["clash_", "block_", "parry_", "guard_break_", "hit_armor_", "hit_flesh_", "whoosh_", "swing_", "thump_", "crack_",
           "rattle_", "swell_", "jingle_", "footstep_", "step_stone", "step_metal", "step_grass", "step_snow", "step_water"]

def momentary_max(path):
    o = subprocess.run(["ffmpeg", "-nostats", "-i", path, "-af", "apad=whole_dur=1,ebur128=peak=true", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
    vals = [float(m) for m in re.findall(r"M:\s*(-?[\d.]+)\s", o) if float(m) > -69]
    return max(vals) if vals else float("nan")

def measure(path):
    sr, x = wavfile.read(path); xf = x.astype(float) / 32768.0
    spec = np.abs(np.fft.rfft(xf)) ** 2; fr = np.fft.rfftfreq(len(xf), 1 / sr)
    return {"dur": len(xf) / sr, "peak": 20 * np.log10(np.abs(xf).max() + 1e-9), "lufs_m": momentary_max(path),
            "centroid": float((spec * fr).sum() / (spec.sum() + 1e-12))}

def family_files(prefix):
    return sorted(f for f in os.listdir(SFX) if f.endswith(".wav") and f.startswith(prefix))

def report(prefixes):
    print(f"{'file':26s}{'dur s':>7s}{'peak dB':>9s}{'LUFS-M':>8s}{'centroid Hz':>13s}")
    for p in prefixes:
        rows = []
        for f in family_files(p):
            m = measure(os.path.join(SFX, f)); rows.append(m)
            print(f"{f:26s}{m['dur']:7.2f}{m['peak']:9.1f}{m['lufs_m']:8.1f}{m['centroid']:13.0f}")
        if len(rows) > 1:
            a = lambda k: np.array([r[k] for r in rows])
            print(f"  -> {p:<11s} n={len(rows)} dur {a('dur').min():.2f}-{a('dur').max():.2f}  LUFS-M spread {np.ptp(a('lufs_m')):.1f} dB  "
                  f"centroid {a('centroid').min():.0f}-{a('centroid').max():.0f}")

if __name__ == "__main__":
    report(sys.argv[1:] or DEFAULT)
