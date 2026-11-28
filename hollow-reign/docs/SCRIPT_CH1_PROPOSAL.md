# Chapter I script: rewrite proposal

Draft for the owner's approval. **Nothing in the game has been changed**: `tools/gen_dialogue.py`, `data/dialogue.json` and the secrets data are untouched. Same data as `docs/SCRIPT_CH1_PROPOSAL.json` (for a review page).

## Counts

| | |
|---|---|
| Lines in scope | 65 rows in 28 scenes (57 distinct line ids: `witness_chamber` replays `witness_discovery_02`-`09`) |
| Kept | 37 |
| Changed | 20 |
| New | 2 (both by the Witness; one needs a new hook) |
| Cut | 0 |
| Words, counted per scene row | 764 before, 756 after |
| Words, each distinct line once | 667 before, 661 after |
| Takes to record | **26** (Archivist 2, Lyra 10, Narrator 3, Orren 3, Knight (m/f) 2, Witness 6) |

A take is each changed or new voiced line, plus each kept line that is text-only today. A knight line counts twice (male and female bodies). A shared line (`witness_discovery_02`-`09`) is one take, however many scenes play it. Lines over 20 words after the rewrite: `witness_discovery_07` (21), `w_courtyard_approach_01` (21).

Takes in full: `opening_03` Narrator x1 (CHANGED); `opening_04` Narrator x1 (CHANGED); `opening_05` Narrator x1 (CHANGED); `awakening_06` Knight (m/f) x2 (CHANGED); `witness_call_01` Lyra x1 (CHANGED, text-only now); `witness_discovery_05` Witness x1 (CHANGED); `witness_discovery_07` Witness x1 (CHANGED); `witness_chamber_01` Witness x1 (CHANGED, text-only now); `witness_chamber_02` Witness x1 (KEEP, text-only now); `courtyard_1_01` Lyra x1 (CHANGED); `w_courtyard_chest_01` Witness x1 (NEW); `courtyard_2_01` Lyra x1 (CHANGED); `sx_cy_loose_stone_01` Lyra x1 (KEEP, text-only now); `courtyard_3_01` Lyra x1 (CHANGED); `courtyard_4_01` Lyra x1 (CHANGED); `sx_cy_charcoal_sketch_01` Lyra x1 (CHANGED, text-only now); `sentinel_retry_01` Witness x1 (NEW); `sentinel_memory_01` Archivist x1 (CHANGED); `sentinel_memory_02` Archivist x1 (CHANGED); `sentinel_memory_03` Lyra x1 (CHANGED); `sx_cy_second_candle_01` Lyra x1 (KEEP, text-only now); `orren_intro_01` Orren x1 (CHANGED); `orren_intro_02` Orren x1 (CHANGED); `orren_idle_01` Orren x1 (CHANGED); `sx_cy_cycle_count_01` Lyra x1 (CHANGED, text-only now).

## Notes for the owner

