class_name Highland
extends RefCounted
## The high road: a windswept headland of grass and heather above the sea, a worn path that climbs it in
## switchbacks, and at the top the outer gate of the old capital, the Ring-Gate, a broken stone ring taller than
## anything else in the kingdom, with the stepped spires of the citadel far behind it.
##
## Everything is made here: the ground is a height field built once and cached, the path is a curve stamped into
## a mask the ground shader reads, the grass is cards in MultiMeshes laid along the path. `Arena` builds it as the
## theme "highland" (see Arena._layout_highland), so the same place serves the prologue, a duel and the menu.
##
## Axes are the arena's: the gate court is the origin, the gate is at -Z, the road comes up from +Z.

const X0 := -260.0
const X1 := 260.0
const Z0 := -140.0
const Z1 := 580.0
const CELL := 5.0
const SEA := -76.0
const COURT_R := 13.0             # the paved court at the gate: flat, at height 0
const RING_C := Vector3(0, 36, -32)
const RING_R := 50.0              # to the middle of the stone
const RING_THICK := 11.0
const RING_DEEP := 9.0
const RING_BLOCKS := 40
const BREAK_FROM := 2.06          # radians from the foot of the ring, clockwise seen from the road: the missing arc
const BREAK_TO := 2.76
const MASK_X0 := -128.0
const MASK_Z0 := -16.0
const MASK_W := 256.0
const MASK_L := 512.0
const MASK_PX := 2.0              # texels a metre

## The road, from its foot to the court (x, z). The middle of it is the climb.
const ROAD := [[-20, 500], [-18, 470], [-8, 432], [8, 398], [6, 360], [-12, 322], [-20, 284], [-8, 250], [16, 228],
	[26, 214], [-20, 198], [-26, 188], [18, 172], [24, 162], [-16, 146], [-20, 137], [4, 124], [2, 108], [-4, 92],
	[-9, 74], [-8, 58], [-3, 40], [1, 24], [0, 12], [0, 5]]
## The ridge line: how high the ground stands at each z (z, height), highest z first.
const PROFILE := [[580, -62], [470, -54], [400, -50], [330, -46], [300, -47], [240, -41], [228, -38], [120, -10.5],
	[105, -7], [70, -8.5], [40, -5], [22, -1.2], [14, 0], [-22, 0], [-44, 4], [-140, 42]]

## The same place in each generation of the family (index = generation - 1).
## I: a summer dawn, the gate whole and kept. II: an autumn dusk, the arc fallen, the road half grown over.
## III: deep winter, still, and the seam in the ring alight: what is under the stone has woken.
const SEASONS := [
	{"sky": "#34578f", "horizon": "#f0c692", "fog": "#c4a888", "fog_d": 0.0008, "sun": "#ffd6a2", "sun_e": 3.6, "sun_rot": Vector3(-12, 166, 0),
		"amb": "#8693a8", "amb_e": 0.8, "exp": 0.95, "sat": 1.02,
		"grass_a": "#56692c", "grass_b": "#8f8a3c", "heather": "#6a4466", "heather_amt": 1.0, "dry": 0.1, "snow": 0.0,
		"cloud": 0.48, "cloud_lit": "#fff0d8", "cloud_dark": "#8a8494", "wind": 1.0, "seam": 0.25, "weather": "", "wear": 1.0, "whole": true},
	{"sky": "#272c3a", "horizon": "#9a6a4c", "fog": "#6a5a56", "fog_d": 0.0026, "sun": "#ff9a5a", "sun_e": 2.1, "sun_rot": Vector3(-6, 192, 0),
		"amb": "#5e6474", "amb_e": 1.0, "exp": 1.12, "sat": 0.9,
		"grass_a": "#6a5628", "grass_b": "#9a7436", "heather": "#5a3a34", "heather_amt": 0.5, "dry": 1.0, "snow": 0.0,
		"cloud": 0.36, "cloud_lit": "#c08a66", "cloud_dark": "#3a3640", "wind": 2.0, "seam": 0.0, "weather": "", "wear": 0.45, "whole": false},
	{"sky": "#5f7088", "horizon": "#cfd6dc", "fog": "#bcc6ce", "fog_d": 0.0034, "sun": "#eaf0fa", "sun_e": 2.0, "sun_rot": Vector3(-14, 160, 0),
		"amb": "#8d99ab", "amb_e": 1.15, "exp": 1.1, "sat": 0.8,
		"grass_a": "#6e7260", "grass_b": "#8e8c74", "heather": "#6a5a60", "heather_amt": 0.4, "dry": 0.7, "snow": 0.85,
		"cloud": 0.42, "cloud_lit": "#f4f6fa", "cloud_dark": "#8e98a6", "wind": 0.6, "seam": 4.5, "weather": "snow", "wear": 0.6, "whole": false},
]

