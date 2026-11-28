#!/usr/bin/env python3
"""Authoring script for data/dialogue.json: every spoken line, its speaker and
direction, and the scenes that string lines together. Player lines are voiced
twice (male and female); the game picks by the chosen knight."""
import json
L = {}; S = {}
def scene(sid, *lines, once=True, new=False, title="", kind="", essential=False):
    """new=True marks every line as not recorded: the game shows the subtitle and plays no file,
    even if an older take with the same id is still on disk."""
    ids = []
    for i, (who, text, *rest) in enumerate(lines):
        lid = "%s_%02d" % (sid, i + 1)
        L[lid] = {"speaker": who, "text": text, "dir": rest[0] if rest else ""}
        if who == "forebear":
            # the first of the house speaks with the body of the lineage, exactly as the knight does: the game picks
            # <line>_m / <line>_f for speaker "player". "cast" tells tools/voices.py whose voice records it.
            L[lid].update(speaker="player", cast="forebear")
        elif who == "player" and sid in HEIR_SCENES:
            L[lid]["cast"] = "heir"
        if who == "player" and sid in ONE_BODY:
            L[lid]["body"] = ONE_BODY[sid]      # only ever said by this body: one take, not two
        if who == "kept":
            L[lid]["by_body"] = True            # takes exist as <line>_m / <line>_f; <line>.ogg is the male one (see VOICE_BIBLE)
        if new:
            L[lid]["recorded"] = False
        ids.append(lid)
    S[sid] = {"lines": ids, "once": once}
    if title:
        S[sid]["title"] = title
    if kind:
        S[sid]["kind"] = kind
    if essential:
        S[sid]["essential"] = True
N, LY, P, OR, AR, W = "narrator", "lyra", "player", "orren", "archivist", "witness"
# Generation III's own scenes: the knight's lines in them are the Last Heir's (cast heir_m / heir_f), not the second generation's.
HEIR_SCENES = ["gen3_arrive", "kept_approach", "kept_intro", "kept_beat", "monarch_g3_intro", "monarch_g3_death", "facility",
               "ending_silence", "ending_steward", "ending_cities"]
ONE_BODY = {"gen2_arrive_m": "m", "gen2_arrive_f": "f"}

# ---------------------------------------------------------------- opening
scene("opening",
 (N, "Once, men begged the gods to spare them from death.", "slow, grave"),
 (N, "Then men became gods.", "quiet awe"),
 (N, "They built bodies that could not grow old. Thrones that could not be inherited. Kingdoms that could not escape them.", "measured"),
 (N, "Eternity did not save them from the people they ruled.", "harder, level; no rise at the end"),
 (N, "Their crowns fell. For three hundred years, we believed ourselves free.", "elegiac; a breath after 'fell', almost warm on 'free'"),
 (N, "We were wrong.", "near whisper"))
scene("awakening",
 (LY, "Can you hear me?", "tentative, through old machinery"),
 (P, "Who are you?", "hoarse, just woken"),
 (LY, "Someone who has been waiting a very long time.", "relief held back"),
 (P, "What happened here?", "wary"),
 (LY, "That depends. What do you remember?", "careful"),
 (P, "I remember dying here. But it wasn't me.", "low, unsettled, not dramatic; a pause before 'But'"),
 (LY, "Then it worked.", "quiet wonder"))
scene("first_road",
 (LY, "The doors above you open onto what was a fortress. Walk. Your body remembers how, even if you don't.", "gentle"),
 (LY, "Tap where you want to go. If something stands in the way, it has been standing there a long time.", "dry"))
# ---------------------------------------------------------------- chapter I: the courtyard
scene("courtyard_0", (LY, "Those statues were kings once. People prayed to them. Some of them answered.", "low"))
scene("courtyard_1", (LY, "Look beneath the armour. There's still light. Something was keeping it alive.", "uneasy, precise; slows on 'still light'"))
scene("courtyard_2", (LY, "It salutes before it strikes. Somebody drilled it. The drill is all that is left.", "precise, unsettled; flat and slow on the last sentence"))
scene("courtyard_3", (LY, "The winch should hold. Strange how much of their work still does.", "matter of fact, then quieter; curious, uneasy"))
scene("courtyard_4", (LY, "That one was built to break gates. When it swings, move aside.", "quick, low; plain advice"))
scene("courtyard_5", (LY, "Rest. That candle is not a candle, but it will not hurt you.", "soft"))
scene("courtyard_6", (LY, "He is still at his post. He has not been told that there is nothing left behind him.", "sad"))
scene("sentinel_intro",
 ("sentinel", "State your allegiance.", "flat, immense, helmeted"),
 (P, "I serve no crown.", "steady"),
 ("sentinel", "Then you have no passage.", "final"))
# ---------------------------------------------------------------- the generations (docs/GENERATIONAL_CAMPAIGN_BRIEF.md)
# Generation I (src/cine/prologue.gd) and the second generation's arrival (src/cine/arrival.gd). Text only: nothing here is
# recorded. "forebear" is the first of the house (the Father, or the Mother in a woman's lineage): the same words either way.
FB = "forebear"
scene("gen1_open",
 (N, "For centuries the bells of Vaelora rang beneath the same sovereign.", "slow, grave"),
 (N, "Harvests failed and were mended. Villages fell silent and were forgotten. Upon the throne, nothing changed.", "measured"),
 (N, "One warden of the low road dared to ask what such permanence had cost.", "quieter"), once=False, new=True)
scene("gen1_throne",
 (FB, "Three villages have fallen silent. Their names are struck from your records.", "level, not afraid"),
 ("monarch", "Their silence has bought another winter for thousands.", "regal, unhurried"),
 (FB, "You speak of people as though they were coin.", "hard"),
 ("monarch", "A ruler must count what others refuse to count.", "patient"), once=False, new=True)
