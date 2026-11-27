#!/usr/bin/env python3
"""Final casting round asked for by the owner (2026-11-27): four candidate voices for every speaking character that is
not yet owner-approved, each as its own file named after the character and the voice.
Earlier audition takes are reused where they exist (same line, same treatment), so nothing is paid for twice.
Output: marketing/audition/final_cast/<NN>_<Character>__<k>_<Voice>.mp3 and final_cast.md. About 2 credits per new take.
Nobody has listened to these; accents and quality are unverified.
Usage: tools/voice_reel_cast.py [role ...]"""
import os, shutil, subprocess, sys
sys.path.insert(0, os.path.dirname(__file__))

FX = "bass=g=2.5:f=150,aecho=0.9:0.35:55|110:0.16|0.08,loudnorm=I=-18:TP=-2"   # same light room as the approved cast
OLD = "marketing/audition/casting_v4"
OUT = "marketing/audition/final_cast"
FORE = "Three villages have fallen silent. Their names have been struck from your records. ... You speak of people as though they were coin. ... Then another will come better prepared."
HEIR = "Three of my house have stood before those gates. And how many returned? ... Then show me another way. ... Two lives. You speak of them as though they were years."
# role: (display name, candidates, line, key of the earlier reel to reuse takes from)
ROLES = {
 "father":        ("Father (first generation, male line)", ["Clive (en)", "Gareth (en)", "Rupert (en)", "Victor (en)"], FORE, ""),
 "mother":        ("Mother (first generation, female line)", ["Elizabeth (en)", "Miranda (en)", "Evelyn (en)", "Deborah (en)"], FORE, ""),
 "grandson":      ("Grandson (last heir, male line)", ["Liam (en)", "Sebastian (en)", "Oliver (en)", "James (en)"], HEIR, ""),
 "granddaughter": ("Granddaughter (last heir, female line)", ["Serena (en)", "Veronica (en)", "Celeste (en)", "Jessica (en)"], HEIR, ""),
 "lyra":          ("Lyra", ["Claire (en)", "Pippa (en)", "Tessa (en)", "Celeste (en)"],
                   "Can you hear me? Good. Don't try to stand just yet. You've been gone a long while, and I'd rather not lose you twice.", "lyra"),
 "orren":         ("Orren the smith", ["Callum (en)", "Shaun (en)", "Liam (en)", "Grant (en)"],
                   "So you're what she woke. Hm. Shoulders are wrong. Feet are worse. Well. We'll start with the feet.", "orren"),
 "monarch":       ("The Forgotten Monarch", ["Hades (en)", "Dominus (en)", "Rupert (en)", "Nikolai (ru)"],
                   "I was never a king. I was the one who stayed. Somebody had to keep the lights burning, and you will find it is harder than it looks.", "monarch"),
 "widow":         ("The Crimson Widow", ["Serena (en)", "Veronica (en)", "Svetlana (ru)", "Marlene (en)"],
                   "That stance. I knew the soldier who taught it. He died badly. Let's see whether he taught you why.", "widow"),
 "frostking":     ("The Frostbound King", ["Lennart (nl)", "Josef (de)", "Erik (nl)", "Dennis (en)"],
                   "I watched men become gods. Then I watched gods become machines. Forgive an old man for wanting to sleep through the rest.", "frostking"),
 "huntsman":      ("The Pale Huntsman", ["Craig (en)", "Derek (en)", "Grant (en)", "Hank (en)"],
                   "You wake what ought to sleep. Turn back down the road, or I leave you for the wood to keep.", ""),
 "gravewarden":   ("The Gravewarden", ["Dominus (en)", "Sebastian (en)", "Ronald (en)", "Mark (en)"],
                   "These stones bear no bodies. Only names. ... Leave them their rest, and go.", ""),
}
CURRENT = {"lyra": "Claire", "orren": "Callum", "monarch": "Hades"}   # already recorded in the game with this voice

def make(line, voice, path):
    raw = path + ".raw"
    try:
        r = subprocess.run(["higgsfield", "generate", "create", "inworld_text_to_speech", "--prompt", line, "--voice", voice, "--wait", "--wait-timeout", "90s"],
                           capture_output=True, text=True, timeout=150, stdin=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        return "timeout"
    url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    if not url.startswith("http"):
        return "FAILED " + (r.stderr or r.stdout)[-160:]
    subprocess.run(["curl", "-sS", "-m", "120", "-o", raw, url], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af", FX, "-ar", "44100", "-c:a", "libmp3lame", "-q:a", "3", path], check=True)
    os.remove(raw)
    return "new"

def main():
    os.makedirs(OUT, exist_ok=True)
    notes = ["# Final casting round\n", "Four candidates per character, same line and same light room treatment. Nobody has listened to these.\n"]
    new = 0
    for n, role in enumerate(ROLES, 1):
        if sys.argv[1:] and role not in sys.argv[1:]:
            continue
        name, voices, line, old = ROLES[role]
        notes.append("\n## %s\nLine: \"%s\"\n" % (name, line))
        for k, voice in enumerate(voices, 1):
            tag = voice.split(" ")[0]
            path = "%s/%02d_%s__%d_%s.mp3" % (OUT, n, role, k, tag)
            how = "kept"
            if not os.path.exists(path):
                prev = [f for f in os.listdir(OLD) if old and f.startswith(old + "_") and f.endswith("_%s.mp3" % tag)]
                if prev:
                    shutil.copy(os.path.join(OLD, prev[0]), path); how = "reused"
                else:
                    how = make(line, voice, path)
                    new += how == "new"
            mark = "  (the voice now in the game)" if CURRENT.get(role) == tag else ""
            notes.append("%d. **%s**%s — `%s` [%s]" % (k, tag, mark, os.path.basename(path), how))
            print(role, k, tag, how, flush=True)
    open(OUT + "/final_cast.md", "w").write("\n".join(notes) + "\n")
    print("new takes:", new)

main()
