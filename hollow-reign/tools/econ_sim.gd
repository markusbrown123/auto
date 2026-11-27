extends Node
## Economy and balance simulation:  tools/econ_sim.sh [--style=sloppy|skilled] [--seed=N]
## Plays the whole campaign through the real rules: every fight is a real DuelSim fight driven by a DuelBot with the
## knight's actual statistics, every victory goes through Game.on_victory, every purchase through Game.buy / upgrade /
## craft. Nothing here has its own copy of a number. It writes to a throwaway save directory.
## Prints: what each region pays, what a full upgrade of the worn weapon and armour costs at that point, when the first
## Legendary and Relic pieces arrive, and flags for any stretch where nothing meaningful was affordable for more than
## three wins or where everything was affordable at once. Then the set-against-mixed balance band.

const ORDER := ["courtyard", "blackwood", "cathedral", "crypt", "roost", "citadel", "deep", "throne"]
const DRY_LIMIT := 3

var style := DuelBot.Style.SLOPPY
var struggling := false          # two wins in three: every third fight or so is fought by the bot that always loses
var seed_base := 1
var fights := 0
var dry := 0                      # wins in a row with nothing meaningful affordable
var first_tier := {}              # tier -> [fight number, region, item]
var flags: Array = []
var row: Dictionary = {}
var start_weapon := "w_rusted_sword"
var per_win := {}                 # region -> gold a win paid there, on average
var quiet := false
var track := false                # the generational run: combinations used and each generation's own tally are recorded, as the game does
var generations_mode := false
var clock := {}                   # the generational run: {key: {fights, wins, deaths, fight_s, stops, rests, gold}}
var clock_key := ""

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "--style=skilled":
			style = DuelBot.Style.SKILLED
		if a == "--style=struggling":
			struggling = true
		if a.begins_with("--seed="):
			seed_base = int(a.trim_prefix("--seed="))
		if a.begins_with("--start="):
			start_weapon = a.trim_prefix("--start=")
		if a == "--generations":
			generations_mode = true
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_econ"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	for f: String in ["save.json", "save.bak", "save.tmp"]:
		DirAccess.remove_absolute(Game.save_dir_override + "/" + f)
	Game.slot = 1
	if generations_mode:
		generations_report()
		get_tree().quit(0)
		return
	begin(start_weapon)
	print("ECONOMY SIMULATION  starting blade: %s" % Db.item(start_weapon).name)
	print("ECONOMY SIMULATION  (player: %s, seed %d)" % ["struggling: sloppy bot, loses about one fight in three" if struggling else ("skilled bot" if style == DuelBot.Style.SKILLED else "sloppy bot, which wins every fight"), seed_base])
	print("%-10s %5s %5s %5s %7s %6s %-34s %7s %5s %9s %9s %4s %3s  %s" % ["region", "fight", "wins", "died", "gold", "shard", "materials", "spent", "level", "full-cost", "remaining", "dry", "", "worn"])
	for r: String in ORDER:
		play_region(r)
	print("")
	for t: String in ["rare", "legendary", "relic"]:
		if first_tier.has(t):
			print("first %-9s after fight %3d (%s): %s" % [t, first_tier[t][0], first_tier[t][1], Db.item(first_tier[t][2]).name])
		else:
			print("first %-9s never" % t)
	print("held at the end: %d gold, %d shards, %s" % [Game.profile.gold, Game.profile.shards, str(Game.profile.materials)])
	print("owned %d of %d items; discovered %d" % [Game.profile.inventory.size(), Db.item_list.size(), Game.profile.discovered.size()])
	# one region of the next cycle, to show that New Game Plus still pays and still costs
	Game.start_ng_plus(true)
	print("\nNEW GAME PLUS")
	play_region("courtyard")
	print("\nFLAGS")
	if flags.is_empty():
		print("  none")
	for f: String in flags:
		print("  " + f)
	shop_ladder()
	four_starts()
	sharpen_effect()
	balance_band()
	get_tree().quit(0)

func begin(weapon: String) -> void:
	for f: String in ["save.json", "save.bak", "save.tmp"]:
		DirAccess.remove_absolute(Game.save_dir_override + "/" + f)
	Game.new_game("#3d0f0f", "m", weapon)
	Game.profile.rewards.seed = seed_base
	Game.rng.seed = seed_base
	fights = 0
	dry = 0

