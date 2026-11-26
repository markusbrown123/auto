#!/usr/bin/env python3
"""Audition reel: for each role, the three catalogued voices that best fit the profile's pitch target,
each reading that role's signature line. Output: marketing/audition/casting/<role>_<n>_<voice>.mp3,
casting_reel.mp3 (all, in order) and casting_reel.md (what you are hearing). ~0.46 credit per take.
Usage: tools/voice_reel.py [role ...]"""
import json, os, subprocess, sys, tempfile
CAT = json.load(open("docs/VOICE_CATALOG.json"))
# role: (pitch lo, pitch hi, wants wide range, stability, line)
ROLES = {
 "narrator": (165, 200, False, 0.5, "Once, men begged the gods to spare them from death. The gods did not answer. So men built something that would."),
 "lyra": (185, 225, True, 0.35, "Can you hear me? Good. Don't try to stand yet — you've been dead a long time, and I'd rather you didn't do it again straight away."),
 "player_m": (100, 125, False, 0.5, "Who are you? And why do I know how to hold this?"),
 "player_f": (180, 210, False, 0.5, "Who are you? And why do I know how to hold this?"),
 "orren": (90, 115, True, 0.35, "So you're what she woke up. Hm. Shoulders are wrong. Feet are worse. We'll start with the feet."),
 "sentinel": (85, 105, False, 0.7, "State your allegiance. The gate is closed. The gate has always been closed."),
 "widow": (165, 200, True, 0.35, "That stance. I knew the soldier who taught it. He died badly — let's see if he taught you why."),
 "monarch": (100, 125, True, 0.35, "Look upon what remains of our civilization. I did not destroy it. I am all of it that agreed to stay."),
 "gravewarden": (60, 95, False, 0.7, "These are not tombs. Nothing here was ever allowed to finish dying."),
 "devourer": (150, 200, True, 0.3, "I had a daughter. I think... I think she had my hands."),
}
OUT = "marketing/audition/casting"
os.makedirs(OUT, exist_ok=True)
notes, parts = ["# Casting reel\n", "Three candidates per role, in this order. Nobody has listened to these; the choice is yours.\n"], []
for role in (sys.argv[1:] or ROLES):
    lo, hi, wide, stab, line = ROLES[role]
    mid = (lo + hi) / 2.0
    def score(n):
        v = CAT[n]; rng = v["f0_p90"] - v["f0_p10"]
        return abs(v["f0_median"] - mid) / (hi - lo) - (0.004 * rng if wide else -0.004 * rng)
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
            subprocess.run(["curl", "-sS", "-m", "120", "-o", path, url], check=True)
        parts.append(path)
        notes.append("%d. **%s** — median pitch %.0f Hz, range %.0f Hz, %.1f words/s, stability %.2f" % (k, name, v["f0_median"], v["f0_p90"] - v["f0_p10"], v["words_per_second"], stab))
        print(role, k, name, flush=True)
open(OUT + "/casting_reel.md", "w").write("\n".join(notes) + "\n")
if parts:
    lst = OUT + "/list.txt"
    open(lst, "w").write("".join("file '%s'\n" % os.path.abspath(p) for p in parts))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-af", "loudnorm=I=-18:TP=-2", "-c:a", "libmp3lame", "-q:a", "4", OUT + "/casting_reel.mp3"], check=True)
    os.remove(lst)
