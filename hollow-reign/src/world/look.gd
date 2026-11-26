class_name Look
extends RefCounted
## Shared procedural textures and materials (no imported art needed).

static var _cache := {}

static func _noise(key: String, type: int, freq: float, as_normal: bool, ramp: Gradient = null, size: int = 256) -> NoiseTexture2D:
	if _cache.has(key):
		return _cache[key]
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.frequency = freq
	n.fractal_octaves = 4
	n.seed = hash(key)
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	t.as_normal_map = as_normal
	t.bump_strength = 6.0
	t.generate_mipmaps = true
	if ramp:
		t.color_ramp = ramp
	_cache[key] = t
	return t

static func grime() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.35, 0.35, 0.35))
	g.set_color(1, Color(0.95, 0.95, 0.95))
	return _noise("grime", FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, false, g, 128)

static func stone(tint: Color, uv: float = 0.35, rough: float = 0.82, key: String = "stone") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var g := Gradient.new()
	g.set_color(0, tint.darkened(0.55))
	g.set_color(1, tint.lightened(0.08))
	g.add_point(0.45, tint.darkened(0.2))
	m.albedo_texture = _noise(key + tint.to_html(), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.018, false, g)
	m.normal_enabled = true
	m.normal_texture = _noise(key + "_n", FastNoiseLite.TYPE_CELLULAR, 0.035, true)
	m.normal_scale = 0.9
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * uv
	return m

static func clouds() -> Texture2D:
	if _cache.has("clouds"):
		return _cache["clouds"]
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.006
	n.fractal_octaves = 5
	n.seed = 11
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0.9))
	g.add_point(0.5, Color(1, 1, 1, 0))
	var t := NoiseTexture2D.new()
	t.width = 1024
	t.height = 512
	t.seamless = true
	t.noise = n
	t.color_ramp = g
	_cache["clouds"] = t
	return t