# ------------------------------------------------------------------ the shop's ladder against what the road pays
func shop_ladder() -> void:
	print("\nSHOP LADDER  (wins to afford = price / gold a win pays where the blade unlocks; the run above)")
	print("  %-26s %-10s %6s  %-34s %9s %6s" % ["weapon", "rank", "price", "unlocks", "gold/win", "wins"])
	var rows: Array = []
	for it: Dictionary in Db.item_list:
		if it.slot != "weapon" or int(it.price) <= 0:
			continue
		var at: String = "courtyard"
		var what := "in stock from the start"
		if it.unlock.has("boss"):
			var region: String = Db.foes[it.unlock.boss].region
			at = ORDER[mini(ORDER.find(region) + 1, ORDER.size() - 1)]
			what = "after the guardian of %s" % str(Db.region_by_id[region].name).trim_prefix("The ")
		elif int(it.unlock.cleared) > 0:
			at = ORDER[mini(int(it.unlock.cleared), ORDER.size() - 1)]
			what = "after %d region(s) cleared" % int(it.unlock.cleared)
		if int(it.get("ng_min", 0)) > 0:
			what = "New Game Plus (late-road income, doubled)"
			at = "ng_late"
		rows.append([int(it.price), it, what, at])
	per_win["ng_late"] = float(per_win.get("throne", 0.0)) * (1.0 + float(Db.equipment.rewards.ng_gold))
	rows.sort_custom(func(a, b): return a[0] < b[0])
	for r: Array in rows:
		var g: float = float(per_win.get(r[3], 0.0))
		var wins: float = float(r[0]) / maxf(1.0, g)
		print("  %-26s %-10s %6d  %-34s %9.0f %6.1f%s" % [r[1].name, Db.tier(r[1]), r[0], r[2], g, wins, "   !" if g > 0.0 and (wins > 14.0 or (wins < 0.5 and r[0] > 400)) else ""])
		if g > 0.0 and wins > 14.0:
			flags.append("%s: %.0f wins to afford where it unlocks" % [r[1].name, wins])
	print("  dropped, never sold: %s" % ", ".join(Db.equipment.boss_weapons.values().map(func(id): return "%s (%s)" % [Db.item(id).name, Db.tier(Db.item(id))])))

# ------------------------------------------------------------------ the four starting blades
func four_starts() -> void:
	print("\nTHE FOUR STARTS  (each plays the Courtyard and the Blackwood; then ten seeded fights each with the sloppy bot, bare starting kit)")
	print("  %-18s %6s %5s %5s %6s %6s   %-22s %-22s" % ["start", "fights", "wins", "died", "gold", "level", "Sentinel wins / time", "Executioner wins / time"])
	var keep_flags := flags.duplicate()
	quiet = true
	for id: String in Db.equipment.basic_swords:
		begin(id)
		var f := 0
		var w := 0
		var d := 0
		for r: String in ["courtyard", "blackwood"]:
			play_region(r)
			f += int(row.fights)
			w += int(row.wins)
			d += int(row.deaths)
		var p := Game.default_profile()
		p.equipped.weapon = id
		var st := Stats.compute(p, Db.items, Db.classes)
		var bits: Array = []
		for foe: String in ["ashen_sentinel", "hollow_executioner"]:
			var wins := 0
			var time := 0.0
			for i: int in 10:
				var s := DuelSim.new()
				s.setup(st, Db.foes[foe], 300 + i, {"combos": Db.combos})
				var bot := DuelBot.new(s, DuelBot.Style.SLOPPY, 300 + i)
				for t: int in 300 * 60:
					bot.tick(1.0 / 60.0)
					s.tick(1.0 / 60.0)
					if s.over:
						break
				wins += 1 if s.b_state == DuelSim.B.DEAD else 0
				time += s.time
			bits.append("%2d/10  %5.0fs" % [wins, time / 10.0])
		print("  %-18s %6d %5d %5d %6d %6d   %-22s %-22s" % [Db.item(id).name, f, w, d, Game.profile.gold, Game.profile.level, bits[0], bits[1]])
	quiet = false
	flags = keep_flags

func sharpen_effect() -> void:
	print("\nSHARPEN  (skilled bot, same seed, bare starting kit against the Ashen Sentinel)")
	for id: String in Db.equipment.basic_swords:
		var p := Game.default_profile()
		p.equipped.weapon = id
		var out: Array = []
		for keen: bool in [false, true]:
			p.edge = {id: 3} if keen else {}
			var s := DuelSim.new()
			s.setup(Stats.compute(p, Db.items, Db.classes), Db.foes.ashen_sentinel, 21, {"combos": Db.combos})
			var bot := DuelBot.new(s, DuelBot.Style.SKILLED, 21)
			for t: int in 300 * 60:
				bot.tick(1.0 / 60.0)
				s.tick(1.0 / 60.0)
				if s.over:
					break
			out.append(s.time)
		print("  %-18s dull %5.1fs   keen %5.1fs   (%+.0f%%)   costs %d gold for three fights" % [Db.item(id).name, out[0], out[1], 100.0 * (out[1] / out[0] - 1.0), int(Db.item(id).mods.sharpen.gold)])

