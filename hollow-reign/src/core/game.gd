extends Node
## Persistent profile, save/load, progression rules and the current run.

signal profile_changed

const SAVE_PATH := "user://save.json"
const SAVE_TMP := "user://save.tmp"
const SAVE_BAK := "user://save.bak"
const SETTINGS_PATH := "user://settings.json"
const SAVE_VERSION := 1
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
			"gauntlets": "a_worn_gauntlets", "legs": "a_worn_legs", "ring": null, "relic": null},
		"upgrades": {}, "mastery": {}, "mastered": [],
		"flags": {}, "defeated": {}, "cleared": [], "endings": [], "ng": 0, "deaths": 0, "heraldry": "#3d0f0f",
		"tutorial_done": false, "playtime": 0.0, "body": "m", "combos": ["double_slash"], "combo_uses": {},
		"lore": [], "quests_done": [], "heard": [],
		"favourites": [], "inv_sort": "equipped", "mastery_taught": {},
		"name": "", "last_played": 0.0,
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
	profile["last_played"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(slot_file(slot, "tmp"), FileAccess.WRITE)
	if f == null:
		push_warning("save failed: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(profile))
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
		var taught := mastery_unlocks(str(id))
		if taught != "":
			out["taught"] = out.get("taught", []) + [taught]
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
	var need: Dictionary = Db.quest_by_id[id].need
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
	return parts

func quest_ready(id: String) -> bool:
	if not Db.quest_by_id.has(id):
		return false
	for part in _quest_parts(id):
		if part[0] < part[1]:
			return false
	return true

func quest_progress(id: String) -> String:
	if not Db.quest_by_id.has(id):
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
	var reward: Dictionary = Db.quest_by_id[id].reward
	profile.gold += int(reward.get("gold", 0))
	profile.shards += int(reward.get("shards", 0))
	if reward.has("item"):
		grant_item(str(reward.item))
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
	return not it.is_empty() and profile.equipped.get(it.slot) == id

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
	var base: int = int(it.price) if int(it.price) > 0 else 80 + 120 * Db.rarity_rank(it)
	return int(base * 0.35)

## Why this item cannot be sold, or "" when it can.
func sell_block(id: String) -> String:
	if not owns(id):
		return "Not yours"
	if is_equipped(id):
		return "Equipped"
	if is_favourite(id):
		return "Favourite"
	var it: Dictionary = Db.item(id)
	if it.slot == "weapon" and not Db.classes[it.cls].two_handed:
		var others := 0
		for other in profile.inventory:
			var o: Dictionary = Db.item(other)
			if other != id and o.get("slot", "") == "weapon" and not Db.classes[o.cls].two_handed:
				others += 1
		if others == 0:
			return "Last one-handed blade"
	return ""

func sell(id: String) -> bool:
	if sell_block(id) != "":
		return false
	profile.gold += sell_price(id)
	profile.inventory.erase(id)
	profile.upgrades.erase(id)
	save()
	profile_changed.emit()
	return true

## The profile as it would be with this item put on (the same rules as equip()).
func trial_profile(id: String) -> Dictionary:
	var trial: Dictionary = profile.duplicate(true)
	var it: Dictionary = Db.item(id)
	if it.is_empty():
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
	["Stamina", "max_stamina", 1.0, "%.0f", 1], ["Swing time", "swing_time", 1.0, "%.2fs", -1], ["Swing cost", "swing_cost", 1.0, "%.0f", -1],
	["Stagger damage", "crit_mult", 1.0, "×%.2f", 1], ["Guard", "block_eff", 100.0, "%.0f%%", 1], ["Resistance", "resist", 1.0, "%.0f", 1],
]

## What changes if this item is put on: one row per stat, each
## {label, key, now, then, delta, better (-1 worse, 0 same, 1 better), now_text, then_text}, plus the element.
func compare(id: String) -> Array:
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
		return "Mastered: one attribute point" if tier == 3 else ""
	match tier:
		1: return "More of its history"
		2:
			var taught := str(profile.get("mastery_taught", {}).get(it.id, ""))
			if taught != "":
				return "Technique learned: %s" % Db.combo_by_id[taught].name
			return "A %s technique, written into the journal" % str(Db.classes[it.cls].name).to_lower()
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