scene("gen1_guard", ("monarch", "Show the warden to the gate.", "bored, final"), once=False, new=True)
scene("gen1_records",
 (FB, "The count is behind that seal. I did not climb this far to be told the sum.", "moving already"),
 ("monarch", "Then you climbed for nothing.", "rising"), once=False, new=True)
scene("gen1_seal",
 ("monarch", "Enough. Seal the hall.", "cold"),
 ("monarch", "You have done nothing but leave this burden to another.", "almost pity"),
 (FB, "Then another will come better prepared.", "failing, certain"), once=False, new=True)
scene("gen1_close_m", (N, "His name disappeared from the royal histories.", "elegiac"), (N, "But not from those of his house.", "near whisper"), once=False, new=True)
scene("gen1_close_f", (N, "Her name disappeared from the royal histories.", "elegiac"), (N, "But not from those of her house.", "near whisper"), once=False, new=True)
scene("gen2_arrive_m", (P, "I know where you died, Father. I would know why.", "low, to the gate"), once=False, new=True)
scene("gen2_arrive_f", (P, "I know where you died, Mother. I would know why.", "low, to the gate"), once=False, new=True)
# ---- the second meeting, the second fall, and the Last Heir (docs/CAMPAIGN_SCRIPT.md "Generation II: what changes", "Generation III").
# Text only. Staged by src/main.gd, src/cine/second_fall.gd, heir_return.gd, kept_scene.gd, aftermath.gd, facility.gd.
scene("monarch_blade", ("monarch", "That blade. I had wondered when I would see it again.", "quiet, to the sword, not to its bearer"), new=True)
scene("gen2_seal_burns", (LY, "The seal behind the throne is burning. What the first of your house could not carry out is still in it.", "urgent, held down"), once=False, new=True)
scene("monarch_restored", ("monarch", "You see the difficulty. I am not the thing that is keeping me.", "rising, almost apologetic"), once=False, new=True)
scene("gen2_seal",
 (P, "All these years I thought I had come for your life.", "at the seal, back to him"),
 ("monarch", "And what have you found instead?", "level"),
 (P, "The means to end your reign.", "certain"), once=False, new=True)
scene("gen2_close", (N, "The second of that house fell beneath the same throne.", "elegiac"),
 (N, "But where the first had left a question, this one left an answer.", "near whisper"), once=False, new=True)
scene("gen3_arrive",
 (LY, "Three of your house have stood before those gates.", "far off, through old machinery"),
 (P, "And how many returned?", "young, flat"),
 (LY, "Not enough.", "plain"),
 (P, "Then show me another way.", "quiet"), once=False, new=True)
scene("gen3_engine", (LY, "I kept all of it. I could not keep them.", "low"), once=False, new=True)
scene("kept_approach",
 (W, "Stop. Do not go in yet.", "sharp, for once"),
 (P, "It is one guardian.", "impatient"),
 (W, "It is the walk. I kept station at that shoulder for a year.", "very quiet"), new=True, title="The Walk", kind="guardian", essential=True)
scene("kept_intro",
 ("kept", "State your... no. That was his question.", "a closed helm; a voice the player knows, slowed"),
 (P, "Who were you?", "careful"),
 ("kept", "Late. I was late home.", "as if reading it off something"), new=True)
scene("kept_beat",
 ("kept", "You stand the way I stood.", "mid-fight, without heat"),
 (P, "Someone taught me how you stood.", "breathing hard"), new=True)
scene("kept_after",
 ("kept", "You kept the edge on it.", "looking at the heir's sword"),
 ("kept", "Go on. I have held this gate as long as I was able.", "tired, courteous"),
 (W, "I will set that down as it happened. All of it. Both times.", "barely audible"), once=False, new=True)
scene("monarch_g3_intro",
 ("monarch", "Your family has spent two lifetimes at my gates.", "regal, unhurried"),
 (P, "Three. You are keeping one of them.", "cold"),
 ("monarch", "I keep everything. It is the whole of my office.", "without shame"),
 (P, "And you have mistaken survival for the right to rule.", "steady"),
 ("monarch", "When these machines fall silent, they will remember whom to blame.", "a warning, not a threat"),
 (P, "Then let them remember a choice was made.", "final"), new=True)
scene("final_door", (W, "There is a door. Not from this side of the wall.", "remembering as it speaks"), once=False, new=True)
scene("facility",
 (LY, "This was never merely a kingdom.", "hushed"),
 (P, "Then what was it?", "low"),
 (LY, "A means of keeping one alive.", "plain"), once=False, new=True)
# The three endings, as directed scenes (src/cine/ending_scene.gd). Written for the campaign fix pass from the three
# epilogues the game already had as text; subtitles only, nothing recorded, nobody has reviewed them.
scene("ending_silence",
 (LY, "You know what this ends. I am asking you to do it anyway.", "steady; she has decided"),
 (P, "Three of us came to this door. I will not ask a fourth.", "low"),
 (LY, "Then thank you. It was a long time to be kept.", "almost light"),
 (W, "It is very quiet. I had forgotten that it could be.", "after a silence"),
 (N, "The bells of Vaelora rang that morning for no sovereign at all.", "elegiac"),
 (N, "Outside, the sun came up on people who would die one day, and knew it.", "plain"), once=False, new=True)
scene("ending_steward",
 (P, "Then it answers to me. And I answer to them.", "steady"),
 (LY, "I will be watching. Somebody has to.", "after a long time"),
 (W, "I have seen this seat taken before. Do it differently. I shall be writing it down.", "dry, not unkind"),
 (N, "The third of that house took the seat the first had come to question.", "elegiac"),
 (N, "The lights of the kingdom came on, one district at a time.", "plain"), once=False, new=True)
