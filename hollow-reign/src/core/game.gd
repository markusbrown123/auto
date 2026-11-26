extends Node
## Persistent profile, save/load, progression rules and the current run.

signal profile_changed

const SAVE_PATH := "user://save.json"
const SAVE_TMP := "user://save.tmp"
const SAVE_BAK := "user://save.bak"
const SETTINGS_PATH := "user://settings.json"
const SAVE_VERSION := 2           # 0: no version field · 1: flat lists · 2: per-item records, materials, cosmetics, reward state
const SLOT_COUNT := 3          # slot 1 keeps the original file names, so an old single save simply is slot 1
const LORE_FOR_DIVIDE := 30   # records needed before the Crown can be divided

var profile: Dictionary = {}
var run: Dictionary = {}          # {region, stage, hp, found:[...]} — reset on death
var settings: Dictionary = {
	"quality": 1, "fps": 60, "master": 1.0, "music": 0.8, "dialogue": 1.0, "combat": 1.0, "ambience": 1.0, "haptics": true,
	"haptic_strength": 1.0, "swipe_sens": 1.0, "sub_size": 1, "sub_bg": true, "reduce_motion": false, "chatter": true,
	"shake": 1.0, "assist": false, "hints": true, "reduce_flash": false, "cine": false, "cine_road": false, "pad_opacity": 0.2,
}
var rng := RandomNumberGenerator.new()
var just_died := false         # set on death, consumed by the sanctuary
var save_dir_override := ""   # tests point this at a temp location
var slot := 1                  # the save slot the profile in memory belongs to


func _ready() -> void:
	rng.randomize()
	load_settings()
	apply_settings()
	apply_subtitles.call_deferred()

# ================================================================ profile
func default_profile() -> Dictionary:
	return {
		"version": SAVE_VERSION, "level": 1, "xp": 0, "attr_points": 0,
		"attrs": {"health": 5, "strength": 5, "dex": 5, "endurance": 5, "defense": 2, "crit": 0, "resist": 0},
		"gold": 0, "shards": 0,
		"inventory": ["w_rusted_sword", "s_plank", "a_worn_helm", "a_worn_chest", "a_worn_gauntlets", "a_worn_legs"],
		"equipped": {"weapon": "w_rusted_sword", "shield": "s_plank", "helm": "a_worn_helm", "chest": "a_worn_chest",
			"gauntlets": "a_worn_gauntlets", "legs": "a_worn_legs", "ring": null, "relic": null,
			"shoulders": null, "boots": null, "offhand": null},
		"upgrades": {}, "mastery": {}, "mastered": [],
		"flags": {}, "defeated": {}, "cleared": [], "endings": [], "ng": 0, "deaths": 0, "heraldry": "#3d0f0f",
		"tutorial_done": false, "playtime": 0.0, "body": "m", "combos": ["double_slash"], "combo_uses": {},
		"lore": [], "quests_done": [], "heard": [],
		"favourites": [], "inv_sort": "equipped", "mastery_taught": {},
		"name": "", "last_played": 0.0,
		# equipment progression (save version 2). In memory the per-item state lives in the lists above and the two
		# sets below; on disk it is one record per item (see _pack). Cosmetics never touch a statistic.
		"materials": {}, "discovered": {}, "seen": {}, "sold": [], "challenges_done": [],
		"mods": {}, "edge": {},     # weapon mods {id: {grip, ore, ore_id}} (blade tier is `upgrades`) and sharpened edges {id: fights left}
		"cosmetics": {}, "rewards": {"seed": 0, "pity": 0, "recent": [], "cores": {}},
		# secrets, side missions and completion (src/core/secrets.gd). Additive: a save without them is credited by Secrets.backfill
		"secrets": {}, "secret_lore": [], "feats": {}, "completion": Secrets.blank(),
	}

func has_save() -> bool:
	for n in range(1, SLOT_COUNT + 1):
		if slot_exists(n):
			return true
	return false

# ================================================================ save slots
## File of a slot: "json", "bak" or "tmp". Slot 1 is save.json, the others save2.json, save3.json.
func slot_file(n: int, ext: String = "json") -> String:
	return _p("user://save%s.%s" % ["" if n <= 1 else str(n), ext])

func slot_exists(n: int) -> bool:
	return FileAccess.file_exists(slot_file(n)) or FileAccess.file_exists(slot_file(n, "bak"))

## The stored profile of a slot (main file, else its backup), migrated; empty if there is none.
func _read_slot(n: int) -> Dictionary:
	for ext: String in ["json", "bak"]:
		var p := slot_file(n, ext)
		if not FileAccess.file_exists(p):
			continue
		var v = _parse(FileAccess.get_file_as_string(p))
		if v is Dictionary and v.has("attrs") and v.has("equipped"):
			var out := _migrate(v)
			if float(out.last_played) <= 0.0:
				out.last_played = float(FileAccess.get_modified_time(p))
			return out
	return {}

## What the slot list shows. Empty dictionary for an empty slot.
func slot_summary(n: int) -> Dictionary:
	var p := _read_slot(n)
	if p.is_empty():
		return {}
	var chapter := furthest_region(p)
	var weapon: Dictionary = Db.item(str(p.equipped.weapon)) if p.equipped.weapon != null else {}
	return {"slot": n, "body": str(p.body), "name": str(p.name), "level": int(p.level), "chapter": str(chapter.name), "chapter_id": str(chapter.id),
		"playtime": float(p.playtime), "last_played": float(p.last_played), "weapon": str(weapon.get("name", "Unarmed")),
		"ng": int(p.ng), "heraldry": str(p.heraldry), "cleared": p.cleared.size()}

## The furthest region a profile has reached (unlocked), in the order the regions are listed.
func furthest_region(p: Dictionary = profile) -> Dictionary:
	var out: Dictionary = Db.regions[0]
	for r in Db.regions:
		if r.requires == null or p.get("cleared", []).has(r.requires):
			out = r
	return out

## Most recently played slot, or 0 when nothing is saved.
func latest_slot() -> int:
	var best := 0
	var best_t := -1.0
	for n in range(1, SLOT_COUNT + 1):
		var p := _read_slot(n)
		if not p.is_empty() and float(p.last_played) > best_t:
			best = n
			best_t = float(p.last_played)
	return best

## First empty slot, or 0 when all are used.
func free_slot() -> int:
	for n in range(1, SLOT_COUNT + 1):
		if not slot_exists(n):
			return n
	return 0

func load_slot(n: int) -> bool:
	if n < 1 or n > SLOT_COUNT:
		return false
	var keep := slot
	slot = n
	if load_game():
		return true
	slot = keep
	return false

func delete_slot(n: int) -> void:
	for ext: String in ["json", "bak", "tmp"]:
		if FileAccess.file_exists(slot_file(n, ext)):
			DirAccess.remove_absolute(slot_file(n, ext))
	if n == slot:
		profile = {}
		run = {}

func _process(delta: float) -> void:
	if not profile.is_empty():
		profile.playtime = float(profile.get("playtime", 0.0)) + delta / maxf(Engine.time_scale, 0.01)

func _p(path: String) -> String:
	return path if save_dir_override == "" else save_dir_override + "/" + path.get_file()

## `weapon` is the blade the knight wakes holding: one of the four basic swords (Db.equipment.basic_swords). Anything
## else, or nothing, gives the Wayfarer's Blade. The other three are in Orren's first stock.
func new_game(heraldry: String = "#3d0f0f", body: String = "m", weapon: String = "w_rusted_sword") -> void:
	profile = default_profile()
	weapon = Db.canon(weapon)
	if Db.equipment.basic_swords.has(weapon):
		profile.inventory[profile.inventory.find("w_rusted_sword")] = weapon
		profile.equipped.weapon = weapon
	profile.heraldry = heraldry
	profile.body = body
	profile.rewards.seed = rng.randi()
	for id: String in profile.inventory:
		profile.discovered[id] = true
		profile.seen[id] = true
	run = {}
	save()
	profile_changed.emit()

