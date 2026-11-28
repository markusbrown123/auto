# Hollow Reign: the flow of a journey

How one screen becomes the next, what is on screen in between, and where a wait is still shown. The router is
`src/main.gd`; the story scenes are in `src/cine/`. Written 2026-11-26 after the flow pass (Addendum 2 of
`MASTER_REQUIREMENTS.md`: one continuous adventure, fades only when the place changes, matched poses and cameras).

Nothing here has run on a phone. Times are the scene's own clock at 30 fps on the development machine.

## A new journey (the generational opening, 2026-11-26)

Story: `docs/CAMPAIGN_SCRIPT.md`, "The Inherited Oath". Shots: `docs/CINEMATIC_SCRIPT.md`, section 1.

| # | Step | File | Length | How it ends, and what joins it to the next |
|---|---|---|---|---|
| 1 | Main menu | `ui/title_screen.gd` | — | New Journey opens character select over the same backdrop. |
| 2 | Character select | `ui/character_select.gd` | — | Confirm: 0.35 s fade to black. |
| 3 | **Generation I** | `cine/prologue.gd` | about 4 min, two duels in it | Opens from black, ends on black. First new journey only; see "Seen before". |
| 3a | · the road | `cine/high_road.gd` | about 70 s | Six shots; 0.5 s fade. |
| 3b | · the throne | | about 36 s | The guardian turns; 0.35 s fade. |
| 3c | · the royal guardian | `combat/duel.gd` | player-paced, about 1 min | Won: 0.5 s fade on. Lost: 0.5 s fade and the same duel again. |
| 3d | · the records | | about 11 s | 0.35 s fade. |
| 3e | · the clash | `combat/duel.gd` | 9 to 32 s | Taken by the story on the fourth cut the player lands (never before 9 s): the sim is paused where it stands, 0.45 s fade. |
| 3f | · the fall | | about 32 s | The Engine's room (`chamber`). Last frame is the Awakening's first frame. Black, the mark, the narrator. |
| 4 | **Time jump** | `cine/time_jump.gd` | about 12 s | The one view in Generation I's state, "TWENTY-TWO YEARS", white, the same view in Generation II's state, 0.5 s to black. |
| 5 | **Arrival** | `cine/arrival.gd` | about 45 s | The same view from black with the player's knight; the line; the game's name; four shots up the road; 0.6 s to black at the gate. |
| 6 | Awakening (the Inheritance Engine) | `cine/awakening.gd` | about 36 s plus one tap | Unchanged. Ends walking into the white of the door. |
| 7 | The walk out (Courtyard, since Stage 3A) | `ui/explore.gd` + `world/court_route.gd` | about 80 s | Out of the same white at the door in the hillside (`CourtRoute.ENTRY`), down the causeway along the sea cliff, over the ravine bridge, to the terrace before the breach. It is the road screen itself, walking (`Explore.arrive = {intro}`); `Explore.skip()` ends it. Since Stage 1's hand-off the Awakening stops at its passage's doorway (`Awakening.handoff`, `reached_exit`): `Main._walk_out_of_chamber` dissolves (no white) from the passage onto the same framing at the hillside door, the knight walking, the shield back on the arm in daylight, and the Witness carried across (`WitnessDrone.continue_from`, placed by `Chamber.to_world(CourtRoute.ENTRY, ENTRY_YAW)`). A skipped Awakening still ends on white and the walk starts at the door. `cine/approach.gd` is kept for the stop-by-stop roads and `--oldroad`. |
| 8 | First stop of the road | `ui/explore.gd` | — | No transition: the walk stops at the first stop's anchor and the choices come up. |
| 9 | The foe is shown, the lesson, the first real duel, rewards | as before | | as before |

To the first stop of Generation II's road a first-time player who skips nothing sees about 6 minutes, of which the two Generation I duels are about a minute and a quarter of play. These figures are summed from the scenes' own timers and the length of the lines (new lines are text-only and are held for 1.4 s plus a fifteenth of a second a character); the chain has not been played through in one sitting on the build machine, and the guardian duel's length is a guess until a person has fought it. With SKIP used on every beat it is under 20 seconds.

### Generation I (`--screen=prologue`, `--beat=1..5`, `--shot=1..6` holds one road shot, `--auto` lets a bot fight)
The forebear is a profile, not a special case: `Prologue.forebear()` is the default knight with veteran attributes, the garrison's silver armour and shield, the player's chosen body, and **the player's own sword item** (`Prologue.inherited_sword()`: what `Game.profile.equipped.weapon` holds if it is a one-handed sword, with its upgrade, mod and edge records copied). Both duels are the game's own `Duel`; for their length `Game.profile` is the forebear's and `Game.save_dir_override` points at a scratch folder, so nothing can be written to a save slot. Both are given back in `_give_back()` (also on leaving the tree).

