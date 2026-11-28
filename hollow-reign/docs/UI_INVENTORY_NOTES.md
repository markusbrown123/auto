# Inventory, forge and settings: how it works and what is not there yet

## Equipment and shop pass (2026-11-28, Addendum 7 section 3)
Captures: `marketing/equipment_pass/before/` and `after/` (1560x720 with `--notch=87,0,87,39`, 2532x1170, 2796x1290), the
combination sheets in `marketing/equipment_pass/combinations/`. Software-rendered only; nothing has run on a phone.
- **The stage** (`src/ui/armory/knight_stage.gd`, `KnightStage`): a seamless dark cove behind and under the knight, a soft
  pool of light and a thin ring at its feet; the place's own scenery is hidden while it is up (lights kept) and given back
  on leaving. Two moods: `studio` (the armoury, cool and even) and `forge` (the shop, dark with a warm ember glow).
  `aim(rect, …)` fits the whole knight, feet to crown, into one rectangle of the screen; zoom (0.32 – 1) closes in toward
  the slot's bone. Drag turns, pinch / wheel / trackpad pinch / the − + buttons zoom.
- **Armoury layout** (Destiny-style): the knight is centred and nothing is drawn over it. Slot tiles in a column each side
  (`ArmoryScreen.LEFT_COL` helm, pauldrons, cuirass, gauntlets, greaves, boots; `RIGHT_COL` weapon, shield, off hand, ring,
  relic: every slot of `Db.EQUIP_SLOTS`), each tile 60 – 78 px, the worn piece's rank colour on the edge facing the knight,
  its forge level under the icon. Far left: the open slot's row (`ItemCarousel`), name, rank, the honest note, set / edge line,
  Sort / Grid / Favourite, Equip and Upgrade. Far right: what is on the knight (preview or equipped), the piece's standing,
  the full comparison against what is worn (one column, green up / red down with the signed change), mastery and forge level,
  Compare and Inspect. Under the knight's feet: Attack / Block (weapon, shield), Close Up / Full Body, − +.
  `tests/armory.gd` checks the knight's rectangle is centred and that no panel or tile intersects it.
- **Standing of a piece** (`ArmoryScreen.state_of`): EQUIPPED (gold), OWNED, FOR SALE · N GOLD (green), N GOLD · M SHORT (red),
  LOCKED / UNKNOWN (lock). Shown on the middle piece in the row (carousel `badge`), in the armoury's right panel and on the
  shop counter. A piece Orren sells reads "To the Shop" in the armoury and opens the shop on it (`Sanctuary.open_shop`);
  Upgrade still opens the forge on an owned piece.
- **Armour pieces are drawn as their own part mesh** in the row and in Inspect (`ItemModel.part_of`, `_part`): the exact
  geometry the knight wears, in its finish, standing alone. Rings and relics keep the medallion. The knight's preview now waits
  only for the part file (not a whole suit model).
- **Comparison rows** gained Protection (the mitigation the duel reads, %) and Shield recovery (seconds per returned block,
  lower is better): with Damage, Defence, Health, Stamina, Stamina recovery, Swing time, Swing cost, Stagger, Guard, Resistance,
  Guard damage, Shield blocks and Footwork that covers damage, protection, stamina, swing speed, block count and recovery and
  mobility. `tests/equipment.gd` and `tests/tests.gd` were updated for the two rows (scale and direction).
- **Shop layout** (Infinity Blade-style): the knight full height on the left of a dark warm stage, wearing the piece in the
  middle of the row (after its models load; drag / zoom as in the armoury); the row, the piece's standing, all changed figures
  in two columns and Buy in the middle; a short category list on the right (All Wares, Blades, Shields, Armour, Trinkets,
  Materials, Sell). The modes and filters are the same as before (`set_mode`, `filter`).
- **Persistence** (`tests/equipment.gd` `t_persistence`): purchases are on disk at once; bought, worn, removed, forged and
  modded state survives a relaunch, a fall taken back to the checkpoint (`Game.on_death(true)`), a fall that ends the road, and
  a damaged main save (the backup is read).
