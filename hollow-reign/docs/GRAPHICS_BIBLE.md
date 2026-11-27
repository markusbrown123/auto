# Graphics bible

The look of Hollow Reign as it is in code after the 2026-11-26 graphics pass. Renderer: Godot 4.6 Mobile.
Values here are the ones in `src/world/arena.gd` (`THEMES`), `src/world/look.gd` (`SURFACE`) and `src/fx/`.
Judged on software-rendered captures only; nothing has been seen on a device.

## Principles

1. **The fighters always read.** Nothing in a frame is pure black, and the two bodies are the brightest, most
   contrasted things in it after fire. A dark region is dark in colour and fog, not in exposure.
2. **Old metal and old stone.** Steel is worn, never chrome. Stone is dry and rough, never glazed. Gold is dull.
3. **One colour per region,** carried by ambient, fog, rim light and firelight. The key light is near-neutral so
   silver armour stays silver everywhere.
4. **Light comes from somewhere.** Every glow has a source in the scene: brazier, lantern, crystal, window.
5. **Effects are small and brief.** They mark a contact and get out of the way.

## Palette

| Role | Colour |
|---|---|
| Knight's armour | worn silver-steel, cool highlights, blue heraldic shield |
| Sword trail | steel-white (0.82, 0.87, 0.94), leaning to a blade's own glow |
| Sparks | hot metal (1.0, 0.82, 0.5) cooling to orange-red |
| Fire | region `fire` colour: orange in Courtyard / Roost / Cathedral, amber-gold in the Throne, corpse-green in the Crypt, pale blue in the Citadel, violet in the Deep, sickly yellow-green in the Blackwood |
| Frost | (0.55, 0.8, 1.0) |
| Old energy (rift, machines) | pale cyan (0.62, 0.9, 1.0) |
| Corruption | near-black violet, never additive |
| UI (owned by the UI theme) | blackened steel, antique gold, silver, charcoal, muted crimson |

## Material rules by class

Every generated model passes through `Look.sanitise(root, class)` when it is loaded
(`PropModel.scenery / weapon / shield`, `SkinDriver._fit`, and the duel for dragons), which replaces its material
with the `pbr_clamp` shader and these limits. Roughness is clamped per pixel, metallic is capped per pixel.

| Class | Roughness | Metallic | Specular | Intent |
|---|---|---|---|---|
| stone | 0.78 - 1.0 | <= 0.05 | 0.30 | dry masonry; no highlights except at grazing angles |
| wood, cloth, plant | 0.80 - 1.0 | 0 | 0.25 | matte |
| scenery metal | 0.50 - 1.0 | <= 0.60 | 0.40 | sooty iron and bronze fittings |
| regal (throne room, altar) | 0.58 - 1.0 | <= 0.45 | 0.35 | dull gilding over dark stone: imposing, not glossy |
| ice, crystal | 0.38 - 0.9 | 0 | 0.50 | the only smooth scenery |
| weapons, shields | 0.30 - 1.0 | as authored | 0.50 | real metal, but never a mirror |
| characters, dragons | 0.33 - 1.0 | <= 0.85 | 0.35 | armour keeps its shape under light; no blown plates |

Other rules:
- Floors are rough stone (roughness 0.8; "wet" regions 0.6), metallic 0. The earlier wet floor
  (metallic 0.25, roughness 0.42) rendered as rippling foil and was removed.
- Albedo and normal maps are sampled with anisotropic mip filtering; all imported textures already carry mipmaps.
- Normal maps are always used when the source material has one.
- Emission is reserved for fire, runes, crystals, eyes and windows.
- Per-foe tint, the hit flash and the fresnel rim are shader uniforms on the fighter's own material instance.

## Lighting recipe

Each arena has the same five-part rig; only the numbers change.

1. **Sun / moon**: one shadow-casting directional light (`sun`, `sun_e`, orthogonal shadows, blur 1.5).
2. **Ambient**: flat colour (`amb`) at energy `amb_e`. This is what keeps the dark regions off black.
3. **Fill**: a shadowless directional from the camera's side (`fill_e`, ambient colour lifted 45% to white,
   no specular). Off in the two daylight regions.