static var _h := PackedFloat32Array()       # the height field, row by row along z
static var _nx := 0
static var _nz := 0
static var _mesh: ArrayMesh
static var _mask: ImageTexture
static var _road := PackedVector2Array()    # the road sampled every half metre
static var _big: FastNoiseLite
static var _small: FastNoiseLite
static var _mask_px := PackedByteArray()    # the road mask's own bytes, for asking "is this on the road?" cheaply
static var _grass_mm := {}                  # density -> the grass batches (MultiMesh resources are shared between builds)

# ================================================================ the ground
static func _noises() -> void:
	if _big != null:
		return
	_big = FastNoiseLite.new()
	_big.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_big.frequency = 1.0 / 150.0
	_big.fractal_octaves = 3
	_big.seed = 41
	_small = FastNoiseLite.new()
	_small.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_small.frequency = 1.0 / 26.0
	_small.fractal_octaves = 2
	_small.seed = 7

static func _profile(z: float) -> float:
	if z >= float(PROFILE[0][0]):
		return float(PROFILE[0][1])
	for i in range(1, PROFILE.size()):
		var a: Array = PROFILE[i - 1]
		var b: Array = PROFILE[i]
		if z >= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), smoothstep(float(a[0]), float(b[0]), z))
	return float(PROFILE[-1][1])

## The shape of the land before it is sampled into the grid.
static func _raw(x: float, z: float) -> float:
	_noises()
	var ridge := _profile(z)
	var mid := clampf(absf(x) / 60.0, 0.0, 1.0)            # the crown of the ridge is kept calm for the road
	var h := ridge + _big.get_noise_2d(x, z) * lerpf(2.0, 9.0, mid) + _small.get_noise_2d(x, z) * lerpf(0.35, 1.3, mid)
	# the west falls away as moor
	var west := maxf(0.0, -x - 48.0)
	h -= west * 0.13 + west * west * 0.0007
	# the east ends: a cliff, and the sea
	var edge := 64.0 + _big.get_noise_2d(z * 1.7, 300.0) * 16.0
	var fall := smoothstep(edge, edge + 26.0, x)
	h = lerpf(h, SEA - 6.0, fall * fall * (3.0 - 2.0 * fall))
	# the court at the gate is level, and the ground eases into it
	var r := Vector2(x, z + 4.0).length()
	h = lerpf(0.0, h, smoothstep(COURT_R + 3.0, COURT_R + 16.0, r))
	# behind the gate the mountain goes on up
	if z < -34.0:
		h += (-34.0 - z) * 0.05 * (1.0 + _big.get_noise_2d(x * 2.0, z * 2.0))
	# the edges of the world go under the sea, so nothing ends in mid-air
	var rim := maxf(smoothstep(X0 + 70.0, X0 + 8.0, x), smoothstep(Z1 - 40.0, Z1 - 6.0, z))
	return lerpf(h, SEA - 6.0, rim)

static func _ensure() -> void:
	if not _h.is_empty():
		return
	_nx = int((X1 - X0) / CELL) + 1
	_nz = int((Z1 - Z0) / CELL) + 1
	_h.resize(_nx * _nz)
	for j in _nz:
		for i in _nx:
			_h[j * _nx + i] = _raw(X0 + i * CELL, Z0 + j * CELL)
	# the road
	var pts: Array = []
	for p: Array in ROAD:
		pts.append(Vector2(float(p[0]), float(p[1])))
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		var n := maxi(2, int(p1.distance_to(p2) * 2.0))
		for k in n:
			_road.append(p1.cubic_interpolate(p2, p0, p3, float(k) / float(n)))
	_road.append(pts[-1])

## Height of the ground at a point: exactly the surface the mesh draws.
static func height(x: float, z: float) -> float:
	_ensure()
	var fx := clampf((x - X0) / CELL, 0.0, float(_nx) - 1.001)
	var fz := clampf((z - Z0) / CELL, 0.0, float(_nz) - 1.001)
	var i := int(fx)
	var j := int(fz)
	fx -= float(i)
	fz -= float(j)
	var h00 := _h[j * _nx + i]
	var h10 := _h[j * _nx + i + 1]
	var h01 := _h[(j + 1) * _nx + i]
	var h11 := _h[(j + 1) * _nx + i + 1]
	if fx + fz <= 1.0:
		return h00 + (h10 - h00) * fx + (h01 - h00) * fz
	return h11 + (h01 - h11) * (1.0 - fx) + (h10 - h11) * (1.0 - fz)

