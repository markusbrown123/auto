# Modular armour: what the existing suits can do

> **Male host is now v4 (2026-11-27).** The male `crownless` host is `knight_m_v4.glb` (concept B, `art/concept/knight_m_v4b.png`); all
> ten male suits were re-fitted to its skeleton with `armor_split.gd --bodies=m --noflex --nohood` (no flex layer or hood files: its
> undersuit is already dark; `--bodies=` limits a rebuild to one body). `--v3m` (`ArmorParts.v3m`) wears the previous male set whole
> from `assets/models/parts_v3m/` on `knight_m_v3.glb`. The female host is unchanged. `FINISH_COAT` is unchanged and reads correctly on v4.
> Sheets: `marketing/knight_v4/`.

> **Integrated (2026-11-26, "gear on rig" pass).** The game now wears parts. What changed against the study below:
> - **Base body = the sleek benchmark knights** (`knight_<body>_v3.glb`, suit id `crownless`). `tools/armor_split.gd`
>   fits every suit to *their* skeleton (`--host=crownless`, the default; `--host=base` rebuilds the study's set), the
>   undersuit is their body, and an empty slot wears their piece. Why: against the old base the v3 knights have a
>   13-16% longer trunk, 11-17% longer arms and 11-14% wider shoulders, so conforming them would have squashed the
>   benchmark; as host they are untouched (identity fit) and the nine older suits are stretched instead, inside the
>   conform's 0.8-1.25 clamp. Looked at both ways (set and mix, both bodies): no holes either way.
> - `FighterRig.build` dresses from `look.parts` (`Duel.player_look()` builds it from `Game.appearance_loadout()`);
>   `FighterRig.wear_parts(loadout)` swaps pieces on a standing knight (the Armory); `ArmorParts.resolve` fills empty
>   slots with the base piece and settles the two linked pieces (`LINK_POLICY`: the Vigil hood brings its mantle,
>   Garrison pauldrons give way over another cuirass).
> - The two gaps are closed: `SkinDriver.measure_parts` takes floor contact, blade clearances and hit volumes from the
>   worn part meshes (cached per part); cinematic actors build through `Duel.player_look()` and inherit all of it.
> - Tint, flash and rim reach the parts through `SkinDriver.tint/flash/rim` (and `Look.set_param` on the skin root).
> - Suit textures are VRAM-compressed (import settings of the `knight_*_{Color,NormalGL,ORM}` files: S3TC/BPTC for
>   the desktop renderer, ETC2 for iOS). Bench frame, male, software renderer: six parts from six suits
>   **197.5 MB -> 106.4 MB**; one suit 101.3 -> 90.1 MB; an extra suit worn costs about 2.7 MB instead of 16.
> - `--oldlook` (or `FighterRig.old_look = true`) restores the whole-suit swap and the first weapon models.

> **Finish pass, third (2026-11-27; the owner: "dont do the neon glow more like these references").** The direction is
> monochrome: pale grey, gunmetal and black; no coloured light; tone-on-tone etched ornament; a faceplate under a dark
> cloth hood. This is the default now. The second pass (below) is kept whole behind `--neon`.
> Sheets: `marketing/armor_finish_pass/v3/`.
> - **No light.** No lines of light, lit visor, cast lights, vents, sheen or pulse unless `--neon`. The eye slot is dark.
>   The hips' flex layer has no seam of light.
> - **Plate.** `FINISH_COAT`: grey satin, about a quarter metal, the suit's creases and seams dark as before (`wear`),
>   a pale line along the plates' borders (`trim`).
> - **Etched ornament** (`etch`, in `src/fx/armor_part.gdshader`), each only a little darker and rougher than the plate
>   so it shows as it catches the light: ripples like pattern-welded steel on the breast, a fine weave on the pauldrons,
>   ruled lines down the shins, and the house's small sigil (an open ring, a diamond, a stem) incised on the breast and
>   the brow.
> - **Faceplate.** The same helm mesh, refinished: two cut lines from the brow down across the cheeks and one down the
>   chin, with the planes between them shaded a step apart. They are painted, not modelled: the helm is as smooth as it
>   was and reads faceted only from the front.
> - **Hood and cowl** (helm slot only). `tools/armor_split.gd` `_hood` builds `<body>_crownless_hood.res` (about 3,400
>   triangles): a shell measured off the helm, open in an arch round the faceplate, gathered into a roll round the neck,
>   with one small ring clasp; carried by Head, Neck and Spine2 blended by height; kept inside the shoulder joints.
>   `ArmorParts` draws it (`HOOD_CODE`: matte dark cloth, a weave in the normal that fades with distance) while the
>   benchmark helm is worn. `--nohood` (or `ArmorParts.hood_on = false`) shows the helm bare, as generated. It is a
>   skinned shell, not simulated cloth: it does not swing, and where the cowl meets the collar it can sink into the
>   plate. No helm was generated or bought.
> - **Tunables:** `FINISH_COAT` (`coat_color`, `coat_rough`, `coat_metal`, `edge_shine`, `wear`, `etch`, `trim`),
>   `HOOD_CLOTH`, `HOOD_CLASP`; for `--neon`: `FINISH_NEON`, `GLOW`, `FX_*`. `--chrome` is still the full revert (no coat,
>   no ornament, no hood).

> **Finish pass, second (2026-11-27; the owner: "paler grey, more detail like armor but still futuristic, stronger design
> of shapes circles, logos, cyan and maybe pink with girl with a clean glow and effect, light, shine, smoke, air coming
> out, no cloak").** Material and a few light effects; no mesh changed, the silhouette is the generated suit's. The
> first finish pass (matte white, three small motifs) is superseded. **Since the third pass this is what `--neon` shows,
> not the default.** Sheets: `marketing/armor_finish_pass/v2/`.
> - **Plate.** `ArmorParts.FINISH_COAT` (merged into the `crownless` finish) coats every texel that is not undersuit in
>   pale cool grey satin, a fifth metal, and draws the suit's own sculpted detail through it: its creases and panel
>   seams dark (`wear` 0.85), its edges catching the light (`edge_shine`). Chipping and scuffs stay off (`wear_edge` 0).
>   The undersuit and the hips' flex layer stay dark.
> - **Designs**, drawn by the shader in dark metal and in lines of light. Every part carries UV2 written by
>   `tools/armor_split.gd`: trunk and head by where they are on the standing body; upper arms, forearms and shins by
>   where they are on the limb itself (round it and along it, from the bone), so a design there follows the limb in any
>   pose. Breast: the house's mark (an open ring round a ring of light, a diamond, a line of light falling from the gap,
>   ticks, strokes, two small rings, two side panel lines). Brow: a ring of light; crown: a dark line. Back: a ring
>   round a ring of light, the spine's line of light with three nodes. Pauldrons: a ring round a ring of light over a
>   chevron. Forearms: a line of light between dark strokes, a ring at the elbow end. Shins: a diamond under the knee
>   and a line of light down the front. Thin dark panel breaks round each limb. `ArmorParts.BODY_MARKS` says where the
>   breast, spine and visor are on each body.
> - **One glow colour per body** (`ArmorParts.GLOW`): cyan on the male, pink on the female. The visor, every line of
>   light, the hips' seam, the vents and the cast light all take it.
> - **Live effects.** In the shader (`fx`): the lights breathe slowly, and a sheen passes up the plate every seven
>   seconds. In `ArmorParts` (`_build_fx`): two small unshadowed lights (visor and breast, `FX_LIGHT`), and three vents
>   (behind each shoulder and at the nape) leaking thin vapour, eight small particles each at most, a third of that when
>   idle (`FX_VENT`); `ArmorParts.vent()` opens them for 0.9 s and `FighterRig.dodge`/`roll` call it. Reduce motion: no
>   vents, no breathing, no sheen. Performance preset: no vents and no lights. Only while the benchmark breastplate is worn.
> - **Tunables, all at the top of `src/chars/armor_parts.gd`:** `FINISH_COAT` (`coat_color`, `coat_rough`, `coat_metal`,
>   `edge_shine`, `wear`, `wear_edge`, `motif`, `motif_dark`, `motif_energy`, `visor`), `GLOW`, `FX_LIGHT`,
>   `FX_LIGHT_RANGE`, `FX_VENT`, `FX_VENT_ALPHA`. The shader is `src/fx/armor_part.gdshader`; every parameter of the
>   refinish is 0 by default, so the other suits are as they were.
> - **`--chrome`** (or `ArmorParts.chrome = true` before a knight is dressed) puts the generated chrome back: no coat, no
>   designs, no visor light, no effects.
> - Known: where the generated texture painted a near-black reflection onto a plate (two patches on the male abdomen)
>   the shader cannot tell it from undersuit and leaves it dark. The designs are drawn at fixed places measured on these
>   two bodies; they are not on the gauntlets' hands or the thighs. No cloak.

> **Gap pass (2026-11-27).** All in `tools/armor_split.gd` (parts rebuilt) and `ArmorParts.FINISH`; no model was regenerated. Sheets: `marketing/armor_gap_pass/`.
> - **The starting kit's bare hips: flex-armour, not plates.** The benchmark knights were generated with a bare black
>   undersuit over the pelvis. A plated skirt (a fauld) was built first and rejected by the owner: it changed the
>   silhouette and made the sleek suit read medieval. What is there now changes nothing but the surface. `_flex` copies
>   exactly the bare region of the body (pelvis height, painted near-black: 638 triangles male, 653 female), lifts it
>   about 2 mm along its normals and keeps the body's own skin weights (`<body>_crownless_flex.res`). `ArmorParts`
>   draws it, while the host's legs are worn, as dark segmented flex-armour (`FLEX_CODE`): graphite lames that follow
>   the body, a slight sheen, fine grooves, one thin seam of cold light on the belt line. The six host parts themselves
>   are exactly as generated; de-spike and the finish table do not touch the host suit. `--noflex` skips the file.
> - **Flat boots on every female suit** (`_flatten_heels`). All nine older female suits were generated in 4-6 cm heels. Each
>   foot is sheared down behind the ball until the shank lies on the floor and the heel block is pressed flat; the ankle and
>   lower shin come down with it, so the mesh ankle sits up to about that much below the ankle joint. Frost keeps a small
>   stub. Pointed toes are untouched. `--heels` builds them as generated. The host's boots were flat already.
> - **Trimmed by default:** black, ash, frost, wyrm, regal, hollow go through the de-spike below whenever parts are built
>   (`DESPIKE_DEFAULT`; `--spikes` for the generated shapes). Its limits are as the study says: stubs remain on pauldrons,
>   the frost and wyrm helms become compact but lumpy, the paint is not corrected.
> - **Finish:** every older family is a step rougher and less mirror-like (`FINISH`); the benchmark suit is unchanged.
> - Not done: no family was regenerated, so "mix of original and future" is only approached by trimming and finish.
>   The black ankle band between the benchmark knights' greaves and shoes is still there.

Study and working prototype for Addendum 3 ("real equipment, not skins"). Nothing here is wired into the live game.
Everything below was measured or looked at in engine captures (`marketing/parts_bench/`); where something was not
checked it says so. Nothing has run on a phone.

## Verdict

**Mix-and-match armour works with the existing 18 models (16 suits + 2 base knights).** A knight can wear a helmet
from one suit, chest from a second, shoulders, gauntlets, legs and boots from others, on one skeleton, through every
authored clip tried (guard stance, walk, overhead cut, dodge). At gameplay distance it reads as one armoured figure.
Close up the joins are visible as steps of 1-5 cm between plates of different thickness, covered by overlap bands and
a dark undersuit, never as holes. Two pieces cannot stand alone and are marked as linked (below).

It does **not** make the suits meet the new visual brief. Splitting does nothing about spikes, heels or generic
shapes. Material correction (done, cheap) fixes the "too shiny" complaint convincingly. Procedural de-spiking works
on limbs and back fins, is rough on helmets and leaves paint blotches; it is a stop-gap, not a redesign.

To finish: (1) integration pass in the rig and Armory (API below); (2) decide per family keep / edit / replace
(table below); (3) compress the suit textures, which is where the memory cost is; (4) regenerate the suits that
cannot be rescued, to the split-friendly spec at the end.

## Inspection (tools/dev/armor_inspect.gd)

| | finding |
|---|---|
| Mesh | every model is 1 skinned mesh, 1 surface, 30.3-33.7k triangles, 4 weights per vertex, stored in rest pose (A-pose, arms about 55-64 deg below horizontal), normalised to height 1.0 |
| Materials | one material each: albedo, normal, packed ORM, all 1024x1024, imported **lossless** (about 16-20 MB of video memory per suit, measured) |
| Bone list | identical on all 18: 65 bones, Mixamo names, same hierarchy |
| Rest pose, same body | **not identical.** Each model was auto-rigged separately: joints sit 1-12 cm apart between suits of one body (on a 1.95 m knight; typical 3-6 cm, worst spine and head), bone rest orientations differ by 20-60 deg (bone-aligned frames), limb lengths differ by up to about 10% (upper arm 0.127-0.156 of height on the male) |
| Across bodies | different proportions (shoulder width 0.18-0.195 male, 0.133-0.141 female; hips higher on the female). Parts are not shared between bodies |
| Height | "height 1.0" includes the crest, so a tall-crested suit has a smaller body inside it (neck height 0.822-0.854 male) |

So the parts cannot simply be parented to one skeleton. They need retargeting by bind pose.

### What the suits look like (front/side/back in `before_turnarounds_m.jpg`, `_f.jpg`)

Closest to the sleek target: **garrison** (plain plate, compact visored helm; small row of crest spikes at the back),
then **base** (clean plates, swept pauldron fins, crest), **hollow f** (smooth, no spikes), **black** (slim, but
bladed pauldrons and calf spurs). Worst: **wyrm** (every plate is a spike, horns, claws), **frost** (crown of spikes,
pauldron horns, forearm fins, long tabard on the male, flared tassets on the female), **hollow m** (row of back
spines, calf fins, pauldron horns), **ash** (feathered pauldrons), **regal** (filigree, horned helm on the female).
**Every female suit has high heels**; the brief asks for flat boots. None can supply female boots.

## How the split works (tools/armor_split.gd, offline)

1. **Conform.** Each suit is re-fitted once to the base knight's skeleton of its body. For each bone, the vertices
   it carries are moved so the donor joint lands on the base joint, turned from the donor limb's direction to the
   base limb's (shortest arc, so differing bone frames do not matter), stretched along the limb to the base limb's
   length (clamped 0.8-1.25) and scaled across it by the ratio of neck heights. Hands, feet and head move as one
   rigid piece each; feet are scaled in height so every sole stays on the same floor. Blended by the skin weights.
   After this all suits of a body share **one skeleton and one Skin**; no per-part retargeting at run time.
2. **Split** by skin weight into helm (Head, Neck), chest (Spine*), shoulders (clavicles, upper arms), arms
   (forearms, hands), legs (Hips, thighs, shins), boots (feet, toes). Triangles are **cut** along the line where the
   part's weight equals its neighbour's (not sorted whole, so edges are smooth), and each part keeps an overlap band
   past that line (`--margin`, default 0.22 in weight).
3. **Undersuit.** The base body without head, hands and feet, drawn in so that it lies inside the *innermost* surface
   of all nine suits (per bone, per 2.5 cm ring, per 30 deg sector; times 0.85) and shown in matt dark cloth. A gap
   between two foreign parts shows cloth, not sky. A shrunk copy of one suit was tried first and failed: it poked
   through every slimmer suit (seen with a lime undersuit; `--underlime` still shows it).

Seam options evaluated: overlap bands (used); undersuit (used, needed); snapping boundary rings to shared positions
(not done: ring radii differ by centimetres, snapping would bend plates; the right fix is at the source, see spec).

## Seam measurements

`--screen=partsbench --measure` on a set cut with no overlap: mean distance between the two parts' seam rings, in cm
on the knight as the game scales it. Same-suit pairs measure 0.0 (the cut is exact).

| seam | male: mean over all 72 suit pairs / worst pair | female | overlap carried (both bands, m / f) |
|---|---|---|---|
| neck (helm-chest) | 4.7 / 12.9 | 2.2 / 4.0 | 5.3 / 3.1 |
| shoulder (chest-shoulders) | 2.7 / 3.9 | 2.4 / 3.9 | 4.3 / 3.2 |
| elbow (shoulders-arms) | 1.1 / 1.6 | 0.9 / 1.4 | 1.6 / 1.4 |
| waist (chest-legs) | 3.0 / 5.1 | 3.9 / 9.3 | 3.5 / 6.1 |
| ankle (legs-boots) | 1.6 / 2.2 | 2.1 / 4.3 | 2.8 / 3.1 |

The figure is ring-to-ring distance: mostly a *step* (one plate standing outside the other), not an open gap.
Outliers: male garrison helm (8.2 mean, it carries a gorget that sits over the other collar: looks fine), female wyrm
and garrison legs at the waist (6.8, 5.1).

In motion (six mixes per body, worst frame of 14 across each clip): the mismatch **does not grow**. Example, male
mix 3 waist: 2.1 guard, 2.5 overhead cut, 2.2 walk, 2.4 dodge; every other seam moved by 0.4 cm or less. The parts
keep their own skin weights, but the auto-rigger weighted similar shapes similarly, so the rings travel together.
Full tables: rerun the command in "Reproduce".

By eye (`seams_mix1.jpg`, `seams_mix2.jpg`, `seams_mix4.jpg`, `edge_cases.jpg`):
- **Elbow**: best seam. Gauntlets from any suit sit on any upper arm.
- **Neck**: good from the front; from behind a band of dark neck shows under some helms. Reads as a gorget.
- **Ankle**: good. Dark streaks on the shin in two captures are the donor suit's own painted undersuit.
- **Waist**: good in front. From behind a plate edge can stand proud (ash legs under a black chest) or leave a ragged
  dark notch (female frost legs under a garrison cuirass).
- **Shoulder**: the weak seam. Same-suit chest and shoulders are clean. Garrison shoulders on a foreign chest carry
  the top of the garrison breastplate and end in a torn edge across the chest: ugly.
- Thin stray slivers (stretched triangles) appear near the armpit in some poses. Not traced.
- In the overhead wind-up, bulky pauldrons (wyrm) balloon round the head, as they would on the whole suit.

## Slot scheme the assets support

helm · chest · shoulders · gauntlets (`arms`) · legs · boots: all six as asked, with two honest restrictions,
encoded in `ArmorParts.LINKED`:

| piece | restriction | why |
|---|---|---|
| vigil (Gravekeeper) helm | only with vigil shoulders | it is a hood; its mantle is the shoulders part. Alone it ends in a torn hem in mid-air (seen) |
| garrison (Crownless) shoulders | only with garrison chest | they carry the upper breastplate (seen) |

Vigil shoulders (the scale mantle) under another helm look fine. The regal high collar accepts another helm (seen).
"legs" includes the pelvis: belts, faulds, tassets and the frost tabard travel with the legs, not the chest.
Recommended default in the interface: shoulders follow the chest unless the player picks otherwise, since that seam
is the weakest.

## Per-suit verdict

Family names from `tools/armor_sets.py`. "Ready" = splits and mixes with seams no worse than the table above.

| suit (family) | male | female | to meet the visual brief |
|---|---|---|---|
| base (starter knight) | ready | ready | keep; pauldron fins and crest want trimming; f boots heeled |
| garrison (Crownless) | ready; **shoulders linked to chest** | ready, same link; waist step 5 cm | **keep**: nearest the target. Material fix only |
| ash (Ashbound) | ready, seams visible at waist (back) | ready | edit: de-spike pauldrons; else keep |
| black (Widow) | ready | ready | edit: material fix (done), de-spike pauldron blades and calf spurs |
| vigil (Gravekeeper) | **helm linked to shoulders**; rest ready | same | keep as is or replace: hood breaks the "compact visored helm" rule |
| frost (Frostwarden) | ready; tabard rides with legs | ready; flared tassets, waist notch from behind | replace (or de-spike as stop-gap: crown, horns, fins) |
| regal (Sovereign) | ready | ready | edit/replace: heavy filigree; f helm horned |
| wyrm (Dragonforged) | ready technically | ready; waist 6.8 cm | **replace**: the design is spikes; flattening them leaves nothing |
| hollow (Architect) | ready | ready | m: edit (de-spike works on back and calves, leaves blotches) or replace; f: keep |

No suit has to stay a complete set. All female boots fail "flat boots" and need replacing whatever else is decided.

## Material study (done; `finish_before_after.jpg`)

Measured on the ORM maps: roughness sits in one narrow glossy band on every suit (median 0.30-0.61, mostly 0.33-0.45,
p10-p90 only about 0.1 apart), and the black undersuit areas are painted as glossy and as metallic as the plate.
A clamp alone (what `Look.sanitise` does) cannot fix that. `src/fx/armor_part.gdshader` re-centres and spreads
roughness, caps metal, and turns near-black albedo into matt non-metal cloth; per-suit values in `ArmorParts.FINISH`.
Seen: black goes from wet lacquer to satin with matt cloth between plates; garrison from chrome to brushed steel
(slightly pale). This needs no regeneration and could be applied to whole-suit models too.

## De-spike study (`despike_before_after.jpg`, `despike_closeups.jpg`; `--despike` in the split tool)

Method: per bone, radii from the bone axis in 2 cm rings; anything beyond the ring's typical radius x tolerance is
pulled in to it (head and shoulder caps are measured as a fitted ellipsoid instead, because crests and horns point
along the bone); moved vertices are relaxed; nothing is deleted, so nothing needs capping. Tried on male frost and
hollow (4325 and 3349 vertices moved).

- Works: forearm fins (frost), back spines and calf fins (hollow) are gone; silhouette is clearly calmer.
- Partly: pauldron horns shrink but a stub remains; frost's crown collapses into a compact but lumpy dome.
- Fails: **the texture is untouched**. Where a fin was, its dark underside paint stays as black blotches on the calf
  (hollow, clearly visible). Lumpy helmets will not pass as "simplified". Scale armour (wyrm) is all protrusion.
- Not done: deleting spikes and capping, UV repaint, any female suit.

Honest reading: usable as a stop-gap on hollow m, black and ash (limb and back spikes). Frost and wyrm, and any
helmet with a crest that defines it, need regenerating.

## Cost (desktop software renderer; relative numbers only)

| | single suit | six parts, one suit | six parts, six suits |
|---|---|---|---|
| triangles (LOD 0) | 31-34k | 34-37k parts + 20.8k (m) / 16.9k (f) undersuit | same, about 51-61k |
| mesh instances / materials | 1 / 1 | 7 / 2 | 7 / 7 |
| draw calls in the bench frame | 6 | 16 | 16 |
| video memory in the bench frame | 94.9 MB | 115.0 MB | 195.6 MB |

Memory is the cost that matters: each extra suit worn brings three lossless 1024 textures (about 16-20 MB). The
hidden base model's textures are also loaded. Fix: VRAM-compress the suit textures (import setting; not changed here
because the GLBs are off limits), or bake a worn loadout into one atlas. Disk: 1.4 MB per suit split (the imported
whole suit is 1.3 MB); `assets/models/parts/` is 30 MB for all 18 plus two de-spiked demos. Offline split: 0.4-0.8 s
per suit. Parts carry generated LODs. Swap time at run time was not measured (first use loads one `.res`; after that
it is a cached mesh assignment).