scene("ending_cities",
 (P, "No one rules it. Not him. Not me.", "steady"),
 (LY, "Then each of us must be asked. Some will stay. Some will ask, very politely, to stop.", "wondering"),
 (W, "A hundred small crowns, none of which can command the others. I did not think I would live to record it.", "moved, hiding it"),
 (N, "They did not break the Crown, and they did not wear it. They divided it.", "elegiac"),
 (LY, "So this is what standing feels like.", "from a doorway, not from the air"), once=False, new=True)
# Generation III's road: a line where the heir first sets foot on each road. Written for this pass, not from the brief;
# nobody has reviewed them. (`<region>_<stop>_g3` is what the companion looks for in the third generation.)
scene("courtyard_0_g3", (LY, "The plate on these is new. He has been replacing what your house broke.", "dry"), new=True)
scene("blackwood_0_g3", (W, "The lanterns were lit when I last came this way. I was at another shoulder.", "level"), new=True, title="Another Shoulder", kind="landmark")
scene("cathedral_0_g3", (LY, "The door under the crossing was on no plan I was given. Neither was I.", "uneasy"), new=True)
scene("citadel_0_g3", (W, "A king who gave up his crown, and the hall is still kept. Habit outlives everything.", "wry"), new=True, title="Habit", kind="landmark")
scene("throne_0_g3", (LY, "Twice this door has opened for your house. Nobody came back through it.", "quiet"), new=True)
scene("deep_0_g3", (LY, "Everything he kept is under here. So am I.", "very quiet"), new=True)
# speech category B: the Sentinel keeps only its challenge and its last words (the retry line was cut)
scene("sentinel_death",
 ("sentinel", "Is the war... over?", "failing, suddenly human"),
 (P, "It ended centuries ago.", "gentle"),
 ("sentinel", "Then why did no one return for me?", "a child's question"))
scene("sentinel_memory",
 (AR, "Record incomplete. Observer lost. Memory retained.", "calm, broken cadence; equal weight on each pair"),
 (AR, "Subject: gate sergeant. Forty-one years in service. Volunteered. Term promised: one winter.", "even, a clerk reading; a small gap before 'one winter'"),
 (LY, "They were people. All of them.", "quiet, not a lecture; then silence"))
scene("sanctuary_return",
 (LY, "You came back by the door this time. I prefer it.", "warm"),
 (LY, "There is a smith here. He does not trust you. He is very good. Let him look at that sword.", "amused"))
scene("orren_intro",
 (OR, "So you're the one she woke. Come here. Let's see what you've brought me.", "Scots, gravel, unhurried; a craftsman sizing up a job"),
 (OR, "That sword's older than my whole line. Mind you don't drop it.", "dry; 'Mind you' a plain warning, not a joke"),
 (OR, "Bring me shards and coin. Your armour remembers its shape. I just remind it.", "matter of fact"))
scene("orren_idle",
 (OR, "A fine blade's no use if you don't know how to care for it.", "to the work, not the knight; plain"), once=False)
# ---------------------------------------------------------------- resurrection (one at random)
for i, t in enumerate(["You returned sooner than I expected.", "Your body has recovered. Your memories are another matter.",
        "You remembered something this time, didn't you?", "The system is learning from you.", "You're becoming someone it cannot predict.",
        "Those memories aren't orders. You don't owe the dead your future."]):
    scene("rebirth_%d" % i, (LY, t, "close, intimate"), once=False)
# ---------------------------------------------------------------- later guardians
scene("executioner_intro", ("executioner", "Your identity is unregistered.", "toneless"), (P, "Your kingdom no longer exists.", "flat"),
      ("executioner", "The law does not require a kingdom.", "certain"))
scene("executioner_death", (LY, "That prison was switched back on from somewhere else. Someone is waking them. On purpose.", "alarmed, controlled"))
scene("huntsman_intro", ("huntsman", "I have hunted what the old kings bred. I know one of their things when I see it.", "cold"), (P, "I am not theirs.", "even"),
      ("huntsman", "They all said that.", "tired"))
# The Widow is mean, mocking and commanding (owner, 2026-11-27; voice Giselle at low stability). Rewritten harsher for that delivery.
scene("widow_intro", ("widow", "That stance! I buried the soldier who taught it. Did he teach you how to die as well?", "contemptuous, loud"), (P, "I've never met you.", "guarded"),
      ("widow", "No. But someone inside you has. Kneel, and I may let that one die quickly.", "mocking, a command"))
scene("widow_death", ("widow", "Enough! You fight like someone I buried. Do not dare pity me.", "breathless, furious"), (LY, "She is yielding. Let her.", "urgent, soft"))
scene("beast_intro", (LY, "That was grown, not born. Do not look for a man inside it.", "tight"))
scene("beast_death", (LY, "They didn't pray here.", "hushed"), (P, "Then what was this place?", "low"), (LY, "A laboratory.", "plain"))
scene("gravewarden_intro", ("gravewarden", "These are not tombs.", "old, patient"), (P, "What are they?", "quiet"),
      ("gravewarden", "People waiting for someone to remember their names.", "tender"))
scene("gravewarden_death", (AR, "You are not the first to enter this chamber. You are merely the first it has permitted to leave.", "calm"),
      (AR, "History has been rewritten seventeen times. Would you prefer the surviving version?", "almost wry"))
scene("frostking_intro", ("frostking", "I watched men become gods. Then I watched gods become machines.", "ancient, weary"),
      (P, "Why didn't you destroy the Crown?", "direct"), ("frostking", "Because there were still people inside it.", "simple"))
