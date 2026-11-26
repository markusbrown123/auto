# Equipment design bible

How swords and shields are designed and built. Second pass (2026-11-26), after the owner's feedback that the first
benchmark was "too plain and historical" and should be a **futuristic style**: ornate, sculpted, jewellery-precise.
Ten swords and three shields exist in `assets/models/gear/`; all come from parameter sets in one generator.
Judged on software-rendered captures (`marketing/gear_bench/v2/`); nothing has been seen on a device.
The owner's taste reference was a photo of four display swords from an existing game. It was described to the
modeller in words only and none of the four is reproduced: the language was taken, the designs are our own.
The two reference web pages named earlier could not be opened from the build machine.

## The language in one paragraph

Every sword is recognised by its **silhouette**, and the silhouette is carried by the **guard**: a flat sculpted
plate with pierced cut-outs, two to four times the blade's width, with a few gold studs. Blades are slim and long with
a **waisted or leaf profile** and a recessed band down the flat that carries **engraved line-work**. Grips are
slender: tight cord, or a spiral-twisted bar. Pommels are small distinctive shapes. Finish is even satin steel,
never chrome and never battle-worn. Light, where a blade has it, is one hairline inside the engraving and is **off
until the weapon is awakened**. Rarity and forge upgrades buy finer work, never more size or more points.

## Roles: shape tells the stat

| Role | Reads as | Sword | Shield |
|---|---|---|---|
| balanced | medium everything, symmetric | **Wayfarer**, King's Remnant, Eternal Edge | **Heater** |
| light / fast | slimmest blade, shortest grip, small open guard | **Silver Vow**, Cold Resolve | **Round** (0.47 m) |
| heavy / damage | broad thick blade with mass toward the point, blocky guard, longer grip | **Ashbrand**, Nightward, Oathbreaker | **Tower** (0.88 m, bolted bars) |
| precision / combo | long slim blade, pierced fuller, asymmetric guard | **Veilcutter**, Twin Relics | - |

`role` and `rarity` are fields in `gear_manifest.json` for the data owner. The four names in bold are the **basic
swords** a player can start with and then mod at the forge.

## Pipeline

- `tools/gear_gen.py` (Python + numpy + PIL, no Blender) writes every GLB, the shared textures in `gear/tex/` and
  `gear_manifest.json`. Run it, then `tools/check.sh` to import. About 15 s for everything.
- `src/chars/gear_model.gd`: `GearModel.spawn(id, lod_at, force_lod, mod)`, `GearModel.info(id)`,
  `GearModel.ids("sword" | "shield")`, `GearModel.apply_mod(node, mod)`, `GearModel.awaken(node, on)`.
- `--screen=gearbench` (`src/dev/gear_bench.gd`) is the viewer; its header lists the switches.
- Primitives: `loft`, `lathe`, `block`, **`plate`** (2D outline with cut-outs, extruded, every rim chamfered; caps
  by ear clipping), **`blade2`** (parametric blade), `ribbon` (swept outlines), `twist_grip`, `hilt_grip`, `dot`
  (gold stud), `board` / `kite_shield` / `strip` / `boss` (shields), `arm_strap`, `hand_grip`, `rivet`.
- **Hard edges are explicit**: every face has a smoothing group and normals are averaged only inside a group, so a
  7 degree blade facet is still a crisp line. Plate walls crease automatically at corners sharper than 35 degrees.
- UVs: metres x 16 for the brushed sets; the engraved band has its own mapping (band width = texture width, one tile
  every 8 half-widths), so a 0.4 mm engraved line is about 3 texels and stays crisp in close-up.

## Conventions (what the rig relies on) - unchanged from the first pass

