#!/usr/bin/env python3
"""Authoring script for the secrets and completion layer (docs/SECRETS_AND_COMPLETION.md).
Writes data/secrets.json, and the two additive blocks the layer keeps in shared files:
"side" in data/quests.json (the side missions) and "hidden" in data/lore.json (records only a secret gives).
The existing "quests" and "lore" lists are written back exactly as they were read.
Run from the project root, then tools/gen_dialogue.py (it reads the subtitle lines from data/secrets.json)."""
import json

LY, W = "lyra", "witness"
SECRETS = []; HIDDEN = []; CHALLENGERS = {}; SIDE = []

def lore(id, title, text, region, secret):
    HIDDEN.append(dict(id=id, title=title, text=text, region=region, stage=-1, secret=secret))
    return id

def S(id, name, family, region, stage, trigger, hint, say, found, reward, tell=None, pos=None, when=None, spoil=(), solution="", rare=False,
      locked_text="", lore_title="", lore_text=""):
    """One secret. `hint` is what the Completion page may show; `solution` is for the design document and the tests
    (a hint must never contain it, nor any word in `spoil`)."""
    reward = dict(reward)
    if lore_title:
        reward["lore"] = lore("s_" + id, lore_title, lore_text, region, id)
    d = dict(id=id, name=name, family=family, region=region, stage=stage, trigger=trigger, hint=hint, found=found, reward=reward,
             say=dict(speaker=say[0], text=say[1], dir=say[2] if len(say) > 2 else ""), spoil=list(spoil), solution=solution, rare=rare)
    if tell: d["tell"] = tell
    if pos: d["pos"] = list(pos)
    if when: d["when"] = when
    if locked_text: d["locked_text"] = locked_text
    SECRETS.append(d)

TAP = dict(type="tap")
def WAIT(seconds): return dict(type="wait", seconds=seconds)
def SEQ(spots, order): return dict(type="sequence", spots=spots, order=order)
def DUEL(challenger): return dict(type="duel", challenger=challenger)
def FEAT(key): return dict(type="feat", feat=key)

# ================================================================ the secrets (thirteen: one to four a region)
S("cy_loose_stone", "The Relief Order", "tap", "courtyard", 2, TAP,
  "At the Barbican, something underfoot is not as it was laid.",
  (LY, "That one has been lifted before. Often, and carefully.", "quiet"),
  "Under the stone, wrapped in oilcloth: an order nobody carried the last hundred paces.",
  dict(gold=60), tell="stone", pos=(3.1, -3.4), spoil=("stone", "flagstone", "lift"),
  solution="Tap the pale, tilted flagstone to the right of the path at the Barbican.",
  lore_title="The Relief Order",
  lore_text="'Sergeant of the Gate: you are relieved at first thaw. Report to the inner ward.' Signed, sealed, dated the first spring. It was hidden under a flagstone thirty paces from the man it names. Whoever was sent with it chose not to arrive.")
S("cy_second_candle", "The Second Candle", "return", "courtyard", 5, TAP,
  "The chapel alcove changes once the gate has no keeper.",
  (LY, "I did not light that one. I want that understood.", "uneasy"),
  "A second candle stands beside the first. It is the same kind, and gives the same light without heat.",
  dict(trophy="t_second_candle"), tell="candle", pos=(-2.6, -2.9), when=dict(defeated=["ashen_sentinel"]), spoil=("candle", "sentinel", "second"),
  solution="After the Ashen Sentinel has fallen, return to the chapel alcove and tap the new, cold-blue candle on the ground to the left.",
  lore_title="The Second Candle",
  lore_text="After the gate lost its keeper a second light appeared in the alcove. It was not carried there. The maintenance point registered one fewer body in service and, for the first time in three centuries, marked it.")
S("cy_charcoal_sketch", "A Charcoal Sketch", "sketch", "courtyard", 4, TAP,
  "Somebody left their working-out in the gate passage.",
  (LY, "Not of here. Somebody wanted that place found again. Keep it.", "curious, quick; 'Keep it' firm"),
  "A square of hide, rolled tight and pushed into a crack: a charcoal drawing of a spring under a hanging tree.",
  dict(shards=1), tell="scroll", pos=(-3.0, -2.2), spoil=("crack", "hide", "roll", "scroll"),
  solution="Tap the rolled hide wedged between two stones on the left of the gate passage.",
  lore_title="Sketch: The Spring",
  lore_text="Charcoal on hide. A tree with a rope hanging from it, and a spring at its foot. To the left of the water three stones lie in a row. The artist has rubbed the middle stone black, and written nothing.")
