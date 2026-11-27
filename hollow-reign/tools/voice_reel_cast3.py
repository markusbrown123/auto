#!/usr/bin/env python3
"""Casting round 3 (owner: not an accent, an English anime-dub style voice, deeper and edgier, like the option-3 voices they chose; the granddaughter higher than the mother). All from the second speech model, expressive setting.\nBased on round 2: (owner, 2026-11-27): "A lot deeper, maybe Chinese style for voices, deep, anime style."
Four candidates per character again, each its own labelled file: East Asian voices of the Inworld model reading the English
lines (Chinese, Japanese, Korean), the deepest catalogued voices of the second model, and the round-1 voice lowered in pitch
(tempo kept). Pitch of every result is measured. Nobody has listened; accent and style are unverified.
Output: marketing/audition/final_cast2/. Usage: tools/voice_reel_cast2.py [role ...]"""
import json, os, subprocess, sys, tempfile
import numpy as np
OUT = "marketing/audition/final_cast3"
CAT = json.load(open("docs/VOICE_CATALOG.json"))
FORE = "Three villages have fallen silent. Their names have been struck from your records. ... You speak of people as though they were coin. ... Then another will come better prepared."
HEIR = "Three of my house have stood before those gates. And how many returned? ... Then show me another way. ... Two lives. You speak of them as though they were years."
L = {"lyra": "Can you hear me? Good. Don't try to stand just yet. You've been gone a long while, and I'd rather not lose you twice.",
     "orren": "So you're what she woke. Hm. Shoulders are wrong. Feet are worse. Well. We'll start with the feet.",
     "monarch": "I was never a king. I was the one who stayed. Somebody had to keep the lights burning, and you will find it is harder than it looks.",
     "widow": "That stance. I knew the soldier who taught it. He died badly. Let's see whether he taught you why.",
     "frostking": "I watched men become gods. Then I watched gods become machines. Forgive an old man for wanting to sleep through the rest.",
     "huntsman": "You wake what ought to sleep. Turn back down the road, or I leave you for the wood to keep.",
     "gravewarden": "These stones bear no bodies. Only names. ... Leave them their rest, and go."}
I, E = "inworld", "eleven"
# role: (display, line, [(engine, voice, semitones, label)])
ROLES = {
 "grandson": ("Grandson", HEIR, [(E, "Holden", 0, "Holden"), (E, "Orion", 0, "Orion"), (E, "Desmond", 0, "Desmond"), (E, "Jasper", 0, "Jasper")]),
 "granddaughter": ("Granddaughter (higher than the mother)", HEIR, [(E, "Maeve", 0, "Maeve"), (E, "Imogen", 0, "Imogen"), (E, "Raina", 0, "Raina"), (E, "Tamsin", 0, "Tamsin")]),
 "lyra": ("Lyra", L["lyra"], [(E, "Helena", 0, "Helena"), (E, "Vera", 0, "Vera"), (E, "Livia", 0, "Livia"), (E, "Naomi", 0, "Naomi")]),
 "orren": ("Orren the smith", L["orren"], [(E, "Bob", 0, "Bob"), (E, "Sterling", 0, "Sterling"), (E, "Ken", 0, "Ken"), (E, "Grady", 0, "Grady")]),
 "monarch": ("The Forgotten Monarch", L["monarch"], [(E, "Vlad", 0, "Vlad"), (E, "Alistair", 0, "Alistair"), (E, "Caspian", -1, "Caspian, lowered a little"), (E, "Barrett", 0, "Barrett")]),
 "widow": ("The Crimson Widow", L["widow"], [(E, "Nora", 0, "Nora"), (E, "Onyx", 0, "Onyx"), (E, "Vesper", 0, "Vesper"), (E, "Xenia", 0, "Xenia")]),
 "frostking": ("The Frostbound King", L["frostking"], [(E, "Alexey", 0, "Alexey"), (E, "Brooks", 0, "Brooks"), (E, "Julian", 0, "Julian"), (E, "Fraser", 0, "Fraser")]),
 "huntsman": ("The Pale Huntsman", L["huntsman"], [(E, "Jake", 0, "Jake"), (E, "Xavier", 0, "Xavier"), (E, "Knox", 0, "Knox"), (E, "Cillian", 0, "Cillian")]),
 "gravewarden": ("The Gravewarden", L["gravewarden"], [(E, "Sterling", -1, "Sterling, lowered a little"), (E, "Barrett", -1, "Barrett, lowered a little"), (E, "Harrison", 0, "Harrison"), (E, "Marcus", 0, "Marcus")]),
}
RAW = {}   # (engine, voice, line) -> raw file, so one paid take serves several pitch treatments

