class_name Arena
extends Node3D
## Builds a region's duel arena procedurally from a theme table.
## The fight happens on the Z axis around the origin; the camera sits at +Z.

## Per-region look. Lighting fields (all optional, defaults in LIGHT_DEFAULTS):
##   amb / amb_e   ambient colour and energy          fill_e   camera-side fill (no shadows)
##   key / key_e   the duel's follow spot             rim / rim_e   back light and the fighters' fresnel edge
##   exp           exposure      sat / con / bri      colour grade (Environment adjustments)
##   particles     ambient emitters joined with "+" (see _particles; budget: 150 live in total with flames)
const THEMES := {
	# clear cold morning: the kingdom is cursed, but the sun still rises on it
	"courtyard": {"sky": "#2f5f9e", "horizon": "#c4d6e6", "fog": "#a8bccc", "fog_d": 0.005, "sun": "#fff2dc", "sun_e": 2.1, "sun_rot": Vector3(-42, 145, 0),
		"stone": "#9a9284", "floor": "#8c8474", "fire": "#ff8a3a", "layout": "ruin", "particles": "motes", "amb": "#7e8ea6", "day": true,
		"amb_e": 0.95, "fill_e": 0.0, "key": "#fff6ea", "key_e": 2.0, "rim": "#ffe6c4", "rim_e": 0.35, "exp": 1.0, "sat": 0.95, "con": 1.06},
	"roost": {"sky": "#2a3c72", "horizon": "#ffb478", "fog": "#d09868", "fog_d": 0.006, "sun": "#ffcf9a", "sun_e": 2.0, "sun_rot": Vector3(-18, 160, 0),
		"stone": "#7a6858", "floor": "#6a5848", "fire": "#ff7a2a", "layout": "crag", "particles": "embers+ash", "amb": "#8a7068", "day": true,
		"amb_e": 0.95, "fill_e": 0.0, "key": "#fff0e0", "key_e": 2.0, "rim": "#ffb070", "rim_e": 0.4, "exp": 1.0, "sat": 0.98, "con": 1.06},
	"deep": {"sky": "#0a0716", "horizon": "#241438", "fog": "#1a1030", "fog_d": 0.026, "sun": "#a48ae0", "sun_e": 0.95, "sun_rot": Vector3(-60, 170, 0),
		"stone": "#3c3446", "floor": "#262030", "fire": "#b07aff", "layout": "abyss", "particles": "spores+motes", "amb": "#3a2e54", "wet": true,
		"amb_e": 1.7, "fill_e": 0.45, "key": "#ece6ff", "key_e": 4.0, "rim": "#b890ff", "rim_e": 0.75, "exp": 1.18, "sat": 0.9, "con": 1.05},
	"blackwood": {"sky": "#101a16", "horizon": "#2e4234", "fog": "#1e2c24", "fog_d": 0.022, "sun": "#b4d0ba", "sun_e": 1.45, "sun_rot": Vector3(-55, 120, 0),
		"stone": "#3a3a32", "floor": "#30332a", "fire": "#c8d86a", "layout": "forest", "particles": "leaves+motes", "amb": "#2e4234",
		"amb_e": 1.6, "fill_e": 0.4, "key": "#f0f4ea", "key_e": 3.8, "rim": "#c8e09a", "rim_e": 0.6, "exp": 1.15, "sat": 0.88, "con": 1.06},
	"cathedral": {"sky": "#1a100c", "horizon": "#52291a", "fog": "#2e1c14", "fog_d": 0.024, "sun": "#ffb47a", "sun_e": 1.25, "sun_rot": Vector3(-30, 200, 0),
		"stone": "#5a4e44", "floor": "#4c423a", "fire": "#ff6a22", "layout": "nave", "particles": "ash+embers", "amb": "#4e382c",
		"amb_e": 1.6, "fill_e": 0.4, "key": "#fff0e2", "key_e": 3.6, "rim": "#ff9a58", "rim_e": 0.6, "exp": 1.15, "sat": 0.9, "con": 1.06},
	"cathedral_steps": {"sky": "#1a100c", "horizon": "#5a2a16", "fog": "#2e1c14", "fog_d": 0.022, "sun": "#ffb47a", "sun_e": 1.25, "sun_rot": Vector3(-25, 170, 0),
		"stone": "#5a4e44", "floor": "#4c423a", "fire": "#ff6a22", "layout": "facade", "particles": "ash+embers", "amb": "#4e382c",
		"amb_e": 1.6, "fill_e": 0.4, "key": "#fff0e2", "key_e": 3.6, "rim": "#ff9a58", "rim_e": 0.6, "exp": 1.15, "sat": 0.9, "con": 1.06},
	"crypt": {"sky": "#081210", "horizon": "#12241f", "fog": "#122620", "fog_d": 0.024, "sun": "#7cc4b0", "sun_e": 0.9, "sun_rot": Vector3(-70, 90, 0),
		"stone": "#3c4440", "floor": "#28342f", "fire": "#5fe0b8", "layout": "vault", "particles": "motes+mist", "amb": "#2a443a", "wet": true,
		"amb_e": 1.7, "fill_e": 0.5, "key": "#e8f6f0", "key_e": 4.0, "rim": "#7ef0cc", "rim_e": 0.7, "exp": 1.2, "sat": 0.88, "con": 1.05},
	"citadel": {"sky": "#101a2e", "horizon": "#6a84a0", "fog": "#4a5e74", "fog_d": 0.026, "sun": "#c8dcf4", "sun_e": 1.5, "sun_rot": Vector3(-35, 140, 0),
		"stone": "#6a7480", "floor": "#8a96a2", "fire": "#7fd4ff", "layout": "hall", "particles": "snow", "amb": "#46586e",
		"amb_e": 1.45, "fill_e": 0.3, "key": "#eef4ff", "key_e": 3.4, "rim": "#a4dcff", "rim_e": 0.55, "exp": 1.1, "sat": 0.9, "con": 1.08},
	"sanctuary": {"sky": "#0c0b0e", "horizon": "#1c1a1c", "fog": "#15120f", "fog_d": 0.04, "sun": "#c8b8a0", "sun_e": 0.6, "sun_rot": Vector3(-50, 160, 0),
		"stone": "#5c564e", "floor": "#48423a", "fire": "#ffb45a", "layout": "chapel", "particles": "motes", "amb": "#3e342c",
		"amb_e": 1.5, "fill_e": 0.25, "key": "#fff2e0", "key_e": 3.6, "rim": "#ffc888", "rim_e": 0.5, "exp": 1.15, "sat": 0.9, "con": 1.06},
	"throne": {"sky": "#0e0a0a", "horizon": "#2e1c12", "fog": "#1c140e", "fog_d": 0.014, "sun": "#ffdcaa", "sun_e": 1.15, "sun_rot": Vector3(-48, 180, 0),
		"stone": "#4a443c", "floor": "#3a332e", "fire": "#ffc860", "layout": "throne", "particles": "motes", "amb": "#42342a",
		"amb_e": 1.55, "fill_e": 0.35, "key": "#fff4e6", "key_e": 3.6, "rim": "#ffd080", "rim_e": 0.55, "exp": 1.12, "sat": 0.95, "con": 1.12},
	# the resurrection chamber under the fortress: a closed round room, lit only by what its machines still give off
	"chamber": {"sky": "#050607", "horizon": "#0a0c0e", "fog": "#0e1414", "fog_d": 0.03, "sun": "#8fb0b0", "sun_e": 0.0, "sun_rot": Vector3(-80, 160, 0),
		"stone": "#5a5750", "floor": "#45433e", "fire": "#ffb45a", "layout": "chamber", "particles": "motes+mist", "amb": "#2c3836",
		"amb_e": 0.75, "fill_e": 0.0, "key": "#ffe9c8", "key_e": 3.0, "rim": "#6fd8c8", "rim_e": 0.0, "exp": 1.1, "sat": 0.92, "con": 1.08},
	# the high road to the Ring-Gate: a headland of grass above the sea at dawn (src/world/highland.gd builds it and sets the light)
	"highland": {"sky": "#34578f", "horizon": "#f0c692", "fog": "#d8b690", "fog_d": 0.0021, "sun": "#ffd6a2", "sun_e": 3.4, "sun_rot": Vector3(-11, 168, 0),
		"stone": "#8d877b", "floor": "#8c8474", "fire": "#ff8a3a", "layout": "highland", "particles": "motes", "amb": "#8693a8", "day": true,
		"amb_e": 0.95, "fill_e": 0.0, "key": "#fff0dc", "key_e": 2.6, "rim": "#ffd8a8", "rim_e": 0.3, "exp": 1.18, "sat": 1.02, "con": 1.06},
}
const LIGHT_DEFAULTS := {"amb_e": 1.5, "fill_e": 0.3, "key": "#ffffff", "key_e": 3.6, "rim": "#ffffff", "rim_e": 0.5, "exp": 1.1, "sat": 0.9, "con": 1.06, "bri": 1.0}
const PARTICLE_BUDGET := 150       # live ambient particles per arena, flames included

var theme := {}
var rng := RandomNumberGenerator.new()
var env: Environment
var sun: DirectionalLight3D
var fires: Array = []
var mat_stone: StandardMaterial3D
var mat_dark: StandardMaterial3D
var _clock := 0.0
var _live := 0                # ambient particles allotted so far (see PARTICLE_BUDGET)

## A theme's lighting value, falling back to LIGHT_DEFAULTS.
func light(key: String) -> Variant:
	return theme.get(key, LIGHT_DEFAULTS.get(key))

static func theme_for(region_theme: String, arena: String = "") -> String:
	if arena != "" and THEMES.has(arena):
		return arena
	return region_theme if THEMES.has(region_theme) else "courtyard"