- The guardian (`throne_guard`) is an ordinary duel with `skip_intro`. Over it, one line of instruction at a time: with a blow coming "HOLD YOUR SHIELD UP · OR SWIPE INTO THE BLOW TO TURN IT", with the foe open "HE IS OPEN · SWIPE ACROSS HIM TO CUT". Losing replays it.
- The clash (`forgotten_monarch`, his real data, phase one) is taken by the story in `Prologue._on_duel_ev` on the sim's own `boss_hit` event: the cut that makes `CLASH_CUTS` (4) landed, once `CLASH_MIN` (9 s) has passed. `CLASH_TIME` (32 s) releases a player who lands nothing; `CLASH_FLOOR` (a quarter of health) is a safety so nobody dies to a stray blow. Nothing in `src/combat` was changed, no damage is faked, and the result is stored (`clash_result`: "ahead", "even", "behind").
- The fall is staged in the `chamber` set so that the sword is left in the block ("Rack") and the forebear ends at `Awakening.SEAT`, which is where the heir is found.

SKIP (top right, every beat) goes to the next beat; skipping the last ends it.

### The time jump (`--screen=timejump --years=22 --from=1 --to=2`)
`TimeJump.make(years, from_gen, to_gen)`, signal `finished`. It builds the high road once and changes it in place with `Highland.generation(arena, g)`. `main.show_time_jump(years, from, to, then)` is the router's entry; the second use is `show_time_jump(24, 2, 3, …)`.

### The arrival (`--screen=arrival`, `--shot=1..6`, `--gen=1..3` shows that generation's road)
`Arrival.gen` (2 by default) chooses the road's state; the walker is `Duel.player_look()`. For Generation III set `gen = 3` and give it the third heir's line scene.

### The high road (`src/world/highland.gd`, `src/cine/high_road.gd`)
An `Arena` theme, `"highland"`: any screen that takes a theme can stand in it (`Backdrop`, `Duel`, the story scenes). `Highland.generation(arena, 1|2|3)`: 1 kept (summer dawn, the Ring-Gate whole, fires lit, banners up, the road worn clear), 2 damaged and overgrown (autumn dusk, an arc of the ring fallen and lying on the slope, fires dead, banners gone, turf over half the road, hard wind), 3 ancient technology waking (winter, snow on the ground and falling, the seam round the ring alight). `HighRoad.vista()` is the one composition every generation is shown from.

The menu can use it: `TitleScreen.vista = true` (off by default; `--screen=title --vista`) puts the menu over that composition with the player's knight on the road, in the generation their save has reached.

## The second fall and the Last Heir (2026-11-26, the three generations wired end to end)

Router: `src/main.gd` (`story_kind`, `_story_opts`, `_story_hooks`, `_story_won`, `resume`). Scenes: `src/cine/second_fall.gd`, `heir_return.gd`, `kept_scene.gd`, `final_hall.gd`, `aftermath.gd`, `facility.gd`, all on `cine_scene.gd` (cards, SKIP, `_closing()` called once however a scene ends). These apply only while the family's canon is open (`Generations.canon_open`): a legacy journey fights the same foes as plain duels and ends at the throne as it always did.

