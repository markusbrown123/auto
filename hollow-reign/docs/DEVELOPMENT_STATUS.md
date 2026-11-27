# HANDOFF — read this first (written 2026-11-27, for the next session on a cheaper model)

**Goal:** a polished, playable first-boss build (Generation I opening → road → Ashen Sentinel) on the owner's iPhone, without burning usage. The game imports and runs on the owner's Mac.

**Usage rules from the owner (2026-11-27):** Sonnet for implementation, UI, visual polish, testing and routine fixes. The top model only for complex animation problems, combat architecture, major bugs and hard technical decisions. Group related changes; do not re-review the whole project; reuse assets and code; avoid paid asset generation (ask first). At most two background agents at once, started with `model: sonnet`, each with strict file ownership and told not to run git. Never resume an agent with a very large context for a small job: start a fresh one.

**Do not break:** texture import settings are frozen (detect-3D off, compressed, mipmapped; `[importer_defaults]` in project.godot). Never hand-edit `.import` files. `tools/clone_test.sh` must show 0 import errors and `git status` clean after import. `marketing/`, `art/`, `shots/` have `.gdignore`. No FBX in git (`git ls-files | grep -ci "\.fbx$"` = 0).

**Last commit with every suite green and a clean-clone pass:** `d9775ed` (clone) / `dd573a5`-era tree (all eleven suites, before armour pass 2). Nothing later has had both.

**Running when this was written (Sonnet agents; their reports arrive as messages):**
1. Death screen, checkpoints, swipe trails (Addendum 5 items 1–2) — owns src/core, overlays.gd, duel.gd, swipe_input.gd, duel_hud.gd, main.gd, tests, gen_regions.py.
2. Walking pace and scenic roads (items 3, 5) — owns explore.gd movement/camera, src/world, locomotion in fighter_rig.gd. No paid generation.
3. Shield clipping and cloak-colour removal (item 4) — owns shield poses in fighter_rig.gd, character_select.gd.
4. Clip re-render and throne-hall scene check — owns src/cine small offsets, assets/video.

**When each lands:** commit and push (stop hook requires it), look at its sheets, tell the owner plainly what is good and what is not, with pictures.

**Then, in order:**
1. `tools/check.sh`, `tools/test.sh` (all eleven suites), `tools/clone_test.sh`; name the build commit for the owner (Mac steps are in docs/IOS_BUILD.md quick start, using `tools/mac_import.sh`).
2. Record one `--screen=slice` run at normal speed and look at the contact sheets (owner asked for testing "in actual gameplay at normal speed").
3. Update this file, DEVELOPMENT_BACKLOG.md, BUG_REGISTER.md.

**Open decisions waiting on the owner:**
- Armour: monochrome gunmetal finish with etched ornament is in (`FINISH_COAT` in src/chars/armor_parts.gd; `--chrome` reverts, `--neon` restores the rejected glow). The code-built hood looks poor close up (a lumpy dark shell, worst on the male). Options: remove it (`--nohood` behaviour as default), or generate one hooded faceplate helm (about $0.30 Tripo, needs the owner's yes). Etching is too subtle at fight distance.
- Witness: small orb (`mote`) is in; faint in daylight. Owner has not yet reacted.
- Older suits: spikes trimmed and finish dulled by default; owner has not said whether to revert (`--spikes`).
- Voices: 99 takes recorded in the final cast, unauditioned. Lyra is Claire lowered (owner named Claire or Caspian). Heir's own takes for shared scenes not recorded (about 140 credits; ask first).

**Known defects not yet assigned:** forge layout at 16:9; roll camera swings 90–120°; dual-blade roll leg clip; two dark patches on the male abdomen; sanctuary orb drifts to the left edge; region menu text may still describe medieval scenery; final hall has no pit; stale docs (STORY_BIBLE, WORLD_HISTORY, CREDITS).

**Budget:** see docs/SPENDING_LOG.md. Tripo graphics allocation about $31.50 of $100 spent; Higgsfield balance about 840 credits. Nothing has run on an iPhone; nobody has listened to the audio.

---

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
The first-boss slice (launch to the Ashen Sentinel's fall) has been played end to end by an automated player that presses the real buttons and fights by synthetic touch (`--screen=slice`, `docs/FLOW.md`): 883 s of game time, seven fights, two deliberate defeats, pause, sanctuary purchase. Sixteen defects fixed, thirteen open (`docs/BUG_REGISTER.md`, "Slice QA"); model textures now VRAM-compressed (Courtyard duel 339 → 148 MB video memory in the software renderer); a phone starts on the Performance preset; the export preset's privacy reasons are filled in (`docs/IOS_BUILD.md`, last section). All eleven suites passed after these changes. Still not run on a phone.

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
