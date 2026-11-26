# Hollow Reign: development status

Last updated 2026-11-25. Version 0.1.0.

## Summary
The game is playable start to finish in Godot 4.6: title, sanctuary, six regions with branching roads, 8 guardians and 6 lesser foes, loot, upgrades, levelling, death and return, New Game Plus. Combat rules are covered by automated tests. **Art is programmer-built placeholder geometry, no iOS build exists yet, and nothing has been played on a phone or by a human.** Those three things are the gap between this and a shippable game.

## Environment this was built in
- Linux container, no GPU, no Mac, no Xcode, no Unreal or Unity, no Blender.
- Higgsfield: no connector and the API host was unreachable. Nothing was generated.
- Engine choice: Godot 4.6. Unreal could not be installed here and cannot build for iOS from Linux; Godot is open source (no vendor dependency that could force the game off the store later), exports native iOS/Metal, and runs headless for tests.

## Done and verified
Verified means covered by `tools/test.sh` or seen in software-rendered screenshots. The script runs three suites: 820 rule checks; an end-to-end run that builds every screen and bot-plays a duel against all 14 foes through the real scene; and a touch suite that pushes synthetic multi-touch events through a real window (swipes in each direction, zig-zag chains, slow drags and jitter rejected, dodge buttons, hold-to-block with a second finger cutting).

| Area | State |
|---|---|
| Directional swipe attacks (8 directions) | Works, tested with synthetic touches. Fires on distance and speed, not on release; one stroke is one cut; slow drags and jitter ignored |
| Parry (swipe against the blow), perfect parry | Works, tested |
| Dodge left/right with correct-side rule, perfect dodge and counter | Works, tested |
| Block, stamina, guard break, unblockable attacks | Works, tested |
| Chains (alternate directions), repeat-cut penalty, input buffering | Works, tested |
| Spam punishment (deflect, stamina recoil, boss counter) | Works. A swipe-spam bot loses to every foe |
| Boss AI: weighted combos, delayed attacks, phases, posture/stagger, retreat and lunge, adapts to block/dodge/parry habits | Works, tested |
| Fairness checks | Every attack has at least one valid defence and a windup of 0.45 s or more; a skilled bot beats every foe |
| 8 guardians (the 6 in the brief plus The Gravewarden and The Pale Huntsman), 6 lesser foes | In, each with its own attack table, look, arena, intro card |
| Elements: frost build-up and frostbite, burn, resistance, weapon vs weakness | Works, tested |
| Progression: XP, levels, 7 attributes, 61 items in 8 slots, 4 weapon classes with different speed and cost, upgrades, mastery, shop | Works, tested |
| Equipment changes the knight's look (armour colour, helm, weapon model, shield, cloak) | Works |
| Six regions, 5 stages each: fights, caches, shrines, levers that open permanent shortcuts, hidden caches, one optional boss | Works, tested |
| Death keeps XP, gold and loot; route resets; New Game Plus scaling and exclusive gear | Works, tested |
| Saves: atomic write, backup recovery from a corrupt file, migration of old saves, save on app pause | Works, tested |
| UI: title, colour choice, sanctuary (journey, armory with comparison, blacksmith, character, settings), road, HUD, pause, victory, death, ending | Works |
| Feedback: hit-stop, camera shake, sparks, blade trails, haptics calls, slow motion on perfect dodge, finisher and death sequences | In. Haptics untested (needs a device) |
| Audio: 37 sound effects, 4 ambiences, 5 music loops, phase-2 music layer | In. **Nobody has listened to it** (see below) |
| Settings: quality, frame cap, volumes, haptics, shake, prompts, forgiving timing, reduced flashes | Works |