| # | Step | File | How it is reached, and what it records |
|---|---|---|---|
| 1 | **The second meeting** (Generation II, Throne stop 6) | `combat/duel.gd` | `forgotten_monarch`, his own data. `monarch_blade` ("That blade.") before `monarch_intro`. Sim options `beat_at [1, 2]`, `beat_hp 0.22`. |
| 1a | · the records choice | `Overlays.choice` over the held fight | Sent by the sim as the third phase begins (33 %) **or** when the knight is under 22 % health, once a fight. "Press the attack" / "Save the records". `Game.record_monarch(2, {choice})`. |
| 1b | · records chosen | | `sim._story_end("records")`: the duel is neither won nor lost (`Duel.interrupted`), no reward is paid, on to 2 with `won = false`. |
| 1c | · pressed and **won** | | The ordinary finisher; `Game.on_victory` (the win is recorded, `monarch_bested:2`, real rewards); the ordinary victory screen shows them. Continue → 2 with `won = true`. |
| 1d | · pressed and lost | | An ordinary defeat: the death screen, the road again. Nothing in the lineage moves. The choice is offered again in the next attempt. |
| 2 | **The second fall** | `cine/second_fall.gd` | `won`: he is down, the floor's machines wake, he is stood up ("I am not the thing that is keeping me."). Then, both ways: the seal burns, the knight goes to it and drives the blade in, `gen2_seal`, the blow (the camera stays on the Monarch), black, the mark, `gen2_close`. At the blow (or on SKIP): a winner's Throne road is cleared, then `Game.fall(2, "saved_the_records", {choice, won})`. |
| 3 | Twenty-four years | `cine/time_jump.gd` | `show_time_jump(24, 2, 3, show_heir)`. |
| 4 | The heir's name | `HeirReturn.Naming` | One field over the family's mark; the line (grandson / granddaughter) follows the body chosen at the start. `Game.inherit({name, body})`. |
| 5 | The heir's arrival | `cine/arrival.gd` with `gen = 3` | The winter road, card "VAELORA · THE LAST HEIR", `gen3_arrive`, no title. |
| 6 | The Inheritance Engine | `cine/heir_return.gd` | The heir walks in. The second's blade stands in the block (the Engine has called it home). `gen3_engine`. **TAKE UP YOUR SWORD** → `Game.take_fallen_weapon()` (also on SKIP). Sets `flags.gen3_arrived`. Out into the white → Approach → the Courtyard. |
| 7 | Generation III's roads | `ui/explore.gd`, `ui/world_map.gd` | The director's stops (`Game.stage_options`); the map's cards read `Encounters.region_info`. |
| 8 | **The Kept** (Courtyard stop 6) | `cine/kept_scene.gd`, `combat/duel.gd` | First meeting: the reveal (its back; the mask at the heir's hip, `kept_approach`; it turns; the card; `kept_intro`), sets `flags.kept_revealed`. The duel: foe `the_kept`, dressed from its saved `rig`; `kept_beat` as its second phase begins; at no health it **yields** (`story.yield`). Then mode `after` (`kept_after`, the blade held out), `KeptScene.grant_edge()` gives **The Second's Edge**, then the ordinary victory screen with it on, and the region is cleared. |
| 9 | **The last meeting** (Throne stop 6) | `combat/duel.gd`, `cine/final_hall.gd` | `monarch_iii`; `monarch_g3_intro`; `FinalHall.dress` over the hall, following the phases; phase three carries the seal (`seal {phase 2, need}`; need = 9 less one for each inheritance record held, never under 2). Ends on the real finisher and the recorded `monarch_death` lines (scene `monarch_g3_death`). |
| 10 | The aftermath | `cine/aftermath.gd` | No victory screen. `Game.on_victory` and `complete_region` are done silently. The hall, the empty throne, `final_door`, the wall parts on white. |
| 11 | The facility | `cine/facility.gd` | The descent; `facility`; sets `flags.facility_seen`. The Deep is open (`monarch_felled:3`). |
| 12 | What was won, and the Crown | `Overlays.message`, `Overlays.choice` | At the sanctuary: the duel's rewards in three lines, then the choice from `Game.endings()` with a fourth answer, "Not yet". It comes back whenever the Deep's road or the Throne's is finished again. |
| 13 | After an ending | | `Game.choose_ending` closes the canon; the sanctuary's journey panel offers the legacy journey as before. |

**Since the campaign fix pass (2026-11-27):** an ending chosen at the Crown is played as a scene (`cine/ending_scene.gd`, about 40 to 55 s, SKIP as elsewhere) and then returns to the sanctuary with the "Elsewhere" note; the road is saved at every stop reached, so Continue from a save made on the road opens that stop (`Game.resume_road`), not the sanctuary; "Return Again" is not offered until an ending is chosen; the Kept's post is empty once it has been let go; the lesson has two more steps (SURGE, RELIC); a companion's remark at a road stop no longer holds the choices back.

**Continue** (`main.resume`): a fall not yet answered → the years and the heir; Generation II with the Monarch beaten or the seal chosen but no fall yet → the second fall; Generation III before `gen3_arrived` → the arrival; the Monarch felled before `facility_seen` → the aftermath; otherwise the sanctuary.

**Death and checkpoints** (Addendum 5 of `MASTER_REQUIREMENTS.md`, 2026-11-27; supersedes the earlier "the Engine restores you to the sanctuary" defeat).
An ordinary defeat on the road, in every generation, goes: the knight's fall clip plays out in full (`Duel._begin_death`; the wait before the fade is the clip's own length plus 0.4 s), the picture fades to black over `Duel.DEATH_FADE` (1.5 s, a layer over the bars and under the screens), `finished(false)`, `Main._duel_done` → `Game.on_death(true)` → `Overlays.death`: near-black ground, a small sword mark between two thin rules, "YOU HAVE FALLEN" in wide-tracked Cinzel capitals in the muted gold, "Your journey is not yet over." in italics, **RETRY FROM CHECKPOINT** (primary, 72 high) and a quieter **RETURN TO MAIN MENU** (60 high). Nothing respawns by itself; nothing is listed as lost, because nothing is.
- **Checkpoints are data.** `checkpoint: true` on a stage of `data/regions.json`, authored in `tools/gen_regions.py` (`_checkpoints`): the road's start; the stop before any guardian's approach (always the stop before the last); the stop after a guardian that is not the last; and a stop in any run of three. Never a guardian's own stop. Today every road has 0, 3, 5 (the Cathedral also 1). `Game.run.checkpoint` is the last one passed (`start_run` sets it to the stop the road began at, so a road begun at an open gate has the gate as its start; `advance_stage` moves it on).
- **What a fall does** (`Game.on_death(keep_road=true)`, `Game.rewind_to_checkpoint`): the run is put at its checkpoint with full health and saved there before anything is shown, so quitting at the death screen and pressing Continue lands in the same place (`resume_road`). Retry goes through the loading screen (`Main._retry_from_checkpoint`) to the road screen at that stop. Every foe and encounter from there is simply not yet reached again, so it stands again; the pooled foes keep the run's seed. Kept: gold, equipment, mods, mastery, levels, victories counted, flags. Not given twice: pouches (`profile.pouches`), chests and levers (flags), one-time rewards. `Game.on_death()` with no argument is the older call, still used where there is no road: it ends the route and the sanctuary follows.
- **No time jump.** An ordinary defeat never touches the lineage. Only `Game.fall(1, …)` and `Game.fall(2, …)` (the two authored moments, `src/core/generations.gd`) do, and their scenes (`src/cine/prologue.gd` clash and fall, `second_fall.gd`) do not use the death screen (`tests/generations.gd` `t_checkpoints` reads the sources to prove it). The story fights expect defeat as before: the second meeting offers the records choice again in every attempt, the Kept's reveal is not replayed, the last meeting starts from its silent card. Generation I's guardian duel, when lost, fades and is simply taken again (it is not the road's; the Prologue handles it).
- **Swipe feedback.** Two things, both drawn in the duel HUD layer (5) and neither taking a touch: the player's own trail (`SwipeInput`: per-finger ring buffer, smoothed, about 50 wide at the head, tapering, 0.3 s life and fade) and the prompt line (`DuelHud.PromptLine`: where to swipe, large, centred, animated head, tinted by kind). Dev screens `--screen=trails` (`src/dev/trail_demo.gd`) and `--screen=prompts` (`src/dev/prompt_demo.gd`); `--screen=slice --road=<stop> [--die=1|boss] [--until=retry]` begins the slice on the Courtyard's road for the death and retry captures.
- **The lesson** cannot be lost (`DuelSim.lesson`: nothing can die in it), so it has no death screen; Yield in its pause menu leaves it unfinished to be offered again, as before. Training likewise. Yield in a real duel is a defeat and goes the same way.
- **Save version 5** adds `road.checkpoint`. A saved road without it (version 4) is given the last checkpoint at or before its stop. Fixture `tests/fixtures/save_v5.json`.

**The Second's Edge** (`w_seconds_edge`, `tools/gen_equipment.py`): in the data a plain sword with one source, `story`. `KeptScene.sync_edge()` (called from `resume`, the inheritance and the dev helpers) lays the snapshot weapon's class, numbers and model over that entry, and `grant_edge()` copies its tier, grip, ore and edge records. A profile read without the router (a test) sees the plain entry until it is synced.

### Dev screens for these
`--screen=gen2choice` (the choice over the held fight), `--screen=gen2fall [--won] [--hold=rise|seal|fall|mark]`, `--screen=heirname`, `--screen=heir [--auto]` (years → name → arrival → Engine), `--screen=heirreturn [--hold=enter|sword|taken]`, `--screen=kept [--mode=reveal|duel|after] [--hold=back|hip|turn|offer] [--kit=a|b]`, `--screen=finalmonarch [--phase=0|1|2] [--seal=N] [--seal_left=K] [--seen]`, `--screen=aftermath [--hold=hall|throne|door]`, `--screen=facility [--hold=shaft|rings|floor|crown]`, `--screen=lineage [--gen=3]`, `--screen=map --gen=3 [--felled]`, `--screen=slots --gen=3`. `--kit=a|b` chooses what the second generation wore; `--bot` lets a bot fight (and answer the records choice with `--choice=press|records`).

## Hooks for the generational pass
Nothing below is generational architecture; it is what these scenes already emit and what they need to be given.

| Moment | Signal / call | Flags written (`Game.profile.flags`, the existing dictionary) |
|---|---|---|
| Generation I ends (played or skipped) | `Prologue.finished` | `gen1_complete = true`; `gen1_clash = "ahead" / "even" / "behind" / ""` (empty if skipped before the clash); `inherited_weapon = <item id>` |
| First time jump ends | `TimeJump.finished` | none |
| Generation II arrives | `Arrival.finished` | `generation = 2` (written when the scene starts) |
| Generation II falls | to be emitted by that pass | wanted: `gen2_complete`, and the snapshot below |
| Second time jump | `main.show_time_jump(24, 2, 3, then)` | none |
| Generation III arrives | `Arrival` with `gen = 3` | `generation = 3` |

Missing from `Game` and worked around here: there is no way to dress or fight as anyone but `Game.profile`, so Generation I swaps the profile for the length of a duel. A `Duel.setup` option naming the profile to fight as (and a `player_look(profile)` argument) would remove the swap and the scratch save folder. There is no flag API beyond the dictionary itself; it was enough.

**The inherited sword.** Today the hand-over is by identity: the forebear fights with the item id the player's knight has equipped, and `Awakening` stands that same equipped weapon in the block. When generations get their own data, Generation I should own the item and its record (`Game.item_record(id)`: tier, mods, edge) and the Engine should move that record into Generation II's inventory at "TAKE UP YOUR SWORD"; the scenes need no change, only `Prologue.inherited_sword()`.

**The Kept: what must be captured at the Generation II fall** (one dictionary, stored with the campaign, never edited afterwards):
- `body` ("m" / "f") and `name`, `heraldry`.
- `look`: the result of `Duel.player_look()` at that moment. It already resolves all six armour slots through `Game.appearance_loadout()` (so cosmetics, finishes and "look as" are in it), the weapon model with `gear_mod` (the forge mods as they are drawn), and the shield.
- `equipped`: the item id in every slot, and for the weapon and shield `Game.item_record(id)` (upgrade tier, mods, edge) so its numbers can be rebuilt.
- `stats`: `Game.stats()` (health, damage, stamina, shield blocks) so the foe is as strong as the player was, not as strong as a table says.
- `combos`: the five highest entries of `profile.combo_uses` with their counts, each with its sequence of directions from `Db.combo_by_id`.
- `level`, `playtime`, and the count of guardians beaten, for the record screen.

**How a duel can build that foe with what exists.** There is no "mirror" option in `duel_sim.gd` or `duel_bot.gd`: the bot plays the player's side only, and the sim's foe is driven by data. What exists and is enough for most of it: `Duel.setup(foe_id)` reads `Db.foes[foe_id]`, a plain dictionary, so a record can be added at run time. Its `rig` is used as the look (`foe.rig.duplicate()`), and because the weapon model is merged without overwriting, a `rig` that already carries `skin`, `parts`, `weapon_model`, `gear`, `gear_mod` and `shield` (that is, the saved `look` plus `scale`) is drawn as saved provided the record's `cls` names no class model and no `assets/models/<id>.glb` exists. `hp` and the attack damage come from the saved `stats`; `phases[].combos[]` are lists of attacks with a direction each, so each saved combination becomes one foe combo (same directions, windups from the weapon class); `arena` chooses the place; `speech` and `foe_voice` in `data/dialogue.json` need an entry for it to speak. **Missing:** (1) this has not been run: whether `FighterRig.build(look, true)` draws armour parts and a hand-modelled weapon correctly on the foe's side is unverified; (2) foes do not raise a shield or dodge in the sim, so the Kept would attack like the player but not defend like them; (3) the voice: the player's takes exist only for the lines the player had. All three belong to the generational pass.

### Awakening (`--screen=awakening`, `--from=sword` starts at the prompt, `--auto` answers it)
The `chamber` arena (new: a round stone-and-metal room, the cradle, machine pylons, a block with the sword in it, one door).
The knight is `Duel.player_look()`: the chosen body and whatever is equipped.

| Beat | What happens | Camera |
|---|---|---|
| Black → one amber light | The knight sits on the floor against the foot of the cradle (`wounded` clip), unarmed. | Low and close, drifting back. |
| "Can you hear me?" / "Who are you?" | The grille on the wall brightens while Lyra speaks (all scene long). | Holds. |
| "Someone who has been waiting…" | The knight gets up: a 2.6 s cross-fade from `wounded` to `idle`. | Pulls back and up to a medium shot. |
| "What happened here?" | The knight turns to look for the voice. | Holds. |
| "That depends…" | — | Over the shoulder toward the grille. |
| "Things I couldn't possibly have seen." | — | Reverse: the helm, close. |
| "Then it worked." | Light comes up on the sword in its block. Music (`hub`) enters. | Wide: knight, cradle, sword, door. |
| Prompt | **The one interaction:** a breathing ring on the sword, "TAKE UP YOUR SWORD". | Wide, still. |
| Tap | The knight walks to the block (authored walk, arms swinging), the sword leaves the block and it and the shield are in hand. | Waits by the block, then eases in. |
| The door | The panel slides up, daylight floods in, `first_road` plays ("The doors above you open…"). The knight turns and walks out. | Behind the knight, riding with them, to white. |

### Approach (`--screen=approach`)
The region's own arena, built once. The knight walks 11 m to the stop's standing point with the camera at the offset the
Awakening ended on. On arrival the camera eases to the road screen's view; if `first_road` is still being spoken the
knight waits for it (at most 14 s), then the road screen adopts the place.

### The continuous Courtyard (Stage 3A, 2026-11-28; docs/TRAVERSAL_PLAN.md)
The Courtyard's road is one place (`src/world/court_route.gd`, `CourtRoute`), walked; every other region keeps the stop-by-stop
screen. `Explore.continuous()` decides (the Courtyard, the kit present, the filmed road off, no `--oldroad`).
- **Stops are anchors** (`anchor` on each Courtyard stage in `data/regions.json`, authored in `tools/gen_regions.py`): a flat place
  in the level; the stop's frame (markers 4.6 m ahead, foes 1.6 m beyond, camera behind) is the old screen's frame moved there.
- **Between stops** the knight walks the way taken (`CourtRoute.LEGS`, "stage|label") at `FighterRig.ROAD_SPEED` with the road
  camera behind (`Explore._route_cam`, pulled in front of walls with `CamFollow.clear_from`). `moved_on` no longer fades:
  `Main._next_stage` calls `Explore.travel()` on the same screen. Chests, the winch and the shrine stand in the place from the
  start (`Explore._world_props`, opened/pulled already if they were); using one walks the knight to it (`CourtRoute.SPOTS`).
- **Fights are fought where they are met** (Stage 3B). Everyone the road will meet is in the place from the moment
  the road is opened (`RouteLife`, data `CourtRoute.ENCOUNTERS`): a sentry walking the line of the breach, a guard in
  the stair-foot post's door, the banneret at attention by his banner, the Breaker behind a barricade in the gate
  passage (or the Gate Colossus sitting dormant there), the Sentinel at his post; each is shown with the section of
  the place it stands in, so nothing appears in view. Choosing the fight (`Explore._meet_then`): the foe comes as
  itself (turns off its line, steps out of its door, salutes and steps forward, smashes through the barricade, wakes
  and gets up), the knight walks up to where it will stand, the camera watches over the knight's shoulder. Then
  `Main._enter_duel` holds the road screen (`Main.parked`, `Explore.park`) and the `Duel` takes up the road's own
  Arena and frame (`Duel.place`: no arena of its own; the duel's frame is the meeting place; its camera starts from
  the road camera's pose and eases into the fight's over 1.4 s), behind a 0.45 s dissolve that covers the swap of
  the two figures for the duel's. A won duel goes back to the same road screen (`Main._resume_road`,
  `Explore.unpark`): the fallen foe stays where it fell (`RouteLife.lay_down`: held pose, no processing, no
  physics), the knight walks on from where it stood and round the body. A road opened again in the same run lays
  the fallen down again (`RouteLife.bodies`); a Retry or Continue from a checkpoint before them stands them again.
  A cache whose way runs past a foe still standing (the murder hole, past the passage's holder) brings the knight
  back out to them (`Explore._back_to_stop`). Story foes, dragons and hidden duels keep the separate duel.
- **Things used on the road** are modelled (`RouteKit`: the strongbox with its hinged lid, the windlass with crank,
  ratchet, pawl and running chain, the barricade) and used by the knight (`Explore._act`: the sword put up, the hand
  on the lid, the crank or the stone by IK, `RouteKit.Reach`); the portcullis rises with the crank, with its jolt,
  judder and sound; the action button is set beside the thing, never over it (`Explore._place_action`). Pouches and
  secrets' tells of every stop lie in the place from the start and stay where they are if not taken.
- **Retry, Continue, Turn Back** are unchanged in the save (version 5); Retry and Continue stand the knight at the anchor of
  `run.stage`. Setting out by the winch gate (the shortcut) walks in through the postern (`CourtRoute.SHORTCUT_IN`).
- Dev: `--screen=routewalk [--from=<stop>] [--pick=1:1,4:1] [--routecost]` walks the whole road at its own pace, fights passed
  over, printing the render cost at every stop and every 2 s of walking.

### The Witness (Courtyard, second stop)
`Companion` picks `witness_discovery` for the stop. On the real-time road the scene is staged (`Explore._find_witness`):
the knight turns to the fallen statue head and the camera eases down to its foot, where a machined hatch lies flush in
the paving. During Lyra's line the hatch slides back in its own dust; the Witness (a `WitnessDrone`, dormant, on its
back) wakes on its own first word: the seam line, then the bar, then the panels part, then it rises, rights itself and
turns to the knight. The dialogue plays (its light follows its voice), it crosses to the knight,
the knight is rebuilt with the Witness as its own (`flags.witness_found`, set by `Companion.mark_heard`), the camera
returns and the choices fade in. The filmed road plays the dialogue only, as before.
Other regions have no monument: a save that meets the Witness late gets the dialogue without the staging.

