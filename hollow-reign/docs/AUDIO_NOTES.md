# Audio notes: combat and footstep sound pass

**Status: everything below is still procedurally synthesised (numpy/scipy, no samples) and nobody has listened to any of it.** The owner's verdict on the earlier effects was "generic cheap video game effects". This pass changes how they are built and played back and measures the result; it cannot say whether they now sound realistic or good, and this document does not claim it. Subjective approval is the owner's.

## What changed

### Engine: `src/core/sfx.gd`
- **Pools and no-repeat variation.** Every combat and footstep one-shot belongs to a pool of numbered variants (`POOLS`). `_pick` never returns the variant played last for that pool (uniform over the others). Pitch jitter per pool: metal +/-2 to 2.5 %, parry +/-2 %, hits +/-3 to 4 %, whooshes +/-6 to 7 %, steps +/-5 %. Volume jitter +/-0.8 to 2 dB. Start offset: every file in these pools carries 4 ms of leading silence (`PREROLL`), and the engine starts playback at a random point in that silence, so the onset moves by 0 to 3.6 ms with no attack lost.
- **Voice families** (`FAMILIES`): a limit on simultaneous voices (the oldest of the family is stolen) and a minimum retrigger gap. metal 4 / 40 ms, parry 2 / 120 ms, break 2 / 200 ms, hit 4 / 40 ms, flesh 4 / 40 ms, whoosh 3 / 70 ms, step 2 / 80 ms, layer 8 / 0. The player pool grew from 12 to 24 and voices are tracked by estimated end time, so with no free player the oldest voice is stolen instead of round-robin cutting a random one. Layers never take the gap (only the first layer of an event does).
- **Layered events** (`EVENTS`): clash = clash file (transient + inharmonic ring) + low `thump` layer (when intensity >= 0.6); parry = bright parry file + short reversed-ring `swell` 30 ms later; guard break = dull thud file + `crack` transient + `rattle` (shield/splinter) 90 ms later; armour hit = hit file + occasional `thump`. Layer picks are no-repeat too, so layer combinations vary.
- **Whooshes** pan by sending through two side buses (`CombatL`, `CombatR`, pan -/+0.35, both feeding `Combat`); successive swings alternate side with a random 0.2 to 0.7 amount. The two buses are not in `BUSES`, so settings and ducking are unchanged.
- **Public API.** `Sfx.play(name, vol_db, pitch, jitter)` still works for every old call (the `jitter` default is now -1 meaning "the pool's own"). New:
  - `Sfx.event(name, intensity = 1.0, vol_db = 0.0, pitch = 1.0, jitter = -1.0) -> bool` for `clash`, `block`, `parry`, `guard_break`, `hit_armor`, `hit_flesh`, `swing`. Intensity 0.1 to 2 scales level (dB of the intensity, clamped), lowers pitch slightly when harder, gates layers, and picks the whoosh weight for `swing` (< 0.6 light, > 1.25 heavy, else medium). Returns false if the retrigger gap swallowed it.
  - `Sfx.footstep(surface = "", weight = 1.0, vol_db = 0.0, pitch = 1.0, jingle = true) -> bool`. Surfaces `stone`, `metal` (`metal deck`), `grass` (`earth`), `snow`, `water` (`shallow`); `""` uses `Sfx.default_surface` (a variable for the scene owner to set). Weight 1 is a normal armoured knight: level +6 dB per unit of weight, pitch x weight^-0.35, an armour jingle layer (about -20 dB under the step) with probability 0.2 + 0.4 x (weight - 0.9), none under weight 0.9. One call plays exactly one step sound (a second call inside 80 ms returns false and plays nothing; at most one jingle layer, in its own family).
- **Old names mapped:** `parry_perfect` to `parry`; `clash`, `block`, `hit_armor`, `hit_flesh`, `guard_break` to events; `swing` / `swing_heavy` to `event("swing", ...)` with the caller's pitch deciding the whoosh weight (>= 1.15 light, < 0.78 heavy, else medium) and then applied as pitch^0.5, because the weight already carries most of what the pitch said; `footstep` to `footstep("", 1.0, vol, pitch, false)` (no jingle, since `fighter_rig.gd` already plays `armor` with each step). `armor`, `roar` and everything else play as before but also never repeat the last variant. No call site was edited.

