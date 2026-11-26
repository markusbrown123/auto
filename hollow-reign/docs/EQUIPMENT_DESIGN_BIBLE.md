# Equipment design bible

How swords and shields are designed and built after the owner's Addendum 3 brief (2026-11-26). The five benchmark
pieces in `assets/models/gear/` are the reference; everything else is meant to be produced from parameter sets in
the same generator. Judged on software-rendered captures (`marketing/gear_bench/`); nothing has been seen on a device.
The owner's two reference pages could not be opened from the build machine (hosts not reachable), so this language
comes from the written brief and from real arms, not from those pages.

## The language in one paragraph

Real swords first. Every blade has the proportions of a historical type and would work as one; the science-fantasy
part is how it is *made*: machined chamfers instead of forged rounding, fittings that meet in clean seams, at most one
hairline of light. Roughly 70% medieval, 30% engineering. Nothing is spiky, nothing is oversized, nothing is chrome.
Rarity buys precision and restraint, never mass: the legendary blade is the slimmest of the three.

## Pipeline

- `tools/gear_gen.py` (Python + numpy, no Blender) writes `assets/models/gear/<id>.glb`, `<id>_lod.glb`, the shared
  detail textures in `gear/tex/` and `gear_manifest.json`. Run it, then `tools/check.sh` to import.
- `src/chars/gear_model.gd` (`GearModel.spawn(id)`) loads a piece with its low model on a visibility range and passes
  it through `Look.sanitise(root, "weapon")`. `GearModel.info(id)` returns the manifest entry.
- `--screen=gearbench` (`src/dev/gear_bench.gd`) is the viewer; its header lists the switches.
- Modelling primitives: `loft` (rings skinned into a closed solid), `lathe`, `block` (all-edges-chamfered box),
  `blade`, `guard_bar`, `grip`, `collar`, `board` (shield body from an outline), `arm_strap`, `hand_grip`, `rivet`.
- **Hard edges are explicit.** Every face carries a smoothing group; normals are averaged only within a group.
  A blade's flats, bevels and fuller are separate groups, so a 7 degree ridge is still a crisp line. Do not switch to
  angle-threshold smoothing: blade facets are far below any usable threshold.
- UVs are in metres x 16 (one 256 px tile = 6.25 cm). Blades are planar-mapped from the flat; grips are cylindrical
  (the cord wrap tiles round them); everything else is box-mapped with the brushing along the part's length.

## Conventions (what the rig relies on)