## Overhaul pass 2026-11-26: movement, combos, controls, authored motion
Scope is the first encounter only (Fallen Courtyard, Ashen Sentinel), per the overhaul brief. Audit and register: `docs/BUG_REGISTER.md`.
- **Movement.** Both fighters move: the foe circles, closes and gives ground, blows push bodies back, the knight steps into cuts. Dodges carry the knight 1.25 m sideways; the foe has to turn to find them and the camera follows.
- **Combos.** 16 data-driven sequences (`data/combos.json`), ten general and six weapon-specific, with distinct purposes (fast, heavy, guard-breaking, armour-piercing, counter, finisher). Found by performing them; the Journal tab lists what is found and hints at the rest; Orren's training ground lets you practise against a foe that only stands open.
- **Blocking.** A shield raised within 0.22 s of impact is a timed block: no stamina, no chip damage, posture added to the attacker.
- **Controls.** Dodge and shield pads rest at 20% opacity, light under the thumb, fade back. Settings has a visibility slider down to hidden; touch areas are unchanged.
- **Authored motion.** Nine skeletal clips bought ($0.90) and baked to `assets/anim/humanoid.res`. Walk and death now use them on the male knight; sword and shield arms stay on IK so cuts keep their exact directions. Not yet checked on the female knight or the bosses.
- **Tests.** 2,654 rule checks, 83 cinematic checks, integration and touch suites pass. The cinematic playback suite was not re-run to completion in this pass.
- **Not done from the brief:** directional sword-cut clips (none owned), blade-to-blade parry contact, boss rework, voice recasting, sound and music overhaul, six-bus mix, camera redesign, courtyard art pass, onboarding, LODs, the demonstration recordings.

## Continuous pass 2026-11-26 (after the "finish the game" brief)
Backlog with per-item status: `docs/DEVELOPMENT_BACKLOG.md`. Resume instructions: `CLAUDE.md`.
- **Animation.** Free CC0/MIT libraries (Quaternius UAL 1+2, Explosive free sample) researched, downloaded and baked into one skeleton-independent library of 41 clips (0.8 MB). Body motion for cuts, sidesteps, rolls, hit reactions, stagger, combat stance, walk and death now comes from authored clips on both knights and the bosses checked so far; the sword arm stays on IK so each cut follows the swiped direction. Free sets do not contain eight labelled cut directions, directional parries, high/low shield blocks, or real greatsword and dual-blade sets (`docs/ANIMATION_SOURCES.md` lists paid options and prices).
- **Contact.** Fighters step to striking distance before each blow; a parried or blocked blade stops at the contact point; the knight's blade is pinned across it; the shield goes to where the blow lands. Seen in `--snap=` captures for parries and hits.
- **Combat.** Dodge rolls (second tap), Sentinel third phase and drill patterns (20 patterns), a rule trait for each other guardian, combo finishers with their own body movement, interactive first-fight lesson.
- **Review.** An independent code review found twelve defects (combo re-cashing, free timed blocks, roll invulnerability, stuck blade pins, discarded clip legs and others); all fixed, with regression tests for the exploits. See `docs/BUG_REGISTER.md` 22–32.
- **Audio.** Six mix buses with trims, master limiter, dialogue ducking, footfalls on foot plants. Voice bible, measured catalogue of 114 voices, and a three-candidate audition reel for ten roles (`marketing/audition/casting/`). Nobody has listened to any of it.
- **Scale.** Duel frame 548k → 402k triangles. Concept art for six region kits generated (42 images); their 3D models are being generated; kit layouts for all six regions are written and fall back to the old geometry until the models arrive.
- **Tests.** 2,727 rule checks. All five suites passed before the review fixes; only the rule suite has been re-run since. Visual regression script written, golden images not yet captured.
- **Recordings.** `marketing/demos/` (rendered offline in software).

## Campaign roll-out 2026-11-26 (same pass, later)
- **Regions.** All six regions that were primitive geometry are now built from generated kits (42 models, $12.60): Cathedral, Crypt, Roost, Citadel, Deep, Throne. Captures: `marketing/region_*_kit.png`. Duel frames are 231k–298k triangles in them.
- **Dragons.** Veyrath, Skeldra and the new optional Azhurion are generated, quadruped-rigged models driven in fights (neck, claws, tail, wings). Mouths do not open and legs do not step: the auto-rig has no jaw and no walk is authored.
- **Story.** Three endings with a choice after the Monarch; the third needs the Devourer ended, the Roost cleared and 30 records. Roost and Deep are optional side roads. 50 records and 8 tasks in the Journal. Intro cards, phase lines, region blurbs brought in line with the story bible. Text only: no new voice, no ending footage.
- **Bosses.** A rule trait each (marks, frenzy, shield tax, life-steal…), third phases for the Executioner and Gravewarden, second for the Huntsman.
- **Audio.** Adaptive music filter (explore / combat / danger), eight new synthesised effects on their frames. Unheard.
- **Footage.** Courtyard road re-filmed for both knights; the road screen shows the player's knight.
- **Spend.** About $68.85 of the $100 cap (`docs/SPENDING_LOG.md`).
- **Tests.** All five suites pass on this state: 2,995 rule checks, 83 cinematic checks, integration (a duel against every foe, the three dragons and Azhurion included), touch, and cinematic playback. These prove rules and wiring, not how it looks, sounds or runs on a phone.

