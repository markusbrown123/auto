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
| G3 | Witness relic model on the knight's belt; discovery scene | TODO |
| G4 | UI theme; launch; animated main menu; save slots; character selection; loading screens with lore; world map | DOING (agent) |
| G5 | Equipment screen with live rotatable knight, comparison, weapon collection with 3D preview, rarity, sorting, favourites; forge; settings (graphics presets, five audio sliders, accessibility); victory/defeat screens | DOING (agent) |
| G6 | Graphics: materials audit, lighting per region, post-processing, thin sword trails, contact sparks, dust, elemental and environmental effects, budgets; GRAPHICS_BIBLE, SHADER_LIBRARY, VFX_BIBLE, PERFORMANCE_REPORT | DOING (agent) |
| G7 | Sixteen combos individually animated | TODO — limited by owned clips; see ANIMATION_SOURCES |
| G8 | Dragons: jaw, walk, wing fold/flap, death | TODO |
| G9 | Creature sound libraries; layered combat effects; interface sounds | TODO |
| G10 | Voice: third reel cast by character (Witness first), no blanket pitch shift; then rewrite and record | TODO — reel, then BLOCKED on owner |
| G11 | Real modular armour geometry (8 named sets × 2 bodies) | BLOCKED on budget: generated whole-body sets cost about $1.35 each ($21.60 for all) and the added allocation is not yet visible |
| G12 | Directed endings, opening, awakening, memories, technology revelation, boss intros and defeats | TODO — in-engine first; generated footage needs the added allocation |
| G13 | Scripted quests | TODO |
| G14 | Ninth guardian design | TODO |
| G15 | End-to-end flow test; demonstration package; iOS export preparation | TODO |

## Decisions waiting on the owner (do not block other work)
- Paid animation library, if the free ones leave gaps (see A13).
- Title: "Hollow Reign" in use; trademark search not done.
