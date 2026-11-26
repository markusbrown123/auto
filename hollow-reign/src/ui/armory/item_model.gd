class_name ItemModel
extends RefCounted
## The 3D piece shown for an item in the armoury's carousel and in Inspect, and the models it needs.
## Weapons and shields are their real hand-held models; a chest piece is its whole suit on a stand, because
## a suit is one model. Helms, gauntlets, greaves, rings and relics have no geometry: `has_model` is false
## for them and the screens draw a medallion instead.
## Loading never blocks: `want` starts a background load, `ready` says when `build` can run without a hitch.

const KEEP := 10                 # loaded scenes held for reuse; older ones are let go
static var _held := {}           # path -> PackedScene
static var _order: Array = []    # least recently used first
static var _pending := {}        # path -> true

## The model files this item is drawn from ([] when it has none).
static func paths(it: Dictionary, body: String = "m") -> Array:
	match str(it.get("slot", "")):
		"weapon":
			var p: String = Duel.weapon_model(str(it.id)).weapon_model
			return [p] if ResourceLoader.exists(p) else []
		"shield":
			var p2 := "res://assets/models/%s.glb" % str(it.id)
			return [p2] if ResourceLoader.exists(p2) else []
		"chest":
			return [suit_path(it, body)]
	return []

## A chest piece's suit model; the plain knight when the suit has none of its own (shown in the piece's metal).
static func suit_path(it: Dictionary, body: String) -> String:
	var p := "res://assets/models/knight_%s_%s.glb" % [body, str(it.id).trim_prefix("a_").trim_suffix("_chest")]
	return p if ResourceLoader.exists(p) else "res://assets/models/knight_%s.glb" % body

static func has_model(it: Dictionary, body: String = "m") -> bool:
	return not paths(it, body).is_empty()

## True when a chest piece changes the knight's geometry and not only its plate colour.
static func is_full_suit(it: Dictionary, body: String) -> bool:
	return str(it.get("slot", "")) == "chest" and not suit_path(it, body).ends_with("knight_%s.glb" % body)

static func want(list: Array) -> void:
	for p: String in list:
		if not _held.has(p) and not _pending.has(p) and ResourceLoader.exists(p):
			if ResourceLoader.load_threaded_request(p) == OK:
				_pending[p] = true

static func ready(list: Array) -> bool:
	var all := true
	for p: String in list:
		if _held.has(p):
			_order.erase(p)
			_order.append(p)
			continue
		if not _pending.has(p):
			want([p])
		if _pending.has(p):
			var st := ResourceLoader.load_threaded_get_status(p)
			if st == ResourceLoader.THREAD_LOAD_LOADED:
				_held[p] = ResourceLoader.load_threaded_get(p)
				_order.append(p)
				_pending.erase(p)
				continue
			elif st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_pending.erase(p)      # failed: treat as nothing to wait for
				continue
		all = false
	while _order.size() > KEEP:
		_held.erase(_order.pop_front())
	return all

## True when every file is loaded or already on its way.
static func known(list: Array) -> bool:
	for p: String in list:
		if not _held.has(p) and not _pending.has(p):
			return false
	return true

static func loading() -> int:
	return _pending.size()