func save() -> bool:
	if profile.is_empty():
		return false
	profile["last_played"] = Time.get_unix_time_from_system()
	Secrets.sync(profile)          # a completion milestone reached since the last save is paid here, once
	var f := FileAccess.open(slot_file(slot, "tmp"), FileAccess.WRITE)
	if f == null:
		push_warning("save failed: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(_pack(profile)))
	f.close()
	var d := DirAccess.open(slot_file(slot).get_base_dir())
	if d == null:
		return false
	# keep the previous good save as a backup, then swap the new one in
	if d.file_exists(slot_file(slot).get_file()):
		d.rename(slot_file(slot).get_file(), slot_file(slot, "bak").get_file())
	return d.rename(slot_file(slot, "tmp").get_file(), slot_file(slot).get_file()) == OK

func load_game() -> bool:
	var v := _read_slot(slot)
	if v.is_empty():
		return false
	profile = v
	run = {}
	profile_changed.emit()
	return true

func _parse(txt: String) -> Variant:
	var j := JSON.new()
	return j.data if j.parse(txt) == OK else null

## Per-item fields that are lists or dictionaries in memory and one record per item on disk.
const _ITEM_FIELDS := ["inventory", "upgrades", "mastery", "mastered", "favourites", "mastery_taught", "discovered", "seen", "mods", "edge"]

## The progress record of one item: what is known and held of it, apart from its definition in the data.
func item_record(id: String, p: Dictionary = profile) -> Dictionary:
	return {"owned": p.get("inventory", []).has(id), "discovered": p.get("discovered", {}).has(id) or p.get("inventory", []).has(id),
		"seen": p.get("seen", {}).has(id), "level": int(p.get("upgrades", {}).get(id, 0)), "mastery_xp": int(p.get("mastery", {}).get(id, 0)),
		"mastered": p.get("mastered", []).has(id), "favourite": p.get("favourites", []).has(id)}

## The profile as it is written to disk: everything as it is, except that the per-item lists become
## `items: {id: {owned, discovered, seen, level, mastery_xp, mastered, favourite, order, taught}}`.
## `equipped` is the loadout by slot. Ids the data does not know are written like any other.
func _pack(p: Dictionary) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	var ids: Array = []
	for k: String in _ITEM_FIELDS:
		var src = p.get(k, [])
		for id in (src.keys() if src is Dictionary else src):
			if not ids.has(str(id)):
				ids.append(str(id))
		if k != "mastered" and k != "favourites":     # two short ordered lists: kept as they are, and mirrored in the records
			out.erase(k)
	var recs := {}
	for id: String in ids:
		var r := item_record(id, p)
		r["order"] = p.get("inventory", []).find(id)
		if p.get("mastery_taught", {}).has(id):
			r["taught"] = p.mastery_taught[id]
		if p.get("mods", {}).has(id):
			r["mods"] = p.mods[id]
		if int(p.get("edge", {}).get(id, 0)) > 0:
			r["edge"] = int(p.edge[id])
		recs[id] = r
	out["items"] = recs
	out["version"] = SAVE_VERSION
	return out

## The reverse of _pack, in place. A profile that is already in the in-memory shape is left alone.
func _unpack(v: Dictionary) -> void:
	if not (v.get("items") is Dictionary):
		return
	var recs: Dictionary = v.items
	v.erase("items")
	var inv: Array = v.get("inventory", []) if v.get("inventory") is Array else []
	var rows: Array = []
	for id: String in recs:
		var r: Dictionary = recs[id] if recs[id] is Dictionary else {}
		if r.get("owned", false) and not inv.has(id):
			rows.append([int(r.get("order", 1 << 20)), rows.size(), id])
	rows.sort_custom(func(a, b): return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	for row: Array in rows:
		inv.append(row[2])
	v["inventory"] = inv
	for k: String in ["upgrades", "mastery", "mastery_taught", "discovered", "seen", "mods", "edge"]:
		if not (v.get(k) is Dictionary):
			v[k] = {}
	for k: String in ["mastered", "favourites"]:
		if not (v.get(k) is Array):
			v[k] = []
	for id: String in recs:
		var r: Dictionary = recs[id] if recs[id] is Dictionary else {}
		if int(r.get("level", 0)) > 0:
			v.upgrades[id] = int(r.level)
		if int(r.get("mastery_xp", 0)) > 0:
			v.mastery[id] = int(r.mastery_xp)
		if r.get("mastered", false) and not v.mastered.has(id):
			v.mastered.append(id)
		if r.get("favourite", false) and not v.favourites.has(id):
			v.favourites.append(id)
		if r.has("taught"):
			v.mastery_taught[id] = r.taught
		if r.get("discovered", false):
			v.discovered[id] = true
		if r.get("seen", false):
			v.seen[id] = true
		if r.get("mods") is Dictionary:
			v.mods[id] = r.mods
		if int(r.get("edge", 0)) > 0:
			v.edge[id] = int(r.edge)

## Brings a stored profile of any earlier shape up to the current one. Safe to run on its own output; nothing a
## save holds is dropped, including ids the data no longer (or does not yet) know.
func _migrate(v: Dictionary) -> Dictionary:
	var from: int = int(v.get("version", 0))
	_unpack(v)
	if not (v.get("completion") is Dictionary):
		Secrets.backfill(v)        # a journey from before secrets and completion: credit the roads it has walked
	var base := default_profile()
	for k in base:
		if not v.has(k):
			v[k] = base[k]
	for k in base.attrs:
		if not v.attrs.has(k):
			v.attrs[k] = base.attrs[k]
	for k in base.equipped:
		if not v.equipped.has(k):
			v.equipped[k] = null
	for k in base.rewards:
		if not v.rewards.has(k):
			v.rewards[k] = base.rewards[k]
	# JSON turns ints into floats; restore the integer fields
	for k in ["level", "xp", "attr_points", "gold", "shards", "ng", "deaths"]:
		v[k] = int(v[k])
	for k in v.attrs:
		v.attrs[k] = int(v.attrs[k])
	for d in ["upgrades", "mastery", "defeated", "combo_uses", "materials", "edge"]:
		for k in v[d]:
			v[d][k] = int(v[d][k])
	for k in v.mods:
		for t in ["grip", "ore"]:
			v.mods[k][t] = int(v.mods[k].get(t, 0))
	v.rewards.seed = int(v.rewards.seed)
	v.rewards.pity = int(v.rewards.pity)
	for k in v.rewards.cores:
		v.rewards.cores[k] = int(v.rewards.cores[k])
	# ids that were renamed resolve to the stored id (an id held under both names keeps the larger progress)
	for k: String in ["inventory", "mastered", "favourites", "sold"]:
		var arr: Array = []
		for id in v[k]:
			if not arr.has(Db.canon(str(id))):
				arr.append(Db.canon(str(id)))
		v[k] = arr
	for k: String in ["upgrades", "mastery", "mastery_taught", "discovered", "seen"]:
		for id in v[k].keys():
			var c := Db.canon(str(id))
			if c != str(id):
				if not v[k].has(c) or (v[k][c] is int and v[k][c] < v[k][id]):
					v[k][c] = v[k][id]
				v[k].erase(id)
	for slot_name in v.equipped:
		if v.equipped[slot_name] != null:
			v.equipped[slot_name] = Db.canon(str(v.equipped[slot_name]))
	if from < 2:
		# what an older journey already holds is known and has been looked at
		for id in v.inventory:
			v.discovered[id] = true
			v.seen[id] = true
		# guardians already ended are owed the core they would give today
		for foe_id in v.defeated:
			if Db.foes.has(foe_id) and Db.foes[foe_id].boss and not v.rewards.cores.has(foe_id):
				v.rewards.cores[foe_id] = v.ng + 1
				v.materials["m_core"] = int(v.materials.get("m_core", 0)) + 1
		# a weapon's old upgrade level is its blade tier now; it is given the ore that level needs, so nothing paid for is lost
		for id in v.upgrades:
			var wit: Dictionary = Db.item(str(id))
			if wit.get("slot", "") == "weapon" and not v.mods.has(id):
				var ore := 0
				while ore < 3 and int(Db.equipment.mods.ore.blade_cap[ore]) < v.upgrades[id]:
					ore += 1
				if ore > 0:
					v.mods[id] = {"grip": 0, "ore": ore, "ore_id": str(wit.get("mat", "m_iron")) if ore >= 2 else ""}
		if v.rewards.seed == 0:
			v.rewards.seed = hash("%s|%s|%d|%d" % [str(v.heraldry), str(v.name), v.level, v.gold])
	# a weapon that needs both hands leaves none for a shield (Oathbreaker became a greatsword); the shield stays owned
	var w: Dictionary = Db.item(str(v.equipped.weapon)) if v.equipped.weapon != null else {}
	if not w.is_empty() and Db.classes[w.cls].two_handed:
		v.equipped.shield = null
	# an appearance override must point at an owned item of the same slot
	for slot_name in v.cosmetics:
		var look: String = str(v.cosmetics[slot_name].get("look_as", "")) if v.cosmetics[slot_name] is Dictionary else ""
		if look != "" and (not v.inventory.has(look) or Db.item(look).get("slot", "") != slot_name):
			v.cosmetics[slot_name].erase("look_as")
	Secrets.tidy(v)
	for foe_id in v.defeated:
		if not Db.foes.has(foe_id):
			Secrets.challenger(str(foe_id))      # a hidden challenger this journey has beaten: known again
	v.version = SAVE_VERSION
	return v

func stats() -> Dictionary:
	return Stats.compute(profile, Db.items, Db.classes)

# ================================================================ progression
func grant_xp(amount: int) -> int:
	profile.xp += amount
	var gained := 0
	while profile.xp >= Stats.xp_for_level(profile.level):
		profile.xp -= Stats.xp_for_level(profile.level)
		profile.level += 1
		profile.attr_points += 2
		gained += 1
	return gained

func spend_attr(attr: String) -> bool:
	if profile.attr_points <= 0 or not profile.attrs.has(attr):
		return false
	profile.attr_points -= 1
	profile.attrs[attr] += 1
	save()
	profile_changed.emit()
	return true

## Records that a combo was performed. Returns true the first time, when it is newly discovered.
func use_combo(id: String) -> bool:
	if not Db.combo_by_id.has(id):
		return false
	profile.combo_uses[id] = int(profile.combo_uses.get(id, 0)) + 1
	if profile.combos.has(id):
		return false
	profile.combos.append(id)
	save()
	return true

func owns(id: String) -> bool:
	return profile.inventory.has(Db.canon(id))

func grant_item(id: String) -> bool:
	id = Db.canon(id)
	if owns(id) or not Db.items.has(id):
		return false
	profile.inventory.append(id)
	profile.discovered[id] = true
	profile.sold.erase(id)
	return true

## Puts an owned item on. Changes that item's slot and nothing else, except that a two-handed weapon and a shield
## cannot be worn together. An unmet requirement does not refuse the item: it costs (see requirement_text).
func equip(id: String) -> bool:
	id = Db.canon(id)
	var it: Dictionary = Db.item(id)
	if not owns(id) or it.is_empty() or not profile.equipped.has(it.slot):
		return false
	profile.equipped[it.slot] = id
	profile.seen[id] = true
	# two-handed weapons leave no hand for a shield
	if it.slot == "weapon" and Db.classes[it.cls].two_handed:
		profile.equipped.shield = null
	if it.slot == "shield":
		var w = profile.equipped.weapon
		if w != null and Db.classes[Db.item(w).cls].two_handed:
			return_to_one_handed()
	save()
	profile_changed.emit()
	return true

func return_to_one_handed() -> void:
	for id in profile.inventory:
		var it: Dictionary = Db.item(id)
		if it.get("slot", "") == "weapon" and not Db.classes[it.cls].two_handed:
			profile.equipped.weapon = id
			return

func unequip(slot: String) -> void:
	if slot == "weapon":
		return
	profile.equipped[slot] = null
	save()
	profile_changed.emit()

func upgrade_level(id: String) -> int:
	return int(profile.upgrades.get(id, 0))

## Why this item cannot be upgraded now, or "" when it can. For a weapon "upgrade" means the next blade tier, taking
## the ore step with it when the blade has gone as far as its ore allows (see mod() for the tracks one at a time).
func upgrade_block(id: String) -> String:
	var it: Dictionary = Db.item(id)
	if it.is_empty() or not owns(id):
		return "Not yours"
	if not it.has("upgrade"):
		return "Cannot be worked"       # rings and relics: an upgrade would change nothing the duel reads
	var lvl := upgrade_level(id)
	if lvl >= int(it.upgrade.max):
		return "Perfected"
	return _cost_block(upgrade_cost(id))

## What Game.upgrade(id) would charge now: {gold, shards, materials}.
func upgrade_cost(id: String) -> Dictionary:
	var it: Dictionary = Db.item(id)
	if it.get("slot", "") != "weapon" or not it.has("mods"):
		return Stats.upgrade_cost(it, upgrade_level(id))
	var c := mod_cost(id, "blade")
	if upgrade_level(id) >= int(weapon_mods(id).caps.blade):
		c = _sum_cost(c, mod_cost(id, "ore", str(it.get("mat", "m_iron"))))
	return c

func _sum_cost(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {"gold": int(a.get("gold", 0)) + int(b.get("gold", 0)), "shards": int(a.get("shards", 0)) + int(b.get("shards", 0)), "materials": a.get("materials", {}).duplicate()}
	for m: String in b.get("materials", {}):
		out.materials[m] = int(out.materials.get(m, 0)) + int(b.materials[m])
	return out

func _cost_block(c: Dictionary) -> String:
	if profile.gold < int(c.get("gold", 0)):
		return "Not enough gold"
	if profile.shards < int(c.get("shards", 0)):
		return "Not enough shards"
	for m: String in c.get("materials", {}):
		if material_count(m) < int(c.materials[m]):
			return "Needs %s" % Db.material_name(m)
	return ""

func _pay(c: Dictionary) -> void:
	profile.gold -= int(c.get("gold", 0))
	profile.shards -= int(c.get("shards", 0))
	for m: String in c.get("materials", {}):
		profile.materials[m] = material_count(m) - int(c.materials[m])

func can_upgrade(id: String) -> bool:
	return upgrade_block(id) == ""

func upgrade(id: String) -> bool:
	id = Db.canon(id)
	if not can_upgrade(id):
		return false
	var it: Dictionary = Db.item(id)
	if it.slot == "weapon" and it.has("mods") and upgrade_level(id) >= int(weapon_mods(id).caps.blade):
		_pay(mod_cost(id, "ore", str(it.get("mat", "m_iron"))))
		_raise_ore(id, str(it.get("mat", "m_iron")))
	_pay(mod_cost(id, "blade") if it.slot == "weapon" and it.has("mods") else Stats.upgrade_cost(it, upgrade_level(id)))
	profile.upgrades[id] = upgrade_level(id) + 1
	save()
	profile_changed.emit()
	return true

# ---------------------------------------------------------------- weapon mods: blade, grip, ore, sharpen
## Where a weapon stands on its four tracks:
##   {blade, grip, ore, ore_id, edge (fights of keen edge left), caps: {blade, grip}, max: {blade, grip, ore},
##    visual: {blade_tier 0-3, grip_tier 0-3, ore: "iron"|"steel"|<material id>|"cored", ore_id, keen}}
## `visual` is for whoever draws the sword; it changes no number.
func weapon_mods(id: String, p: Dictionary = profile) -> Dictionary:
	id = Db.canon(id)
	var r: Dictionary = Db.equipment.mods
	var m: Dictionary = p.get("mods", {}).get(id, {})
	var blade: int = int(p.get("upgrades", {}).get(id, 0))
	var ore: int = int(m.get("ore", 0))
	var ore_id: String = str(m.get("ore_id", ""))
	var edge: int = int(p.get("edge", {}).get(id, 0))
	return {"blade": blade, "grip": int(m.get("grip", 0)), "ore": ore, "ore_id": ore_id, "edge": edge,
		"caps": {"blade": int(r.ore.blade_cap[clampi(ore, 0, 3)]), "grip": int(r.ore.grip_cap[clampi(ore, 0, 3)])},
		"max": {"blade": int(r.blade.tiers), "grip": int(r.grip.tiers), "ore": int(r.ore.tiers)},
		"visual": {"blade_tier": mini(3, (blade * 3 + 4) / 5), "grip_tier": int(m.get("grip", 0)),
			"ore": ["iron", "steel", ore_id, "cored"][clampi(ore, 0, 3)], "ore_id": ore_id, "keen": edge > 0}}

## The cost of the next step on a track: {gold, shards, materials}. For the second ore tier `ore_id` is the region
## material the blade is reforged in (Db.equipment.mods.ores); the third keeps it and asks for a guardian core.
func mod_cost(id: String, track: String, ore_id: String = "") -> Dictionary:
	var it: Dictionary = Db.item(id)
	var w := weapon_mods(id)
	var out := {"gold": 0, "shards": 0, "materials": {}}
	if not it.has("mods"):
		return out
	var c: Dictionary = {}
	match track:
		"blade":
			if w.blade < it.upgrade.costs.size():
				c = it.upgrade.costs[w.blade]
		"grip":
			if w.grip < it.mods.grip.size():
				c = it.mods.grip[w.grip]
		"ore":
			if w.ore < it.mods.ore.size():
				c = it.mods.ore[w.ore]
		"sharpen":
			c = it.mods.sharpen
	out.gold = int(c.get("gold", 0))
	out.shards = int(c.get("shards", 0))
	for m: String in c.get("materials", {}):
		out.materials[ore_id if m == "ore" else m] = int(c.materials[m])
	return out

## Why the next step on a track cannot be taken, or "" when it can.
func mod_block(id: String, track: String, ore_id: String = "") -> String:
	id = Db.canon(id)
	var it: Dictionary = Db.item(id)
	if it.is_empty() or not owns(id):
		return "Not yours"
	if it.slot != "weapon" or not it.has("mods"):
		return "Not a weapon"
	var w := weapon_mods(id)
	match track:
		"blade":
			if w.blade >= int(w.max.blade):
				return "Perfected"
			if w.blade >= int(w.caps.blade):
				return "Needs better ore"
		"grip":
			if w.grip >= int(w.max.grip):
				return "Perfected"
			if w.grip >= int(w.caps.grip):
				return "Needs better ore"
		"ore":
			if w.ore >= int(w.max.ore):
				return "Perfected"
			if w.ore == 1 and not Db.equipment.mods.ores.has(ore_id):
				return "Choose an ore"
		"sharpen":
			if w.edge > 0:
				return "Still keen"
		_:
			return "No such work"
	return _cost_block(mod_cost(id, track, ore_id))

func can_mod(id: String, track: String, ore_id: String = "") -> bool:
	return mod_block(id, track, ore_id) == ""

func _raise_ore(id: String, ore_id: String) -> void:
	var m: Dictionary = profile.mods.get(id, {"grip": 0, "ore": 0, "ore_id": ""})
	if int(m.get("ore", 0)) == 1:
		m["ore_id"] = ore_id
	m["ore"] = int(m.get("ore", 0)) + 1
	profile.mods[id] = m

## Takes the next step on a track, paying for it. Tracks: "blade", "grip", "ore", "sharpen".
func mod(id: String, track: String, ore_id: String = "") -> bool:
	id = Db.canon(id)
	if not can_mod(id, track, ore_id):
		return false
	_pay(mod_cost(id, track, ore_id))
	match track:
		"blade":
			profile.upgrades[id] = upgrade_level(id) + 1
		"grip":
			var m: Dictionary = profile.mods.get(id, {"grip": 0, "ore": 0, "ore_id": ""})
			m["grip"] = int(m.get("grip", 0)) + 1
			profile.mods[id] = m
		"ore":
			_raise_ore(id, ore_id)
		"sharpen":
			profile.edge[id] = int(Db.equipment.mods.sharpen.fights)
	save()
	profile_changed.emit()
	return true

func sharpen(id: String) -> bool:
	return mod(id, "sharpen")

## What the next step on a track would do to the duel's numbers, without doing it: compare()-style rows that change.
## Only meaningful for the equipped weapon (others give []).
func mod_preview(id: String, track: String, ore_id: String = "") -> Array:
	id = Db.canon(id)
	if not is_equipped(id) or Db.item(id).get("slot", "") != "weapon":
		return []
	var trial: Dictionary = profile.duplicate(true)
	var m: Dictionary = trial.mods.get(id, {"grip": 0, "ore": 0, "ore_id": ""})
	match track:
		"blade": trial.upgrades[id] = int(trial.upgrades.get(id, 0)) + 1
		"grip": m["grip"] = int(m.get("grip", 0)) + 1
		"ore":
			if int(m.get("ore", 0)) == 1:
				m["ore_id"] = ore_id
			m["ore"] = int(m.get("ore", 0)) + 1
		"sharpen": trial.edge[id] = 1
	trial.mods[id] = m
	return _rows(stats(), Stats.compute(trial, Db.items, Db.classes)).filter(func(r): return int(r.better) != 0)

## A fight is over, won or lost: the equipped weapon's keen edge is one fight nearer to dull.
func _dull() -> void:
	var w = profile.equipped.get("weapon")
	if w != null and int(profile.edge.get(w, 0)) > 0:
		profile.edge[w] = int(profile.edge[w]) - 1
		if profile.edge[w] <= 0:
			profile.edge.erase(w)

## How far along the road Orren's stock has come: regions cleared, or everything once the world has turned over.
func shop_progress() -> int:
	return 99 if int(profile.ng) > 0 else profile.cleared.size()

## Has the road been walked far enough for Orren to stock this (a guardian ended, or enough regions cleared)?
func shop_unlocked(it: Dictionary) -> bool:
	var u: Dictionary = it.get("unlock", {})
	if profile.get("completion", {}).get("shop", []).has(it.get("id", "")):
		return true                 # a side mission's reward: Orren stocks it whatever the road says
	if u.has("boss"):
		return profile.defeated.has(u.boss)
	return int(u.get("cleared", 0)) <= shop_progress()

func _in_stock(it: Dictionary) -> bool:
	return int(it.get("price", 0)) > 0 and int(it.get("ng_min", 0)) <= int(profile.ng) and shop_unlocked(it)

## A locked shop entry the player may already see: its guardian's region is open, or it is the next step of stock.
func _shop_visible(it: Dictionary) -> bool:
	if int(it.get("price", 0)) <= 0 or int(it.get("ng_min", 0)) > int(profile.ng):
		return false
	var u: Dictionary = it.get("unlock", {})
	if u.has("boss"):
		return region_unlocked(str(Db.foes[u.boss].region))
	return int(u.get("cleared", 0)) <= shop_progress() + 1

## The whole shop as a screen wants it: what is for sale now and what is visibly locked, cheapest first.
## Each entry: {id, item, price, available, affordable, unlock_text ("" when available), slot}. Owned items are left out.
func shop_catalog() -> Array:
	var out: Array = []
	for it in Db.item_list:
		if owns(it.id) or not _shop_visible(it):
			continue
		var open := _in_stock(it)
		out.append({"id": it.id, "item": it, "price": int(it.price), "available": open, "affordable": open and profile.gold >= int(it.price),
			"unlock_text": "" if open else str(it.get("unlock_text", "")), "slot": it.slot})
	out.sort_custom(func(a, b): return a.price < b.price if a.price != b.price else str(a.id) < str(b.id))
	return out

## What the item costs to buy now: its price while Orren stocks it, the buy-back price for a one-of-a-kind item
## that was sold to him, 0 when it is not for sale.
func buy_price(id: String) -> int:
	var it: Dictionary = Db.item(id)
	if it.is_empty():
		return 0
	if _in_stock(it):
		return int(it.price)
	if profile.sold.has(Db.canon(id)):
		return int(ceil(sell_price(id) * float(Db.equipment.buyback_rate)))
	return 0

func buy(id: String) -> bool:
	id = Db.canon(id)
	var cost := buy_price(id)
	if owns(id) or cost <= 0 or profile.gold < cost:
		return false
	profile.gold -= cost
	grant_item(id)
	save()
	profile_changed.emit()
	return true

## What Orren has for sale: his stock for how far the road has been walked, then anything one-of-a-kind that was
## sold to him (each a copy of the definition with `price` set to the buy-back price and `buyback: true`).
func shop_stock() -> Array:
	var out: Array = []
	for it in Db.item_list:
		if _in_stock(it) and not owns(it.id):
			out.append(it)
	for id: String in profile.sold:
		var it: Dictionary = Db.item(id)
		if it.is_empty() or owns(id) or _in_stock(it):
			continue
		var copy: Dictionary = it.duplicate()
		copy["price"] = buy_price(id)
		copy["buyback"] = true
		out.append(copy)
	return out

# ================================================================ runs
func region_unlocked(id: String) -> bool:
	var req = Db.region_by_id[id].requires
	return req == null or profile.cleared.has(req)

func shortcut_open(id: String) -> bool:
	return profile.flags.has(Db.region_by_id[id].shortcut.flag)

func start_run(region_id: String, use_shortcut: bool = false) -> void:
	var st := stats()
	var stage := 0
	if use_shortcut and shortcut_open(region_id):
		stage = int(Db.region_by_id[region_id].shortcut.stage)
	run = {"region": region_id, "stage": stage, "hp": st.max_hp, "found": [], "xp": 0, "gold": 0, "seed": rng.randi()}

func run_region() -> Dictionary:
	return Db.region_by_id[run.region]

func run_stage() -> Dictionary:
	return run_region().stages[run.stage]

func stage_options() -> Array:
	var out: Array = []
	for o in run_stage().options:
		if o.has("needs") and not profile.flags.has(o.needs):
			continue
		if o.type == "treasure" and profile.flags.has(_chest_flag(o)) and out.size() > 0:
			continue   # already looted; hide unless it is the only way on
		if o.type == "lever" and profile.flags.has(o.flag):
			continue
		if o.has("foes"):
			# this stop draws from a pool: fixed for the run, different on the next
			o = o.duplicate()
			var pool: Array = o.foes
			o.foe = pool[absi(hash("%d|%d|%s" % [int(run.get("seed", 0)), int(run.stage), o.label])) % pool.size()]
		out.append(o)
	if out.is_empty():
		out.append({"type": "pass", "label": "Press On", "hint": "Nothing more to find here."})
	return out

func _chest_flag(o: Dictionary) -> String:
	return "chest_%s_%d_%s" % [run.region, run.stage, o.label]

func advance_stage() -> bool:
	Secrets.mark_stop(str(run.region), int(run.stage), profile)
	run.stage += 1
	return run.stage < run_region().stages.size()

## Open a treasure node. Returns what was found.
func open_treasure(o: Dictionary) -> Dictionary:
	var out := {"items": [], "gold": int(o.get("gold", 0)), "shards": int(o.get("shards", 0))}
	var flag := _chest_flag(o)
	if profile.flags.has(flag):
		out.gold = int(out.gold / 4)
		out.shards = 0
	else:
		for id in o.get("items", []):
			if grant_item(id):
				out.items.append(id)
		profile.flags[flag] = true
	profile.gold += out.gold
	profile.shards += out.shards
	run.found.append_array(out.items)
	save()
	return out

## Loose coin found by a sharp eye on the road. Returns the amount.
func take_pouch() -> int:
	var tier: int = Db.regions.find(run_region()) + 1
	var amount: int = rng.randi_range(8, 16) * tier * (1 + int(profile.ng))
	profile.gold += amount
	if not run.is_empty():
		run.gold += amount
	save()
	return amount

func pull_lever(o: Dictionary) -> void:
	profile.flags[o.flag] = true
	save()

func rest_at_shrine() -> float:
	var st := stats()
	var heal: float = st.max_hp * 0.6
	run.hp = minf(st.max_hp, float(run.hp) + heal)
	return heal

## Apply the rewards for defeating a foe. Returns the reward result (see Rewards) for the victory screen: the keys
## the first overlay reads (xp, gold, shards, items, levels, mastered, first) and the fuller ones a reveal screen
## wants (items_new, materials, mastery_ups, unlocks, discoveries, compensation, repeat, pity).
func on_victory(foe_id: String, hp_left: float) -> Dictionary:
	var foe: Dictionary = Db.foes[foe_id]
	var out := Rewards.roll(profile, foe_id)
	var st: Dictionary = profile.rewards
	profile.defeated[foe_id] = int(profile.defeated.get(foe_id, 0)) + 1
	st.recent.append(foe_id)
	while st.recent.size() > int(Db.equipment.rewards.window):
		st.recent.pop_front()
	if out.core:
		st.cores[foe_id] = int(profile.ng) + 1
	for id: String in out.items:
		grant_item(id)
	for m: String in out.materials:
		add_material(m, int(out.materials[m]))
	for id: String in out.discoveries:
		profile.discovered[id] = true
	_dull()
	# equipment mastery: fighting with a piece of gear teaches you its weight
	var taught_all: Array = []
	for slot in profile.equipped:
		var id = profile.equipped[slot]
		if id == null or profile.mastered.has(id) or Db.item(id).is_empty():
			continue
		var it: Dictionary = Db.item(id)
		var before := mastery_tier(id)
		profile.mastery[id] = int(profile.mastery.get(id, 0)) + (2 if foe.boss else 1)
		var taught := mastery_unlocks(str(id))
		if taught != "":
			taught_all.append(taught)
		if profile.mastery[id] >= Stats.mastery_needed(it):
			profile.mastered.append(id)
			profile.attr_points += 1
			out.mastered.append(id)
		for tier: int in range(before + 1, mastery_tier(id) + 1):
			var kind: String = _mark_type(it, tier)
			if kind == "":
				continue                # this kind of item has no mark at that point
			out.mastery_ups.append({"id": id, "slot": slot, "tier": tier, "text": mastery_tier_text(it, tier)})
			match kind:
				"combo":
					if taught != "":
						out.unlocks.append({"type": "combo", "id": taught, "item": id})
				"discovery":
					var found := _family_rumour(it)
					if found != "":
						out.discoveries.append(found)
						out.unlocks.append({"type": "discovery", "id": found, "item": id})
				"":
					pass
				_:
					out.unlocks.append({"type": kind, "id": id, "item": id})
	if not taught_all.is_empty():
		out["taught"] = taught_all
	profile.gold += out.gold
	profile.shards += out.shards
	out.levels = grant_xp(out.xp)
	# the dry streak counts wins that gave nothing new to look at
	var fresh: bool = not out.items.is_empty() or not out.discoveries.is_empty() or not out.mastery_ups.is_empty() or out.levels > 0
	st.pity = 0 if fresh else int(st.pity) + 1
	if not run.is_empty():
		run.hp = hp_left
		run.xp += out.xp
		run.gold += out.gold
		run.found.append_array(out.items)
	save()
	profile_changed.emit()
	return out

## What kind of thing the item's mastery mark `tier` opens ("history", "combo", "discovery", "efficiency", "attr_point", "").
func _mark_type(it: Dictionary, tier: int) -> String:
	var at := mastery_threshold(it, tier)
	for m: Dictionary in it.get("mastery", {}).get("marks", []):
		if int(m.at) == at:
			return str(m.type)
	return "attr_point" if tier == 3 else ""

## Wearing a piece long enough brings word of another of its family: the first one not yet known. "" when all are.
func _family_rumour(it: Dictionary) -> String:
	for other: Dictionary in Db.item_list:
		if other.get("family", "") == it.get("family", "-") and Db.ARMOUR_SLOTS.has(other.slot) and not is_discovered(str(other.id)):
			profile.discovered[other.id] = true
			return str(other.id)
	return ""

func complete_region() -> bool:
	var id: String = run.region
	var first: bool = not profile.cleared.has(id)
	if first:
		profile.cleared.append(id)
	Secrets.mark_stop(id, int(run.get("stage", 0)), profile)
	run = {}
	save()
	profile_changed.emit()
	return first

func on_death() -> Dictionary:
	# Everything earned is kept; only the route resets.
	profile.deaths += 1
	just_died = true
	_dull()
	var summary := run.duplicate(true)
	run = {}
	save()
	return summary

func game_complete() -> bool:
	return profile.cleared.has(Db.regions[-1].id)      # the throne; the Roost and the Deep are optional

## The third ending needs the side roads walked: the Devourer ended and the wyrm of the Roost faced,
## and enough of the record recovered to know what is being divided.
func can_divide_crown() -> bool:
	return profile.defeated.has("devourer") and profile.cleared.has("roost") and profile.lore.size() >= LORE_FOR_DIVIDE

# ================================================================ records and tasks
## Grants every record kept at this stop that is not yet held. Returns the newly found entries.
func find_lore(region_id: String, stage: int) -> Array:
	var out: Array = []
	for l in Db.lore:
		if l.region == region_id and int(l.stage) == stage and not profile.lore.has(l.id):
			profile.lore.append(l.id)
			out.append(l)
	if not out.is_empty():
		save()
	return out

## Each condition of a task as [have, need, noun].
func _quest_parts(id: String) -> Array:
	var need: Dictionary = Secrets.quest_def(id).need
	var parts: Array = []
	if need.has("defeated"):
		var n := 0
		var bosses := true
		for f in need.defeated:
			n += 1 if profile.defeated.has(f) else 0
			bosses = bosses and Db.foes[f].boss
		parts.append([n, need.defeated.size(), "guardians" if bosses else "foes"])
	if need.has("cleared"):
		var n := 0
		for r in need.cleared:
			n += 1 if profile.cleared.has(r) else 0
		parts.append([n, need.cleared.size(), "regions"])
	if need.has("lore"):
		parts.append([mini(profile.lore.size(), int(need.lore)), int(need.lore), "records"])
	if need.has("combos"):
		parts.append([mini(profile.combos.size(), int(need.combos)), int(need.combos), "sequences"])
	parts.append_array(Secrets.quest_parts(need, profile))      # what only side missions ask: materials, deeds, secrets
	return parts

func quest_ready(id: String) -> bool:
	if Secrets.quest_def(id).is_empty():
		return false
	for part in _quest_parts(id):
		if part[0] < part[1]:
			return false
	return true

func quest_progress(id: String) -> String:
	if Secrets.quest_def(id).is_empty():
		return ""
	if profile.quests_done.has(id):
		return "Done"
	var bits: Array = []
	for part in _quest_parts(id):
		bits.append("%d / %d %s" % part)
	return "  ·  ".join(bits)

## Pays out a finished task, once.
func claim_quest(id: String) -> bool:
	if profile.quests_done.has(id) or not quest_ready(id):
		return false
	var reward: Dictionary = Secrets.quest_def(id).reward
	Secrets.settle_quest(Secrets.quest_def(id), profile)       # materials handed over; a finish, a title, a blade stocked
	profile.gold += int(reward.get("gold", 0))
	profile.shards += int(reward.get("shards", 0))
	if reward.has("item") and not grant_item(str(reward.item)):
		add_material("m_core", 1)       # already held (bought first): never a duplicate, a guardian core instead
	profile.quests_done.append(id)
	save()
	profile_changed.emit()
	return true

func choose_ending(id: String) -> void:
	if not profile.endings.has(id):
		profile.endings.append(id)
	profile.flags["last_ending"] = id
	save()

func start_ng_plus() -> void:
	profile.ng += 1
	profile.cleared = []
	var keep := {}
	profile.flags = keep
	save()
	profile_changed.emit()

# ================================================================ settings
func load_settings() -> void:
	if FileAccess.file_exists(_p(SETTINGS_PATH)):
		var v = _parse(FileAccess.get_file_as_string(_p(SETTINGS_PATH)))
		if v is Dictionary:
			migrate_settings(v)
			for k in settings:
				if v.has(k) and typeof(v[k]) == typeof(settings[k]) or (v.has(k) and v[k] is float and settings[k] is int):
					settings[k] = int(v[k]) if settings[k] is int else v[k]

## Older settings files had three volume sliders (music / sfx / voice) and an on-off haptics switch.
## Carries them onto the five-slider mix and the haptic strength, in place.
func migrate_settings(v: Dictionary) -> void:
	if v.has("sfx"):
		for k in ["combat", "ambience"]:
			if not v.has(k):
				v[k] = v.sfx
	if v.has("voice") and not v.has("dialogue"):
		v["dialogue"] = v.voice
	if v.get("haptics") == false and not v.has("haptic_strength"):
		v["haptic_strength"] = 0.0
		v["haptics"] = true

func save_settings() -> void:
	var f := FileAccess.open(_p(SETTINGS_PATH), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))

## What each graphics preset really sets. shadow_atlas 0 turns spot and omni shadows off;
## shadow_dist caps how far sun shadows are drawn; lod is the mesh LOD pixel threshold (higher = coarser sooner).
const GRAPHICS := [
	{"name": "Performance", "scale": 0.75, "msaa": Viewport.MSAA_DISABLED, "shadow_atlas": 0, "sun_atlas": 1024, "shadow_dist": 16.0, "particles": 0.5, "lod": 4.0},
	{"name": "Balanced", "scale": 1.0, "msaa": Viewport.MSAA_2X, "shadow_atlas": 2048, "sun_atlas": 2048, "shadow_dist": 45.0, "particles": 0.8, "lod": 1.0},
	{"name": "High", "scale": 1.15, "msaa": Viewport.MSAA_4X, "shadow_atlas": 4096, "sun_atlas": 4096, "shadow_dist": 400.0, "particles": 1.0, "lod": 0.5},
]
const SUB_SIZES := [20, 25, 32]
var _lights_hooked := false

func graphics() -> Dictionary:
	return GRAPHICS[clampi(int(settings.quality), 0, GRAPHICS.size() - 1)]

## Multiply particle amounts by this (0.5 Performance, 0.8 Balanced, 1.0 High).
func particle_scale() -> float:
	return float(graphics().particles)

func subtitle_size() -> int:
	return SUB_SIZES[clampi(int(settings.sub_size), 0, SUB_SIZES.size() - 1)]

func apply_settings() -> void:
	Engine.max_fps = int(settings.fps)
	var g := graphics()
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = float(g.scale)
		vp.msaa_3d = g.msaa
		vp.positional_shadow_atlas_size = int(g.shadow_atlas)
		vp.mesh_lod_threshold = float(g.lod)
		RenderingServer.directional_shadow_atlas_set_size(int(g.sun_atlas), true)
		if not _lights_hooked:
			_lights_hooked = true
			get_tree().node_added.connect(func(n: Node):
				if n is DirectionalLight3D:
					_fit_sun.call_deferred(n))
		for l in vp.find_children("*", "DirectionalLight3D", true, false):
			_fit_sun(l)
	# the master slider lives on the Master bus, so every other bus follows it
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(settings.master), 0.0001)))
	AudioServer.set_bus_mute(0, float(settings.master) <= 0.001)
	for bus_name: String in Sfx.BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			var vol := bus_level(bus_name)
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(vol, 0.0001)) + float(Sfx.BUS_TRIM[bus_name]))
			AudioServer.set_bus_mute(idx, vol <= 0.001)
	apply_subtitles()

