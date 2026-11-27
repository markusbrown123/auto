# Performance report

**Every number in this file comes from a desktop software renderer** (Godot 4.6 Mobile rendering method on
lavapipe / llvmpipe under Xvfb, 1280x720, `--fixed-fps 30`, Balanced preset). **None of it is a device measurement.**
Nothing has run on an iPhone; frame rate, thermal behaviour and memory on a real device are unknown.
What these counters are good for is comparing one build against another: draw calls, primitives and video memory
are reported by the engine (`RenderingServer` info, printed by `tools/shoot.sh`) and do not depend on how fast the machine is.

## Graphics pass (2026-11-26): before and after

Bot-played duel per region (`tools/shoot.sh <dir> 4,9 --demo=<foe> --skip_intro --bot=3`), average of the frames at
t = 4 s and t = 9 s. "Primitives" is what the engine submits in a frame, shadow pass included, which is why it is
higher than the visible triangle count.

| Region | Draw calls before | after | Primitives before | after | change | Video mem MB before | after |
|---|---|---|---|---|---|---|---|
| Courtyard | 132 | 133 | 562,744 | 548,530 | -2.5% | 351 | 351 |
| Blackwood | 157 | 154 | 805,670 | 758,220 | -5.9% | 350 | 350 |
| Cathedral | 118 | 125 | 343,597 | 360,150 | +4.8% | 250 | 250 |
| Crypt | 126 | 128 | 382,218 | 379,330 | -0.8% | 266 | 266 |
| Roost | 118 | 121 | 360,150 | 336,533 | -6.6% | 254 | 254 |
| Citadel | 118 | 126 | 347,043 | 346,387 | -0.2% | 266 | 266 |
| Deep | 122 | 121 | 339,859 | 339,787 | -0.0% | 250 | 250 |
| Throne | 127 | 133 | 373,652 | 373,578 | -0.0% | 266 | 266 |

Reading the table:

- **Primitives went down or stayed level in seven regions.** The reduction comes from one change: scenery more than
  27 m from the ring no longer casts shadows (`PropModel.scenery`), which removes its second draw. The Blackwood
  (28 trees) and the Roost (14 spires) gain most.
- **Cathedral reads +4.8%, and that is camera variation, not added geometry.** The bot's fight is not frame-identical
  between runs, so the camera and the mesh LODs differ: the t = 4 s frames are 354,872 before and 354,558 after;
  the t = 9 s frames are 332,322 and 365,742. Treat differences under about 5% in any row as noise.
- **Draw calls rose by 1 to 8 in most regions.** Sources: brazier flame emitters in the kit layouts (up to 4), the
  second ambient emitter per region, the pooled spark / dust emitters while they are live, and two extra
  shadowless lights (camera-side fill, pooled impact light). Sword trails are 2 strips per swinging fighter, as before.
- **Video memory is unchanged.** No textures were added; the new materials reuse the imported albedo / normal / ORM
  textures. The generated shader variants are too small to register.
- The Courtyard and the Blackwood remain the heaviest scenes by a wide margin (about 550k and 760k primitives
  against 340k-380k elsewhere). That was true before this pass and is the first thing to cut if a device struggles.

## Budgets now enforced in code

| Budget | Limit | Where |
|---|---|---|
| Ambient particles per arena, flames included | 150 live | `Arena.PARTICLE_BUDGET`, `Arena._allot` |
| Sparks in one burst | 40 (perfect parry); parry 24, guard break / critical cut 16, block 10, ordinary cut 10 | `Fx.MAX_SPARKS`, `Fx.BUDGET`, call sites in `duel.gd` |
| Dust per puff | 8 | `Fx.BUDGET.dust` |
| Stone chips per slam | 10 (+7 dust) | `Fx.BUDGET.chips` |
| Elemental burst | 12 particles, or 3 arcs | `Fx.BUDGET.element` |
| Pooled emitters | 4 spark, 3 dust, 2 chips, 2 ember, 2 ice, 2 mote; 2 impact lights; 1 arc mesh | `Fx.POOL` |
| Sword trail | 24 samples, 2 strips, about 290 triangles per swinging fighter | `FighterRig._update_trail` |

