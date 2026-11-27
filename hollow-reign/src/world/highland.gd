class_name Highland
extends RefCounted
## The high road: a windswept headland of grass and heather above the sea, a worn path that climbs it in
## switchbacks, and at the top the outer gate of the old capital, the Ring-Gate, a broken stone ring taller than
## anything else in the kingdom, with the stepped spires of the citadel far behind it.
##
## Everything is made here. The ground is a height field built once and cached: a calm crown for the road, two rock
## steps across the climb, tors on the moor, and on the east a banded sea cliff with a shelf and a surf line at its
## foot. Its shader blends turf, scree and rock by slope and lays the road from a mask. Grass and heath are clumps of
## cards in MultiMeshes along the road; crags are faceted rock in another. The light is a low sun with the land's own
## shadow baked for each generation, the Ring-Gate's shadow worked out in the shader, and cloud shadow drifting over
## all of it. Behind everything stand ranges of far hills, each thinner in the air than the one before.
## `Arena` builds it as the theme "highland" (see Arena._layout_highland), so the same place serves the prologue, a
## duel and the menu.
##
## Axes are the arena's: the gate court is the origin, the gate is at -Z, the road comes up from +Z, the sea is +X.

const X0 := -260.0
const X1 := 260.0
const Z0 := -140.0
const Z1 := 580.0
const CELL := 4.0
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
const GATE_AT := Vector3(0, 0, -21.0)
const GATE_YAW := 90.0             # the gatehouse model's doors are on its X side

## The road, from its foot to the court (x, z). The middle of it is the climb.
const ROAD := [[-20, 500], [-18, 470], [-8, 432], [8, 398], [6, 360], [-12, 322], [-20, 284], [-8, 250], [16, 228],
	[26, 214], [-20, 198], [-26, 188], [18, 172], [24, 162], [-16, 146], [-20, 137], [4, 124], [2, 108], [-4, 92],
	[-9, 74], [-8, 58], [-3, 40], [1, 24], [0, 12], [0, 5]]
## The ridge line: how high the ground stands at each z (z, height), highest z first.
const PROFILE := [[580, -62], [470, -54], [400, -50], [330, -46], [300, -47], [240, -41], [228, -38], [120, -10.5],
	[105, -7], [70, -8.5], [40, -5], [22, -1.2], [14, 0], [-22, 0], [-40, 2], [-64, 31], [-140, 48]]

## The same place in each generation of the family (index = generation - 1).
## I: a summer dawn, the sun low over the sea, the gate whole and kept. II: an autumn dusk, the sun going down behind
## the moor, the arc fallen, the road half grown over. III: deep winter, a pale sun behind the ring, and the seam in
## it alight: what is under the stone has woken.
const SEASONS := [
	{"sky": "#2a5798", "horizon": "#f2c58a", "fog": "#cfb596", "fog_d": 0.00028, "sun": "#ffd49a", "sun_e": 3.5, "sun_rot": Vector3(-15, 80, 0),
		"amb": "#6c84aa", "amb_e": 0.72, "fill": 0.2, "exp": 0.92, "sat": 1.1, "con": 1.12,
		"grass_a": "#2c5a20", "grass_b": "#5c7c2a", "heather": "#75507e", "heather_amt": 1.0, "straw": "#b8a24c", "dry": 0.1, "snow": 0.0,
		"rock_a": "#2a2826", "rock_b": "#857c6e", "earth": "#4a3a26", "wet": 0.5,
		"cloud": 0.5, "cloud_lit": "#fff0d6", "cloud_dark": "#646a84", "cloud_shadow": 0.5,
		"far_lit": "#8c8a7a", "far_shade": "#3c4e6c", "haze": "#c8bca8", "rim": "#ffdf9c",
		"deep": "#0d2a3a", "shelf": "#2a6c6c", "shafts": 0.2,
		"wind": 1.0, "seam": 0.25, "weather": "", "wear": 1.0, "whole": true},
	{"sky": "#18224a", "horizon": "#d8763c", "fog": "#4c4a60", "fog_d": 0.00045, "sun": "#ff8e4a", "sun_e": 2.6, "sun_rot": Vector3(-7, 208, 0),
		"amb": "#3c4e80", "amb_e": 1.1, "fill": 0.5, "exp": 0.95, "sat": 1.0, "con": 1.14,
		"grass_a": "#3c4a26", "grass_b": "#7a5e2c", "heather": "#4c2d2a", "heather_amt": 0.6, "straw": "#a07a40", "dry": 0.8, "snow": 0.0,
		"rock_a": "#201d1e", "rock_b": "#766252", "earth": "#3a2a1c", "wet": 0.7,
		"cloud": 0.49, "cloud_lit": "#d89468", "cloud_dark": "#262b44", "cloud_shadow": 0.55,
		"far_lit": "#8a5a48", "far_shade": "#1c2238", "haze": "#6a5062", "rim": "#ffb070",
		"deep": "#0b1620", "shelf": "#1e3842", "shafts": 0.3,
		"wind": 2.0, "seam": 0.0, "weather": "", "wear": 0.45, "whole": false},
	{"sky": "#22344e", "horizon": "#aebccc", "fog": "#8c9aac", "fog_d": 0.0005, "sun": "#e6eefc", "sun_e": 3.0, "sun_rot": Vector3(-13, 138, 0),
		"amb": "#5a6c8a", "amb_e": 0.8, "fill": 0.35, "exp": 0.82, "sat": 0.85, "con": 1.18,
		"grass_a": "#4e5646", "grass_b": "#77775e", "heather": "#5c4c52", "heather_amt": 0.4, "straw": "#9a9478", "dry": 0.7, "snow": 0.6,
		"rock_a": "#1e2126", "rock_b": "#63676f", "earth": "#34322e", "wet": 0.3,
		"cloud": 0.4, "cloud_lit": "#e8eef6", "cloud_dark": "#3c4658", "cloud_shadow": 0.4,
		"far_lit": "#aab8c8", "far_shade": "#2e3c52", "haze": "#93a2b4", "rim": "#ffffff",
		"deep": "#0b1c28", "shelf": "#224852", "shafts": 0.1,
		"wind": 0.6, "seam": 6.0, "weather": "snow", "wear": 0.6, "whole": false},
]

static var _h := PackedFloat32Array()       # the height field, row by row along z
static var _nx := 0
static var _nz := 0
static var _mesh: ArrayMesh
static var _mask: ImageTexture
static var _road := PackedVector2Array()    # the road sampled every half metre
static var _big: FastNoiseLite
static var _small: FastNoiseLite
static var _tor: FastNoiseLite
static var _mask_px := PackedByteArray()    # the road mask's own bytes, for asking "is this on the road?" cheaply
static var _grass_mm := {}                  # density -> [[MultiMesh, kind]] (MultiMesh resources are shared between builds)
static var _noise: ImageTexture
static var _noise_px := PackedByteArray()
static var _sun := {}                       # generation -> the land's baked shadow for that generation's sun
static var _height_tex: ImageTexture
static var _crags: Array = []               # the crag meshes
static var _crag_mm: MultiMesh
static var _far: ArrayMesh

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
	_tor = FastNoiseLite.new()
	_tor.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_tor.frequency = 1.0 / 64.0
	_tor.fractal_octaves = 1
	_tor.seed = 19

static func _profile(z: float) -> float:
	if z >= float(PROFILE[0][0]):
		return float(PROFILE[0][1])
	for i in range(1, PROFILE.size()):
		var a: Array = PROFILE[i - 1]
		var b: Array = PROFILE[i]
		if z >= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), smoothstep(float(a[0]), float(b[0]), z))
	return float(PROFILE[-1][1])

## Where the middle of the road is at this z (the road never doubles back in z).
static func _road_x(z: float) -> float:
	if z >= float(ROAD[0][1]):
		return float(ROAD[0][0])
	for i in range(1, ROAD.size()):
		if z >= float(ROAD[i][1]):
			return lerpf(float(ROAD[i - 1][0]), float(ROAD[i][0]), inverse_lerp(float(ROAD[i - 1][1]), float(ROAD[i][1]), z))
	return float(ROAD[-1][0])

## Where the land ends and the cliff begins, at this z.
static func cliff_x(z: float) -> float:
	_noises()
	return maxf(57.0 + _big.get_noise_2d(z * 1.7, 300.0) * 14.0 + _small.get_noise_2d(z * 2.0, 77.0) * 4.0, _road_x(z) + 26.0)

