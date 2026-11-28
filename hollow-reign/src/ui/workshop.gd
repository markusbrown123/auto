class_name Workshop
extends Node3D
## Orren's workshop: the room the shop is held in (KnightStage "forge" builds it round the knight). Placed in the
## stage's own space: the knight stands at the origin facing +Z, the camera is in front (+Z) and to the right, so
## the room is seen in the band of screen left of the panels, and widens with depth. Everything in the band is kept
## low and dark directly behind the knight, so the gear still reads against it.
##   back left    the forge: brick hearth, coals and a hood, its glow the warm light behind the figure
##   back         racks of swords, shields on the wall, a grindstone, sacks and an ore crate
##   left         armour on stands (a helm and breastplate on each, from the modular armour parts), a shelf of helms
##   right        Orren at his anvil, a bench beside him; candles; the old-technology workbench (a lens arm and a
##                screen that still holds a little light), cables along the floor
## Primitives and models already in the project only.

const FLOOR_Y := 0.0
const ORREN_AT := Vector3(0.28, 0.0, -2.95)
const ANVIL_AT := Vector3(0.22, 0.0, -2.42)

var orren: Orren
var _forge_light: OmniLight3D
var _candles: Array = []
var _sparks: CPUParticles3D
var _strike_light: OmniLight3D
var _clock := 0.0
var _wood: StandardMaterial3D
var _iron: StandardMaterial3D
var _dark_iron: StandardMaterial3D
var _brick: StandardMaterial3D
var _stone: StandardMaterial3D
var _leather: StandardMaterial3D
var _brass: StandardMaterial3D

func _ready() -> void:
	_wood = Look.flat(Color("#3b2a1d"), 0.86)
	_iron = Look.flat(Color("#4a4846"), 0.42, 0.8)
	_dark_iron = Look.flat(Color("#232222"), 0.55, 0.75)
	_brick = Look.stone(Color("#5b3a2c"), 0.6, 0.9, "brick")
	_stone = Look.stone(Color("#3b3733"), 0.3, 0.9)
	_leather = Look.flat(Color("#4a3322"), 0.8)
	_brass = Look.flat(Color("#9a7442"), 0.4, 0.85)
	_room()
	_forge(Vector3(-3.6, 0, -4.4))
	_racks()
	_stands()
	_anvil(ANVIL_AT)
	_bench(Vector3(1.05, 0, -2.85))
	_tech_bench(Vector3(-1.6, 0, -4.2))
	_grindstone(Vector3(-0.2, 0, -4.3))
	_candle(Vector3(0.95, 0.96, -2.7))
	_candle(Vector3(1.18, 0.96, -2.95))
	_candle(Vector3(-2.75, 1.62, -4.55))
	_candle(Vector3(-1.2, 0.98, -4.0))
	orren = Orren.new()
	add_child(orren)
	orren.position = ORREN_AT
	orren.rotation.y = PI
	orren.knight_at = Vector3(0, 0, 0)
	orren.anvil_top = to_global(ANVIL_AT + Vector3(0.0, 0.8, 0.0))
	orren.struck.connect(_on_struck)
	_props_for_orren()

# ---------------------------------------------------------------- helpers
func _box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(b, pos, mat, rot, parent)

func _cyl(top: float, bottom: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, sides := 12, parent: Node3D = null) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return _mesh(c, pos, mat, rot, parent)

