# Camera bible — the duel

Code: `src/combat/cam_director.gd` (`CamDirector`). `Duel._camera()` only calls `director.update(delta, _trauma, _clock)`; events ask for shots with `director.cue(name, params)`.

## Principles

- **Ring frame.** Every shot is written with the knight at +Z, the foe at −Z facing +Z, and +X the knight's sword side. The finished pose is rotated by `Basis(UP, duel.ring_cam)`, so all shots turn with the fight as it circles.
- **One side of the line.** The camera is always on +X. The knight is screen-left, the foe screen-right or centre, in every shot including the reverse. In the fight, the camera's X is clamped to at least 0.7 m on the sword side of the line between the fighters.
- **Flank, low, looking up.** The combat camera stands beside and a little behind the knight, below shoulder height. The knight is a cropped foreground figure at the left edge with the sword arm in frame; the foe is centred and seen whole.
- **Eases in the fight, cuts in the cinematics.** Shot changes are hard cuts only in the INTRO, FINISHER and DEATH stages. In FIGHT every change is an exponential ease, so timing stays readable. The intro eases (rate capped at 3 for 1.4 s) into combat framing: no pop when the fight starts.
- **Limits.** Camera is kept within 6.4 m of the arena's centre (some arenas stand scenery from about 7 m) and at y ≥ 0.25.
- **Settings.** `reduce_motion`: no clash punch-in, no exchange tightening, no drift inside cinematic shots, all ease rates ×0.6. `shake`: scales trauma shake as before (0.16 m, 0.035 rad roll at full trauma).
- **Standing distance.** `Duel.KEEP_CLOSE = 0.25`: while prowling the foe keeps a quarter of its authored stand-off (`footwork.keep`), so the pair stand at about `gap` + 0.1–0.3 m. Sim rules and data are unchanged.

## Classes of foe (`CamDirector.CLASS`)

Chosen per fight: `dragon` if the rig is a `DragonRig`; `giant` if scale ≥ 1.3 or cls is Heavy/Giant; otherwise `humanoid`.

| class | side (m) | back (m) | height y (m) | fov | aim height | wide factor |
|---|---|---|---|---|---|---|
| humanoid | 1.9 | 0.7 | 1.0 | 54 | 1.05 × H | 1.0 |
| giant | 1.85 | 0.9 | 0.85 | 60 | 1.0 × H | 1.0 |
| dragon | 2.6 | 1.2 | 0.6 | 54 | 0.55 × H | 1.5 |

`side`/`back` are measured from the knight's feet; H = 1.4 × scale × (1 − 0.3 × hunch). `big` = scale × wide factor and sizes every cinematic shot, so dragons get wider versions of all of them. Giants: lower, steeper, wider lens. Dragons: furthest out and lowest, aimed at the head and forequarters so head, claws and wings are in frame.

## Base shots (chosen every frame from the sim, priority 0)

| shot | when | numbers (relative to the class row) | ease rate |
|---|---|---|---|
| COMBAT | default | class row; +0.6 × sidestep offset in X; fov −5 when the foe has backed off (`b_far`) | 6 |
| GUARD | foe winding up a slam, sweep, breath, or any blow of 30+ damage | back +0.45, side +0.1, y −0.08, fov +4 | 4 |
| OPENING | `sim.boss_open()` (recovering or staggered) | back −0.35, side +0.55, y +0.12, fov −5; aims at 0.82 × H, 0.3 m in front of the foe | 3.5 |

Modifiers on all three:
- **exchange** (`cue("exchange")`, on a landed cut, a block, or a hit taken): 0.7 s of back −0.18, fov −2.5.
- **reposition** (`cue("reposition", {t})`, dodge 0.7 s, roll 1.0 s): back +0.7, side +0.25, y +0.1, fov +3; eases out at 5, back at 2.
- **keep the knight in frame**: if the knight would pass 92% of the half-width of the view, the aim turns toward them by the excess.

## Cued shots (FIGHT)

