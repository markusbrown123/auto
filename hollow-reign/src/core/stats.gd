class_name Stats
extends RefCounted
## Derives combat numbers from a save profile (attributes + equipped gear).

const MAX_UPGRADE := 5

static func xp_for_level(level: int) -> int:
	return int(120.0 * pow(level, 1.6))

## The equipment rules (data/equipment.json): weight classes, families and their set bonuses, requirement penalties.
## Set by Db when the data is loaded; empty means "no such rules", and compute() then behaves as it did before them.
static var rules: Dictionary = {}

## What the next upgrade level costs: {gold, shards, materials: {material id: count}}. `level` is the level held now.
## Items with an upgrade track in the data use its table; anything else falls back to the old formula.
static func upgrade_cost(it: Dictionary, level: int) -> Dictionary:
	var costs: Array = it.get("upgrade", {}).get("costs", [])
	if level >= 0 and level < costs.size():
		var mats := {}
		for m: String in costs[level].get("materials", {}):
			mats[m] = int(costs[level].materials[m])
		return {"gold": int(costs[level].gold), "shards": int(costs[level].shards), "materials": mats}
	var rank: int = ["common", "uncommon", "rare", "epic", "legendary"].find(it.get("rarity", "common"))
	return {"gold": (120 + rank * 110) * (level + 1), "shards": (level + 1) * (1 + rank / 2), "materials": {}}

## Mastery mark reached with this item (0-3) in the given profile.
static func mastery_mark(profile: Dictionary, it: Dictionary) -> int:
	var need := mastery_needed(it)
	var id: String = str(it.get("id", ""))
	var have: int = need if profile.get("mastered", []).has(id) else int(profile.get("mastery", {}).get(id, 0))
	if have >= need:
		return 3
	return 2 if have >= ceili(need * 2.0 / 3.0) else (1 if have >= ceili(need / 3.0) else 0)

## Requirement keys of the item the attributes do not meet ([] when it can be used freely).
static func unmet(attrs: Dictionary, it: Dictionary) -> Array:
	var out: Array = []
	for k: String in it.get("req", {}):
		if float(attrs.get(k, 0)) < float(it.req[k]):
			out.append(k)
	return out

static func mastery_needed(it: Dictionary) -> int:
	var rank: int = ["common", "uncommon", "rare", "epic", "legendary"].find(it.get("rarity", "common"))
	return 3 + rank * 2

static func item_power(it: Dictionary, level: int) -> float:
	var up := 1.0 + 0.1 * level
	if it.slot == "weapon":
		return float(it.damage) * up
	return float(it.get("defense", 0)) * up

## One-line summary numbers used by the comparison UI.
static func item_lines(it: Dictionary, level: int, classes: Dictionary) -> Array:
	var out: Array = []
	var up := 1.0 + 0.1 * level
	if it.slot == "weapon":
		var c: Dictionary = classes[it.cls]
		out.append(["Damage", snappedf(float(it.damage) * up, 0.1)])
		out.append(["Swing", "%.2fs" % c.swing])
		out.append(["Stamina", c.stamina])
		if it.get("element") != null:
			out.append(["Element", str(it.element).capitalize()])
	for k in [["defense", "Defense"], ["hp", "Health"], ["stamina", "Stamina"], ["strength", "Strength"], ["dex", "Dexterity"], ["crit", "Critical"], ["resist", "Resistance"]]:
		var v: float = float(it.get(k[0], 0))
		if it.slot == "weapon" and k[0] == "stamina":
			continue
		if v != 0.0:
			out.append([k[1], snappedf(v * (up if k[0] == "defense" else 1.0), 0.1)])
	if float(it.get("block", 0)) > 0.0:
		out.append(["Guard", "%d%%" % int(float(it.block) * 100.0)])
	if it.has("weight") and rules.get("weights", {}).has(it.weight):
		out.append(["Weight", str(rules.weights[it.weight].name)])
	return out