func _mesh(m: Mesh, pos: Vector3, mat: Material, rot: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	(parent if parent else self).add_child(mi)
	return mi

func _light(pos: Vector3, c: Color, e: float, r: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = e
	l.omni_range = r
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadow
	l.position = pos
	add_child(l)
	return l

# ---------------------------------------------------------------- the room
func _room() -> void:
	# a back wall of old stone, a beamed ceiling, the left wall; the floor is the stage's own (its pool of light)
	_box(Vector3(12, 5.0, 0.4), Vector3(-1.0, 2.5, -5.2), _stone)
	_box(Vector3(0.4, 5.0, 8.0), Vector3(-5.0, 2.5, -1.6), _stone)
	for x: float in [-4.2, -2.2, -0.2, 1.8]:
		_box(Vector3(0.22, 0.26, 7.0), Vector3(x, 3.9, -1.8), _wood)
	_box(Vector3(12, 0.2, 0.3), Vector3(-1.0, 3.75, -4.9), _wood)
	# posts in the back wall
	for x: float in [-4.6, -1.0, 2.4]:
		_box(Vector3(0.3, 3.8, 0.3), Vector3(x, 1.9, -4.9), _wood)
	# a worn floor of flags under the far half of the room (the near half is the stage's lit floor)
	var flags := _box(Vector3(12, 0.04, 4.2), Vector3(-1.0, 0.0, -3.4), Look.stone(Color("#2c2723"), 0.5, 0.95))
	flags.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# cables from the old bench along the foot of the wall
	for i in 3:
		var cable := _cyl(0.025, 0.025, 3.4, Vector3(-2.6 + i * 0.07, 0.03 + i * 0.02, -4.75 + i * 0.05), _dark_iron, Vector3(0, 0, PI * 0.5), 6)
		cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a low warm fill so nothing in the room is black
	var fill := _light(Vector3(-1.4, 2.6, -2.0), Color("#ffb878"), 0.35, 7.0)
	fill.light_specular = 0.0

func _forge(at: Vector3) -> void:
	var n := Node3D.new()
	n.position = at
	add_child(n)
	_box(Vector3(1.8, 0.9, 1.1), Vector3(0, 0.45, 0), _brick, Vector3.ZERO, n)
	_box(Vector3(1.9, 0.1, 1.2), Vector3(0, 0.92, 0), _stone, Vector3.ZERO, n)
	# the coal bed and its glow
	var coals := _box(Vector3(1.1, 0.08, 0.6), Vector3(0, 0.98, 0.05), Look.glow(Color("#ff6a1e"), 2.6), Vector3.ZERO, n)
	coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the back and the hood over it, narrowing to the flue
	_box(Vector3(1.8, 1.2, 0.3), Vector3(0, 1.55, -0.4), _brick, Vector3.ZERO, n)
	_cyl(0.35, 0.95, 1.1, Vector3(0, 2.55, -0.1), _brick, Vector3.ZERO, 4, n).rotation.y = PI * 0.25
	_box(Vector3(0.6, 2.0, 0.6), Vector3(0, 3.9, -0.15), _brick, Vector3.ZERO, n)
	# bellows at its side
	_box(Vector3(0.5, 0.18, 0.8), Vector3(1.15, 0.8, 0.1), _leather, Vector3(0, 0, 0.15), n)
	_cyl(0.03, 0.03, 0.9, Vector3(1.15, 0.6, 0.55), _wood, Vector3(0.3, 0, 0), 6, n)
	# embers rising off the coals
	var em := CPUParticles3D.new()
	em.amount = maxi(4, int(14.0 * Game.particle_scale()))
	em.lifetime = 2.4
	em.mesh = QuadMesh.new()
	(em.mesh as QuadMesh).size = Vector2(0.025, 0.025)
	em.material_override = Look.particle(Color("#ffa040"))
	em.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	em.emission_box_extents = Vector3(0.45, 0.02, 0.2)
	em.direction = Vector3.UP
	em.spread = 18.0
	em.gravity = Vector3(0, 0.25, 0)
	em.initial_velocity_min = 0.25
	em.initial_velocity_max = 0.6
	em.position = Vector3(0, 1.05, 0.05)
	n.add_child(em)
	_forge_light = _light(at + Vector3(0.3, 1.5, 0.9), Color("#ff8a3a"), 3.2, 7.5, true)
	# tools hung on the hood's side
	for i in 3:
		_cyl(0.015, 0.015, 0.7, Vector3(-1.05, 1.9 - i * 0.05, 0.1 + i * 0.16), _dark_iron, Vector3(0, 0, 0.05), 6, n)

func _racks() -> void:
	# a tall sword rack against the back wall: blades on pegs, points down
	var rack := Node3D.new()
	rack.position = Vector3(-2.3, 0, -4.85)
	add_child(rack)
	_box(Vector3(2.0, 0.08, 0.12), Vector3(0, 1.95, 0.05), _wood, Vector3.ZERO, rack)
	_box(Vector3(2.0, 0.08, 0.2), Vector3(0, 0.25, 0.08), _wood, Vector3.ZERO, rack)
	for x: float in [-0.95, 0.95]:
		_box(Vector3(0.08, 2.1, 0.12), Vector3(x, 1.05, 0.05), _wood, Vector3.ZERO, rack)
	var blades := ["w_knight_sword", "w_rusted_sword", "w_vigil_edge", "w_rime_sword", "w_dawnline", "w_throneshard"]
	for i in blades.size():
		var holder := Node3D.new()
		rack.add_child(holder)
		holder.position = Vector3(-0.75 + i * 0.3, 1.9, 0.14)
		holder.rotation = Vector3(PI, 0, 0.0)
		PropModel.weapon(holder, "res://assets/models/%s.glb" % blades[i], "sword", null, 0.95)
	# shields hung on the wall above and beside it
	var shields := ["s_garrison", "s_plank", "s_scale"]
	for i in shields.size():
		var sh := Node3D.new()
		add_child(sh)
		sh.position = Vector3(-4.2 + i * 0.75, 2.75 - (i % 2) * 0.2, -4.92)
		PropModel.shield(sh, "res://assets/models/%s.glb" % shields[i], 0.62, true)
	# a shelf of helms on the left wall
	_box(Vector3(0.35, 0.06, 1.8), Vector3(-4.62, 1.72, -3.2), _wood)
	_box(Vector3(0.35, 0.06, 1.8), Vector3(-4.62, 1.02, -3.2), _wood)
	# ore crate, sacks and a quench barrel by the anvil
	var crate := Node3D.new()
	crate.position = Vector3(-0.9, 0, -3.5)
	add_child(crate)
	_box(Vector3(0.6, 0.4, 0.45), Vector3(0, 0.2, 0), _wood, Vector3.ZERO, crate)
	for i in 6:
		var ore := SphereMesh.new()
		ore.radius = 0.08
		ore.height = 0.12
		_mesh(ore, Vector3(-0.2 + (i % 3) * 0.18, 0.43, -0.1 + (i / 3) * 0.18), Look.flat(Color("#2e2b2c"), 0.5, 0.6), Vector3(i, i * 2, 0), crate)
	var barrel := _cyl(0.27, 0.24, 0.7, Vector3(0.95, 0.35, -2.25), _wood, Vector3.ZERO, 14)
	barrel.name = "Quench"
	_cyl(0.255, 0.255, 0.02, Vector3(0.95, 0.66, -2.25), Look.flat(Color("#141a1c"), 0.1, 0.3), Vector3.ZERO, 14)
	for y: float in [0.12, 0.58]:
		_cyl(0.275, 0.275, 0.04, Vector3(0.95, y, -2.25), _dark_iron, Vector3.ZERO, 14)

## Breastplates and helms on stands, and helms on the shelf: the game's own modular armour parts, on the base knight's
## skeleton with the body itself left hidden (so only the worn pieces show).
func _stands() -> void:
	var suits := [["garrison", Vector3(-2.35, 0, -3.15), 0.5], ["ash", Vector3(-3.3, 0, -3.6), 0.35], ["black", Vector3(-4.25, 0, -3.0), 0.9]]
	for s: Array in suits:
		var st := Node3D.new()
		add_child(st)
		st.position = s[1]
		st.rotation.y = float(s[2])
		# the stand: a base, a post, a cross-piece at the shoulders
		_cyl(0.22, 0.26, 0.06, Vector3(0, 0.03, 0), _wood, Vector3.ZERO, 10, st)
		_cyl(0.03, 0.035, 1.5, Vector3(0, 0.78, 0), _wood, Vector3.ZERO, 8, st)
		_box(Vector3(0.5, 0.05, 0.05), Vector3(0, 1.45, 0), _wood, Vector3.ZERO, st)
		_armour(st, {"helm": s[0], "chest": s[0], "shoulders": s[0]}, Vector3.ZERO)
	for i in 3:
		var hs := Node3D.new()
		add_child(hs)
		hs.position = Vector3(-4.55, 1.75, -3.8 + i * 0.6)
		hs.rotation.y = PI * 0.5 + (i - 1) * 0.2
		_armour(hs, {"helm": ["vigil", "frost", "garrison"][i]}, Vector3.ZERO, true)

## One set of parts, posed as it would hang: on the base knight's skeleton at rest, the body hidden.
func _armour(parent: Node3D, wear: Dictionary, at: Vector3, helm_only := false) -> void:
	var path := ArmorParts.host_path("m")
	if not ResourceLoader.exists(path):
		return
	var host: Node3D = (load(path) as PackedScene).instantiate()
	parent.add_child(host)
	var skel: Skeleton3D = host.find_children("*", "Skeleton3D", true, false)[0]
	var head_i := -1
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).ends_with("Head"):
			head_i = i
	var head_y := (skel.global_transform * skel.get_bone_global_rest(head_i)).origin.y - parent.global_position.y
	var sc := 1.72 / maxf(head_y, 0.01)
	host.scale *= sc
	var loadout := wear.duplicate()
	loadout["body"] = "m"
	ArmorParts.dress(skel, "m", loadout, {"under": false})
	if helm_only:
		# the helm sits on the shelf: the head brought down to the board
		host.position = at - Vector3(0, 1.72 - 0.12, 0)
	else:
		host.position = at
	# pauldrons and arms in the model's rest pose spread wide; on a stand the shoulders are drawn in
	for side: String in ["Left", "Right"]:
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).ends_with(side + "Arm"):
				var r := skel.get_bone_pose_rotation(i)
				skel.set_bone_pose_rotation(i, Quaternion(Vector3.FORWARD, 0.5 if side == "Left" else -0.5) * r)

