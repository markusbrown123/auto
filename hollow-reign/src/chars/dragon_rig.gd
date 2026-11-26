class_name DragonRig
extends Node3D
## A procedurally built and animated wyrm. Presents the same interface as
## FighterRig so the duel can drive either: its head is its weapon, and every
## bite, maul and gout of flame follows an exact, readable arc.
## Local space: forward is -Z.

enum Mode { GUARD, WINDUP, STRIKE, FOLLOW, RECOVER, STAGGER, DEAD, ROAR, BITE_WINDUP, BITE, BREATH_WINDUP, BREATH, CLAW_WINDUP, CLAW }

const ARC_MAX := 1.5
const NECK_SEGS := 8
const TAIL_SEGS := 7

var cfg: Dictionary = {}
var mode: int = Mode.GUARD
var time_scale := 1.0
var weapon_len := 0.8
var mat_hide: StandardMaterial3D
var mat_belly: StandardMaterial3D
var mat_blade: StandardMaterial3D     # teeth and claws: glows red on unblockables
var mat_glow: StandardMaterial3D
var eye_light: OmniLight3D
var _root := Vector3.ZERO

var body: Node3D
var head: Node3D
var jaw: Node3D
var neck: Array = []
var tail: Array = []
var legs := {}
var wings: Array = []
var fire: CPUParticles3D
var throat: OmniLight3D

var _t := 0.0
var _dur := 1.0
var _swing := 0.3
var _dir := Vector3.RIGHT
var _theta := 0.0
var _head := Vector3(0, 2.4, -1.2)
var _aim := Vector3(0, -0.2, -1)
var _jaw := 0.0
var _claw_side := 1.0
var _claw := 0.0             # 0 planted .. 1 raised .. swipe
var _claw_x := 0.0
var _root_target := Vector3.ZERO
var _far := 0.0
var _far_target := 0.0
var _lift := 0.0
var _spread := 0.0
var _clock := 0.0
var _flash := 0.0
var _from := Vector3.ZERO
var _sink := 0.0
var has_wings := false


