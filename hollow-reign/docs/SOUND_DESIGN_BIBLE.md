# Hollow Reign: sound design bible

Every sound event the game needs, grouped by the six mix buses, with what is in the build today. Written 2026-11-26.

## Honesty note
Nobody has listened to any audio in this project. The build environment has no ears. Where a file exists, its status is **exists (synthesised, unheard)**, **exists (generated, unheard)** or **exists (generated speech, provisional, unheard)**. Those words mean a file is on disk and is wired to code; they say nothing about how it sounds. "Character" and "layers" columns for existing synthesised files describe what `tools/gen_audio.py` computes, not what a listener would hear. Everything marked **missing** is a specification and a proposal.

## 1. How the mix works today (read from `src/core/sfx.gd`, `src/core/story.gd`, `src/core/game.gd`, `src/cine/cine_player.gd`)

### Buses
`Sfx._ready()` creates six buses at start-up if they do not exist, all sending to Master: **Music, Dialogue, Combat, Ambience, Interface, Cinematics**. If Master has no effect on it, a limiter is added: ceiling −1 dB, threshold −6 dB.

| Bus | Fixed trim (`BUS_TRIM`) | Player setting that scales it (`BUS_SETTING`) | Default setting | What plays on it today |
|---|---|---|---|---|
| Dialogue | 0 dB | `voice` | 1.0 | One `AudioStreamPlayer` in `story.gd` |
| Combat | −1 dB | `sfx` | 1.0 | Every `Sfx.play()` sound that is not listed as interface or ambient |
| Cinematics | −2 dB | `sfx` | 1.0 | Only the video players in `cine_player.gd`, which are set to −80 dB. In effect nothing audible |
| Music | −3 dB | `music` | 0.8 | Two crossfading players and one layer player |
| Interface | −5 dB | `sfx` | 1.0 | `loot`, `levelup`, `ui_tap`, `ui_back`, `bell` |
| Ambience | −7 dB | `sfx` | 1.0 | The ambience loop player (itself at −8 dB) and `footstep` |

Bus volume is `linear_to_db(setting) + trim`; a bus is muted when its setting is at or below 0.001 (`Game.apply_settings()`). There are three sliders (music, sfx, voice) for six buses: Combat, Ambience, Interface and Cinematics move together.

### One-shot playback
- A pool of 12 players, used round-robin. The thirteenth overlapping sound cuts the oldest. No priority system.
- Routing is by name at play time: in `INTERFACE_SOUNDS` → Interface; in `AMBIENT_SOUNDS` (`footstep`) → Ambience; otherwise Combat.
- Variants: `swing` 3, `clash` 3, `hit_armor` 2, `hit_flesh` 2, `block` 2, `roar` 3, `footstep` 2, picked at random with no repeat-avoidance.
- Each play takes a level in dB and a pitch, and adds random pitch jitter of ±6% by default.
- All one-shots are non-positional mono. Nothing is panned or attenuated by distance.

Routing gaps found in code (facts, not fixes)
- `ui_confirm` is not in `INTERFACE_SOUNDS`, so it plays on Combat.
- `victory`, `death`, `finisher`, `levelup`-as-relic and other stingers play on Combat; `bell` (boss intro and phase change) plays on Interface.
- `footstep` is on Ambience, so combat footsteps drop 9 dB during dialogue while weapon sounds do not.

### Music
- `Sfx.music(track, fade=1.5)`: the new track starts at −40 dB and is raised to −5 dB over the fade; the old one falls to −60 dB and stops. Same track requested twice is ignored. Any music change clears the layer (0.5 s).
- `Sfx.music_for(preferred, fallback)`: plays `preferred` if the file exists, else `fallback`. Used as `boss_<foe id>` → the foe's `music` field; `explore_<region id>` → `menu`; `theme` → `menu`; `hub` → `sanctuary`.
- `Sfx.set_layer(track, fade=1.2)`: a third player starts the layer at the main track's current playback position, raises it to −5 dB and pulls the main track down to −14 dB. Used on boss phase change, only when the foe's `music` field is `combat_a`, and the layer is always `combat_b`.
- Consequence to check: `combat_a` and `combat_b` are synthesised from the same chord chart at the same tempo and length (33.6 s), so layering them is coherent by construction. For the Ashen Sentinel the main track is now `boss_ashen_sentinel` (90.1 s, generated, different tempo and key) and the layer is still `combat_b`, started at the boss track's position. These two were not made to play together.