# ------------------------------------------------------------------ one region, until it is cleared
func play_region(region: String) -> void:
	row = {"fights": 0, "wins": 0, "deaths": 0, "gold": 0, "shards": 0, "mats": {}, "spent": 0, "dry": 0}
	var gold0: int = Game.profile.gold
	var shards0: int = Game.profile.shards
	var mats0: Dictionary = Game.profile.materials.duplicate()
	var cleared := false
	var sweeps := 0
	var attempts := 0
	while not cleared or (sweeps < 2 and unfinished(region)):
		if cleared:
			sweeps += 1
		attempts += 1
		Game.start_run(region, Game.shortcut_open(region) and cleared == false and attempts > 1 and not unfinished(region))
		var alive := true
		while alive:
			tick_clock("stops", 1)
			var o: Dictionary = choose(Game.stage_options())
			match str(o.type):
				"treasure":
					Game.open_treasure(o)
				"lever":
					Game.pull_lever(o)
				"shrine":
					Game.rest_at_shrine()
				"fight", "boss":
					alive = duel(str(o.foe), attempts)
			if not alive:
				break
			if not Game.advance_stage():
				cleared = true
				Game.complete_region()
				break
		if not alive:
			row.deaths += 1
			tick_clock("deaths", 1)
			Game.on_death()
		tick_clock("rests", 1)
		row.spent += sanctuary()
		if attempts > 40:
			flags.append("%s: not cleared in 40 attempts" % region)
			break
	row.gold = Game.profile.gold - gold0 + int(row.spent)
	row.shards = Game.profile.shards - shards0 + int(row.get("shards_spent", 0))
	var mats: Array = []
	for m: String in Game.profile.materials:
		var d: int = int(Game.profile.materials[m]) - int(mats0.get(m, 0)) + int(row.get("mats_spent", {}).get(m, 0))
		if d != 0:
			mats.append("%s %d" % [str(Db.materials[m].name), d])
	per_win["ng" if int(Game.profile.ng) > 0 else region] = float(row.gold) / maxf(1.0, float(row.wins))
	if quiet:
		return
	var cost := full_cost()
	print("%-10s %5d %5d %5d %7d %6d %-34s %7d %5d %9d %9d %4d %3s  %s" % [region, row.fights, row.wins, row.deaths, row.gold, row.shards, ", ".join(mats),
		row.spent, Game.profile.level, cost.total, cost.remaining, row.dry, "!" if int(row.dry) > DRY_LIMIT else "", worn()])
	if int(row.dry) > DRY_LIMIT:
		flags.append("%s: %d wins in a row with nothing meaningful affordable" % [region, row.dry])
	if cost.remaining > 0 and Game.profile.gold >= cost.remaining_gold:
		flags.append("%s: everything left is affordable at once (%d gold held, %d needed)" % [region, Game.profile.gold, cost.remaining_gold])
	if Game.profile.gold > 2 * maxi(1, int(row.gold)):
		flags.append("%s: gold is piling up unspent (%d held, the region paid %d)" % [region, Game.profile.gold, row.gold])

## Something still to do on a cleared road: an unopened chest or an optional guardian not yet ended.
func unfinished(region: String) -> bool:
	var r: Dictionary = Db.region_by_id[region]
	var gen := Encounters.generation(Game.profile)
	for i: int in r.stages.size():
		for o: Dictionary in Encounters.stop(gen, region, i, Game.profile).options:      # the second generation: the road's own options
			if o.type == "treasure" and not Game.profile.flags.has("chest_%s_%d_%s" % [region, i, o.label]):
				if not o.has("needs") or Game.profile.flags.has(o.needs):
					return true
			if o.type == "boss" and o.get("optional", false) and not Game.profile.defeated.has(o.foe):
				return true
	return false

## One option per stop, as in the game: new chests and levers first, then an optional guardian, then the road.
func choose(opts: Array) -> Dictionary:
	for kind: String in ["treasure", "lever", "boss", "shrine", "fight"]:
		for o: Dictionary in opts:
			if str(o.type) != kind:
				continue
			if kind == "treasure" and Game.profile.flags.has(Game._chest_flag(o)):
				continue
			if kind == "boss" and o.get("optional", false) and Game.profile.defeated.has(o.foe):
				continue
			return o
	return opts[0]