func build(config: Dictionary, _as_foe: bool) -> void:
	cfg = config
	has_wings = cfg.get("wings", false)
	scale = Vector3.ONE * float(cfg.get("size", 1.0))
	var hide := Color(str(cfg.get("hide", "#5a2a20")))
	mat_hide = StandardMaterial3D.new()
	mat_hide.albedo_color = hide
	mat_hide.roughness = 0.62
	mat_hide.metallic = 0.25
	mat_hide.roughness_texture = Look.grime()
	mat_hide.normal_enabled = true
	mat_hide.normal_texture = Look._noise("scales_n", FastNoiseLite.TYPE_CELLULAR, 0.09, true)
	mat_hide.uv1_triplanar = true
	mat_hide.uv1_scale = Vector3.ONE * 1.6
	mat_belly = Look.flat(Color(str(cfg.get("belly", "#b8602a"))), 0.7, 0.1)
	mat_blade = StandardMaterial3D.new()
	mat_blade.albedo_color = Color("#e8dcc0")
	mat_blade.roughness = 0.35
	var glow := Color(str(cfg.get("glow", "#ff5a14")))
	mat_glow = Look.glow(Color(str(cfg.get("eye", "#ffb040"))), 3.0)
	body = Node3D.new()
	add_child(body)
	# --- torso
	_sphere(body, 1.0, Vector3(0, 1.55, 2.1), mat_hide, Vector3(1.15, 1.0, 2.0))
	_sphere(body, 0.95, Vector3(0, 1.6, 0.7), mat_hide, Vector3(1.05, 1.05, 1.2))
	_sphere(body, 0.8, Vector3(0, 1.2, 1.4), mat_belly, Vector3(0.95, 0.8, 2.0))
	for i in 7:
		_cyl(body, 0.0, 0.13, 0.5 - i * 0.03, Vector3(0, 2.62 - i * 0.04, 0.5 + i * 0.5), mat_hide, 4)
	# hind legs: planted
	for sx: float in [-1.0, 1.0]:
		_sphere(body, 0.55, Vector3(sx * 0.95, 1.2, 2.9), mat_hide, Vector3(0.75, 1.2, 1.1))
		var shin := _cyl(body, 0.2, 0.3, 1.1, Vector3(sx * 1.1, 0.55, 3.0), mat_hide, 7)
		shin.rotation_degrees.x = -12.0
		_box(body, Vector3(0.5, 0.2, 0.8), Vector3(sx * 1.1, 0.1, 2.75), mat_hide)
	# --- neck, head
	for i in NECK_SEGS:
		var n := Node3D.new()
		body.add_child(n)
		var r := lerpf(0.5, 0.26, float(i) / NECK_SEGS)
		_sphere(n, r, Vector3.ZERO, mat_hide, Vector3(1, 1, 1.3))
		_sphere(n, r * 0.8, Vector3(0, -r * 0.35, 0), mat_belly, Vector3(0.9, 0.8, 1.2))
		_cyl(n, 0.0, 0.08, 0.3, Vector3(0, r + 0.08, 0), mat_hide, 4)
		neck.append(n)
	head = Node3D.new()
	body.add_child(head)
	_box(head, Vector3(0.52, 0.34, 0.6), Vector3(0, 0.05, 0.05), mat_hide)          # skull
	_box(head, Vector3(0.38, 0.22, 0.75), Vector3(0, 0.02, -0.6), mat_hide)         # snout
	_box(head, Vector3(0.56, 0.1, 0.4), Vector3(0, 0.24, -0.02), mat_hide)          # brow
	for sx: float in [-1.0, 1.0]:
		_sphere(head, 0.05, Vector3(sx * 0.24, 0.13, -0.2), mat_glow)
		var horn := _cyl(head, 0.0, 0.09, 0.8, Vector3(sx * 0.22, 0.42, 0.42), mat_blade, 6)
		horn.rotation_degrees = Vector3(-62, 0, -sx * 14.0)
		var horn2 := _cyl(head, 0.0, 0.05, 0.4, Vector3(sx * 0.3, 0.16, 0.35), mat_blade, 5)
		horn2.rotation_degrees = Vector3(-80, 0, -sx * 40.0)
		for k in 4:
			var tooth := _cyl(head, 0.03, 0.0, 0.14, Vector3(sx * 0.16, -0.14, -0.3 - k * 0.19), mat_blade, 4)
			tooth.rotation.z = 0.0
	jaw = Node3D.new()
	head.add_child(jaw)
	jaw.position = Vector3(0, -0.1, 0.1)
	_box(jaw, Vector3(0.34, 0.12, 0.95), Vector3(0, -0.06, -0.55), mat_hide)
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			_cyl(jaw, 0.0, 0.03, 0.13, Vector3(sx * 0.14, 0.06, -0.4 - k * 0.22), mat_blade, 4)
	var maw := _box(jaw, Vector3(0.24, 0.02, 0.7), Vector3(0, 0.01, -0.5), Look.glow(glow, 2.0))
	maw.name = "Maw"
	throat = OmniLight3D.new()
	throat.light_color = glow
	throat.light_energy = 0.0
	throat.omni_range = 5.0
	head.add_child(throat)
	throat.position = Vector3(0, -0.1, -0.9)
	eye_light = OmniLight3D.new()
	eye_light.light_color = Color(str(cfg.get("eye", "#ffb040")))
	eye_light.light_energy = 0.8
	eye_light.omni_range = 2.5
	head.add_child(eye_light)
	eye_light.position = Vector3(0, 0.2, -0.5)
	# breath
	fire = CPUParticles3D.new()
	head.add_child(fire)
	fire.position = Vector3(0, -0.1, -1.0)
	fire.emitting = false
	fire.amount = 90
	fire.lifetime = 0.55
	fire.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.6)
	fire.mesh = q
	fire.material_override = Look.particle(glow)
	fire.direction = Vector3(0, -0.1, -1)
	fire.spread = 9.0
	fire.initial_velocity_min = 9.0
	fire.initial_velocity_max = 13.0
	fire.gravity = Vector3(0, 1.5, 0)
	fire.scale_amount_min = 0.5
	fire.scale_amount_max = 1.6
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 0.9, 0.95))
	g.set_color(1, Color(1, 0.2, 0.05, 0.0))
	if glow.b > glow.r:
		g.set_color(1, Color(0.4, 0.7, 1.0, 0.0))
	fire.color_ramp = g
	# --- forelegs (IK), claws
	for side in ["r", "l"]:
		var up := _limb(0.95, 0.3, 0.2)
		var lo := _limb(0.95, 0.2, 0.13)
		var foot := Node3D.new()
		body.add_child(foot)
		_box(foot, Vector3(0.42, 0.16, 0.5), Vector3(0, 0.08, -0.1), mat_hide)
		for k in 3:
			var c := _cyl(foot, 0.0, 0.05, 0.42, Vector3((k - 1) * 0.14, 0.1, -0.5), mat_blade, 5)
			c.rotation_degrees.x = -78.0
		legs[side] = [up, lo, foot]
	# --- wings
	if has_wings:
		var membrane := Look.flat(Color(str(cfg.get("belly", "#b8602a"))).darkened(0.35), 0.8)
		membrane.cull_mode = BaseMaterial3D.CULL_DISABLED
		for sx: float in [-1.0, 1.0]:
			var w := Node3D.new()
			body.add_child(w)
			w.position = Vector3(sx * 0.7, 2.25, 1.0)
			var arm := _cyl(w, 0.07, 0.14, 3.6, Vector3(sx * 1.8, 0, 0), mat_hide, 6)
			arm.rotation_degrees.z = 90.0
			for k in 3:
				var f := _cyl(w, 0.03, 0.07, 3.0 - k * 0.3, Vector3(sx * (1.6 + k * 0.9), 0, 1.4 - k * 0.1), mat_hide, 5)
				f.rotation_degrees = Vector3(90, 0, 0)
			var sail := MeshInstance3D.new()
			var im := ImmediateMesh.new()
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			var pts := [Vector3(0, 0, 0), Vector3(sx * 3.6, 0, 0), Vector3(sx * 3.4, 0, 2.6), Vector3(sx * 2.5, 0, 2.9), Vector3(sx * 1.6, 0, 2.9), Vector3(0, 0, 1.6)]
			for k in range(1, pts.size() - 1):
				for v in [pts[0], pts[k], pts[k + 1]]:
					im.surface_set_normal(Vector3.UP)
					im.surface_add_vertex(v)
			im.surface_end()
			sail.mesh = im
			sail.material_override = membrane
			w.add_child(sail)
			wings.append([w, sx])
	# --- tail
	for i in TAIL_SEGS:
		var tn := Node3D.new()
		body.add_child(tn)
		var r2 := lerpf(0.5, 0.08, float(i) / TAIL_SEGS)
		_sphere(tn, r2, Vector3.ZERO, mat_hide, Vector3(1, 1, 1.8))
		if i % 2 == 0:
			_cyl(tn, 0.0, 0.07, 0.3, Vector3(0, r2 + 0.06, 0), mat_hide, 4)
		tail.append(tn)
	if cfg.has("skin"):
		_attach_skin(str(cfg.skin))
	_solve(0.0)