static func on_ground(x: float, z: float, lift: float = 0.0) -> Vector3:
	return Vector3(x, height(x, z) + lift, z)

# ================================================================ the road
static func road_length() -> float:
	_ensure()
	return float(_road.size() - 1) * 0.5

## A point on the road `s` metres from its foot, on the ground. (Samples are half a metre apart, near enough.)
static func road(s: float, side: float = 0.0) -> Vector3:
	_ensure()
	var f := clampf(s * 2.0, 0.0, float(_road.size()) - 1.001)
	var i := int(f)
	var p := _road[i].lerp(_road[i + 1], f - float(i))
	if side != 0.0:
		var d := (_road[mini(i + 3, _road.size() - 1)] - _road[maxi(i - 3, 0)]).normalized()
		p += Vector2(-d.y, d.x) * -side          # positive: to the walker's right
	return on_ground(p.x, p.y)

## The way the road runs at `s`, as a yaw for a rig (rigs face -Z).
static func road_yaw(s: float) -> float:
	_ensure()
	var i := clampi(int(s * 2.0), 0, _road.size() - 1)
	var d := _road[mini(i + 4, _road.size() - 1)] - _road[maxi(i - 4, 0)]
	return atan2(-d.x, -d.y)

## How far along the road it first comes down to this z.
static func road_at_z(z: float) -> float:
	_ensure()
	for i in _road.size():
		if _road[i].y <= z:
			return float(i) * 0.5
	return road_length()

## How much of the road is underfoot at a point: 0 turf, 1 the middle of the road (read from the mask).
static func on_road(x: float, z: float) -> float:
	_road_mask()
	var w := int(MASK_W * MASK_PX)
	var px := int((x - MASK_X0) * MASK_PX)
	var pz := int((z - MASK_Z0) * MASK_PX)
	if px < 0 or pz < 0 or px >= w or pz >= int(MASK_L * MASK_PX):
		return 0.0
	return float(_mask_px[pz * w + px]) / 255.0

