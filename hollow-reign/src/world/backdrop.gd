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

func refresh_knight() -> void:
	if rig:
		rig.queue_free()
	rig = FighterRig.new()
	add_child(rig)
	rig.build(Duel.player_look() if not Game.profile.is_empty() else {"metal": "#4a4038", "cloth": "#3d0f0f", "cape": true, "weapon": "sword", "helm": "kettle", "eye": "#000000", "shield": {"color": "#4a3a2a"}}, false)
	rig.rotation.y = PI * 0.92

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
	cam.position = _pos + drift
	cam.look_at(_look)
