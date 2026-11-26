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

# ================================================================ the Fallen Courtyard
S("cy_loose_stone", "The Relief Order", "tap", "courtyard", 2, TAP,
  "At the Barbican, something underfoot is not as it was laid.",
  (LY, "That one has been lifted before. Often, and carefully.", "quiet"),
  "Under the stone, wrapped in oilcloth: an order nobody carried the last hundred paces.",
  dict(gold=60), tell="stone", pos=(3.1, -3.4), spoil=("stone", "flagstone", "lift"),
  solution="Tap the pale, tilted flagstone to the right of the path at the Barbican.",
  lore_title="The Relief Order",
  lore_text="'Sergeant of the Gate: you are relieved at first thaw. Report to the inner ward.' Signed, sealed, dated the first spring. It was hidden under a flagstone thirty paces from the man it names. Whoever was sent with it chose not to arrive.")
S("cy_winch_hum", "What the Drum Counts", "listen", "courtyard", 3, WAIT(14),
  "The winch-house has more to say than it says at once.",
  (LY, "Listen. Under the chain. It is counting, and it has not lost its place.", "hushed"),
  "The sealed drum ticks through a pattern, pauses, and begins again where it stopped three hundred years ago.",
  dict(materials={"m_iron": 2}), spoil=("wait", "stand", "still", "linger"),
  solution="Stand at the winch-house stop for fourteen seconds without choosing a way onward or taking anything.",
  lore_title="What the Drum Counts",
  lore_text="Stand long enough beside the winch and the grey drum can be heard keeping a tally: a tick for each time the gate has opened. The count is very long. The last four ticks are yours.")
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
  (LY, "A drawing. Not of here. Keep it. Somebody wanted a place found again.", "curious"),
  "A square of hide, rolled tight and pushed into a crack: a charcoal drawing of a spring under a hanging tree.",
  dict(shards=1), tell="scroll", pos=(-3.0, -2.2), spoil=("crack", "hide", "roll", "scroll"),
  solution="Tap the rolled hide wedged between two stones on the left of the gate passage.",
  lore_title="Sketch: The Spring",
  lore_text="Charcoal on hide. A tree with a rope hanging from it, and a spring at its foot. To the left of the water three stones lie in a row. The artist has rubbed the middle stone black, and written nothing.")
S("cy_second_salute", "The Second Salute", "duel", "courtyard", 5, DUEL("second_salute"),
  "Good manners at the Barbican are noticed, and returned later.",
  (LY, "He is saluting. He is waiting for you to finish resting. I think that is courtesy.", "wary"),
  "He salutes, and this time it is not a formality. When it is over he sets his sword down hilt-first, toward you.",
  dict(title="ti_answered", shards=3), tell="figure", pos=(3.6, -6.4), when=dict(feat="parry_first:banneret"), spoil=("parry", "first", "blow", "cut"),
  solution="Parry the very first blow the Banneret throws at the Barbican. At the chapel alcove later on that road a second duellist stands at the edge of the light: tap him and win.",
  lore_title="The Salute",
  lore_text="The duellists of the barbican were taught one rule before any stroke: the first cut is a question. Answer it with your blade and you are a guest. Step away from it and you are only an intruder. There were always two of them posted. The second was for guests.")
S("cy_unmarked", "Unmarked", "mastery", "courtyard", 6, FEAT("flawless:ashen_sentinel"),
  "The Sentinel's discipline can be matched exactly.",
  (LY, "He never touched you. He stood a post for three hundred years and you gave him nothing to report.", "soft"),
  "Not a mark on you. The embers settle on your armour and go out.",
  dict(trophy="t_clean_tabard", title="ti_unmarked"), spoil=("hit", "struck", "damage", "untouched"),
  solution="Defeat the Ashen Sentinel without being struck once.")

# ================================================================ the Blackwood
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
S("bw_last_row", "The Last Row", "return", "blackwood", 1, TAP,
  "The deer trail keeps something for whoever walks it after the hunt is over.",
  (W, "He kept accounts. I approve of a man who keeps accounts, even of that.", "dry"),
  "A knife pins a strip of hide to the trunk. The last three rows have not been scored through. He left them for someone.",
  dict(materials={"m_iron": 3}), tell="blade", pos=(3.3, -4.4), when=dict(defeated=["pale_huntsman"]), spoil=("knife", "trunk", "huntsman", "hide"),
  solution="After the Pale Huntsman has been met and beaten, return to the fork at the deer trail and tap the knife standing in the stump on the right.",
  lore_title="The Last Row",
  lore_text="Three drawings with no line through them: a thing with a long neck and a chain on it, a thing that walks on its knuckles in the dark, and a thing drawn only as a white shape with a crown of ice. Under them, in a different hand: 'If I am not here, these are yours.'")
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
S("bw_ravine_answer", "What the Ravine Keeps", "listen", "blackwood", 3, WAIT(16),
  "The ravine answers those who are in no hurry to cross it.",
  (W, "Do you hear it? Water, where there is no river. They ran the cold lines under the forest. I signed for the pipe.", "remembering"),
  "From far below, a steady rush that is not water, and now and then a click, like a valve.",
  dict(gold=90), when=dict(witness=True), spoil=("wait", "stand", "still", "linger", "witness"),
  solution="With the Witness found, stand at the ravine stop for sixteen seconds without acting.",
  lore_title="Cold Lines",
  lore_text="Under the ravine runs a pipe as wide as a cart, sweating frost in summer. It comes from the direction of the Citadel and goes toward the Crypt. The forest above it has never once burned.")