## A bus's own slider value, 0-1 (the master is applied separately, on the Master bus).
func bus_level(bus_name: String) -> float:
	var key: String = Sfx.BUS_SETTING[bus_name]
	return 1.0 if key == "master" else float(settings[key])

## Sun shadows are drawn no further than the preset allows; the scene's own distance is remembered.
func _fit_sun(l) -> void:
	if not is_instance_valid(l):
		return
	if not l.has_meta("hr_shadow_dist"):
		l.set_meta("hr_shadow_dist", l.directional_shadow_max_distance)
	l.directional_shadow_max_distance = minf(float(l.get_meta("hr_shadow_dist")), float(graphics().shadow_dist))

## Subtitle size and backing, applied to the Story autoload's label.
func apply_subtitles() -> void:
	var st := get_node_or_null("/root/Story")
	if st == null:
		return
	var t = st.get("_text")
	if t is Label:
		t.add_theme_font_size_override("font_size", subtitle_size())
	var layer = st.get("_layer")
	if layer is CanvasLayer:
		for c in layer.get_children():
			if c is TextureRect:
				c.visible = bool(settings.sub_bg)

## Strength actually sent to the device for a requested strength (0 = no vibration).
func haptic_amount(strength: float) -> float:
	return clampf(strength * float(settings.haptic_strength), 0.0, 1.0) if settings.haptics else 0.0