S("bw_dark_lantern", "The Lamplighter's Round", "tap", "blackwood", 0, TAP,
  "On the Lantern Road, count what is lit and what is not.",
  (LY, "It was only waiting to be asked. Everything here is still waiting to be asked.", "low"),
  "The one dark lantern takes light from your hand and holds it. Inside the cage is a strip of bark, cut with marks.",
  dict(gold=80), tell="lantern", pos=(-3.2, -3.8), spoil=("dark", "unlit", "low"),
  solution="Tap the one unlit lantern standing low by the left of the Lantern Road.",
  lore_title="The Lamplighter's Round",
  lore_text="Bark, cut with a knife: 'My round, as my mother walked it. At the woodpile trim the posts in her order: the tall post, the split post, the leaning post, the short. Do it wrong and start again. Nobody is watching. Do it right anyway.'")
S("bw_three_stones", "The Shaded Stone", "sketch", "blackwood", 5, TAP,
  "A drawing found elsewhere shows this spring from the artist's side.",
  (LY, "The middle one. Exactly as it was drawn. Somebody trusted a stranger to look closely.", "pleased"),
  "Under the middle stone, a tin of blacking and a rag: a soldier's kit, kept dry for three centuries.",
  dict(finish="f_charcoal", shards=2), tell="three_stones", pos=(-2.8, -3.2), when=dict(secret="cy_charcoal_sketch"), spoil=("middle", "three", "stone"),
  locked_text="Three stones in a row by the water. They mean nothing to you yet.",
  solution="Holding the charcoal sketch from the Courtyard's gate passage, tap the row of three stones left of the spring under the gibbet tree.")
S("bw_woodpile_posts", "The Trimmed Posts", "sequence", "blackwood", 4,
  SEQ([dict(tell="post_tall", pos=(-3.6, -4.6), label="tall"), dict(tell="post_short", pos=(-2.6, -3.0), label="short"),
       dict(tell="post_lean", pos=(2.9, -3.2), label="leaning"), dict(tell="post_split", pos=(3.8, -4.8), label="split")], [0, 3, 2, 1]),
  "Four marker posts stand about the woodpile. A lamplighter once wrote down how they are tended.",
  (LY, "The fourth one lit. They were never markers. They are the lamps for a road nobody finished.", "wondering"),
  "Each post warms under the hand in turn. At the fourth, all of them light, low and steady, along a road that was never cut.",
  dict(materials={"m_iron": 3}, trophy="t_trimmed_wick"), spoil=("tall", "split", "leaning", "short", "order"),
  solution="Touch the four posts at the Woodpile in the order the Lamplighter's Round gives: tall, split, leaning, short.",
  lore_title="The Unfinished Road",
  lore_text="Four lamp posts in a clearing with no road between them. The survey pegs for the rest still stand in a line through the trees, pointing at the Cathedral. The woodcutter was clearing the way for it. Nobody told him the road had been cancelled, or what it was meant to carry.")
S("ca_end_of_cylinder", "End of the Cylinder", "listen", "cathedral", 4, WAIT(16),
  "The hymn in the choir loft is not as endless as it sounds.",
  (LY, "It stopped. And then it said a number. Hymns do not end with a number.", "unsettled"),
  "The hymn runs out. In the silence a flat voice reads a batch number and a date, and the hymn begins again.",
  dict(gold=110), spoil=("wait", "stay", "listen", "stand"),
  solution="Stand in the Choir Loft for sixteen seconds without acting.",
  lore_title="End of the Cylinder",
  lore_text="'Devotional cycle nine. Congregation batch forty-one. Play until relieved.' The voice is bored. It is the only voice in the cathedral that sounds like a person at work.")
S("cr_whispered_name", "A Name You Answer To", "listen", "crypt", 5, WAIT(18),
  "The reliquary lamp asks nothing. It does, given time, say something.",
  (LY, "It said a name. You turned your head. You turned before I had finished hearing it.", "very quiet"),
  "The lamp murmurs, too low to catch, and then quite clearly says a name. It is not yours. You answer to it anyway.",
  dict(shards=4), spoil=("wait", "sit", "listen", "stay", "name"), rare=True,
  solution="Sit by the reliquary lamp for eighteen seconds without acting.",
  lore_title="A Name You Answer To",
  lore_text="The lamp reads its row aloud when someone sits long enough: a soldier's name, a child's, and a third with a line struck through it on the plate. You know all three the way you know your own hands. The lamp does not read a fourth, though there is room on the plate for one.")
