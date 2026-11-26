# Front end: notes for whoever works on it next

Written 2026-11-26. Covers the theme, the menu flow, save slots, the loading screen, the map, the chronicle,
the result screens and credits. Nothing here has run on a device; every statement about how a screen looks
comes from software-rendered captures at 1280x720 and 1278x590 (the iPhone 2556x1179 shape).

## Theme (`src/ui/ui.gd`)
- `UI.theme()` builds the one `Theme`: Cinzel headings, EB Garamond body, steel button plates with a thin gold
  edge, dark translucent panels, a hairline scroll bar, a diamond slider grabber, text entry, bars, rules.
- `UI.apply(node)` installs it. It sets the root window's theme **and** merges it into the engine's default
  theme, because a Control under a `CanvasLayer` does not inherit the root window's theme and almost every
  screen here sits under one. `main.gd` calls it at start; each front-end screen calls it too, so they look
  right when built by a test without `main.gd`.
- Palette constants: `GOLD`, `GOLD_DIM`, `BONE`, `DIM`, `BLOOD`, `INK`, `PANEL` (as before) plus `STEEL`,
  `STEEL_LIGHT`, `SILVER`, `CHARCOAL`, `CRIMSON`, `PARCHMENT`, `MAP_INK`.
- Every earlier factory keeps its signature (`label`, `title`, `box`, `panel`, `button`, `bar`, `rule`, `spacer`,
  `full`, `safe_margins`, `margin`). New: `menu_item`, `wrapped`, `header`, `confirm`, `ornament`, `corners`,
  `shade`, `vignette`, `roman`, `playtime`, `when`.
- Motion: `fade_in`, `fade_out`, `slide_in`, `stagger`. `UI.motion()` is 0 when the `reduce_motion` setting is
  on: slides become fades, the map stops pulsing, the loading still stops drifting.
- `Emblem` (`src/ui/emblem.gd`) is the game's mark, drawn in code. With `turning` it is the loading mark.

## Flow (`src/main.gd`, routing only)
`show_launch` → `show_title` (the main menu) → Continue / New Journey / … → sanctuary, road, duel as before.
- `Launch`: studio card, then the mark. 3.6 s on the first launch, 1.7 s afterwards (a marker file
  `user://launched`), any tap or key skips. The studio name is the constant `Launch.STUDIO`; it is a
  placeholder text mark and not a real company as far as anyone here knows. **Owner: replace it or confirm it.**
- `TitleScreen` is the main menu. The other front-end screens open *over* it as full-rect Controls
  (`TitleScreen.open(name, arg)`), so the courtyard and the knight are built once. Entries shown: Continue,
  Journeys, Character, Equipment, World Map, Chronicle, Training only when a journey is saved; New Journey,
  Settings, Credits always. "Journeys" (the save slots) is one more entry than the brief listed.
- Character and Equipment open the sanctuary on its Character and Armory tabs (`show_sanctuary(tab)`).
- New Journey: with a free slot it goes straight to who wakes; with none, to the slot list in "new" mode, where
  an occupied slot asks before it is overwritten. Nothing is deleted until "Rise" is pressed.
- `_set_out` (sanctuary and map) and `_enter_duel` (road → duel) go through `LoadingScreen`.

## Save slots (`src/core/game.gd`)
- Three slots. Slot 1 is `save.json` / `save.bak`, exactly the old single-save files, so an existing save is
  slot 1 with no conversion and an older build can still read it. Slots 2 and 3 are `save2.json`, `save3.json`.
- `Game.slot` is the slot the profile in memory belongs to; `save()` and `load_game()` use it.
- New: `slot_file`, `slot_exists`, `slot_summary`, `latest_slot`, `free_slot`, `load_slot`, `delete_slot`,
  `furthest_region`. The profile gained `name` and `last_played`; `playtime` is now counted (it was always 0).
  A save with no `last_played` uses the file's modified time.
- Test: `t_save_slots` in `tests/tests.gd`.

## Loading screen (`src/ui/loading_screen.gd`, `data/loading_tips.json`)
`await LoadingScreen.show(region_id_or_theme, work, warm := [])`.
- The picture: for the Fallen Courtyard, one of the stills in `assets/video/stills/` (only stops the journey
  has already passed, never the last, which shows the guardian). For every other region no art is in the build,
  so the region's own arena is rendered once off-screen at 960x540 and kept as a picture for the session.
  Headless runs get a plain dark ground.