func duel(foe: String, attempt: int) -> bool:
	fights += 1
	row.fights += 1
	var s := DuelSim.new()
	var known: Array = []
	for id: String in Game.profile.combos:
		known.append(Db.combo_by_id[id])
	var sd: int = hash("%d|%s|%d" % [seed_base, foe, fights])
	s.setup(Game.stats(), Db.foes[foe], sd, {"combos": known, "start_hp": Game.run.hp, "ng": Game.profile.ng})
	# a road that has beaten the player six times is finally walked with care
	var how: int = style
	if struggling and absi(hash("lose|%d" % sd)) % 100 < 35:
		how = DuelBot.Style.TURTLE
	var bot := DuelBot.new(s, DuelBot.Style.SKILLED if attempt > 6 else how, sd)
	if track:
		s.ev.connect(func(n: StringName, d: Dictionary):
			if n == &"boss_hit" and str(d.get("named", "")) != "":
				Game.use_combo(str(d.get("combo_id", ""))))
	for i: int in 300 * 60:
		bot.tick(1.0 / 60.0)
		s.tick(1.0 / 60.0)
		if s.over:
			break
	tick_clock("fights", 1)
	tick_clock("fight_s", s.time)
	if OS.get_cmdline_user_args().has("--fights"):
		print("    %-4s %-22s %5.0fs  %s  health left %3.0f%%  hits taken %d  (took %3.0f%% of %d health in all, mended %d times, armour stops %2.0f%%, began at %3.0f%%)" % [clock_key, foe, s.time, "won " if s.b_state == DuelSim.B.DEAD else "LOST", 100.0 * float(s.pl.hp) / float(s.pl.max_hp), int(s.stats.hits_taken),
			100.0 * float(s.stats.taken) / float(s.pl.max_hp), int(s.pl.max_hp), int(s.stats.get("relics", 0)), 100.0 * float(s.pl.mitigation), 100.0 * float(Game.run.hp) / float(s.pl.max_hp)])
	if track:
		Generations.note_duel(Game.profile, s.b_state == DuelSim.B.DEAD, s)
	if s.b_state != DuelSim.B.DEAD:
		return false
	row.wins += 1
	tick_clock("wins", 1)
	var r := Game.on_victory(foe, s.pl.hp)
	for id: String in r.items:
		var t := Db.tier(Db.item(id))
		if not first_tier.has(t):
			first_tier[t] = [fights, Game.run.region, id]
	dry = 0 if affordable() else dry + 1
	row.dry = maxi(int(row.dry), dry)
	return true

## Is there something worth buying right now: an upgrade of something worn, a better piece in the shop, a pattern?
func affordable() -> bool:
	for slot: String in Game.profile.equipped:
		var id = Game.profile.equipped[slot]
		if id != null and upgradable(str(id), false):
			return true
	var w: String = str(Game.profile.equipped.weapon)
	if Game.mod_block(w, "grip") in ["", "Not enough shards"] and cover(Game.mod_cost(w, "grip"), false):
		return true
	if Game.weapon_mods(w).edge == 0 and Game.profile.gold >= int(Game.mod_cost(w, "sharpen").gold):
		return true
	for it: Dictionary in Game.shop_stock():
		if Game.profile.gold >= int(it.price) and better(it):
			return true
	for it: Dictionary in Game.craft_stock():
		if cover(it.craft, false):
			return true
	return false

## Buys whatever shards and materials the cost still lacks, if the whole thing can be paid for. True when it now can be.
func cover(cost: Dictionary, really: bool) -> bool:
	var extra := Game.shortfall_price(cost)
	if extra < 0 or Game.profile.gold < int(cost.get("gold", 0)) + extra:
		return false
	if really:
		var need: Dictionary = cost.get("materials", {}).duplicate()
		need["shards"] = int(cost.get("shards", 0))
		for m: String in need:
			var lack: int = int(need[m]) - Game.material_count(m)
			if lack > 0:
				Game.buy_material(m, lack)
	return true

func upgradable(id: String, really: bool) -> bool:
	var it: Dictionary = Db.item(id)
	if not it.has("upgrade") or Game.upgrade_level(id) >= int(it.upgrade.max):
		return false
	return cover(Game.upgrade_cost(id), really)

func better(it: Dictionary) -> bool:
	var cur = Game.profile.equipped.get(it.slot)
	if it.slot == "weapon":
		return dps(Game.preview_stats("weapon", str(it.id))) > dps(Game.stats()) * 1.02 and Game.meets_requirements(str(it.id))
	if cur == null:
		return it.slot != "shield" or not Db.classes[Db.item(str(Game.profile.equipped.weapon)).cls].two_handed
	return score(it) > score(Db.item(str(cur))) and (not it.has("weight") or Game.meets_requirements(str(it.id)))

func dps(st: Dictionary) -> float:
	return float(st.attack) / (float(st.swing_time) + 0.12)