## The slice, played by touch (`--screen=slice`, `src/dev/slice_bot.gd`, added 2026-11-27)
An automated first-time player for the first-boss slice. It starts at the launch screen with no save and plays to the
Ashen Sentinel's fall and the sanctuary after it. Every button is pressed by a synthetic touch at its centre, sent
through `Input` (the path a finger takes, so a button with something lying over it is found out and logged as
`TAP MISSED`); every cut, parry, dodge, roll, block and struggle tap in a fight is a touch on the duel's own surface
and pads; the name is typed as key events. It walks: launch → menu → New Legacy → (a place, if none is free) →
body, name, cloak → the sword row, dragged to the sword asked for → Rise → Generation I (both duels fought) → the
years → the arrival → the Engine (the prompt tapped) → the walk out → stop 1 (the pouch, the lesson, the first
fight) → stop 2 (the Witness; the Guardhouse cache) → stop 3 (anything odd is touched; the Banneret) → stop 4 (the
winch) → stop 5: Turn Back → sanctuary: Armory (put on what was found), Shop (buy the dearest thing in reach), Forge
(one piece of work if it can be paid for), Settings → Return to title → Continue → out by the Winch Gate → stop 5
(fight) → stop 6 (kneel) → stop 7, the Sentinel → the victory screen → the sanctuary. It pauses once mid-fight and
resumes.

