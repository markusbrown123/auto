# Hollow Reign: audio asset manifest

Every audio file in `assets/audio/` as of 2026-11-26, and the list of what is missing. Durations were read with `ffprobe`. Call sites were found with `grep` over `src/`. Companion to `SOUND_DESIGN_BIBLE.md` and `SOUNDTRACK_PLAN.md`.

## Honesty note
Nobody has listened to any of these files. "Exists" means the file is on disk at the stated length; it is not a statement about how it sounds. All speech is provisional and unauditioned. Line numbers in the effects table were taken on 2026-11-26 while `src/combat/duel.gd` was being edited by other work, so they will drift; the event name is the stable reference.

## Summary
| Folder | Files | Total length | Kind | Source |
|---|---|---|---|---|
| `assets/audio/sfx/` | 34 `.wav` | 31.0 s | Effects | synthesised by tools/gen_audio.py |
| `assets/audio/amb/` | 4 `.ogg` | 80.0 s | Ambience loops | synthesised by tools/gen_audio.py |
| `assets/audio/music/` | 9 `.ogg` | 544 s | Music | 5 synthesised by tools/gen_audio.py; 4 generated music (tools/music.py) |
| `assets/audio/vo/` | 97 `.ogg` | 342 s | Speech | generated speech (provisional), tools/voices.py |
| Total | 144 | about 16.6 minutes | | |

Each file also has a Godot `.import` sidecar, not listed. The folder `assets/audio/amb/` was not in the brief's list of folders but exists and is used, so it is included.

Sources in detail
- **synthesised by tools/gen_audio.py**: computed from noise, sine and modal models with numpy and scipy; deterministic (each sound seeds its generator from its own name); no samples.
- **generated music**: `tools/music.py`, a text-to-music model reached through the Higgsfield CLI; instrumental; the first 5 s cross-faded onto the tail for looping; `loudnorm` I=−16, TP=−1.5. Logged in `SPENDING_LOG.md` as 4 cues, about 50 credits.
- **generated speech (provisional)**: `tools/voices.py`, a text-to-speech model reached through the Higgsfield CLI, one preset voice per speaker. Logged as 97 lines, about 50 credits. The voice bible states the casting was made from a list of names without listening.

## Files

### Effects — `assets/audio/sfx/` (34 files)
All: mono, 44.1 kHz, 16-bit WAV, peak-normalised to −3 dBFS by the script. Source for every row: **synthesised by tools/gen_audio.py**. Status for every row: unheard.

