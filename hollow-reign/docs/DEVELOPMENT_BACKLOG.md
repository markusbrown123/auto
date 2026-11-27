# Development backlog

## Checkpoint — read this first when resuming
Last written 2026-11-26, end of the continuous pass. No background jobs are outstanding: all 42 kit models, three dragons and the road re-film are finished and committed.
Next actions, in order:
1. `tools/test.sh` (all five suites, about 6–8 minutes; run in the background) — confirm the result recorded in `DEVELOPMENT_STATUS.md` still holds.
2. `tools/visual_test.sh --update` if `tests/golden/` is empty, look at the images, commit; afterwards run `tools/visual_test.sh` with each change.
3. Take the first TODO/DOING row below. Biggest remaining gaps: directional sword-arm animation (needs a paid library — owner decision), voice recording after the owner picks a cast, remaining demonstration recordings, per-boss pattern widening (Widow, Beast, Frost King), story scenes listed under F4.

## A. First encounter to standard (Fallen Courtyard, Ashen Sentinel)
| # | Task | Status |
|---|---|---|
| A1 | Stance and footwork: both fighters move | DONE — captures in `marketing/overhaul_pass_1.jpg` |
| A2 | Sidestep dodge moves the body, foe turns, camera follows | DONE |
| A3 | 16-combo library, discovery, journal, training ground | DONE — `t_meters_combos` |
| A4 | Timed block | DONE |
| A5 | Pads fade to 20%, glow, visibility setting | DONE |
| A6 | Authored walk and death on male knight | DONE — `marketing/overhaul_walk_fall.jpg` |
| A7 | Rerun all suites; make cinematic playback suite finish | DONE — all five suites pass; the earlier non-finish was the 120 s command limit, the suite takes about 3 min |
| A8 | Sentinel greatsword through its own head while open | DONE — two-handed guard holds the point forward |
| A9 | Parry: blades visibly meet | DONE — stopped blade + pinned knight blade; `--snap=parried` captures |
| A10 | Block: incoming weapon lands on the shield; shield recoil | DOING — shield braces to the contact point; not yet captured (bot rarely blocks) |
| A11 | Dodge: blow visibly passes through empty space | TODO |
| A12 | Hits visibly connect (blade reaches the body at the contact frame) | DONE — fighters step to striking range; `--snap=boss_hit,hit` |
| A13 | Animation library research (`docs/ANIMATION_SOURCES.md`) | DONE — free CC0 Quaternius UAL downloaded to `art/anim_src/`; paid top-ups listed for the owner |
| A14 | Import chosen library: bone map, bake, directional cuts, parries, blocks, rolls, reactions, stances | DOING — 41 clips baked skeleton-independently; body motion live for cuts, steps, rolls, hits, stagger, stance, walk, death. Sword arm still IK. Missing from free sets: 8 labelled directions, directional parries, high/low blocks, greatsword and dual sets |
| A15 | Left/right dodge rolls (deeper than sidestep) | DONE — second tap on the same pad; tests; needs a capture |
| A16 | Each of the 16 combos visually distinct | DOING — finishing cut uses a body clip per combo kind (overhead, lunge, shield dash, long swing); needs captures per combo |
| A17 | Authored clips verified on female knight and each boss (`--screen=animtest --model=…`) | DOING — clean on knight_f, Sentinel, Executioner, Widow, Gravewarden; Beast, Frost King, Huntsman, Monarch, Devourer unchecked |
| A18 | Sentinel: richer attack set, own movement style | DONE — 20 patterns, three phases, drill/thrust/give-ground identity; balance tests pass |
| A19 | Subtle temporary sword trails; replace drawn parry arrow with blade glint | DONE — trails exist; prompts shrunk and dimmed; blade glints as each blow commits; needs a capture |
| A20 | Camera redesign for the duel | DOING — camera now tracks the knight's real position and sits wider |
| A21 | Courtyard art pass | TODO |
| A22 | Visual regression test (golden captures, tolerance) | DONE — nine golden images in `tests/golden/`, compared by structural similarity (`tools/visual_test.sh`); covers static scenes only, not motion |
| A23 | Triangle reduction / LOD | DOING — duel frame 548k → 402k triangles via LOD threshold and scenery bias; characters (32k each) not yet reduced |
| A24 | Onboarding as an interactive lesson | DONE — five do-it-once steps before the first fight; rule test; needs a capture |

## B. Audio
| # | Task | Status |
|---|---|---|
| B1 | Six buses: Music, Dialogue, Combat, Ambience, Interface, Cinematics | DONE — routed with trims, master limiter, dialogue ducks music and ambience. Unheard |
| B2 | Casting profiles (`docs/VOICE_BIBLE.md`) and audition reel with several candidates per role | DOING — profiles written; measured catalogue building; reel next, then BLOCKED on owner's ears |
| B3 | Combat effects synchronised to contact frames; footsteps, armour, effort sounds | TODO |
| B4 | Adaptive music layers | TODO |
| B5 | `SOUND_DESIGN_BIBLE.md`, `SOUNDTRACK_PLAN.md`, `AUDIO_ASSET_MANIFEST.md` | DONE — written; all audio labelled unheard |

