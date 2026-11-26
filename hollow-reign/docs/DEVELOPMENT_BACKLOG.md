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
| A16 | Each of the 16 combos visually distinct | TODO |
| A17 | Authored clips verified on female knight and each boss (`--screen=animtest --model=…`) | TODO |
| A18 | Sentinel: richer attack set, own movement style | DONE — 20 patterns, three phases, drill/thrust/give-ground identity; balance tests pass |
| A19 | Subtle temporary sword trails; replace drawn parry arrow with blade glint | TODO |
| A20 | Camera redesign for the duel | DOING — camera now tracks the knight's real position and sits wider |
| A21 | Courtyard art pass | TODO |
| A22 | Visual regression test (golden captures, tolerance) | TODO |
| A23 | Triangle reduction / LOD | TODO |
| A24 | Onboarding as an interactive lesson | TODO |

## B. Audio
| # | Task | Status |
|---|---|---|
| B1 | Six buses: Music, Dialogue, Combat, Ambience, Interface, Cinematics | DONE — routed with trims, master limiter, dialogue ducks music and ambience. Unheard |
| B2 | Casting profiles (`docs/VOICE_BIBLE.md`) and audition reel with several candidates per role | DOING — profiles written; measured catalogue building; reel next, then BLOCKED on owner's ears |
| B3 | Combat effects synchronised to contact frames; footsteps, armour, effort sounds | TODO |
| B4 | Adaptive music layers | TODO |
| B5 | `SOUND_DESIGN_BIBLE.md`, `SOUNDTRACK_PLAN.md`, `AUDIO_ASSET_MANIFEST.md` | TODO |

## C. Cinematics
| # | Task | Status |
|---|---|---|
| C1 | Hybrid: live knight over filmed backgrounds, so equipment and body show | TODO |
| C2 | Re-film crowded Courtyard stops 3 and 5 | TODO |
| C3 | Memories, conversations, finishers | TODO |
| C4 | `CAMPAIGN_SCRIPT.md`, `CINEMATIC_SCRIPT.md` | TODO |

## D. Campaign roll-out (after A is accepted)
| # | Task | Status |
|---|---|---|
| D1 | Unique mechanics and movement per boss (8 remaining + Devourer) | TODO |
| D2 | Dragons on the stance system | TODO |
| D3 | Environment kits for the six regions still on primitive geometry | TODO — costs about $3–4 each on Tripo |
| D4 | Optional quests, lore collectibles, memories | TODO |
| D5 | Three endings, New Game Plus check | TODO |
| D6 | Modular armour customisation | TODO |

## E. Delivery
| # | Task | Status |
|---|---|---|
| E1 | 20 demonstration recordings | TODO |
| E2 | iOS export preparation | BLOCKED — needs a Mac with Xcode and an iPhone (owner) |
| E3 | Device performance | BLOCKED — same |
| E4 | Audio sign-off | BLOCKED — needs the owner to listen |

## Decisions waiting on the owner (do not block other work)
- Paid animation library, if the free ones leave gaps (see A13).
- Title: "Hollow Reign" in use; trademark search not done.