- `warm` resources are loaded on a thread while the mark turns; `work` (building the next screen) then runs on
  the main thread and the picture holds still for as long as that really takes. There is no percentage.
  Minimum time on screen is 1.1 s so it never flashes.
- 42 lines: 24 combat/travel tips, 18 lore notes. A lore note with `"after": "<region>"` only appears once that
  region has been reached. **The brief's four example lines were not available to me (the brief is not in the
  repository), so they are not included; add them to the JSON.**

## World map (`src/ui/world_map.gd`)
Drawn with `_draw` calls on one Control: parchment sheet, brass frame, survey grid and range rings centred on
the throne, coast, river, terrain drawings that appear as their region is reached. Roads are drawn only to
unlocked regions; side roads (roost, deep) are dashed crimson with diamond markers; a cleared region carries
crossed blades; the pennant is where the knight is (the sanctuary unless a journey is under way). The next
locked region is a faint "?" with no name; anything further is not drawn at all. Positions are the `PLACE`
constant. The chapter card shows chapter number, name, blurb, objective, records found there, optional
encounters, and Set out (plus the short way when its lever has been pulled).

## Chronicle (`src/ui/chronicle.gd`)
Records (by region reached), Sequences, Guardians, Endings, and Stories when the `Companion` autoload exists
and has `archive()`. Things not yet found are listed without their names.

## Results (`src/ui/overlays.gd`)
`victory`, `death`, `pause`, `choice`, `message` keep their signatures. `death` takes an optional fifth
argument `{"retry": Callable, "equipment": Callable}` for the extra buttons. "Set out again" starts the same
road again (by the short way if open); it does not restart the duel, because the rule that death resets the
route was left alone. `victory` also lists `r.new_combos` (filled by `main.gd`) and `r.lore` if a caller sets it.

## Credits (`src/ui/credits.gd`, `data/credits.json`)
`data/credits.json` is a hand copy of `docs/CREDITS.md` plus the texts in `docs/licenses` and the two font
licences, because `docs/` and `.txt` files are not exported. Keep them in step by hand. The engine's licence,
its third-party component list and licence texts are read from the engine at run time. `docs/CREDITS.md` says
all audio is synthesised; `docs/AUDIO_ASSET_MANIFEST.md` says four music cues and the speech were generated,
and the credits screen follows the manifest. **CREDITS.md should be corrected by its owner.**

## Dev screens
`--screen=launch|menu|slots|charselect|loading|map|chronicle|credits` (and the earlier `title`, `victory`,
`death`). Options: `--rich` (a level-14 journey), `--fresh` (no saves; first-launch card), `--mode=new`
(slots), `--region=<id>` (map selection, loading picture), `--tab=<Name>` (chronicle), `--licences` (credits),
`--savedir=<suffix>` (separate dev save folder, so captures can run side by side).

## Shop, forge, picker, reward screen (2026-11-26, `tests/shop_forge.tscn`)
Shared pieces: `src/ui/item_stage.gd` (`ItemStage`: one item turning in one SubViewport; blades sway across their flat
instead of going round, because edge-on they are a line), `src/ui/gear_ui.gd` (`GearUI`: a cost written out with what is
missing, comparison rows, list rows, chips), `ItemModel` in `src/ui/armory/item_model.gd` (now draws the hand-modelled
gear with its forge state: `gear_id`, `gear_mod`, `gear_sword`, `sig`, `studio_env`).

**Starting sword** (`character_select.gd`). Two steps: body / name / cloak, then "The Blade You Wake Holding": the four
`Db.equipment.basic_swords` in an `ItemCarousel` (real models, unworked: blade 0, grip 0, iron), role, `role_text`, and
four bars (Damage, Speed, Economy, Stagger) from `Stats.compute` on a new knight holding that sword, each against the
best of the four, fuller always better. Rise sets `CharacterSelect.start_weapon`; `main.gd` passes it to
`Game.new_game` (one changed line). The knights standing in the scene still hold the old sword model.
Dev: `--screen=charselect --step=blade [--sword=<id>] [--cs_demo=<t>:<id>,...]`.