func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.material_override = mat
	parent.add_child(m)
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(parent, b, pos, mat)

func _sphere(parent: Node3D, r: float, pos: Vector3, mat: Material, squash: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	var m := _mi(parent, s, pos, mat)
	m.scale = squash
	return m

func _cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, mat: Material, sides: int = 8) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return _mi(parent, c, pos, mat)

func _limb(length: float, r0: float, r1: float) -> Node3D:
	var n := Node3D.new()
	body.add_child(n)
	_cyl(n, r1, r0, length, Vector3(0, length * 0.5, 0), mat_hide, 8)
	_sphere(n, r0 * 1.05, Vector3.ZERO, mat_hide)
	return n


# ================================================================ actions (FighterRig interface)
func _go(m: int, dur: float = 1.0) -> void:
	mode = m
	_t = 0.0
	_dur = maxf(dur, 0.01)

func guard() -> void:
	if mode != Mode.DEAD:
		_go(Mode.GUARD)
		_root_target = Vector3.ZERO

func telegraph(dir: Vector2, windup: float, swing: float, kind: String = "slash") -> void:
	_dir = Vector3(-dir.x, dir.y, 0).normalized()
	_swing = swing
	match kind:
		"breath":
			_go(Mode.BREATH_WINDUP, windup)
		"sweep":
			# a claw from the side the blow starts on
			_claw_side = -signf(_dir.x) if absf(_dir.x) > 0.1 else 1.0
			_go(Mode.CLAW_WINDUP, windup)
		"thrust", "lunge", "bite":
			if kind == "bite" and absf(_dir.x) > 0.5:
				_go(Mode.WINDUP, windup)
			else:
				_go(Mode.BITE_WINDUP, windup)
		_:
			_go(Mode.WINDUP, windup)
	_root_target = Vector3(0, 0, 0.3)

