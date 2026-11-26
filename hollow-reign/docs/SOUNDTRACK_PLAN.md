# Hollow Reign: soundtrack plan

The soundtrack as a system: what exists, the full track list, how tracks adapt to play, loop and transition rules, and generation prompts. Written 2026-11-26.

## Honesty note
Nobody has listened to any music in this project. Existing files are described by how they were made and how long they are, never by how they sound. Everything not marked "exists" is PROPOSED. This plan authorises no spending: generation with the current tool costs about 9 credits a minute (`tools/music.py`), and every purchase must fit the $100 cap and be logged in `SPENDING_LOG.md`.

## 1. What exists (`assets/audio/music/`)

| File | Length | Source | Loudness target in the script | Used by |
|---|---|---|---|---|
| `theme.ogg` | 90.1 s | generated music (`tools/music.py`, prompt "Main theme for a dark sci-fantasy epic…") | loudnorm I=−16, TP=−1.5 | Title screen and the opening (`music_for("theme", "menu")`) |
| `hub.ogg` | 75.1 s | generated music ("Quiet sanctuary music…") | same | Sanctuary (`music_for("hub", "sanctuary")`) |
| `explore_courtyard.ogg` | 85.1 s | generated music ("Exploration underscore for a ruined mountain fortress…") | same | Courtyard exploration and road walks (`music_for("explore_courtyard", "menu")`) |
| `boss_ashen_sentinel.ogg` | 90.1 s | generated music ("Boss battle music for a towering ancient guardian knight… 90 beats per minute") | same | Ashen Sentinel, real-time and cinematic duel (`music_for("boss_ashen_sentinel", foe.music)`) |
| `menu.ogg` | 48.0 s | synthesised by `tools/gen_audio.py` (drone-based) | −14 LUFS (script's estimate) | Fallback for `theme` and for every `explore_<region>` that has no file: all regions except the Courtyard |
| `sanctuary.ogg` | 48.0 s | synthesised by `tools/gen_audio.py` | −14 | Fallback for `hub`; not reached while `hub.ogg` exists |
| `combat_a.ogg` | 33.6 s | synthesised: 100 bpm, 14 bars, E minor chart (Em Em C D Em Em C B Am Am C D Em B) | −14 | `music` field of all 40 ordinary foes and of the Sentinel, Executioner, Widow and Huntsman |
| `combat_b.ogg` | 33.6 s | synthesised: same chart and tempo as `combat_a`, denser arrangement | −14 | `music` field of the Beast, Gravewarden, Frostbound King, Veyrath and Skeldra; also the phase-change layer over `combat_a` |
| `final.ogg` | 40.0 s | synthesised: 72 bpm, 12 bars, D minor chart (Dm Dm Bb F Gm Gm A A Bb C A A) | −14 | `music` field of the Monarch and the Devourer |

All nine are **unheard**. The four generated cues share one written motif (section 2). The five synthesised cues were made earlier and do not use it.

How the generated cues were made loopable: the first 5 seconds are cut off and cross-faded onto the end (triangular curves), so each file is 5 s shorter than the requested duration. Whether the join is inaudible has not been checked by ear; the script's comment says it is, which is an expectation, not a result.

## 2. The motif
From `tools/music.py`, used in all four generated prompts:

> one recurring original motif: a slow rising four-note figure on solo cello that falls back by a step, as if remembering something and losing it.

Plan for its use (PROPOSED):
- Every region and boss cue states it at least once, on an instrument that belongs to that place.
- It is never completed (it always falls back) until the third ending, where it rises and stays.
- The Monarch's cue plays it in the major, harmonised: his version of the same idea.
- A text prompt cannot guarantee that a generation service reproduces the same four notes across cues. Whether the existing four cues actually share a recognisable figure is unknown until someone listens. If they do not, the fallback is to record the motif once as a short stem and layer it over each cue in the engine.

## 3. Full track list

Naming follows what the code already looks for: `explore_<region id>`, `boss_<foe id>`. A file with the right name is picked up with no code change.

### 3.1 Front end and hub
| Track | Status | Instrumentation | Mood |
|---|---|---|---|
| `theme` | exists (generated, unheard) | Solo cello, low drone, violins, French horns, full orchestra, wordless mixed choir, frame drums | Grand, sorrowful, mysterious |
| `hub` | exists (generated, unheard) | Felt piano, solo cello, string pad, distant metallic bell tones, no percussion | Intimate, safe, melancholy |
| `menu`, `sanctuary` | exist (synthesised, unheard) | Synthetic drones and pads | Placeholders; retire once every `explore_*` file exists |
| `credits` | missing, PROPOSED | Full statement of the theme, then each region's instrument in turn | Summation |

### 3.2 Regions (exploration)
| Track | Status | Instrumentation | Mood |
|---|---|---|---|
| `explore_courtyard` | exists (generated, unheard) | High strings, French horn call, low harp, wind textures, faint metallic hum | Calm, watchful, uneasy |
| `explore_blackwood` | missing | Bass clarinet, bowed double bass harmonics, hand drum played with fingers, wooden percussion, hurdy-gurdy drone | Close, patient, hunted |
| `explore_cathedral` | missing | Pipe organ pedal notes, wordless women's choir recorded as if far away and slightly detuned, solo viola, bowed metal | Scorched reverence; something clinical underneath |
| `explore_crypt` | missing | Low male choir on closed vowels, bass flute, water-like harp harmonics, glass harmonica, sub drone | Tender, patient, drowned |
| `explore_roost` | missing | Solo horn in open fifths, high tremolo violins, large frame drum struck rarely, breathy wind instruments | Height, heat, exposure |
| `explore_citadel` | missing | Celesta, bowed crotales, string harmonics without vibrato, a single muted trumpet far away | Stillness; cold that is kept, not weather |
| `explore_deep` | missing | Whispering choir with no pitch, contrabass clarinet, reversed piano, long silences | Absence; the sense of being listened to |
| `explore_throne` | missing | String orchestra in slow chorale, solo cello carrying the motif, faint steady electronic pulse like a relay | Ceremony over machinery; arrival |

### 3.3 Bosses
| Track | Status | Current fallback | Instrumentation | Mood | Tempo |
|---|---|---|---|---|---|
| `boss_ashen_sentinel` | exists (generated, unheard) | — | War drums, anvil, low brass and cellos ostinato, male choir, driving violins | Powerful, tragic, disciplined | 90 bpm |
| `boss_pale_huntsman` | missing | `combat_a` | Solo fiddle played roughly, hand drums, bass clarinet, no choir | Lean, mortal, wary; smaller than the other fights | 104 |
| `boss_hollow_executioner` | missing | `combat_a` | Low strings in strict unison, timpani on every bar line, a struck iron bar, bassoons | Mechanical procedure; a sentence being read | 76 |
| `boss_crimson_widow` | missing | `combat_a` | Two solo violins in close canon, harpsichord-like plucked strings, snare with brushes, cello pizzicato | Fast, exact, bitter; a duel between equals | 132 |
| `boss_cathedral_beast` | missing | `combat_b` | Full organ clusters, cracked bell, low brass growls, large drums, no melody until the second half | Animal mass in a sacred room | 96 |
| `boss_gravewarden` | missing | `combat_b` | Low male choir, cellos and basses, slow bass drum, solo bass flute over the top | A heavy lament; he does not want this fight | 60 |
| `boss_cinder_wyrm` | missing | `combat_b` | Horns in fifths, racing string ostinato, taiko-like drums, anvils, high piccolo shrieks | Scale and heat; the sky as an opponent | 120 |
| `boss_rimewyrm` | missing | `combat_b` | Bowed metal, high strings sul ponticello, chain-like metallic percussion, low horn calls | Cold, restrained, sad obedience | 88 |
| `boss_frostbound_king` | missing | `combat_b` | Brass chorale, celesta, tremolo strings, timpani, late entry of full choir | Ruined majesty, weariness that turns to storm | 80 |
| `boss_devourer` | missing | `final` | Many solo voices entering one by one (men, women, children, wordless), prepared piano, low strings glissando | Grief more than horror | free, then 72 |
| `boss_forgotten_monarch` | missing | `final` | Full orchestra and choir; the motif harmonised in the major on strings; solo cello against it in the minor | A reasonable argument set to music; tragic, not villainous | 84 |
| `boss_azhurion` | missing; the boss is not in the game | — | Reserved | — | — |

### 3.4 Shared combat and story cues
| Track | Status | Use |
|---|---|---|
| `combat_a`, `combat_b` | exist (synthesised, unheard) | Ordinary fights everywhere today |
| `combat_<region id>` ×8 | missing, PROPOSED | A short combat variant of each region's exploration cue, same key and tempo, so ordinary fights stay in the region's sound |
| `sting_victory`, `sting_defeat` | missing (the effects `victory.wav` and `death.wav` do this job today, on the Combat bus) | Musical endings in the key of the current cue |
| `memory` | missing | Under memory records: the motif on a music-box-like instrument, band-limited |
| `ending_silence`, `ending_steward`, `ending_free_cities` | missing | See `CINEMATIC_SCRIPT.md` section 5 |
| `postcredits` | missing | Twenty seconds: a drone in an unrelated key and one answering tone |

## 4. Adaptive layering

### 4.1 What the engine does now
- Two music players crossfade between whole tracks (default 1.5 s; 2.0–2.5 s to silence at a fight's end).
- One extra layer player can start a second file at the main track's playback position and bring it to −5 dB while the main drops to −14 dB (1.2 s). It is used once: on a boss phase change, `combat_b` is layered over foes whose `music` is `combat_a`.
- There are no states, no beat or bar awareness, no stems, no stingers, and no response to health.
- Known mismatch: the Sentinel's main track is now `boss_ashen_sentinel` but the phase layer is still `combat_b`, which was written to fit `combat_a`.

### 4.2 Target states (PROPOSED)
| State | Entered when | Layers sounding | Exit |
|---|---|---|---|
| Exploration | In a region, no foe chosen | A (pad and motif) | Stage option chosen |
| Tension | A fight or boss option is highlighted or chosen; during a boss intro's dialogue | A + B (pulse, low strings) | Fight starts, or the player backs out |
| Combat | Fight begins | B + C (percussion, ostinato), A reduced | Foe dies or player dies |
| Combat, phase 2 and 3 | Boss phase change | B + C + D (choir or brass, full) | — |
| Low health | Player under 25% health | Current layers low-passed, plus E (heartbeat-tempo low drum, a held high string) | Health back over 35% (hysteresis so it does not flutter) |
| Victory | Foe dies | Everything cuts on the finisher frame; `sting_victory` after 1.6 s (the delay already used); then A returns alone | Next stage |
| Defeat | Player dies | 2.0 s fade (already implemented), `sting_defeat` | Sanctuary: `hub` |
| Dialogue | A scene plays | Whatever is sounding, ducked 9 dB (implemented) | Scene ends |

### 4.3 How to build it
Two routes; both PROPOSED.

**Route 1: stems of one piece (preferred).** Each region and boss cue is delivered as three or four files of identical length, tempo and key (A pad, B pulse, C percussion, D full). All start together and loop together; states are volume changes only. This needs `sfx.gd` to hold four synchronised players instead of one layer, about 30 lines of change. A text-to-music service does not reliably return matched stems. Options: a service or mode that exports stems; or generate the full cue once and split it with a stem separator; or compose stems by synthesis as `gen_audio.py` already does for `combat_a`/`combat_b`, which guarantees alignment.

**Route 2: whole-track crossfades (works with today's code).** Per region: `explore_<region>` and `combat_<region>` in the same key and tempo, crossfaded over one bar at state change. Boss phases use the existing layer call with a purpose-made `boss_<id>_p2` file of identical length. Cheaper, less smooth, and tension and low-health states become filters and added one-shot layers instead of music changes.

Recommended first step for the Sentinel encounter, in keeping with "one exceptional encounter first": make `boss_ashen_sentinel_p2` (same length, key and tempo as the existing boss file) and change the layer name used on phase change from the fixed `combat_b` to `boss_<foe id>_p2` when that file exists.

## 5. Loop and transition rules
1. Every looping cue is cut to a whole number of bars at a stated tempo. Record tempo, bar count and key in a table (below) so the engine can time transitions. The four generated cues were not made this way: they are cut by seconds, and their actual tempo and bar count are unmeasured.
2. Loops are made by a tail-to-head crossfade (5 s today). For bar-accurate loops, prefer rendering two passes and cutting on the bar line with the reverb tail of pass one mixed into the head.
3. Minimum loop lengths: exploration 120 s, boss 90 s, ordinary combat 60 s. Existing `combat_a`/`combat_b` at 33.6 s will repeat four or more times in a long fight.
4. State changes happen on the next bar line, at most one bar late. Exceptions that cut at once: finisher frame, player death, perfect-parry duck.
5. Fades: exploration → combat one bar; combat → exploration two bars after the victory sting; any → silence for dialogue-only scenes 2.5 s; region → region 3 s through silence, never a direct crossfade between two keys.
6. Related keys: a region's exploration, combat and boss cues share a tonal centre. Proposed centres: courtyard D minor, blackwood G minor, cathedral C minor, crypt A minor, roost E minor, citadel F-sharp minor, deep no fixed centre, throne D minor returning to the courtyard's key, with the third ending in D major.
7. No vocals with words, anywhere. Wordless choir only.
8. Loudness: keep the existing `loudnorm` target (I=−16, TP=−1.5) for boss cues; PROPOSED −20 for exploration so that the 9 dB dialogue duck is not the only thing keeping speech clear.
9. The music setting defaults to 0.8 and the bus trim is −3 dB; tracks play at −5 dB on their players. Do not compensate by mastering louder.

| Cue | Tempo | Bars | Key | Measured? |
|---|---|---|---|---|
| `combat_a`, `combat_b` | 100 bpm | 14 | E minor | From the generating script |
| `final` | 72 bpm | 12 | D minor | From the generating script |
| `menu`, `sanctuary` | none (drone, 48 s) | — | D-based drone (`menu`) | From the generating script |
| `boss_ashen_sentinel` | 90 bpm requested | unknown | unknown | No |
| `theme`, `hub`, `explore_courtyard` | not specified | unknown | unknown | No |

## 6. Generation prompts
Written for a text-to-music service in the same form `tools/music.py` uses: instrumental, with a requested duration. All are original descriptions; none names an artist, a composer, a game, a film or an existing piece. Each ends with the shared motif sentence, shown as **[MOTIF]**:

> Built on one recurring original motif: a slow rising four-note figure on solo cello that falls back by a step, as if remembering something and losing it. Original composition, no vocals with words.

Add to each a tempo and key line so cues can be related: "Tempo N beats per minute, in X minor, in four-four time, ending so that it can loop."

### Regions (request 125 s each to keep 120 s after the loop crossfade)
- **`explore_blackwood`** — "Exploration underscore for an overgrown royal hunting forest at dusk. Bass clarinet and bowed double bass harmonics, a hurdy-gurdy drone, soft hand drum played with fingertips, occasional wooden percussion like branches knocking. Close, patient, the feeling of being followed. Sparse, with long rests. Tempo 66 beats per minute, G minor. [MOTIF]"
- **`explore_cathedral`** — "Exploration underscore for a vast burned cathedral open to the sky, ash falling. Deep pipe organ pedal tones, a distant wordless women's choir that sounds like an old recording, slightly unsteady in pitch, solo viola, bowed metal resonances. Reverent and scorched, with something cold and clinical underneath. Tempo 54 beats per minute, C minor. [MOTIF]"
- **`explore_crypt`** — "Exploration underscore for flooded burial halls lit from under the water. Low male choir on closed vowels, bass flute, harp harmonics like drips, glass harmonica, a very low sustained drone. Tender, patient, sorrowful rather than frightening. Tempo 50 beats per minute, A minor. [MOTIF]"
- **`explore_roost`** — "Exploration underscore for a high mountain crag above the clouds, hot wind rising. A solo horn calling in open fifths, high tremolo violins, a large frame drum struck rarely, breathy flutes. Exposed, vast, wary. Tempo 60 beats per minute, E minor. [MOTIF]"
- **`explore_citadel`** — "Exploration underscore for a fortress frozen solid and silent. Celesta, bowed crotales, string harmonics played without vibrato, a single muted trumpet far away. Extremely still and cold, every note isolated. Tempo 48 beats per minute, F-sharp minor. [MOTIF]"
- **`explore_deep`** — "Exploration underscore for a lightless place far underground. Unpitched whispering choir at the edge of hearing, contrabass clarinet, reversed piano notes, very long silences. Empty and watchful, no pulse, no clear key. Sad, not monstrous. [MOTIF, heard once, very quietly, near the end]"
- **`explore_throne`** — "Exploration underscore for the approach to an ancient throne hall. A slow string-orchestra chorale, solo cello carrying the melody, a faint steady electronic pulse like a relay ticking underneath. Ceremonial, heavy with arrival, restrained. Tempo 58 beats per minute, D minor. [MOTIF]"

### Bosses (request 95 s each, as the existing boss cue did; 125 s if budget allows)
- **`boss_pale_huntsman`** — "Battle music for a duel with a lone hunter in a dark forest. A rough solo fiddle, hand drums, bass clarinet, plucked low strings. Lean and wary, human in scale, no choir, no brass. Tempo 104 beats per minute, G minor. [MOTIF]"
- **`boss_hollow_executioner`** — "Boss battle music for an implacable executioner. Low strings in strict unison, timpani on the first beat of every bar, a struck iron bar, bassoons. Slow, procedural, merciless without anger, like a sentence being read aloud. Tempo 76 beats per minute, G minor. [MOTIF]"
- **`boss_crimson_widow`** — "Boss battle music for a fast duel with a master of two blades on cathedral steps. Two solo violins chasing each other in close imitation, plucked strings, brushed snare, cello pizzicato. Quick, exact, bitter, elegant. Tempo 132 beats per minute, C minor. [MOTIF]"
- **`boss_cathedral_beast`** — "Boss battle music for a huge beast in a ruined cathedral. Massive pipe organ clusters, a cracked bell, growling low brass, large drums. Brutal and shapeless at first, a melody forming only in the second half. Tempo 96 beats per minute, C minor. [MOTIF]"
- **`boss_gravewarden`** — "Boss battle music for an old keeper of the dead who does not want to fight. Low male choir, cellos and double basses, a slow bass drum, a solo bass flute above. A heavy lament with the weight of a march. Tempo 60 beats per minute, A minor. [MOTIF]"
- **`boss_cinder_wyrm`** — "Boss battle music for a fight with a great dragon on a mountain summit. Horns in open fifths, racing string ostinato, thunderous large drums, anvil strikes, shrieking piccolo. Enormous, hot, soaring, dangerous. Tempo 120 beats per minute, E minor. [MOTIF]"
- **`boss_rimewyrm`** — "Boss battle music for a chained ice dragon in a frozen pit. Bowed metal, high strings played near the bridge, metallic percussion like a heavy chain, low horn calls. Cold, restrained, sorrowful, building slowly. Tempo 88 beats per minute, F-sharp minor. [MOTIF]"
- **`boss_frostbound_king`** — "Boss battle music for an ancient king entombed in ice. A solemn brass chorale, celesta, tremolo strings, timpani, a full wordless choir entering late. Ruined majesty and great weariness that turns into a storm. Tempo 80 beats per minute, F-sharp minor. [MOTIF]"
- **`boss_devourer`** — "Boss battle music built from many solo voices entering one at a time, men, women and children, wordless, over prepared piano and sliding low strings. It begins without pulse and gathers into a slow, grieving procession. Sorrow, not horror. Tempo 72 beats per minute once the pulse arrives. [MOTIF, sung by a single child's voice]"
- **`boss_forgotten_monarch`** — "Final boss battle music for a dignified ruler who believes he is right. Full orchestra and wordless choir. A noble melody in a major key on the strings is answered by a solo cello in the minor. Controlled, regal, tragic rather than evil, growing to a great climax and never losing its composure. Tempo 84 beats per minute, D minor against D major. [MOTIF, harmonised in the major]"

### Phase layer for the existing boss cue
- **`boss_ashen_sentinel_p2`** — "An added intensity layer for an existing piece: 90 beats per minute, four-four time. Only high driving violins, wordless male choir and anvil strikes, with no bass instruments and no drums, so it can be mixed over another track. Relentless and tragic." (The key must match the existing file, which is unmeasured. Measure it before generating.)

### Story cues
- **`memory`** (40 s) — "A fragile, distant memory. A music-box-like metallic instrument and a single sustained string note, heard as though through an old speaker, band-limited and slightly unsteady. [MOTIF, played once and left unfinished]"
- **`ending_silence`** (90 s) — "An ending of loss and peace at sunrise. A solo cello entirely alone for the first half, then quiet strings entering beneath it, ending on a single warm sustained chord. No percussion, no choir. [MOTIF]"
- **`ending_steward`** (75 s) — "An uncertain ending. A stately string chorale that sounds like a coronation but never resolves; low strings carry a slow rising figure; the final chord is held without its bass note. Grand and uneasy. [MOTIF]"
- **`ending_free_cities`** (110 s) — "A hopeful ending after long sorrow. It begins with a solo cello, joined one instrument at a time by horn, harp, strings and wordless choir, each with its own line, until the full ensemble plays together. Here the rising four-note figure is completed for the first time: it rises and stays, without falling back. Warm, open, earned. Original composition, no vocals with words."
- **`postcredits`** (20 s) — "A cold sustained drone under an unfamiliar sky, in a key unrelated to anything before it. After a long pause, one distant pure tone answers. Nothing else."
- **`credits`** (150 s) — "End credits suite for a dark sci-fantasy epic. A full statement of a sorrowful main melody by orchestra and wordless choir, then quieter passages featuring in turn a horn, an organ, a low choir, a celesta and a solo cello, closing with the solo cello alone. [MOTIF]"

## 7. Cost estimate (not a commitment)
At about 9 credits a minute and about $0.041 a credit (both from the spending log and `tools/music.py`): seven region cues at 125 s ≈ 131 credits; ten boss cues at 95 s ≈ 143 credits; story cues ≈ 73 credits. About 350 credits, roughly $14. The log shows about $48 of the $100 cap used. Failed generations must be recovered by task id, not regenerated.

## 8. Gaps and disagreements found while writing
- The master requirements ask for an "adaptive original soundtrack". What exists is whole-track crossfading plus one phase layer.
- Five of nine music files are synthesised placeholders that share no material with the four generated cues.
- `data/bosses.json` still assigns every foe one of `combat_a`, `combat_b` or `final`; bespoke tracks are found only by file name.
- `tools/music.py` lists four cues; there is no record in the repository of the tempo, key or bar structure of what came back.
- The backlog lists adaptive music layers (B4) as to do and audio sign-off as blocked on the owner listening.
