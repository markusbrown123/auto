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
# ---- weapons and shields: one object, upright, isolated, so image-to-3D gets a clean read
WFRAME = (" A single object only, shown upright and vertical, perfectly centred, straight-on front view, isolated on a plain light grey background, "
          "no hands, no character, no stand, no scabbard, even soft studio lighting, realistic materials, high detail. No text, no logos.")
WSTYLE = "Original weapon design for a sci-fantasy action game, sleek futuristic-medieval style with smooth sculpted metal surfaces and clean flowing panel lines. "
SW = "A one-handed sword, blade pointing up, hilt at the bottom: "
GS = "A huge two-handed greatsword, blade pointing up, long grip at the bottom: "
AX = "A one-handed battle axe, axe head at the top, haft pointing down: "
DB = "A single short curved blade for dual wielding, blade pointing up, grip at the bottom: "
SH = "A knight's shield seen from the front: "
W = {
 "w_rusted_sword": SW + "plain and worn, straight narrow brushed-steel blade with a single shallow fuller, simple straight crossguard, wrapped dark grip, small round pommel, a few nicks.",
 "w_knight_sword": SW + "clean military issue, polished steel blade with a crisp central ridge, swept angular crossguard, dark grip with steel bands.",
 "w_dawnline": SW + "elegant slim silver blade with a long bevel and a thin gold line down the centre, winged crossguard, white grip.",
 "w_vigil_edge": SW + "broad leaf-shaped steel blade with layered plate-like fullers, a guard shaped like folded wings, dark blue grip, faceted pommel.",
 "w_censer_sword": SW + "bronze-gold blade with a perforated channel glowing ember-orange from within, flared guard, soot-darkened edges.",
 "w_rime_sword": SW + "curved sabre of pale blue translucent glass-like alloy with frost crystals along the spine, silver knuckle guard, faint icy glow.",
 "w_starfall": SW + "long dark meteoric-alloy blade split by a glowing white-blue seam down its length, asymmetric swept guard, sleek black grip, star-shaped pommel.",
 "w_monarch": SW + "the final king's sword: long regal blade of tarnished gold and black steel with a glowing white-gold core, ornate crown-shaped crossguard with thin spikes, black grip wound in gold wire.",
 "w_ashen_great": GS + "massive slab of scorched blackened iron with glowing ember-orange cracks, thick blunt edges, heavy straight guard, long charred grip.",
 "w_crypt_great": GS + "long corroded sea-green bronze zweihander with barnacle pitting, a second small parrying guard above the main crossguard, teal patina.",
 "w_throneshard": GS + "a jagged shard of polished black stone veined with gold, shaped into a blade, set in a gold collar and a long black grip.",
 "w_frost_great": GS + "enormous pale blue-silver blade sheathed in clear ice with icicles hanging from the guard, glowing cold blue core, crystalline pommel.",
 "w_wyrmfang": GS + "a giant curved ivory dragon fang as the blade, mounted in dark red scaled metal with a claw-shaped guard, faint ember glow at the root.",
 "w_woodcutter": AX + "simple bearded steel axe head with a clean curved edge, dark wooden haft with steel langets.",
 "w_headsman": AX + "very broad heavy matte-black crescent blade with a pale bone-white edge line, thick dark haft bound in dark red cord.",
 "w_oath_axe": AX + "double-bitted black alloy axe with swept wing-like blades and glowing deep red seams, spike on top, sleek black haft.",
 "w_pilgrim_blades": DB + "plain slim steel knife-sword with a slight curve, simple disc guard, cord-wrapped grip.",
 "w_twin_fangs": DB + "elegant crimson-lacquered blade curved like a fang with a mirror-bright edge, small swept guard, red silk-wrapped grip.",
 "w_ember_fangs": DB + "dark smoked-steel blade with a glowing molten orange edge, serrated spine, black grip.",
 "w_hunger": DB + "thin hooked blade of dark violet-black metal with a glowing violet inner edge, organic bone-like guard.",
 "w_glaive": "A double-ended polearm, shown vertical: a long dark haft with a slim leaf-shaped steel blade at each end, steel collars, sleek and symmetrical.",
 "s_plank": SH + "small plain heater shield of dented steel-blue painted metal with a scratched surface and a simple rim.",
 "s_garrison": SH + "kite shield in polished steel with a dark red enamel field and a raised central ridge, clean angular rim.",
 "s_tower": SH + "tall heavy tower shield of scorched blackened iron with glowing ember-orange seams and layered plates.",
 "s_reliquary": SH + "ornate tarnished-gold shield shaped like a cathedral door with a pointed arch top, relief panels, a round glass reliquary at its centre.",
 "s_rime": SH + "angular shield of pale blue-silver alloy sheathed in clear ice with frost crystals on the rim and a glowing cold blue centre line.",
 "s_scale": SH + "rounded shield made from one huge dark red dragon scale with a ridged surface, rimmed in dark metal.",
}
C.update(W)
# ---- scenery: one set piece each, isolated, for the Fallen Courtyard kit
EFRAME = (" A single isolated object, complete and fully visible, three-quarter front view, standing on nothing, plain light grey background, "
          "soft even daylight, realistic weathered materials, high detail, game environment asset. No people, no text, no logos.")
