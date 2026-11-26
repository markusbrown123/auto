# Shader library

Every shader and material recipe that exists in code. Target: Godot 4.6 **Mobile** renderer.
Nothing here uses screen-space reflections, SSAO, SDFGI, volumetric fog, refraction or depth-texture reads.
Costs are stated as texture samples and passes; no figure in this file is a device measurement.

## Custom shaders (`src/fx/*.gdshader`)

| Shader | Used by | What it does | Cost |
|---|---|---|---|
| `pbr_clamp.gdshader` | every generated (Tripo) model: scenery, weapons, shields, characters, dragons. Applied by `Look.sanitise(root, class)` | Albedo + normal + packed ORM, like StandardMaterial3D, but roughness is clamped per pixel into `[rough_min, rough_max]` and metallic is capped at `metal_max`, by asset class (`Look.SURFACE`). Uniforms: `tint` (per-foe tint), `flash` (hit flash, replaces the old emission toggle), `rim_color`/`rim_power` (fresnel edge in the region's light, characters only), `emissive`/`emissive_tex` (carried over from the source material), `spec`. A two-sided variant is built at load for materials that were `cull_disabled`. | 3 texture samples (4 if the source was emissive), one `pow`. Opaque, single pass, casts shadows normally. Albedo and normal use anisotropic mip filtering. |
| `grass_sway.gdshader` | grass tufts (`Arena._grass`, Courtyard and Blackwood MultiMesh) | Alpha-cut crossed quads; the top edge sways on two sines phased by world position. | 1 texture sample, 3 trig calls per vertex (8 vertices per tuft). No shadows cast. |

## Material recipes built in code (StandardMaterial3D)

| Recipe | Where | Notes |
|---|---|---|
| `Look.stone(tint, uv, rough, key)` | arena floor, primitive fallback layouts | Triplanar, two procedural noise textures (albedo ramp + cellular normal). Triplanar costs 3 samples per texture; used on the floor plane and fallback boxes only. Floor: roughness 0.8 dry / 0.6 "wet", metallic 0 (was 0.25 metallic / 0.42 rough: read as a mirror). |
| `Look.flat(color, rough, metal)` | primitive rig parts, fallback props | Untextured PBR. |
| `Look.glow(color, energy)` | window glows, lantern cores, rune lines | Unshaded + emission; the only surfaces meant to cross the bloom threshold. |
| `Look.particle(color, additive)` | all billboard particles | Unshaded, vertex colour, soft radial dot (32 px), additive or alpha. |
| `Look.leaf()` | Blackwood falling leaves | Unshaded billboard, 16 px procedural leaf, alpha, spun by the emitter. |
| `Fx.ribbon_material()` | sword trails, energy arcs | Unshaded, additive, vertex colour, 1-D soft-edge gradient across the width, no fog, two-sided. |
| `Fx._streak_material()` | sparks, ice chips | Unshaded, additive, vertex colour; mesh is two crossed tapered quads aligned to velocity (4 triangles per spark). |
| stone-chip material | `Fx` "chips" emitter | Lit, roughness 0.95, vertex colour = floor colour. |
| unblockable overlay | `FighterRig` (`_warn_overlay`, gameplay-owned) | Additive unshaded `material_overlay` on the weapon. Listed for completeness; not changed in this pass. |

## Asset classes (`Look.SURFACE`)

| Class | rough_min | rough_max | metal_max | specular | Applied to |
|---|---|---|---|---|---|
| stone | 0.78 | 1.0 | 0.05 | 0.30 | scenery by default (walls, towers, pillars, statues, rubble, rock, sarcophagi) |
| wood | 0.80 | 1.0 | 0.00 | 0.25 | trees, logs, carts, huts, pews, banners, nests, roots, fungus, coffins |
| scenery_metal | 0.50 | 1.0 | 0.60 | 0.40 | braziers, censers, bells, candelabra, lanterns, conduits, gibbet, rings, husks, chest, wreck, obelisk |
| regal | 0.58 | 1.0 | 0.45 | 0.35 | throne-room set (throne, statues, pillars, stairs), cathedral altar and windows |
| ice | 0.38 | 0.9 | 0.00 | 0.50 | citadel shards, deep crystals |
| weapon | 0.30 | 1.0 | 1.00 | 0.50 | weapons and shields |
| character | 0.33 | 1.0 | 0.85 | 0.35 | knights, foes, dragons |

Class is chosen from the file name in `PropModel.scenery_class()`.

## Quality tiers

The Game's three graphics presets (`Game.GRAPHICS`, owned by core) change render scale, MSAA, shadow size and
distance, LOD and the particle multiplier. Effects read the multiplier through `Fx.pscale()`:
spark, dust, chip, elemental and ambient counts are all multiplied by it (0.5 / 0.8 / 1.0).
**No shader has per-tier variants yet**: `pbr_clamp` and `grass_sway` are the same on all three presets.

## Not built

These are named in the brief or would be expected of a shader library, and do not exist:

- dissolve / burn-away for dying foes; frost-creep and burn overlays on a struck body
- heat haze or refraction over fire and dragon breath (needs screen texture; deliberately avoided on Mobile)
- water / wet-floor reflections (the "wet" floors are plain damp stone)
- soft particles (depth fade where a billboard meets geometry)
- cloth or banner wind in the vertex shader (only grass sways)
- emissive pulse on runes, crystals and the Witness mask; an eye-glow shader
- per-tier shader variants (a cheaper `pbr_clamp` without normal map or rim for the Performance preset)
- LUT-based colour grading (grade is Environment brightness / contrast / saturation only)
- cinematic shaders (vignette, letterbox blur, depth of field)