All particle counts are multiplied by `Game.particle_scale()` (0.5 / 0.8 / 1.0 by preset). The captures above ran
at the default Balanced preset (0.8).

Worst case for combat effects alive at once (perfect parry with an elemental blow and a push-back):
40 sparks x 4 triangles + 12 embers + 8 dust, about 200 triangles and 3 draw calls, for about a third of a second.

## Image checks made on the captures (software renderer)

Share of pixels in the play area of the t = 9 s frame that are clipped white (all channels >= 250) or
effectively black (all channels <= 6):

| Region | Clipped % before | after | Black % before | after |
|---|---|---|---|---|
| Courtyard | 4.09 | 0.07 | 0.00 | 0.00 |
| Blackwood | 0.04 | 0.04 | 0.04 | 0.04 |
| Cathedral | 0.03 | 0.05 | 0.13 | 0.08 |
| Crypt | 0.02 | 0.02 | 1.36 | 0.17 |
| Roost | 0.06 | 0.01 | 0.00 | 0.00 |
| Citadel | 0.07 | 0.05 | 0.00 | 0.00 |
| Deep | 0.08 | 0.02 | 3.37 | 0.02 |
| Throne | 0.00 | 0.00 | 0.06 | 0.05 |

The Blackwood "before" frame was taken during a phase stain, so its row is not a clean comparison.

## Not measured

- Anything on an iPhone or any GPU: frame time, fill-rate cost of the additive ribbons and dust, shader compile
  hitches (the `pbr_clamp` shader has two variants; the first frame that shows each will compile it).
- The Performance and High presets (only Balanced was captured).
- Sanctuary, cathedral steps, the exploration and cinematic scenes.
- Memory on device: the 250-350 MB figure is the software renderer's own accounting with uncompressed fallbacks and
  says little about ASTC textures on iOS.

## Slice QA (2026-11-27): the first-boss slice's heaviest moments, and the texture change

Software renderer, 1280 x 720, one frame each (`tools/shoot.sh … --quality=0|1 [--meshes]`). Not device figures.
"Before" is with 337 model textures imported lossless; "after" is with them VRAM-compressed (`compress/mode=2`).

| Scene | Preset | Draw calls | Primitives | Video mem MB before | after |
|---|---|---|---|---|---|
| Courtyard duel (Hollow Soldier, t = 6 s) | Balanced | 134 | 436,244 | 339 | 148 |
| | Performance | 134 | 403,621 | 318 | 127 |
| Ashen Sentinel (t = 8 s) | Balanced | 131 | 467,416 (495,689 in the second run: the fight is not frame-identical) | 332 | 146 |
| | Performance | 129 | 410,604 | 311 | 125 |
| High road vista (Generation I, shot 1) | Balanced | 101 | 380,753 | 172 | 145 |
| | Performance | 101 | 308,239 | 149 | 123 |
| Sanctuary, Armory | Balanced | 292 | 188,639 | 151 | 133 |
| | Performance | 305 | 117,256 | 120 | 102 |

- Of the duel's 339 MB, 301 MB was textures and 21 MB buffers (`RenderingServer.get_rendering_info`).
- What is left after the change is mostly render targets and shadow atlases, which grow with the window: the same duel in a 2796 x 1290 window reports 241 MB on Balanced.
- Geometry was not reduced. The Courtyard duel holds 60 visible meshes, 486,000 triangles at full detail: about 9,600 each for `env_peak` (8 copies, no shadows), `env_rubble` (4), `env_banner` (3), 31,500 for the foe, 34,000 for the knight's under-layer and arms. The Armory's 292 draw calls are the carousel's pieces and the armour parts.
- Shadows: on Performance the spot and omni shadow atlas is 0, so only the sun casts; Balanced allocates a 2048 atlas for positional lights. How many lights use it was not counted in this pass.

## Far-future environment pass (2026-11-27): the duel arenas rebuilt, and their geometry

Software renderer, 1280 x 720, **Performance preset** (`--quality=0`), one frame at t = 8 s of a bot-played boss duel
(`tools/shoot.sh <dir> 8 --demo=<foe> --skip_intro --bot=3 --quality=0`; "before" adds `--oldworld`). Not device
figures. The fight is not frame-identical between runs: treat differences under about 5% as noise.