var _theme_id := ""
func build(theme_id: String) -> void:
	_theme_id = theme_id
	theme = THEMES[theme_id]
	rng.seed = hash(theme_id)
	mat_stone = Look.stone(Color(theme.stone))
	mat_dark = Look.flat(Color(theme.stone).darkened(0.3 if theme.get("day", false) else 0.7), 1.0)
	_environment()
	_floor()
	call("_layout_" + theme.layout)
	_particles(theme.particles)

# ---------------------------------------------------------------- environment
func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(theme.sky)
	sky_mat.sky_horizon_color = Color(theme.horizon)
	sky_mat.ground_bottom_color = Color(theme.sky)
	sky_mat.ground_horizon_color = Color(theme.horizon)
	sky_mat.sky_curve = 0.08
	sky_mat.sun_angle_max = 6.0
	if theme.get("day", false):
		sky_mat.sky_curve = 0.18
		sky_mat.sky_cover = Look.clouds()
		sky_mat.sky_cover_modulate = Color(theme.horizon).lerp(Color.WHITE, 0.6)
		sky_mat.sun_angle_max = 14.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(theme.amb)
	env.ambient_light_energy = float(light("amb_e"))
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# restrained filmic curve with headroom: silver armour and fire keep detail instead of clipping
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 3.0
	env.tonemap_exposure = float(light("exp")) * 1.25
	# fog gives depth; density is kept low enough that the far wall is still visible
	env.fog_enabled = true
	env.fog_light_color = Color(theme.fog)
	env.fog_density = theme.fog_d
	env.fog_sky_affect = 0.1 if theme.get("day", false) else 0.6
	# mild bloom, emissive and fire only (nothing below the HDR threshold blooms)
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_brightness = float(light("bri"))
	env.adjustment_saturation = float(light("sat"))
	env.adjustment_contrast = float(light("con"))
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(theme.sun)
	sun.light_energy = theme.sun_e
	sun.rotation_degrees = theme.sun_rot
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30.0
	sun.shadow_blur = 1.5
	add_child(sun)
	# a soft rim from behind the foe so silhouettes read against the fog
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(str(light("rim")))
	rim.light_energy = float(light("rim_e"))
	rim.rotation_degrees = Vector3(-20, 20, 0)
	rim.light_specular = 0.3
	add_child(rim)
	# a shadowless fill from the camera's side: lifts the faces turned to the player in the dark regions
	if float(light("fill_e")) > 0.0:
		var fill := DirectionalLight3D.new()
		fill.light_color = Color(theme.amb).lerp(Color.WHITE, 0.45)
		fill.light_energy = float(light("fill_e"))
		fill.light_specular = 0.0
		fill.rotation_degrees = Vector3(-28, -155, 0)
		add_child(fill)

func _floor() -> void:
	# damp stone, not a mirror: wet floors are only a little smoother than dry ones
	var m := Look.stone(Color(theme.floor), 0.22, 0.6 if theme.get("wet", false) else 0.8, "floor")
	m.metallic = 0.0
	m.metallic_specular = 0.5 if theme.get("wet", false) else 0.35
	m.normal_scale = 0.6 if theme.get("wet", false) else 0.9
	# a real ground texture where one has been made for this region: sharp paving instead of soft noise
	var tex_id := {"cathedral_steps": "cathedral"}.get(_theme_id, _theme_id) as String
	var tex_path := "res://assets/textures/floor_%s.jpg" % tex_id
	if ResourceLoader.exists(tex_path):
		var fm := StandardMaterial3D.new()
		fm.albedo_texture = load(tex_path)
		fm.albedo_color = Color(0.92, 0.92, 0.92)
		if ResourceLoader.exists("res://assets/textures/floor_%s_n.png" % tex_id):
			fm.normal_enabled = true
			fm.normal_texture = load("res://assets/textures/floor_%s_n.png" % tex_id)
			fm.normal_scale = 1.1
		fm.uv1_scale = Vector3(20, 20, 1)          # one tile every 4.5 m
		fm.roughness = 0.62 if theme.get("wet", false) else 0.85
		fm.metallic = 0.0
		fm.metallic_specular = 0.45 if theme.get("wet", false) else 0.3
		fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m = fm
	var p := PlaneMesh.new()
	p.size = Vector2(90, 90)
	var mi := MeshInstance3D.new()
	mi.mesh = p
	mi.material_override = m
	add_child(mi)
	# a worn duelling circle
	var ring := TorusMesh.new()
	ring.inner_radius = 4.3
	ring.outer_radius = 4.45
	ring.rings = 48
	ring.ring_segments = 4
	var r := MeshInstance3D.new()
	r.mesh = ring
	r.scale.y = 0.08
	r.material_override = Look.flat(Color(theme.stone).darkened(0.35), 0.8, 0.0)
	add_child(r)

