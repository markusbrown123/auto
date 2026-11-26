#!/usr/bin/env python3
"""Authoring script for data/dialogue.json: every spoken line, its speaker and
direction, and the scenes that string lines together. Player lines are voiced
twice (male and female); the game picks by the chosen knight."""
import json
L = {}; S = {}
def scene(sid, *lines, once=True):
    ids = []
    for i, (who, text, *rest) in enumerate(lines):
        lid = "%s_%02d" % (sid, i + 1)
        L[lid] = {"speaker": who, "text": text, "dir": rest[0] if rest else ""}
        ids.append(lid)
    S[sid] = {"lines": ids, "once": once}
N, LY, P, OR, AR = "narrator", "lyra", "player", "orren", "archivist"

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
scene("sentinel_retry", ("sentinel", "Your oath must be stronger than mine.", "grudging respect"), once=False)
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
scene("devourer_intro", ("devourer", "I had a daughter.", "a man, lost"), ("devourer", "I remember the sea.", "a woman, far away"),
      ("devourer", "Please. What was my name?", "a child"))
scene("monarch_intro", ("monarch", "Look upon what remains of our civilization.", "regal, controlled"),
      (P, "I see a kingdom that should have been allowed to die.", "hard"),
      ("monarch", "And I see children who will never wake if these machines fall silent.", "patient"),
      (P, "How many people have you sacrificed?", "cold"),
      ("monarch", "Enough to ensure there are still people left to ask that question.", "unflinching"))
scene("monarch_retry", ("monarch", "You still believe death cannot teach you surrender.", "almost fond"), once=False)
scene("monarch_death", ("monarch", "I have counted every life this machine has taken. Have you counted the lives it has saved?", "failing"),
      (LY, "I think I remember the rain.", "distant"), (P, "Tell me about it.", "soft"))
VOICES = {  # cast by name only: nobody has auditioned these by ear yet
 "narrator": "Helena", "lyra": "Vesper", "player_m": "Callum", "player_f": "Imogen", "orren": "Gideon", "archivist": "Onyx",
 "sentinel": "Sterling", "executioner": "Vlad", "huntsman": "Brooks", "widow": "Sloane", "gravewarden": "Bram", "frostking": "Alistair",
 "monarch": "Caspian", "devourer": "Luna"}
NAMES = {"narrator": "", "lyra": "Lyra", "player": "", "orren": "Orren", "archivist": "The Archivist", "sentinel": "Ashen Sentinel", "executioner": "Hollow Executioner",
 "huntsman": "Pale Huntsman", "widow": "Crimson Widow", "gravewarden": "Gravewarden", "frostking": "Frostbound King", "monarch": "Forgotten Monarch", "devourer": "Devourer of Names"}
json.dump({"lines": L, "scenes": S, "voices": VOICES, "names": NAMES}, open("data/dialogue.json", "w"), indent=1)
print(len(L), "lines,", len(S), "scenes")