- **Combination driver** `tools/dev/equip_sheet.tscn` (see its header): every armour piece, weapon and shield on the
  armoury's knight, both bodies, then the nine complete sets, six mixes and each weapon class with three shields; front / side /
  back sheets and `<body>_report.txt` with the floor, blade-through-body (idle and the armoury's preview cut), shield-through-body
  (idle and block), seam ring mismatch and missing texture / mesh checks.

## Follow-up pass (2026-11-26, later): what changed on the Armory
- The rail is `Db.EQUIP_SLOTS` without the off hand (it has no items): helm, chest, pauldrons, gauntlets, greaves, boots, weapon, shield, ring, relic.
- The case is taller (about 300 px at 720p instead of 225) with its heading, Sort and Grid laid over its top edge, and the middle piece is drawn at 1.25× (`ItemCarousel.zoom`; 1.1× for whole suits). The EQUIPPED tag moved under the piece.
- Weapons and shields with a hand-modelled piece (`gear_id` + `gear_ready`) are shown as THAT model, in their forge state (blade and grip parts, ore tint, polished edge), built by `GearModel.spawn` with `GearModel.mod_from_visual`, the same call the rig makes. During this pass the rig work landed too (`Duel.player_look` now hands the gear model and the armour parts to `fighter_rig.gd`), so the knight holds the same piece; the per-item notes about that (`part_note`) belong to that work.
- The case's pieces sit a little low (`ItemCarousel.drop`) so they clear the heading.
- Every slot's view keeps the whole knight in frame, feet included; a slot only turns the knight and steps a little closer than Full Body.
- Rows: weight class after the rank; a second line for an unmet requirement, a keen edge and forge state, or set progress ("Ashbound set 3 of 6 with this · 2 ✓ 4 – 6 – · at 4: …"); undiscovered pieces are silhouettes named "Unknown <kind>" with `Game.item_hint`; shop pieces show the price or `unlock_text`. Inspect lists requirement, forge work, weight text and all three set tiers.
- Body text is 22 px. Upgrade stays enabled for a weapon at blade V (its other tracks live in the forge).
- A spoken line no longer covers the buttons: the Sanctuary lifts the whole hub above the subtitle while `Story.busy`.
- The Wares and Sell lists described under "Forge" below moved to the Shop tab; see `docs/UI_NOTES.md`.

## Equipment screen (Armory tab), rebuilt 2026-11-26
Files: `src/ui/armory/armory_screen.gd` (the screen), `item_carousel.gd` (the reusable swipe row), `item_model.gd` (what an item looks like in 3D, and background loading), `armory_rig.gd` (the knight's clips), `armory_inspect.gd` (full-screen item). `sanctuary.gd` only creates the screen (`_tab_armory`), hides its right-hand panel for it, forwards `profile_changed` (`armory.on_profile()`) and takes the item for the forge (`open_forge`). Test: `tests/armory.tscn`.

**Layout.** Slot rail (eight drawn icons, `InvGlyph`), then the carousel, name, rank, mastery marks, forged level, one honest line about the item, a stat block, and Equip / Upgrade / Compare / Inspect / Favourite. The right 45% is the knight's: drag turns it, pinch or wheel zooms, a double tap or the Focus button goes between the slot's framing and the whole figure, and Preview Attack (weapon slot) or Preview Block (shield slot) sits under its feet. While a companion's line is on screen the two bottom rows fade to 12% so the subtitle is read cleanly; they still work.

**Carousel** (`ItemCarousel`). `pos` is the row's place in items. A drag moves it 1:1 (`spacing()` pixels per item; a third as far past either end). On release the flick's speed is taken from the last 90 ms, the resting item is the one nearest `pos + vel / 5`, and a critically damped spring (k = 150) takes the row there. `centred` fires as items pass the middle, `settled` once at rest. A tap on a neighbour centres it; a tap on the middle item opens Inspect; the wheel steps one item. The touch handler calls `drag_begin / drag_move / drag_end`, and so does the capture script, so scripted swipes use the real path. With `reduce_motion` the row jumps to its resting item and nothing turns.
All 3D pieces are drawn by **one** `SubViewport` the size of the row (×0.7, no MSAA and no rim light on the Performance preset) with a transparent ground, shown through a shader that fades the sides. Only pieces within two places of the middle are nodes; at most seven built pieces are kept (`ItemCarousel.keep`; three for whole suits) and at most ten loaded scenes (`ItemModel.keep`; four for suits), all let go on leaving the tab. Scenes are loaded with `ResourceLoader.load_threaded_request`, at most two at a time and only for items within 1.6 places of the middle, so a long flick does not queue the collection. Until a piece arrives, and for items with no model, a drawn medallion with the slot's icon stands in.
The Grid button lays the same entries out as a scrolling grid of names; choosing one jumps the row to it.

**What each slot shows, exactly.**
| Slot | In the carousel | On the knight |
|---|---|---|
| Weapon | its real model (`Duel.weapon_model`; four borrow another blade with a tint, and the note says so) | really changes: the model in the hand, the stance clip for its class |
| Shield | its real model | really changes: the model on the arm (none with a two-handed or dual weapon) |
| Chest | the whole suit model on a stand | really changes when the suit has a model (`knight_<m|f>_<suit>.glb`, eight suits): the whole knight is swapped. "Wayfarer Cuirass" has none: plate colour only, and the note says so |
| Helm, gauntlets, greaves | a medallion (no geometry exists) | **nothing changes**; the note reads "A fitting: changes statistics, not the knight's appearance" |
| Ring, relic | a medallion | nothing; "Worn unseen: changes statistics only" |
`ArmoryScreen.apply_preview(slot, id)` is the one function that puts an item on the knight; it calls `Backdrop.dress_knight(trial_profile)`, which swaps only the hand-held pieces when the body is the same and rebuilds the knight only for a change of suit. When armour parts become real geometry, that function (and `ItemModel.paths/build` for the carousel piece) is where they go.

**Preview never saves.** The knight is dressed from `Game.trial_profile(id)`, a copy. `Game.profile` is written only by Equip / Remove (`Game.equip`, `Game.unequip`), Favourite and Sort. Leaving the tab calls `ArmoryScreen.leave()`, which rebuilds the knight from what is equipped. The preview is applied 0.06 s after the row settles, or after 0.4 s of a finger resting on one item, and only once its models are in memory. `tests/armory.gd` browses all 71 entries of all eight slots and checks the save file is byte-identical afterwards, then that Equip changes exactly one slot.

**Items not held** are listed after the held ones, by rarity, limited to the current journey (`ng_min`). One the smith sells is shown dimmed with its name and "Locked · Orren sells this for N gold"; anything else is a dark shape named "Unknown <kind>" with "Locked · Not yet found" (the data has no per-item hint; an `"hint"` string on an item would be shown instead). Both can be previewed; Equip reads Locked and is disabled.

**The knight.** `ArmoryRig` extends `FighterRig` and replaces only `_pick_clip`: whole-body authored clips at full weight with no travel. Stance: `ss_idle` / `th_idle` / `dw_idle` by weapon class while the weapon or shield slot is open; the plain `idle` (arms down, shield by the side) for the armour slots, so the suit is never hidden behind the shield. Each slot also sets the knight's facing (weapon: sword side to the camera; shield: shield side) and a camera framing (`FOCUS`), all straight-on through a 36° lens; the camera glide and idle drift are parameters of `Backdrop` (`cam_speed`, `cam_drift`, `cam_fov`). `Backdrop.studio()` adds a warm key with shadows, a cool fill and a cool rim (no rim on Performance).
Preview Attack plays `ATTACK_PREFER` for the class's pack (`ss_cut_r_high`, `th_cut_dl2`, `dw_cut_r`), or failing that the shortest clip in `clip_meta.json` of kind `attack` that winds up from the stance and recovers to it. Preview Block plays `ss_block` then holds `ss_block_idle` for 1.3 s. A deliberate change of weapon plays the last 0.45 s of `ss_unsheath` (sword and axe) or a 0.42 s lower-and-raise; settling within 0.7 s of the previous settle (rapid browsing) skips it, as does `reduce_motion`. For items that are `legendary` (or carry `"advanced": true` / `"recall": true`), `play_recall(id)` is tried first: if `res://src/fx/recall.gd` exists and has a static `play(rig, item_id, short)`, it is called; otherwise the short swap plays.

**Comparison** is always against what is equipped (`Game.compare`): the new figure, an arrow and the signed change; Compare switches to "equipped → this" for every non-zero row. A green up-arrow always means better and a red down-arrow worse; the signed number says which way the figure itself moved (a quicker swing is an up-arrow with a minus). Every row is a number `DuelSim` reads.

**Known limits.** Shoulders and boots have no items and are not on the rail. Rings and relics cannot be zoomed to (there is nothing to see). The suit on its stand is the model's rest pose with the arms let down, not a posed figure. Mastery detail (what each mark gives) moved into Inspect.
- "Guard damage" on a weapon is the fixed 4 posture a clean hit deals (`DuelSim._add_posture(4.0)`), shown in Inspect.
- **The hub and the duel tint differently** (unchanged): `SkinDriver.tint` keeps only the hue of the plate colour; `Backdrop.refresh_knight` keeps its lightness too, for the one suit without a model.

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
