#!/usr/bin/env python3
"""Real armour sets: a full-body knight model per set and per body, so equipping armour changes the geometry.
Step 1 (this tool, 'concepts'): a concept per set and body, generated from the approved knight as a reference so the
build, helm silhouette language and proportions stay the same (Higgsfield image, about 1.25 credits each).
Step 2 ('models'): each concept through tools/tripo.py (low-poly model + Mixamo rig, $1.35) into
assets/models/knight_<body>_<set>.glb. Resumable; never regenerates something that exists.
Usage: tools/armor_sets.py concepts|models [set ...]"""
import os, shutil, subprocess, sys, concurrent.futures as cf
SETS = {  # set id (matches the chest item a_<id>_chest) : (name, description)
 "garrison": ("Crownless plate", "plain garrison plate: brushed grey steel, simple clean panels, dark blue cloth at the joints, little ornament"),
 "ash": ("Ashbound", "blackened steel plate with heavier layered shoulder and chest plates, ember-orange light in thin seams, soot-dark cloth"),
 "black": ("Widow's Regalia", "light close-fitting armour in deep crimson and black lacquer, narrow elegant plates, a slim swept helm, made for speed"),
 "vigil": ("Gravekeeper", "ancient dark bronze-green plate with a weathered patina, a hooded mantle of small scales over the shoulders, dim green light at the chest"),
 "frost": ("Frostwarden", "pale silver plate with faceted pale-blue crystalline inlays, frost-white cloth, a tall narrow helm crest"),
 "regal": ("Sovereign", "regal black plate with antique gold edging and filigree, a high collar, a crown-like ridge on the helm, deep red cloth"),
 "wyrm": ("Dragonforged", "heavy armour of overlapping dark red-bronze scale plates, clawed gauntlets, a horned helm, charcoal cloth"),
 "hollow": ("Architect", "smooth seamless white-and-graphite armour with thin lines of white-gold light, almost no rivets, a featureless visor: plainly advanced technology"),
}
FRAME = (" Keep exactly the same person, body proportions, height, slim athletic build and pose as the reference image: full body, standing in a neutral A-pose facing the camera, "
         "arms held away from the body, legs apart, empty hands, no weapon, no shield, no cloak or cape. Change only the armour. Even soft studio lighting, plain light grey background, "
         "whole figure in frame from head to toe, realistic materials, sharp high detail. No text, no logos.")

def concept(job):
    sid, body = job
    out = "art/concept/armor_%s_%s_v1.png" % (sid, body)
    if os.path.exists(out):
        return out, "exists"
    prompt = "Original character design for a sci-fantasy action game: the same sleek future-knight as the reference, now wearing a different suit of armour: " + SETS[sid][1] + "." + FRAME
    r = subprocess.run(["higgsfield", "generate", "create", "gpt_image_2_6", "--prompt", prompt, "--image-references", "art/concept/knight_%s_v2.png" % body,
                        "--aspect_ratio", "3:4", "--resolution", "2k", "--wait", "--wait-timeout", "10m"], capture_output=True, text=True, stdin=subprocess.DEVNULL)
    url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    if not url.startswith("http"):
        return out, "FAILED: " + (r.stderr or r.stdout)[-200:]
    subprocess.run(["curl", "-sS", "-m", "180", "-o", out, url], check=True)
    return out, "ok"

def model(job):
    sid, body = job
    name = "knight_%s_%s" % (body, sid)
    dst = "assets/models/%s.glb" % name
    if os.path.exists(dst):
        return name, "exists"
    img = "art/concept/armor_%s_%s_v1.png" % (sid, body)
    if not os.path.exists(img):
        return name, "no concept"
    if os.path.exists("art/models/%s.json" % name) and not os.path.exists("art/models/%s.glb" % name):
        return name, "PAID BUT NOT DOWNLOADED: recover from the task ids in art/models/%s.json" % name
    if not os.path.exists("art/models/%s.glb" % name):
        if subprocess.run([sys.executable, "tools/tripo.py", img, name, "30000"], stdin=subprocess.DEVNULL).returncode != 0:
            return name, "FAILED"
    shutil.copy("art/models/%s.glb" % name, dst)
    return name, "ok"

mode = sys.argv[1]
ids = sys.argv[2:] or list(SETS)
jobs = [(s, b) for s in ids for b in ("m", "f")]
with cf.ThreadPoolExecutor(3) as ex:
    for name, status in ex.map(concept if mode == "concepts" else model, jobs):
        print(name, status, flush=True)