# ---------------------------------------------------------------- pieces
func box(size: Vector3, pos: Vector3, mat: Material = null, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat if mat else mat_stone
	add_child(mi)
	return mi

func cyl(r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material = null, sides: int = 10) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.position = pos
	mi.material_override = mat if mat else mat_stone
	add_child(mi)
	return mi

func column(pos: Vector3, h: float, r: float = 0.45, broken: bool = false) -> void:
	box(Vector3(r * 2.8, 0.4, r * 2.8), pos + Vector3(0, 0.2, 0))
	cyl(r * 0.9, r, h, pos + Vector3(0, 0.4 + h * 0.5, 0), null, 10)
	if not broken:
		box(Vector3(r * 2.6, 0.35, r * 2.6), pos + Vector3(0, 0.55 + h, 0))
	else:
		box(Vector3(r * 1.6, 0.5, r * 1.3), pos + Vector3(r * 2.5, 0.25, r), null, Vector3(8, 30, 14))

func fire(pos: Vector3, energy: float = 2.2, rng_range: float = 9.0, brazier: bool = true) -> void:
	var c := Color(theme.fire)
	if brazier:
		cyl(0.3, 0.16, 0.25, pos + Vector3(0, -0.12, 0), Look.flat(Color("#141210"), 0.6, 0.7), 8)
		cyl(0.05, 0.08, pos.y, Vector3(pos.x, pos.y * 0.5 - 0.12, pos.z), Look.flat(Color("#141210"), 0.6, 0.7), 6)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng_range
	l.omni_attenuation = 1.4
	l.position = pos + Vector3(0, 0.3, 0)
	add_child(l)
	fires.append([l, energy, rng.randf() * 10.0])
	var n := _allot(10)
	if n <= 0:
		return
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = n
	p.lifetime = 0.9
	p.mesh = _quad(0.34)
	p.material_override = Look.particle(c)
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.6, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.color_ramp = _fade(Color(1, 1, 1, 0.9), Color(1, 0.3, 0.1, 0.0))
	add_child(p)

func window_glow(pos: Vector3, size: Vector2, yaw: float = 0.0) -> void:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.position = pos
	mi.rotation_degrees.y = yaw
	mi.material_override = Look.glow(Color(theme.fire).darkened(0.35), 1.0)
	add_child(mi)

func rubble(center: Vector3, n: int, spread: float) -> void:
	for i in n:
		var s := rng.randf_range(0.2, 0.7)
		box(Vector3(s * rng.randf_range(0.8, 1.8), s * 0.7, s), center + Vector3(rng.randf_range(-spread, spread), s * 0.25, rng.randf_range(-spread, spread)), null,
			Vector3(rng.randf_range(-15, 15), rng.randf_range(0, 180), rng.randf_range(-15, 15)))

func tower(pos: Vector3, w: float, h: float, lit: bool = true) -> void:
	box(Vector3(w, h, w), pos + Vector3(0, h * 0.5, 0), mat_dark)
	for i in 4:
		var a := i * PI / 2.0
		box(Vector3(w * 0.25, w * 0.3, w * 0.25), pos + Vector3(cos(a + 0.78) * w * 0.52, h + w * 0.15, sin(a + 0.78) * w * 0.52), mat_dark)
	if lit:
		for i in rng.randi_range(1, 3):
			window_glow(pos + Vector3(rng.randf_range(-w * 0.3, w * 0.3), h * rng.randf_range(0.45, 0.9), w * 0.51), Vector2(w * 0.08, w * 0.2))

func arch(pos: Vector3, w: float, h: float, depth: float = 1.0, mat: Material = null) -> void:
	box(Vector3(w * 0.22, h, depth), pos + Vector3(-w * 0.5, h * 0.5, 0), mat)
	box(Vector3(w * 0.22, h, depth), pos + Vector3(w * 0.5, h * 0.5, 0), mat)
	box(Vector3(w * 1.22, h * 0.2, depth), pos + Vector3(0, h * 1.08, 0), mat)
	box(Vector3(w * 0.5, h * 0.16, depth), pos + Vector3(-w * 0.3, h * 0.95, 0), mat, Vector3(0, 0, 38))
	box(Vector3(w * 0.5, h * 0.16, depth), pos + Vector3(w * 0.3, h * 0.95, 0), mat, Vector3(0, 0, -38))

func banner(pos: Vector3, h: float, c: Color) -> void:
	var m := Look.flat(c, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	box(Vector3(0.9, h, 0.03), pos + Vector3(0, -h * 0.5, 0), m)
	box(Vector3(1.1, 0.06, 0.06), pos, Look.flat(Color("#2a2018"), 0.6, 0.6))

# ---------------------------------------------------------------- layouts
func prop(id: String, height: float, pos: Vector3, yaw: float = 0.0) -> Node3D:
	return PropModel.scenery(self, "res://assets/models/env_%s.glb" % id, height, pos, yaw)

## The Fallen Courtyard, built from the generated set pieces: the inner ward of
## a mountain fortress, with the gatehouse behind the foe and the peaks beyond.
func _layout_ruin() -> void:
	if not PropModel.exists("res://assets/models/env_gate.glb"):
		_layout_ruin_basic()
		return
	sun.directional_shadow_max_distance = 60.0
	prop("gate", 12.0, Vector3(0, 0, -15.0), 0.0)
	for sx: float in [-1.0, 1.0]:
		prop("wall", 8.5, Vector3(sx * 17.0, 0, -14.0), 0.0 if sx < 0 else 180.0)
		prop("wall", 7.5, Vector3(sx * 21.0, 0, -1.0), 90.0 * sx)
		prop("pillar", 4.2, Vector3(sx * 6.2, 0, -4.2), sx * 35.0)
		prop("banner", 6.0, Vector3(sx * 7.4, 0, -11.5), sx * -20.0)
		fire(Vector3(sx * 4.0, 1.75, -7.2), 2.0, 9.0, false)
		prop("brazier", 1.9, Vector3(sx * 4.0, 0, -7.2), 0.0)
		prop("rubble", 2.6, Vector3(sx * 10.5, 0, -7.5), sx * 60.0)
	prop("tower", 20.0, Vector3(-20.0, 0, -20.0), 20.0)
	prop("tower", 17.0, Vector3(22.0, 0, -22.0), -60.0)
	prop("statue", 8.0, Vector3(-8.5, 0, -8.5), 25.0)
	prop("statue", 8.0, Vector3(9.5, 0, -10.5), -30.0)
	prop("statue_head", 2.4, Vector3(6.4, 0, -2.4), -40.0)
	prop("tree", 8.5, Vector3(-12.5, 0, 0.5), 110.0)
	prop("rubble", 1.8, Vector3(-5.8, 0, 2.4), 10.0)
	prop("pillar", 3.6, Vector3(11.0, 0, 3.0), 160.0)
	# something under the stone was never medieval
	var ob := prop("obelisk", 5.5, Vector3(11.5, 0, -3.5), -25.0)
	if ob:
		var glow := OmniLight3D.new()
		glow.light_color = Color("#6fc8ff")
		glow.light_energy = 1.6
		glow.omni_range = 6.0
		glow.position = Vector3(0, 2.6, 0.8)
		ob.add_child(glow)
	# the mountains the fortress was cut from
	for m in [[-150.0, -170.0, 120.0, 30.0], [-40.0, -210.0, 150.0, 160.0], [90.0, -190.0, 130.0, -70.0], [190.0, -110.0, 105.0, 200.0], [-220.0, -60.0, 110.0, 100.0]]:
		var pk := prop("peak", m[2], Vector3(m[0], -8.0, m[1]), m[3])
		if pk:
			for mi in pk.find_children("*", "MeshInstance3D", true, false):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the road turns to look every way, so the ward is enclosed on all sides
	prop("wall", 8.0, Vector3(-9.0, 0, 19.0), 180.0)
	prop("wall", 7.0, Vector3(12.0, 0, 20.0), 170.0)
	prop("tower", 16.0, Vector3(-22.0, 0, 16.0), 200.0)
	prop("tower", 19.0, Vector3(24.0, 0, 12.0), 100.0)
	prop("statue", 7.0, Vector3(-15.0, 0, 9.0), 120.0)
	prop("pillar", 4.0, Vector3(15.5, 0, 7.5), 80.0)
	prop("rubble", 2.4, Vector3(4.0, 0, 14.0), 200.0)
	prop("tree", 7.5, Vector3(17.0, 0, -9.0), 30.0)
	prop("banner", 5.5, Vector3(-6.5, 0, 12.0), 160.0)
	for m in [[120.0, 170.0, 125.0, 10.0], [-60.0, 200.0, 140.0, 250.0], [-190.0, 110.0, 115.0, 130.0], [230.0, 40.0, 120.0, 300.0]]:
		var pk2 := prop("peak", m[2], Vector3(m[0], -8.0, m[1]), m[3])
		if pk2:
			for mi in pk2.find_children("*", "MeshInstance3D", true, false):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grass(420, 24.0)

## Tufts of grass between the flagstones: crossed quads, wind handled by a tiny vertex sway.
func _grass(count: int, radius: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var blade := QuadMesh.new()
	blade.size = Vector2(0.5, 0.45)
	blade.center_offset = Vector3(0, 0.22, 0)
	mm.mesh = blade
	mm.instance_count = count * 2
	var n := 0
	for i in count:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var p := Vector3(cos(a) * d, 0, sin(a) * d - 3.0)
		if p.length() < 4.6 or (absf(p.x) < 2.2 and p.z > -1.0):
			p = p.normalized() * rng.randf_range(5.0, radius)
		var yaw := rng.randf() * PI
		var s := rng.randf_range(0.6, 1.5)
		for k in 2:
			mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, yaw + k * PI * 0.5).scaled(Vector3.ONE * s), p))
			n += 1
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/fx/grass_sway.gdshader")
	mat.set_shader_parameter("albedo_tex", Look.grass())
	var mi2 := MultiMeshInstance3D.new()
	mi2.multimesh = mm
	mi2.material_override = mat
	mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi2)

func _layout_ruin_basic() -> void:
	# broken curtain wall behind the foe, with the gatehouse arch
	arch(Vector3(0, 0, -11), 4.5, 5.5, 1.6)
	for sx: float in [-1.0, 1.0]:
		var x := sx * 5.0
		var h := 6.0
		while absf(x) < 20.0:
			h = clampf(h + rng.randf_range(-2.2, 1.2), 1.5, 7.0)
			box(Vector3(2.6, h, 1.5), Vector3(x, h * 0.5, -11 + rng.randf_range(-0.3, 0.3)))
			if rng.randf() < 0.5:
				box(Vector3(0.7, 0.7, 1.5), Vector3(x - 0.9, h + 0.35, -11))
			x += sx * 2.6
		column(Vector3(sx * 5.5, 0, -4.5), rng.randf_range(2.0, 4.0), 0.45, true)
		column(Vector3(sx * 6.5, 0, 1.0), rng.randf_range(1.2, 3.0), 0.45, true)
		fire(Vector3(sx * 3.6, 1.3, -6.5))
		rubble(Vector3(sx * 7.0, 0, -7.0), 9, 2.5)
	rubble(Vector3(0, 0, -9.0), 6, 2.0)
	# the keep beyond the wall
	tower(Vector3(-9, 0, -30), 6, 22)
	tower(Vector3(4, 0, -38), 9, 30)
	tower(Vector3(17, 0, -28), 5, 17)
	tower(Vector3(-22, 0, -24), 5, 13, false)
	box(Vector3(40, 9, 3), Vector3(0, 4.5, -34), mat_dark)
	# chains and a fallen portcullis bar give the gate some story
	box(Vector3(0.12, 0.12, 5.0), Vector3(-1.2, 0.3, -9.0), Look.flat(Color("#1a1816"), 0.5, 0.8), Vector3(0, 25, 4))

## The Blackwood, from its generated kit: a clearing ringed by colossal trunks, a drowned shrine, lanterns still lit.
func _layout_forest() -> void:
	if not PropModel.exists("res://assets/models/env_bw_giant_tree.glb"):
		_layout_forest_basic()
		return
	sun.directional_shadow_max_distance = 55.0
	# the great trees: a wall of trunks all round, taller behind the foe
	var ring := [[-13.0, -15.0, 26.0, 20.0], [0.5, -20.0, 30.0, 140.0], [14.0, -14.0, 24.0, 250.0], [-21.0, -3.0, 22.0, 80.0], [21.0, -1.0, 25.0, 310.0],
		[-17.0, 12.0, 23.0, 200.0], [16.0, 14.0, 22.0, 30.0], [0.0, 22.0, 24.0, 100.0], [-30.0, -22.0, 34.0, 0.0], [30.0, -24.0, 36.0, 180.0], [-34.0, 8.0, 30.0, 60.0], [34.0, 10.0, 32.0, 240.0]]
	for t in ring:
		prop("bw_giant_tree", t[2], Vector3(t[0], -0.6, t[1]), t[3])
	for i in 16:
		var a := TAU * i / 16.0 + 0.2
		var d := rng.randf_range(11.0, 26.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d - 2.0)
		if p.length() < 9.0:
			continue
		prop("bw_tree", rng.randf_range(11.0, 18.0), p, rng.randf() * 360.0)
	prop("bw_shrine", 4.6, Vector3(0.5, 0, -11.5), 0.0)
	prop("bw_root_arch", 7.5, Vector3(-9.0, 0, -8.0), 40.0)
	prop("bw_gibbet", 8.5, Vector3(9.5, 0, -8.5), -50.0)
	prop("bw_stone", 4.6, Vector3(-6.8, 0, -3.6), 20.0)
	prop("bw_log", 2.6, Vector3(8.5, 0, 1.5), 70.0)
	prop("bw_cart", 2.2, Vector3(-9.5, 0, 4.5), 130.0)
	prop("bw_hut", 5.0, Vector3(13.0, 0, 8.5), 215.0)
	prop("bw_boulder", 2.4, Vector3(-5.5, 0, 8.0), 0.0)
	prop("bw_boulder", 3.2, Vector3(12.0, 0, -3.0), 140.0)
	prop("bw_root_arch", 6.5, Vector3(6.0, 0, 15.0), 200.0)
	# the executioner's blocks, round the clearing's edge
	for i in 6:
		var a2 := TAU * i / 6.0 + 0.5
		prop("bw_block", rng.randf_range(0.9, 1.3), Vector3(cos(a2) * 6.2, 0, sin(a2) * 6.2 - 1.0), rng.randf() * 360.0)
	for l in [Vector3(-4.2, 0, -6.6), Vector3(4.4, 0, -6.2), Vector3(-7.5, 0, 1.5), Vector3(6.8, 0, 6.0), Vector3(-2.5, 0, 12.0)]:
		var post := prop("bw_lantern", 4.2, l, rng.randf() * 360.0)
		if post:
			var glow := OmniLight3D.new()
			glow.light_color = Color(theme.fire)
			glow.light_energy = 1.9
			glow.omni_range = 8.0
			glow.omni_attenuation = 1.3
			glow.position = Vector3(0, 3.3, 0)
			post.add_child(glow)
	# the standing stone is not stone all the way through
	var hum := OmniLight3D.new()
	hum.light_color = Color("#7dffb0")
	hum.light_energy = 1.2
	hum.omni_range = 5.0
	hum.position = Vector3(-6.4, 2.2, -3.0)
	add_child(hum)
	_grass(380, 22.0)