### Synthesis: `tools/gen_audio_combat.py` (new), `tools/gen_audio_measure.py` (new), `tools/gen_audio.py` (3 small edits)
- Metal: sums of inharmonic partials with free-free bar ratios (a blade) plus a second blade at a different pitch, plate-like ratios for guard/shield, frequency-dependent decay (high partials die faster), beating partner partials, and a noisy 2 to 12 ms attack with a broadband smear; some clashes add a short sliding "shing". Six distinct tunings and lengths.
- Parries: higher base (1.9 to 2.7 kHz), longer ring (1.0 to 1.5 s), air shimmer partials, bright sweep. Blocks: lower, duller, 0.26 to 0.38 s, with built-in body.
- Whooshes: band-swept noise whose centre frequency rises to a peak and then falls faster (Doppler-like arc), asymmetric amplitude, turbulence ripple, an air band an octave up, a faint edge whistle, and a low push on heavy. 9 files, three weights.
- Footsteps: heel thud, toe drop, scuff and a per-surface texture (stone slab resonance; metal deck plate modes and clank; grass rustle and crackle; snow granular crunch and a faint squeak; water splash with rising droplet chirps).
- `gen_audio.py` no longer generates `clash_*`, `block_*`, `hit_*` (their old generators were removed) and calls `gen_audio_combat.build()` at the end of `build_sfx()`. Legacy `swing_1..3`, `swing_heavy`, `parry_perfect`, `guard_break`, `footstep_1..4` are still generated and kept on disk but are no longer played by the engine (they are the fallback if the new pools were ever deleted). I ran `build_sfx()` and `verify()` again: output was byte-identical to the files on disk (md5 of all 142 WAVs), so generation is deterministic.
- Import: one `--headless --import` was run (via `tools/check.sh` and `tools/test.sh`). All new files got their own `.import`; no pre-existing `.import` file changed (checked in git history, because another agent's checkpoint commits had already swept the working tree, so `git status` alone cannot show it any more).

## Measurements

Method (`tools/gen_audio_measure.py`): duration; sample peak; loudness = maximum EBU R128 momentary value from ffmpeg `ebur128` after padding each short file to 1 s (called LUFS-M); spectral centroid = power-weighted mean frequency of the whole file. Within a family files were scaled to a common LUFS-M target chosen near the loudness of the old files (clash -20, block -21, parry -17, guard break -17, hit_armor -21, hit_flesh -17.5, whoosh -17/-16.5/-16.3, steps -20 to -24 by surface), with the peak capped at -2 dBFS; 27 of 79 files hit that cap and sit a little under their target (spread column). Durations include the 4 ms preroll.

| family | files | duration s | peak dBFS | LUFS-M | LUFS-M spread | centroid Hz |
|---|---|---|---|---|---|---|
| clash | 6 | 0.38-0.95 | -2.0 to -2.0 | -22.2 to -20.0 | 2.2 dB | 2080-3774 |
| block | 4 | 0.26-0.38 | -3.4 to -2.0 | -23.2 to -21.0 | 2.2 dB | 266-440 |
| parry | 3 | 1.00-1.50 | -7.4 to -3.5 | -17.0 to -17.0 | 0.0 dB | 3976-5097 |
| guard_break | 3 | 0.90-1.25 | -2.9 to -2.4 | -17.0 to -17.0 | 0.0 dB | 78-122 |
| hit_armor | 4 | 0.38-0.50 | -3.9 to -2.0 | -21.7 to -21.0 | 0.7 dB | 440-886 |
| hit_flesh | 4 | 0.35-0.35 | -3.0 to -2.0 | -17.9 to -17.5 | 0.4 dB | 70-106 |
| whoosh light | 3 | 0.22-0.28 | -3.8 to -2.0 | -17.1 to -17.0 | 0.1 dB | 3169-4370 |
| whoosh medium | 3 | 0.33-0.41 | -3.9 to -2.0 | -17.8 to -16.5 | 1.3 dB | 2244-2561 |
| whoosh heavy | 3 | 0.50-0.72 | -2.0 to -2.0 | -18.3 to -16.8 | 1.5 dB | 613-1693 |
| layer thump | 3 | 0.30-0.30 | -8.7 to -7.5 | -23.0 to -23.0 | 0.0 dB | 69-99 |
| layer crack | 3 | 0.22-0.22 | -2.0 to -2.0 | -29.3 to -25.9 | 3.4 dB | 7117-8223 |
| layer rattle | 3 | 0.55-0.55 | -7.5 to -4.4 | -24.0 to -24.0 | 0.0 dB | 1479-2160 |
| layer swell | 3 | 0.16-0.17 | -10.3 to -7.7 | -24.0 to -24.0 | 0.0 dB | 3595-5398 |
| layer jingle | 4 | 0.26-0.26 | -10.6 to -8.6 | -28.0 to -28.0 | 0.0 dB | 5427-6255 |
| step stone | 6 | 0.26-0.26 | -3.1 to -2.0 | -22.7 to -21.0 | 1.7 dB | 313-437 |
| step metal deck | 6 | 0.38-0.38 | -5.3 to -2.0 | -22.2 to -20.0 | 2.2 dB | 365-543 |
| step grass/earth | 6 | 0.28-0.28 | -8.1 to -5.5 | -24.0 to -24.0 | 0.0 dB | 424-788 |
| step snow | 6 | 0.32-0.32 | -3.8 to -2.0 | -23.9 to -23.5 | 0.4 dB | 2697-3142 |
| step water | 6 | 0.42-0.42 | -8.8 to -6.1 | -22.0 to -22.0 | 0.0 dB | 1080-1559 |

Ordering checks that hold in the numbers: parry (1.0 to 1.5 s, centroid 4.0 to 5.1 kHz) is longer and brighter than block (0.26 to 0.38 s, 0.27 to 0.44 kHz) and than clash (0.38 to 0.95 s, 2.1 to 3.8 kHz); whoosh centroid falls light to medium to heavy.

Distinctness (rms difference of third-octave band levels, dB, between variants of a family; min / mean): clash 5.2 / 8.7, block 5.9 / 8.6, parry 9.1 / 10.5, guard break 6.3 / 7.3, hit_armor 8.2 / 10.3, whoosh light 5.1 / 6.9, medium 3.0 / 3.8, heavy 4.2 / 6.3. Weakly separated spectrally (they differ mostly in timing and fine structure, not in average spectrum): hit_flesh 2.6 / 3.8, snow steps 1.6 / 2.5, water steps 1.3 / 2.4, grass steps 1.4 / 4.6, stone steps 1.9 / 4.3. Whether variants of those families are audibly different is unknown.

## What is unverified
- Nothing has been listened to, on a desktop or on the iPhone. Realism, power, "cheap" or not, whether the whoosh arc reads as a blade, whether the parry is distinct enough from a clash in play: all unknown.
- Perceptual loudness balance between families (clash vs whoosh vs step) is only matched to the old files' loudness; the caller dB offsets in `duel.gd` were left alone.
- iPhone speaker response and the mobile mixer (voice counts, the panner buses) are untested on device.
- Delayed layers (the 30 and 90 ms ones) use scene timers and are frame-quantised.
- Footstep timing against real foot contacts is the other agent's work; this pass only supplies `Sfx.footstep`. No caller uses it yet except through the old `play("footstep")`.
- `tests/tests.gd` `t_sfx` checks the logic (no repeat, polyphony, retrigger gap, one step per call, old names) with the headless dummy audio driver; it cannot check what comes out.

## Proposal for the owner (not acted on, nothing bought or generated)

You said not to buy sound assets without asking, so none were. Credit estimates below come from `higgsfield generate cost` (a no-job estimate) at the SPENDING_LOG rate of about $0.041 per credit; models were inspected with `higgsfield model get`.

Where real recordings or generated samples would help most, in order: **1. clashes and parries** (metal ring is where synthesis is weakest; about 12 clash and 8 parry sounds replace the six and three synthesised ones), **2. footsteps** (5 surfaces x 8 = 40 files), **3. whooshes** (about 12), **4. armour impacts and guard break** (about 12).

Options:
1. **Higgsfield `mirelo_text_to_audio`** (inputs: prompt, duration). Estimate 0.25 credit per second of audio (1 s 0.25, 5 s 1.25, 10 s 2.5), about $0.01 per second. 80 files of about 1.5 s is 30 credits, about $1.25. Cheap enough to try 6 files first (about 2 credits, under $0.10) so you can judge before the rest.
2. **Higgsfield `seed_audio`** (Seed Audio 1.0; mainly a speech and voice model with a prompt; sound-effect quality unproven). Estimate 0.3 to 0.6 credit per job depending on prompt length (about $0.01 to $0.025); output up to 48 kHz WAV. About 80 jobs is 24 to 48 credits, about $1 to $2. One try of each model on one sound is the sensible test.
3. **Free CC0 libraries** (for example Freesound CC0, OpenGameArt CC0, Kenney, Sonniss GDC bundles): $0, real recordings, but each file needs a licence check (CC0 only; CC-BY needs credits in `docs/CREDITS.md`), downloads need the network allow-list opened and your go-ahead, and quality varies. Realistic sword and footstep sets exist but finding and cutting about 80 files by hand is slow.

Whatever is added, the pools and layers here accept it without engine changes: drop `clash_7.wav` etc. in place with 4 ms of leading silence (or skip the offset) and raise the count in `POOLS`.

Recommendation: spend about $0.10 on 6 `mirelo_text_to_audio` clashes and whooshes, and listen to them next to the current set before deciding anything bigger. Total spend even for all 80 files stays under about $3, far inside the $100 cap, but it needs your approval first.

## Opening audio forensics and the audio log (2026-11-28)

Full report: `marketing/audio_pass/opening_audio_forensics.md`. Nobody has listened to the result.

### The audio log (dev only, off by default)
`-- --audiolog=<file>` (read in `Sfx._ready`) writes a tab-separated line for every sound start: game clock (scaled
delta, so a `--fixed-fps` run keeps the game's own time), frame, kind, name or file, bus, volume dB, pitch, who asked
and the calling stack (five frames from `get_stack()`; empty in a release export). Kinds: `pool` (a pooled combat or
footstep variant), `sfx` (a flat sound), `step_gated` (a footstep the step family's 80 ms gap swallowed), `music`,
`music_layer`, `ambience`, `voice` (`Story`, Dialogue bus), `video` (a `CinePlayer` clip; those are muted at -80 dB).
Once a second a `rigs` line names the router's current screen and lists every rig with `footsteps` on (path, walking,
stride amount, speed, visible, mode, duel stepping, last stance-step length). `FighterRig._footfall` names itself in
`Sfx.log_who` before it calls `Sfx.footstep`, so each step line says which figure put a foot down and what it was doing.
Nothing is computed while the flag is off. `tools/dev/audiolog_report.py <log> [slice log]` summarises a log per
slice-bot step or per screen.

Example: `godot --headless --path . --fixed-fps 60 --quit-after 33000 -- --screen=prologue --auto --audiolog=/tmp/a.tsv`
(Generation I with a bot fighting, the years, the arrival, the Engine, the walk out, the first stop). The engine's
retrigger gaps run on wall-clock milliseconds, so a headless run that is faster than real time shows many
`step_gated` lines that a phone would play; count requests, not plays, from such runs.

### What changed
- `src/cine/arrival.gd`: the heir's first walk is the road's own `stride`, and `HighRoad.stride` tweens `s` explicitly
  `from(a)`. Before, the arrival's own tween on `road.s` outlived its walk by a frame and the next shot's walk took its
  start from it: shot 3 ran the walker about 300 m in 12 s (25 m/s) and the feet came down 6 to 7 times a second.
- `FighterRig._footfall`: the step is played at the level the call always had before the pooled engine took it over
  (-6 dB walking, -9 dB in a duel, +3 dB per unit of bulk); since that hand-over it had been passed no level and played
  6 to 9 dB louder, at about the level of a sword clash. No footfall in a figure's first 0.75 s (its feet only catch up
  with where it was put: two or three steps at the start of every duel). The step no longer carries the jingle layer.
- Armour movement: `Sfx.armour(weight, vol_db)` (family `armour`: one voice, 2.5 s gap), called by `_footfall` only on
  the first footfall of a walk that sets off after a second of standing, and at most once every 6 s per figure, never in
  a duel; 20 dB under the step. It uses the `jingle` pool until recorded armour-movement files exist: replace the
  `jingle_N.wav` files, or point `armour()` at a new pool.