# ================================================================ the Cathedral of Ash
S("ca_grate_light", "Under the Drain", "tap", "cathedral", 3, TAP,
  "In the nave, not every light comes from above.",
  (LY, "There is light under the floor. Churches do not keep their lamps under the floor.", "sharp"),
  "Beneath the grate a lamp burns in a clean white corridor, and a stamped pipe runs along its wall.",
  dict(materials={"m_silver": 2}), tell="grate", pos=(2.8, -3.0), spoil=("grate", "drain", "floor"),
  solution="Tap the floor drain with light pulsing under it, right of the path in the nave.",
  lore_title="Under the Drain",
  lore_text="Through the grate: a corridor, swept, lit, and empty. A pipe runs along it, stamped at every joint with the order its vents open in: two, three, one. Above, the faithful lit their candles in whatever order they liked. It did not matter. It was never the candles.")
S("ca_end_of_cylinder", "End of the Cylinder", "listen", "cathedral", 4, WAIT(16),
  "The hymn in the choir loft is not as endless as it sounds.",
  (LY, "It stopped. And then it said a number. Hymns do not end with a number.", "unsettled"),
  "The hymn runs out. In the silence a flat voice reads a batch number and a date, and the hymn begins again.",
  dict(gold=110), spoil=("wait", "stay", "listen", "stand"),
  solution="Stand in the Choir Loft for sixteen seconds without acting.",
  lore_title="End of the Cylinder",
  lore_text="'Devotional cycle nine. Congregation batch forty-one. Play until relieved.' The voice is bored. It is the only voice in the cathedral that sounds like a person at work.")
S("ca_votive_order", "The Vent Cycle", "sequence", "cathedral", 5,
  SEQ([dict(tell="votive_1", pos=(-3.2, -3.0), label="one flame"), dict(tell="votive_2", pos=(-2.4, -4.6), label="two flames"),
       dict(tell="votive_3", pos=(3.0, -3.6), label="three flames")], [1, 2, 0]),
  "A few votive stands are set apart from the hundreds. Something beneath the nave explains them.",
  (LY, "It opened. You lit candles in the right order and a wall opened. I am going to stop calling this a church.", "flat"),
  "The stands dim one after another, and behind the candles a panel slides aside on a shelf of sealed tins of wax.",
  dict(finish="f_votive", gold=120), spoil=("two", "three", "one", "order", "flames"),
  solution="Touch the three votive stands in the order stamped on the pipe under the nave drain: the stand with two flames, then three, then one.")
S("ca_six_cuts", "Six Cuts", "return", "cathedral", 2, TAP,
  "The Cathedral Steps keep a tally that only shows once nobody is standing guard over it.",
  (W, "Six. She cut one for each of them, and kept the blade sharp enough to do it neatly. That is grief with a method.", "quiet"),
  "Six short cuts in the oak, side by side, each made with two blades at once. Under them a seventh has been started and left.",
  dict(materials={"m_silver": 2}), tell="blade", pos=(-3.4, -4.2), when=dict(defeated=["crimson_widow"]), spoil=("cuts", "widow", "door", "blade"),
  solution="After the Crimson Widow has been faced, return to the Cathedral Steps and tap the blade standing in the fallen door-timber on the left.",
  lore_title="Six Cuts",
  lore_text="Six pairs of cuts in the cathedral door, one pair for each soldier she buried. A seventh pair is begun and not finished: one blade only, and shallow. She was counting someone who was not dead yet, and thought better of it.")

# ================================================================ the Sunken Crypt
S("cr_dry_lamp", "Lamp Without Water", "tap", "crypt", 0, TAP,
  "The Drowned Stair is worth walking twice: once wet, once not.",
  (LY, "It burned under the river the whole time. Take it out of the niche. Look at the base.", "intent"),
  "With the water gone one lamp is left burning on bare stone. Its base is stamped with a row of small numbers.",
  dict(materials={"m_silver": 2}), tell="glint", pos=(3.0, -3.6), when=dict(flag="crypt_sluice"), spoil=("lamp", "sluice", "drain"),
  solution="Open the sluice, then walk the Drowned Stair again and tap the lamp left burning low on the right.",
  lore_title="Lamp Without Water",
  lore_text="Not a lamp. A marker: each one stands over a row of the stored and shows, by its colour, how many in the row still answer. This one is amber. The stamp on its base gives the row: forty names. The light says eleven.")
