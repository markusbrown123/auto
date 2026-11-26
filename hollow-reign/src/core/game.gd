extends Node
## Persistent profile, save/load, progression rules and the current run.

signal profile_changed

const SAVE_PATH := "user://save.json"
const SAVE_TMP := "user://save.tmp"
const SAVE_BAK := "user://save.bak"
const SETTINGS_PATH := "user://settings.json"
const SAVE_VERSION := 1

var profile: Dictionary = {}
var run: Dictionary = {}          # {region, stage, hp, found:[...]} — reset on death
var settings: Dictionary = {
	"quality": 1, "fps": 60, "music": 0.8, "sfx": 1.0, "voice": 1.0, "haptics": true,
	"shake": 1.0, "assist": false, "hints": true, "reduce_flash": false, "cine": false, "cine_road": false, "pad_opacity": 0.2,
}
var rng := RandomNumberGenerator.new()
var just_died := false         # set on death, consumed by the sanctuary
var save_dir_override := ""   # tests point this at a temp location


func _ready() -> void:
	rng.randomize()
	load_settings()
	apply_settings()

# ================================================================ profile
func default_profile() -> Dictionary:
	return {
		"version": SAVE_VERSION, "level": 1, "xp": 0, "attr_points": 0,
		"attrs": {"health": 5, "strength": 5, "dex": 5, "endurance": 5, "defense": 2, "crit": 0, "resist": 0},
		"gold": 0, "shards": 0,
		"inventory": ["w_rusted_sword", "s_plank", "a_worn_helm", "a_worn_chest", "a_worn_gauntlets", "a_worn_legs"],
		"equipped": {"weapon": "w_rusted_sword", "shield": "s_plank", "helm": "a_worn_helm", "chest": "a_worn_chest",
			"gauntlets": "a_worn_gauntlets", "legs": "a_worn_legs", "ring": null, "relic": null},
		"upgrades": {}, "mastery": {}, "mastered": [],
		"flags": {}, "defeated": {}, "cleared": [], "ng": 0, "deaths": 0, "heraldry": "#3d0f0f",
		"tutorial_done": false, "playtime": 0.0, "body": "m", "combos": ["double_slash"], "combo_uses": {},
	}

func has_save() -> bool:
	return FileAccess.file_exists(_p(SAVE_PATH)) or FileAccess.file_exists(_p(SAVE_BAK))

func _p(path: String) -> String:
	return path if save_dir_override == "" else save_dir_override + "/" + path.get_file()

func new_game(heraldry: String = "#3d0f0f", body: String = "m") -> void:
	profile = default_profile()
	profile.heraldry = heraldry
	profile.body = body
	run = {}
	save()
	profile_changed.emit()