func _layout_forest_basic() -> void:
	var bark := Look.stone(Color("#2a241e"), 0.5, 0.95, "bark")
	for i in 46:
		var a := rng.randf() * TAU
		var d := rng.randf_range(6.5, 30.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d - 6.0)
		if p.z > 3.0 and absf(p.x) < 4.0:
			continue
		var h := rng.randf_range(9.0, 18.0)
		var r := rng.randf_range(0.25, 0.6)
		var t := cyl(r * 0.6, r, h, p + Vector3(0, h * 0.5, 0), bark, 7)
		t.rotation_degrees = Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))
		for b in rng.randi_range(1, 3):
			var br := cyl(0.02, r * 0.3, rng.randf_range(2.0, 4.0), p + Vector3(0, h * rng.randf_range(0.35, 0.8), 0), bark, 5)
			br.rotation_degrees = Vector3(rng.randf_range(40, 75), rng.randf() * 360.0, 0)
			br.translate_object_local(Vector3(0, 1.2, 0))
	# stumps: the executioner's blocks
	for i in 7:
		var a2 := rng.randf() * TAU
		var d2 := rng.randf_range(5.2, 8.0)
		cyl(0.42, 0.5, 0.6, Vector3(cos(a2) * d2, 0.3, sin(a2) * d2 - 2.0), bark, 9)
	# hanging lanterns
	for p2 in [Vector3(-4.5, 3.2, -5.0), Vector3(4.0, 3.8, -6.5), Vector3(-7.0, 4.0, 0.0), Vector3(6.5, 3.0, -1.0)]:
		box(Vector3(0.18, 0.26, 0.18), p2, Look.glow(Color(theme.fire), 3.0))
		box(Vector3(0.02, 6.0, 0.02), p2 + Vector3(0, 3.1, 0), Look.flat(Color.BLACK))
		fire(p2, 1.6, 7.0, false)

func _layout_nave_basic() -> void:
	for i in 7:
		var z := 6.0 - i * 5.0
		for sx: float in [-1.0, 1.0]:
			column(Vector3(sx * 6.5, 0, z), 9.0, 0.6, i == 2 and sx > 0)
			box(Vector3(1.0, 14.0, 5.0), Vector3(sx * 11.5, 7.0, z))
			window_glow(Vector3(sx * 10.95, 6.5, z + 2.5), Vector2(1.3, 5.0), -90.0 * sx)
	# apse wall with the great window, and the fallen bell
	box(Vector3(26, 18, 1.2), Vector3(0, 9, -26))
	window_glow(Vector3(0, 9.5, -25.3), Vector2(3.5, 9.0))
	for sx: float in [-1.0, 1.0]:
		window_glow(Vector3(sx * 5.0, 8.0, -25.3), Vector2(1.6, 6.0))
		fire(Vector3(sx * 4.2, 1.3, -7.0), 2.6)
		rubble(Vector3(sx * 5.0, 0, -12.0), 8, 2.0)
	var bell := cyl(0.9, 2.0, 2.6, Vector3(1.5, 1.0, -13.0), Look.flat(Color("#6a5630"), 0.45, 0.9), 14)
	bell.rotation_degrees = Vector3(62, 20, 0)
	# burnt roof beams fallen across the nave
	for i in 5:
		box(Vector3(0.4, 0.4, rng.randf_range(6, 11)), Vector3(rng.randf_range(-9, 9), rng.randf_range(0.3, 6.0), rng.randf_range(-20, -9)), Look.flat(Color("#120e0c")), Vector3(rng.randf_range(-35, 35), rng.randf_range(0, 180), rng.randf_range(-20, 20)))

func _layout_facade() -> void:
	# broad steps rising to the cathedral doors
	for i in 8:
		box(Vector3(26, 0.3, 1.2), Vector3(0, 0.15 + i * 0.3, -8.0 - i * 1.2))
	box(Vector3(34, 24, 2), Vector3(0, 12 + 2.4, -19))
	arch(Vector3(0, 2.4, -17.9), 5.0, 8.0, 0.8, mat_dark)
	window_glow(Vector3(0, 6.0, -17.95), Vector2(4.0, 7.0))
	window_glow(Vector3(0, 18.0, -17.95), Vector2(4.5, 4.5))
	for sx: float in [-1.0, 1.0]:
		tower(Vector3(sx * 13, 0, -20), 7, 34)
		fire(Vector3(sx * 4.0, 1.3, -5.5), 2.6)
		column(Vector3(sx * 6.5, 0, -2.0), 3.5, 0.5, true)
		for k in 3:
			window_glow(Vector3(sx * (6.0 + k * 2.2), 9.0, -17.95), Vector2(1.0, 5.0))

func _layout_vault_basic() -> void:
	for i in 6:
		var z := 5.0 - i * 5.0
		for sx: float in [-1.0, 1.0]:
			column(Vector3(sx * 5.5, 0, z), 4.2, 0.7)
			box(Vector3(1.0, 6.0, 5.0), Vector3(sx * 10.0, 3.0, z))
			# burial niches
			box(Vector3(0.6, 0.9, 2.2), Vector3(sx * 9.4, 1.6, z), mat_dark)
			if i % 2 == 0:
				fire(Vector3(sx * 5.5, 2.6, z + 0.9), 1.5, 7.0, false)
				box(Vector3(0.14, 0.2, 0.14), Vector3(sx * 5.5, 2.6, z + 0.9), Look.glow(Color(theme.fire), 3.0))
	box(Vector3(22, 0.8, 40), Vector3(0, 5.6, -8), mat_dark)   # low ceiling
	box(Vector3(22, 7, 1), Vector3(0, 3.5, -22))
	# the first tomb
	box(Vector3(2.2, 1.0, 4.0), Vector3(0, 0.5, -15), Look.stone(Color("#5a6660")))
	box(Vector3(2.5, 0.25, 4.3), Vector3(0, 1.1, -15), Look.stone(Color("#5a6660")), Vector3(0, 6, 0))
	rubble(Vector3(-4, 0, -10), 6, 1.5)

func _layout_hall_basic() -> void:
	var ice := Look.flat(Color("#a8d0e8"), 0.12, 0.3)
	for i in 7:
		var z := 6.0 - i * 5.0
		for sx: float in [-1.0, 1.0]:
			column(Vector3(sx * 7.0, 0, z), 10.0, 0.7)
			# icicles and drifts
			for k in 3:
				var ic := cyl(0.1, 0.0, rng.randf_range(0.8, 2.2), Vector3(sx * 7.0 + rng.randf_range(-0.8, 0.8), 10.0, z + rng.randf_range(-0.8, 0.8)), ice, 5)
				ic.position.y -= ic.mesh.height * 0.5
			var drift := cyl(0.3, 2.2, 0.8, Vector3(sx * rng.randf_range(6.0, 9.0), 0.2, z + 2.0), Look.flat(Color("#c8d4e0"), 0.9), 8)
			drift.scale.z = 1.6
			box(Vector3(1.0, 16.0, 5.0), Vector3(sx * 12.5, 8.0, z))
			window_glow(Vector3(sx * 11.95, 8.0, z + 2.5), Vector2(1.0, 6.0), -90.0 * sx)
	box(Vector3(28, 20, 1.2), Vector3(0, 10, -27))
	# the winter throne, sheathed in ice
	box(Vector3(5, 0.5, 4), Vector3(0, 0.25, -21))
	box(Vector3(2.2, 5.5, 0.8), Vector3(0, 3.2, -22.5), ice)
	box(Vector3(2.2, 1.0, 1.8), Vector3(0, 1.0, -21.6), ice)
	for sx: float in [-1.0, 1.0]:
		var sp := cyl(0.0, 0.5, 5.0, Vector3(sx * 2.2, 2.5, -22.0), ice, 5)
		sp.rotation_degrees.z = -sx * 14.0
		fire(Vector3(sx * 4.5, 1.3, -6.0), 2.2)

