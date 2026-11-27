extends Node
## Equipment and progression rules:  godot --headless --path . res://tests/equipment.tscn
## Data integrity, save migration, previews, rewards, the economy's guards, and that every number shown reaches the duel.
var passed := 0
var failed := 0

func ok(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", what)

func _ready() -> void:
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_equipment_test"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	wipe()
	for t: String in ["t_data", "t_sources", "t_totals", "t_migration", "t_preview", "t_equip", "t_compare", "t_stats_reach_the_duel", "t_items_reach_the_duel",
			"t_weight_sets_requirements", "t_basic_swords", "t_shields", "t_mods", "t_shop", "t_rewards", "t_guards", "t_discovery", "t_cosmetics", "t_mastery", "t_loop"]:
		print("• ", t)
		call(t)
	wipe()
	print("\n%d passed, %d failed" % [passed, failed])
	print("equipment: %s" % ("PASS" if failed == 0 else "%d FAILED" % failed))
	get_tree().quit(1 if failed > 0 else 0)

func wipe() -> void:
	for n: int in [1, 2, 3]:
		for ext: String in ["json", "bak", "tmp"]:
			if FileAccess.file_exists(Game.slot_file(n, ext)):
				DirAccess.remove_absolute(Game.slot_file(n, ext))
	Game.slot = 1

func fresh(seed_value: int = 4242) -> void:
	wipe()
	Game.new_game("#123456")
	Game.profile.rewards.seed = seed_value

func snap() -> String:
	return JSON.stringify(Game.profile)

## A knight strong enough that no requirement interferes, in plain gear.
func strong() -> Dictionary:
	var p := Game.default_profile()
	for k: String in ["health", "strength", "dex", "endurance"]:
		p.attrs[k] = 16
	p.equipped.weapon = "w_knight_sword"
	p.equipped.shield = "s_garrison"
	return p

## What a fixed stretch of one seeded fight leaves behind. Two different sets of numbers give two different prints.
func print_of(st: Dictionary, foe: String, style: int, seconds: float = 40.0, sd: int = 5) -> String:
	var s := DuelSim.new()
	s.setup(st, Db.foes[foe], sd, {"combos": Db.combos})
	var bot := DuelBot.new(s, style, sd)
	for i: int in int(seconds * 60.0):
		bot.tick(1.0 / 60.0)
		s.tick(1.0 / 60.0)
		if s.over:
			break
	return "%.3f|%.3f|%.3f|%.2f|%d" % [s.pl.hp, s.pl.stamina, s.b_hp, s.time, int(s.stats.hits_taken)]

const SCENES := [["frostbound_king", DuelBot.Style.SLOPPY], ["cinder_wyrm", DuelBot.Style.TURTLE], ["hollow_executioner", DuelBot.Style.SPAM], ["crimson_widow", DuelBot.Style.SKILLED]]

func differs(a: Dictionary, b: Dictionary) -> bool:
	for sc: Array in SCENES:
		if print_of(a, sc[0], sc[1]) != print_of(b, sc[0], sc[1]):
			return true
	return false

# ------------------------------------------------------------------ data
func t_data() -> void:
	var eq: Dictionary = Db.equipment
	ok(Db.EQUIP_SLOTS == ["weapon", "offhand", "shield", "helm", "chest", "shoulders", "gauntlets", "legs", "boots", "ring", "relic"], "eleven slots")
	ok(eq.slots == Db.EQUIP_SLOTS and eq.armour_slots == Db.ARMOUR_SLOTS, "the data and the code agree on the slots")
	for s: String in Db.EQUIP_SLOTS:
		ok(Db.SLOT_NAME.has(s), "slot %s has a name" % s)
	ok(Db.families.size() == 8, "eight armour families")
	for want: String in ["Crownless", "Ashbound", "Frostwarden", "Widow", "Gravekeeper", "Sovereign", "Dragonforged", "Architect"]:
		ok(Db.families.values().any(func(f): return f.name == want), "family %s" % want)
	var tiers := {}
	for it: Dictionary in Db.item_list:
		var id: String = it.id
		ok(Db.EQUIP_SLOTS.has(it.slot), "%s has a known slot" % id)
		ok(["common", "uncommon", "rare", "legendary", "relic"].has(Db.tier(it)), "%s has one of the five ranks" % id)
		ok(Db.tier(it) == str(eq.tiers[it.rarity]), "%s rank follows its stored rarity" % id)
		tiers[Db.tier(it)] = true
		ok(Db.families.has(it.get("family", "")), "%s belongs to a family" % id)
		ok(str(it.get("hint", "")).length() > 8, "%s has a hint" % id)
		ok(str(it.get("desc", "")) != "" and str(it.name) != "", "%s has a name and a description" % id)
		ok(it.has("mastery") and int(it.mastery.need) == Stats.mastery_needed(it) and not it.mastery.marks.is_empty(), "%s has a mastery track" % id)
		ok(it.has("advanced") and int(it.get("sell", 0)) > 0, "%s has its Recall flag and a sell value" % id)
		ok(["suit", "model", "alias", "none"].has(it.get("visual", "")), "%s says what of it is drawn" % id)
		if Db.ARMOUR_SLOTS.has(it.slot):
			ok(["light", "medium", "heavy"].has(it.get("weight", "")) and it.weight == Db.family(it).weight, "%s has its family's weight" % id)
			ok(it.has("part") and it.has("part_slot"), "%s records its suit part" % id)
			ok((it.visual == "suit") == (it.slot == "chest"), "%s: only a chest claims the suit as its look" % id)
		if it.visual == "suit":
			ok(ResourceLoader.exists("res://assets/models/%s.glb" % str(it.model).replace("{body}", "m")), "%s suit model exists" % id)
		if it.visual == "model" or it.visual == "alias":
			ok(ResourceLoader.exists("res://assets/models/%s.glb" % str(it.model)), "%s model exists" % id)
		if it.slot == "shield":
			ok(["heater", "round", "kite", "curved", "segmented"].has(it.get("shield_class", "")) and it.has("weight"), "%s has a shield class and weight" % id)
		if it.has("upgrade"):
			var prev := -1
			var good: bool = int(it.upgrade.max) == Stats.MAX_UPGRADE and it.upgrade.costs.size() == Stats.MAX_UPGRADE
			for n: int in Stats.MAX_UPGRADE:
				var c := Stats.upgrade_cost(it, n)
				good = good and int(c.gold) > prev and int(c.gold) > 0 and int(c.shards) > 0
				for m: String in c.materials:
					good = good and Db.materials.has(m) and int(c.materials[m]) > 0
				prev = int(c.gold)
			ok(good, "%s upgrade costs rise and never reach zero" % id)
			ok(Stats.item_power(it, 1) > Stats.item_power(it, 0), "%s grows when upgraded" % id)
		else:
			ok(it.slot == "ring" or it.slot == "relic", "%s: only rings and relics have no upgrade track" % id)
		if int(it.price) > 0:
			ok(int(it.sell) < int(it.price), "%s sells for less than it costs" % id)
	ok(tiers.size() == 5, "all five ranks are used")
	# every family has a full six-slot harness
	for fam: String in Db.families:
		for suit: String in Db.families[fam].suits:
			for s: String in Db.ARMOUR_SLOTS:
				var it: Dictionary = Db.item("a_%s_%s" % [suit, s])
				ok(not it.is_empty() and it.family == fam and it.slot == s, "%s has %s of %s" % [fam, s, suit])
		ok(Db.families[fam].set.size() == 3 and int(Db.families[fam].set[0].pieces) == 2 and int(Db.families[fam].set[2].pieces) == 6, "%s has 2/4/6 bonuses" % fam)
	# the brief's named swords
	for sword: String in ["Wayfarer", "Silver Vow", "Ashbrand", "King's Remnant", "Cold Resolve", "Nightward", "Oathbreaker", "Veilcutter", "Twin Relics", "Eternal Edge"]:
		var n: Dictionary = eq.named.get(sword, {})
		ok(Db.items.has(n.get("id", "")) and str(Db.item(n.id).name).begins_with(sword), "%s is an item (%s)" % [sword, n.get("id", "?")])
	ok(Db.item("w_oath_axe").cls == "greatsword", "Oathbreaker is a greatsword under its old id")
	for alias: String in Db.aliases:
		ok(Db.items.has(Db.aliases[alias]) and Db.item(alias) == Db.item(Db.aliases[alias]), "alias %s resolves" % alias)
	var weapons := 0
	for it: Dictionary in Db.item_list:
		weapons += 1 if it.slot == "weapon" else 0
	# 22 blades to be found, and the one the Kept gives back (The Second's Edge: a copy of a blade already carried)
	ok(weapons >= 12 and weapons <= 23 and Db.items.has("w_seconds_edge"), "a collection of blades (%d)" % weapons)
	for m: String in Db.materials:
		for r: String in Db.materials[m].regions:
			ok(Db.region_by_id.has(r), "material %s region %s" % [m, r])
	for r: Dictionary in Db.regions:
		ok(Db.materials.has(eq.region_material.get(r.id, "")), "region %s has a material" % r.id)

# ------------------------------------------------------------------ every acquisition source is a real thing
func t_sources() -> void:
	var eq: Dictionary = Db.equipment
	var start: Array = Game.default_profile().inventory
	for it: Dictionary in Db.item_list:
		ok(not it.get("sources", []).is_empty() and it.source == it.sources[0], "%s has a source" % it.id)
		for s: Dictionary in it.get("sources", []):
			var good := false
			match str(s.type):
				"start":
					good = start.has(it.id) or (s.get("choice", false) and eq.basic_swords.has(it.id))
				"boss":
					var b: Dictionary = eq.boss_rewards.get(s.id, {})
					good = Db.foes.has(s.id) and Db.foes[s.id].boss and (b.first.has(it.id) or b.pool.any(func(e): return e[0] == it.id))
				"encounter":
					good = Db.foes.has(s.id) and not Db.foes[s.id].boss and eq.encounters.get(s.id, "") == it.id
				"region":
					var st: Dictionary = Db.region_by_id[s.id].stages[int(s.stage)]
					good = st.options.any(func(o): return o.get("items", []).has(it.id) and o.label == s.label)
				"quest":
					good = Db.quest_by_id.has(s.id) and Db.quest_by_id[s.id].reward.get("item", "") == it.id
				"craft":
					good = it.has("craft")
					for m: String in it.get("craft", {}).get("materials", {}):
						good = good and Db.materials.has(m)
				"challenge":
					good = Db.challenges.has(s.id) and Db.challenges[s.id].reward.get("item", "") == it.id
				"shop":
					good = int(it.price) > 0 and it.has("unlock") and (not it.unlock.has("boss") or (Db.foes.has(it.unlock.boss) and Db.foes[it.unlock.boss].boss))
				"ng":
					good = int(it.get("ng_min", 0)) >= 1
				"story":
					# given at one authored moment and by nothing else (the Kept's blade, src/cine/kept_scene.gd)
					good = str(s.id) == str(Generations.data().echo.id) and it.sources.size() == 1 and int(it.price) == 0 and bool(it.get("unsellable", false))
			ok(good, "%s source %s %s is real" % [it.id, s.type, s.get("id", "")])
	# foes that carry something can be met on a road
	var placed := {}
	for r: Dictionary in Db.regions:
		for st: Dictionary in r.stages:
			for o: Dictionary in st.options:
				if o.has("foe"):
					placed[o.foe] = true
				for f in o.get("foes", []):
					placed[f] = true
	for foe: String in eq.encounters:
		ok(placed.has(foe) and Db.items.has(eq.encounters[foe]), "encounter %s is on a road" % foe)
	var firsts := {}
	for b: String in eq.boss_rewards:
		ok(placed.has(b), "guardian %s is on a road" % b)
		for id: String in eq.boss_rewards[b].first:
			ok(Db.items.has(id) and not firsts.has(id), "%s is one guardian's guaranteed reward" % id)
			firsts[id] = b
		for e: Array in eq.boss_rewards[b].pool:
			ok(Db.items.has(e[0]) and float(e[1]) > 0.0 and float(e[1]) < 1.0, "%s pool entry %s" % [b, e[0]])
	for b: String in Db.foes:
		if Db.foes[b].boss:
			ok(eq.boss_rewards.has(b) and int(eq.boss_rewards[b].materials.get("m_core", 0)) == 1, "guardian %s always gives its core" % b)
	for r: String in eq.drops:
		for id: String in eq.drops[r]:
			ok(Db.items.has(id) and int(Db.item(id).price) > 0 and not firsts.has(id), "%s drop %s is ordinary stock" % [r, id])

# ------------------------------------------------------------------ six pieces stay close to what four gave
func t_totals() -> void:
	for suit: String in Db.equipment.suit_family:
		var old := 0.0
		var now := 0.0
		for s: String in Db.ARMOUR_SLOTS:
			var d: float = float(Db.item("a_%s_%s" % [suit, s]).get("defense", 0))
			now += d
			if s in ["helm", "chest", "gauntlets", "legs"]:
				old += d
		ok(now > old and now <= old * 1.2, "%s: six pieces give %.0f defence where four gave %.0f" % [suit, now, old])
	# the knight still starts with exactly what it started with
	var p := Game.default_profile()
	ok(p.equipped.shoulders == null and p.equipped.boots == null and p.equipped.offhand == null and p.inventory.size() == 6, "the starting knight is unchanged")
	var st := Stats.compute(p, Db.items, Db.classes)
	ok(is_equal_approx(st.max_hp, 160.0) and is_equal_approx(st.max_stamina, 130.0) and is_equal_approx(st.stamina_regen, 30.0) and is_equal_approx(st.swing_cost, 11.0)
		and is_equal_approx(st.defense, 21.0) and is_equal_approx(st.block_eff, 0.0), "and has the numbers it always had")

# ------------------------------------------------------------------ migration
func fixture(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/%s.json" % name))

func t_migration() -> void:
	for name: String in ["save_v0", "save_v1_early", "save_v1"]:
		var old := fixture(name)
		var m := Game._migrate(fixture(name))
		ok(int(m.version) == Game.SAVE_VERSION, "%s: brought to the current version" % name)
		ok(m.gold == int(old.gold) and m.level == int(old.level) and m.shards == int(old.shards) and m.xp == int(old.xp), "%s: gold, level, shards, experience survive" % name)
		for k: String in old.attrs:
			ok(m.attrs[k] == int(old.attrs[k]), "%s: attribute %s survives" % [name, k])
		for id in old.inventory:
			ok(m.inventory.has(id), "%s: still owns %s" % [name, id])
		ok(m.inventory.slice(0, old.inventory.size()) == old.inventory, "%s: in the order it was acquired" % name)
		for id: String in old.get("upgrades", {}):
			ok(m.upgrades.get(id, -1) == int(old.upgrades[id]) and typeof(m.upgrades[id]) == TYPE_INT, "%s: upgrade of %s survives" % [name, id])
		for id: String in old.get("mastery", {}):
			ok(m.mastery.get(id, -1) == int(old.mastery[id]), "%s: mastery of %s survives" % [name, id])
		for id in old.get("mastered", []):
			ok(m.mastered.has(id), "%s: %s still mastered" % [name, id])
		for id in old.get("favourites", []):
			ok(m.favourites.has(id), "%s: %s still a favourite" % [name, id])
		for k: String in old.get("flags", {}):
			ok(m.flags.get(k) == old.flags[k], "%s: story flag %s survives" % [name, k])
		for k: String in old.get("defeated", {}):
			ok(m.defeated.get(k, -1) == int(old.defeated[k]), "%s: the count of %s survives" % [name, k])
		for k: String in ["cleared", "endings", "combos", "lore", "quests_done", "heard"]:
			if old.has(k):
				ok(m[k] == old[k], "%s: %s survives" % [name, k])
		for slot: String in old.equipped:
			if slot == "shield" and name == "save_v1":
				continue
			ok(m.equipped[slot] == old.equipped[slot], "%s: %s still equipped" % [name, slot])
		for slot: String in Db.EQUIP_SLOTS:
			ok(m.equipped.has(slot), "%s: has the %s slot" % [name, slot])
		for id in old.inventory:
			ok(m.discovered.has(id) and m.seen.has(id), "%s: %s counts as discovered and seen" % [name, id])
		# idempotent, and stable through the file format
		var once := JSON.stringify(m)
		ok(JSON.stringify(Game._migrate(m.duplicate(true))) == once, "%s: migrating again changes nothing" % name)
		var packed := Game._pack(m)
		ok(packed.has("items") and not packed.has("inventory") and not packed.has("upgrades") and packed.has("equipped") and packed.has("materials") and packed.has("cosmetics"),
			"%s: on disk, one record per item apart from the definitions" % name)
		for id in m.inventory:
			var r: Dictionary = packed.items[id]
			ok(r.owned and r.discovered and r.seen and int(r.level) == int(m.upgrades.get(id, 0)) and int(r.mastery_xp) == int(m.mastery.get(id, 0))
				and r.favourite == m.favourites.has(id) and r.mastered == m.mastered.has(id), "%s: record of %s" % [name, id])
		var back := Game._migrate(JSON.parse_string(JSON.stringify(packed)))
		ok(JSON.stringify(back) == once, "%s: written and read back, it is identical" % name)
		ok(Stats.compute(m, Db.items, Db.classes).max_hp > 0.0, "%s: the migrated knight computes" % name)
	# the richest fixture, in detail
	var v := Game._migrate(fixture("save_v1"))
	ok(v.inventory.has("w_future_blade") and v.upgrades["w_future_blade"] == 2 and v.mastery["w_future_blade"] == 3 and v.favourites.has("w_future_blade"),
		"an id this version does not know keeps its place, level, mastery and star")
	ok(v.defeated["future_foe"] == 2 and v.some_future_field.kept == true, "unknown foes and unknown fields are kept")
	ok(v.equipped.weapon == "w_oath_axe" and v.equipped.shield == null and v.inventory.has("s_rime") and v.upgrades["s_rime"] == 2,
		"Oathbreaker now needs both hands: the shield comes off the arm and stays in the pack, level and all")
	ok(v.materials.get("m_core", 0) == 7 and v.rewards.cores.size() == 7, "one guardian core for each guardian already ended (%s)" % str(v.materials))
	ok(v.rewards.seed != 0 and v.mastery_taught["w_monarch"] == "rising_fang" and v.name == "Aldous" and is_equal_approx(v.playtime, 86400.25), "the rest of the journey is as it was")
	# from the files themselves: load, save, load
	for name: String in ["save_v0", "save_v1_early", "save_v1"]:
		wipe()
		var f := FileAccess.open(Game.slot_file(1), FileAccess.WRITE)
		f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/%s.json" % name))
		f.close()
		var old := fixture(name)
		ok(Game.load_game() and Game.profile.gold == int(old.gold) and Game.profile.inventory.size() >= old.inventory.size(), "%s loads from disk" % name)
		ok(not Game.slot_summary(1).is_empty() and int(Game.slot_summary(1).level) == int(old.level), "%s shows in the slot list" % name)
		var mem := snap()
		ok(Game.save(), "%s saves in the new shape" % name)
		var on_disk = JSON.parse_string(FileAccess.get_file_as_string(Game.slot_file(1)))
		ok(on_disk is Dictionary and int(on_disk.version) == Game.SAVE_VERSION and on_disk.has("items") and on_disk.has("equipped"), "%s: the file is the current version" % name)
		Game.profile = {}
		ok(Game.load_game(), "%s loads again" % name)
		var a: Dictionary = JSON.parse_string(mem)
		var b: Dictionary = JSON.parse_string(snap())
		a.erase("last_played"); b.erase("last_played"); a.erase("playtime"); b.erase("playtime")
		ok(JSON.stringify(a) == JSON.stringify(b), "%s: identical after a save and a load" % name)
	# ids that were renamed
	var al := Game.default_profile()
	al.version = 1
	al.inventory.append("w_eternal_edge")
	al.upgrades["w_eternal_edge"] = 3
	al.equipped.weapon = "w_eternal_edge"
	al = Game._migrate(al)
	ok(al.inventory.has("w_monarch") and not al.inventory.has("w_eternal_edge") and al.upgrades["w_monarch"] == 3 and al.equipped.weapon == "w_monarch", "an alternative id in a save resolves to the stored one")
	fresh()

# ------------------------------------------------------------------ previews never change anything
func t_preview() -> void:
	fresh()
	for id: String in ["w_knight_sword", "w_ashen_great", "s_tower", "a_ash_chest", "a_black_helm", "a_garrison_shoulders", "a_black_boots", "r_ember", "x_candle"]:
		Game.grant_item(id)
	Game.profile.gold = 3000
	Game.save()
	var before := snap()
	var bytes := FileAccess.get_file_as_bytes(Game.slot_file(1))
	for it: Dictionary in Db.item_list:
		var p := Game.preview_profile(it.slot, it.id)
		ok(p.equipped[it.slot] == it.id, "preview of %s wears it" % it.id)
		var changed: Array = []
		for s: String in p.equipped:
			if p.equipped[s] != Game.profile.equipped[s]:
				changed.append(s)
		var two: bool = it.slot == "weapon" and Db.classes[it.cls].two_handed
		ok(changed == [it.slot] or changed.is_empty() or (two and changed.size() == 2 and changed.has("shield")), "preview of %s changes its own slot only (%s)" % [it.id, str(changed)])
		Game.preview_stats(it.slot, it.id)
		Game.compare(it.slot, it.id)
		Game.compare(it.id)
		Game.item_state(it.id)
		Game.upgrade_preview(it.id)
		Game.upgrade_block(it.id)
		Game.craft_block(it.id)
		Game.sell_block(it.id)
		Game.buy_price(it.id)
		Game.item_record(it.id)
		Game.is_new(it.id)
		Game.requirement_text(it.id)
	for s: String in Db.EQUIP_SLOTS:
		Game.items_for_slot(s, true)
		Game.items_for_slot(s)
		Game.cosmetic(s)
		Game.appearance(s)
	Game.set_status()
	Game.shop_stock()
	Game.craft_stock()
	Game.materials_list()
	Game.appearance_loadout()
	Rewards.roll(Game.profile, "ashen_sentinel")
	ok(snap() == before, "previews, comparisons and queries leave the profile untouched")
	ok(FileAccess.get_file_as_bytes(Game.slot_file(1)) == bytes, "and the save file byte-identical")
	ok(Game.preview_profile("helm", "w_knight_sword").equipped == Game.profile.equipped, "an item cannot be previewed in a slot it does not belong to")
	var p := Game.preview_profile("weapon", "w_monarch")
	ok(not Game.owns("w_monarch") and p.equipped.weapon == "w_monarch" and not p.inventory.has("w_monarch"), "a locked item can be previewed without being given")

# ------------------------------------------------------------------ equip changes exactly one slot
func t_equip() -> void:
	fresh()
	for it: Dictionary in Db.item_list:
		Game.grant_item(it.id)
	for it: Dictionary in Db.item_list:
		Game.equip("w_rusted_sword")
		Game.equip("s_plank")
		var before: Dictionary = Game.profile.equipped.duplicate()
		var inv: Array = Game.profile.inventory.duplicate()
		ok(Game.equip(it.id), "%s can be put on" % it.id)
		var changed: Array = []
		for s: String in before:
			if before[s] != Game.profile.equipped[s]:
				changed.append(s)
		if it.slot == "weapon" and Db.classes[it.cls].two_handed:
			ok(changed.size() == 2 and changed.has("weapon") and changed.has("shield") and Game.profile.equipped.shield == null, "%s takes both hands" % it.id)
		elif before[it.slot] == it.id:
			ok(changed.is_empty(), "%s was already on" % it.id)
		else:
			ok(changed == [it.slot], "%s changed exactly one slot (%s)" % [it.id, str(changed)])
		ok(Game.profile.inventory == inv, "%s: the pack is as it was" % it.id)
	ok(not Game.equip("w_nothing") and not Game.equip(""), "what does not exist cannot be put on")
	fresh()
	ok(not Game.equip("w_monarch"), "what is not owned cannot be put on")
	Game.profile.inventory.append("w_future_blade")
	var eq := snap()
	ok(not Game.equip("w_future_blade") and snap() == eq, "an unknown id is kept but cannot be put on")
	ok(Game.sell_block("w_future_blade") == "Unknown" and not Game.sell("w_future_blade") and Game.sorted_items().size() == 6, "nor sold, and it does not break the lists")
	ok(Game.owns("w_rusted_sword") and Game.owns("w_wayfarer") and Game.is_equipped("w_wayfarer"), "an alternative id answers for the same item")

# ------------------------------------------------------------------ comparison
func t_compare() -> void:
	fresh()
	for id: String in ["w_ashen_great", "a_ash_chest", "a_black_chest", "s_tower", "a_garrison_boots"]:
		Game.grant_item(id)
	Game.profile.attrs.strength = 12
	Game.profile.attrs.endurance = 12
	var rows := Game.compare("weapon", "w_ashen_great")
	var by := {}
	for r: Dictionary in rows:
		by[r.key] = r
	for k: String in ["attack", "defense", "max_hp", "max_stamina", "stamina_regen", "swing_time", "swing_cost", "crit_mult", "block_eff", "resist", "element"]:
		ok(by.has(k), "comparison has a row for %s" % k)
	ok(by.attack.delta > 0.0 and by.attack.better == 1, "more damage is better")
	ok(by.swing_time.delta > 0.0 and by.swing_time.better == -1, "a longer swing is worse, though the number rises")
	ok(by.swing_cost.delta > 0.0 and by.swing_cost.better == -1, "a dearer swing is worse")
	ok(by.block_eff.delta < 0.0 and by.block_eff.better == -1, "losing the shield is worse")
	ok(by.element.then_text == "Fire", "the element is named")
	var now := Game.stats()
	var then := Game.preview_stats("weapon", "w_ashen_great")
	for r: Dictionary in rows:
		if r.key != "element":
			var k: float = 100.0 if r.key == "block_eff" else 1.0
			ok(is_equal_approx(r.now, float(now[r.key]) * k) and is_equal_approx(r.then, float(then[r.key]) * k) and is_equal_approx(r.delta, r.then - r.now), "row %s is the equipped figure against the previewed one" % r.key)
	ok(Game.compare("helm", "w_ashen_great").is_empty(), "comparing in the wrong slot gives nothing")
	ok(JSON.stringify(Game.compare("w_ashen_great")) == JSON.stringify(rows), "the one-argument form is the same comparison")
	# lower-is-better the other way round: light armour makes swings cheaper, and that is marked better
	Game.profile.equipped.chest = "a_ash_chest"
	var light := {}
	for r: Dictionary in Game.compare("chest", "a_black_chest"):
		light[r.key] = r
	ok(light.swing_cost.delta < 0.0 and light.swing_cost.better == 1, "a cheaper swing is better, though the number falls")
	ok(light.stamina_regen.delta > 0.0 and light.stamina_regen.better == 1 and light.resist.better == -1, "light for heavy: faster recovery, less resistance")
	for r: Dictionary in Game.compare("chest", "a_ash_chest"):
		ok(r.better == 0 and is_zero_approx(r.delta), "comparing the equipped item with itself shows no change (%s)" % r.key)

# ------------------------------------------------------------------ every number shown is read by the duel
func t_stats_reach_the_duel() -> void:
	var base := Stats.compute(strong(), Db.items, Db.classes)
	var bumps := {"attack": 1.3, "max_hp": 1.3, "max_stamina": 1.4, "stamina_regen": 1.5, "swing_time": 1.4, "swing_cost": 1.6, "crit_mult": 1.4,
		"guard_dmg": 2.0}
	for key: String in bumps:
		var st: Dictionary = base.duplicate(true)
		st[key] = float(st[key]) * float(bumps[key])
		ok(differs(base, st), "the duel reads %s" % key)
	for pair: Array in [["mitigation", 0.25], ["block_eff", 0.35], ["resist", 60.0], ["shield_blocks", -3.0]]:
		var st: Dictionary = base.duplicate(true)
		st[pair[0]] = float(st[pair[0]]) + float(pair[1])
		ok(differs(base, st), "the duel reads %s" % pair[0])
	var el: Dictionary = base.duplicate(true)
	el["element"] = "fire"
	ok(print_of(base, "frostbound_king", DuelBot.Style.SKILLED) != print_of(el, "frostbound_king", DuelBot.Style.SKILLED) or differs(base, el), "the duel reads the element")
	# defence is shown; the duel reads the mitigation made from it
	var p := strong()
	var lo := Stats.compute(p, Db.items, Db.classes)
	p.attrs.defense += 6
	var hi := Stats.compute(p, Db.items, Db.classes)
	ok(hi.defense > lo.defense and hi.mitigation > lo.mitigation and differs(lo, hi), "defence becomes mitigation, and the duel reads it")
	# every row of the comparison is one of the keys proven above
	for r: Array in Game.COMPARE_ROWS:
		ok(bumps.has(r[1]) or r[1] in ["defense", "dodge_cost", "block_eff", "resist", "shield_blocks", "footwork"], "comparison row %s is a number the duel reads" % r[1])
	ok(is_equal_approx(base.footwork, 100.0 / base.dodge_cost), "footwork is the dodge cost, turned so that more is better")
	# and the keys that are only for the screens change nothing
	var extra: Dictionary = base.duplicate(true)
	extra["burden"] = "heavy"
	extra["sets"] = [{"family": "x"}]
	ok(not differs(base, extra), "the descriptive keys are not read by the duel")

func t_items_reach_the_duel() -> void:
	var base_p := strong()
	var base := Stats.compute(base_p, Db.items, Db.classes)
	for it: Dictionary in Db.item_list:
		if base_p.equipped.get(it.slot) == it.id:
			continue
		var p := base_p.duplicate(true)
		p.equipped[it.slot] = it.id
		if it.slot == "weapon" and Db.classes[it.cls].two_handed:
			p.equipped.shield = null
		var st := Stats.compute(p, Db.items, Db.classes)
		ok(differs(base, st), "wearing %s changes a fight" % it.id)
		if it.has("upgrade"):
			var up := p.duplicate(true)
			up.upgrades[it.id] = 3
			ok(differs(st, Stats.compute(up, Db.items, Db.classes)), "upgrading %s changes a fight" % it.id)
	# the lines an item shows are all made of those numbers
	var known := ["Damage", "Swing", "Stamina", "Element", "Defense", "Health", "Strength", "Dexterity", "Critical", "Resistance", "Guard", "Weight", "Guard damage", "Blocks", "Footwork"]
	for it: Dictionary in Db.item_list:
		for line: Array in Stats.item_lines(it, 0, Db.classes):
			ok(known.has(line[0]), "%s shows %s" % [it.id, line[0]])

# ------------------------------------------------------------------ weight, sets, requirements
func suit(p: Dictionary, s: String, slots: Array = Db.ARMOUR_SLOTS) -> Dictionary:
	for slot: String in slots:
		p.equipped[slot] = "a_%s_%s" % [s, slot]
	return p

func t_weight_sets_requirements() -> void:
	var light := Stats.compute(suit(strong(), "black"), Db.items, Db.classes)
	var medium := Stats.compute(suit(strong(), "vigil"), Db.items, Db.classes)
	var heavy := Stats.compute(suit(strong(), "ash"), Db.items, Db.classes)
	ok(light.stamina_regen > medium.stamina_regen and medium.stamina_regen > heavy.stamina_regen, "light recovers stamina fastest, heavy slowest")
	ok(light.swing_cost < medium.swing_cost and medium.swing_cost < heavy.swing_cost, "light swings cheapest, heavy dearest")
	ok(heavy.block_eff > medium.block_eff and heavy.resist > light.resist, "heavy guards and resists best")
	ok(light.burden == "light" and medium.burden == "medium" and heavy.burden == "heavy", "the overall burden is named")
	ok(Stats.compute(suit(suit(strong(), "black"), "ash", ["chest", "legs", "helm"]), Db.items, Db.classes).burden == "medium", "three light and three heavy is a medium burden")
	# set bonuses at 2, 4 and 6, and not from the starting plate
	var none := Stats.compute(strong(), Db.items, Db.classes)
	ok(none.sets.is_empty() or none.sets[0].active.is_empty(), "the starting plate counts towards no set")
	var prev := 0
	for n: int in [1, 2, 3, 4, 5, 6]:
		var st := Stats.compute(suit(strong(), "garrison", Db.ARMOUR_SLOTS.slice(0, n)), Db.items, Db.classes)
		var active: int = 0
		for s: Dictionary in st.sets:
			if s.family == "crownless":
				active = s.active.size()
		ok(active == [0, 0, 1, 1, 2, 2, 3][n], "%d Crownless pieces: %d bonuses" % [n, active])
		ok(active >= prev, "bonuses only accumulate")
		prev = active
	var four := Stats.compute(suit(strong(), "garrison", ["helm", "chest", "gauntlets", "legs"]), Db.items, Db.classes)
	var raw := 0.0
	for s: String in ["helm", "chest", "gauntlets", "legs"]:
		raw += float(Db.item("a_garrison_" + s).get("hp", 0))
	ok(is_equal_approx(four.max_hp, 100.0 + 12.0 * 16.0 + raw + 12.0) and is_equal_approx(four.max_stamina, 100.0 + 96.0 + 4.0 + 6.0), "four Crownless pieces: +6 stamina and +12 health, exactly")
	for fam: String in Db.families:
		var s: String = Db.families[fam].suits[-1]
		var full := Stats.compute(suit(strong(), s), Db.items, Db.classes)
		ok(full.sets.size() == 1 and full.sets[0].active.size() == 3, "six %s pieces give all three bonuses" % fam)
		var p := suit(strong(), s)
		p.equipped.boots = null
		ok(differs(full, Stats.compute(p, Db.items, Db.classes)), "the %s six-piece bonus changes a fight" % fam)
	Game.profile = suit(strong(), "garrison")
	ok(Game.set_status().size() == 1 and Game.set_status()[0].name == "Crownless" and Game.set_status()[0].tiers.all(func(t): return t.active), "the set status lists what is active")
	# mixing stays close to a full set: no build is more than a fifth ahead in what it can take or deal
	var builds := [suit(strong(), "black"), suit(strong(), "ash"), suit(suit(strong(), "black"), "ash", ["chest", "legs", "helm"]), suit(suit(strong(), "ash"), "black", ["chest", "legs", "helm"])]
	var lo := 1.0e9
	var hi := 0.0
	for b: Dictionary in builds:
		var st := Stats.compute(b, Db.items, Db.classes)
		var worth: float = st.max_hp / (1.0 - st.mitigation) * (st.stamina_regen / st.swing_cost)
		lo = minf(lo, worth)
		hi = maxf(hi, worth)
		ok(print_of(st, "hollow_executioner", DuelBot.Style.SKILLED, 300.0).split("|")[2].to_float() <= 0.0, "a %s build beats the Executioner" % st.burden)
	ok(hi / lo < 1.45, "full sets and mixed builds sit in one band (%.2f)" % (hi / lo))
	# requirements: never a refusal, always a cost
	fresh()
	Game.grant_item("w_ashen_great")
	ok(not Game.meets_requirements("w_ashen_great") and Game.requirement_text("w_ashen_great") == "Strength 9", "an unmet requirement is stated")
	ok(Game.equip("w_ashen_great"), "the weapon can still be carried")
	var weak := Game.stats()
	ok(weak.unmet == ["w_ashen_great"], "and is listed as beyond the knight")
	Game.profile.attrs.strength = 9
	var able := Game.stats()
	ok(Game.meets_requirements("w_ashen_great") and able.unmet.is_empty() and able.swing_cost < weak.swing_cost, "meeting it lifts the penalty on the swing")
	Game.profile.attrs.strength = 5
	var same_scale := Game.stats()
	Game.profile.attrs.strength = 9
	ok(is_equal_approx(weak.swing_cost, able.swing_cost * 1.2) and same_scale.attack < able.attack, "an unmet weapon costs a fifth more to swing and hits less hard")

# ------------------------------------------------------------------ rewards
func t_rewards() -> void:
	# determinism: the same journey pays the same
	var logs: Array = []
	for pass_n: int in 2:
		fresh(777)
		Game.start_run("courtyard")
		var log: Array = []
		for foe: String in ["hollow_soldier", "banneret", "hollow_soldier", "rampart_brute", "ashen_sentinel", "gate_colossus", "pike_sergeant", "ashen_sentinel"]:
			log.append(JSON.stringify(Game.on_victory(foe, 50.0)))
		logs.append(log)
	ok(logs[0] == logs[1], "the same journey gives the same rewards")
	fresh(778)
	Game.start_run("courtyard")
	var other: Array = []
	for foe: String in ["hollow_soldier", "banneret", "hollow_soldier", "rampart_brute", "ashen_sentinel", "gate_colossus", "pike_sergeant", "ashen_sentinel"]:
		other.append(JSON.stringify(Game.on_victory(foe, 50.0)))
	ok(other != logs[0], "another journey rolls differently")
	# the roll is pure, and losing does not re-roll it
	fresh(31)
	Game.start_run("courtyard")
	var before := snap()
	var a := JSON.stringify(Rewards.roll(Game.profile, "ashen_sentinel"))
	ok(snap() == before and a == JSON.stringify(Rewards.roll(Game.profile, "ashen_sentinel")), "rolling changes nothing and repeats itself")
	var gold: int = Game.profile.gold
	var inv: int = Game.profile.inventory.size()
	var mats := JSON.stringify(Game.profile.materials)
	for i: int in 5:
		Game.on_death()
		Game.start_run("courtyard")
	ok(Game.profile.gold == gold and Game.profile.inventory.size() == inv and JSON.stringify(Game.profile.materials) == mats and Game.profile.xp == 0, "losing gives nothing, however often")
	ok(JSON.stringify(Rewards.roll(Game.profile, "ashen_sentinel")) == a, "and the reward that was waiting is still the one waiting")
	# the result has everything the overlay and a reveal screen read
	var r := Game.on_victory("ashen_sentinel", 50.0)
	for k: String in ["xp", "gold", "shards", "items", "levels", "mastered", "first", "items_new", "materials", "mastery_ups", "unlocks", "discoveries", "compensation", "repeat", "pity"]:
		ok(r.has(k), "the result has %s" % k)
	ok(r.first and r.items.has("s_tower") and r.items == r.items_new and Game.owns("s_tower"), "the guardian's guaranteed reward, first time")
	ok(r.shop_unlocks == ["w_ashen_great"] and not Game.owns("w_ashen_great") and Game.shop_stock().any(func(it): return it.id == "w_ashen_great"), "its blade is not dropped: Orren sells it from now on")
	ok(int(r.materials.get("m_core", 0)) == 1 and int(r.materials.get("m_iron", 0)) >= 4 and Game.material_count("m_core") == 1, "materials of its region and one core")
	ok(r.xp > 0 and r.gold > 0 and r.shards >= 3 and not r.mastery_ups.is_empty(), "experience, gold, shards and mastery")
	for u: Dictionary in r.mastery_ups:
		ok(Db.items.has(u.id) and int(u.tier) >= 1 and str(u.text) != "", "mastery mark for %s is described" % u.id)
	for id: String in r.discoveries:
		ok(Db.items.has(id) and Game.is_discovered(id), "discovery %s is real and now known" % id)
	# no duplicates, ever; later kills pay in gold and material instead
	var cores := 1
	var saw_comp := false
	for i: int in 14:
		var again := Game.on_victory("ashen_sentinel", 50.0)
		cores += int(again.materials.get("m_core", 0))
		ok(not again.first and not again.items.has("s_tower") and again.shop_unlocks.is_empty(), "kill %d does not give the bulwark again" % (i + 2))
		saw_comp = saw_comp or (int(again.compensation.get("gold", 0)) > 0 and int(again.compensation.materials.get("m_iron", 0)) > 0)
		for id: String in again.items:
			ok(Game.profile.inventory.count(id) == 1, "%s is held once" % id)
	ok(saw_comp and cores == 1, "the guaranteed place pays gold and material instead, and there is one core to a guardian")
	var uniq := {}
	for id: String in Game.profile.inventory:
		uniq[id] = true
	ok(uniq.size() == Game.profile.inventory.size(), "nothing is held twice")
	for e: Array in Db.equipment.boss_rewards.ashen_sentinel.pool:
		ok(Game.owns(e[0]), "fifteen kills empty the Sentinel's pool (%s)" % e[0])
	# already held before the first kill: compensation, not a duplicate
	fresh(5)
	Game.grant_item("x_tooth")
	var held := Game.on_victory("hollow_executioner", 50.0)
	ok(held.first and not held.items.has("x_tooth") and int(held.compensation.get("gold", 0)) > 0 and Game.profile.inventory.count("x_tooth") == 1, "a guaranteed reward already held is paid out instead")
	# an optional encounter's exclusive: once
	fresh(6)
	var enc := Game.on_victory("gate_colossus", 50.0)
	ok(enc.items.has("a_ash_shoulders"), "the Gate Colossus carries its own piece")
	ok(not Game.on_victory("gate_colossus", 50.0).items.has("a_ash_shoulders") and Game.profile.inventory.count("a_ash_shoulders") == 1, "and only one of it")
	# no farming: the same foe again and again pays less and less, down to a floor
	fresh(9)
	var pays: Array = []
	for i: int in 9:
		pays.append(int(Game.on_victory("hollow_soldier", 50.0).gold))
	var falling := true
	for i: int in range(1, pays.size()):
		falling = falling and pays[i] <= pays[i - 1]
	ok(falling and pays[0] == int(Db.foes.hollow_soldier.gold) and pays[-1] == int(Db.foes.hollow_soldier.gold * 0.4), "one foe farmed pays less each time, to a floor (%s)" % str(pays))
	for foe: String in ["banneret", "rampart_brute", "pike_sergeant", "gate_colossus", "banneret", "rampart_brute", "pike_sergeant", "gate_colossus"]:
		Game.on_victory(foe, 50.0)
	ok(int(Game.on_victory("hollow_soldier", 50.0).gold) == int(Db.foes.hollow_soldier.gold), "after other fights it pays in full again")
	# the dry-streak rule: never three wins in a row with nothing new
	fresh(12)
	var dry := 0
	var worst := 0
	var forced := 0
	for i: int in 60:
		var foe: String = ["hollow_soldier", "banneret", "pike_sergeant", "rampart_brute"][i % 4]
		var res := Game.on_victory(foe, 50.0)
		forced += 1 if res.pity else 0
		if res.items.is_empty() and res.discoveries.is_empty() and res.mastery_ups.is_empty() and int(res.levels) == 0 and res.materials.is_empty():
			dry += 1
		else:
			dry = 0
		worst = maxi(worst, dry)
		ok(Game.profile.rewards.pity < int(Db.equipment.rewards.pity), "the streak counter never passes its limit")
	ok(worst <= 2 and forced >= 1, "sixty wins: never three in a row with nothing to show (worst %d, forced %d)" % [worst, forced])
	ok(Game.profile.gold >= 0 and Game.profile.shards >= 0, "currencies are never negative")
	# New Game Plus still pays, and a guardian gives its core again
	fresh(13)
	Game.on_victory("ashen_sentinel", 50.0)
	Game.start_ng_plus(true)
	var ngr := Game.on_victory("ashen_sentinel", 50.0)
	ok(int(ngr.materials.get("m_core", 0)) == 1 and not ngr.items.has("s_tower") and int(ngr.gold) > int(Db.foes.ashen_sentinel.gold), "the next cycle pays more and gives one more core")

# ------------------------------------------------------------------ the economy's guards
func t_guards() -> void:
	fresh()
	# buying
	Game.profile.gold = 100
	ok(not Game.buy("w_knight_sword") and Game.profile.gold == 100 and not Game.owns("w_knight_sword"), "cannot buy without the gold")
	Game.profile.gold = 100000
	ok(not Game.buy("a_vigil_chest") and Game.profile.gold == 100000, "Orren does not stock that yet")
	ok(not Game.buy("w_monarch") and not Game.buy("w_nothing") and not Game.buy("a_ash_boots"), "what is not for sale cannot be bought")
	var stock: Array = Game.shop_stock().map(func(it): return it.id)
	ok(stock.has("w_knight_sword") and stock.has("a_garrison_shoulders") and stock.has("a_worn_boots") and not stock.has("a_black_chest") and not stock.has("a_vigil_chest"), "the first stock is the Courtyard's")
	Game.profile.cleared = ["courtyard"]
	stock = Game.shop_stock().map(func(it): return it.id)
	ok(stock.has("a_black_chest") and not stock.has("a_vigil_chest"), "one region on, the rare stock arrives")
	Game.profile.cleared = ["courtyard", "blackwood", "cathedral"]
	stock = Game.shop_stock().map(func(it): return it.id)
	ok(stock.has("a_vigil_chest") and stock.has("a_vigil_boots"), "three regions on, the legendary stock")
	ok(Game.buy("w_knight_sword") and Game.profile.gold == 100000 - 260 and not Game.buy("w_knight_sword"), "a purchase is paid for once")
	for it: Dictionary in Game.shop_stock():
		ok(Game.buy_price(it.id) == int(it.price) and int(it.price) > Game.sell_price(it.id), "%s sells for less than it costs" % it.id)
	# selling
	Game.profile.cleared = []
	ok(Game.sell_block("w_rusted_sword") == "Equipped", "cannot sell what is equipped")
	Game.equip("w_knight_sword")
	ok(Game.sell_block("w_rusted_sword") == "Not for sale" and not Game.sell("w_rusted_sword"), "the sword you woke with is not for sale")
	Game.grant_item("x_name")
	Game.grant_item("r_crown")
	ok(Game.sell_block("x_name") == "Keepsake" and not Game.sell("x_name") and not Game.sell("r_crown") and Game.owns("x_name"), "story keepsakes cannot be sold")
	Game.grant_item("w_headsman")
	Game.toggle_favourite("w_headsman")
	ok(Game.sell_block("w_headsman") == "Favourite" and not Game.sell("w_headsman"), "a favourite is locked")
	Game.toggle_favourite("w_headsman")
	var g: int = Game.profile.gold
	ok(Game.sell("w_headsman") and Game.profile.gold == g + Game.sell_price("w_headsman") and not Game.sell("w_headsman") and Game.profile.gold == g + Game.sell_price("w_headsman"), "sold once, paid once")
	# a one-of-a-kind item can be bought back, for more than it sold for
	stock = Game.shop_stock().map(func(it): return it.id)
	ok(stock.has("w_headsman") and Game.buy_price("w_headsman") > Game.sell_price("w_headsman"), "Orren keeps it, at a higher price")
	g = Game.profile.gold
	ok(Game.buy("w_headsman") and Game.owns("w_headsman") and Game.profile.gold == g - int(ceil(Game.sell_price("w_headsman") * 3.0)) and not Game.profile.sold.has("w_headsman"), "and sells it back")
	# the last weapon
	fresh()
	Game.profile.inventory = ["w_ashen_great"]
	Game.profile.equipped.weapon = null
	ok(Game.sell_block("w_ashen_great") == "Last weapon" and not Game.sell("w_ashen_great"), "the last weapon cannot be sold")
	# upgrading
	fresh()
	Game.profile.gold = 0
	Game.profile.shards = 50
	ok(Game.upgrade_block("w_rusted_sword") == "Not enough gold" and not Game.upgrade("w_rusted_sword") and Game.profile.gold == 0, "no gold, no upgrade, no debt")
	Game.profile.gold = 100000
	Game.profile.shards = 0
	ok(Game.upgrade_block("w_rusted_sword") == "Not enough shards" and not Game.upgrade("w_rusted_sword") and Game.profile.shards == 0, "no shards, no upgrade")
	Game.profile.shards = 500
	Game.grant_item("w_ashen_great")
	ok(Game.upgrade("w_ashen_great") and Game.upgrade("w_ashen_great"), "the first two levels ask for gold and shards")
	ok(Game.upgrade_block("w_ashen_great") == "Needs Old Iron" and not Game.upgrade("w_ashen_great") and Game.upgrade_level("w_ashen_great") == 2, "the third asks for the material of its region")
	Game.add_material("m_iron", 2)
	var need := Stats.upgrade_cost(Db.item("w_ashen_great"), 2)
	g = Game.profile.gold
	ok(Game.upgrade("w_ashen_great") and Game.material_count("m_iron") == 2 - int(need.materials.m_iron) and Game.profile.gold == g - int(need.gold), "paid in gold, shards and material, exactly")
	Game.grant_item("w_monarch")
	Game.profile.upgrades["w_monarch"] = 4
	Game.profile.mods["w_monarch"] = {"grip": 0, "ore": 2, "ore_id": "m_glass"}
	Game.add_material("m_glass", 50)
	ok(Game.upgrade_block("w_monarch") == "Needs Guardian Core" and Game.material_price("m_core") == 0 and not Game.buy_material("m_core"), "the last level of a relic asks for a core, and cores are not sold")
	Game.add_material("m_core", 1)
	ok(Game.upgrade("w_monarch") and Game.upgrade_block("w_monarch") == "Perfected" and not Game.upgrade("w_monarch") and Game.material_count("m_core") == 0, "perfected, and no further")
	Game.grant_item("r_ember")
	ok(Game.upgrade_block("r_ember") == "Cannot be worked" and not Game.upgrade("r_ember"), "a ring has nothing an upgrade would change, so none is sold")
	ok(Game.upgrade_block("w_starfall") == "Not yours" and not Game.upgrade("w_nothing"), "only what is held can be worked")
	ok(not Game.add_material("m_iron", -999) and Game.material_count("m_iron") >= 0 and not Game.add_material("shards", -99999), "materials never go below zero")
	# an upgrade changes what the duel reads
	fresh()
	Game.profile.gold = 100000
	Game.profile.shards = 500
	var pv := Game.upgrade_preview("w_rusted_sword")
	ok(pv.block == "" and pv.level == 0 and pv.rows.size() == 2 and pv.rows[0].key == "attack" and pv.rows[0].better == 1 and pv.rows[1].key == "guard_dmg" and pv.item_then > pv.item_now, "the forge can say what the next level does")
	var s0 := Game.stats()
	Game.upgrade("w_rusted_sword")
	ok(is_equal_approx(Game.stats().attack, pv.rows[0].then) and differs(s0, Game.stats()), "and the upgrade does exactly that, in the duel")
	s0 = Game.stats()
	Game.upgrade("a_worn_chest")
	Game.upgrade("s_plank")
	ok(Game.stats().defense > s0.defense and Game.stats().block_eff > s0.block_eff and differs(s0, Game.stats()), "armour and shield upgrades reach the duel too")
	# buying materials
	fresh()
	Game.profile.gold = 1000
	ok(Game.material_price("m_iron") == 0 and not Game.buy_material("m_iron"), "a region's material is not sold before the region is cleared")
	ok(Game.buy_material("shards", 2) and Game.profile.shards == 2 and Game.profile.gold == 1000 - 2 * Game.material_price("shards"), "shards can be bought")
	Game.profile.cleared = ["courtyard"]
	ok(Game.buy_material("m_iron", 3) and Game.material_count("m_iron") == 3, "and Old Iron once the Courtyard is cleared")
	ok(not Game.buy_material("m_iron", 100000) and not Game.buy_material("m_iron", 0) and not Game.buy_material("m_iron", -3) and Game.profile.gold >= 0, "never into debt, never a negative amount")
	ok(Game.shortfall_price({"gold": 0, "shards": 4, "materials": {"m_iron": 5}}) == 2 * 60 + 2 * 40, "what a cost still lacks is priced")
	ok(Game.shortfall_price({"gold": 0, "shards": 0, "materials": {"m_core": 1}}) == -1, "and a missing core cannot be bought")
	# crafting
	fresh()
	ok(Game.craft_block("w_knight_sword") == "No pattern" and not Game.craft("w_knight_sword"), "only patterns can be made")
	Game.profile.gold = 100000
	Game.profile.shards = 100
	ok(Game.craft_block("a_frost_boots") == "Unknown work" and Game.craft_stock().is_empty(), "a pattern is unknown until its region is reached")
	Game.profile.cleared = ["courtyard", "blackwood", "cathedral", "crypt"]
	ok(Game.craft_stock().map(func(it): return it.id).has("a_frost_boots") and Game.craft_block("a_frost_boots") == "Needs Rimesteel" and not Game.craft("a_frost_boots"), "then it wants its material")
	Game.add_material("m_rime", 6)
	var gold0: int = Game.profile.gold
	ok(Game.craft("a_frost_boots") and Game.owns("a_frost_boots") and Game.material_count("m_rime") == 0 and Game.profile.gold == gold0 - 700 and not Game.craft("a_frost_boots"), "made once, paid for exactly")
	# a task whose reward is already held
	fresh()
	Game.grant_item("w_vigil_edge")
	Game.profile.defeated["ashen_sentinel"] = 1
	for l: Dictionary in Db.lore.slice(0, 4):
		Game.profile.lore.append(l.id)
	ok(Game.claim_quest("relief_of_the_gate") and Game.profile.inventory.count("w_vigil_edge") == 1 and Game.material_count("m_core") == 1, "a task reward already held becomes a core, not a second blade")

# ------------------------------------------------------------------ discovery states
func t_discovery() -> void:
	fresh()
	ok(Game.item_state("w_rusted_sword") == "equipped" and Game.item_state("w_monarch") == "undiscovered" and Game.item_state("w_knight_sword") == "discovered", "equipped; unknown; seen in the shop")
	ok(Game.item_state("a_black_chest") == "discovered" and Game.item_state("a_vigil_chest") == "undiscovered", "the next step of Orren's stock can be seen; what lies beyond it cannot")
	ok(Game.discover("w_monarch") and not Game.discover("w_monarch") and not Game.discover("w_nothing") and Game.item_state("w_monarch") == "discovered", "seen once: discovered")
	Game.grant_item("w_monarch")
	ok(Game.item_state("w_monarch") == "owned" and Game.is_new("w_monarch"), "found: owned, and marked new")
	Game.mark_seen("w_monarch")
	ok(not Game.is_new("w_monarch"), "looked at: no longer new")
	Game.equip("w_monarch")
	ok(Game.item_state("w_monarch") == "equipped", "worn: equipped")
	var rows := Game.items_for_slot("weapon")
	ok(rows.size() == 2 and rows.all(func(r): return r.owned), "without locked items, only what is held")
	rows = Game.items_for_slot("weapon", true)
	var states: Array = rows.map(func(r): return r.state)
	var weapons := Db.item_list.filter(func(it): return it.slot == "weapon" and int(it.get("ng_min", 0)) == 0)
	ok(rows.size() == weapons.size(), "with locked items, every blade of this cycle (%d)" % rows.size())
	var rank := {"equipped": 0, "owned": 0, "discovered": 1, "undiscovered": 2}
	var ordered := true
	for i: int in range(1, states.size()):
		ordered = ordered and rank[states[i]] >= rank[states[i - 1]]
	ok(ordered, "owned first, then discovered, then undiscovered")
	for r: Dictionary in rows:
		ok(r.hint != "" and (r.name == "Unknown") == (r.state == "undiscovered") and r.can_equip == r.owned and not r.item.is_empty(), "%s row is complete" % r.id)
	ok(not rows.any(func(r): return r.id == "w_oath_axe"), "what belongs to a later cycle stays out")
	Game.profile.ng = 1
	ok(Game.items_for_slot("weapon", true).any(func(r): return r.id == "w_oath_axe"), "until that cycle comes")
	for s: String in Db.EQUIP_SLOTS:
		for r: Dictionary in Game.items_for_slot(s, true):
			ok(r.item.slot == s, "%s is listed under %s" % [r.id, s])
	ok(Game.items_for_slot("offhand", true).is_empty(), "the off hand has nothing yet")
	# states survive a save
	Game.save()
	Game.profile = {}
	Game.load_game()
	ok(Game.item_state("w_monarch") == "equipped" and not Game.is_new("w_monarch") and Game.profile.discovered.has("w_monarch"), "discovery is saved")

# ------------------------------------------------------------------ cosmetics
func t_cosmetics() -> void:
	fresh()
	Game.grant_item("a_garrison_chest")
	Game.grant_item("a_ash_helm")
	var st := JSON.stringify(Game.stats())
	ok(Game.cosmetic("chest") == {"finish": "issued", "accent": "heraldry", "look_as": ""}, "no cosmetics to begin with")
	ok(Game.set_finish("chest", "graphite") and Game.set_accent("chest", "gold") and Game.set_look_as("chest", "a_garrison_chest"), "finish, accent and appearance can be set")
	ok(not Game.set_finish("chest", "rainbow") and not Game.set_accent("nowhere", "gold"), "only real finishes on real slots")
	ok(not Game.set_look_as("chest", "a_black_chest"), "an appearance must be owned")
	ok(not Game.set_look_as("chest", "a_ash_helm") and not Game.set_look_as("chest", "w_nothing"), "and of the same slot")
	ok(Game.cosmetic("chest") == {"finish": "graphite", "accent": "gold", "look_as": "a_garrison_chest"}, "what was set is kept")
	ok(JSON.stringify(Game.stats()) == st, "cosmetics change no number at all")
	ok(Game.appearance("chest") == "a_garrison_chest" and Game.profile.equipped.chest == "a_worn_chest" and Game.appearance("helm") == "a_worn_helm", "the look is one item, the real gear another")
	ok(Game.appearance_loadout().chest == "a_garrison_chest" and Game.appearance_loadout().ring == null, "the loadout to draw")
	Game.profile = {}
	Game.load_game()
	ok(Game.cosmetic("chest").look_as == "a_garrison_chest" and Game.cosmetic("chest").finish == "graphite", "cosmetics are saved")
	ok(Game.sell("a_garrison_chest") and Game.cosmetic("chest").look_as == "" and Game.appearance("chest") == "a_worn_chest", "selling the look removes the override")
	ok(Game.set_look_as("chest", "") and Game.cosmetic("chest").finish == "graphite", "an override can be cleared on its own")
	var bad := Game.profile.duplicate(true)
	bad.cosmetics = {"chest": {"finish": "gilt", "look_as": "a_regal_chest"}}
	bad = Game._migrate(bad)
	ok(not bad.cosmetics.chest.has("look_as") and bad.cosmetics.chest.finish == "gilt", "a stored override that is no longer owned is dropped; the finish stays")

# ------------------------------------------------------------------ mastery
func t_mastery() -> void:
	fresh()
	Game.grant_item("a_ash_chest")
	Game.equip("a_ash_chest")
	Game.profile.attrs.endurance = 12
	var it: Dictionary = Db.item("a_ash_chest")
	ok(Game.mastery_tier_text(it, 1) != "" and Game.mastery_tier_text(it, 2).contains("1%") and Game.mastery_tier_text(it, 3).contains("attribute point"), "an armour piece has three described marks")
	var regen: float = Game.stats().stamina_regen
	var found: Array = []
	var ups: Array = []
	for i: int in 8:
		var r := Game.on_victory(["banneret", "rampart_brute", "pike_sergeant"][i % 3], 50.0)
		for u: Dictionary in r.mastery_ups:
			if u.id == "a_ash_chest":
				ups.append(int(u.tier))
		for u: Dictionary in r.unlocks:
			if u.item == "a_ash_chest":
				found.append(u.type)
	ok(ups == [1, 2, 3] and found == ["discovery", "efficiency", "attr_point"], "the cuirass earns its three marks in order (%s %s)" % [str(ups), str(found)])
	ok(Game.stats().stamina_regen > regen, "worn in: stamina really does return faster")
	Game.profile.mastery.clear()
	Game.profile.mastered.clear()
	var cost0: float = Game.stats().swing_cost
	Game.profile.mastery["w_rusted_sword"] = 2
	ok(is_equal_approx(Game.stats().swing_cost, cost0 - 11.0 * 0.03), "a weapon's second mark makes its swings 3% cheaper")
	var guard0: float = Game.stats().block_eff
	Game.profile.mastery["s_plank"] = 2
	ok(is_equal_approx(Game.stats().block_eff, guard0 + 0.02), "a shield's second mark makes guarding 2% cheaper")
	Game.profile.mastery.clear()
	for w: Dictionary in Db.item_list:
		if w.slot == "weapon":
			var kinds: Array = w.mastery.marks.map(func(m): return m.type)
			ok(kinds == ["history", "combo", "attr_point"] and Game.item_history(w.id).size() == 1, "%s: history, technique, a point" % w.id)
			var has_combo := false
			for c: Dictionary in Db.combos:
				has_combo = has_combo or c.cls.is_empty() or c.cls.has(w.cls)
			ok(has_combo, "%s has techniques to teach" % w.id)
	# the mastery challenge
	fresh()
	ok(not Game.challenge_ready("both_hands") and not Game.claim_challenge("both_hands"), "the challenge is not met at first")
	Game.profile.mastered.append("w_pilgrim_blades")
	ok(not Game.challenge_ready("both_hands"), "one set of twin blades is not enough")
	Game.profile.mastered.append("w_twin_fangs")
	ok(Game.challenge_ready("both_hands") and Game.claim_challenge("both_hands") and Game.owns("w_twin_relics") and not Game.claim_challenge("both_hands"), "two are: Twin Relics, once")
	ok(Db.item("w_twin_relics").advanced and Db.item("w_monarch").advanced and not Db.item("w_knight_sword").advanced, "Recall belongs to the old make only")

# ------------------------------------------------------------------ the whole loop
func t_loop() -> void:
	fresh(99)
	Game.start_run("courtyard")
	# fight
	var s := DuelSim.new()
	s.setup(Game.stats(), Db.foes.hollow_soldier, 3, {"combos": Db.combos})
	var bot := DuelBot.new(s, DuelBot.Style.SKILLED, 3)
	for i: int in 300 * 60:
		bot.tick(1.0 / 60.0)
		s.tick(1.0 / 60.0)
		if s.over:
			break
	ok(s.b_state == DuelSim.B.DEAD, "the first foe falls")
	var first_time: float = s.time
	# reward
	var r := Game.on_victory("hollow_soldier", s.pl.hp)
	ok(r.gold > 0 and r.xp > 0 and Game.profile.gold == r.gold, "the victory pays")
	Game.profile.gold += 2000
	Game.profile.shards += 20
	# inspect, compare, equip
	ok(Game.buy("w_knight_sword") and Game.is_new("w_knight_sword"), "a better blade is bought and is new")
	var rows := Game.compare("weapon", "w_knight_sword")
	ok(rows[0].key == "attack" and rows[0].better == 1, "it compares as better")
	var before := Game.stats()
	ok(Game.equip("w_knight_sword") and Game.item_state("w_knight_sword") == "equipped" and not Game.is_new("w_knight_sword"), "it is equipped")
	ok(is_equal_approx(Game.stats().attack, rows[0].then) and Game.stats().attack > before.attack, "and does what the comparison said")
	# upgrade
	var pre := Game.stats()
	ok(Game.upgrade("w_knight_sword") and Game.upgrade("w_knight_sword") and Game.stats().attack > pre.attack, "it is upgraded twice")
	# fight again: the same fight, seed and bot, ends sooner
	var s2 := DuelSim.new()
	s2.setup(Game.stats(), Db.foes.hollow_soldier, 3, {"combos": Db.combos})
	var bot2 := DuelBot.new(s2, DuelBot.Style.SKILLED, 3)
	for i: int in 300 * 60:
		bot2.tick(1.0 / 60.0)
		s2.tick(1.0 / 60.0)
		if s2.over:
			break
	ok(s2.b_state == DuelSim.B.DEAD and s2.time < first_time and s2.pl.attack > s.pl.attack, "the same fight is shorter with the better, upgraded blade (%.1fs, was %.1fs)" % [s2.time, first_time])
	Game.on_victory("hollow_soldier", s2.pl.hp)
	Game.toggle_favourite("w_knight_sword")
	Game.set_finish("weapon", "brushed")
	# save, restart, everything persists
	ok(Game.save(), "saved")
	var mem: Dictionary = JSON.parse_string(snap())
	Game.profile = {}
	Game.run = {}
	ok(Game.load_game(), "loaded")
	var back: Dictionary = JSON.parse_string(snap())
	mem.erase("playtime"); back.erase("playtime")
	ok(JSON.stringify(mem) == JSON.stringify(back), "the journey is identical after a restart")
	ok(Game.is_equipped("w_knight_sword") and Game.upgrade_level("w_knight_sword") == 2 and Game.is_favourite("w_knight_sword") and Game.cosmetic("weapon").finish == "brushed"
		and Game.profile.defeated.hollow_soldier == 2 and typeof(Game.profile.materials.get("m_iron", 0)) == TYPE_INT and Game.profile.rewards.seed == 99, "gear, level, star, finish, kills, materials and the reward seed are all there")
	ok(is_equal_approx(Game.stats().attack, s2.pl.attack), "and the knight hits exactly as hard as before")

# ------------------------------------------------------------------ the four basic swords
func duel_log(st: Dictionary, foe: String, sd: int = 21) -> Dictionary:
	var s := DuelSim.new()
	s.setup(st, Db.foes[foe], sd, {"combos": Db.combos})
	var bot := DuelBot.new(s, DuelBot.Style.SKILLED, sd)
	var log := {"swings": 0, "openings": 0, "won": false, "time": 0.0, "dealt": 0.0, "per_cut": 0.0, "per_opening": 0.0, "spent": 0.0}
	var was_open := false
	var last_stamina: float = s.pl.stamina
	s.ev.connect(func(n: StringName, _d: Dictionary):
		if n == &"player_swing":
			log.swings += 1)
	for i: int in 300 * 60:
		bot.tick(1.0 / 60.0)
		s.tick(1.0 / 60.0)
		if s.boss_open() and not was_open:
			log.openings += 1
		was_open = s.boss_open()
		log.spent += maxf(0.0, last_stamina - s.pl.stamina)
		last_stamina = s.pl.stamina
		if s.over:
			break
	log.won = s.b_state == DuelSim.B.DEAD
	log.time = s.time
	log.dealt = s.stats.dealt
	log.per_cut = s.stats.dealt / maxf(1.0, log.swings)
	log.per_opening = float(log.swings) / maxf(1.0, log.openings)
	return log

func t_basic_swords() -> void:
	var basic: Array = Db.equipment.basic_swords
	ok(basic == ["w_rusted_sword", "w_dawnline", "w_censer_sword", "w_starfall"], "Wayfarer, Silver Vow, Ashbrand, Veilcutter")
	var by := {}
	var stat := {}
	for id: String in basic:
		var it: Dictionary = Db.item(id)
		ok(it.cls == "sword" and Db.rarity_rank(it) <= 1 and it.has("role") and str(it.role_text) != "" and it.get("req", {}).is_empty(), "%s is a basic sword anyone can use" % it.name)
		var p := Game.default_profile()
		p.equipped.weapon = id
		stat[it.role] = Stats.compute(p, Db.items, Db.classes)
		by[it.role] = [duel_log(stat[it.role], "ashen_sentinel"), duel_log(stat[it.role], "hollow_soldier"), duel_log(stat[it.role], "banneret")]
	ok(by.size() == 4, "four roles: balanced, light, heavy, precision")
	var b: Dictionary = stat.balanced
	ok(stat.light.swing_time < b.swing_time and stat.light.swing_cost < b.swing_cost and stat.light.attack < b.attack, "light: quicker, cheaper, softer")
	ok(stat.heavy.swing_time > b.swing_time and stat.heavy.swing_cost > b.swing_cost and stat.heavy.attack > b.attack and stat.heavy.guard_dmg > b.guard_dmg, "heavy: slower, dearer, harder, breaks guards")
	ok(stat.precision.crit_mult > b.crit_mult and stat.precision.swing_cost < b.swing_cost and stat.precision.attack < b.attack, "precision: punishes a stagger, cheap to chain")
	# each one's fight is a different fight
	var times: Array = []
	for role: String in by:
		var l: Dictionary = by[role][0]
		ok(l.won and by[role][1].won and by[role][2].won, "the %s sword beats the Courtyard" % role)
		times.append(l.time)
		print("    %-10s Sentinel in %5.1fs  %3d swings  %.1f per opening  %4.1f damage a cut  %4.0f stamina   soldier %4.1fs  banneret %4.1fs" % [role, l.time, l.swings, l.per_opening, l.per_cut, l.spent, by[role][1].time, by[role][2].time])
	var prints := {}
	for role: String in by:
		prints["%.2f|%d" % [by[role][0].time, by[role][0].swings]] = true
	ok(prints.size() == 4, "no two of them fight the Sentinel the same way")
	ok(by.light[0].swings > by.balanced[0].swings and by.balanced[0].swings > by.heavy[0].swings, "light needs the most cuts, heavy the fewest (%d > %d > %d)" % [by.light[0].swings, by.balanced[0].swings, by.heavy[0].swings])
	ok(by.light[0].per_opening > by.heavy[0].per_opening, "light fits more cuts into an opening than heavy (%.1f against %.1f)" % [by.light[0].per_opening, by.heavy[0].per_opening])
	ok(by.heavy[0].per_cut > by.balanced[0].per_cut and by.balanced[0].per_cut > by.light[0].per_cut, "and heavy does the most with each one")
	times.sort()
	ok(times[-1] / times[0] < 1.4, "sidegrades: the slowest kill is within 40%% of the quickest (%.1fs to %.1fs)" % [times[0], times[-1]])
	# the starting choice
	for id: String in basic:
		wipe()
		Game.new_game("#123456", "f", id)
		ok(Game.profile.equipped.weapon == id and Game.profile.inventory.has(id) and Game.profile.inventory.size() == 6 and Game.profile.body == "f", "a journey can start with %s" % id)
		var stock: Array = Game.shop_stock().map(func(it): return it.id)
		for other: String in basic:
			ok(other == id or (stock.has(other) and int(Db.item(other).price) <= 200), "starting with %s, %s is in Orren's first stock, cheaply" % [id, other])
		ok(basic.filter(func(o): return Game.owns(o)).size() == 1, "one basic sword to begin with")
		ok(Game.save() and Game.load_game() and Game.profile.equipped.weapon == id, "and the choice is saved")
	wipe()
	Game.new_game("#123456", "m", "w_monarch")
	ok(Game.profile.equipped.weapon == "w_rusted_sword" and not Game.owns("w_monarch"), "only a basic sword can be chosen")
	wipe()
	Game.new_game("#123456", "m", "w_silver_vow")
	ok(Game.profile.equipped.weapon == "w_dawnline", "by either of its ids")
	wipe()
	Game.new_game()
	ok(Game.profile.equipped.weapon == "w_rusted_sword" and Game.profile.heraldry == "#3d0f0f", "with nothing said, the Wayfarer's Blade as before")

# ------------------------------------------------------------------ shields: a count of blocks, and footwork
func shield_run(blocks: int, seconds: float = 40.0) -> Dictionary:
	var st := Stats.compute(strong(), Db.items, Db.classes)
	st["shield_blocks"] = blocks
	st["max_hp"] = 1.0e6
	st["max_stamina"] = 1.0e6
	var s := DuelSim.new()
	s.setup(st, Db.foes.hollow_soldier, 3, {"combos": Db.combos})
	var evs: Array = []
	s.ev.connect(func(n: StringName, d: Dictionary):
		if n == &"shield_charges":
			evs.append(d.duplicate()))
	s.input_block(true)
	for i: int in int(seconds * 60.0):
		s.tick(1.0 / 60.0)
	return {"sim": s, "events": evs, "lost": 1.0e6 - s.pl.hp, "spent": 1.0e6 - s.pl.stamina}

func t_shields() -> void:
	var classes := {}
	for it: Dictionary in Db.item_list:
		if it.slot != "shield":
			continue
		classes[it.shield_class] = true
		ok(int(it.get("blocks", 0)) >= 2 and float(it.get("regen", 0)) > 0.0 and float(it.get("mobility", 0)) > 0.0, "%s has a block count, a recovery and a footwork value" % it.id)
		var p := strong()
		p.equipped.shield = it.id
		var st := Stats.compute(p, Db.items, Db.classes)
		ok(st.shield_blocks == int(it.blocks) and is_equal_approx(st.dodge_cost, float(it.mobility)) and is_equal_approx(st.shield_regen, float(it.regen)), "%s reaches the duel's numbers" % it.id)
	ok(classes.has("heater") and classes.has("round") and classes.has("kite") and classes.has("segmented") and classes.has("curved"), "heater, round, kite, segmented and curved shields exist")
	var round_s: Dictionary = Db.item("s_round")
	var heater: Dictionary = Db.item("s_plank")
	var tower: Dictionary = Db.item("s_tower")
	ok(int(round_s.blocks) < int(heater.blocks) and int(heater.blocks) < int(tower.blocks), "light stops fewest blows, heavy most")
	ok(float(round_s.mobility) < float(heater.mobility) and float(heater.mobility) < float(tower.mobility), "light moves freest, heavy least")
	var two := strong()
	two.equipped.weapon = "w_ashen_great"
	ok(Stats.compute(two, Db.items, Db.classes).shield_blocks == 0, "a two-handed blade carries no shield count, even with a shield in the pack")
	var up := strong()
	up.upgrades["s_garrison"] = 4
	ok(Stats.compute(up, Db.items, Db.classes).shield_blocks == int(Db.item("s_garrison").blocks) + 2, "a worked shield stops more blows")
	# the count in the duel: it runs down, then the shield is spent
	var a := shield_run(3)
	var lefts: Array = a.events.map(func(e): return int(e.left))
	ok(lefts.size() >= 6 and lefts.slice(0, 4) == [2, 1, 0, 0] and a.events[0].max == 3, "three blocks count down to none (%s)" % str(lefts.slice(0, 6)))
	ok(not a.events[2].spent and a.events[3].spent and int(a.sim.stats.spent_blocks) == lefts.size() - 3, "the blow after the last is caught on a spent shield")
	var many := shield_run(100)
	ok(int(many.sim.stats.get("spent_blocks", 0)) == 0 and many.sim.stats.blocks == a.sim.stats.blocks, "a shield with blocks to spare is never spent in the same fight")
	ok(a.lost > many.lost * 2.0 and a.spent > many.spent * 1.3, "a spent shield lets blows through and costs more stamina (%.0f health against %.0f)" % [a.lost, many.lost])
	ok(shield_run(0).events.is_empty() and is_equal_approx(shield_run(0).lost, many.lost), "with no count (no shield) guarding is as it always was")
	# and comes back while the guard is down, one at a time
	var s: DuelSim = a.sim
	s.input_block(false)
	a.events.clear()
	var regen: float = s.pl.shield_regen
	for i: int in int((regen * 3.0 + 0.5) * 60.0):
		s.tick(1.0 / 60.0)
	ok(a.events.map(func(e): return int(e.left)) == [1, 2, 3] and s.p_shield == 3, "one block returns for every %.1fs the guard is down" % regen)
	for i: int in 600:
		s.tick(1.0 / 60.0)
	ok(a.events.size() == 3 and s.p_shield == 3, "and never more than it holds")
	# holding the guard up does not bring it back
	var held := shield_run(2, 30.0)
	ok(held.sim.p_shield == 0, "a shield held up does not recover")
	# a block timed to the blow costs no charge
	var t := DuelSim.new()
	var st := Stats.compute(strong(), Db.items, Db.classes)
	t.setup(st, Db.foes.hollow_soldier, 3, {"combos": Db.combos})
	for i: int in 4000:
		if t.b_state == DuelSim.B.WINDUP and t.b_t <= 0.1:
			break
		t.tick(1.0 / 120.0)
	t.input_block(true)
	while t.b_state == DuelSim.B.WINDUP:
		t.tick(1.0 / 120.0)
	t.tick(1.0 / 60.0)
	ok(int(t.stats.get("perfect_blocks", 0)) == 1 and t.p_shield == t.p_shield_max and t.p_shield_max == int(Db.item("s_garrison").blocks), "a timed block keeps the shield whole")
	# footwork: the same dodge costs a light shield less and a heavy one more
	var costs := {}
	for id: String in ["s_round", "s_plank", "s_tower"]:
		var p := strong()
		p.equipped.shield = id
		var d := DuelSim.new()
		d.setup(Stats.compute(p, Db.items, Db.classes), Db.foes.hollow_soldier, 3, {"combos": Db.combos})
		var before: float = d.pl.stamina
		d.input_dodge(-1)
		costs[id] = before - d.pl.stamina
	ok(is_equal_approx(costs.s_plank, DuelSim.DODGE_COST) and is_equal_approx(costs.s_round, DuelSim.DODGE_COST * 0.8) and is_equal_approx(costs.s_tower, DuelSim.DODGE_COST * 1.25),
		"a dodge costs %.1f with the round shield, %.1f with the heater, %.1f with the bulwark" % [costs.s_round, costs.s_plank, costs.s_tower])
	# practice and the lesson still run with a shield on the arm
	for mode: String in ["training", "lesson"]:
		var pr := DuelSim.new()
		pr.setup(st, Db.foes.hollow_soldier, 3, {"combos": Db.combos, mode: true})
		pr.input_block(true)
		for i: int in 600:
			pr.tick(1.0 / 60.0)
		ok(not pr.over and pr.p_shield == pr.p_shield_max, "%s runs with the shield count in place" % mode)

# ------------------------------------------------------------------ weapon mods: blade, grip, ore, sharpen
func t_mods() -> void:
	fresh()
	var id := "w_rusted_sword"
	var it: Dictionary = Db.item(id)
	Game.profile.gold = 0
	ok(Game.mod_block(id, "blade") == "Not enough gold" and not Game.mod(id, "blade") and not Game.mod(id, "grip") and not Game.sharpen(id) and Game.profile.gold == 0, "no gold: no work, no debt")
	ok(Game.mod_block("s_plank", "blade") == "Not a weapon" and Game.mod_block("w_monarch", "blade") == "Not yours" and Game.mod_block(id, "polish") == "No such work", "only weapons that are held, only real tracks")
	Game.profile.gold = 100000
	Game.profile.shards = 500
	var base := Game.stats()
	# blade
	ok(Game.mod(id, "blade") and Game.mod(id, "blade") and Game.upgrade_level(id) == 2 and Game.weapon_mods(id).blade == 2, "two blade tiers on plain iron; the old level reads the same")
	var bl := Game.stats()
	ok(is_equal_approx(bl.attack, base.attack * 1.2) and is_equal_approx(bl.guard_dmg, base.guard_dmg * 1.16) and differs(base, bl), "blade: more damage and guard damage, in the duel")
	ok(Game.mod_block(id, "blade") == "Needs better ore" and not Game.mod(id, "blade"), "the blade can go no further in iron")
	# grip
	ok(Game.mod(id, "grip") and Game.mod_block(id, "grip") == "Needs better ore", "one grip tier on iron")
	var gr := Game.stats()
	ok(is_equal_approx(gr.swing_time, bl.swing_time * 0.97) and is_equal_approx(gr.swing_cost, bl.swing_cost * 0.95) and differs(bl, gr), "grip: quicker and cheaper swings, in the duel")
	# ore
	ok(Game.mod(id, "ore") and Game.weapon_mods(id).ore == 1 and Game.weapon_mods(id).caps.blade == 3 and Game.weapon_mods(id).caps.grip == 2, "steel lifts both caps")
	var o1 := Game.stats()
	ok(is_equal_approx(o1.attack, gr.attack * 1.03) and differs(gr, o1), "ore: a little damage of its own")
	ok(Game.mod(id, "blade") and Game.mod(id, "grip"), "and the other tracks move again")
	ok(Game.mod_block(id, "ore") == "Choose an ore" and Game.mod_block(id, "ore", "m_rime") == "Needs Rimesteel" and not Game.mod(id, "ore", "m_rime"), "the next ore is a region's, and has to be brought")
	Game.add_material("m_rime", 4)
	var pre := Game.stats()
	var seen: Array = Game.mod_preview(id, "ore", "m_rime").map(func(r): return r.key)
	ok(Game.mod(id, "ore", "m_rime") and Game.material_count("m_rime") == 0 and Game.weapon_mods(id).ore_id == "m_rime" and Game.stats().element == "frost", "reforged in rimesteel the blade bites with frost")
	ok(seen.has("attack") and pre.element == null and differs(pre, Game.stats()), "and that changes the duel")
	ok(Game.mod_block(id, "ore") == "Needs Guardian Core", "the last ore wants a guardian core")
	Game.add_material("m_core", 1)
	ok(Game.mod(id, "ore") and Game.weapon_mods(id).ore_id == "m_rime" and Game.mod_block(id, "ore") == "Perfected", "cored: the ore keeps its nature")
	while Game.mod(id, "blade") or Game.mod(id, "grip"):
		pass
	var w := Game.weapon_mods(id)
	ok(w.blade == 5 and w.grip == 3 and w.ore == 3 and Game.upgrade_level(id) == Stats.MAX_UPGRADE and Game.mod_block(id, "blade") == "Perfected" and Game.mod_block(id, "grip") == "Perfected", "every track has an end")
	ok(w.visual == {"blade_tier": 3, "grip_tier": 3, "ore": "cored", "ore_id": "m_rime", "keen": false}, "the look of the mods is recorded for whoever draws the sword")
	ok(Game.weapon_mods("w_knight_sword").visual.ore == "iron" and Game.weapon_mods("w_knight_sword").visual.blade_tier == 0, "an unworked blade is plain iron")
	# every track's costs rise
	for wp: Dictionary in Db.item_list:
		if wp.slot != "weapon":
			continue
		var good: bool = wp.has("mods") and wp.mods.grip.size() == 3 and wp.mods.ore.size() == 3 and int(wp.mods.sharpen.gold) > 0
		for track: String in ["grip", "ore"]:
			for n: int in [1, 2]:
				good = good and int(wp.mods[track][n].gold) > int(wp.mods[track][n - 1].gold)
		ok(good, "%s has rising grip and ore costs and a sharpening price" % wp.id)
		ok(int(wp.mods.sharpen.gold) < int(wp.upgrade.costs[0].gold), "%s: sharpening is the cheapest work there is" % wp.id)
	# the old one-button upgrade walks the same road and charges what it says
	fresh()
	Game.profile.gold = 100000
	Game.profile.shards = 500
	Game.add_material("m_iron", 20)
	Game.add_material("m_core", 2)
	Game.grant_item("w_knight_sword")
	var steps := 0
	var honest := true
	while Game.can_upgrade("w_knight_sword"):
		var said := Stats.upgrade_cost(Db.item("w_knight_sword"), Game.upgrade_level("w_knight_sword"))
		var g: int = Game.profile.gold
		var sh: int = Game.profile.shards
		honest = honest and JSON.stringify(said) == JSON.stringify(Game.upgrade_cost("w_knight_sword"))
		Game.upgrade("w_knight_sword")
		honest = honest and Game.profile.gold == g - int(said.gold) and Game.profile.shards == sh - int(said.shards)
		steps += 1
	ok(steps == 5 and honest and Game.upgrade_level("w_knight_sword") == 5 and Game.weapon_mods("w_knight_sword").ore == 3 and Game.weapon_mods("w_knight_sword").ore_id == "m_iron",
		"five presses of the old button perfect the blade, ore steps included, each charging the price shown")
	ok(Game.material_count("m_iron") == 16 and Game.material_count("m_core") == 1, "and its ore came out of the pack")
	# sharpen: cheap, temporary, never stacked, saved
	fresh()
	Game.profile.gold = 1000
	var dull := Game.stats()
	var price: int = int(Game.mod_cost(id, "sharpen").gold)
	ok(Game.sharpen(id) and Game.profile.gold == 1000 - price and Game.weapon_mods(id).edge == 3 and Game.weapon_mods(id).visual.keen, "sharpened: three fights of edge")
	var keen := Game.stats()
	ok(is_equal_approx(keen.attack, dull.attack * 1.08) and differs(dull, keen), "a keen edge cuts 8% deeper, in the duel")
	ok(Game.mod_block(id, "sharpen") == "Still keen" and not Game.sharpen(id) and Game.profile.gold == 1000 - price and Game.weapon_mods(id).edge == 3, "it cannot be stacked or topped up")
	Game.start_run("courtyard")
	Game.on_victory("hollow_soldier", 50.0)
	ok(Game.weapon_mods(id).edge == 2, "a win uses one fight of it")
	Game.on_death()
	ok(Game.weapon_mods(id).edge == 1, "so does a loss")
	Game.save()
	Game.profile = {}
	Game.load_game()
	ok(Game.weapon_mods(id).edge == 1 and typeof(Game.profile.edge[id]) == TYPE_INT and is_equal_approx(Game.stats().attack, keen.attack), "the edge is saved as it stands")
	Game.start_run("courtyard")
	Game.on_victory("banneret", 50.0)
	ok(Game.weapon_mods(id).edge == 0 and not Game.profile.edge.has(id) and is_equal_approx(Game.stats().attack, dull.attack), "after three fights it is dull again, exactly as before")
	ok(Game.sharpen(id) and Game.weapon_mods(id).edge == 3, "and can be sharpened again")
	Game.grant_item("w_knight_sword")
	Game.equip("w_knight_sword")
	Game.on_victory("pike_sergeant", 50.0)
	ok(Game.weapon_mods(id).edge == 3, "an edge only wears on the blade that is carried")
	# old saves: the level a weapon had is its blade tier, with the ore that tier needs
	var v := Game._migrate(fixture("save_v1"))
	ok(v.upgrades["w_oath_axe"] == 5 and v.mods["w_oath_axe"].ore == 3 and v.upgrades["w_monarch"] == 4 and v.mods["w_monarch"].ore == 2 and v.mods["w_monarch"].ore_id == "m_glass",
		"old weapon levels land on the blade track with ore to match")
	Game.profile = v
	ok(Game.weapon_mods("w_oath_axe").blade == 5 and Game.weapon_mods("w_monarch").caps.blade >= 4 and Game.weapon_mods("w_oath_axe").caps.blade == 5, "and are not stranded above their cap")
	var old_dmg: float = float(Db.item("w_oath_axe").damage) * 1.5
	var legacy := v.duplicate(true)
	legacy.mods = {}
	ok(Stats.compute(v, Db.items, Db.classes).attack >= Stats.compute(legacy, Db.items, Db.classes).attack and Stats.compute(legacy, Db.items, Db.classes).attack >= old_dmg, "the migrated blade hits at least as hard as it did")
	var e := Game._migrate(fixture("save_v1_early"))
	ok(e.upgrades["w_ashen_great"] == 3 and e.mods["w_ashen_great"].ore == 1 and not e.mods.has("a_black_chest"), "level three needed steel; armour has no ore")
	var packed := Game._pack(v)
	ok(packed.items["w_monarch"].mods.ore == 2 and not packed.has("mods") and not packed.has("edge"), "mods are written in the item's own record")
	fresh()

# ------------------------------------------------------------------ the shop is where blades come from
func t_shop() -> void:
	var eq: Dictionary = Db.equipment
	# three weapons are dropped in the whole campaign, and they cannot be bought
	var dropped: Array = []
	for b: String in eq.boss_rewards:
		for id: String in eq.boss_rewards[b].first:
			if Db.item(id).slot == "weapon":
				dropped.append(id)
		for e: Array in eq.boss_rewards[b].pool:
			ok(Db.item(e[0]).slot != "weapon", "%s's pool holds no weapon (%s)" % [b, e[0]])
	for foe: String in eq.encounters:
		ok(Db.item(eq.encounters[foe]).slot != "weapon", "no optional foe drops a weapon")
	ok(dropped.size() == 3 and dropped.has("w_monarch"), "guardians drop three weapons in all (%s)" % str(dropped))
	for id: String in dropped:
		ok(int(Db.item(id).price) == 0 and Db.rarity_rank(Db.item(id)) >= 3, "%s is Legendary or Relic and never sold" % id)
	var regions: Array = dropped.map(func(id): return Db.regions.find(Db.region_by_id[Db.item(id).source.region]))
	ok(regions[0] != regions[1] and regions[1] != regions[2] and regions.max() - regions.min() >= 4, "and they are spread along the road")
	# every other weapon is bought, or is a start, a task, a pattern or a challenge
	var ladder: Array = []
	for it: Dictionary in Db.item_list:
		if it.slot != "weapon" or dropped.has(it.id):
			continue
		var kinds: Array = it.sources.map(func(s): return s.type)
		ok(not kinds.has("boss") and not kinds.has("encounter"), "%s is not a drop" % it.id)
		if int(it.price) > 0:
			ladder.append(it)
			ok(str(it.unlock_text) != "" and it.has("unlock"), "%s says when it unlocks" % it.id)
	ok(ladder.size() >= 12, "the shop carries most blades (%d)" % ladder.size())
	# locked entries can be seen, not bought; a guardian's fall opens its blade
	fresh()
	Game.profile.gold = 100000
	var cat := {}
	for e: Dictionary in Game.shop_catalog():
		cat[e.id] = e
	ok(cat.has("w_knight_sword") and cat.w_knight_sword.available and cat.w_knight_sword.affordable and cat.w_knight_sword.unlock_text == "", "what is in stock is plainly for sale")
	ok(cat.has("w_ashen_great") and not cat.w_ashen_great.available and str(cat.w_ashen_great.unlock_text).contains("Fallen Courtyard") and not str(cat.w_ashen_great.unlock_text).contains("Sentinel"),
		"a locked blade is shown with a spoiler-free line (%s)" % cat.get("w_ashen_great", {}).get("unlock_text", ""))
	ok(not cat.has("w_wyrmfang") and not cat.has("w_hunger") and not cat.has("w_rusted_sword"), "far-off stock and what is already held are not listed")
	ok(not Game.buy("w_ashen_great") and Game.profile.gold == 100000 and Game.buy_price("w_ashen_great") == 0, "a locked blade cannot be bought, whatever the purse")
	var row: Dictionary = Game.items_for_slot("weapon", true).filter(func(r): return r.id == "w_ashen_great")[0]
	ok(row.state == "discovered" and row.shop == "locked" and row.unlock_text != "" and row.price == 0, "the armoury row says it is shop-locked")
	var prices: Array = Game.shop_catalog().map(func(e): return e.price)
	var sorted_prices: Array = prices.duplicate()
	sorted_prices.sort()
	ok(prices == sorted_prices, "the catalogue runs from cheapest to dearest")
	Game.on_victory("ashen_sentinel", 50.0)
	ok(Game.buy_price("w_ashen_great") == 900 and Game.buy("w_ashen_great") and Game.profile.gold > 100000 - 900, "once its guardian has fallen it is for sale")
	Game.profile.cleared = ["courtyard"]
	ok(Game.items_for_slot("weapon", true).filter(func(r): return r.id == "w_headsman")[0].shop == "locked", "and with the next region open, the next one is in view")
	# the ladder climbs with the road
	var by_stage := {}
	for it: Dictionary in ladder:
		if int(it.get("ng_min", 0)) > 0:
			continue
		var stage: int = Db.regions.find(Db.region_by_id[Db.foes[it.unlock.boss].region]) + 1 if it.unlock.has("boss") else int(it.unlock.cleared)
		by_stage[stage] = maxi(int(by_stage.get(stage, 0)), int(it.price))
	var early := 0
	var late := 0
	for stage: int in by_stage:
		if stage <= 2:
			early = maxi(early, int(by_stage[stage]))
		elif stage >= 5:
			late = maxi(late, int(by_stage[stage]))
	ok(int(by_stage[0]) <= 400 and early < 2000 and late >= 5000 and late >= 15 * int(by_stage[0]), "prices climb steeply along the road (%s)" % str(by_stage))
	# the next cycle's blades
	ok(not Game.shop_catalog().any(func(e): return e.id == "w_oath_axe"), "Oathbreaker is not offered the first time round")
	Game.start_ng_plus(true)
	ok(Game.shop_catalog().any(func(e): return e.id == "w_oath_axe" and e.available), "it is in the shop for those who return")
