class_name Backdrop
extends Node3D
## A living 3D scene behind the menus: a region's environment, the knight
## wearing whatever is equipped, and a slowly drifting camera.

var arena: Arena
var rig: FighterRig
var cam: Camera3D
var key: SpotLight3D
var cam_pos := Vector3(1.6, 1.5, 4.2)
var cam_look := Vector3(-0.4, 1.15, 0)
var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var _clock := 0.0
var props: Node3D
var knight_yaw := PI * 0.92       # kept across rebuilds; the equipment screen turns it by drag
var forge: Node3D                 # Orren's anvil, built the first time the forge is used

func build(theme: String, with_knight: bool = true) -> void:
	arena = Arena.new()
	add_child(arena)
	arena.build(theme)
	props = Node3D.new()
	add_child(props)
	key = SpotLight3D.new()
	key.light_color = Color(arena.theme.sun).lerp(Color.WHITE, 0.5)
	key.light_energy = 5.0
	key.spot_range = 16.0
	key.spot_angle = 40.0
	add_child(key)
	key.position = Vector3(4.0, 6.0, 5.0)
	key.look_at(Vector3(0, 1.0, 0))
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.make_current()
	_pos = cam_pos
	_look = cam_look
	if with_knight:
		refresh_knight()

## Rebuilds the knight from what is equipped. `preview` is a profile to dress it from instead
## (the equipment screen's "what if"), and `tint` overrides the plate colour for that preview.
func refresh_knight(preview: Dictionary = {}, tint: String = "") -> void:
	if rig:
		rig.queue_free()
	rig = FighterRig.new()
	add_child(rig)
	var look := {"metal": "#4a4038", "cloth": "#3d0f0f", "cape": true, "weapon": "sword", "helm": "kettle", "eye": "#000000", "shield": {"color": "#4a3a2a"}}
	if not Game.profile.is_empty():
		var real: Dictionary = Game.profile
		if not preview.is_empty():
			Game.profile = preview
		look = Duel.player_look()
		Game.profile = real
		if tint != "" and look.has("skin_tint"):      # a suit with its own model keeps its own colours
			look["metal"] = tint
			look["skin_tint"] = tint
	rig.build(look, false)
	rig.rotation.y = knight_yaw
	if rig.skin and look.has("skin_tint"):
		# The rig's own tint keeps only the hue of the plate, so dark iron and bright steel look alike.
		# Here the metal's lightness is kept too, so a change of armour can be seen.
		var plate := Color.WHITE.lerp(Color(str(look.skin_tint)), 0.6)
		for mi in rig.skin.root.find_children("*", "MeshInstance3D", true, false):
			for surf in mi.mesh.get_surface_count():
				var mat = mi.get_surface_override_material(surf)
				if mat is BaseMaterial3D:
					mat.albedo_color = plate

func turn_knight(by: float) -> void:
	knight_yaw = wrapf(knight_yaw + by, -PI, PI)
	if rig:
		rig.rotation.y = knight_yaw

## Orren's anvil and a work light, placed once. Returns the node; its "Top" child is where the piece lies.
func forge_spot(at: Vector3) -> Node3D:
	if forge:
		return forge
	forge = Node3D.new()
	add_child(forge)
	forge.position = at
	var iron := Look.flat(Color("#2b2a2c"), 0.55, 0.85)
	_box(forge, Vector3(0.5, 0.5, 0.4), Vector3(0, 0.25, 0), Look.flat(Color("#3a2a1c"), 0.9))
	_box(forge, Vector3(0.34, 0.1, 0.24), Vector3(0, 0.55, 0), iron)
	_box(forge, Vector3(0.22, 0.14, 0.18), Vector3(0, 0.67, 0), iron)
	_box(forge, Vector3(0.74, 0.12, 0.26), Vector3(0.04, 0.8, 0), iron)
	_box(forge, Vector3(0.2, 0.07, 0.16), Vector3(0.5, 0.8, 0), iron)
	var top := Node3D.new()
	top.name = "Top"
	top.position = Vector3(0, 0.875, 0)
	forge.add_child(top)
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color("#ffb060")
	glow.light_energy = 1.2
	glow.omni_range = 4.0
	glow.position = Vector3(0.2, 1.5, 0.9)
	forge.add_child(glow)
	return forge

func move_camera(pos: Vector3, look: Vector3, snap: bool = false) -> void:
	cam_pos = pos
	cam_look = look
	if snap:
		_pos = pos
		_look = look