def pitch(path):
    pcm = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", "16000", "-f", "s16le", "-"], capture_output=True).stdout
    x = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    f0 = []
    for i in range(0, len(x) - 640, 160):
        w = x[i:i + 640] - x[i:i + 640].mean()
        if float((w * w).mean()) < 1e-4: continue
        ac = np.correlate(w, w, "full")[639:]
        k = 40 + int(np.argmax(ac[40:266]))
        if ac[k] > 0.45 * ac[0]: f0.append(16000.0 / k)
    return float(np.median(f0)) if len(f0) > 10 else 0.0

def fetch(engine, voice, line):
    key = (engine, voice, line)
    if key in RAW: return RAW[key], 0
    raw = "%s/.raw_%s_%s_%d.mp3" % (OUT, engine, voice.split(" ")[0], abs(hash(line)) % 100000)
    if engine == I:
        cmd = ["higgsfield", "generate", "create", "inworld_text_to_speech", "--prompt", line, "--voice", voice, "--wait", "--wait-timeout", "90s"]
    else:
        v = CAT[voice]
        f = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False)
        json.dump([{"text": line, "voice_id": v["id"], "voice_type": v["voice_type"]}], f); f.close()
        cmd = ["higgsfield", "generate", "create", "elevenlabs_v4", "--dialogue", "@" + f.name, "--stability", "0.3", "--wait", "--wait-timeout", "90s"]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=150, stdin=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        return None, 0
    url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    if not url.startswith("http"):
        print("  FAILED", voice, (r.stderr or r.stdout)[-160:], flush=True); return None, 0
    subprocess.run(["curl", "-sS", "-m", "120", "-o", raw, url], check=True)
    RAW[key] = raw
    return raw, 1

def main():
    os.makedirs(OUT, exist_ok=True)
    notes = ["# Casting round 2: deeper, East Asian voices, lowered voices\n", "Nobody has listened to these. Pitch is measured (lower = deeper).\n"]
    new = 0
    for n, role in enumerate(ROLES, 3):
        if sys.argv[1:] and role not in sys.argv[1:]: continue
        name, line, cands = ROLES[role]
        notes.append("\n## %s\n" % name)
        for k, (engine, voice, st, label) in enumerate(cands, 1):
            tag = voice.split(" ")[0] + ("_low%d" % -st if st else "")
            path = "%s/%02d_%s__%d_%s.mp3" % (OUT, n, role, k, tag)
            if not os.path.exists(path):
                raw, paid = fetch(engine, voice, line); new += paid
                if not raw: continue
                fx = ("rubberband=pitch=%.5f:formant=preserved," % (2 ** (st / 12.0)) if st else "") + "bass=g=3:f=140,aecho=0.9:0.35:55|110:0.16|0.08,loudnorm=I=-18:TP=-2"
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af", fx, "-ar", "44100", "-c:a", "libmp3lame", "-q:a", "3", path], check=True)
            hz = pitch(path)
            notes.append("%d. **%s** — %.0f Hz — `%s`" % (k, label, hz, os.path.basename(path)))
            print(role, k, label, "%.0f Hz" % hz, flush=True)
    for f in os.listdir(OUT):
        if f.startswith(".raw_"): os.remove(os.path.join(OUT, f))
    open(OUT + "/final_cast3.md", "w").write("\n".join(notes) + "\n")
    print("new takes:", new)
main()
