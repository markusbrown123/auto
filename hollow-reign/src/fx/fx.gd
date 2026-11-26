class_name Fx
extends Node3D
## Pooled combat effects: contact sparks, dust, stone chips, elemental bursts and energy arcs.
## One instance lives under the duel; every emitter and light is created once and re-triggered,
## so a hit allocates nothing. All counts go through `pscale()` (Game.particle_scale() when it exists).
## Budgets and triggers are listed in docs/VFX_BIBLE.md.

const MAX_SPARKS := 40        # hard cap for a single burst (a perfect parry)
const BUDGET := {"parry": 24, "perfect": 40, "block": 12, "hit": 16, "dust": 8, "chips": 10, "element": 12}
const POOL := {"spark": 4, "dust": 3, "chips": 2, "ember": 2, "ice": 2, "mote": 2}

var ground := Color(0.55, 0.52, 0.46)      # dust and chip colour: the arena's floor
var _pool := {}                            # kind -> [emitters]
var _next := {}                            # kind -> round-robin index
var _lights: Array = []
var _light_i := 0
var _arc: MeshInstance3D
var _arc_mesh: ImmediateMesh
var _arc_jobs: Array = []                  # [from, to, seed]
var _arc_t := 0.0
var _arc_col := Color(0.7, 0.9, 1.0)

static var _res := {}

static func pscale() -> float:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var g: Node = (loop as SceneTree).root.get_node_or_null("Game")
		if g and g.has_method("particle_scale"):
			return clampf(float(g.call("particle_scale")), 0.0, 1.0)
	return 1.0

static func count(n: int, cap: int = MAX_SPARKS) -> int:
	return int(round(mini(n, cap) * pscale()))

# ---------------------------------------------------------------- shared resources
## Sword-trail ribbon: unshaded, additive, soft across its width (see FighterRig._update_trail).
static func ribbon_material() -> StandardMaterial3D:
	if _res.has("ribbon"):
		return _res["ribbon"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 1))
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 32
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = t
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	_res["ribbon"] = m
	return m

## A spark is a short streak: two crossed quads along +Y, turned to its velocity by the emitter.
static func streak_mesh() -> ArrayMesh:
	if _res.has("streak"):
		return _res["streak"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.011
	var h := 0.13
	for ax: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var a := -ax * w
		var b := ax * w
		var top := Vector3(0, h, 0)
		for v: Vector3 in [a, b, b * 0.2 + top, a, b * 0.2 + top, a * 0.2 + top]:
			st.add_vertex(v)
	var mesh := st.commit()
	_res["streak"] = mesh
	return mesh

static func _streak_material() -> StandardMaterial3D:
	if _res.has("streak_m"):
		return _res["streak_m"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_res["streak_m"] = m
	return m

static func _quad(s: float) -> QuadMesh:
	var key := "q%.3f" % s
	if not _res.has(key):
		var q := QuadMesh.new()
		q.size = Vector2(s, s)
		_res[key] = q
	return _res[key]

static func _ramp(stops: Array) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, stops[0])
	g.set_color(1, stops[-1])
	for i in range(1, stops.size() - 1):
		g.add_point(float(i) / (stops.size() - 1), stops[i])
	return g

static func _curve(a: float, b: float) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, a))
	c.add_point(Vector2(1, b))
	return c

