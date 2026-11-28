# Opening audio forensics (2026-11-28)

The owner, after playing on an iPhone: a "horrible shuffling sound" at the beginning of the game, "like 50 Minecraft
characters walking at once", later also in the tutorial fight. This is what the game was measured to play, where it
comes from, and what was changed. **Nobody has listened to any of it, before or after.** Nothing here has run on a
phone. Sound files were not changed.

## Method
A dev-only audio log (`-- --audiolog=<file>`, documented in `docs/AUDIO_NOTES.md`) records every sound start in
`src/core/sfx.gd` (pools, flat sounds, music, music layer, ambience, swallowed footsteps), every voice line
(`src/core/story.gd`) and every video clip (`src/cine/cine_player.gd`). Those are the only places the game creates
or starts audio players: a search of `src/`, scenes and resources found no other `AudioStreamPlayer` (2D or 3D),
generator or animation audio track. Each footstep line names the rig, whether it was walking, its stride amount,
speed, visibility, mode, and the length of its last stance step. Once a second the log lists every rig with footsteps on
and the current screen.

Runs (all logs in the session scratchpad, not committed):
1. The slice bot under xvfb at a fixed 30 fps, writing a movie so the mixed output could be measured: launch, menu,
   character select, sword, Generation I beats 1 and 2 (stopped there: about 14 times slower than real time).
2. `--screen=prologue --auto` headless at a fixed 60 fps, 550 s of game time: Generation I with a bot fighting both
   duels, the time jump, the arrival, the Engine, the Approach and 258 s standing at the first stop. Run before and
   after the fix.
3. The slice bot from the road (`--road=0`): stop 1 and its first fight, stop 2.
4. Duels headless with the sim's bot (`--demo=throne_guard` and `--demo=hollow_soldier`, 60 s each) and the lesson
   duel with nobody touching it (`--screen=lesson`, 60 s). Before and after.
5. `--screen=arrival` alone, and its shots 3 and 4 held, before and after.

The engine's retrigger gaps use wall-clock milliseconds, so a headless run faster than real time swallows steps a phone
would play. Counts below are requests (what the rigs asked for); "real-time playable" re-applies the 80 ms step gap on
the game clock.

## Timeline, before the fix