func set_blade_warning(on: bool) -> void:
	mat_blade.emission_enabled = on
	mat_blade.emission = Color(1.0, 0.12, 0.05)
	mat_blade.emission_energy_multiplier = 3.0

func swing(_dir2: Vector2, _time: float) -> void:
	pass

func parry(_dir2: Vector2) -> void:
	pass

func recover() -> void:
	if mode != Mode.DEAD:
		_go(Mode.RECOVER)
		_root_target = Vector3(0, 0, -0.2)

func stagger() -> void:
	if mode != Mode.DEAD:
		_go(Mode.STAGGER)
		_root_target = Vector3(0, 0, 0.3)

func hurt() -> void:
	_flash = 1.0

func flash(v: float = 1.0) -> void:
	_flash = v

func dodge(_side: float) -> void:
	pass

func roar() -> void:
	_go(Mode.ROAR, 2.2)
	_root_target = Vector3.ZERO

func die(_d: float = 1.0) -> void:
	_go(Mode.DEAD, 2.2)

func set_far(far: bool) -> void:
	_far_target = 1.0 if far else 0.0

func is_striking() -> bool:
	return mode in [Mode.STRIKE, Mode.BITE, Mode.BREATH, Mode.CLAW]

func blade_tip() -> Vector3:
	return head.global_transform * Vector3(0, 0, -1.0)

func blade_mid() -> Vector3:
	return head.global_transform * Vector3(0, 0, -0.6)

func chest_point() -> Vector3:
	return head.global_transform * Vector3(0, 0.1, 0.0)

## What a fighter's blade can bite into: the head and the upper neck, in world space ([a, b, radius]).
func hit_caps() -> Array:
	if mode == Mode.DEAD:
		return []
	var k := scale.x
	return [[(neck[NECK_SEGS - 3] as Node3D).global_position, head.global_transform * Vector3(0, 0, -0.5), 0.36 * k]]

## The same interface as FighterRig: a dragon's head is its weapon and is stopped short of its prey in `_keep_out`.
func bite(_world_point: Vector3, _hold: float = 0.13) -> void:
	pass

## The head never ends up inside whoever it is attacking: the snout stops at the surface of the body.
func _keep_out() -> void:
	var par := get_parent()
	if par == null or mode == Mode.DEAD:
		return
	var inv := body.global_transform.affine_inverse()
	for c in par.get_children():
		if c == self or not (c is Node3D) or not c.has_method("hit_caps") or not (c as Node3D).visible:
			continue
		for cap: Array in c.call("hit_caps"):
			var a: Vector3 = inv * (cap[0] as Vector3)
			var b: Vector3 = inv * (cap[1] as Vector3)
			var r: float = float(cap[2]) / maxf(scale.x, 0.01) + 0.12
			var snout_a := _head
			var snout_b := _head + _aim.normalized() * 1.25
			var cp := Geometry3D.get_closest_points_between_segments(snout_a, snout_b, a, b) if not a.is_equal_approx(b) \
				else PackedVector3Array([Geometry3D.get_closest_point_to_segment(a, snout_a, snout_b), a])
			var d := cp[0].distance_to(cp[1])
			if d < r:
				# draw the head back along the way it is pointing (and a little up) until the snout is clear
				_head -= (_aim.normalized() * Vector3(1, 0.3, 1)).normalized() * (r - d)


# ================================================================ per-frame
func _process(delta: float) -> void:
	var dt := delta * time_scale
	_clock += dt
	_t += dt
	_solve(dt)

func _arc(theta: float) -> Vector3:
	var f := Vector3(0, 0, -1)
	var c := Vector3(0, 2.0, -0.4)
	var p := c + (f * cos(theta) + _dir * sin(theta)) * 1.5
	p.y = maxf(p.y + 0.5 * clampf(-theta / ARC_MAX, 0.0, 1.0), 0.6)
	return p