```
tools/record.sh <name> 900 --screen=slice [--body=m|f] [--weapon=<id>] [--die=1,boss] [--forge_first] [--audit]
                           [--fast] [--until=menu|arrival|quit] [--resume] [--log=<file>] [--snaps=<dir>] [--notch=l,t,r,b]
```
`--die=1,boss` stands still in the first real fight and/or the Sentinel's, then takes "Retry from checkpoint" (the road resumes at its last checkpoint, not at the foe). `--until=quit`
ends at the main menu after the sanctuary visit; a second launch with `--resume` (and the same `--savedir`) presses
Continue, checks what the save holds, and plays the rest: that pair is the app-relaunch test. `--fast` presses SKIP on
every story beat. `--audit` lists, per screen, touch targets under 60 units, text under 22, and controls outside the
safe area. The log gives the game's clock and the wall clock for every step, each fight's length and tallies, and the
peak and mean level of every audio bus during each step. A step that does not arrive is logged as `STUCK` with what
is on screen. If the touch player loses more than three unplanned fights the sim's own bot takes over and the log
says `assist`.

One full run is about 14 to 15 minutes of game time (measured: 883 s with two deliberate defeats). On the build
machine's software renderer that is one to three hours of wall time.

## Combat rules (free cutting and guarding, 2026-11-27)