func _anvil(at: Vector3) -> void:
	var n := Node3D.new()
	n.position = at
	add_child(n)
	# the stump, the waist, the face, the horn and the heel
	_cyl(0.26, 0.3, 0.45, Vector3(0, 0.225, 0), Look.flat(Color("#2f2116"), 0.95), Vector3.ZERO, 12, n)
	_box(Vector3(0.36, 0.1, 0.24), Vector3(0, 0.5, 0), _dark_iron, Vector3.ZERO, n)
	_box(Vector3(0.2, 0.12, 0.16), Vector3(0, 0.61, 0), _dark_iron, Vector3.ZERO, n)
	_box(Vector3(0.52, 0.12, 0.2), Vector3(0.0, 0.73, 0), _iron, Vector3.ZERO, n)
	_cyl(0.0, 0.07, 0.28, Vector3(-0.39, 0.74, 0), _iron, Vector3(0, 0, PI * 0.5), 10, n)
	_box(Vector3(0.12, 0.08, 0.14), Vector3(0.31, 0.75, 0), _iron, Vector3.ZERO, n)
	# the bar on the face, still hot
	var bar := _box(Vector3(0.34, 0.025, 0.04), Vector3(-0.02, 0.805, 0.03), Look.glow(Color("#ff7a2a"), 2.2), Vector3(0, 0.25, 0), n)
	bar.name = "Bar"
	_strike_light = _light(at + Vector3(0, 1.0, 0.3), Color("#ffb060"), 0.0, 3.0)
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = maxi(6, int(20.0 * Game.particle_scale()))
	_sparks.lifetime = 0.5
	_sparks.explosiveness = 0.95
	_sparks.direction = Vector3(0, 1, 0.4)
	_sparks.spread = 60.0
	_sparks.initial_velocity_min = 1.4
	_sparks.initial_velocity_max = 3.4
	_sparks.gravity = Vector3(0, -9.0, 0)
	_sparks.mesh = QuadMesh.new()
	(_sparks.mesh as QuadMesh).size = Vector2(0.025, 0.025)
	_sparks.material_override = Look.particle(Color("#ffb648"))
	_sparks.position = Vector3(0, 0.82, 0.04)
	n.add_child(_sparks)