func score(it: Dictionary) -> float:
	return float(it.get("defense", 0)) * (1.0 + 0.1 * Game.upgrade_level(str(it.id))) + float(it.get("hp", 0)) * 0.25 + float(it.get("stamina", 0)) * 0.25 \
		+ float(it.get("resist", 0)) * 0.1 + float(it.get("crit", 0)) * 0.4 + float(it.get("strength", 0)) + float(it.get("dex", 0)) + float(it.get("block", 0)) * 20.0

## Between roads: spend points, hand in tasks, wear the best, buy, make, and have Orren work on what is worn.
func sanctuary() -> int:
	var gold0: int = Game.profile.gold
	var earned := 0
	var i := 0
	while Game.profile.attr_points > 0:
		Game.spend_attr(["health", "strength", "dex", "endurance"][i % 4])
		i += 1
	for q: Dictionary in Db.quests:
		var g: int = Game.profile.gold
		if Game.claim_quest(str(q.id)):
			earned += Game.profile.gold - g
	for c: String in Db.challenges:
		Game.claim_challenge(c)
	wear_best()
	var bought := true
	while bought:
		bought = false
		var pick: Dictionary = {}
		for it: Dictionary in Game.shop_stock():
			if Game.profile.gold >= int(it.price) and better(it) and (pick.is_empty() or int(it.price) < int(pick.price)):
				pick = it
		if not pick.is_empty():
			bought = Game.buy(str(pick.id))
			wear_best()
	for it: Dictionary in Game.craft_stock():
		if better(it) and cover(it.craft, true) and Game.can_craft(str(it.id)):
			note_cost(it.craft)
			Game.craft(str(it.id))
			wear_best()
	var worked := true
	while worked:
		worked = false
		var best := ""
		var best_gold := 1 << 30
		for slot: String in ["weapon", "chest", "shield", "helm", "legs", "shoulders", "gauntlets", "boots"]:
			var id = Game.profile.equipped.get(slot)
			if id == null or not upgradable(str(id), false):
				continue
			var c := Game.upgrade_cost(str(id))
			if slot == "weapon" or int(c.gold) < best_gold:
				best = str(id)
				best_gold = int(c.gold)
				if slot == "weapon":
					break
		if best != "" and upgradable(best, true):
			note_cost(Game.upgrade_cost(best))
			worked = Game.upgrade(best)
	# the grip, as far as the ore allows; and a keen edge for the road, when it is small change
	var w: String = str(Game.profile.equipped.weapon)
	while Game.mod_block(w, "grip") in ["", "Not enough shards"] and cover(Game.mod_cost(w, "grip"), true):
		note_cost(Game.mod_cost(w, "grip"))
		if not Game.mod(w, "grip"):
			break
	if Game.profile.gold >= 4 * int(Game.mod_cost(w, "sharpen").gold):
		Game.sharpen(w)
	dry = 0 if gold0 > Game.profile.gold - earned else dry
	return gold0 + earned - Game.profile.gold

func note_cost(c: Dictionary) -> void:
	row["shards_spent"] = int(row.get("shards_spent", 0)) + int(c.get("shards", 0))
	if not row.has("mats_spent"):
		row["mats_spent"] = {}
	for m: String in c.get("materials", {}):
		row.mats_spent[m] = int(row.mats_spent.get(m, 0)) + int(c.materials[m])

func wear_best() -> void:
	for id: String in Game.profile.inventory.duplicate():
		var it: Dictionary = Db.item(id)
		if it.is_empty() or Game.is_equipped(id) or it.slot == "shield" and Db.classes[Db.item(str(Game.profile.equipped.weapon)).cls].two_handed:
			continue
		if better(it):
			Game.equip(id)

## Gold (and the rest) to take the worn weapon and the six armour pieces from nothing to perfected, and what is left to pay.
func full_cost() -> Dictionary:
	var out := {"total": 0, "remaining": 0, "remaining_gold": 0}
	for slot: String in ["weapon", "helm", "chest", "shoulders", "gauntlets", "legs", "boots"]:
		var id = Game.profile.equipped.get(slot)
		if id == null:
			continue
		var it: Dictionary = Db.item(str(id))
		for n: int in int(it.upgrade.max):
			var g: int = int(Stats.upgrade_cost(it, n).gold)
			out.total += g
			if n >= Game.upgrade_level(str(id)):
				out.remaining += g
				out.remaining_gold += g
		if slot == "weapon":
			for n: int in it.mods.grip.size():
				out.total += int(it.mods.grip[n].gold)
				if n >= int(Game.weapon_mods(str(id)).grip):
					out.remaining += int(it.mods.grip[n].gold)
					out.remaining_gold += int(it.mods.grip[n].gold)
	return out