func _layout_throne_basic() -> void:
	var gold := Look.flat(Color("#8a6e34"), 0.38, 0.9)
	for i in 8:
		var z := 8.0 - i * 5.0
		for sx: float in [-1.0, 1.0]:
			column(Vector3(sx * 7.5, 0, z), 13.0, 0.8)
			box(Vector3(1.0, 20.0, 5.0), Vector3(sx * 13.0, 10.0, z))
			banner(Vector3(sx * 7.5, 11.0, z + 0.95), 7.0, Color("#3a0a0a"))
			if i % 2 == 1:
				fire(Vector3(sx * 5.6, 1.5, z), 2.4, 10.0)
	box(Vector3(30, 24, 1.2), Vector3(0, 12, -34))
	window_glow(Vector3(0, 13.0, -33.3), Vector2(2.4, 11.0))
	# dais and the hollow throne
	for i in 4:
		box(Vector3(11.0 - i * 1.6, 0.35, 8.0 - i * 1.2), Vector3(0, 0.17 + i * 0.35, -24))
	box(Vector3(2.6, 7.5, 0.9), Vector3(0, 5.0, -26.5), gold)
	box(Vector3(2.6, 1.0, 2.2), Vector3(0, 1.9, -25.4), gold)
	for sx: float in [-1.0, 1.0]:
		box(Vector3(0.5, 2.0, 2.2), Vector3(sx * 1.4, 2.6, -25.4), gold)
		var sp := cyl(0.0, 0.35, 4.0, Vector3(sx * 1.1, 10.2, -26.5), gold, 4)
		sp.rotation_degrees.z = -sx * 8.0
	# a long, rotted carpet
	box(Vector3(3.0, 0.02, 40.0), Vector3(0, 0.012, -8.0), Look.flat(Color("#2a0808"), 1.0))

func _layout_crag_basic() -> void:
	# a cliff-top eyrie: rock teeth, a nest of timber and bone, the sky all round
	var bone := Look.flat(Color("#d8cfb8"), 0.7)
	var rock := Look.stone(Color(theme.stone).darkened(0.15), 0.25, 0.9, "rock")
	for i in 16:
		var a := TAU * i / 16.0 + rng.randf_range(-0.12, 0.12)
		var d := rng.randf_range(9.0, 15.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d - 3.0)
		if p.z > 5.0 and absf(p.x) < 5.0:
			continue
		var h := rng.randf_range(3.0, 11.0)
		var sp := cyl(0.0, rng.randf_range(1.0, 2.4), h, p + Vector3(0, h * 0.5 - 0.3, 0), rock, 6)
		sp.rotation_degrees = Vector3(rng.randf_range(-14, 14), rng.randf() * 360.0, rng.randf_range(-14, 14))
	# great ribs arcing over the nest
	for i in 5:
		for sx: float in [-1.0, 1.0]:
			var z := -5.0 - i * 1.7
			var lower := cyl(0.2, 0.28, 3.4, Vector3(sx * 3.8, 1.5, z), bone, 7)
			lower.rotation_degrees.z = sx * 18.0
			var upper := cyl(0.08, 0.2, 3.0, Vector3(sx * 2.6, 4.1, z), bone, 7)
			upper.rotation_degrees.z = sx * 52.0
	box(Vector3(0.5, 0.5, 9.0), Vector3(0, 0.25, -8.5), bone)
	# nest: a ring of charred timber
	for i in 22:
		var a2 := TAU * i / 22.0
		box(Vector3(0.3, 0.3, rng.randf_range(2.5, 4.5)), Vector3(cos(a2) * 6.4, rng.randf_range(0.15, 0.7), sin(a2) * 6.4 - 1.0), Look.flat(Color("#1a1410")), Vector3(rng.randf_range(-12, 12), -rad_to_deg(a2) + rng.randf_range(-25, 25), 0))
	tower(Vector3(-13, 0, -16), 4.5, 12, false)
	rubble(Vector3(-10, 0, -12), 10, 2.5)
	for sx: float in [-1.0, 1.0]:
		fire(Vector3(sx * 4.6, 0.25, -5.5), 2.0, 8.0, false)
	# far peaks
	for i in 7:
		var m := cyl(0.0, rng.randf_range(14, 26), rng.randf_range(20, 44), Vector3(rng.randf_range(-90, 90), 2.0, rng.randf_range(-110, -60)), Look.flat(Color(theme.horizon).darkened(0.45)), 5)
		m.position.y = m.mesh.height * 0.5 - 14.0

func _layout_abyss_basic() -> void:
	# the bottom of the kingdom: leaning name-stones, and a dark with shapes in it
	var glowm := Look.glow(Color(theme.fire).darkened(0.2), 1.4)
	for i in 14:
		var a := TAU * i / 14.0 + 0.2
		var d := rng.randf_range(7.0, 11.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d - 3.0)
		if p.z > 4.5 and absf(p.x) < 4.5:
			continue
		var h := rng.randf_range(4.0, 9.0)
		var slab := box(Vector3(rng.randf_range(1.6, 2.6), h, 0.7), p + Vector3(0, h * 0.5 - 0.2, 0), null, Vector3(rng.randf_range(-9, 9), -rad_to_deg(a) + 90.0, rng.randf_range(-9, 9)))
		# rows of names, most worn away
		for k in rng.randi_range(2, 6):
			var line := box(Vector3(rng.randf_range(0.5, 1.3), 0.05, 0.02), Vector3.ZERO, glowm)
			remove_child(line)
			slab.add_child(line)
			line.position = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-h * 0.35, h * 0.4), 0.36)
	# stones that have forgotten which way is down
	for i in 18:
		var s := rng.randf_range(0.4, 1.6)
		box(Vector3(s, s * rng.randf_range(0.5, 1.4), s), Vector3(rng.randf_range(-16, 16), rng.randf_range(4.0, 14.0), rng.randf_range(-22, -4)), null,
			Vector3(rng.randf_range(0, 90), rng.randf_range(0, 90), rng.randf_range(0, 90)))
	# the maw: a ring of standing teeth around a low violet light
	for i in 9:
		var a3 := PI * (0.15 + 0.7 * i / 8.0)
		var t := cyl(0.0, 0.7, 6.0, Vector3(cos(a3) * 6.0, 3.0, -14.0 - sin(a3) * 3.0), mat_dark, 5)
		t.rotation_degrees.z = (cos(a3)) * 18.0
	window_glow(Vector3(0, 3.0, -17.5), Vector2(7.0, 5.0))
	for sx: float in [-1.0, 1.0]:
		fire(Vector3(sx * 4.8, 1.3, -5.0), 1.8, 9.0)

func _layout_chapel() -> void:
	# a small round chapel: the one place the curse has not reached
	for i in 10:
		var a := TAU * i / 10.0 + 0.3
		var p := Vector3(cos(a) * 7.5, 0, sin(a) * 7.5 - 1.0)
		if p.z > 4.0:
			continue
		column(p, 5.5, 0.42, i == 3)
		box(Vector3(4.6, 7.0, 0.8), Vector3(cos(a + 0.31) * 9.2, 3.5, sin(a + 0.31) * 9.2 - 1.0), null, Vector3(0, -rad_to_deg(a + 0.31) + 90.0, 0))
	box(Vector3(2.4, 1.0, 1.1), Vector3(0, 0.5, -5.0))
	box(Vector3(2.8, 0.14, 1.4), Vector3(0, 1.07, -5.0))
	window_glow(Vector3(0, 4.6, -8.6), Vector2(0.9, 3.2))
	fire(Vector3(0, 1.32, -5.0), 2.6, 11.0, false)
	for i in 9:
		var c := Vector3(rng.randf_range(-1.1, 1.1), 1.14, -5.0 + rng.randf_range(-0.5, 0.5))
		var h := rng.randf_range(0.1, 0.32)
		cyl(0.025, 0.03, h, c + Vector3(0, h * 0.5, 0), Look.flat(Color("#d8cfb8")), 6)
		box(Vector3(0.02, 0.04, 0.02), c + Vector3(0, h + 0.03, 0), Look.glow(Color(theme.fire), 3.0))
	for sx: float in [-1.0, 1.0]:
		fire(Vector3(sx * 3.4, 1.3, -2.5), 1.8, 8.0)
	rubble(Vector3(5, 0, -5), 5, 1.2)