func _solve(dt: float) -> void:
	var k := 1.0 - exp(-dt * 9.0)
	var head_t := Vector3(sin(_clock * 0.8) * 0.25, 2.5 + sin(_clock * 1.3) * 0.08, -1.2)
	var aim_t := Vector3(0, -0.25, -1)
	var jaw_t := 0.08
	var claw_t := 0.0
	var spread_t := 0.15
	var direct := false
	var breathing := false
	match mode:
		Mode.WINDUP:
			var rise := minf(_dur * 0.5, 0.55)
			var start := _dur - _swing * 0.5
			if _t < start:
				var u := 1.0 - pow(1.0 - clampf(_t / rise, 0.0, 1.0), 3.0)
				_theta = lerpf(_theta, -ARC_MAX * u, 1.0 - exp(-dt * 12.0))
				head_t = _arc(_theta) + Vector3(sin(_clock * 29.0), cos(_clock * 23.0), 0) * (0.012 if _t > rise else 0.0)
				aim_t = (Vector3(0, 1.2, -2.4) - head_t).normalized()
				jaw_t = 0.5 * u
			else:
				_go(Mode.STRIKE, _swing)
				_root_target = Vector3(0, 0, -0.6)
		Mode.BITE_WINDUP:
			var start2 := _dur - _swing * 0.5
			head_t = Vector3(-_dir.x * 0.3, 3.1, 0.2) + Vector3(sin(_clock * 29.0), cos(_clock * 23.0), 0) * (0.012 if _t > 0.5 else 0.0)
			aim_t = Vector3(0, -0.55, -1).normalized()
			jaw_t = 0.75 * clampf(_t / 0.4, 0.0, 1.0)
			if _t >= start2:
				_go(Mode.BITE, _swing)
				_from = _head
				_root_target = Vector3(0, 0, -1.0)
		Mode.BREATH_WINDUP:
			var start3 := _dur - _swing * 0.5
			var side := -_dir.x if absf(_dir.x) > 0.1 else 0.0
			head_t = Vector3(side * 1.5, 3.2, 0.1)
			aim_t = Vector3(-side * 0.2, -0.5, -1).normalized()
			jaw_t = 0.9 * clampf(_t / 0.5, 0.0, 1.0)
			# the throat lights before the fire comes: this is the tell
			throat.light_energy = 4.0 * clampf(_t / maxf(start3, 0.01), 0.0, 1.0)
			if _t >= start3:
				_go(Mode.BREATH, _swing + 0.25)
		Mode.CLAW_WINDUP:
			var start4 := _dur - _swing * 0.5
			claw_t = clampf(_t / 0.4, 0.0, 1.0)
			_claw_x = lerpf(_claw_x, 0.0, k)
			head_t = Vector3(-_claw_side * 0.6, 2.7, -0.6)
			if _t >= start4:
				_go(Mode.CLAW, _swing)
				_root_target = Vector3(0, 0, -0.5)
	match mode:
		Mode.STRIKE:
			var u2 := clampf(_t / _dur, 0.0, 1.0)
			_theta = lerpf(-ARC_MAX, ARC_MAX * 0.9, u2)
			head_t = _arc(_theta)
			aim_t = (Vector3(0, 0.9, -2.6) - head_t).normalized().lerp(_dir, 0.35).normalized()
			jaw_t = 0.7 * (1.0 - u2)
			direct = true
			if u2 >= 1.0:
				_go(Mode.FOLLOW, 0.35)
		Mode.BITE:
			var u3 := clampf(_t / _dur, 0.0, 1.0)
			head_t = _from.lerp(Vector3(0, 1.3, -2.7), ease(u3, 0.4))
			aim_t = Vector3(0, -0.2, -1).normalized()
			jaw_t = 0.8 * (1.0 - u3 * u3)
			direct = true
			if u3 >= 1.0:
				_go(Mode.FOLLOW, 0.35)
		Mode.BREATH:
			var u4 := clampf(_t / _dur, 0.0, 1.0)
			var sweep := lerpf(-1.0, 1.0, u4)
			if absf(_dir.x) > 0.1:
				head_t = Vector3(_dir.x * sweep * 1.3, 2.1, -1.0)
				aim_t = Vector3(_dir.x * sweep * 0.55, -0.42, -1).normalized()
			else:
				head_t = Vector3(0, 3.0 - u4 * 1.2, -0.8)
				aim_t = Vector3(0, -0.75 + u4 * 0.4, -1).normalized()
			jaw_t = 1.0
			breathing = true
			direct = true
			if u4 >= 1.0:
				_go(Mode.FOLLOW, 0.4)
		Mode.CLAW:
			var u5 := clampf(_t / _dur, 0.0, 1.0)
			claw_t = 1.0
			_claw_x = lerpf(0.0, 1.0, u5)
			head_t = Vector3(-_claw_side * 0.6, 2.6, -0.5)
			if u5 >= 1.0:
				_go(Mode.FOLLOW, 0.3)
		Mode.FOLLOW:
			head_t = _head
			aim_t = _aim
			claw_t = _claw * 0.5
			if _t >= _dur:
				_go(Mode.GUARD)
				_root_target = Vector3.ZERO
		Mode.RECOVER:
			# spent: the head hangs low within reach
			head_t = Vector3(0.3, 1.0 + sin(_clock * 4.5) * 0.06, -1.9)
			aim_t = Vector3(0.1, -0.1, -1).normalized()
			jaw_t = 0.35 + sin(_clock * 4.5) * 0.1
		Mode.STAGGER:
			head_t = Vector3(0.5, 0.55, -2.0)
			aim_t = Vector3(0.5, 0.05, -1).normalized()
			jaw_t = 0.25
			spread_t = 0.0
		Mode.ROAR:
			var u6 := clampf(_t / _dur, 0.0, 1.0)
			head_t = Vector3(0, 3.6, -0.3) + Vector3(sin(_clock * 24.0), 0, cos(_clock * 21.0)) * 0.03
			aim_t = Vector3(0, 0.35, -1).normalized()
			jaw_t = 1.0 * sin(u6 * PI)
			spread_t = 1.0
			if u6 >= 1.0:
				guard()
		Mode.DEAD:
			var u7 := ease(clampf(_t / _dur, 0.0, 1.0), 2.0)
			head_t = Vector3(0.7, lerpf(1.6, 0.3, u7), -1.9)
			aim_t = Vector3(0.6, 0.0, -1).normalized()
			jaw_t = 0.3
			_sink = u7
			spread_t = 0.0
	if direct:
		_head = head_t
		_aim = aim_t
	else:
		_head = _head.lerp(head_t, k)
		_aim = _aim.lerp(aim_t, k).normalized()
	_jaw = lerpf(_jaw, jaw_t, 1.0 - exp(-dt * 14.0))
	_claw = lerpf(_claw, claw_t, 1.0 - exp(-dt * 12.0))
	_far = lerpf(_far, _far_target, 1.0 - exp(-dt * 3.0))
	# far means airborne (if she can fly) or simply drawn back
	_lift = _far * (1.6 if has_wings else 0.0)
	_spread = lerpf(_spread, maxf(spread_t, _far), 1.0 - exp(-dt * 4.0))
	_root = _root.lerp(_root_target + Vector3(0, 0, _far * 1.8), 1.0 - exp(-dt * 7.0))
	_keep_out()
	fire.emitting = breathing
	if mode != Mode.BREATH_WINDUP:
		throat.light_energy = lerpf(throat.light_energy, 5.0 if breathing else 0.0, 1.0 - exp(-dt * 10.0))
	_pose()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 7.0)
		mat_hide.emission_enabled = _flash > 0.0
		mat_hide.emission = Color(1, 0.9, 0.8)
		mat_hide.emission_energy_multiplier = _flash * 0.12