func worn() -> String:
	var bits: Array = []
	for slot: String in ["weapon", "shield", "helm", "chest", "shoulders", "gauntlets", "legs", "boots"]:
		var id = Game.profile.equipped.get(slot)
		if id != null:
			var tag := "+%d" % Game.upgrade_level(str(id))
			if slot == "weapon":
				var m := Game.weapon_mods(str(id))
				tag = "[blade %d grip %d ore %d]" % [m.blade, m.grip, m.ore]
			bits.append("%s%s" % [str(id).trim_prefix("a_").trim_prefix("w_").trim_prefix("s_"), tag])
	return " ".join(bits)

# ------------------------------------------------------------------ full sets against mixed builds
func build(pieces: Dictionary, weapon: String, shield, attr_bonus: int) -> Dictionary:
	var p := Game.default_profile()
	for k: String in ["health", "strength", "dex", "endurance"]:
		p.attrs[k] += attr_bonus
	p.equipped.weapon = weapon
	p.equipped.shield = shield
	for slot: String in Db.ARMOUR_SLOTS:
		p.equipped[slot] = "a_%s_%s" % [pieces[slot], slot]
	return p

func trial(label: String, p: Dictionary, foe: String) -> void:
	var st := Stats.compute(p, Db.items, Db.classes)
	var wins := 0
	var hp := 0.0
	var time := 0.0
	var n := 10
	for i: int in n:
		var s := DuelSim.new()
		s.setup(st, Db.foes[foe], 100 + i, {"combos": Db.combos})
		var bot := DuelBot.new(s, DuelBot.Style.SLOPPY, 100 + i)
		for t: int in 300 * 60:
			bot.tick(1.0 / 60.0)
			s.tick(1.0 / 60.0)
			if s.over:
				break
		if s.b_state == DuelSim.B.DEAD:
			wins += 1
			hp += s.pl.hp / s.pl.max_hp
		time += s.time
	print("  %-34s def %3.0f  hp %3.0f  stam %3.0f  regen %4.1f  swing %4.1f  guard %3.0f%%  resist %2.0f   wins %2d/%d  health left %3.0f%%  %3.0fs" % [label, st.defense, st.max_hp,
		st.max_stamina, st.stamina_regen, st.swing_cost, st.block_eff * 100.0, st.resist, wins, n, 100.0 * hp / maxf(1.0, wins), time / n])

func balance_band() -> void:
	print("\nSET AGAINST MIXED  (sloppy bot, ten seeds each; same weapon, shield and attributes within a group)")
	var all := func(s: String) -> Dictionary:
		var d := {}
		for slot: String in Db.ARMOUR_SLOTS:
			d[slot] = s
		return d
	var mix := func(a: String, b: String) -> Dictionary:
		return {"helm": a, "chest": b, "shoulders": a, "gauntlets": b, "legs": a, "boots": b}
	print(" Rare, against the Hollow Executioner")
	trial.call("Widow x6 (light)", build(all.call("black"), "w_knight_sword", "s_garrison", 6), "hollow_executioner")
	trial.call("Ashbound x6 (heavy)", build(all.call("ash"), "w_knight_sword", "s_garrison", 6), "hollow_executioner")
	trial.call("3 Widow + 3 Ashbound (mixed)", build(mix.call("black", "ash"), "w_knight_sword", "s_garrison", 6), "hollow_executioner")
	trial.call("3 Ashbound + 3 Widow (mixed)", build(mix.call("ash", "black"), "w_knight_sword", "s_garrison", 6), "hollow_executioner")
	print(" Legendary, against the Gravewarden")
	trial.call("Gravekeeper x6 (medium)", build(all.call("vigil"), "w_rime_sword", "s_reliquary", 12), "gravewarden")
	trial.call("Frostwarden x6 (heavy)", build(all.call("frost"), "w_rime_sword", "s_reliquary", 12), "gravewarden")
	trial.call("Dragonforged x6 (heavy)", build(all.call("wyrm"), "w_rime_sword", "s_reliquary", 12), "gravewarden")
	trial.call("3 Gravekeeper + 3 Frostwarden", build(mix.call("vigil", "frost"), "w_rime_sword", "s_reliquary", 12), "gravewarden")
	trial.call("2 Frost + 2 Wyrm + 2 Gravekeeper", build({"helm": "frost", "chest": "wyrm", "shoulders": "vigil", "gauntlets": "frost", "legs": "wyrm", "boots": "vigil"}, "w_rime_sword", "s_reliquary", 12), "gravewarden")
	print(" Relic, against the Forgotten Monarch")
	trial.call("Sovereign x6 (medium)", build(all.call("regal"), "w_frost_great", null, 18), "forgotten_monarch")
	trial.call("Architect x6 (light)", build(all.call("hollow"), "w_frost_great", null, 18), "forgotten_monarch")
	trial.call("3 Sovereign + 3 Architect", build(mix.call("regal", "hollow"), "w_frost_great", null, 18), "forgotten_monarch")