ESTYLE = "Environment set piece for a sci-fantasy action game: an ancient mountain fortress in ruin, pale weathered limestone, moss and ivy, subtle hints of forgotten advanced technology. "
E = {
 "env_wall": "A long straight section of ruined fortress curtain wall with crenellations, one end collapsed into a jagged breach, ivy climbing it.",
 "env_gate": "A massive ruined fortress gatehouse: a tall pointed stone archway flanked by two square buttress towers, a bent iron portcullis half raised, thin lines of faint blue light in the seams of the arch.",
 "env_statue": "A colossal broken statue of an armoured king in sleek stylised plate, standing on a square plinth, the head and one arm missing, cracked and overgrown with moss.",
 "env_statue_head": "The fallen head of a colossal stone statue lying on its side: a smooth stylised crowned helm with a blank faceplate, cracked, half covered in moss.",
 "env_tower": "A tall round ruined fortress tower with a broken open top, narrow arrow slits, part of a wooden hoarding still clinging on, ivy up one side.",
 "env_pillar": "A thick broken stone column on a square base, snapped two thirds of the way up, its fallen top section lying beside it, moss in the cracks.",
 "env_rubble": "A low heap of large fallen limestone blocks and broken masonry with grass and small ferns growing between the stones.",
 "env_tree": "An old gnarled leafless tree with a twisted thick trunk and spreading bare branches, pale bark, exposed roots gripping broken paving stones.",
 "env_brazier": "A tall sleek wrought-iron brazier on three slender legs with a wide shallow bowl holding glowing coals and a small flame.",
 "env_banner": "A tall iron banner pole on a stone base with a long tattered faded crimson banner bearing a simple crown emblem, torn and sun-bleached.",
 "env_obelisk": "A half-buried ancient machine disguised as a stone obelisk: a tall four-sided pale stone pillar split open at one corner to reveal smooth dark metal and thin glowing blue circuit lines inside.",
 "env_peak": "A single huge jagged rocky mountain peak with sheer grey cliffs and patches of snow near the summit, sparse pine trees at its base.",
 "env_chest": "An ornate closed treasure chest of dark wood with sleek silver metal banding and a glowing blue seam under the lid.",
}
C.update(E)

def gen(cid):
    out = "art/concept/%s_v1.png" % cid
    if os.path.exists(out):
        return cid, "exists"
    prompt = (WSTYLE + C[cid] + WFRAME) if cid in W else ((ESTYLE + C[cid] + EFRAME) if cid in E else (STYLE + C[cid] + FRAME))
    r = subprocess.run(["higgsfield", "generate", "create", "gpt_image_2_6", "--prompt", prompt,
                        "--aspect_ratio", "9:16" if cid in W and not cid.startswith("s_") else ("1:1" if cid in E else "3:4"),
                        "--resolution", "1k" if (cid in W or cid in E) else "2k", "--wait", "--wait-timeout", "10m"], capture_output=True, text=True, stdin=subprocess.DEVNULL)
    url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    if not url.startswith("http"):
        return cid, "FAILED: " + (r.stderr or r.stdout)[-200:]
    subprocess.run(["curl", "-sS", "-m", "180", "-o", out, url], check=True)
    return cid, "ok"
ids = sys.argv[1:] or list(C)
if ids == ["weapons"]:
    ids = list(W)
if ids == ["env"]:
    ids = list(E)
with cf.ThreadPoolExecutor(4) as ex:
    for cid, status in ex.map(gen, ids):
        print(cid, status, flush=True)
