# Hollow Reign: cinematic script

Shot lists for the opening, the Courtyard walks, every boss introduction and death/memory, and the three endings. Written 2026-11-26. Companion to `CAMPAIGN_SCRIPT.md`; dialogue is cited by scene id from `data/dialogue.json`.

## Status key
- **EXISTS (in-engine render)**: a file in `assets/video/` filmed from the game's own scene by `src/cine/clip_stage.gd` and cut by `tools/render_clips.sh`.
- **EXISTS (generated clip)**: a file in `assets/video/` produced by a video generation service.
- **EXISTS (live)**: staged in real time by game code today, no footage.
- **PLANNED**: nothing exists. Every planned shot is a proposal.

Footage was not viewed while writing this document. Framing and camera notes for existing clips are taken from the camera code in `clip_stage.gd` and from `docs/CINEMATIC_COMBAT.md`, not from watching the files. Each existing clip still needs a continuity and equipment check, as the master requirements ask. No audio described here has been heard by anyone.

## What exists today (file list checked 2026-11-26)

| File(s) in `assets/video/` | Length | Kind | Used by |
|---|---|---|---|
| `courtyard_road_0.ogv` … `courtyard_road_6.ogv` | 6.0 s each | In-engine render | `src/cine/cine_road.gd` via `data/cine_courtyard.json` (clips `road_0` … `road_6`) |
| `stills/courtyard_stop_0.jpg` … `courtyard_stop_6.jpg` | — | Last frame of each walk | Same; shown after the walk, with tap hotspots |
| `sentinel_intro.ogv` | 6.0 s | In-engine render | `src/cine/cine_duel.gd` via `data/cine_sentinel.json` |
| `sentinel_idle.ogv`, `sentinel_open.ogv`, `sentinel_counter.ogv`, `sentinel_recover.ogv` | 3.0 s each | In-engine render | Combat loop |
| `sentinel_a_tele.ogv` (1.7 s), `sentinel_a_parry/dodge/block/hit.ogv` (4.3 s each) | | In-engine render | "Overhead" exchange |
| `sentinel_b_tele.ogv` (1.5 s), `sentinel_b_parry/dodge/block/hit.ogv` (4.5 s each) | | In-engine render | "Sweep" exchange |
| `sentinel_victory.ogv` | 6.0 s | In-engine render | Final blow |
| `sentinel_defeat.ogv` | 4.5 s | In-engine render | Player's death |
| `sentinel_memory.ogv` | 5.0 s | Generated clip (Seedance 2.5, 720p; see `SPENDING_LOG.md`) | Plays under `sentinel_memory` |

Gaps and oddities in the file list
- `sentinel_travel.ogv.uid` exists but `sentinel_travel.ogv` does not. `CINEMATIC_COMBAT.md` counts "1 travel clip" and "19 clips"; today there are 18 Sentinel clips. The travel walk appears to have been replaced by the seven road clips.
- `sentinel_memory.ogv` is not an in-engine render. `CINEMATIC_COMBAT.md` records that the generated soldiers wear generic plate, not the game's armour design.
- All existing footage shows one loadout: the male knight, Courtyard Longsword, Garrison Kite. There is no female-knight footage.
- Existing clips are 720p30 Ogg Theora. Their own audio track is silenced (`volume_db = -80` in `cine_player.gd`); all sound is played live.