S("cr_whispered_name", "A Name You Answer To", "listen", "crypt", 5, WAIT(18),
  "The reliquary lamp asks nothing. It does, given time, say something.",
  (LY, "It said a name. You turned your head. You turned before I had finished hearing it.", "very quiet"),
  "The lamp murmurs, too low to catch, and then quite clearly says a name. It is not yours. You answer to it anyway.",
  dict(shards=4), spoil=("wait", "sit", "listen", "stay", "name"), rare=True,
  solution="Sit by the reliquary lamp for eighteen seconds without acting.",
  lore_title="A Name You Answer To",
  lore_text="The lamp reads its row aloud when someone sits long enough: the long name of a soldier, the short name of a child, and a third name with a line struck through it. It reads them twice in that order. You know all three the way you know your own hands.")
S("cr_first_winter", "The First Winter", "duel", "crypt", 2, DUEL("first_winter"),
  "The Weeping Tomb remembers a soldier you have already relieved.",
  (LY, "That is him. Before the ash. This is what they stored: the man from the first winter, when he still expected the thaw.", "stricken"),
  "He fights as he did before three hundred years wore him down to a post. Afterwards he looks at his hands, and is gone.",
  dict(trophy="t_winter_token", shards=4), tell="figure", pos=(-3.6, -6.2), when=dict(quest="relief_of_the_gate"), spoil=("relief", "quest", "task", "sentinel"),
  solution="Complete Lyra's task The Relief of the Gate, then return to the Weeping Tomb: a figure in unburnt garrison plate stands at the back. Tap him and win.",
  lore_title="First Winter",
  lore_text="The store kept him as he was the day he volunteered: upright, quick, certain of the thaw. The thing at the gate was what three hundred years made of the body. Nobody ever told either of them about the other.")
S("cr_scratched_drawing", "A Scratched Drawing", "sketch", "crypt", 4, TAP,
  "One of the defaced kings was used as a slate.",
  (W, "A mason's mark, and a mason's secret. They always leave themselves a way back in.", "amused"),
  "Low on the plinth, where the chisel never reached, somebody scratched a picture of a great door and marked one point on it.",
  dict(shards=2), tell="scratch", pos=(3.2, -2.6), spoil=("plinth", "scratch", "effigy"),
  solution="Tap the scratched plinth-stone on the right at the fourth stop of the Crypt (the Royal Vault and the Gallery of Kings).",
  lore_title="Sketch: The Door",
  lore_text="Scratched with a nail: two tall doors standing open, and on the left one, above the lowest hinge, a small circle. Beside the circle the mason has drawn a hand, flat, the way you would press on a thing rather than pull it.")

# ================================================================ the Wyrm's Roost
S("ro_stood_ground", "One Who Stood", "tap", "roost", 0, TAP,
  "The Glass Road ran once. Something in it did not.",
  (W, "Somebody stood here while the road ran like water round their feet. And carried no shield. Look, there is none in the glass.", "grave"),
  "A sword-point is fused upright into the glazed stone, and before it two footprints, set square.",
  dict(gold=150), tell="blade", pos=(-2.9, -3.6), spoil=("blade", "sword", "footprint"),
  solution="Tap the blade fused upright into the road on the left of the Glass Road.",
  lore_title="One Who Stood",
  lore_text="Two footprints in glass and a sword left standing between them. Whoever it was faced the thing on the summit with a blade and nothing else, and held long enough for the stone to cool around their boots. There is no shield in the glass. There is no body either.")
S("ro_answered_whistle", "The Answer", "listen", "roost", 1, WAIT(16),
  "In the Mews a whistle went unanswered. Or so the falconer thought.",
  (LY, "Something answered. From above the cloud. It has been waiting three hundred years for the second note.", "awed"),
  "Long after the falconer's whistle has died, a sound comes down from the summit: one low note, patient, like a question.",
  dict(materials={"m_scale": 2}), spoil=("wait", "stand", "stay", "listen"),
  solution="Stand in the Mews for sixteen seconds without acting.",
  lore_title="The Answer",
  lore_text="The keepers called with two notes: come, and then stand down. Only the first was ever taught to the last falconer. The thing on the summit has been answering 'come' for three centuries and waiting, politely, to be told it may stop.")
S("ro_warm_stone", "Imprint", "carried", "roost", 2, TAP,
  "Something in the Boneyard knows its own.",
  (LY, "It is warm because of what you are wearing. It thinks you are the keeper. Do not tell it otherwise.", "gentle"),
  "The nest-stone warms under your hand, and something small and ember-bright rolls out from under it to your feet.",
  dict(materials={"m_scale": 3}), tell="ember", pos=(2.7, -2.8), when=dict(equipped="r_brood"), spoil=("ring", "ember", "brood", "wear", "worn"),
  locked_text="A hollowed stone among the bones, faintly warm. It does nothing for you as you are.",
  solution="Wear the Broodmother's Ember (from the Clutch, or the wyrm) and tap the glowing nest-stone on the right of the Boneyard.",
  lore_title="Imprint",
  lore_text="The young were taught to know one keeper by a mark carried on the hand, and to bring that keeper the first thing they ever killed. The stone is where they left it. What the whelp has left here is very old, and was a rat.")