# ------------------------------------------------------------------ the three generations:  tools/econ_sim.sh --generations [--style=skilled]
## Plays the whole of the campaign as the generations tell it, through the same rules: the first generation's slice
## (with the forebear's sheet), the fall, the second generation's roads (today's campaign), the second fall, and the
## last heir's faster pass with everything inherited. Prints fights and estimated minutes for each, what the last
## pass pays, and how far the shop's top shelf is from what it pays.
const WALK_S := 20.0             # a stop: the walk to it and the choice
const FRAME_S := 35.0            # around a fight: the approach, the first words, the end, the reward screen
const HUMAN_X := 3.0            # how much longer a person fights than the bot does (assumed)
const REST_S := 75.0             # a visit to the sanctuary
const G2_MAIN := ["courtyard", "blackwood", "cathedral", "crypt", "citadel", "throne"]
const G3_MAIN := ["courtyard", "blackwood", "cathedral", "throne"]
const G3_SIDE := ["citadel", "crypt", "roost", "deep"]

func tick_clock(what: String, n: float) -> void:
	if clock_key == "":
		return
	if not clock.has(clock_key):
		clock[clock_key] = {"fights": 0.0, "wins": 0.0, "deaths": 0.0, "fight_s": 0.0, "stops": 0.0, "rests": 0.0}
	clock[clock_key][what] += n

## Minutes of play for a tally. The bots end a fight far sooner than a person does, so the fighting is counted
## HUMAN_X times over: an assumption, stated in the report, not a measurement.
func clock_minutes(key: String) -> float:
	var c: Dictionary = clock.get(key, {})
	if c.is_empty():
		return 0.0
	return (float(c.fight_s) * HUMAN_X + FRAME_S * float(c.fights) + WALK_S * float(c.stops) + REST_S * float(c.rests)) / 60.0

## One fight outside a road (the first generation's two): returns the sim when it is over or `limit` seconds have gone.
func staged(foe: String, st: Dictionary, limit: float, cuts_to_end: int = 0, not_before: float = 0.0) -> DuelSim:
	var s := DuelSim.new()
	var sd: int = hash("%d|%s" % [seed_base, foe])
	s.setup(st, Db.foes[foe], sd, {"combos": [Db.combos[0]]})
	var bot := DuelBot.new(s, style, sd)
	var landed := [0]
	s.ev.connect(func(n: StringName, d: Dictionary):
		if n == &"boss_hit" and not d.get("chip", false):
			landed[0] += 1)
	while s.time < limit and not s.over:
		bot.tick(1.0 / 60.0)
		s.tick(1.0 / 60.0)
		if cuts_to_end > 0 and s.time >= not_before and landed[0] >= cuts_to_end:
			break
	tick_clock("fights", 1)
	tick_clock("fight_s", s.time)
	return s