| Path | Duration | Bus at play time | Event name in code | Used by (found with grep) |
|---|---|---|---|---|
| `assets/audio/sfx/bell.wav` | 4.00 s | Interface | `bell` | `src/main.gd` lines 199; `src/combat/duel.gd` lines 231, 569, 671, 788 |
| `assets/audio/sfx/block_1.wav` | 0.40 s | Combat | `block` (random 1 of 2) | `src/combat/duel.gd` lines 735; `src/cine/cine_duel.gd` lines 165 |
| `assets/audio/sfx/block_2.wav` | 0.40 s | Combat | `block` (random 1 of 2) | `src/combat/duel.gd` lines 735; `src/cine/cine_duel.gd` lines 165 |
| `assets/audio/sfx/clash_1.wav` | 0.80 s | Combat | `clash` (random 1 of 3) | `src/combat/duel.gd` lines 606, 631, 636, 719; `src/ui/sanctuary.gd` lines 357; `src/cine/cine_duel.gd` lines 154 |
| `assets/audio/sfx/clash_2.wav` | 0.70 s | Combat | `clash` (random 1 of 3) | `src/combat/duel.gd` lines 606, 631, 636, 719; `src/ui/sanctuary.gd` lines 357; `src/cine/cine_duel.gd` lines 154 |
| `assets/audio/sfx/clash_3.wav` | 0.90 s | Combat | `clash` (random 1 of 3) | `src/combat/duel.gd` lines 606, 631, 636, 719; `src/ui/sanctuary.gd` lines 357; `src/cine/cine_duel.gd` lines 154 |
| `assets/audio/sfx/death.wav` | 2.50 s | Combat | `death` | `src/combat/duel.gd` lines 799; `src/cine/cine_duel.gd` lines 201 |
| `assets/audio/sfx/dodge.wav` | 0.29 s | Combat | `dodge` | `src/combat/duel.gd` lines 561, 565, 662; `src/cine/cine_duel.gd` lines 161 |
| `assets/audio/sfx/ember_burst.wav` | 0.90 s | Combat | `ember_burst` | `src/combat/duel.gd` lines 587, 693 |
| `assets/audio/sfx/finisher.wav` | 1.37 s | Combat | `finisher` | `src/combat/duel.gd` lines 775 |
| `assets/audio/sfx/footstep_1.wav` | 0.25 s | Ambience | `footstep` (random 1 of 2) | `src/chars/fighter_rig.gd` lines 688; `src/combat/duel.gd` lines 575; `src/ui/explore.gd` lines 34, 151; `src/cine/cine_road.gd` lines 91 |
| `assets/audio/sfx/footstep_2.wav` | 0.25 s | Ambience | `footstep` (random 1 of 2) | `src/chars/fighter_rig.gd` lines 688; `src/combat/duel.gd` lines 575; `src/ui/explore.gd` lines 34, 151; `src/cine/cine_road.gd` lines 91 |
| `assets/audio/sfx/frost.wav` | 1.10 s | Combat | `frost` | `src/combat/duel.gd` lines 687, 691, 761 |
| `assets/audio/sfx/guard_break.wav` | 1.10 s | Combat | `guard_break` | `src/combat/duel.gd` lines 742; `src/ui/explore.gd` lines 232; `src/cine/cine_road.gd` lines 245 |
| `assets/audio/sfx/hit_armor_1.wav` | 0.45 s | Combat | `hit_armor` (random 1 of 2) | `src/combat/duel.gd` lines 610, 753; `src/cine/cine_duel.gd` lines 168, 177 |
| `assets/audio/sfx/hit_armor_2.wav` | 0.45 s | Combat | `hit_armor` (random 1 of 2) | `src/combat/duel.gd` lines 610, 753; `src/cine/cine_duel.gd` lines 168, 177 |
| `assets/audio/sfx/hit_flesh_1.wav` | 0.35 s | Combat | `hit_flesh` (random 1 of 2) | `src/combat/duel.gd` lines 612, 754; `src/cine/cine_duel.gd` lines 169, 178 |
| `assets/audio/sfx/hit_flesh_2.wav` | 0.35 s | Combat | `hit_flesh` (random 1 of 2) | `src/combat/duel.gd` lines 612, 754; `src/cine/cine_duel.gd` lines 169, 178 |
| `assets/audio/sfx/levelup.wav` | 1.45 s | Interface | `levelup` | `src/combat/duel.gd` lines 597; `src/ui/overlays.gd` lines 49; `src/ui/explore.gd` lines 226; `src/cine/cine_road.gd` lines 241 |
| `assets/audio/sfx/loot.wav` | 0.60 s | Interface | `loot` | `src/combat/duel.gd` lines 65, 581, 584; `src/ui/sanctuary.gd` lines 374; `src/ui/explore.gd` lines 117, 214; `src/cine/cine_road.gd` lines 230 |
| `assets/audio/sfx/parry_perfect.wav` | 1.20 s | Combat | `parry_perfect` | `src/combat/duel.gd` lines 588, 628, 724; `src/cine/cine_duel.gd` lines 156 |
| `assets/audio/sfx/roar_1.wav` | 1.29 s | Combat | `roar` (random 1 of 3) | `src/combat/duel.gd` lines 270, 278, 544, 670; `src/cine/cine_duel.gd` lines 183 |
| `assets/audio/sfx/roar_2.wav` | 1.59 s | Combat | `roar` (random 1 of 3) | `src/combat/duel.gd` lines 270, 278, 544, 670; `src/cine/cine_duel.gd` lines 183 |
| `assets/audio/sfx/roar_3.wav` | 1.79 s | Combat | `roar` (random 1 of 3) | `src/combat/duel.gd` lines 270, 278, 544, 670; `src/cine/cine_duel.gd` lines 183 |
| `assets/audio/sfx/stagger.wav` | 0.70 s | Combat | `stagger` | `src/combat/duel.gd` lines 645; `src/cine/cine_duel.gd` lines 175 |
| `assets/audio/sfx/swing_1.wav` | 0.31 s | Combat | `swing` (random 1 of 3) | `src/combat/duel.gd` lines 346, 554, 557; `src/cine/cine_duel.gd` lines 139, 141 |
| `assets/audio/sfx/swing_2.wav` | 0.34 s | Combat | `swing` (random 1 of 3) | `src/combat/duel.gd` lines 346, 554, 557; `src/cine/cine_duel.gd` lines 139, 141 |
| `assets/audio/sfx/swing_3.wav` | 0.29 s | Combat | `swing` (random 1 of 3) | `src/combat/duel.gd` lines 346, 554, 557; `src/cine/cine_duel.gd` lines 139, 141 |
| `assets/audio/sfx/swing_heavy.wav` | 0.62 s | Combat | `swing_heavy` | `src/combat/duel.gd` lines 346; `src/cine/cine_duel.gd` lines 115 |
| `assets/audio/sfx/telegraph_unblockable.wav` | 0.50 s | Combat | `telegraph_unblockable` | `src/combat/duel.gd` lines 541 |
| `assets/audio/sfx/ui_back.wav` | 0.28 s | Interface | `ui_back` | `src/cine/cine_duel.gd` lines 132, 137 |
| `assets/audio/sfx/ui_confirm.wav` | 0.35 s | Combat | `ui_confirm` | `src/ui/sanctuary.gd` lines 267; `src/ui/title_screen.gd` lines 117; `src/cine/cine_road.gd` lines 218 |
| `assets/audio/sfx/ui_tap.wav` | 0.12 s | Interface | `ui_tap` | `src/ui/ui.gd` lines 75; `src/ui/title_screen.gd` lines 109 |
| `assets/audio/sfx/victory.wav` | 3.00 s | Combat | `victory` | `src/combat/duel.gd` lines 789; `src/cine/cine_duel.gd` lines 193 |

Total effects duration: 31.0 s.

### Music — `assets/audio/music/` (9 files)
All Ogg Vorbis, looped by the engine. Status for every row: unheard.