func haptic(ms: int, strength: float = 0.6) -> void:
	var k := haptic_amount(strength)
	if k > 0.01:
		Input.vibrate_handheld(ms, k)

# ================================================================ collection: rarity, favourites, sorting, selling
## The five named ranks shown to the player, from the rarity values in the data: [name, pips].
const RARITY_TIERS := {"common": ["Common", 1], "uncommon": ["Uncommon", 2], "rare": ["Rare", 3], "epic": ["Legendary", 4], "legendary": ["Relic", 5]}
const SORTS := ["equipped", "damage", "defence", "rarity", "recent", "mastery"]
const SORT_NAME := {"equipped": "Equipped first", "damage": "Damage", "defence": "Defence", "rarity": "Rarity", "recent": "Newest", "mastery": "Mastery"}

func rarity_name(it: Dictionary) -> String:
	return RARITY_TIERS.get(it.get("rarity", "common"), RARITY_TIERS.common)[0]

func rarity_pips(it: Dictionary) -> int:
	return RARITY_TIERS.get(it.get("rarity", "common"), RARITY_TIERS.common)[1]

func is_equipped(id: String) -> bool:
	var it: Dictionary = Db.item(id)
	return not it.is_empty() and profile.equipped.get(it.slot) == Db.canon(id)

func is_favourite(id: String) -> bool:
	return profile.get("favourites", []).has(id)