func _bench(at: Vector3) -> void:
	var n := Node3D.new()
	n.position = at
	add_child(n)
	_box(Vector3(0.7, 0.08, 1.2), Vector3(0, 0.92, 0), _wood, Vector3.ZERO, n)
	for x: float in [-0.28, 0.28]:
		for z: float in [-0.52, 0.52]:
			_box(Vector3(0.07, 0.9, 0.07), Vector3(x, 0.45, z), _wood, Vector3.ZERO, n)
	_box(Vector3(0.6, 0.04, 1.1), Vector3(0, 0.3, 0), _wood, Vector3.ZERO, n)
	# files and a pair of pincers on the board
	for i in 3:
		_box(Vector3(0.02, 0.015, 0.26), Vector3(-0.15 + i * 0.05, 0.97, -0.3), _dark_iron, Vector3(0, 0.2 * i, 0), n)

## The old-technology workbench: a scarred metal bench with a lens on a jointed arm over it and a small screen
## that still holds a little cold light, the cables running from it along the wall.
func _tech_bench(at: Vector3) -> void:
	var n := Node3D.new()
	n.position = at
	add_child(n)
	var alloy := Look.flat(Color("#55595c"), 0.5, 0.6)
	_box(Vector3(1.3, 0.07, 0.65), Vector3(0, 0.9, 0), alloy, Vector3.ZERO, n)
	_box(Vector3(1.2, 0.8, 0.55), Vector3(0, 0.45, -0.02), _dark_iron, Vector3.ZERO, n)
	for i in 4:
		_box(Vector3(0.24, 0.08, 0.02), Vector3(-0.42 + i * 0.28, 0.6, 0.27), Look.flat(Color("#3a3d40"), 0.5, 0.6), Vector3.ZERO, n)
	# the screen, tilted back, faint teal
	_box(Vector3(0.5, 0.34, 0.05), Vector3(0.3, 1.18, -0.22), alloy, Vector3(-0.3, 0, 0), n)
	_box(Vector3(0.42, 0.26, 0.01), Vector3(0.3, 1.185, -0.19), Look.glow(Color("#174039"), 0.14), Vector3(-0.3, 0, 0), n)
	# the lens on its arm
	_cyl(0.025, 0.025, 0.5, Vector3(-0.4, 1.15, -0.2), _brass, Vector3(0.2, 0, 0), 8, n)
	_cyl(0.02, 0.02, 0.4, Vector3(-0.3, 1.42, -0.05), _brass, Vector3(0, 0, -1.0), 8, n)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.11
	ring.outer_radius = 0.135
	_mesh(ring, Vector3(-0.15, 1.38, 0.05), _brass, Vector3(PI * 0.5, 0, 0.3), n)
	_cyl(0.11, 0.11, 0.01, Vector3(-0.15, 1.38, 0.05), Look.flat(Color(0.7, 0.8, 0.85), 0.05, 0.2), Vector3(PI * 0.5, 0, 0.3), 16, n)
	var l := _light(at + Vector3(0.3, 1.3, 0.2), Color("#5fd0c0"), 0.2, 1.4)
	l.light_specular = 0.2