S("ro_no_shield", "Unshielded at the Summit", "mastery", "roost", 6, FEAT("noshield:cinder_wyrm"),
  "Someone once faced the summit with less than you carry.",
  (W, "As the one in the glass did. I shall record that it was done twice, and that the second walked down again.", "level"),
  "The sky is very large, and you met it with a blade and nothing else.",
  dict(trophy="t_glass_footprints", title="ti_unshielded"), spoil=("shield", "without", "two-handed"),
  solution="Defeat the Cinder Wyrm with no shield equipped.")

# ================================================================ the Frozen Citadel
S("ci_still_counting", "Still Counting", "listen", "citadel", 0, WAIT(16),
  "Of the Frozen Rank, more than one is breathing.",
  (LY, "The third from the end. Its lips are moving. It is counting the watch. It thinks it is still the same night.", "low"),
  "One of the rimed soldiers turns its head a finger's width toward you, and its breath shows, once.",
  dict(materials={"m_rime": 2}), spoil=("wait", "stand", "stay", "watch"),
  solution="Stand before the Frozen Rank for sixteen seconds without acting.",
  lore_title="Still Counting",
  lore_text="The rank was ordered to hold the pass until the gates were opened from inside. The gates were frozen shut from inside the same hour. One of them has counted every change of the watch since, aloud, so the others would know they had not been forgotten.")
S("ci_reflection", "Twice Yourself", "duel", "citadel", 1, DUEL("reflection"),
  "On the Wall Walk somebody practised alone for an age. Ask what against.",
  (LY, "That is a Recall surface. It is not showing you. It is playing you back.", "tense"),
  "It has your stance, your reach, and your habit of dropping the point. When it breaks, it breaks exactly the way you would.",
  dict(title="ti_twice", shards=4), tell="ice", pos=(-3.4, -5.6), when=dict(defeated=["rime_duelist"]), spoil=("ice", "mirror", "reflection", "duelist", "duellist"),
  solution="After beating the Rime Duelist, return to the Wall Walk and tap the slab of black ice standing on the left. Beat the reflection that steps out of it.",
  lore_title="Recall Surface",
  lore_text="A sheet of black ice that is not ice. The Everbound used such surfaces to rehearse: it stores whoever stands before it and gives them back as an opponent. The duellist on the wall had been losing to himself, narrowly, for three hundred years.")
S("ci_queens_pane", "The Queen's Pane", "tap", "citadel", 5, TAP,
  "In the Solar everything is flowered with frost. Check that.",
  (W, "She kept one pane clear with her own hand, every morning, to watch the pass. I remember thinking it a waste of a queen's time.", "regretful"),
  "One pane is clear, and warm. On the sill beneath it lies a pot of pale grease, still soft.",
  dict(finish="f_hoarfrost"), tell="pane", pos=(2.6, -3.2), spoil=("pane", "clear", "window", "warm"),
  solution="Tap the one clear, faintly lit pane propped on the right in the Solar.",
  lore_title="The Queen's Pane",
  lore_text="She refused the king's order to seal the gates, and was overruled. After that she cleared one pane each morning and watched the soldiers in the pass go white. The pane has stayed clear. Nothing in the Citadel explains why.")
S("ci_every_answer", "Every Answer Exact", "mastery", "citadel", 6, FEAT("perfect:frostbound_king"),
  "The Winter King can be refused without a single flaw.",
  (LY, "Every single one. You did not turn one blow early or late. He looked almost relieved.", "breathless"),
  "Not one parry early, not one late. The frost on the throne cracks along a single clean line.",
  dict(trophy="t_split_frost", title="ti_exact"), spoil=("parry", "parries", "perfect", "timed"),
  solution="Defeat the Frostbound King with at least three parries, every one of them perfect.")

# ================================================================ the Hollow Deep
S("de_three_plates", "The Seventh Plate", "sequence", "deep", 1,
  SEQ([dict(tell="plate_long", pos=(-3.4, -3.4), label="long"), dict(tell="plate_struck", pos=(2.6, -2.8), label="struck"),
       dict(tell="plate_short", pos=(3.6, -4.8), label="short")], [0, 2, 1]),
  "Names have fallen from the Gallery wall. Somewhere above, they are still being read aloud.",
  (LY, "There were six who made you. This says seven. The seventh plate has no name on it. It has a date, and the date is the day you woke.", "shaken"),
  "The three plates settle, and behind the place they fell from, a seventh is set in the wall. It is blank but for a date.",
  dict(shards=6), spoil=("long", "short", "struck", "order", "lamp", "three"), rare=True,
  solution="Touch the three fallen plates in the order the Crypt's reliquary lamp reads its names: the long plate, the short plate, the struck plate.",
  lore_title="The Seventh Plate",
  lore_text="Six donor plates in the Crypt, and here, where the Crown sent what it had no use for, a seventh: fixed to the wall, polished, and blank. The date on it is not three hundred years old. Somebody added a seventh giver to the Unbound on the morning the chamber opened, and left the name for later.")
