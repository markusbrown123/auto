#!/usr/bin/env python3
"""Authoring script for data/regions.json. Each road is seven stops:
a first blood, a fork, a second foe type, a shortcut mechanism, an elite or
an optional hunt, a breath, and the guardian."""
import json
def fight(label, hint, foe): return dict(type="fight", label=label, hint=hint, foe=foe)
def boss(label, hint, foe, optional=False): return dict(type="boss", label=label, hint=hint, foe=foe, optional=optional)
def chest(label, hint, items, gold=0, shards=0, **k): return dict(type="treasure", label=label, hint=hint, items=items, gold=gold, shards=shards, **k)
def shrine(label, hint): return dict(type="shrine", label=label, hint=hint)
def lever(label, hint, flag): return dict(type="lever", label=label, hint=hint, flag=flag)
def st(prompt, *opts, pouches=1): return dict(prompt=prompt, options=list(opts), pouches=pouches)
R = [
 dict(id="courtyard", name="The Fallen Courtyard", theme="courtyard", amb="wind", requires=None,
  blurb="The gate of a fortress nobody has garrisoned in centuries. Morning still comes here. Nothing else does.",
  shortcut=dict(flag="courtyard_gate", stage=4, label="The Winch Gate"),
  stages=[
   st("The outer wall has fallen in on itself. Something in garrison plate still walks its rounds.",
      fight("The Breach", "Steel scrapes on stone ahead.", "hollow_soldier")),
   st("Beyond the rubble the path divides.",
      chest("The Guardhouse", "A door hangs from one hinge.", ["a_garrison_gauntlets"], gold=60, shards=1),
      fight("The Rampart Stair", "A longer way, and watched.", "hollow_soldier")),
   st("A banner still flies on the barbican. Someone is standing under it, at attention.",
      fight("The Barbican", "Light on his feet. He salutes first.", "banneret")),
   st("A winch-house stands beside the inner gate. Its chain is rusted but whole.",
      lever("Turn the Winch", "The gate would stay open behind you.", "courtyard_gate"),
      chest("The Well", "Something glints below the waterline.", ["r_iron"], gold=40, shards=1, needs="courtyard_gate")),
   st("The gate passage. It is narrow, and it is occupied.",
      fight("The Gate Passage", "He fills it wall to wall.", "rampart_brute"),
      chest("The Murder Hole", "A ladder up, behind a loose stone.", ["a_garrison_helm"], gold=80, shards=1)),
   st("A chapel alcove survives against the keep wall. A single candle burns.",
      shrine("Kneel", "Rest a moment. Wounds close.")),
   st("The inner ward. He is standing exactly where he was posted.",
      boss("The Inner Ward", "Embers drift from the gatehouse.", "ashen_sentinel")),
  ]),
 dict(id="blackwood", name="The Blackwood", theme="blackwood", amb="wind", requires="courtyard",
  blurb="The royal hunting forest. The trees grew in over the road, and over the hunters.",
  shortcut=dict(flag="blackwood_bridge", stage=4, label="The Rope Bridge"),
  stages=[
   st("The road gives out under roots. Lanterns hang in the branches, still lit.",
      fight("The Lantern Road", "Someone is keeping them lit.", "blackwood_stalker")),
   st("A deer trail leaves the road. The road goes on.",
      fight("The Road", "Hoofprints, then bootprints.", "blackwood_stalker"),
      boss("The Deer Trail", "White antlers move between the trunks.", "pale_huntsman", optional=True)),
   st("Briars have been woven across the way. Not by the wind.",
      fight("The Briar Gate", "Two blades part the thorns from inside.", "thornblade"),
      chest("The Hollow Oak", "Wide enough to hide a man. Or his things.", ["a_black_gauntlets"], gold=110, shards=2)),
   st("A ravine. A bridge of rope lies coiled on your side of it.",
      lever("Cast the Bridge", "It will hold. It will also remain.", "blackwood_bridge"),
      chest("The Charcoal Burner's Hut", "The door is barred from outside.", ["w_woodcutter"], gold=90, shards=2)),
   st("The trees here have been cut and stacked, very neatly, for a very long time.",
      fight("The Woodpile", "The woodcutter is still at work.", "woodward")),
   st("A gibbet tree, and beneath it a spring.",
      shrine("Drink", "The water is cold and clean."),
      chest("Under the Gibbet", "The hanged have dropped their purses.", ["a_black_legs"], gold=140, shards=2, needs="blackwood_bridge")),
   st("A clearing of stumps. Every one has been used as a block.",
      boss("The Clearing", "A cleaver drags somewhere in the dark.", "hollow_executioner")),
  ]),
 dict(id="cathedral", name="The Cathedral of Ash", theme="cathedral", amb="fire", requires="blackwood",
  blurb="A cathedral raised over a research works. Someone burned it to keep what was underneath. It is still burning.",
  shortcut=dict(flag="cathedral_door", stage=4, label="The Sacristy Door"),
  stages=[
   st("Pilgrims' steps, worn into bowls. Ash falls like first snow.",
      fight("The Pilgrim Stair", "Robed figures turn toward you.", "ash_acolyte")),
   st("A censer the size of a bell swings across the porch, and a knight swings it.",
      fight("The Porch", "Slow. Do not mistake that for safe.", "censer_knight"),
      chest("The Almoner's Box", "Chained to the wall. The chain is ash.", ["x_candle"], gold=150, shards=2)),
   st("At the great doors, a woman in red is waiting. She has been waiting a long time.",
      boss("The Cathedral Steps", "Two blades. No hesitation.", "crimson_widow")),
   st("Inside, the nave is open to the sky. A side door leads to the sacristy.",
      lever("Unbar the Sacristy", "A way in that avoids the steps.", "cathedral_door"),
      chest("The Reliquary", "Saints' bones, and what was buried with them.", ["a_vigil_gauntlets"], gold=160, shards=3)),
   st("The choir is still singing. There is nothing left of them to sing with.",
      fight("The Choir Loft", "It reaches for you with the hymn.", "choir_wraith")),
   st("Votive candles, hundreds, none burned down.",
      shrine("Light One", "Warmth without smoke.")),
   st("The bell tower has fallen through the crossing. Something has made its den in the bronze.",
      boss("The Crossing", "The bell tolls by itself.", "cathedral_beast")),
  ]),
 dict(id="crypt", name="The Sunken Crypt", theme="crypt", amb="crypt", requires="cathedral",
  blurb="Not a burial place. The minds the Crown stored were kept here, and then the river was let in.",
  shortcut=dict(flag="crypt_sluice", stage=4, label="The Sluice Gate"),
  stages=[
   st("Stairs descend into black water. Lamps burn beneath its surface.",
      fight("The Drowned Stair", "A squire, still carrying his lord's shield.", "drowned_squire")),
   st("The ossuary. Skulls are stacked to the vault.",
      chest("The Ossuary", "One niche is sealed with newer mortar.", ["a_vigil_legs"], gold=200, shards=3),
      fight("The Processional", "Heavy footfalls in the water.", "crypt_warden")),
   st("Something pale is pressed against a tomb lid, drinking what seeps out.",
      fight("The Weeping Tomb", "It turns. It is not finished.", "tomb_leech")),
   st("A sluice wheel. Turning it would drain the lower halls.",
      lever("Open the Sluice", "The water would not come back.", "crypt_sluice"),
      shrine("The Dry Niche", "A saint's alcove above the waterline.")),
   st("With the water gone, a lower door stands revealed.",
      chest("The Royal Vault", "Sealed since before the flood.", ["a_vigil_helm"], gold=300, shards=4, needs="crypt_sluice"),
      fight("The Gallery of Kings", "Their effigies have been defaced.", "crypt_warden")),
   st("A reliquary lamp, lit, in a room with no door but the one you came by.",
      shrine("Sit by the Lamp", "It asks nothing.")),
   st("The oldest tomb. Its keeper has not left his post.",
      boss("The First Tomb", "A lantern, held very still.", "gravewarden")),
  ]),
 dict(id="roost", name="The Wyrm's Roost", theme="roost", amb="wind", requires="crypt", optional=True,
  blurb="A volcanic fortress. Under it they kept a thing built to break sieges, and never told it the wars were over.",
  shortcut=dict(flag="roost_chain", stage=4, label="The Feeding Chain"),
  stages=[
   st("The cliff road. The stone is glazed, as if it ran once.",
      fight("The Glass Road", "A knight in scale. Not his own.", "scalebound")),
   st("The falconry, roofless. The perches are man-height.",
      fight("The Mews", "He whistles. Nothing comes. He draws instead.", "ash_falconer"),
      chest("The Tack Room", "Harness for something with a long neck.", ["a_wyrm_gauntlets"], gold=340, shards=4)),
   st("Bones, heaped. Among them something small is learning to hunt.",
      fight("The Boneyard", "Small for a dragon. Not small.", "cinder_whelp")),
   st("A chain as thick as a tree runs down the cliff to the valley, with a cage on it.",
      lever("Free the Counterweight", "The cage would ride up and down at your word.", "roost_chain"),
      chest("The Keeper's Cell", "He locked himself in. It did not help.", ["a_wyrm_legs"], gold=300, shards=4)),
   st("The egg chamber. The shells are old. One is not.",
      chest("The Clutch", "Warm ash, and something under it.", ["r_brood"], gold=420, shards=5, needs="roost_chain"),
      fight("The Brood Guard", "Two knights swore to guard the clutch. One is left.", "scalebound")),
   st("A spring runs hot from the rock. Someone cut a basin for it.",
      shrine("Bathe Your Hands", "Heat without harm.")),
   st("The summit. The sky is very large here, and part of it is looking at you.",
      boss("The Summit", "A shadow crosses the sun, and comes back.", "cinder_wyrm")),
  ]),
 dict(id="citadel", name="The Frozen Citadel", theme="citadel", amb="wind", requires="crypt",
  blurb="The mountain fortress. Its king had the gates frozen shut, and himself with them.",
  shortcut=dict(flag="citadel_lift", stage=4, label="The Ice Lift"),
  stages=[
   st("The pass. Soldiers stand in ranks along it, upright, rimed white.",
      fight("The Frozen Rank", "One of them is breathing.", "frost_thrall")),
   st("The curtain wall, sheathed in ice.",
      fight("The Wall Walk", "A duellist practises alone, as he has for an age.", "rime_duelist"),
      chest("The Armoury", "The racks are frozen solid.", ["a_frost_gauntlets"], gold=320, shards=4)),
   st("Below the keep, a pit. A chain runs down into it, and the chain is moving.",
      fight("The Kennel Stair", "A thrall bars the way down.", "frost_thrall"),
      boss("The Pit", "Whatever is on the chain has heard you.", "rimewyrm", optional=True)),
   st("A counterweight lift, iced into its shaft.",
      lever("Break the Ice", "It would run from the pass to the keep.", "citadel_lift"),
      shrine("The Brazier", "Someone kept one fire alive.")),
   st("The great stair. Halfway up it, a shape that was part of the wall steps out.",
      fight("The Great Stair", "The air itself resists you.", "glacier_brute")),
   st("The queen's solar. Frost flowers cover every pane.",
      chest("The Solar", "A jewel case, frozen shut.", ["r_frost", "a_frost_helm"], gold=400, shards=5, needs="citadel_lift"),
      shrine("The Window Seat", "The view is all white. It is restful.")),
   st("The hall of the winter throne.",
      boss("The Winter Throne", "He has not moved in an age. He moves now.", "frostbound_king")),
  ]),
 dict(id="deep", name="The Hollow Deep", theme="deep", amb="crypt", requires="citadel", optional=True,
  blurb="Under the throne is where the Crown sent what it had no use for. All of it is still down there, together.",
  shortcut=dict(flag="deep_stair", stage=4, label="The Unlit Stair"),
  stages=[
   st("The stair goes down past where stairs should stop. People stand along it, facing the wall.",
      fight("The Long Stair", "One turns. There is no one in it.", "husk")),
   st("A gallery of names, carved floor to roof. Most have been licked smooth.",
      fight("The Gallery of Names", "It is eating one now. It looks up.", "soul_eater"),
      chest("The Unread Wall", "A few names survive. Something was hidden behind them.", ["a_hollow_gauntlets"], gold=520, shards=6)),
   st("The dark here has a grain to it, like wood. Like something growing.",
      fight("The Grain", "It comes apart from the dark as it moves.", "soul_eater")),
   st("A second stair, unlit, climbing. It smells of candle smoke — the sanctuary's.",
      lever("Mark the Way", "You could find this from above.", "deep_stair"),
      shrine("The Last Candle", "Someone carried it this far.")),
   st("A hall where oaths were sworn. The banners hang empty; the words are gone out of them.",
      fight("The Oath Hall", "It has eaten promises. It is very strong.", "oath_eater"),
      chest("The Reliquary of Vows", "One vow, kept, in a lead box.", ["a_hollow_legs", "a_hollow_helm"], gold=600, shards=7, needs="deep_stair")),
   st("Stillness. A place it has already emptied, and so does not visit.",
      shrine("Rest in the Emptied Place", "Nothing here wants anything.")),
   st("The bottom. It is not dark. It is occupied.",
      boss("The Bottom", "It says a name. It might be yours.", "devourer")),
  ]),
 dict(id="throne", name="The Hollow Throne", theme="throne", amb="wind", requires="citadel",
  blurb="The last hall, and the machine at the end of it. Somebody stayed to keep it running.",
  shortcut=dict(flag="throne_door", stage=4, label="The King's Door"),
  stages=[
   st("The royal mile. Statues of every monarch, each with the face struck off.",
      fight("The Royal Mile", "The honour guard still stands.", "throne_guard")),
   st("The antechamber, hung with banners gone to thread.",
      fight("The Antechamber", "The king's own blade. He bows.", "kingsblade"),
      chest("The Treasury", "Open. Unguarded. Nearly empty.", ["a_regal_gauntlets", "a_regal_legs"], gold=600, shards=6)),
   st("A figure sits on the steps with a crown in its lap, turning it over and over.",
      fight("The Steps", "It was a king. It has forgotten which.", "crownless")),
   st("A small door behind the arras, for the king's private use.",
      lever("Unlock the King's Door", "Kings do not use the front.", "throne_door"),
      shrine("The Chapel Royal", "The last quiet place.")),
   st("The last guard. He has not been relieved. He does not expect to be.",
      fight("The Last Post", "He raises his sword like a man lifting a door.", "throne_guard"),
      chest("Behind the Throne", "Where a king hides what matters.", ["x_heart"], gold=800, shards=8, needs="throne_door")),
   st("The throne room doors. They are open. They have always been open.",
      shrine("Steady Yourself", "Breathe."),
      boss("The Roof of the Hall", "Something vast is folded up among the rafters. It has been listening.", "azhurion", optional=True)),
   st("The Hollow Throne.",
      boss("The Hollow Throne", "The crown turns toward you.", "forgotten_monarch")),
  ]),
]
# Some stops draw their foe from a pool, so a road is not the same twice.
POOLS = {
 "The Rampart Stair": ["hollow_soldier", "pike_sergeant"], "The Gate Passage": ["rampart_brute", "gate_colossus"],
 "The Road": ["blackwood_stalker", "veil_dancer"], "The Briar Gate": ["thornblade", "veil_dancer"], "The Woodpile": ["woodward", "maulbeast"],
 "The Pilgrim Stair": ["ash_acolyte", "censer_adept"], "The Porch": ["censer_knight", "bell_ringer"],
 "The Drowned Stair": ["drowned_squire", "tomb_mummer"], "The Processional": ["crypt_warden", "crypt_crawler"],
 "The Gallery of Kings": ["crypt_warden", "crypt_crawler", "tomb_mummer"],
 "The Mews": ["ash_falconer", "scalebound"], "The Brood Guard": ["scalebound", "brood_keeper"],
 "The Wall Walk": ["rime_duelist", "rime_glaive"], "The Kennel Stair": ["frost_thrall", "frost_drake"], "The Great Stair": ["glacier_brute", "hoarbeast"],
 "The Grain": ["soul_eater", "name_thief"], "The Oath Hall": ["oath_eater", "the_unburied"],
 "The Antechamber": ["kingsblade", "herald"], "The Last Post": ["throne_guard", "throne_colossus"],
}
used = set()
for r in R:
    assert len(r["stages"]) == 7, r["id"]
    for s in r["stages"]:
        for o in s["options"]:
            if o["label"] in POOLS:
                assert o["foe"] in POOLS[o["label"]], o["label"]
                o["foes"] = POOLS[o["label"]]; used.add(o["label"])