| Path | Duration | Channels / rate | Source | Used by |
|---|---|---|---|---|
| `assets/audio/music/boss_ashen_sentinel.ogg` | 90.1 s | 2 ch / 44100 Hz | generated music (tools/music.py) | `src/combat/duel.gd`, `src/cine/cine_duel.gd` (`music_for("boss_" + foe id, foe.music)`) |
| `assets/audio/music/combat_a.ogg` | 33.6 s | 2 ch / 44100 Hz | synthesised by tools/gen_audio.py | `music` field of 44 foes in `data/bosses.json` (40 ordinary foes, Sentinel, Executioner, Widow, Huntsman); played by `duel.gd` when no `boss_<id>` file exists |
| `assets/audio/music/combat_b.ogg` | 33.6 s | 2 ch / 44100 Hz | synthesised by tools/gen_audio.py | `music` field of 5 bosses (Beast, Gravewarden, Frostbound King, Veyrath, Skeldra); phase layer `set_layer("combat_b")` in `duel.gd` and `cine_duel.gd` |
| `assets/audio/music/explore_courtyard.ogg` | 85.1 s | 2 ch / 44100 Hz | generated music (tools/music.py) | `src/ui/explore.gd`, `src/cine/cine_road.gd` (`music_for("explore_" + region.id, "menu")`) |
| `assets/audio/music/final.ogg` | 40.0 s | 2 ch / 44100 Hz | synthesised by tools/gen_audio.py | `music` field of the Forgotten Monarch and the Devourer |
| `assets/audio/music/hub.ogg` | 75.1 s | 2 ch / 44100 Hz | generated music (tools/music.py) | `src/ui/sanctuary.gd`, `src/main.gd` (`music_for("hub", "sanctuary")`) |
| `assets/audio/music/menu.ogg` | 48.0 s | 2 ch / 44100 Hz | synthesised by tools/gen_audio.py | Fallback in the `theme` and `explore_*` calls above; in effect the exploration music of seven regions |
| `assets/audio/music/sanctuary.ogg` | 48.0 s | 2 ch / 44100 Hz | synthesised by tools/gen_audio.py | Fallback for `hub`; not reached while `hub.ogg` exists |
| `assets/audio/music/theme.ogg` | 90.1 s | 2 ch / 44100 Hz | generated music (tools/music.py) | `src/ui/title_screen.gd`, `src/main.gd` (`music_for("theme", "menu")`) |

Total music duration: 544 s.

### Ambience — `assets/audio/amb/` (4 files)
Source for every row: **synthesised by tools/gen_audio.py**, mastered by the script to its own estimate of −18 LUFS. Played on the Ambience bus by `Sfx.ambience()`. Status: unheard.

| Path | Duration | Channels / rate | Used by |
|---|---|---|---|
| `assets/audio/amb/crypt.ogg` | 20.0 s | 2 ch / 44100 Hz | `amb` of crypt and deep |
| `assets/audio/amb/fire.ogg` | 20.0 s | 2 ch / 44100 Hz | `amb` of cathedral; Sanctuary (`sanctuary.gd`) |
| `assets/audio/amb/rain.ogg` | 20.0 s | 2 ch / 44100 Hz | no use found |
| `assets/audio/amb/wind.ogg` | 20.0 s | 2 ch / 44100 Hz | `amb` of courtyard, blackwood, roost, citadel, throne in `data/regions.json` (via `explore.gd`, `cine_road.gd`, `duel.gd`); title screen (`title_screen.gd`); cinematic duel (`cine_duel.gd`) |

### Speech — `assets/audio/vo/` (97 files)
Source for every row: **generated speech (provisional)**, made through `tools/voices.py` with the preset voice named in `data/dialogue.json` → `voices`. Played on the Dialogue bus by `Story.play()`; the path is built in `src/core/story.gd` (`audio_path`). Player lines have `_m` and `_f` files. Status for every row: unheard, unauditioned.

