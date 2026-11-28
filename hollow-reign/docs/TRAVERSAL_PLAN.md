# Continuous Courtyard traversal: plan (2026-11-28; steps 1-3, 6, 7 done in Stage 3A, steps 4-5 are Stage 3B)

Owner (after phone play): "we're not really walking ... new monsters just show up ... should be a real story and they come up, not just spawn in."

## Today
- Every courtyard stop rebuilds the same walled court (`Future._court`, src/world/future.gd:564-629) and only turns the camera (`Explore.bearing`, src/ui/explore.gd:33). Between stops the knight walks 3.9-6.2 m (`_walk_then`), then a 0.35 s fade (`main._fade_then`) and a new `Explore`.
- `Corridor.clear` moves or removes props per bearing, so scenery shifts between stops.
- Foes are built already standing on their marker (`_stand_foe`, explore.gd:215-232; approach.gd:60-75); chests/levers appear only when tapped (`_interact`).
- Each fight cuts to a separate `Duel` with its own Arena (duel.gd:275-277).

## Design
One connected `CourtRoute` (~230 m, rising ~8 m): hill causeway → Breach (stop 0) → rubble yard / Guardhouse (1) → Barbican (2) → winch-house (3, checkpoint) → gate passage (4) → chapel alcove (5, checkpoint) → inner ward, Sentinel arena (6). Walked continuously at ROAD_SPEED with a follow camera; no fades or rebuilds; props placed in the level from the start. Foes are spawned out of sight and enter in view (climb the breach rubble, drop from the wall-walk, step out of the barbican door, portcullis raised by the winch, march out of the passage, the Sentinel rises from kneeling). Duels happen in place (Duel adopts the route's Arena and the stop's duel-ring origin). Save v5 unchanged; Retry/Continue place the knight at the anchor of `run.stage`. Courtyard only; other regions keep the stop flow.

## Steps
1. Route data and anchors (tools/gen_regions.py, new src/world/court_route.gd) + test.
2. Build and stream the level (keep current, previous and next sections; merged kit meshes per section). Risk: iPhone memory and draw calls, unmeasured.
3. Continuous Explore (explore.gd, main.gd), gated by region.
4. Foe entrances (new src/world/foe_entrance.gd; clips: climb, drop-land, kneel-rise may need baking from the owned packs or procedural fallback).
5. Duel in place (duel.gd adopts place/origin; walk on after a win).
6. Checkpoint, Retry, Continue, Turn Back.
7. Update tests that assert the stop flow (integration.gd:60/70/185/434, fix_pass.gd:65-225, secrets.gd t_road, tests.gd t_corridor, campaign.gd:131/186/271/314, generations.gd t_checkpoints) and the slice bot (`_stop`, waits on `main.current is Explore`), then a full slice run.
No purchases needed. Missing pieces: climb/drop/kneel-rise clips, a portcullis that slides, a height-field path.

## Additions (owner, 2026-11-28; see MASTER_REQUIREMENTS Addendum 7 §6)
- Witness discovery: found dormant early on the route (an ancient chamber / damaged machine / forgotten shrine off the path, e.g. a side room before the Breach), a visible reason to investigate (its light pulsing, a mechanism), the player wakes it; a short scene explains it was left to watch and why it follows (mysteries held back). Afterwards it follows physically (orbit near the shoulder, flies ahead to points of interest, inspects objects, leads toward optional areas); never appears through the floor or teleports. Replace every existing Witness entrance/exit (grep the stop asides, Companion, witness_drone.gd, the Engine scene) with travel from where it was.
- Exploration: branches with real geometry — optional rooms (guardhouse interior, chapel crypt), stairs to the wall-walk, a bridge over the moat or a ravine, elevation changes, hidden areas behind breakable or levered gates; choices at forks are made in the world (the guided walk goes where you tap), rewards placed in the world (chests, lore objects, optional foes); backtracking to visited places where it makes sense (e.g. the winch shortcut back to the yard).
- Merchant: Orren works in a real workshop at the sanctuary (forge, anvil, racks of weapons and armour, tools, warm light); the shop and forge screens open in that space.
- Consistency audit: list every moment where something appears, disappears or happens without a reason (foes, props, the Witness, cutscene characters, pickups, doors) across the whole slice, then fix each as part of the stages above.

## Stage 3A (2026-11-28): what was built
- `src/world/court_route.gd` (`CourtRoute`): the place, its floors (`FLOORS`: what is drawn is what `ground_y` answers), the
  ways between stops (`LEGS`), where interactions stand (`SPOTS`), streaming (five sections, built a few ms a frame ahead,
  freed two behind; merged by material per section; visibility ranges; box occluders in the walls), the air of each place
  (`AIR`). New shader `court_ground.gdshader` (turf, earth, rock by slope, mapped from three sides).
- Route (main way, about 245 m, 0 m to 8 m; the wall-walk reaches 7.8 m over a 3.2 m yard):
  hillside door z +56 → causeway along the sea cliff (x up to 10.5, the cliff at 15-21) → ravine bridge z -34..-52
  (the falls off the west hill and over the sea cliff) → terrace, **stop 1 the Breach** (z -68, 3.0 m) → over the rubble
  → **stop 2 the rubble yard** (z -92, 3.2 m): left the guardhouse (a room, the chest inside), right the stair to the
  wall-walk (7.8 m) and down into the forecourt; both rejoin → **stop 3 the barbican forecourt** (z -116.5, 4.5 m) →
  through the barbican → **stop 4 the winch yard** (z -141, 5.5 m): the winch-house, the well, the postern of the lane back
  down to the yard (the winch gate: the shortcut) → **stop 5 the inner gate** (z -152) → the gate passage (the murder hole
  off it through a gap: the hidden room) → **stop 6 the chapel court** (z -184, 6.2 m) → nine steps → **stop 7 the inner
  ward** (z -206, 8.0 m) under the keep.
- Hooks: `CourtRoute.ENTRY` / `_entry_door` (Stage 1's chamber exit), `witness_hook`, `foe_spots` and `gates` (Stage 3B).
- Not done here (3B): foe entrances, duels in place, bodies remaining, animated props with sound (the portcullises only
  slide up on a tween when the winch is turned).