assert used == set(POOLS), set(POOLS) - used
# Checkpoints (docs/FLOW.md, "Death and checkpoints"): a stage flagged `checkpoint: true` is where a knight who has fallen
# starts the road again. The road's start; the stop before every guardian's approach; the stop after a guardian that is
# not the last; and a stop in any long run between them, so that about every second or third stop is one. Never a stop
# that has a (non-optional) guardian in it.
def _checkpoints(stages):
    n = len(stages)
    boss = [any(o["type"] == "boss" and not o.get("optional") for o in s["options"]) for s in stages]
    forced = {0}
    for i in range(n):
        if boss[i]:
            if i > 0: forced.add(i - 1)
            if i + 1 < n: forced.add(i + 1)
    cps = sorted(i for i in forced if not boss[i])
    out, last = [], 0
    for i in range(n):
        if i in cps:
            out.append(i); last = i
        elif not boss[i] and i - last >= 3 and min([c for c in cps if c > i] or [n]) - i >= 2:
            out.append(i); last = i
    return out
for r in R:
    cps = _checkpoints(r["stages"])
    assert 0 in cps and all(not any(o["type"] == "boss" and not o.get("optional") for o in r["stages"][i]["options"]) for i in cps), r["id"]
    for i, s in enumerate(r["stages"]):
        if i in cps: s["checkpoint"] = True
    print(r["id"], "checkpoints at stops", cps)
