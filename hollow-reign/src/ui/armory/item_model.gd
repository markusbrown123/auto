class_name ItemModel
extends RefCounted
## The 3D piece shown for an item in the armoury's carousel and in Inspect, and the models it needs.
## Weapons and shields are their real hand-held models; a chest piece is its whole suit on a stand, because
## a suit is one model. Helms, gauntlets, greaves, rings and relics have no geometry: `has_model` is false
## for them and the screens draw a medallion instead.
## Loading never blocks: `want` starts a background load, `ready` says when `build` can run without a hitch.

static var keep := 10            # loaded scenes held for reuse; older ones are let go (the screen lowers it for whole suits)
static var _held := {}           # path -> PackedScene
static var _order: Array = []    # least recently used first
static var _pending := {}        # path -> true

const SWAY := 1.05               # how far (radians) a blade on show turns to either side of its flat
static var _env: Environment

## The light a piece is looked at in: a soft box all the way round for the metal to reflect (a polished flat with
## nothing to mirror goes black), over a transparent ground. Shared by the carousel, the previews and Inspect.
static func studio_env() -> Environment:
	if _env:
		return _env
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.42, 0.45, 0.52)
	sky_mat.sky_horizon_color = Color(0.66, 0.67, 0.7)
	sky_mat.ground_horizon_color = Color(0.5, 0.5, 0.52)
	sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.23)
	sky_mat.sky_curve = 0.35
	sky_mat.ground_curve = 0.25
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#4a4640")
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env = env
	return env

## The name the item's hand-modelled piece is built under in assets/models/gear/, "" when it has none.
static func gear_id(it: Dictionary) -> String:
	var g := str(it.get("gear_id", ""))
	return g if g != "" and bool(it.get("gear_ready", false)) and GearModel.exists(g) else ""

static func _has_parts(g: String) -> bool:
	return ResourceLoader.exists("%s%s__blade0.glb" % [GearModel.DIR, g])

## The forge state of a weapon as the model wants it: {blade_tier, grip_tier, ore, keen}. From the profile given
## (the player's by default); an item not held is shown as it leaves the smith: unworked.
static func gear_mod(it: Dictionary, p: Dictionary = Game.profile) -> Dictionary:
	if str(it.get("slot", "")) != "weapon" or gear_id(it) == "":
		return {}
	var v: Dictionary = Game.weapon_mods(str(it.id), p).visual
	var ore := str(v.ore)
	if ore == "cored" or ore == "":
		ore = str(v.ore_id) if str(v.ore_id) != "" else "steel"
	return {"blade_tier": int(v.blade_tier), "grip_tier": int(v.grip_tier), "ore": ore, "keen": bool(v.keen)}

## A short text that changes whenever the item would be drawn differently (cache keys).
static func sig(it: Dictionary, mod = null) -> String:
	var m: Dictionary = mod if mod is Dictionary else gear_mod(it)
	return "" if m.is_empty() else "%d%d%s%s" % [int(m.get("blade_tier", 0)), int(m.get("grip_tier", 0)), str(m.get("ore", "")), "k" if m.get("keen", false) else ""]

## The colour an ore gives a blade (GearModel's palette), for swatches.
static func ore_color(ore: String) -> Color:
	if GearModel.ORE_OWN.has(ore):
		var c = GearModel.ORE_OWN[ore]
		return c if c is Color else Color(float(c[0]), float(c[1]), float(c[2]))
	var o: Array = GearModel.manifest().get("_mods", {}).get("ores", {}).get(str(GearModel.ORE_GEAR.get(ore, "steel")), [1.0, 1.0, 1.0])
	return Color(float(o[0]), float(o[1]), float(o[2]))

## The hand-modelled sword in a forge state ({blade_tier, grip_tier, ore, keen}), in the model's own conventions
## (metres, +Y to the tip): built exactly as the rig builds the one in the knight's hand.
static func gear_sword(g: String, mod: Dictionary) -> Node3D:
	return GearModel.spawn(g, 0.0, false, GearModel.mod_from_visual(g, {"blade_tier": int(mod.get("blade_tier", 0)), "grip_tier": int(mod.get("grip_tier", 0)),
		"ore": str(mod.get("ore", "steel")), "ore_id": "", "keen": bool(mod.get("keen", false))}))