func save() -> bool:
	if profile.is_empty():
		return false
	var f := FileAccess.open(_p(SAVE_TMP), FileAccess.WRITE)
	if f == null:
		push_warning("save failed: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(profile))
	f.close()
	var d := DirAccess.open(_p(SAVE_PATH).get_base_dir())
	if d == null:
		return false
	# keep the previous good save as a backup, then swap the new one in
	if d.file_exists(_p(SAVE_PATH).get_file()):
		d.rename(_p(SAVE_PATH).get_file(), _p(SAVE_BAK).get_file())
	return d.rename(_p(SAVE_TMP).get_file(), _p(SAVE_PATH).get_file()) == OK

func load_game() -> bool:
	for path in [SAVE_PATH, SAVE_BAK]:
		var p := _p(path)
		if not FileAccess.file_exists(p):
			continue
		var v = _parse(FileAccess.get_file_as_string(p))
		if v is Dictionary and v.has("attrs") and v.has("equipped"):
			profile = _migrate(v)
			run = {}
			profile_changed.emit()
			return true
	return false

func _parse(txt: String) -> Variant:
	var j := JSON.new()
	return j.data if j.parse(txt) == OK else null

func _migrate(v: Dictionary) -> Dictionary:
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
	# JSON turns ints into floats; restore the integer fields
	for k in ["level", "xp", "attr_points", "gold", "shards", "ng", "deaths"]:
		v[k] = int(v[k])
	for k in v.attrs:
		v.attrs[k] = int(v.attrs[k])
	for d in ["upgrades", "mastery", "defeated", "combo_uses"]:
		for k in v[d]:
			v[d][k] = int(v[d][k])
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
	return profile.inventory.has(id)

func grant_item(id: String) -> bool:
	if owns(id) or not Db.items.has(id):
		return false
	profile.inventory.append(id)
	return true

func equip(id: String) -> bool:
	if not owns(id):
		return false
	var it: Dictionary = Db.item(id)
	profile.equipped[it.slot] = id
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
		if it.slot == "weapon" and not Db.classes[it.cls].two_handed:
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

func can_upgrade(id: String) -> bool:
	var lvl := upgrade_level(id)
	if lvl >= Stats.MAX_UPGRADE or not owns(id):
		return false
	var c := Stats.upgrade_cost(Db.item(id), lvl)
	return profile.gold >= c.gold and profile.shards >= c.shards

func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	var c := Stats.upgrade_cost(Db.item(id), upgrade_level(id))
	profile.gold -= int(c.gold)
	profile.shards -= int(c.shards)
	profile.upgrades[id] = upgrade_level(id) + 1
	save()
	profile_changed.emit()
	return true

func buy(id: String) -> bool:
	var it: Dictionary = Db.item(id)
	if it.is_empty() or owns(id) or int(it.price) <= 0 or profile.gold < int(it.price):
		return false
	profile.gold -= int(it.price)
	grant_item(id)
	save()
	profile_changed.emit()
	return true

func shop_stock() -> Array:
	var out: Array = []
	for it in Db.item_list:
		if int(it.price) > 0 and not owns(it.id) and int(it.get("ng_min", 0)) <= profile.ng:
			out.append(it)
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

## Apply the rewards for defeating a foe. Returns a summary for the victory screen.
func on_victory(foe_id: String, hp_left: float) -> Dictionary:
	var foe: Dictionary = Db.foes[foe_id]
	var ng: int = profile.ng
	var first: bool = not profile.defeated.has(foe_id)
	profile.defeated[foe_id] = int(profile.defeated.get(foe_id, 0)) + 1
	var out := {"xp": int(foe.xp * (1.0 + 0.5 * ng)), "gold": int(foe.gold * (1.0 + 0.5 * ng)),
		"shards": 3 if foe.boss else 1, "items": [], "levels": 0, "mastered": [], "first": first}
	for entry in foe.get("loot", []):
		var id: String = entry[0]
		if owns(id):
			continue
		if (first and float(entry[1]) >= 1.0) or rng.randf() < float(entry[1]):
			grant_item(id)
			out.items.append(id)
	if foe.boss and ng > 0 and rng.randf() < 0.5:
		for it in Db.item_list:
			if int(it.get("ng_min", 0)) >= 1 and int(it.ng_min) <= ng and not owns(it.id):
				grant_item(it.id)
				out.items.append(it.id)
				break
	# equipment mastery: fighting with a piece of gear teaches you its weight
	for slot in profile.equipped:
		var id = profile.equipped[slot]
		if id == null or profile.mastered.has(id):
			continue
		profile.mastery[id] = int(profile.mastery.get(id, 0)) + (2 if foe.boss else 1)
		if profile.mastery[id] >= Stats.mastery_needed(Db.item(id)):
			profile.mastered.append(id)
			profile.attr_points += 1
			out.mastered.append(id)
	profile.gold += out.gold
	profile.shards += out.shards
	out.levels = grant_xp(out.xp)
	if not run.is_empty():
		run.hp = hp_left
		run.xp += out.xp
		run.gold += out.gold
		run.found.append_array(out.items)
	save()
	profile_changed.emit()
	return out

func complete_region() -> bool:
	var id: String = run.region
	var first: bool = not profile.cleared.has(id)
	if first:
		profile.cleared.append(id)
	run = {}
	save()
	profile_changed.emit()
	return first

func on_death() -> Dictionary:
	# Everything earned is kept; only the route resets.
	profile.deaths += 1
	just_died = true
	var summary := run.duplicate(true)
	run = {}
	save()
	return summary

func game_complete() -> bool:
	return profile.cleared.size() >= Db.regions.size()

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
			for k in settings:
				if v.has(k) and typeof(v[k]) == typeof(settings[k]) or (v.has(k) and v[k] is float and settings[k] is int):
					settings[k] = int(v[k]) if settings[k] is int else v[k]

func save_settings() -> void:
	var f := FileAccess.open(_p(SETTINGS_PATH), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))

func apply_settings() -> void:
	Engine.max_fps = int(settings.fps)
	var q: int = settings.quality
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = [0.6, 0.8, 1.0][q]
		vp.msaa_3d = Viewport.MSAA_DISABLED if q == 0 else Viewport.MSAA_2X
	for bus_name: String in Sfx.BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			var vol: float = float(settings[Sfx.BUS_SETTING[bus_name]])
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(vol, 0.0001)) + float(Sfx.BUS_TRIM[bus_name]))
			AudioServer.set_bus_mute(idx, vol <= 0.001)

func haptic(ms: int, strength: float = 0.6) -> void:
	if settings.haptics:
		Input.vibrate_handheld(ms, strength)