## Component API (`src/chars/armor_parts.gd`)

```gdscript
var p := ArmorParts.dress(skeleton, "m", {"helm": "frost", "chest": "black", "shoulders": "black",
    "arms": "regal", "legs": "ash", "boots": "vigil"})      # opts: {"under": true, "finish": true}
p.wear("helm", "garrison")          # one swap; false if that part file does not exist; "" takes the slot off
p.wear_all(loadout)
p.set_param(&"tint", c)             # also &"flash", &"rim_color": same meaning as Look.set_param
p.is_clean()                        # false if a linked piece is worn without its companion
ArmorParts.needs("vigil", "helm")   # -> ["shoulders"], for the interface's "worn with" label
ArmorParts.has_part("m", "frost", "helm"); p.cost(); p.remove(); ArmorParts.flush()
```
Suit ids: base, garrison, ash, black, vigil, frost, regal, wyrm, hollow. Slots: helm, chest, shoulders, arms, legs, boots.

### Integration pass
- **Rig**: `Duel.player_look()` always sets `skin` to the *base* knight (`knight_<body>.glb`); after
  `SkinDriver.attach` succeeds in `FighterRig.build`, call `ArmorParts.dress(skin.skel, body, loadout)` and keep it on
  the rig. Route `SkinDriver.tint/flash/rim` to `parts.set_param` as well (the hidden base mesh no longer shows).
  `src/dev/parts_bench.gd::_rig/_knights` does exactly this from outside.