# ---------------------------------------------------------------- pool
func _make(kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.96
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match kind:
		"spark":
			p.mesh = streak_mesh()
			p.material_override = _streak_material()
			p.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
			p.lifetime = 0.34
			p.lifetime_randomness = 0.5
			p.spread = 24.0
			p.gravity = Vector3(0, -9.8, 0)
			p.damping_min = 0.8
			p.damping_max = 2.4
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.2
			p.color_ramp = _ramp([Color(1, 0.92, 0.72, 1), Color(1, 0.7, 0.36, 0.9), Color(1, 0.3, 0.06, 0)])
		"dust":
			p.mesh = _quad(0.34)
			p.material_override = Look.particle(Color.WHITE, false)
			p.explosiveness = 0.85
			p.lifetime = 0.75
			p.lifetime_randomness = 0.3
			p.direction = Vector3.UP
			p.spread = 80.0
			p.flatness = 0.7
			p.gravity = Vector3(0, 0.25, 0)
			p.initial_velocity_min = 0.35
			p.initial_velocity_max = 1.1
			p.damping_min = 1.2
			p.damping_max = 2.0
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.0
			p.scale_amount_curve = _curve(0.45, 1.3)
			p.color_ramp = _ramp([Color(1, 1, 1, 0), Color(1, 1, 1, 0.13), Color(1, 1, 1, 0.07), Color(1, 1, 1, 0)])
		"chips":
			var b := BoxMesh.new()
			b.size = Vector3(0.04, 0.025, 0.035)
			p.mesh = b
			var m := StandardMaterial3D.new()
			m.albedo_color = ground.darkened(0.35)
			m.roughness = 0.95
			p.material_override = m
			p.lifetime = 0.65
			p.lifetime_randomness = 0.3
			p.direction = Vector3.UP
			p.spread = 50.0
			p.gravity = Vector3(0, -12.0, 0)
			p.initial_velocity_min = 1.8
			p.initial_velocity_max = 4.4
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.5
			p.scale_amount_curve = _curve(1.0, 0.6)
		"ember":
			p.mesh = _quad(0.035)
			p.material_override = Look.particle(Color.WHITE)
			p.explosiveness = 0.8
			p.lifetime = 0.65
			p.lifetime_randomness = 0.4
			p.spread = 55.0
			p.gravity = Vector3(0, 1.6, 0)
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 2.2
			p.damping_min = 1.5
			p.damping_max = 3.0
			p.color_ramp = _ramp([Color(1, 0.95, 0.7, 1), Color(1, 0.5, 0.12, 0.9), Color(0.8, 0.12, 0.0, 0)])
		"ice":
			p.mesh = streak_mesh()
			p.material_override = _streak_material()
			p.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
			p.lifetime = 0.45
			p.lifetime_randomness = 0.4
			p.spread = 48.0
			p.gravity = Vector3(0, -7.0, 0)
			p.damping_min = 1.0
			p.damping_max = 2.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.5
			p.color_ramp = _ramp([Color(0.9, 0.97, 1, 1), Color(0.55, 0.8, 1, 0.8), Color(0.3, 0.55, 1, 0)])
		"mote":
			p.mesh = _quad(0.07)
			p.material_override = Look.particle(Color.WHITE, false)
			p.explosiveness = 0.7
			p.lifetime = 0.8
			p.lifetime_randomness = 0.3
			p.spread = 180.0
			p.gravity = Vector3(0, 0.5, 0)
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 1.2
			p.radial_accel_min = -3.0
			p.radial_accel_max = -1.5
			p.damping_min = 1.0
			p.damping_max = 2.0
			p.scale_amount_curve = _curve(1.0, 0.3)
			p.color_ramp = _ramp([Color(0.2, 0.06, 0.3, 0), Color(0.12, 0.03, 0.2, 0.85), Color(0.05, 0.0, 0.1, 0)])
	add_child(p)
	return p

func _take(kind: String) -> CPUParticles3D:
	if not _pool.has(kind):
		_pool[kind] = []
		_next[kind] = 0
	var list: Array = _pool[kind]
	if list.size() < int(POOL[kind]):
		list.append(_make(kind))
		return list[-1]
	_next[kind] = (int(_next[kind]) + 1) % list.size()
	return list[_next[kind]]

func _fire(kind: String, at: Vector3, dir: Vector3, n: int, color: Color, speed: float = -1.0) -> void:
	if n <= 0 or not is_inside_tree():
		return
	var p := _take(kind)
	p.emitting = false
	p.amount = n
	p.color = color
	if dir.length_squared() > 0.0001:
		p.direction = dir.normalized()
	if speed > 0.0:
		p.initial_velocity_min = speed * 0.45
		p.initial_velocity_max = speed
	p.global_position = at
	p.restart()
	p.emitting = true

func _flash(at: Vector3, color: Color, energy: float, reach: float, time: float = 0.16) -> void:
	if _lights.size() < 2:
		var nl := OmniLight3D.new()
		nl.light_energy = 0.0
		nl.shadow_enabled = false
		add_child(nl)
		_lights.append([nl, null])
	_light_i = (_light_i + 1) % _lights.size()
	var slot: Array = _lights[_light_i]
	var l: OmniLight3D = slot[0]
	if slot[1] != null and (slot[1] as Tween).is_valid():
		(slot[1] as Tween).kill()
	l.global_position = at
	l.light_color = color
	l.omni_range = reach
	l.light_energy = energy
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, time)
	slot[1] = tw

# ---------------------------------------------------------------- effects
## Metal on metal. Starts exactly at `at`, leaves along `dir`, falls under gravity, gone in ~0.3 s.
func sparks(at: Vector3, dir: Vector3, amount: int = 16, color: Color = Color(1.0, 0.78, 0.45), speed: float = 5.0, light: bool = true) -> void:
	_fire("spark", at, dir if dir.length_squared() > 0.0001 else Vector3.UP, count(amount), color, speed)
	if light:
		_flash(at, color, 1.2 + 0.03 * mini(amount, MAX_SPARKS), 3.0)

## A low puff at the feet: rolls, sidesteps, being driven back.
func dust(at: Vector3, amount: int = 6, tint = null, strength: float = 1.0) -> void:
	# particle vertex colours are read as linear, so convert: otherwise dark floors raise pale grey dust
	var c: Color = (tint if tint != null else ground.lerp(Color(0.7, 0.68, 0.64), 0.35)).srgb_to_linear()
	c.a = clampf(strength, 0.2, 1.5)
	_fire("dust", Vector3(at.x, maxf(at.y, 0.0) + 0.08, at.z), Vector3.UP, count(amount, BUDGET.dust), c)