# The continuous Courtyard (src/world/court_route.gd, docs/TRAVERSAL_PLAN.md): where each stop stands in the one place,
# [x, height, z, yaw in degrees]. Its frame: the knight stands at the anchor facing -z turned by yaw; the ways onward
# are marked 4.6 m ahead, the camera 4.2 m behind. The geometry round each anchor is built to that frame (a flat
# place about 10 m wide and 12 m deep), so these must move with court_route.gd's FLOORS and LEGS.
COURT_ANCHORS = [[0.0, 3.0, -68.0, 0.0], [0.0, 3.2, -92.0, 0.0], [0.0, 4.5, -119.0, 0.0], [0.0, 5.5, -141.0, 0.0],
                 [0.0, 5.5, -152.0, 0.0], [0.0, 6.2, -184.0, 0.0], [0.0, 8.0, -206.0, 0.0]]
assert R[0]["id"] == "courtyard"
for i, s in enumerate(R[0]["stages"]):
    s["anchor"] = COURT_ANCHORS[i]
json.dump({"regions": R}, open("data/regions.json", "w"), indent=1)
print(len(R), "regions")

# ================================================================ the three generations (docs/GENERATIONS_DATA.md)
# Written to data/generations.json and read by src/core/generations.gd and src/core/encounters.gd. The roads above are
# Generation II's and are not touched: the other generations are told as differences from them, stop by stop, so a
# stop keeps its number (and with it its records, its secrets, its chest and its place in the completion count).
def keep(label): return dict(keep=label)
def quiet(label, hint, **k): return dict(type="pass", label=label, hint=hint, **k)
def when(o, fact): o = dict(o); o["when"] = fact; return o
def unless(o, fact): o = dict(o); o["unless"] = fact; return o
GENERATIONS = [
 dict(index=1, role="first", ordinal="the First", chapter="The First Oath", year=0, fate="fallen", relation=dict(m="Father", f="Mother"),
      aim="Stop the exploitation", scenes_min=4.0),
 dict(index=2, role="second", ordinal="the Second", chapter="The Broken Crown", year=22, fate="kept", relation=dict(m="Son", f="Daughter"),
      aim="Avenge the first", scenes_min=9.0),
 dict(index=3, role="heir", ordinal="the Last", chapter="The Last Heir", year=46, fate="alive", relation=dict(m="Grandson", f="Granddaughter"),
      aim="Free the kingdom", scenes_min=8.0),
]
# What one of the house is to another, by how many generations apart (theirs minus the reader's).
KIN = {"-2": dict(m="Grandfather", f="Grandmother"), "-1": dict(m="Father", f="Mother"), "0": dict(m="Yourself", f="Yourself"),
       "1": dict(m="Son", f="Daughter"), "2": dict(m="Grandson", f="Granddaughter")}