# ---------------------------------------------------------------- particles
func _quad(s: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(s, s)
	return q

func _fade(a: Color, b: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	return g

## Takes `want` particles from the arena's budget (scaled by the particle setting); returns what is granted.
func _allot(want: int) -> int:
	var n: int = clampi(int(round(want * Fx.pscale())), 0, PARTICLE_BUDGET - _live)
	_live += n
	return n

## Ambient life. `kinds` is one or more emitter names joined with "+".
func _particles(kinds: String) -> void:
	for kind: String in kinds.split("+"):
		_ambient(kind)

func _ambient(kind: String) -> void:
	var p := CPUParticles3D.new()
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(12, 0.5, 12)
	p.position = Vector3(0, 0.5, -3)
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var want := 40
	match kind:
		"embers":
			want = 50
			p.mesh = _quad(0.045)
			p.material_override = Look.particle(Color(1.0, 0.5, 0.15))
			p.gravity = Vector3(0.15, 0.5, 0.1)
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.6
			p.direction = Vector3.UP
			p.spread = 40.0
			p.color_ramp = _fade(Color(1, 1, 1, 1), Color(1, 0.2, 0.0, 0.0))
		"ash":
			want = 60
			p.position.y = 8.0
			p.mesh = _quad(0.05)
			p.material_override = Look.particle(Color(0.7, 0.66, 0.62, 0.8), false)
			p.gravity = Vector3(0.1, -0.5, 0.0)
			p.color_ramp = _fade(Color(1, 1, 1, 1), Color(1, 1, 1, 0.0))
		"snow":
			want = 110
			p.position.y = 9.0
			p.lifetime = 6.0
			p.preprocess = 6.0
			p.mesh = _quad(0.05)
			p.material_override = Look.particle(Color(0.9, 0.95, 1.0, 0.9), false)
			p.gravity = Vector3(-0.9, -1.4, 0.3)
			p.color_ramp = _fade(Color(1, 1, 1, 1), Color(1, 1, 1, 0.3))
		"spores":
			# slow, large, faintly lit: the Deep breathes
			want = 55
			p.position.y = 1.2
			p.emission_box_extents = Vector3(11, 1.4, 11)
			p.lifetime = 9.0
			p.preprocess = 9.0
			p.mesh = _quad(0.07)
			p.material_override = Look.particle(Color(theme.fire).lerp(Color(0.55, 0.9, 1.0), 0.35))
			p.gravity = Vector3(0.02, 0.07, -0.02)
			p.initial_velocity_min = 0.02
			p.initial_velocity_max = 0.12
			p.spread = 180.0
			p.scale_amount_min = 0.4
			p.scale_amount_max = 1.2
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 0))
			g.set_color(1, Color(1, 1, 1, 0))
			g.add_point(0.3, Color(1, 1, 1, 0.75))
			g.add_point(0.7, Color(1, 1, 1, 0.5))
			p.color_ramp = g
		"leaves":
			want = 34
			p.position.y = 7.0
			p.emission_box_extents = Vector3(11, 1.0, 11)
			p.lifetime = 8.0
			p.preprocess = 8.0
			p.mesh = _quad(0.13)
			p.material_override = Look.leaf()
			p.gravity = Vector3(0.25, -0.95, 0.1)
			p.initial_velocity_min = 0.0
			p.initial_velocity_max = 0.4
			p.spread = 180.0
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -140.0
			p.angular_velocity_max = 140.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.3
			p.color = Color(0.42, 0.36, 0.2)
			p.color_ramp = _fade(Color(1, 1, 1, 1), Color(0.8, 0.8, 0.8, 0.0))
		"mist":
			# low ground mist: a few big, very faint sheets drifting over the wet floor
			want = 14
			p.position.y = 0.25
			p.emission_box_extents = Vector3(10, 0.1, 10)
			p.lifetime = 10.0
			p.preprocess = 10.0
			p.mesh = _quad(3.2)
			p.material_override = Look.particle(Color(theme.fog).lerp(Color(theme.fire), 0.25).lightened(0.3), false)
			p.gravity = Vector3(0.05, 0.0, 0.03)
			p.initial_velocity_min = 0.02
			p.initial_velocity_max = 0.1
			p.spread = 180.0
			p.flatness = 1.0
			var gm := Gradient.new()
			gm.set_color(0, Color(1, 1, 1, 0))
			gm.set_color(1, Color(1, 1, 1, 0))
			gm.add_point(0.5, Color(1, 1, 1, 0.1))
			p.color_ramp = gm
		_:
			want = 40
			p.position.y = 1.5
			p.emission_box_extents = Vector3(10, 1.5, 10)
			p.mesh = _quad(0.035)
			p.material_override = Look.particle(Color(theme.fire).lerp(Color.WHITE, 0.3))
			p.gravity = Vector3(0.03, 0.04, 0)
			p.color_ramp = _fade(Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0))
	var n := _allot(want)
	if n <= 0:
		p.free()
		return
	p.amount = n
	add_child(p)

func _process(delta: float) -> void:
	_clock += delta
	for f in fires:
		var l: OmniLight3D = f[0]
		var t: float = _clock * 7.0 + f[2]
		l.light_energy = f[1] * (0.86 + 0.09 * sin(t) + 0.07 * sin(t * 2.7 + 1.3) + 0.05 * sin(t * 6.1 + f[2]))

## Phase changes can stain the whole arena (embers, frost, the white crown).
func tint(c: Color, amount: float, time: float = 1.5) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(env, "fog_light_color", Color(theme.fog).lerp(c, amount), time)
	tw.tween_property(env, "ambient_light_color", Color(theme.amb).lerp(c, amount * 0.6), time)


# ================================================================ generated kits for the later regions
## Each falls back to the primitive layout until its kit has been generated.
func _kit(pre: String, first: String) -> bool:
	return PropModel.exists("res://assets/models/env_%s_%s.glb" % [pre, first])

