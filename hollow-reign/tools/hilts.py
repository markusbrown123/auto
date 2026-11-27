#!/usr/bin/env python3
"""Sculpted hilts for the hybrid swords: one concept image and one prop model per sword (about 1.25 image credits + 30 Tripo credits).
Resumable: never regenerates a concept or a model that exists (art/models/<name>.json holds the paid task id).
Usage: tools/hilts.py [sword ...]"""
import os, subprocess, sys
H = {
 "silver_vow": "a small open lens-shaped frame guard with two pierced leaf-shaped windows, a very slender grip, a faceted bead pommel",
 "ashbrand": "a broad blocky anvil-like guard with stepped shoulders and two rectangular windows, a tall fluted collar, a longer grip, a heavy slotted block pommel",
 "veilcutter": "an asymmetric guard: one short arm leaning forward and one long arm sweeping back past the knuckles as a smooth open ribbon with a rounded end, a slim grip, a small tapered pommel",
 "oathbreaker": "a wide tiered architectural guard with windows and slots, a tall clamp rising where the blade would start, a long two-handed grip with a centre ring, a keystone-shaped pommel",
 "kings_remnant": "a guard whose upper edge is a row of small squared merlons like a broken crown above a long pierced window, antique gold inlay, a disc pommel pierced by a square",
 "cold_resolve": "an open hexagonal collar guard with a faceted window each side, pale steel with one hair-thin pale-blue light line, a four-sided crystal-like faceted pommel",
 "nightward": "a half-disc guard on one side only, pierced by three graduated round ports, blackened graphite steel with a thin bright edge, a flat tab pommel with a lanyard eye",
 "twin_relics": "an angular C-shaped frame guard that returns to the pommel as a knuckle bar, a short grip, a hexagonal cap pommel",
}
BASE = ("Game prop on a plain light grey background, whole object in frame, front view, upright: the HILT ONLY of an elegant futuristic sword, no blade "
        "(the blade is cut off flat just above the guard): %s. Sculpted in the round with smooth flowing surfaces, satin brushed steel, tiny antique-gold inlays, "
        "grip wrapped in tight black cord with thin steel rings, jewellery-like precision, original science-fantasy design, rounded ends, no sharp spikes or hooks, "
        "no skulls, realistic materials, sharp detail. No text.")
for name in (sys.argv[1:] or H):
    img = "art/concept/hilt_%s_v1.png" % name
    if not os.path.exists(img):
        r = subprocess.run(["higgsfield", "generate", "create", "gpt_image_2_6", "--prompt", BASE % H[name], "--aspect_ratio", "1:1", "--resolution", "2k", "--wait", "--wait-timeout", "10m"],
                           capture_output=True, text=True, stdin=subprocess.DEVNULL)
        url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
        if not url.startswith("http"):
            print(name, "concept FAILED", (r.stderr or r.stdout)[-200:], flush=True); continue
        subprocess.run(["curl", "-sS", "-m", "180", "-o", img, url], check=True)
    if os.path.exists("art/models/hilt_%s.json" % name) or os.path.exists("art/models/hilt_%s.glb" % name):
        print(name, "model exists", flush=True)
    else:
        subprocess.run([sys.executable, "tools/tripo.py", "prop", img, "hilt_" + name, "5000"], stdin=subprocess.DEVNULL)
    if os.path.exists("art/models/hilt_%s.glb" % name):
        os.makedirs("assets/models/gear/hilts", exist_ok=True)
        subprocess.run(["cp", "art/models/hilt_%s.glb" % name, "assets/models/gear/hilts/"])
        print(name, "ok", flush=True)