4. **Rim**: a shadowless directional from behind the foe (`rim`, `rim_e`), and the same colour at 40% as a fresnel
   edge on both fighters (`rim_color` uniform), so silhouettes separate from the fog.
5. **Key**: the duel's spot light (`key`, `key_e`, 40 degree cone, no shadows). It follows the fight: `Fx.follow_key`
   keeps it over the camera's right shoulder, aimed between the two fighters.

Plus local fire and glow lights placed by each layout, flickering if they are firelight.

Values in code (`_e` = energy, `fog_d` = fog density, `exp` = exposure before the x1.25 tonemap compensation):

| Region | sun | sun_e | amb | amb_e | fill_e | key | key_e | rim | rim_e | fog | fog_d | exp | sat | con |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| courtyard | #fff2dc | 2.1 | #7e8ea6 | 0.95 | 0.0 | #fff6ea | 2.0 | #ffe6c4 | 0.35 | #a8bccc | 0.005 | 1.0 | 0.95 | 1.06 |
| roost | #ffcf9a | 2.0 | #8a7068 | 0.95 | 0.0 | #fff0e0 | 2.0 | #ffb070 | 0.4 | #d09868 | 0.006 | 1.0 | 0.98 | 1.06 |
| deep | #a48ae0 | 0.95 | #3a2e54 | 1.7 | 0.45 | #ece6ff | 4.0 | #b890ff | 0.75 | #1a1030 | 0.026 | 1.18 | 0.9 | 1.05 |
| blackwood | #b4d0ba | 1.45 | #2e4234 | 1.6 | 0.4 | #f0f4ea | 3.8 | #c8e09a | 0.6 | #1e2c24 | 0.022 | 1.15 | 0.88 | 1.06 |
| cathedral | #ffb47a | 1.25 | #4e382c | 1.6 | 0.4 | #fff0e2 | 3.6 | #ff9a58 | 0.6 | #2e1c14 | 0.024 | 1.15 | 0.9 | 1.06 |
| cathedral_steps | #ffb47a | 1.25 | #4e382c | 1.6 | 0.4 | #fff0e2 | 3.6 | #ff9a58 | 0.6 | #2e1c14 | 0.022 | 1.15 | 0.9 | 1.06 |
| crypt | #7cc4b0 | 0.9 | #2a443a | 1.7 | 0.5 | #e8f6f0 | 4.0 | #7ef0cc | 0.7 | #122620 | 0.024 | 1.2 | 0.88 | 1.05 |
| citadel | #c8dcf4 | 1.5 | #46586e | 1.45 | 0.3 | #eef4ff | 3.4 | #a4dcff | 0.55 | #4a5e74 | 0.026 | 1.1 | 0.9 | 1.08 |
| sanctuary | #c8b8a0 | 0.6 | #3e342c | 1.5 | 0.25 | #fff2e0 | 3.6 | #ffc888 | 0.5 | #15120f | 0.04 | 1.15 | 0.9 | 1.06 |
| throne | #ffdcaa | 1.15 | #42342a | 1.55 | 0.35 | #fff4e6 | 3.6 | #ffd080 | 0.55 | #1c140e | 0.014 | 1.12 | 0.95 | 1.12 |

Region notes:
- **Courtyard**: rich daylight, hard architectural shadows, light haze only at distance. Sun lowered slightly
  (2.3 to 2.1) and exposure curve given headroom; clipped pixels fell from 4.1% to 0.1% of the frame.
- **Blackwood**: green dusk under the canopy; lanterns are the warm note. Fog density 0.035 to 0.022.
- **Cathedral**: ember-orange gloom; ash falls, embers rise. Fog 0.04 to 0.024.
- **Crypt**: corpse-light teal. Was the darkest region (sun 0.35, fog 0.07); now sun 0.9, fog 0.024, ambient
  doubled in value, ground mist added.
