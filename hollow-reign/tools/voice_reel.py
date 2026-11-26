#!/usr/bin/env python3
"""Audition reel: for each role, the three catalogued voices that best fit the profile's pitch target,
each reading that role's signature line. Output: marketing/audition/casting/<role>_<n>_<voice>.mp3,
casting_reel.mp3 (all, in order) and casting_reel.md (what you are hearing). ~0.46 credit per take.
Usage: tools/voice_reel.py [role ...]"""
import json, os, subprocess, sys, tempfile
CAT = json.load(open("docs/VOICE_CATALOG.json"))
# Second reel, after the owner's note: older, deeper, graver — the weight of dark fantasy epics.
# Cast from the lowest and slowest voices in the measured catalogue, written in a plainer, older cadence,
# then set a little deeper and placed in stone (pitch down about a semitone, low shelf, short hall).
# role: (pitch lo, pitch hi, wants wide range, stability, line)
ROLES = {
 "narrator": (140, 175, False, 0.6, "In the elder days, men begged the gods to spare them from death. The gods kept their silence. And so men built a thing that would answer."),
 "lyra": (150, 185, True, 0.45, "Can you hear me? Good. Lie still a while. You have been a long time dead, and I would not have you do it twice."),
 "player_m": (80, 108, False, 0.6, "Who speaks? ... And why does my hand know the weight of this blade?"),
 "player_f": (140, 175, False, 0.6, "Who speaks? ... And why does my hand know the weight of this blade?"),
 "orren": (75, 102, True, 0.45, "So. You are what she woke. Hm. The shoulders are wrong. The feet are worse. We begin with the feet."),
 "sentinel": (70, 98, False, 0.75, "Halt. Name your allegiance. The gate is shut. The gate has ever been shut."),
 "widow": (140, 175, True, 0.45, "That stance. I knew the soldier who taught it. He died badly. Come, then. Show me whether he taught you why."),
 "monarch": (75, 105, True, 0.5, "Look upon what remains of us. I did not unmake it. I am only the last of it that would not leave."),
 "gravewarden": (60, 92, False, 0.75, "These are not tombs, child. Nothing here was ever suffered to finish dying."),
 "devourer": (95, 150, True, 0.4, "I had a daughter once. I think ... I think she had my hands."),
}
# deeper, and in a hall of stone
FX = "asetrate=44100*0.94,aresample=44100,atempo=1.03,bass=g=5:f=140,treble=g=-2:f=5000,aecho=0.85:0.5:60|140:0.22|0.12"
OUT = "marketing/audition/casting_v2"
os.makedirs(OUT, exist_ok=True)
notes, parts = ["# Casting reel\n", "Second reel: deeper, older, graver. Three candidates per role, in this order. Each take is set about a semitone lower and placed in a stone hall. Nobody has listened to these; the choice is yours.\n"], []
for role in (sys.argv[1:] or ROLES):
    lo, hi, wide, stab, line = ROLES[role]
    mid = (lo + hi) / 2.0
    def score(n):
        v = CAT[n]; rng = v["f0_p90"] - v["f0_p10"]
        # lean low and slow: below the middle of the band is better than above it, and unhurried is better than quick
        off = (v["f0_median"] - mid) / (hi - lo)
        return (abs(off) if off < 0 else off * 2.0) - (0.004 * rng if wide else -0.004 * rng) + 0.25 * (v["words_per_second"] - 3.0)
    picks = sorted(CAT, key=score)[:3]
    notes.append("\n## %s\nLine: \"%s\"\n" % (role, line))
    for k, name in enumerate(picks, 1):
        v = CAT[name]; path = "%s/%s_%d_%s.mp3" % (OUT, role, k, name)
        if not os.path.exists(path):
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump([{"text": line, "voice_id": v["id"], "voice_type": v["voice_type"]}], f)
            try:
                r = subprocess.run(["higgsfield", "generate", "create", "elevenlabs_v4", "--dialogue", "@" + f.name, "--stability", str(stab), "--wait", "--wait-timeout", "90s"],
                                   capture_output=True, text=True, timeout=150, stdin=subprocess.DEVNULL)
            except subprocess.TimeoutExpired:
                print(role, name, "timeout", flush=True); continue
            url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
            if not url.startswith("http"):
                print(role, name, "FAILED", (r.stderr or r.stdout)[-160:], flush=True); continue
            subprocess.run(["curl", "-sS", "-m", "120", "-o", path + ".raw.mp3", url], check=True)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path + ".raw.mp3", "-af", FX, "-c:a", "libmp3lame", "-q:a", "3", path], check=True)
            os.remove(path + ".raw.mp3")
        parts.append(path)
        notes.append("%d. **%s** — median pitch %.0f Hz, range %.0f Hz, %.1f words/s, stability %.2f" % (k, name, v["f0_median"], v["f0_p90"] - v["f0_p10"], v["words_per_second"], stab))
        print(role, k, name, flush=True)
open(OUT + "/casting_reel.md", "w").write("\n".join(notes) + "\n")
if parts:
    lst = OUT + "/list.txt"
    open(lst, "w").write("".join("file '%s'\n" % os.path.abspath(p) for p in parts))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-af", "loudnorm=I=-18:TP=-2", "-c:a", "libmp3lame", "-q:a", "4", OUT + "/casting_reel.mp3"], check=True)
    os.remove(lst)
