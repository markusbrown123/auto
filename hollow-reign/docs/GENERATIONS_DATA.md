# Generations: data, rules and hooks

The rules and data layer of the three-generation campaign (`docs/GENERATIONAL_CAMPAIGN_BRIEF.md`, `docs/CAMPAIGN_SCRIPT.md`). No scene or screen is in this layer. Code: `src/core/generations.gd` (rules), `src/core/encounters.gd` (the encounter director), thin wrappers at the end of `src/core/game.gd`. Data: `data/generations.json` (written by `tools/gen_regions.py`) and the `variants` list in `data/bosses.json` (written by `tools/gen_bosses.py`). Tests: `tests/generations.gd`. Simulation: `tools/econ_sim.sh --generations [--style=skilled] [--fights]`.

Today's New Journey is Generation II with Generation I already recorded as fallen. Nothing has to change for the game to run as it did.

## 1. The save (version 3)

One file per slot, as before. Four layers:

| Layer | Where | What | At a transition |
|---|---|---|---|
| PROFILE (the family's) | every key the profile had in version 2, plus `family {name, emblem}` | owned gear and item records, gold, shards, materials, mastery, combos and `combo_uses`, lore, secrets, completion, level, attributes, heraldry, `defeated`, `flags`, `rewards` | untouched (proved by test, field by field) |
| GENERATION | `generations: [record]`, one per protagonist, kept for good | `index` 1–3, `role` first/second/heir, `body`, `name`, `chapter`, `year` (0, 22, 46), `fate` alive/fallen/kept, `cause`, `context`, `loadout`, `deeds {guardians, routes, regions, discoveries}`, `stats` (fights, wins, defeats, parries, perfect_parries, dodges, perfect_dodges, blocks, hits_taken, dealt, taken, time), `authored`, `migrated` | the fallen one's record is closed; a new one is appended |
| WORLD | `world {facts, cleared}` | `facts {typed fact: generation}`; `cleared {region: [generations]}` | accumulates; `profile.cleared` (the present road) is emptied for the heir |
| CAMPAIGN | `campaign` | `generation`, `transition {state, from, to, cause}`, `history`, `monarch {"1" \| "2" \| "3": {fought, won, choice, result}}`, `inheritance {record id: generation}`, `left_weapon`, `echo` (the snapshot), `ending`, `legacy` | |

Typed facts written by the rules: `slain:<foe>`, `route_opened:<region>`, `cleared:<region>`, `monarch_bested:<gen>`, `monarch_felled:3`, `ending:<id>`. Scenes may add their own with `Game.add_fact("released:rimewyrm")`; the director's tables can test any fact with `when` / `unless`.

Relationship words are data (`generations[].relation {m, f}`, `kin`): Father/Mother, Son/Daughter, Grandson/Granddaughter; relative to the present one: Grandfather/Grandmother, Father/Mother, Yourself.

In `generations`, `world`, `campaign` and `family` a whole number is always an integer, in memory as on disk, so a save read back is identical to the save written.

### Migration (0, 1, 2 → 3)
`Game._migrate` calls `Generations.migrate`. Idempotent. Nothing the save holds is dropped.
- A journey still on the road becomes **Generation II in progress**. Generation I is recorded as fallen (authored, `migrated`), `campaign.monarch["1"]` and `flags.gen1_complete` mark its opening seen. What the save had done (guardians, opened routes, cleared regions, lore, secrets) is credited to the second as deeds and written to the world as facts.
- A journey that had chosen an ending or turned the world over (NG+) becomes **the last heir's**, with the first two recorded (fallen, kept), the canon's ending set from `last_ending`, and `legacy` = `ng`.
- No snapshot exists in a migrated save, so its echo is the default one (starting kit).
- Fixtures: `tests/fixtures/save_v0.json`, `save_v1_early.json`, `save_v1.json`, `save_v2.json` (unchanged) and `save_v3.json` (a last heir with a real snapshot, written by `tests/generations.tscn -- --write_fixture`).

## 2. API (all on `Game`; rules in `Generations`)

| Call | Does |
|---|---|
| `new_game(heraldry, body, weapon, start_generation = 2)` | `2`: as today. `1`: the first generation is the present one until `fall(1)` + `inherit()`. |
| `generation()`, `generation_record(i = 0)` | the present generation; a record |
| `fall(gen, cause, context = {}) -> bool` | one of the two canonical falls. Only the present generation, only 1 and 2, each once; otherwise `false` and nothing changes. `context`: `weapon`, `where`, `clash` (I), `choice`, `won` (II). Saves. |
| `inherit(who = {}) -> bool` | the next of the house takes up the road. `who`: `body`, `name`, `heraldry` (all optional). Needs a fall not yet answered. Saves. |
| `transition_pending()` | `{state: "fallen", from, to, cause}` between a fall and its inheritance, else `{}` |
| `fallen_weapon()`, `take_fallen_weapon()` | the blade left where it fell: `{id, generation, taken, left_where_it_fell, where, record}`. It is in the inventory and in the heir's hand whether or not the scene is played; `take` only records that it was. |
| `fighter_profile(gen = 0)`, `fighter_stats(gen = 0)` | what a generation fights with: the family's profile, except Generation I, which uses the forebear's sheet (`data/generations.json` `forebear`, the same figures as `Prologue.forebear()`) |
| `echo_foe()` | builds the echo and registers it as `Db.foes["the_kept"]` |
| `record_monarch(gen, {won, choice, result, …})`, `monarch(gen = 0)`, `monarch_won(gen)` | the three meetings |
| `add_fact(fact)`, `has_fact(fact)` | world facts |
| `inheritance()`, `endings()`, `can_divide_crown()` | records held; the three endings with `open` and `chosen` |
| `witness_state()` | `imprisoned` / `found` / `returning` |
| `lineage()` | see §7 |
| `on_legacy_journey()`, `start_legacy_journey()` (= `start_ng_plus()`) | after the story |
| `region_unlocked(id)`, `region_known(id)`, `shop_cycle()` | generation-aware gating (see §4, §8) |

`Encounters` (reads only): `generation(p)`, `access(gen, region, p)`, `unlocked(region, p)`, `sealed(gen, region, p)`, `options(gen, region, stop, p)`, `stop(gen, region, stop, p)`, `cast(gen, foe, p)`, `guardian(gen, region, p)`, `route(gen, region, p)`, `region_info(region, p)`, `why(foe)`, `foe(id, p)`, `base_of(id)`, `monarch_of(id, p)`.

### The two falls
- An ordinary defeat is `Game.on_death()`. It never touches `generations`, `world` or `campaign` (test: six defeats in a row, then three more while a transition is pending).
- `fall(1, …)`: records the clash result, the forebear's loadout and the sword. `fall(2, …)`: also takes the echo snapshot and records the choice. Both set `left_weapon` with the weapon's exact record (level, mods, ore, edge, mastery). If the weapon in hand is not owned (the forebear's own), it is added to the inventory first: it cannot be lost.
- `inherit()`: appends the new record, empties `profile.cleared`, keeps every flag (opened routes, emptied chests, scenes heard), puts the left weapon in the heir's hand, sets `flags.witness_found` and `flags.generation` for the third. The loadout is otherwise what the predecessor wore.

## 3. The echo ("the Kept", card name "The Crownless Champion")

Snapshot (`campaign.echo`, taken at `fall(2)`, never changed afterwards): body, name, heraldry, level, attributes, `equipped` per slot, `look` (the appearance loadout with cosmetic overrides), `cosmetics`, `upgrades`, `weapon {id, cls, level, mods {grip, ore, ore_id}, edge, mastery_xp, mastered}`, `shield`, `stats` (max_hp, max_stamina, attack, swing_time, mitigation, defense, block_eff, crit_mult), `combos` (top five by use, with counts), `known`, `habits {parry, dodge, block, seen}`.

Habits come from each generation's own fight tally, which `Secrets.duel_ended` feeds from `sim.stats` after every duel. The sim was not edited.

`Generations.echo_foe()` is a pure function of the snapshot:
- **Health** = the snapshot's own attack ÷ (swing time + 0.12) × 90 s, clamped 2,400–17,000.
- **A plain cut** takes 11.5 % of the snapshot's own health after its own armour (×1.25 for a greatsword or axe, ×0.82 for dual blades).
- **Patterns**: two plain cuts and an overhead everyone can read, then the player's favourite combinations with the same directions in the same order. The first blow of each is wound up in full (0.8–1.05 s by weapon class), the rest follow at the blade's pace (0.55–0.72 s). A "Counter" opens late (anti-parry), a "Guard-breaking" one ends on a guard-crushing blow (anti-block), three cuts or more are anti-dodge, "Heavy"/"Finisher" end on a slow slam or thrust. With a shield it gains a shove from phase two.
- **Phases**: 100 % (two favourites), 62 % (four, speed 1.07), 30 % (all five and the most-used one again at 115 % as its signature, speed 1.13).
- **Traits** (existing keys only): `parry_open 0.9` if the player parried most, `dodge_open 0.8` if they dodged most or carry dual blades, `block_tax 1.4` if they blocked most or carry a heavy weapon.
- **Look**: `rig` is the player's own look as it stood (`Duel.player_look()` run against the snapshot); `look {body, name, heraldry, equipped, appearance, cosmetics, weapon, shield, upgrades}` is the same information as data for the rig agent.
- Never slower to read than 0.45 s. No snapshot → the same from the starting kit (`default: true`).

Test results (skilled bot with the inherited kit, four seeds; SPAM bot, three seeds):

| Snapshot | Echo health | Plain cut | Traits | Skilled | Fastest | Mashing |
|---|---|---|---|---|---|---|
| Light sword + plank shield, dodger | 4,363 | 35 | dodge_open | 4/4 | 65 s | 0/3 |
| Greatsword, heavy plate | 13,332 | 80 | parry_open, dodge_open, block_tax | 4/4 | 105 s | 0/3 |
| Dual blades, parrier | 16,511 | 36 | parry_open, dodge_open | 4/4 | 35 s | 0/3 |
| Sword, no shield, parrier | 9,123 | 61 | parry_open | 4/4 | 69 s | 0/3 |

## 4. The encounter director

Generation II's stops are `data/regions.json` exactly. Generations I and III are told as differences, stop by stop (`data/generations.json` `stops`), so **a stop keeps its number in every generation** and with it its lore, its secrets, its chest flag and its place in the completion count. A stop not listed is as Generation II left it. `Game.stage_options()` asks the director; nothing else about a run changed.

Region access:

| Region | I | II | III |
|---|---|---|---|
| Fallen Courtyard | passed (no fight) | open | open; first |
| Blackwood | open, optional (Royal Patrol; proposed, not staged) | after the Courtyard | after the Courtyard |
| Cathedral of Ash | sealed | after the Blackwood | after the Courtyard |
| Sunken Crypt | shut | after the Cathedral | after the Courtyard; optional ("the way down") |
| Wyrm's Roost | distant | optional | after the Courtyard; optional (the dragon hunt) |
| Frozen Citadel | shut | after the Crypt | after the Courtyard |
| Hollow Deep | unknown | optional | sealed until `monarch_felled:3`, then open |
| Hollow Throne | open | after the Citadel | after two of Blackwood / Cathedral / Citadel |

Who stands where (existing roster only):

| Place | I | II | III |
|---|---|---|---|
| Courtyard | nobody bars the way | hollow_soldier, banneret, rampart_brute (pools); **Ashen Sentinel** | pike_sergeant, gate_colossus; **the Kept** (echo) |
| Blackwood | `royal_patrol` (= pike_sergeant) | stalker, thornblade, woodward; Pale Huntsman (opt.); **Hollow Executioner** | veil_dancer; Pale Huntsman if not slain (opt.); **Awakened Beast** (= maulbeast) |
| Cathedral | — | acolyte, censer_knight, **Crimson Widow**, choir_wraith; **Cathedral Beast** | censer_adept, bell_ringer; **Laboratory Guardian** (= gate_colossus) at the lower door |
| Crypt | — | squire, warden, leech; **Gravewarden** | tomb_mummer, crypt_crawler; **Devourer** if not slain |
| Roost | — | scalebound, falconer, whelp; **Veyrath** | scalebound, brood_keeper; **Veyrath** if alive, else **Azhurion** if alive, else nobody |
| Citadel | — | thrall, duelist, brute; Skeldra (opt.); **Frostbound King** | rime_glaive, hoarbeast; **Skeldra** if alive, else **the White Brood** (= frost_drake) |
| Deep | — | husk, soul_eater, oath_eater; **Devourer** | husk, name_thief, the_unburied; **Devourer** if not slain, else the Eternal Crown's room |
| Throne | `royal_gatekeeper` (= throne_guard); **Monarch, the clash** (`monarch_i`) | guard, kingsblade, crownless; Azhurion (opt.); **Monarch, the duel** | throne_colossus, herald; Azhurion if alive (opt.); **Monarch, three phases** (`monarch_iii`) |

Rules:
- A sealed region gives no stop (`options` returns `[]`).
- A mortal individual (`data/generations.json` `mortals`, and any variant marked `mortal`) that fell in an **earlier** generation never stands again; the table names who replaced it and why (`Encounters.why`, `guardian().why`). Within one generation a guardian still returns when its road is walked again, as it always has.
- Immortal: the Monarch only (`reason` on each variant).
- Every foe Generation III meets is cast as a copy `<id>_g3` brought up to the end of the road (`tuning`), or as an authored variant. Copies keep the original's rig, model, weapon, speech and reward tables (`reward_as`). They are built in memory when the director casts them, as hidden challengers are, and are not counted by completion.

Generation III's numbers (`tuning`, against the Throne's own road: health ×2.4, damage ×1.3, experience ×1.25, gold ×2.2; shards ×2):

| Home region | Health | Damage | XP | Gold |
|---|---|---|---|---|
| Courtyard | ×7.01 | ×3.51 | ×7.89 | ×12.8 |
| Blackwood | ×6.22 | ×3.2 | ×5.31 | ×9.08 |
| Cathedral | ×4.15 | ×2.11 | ×3.3 | ×5.71 |
| Crypt | ×4.06 | ×2.11 | ×2.71 | ×4.69 |
| Roost | ×2.94 | ×1.6 | ×2.01 | ×3.54 |
| Citadel | ×2.95 | ×1.56 | ×1.79 | ×3.17 |
| Deep | ×2.53 | ×1.34 | ×1.48 | ×2.61 |
| Throne | ×2.4 | ×1.3 | ×1.25 | ×2.2 |

Roster guardians met again (Huntsman, the dragons, the Devourer) are brought to 13,000 health (×1.4 to ×4.6) and take 70 % of their region's damage factor.

### Fights and time (`tools/econ_sim.sh --generations`, seed 1)

| | Fights (main / optional) | Bot's fighting, sloppy | Estimated for a person, main road | Brief's target |
|---|---|---|---|---|
| Generation I | 2 / 0 | 0.3 min | about 7 min (4 of scenes) | about 10 |
| Generation II | 31 / 7 | 13.6 min | about 96 min (9 of scenes); +17 optional | 75–90 |
| Generation III | 11 / 10 | 3.2 min | about 38 min (8 of scenes); +25 optional | 45–60 |
| Whole | 44 / 17 | | about 141 min (2.3 h); 183 min (3.1 h) with every optional road | 2–3 h |

The estimate counts a person's fighting as three times the sloppy bot's, plus 20 s a stop, 35 s around a fight and 75 s a rest. That multiplier is an assumption; nobody has timed a person. With the skilled bot the same run gives 115 min main, 153 with everything.

What Generation III pays (sloppy bot): Courtyard 5,801 gold (1,934 a win), Blackwood 2,535, Cathedral 3,482, Throne 11,693 (3,898 a win), Citadel 3,726, Crypt 1,809, Roost 2,119, Deep 2,558. The bot spends most of it finishing the forge tracks (blade 5, grip 3, ore 3, all armour +5) and ends holding about 7,400. Still on the shelf: Wyrmfang 9,000 (0.4 more throne-level wins), The Twin Hungers 14,000 (1.7), Embertwin and Oathbreaker 20,000 each (3.2). No flags.

## 5. The three meetings with the Monarch (`data/generations.json` `monarch`)

| | Foe | Rules |
|---|---|---|
| I, the clash | `monarch_i`: phase one only, damage ×0.4, no reward | `clash {min_time 9, cuts 4, release 32}` is for the scene: end it on the fourth cut after nine seconds, release at 32 s. With no hand on the controls the forebear still outlives the 32 s (test). The outcome is recorded with `record_monarch(1, {result})` or through the flags `prologue.gd` already sets (`gen1_complete`, `gen1_clash`); the fall does not depend on it. |
| II, the duel | `forgotten_monarch`, unchanged | `threshold {phase 2, at 0.33}` and `choices ["press", "records"]` are for the scene. A victory through `Game.on_victory` records `won` by itself, pays the ordinary rewards (experience, gold, the first-kill items, a guardian core), sets the fact `monarch_bested:2` and gathers the record "The Crown Can Bleed". A win is never unrecorded by a later call. |
| III, the final | `monarch_iii`: The Sovereign (100 %), The Ancient Crown (60 %, two new strings), The Last Defense (falls at 0 and is stood up again by `revive`; feeds through `lifesteal`) | Health ×1.7, damage ×1.22. Each inheritance record held weakens phase three: `revive` 0.60 → 0.20, `lifesteal` 0.30 → 0, `parry_open` 1.15 → 1.45 (none → all eight). A win sets `monarch_felled:3`, which opens the Deep. |

## 6. Inheritance records and endings

| Record | Gathered | Needs | Ending |
|---|---|---|---|
| The First Oath | I, automatic | the first has fallen | |
| The Measure of Him | I | the clash stood "ahead" | |
| The Broken Crown | II, automatic | the second has fallen | |
| The Crown Can Bleed | II | the player beat the Monarch | |
| The Surviving Version | any | 30 lore records | yes |
| The Siege That Outlived Its War | any | the Roost cleared, by anyone of the house | yes |
| The Partition Key | any | the Devourer defeated | yes |
| One Who Was Kept | III | the Kept defeated | yes |

- **The Final Silence**, **The Last Steward**: always open.
- **The Free Cities**: every record marked for it that the house has had the chance to gather. In Generation II (the game as it stands today) that is the three old conditions, unchanged. The last heir also needs One Who Was Kept. A record of a generation that was never played (a migrated save) is not asked for.
- The first ending chosen is the canon's (`campaign.ending`). `choose_ending` on a legacy journey still appends to `profile.endings` and sets `flags.last_ending`, as before, and leaves the canon alone.
- **Legacy journeys** are New Game Plus under another name: `start_ng_plus()` behaves exactly as it did. From the moment an ending is chosen or the world turns over, nothing is written to `generations`, `world` or `campaign` except `campaign.legacy`. A legacy journey walks Generation II's roads with the heir.
- **Secrets and completion** carry across generations. No secret or mission is generation-specific in the data today; the condition key `"generation": [n, …]` exists for when one is.

## 7. `Game.lineage()`

```
{house, emblem, heraldry, generation, ending, legacy, records: [...],
 people: [{index, role, ordinal, chapter, name, display, body, relation, relation_words {m, f}, kin, year, years_ago,
           fate, cause, current, authored, loadout {level, attrs, equipped, look, cosmetics, upgrades, weapon, shield},
           deeds {guardians [{id, name}], routes [{id, name}], regions [{id, name}], discoveries, lore, secrets},
           stats, weapon_left}]}
```
Reads only. The present one's loadout is live until the canon closes, then as it stood.

## 8. Hooks: who must call what

**Scenes (`src/cine/*`, `src/main.gd` routing)**
1. Generation I may stay as it is: `prologue.gd` already sets `flags.gen1_complete` / `gen1_clash`, which are read on the next save. To play it as a real generation instead: `Game.new_game(h, body, weapon, 1)`, fight with `Game.fighter_stats(1)` against `Encounters.route(1, "throne")`, then `Game.fall(1, "sealed_hall", {"clash": result})`, the time jump, `Game.inherit()`.
2. "TAKE UP YOUR SWORD": `Game.fallen_weapon()` for what lies there, `Game.take_fallen_weapon()` when it is taken. Skipping needs no call.
3. Generation II's Monarch: read `Game.monarch(2).threshold` and `.choices`; call `Game.record_monarch(2, {"choice": "press" | "records"})`. If the player wins, route the victory through `Game.on_victory("forgotten_monarch", hp)` as today (it records the win and pays), stage the restoration, then `Game.fall(2, "saved_the_records", {"choice": "records"})`, `show_time_jump(24, 2, 3, …)`, `Game.inherit({"name": …, "body": …})`. **`main.gd` still sends a throne victory to `_ending()`**: that routing is yours to change when the second fall is staged; `Game.transition_pending()` says when the scenes between generations are due.
4. Generation III: the roads need nothing new. The Kept is the option at Courtyard stop 6 (`o.foe == "the_kept"`); `Duel.setup("the_kept")` runs it. The last meeting is `monarch_iii`; phase names are in `phases[].name`. After it, `Game.has_fact("monarch_felled:3")` and the Deep is open.
5. The ending: `Game.endings()` for what can be chosen; `Game.choose_ending(id)`.
6. Lines by generation: a scene `<id>_g<N>` replaces `<id>` for generation N wherever `Companion` picks; `companion.gen.<N>.{stage, boss, topics}` replaces a region's, a foe's or the topic table for generation N; `speech` / `foe_voice` may name a variant (`the_kept`, `monarch_iii`) by its own id, otherwise it speaks as the foe it is cast from; `<voice key>_g<N>_intro` etc. are used when present. No change to `tools/gen_dialogue.py` was needed: these are ids and one optional key.

**Screens (`src/ui/*`)**
- World map and chronicle: `Game.region_unlocked(id)` is already generation-aware. For the state behind a lock, the guardian's name and the number of fights use `Encounters.region_info(id)`; do not read `Db.region_by_id[id].stages[-1]` for the guardian's name outside Generation II.
- Explore: `Game.stage_options()` is already the director's. Fight options in Generations I and III carry `was` (the authored id). A stop with nobody left gives `{type: "pass"}`.
- Lineage screen: `Game.lineage()`. Menu wording "Continue / New Legacy": `Game.slot_summary(n)` now has `generation`, `generation_title`, `family`.
- Shop and forge: `Game.shop_cycle()` replaces `profile.ng` for "only offered to those who return" (the last heir counts as a return). `shop_progress()`, material prices, patterns and quest progress count regions cleared by anyone of the house.
- HUD: the foe's `phases[i].name` exists for `monarch_iii`.

**Rig (`src/chars/*`, `Duel.player_look`, `Duel.weapon_model`)**
- The echo's `rig` is whatever `Duel.player_look()` returns for the snapshot (the profile in memory is swapped for the length of that call, the way the hidden mirror duel uses it). If `player_look` grows a parameter for a profile, call it with `Generations._echo_rig`'s stand-in instead of swapping.
- `Db.foes["the_kept"].look` has the loadout as data: `equipped`, `appearance` (with cosmetic overrides), `cosmetics`, `weapon {id, mods, level}`, `shield`, `upgrades`, `body`, `heraldry`.
- A variant keeps its base's model through `rig.skin` and its weapon through `rig.weapon_model` (set from `Duel.weapon_model` and `Duel.BOSS_WEAPON`), because `Duel.setup` looks for `assets/models/<foe id>.glb`.

## 9. Sim features wanted (`duel_sim.gd` was not edited)
1. **A story-ended fight**: an option such as `end_on {cuts, not_before, release}` that ends the duel with a third result ("interrupted"). Today the scene has to watch the sim and stop it.
2. **A mid-fight choice**: the `story_beat` event fires only at phase index 1. Generation II's choice is at phase index 2 (33 %). A `story_beat` for any phase listed in the foe (`beat_at: [2]`) would let the scene offer press / records without polling `b_phase`.
3. **Phase three as real actions**: "disable the restoration by parrying into it" is expressed today as records lowering `revive` / `lifesteal` and raising `parry_open`. A per-phase counter such as `seal {parries: 3}` (perfect parries in this phase cancel the next `revive`) would make it a thing the player does in the fight.
4. **Fractional generation scaling**: the `ng` option is a whole number. Generation III is scaled in the foe data instead, which works, but an `opts.scale {hp, dmg}` would avoid casting copies.
5. **Per-phase traits** (`phases[i].traits`): the Ancient Crown and the Last Defense share one trait set with the Sovereign.
6. **Defensive habits by direction** in `sim.stats` (dodges left / right, blocks held): the echo could then favour the side the player neglected.

## 10. What changed in existing behaviour
- `default_profile()` carries the three new layers; `SAVE_VERSION` is 3.
- `region_unlocked`, `stage_options`, `shop_progress`, `material_price`, `craft_block`, quest progress and `can_divide_crown` go through the generation rules. For Generation II their answers are what they were.
- `Rewards.roll` reads `reward_as` and `shard_mult` from the foe (absent on every roster foe).
- `Secrets.things` skips foes marked `variant`; `Secrets.duel_ended` also feeds the generation's fight tally.
- `tests/equipment.gd`: one assertion said the file on disk "is version 2"; it now compares with `Game.SAVE_VERSION`.