func clear_props() -> void:
	for c in props.get_children():
		c.queue_free()

## Drops a simple interactable (chest / shrine / lever) into the scene.
func add_prop(kind: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	props.add_child(n)
	n.position = at
	var wood := Look.flat(Color("#3a2a1c"), 0.85)
	var iron := Look.flat(Color("#2a2826"), 0.5, 0.8)
	var gold := Look.glow(Color(arena.theme.fire), 2.5)
	match kind:
		"treasure":
			_box(n, Vector3(0.9, 0.5, 0.55), Vector3(0, 0.25, 0), wood)
			var lid := Node3D.new()
			lid.name = "Lid"
			lid.position = Vector3(0, 0.5, -0.27)
			n.add_child(lid)
			_box(lid, Vector3(0.94, 0.16, 0.58), Vector3(0, 0.08, 0.28), wood)
			for x: float in [-0.3, 0.3]:
				_box(n, Vector3(0.06, 0.54, 0.58), Vector3(x, 0.26, 0), iron)
			_box(n, Vector3(0.1, 0.12, 0.04), Vector3(0, 0.44, 0.29), gold)
		"shrine":
			_box(n, Vector3(0.9, 0.9, 0.5), Vector3(0, 0.45, 0), Look.stone(Color("#5a564e")))
			_box(n, Vector3(0.5, 1.3, 0.25), Vector3(0, 1.4, -0.1), Look.stone(Color("#5a564e")))
			_box(n, Vector3(0.04, 0.2, 0.04), Vector3(0, 1.0, 0.1), Look.flat(Color("#d8cfb8")))
			_box(n, Vector3(0.025, 0.05, 0.025), Vector3(0, 1.13, 0.1), gold)
			var l := OmniLight3D.new()
			l.light_color = Color(arena.theme.fire)
			l.light_energy = 1.6
			l.omni_range = 5.0
			l.position = Vector3(0, 1.3, 0.4)
			n.add_child(l)
		"pouch":
			var leather := Look.flat(Color("#5a3e24"), 0.8)
			var bag := SphereMesh.new()
			bag.radius = 0.16
			bag.height = 0.3
			var mi := MeshInstance3D.new()
			mi.mesh = bag
			mi.position = Vector3(0, 0.13, 0)
			mi.scale = Vector3(1, 0.85, 1)
			mi.material_override = leather
			n.add_child(mi)
			_box(n, Vector3(0.1, 0.08, 0.1), Vector3(0, 0.3, 0), leather)
			_box(n, Vector3(0.05, 0.02, 0.05), Vector3(0.12, 0.02, 0.1), gold)
			_box(n, Vector3(0.05, 0.02, 0.05), Vector3(-0.1, 0.02, 0.14), gold)
		"marker":
			# a ring of light on the ground: a way onward
			var ring := TorusMesh.new()
			ring.inner_radius = 0.42
			ring.outer_radius = 0.5
			ring.rings = 28
			ring.ring_segments = 4
			var rm := MeshInstance3D.new()
			rm.mesh = ring
			rm.scale.y = 0.15
			rm.position.y = 0.03
			rm.material_override = Look.glow(Color("#9fd0ff"), 2.2)
			n.add_child(rm)
			var l2 := OmniLight3D.new()
			l2.light_color = Color("#9fd0ff")
			l2.light_energy = 0.9
			l2.omni_range = 2.5
			l2.position.y = 0.5
			n.add_child(l2)
		"lever":
			_box(n, Vector3(0.7, 0.3, 0.7), Vector3(0, 0.15, 0), iron)
			var arm := Node3D.new()
			arm.name = "Arm"
			arm.position = Vector3(0, 0.3, 0)
			arm.rotation.z = 0.6
			n.add_child(arm)
			_box(arm, Vector3(0.07, 1.1, 0.07), Vector3(0, 0.55, 0), iron)
			_box(arm, Vector3(0.14, 0.14, 0.14), Vector3(0, 1.1, 0), gold)
	return n

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)

func _process(delta: float) -> void:
	_clock += delta
	var k := 1.0 - exp(-delta * 1.6)
	_pos = _pos.lerp(cam_pos, k)
	_look = _look.lerp(cam_look, k)
	var drift := Vector3(sin(_clock * 0.23) * 0.12, sin(_clock * 0.31) * 0.05, cos(_clock * 0.19) * 0.1)
	if Game.settings.reduce_motion:
		drift = Vector3.ZERO
	cam.position = _pos + drift
	cam.look_at(_look)
