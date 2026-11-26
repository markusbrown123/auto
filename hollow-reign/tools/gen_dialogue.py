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

# ---------------------------------------------------------------- opening
scene("opening",
 (N, "Once, men begged the gods to spare them from death.", "slow, grave"),
 (N, "Then men became gods.", "quiet awe"),
 (N, "They built bodies that could not grow old. Thrones that could not be inherited. Kingdoms that could not escape them.", "measured"),
 (N, "But even eternity could not protect them from the people they ruled.", "harder"),
 (N, "The crowns shattered. Their kingdoms fell. And for three hundred years, humanity believed itself free.", "elegiac"),
 (N, "We were wrong.", "near whisper"))
scene("awakening",
 (LY, "Can you hear me?", "tentative, through old machinery"),
 (P, "Who are you?", "hoarse, just woken"),
 (LY, "Someone who has been waiting a very long time.", "relief held back"),
 (P, "What happened here?", "wary"),
 (LY, "That depends. What do you remember?", "careful"),
 (P, "Things I couldn't possibly have seen.", "unsettled"),
 (LY, "Then it worked.", "quiet wonder"))
scene("first_road",
 (LY, "The doors above you open onto what was a fortress. Walk. Your body remembers how, even if you don't.", "gentle"),
 (LY, "Tap where you want to go. If something stands in the way, it has been standing there a long time.", "dry"))
# ---------------------------------------------------------------- chapter I: the courtyard
scene("courtyard_0", (LY, "Those statues were kings once. People prayed to them. Some of them answered.", "low"))
scene("courtyard_1", (LY, "Look at its armour. Under the plate there is light. That is not rust moving it.", "uneasy"))
scene("courtyard_2", (LY, "It salutes before it strikes. Someone taught it manners, three hundred years ago.", "wry"))
scene("courtyard_3", (LY, "That winch will hold. Most things they built still do. That is rather the problem.", "dry"))
scene("courtyard_4", (LY, "Careful. The big ones were made for breaking gates. You are much smaller than a gate.", "light"))
scene("courtyard_5", (LY, "Rest. That candle is not a candle, but it will not hurt you.", "soft"))
scene("courtyard_6", (LY, "He is still at his post. He has not been told that there is nothing left behind him.", "sad"))
scene("sentinel_intro",
 ("sentinel", "State your allegiance.", "flat, immense, helmeted"),
 (P, "I serve no crown.", "steady"),
 ("sentinel", "Then you have no passage.", "final"))
# speech category B: the Sentinel keeps only its challenge and its last words (the retry line was cut)
scene("sentinel_death",
 ("sentinel", "Is the war... over?", "failing, suddenly human"),
 (P, "It ended centuries ago.", "gentle"),
 ("sentinel", "Then why did no one return for me?", "a child's question"))
scene("sentinel_memory",
 (AR, "Record incomplete. Witness deceased. Memory retained.", "calm, broken cadence"),
 (AR, "Subject: gate sergeant, forty-one years of service. Volunteered. He was told it would be for one winter.", "even"),
 (LY, "They were people. All of them. Remember that when the next one raises its sword.", "quiet"))
scene("sanctuary_return",
 (LY, "You came back by the door this time. I prefer it.", "warm"),
 (LY, "There is a smith here. He does not trust you. He is very good. Let him look at that sword.", "amused"))
scene("orren_intro",
 (OR, "So you're what she woke up. Hm.", "gravel, unimpressed"),
 (OR, "That sword is older than my entire bloodline. Try not to drop it.", "dry"),
 (OR, "Bring me shards and coin. Your armour remembers its shape. I just remind it.", "matter of fact"))
scene("orren_idle",
 (OR, "People spend their lives searching for legendary weapons. Most of them wouldn't know what to do with one.", "dry"), once=False)
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
scene("widow_intro", ("widow", "That stance. I knew the soldier who taught it.", "sharp, shaken"), (P, "I've never met you.", "guarded"),
      ("widow", "No. But someone inside you has.", "bitter"))
scene("widow_death", ("widow", "You fight like six people I buried. And none of them.", "breathless"), (LY, "She is yielding. Let her.", "urgent, soft"))
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
 (W, "And to rather less than I ought. They took a good deal out of me before they shut that door.", "lighter than it should be"),
 (P, "Who did?", "direct"),
 (W, "If I knew that, I should be a happier ornament. Lift me down. I weigh very little, and I know this road.", "brisk"),
 (LY, "I do not know what that is. I do not like not knowing.", "low, to the player"),
 (W, "The voice in the walls disapproves of me. Good. We shall get on.", "amused"),
 once=False, new=True, title="The Witness", kind="discovery", essential=True)