func _glow(at: Vector3, color: Color, energy: float = 1.8, reach: float = 8.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.3
	l.position = at
	add_child(l)
	if color.is_equal_approx(Color(theme.fire)):
		fires.append([l, energy, rng.randf() * 10.0])

## A lit brazier from a kit: flickering light and a small flame over the bowl.
func _brazier(at: Vector3, energy: float, reach: float) -> void:
	fire(at, energy, reach, false)

## The Cathedral of Ash: a burned nave, pillars marching to the altar behind the foe.
func _layout_nave() -> void:
	if not _kit("ca", "pillar"):
		_layout_nave_basic()
		return
	sun.directional_shadow_max_distance = 55.0
	for i in 6:
		for sx: float in [-1.0, 1.0]:
			prop("ca_pillar", 15.0, Vector3(sx * 8.5, 0, 10.0 - i * 6.5), 90.0 * i)
			if i % 2 == 0:
				prop("ca_window", 11.0, Vector3(sx * 14.5, 0, 8.0 - i * 6.5), 90.0 * sx)
	prop("ca_altar", 6.5, Vector3(0, 0, -17.0), 0.0)
	prop("ca_statue", 7.5, Vector3(-5.5, 0, -14.5), 15.0)
	prop("ca_statue", 7.5, Vector3(5.5, 0, -14.5), -15.0)
	prop("ca_bell", 4.2, Vector3(-5.8, 0, -3.5), 30.0)
	prop("ca_censer", 4.6, Vector3(5.2, 0, -5.5), 0.0)
	prop("ca_censer", 4.6, Vector3(-4.8, 0, 6.5), 0.0)
	for i in 4:
		prop("ca_pew", 1.5, Vector3(-5.2 + rng.randf_range(-0.4, 0.4), 0, 9.0 + i * 2.6), 180.0 + rng.randf_range(-12.0, 12.0))
		prop("ca_pew", 1.5, Vector3(5.2 + rng.randf_range(-0.4, 0.4), 0, 9.0 + i * 2.6), 180.0 + rng.randf_range(-12.0, 12.0))
	_glow(Vector3(0, 3.5, -15.5), Color(theme.fire), 2.4, 12.0)
	_glow(Vector3(5.2, 2.6, -5.5), Color(theme.fire), 1.5, 7.0)
	_glow(Vector3(-4.8, 2.6, 6.5), Color(theme.fire), 1.5, 7.0)

## The Sunken Crypt: a flooded vault of tombs and corpse-light.
func _layout_vault() -> void:
	if not _kit("cr", "sarcophagus"):
		_layout_vault_basic()
		return
	sun.directional_shadow_max_distance = 40.0
	prop("cr_gate", 8.5, Vector3(0, 0, -15.0), 0.0)
	for i in 5:
		for sx: float in [-1.0, 1.0]:
			prop("cr_pillar", 6.5, Vector3(sx * 7.5, 0, 9.0 - i * 6.0), 45.0 * i)
			_glow(Vector3(sx * 7.2, 2.6, 9.0 - i * 6.0), Color(theme.fire), 0.9, 5.5)
	prop("cr_arch", 7.5, Vector3(-12.0, 0, -6.0), 90.0)
	prop("cr_arch", 7.5, Vector3(12.0, 0, -6.0), -90.0)
	prop("cr_arch", 7.5, Vector3(0, 0, 16.0), 180.0)
	for t in [[-4.8, -6.5, 20.0], [4.6, -7.5, -15.0], [-10.5, 2.0, 80.0], [10.5, 3.5, -75.0], [-4.0, 9.5, 10.0], [5.0, 10.5, 170.0]]:
		prop("cr_sarcophagus", 2.3, Vector3(t[0], 0, t[1]), t[2])
	prop("cr_coffins", 2.6, Vector3(-9.5, 0, -10.5), 30.0)
	prop("cr_coffins", 2.6, Vector3(9.0, 0, 9.0), 200.0)
	prop("cr_urns", 1.9, Vector3(6.2, 0, -3.0), 0.0)
	prop("cr_urns", 1.9, Vector3(-6.5, 0, 4.5), 140.0)
	for c in [Vector3(-3.6, 0, -5.0), Vector3(3.8, 0, -5.6), Vector3(-6.5, 0, 0.0), Vector3(6.6, 0, 6.0)]:
		prop("cr_candelabra", 3.2, c, rng.randf() * 360.0)
		_glow(c + Vector3(0, 2.8, 0), Color(theme.fire), 1.2, 6.0)

## The Wyrm's Roost: a volcanic eyrie among the bones of older dragons.
func _layout_crag() -> void:
	if not _kit("ro", "spire"):
		_layout_crag_basic()
		return
	sun.directional_shadow_max_distance = 70.0
	for i in 14:
		var a := TAU * i / 14.0 + 0.3
		var d := rng.randf_range(17.0, 30.0)
		prop("ro_spire", rng.randf_range(12.0, 26.0), Vector3(cos(a) * d, -0.5, sin(a) * d - 3.0), rng.randf() * 360.0)
	prop("ro_skull", 7.0, Vector3(0.5, 0, -14.0), 0.0)
	prop("ro_ribs", 8.0, Vector3(-11.0, 0, -6.0), 60.0)
	prop("ro_ribs", 6.5, Vector3(12.0, 0, 4.0), -110.0)
	prop("ro_arch", 9.0, Vector3(11.5, 0, -9.5), -40.0)
	prop("ro_nest", 4.2, Vector3(-9.5, 0, 6.5), 0.0)
	prop("ro_wreck", 4.8, Vector3(8.0, 0, 11.0), 150.0)
	for b in [Vector3(-5.5, 0, -5.0), Vector3(5.8, 0, -4.4), Vector3(-6.5, 0, 9.5)]:
		prop("ro_brazier", 2.6, b, rng.randf() * 360.0)
		_brazier(b + Vector3(0, 2.25, 0), 2.0, 9.0)
	_glow(Vector3(-9.5, 1.5, 6.5), Color("#ff8a3a"), 1.4, 6.0)

## The Frozen Citadel: a king's hall under ice.
func _layout_hall() -> void:
	if not _kit("ci", "pillar"):
		_layout_hall_basic()
		return
	sun.directional_shadow_max_distance = 55.0
	prop("ci_throne", 6.5, Vector3(0, 0, -15.5), 0.0)
	prop("ci_gate", 10.0, Vector3(0, 0, 18.0), 180.0)
	for i in 5:
		for sx: float in [-1.0, 1.0]:
			prop("ci_pillar", 12.0, Vector3(sx * 8.0, 0, 10.0 - i * 6.2), 0.0)
	for sx2: float in [-1.0, 1.0]:
		prop("ci_wall", 7.5, Vector3(sx2 * 16.5, 0, -4.0), 90.0 * sx2)
		prop("ci_wall", 7.5, Vector3(sx2 * 16.5, 0, 9.0), 90.0 * sx2)
		prop("ci_statue", 7.0, Vector3(sx2 * 5.0, 0, -12.5), -20.0 * sx2)
	for sh in [[-10.5, -9.0, 4.5], [11.0, 2.0, 3.6], [-9.5, 8.0, 3.0], [6.0, -8.5, 2.6]]:
		prop("ci_shard", sh[2], Vector3(sh[0], 0, sh[1]), rng.randf() * 360.0)
		_glow(Vector3(sh[0], 1.4, sh[1]), Color("#7fe0ff"), 1.0, 6.0)
	for b in [Vector3(-4.6, 0, -5.5), Vector3(4.6, 0, -5.5), Vector3(-4.6, 0, 6.5), Vector3(4.6, 0, 6.5)]:
		prop("ci_brazier", 3.6, b, 0.0)
		_brazier(b + Vector3(0, 3.1, 0), 1.6, 8.0)

## The Hollow Deep: the machine under the world, and what grows on it.
func _layout_abyss() -> void:
	if not _kit("de", "pillar"):
		_layout_abyss_basic()
		return
	sun.directional_shadow_max_distance = 45.0
	for i in 10:
		var a := TAU * i / 10.0 + 0.15
		var d := rng.randf_range(14.0, 24.0)
		prop("de_pillar", rng.randf_range(16.0, 28.0), Vector3(cos(a) * d, -1.0, sin(a) * d - 2.0), rng.randf() * 360.0)
	prop("de_conduit", 6.0, Vector3(-11.0, 0, -9.0), 35.0)
	prop("de_conduit", 5.0, Vector3(12.0, 0, 6.0), 200.0)
	prop("de_bridge", 5.5, Vector3(0.5, 0, -15.0), 0.0)
	prop("de_husk", 3.2, Vector3(5.6, 0, -6.2), -30.0)
	prop("de_husk", 3.2, Vector3(-6.0, 0, 7.0), 150.0)
	for c in [[-5.0, -5.5, 3.8], [8.5, -2.0, 3.0], [-9.0, 2.5, 4.4], [4.5, 9.0, 3.2]]:
		prop("de_crystal", c[2], Vector3(c[0], 0, c[1]), rng.randf() * 360.0)
		_glow(Vector3(c[0], 1.6, c[1]), Color(theme.fire), 1.3, 6.5)
	for f in [[6.5, 3.5, 3.4], [-4.0, 11.0, 4.2], [-11.5, -2.5, 3.0], [10.0, -9.0, 4.8]]:
		prop("de_fungus", f[2], Vector3(f[0], 0, f[1]), rng.randf() * 360.0)
		_glow(Vector3(f[0], 2.0, f[1]), Color("#9ab8ff"), 1.0, 6.0)
	for i in 7:
		var a2 := TAU * i / 7.0
		prop("de_rock", rng.randf_range(1.6, 3.4), Vector3(cos(a2) * 8.8, 0, sin(a2) * 8.8), rng.randf() * 360.0)

## The Hollow Throne: the last hall, and the crown-machine at the end of it.
func _layout_throne() -> void:
	if not _kit("th", "pillar"):
		_layout_throne_basic()
		return
	sun.directional_shadow_max_distance = 60.0
	prop("th_stairs", 2.6, Vector3(0, 0, -12.5), 0.0)
	prop("th_throne", 12.0, Vector3(0, 0.6, -18.0), 0.0)
	_glow(Vector3(0, 7.0, -15.5), Color(theme.fire), 3.0, 16.0)
	for i in 6:
		for sx: float in [-1.0, 1.0]:
			prop("th_pillar", 14.0, Vector3(sx * 8.5, 0, 12.0 - i * 6.0), 0.0)
			if i % 2 == 1:
				prop("th_banner", 8.5, Vector3(sx * 6.4, 0, 12.0 - i * 6.0), 90.0 * sx)
	for sx2: float in [-1.0, 1.0]:
		prop("th_statue", 8.0, Vector3(sx2 * 5.2, 0, -10.0), -25.0 * sx2)
		prop("th_statue", 8.0, Vector3(sx2 * 13.0, 0, 3.0), -90.0 * sx2)
	prop("th_ring", 3.4, Vector3(-9.5, 0, 8.5), 40.0)
	prop("th_ring", 2.6, Vector3(10.5, 0, -4.5), 160.0)
	for b in [Vector3(-4.4, 0, -6.0), Vector3(4.4, 0, -6.0), Vector3(-4.4, 0, 5.0), Vector3(4.4, 0, 5.0)]:
		prop("th_brazier", 2.4, b, 0.0)
		_brazier(b + Vector3(0, 2.1, 0), 1.8, 8.5)

## The resurrection chamber: a round stone-and-metal room with the cradle in the middle, machine pylons round the
## wall, a block the sword was left in, and one door (at -Z) that the story scene opens. Named nodes for that scene:
## "Door" (the panel), "DoorGlow" (the light beyond it), "Rack" (where the sword stands), "Lyra" (the light she speaks through).
const CHAMBER_R := 6.2
func _layout_chamber() -> void:
	var metal := Look.flat(Color("#2a2c2e"), 0.45, 0.85)
	var amber := Look.glow(Color(theme.fire), 2.2)
	var teal := Look.glow(Color("#5fe0c8"), 2.0)
	var n := 22
	for i in n:
		var a := TAU * (i + 0.5) / n
		var dir := Vector3(sin(a), 0, cos(a))
		if absf(wrapf(a - PI, -PI, PI)) < TAU / n * 0.8:
			continue          # the doorway
		var w := box(Vector3(TAU * CHAMBER_R / n + 0.12, 5.4, 0.7), dir * CHAMBER_R + Vector3(0, 2.7, 0), null, Vector3(0, rad_to_deg(a), 0))
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# a metal band at head height, and every third panel carries a strip of machine light
		box(Vector3(TAU * CHAMBER_R / n + 0.14, 0.22, 0.1), dir * (CHAMBER_R - 0.38) + Vector3(0, 2.6, 0), metal, Vector3(0, rad_to_deg(a), 0))
		if i % 3 == 1:
			box(Vector3(0.09, 1.5, 0.05), dir * (CHAMBER_R - 0.37) + Vector3(0, 1.5, 0), teal if i % 6 == 1 else amber, Vector3(0, rad_to_deg(a), 0))
	# ceiling and its ring of dead lamps
	cyl(CHAMBER_R + 0.6, CHAMBER_R + 0.6, 0.4, Vector3(0, 5.5, 0), mat_dark, 22)
	cyl(2.4, 2.6, 0.25, Vector3(0, 5.25, 0), metal, 16)
	# door frame, the panel that slides up, and the daylight waiting behind it
	var dz := -CHAMBER_R
	box(Vector3(0.5, 3.4, 0.9), Vector3(-1.25, 1.7, dz), metal)
	box(Vector3(0.5, 3.4, 0.9), Vector3(1.25, 1.7, dz), metal)
	box(Vector3(3.0, 0.5, 0.9), Vector3(0, 3.55, dz), metal)
	box(Vector3(3.0, 1.6, 0.7), Vector3(0, 4.6, dz), null)
	var door := box(Vector3(2.0, 3.3, 0.22), Vector3(0, 1.65, dz), Look.flat(Color("#3a3c3e"), 0.5, 0.8))
	door.name = "Door"
	var seam := box(Vector3(0.06, 3.0, 0.24), Vector3.ZERO, amber)
	remove_child(seam)
	door.add_child(seam)
	# the passage beyond: short, and white with daylight at the end
	for sx: float in [-1.0, 1.0]:
		box(Vector3(0.6, 4.0, 6.0), Vector3(sx * 1.6, 2.0, dz - 3.4), null)
	box(Vector3(3.8, 0.5, 6.0), Vector3(0, 4.0, dz - 3.4), null)
	var day := box(Vector3(3.0, 4.0, 0.1), Vector3(0, 2.0, dz - 6.3), Look.glow(Color("#fff4e0"), 5.0))
	day.name = "Daylight"
	var dg := OmniLight3D.new()
	dg.name = "DoorGlow"
	dg.light_color = Color("#fff0d8")
	dg.light_energy = 0.0
	dg.omni_range = 16.0
	dg.omni_attenuation = 0.9
	dg.shadow_enabled = true
	dg.position = Vector3(0, 2.2, dz - 2.2)
	add_child(dg)
	# the cradle: a stone bed in a metal frame, its cover long since slid off
	box(Vector3(1.3, 0.5, 2.6), Vector3(0, 0.25, 0), null)
	box(Vector3(1.5, 0.12, 2.8), Vector3(0, 0.52, 0), metal)
	box(Vector3(1.1, 0.06, 2.4), Vector3(0, 0.6, 0), Look.flat(Color("#1c1e20"), 0.7, 0.3))
	box(Vector3(1.4, 0.1, 2.7), Vector3(1.45, 0.3, 0.5), metal, Vector3(0, 14, -68))
	for sz: float in [-1.0, 1.0]:
		box(Vector3(0.05, 0.05, 0.9), Vector3(-0.76, 0.5, sz * 0.7), teal)
		box(Vector3(0.05, 0.05, 0.9), Vector3(0.76, 0.5, sz * 0.7), teal)
	cyl(0.07, 0.07, 4.7, Vector3(0, 2.95, -1.25), metal, 6)
	cyl(0.5, 0.2, 0.3, Vector3(0, 5.1, -1.25), metal, 8)
	# machine pylons between the wall panels, with conduits where the kit has them
	for i in 6:
		var a2 := TAU * (i + 0.5) / 6.0 + 0.2
		var at := Vector3(sin(a2), 0, cos(a2)) * (CHAMBER_R - 1.0)
		if absf(wrapf(a2 - PI, -PI, PI)) < 0.5:
			continue
		box(Vector3(0.7, 3.0, 0.7), at + Vector3(0, 1.5, 0), metal, Vector3(0, rad_to_deg(a2), 0))
		box(Vector3(0.9, 0.3, 0.9), at + Vector3(0, 0.15, 0), null, Vector3(0, rad_to_deg(a2), 0))
		var lit: Material = amber if i % 2 == 1 else teal
		box(Vector3(0.74, 0.08, 0.74), at + Vector3(0, 2.2, 0), lit, Vector3(0, rad_to_deg(a2), 0))
		box(Vector3(0.74, 0.05, 0.74), at + Vector3(0, 1.1, 0), lit, Vector3(0, rad_to_deg(a2), 0))
		cyl(0.06, 0.06, 2.6, at * 1.02 + Vector3(0, 4.2, 0), metal, 6)
		_glow(at * 0.86 + Vector3(0, 1.8, 0), Color(theme.fire) if i % 2 == 1 else Color("#5fe0c8"), 0.55, 4.5)
	_chamber_machine(metal, amber, teal)
	# the voice in the walls: a grille over the cradle's head with a light behind it
	var ly := OmniLight3D.new()
	ly.name = "Lyra"
	ly.light_color = Color("#7fe6d8")
	ly.light_energy = 0.0
	ly.omni_range = 7.0
	ly.position = Vector3(-2.6, 2.6, -4.2)
	add_child(ly)
	box(Vector3(0.9, 0.9, 0.12), Vector3(-3.05, 2.6, -5.0), metal, Vector3(0, 31, 0))
	box(Vector3(0.6, 0.6, 0.14), Vector3(-3.04, 2.6, -4.98), teal, Vector3(0, 31, 0))
	# the block the sword was left standing in
	var rack := Node3D.new()
	rack.name = "Rack"
	rack.position = Vector3(3.1, 0, -1.4)
	add_child(rack)
	box(Vector3(0.8, 0.5, 0.8), rack.position + Vector3(0, 0.25, 0), null, Vector3(0, 20, 0))
	box(Vector3(1.2, 0.14, 1.2), rack.position + Vector3(0, 0.07, 0), metal, Vector3(0, 20, 0))
	rubble(Vector3(-3.6, 0, 2.6), 5, 1.0)
	rubble(Vector3(3.4, 0, 3.4), 4, 0.8)

## What makes the chamber a machine rather than a round room: old stone from the kits standing between the panels,
## conduits and the crown-ring from the regions that came after it, the cradle's ribs and its head unit, cables
## across the floor from the cradle to every pylon and to the block, banks of small lit readouts on the wall, and a
## band of metal let into the floor round the cradle. The merged pieces are one draw each.
func _chamber_machine(metal: Material, amber: Material, teal: Material) -> void:
	var dark := Look.flat(Color("#17191b"), 0.6, 0.6)
	# kit stone and machinery round the wall (each only if its kit is there), kept out of the story cameras' way
	for c0: Array in [[-5.2, 1.6], [-4.7, -3.0], [4.8, -3.4]]:
		var p := prop("cr_pillar", 5.3, Vector3(float(c0[0]), 0, float(c0[1])), rad_to_deg(atan2(float(c0[0]), float(c0[1]))))
		if p:
			Look.set_param(p, &"tint", Color(0.62, 0.66, 0.66))
	for c: Array in [[-4.3, 3.0, 130.0], [-5.0, -0.5, 80.0], [3.0, -4.9, -30.0]]:
		prop("de_conduit", 2.6, Vector3(float(c[0]), 0, float(c[1])), float(c[2]))
	var ring := prop("th_ring", 2.2, Vector3(-3.6, 0, 4.2), 140.0)
	if ring:
		Look.set_param(ring, &"tint", Color(0.5, 0.55, 0.55))
	# the cradle: three hoops over the bed, a head unit with its panel, feet under the frame
	var solid: Array = []
	var hoops: Array = []
	var lit_teal: Array = []
	var lit_amber: Array = []
	for k in 3:
		var z := -0.9 + k * 0.75
		for sx: float in [-1.0, 1.0]:
			hoops.append([Vector3(0.05, 0.5, 0.06), Vector3(sx * 0.74, 0.8, z), Vector3(0, 0, sx * -14.0)])
			hoops.append([Vector3(0.05, 0.42, 0.06), Vector3(sx * 0.52, 1.14, z), Vector3(0, 0, sx * -56.0)])
		hoops.append([Vector3(0.72, 0.05, 0.06), Vector3(0, 1.26, z)])
	solid.append([Vector3(1.7, 1.7, 0.5), Vector3(0, 0.85, -1.62)])
	solid.append([Vector3(1.2, 0.4, 0.6), Vector3(0, 1.9, -1.6)])
	lit_teal.append([Vector3(1.1, 0.5, 0.04), Vector3(0, 1.2, -1.36)])
	lit_amber.append([Vector3(0.9, 0.06, 0.04), Vector3(0, 0.78, -1.36)])
	for sx2: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			solid.append([Vector3(0.22, 0.2, 0.3), Vector3(sx2 * 0.7, 0.1, sz * 1.15)])
	Highland._solid(self, "Hoops", hoops, metal, false)
	# readouts: banks of small lights on the wall panels, some of them out
	for i in 22:
		var a2 := TAU * (i + 0.5) / 22.0
		if absf(wrapf(a2 - PI, -PI, PI)) < TAU / 22.0 * 1.6 or i % 3 == 1:
			continue
		var dir := Vector3(sin(a2), 0, cos(a2))
		var side := Vector3(cos(a2), 0, -sin(a2))
		solid.append([Vector3(1.2, 0.9, 0.06), dir * (CHAMBER_R - 0.37) + Vector3(0, 1.55, 0), Vector3(0, rad_to_deg(a2), 0)])
		for r in 3:
			for c2 in 5:
				if rng.randf() < 0.35:
					continue
				var where := dir * (CHAMBER_R - 0.41) + side * ((c2 - 2) * 0.2) + Vector3(0, 1.3 + r * 0.25, 0)
				(lit_teal if rng.randf() < 0.6 else lit_amber).append([Vector3(0.12 if rng.randf() < 0.7 else 0.17, 0.07, 0.02), where, Vector3(0, rad_to_deg(a2), 0)])
	Highland._solid(self, "Machine", solid, dark, false)
	Highland._solid(self, "ReadoutsTeal", lit_teal, teal, false)
	Highland._solid(self, "ReadoutsAmber", lit_amber, amber, false)
	# cables: from under the cradle out to each pylon and to the block, lying in loops on the floor
	var cables := SurfaceTool.new()
	cables.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ends: Array = [Vector3(3.1, 0.2, -1.4), Vector3(-2.8, 1.2, -4.6)]
	for i in 6:
		var a3 := TAU * (i + 0.5) / 6.0 + 0.2
		if absf(wrapf(a3 - PI, -PI, PI)) >= 0.5:
			ends.append(Vector3(sin(a3), 0, cos(a3)) * (CHAMBER_R - 1.35) + Vector3(0, 0.5, 0))
	for e: Vector3 in ends:
		var from := Vector3(clampf(e.x, -0.5, 0.5), 0.3, clampf(e.z, -1.2, 1.2))
		var bow := Vector3(-(e.z - from.z), 0, e.x - from.x).normalized() * rng.randf_range(-0.9, 0.9)
		var last := from
		for s in range(1, 11):
			var t := float(s) / 10.0
			var pt := from.lerp(e, t) + bow * sin(t * PI)
			pt.y = lerpf(0.045, lerpf(from.y, e.y, t), pow(absf(t * 2.0 - 1.0), 3.0))
			var seg := CylinderMesh.new()
			seg.top_radius = 0.035
			seg.bottom_radius = 0.035
			seg.height = last.distance_to(pt) + 0.03
			seg.radial_segments = 5
			seg.rings = 1
			cables.append_from(seg, 0, Transform3D(Basis(Quaternion(Vector3.UP, (pt - last).normalized())), (last + pt) * 0.5))
			last = pt
	var cmi := MeshInstance3D.new()
	cmi.name = "Cables"
	cmi.mesh = cables.commit()
	cmi.material_override = dark
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cmi)
	# a band of metal let into the floor round the cradle, and the block's own ring
	var band := TorusMesh.new()
	band.inner_radius = 2.5
	band.outer_radius = 2.62
	band.rings = 48
	band.ring_segments = 4
	var bmi := MeshInstance3D.new()
	bmi.mesh = band
	bmi.scale = Vector3(1, 0.12, 1)
	bmi.position = Vector3(0, 0.005, 0)
	bmi.material_override = metal
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bmi)
	set_meta("machine_light", teal)

## The high road and the Ring-Gate (the prologue's place, and a duel's): everything is in src/world/highland.gd.
func _layout_highland() -> void:
	Highland.build(self)
