class_name Arena
extends Node3D
## Builds a region's duel arena procedurally from a theme table.
## The fight happens on the Z axis around the origin; the camera sits at +Z.

const THEMES := {
	"courtyard": {"sky": "#0b0f18", "horizon": "#27303c", "fog": "#1a212b", "fog_d": 0.035, "sun": "#8fa6c8", "sun_e": 1.1, "sun_rot": Vector3(-38, 150, 0),
		"stone": "#55524e", "floor": "#4a4845", "fire": "#ff7a2a", "layout": "ruin", "particles": "embers", "amb": "#2a3340"},
	"blackwood": {"sky": "#070a09", "horizon": "#1a241c", "fog": "#131b15", "fog_d": 0.06, "sun": "#7f9a86", "sun_e": 0.7, "sun_rot": Vector3(-55, 120, 0),
		"stone": "#3a3a32", "floor": "#2c2e25", "fire": "#c8d86a", "layout": "forest", "particles": "motes", "amb": "#1c2a20"},
	"cathedral": {"sky": "#120b08", "horizon": "#4a2414", "fog": "#2a1810", "fog_d": 0.04, "sun": "#ffb070", "sun_e": 0.9, "sun_rot": Vector3(-30, 200, 0),
		"stone": "#5a4e44", "floor": "#4c423a", "fire": "#ff6a22", "layout": "nave", "particles": "ash", "amb": "#3a2418"},
	"cathedral_steps": {"sky": "#120b08", "horizon": "#5a2a16", "fog": "#2a1810", "fog_d": 0.03, "sun": "#ffb070", "sun_e": 1.0, "sun_rot": Vector3(-25, 170, 0),
		"stone": "#5a4e44", "floor": "#4c423a", "fire": "#ff6a22", "layout": "facade", "particles": "ash", "amb": "#3a2418"},
	"crypt": {"sky": "#020405", "horizon": "#06100f", "fog": "#0a1614", "fog_d": 0.07, "sun": "#5fa894", "sun_e": 0.35, "sun_rot": Vector3(-70, 90, 0),
		"stone": "#3c4440", "floor": "#1a2422", "fire": "#5fe0b8", "layout": "vault", "particles": "motes", "amb": "#10201c", "wet": true},
	"citadel": {"sky": "#0c1220", "horizon": "#5a7088", "fog": "#3a4a5c", "fog_d": 0.045, "sun": "#bcd4f0", "sun_e": 1.3, "sun_rot": Vector3(-35, 140, 0),
		"stone": "#6a7480", "floor": "#8a96a2", "fire": "#7fd4ff", "layout": "hall", "particles": "snow", "amb": "#3c4c60"},
	"sanctuary": {"sky": "#07070a", "horizon": "#1c1a1c", "fog": "#15120f", "fog_d": 0.045, "sun": "#c8b8a0", "sun_e": 0.5, "sun_rot": Vector3(-50, 160, 0),
		"stone": "#5c564e", "floor": "#48423a", "fire": "#ffb45a", "layout": "chapel", "particles": "motes", "amb": "#3a3028"},
	"throne": {"sky": "#060404", "horizon": "#2a1a10", "fog": "#16100c", "fog_d": 0.03, "sun": "#ffd9a0", "sun_e": 0.9, "sun_rot": Vector3(-48, 180, 0),
		"stone": "#4a443c", "floor": "#2e2a26", "fire": "#ffc860", "layout": "throne", "particles": "motes", "amb": "#2a2018", "wet": true},
}

var theme := {}
var rng := RandomNumberGenerator.new()
var env: Environment
var sun: DirectionalLight3D
var fires: Array = []
var mat_stone: StandardMaterial3D
var mat_dark: StandardMaterial3D
var _clock := 0.0

static func theme_for(region_theme: String, arena: String = "") -> String:
	if arena != "" and THEMES.has(arena):
		return arena
	return region_theme if THEMES.has(region_theme) else "courtyard"

func build(theme_id: String) -> void:
	theme = THEMES[theme_id]
	rng.seed = hash(theme_id)
	mat_stone = Look.stone(Color(theme.stone))
	mat_dark = Look.flat(Color(theme.stone).darkened(0.7), 1.0)
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
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(theme.amb)
	env.ambient_light_energy = 1.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.fog_enabled = true
	env.fog_light_color = Color(theme.fog)
	env.fog_density = theme.fog_d
	env.fog_sky_affect = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.08
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
	rim.light_color = Color(theme.fire).lerp(Color.WHITE, 0.4)
	rim.light_energy = 0.45
	rim.rotation_degrees = Vector3(-20, 20, 0)
	add_child(rim)

func _floor() -> void:
	var m := Look.stone(Color(theme.floor), 0.22, 0.42 if theme.get("wet", false) else 0.74, "floor")
	m.metallic = 0.25 if theme.get("wet", false) else 0.05
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
	r.material_override = Look.flat(Color(theme.stone).darkened(0.35), 0.6, 0.3)
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
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 14
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
func _layout_ruin() -> void:
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

func _layout_forest() -> void:
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

func _layout_nave() -> void:
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

func _layout_vault() -> void:
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

func _layout_hall() -> void:
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

func _layout_throne() -> void:
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

func _particles(kind: String) -> void:
	var p := CPUParticles3D.new()
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(12, 0.5, 12)
	p.position = Vector3(0, 0.5, -3)
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	match kind:
		"embers":
			p.amount = 70
			p.mesh = _quad(0.045)
			p.material_override = Look.particle(Color(1.0, 0.5, 0.15))
			p.gravity = Vector3(0.15, 0.5, 0.1)
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.6
			p.direction = Vector3.UP
			p.spread = 40.0
			p.color_ramp = _fade(Color(1, 1, 1, 1), Color(1, 0.2, 0.0, 0.0))
		"ash":
			p.amount = 110
			p.position.y = 8.0
			p.mesh = _quad(0.05)
			p.material_override = Look.particle(Color(0.7, 0.66, 0.62, 0.8), false)
			p.gravity = Vector3(0.1, -0.5, 0.0)
			p.color_ramp = _fade(Color(1, 1, 1, 1), Color(1, 1, 1, 0.0))
		"snow":
			p.amount = 220
			p.position.y = 9.0
			p.lifetime = 6.0
			p.mesh = _quad(0.05)
			p.material_override = Look.particle(Color(0.9, 0.95, 1.0, 0.9), false)
			p.gravity = Vector3(-0.9, -1.4, 0.3)
			p.color_ramp = _fade(Color(1, 1, 1, 1), Color(1, 1, 1, 0.3))
		_:
			p.amount = 50
			p.position.y = 1.5
			p.emission_box_extents = Vector3(10, 1.5, 10)
			p.mesh = _quad(0.035)
			p.material_override = Look.particle(Color(theme.fire).lerp(Color.WHITE, 0.3))
			p.gravity = Vector3(0.03, 0.04, 0)
			p.color_ramp = _fade(Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0))
	add_child(p)

func _process(delta: float) -> void:
	_clock += delta
	for f in fires:
		var l: OmniLight3D = f[0]
		var t: float = _clock * 9.0 + f[2]
		l.light_energy = f[1] * (0.85 + 0.1 * sin(t) + 0.08 * sin(t * 2.7 + 1.3))

## Phase changes can stain the whole arena (embers, frost, the white crown).
func tint(c: Color, amount: float, time: float = 1.5) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(env, "fog_light_color", Color(theme.fog).lerp(c, amount), time)
	tw.tween_property(env, "ambient_light_color", Color(theme.amb).lerp(c, amount * 0.6), time)