## Conventions for planned shots
- Shot sizes: ELS extreme long, LS long, MS medium, MCU medium close-up, CU close-up, OTS over the shoulder.
- Every boss intro ends on the combat camera (behind the knight's right shoulder: `cam_base` in `clip_stage.gd`) so play can begin without a cut.
- Every clip starts and ends on a held pose, as the existing combat clips do, so joins are invisible.
- PROPOSED: where the knight's equipment must be right, keep the knight out of frame or render live over a filmed background (the hybrid route in `CINEMATIC_COMBAT.md`).
- Audio column: bus in brackets. Music cue names are from `SOUNDTRACK_PLAN.md`; sound events from `SOUND_DESIGN_BIBLE.md`.

---

## 1. The opening

Status: EXISTS (live) as a black screen with narration, then a camera move in the Sanctuary set (`src/main.gd`: fader at full black, `theme` music, `opening`, fade over 2.5 s, camera move, `awakening`, `first_road`). The shot list below is PLANNED and would replace the black screen.

| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| O1 | Black | — | 4 s | Nothing. | [Music] `theme` solo cello enters. [Dialogue] `opening_01` |
| O2 | ELS, a walled city at dusk, lit windows | Slow push in | 5 s | Lights come on in rows, too regular for torches. | [Dialogue] `opening_02` |
| O3 | MS, a row of identical thrones, figures seated, faces in shadow | Lateral track | 9 s | The figures do not move. Dust does. | [Dialogue] `opening_03`. [Cinematics] low machine hum |
| O4 | LS, a crowd with torches at a gate | Handheld drift | 5 s | The gate gives. | [Dialogue] `opening_04`. [Cinematics] crowd, distant, filtered |
| O5 | ELS, the same city, dark, overgrown | Static, time-lapse of seasons | 9 s | Three hundred years pass: snow, green, snow. | [Dialogue] `opening_05`. [Music] theme falls back to solo cello |
| O6 | CU, a dead indicator on a stone wall | Static | 3 s | It lights. | [Dialogue] `opening_06`. [Cinematics] `cine_crown_wake` single tone. Music cuts to silence |
| O7 | MCU, the resurrection chamber, lid cracked, the knight's hand on the rim | Slow tilt up to the face/helm | 8 s | The Unbound sits up. Light from old machinery flickers. | [Dialogue] `awakening` begins (`awakening_01` "Can you hear me?"). [Ambience] `amb_sanctuary` |
| O8 | MS, knight seated on the chamber edge; a wall speaker grille behind | Slow orbit, 30° | 18 s | The exchange. The knight looks at their own hands on `awakening_06`. | [Dialogue] `awakening_02` … `awakening_07`. [Music] `hub` enters under the last line |
| O9 | LS from behind the knight, a stair up to daylight | Static, then follow | 15 s | The knight stands, takes the sword from the rack, climbs. | [Dialogue] `first_road`. [Combat/Ambience] `foot_stone`, `armor_move` |

Proposed footage route: O2–O6 generated (places and distant history, the use `CINEMATIC_COMBAT.md` recommends for generation); O7–O9 in-engine so both knights and their equipment are exact.

---

## 2. Courtyard exploration walks

Status: EXISTS (in-engine render), seven clips of 6.0 s. Each plays once in full; on a retry or return the player arrives at the still at once (`cine_road.gd`). Tap skips after 0.4 s. Five footstep sounds are fired on a fixed timer (0.6 s, then every 0.85 s), not from the footage. After arrival the still (the walk's last frame) shows with hotspots, and the stage remark plays.

| Clip | Stage | Intended content | Camera (from code: "road" mode follows the knight) | Hotspots at arrival | Dialogue after arrival | Audio during walk |
|---|---|---|---|---|---|---|
| `courtyard_road_0` | 0 The Breach | Knight walks from the fortress door to the fallen outer wall; a soldier in garrison plate ahead. | Follow from behind | 1 (The Breach) | `courtyard_0` | [Music] `explore_courtyard`. [Ambience] `wind`, `footstep` ×5 |
| `courtyard_road_1` | 1 Guardhouse / Rampart Stair | Past the rubble to where the path divides. | Follow | 2 | `courtyard_1` | Same |
| `courtyard_road_2` | 2 The Barbican | Toward the barbican and its banner; a figure at attention. | Follow | 1 | `courtyard_2` | Same |
| `courtyard_road_3` | 3 Winch / Well | To the winch-house beside the inner gate. | Follow | 2 | `courtyard_3` | Same |
| `courtyard_road_4` | 4 Gate Passage / Murder Hole | Into the narrow gate passage. | Follow | 2 | `courtyard_4` | Same |
| `courtyard_road_5` | 5 Kneel | To the chapel alcove and the candle. | Follow | 1 | `courtyard_5` | Same |
| `courtyard_road_6` | 6 The Inner Ward | Into the inner ward; the Sentinel standing at his post. | Follow, hotspot sits higher in frame (y 0.443) | 1 | `courtyard_6` | Same |

To verify by viewing: that each clip's content matches its stage prompt; that feet do not slide; that the footstep timer lands on visible footfalls (it is not derived from the animation, so it probably does not).

PLANNED additions for the Courtyard
- A second set for the female knight, or the hybrid route (filmed background, live knight).
- Per-walk footstep cue lists in `data/cine_courtyard.json` (times of visible heel strikes) replacing the fixed timer.
- A short "treasure" insert (2 s, CU of the chest or the well) per treasure stage.

Walks for the other seven regions are PLANNED. Template per region: seven 6-second follow shots ending on a still with hotspots, each ending on the stage's landmark as given by its prompt in `data/regions.json`.

---

## 3. Boss introductions

Dialogue plays live over the picture. In the real-time duel the intro today is: bell, the foe holds guard, the `_intro` scene plays, then a roar and the fight (`duel.gd`). On later attempts the `_retry` scene and a title card with the boss's name and intro text.

### 3.1 The Ashen Sentinel — EXISTS (in-engine render, `sentinel_intro.ogv`, 6.0 s)
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| S1 | MS on the Sentinel from his flank, moving to OTS behind the knight | One unbroken sweep from the Sentinel's flank round to the combat camera; arrives early and holds (from `clip_stage.gd`, "intro" mode) | 6.0 s | Sentinel at his post, greatsword grounded. Knight enters frame as the camera settles. | [Dialogue] `sentinel_intro` on first meeting, `sentinel_retry` afterwards. [Music] `boss_ashen_sentinel`. [Ambience] `wind` |

PLANNED extension (two shots before S1): ELS of the inner ward with embers drifting from the gatehouse (3 s, static); CU of the Sentinel's helm turning 10° toward the knight (2 s) on "State your allegiance."

### 3.2 The Pale Huntsman — PLANNED
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| H1 | LS through trunks, white antlers crossing behind them | Slow lateral track, trunks wiping frame | 4 s | A shape keeps pace with the knight, three trees back. | [Ambience] `amb_blackwood`, single `foot_leaf`. Music out |
| H2 | MCU, the Huntsman stepping out, axe low | Static | 5 s | He looks the knight over like an animal he has seen before. | [Dialogue] `huntsman_intro_01` |
| H3 | OTS knight | Push in to combat camera | 4 s | Knight answers; he raises the axe. | [Dialogue] `huntsman_intro_02`, `_03`. [Music] `boss_pale_huntsman` enters on the last word |

### 3.3 The Hollow Executioner — PLANNED
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| E1 | ELS, the clearing of stumps, fog | Static | 3 s | Empty. | [Combat] `exec_cleaver_drag` off-screen, approaching |
| E2 | CU, the cleaver's edge dragging through roots | Follow at ground level | 3 s | It leaves a furrow. | Same, close |
| E3 | Low MS up at the Executioner | Slow tilt up | 4 s | He stops. Reads the knight as a clerk reads a form. | [Dialogue] `executioner_intro_01` |
| E4 | OTS knight | Settle to combat camera | 5 s | Exchange. He lifts the cleaver to his shoulder. | [Dialogue] `executioner_intro_02`, `_03`. [Music] `boss_hollow_executioner` |

### 3.4 The Crimson Widow — PLANNED
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| W1 | LS up the cathedral steps, a red figure against the great doors, ash falling | Slow crane up the steps | 5 s | She is already watching. | [Ambience] `amb_cathedral`. Music: solo viola, single held note |
| W2 | CU, her eyes on the knight's feet and guard | Static | 3 s | Recognition, and she does not like it. | [Dialogue] `widow_intro_01` |
| W3 | Two-shot, profile | Slow push | 5 s | She draws both blades without hurry. | [Dialogue] `widow_intro_02`, `_03` |
| W4 | OTS knight | Settle to combat camera | 2 s | She comes down one step. | [Music] `boss_crimson_widow` |

### 3.5 The Cathedral Beast — PLANNED
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| B1 | LS, the fallen bell in the crossing, open sky above | Static | 4 s | The bell tolls. Nothing touches it. | [Combat] `beast_bell_toll`. Music out |
| B2 | CU, the bell's cracked mouth, dark inside | Slow push in | 4 s | Something shifts in the bronze. | [Combat] `beast_breath`. [Dialogue] `beast_intro_01` (Lyra) |
| B3 | LS, the Beast unfolding out of the bell on four limbs | Pull back fast to combat camera | 4 s | It shakes off ash and faces the knight. | [Combat] `beast_roar`. [Music] `boss_cathedral_beast` |

### 3.6 The Gravewarden — PLANNED
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| G1 | ELS down a drained hall of niches, one lantern at the far end | Slow dolly forward | 6 s | The lantern does not move. | [Ambience] `amb_crypt_deep`. Music: low drone only |
| G2 | MCU, the Gravewarden in profile, lantern raised to a niche | Static | 4 s | He is reading a name. He finishes before turning. | [Dialogue] `gravewarden_intro_01` |
| G3 | Two-shot across the lantern | Slow orbit to OTS knight | 6 s | He sets the lantern down with care, then takes up the greatsword. | [Dialogue] `gravewarden_intro_02`, `_03`. [Music] `boss_gravewarden` |

### 3.7 Veyrath, the Cinder Wyrm — PLANNED
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| V1 | ELS, the summit, knight small at frame bottom, huge sky | Static | 4 s | A shadow crosses the sun. | [Ambience] `amb_roost`. [Combat] `wyrm_wing_pass` |
| V2 | Knight's POV, sky | Whip pan following the shadow back | 2 s | It comes back. | [Combat] `wyrm_wing_pass` louder |
| V3 | LS, Veyrath landing on the far rock | Camera jolts on landing | 3 s | Glazed stone cracks under her. | [Combat] `wyrm_land`. [Dialogue] `wyrm_intro_01` (Lyra) |
| V4 | Low MS, her head lowering to the knight's height | Slow push to combat camera | 4 s | She studies the knight. Then the throat lights. | [Combat] `wyrm_inhale`. [Music] `boss_cinder_wyrm` |

### 3.8 Skeldra, the White Ruin — PLANNED
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| K1 | LS straight down the pit, a chain running into the dark | Slow descent | 5 s | The chain is moving. | [Combat] `skeldra_chain`. Music out |
| K2 | CU, a link rimed white, frozen through | Static | 3 s | It is not holding anything. It has not for an age. | [Dialogue] PROPOSED `rimewyrm_intro` (not recorded) |
| K3 | LS, Skeldra raising its head from its coils | Settle to combat camera | 4 s | Frost falls from it. It does not pull against the chain. | [Combat] `skeldra_roar`. [Music] `boss_rimewyrm` |

### 3.9 The Frostbound King — PLANNED
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| F1 | ELS, the hall of the winter throne, a seated figure sheathed in ice | Slow dolly down the aisle | 6 s | Breath shows from the knight, none from the King. | [Ambience] `amb_citadel`. Music: high glass tones only |
| F2 | CU, ice over a crowned helm | Static | 5 s | A crack runs across it as he speaks. | [Dialogue] `frostking_intro_01` |
| F3 | MS, knight | Static | 3 s | Knight asks. | [Dialogue] `frostking_intro_02` |
| F4 | Low MS, the King standing, ice falling in sheets | Tilt up, then settle to combat camera | 6 s | He rises as if it costs him. | [Dialogue] `frostking_intro_03`. [Combat] `frost_shatter`. [Music] `boss_frostbound_king` |

### 3.10 The Devourer of Names — PLANNED
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| D1 | LS, the bottom of the Deep, lit from no source | Static | 4 s | A mass that might be a crowd. | Music out. [Ambience] `amb_deep` drops to near silence |
| D2 | CU, one face surfacing in it, a man's | Slow push | 3 s | It speaks. | [Dialogue] `devourer_intro_01` |
| D3 | CU, another face, a woman's | Static | 3 s | | [Dialogue] `devourer_intro_02` |
| D4 | CU, a child's, looking straight at the lens | Static | 4 s | | [Dialogue] `devourer_intro_03` |
| D5 | LS, the whole body gathering itself upright | Pull back to combat camera | 4 s | It comes forward on too many hands. | [Combat] `devourer_gather`. [Music] `boss_devourer` |

### 3.11 The Forgotten Monarch — PLANNED
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| M1 | ELS, the throne room, doors open, a figure seated far off | Slow dolly in, symmetrical | 6 s | He does not rise. | [Ambience] `amb_throne`. Music: `theme` motif, solo cello, very quiet |
| M2 | MS, the Monarch, one hand open toward the hall | Static | 4 s | The walls behind him are racks of faint lights. | [Dialogue] `monarch_intro_01` |
| M3 | MCU knight | Static | 4 s | | [Dialogue] `monarch_intro_02` |
| M4 | CU Monarch | Very slow push | 5 s | Patient. Some lights behind him go out as he speaks. | [Dialogue] `monarch_intro_03` |
| M5 | Two-shot down the aisle | Static | 8 s | The question and the answer. | [Dialogue] `monarch_intro_04`, `_05` |
| M6 | OTS knight | Settle to combat camera | 3 s | He remains seated; the fight starts with him on the throne (phase card at 66%: he rises). | [Music] `boss_forgotten_monarch` |

---

## 4. Boss deaths and memories

In the real-time duel today: the finisher sound, music fades over 2.5 s, a bell, a victory sting, then `<key>_death` and `<key>_memory` are played over the live scene. Only the Sentinel has footage.

### 4.1 The Ashen Sentinel — EXISTS
| # | File | Framing / camera (from code) | Dur. | Action | Audio |
|---|---|---|---|---|---|
| SD1 | `sentinel_victory.ogv` (in-engine) | From the combat camera, moves in and to the left and tilts down ("victory" mode); impact marker at 0.68 of the clip | 6.0 s | The final blow; the Sentinel goes down. | [Combat] impact at the marker, `victory`. [Dialogue] `sentinel_death` follows |
| SD2 | `sentinel_memory.ogv` (generated) | Not verified; intended as the Courtyard three centuries ago | 5.0 s, shown without loop | The garrison at the gate. Armour in the clip is generic plate, not the game's design. | [Dialogue] `sentinel_memory` (Archivist ×2, Lyra). Lasts about 20 s of speech over 5 s of picture, so the last frame is held |
| SX | `sentinel_defeat.ogv` (in-engine) | Camera rises and looks down at the knight ("defeat" mode) | 4.5 s | The player's death. | [Combat] `death` |

PLANNED fixes: extend or loop SD2 so the picture lasts as long as the three memory lines; re-render the memory in-engine with the game's garrison armour, or keep the soldiers distant and silhouetted.

### 4.2 Planned death and memory shots for the other bosses
Each is two parts: a death beat staged in-engine at the arena, then a memory insert (a place or distant figures, suitable for generation). All PLANNED.

| Boss | Death beat (in-engine) | Dur. | Memory insert | Dur. | Dialogue |
|---|---|---|---|---|---|
| Pale Huntsman (killed) | MS: he sits back against a trunk, axe across his knees, watching the knight until he stops. Static. | 6 s | None; he is mortal and leaves no record. | — | PROPOSED `huntsman_death` (not recorded) |
| Pale Huntsman (yielded) | Two-shot: knight's blade held at his throat, then lowered. He picks up his axe and backs into the trees. Slow pull back. | 10 s | — | — | PROPOSED `huntsman_yield` (not recorded) |
| Hollow Executioner | Low MS: he kneels at one of his own stumps and lays his head down. Camera does not show a blow. Cut to black. | 6 s | A prison yard lighting up cell by cell, at night, with no one in it. ELS, static. | 5 s | `executioner_death` (Lyra). PROPOSED `executioner_memory` |
| Crimson Widow (yield offered) | MCU: on one knee, one blade dropped, breathing. Hold for the choice prompt. | until input | Six graves on a hillside, a woman standing over them, back to camera. LS, slow push. | 6 s | `widow_death`. PROPOSED `widow_yield`, `widow_memory` |
| Cathedral Beast | LS: it collapses across the bell; the floor under the bell gives way. Camera drops through the hole after it. | 7 s | Not a memory: a reveal. Slow dolly along a lit corridor of glass cradles under the crossing. In-engine. | 12 s | `beast_death` ("A laboratory." on the last frame) |
| Gravewarden | MS: he lowers himself to sit by his lantern. He puts it out himself. | 8 s | The hall of niches, each lit in turn then going dark, a few at a time. ELS, static. | 10 s | PROPOSED `gravewarden_last`; `gravewarden_death` (Archivist); PROPOSED `crypt_truth` |
| Veyrath | ELS: she pulls herself to the edge of the summit and looks at the sky rather than at the knight. Slow push past the knight to her eye closing. | 9 s | Numbered eggshells on a rack, one keeper in a doorway. MS, static. | 5 s | PROPOSED `wyrm_death`, `wyrm_memory` |
| Skeldra | LS: with the chain broken it lays its head beside the last link. If let go (quest 7), it climbs the pit wall and is gone. | 7 s | — | — | PROPOSED `rimewyrm_death` |
| Frostbound King | MCU: the crown splits; under it an old man's face, relieved. Ice in the hall starts to drip. | 8 s | A council table of the Everbound, one empty chair, the King standing to leave. LS, slow lateral track. | 8 s | `frostking_death`. PROPOSED `frostking_memory` |
| Devourer of Names | LS: after the revive it falls a second time and comes apart into separate still figures, lying as if asleep. Slow rise. | 10 s | Faces, one at a time, each for under a second, ordinary and unremarkable. CU, hard cuts. | 8 s | PROPOSED `devourer_death`, `devourer_memory` |
| Forgotten Monarch | MS: he sits back on the throne because standing is finished. He takes the crown off and holds it out. | 10 s | None. The lights behind the throne are the memory. | — | `monarch_death` (leads straight into the ending choice) |

---

## 5. The three endings — all PLANNED

Shared lead-in (after `monarch_death`):

| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| X1 | MS, the Crown mechanism behind the throne opening | Slow push | 6 s | Racks of lights, most dark. | [Cinematics] `cine_crown_hum`. Music: silence |
| X2 | OTS knight, the choice prompt over the mechanism | Static | until input | Two options, or three if the third ending is unlocked. | [Dialogue] `monarch_death_02`, `_03` (Lyra's rain line) plays here |

### Ending 1: The Final Silence
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| A1 | CU, the knight's hand on the main coupling | Static | 4 s | Pulls it. | [Cinematics] `cine_crown_disconnect` |
| A2 | LS, the racks going dark row by row | Slow pull back | 10 s | The hall dims to window light. | [Music] `ending_silence`: solo cello, no accompaniment. PROPOSED Lyra lines (not recorded) |
| A3 | Montage: the candle in the Courtyard alcove going out; the bell in the crossing still; the Sanctuary speaker grille silent | Static shots, 3 s each | 9 s | The maintenance points stop. | Lyra's voice thins and stops mid-word |
| A4 | ELS, the capital from outside, sunrise | Static | 12 s | First light. The knight walks out alone. | [Ambience] birdsong begins, the first in the game. Music resolves |

### Ending 2: The Last Steward
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| S1 | MS, the knight picking up the crown from the Monarch's hands | Static | 5 s | Looks at it. | Music: `theme` motif on low strings, unresolved |
| S2 | LS, the knight sitting on the throne | Slow symmetrical dolly in, mirroring M1 | 10 s | Same framing as the Monarch's introduction. | PROPOSED ending-2 lines (not recorded) |
| S3 | CU, the racks; a few dark lights come back on | Static | 6 s | It is not clear what that cost. | [Cinematics] `cine_crown_hum` steadier |
| S4 | MCU, the knight's helm, lit from below by the crown | Hold, then cut to black on a breath | 6 s | No expression to read. | [Music] `ending_steward`: ends on a held chord without its root |

### Ending 3: The Free Cities
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| C1 | CU, the Partition Key set into the mechanism | Static | 4 s | Turned. | [Cinematics] `cine_crown_partition` |
| C2 | LS, the racks separating into clusters, each with its own light colour | Slow orbit | 10 s | No centre remains. | PROPOSED Archivist line (not recorded) |
| C3 | Montage: the Crypt niches, some going dark by choice, some bright; a workshop where a body is being built; Orren at his forge looking up | Static shots, 4 s each | 12 s | The stored choose. | [Music] `ending_free_cities`: the motif completed for the first time (it rises and does not fall back) |
| C4 | MS, the Sanctuary, a second chamber opening | Slow push | 8 s | A hand on the rim. We do not see a face. | PROPOSED Lyra line, heard without the machine filter for the first time |
| C5 | ELS, several towns at dusk, each lit differently | Slow crane up | 10 s | | Music out on the full motif |

### Post-credits (story bible)
| # | Framing | Camera | Dur. | Action | Audio |
|---|---|---|---|---|---|
| P1 | ELS, a fortress under an unfamiliar sky (two moons or a different star field) | Static | 6 s | Still. | [Ambience] wind of a different pitch. No music |
| P2 | CU, a dark console | Static | 8 s | Text appears: "Local network disconnected. Searching for external systems." | [Cinematics] `cine_external_search` |
| P3 | Same | Static | 4 s | A second line of light answers. Cut to black. | [Cinematics] `cine_external_answer`: one distant tone, a fifth above |

---

## Production notes
- Footage cost from `CINEMATIC_COMBAT.md`: about 0.55 MB per second at 720p Theora. The planned boss intros (ten at 11 to 30 s) and death scenes total roughly 5 minutes, about 165 MB before any per-loadout variants. That is a planning figure, not a measurement.
- Nothing has run on an iPhone. Decoder load on a device is unknown.
- Every planned generated shot needs a spending entry and must fit the $100 cap. This document authorises none.