# ================================================================ meshes
static func _terrain_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	_ensure()
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	v.resize(_nx * _nz)
	n.resize(_nx * _nz)
	for j in _nz:
		for i in _nx:
			var k := j * _nx + i
			v[k] = Vector3(X0 + i * CELL, _h[k], Z0 + j * CELL)
			var hl := _h[k - 1] if i > 0 else _h[k]
			var hr := _h[k + 1] if i < _nx - 1 else _h[k]
			var hd := _h[k - _nx] if j > 0 else _h[k]
			var hu := _h[k + _nx] if j < _nz - 1 else _h[k]
			n[k] = Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()
	for j in _nz - 1:
		for i in _nx - 1:
			var a := j * _nx + i
			idx.append_array(PackedInt32Array([a, a + 1, a + _nx, a + 1, a + _nx + 1, a + _nx]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_INDEX] = idx
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _mesh

## Where the road is, for the ground shader: worn bare along the middle, fraying at the edges.
static func _road_mask() -> ImageTexture:
	if _mask != null:
		return _mask
	_ensure()
	var w := int(MASK_W * MASK_PX)
	var l := int(MASK_L * MASK_PX)
	var px := PackedByteArray()
	px.resize(w * l)
	var reach := 5                # texels: 2.5 m
	for s in range(0, _road.size()):
		var c := _road[s]
		# the road is wider and more broken where it climbs, and opens out as it reaches the court
		var half := 1.25 + 1.6 * smoothstep(34.0, 8.0, c.y)
		var cx := (c.x - MASK_X0) * MASK_PX
		var cz := (c.y - MASK_Z0) * MASK_PX
		for dz in range(-reach - 4, reach + 5):
			for dx in range(-reach - 4, reach + 5):
				var x := int(cx) + dx
				var z := int(cz) + dz
				if x < 0 or z < 0 or x >= w or z >= l:
					continue
				var d := Vector2(float(x) + 0.5 - cx, float(z) + 0.5 - cz).length() / MASK_PX
				var val := int(255.0 * clampf(1.0 - (d - half * 0.55) / (half * 0.9), 0.0, 1.0))
				if val > px[z * w + x]:
					px[z * w + x] = val
	_mask_px = px
	var img := Image.create_from_data(w, l, false, Image.FORMAT_R8, px)
	_mask = ImageTexture.create_from_image(img)
	return _mask

static func _noise_tex() -> Texture2D:
	return Look._noise("highland", FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, false, null, 256)

# ================================================================ building it
## Fills an Arena that has made its sky, sun and floor. Called by Arena._layout_highland.
static func build(a: Arena) -> void:
	_ensure()
	var st := {}
	# the arena's square of paving becomes the round court at the gate, in the Courtyard's own stone
	for c in a.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is PlaneMesh:
			var disc := CylinderMesh.new()
			disc.top_radius = COURT_R + 1.5
			disc.bottom_radius = COURT_R + 1.5
			disc.height = 0.3
			disc.radial_segments = 40
			disc.rings = 1
			(c as MeshInstance3D).mesh = disc
			(c as MeshInstance3D).position = Vector3(0, -0.13, -4.0)
			if ResourceLoader.exists("res://assets/textures/floor_courtyard.jpg"):
				var fm := StandardMaterial3D.new()
				fm.albedo_texture = load("res://assets/textures/floor_courtyard.jpg")
				fm.albedo_color = Color(0.86, 0.84, 0.8)
				fm.uv1_triplanar = true
				fm.uv1_world_triplanar = true
				fm.uv1_scale = Vector3.ONE * 0.22
				fm.roughness = 0.9
				fm.metallic_specular = 0.25
				if ResourceLoader.exists("res://assets/textures/floor_courtyard_n.png"):
					fm.normal_enabled = true
					fm.normal_texture = load("res://assets/textures/floor_courtyard_n.png")
				(c as MeshInstance3D).material_override = fm
		elif c is MeshInstance3D and (c as MeshInstance3D).mesh is TorusMesh:
			(c as MeshInstance3D).visible = false      # no duelling ring painted on a road
	a.sun.directional_shadow_max_distance = 70.0
	a.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	a.env.fog_aerial_perspective = 0.35
	a.env.fog_sun_scatter = 0.12
	a.env.fog_sky_affect = 0.0
	a.env.fog_height = SEA + 8.0
	a.env.fog_height_density = 0.02
	# ---- ground
	var ground := ShaderMaterial.new()
	ground.shader = load("res://src/world/highland_ground.gdshader")
	ground.set_shader_parameter("path_mask", _road_mask())
	ground.set_shader_parameter("noise_tex", _noise_tex())
	ground.set_shader_parameter("mask_rect", Vector4(MASK_X0, MASK_Z0, 1.0 / MASK_W, 1.0 / MASK_L))
	var land := MeshInstance3D.new()
	land.name = "HLGround"
	land.mesh = _terrain_mesh()
	land.material_override = ground
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	land.extra_cull_margin = 4.0
	a.add_child(land)
	st["ground"] = ground
	# ---- sea
	var sea := PlaneMesh.new()
	sea.size = Vector2(6000, 6000)
	var seam := StandardMaterial3D.new()
	seam.albedo_color = Color("#27404c")
	seam.roughness = 0.32
	seam.metallic_specular = 0.7
	var sea_mi := MeshInstance3D.new()
	sea_mi.mesh = sea
	sea_mi.material_override = seam
	sea_mi.position = Vector3(0, SEA, 0)
	sea_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(sea_mi)
	# ---- cloud, moving
	var cloud := ShaderMaterial.new()
	cloud.shader = load("res://src/world/highland_cloud.gdshader")
	cloud.set_shader_parameter("noise_tex", _noise_tex())
	var deck := PlaneMesh.new()
	deck.size = Vector2(9000, 9000)
	deck.orientation = PlaneMesh.FACE_Y
	var deck_mi := MeshInstance3D.new()
	deck_mi.name = "HLCloud"
	deck_mi.mesh = deck
	deck_mi.material_override = cloud
	deck_mi.position = Vector3(0, 420.0, 0)
	deck_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(deck_mi)
	st["cloud"] = cloud
	st["grass"] = _grass(a)
	st["seam"] = _ring(a)
	_citadel(a)
	st["kept"] = []
	_gate_court(a, st)
	_wayside(a, st)
	a.set_meta("highland", st)
	generation(a, 1)

## Tufts along the road, thick beside it and thinning with distance, in a few batches so the far ones are not drawn.
static func _grass(a: Arena) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/world/highland_grass.gdshader")
	mat.set_shader_parameter("albedo_tex", _blades())
	var density := Game.particle_scale()            # 0.5 Performance, 0.8 Balanced, 1.0 High
	if _grass_mm.has(density):
		for mm0: MultiMesh in _grass_mm[density]:
			_grass_batch(a, mm0, mat)
		return mat
	_grass_mm[density] = []
	var blade := QuadMesh.new()
	blade.size = Vector2(0.95, 0.5)
	blade.center_offset = Vector3(0, 0.24, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	_noises()
	var total := road_length()
	var span := 44.0
	var s0 := 0.0
	while s0 < total:
		var xf: Array = []
		var cols: Array = []
		var lo := Vector3.ONE * 1e9
		var hi := Vector3.ONE * -1e9
		var near := int(span * 62.0 * density)
		var want := near + int(260.0 * density)
		for i in want:
			var s := s0 + rng.randf() * span
			# most of it close to the road, where the camera is; the rest is big tussocks out across the moor
			var wide := i >= near
			var off := ((1.4 + pow(rng.randf(), 1.7) * 30.0) if not wide else rng.randf_range(24.0, 120.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
			var p := road(s, off)
			if p.x > 58.0 or on_road(p.x, p.z) > 0.02 or Vector2(p.x, p.z + 4.0).length() < COURT_R + 1.0 or p.y < SEA + 8.0:
				continue
			var slope := absf(height(p.x + 1.0, p.z) - p.y) + absf(height(p.x, p.z + 1.0) - p.y)
			if slope > 1.1:
				continue                    # rock, not turf
			var yaw := rng.randf() * PI
			var sc := rng.randf_range(0.7, 1.5) * (2.4 if wide else 1.0)
			var heath := _big.get_noise_2d(p.x * 3.1 + 500.0, p.z * 3.1) > 0.22 and rng.randf() < 0.75
			var c := Color(0.62, 0.3, 0.6, 1.0) if heath else Color(rng.randf_range(0.0, 1.0), 1.0, 0.0, 0.0)
			for k in 2:
				xf.append(Transform3D(Basis(Vector3.UP, yaw + k * PI * 0.5).scaled(Vector3(sc, sc * (0.7 if heath else 1.0), sc)), p))
				cols.append(c)
			lo = lo.min(p)
			hi = hi.max(p)
		if not xf.is_empty():
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = blade
			mm.instance_count = xf.size()
			for i in xf.size():
				mm.set_instance_transform(i, xf[i])
				mm.set_instance_color(i, cols[i])
			mm.custom_aabb = AABB(lo - Vector3(2, 1, 2), hi - lo + Vector3(4, 3, 4))
			_grass_mm[density].append(mm)
			_grass_batch(a, mm, mat)
		s0 += span
	return mat

static func _grass_batch(a: Arena, mm: MultiMesh, mat: ShaderMaterial) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 310.0
	a.add_child(mi)

## Blades of grass for the cards: thin, many, pale at the tip. Tinted by the shader.
static func _blades() -> Texture2D:
	if Look._cache.has("highland_blades"):
		return Look._cache["highland_blades"]
	var img := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.6, 0.6, 0))
	var r := RandomNumberGenerator.new()
	r.seed = 23
	for b in 26:
		var base_x := r.randf_range(12.0, 244.0)
		var lean := r.randf_range(-32.0, 32.0)
		var h := r.randf_range(52.0, 126.0)
		var w := r.randf_range(3.2, 6.0)
		var shade := r.randf_range(0.7, 1.0)
		for y in int(h):
			var u := float(y) / h
			var cx := base_x + lean * u * u
			var half := w * (1.0 - u * 0.85) + 0.35
			for x in range(int(cx - half), int(cx + half) + 1):
				if x >= 0 and x < 256:
					var v := (0.45 + 0.55 * u) * shade
					img.set_pixel(x, 127 - y, Color(v, v, v, 1.0))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	Look._cache["highland_blades"] = t
	return t

## The Ring-Gate: forty stones in a ring, an arc of them gone, and a seam of something that is not stone
## set into the inner face.
static func _ring(a: Arena) -> StandardMaterial3D:
	var stone := Look.stone(Color("#8d877b"), 0.07, 0.9, "ringgate")
	var block := BoxMesh.new()
	block.size = Vector3(TAU * (RING_R + RING_THICK * 0.5) / RING_BLOCKS * 0.97, RING_THICK, RING_DEEP)
	var rng := RandomNumberGenerator.new()
	rng.seed = 97
	var xf: Array = []
	var lamps: Array = []
	var arc: Array = []           # the stones that stand in the first generation and are down by the second
	var arc_lamps: Array = []
	var fallen: Array = []
	for i in RING_BLOCKS:
		var ang := TAU * (float(i) + 0.5) / RING_BLOCKS
		var gone := ang > BREAK_FROM and ang < BREAK_TO
		var r := RING_R + rng.randf_range(-0.5, 0.5)
		var basis := Basis(Vector3(0, 0, 1), ang)
		var at := RING_C + Vector3(sin(ang) * r, -cos(ang) * r, rng.randf_range(-0.35, 0.35))
		var sc := Vector3(1.0, rng.randf_range(0.94, 1.05), rng.randf_range(0.92, 1.06))
		(arc if gone else xf).append(Transform3D(basis.scaled(sc), at))
		if rng.randf() < 0.8:
			(arc_lamps if gone else lamps).append(Transform3D(basis, RING_C + Vector3(sin(ang), -cos(ang), 0) * (RING_R - RING_THICK * 0.5 - 0.05) + Vector3(0, 0, RING_DEEP * 0.5 - 0.6)))
		if false:
			lamps.append(Transform3D(basis, RING_C + Vector3(sin(ang), -cos(ang), 0) * (RING_R - RING_THICK * 0.5 - 0.05) + Vector3(0, 0, RING_DEEP * 0.5 - 0.6)))
	# what came down lies east of the court, where the ground breaks toward the cliff
	for f: Array in [[38.0, -14.0, 0.5, 0.3], [47.0, -2.0, 1.1, -0.4], [33.0, 4.0, 2.0, 0.7], [52.0, -22.0, 0.2, 1.3]]:
		var p := on_ground(float(f[0]), float(f[1]), 2.2)
		fallen.append(Transform3D(Basis.from_euler(Vector3(float(f[3]) * 0.5, float(f[2]), float(f[3]))).scaled(Vector3.ONE * 0.9), p))
	var seam := Look.glow(Color("#5fe0c8"), 0.5)
	seam.albedo_color = Color(0.08, 0.1, 0.1)
	var strip := BoxMesh.new()
	strip.size = Vector3(block.size.x * 0.62, 0.5, 0.5)
	_batch(a, "HLRing", block, xf, stone, true)
	_batch(a, "HLRingArc", block, arc, stone, true)
	_batch(a, "HLRingFallen", block, fallen, stone, true)
	_batch(a, "HLSeam", strip, lamps, seam, false)
	_batch(a, "HLSeamArc", strip, arc_lamps, seam, false)
	return seam

static func _batch(a: Arena, node_name: String, mesh: Mesh, xf: Array, mat: Material, shadows: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(mi)

## The citadel, far behind the gate and seen through it: two stepped spires and the span between them.
static func _citadel(a: Arena) -> void:
	var m := Look.flat(Color("#6f6a66"), 1.0)
	var root := Node3D.new()
	root.name = "HLCitadel"
	root.position = Vector3(6.0, 34.0, -330.0)
	a.add_child(root)
	for sx: float in [-1.0, 1.0]:
		var y := 0.0
		for k in 5:
			var w := 34.0 - k * 6.0
			var h := 26.0 - k * 3.0
			_far_box(root, Vector3(w, h, w), Vector3(sx * 25.0, y + h * 0.5, sx * -6.0), m)
			y += h
		_far_box(root, Vector3(3.0, 16.0, 3.0), Vector3(sx * 25.0, y + 8.0, sx * -6.0), m)
	_far_box(root, Vector3(40.0, 5.0, 8.0), Vector3(0, 62.0, 0), m)
	_far_box(root, Vector3(150.0, 30.0, 60.0), Vector3(0, -6.0, 6.0), m)
	_far_box(root, Vector3(260.0, 22.0, 40.0), Vector3(0, -22.0, 30.0), m)
	# and the mountains it was cut from, a long way off
	for p: Array in [[-560.0, -640.0, 300.0, 40.0], [-800.0, -160.0, 270.0, 280.0]]:
		var pk := a.prop("peak", float(p[2]), Vector3(float(p[0]), -40.0, float(p[1])), float(p[3]))
		if pk:
			for mi in pk.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _far_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

## The court between the ring's feet: the gatehouse that is shut, the curtain wall, fires that are still fed.
static func _gate_court(a: Arena, st: Dictionary) -> void:
	a.prop("gate", 13.0, Vector3(0, 0, -21.0), 0.0)
	for sx: float in [-1.0, 1.0]:
		a.prop("wall", 8.5, Vector3(sx * 15.5, 0, -22.0), 0.0 if sx < 0 else 180.0)
		a.prop("wall", 7.5, on_ground(sx * 30.0, -23.0, -0.6), 8.0 * sx + (0.0 if sx < 0 else 180.0))
		a.prop("brazier", 1.9, Vector3(sx * 4.2, 0, -9.5), 0.0)
		a.fire(Vector3(sx * 4.2, 1.75, -9.5), 2.0, 9.0, false)
		st.kept.append(a.prop("banner", 6.5, Vector3(sx * 8.6, 0, -12.5), sx * -18.0))
		a.prop("pillar", 4.4, Vector3(sx * 11.0, 0, 2.0), sx * 40.0)
	a.prop("statue", 9.0, on_ground(-17.5, -3.0, -0.3), 28.0)
	a.prop("rubble", 2.4, on_ground(12.5, 4.5, -0.2), 70.0)
	a.prop("rubble", 1.8, on_ground(-11.0, 8.5, -0.2), 200.0)

## What stands beside the road: waystones in pairs, a ruined arch where the climb ends, the dead tree, a king's
## fallen head, old banners, and the rock the turf never covered.
static func _wayside(a: Arena, st: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1909
	# waystones: one each side, every sixty metres or so, some of them broken off short
	var s := 26.0
	var k := 0
	while s < road_length() - 30.0:
		for side: float in [-1.0, 1.0]:
			if rng.randf() < 0.25:
				continue
			var p := road(s + rng.randf_range(-1.0, 1.0), side * rng.randf_range(2.5, 3.1))
			_shadowed(a.prop("pillar", rng.randf_range(1.6, 3.3) if rng.randf() < 0.7 else 1.0, p - Vector3(0, 0.15, 0), rng.randf() * 360.0))
		s += 58.0 if k % 2 == 0 else 46.0
		k += 1
	# the arch at the head of the climb
	var sa := road_at_z(126.0)
	var along := road_yaw(sa)
	for side: float in [-1.0, 1.0]:
		_shadowed(a.prop("pillar", 6.6 if side < 0.0 else 4.9, road(sa, side * 3.3) - Vector3(0, 0.3, 0), rad_to_deg(along)))
	var lintel := a.box(Vector3(5.6, 0.9, 1.2), road(sa, -1.6) + Vector3(0, 6.5, 0), Look.stone(Color("#8d877b"), 0.2), Vector3(0, rad_to_deg(along), -7.0))
	lintel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# the dead tree in the saddle below the gate
	var s_tree := tree_s()
	_shadowed(a.prop("tree", 10.5, road(s_tree, -5.5) - Vector3(0, 0.3, 0), 75.0))
	# a king's head, off its statue, where the road tops the rise
	var sh := road_at_z(103.0)
	_shadowed(a.prop("statue_head", 4.6, road(sh, 9.0) - Vector3(0, 1.1, 0), -150.0))
	# banners, long past their colours, on the last stretch
	for b: Array in [[44.0, 3.4, 20.0], [31.0, -3.6, -30.0], [58.0, 3.8, 0.0]]:
		var flag := a.prop("banner", 5.6, road(road_at_z(float(b[0])), float(b[1])) - Vector3(0, 0.2, 0), rad_to_deg(road_yaw(road_at_z(float(b[0])))) + float(b[2]))
		_shadowed(flag)
		st.kept.append(flag)
	# rock the turf never covered: one batch of rough lumps
	var lump := SphereMesh.new()
	lump.radius = 1.0
	lump.height = 2.0
	lump.radial_segments = 9
	lump.rings = 5
	var xf: Array = []
	for i in 46:
		var sr := rng.randf() * road_length()
		var off := rng.randf_range(4.5, 60.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var p := road(sr, off)
		if p.y < SEA + 8.0 or Vector2(p.x, p.z + 4.0).length() < COURT_R + 4.0 or on_road(p.x, p.z) > 0.0:
			continue
		var size := rng.randf_range(0.6, 2.6)
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5)))
		xf.append(Transform3D(b.scaled(Vector3(size * rng.randf_range(0.9, 1.7), size * rng.randf_range(0.5, 0.9), size)), p - Vector3(0, size * 0.2, 0)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lump
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var rocks := MultiMeshInstance3D.new()
	rocks.multimesh = mm
	rocks.material_override = Look.stone(Color("#7b766c"), 0.3, 0.95, "crag")
	a.add_child(rocks)

## Where on the road the dead tree stands.
static func tree_s() -> float:
	return road_at_z(62.0)

## Scenery away from the court is told not to cast shadows (PropModel.scenery); these few are the road's
## landmarks, and their long shadows are part of the picture.
static func _shadowed(n: Node3D) -> void:
	if n == null:
		return
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

# ================================================================ seasons
## Sets which generation's road this is (1, 2 or 3): the light and the air, the colour of the turf, the weather,
## whether the ring is whole, how worn the road still is, whether the fires and banners are kept, and how awake
## the gate is. The composition never changes; what is in it does.
static func generation(a: Arena, g: int) -> void:
	var st: Dictionary = a.get_meta("highland", {})
	if st.is_empty():
		return
	var s: Dictionary = SEASONS[clampi(g, 1, SEASONS.size()) - 1]
	a.set_meta("generation", clampi(g, 1, SEASONS.size()))
	var whole: bool = s.whole
	for nm: String in ["HLRingArc", "HLSeamArc"]:
		(a.get_node(nm) as Node3D).visible = whole
	(a.get_node("HLRingFallen") as Node3D).visible = not whole
	# kept in the first generation; after it nobody feeds the fires, and the banners are down
	for f: Array in a.fires:
		f[1] = 2.0 if whole else 0.0
		(f[0] as Light3D).visible = whole
	for p in a.find_children("*", "CPUParticles3D", true, false):
		if (p as CPUParticles3D).lifetime < 1.0:
			(p as CPUParticles3D).emitting = whole
	for n in st.get("kept", []):
		if n != null:
			(n as Node3D).visible = whole
	var env := a.env
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = Color(str(s.sky))
	sky.sky_horizon_color = Color(str(s.horizon))
	sky.ground_horizon_color = Color(str(s.horizon))
	sky.ground_bottom_color = Color(str(s.fog))
	sky.sky_curve = 0.12
	sky.sky_cover_modulate = Color(str(s.cloud_lit))
	sky.sun_angle_max = 10.0
	sky.sun_curve = 0.12
	env.fog_light_color = Color(str(s.fog))
	env.fog_density = float(s.fog_d)
	env.ambient_light_color = Color(str(s.amb))
	env.ambient_light_energy = float(s.amb_e)
	env.tonemap_exposure = float(s.exp) * 1.25
	env.adjustment_saturation = float(s.sat)
	a.sun.light_color = Color(str(s.sun))
	a.sun.light_energy = float(s.sun_e)
	a.sun.rotation_degrees = s.sun_rot
	var wind := Vector2(0.86, 0.5) * float(s.wind)
	var ground: ShaderMaterial = st.ground
	var grass: ShaderMaterial = st.grass
	for m: ShaderMaterial in [ground, grass]:
		m.set_shader_parameter("grass_a", Color(str(s.grass_a)))
		m.set_shader_parameter("grass_b", Color(str(s.grass_b)))
		m.set_shader_parameter("heather", Color(str(s.heather)))
		m.set_shader_parameter("heather_amt", float(s.heather_amt))
		m.set_shader_parameter("snow", float(s.snow))
		m.set_shader_parameter("wind", wind)
	grass.set_shader_parameter("dry", float(s.dry))
	ground.set_shader_parameter("wear", float(s.wear))
	var cloud: ShaderMaterial = st.cloud
	cloud.set_shader_parameter("cover", float(s.cloud))
	cloud.set_shader_parameter("lit", Color(str(s.cloud_lit)))
	cloud.set_shader_parameter("dark", Color(str(s.cloud_dark)))
	cloud.set_shader_parameter("haze", Color(str(s.horizon)))
	cloud.set_shader_parameter("wind", wind)
	(st.seam as StandardMaterial3D).emission_energy_multiplier = float(s.seam)
	var old := a.get_node_or_null("HLWeather")
	if old:
		old.free()
	if str(s.weather) != "":
		_weather(a, str(s.weather))

## Rain or snow in a box that the scene keeps over its camera (see `follow`).
static func _weather(a: Arena, kind: String) -> void:
	var p := CPUParticles3D.new()
	p.name = "HLWeather"
	var rain := kind == "rain"
	p.amount = int((220 if rain else 140) * Game.particle_scale())
	p.lifetime = 1.1 if rain else 5.0
	p.preprocess = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 0.5, 14)
	p.direction = Vector3(0.5, -1.0, 0.3) if rain else Vector3(0.15, -1.0, 0.05)
	p.spread = 4.0 if rain else 25.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 13.0 if rain else 1.1
	p.initial_velocity_max = 16.0 if rain else 1.8
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.55) if rain else Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if rain else BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.8, 0.84, 0.9, 0.3) if rain else Color(1, 1, 1, 0.85)
	q.material = mat
	p.mesh = q
	p.local_coords = false
	p.position = Vector3(0, 9.0, 0)
	a.add_child(p)

## Keeps the weather over whoever is looking.
static func follow(a: Arena, at: Vector3) -> void:
	var w := a.get_node_or_null("HLWeather") as Node3D
	if w:
		w.global_position = at + Vector3(0, 7.0, -4.0)

## Cold start: the grid, the road and the mask, so the first scene to use them does not pay for them in a cut.
static func warm() -> void:
	_terrain_mesh()
	_road_mask()