## The model files this item is drawn from ([] when it has none).
static func paths(it: Dictionary, body: String = "m", mod = null) -> Array:
	var g := gear_id(it)
	if g != "" and str(it.get("slot", "")) in ["weapon", "shield"]:
		if str(it.slot) == "weapon" and _has_parts(g):
			var m: Dictionary = mod if mod is Dictionary else gear_mod(it)
			return ["%s%s__blade%d.glb" % [GearModel.DIR, g, clampi(int(m.get("blade_tier", 0)), 0, 3)], "%s%s__hilt%d.glb" % [GearModel.DIR, g, clampi(int(m.get("grip_tier", 0)), 0, 3)]]
		return [GearModel.DIR + g + ".glb"]
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
	while _order.size() > keep:
		_held.erase(_order.pop_front())
	return all

## True when every file is loaded or already on its way.
static func known(list: Array) -> bool:
	for p: String in list:
		if not _held.has(p) and not _pending.has(p):
			return false
	return true

## Lets go of every scene held here (the armoury calls it on the way out); what is on screen keeps its own.
static func clear() -> void:
	_held.clear()
	_order.clear()

static func loading() -> int:
	return _pending.size()

## The piece, about one unit across and centred, under a node named "Pivot" that the caller may turn.
## Returns null when the item has no model. `dark` gives the unlit shape only, for things not yet found.
static func build(it: Dictionary, body: String = "m", dark: bool = false, mod = null) -> Node3D:
	var list := paths(it, body, mod)
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
	var g := gear_id(it)
	match str(it.slot) if g == "" or str(it.slot) == "chest" else "gear_" + str(it.slot):
		"gear_weapon":
			# life size, +Y to the tip, origin in the hand: one-handed blades keep their sizes against each other
			var info: Dictionary = GearModel.info(g)
			var tip: float = float(info.get("tip", 0.9))
			var pom: float = float(info.get("pommel", 0.1))
			var k: float = 1.3 / maxf(tip + pom, 1.1)
			var m: Dictionary = mod if mod is Dictionary else gear_mod(it)
			var n: int = 2 if bool(info.get("pair", false)) else 1
			for i in n:
				var arm := Node3D.new()
				pivot.add_child(arm)
				arm.rotation.z = 0.0 if n == 1 else (0.22 if i == 0 else -0.22)
				var sword := gear_sword(g, m)
				if sword == null:
					break
				arm.add_child(sword)
				sword.scale = Vector3(-k if i == 1 and bool(info.get("mirror_left", false)) else k, k, k)
				sword.position = Vector3(0.0 if n == 1 else (0.12 if i == 0 else -0.12), -(tip - pom) * 0.5 * k, 0.04 * i)
				ok = true
			tilt.rotation.z = -PI * (0.26 if n == 1 else 0.0)
		"gear_shield":
			var info2: Dictionary = GearModel.info(g)
			var sh := GearModel.spawn(g, 0.0)
			if sh:
				var k2: float = 0.98 / maxf(maxf(float(info2.get("width", 0.5)), float(info2.get("height", 0.5))), 0.3)
				var bc: Array = info2.get("board_centre", [0.0, 0.0, 0.0])
				var face := Basis(Vector3.UP, PI)          # the model's front is -Z; the viewer stands at +Z
				sh.transform = Transform3D(face.scaled(Vector3.ONE * k2), -(face * Vector3(float(bc[0]), float(bc[1]), float(bc[2]))) * k2)
				pivot.add_child(sh)
				ok = true
		"weapon":
			var cls: String = it.cls
			var wm: Dictionary = Duel.weapon_model(str(it.id))
			var grip: float = float(PropModel.GRIP.get(cls, 0.11))
			var kk: float = 1.3 / float(PropModel.LENGTH.get(cls, 1.1))
			var nn: int = 2 if cls == "dual" else 1
			for i in nn:
				var arm := Node3D.new()
				pivot.add_child(arm)
				arm.rotation.z = 0.0 if nn == 1 else (0.2 if i == 0 else -0.2)
				var holder := Node3D.new()
				arm.add_child(holder)
				holder.position = Vector3(0.0 if nn == 1 else (0.12 if i == 0 else -0.12), -1.3 * (0.5 - grip), 0.04 * i)
				ok = PropModel.weapon(holder, wm.weapon_model, cls, wm.get("weapon_tint"), kk) > 0.0
			tilt.rotation.z = -PI * (0.26 if nn == 1 else 0.0)      # point up and to the right, as on a rack
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