S("ro_no_shield", "Unshielded at the Summit", "mastery", "roost", 6, FEAT("noshield:cinder_wyrm"),
  "Something stands fused into the Glass Road. Whoever left it carried less than you do.",
  (LY, "There are two footprints fused into the glass road below. Whoever made them carried no shield either. You walked down again.", "level"),
  "The sky is very large, and you met it with a blade and nothing else.",
  dict(trophy="t_glass_footprints", title="ti_unshielded"), spoil=("shield", "without", "two-handed"),
  solution="Defeat the Cinder Wyrm with no shield equipped.")
S("ci_reflection", "Twice Yourself", "duel", "citadel", 1, DUEL("reflection"),
  "On the Wall Walk somebody practised alone for an age. Ask what against.",
  (LY, "That is a Recall surface. It is not showing you. It is playing you back.", "tense"),
  "It has your stance, your reach, and your habit of dropping the point. When it breaks, it breaks exactly the way you would.",
  dict(title="ti_twice", shards=4), tell="ice", pos=(-3.4, -5.6), when=dict(defeated=["rime_duelist"]), spoil=("ice", "mirror", "reflection", "duelist", "duellist"),
  solution="After beating the Rime Duelist, return to the Wall Walk and tap the slab of black ice standing on the left. Beat the reflection that steps out of it.",
  lore_title="Recall Surface",
  lore_text="A sheet of black ice that is not ice. The Everbound used such surfaces to rehearse: it stores whoever stands before it and gives them back as an opponent. The duellist on the wall had been losing to himself, narrowly, for three hundred years.")
S("de_candle_bearer", "Who Carried It", "carried", "deep", 3, TAP,
  "The Last Candle was set down by someone. One of your companions could say who.",
  (W, "I know that hand. She carried it down herself, when she could still carry. Lyra, you were told you had never left the sanctuary.", "careful"),
  "In the wax at the candle's foot is the print of a thumb, small, pressed in while it was warm.",
  dict(gold=260), tell="candle", pos=(-2.6, -2.6), when=dict(witness=True), spoil=("witness", "thumb", "wax"), rare=True,
  solution="With the Witness found, tap the small cold candle on the left at the fourth stop of the Deep (Mark the Way and the Last Candle).",
  lore_title="Who Carried It",
  lore_text="The candle on the unlit stair is the sanctuary's, and the thumbprint in its wax is a living hand's. Lyra remembers no body and no stair. The Witness remembers a woman going down with a light, and coming up without it, and being asked to forget which.")
S("th_parade_sword", "The Parade Sword of the Ninth Jubilee", "oddity", "throne", 1, TAP,
  "The Treasury was emptied by people with taste. They left one thing.",
  (W, "I was present when it was presented. The applause was the bravest thing I ever saw at court.", "very dry"),
  "It is enormous, gilded, and enamelled with the faces of nine kings. It could not cut bread. Three hundred years of looters have walked past it.",
  dict(trophy="t_parade_sword"), tell="gaudy", pos=(-2.8, -3.0), spoil=("sword", "gilt", "gilded", "enamel"),
  solution="Tap the gaudy gilt sword propped on the left in the Antechamber.",
  lore_title="The Parade Sword of the Ninth Jubilee",
  lore_text="Commissioned by a guild that wished to be noticed, at a weight no arm could lift twice. The blade is soft gold over softer iron; the hilt has nine enamelled royal portraits, two of them of the same king. It was carried in one procession, by four men. Orren, shown it, was silent for some time and then asked to be left alone with his anvil.")