- **Loadout** from `Game.profile.equipped`: item `a_<suit>_<slot>` -> suit id; an empty slot should wear `"base"`
  (an empty slot shows bare undersuit, and bare hands/feet/head do not exist). There is no `shoulders` item slot in
  the data yet: add one, or pass the chest's suit.
- **Armory preview**: `wear()` on the preview knight only; Equip commits. Show `needs()` as "worn with ...".
- Known gap: `SkinDriver` measures floor contact and hit volumes from the base mesh, not the worn parts. Soles are
  conformed to the same floor, but a bulky part (frost tabard, wyrm pauldrons) is not in those volumes.
- Cinematic actors (`src/cine/`) build their own figures and were not looked at.

## What to ask of regenerated suits

1. **One base body per sex**, modelled or generated once: black undersuit, natural athletic proportions, flat feet.
   Every suit is generated *on that body in the same A-pose* and rigged by transferring the base skeleton and
   weights, not auto-rigged again. That removes the conform step and the 1-12 cm joint scatter.
2. **Standard seam rings**: a plain band of fixed radius at neck base, shoulder cap/upper-arm, mid-forearm (not the
   elbow), natural waist, mid-shin (not the ankle). Each piece ends in a rolled edge just past its ring, so pieces
   overlap by design.
3. **Compact silhouettes**: nothing standing more than about 3 cm off the body; no crest, horn, fin, hood, mantle,
   tabard or skirt crossing a seam ring; pauldrons that stop at the shoulder ring and do not merge into the chest.