## The shape of the land before it is sampled into the grid.
static func _raw(x: float, z: float) -> float:
	_noises()
	var ridge := _profile(z)
	# the road's own ground is kept calm; away from it the land does what it likes
	var calm := 1.0 - smoothstep(9.0, 32.0, absf(x - _road_x(z)))
	if z > 126.0 and z < 236.0:
		calm = maxf(calm, 1.0 - smoothstep(30.0, 46.0, absf(x)))
	var mid := 1.0 - calm
	# the climb: beside the road it is two steps of rock rather than one long slope
	var t := clampf((ridge + 38.0) / 27.5, 0.0, 1.0)
	if t > 0.0 and t < 1.0 and z < 228.0 and z > 120.0:
		var tw := clampf(t + _small.get_noise_2d(x * 0.6, 900.0) * 0.1 * mid, 0.0, 1.0)
		var ts := (floorf(tw * 2.0) + smoothstep(0.36, 0.6, fposmod(tw * 2.0, 1.0))) * 0.5
		ridge = lerpf(ridge, -38.0 + 27.5 * minf(ts, 1.0), mid)
	var h := ridge + _big.get_noise_2d(x, z) * lerpf(1.6, 6.5, mid) + _small.get_noise_2d(x, z) * lerpf(0.3, 1.3, mid)
	# east of the road the ground tips toward the cliff, so the sea is seen from the road
	h -= minf(maxf(0.0, x - _road_x(z) - 12.0) * 0.17, 7.5) * smoothstep(-10.0, 60.0, z)
	# the west falls away as moor
	var west := maxf(0.0, -x - 48.0)
	h -= west * 0.13 + west * west * 0.0007
	# the east ends: a cliff in ledges, a shelf of rock at its foot, and the sea
	var edge := cliff_x(z)
	var fall := smoothstep(edge, edge + 10.0, x)
	if fall > 0.0:
		var foot := lerpf(SEA + 1.5, SEA - 7.0, smoothstep(edge + 12.0, edge + 50.0, x))
		foot += maxf(0.0, _small.get_noise_2d(x * 1.5, z * 1.5)) * 3.0 * (1.0 - smoothstep(edge + 14.0, edge + 40.0, x))
		var hc := lerpf(h, foot, fall * fall * (3.0 - 2.0 * fall))
		var ledge := (floorf(hc / 9.0) + smoothstep(0.25, 0.75, fposmod(hc / 9.0, 1.0))) * 9.0
		h = lerpf(hc, ledge, 0.55 * sin(fall * PI))
	# the court at the gate is level, and the ground eases into it
	var r := Vector2(x, z + 4.0).length()
	h = lerpf(0.0, h, smoothstep(COURT_R + 3.0, COURT_R + 16.0, r))
	# behind the gate the mountain goes on up
	if z < -34.0:
		h += (-34.0 - z) * 0.05 * (1.0 + _big.get_noise_2d(x * 2.0, z * 2.0))
	# the edges of the world go under the sea, so nothing ends in mid-air
	var rim := maxf(smoothstep(X0 + 70.0, X0 + 8.0, x), smoothstep(Z1 - 40.0, Z1 - 6.0, z))
	return lerpf(h, SEA - 7.0, rim)

static func _ensure() -> void:
	if not _h.is_empty():
		return
	_nx = int((X1 - X0) / CELL) + 1
	_nz = int((Z1 - Z0) / CELL) + 1
	var h := PackedFloat32Array()
	h.resize(_nx * _nz)
	for j in _nz:
		for i in _nx:
			h[j * _nx + i] = _raw(X0 + i * CELL, Z0 + j * CELL)
	_h = h
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

## Which way the ground faces at a point.
static func normal(x: float, z: float) -> Vector3:
	return Vector3(height(x - 2.0, z) - height(x + 2.0, z), 4.0, height(x, z - 2.0) - height(x, z + 2.0)).normalized()

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

# ================================================================ meshes and textures
static func _terrain_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	_ensure()
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var tg := PackedFloat32Array()
	var idx := PackedInt32Array()
	v.resize(_nx * _nz)
	n.resize(_nx * _nz)
	tg.resize(_nx * _nz * 4)
	for j in _nz:
		for i in _nx:
			var k := j * _nx + i
			v[k] = Vector3(X0 + i * CELL, _h[k], Z0 + j * CELL)
			var hl := _h[k - 1] if i > 0 else _h[k]
			var hr := _h[k + 1] if i < _nx - 1 else _h[k]
			var hd := _h[k - _nx] if j > 0 else _h[k]
			var hu := _h[k + _nx] if j < _nz - 1 else _h[k]
			var nn := Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()
			n[k] = nn
			# the detail maps are laid flat (u east, v south), so the tangent is east along the surface
			var t := (Vector3.RIGHT - nn * nn.x).normalized()
			tg[k * 4] = t.x
			tg[k * 4 + 1] = t.y
			tg[k * 4 + 2] = t.z
			tg[k * 4 + 3] = -1.0
	for j in _nz - 1:
		for i in _nx - 1:
			var a := j * _nx + i
			idx.append_array(PackedInt32Array([a, a + 1, a + _nx, a + 1, a + _nx + 1, a + _nx]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TANGENT] = tg
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
		var half := 1.35 + 1.6 * smoothstep(34.0, 8.0, c.y)
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

## One tiling noise for every shader here, kept as bytes too so that what is planted can follow what is painted.
static func _noise_tex() -> Texture2D:
	if _noise != null:
		return _noise
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 4
	n.seed = 1909
	var img := n.get_seamless_image(256, 256)
	img.convert(Image.FORMAT_L8)
	_noise_px = img.get_data()
	img.generate_mipmaps()
	_noise = ImageTexture.create_from_image(img)
	return _noise

## The noise as the shaders read it, at a texture coordinate.
static func _n(u: float, v: float) -> float:
	return float(_noise_px[int(fposmod(v, 1.0) * 255.99) * 256 + int(fposmod(u, 1.0) * 255.99)]) / 255.0

## Where heather grows: the same test the ground shader paints its patches with.
static func heathy(x: float, z: float) -> float:
	_noise_tex()
	return _n(x * 0.011 + 0.7, z * 0.011 + 0.2) * 0.62 + _n(x * 0.045 + 0.37, z * 0.045 + 0.11) * 0.38

## Which way the sun is, from a light's rotation in degrees.
static func _sun_dir(rot: Vector3) -> Vector3:
	return Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), 0.0)).z

## The land's own shadow for one generation's sun: every other vertex of the height field looks toward the sun and
## asks whether a hill or the cliff stands in the way. Baked once for each generation and kept.
static func _sun_mask(g: int) -> ImageTexture:
	if _sun.has(g):
		return _sun[g]
	_ensure()
	var s := _sun_dir(SEASONS[g - 1].sun_rot)
	var flat := Vector2(s.x, s.z)
	var rise := s.y / maxf(flat.length(), 0.001)
	flat = flat.normalized() / CELL          # in cells a metre
	var mx := (_nx + 1) / 2
	var mz := (_nz + 1) / 2
	var px := PackedByteArray()
	px.resize(mx * mz)
	for j in mz:
		for i in mx:
			var ci := float(i * 2)
			var cj := float(j * 2)
			var h0 := _h[mini(j * 2, _nz - 1) * _nx + mini(i * 2, _nx - 1)] + 0.6
			var worst := 0.0
			var d := 6.0
			for k in 30:
				var x := int(ci + flat.x * d + 0.5)
				var z := int(cj + flat.y * d + 0.5)
				if x < 0 or z < 0 or x >= _nx or z >= _nz:
					break
				var over := (_h[z * _nx + x] - (h0 + rise * d)) / (d * 0.05 + 1.0)
				if over > worst:
					worst = over
					if worst >= 1.0:
						break
				d += 5.0 + d * 0.07
			px[j * mx + i] = int(255.0 * (1.0 - clampf(worst, 0.0, 1.0)))
	var img := Image.create_from_data(mx, mz, false, Image.FORMAT_R8, px)
	_sun[g] = ImageTexture.create_from_image(img)
	return _sun[g]

## The height field as a texture, for the sea to find its shore by.
static func _heights() -> ImageTexture:
	if _height_tex != null:
		return _height_tex
	_ensure()
	var img := Image.create_from_data(_nx, _nz, false, Image.FORMAT_RF, _h.to_byte_array())
	img.convert(Image.FORMAT_RH)
	_height_tex = ImageTexture.create_from_image(img)
	return _height_tex

static func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

