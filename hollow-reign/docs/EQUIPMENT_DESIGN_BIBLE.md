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

## Hybrid swords: our blade in a generated hilt (live since 2026-11-27)

The owner found the flat plate guards too plain. Every sword is now drawn as a **hybrid**: the code-built blade
(profile, engraving, forge tiers, ore, light channel) seated in one **image-to-3D hilt** (guard + grip + pommel) made
from a concept image. Ids do not change for callers: `GearModel.spawn("wayfarer")`, `info()`, `hold()` and `reach()`
answer with the hybrid (manifest entry `wayfarer_h`: `hybrid`, `base`, `hilt_source`). The code-built swords are
still built and are reached with the dev arg `--oldhilts` (every sword) or `{"old_hilt": true}` in a spawn's mod.
Captures: `marketing/gear_bench/v3_hybrid/` (the two-sword trial, code-built beside hybrid) and `v4_hybrid_all/`.

**Files per sword.** `<id>_h__hilt0.glb` + `_lod` (baked hilt and its clustered low model), `<id>_h__blade<n>.glb` +
`_lod` (the blade at the hybrid's seat: tiers 0 - 3 for the four basic swords, the default tier for the rest),
`<id>_h__rings2/3.glb` (basic swords), and three 1K textures in `gear/hilts/` (`<src>_color|normal|orm.jpg`, VRAM
compressed like the knights' textures). The generated sources are kept outside the imported tree in
`art/gear_hilts_src/`, so their embedded 2K textures are not imported again.

**Alignment recipe** (`HYBRIDS` and `bake_hilt()` in `tools/gear_gen.py`; `python3 tools/gear_gen.py --hybrids [id ...]`):
1. A generated hilt arrives 1 unit long, pommel at -Y, guard along Z, depth along X. Slice it along Y and read off the
   pommel, the grip (the long run of near-constant radius: `grip`, `rg`), the collar where it widens, the guard, and
   the cup the blade leaves from (`seat`, the top unless the model includes a blade stub).
2. Scale. `r / rg` makes the grip a hand's thickness (`r` 12.8 - 15.8 mm by role). Where the generated grip is fat for
   its guard, give a larger `sc` instead: the guard is sized by it and everything below the collar is slimmed about the
   grip's axis back to `r` (Ashbrand, Oathbreaker, King's Remnant, Cold Resolve, Nightward, Twin Relics).
3. `grip_len`: the grip span alone is stretched or squeezed along Y to the length the role wants (one palm 0.10 for
   the light sword, 0.30 for the greatsword). The hand's centre, the origin, is 5 cm under the collar.
4. `axis_z` for one-sided guards whose bounding box is not centred on the grip (Veilcutter, Nightward, Twin Relics);
   `turn = -1` where the knuckle side has to be turned to the manifest's convention (Veilcutter's long arm at -X;
   Nightward's half-disc and Twin Relics' knuckle bar at +X; the left twin is the same model with `scale.x = -1`).
5. `flatten`: guards that came out too deep front to back are squeezed in depth above the grip (x 0.62 - 0.7).
   `blunt`: pulls in the last part of the guard arms (Wayfarer).
6. Seat: the blade starts 13 mm below the top of the cup, so its foot is inside the hilt: no gap, nothing coplanar.
   If the foot is wider than the cup, narrow the first width control point (`P`; Wayfarer 23.8 -> 21.2 mm).
7. Metal match: the bake averages the hilt's albedo over its metal texels and writes `blade_tint` (a near-neutral
   grey x 0.58 - 0.79, so gold inlays do not turn blades bronze) and `blade_rough_max` 0.42. Ore tints multiply on top.
8. Low model: vertex clustering on an 8.5 mm grid, same textures.

| Sword | Scale | Grip (m) | Guard span | Hilt tris / low | Sword tris / low | Notes |
|---|---|---|---|---|---|---|
| Wayfarer | 0.255 | 0.125 | 0.200 | 4,938 / 1,232 | 5,962 / 1,616 | arm tips pulled in 50%, still pointed |
| Silver Vow | 0.312 | 0.100 | 0.163 | 4,768 / 1,131 | 5,824 / 1,547 | depth x 0.65 |
| Ashbrand | 0.260 | 0.148 | 0.177 | 4,946 / 1,366 | 5,970 / 1,782 | slimmed grip, depth x 0.62 |
| Veilcutter | 0.260 | 0.118 | 0.200 | 4,896 / 1,375 | 6,648 / 1,783 | knuckle bow at -X |
| Oathbreaker | 0.360 | 0.300 | 0.216 | 4,888 / 2,318 | 6,200 / 2,750 | grip stretched 1.5x for two hands; off-hand at -0.165 |
| Eternal Edge | 0.3375 | 0.135 | 0.128 | 4,862 / 1,297 | 6,190 / 1,713 | model includes a collar stub: seat at 0.44 |
| King's Remnant | 0.300 | 0.130 | 0.169 | 4,720 / 1,417 | 6,064 / 1,833 | slimmed grip |
| Cold Resolve | 0.220 | 0.115 | 0.101 | 4,862 / 1,294 | 5,854 / 1,702 | collar is a solid block: weakest of the ten |
| Nightward | 0.240 | 0.112 | 0.107 | 4,774 / 993 | 5,600 / 1,433 | turned; half-disc on the edge side |
| Twin Relics | 0.200 | 0.110 | 0.142 | 4,876 / 1,218 | 6,172 / 1,634 | turned; knuckle bar outward |