scene("frostking_retry", ("frostking", "Every resurrection makes the chains harder to break.", "warning"), once=False)
scene("frostking_death", ("frostking", "Go to the capital. Do better than we did. It will not be difficult.", "fading, dry"))
scene("wyrm_intro", (LY, "They built her to break sieges. She has had centuries to decide what else she is.", "awed"))
# the Devourer never makes a speech: layered fragments and whispers only (rewritten 2026-11-26, not recorded)
scene("devourer_intro", ("devourer", "...a daughter... I had...", "a man, lost, under other voices"), ("devourer", "...the sea... the sea...", "a woman, far away"),
      ("devourer", "...my name... what was... my name...", "a child, whispering"), new=True)
scene("devourer_death", ("devourer", "...someone... there...?", "a woman, very small"), (P, "Yes.", "quiet"),
      ("devourer", "...say us... any of us... once...", "many, fading"), (P, "I don't know them. I'm sorry.", "low"), new=True)
scene("monarch_intro", ("monarch", "Look upon what remains of our civilization.", "regal, controlled"),
      (P, "I see a kingdom that should have been allowed to die.", "hard"),
      ("monarch", "And I see children who will never wake if these machines fall silent.", "patient"),
      (P, "How many people have you sacrificed?", "cold"),
      ("monarch", "Enough to ensure there are still people left to ask that question.", "unflinching"))
scene("monarch_retry", ("monarch", "You still believe death cannot teach you surrender.", "almost fond"), once=False)
scene("monarch_death", ("monarch", "I have counted every life this machine has taken. Have you counted the lives it has saved?", "failing"),
      (LY, "I think I remember the rain.", "distant"), (P, "Tell me about it.", "soft"))
# ================================================================ the Witness (companion)
# Everything below is text only: no line has been recorded. src/core/companion.gd decides what plays and when,
# from the tables STAGE / BOSS / TOPICS written out under "companion".
STAGE = {}; BOSS = {}; TOPICS = []
def wstage(region, stage, slug, title, *lines, kind="landmark"):
    sid = "w_%s_%s" % (region, slug)
    scene(sid, *lines, once=False, new=True, title=title, kind=kind)
    STAGE.setdefault(region, {}).setdefault(str(stage), []).append(sid)
def wboss(foe, when, slug, title, *lines, essential=False):
    sid = "w_%s_%s" % (slug, when)
    scene(sid, *lines, once=False, new=True, title=title, kind="boss" if when == "approach" else "victory", essential=essential)
    BOSS.setdefault(foe, {"approach": [], "fallback": [], "victory": []})[when].append(sid)
def topic(slug, title, *lines, after=None):
    sid = "w_talk_" + slug
    scene(sid, *lines, once=False, new=True, title=title, kind="topic")
    TOPICS.append({"id": sid, "after": after} if after else {"id": sid})

# discovery: the Fallen Courtyard, stop 1, under the toppled monument of the thirteen kings
scene("witness_discovery",
 (LY, "Wait. Under the fallen plinth. There is a door there that is on no plan I hold.", "puzzled, wary"),
 (W, "Ah. At last. I had begun to suspect the dead were better company.", "dry, unhurried, from the dark"),
 (P, "What are you?", "guarded"),
 (W, "A witness to rather more than I would care to remember.", "wry"),
 (W, "And rather less than I ought. They cut a good deal out of me before they shut me away.", "lighter than it should be; the smile goes on 'shut me away'"),
 (P, "Who did?", "direct"),
 (W, "If I knew, I should be a happier ornament. Lift me out. I weigh very little, and I know this road.", "brisk; 'Lift me out' a request, never an order"),
 (LY, "I do not know what that is. I do not like not knowing.", "low, to the player"),
 (W, "The voice in the walls disapproves of me. Good. We shall get on.", "amused"),
 once=False, new=True, title="The Witness", kind="discovery", essential=True)

# Stage 1 (docs/AAA_STAGES.md): the Witness is found in the awakening chamber itself, dormant in the maintenance housing
# beside the door, which will not open without it. The recorded discovery lines are reused (02-09); Lyra's opening
# line (the old one names the fallen plinth) and the Witness's two lines on the cradle and the door are new and text
# only until they are recorded. The courtyard scene above stays as the fallback for a save that never saw the chamber.
scene("witness_call",
 (LY, "The door won't open. That device beside it... it isn't on any of my plans.", "puzzled, then wary; slower after the pause, eyes on the device"),
 once=False, new=True, title="The Witness", kind="discovery", essential=True)
scene("witness_chamber",
 (W, "They set me here to watch that cradle. You are what it kept. Let me see you safely out.", "quiet, curious; 'what it kept' plain, not ominous"),
 (W, "This door answers to the old seals. So, as it happens, do I.", "brisk"),
 once=False, new=True, title="The Witness", kind="discovery", essential=True)
_wc = S["witness_chamber"]["lines"]
S["witness_chamber"]["lines"] = S["witness_discovery"]["lines"][1:] + _wc

# The first chest opened in a region (Companion.on_chest; once, never at every chest). Text only until recorded.
CHEST = {}
def wchest(region, title, *lines):
    sid = "w_%s_chest" % region
    scene(sid, *lines, once=False, new=True, title=title, kind="landmark")
    CHEST[region] = sid
wchest("courtyard", "Garrison Issue",
 (W, "Garrison issue. Somebody counted every piece out. I have a terrible feeling it was me.", "dry, peering in; the last clause rueful, not comic"))
# A later attempt at the Sentinel after a fall (duel.gd plays "<voice key>_retry" over the intro card, once): the Witness
# steadies the knight. Not canon: it says nothing of dying. The Sentinel's four lines are all used (category B).
scene("sentinel_retry", (W, "Again, then. Take your time. Watch his blade.", "low, steady; encouragement, not mockery"), new=True)