## C. Cinematics
| # | Task | Status |
|---|---|---|
| C1 | Hybrid: live knight over filmed backgrounds, so equipment and body show | DONE (as far as chosen) — road now filmed per body with the authored walk and picked by the player's knight; investigated (`CINEMATIC_COMBAT.md`): compositing rejected; road is being re-filmed per body with the authored walk; live-rendered road is the route to equipment-accurate walks |
| C2 | Re-film crowded Courtyard stops 3 and 5 | TODO — all stops were re-filmed with the same camera spots; framing of 3 and 5 not yet changed |
| C3 | Memories, conversations, finishers | TODO |
| C4 | `CAMPAIGN_SCRIPT.md`, `CINEMATIC_SCRIPT.md` | DONE — written; new lines marked proposed |

## D. Campaign roll-out (after A is accepted)
| # | Task | Status |
|---|---|---|
| D1 | Unique mechanics and movement per boss (8 remaining + Devourer) | DOING — one rule trait each (`TRAITS` in `tools/gen_bosses.py`), tested; pattern sets not yet widened like the Sentinel's |
| D2 | Dragons on the stance system | DONE — three generated, quadruped-rigged dragons driven by `dragon_skin.gd` (neck aim, claw swipe, tail, wings) on the turning line; captures in `marketing/dragon*`. No jaw bone found, so mouths do not open; no walk cycle for the legs |
| D3 | Environment kits for the six regions still on primitive geometry | DONE — all six kits generated (42 models) and seen in game: `marketing/region_*_kit.png`; 231k–298k triangles per duel frame |
| D4 | Optional quests, lore collectibles, memories | DOING — 50 records found on the road, 8 tasks claimable from the Journal, third ending needs 30 records; quests are profile conditions (the scripted steps are not built); needs captures |
| D5 | Three endings, New Game Plus check | DOING — choice after the Monarch, three written epilogues, post-credits text, third ending gated on the side roads; text only, no footage or voice; needs a capture (`--screen=ending`) |
| D6 | Modular armour customisation | TODO |

## E. Delivery
| # | Task | Status |
|---|---|---|
| E1 | 20 demonstration recordings | DOING — `tools/record.sh`, `--showcase=` driver; files land in `marketing/demos/` |
| E2 | iOS export preparation | BLOCKED — needs a Mac with Xcode and an iPhone (owner) |
| E3 | Device performance | BLOCKED — same |
| E4 | Audio sign-off | BLOCKED — needs the owner to listen |

## F. Story and data consistency (found while writing the campaign and audio documents)
| # | Task | Status |
|---|---|---|
| F1 | Boss intro cards, region blurbs and some item text still tell the older story (a returning servant of the crown); the story bible says the Unbound is a newly made person | DONE — intro cards, titles, region blurbs and two items rewritten to the story bible |
| F2 | Master brief asks for nine guardians and three dragons; data has eight guardians, the Devourer and two dragons (no Azhurion) | DOING — Azhurion added (optional, throne hall, three phases, 2,821 checks pass); a ninth guardian is still undesigned |
| F3 | Story bible wants the Roost and the Deep optional; data chains all eight regions, so the third ending's condition cannot fail | DONE — Roost and Deep are side roads; throne follows the Citadel; test `t_endings` |
| F4 | Missing scenes: Huntsman, Veyrath and Devourer deaths; all of Skeldra; the Unbound's origin; stage remarks outside the Courtyard | TODO — proposed text in `CAMPAIGN_SCRIPT.md`; recording waits on casting |
| F5 | Memory clip is 5 s under about 20 s of speech; `sentinel_travel` clip missing; all footage shows the male knight | TODO (see C1) |
| F6 | Phase music layer is hard-coded to one cue and may not fit generated boss tracks; one roar set for every boss; `menu` cue still used as exploration music in seven regions | TODO — see `SOUNDTRACK_PLAN.md` |

