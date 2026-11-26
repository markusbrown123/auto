#!/usr/bin/env python3
"""Builds a measured catalogue of every Higgsfield preset voice: one short sample each, then median pitch,
pitch range and speaking rate, so roles can be cast from evidence instead of from names.
Samples go to art/voice_catalog/ (not shipped); results to docs/VOICE_CATALOG.json. Resumable. ~0.46 credit per voice.
Usage: tools/voice_catalog.py [max_new]"""
import json, os, subprocess, sys, tempfile
import numpy as np

LINE = "The crown does not rest. It waits, and it remembers every name it has ever worn."
OUT = "art/voice_catalog"
os.makedirs(OUT, exist_ok=True)
CAT = "docs/VOICE_CATALOG.json"
cat = json.load(open(CAT)) if os.path.exists(CAT) else {}
raw = json.loads(subprocess.run(["higgsfield", "voices", "list", "--json"], capture_output=True, text=True, stdin=subprocess.DEVNULL).stdout)
voices = raw.get("items", raw.get("voices", [])) if isinstance(raw, dict) else raw

def measure(path):
    pcm = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", "16000", "-f", "s16le", "-"], capture_output=True).stdout
    x = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    n, hop, f0 = 640, 160, []
    voiced_frames = 0
    for i in range(0, len(x) - n, hop):
        w = x[i:i + n] - x[i:i + n].mean()
        e = float((w * w).mean())
        if e < 1e-4:
            continue
        voiced_frames += 1
        ac = np.correlate(w, w, "full")[n - 1:]
        lo, hi = 16000 // 400, 16000 // 60
        k = lo + int(np.argmax(ac[lo:hi]))
        if ac[k] > 0.45 * ac[0]:
            f0.append(16000.0 / k)
    if len(f0) < 10:
        return None
    f0 = np.array(f0)
    return {"f0_median": round(float(np.median(f0)), 1), "f0_p10": round(float(np.percentile(f0, 10)), 1),
            "f0_p90": round(float(np.percentile(f0, 90)), 1), "seconds": round(len(x) / 16000.0, 2),
            "speech_seconds": round(voiced_frames * hop / 16000.0, 2), "words_per_second": round(len(LINE.split()) / max(voiced_frames * hop / 16000.0, 0.1), 2)}

budget = int(sys.argv[1]) if len(sys.argv) > 1 else 999
fails = 0
for v in voices:
    name = v["name"]
    path = "%s/%s.mp3" % (OUT, name)
    if name in cat and os.path.exists(path):
        continue
    if not os.path.exists(path):
        if budget <= 0 or fails >= 3:
            continue
        budget -= 1
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump([{"text": LINE, "voice_id": v["id"], "voice_type": v["voice_type"]}], f)
        try:
            r = subprocess.run(["higgsfield", "generate", "create", "elevenlabs_v4", "--dialogue", "@" + f.name, "--wait", "--wait-timeout", "90s"], capture_output=True, text=True, timeout=150, stdin=subprocess.DEVNULL)
        except subprocess.TimeoutExpired:
            fails += 1; print(name, "timeout", flush=True); continue
        url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
        if not url.startswith("http"):
            fails += 1; print(name, "FAILED", (r.stderr or r.stdout)[-120:], flush=True); continue
        subprocess.run(["curl", "-sS", "-m", "120", "-o", path, url], check=True)
        fails = 0
    m = measure(path)
    if m:
        cat[name] = dict(m, id=v["id"], voice_type=v["voice_type"])
        json.dump(cat, open(CAT, "w"), indent=1, sort_keys=True)
        print(name, m["f0_median"], m["words_per_second"], flush=True)
print("catalogued", len(cat), "of", len(voices))