# ================================================================ building it
## Fills an Arena that has made its sky, sun and floor. Called by Arena._layout_highland.
static func build(a: Arena) -> void:
	_ensure()
	var st := {"kept": [], "ruin": [], "woken": [], "fires": [], "shared": [], "sunlit": []}
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
				fm.albedo_color = Color(0.62, 0.6, 0.57)
				fm.uv1_triplanar = true
				fm.uv1_world_triplanar = true
				fm.uv1_scale = Vector3.ONE * 0.22
				fm.roughness = 0.8
				fm.metallic_specular = 0.3
				if ResourceLoader.exists("res://assets/textures/floor_courtyard_n.png"):
					fm.normal_enabled = true
					fm.normal_texture = load("res://assets/textures/floor_courtyard_n.png")
				(c as MeshInstance3D).material_override = fm
		elif c is MeshInstance3D and (c as MeshInstance3D).mesh is TorusMesh:
			(c as MeshInstance3D).visible = false      # no duelling ring painted on a road
	a.sun.directional_shadow_max_distance = 85.0
	a.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	a.env.fog_aerial_perspective = 0.3
	a.env.fog_sun_scatter = 0.1
	a.env.fog_sky_affect = 0.0
	a.env.fog_height = SEA + 5.0
	a.env.fog_height_density = 0.012
	# a little light from the camera's side of the land, so a figure with the sun behind it is not a cut-out
	var fill := DirectionalLight3D.new()
	fill.name = "HLFill"
	fill.shadow_enabled = false
	fill.light_specular = 0.0
	fill.rotation_degrees = Vector3(-24, 0, 0)
	a.add_child(fill)
	var land_rect := Vector4(X0 - CELL, Z0 - CELL, 1.0 / (float((_nx + 1) / 2) * CELL * 2.0), 1.0 / (float((_nz + 1) / 2) * CELL * 2.0))
	# ---- ground
	var ground := ShaderMaterial.new()
	ground.shader = load("res://src/world/highland_ground.gdshader")
	ground.set_shader_parameter("path_mask", _road_mask())
	ground.set_shader_parameter("mask_rect", Vector4(MASK_X0, MASK_Z0, 1.0 / MASK_W, 1.0 / MASK_L))
	ground.set_shader_parameter("turf_tex", _tex("res://assets/textures/floor_blackwood.jpg"))
	ground.set_shader_parameter("turf_n", _tex("res://assets/textures/floor_blackwood_n.png"))
	ground.set_shader_parameter("rock_tex", _tex("res://assets/textures/floor_deep.jpg"))
	ground.set_shader_parameter("sett_tex", _tex("res://assets/textures/floor_courtyard.jpg"))
	ground.set_shader_parameter("sett_n", _tex("res://assets/textures/floor_courtyard_n.png"))
	ground.set_shader_parameter("sea_level", SEA)
	var land := MeshInstance3D.new()
	land.name = "HLGround"
	land.mesh = _terrain_mesh()
	land.material_override = ground
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	land.extra_cull_margin = 4.0
	a.add_child(land)
	st["ground"] = ground
	st.shared.append(ground)
	# ---- sea
	var sea := PlaneMesh.new()
	sea.size = Vector2(7000, 7000)
	var sea_mat := ShaderMaterial.new()
	sea_mat.shader = load("res://src/world/highland_sea.gdshader")
	sea_mat.set_shader_parameter("noise_tex", _noise_tex())
	sea_mat.set_shader_parameter("height_tex", _heights())
	sea_mat.set_shader_parameter("land_rect", Vector4(X0 - CELL * 0.5, Z0 - CELL * 0.5, 1.0 / (float(_nx) * CELL), 1.0 / (float(_nz) * CELL)))
	sea_mat.set_shader_parameter("sea_level", SEA)
	var sea_mi := MeshInstance3D.new()
	sea_mi.name = "HLSea"
	sea_mi.mesh = sea
	sea_mi.material_override = sea_mat
	sea_mi.position = Vector3(0, SEA, 0)
	sea_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(sea_mi)
	st["sea"] = sea_mat
	st.sunlit.append(sea_mat)
	# ---- cloud, moving, in two layers: a low broken deck and high streaks
	st["clouds"] = []
	for layer: Array in [[310.0, 0.00034, Vector2(1.0, 1.0), 1.0, 0.000026, 0.0, 0.95], [760.0, 0.00016, Vector2(1.0, 2.2), 0.45, 0.00006, 0.1, 0.4]]:
		var cloud := ShaderMaterial.new()
		cloud.shader = load("res://src/world/highland_cloud.gdshader")
		cloud.set_shader_parameter("noise_tex", _noise_tex())
		cloud.set_shader_parameter("scale", float(layer[1]))
		cloud.set_shader_parameter("stretch", layer[2])
		cloud.set_shader_parameter("speed", float(layer[3]))
		cloud.set_shader_parameter("bow", float(layer[4]))
		cloud.set_shader_parameter("density", float(layer[6]))
		cloud.set_meta("thin", float(layer[5]))
		var deck := PlaneMesh.new()
		deck.size = Vector2(9000, 9000)
		deck.subdivide_width = 36
		deck.subdivide_depth = 36
		deck.orientation = PlaneMesh.FACE_Y
		var deck_mi := MeshInstance3D.new()
		deck_mi.name = "HLCloud" if st.clouds.is_empty() else "HLCloudHigh"
		deck_mi.mesh = deck
		deck_mi.material_override = cloud
		deck_mi.position = Vector3(0, float(layer[0]), 0)
		deck_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		deck_mi.custom_aabb = AABB(Vector3(-4500, -900, -4500), Vector3(9000, 1000, 9000))
		deck_mi.sorting_offset = -float(layer[0])
		a.add_child(deck_mi)
		st.clouds.append(cloud)
		st.sunlit.append(cloud)
	st["cloud"] = st.clouds[0]
	_ranges(a, st)
	_shafts(a, st)
	_grass(a, st)
	_rocks(a, st)
	st["seam"] = _ring(a, st)
	_citadel(a, st)
	_gate_court(a, st)
	_wayside(a, st)
	for m: ShaderMaterial in st.shared:
		m.set_shader_parameter("noise_tex", _noise_tex())
		m.set_shader_parameter("land_rect", land_rect)
	a.set_meta("highland", st)
	generation(a, 1)

# ================================================================ grass and heath
## Clumps along the road: thick and fine beside it, where the camera is, coarser across the moor, and heather and
## gorse in their own patches. A few batches for each stretch, so what is far off is not drawn.
static func _grass(a: Arena, st: Dictionary) -> void:
	var mats: Array = []
	for kind in 3:
		var mat := ShaderMaterial.new()
		mat.shader = load("res://src/world/highland_grass.gdshader")
		mat.set_shader_parameter("albedo_tex", _heath_tex() if kind == 2 else _blades())
		mat.set_shader_parameter("heath", 1.0 if kind == 2 else 0.0)
		mat.set_shader_parameter("stiff", 0.45 if kind == 2 else 1.0)
		mat.set_shader_parameter("fade_near", [100.0, 250.0, 210.0][kind])
		mat.set_shader_parameter("fade_far", [136.0, 310.0, 260.0][kind])
		mats.append(mat)
		st.shared.append(mat)
	st["grass"] = mats[0]
	st["turf"] = mats
	var density := Game.particle_scale()            # 0.5 Performance, 0.8 Balanced, 1.0 High
	if _grass_mm.has(density):
		for e: Array in _grass_mm[density]:
			_grass_batch(a, e[0], mats[int(e[1])], int(e[1]))
		return
	_grass_mm[density] = []
	var clump := _clump_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	_noises()
	_noise_tex()
	var total := road_length()
	var span := 40.0
	var s0 := 0.0
	while s0 < total:
		# [transforms, colours, (unused), lowest corner, highest corner] for fine grass, tussocks, heath
		var sets: Array = []
		for kind in 3:
			sets.append([[], [], [], Vector3.ONE * 1e9, Vector3.ONE * -1e9])
		var fine := int(span * 66.0 * density)
		var middle := fine + int(span * 30.0 * density)
		var want := middle + int(span * 9.0 * density)
		var heath_tries := int(span * 26.0 * density)
		for i in want + heath_tries:
			var s := s0 + rng.randf() * span
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var off := 0.0
			var kind := 0
			var sc := rng.randf_range(0.62, 1.15)
			if i < fine:
				off = 1.1 + pow(rng.randf(), 1.5) * 11.0
				sc *= lerpf(0.5, 1.0, smoothstep(1.1, 4.5, off))
			elif i < middle:
				off = rng.randf_range(10.0, 40.0)
				sc *= 1.55
			elif i < want:
				off = rng.randf_range(36.0, 130.0)
				sc *= 2.7
				kind = 1
			else:
				off = 1.6 + pow(rng.randf(), 1.2) * 60.0
				kind = 2
			var p := road(s, off * side)
			if p.y < SEA + 9.0 or on_road(p.x, p.z) > 0.02 or Vector2(p.x, p.z + 4.0).length() < COURT_R + 1.4:
				continue
			var nn := normal(p.x, p.z)
			if nn.y < 0.88:
				continue                    # scree and rock, not turf
			var heathy_here := heathy(p.x, p.z)
			if kind == 2:
				if heathy_here < 0.555:
					continue
				sc = rng.randf_range(0.9, 1.9)
			elif kind == 0 and heathy_here > 0.59 and rng.randf() < 0.6:
				continue                    # the heather has that ground
			var e: Array = sets[kind]
			# a clump stands square to its own ground, so its up axis is also the normal it is lit with
			var basis := Basis(Quaternion(Vector3.UP, nn)) * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * (rng.randf_range(0.5, 0.75) if kind == 2 else rng.randf_range(0.8, 1.25)), sc))
			e[0].append(Transform3D(basis, p - Vector3(0, 0.03, 0)))
			# gorse among the heather: one clump in five flowers yellow (colour g says which)
			e[1].append(Color(rng.randf(), rng.randf(), rng.randf(), 1.0))
			e[3] = (e[3] as Vector3).min(p)
			e[4] = (e[4] as Vector3).max(p)
		for kind in 3:
			var e: Array = sets[kind]
			if e[0].is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = clump
			mm.instance_count = e[0].size()
			for i in e[0].size():
				mm.set_instance_transform(i, e[0][i])
				mm.set_instance_color(i, e[1][i])
			mm.custom_aabb = AABB(e[3] - Vector3(3, 1, 3), e[4] - e[3] + Vector3(6, 4, 6))
			_grass_mm[density].append([mm, kind])
			_grass_batch(a, mm, mats[kind], kind)
		s0 += span

