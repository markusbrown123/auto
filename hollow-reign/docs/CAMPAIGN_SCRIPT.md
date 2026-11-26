# Hollow Reign: campaign script

Beat-by-beat campaign, written 2026-11-26 from `STORY_BIBLE.md`, `WORLD_HISTORY.md`, `CHARACTER_BIBLE.md`, `data/regions.json`, `data/bosses.json` and `data/dialogue.json`. Canon is the story bible. Stage names, hints, foes and loot are quoted from the data files as they are today.

## How to read this
- **Scene id** means a key under `scenes` in `data/dialogue.json`. Every id cited without a marker exists today (83 lines, 41 scenes, 97 voice files; the voice files are provisional and unheard).
- **PROPOSED (not recorded)** means the line or scene does not exist in `data/dialogue.json`, has no audio, and is a suggestion only.
- Stage remarks are played by `src/ui/explore.gd` and `src/cine/cine_road.gd` as scene `<region id>_<stage index>`. Only `courtyard_0` to `courtyard_6` exist. The proposed remarks below use that same id pattern so they would play with no code change once added.
- Boss scenes are played by `src/combat/duel.gd` as `<key>_intro` (first meeting), `<key>_retry` (later attempts), `<key>_death` and `<key>_memory` (after a win). Keys: sentinel, executioner, huntsman, widow, beast, gravewarden, frostking, wyrm, devourer, monarch. Skeldra (`rimewyrm`) has no key.
- Lore discoveries: the story bible lists "the 50 lore discoveries" as not built. All 50 named here are PROPOSED. Treasure contents (items, gold, shards) are real data.

## Source disagreements that affect the script
These are recorded, not resolved. Section "Open contradictions" at the end lists them in full.
- The boss intro cards and region blurbs in `data/bosses.json` and `data/regions.json` tell an older story (kings, weddings, a kingdom the player once served). The story bible says the 2026-11-25 brief "replaces all earlier narrative". Both texts are currently shown to the player.
- `data/regions.json` makes all eight regions a single required chain. The story bible says the Wyrm's Roost and the Hollow Deep should be optional or secret.

## Prologue: the opening and the chamber

| Beat | What happens | Scene ids |
|---|---|---|
| Opening | Black screen, narrator over the main theme. Six lines of history: mortals, the Everbound, the fall, three hundred years, "We were wrong." | `opening` |
| Awakening | Fade up on the damaged resurrection chamber under the fortress (the Sanctuary set). Lyra speaks first. The Unbound admits to memories they could not have. | `awakening` |
| First road | Lyra sends the Unbound up and out, and explains tap-to-move in fiction. | `first_road` |
| Return visits | After a death: one of six Lyra lines, chosen at random. After the Courtyard is cleared: Lyra greets the return and points at the smith. | `rebirth_0` … `rebirth_5`, `sanctuary_return` |
| Orren | First talk at the forge, then an idle line on later visits. | `orren_intro`, `orren_idle` |

Notes
- `rebirth_*` is picked with `randi() % 6`. The lines read as a progression (0 "sooner than I expected" to 5 "you don't owe the dead your future") but they do not play in order. PROPOSED: index by death count, capped at 5.
- The story bible places meeting Orren in Chapter II. In the game he is in the Sanctuary from the start and `sanctuary_return` introduces him after the Courtyard, which fits Chapter II.

---

## Chapter I. The Broken Oath — The Fallen Courtyard (`courtyard`)
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
- First meeting: `sentinel_intro` ("State your allegiance." / "I serve no crown." / "Then you have no passage."). Later attempts: `sentinel_retry`.
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

## Open contradictions
1. **Two narratives in shipping text.** Region blurbs and boss intro cards (`data/regions.json`, `data/bosses.json`) describe a player who once served this kingdom ("The gate you once rode out of", "You knelt to this crown once", "You have been here before. You are always here before.", "the name you had before"), a Widow "promised a wedding", a Beast that "the congregation became", a Gravewarden who "buried every king". The story bible describes a newly made person and guardians with different histories. Item text also carries the older reading ("The sword you were buried with", "Your Name — You do not remember it").
2. **Optional regions.** Bible: Roost and Deep optional or secret. Data: required chain courtyard → blackwood → cathedral → crypt → roost → citadel → deep → throne.
3. **Chapter VI location.** The bible's table says "The former capital"; the region is named "The Hollow Throne". The Deep's blurb places it "under the throne" although it is entered before the throne region.
4. **Boss count.** Master requirements: "nine bosses plus the Devourer and three dragons". The data has eight non-dragon guardians (Sentinel, Executioner, Huntsman, Widow, Beast, Gravewarden, Frostbound King, Monarch), the Devourer and two dragons. Azhurion is not in the game; the ninth guardian is not identified in any document.
5. **Character descriptions.** `VOICE_BIBLE.md` and `CHARACTER_BIBLE.md` differ on the Widow (duelist who knew your teacher, courteous; versus rebel commander, bitter), the Monarch (last wearer of the crown; versus steward, not an emperor), the Devourer (made of a father; versus many discarded minds), Orren (smith and trainer who has buried many like you; versus smith who distrusts the Unbound), the Huntsman (amused; versus cold, tired), the Executioner (bored clerk; versus toneless, certain), Lyra's age (30s; versus young adult) and the narrator (outside the story; versus possibly Lyra long ago).
6. **Veyrath's home.** Character bible: under a volcanic fortress. Region data: a high crag stable; "never sent to war". Lyra's line: built to break sieges.
7. **Implementation status wording.** The bible says first-meeting and death exchanges exist "for the other guardians". Missing today: any Huntsman death or yield scene, any Veyrath death scene, any Devourer death scene, all Skeldra dialogue.
8. **Stage remarks.** Only the Courtyard has them. The other 49 stage remarks above are proposals.
