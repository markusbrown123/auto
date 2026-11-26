#!/usr/bin/env python3
"""Ground textures: one seamless, sharp, top-down paving or earth texture per region (Higgsfield image, about 1 credit),
made tileable by cross-blending its edges, with a normal map derived from its own detail.
Output: assets/textures/floor_<theme>.jpg and floor_<theme>_n.png (1024 px). Skips ones that exist.
Usage: tools/floors.py [theme ...]"""
import os, subprocess, sys
import numpy as np
from PIL import Image
FRAME = " Seamless tileable texture, photographed straight down from directly above, completely flat even overcast lighting, no cast shadows, no perspective, no horizon, no objects, fills the whole frame edge to edge, very sharp crisp detail, realistic. No text."
T = {
 "courtyard": "Worn pale grey medieval flagstone paving, large irregular fitted slabs with dark mortar joints, chipped edges, fine cracks, a little moss and grit in the joints.",
 "blackwood": "Dark forest floor: black wet earth packed with dead leaves, small roots, twigs, patches of deep green moss and a few flat buried stones.",
 "cathedral": "Scorched cathedral floor of large square dark stone tiles, cracked, dusted with grey ash and soot, faint traces of worn gold inlay lines.",
 "crypt": "Wet green-black crypt flagstones, uneven old slabs with deep joints, slick with damp, verdigris stains and thin puddles in the hollows.",
 "roost": "Black volcanic basalt ground, cracked into rough plates, coarse ash and cinders in the cracks, a few faint dull orange veins.",
 "citadel": "Frozen palace floor: pale grey-white stone slabs glazed with thin blue ice, frost crystals, hairline cracks, windblown snow in the joints.",
 "deep": "Cavern floor of dark violet-grey rock, layered and cracked, with thin seams of black glass and pale mineral veins.",
 "throne": "Royal hall floor of large polished black marble slabs with fine white and gold veining and narrow tarnished gold inlay strips between slabs, worn and dusty.",
 "sanctuary": "Old chapel floor of warm brown-grey stone flags, worn smooth in the middle, candle soot and dust in the joints.",
}
os.makedirs("assets/textures", exist_ok=True)
os.makedirs("art/floors", exist_ok=True)

def tileable(a, m=96):
    # cross-fade each edge into the opposite one so the texture repeats without a seam
    h, w, _ = a.shape
    a = a.astype(np.float32)
    ramp = np.linspace(0, 1, m)[None, :, None]
    left, right = a[:, :m].copy(), a[:, -m:].copy()
    a[:, :m] = left * ramp + right * (1 - ramp)
    a = a[:, :w - m]
    ramp = np.linspace(0, 1, m)[:, None, None]
    top, bot = a[:m].copy(), a[-m:].copy()
    a[:m] = top * ramp + bot * (1 - ramp)
    return a[:h - m]

for theme in (sys.argv[1:] or T):
    out = "assets/textures/floor_%s.jpg" % theme
    if os.path.exists(out):
        print(theme, "exists"); continue
    raw = "art/floors/%s.png" % theme
    if not os.path.exists(raw):
        r = subprocess.run(["higgsfield", "generate", "create", "gpt_image_2_6", "--prompt", T[theme] + FRAME, "--aspect_ratio", "1:1", "--resolution", "1k", "--wait", "--wait-timeout", "6m"],
                           capture_output=True, text=True, stdin=subprocess.DEVNULL)
        url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
        if not url.startswith("http"):
            print(theme, "FAILED", (r.stderr or r.stdout)[-160:]); continue
        subprocess.run(["curl", "-sS", "-m", "180", "-o", raw, url], check=True)
    a = tileable(np.asarray(Image.open(raw).convert("RGB")))
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).resize((1024, 1024), Image.LANCZOS)
    img.save(out, quality=92)
    # normal map from luminance (wrapping Sobel so it tiles too)
    g = np.asarray(img.convert("L")).astype(np.float32) / 255.0
    dx = (np.roll(g, -1, 1) - np.roll(g, 1, 1)) * 3.0
    dy = (np.roll(g, -1, 0) - np.roll(g, 1, 0)) * 3.0
    n = np.dstack([-dx, -dy, np.ones_like(g)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save("assets/textures/floor_%s_n.png" % theme)
    print(theme, "ok", flush=True)
