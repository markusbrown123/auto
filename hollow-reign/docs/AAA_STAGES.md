# AAA overhaul: implementation stages (2026-11-28)
Requirements: docs/MASTER_REQUIREMENTS.md Addenda 7 and 8. Recovery point: 977c70a (Phone Test 02).
Rule: one agent per file group at a time; each stage ends with check + all suites + normal-speed recordings reviewed by eye + commit.

| Stage | Content | Main files | Depends on | Status |
|---|---|---|---|---|
| 0a | Opening/tutorial shuffling forensics and fix | sfx.gd, fighter_rig.gd (audio hooks), cine_player.gd, story.gd | — | running |
| 0b | Recorded-sound audition pack + licence ledger | art/sfx_recorded, docs/AUDIO_SOURCES_RECORDED.md | — | running |
| 0c | Cutscene backgrounds survey + first sword visibility fix | src/cine/*, src/world/* | — | running |
| 0d | Equipment screen and shop overhaul | src/ui/armory*, shop, gear_ui, inv_preview, item_stage | — | running |
| 0e | Logo, icon, merchant and Monarch concepts (approved credits) | marketing/presentation_pass | — | running |
| 1 | **Opening sequence**: awakening chamber rebuilt (detailed ancient facility, restrained light, entrance/exit), waking machine, waking and getting-up animation (packs, both bodies), sword on its holder with cinematic pickup and correct grip, Witness discovery and awakening, leaving the room into the world | awakening/opening cine, chamber build (future.gd section), skin_driver clips, witness_drone.gd | 0c | next |
| 2 | **Locomotion and idle**: breathing reduced (visual and audio), calm idle, weighted walk without sliding, turns, stairs, slopes, surface changes, stable camera with obstruction avoidance | fighter_rig.gd, skin_driver.gd, camera | 0a | after 0a |
| 3 | **Continuous Courtyard** (TRAVERSAL_PLAN steps 1-7): connected route from chamber exit and hillside to the inner ward, branches, optional rooms, stairs, bridge, elevations, hidden areas, backtracking, world-placed props/chests/levers/gates with animation and sound, enemies as inhabitants with entrances, duels in place, bodies remain, Witness companion behaviour, no pop-in (streaming, LOD, occlusion) | court_route.gd, future.gd, explore.gd, main.gd, duel.gd entry, gen_regions.py, foe_entrance.gd | 1, 2 | |
| 4 | **Cinematics and characters**: every slice cutscene directed (cameras, light, acting, equipped gear, entrances/exits), merchant workshop and animations, Monarch/merchant models (3D only with approved spend) | src/cine/*, sanctuary workshop | 1, 3, 0e choice | |
| 5 | **Audio integration**: approved recorded sounds in place with distance falloff, ambience zones along the route, machinery, combat set synced to contact, full soundtrack on the approved theme (credits asked first), mix for speaker/headphones | sfx.gd, music cues, assets/audio | 0b approval, 3 | |
| 6 | **Branding, menus, loading**: chosen logo/icon in game and export, title reveal with the theme, main menu, startup, loading screens only where needed, UI consistency at iPhone sizes | launch.gd, title_screen.gd, loading_screen.gd, ui.gd, icons | 0e choice | |
| 7 | **QA and build**: full normal-speed recordings from launch to the sanctuary after the Sentinel, both bodies, death/retry; fix list; clean clone; build document | all | 1-6 | |

Cannot be verified here: anything on the phone (performance, heat, touch feel), how audio sounds (nobody listens here), Theora on iOS.
