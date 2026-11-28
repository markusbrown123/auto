# Recorded-sound audition pack (2026-11-28)

These are real recordings, openly licensed (CC0 or CC BY 4.0), proposed as replacements for the synthesised sounds. **Nobody has listened to any of them.** Every comment below is a measurement or a description of the source. None of it says how a file sounds; that is for the owner to judge. Nothing is in `assets/` and no game code has changed.

- Sources, licences and attributions: `docs/AUDIO_SOURCES_RECORDED.md` (one row per source file, with the gaps listed at the end).
- Cleaned single shots and loops (WAV, 44.1 kHz): `art/sfx_recorded/{footsteps,armor,fire,ambience,combat}/`.
- Where two credible options were found, both are here as `_a` and `_b`.

## Read this first: loudness and source quality
- **Loudness.** The brief asked for about -16 LUFS on short effects and -23 LUFS on ambience. Peaks were capped at -2 dBFS and **no limiter or compressor was used**, so -16 could not be reached: single footsteps, clashes and crackles are too peaky. Each group was set to one common loudness instead, the highest level every member reaches without passing the peak cap. Files within a group can be compared directly; files from different groups cannot.

  | Group | Common integrated loudness |
  |---|---|
  | Footsteps | -27.5 LUFS |
  | Armour | -22.5 LUFS |
  | Combat | -25 LUFS |
  | Fire (close part) | -36 LUFS |
  | Wind, birds | -23 LUFS |
  | Ocean | -24 LUFS |
  | Atmosphere | -25.5 LUFS |
  | Stream | -27.5 LUFS |

  Measured values (decoded mp3, ffmpeg `ebur128`) are in the table, and sit 0.1 to 0.4 LU from the group value.
- **Freesound material is from previews.** These are lossy Ogg Vorbis files (about 100 to 190 kbps), or MP3 for `ambience_ocean_b`, because the original WAV/FLAC needs a Freesound OAuth2 login. OpenGameArt material is from the lossless files. Which source is which is marked below and in the ledger.
- **"Floor" column.** This is the peak-to-floor ratio of the source recording: peak minus the 10th percentile of 50 ms RMS, in dB. It roughly indicates noise between events, so higher means quieter background. Two caveats: for continuous ambiences it only says how steady the sound is, and "gated" means the author's file is digital silence between events, so the noise under the events cannot be measured.
- **mp3 format.** 192 kbps CBR, 44.1 kHz. Footsteps and combat are mono; ambience and fire are stereo.
- **Timing.** Footstep walks use 0.64 s per step, about 1.1 m/s with 0.70 m steps. Each step varies by ±4 % in interval, ±3 % in pitch and ±1.5 dB in level. Each walk has 7 steps and uses each single step once where there are 7 or more singles.

## Listening order