| Arena (boss) | Draw calls before | after | Primitives before | after | change | Video mem MB before | after | Balanced after (primitives) |
|---|---|---|---|---|---|---|---|---|
| Fallen Courtyard (Ashen Sentinel) | 134 | 116 | 443,099 | 205,384 | -54% | 124.6 | 107.2 | 242,098 |
| Blackwood (Hollow Executioner) | 175 | 131 | 695,151 | 200,318 | -71% | 122.2 | 105.3 | 254,916 |
| Cathedral steps (Crimson Widow) | 145 | 113 | 159,271 | 169,560 | +6% | 85.1 | 95.6 | 260,632 |
| Cathedral of Ash (Cathedral Beast) | 144 | 124 | 350,763 | 173,806 | -50% | 102.3 | 95.9 | 205,754 |
| Sunken Crypt (Gravewarden) | 145 | 127 | 351,231 | 202,568 | -42% | 105.6 | 97.0 | 230,020 |
| Frozen Citadel (Frostbound King) | 132 | 123 | 324,472 | 205,186 | -37% | 106.2 | 101.0 | 231,730 |
| Hollow Throne (Forgotten Monarch) | 141 | 124 | 299,082 | 167,688 | -44% | 107.0 | 93.6 | 232,380 |

The Courtyard's second frame (t = 4 s): 408,601 before, 208,094 after.

- **The target of 200,000 on Performance was not reached in the Courtyard: it reads 205,000 to 208,000.** What is left
  is the two fighters. With the scenery reduced to a row of eleven props the same duel read 226,000; the knight's
  under-layer (22,729 triangles), arms, legs and shoulders (28,300 together), the Sentinel (32,943) and his sword
  (5,602) are about 100,000 triangles, and most of them are drawn a second time for the sun's shadow: about 175,000
  primitives a frame before any scenery. The arena itself is now about 30,000 (it was about 250,000). Going lower
  means cutting the fighters' meshes or their shadow pass, which is `src/chars`, not this pass.
- **Where the cut came from.** The medieval kit was 60 generated meshes of about 9,600 triangles. The far-future kit
  is eleven generated props of 2,300 to 5,700 triangles, used 10 to 15 times an arena, and everything else (walls,
  ribs, spires, columns, rings, masts, beacons, trunks, hills) is built in code and merged into four to nine meshes of
  a few thousand triangles in all. The nine `env_peak` mountains (86,000 triangles) are one 770-triangle mesh.
- **Shadow casters** (`Future.prop`): a prop casts only if it stands within 14 m of the ring's centre (10.5 m on
  Performance) and is at least 2.5 m tall; built pieces away from the ring are in the kit's no-shadow meshes.
- **Detail levels**: props use the importer's levels with `lod_bias` 0.4 near the ring and 0.2 away from it (0.18 and
  0.09 on Performance); the gate, the two spires and the Blackwood's giant trees 0.1 (0.05). Lower than that the gate
  visibly melts (tried at 0.02 and 0.001 and put back).
- **Left out on Performance only**: the Courtyard's dead tree (8,300 triangles) and its second engine; 40% of the grass tufts.
- **Cathedral steps went up 6%**: the old steps were boxes and three towers with no models at all; the new ones
  carry the blast door (10,000 triangles), a guardian, two pylons and a wreck.
- **Lights**: no arena has more omni lights than before (Courtyard 4, Blackwood 6, Cathedral 3, steps 2, Crypt 5,
  Citadel 6, Throne 5); the Crypt had 14 and the Blackwood 6.
- **Shaders added**: `future_ground` (floor: 3 noise, 3 land, 2 panel reads), `future_built` (6 panel, 2 noise),
  `future_prop` (3 reads, the same as `pbr_clamp`). Their cost on a phone GPU is not measured.
- Video memory fell in six arenas because fewer distinct models are loaded; the steps rose because they now load some.
- The opening: the Engine room with the cradle model reads 81,000 to 115,000 primitives in the awakening (three
  frames); the command hall with the throne model 87,000 to 164,000 in the throne beat.

Not measured: the High preset; any arena outside a boss duel (exploration stops, the road walk, the story scenes that
borrow the throne hall); anything on a device.