The rules live in `src/combat/duel_sim.gd` (pure, seeded); `src/combat/duel.gd` shows them. Tests: `tests/tests.gd`
`t_free_combat`, `t_block_rules`. Review driver: `-- --demo=<foe> --skip_intro --combat=<log file>`
(`src/dev/combat_demo.gd`, synthetic touches through the real swipe recogniser). Balance table:
`godot --headless --path . res://tools/dev/duel_balance.tscn`.

**A swipe is always a cut.** What the cut does depends on the moment, never on whether it was the "asked for" one:

| The foe is | Any swipe | The shown line (the bonus) |
|---|---|---|
| open (recovering after a string, or broken: `B.RECOVER`, `B.STAGGER`) | lands plain damage, in any of the eight directions | along the seam (`rift_dir`): ×1.6 (`RIFT_MULT`); the first such cut after a parry is the **counter**, ×2.0 (`COUNTER_MULT`) |
| on guard (`B.IDLE`) | is thrown and **deflected**: 12% chip, a little extra stamina; `patience` such cuts running bring the foe's punish blow | none |
| winding up a blow (`B.WINDUP`) | is a parry cut. Square or one step off the blow's line, inside 0.30 s: parried (`PARRY_WINDOW`). Any other line: not a parry, the blow lands (`parry_failed {why: dir}`). Too early: it rings off the foe's guard for 6% chip and the knight is 0.25 s recovering | exact line inside 0.12 s: perfect parry (the string is cut short, 45 poise) |
| changing phase (`B.SHIFT`) | is thrown and turned for nothing | none |
| out of reach (`b_far`) | steps in (0.35 s) | none |