## G. Final production brief (2026-11-26)
| # | Task | Status |
|---|---|---|
| G1 | The Witness: bible entries, dialogue (travel, landmarks, boss approaches, victories, sanctuary talks), cooldowns, no repeats after death, archive | DONE (text) — 95 Witness lines in 69 scenes, `Companion` autoload, once-per-save, cooldown, silent in combat, test `t_companion`; unrecorded (subtitles only); sanctuary-topics and archive UI still to build |
| G2 | Enemy speech categories: creatures silent, guardians sparse, Devourer whispers | DONE — categories in data and enforced by the generator and the duel; creature sound libraries play instead |
| G3 | Witness relic model on the knight's belt; discovery scene | DOING — relic modelled and worn behind the sword-side hip once found (`marketing/witness_on_knight.png`); discovery is dialogue only, no staged scene yet |
| G4 | UI theme; launch; animated main menu; save slots; character selection; loading screens with lore; world map | DONE (first pass) — theme, launch, animated menu, three save slots, character selection, loading screens with gated lore, world map, chronicle, credits, victory/defeat; captures in `marketing/ui_pass/`; notes and gaps in `UI_NOTES.md` (studio name placeholder, slot cards without 3D knight, loading art only for the Courtyard) |
| G5 | Equipment screen with live rotatable knight, comparison, weapon collection with 3D preview, rarity, sorting, favourites; forge; settings (graphics presets, five audio sliders, accessibility); victory/defeat screens | DONE (first pass) — Armory with live turning knight, preview-before-equip, deltas, 3D weapon preview, rarity, sorting, favourites; forge sequence, sell, wares; full settings with working presets and five audio sliders; mastery tiers. Not done: side-by-side compare, real armour geometry (tint only), victory/defeat screens (menu agent), touch-exercised captures. Notes in `UI_INVENTORY_NOTES.md` |
| G6 | Graphics: materials audit, lighting per region, post-processing, thin sword trails, contact sparks, dust, elemental and environmental effects, budgets; GRAPHICS_BIBLE, SHADER_LIBRARY, VFX_BIBLE, PERFORMANCE_REPORT | DONE (first pass) — thin ribbon trails, pooled contact sparks at the true point, dust and chips, material clamp shader, fill/rim/key lighting per region (no black backgrounds), restrained post, ambient life within a 150-particle budget, four docs. Open: knight slightly bright in daylight, Throne a little flat, elemental bursts hidden under the hurt flash, chips fall through the floor, female knight and presets unviewed; Courtyard and Blackwood still 550k–760k triangles |
| G7 | Sixteen combos individually animated | TODO — limited by owned clips; see ANIMATION_SOURCES |
| G8 | Dragons: jaw, walk, wing fold/flap, death | TODO |
| G9 | Creature sound libraries; layered combat effects; interface sounds | TODO |
| G10 | Voice: third reel cast by character (Witness first), no blanket pitch shift; then rewrite and record | DOING — owner chose from reel 4: Witness = Hamish, male knight = Malcolm, narrator = Graham, pre-battle human = Mortimer; those 144 lines are recorded (one refused by the content filter). Still provisional and awaiting the owner: Lyra, female knight, Orren, Monarch, Widow, Frostbound King, Huntsman, Gravewarden, Archivist, Devourer |
| G11 | Real modular armour geometry (8 named sets × 2 bodies) | DOING — allocation confirmed on Tripo; 16 concepts made from the knight references, 16 suit models generating (`tools/armor_sets.py`); the game swaps the knight model by equipped chest piece. Per-slot pieces (helm, gauntlets, legs separately) are not modular: a suit is one model |
| G12 | Directed endings, opening, awakening, memories, technology revelation, boss intros and defeats | TODO — in-engine first; generated footage needs the added allocation |
| G13 | Scripted quests | TODO |
| G14 | Ninth guardian design | TODO |
| G15 | End-to-end flow test; demonstration package; iOS export preparation | TODO |

## H. Frame-based reference brief (2026-11-26)
| # | Task | Status |
|---|---|---|
| H1 | Camera director with named shots driven by events (duel, intro, finisher, dialogue) | DOING (agent) |
| H2 | Combat rhythm: consecutive attacks, posture-based openings, parry break; blade struggle; mid-battle story beat | DOING (agent) |
| H3 | Opening, awakening, weapon, walk to the first enemy, continuous flow without loading between short steps; staged Witness discovery | DOING (agent) |
| H4 | First-encounter teaching extended: rolls, counters, three-hit combination, stamina | TODO |
| H5 | Unique finishers per major boss | TODO |
| H6 | Cathedral technology revelation as a staged scene | TODO |
| H7 | Measured responsiveness report (input-to-acknowledgement, transition, contact accuracy) | TODO |
| H8 | The complete Sentinel encounter recorded end to end and compared with the reference principles | TODO |