**Forge mods on a hybrid.** `blade_tier`, `ore` and `sharpened` work unchanged. A generated grip cannot change form,
so `grip_tier` 2 and 3 lay two or four thin gold rings over it (`__rings` parts, sized from the hilt's own radius at
each height); tiers 0 and 1 look the same. If handle upgrades must show more, generate only guard and pommel and keep
the code-built grip between them.

**Cost, before and after the phone pass.**
- Textures: 2K colour / normal / ORM per hilt (3.3 - 3.7 MB each as files) -> 1K JPEG (0.40 - 0.54 MB each, 4.7 MB
  for all ten), a quarter of the texels in memory, VRAM compressed.
- Disk in the imported tree: `gear/hilts/` was 76 MB (ten source GLBs with embedded textures plus the extracted
  copies) and is now 4.7 MB; each baked hilt GLB is about 160 kB and its low model 25 - 70 kB.
- Triangles at the 9 m switch: hilt 4,700 - 4,950 -> 720 - 2,320; whole sword 5,600 - 6,650 -> 1,430 - 2,750.
- Draw calls: the hilt is one surface; a hybrid is 5 - 7 draws, one or two fewer than a code-built sword.

**Known weaknesses.** Grips are soft (cord comes back as banded leather); the generated metal is glossier than our
steel and blooms on thin edges; Wayfarer's arms still end in points; Cold Resolve's crystal collar came back as a
solid faceted block; Oathbreaker's centre ornament is stretched with its grip; the low models are clustered, so
their UV seams are rough close up (they are only drawn beyond 9 m).

**A new sword this way.** One hilt concept (hilt only, straight-on, plain grey ground, an empty cup where the blade
enters, rounded ends, no blade), image-to-3D at about 5k triangles into `art/gear_hilts_src/`, one `HYBRIDS` line from
the slices, then look at it: hilt close-up, silhouette beside the others, in the hand. 30 Tripo credits + about 1.25
image credits each.

## Known limits (second pass)

- Guards and pommels are flat plates: sculpted in outline, not in relief. There is no surface modelling on a guard's
  face beyond chamfers, bosses and studs.
- Engraving is a normal/albedo pattern in a 0.5 mm recess, not cut geometry; it tiles every 7 - 14 cm.
- The whole blade is one material tint: no heat gradients, no wear masks, no per-vertex colour.
- Pierced openings are diamonds only (a consequence of lofting); round or slotted piercings need a different blade build.
- Plate caps are ear-clipped: fine for shading (they are flat) but the triangles are long and thin.
- Fittings pass through each other where they meet instead of being welded.
- On the rig (gear pass): the shield hand closes on the grip bar and the forearm lies in the strap (`pose_review` "fingers" = 0);
  the Tower shield is worn at life size (`GearModel.RIG_SCALE`), the rest at 1.15. Seen in duel frames on the software
  renderer; nothing has run on a device.

## Proposal: three armour weight classes from the male v4 concepts (design only, 2026-11-27)

> **Status: proposal.** Nothing here is coded, no fight changes, nothing is bought. The owner chose concept B for the
> starting suit ("maybe ability to be all 3 and roll and power changes"). B is bought and wired (`knight_m_v4`); A and C
> exist only as concepts (`art/concept/knight_m_v4a.png`, `knight_m_v4c.png`, sheet
> `marketing/armor_finish_pass/male_v4_concepts_A_B_C.jpg`).