# ---- the Fallen Courtyard (the Witness is found at stop 1, so its first words on the region come at stop 2)
wstage("courtyard", 0, "approach", "The Fallen Courtyard",
 (W, "So this is what became of the outer court. It had a grander name when it stood. I forget it. Mercifully.", "surveying"), kind="approach")
wstage("courtyard", 3, "gate", "Thirteen Banners",
 (W, "That gate once bore the banners of thirteen kings. Now look at it. Eternity has a peculiar sense of humour.", "dry"))
wstage("courtyard", 4, "passage", "The Narrow Way",
 (W, "They built the passage narrow so that one man could hold it. Nobody asked which man.", "flat"))
wstage("courtyard", 5, "candle", "The Candle",
 (W, "A candle three hundred years alight. In my day we called that a miracle. We were paid to.", "dry"))
wboss("ashen_sentinel", "approach", "sentinel", "Before the Sentinel",
 (W, "He will ask your allegiance. There is no right answer. There never was one.", "quiet"),
 (P, "Then he will have the true one.", "steady"))
wboss("ashen_sentinel", "victory", "sentinel", "One Winter",
 (W, "One winter, they told him. I believe I wrote that order down. I hope I argued.", "troubled, a memory returning"))

# ---- the Blackwood
wstage("blackwood", 0, "approach", "The Blackwood",
 (W, "The Blackwood. The lanterns are still lit. Somebody is paying the lamplighter, and I should like to know in what coin.", "dry"), kind="approach")
wstage("blackwood", 2, "briars", "A Kept Boundary",
 (W, "Woven. Thorn does not plait itself. Somebody here still keeps a boundary.", "noticing"))
wstage("blackwood", 3, "bridge", "The Toll Bridge",
 (W, "There was a toll on this crossing, and a clerk. He counted heads going in. He did not count them coming out.", "a memory, unwelcome"), kind="memory")
wstage("blackwood", 5, "gibbet", "Gallows and Spring",
 (W, "A gallows over the drinking water. There is the old kingdom entire, in one view.", "sour"))
wboss("pale_huntsman", "approach", "huntsman", "He Who Follows",
 (W, "Someone has kept pace with us these three trees. A mortal, by the breathing. Be civil. He has earned his opinions.", "low"))
wboss("pale_huntsman", "victory", "huntsman", "The Hunter's Fear",
 (W, "He was not wrong to fear what we were. Only late.", "tired"))
wboss("hollow_executioner", "approach", "executioner", "The Clearing of Stumps",
 (W, "Every stump a block. He has not stopped working. He has only run short of the condemned.", "grim"),
 (P, "And now?", "flat"),
 (W, "Now he has you. Do try to be a disappointment to him.", "dry"))
wboss("hollow_executioner", "victory", "executioner", "Nobody Told the Axe",
 (W, "The court that passed those sentences was dissolved before your grandmother's grandmother. Nobody told the axe.", "dry, sad"))

# ---- the Cathedral of Ash
wstage("cathedral", 0, "approach", "The Cathedral of Ash",
 (W, "I climbed these steps once, in a procession. I remember the incense. I do not remember what we were asking for.", "a memory, half there"), kind="approach")
wstage("cathedral", 1, "censer", "The Great Censer",
 (W, "A censer that size is not for perfume. It is for covering the smell of something else.", "dry"))
wboss("crimson_widow", "approach", "widow", "The Woman in Red",
 (W, "I know that bearing. Rebels stand straighter than kings. They have to.", "quiet"),
 (P, "She is waiting for me.", "wary"),
 (W, "She is waiting for someone. Find out whom before you draw.", "pointed"))
wboss("crimson_widow", "victory", "widow", "To Yield",
 (W, "She yielded. In my day that took more courage than dying. It still does.", "respect"))
wstage("cathedral", 3, "nave", "The Open Nave",
 (W, "The roof came down in the Rising. I was here. No. I was told I was here. The two are not the same, and I can no longer tell them apart.", "a memory, uncertain"), kind="memory")
wstage("cathedral", 4, "choir", "Forty Verses",
 (W, "Still singing. That hymn has forty verses. I should not stay for the last.", "uneasy"))
wboss("cathedral_beast", "approach", "beast", "Under the Bronze",
 (W, "Stop. Listen. What breathes under that bronze was built in a laboratory.", "low, certain"),
 (P, "What was it built for?", "quiet"),
 (W, "Nothing merciful.", "flat"), essential=True)
wboss("cathedral_beast", "victory", "beast", "The Altar and the Works",
 (W, "A workshop under an altar. I should like to say I am surprised. I think I signed for the candles.", "dry, shaken"))

# ---- the Sunken Crypt
wstage("crypt", 0, "approach", "The Sunken Crypt",
 (W, "Lamps under the water, and burning yet. Do you know, I helped consecrate this place. I cannot recall to whom.", "a memory, dry"), kind="approach")
wstage("crypt", 1, "ossuary", "The Ossuary",
 (W, "Those are for show. The dead that mattered are kept lower down, and a great deal more carefully.", "dry"))
wstage("crypt", 3, "sluice", "The Sluice",
 (W, "Drain it, by all means. But they flooded the lower halls on purpose. One ought always to wonder why.", "warning"))
wstage("crypt", 4, "door", "The Ledger",
 (W, "That door. I have stood before it with a ledger. Names down one column. I cannot see the heading of the other.", "a memory, troubled"), kind="memory")
wboss("gravewarden", "approach", "gravewarden", "The Keeper",
 (W, "The keeper. He is the gentlest thing down here, and he will end you for a careless word.", "low"),   # "kill you" was refused twice by the speech service's filter
 (P, "What does he keep?", "quiet"),
 (W, "Ask him. He has waited long enough to be asked.", "gentle"))
wboss("gravewarden", "victory", "gravewarden", "Every Name",
 (W, "He remembered their names. Every one. I was paid to remember, and I cannot manage my own.", "quiet"))