static func _grass_batch(a: Arena, mm: MultiMesh, mat: ShaderMaterial, kind: int) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = [142.0, 320.0, 268.0][kind]
	a.add_child(mi)

## One clump: three cards crossed through a point, each showing a different run of the blades.
static func _clump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.6
	var h := 0.52
	for k in 3:
		var ang := PI * float(k) / 3.0 + 0.2
		var d := Vector3(cos(ang), 0, sin(ang)) * w
		var lean := Vector3(-sin(ang), 0, cos(ang)) * 0.1 * (1.0 if k != 1 else -1.0)
		var u0 := 0.0 if k % 2 == 0 else 1.0
		var corners := [[-d, Vector2(u0, 1.0)], [d, Vector2(1.0 - u0, 1.0)], [d + Vector3(0, h, 0) + lean, Vector2(1.0 - u0, 0.0)], [-d + Vector3(0, h, 0) + lean, Vector2(u0, 0.0)]]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(corners[i][1])
			st.set_normal(Vector3.UP)
			st.add_vertex(corners[i][0])
	return st.commit()

## Blades of grass for the cards: thin, many, of every height, a few gone to seed. The shader tints them.
static func _blades() -> Texture2D:
	if Look._cache.has("highland_blades3"):
		return Look._cache["highland_blades3"]
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.0, 0.0, 0))
	var r := RandomNumberGenerator.new()
	r.seed = 23
	for b in 120:
		var base_x := r.randf_range(6.0, 250.0)
		var lean := r.randf_range(-46.0, 46.0)
		var h := float(size) * (r.randf_range(0.3, 0.72) if b % 5 != 0 else r.randf_range(0.74, 0.99))
		var w := r.randf_range(1.3, 3.1)
		var shade := r.randf_range(0.45, 1.0)
		var seed_head := b % 9 == 0
		for y in int(h):
			var u := float(y) / h
			var cx := base_x + lean * u * u
			var half := w * (1.0 - u * 0.9) + 0.4
			if seed_head and u > 0.84:
				half += 1.6 * sin((u - 0.84) / 0.16 * PI)
			for x in range(int(cx - half), int(cx + half) + 1):
				if x >= 0 and x < size:
					# a pale midrib and a darker edge give each blade a little form
					var across := absf(float(x) - cx) / maxf(half, 0.5)
					var v := (0.5 + 0.5 * u) * shade * (1.0 - 0.3 * across)
					img.set_pixel(x, size - 1 - y, Color(v, 0.0, 0.0, 1.0))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	Look._cache["highland_blades3"] = t
	return t

## Heather and gorse: a low dome of twigs (red: light and dark) with flower along the upper stems (green).
static func _heath_tex() -> Texture2D:
	if Look._cache.has("highland_heath"):
		return Look._cache["highland_heath"]
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.0, 0.0, 0))
	var r := RandomNumberGenerator.new()
	r.seed = 61
	for b in 120:
		var base_x := r.randf_range(22.0, 106.0)
		var lean := (base_x - 64.0) * r.randf_range(0.6, 1.3) + r.randf_range(-14.0, 14.0)
		var dome := sqrt(maxf(0.0, 1.0 - pow((base_x - 64.0) / 60.0, 2.0)))
		var h := float(size) * r.randf_range(0.45, 0.98) * (0.45 + 0.55 * dome)
		var shade := r.randf_range(0.35, 1.0)
		var flower_from := r.randf_range(0.35, 0.7)
		for y in int(h):
			var u := float(y) / h
			var cx := base_x + lean * u * u * 0.5 + sin(u * 9.0 + float(b)) * 1.5
			var half := 1.6 + (2.4 * sin(u * 34.0 + float(b)) if u > flower_from else 0.0)
			for x in range(int(cx - half), int(cx + half) + 1):
				if x >= 0 and x < size:
					img.set_pixel(x, size - 1 - y, Color((0.4 + 0.6 * u) * shade, 1.0 if u > flower_from and (x + y + b) % 3 != 0 else 0.0, 0.0, 1.0))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	Look._cache["highland_heath"] = t
	return t

# ================================================================ rock
## A crag: a ball cut by a handful of planes into faces, then stepped a little so it has beds like the cliffs.
static func _crag_mesh(seed_n: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var planes: Array = []
	for k in 11:
		var n := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.25, 0.9), rng.randf_range(-1.0, 1.0)).normalized()
		planes.append([n, rng.randf_range(0.58, 1.0)])
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 14
	ball.rings = 7
	var arr := ball.get_mesh_arrays()
	var src: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var pts := PackedVector3Array()
	for v: Vector3 in src:
		var d := v.normalized()
		var reach := 1.3
		for pl: Array in planes:
			var along := d.dot(pl[0])
			if along > 0.05:
				reach = minf(reach, float(pl[1]) / along)
		var p := d * reach
		p.y = lerpf(p.y, roundf(p.y * 3.5) / 3.5, 0.55)
		pts.append(p)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i: int in idx:
		st.add_vertex(pts[i])
	st.generate_normals()
	return st.commit()

## Rock the turf never covered: outcrops beside the road, the broken edge of the cliff, stacks standing in the sea,
## and the shoulders the Ring-Gate is footed on. One batch.
static func _rocks(a: Arena, st: Dictionary) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/world/highland_rock.gdshader")
	mat.set_shader_parameter("rock_tex", _tex("res://assets/textures/floor_deep.jpg"))
	mat.set_shader_parameter("sea_level", SEA)
	st["rock"] = mat
	st.shared.append(mat)
	if _crag_mm == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1909
		var xf: Array = []
		# [x, z, width, height, depth, sink]: the ones that are placed by hand
		var placed: Array = [
			# stacks in the sea, and the reef they stand on
			[112.0, 318.0, 9.0, 34.0, 8.0, 5.0], [124.0, 300.0, 6.0, 20.0, 6.0, 4.0], [138.0, 214.0, 11.0, 44.0, 9.0, 5.0],
			[118.0, 108.0, 8.0, 30.0, 8.0, 4.0], [150.0, 420.0, 10.0, 26.0, 9.0, 4.0], [104.0, 30.0, 7.0, 38.0, 7.0, 4.0],
			# the shoulders of the gate
			[-52.0, -12.0, 12.0, 11.0, 10.0, 3.0], [-64.0, -24.0, 15.0, 16.0, 11.0, 4.0], [50.0, -14.0, 11.0, 9.0, 9.0, 3.0],
			[-44.0, 6.0, 6.0, 5.0, 5.0, 1.5], [44.0, 10.0, 7.0, 4.5, 6.0, 1.5],
		]
		for p: Array in placed:
			var at := on_ground(float(p[0]), float(p[1]))
			at.y = maxf(at.y, SEA - 2.0) - float(p[5])
			xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(float(p[2]), float(p[3]), float(p[4]))), at))
		# outcrops: one big stone and a couple that came off it
		for i in 44:
			var sr := rng.randf() * road_length()
			var off := rng.randf_range(6.0, 64.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			var p := road(sr, off)
			if p.y < SEA + 8.0 or Vector2(p.x, p.z + 4.0).length() < COURT_R + 6.0 or on_road(p.x, p.z) > 0.0:
				continue
			var size := rng.randf_range(0.9, 3.4) * (1.0 + absf(off) / 60.0)
			for k in 3:
				var q := p if k == 0 else on_ground(p.x + rng.randf_range(-1.6, 1.6) * size, p.z + rng.randf_range(-1.6, 1.6) * size)
				if on_road(q.x, q.z) > 0.0:
					continue
				var sk := size if k == 0 else size * rng.randf_range(0.25, 0.5)
				var b := Basis.from_euler(Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25)))
				xf.append(Transform3D(b.scaled(Vector3(sk * rng.randf_range(1.0, 1.7), sk * rng.randf_range(0.6, 1.1), sk)), q - Vector3(0, sk * 0.3, 0)))
		# the lip of the cliff
		var z := 500.0
		while z > -30.0:
			var x := cliff_x(z) - rng.randf_range(0.0, 5.0)
			var sk := rng.randf_range(2.0, 4.6)
			xf.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))).scaled(Vector3(sk * 1.5, sk, sk * 1.2)), on_ground(x, z, -sk * 0.35)))
			z -= rng.randf_range(11.0, 26.0)
		_crags = [_crag_mesh(5), _crag_mesh(17), _crag_mesh(31)]
		# one MultiMesh for each shape, sharing the list out
		_crag_mm = MultiMesh.new()
		_crag_mm.set_meta("xf", xf)
	var all: Array = _crag_mm.get_meta("xf")
	for k in _crags.size():
		var mine: Array = []
		for i in all.size():
			if i % _crags.size() == k:
				mine.append(all[i])
		var mi := _batch(a, "HLCrag%d" % k, _crags[k], mine, mat, true)
		mi.custom_aabb = AABB(Vector3(X0, SEA - 10.0, Z0), Vector3(X1 - X0, 200.0, Z1 - Z0))