| | Swords | Shields |
|---|---|---|
| Units | metres, life size | metres, life size |
| Origin | centre of the main hand on the grip | centre of the hand-grip bar |
| +Y | toward the tip | up |
| X | guard runs along X | +X is the bearer's right (grip side); the arm strap is at -X |
| Z | flat of the blade faces +-Z (thin axis) | the FRONT faces -Z (the rig's "outward"); straps on +Z |
| Manifest | `tip` (hand to tip), `pommel` (hand to pommel end), `off_hand` (second hand, two-handers), `grip_clear`, `guard_span` | `board_centre` (centre of the board from the origin), `width`, `height`, `strap_x`, `thickness` |
| `rig_scale` | 1.15 | 1.15 |

`rig_scale`: the knights are heroic figures with large gauntlets; life-size steel looks like a toy in their hands.
The rig already draws swords at about 115% (`PropModel.LENGTH.sword` 1.12 m against a 0.97 m arming sword), so pieces
are modelled true and scaled once, at the attach point.

## Sword proportions

All lengths in metres at life size. "Grip clear" is the wrapped length between guard and pommel; a palm is 0.09.

| | Arming (Wayfarer) | Hand-and-a-half (Eternal Edge) | Greatsword (Oathbreaker) |
|---|---|---|---|
| Overall | 0.97 | 1.085 | 1.61 |
| Blade | 0.80 | 0.865 | 1.21 |
| Blade width at guard | 0.053 | 0.044 | 0.060 (0.054 across the ricasso) |
| Width where the tip begins | 0.032 at 84% | 0.033 at 78% | 0.037 at 88% |
| Thickness guard -> tip | 6.2 -> 3.2 mm | 6.6 -> 3.4 mm | 8.8 -> 4.2 mm |
| Edge bevel width | 4.2 mm | 3.6 mm | 5.2 mm |
| Grip clear | 0.106 (one palm + 1.6 cm) | 0.162 (palm and a half) | 0.302 (two palms + riser) |
| Grip section (w x t) | 30 x 24 mm | 27 x 23 mm | 32 x 26 mm |
| Guard span | 0.196 (3.7x blade width) | 0.164 (3.7x) | 0.316 (5.3x) |
| Guard bar section at centre | 14 x 19 mm | 13 x 19 mm | 17 x 24 mm |
| Pommel | wheel, 47 mm across, 27 mm thick | hexagonal cap, 32 mm, 40 mm long | faceted pear, 47 mm, 74 mm long |
| Triangles (detail / low) | 1,744 / 572 | 1,932 / 864 | 1,716 / 768 |

Rules that hold for every sword:
- Blade thickness is about 1.3x a real blade's, never more. It is the faceting that stops a blade reading as
  cardboard, not the bulk.
- **Distal taper** (thickness) and **profile taper** (width) are both always present; the tip is an ogive that comes
  to an actual point, with thickness falling to zero over its last third.
- The grip is never shorter than palm + 1.5 cm per hand. The guard is 3.5x - 5.5x the blade's width and no thicker
  than the grip. The pommel is no wider than the grip is long divided by two.
- Guards end blunt (a small chamfered stop), not in points. Forward sweep is at most 1.5 cm and is straight, a
  chevron, never a crescent or hook.
- No holes through a blade, no serrations, no secondary blades, no asymmetry in X.

## Cross-sections

Built by `blade(prof, seg_mats, seg_groups, stations)`: `prof(s)` returns one quadrant from the edge to the centre.

| Section | Points edge -> centre | Used for |
|---|---|---|
| Fullered lenticular | edge, bevel shoulder (52% of thickness), fuller lip, 3-point trough | Wayfarer; fuller 15.6 mm wide, 1.2 mm deep, closes to a point at 60% |
| Ricasso + fullered | the same, with a 3 mm blunt edge and a narrower blade over the first 10.5%, blending out over 3% | Oathbreaker; fuller 21 mm wide, 3% to 56% |
| Rail and core | edge, shoulder, rail lip, 0.55 mm step down, core, light channel wall, channel floor | Eternal Edge; graphite core 15.6 mm wide closing at 70%, channel 2.2 mm wide from 7.5% to 60% |
| Diamond | edge, shoulder, ridge (fuller width 0) | what every section becomes beyond its fuller; daggers, Veilcutter |
| Hexagonal | edge, shoulder, wide flat lip, no trough | Nightward, cleavers |

## Shield proportions

| | Heater | Round (technological) |
|---|---|---|
| Size | 0.49 wide x 0.67 tall | 0.51 across |
| Outline | flat top lifted 12 mm at the middle, 34 mm corner radius, straight shoulders to 31 cm, then `x = hw(1 - t^2.15)` to a point | circle |
| Curvature | wrapped round the arm, radius 0.47; shallow rounded keel 6 mm; slight top-to-bottom dish | dome, radius 0.72 (46 mm of rise) |
| Board | 8 mm | 9 mm |
| Rim | steel, 30 mm wide, 4.2 mm proud, chamfered both sides, 10 rivets | steel, 40 mm, 4.5 mm proud, 8 hex bolts |
| Face | graphite-blue enamel, one 1 mm gold line inside the rim | two stepped tiers (graphite over enamel) cut by four seams, hub ringed by one 3.5 mm light channel and a gold ring |
| Rear | grip bar 104 mm on two steel posts at the origin; leather arm strap 42 mm wide 20.5 cm toward the elbow, on sheared steel plates; forearm pad between | the same bar and strap; a hub housing at the centre |
| Hand clearance | 35-40 mm between bar and board | 40 mm |
| Triangles (detail / low) | 3,524 / 1,100 | 4,012 / 1,252 |

Other classes, not yet built: **kite** (heater outline stretched to 0.95 tall, `y_mid` raised, same rim table),
**curved technological tower** (rectangular outline with 6 cm corner radii, wrap radius 0.38, seams as horizontal
grooves), **segmented** (round or kite board whose field is three overlapping `board` plates with 3 mm steps).

## Material palette

Shared 256 px tiling textures (13 files, 0.5 MB on disk); colour comes from the glTF base-colour factor.

| Material | Albedo (linear) | Metal | Roughness | Detail | Use |
|---|---|---|---|---|---|
| `steel` | 0.45 cool grey | 1.0 | 0.47 - 0.57 | brushed along the part, normal scale 0.22 | blade flats, guards, pommels, rims |
| `edge` | 0.80 | 1.0 | 0.30 (the class minimum) | none, untextured | the ground bevel only |
| `fuller` | steel x 0.62 | 1.0 | as steel | stronger brushing | fuller trough |
| `graphite` | 0.09 blue-black | 0.8 | 0.46 - 0.54 | bead-blast | cores, collars, tech plates |
| `enamel` | 0.075 / 0.095 / 0.135 | 0.8 | as graphite | bead-blast | shield fields |
| `gold` | 0.43 / 0.30 / 0.12 antique | 1.0 | as steel | brushed | lines and rings only; never a whole part |
| `grip` | 0.07 graphite cord (Oathbreaker: dark brown) | 0 | 0.76 - 0.9 | cord wrap, 8 turns per 3.8 cm | grips, shield grip bar |
| `leather` | 0.10 brown-black | 0 | 0.8 - 0.88 | fine grain | straps, pads, heater lining |
| `glow` | emissive (0.38, 0.8, 1.0) x 1.0 | 0 | 0.6 | none | one hairline per piece at most |
| worn steel (variant) | 0.33, faint warm stains along the blade | 0.85 - 1.0 | 0.5 - 0.7 | brushing + sparse pits | Oathbreaker; any "weathered" blade |

Each material is one surface (one draw). Benchmark pieces have 4 - 7 surfaces. Gold covers under 2% of any piece.
Emission is below the bloom threshold's blow-out point: the channel reads as a pale line, not a neon tube.

## What rarity changes, and what it does not

| Changes | Does not change |
|---|---|
| Construction: one-piece forged look (common) -> separate fitted parts with seams (rare) -> composite blade, inlaid core (legendary / relic) | Overall size. A legendary is within 10% of the common sword of its class |
| Edge and chamfer precision: wider, softer bevels at the bottom; narrow exact ones at the top | Silhouette complexity. No added spikes, wings, hooks or holes at any tier |
| Finish: worn or plain satin -> even satin -> satin with polished bevels and one gold line | Gloss. Roughness never goes below 0.30; higher tiers are *more* even, not shinier |
| Accent: none (common, uncommon) -> gold rings (rare) -> gold + one light channel (legendary, relic) | Number of light channels: one, 2 - 3.5 mm wide |
| Grip: cord -> cord with risers -> divided by fitted rings | Grip length rules, guard rules |
| Recall: only pieces with a `glow` surface are Recalled; the rest are drawn and sheathed | |

## Parameter sets for the remaining pieces

Not built yet. Each is a new `build_*` in `gear_gen.py` that calls the same primitives with these numbers
(half-widths `w` in mm at guard -> at tip start; `t` thickness guard -> tip; `L` blade; all life size).

| Blade | Class / rarity | Blade | Section | Guard | Grip / pommel | Materials and accent |
|---|---|---|---|---|---|---|
| **Silver Vow** | sword, uncommon | L 0.82, w 25 -> 15 at 82%, t 6.4 -> 3.2, bevel 4.0 | fullered lenticular, narrow fuller 10 mm to 72% | straight, span 0.21, section 13 x 18, end_scale 0.6, small disc stops (flare 0.25) | grip 0.11, steel riser at mid; wheel pommel 45 mm with a recessed gold disc | bright even `steel`, `grip` in pale grey cord (0.42, 0.43, 0.46); one gold disc |
| **Ashbrand** | sword, rare | L 0.80, w 27 -> 17 at 80%, t 7.0 -> 3.4, bevel 4.6 | hexagonal, flat 40% of width, no fuller | span 0.19, sweep 0.010 chevron, section 15 x 20, `graphite` | grip 0.115 dark brown; pear pommel 6 flats, 55 mm | worn steel variant darkened x 0.8 with a heat-blue tint toward the tip (base-colour gradient by vertex row is NOT supported yet: use the darker worn set); no gold, no glow |
| **King's Remnant** | sword, rare | L 0.86, w 26 -> 15 at 84%, t 6.6 -> 3.2, bevel 4.0 | fullered, double narrow fuller (two 5 mm troughs 6 mm apart) to 45% | span 0.23, section 14 x 19, steel with one gold seam block as on Eternal Edge | grip 0.14 (hand and a half) with two gold rings; wheel pommel 50 mm, gold recessed centre | `steel`, gold under 2%; worn set on the guard and pommel only |
| **Cold Resolve** | sword, rare | L 0.84, w 23 -> 15 at 80%, t 6.0 -> 3.0, bevel 3.4 | diamond with a 0.6 mm flat-bottomed channel 3 mm wide to 55% | span 0.17, straight, section 12 x 17, squared ends (flare 0) | grip 0.12 in pale cord; long hexagonal cap 36 mm | cool steel (base factor 0.93, 0.97, 1.0); channel in `glow` recoloured to frost (0.55, 0.8, 1.0) x 0.6; no gold |
| **Nightward** | sword, uncommon | L 0.78, w 28 -> 20 at 86% (broad, short tip p 1.5), t 6.8 -> 3.6, bevel 5.0 | hexagonal, flat 50% | span 0.20, section 16 x 22, end_scale 0.8, heavy block | grip 0.11 graphite; faceted pear 8 flats 50 mm | flats in `graphite` (blackened blade), `edge` bright: the only sword whose flats are dark; no accent |
| **Veilcutter** | sword (light), legendary | L 0.90, w 18 -> 12 at 76% (long needle tip p 2.3), t 6.0 -> 2.8, bevel 3.0 | diamond over a rail-and-core root: core 8 mm wide closing at 40%, channel to 34% | span 0.14, sweep 0.008, section 11 x 16, `steel`; chevron collar 45 mm | grip 0.15 with three gold rings; hexagonal cap 28 mm | `steel`, `graphite` core, one `glow` channel; the narrowest blade in the game |
| **Twin Relics** | dual, relic | two mirrored blades L 0.62, w 21 -> 14 at 78%, t 5.6 -> 2.8, bevel 3.4 | rail and core, core to 60%, channel 10% - 52% | span 0.12, sweep 0.012, guard offset: long arm 0.07 on the knuckle side, 0.05 on the other (mirror the pair in X; this is the one allowed asymmetry) | grip 0.105; cap 28 mm; a gold ring each end | as Eternal Edge; left blade's channel may take a second relic colour |
| Greatswords beyond Oathbreaker | rare / legendary | L 1.15 - 1.25, w 28 - 31 -> 18 - 20, ricasso 9 - 11% | Oathbreaker's, or rail and core with the core closing at 60% | span 0.30 - 0.34, sweep <= 0.015 | grip 0.29 - 0.31 with a riser; no lugs wider than the guard | per rarity table |

Estimated cost per new sword: 1,600 - 2,100 triangles, 500 - 900 low; no new textures unless a new material class
is introduced.

## Known limits (benchmark pass)

- Rim and hub brushing on the round shield runs straight across, not round the ring (box-mapped UVs).
- Brushed steel is a normal/roughness detail, not true anisotropic shading; at a grazing key light a flat can still
  clip to white in the studio viewer.
- No per-vertex colour, so no heat-tint gradients or edge wear masks yet; "weathered" is a tiling texture.
- Fittings pass through each other where they meet (blade into guard block) instead of being welded; invisible at
  any normal distance, wasteful by a few dozen hidden triangles.
- The rig's off-hand is posed open: with the hand on the shield's grip bar the fingers pass through the board
  (see `marketing/gear_bench/hand_wayfarer_heater_front.png`). The integration pass must close the left fist.
- The low models are built by the same code with fewer stations and segments; they are not yet checked at their
  switch distance in a duel.