S("de_candle_bearer", "Who Carried It", "carried", "deep", 3, TAP,
  "The Last Candle was set down by someone. One of your companions could say who.",
  (W, "I know that hand. She carried it down herself, when she could still carry. Lyra, you were told you had never left the sanctuary.", "careful"),
  "In the wax at the candle's foot is the print of a thumb, small, pressed in while it was warm.",
  dict(gold=260), tell="candle", pos=(-2.6, -2.6), when=dict(witness=True), spoil=("witness", "thumb", "wax"), rare=True,
  solution="With the Witness found, tap the small cold candle on the left at the fourth stop of the Deep (Mark the Way and the Last Candle).",
  lore_title="Who Carried It",
  lore_text="The candle on the unlit stair is the sanctuary's, and the thumbprint in its wax is a living hand's. Lyra remembers no body and no stair. The Witness remembers a woman going down with a light, and coming up without it, and being asked to forget which.")
S("de_unhurried", "A Moment's Peace", "oddity", "deep", 5, WAIT(22),
  "The Emptied Place has no treasure. It has something, for the patient.",
  (LY, "Nothing happened. I checked twice. I think that may be the first time since you woke.", "almost laughing"),
  "You wait. Nothing comes. Nothing wants anything. After a while you notice you have been standing easy.",
  dict(title="ti_unhurried", heal=True), spoil=("wait", "stand", "stay", "seconds"),
  solution="Stand in the Emptied Place for twenty-two seconds without acting.")

# ================================================================ the Hollow Throne
S("th_unfinished_statue", "The Unfinished Statue", "tap", "throne", 0, TAP,
  "On the Royal Mile every monarch's face was struck off. Count the monarchs, then the faces.",
  (W, "That one was never defaced. It was never carved. They left a plinth for whoever came next, and nobody did.", "dry"),
  "The last statue has no chisel marks. Its face was left smooth, waiting, and there is no name on the plinth.",
  dict(gold=220), tell="bust", pos=(3.2, -3.8), spoil=("statue", "smooth", "blank", "plinth"), rare=True,
  solution="Tap the small pale bust with a smooth, unbroken face on the right of the Royal Mile.",
  lore_title="The Unfinished Statue",
  lore_text="A reserved plinth at the end of the line of kings, with a blank head roughed out and no name cut. The dust on it is three hundred years deep, except for one clean hand-width on the shoulder, at the height of somebody who cannot reach very far.")
S("th_parade_sword", "The Parade Sword of the Ninth Jubilee", "oddity", "throne", 1, TAP,
  "The Treasury was emptied by people with taste. They left one thing.",
  (W, "I was present when it was presented. The applause was the bravest thing I ever saw at court.", "very dry"),
  "It is enormous, gilded, and enamelled with the faces of nine kings. It could not cut bread. Three hundred years of looters have walked past it.",
  dict(trophy="t_parade_sword"), tell="gaudy", pos=(-2.8, -3.0), spoil=("sword", "gilt", "gilded", "enamel"),
  solution="Tap the gaudy gilt sword propped on the left in the Antechamber.",
  lore_title="The Parade Sword of the Ninth Jubilee",
  lore_text="Commissioned by a guild that wished to be noticed, at a weight no arm could lift twice. The blade is soft gold over softer iron; the hilt has nine enamelled royal portraits, two of them of the same king. It was carried in one procession, by four men. Orren, shown it, was silent for some time and then asked to be left alone with his anvil.")
S("th_hinge_plate", "The Hinge Plate", "sketch", "throne", 5, TAP,
  "A mason who worked on the throne room left a drawing of it a long way from here.",
  (W, "The left door, above the low hinge. Press, do not pull. Masons. I told you.", "satisfied"),
  "The plate above the hinge gives under a flat hand. Behind it is the builders' own tally of who came through.",
  dict(finish="f_regal_black", shards=3), tell="hinge", pos=(-3.0, -3.4), when=dict(secret="cr_scratched_drawing"), spoil=("hinge", "press", "plate"), rare=True,
  locked_text="A dull plate set low on a fallen door-leaf. It means nothing to you yet.",
  solution="Holding the scratched drawing from the Crypt, tap the dull plate on the left at the throne room doors.",
  lore_title="The Hinge Plate",
  lore_text="Behind the plate the masons kept a count of everyone who walked through the throne doors and did not walk back: a scratch for each. There are a great many scratches. The last seventeen are in a neat row of their own, each one the same height as you.")