# The forebear's own sheet: Generation I is fought with it and never with the family's profile (src/cine/prologue.gd).
FOREBEAR = dict(level=12, attrs=dict(health=14, strength=16, dex=9, endurance=12, defense=6, crit=2, resist=0), weapon="w_knight_sword",
                equipped=dict(shield=None, helm=None, chest=None, gauntlets=None, legs=None))
# Where each generation may go. Generation II is the chain of `requires` above. States: open, passed (walked through,
# nobody bars the way), sealed, shut, distant (seen, not reached), unknown.
ACCESS = {
 "1": dict(courtyard=dict(state="passed", why="The gate is kept and manned. Nobody bars a warden with a petition."),
           blackwood=dict(state="open", optional=True, why="The low road, and the patrol that walks it."),
           cathedral=dict(state="sealed", why="The cathedral is whole, and its doors are the Crown's."),
           crypt=dict(state="shut", why="The crypt is not yet flooded, and not yet open."),
           roost=dict(state="distant", why="A far light on the mountain."),
           citadel=dict(state="shut", why="The winter king still keeps his gates."),
           deep=dict(state="unknown", why="Nobody alive knows there is anything under the throne."),
           throne=dict(state="open", why="A warden may petition the throne.")),
 "3": dict(courtyard=dict(state="open"),
           blackwood=dict(state="open", requires=["courtyard"]), cathedral=dict(state="open", requires=["courtyard"]),
           citadel=dict(state="open", requires=["courtyard"], optional_guardian=True),
           crypt=dict(state="open", requires=["courtyard"], optional=True, why="The way down."),
           roost=dict(state="open", requires=["courtyard"], optional=True, why="The dragon hunt."),
           throne=dict(state="open", requires_any=dict(of=["blackwood", "cathedral", "citadel"], count=2)),
           deep=dict(state="open", optional=True, needs_fact="monarch_felled:3", sealed_as="sealed",
                     why="The door the Witness remembers. It opens from the other side of the throne.")),
}
# Stops told as differences. A stop not listed is as Generation II left it (levers already turned stay turned, chests
# already opened stay open). In Generation I every stop not listed is walked past.
STOPS = {
 "1": {
  "blackwood": {0: [fight("The Low Road", "The patrol knows a warden's colours. It has orders all the same.", "royal_patrol")]},
  "throne": {0: [fight("The King's Door", "\"Show the warden to the gate.\"", "royal_gatekeeper")],
             6: [boss("The Hollow Throne", "He comes down the steps himself.", "monarch_i")]},
 },
 "3": {
  "courtyard": {
   0: [fight("The Breach", "New plate, new recruits. The Crown replaces what it loses.", "pike_sergeant")],
   1: [keep("The Guardhouse"), quiet("The Rampart Stair", "Nobody walks the stair now.")],
   2: [quiet("The Barbican", "The banner is down. The one who stood under it was not replaced.")],
   4: [fight("The Gate Passage", "Something larger has been posted where the Breaker stood.", "gate_colossus"), keep("The Murder Hole")],
   # once the Kept has yielded and been let go it does not stand again: the post is empty on every later walk
   6: [unless(boss("The Inner Ward", "A guardian stands in the Sentinel's post. You know the way it stands.", "the_kept"), "released:the_kept"),
       when(quiet("The Inner Ward", "The post is empty. Two sets of footprints, and one blade's mark in the stone."), "released:the_kept")],
  },
  "blackwood": {
   0: [fight("The Lantern Road", "The lanterns are out. Something moves between them anyway.", "veil_dancer")],
   1: [quiet("The Road", "Bootprints, old ones, going one way."),
       unless(boss("The Deer Trail", "White antlers, greyer now, between the trunks.", "pale_huntsman", optional=True), "slain:pale_huntsman")],
   2: [quiet("The Briar Gate", "The briars were cut through years ago, and never grew back."), keep("The Hollow Oak")],
   4: [quiet("The Woodpile", "The stacks have rotted where they stood.")],
   6: [boss("The Clearing", "The stumps have been torn out of the ground.", "awakened_beast")],
  },
  "cathedral": {
   0: [fight("The Pilgrim Stair", "The robes are new. The hymn is not.", "censer_adept")],
   1: [quiet("The Porch", "The great censer lies where it fell."), keep("The Almoner's Box")],
   2: [quiet("The Cathedral Steps", "Nobody is waiting on the steps.")],
   4: [fight("The Choir Loft", "The choir is silent. The bell is not.", "bell_ringer")],
   6: [boss("The Lower Door", "Under the crossing, where the bronze lay, a door stands open.", "laboratory_guardian")],
  },
  "crypt": {
   0: [fight("The Drowned Stair", "The water is lower. What it covered is not gone.", "tomb_mummer")],
   1: [keep("The Ossuary"), quiet("The Processional", "The footfalls have stopped.")],
   2: [quiet("The Weeping Tomb", "The lid is dry.")],
   4: [keep("The Royal Vault"), fight("The Gallery of Kings", "Something crawls where the wardens walked.", "crypt_crawler")],
   6: [unless(boss("The Way Down", "Behind the first tomb, a stair. Something at the foot of it says a name.", "devourer"), "slain:devourer"),
       when(quiet("The Way Down", "The stair goes down to an emptied place."), "slain:devourer")],
  },
  "roost": {
   0: [fight("The Glass Road", "The scale is new. The oath is the old one.", "scalebound")],
   1: [quiet("The Mews", "The perches are empty."), keep("The Tack Room")],
   2: [fight("The Boneyard", "The keeper of the clutch has come down to the bones.", "brood_keeper")],
   4: [keep("The Clutch"), quiet("The Brood Guard", "Nobody guards the shells.")],
   6: [unless(boss("The Summit", "A shadow crosses the sun, and comes back.", "cinder_wyrm"), "slain:cinder_wyrm"),
       when(unless(boss("The Summit", "The old one has come down from the hall to the empty nest.", "azhurion"), "slain:azhurion"), "slain:cinder_wyrm"),
       when(when(quiet("The Summit", "The sky is only sky."), "slain:cinder_wyrm"), "slain:azhurion")],
  },
  "citadel": {
   0: [fight("The Frozen Rank", "The ranks have thawed. One of them kept his post.", "rime_glaive")],
   1: [quiet("The Wall Walk", "The duellist's footprints are worn into the ice. He is not in them."), keep("The Armoury")],
   2: [quiet("The Kennel Stair", "The chain hangs slack.")],
   4: [fight("The Great Stair", "It has made its den on the landing.", "hoarbeast")],
   6: [unless(boss("The Winter Throne", "The king is gone. What he kept chained has climbed to his seat.", "rimewyrm"), "slain:rimewyrm"),
       when(boss("The Winter Throne", "The pit is empty. Her brood has taken the hall.", "white_brood"), "slain:rimewyrm")],
  },
  "throne": {
   0: [fight("The King's Door", "The King's Shadow stands where the Gatekeeper stood.", "throne_colossus")],
   1: [quiet("The Antechamber", "The king's own blade does not bow to you. He is not here."), keep("The Treasury")],
   2: [quiet("The Steps", "A crown lies on the steps. Nobody is turning it.")],
   4: [fight("The Last Post", "A herald, with nothing left to announce.", "herald"), keep("Behind the Throne")],
   5: [keep("Steady Yourself"),
       unless(boss("The Roof of the Hall", "Something vast is still folded among the rafters.", "azhurion", optional=True), "slain:azhurion")],
   6: [boss("The Hollow Throne", "The floor of the hall stands open.", "monarch_iii")],
  },
  "deep": {
   0: [fight("The Long Stair", "The ones along the wall have turned round.", "husk")],
   1: [quiet("The Gallery of Names", "No more names have gone from the wall."), keep("The Unread Wall")],
   2: [fight("The Grain", "It wears a name it took.", "name_thief")],
   4: [fight("The Oath Hall", "It was put in the ground and did not stay.", "the_unburied"), keep("The Reliquary of Vows")],
   6: [unless(boss("The Bottom", "It says a name. It might be yours.", "devourer"), "slain:devourer"),
       when(quiet("The Eternal Crown", "The lowest room. The machine is here, and it is waiting to be told."), "slain:devourer")],
  },
 },
}
# The individuals of Generation II that a later generation must account for. A mortal one that fell is never met again;
# `after` is who stands in its post and why. One that was not fought may still be there.
MORTALS = {
 "ashen_sentinel": dict(after="the_kept", why="His post was given to another."),
 "hollow_executioner": dict(after="awakened_beast", why="The clearing was empty for twenty-four years."),
 "crimson_widow": dict(after="", why="She is not waiting on the steps."),
 "cathedral_beast": dict(after="laboratory_guardian", why="Its fall uncovered the lower door."),
 "gravewarden": dict(after="devourer", why="Behind the first tomb there was always a way down."),
 "frostbound_king": dict(after="rimewyrm", why="He gave up his crown. What he kept chained did not."),
 "pale_huntsman": dict(after="", why="If he fell, the trail is empty."),
 "cinder_wyrm": dict(after="azhurion", why="The old one comes down to the empty nest."),
 "rimewyrm": dict(after="white_brood", why="What she left in the pit grew."),
 "azhurion": dict(after="", why="The rafters are empty."),
 "devourer": dict(after="", why="The bottom is an emptied place."),
 "kingsblade": dict(after="herald", why="The king's own blade was not replaced."),
 "crownless": dict(after="", why="Only the crown is left on the steps."),
 "banneret": dict(after="", why="The banner is down."),
}
# Generation III's numbers: every foe it meets is brought up to the end of the road, so what the house inherited does
# not walk through it, and pays at that level. Measured against the roster itself (ordinary foes, by home region).
_foes = json.load(open("data/bosses.json"))["bosses"]
def _mean(region, f):
    v = [f(x) for x in _foes if x["region"] == region and not x["boss"]]
    return sum(v) / len(v)