| # | File | What it is | Duration | Peak dBFS | LUFS (I) | Source and floor | Notes from measurement and source description |
|---|---|---|---|---|---|---|---|
| 1 | `footsteps_stone_sequence_a.mp3` | 7-step walk on stone | 5.0 s | -3.1 | -27.8 | Vrymaa, "Footsteps Knight - Walk & run, courtyard" (Freesound preview, CC0). Floor 61 dB | Heavy boots with several belts on a stone courtyard. Author: "No background noise. No reverb." Recorded on an iPhone or a cheap condenser. 8 steps cut from 1.5 to 13 s. The source peaks at +0.8 dBFS in the decoded preview, so its loudest event may be clipped; the steps chosen peak at -5 to -18 dBFS in the source. |
| 2 | `footsteps_stone_sequence_b.mp3` | 7-step walk on rock | 5.0 s | -3.4 | -27.7 | Nox_Sound, "Footsteps_Mountain_Boots_Rock_Walk" (Freesound preview, CC0). Gated | Mountain boots on rock. Original is 48 kHz 24-bit, recorded with a Rode NTG4+. |
| 3 | `footsteps_dirt_sequence_a.mp3` | 7-step walk, gravel or dirt path | 5.0 s | -5.7 | -27.9 | Ali_6868, "Knight Left/Right Footstep on Gravel 1-5 (With Chainmail)" (8 Freesound previews, CC0). Floor 44 to 83 dB | A knight wearing chainmail on gravel. Each file is one step; the chainmail is part of the recording. |
| 4 | `footsteps_dirt_sequence_b.mp3` | 7-step walk on mud and soil | 4.8 s | -2.3 | -27.8 | Vehicle (Jan Schupke), `mud-steps-02..05` and `soil-steps-01` (OGA, lossless, CC0). Floor 74 to 91 dB | Only 5 singles, so two are reused, never twice in a row. Shoe type unknown and probably not armoured. |
| 5 | `footsteps_grass_sequence_a.mp3` | 7-step walk on forest floor or grass | 5.2 s | -8.8 | -28.0 | Ali_6868, "Knight ... Footstep Forest/Grass 1-6 (With Chainmail)" (8 Freesound previews, CC0). Floor 31 to 123 dB | The originals are quiet (peak -10 to -23 dBFS) and were raised by up to 20 dB, which raises their noise too. The lowest floor is 31 dB under the step peak. |
| 6 | `footsteps_grass_sequence_b.mp3` | 7-step walk, "sand that sounds like grass" | 4.9 s | -3.1 | -27.8 | Fantozzi, "Sand" steps L1-L3 and R1-R3 (OGA, lossless FLAC, CC0). Floor 28 to 41 dB | The lowest floor in the footstep group: each file is almost all step, with little room tone to judge from. Not armoured. |
| 7 | `footsteps_metal_sequence_a.mp3` | 7-step walk on metal | 5.2 s | -8.3 | -27.8 | Sanderboah, "Walking on metal" (Freesound preview, CC0, original 96 kHz). Floor 63 dB | Shoes on a metal bathtub, so a resonant sheet, not a deck. Steps ring for 0.5 to 0.6 s and were cut there with a fade, so part of the ring is faded out. |
| 8 | `footsteps_metal_sequence_b.mp3` | 7-step walk on metal | 4.7 s | -4.4 | -27.8 | Phil25, "Metal Steps" (Freesound preview, CC0). Gated | Stepping on a metal plate. Short steps (0.19 to 0.34 s). |
| 9 | `armor_movement_a.mp3` | 6 armour shifts, 1 s gaps | 10.9 s | -5.7 | -22.9 | sgossner, "Plate Armor- Rustle 3/4/5" and "chain_rustle_med3" (Freesound previews, **CC BY 4.0**). Floor 36 to 41 dB | A home-made reconstruction Lorica Segmentata (Roman plate), recorded in a studio with two SM57s. Originals are already mp3 on Freesound. Order: rustle 3, chain, rustle 5, rustle 4, rustle 3, chain, at pitch 0.97 to 1.03. Played far louder here than it would be in game. |
| 10 | `armor_movement_b.mp3` | 6 strap and buckle movements | 8.6 s | -2.5 | -22.7 | Vrymaa, "Harness Armour straps - Baldric or military equipment" (Freesound preview, CC0). Floor 79 dB | Straps snagging on carabiners and hooks. Not plate armour. |
| 11 | `fire_close_and_far_a.mp3` | 0-12 s close fire, 1 s silence, 13-25 s far | 25.0 s | -7.0 | -37.1 | felix.blume, "Wood fire crackling, near flames" (Freesound preview, CC0; original 48 kHz 24-bit, Schoeps MS, Sound Devices 744T). Floor 42 dB | Loop made from 40 to 72 s of a 181 s take. "Far" is another 12 s of the same loop, low-passed at 1.2 kHz (two 2nd-order passes) and 10 dB down. Integrated -37 LUFS (the close part alone is about -36): quiet, see the loudness note. |
| 12 | `fire_close_and_far_b.mp3` | same layout | 25.0 s | -2.8 | -39.0 | Spandau, "campfire.wav" (Freesound preview, CC0; original 48 kHz 24-bit, spaced omnis, Vermont). Floor 33 dB | Excerpt from 60 to 92 s. A higher peak-to-loudness ratio than a, so its crackles are more prominent relative to the bed. |
| 13 | `ambience_wind_a.mp3` | mountain wind | 28.0 s | -7.0 | -23.3 | kyles, "mountain wind heavy strong gusts Swiss Alps" (Freesound preview, CC0). Floor 34 dB | Strong gusts. Every ambience file is 25 s of a 30 s loop (from 5 s to its end), then its first 3 s again, so **the loop seam is at 25.0 s**. The loops are 2 s equal-power cross-fades. A 30 s loop is shorter than the 90 s the sound design bible proposes; most sources are long enough (61 to 418 s; the shortest are ocean a and atmosphere b) to cut longer loops after approval. |
| 14 | `ambience_wind_b.mp3` | cliff-top wind | 28.0 s | -8.2 | -23.2 | felix.blume, "Post vibrating in the wind, on the top of the cliff (Desert of Chile)" (Freesound preview, CC0; original mono). Floor 24 dB | Mono source. The title says a post vibrates in the wind, so there may be a tonal component; it was not checked. The steadiest wind measured (10th percentile only 24 dB under the peak). |
| 15 | `ambience_ocean_a.mp3` | distant waves | 28.0 s | -10.3 | -24.3 | chris_dagorne, "11ft waves breaking on sandy beach in the distance from the top of the cliff" (Freesound preview, CC0). Floor 18 dB | Recorded as distant by the author. The narrowest dynamics of the set (18 dB). |
| 16 | `ambience_ocean_b.mp3` | close waves made "distant" | 28.0 s | -2.5 | -24.3 | Luftrum, "oceanwavescrushing.wav" (Freesound **hq MP3** preview, **CC BY 4.0**). Floor 35 dB | Originally close, crashing waves. Low-passed at 900 Hz (two 2nd-order passes) to sound further away. Large wave peaks (peak 22 dB above loudness). |
| 17 | `ambience_stream_a.mp3` | stream, close | 28.0 s | -2.5 | -27.7 | jackthemurray, "Stream River Water Up Close" (Freesound preview, CC0). Floor 32 dB | The source is very quiet (peak -27.9 dBFS) and was raised 26 dB, so preview codec noise is raised with it. One transient sets the peak, which held the stream pair to -27.5 LUFS. |
| 18 | `ambience_stream_b.mp3` | mountain stream from the bank | 28.0 s | -6.8 | -27.8 | bassimat, "Mountain Stream Flowing Past from the Riverbank, Boscoverde, Dolomites" (Freesound preview, CC0). Floor 27 dB | Steady, dense flow; excerpt from 60 to 92 s of 418 s. |
| 19 | `ambience_birds_a.mp3` | forest morning birds | 28.0 s | -8.9 | -23.3 | kvgarlic, "MidwestForestSummerMorningMay2018" (Freesound preview, CC0). Floor 23 dB | Midwest USA species, so not necessarily European. Quiet source, raised 17 dB. |
| 20 | `ambience_birds_b.mp3` | forest ambience | 28.0 s | -7.4 | -23.3 | keng-wai-chane-chick-te, "AMBIANCE_FORET_LANDENNE_00001" (Freesound preview, CC0; original 96 kHz). Floor 29 dB | Belgian forest (Landenne). Excerpt from 60 to 92 s. |
| 21 | `ambience_atmosphere_a.mp3` | very quiet night air tone | 28.0 s | -2.5 | -25.8 | kyles, "air tone village night very quiet light breeze distant something" (Freesound preview, CC0). Floor 17 dB | The original peaks at -43.5 dBFS and was raised 37.5 dB, so codec and recorder noise are probably a large part of what is heard. One event ("distant something") sets the peak. |
| 22 | `ambience_atmosphere_b.mp3` | interior room tone | 28.0 s | -12.6 | -25.7 | composingatnight, "1800's Church Room Tone" (Freesound preview, CC0; original mono). Floor 33 dB | Raised 30 dB; same caveat as 21. An interior tone, a possible bed for the Sanctuary or cathedral. |
| 23 | `combat_clashes_a.mp3` | 8 blade-on-blade clashes, 1 s gaps | 12.8 s | -2.4 | -25.3 | Still North Media, "Medieval sound effects - Weapon impacts" (OGA, lossless 192 kHz 24-bit, CC0). Floor 76 to 86 dB | Real weapons. The loudest take from each of 8 pairings, in order: sabre/Norse sword, Norse sword/katana, axe/Norse sword, spear/Norse sword, seax/Norse sword, sabre/katana, dagger/Norse sword, spear/sabre. Some takes were followed closely by the next one, so clashes are cut at 0.32 to 1.08 s with a 150 ms fade, not a natural decay. Two source files measure slightly above 0 dBFS (seax/Norse +1.0, mace +0.3), a sign of possible clipping in the loudest takes. |
| 24 | `combat_clashes_b.mp3` | 8 clashes, 1 s gaps | 20.3 s | -4.9 | -25.2 | Vehicle, `sword-knife-clash-02,05,07,08,11,12,17,09` (OGA, lossless, CC0). Floor 55 to 74 dB | A sword against a knife; the files are normalised to 0 dBFS by the author. Each is about 1.5 s with its natural ring. |
| 25 | `combat_swings_light_heavy_a.mp3` | 4 light, then 4 heavy swings, 0.8 s gaps | 11.1 s | -3.4 | -25.1 | Still North Media, "Weapon Textures": Katana, Seax (light); Axe, Spear (heavy) (OGA, lossless, CC0). Floor 34 to 59 dB | The axe and spear takes have the higher background (floor 34 to 46 dB under peak). Fixed windows around each loudness peak: 0.47 s light, 0.75 s heavy. |
| 26 | `combat_swings_light_heavy_b.mp3` | 4 light, then 4 heavy | 13.4 s | -5.0 | -25.3 | qubodup, bamboo stick swooshes `swosh-01,05,07,08` (light) and `03,28,31,32` (heavy) (OGA, lossless, CC0). Floor 34 to 45 dB | A bamboo stick, not a blade. The "heavy" ones are longer swooshes **pitched and slowed to 0.8x**. |
| 27 | `combat_block_parry_hit_a.mp3` | 5 sounds, 1.2 s gaps, in this order: **block** at 0.3 s, **parry** at 1.9 s, **armour impact** at 4.3 s, **direct hit** at 6.1 s, **heavy impact** at 7.9 s | 8.6 s | -3.9 | -25.3 | Block: SNM "Axe Sabre Haft on Blade" (CC0). Parry: SNM "Sabre Katana Hilt on Blade", the take with the longest ring (1.17 s) (CC0). Armour impact: sgossner "Plate Armor- Hit 4" (**CC BY 4.0**). Direct hit: magnuswaker "Pound of Flesh 1" (CC0). Heavy impact: SNM "Mace Norse Sword Blade" (CC0). Floor 44 to 78 dB | The block is steel on a wooden haft, standing in for a shield. The direct hit is foley (wet paper towels, a sloshed bottle). The heavy impact is a mace on a sword, metal on metal. |
| 28 | `combat_block_parry_hit_b.mp3` | same order: **block** at 0.3 s, **parry** at 3.1 s, **armour impact** at 6.3 s, **direct hit** at 8.1 s, **heavy impact** at 10.1 s | 12.2 s | -5.9 | -25.2 | Block: Hakren "Iron-Wood Slam" (CC0). Parry: Vehicle `sword-knife-clash-04` (2.0 s ring) (CC0). Armour impact: EminYILDIRIM "Combat Punch Metal Armor" (**CC BY 4.0**). Direct hit: Slave2theLight "3 Bat hits", hit 1 (**CC BY 4.0**). Heavy impact: sgossner "Plate Armor- Drop 4" (**CC BY 4.0**). Floor 36 to 84 dB | The block is a metal ladder on a wood plank, with reverb and EQ the author added. The armour impact source has the lowest floor of the combat set (36 dB). The direct hit is a wooden bat on a prop. The heavy impact is armour falling (a "death drop"), not a weapon. |

