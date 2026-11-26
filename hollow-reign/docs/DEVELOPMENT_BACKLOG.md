# Development backlog

Work top to bottom. Status: TODO · DOING · DONE (evidence) · BLOCKED (why, and on whom).
Update this file in the same commit as the work.

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
| A19 | Subtle temporary sword trails; replace drawn parry arrow with blade glint | DOING — trails exist; seam and parry prompts shrunk and dimmed; blade glint not done |
| A20 | Camera redesign for the duel | DOING — camera now tracks the knight's real position and sits wider |
| A21 | Courtyard art pass | TODO |
| A22 | Visual regression test (golden captures, tolerance) | DOING — `tools/visual_test.sh` written; golden images not yet captured |
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
| C1 | Hybrid: live knight over filmed backgrounds, so equipment and body show | TODO |
| C2 | Re-film crowded Courtyard stops 3 and 5 | TODO |
| C3 | Memories, conversations, finishers | TODO |
| C4 | `CAMPAIGN_SCRIPT.md`, `CINEMATIC_SCRIPT.md` | DONE — written; new lines marked proposed |

## D. Campaign roll-out (after A is accepted)
| # | Task | Status |
|---|---|---|
| D1 | Unique mechanics and movement per boss (8 remaining + Devourer) | DOING — one rule trait each (`TRAITS` in `tools/gen_bosses.py`), tested; pattern sets not yet widened like the Sentinel's |
| D2 | Dragons on the stance system | DOING — dragons now ride the turning line; needs a capture |
| D3 | Environment kits for the six regions still on primitive geometry | DOING — Cathedral kit in and captured (237k triangles); other five kits: 42 concepts made, models generating (`tools/kit_props.py`), layouts written in `arena.gd`; needs captures per region |
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

## Decisions waiting on the owner (do not block other work)
- Paid animation library, if the free ones leave gaps (see A13).
- Title: "Hollow Reign" in use; trademark search not done.