def _dmg(x):
    d = [a["dmg"] for ph in x["phases"] for c in ph["combos"] for a in c["attacks"]]
    return sum(d) / len(d)
G3 = dict(hp=4.2, dmg=1.45, xp=1.25, gold=2.2)          # against the Hollow Throne's own road; tuned with tools/econ_sim.sh --generations
TUNING = {"3": dict(regions={}, boss_hp_target=26000, boss_hp_range=[1.4, 9.0], boss_dmg_share=0.7, shards=2.0)}
for r in R:
    rid = r["id"]
    TUNING["3"]["regions"][rid] = dict(
        hp=round(G3["hp"] * _mean("throne", lambda x: x["hp"]) / _mean(rid, lambda x: x["hp"]), 2),
        dmg=round(G3["dmg"] * _mean("throne", _dmg) / _mean(rid, _dmg), 2),
        xp=round(G3["xp"] * _mean("throne", lambda x: x["xp"]) / _mean(rid, lambda x: x["xp"]), 2),
        gold=round(G3["gold"] * _mean("throne", lambda x: x["gold"]) / _mean(rid, lambda x: x["gold"]), 2))
# The family's knowledge. Gathered in the generation named (0 = whichever finds it), kept for good. `auto` ones cannot be
# missed; the rest are the optional discoveries. `ending` ones are what dividing the Crown needs; every one gathered
# weakens the Monarch's last defence (bosses.json variants, monarch_iii `records`).
RECORDS = [
 dict(id="first_oath", gen=1, auto=True, name="The First Oath", text="What the first of the house sent out through the sword.", need=dict(fallen=1)),
 dict(id="measure_of_him", gen=1, name="The Measure of Him", text="How he fights, set down by one who crossed blades with him and was winning.", need=dict(clash="won")),
 dict(id="broken_crown", gen=2, auto=True, name="The Broken Crown", text="The count behind the seal, carried out whole.", need=dict(fallen=2)),
 dict(id="the_crown_can_bleed", gen=2, name="The Crown Can Bleed", text="He was beaten once, in a fair fight, and the machines stood him up again.", need=dict(monarch_won=2)),
 dict(id="surviving_version", gen=0, ending=True, name="The Surviving Version", text="Thirty records of what the Crown rewrote.", need=dict(lore=30)),
 dict(id="siege_engine", gen=0, ending=True, name="The Siege That Outlived Its War", text="What was kept under the Roost, faced.", need=dict(cleared=["roost"])),
 dict(id="partition_key", gen=0, ending=True, name="The Partition Key", text="What the Devourer was made of, and how it was unmade.", need=dict(defeated=["devourer"])),
 dict(id="one_who_was_kept", gen=3, ending=True, name="One Who Was Kept", text="A stored mind that was asked, and chose.", need=dict(defeated=["the_kept"])),
]
# The three meetings with the Monarch.
MONARCH = {
 "1": dict(foe="monarch_i", kind="clash", region="throne", stop=6, outcome="story",
           note="The story takes the fight on a cut the player lands, not on a health bar. Nothing here is won or lost."),
 "2": dict(foe="forgotten_monarch", kind="duel", region="throne", stop=6, threshold=dict(phase=2, at=0.33), choices=["press", "records"],
           note="At the threshold the seal burns: press the attack, or save the records. A player who wins is recorded as having won."),
 "3": dict(foe="monarch_iii", kind="final", region="throne", stop=6, phases=["The Sovereign", "The Ancient Crown", "The Last Defense"]),
}
ENDINGS = [
 dict(id="silence", name="The Final Silence", need=dict()),
 dict(id="steward", name="The Last Steward", need=dict()),
 dict(id="cities", name="The Free Cities", need=dict(records="ending")),
]
ECHO = dict(id="the_kept", name="The Crownless Champion", title="The Kept", region="courtyard", stop=6, music_as="frostbound_king",
            intro="It is wearing what you wore. It stands the way you stood.", combos=5)