## What was done, in general
Details per file are in the ledger.
- **Decoding and resampling.** Every source was decoded with ffmpeg and resampled to 44.1 kHz. Stereo sources were downmixed to mono for one-shots, as (L+R)/2.
- **Cutting.** One-shots were cut at the detected onset with 4 ms pre-roll, ending before the next event or at a maximum length.
- **Filtering.** High-pass at 30 Hz, or 60 Hz for whooshes and armour.
- **Fades and level.** 2 ms fade-in and a 30 to 400 ms fade-out; one-shot WAVs peak-normalised to -3 dBFS.
- **Loops.** A 32 s excerpt with the last 2 s equal-power cross-faded into the start, giving 30 s.
- **Extra treatment.** Pitch variation only in the walks and armour sequence (±3 %) and the "heavy b" swings (0.8x). Low-pass only on the fire "far" halves and on `ambience_ocean_b`.
- **Not done.** No EQ beyond those filters, no layering, no reverb, no denoising, no limiting.

## Not yet checked (needs ears)
- Whether any of this sounds real, heavy or good.
- Whether the loop seams at 25.0 s are audible.
- Whether the preview codec artefacts are audible in the boosted quiet sources (items 5, 17, 19, 21, 22).
- Whether the cut-short clashes in item 23 sound truncated.
- Whether the stand-ins (shield blocks, flesh hits, non-armoured steps) are acceptable.
