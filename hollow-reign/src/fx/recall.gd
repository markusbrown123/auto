class_name Recall
extends Node
## Recall: rebuilds a weapon or shield into the hand (hilt first, then the blade to its tip, one narrow pulse,
## then plain metal), or takes it apart again. Works on any MeshInstance3D tree whose origin is at the grip:
## a GearModel, or the holder PropModel.weapon / PropModel.shield made.
##
##   Recall.summon(node)                       # ~0.95 s, ends on the node's ordinary materials
##   Recall.summon(node, {"short": true})      # repeat viewings, ~0.5 s
##   Recall.dismiss(node)                      # the reverse; hides the node when it is gone
##   Recall.hold(node, 0.4)                    # a still at a chosen progress (previews, captures); .release() ends it
##   await Recall.summon(node).finished
## Options: duration, short, color (Color), radial (bool; default: true when the tree is wider than it is long,
## i.e. a shield), sparks (bool), cheap (bool; default from Game.settings).
## While it runs every surface carries recall.gdshader with the original's textures; at the end each surface gets
## back exactly the override it had (or none), so nothing of the effect stays on the piece.

signal finished

const SHADER := "res://src/fx/recall.gdshader"
const COLOR := Color(0.62, 0.9, 1.0)       # "old energy" in the graphics bible

var root: Node3D
var progress := 0.0
var _from := 0.0
var _to := 1.0
var _dur := 0.95
var _t := 0.0
var _held := false
var _mats: Array = []          # [MeshInstance3D, surface, previous override, recall material]
var _sparks: CPUParticles3D
var _origin := Vector3.ZERO
var _dir := Vector3.UP
var _len := 1.0
var _radial := false
var _cheap := false
static var _shaders := {}

static func summon(node: Node3D, opts: Dictionary = {}) -> Recall:
	return _start(node, 0.0, 1.0, opts)

static func dismiss(node: Node3D, opts: Dictionary = {}) -> Recall:
	return _start(node, 1.0, 0.0, opts)

static func hold(node: Node3D, at: float, opts: Dictionary = {}) -> Recall:
	var r := _start(node, at, at, opts)
	r._held = true
	return r

## True when effects should take the cheaper path: Performance preset or reduced motion.
static func reduced() -> bool:
	return int(Game.settings.get("quality", 1)) == 0 or bool(Game.settings.get("reduce_motion", false))

static func _start(node: Node3D, from: float, to: float, opts: Dictionary) -> Recall:
	for c in node.get_children():
		if c is Recall:
			(c as Recall).release()
	var r := Recall.new()
	r.root = node
	r._from = from
	r._to = to
	r._cheap = bool(opts.get("cheap", reduced()))
	var still := bool(Game.settings.get("reduce_motion", false))
	r._dur = float(opts.get("duration", 0.35 if still else (0.5 if opts.get("short", false) or r._cheap else 0.95)))
	node.add_child(r)
	node.visible = true
	r._measure(opts)
	r._apply(opts.get("color", COLOR))
	if bool(opts.get("sparks", not r._cheap)) and from != to:
		r._make_sparks(opts.get("color", COLOR))
	r._set_progress(from)
	return r

func _meshes() -> Array:
	var list: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		list.append(root)
	return list.filter(func(m: MeshInstance3D) -> bool: return m.mesh != null)

