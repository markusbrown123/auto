class_name Stats
extends RefCounted
## Derives combat numbers from a save profile (attributes + equipped gear).

const MAX_UPGRADE := 5

static func xp_for_level(level: int) -> int:
	return int(120.0 * pow(level, 1.6))

static func upgrade_cost(it: Dictionary, level: int) -> Dictionary:
	var rank: int = ["common", "uncommon", "rare", "epic", "legendary"].find(it.get("rarity", "common"))
	return {"gold": (120 + rank * 110) * (level + 1), "shards": (level + 1) * (1 + rank / 2)}

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
	return out

static func compute(profile: Dictionary, items: Dictionary, classes: Dictionary) -> Dictionary:
	var a: Dictionary = profile.attrs
	var eq: Dictionary = profile.equipped
	var up: Dictionary = profile.get("upgrades", {})
	var bonus := {"defense": 0.0, "hp": 0.0, "stamina": 0.0, "strength": 0.0, "dex": 0.0, "crit": 0.0, "resist": 0.0}
	var block_eff := 0.0
	var weapon: Dictionary = {}
	for slot in eq:
		var id = eq[slot]
		if id == null or not items.has(id):
			continue
		var it: Dictionary = items[id]
		var lvl: int = int(up.get(id, 0))
		if slot == "weapon":
			weapon = it
			bonus.crit += float(it.get("crit", 0))
			continue
		for k in bonus:
			var v := float(it.get(k, 0))
			bonus[k] += v * (1.0 + 0.1 * lvl) if k == "defense" else v
		if slot == "shield":
			block_eff = float(it.get("block", 0)) + 0.03 * lvl
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
	return {
		"max_hp": 100.0 + 12.0 * float(a.health) + bonus.hp,
		"max_stamina": 100.0 + 6.0 * endurance + bonus.stamina,
		"stamina_regen": 26.0 + 0.8 * endurance,
		"attack": wdmg * (1.0 + 0.025 * scale),
		"swing_time": float(cls.swing),
		"swing_cost": float(cls.stamina),
		"mitigation": defense / (defense + 110.0),
		"defense": defense,
		"crit_mult": 1.5 + 0.02 * (float(a.crit) + bonus.crit),
		"resist": float(a.resist) * 3.0 + bonus.resist,
		"block_eff": block_eff,
		"element": weapon.get("element"),
		"weapon_cls": weapon.get("cls", "sword"),
	}