**Sanctuary bar**: Journey, Armory, Shop, Forge, Character, Journal, Settings. The forge's tab is still named
`Blacksmith` in code (`show_tab("Blacksmith")`, `open_forge`). Armory, Shop and Forge use the whole width
(`Sanctuary.WIDE`); `Sanctuary.screen` is the shop or forge while its tab is open. The purse counts to its new figure
(`_purse`, 0.35–0.9 s, at once with reduced motion). While `Story.busy` the whole hub lifts its bottom edge 122 px
(`SPEECH_LIFT`) so a spoken line is never over the buttons.

**Shop** (`shop_screen.gd`). Wares / Materials / Sell. Left: the row to flick through (`ItemCarousel`, middle piece
large, neighbours dimmed, a lock on what is not yet sold, tap the middle one to inspect). Right: gold held, name and
rank, mastery, the three figures that change most against what is worn, Compare for all of them, the price and one
large Buy. Locked entries show `unlock_text` and the price. Buy asks first from 500 gold or when it takes more than
half the purse (`CONFIRM_FROM`). After buying, the piece stays in the row and the counter offers Equip and Inspect.
Buy-back pieces (`shop_stock()` `buyback`) are in the same row. Sell shows each guard as the disabled button's own
text plus a sentence. The stall sells 1 or 5 of anything `material_price` allows.
Dev: `--tab=Shop [--shopmode=Sell] [--item=<id>] [--gold=n] [--quiet=1] --shop_demo=<t>:<action>[:<arg>],...`
(actions in the file).

**Forge** (`forge_screen.gd`, `forge_seq.gd`). Left: what can be worked. Middle: the piece in its real forge state
and what is on the bench. Right: Blade, Grip, Ore, Sharpen strips for a weapon (tier marks, `mod_preview` rows when
it is the equipped weapon and the rule's text when it is not, `mod_cost` with missing parts in red and
`shortfall_price`), an ore picker at the second ore tier, or one Temper strip for a shield or armour piece
(`upgrade_preview`, with materials). Patterns lists `craft_stock()` and the mastery challenge. Work goes through
`Sanctuary.forge_work(id, track, ore)`: paid and saved, then `ForgeSeq` with the actual model laid on the anvil in
its old state and swapped for the new one at the reveal; five blows instead of three for Legendary and Relic.
Ore colours: GearModel's palette where it has the metal (steel, Old Iron→graphite, Grave Silver→silver, Wyrm
Scale→bronze, Rimesteel→frost); plain iron and Hollow Glass are two tints added in `ItemModel.ORE_OWN`.
Dev: `--tab=Blacksmith --mods=<id>:<track>[:<ore>],... --mats=<id>:<n>,... --edge=<id>:<n>
--forge_demo=<t>:<sel|mod|quick|ore|mode|skip|done>[:..]`.

**Duel HUD** (`duel_hud.gd`). `shield_charges(d)` (called from the one new case in `Duel._on_ev`): diamonds on an arc
over the shield pad, drawn by the pad so they fade with it; a change lights the pad for about a second; none left
turns the ring crimson with a crack on the icon and says SHIELD SPENT once; a blow on a spent shield shakes the
pips; a block coming back swells in. `KEEN` beside the bars while the equipped blade's edge lasts.
Dev: `--hud_shield=<left>:<of>`, `--hud_keen`.

**Victory** (`Overlays.victory`, same signature). Left: everything worn with its mastery bar filling by this fight's
gain. Centre: banner, level bar, salvage, a card for each new piece (Compare in place, Inspect; Legendary/Relic with
the model and a slower fade), then lines (shop unlocks first). Right: gold won counting into the purse. All of it
runs in under two seconds, a tap on the background finishes it, Continue is live from the first frame.
Dev: `--screen=victory [--rich] [--reveal=<item id>]`.

## Known gaps
- The slot cards show the body as text and the cloak colour as a band, not a rendered knight.
- The map is not yet reachable from inside the sanctuary (that file belongs to other work); it is on the menu.
- Loading-screen art exists only for the courtyard.
- Text entry for the knight's name has not been tried with the iOS keyboard.
