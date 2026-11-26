#!/usr/bin/env python3
"""Generates voice lines for data/dialogue.json through Higgsfield (ElevenLabs v4,
about half a credit a line) into assets/audio/vo/. Skips lines that already exist.
Usage: tools/voices.py [scene_id ...]    (no arguments = every scene)"""
import json, os, subprocess, sys, tempfile, concurrent.futures as cf

D = json.load(open("data/dialogue.json"))
_raw = json.loads(subprocess.run(["higgsfield", "voices", "list", "--json"], capture_output=True, text=True).stdout)
VOICE_IDS = {v["name"]: v for v in (_raw.get("items", _raw.get("voices", [])) if isinstance(_raw, dict) else _raw)}
# light post-processing so each kind of speaker sits in the world differently
FX = {
 "lyra": "highpass=f=180,aecho=0.8:0.5:38:0.18,chorus=0.7:0.9:45:0.25:0.3:2",          # heard through old machinery
 "archivist": "highpass=f=220,lowpass=f=5200,aecho=0.8:0.6:22|47:0.25|0.18,tremolo=f=38:d=0.12",
 "narrator": "aecho=0.8:0.3:90:0.12",
 "helm": "lowpass=f=3400,aecho=0.8:0.7:14|29:0.32|0.2,bass=g=4",                        # spoken inside a closed helmet
 "devourer": "aecho=0.8:0.8:60|130|210:0.4|0.3|0.2,chorus=0.6:0.9:55|70:0.4|0.3:0.25|0.4:2|1.3",
}
HELMED = ["sentinel", "executioner", "gravewarden", "frostking", "monarch", "huntsman", "widow"]
os.makedirs("assets/audio/vo", exist_ok=True)

def make(lid, speaker_key, suffix):
    out = "assets/audio/vo/%s%s.ogg" % (lid, suffix)
    if os.path.exists(out):
        return out, "exists"
    line = D["lines"][lid]
    v = VOICE_IDS[D["voices"][speaker_key]]
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump([{"text": line["text"], "voice_id": v["id"], "voice_type": v["voice_type"]}], f)
    try:
        r = subprocess.run(["higgsfield", "generate", "create", "elevenlabs_v4", "--dialogue", "@" + f.name, "--wait", "--wait-timeout", "90s"], capture_output=True, text=True, timeout=150, stdin=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        return out, "FAILED timeout"
    url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    if not url.startswith("http"):
        return out, "FAILED " + (r.stderr or r.stdout)[-160:]
    raw = out + ".src"
    subprocess.run(["curl", "-sS", "-m", "120", "-o", raw, url], check=True)
    base = line["speaker"]
    fx = FX.get(base) or (FX["helm"] if base in HELMED else "anull")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af", fx + ",loudnorm=I=-18:TP=-2", "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    os.remove(raw)
    return out, "ok"

jobs = []
for sid in ([a for a in sys.argv[1:] if not a.startswith("--")] or list(D["scenes"])):
    for lid in D["scenes"][sid]["lines"]:
        if D["lines"][lid].get("recorded") is False and "--new" not in sys.argv:
            continue      # written but uncast: recording these waits for the owner's casting choice (pass --new to record them)
        sp = D["lines"][lid]["speaker"]
        if sp != "player" and sp not in D["voices"]:
            continue
        if sp == "player":
            jobs += [(lid, "player_m", "_m"), (lid, "player_f", "_f")]
        else:
            jobs.append((lid, sp, ""))
with cf.ThreadPoolExecutor(1) as ex:   # the service stalls when speech jobs run in parallel
    for out, status in ex.map(lambda j: make(*j), jobs):
        if status != "exists":
            print(out.split("/")[-1], status, flush=True)