**The idea.** One body, three silhouettes, three ways to play. A = **medium** (the baseline: today's numbers), B = **light**
(the starting suit: fast, brittle), C = **heavy** (slow, hard to shift, hits harder). Today's item data has a per-piece
`weight` (`gen_equipment.py` `WEIGHTS`: light +2% regen / -1% swing cost, heavy -2% regen / +1% swing cost / -1.2% guard
cost per piece) and `Stats.compute` already derives a `burden` word from the worn pieces. That is too small to feel and
has no say over the roll, so the class below is a **whole-suit bundle**, scaled by how many of the six pieces are of the
class (so a mixed loadout lands between, as `burden` does now). Numbers are for six pieces; each piece carries 1/6.

| | **B light (starting suit)** | **A medium** | **C heavy** |
|---|---|---|---|
| Roll distance (`ROLL_DIST` 2.55 m; sidestep `DODGE_DIST` 1.25 m) | x1.12 (2.85 m; 1.40 m) | x1.00 | x0.88 (2.25 m; 1.10 m) |
| Roll / dodge speed (`DODGE_TIME` 0.55 s + `ROLL_EXTRA_TIME` 0.35 s) | -0.04 s dodge, -0.05 s roll extra | baseline | +0.05 s dodge, +0.07 s roll extra |
| Dodge recovery (the rise back into guard, `ROLL_UP` tail) | -10% | baseline | +12% |
| Stamina cost of a dodge / roll (`DODGE_COST` 14, `ROLL_EXTRA_COST` 8; same multiplier as a shield's `mobility`) | x0.85 (11.9 / 6.8) | x1.00 | x1.20 (16.8 / 9.6) |
| Max stamina | +8 | +0 | -6 |
| Stamina regen (`regen_pct`) | +6% | 0 | -6% |
| Damage taken (`defense`, `mitigation = d / (d + 110)`) | defense x0.75 | x1.00 | defense x1.40 |
| Poise (the player's; see below) | x0.80 | x1.00 | x1.40 |
| Attack power (`attack_pct`) and swing cost (`swing_cost_pct`) | 0% power, -3% swing cost | 0 / 0 | +8% power, +4% swing cost |
| Guarding cost (`block`) | 0 | 0 | +0.04 (cheaper) |

**Fit with today's numbers.** The Crownless starter set (`a_worn_*`) is 15 defence (helm 3, chest 6, gauntlets 2, legs 4;
shoulders and boots add 1 each at most), about 13% mitigation: B's x0.75 takes that to about 10%. The garrison set
(36 defence, 25%) is the next medium rung; black (45) and ash (45) are the light and heavy rungs in `FAMILIES` today.
With the class multiplier on a 36-defence rung: light 27 (20%), medium 36 (25%), heavy 50 (31%). Light takes about 6%
more damage than medium for the same rung, heavy takes about 8% less; the price is paid in the roll, which is the
game's main defence. Stamina: a 100-stamina knight rolls (14 + 8 = 22) 4.5 times from full in medium, 5.3 times in
light (18.7), 3.8 times in heavy (26.4). Attack: a 21-damage sword becomes 22.7 in heavy (`attack_pct` +8%), unchanged
in medium and light; light makes it up in swing cost and speed of recovery. None of these touch `data/items.json`
ids or prices: they are a class table read by `Stats.compute`, next to `WEIGHTS`, and `gen_equipment.py` would write it.

**Poise needs one new thing.** `duel_sim.gd` has poise only for foes (`b_poise`). The player has `max_hp`, shield
charges and stamina but nothing that makes a heavy knight stand through a light blow. If the owner wants that line of
the table, the smallest version is a player flinch threshold: a hit below `poise x 8` HP does not interrupt a swing or
a guard (light 6, medium 8, heavy 11), with the staggering blows unchanged. Without it, drop the row and fold it into
the damage-taken numbers (heavy x1.40 becomes x1.50).

**Role, not just numbers.** Light is the duellist: rolls through a heavy foe's string, wins by not being hit, loses to
anything it cannot dodge (breath, sweeps). Medium is the all-rounder the early game is balanced around. Heavy trades
the roll for the stand: it can take a blow and swing back, and punishes a foe that is already staggered. The Armory
should show the class as one line (as `role_text` does for swords): "Light: rolls further and recovers quicker,
tires less, takes more from every blow."

**Cost to get A and C.** A knight body is 135 Tripo credits = **$1.35** (model 110, rig 25; rig check free), the same
per body and per attempt as v4. Male A and C: **$2.70**. If the female body also gets three classes: three concepts
(about 1.25 Higgsfield credits each) and three bodies, **$4.05**; all six: **$8.10**. Everything after the purchase is
free: `tools/armor_split.gd` fits each to the same host skeleton, splits it into the six parts (so A's and C's chests,
shoulders, gauntlets, legs and boots become mixable pieces like every other suit), and `ArmorParts` finishes it. Risk
to state honestly: v4 needed no per-body clean-up, but every generated suit has needed a look for stretching and
clipping, and a heavy C (broader pauldrons, thicker thighs) is the likeliest to clip the shield arm and the roll. One
attempt each: a failed task is recovered by task id; a bad result is reported, not rebought. Current allocation after
v4: $31.50 + $1.35 = **$32.85** of $100 (see `docs/SPENDING_LOG.md`).
