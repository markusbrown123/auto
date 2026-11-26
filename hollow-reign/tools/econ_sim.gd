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
var seed_base := 1
var fights := 0
var dry := 0                      # wins in a row with nothing meaningful affordable
var first_tier := {}              # tier -> [fight number, region, item]
var flags: Array = []
var row: Dictionary = {}

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "--style=skilled":
			style = DuelBot.Style.SKILLED
		if a.begins_with("--seed="):
			seed_base = int(a.trim_prefix("--seed="))
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_econ"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	for f: String in ["save.json", "save.bak", "save.tmp"]:
		DirAccess.remove_absolute(Game.save_dir_override + "/" + f)
	Game.slot = 1
	Game.new_game()
	Game.profile.rewards.seed = seed_base
	Game.rng.seed = seed_base
	print("ECONOMY SIMULATION  (bot: %s, seed %d)" % ["skilled" if style == DuelBot.Style.SKILLED else "sloppy", seed_base])
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
	Game.start_ng_plus()
	print("\nNEW GAME PLUS")
	play_region("courtyard")
	print("\nFLAGS")
	if flags.is_empty():
		print("  none")
	for f: String in flags:
		print("  " + f)
	balance_band()
	get_tree().quit(0)

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
			Game.on_death()
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
	var cost := full_cost()
	print("%-10s %5d %5d %5d %7d %6d %-34s %7d %5d %9d %9d %4d %3s  %s" % [region, row.fights, row.wins, row.deaths, row.gold, row.shards, ", ".join(mats),
		row.spent, Game.profile.level, cost.total, cost.remaining, row.dry, "!" if int(row.dry) > DRY_LIMIT else "", worn()])
	if int(row.dry) > DRY_LIMIT:
		flags.append("%s: %d wins in a row with nothing meaningful affordable" % [region, row.dry])
	if cost.remaining > 0 and Game.profile.gold >= cost.remaining_gold and Game.shop_stock().is_empty():
		flags.append("%s: everything is affordable at once (%d gold held, %d needed)" % [region, Game.profile.gold, cost.remaining_gold])
	if cost.remaining_gold > 0 and int(row.gold) > 0 and float(cost.remaining_gold) / float(row.gold) > 6.0:
		flags.append("%s: a full upgrade of what is worn costs %.1f times what the region pays" % [region, float(cost.remaining_gold) / float(row.gold)])

## Something still to do on a cleared road: an unopened chest or an optional guardian not yet ended.
func unfinished(region: String) -> bool:
	var r: Dictionary = Db.region_by_id[region]
	for i: int in r.stages.size():
		for o: Dictionary in r.stages[i].options:
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
	var bot := DuelBot.new(s, DuelBot.Style.SKILLED if attempt > 6 else style, sd)
	for i: int in 300 * 60:
		bot.tick(1.0 / 60.0)
		s.tick(1.0 / 60.0)
		if s.over:
			break
	if s.b_state != DuelSim.B.DEAD:
		return false
	row.wins += 1
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
		if id != null and Game.can_upgrade(str(id)):
			return true
	for it: Dictionary in Game.shop_stock():
		if Game.profile.gold >= int(it.price) and better(it):
			return true
	for it: Dictionary in Game.craft_stock():
		if Game.can_craft(str(it.id)):
			return true
	return false

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
	var w: Dictionary = Db.item(str(Game.profile.equipped.weapon))
	var main: String = "strength" if float(Db.classes[w.cls].scale.strength) >= 0.5 else "dex"
	while Game.profile.attr_points > 0:
		Game.spend_attr(["health", main, "endurance", main][i % 4])
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
		if Game.can_craft(str(it.id)):
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
			if id == null or not Game.can_upgrade(str(id)):
				continue
			var c := Stats.upgrade_cost(Db.item(str(id)), Game.upgrade_level(str(id)))
			if slot == "weapon" or int(c.gold) < best_gold:
				best = str(id)
				best_gold = int(c.gold)
				if slot == "weapon":
					break
		if best != "":
			note_cost(Stats.upgrade_cost(Db.item(best), Game.upgrade_level(best)))
			worked = Game.upgrade(best)
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
	return out

func worn() -> String:
	var bits: Array = []
	for slot: String in ["weapon", "shield", "helm", "chest", "shoulders", "gauntlets", "legs", "boots"]:
		var id = Game.profile.equipped.get(slot)
		if id != null:
			bits.append("%s+%d" % [str(id).trim_prefix("a_").trim_prefix("w_").trim_prefix("s_"), Game.upgrade_level(str(id))])
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
	trial.call("Gravekeeper x6 (medium)", build(all.call("vigil"), "w_censer_sword", "s_reliquary", 12), "gravewarden")
	trial.call("Frostwarden x6 (heavy)", build(all.call("frost"), "w_censer_sword", "s_reliquary", 12), "gravewarden")
	trial.call("Dragonforged x6 (heavy)", build(all.call("wyrm"), "w_censer_sword", "s_reliquary", 12), "gravewarden")
	trial.call("3 Gravekeeper + 3 Frostwarden", build(mix.call("vigil", "frost"), "w_censer_sword", "s_reliquary", 12), "gravewarden")
	trial.call("2 Frost + 2 Wyrm + 2 Gravekeeper", build({"helm": "frost", "chest": "wyrm", "shoulders": "vigil", "gauntlets": "frost", "legs": "wyrm", "boots": "vigil"}, "w_censer_sword", "s_reliquary", 12), "gravewarden")
	print(" Relic, against the Forgotten Monarch")
	trial.call("Sovereign x6 (medium)", build(all.call("regal"), "w_frost_great", null, 18), "forgotten_monarch")
	trial.call("Architect x6 (light)", build(all.call("hollow"), "w_frost_great", null, 18), "forgotten_monarch")
	trial.call("3 Sovereign + 3 Architect", build(mix.call("regal", "hollow"), "w_frost_great", null, 18), "forgotten_monarch")
