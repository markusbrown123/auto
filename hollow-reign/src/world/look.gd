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