func toggle_favourite(id: String) -> bool:
	if not owns(id):
		return false
	if is_favourite(id):
		profile.favourites.erase(id)
	else:
		profile.favourites.append(id)
	save()
	return is_favourite(id)

func set_sort(mode: String) -> void:
	if SORTS.has(mode):
		profile["inv_sort"] = mode
		save()

func _sort_key(id: String, mode: String) -> float:
	var it: Dictionary = Db.item(id)
	var up := 1.0 + 0.1 * upgrade_level(id)
	match mode:
		"damage": return float(it.get("damage", 0)) * up
		"defence": return float(it.get("defense", 0)) * up
		"rarity": return float(Db.rarity_rank(it))
		"recent": return float(profile.inventory.find(id))
		"mastery": return float(mastery_points(id)) / float(Stats.mastery_needed(it))
	return (1000.0 if is_equipped(id) else 0.0) + (500.0 if is_favourite(id) else 0.0) + Stats.item_power(it, upgrade_level(id))

## Owned item ids of the given slots (all slots when empty), best first for the mode.
## Ties keep the order the items were acquired in, so the list never shuffles between opens.
func sorted_items(slots: Array = [], mode: String = "") -> Array:
	if mode == "":
		mode = str(profile.get("inv_sort", "equipped"))
	var rows: Array = []
	for i in profile.inventory.size():
		var id: String = profile.inventory[i]
		var it: Dictionary = Db.item(id)
		if it.is_empty() or (not slots.is_empty() and not slots.has(it.slot)):
			continue
		rows.append([_sort_key(id, mode), i, id])
	rows.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
	var out: Array = []
	for r in rows:
		out.append(r[2])
	return out