4. **Helmets** compact and visored, closed at the neck ring. **Boots** flat, both sexes.
5. Textures: real roughness variation (brushed plate about 0.45-0.6, undersuit 0.85+, undersuit non-metal).
6. Better still, generate each **piece** separately on the base body rather than cutting whole suits.

## Recommendation for the eight families

| family | now | recommendation |
|---|---|---|
| Crownless (garrison) | closest to brief | **keep**, new finish; trim helm crest spikes; replace f boots |
| Widow (black) | slim, bladed | **edit**: new finish + de-spike pauldrons/calves; review after |
| Ashbound (ash) | feathered pauldrons | **edit**: de-spike shoulders; keep the rest |
| Architect (hollow) | f clean; m finned | f **keep**; m **edit** now, replace when budget allows (blotches) |
| Sovereign (regal) | ornate | **edit** (finish) short term; **replace** for a cleaner legendary: "the best gear is the cleanest" |
| Gravekeeper (vigil) | hood and mantle | keep as the one deliberately hooded family with its linked helm, or **replace** if hoods are out |
| Frostwarden (frost) | crown, horns, tabard | **replace** |
| Dragonforged (wyrm) | all spikes | **replace** |

Benchmark knights in the brief: build them from garrison + base parts with the new finish before paying for anything.