## A tuft of grass blades drawn into a small texture (alpha-cut).
static func grass() -> Texture2D:
	if _cache.has("grass"):
		return _cache["grass"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for b in 9:
		var base_x := r.randf_range(8.0, 56.0)
		var lean := r.randf_range(-14.0, 14.0)
		var h := r.randf_range(34.0, 62.0)
		var w := r.randf_range(2.5, 4.5)
		var shade := r.randf_range(0.75, 1.1)
		for y in int(h):
			var u := float(y) / h
			var cx := base_x + lean * u * u
			var half := w * (1.0 - u) + 0.4
			for x in range(int(cx - half), int(cx + half) + 1):
				if x >= 0 and x < 64:
					img.set_pixel(x, 63 - y, Color(0.20 + 0.22 * u, 0.30 + 0.24 * u, 0.12 + 0.08 * u, 1.0) * Color(shade, shade, shade, 1.0))
	var t := ImageTexture.create_from_image(img)
	_cache["grass"] = t
	return t

static func flat(c: Color, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

static func glow(c: Color, energy: float = 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func particle(c: Color, additive: bool = true) -> StandardMaterial3D:
	var key := "pt" + c.to_html() + str(additive)
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = soft_dot()
	_cache[key] = m
	return m

static func soft_dot() -> Texture2D:
	if _cache.has("dot"):
		return _cache["dot"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	_cache["dot"] = t
	return t

# ================================================================ generated-model materials
## Roughness/metallic ranges by asset class (see docs/GRAPHICS_BIBLE.md). Generated PBR sets tend to
## come out as liquid chrome or wet plastic; every loaded model goes through `sanitise` once.
const SURFACE := {
	"stone": {"rough_min": 0.78, "rough_max": 1.0, "metal_max": 0.05, "spec": 0.3},
	"wood": {"rough_min": 0.8, "rough_max": 1.0, "metal_max": 0.0, "spec": 0.25},
	"scenery_metal": {"rough_min": 0.5, "rough_max": 1.0, "metal_max": 0.6, "spec": 0.4},
	"regal": {"rough_min": 0.58, "rough_max": 1.0, "metal_max": 0.45, "spec": 0.35},
	"ice": {"rough_min": 0.38, "rough_max": 0.9, "metal_max": 0.0, "spec": 0.5},
	"weapon": {"rough_min": 0.3, "rough_max": 1.0, "metal_max": 1.0, "spec": 0.5},
	"character": {"rough_min": 0.33, "rough_max": 1.0, "metal_max": 0.85, "spec": 0.35},
}
const PBR_SHADER := "res://src/fx/pbr_clamp.gdshader"

static func _pbr_shader(two_sided: bool) -> Shader:
	var key := "pbr2" if two_sided else "pbr1"
	if _cache.has(key):
		return _cache[key]
	var base: Shader = load(PBR_SHADER)
	var sh := base
	if two_sided:
		sh = Shader.new()
		sh.code = base.code.replace("; //CULL", ", cull_disabled;")
	_cache[key] = sh
	return sh

static func _white() -> Texture2D:
	if not _cache.has("white"):
		var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
		img.fill(Color.WHITE)
		_cache["white"] = ImageTexture.create_from_image(img)
	return _cache["white"]

## Replaces each textured, opaque generated material under `root` with the clamped PBR shader for its
## class. `unique` gives this instance its own materials (characters: tint, flash, rim are per fighter);
## otherwise one material is shared by every instance of the same source material.
## Untextured (primitive) and transparent materials are left alone apart from a scalar clamp on the latter.
static func sanitise(root: Node, cls: String, unique: bool = false) -> void:
	if root == null or not SURFACE.has(cls):
		return
	var r: Dictionary = SURFACE[cls]
	var list: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		list.append(root)
	for mi: MeshInstance3D in list:
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			if not (mat is BaseMaterial3D):
				continue
			var bm: BaseMaterial3D = mat
			if bm.albedo_texture == null or bm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				continue
			var key := "san%d%s" % [bm.get_instance_id(), cls]
			if not unique and _cache.has(key):
				mi.set_surface_override_material(s, _cache[key])
				continue
			var out: Material
			if bm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				var sm := ShaderMaterial.new()
				sm.shader = _pbr_shader(bm.cull_mode == BaseMaterial3D.CULL_DISABLED)
				sm.set_shader_parameter("albedo_tex", bm.albedo_texture)
				sm.set_shader_parameter("tint", bm.albedo_color)
				if bm.normal_enabled and bm.normal_texture:
					sm.set_shader_parameter("normal_tex", bm.normal_texture)
					sm.set_shader_parameter("normal_scale", bm.normal_scale)
				var orm: Texture2D = bm.roughness_texture if bm.roughness_texture else bm.metallic_texture
				if orm:
					sm.set_shader_parameter("orm_tex", orm)
				# without a packed texture the scalar values stand in: white ORM -> rough_max / metal_max
				var top: float = float(r.rough_max) if orm else clampf(bm.roughness, float(r.rough_min), float(r.rough_max))
				var metal: float = float(r.metal_max) if bm.metallic_texture else minf(bm.metallic, float(r.metal_max))
				sm.set_shader_parameter("rough_min", r.rough_min)
				sm.set_shader_parameter("rough_max", top)
				sm.set_shader_parameter("metal_max", metal)
				sm.set_shader_parameter("spec", r.spec)
				if bm.emission_enabled:
					sm.set_shader_parameter("emissive", bm.emission * bm.emission_energy_multiplier)
					sm.set_shader_parameter("emissive_tex", bm.emission_texture if bm.emission_texture else _white())
				out = sm
			else:
				var d: BaseMaterial3D = bm.duplicate()
				d.metallic = minf(d.metallic, float(r.metal_max))
				d.metallic_specular = r.spec
				d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				if d.roughness_texture:
					d.roughness_texture = null
					d.roughness = lerpf(float(r.rough_min), float(r.rough_max), 0.6)
				out = d
			if not unique:
				_cache[key] = out
			mi.set_surface_override_material(s, out)

## Sets a shader parameter on every sanitised material under `root` (tint, flash, rim_color ...).
static func set_param(root: Node, param: StringName, value: Variant) -> void:
	if root == null:
		return
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(s)
			if m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter(param, value)

## A small dead leaf for falling-leaf particles (billboarded, spun by the emitter).
static func leaf() -> StandardMaterial3D:
	if _cache.has("leaf"):
		return _cache["leaf"]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 16:
		for x in 16:
			var u := (x - 7.5) / 7.5
			var v := (y - 7.5) / 3.6
			if u * u + v * v < 1.0:
				img.set_pixel(x, y, Color(1, 1, 1, 1).darkened(0.25 * absf(v)))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_cache["leaf"] = m
	return m
