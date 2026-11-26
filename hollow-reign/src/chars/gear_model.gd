class_name GearModel
extends RefCounted
## Loads the hand-modelled equipment in assets/models/gear/ (built by tools/gear_gen.py).
## These models are already in the rig's conventions and in metres, so nothing is measured or rescaled:
##   swords  : origin at the centre of the main hand, +Y to the tip, guard along X, flat of the blade faces Z
##   shields : origin at the centre of the hand grip, +Y up, front faces -Z, +X is the bearer's right
## Dimensions the rig needs (blade length beyond the hand, pommel drop, board centre) are in gear_manifest.json.

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

static func exists(id: String) -> bool:
	return ResourceLoader.exists(DIR + id + ".glb")

static func info(id: String) -> Dictionary:
	return manifest().get(id, {})

## The item as a Node3D. Beyond `lod_at` metres from the camera the low model is drawn instead (0: detailed only;
## `force_lod`: low only). Materials pass through the same clamp as every other weapon.
static func spawn(id: String, lod_at: float = 9.0, force_lod: bool = false) -> Node3D:
	if not exists(id):
		return null
	var root := Node3D.new()
	root.name = id
	var has_lod := ResourceLoader.exists(DIR + id + "_lod.glb")
	if not (force_lod and has_lod):
		var hi: Node3D = (load(DIR + id + ".glb") as PackedScene).instantiate()
		root.add_child(hi)
		if lod_at > 0.0 and has_lod:
			for mi: MeshInstance3D in hi.find_children("*", "MeshInstance3D", true, false):
				mi.visibility_range_end = lod_at
				mi.visibility_range_end_margin = 0.5
	if has_lod and (force_lod or lod_at > 0.0):
		var lo: Node3D = (load(DIR + id + "_lod.glb") as PackedScene).instantiate()
		root.add_child(lo)
		if not force_lod:
			for mi: MeshInstance3D in lo.find_children("*", "MeshInstance3D", true, false):
				mi.visibility_range_begin = lod_at
				mi.visibility_range_begin_margin = 0.5
	Look.sanitise(root, "weapon")
	return root

## Usable blade beyond the hand, as FighterRig.weapon_len expects.
static func reach(id: String) -> float:
	return float(info(id).get("tip", 1.0))