| | Swords | Shields |
|---|---|---|
| Units | metres, life size | metres, life size |
| Origin | centre of the main hand on the grip | centre of the hand-grip bar |
| +Y | toward the tip | up |
| X | guard plate lies in the XY plane | +X is the bearer's right (grip side); the arm strap is at -X |
| Z | flat of the blade faces +-Z (thin axis) | the FRONT faces -Z (the rig's "outward"); straps on +Z |
| Manifest | `tip`, `pommel`, `off_hand` (two-handers), `grip_clear`, `guard_span`, `single_edged`, `pair` / `mirror_left` | `board_centre`, `width`, `height`, `strap_x`, `thickness` |
| `rig_scale` | 1.15 | 1.15 |

Asymmetric swords (Veilcutter, Nightward, Twin Relics): the long guard arm / knuckle side is toward **-X** on
Veilcutter and **+X** on Nightward and Twin Relics; turn the model 180 degrees about Y at the attach point if the rig
wants it on the other side. Twin Relics' left-hand blade is the same model with `scale.x = -1`.

## The ten swords

Life size, metres. "Overall" is tip to pommel end. Triangles are detail / low model.

| Sword | Role, rarity | Overall | Blade profile (half-width mm at guard -> waist -> belly -> tip start) | Guard (our motif) | Grip, pommel | Engraving | Tris |
|---|---|---|---|---|---|---|---|
| **Wayfarer** | balanced, common | 0.97 | 23.8 -> 22.2 -> 25.0 -> 16.5 at 84%; gentle waist | symmetric slotted bar, tips turned down, span 0.196 | cord 0.106; pentagonal tab with a hexagonal eye | `rule` (hairlines and graduations) | 2,148 / 596 |
| **Silver Vow** | light, common | 0.92 | 16.5 -> 14.0 -> 17.2 -> 15.0 at 72%; needle | small open lens frame, two pointed windows, span 0.109 | cord 0.095 (one palm); faceted bead | `lattice` | 2,318 / 664 |
| **Ashbrand** | heavy, common | 1.03 | 21.5 -> 20.5 -> 30.0 at 62% -> 26.2 at 80%; leaf, 8 mm thick | blocky anvil plate, two windows, tall graphite collar, span 0.176 | cord 0.148; slotted block | `chevron` | 2,204 / 644 |
| **Veilcutter** | precision, common | 1.10 | 16.8 -> 15.0 -> 17.2 -> 16.0 at 72%; long | asymmetric: short arm toward the point, long arm swept back past the knuckles | cord 0.113; spike | `feather`; **7 diamond openings pierced through the fuller** | 3,120 / 660 |
| Oathbreaker | heavy, rare (greatsword) | 1.62 | 29 (24.5 across the blunt ricasso) -> 27.2 -> 19 at 88% | wide tiered "circuit" plate, windows and slots, clamp up the ricasso, span 0.30 | two-hand cord 0.30 with riser; keystone with slot | `circuit` | 3,172 / 776 |
| Eternal Edge | balanced, legendary | 1.10 | 17.0 -> 15.8 -> 21.5 at 52% -> 15.0 at 80%; waisted leaf | slender arrow frame: short wings, two prongs running 9 cm up beside the blade, open slits between | cord 0.161 with gold rings; open hexagonal ring | `wave`; light channel | 2,628 / 632 |
| King's Remnant | balanced, rare | 1.08 | 25.0 -> 23.8 at 70% -> 19.6 at 86%; parallel, strong point | "broken crown": merlons along the upper edge over a long window, span 0.192 | cord 0.135; disc pierced by a square | `meander`; gold-inlaid groove | 3,052 / 672 |
| Cold Resolve | light, rare | 1.04 | 18.0 -> 15.0 -> 10.5 at 80%; needle taper | open hexagonal collar the blade stands in, a window each side, span 0.112 | cord 0.118; four-sided crystal | `hexcell`; light channel | 1,916 / 552 |
| Nightward | heavy, uncommon | 0.94 | single-edged: 30 edge side, 9 spine side; blackened flats, bright edge; **six fins on the spine** | half-disc on the edge side only, three graduated ports | cord 0.111; tab with lanyard eye | `feather` | 1,778 / 600 |
| Twin Relics | precision, relic (pair) | 0.78 | 18.0 -> 16.5 -> 23.5 at 55% -> 16.5 at 80%; short leaf | angular C-frame returning to the pommel as a knuckle bar | cord 0.146; hexagonal cap | `hexcell`; light channel | 2,224 / 572 |

Rules that hold for every sword:
- Blade thickness about 1.3x a real blade's (5.6 - 8.8 mm at the guard, tapering to about half). Distal and profile
  taper always present; the tip is an ogive to a real point.
- The grip is never shorter than one palm (0.09) plus 5 mm per hand; the lightest sword has the shortest grip.
- A guard is a plate 10 - 18 mm thick with chamfered rims; cut-outs keep at least 4.5 mm of metal round them.
  Ends are blunt. No guard is wider than 5x the blade.
- One silhouette per sword. Before a new sword is accepted it is rendered black beside the others
  (`--lineup=swords --silhouette`); two that read alike means one is redesigned.
- Gold is studs, rings and (top blade tier) the centre groove only: under 2% of the surface.
- No serrated cutting edges, no secondary blades, no spikes. Openings are inside the outline, not points on it.

## Blade cross-section (`blade2`)

One quadrant, from the cutting edge to the centre line:

`edge -> bevel shoulder (50% of thickness) -> flat -> lip of the recessed band -> band (0.5 mm lower) -> groove lip -> groove floor -> centre`

- **Band**: 55 - 80% of the flat's width, closes to a point at 60 - 74% of the blade. It carries the engraving.
- **Groove**: 2 - 7 mm wide in the middle of the band; plain steel, gold inlay (tier 3), or a light channel.
- **Pierced openings** (`holes`): the groove floor is left out between stations and walled, so they are real holes
  through the blade and show in silhouette. Diamond-shaped because the section is lofted.
- **Ricasso** (`ric`): narrower, blunt-edged first 10% (greatswords).
- **Single edge** (`wl`): the other side becomes a 9 mm blunt spine; fins are small plates set on it.
- Width comes from control points through a smooth curve, then an ogive from `s_tip`: that is how waists and
  leaf bellies are made.

## Engraving

Eight tiling patterns, 128 x 512 px each (albedo with a darker fill, normal, roughness/metal): `rule`, `lattice`,
`chevron`, `feather`, `circuit`, `wave`, `meander`, `hexcell`. One pattern per sword (`ENGRAVE` in the generator);
shields use `circuit` on the spine. The light channel is geometry (a `glow` surface in the groove), so it sits
exactly inside the engraving; `GearModel.spawn` leaves it dark and `GearModel.awaken(node, true)` lights it.

## Forge mods (the four basic swords)

| Parameter | Values | What changes on the model | How it is delivered |
|---|---|---|---|
| `blade_tier` | 0 | plain recessed band, plain centre groove | file `<id>__blade0.glb` |
| | 1 | band engraved with the sword's pattern | `<id>__blade1.glb` |
| | 2 | + gold studs at the foot of each flat | `<id>__blade2.glb` |
| | 3 | + centre groove inlaid in gold | `<id>__blade3.glb` |
| `grip_tier` | 0 | plain cord | `<id>__hilt0.glb` |
| | 1 | cord between steel ferrules | `<id>__hilt1.glb` |
| | 2 | finer, darker wrap divided by gold rings | `<id>__hilt2.glb` |
| | 3 | spiral-twisted steel bar banded in gold | `<id>__hilt3.glb` |
| `ore` | `steel`, `silver`, `graphite`, `bronze`, `frost` | tint of the blade's own surfaces (flats, groove, engraving, edge) | material only, at load; palette in manifest `_mods.ores` |
| `sharpened` | false / true | edge bevel from dull (roughness 0.52, darker) to polished (0.30, bright) | material only, at load |

`GearModel.spawn("ashbrand", 9.0, false, {"blade_tier": 3, "grip_tier": 2, "ore": "bronze", "sharpened": true})`.
The guard and pommel belong to the hilt part and do not change with tier: a mod never alters the silhouette, the
length or the role. `<id>.glb` is the whole sword at `default_mod` (blade 1, grip 1) for anything that just wants
the item.

**Pre-built or at load?** Geometry tiers are pre-built as parts, material mods are applied at load. Per basic sword:
8 part models x 2 detail levels = 16 files, about 0.55 MB; they combine into all 16 blade x grip states, times 5
ores, times sharpened = 160 looks without another file. Building every combination whole would be 16 x 2 files
and about 1.7 MB per sword; generating at load would mean porting the generator to GDScript (not done).
Cost of a modded sword at run time: two mesh instances instead of one, same surfaces.

Captures: `marketing/gear_bench/v2/mods_<id>.png` and `mods_<id>_close.png`.

## Shields

| | Round (light) | Heater (balanced) | Tower (heavy) |
|---|---|---|---|
| Size | 0.47 across | 0.49 x 0.67 | 0.52 x 0.88 |
| Board | 8 mm, dome radius 0.72 | 8 mm, wrap radius 0.47, 6 mm keel | 11 mm, wrap radius 0.42 |
| Rim | two-tone turned rim 38 mm (graphite inner ring, raised steel lip), 8 hex bolts | steel 30.5 mm, 4.2 mm proud, five graphite inlays, 10 rivets | steel 40 mm, 5.8 mm proud, five inlays, 16 hex bolts |
| Face | two stepped tiers, four seams, two engraved rings, hexagonal boss in a light-channel ring | enamel field with an engraved contour line, engraved spine under a hexagonal boss | graphite field, the same spine and boss, **two bolted reinforcing bars** |
| Rear | grip bar on posts, arm strap, low housing under a hexagonal cap | grip bar, strap, forearm pad | grip bar, wider strap, pad |
| Triangles | 4,908 / 1,372 | 4,212 / 1,212 | 5,448 / 1,276 |

Heater and Tower are one function (`kite_shield`) with different outlines and numbers; a **kite** proper and a
**segmented** shield would be two more parameter sets. Brushing on the round shield now runs round the centre
(polar UVs).

## Material palette

Shared tiling textures: 13 brushed / bead-blast / cord files at 256 px and 24 engraving files at 128 x 512 px.
Colour comes from the glTF base-colour factor; every textured surface renders through `pbr_clamp` (roughness floor 0.30).

| Material | Albedo (linear) | Metal | Roughness | Use |
|---|---|---|---|---|
| `steel`, `blade` | 0.45 cool grey | 0.9 | 0.49 - 0.59 | guards, pommels, rims; `blade` is the same set under its own name so ore can tint it |
| `blade_groove` | blade x 0.6 | 0.9 | as blade | plain centre groove |
| `engrave_<pattern>` | blade, lines 62% darker | 0.65 - 0.9 | 0.5 - 0.85 | engraved band |
| `edge` | 0.80 | 1.0 | 0.30 | the ground bevel (dull variant when not sharpened) |
| `graphite` | 0.09 blue-black | 0.8 | 0.46 - 0.54 | collars, bosses, Nightward's flats, tower field |
| `enamel` | 0.075 / 0.095 / 0.135 | 0.8 | as graphite | heater and round fields |
| `gold` | 0.43 / 0.30 / 0.12 | 0.9 | as steel | studs, rings, inlaid groove |
| `grip`, `grip_fine` | 0.07 / 0.05 cord | 0 | 0.76 - 0.9 | grips, shield grip bars |
| `leather` | 0.10 brown-black | 0 | 0.8 - 0.88 | straps, pads, shield linings |
| `glow` | emissive (0.38, 0.8, 1.0) x 1.0 when awake; dark graphite when not | - | - | one hairline per piece |

Steel is 90% metallic, not 100%, and a little rougher than in the first pass: with the viewer's all-round soft
box a flat now shows a gradient at every yaw (`steel_yaw_sweep_wayfarer.png`) instead of dropping to black or
clipping. One surface per material; swords have 6 - 8 surfaces, shields 6 - 7.

## What rarity and upgrades change, and what they do not

| Change | Never change |
|---|---|
| Engraving: none -> pattern -> pattern with studs -> gold-inlaid groove | Overall size, blade width, guard outline (the role silhouette) |
| Grip: plain cord -> ferrules -> fine wrap and gold rings -> twisted bar | Grip length |
| Blade metal (ore) and edge polish | Gloss beyond the 0.30 floor |
| Light channel: only rare and above have one; dark until awakened | The number of channels: one |

## Known limits (second pass)

- Guards and pommels are flat plates: sculpted in outline, not in relief. There is no surface modelling on a guard's
  face beyond chamfers, bosses and studs.
- Engraving is a normal/albedo pattern in a 0.5 mm recess, not cut geometry; it tiles every 7 - 14 cm.
- The whole blade is one material tint: no heat gradients, no wear masks, no per-vertex colour.
- Pierced openings are diamonds only (a consequence of lofting); round or slotted piercings need a different blade build.
- Plate caps are ear-clipped: fine for shading (they are flat) but the triangles are long and thin.
- Fittings pass through each other where they meet instead of being welded.
- The rig's off-hand is posed open, so fingers pass through a shield board when the hand is on the grip bar.
- Low models and the 1.15 rig scale have not been checked in a duel; nothing has run on a device.
