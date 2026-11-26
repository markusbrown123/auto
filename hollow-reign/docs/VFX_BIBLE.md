# VFX bible

All combat effects come from one pooled node, `Fx` (`src/fx/fx.gd`), created by the duel in `setup`.
Emitters and lights are created once and re-triggered; a hit allocates nothing after the first use of its kind.
Every count below is the maximum; it is multiplied by `Game.particle_scale()` (0.5 Performance, 0.8 Balanced, 1.0 High)
through `Fx.pscale()`. Rule for every effect: it starts at the contact point, it is small, and it is gone before the
next exchange, so it never covers the fighters.

## Sword trail

| | |
|---|---|
| File | `src/chars/fighter_rig.gd` (`_build_trail`, `_update_trail`), material `Fx.ribbon_material()` |
| Trigger | every frame while the rig is in `STRIKE` or `THRUST` (`is_striking()`) |
| Shape | two camera-facing ribbons: one on the path of the blade tip, a thinner fainter one at 70% of blade length; Catmull-Rom between samples so a 30 fps arc is still a curve |
| Life | samples older than 0.12 s are dropped, so nothing is left 0.12 s after the swing ends |
| Width | 5.5 cm at the head (8 cm for two-handed weapons or rigs scaled above 1.3), tapering to zero at the tail; capped at 0.9% of the distance to the camera so a blade passing the lens cannot become a band |
| Alpha | 0.55 (0.7 heavy) at the head, falling with the square of age, and reduced when the tip moves faster than 10 m/s; additive, unshaded |
| Colour | steel-white (0.82, 0.87, 0.94); blades with a glow lean 60% toward their glow colour |
| Budget | at most 24 samples, 2 strips, about 290 triangles per fighter while swinging |

## Contact effects

| Effect | Trigger (file `src/combat/duel.gd`) | Origin | Direction | Max count | Life |
|---|---|---|---|---|---|
| Parry sparks | `_on_strike`, result `parried` | `meet`: the point 72% along the foe's blade | `_deflect_dir`: against the blow's travel across the screen, up, slightly away from camera | 24 | 0.34 s |
| Perfect-parry sparks | same, `d.perfect` | `meet` | same | 40 | 0.34 s |
| Block sparks | result `blocked` | `meet` | same | 7 (10 for a heavy blow) | 0.34 s |
| Guard-break sparks | result `guard_break` | `meet` | same | 16 | 0.34 s |
| Player struck | result `hit` | player's chest | same | 12, dark red | 0.34 s |
| Player's cut lands | `boss_hit` | `_cut_point`: the foe's torso surface on the side the player's blade is on | along the cut, toward the camera | 10 (16 on a critical or rift cut) | 0.34 s |
| Deflected cut | `deflected` | middle of the foe's blade | up and back | 8 | 0.34 s |
| Blade glint (tell) | wind-up, 0.32 s before the blow | foe's blade tip | up | 3 | 0.34 s |
| Surge / phase change / finisher bursts | `surge`, `phase_change`, finisher | foe's chest | up | capped at 40 by `Fx.MAX_SPARKS` | 0.34 s |

Sparks are streaks (two crossed tapered quads, 13 cm x 2 cm, turned to their velocity), additive, warm metal
(1.0, 0.82, 0.5) cooling to orange-red, gravity 9.8 m/s2, spread 24 degrees, speed 45-100% of the given speed.
Each burst also fires one pooled omni light (two in the pool, no shadows, range 3 m, 0.16 s).
Pool: 4 spark emitters.

| Effect | Trigger | Origin | Max count | Life |
|---|---|---|---|---|
| Dodge dust | `player_dodge` | ground under the player | 5 | 0.75 s |
| Roll dust | `player_roll` | ground under the player | 8 | 0.75 s |
| Push-back dust | `blocked` (4, heavy 7), `guard_break` (8), `hit` (4, heavy 7) | ground under the player | 8 | 0.75 s |
| Stagger dust | `boss_stagger` | ground under the foe | 7 | 0.75 s |
| Slam chips | `_on_strike` when `attack.kind == "slam"`, whatever the result | ground under the foe's blade tip | 10 chips + 7 dust | 0.65 s |

Dust is soft billboards (34 cm growing to 44 cm), alpha-blended, peak alpha 0.13, coloured from the arena floor.
Chips are small lit boxes in the floor colour, thrown up 1.8-4.4 m/s under 12 m/s2 gravity.
Pools: 3 dust emitters, 2 chip emitters.

## Elemental effects

Triggered in `_on_strike` when the foe's attack data has `element` (any result except a dodge), at `meet`
(or the player's chest if the blow landed); and in `boss_hit` when the player's weapon has an element.

| Element | Effect | Max count | Data that triggers it today |
|---|---|---|---|
| `fire` | rising embers (additive dots, 0.65 s) + orange light, 0.3 s | 12 | boss attacks with `"element": "fire"`, fire weapons |
| `frost` | ice chips (pale streaks, 0.45 s) + a cold mist puff + pale blue light | 10 + 4 | boss attacks with `"element": "frost"`, frost weapons |
| `rift` / `ancient` / `arc` | 3 thin jagged arcs, redrawn each frame for 0.14 s, + cyan light | 3 arcs (4 max), 36 triangles | a rift cut (`boss_hit` with `rift`) |
| `drain` / `corruption` / `void` | dark violet motes drawn inward, alpha-blended (not additive), 0.8 s | 12 | the Devourer's `drain` status |

No attack in `data/bosses.json` or `data/items.json` carries an `ancient` or `corruption` element yet; those
two effects are reachable only through the rift cut and the drain status.
Pools: 2 emitters each for embers, ice, motes; one arc mesh.

## Ambient life (`src/world/arena.gd`, `_particles` / `_ambient` / `fire`)

Budget: **150 live ambient particles per arena**, flames included (`Arena.PARTICLE_BUDGET`, enforced by `_allot`),
before the particle multiplier.

| Region | Emitters (max count) | Flames (10 each) | Total |
|---|---|---|---|
| Courtyard | dust motes 40 | 2 braziers | 60 |
| Blackwood | falling leaves 34, motes 40 | - (lanterns are lights only) | 74 |
| Cathedral | ash 60, embers 50 | - (censers are lights only) | 110 |
| Crypt | motes 40, ground mist 14 | - (candles are lights only) | 54 |
| Roost | embers 50, ash 60 | 3 braziers | 140 |
| Citadel | snow 110 | 4 braziers (cold flame) | 150 |
| Deep | spores 55, motes 40 | - | 95 |
| Throne | motes 40 | 4 braziers | 80 |
| Sanctuary | motes 40 | 3 | 70 |

- **Firelight flicker:** every fire-coloured light (`fire()`, `_brazier()`, `_glow()` in the theme's fire colour) is
  modulated by three summed sines in `Arena._process` (about +-20% energy).
- **Vegetation:** grass tufts sway in `grass_sway.gdshader` (Courtyard 420 tufts, Blackwood 380).
- **Phase stain:** `Arena.tint()` leans fog and ambient toward the foe's eye colour on a phase change (existing).

## Not built

Dragon breath as a volume (the gout is still the rig's own geometry), footstep dust on ordinary steps (only
rolls, dodges, push-back and staggers raise dust), blood, weapon-specific impact shapes, environmental
destruction, weather beyond snow, cinematic-only effects, and screen-space effects of any kind.
