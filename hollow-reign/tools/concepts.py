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
# ---- the Blackwood kit (ids are prefixed bw_, files become env_bw_*)
BSTYLE = "Environment set piece for a sci-fantasy action game: an ancient black-barked forest swallowing old ruins, dark wet bark, deep green moss, pale fungus, subtle hints of forgotten advanced technology. "
B = {
 "env_bw_giant_tree": "A colossal ancient tree: an enormously thick twisted black trunk with huge buttress roots and a few heavy bare lower branches, moss on the roots.",
 "env_bw_tree": "A tall dead black tree with a straight scarred trunk and a crown of crooked leafless branches, moss at its base.",
 "env_bw_root_arch": "A natural archway formed by two enormous black tree roots meeting overhead, hung with moss and pale hanging lichen.",
 "env_bw_shrine": "A small ruined forest shrine of dark mossy stone: three broken pillars and a cracked lintel around a low altar, overgrown with roots and ferns.",
 "env_bw_lantern": "A tall crooked iron lantern post wound with dead vines, an old glass lantern hanging from its hook glowing pale yellow-green.",
 "env_bw_block": "A wide tree stump used as an executioner's block, its top scarred with deep axe cuts, an iron ring bolted to its side, dark stains.",
 "env_bw_gibbet": "A dead leaning tree with an iron gibbet cage hanging from one branch on a chain, the cage empty and rusted.",
 "env_bw_log": "A huge fallen tree trunk lying on its side, hollow at one end, covered in thick moss, shelf fungus and ferns.",
 "env_bw_stone": "A tall leaning standing stone of black rock carved with worn lines, a crack down its face showing smooth dark metal and thin glowing green circuit lines inside.",
 "env_bw_cart": "An abandoned broken wooden cart with one wheel missing, sunk into the ground, covered in moss, with a rusted iron-bound chest in its bed.",
 "env_bw_boulder": "A large rounded mossy boulder with ferns and small pale mushrooms growing around its base.",
 "env_bw_hut": "A small ruined charcoal burner's hut: sagging dark timber walls, a collapsed mossy thatch roof, a crooked stone chimney.",
}
C.update(B)
# ---- kits for the other six regions: {prefix: (style, {id: description})}; files become env_<prefix>_*
KITS = {
 "ca": ("Environment set piece for a sci-fantasy action game: a vast burned cathedral, soot-black stone, grey ash drifts, cracked gold leaf, faint embers, sleek forgotten machinery beneath the masonry. ", {
  "pillar": "A towering clustered gothic cathedral pillar of soot-black stone, its base buried in grey ash, cracked gold bands near the top.",
  "altar": "A broad stone high altar scorched black, covered in melted candle stubs and ash, a cracked golden sun disc mounted behind it.",
  "window": "A tall free-standing gothic lancet window frame of blackened stone holding shattered stained glass in amber and deep red.",
  "pew": "A row of heavy carved wooden church pews, charred and half collapsed, dusted with ash.",
  "censer": "A huge ornate bronze censer on a tall iron stand with hanging chains, thin smoke and a dull orange glow inside.",
  "bell": "A giant fallen bronze church bell lying tilted and cracked on broken flagstones, half buried in ash.",
  "statue": "A tall robed stone saint statue with a smooth featureless mask for a face and hands folded, scorched, one arm broken off."}),
 "cr": ("Environment set piece for a sci-fantasy action game: a flooded ancient crypt, wet green-black stone, pale blue corpse-light, verdigris bronze, still dark water, sleek forgotten machinery in the walls. ", {
  "sarcophagus": "A massive stone sarcophagus with a smooth armoured knight effigy carved on the lid, green with damp, a thin pale blue glow leaking from the seam.",
  "arch": "A heavy low crypt archway of wet black stone blocks with a carved keystone, dripping moss.",
  "urns": "A cluster of tall cracked funeral urns of dark glazed clay with verdigris bronze lids, one toppled.",
  "candelabra": "A tall wrought-iron standing candelabra with many arms and pale blue flames, wax dripping down it.",
  "coffins": "A stack of rotting wooden coffins bound with rusted iron bands, one lid ajar.",
  "pillar": "A squat thick crypt pillar of wet stone with niches holding small skull-shaped lamps glowing pale blue.",
  "gate": "A tall rusted iron portcullis gate set in a stone frame, half raised, hung with chains."}),
 "ro": ("Environment set piece for a sci-fantasy action game: a volcanic mountain eyrie where dragons nest, black basalt, glowing orange lava cracks, scorched bone, sleek ancient metal fused into the rock. ", {
  "spire": "A tall jagged black basalt rock spire with glowing orange lava cracks running up it.",
  "ribs": "An enormous dragon ribcage half buried in ash, scorched black bone arcs rising high.",
  "skull": "A colossal horned dragon skull resting on black rock, jaw open, scorched and cracked.",
  "nest": "A huge nest built of charred tree trunks, bones and fused slag, with three large dark scaled eggs glowing faintly orange.",
  "arch": "A natural basalt rock arch with hexagonal columns, lava glow beneath it.",
  "brazier": "A giant ancient iron fire bowl on three clawed legs, filled with glowing coals.",
  "wreck": "The wreck of a sleek ancient metal war machine half melted into black rock, panels peeled open, faint orange light inside."}),
 "ci": ("Environment set piece for a sci-fantasy action game: a frozen royal citadel, pale blue ice over white stone, frost, silver metal, cold cyan light from forgotten machinery. ", {
  "pillar": "A tall fluted palace pillar of white stone sheathed in thick blue ice with long icicles.",
  "throne": "A high-backed royal stone throne encased in clear ice, frost flowers growing over it.",
  "statue": "A tall statue of an armoured king in sleek plate, frozen over, sword point resting on the ground, icicles hanging from the arms.",
  "brazier": "A tall silver brazier on a slender stand burning with a cold blue flame, rimmed with frost.",
  "gate": "A grand double doorway of silver-banded pale wood frozen half open, snow drifted against it.",
  "wall": "A section of white stone battlement wall with crenellations, crusted in ice and snow.",
  "shard": "A cluster of huge jagged blue ice crystals erupting from cracked flagstones, a cyan glow deep inside."}),
 "de": ("Environment set piece for a sci-fantasy action game: a bottomless cavern beneath the world, dark violet rock, pale bioluminescent fungus, black glass, exposed colossal ancient machinery with dim violet light. ", {
  "pillar": "A colossal cracked support column of dark metal and stone with dim violet light lines, cables hanging from it.",
  "fungus": "A cluster of tall pale bioluminescent mushrooms with wide caps glowing soft blue-violet, growing from dark rock.",
  "conduit": "A huge broken ancient machine conduit, a ribbed dark metal pipe as thick as a tree, torn open and leaking violet light.",
  "crystal": "A cluster of black glass crystal shards with violet light pulsing inside, jutting from the ground.",
  "husk": "A kneeling hollow suit of sleek ancient armour fused to the rock, empty, overgrown with pale fungus.",
  "bridge": "A short broken span of an ancient dark metal walkway with railings, ending in twisted torn beams.",
  "rock": "A large jagged dark violet boulder veined with thin glowing lines."}),
 "th": ("Environment set piece for a sci-fantasy action game: the last throne hall of a dead empire, black marble, tarnished gold, deep crimson, a great crown-machine of sleek dark metal with white-gold light. ", {
  "pillar": "A tall square black marble pillar with tarnished gold capital and a thin white-gold light line running up each face.",
  "throne": "A towering throne of black metal and gold with a huge ring-shaped machine halo rising behind it, glowing white-gold.",
  "banner": "A very tall hanging royal banner of faded crimson cloth on a gold pole stand, embroidered with a simple crown ring emblem, torn at the bottom.",
  "statue": "A tall statue of a crowned monarch in sleek armour, black marble with gold inlay, head bowed, hands resting on a sword.",
  "brazier": "A wide gold fire bowl on a black marble pedestal burning with a white-gold flame.",
  "stairs": "A broad short flight of black marble steps with gold edging and low balustrades.",
  "ring": "A giant fallen ring-shaped machine part of dark metal with gold filigree, lying tilted on cracked marble, faint white-gold light in its channels."}),
}
KIT_OF = {}
for _pre, (_style, _items) in KITS.items():
    for _k, _v in _items.items():
        C["env_%s_%s" % (_pre, _k)] = _v
        B["env_%s_%s" % (_pre, _k)] = _v       # same framing and size as the Blackwood kit
        KIT_OF["env_%s_%s" % (_pre, _k)] = _style