static func compute(profile: Dictionary, items: Dictionary, classes: Dictionary) -> Dictionary:
	var a: Dictionary = profile.attrs
	var eq: Dictionary = profile.equipped
	var up: Dictionary = profile.get("upgrades", {})
	var bonus := {"defense": 0.0, "hp": 0.0, "stamina": 0.0, "strength": 0.0, "dex": 0.0, "crit": 0.0, "resist": 0.0}
	# percentage and guard modifiers from weight class, set bonuses, unmet requirements and mastery
	var mods := {"regen_pct": 0.0, "swing_cost_pct": 0.0, "attack_pct": 0.0, "block": 0.0}
	var weights := {"light": 0, "medium": 0, "heavy": 0}
	var fam_count := {}
	var unmet_ids: Array = []
	var pen: Dictionary = rules.get("require_penalty", {})
	var block_eff := 0.0
	var weapon: Dictionary = {}
	for slot in eq:
		var id = eq[slot]
		if id == null or not items.has(id):
			continue
		var it: Dictionary = items[id]
		var lvl: int = int(up.get(id, 0))
		var w: Dictionary = rules.get("weights", {}).get(it.get("weight", ""), {})
		if not w.is_empty():
			weights[it.weight] += 1
			for k: String in mods:
				mods[k] += float(w.get(k, 0.0))
		if slot != "weapon" and slot != "shield" and it.has("weight") and it.has("family") and it.get("set_piece", true):
			fam_count[it.family] = int(fam_count.get(it.family, 0)) + 1
		if not unmet(a, it).is_empty():
			unmet_ids.append(id)
			if slot == "weapon":
				mods.attack_pct += float(pen.get("attack_pct", 0.0))
				mods.swing_cost_pct += float(pen.get("swing_cost_pct", 0.0))
			else:
				mods.regen_pct += float(pen.get("regen_pct", 0.0))
		if not rules.is_empty() and mastery_mark(profile, it) >= 2:
			if slot == "weapon":
				mods.swing_cost_pct -= 3.0
			elif slot == "shield":
				mods.block += 0.02
			elif it.has("weight"):
				mods.regen_pct += 1.0
		if slot == "weapon":
			weapon = it
			bonus.crit += float(it.get("crit", 0))
			continue
		for k in bonus:
			var v := float(it.get(k, 0))
			bonus[k] += v * (1.0 + 0.1 * lvl) if k == "defense" else v
		if slot == "shield":
			block_eff = float(it.get("block", 0)) + 0.03 * lvl
	# set bonuses: every threshold reached counts, so six pieces give the 2, the 4 and the 6
	var sets: Array = []
	for fam: String in fam_count:
		var active: Array = []
		for tier: Dictionary in rules.get("families", {}).get(fam, {}).get("set", []):
			if int(fam_count[fam]) < int(tier.pieces):
				continue
			active.append(str(tier.text))
			for k: String in tier.bonus:
				if bonus.has(k):
					bonus[k] += float(tier.bonus[k])
				else:
					mods[k] += float(tier.bonus[k])
		sets.append({"family": fam, "pieces": int(fam_count[fam]), "active": active})
	var cls: Dictionary = classes[weapon.get("cls", "sword")] if not weapon.is_empty() else classes["sword"]
	var strength: float = float(a.strength) + bonus.strength
	var dex: float = float(a.dex) + bonus.dex
	var scale: float = strength * float(cls.scale.strength) + dex * float(cls.scale.dex)
	var wdmg: float = float(weapon.get("damage", 6)) * (1.0 + 0.1 * int(up.get(weapon.get("id", ""), 0)))
	var defense: float = bonus.defense + float(a.defense) * 2.0
	var endurance: float = float(a.endurance)
	# two-handed classes have no shield: blocking with the blade costs more
	if cls.two_handed:
		block_eff = minf(block_eff, 0.0) - 0.15
	block_eff = minf(block_eff + float(mods.block), 0.9)
	var worn: int = int(weights.light) + int(weights.medium) + int(weights.heavy)
	var burden := "none"
	if worn > 0:
		var score: float = float(int(weights.heavy) - int(weights.light)) / float(worn)
		burden = "heavy" if score > 0.34 else ("light" if score < -0.34 else "medium")
	return {
		"max_hp": 100.0 + 12.0 * float(a.health) + bonus.hp,
		"max_stamina": 100.0 + 6.0 * endurance + bonus.stamina,
		"stamina_regen": (26.0 + 0.8 * endurance) * maxf(0.4, 1.0 + float(mods.regen_pct) / 100.0),
		"attack": wdmg * (1.0 + 0.025 * scale) * maxf(0.4, 1.0 + float(mods.attack_pct) / 100.0),
		"swing_time": float(cls.swing),
		"swing_cost": float(cls.stamina) * maxf(0.5, 1.0 + float(mods.swing_cost_pct) / 100.0),
		"mitigation": defense / (defense + 110.0),
		"defense": defense,
		"crit_mult": 1.5 + 0.02 * (float(a.crit) + bonus.crit),
		"resist": float(a.resist) * 3.0 + bonus.resist,
		"block_eff": block_eff,
		"element": weapon.get("element"),
		"weapon_cls": weapon.get("cls", "sword"),
		# not read by the duel: what the equipment screens say about how the numbers above came to be
		"burden": burden, "weights": weights, "sets": sets, "unmet": unmet_ids,
	}