- **Why no cuts.** Every line carries a plot fact, a staging cue (the chamber scenes are staged line by line in `src/cine/awakening.gd`, and the opening's shots wait on line indices in `src/cine/prologue.gd`), or a tutorial hint. The trims are made inside lines instead.
- **Voices.** Lyra loses the Witness's vocabulary ("rather") and most of her jokes: she notices, precisely, and is uneasy. The wit belongs to the Witness. Her Courtyard remarks keep calling the hollow soldiers "it", then the Sentinel "he", then "people" in the memory record. That arc is the chapter's lesson.
- **Approved takes kept.** The Sentinel's challenge and last words, the Witness's best recorded lines, and Lyra's awakening stay as recorded. The Sentinel cannot gain a line (speech category B allows at most four, and all four are used).
- **Placement, at no cost.** Move `w_courtyard_approach` from stop 2 to stop 0. The Witness is now found in the chamber, so its first look at daylight in three centuries belongs at the Breach.
- **Hooks.** `sentinel_retry` plays through an existing hook (`duel.gd`, `<key>_retry`, once). It goes through `Story.play` directly, so the chatter setting does not silence it. `w_courtyard_chest` needs a new call when a chest is opened. Without that call, drop it.
- **Timing.** The opening becomes shorter (64 words down to 49). Its road shots have minimum holds, so the last shot may run a few seconds without narration. Check it in a capture.
- **Not checked.** Nobody has heard any of this aloud. The directions are written for the approved cast (Graham, Claire, Hamish, Mortimer, Callum, Malcolm and Victoria; Onyx for the Archivist is still provisional).

## The script, in play order

### `opening`

*Generation I, the high road (src/cine/prologue.gd, shots R1-R5): narrator over the forebear's climb, under the card VAELORA · THE FIRST OATH. First new journey only. Shot changes wait on line indices 2-5, so all six ids must stay.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `opening_01` | Narrator | Once, men begged the gods to spare them from death. | KEEP | slow, grave; let 'death' fall away, do not land it | sets the frame; already short |
| `opening_02` | Narrator | Then men became gods. | KEEP | quiet, as a plain fact; no awe pushed | four words, carries the premise |
| `opening_03` | Narrator | They built bodies that could not grow old. Thrones that could not be inherited. Kingdoms that could not escape them. | They built bodies that would not age, and thrones that no one would inherit. | measured; the faintest weight on 'inherit' | third clause cut; keeps the inheritance seed |
| `opening_04` | Narrator | But even eternity could not protect them from the people they ruled. | Eternity did not save them from the people they ruled. | harder, level; no rise at the end | same fact, fewer words |
| `opening_05` | Narrator | The crowns shattered. Their kingdoms fell. And for three hundred years, humanity believed itself free. | For three hundred years, we believed ourselves free. | elegiac, almost warm on 'free' | 'crowns shattered' repeated 04; 'we' sets up 06 |
| `opening_06` | Narrator | We were wrong. | KEEP | near whisper, after a full beat of silence | the turn; perfect as is |

### `awakening`

*Generation II, the Inheritance Engine (src/cine/awakening.gd): the knight comes to at the foot of the cradle, where the forebear died; Lyra through the grille. Ends on the TAKE UP YOUR SWORD prompt.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `awakening_01` | Lyra | Can you hear me? | KEEP | tentative, close to the grille, as if not expecting an answer | approved, recorded |
| `awakening_02` | Knight (m/f) | Who are you? | KEEP | hoarse, first words in years; dry throat | terse; right |
| `awakening_03` | Lyra | Someone who has been waiting a very long time. | KEEP | relief held back; she will not say how long | quoted later by the Witness (w_talk_lyra) |
| `awakening_04` | Knight (m/f) | What happened here? | KEEP | wary, still finding the room; eyes, not voice, searching | sets up her answer |
| `awakening_05` | Lyra | That depends. What do you remember? | KEEP | careful; she already hopes | good misdirection |
| `awakening_06` | Knight (m/f) | Things I couldn't possibly have seen. | Someone dying. Here. It wasn't me. | low, unsettled; a pause after 'Here'; the last three words nearly a question | shows the inherited memory: the forebear died at this cradle |
| `awakening_07` | Lyra | Then it worked. | KEEP | quiet wonder, barely voiced; a held breath before it | now answers 06 exactly |

### `witness_call`

*Chamber, after the sword is taken: the door will not open (bars knock, its lamp blinks red), the housing beside it flickers; the WAKE IT prompt follows.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `witness_call_01` | Lyra | Wait. That housing by the door. It is on no plan I hold. | The door will not answer me. That housing beside it is on no plan I hold. | puzzled, then wary; the second sentence slower, eyes on the housing | reacts to the door refusing them |

### `witness_chamber`

*Chamber, after WAKE IT: the lid lifts, the Witness wakes on its first word (02), is lifted from its prongs (07), turns to the grille (08), looks at the cradle (chamber_01), flies to the lock (chamber_02); the door opens. Lines 02-09 are shared with witness_discovery and staged by id in awakening.gd.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `witness_discovery_02` | Witness | Ah. At last. I had begun to suspect the dead were better company. | KEEP | dry, unhurried, muffled in the housing; 'At last' faintly put out | recorded; lands over the cradle where the forebear died |
| `witness_discovery_03` | Knight (m/f) | What are you? | KEEP | guarded, quiet; hand still on the lid | terse |
| `witness_discovery_04` | Witness | A witness to rather more than I would care to remember. | KEEP | wry, savouring 'rather' | recorded; its voice in one line |
| `witness_discovery_05` | Witness | And to rather less than I ought. They took a good deal out of me before they shut that door. | And rather less than I ought. They cut a good deal out of me before they shut me away. | lighter than it should be; the smile goes on 'shut me away' | 'that door' read as the door the Monarch sealed; 'cut' names the wound |
| `witness_discovery_06` | Knight (m/f) | Who did? | KEEP | direct, one breath | terse |
| `witness_discovery_07` | Witness | If I knew that, I should be a happier ornament. Lift me down. I weigh very little, and I know this road. | If I knew, I should be a happier instrument. Lift me out. I weigh very little, and I know this road. | brisk; 'Lift me out' a request it would never call an order | flagged mask wording: it is a ball in prongs, lifted out, not down |
| `witness_discovery_08` | Lyra | I do not know what that is. I do not like not knowing. | KEEP | low, to the player, not to it; precise, unsettled | Lyra's voice exactly |
| `witness_discovery_09` | Witness | The voice in the walls disapproves of me. Good. We shall get on. | KEEP | amused; a beat before 'Good.' | recorded; the pair's dynamic in one line |
| `witness_chamber_01` | Witness | I was set here to keep watch on that cradle. You are what it kept. I should like to see where you go. | They set me to watch that cradle. You are what it kept. I should like to see where you go. | quiet, curious; 'what it kept' plain, not ominous | two words lighter; reads cleanly aloud |
| `witness_chamber_02` | Witness | This door answers to the old seals. So, as it happens, do I. *(text only)* | KEEP | brisk, a little proud; a beat before 'So, as it happens' | good exit line |

### `courtyard_0`

*Courtyard stop 0, The Breach: first sight of the courtyard, on arrival (Lyra's road remark, chatter setting), before the first fight; a garrison sentry walks the breach.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `courtyard_0_01` | Lyra | Those statues were kings once. People prayed to them. Some of them answered. | KEEP | low, first daylight; a small pause before 'Some of them answered.' | subtext already does the work |

### `witness_discovery`

*FALLBACK only: Courtyard stop 1, for a save that never saw the chamber; staged at the fallen statue head, the hatch sliding back during Lyra's line. Lines 02-09 are the shared lines above.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `witness_discovery_01` | Lyra | Wait. Under the fallen plinth. There is a door there that is on no plan I hold. | KEEP | puzzled, wary; over the hatch sliding back | rare path; not worth a new take |
| `witness_discovery_02` | Witness | Ah. At last. I had begun to suspect the dead were better company. | KEEP | as in witness_chamber | shared line; one take |
| `witness_discovery_03` | Knight (m/f) | What are you? | KEEP | as in witness_chamber | shared line; one take |
| `witness_discovery_04` | Witness | A witness to rather more than I would care to remember. | KEEP | as in witness_chamber | shared line; one take |
| `witness_discovery_05` | Witness | And to rather less than I ought. They took a good deal out of me before they shut that door. | And rather less than I ought. They cut a good deal out of me before they shut me away. | as in witness_chamber | shared line; works for the hatch too |
| `witness_discovery_06` | Knight (m/f) | Who did? | KEEP | as in witness_chamber | shared line; one take |
| `witness_discovery_07` | Witness | If I knew that, I should be a happier ornament. Lift me down. I weigh very little, and I know this road. | If I knew, I should be a happier instrument. Lift me out. I weigh very little, and I know this road. | as in witness_chamber | shared line; 'out' fits the hatch too |
| `witness_discovery_08` | Lyra | I do not know what that is. I do not like not knowing. | KEEP | as in witness_chamber | shared line; one take |
| `witness_discovery_09` | Witness | The voice in the walls disapproves of me. Good. We shall get on. | KEEP | as in witness_chamber | shared line; one take |

### `courtyard_1`

*Courtyard stop 1, on arrival after the first fight is won; the path forks: The Guardhouse (first chest) or The Rampart Stair.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `courtyard_1_01` | Lyra | Look at its armour. Under the plate there is light. That is not rust moving it. | Look at the one you felled. Light, under the plate. That is not rust moving it. | uneasy, precise; slows on 'Light' | reacts to the first kill |

### `w_courtyard_chest`

*NEW scene, NEEDS A HOOK that does not exist yet: the Witness on the first chest opened in the Courtyard (the Guardhouse, the Well or the Murder Hole). Would need an on-loot call in Companion and a STAGE-like table.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `w_courtyard_chest_01` | Witness | — | **NEW:** Garrison issue. Somebody counted every piece out. I have a terrible feeling it was me. | dry, peering in; the last clause rueful, not comic | nothing reacts to a chest; plants the recorder's guilt |

### `courtyard_2`

*Courtyard stop 2, The Barbican, on arrival: the banneret stands at attention under his banner; he salutes before he fights.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `courtyard_2_01` | Lyra | It salutes before it strikes. Someone taught it manners, three hundred years ago. | It salutes before it strikes. Somebody drilled it. The drill is all that is left. | precise, unsettled; flat and slow on the last sentence | Lyra's unease, not the Witness's wit; still 'it' |

### `w_courtyard_approach`

*Courtyard stop 2, the Witness's remark after Lyra's (two remarks at most a stop, played back to back). PROPOSED: move it to stop 0 (wstage stage 2 -> 0) so it is the Witness's first sight of daylight in three hundred years; no new take.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `w_courtyard_approach_01` | Witness | So this is what became of the outer court. It had a grander name when it stood. I forget it. Mercifully. | KEEP | surveying, slow; 'Mercifully' after a beat, dry as dust | recorded; better placed at stop 0 |

### `sx_cy_loose_stone`

*Secret, Courtyard stop 2: said on tapping the tilted flagstone at the Barbican (an undelivered relief order under it).*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `sx_cy_loose_stone_01` | Lyra | That one has been lifted before. Often, and carefully. *(text only)* | KEEP | quiet, close, half to herself | subtext: somebody keeps rereading it |

### `courtyard_3`

*Courtyard stop 3, the winch house by the inner gate (Turn the Winch, or The Well chest once the gate is open).*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `courtyard_3_01` | Lyra | That winch will hold. Most things they built still do. That is rather the problem. | The winch will hold. Everything they built still holds. That is what worries me. | matter of fact, then quieter on the last sentence | 'rather' is the Witness's word; she is built too |

### `w_courtyard_gate`

*Courtyard stop 3, the Witness after Lyra, at the inner gate.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `w_courtyard_gate_01` | Witness | That gate once bore the banners of thirteen kings. Now look at it. Eternity has a peculiar sense of humour. | KEEP | dry; a beat before 'Now look at it' | recorded; the thirteen kings planted |

### `courtyard_4`

*Courtyard stop 4, The Gate Passage, on arrival: the first heavy foe (Rampart Brute or Gate Colossus); the lesson here is the dodge.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `courtyard_4_01` | Lyra | Careful. The big ones were made for breaking gates. You are much smaller than a gate. | Careful. That one was made for breaking gates. Do not stand where a gate would. | quick, low; serious advice, the joke accidental | same dodge hint, as an instruction |

### `w_courtyard_passage`

*Courtyard stop 4, the Witness after Lyra.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `w_courtyard_passage_01` | Witness | They built the passage narrow so that one man could hold it. Nobody asked which man. | KEEP | flat; 'which man' dropped, not pointed | recorded; sharp |

### `sx_cy_charcoal_sketch`

*Secret, Courtyard stop 4: said on tapping the rolled hide in the gate passage (a sketch of the Blackwood's spring under the gallows).*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `sx_cy_charcoal_sketch_01` | Lyra | A drawing. Not of here. Keep it. Somebody wanted a place found again. | Not of here. Somebody wanted that place found again. Keep it. | curious, quick; 'Keep it' firm | drops 'A drawing', which the screen shows |

### `courtyard_5`

*Courtyard stop 5, the chapel alcove: one candle; the Kneel shrine (rest).*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `courtyard_5_01` | Lyra | Rest. That candle is not a candle, but it will not hurt you. | KEEP | soft, reassuring; 'not a candle' plain | recorded; pairs with the Witness's next |

### `w_courtyard_candle`

*Courtyard stop 5, the Witness after Lyra: they disagree about the candle without arguing.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `w_courtyard_candle_01` | Witness | A candle three hundred years alight. In my day we called that a miracle. We were paid to. | KEEP | dry; 'We were paid to' after a beat, not a punchline | the bible's model line |

### `courtyard_6`

*Courtyard stop 6, The Inner Ward, on arrival: the Sentinel stands exactly where he was posted.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `courtyard_6_01` | Lyra | He is still at his post. He has not been told that there is nothing left behind him. | KEEP | sad, slow; no pity in it | recorded; sets up his last words |

### `w_sentinel_approach`

*Sentinel duel, first meeting: before his challenge, while he stands on guard (Companion.on_boss_approach).*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `w_sentinel_approach_01` | Witness | He will ask your allegiance. There is no right answer. There never was one. | KEEP | quiet, close at the shoulder | recorded; good |
| `w_sentinel_approach_02` | Knight (m/f) | Then he will have the true one. | KEEP | steady, low | terse |

### `sentinel_intro`

*Sentinel duel, first meeting, before steel is drawn (also the filmed road, cine_duel.gd).*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `sentinel_intro_01` | Sentinel | State your allegiance. | KEEP | flat, immense, helmeted (owner-approved take) | approved challenge |
| `sentinel_intro_02` | Knight (m/f) | I serve no crown. | KEEP | steady | terse |
| `sentinel_intro_03` | Sentinel | Then you have no passage. | KEEP | final; procedure, not menace | approved; category B is full |

### `sentinel_retry`

*NEW scene: a later attempt at the Sentinel after a death and Retry from checkpoint. The hook exists: duel.gd plays '<key>_retry' over the intro card on a later meeting (once). The Sentinel may not say it (category B: four lines, all used), so the Witness does. An old cut Sentinel take named sentinel_retry_01.ogg is still on disk; new=True keeps it from playing.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `sentinel_retry_01` | Witness | — | **NEW:** Again, then. He keeps no count of these. I am obliged to. | dry, low, a little tired; not mocking the knight | the only reaction to a death and retry |

### `sentinel_death`

*Sentinel duel won: his last words.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `sentinel_death_01` | Sentinel | Is the war... over? | KEEP | failing, suddenly human; the helm muffles less | the human moment |
| `sentinel_death_02` | Knight (m/f) | It ended centuries ago. | KEEP | gentle | terse |
| `sentinel_death_03` | Sentinel | Then why did no one return for me? | KEEP | a child's question | planted for the Kept in Generation III |

### `sentinel_memory`

*After his last words: the Archivist's record, then Lyra.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `sentinel_memory_01` | Archivist | Record incomplete. Witness deceased. Memory retained. | Record incomplete. Observer lost. Memory retained. | calm, broken cadence; equal weight on each pair | 'Witness deceased', heard beside the Witness, misleads |
| `sentinel_memory_02` | Archivist | Subject: gate sergeant, forty-one years of service. Volunteered. He was told it would be for one winter. | Subject: gate sergeant. Forty-one years in service. Volunteered. Term promised: one winter. | even, a clerk reading; a small gap before 'one winter' | every fact kept; reads as a record |
| `sentinel_memory_03` | Lyra | They were people. All of them. Remember that when the next one raises its sword. | They were people. All of them. Remember that, the next time one salutes you. | quiet, not a lecture; a catch on 'salutes' | callback to the Barbican, less sermon |

### `w_sentinel_victory`

*After the memory record: the Witness's posting-order memory returns (first of its returning memories).*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `w_sentinel_victory_01` | Witness | One winter, they told him. I believe I wrote that order down. I hope I argued. | KEEP | troubled, a memory arriving mid-sentence; 'I hope I argued' almost inaudible | the chapter's best line |

### `sx_cy_second_candle`

*Secret, Courtyard stop 5 on a return after the Sentinel has fallen: a second, cold-blue candle in the chapel alcove.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `sx_cy_second_candle_01` | Lyra | I did not light that one. I want that understood. *(text only)* | KEEP | uneasy, quick, defensive; 'I want that understood' clipped | precise and unsettled already |

### `orren_intro`

*Sanctuary forge, the first visit (Turn Back at stop 5, or after the Sentinel). Workshop, Orren at his bench.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `orren_intro_01` | Orren | So you're what she woke up. Hm. | So you're what she woke. Hm. I'd hoped for taller. | Scots, gravel, unimpressed; 'Hm' is a look up and down | reacts to the knight in front of him |
| `orren_intro_02` | Orren | That sword is older than my entire bloodline. Try not to drop it. | That sword's older than my whole line. Mind you don't drop it. | dry; 'Mind you' a Scots warning, not a joke | Scots idiom, fewer words |
| `orren_intro_03` | Orren | Bring me shards and coin. Your armour remembers its shape. I just remind it. | KEEP | matter of fact; a little warmth on 'remind' | his best line |

### `orren_idle`

*Sanctuary forge, repeating: at most once per two fights since he last spoke.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `orren_idle_01` | Orren | People spend their lives searching for legendary weapons. Most of them wouldn't know what to do with one. | Folk spend their lives hunting legendary blades. Most wouldn't know which end to hold. | dry, to the work, not the knight | shorter for a line that repeats |

### `sx_cy_cycle_count`

*Secret, New Game Plus only, Courtyard stop 0: the blade standing in the rubble at the Breach, a fresh cut in a tally.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `sx_cy_cycle_count_01` | Lyra | That mark was not there the first time. Or it was, and you could not see it yet. I do not know which frightens me more. | That mark was not there the first time. Or you could not see it. I cannot tell which is worse. | unsteady; the second sentence slower, afraid of itself | 24 words down to 20 |

### `courtyard_0_g3`

*Generation III, Courtyard stop 0, in place of courtyard_0.*

| line id | speaker | current text | proposed | direction | why |
|---|---|---|---|---|---|
| `courtyard_0_g3_01` | Lyra | The plate on these is new. He has been replacing what your house broke. | KEEP | dry, then a shade colder on 'your house' | recorded; does its job |