| Path | Duration | Speaker (voice preset) | Scene id | Triggered from |
|---|---|---|---|---|
| `assets/audio/vo/awakening_01.ogg` | 1.31 s | lyra (Vesper) | `awakening` | `src/main.gd` |
| `assets/audio/vo/awakening_02_f.ogg` | 1.15 s | player (Imogen) | `awakening` | `src/main.gd` |
| `assets/audio/vo/awakening_02_m.ogg` | 1.07 s | player (Callum) | `awakening` | `src/main.gd` |
| `assets/audio/vo/awakening_03.ogg` | 3.41 s | lyra (Vesper) | `awakening` | `src/main.gd` |
| `assets/audio/vo/awakening_04_f.ogg` | 1.41 s | player (Imogen) | `awakening` | `src/main.gd` |
| `assets/audio/vo/awakening_04_m.ogg` | 1.49 s | player (Callum) | `awakening` | `src/main.gd` |
| `assets/audio/vo/awakening_05.ogg` | 2.78 s | lyra (Vesper) | `awakening` | `src/main.gd` |
| `assets/audio/vo/awakening_06_f.ogg` | 2.59 s | player (Imogen) | `awakening` | `src/main.gd` |
| `assets/audio/vo/awakening_06_m.ogg` | 2.51 s | player (Callum) | `awakening` | `src/main.gd` |
| `assets/audio/vo/awakening_07.ogg` | 1.89 s | lyra (Vesper) | `awakening` | `src/main.gd` |
| `assets/audio/vo/beast_death_01.ogg` | 1.81 s | lyra (Vesper) | `beast_death` | `src/combat/duel.gd` (`Story.play("beast_death")` via `VOICE_KEYS`) |
| `assets/audio/vo/beast_death_02_f.ogg` | 2.12 s | player (Imogen) | `beast_death` | `src/combat/duel.gd` (`Story.play("beast_death")` via `VOICE_KEYS`) |
| `assets/audio/vo/beast_death_02_m.ogg` | 1.88 s | player (Callum) | `beast_death` | `src/combat/duel.gd` (`Story.play("beast_death")` via `VOICE_KEYS`) |
| `assets/audio/vo/beast_death_03.ogg` | 1.50 s | lyra (Vesper) | `beast_death` | `src/combat/duel.gd` (`Story.play("beast_death")` via `VOICE_KEYS`) |
| `assets/audio/vo/beast_intro_01.ogg` | 5.40 s | lyra (Vesper) | `beast_intro` | `src/combat/duel.gd` (`Story.play("beast_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/courtyard_0_01.ogg` | 5.70 s | lyra (Vesper) | `courtyard_0` | `src/ui/explore.gd`, `src/cine/cine_road.gd` (scene `<region>_<stage>`) |
| `assets/audio/vo/courtyard_1_01.ogg` | 5.90 s | lyra (Vesper) | `courtyard_1` | `src/ui/explore.gd`, `src/cine/cine_road.gd` (scene `<region>_<stage>`) |
| `assets/audio/vo/courtyard_2_01.ogg` | 5.90 s | lyra (Vesper) | `courtyard_2` | `src/ui/explore.gd`, `src/cine/cine_road.gd` (scene `<region>_<stage>`) |
| `assets/audio/vo/courtyard_3_01.ogg` | 5.90 s | lyra (Vesper) | `courtyard_3` | `src/ui/explore.gd`, `src/cine/cine_road.gd` (scene `<region>_<stage>`) |
| `assets/audio/vo/courtyard_4_01.ogg` | 5.80 s | lyra (Vesper) | `courtyard_4` | `src/ui/explore.gd`, `src/cine/cine_road.gd` (scene `<region>_<stage>`) |
| `assets/audio/vo/courtyard_5_01.ogg` | 5.30 s | lyra (Vesper) | `courtyard_5` | `src/ui/explore.gd`, `src/cine/cine_road.gd` (scene `<region>_<stage>`) |
| `assets/audio/vo/courtyard_6_01.ogg` | 5.50 s | lyra (Vesper) | `courtyard_6` | `src/ui/explore.gd`, `src/cine/cine_road.gd` (scene `<region>_<stage>`) |
| `assets/audio/vo/devourer_intro_01.ogg` | 1.69 s | devourer (Luna) | `devourer_intro` | `src/combat/duel.gd` (`Story.play("devourer_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/devourer_intro_02.ogg` | 2.08 s | devourer (Luna) | `devourer_intro` | `src/combat/duel.gd` (`Story.play("devourer_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/devourer_intro_03.ogg` | 2.79 s | devourer (Luna) | `devourer_intro` | `src/combat/duel.gd` (`Story.play("devourer_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/executioner_death_01.ogg` | 6.60 s | lyra (Vesper) | `executioner_death` | `src/combat/duel.gd` (`Story.play("executioner_death")` via `VOICE_KEYS`) |
| `assets/audio/vo/executioner_intro_01.ogg` | 3.04 s | executioner (Vlad) | `executioner_intro` | `src/combat/duel.gd` (`Story.play("executioner_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/executioner_intro_02_f.ogg` | 2.59 s | player (Imogen) | `executioner_intro` | `src/combat/duel.gd` (`Story.play("executioner_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/executioner_intro_02_m.ogg` | 2.59 s | player (Callum) | `executioner_intro` | `src/combat/duel.gd` (`Story.play("executioner_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/executioner_intro_03.ogg` | 3.04 s | executioner (Vlad) | `executioner_intro` | `src/combat/duel.gd` (`Story.play("executioner_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/first_road_01.ogg` | 8.30 s | lyra (Vesper) | `first_road` | `src/main.gd` |
| `assets/audio/vo/first_road_02.ogg` | 6.60 s | lyra (Vesper) | `first_road` | `src/main.gd` |
| `assets/audio/vo/frostking_death_01.ogg` | 5.10 s | frostking (Alistair) | `frostking_death` | `src/combat/duel.gd` (`Story.play("frostking_death")` via `VOICE_KEYS`) |
| `assets/audio/vo/frostking_intro_01.ogg` | 6.00 s | frostking (Alistair) | `frostking_intro` | `src/combat/duel.gd` (`Story.play("frostking_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/frostking_intro_02_f.ogg` | 2.19 s | player (Imogen) | `frostking_intro` | `src/combat/duel.gd` (`Story.play("frostking_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/frostking_intro_02_m.ogg` | 2.19 s | player (Callum) | `frostking_intro` | `src/combat/duel.gd` (`Story.play("frostking_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/frostking_intro_03.ogg` | 2.62 s | frostking (Alistair) | `frostking_intro` | `src/combat/duel.gd` (`Story.play("frostking_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/frostking_retry_01.ogg` | 3.66 s | frostking (Alistair) | `frostking_retry` | `src/combat/duel.gd` (`Story.play("frostking_retry")` via `VOICE_KEYS`) |
| `assets/audio/vo/gravewarden_death_01.ogg` | 6.20 s | archivist (Onyx) | `gravewarden_death` | `src/combat/duel.gd` (`Story.play("gravewarden_death")` via `VOICE_KEYS`) |
| `assets/audio/vo/gravewarden_death_02.ogg` | 5.70 s | archivist (Onyx) | `gravewarden_death` | `src/combat/duel.gd` (`Story.play("gravewarden_death")` via `VOICE_KEYS`) |
| `assets/audio/vo/gravewarden_intro_01.ogg` | 2.14 s | gravewarden (Bram) | `gravewarden_intro` | `src/combat/duel.gd` (`Story.play("gravewarden_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/gravewarden_intro_02_f.ogg` | 1.15 s | player (Imogen) | `gravewarden_intro` | `src/combat/duel.gd` (`Story.play("gravewarden_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/gravewarden_intro_02_m.ogg` | 0.99 s | player (Callum) | `gravewarden_intro` | `src/combat/duel.gd` (`Story.play("gravewarden_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/gravewarden_intro_03.ogg` | 3.11 s | gravewarden (Bram) | `gravewarden_intro` | `src/combat/duel.gd` (`Story.play("gravewarden_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/huntsman_intro_01.ogg` | 5.60 s | huntsman (Brooks) | `huntsman_intro` | `src/combat/duel.gd` (`Story.play("huntsman_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/huntsman_intro_02_f.ogg` | 1.72 s | player (Imogen) | `huntsman_intro` | `src/combat/duel.gd` (`Story.play("huntsman_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/huntsman_intro_02_m.ogg` | 1.80 s | player (Callum) | `huntsman_intro` | `src/combat/duel.gd` (`Story.play("huntsman_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/huntsman_intro_03.ogg` | 1.60 s | huntsman (Brooks) | `huntsman_intro` | `src/combat/duel.gd` (`Story.play("huntsman_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/monarch_death_01.ogg` | 6.20 s | monarch (Caspian) | `monarch_death` | `src/combat/duel.gd` (`Story.play("monarch_death")` via `VOICE_KEYS`) |
| `assets/audio/vo/monarch_death_02.ogg` | 2.12 s | lyra (Vesper) | `monarch_death` | `src/combat/duel.gd` (`Story.play("monarch_death")` via `VOICE_KEYS`) |
| `assets/audio/vo/monarch_death_03_f.ogg` | 1.49 s | player (Imogen) | `monarch_death` | `src/combat/duel.gd` (`Story.play("monarch_death")` via `VOICE_KEYS`) |
| `assets/audio/vo/monarch_death_03_m.ogg` | 1.41 s | player (Callum) | `monarch_death` | `src/combat/duel.gd` (`Story.play("monarch_death")` via `VOICE_KEYS`) |
| `assets/audio/vo/monarch_intro_01.ogg` | 2.88 s | monarch (Caspian) | `monarch_intro` | `src/combat/duel.gd` (`Story.play("monarch_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/monarch_intro_02_f.ogg` | 3.16 s | player (Imogen) | `monarch_intro` | `src/combat/duel.gd` (`Story.play("monarch_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/monarch_intro_02_m.ogg` | 3.32 s | player (Callum) | `monarch_intro` | `src/combat/duel.gd` (`Story.play("monarch_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/monarch_intro_03.ogg` | 4.90 s | monarch (Caspian) | `monarch_intro` | `src/combat/duel.gd` (`Story.play("monarch_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/monarch_intro_04_f.ogg` | 2.51 s | player (Imogen) | `monarch_intro` | `src/combat/duel.gd` (`Story.play("monarch_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/monarch_intro_04_m.ogg` | 2.43 s | player (Callum) | `monarch_intro` | `src/combat/duel.gd` (`Story.play("monarch_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/monarch_intro_05.ogg` | 4.30 s | monarch (Caspian) | `monarch_intro` | `src/combat/duel.gd` (`Story.play("monarch_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/monarch_retry_01.ogg` | 3.43 s | monarch (Caspian) | `monarch_retry` | `src/combat/duel.gd` (`Story.play("monarch_retry")` via `VOICE_KEYS`) |
| `assets/audio/vo/opening_01.ogg` | 4.10 s | narrator (Helena) | `opening` | `src/main.gd` |
| `assets/audio/vo/opening_02.ogg` | 2.44 s | narrator (Helena) | `opening` | `src/main.gd` |
| `assets/audio/vo/opening_03.ogg` | 8.30 s | narrator (Helena) | `opening` | `src/main.gd` |
| `assets/audio/vo/opening_04.ogg` | 4.30 s | narrator (Helena) | `opening` | `src/main.gd` |
| `assets/audio/vo/opening_05.ogg` | 8.20 s | narrator (Helena) | `opening` | `src/main.gd` |
| `assets/audio/vo/opening_06.ogg` | 1.58 s | narrator (Helena) | `opening` | `src/main.gd` |
| `assets/audio/vo/orren_idle_01.ogg` | 6.20 s | orren (Gideon) | `orren_idle` | `src/ui/sanctuary.gd` |
| `assets/audio/vo/orren_intro_01.ogg` | 3.16 s | orren (Gideon) | `orren_intro` | `src/ui/sanctuary.gd` |
| `assets/audio/vo/orren_intro_02.ogg` | 4.60 s | orren (Gideon) | `orren_intro` | `src/ui/sanctuary.gd` |
| `assets/audio/vo/orren_intro_03.ogg` | 5.80 s | orren (Gideon) | `orren_intro` | `src/ui/sanctuary.gd` |
| `assets/audio/vo/rebirth_0_01.ogg` | 2.44 s | lyra (Vesper) | `rebirth_0` | `src/ui/sanctuary.gd` (random 1 of 6 after a death) |
| `assets/audio/vo/rebirth_1_01.ogg` | 4.50 s | lyra (Vesper) | `rebirth_1` | `src/ui/sanctuary.gd` (random 1 of 6 after a death) |
| `assets/audio/vo/rebirth_2_01.ogg` | 2.85 s | lyra (Vesper) | `rebirth_2` | `src/ui/sanctuary.gd` (random 1 of 6 after a death) |
| `assets/audio/vo/rebirth_3_01.ogg` | 2.28 s | lyra (Vesper) | `rebirth_3` | `src/ui/sanctuary.gd` (random 1 of 6 after a death) |
| `assets/audio/vo/rebirth_4_01.ogg` | 2.93 s | lyra (Vesper) | `rebirth_4` | `src/ui/sanctuary.gd` (random 1 of 6 after a death) |
| `assets/audio/vo/rebirth_5_01.ogg` | 4.70 s | lyra (Vesper) | `rebirth_5` | `src/ui/sanctuary.gd` (random 1 of 6 after a death) |
| `assets/audio/vo/sanctuary_return_01.ogg` | 3.41 s | lyra (Vesper) | `sanctuary_return` | `src/ui/sanctuary.gd` |
| `assets/audio/vo/sanctuary_return_02.ogg` | 6.90 s | lyra (Vesper) | `sanctuary_return` | `src/ui/sanctuary.gd` |
| `assets/audio/vo/sentinel_death_01.ogg` | 2.30 s | sentinel (Sterling) | `sentinel_death` | `src/combat/duel.gd` (`Story.play("sentinel_death")` via `VOICE_KEYS`); `src/cine/cine_duel.gd` |
| `assets/audio/vo/sentinel_death_02_f.ogg` | 2.04 s | player (Imogen) | `sentinel_death` | `src/combat/duel.gd` (`Story.play("sentinel_death")` via `VOICE_KEYS`); `src/cine/cine_duel.gd` |
| `assets/audio/vo/sentinel_death_02_m.ogg` | 2.12 s | player (Callum) | `sentinel_death` | `src/combat/duel.gd` (`Story.play("sentinel_death")` via `VOICE_KEYS`); `src/cine/cine_duel.gd` |
| `assets/audio/vo/sentinel_death_03.ogg` | 2.30 s | sentinel (Sterling) | `sentinel_death` | `src/combat/duel.gd` (`Story.play("sentinel_death")` via `VOICE_KEYS`); `src/cine/cine_duel.gd` |
| `assets/audio/vo/sentinel_intro_01.ogg` | 1.60 s | sentinel (Sterling) | `sentinel_intro` | `src/combat/duel.gd` (`Story.play("sentinel_intro")` via `VOICE_KEYS`); `src/cine/cine_duel.gd` |
| `assets/audio/vo/sentinel_intro_02_f.ogg` | 1.72 s | player (Imogen) | `sentinel_intro` | `src/combat/duel.gd` (`Story.play("sentinel_intro")` via `VOICE_KEYS`); `src/cine/cine_duel.gd` |
| `assets/audio/vo/sentinel_intro_02_m.ogg` | 1.88 s | player (Callum) | `sentinel_intro` | `src/combat/duel.gd` (`Story.play("sentinel_intro")` via `VOICE_KEYS`); `src/cine/cine_duel.gd` |
| `assets/audio/vo/sentinel_intro_03.ogg` | 2.07 s | sentinel (Sterling) | `sentinel_intro` | `src/combat/duel.gd` (`Story.play("sentinel_intro")` via `VOICE_KEYS`); `src/cine/cine_duel.gd` |
| `assets/audio/vo/sentinel_memory_01.ogg` | 5.30 s | archivist (Onyx) | `sentinel_memory` | `src/combat/duel.gd` (`Story.play("sentinel_memory")` via `VOICE_KEYS`); `src/cine/cine_duel.gd` |
| `assets/audio/vo/sentinel_memory_02.ogg` | 8.50 s | archivist (Onyx) | `sentinel_memory` | `src/combat/duel.gd` (`Story.play("sentinel_memory")` via `VOICE_KEYS`); `src/cine/cine_duel.gd` |
| `assets/audio/vo/sentinel_memory_03.ogg` | 6.10 s | lyra (Vesper) | `sentinel_memory` | `src/combat/duel.gd` (`Story.play("sentinel_memory")` via `VOICE_KEYS`); `src/cine/cine_duel.gd` |
| `assets/audio/vo/sentinel_retry_01.ogg` | 2.72 s | sentinel (Sterling) | `sentinel_retry` | `src/combat/duel.gd` (`Story.play("sentinel_retry")` via `VOICE_KEYS`); `src/cine/cine_duel.gd` |
| `assets/audio/vo/widow_death_01.ogg` | 4.30 s | widow (Sloane) | `widow_death` | `src/combat/duel.gd` (`Story.play("widow_death")` via `VOICE_KEYS`) |
| `assets/audio/vo/widow_death_02.ogg` | 2.44 s | lyra (Vesper) | `widow_death` | `src/combat/duel.gd` (`Story.play("widow_death")` via `VOICE_KEYS`) |
| `assets/audio/vo/widow_intro_01.ogg` | 3.82 s | widow (Sloane) | `widow_intro` | `src/combat/duel.gd` (`Story.play("widow_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/widow_intro_02_f.ogg` | 1.65 s | player (Imogen) | `widow_intro` | `src/combat/duel.gd` (`Story.play("widow_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/widow_intro_02_m.ogg` | 1.49 s | player (Callum) | `widow_intro` | `src/combat/duel.gd` (`Story.play("widow_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/widow_intro_03.ogg` | 3.27 s | widow (Sloane) | `widow_intro` | `src/combat/duel.gd` (`Story.play("widow_intro")` via `VOICE_KEYS`) |
| `assets/audio/vo/wyrm_intro_01.ogg` | 6.00 s | lyra (Vesper) | `wyrm_intro` | `src/combat/duel.gd` (`Story.play("wyrm_intro")` via `VOICE_KEYS`) |

Total speech duration: 342 s across 97 files.

Coverage check: `data/dialogue.json` has 83 lines; 14 are player lines with two files each; 83 + 14 = 97 files expected, 97 present, none missing and none orphaned.

## Things the file list shows
- `rain.ogg` has no caller.
- `sanctuary.ogg` is unreachable while `hub.ogg` exists; `menu.ogg` is still the exploration music of seven regions.
- No file exists for any `explore_<region>` other than the Courtyard or any `boss_<id>` other than the Ashen Sentinel.
- `ui_confirm`, `victory`, `death` and `finisher` are routed to the Combat bus by name; `bell` to Interface; `footstep` to Ambience.
- The comment at the top of `src/core/sfx.gd` ("All audio is original, synthesized by tools/gen_audio.py") is out of date for four music files and all speech.
- Speech files were not loudness-normalised by any script in `tools/` that was read for this manifest.

---

## Missing list
Derived from `SOUND_DESIGN_BIBLE.md` (effects, ambience, interface, cinematics), `SOUNDTRACK_PLAN.md` (music) and `CAMPAIGN_SCRIPT.md` (speech). Every name below is PROPOSED; none exists. "Files" is the count at the variation numbers given in the sound design bible.

### Combat bus
| Family | Proposed names | Files |
|---|---|---|
| Player swings by weapon class | `swing_sword_1..4`, `swing_greatsword_1..4`, `swing_axe_1..4`, `swing_dual_1..4` | 16 |
| Enemy-only swing classes | `swing_cleaver_1..3`, `swing_glaive_1..3`, `swing_claws_1..3` | 9 |
| Heavy swing variants, combo finish | `swing_heavy_2..3`, `swing_combo_finish_1..2` | 4 |
| Blade-on-blade by class pairing | `clash_<class>_<class>_1..2` for 10 pairings of sword, greatsword, axe, dual | 20 |
| Blade bind | `blade_scrape_1..3` | 3 |
| Impacts by weapon class and material | `hit_<sword/greatsword/axe/dual>_<plate/mail/hide/stone/scale>_1..3` | 60 |
| Critical sweetener, posture break | `hit_crit_1..2`, `posture_break_1..2` | 4 |
| Body falls | `body_fall_plate_1..2`, `body_fall_large_1..2` | 4 |
| Finishers by class | `finisher_sword`, `finisher_greatsword`, `finisher_axe`, `finisher_dual` | 4 |
| Shield impacts by shield | `shield_heater_1..3`, `shield_kite_1..3`, `shield_bulwark_1..3`, `shield_reliquary_1..3`, `shield_glacier_1..3`, `shield_scale_1..3` | 18 |
| Block grades | `block_heavy_1..2`, `block_timed_1..2`, `block_perfect_1..2` | 6 |
| Shield handling | `shield_raise_1..3`, `shield_lower_1..3` | 6 |
| Movement | `roll_ground_<surface>_1..2` (10 surfaces), `lunge_step_1..3`, `skid_stop_1..3` | 26 |
| Armour movement, knight | `armor_move_1..6`, `armor_set_light_1..4`, `armor_set_medium_1..4`, `armor_set_heavy_1..4` | 18 |
| Armour movement, foes | `foe_armor_move_<humanoid/heavy/giant/guardian>_1..4` | 16 |
| Effort vocals, male knight | `effort_m_light_1..6`, `_heavy_1..4`, `_block_1..4`, `_hurt_1..5`, `_dodge_1..3`, `_death_1..2`, `effort_m_exhausted`, `breath_m_low_health` | 26 |
| Effort vocals, female knight | same set with `_f_` | 26 |
| Telegraphs and status | `telegraph_heavy_1..2`, `burn_tick_1..2`, `frost_tick_1..2`, `bleed_tick_1..2`, `surge_ready`, `relic_ready`, `relic_use`, second variants of `ember_burst` and `frost` | 13 |
| Foe voices by class | `foe_effort_<5 classes>_1..4`, `foe_hurt_<5>_1..3`, `foe_death_<5>_1..2` | 45 |
| Creature voices | `creature_monstrosity_<idle/attack/hurt/death>_1..3`, `creature_souleater_<…>_1..3` | 24 |
| Ashen Sentinel | `sentinel_step`, `sentinel_ember_vent`, `sentinel_armor_split`, `sentinel_blade_plant`, `sentinel_fall` | 5 |
| Hollow Executioner | `exec_cleaver_drag`, `exec_cleaver_chop`, `exec_root_answer`, `exec_stump_hit` | 4 |
| Pale Huntsman | `hunt_whistle`, `hunt_step_leaf`, `hunt_axe_spin`, `hunt_breath` | 4 |
| Crimson Widow | `widow_blade_draw`, `widow_dash`, `widow_veil_tear`, `widow_breath` | 4 |
| Cathedral Beast | `beast_bell_toll`, `beast_breath`, `beast_roar`, `beast_rise`, `beast_claw_bronze`, `beast_death` | 6 |
| Gravewarden | `warden_lantern_creak`, `warden_lantern_set`, `warden_water_rise`, `warden_wade`, `warden_lantern_out` | 5 |
| Veyrath | `wyrm_wing_pass`, `wyrm_land`, `wyrm_inhale`, `wyrm_fire`, `wyrm_roar`, `wyrm_takeoff`, `wyrm_wing_tear`, `wyrm_death` | 8 |
| Skeldra | `skeldra_chain`, `skeldra_roar`, `skeldra_chain_snap`, `skeldra_frost_breath`, `skeldra_death` | 5 |
| Frostbound King | `king_ice_crack`, `frost_shatter`, `king_frost_climb`, `king_crown_crack`, `king_step_ice` | 5 |
| Devourer of Names | `devourer_gather`, `devourer_whisper_bed`, `devourer_open`, `devourer_name`, `devourer_fall` | 5 |
| Forgotten Monarch | `monarch_rise`, `monarch_hall_kneel`, `monarch_crown_burn`, `monarch_blade`, `monarch_sit` | 5 |

### Ambience bus
| Family | Proposed names | Files |
|---|---|---|
| Region beds (90 s or longer) | `amb_sanctuary`, `amb_courtyard`, `amb_blackwood`, `amb_cathedral`, `amb_crypt`, `amb_crypt_deep`, `amb_roost`, `amb_citadel`, `amb_deep`, `amb_throne` | 10 |
| Region one-shots | `amb_oneshot_<region>_1..4` for 8 regions | 32 |
| Footsteps by surface | `foot_stone_1..6`, `foot_rubble_1..6`, `foot_leaf_1..6`, `foot_ash_1..6`, `foot_water_1..6`, `foot_glass_1..6`, `foot_snow_1..6`, `foot_ice_1..6`, `foot_deep_1..4`, `foot_marble_1..6` | 58 |
| Low health | `player_heartbeat` | 1 |

### Interface bus
| Family | Proposed names | Files |
|---|---|---|
| Equipment | `ui_equip_weapon_1..2`, `ui_equip_shield_1..2`, `ui_equip_armor_1..2` | 6 |
| Forge and shop | `ui_upgrade`, `ui_error` | 2 |
| Navigation | `ui_tab`, `ui_scroll_tick`, `ui_slider`, `ui_pause`, `ui_resume` | 5 |
| Discovery | `ui_combo_discovered`, `ui_lore_found`, `ui_memory_found` | 3 |
| World interactions | `ui_lever_<courtyard/blackwood/cathedral/crypt/roost/citadel/deep/throne>`, `ui_shrine_rest` | 9 |

### Cinematics bus
| Family | Proposed names | Files |
|---|---|---|
| Opening | `cine_crown_wake`, `cine_chamber_open` | 2 |
| Memories | `cine_memory_in`, `cine_memory_out`, `cine_archivist_bed` | 3 |
| Reveal and endings | `cine_lab_reveal`, `cine_crown_hum`, `cine_crown_disconnect`, `cine_crown_partition`, `cine_external_search`, `cine_external_answer` | 6 |
| Foley for filmed clips | cue lists and foley for 7 road clips and 18 Sentinel clips | per clip |

### Music bus
| Family | Proposed names | Files |
|---|---|---|
| Region exploration | `explore_blackwood`, `explore_cathedral`, `explore_crypt`, `explore_roost`, `explore_citadel`, `explore_deep`, `explore_throne` | 7 |
| Region combat variants | `combat_<region id>` for 8 regions | 8 |
| Bosses | `boss_pale_huntsman`, `boss_hollow_executioner`, `boss_crimson_widow`, `boss_cathedral_beast`, `boss_gravewarden`, `boss_cinder_wyrm`, `boss_rimewyrm`, `boss_frostbound_king`, `boss_devourer`, `boss_forgotten_monarch` | 10 |
| Phase layers | `boss_ashen_sentinel_p2` first; one per multi-phase boss after | 1 to 10 |
| Stingers and story | `sting_victory`, `sting_defeat`, `memory`, `ending_silence`, `ending_steward`, `ending_free_cities`, `postcredits`, `credits` | 8 |

### Dialogue bus
| Family | Detail | Lines |
|---|---|---|
| Recast of all existing lines | The master requirements call for recasting from the written profiles after the owner picks from the audition reel; blocked on the owner listening | 83 lines, 97 files |
| Stage remarks, seven regions | `blackwood_0..6`, `cathedral_0..6`, `crypt_0..6`, `roost_0..6`, `citadel_0..6`, `deep_0..6`, `throne_0..5` (throne 6 goes straight to the Monarch) | 48 |
| New boss scenes | `huntsman_yield`, `huntsman_death`, `executioner_retry`, `executioner_memory`, `widow_yield`, `widow_memory`, `gravewarden_last`, `crypt_truth`, `wyrm_death`, `wyrm_memory`, `rimewyrm_intro`, `rimewyrm_death`, `frostking_memory`, `devourer_death`, `devourer_memory` | about 32 |
| Endings | Three endings, two or three lines each | about 8 |
| Quest lines | Eight proposed quests, one or two lines each where given | about 6 |
| Voice processing | Helm, machine echo, band-limit and tremolo, layered echo, per the voice bible; no processing exists | — |
| Devourer layering | Several voices per line | 3 lines to rebuild |

Approximate size of the missing list: about 400 effect files on the Combat bus, about 100 on Ambience, 25 on Interface, 11 on Cinematics, 34 to 43 music files, and about 95 new speech lines plus the recast. These are specification counts, not a schedule.