- **Roost**: low orange sun, long shadows, embers and ash.
- **Citadel**: blue-white with depth: fog thinned 0.045 to 0.026 so the far hall shows, snow halved to fit the budget.
- **Deep**: violet, lit by crystals and fungus; spores drift. Fog 0.05 to 0.026, floor lifted off black.
- **Throne**: warm, royal, dark red and dull gold; fog 0.03 to 0.014, contrast 1.12, brazier flames added.

## Post-processing

Set in `Arena._environment()`; identical in every region apart from the grade.

| Setting | Value | Why |
|---|---|---|
| Tonemap | Filmic, white point 3.0, exposure = `exp` x 1.25 | headroom above 1.0 so silver and fire roll off instead of clipping |
| Glow | on, intensity 0.55, strength 0.9, bloom 0.0, HDR threshold 1.05, screen blend | only emissive surfaces and fire cross the threshold; lit stone and armour do not bloom |
| Fog | exponential depth fog, per-region colour and density (0.005 - 0.04) | depth cue; far walls stay visible |
| Grade | `sat` 0.88 - 0.98, `con` 1.05 - 1.12, `bri` 1.0 | slight, per region |
| Not used | film grain, chromatic aberration, motion blur, vignette, depth of field, SSR, SSAO, SDFGI, volumetric fog | brief, and Mobile renderer limits |

Anti-aliasing, render scale and shadow resolution belong to the Game's graphics presets (`Game.GRAPHICS`), not to this file.
`project.godot` rendering settings were not changed in this pass.

## Known weak points

See the end of the pass report; in short: armour still reads a little bright in the two daylight regions, the
Throne is slightly hazy, the dragon's fireball is an untextured disc, there are no reflections of any kind, and
none of this has been seen on a phone screen.

## High road (the opening's place; `src/world/highland.gd`, 2026-11-27)

Art direction from the owner: **the land is natural, everything built on it is futuristic, and the sky is not Earth's.**
Nothing on the road, in the gate court, or in the opening's two interiors uses the medieval kit models
(`env_gate`, `env_wall`, `env_statue*`, `env_banner`, `env_brazier`, `env_pillar`, `env_peak`, `env_th_*`, `env_cr_*`);
the first generated gatehouse (`env_road_gatehouse.glb`) is left unused. What is used: `env_road_gate_future.glb`
(the blast-door bulkhead at the gate) and `env_road_dead_tree.glb` (nature). Everything else is built in code.
Judged on software-rendered captures only (`marketing/road_pass/`).

### The land
- **Height field** 4 m cells, built once and cached: a calm crown for the road, two rock steps across the climb,
  ground tipping east to a banded sea cliff with a rock shelf at its foot, a 50 degree rock wall behind the gate.
- **Ground shader** (`highland_ground.gdshader`): turf in two tones with a large-scale colour drift and heather
  patches; slope decides turf, then earth and scree, then rock (triplanar `floor_deep`, soft beds, dark and wet near
  the sea). `floor_blackwood` and its normal map are the detail layer at two scales so neither repeat shows.
- **Light on the land** is custom (`light()` in the ground, rock and grass shaders, shared in
  `highland_common.gdshaderinc`): the directional light is multiplied by (1) the land's own shadow, baked per
  generation on the CPU from the height field (one 66 x 91 R8 texture each, about a quarter of a second), (2) the
  Ring-Gate's shadow, computed analytically, (3) cloud shadow, a scrolling noise that moves with the wind.
  The real shadow map only covers 85 m and is for the figure and props.
- **Grass**: clumps of three crossed cards in MultiMeshes per 40 m of road (fine near the road, coarser to 40 m,
  tussocks to 130 m, heather and gorse in their own batches where the ground shader paints heather). Blade texture
  is generated (120 thin blades, seed heads). Each clump stands square to its ground and is lit with that normal;
  roots dark, tips pale; gusts are fronts in a scrolling noise; far clumps sink into ground of the same colour.
  Density follows `Game.particle_scale()` (0.5 / 0.8 / 1.0).
  **Renderer trap found here:** on the Mobile renderer a non-constant `ALPHA_SCISSOR_THRESHOLD` rendered the whole
  material black once the specialised pipeline replaced the ubershader (lavapipe). Keep the threshold constant and
  scale `ALPHA` with distance instead.
