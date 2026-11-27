class_name GearModel
extends RefCounted
## Loads the hand-modelled equipment in assets/models/gear/ (built by tools/gear_gen.py).
## These models are already in the rig's conventions and in metres, so nothing is measured or rescaled:
##   swords  : origin at the centre of the main hand, +Y to the tip, guard along X, flat of the blade faces Z
##   shields : origin at the centre of the hand grip, +Y up, front faces -Z, +X is the bearer's right
## Dimensions the rig needs (blade length beyond the hand, pommel drop, board centre) are in gear_manifest.json,
## with each piece's `role` (balanced / light / heavy / precision) and `rarity`.
##
## Forge state. The four basic swords are built as parts, so a mod is a choice of files plus material settings:
##   GearModel.spawn("wayfarer", 9.0, false, {"blade_tier": 2, "grip_tier": 3, "ore": "bronze", "sharpened": true})
## blade_tier / grip_tier 0-3 pick <id>__blade<n>.glb and <id>__hilt<n>.glb; `ore` tints the blade's own surfaces
## (manifest "_mods".ores); `sharpened` polishes the edge bevel. With no mod the sword's own file is used.
## Light channels ("glow" surfaces) are dark until GearModel.awaken(node, true).

const DIR := "res://assets/models/gear/"
static var _manifest := {}
## Every sword is drawn as its hybrid (our blade in a generated, sculpted hilt: manifest entry "<id>_h") under its
## own id. `old_hilts` (dev arg --oldhilts, or mod {"old_hilt": true} for one piece) gives the code-built hilts back.
static var old_hilts := "--oldhilts" in OS.get_cmdline_user_args()