## Experiment 2026-11-26: cinematic presentation
A complete, playable test of prerecorded footage with live rules (the Ashen Sentinel in the Fallen Courtyard), plus a short hotspot-and-travel exploration example. Off by default; switch on in Settings. The real-time duel is unchanged. Full write-up, measurements and recommendation: `docs/CINEMATIC_COMBAT.md`. Short version: it works and is verified on desktop; it suits travel, intros, finishers and story scenes; the real-time duel remains the better choice for the fighting itself. Asset manifest: `docs/ASSET_MANIFEST.json` (`tools/asset_manifest.py`). Audition reels for the unheard voices and music: `marketing/audition/`.

Since then: the whole Fallen Courtyard can be played as cinematic exploration (filmed walks and views with hotspots, real-time duels), also off by default; the knight has a procedural walk cycle; and the real-time duel gained a surge meter (stuns the foe when full), a healing relic, and four named three-cut combos.

The Blackwood has also been rebuilt from a 12-piece generated kit (giant trees, root arches, a shrine, lanterns, the executioner's blocks, a gibbet, a standing stone with machinery inside). Two of eight regions now have real environments. Scene cost is high: about 750 thousand triangles per frame in a Blackwood duel, so level-of-detail work is needed before testing on older phones.

Also fixed: weapon models could be fitted upside down (the Sentinel's greatsword was). The fitter now finds the handle by cross-section shape, and `-- --screen=weapons` shows every weapon as fitted.

## Milestone 2026-11-26: the first region, voiced
- **Weapons and shields:** 21 generated models (8 swords incl. two recoloured variants, 5 greatswords, axes, 4 dual-blade sets, 6 shields), fitted automatically to the hand (`src/chars/prop_model.gd`). Bosses carry their signature weapons. Four concepts were refused by the image service's content filter and are covered by recoloured variants; the glaive is still a primitive shape.
- **The Fallen Courtyard:** rebuilt from 13 generated set pieces (gatehouse, walls, towers, statues, pillars, braziers, banners, tree, rubble, a half-buried machine obelisk, mountain peaks), enclosed on all sides, with grass, fire light and shadows. The other seven regions are still primitive geometry.
- **Story:** the new canon is in `docs/STORY_BIBLE.md`, `WORLD_HISTORY.md`, `CHARACTER_BIBLE.md`. A dialogue system (`src/core/story.gd`, `data/dialogue.json`, 83 lines in 40 scenes) plays subtitled, voiced lines: opening narration, the awakening with Lyra, a remark at each Courtyard stop, the Sentinel's challenge and last words, the Archivist's record, Orren at the forge, resurrection lines, and first-meeting and death exchanges for the other guardians.
- **Voices:** 97 files generated (player lines in both a male and a female voice). Cast by name only and never listened to; treat as placeholder until auditioned.
- **Music:** four generated cues (main theme, hub, Courtyard exploration, Ashen Sentinel) alongside the earlier synthesized ones. Also never listened to.
- **Memory:** video memory in a Courtyard duel is about 350 MB after capping textures at 1024 px; about 550k triangles per frame, which is high and needs level-of-detail work before older phones.

Not done from the 2026-11-25 direction: animation polish, cinematic camera work beyond the existing road system, interface redesign, modular armour, dragons as real models, the remaining regions, the story's choices and endings, adaptive music layers, the lore collectibles. Remaining required documents not yet written: CAMPAIGN_SCRIPT, CINEMATIC_SCRIPT, VOICE_BIBLE, SOUNDTRACK_PLAN, SOUND_DESIGN_BIBLE, AUDIO_ASSET_MANIFEST.

## Generated art pipeline (added 2026-11-25)
Characters are no longer primitive shapes. The pipeline, all scripted and repeatable:

1. `tools/concepts.py` writes a concept image per character with Higgsfield (about 1.25 credits each) into `art/concept/`.
2. `tools/tripo.py` turns a concept into a low-poly (about 30k triangles), PBR-textured model with Tripo, then auto-rigs it with a Mixamo-named skeleton (135 credits, $1.35 each) into `assets/models/`.
3. `src/chars/skin_driver.gd` drives that skeleton from the existing procedural combat rig (two-bone IK on the model's real bone lengths), so every model inherits all attacks, parries, dodges and staggers with no authored animation.

In the game now: male and female player knights (chosen at New Game), nine bosses (Ashen Sentinel, Hollow Executioner, Crimson Widow, Cathedral Beast, Gravewarden, Frostbound King, Forgotten Monarch, Pale Huntsman, Devourer of Names), and one shared model per enemy class (Humanoid, Heavy, Giant, Twin-Bladed, Double-Weapon, Monstrosity, Soul-Eater), tinted per foe.

Spend to date: Tripo $24.50 of $49.80; Higgsfield about 26 of 1,212 credits.

Still primitive: weapons and shields, all environments, and the three dragons (they need a quadruped skeleton mapping that does not exist yet). Equipment no longer changes the knight's armour shape, only its tint, weapon and shield.

## Placeholder or unverified (must be addressed before release)
1. **Environment, weapon and dragon art.** Characters now use generated models (see above), but arenas, weapons, shields and dragons are still built from primitive shapes. Generated models have not been checked up close for seams, texture errors or bad skin weights.
2. **Audio quality.** All sound was synthesized by script and checked only for levels, clipping and loop seams. Roars, choir pads, rain and fire are the likeliest to sound synthetic. Needs an ear, and probably recorded or licensed replacements.
3. **Feel and balance on a real phone.** Swipe thresholds, parry windows (0.30 s, 0.12 s perfect), boss health and damage are tuned by bots, not hands. Expect a tuning pass after the first device playtest.
4. **Performance.** Not profiled on any device. Measured under software rendering: about 380 to 410 draw calls and 23k to 25k triangles per frame in a duel. Triangle count is light; draw calls are high for older phones because every arena block is its own mesh.
5. **iOS build.** `export_presets.cfg` is hand-written and has never been opened in the editor or exported. See `docs/IOS_BUILD.md`.
6. **Name.** "Hollow Reign" is not cleared. A web search found no identical game but USPTO, EUIPO and the App Store were not searched. See `docs/RESEARCH.md`.
7. **Cinematics.** Boss intros and the finisher are in-engine camera moves. There is no pre-rendered opening or trailer.

## Marketing material
- `marketing/screenshots/`: five in-engine captures at 2556x1179 (iPhone landscape size). They show the current placeholder art, so treat them as layout drafts, not store-ready images.
- `assets/icons/icon_1024.png`: app icon (script-drawn crown and sword).
- `docs/APP_STORE.md`: listing copy, shot list, preview storyboard. `docs/HIGGSFIELD_PROMPTS.md`: prompt library.
- No trailer or app preview video exists.

## Known bugs and rough edges
- Weapons pass through bodies; contact is decided by the rules, not by mesh collision. Sparks are placed at the expected meeting point.
- The intro orbit can briefly clip the knight's sword into frame.
- Smallest menu text is 15 to 16 px at the 720p reference height; there is no large-text option yet.
- Cathedral window glows are flat quads.
- No engine licence screen yet (required by Godot's MIT notice).
- No localisation; English only.

## Blocked on you
- A Mac with Xcode 26 or later, and an Apple Developer account, to build, sign and test.
- A decision on art: commission, licensed packs, or a generation service (and Higgsfield access if you want concept art and trailers from it).
- A proper trademark search on the name.

## Next tasks, in order
1. Open on a Mac, fix any export warnings, run on an iPhone. Tune swipe and parry feel by hand.
2. Profile. Merge static arena meshes to cut draw calls; confirm 60 fps and thermal behaviour.
3. Replace the knight and the Ashen Sentinel with real models to set the art bar, then roll through the roster.
4. Listen to the audio; replace the weakest sounds.
5. Larger text option, licence screen, VoiceOver labels on menus.
6. More roads per region and more enemy variants for New Game Plus.