## Broken flagstone thrown up where a slam lands, with its dust.
func chips(at: Vector3, amount: int = 10) -> void:
	var g := Vector3(at.x, 0.05, at.z)
	_fire("chips", g, Vector3.UP, count(amount, BUDGET.chips), Color.WHITE)
	dust(g, 7, null, 1.3)

## Elemental accent at a contact point. Returns false for an element with no effect.
func element(kind: String, at: Vector3, dir: Vector3 = Vector3.UP) -> bool:
	var n: int = count(BUDGET.element, BUDGET.element)
	match kind:
		"fire":
			_fire("ember", at, dir + Vector3.UP, n, Color(1, 1, 1))
			_flash(at, Color(1.0, 0.5, 0.18), 2.0, 3.5, 0.3)
		"frost":
			_fire("ice", at, dir + Vector3(0, 0.6, 0), count(10, BUDGET.element), Color(1, 1, 1), 3.4)
			dust(at, 3, Color(0.78, 0.9, 1.0), 0.9)
			_flash(at, Color(0.55, 0.8, 1.0), 1.2, 3.0, 0.22)
		"ancient", "arc", "rift":
			arcs(at, 3)
			_flash(at, Color(0.6, 0.9, 1.0), 1.6, 3.0, 0.14)
		"corruption", "void", "drain":
			_fire("mote", at, Vector3.UP, n, Color(1, 1, 1))
		_:
			return false
	return true

## A few thin arcs of old energy jumping out of a point; redrawn each frame for ~0.14 s.
func arcs(at: Vector3, n: int = 3, reach: float = 0.55, color: Color = Color(0.62, 0.9, 1.0)) -> void:
	if pscale() <= 0.0:
		return
	if _arc == null:
		_arc_mesh = ImmediateMesh.new()
		_arc = MeshInstance3D.new()
		_arc.mesh = _arc_mesh
		_arc.top_level = true
		_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arc.extra_cull_margin = 4.0
		_arc.material_override = ribbon_material()
		add_child(_arc)
		_arc.global_transform = Transform3D.IDENTITY
	_arc_jobs.clear()
	for i in mini(n, 4):
		var d := Vector3(randf_range(-1, 1), randf_range(-0.3, 1.0), randf_range(-1, 1)).normalized()
		_arc_jobs.append([at, at + d * reach * randf_range(0.6, 1.0), randi()])
	_arc_t = 0.14
	_arc_col = color

## The duel's key light: a spot that stays over the camera's right shoulder and aims between the two
## fighters wherever the fight drifts, so both are always lit from the side the player sees.
var _key: SpotLight3D
var _key_a: Node3D
var _key_b: Node3D
func follow_key(light: SpotLight3D, a: Node3D, b: Node3D) -> void:
	_key = light
	_key_a = a
	_key_b = b
	_aim_key(1.0)

func _aim_key(k: float) -> void:
	if _key == null or not is_instance_valid(_key_a) or not is_instance_valid(_key_b) or not _key.is_inside_tree():
		return
	var mid: Vector3 = (_key_a.global_position + _key_b.global_position) * 0.5
	var cam := get_viewport().get_camera_3d()
	var right := Vector3.RIGHT
	var back := Vector3.BACK
	if cam:
		right = Vector3(cam.global_basis.x.x, 0, cam.global_basis.x.z).normalized()
		back = Vector3(cam.global_basis.z.x, 0, cam.global_basis.z.z).normalized()
	var want := mid + right * 4.0 + back * 3.6 + Vector3(0, 6.2, 0)
	_key.global_position = _key.global_position.lerp(want, k)
	_key.look_at(mid + Vector3(0, 1.1, 0))

func _process(delta: float) -> void:
	_aim_key(1.0 - exp(-delta * 3.0))
	if _arc == null or (_arc_t <= 0.0 and _arc_jobs.is_empty()):
		return
	_arc_t -= delta
	_arc_mesh.clear_surfaces()
	if _arc_t <= 0.0:
		_arc_jobs.clear()
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var a := clampf(_arc_t / 0.14, 0.0, 1.0)
	for job in _arc_jobs:
		var from: Vector3 = job[0]
		var to: Vector3 = job[1]
		var len := (to - from).length()
		_arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for k in 7:
			var f := k / 6.0
			var p := from.lerp(to, f)
			if k > 0 and k < 6:
				p += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * len * 0.12
			var side := (to - from).cross(cam.global_position - p).normalized() * 0.009 * (1.0 - f * 0.7)
			_arc_mesh.surface_set_color(Color(_arc_col.r, _arc_col.g, _arc_col.b, a * 0.9))
			_arc_mesh.surface_set_uv(Vector2(0, f))
			_arc_mesh.surface_add_vertex(p - side)
			_arc_mesh.surface_set_uv(Vector2(1, f))
			_arc_mesh.surface_add_vertex(p + side)
		_arc_mesh.surface_end()