func generations_report() -> void:
	track = true
	quiet = true
	for f: String in ["save.json", "save.bak", "save.tmp"]:
		DirAccess.remove_absolute(Game.save_dir_override + "/" + f)
	Game.new_game("#3d0f0f", "m", start_weapon, 1)
	Game.profile.rewards.seed = seed_base
	Game.rng.seed = seed_base
	print("THE THREE GENERATIONS  (%s bot, seed %d, starting blade %s)" % ["skilled" if style == DuelBot.Style.SKILLED else "sloppy", seed_base, Db.item(start_weapon).name])
	# ---- I
	clock_key = "I"
	var notes: Array = []
	for e: Dictionary in Encounters.route(1, "throne", Game.profile):
		tick_clock("stops", 1)
		var v: Dictionary = Encounters.variants[e.foe]
		if v.has("clash"):
			var s := staged(str(e.foe), Game.fighter_stats(1), float(v.clash.release), int(v.clash.cuts), float(v.clash.min_time))
			notes.append("%s: story ends it at %.0fs, forebear at %.0f%% health%s" % [v.name, s.time, 100.0 * float(s.pl.hp) / float(s.pl.max_hp), "  ! THE FOREBEAR DIED" if s.p_state == DuelSim.P.DEAD else ""])
			Game.fall(1, "sealed_hall", {"clash": "ahead" if s.time < float(v.clash.release) else "even"})
		else:
			var tries := 0
			var s := staged(str(e.foe), Game.fighter_stats(1), 300.0)
			while s.b_state != DuelSim.B.DEAD and tries < 5:
				tries += 1
				tick_clock("deaths", 1)
				seed_base += 1000
				s = staged(str(e.foe), Game.fighter_stats(1), 300.0)
			seed_base -= 1000 * tries
			notes.append("%s: won in %.0fs after %d defeat(s)" % [v.name, s.time, tries])
	Game.inherit()
	gen_line(1, ["I"], notes)
	# ---- II
	var side: Array = []
	for r: String in ORDER:
		clock_key = "II" if G2_MAIN.has(r) else "II+"
		play_region(r)
		if not G2_MAIN.has(r):
			side.append(r)
	gen_line(2, ["II", "II+"], ["optional roads: %s" % ", ".join(side), "the Monarch was beaten in the fight: %s" % str(Game.monarch_won(2)),
		"at the fall: level %d, %d gold held, wearing %s" % [Game.profile.level, Game.profile.gold, worn()]])
	Game.fall(2, "saved_the_records", {"choice": "records"})
	Game.inherit()
	# ---- III
	var gold0: int = Game.profile.gold
	var pay: Array = []
	for r: String in G3_MAIN + G3_SIDE:
		clock_key = "III" if G3_MAIN.has(r) else "III+"
		if not Game.region_unlocked(r):
			pay.append("%s: not open" % r)
			continue
		play_region(r)
		pay.append("%-10s %2d fights %2d died  %6d gold  (%4.0f a win)  level %d" % [r, row.fights, row.deaths, row.gold, per_win.get(r, 0.0), Game.profile.level])
	gen_line(3, ["III", "III+"], ["the echo: %s" % ("built from the second's snapshot" if not Game.echo_foe().default else "the default"),
		"at the end: level %d, %d gold held, wearing %s" % [Game.profile.level, Game.profile.gold, worn()]])
	print("\nGENERATION III, ROAD BY ROAD  (foes brought up to the end of the road: data/generations.json \"tuning\")")
	for l: String in pay:
		print("  " + l)
	var total := 0.0
	var total_all := 0.0
	for k: String in ["I", "II", "III"]:
		total += clock_minutes(k) + float(Generations.def(["I", "II", "III"].find(k) + 1).scenes_min)
	total_all = total + clock_minutes("II+") + clock_minutes("III+")
	print("\n(a person is taken to fight %.0f times as long as the bot; a stop %.0fs, the frame of a fight %.0fs, a rest %.0fs)" % [HUMAN_X, WALK_S, FRAME_S, REST_S])
	print("WHOLE CAMPAIGN  main roads %.0f min (%.1f h); with every optional road %.0f min (%.1f h)" % [total, total / 60.0, total_all, total_all / 60.0])
	# ---- the top shelf
	var g3: Dictionary = clock.get("III", {})
	var earned: float = float(Game.profile.gold - gold0)
	print("\nTOP SHELF  (what is still for sale when the last road is walked; a win on the last heir's main roads pays about %.0f gold)" % (float(per_win.get("throne", 0.0))))
	var rows: Array = []
	for e: Dictionary in Game.shop_catalog():
		if e.available:
			rows.append(e)
	for id: String in Game.profile.inventory:
		if int(Db.item(id).get("ng_min", 0)) > 0:
			print("  owned        %-26s %-10s (only offered to those who return)" % [Db.item(id).name, Db.tier(Db.item(id))])
	for e: Dictionary in rows:
		print("  %-12s %-26s %-10s %6d gold  %s" % ["affordable" if e.affordable else "for sale", e.item.name, Db.tier(e.item), e.price,
			"" if e.affordable else "%.1f more wins" % (float(e.price - Game.profile.gold) / maxf(1.0, float(per_win.get("throne", 1.0))))])
	if rows.is_empty():
		print("  nothing is left on the shelf")
	print("  held: %d gold, %d shards; net gold over the last generation %+.0f" % [Game.profile.gold, Game.profile.shards, earned])
	print("\nFLAGS")
	if flags.is_empty():
		print("  none")
	for f: String in flags:
		print("  " + f)

func gen_line(i: int, keys: Array, notes: Array) -> void:
	var d: Dictionary = Generations.def(i)
	var main: Dictionary = clock.get(keys[0], {"fights": 0.0, "wins": 0.0, "deaths": 0.0, "fight_s": 0.0})
	var scenes: float = float(d.scenes_min)
	print("\nGENERATION %s  %s  (year +%d)" % [keys[0], d.chapter, int(d.year)])
	print("  main road   %3d fights, %2d defeats, %5.1f min of fighting by the bot; about %3.0f min for a person with walking, rests and %.0f min of scenes" % [int(main.fights), int(main.deaths), float(main.fight_s) / 60.0, clock_minutes(keys[0]) + scenes, scenes])
	if keys.size() > 1 and clock.has(keys[1]):
		var opt: Dictionary = clock[keys[1]]
		print("  optional    %3d fights, %2d defeats, %5.1f min of fighting; about %3.0f min more" % [int(opt.fights), int(opt.deaths), float(opt.fight_s) / 60.0, clock_minutes(keys[1])])
	for n: String in notes:
		print("  " + n)