## Reproduce

```
G=.tools/Godot_v4.6-stable_linux.x86_64
$G --headless --path . -s tools/dev/armor_inspect.gd                       # skeleton / mesh / material facts
$G --headless --path . -s tools/armor_split.gd                             # rebuild assets/models/parts/
$G --headless --path . -s tools/armor_split.gd -- --only=m_frost,m_hollow --despike=all --tag=_ds
$G --headless --path . -s tools/armor_split.gd -- --margin=0 --out=/tmp/parts_m0 --nohull --nolod
$G --headless --path . -- --screen=partsbench --measure --body=m --parts_dir=/tmp/parts_m0/
tools/shoot.sh out 1.0 --screen=partsbench --body=m --helm=frost --chest=black --arms=regal --legs=ash --boots=vigil --yaws=0,180 --noweapon
tools/shoot.sh out 0.6 --screen=partsbench --body=f --set=black --legs=wyrm --clip=th_overhead --cam=waist
tools/shoot.sh out 0.6 --screen=partsbench --turn=frost --body=m [--oldfinish] [--split] [--tag=_ds]
```

## Captures (`marketing/parts_bench/`)

`before_turnarounds_{m,f}.jpg` all 18 as shipped · `split_refinished_turnarounds_{m,f}.jpg` each suit rebuilt from
its six parts with the new finish (identical shape: the split loses nothing) · `mix1-3.jpg` male, `mix4-6.jpg` female
mixed knights, front and back, guard, walk, overhead cut · `seams_mix{1,2,4}.jpg` each seam, idle / swing / from
behind · `edge_cases.jpg` vigil hood alone, vigil mantle, regal collar, two female waists ·
`finish_before_after.jpg` · `despike_before_after.jpg`, `despike_closeups.jpg`.