func _basis_z(fwd: Vector3) -> Basis:
	# basis whose -Z points along fwd
	var z := -fwd.normalized()
	var x := Vector3.UP.cross(z)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, z.cross(x), z)

func _basis_y(y: Vector3) -> Basis:
	y = y.normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, y, x.cross(y))

var skin: DragonSkin
var _walk_last := Vector3.ZERO
var _walk_phase := 0.0
var _walk_amt := 0.0
func _attach_skin(path: String) -> void:
	skin = DragonSkin.attach(body, path)
	if skin == null:
		# The duel swaps in a class model for ordinary foes; for the lesser dragons (class Monstrosity) that is a
		# humanoid body no dragon can wear, and the animal used to be shown as the bare primitive rig. Fall back to
		# the dragon model of its own kind: the frost breed by its cold glow, otherwise the fire breed.
		var glow := Color(str(cfg.get("glow", "#ff5a14")))
		var own := "res://assets/models/dragon_skeldra.glb" if glow.b > glow.r else "res://assets/models/dragon_veyrath.glb"
		if own != path:
			skin = DragonSkin.attach(body, own)
	if skin == null:
		return
	# the generated model replaces the primitive body; the old nodes stay as invisible handles for hit points and fire
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		if not skin.root.is_ancestor_of(mi):
			(mi as MeshInstance3D).visible = false