S("cy_cycle_count", "The Cycle Count", "cycle", "courtyard", 0, TAP,
  "The Breach looks different to someone who has already seen how this ends.",
  (LY, "That mark was not there the first time. Or you could not see it. I cannot tell which is worse.", "unsteady; the second sentence slower"),
  "A line of small cuts in the fallen wall, at eye height, and a fresh one at the end. It is made with the edge you are carrying.",
  dict(trophy="t_cycle_tally", title="ti_twice_walked", shards=6), tell="blade", pos=(2.9, -3.0), when=dict(ng_min=1), rare=True,
  spoil=("ending", "new game", "cycle", "again", "second"),
  solution="Finish the story, begin a New Game Plus, and at the very first stop of the Courtyard tap the blade standing in the rubble on the right.",
  lore_title="The Cycle Count",
  lore_text="Somebody has been marking the breach each time they walked out through it. The cuts are old at one end and bright at the other, and all of them were made by the same hand at the same height. The Gravewarden's record said you were the first the chamber permitted to leave. It did not say you were the first to wake.")

# ================================================================ clues: things in a scene that can be touched and only speak
# Not secrets and not counted. A deed in a duel has no place to put a tell, so its tell stands on the road to it.
CLUES = [
 dict(id="clue_glass_footprints", region="roost", stage=0, tell="blade", pos=(-2.9, -3.6), points_to="ro_no_shield",
      text="A sword fused upright in the glazed road, and two footprints set square before it. Whoever stood here against the summit carried no shield: there is none in the glass."),
]

# ================================================================ hidden challengers (existing rigs and models, retuned)
CHALLENGERS.update({
 "reflection": dict(base="rime_duelist", name="Your Reflection", title="Played Back", hp=1.0, speed=1.05, xp=1.4, gold=1.2,
    traits={"parry_open": 1.1}, rig={"eye": "#8fdcff"}, mirror=True),
})

# ================================================================ side missions (data/quests.json "side")
def M(id, name, giver, text, need, reward, done_text, after=None):
    d = dict(id=id, name=name, giver=giver, text=text, need=need, reward=reward, done_text=done_text, side=True)
    if after: d["after"] = after
    SIDE.append(d)

M("orren_stock", "Stock for the Anvil", "Orren",
  "Orren is low on sound metal. Bring him six pieces of Old Iron from the Courtyard or the Blackwood, and he will show you what his family did with the offcuts.",
  dict(materials={"m_iron": 6}), dict(gold=150, finish="f_oiled"),
  "\"Garrison stock. Rust on the outside, honest underneath.\" He rubs a rag of black oil along your vambrace without asking.")
M("orren_proof", "Proof Strokes", "Orren",
  "Orren has reground a Courtyard Longsword and does not trust his own work until it has been used in earnest. Win three fights with one in your hand.",
  dict(feats={"win_item:w_knight_sword": 3}), dict(gold=200, shards=3),
  "He sights down the edge for a long time. \"It held. Good. I was not sure I still could.\"")
M("lyra_courtyard", "What the Courtyard Hid", "Lyra",
  "Lyra's plans of the Fallen Courtyard are three hundred years out of date. Find three things there that are on no plan she holds.",
  dict(secrets_in={"courtyard": 3}), dict(gold=150, shards=2),
  "\"Three. On a ground I thought I knew stone by stone. I am going to have to look at everything again.\"")
M("lyra_stand_still", "Stand Still", "Lyra",
  "You walk through places as if they were only on the way. Lyra asks you, twice, somewhere on the road, simply to stay and listen until the place has finished speaking.",
  dict(feats={"listened": 2}), dict(finish="f_dusk", gold=120),
  "\"You heard them. Most people leave before a place has finished.\"")
M("witness_record", "For the Record", "The Witness",
  "The Witness wrote down what he was told to for a lifetime. Bring him six things nobody told anyone to write down.",
  dict(secrets=6), dict(title="ti_corrector", gold=300),
  "\"Six corrections. The record is still a disgrace, but it is now a disgrace with footnotes.\"", after=dict(witness=True))

# ================================================================ completion
COMPLETION = dict(
 weights=dict(stops=25, guardians=20, secrets=25, missions=15, lore=15),
 region_weights=dict(stops=30, guardians=25, secrets=25, lore=20),
 names=dict(stops="Stops walked", guardians="Guardians ended", secrets="Secrets found", missions="Tasks done", lore="Records recovered"),
 hints=dict(stops="A stretch of this road has not been walked on foot.", guardians="Something here has not been faced.",
            lore="A record on this road is unread.", missions="A task in the Journal is unfinished."))

