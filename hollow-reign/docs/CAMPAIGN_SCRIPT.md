# Hollow Reign: campaign script

Beat-by-beat campaign, written 2026-11-26 from `STORY_BIBLE.md`, `WORLD_HISTORY.md`, `CHARACTER_BIBLE.md`, `data/regions.json`, `data/bosses.json` and `data/dialogue.json`. Canon is the story bible. Stage names, hints, foes and loot are quoted from the data files as they are today.

## How to read this
- **Scene id** means a key under `scenes` in `data/dialogue.json`. Every id cited without a marker exists today (83 lines, 41 scenes, 97 voice files; the voice files are provisional and unheard).
- **PROPOSED (not recorded)** means the line or scene does not exist in `data/dialogue.json`, has no audio, and is a suggestion only.
- Stage remarks are chosen by `src/core/companion.gd` (`Companion.on_stage`, called from `src/ui/explore.gd` and `src/cine/cine_road.gd`): Lyra's scene `<region id>_<stage index>` where one exists, then the Witness's remark for that stop. Of Lyra's, only `courtyard_0` to `courtyard_6` exist. The proposed Lyra remarks below use that same id pattern so they would play with no code change once added. The Witness's remarks exist and are listed in "The Witness and who speaks" near the end.
- Boss scenes are played by `src/combat/duel.gd` as `<key>_intro` (first meeting), `<key>_retry` (later attempts), `<key>_death` and `<key>_memory` (after a win). Keys (`foe_voice` in `data/dialogue.json`): sentinel, executioner, huntsman, widow, gravewarden, frostking, devourer, monarch. Creatures (the Beast, the dragons) have no key and never speak; `beast_intro`, `beast_death` and `wyrm_intro` are Lyra's and are now played by the Companion. Since 2026-11-26 the file holds 214 lines in 109 scenes; the "83 lines, 41 scenes" in the first bullet predates the Witness.
- Lore discoveries: the story bible lists "the 50 lore discoveries" as not built. All 50 named here are PROPOSED. Treasure contents (items, gold, shards) are real data.

## Source disagreements that affect the script
These are recorded, not resolved. Section "Open contradictions" at the end lists them in full.
- The boss intro cards and region blurbs in `data/bosses.json` and `data/regions.json` tell an older story (kings, weddings, a kingdom the player once served). The story bible says the 2026-11-25 brief "replaces all earlier narrative". Both texts are currently shown to the player.
- `data/regions.json` makes all eight regions a single required chain. The story bible says the Wyrm's Roost and the Hollow Deep should be optional or secret.

## The Inherited Oath: three generations (2026-11-26, supersedes the single-knight campaign)

Source: `docs/GENERATIONAL_CAMPAIGN_BRIEF.md` and the owner's decision on the twist ("a mix of 1 and 3"). This section is the campaign. The chapter sections after it are kept as the detail of **Generation II's** journey: places, stages, foes and loot are unchanged, and each chapter carries a short note where the generations change what it means. Where an older paragraph below still speaks of "the Unbound" as a made person, read "the heir": that origin is withdrawn.

> **Owner decision box**
> **Scripted and partly built: "The sword stays, and the throne keeps what it takes."**
> 1. *The first death comes when you are winning.* Generation I is short and playable. In the clash with the Monarch the story takes the fight on a cut the player lands, not on a health bar: the hall is sealed, the forebear gets through the seal to the Inheritance Engine, drives the sword into its block to send the records out, and dies at the foot of the cradle. The sword stays in the block. Twenty-two years later the heir comes to in the same spot, in the same frame, and the first thing the game asks is "TAKE UP YOUR SWORD": the same item, with whatever has been done to it. **Built** (Generation I, the time jump, the arrival; the chamber scene is the existing one).
> 2. *The second death is not a death.* The second generation falls saving the records, and it plays as a hero's end. In Generation III the first guardian the heir meets, standing in the Ashen Sentinel's old post, wears the armour, sword, shield and forge mods the player had equipped as Generation II and fights with the combinations that player used most. The Witness knows the walk before the player knows the armour. **Scripted, not built** (the snapshot and the mirror foe are specified in `docs/FLOW.md`).
> **Where the echo stands, and why:** the Inner Ward of the Fallen Courtyard, first guardian of Generation III, not the last door before the throne. Generation III is the fast pass, so its strongest moment should come while the player still expects a rerun; it is the post where Generation II began its own road ("why did no one return for me?" is answered by the one person who cannot); and it leaves the whole of Generation III to carry what the heir learned there to the Monarch. Putting it at the throne door would make it a prelude to the last fight and compete with it.
> **Not chosen, noted as garnish only:** a false ending after a Generation II win; the fallen speaking one line each in the last fight.
> **Decisions still the owner's:** (a) whether ordinary defeat is in the fiction (the Engine returns the heir) or a plain retry: six recorded Lyra lines and one of the Witness's depend on it; (b) whether the gear the second generation was wearing is withheld until the Kept is beaten (stronger, but it bends "nothing earned is lost"; the script below does **not** withhold it); (c) casting for four new voices (below).

### The family and the fixed points (names are original)
- **House Marrek**, wardens of the low road. The game never says the given names aloud unless the player names their knight; the Lineage screen lists "the First", "the Second", "the Last" under the player's chosen names.
- **Generation I, the First Oath:** the Father (or the Mother). A veteran in weathered silver, a clean sword, a practical shield. Speaker key `forebear`.
- **Generation II, the Broken Crown:** the Son (or the Daughter), twenty-two years on. The player's chosen knight. Motive: to know why, and to make someone pay.
- **Generation III, the Last Heir:** the Grandson (or Granddaughter), twenty-four years after that. Raised on the story of two graves, one of which is empty.
- **The Forgotten Monarch** does not age. He is fought three times: a clash (I), a full duel (II), the last duel in three phases (III).
- **The Inheritance Engine** is the cradle and its room under the Ring-Gate (the existing `chamber` set). It keeps the house's records, its trained hand, and the door to its vault. It does not copy people. Lyra is the stored mind that tends it: "Someone who has been waiting a very long time."
- **The Witness** is found by the second generation in the Courtyard monument, as staged today, and is not kin. It simply remembers all three.
- **Orren** is at the forge in Generation II. In Generation III he is old, half-blind, and still there; his recorded lines belong to II.
- **The fortress** is always seen from one composition on the high road (`HighRoad.vista()`): Generation I whole and kept, II with an arc of the Ring-Gate fallen and the road half grown over, III under snow with the seam in the ring alight.
- **Recall**, the knight's summoning of the blade, is the Engine's first gift and is first shown in Generation II's first duel, as it is today.