func _pose() -> void:
	# (with a generated model the death is the model's own: it comes down onto its belly, see DragonSkin.drive;
	# and its feet stay on the floor: the breathing is in the chest, not a bob of the whole animal)
	body.position = _root + Vector3(0, _lift - (0.0 if skin else _sink * 0.55) + (0.0 if skin and _lift < 0.05 else sin(_clock * 1.3) * 0.04), 0)
	body.rotation.x = _lift * 0.12
	# neck: a curve from the shoulders to the head
	var base := Vector3(0, 2.1, 0.25)
	var ctrl := base.lerp(_head, 0.45) + Vector3(0, 0.9 - _sink * 0.8, 0.5)
	var prev := base
	for i in NECK_SEGS:
		var u := float(i + 1) / (NECK_SEGS + 1)
		var p := base.lerp(ctrl, u).lerp(ctrl.lerp(_head, u), u)
		neck[i].transform = Transform3D(_basis_z(p - prev), p)
		prev = p
	head.transform = Transform3D(_basis_z(_aim), _head)
	jaw.rotation.x = -_jaw * 0.75
	# forelegs
	for side in ["r", "l"]:
		var sx := 1.0 if side == "r" else -1.0
		var shoulder := Vector3(sx * 0.8, 1.45, 0.4)
		var foot := Vector3(sx * 1.05, 0.0, -0.45) - Vector3(_root.x, _lift, _root.z) * 0.6
		if sx == _claw_side and _claw > 0.01:
			var raised := Vector3(sx * 1.7, 1.9, -0.6)
			var across := Vector3(-sx * 0.9, 0.5, -1.9)
			var target := raised.lerp(across, _claw_x)
			target.z -= sin(_claw_x * PI) * 0.6
			foot = foot.lerp(target, _claw)
		var d := foot - shoulder
		if d.length() > 1.85:
			foot = shoulder + d.normalized() * 1.85
		var elbow := _ik(shoulder, foot, 0.95, 0.95, Vector3(sx * 0.4, 0.3, 1.0))
		legs[side][0].transform = Transform3D(_basis_y(elbow - shoulder), shoulder)
		legs[side][1].transform = Transform3D(_basis_y(foot - elbow), elbow)
		legs[side][2].position = foot
		legs[side][2].rotation.x = -_claw * 0.9 if sx == _claw_side else 0.0
	for w in wings:
		var flap := sin(_clock * (7.0 if _far > 0.3 else 1.1)) * (0.45 if _far > 0.3 else 0.05)
		w[0].rotation.z = w[1] * (lerpf(1.15, 0.1, _spread) + flap)
		w[0].rotation.y = w[1] * lerpf(-0.9, -0.15, _spread)
	for i in TAIL_SEGS:
		var u2 := float(i) / TAIL_SEGS
		var sway := sin(_clock * 1.4 + u2 * 3.0) * 0.9 * u2
		tail[i].position = Vector3(sway, 1.35 - u2 * 1.0 + sin(u2 * PI) * 0.3, 3.9 + i * 0.75)
		tail[i].rotation.y = cos(_clock * 1.4 + u2 * 3.0) * 0.4 * u2
	if skin:
		var flap2 := sin(_clock * (7.0 if _far > 0.3 else 1.1)) * (0.4 if _far > 0.3 else 0.04)
		# stride follows ground actually covered, so the feet step when the body moves and rest when it does not
		var moved := global_position.distance_to(_walk_last)
		_walk_last = global_position
		if moved < 1.0:
			_walk_phase += moved / (1.1 * maxf(scale.x, 0.1)) * PI
		_walk_amt = lerpf(_walk_amt, 1.0 if moved > 0.002 else 0.0, 0.12)
		skin.drive({"jaw": _jaw, "walk": _walk_phase, "walk_amt": _walk_amt, "aim": _aim.normalized(), "reach": clampf((-_head.z - 1.2) / 1.5, -1.0, 1.0), "claw": _claw, "claw_side": _claw_side, "claw_x": _claw_x,
			"spread": _spread, "flap": flap2, "clock": _clock, "sink": _sink})

func _ik(a: Vector3, b: Vector3, la: float, lb: float, pole: Vector3) -> Vector3:
	var d := b - a
	var dist := clampf(d.length(), 0.05, la + lb - 0.001)
	var n := d.normalized()
	var x := (la * la - lb * lb + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(la * la - x * x, 0.0))
	var perp := (pole - n * pole.dot(n)).normalized()
	return a + n * x + perp * h