## The piece, about one unit across and centred, under a node named "Pivot" that the caller may turn.
## Returns null when the item has no model. `dark` gives the unlit shape only, for things not yet found.
static func build(it: Dictionary, body: String = "m", dark: bool = false) -> Node3D:
	var list := paths(it, body)
	if list.is_empty():
		return null
	var root := Node3D.new()
	var tilt := Node3D.new()
	tilt.name = "Tilt"
	root.add_child(tilt)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	tilt.add_child(pivot)
	var ok := false
	match str(it.slot):
		"weapon":
			var cls: String = it.cls
			var m: Dictionary = Duel.weapon_model(str(it.id))
			var grip: float = float(PropModel.GRIP.get(cls, 0.11))
			var k: float = 1.3 / float(PropModel.LENGTH.get(cls, 1.1))
			var n: int = 2 if cls == "dual" else 1
			for i in n:
				var arm := Node3D.new()
				pivot.add_child(arm)
				arm.rotation.z = 0.0 if n == 1 else (0.2 if i == 0 else -0.2)
				var holder := Node3D.new()
				arm.add_child(holder)
				holder.position = Vector3(0.0 if n == 1 else (0.12 if i == 0 else -0.12), -1.3 * (0.5 - grip), 0.04 * i)
				ok = PropModel.weapon(holder, m.weapon_model, cls, m.get("weapon_tint"), k) > 0.0
			tilt.rotation.z = -PI * (0.26 if n == 1 else 0.0)      # point up and to the right, as on a rack
		"shield":
			ok = PropModel.shield(pivot, list[0], 0.98)
		"chest":
			ok = _suit(pivot, list[0], it, body)
	if not ok:
		root.free()
		return null
	if dark:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.035, 0.036, 0.042)
		mat.roughness = 0.55
		mat.metallic = 0.3
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
	return root

## A suit on its stand: the whole model, 1.12 units tall, feet at -0.56, facing +Z, arms let down from the rest pose.
static func _suit(parent: Node3D, path: String, it: Dictionary, body: String) -> bool:
	var scene: PackedScene = load(path)
	if scene == null:
		return false
	var inst: Node3D = scene.instantiate()
	parent.add_child(inst)
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return true
	var sk: Skeleton3D = skels[0]
	var idx := {}
	for i in sk.get_bone_count():
		var nm := sk.get_bone_name(i)
		idx[nm.get_slice(":", nm.get_slice_count(":") - 1).trim_prefix("mixamorig_").trim_prefix("mixamorig")] = i
	for need: String in ["Head", "LeftArm", "RightArm", "LeftFoot", "LeftForeArm", "RightForeArm"]:
		if not idx.has(need):
			return true
	var to_root := PropModel._to_root(sk, inst) if sk != inst else Transform3D.IDENTITY
	var at := func(b: String) -> Vector3: return to_root * sk.get_bone_global_rest(idx[b]).origin
	var head: Vector3 = at.call("Head")
	var foot: Vector3 = at.call("LeftFoot")
	var across: Vector3 = at.call("LeftArm") - at.call("RightArm")
	var yaw := atan2(across.z, across.x)
	var k: float = 1.12 / maxf((head.y - foot.y) * 1.16, 0.01)
	var turn := Basis(Vector3.UP, yaw)
	var mid: Vector3 = (at.call("LeftArm") + at.call("RightArm")) * 0.5
	inst.transform = Transform3D(turn.scaled(Vector3.ONE * k), -(turn * Vector3(mid.x, foot.y - (head.y - foot.y) * 0.04, mid.z)) * k - Vector3(0, 0.56, 0))
	# arms down by the sides: turn each upper arm about the body's front-to-back axis until it hangs
	var fwd_local: Vector3 = (to_root.basis.inverse() * (turn.inverse() * Vector3(0, 0, 1))).normalized()
	for side: String in ["Left", "Right"]:
		var i: int = idx[side + "Arm"]
		var g := sk.get_bone_global_rest(i)
		var along: Vector3 = (sk.get_bone_global_rest(idx[side + "ForeArm"]).origin - g.origin).normalized()
		var down: Vector3 = (to_root.basis.inverse() * (turn.inverse() * Vector3(0.22 if side == "Left" else -0.22, -1, 0))).normalized()
		var q := Quaternion(along, down) if along.dot(down) > -0.999 else Quaternion(fwd_local, PI)
		sk.set_bone_global_pose(i, Transform3D(Basis(q) * g.basis, g.origin))
	if not is_full_suit(it, body):
		var plate := Color.WHITE.lerp(Color(str(it.get("look", {}).get("metal", "#aeb2b8"))), 0.6)
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m3: MeshInstance3D = mi
			for s in m3.mesh.get_surface_count():
				var mat = m3.get_active_material(s)
				if mat is BaseMaterial3D:
					var dup: BaseMaterial3D = mat.duplicate()
					dup.albedo_color = plate
					m3.set_surface_override_material(s, dup)
	return true