# ---- the Wyrm's Roost
wstage("roost", 0, "approach", "The Glass Road",
 (W, "Glazed stone. I have seen a wall run like wax before. Never from the outside.", "dry"), kind="approach")
wstage("roost", 1, "mews", "The Mews",
 (W, "They called this the Mews. One learns a great deal about a court from the things it calls small.", "wry"))
wstage("roost", 3, "chain", "The Feeding Lift",
 (W, "A feeding lift. The cage was for cattle. Mostly.", "flat"))
wstage("roost", 4, "shells", "The Tally",
 (W, "Numbered shells. Somebody kept a tally. Somebody always does. It was usually me.", "a memory, rueful"), kind="memory")
wboss("cinder_wyrm", "approach", "wyrm", "Veyrath",
 (W, "There she is. Veyrath. They made her to end sieges, and then they ran out of walls.", "hushed"),
 (P, "Can it be killed?", "level"),
 (W, "Everything can be killed. Convincing it of that is the difficult part.", "dry"), essential=True)
wboss("cinder_wyrm", "victory", "wyrm", "No Orders",
 (W, "She never once took an order. I envied her that. I believe I still do.", "quiet"))

# ---- the Frozen Citadel
wstage("citadel", 0, "approach", "The Frozen Rank",
 (W, "Dressed by the right, and frozen so. Weather has no sense of drill. Somebody gave a last command here.", "grim"), kind="approach")
wstage("citadel", 1, "wall", "The Shut Wall",
 (W, "This wall was never taken. It was closed, from within, and left.", "plain"))
wboss("rimewyrm", "approach", "rimewyrm", "The Thing on the Chain",
 (W, "Something on a chain, down there. A chained thing in a king's cellar is never a pet.", "low"),
 (P, "Then what is it?", "level"),
 (W, "A decision he could not bring himself to make.", "dry"), essential=True)
wboss("rimewyrm", "victory", "rimewyrm", "It Stayed",
 (W, "It could have left at any hour. So could most of us.", "quiet"))
wstage("citadel", 3, "lift", "Manufactured Winter",
 (W, "This cold is made, not fallen. Somewhere beneath us a great deal of effort is spent keeping one man from thawing.", "dry"))
wstage("citadel", 5, "solar", "The Queen's Window",
 (W, "A queen sat at that window. I struck her name from the rolls with my own hand. I was ordered to. I think that is where I began to refuse.", "a memory, hard-won"), kind="memory")
wboss("frostbound_king", "approach", "frostking", "The Winter Throne",
 (W, "I knew him. He is the only one of them who ever asked to stop.", "quiet"),
 (P, "Did they let him?", "direct"),
 (W, "Look at the door. He had to let himself.", "dry"))
wboss("frostbound_king", "victory", "frostking", "The Mark He Set",
 (W, "Do better than we did, he says. He always set the mark where a man might reach it.", "fond, tired"))

# ---- the Hollow Deep
wstage("deep", 0, "approach", "The Long Stair",
 (W, "No. I do not know this stair. I knew every stair they built. Either this was dug afterwards, or it was taken out of me.", "unsettled"), kind="approach")
wstage("deep", 1, "names", "The Gallery of Names",
 (W, "Names, floor to roof. I cut the first of these. That was my office: to set down who a person was, before.", "a memory, plain at last"), kind="memory")
wstage("deep", 3, "stair", "Beneath the Sanctuary",
 (W, "Candle smoke. So this lay under your sanctuary the whole while. Your voice in the walls might have mentioned it.", "pointed"),
 (LY, "I did not know.", "stung"),
 (W, "No. I do not suppose you were permitted to.", "gentler"))
wstage("deep", 4, "oaths", "The Oath Hall",
 (W, "They swore here to keep the stored safe. I administered the oath. It was a good oath. It deserved better men.", "a memory, bitter"), kind="memory")
wboss("devourer", "approach", "devourer", "The Bottom",
 (W, "Do not answer it, whatever it asks. It is not one voice, and not one of them is lying.", "low, urgent"),
 (P, "Who were they?", "quiet"),
 (W, "The ones we lost count of. I begin to think I kept the count.", "ashamed"))
wboss("devourer", "victory", "devourer", "The Rest of the Names",
 (W, "Say what names you have. I will hold the rest, now that I remember how.", "quiet"))

# ---- the Hollow Throne
wstage("throne", 0, "approach", "The Royal Mile",
 (W, "The royal mile. Every face struck off. I approve the sentiment and regret the workmanship.", "dry"), kind="approach")
wstage("throne", 1, "hooks", "Thirteen Hooks",
 (W, "Thirteen banners hung in this room also. Count the hooks, if you doubt me.", "dry"))
wstage("throne", 2, "crown", "What I Would Not Unwrite",
 (W, "There. Now I have it. They did not shut me away for what I knew. They shut me away because I would not unwrite it.", "a memory, whole"), kind="memory")
wstage("throne", 4, "guard", "Unrelieved",
 (W, "Unrelieved. Like the first one you met. It is the same order, you know. Only the handwriting differs.", "quiet"))
wboss("azhurion", "approach", "azhurion", "The Last Wing",
 (W, "That is the first of them. The Last Wing. Nobody wrote down how to stop it. I looked.", "hushed"),
 (P, "Then how?", "level"),
 (W, "The usual way. Slowly, and at great personal cost.", "dry"), essential=True)
wboss("azhurion", "victory", "azhurion", "A Moral Declined",
 (W, "The oldest thing they built, and it ends in a doorway. There is a moral in that. I decline to draw it.", "dry"))