func sell_price(id: String) -> int:
	var it: Dictionary = Db.item(id)
	if it.is_empty():
		return 0
	if it.has("sell"):
		return int(it.sell)
	var base: int = int(it.price) if int(it.price) > 0 else 80 + 120 * Db.rarity_rank(it)
	return int(base * 0.35)

## Why this item cannot be sold, or "" when it can.
func sell_block(id: String) -> String:
	id = Db.canon(id)
	if not owns(id):
		return "Not yours"
	if is_equipped(id):
		return "Equipped"
	if is_favourite(id):
		return "Favourite"
	var it: Dictionary = Db.item(id)
	if it.is_empty():
		return "Unknown"                 # an id this version does not know: kept, never sold
	if it.get("quest_item", false):
		return "Keepsake"
	if it.get("unsellable", false):
		return "Not for sale"
	if it.slot == "weapon":
		var others := 0
		var one_handed := 0
		for other in profile.inventory:
			var o: Dictionary = Db.item(other)
			if other != id and o.get("slot", "") == "weapon":
				others += 1
				one_handed += 0 if Db.classes[o.cls].two_handed else 1
		if others == 0:
			return "Last weapon"
		if not Db.classes[it.cls].two_handed and one_handed == 0:
			return "Last one-handed blade"
	return ""

func sell(id: String) -> bool:
	id = Db.canon(id)
	if sell_block(id) != "":
		return false
	profile.gold += sell_price(id)
	profile.inventory.erase(id)
	profile.upgrades.erase(id)
	profile.mods.erase(id)
	profile.edge.erase(id)
	# something Orren does not stock can be bought back from him; it is never lost for good
	if not _in_stock(Db.item(id)) and not profile.sold.has(id):
		profile.sold.append(id)
	for slot_name in profile.cosmetics:
		if profile.cosmetics[slot_name].get("look_as", "") == id:
			profile.cosmetics[slot_name].erase("look_as")
	save()
	profile_changed.emit()
	return true

## The profile as it would be with this item put on (the same rules as equip()).
func trial_profile(id: String) -> Dictionary:
	var trial: Dictionary = profile.duplicate(true)
	id = Db.canon(id)
	var it: Dictionary = Db.item(id)
	if it.is_empty() or not trial.equipped.has(it.slot):
		return trial
	trial.equipped[it.slot] = id
	if it.slot == "weapon" and Db.classes[it.cls].two_handed:
		trial.equipped.shield = null
	if it.slot == "shield":
		var w = trial.equipped.weapon
		if w != null and Db.classes[Db.item(w).cls].two_handed:
			for other in trial.inventory:
				var o: Dictionary = Db.item(other)
				if o.get("slot", "") == "weapon" and not Db.classes[o.cls].two_handed:
					trial.equipped.weapon = other
					break
	return trial

## [label, stat key, display scale, format, +1 when higher is better / -1 when lower is]
const COMPARE_ROWS := [
	["Damage", "attack", 1.0, "%.1f", 1], ["Defence", "defense", 1.0, "%.0f", 1], ["Health", "max_hp", 1.0, "%.0f", 1],
	["Stamina", "max_stamina", 1.0, "%.0f", 1], ["Stamina recovery", "stamina_regen", 1.0, "%.1f/s", 1], ["Swing time", "swing_time", 1.0, "%.2fs", -1], ["Swing cost", "swing_cost", 1.0, "%.0f", -1],
	["Stagger damage", "crit_mult", 1.0, "×%.2f", 1], ["Guard", "block_eff", 100.0, "%.0f%%", 1], ["Resistance", "resist", 1.0, "%.0f", 1],
	["Guard damage", "guard_dmg", 1.0, "×%.2f", 1], ["Shield blocks", "shield_blocks", 1.0, "%.0f", 1], ["Footwork", "footwork", 1.0, "%.0f%%", 1],
]

## What changes if this item is put on: one row per stat, each
## {label, key, now, then, delta, better (-1 worse, 0 same, 1 better), now_text, then_text}, plus the element.
## Two ways to call it: compare(item_id), or compare(slot, item_id), which gives [] when the item does not belong to
## that slot. Always against what is EQUIPPED now. `better` already knows which stats are better when lower.
func compare(slot_or_id: String, item_id: String = "") -> Array:
	var id := Db.canon(slot_or_id if item_id == "" else item_id)
	if item_id != "" and Db.item(id).get("slot", "") != slot_or_id:
		return []
	var now := stats()
	var then := Stats.compute(trial_profile(id), Db.items, Db.classes)
	var out: Array = []
	for r in COMPARE_ROWS:
		var a: float = float(now[r[1]]) * float(r[2])
		var b: float = float(then[r[1]]) * float(r[2])
		var d := b - a
		out.append({"label": r[0], "key": r[1], "now": a, "then": b, "delta": d,
			"better": 0 if is_zero_approx(d) else (1 if d * float(r[4]) > 0.0 else -1),
			"now_text": str(r[3]) % a, "then_text": str(r[3]) % b})
	var ea: String = str(now.element).capitalize() if now.element != null else "None"
	var eb: String = str(then.element).capitalize() if then.element != null else "None"
	out.append({"label": "Element", "key": "element", "now": 0.0, "then": 0.0, "delta": 0.0, "better": 0, "now_text": ea, "then_text": eb})
	return out