S("th_cycle_count", "The Cycle Count", "cycle", "throne", 3, TAP,
  "The King's private door looks different to someone who has already seen how this ends, more than once.",
  (LY, "That mark was not there the first time. Or it was, and you could not see it yet. I do not know which frightens me more.", "unsteady"),
  "A line of small cuts beside the door, at eye height, and a fresh one at the end. It is made with the edge you are carrying.",
  dict(trophy="t_cycle_tally", title="ti_twice_walked", shards=8), tell="blade", pos=(2.8, -2.6), when=dict(ng_min=1, endings_min=2), rare=True,
  spoil=("ending", "endings", "new game", "cycle", "again"),
  solution="See two different endings, begin a New Game Plus, and return to the King's Door in the Throne: tap the blade standing by it on the right.",
  lore_title="The Cycle Count",
  lore_text="Somebody has been marking the wall by the King's door each time they reached it. The cuts are old at one end and bright at the other, and all of them were made by the same hand at the same height. The Gravewarden's record said you were the first the chamber permitted to leave. It did not say you were the first to arrive.")

# ================================================================ hidden challengers (existing rigs and models, retuned)
CHALLENGERS.update({
 "second_salute": dict(base="banneret", name="The Second Salute", title="Posted for Guests", hp=1.3, speed=1.12, xp=1.6, gold=1.6,
    traits={"parry_open": 1.3, "dodge_open": 0.6}, rig={"metal": "#c8ccd4", "cloth": "#e8e4d8", "eye": "#ffe2a0"}),
 "first_winter": dict(base="ashen_sentinel", name="The Sentinel, First Winter", title="As He Was Stored", hp=0.6, speed=1.1, xp=0.6, gold=0.6,
    traits={"parry_open": 1.2}, rig={"metal": "#8a8c90", "cloth": "#5a1616", "eye": "#bfe6ff"}, model="ashen_sentinel", phases=1),
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
M("orren_silver", "Silver for the Dead's Edge", "Orren",
  "Grave Silver takes an edge nothing else will. Bring Orren five pieces and he will finish a blade he has had on the bench since before you woke.",
  dict(materials={"m_silver": 5}), dict(gold=100, shop=["w_crypt_great"]),
  "\"There. It is not for sale to anybody. It is for sale to you.\" A long shape lies on the bench under a cloth.", after=dict(cleared="blackwood"))
M("orren_both_hands", "Both Hands, Once", "Orren",
  "Orren says nobody understands a greatsword until it has nearly pulled them over. Win two fights with one.",
  dict(feats={"win_cls:greatsword": 2}), dict(gold=250, materials={"m_iron": 3}),
  "\"And now your shoulders know why I charge more for them.\"", after=dict(cleared="courtyard"))
M("orren_as_far", "As Far As It Goes", "Orren",
  "Take one blade as far as the forge can take it: every blade tier, the full grip, and a cored ore. Orren wants to see it finished, once, in his lifetime.",
  dict(maxed="weapon"), dict(gold=500, title="ti_orrens_proof"),
  "He holds it to the light and then hands it back hilt first. \"My grandmother would have called that a prayer answered. I call it paid for.\"", after=dict(cleared="cathedral"))
M("lyra_carry_light", "Carry the Light", "Lyra",
  "Somebody carried a sanctuary candle as far down as the unlit stair in the Deep. Lyra asks you to carry another there, so the first is not alone. Wear the Sanctuary Candle when you reach the Last Candle.",
  dict(feats={"carry:x_candle:deep:3": 1}), dict(gold=400, shards=6),
  "Two lights on the stair now. \"Thank you,\" Lyra says. \"I do not know why that mattered so much. I will think about why.\"", after=dict(cleared="citadel"))
M("lyra_courtyard", "What the Courtyard Hid", "Lyra",
  "Lyra's plans of the Fallen Courtyard are three hundred years out of date. Find three things there that are on no plan she holds.",
  dict(secrets_in={"courtyard": 3}), dict(gold=150, shards=2),
  "\"Three. On a ground I thought I knew stone by stone. I am going to have to look at everything again.\"")
M("lyra_stand_still", "Stand Still", "Lyra",
  "You walk through places as if they were only on the way. Lyra asks you, three times, somewhere on the road, simply to stay and listen until the place has finished speaking.",
  dict(feats={"listened": 3}), dict(finish="f_dusk", gold=120),
  "\"You heard them. Most people leave before a place has finished.\"")
M("lyra_without_mark", "Without a Mark", "Lyra",
  "Lyra watches every blow that lands on you and can do nothing about any of them. Win three fights without being struck, as a kindness to her.",
  dict(feats={"flawless_wins": 3}), dict(gold=300, shards=4),
  "\"Three times I did not have to look away. I had forgotten what that was like.\"")
M("lyra_niches", "Count the Niches", "Lyra",
  "There are more niches in the Sunken Crypt than the kingdom ever had dead. Recover every record the Crypt's road holds, so the count can be made properly.",
  dict(lore_in={"crypt": 7}), dict(gold=350, shards=5),
  "Lyra reads the count back to you, slowly. It is not a number of graves. It is a number of people.", after=dict(cleared="cathedral"))
M("witness_record", "For the Record", "The Witness",
  "The Witness wrote down what he was told to for a lifetime. Bring him ten things nobody told anyone to write down.",
  dict(secrets=10), dict(title="ti_corrector", gold=300),
  "\"Ten corrections. The record is still a disgrace, but it is now a disgrace with footnotes.\"", after=dict(witness=True))
M("witness_answer", "A Proper Answer", "The Witness",
  "The Witness holds that a parry made at exactly the right moment is the only honest sentence in fencing. Make twenty-five of them.",
  dict(feats={"perfect_parries": 25}), dict(gold=250, shards=4),
  "\"Twenty-five. I counted. It is what I do.\"", after=dict(witness=True))
M("witness_tellings", "Two Tellings", "The Witness",
  "The Witness will not say what you should do with the Crown. He would like to see, for the record, two of the things that can be done with it.",
  dict(endings=2), dict(finish="f_ledger", shards=6),
  "\"I have now seen it end twice and neither was the one I was ordered to write. Good.\"", after=dict(witness=True, cleared="throne"))
M("found_unscored", "The Unscored Rows", "A strip of hide",
  "Three rows on the Huntsman's tally were never scored through. Put down the knuckle-walker in the Blackwood, the crawler in the Crypt and the white beast of the Citadel's great stair. They are not always on the road: look for them.",
  dict(defeated=["maulbeast", "crypt_crawler", "hoarbeast"]), dict(gold=400, materials={"m_scale": 2}),
  "You score the three rows through yourself. The knife is still sharp.", after=dict(secret="bw_last_row"))
M("found_muster", "Answer the Roll", "The garrison roll",
  "The muster nailed in the guardhouse lists five kinds of soldier 'posted'. Meet each of them once on the Courtyard's roads, so that somebody has answered the roll.",
  dict(defeated=["hollow_soldier", "banneret", "rampart_brute", "pike_sergeant", "gate_colossus"]), dict(gold=200, materials={"m_iron": 4}),
  "Five names answered. The ink of the sixth, the sergeant's, has not changed. It was never going to.", after=dict(lore="garrison_roll"))
M("found_handbell", "Ring It Where It Rang", "A cracked handbell",
  "The handbell the Beast kept was the choir-master's. Carry it back up to the Choir Loft, where the hymn is still running without him.",
  dict(feats={"carry:x_bell:cathedral:4": 1}), dict(gold=300, shards=4),
  "You ring it once. The recording falters for half a beat, as if somebody had looked up.", after=dict(defeated="cathedral_beast"))

# ================================================================ completion
COMPLETION = dict(
 weights=dict(stops=15, guardians=12, secrets=15, missions=10, lore=10, gear=15, mods=3, masteries=8, combos=5, endings=5, challenges=2),
 region_weights=dict(stops=30, guardians=20, secrets=25, lore=15, gear=10),
 names=dict(stops="Stops walked", guardians="Guardians ended", secrets="Secrets found", missions="Tasks done", lore="Records recovered",
            gear="Arms and armour held", mods="Forge work finished", masteries="Masteries", combos="Sequences found", endings="Endings seen",
            challenges="Challenges met"),
 hints=dict(stops="A stretch of this road has not been walked on foot.", guardians="Something here has not been faced.",
            lore="A record on this road is unread.", gear="Something made or carried here is not yet yours.",
            missions="A task in the Journal is unfinished.", mods_weapon="No blade has been taken as far as the forge can take it.",
            mods_shield="No shield has been worked to its last tier.", mods_armour="No piece of armour has been worked to its last tier.",
            masteries="Some kind of weapon, shield or harness is still unfamiliar to your hands.", combos="A sequence of the blade is unfound.",
            endings="The Crown has been dealt with in fewer ways than there are.", challenges="A mastery challenge stands open."),
 exclude_items=[])

FINISHES = {"f_charcoal": "Soldier's blacking", "f_votive": "Votive wax", "f_hoarfrost": "Hoarfrost", "f_regal_black": "Throne-door black",
            "f_oiled": "Oiled black", "f_dusk": "Dusk grey", "f_ledger": "Ledger ink",
            "f_quarter": "Road-worn", "f_half": "Field-dressed", "f_three_quarter": "Veteran's polish", "f_complete": "Unbound gilt",
            "f_courtyard": "Garrison grey", "f_blackwood": "Park green", "f_cathedral": "Ash white", "f_crypt": "Grave silver",
            "f_roost": "Cinder red", "f_citadel": "Rime blue", "f_deep": "Hollow violet", "f_throne": "Royal ochre"}
TROPHIES = {
 "t_second_candle": ("The Second Candle", "A light that came by itself after the gate lost its keeper."),
 "t_clean_tabard": ("An Unmarked Tabard", "Worn against the Ashen Sentinel. Not a thread out of place."),
 "t_trimmed_wick": ("A Trimmed Wick", "From the lamps of a road nobody finished."),
 "t_winter_token": ("First-Winter Token", "A garrison tally-disc, unburnt. One winter is stamped on it."),
 "t_glass_footprints": ("Cast of Two Footprints", "Taken from the glazed road under the Roost."),
 "t_split_frost": ("A Shard of the Winter Throne", "It broke along one clean line."),
 "t_parade_sword": ("The Parade Sword of the Ninth Jubilee", "Too ugly to steal. Hung where Orren does not have to look at it."),
 "t_cycle_tally": ("A Rubbing of the Tally", "The marks by the King's door, in charcoal. All in one hand."),
 "t_quarter": ("A Road Stone", "From the first mile. Everyone starts with one."),
 "t_half": ("A Half-Burned Map", "Lyra's plan of the kingdom, with your corrections."),
 "t_three_quarter": ("The Witness's Pen", "He says he will not need it for a while."),
 "t_complete": ("The Empty Plinth", "A plinth with no statue. There is nothing left to put on it that you have not seen."),
 "t_courtyard": ("Winch Pawl", "The Fallen Courtyard, known stone by stone."), "t_blackwood": ("Cold Lantern", "The Blackwood, known tree by tree."),
 "t_cathedral": ("Hymn Cylinder", "The Cathedral of Ash, known to its drains."), "t_crypt": ("Row Marker", "The Sunken Crypt, known name by name."),
 "t_roost": ("Keeper's Whistle", "The Wyrm's Roost, known to the summit."), "t_citadel": ("Clear Pane", "The Frozen Citadel, known in every room."),
 "t_deep": ("Lead Box", "The Hollow Deep, known to the bottom."), "t_throne": ("Mason's Nail", "The Hollow Throne, known behind its doors."),
}
TITLES = {"ti_answered": "the Answered", "ti_unmarked": "the Unmarked", "ti_unshielded": "the Unshielded", "ti_twice": "Twice Yourself",
          "ti_exact": "the Exact", "ti_unhurried": "the Unhurried", "ti_twice_walked": "the Twice-Walked", "ti_orrens_proof": "Orren's Proof",
          "ti_corrector": "Corrector of the Record", "ti_wayfarer": "Wayfarer", "ti_surveyor": "Surveyor of Ruins", "ti_archivist": "Keeper of the True Record",
          "ti_complete": "the Unbound, Entire"}
REGIONS = ["courtyard", "blackwood", "cathedral", "crypt", "roost", "citadel", "deep", "throne"]
MILESTONES = [
 dict(id="all_25", scope="overall", at=25, reward=dict(finish="f_quarter", trophy="t_quarter", title="ti_wayfarer")),
 dict(id="all_50", scope="overall", at=50, reward=dict(finish="f_half", trophy="t_half", title="ti_surveyor")),
 dict(id="all_75", scope="overall", at=75, reward=dict(finish="f_three_quarter", trophy="t_three_quarter", title="ti_archivist")),
 dict(id="all_100", scope="overall", at=100, reward=dict(finish="f_complete", trophy="t_complete", title="ti_complete")),
] + [dict(id="region_" + r, scope=r, at=100, reward=dict(finish="f_" + r, trophy="t_" + r)) for r in REGIONS]

# ---------------------------------------------------------------- checks
ids = [s["id"] for s in SECRETS]
assert len(ids) == len(set(ids)) and 25 <= len(ids) <= 40, len(ids)
for s in SECRETS:
    assert s["region"] in REGIONS and 0 <= s["stage"] <= 6, s["id"]
    low = s["hint"].lower()
    assert s["solution"] and s["solution"].lower() not in low and s["name"].lower() not in low, s["id"]
    for w in s["spoil"]:
        assert w.lower() not in low, (s["id"], w)
    r = s["reward"]
    assert r.get("finish", "f_dusk") in FINISHES and r.get("trophy", "t_half") in TROPHIES and r.get("title", "ti_twice") in TITLES, s["id"]
    w = s.get("when", {})
    assert w.get("secret", ids[0]) in ids, s["id"]
    if s["trigger"]["type"] == "duel":
        assert s["trigger"]["challenger"] in CHALLENGERS
    if s["trigger"]["type"] in ("tap", "duel"):
        assert s.get("tell") and s.get("pos"), s["id"]
assert len({m["id"] for m in SIDE}) == len(SIDE) and 12 <= len(SIDE) <= 20
for m in SIDE:
    r = m["reward"]
    assert r.get("finish", "f_dusk") in FINISHES and r.get("title", "ti_twice") in TITLES, m["id"]
for m in MILESTONES:
    assert m["reward"]["finish"] in FINISHES and m["reward"]["trophy"] in TROPHIES
assert sum(COMPLETION["weights"].values()) == 100 and sum(COMPLETION["region_weights"].values()) == 100

json.dump(dict(secrets=SECRETS, challengers=CHALLENGERS, completion=COMPLETION, milestones=MILESTONES, finishes=FINISHES,
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