# ================================================================ the far country
## Ranges of hills behind the gate and across the moor, one behind another, in one mesh. Each row of it is a ridge:
## a crest, a shoulder and a foot, so its faces take the sun differently; the vertex alpha is how much air there is
## in front of it.
static func _ranges(a: Arena, st: Dictionary) -> void:
	if _far == null:
		var crest := FastNoiseLite.new()
		crest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		crest.frequency = 1.0
		crest.fractal_octaves = 4
		var sf := SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		# [radius, air, height, from, to (degrees; 0 is behind the gate, positive toward the sea), seed, snow on the tops]
		for layer: Array in [[470.0, 0.1, 110.0, -78.0, 70.0, 3, 0.0], [820.0, 0.28, 290.0, -150.0, 34.0, 11, 0.0], [1250.0, 0.44, 440.0, -160.0, 48.0, 23, 0.0],
				[1900.0, 0.64, 640.0, -165.0, 30.0, 37, 0.5], [2900.0, 0.8, 930.0, -170.0, 60.0, 51, 1.0], [2500.0, 0.72, 170.0, 58.0, 118.0, 67, 0.0]]:
			var radius := float(layer[0])
			var n := 150
			var rows: Array = []
			for i in n + 1:
				var u := float(i) / float(n)
				var az := deg_to_rad(lerpf(float(layer[3]), float(layer[4]), u))
				var env := pow(sin(u * PI), 0.55)
				var ridged := 1.0 - absf(crest.get_noise_2d(az * 3.2, float(layer[5])))
				var top := float(layer[2]) * env * (0.3 + 0.7 * ridged * ridged) * (0.75 + 0.5 * crest.get_noise_2d(az * 0.9 + 10.0, float(layer[5])))
				var dir := Vector3(sin(az), 0, -cos(az))
				var wob := crest.get_noise_2d(az * 9.0, float(layer[5]) + 5.0)
				rows.append([
					RING_C * Vector3(1, 0, 1) + dir * radius + Vector3(0, SEA + top, 0),
					RING_C * Vector3(1, 0, 1) + dir * (radius - top * (0.55 + 0.35 * wob)) + Vector3(0, SEA + top * (0.5 + 0.2 * wob), 0),
					RING_C * Vector3(1, 0, 1) + dir * (radius - top * 1.5 - 40.0) + Vector3(0, SEA - 12.0, 0)])
			var col := Color(0, float(layer[6]), 0, float(layer[1]))
			for i in n:
				for r in 2:
					var quad := [[rows[i][r], 1.0 - 0.5 * r], [rows[i + 1][r], 1.0 - 0.5 * r], [rows[i + 1][r + 1], 0.5 - 0.5 * r], [rows[i][r + 1], 0.5 - 0.5 * r]]
					for k: int in [0, 1, 2, 0, 2, 3]:
						sf.set_color(col)
						sf.set_uv(Vector2(float(i) / float(n), quad[k][1]))
						sf.add_vertex(quad[k][0])
		sf.generate_normals()
		_far = sf.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/world/highland_far.gdshader")
	var mi := MeshInstance3D.new()
	mi.name = "HLFar"
	mi.mesh = _far
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(mi)
	st["far"] = mat
	st.sunlit.append(mat)

## Shafts of light through the cloud: a few long cards the shader lays along the sun's direction.
static func _shafts(a: Arena, st: Dictionary) -> void:
	var card := ArrayMesh.new()
	var sf := SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0)]
	for k: int in [0, 1, 2, 0, 2, 3]:
		sf.set_uv(Vector2(corners[k].x + 0.5, corners[k].y))
		sf.add_vertex(corners[k])
	card = sf.commit()
	var xf: Array = []
	# [where it lands (x, z), width, length]
	for f: Array in [[14.0, -8.0, 30.0, 360.0], [-70.0, 110.0, 44.0, 420.0], [-36.0, 300.0, 36.0, 380.0], [40.0, 250.0, 26.0, 340.0],
			[120.0, 200.0, 60.0, 460.0], [150.0, 40.0, 48.0, 420.0], [-130.0, 20.0, 54.0, 440.0], [10.0, -150.0, 70.0, 520.0], [84.0, 380.0, 40.0, 400.0]]:
		xf.append(Transform3D(Basis.IDENTITY.scaled(Vector3(float(f[2]), float(f[3]), 1.0)), on_ground(float(f[0]), float(f[1]), -2.0)))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/world/highland_shaft.gdshader")
	var mi := _batch(a, "HLShafts", card, xf, mat, false)
	mi.custom_aabb = AABB(Vector3(-900, SEA - 20.0, -900), Vector3(1800, 900, 1800))
	st["shaft"] = mat
	st.sunlit.append(mat)

