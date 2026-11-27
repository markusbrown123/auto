# Hollow Reign — development status

Updated 2026-11-27 (UTC). Read `docs/DEVELOPMENT_BACKLOG.md` for the ordered list; this file says what is true now.

## Definitive direction
- Campaign: three generations of one family against the never-aging Forgotten Monarch (`docs/GENERATIONAL_CAMPAIGN_BRIEF.md`). Chosen twists: the first hero dies while winning and the heir takes up the actual sword left behind; the second hero is kept by the Monarch's machinery and is fought in Generation III wearing the player's own saved gear.
- Compact game: about 2–3 hours for the story (simulation estimate 2.3 h main road; not timed by a person).
- Look: sleek fitted science-fantasy plate, futuristic engraved swords, no spikes. Only the Crownless (v3) knights and the ten code-built swords are in the new style; the other nine suits, most bosses and the Monarch are still the old spiky designs.
- Economy: gold from fights, item shop that unlocks with progress, forge mods (blade, grip, ore, sharpen), three boss weapon drops in the whole campaign, shields with block counts.

## Built and passing its own tests
Authored whole-body swings (purchased packs, baked library; source files never committed), camera director, poise/pressure/blade struggle, eight-step lesson, clipping and grounding fixes, modular armour parts on the rig, gear models in hand with Recall and draw, Armory carousel, shop, forge, starting-sword picker, victory screen, shield block pips, 13 secrets, 5 side missions, completion page, Generation I playable opening on the high road, time jump, heir's arrival, generational data layer (save v3, falls, inheritance, echo foe, per-generation encounters).

## In progress (agents)
1. Visual pass on the opening road, throne and Engine rooms (gatehouse and dead-tree props already generated).
2. Wiring Generations II and III into play: second Monarch fight with the records choice, second fall, 24-year jump, the Kept, three-phase final Monarch, facility reveal, endings, lineage page.

## Slice QA for the first phone test (2026-11-27)
The first-boss slice (launch to the Ashen Sentinel's fall) has been played end to end by an automated player that presses the real buttons and fights by synthetic touch (`--screen=slice`, `docs/FLOW.md`): 883 s of game time, seven fights, two deliberate defeats, pause, sanctuary purchase. Fifteen defects fixed, eleven open (`docs/BUG_REGISTER.md`, "Slice QA"); model textures now VRAM-compressed (Courtyard duel 339 → 148 MB video memory in the software renderer); a phone starts on the Performance preset; the export preset's privacy reasons are filled in (`docs/IOS_BUILD.md`, last section). All eleven suites passed after these changes. Still not run on a phone.

## Not true yet / known open
- Touch targets (44 to 58 units against a 60 target) and text sizes (179 labels under 22) are below phone guidance throughout the UI; about 400k to 500k primitives a frame in the Courtyard.
- Nothing has run on an iPhone. Nobody has listened to music, effects or most voices. Most animation was judged from stills.
- New story lines are subtitles only: 19 in data, 41 proposed. Casting needed for father, mother, grandson, granddaughter; Lyra, Orren and Monarch samples still owed to the owner.
- King's Remnant is classed greatsword but modelled as a smaller sword. Awakened Beast needs authored patterns. Late-game power curve needs a balance pass.
- Sword guards are flat plates (owner asked for more sculpted, futuristic guards; hybrid generated guards proposed, awaiting an answer).
- Stale docs: `STORY_BIBLE.md`, `CHARACTER_BIBLE.md`, `WORLD_HISTORY.md`, `CREDITS.md`.

## Owner decisions waiting (none blocks current work)
Knight style (more futuristic armour?), generated sculpted guards trial (~$0.60), whether ordinary defeat is part of the fiction, title (default "Hollow Reign"), voice casting samples.

## Spend
Tripo graphics allocation: $24.90 of $100. Original $100 cap: about $86 before the last voice run (see `docs/SPENDING_LOG.md`; needs reconciling against live balances).
