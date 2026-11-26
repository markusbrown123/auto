#!/usr/bin/env python3
"""Audition reel: for each role, the three catalogued voices that best fit the profile's pitch target,
each reading that role's signature line. Output: marketing/audition/casting/<role>_<n>_<voice>.mp3,
casting_reel.mp3 (all, in order) and casting_reel.md (what you are hearing). ~0.46 credit per take.
Usage: tools/voice_reel.py [role ...]"""
import json, os, subprocess, sys, tempfile
CAT = json.load(open("docs/VOICE_CATALOG.json"))
# Third reel, to the final voice direction: mature, weathered, grounded; cast by character, not by depth alone.
# No pitch shifting, no echo, no helm effect: the takes are the voices as generated, only levelled.
# Each role draws from a different band so the cast does not collapse onto the same few deep voices.
# role: (pitch lo, pitch hi, wants wide range, stability, line, how many candidates)
ROLES = {
 "witness": (95, 128, True, 0.4, "Ah. At last. I had begun to suspect the dead were better company. ... That gate once bore the banners of thirteen kings. Now look at it. Eternity has a peculiar sense of humour.", 6),
 "lyra": (185, 215, True, 0.45, "Can you hear me? Good. Don't try to stand just yet. You've been gone a long while, and I'd rather not lose you twice.", 4),
 "narrator": (160, 185, False, 0.6, "The Everbound feared neither age nor sickness. What they feared was being forgotten. And so they built a crown that would remember them for ever.", 3),
 "player_m": (100, 125, False, 0.55, "What was it built for? ... Can it be killed?", 3),
 "player_f": (175, 205, False, 0.55, "What was it built for? ... Can it be killed?", 3),
 "orren": (88, 112, True, 0.4, "So you're what she woke. Hm. Shoulders are wrong. Feet are worse. Well. We'll start with the feet.", 3),
 "monarch": (85, 110, False, 0.55, "I was never a king. I was the one who stayed. Somebody had to keep the lights burning, and you will find it is harder than it looks.", 3),
 "widow": (165, 195, False, 0.5, "That stance. I knew the soldier who taught it. He died badly. Let's see whether he taught you why.", 3),
 "frostking": (95, 120, False, 0.65, "I watched men become gods. Then I watched gods become machines. Forgive an old man for wanting to sleep through the rest.", 3),
 "archivist": (125, 160, False, 0.75, "Record incomplete. Witness deceased. Memory ... retained. I am sorry. I was asked to forget this, and I did not.", 3),
}
FX = "loudnorm=I=-18:TP=-2"
OUT = "marketing/audition/casting_v3"
os.makedirs(OUT, exist_ok=True)
used = set()
notes, parts = ["# Casting reel\n", "Third reel: cast by character. Unprocessed takes (levelled only), each voice auditions for one role only. Candidates in this order. Nobody has listened to these; the choice is yours.\n"], []
for role in (sys.argv[1:] or ROLES):
    lo, hi, wide, stab, line, count = ROLES[role]
    mid = (lo + hi) / 2.0
    def score(n):
        v = CAT[n]; rng = v["f0_p90"] - v["f0_p10"]
        # lean low and slow: below the middle of the band is better than above it, and unhurried is better than quick
        off = (v["f0_median"] - mid) / (hi - lo)
        return abs(off) - (0.004 * rng if wide else -0.004 * rng) + 0.2 * (v["words_per_second"] - 3.0)
    picks = [n for n in sorted(CAT, key=score) if n not in used][:count]
    used.update(picks)          # nobody auditions for two roles
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