# ================================================================ mastery
## Fighting with a weapon fills its mastery (see on_victory). Three marks along the way:
##   I   a further line of the weapon's history
##   II  a technique for its class, written into the journal
##   III mastered: one attribute point
var _histories: Dictionary = {}

func mastery_points(id: String) -> int:
	var need := Stats.mastery_needed(Db.item(id))
	return need if profile.mastered.has(id) else mini(int(profile.mastery.get(id, 0)), need)

func mastery_threshold(it: Dictionary, tier: int) -> int:
	var need := Stats.mastery_needed(it)
	return [0, ceili(need / 3.0), ceili(need * 2.0 / 3.0), need][clampi(tier, 0, 3)]

func mastery_tier(id: String) -> int:
	var it: Dictionary = Db.item(id)
	var have := mastery_points(id)
	var tier := 0
	for t in [1, 2, 3]:
		if have >= mastery_threshold(it, t):
			tier = t
	return tier

## The technique tier II would teach for this weapon right now ({} when every one is known).
func mastery_technique(it: Dictionary) -> Dictionary:
	for own_class in [true, false]:
		for c in Db.combos:
			if profile.combos.has(c.id):
				continue
			if (own_class and c.cls.has(it.get("cls", ""))) or (not own_class and c.cls.is_empty()):
				return c
	return {}

func mastery_tier_text(it: Dictionary, tier: int) -> String:
	if it.get("slot", "") != "weapon":
		var at := mastery_threshold(it, tier)
		for m: Dictionary in it.get("mastery", {}).get("marks", []):
			if int(m.at) == at and tier >= 1:
				return str(m.text)
		return "Mastered: one attribute point" if tier == 3 else ""
	match tier:
		1: return "More of its history"
		2:
			var taught := str(profile.get("mastery_taught", {}).get(it.id, ""))
			if taught != "":
				return "Technique learned: %s. Swings with it cost 3%% less" % Db.combo_by_id[taught].name
			return "A %s technique, written into the journal. Swings with it cost 3%% less" % str(Db.classes[it.cls].name).to_lower()
		3: return "Mastered: one attribute point"
	return ""

## Grants what the weapon's current mastery has earned and not yet given. Returns the id of a
## technique taught just now, or "". Safe to call at any time.
func mastery_unlocks(id: String) -> String:
	var it: Dictionary = Db.item(id)
	if it.get("slot", "") != "weapon" or mastery_tier(id) < 2:
		return ""
	if not profile.has("mastery_taught"):
		profile["mastery_taught"] = {}
	if profile.mastery_taught.has(id):
		return ""
	var c := mastery_technique(it)
	if c.is_empty():
		return ""
	profile.mastery_taught[id] = c.id
	profile.combos.append(c.id)      # known, but not counted as used
	return str(c.id)

## Brings an older save up to date with the mastery it already holds.
func sync_mastery() -> void:
	var changed := false
	for id in profile.inventory:
		changed = (mastery_unlocks(id) != "") or changed
	if changed:
		save()

## The weapon whose mastery taught this technique, or "".
func technique_source(combo_id: String) -> String:
	var taught: Dictionary = profile.get("mastery_taught", {})
	for id in taught:
		if taught[id] == combo_id:
			return id
	return ""

## The item's description, with the further line that mastery mark I reveals.
func item_history(id: String) -> Array:
	var it: Dictionary = Db.item(id)
	var out: Array = [str(it.get("desc", ""))]
	if _histories.is_empty():
		var v = _parse(FileAccess.get_file_as_string("res://data/weapon_history.json"))
		_histories = v if v is Dictionary else {"_": ""}
	if _histories.has(id) and mastery_tier(id) >= 1:
		out.append(str(_histories[id]))
	return out

# ================================================================ equipment: materials, forge, discovery, cosmetics
## The rules are in data/equipment.json (tools/gen_equipment.py) and docs/EQUIPMENT_PROGRESSION.md.

func material_count(id: String) -> int:
	return int(profile.shards) if id == "shards" else int(profile.get("materials", {}).get(id, 0))

## Adds (or, with a negative count, takes) a material. Never goes below zero; false when it would.
func add_material(id: String, n: int) -> bool:
	if material_count(id) + n < 0:
		return false
	if id == "shards":
		profile.shards += n
	else:
		profile.materials[id] = material_count(id) + n
	return true

## Every material with what is held: [{id, name, desc, count}], shards first.
func materials_list() -> Array:
	var out: Array = [{"id": "shards", "name": "Shards", "desc": "Splinters of the Crown. Orren works them into anything.", "count": int(profile.shards)}]
	for id: String in Db.materials:
		out.append({"id": id, "name": str(Db.materials[id].name), "desc": str(Db.materials[id].desc), "count": material_count(id)})
	return out

## What one unit costs at the forge, 0 when Orren does not have it: shards always, a region's material once one of its
## regions has been cleared, guardian cores never. Materials cannot be sold back, so nothing is gained by trading.
func material_price(id: String) -> int:
	if id == "shards":
		return int(Db.equipment.shard_price)
	var m: Dictionary = Db.materials.get(id, {})
	if int(m.get("price", 0)) <= 0:
		return 0
	for r: String in m.get("regions", []):
		if profile.cleared.has(r) or int(profile.ng) > 0:
			return int(m.price)
	return 0

func buy_material(id: String, n: int = 1) -> bool:
	var cost := material_price(id) * n
	if n <= 0 or cost <= 0 or profile.gold < cost:
		return false
	profile.gold -= cost
	add_material(id, n)
	save()
	profile_changed.emit()
	return true

## Gold needed to buy what an upgrade or a pattern still lacks in shards and materials, or -1 when some of it
## cannot be bought. `cost` is {gold, shards, materials}; the gold of the cost itself is not included.
func shortfall_price(cost: Dictionary) -> int:
	var total := 0
	var need: Dictionary = cost.get("materials", {}).duplicate()
	need["shards"] = int(cost.get("shards", 0))
	for m: String in need:
		var lack: int = int(need[m]) - material_count(m)
		if lack > 0:
			if material_price(m) <= 0:
				return -1
			total += lack * material_price(m)
	return total

# ---------------------------------------------------------------- requirements
func meets_requirements(id: String) -> bool:
	return Stats.unmet(profile.attrs, Db.item(id)).is_empty()

## "Strength 9" style line for what the item asks, "" when it asks nothing.
func requirement_text(id: String) -> String:
	var bits: Array = []
	for k: String in Db.item(id).get("req", {}):
		bits.append("%s %d" % [Db.ATTR_NAME.get(k, k), int(Db.item(id).req[k])])
	return ", ".join(bits)

# ---------------------------------------------------------------- forge: upgrade preview, crafting
## What the next upgrade would do, without doing it: {level, max, cost, block, rows} where rows are compare()-style
## rows of the stats the duel reads, now against after. Empty rows when the item is not worn (its own figures are in
## `item_now` / `item_then`: damage or defence, and guard for a shield).
func upgrade_preview(id: String) -> Dictionary:
	id = Db.canon(id)
	var it: Dictionary = Db.item(id)
	var lvl := upgrade_level(id)
	var out := {"level": lvl, "max": int(it.get("upgrade", {}).get("max", 0)), "cost": upgrade_cost(id), "block": upgrade_block(id),
		"rows": [], "item_now": Stats.item_power(it, lvl) if not it.is_empty() else 0.0, "item_then": Stats.item_power(it, lvl + 1) if not it.is_empty() else 0.0}
	if it.is_empty() or not is_equipped(id) or lvl >= int(out.max):
		return out
	var trial: Dictionary = profile.duplicate(true)
	trial.upgrades[id] = lvl + 1
	out.rows = _rows(stats(), Stats.compute(trial, Db.items, Db.classes)).filter(func(r): return int(r.better) != 0)
	return out

func _rows(now: Dictionary, then: Dictionary) -> Array:
	var out: Array = []
	for r in COMPARE_ROWS:
		var a: float = float(now[r[1]]) * float(r[2])
		var b: float = float(then[r[1]]) * float(r[2])
		var d := b - a
		out.append({"label": r[0], "key": r[1], "now": a, "then": b, "delta": d,
			"better": 0 if is_zero_approx(d) else (1 if d * float(r[4]) > 0.0 else -1),
			"now_text": str(r[3]) % a, "then_text": str(r[3]) % b})
	return out

## Why this cannot be made now, or "" when it can.
func craft_block(id: String) -> String:
	var it: Dictionary = Db.item(id)
	if it.is_empty() or not it.has("craft"):
		return "No pattern"
	if owns(id):
		return "Already yours"
	var fam: Dictionary = Db.family(it)
	if not fam.is_empty() and not region_unlocked(str(fam.region)):
		return "Unknown work"
	var c: Dictionary = it.craft
	if profile.gold < int(c.get("gold", 0)):
		return "Not enough gold"
	if profile.shards < int(c.get("shards", 0)):
		return "Not enough shards"
	for m: String in c.get("materials", {}):
		if material_count(m) < int(c.materials[m]):
			return "Needs %s" % Db.material_name(m)
	return ""

func can_craft(id: String) -> bool:
	return craft_block(id) == ""