- **Crags** (`highland_rock.gdshader`): three faceted meshes in MultiMeshes: outcrops, the lip of the cliff, sea
  stacks, the shoulders of the gate. Turf or snow lies on upward faces.
- **Sea** (`highland_sea.gdshader`): reads the height field as a texture to find its shore; surf bands, a paler
  shelf, a path of light toward the sun.
- **Far country** (`highland_far.gdshader`): six ranges in one mesh, each with a crest, shoulder and foot so its
  faces take the sun, each thinner in the air than the last (vertex alpha), all standing in sea haze. Fog is off for
  them and for the landmarks: recession is done by hand, in layers, so nothing washes out.
- **Cloud** (`highland_cloud.gdshader`): two sheets bowed down to the horizon (a low broken deck, high streaks),
  lit edge and dark belly from a second sample toward the sun. Light shafts are additive cards laid along the sun's
  direction (`highland_shaft.gdshader`).

### The sky that is not Earth's
`Highland._sky`: a pale banded planet low in the north-west (`highland_planet.gdshader`, lit from the sun's side,
gone to sky colour on the other), the arc of an orbital ring crossing the sky plate by plate, stars near the zenith
by day, aurora curtains, and in Generation II the trails of what is falling from the arc
(`highland_skyline.gdshader`). Five draws, all additive or alpha cards beyond the hills; they need a camera far
plane of 6000 (CineCam and the menu's vista set it).

### What is built (`Highland.built`, `_panels`, `_arc`, `_prism`, `_beam`)
- **Materials**: one generated panel-line sheet (plates of slightly different tone with grooves; albedo and normal),
  world-triplanar. `built(tint, metal, rough, scale)` gives matte pale ceramic (metal 0.1-0.2, roughness 0.5) or
  brushed alloy and gunmetal (metal 0.5-0.6). Lights are their own unshaded emissive materials so a generation can
  recolour or kill them (`_set_lamp`).
- **Ring-Gate**: 24 curved ceramic segments with seams, a darker spine showing in the seams, a channel of light in
  the inner face, fins cantilevered off the rim, plates hovering over the crown, stays to the rock, angled housings
  at its feet. Two segments are down by Generation II.
- **Citadel**: seven tapering hexagonal towers in three setbacks with lines of light, thin spans, terraces.
- **Gate court**: `env_road_gate_future.glb` (14.5 m) with an emissive strip laid over its seam so generations can
  switch it; leaning bulkhead walls with ribs, alcoves and a top line of light; lamp posts; pennants of light on
  masts; a landing ring inlaid in the pad. Without the model the same court builds its own frame and two door leaves.
- **Road**: laid slabs (joint every 3 m, kerb line, a lit guide strip down the middle) drawn in the ground shader
  from a two-channel mask; marker pylons with lit heads; a gantry at the head of the climb; signal masts; a conduit
  along the verge; half-buried pipes, hoops and a sensor dome in the turf.

### The three generations (`Highland.generation(arena, 1|2|3)`; values in `SEASONS` and `SKY`)
| | I, kept | II, breached | III, waking |
|---|---|---|---|
| Sun | dawn gold from the sea (east), 15 degrees up | amber dusk from behind the moor (west), 7 degrees | pale, from behind the ring |
| Ambient | cool blue 0.72 | blue 1.1 (warm sun against cool shadow) | steel 0.8 |
| Fog density | 0.00028 | 0.00045 | 0.0005 |
| Structure lights | amber, fed | dead | the Engine's teal |
| Ring | whole, halo plates up | two segments down, a gantry at the break | seam alight (emission 6) |
| Gate | square, seam amber | settled, dark, ivy, plates down | seam and landing ring teal |
| Road | clear, guide strip dim | half taken back by turf, strip dead | snow at the edges, strip lit |
| Sky | serene, planet pale | amber planet, debris trails | orbital arc lit, strong aurora |

### The opening's interiors
- **Command hall** (`Arena` theme `command`, `_layout_command`): the first generation's throne room. Leaning alloy
  ribs with a column of light in each, plated walls, guide lines in the floor, and at the head a ceramic ring on end
  with the throne in its mouth. The Generation I scenes and both Generation I duels use it (the duels by lending the
  foe record another `arena` for their length); the gothic `throne` theme is untouched for the later game.
- **Engine room** (`chamber`): ribs up the wall with light channels, a cradle with hoops and a head unit, cables
  across the floor, banks of readouts, a metal band in the floor, ground mist.

### Measured cost (software renderer, 1280x720, engine monitors after 4 s; not a device measurement)
The envelope is the Balanced courtyard duel in `PERFORMANCE_REPORT.md`: 133 draws, 549k primitives, 351 MB.

| Shot (Generation I) | Balanced draws | primitives | video MB | Performance draws | primitives | video MB |
|---|---|---|---|---|---|---|
| 1 vista | 96 | 380,707 | 143 | 96 | 308,193 | 120 |
| 2 low, beside the walker | 50 | 389,365 | 143 | 51 | 315,858 | 120 |
| 3 the switchback (heaviest) | 102 | 478,423 | 143 | 102 | 339,083 | 120 |
| 4 over the shoulder | 94 | 467,443 | 143 | 93 | 356,733 | 120 |
| 5 the dead tree | 80 | 418,657 | 143 | 80 | 296,165 | 120 |
| 6 the gate court | 73 | 322,341 | 143 | 68 | 264,077 | 120 |

Those six were taken without the story overlay; through the game's own capture path (overlay and SKIP on) the same
shots read 5 draws and about 30 MB higher. Generation II's vista is the heaviest vista (105 draws, 431,701
primitives). The menu over the vista: 133 draws, 432,705 primitives, 167 MB. Command hall scenes: 33-57 draws,
93k-205k primitives; the guardian duel in it 126 draws, 218k. The Engine room in the fall: 74-144 draws (it is many
separate boxes; the peak is while the dust and sparks are live), 137k-174k primitives, 131 MB. The Approach is the
Courtyard's own arena plus one foe: 587k primitives and 335 MB at its first shot, which is over the courtyard duel's
figure by the weight of that one rig.
The High preset was not measured. The kit props the road no longer loads are why its video memory is under half
what the first version of the road used (274 MB).

