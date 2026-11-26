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