func _grindstone(at: Vector3) -> void:
	var n := Node3D.new()
	n.position = at
	add_child(n)
	var wheel := _cyl(0.38, 0.38, 0.12, Vector3(0, 0.62, 0), Look.stone(Color("#7a7066"), 0.6, 0.9), Vector3(0, 0, PI * 0.5), 20, n)
	wheel.name = "Wheel"
	for x: float in [-0.12, 0.12]:
		_box(Vector3(0.06, 0.7, 0.08), Vector3(x, 0.35, 0), _wood, Vector3.ZERO, n)
	_box(Vector3(0.5, 0.06, 0.7), Vector3(0, 0.1, 0), _wood, Vector3.ZERO, n)
	_cyl(0.02, 0.02, 0.4, Vector3(0.25, 0.62, 0), _dark_iron, Vector3(0, 0, PI * 0.5), 6, n)

func _candle(at: Vector3) -> void:
	var c := Node3D.new()
	c.position = at
	add_child(c)
	var h := 0.1 + fmod(at.x * 7.3, 0.08)
	_cyl(0.022, 0.025, h, Vector3(0, h * 0.5, 0), Look.flat(Color("#d8c8a0"), 0.7), Vector3.ZERO, 8, c)
	var flame := SphereMesh.new()
	flame.radius = 0.012
	flame.height = 0.04
	var f := _mesh(flame, Vector3(0, h + 0.02, 0), Look.glow(Color("#ffc46a"), 4.0), Vector3.ZERO, c)
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = Color("#ffb45a")
	l.light_energy = 0.45
	l.omni_range = 1.8
	l.position = Vector3(0, h + 0.08, 0)
	c.add_child(l)
	_candles.append([l, f, randf() * 10.0])