wboss("forgotten_monarch", "approach", "monarch", "A Reasonable Man",
 (W, "He will be reasonable. That is the danger of him. I served reasonable men all my life.", "quiet"),
 (P, "And?", "flat"),
 (W, "And here I drift at your shoulder. What is decided in there is yours to decide. I shall only witness it.", "level"))
wboss("forgotten_monarch", "victory", "monarch", "As It Happened",
 (W, "Whatever you do next, I will set it down as it happened. That much I can still swear to.", "steady"))

# silent foes that already had a line of context from Lyra keep it as the fallback, for when the Witness cannot speak
BOSS["cathedral_beast"]["fallback"] = ["beast_intro"]
BOSS["cinder_wyrm"]["fallback"] = ["wyrm_intro"]
# what Lyra finds after the Beast is the chapter's turn: it plays with or without the Witness
BOSS["cathedral_beast"]["victory"].insert(0, "beast_death")
S["beast_death"]["essential"] = True

# ---- optional conversations in the sanctuary
# ("The Mask" was removed 2026-11-27: the Witness is a free-roaming drone, not a mask carried on the belt.)
topic("sword", "On Old Weapons",
 (P, "This sword. They say it is enchanted.", "doubtful"),
 (W, "It is a tool nobody remembers how to make. That is all an enchantment has ever been.", "dry"),
 (W, "Keep it clean. It will outlast us both, and it knows it.", "wry"))
topic("lyra", "The Voice in the Walls",
 (W, "Your Lyra says she has waited a very long time. Ask her how she knows how long.", "needling"),
 (LY, "I counted.", "cool"),
 (W, "From inside? One cannot count from inside. I tried.", "dry"),
 (LY, "Then we counted differently. I had something to wait for.", "quiet, firm"))
topic("return", "Coming Back",
 (P, "I die, and I wake here. What does that make me?", "low"),
 (W, "Persistent. I would not look for a grander word just yet.", "dry"),
 (W, "I watched men buy that trick with whole kingdoms. You seem to have it on loan. Mind the lender.", "serious"))
topic("smith", "The Smith",
 (P, "Orren does not trust you.", "even"),
 (W, "Sensible. His line kept the old craft alive by trusting nobody in a mask.", "approving"),
 (W, "I should like him, if he would stop looking at my rivets.", "dry"))
topic("kings", "Thirteen Kings", after="courtyard",
 *[(P, "Thirteen kings. Did you know them?", "curious"),
 (W, "I knew eleven. One died too early to matter. One I have been made to forget.", "dry"),
 (P, "Which one?", "direct"),
 (W, "If I could tell you that, they would have done poor work.", "wry")])
topic("people", "They Were People", after="courtyard",
 *[(LY, "They were people. Every one you have cut down.", "quiet"),
 (W, "They were volunteers. That is worse, and she knows it.", "flat"),
 (LY, "They were lied to.", "sharp"),
 (W, "They were. By persons like me, in rooms like this. I merely wrote it down neatly.", "unsparing")])
topic("silence", "The Great Silence", after="blackwood",
 *[(LY, "The Silence came without warning. One night the far towns simply stopped answering.", "remembering"),
 (W, "Nothing that size comes without warning. Somebody was warned. Somebody always is, and thanked, and filed.", "certain"),
 (LY, "There is no record of a warning.", "firm"),
 (W, "No. That is rather my point about records.", "dry")])
topic("prayer", "What We Prayed To", after="cathedral",
 *[(P, "You prayed in that cathedral.", "probing"),
 (W, "I attended. It is not the same. The gods sat in the front pew, taking note of who knelt.", "dry")])
topic("stored", "The Stored", after="crypt",
 *[(LY, "The stored can be saved. All of them. I have to believe that.", "raw"),
 (W, "Believe it, then. I have read the ledgers. Some of those minds were filed already broken.", "gentle, unyielding"),
 (LY, "Broken is not gone.", "fierce"),
 (W, "No. On that, at least, we agree.", "quiet")])
topic("refusal", "The Eighteenth Time", after="citadel",
 *[(W, "It has come back, a little. There was a list. Places, and what was done in them.", "slow"),
 (P, "And you were told to erase it.", "quiet"),
 (W, "Seventeen times they tidied the past, and I held the pen. The eighteenth I would not.", "plain")])
topic("choice", "The Choice Ahead", after="citadel",
 *[(P, "When we reach the capital. What would you do?", "direct"),
 (W, "I shall not tell you. I spent a lifetime telling the powerful that what they wished for was wise.", "level"),
 (W, "Choose. I will see it remembered correctly. It is the only gift I have left.", "quiet")])

# ================================================================ secrets (docs/SECRETS_AND_COMPLETION.md)
# One subtitle line for each secret, said as it is found. The text is authored in tools/gen_secrets.py and read from
# data/secrets.json. Text only: none of these lines has been recorded (new=True), so no file is ever played for them.
import os as _os
if _os.path.exists("data/secrets.json"):
    for _s in json.load(open("data/secrets.json"))["secrets"]:
        scene("sx_" + _s["id"], (_s["say"]["speaker"], _s["say"]["text"], _s["say"].get("dir", "")), once=False, new=True, title=_s["name"], kind="secret")

# ================================================================ who may speak
# A: creatures. No human speech at all; every foe not listed here is A.
# B: guardians that are barely people any more. A few short lines at most.
# C: directed dialogue.   D: the Devourer. Fragments and whispers only.
SPEECH = {"ashen_sentinel": "B", "hollow_executioner": "B", "gravewarden": "B",
 "crimson_widow": "C", "pale_huntsman": "C", "frostbound_king": "C", "forgotten_monarch": "C", "devourer": "D",
 "cathedral_beast": "A", "cinder_wyrm": "A", "rimewyrm": "A", "azhurion": "A"}