# ================================================================ the Ring-Gate
## The Ring-Gate: forty stones in a ring, an arc of them gone, a seam of something that is not stone set into the
## inner face; and so that it has form from a long way off, teeth standing out of its rim, a plinth under each foot,
## and in the first generation the long banners of the house on it and watch-fires on its shoulders.
static func _ring(a: Arena, st: Dictionary) -> StandardMaterial3D:
	var stone := Look.stone(Color("#8d877b"), 0.07, 0.9, "ringgate")
	stone.disable_fog = true          # the landmark is drawn by its own light and shadow, not by the haze
	var block := BoxMesh.new()
	block.size = Vector3(TAU * (RING_R + RING_THICK * 0.5) / RING_BLOCKS * 0.97, RING_THICK, RING_DEEP)
	var tooth := BoxMesh.new()
	tooth.size = Vector3(block.size.x * 0.56, 4.4, RING_DEEP * 1.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 97
	var xf: Array = []
	var lamps: Array = []
	var teeth: Array = []
	var arc: Array = []           # the stones that stand in the first generation and are down by the second
	var arc_lamps: Array = []
	var arc_teeth: Array = []
	var fallen: Array = []
	for i in RING_BLOCKS:
		var ang := TAU * (float(i) + 0.5) / RING_BLOCKS
		var gone := ang > BREAK_FROM and ang < BREAK_TO
		var r := RING_R + rng.randf_range(-0.5, 0.5)
		var basis := Basis(Vector3(0, 0, 1), ang)
		var out := Vector3(sin(ang), -cos(ang), 0)
		var at := RING_C + out * r + Vector3(0, 0, rng.randf_range(-0.35, 0.35))
		var sc := Vector3(1.0, rng.randf_range(0.94, 1.05), rng.randf_range(0.92, 1.06))
		(arc if gone else xf).append(Transform3D(basis.scaled(sc), at))
		if rng.randf() < 0.8:
			(arc_lamps if gone else lamps).append(Transform3D(basis, RING_C + out * (RING_R - RING_THICK * 0.5 - 0.05) + Vector3(0, 0, RING_DEEP * 0.5 - 0.6)))
		if i % 2 == 0:
			(arc_teeth if gone else teeth).append(Transform3D(basis, RING_C + out * (RING_R + RING_THICK * 0.5 + 1.6)))
	# what came down lies east of the court, where the ground breaks toward the cliff
	for f: Array in [[38.0, -14.0, 0.5, 0.3], [47.0, -2.0, 1.1, -0.4], [33.0, 4.0, 2.0, 0.7], [52.0, -22.0, 0.2, 1.3]]:
		var p := on_ground(float(f[0]), float(f[1]), 2.2)
		fallen.append(Transform3D(Basis.from_euler(Vector3(float(f[3]) * 0.5, float(f[2]), float(f[3]))).scaled(Vector3.ONE * 0.9), p))
	var seam := Look.glow(Color("#5fe0c8"), 0.5)
	seam.albedo_color = Color(0.08, 0.1, 0.1)
	var strip := BoxMesh.new()
	strip.size = Vector3(block.size.x * 0.7, 1.9, 0.7)
	_batch(a, "HLRing", block, xf, stone, true)
	_batch(a, "HLRingArc", block, arc, stone, true)
	_batch(a, "HLRingFallen", block, fallen, stone, true)
	_batch(a, "HLRingTeeth", tooth, teeth, stone, false)
	st.kept.append(_batch(a, "HLRingTeethArc", tooth, arc_teeth, stone, false))
	_batch(a, "HLSeam", strip, lamps, seam, false)
	_batch(a, "HLSeamArc", strip, arc_lamps, seam, false)
	# the plinths: where the ring goes into the ground it stands on something
	var feet: Array = []
	var cloth: Array = []
	var scars: Array = []
	for sx: float in [-1.0, 1.0]:
		var foot := Vector3(sx * 35.0, 0, RING_C.z)
		feet.append([Vector3(23.0, 5.0, 16.0), on_ground(foot.x, foot.z, 1.5)])
		feet.append([Vector3(20.0, 5.0, 14.0), on_ground(foot.x, foot.z, 6.0), Vector3(0, 0, sx * 5.0)])
		feet.append([Vector3(16.5, 6.0, 12.5), on_ground(foot.x, foot.z, 11.0), Vector3(0, 0, sx * 12.0)])
		for fin: float in [-7.5, 0.0, 7.5]:
			feet.append([Vector3(2.0, 13.0, 2.2), on_ground(foot.x + fin, foot.z, 6.5) + Vector3(0, 0, 7.6), Vector3(-6.0, 0, 0)])
		feet.append([Vector3(5.0, 22.0, 4.0), on_ground(sx * 27.5, RING_C.z + 5.5, 9.0), Vector3(0, 0, sx * -4.0)])
		# the house's colours, the height of the gatehouse twice over
		cloth.append([Vector3(3.6, 11.0, 0.25), on_ground(sx * 38.0, RING_C.z, 7.0) + Vector3(0, 0, 8.3)])
		a.fire(Vector3(sx * 36.0, 15.2, RING_C.z + 5.0), 3.0, 34.0, false)
	_solid(a, "HLRingFeet", feet, stone, true)
	st.kept.append(_solid(a, "HLRingCloth", cloth, _cloth_mat(), false))
	# where the arc came away: the timber the masons left when they gave up on mending it
	var timber := Look.flat(Color("#2a2119"), 1.0)
	for ang: float in [BREAK_FROM - 0.03, BREAK_TO + 0.03]:
		var out := Vector3(sin(ang), -cos(ang), 0)
		var c := RING_C + out * RING_R
		for k in 5:
			scars.append([Vector3(0.7, 17.0, 0.7), c + Vector3((k - 2) * 2.8, -1.0, RING_DEEP * 0.5 + 1.2), Vector3(0, 0, (k - 2) * 3.0)])
		for k in 3:
			scars.append([Vector3(13.0, 0.6, 0.9), c + Vector3(0, -7.0 + k * 6.0, RING_DEEP * 0.5 + 1.4), Vector3(0, 0, rad_to_deg(ang) * 0.1 + (k - 1) * 6.0)])
	st.ruin.append(_solid(a, "HLRingScars", scars, timber, false))
	return seam

static func _cloth_mat() -> StandardMaterial3D:
	var m := Look.flat(Color("#7a1c16"), 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func _batch(a: Arena, node_name: String, mesh: Mesh, xf: Array, mat: Material, shadows: bool) -> MultiMeshInstance3D:
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
	return mi

## Many boxes as one mesh: [size, where, rotation in degrees] each. One draw for a whole building.
static func _solid(parent: Node3D, node_name: String, boxes: Array, mat: Material, shadows: bool) -> MeshInstance3D:
	var sf := SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var unit := BoxMesh.new()
	for b: Array in boxes:
		var rot: Vector3 = b[2] if b.size() > 2 else Vector3.ZERO
		var basis := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))) * Basis.from_scale(b[0])
		sf.append_from(unit, 0, Transform3D(basis, b[1]))
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = sf.commit()
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

# ================================================================ the citadel
## The citadel, far behind the gate and seen through it: two stepped spires and the span between them, on a wall
## of towers. Built so that it has a lit side and a shadow side from the road: every tier has corner piers and a
## buttress, the wall has towers and merlons, the windows of the first generation are lit and its banners are out.
## By the second the eastern spire has lost its head and stands in scaffolding.
static func _citadel(a: Arena, st: Dictionary) -> void:
	var m := Look.stone(Color("#77716a"), 0.016, 0.95, "citadel")
	m.disable_fog = true
	var root := Node3D.new()
	root.name = "HLCitadel"
	root.position = Vector3(6.0, 34.0, -330.0)
	a.add_child(root)
	var body: Array = []
	var head: Array = []          # the top of the eastern spire: gone after the first generation
	var lit: Array = []
	var cloth: Array = []
	var scaffold: Array = []
	for sx: float in [-1.0, 1.0]:
		var y := 0.0
		var c := Vector3(sx * 27.0, 0, sx * -6.0)
		for k in 5:
			var w := 34.0 - k * 6.0
			var h := 27.0 - k * 3.0
			var into: Array = head if sx > 0.0 and k >= 3 else body
			into.append([Vector3(w, h, w), c + Vector3(0, y + h * 0.5, 0)])
			for cx: float in [-1.0, 1.0]:
				for cz: float in [-1.0, 1.0]:
					into.append([Vector3(w * 0.17, h + 3.5, w * 0.17), c + Vector3(cx * w * 0.5, y + h * 0.5 + 1.75, cz * w * 0.5)])
			into.append([Vector3(w * 0.22, h * 0.8, 5.0), c + Vector3(0, y + h * 0.4, w * 0.5 + 2.0)])
			into.append([Vector3(5.0, h * 0.8, w * 0.22), c + Vector3(sx * (w * 0.5 + 2.0), y + h * 0.4, 0)])
			if k >= 1 and k <= 3:
				for wx: float in [-0.27, 0.27]:
					lit.append([Vector3(1.5, h * 0.36, 0.5), c + Vector3(wx * w, y + h * 0.55, w * 0.5 + 0.3)])
			y += h
		(head if sx > 0.0 else body).append([Vector3(3.2, 22.0, 3.2), c + Vector3(0, y + 11.0, 0)])
		(head if sx > 0.0 else body).append([Vector3(7.0, 3.0, 7.0), c + Vector3(0, y + 1.5, 0)])
		cloth.append([Vector3(5.5, 46.0, 0.4), c + Vector3(0, 48.0, 17.6)])
	# the span, and the piers it rides on
	body.append([Vector3(46.0, 5.0, 8.0), Vector3(0, 64.0, 0)])
	body.append([Vector3(46.0, 2.0, 10.0), Vector3(0, 67.5, 0)])
	for px: float in [-7.0, 7.0]:
		body.append([Vector3(3.6, 40.0, 6.0), Vector3(px, 44.0, 0)])
	# the rock it stands on, cut square, and the wall along the front of it
	body.append([Vector3(150.0, 30.0, 60.0), Vector3(0, -6.0, 6.0)])
	body.append([Vector3(270.0, 22.0, 40.0), Vector3(0, -22.0, 30.0)])
	for tx: float in [-118.0, -78.0, -42.0, 42.0, 78.0, 118.0]:
		body.append([Vector3(15.0, 46.0, 15.0), Vector3(tx, -4.0, 44.0)])
		body.append([Vector3(18.0, 4.0, 18.0), Vector3(tx, 20.0, 44.0)])
		lit.append([Vector3(1.4, 5.0, 0.5), Vector3(tx, 8.0, 51.8)])
	for i in 26:
		body.append([Vector3(5.0, 4.0, 4.0), Vector3(-125.0 + i * 10.0, -9.0, 49.0)])
	# scaffolding up the broken spire
	var east := Vector3(27.0, 0, -6.0)
	for k in 6:
		scaffold.append([Vector3(1.2, 52.0, 1.2), east + Vector3(-12.0 + k * 4.8, 78.0, 12.5 + (k % 2) * 1.5), Vector3(0, 0, (k - 2.5) * 0.8)])
	for k in 5:
		scaffold.append([Vector3(28.0, 1.0, 1.4), east + Vector3(0, 56.0 + k * 10.0, 13.5), Vector3(0, 0, (k % 2) * 4.0 - 2.0)])
	_solid(root, "Stone", body, m, false)
	st.kept.append(_solid(root, "Head", head, m, false))
	st.kept.append(_solid(root, "Cloth", cloth, _cloth_mat(), false))
	st.ruin.append(_solid(root, "Scaffold", scaffold, Look.flat(Color("#231c16"), 1.0), false))
	var windows := Look.glow(Color("#ffb45a"), 2.4)
	_solid(root, "Windows", lit, windows, false)
	st["windows"] = windows
	# and the mountains it was cut from, a long way off
	for p: Array in [[-560.0, -640.0, 300.0, 40.0], [-800.0, -160.0, 270.0, 280.0]]:
		var pk := a.prop("peak", float(p[2]), Vector3(float(p[0]), -40.0, float(p[1])), float(p[3]))
		if pk:
			for mi in pk.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ================================================================ the gate court
