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

import hashlib
TAKES_PATH = "assets/audio/vo/takes.json"
TAKES = json.load(open(TAKES_PATH)) if os.path.exists(TAKES_PATH) else {}
RECAST = [a[9:].split(",") for a in sys.argv if a.startswith("--recast=")]
RECAST = RECAST[0] if RECAST else []
# owner's direction: a little stone-room echo, a little weight, the voice itself untouched
ROOM = "bass=g=2.5:f=150,aecho=0.9:0.35:55|110:0.16|0.08"
# the female knight (owner's choice): the accent of this voice, treated for clarity — presence up, low-mids down, lighter room
CLEAR = "highpass=f=90,equalizer=f=3500:t=q:w=1.2:g=4.5,equalizer=f=250:t=q:w=1.0:g=-2,treble=g=1.5:f=7000,aecho=0.9:0.22:45|95:0.10|0.05"
ROLE_FX = {"player_f": CLEAR, "witness": ROOM + ",aecho=0.9:0.25:11:0.12", "narrator": "bass=g=2:f=150,aecho=0.9:0.4:80|170:0.18|0.1"}

def text_hash(line):
    return hashlib.sha1(line["text"].encode()).hexdigest()[:12]

def make_inworld(lid, line, voice, out, key=""):
    """The owner-approved cast: a named voice on the Inworld model (2 credits a take)."""
    try:
        r = subprocess.run(["higgsfield", "generate", "create", "inworld_text_to_speech", "--prompt", line["text"], "--voice", voice, "--wait", "--wait-timeout", "120s"],
                           capture_output=True, text=True, timeout=180, stdin=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        return out, "FAILED timeout"
    url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    if not url.startswith("http"):
        return out, "FAILED " + (r.stderr or r.stdout)[-160:]
    raw = out + ".src"
    subprocess.run(["curl", "-sS", "-m", "120", "-o", raw, url], check=True)
    fx = ROLE_FX.get(key, ROLE_FX.get(line["speaker"], ROOM))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af", fx + ",loudnorm=I=-18:TP=-2", "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    os.remove(raw)
    if os.path.exists(TAKES_PATH):
        TAKES.update(json.load(open(TAKES_PATH)))
    TAKES[os.path.basename(out)] = text_hash(line)
    json.dump(TAKES, open(TAKES_PATH, "w"), indent=1, sort_keys=True)
    return out, "ok"

def make(lid, speaker_key, suffix):
    out = "assets/audio/vo/%s%s.ogg" % (lid, suffix)
    base_speaker = D["lines"][lid]["speaker"]
    redo = (speaker_key in RECAST or base_speaker in RECAST) and TAKES.get(os.path.basename(out)) != text_hash(D["lines"][lid])
    if os.path.exists(out) and not redo:
        return out, "exists"
    line = D["lines"][lid]
    cast = D["voices"][speaker_key]
    if cast.startswith("inworld:"):
        return make_inworld(lid, line, cast[8:], out, speaker_key)
    v = VOICE_IDS[cast]
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
ONLY = [a[7:].split(",") for a in sys.argv if a.startswith("--only=")]
if ONLY:
    jobs = [j for j in jobs if j[1] in ONLY[0]]
with cf.ThreadPoolExecutor(1) as ex:   # the service stalls when speech jobs run in parallel
    for out, status in ex.map(lambda j: make(*j), jobs):
        if status != "exists":
            print(out.split("/")[-1], status, flush=True)