# ---- dragons: framed for a four-legged rig (all four feet down, wings folded back clear of the legs, neck and tail straight)
DFRAME = (" The whole creature standing square on all four legs in a neutral pose, seen from the side and slightly in front, head level and looking forward, mouth closed, "
          "neck stretched forward, tail held straight out behind, wings half folded and swept back above the body so the legs are clearly separate. "
          "Even soft studio lighting, plain light grey background, entire creature in frame, realistic materials, high detail. No text, no logos, no rider.")
DSTYLE = "Original creature design for a sci-fantasy action game: an engineered war dragon, sleek and powerful, part living animal and part ancient machine. "
D = {
 "dragon_veyrath": "A siege dragon with dark red and charcoal scales, heavy armoured forequarters, a blunt horned battering head, glowing orange seams between the scales as if lit from inside, scorched wing membranes.",
 "dragon_skeldra": "A lean pale dragon with white and ice-blue scales rimed with frost, a long narrow head with swept-back horns, a broken length of heavy chain on an iron collar round its neck, torn translucent wing membranes, cold cyan eyes.",
 "dragon_azhurion": "The oldest of them: a huge dragon more machine than animal, dark gunmetal armour plates bolted over black hide, tarnished gold filigree, exposed mechanical joints, wing frames of metal spars with dark membrane, white-gold light in its eyes and chest.",
}
C.update(D)

def gen(cid):
    out = "art/concept/%s_v1.png" % cid
    if os.path.exists(out):
        return cid, "exists"
    prompt = (DSTYLE + C[cid] + DFRAME) if cid in D else (WSTYLE + C[cid] + WFRAME) if cid in W else ((ESTYLE + C[cid] + EFRAME) if cid in E else ((KIT_OF.get(cid, BSTYLE) + C[cid] + EFRAME) if cid in B else (STYLE + C[cid] + FRAME)))
    r = subprocess.run(["higgsfield", "generate", "create", "gpt_image_2_6", "--prompt", prompt,
                        "--aspect_ratio", "16:9" if cid in D else "9:16" if cid in W and not cid.startswith("s_") else ("1:1" if (cid in E or cid in B) else "3:4"),
                        "--resolution", "1k" if (cid in W or cid in E or cid in B) else "2k", "--wait", "--wait-timeout", "10m"], capture_output=True, text=True, stdin=subprocess.DEVNULL)
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
if ids == ["blackwood"]:
    ids = [i for i in B if i.startswith("env_bw_")]
if ids == ["kits"]:
    ids = list(KIT_OF)
with cf.ThreadPoolExecutor(4) as ex:
    for cid, status in ex.map(gen, ids):
        print(cid, status, flush=True)
