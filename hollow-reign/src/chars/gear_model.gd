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

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var f := FileAccess.open(DIR + "gear_manifest.json", FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_manifest = d
	return _manifest

## Item ids in the manifest, optionally of one class ("sword" matches every blade class).
static func ids(kind: String = "") -> Array:
	var out: Array = []
	for k: String in manifest():
		if k.begins_with("_"):
			continue
		var cls := str(manifest()[k].get("class", ""))
		if kind == "" or (kind == "shield") == (cls == "shield"):
			out.append(k)
	return out

static func exists(id: String) -> bool:
	return ResourceLoader.exists(DIR + id + ".glb")

static func info(id: String) -> Dictionary:
	return manifest().get(id, {})

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
	if parts and ResourceLoader.exists("%s%s__blade%d.glb" % [DIR, id, bt]):
		_add(root, "%s__blade%d" % [id, bt], lod_at, force_lod)
		_add(root, "%s__hilt%d" % [id, gt], lod_at, force_lod)
	else:
		_add(root, id, lod_at, force_lod)
	Look.sanitise(root, "weapon")
	awaken(root, false)
	if not mod.is_empty():
		apply_mod(root, mod)
	return root

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
	var sharp := bool(mod.get("sharpened", true))
	for e: Array in _surfaces(root):
		var mi: MeshInstance3D = e[0]
		var mname: String = e[2]
		var cur: Material = mi.get_active_material(e[1])
		if mname == "edge" and cur is BaseMaterial3D:
			var d: BaseMaterial3D = cur.duplicate()
			d.albedo_color = Color(tint.r * (0.80 if sharp else 0.6), tint.g * (0.81 if sharp else 0.61), tint.b * (0.83 if sharp else 0.63))
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