## The court between the ring's feet. In the first generation it is a kept fortress: the gatehouse shut, the curtain
## wall whole to either side of it, fires fed, banners in ranks, the kings' statues standing. After it, what the
## years did: the gatehouse settled and dark, ivy on it, a statue down, rubble where the wall has shed.
static func _gate_court(a: Arena, st: Dictionary) -> void:
	var gate := a.prop("road_gatehouse", 13.0, GATE_AT, GATE_YAW)
	if gate == null:
		gate = a.prop("gate", 13.0, GATE_AT, 0.0)
	st["gatehouse"] = gate
	_shadowed(gate)
	for sx: float in [-1.0, 1.0]:
		a.prop("wall", 8.5, Vector3(sx * 12.6, 0, -22.5), 0.0 if sx < 0 else 180.0)
		a.prop("wall", 8.5, on_ground(sx * 21.6, -23.5, -0.4), 4.0 * sx + (0.0 if sx < 0 else 180.0))
		for b: Array in [[4.4, -8.5], [4.4, 3.0]]:
			a.prop("brazier", 1.9, Vector3(sx * float(b[0]), 0, float(b[1])), 0.0)
			a.fire(Vector3(sx * float(b[0]), 1.75, float(b[1])), 2.2, 10.0, false)
		for b: Array in [[8.4, -13.0, -14.0], [10.6, -4.0, -8.0]]:
			st.kept.append(_shadowed(a.prop("banner", 6.5, Vector3(sx * float(b[0]), 0, float(b[1])), sx * float(b[2]))))
		_shadowed(a.prop("pillar", 4.6, Vector3(sx * 11.5, 0, 6.5), sx * 40.0))
	_shadowed(a.prop("statue", 9.0, on_ground(-17.0, -8.0, -0.3), 28.0))
	st.kept.append(_shadowed(a.prop("statue", 9.0, on_ground(17.0, -8.0, -0.3), -28.0)))
	# the years
	for r: Array in [[17.5, -7.0, 3.6, 70.0], [12.5, 4.5, 2.4, 20.0], [-11.0, 8.5, 1.8, 200.0], [-7.5, -15.5, 2.2, 140.0], [6.0, -17.0, 1.6, 300.0]]:
		st.ruin.append(a.prop("rubble", float(r[2]), on_ground(float(r[0]), float(r[1]), -0.2), float(r[3])))
	st.ruin.append(_ivy(a))
	# awake: the seam between the doors
	var seam := Node3D.new()
	seam.name = "HLGateSeam"
	a.add_child(seam)
	var glow := a.box(Vector3(0.22, 8.2, 0.3), GATE_AT + Vector3(0, 4.3, 2.8), Look.glow(Color("#5fe0c8"), 4.0))
	a.remove_child(glow)
	seam.add_child(glow)
	var l := OmniLight3D.new()
	l.light_color = Color("#5fe0c8")
	l.light_energy = 3.0
	l.omni_range = 16.0
	l.position = GATE_AT + Vector3(0, 3.0, 6.0)
	seam.add_child(l)
	st.woken.append(seam)

## Ivy up the face of the gatehouse: leaf cards in one batch, thick at the foot and thinning as it climbs.
static func _ivy(a: Arena) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.9, 0.9)
	var xf: Array = []
	for stem in 9:
		var x := rng.randf_range(-6.5, 6.5)
		if absf(x) < 2.6:
			x = signf(x) * rng.randf_range(2.8, 6.5)
		var top := rng.randf_range(3.0, 10.5)
		var y := 0.0
		while y < top:
			x += rng.randf_range(-0.35, 0.35)
			var sc := lerpf(1.3, 0.6, y / top) * rng.randf_range(0.7, 1.3)
			xf.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.5, 0.5), rng.randf() * TAU)).scaled(Vector3.ONE * sc),
				GATE_AT + Vector3(x, y + 0.2, 2.85 + rng.randf_range(0.0, 0.25))))
			y += rng.randf_range(0.25, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _ivy_tex()
	mat.albedo_color = Color(0.3, 0.36, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	return _batch(a, "HLIvy", leaf, xf, mat, false)

## A spray of ivy leaves.
static func _ivy_tex() -> Texture2D:
	if Look._cache.has("highland_ivy"):
		return Look._cache["highland_ivy"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 0))
	var r := RandomNumberGenerator.new()
	r.seed = 12
	for leaf in 16:
		var c := Vector2(r.randf_range(8.0, 56.0), r.randf_range(8.0, 56.0))
		var rad := r.randf_range(4.0, 8.0)
		var turn := r.randf() * TAU
		var shade := r.randf_range(0.55, 1.0)
		for y in range(int(c.y - rad), int(c.y + rad) + 1):
			for x in range(int(c.x - rad), int(c.x + rad) + 1):
				if x < 0 or y < 0 or x >= 64 or y >= 64:
					continue
				var d := Vector2(x, y) - c
				var ang := d.angle() - turn
				# five points, like a hand
				if d.length() < rad * (0.62 + 0.38 * absf(cos(ang * 2.5))):
					img.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	Look._cache["highland_ivy"] = t
	return t

# ================================================================ beside the road
## What stands beside the road: waystones in pairs, a ruined arch where the climb ends, the dead tree (and its
## fellow, down where the road begins), a king's fallen head, old banners.
static func _wayside(a: Arena, st: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1909
	# waystones: one each side, every sixty metres or so, some of them broken off short
	var s := 44.0
	var k := 0
	while s < road_length() - 30.0:
		for side: float in [-1.0, 1.0]:
			if rng.randf() < 0.25:
				continue
			var p := road(s + rng.randf_range(-1.0, 1.0), side * rng.randf_range(2.7, 3.3))
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
	# the dead tree in the saddle below the gate, and another where the road sets out
	_dead_tree(a, road(tree_s(), -5.5) - Vector3(0, 0.5, 0), 7.6, 200.0)
	_dead_tree(a, road(75.0, 7.5) - Vector3(0, 0.5, 0), 6.8, 20.0)
	# a king's head, off its statue, where the road tops the rise
	var sh := road_at_z(103.0)
	_shadowed(a.prop("statue_head", 4.6, road(sh, 9.0) - Vector3(0, 1.1, 0), -150.0))
	# banners on the last stretch, kept while the road is
	for b: Array in [[44.0, 3.4, 20.0], [31.0, -3.6, -30.0], [58.0, 3.8, 0.0]]:
		var flag := a.prop("banner", 5.6, road(road_at_z(float(b[0])), float(b[1])) - Vector3(0, 0.2, 0), rad_to_deg(road_yaw(road_at_z(float(b[0])))) + float(b[2]))
		st.kept.append(_shadowed(flag))

## The dead tree: a wind-bent hawthorn on its mound of rock (the generated prop; a bare procedural one without it).
static func _dead_tree(a: Arena, at: Vector3, tall: float, yaw: float) -> void:
	var tree := a.prop("road_dead_tree", tall, at, yaw)
	if tree:
		_shadowed(tree)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# [base, direction, length, radius, depth]
	var todo: Array = [[Vector3.ZERO, Vector3(-0.12, 1.0, 0.05).normalized(), 3.6, 0.42, 0]]
	while not todo.is_empty():
		var b: Array = todo.pop_back()
		var from: Vector3 = b[0]
		var dir: Vector3 = b[1]
		var length: float = b[2]
		var r: float = b[3]
		var depth: int = b[4]
		var limb := CylinderMesh.new()
		limb.top_radius = r * 0.62
		limb.bottom_radius = r
		limb.height = length
		limb.radial_segments = 7 if depth < 2 else 5
		limb.rings = 1
		var basis := Basis(Quaternion(Vector3.UP, dir))
		st.append_from(limb, 0, Transform3D(basis, from + dir * length * 0.5))
		if depth >= 4:
			continue
		var tip := from + dir * length
		for k in (2 if depth > 0 else 3):
			var bend := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.1, 0.9), rng.randf_range(-1.0, 1.0)) + Vector3(-0.8, 0.0, 0.5)
			todo.append([tip - dir * rng.randf_range(0.0, length * 0.3), (dir * 0.75 + bend.normalized() * 0.75).normalized(), length * rng.randf_range(0.55, 0.78), r * 0.6, depth + 1])
	var mi := MeshInstance3D.new()
	mi.name = "HLTree"
	mi.mesh = st.commit()
	mi.material_override = Look.stone(Color("#3b342d"), 0.9, 0.95, "bark")
	mi.position = at
	a.add_child(mi)