FINISHES = {"f_charcoal": "Soldier's blacking", "f_oiled": "Oiled black", "f_dusk": "Dusk grey", "f_half": "Field-dressed", "f_complete": "Unbound gilt"}
TROPHIES = {
 "t_second_candle": ("The Second Candle", "A light that came by itself after the gate lost its keeper."),
 "t_trimmed_wick": ("A Trimmed Wick", "From the lamps of a road nobody finished."),
 "t_glass_footprints": ("Cast of Two Footprints", "Taken from the glazed road under the Roost."),
 "t_parade_sword": ("The Parade Sword of the Ninth Jubilee", "Too ugly to steal. Hung where Orren does not have to look at it."),
 "t_cycle_tally": ("A Rubbing of the Tally", "The marks at the breach, in charcoal. All in one hand."),
 "t_three_quarter": ("The Witness's Pen", "He says he will not need it for a while."),
 "t_complete": ("The Empty Plinth", "A plinth with no statue. There is nothing left to put on it that you have not seen."),
}
TITLES = {"ti_unshielded": "the Unshielded", "ti_twice": "Twice Yourself", "ti_twice_walked": "the Twice-Walked",
          "ti_corrector": "Corrector of the Record", "ti_surveyor": "Surveyor of Ruins", "ti_complete": "the Unbound, Entire"}
REGIONS = ["courtyard", "blackwood", "cathedral", "crypt", "roost", "citadel", "deep", "throne"]
# two milestones on the way and the last one: nothing here is a statistic
MILESTONES = [
 dict(id="all_50", scope="overall", at=50, reward=dict(finish="f_half", title="ti_surveyor")),
 dict(id="all_75", scope="overall", at=75, reward=dict(trophy="t_three_quarter")),
 dict(id="all_100", scope="overall", at=100, reward=dict(finish="f_complete", trophy="t_complete", title="ti_complete")),
]

# ---------------------------------------------------------------- checks
ids = [s["id"] for s in SECRETS]
assert len(ids) == len(set(ids)) and 10 <= len(ids) <= 14, len(ids)
for s in SECRETS:
    assert s["region"] in REGIONS and 0 <= s["stage"] <= 6, s["id"]
    low = s["hint"].lower()
    assert s["solution"] and s["solution"].lower() not in low and s["name"].lower() not in low, s["id"]
    for w in s["spoil"]:
        assert w.lower() not in low, (s["id"], w)
    r = s["reward"]
    assert r.get("finish", "f_dusk") in FINISHES and r.get("trophy", "t_complete") in TROPHIES and r.get("title", "ti_twice") in TITLES, s["id"]
    w = s.get("when", {})
    assert w.get("secret", ids[0]) in ids, s["id"]
    if s["trigger"]["type"] == "duel":
        assert s["trigger"]["challenger"] in CHALLENGERS
    if s["trigger"]["type"] in ("tap", "duel"):
        assert s.get("tell") and s.get("pos"), s["id"]
assert len({m["id"] for m in SIDE}) == len(SIDE) and 4 <= len(SIDE) <= 6
for m in SIDE:
    r = m["reward"]
    assert r.get("finish", "f_dusk") in FINISHES and r.get("title", "ti_twice") in TITLES, m["id"]
for m in MILESTONES:
    assert m["reward"].get("finish", "f_half") in FINISHES and m["reward"].get("trophy", "t_complete") in TROPHIES
assert sum(COMPLETION["weights"].values()) == 100 and sum(COMPLETION["region_weights"].values()) == 100

for c in CLUES:
    assert c["points_to"] in ids and c["region"] in REGIONS
json.dump(dict(secrets=SECRETS, clues=CLUES, challengers=CHALLENGERS, completion=COMPLETION, milestones=MILESTONES, finishes=FINISHES,
               trophies={k: dict(name=v[0], text=v[1]) for k, v in TROPHIES.items()}, titles=TITLES), open("data/secrets.json", "w"), indent=1)
q = json.load(open("data/quests.json"))
q["side"] = SIDE
json.dump(q, open("data/quests.json", "w"), indent=1)
l = json.load(open("data/lore.json"))
l["hidden"] = HIDDEN
json.dump(l, open("data/lore.json", "w"), indent=1)
fam = {}
for s in SECRETS:
    fam[s["family"]] = fam.get(s["family"], 0) + 1
print(len(SECRETS), "secrets", fam, "|", len(SIDE), "side missions |", len(HIDDEN), "hidden records |", len(CHALLENGERS), "challengers")