## The duel regions as the far future left them (`src/world/future.gd`, 2026-11-27)

Owner's direction: "Environment more new and space but land like futuristic not medieval at all." The same rule as the
high road now holds in the duel arenas: **the land is natural, everything built on it is far-future, and it is old.**
Seven arenas are rebuilt (Fallen Courtyard, Blackwood, Cathedral of Ash and its steps, Sunken Crypt, Frozen Citadel,
Hollow Throne). The Wyrm's Roost, the Hollow Deep and the Sanctuary are as they were. `--oldworld` (dev flag) loads the
earlier medieval layouts; they also load by themselves if the kit's models are missing.
Judged on software-rendered captures only (`marketing/world_future_pass/`); nothing has been seen on a device.

What did not change: the arena's size, the duelling ring (4.38 m), the flat floor, the theme table (`Arena.THEMES`:
every light, fog and grade value above still applies), the hooks other code uses (`theme`, `env`, `sun`, `fires`,
`tint()`), and the rule that nothing stands nearer the ring's centre than about 7 m (the camera keeps inside 6.4 m).

### The shared kit
- **Eleven generated props** (`assets/models/env_fu_*.glb`): `pylon` (a leaning monolith with a seam of light),
  `tower` (a watch spire), `wall` (a length of bulkhead, torn at one end), `colossus` (a guardian machine that knelt
  and never got up), `engine` (a turbine in the ground), `wreck` (a fallen arc of ring), `core` (a machine core: a
  sphere held in an upright ring), `husk` (a dead walker by a slab), `pod` (an upright stasis pod), `throne` and
  `cradle`. 2,300 to 5,700 triangles each. They come facing +X; `Future.prop` turns them so yaw 0 faces the camera's
  side, sinks their own skirt of turf a few centimetres, and gives them `future_prop.gdshader`.