### Ambience
One looping player at −8 dB on the Ambience bus. `Sfx.ambience(name)` is a hard stop and start with no fade. Regions name their loop in `data/regions.json` (`amb`): `wind` for courtyard, blackwood, roost, citadel, throne; `fire` for cathedral; `crypt` for crypt and deep. The Sanctuary uses `fire`, the title `wind`. `rain` exists and is used nowhere.

### Ducking (implemented)
`Story._duck(on)`: while a dialogue scene is playing, the **Music** and **Ambience** buses are set 9 dB below their normal level (setting + trim − 9). It is applied at once, with no ramp, when the scene starts and removed when the scene ends or is stopped. Combat, Interface and Cinematics are not ducked. There is no other ducking: no sidechain, no low-health filter, no duck on impacts.

### Dialogue timing (implemented)
A line with an audio file is held for the file's length plus 0.45 s. A line without audio is held for 1.4 s plus one second per 15 characters. A tap skips to the next line and stops the audio. Player lines load `<line id>_m.ogg` or `<line id>_f.ogg` by the profile's body.

### Loudness of what exists (from the generating scripts, not measured by ear)
| Group | Target written in the script |
|---|---|
| Synthesised effects (`gen_audio.py`) | Peak-normalised to −3 dBFS each, mono 44.1 kHz 16-bit WAV; no loudness matching between effects |
| Synthesised ambience | −18 LUFS (script's own approximation), stereo, 20 s loops |
| Synthesised music (`menu`, `sanctuary`, `combat_a`, `combat_b`, `final`) | −14 LUFS (script's own approximation) |
| Generated music (`tools/music.py`) | ffmpeg `loudnorm` I=−16, TP=−1.5; 5 s tail-to-head crossfade for looping |
| Generated speech | Not normalised by any script found |

## 2. Mixing targets

Rows 1–3 restate what the code does. The rest are PROPOSED targets for a person to tune by ear.

| # | Rule | Status |
|---|---|---|
| 1 | Order of layers by trim: Dialogue 0, Combat −1, Cinematics −2, Music −3, Interface −5, Ambience −7 | Implemented |
| 2 | Dialogue ducks Music and Ambience by 9 dB, instantly | Implemented |
| 3 | Master limiter, ceiling −1 dB, threshold −6 dB | Implemented |
| 4 | Ramp the dialogue duck: 0.15 s down, 0.6 s up | PROPOSED |
| 5 | Duck Combat by 4 dB under dialogue during scripted scenes only (intro, death, memory), never during play | PROPOSED |
| 6 | Perfect parry and finisher: duck Music 6 dB for 0.4 s so the impact reads | PROPOSED |
| 7 | Low health (under 25%): low-pass Music and Ambience at 1.2 kHz, add `player_heartbeat` | PROPOSED |
| 8 | Integrated loudness: speech −18 LUFS per line; music −20 LUFS in exploration, −16 in boss fights; ambience −28 | PROPOSED |
| 9 | Normalise effects by loudness class instead of by peak: light (swings, steps) −24 LUFS, medium (hits, blocks) −18, heavy (guard break, finisher, roars) −14 | PROPOSED |
| 10 | Move `ui_confirm` to Interface; move `footstep` in combat to Combat; move story stingers (`cine_*`) to Cinematics | PROPOSED |
| 11 | Voice priority: 2 slots reserved for player impacts, steal lowest-level ambient one-shot first | PROPOSED |
| 12 | Positional pan: foe sounds ±20% by screen position | PROPOSED |
| 13 | Separate sliders or at least a separate Ambience level | PROPOSED |

Synchronisation rule for every combat event: the transient lands on the visible contact frame. Today most sounds fire when the simulation emits its event (`duel.gd`), and the foe's swing whoosh is scheduled at `windup − 0.6 × swing`. Whether those moments coincide with the drawn contact frame has not been checked by eye and ear together.

---

## 3. Event catalogue

Columns: **Event** (file base name, or proposed name) · **Trigger and frame** · **Character** · **Layers** · **Var.** (variations needed; existing count in brackets) · **Status**.

### 3.1 Combat bus

#### Swings (whooshes)
| Event | Trigger and frame | Character | Layers | Var. | Status |
|---|---|---|---|---|---|
| `swing` (`swing_1..3`) | Player cut starts (`player_swing`); foe's light attack at `windup − 0.6 × swing`; parry motion at lower level | Band-passed noise sweep, 0.29–0.34 s | Swept noise, high air | 3 (3) | exists (synthesised, unheard) |
| `swing_heavy` | Foe attack when its scale is over 1.3 or the attack is a slam | Slower sweep with low rumble, 0.62 s | Swept noise, sub layer | 3 (1) | exists (synthesised, unheard); 2 more missing |
| `swing_sword_*` | Frame the blade passes shoulder height, sword class (swing time 0.26 s) | Clean, narrow, mid-high | Air, edge whistle | 4 | missing (generic `swing` used) |
| `swing_greatsword_*` | Frame the blade passes the hip on the downswing (0.46 s) | Long, low, with weight | Air, low body, cloth | 4 | missing |
| `swing_axe_*` | Frame the head passes the shoulder (0.38 s) | Blunt, shorter, head-heavy thrum | Air, haft creak | 4 | missing |
| `swing_dual_*` | Each blade's pass; second blade 60–90 ms after the first (0.18 s) | Two short, bright cuts | Air ×2 | 4 | missing |
| `swing_cleaver_*`, `swing_glaive_*`, `swing_claws_*` | Enemy classes cleaver, glaive, claws at their swing frame | Cleaver: wide and dull. Glaive: long with a late tip whistle. Claws: three close short cuts | Air, material | 3 each | missing |
| `swing_combo_finish` | Last cut of a named combo | Longer tail, rising pitch | Air, shimmer | 2 | missing |

#### Blade contact
| Event | Trigger and frame | Character | Layers | Var. | Status |
|---|---|---|---|---|---|
| `clash` (`clash_1..3`) | Parry contact (`player_parry` result); named combo landing (lower pitch); `deflected` (quiet, higher) | Inharmonic metal ring, 0.7–0.9 s | Modal partials with beating pairs, click, noise burst, low thump | 6 (3) | exists (synthesised, unheard) |
| `parry_perfect` | Perfect-parry contact frame; also combo discovery and surge | Brighter ring with long shimmer, 1.2 s | Modal ring, high sines with tremolo, three tuned tones | 2 (1) | exists (synthesised, unheard) |
| `clash_<class>_<class>` | Blades meet: by attacker and defender class (sword, greatsword, axe, dual) | Greatsword pairs lower and longer; dual higher and doubled; axe with a wooden haft knock | Ring, click, body | 2 per pairing, 10 pairings | missing |
| `blade_scrape` | Blades held together after a parry, before the push | Sustained grind, 0.4–0.8 s | Friction noise, ring | 3 | missing |

#### Hits on bodies
| Event | Trigger and frame | Character | Layers | Var. | Status |
|---|---|---|---|---|---|
| `hit_armor` (`hit_armor_1..2`) | Player's cut lands on the foe (`boss_hit`), pitch rises with combo count; foe's strike lands on the player | Low thud with plate clank, 0.45 s | Pitch-dropping sine, modal plate, noise bursts | 6 (2) | exists (synthesised, unheard) |
| `hit_flesh` (`hit_flesh_1..2`) | Layered under `hit_armor` on critical hits and on hits to the player | Dull body thud, 0.35 s | Low sine drop, low-passed noise | 4 (2) | exists (synthesised, unheard) |
| `hit_<class>_plate/mail/hide/stone/scale` | Contact frame by weapon class and target material (plate: knights and guardians; mail and cloth: acolytes; hide: beasts; stone and ice: Glacier Hulk, colossi; scale: Veyrath, Skeldra, whelps) | Cut versus chop versus crush, on the target's material | Transient, material body, tail | 3 per pair | missing |
| `hit_crit` | Critical hit sweetener on the contact frame | Short sub drop and bright crack | Sub, crack | 2 | missing |
| `stagger` | Foe's posture breaks or is staggered (`boss_stagger`) | 0.7 s | Not inspected in detail | 3 (1) | exists (synthesised, unheard) |
| `finisher` | Finishing blow lands | 1.37 s | Not inspected in detail | 1 per weapon class (1) | exists (synthesised, unheard); per-class versions missing |
| `death` | Player dies (`player_dead`) | 2.5 s falling pad | String pad, low drop | 1 (1) | exists (synthesised, unheard) |
| `body_fall_plate`, `body_fall_large` | Body reaches the ground on a death animation | Plate collapse; heavier for giants | Impact, plate rattle, dust | 2 each | missing |

#### Shields and blocks
| Event | Trigger and frame | Character | Layers | Var. | Status |
|---|---|---|---|---|---|
| `block` (`block_1..2`) | Foe's strike meets the player's shield | Wood knock with a metal edge, 0.4 s | Low modal, sine drop, small metal modal, noise | — (2) | exists (synthesised, unheard); one sound for all shields |
| `guard_break` | Guard is broken; also reused quietly and pitched down in exploration | Splintering clicks, low drop, metal ring, 1.1 s | 16 clicks, noise, sub drop, modal | 2 (1) | exists (synthesised, unheard) |
| `shield_heater_*` (Splintered Heater) | Weapon visibly strikes the shield face | Cracked plank, loose, short | Wood crack, rattle | 3 | missing |
| `shield_kite_*` (Garrison Kite) | Same | Solid wood with iron rim | Wood body, rim ring | 3 | missing |
| `shield_bulwark_*` (Sentinel Bulwark) | Same | Thick scorched iron, low and long | Iron body, low ring | 3 | missing |
| `shield_reliquary_*` (Reliquary Door) | Same | Stone-cored door, hollow boom, faint bell tone | Stone knock, cavity, bronze | 3 | missing |
| `shield_glacier_*` (Glacier Ward) | Same | Ice: glassy crack with a high squeal | Ice crack, shimmer | 3 | missing |
| `shield_scale_*` (Broodscale Aegis) | Same | Horn-like, dry, slightly resonant | Keratin knock, hiss | 3 | missing |
| `block_heavy`, `block_timed`, `block_perfect` | Heavy block: strike from a Heavy or Giant foe. Timed and perfect: by window | Heavy adds sub and recoil scrape; perfect adds a short bright ping | Base shield sound plus sweetener | 2 each | missing |
| `shield_raise`, `shield_lower` | Shield arm reaches guard / leaves it | Strap creak and small rattle | Leather, buckle | 3 each | missing |

#### Movement in combat
| Event | Trigger and frame | Character | Layers | Var. | Status |
|---|---|---|---|---|---|
| `dodge` | Sidestep (`player_dodge`) and roll (`player_roll`, lower pitch); foe retreat | Rising noise sweep, 0.29 s | Swept noise, low noise | — (1) | exists (synthesised, unheard) |
| `roll_ground_<surface>` | Shoulder touches ground in the roll | Body and plate on the surface | Thump, plate, grit | 2 per surface | missing |
| `lunge_step`, `skid_stop` | Lead foot plants at the end of an advance; feet stop after pushback | Hard plant; short scrape | Foot, grit | 3 each | missing |
| `armor_move_*` | Any torso turn or step of the knight, at low level | Plate shift, strap creak | Plate, leather, mail | 6 | missing |
| `armor_set_<light/medium/heavy>` | Same, chosen by equipped chest piece | Light: leather and mail. Heavy: full plate | — | 4 each | missing |
| `foe_armor_move_*` | Foe steps, by class (Humanoid, Heavy, Giant, Guardian) | Heavier and slower with size | Plate, chain | 4 per class | missing |

#### Effort vocals (per knight; voice bible: separate short takes, never cut from dialogue)
| Event | Trigger and frame | Character | Var. | Status |
|---|---|---|---|---|
| `effort_m_light_*`, `effort_f_light_*` | Start of a light cut, about 1 in 3 swings | Short exhale | 6 each | missing |
| `effort_m_heavy_*`, `effort_f_heavy_*` | Start of a heavy cut or combo finisher | Longer, voiced | 4 each | missing |
| `effort_m_block_*`, `effort_f_block_*` | Shield impact frame | Clipped grunt | 4 each | missing |
| `effort_m_hurt_*`, `effort_f_hurt_*` | Hit lands on the player | Pain, not a scream | 5 each | missing |
| `effort_m_dodge_*`, `effort_f_dodge_*` | Push-off frame of a dodge or roll | Breath | 3 each | missing |
| `effort_m_death_*`, `effort_f_death_*` | Player's death, first frame of the fall | Last breath | 2 each | missing |
| `effort_m_exhausted`, `effort_f_exhausted` | Stamina empty (`exhausted`) | Ragged breath loop, 2 s | 1 each | missing |
| `breath_m_low_health`, `breath_f_low_health` | Health under 25%, looping | Strained breathing | 1 each | missing |

#### Telegraphs, elements, abilities
| Event | Trigger and frame | Character | Var. | Status |
|---|---|---|---|---|
| `telegraph_unblockable` | Start of an unblockable attack's wind-up | 0.5 s warning | 1 (1) | exists (synthesised, unheard) |
| `telegraph_heavy` | Start of a slam wind-up | Low rising tone | 2 | missing (a quiet `roar` is used for a boss's opening slam) |
| `ember_burst` | Surge activated; fire status applied | 0.9 s | 2 (1) | exists (synthesised, unheard) |
| `frost` | Frost status applied or ticking | 1.1 s | 2 (1) | exists (synthesised, unheard) |
| `burn_tick`, `frost_tick`, `bleed_tick` | Each status tick on the health bar | Short, quiet | 2 each | missing (`frost` and `ember_burst` reused at low level) |
| `surge_ready`, `relic_ready` | Meter fills | Rising chime | 1 each | missing (`loot` reused at two pitches) |
| `relic_use` | Relic activated | Warm swell | 1 | missing (`levelup` reused) |
| `posture_break` | "POSTURE BROKEN" toast frame | Crack and ring-out | 2 | missing (`stagger` used) |

#### Generic foe voices
| Event | Trigger and frame | Character | Var. | Status |
|---|---|---|---|---|
| `roar` (`roar_1..3`) | Boss intro (after speech), phase change, some slam telegraphs; pitch scaled by the foe's size | Sawtooth voice through moving formants with rasp, 1.3–1.8 s | 3 (3) | exists (synthesised, unheard); one set shared by every boss, including those the story treats as human |
| `foe_effort_<class>_*` | Foe's attack start, by class (Humanoid, Heavy, Giant, Twin-Bladed, Double-Weapon) | Helmeted grunts | 4 per class | missing |
| `foe_hurt_<class>_*`, `foe_death_<class>_*` | Hit and death | — | 3 and 2 per class | missing |
| `creature_<monstrosity/souleater>_*` | Idle, attack, hurt, death for Monstrosity and Soul-Eater classes | Monstrosity: animal. Soul-Eater: breathy, voices under it | 4 sets of 3 each | missing |

#### Boss-specific sounds — all missing
| Boss | Events | Trigger and frame | Character |
|---|---|---|---|
| Ashen Sentinel | `sentinel_step`, `sentinel_ember_vent`, `sentinel_armor_split`, `sentinel_blade_plant`, `sentinel_fall` | Each footfall; idle vents; phase 2 card ("armour splits"); phase 3 card ("plants the blade"); death | Enormous plate on stone; furnace breath; plate tearing; blade into flagstone with a bell-like ring |
| Hollow Executioner | `exec_cleaver_drag`, `exec_cleaver_chop`, `exec_root_answer`, `exec_stump_hit` | Approach and idle walk; chop contact; phase 2 card; missed chops into wood | Iron dragged through roots; wet wood chop; a groan from under the ground |
| Pale Huntsman | `hunt_whistle`, `hunt_step_leaf`, `hunt_axe_spin`, `hunt_breath` | Before he appears; steps; feints; idle | Low two-note whistle (original); careful leaf steps; a living man's breath |
| Crimson Widow | `widow_blade_draw`, `widow_dash`, `widow_veil_tear`, `widow_breath` | Intro; each dash step; phase 2 card; under 30% health | Two thin blades; cloth snap; audible human breathing, the only guardian with it |
| Cathedral Beast | `beast_bell_toll`, `beast_breath`, `beast_roar`, `beast_rise`, `beast_claw_bronze`, `beast_death` | Intro and phase 2 card (the bell tolls once); idle; attacks; standing up; claws on the bell | Cracked great bell; wet, large lungs; no human quality at all |
| Gravewarden | `warden_lantern_creak`, `warden_lantern_set`, `warden_water_rise`, `warden_wade`, `warden_lantern_out` | Idle; intro; phase 2 card (water to the knees); steps in phase 2; death | Small iron lantern handle; water filling a stone hall; slow wading |
| Veyrath | `wyrm_wing_pass`, `wyrm_land`, `wyrm_inhale`, `wyrm_fire`, `wyrm_roar`, `wyrm_takeoff`, `wyrm_wing_tear`, `wyrm_death` | Intro; landing; before breath; breath; phase 2 card (takes the air); phase 3 card (wing torn) | Leather sails; furnace draw before flame; flame as pressure, not crackle |
| Skeldra | `skeldra_chain`, `skeldra_roar`, `skeldra_chain_snap`, `skeldra_frost_breath`, `skeldra_death` | Idle and movement; intro; phase 2 card; breath | Huge frozen chain; a thinner, colder voice than Veyrath; a single link breaking |
| Frostbound King | `king_ice_crack`, `frost_shatter`, `king_frost_climb`, `king_crown_crack`, `king_step_ice` | Intro (ice breaks as he rises); phase 2 card; phase 3 card; steps | Ice sheets; slow creeping crystal; one sharp metallic crack |
| Devourer of Names | `devourer_gather`, `devourer_whisper_bed`, `devourer_open`, `devourer_name`, `devourer_fall` | Intro; loop under the whole fight; phase 2 card; the revive ("says your name"); second death | Many quiet voices, men, women, children, never words that can be made out; the revive is one clear voice |
| Forgotten Monarch | `monarch_rise`, `monarch_hall_kneel`, `monarch_crown_burn`, `monarch_blade`, `monarch_sit` | Phase 2 card (rises); same card (the hall answers); phase 3 card; his swings; death | Stone throne releasing weight; a hall of machinery powering up; a clean, expensive blade |

### 3.2 Ambience bus

#### Region beds
| Event | Used where | Character (as computed by the script, for existing files) | Var. | Status |
|---|---|---|---|---|
| `wind` | Title, courtyard, blackwood, roost, citadel, throne (per `amb` in the data) | 20 s stereo loop: low rumble, gusting mid and high bands, narrow whistle band | 1 | exists (synthesised, unheard) |
| `fire` | Sanctuary, cathedral | 20 s stereo loop | 1 | exists (synthesised, unheard) |
| `crypt` | Crypt, deep | 20 s stereo loop | 1 | exists (synthesised, unheard) |
| `rain` | Nothing | 20 s stereo loop | 1 | exists (synthesised, unheard), unused |
| `amb_sanctuary` | Sanctuary | Close room, one candle-machine hum, forge at a distance | 1 bed, 90 s | missing (`fire` used) |
| `amb_courtyard` | Courtyard | Open morning wind, banner cloth, far crows, a faint hum under stone | 1 bed, 90 s | missing (`wind` used) |
| `amb_blackwood` | Blackwood | Close trees, creaking trunks, no birds, lanterns ticking | 1 bed | missing (`wind` used) |
| `amb_cathedral` | Cathedral | Slow fire, falling ash, a choir recording far off, large stone space | 1 bed | missing (`fire` used) |
| `amb_crypt` / `amb_crypt_deep` | Crypt before and after the sluice | Dripping and lapping water; after draining: dry stone, low electrical hum | 2 beds | missing (`crypt` used) |
| `amb_roost` | Roost | High thin wind, hot updrafts, distant rockfall | 1 bed | missing (`wind` used) |
| `amb_citadel` | Citadel | Dead-cold stillness, ice ticking, wind held outside walls | 1 bed | missing (`wind` used) |
| `amb_deep` | Deep | Near silence, a pressure tone, whispering at the edge of hearing | 1 bed | missing (`crypt` used) |
| `amb_throne` | Throne | Large hall, steady machine hum, faint relay clicks | 1 bed | missing (`wind` used) |

Twenty-second loops repeat three times a minute; a looping bed that short is likely to be noticed. PROPOSED minimum 90 s per bed.

#### Ambient one-shots and footsteps
| Event | Trigger and frame | Character | Var. | Status |
|---|---|---|---|---|
| `footstep` (`footstep_1..2`) | Rig foot plant (`fighter_rig.gd`, level by bulk, pitch by scale); advance in combat; five timed steps during walks; stage entry | Low thump with a small metallic click, 0.25 s | — (2) | exists (synthesised, unheard); one surface for everything |
| `foot_stone_*` | Heel strike frame on flagstone (courtyard, cathedral, throne) | Hard, short | 6 | missing |
| `foot_rubble_*` | Courtyard breach, fallen walls | Stone with loose grit | 6 | missing |
| `foot_leaf_*` | Blackwood | Leaf litter and root | 6 | missing |
| `foot_ash_*` | Cathedral steps and nave | Soft, muffled, slight crunch | 6 | missing |
| `foot_water_*` | Crypt, flooded | Splash to ankle; wade in the Gravewarden's second phase | 6 | missing |
| `foot_glass_*` | Roost glazed road | Hard with a glassy tick | 6 | missing |
| `foot_snow_*`, `foot_ice_*` | Citadel | Compressing snow; hard ice with a slip | 6 each | missing |
| `foot_deep_*` | Deep | Dull, close, almost no tail | 4 | missing |
| `foot_marble_*` | Throne room | Hard with a long hall tail | 6 | missing |
| `amb_oneshot_<region>_*` | Random, every 8–20 s | Courtyard: banner snap, stone fall. Blackwood: branch crack. Cathedral: beam settling. Crypt: drip, distant lid. Roost: far wingbeat. Citadel: ice crack. Deep: a single word, unintelligible. Throne: relay click | 4 per region | missing |
| `player_heartbeat` | Health under 25% | Slow, low | 1 loop | missing |

### 3.3 Interface bus
| Event | Trigger and frame | Character | Var. | Status |
|---|---|---|---|---|
| `ui_tap` | Any button press (`ui.gd`); title options | 0.12 s | 1 (1) | exists (synthesised, unheard) |
| `ui_confirm` | Start game, purchase, hotspot chosen | 0.35 s | 1 (1) | exists (synthesised, unheard); plays on Combat today |
| `ui_back` | Cinematic duel: early or wasted input | 0.28 s | 1 (1) | exists (synthesised, unheard) |
| `loot` | Treasure opened, pouch collected, item bought; reused for surge/relic ready | 0.6 s | 2 (1) | exists (synthesised, unheard) |
| `levelup` | Level gained; shrine rest; relic use | 1.45 s | 1 (1) | exists (synthesised, unheard) |
| `bell` | Boss intro; phase change; boss death; return to the Sanctuary after the final region is cleared | Large bell, 4.0 s | 1 (1) | exists (synthesised, unheard) |
| `victory` | 1.6 s after a boss dies | 3.0 s pad | 1 (1) | exists (synthesised, unheard); plays on Combat today |
| `ui_equip_weapon`, `ui_equip_shield`, `ui_equip_armor` | Item equipped in the Sanctuary | A short handling sound of the item's material | 2 each | missing |
| `ui_upgrade` | Orren's upgrade completes | Hammer on anvil, three strikes | 1 | missing (`clash` reused) |
| `ui_error` | Cannot afford, locked | Dull knock | 1 | missing |
| `ui_tab`, `ui_scroll_tick`, `ui_slider` | Tab change; list detent; settings slider | Very short, quiet | 1 each | missing |
| `ui_combo_discovered` | "DISCOVERED" toast frame | Three-note rising figure from the main motif | 1 | missing (`parry_perfect` reused) |
| `ui_lore_found`, `ui_memory_found` | Lore discovery or memory collected | Paper or stone for lore; a soft machine chirp for memory | 1 each | missing |
| `ui_lever`, `ui_shortcut_open` | Lever stage chosen | Mechanism per region: winch chain, rope bridge, sacristy bar, sluice wheel, counterweight chain, ice lift, marked stair, king's door | 8 | missing (`guard_break` reused, pitched down) |
| `ui_shrine_rest` | Shrine stage chosen | Soft swell with a faint hum, hinting the shrine is a machine | 1 | missing (`levelup` reused) |
| `ui_pause`, `ui_resume` | Pause opened and closed | Low-pass down and up on the rest of the mix would serve instead | 1 each | missing |
| Haptics | Exist in code (`Game.haptic`) alongside several combat events | Not audio; listed so sound and haptic land on the same frame | — | exists (not tested on a device) |

### 3.4 Dialogue bus
| Event | Trigger | Var. | Status |
|---|---|---|---|
| 83 scripted lines, 97 files | Scenes in `data/dialogue.json` (see `AUDIO_ASSET_MANIFEST.md`) | — | exists (generated speech, provisional, unheard) |
| Stage remarks for seven regions (49), new boss scenes, endings | `CAMPAIGN_SCRIPT.md` proposals | — | missing |
| Voice processing per role (voice bible: closed helm, machine echo, band-limit with tremolo, layered echo) | Should be a bus effect or baked per file | — | missing; no processing found in code or scripts |
| Devourer layering (several voices at once) | `devourer_intro` | — | missing; three single-voice files exist |

### 3.5 Cinematics bus
Only silent video players use this bus today. PROPOSED use: story stingers and footage-only sound, so they can be balanced apart from combat.

| Event | Trigger and frame | Character | Var. | Status |
|---|---|---|---|---|
| `cine_crown_wake` | Opening shot O6, the indicator lighting | One pure tone with a slow beat | 1 | missing |
| `cine_chamber_open` | Opening shot O7 | Seal release, lid servo, old and tired | 1 | missing |
| `cine_memory_in`, `cine_memory_out` | First and last frame of a memory insert | Tape-like rise and fall, band-limited | 1 each | missing |
| `cine_archivist_bed` | Under Archivist lines | Faint carrier hum with tremolo | 1 loop | missing |
| `cine_lab_reveal` | Cathedral Beast death, the floor giving way and the corridor | Stone fall, then clean ventilation and lights striking on in sequence | 1 | missing |
| `cine_crown_hum`, `cine_crown_disconnect`, `cine_crown_partition` | Ending lead-in and endings 1 and 3 | Hum: steady chord of machine tones. Disconnect: the chord losing notes one at a time. Partition: the chord splitting into several independent ones | 1 each | missing |
| `cine_external_search`, `cine_external_answer` | Post-credits P2 and P3 | Search: slow repeating ping. Answer: one tone a fifth above, far away | 1 each | missing |
| Per-clip foley for filmed footage | Road walks and the Sentinel clips | Footsteps and armour cut to the picture, stored as cue times per clip | per clip | missing (road walks use five timed `footstep` plays) |

### 3.6 Music bus
See `SOUNDTRACK_PLAN.md`. Sound-design items that live on this bus:

| Event | Trigger | Status |
|---|---|---|
| Phase layer | Boss phase change | exists in code (`set_layer("combat_b")`, only for foes whose `music` is `combat_a`); unheard |
| Low-health layer, tension layer, victory and defeat stingers | See soundtrack plan | missing |

---

## 4. Counts
| | Existing files | Events specified here as missing (families) |
|---|---|---|
| Effects (`assets/audio/sfx`) | 34 files, 24 event names | about 400 individual Combat-bus files and about 25 Interface files at the variation counts given (itemised in `AUDIO_ASSET_MANIFEST.md`) |
| Ambience (`assets/audio/amb`) | 4 loops | 10 beds, 32 one-shots, 58 footstep files |
| Speech (`assets/audio/vo`) | 97 files | see campaign script proposals and effort vocals (26 files per knight) |

The variation counts are targets for a finished game, not a minimum for the next build. PROPOSED first pass, in the order the owner set (one exceptional encounter first): per-class swings and impacts for sword and greatsword, the Garrison Kite and Sentinel Bulwark shield sets, stone and rubble footsteps, armour movement, both knights' effort sets, the five Sentinel sounds, `amb_courtyard`.

## 5. Gaps and disagreements found while writing
- The header comment of `sfx.gd` says all audio is synthesised by `tools/gen_audio.py`. Four music files come from `tools/music.py` (generated) and all speech is generated.
- The backlog marks the six buses done; the Cinematics bus carries nothing audible.
- `rain` ambience is produced and never used.
- The same `roar` set is played for every boss, including the Widow, the Gravewarden and the Monarch, whom the story treats as people who speak.
- `set_layer("combat_b")` over `boss_ashen_sentinel` combines two tracks not written to fit.
- The master requirements ask for weapon, shield, footstep, armour and effort sounds "synchronised to visible events". None of the armour or effort sounds exist, shields and footsteps have one sound each, and sync has not been verified.