func craft(id: String) -> bool:
	id = Db.canon(id)
	if not can_craft(id):
		return false
	var c: Dictionary = Db.item(id).craft
	profile.gold -= int(c.get("gold", 0))
	profile.shards -= int(c.get("shards", 0))
	for m: String in c.get("materials", {}):
		profile.materials[m] = material_count(m) - int(c.materials[m])
	grant_item(id)
	save()
	profile_changed.emit()
	return true

## Patterns Orren can work from now (the family's region has been reached and the piece is not held).
func craft_stock() -> Array:
	var out: Array = []
	for it in Db.item_list:
		if it.has("craft") and not owns(it.id) and craft_block(it.id) != "Unknown work":
			out.append(it)
	return out

# ---------------------------------------------------------------- mastery challenges
func challenge_ready(id: String) -> bool:
	if not Db.challenges.has(id) or profile.challenges_done.has(id):
		return false
	var need: Dictionary = Db.challenges[id].need
	var n := 0
	for item_id in profile.mastered:
		if Db.item(str(item_id)).get("cls", "") == need.get("mastered_cls", "-"):
			n += 1
	return n >= int(need.get("count", 1))

func claim_challenge(id: String) -> bool:
	if not challenge_ready(id):
		return false
	var reward: Dictionary = Db.challenges[id].reward
	if reward.has("item"):
		grant_item(str(reward.item))
	profile.challenges_done.append(id)
	save()
	profile_changed.emit()
	return true

# ---------------------------------------------------------------- discovery states
func is_discovered(id: String) -> bool:
	id = Db.canon(id)
	return owns(id) or profile.get("discovered", {}).has(id) or _shop_visible(Db.item(id))

## "equipped", "owned", "discovered" (seen as a drop, in the shop, or heard of) or "undiscovered" (a silhouette and a hint).
func item_state(id: String) -> String:
	if is_equipped(id):
		return "equipped"
	if owns(id):
		return "owned"
	return "discovered" if is_discovered(id) else "undiscovered"

## The spoiler-free line about where an item is to be had.
func item_hint(id: String) -> String:
	return str(Db.item(id).get("hint", ""))

## Marks an item as looked at (clears its "new" mark). Saved with the next save; never writes on its own.
func mark_seen(id: String) -> void:
	if owns(id):
		profile.seen[Db.canon(id)] = true

func is_new(id: String) -> bool:
	return owns(id) and not profile.get("seen", {}).has(Db.canon(id))

## Records that the player has come across an item (a drop seen, a line of lore). True when that was news.
func discover(id: String) -> bool:
	id = Db.canon(id)
	if not Db.items.has(id) or profile.discovered.has(id):
		return false
	profile.discovered[id] = true
	return true

## Everything a slot's row needs. Owned items first, in the stored sort order; with `include_locked`, then the
## discovered and then the undiscovered ones. Each entry:
##   {id, state, item (the definition), name ("Unknown" while undiscovered), hint, owned, equipped, is_new, favourite,
##    level, mastery_tier, visual, meets_req, can_equip}
## Items only offered on a later cycle stay out until that cycle or until discovered.
func items_for_slot(slot_name: String, include_locked: bool = false) -> Array:
	var ids: Array = sorted_items([slot_name])
	if include_locked:
		for want: String in ["discovered", "undiscovered"]:
			for it in Db.item_list:
				if it.slot != slot_name or owns(it.id) or item_state(it.id) != want:
					continue
				if want == "undiscovered" and int(it.get("ng_min", 0)) > int(profile.ng):
					continue
				ids.append(it.id)
	var out: Array = []
	for id: String in ids:
		var it: Dictionary = Db.item(id)
		var state := item_state(id)
		out.append({"id": id, "state": state, "item": it, "name": str(it.name) if state != "undiscovered" else "Unknown",
			"hint": str(it.get("hint", "")), "owned": owns(id), "equipped": state == "equipped", "is_new": is_new(id),
			"favourite": is_favourite(id), "level": upgrade_level(id), "mastery_tier": mastery_tier(id),
			"visual": str(it.get("visual", "none")), "meets_req": meets_requirements(id), "can_equip": owns(id),
			"shop": "" if owns(id) or not _shop_visible(it) else ("available" if _in_stock(it) else "locked"),
			"price": buy_price(id), "unlock_text": "" if owns(id) or _in_stock(it) else str(it.get("unlock_text", ""))})
	return out

## The profile as it would be with this item in this slot. Nothing is changed and nothing is saved. An item that
## does not belong to the slot gives an unchanged copy. Works for items not owned, so locked gear can be previewed.
func preview_profile(slot_name: String, item_id: String) -> Dictionary:
	if Db.item(item_id).get("slot", "") != slot_name:
		return profile.duplicate(true)
	return trial_profile(item_id)

## The duel's numbers for that what-if profile.
func preview_stats(slot_name: String, item_id: String) -> Dictionary:
	return Stats.compute(preview_profile(slot_name, item_id), Db.items, Db.classes)

## The set bonuses of a profile: [{family, name, pieces, tiers: [{pieces, text, active}]}], families worn only.
func set_status(p: Dictionary = profile) -> Array:
	var out: Array = []
	for s: Dictionary in Stats.compute(p, Db.items, Db.classes).sets:
		var fam: Dictionary = Db.families[s.family]
		var tiers: Array = []
		for t: Dictionary in fam.set:
			tiers.append({"pieces": int(t.pieces), "text": str(t.text), "active": int(s.pieces) >= int(t.pieces)})
		out.append({"family": s.family, "name": str(fam.name), "pieces": int(s.pieces), "tiers": tiers})
	return out

# ---------------------------------------------------------------- cosmetics (never a statistic)
## A slot's cosmetic layer: {finish, accent, look_as}. `look_as` is "" or the id of an owned item of the same slot
## whose appearance is shown instead of the equipped one's.
func cosmetic(slot_name: String) -> Dictionary:
	var c: Dictionary = profile.get("cosmetics", {}).get(slot_name, {})
	return {"finish": str(c.get("finish", "issued")), "accent": str(c.get("accent", "heraldry")), "look_as": str(c.get("look_as", ""))}

func _cosmetic_set(slot_name: String, key: String, value: String) -> void:
	if not profile.cosmetics.has(slot_name):
		profile.cosmetics[slot_name] = {}
	if value == "":
		profile.cosmetics[slot_name].erase(key)
	else:
		profile.cosmetics[slot_name][key] = value
	save()
	profile_changed.emit()

func set_finish(slot_name: String, finish: String) -> bool:
	if not Db.EQUIP_SLOTS.has(slot_name) or not finishes_available().has(finish):
		return false
	_cosmetic_set(slot_name, "finish", finish)
	return true

func set_accent(slot_name: String, accent: String) -> bool:
	if not Db.EQUIP_SLOTS.has(slot_name) or not Db.equipment.accents.has(accent):
		return false
	_cosmetic_set(slot_name, "accent", accent)
	return true

## Shows another owned item of the same slot in place of the equipped one. "" removes the override.
func set_look_as(slot_name: String, item_id: String) -> bool:
	item_id = Db.canon(item_id) if item_id != "" else ""
	if not Db.EQUIP_SLOTS.has(slot_name):
		return false
	if item_id != "" and (not owns(item_id) or Db.item(item_id).get("slot", "") != slot_name):
		return false
	_cosmetic_set(slot_name, "look_as", item_id)
	return true

## The item whose appearance a slot shows: the override if one is set and still valid, else what is equipped ("" for none).
func appearance(slot_name: String, p: Dictionary = profile) -> String:
	var look: String = str(p.get("cosmetics", {}).get(slot_name, {}).get("look_as", ""))
	if look != "" and p.inventory.has(look) and Db.item(look).get("slot", "") == slot_name and p.equipped.get(slot_name) != null:
		return look
	return str(p.equipped[slot_name]) if p.equipped.get(slot_name) != null else ""

## A copy of the profile's loadout with every appearance override applied: hand this to whatever draws the knight.
## Never hand it to Stats.
func appearance_loadout(p: Dictionary = profile) -> Dictionary:
	var out := {}
	for slot_name in p.equipped:
		var id := appearance(slot_name, p)
		out[slot_name] = id if id != "" else null
	return out

# ================================================================ secrets, side missions, completion (rules in Secrets)
## How much of the kingdom has been seen: {pct, categories, remains, regions [{id, name, pct, unlocked, categories,
## remains}], milestones}. `remains` are spoiler-free lines about what is still missing there. Reads only.
func completion() -> Dictionary:
	return Secrets.completion(profile)

## Finds a secret, once: {} if unknown or already found, else {id, name, found, lines}. Saved at once.
func find_secret(id: String) -> Dictionary:
	return Secrets.find(id)

func secret_found(id: String) -> bool:
	return Secrets.found(id, profile)

## The Journal's tasks: the eight, then the side missions offered so far.
func journal_quests() -> Array:
	return Secrets.journal_quests(profile)

## Every finish that can be chosen: the four everyone has, then those earned ({id: name}).
func finishes_available() -> Dictionary:
	var out: Dictionary = Db.equipment.finishes.duplicate()
	for id: String in profile.get("completion", {}).get("finishes", []):
		out[id] = Secrets.label_of("finish", id)
	return out

## The title the knight goes by ("" for none), and choosing among those earned.
func title() -> String:
	var id := str(profile.get("completion", {}).get("title", ""))
	return Secrets.label_of("title", id) if id != "" else ""

func set_title(id: String) -> bool:
	if id != "" and not profile.get("completion", {}).get("titles", []).has(id):
		return false
	profile.completion.title = id
	save()
	return true