## Where on the road the dead tree stands.
static func tree_s() -> float:
	return road_at_z(62.0)

## Scenery away from the court is told not to cast shadows (PropModel.scenery); these few are the road's
## landmarks, and their long shadows are part of the picture.
static func _shadowed(n: Node3D) -> Node3D:
	if n == null:
		return null
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return n

# ================================================================ seasons
## Sets which generation's road this is (1, 2 or 3): the light and the air, the colour of the turf, the weather,
## whether the ring is whole, how worn the road still is, whether the fires and banners are kept, and how awake
## the gate is. The composition never changes; what is in it does.
static func generation(a: Arena, g: int) -> void:
	var st: Dictionary = a.get_meta("highland", {})
	if st.is_empty():
		return
	g = clampi(g, 1, SEASONS.size())
	var s: Dictionary = SEASONS[g - 1]
	a.set_meta("generation", g)
	var whole: bool = s.whole
	for nm: String in ["HLRingArc", "HLSeamArc"]:
		(a.get_node(nm) as Node3D).visible = whole
	(a.get_node("HLRingFallen") as Node3D).visible = not whole
	# kept in the first generation; after it nobody feeds the fires, and the banners are down
	if st.fires.is_empty():
		for f: Array in a.fires:
			st.fires.append(float(f[1]))
	for i in a.fires.size():
		a.fires[i][1] = float(st.fires[i]) if whole and i < st.fires.size() else 0.0
		(a.fires[i][0] as Light3D).visible = whole
	for p in a.find_children("*", "CPUParticles3D", true, false):
		if (p as CPUParticles3D).lifetime < 1.0:
			(p as CPUParticles3D).emitting = whole
	for n in st.kept:
		if n != null:
			(n as Node3D).visible = whole
	for n in st.ruin:
		if n != null:
			(n as Node3D).visible = not whole
	for n in st.woken:
		(n as Node3D).visible = float(s.seam) > 1.0
	# the gatehouse: square and clean while it is kept; settled, stained and dark afterwards
	var gate: Node3D = st.get("gatehouse")
	if gate:
		gate.rotation_degrees = Vector3(0, GATE_YAW, 0) if whole else Vector3(2.6, GATE_YAW, 1.6)
		gate.position = GATE_AT if whole else GATE_AT + Vector3(0, -0.5, 0)
		Look.set_param(gate, &"tint", Color(1, 1, 1) if whole else (Color(0.5, 0.47, 0.42) if g == 2 else Color(0.6, 0.63, 0.68)))
	var env := a.env
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_cover = null                      # the cloud is the two decks; a painted cover would lie flat behind them
	sky.sky_top_color = Color(str(s.sky))
	sky.sky_horizon_color = Color(str(s.horizon))
	sky.ground_horizon_color = Color(str(s.horizon))
	sky.ground_bottom_color = Color(str(s.fog))
	sky.sky_curve = 0.1
	sky.sun_angle_max = 9.0
	sky.sun_curve = 0.1
	env.fog_light_color = Color(str(s.fog))
	env.fog_density = float(s.fog_d)
	env.ambient_light_color = Color(str(s.amb))
	env.ambient_light_energy = float(s.amb_e)
	env.tonemap_exposure = float(s.exp) * 1.25
	env.adjustment_saturation = float(s.sat)
	env.adjustment_contrast = float(s.con)
	a.sun.light_color = Color(str(s.sun))
	a.sun.light_energy = float(s.sun_e)
	a.sun.rotation_degrees = s.sun_rot
	var fill := a.get_node("HLFill") as DirectionalLight3D
	fill.light_color = Color(str(s.amb)).lerp(Color.WHITE, 0.4)
	fill.light_energy = float(s.fill)
	var sun_dir := _sun_dir(s.sun_rot)
	var wind := Vector2(0.86, 0.5) * float(s.wind)
	for m: ShaderMaterial in st.shared:
		m.set_shader_parameter("grass_a", Color(str(s.grass_a)))
		m.set_shader_parameter("grass_b", Color(str(s.grass_b)))
		m.set_shader_parameter("heather", Color(str(s.heather)))
		m.set_shader_parameter("heather_amt", float(s.heather_amt))
		m.set_shader_parameter("straw", Color(str(s.straw)))
		m.set_shader_parameter("rock_a", Color(str(s.rock_a)))
		m.set_shader_parameter("rock_b", Color(str(s.rock_b)))
		m.set_shader_parameter("earth", Color(str(s.earth)))
		m.set_shader_parameter("snow", float(s.snow))
		m.set_shader_parameter("dry", float(s.dry))
		m.set_shader_parameter("wind", wind)
		m.set_shader_parameter("sun_dir", sun_dir)
		m.set_shader_parameter("sun_mask", _sun_mask(g))
		m.set_shader_parameter("ring_break", 0.0 if whole else 1.0)
		m.set_shader_parameter("cloud_shadow", float(s.cloud_shadow))
	var ground: ShaderMaterial = st.ground
	ground.set_shader_parameter("wear", float(s.wear))
	ground.set_shader_parameter("wet", float(s.wet))
	for m in st.sunlit:
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("sun_dir", sun_dir)
			(m as ShaderMaterial).set_shader_parameter("haze", Color(str(s.haze)))
	for cloud: ShaderMaterial in st.clouds:
		cloud.set_shader_parameter("cover", float(s.cloud) + float(cloud.get_meta("thin", 0.0)))
		cloud.set_shader_parameter("lit", Color(str(s.cloud_lit)))
		cloud.set_shader_parameter("dark", Color(str(s.cloud_dark)))
		cloud.set_shader_parameter("sun_col", Color(str(s.sun)))
		cloud.set_shader_parameter("wind", wind)
	var far: ShaderMaterial = st.far
	far.set_shader_parameter("lit", Color(str(s.far_lit)))
	far.set_shader_parameter("shade", Color(str(s.far_shade)))
	far.set_shader_parameter("rim", Color(str(s.rim)))
	far.set_shader_parameter("snow", float(s.snow))
	var sea: ShaderMaterial = st.sea
	sea.set_shader_parameter("deep", Color(str(s.deep)))
	sea.set_shader_parameter("shelf", Color(str(s.shelf)))
	sea.set_shader_parameter("glint", Color(str(s.sun)))
	var shaft: ShaderMaterial = st.shaft
	shaft.set_shader_parameter("tint", Color(str(s.sun)))
	shaft.set_shader_parameter("strength", float(s.shafts))
	# the citadel's windows: lit while it is lived in, dark after, and the Engine's colour when it wakes
	var windows: StandardMaterial3D = st.windows
	windows.emission = Color("#ffb45a") if whole else Color("#5fe0c8")
	windows.albedo_color = windows.emission if (whole or g == 3) else Color(0.05, 0.05, 0.06)
	windows.emission_energy_multiplier = 2.4 if whole else (3.0 if g == 3 else 0.0)
	(st.seam as StandardMaterial3D).emission_energy_multiplier = float(s.seam)
	# awake, it is seen through any weather
	(st.seam as StandardMaterial3D).disable_fog = float(s.seam) > 1.0
	(st.seam as StandardMaterial3D).albedo_color = Color("#5fe0c8") if float(s.seam) > 1.0 else Color(0.08, 0.1, 0.1)
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

## Cold start: the grid, the road, the mask and the first generation's shadow, so the first scene to use them does
## not pay for them in a cut.
static func warm() -> void:
	_terrain_mesh()
	_road_mask()
	_noise_tex()
	_sun_mask(1)
