class_name Rewards
extends RefCounted
## What a victory gives. roll() is pure: it reads the profile and the data and returns a result, and changes nothing.
## Game.on_victory() applies the result. The roll is seeded from the journey's own seed, the foe and how many times
## that foe has already fallen, so the same victory always pays the same and nothing is gained by losing and trying
## again. Numbers live in data/equipment.json ("rewards", "boss_rewards", "encounters", "drops").
##
## Result (everything a victory screen or a reveal screen needs):
##   xp, gold, shards            numbers, already scaled for New Game Plus and for repeats
##   items_new / items           ids of gear gained (the same array: `items` is what the first overlay reads)
##   materials                   {material id: count}
##   discoveries                 ids that went from unknown silhouette to known (seen as a drop, or heard of)
##   mastery_ups, unlocks        filled in by Game.on_victory (mastery marks reached, things they opened)
##   first                       the first time this foe has fallen
##   repeat                      share paid because of recent repeats of this foe (1.0 = full)
##   compensation                {gold, materials} paid in place of a guaranteed item already held
##   shop_unlocks                ids Orren stocks from now on because this guardian fell (first kill only)
##   pity                        true when the dry-streak rule forced something new into this result

static func rules() -> Dictionary:
	return Db.equipment.rewards

## The seed of the next victory over this foe.
static func roll_seed(profile: Dictionary, foe_id: String) -> int:
	var st: Dictionary = profile.get("rewards", {})
	return hash("%d|%s|%d|%d" % [int(st.get("seed", 0)), foe_id, int(profile.get("defeated", {}).get(foe_id, 0)), int(profile.get("ng", 0))])

## Share of gold, experience and materials paid for this foe now: it falls as the same foe fills the recent wins.
static func repeat_share(profile: Dictionary, foe_id: String) -> float:
	var steps: Array = rules().repeat
	var n: int = profile.get("rewards", {}).get("recent", []).count(foe_id)
	return float(steps[mini(n, steps.size() - 1)])

static func known(profile: Dictionary, id: String) -> bool:
	return profile.get("inventory", []).has(id) or profile.get("discovered", {}).has(id)

static func _add(mats: Dictionary, id: String, n: int) -> void:
	if n > 0:
		mats[id] = int(mats.get(id, 0)) + n

## Items tied to a region by any of their sources, in data order.
static func region_items(region: String) -> Array:
	var out: Array = []
	for it: Dictionary in Db.item_list:
		for s: Dictionary in it.get("sources", []):
			if str(s.get("region", "")) == region:
				out.append(str(it.id))
				break
	return out

static func roll(profile: Dictionary, foe_id: String) -> Dictionary:
	var foe: Dictionary = Db.foes[foe_id]
	var r := rules()
	var eq: Dictionary = Db.equipment
	var st: Dictionary = profile.get("rewards", {})
	var ng: int = int(profile.get("ng", 0))
	var first: bool = not profile.get("defeated", {}).has(foe_id)
	var rep := repeat_share(profile, foe_id)
	var region: String = str(foe.get("region", ""))
	var mat: String = str(eq.region_material.get(region, "m_iron"))
	var elite: bool = eq.elites.has(foe_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed(profile, foe_id)
	var items: Array = []
	var mats := {}
	var out := {"xp": int(foe.xp * (1.0 + float(r.ng_xp) * ng) * rep), "gold": int(foe.gold * (1.0 + float(r.ng_gold) * ng) * rep), "shards": int(r.shards_fight),
		"items": items, "items_new": items, "materials": mats, "discoveries": [], "mastery_ups": [], "unlocks": [],
		"levels": 0, "mastered": [], "first": first, "repeat": rep, "compensation": {}, "pity": false, "core": false, "shop_unlocks": []}
	var has := func(id: String) -> bool: return profile.get("inventory", []).has(id) or items.has(id)
	if foe.boss:
		out.shards = int(r.shards_boss) + int(r.shards_boss_per_region) * maxi(0, eq.region_order.find(region))
		var b: Dictionary = eq.boss_rewards.get(foe_id, {"first": [], "pool": [], "materials": {}})
		# one guardian core for each guardian, once in each cycle of the world
		out.core = int(st.get("cores", {}).get(foe_id, 0)) <= ng
		for m: String in b.materials:
			if m == "m_core":
				_add(mats, m, int(b.materials[m]) if out.core else 0)
			else:
				_add(mats, m, maxi(1, roundi(float(b.materials[m]) * rep)))
		for id: String in b.first:
			if not has.call(id):
				items.append(id)
			else:
				# never a duplicate: the guaranteed place pays gold and material instead
				var g: int = int(foe.gold * float(r.dup_gold) * rep)
				out.gold += g
				_add(mats, mat, int(r.dup_mats))
				out.compensation = {"gold": int(out.compensation.get("gold", 0)) + g, "materials": {mat: int(out.compensation.get("materials", {}).get(mat, 0)) + int(r.dup_mats)}}
		for e: Array in b.pool:
			var hit: bool = rng.randf() < float(e[1])        # rolled for every entry, so owning one never shifts the others
			if hit and not has.call(str(e[0])):
				items.append(str(e[0]))
		if ng > 0 and rng.randf() < float(r.ng_item_chance):
			for it: Dictionary in Db.item_list:
				if int(it.get("ng_min", 0)) >= 1 and int(it.ng_min) <= ng and int(it.get("price", 0)) <= 0 and not has.call(str(it.id)):
					items.append(str(it.id))
					break
		if first:
			# what Orren can sell now that this guardian is gone
			for id: String in b.get("unlocks", []):
				if not has.call(id):
					out.shop_unlocks.append(id)
			for e: Array in b.pool:
				if not known(profile, str(e[0])) and not items.has(str(e[0])):
					out.discoveries.append(str(e[0]))
	else:
		var m_roll := rng.randf()
		var d_roll := rng.randf()
		var pick := rng.randi()
		var k_roll := rng.randf()
		_add(mats, mat, int(r.mat_elite) if elite else (int(r.mat_fight) if m_roll < float(r.mat_chance) * rep else 0))
		var exclusive: String = str(eq.encounters.get(foe_id, ""))
		if exclusive != "" and not has.call(exclusive):
			items.append(exclusive)
		var pool: Array = eq.drops.get(region, []).filter(func(id): return not has.call(id))
		if not pool.is_empty() and d_roll < float(r.elite_drop_chance if elite else r.drop_chance) * rep:
			items.append(str(pool[pick % pool.size()]))
		if k_roll < float(r.discover_chance):
			var unknown: Array = region_items(region).filter(func(id): return not known(profile, id) and not items.has(id))
			if not unknown.is_empty():
				out.discoveries.append(str(unknown[pick % unknown.size()]))
	# the dry-streak rule: after `pity` wins with nothing new to look at, something new is found
	if items.is_empty() and out.discoveries.is_empty() and int(st.get("pity", 0)) >= int(r.pity) - 1:
		out.pity = true
		var pool: Array = eq.drops.get(region, []).filter(func(id): return not has.call(id))
		var unknown: Array = region_items(region).filter(func(id): return not known(profile, id))
		if unknown.is_empty():
			for it: Dictionary in Db.item_list:
				if not known(profile, str(it.id)):
					unknown.append(str(it.id))
					break
		var n := rng.randi()
		if not pool.is_empty():
			items.append(str(pool[n % pool.size()]))
		elif not unknown.is_empty():
			out.discoveries.append(str(unknown[n % unknown.size()]))
		else:
			_add(mats, mat, 2)       # everything is known and held: the streak pays in material
	return out