## The manifest key a sword id is drawn from: its hybrid where there is one.
static func _key(id: String) -> String:
	if not old_hilts and not id.ends_with("_h") and manifest().has(id + "_h"):
		return id + "_h"
	return id

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var f := FileAccess.open(DIR + "gear_manifest.json", FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_manifest = d
	return _manifest

## Item ids in the manifest, optionally of one class ("sword" matches every blade class).
## Hybrids (a modelled blade in a generated hilt: manifest `hybrid`) are trial pieces and are left out unless asked for.
static func ids(kind: String = "", hybrids: bool = false) -> Array:
	var out: Array = []
	for k: String in manifest():
		if k.begins_with("_") or (not hybrids and k.ends_with("_h") and bool(manifest()[k].get("hybrid", false))):
			continue
		var cls := str(manifest()[k].get("class", ""))
		if kind == "" or (kind == "shield") == (cls == "shield"):
			out.append(k)
	return out

## On the rig the gear is drawn a little over life size (the knight is 1.95 m): the manifest's `rig_scale`, except
## where a piece looked wrong on the figure. The Tower shield at 1.15 stood 1.01 m, chin to shin: it is worn life size.
const RIG_SCALE := {"shield_tower": 1.0}
## Asymmetric hilts: the models whose knuckle side (the long guard arm) is on -X; the rig turns these half round so
## every sword's knuckle side is +X, which FighterRig lays over the knuckles of the hand that holds it.
const KNUCKLES_MINUS_X := ["veilcutter"]
## Game.weapon_mods().visual names an ore as "iron", "steel", a region material id or "cored" (ore_id says which):
## the manifest's palette where it has the metal, two colours of our own where it has not (as the Armory's carousel).
const ORE_GEAR := {"steel": "steel", "m_iron": "graphite", "m_silver": "silver", "m_scale": "bronze", "m_rime": "frost"}
const ORE_OWN := {"iron": Color(0.8, 0.78, 0.76), "m_glass": Color(0.8, 0.74, 1.12)}

static func rig_scale(id: String) -> float:
	return float(RIG_SCALE.get(id, info(id).get("rig_scale", 1.15)))

## The forge state FighterRig hands to spawn(), from Game.weapon_mods(id).visual. Swords that are not built in parts
## take only the ore and the edge.
static func mod_from_visual(id: String, v: Dictionary) -> Dictionary:
	var ore := str(v.get("ore", "steel"))
	if ore == "cored" or ore == "":
		ore = str(v.get("ore_id", "")) if str(v.get("ore_id", "")) != "" else "steel"
	var out := {"sharpened": bool(v.get("keen", false))}
	if ORE_OWN.has(ore):
		out["tint"] = ORE_OWN[ore]
	else:
		out["ore"] = str(ORE_GEAR.get(ore, "steel"))
	if ResourceLoader.exists("%s%s__blade0.glb" % [DIR, id]):
		out["blade_tier"] = int(v.get("blade_tier", 0))
		out["grip_tier"] = int(v.get("grip_tier", 0))
	else:
		out["sharpened"] = true       # the finished swords leave the smith keen
	return out

## What the rig needs to hold a piece, in metres on the rig (rig_scale applied).
## swords: {scale, len (grip to tip), pommel (grip to pommel end), off_hand (grip to the second hand, two-handers),
##          half (half the blade's width), pair, turn (radians about the blade to bring the knuckle side to +X)}
## shields: {scale, centre (board centre from the grip), hw, hh (half width and height), strap (grip to the arm strap)}
static func hold(id: String) -> Dictionary:
	var i := info(id)
	var k := rig_scale(id)
	if str(i.get("class", "")) == "shield":
		var c: Array = i.get("board_centre", [0, 0, 0])
		return {"scale": k, "centre": Vector3(float(c[0]), float(c[1]), float(c[2])) * k, "hw": float(i.get("width", 0.5)) * 0.5 * k,
			"hh": float(i.get("height", 0.7)) * 0.5 * k, "strap": absf(float(i.get("strap_x", -0.2))) * k}
	var two := float(i.get("hands", 1)) >= 2.0
	return {"scale": k, "len": float(i.get("tip", 1.0)) * k, "pommel": float(i.get("pommel", 0.12)) * k,
		"off_hand": absf(float(i.get("off_hand", -0.16))) * k, "half": (0.034 if two else 0.03) * k,
		"pair": bool(i.get("pair", false)), "turn": PI if KNUCKLES_MINUS_X.has(id) else 0.0}

static func exists(id: String) -> bool:
	return ResourceLoader.exists(DIR + id + ".glb")

## What the manifest says of a piece as it is drawn: a sword's numbers (tip, pommel, grip) are its hybrid's.
static func info(id: String) -> Dictionary:
	return manifest().get(_key(id), {})

static func _add(root: Node3D, file: String, lod_at: float, force_lod: bool) -> void:
	var has_lod := ResourceLoader.exists(DIR + file + "_lod.glb")
	if not (force_lod and has_lod):
		var hi: Node3D = (load(DIR + file + ".glb") as PackedScene).instantiate()
		root.add_child(hi)
		if lod_at > 0.0 and has_lod:
			for mi: MeshInstance3D in hi.find_children("*", "MeshInstance3D", true, false):
				mi.visibility_range_end = lod_at
				mi.visibility_range_end_margin = 0.5
	if has_lod and (force_lod or lod_at > 0.0):
		var lo: Node3D = (load(DIR + file + "_lod.glb") as PackedScene).instantiate()
		root.add_child(lo)
		if not force_lod:
			for mi: MeshInstance3D in lo.find_children("*", "MeshInstance3D", true, false):
				mi.visibility_range_begin = lod_at
				mi.visibility_range_begin_margin = 0.5

## The item as a Node3D. Beyond `lod_at` metres from the camera the low model is drawn instead (0: detailed only;
## `force_lod`: low only). Materials pass through the same clamp as every other weapon.
static func spawn(id: String, lod_at: float = 9.0, force_lod: bool = false, mod: Dictionary = {}) -> Node3D:
	if not exists(id):
		return null
	var root := Node3D.new()
	root.name = id
	var parts := mod.has("blade_tier") or mod.has("grip_tier")
	var def: Dictionary = info(id).get("default_mod", {})
	var bt := clampi(int(mod.get("blade_tier", def.get("blade_tier", 0))), 0, 3)
	var gt := clampi(int(mod.get("grip_tier", def.get("grip_tier", 0))), 0, 3)
	var hid := id if bool(mod.get("old_hilt", false)) else _key(id)
	var hybrid := bool(manifest().get(hid, {}).get("hybrid", false))
	if hybrid:
		def = manifest()[hid].get("default_mod", def)
		if not mod.has("blade_tier") or not ResourceLoader.exists("%s%s__blade%d.glb" % [DIR, hid, bt]):
			bt = int(def.get("blade_tier", 0))
		# a modelled blade seated in a generated hilt: always joined from parts; the hilt has one form, and the
		# upper handle tiers are gold rings laid over its grip
		_add(root, "%s__blade%d" % [hid, bt], lod_at, force_lod)
		_add(root, hid + "__hilt0", lod_at, force_lod)
		if gt >= 2 and ResourceLoader.exists("%s%s__rings%d.glb" % [DIR, hid, gt]):
			_add(root, "%s__rings%d" % [hid, gt], lod_at, force_lod)
	elif parts and ResourceLoader.exists("%s%s__blade%d.glb" % [DIR, id, bt]):
		_add(root, "%s__blade%d" % [id, bt], lod_at, force_lod)
		_add(root, "%s__hilt%d" % [id, gt], lod_at, force_lod)
	else:
		_add(root, id, lod_at, force_lod)
	Look.sanitise(root, "weapon")
	if hybrid:
		_match_blade(root, manifest()[hid])
	awaken(root, false)
	if not mod.is_empty():
		apply_mod(root, mod)
	return root

## Hybrids: brings the blade's steel to the generated hilt's metal (manifest `blade_tint`, `blade_rough_max`,
## measured from the hilt's own textures) so the two read as one object. Ore tints multiply on top of this.
static func _match_blade(root: Node3D, i: Dictionary) -> void:
	var t: Array = i.get("blade_tint", [1.0, 1.0, 1.0])
	var tint := Color(float(t[0]), float(t[1]), float(t[2]))
	root.set_meta("blade_base_tint", tint)
	for e: Array in _surfaces(root):
		var mi: MeshInstance3D = e[0]
		var mname: String = e[2]
		var cur: Material = mi.get_active_material(e[1])
		if mname == "edge" and cur is BaseMaterial3D:
			var d: BaseMaterial3D = cur.duplicate()
			d.albedo_color = Color(d.albedo_color.r * tint.r, d.albedo_color.g * tint.g, d.albedo_color.b * tint.b)
			mi.set_surface_override_material(e[1], d)
		elif (mname == "blade" or mname == "blade_groove" or mname.begins_with("engrave_")) and cur is ShaderMaterial:
			var sm: ShaderMaterial = cur.duplicate()
			var base: Color = sm.get_shader_parameter("tint")
			sm.set_shader_parameter("tint", Color(base.r * tint.r, base.g * tint.g, base.b * tint.b, 1.0))
			sm.set_shader_parameter("rough_max", float(i.get("blade_rough_max", 1.0)))
			mi.set_surface_override_material(e[1], sm)

static func _surfaces(root: Node3D) -> Array:
	var out: Array = []           # [MeshInstance3D, surface, material name]
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			out.append([mi, s, m.resource_name if m else ""])
	return out

## Ore and sharpening: material settings on the blade's own surfaces (flats, groove, engraving, edge bevel).
static func apply_mod(root: Node3D, mod: Dictionary) -> void:
	var ores: Dictionary = manifest().get("_mods", {}).get("ores", {})
	var o: Array = ores.get(str(mod.get("ore", "steel")), [1.0, 1.0, 1.0])
	var tint := Color(float(o[0]), float(o[1]), float(o[2]))
	if mod.get("tint") is Color:
		tint = mod.tint            # a metal the manifest's palette does not have
	var sharp := bool(mod.get("sharpened", true))
	var bb: Color = root.get_meta("blade_base_tint", Color.WHITE)      # hybrids: the hilt's metal, under the ore
	for e: Array in _surfaces(root):
		var mi: MeshInstance3D = e[0]
		var mname: String = e[2]
		var cur: Material = mi.get_active_material(e[1])
		if mname == "edge" and cur is BaseMaterial3D:
			var d: BaseMaterial3D = cur.duplicate()
			d.albedo_color = Color(tint.r * bb.r * (0.80 if sharp else 0.6), tint.g * bb.g * (0.81 if sharp else 0.61), tint.b * bb.b * (0.83 if sharp else 0.63))
			d.roughness = 0.3 if sharp else 0.52
			mi.set_surface_override_material(e[1], d)
		elif (mname == "blade" or mname == "blade_groove" or mname.begins_with("engrave_")) and cur is ShaderMaterial and tint != Color.WHITE:
			var sm: ShaderMaterial = cur.duplicate()
			var base: Color = sm.get_shader_parameter("tint")
			sm.set_shader_parameter("tint", Color(base.r * tint.r, base.g * tint.g, base.b * tint.b, 1.0))
			mi.set_surface_override_material(e[1], sm)

## Light channels are part of the engraving and stay dark until the weapon is awakened (Recall, relic states).
static func awaken(root: Node3D, on: bool, energy: float = 1.0) -> void:
	for e: Array in _surfaces(root):
		if e[2] != "glow":
			continue
		var mi: MeshInstance3D = e[0]
		var src: Material = mi.mesh.surface_get_material(e[1])
		if not (src is BaseMaterial3D):
			continue
		var d: BaseMaterial3D = src.duplicate()
		d.emission_enabled = on
		d.emission_energy_multiplier = (src as BaseMaterial3D).emission_energy_multiplier * energy
		if not on:
			d.albedo_color = Color(0.05, 0.06, 0.07)
			d.metallic = 0.6
			d.roughness = 0.5
		mi.set_surface_override_material(e[1], d)

## Usable blade beyond the hand, as FighterRig.weapon_len expects.
static func reach(id: String) -> float:
	return float(info(id).get("tip", 1.0))
