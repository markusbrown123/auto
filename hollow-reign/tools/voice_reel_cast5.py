#!/usr/bin/env python3
"""Casting round 5 (owner's correction, 2026-11-27): nothing after Father and Mother was locked. For each remaining character:
four options where option 1 is the voice the owner said they liked and the other three are new voices of the same kind
(natural English voices lowered in pitch, or deep second-model voices; no Asian accent). Built mostly by lowering earlier
takes, so almost nothing new is paid for. Output: marketing/audition/final_cast5/. Nobody has listened to these."""
import json, os, shutil, subprocess, tempfile
A1, A2, A3, A4, OUT = "marketing/audition/final_cast", "marketing/audition/final_cast2", "marketing/audition/final_cast3", "marketing/audition/final_cast4", "marketing/audition/final_cast5"
CAT = json.load(open("docs/VOICE_CATALOG.json"))
WIDOW = "That stance. I knew the soldier who taught it. He died badly. Let's see whether he taught you why."
def low(src, st):   # lower an existing take, tempo and formants kept
    return ("low", src, st)
def keep(src):
    return ("keep", src, 0)
SETS = {  # role: (display, [(label, source)])
 "grandson": ("Grandson", [("Carter, lowered", keep(A4 + "/grandson__1_Carter_low3.mp3")), ("Blake, lowered", keep(A4 + "/grandson__2_Blake_low3.mp3")), ("Ethan, lowered", keep(A4 + "/grandson__3_Ethan_low3.mp3")), ("Grant, lowered", keep(A4 + "/grandson__4_Grant_low3.mp3"))]),
 "granddaughter": ("Granddaughter (high, no accent)", [("Julia", keep(A4 + "/granddaughter__1_Julia.mp3")), ("Olivia", keep(A4 + "/granddaughter__2_Olivia.mp3")), ("Chloe", keep(A4 + "/granddaughter__3_Chloe.mp3")), ("Ashley", keep(A4 + "/granddaughter__4_Ashley.mp3"))]),
 "lyra": ("Lyra", [("Claire, lowered (the one you liked)", keep(A2 + "/05_lyra__4_Claire_low2.mp3")), ("Celeste, lowered", low(A1 + "/05_lyra__4_Celeste.mp3", -2)), ("Tessa, lowered", low(A1 + "/05_lyra__3_Tessa.mp3", -2)), ("Helena", keep(A3 + "/05_lyra__1_Helena.mp3"))]),
 "widow": ("The Crimson Widow", [("Elodie (the one you liked, from Lyra's set)", ("eleven", "Elodie", 0)), ("Veronica, lowered", keep(A2 + "/08_widow__4_Veronica_low3.mp3")), ("Serena, lowered", low(A1 + "/08_widow__1_Serena.mp3", -3)), ("Nora", keep(A2 + "/08_widow__3_Nora.mp3"))]),
 "orren": ("Orren the smith", [("Callum, lowered (the one you liked)", keep(A2 + "/06_orren__4_Callum_low3.mp3")), ("Grant, lowered", low(A1 + "/06_orren__4_Grant.mp3", -3)), ("Shaun, lowered", low(A1 + "/06_orren__2_Shaun.mp3", -3)), ("Sterling", keep(A3 + "/06_orren__2_Sterling.mp3"))]),
 "monarch": ("The Forgotten Monarch", [("Hades, lowered (the one you liked)", keep(A2 + "/07_monarch__4_Hades_low3.mp3")), ("Dominus, lowered", low(A1 + "/07_monarch__2_Dominus.mp3", -3)), ("Rupert, lowered", low(A1 + "/07_monarch__3_Rupert.mp3", -3)), ("Caspian, lowered a little", keep(A3 + "/07_monarch__3_Caspian_low1.mp3"))]),
 "frostking": ("The Frostbound King", [("Josef, lowered (the one you liked; German voice)", keep(A2 + "/09_frostking__4_Josef_low3.mp3")), ("Dennis, lowered", low(A1 + "/09_frostking__4_Dennis.mp3", -3)), ("Alexey", keep(A3 + "/09_frostking__1_Alexey.mp3")), ("Brooks", keep(A3 + "/09_frostking__2_Brooks.mp3"))]),
 "huntsman": ("The Pale Huntsman", [("Craig, lowered (your placeholder)", keep(A2 + "/10_huntsman__4_Craig_low3.mp3")), ("Derek, lowered", keep(A4 + "/huntsman__1_Derek_low3.mp3")), ("Victor, lowered", keep(A4 + "/huntsman__2_Victor_low3.mp3")), ("Dennis, lowered", keep(A4 + "/huntsman__3_Dennis_low3.mp3"))]),
 "gravewarden": ("The Gravewarden", [("Dominus, lowered (the one you liked)", keep(A2 + "/11_gravewarden__4_Dominus_low4.mp3")), ("Sebastian, lowered", low(A1 + "/11_gravewarden__2_Sebastian.mp3", -4)), ("Ronald, lowered", low(A1 + "/11_gravewarden__3_Ronald.mp3", -4)), ("Mark, lowered", low(A1 + "/11_gravewarden__4_Mark.mp3", -4))]),
}
os.makedirs(OUT, exist_ok=True)
notes = ["# Casting round 5\n", "Option 1 is the voice the owner said they liked (where there was one); 2 to 4 are new voices of the same kind. No Asian accents. Nobody has listened.\n"]
for n, (role, (name, cands)) in enumerate(SETS.items(), 1):
    notes.append("\n## %d. %s\n" % (n, name))
    for k, (label, (how, src, st)) in enumerate(cands, 1):
        tag = label.split(",")[0].split(" ")[0]
        path = "%s/%d_%s__%d_%s.mp3" % (OUT, n, role, k, tag)
        if not os.path.exists(path):
            if how == "keep":
                if not os.path.exists(src): print("MISSING", src); continue
                shutil.copy(src, path)
            elif how == "low":
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-af", "rubberband=pitch=%.5f:formant=preserved,loudnorm=I=-18:TP=-2" % (2 ** (st / 12.0)), "-c:a", "libmp3lame", "-q:a", "3", path], check=True)
            else:
                v = CAT[src]; f = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False)
                json.dump([{"text": WIDOW, "voice_id": v["id"], "voice_type": v["voice_type"]}], f); f.close()
                r = subprocess.run(["higgsfield", "generate", "create", "elevenlabs_v4", "--dialogue", "@" + f.name, "--stability", "0.35", "--wait", "--wait-timeout", "90s"], capture_output=True, text=True, timeout=150, stdin=subprocess.DEVNULL)
                url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
                if not url.startswith("http"): print("FAILED", label, (r.stderr or r.stdout)[-160:]); continue
                subprocess.run(["curl", "-sS", "-m", "120", "-o", path + ".raw", url], check=True)
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path + ".raw", "-af", "bass=g=3:f=140,aecho=0.9:0.35:55|110:0.16|0.08,loudnorm=I=-18:TP=-2", "-ar", "44100", "-c:a", "libmp3lame", "-q:a", "3", path], check=True)
                os.remove(path + ".raw")
        notes.append("%d. %s — `%s`" % (k, label, os.path.basename(path)))
        print(role, k, label, flush=True)
open(OUT + "/final_cast5.md", "w").write("\n".join(notes) + "\n")