**Rate.** A cut takes the weapon's `swing_time`; the blade lands at 60% of it; from 85% (`CANCEL_FRAC`) a queued swipe,
a queued dodge or the shield going up cuts the rest short. One swipe is queued, the latest wins, and one made during a
cut never goes stale before that cut's cancel frame. So a flurry lands a cut every `swing_time × 0.85`: 0.22 s with the
0.26 s sword, 0.39 s with a 0.46 s greatsword. With no stamina a cut is still thrown, as a tired one (half damage, 1.4
times as long); stamina is 11 a cut with the first sword against 130, so a flurry of eight never stalls.

**Variety.** Each cut along a new line raises the count (+12% damage and +15% poise wear a step, to six); the same
line a second time holds it; a third time running it is read (the count starts over and the cut lands at 0.6); 0.9 s
without a cut landing starts it over. Named combos (`data/combos.json`) are unchanged and may repeat a line freely.

**Blocking.** A blockable blow caught on a raised guard costs **no health**. It costs one shield charge
(`shield_blocks`, back at one per `shield_regen` seconds with the guard down) and stamina (the blow's `guard`, less
`block_eff`, halved while the shield has a charge). Raised within 0.22 s of the blow, from rest, it is a **perfect
block**: nothing spent, 25 poise worn (a plain block wears 6), 0.35 s more opening. With no charge left, or not the
stamina to pay, the **guard breaks**: half the blow lands and the knight reels for 0.9 s; a shield beaten down is whole
again when the knight recovers. An **unblockable** blow ignores the guard and is announced when it is wound up
(`unblockable_warning`): it is dodged, or parried where its data allows. Fire no longer catches through a held guard;
frost still creeps through at half.