- **`future_prop.gdshader`**: the clamped PBR read (roughness >= 0.55, metal <= 0.45: weathered, never chrome) plus
  three things that let one model serve every region: `tint`; `seam`, the region's own light, put wherever the
  texture has a painted light line (found by colour: cyan in most props, amber in the throne); and `snow` on faces
  turned up.
- **Built in code and merged by material** (`Future.Kit`; four structural meshes and up to five of light an arena):
  `bulkhead` (leaning plates between ribs with a cap, a kerb, buttress feet, a line of light), `plates` and `door`
  (interior walls), `ribs` (a pair of leaning ribs meeting overhead, a column of light in each), `ring` (a ring of
  ceramic on end with a light channel), `monolith`, `spire`, `column`, `mast` and `beacon` (the lamp post that replaces
  every brazier, lantern and candelabra), `conduit`, `console`; and the land's own: `trunk` (the Blackwood's colossal
  trees), `crystals` (ice), `drift` (snow), `tufts` (grass).
- **`future_built.gdshader`**: the high road's panel sheet laid on in world space from three sides, with age added in
  the shader: rain streaks down upright faces, broad stains, the region's grime climbing from the ground (moss, soot,
  rime), snow on top faces. Two tints a region: `pale` (matte ceramic, metal 0.12) and `alloy` (brushed, metal 0.5).
- **`future_ground.gdshader`** (replaces the flagstone floor): a deck of plates round the duelling ring (the ring is an
  inlaid alloy band with a broken line of light), joints in rings and spokes, a second band at the deck's edge, and
  beyond the deck the region's land from its ground texture: turf, leaf mould, ash, wet rock, ice. The land takes
  the deck back at its edge and in patches (`lost`); indoors the deck is the whole floor and the patches are what
  has come through it.
- **Outside** (`Future.ranges`, `Future.sky`): two ranges of hills and the planet and orbital arc of the high road,
  brought inside the duel camera's 120 m far plane; drawn by their own light (`highland_far`, `highland_planet`,
  `highland_skyline`), three draws.

### Region by region (`Future.LOOKS`)
| Region | What it is now | Land | Light in the seams | Deck |
|---|---|---|---|---|
| Fallen Courtyard | the landing court of a hill fortress: blast door between leaning bulkheads, spires, the kneeling guardian, an engine in the grass, beacons | turf, one dead tree | pale cyan, amber beacons | 8.4 m, pale |
| Blackwood | the forest has had it a long time: colossal trunks, a machine shrine still giving off its sick light, a guardian among the trees | leaf mould, trees | sickly yellow-green | 6.6 m, mostly lost |
| Cathedral of Ash | an archive hall that burned: leaning ribs with ember columns, half the roof gone, the core in a ring let into the end wall | ash through the deck | ember orange | whole floor |
| Cathedral steps | the deck climbs in treads to a blast door in a bulkhead front | ash | ember orange | whole floor |
| Sunken Crypt | a stasis vault, flooded: columns with a band of corpse-light, pods along the walls, cradles open on the floor | wet rock through the deck | teal | whole floor, wet |
| Frozen Citadel | a hall of monoliths open to the snow, the seat iced into its machine, a guardian under a drift | ice, drifts, crystals | cold cyan | 9 m, snowed |
| Hollow Throne | the last hall: whole ribs, dull gold light, the machine's ring on end behind the seat | none | dull gold | whole floor, dark |

Material rule added to the table above: **far-future scenery** (class of the kit): roughness 0.55 - 1.0, metallic
<= 0.45 on props, 0.12 (ceramic) or 0.5 (alloy) on built surfaces; emission only in seams, beacons and channels.

### The opening's two interiors
`env_fu_throne.glb` is the command hall's throne (node `Throne`; `Arena.THRONE_TALL`, `THRONE_SINK`, `THRONE_OFF`: 6 m
tall with its own dais sunk under the floor, so the seat is 0.9 m up and where the built seat was) and
`env_fu_cradle.glb` is the Engine room's cradle (node `Cradle`; `Arena.CRADLE_AT`, `CRADLE_TALL`, `CRADLE_YAW`).
Both fall back to the earlier boxes under `--oldworld` or without the model.
