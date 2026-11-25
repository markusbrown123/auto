#!/usr/bin/env python3
"""Batch concept art through the Higgsfield CLI (about 1.25 credits each).
Usage: tools/concepts.py [id ...]   — with no ids, generates every missing one.
Each prompt is an original design in the game's sleek sci-fantasy language and
is framed for image-to-3D: full body, A-pose, plain background, no weapon."""
import subprocess, sys, os, concurrent.futures as cf

FRAME = (" Full body, standing in a neutral A-pose facing the camera, arms held away from the body, legs apart, empty hands, no weapon, no cloak or cape. "
         "Even soft studio lighting, plain light grey background, whole figure in frame from head to toe, realistic materials, high detail. No text, no logos.")
STYLE = "Original character design for a sci-fantasy action game, sleek sculpted armour with smooth surfaces and clean flowing panel lines. "
C = {
 "hollow_executioner": "A hulking executioner: broad heavy build, matte black segmented armour with a smooth featureless hooded helm that hides the face, a long dark red armoured apron of overlapping plates, thick forearms, pale bone-white inlay lines.",
 "crimson_widow": "A tall slender female duelist: slim elegant crimson-lacquered armour with blade-like fins on the forearms and calves, a smooth narrow helm with a veil-shaped faceplate and two thin glowing red eye slits, a high swept collar.",
 "cathedral_beast": "A monstrous hunched guardian creature standing on two legs: enormous clawed hands hanging low, massive shoulders, a horned beast-skull head with glowing yellow eyes, body of dark hide partly covered in cracked ornate tarnished-gold ceremonial armour plates.",
 "gravewarden": "A tall gaunt armoured gravekeeper knight: weathered sea-green patinated bronze plate with smooth barnacled surfaces, a tall closed helm with a single glowing teal visor slit, a hooded mantle of metal scales over the shoulders, a glowing teal lantern-core set in the chest.",
 "frostbound_king": "A towering frozen king: sleek pale blue-silver armour sheathed in clear ice, jagged icicles on the shoulders and forearms, a tall crown of ice spikes fused to a smooth faceless helm with a glowing pale-blue visor line, frost-rimed plates.",
 "forgotten_monarch": "A tall regal undead monarch: elegant tarnished-gold and black sleek armour with long tapered plates, a hollow spiked crown fused to a smooth blank white-gold faceplate with glowing white eye slits, a long armoured skirt of narrow gold plates, gaunt proportions.",
 "pale_huntsman": "A lean pale hunter: slim bone-white and grey-green light armour, a smooth helm with tall branching antlers and glowing pale-green eye slits, long limbs, angular knee and elbow guards.",
 "devourer": "A tall emaciated soul-eating wraith creature: long thin arms ending in long claws, a ragged dark violet-black carapace, a smooth eyeless hooded head with curved horns, and a large glowing violet hollow maw ringed with teeth in the centre of its chest, tattered strips hanging from the waist.",
 "cls_humanoid": "A rank-and-file soldier: medium build, plain sleek steel-grey armour with simple smooth plates, a round open-brimmed helm with a dark visor band and two dim amber eye lights, minimal ornament.",
 "cls_heavy": "A heavy brute soldier: very broad and thick-set, bulky dull-iron armour with oversized shoulder and forearm plates, a squat flat-topped helm with a narrow amber visor slit.",
 "cls_giant": "A towering colossus soldier: enormously tall with long thick limbs and a small helm, slab-like dull-grey armour plates, heavy fists, a narrow amber visor slit.",
 "cls_twin_bladed": "A lithe agile blade-dancer: very slim build, light segmented pale-grey armour with ribbon-like trailing fins at the hips, a smooth narrow mask-like helm with two amber eye slits.",
 "cls_double_weapon": "A disciplined polearm guard: tall upright build, sleek steel armour with a long armoured tabard of narrow plates front and back, a tall crested helm with a T-shaped amber visor.",
 "cls_monstrosity": "A feral hunched beast standing on two legs: thick fur-and-hide body with scattered riveted iron plates, huge clawed hands hanging low, a snouted fanged head with small glowing amber eyes and short horns.",
 "cls_soul_eater": "A thin floating soul-eating wraith: long thin arms with clawed hands, a ragged dark shroud-like carapace, a smooth eyeless hooded head, a glowing pale-violet hollow maw ringed with teeth in its chest, legs wrapped in hanging tattered strips.",
}
def gen(cid):
    out = "art/concept/%s_v1.png" % cid
    if os.path.exists(out):
        return cid, "exists"
    r = subprocess.run(["higgsfield", "generate", "create", "gpt_image_2_6", "--prompt", STYLE + C[cid] + FRAME,
                        "--aspect_ratio", "3:4", "--resolution", "2k", "--wait", "--wait-timeout", "10m"], capture_output=True, text=True)
    url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    if not url.startswith("http"):
        return cid, "FAILED: " + (r.stderr or r.stdout)[-200:]
    subprocess.run(["curl", "-sS", "-m", "180", "-o", out, url], check=True)
    return cid, "ok"
ids = sys.argv[1:] or list(C)
with cf.ThreadPoolExecutor(4) as ex:
    for cid, status in ex.map(gen, ids):
        print(cid, status, flush=True)