| shot | cue | priority | length | numbers | rate |
|---|---|---|---|---|---|
| CLASH | `cue("clash", {at, perfect})` on a parry | 4 | 0.30 s (perfect 0.40 s) | from COMBAT, position 28% (perfect 36%) of the way to the contact point, aim 45% toward it, fov −6 (−8) | 16 in, base rate out |
| PHASE | `cue("phase")` on `phase_change` | 3 | 1.5 s | foe + (0.8 + 0.4·big, 0.3, 1.2 + 0.9·big), aim 0.95 × H, fov 54, roll 0.05 | 4.5 |
| STRUGGLE | `cue("struggle", {on: true/false})` | 5 | until `on: false` | midpoint at blade height (1.15 m) + (2.1 + 0.7·big, −0.15, 0.45), fov 48, roll −0.03 | 5 |

| STORY BEAT | `cue("story_beat", {on})` from `Duel._story_beat` | 5 | until `on: false` | the OTS shot, eased | 3 |

A cue replaces the active one only if its priority is equal or higher. When a cue ends the base shot eases back.

## Intro (cuts)

Silent intro (4.6 s, unchanged, tap to skip unchanged): ESTABLISH 0–1.3 s, REVEAL_LOW 1.3–2.6, CLOSE_UP 2.6–3.6, OTS 3.6–4.6, then the fight eases to COMBAT.

Spoken intro (as long as the scene): ESTABLISH 0–2.4 s, REVEAL_LOW 2.4–4.6, CLOSE_UP 4.6–6.4, then OTS while the foe speaks and REVERSE while anyone else speaks (minimum 1.6 s per shot); `cue("reveal", {t: 1.7})` returns to REVEAL_LOW for the roar before the fight.

| shot | numbers |
|---|---|
| ESTABLISH | (3.0 + 0.9·big, 1.7 + 0.6·big, knight.z + 2.2 + 0.7·big), aim at the midpoint 0.55 × H up, fov 56, drifts in 0.22 m/s |
| REVEAL_LOW | foe + (0.7·big, 0.3, 1.4·big + 0.35), aim 0.9 × H, fov 48, roll 0.04, rises 0.12 m/s |
| CLOSE_UP | foe's head bone + (0.8·big, 0.1·big, 1.25·big), fov 32, pushes in 0.1·big m/s |
| OTS | knight + (0.62, 1.5, 1.05 + 0.25·(big − 1)), aim foe at 0.9 × H, fov 46 |
| REVERSE | foe's head + (0.55·big, 0.15·scale, −0.45·scale), aim knight at 1.25 m, fov 44 |

## Finisher (3.4 s, cuts) and victory

| shot | time | numbers |
|---|---|---|
| FINISH blow | 0–1.25 s (the blow lands at 0.75) | side-on: midpoint + (2.3 + 0.9·big, 0.9, 0.5), fov 46, pushes in 0.25 m/s |
| FINISH fall | 1.25–2.4 s | foe + (1.5·big, 0.3, 1.7·big), aim 0.55 × H, fov 52, roll 0.06 |
| VICTORY | 2.4 s on, held through the DONE stage | knight + (1.0, 0.9 + 0.3t, 2.3 + 0.15t), aim 55% of the way to the foe at 0.9 m, fov 50 |

## Death (3.0 s, cuts)

| shot | time | numbers |
|---|---|---|
| DEATH fall | 0–1.2 s | knight + (2.5, 0.4, 1.3), aim 30% toward the foe at 0.8 m, fov 52, roll −0.05 |
| DEFEAT | 1.2 s on, held through DONE | knight + (0.9, 0.3, 1.9 → 1.54), aim foe at 0.8 × H, fov 40 (long lens so the foe looms), roll 0.03 |

Training and lesson duels end without a finisher and stay on COMBAT.

## Priority summary

reveal 6 (intro only) › struggle 5 = story_beat 5 › clash 4 › phase 3 › base state (opening › guard › combat) with exchange/reposition as modifiers. Stage shots (intro, finisher, death) ignore fight cues.

## Dev hooks (capture only)

- `HR_CAM="side,back,y,fov,look_h,look_x"` overrides the class row.
- `HR_CAM_DEV="shot=struggle"` holds a shot during the fight; `kill@3` / `die@3` leaves the foe / knight on 1 hp three seconds in, to film phase changes, the finisher or the death.
- `HR_CAM_SEEN=1` marks the foe's spoken intro as seen, to film the silent intro.