# checks: every stop named exists, every kept label is on that stop, every foe is in the roster or is a variant
_ids = set(x["id"] for x in _foes) | set(v["id"] for v in json.load(open("data/bosses.json")).get("variants", [])) | {ECHO["id"]}
_by = {r["id"]: r for r in R}
for g in STOPS:
    for rid in STOPS[g]:
        for i, opts in STOPS[g][rid].items():
            labels = [o["label"] for o in _by[rid]["stages"][i]["options"]]
            for o in opts:
                assert "keep" not in o or o["keep"] in labels, (g, rid, i, o)
                assert "foe" not in o or o["foe"] in _ids, (g, rid, i, o)
        STOPS[g][rid] = {str(i): v for i, v in STOPS[g][rid].items()}
for m in MORTALS:
    assert m in _ids and (MORTALS[m]["after"] == "" or MORTALS[m]["after"] in _ids), m
json.dump(dict(house="Marrek", generations=GENERATIONS, kin=KIN, forebear=FOREBEAR, access=ACCESS, stops=STOPS, mortals=MORTALS, tuning=TUNING,
               records=RECORDS, monarch=MONARCH, endings=ENDINGS, echo=ECHO), open("data/generations.json", "w"), indent=1)
print("generations:", len(GENERATIONS), "| records:", len(RECORDS))
