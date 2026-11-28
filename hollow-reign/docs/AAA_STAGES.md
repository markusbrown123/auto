# AAA overhaul: implementation stages (2026-11-28)
Requirements: docs/MASTER_REQUIREMENTS.md Addenda 7 and 8. Recovery point: 977c70a (Phone Test 02).
Rule: one agent per file group at a time; each stage ends with check + all suites + normal-speed recordings reviewed by eye + commit.

| Stage | Content | Main files | Depends on | Status |
|---|---|---|---|---|
| 0a | Opening/tutorial shuffling forensics and fix | sfx.gd, fighter_rig.gd (audio hooks), cine_player.gd, story.gd | — | done ed7815d |
| 0b | Recorded-sound audition pack + licence ledger | art/sfx_recorded, docs/AUDIO_SOURCES_RECORDED.md | — | done (audition sent) |
| 0c | Cutscene backgrounds survey + first sword visibility fix | src/cine/*, src/world/* | — | done 93bd4d7 |
| 0d | Equipment screen and shop overhaul | src/ui/armory*, shop, gear_ui, inv_preview, item_stage | — | done 54d0491 |
| 0e | Logo, icon, merchant and Monarch concepts (approved credits) | marketing/presentation_pass | — | done 25b6890 (owner to pick) |
| 1 | **Opening sequence**: awakening chamber rebuilt (detailed ancient facility, restrained light, entrance/exit), waking machine, waking and getting-up animation (packs, both bodies), sword on its holder with cinematic pickup and correct grip, Witness discovery and awakening, leaving the room into the world | awakening/opening cine, chamber build (future.gd section), skin_driver clips, witness_drone.gd | 0c | done 250e262 |
| 2 | **Locomotion and idle**: breathing reduced (visual and audio), calm idle, weighted walk without sliding, turns, stairs, slopes, surface changes, stable camera with obstruction avoidance | fighter_rig.gd, skin_driver.gd, camera | 0a | done d840bee + follow-up |
| 3 | **Continuous Courtyard** (TRAVERSAL_PLAN steps 1-7): connected route from chamber exit and hillside to the inner ward, branches, optional rooms, stairs, bridge, elevations, hidden areas, backtracking, world-placed props/chests/levers/gates with animation and sound, enemies as inhabitants with entrances, duels in place, bodies remain, Witness companion behaviour, no pop-in (streaming, LOD, occlusion) | court_route.gd, future.gd, explore.gd, main.gd, duel.gd entry, gen_regions.py, foe_entrance.gd | 1, 2 | 3A route done 5c3e708; 3B encounters/interactions running; 3C environment detail running |
| 4 | **Cinematics and characters**: every slice cutscene directed (cameras, light, acting, equipped gear, entrances/exits), merchant workshop and animations, Monarch/merchant models (3D only with approved spend) | src/cine/*, sanctuary workshop | 1, 3, 0e choice | done in code (see Stage 4 notes); recordings in marketing/stage4 |
| 5 | **Audio integration**: approved recorded sounds in place with distance falloff, ambience zones along the route, machinery, combat set synced to contact, full soundtrack on the approved theme (credits asked first), mix for speaker/headphones | sfx.gd, music cues, assets/audio | 0b approval, 3 | |
| 6 | **Branding, menus, loading**: chosen logo/icon in game and export, title reveal with the theme, main menu, startup, loading screens only where needed, UI consistency at iPhone sizes | launch.gd, title_screen.gd, loading_screen.gd, ui.gd, icons | 0e choice | logo A on title + icon A done 12aecdc; rest pending |
| 7 | **QA and build**: full normal-speed recordings from launch to the sanctuary after the Sentinel, both bodies, death/retry; fix list; clean clone; build document | all | 1-6 | |

Cannot be verified here: anything on the phone (performance, heat, touch feel), how audio sounds (nobody listens here), Theora on iOS.

Stage 3 is split: 3A (route, streaming, continuous explore; running), 3B (foe entrances, duels in place, interactive props, bodies remain, Witness companion on the route).

## Stage 4 notes (2026-11-28)
- **Monarch**: `assets/models/forgotten_monarch.glb` is now the approved new model, written by `tools/fix_rigged_glb.py monarch`
  from `art/models/monarch_v2.glb` (the old model stays in `art/models/forgotten_monarch.glb`): the concept's sword, a
  separate piece of the mesh skinned to the hands, is removed (the game's `w_monarch` is his only blade), and the cloak
  is bound to the trunk (collar to the clavicles, spine to hips by height, the hem to both thighs) instead of the upper
  arms. The long rigid cloak cannot lie flat: a fallen Monarch stands it up off the floor, so the Aftermath kneels him
  (`CineSeat.kneel`, `slump`). Bench: `tools/dev/foe_bench.tscn`.
- **Orren's workshop**: the shop is held in it (`src/ui/workshop.gd`, built by `KnightStage` "forge"; `--noworkshop`
  gives the plain cove back); Orren is `src/ui/orren.gd` (procedural work over the `idle` clip, voice-driven head and
  hand, per-line business). Bench: `tools/dev/workshop_bench.tscn`.
- **Asked of other owners**: the Monarch's death in `duel.gd` (kneel instead of `die()`); the Witness's halo size in close
  shots (`witness_drone.gd`; the Awakening halves it locally); the Forge tab still shows the hall, not the workshop.

## Owner directive for Phone Test 03 (2026-11-28, evening)
Priorities: finish the castle environments and continuous traversal; finish the awakening room, sword pickup and get-up;
a proper Witness introduction (never appearing at random); fix the checkpoint Retry failure; investigate the "untextured
grey knight" and check every equipment material; finish the cutscenes. Merchant and Monarch: the $2.70 for both models is
already spent and logged (no new purchase); they must be rigged and animated, and the merchant needs a working workshop.
Equipment: full shop/armory redesign (see the knight wearing every selection, rotate and inspect, compare stats, buy, the
change shows in gameplay and cutscenes, text never covers the character). Audio: one audition sheet for every remaining
decision, approved together. Performance: expensive renders and playthroughs run one at a time; no duplicate recordings or
test copies; iPhone budget kept through the castle rebuild. Final standard: an actual playthrough from startup to the
Sentinel's defeat and back to the sanctuary. Stop only for decisions that need approval; spend nothing beyond approval.

Plan and status:
- Retry check: passes on a quiet machine (fix_pass PASS, knight at the chapel anchor); the earlier failure was load. Re-run
  in Stage 7.
- Audition sheet (every remaining sound, music and voice decision, picks saved for Claude to read):
  https://claude.ai/artifact/JxJBpYqxgYCq2abb4Mx5mG. 14 recorded-sound categories (free), 3 music cues against the current
  tracks (free) plus the full chapter soundtrack (up to 80 credits, asks approval), 7 unrecorded first-chapter lines
  (about 14 credits, asks approval). Stage 5 waits for the picks.
- Stage 3C (environment) and Stage 4 (cinematics, merchant, Monarch) resumed after the container restart.
- Stage E (new, after Stage 4 because it shares the shop/armory files): equipment and shop redesign plus the grey-knight
  and material audit.
- Then Stage 5 (audio, on the picks), Stage 6 (title, menus, loading), Stage 7 (QA, sequential full playthroughs, build doc).
- 2026-11-28: the owner rejected every recorded effect on the sheet (music and voice still open) and chose the free Sonniss
  GDC bundles. sonniss.com refuses this container (Cloudflare "Just a moment" page, also in a headless browser), so the
  owner downloads the chosen packs on the Mac and shares them; raw files go only in git-ignored art/sfx_src/ (the licence
  allows use in the game, not redistribution of the library). Until then the synthesised effects stay.