FOE_VOICE = {"ashen_sentinel": "sentinel", "hollow_executioner": "executioner", "pale_huntsman": "huntsman", "crimson_widow": "widow",
 "gravewarden": "gravewarden", "frostbound_king": "frostking", "devourer": "devourer", "forgotten_monarch": "monarch"}
# the Kept (Generation III, built from the second generation's snapshot): very few words, in a voice the player knows
SPEECH["the_kept"] = "C"
FOE_VOICE["the_kept"] = "kept"
# the last meeting ends on the recorded lines: the same takes, under the third generation's key
# ...except the knight's answer, which is the Last Heir's own take.
L["monarch_g3_death_03"] = dict(L["monarch_death_03"], cast="heir", recorded=False)
S["monarch_g3_death"] = {"lines": S["monarch_death"]["lines"][:2] + ["monarch_g3_death_03"], "once": True}
for foe, cat in SPEECH.items():
    n = sum(1 for l in L.values() if l["speaker"] == FOE_VOICE.get(foe, foe))
    assert not (cat == "A" and n), foe + " is a creature and must not speak"
    assert not (cat == "B" and n > 4), foe + " has too many lines for category B"
COMPANION = {"discovery": {"scene": "witness_discovery", "region": "courtyard", "stage": 1}, "stage": STAGE, "boss": BOSS, "topics": TOPICS, "chest": CHEST}
# Cast. The owner's final casting is tools/cast_final.json (2026-11-27) on top of the voices approved earlier (Witness,
# narrator, the second generation's knight, the plain challenge of the Sentinel and Executioner). "inworld:<voice>" is the
# Inworld model (about 2 credits a take); a bare name is a preset on the second model (about half a credit).
# NOT chosen by the owner, provisional: archivist (Onyx) and devourer (Luna). The Kept is the second generation's own voice.
VOICES = {
 "witness": "inworld:Hamish (en)", "narrator": "inworld:Graham (en)",
 "player_m": "inworld:Malcolm (en)", "player_f": "inworld:Victoria (en)",
 "kept_m": "inworld:Malcolm (en)", "kept_f": "inworld:Victoria (en)",
 "sentinel": "inworld:Mortimer (en)", "executioner": "inworld:Mortimer (en)",
 "archivist": "Onyx", "devourer": "Luna"}
PITCH = {}        # semitones, applied after generation with tempo and formants kept (tools/voices.py)
STABILITY = {}    # second model only
TEMPO = {}        # rubberband tempo applied with the pitch (1.0 = none)
for _role, _c in json.load(open("tools/cast_final.json")).items():
    if isinstance(_c, dict):
        VOICES[_role] = ("inworld:" if _c.get("model", _c.get("provider")) == "inworld" else "") + _c["voice"]
        if _c.get("pitch"):
            PITCH[_role] = _c["pitch"]
        if "stability" in _c:
            STABILITY[_role] = _c["stability"]
        if _c.get("tempo"):
            TEMPO[_role] = _c["tempo"]
# the male Kept is the male knight's voice (Sterling, same treatment; tools/voices.py adds the Kept's extra slowing)
VOICES["kept_m"] = VOICES["player_m"]
for _d in (PITCH, STABILITY, TEMPO):
    if "player_m" in _d:
        _d["kept_m"] = _d["player_m"]
# Chapter I rewrite (owner's decisions 2026-11-28, docs/SCRIPT_CH1_DECISIONS.md). Each of these had a take of its old
# words: it is text only until a take of the new words exists (the check below clears the mark when one does).
for _lid in ["opening_04", "opening_05", "awakening_06", "courtyard_1_01", "courtyard_2_01", "courtyard_3_01", "courtyard_4_01",
             "sentinel_memory_01", "sentinel_memory_02", "sentinel_memory_03", "orren_intro_01", "orren_intro_02", "orren_idle_01",
             "witness_discovery_05", "witness_discovery_07"]:
    L[_lid]["recorded"] = False
# A line written after its speaker was last recorded is text-only until tools/voices.py records it: that tool keeps
# assets/audio/vo/takes.json (file -> hash of the text it was recorded from). A new line counts as recorded when a
# take of exactly its current text exists (for the knight's lines, the male take).
import hashlib, os
_takes = json.load(open("assets/audio/vo/takes.json")) if os.path.exists("assets/audio/vo/takes.json") else {}
for _lid, _l in L.items():
    if _l.get("recorded") is False:
        _f = _lid + ("_" + _l.get("body", "m") if _l["speaker"] == "player" else "") + ".ogg"
        if _takes.get(_f) == hashlib.sha1(_l["text"].encode()).hexdigest()[:12]:
            del _l["recorded"]
NAMES = {"narrator": "", "lyra": "Lyra", "player": "", "orren": "Orren", "archivist": "The Archivist", "sentinel": "Ashen Sentinel", "executioner": "Hollow Executioner",
 "huntsman": "Pale Huntsman", "widow": "Crimson Widow", "gravewarden": "Gravewarden", "frostking": "Frostbound King", "monarch": "Forgotten Monarch", "devourer": "Devourer of Names", "witness": "The Witness", "forebear": ""}
NAMES["kept"] = "The Crownless Champion"
OUT = {"lines": L, "scenes": S, "voices": VOICES, "voice_pitch": PITCH, "voice_stability": STABILITY, "voice_tempo": TEMPO, "names": NAMES, "speech": SPEECH, "foe_voice": FOE_VOICE, "companion": COMPANION}
for path in ["data/dialogue.json", "docs/DIALOGUE_DATABASE.json"]:   # the docs copy is the same file, kept for readers
    json.dump(OUT, open(path, "w"), indent=1)
wl = [l for l in L.values() if l["speaker"] == "witness"]
print(len(L), "lines,", len(S), "scenes;", len(wl), "Witness lines,", sum(1 for l in L.values() if l.get("recorded") is False), "not recorded")