| Part | Length | Step requests | Peak in any 1 s | Gaps under 0.3 s | Rigs with footsteps on at once | Armour layer | Step level |
|---|---|---|---|---|---|---|---|
| Launch, menu, character select | 11 s | 0 | 0 | 0 | 0 | none | |
| Generation I, the road (one walker) | 63 s | 84 (1.34/s) | 2 | 0 | 1 | none | -0.3 to -2.2 dB |
| Generation I, the hall | 32 s | 18 | 2 | 0 | 1 | 1 scripted `armor` | |
| Generation I, both duels and the fall | about 85 s | about 120 over 8 rigs | 7 (two fighters) | about 55 | 2 | 2 scripted `armor` | -1.6 dB median |
| Time jump | 10 s | 0 | 0 | 0 | 0 | none | |
| **Arrival (the heir's walk up the road)** | 51 s | **110** | **7** | **54** | 1 | none | -0.8 dB median |
| Awakening at the Engine | 37 s | 15 | 2 | 0 | 1 | 1 scripted `armor` | |
| Approach | 10 s | 15 | 2 | 0 | 1 | none | |
| First stop, standing | 258 s | 1 | 1 | 0 | 1 | none | |
| Lesson duel, nobody touching | 60 s | 2 (both in the first 0.4 s) | 2 | 1 | 2 | none | -2.8 dB |
| Ordinary duel, bot fighting | 60 s | 31 to 44 (+3 in the first 0.6 s) | 5 to 6 | 16 to 20 | 2 | none | -1.8 to -2.1 dB |

Every step line came from `FighterRig._footfall`, called from the feet passes (`_feet_walk` for walking, `_feet_step`
for stance steps). No step came from a hidden rig, from a rig left over from an earlier scene, from the stride-phase
fallback, from a timer, or from `Duel`'s `player_advance` footstep (that event did not happen in these runs). No two
systems played a step for the same foot. The `jingle` armour layer never played (the rigs' weight never reached the
0.9 it needs). The ambience (wind, crypt) and music start once per scene and never doubled.

## Findings

### 1. The arrival's walker ran at 25 m/s for nine seconds (proven, fixed)
At the start of Generation II, shot 3 of `Arrival` (about 13.5 s to 22.5 s into the scene) the walker's speed in the log
was 24.6 to 26.5 m/s, against 1.0 to 1.3 m/s in every other shot. The feet kept to the stride, so footfalls came every
0.13 to 0.2 s, limited only by the rig's own 0.12 s guard: 6 to 7 a second (log lines 204.1 s to 213.1 s of the chain
run; 54 of the scene's 110 requests were under 0.3 s apart). Reproduced alone with `--screen=arrival`.

Cause: `Arrival._run` walked the knight with its own tween on `road.s` for 6.5 s and then called `road.shot(3)` after
6.4 s. `HighRoad.stride` kills only the road's own walk tween, so the arrival's tween wrote `s` once more before the new
walk's first step, and `tween_property` takes its start value at that first step: the new walk started from s = 37 m
instead of its own start and covered about 300 m in its 12.5 s. Holding shot 3 alone (`--shot=3`) did not show it,
which is why it was missed.

### 2. Footsteps played 5 to 9 dB louder than they were set up to (proven, fixed)
`FighterRig._footfall` passed no level to `Sfx.footstep`, so the step played at 0 dB plus the weight term: -0.3 to
-2.2 dB on the Combat bus, about the level of a sword clash. The same call's own fallback (`Sfx.play("footstep", ...)`)
and the call before the pooled engine took footsteps over used -6 dB walking and -9 dB in a duel. Measured in the
xvfb movie above 400 Hz on the Generation I road, the steps were still about 8 dB under the rest of the mix there (the
narration dominates), so this alone does not make a flood; with nothing being spoken they were the loudest
transient on screen.

### 3. Duels: footwork is real foot movement, not idle shuffling (measured, one start artefact fixed)
Stance steps in duels had a median length of 0.3 to 0.5 m (4 of 81 under 0.15 m), at 0.2 to 0.45 requests a second per
fighter, about 0.5 to 0.8 a second for the pair. The busiest second (7 requests) was the Generation I guardian
circling at 0.5 to 0.7 m/s with 0.5 m steps while the forebear recovered from a stagger. The lesson with nobody
touching it made no steps after its first 0.4 s. The defect found: two or three footfalls at the start of every
duel (and of the lesson), in the first 0.6 s, as the feet caught up with where the figures had just been placed.

### 4. Steps while standing still
None from a figure that was standing. The 11 Generation I steps logged at under 0.05 m/s are each the closing step
of a walk (a foot brought in 0.2 to 0.56 m as the figure stops), or a step at the end of a stagger.

### 5. Armour movement
There was no constant armour layer: the jingle never played and the `armor` one-shots are scripted moments in the
story scenes (4 in the whole opening). The armour was therefore silent on walks, not rattling.

## What changed
- `src/cine/arrival.gd`: the arrival's walk is `road.stride(...)`, so the next shot's stride stops it.
- `src/cine/high_road.gd`: `stride` tweens `s` `.from(a)`, so no other writer can move a walk's start.
- `src/chars/fighter_rig.gd`: `_footfall` passes the old levels (-6 / -9 dB, +3 dB per unit of bulk), no jingle on the
  step, no footfall in a figure's first 0.75 s, and an occasional armour settle (below). Dev-only log fields.
- `src/core/sfx.gd`: `armour(weight, vol_db)` (family `armour`, one voice, 2.5 s gap; the `jingle` pool 20 dB under
  the step until recorded files replace it); the audio log.
- `src/core/story.gd`, `src/cine/cine_player.gd`: one log line each when the flag is on.
- `tests/tests.gd`: one new check, `Sfx.armour` is never heard twice inside its gap. No existing test was changed.
- `tools/dev/audiolog_report.py`: the summary script.

## After the fix (same runs)

| Part | Step requests before → after | Peak in 1 s | Gaps under 0.3 s | Step level (median) | Armour settles |
|---|---|---|---|---|---|
| Generation I (road, hall, duels, fall) | 222 → 215 | 7 → 7 | 55 → 51 | -1.6 → -7.9 dB | 0 → 3 in 179 s |
| Arrival | 110 → 74 | 7 → 3 | 54 → 2 | -0.8 → -6.8 dB | 0 → 0 or 1 |
| Arrival alone (`--screen=arrival`, 40 s) | 92 → 56 | 7 → 3 | 54 → 1 | | |
| Awakening | 15 → 15 | 2 → 2 | 0 → 0 | -1.5 → -7.1 dB | 0 → 1 |
| Approach | 15 → 15 | 2 → 2 | 0 → 0 | -1.1 → -7.4 dB | 0 |
| Lesson, nobody touching (60 s) | 2 → 0 | | | -2.8 → (none) | 0 |
| Guardian duel, bot (60 s) | 47 → 45 | 6 → 6 | 20 → 19 | -1.8 → -11.3 dB | 0 |
| Hollow Soldier duel, bot (60 s) | 34 → 31 | 5 → 5 | 18 → 17 | -2.1 → -11.6 dB | 0 |

The arrival walker's speed in shot 3 after the fix: 1.10 to 1.34 m/s. Duel and Generation I runs are bot-fought and
not identical between runs. Armour settles are undercounted in fast headless runs (their 2.5 s gap is wall-clock).

## What could not be determined
- What the owner's iPhone build was built from. If it predates the 2026-11-27 footfall pass (BUG_REGISTER T6) it
  had two sounds on every half stride; nothing here can tell.
- Whether anything sounds like shuffling. No source in the log produced dozens of simultaneous steps: at most two rigs
  had footsteps on at once, and at most 7 step requests fell in any second (the arrival defect, and two fighters
  together). If the owner still hears a crowd after this build, the remaining candidates are inside sound files, which
  this pass did not touch: each synthesised step is a heel and toe noise burst plus a scuff (three short noise events,
  mostly noise above 400 Hz once a phone speaker loses the thud), and the wind ambience (title, Generation I road,
  Courtyard, duels) is band-passed noise whose 4 to 10 kHz band fluctuates by about 12 dB at 4 to 32 Hz. Those are for
  the recorded-sound pass and for a listener.
- `Duel`'s `player_advance` event plays `Sfx.play("footstep")` while the rig steps in on its own feet; that would be
  two systems for one step, but the event did not occur in any run, so it is not proven and was not changed.
- The slice bot's own run under xvfb was stopped at Generation I beat 2 for time; the later parts come from the headless
  chain, which uses the same scenes but a bot instead of synthetic touches.