## I. Equipment, redesign and progression brief (2026-11-26, Addendum 3)
Order: benchmark set first, then roll out.
1. [running] Hard-surface sword and shield benchmark (3 swords, 2 shields, modelled by code, with grips) + Recall shader/particles.
2. [running] Modular armour study: split the 16 suits by skeleton region, mix parts across suits, measure seams; honest verdict per suit. De-spike/material fixes on existing suits.
3. [running] Armory rebuild: swipe carousel + live knight, slot camera, preview without saving, compare vs equipped, locked items.
4. [open] Item data architecture (stable ids, slots incl. shoulders/boots, rarity incl. Relic, armour weight classes, ownership separate) + save migration. Starts when the flow pass releases `game.gd`.
5. [open] Rewards after every fight, discovery states, reveal presentation, economy guards.
6. [open] Forge: armour-piece and shield upgrades, craft/buy/sell, upgrade sequence with the real item.
7. [open] Wire authored pack clips into the rig (cuts by swipe, blocks, draw/sheath, Preview Attack); needs `fighter_rig.gd` from the clipping pass.
8. [open] Knight redesign to the sleeker language: decide from item 2 which suits are kept, edited or regenerated; concept sheets, then models (Tripo allocation). Rename families to Crownless/Ashbound/Frostwarden/Widow/Gravekeeper/Sovereign/Dragonforged/Architect.
9. [open] Recall and draw/sheath in awakening, lesson, boss introductions, previews; shield deployment.
10. [open] Sanctuary as a place; main menu shows equipped knight; equipped gear in all in-engine cinematics.
11. [open] Review captures listed in Addendum 3; full equipment loop test.

## J. Generational campaign (Addendum 4, 2026-11-26) — the definitive story structure
1. [running] Story docs rewritten to three generations; recorded-line audit; Generation I playable opening on the scenic road; time-jump scene; Generation II arrival.
2. [open, after 1 and after the secrets pass releases `game.gd`] Generation/world/campaign data separation, save migration v3, encounter director, canonical-death transitions, inheritance of everything earned.
3. [open] Second Monarch fight (real duel, records choice, honest outcome if the player wins) and second transition.
4. [open] Generation III: changed encounters, final three-phase Monarch, facility reveal, endings re-fitted, hidden endgame.
5. [open] Lineage screen; menu wording (Continue, New Legacy); legacy journeys.
6. [open, owner approval first] Casting and recording for father, son, heir and female equivalents; family and Monarch musical motifs.
7. [open] Full-campaign test list in the brief; recordings.

## K. Finalising for the first phone test (owner, 2026-11-27) — do in this order
1. [running] Finish the two agent passes (opening visuals; generations II and III playable).
2. [running] Casting files: four candidates per character in `marketing/audition/final_cast/`; owner chooses; then record all unrecorded lines with the chosen voices and regenerate dialogue.
3. [open] Sculpted guard trial on two swords (generated hilt, code-built blade); if better, roll out.
4. [open] Remaining armour families in the mixed medieval/future language on the v3 body (concepts, models, split into parts), replacing the spiky suits; bosses and the Monarch brought into line where cheap.
5. [open] Stabilise: run every suite together on a quiet machine (touch suite's two failures first), fix all failures, then a bug sweep from `docs/BUG_REGISTER.md` open rows (shield through body in rolls, elbow through shield, shield facing in swings, King's Remnant class, Awakened Beast patterns, late-game balance, tab bar crowding, forge layout at 16:9, tells as plain boxes).
6. [open] Full playthrough recording by bot from New Legacy to an ending; watch the contact sheets; fix what breaks.
7. [open] iOS readiness: export preset checked against the current project (icons, orientation, bundle id placeholder, privacy reasons), ASTC import for all textures, Performance preset as the device default, a tagged commit named for the owner to build from, `docs/IOS_BUILD.md` quick start verified against that commit.
8. [open] Stale docs brought into line (story bible, character bible, world history, credits).

## Owner decisions made 2026-11-26 (act on these)
- **Animation library: buy the Game Dev Hero packs ($59.97)** — Sword And Shield Animation V3, Two Handed Sword Animation V3, Dual Sword Animation V1 (itch.io, $19.99 each). The owner buys them and supplies the `*_Mixamo.zip` from each. WAITING on the files. When they arrive: unpack under `art/anim_src/gamedevhero/` (git-ignored: the licence forbids redistribution, so never commit the sources), read the licence text and save it to `docs/licenses/`, list the clips, extend `tools/bake_anims.gd` (FBX via `FBXDocument`; Mixamo names need no bone map) and bake: eight directional cuts, combo chains, directional parries, shield blocks high/low, rolls, greatsword and dual sets, hit reactions, finishers. Then replace the IK sword arm with authored full-body clips per direction and give each of the sixteen combos its own chain.
- **iOS:** the owner has a Mac with Xcode and an iPhone; the Apple Developer account is awaiting approval. Building needs a session on that Mac (this cloud container cannot reach it; no folders are shared with it yet). Prepare: `docs/IOS_BUILD.md` exact steps, export presets, icon, launch screen.
- **Female knight voice:** Victoria with the clarity treatment (recorded).

## Decisions waiting on the owner (do not block other work)
- Paid animation library, if the free ones leave gaps (see A13).
- Title: "Hollow Reign" in use; trademark search not done.