### Length (target about 2 to 3 hours in all)
| Part | Target | Content |
|---|---|---|
| Generation I | about 4 minutes as built (the brief allows 8 to 10) | the road, the throne, one winnable duel, the clash, the fall |
| Time jump and arrival | about 1.5 minutes | the same view changed; the heir's line; the game's name; the walk to the gate |
| Generation II | about 85 to 100 minutes | the Engine, the Courtyard (Witness, lesson, Sentinel), Blackwood, Cathedral, Crypt, Citadel, the Throne and the second meeting. The Roost is optional. Not every guardian has to fall. |
| Generation III | about 40 to 50 minutes | the same places with changed encounters, entered by the routes II opened; the Kept; the last duel; the door under the throne |
| Beneath the throne | optional, 20 minutes and up | the facility (the Hollow Deep's set), the Devourer, the dragons, the third ending's conditions |

### Who stands where (the existing roster, reused; nothing new is modelled)
| Place | Generation I | Generation II | Generation III |
|---|---|---|---|
| The Hollow Throne, the hall | **Royal Gatekeeper** = `throne_guard` (Throne Guard); the Monarch (clash) | `throne_guard`, `kingsblade`, `crownless`, `herald`; the Monarch (full duel) | `throne_colossus` (The King's Shadow) at the door; the Monarch (three phases) |
| The Fallen Courtyard | passed on the way in: the gate is kept and manned, nobody bars a warden with a petition | `hollow_soldier`, `banneret`, `rampart_brute`; **Ashen Sentinel** | **"The Crownless Champion"** on the card = **the Kept** (a mirror foe built from the Generation II snapshot); lesser foes `pike_sergeant`, `gate_colossus` |
| The Blackwood | Royal Patrol = `pike_sergeant` (PROPOSED, only if Generation I is lengthened) | **Pale Huntsman** (optional), **Hollow Executioner** | **Awakened Beast** = `maulbeast` promoted to the Clearing; the Huntsman, if spared in II, stands with the heir |
| The Cathedral of Ash | sealed | **Crimson Widow**, **Cathedral Beast** | **Ancient Laboratory Guardian** = `gate_colossus` re-dressed (the kind that is "bolted into its armour"), at the lower door the Beast's fall uncovered |
| The Sunken Crypt | shut | **Gravewarden** | the way down: **The Devourer of Names** (set: the Hollow Deep) |
| The Frozen Citadel | shut | **Frostbound King** | optional **Skeldra** |
| The Wyrm's Roost | a far light on the vista | optional **Veyrath** | the dragon hunt: Veyrath if she lives, then **Azhurion** |
| Beneath the throne | unknown | glimpsed through the seal | the Eternal Crown's facility |

Consequences that carry: the Winch Gate, the Rope Bridge, the Sacristy Door, the Sluice, the Ice Lift and the King's Door stay as Generation II left them (the existing shortcut flags, read by Generation III); a guardian II killed is replaced in III, a guardian II spared is still there and remembers.

### Generation I, scene by scene (built: `src/cine/prologue.gd`)
| Beat | What happens | Played? | Lines |
|---|---|---|---|
| The vista | Dawn on the headland. The forebear small on the worn road; far ahead the Ring-Gate, whole, the citadel's two spires inside it. Card: "VAELORA · THE FIRST OATH". | watched | `opening` begins (recorded) |
| The climb | Five designed shots: through the grass, the switchbacks, cresting the rise, the dead tree, the court between the ring's feet. The narrator tells how the immortal kingdoms fell: the history is the thing being walked up to. | watched | `opening` (six recorded lines, unchanged) |
| The gate | The court. The new narration brings it down to one reign and one person. | watched | `gen1_open` (3, new) |
| The hall | The forebear walks the length of the throne hall. The exchange. | watched | `gen1_throne` (4, new) |
| The guardian | "Show the warden to the gate." A Throne Guard leaves the wall and turns. **A real duel**, winnable; two prompts say what the shield and a cut are for. Lost: it is taken again. | **played** | `gen1_guard` (1, new) |
| The records | The forebear goes for the seal instead of the door. The Monarch comes down himself. | watched | `gen1_records` (2, new) |
| The clash | **A real duel** with the Monarch at full strength. After nine seconds, the cut that makes four landed is the one the story answers: the hall is sealed mid-exchange. (A player who lands nothing is released at 32 seconds; nobody dies to an ordinary blow here.) | **played** | none: no words in a fight |
| The fall | Behind the seal, the Engine's room. The door comes down. The sword goes into the block; light goes out through it. The forebear reaches the foot of the cradle. The Monarch is heard through the door he has shut. | watched | `gen1_seal` (3, new) |
| The mark | Black. The family's mark. | watched | `gen1_close_m` / `_f` (2 each, new) |

Lines as written (all new, text only):
- `gen1_open`, Narrator: "For centuries the bells of Vaelora rang beneath the same sovereign." / "Harvests failed and were mended. Villages fell silent and were forgotten. Upon the throne, nothing changed." / "One warden of the low road dared to ask what such permanence had cost."
- `gen1_throne`: Forebear: "Three villages have fallen silent. Their names are struck from your records." / Monarch: "Their silence has bought another winter for thousands." / Forebear: "You speak of people as though they were coin." / Monarch: "A ruler must count what others refuse to count."
- `gen1_guard`, Monarch: "Show the warden to the gate."
- `gen1_records`: Forebear: "The count is behind that seal. I did not climb this far to be told the sum." / Monarch: "Then you climbed for nothing."
- `gen1_seal`: Monarch: "Enough. Seal the hall." / Monarch: "You have done nothing but leave this burden to another." / Forebear: "Then another will come better prepared."
- `gen1_close_m` (`_f`), Narrator: "His (Her) name disappeared from the royal histories." / "But not from those of his (her) house."

### The time jump and Generation II's arrival (built: `src/cine/time_jump.gd`, `src/cine/arrival.gd`)
| Beat | What happens | Lines |
|---|---|---|
| Twenty-two years | The one view, as Generation I left it. Card: "TWENTY-TWO YEARS". Weather closes over it and opens on the same view: an arc of the ring down, its stones on the slope, the fires out, the banners gone, turf over half the road, an autumn dusk. | none |
| The heir | The player's own knight, in what they chose, standing where the forebear stood. | `gen2_arrive_m`: "I know where you died, Father. I would know why." (`_f`: "…, Mother.") |
| The name | They set off. **HOLLOW REIGN** comes up over the road. | none |
| The walk | The climb, the rise, the dead tree, the court. The gate is not kept: nobody is there. | none |
| The Engine | Black, then one light: the existing chamber scene, unchanged. The heir is on the floor at the foot of the cradle, in the forebear's last frame. Lyra: "Can you hear me?" … "Then it worked." The sword is in the block. **TAKE UP YOUR SWORD.** | `awakening`, `first_road` (recorded) |
| Out | The door, the walk out, the Fallen Courtyard, the Witness at the second stop, the lesson, the Sentinel. | as today |

### Generation II: what changes in the chapters below
The chapters are played as written, with these differences. PROPOSED lines here are not in `data/dialogue.json`.
- **Courtyard.** After `witness_discovery`, on leaving the stop, PROPOSED `witness_walk`: Witness: "Well. You have his manner of walking." (`_f`: "her") / Heir: "You knew my father." / Witness: "I knew what he was looking for. That is a somewhat different matter."
- **Sanctuary.** After `orren_intro`, PROPOSED `orren_sword`: Orren: "That sword has seen better years." / Heir: "It belonged to my father." / Orren: "Then I shall mend it. I cannot teach it to forgive your mistakes."
- **Cathedral.** At the Beast's door, after `w_beast_approach`, PROPOSED one line, Witness: "They heard what breathed under it and took the breathing for the voice of a god."
- **Crypt.** The Gravewarden is the first clue: he keeps names, not bodies (`gravewarden_intro`, recorded). PROPOSED after his fall, Witness: "Kept as writing. One wonders where the hands go."
- **Citadel.** Before `frostking_death`, PROPOSED, Frostbound King: "You cannot free a kingdom by starving it. Learn what lies beneath the throne before you raise your sword against it."
- **Throne, the Antechamber.** The second clue. The Kingsblade bows in a form the Witness knows (`w_throne_guard` is recorded and already says it of the guard: "It is the same order, you know. Only the handwriting differs."). PROPOSED, Witness: "That salute went out of use before your grandfather was born. He did not learn it from a book."
- **Throne, the second meeting** (replaces "Boss: The Forgotten Monarch" for this generation). PROPOSED `monarch_blade`, Monarch: "That blade. I had wondered when I would see it again." Then `monarch_intro` (recorded, five lines). A real duel in two phases. At 33 per cent, or when the heir is near falling, the seal behind the throne starts to burn: the records the forebear could only send part of. The player chooses, in play: keep cutting, or go to the seal (a marked spot, three held taps under attack). Going to the seal ends the generation. Not going means the fight continues until the player wins or is beaten; a win is acknowledged (PROPOSED, Monarch, rising again as the hall's machines turn over: "You see the difficulty. I am not the thing that is keeping me.") and the seal is then the only thing left to do. A defeat here is an ordinary defeat.
- **The second fall.** PROPOSED `gen2_seal`: Heir: "All these years I thought I had come for your life." / Monarch: "And what have you found instead?" / Heir: "The means to end your reign." The heir is cut down at the seal with the transfer complete. The camera does not leave the Monarch; it does not show the body being taken up. PROPOSED `gen2_close`, Narrator: "The second of that house fell beneath the same throne." / "But where the first had left a question, this one left an answer." Card: "TWENTY-FOUR YEARS" (`TimeJump.make(24, 2, 3)`).

### Generation III: the Last Heir (scripted, not built)
| Beat | What happens | Lines (all PROPOSED) |
|---|---|---|
| The view | The same composition under snow. The seam in the ring is lit all the way round. A third figure. | Lyra: "Three of your house have stood before those gates." / Heir: "And how many returned?" / Lyra: "Not enough." / Heir: "Then show me another way." |
| The Engine | No waking on the floor: the heir walks in. Two things are in the block's place: the first sword's scabbard, and nothing else. Everything the house earned is in the vault. | Lyra: "I kept all of it. I could not keep them." |
| The Courtyard | The Winch Gate is as the second left it. The road is quicker. At the Inner Ward a guardian stands in the Sentinel's post. The card reads "The Crownless Champion". | Witness: "Stop. Do not go in yet." / Heir: "It is one guardian." / Witness: "It is the walk. I was carried at that hip for a year." |
| **The Kept** | The guardian turns. It is wearing what the player wore. It fights with what the player favoured. It is the hardest humanoid before the throne, and it is fair: every pattern in it is one the player made. Speech category C, very few words. | The Kept: "State your… no. That was his question." / Heir: "Who were you?" / The Kept: "Late. I was late home." |
| After | It does not die like a guardian. It lowers the sword and holds it out, hilt first. | The Kept: "You kept the edge on it." / "Go on. I have held this gate as long as I was able." / Witness: "I will set that down as it happened. All of it. Both times." |
| What it gives | The Kept's own sword as a second copy of the inherited blade with its Generation II mods, renamed (PROPOSED "The Second's Edge"); the record "One Who Was Kept"; and one of the conditions of the third ending: a stored mind that was asked, and chose. | |
| The road | Blackwood (the Awakened Beast), the Cathedral's lower door (the Laboratory Guardian), the Citadel (optional Skeldra), in any order the open routes allow. Two of the three are enough. | |
| The last meeting | The hall with its floor open and the machinery showing. Three phases: the Sovereign, the Ancient Crown, the Last Defence (the restoration engines; broken by parrying into them, cut by cut). | Monarch: "Your family has spent two lifetimes at my gates." / Heir: "Three. You are keeping one of them." / Monarch: "I keep everything. It is the whole of my office." / Heir: "And you have mistaken survival for the right to rule." / Monarch: "When these machines fall silent, they will remember whom to blame." / Heir: "Then let them remember a choice was made." Then `monarch_death` (recorded). |
| The door | No victory screen. The Witness remembers a door. | Witness: "There is a door. Not from this side of the wall." / Lyra: "This was never merely a kingdom." / Heir: "Then what was it?" / Lyra: "A means of keeping one alive." |
| Beneath | The facility; the Devourer; the dragons; the choice at the Crown. | as "The three endings" below |

The three endings stand as written below. The third (The Free Cities) gains one condition and loses none: the Kept was faced and let go.

### Every recorded line (208 lines in `data/dialogue.json`, 231 takes in `assets/audio/vo/takes.json`)
| Recorded scene(s) | Lines | Verdict | Where it lives now |
|---|---|---|---|
| opening | 6 | Reassign | Generation I, over the climb of the high road (was: over the throne hall). Same takes, same order. |
| awakening | 7 | Reassign | Generation II, at the Inheritance Engine: the heir comes to where the forebear died. "Things I couldn't possibly have seen" is now what the Engine carried; "Then it worked" is the transmission, twenty-two years late. |
| first_road | 2 | Keep | Generation II, leaving the Engine. "Your body remembers how, even if you don't" is the inherited combat knowledge. |
| courtyard_0 … courtyard_6 | 7 | Keep | Generation II, the Fallen Courtyard stops. |
| sentinel_intro, sentinel_death, sentinel_memory | 9 | Keep | Generation II. The owner's one-line "None shall pass." is not needed: the recorded challenge does that job in three. |
| sanctuary_return, orren_intro, orren_idle | 6 | Keep | Generation II. "So you're what she woke up" now means what Lyra woke at the Engine. The owner's new forge exchange is added after it, not instead of it. |
| rebirth_0 … rebirth_5 | 6 | Keep (soft) | Any generation, on return after an ordinary defeat. They assume the Engine brings the heir back; if ordinary defeat is to be a plain retry with no fiction, these six go unused. `rebirth_5` ("You don't owe the dead your future") is the theme of the whole game and should be kept whatever is decided. |
| executioner_intro, executioner_death | 4 | Keep | Generation II, the Blackwood. |
| huntsman_intro | 3 | Keep | Generation II, optional. "One of their things": he takes a knight carrying Engine knowledge for the kings' work. |
| widow_intro, widow_death | 5 | Keep (soft) | Generation II, the Cathedral steps. "I knew the soldier who taught it" / "someone inside you has" is now the forebear, plainly. "Six people I buried" overstates one forebear: read as the Engine's older holdings, or re-record as "like someone I buried". |
| beast_intro, beast_death | 4 | Keep | Generation II, the Cathedral. |
| gravewarden_intro, gravewarden_death | 5 | Keep | Generation II, the Crypt. "Names, not bodies" is the planted clue for the Kept; "You are not the first to enter this chamber" is the forebear. |
| frostking_intro, frostking_retry, frostking_death | 5 | Keep | Generation II, the Citadel. The owner's "You cannot free a kingdom by starving it" is added as a new line before `frostking_death`. |
| wyrm_intro | 1 | Keep | Generation II (optional) or III (the dragon hunt), whichever meets her first. |
| monarch_intro, monarch_retry | 6 | Reassign | Generation II, the second meeting with the Monarch, after the new "That blade." line. "A kingdom that should have been allowed to die" is the son's anger; the heir would not say it. |
| monarch_death | 3 | Reassign | Generation III, the end of the last fight ("I think I remember the rain." / "Tell me about it."). |
| devourer_death (the knight's two lines) | 2 | Reassign | Generation III, beneath the throne. |
| witness_discovery | 9 | Keep | Generation II, the Courtyard monument, exactly as staged. The owner's "You have his manner of walking" is added as a second scene on leaving the stop. |
| Witness: road remarks, before/after each guardian, sanctuary talks (`w_*`, 68 scenes) | 118 | Keep | Generation II. Two need a ruling, neither is wrong: `w_talk_return` ("I die, and I wake here") depends on the same decision as `rebirth_*`; `w_throne_guard` ("Unrelieved. Like the first one you met.") is the second planted clue for the Kept. Scenes for foes moved to Generation III (`w_devourer_*`, `w_azhurion_*`, `w_rimewyrm_*`) play there unchanged. |
| **Total** | **208** | | **0 now wrong.** 24 reassigned, the rest kept; 3 groups kept "soft" (they work, a re-record would fit better). |

### New lines
**In `data/dialogue.json` now, text only (`"recorded": false`): 19 lines in 9 scenes.**
| Speaker | Lines | Scenes |
|---|---|---|
| Narrator | 7 | `gen1_open` 3, `gen1_close_m` 2, `gen1_close_f` 2 |
| Forebear (Father and Mother read the same words) | 4 | `gen1_throne` 2, `gen1_records` 1, `gen1_seal` 1 |
| Forgotten Monarch | 6 | `gen1_throne` 2, `gen1_guard` 1, `gen1_records` 1, `gen1_seal` 2 |
| The second generation (the knight) | 2 | `gen2_arrive_m` 1, `gen2_arrive_f` 1 |

**PROPOSED above, not in data: 41 lines.** Witness 9, Monarch 6, the second generation 4, the Last Heir 8, Lyra 5, the Kept 4, Orren 2, Frostbound King 1, Narrator 2. Generation III's road remarks and Orren's old-age lines are not yet written.

**Casting needed (nothing is to be recorded until the story is approved):**
| Role | Voice |
|---|---|
| The Son (Generation II, male) | Malcolm: the approved male knight. All existing male takes are his and stay. |
| The Daughter (Generation II, female) | Victoria: the approved female knight. All existing female takes stay. |
| The Father | **new**: older and rougher than Malcolm. 4 lines. |
| The Mother | **new**: older than Victoria. The same 4 lines. |
| The Grandson, the Granddaughter | **new**, two voices: younger, lighter than II, never bright. About 8 lines each so far. |
| The Kept | no new voice: the second generation's own (Malcolm or Victoria) through the guardians' closed-helm treatment. That is the point of it. |
| Narrator, Witness, Sentinel | Graham, Hamish, Mortimer as approved. |
| Monarch, Lyra, Orren | still the unapproved provisional cast; the Monarch now has 13 more lines to carry. |

Notes
- `rebirth_*` is picked with `randi() % 6`. PROPOSED: index by defeat count, capped at 5.
- The throne-hall opening (`src/cine/opening.gd`) is no longer played: its narration moved to the climb and its hall is where Generation I's exchange happens. The class is kept because the "seen" mark lives in it and `--screen=opening` still shows it. PROPOSED later use: its ruined-hall shots for the Generation III throne room.
- `STORY_BIBLE.md`, `CHARACTER_BIBLE.md` and `WORLD_HISTORY.md` still describe the Unbound as a made person and count "nineteen years after the Great Silence". They were not edited in this pass and must be brought into line once this is approved.

---

## Chapter I. The Broken Oath — The Fallen Courtyard (`courtyard`)
*Generations: II as written here. III: the same ward, the Winch Gate as II left it, and the Kept in the Sentinel's post.*
Ambience `wind`. Music `explore_courtyard` (exists), boss `boss_ashen_sentinel` (exists). Shortcut: The Winch Gate (flag `courtyard_gate`, returns to stage 4). What the player learns: the enemies were people.

| # | Stage (data) | What happens | Dialogue | Collectibles |
|---|---|---|---|---|
| 0 | The Breach — fight `hollow_soldier` | First fight. A garrison soldier still walks rounds on a fallen wall. | `courtyard_0` (Lyra, the statues) | Lore 1 PROPOSED: "Defaced King" (statue plinth with a maintenance hatch) |
| 1 | The Guardhouse (treasure: Garrison Gauntlets, 60 gold, 1 shard) or The Rampart Stair (fight `hollow_soldier` / `pike_sergeant`) | First branch: loot or a harder fight. | `courtyard_1` (Lyra, light under the plate) | Lore 2 PROPOSED: "Garrison Roll" in the Guardhouse (names, one marked "volunteered") |
| 2 | The Barbican — fight `banneret` | A duellist who salutes first. Teaches parry. | `courtyard_2` (Lyra, manners) | Lore 3 PROPOSED: "The Standing Banner" (cloth that does not rot) |
| 3 | Turn the Winch (lever, sets `courtyard_gate`) or The Well (treasure: Iron Band, 40 gold, 1 shard; needs the gate flag) | Shortcut choice. | `courtyard_3` (Lyra, things they built still hold) | Lore 4 PROPOSED: "Winch Housing" (a sealed motor behind the chain drum) |
| 4 | The Gate Passage (fight `rampart_brute` / `gate_colossus`) or The Murder Hole (treasure: Garrison Helm, 80 gold, 1 shard) | First heavy enemy. Teaches dodge. | `courtyard_4` (Lyra, smaller than a gate) | Lore 5 PROPOSED: "Breaker's Harness" (the brute is bolted into its armour) |
| 5 | Kneel (shrine) | Rest. The "candle" is a maintenance point. | `courtyard_5` (Lyra, not a candle) | Lore 6 PROPOSED: "The Candle That Is Not" |
| 6 | The Inner Ward — boss `ashen_sentinel` | See below. | `courtyard_6`, then boss scenes | Memory: `sentinel_memory` (exists) |

**Boss: The Ashen Sentinel.** Three phases (at 50% "The Sentinel's armour splits. Embers pour from the seams."; at 22% "He plants the blade and speaks the oath of the gate one last time."). Weak to frost. Loot: Sentinel's Burden (always), Sentinel Bulwark, Ashen Cuirass, Ember Signet.
- First meeting: `sentinel_intro` ("State your allegiance." / "I serve no crown." / "Then you have no passage."). Later attempts: none (`sentinel_retry` was cut under the speech rules).
- Death: `sentinel_death` ("Is the war... over?" … "Then why did no one return for me?").
- Memory: `sentinel_memory` (Archivist record, then Lyra: "They were people. All of them.").
- Story meaning: the first guardian is a man who was told his duty would last one winter. The fight should feel like discipline, not malice, and the win should not feel like a victory.

---

## Chapter II. The Kingdom Without Kings — The Blackwood (`blackwood`)
Ambience `wind`. Music `explore_blackwood` (missing; falls back to `menu`), boss music `combat_a` (no bespoke track). Shortcut: The Rope Bridge (`blackwood_bridge`). What the player learns: someone is waking the guardians on purpose.

| # | Stage (data) | What happens | Dialogue | Collectibles |
|---|---|---|---|---|
| 0 | The Lantern Road — fight `blackwood_stalker` | Lit lanterns in a dead forest. | PROPOSED `blackwood_0`, Lyra: "Those lanterns have no oil in them. Something is still paying for the light." | Lore 7 PROPOSED: "Cold Lantern" |
| 1 | The Road (fight `blackwood_stalker` / `veil_dancer`) or The Deer Trail (optional boss `pale_huntsman`) | The optional guardian. See below. | PROPOSED `blackwood_1`, Lyra: "Two sets of tracks. One of them wants to be followed." Then `huntsman_intro` if the trail is taken. | Lore 8 PROPOSED: "Hunter's Tally" (a list of engineered creatures, most crossed out) |
| 2 | The Briar Gate (fight `thornblade` / `veil_dancer`) or The Hollow Oak (treasure: Blackwood Gauntlets, 110 gold, 2 shards) | Woven briars: someone lives here. | PROPOSED `blackwood_2`, Lyra: "This was a hunting park. The fences were not built to keep deer in." | Lore 9 PROPOSED: "Park Warden's Key" in the Hollow Oak |
| 3 | Cast the Bridge (lever, `blackwood_bridge`) or The Charcoal Burner's Hut (treasure: Blackwood Hatchet, 90 gold, 2 shards) | Shortcut choice. | PROPOSED `blackwood_3`, Lyra: "Cast it and it stays. I would like one thing in this wood to be on our side." | Lore 10 PROPOSED: "Barred From Outside" (who locked the hut, and why) |
| 4 | The Woodpile — fight `woodward` / `maulbeast` | A woodcutter still stacking timber. | PROPOSED `blackwood_4`, Lyra: "He has been stacking for three hundred years. Nobody told him the fires were out." | Lore 11 PROPOSED: "Fuel Order" (a requisition for a prison furnace) |
| 5 | Drink (shrine) or Under the Gibbet (treasure: Blackwood Greaves, 140 gold, 2 shards; needs the bridge flag) | Rest under a gibbet tree. | PROPOSED `blackwood_5`, Lyra: "Drink. The water is clean. The tree is not my doing." | Lore 12 PROPOSED: "Sentence Without a Court" |
| 6 | The Clearing — boss `hollow_executioner` | See below. | PROPOSED `blackwood_6`, Lyra: "Every stump has been used as a block. Do not count them." Then boss scenes. | Memory PROPOSED: `executioner_memory` |

**Optional boss: The Pale Huntsman.** One phase. Weak to fire. Loot: Pilgrim Knives, Blackwood Greaves, Blackwood Gauntlets.
- First meeting: `huntsman_intro` ("I know one of their things when I see it." / "I am not theirs." / "They all said that.").
- No death or retry scene exists. The story bible lists "the Huntsman's peaceful resolution" as not built.
- PROPOSED `huntsman_yield` (not recorded), played if the player breaks his posture and then holds instead of striking:
  - Huntsman: "You had the blow. Their things do not hold a blow."
  - Player: "Then stop calling me theirs."
  - Huntsman: "Hm. I will watch you a while longer. From further off."
- PROPOSED `huntsman_death` (not recorded), if killed: Huntsman: "One more of you loose in the world. I hope I was wrong."
- Story meaning: the only mortal among the guardians. He is right about what the old kings bred and wrong about the Unbound. Killing him should cost the player something later (see quest 3).

**Boss: The Hollow Executioner.** Two phases (at 55% "He drags the cleaver through the roots. Something under the wood answers."). Weak to fire. Loot: Headsman's Promise, Executioner's Tally, Blackwood Cuirass, Blackwood Helm.
- First meeting: `executioner_intro` ("Your identity is unregistered." / "Your kingdom no longer exists." / "The law does not require a kingdom.").
- Death: `executioner_death` (Lyra: "That prison was switched back on from somewhere else. Someone is waking them. On purpose.").
- PROPOSED `executioner_retry` (not recorded): "Sentence deferred is not sentence commuted."
- PROPOSED `executioner_memory` (not recorded): Archivist: "Subject: court officer. Four thousand and nine sentences carried out. Zero appeals heard. The appeals office was closed first."
- Story meaning: law outliving the state that wrote it. The death scene is the chapter's turn: the waking is deliberate and remote.

---

## Chapter III. The Woman Who Remembered — The Cathedral of Ash (`cathedral`)
Ambience `fire`. Music `explore_cathedral` (missing), boss music `combat_a` (Widow) and `combat_b` (Beast). Shortcut: The Sacristy Door (`cathedral_door`). What the player learns: the world is science fiction; the cathedral is a laboratory.

| # | Stage (data) | What happens | Dialogue | Collectibles |
|---|---|---|---|---|
| 0 | The Pilgrim Stair — fight `ash_acolyte` / `censer_adept` | Ash falling; robed figures. | PROPOSED `cathedral_0`, Lyra: "They say the faithful burned it themselves. Stone does not burn for three hundred years." | Lore 13 PROPOSED: "Pilgrim's Token" (a numbered tag, not a charm) |
| 1 | The Porch (fight `censer_knight` / `bell_ringer`) or The Almoner's Box (treasure: Sanctuary Candle, 150 gold, 2 shards) | The giant censer. | PROPOSED `cathedral_1`, Lyra: "That censer is venting something. It is not incense. Stay out of the swing." | Lore 14 PROPOSED: "Almoner's Ledger" (donations recorded in years of life, not coin) |
| 2 | The Cathedral Steps — boss `crimson_widow` | Mid-region boss. See below. | PROPOSED `cathedral_2`, Lyra: "She is not one of theirs. Listen. She is breathing." Then boss scenes. | Memory PROPOSED: `widow_memory` |
| 3 | Unbar the Sacristy (lever, `cathedral_door`) or The Reliquary (treasure: Vigil Gauntlets, 160 gold, 3 shards) | Shortcut choice. | PROPOSED `cathedral_3`, Lyra: "There are drains in the floor of the nave. I never asked why a church needs drains." | Lore 15 PROPOSED: "Saint's Bones" (a skeleton with fittings) |
| 4 | The Choir Loft — fight `choir_wraith` | A hymn with no singers. | PROPOSED `cathedral_4`, Lyra: "That is a recording. It has been singing to an empty room longer than your oldest memory." | Lore 16 PROPOSED: "The Hymn Cylinder" |
| 5 | Light One (shrine) | Hundreds of candles, none burned down. | PROPOSED `cathedral_5`, Lyra: "None of them have burned down. You have seen one of these before." | Lore 17 PROPOSED: "Votive Array" |
| 6 | The Crossing — boss `cathedral_beast` | See below. | PROPOSED `cathedral_6`, Lyra: "The bell rings on the hour. There has been no rope for centuries." Then boss scenes. | Lore 18 PROPOSED: "The Lower Facility" (found after the Beast); Lore 19 PROPOSED: "Transfer Cradle" |

**Boss: The Crimson Widow.** Two phases (at 50% "She tears away the veil. There is nothing beneath it to pity."). Loot: Widow's Fangs, Widow's Thread, Vigil Gauntlets.
- First meeting: `widow_intro` ("That stance. I knew the soldier who taught it." / "I've never met you." / "No. But someone inside you has.").
- Death: `widow_death` ("You fight like six people I buried. And none of them." / Lyra: "She is yielding. Let her.").
- The yield-or-fight choice is listed as not built. PROPOSED rule: at the end of the fight the finisher prompt offers "Strike" or "Lower your blade". Lyra's existing line is the cue.
- PROPOSED `widow_yield` (not recorded), if spared:
  - Widow: "They built you out of my dead and sent you to finish our war."
  - Player: "Nobody sent me."
  - Widow: "Then find out who made you before you decide what you are for."
- PROPOSED `widow_memory` (not recorded): Archivist: "Subject: commander, mortal levy. Life extended without consent by experimental means. She asked to be allowed to stop. Request not processed."
- Story meaning: she is the first to recognise the donated memories. She confirms the Unbound's doubt is justified. The phase card ("nothing beneath it to pity") is from the older narrative and reads against the character bible, which lets her yield.

**Boss: The Cathedral Beast.** Two phases (at 60% "The bell above tolls once, by itself. The Beast rises onto two legs."). Weak to fire. No speech. Loot: Ashbrand, Cracked Handbell, Reliquary Door, Vigil Cuirass.
- First meeting: `beast_intro` (Lyra: "That was grown, not born. Do not look for a man inside it.").
- Death: `beast_death` ("They didn't pray here." / "Then what was this place?" / "A laboratory.").
- Story meaning: the genre turn. Beneath the fallen bell is a working facility. After this, Lyra stops speaking in fantasy terms.
- Disagreement: the intro card says "They prayed to be made strong enough to endure. They were answered." (the Beast as the congregation). Lyra's line says it was grown and there is no man inside it. The character bible says "engineered guardian".

---

## Chapter IV. The City of the Dead — The Sunken Crypt (`crypt`)
Ambience `crypt`. Music `explore_crypt` (missing), boss music `combat_b`. Shortcut: The Sluice Gate (`crypt_sluice`). What the player learns: the Unbound's origin; the Crown is eating the stored dead.

| # | Stage (data) | What happens | Dialogue | Collectibles |
|---|---|---|---|---|
| 0 | The Drowned Stair — fight `drowned_squire` / `tomb_mummer` | Lamps burning under water. | PROPOSED `crypt_0`, Lyra: "The lamps are under the water and still lit. Stop expecting fire to behave like fire." | Lore 20 PROPOSED: "Drowned Lamp" |
| 1 | The Ossuary (treasure: Vigil Greaves, 200 gold, 3 shards) or The Processional (fight `crypt_warden` / `crypt_crawler`) | More niches than dead. | PROPOSED `crypt_1`, Lyra: "Count the niches, not the skulls. There are more niches than this kingdom ever had dead." | Lore 21 PROPOSED: "The Newer Mortar" |
| 2 | The Weeping Tomb — fight `tomb_leech` | Something feeding on a storage unit. | PROPOSED `crypt_2`, Lyra: "It is drinking from that tomb. Whatever is inside is not ash." | Lore 22 PROPOSED: "Seepage" (coolant, not water) |
| 3 | Open the Sluice (lever, `crypt_sluice`) or The Dry Niche (shrine) | Drain the lower halls. | PROPOSED `crypt_3`, Lyra: "Drain it. I want to see what the river was let in to hide." | Lore 23 PROPOSED: "Flood Order" (who let the river in) |
| 4 | The Royal Vault (treasure: Vigil Helm, 300 gold, 4 shards; needs the sluice flag) or The Gallery of Kings (fight) | Defaced effigies. | PROPOSED `crypt_4`, Lyra: "Someone took a chisel to every king's face. They left the names." | Lore 24 PROPOSED: "Donor Plates" (six names; see quest 4) |
| 5 | Sit by the Lamp (shrine) | Last rest before the keeper. | PROPOSED `crypt_5`, Lyra: "Sit. There is something I have to tell you below, and I would rather you were rested." | Lore 25 PROPOSED: "Reliquary Lamp" |
| 6 | The First Tomb — boss `gravewarden` | See below. | PROPOSED `crypt_6`, Lyra: "He knows exactly what he keeps. Ask him." Then boss scenes. | Memory: `gravewarden_death` doubles as the record; Lore 26 PROPOSED: "Project Record: Unbound" |

**Boss: The Gravewarden.** Two phases (at 50% "The water rises to your knees. The dead are holding it up."). Weak to fire. Loot: Gravewarden's Zweihander, Vigil Greaves, Vigil Helm, Iron Band.
- First meeting: `gravewarden_intro` ("These are not tombs." / "What are they?" / "People waiting for someone to remember their names.").
- Death: `gravewarden_death` (Archivist: "You are not the first to enter this chamber. You are merely the first it has permitted to leave." / "History has been rewritten seventeen times. Would you prefer the surviving version?").
- The origin reveal belongs here by the story bible, but no existing line states it. PROPOSED `crypt_truth` (not recorded), after `gravewarden_death`:
  - Lyra: "I should have told you at the start. I was afraid of what you would do with it."
  - Player: "Tell me now."
  - Lyra: "You were not brought back. You were made. Soldiers, engineers, a baker, a girl of nine. They gave what they remembered so that one person could walk in here and not be owned."
  - Player: "Then whose life do I remember?"
  - Lyra: "All of theirs. And since the chamber, yours."
  - Archivist: "Correction for the record. The stored are decreasing. The Crown is spending them."
- PROPOSED `gravewarden_last` (not recorded), his own last words before the Archivist speaks: "I learned every name. Someone has to. It is you now."
- Story meaning: the tenderest guardian. He is not wrong to stand there; the thing he guards is being consumed behind him.
- Disagreement: the intro card says "He buried every king of this line. He does not intend to bury another." The character bible makes him keeper of stored minds, not of royal graves.

---

## Side chapter. The Wyrm's Roost (`roost`)
Ambience `wind`. Music `explore_roost` (missing), boss music `combat_b`. Shortcut: The Feeding Chain (`roost_chain`). What the player learns: the dragons were engineered siege weapons. The story bible says this region should become optional; in the data it is required (`citadel` requires `roost`).

| # | Stage (data) | What happens | Dialogue | Collectibles |
|---|---|---|---|---|
| 0 | The Glass Road — fight `scalebound` | Stone glazed by heat. | PROPOSED `roost_0`, Lyra: "Stone does not glaze by itself. Something breathed on this road." | Lore 27 PROPOSED: "Glazed Mile-Marker" |
| 1 | The Mews (fight `ash_falconer` / `scalebound`) or The Tack Room (treasure: Broodscale Gauntlets, 340 gold, 4 shards) | Perches at man height. | PROPOSED `roost_1`, Lyra: "Perches at the height of a man. They were not keeping falcons." | Lore 28 PROPOSED: "Long-Neck Harness" (with control ports) |
| 2 | The Boneyard — fight `cinder_whelp` | A young one, untaught. | PROPOSED `roost_2`, Lyra: "It hatched without a keeper. Nobody has told it what it was made for." | Lore 29 PROPOSED: "Feeding Schedule" |
| 3 | Free the Counterweight (lever, `roost_chain`) or The Keeper's Cell (treasure: Broodscale Greaves, 300 gold, 4 shards) | Shortcut choice. | PROPOSED `roost_3`, Lyra: "A feeding chain. Mind what it was built to lift." | Lore 30 PROPOSED: "Keeper's Last Entry" |
| 4 | The Clutch (treasure: Broodmother's Ember, 420 gold, 5 shards; needs the chain flag) or The Brood Guard (fight `scalebound` / `brood_keeper`) | Old shells and one new. | PROPOSED `roost_4`, Lyra: "The shells are numbered. Someone was counting a production run." | Lore 31 PROPOSED: "Shell Seventeen" |
| 5 | Bathe Your Hands (shrine) | Hot spring. | PROPOSED `roost_5`, Lyra: "The heat comes up through the rock. Use it. Do not ask it where it comes from yet." | — |
| 6 | The Summit — boss `cinder_wyrm` | See below. | PROPOSED `roost_6`, Lyra: "She has seen you. Walk out where she can see your hands. It will not help. Walk anyway." Then `wyrm_intro`. | Memory PROPOSED: `wyrm_memory` |

**Boss: Veyrath, the Cinder Wyrm.** Three phases (at 60% "She takes the air. The roost drops away beneath her and the wind turns hot."; at 28% "Her wing is torn through. She will not fly again. She does not need to."). Weak to frost. Loot: Wyrmfang, Broodscale Aegis, Broodscale Hauberk, Broodscale Helm, Broodmother's Ember.
- First meeting: `wyrm_intro` (Lyra: "They built her to break sieges. She has had centuries to decide what else she is.").
- No death scene exists. PROPOSED `wyrm_death` (not recorded): Lyra: "She was the only thing in this kingdom that never took an order. I am sorry it was us." PROPOSED `wyrm_memory` (not recorded): Archivist: "Asset: siege platform, brood two. Deployment orders issued: none. Reason not recorded."
- Story meaning: a weapon that outlived its purpose and became an animal. The only guardian with nothing to say and nothing to regret.
- Disagreement: the character bible says she was "woken under a volcanic fortress"; the region data calls the place a "high crag where the royal dragons were stabled" and says she "was never sent to war".

---

## Chapter V. The King Who Refused Eternity — The Frozen Citadel (`citadel`)
Ambience `wind`. Music `explore_citadel` (missing), boss music `combat_b`. Shortcut: The Ice Lift (`citadel_lift`). What the player learns: how the Crown can be divided.

| # | Stage (data) | What happens | Dialogue | Collectibles |
|---|---|---|---|---|
| 0 | The Frozen Rank — fight `frost_thrall` | Soldiers frozen upright in ranks. | PROPOSED `citadel_0`, Lyra: "They froze standing. That was an order, not weather." | Lore 32 PROPOSED: "Standing Order" |
| 1 | The Wall Walk (fight `rime_duelist` / `rime_glaive`) or The Armoury (treasure: Rimebound Gauntlets, 320 gold, 4 shards) | A duellist drilling alone. | PROPOSED `citadel_1`, Lyra: "He has drilled that form every day for three hundred years. He will be very good at it." | Lore 33 PROPOSED: "Frozen Rack" (relic blades with dead power cells) |
| 2 | The Kennel Stair (fight `frost_thrall` / `frost_drake`) or The Pit (optional boss `rimewyrm`) | The optional dragon. See below. | PROPOSED `citadel_2`, Lyra: "Whatever is on that chain, the king did not trust it loose. Consider whether you do." | Lore 34 PROPOSED: "Kennel Ledger" |
| 3 | Break the Ice (lever, `citadel_lift`) or The Brazier (shrine) | Shortcut choice. | PROPOSED `citadel_3`, Lyra: "The cold here is kept, not fallen. Somewhere under us a machine is making winter." | Lore 35 PROPOSED: "The Kept Fire" |
| 4 | The Great Stair — fight `glacier_brute` / `hoarbeast` | Part of the wall steps out. | PROPOSED `citadel_4`, Lyra: "The wall just moved. I am sorry. I have nothing cleverer." | — |
| 5 | The Solar (treasure: Hoarfrost Loop, Rimebound Helm, 400 gold, 5 shards; needs the lift flag) or The Window Seat (shrine) | The queen's room. | PROPOSED `citadel_5`, Lyra: "A queen sat here. She is not in any record I can reach. Someone removed her carefully." | Lore 36 PROPOSED: "The Queen's Refusal" (a letter declining transfer); Lore 37 PROPOSED: "Partition Key" (the division method) |
| 6 | The Winter Throne — boss `frostbound_king` | See below. | PROPOSED `citadel_6`, Lyra: "He was one of the first of them. He shut this door from the inside." Then boss scenes. | Memory PROPOSED: `frostking_memory` |

**Optional boss: Skeldra, the White Ruin.** Two phases (at 50% "The chain snaps. It looks at the broken link for a long moment, and then at you."). Weak to fire. Loot: Rimeglass Sabre, Rimebound Greaves, Rimebound Gauntlets.
- No dialogue of any kind exists and there is no voice key for `rimewyrm`. PROPOSED `rimewyrm_intro` (not recorded), Lyra: "It was told to stay. The chain was only ever a reminder." PROPOSED `rimewyrm_death` (not recorded), Lyra: "It waited three hundred years for someone to tell it otherwise."
- Story meaning: obedience as a prison; the animal mirror of the Sentinel.

**Boss: The Frostbound King.** Three phases (at 66% "Frost climbs the walls. Your breath hangs in front of you and stays there."; at 33% "The crown cracks. Winter is no longer something he commands. It is something he is."). Weak to fire. Loot: Winter's Verdict, Glacier Ward, Frozen Tear, Rimebound Cuirass, Hoarfrost Loop.
- First meeting: `frostking_intro` ("I watched men become gods. Then I watched gods become machines." / "Why didn't you destroy the Crown?" / "Because there were still people inside it.").
- Later attempts: `frostking_retry` ("Every resurrection makes the chains harder to break.").
- Death: `frostking_death` ("Go to the capital. Do better than we did. It will not be difficult.").
- The chapter's lesson (how the Crown can be divided) is not in any existing line. PROPOSED `frostking_memory` (not recorded):
  - Archivist: "Subject: Everbound, first cohort. Petitioned to end his own continuity. Petition denied by the network."
  - Frostbound King (recorded voice): "It was built as one thing so that one hand could hold it. Break it into many and no hand can. I had the key. I lacked the nerve."
- Story meaning: an immortal who tried to stop and could only freeze. He hands over the method for the third ending and expects to be surpassed.

---

## Secret chapter. The Hollow Deep (`deep`)
Ambience `crypt`. Music `explore_deep` (missing), boss music `final`. Shortcut: The Unlit Stair (`deep_stair`). What the player learns: the minds the system failed. Unlocks the third ending. In the data this region is required (`throne` requires `deep`) and its boss is not marked optional.

| # | Stage (data) | What happens | Dialogue | Collectibles |
|---|---|---|---|---|
| 0 | The Long Stair — fight `husk` | People facing the wall. | PROPOSED `deep_0`, Lyra: "Do not speak to them. There is nobody to answer, and something that listens." | Lore 38 PROPOSED: "Discard Manifest" |
| 1 | The Gallery of Names (fight `soul_eater`) or The Unread Wall (treasure: Hollowed Gauntlets, 520 gold, 6 shards) | Names licked smooth. | PROPOSED `deep_1`, Lyra: "These are the ones the system could not keep whole. It kept them anyway." | Lore 39 PROPOSED: "Surviving Names" (see quest 6) |
| 2 | The Grain — fight `soul_eater` / `name_thief` | The dark has structure. | PROPOSED `deep_2`, Lyra: "I am losing you down here. If my voice changes, it is not me." | Lore 40 PROPOSED: "Growth Medium" |
| 3 | Mark the Way (lever, `deep_stair`) or The Last Candle (shrine) | A stair up to the Sanctuary. | PROPOSED `deep_3`, Lyra: "Candle smoke. That stair comes up under the sanctuary. This was beneath us the whole time." | Lore 41 PROPOSED: "The Carried Candle" |
| 4 | The Oath Hall (fight `oath_eater` / `the_unburied`) or The Reliquary of Vows (treasure: Hollowed Greaves, Hollowed Helm, 600 gold, 7 shards; needs the stair flag) | Empty banners. | PROPOSED `deep_4`, Lyra: "They swore here to keep the stored safe. The words were the first thing it ate." | Lore 42 PROPOSED: "One Vow, Kept" |
| 5 | Rest in the Emptied Place (shrine) | Nothing left to take. | PROPOSED `deep_5`, Lyra: "There is nothing left here to take. Rest. It is the only mercy this place has." | — |
| 6 | The Bottom — boss `devourer` | See below. | PROPOSED `deep_6`, Lyra: "It will use voices you know. Some of them are yours." Then boss scenes. | Memory PROPOSED: `devourer_memory`; item Your Name (always drops) |

**Boss: The Devourer of Names.** Three phases (at 50% "It opens. Inside it is every face it has taken. Some of them know you."; at 0% it revives at 45% health: "It falls, and is still. Then it says your name — the one you had before — and stands."). Loot: The Twin Hungers, Your Name, Hollowed Cuirass.
- First meeting: `devourer_intro` ("I had a daughter." / "I remember the sea." / "Please. What was my name?").
- No death scene exists. PROPOSED `devourer_death` (not recorded):
  - Devourer (a woman): "Is someone there?"
  - Player: "Yes."
  - Devourer (a child): "Will you say us? Any of us. Just once."
  - Player: (if quest 6 is complete, the player reads the surviving names; otherwise) "I don't know them. I'm sorry."
- PROPOSED `devourer_memory` (not recorded): Archivist: "Records: nine thousand, fragmentary. Status: unrecoverable. Status amended: witnessed."
- Story meaning: not a monster but a remainder. The fight should be the saddest in the game.
- Disagreements: the intro card says it "ate the kingdom's dead" and "knows what you were called", and the revive card speaks of "the name you had before". The story bible says the Unbound is a new person with no prior self. The voice bible calls it "what the crown made of a father"; the character bible says centuries of discarded memories with many voices.

---

## Chapter VI. The Hollow Throne (`throne`)
Ambience `wind`. Music `explore_throne` (missing), boss music `final`. Shortcut: The King's Door (`throne_door`). The choice.

| # | Stage (data) | What happens | Dialogue | Collectibles |
|---|---|---|---|---|
| 0 | The Royal Mile — fight `throne_guard` | Statues with the faces struck off. | PROPOSED `throne_0`, Lyra: "Every face struck off. The people did that. Then they forgot why." | Lore 43 PROPOSED: "The Signal Mast" (the broadcast from the capital) |
| 1 | The Antechamber (fight `kingsblade` / `herald`) or The Treasury (treasure: Monarch's Gauntlets, Monarch's Greaves, 600 gold, 6 shards) | A blade who bows. | PROPOSED `throne_1`, Lyra: "He bows because the form requires it. Bow back if you like." | Lore 44 PROPOSED: "Empty Treasury" (spent on keeping the machines fed) |
| 2 | The Steps — fight `crownless` | A figure turning a crown over. | PROPOSED `throne_2`, Lyra: "It wore a crown once. The network kept the habit and lost the man." | Lore 45 PROPOSED: "A Crown, Unplugged" |
| 3 | Unlock the King's Door (lever, `throne_door`) or The Chapel Royal (shrine) | Shortcut choice. | PROPOSED `throne_3`, Lyra: "Stewards use the side door. He was never a king. Remember that when he speaks like one." | Lore 46 PROPOSED: "Letter of Appointment" (the Monarch named steward during the collapse) |
| 4 | The Last Post (fight `throne_guard` / `throne_colossus`) or Behind the Throne (treasure: Hollow Heart, 800 gold, 8 shards; needs the door flag) | The last unrelieved guard. | PROPOSED `throne_4`, Lyra: "Not relieved. You have met his kind before. Be quick with him." | Lore 47 PROPOSED: "The Count" (the Monarch's ledger of lives spent and lives kept) |
| 5 | Steady Yourself (shrine) | The open doors. | PROPOSED `throne_5`, Lyra: "Whatever you decide in there, I asked you to come. I am not asking you to choose for me." | — |
| 6 | The Hollow Throne — boss `forgotten_monarch` | See below. | Boss scenes. | Lore 48–50 PROPOSED: "Lyra's Cradle", "External Handshake Log", "The First Donor" |

**Boss: The Forgotten Monarch.** Three phases (at 66% "The Monarch rises from the throne at last. The hall remembers how to kneel."; at 33% "The crown burns white. Every king this hall has ever held stands up inside him."). Loot: Eternal Edge, Sliver of the Crown, Monarch's Cuirass, Monarch's Helm. The regeneration phase named in the story bible is not built.
- First meeting: `monarch_intro` (five lines, ending "Enough to ensure there are still people left to ask that question.").
- Later attempts: `monarch_retry` ("You still believe death cannot teach you surrender.").
- Death: `monarch_death` ("I have counted every life this machine has taken. Have you counted the lives it has saved?" / Lyra: "I think I remember the rain." / "Tell me about it.").
- Story meaning: a steward, not a tyrant, who has done the arithmetic. He must be answerable, and the player should leave the fight less sure than they entered it.
- Disagreement: the intro card says "You knelt to this crown once. It remembers. You do not." and the title is "Last Ruler of the Fallen Realm". The story bible says the Unbound never existed before the chamber, and the character bible says the Monarch is "not an emperor: a steward".

---

## The three endings
*Chosen by the Last Heir, beneath the throne, after the door. The Free Cities also needs the Kept to have been faced and let go.*
The endings and their choice are not built. Outcomes are from the story bible. All trigger conditions and lines below are PROPOSED (not recorded) except where the bible states them.

| Ending | Outcome (story bible) | Condition (PROPOSED unless noted) |
|---|---|---|
| 1. The Final Silence | The Crown is disconnected. Immortality ends. The archives, and Lyra, are lost. Sunrise. | After `monarch_death`, choose "Silence it" at the Crown. Always available. |
| 2. The Last Steward | The Unbound takes over the Crown without the Monarch's methods. Deliberately ambiguous. | Choose "Take the seat". Always available. |
| 3. The Free Cities | The Crown is split into independent systems nobody can rule; the stored choose to stay, be re-embodied or let go; Lyra may exist outside the network. | Story bible: needs the optional quests, recovered memories and the Devourer defeated. PROPOSED detail: quests 4, 5, 6 and 8 complete; every boss memory seen; lore 37 "Partition Key" found; Devourer defeated. The third option "Divide it" then appears. |

Note: with the present region chain the Devourer is always defeated before the throne, so that condition cannot fail until the Deep is made optional.

PROPOSED ending lines (not recorded):
- Ending 1 — Lyra: "It is quieter already. I did not expect it to be gentle." / Player: "Lyra." / Lyra: "The rain. Tell me about it. Quickly."
- Ending 2 — Player: "No one is spent. Not one." / Lyra: "Everyone who sat there began by saying that." / Player: "Then stay and count for me."
- Ending 3 — Archivist: "Partition accepted. There is no longer a centre. Record complete." / Lyra: "I can feel the edge of it. There is an outside." / Player: "Then come and see it."
- Post-credits (story bible text): a far fortress under an unfamiliar sky, a machine waking. On-screen text: "Local network disconnected. Searching for external systems." A distant signal answers. No speech.

---

## Optional quests — all PROPOSED
None of these exist in data or code. Each is tied to an existing character and to real stage locations.

| # | Quest | Giver | Steps | Outcome |
|---|---|---|---|---|
| 1 | The Relief of the Gate | Lyra (after `sentinel_memory`) | Find the Garrison Roll in the Guardhouse (courtyard 1). Return to the Inner Ward (courtyard 6) and read the relief order aloud. | Closes the Sentinel's question. Unlocks lore 2. PROPOSED line, Player: "Sergeant. You are relieved." |
| 2 | Older Than My Bloodline | Orren | Bring three relic cores: the Well (courtyard 3), the Charcoal Burner's Hut (blackwood 3), the Armoury (citadel 1). | Orren shows his family's engineering scraps and begins to trust the Unbound. Unlocks top-tier upgrades. PROPOSED line, Orren: "My grandmother called it prayer. It was a wiring diagram." |
| 3 | What the Kings Bred | Pale Huntsman (only if he yielded) | Show him the Long-Neck Harness (roost 1) and the Kennel Ledger (citadel 2). | He accepts the Unbound is not the tyranny returning. He appears at the Summit and weakens Veyrath's first phase. If he was killed, the quest never opens. |
| 4 | Six People I Buried | Crimson Widow (only if she yielded) | Find the six Donor Plates in the Gallery of Kings (crypt 4). Return to the Cathedral Steps. | She names the six. The Unbound gains six memory fragments. Required for ending 3. |
| 5 | The Surviving Version | The Archivist (after `gravewarden_death`) | Recover 30 of the 50 lore discoveries. | The Archivist states the unrewritten record. Required for ending 3. PROPOSED line, Archivist: "Version zero. Not surviving. True. I had forgotten there was a difference." |
| 6 | Names for the Waiting | The Gravewarden's lantern (left at the First Tomb) | Copy the surviving names from the Unread Wall (deep 1). Read them at the First Tomb (crypt 6). | Changes `devourer_death`. Required for ending 3. |
| 7 | The Chain That Stayed | Lyra, at the Kennel Stair | Before entering the Pit, break the frozen link from above (needs the Ice Lift). | Skeldra starts unchained and in its second phase, and can be let go at posture break instead of killed. |
| 8 | The Rain | Lyra (after `beast_death`) | Find Lyra's Cradle: clues in the Lower Facility (cathedral 6), the Project Record (crypt 6) and the throne room. | Establishes where Lyra's mind is held, so that ending 3 can carry her out. Required for ending 3. |

---

## New Game Plus
The master requirements list New Game Plus. Items marked "Only offered to those who return" exist (Oathbreaker, Embertwin, Hollow Heart). PROPOSED: on a second cycle the opening is replaced by a single Lyra line (not recorded): "You came back by the long way this time." and the Archivist's "seventeen times" becomes "eighteen".

## The Witness and who speaks (added 2026-11-26)
The Witness is the second companion (`STORY_BIBLE.md`, "The Witness"). All of the lines below exist in `data/dialogue.json` as text only: none is recorded, and the game shows them as subtitles. `src/core/companion.gd` (autoload `Companion`) decides what plays: each scene once per save, never again after a death; a 20 second gap between unprompted remarks; at most two remarks at a stop (Lyra's first); nothing during a fight; nothing from the Witness before it is found; with the `chatter` setting off, only the scenes marked essential.

**Discovery.** Chapter I, the Fallen Courtyard, stage 1 (the stop after The Breach, where the path divides). The monument of the thirteen kings has fallen; under the plinth is a walled chamber, and the mask hangs in it. Scene `witness_discovery` (essential) plays on arrival, before the choices appear:

- Lyra: "Wait. Under the fallen plinth. There is a door there that is on no plan I hold."
- The Witness: "Ah. At last. I had begun to suspect the dead were better company."
- Player: "What are you?"
- The Witness: "A witness to rather more than I would care to remember."
- The Witness: "And to rather less than I ought. They took a good deal out of me before they shut that door."
- Player: "Who did?"
- The Witness: "If I knew that, I should be a happier ornament. Lift me down. I weigh very little, and I know this road."
- Lyra: "I do not know what that is. I do not like not knowing."
- The Witness: "The voice in the walls disapproves of me. Good. We shall get on."

Lyra's `courtyard_1` remark is held over to the next visit to that stop. A save already past stage 1 plays the discovery at the next stop reached, in any region.

**Speech categories** (`speech` in `data/dialogue.json`; unlisted foes are A):

| Category | Foes | What the duel does |
|---|---|---|
| A, no human speech | `cathedral_beast`, `cinder_wyrm`, `rimewyrm`, `azhurion`, all lesser foes | No voice key, so no `_intro`, `_retry`, `_death`. The Witness sets the scene before the fight (essential scenes `w_beast_approach`, `w_wyrm_approach`, `w_rimewyrm_approach`, `w_azhurion_approach`); if the Witness cannot speak, Lyra's older `beast_intro` / `wyrm_intro` play instead. `beast_death` (Lyra, "A laboratory.") now plays as the first victory scene. |
| B, a few short lines | `ashen_sentinel` (4 lines), `hollow_executioner` (2), `gravewarden` (2) | Unchanged scenes, except `sentinel_retry` was cut. The generator refuses more than four lines for a B foe. |
| C, directed dialogue | `forgotten_monarch`, `crimson_widow`, `frostbound_king`, `pale_huntsman` | Unchanged. |
| D, fragments | `devourer` | `devourer_intro` rewritten as whispers ("...a daughter... I had..." / "...the sea... the sea..." / "...my name... what was... my name..."); new `devourer_death` in the same manner. Its three recorded takes no longer match and are not played. |

Order at a guardian: Witness approach scene, then the guardian's own `_intro`, the fight, `_death`, `_memory`, then the victory scenes.

**The Witness on the road.** Stage numbers are the indices in `data/regions.json`. "memory" marks a returning memory.

| Region | Stage | Scene | Line |
|---|---|---|---|
| The Fallen Courtyard | 2 | `w_courtyard_approach` (approach) | "So this is what became of the outer court. It had a grander name when it stood. I forget it. Mercifully." |
| The Fallen Courtyard | 3 | `w_courtyard_gate` | "That gate once bore the banners of thirteen kings. Now look at it. Eternity has a peculiar sense of humour." |
| The Fallen Courtyard | 4 | `w_courtyard_passage` | "They built the passage narrow so that one man could hold it. Nobody asked which man." |
| The Fallen Courtyard | 5 | `w_courtyard_candle` | "A candle three hundred years alight. In my day we called that a miracle. We were paid to." |
| The Blackwood | 0 | `w_blackwood_approach` (approach) | "The Blackwood. The lanterns are still lit. Somebody is paying the lamplighter, and I should like to know in what coin." |
| The Blackwood | 2 | `w_blackwood_briars` | "Woven. Thorn does not plait itself. Somebody here still keeps a boundary." |
| The Blackwood | 3 | `w_blackwood_bridge` (memory) | "There was a toll on this crossing, and a clerk. He counted heads going in. He did not count them coming out." |
| The Blackwood | 5 | `w_blackwood_gibbet` | "A gallows over the drinking water. There is the old kingdom entire, in one view." |
| The Cathedral of Ash | 0 | `w_cathedral_approach` (approach) | "I climbed these steps once, in a procession. I remember the incense. I do not remember what we were asking for." |
| The Cathedral of Ash | 1 | `w_cathedral_censer` | "A censer that size is not for perfume. It is for covering the smell of something else." |
| The Cathedral of Ash | 3 | `w_cathedral_nave` (memory) | "The roof came down in the Rising. I was here. No. I was told I was here. The two are not the same, and I can no longer tell them apart." |
| The Cathedral of Ash | 4 | `w_cathedral_choir` | "Still singing. That hymn has forty verses. I should not stay for the last." |
| The Sunken Crypt | 0 | `w_crypt_approach` (approach) | "Lamps under the water, and burning yet. Do you know, I helped consecrate this place. I cannot recall to whom." |
| The Sunken Crypt | 1 | `w_crypt_ossuary` | "Those are for show. The dead that mattered are kept lower down, and a great deal more carefully." |
| The Sunken Crypt | 3 | `w_crypt_sluice` | "Drain it, by all means. But they flooded the lower halls on purpose. One ought always to wonder why." |
| The Sunken Crypt | 4 | `w_crypt_door` (memory) | "That door. I have stood before it with a ledger. Names down one column. I cannot see the heading of the other." |
| The Wyrm's Roost | 0 | `w_roost_approach` (approach) | "Glazed stone. I have seen a wall run like wax before. Never from the outside." |
| The Wyrm's Roost | 1 | `w_roost_mews` | "They called this the Mews. One learns a great deal about a court from the things it calls small." |
| The Wyrm's Roost | 3 | `w_roost_chain` | "A feeding lift. The cage was for cattle. Mostly." |
| The Wyrm's Roost | 4 | `w_roost_shells` (memory) | "Numbered shells. Somebody kept a tally. Somebody always does. It was usually me." |
| The Frozen Citadel | 0 | `w_citadel_approach` (approach) | "Dressed by the right, and frozen so. Weather has no sense of drill. Somebody gave a last command here." |
| The Frozen Citadel | 1 | `w_citadel_wall` | "This wall was never taken. It was closed, from within, and left." |
| The Frozen Citadel | 3 | `w_citadel_lift` | "This cold is made, not fallen. Somewhere beneath us a great deal of effort is spent keeping one man from thawing." |
| The Frozen Citadel | 5 | `w_citadel_solar` (memory) | "A queen sat at that window. I struck her name from the rolls with my own hand. I was ordered to. I think that is where I began to refuse." |
| The Hollow Deep | 0 | `w_deep_approach` (approach) | "No. I do not know this stair. I knew every stair they built. Either this was dug afterwards, or it was taken out of me." |
| The Hollow Deep | 1 | `w_deep_names` (memory) | "Names, floor to roof. I cut the first of these. That was my office: to set down who a person was, before." |
| The Hollow Deep | 3 | `w_deep_stair` | "Candle smoke. So this lay under your sanctuary the whole while. Your voice in the walls might have mentioned it." / Lyra: "I did not know." / "No. I do not suppose you were permitted to." |
| The Hollow Deep | 4 | `w_deep_oaths` (memory) | "They swore here to keep the stored safe. I administered the oath. It was a good oath. It deserved better men." |
| The Hollow Throne | 0 | `w_throne_approach` (approach) | "The royal mile. Every face struck off. I approve the sentiment and regret the workmanship." |
| The Hollow Throne | 1 | `w_throne_hooks` | "Thirteen banners hung in this room also. Count the hooks, if you doubt me." |
| The Hollow Throne | 2 | `w_throne_crown` (memory) | "There. Now I have it. They did not shut me away for what I knew. They shut me away because I would not unwrite it." |
| The Hollow Throne | 4 | `w_throne_guard` | "Unrelieved. Like the first one you met. It is the same order, you know. Only the handwriting differs." |

**Before and after the guardians.**

| Foe | Before (`approach`) | After (`victory`) |
|---|---|---|
| `ashen_sentinel` | `w_sentinel_approach` The Witness: "He will ask your allegiance. There is no right answer. There never was one." / Player: "Then he will have the true one." | `w_sentinel_victory` The Witness: "One winter, they told him. I believe I wrote that order down. I hope I argued." |
| `pale_huntsman` | `w_huntsman_approach` The Witness: "Someone has kept pace with us these three trees. A mortal, by the breathing. Be civil. He has earned his opinions." | `w_huntsman_victory` The Witness: "He was not wrong to fear what we were. Only late." |
| `hollow_executioner` | `w_executioner_approach` The Witness: "Every stump a block. He has not stopped working. He has only run short of the condemned." / Player: "And now?" / The Witness: "Now he has you. Do try to be a disappointment to him." | `w_executioner_victory` The Witness: "The court that passed those sentences was dissolved before your grandmother's grandmother. Nobody told the axe." |
| `crimson_widow` | `w_widow_approach` The Witness: "I know that bearing. Rebels stand straighter than kings. They have to." / Player: "She is waiting for me." / The Witness: "She is waiting for someone. Find out whom before you draw." | `w_widow_victory` The Witness: "She yielded. In my day that took more courage than dying. It still does." |
| `cathedral_beast` | `w_beast_approach` The Witness: "Stop. Listen. What breathes under that bronze was built in a laboratory." / Player: "What was it built for?" / The Witness: "Nothing merciful." | `w_beast_victory` The Witness: "A workshop under an altar. I should like to say I am surprised. I think I signed for the candles." |
| `gravewarden` | `w_gravewarden_approach` The Witness: "The keeper. He is the gentlest thing down here, and he will kill you for a careless word." / Player: "What does he keep?" / The Witness: "Ask him. He has waited long enough to be asked." | `w_gravewarden_victory` The Witness: "He remembered their names. Every one. I was paid to remember, and I cannot manage my own." |
| `cinder_wyrm` | `w_wyrm_approach` The Witness: "There she is. Veyrath. They made her to end sieges, and then they ran out of walls." / Player: "Can it be killed?" / The Witness: "Everything can be killed. Convincing it of that is the difficult part." | `w_wyrm_victory` The Witness: "She never once took an order. I envied her that. I believe I still do." |
| `rimewyrm` | `w_rimewyrm_approach` The Witness: "Something on a chain, down there. A chained thing in a king's cellar is never a pet." / Player: "Then what is it?" / The Witness: "A decision he could not bring himself to make." | `w_rimewyrm_victory` The Witness: "It could have left at any hour. So could most of us." |
| `frostbound_king` | `w_frostking_approach` The Witness: "I knew him. He is the only one of them who ever asked to stop." / Player: "Did they let him?" / The Witness: "Look at the door. He had to let himself." | `w_frostking_victory` The Witness: "Do better than we did, he says. He always set the mark where a man might reach it." |
| `devourer` | `w_devourer_approach` The Witness: "Do not answer it, whatever it asks. It is not one voice, and not one of them is lying." / Player: "Who were they?" / The Witness: "The ones we lost count of. I begin to think I kept the count." | `w_devourer_victory` The Witness: "Say what names you have. I will hold the rest, now that I remember how." |
| `azhurion` | `w_azhurion_approach` The Witness: "That is the first of them. The Last Wing. Nobody wrote down how to stop it. I looked." / Player: "Then how?" / The Witness: "The usual way. Slowly, and at great personal cost." | `w_azhurion_victory` The Witness: "The oldest thing they built, and it ends in a doorway. There is a moral in that. I decline to draw it." |
| `forgotten_monarch` | `w_monarch_approach` The Witness: "He will be reasonable. That is the danger of him. I served reasonable men all my life." / Player: "And?" / The Witness: "And here I hang at your belt. What is decided in there is yours to decide. I shall only witness it." | `w_monarch_victory` The Witness: "Whatever you do next, I will set it down as it happened. That much I can still swear to." |

**Sanctuary conversations** (optional, from `Companion.sanctuary_topics()`; no screen lists them yet).

| Scene | Title | Opens | Speakers | First line |
|---|---|---|---|---|
| `w_talk_mask` | The Mask | once the Witness is found | Player, The Witness | "The mask. Was it your face?" |
| `w_talk_sword` | On Old Weapons | once the Witness is found | Player, The Witness | "This sword. They say it is enchanted." |
| `w_talk_lyra` | The Voice in the Walls | once the Witness is found | The Witness, Lyra | "Your Lyra says she has waited a very long time. Ask her how she knows how long." |
| `w_talk_return` | Coming Back | once the Witness is found | Player, The Witness | "I die, and I wake here. What does that make me?" |
| `w_talk_smith` | The Smith | once the Witness is found | Player, The Witness | "Orren does not trust you." |
| `w_talk_kings` | Thirteen Kings | after The Fallen Courtyard | Player, The Witness | "Thirteen kings. Did you know them?" |
| `w_talk_people` | They Were People | after The Fallen Courtyard | Lyra, The Witness | "They were people. Every one you have cut down." |
| `w_talk_silence` | The Great Silence | after The Blackwood | Lyra, The Witness | "The Silence came without warning. One night the far towns simply stopped answering." |
| `w_talk_prayer` | What We Prayed To | after The Cathedral of Ash | Player, The Witness | "You prayed in that cathedral." |
| `w_talk_stored` | The Stored | after The Sunken Crypt | Lyra, The Witness | "The stored can be saved. All of them. I have to believe that." |
| `w_talk_refusal` | The Eighteenth Time | after The Frozen Citadel | The Witness, Player | "It has come back, a little. There was a list. Places, and what was done in them." |
| `w_talk_choice` | The Choice Ahead | after The Frozen Citadel | Player, The Witness | "When we reach the capital. What would you do?" |

**Not from the brief verbatim.** The brief's example exchanges were available only as the fragments quoted in the work order and the casting reel: the discovery lines, the thirteen kings line, "built in a laboratory" / "What was it built for?" / "Nothing merciful.", and "Can it be killed?" / "Everything can be killed. Convincing it of that is the difficult part." are used as given. The Frostbound King exchange and the old-weapon exchange were written fresh; if the brief's wording differs, replace them in `tools/gen_dialogue.py`.

## Open contradictions
1. **Two narratives in shipping text.** Region blurbs and boss intro cards (`data/regions.json`, `data/bosses.json`) describe a player who once served this kingdom ("The gate you once rode out of", "You knelt to this crown once", "You have been here before. You are always here before.", "the name you had before"), a Widow "promised a wedding", a Beast that "the congregation became", a Gravewarden who "buried every king". The story bible describes a newly made person and guardians with different histories. Item text also carries the older reading ("The sword you were buried with", "Your Name — You do not remember it").
2. **Optional regions.** Bible: Roost and Deep optional or secret. Data: required chain courtyard → blackwood → cathedral → crypt → roost → citadel → deep → throne.
3. **Chapter VI location.** The bible's table says "The former capital"; the region is named "The Hollow Throne". The Deep's blurb places it "under the throne" although it is entered before the throne region.
4. **Boss count.** Master requirements: "nine bosses plus the Devourer and three dragons". The data has eight non-dragon guardians (Sentinel, Executioner, Huntsman, Widow, Beast, Gravewarden, Frostbound King, Monarch), the Devourer and two dragons. Azhurion is not in the game; the ninth guardian is not identified in any document.
5. **Character descriptions.** `VOICE_BIBLE.md` and `CHARACTER_BIBLE.md` differ on the Widow (duelist who knew your teacher, courteous; versus rebel commander, bitter), the Monarch (last wearer of the crown; versus steward, not an emperor), the Devourer (made of a father; versus many discarded minds), Orren (smith and trainer who has buried many like you; versus smith who distrusts the Unbound), the Huntsman (amused; versus cold, tired), the Executioner (bored clerk; versus toneless, certain), Lyra's age (30s; versus young adult) and the narrator (outside the story; versus possibly Lyra long ago).
6. **Veyrath's home.** Character bible: under a volcanic fortress. Region data: a high crag stable; "never sent to war". Lyra's line: built to break sieges.
7. **Implementation status wording.** The bible says first-meeting and death exchanges exist "for the other guardians". Missing today: any Huntsman death or yield scene, any Veyrath death scene, any Devourer death scene, all Skeldra dialogue.
8. **Stage remarks.** Only the Courtyard has them. The other 49 stage remarks above are proposals.