func _to_root(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root and cur != null:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

func _measure(opts: Dictionary) -> void:
	var lo := Vector3.ONE * 1e9
	var hi := Vector3.ONE * -1e9
	for mi: MeshInstance3D in _meshes():
		var xf := _to_root(mi)
		var bb: AABB = mi.mesh.get_aabb()
		for i in 8:
			var p: Vector3 = xf * bb.get_endpoint(i)
			lo = lo.min(p)
			hi = hi.max(p)
	if lo.x > hi.x:
		lo = Vector3.ZERO
		hi = Vector3.UP
	var ext := hi - lo
	var long_axis := ext.max_axis_index()
	var mid: float = ext[(long_axis + 1) % 3]
	var other: float = ext[(long_axis + 2) % 3]
	_radial = bool(opts.get("radial", maxf(mid, other) > ext[long_axis] * 0.55))
	if _radial:
		_origin = Vector3.ZERO
		var far := 0.0
		for i in 8:
			far = maxf(far, AABB(lo, ext).get_endpoint(i).length())
		_len = maxf(far * 0.94, 0.01)
		_dir = Vector3.ZERO
		_dir[ext.min_axis_index()] = 1.0       # the axis the opening ring lies around
	else:
		# the end nearer the grip (the origin) is where it starts
		var up: bool = absf(lo[long_axis]) <= absf(hi[long_axis])
		_dir = Vector3.ZERO
		_dir[long_axis] = 1.0 if up else -1.0
		_origin = Vector3.ZERO
		_origin[long_axis] = lo[long_axis] if up else hi[long_axis]
		_len = maxf(ext[long_axis], 0.01)

static func _shader(two_sided: bool) -> Shader:
	if not _shaders.has(two_sided):
		var base: Shader = load(SHADER)
		var sh := base
		if two_sided:
			sh = Shader.new()
			sh.code = base.code.replace("; //CULL", ", cull_disabled;")
		_shaders[two_sided] = sh
	return _shaders[two_sided]

func _apply(color: Color) -> void:
	for mi: MeshInstance3D in _meshes():
		var xf := _to_root(mi)
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.get_active_material(s)
			if mi.material_override != null:
				continue
			var m := ShaderMaterial.new()
			var two := false
			if src is ShaderMaterial:
				var sm: ShaderMaterial = src
				for p: String in ["albedo_tex", "normal_tex", "orm_tex", "tint", "rough_min", "rough_max", "metal_max", "spec", "emissive", "emissive_tex"]:
					var v: Variant = sm.get_shader_parameter(p)
					if v != null:
						m.set_shader_parameter(p, v)
				if sm.get_shader_parameter("normal_tex") != null:
					var ns: Variant = sm.get_shader_parameter("normal_scale")
					m.set_shader_parameter("normal_scale", 1.0 if ns == null else ns)
				two = sm.shader != null and sm.shader.code.contains("cull_disabled")
			elif src is BaseMaterial3D:
				var bm: BaseMaterial3D = src
				two = bm.cull_mode == BaseMaterial3D.CULL_DISABLED
				m.set_shader_parameter("tint", bm.albedo_color)
				if bm.albedo_texture:
					m.set_shader_parameter("albedo_tex", bm.albedo_texture)
				if bm.normal_enabled and bm.normal_texture:
					m.set_shader_parameter("normal_tex", bm.normal_texture)
					m.set_shader_parameter("normal_scale", bm.normal_scale)
				var orm: Texture2D = bm.roughness_texture if bm.roughness_texture else bm.metallic_texture
				if orm:
					m.set_shader_parameter("orm_tex", orm)
				m.set_shader_parameter("rough_mul", bm.roughness)
				m.set_shader_parameter("metal_mul", bm.metallic)
				m.set_shader_parameter("rough_min", 0.0)
				m.set_shader_parameter("spec", bm.metallic_specular)
				if bm.emission_enabled:
					m.set_shader_parameter("emissive", bm.emission * bm.emission_energy_multiplier)
					if bm.emission_texture:
						m.set_shader_parameter("emissive_tex", bm.emission_texture)
			m.shader = _shader(two)
			m.set_shader_parameter("to_root", xf)
			m.set_shader_parameter("axis_origin", _origin)
			m.set_shader_parameter("axis_dir", _dir)
			m.set_shader_parameter("axis_len", _len)
			m.set_shader_parameter("radial", 1.0 if _radial else 0.0)
			m.set_shader_parameter("front_color", Vector3(color.r, color.g, color.b))
			m.set_shader_parameter("cheap", 1.0 if _cheap else 0.0)
			_mats.append([mi, s, mi.get_surface_override_material(s), m])
			mi.set_surface_override_material(s, m)

func _make_sparks(color: Color) -> void:
	_sparks = CPUParticles3D.new()
	_sparks.amount = maxi(4, int(18.0 * Game.particle_scale()))
	_sparks.lifetime = 0.28
	_sparks.local_coords = false
	_sparks.mesh = _spark_mesh()
	_sparks.material_override = Look.particle(Color(color.r, color.g, color.b, 0.9))
	_sparks.direction = Vector3.UP
	_sparks.spread = 180.0
	_sparks.initial_velocity_min = 0.08
	_sparks.initial_velocity_max = 0.45
	_sparks.gravity = Vector3(0, -0.6, 0)
	_sparks.damping_min = 1.5
	_sparks.damping_max = 3.0
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.0
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	_sparks.scale_amount_curve = c
	if _radial:
		_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		_sparks.emission_ring_axis = _dir
		_sparks.emission_ring_height = 0.01
	else:
		_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_sparks.emission_sphere_radius = 0.02
	_sparks.emitting = false
	root.add_child(_sparks)       # in the piece's own space, so the emitter rides the front wherever the hand goes

static var _spark: QuadMesh
static func _spark_mesh() -> QuadMesh:
	if _spark == null:
		_spark = QuadMesh.new()
		_spark.size = Vector2(0.014, 0.014)
	return _spark

func _set_progress(p: float) -> void:
	progress = p
	for e: Array in _mats:
		(e[3] as ShaderMaterial).set_shader_parameter("progress", p)
	if _sparks:
		var reveal := clampf(p / 0.72, 0.0, 1.0)
		var cut := clampf(reveal * 1.08 - 0.03, 0.0, 1.0)
		_sparks.emitting = reveal > 0.02 and reveal < 0.98
		if _radial:
			_sparks.position = _origin
			_sparks.emission_ring_radius = cut * _len
			_sparks.emission_ring_inner_radius = cut * _len * 0.96
		else:
			_sparks.position = _origin + _dir * (cut * _len)

func _process(delta: float) -> void:
	if _held:
		return
	_t += delta
	var k := clampf(_t / maxf(_dur, 0.01), 0.0, 1.0)
	_set_progress(lerpf(_from, _to, k))
	if k >= 1.0:
		var gone := _to <= 0.0
		release()
		if gone and is_instance_valid(root):
			root.visible = false
		finished.emit()

## Puts every surface back exactly as it was and removes the effect.
func release() -> void:
	for e: Array in _mats:
		if is_instance_valid(e[0]):
			(e[0] as MeshInstance3D).set_surface_override_material(e[1], e[2])
	_mats.clear()
	set_process(false)
	if _sparks:
		# let the last sparks die where they are, then go
		_sparks.emitting = false
		var s := _sparks
		_sparks = null
		if is_instance_valid(s) and s.is_inside_tree():
			s.get_tree().create_timer(0.4).timeout.connect(s.queue_free)
		elif is_instance_valid(s):
			s.queue_free()
	queue_free()