| Sim event | Sound (`Sfx.play`) | Seen |
|---|---|---|
| `block` | `block` / `shield_heavy` (heavy blow), `shield_scrape` | sparks at the contact, a warm flash on the shield, BLOCKED, the charge pip |
| `perfect_block` | `parry_perfect` over the block | bright ring on the shield, a flash, 40 sparks, PERFECT BLOCK, 0.22 s of slow time |
| `guard_break {why}` | `guard_break`, `shield_heavy` | red ring, splinters, red screen edge, shake, GUARD BROKEN or SHIELD BEATEN DOWN, the knight staggers |
| `block_failed {why}` | the hit's own | CANNOT BE BLOCKED (unblockable) · GUARD TOO SLOW (blade still committed) · TOO LATE (raised just after) |
| `parry_failed {why}` | the hit's own | WRONG LINE · TOO EARLY · CANNOT BE PARRIED |
| `unblockable_warning` | `telegraph_unblockable` | UNBLOCKABLE in red, a red ring on the foe's weapon (twice), the weapon glows red, the cue line is red |
| `boss_hit {counter}` | `parry_perfect` (high) | COUNTER ×2.0, a gold ring at the cut |
| `boss_hit` (any landed cut) | `hit_armor` (+ `hit_flesh` on a crit) | sparks on the body, the foe flashes and is driven back a pace |
| `deflected` (cut into a raised guard) | `deflect` (clash pitched up + rattle + crack; not the parry's ring) | the foe's weapon comes across to meet the cut (`FighterRig.parry` + `clash` at the cut), the knight's blade is stopped there (`halt`), sparks at the contact |

Openings differ per foe (`traits.parry_open` / `dodge_open` in `tools/gen_bosses.py`): Banneret 0.8 / 0.9 (quick to
recover), Pike Sergeant 1.35 / 0.85, Rampart Brute 0.9 / 1.35, Gate Colossus 1.25 / 1.25; the Hollow Soldier and the
Ashen Sentinel keep the plain rules. Patience (guarded cuts before the punish blow) is 2-4 per foe.

What was removed: the 0.45 "glancing" penalty for repeating a line once; the refusal to swing with no stamina; the 8%
health chip through every block; the 35% leak and doubled stamina cost of a spent shield; the 0.18 s limit on a swipe
queued during a cut.

## Continue
Continue → the road where it was left if the save holds one (the last stop reached; after a fall, its checkpoint at full health), else the sanctuary of the latest save (0.35 s fade). It never plays the opening or the chamber.

## Seen before
`Opening.SEEN_FILE` (`user://opening_seen`, beside the settings, not in a save slot) is written when Generation I ends or is skipped through. Later new journeys go from character select straight to the chamber: no Generation I, no time jump, no arrival. The menu then shows a small "Watch the Opening" at the bottom right; it plays Generation I (duels included) and returns to the menu. The chamber always plays for a new knight. New Game Plus does not pass through any of this.

## Where a wait or a cut is still shown
| Where | What the player sees | Why |
|---|---|---|
| Setting out for a region from the sanctuary or the map, or "Retry from checkpoint" after a death | Loading screen | A change of region: a whole place is built. This is the case the loading screen is kept for. |
| Entering a duel when the foe's model is not yet in memory | Loading screen | Only if the player chooses within the moment it takes the road to read the foe ahead on a thread, or on the filmed road, which does not read ahead. Otherwise a 0.35 s fade. |
| Character select → opening, opening → chamber | Black, held for as long as the next set takes to build | Both scenes open on black by design, so the build is hidden in it; it is still a held frame. |
| Chamber → Approach | White, held while the Courtyard is built | A change of place, covered by the white of the doorway. |
| Road stop → duel, lesson → real duel, duel → next stop | 0.35 s fade to black, a held black frame while the arena and both fighters are built, 0.7 s in | The duel builds its own arena and rigs (`src/combat/duel.gd`, not part of this pass). The figures and the place are the same on both sides of the fade, but it is a fade, not a cut on action. |
| Opening shot 4 → 5 | Dip through black | Three hundred years pass. |
| Opening and chamber shot changes | Hard cuts | Ordinary cutting between shots of one scene. |

## Dev screens
`--screen=prologue [--beat=1..5] [--shot=1..6] [--auto] [--body=m|f]`, `--screen=timejump [--years=22 --from=1 --to=2]`,
`--screen=arrival [--shot=1..6] [--gen=1..3] [--body=m|f]`, `--screen=title --vista`, `--screen=opening [--shot=N]` (the retired hall opening),
`--screen=awakening [--from=sword] [--auto]`, `--screen=approach [--auto]`,
`--screen=newgame [--body=m|f] [--auto] [--seen] [--bot]` (the whole chain from character select; `--auto` confirms the
knight after 2.5 s, lets a bot fight Generation I's duels, answers the sword prompt and takes the first way onward at each stop; `--seen`
passes over Generation I; `--bot` lets a bot fight on the road and skips the lesson).
