#!/usr/bin/env python3
"""Fourth audition reel, to the owner's note: deep, a little echo (not much), old-European accents
(Scottish, Irish, northern European and similar), natural rather than synthetic.
Uses the Inworld speech model, whose voices are named individuals rather than anonymous presets; several are
plainly regional by name, and its Dutch, German and Russian voices are tried reading English for a continental accent.
Accents are NOT verified: nobody has listened. Each take is measured for pitch so the notes can say how deep it is.
Processing: a short stone-room reflection and a gentle low shelf. No pitch shifting.
Output: marketing/audition/casting_v4/. About 2 credits per take.
Usage: tools/voice_reel_inworld.py [role ...]"""
import json, os, subprocess, sys
import numpy as np

ROLES = {
 "witness": (["Hamish (en)", "Mortimer (en)", "Graham (en)", "Clive (en)", "Malcolm (en)", "Gareth (en)"],
   "Ah. At last. I had begun to suspect the dead were better company. ... That gate once bore the banners of thirteen kings. Now look at it. Eternity has a peculiar sense of humour."),
 "orren": (["Shaun (en)", "Callum (en)", "Liam (en)"],
   "So you're what she woke. Hm. Shoulders are wrong. Feet are worse. Well. We'll start with the feet."),
 "monarch": (["Dominus (en)", "Hades (en)", "Rupert (en)", "Nikolai (ru)"],
   "I was never a king. I was the one who stayed. Somebody had to keep the lights burning, and you will find it is harder than it looks."),
 "frostking": (["Lennart (nl)", "Josef (de)", "Erik (nl)"],
   "I watched men become gods. Then I watched gods become machines. Forgive an old man for wanting to sleep through the rest."),
 "player_m": (["Simon (en)", "Edward (en)", "Theodore (en)"],
   "What was it built for? ... Can it be killed?"),
 "lyra": (["Pippa (en)", "Tessa (en)", "Claire (en)", "Celeste (en)"],
   "Can you hear me? Good. Don't try to stand just yet. You've been gone a long while, and I'd rather not lose you twice."),
 "narrator": (["Victoria (en)", "Miranda (en)", "Elizabeth (en)"],
   "The Everbound feared neither age nor sickness. What they feared was being forgotten. And so they built a crown that would remember them for ever."),
 "widow": (["Serena (en)", "Veronica (en)", "Svetlana (ru)"],
   "That stance. I knew the soldier who taught it. He died badly. Let's see whether he taught you why."),
 "player_f": (["Abby (en)", "Julia (en)", "Olivia (en)"],
   "What was it built for? ... Can it be killed?"),
 "archivist": (["Evelyn (en)", "Deborah (en)"],
   "Record incomplete. Witness deceased. Memory ... retained. I am sorry. I was asked to forget this, and I did not."),
}
# a little room, a little weight; the voice itself is left alone
FX = "bass=g=2.5:f=150,aecho=0.9:0.35:55|110:0.16|0.08,loudnorm=I=-18:TP=-2"
OUT = "marketing/audition/casting_v4"
os.makedirs(OUT, exist_ok=True)

def pitch(path):
    pcm = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", "16000", "-f", "s16le", "-"], capture_output=True).stdout
    x = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    f0 = []
    for i in range(0, len(x) - 640, 160):
        w = x[i:i + 640] - x[i:i + 640].mean()
        if float((w * w).mean()) < 1e-4:
            continue
        ac = np.correlate(w, w, "full")[639:]
        k = 40 + int(np.argmax(ac[40:266]))
        if ac[k] > 0.45 * ac[0]:
            f0.append(16000.0 / k)
    return float(np.median(f0)) if len(f0) > 10 else 0.0

notes = ["# Casting reel 4\n", "Deeper, a little echo, regional and continental voices. Candidates in this order. Accents are guessed from the voice names and are not verified; nobody has listened to these.\n"]
parts = []
for role in (sys.argv[1:] or ROLES):
    voices, line = ROLES[role]
    notes.append("\n## %s\nLine: \"%s\"\n" % (role, line))
    for k, voice in enumerate(voices, 1):
        tag = voice.split(" ")[0]
        path = "%s/%s_%d_%s.mp3" % (OUT, role, k, tag)
        raw = path + ".raw"
        if not os.path.exists(path):
            try:
                r = subprocess.run(["higgsfield", "generate", "create", "inworld_text_to_speech", "--prompt", line, "--voice", voice, "--wait", "--wait-timeout", "90s"],
                                   capture_output=True, text=True, timeout=150, stdin=subprocess.DEVNULL)
            except subprocess.TimeoutExpired:
                print(role, voice, "timeout", flush=True); continue
            url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
            if not url.startswith("http"):
                print(role, voice, "FAILED", (r.stderr or r.stdout)[-160:], flush=True); continue
            subprocess.run(["curl", "-sS", "-m", "120", "-o", raw, url], check=True)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af", FX, "-ar", "44100", "-c:a", "libmp3lame", "-q:a", "3", path], check=True)
            os.remove(raw)
        parts.append(path)
        notes.append("%d. **%s** — median pitch %.0f Hz" % (k, voice, pitch(path)))
        print(role, k, voice, flush=True)
open(OUT + "/casting_reel.md", "w").write("\n".join(notes) + "\n")
if parts:
    lst = OUT + "/list.txt"
    open(lst, "w").write("".join("file '%s'\n" % os.path.abspath(p) for p in parts))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c:a", "libmp3lame", "-q:a", "4", OUT + "/casting_reel.mp3"], check=True)
    os.remove(lst)