# ---------------------------------------------------------------- what Orren works with
func _props_for_orren() -> void:
	var hammer := Node3D.new()
	add_child(hammer)
	_cyl(0.016, 0.018, 0.36, Vector3(0, 0.12, 0), _wood, Vector3.ZERO, 6, hammer)
	_box(Vector3(0.05, 0.05, 0.14), Vector3(0, 0.3, 0.0), _dark_iron, Vector3.ZERO, hammer)
	hammer.position = ANVIL_AT + Vector3(0.18, 0.79, -0.06)
	hammer.rotation = Vector3(PI * 0.5, 0.0, 0.3)
	var tongs := Node3D.new()
	add_child(tongs)
	for s: float in [-0.012, 0.012]:
		_cyl(0.008, 0.008, 0.46, Vector3(s, 0.16, 0), _dark_iron, Vector3(0, 0, s * 3.0), 5, tongs)
	tongs.position = ANVIL_AT + Vector3(-0.33, 0.62, 0.1)
	tongs.rotation = Vector3(0.0, 0.0, 0.3)
	var blade := Node3D.new()
	add_child(blade)
	PropModel.weapon(blade, "res://assets/models/w_knight_sword.glb", "sword", null, 0.95)
	blade.position = Vector3(0.84, 0.965, -2.72)
	blade.rotation = Vector3(-PI * 0.5, 0.4, 0)
	# the rag lies folded on the bench's corner by his hand
	var rag := _box(Vector3(0.16, 0.22, 0.02), Vector3(0.86, 0.975, -2.42), Look.flat(Color("#6b5a44"), 0.95))
	rag.rotation = Vector3(-PI * 0.5, 0.0, 0.35)
	orren.add_prop("hammer", hammer)
	orren.add_prop("tongs", tongs)
	orren.add_prop("blade", blade)
	var rag_holder := Node3D.new()
	add_child(rag_holder)
	rag_holder.global_transform = rag.global_transform
	remove_child(rag)
	rag_holder.add_child(rag)
	rag.transform = Transform3D.IDENTITY
	orren.add_prop("rag", rag_holder)

func _on_struck(at: Vector3) -> void:
	if _sparks:
		_sparks.restart()
	if _strike_light:
		_strike_light.light_energy = 2.2 if Game.settings.reduce_flash else 4.0
	if not Story.busy:
		Sfx.play("clash", -19.0, 1.25 + randf() * 0.1)

func _process(delta: float) -> void:
	_clock += delta
	if _forge_light:
		_forge_light.light_energy = 3.0 + 0.35 * sin(_clock * 7.0) + 0.2 * sin(_clock * 13.0 + 1.3)
	if _strike_light:
		_strike_light.light_energy = maxf(0.0, _strike_light.light_energy - delta * 16.0)
	for c: Array in _candles:
		var k := sin(_clock * 9.0 + float(c[2])) * 0.5 + sin(_clock * 17.0 + float(c[2]) * 2.0) * 0.3
		(c[0] as OmniLight3D).light_energy = 0.45 + 0.08 * k
		(c[1] as Node3D).scale = Vector3(1.0, 1.0 + 0.15 * k, 1.0)
