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
| COMBAT | default | class row; fov −5 when the foe has backed off (`b_far`) | 6 |
| GUARD | foe winding up a slam, sweep, breath, or any blow of 30+ damage | back +0.45, side +0.1, y −0.08, fov +4 | 4 |
| OPENING | `sim.boss_open()` (recovering or staggered) | back −0.35, side +0.55, y +0.12, fov −5; aims at 0.82 × H, 0.3 m in front of the foe | 3.5 |

Modifiers on all three:
- **exchange** (`cue("exchange")`, on a landed cut, a block, or a hit taken): 0.7 s of back −0.18, fov −2.5.
- **reposition** (`cue("reposition", {t, amt})`, sidestep 0.7 s at 0.9, roll 1.0 s at 1.0): the move shot, below.
- **keep the knight in frame**: if the middle of the knight's body would pass 92% of the half-width of the view, the aim turns toward them by the excess. In a move the limit comes in by the body's own half-width (atan(0.85 m / distance)), and it is applied to the eased pose as well, so the aim cannot trail a fast body out of the frame.

## The move shot: rolls and sidesteps

What the player sees when the knight sidesteps (1.25 m) or rolls (2.55 m): the knight whole, at a readable size, at the left of the frame for the whole move; the foe and its blow in the middle of the frame for the whole move; one eased turn of the camera about the duel that starts with the knight and ends with them; then the close combat framing eases back. Rules, timing and distances are the sim's and the duel's and are unchanged.

How it is made (all in the base shots, so GUARD and OPENING get it too):

- **The knight goes round the circle they stand on** (`Duel._footwork`): `p_side` is an arc about the arena's centre, not a tangent, and it is paid out at the pace of the clip being played (`FighterRig.carry_step`) instead of 14/s. The rig's origin and the body are then the same place, a roll's 2.55 m is 2.55 m of ground, and nothing curls back in toward the line afterwards.
- **One turn, critically damped** (`CamDirector.axis`, called from `Duel._footwork`): `ring_cam` goes to the angle the line between the fighters will have when the move in hand is over (`ring + (p_side + p_side_owed) / radius`), smoothing time `AXIS_TIME` 0.34 s (×1.6 with `reduce_motion`). No step in speed at the start, never past the target. A sidestep turns the camera 45–57°, a roll 66° (dragon) to 117° (man-sized foe): the pair stand on a line through the arena's centre, so the line turns by distance / radius.
- **Station.** The class row in the frame of `ring_cam` (it no longer chases `p_side`). On top of the eased pose, not eased itself: 0.85 × how far sideways the knight's hips really are from the line in that frame, beyond a 0.15 m dead band (0.4 with `reduce_motion`). A quick sidestep gets ahead of the turn (up to 30°); the lens goes most of the way with it, so the knight is seen to cross a little of the frame but not as far as the foe.
- **Stand-off.** The lens is kept at least `_floor` metres across the floor from the knight's hips (their real place, read from the skeleton), by moving away from them and out to the sword side in equal parts (straight back would bring the knight in front of the foe). `_floor` = REST_MIN 1.5 m at rest, rising with smoothstep(`_wide`) to max(MOVE_MIN 3.2, 1.3 × the distance at which the frame's lower edge meets the floor + 0.6). At 3.2 m a standing knight is about 0.6–0.7 of the frame's height with the feet in frame; mid-tumble about 0.3. Applied to the target and again to the eased pose, so the pose ease cannot trail the knight into the lens.
- **Aim and lens.** The aim comes down to 0.1 m under the lens's height (so the floor under the knight is in frame with a short step back instead of a long one; the foe is tall enough to stay in), fov +4, pose ease rate 6 → 12. `_wide` rises at 6/s to the cue's `amt` and falls at 2/s; it is held up for as long as the rig is in its dodge state (a roll in slowed time outlasts the cue).
- **Keep-out** (`KEEP_OUT` 0.9 m): after everything else, if any joint of either fighter, a weapon's point or a shield is within 0.9 m of the lens, the lens backs away from it and rises.
- **`reduce_motion`**: slower turn (×1.6), no fov change, a shorter step back (+0.4 instead of +0.6), less sideways follow; all ease rates ×0.6 as elsewhere. The turn itself cannot be made smaller: the camera has to end on the sword side of the new line.
- **The line of action** is measured between the fighters' real places (hips), not their nominal ones.

`--oldrollcam` (dev) films the camera, the footwork and the roll's body placement as they were before this pass. `--camlog=<file>` writes one CSV line a frame of the fight: nearest joint to the lens, the knight's box on screen, share of the knight's joints in frame, share of the foe's joints in frame and not behind the knight's box, the knight's angle from the camera's axis, camera speed and turn rate, fov. `--side=L|R` makes the `--showcase=dodge|roll` driver always go one way; `--calm` turns Reduce motion on.

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
- `--oldrollcam`, `--camlog=<file>`, `--side=L|R`, `--calm`: see "The move shot".

## The traversal camera (2026-11-27, `docs/MASTER_REQUIREMENTS.md` Addendum 5 items 3 and 5)

Nothing here has run on a phone; stills and recordings are from the software renderer.

- **A walk has a camera of its own** (`Explore._follow_cam`): behind the knight and to the sword side, 1.3 m high rising to
  1.65, 3.5 m back drifting to 4.4 and from 1.4 m to the side to 0.5 as the walk goes on (a slow arc round and up), looking
  2.8 m ahead of them so there is room in front for the road, 46 degrees. It is the Backdrop's eased glide (`cam_speed` 1.7),
  never a cut, and the knight turns onto the line to the marker over the first 30% of the walk, so a bend is an arc.
  Reduce motion: the offsets are fixed (no arc, no rise) and the Backdrop's idle drift is already off.
- **Arrival at a stop** glides onto the road's view from the last stop's bearing starting slowly (`cam_speed` 0.55, to 1.6 over
  5 s); with Reduce motion it is set at once.
- **Interactions** (chest, shrine, lever) are framed from where the prop stands, which is now to the side of the line to its
  marker, so the walk on afterwards goes past it and not through it.
- **No clipping:** the camera stays within the walking corridor's lane (it starts 5.5 m behind the knight, where the lane
  starts, and stays within 1.5 m of the line), and the corridor is kept free of props (see GRAPHICS_BIBLE "Walking corridor").
- **Not done (src/cine is not this pass's):** the Approach's three set-ups and the Generation I road's six shots
  (`HighRoad.shot`) are unchanged; they cut between shots, which is their design.

## The continuous Courtyard's road camera (Stage 3A, 2026-11-28)
`Explore._route_cam` while the knight walks between stops (`src/world/court_route.gd`): behind and to the sword side,
(1.05 → 0.75, 1.55 → 1.7, 3.9) m in a frame that turns with the walker but late (its yaw follows the knight's at a rate of 1.4/s,
so a corner is a slow arc, never a swing), looking 3.2 m ahead at 1.25 m, 48 degrees, the Backdrop's eased glide (`cam_speed` 2.4).
Heights follow the knight (stairs, the wall-walk) through the glide. Obstruction: `CamFollow.clear_from` (Stage 2's) pulls the lens in
toward the head in front of whatever would come between (the guardhouse walls, the passage, the murder hole), quickly (rate 7), and
lets it back out slowly. Arriving at a stop the camera glides (0.8 → 1.6 over 3 s) to the stop's own view (`Explore.CAM_POS`
in the stop's frame). Interactions walk the knight to the thing and frame it from the side it was approached from, pulled in front
of any wall. Reduce motion: no drift of the offsets. Nothing here has run on a phone.
