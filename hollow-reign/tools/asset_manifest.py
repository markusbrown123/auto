#!/usr/bin/env python3
"""Writes docs/ASSET_MANIFEST.json: every shipped asset with its source, how it
was made, usage rights, cost and whether it is in the game. Re-run after adding assets."""
import glob, json, os
RIGHTS_GEN = "Generated for this project; commercial use depends on the account's plan terms (to be confirmed)"
out = []
def add(path, kind, source, method, rights, cost, status):
    out.append({"path": path, "kind": kind, "bytes": os.path.getsize(path), "source": source, "method": method, "rights": rights, "cost_usd": cost, "status": status})
for f in sorted(glob.glob("assets/models/*.glb")):
    n = os.path.basename(f)
    rig = not (n.startswith("w_") or n.startswith("s_") or n.startswith("env_"))
    add(f, "character model" if rig else ("scenery model" if n.startswith("env_") else "weapon or shield model"), "Tripo API",
        "image-to-3D from art/concept/%s_v1.png%s" % (n[:-4], ", auto-rigged (Mixamo names)" if rig else ""), RIGHTS_GEN,
        1.25 if n == "w_knight_sword.glb" else (1.35 if rig else 0.30), "in game")
for f in sorted(glob.glob("art/concept/*.png")):
    add(f, "concept image", "Higgsfield (GPT Image 2.6)", "text-to-image, prompts in tools/concepts.py", RIGHTS_GEN, 0.05 if "knight" in f or "_v1" in f and not os.path.basename(f)[:2] in ("w_", "s_", "en") else 0.03, "reference only, not shipped")
for f in sorted(glob.glob("assets/video/*.ogv")):
    add(f, "combat/travel footage", "This project", "rendered from the game's own scene by src/cine/clip_stage.gd (Godot movie writer), encoded Ogg Theora 720p30 q7", "Original (derived from the generated models above)", 0.0, "in game (cinematic test)")
for f in sorted(glob.glob("assets/video/stills/*")):
    if not f.endswith(".import"):
        add(f, "view still", "This project", "frame taken from the rendered takes", "Original", 0.0, "in game (cinematic test)")
for f in sorted(glob.glob("assets/audio/vo/*.ogg")):
    add(f, "voice line", "Higgsfield (ElevenLabs v4)", "text-to-speech, cast and text in tools/gen_dialogue.py; effects by ffmpeg", RIGHTS_GEN, 0.02, "in game; not yet auditioned by ear")
for f in sorted(glob.glob("assets/audio/music/*.ogg")):
    n = os.path.basename(f)[:-4]
    gen = n in ("theme", "hub", "explore_courtyard", "boss_ashen_sentinel")
    add(f, "music", "Higgsfield (ElevenLabs Music v2.5)" if gen else "This project", "text-to-music, prompts in tools/music.py; loop made by ffmpeg crossfade" if gen else "synthesized by tools/gen_audio.py",
        RIGHTS_GEN if gen else "Original", 0.5 if gen else 0.0, "in game; not yet auditioned by ear")
for f in sorted(glob.glob("assets/audio/sfx/*.wav")) + sorted(glob.glob("assets/audio/amb/*.ogg")):
    add(f, "sound effect" if "/sfx/" in f else "ambience", "This project", "synthesized by tools/gen_audio.py", "Original", 0.0, "in game; not yet auditioned by ear")
for f in sorted(glob.glob("assets/fonts/*.woff2")):
    add(f, "font", "Fontsource (Cinzel / EB Garamond)", "downloaded", "SIL Open Font License 1.1", 0.0, "in game")
tot = {}
for a in out:
    tot[a["kind"]] = tot.get(a["kind"], 0) + a["bytes"]
json.dump({"generated": "see tools/asset_manifest.py", "count": len(out), "bytes_by_kind": tot, "assets": out}, open("docs/ASSET_MANIFEST.json", "w"), indent=1)
print(len(out), "assets;", {k: round(v / 1048576, 1) for k, v in tot.items()})