# ---- the Fallen Courtyard (the Witness is found at stop 1, so its first words on the region come at stop 2)
wstage("courtyard", 2, "approach", "The Fallen Courtyard",
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
 (W, "The keeper. He is the gentlest thing down here, and he will kill you for a careless word.", "low"),
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
 (W, "And here I hang at your belt. What is decided in there is yours to decide. I shall only witness it.", "level"))
wboss("forgotten_monarch", "victory", "monarch", "As It Happened",
 (W, "Whatever you do next, I will set it down as it happened. That much I can still swear to.", "steady"))

# silent foes that already had a line of context from Lyra keep it as the fallback, for when the Witness cannot speak
BOSS["cathedral_beast"]["fallback"] = ["beast_intro"]
BOSS["cinder_wyrm"]["fallback"] = ["wyrm_intro"]
# what Lyra finds after the Beast is the chapter's turn: it plays with or without the Witness
BOSS["cathedral_beast"]["victory"].insert(0, "beast_death")
S["beast_death"]["essential"] = True

# ---- optional conversations in the sanctuary
topic("mask", "The Mask",
 (P, "The mask. Was it your face?", "curious"),
 (W, "It was my office. One wore it to set down a judgment, so that the record had no face to bribe.", "plain"),
 (W, "It amused them, I think, to leave me in it.", "dry"))
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
for foe, cat in SPEECH.items():
    n = sum(1 for l in L.values() if l["speaker"] == FOE_VOICE.get(foe, foe))
    assert not (cat == "A" and n), foe + " is a creature and must not speak"
    assert not (cat == "B" and n > 4), foe + " has too many lines for category B"
COMPANION = {"discovery": {"scene": "witness_discovery", "region": "courtyard", "stage": 1}, "stage": STAGE, "boss": BOSS, "topics": TOPICS}
# Cast. "inworld:<voice>" entries were CHOSEN BY THE OWNER from audition reel 4 (2026-11-26): the Witness, the male knight,
# the narrator, and the plain human challenge before a fight (Sentinel, Executioner). Everything else is still the
# provisional cast picked by name, which nobody has approved.
VOICES = {
 "witness": "inworld:Hamish (en)", "player_m": "inworld:Malcolm (en)", "narrator": "inworld:Graham (en)",
 "sentinel": "inworld:Mortimer (en)", "executioner": "inworld:Mortimer (en)",
 # player_f = Victoria with the clarity treatment: CHOSEN BY THE OWNER (2026-11-26). Lyra, Orren and the Monarch below are the developer's picks from reel 4's measurements, not yet heard or approved:
 "lyra": "inworld:Claire (en)", "player_f": "inworld:Victoria (en)", "orren": "inworld:Callum (en)", "monarch": "inworld:Hades (en)",
 "archivist": "Onyx",
 "huntsman": "Brooks", "widow": "Sloane", "gravewarden": "Bram", "frostking": "Alistair",
 "devourer": "Luna"}
# A line written after its speaker was last recorded is text-only until tools/voices.py records it: that tool keeps
# assets/audio/vo/takes.json (file -> hash of the text it was recorded from). A new line counts as recorded when a
# take of exactly its current text exists (for the knight's lines, the male take).
import hashlib, os
_takes = json.load(open("assets/audio/vo/takes.json")) if os.path.exists("assets/audio/vo/takes.json") else {}
for _lid, _l in L.items():
    if _l.get("recorded") is False:
        _f = _lid + ("_m" if _l["speaker"] == "player" else "") + ".ogg"
        if _takes.get(_f) == hashlib.sha1(_l["text"].encode()).hexdigest()[:12]:
            del _l["recorded"]
NAMES = {"narrator": "", "lyra": "Lyra", "player": "", "orren": "Orren", "archivist": "The Archivist", "sentinel": "Ashen Sentinel", "executioner": "Hollow Executioner",
 "huntsman": "Pale Huntsman", "widow": "Crimson Widow", "gravewarden": "Gravewarden", "frostking": "Frostbound King", "monarch": "Forgotten Monarch", "devourer": "Devourer of Names", "witness": "The Witness"}
OUT = {"lines": L, "scenes": S, "voices": VOICES, "names": NAMES, "speech": SPEECH, "foe_voice": FOE_VOICE, "companion": COMPANION}
for path in ["data/dialogue.json", "docs/DIALOGUE_DATABASE.json"]:   # the docs copy is the same file, kept for readers
    json.dump(OUT, open(path, "w"), indent=1)
wl = [l for l in L.values() if l["speaker"] == "witness"]
print(len(L), "lines,", len(S), "scenes;", len(wl), "Witness lines,", sum(1 for l in L.values() if l.get("recorded") is False), "not recorded")
