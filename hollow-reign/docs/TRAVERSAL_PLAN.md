# Continuous Courtyard traversal: plan (2026-11-28, not started)

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
