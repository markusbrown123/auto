# Inventory, forge and settings: how it works and what is not there yet

## Equipment screen (Armory tab)
- The knight in the backdrop is the live rig, dressed from the profile. Selecting an item you do not wear re-dresses it at once from `Game.trial_profile(id)` (a copy; nothing is saved) and the stage shows "Preview: <name>". Leaving the tab, equipping, or selecting the worn item puts the real gear back.
- **Armour is tint-only.** The generated knight (`assets/models/knight_m.glb`, `knight_f.glb`) is a single skinned mesh with no separate helm, cuirass, gauntlet or greave geometry. Today the only visible effect of armour is the plate colour, taken from the cuirass (`look.metal` → `skin_tint`). Previewing a helm, gauntlets or greaves tints the whole knight with that piece's metal so its colour can be judged, and the stage says "Shown as plate colour only"; once equipped, those three slots do not change the knight's look at all. Real modular armour sets (the brief's Crownless, Ashbound, … sets) need new models and are not built.
- **The hub and the duel tint differently.** `SkinDriver.tint` keeps only the hue of the plate colour (45% blend), so dark iron and bright steel look the same in a fight. `Backdrop.refresh_knight` re-applies the colour keeping its lightness (60% blend) so that a change of cuirass is visible in the sanctuary. Until the rig uses the same rule, a dark cuirass looks darker in the hub than in combat.
- In the comparison, a green up-arrow always means better and a red down-arrow worse; the signed number beside it says which way the figure itself moved (a quicker swing is an up-arrow with a minus).
- Weapons and shields are real: the hand-held models are the equipped `w_*.glb` / `s_*.glb`. Four weapons have no model of their own and borrow another with a tint (`Duel.MODEL_ALIAS`: Ashbrand, Eternal Edge, Blackwood Hatchet, Oathbreaker).
- Rings and relics have no model and no preview on the knight.
- Slot rail: the eight slots in `Db.SLOTS` plus **Shoulders** and **Boots**, which are in the design but have no items in `data/items.json`; they are shown locked, "Not yet found". They become live automatically if those slot names are added to `Db.SLOTS`.
- Comparison rows come from `Game.compare(id)`: `Stats.compute` on the current profile and on the trial copy. Up/down arrows are drawn shapes (`InvGlyph`), coloured green/red, and the sign is printed, so the meaning does not rest on colour.
- "Guard damage" on a weapon card is the fixed 4 posture a clean hit deals (`DuelSim._add_posture(4.0)`), also shown per second of swinging. Weapons do not differ in posture per hit.

## Rarity
Data values map onto the five shown ranks in `Game.RARITY_TIERS`: common → Common, uncommon → Uncommon, rare → Rare, epic → Legendary, legendary → Relic. Each is shown as a name, the existing restrained colour, and 1–5 filled diamonds.

## Sorting and favourites
`profile.inv_sort` (equipped first, damage, defence, rarity, newest, mastery) and `profile.favourites` are saved with the profile. Ties keep acquisition order. A favourite cannot be sold; neither can anything worn, or the last one-handed weapon (equipping a shield needs one).

## Mastery
Stored as before: `profile.mastery[id]` counts fights won with the piece equipped (a guardian counts two), `profile.mastered` lists finished pieces. Needed: 3 / 5 / 7 / 9 / 11 by rarity. Weapons now have three marks, at one third, two thirds and all of that:
1. **I**: a further line of the weapon's history (`data/weapon_history.json`).
2. **II**: one technique for the weapon's class (or a general one when the class has none left) is written into the journal, tagged "learned from mastery of …". It is added to `profile.combos` without touching `combo_uses`; `profile.mastery_taught` records which weapon taught what.
3. **III**: mastered, one attribute point (this already existed).
Armour and trinkets keep only the final mark. `Game.sync_mastery()` runs when the sanctuary opens so older saves receive what they had already earned.

## Forge
Upgrades are paid and saved before the sequence plays; a tap skips to the result. Armour has no model, so a plate of its metal lies on the anvil instead. The anvil is a simple built prop placed by `Backdrop.forge_spot`. Orren's remark plays the first time, then at most once per two fights (`profile.flags.orren_spoke`). Only `orren_intro` and `orren_idle` exist in `data/dialogue.json`.

## Settings: what each one really changes
| Key | Effect |
|---|---|
| `quality` 0/1/2 | `Game.GRAPHICS`: 3D resolution scale 0.6/0.8/1.0; MSAA off/2×/4×; spot and point shadow atlas 0 (off)/2048/4096; sun shadow atlas 1024/2048/4096; sun shadow distance capped at 16/45/no cap (applied to every `DirectionalLight3D`, including ones added later); mesh LOD threshold 4.0/1.0/0.5; `Game.particle_scale()` 0.5/0.8/1.0 |
| `fps` | `Engine.max_fps` |
| `master` | Master bus volume |
| `music`, `dialogue`, `combat`, `ambience` | Their buses; Interface follows `combat`; Cinematics follows the master only |
| `pad_opacity`, `hints`, `shake`, `reduce_flash`, `assist` | As before (read by the duel and its HUD) |
| `haptic_strength` 0–1 | Multiplies every `Game.haptic` strength; 0 is off |
| `sub_size` 0/1/2 | Subtitle font 20/25/32 px on Story's label |
| `sub_bg` | Shows or hides the dark band behind subtitles |
| `reduce_motion` | Menu camera drift, camera glides, the weapon preview's turning and the forge fade are stilled. **Combat and cinematics do not read it yet.** |
| `swipe_sens` 0.5–1.5 | **Stored and exposed only.** Hook: in `src/combat/swipe_input.gd`, divide `min_dist_frac` (0.085) and `min_speed_frac` (0.55) by `Game.settings.swipe_sens`. |
| `chatter` | **Stored and exposed only**, for the companion system. |

`Game.particle_scale()` is likewise only consumed by the forge sparks so far; combat and arena particles need to multiply their amounts by it.

Old settings files (music / sfx / voice sliders, haptics on-off) are migrated on load by `Game.migrate_settings`.
