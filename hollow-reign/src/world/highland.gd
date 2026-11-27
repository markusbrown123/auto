class_name Highland
extends RefCounted
## The high road: a windswept headland of grass and heather above the sea, a worn path that climbs it in
## switchbacks, and at the top the outer gate of the old capital, the Ring-Gate: one engineered ring of pale ceramic
## taller than anything else in the kingdom, with the towers of the citadel far behind it. The land is natural; what
## is built on it is the work of the Everbound, plate and alloy and light, and the sky is not Earth's.
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
const GATE_YAW := -90.0            # the gate model's doors are on its X side
const GATE_TALL := 14.5            # the whole gate model; its door is about two thirds of that

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
		"rock_a": "#2a2928", "rock_b": "#7e7c78", "earth": "#4a3a26", "wet": 0.5,
		"cloud": 0.5, "cloud_lit": "#fff0d6", "cloud_dark": "#646a84", "cloud_shadow": 0.5,
		"far_lit": "#8c8a7a", "far_shade": "#3c4e6c", "haze": "#a9b0bd", "rim": "#ffdf9c",
		"deep": "#0d2a3a", "shelf": "#2a6c6c", "shafts": 0.2,
		"wind": 1.0, "seam": 0.25, "weather": "", "wear": 1.0, "whole": true},
	{"sky": "#18224a", "horizon": "#d8763c", "fog": "#4c4a60", "fog_d": 0.00045, "sun": "#ff8e4a", "sun_e": 2.6, "sun_rot": Vector3(-7, 208, 0),
		"amb": "#3c4e80", "amb_e": 1.3, "fill": 0.9, "exp": 1.08, "sat": 1.0, "con": 1.14,
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
## The sky in each generation: the colours of the planet, how strongly it and the arc, aurora, stars and falling
## trails show, and the colour of the road's slabs. I serene; II hazy amber, with debris coming down; III cold, the
## orbital structure lit.
const SKY := [
	{"planet": "#ffe6c2", "band": "#a8705c", "planet_e": 1.0, "arc": 1.0, "aurora": 0.16, "stars": 0.5, "trails": 0.0, "slab": "#a6aaa8"},
	{"planet": "#f0b98a", "band": "#9a5a48", "planet_e": 0.75, "arc": 0.5, "aurora": 0.08, "stars": 0.6, "trails": 0.9, "slab": "#7c7772"},
	{"planet": "#d6e2f0", "band": "#8a9cb4", "planet_e": 0.85, "arc": 1.0, "aurora": 0.5, "stars": 0.9, "trails": 0.0, "slab": "#98a0a8"},
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
	var rg := PackedByteArray()          # red: how near the middle of the road; green: where the slab joints fall along it
	rg.resize(w * l * 2)
	var reach := 9
	for s in range(0, _road.size()):
		var c := _road[s]
		# the road is wider where it climbs, and opens out as it reaches the court
		var half := 1.4 + 1.6 * smoothstep(34.0, 8.0, c.y)
		var cx := (c.x - MASK_X0) * MASK_PX
		var cz := (c.y - MASK_Z0) * MASK_PX
		# a joint every three metres of road: a wave that peaks on each joint, so it can be filtered
		var joint := int(255.0 * absf(fposmod(float(s) * 0.5 / 3.0, 1.0) - 0.5) * 2.0)
		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var x := int(cx) + dx
				var z := int(cz) + dz
				if x < 0 or z < 0 or x >= w or z >= l:
					continue
				var d := Vector2(float(x) + 0.5 - cx, float(z) + 0.5 - cz).length() / MASK_PX
				var val := int(255.0 * clampf(1.0 - d / (half * 1.45), 0.0, 1.0))
				if val > px[z * w + x]:
					px[z * w + x] = val
					rg[(z * w + x) * 2] = val
					rg[(z * w + x) * 2 + 1] = joint
	_mask_px = px
	var img := Image.create_from_data(w, l, false, Image.FORMAT_RG8, rg)
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
static var snow_now := 0.0                   # how much snow lies (the generation's), for what a footfall lands on
static var stream: PackedVector2Array = PackedVector2Array()      # the stream's line (HighlandSights), for the same

## What is underfoot at a point: the laid road is stone, the stream shallow water, snow where it lies, turf elsewhere.
static func surface_at(p: Vector3) -> String:
	for q: Vector2 in stream:
		if absf(q.x - p.x) < 1.3 and absf(q.y - p.z) < 1.3:
			return "water"
	if snow_now > 0.4:
		return "snow"
	return "stone" if on_road(p.x, p.z) > 0.3 else "grass"

static func off_sights() -> bool:
	return HighlandSights.off

static func build(a: Arena) -> void:
	_ensure()
	var st := {"kept": [], "ruin": [], "woken": [], "fires": [], "shared": [], "sunlit": [], "lamps": [], "lights": []}
	# the arena's square of paving becomes the round pad at the gate, in the makers' own plate
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
			(c as MeshInstance3D).material_override = built(Color("#aeb2b0"), 0.2, 0.5, 0.16)
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
	_sky(a, st)
	_ranges(a, st)
	_shafts(a, st)
	_grass(a, st)
	_rocks(a, st)
	st["seam"] = _ring(a, st)
	_citadel(a, st)
	_gate_court(a, st)
	_wayside(a, st)
	HighlandSights.build(a, st)
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
		crest.fractal_octaves = 2
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
				var ridged := 1.0 - absf(crest.get_noise_2d(az * 1.5, float(layer[5])))
				var top := float(layer[2]) * env * (0.3 + 0.7 * ridged * ridged) * (0.75 + 0.5 * crest.get_noise_2d(az * 0.9 + 10.0, float(layer[5])))
				var dir := Vector3(sin(az), 0, -cos(az))
				var wob := crest.get_noise_2d(az * 4.0, float(layer[5]) + 5.0)
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

# ================================================================ what was built here
# Nothing on this road is masonry. The people who made the Ring-Gate worked in pale ceramic and alloy, cut to the
# millimetre and laid in panels; what they built is still square where it stands. These are the materials and the
# few shapes all of it is made from.

## Panel lines: a sheet cut into rectangular plates, each a slightly different tone, with a groove between them.
## Returns [albedo, normal].
static func _panels() -> Array:
	if Look._cache.has("highland_panels"):
		return Look._cache["highland_panels"]
	var size := 256
	var tone := Image.create(size, size, false, Image.FORMAT_RGB8)
	var high := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var todo: Array = [Rect2i(0, 0, size, size)]
	while not todo.is_empty():
		var r: Rect2i = todo.pop_back()
		var big := maxi(r.size.x, r.size.y)
		if big > 96 or (big > 40 and rng.randf() < 0.6):
			if r.size.x >= r.size.y:
				var cut := int(r.size.x * rng.randf_range(0.35, 0.65))
				todo.append(Rect2i(r.position, Vector2i(cut, r.size.y)))
				todo.append(Rect2i(r.position + Vector2i(cut, 0), Vector2i(r.size.x - cut, r.size.y)))
			else:
				var cut2 := int(r.size.y * rng.randf_range(0.35, 0.65))
				todo.append(Rect2i(r.position, Vector2i(r.size.x, cut2)))
				todo.append(Rect2i(r.position + Vector2i(0, cut2), Vector2i(r.size.x, r.size.y - cut2)))
			continue
		var v := rng.randf_range(0.8, 1.0)
		tone.fill_rect(r, Color(v, v, v))
		high.fill_rect(r, Color(1, 1, 1))
		# the groove along two sides of every plate (its neighbours draw the other two; the sheet tiles)
		tone.fill_rect(Rect2i(r.position, Vector2i(r.size.x, 2)), Color(0.42, 0.42, 0.42))
		tone.fill_rect(Rect2i(r.position, Vector2i(2, r.size.y)), Color(0.42, 0.42, 0.42))
		high.fill_rect(Rect2i(r.position, Vector2i(r.size.x, 2)), Color(0, 0, 0))
		high.fill_rect(Rect2i(r.position, Vector2i(2, r.size.y)), Color(0, 0, 0))
	high.bump_map_to_normal_map(3.0)
	tone.generate_mipmaps()
	high.generate_mipmaps()
	var out := [ImageTexture.create_from_image(tone), ImageTexture.create_from_image(high)]
	Look._cache["highland_panels"] = out
	return out

## A built surface: `metal` 0 is matte ceramic, towards 1 brushed alloy. `scale` is panel sheets a metre.
static func built(tint: Color, metal: float, rough: float, scale: float, far: bool = false) -> StandardMaterial3D:
	var key := "hlbuilt%s%.2f%.2f%.3f%s" % [tint.to_html(), metal, rough, scale, far]
	if Look._cache.has(key):
		return Look._cache[key]
	var tex := _panels()
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = tex[0]
	m.normal_enabled = true
	m.normal_texture = tex[1]
	m.normal_scale = 0.8
	m.metallic = metal
	m.metallic_specular = 0.45
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.disable_fog = far               # the landmarks are drawn by their own light and shadow, not by the haze
	Look._cache[key] = m
	return m

## A light that is part of a structure. Each call is its own material, so a generation can turn it down or recolour it.
static func _lamp(c: Color, energy: float) -> StandardMaterial3D:
	var m := Look.glow(c, energy)
	m.disable_fog = true
	return m

## A length of ring: `section` (radial offset, depth) swept from angle a0 to a1 at radius r about the origin, in the
## ring's own plane (angle 0 is the foot, as everywhere here). `at_mid` moves it so its middle is the origin (for a
## piece that has come off and lies on the ground).
static func _arc(sf: SurfaceTool, r: float, a0: float, a1: float, section: PackedVector2Array, steps: int, at_mid: bool = false) -> void:
	var mid := Vector3(sin((a0 + a1) * 0.5), -cos((a0 + a1) * 0.5), 0) * r if at_mid else Vector3.ZERO
	var n := section.size()
	var rings: Array = []
	for s in steps + 1:
		var ang := lerpf(a0, a1, float(s) / float(steps))
		var out := Vector3(sin(ang), -cos(ang), 0)
		var ring := PackedVector3Array()
		for p: Vector2 in section:
			ring.append(out * (r + p.x) + Vector3(0, 0, p.y) - mid)
		rings.append(ring)
	var centres: Array = []
	for s in steps + 1:
		var ang2 := lerpf(a0, a1, float(s) / float(steps))
		centres.append(Vector3(sin(ang2), -cos(ang2), 0) * r - mid)
	for s in steps:
		var p0: PackedVector3Array = rings[s]
		var p1: PackedVector3Array = rings[s + 1]
		var mid_line: Vector3 = ((centres[s] as Vector3) + (centres[s + 1] as Vector3)) * 0.5
		for k in n:
			var k2 := (k + 1) % n
			var away := (p0[k] + p1[k2]) * 0.5 - mid_line
			_tri(sf, p0[k], p1[k], p1[k2], away)
			_tri(sf, p0[k], p1[k2], p0[k2], away)
	# the two cut ends
	var along: Vector3 = (centres[steps] as Vector3) - (centres[0] as Vector3)
	for e: Array in [[rings[0], -along], [rings[steps], along]]:
		var ring2: PackedVector3Array = e[0]
		for k in range(1, n - 1):
			_tri(sf, ring2[0], ring2[k], ring2[k + 1], e[1])

## One flat triangle, wound and given its normal so that it faces `away`.
static func _tri(sf: SurfaceTool, p: Vector3, q: Vector3, r: Vector3, away: Vector3) -> void:
	var nrm := (q - p).cross(r - p).normalized()
	if nrm.dot(away) < 0.0:
		var t := q
		q = r
		r = t
		nrm = -nrm
	for v: Vector3 in [p, r, q]:
		sf.set_normal(nrm)
		sf.add_vertex(v)

static func _commit(parent: Node3D, node_name: String, sf: SurfaceTool, mat: Material, shadows: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = sf.commit()
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _flat_tool() -> SurfaceTool:
	var sf := SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	return sf

## A tapered prism standing on `at` (a tower's tier, a mast, a pylon): `sides` faces, `r0` at the foot, `r1` at the top.
static func _prism(sf: SurfaceTool, at: Vector3, r0: float, r1: float, h: float, sides: int = 6, turn: float = 0.0, squash: Vector3 = Vector3.ONE) -> void:
	var c := CylinderMesh.new()
	c.bottom_radius = r0
	c.top_radius = r1
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	sf.append_from(c, 0, Transform3D(Basis(Vector3.UP, turn).scaled(squash), at + Vector3(0, h * 0.5, 0)))

## A slender member from one point to another (a strut, a stay, a span).
static func _beam(sf: SurfaceTool, from: Vector3, to: Vector3, w: float, d: float = -1.0) -> void:
	var b := BoxMesh.new()
	b.size = Vector3(w, from.distance_to(to), d if d > 0.0 else w)
	sf.append_from(b, 0, Transform3D(Basis(Quaternion(Vector3.UP, (to - from).normalized())), (from + to) * 0.5))

# ================================================================ the Ring-Gate
const RING_SEGS := 24
const RING_SECTION := [Vector2(-5.0, -2.3), Vector2(-5.0, 2.3), Vector2(-3.7, 3.6), Vector2(3.7, 3.6), Vector2(5.0, 2.3), Vector2(5.0, -2.3), Vector2(3.7, -3.6), Vector2(-3.7, -3.6)]

## Whether a segment of the ring is one of those that come down between the first generation and the second.
static func _in_break(i: int) -> bool:
	var ang := TAU * (float(i) + 0.5) / RING_SEGS
	return ang > BREAK_FROM and ang < BREAK_TO

## The Ring-Gate: one engineered ring of pale ceramic in twenty-four segments, a seam between each, a channel of
## light let into its inner face, slim fins cantilevered off its rim, plates that hang in the air over its crown,
## and stays running down to the rock on either side. Two segments of it are gone by the second generation.
## Returns the channel's light.
static func _ring(a: Arena, st: Dictionary) -> StandardMaterial3D:
	var shell := built(Color("#cfd2cf"), 0.15, 0.5, 0.05, true)
	var dark := built(Color("#4a5058"), 0.6, 0.45, 0.1, true)
	var section := PackedVector2Array(RING_SECTION)
	var channel := PackedVector2Array([Vector2(-5.25, -1.0), Vector2(-5.25, 1.0), Vector2(-4.95, 1.0), Vector2(-4.95, -1.0)])
	var gap := deg_to_rad(0.55)
	var whole := _flat_tool()
	var arc := _flat_tool()
	var light := _flat_tool()
	var arc_light := _flat_tool()
	var core := _flat_tool()
	var fins: Array = []
	var arc_fins: Array = []
	var fin := BoxMesh.new()
	fin.size = Vector3(0.5, 6.5, 2.4)
	for i in RING_SEGS:
		var a0 := TAU * float(i) / RING_SEGS + gap
		var a1 := TAU * float(i + 1) / RING_SEGS - gap
		var gone := _in_break(i)
		_arc(arc if gone else whole, RING_R, a0, a1, section, 6)
		_arc(arc_light if gone else light, RING_R, a0 + gap, a1 - gap, channel, 6)
		var ang := (a0 + a1) * 0.5
		if cos(ang) < 0.55:          # none underground
			(arc_fins if gone else fins).append(Transform3D(Basis(Vector3(0, 0, 1), ang), RING_C + Vector3(sin(ang), -cos(ang), 0) * (RING_R + 7.2)))
	# a darker spine shows in the seams, so the ring reads as plates on a frame rather than a row of blocks
	_arc(core, RING_R, 0.0, BREAK_FROM - 0.08, PackedVector2Array([Vector2(-3.6, -2.6), Vector2(-3.6, 2.6), Vector2(3.6, 2.6), Vector2(3.6, -2.6)]), 40)
	_arc(core, RING_R, BREAK_TO + 0.08, TAU, PackedVector2Array([Vector2(-3.6, -2.6), Vector2(-3.6, 2.6), Vector2(3.6, 2.6), Vector2(3.6, -2.6)]), 60)
	var seam := _lamp(Color("#5fe0c8"), 0.5)
	for e: Array in [["HLRing", whole, shell, true], ["HLRingArc", arc, shell, true], ["HLRingCore", core, dark, false], ["HLSeam", light, seam, false], ["HLSeamArc", arc_light, seam, false]]:
		_commit(a, e[0], e[1], e[2], e[3]).position = RING_C
	_batch(a, "HLRingFins", fin, fins, dark, false)
	st.kept.append(_batch(a, "HLRingFinsArc", fin, arc_fins, dark, false))
	# what came down lies east of the court, where the ground breaks toward the cliff
	var piece := _flat_tool()
	_arc(piece, RING_R, 0.0, TAU / RING_SEGS - gap * 2.0, section, 6, true)
	var fallen: Array = []
	for f: Array in [[40.0, -10.0, 0.5, 0.25], [50.0, 6.0, 1.9, -0.35]]:
		fallen.append(Transform3D(Basis.from_euler(Vector3(PI * 0.5 + float(f[3]), float(f[2]), float(f[3]) * 0.6)), on_ground(float(f[0]), float(f[1]), 2.0)))
	_batch(a, "HLRingFallen", piece.commit(), fallen, shell, true)
	# stays, feet, and the plates over the crown
	var frame := _flat_tool()
	var pale := _flat_tool()
	var lit := _flat_tool()
	for sx: float in [-1.0, 1.0]:
		# each foot goes into an angled housing rather than the ground
		var foot := on_ground(sx * 35.0, RING_C.z)
		for b: Array in [[Vector3(22.0, 6.0, 15.0), 2.0, 0.0], [Vector3(17.0, 6.0, 12.5), 7.0, 9.0], [Vector3(12.0, 6.0, 10.5), 12.0, 17.0]]:
			var box := BoxMesh.new()
			box.size = b[0]
			frame.append_from(box, 0, Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(float(b[2]) * sx)), foot + Vector3(sx * float(b[2]) * 0.12, float(b[1]), 0)))
		for k in 3:
			_beam(lit, foot + Vector3(sx * -9.0 + sx * k * 7.0, 1.0, 7.7), foot + Vector3(sx * -7.0 + sx * k * 6.0, 13.5, 6.6), 0.35, 0.2)
		# two stays to each flank, one before the ring and one behind
		for stay: Array in [[1.35, 74.0, 16.0], [1.35, 78.0, -22.0], [2.15, 96.0, -10.0]]:
			var ang := float(stay[0]) * sx
			var on_ring := RING_C + Vector3(sin(ang), -cos(ang), 0) * (RING_R + 4.0)
			_beam(frame, on_ground(sx * float(stay[1]), RING_C.z + float(stay[2]), -1.0), on_ring, 1.1)
	for k in 7:
		# plates that hold station over the crown: nothing joins them to it
		var ang2 := PI + (k - 3) * 0.14
		var out := Vector3(sin(ang2), -cos(ang2), 0)
		var slab := BoxMesh.new()
		slab.size = Vector3(5.2 - absf(k - 3) * 0.6, 1.1, 4.0)
		pale.append_from(slab, 0, Transform3D(Basis(Vector3(0, 0, 1), ang2), RING_C + out * (RING_R + 12.5 - absf(k - 3) * 0.9)))
	_commit(a, "HLRingFrame", frame, dark, true)
	st.kept.append(_commit(a, "HLRingHalo", pale, shell, false))
	var foot_light := _lamp(Color("#ffc27a"), 2.2)
	_commit(a, "HLRingFootLights", lit, foot_light, false)
	st.lamps.append([foot_light, Color("#ffc27a"), 2.2])
	return seam

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

## Many boxes as one mesh: [size, where, rotation in degrees] each. One draw for a whole structure.
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
## The citadel, far behind the gate and seen through it: not a keep but a stand of towers, each a clean taper in
## three setbacks with lines of light up its faces, thin spans between them, on a terraced base. Lit and whole in the
## first generation; by the second the tallest has lost its head and stands in a gantry.
static func _citadel(a: Arena, st: Dictionary) -> void:
	var m := built(Color("#b9bdbd"), 0.2, 0.5, 0.012, true)
	var root := Node3D.new()
	root.name = "HLCitadel"
	root.position = Vector3(6.0, 34.0, -330.0)
	a.add_child(root)
	var body := _flat_tool()
	var head := _flat_tool()
	var lit := _flat_tool()
	var holo := _flat_tool()
	var gantry := _flat_tool()
	# [x, z, height, foot radius]
	var towers: Array = [[-66.0, 4.0, 118.0, 13.0], [-27.0, -6.0, 176.0, 16.0], [2.0, -24.0, 104.0, 12.0], [29.0, 6.0, 212.0, 17.0], [68.0, -2.0, 128.0, 13.0], [104.0, 10.0, 70.0, 10.0], [-104.0, 12.0, 62.0, 10.0]]
	for ti in towers.size():
		var t: Array = towers[ti]
		var c := Vector3(float(t[0]), 0, float(t[1]))
		var h := float(t[2])
		var r := float(t[3])
		var y := 0.0
		for k in 3:
			var hh: float = h * float([0.46, 0.32, 0.22][k])
			var r0: float = r * float([1.0, 0.7, 0.44][k])
			var r1: float = r * float([0.78, 0.5, 0.2][k])
			var into: SurfaceTool = head if ti == 3 and k >= 1 else body
			_prism(into, c + Vector3(0, y, 0), r0, r1, hh, 6, 0.26)
			# a collar where each tier sets back
			_prism(into, c + Vector3(0, y + hh - 1.2, 0), r1 * 1.12, r1 * 1.12, 1.6, 6, 0.26)
			# lines of light up the faces that look down the road
			for face: float in [-1.0, 0.0, 1.0]:
				var rr: float = (r0 + r1) * 0.5 * 0.9
				var where := c + Vector3(sin(face * 1.05) * rr, y + hh * 0.5, cos(face * 1.05) * rr)
				var strip := BoxMesh.new()
				strip.size = Vector3(0.7, hh * (0.62 if face == 0.0 else 0.4), 0.5)
				(lit if not (ti == 3 and k >= 1) else holo).append_from(strip, 0, Transform3D(Basis(Vector3.UP, face * 1.05), where))
			y += hh
		_prism(head if ti == 3 else body, c + Vector3(0, y, 0), 1.2, 0.15, h * 0.16, 4)
	# thin spans from tower to tower
	for sp: Array in [[0, 1, 70.0], [1, 3, 98.0], [3, 4, 84.0], [1, 2, 52.0], [2, 3, 60.0]]:
		var p0 := Vector3(float(towers[sp[0]][0]), float(sp[2]), float(towers[sp[0]][1]))
		var p1 := Vector3(float(towers[sp[1]][0]), float(sp[2]) + 4.0, float(towers[sp[1]][1]))
		_beam(body, p0, p1, 2.2, 1.2)
	# the terraces it stands on
	_prism(body, Vector3(0, -24.0, 14.0), 150.0, 128.0, 16.0, 8, 0.39, Vector3(1.0, 1.0, 0.36))
	_prism(body, Vector3(0, -8.0, 6.0), 118.0, 100.0, 12.0, 8, 0.39, Vector3(1.0, 1.0, 0.34))
	_prism(body, Vector3(0, -40.0, 24.0), 190.0, 170.0, 18.0, 8, 0.39, Vector3(1.0, 1.0, 0.36))
	for k in 9:
		var strip2 := BoxMesh.new()
		strip2.size = Vector3(14.0, 0.8, 0.5)
		lit.append_from(strip2, 0, Transform3D(Basis.IDENTITY, Vector3(-96.0 + k * 24.0, -2.0, 41.5)))
	# the gantry up the tower that lost its head
	var east := Vector3(29.0, 0, 6.0)
	for k in 5:
		_beam(gantry, east + Vector3(-11.0 + k * 5.5, 86.0, 11.0), east + Vector3(-10.0 + k * 5.0, 150.0, 8.0), 1.0)
	for k in 5:
		_beam(gantry, east + Vector3(-13.0, 96.0 + k * 12.0, 10.5), east + Vector3(13.0, 98.0 + k * 12.0, 9.5), 0.9)
	_commit(root, "Stone", body, m, false)
	st.kept.append(_commit(root, "Head", head, m, false))
	st.ruin.append(_commit(root, "Scaffold", gantry, Look.flat(Color("#1d2126"), 0.8, 0.4), false))
	var windows := _lamp(Color("#ffb45a"), 2.4)
	_commit(root, "Windows", lit, windows, false)
	st.kept.append(_commit(root, "HeadLights", holo, windows, false))
	st["windows"] = windows

# ================================================================ the gate court
## Where the gate itself stands (a generated model can take the place of the built door: see _gate_court).
const GATE_FRONT := 6.2            # how far in front of the gate model's middle its door face is
const DOOR_W := 9.6
const DOOR_H := 11.6

## The court between the ring's feet: an engineered forecourt. A blast door twelve metres high with a seam of light
## down the middle of it, in a frame of two leaning pylons; bulkhead walls running out from it to the ring's feet,
## with sentry alcoves let into them; lamps on slim posts; pennants of light on masts; a landing ring inlaid in the
## floor. Kept and shut in the first generation. Breached and overgrown in the second: a leaf of the door hangs off
## true, plates are down, ivy is up the wall. In the third the seam and the inlay are alight again.
static func _gate_court(a: Arena, st: Dictionary) -> void:
	var wall := built(Color("#565c64"), 0.55, 0.5, 0.14)
	var pale := built(Color("#c4c8c6"), 0.12, 0.55, 0.1)
	var black := Look.flat(Color("#0c0e10"), 0.9)
	var gate := Node3D.new()
	gate.name = "HLGate"
	gate.position = GATE_AT
	a.add_child(gate)
	st["gatehouse"] = gate
	# the gate itself: the generated model (a ceramic bulkhead with its blast door, alcoves and masts), or, without it,
	# the frame and two leaves built here in the same language
	var model := a.prop("road_gate_future", GATE_TALL, GATE_AT + Vector3(0, -0.15, 0), GATE_YAW)
	st["gate_model"] = model
	_shadowed(model)
	var front := 2.2 if model == null else GATE_FRONT
	var leaves: Array = []
	var frame := _flat_tool()
	var trim := _flat_tool()
	var dark := _flat_tool()
	var lamps := _flat_tool()
	if model == null:
		# the frame: two pylons leaning in over the door, a head across them, a hood above that
		for sx: float in [-1.0, 1.0]:
			var py := BoxMesh.new()
			py.size = Vector3(3.4, 15.5, 5.0)
			frame.append_from(py, 0, Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(sx * 5.0)), Vector3(sx * 7.3, 7.6, 0)))
			var cap := BoxMesh.new()
			cap.size = Vector3(4.2, 1.0, 5.6)
			trim.append_from(cap, 0, Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(sx * 5.0)), Vector3(sx * 6.65, 15.6, 0)))
			for k in 4:
				_beam(lamps, Vector3(sx * 8.95 - sx * k * 0.06, 2.0 + k * 3.2, front + 0.35), Vector3(sx * 8.8 - sx * k * 0.06, 4.2 + k * 3.2, front + 0.35), 0.16, 0.1)
			# sentry alcoves either side of the door: a dark recess, a sill, a light in its head
			var recess := BoxMesh.new()
			recess.size = Vector3(1.5, 3.4, 0.5)
			dark.append_from(recess, 0, Transform3D(Basis.IDENTITY, Vector3(sx * 7.3, 2.5, front + 0.3)))
			var sill := BoxMesh.new()
			sill.size = Vector3(1.9, 0.25, 0.9)
			trim.append_from(sill, 0, Transform3D(Basis.IDENTITY, Vector3(sx * 7.3, 0.7, front + 0.4)))
			_beam(lamps, Vector3(sx * 6.7, 4.25, front + 0.5), Vector3(sx * 7.9, 4.25, front + 0.5), 0.12)
		var head := BoxMesh.new()
		head.size = Vector3(12.4, 2.6, 5.2)
		frame.append_from(head, 0, Transform3D(Basis.IDENTITY, Vector3(0, 13.1, 0)))
		var hood := BoxMesh.new()
		hood.size = Vector3(15.5, 0.7, 7.0)
		trim.append_from(hood, 0, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(8.0)), Vector3(0, 15.2, 0.8)))
		_beam(lamps, Vector3(-5.6, 12.1, front + 0.45), Vector3(5.6, 12.1, front + 0.45), 0.18, 0.1)
		_commit(gate, "Frame", frame, wall, true)
		_commit(gate, "Trim", trim, pale, true)
		_commit(gate, "Recess", dark, black, false)
		if true:
			for sx: float in [-1.0, 1.0]:
				var leaf := Node3D.new()
				leaf.name = "Leaf" + ("L" if sx < 0.0 else "R")
				leaf.position = Vector3(sx * DOOR_W * 0.5, 0, front - 0.4)       # hinged, so to speak, at its outer edge
				gate.add_child(leaf)
				var lf := _flat_tool()
				var lt := _flat_tool()
				var slab := BoxMesh.new()
				slab.size = Vector3(DOOR_W * 0.5 - 0.12, DOOR_H, 0.9)
				lf.append_from(slab, 0, Transform3D(Basis.IDENTITY, Vector3(-sx * DOOR_W * 0.25, DOOR_H * 0.5, 0)))
				for k in 4:
					# raised plates, and between them the rails the leaf runs on
					var plate := BoxMesh.new()
					plate.size = Vector3(DOOR_W * 0.5 - 1.1, 2.1, 0.3)
					lt.append_from(plate, 0, Transform3D(Basis.IDENTITY, Vector3(-sx * DOOR_W * 0.25 + sx * 0.2, 1.7 + k * 2.75, 0.5)))
				var edge := BoxMesh.new()
				edge.size = Vector3(0.5, DOOR_H - 0.6, 1.2)
				lf.append_from(edge, 0, Transform3D(Basis.IDENTITY, Vector3(-sx * (DOOR_W * 0.5 - 0.42), DOOR_H * 0.5, 0)))
				_commit(leaf, "Slab", lf, built(Color("#3c4148"), 0.6, 0.45, 0.16), true)
				_commit(leaf, "Plates", lt, wall, false)
				leaves.append(leaf)
		st["leaves"] = leaves
	# bulkheads from the door out to the ring's feet: leaning plates, a rib between each, a line of light along the top
	var bulk := _flat_tool()
	var rib := _flat_tool()
	for sx: float in [-1.0, 1.0]:
		for k in 4:
			var x0 := (9.2 if model == null else 10.4) + k * 5.6
			var hgt := 10.0 - k * 0.9
			var base := on_ground(sx * (x0 + 2.8), GATE_AT.z - 0.8 - k * 0.5)
			var plate2 := BoxMesh.new()
			plate2.size = Vector3(5.5, hgt + 2.0, 1.6)
			bulk.append_from(plate2, 0, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-7.0)), Vector3(base.x, base.y + hgt * 0.5 - 1.0, base.z) - GATE_AT))
			var fin := BoxMesh.new()
			fin.size = Vector3(0.7, hgt + 2.6, 3.0)
			rib.append_from(fin, 0, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-12.0)), Vector3(sx * (x0 + 5.6), base.y + hgt * 0.5 - 1.0, base.z + 0.9) - GATE_AT))
			_beam(lamps, Vector3(sx * (x0 + 0.3), base.y + hgt - 0.2, base.z + 1.6) - GATE_AT, Vector3(sx * (x0 + 5.2), base.y + hgt - 0.2, base.z + 1.6) - GATE_AT, 0.14, 0.1)
			if k == 1:
				var recess2 := BoxMesh.new()
				recess2.size = Vector3(1.6, 3.2, 0.5)
				dark.append_from(recess2, 0, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-7.0)), Vector3(base.x, base.y + 2.2, base.z + 1.2) - GATE_AT))
	_commit(gate, "Bulkhead", bulk, wall, true)
	_commit(gate, "Ribs", rib, pale, true)
	_commit(gate, "Recess2", dark, black, false)
	var gate_light := _lamp(Color("#ffc27a"), 2.0)
	_commit(gate, "Lines", lamps, gate_light, false)
	st.lamps.append([gate_light, Color("#ffc27a"), 2.0])
	# the seam down the middle of the door: what the door is for
	var seam := _lamp(Color("#ffb060"), 1.6)
	var seam_h := DOOR_H - 0.5 if model == null else GATE_TALL * 0.6
	var seam_mi := a.box(Vector3(0.26, seam_h, 0.3), GATE_AT + Vector3(0, seam_h * 0.5 + 0.2, front + 0.15), seam)
	seam_mi.name = "HLGateSeam"
	seam_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	st["gate_seam"] = seam
	var seam_glow := OmniLight3D.new()
	seam_glow.name = "HLGateGlow"
	seam_glow.omni_range = 18.0
	seam_glow.position = GATE_AT + Vector3(0, 3.5, front + 4.0)
	a.add_child(seam_glow)
	st["gate_glow"] = seam_glow
	# lamps on posts down the approach, and pennants of light on masts behind them
	var posts := _flat_tool()
	var heads := _flat_tool()
	var pennants := _flat_tool()
	for sx: float in [-1.0, 1.0]:
		for b: Array in [[4.6, -8.5], [4.6, 3.0]]:
			var at := Vector3(sx * float(b[0]), 0, float(b[1]))
			_prism(posts, at, 0.16, 0.09, 2.5, 6)
			_prism(heads, at + Vector3(0, 2.5, 0), 0.2, 0.2, 0.34, 6)
			var l := OmniLight3D.new()
			l.omni_range = 10.0
			l.omni_attenuation = 1.3
			l.position = at + Vector3(0, 2.8, 0)
			a.add_child(l)
			st.lights.append([l, 1.8])
		for b: Array in [[9.0, -11.5], [11.2, -2.5], [12.4, 6.5]]:
			var at2 := Vector3(sx * float(b[0]), 0, float(b[1]))
			_prism(posts, at2, 0.14, 0.05, 8.2, 6)
			var card := BoxMesh.new()
			card.size = Vector3(0.6, 2.6, 0.02)
			pennants.append_from(card, 0, Transform3D(Basis(Vector3.UP, sx * -0.3), at2 + Vector3(sx * -0.55, 6.0, 0)))
	_commit(a, "HLPosts", posts, wall, true)
	var post_light := _lamp(Color("#ffd9a0"), 3.0)
	_commit(a, "HLPostLights", heads, post_light, false)
	st.lamps.append([post_light, Color("#ffd9a0"), 3.0])
	st.kept.append(_commit(a, "HLPennants", pennants, _pennant_mat(), false))
	# the landing ring let into the floor, and its four marks
	var inlay := _flat_tool()
	_arc(inlay, 8.6, 0.0, TAU, PackedVector2Array([Vector2(-0.14, -0.02), Vector2(-0.14, 0.02), Vector2(0.14, 0.02), Vector2(0.14, -0.02)]), 48)
	var pad := _lamp(Color("#ffb060"), 1.2)
	var pad_mi := _commit(a, "HLPad", inlay, pad, false)
	pad_mi.rotation.x = PI * 0.5
	pad_mi.position = Vector3(0, 0.035, -4.0)
	var marks := _flat_tool()
	for k in 4:
		var ang := PI * 0.25 + k * PI * 0.5
		var mk := BoxMesh.new()
		mk.size = Vector3(0.3, 0.03, 2.6)
		marks.append_from(mk, 0, Transform3D(Basis(Vector3.UP, ang), Vector3(sin(ang) * 10.4, 0.04, -4.0 + cos(ang) * 10.4)))
	_commit(a, "HLPadMarks", marks, pad, false)
	st["pad"] = pad
	# the years: plates off the wall, lying where they fell, and ivy up what still stands
	var down := _flat_tool()
	for r: Array in [[15.5, -15.0, 5.0, 3.4, 24.0, 8.0], [19.0, -9.0, 4.2, 5.2, 70.0, -5.0], [-12.5, -14.0, 5.2, 4.0, 150.0, 6.0], [-8.5, 7.5, 2.6, 1.8, 200.0, 12.0], [6.5, -15.5, 3.0, 2.2, 300.0, -9.0]]:
		var pl := BoxMesh.new()
		pl.size = Vector3(float(r[2]), 0.5, float(r[3]))
		down.append_from(pl, 0, Transform3D(Basis.from_euler(Vector3(deg_to_rad(float(r[5])), deg_to_rad(float(r[4])), deg_to_rad(float(r[5]) * 0.6))), on_ground(float(r[0]), float(r[1]), 0.3)))
	st.ruin.append(_commit(a, "HLDown", down, wall, true))
	st.ruin.append(_ivy(a))

## A pennant of light: a flat card that glows and is seen through.
static func _pennant_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.36, 0.2, 0.4)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.emission_enabled = true
	m.emission = Color("#ff4a30")
	m.emission_energy_multiplier = 1.6
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	return m

## Ivy up the bulkheads either side of the door: leaf cards in one batch, thick at the foot and thinning as it climbs.
static func _ivy(a: Arena) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.9, 0.9)
	var xf: Array = []
	for stem in 16:
		var x := rng.randf_range(5.6, 26.0) * (1.0 if stem % 2 == 0 else -1.0)
		var top := rng.randf_range(3.0, 9.5)
		var y := 0.0
		while y < top:
			x += rng.randf_range(-0.35, 0.35)
			var sc := lerpf(1.3, 0.6, y / top) * rng.randf_range(0.7, 1.3)
			var lean := 0.8 - y * 0.123 if absf(x) > 9.0 else 2.75
			xf.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.5, 0.5), rng.randf() * TAU)).scaled(Vector3.ONE * sc),
				GATE_AT + Vector3(x, y + 0.2, lean + rng.randf_range(0.0, 0.25))))
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
## What stands beside the road: marker pylons in pairs with a light in the head of each, a slim gantry where the
## climb ends, signal masts with pennants of light on the last stretch, a conduit lying along the verge, and what
## the makers left in the turf: lengths of great pipe, a hoop off some machine, a sensor dome the size of a house.
## And the dead tree, which nobody made.
static func _wayside(a: Arena, st: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1909
	var alloy := built(Color("#7c838a"), 0.55, 0.45, 0.35)
	var worn := built(Color("#6c7068"), 0.35, 0.7, 0.2)
	var pale := built(Color("#c4c8c6"), 0.12, 0.55, 0.2)
	# marker pylons: one each side, every fifty metres or so; a few have been knocked short
	var body := _flat_tool()
	var caps := _flat_tool()
	var s := 44.0
	var k := 0
	while s < road_length() - 30.0:
		for side: float in [-1.0, 1.0]:
			if rng.randf() < 0.2:
				continue
			var p := road(s + rng.randf_range(-1.0, 1.0), side * rng.randf_range(2.6, 3.0)) - Vector3(0, 0.1, 0)
			var tall := 1.5 if rng.randf() < 0.8 else 0.6
			_prism(body, p, 0.17, 0.11, tall, 4, road_yaw(s) + PI * 0.25)
			if tall > 1.0:
				_prism(caps, p + Vector3(0, tall, 0), 0.12, 0.12, 0.14, 4, road_yaw(s) + PI * 0.25)
		s += 52.0 if k % 2 == 0 else 44.0
		k += 1
	# the gantry at the head of the climb: two masts and a thin span, lights along it
	var sa := road_at_z(126.0)
	var g0 := road(sa, -3.6)
	var g1 := road(sa, 3.6)
	_prism(body, g0 - Vector3(0, 0.3, 0), 0.34, 0.16, 7.4, 6)
	_prism(body, g1 - Vector3(0, 0.3, 0), 0.34, 0.16, 6.8, 6)
	_beam(body, g0 + Vector3(0, 6.6, 0), g1 + Vector3(0, 6.2, 0), 0.3, 0.5)
	for t: float in [0.25, 0.5, 0.75]:
		var lp := (g0 + Vector3(0, 6.3, 0)).lerp(g1 + Vector3(0, 5.9, 0), t)
		_beam(caps, lp - Vector3(0, 0.12, 0), lp + Vector3(0, 0.12, 0), 0.3)
	# signal masts on the last stretch, kept while the road is
	var pennants := _flat_tool()
	for b: Array in [[44.0, 3.4], [31.0, -3.6], [58.0, 3.8], [72.0, -3.8]]:
		var sm := road_at_z(float(b[0]))
		var at := road(sm, float(b[1])) - Vector3(0, 0.2, 0)
		_prism(body, at, 0.13, 0.05, 6.4, 6)
		var card := BoxMesh.new()
		card.size = Vector3(0.55, 2.2, 0.02)
		pennants.append_from(card, 0, Transform3D(Basis(Vector3.UP, road_yaw(sm) + PI * 0.5), at + Vector3(0, 4.7, 0) + Basis(Vector3.UP, road_yaw(sm)) * Vector3(0.5 * signf(float(b[1])) * -1.0, 0, 0)))
	_commit(a, "HLMarkers", body, alloy, true)
	var marker := _lamp(Color("#9ff0e0"), 2.2)
	_commit(a, "HLMarkerLights", caps, marker, false)
	st.lamps.append([marker, Color("#9ff0e0"), 2.2])
	st.kept.append(_commit(a, "HLSignal", pennants, _pennant_mat(), false))
	# a conduit along the verge for two stretches of the road, half in the turf
	var pipe := _flat_tool()
	for stretch: Array in [[36.0, 150.0, -2.3], [300.0, 372.0, 2.4], [420.0, 500.0, -2.4]]:
		var d := float(stretch[0])
		while d < float(stretch[1]):
			var p0 := road(d, float(stretch[2])) + Vector3(0, 0.03, 0)
			var p1 := road(d + 3.0, float(stretch[2])) + Vector3(0, 0.03, 0)
			var seg := CylinderMesh.new()
			seg.top_radius = 0.13
			seg.bottom_radius = 0.13
			seg.height = p0.distance_to(p1) + 0.05
			seg.radial_segments = 6
			seg.rings = 1
			pipe.append_from(seg, 0, Transform3D(Basis(Quaternion(Vector3.UP, (p1 - p0).normalized())), (p0 + p1) * 0.5))
			if int(d) % 12 == 0:
				_prism(pipe, p0 - Vector3(0, 0.1, 0), 0.24, 0.24, 0.34, 6)
			d += 3.0
	_commit(a, "HLConduit", pipe, worn, false)
	# what was left in the turf
	var junk := _flat_tool()
	var junk_pale := _flat_tool()
	# lengths of great pipe, lying half under
	for pp: Array in [[86.0, 13.0, 0.5, 2.0, 16.0], [352.0, -16.0, 1.3, 1.5, 12.0], [246.0, 30.0, 2.2, 2.4, 20.0], [455.0, 18.0, 0.2, 1.7, 14.0]]:
		var c := road(float(pp[0]), float(pp[1]))
		var tube := CylinderMesh.new()
		tube.top_radius = float(pp[3])
		tube.bottom_radius = float(pp[3])
		tube.height = float(pp[4])
		tube.radial_segments = 14
		tube.rings = 1
		var lie := Basis(Vector3.UP, float(pp[2])) * Basis(Vector3.RIGHT, PI * 0.5 + 0.07)
		junk.append_from(tube, 0, Transform3D(lie, c + Vector3(0, float(pp[3]) * 0.28, 0)))
		for e: float in [-0.42, 0.0, 0.42]:
			var band := CylinderMesh.new()
			band.top_radius = float(pp[3]) * 1.08
			band.bottom_radius = float(pp[3]) * 1.08
			band.height = 0.7
			band.radial_segments = 14
			band.rings = 1
			junk_pale.append_from(band, 0, Transform3D(lie, c + Vector3(0, float(pp[3]) * 0.28, 0) + lie * Vector3(0, e * float(pp[4]), 0)))
	# a hoop off some machine, standing a third out of the ground and leaning
	for hp: Array in [[150.0, -17.0, 6.0, 0.3], [404.0, 24.0, 8.0, -0.25]]:
		var hoop := _flat_tool()
		_arc(hoop, float(hp[2]), 0.0, TAU, PackedVector2Array([Vector2(-0.6, -0.5), Vector2(-0.6, 0.5), Vector2(0.6, 0.5), Vector2(0.6, -0.5)]), 28)
		var hmi := _commit(a, "HLHoop", hoop, worn, true)
		hmi.position = road(float(hp[0]), float(hp[1])) + Vector3(0, float(hp[2]) * 0.2, 0)
		hmi.rotation = Vector3(float(hp[3]), rng.randf() * TAU, 0.1)
	# the dome, where the road tops the rise (it has a face of sorts: a ring of dead lenses)
	var dome_at := road(road_at_z(103.0), 9.5) - Vector3(0, 1.2, 0)
	var dome := SphereMesh.new()
	dome.radius = 3.6
	dome.height = 7.2
	dome.radial_segments = 20
	dome.rings = 10
	junk_pale.append_from(dome, 0, Transform3D(Basis.from_euler(Vector3(0.3, 0.6, 0.2)), dome_at))
	_prism(junk, dome_at - Vector3(0, 1.6, 0), 4.4, 4.0, 2.0, 12)
	for k2 in 6:
		var la := k2 * TAU / 6.0
		_prism(junk, dome_at + Basis.from_euler(Vector3(0.3, 0.6, 0.2)) * (Vector3(cos(la), 0.55, sin(la)).normalized() * 3.45), 0.5, 0.42, 0.4, 8)
	_commit(a, "HLJunk", junk, worn, true)
	_commit(a, "HLJunkPale", junk_pale, pale, true)
	# the dead tree in the saddle below the gate, and another where the road sets out
	_dead_tree(a, road(tree_s(), -5.5) - Vector3(0, 0.5, 0), 7.6, 200.0)
	_dead_tree(a, road(75.0, 7.5) - Vector3(0, 0.5, 0), 6.8, 20.0)

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

# ================================================================ the sky that is not this world's
## What says, before anything built does, that this is not Earth: the pale banded world this one turns about, low
## in the north-west; the arc of the orbital ring crossing the whole sky, plate by plate; stars near the zenith
## even by day; aurora in high thin curtains; and, in the second generation, the trails of what is falling.
static func _sky(a: Arena, st: Dictionary) -> void:
	var centre := Vector3(0, 0, 200.0)
	# ---- the planet
	var pdir := (Basis(Vector3.UP, deg_to_rad(27.0)) * Vector3(0, 0, -1)).rotated(Basis(Vector3.UP, deg_to_rad(27.0)) * Vector3.RIGHT, deg_to_rad(9.5))
	var card := QuadMesh.new()
	card.size = Vector2(1350, 1350)
	var planet := ShaderMaterial.new()
	planet.shader = load("res://src/world/highland_planet.gdshader")
	planet.set_shader_parameter("noise_tex", _noise_tex())
	var pmi := MeshInstance3D.new()
	pmi.name = "HLPlanet"
	pmi.mesh = card
	pmi.material_override = planet
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pmi.sorting_offset = -6000.0
	a.add_child(pmi)
	pmi.position = centre + pdir * 5000.0
	pmi.look_at(centre, Vector3.UP, true)
	st["planet"] = planet
	st["planet_node"] = pmi
	# ---- ribbons: the orbital arc, the aurora, the falling trails
	var lines := load("res://src/world/highland_skyline.gdshader") as Shader
	var mats := {}
	for nm: String in ["arc", "aurora", "trails", "stars"]:
		var m := ShaderMaterial.new()
		m.shader = lines
		m.set_shader_parameter("noise_tex", _noise_tex())
		mats[nm] = m
	st["skyfx"] = mats
	# the arc: a circle about the viewer, tipped over toward the north, so it climbs out of the west and comes down in the sea
	var u := Vector3(0.94, 0, -0.34).normalized()
	var v := Vector3(0.22, 0.78, 0.59).normalized()
	v = (v - u * v.dot(u)).normalized()
	var arc := SurfaceTool.new()
	arc.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band: Array in [[70.0, 1.0, Color(0.95, 0.93, 0.88, 0.85)], [420.0, 0.0, Color(0.7, 0.75, 0.85, 0.1)]]:
		_ribbon(arc, func(t: float) -> Vector3: return centre + (u * cos(t * PI) + v * sin(t * PI)) * 5100.0,
			func(_t: float) -> Vector3: return u.cross(v).normalized(),
			float(band[0]), 96, band[2], float(band[1]))
	_sky_mesh(a, "HLOrbit", arc.commit(), mats.arc, -5600.0)
	# aurora: three curtains hanging high in the north and west
	var aur := SurfaceTool.new()
	aur.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c: Array in [[-70.0, 10.0, 34.0, Color(0.3, 1.0, 0.75, 0.5)], [-20.0, 60.0, 42.0, Color(0.45, 0.6, 1.0, 0.4)], [-130.0, -60.0, 30.0, Color(0.5, 0.95, 0.7, 0.4)]]:
		var from_az := deg_to_rad(float(c[0]))
		var to_az := deg_to_rad(float(c[1]))
		var elev := deg_to_rad(float(c[2]))
		_ribbon(aur, func(t: float) -> Vector3:
			var az := lerpf(from_az, to_az, t)
			var el := elev + sin(t * 9.0) * 0.05
			return centre + Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)) * 4900.0 + Vector3(0, 450.0, 0),
			func(_t: float) -> Vector3: return Vector3.DOWN, 900.0, 40, c[3], 2.0)
	_sky_mesh(a, "HLAurora", aur.commit(), mats.aurora, -5400.0)
	# trails: short bright streaks coming down out of the arc
	var tr := SurfaceTool.new()
	tr.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 7:
		var t0 := rng.randf_range(0.2, 0.75)
		var head := centre + (u * cos(t0 * PI) + v * sin(t0 * PI)) * 5050.0
		var fall := (Vector3(rng.randf_range(-0.5, 0.2), -1.0, rng.randf_range(-0.2, 0.3))).normalized()
		var length := rng.randf_range(350.0, 900.0)
		_ribbon(tr, func(t: float) -> Vector3: return head + fall * length * (1.0 - t), func(_t: float) -> Vector3: return fall.cross(head - centre).normalized(),
			rng.randf_range(14.0, 30.0), 2, Color(1.0, 0.62, 0.3, rng.randf_range(0.4, 0.9)), 0.0)
	st["trails"] = _sky_mesh(a, "HLTrails", tr.commit(), mats.trails, -5500.0)
	# stars, near the zenith
	var sm := SurfaceTool.new()
	sm.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 170:
		var az := rng.randf() * TAU
		var el := deg_to_rad(rng.randf_range(24.0, 86.0))
		var dir := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
		var at := centre + dir * 5300.0
		var size := rng.randf_range(11.0, 30.0) * (2.2 if k % 23 == 0 else 1.0)
		var sx := dir.cross(Vector3.UP).normalized() * size
		var sy := sx.cross(dir).normalized() * size
		var col := Color(rng.randf_range(0.8, 1.0), rng.randf_range(0.85, 1.0), 1.0, rng.randf_range(0.35, 1.0) * smoothstep(20.0, 55.0, rad_to_deg(el)))
		var corners := [[-sx - sy, Vector2(0, 0)], [sx - sy, Vector2(1, 0)], [sx + sy, Vector2(1, 1)], [-sx + sy, Vector2(0, 1)]]
		for i: int in [0, 1, 2, 0, 2, 3]:
			sm.set_color(col)
			sm.set_uv(corners[i][1])
			sm.set_uv2(Vector2(3.0, rng.randf()))
			sm.add_vertex(at + corners[i][0])
	_sky_mesh(a, "HLStars", sm.commit(), mats.stars, -5900.0)

## A strip of sky light: `path` gives its line (t from 0 to 1), `across` the way it is wide.
static func _ribbon(sf: SurfaceTool, path: Callable, across: Callable, width: float, steps: int, col: Color, kind: float) -> void:
	for s in steps:
		var t0 := float(s) / float(steps)
		var t1 := float(s + 1) / float(steps)
		var p0: Vector3 = path.call(t0)
		var p1: Vector3 = path.call(t1)
		var w0: Vector3 = across.call(t0) * width
		var w1: Vector3 = across.call(t1) * width
		var quad := [[p0, Vector2(0, t0)], [p0 + w0, Vector2(1, t0)], [p1 + w1, Vector2(1, t1)], [p1, Vector2(0, t1)]]
		for i: int in [0, 1, 2, 0, 2, 3]:
			sf.set_color(col)
			sf.set_uv(quad[i][1])
			sf.set_uv2(Vector2(kind, 0.0))
			sf.add_vertex(quad[i][0])

static func _sky_mesh(a: Arena, node_name: String, mesh: Mesh, mat: Material, order: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = order
	mi.custom_aabb = AABB(Vector3(-7000, -500, -7000), Vector3(14000, 7000, 14000))
	a.add_child(mi)
	return mi

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
	var woke := float(s.seam) > 1.0
	var engine := Color("#5fe0c8")
	# the door: shut and true while it is kept; afterwards one leaf hangs off its rail and stands ajar
	var leaves: Array = st.get("leaves", [])
	if leaves.size() == 2:
		(leaves[1] as Node3D).rotation_degrees = Vector3.ZERO if whole else Vector3(2.0, -17.0, -3.0)
		(leaves[1] as Node3D).position.y = 0.0 if whole else -0.45
	var model: Node3D = st.get("gate_model")
	if model:
		model.rotation_degrees = Vector3(0, GATE_YAW, 0) if whole else Vector3(1.4, GATE_YAW, 0.9)
		Look.set_param(model, &"tint", Color(1, 1, 1) if whole else (Color(0.68, 0.64, 0.6) if g == 2 else Color(0.66, 0.7, 0.76)))
	# every light that is part of a structure: fed while the road is kept, dead after, and the Engine's colour when it wakes
	for l: Array in st.lamps:
		_set_lamp(l[0], l[1] if whole else engine, float(l[2]) if whole else (float(l[2]) * 0.8 if woke else 0.0))
	_set_lamp(st.gate_seam, Color("#ffb060") if whole else engine, 1.6 if whole else (6.0 if woke else 0.0))
	_set_lamp(st.pad, Color("#ffb060") if whole else engine, 1.0 if whole else (3.5 if woke else 0.0))
	var glow := st.gate_glow as OmniLight3D
	glow.light_color = Color("#ffb060") if whole else engine
	glow.light_energy = 1.0 if whole else (3.5 if woke else 0.0)
	for l: Array in st.lights:
		(l[0] as Light3D).light_color = Color("#ffd9a0")
		(l[0] as Light3D).light_energy = float(l[1]) if whole else 0.0
	# the sky that is not this world's
	var sk: Dictionary = SKY[g - 1]
	var planet: ShaderMaterial = st.planet
	planet.set_shader_parameter("lit", Color(str(sk.planet)))
	planet.set_shader_parameter("band", Color(str(sk.band)))
	planet.set_shader_parameter("strength", float(sk.planet_e))
	planet.set_shader_parameter("light", (st.planet_node as Node3D).global_basis.inverse() * _sun_dir(s.sun_rot))
	for nm: String in ["arc", "aurora", "stars", "trails"]:
		(st.skyfx[nm] as ShaderMaterial).set_shader_parameter("strength", float(sk[nm]))
	(st.skyfx.arc as ShaderMaterial).set_shader_parameter("wake", engine * 1.4 if woke else Color.BLACK)
	(st.trails as Node3D).visible = float(sk.trails) > 0.0
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
	ground.set_shader_parameter("slab", Color(str(sk.slab)))
	ground.set_shader_parameter("guide", Color(0.1, 0.42, 0.38) * 0.7 if whole else (Color(0.14, 0.7, 0.6) if woke else Color.BLACK))
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
	snow_now = float(s.snow)
	var water: ShaderMaterial = st.get("water")
	if water:
		water.set_shader_parameter("freeze", float(s.snow))
		water.set_shader_parameter("haze", Color(str(s.haze)))
	var shaft: ShaderMaterial = st.shaft
	shaft.set_shader_parameter("tint", Color(str(s.sun)))
	shaft.set_shader_parameter("strength", float(s.shafts))
	# the citadel's lines of light: lit while it is lived in, dark after, and the Engine's colour when it wakes
	_set_lamp(st.windows, Color("#ffb45a") if whole else engine, 2.4 if whole else (3.0 if woke else 0.0))
	(st.seam as StandardMaterial3D).emission_energy_multiplier = float(s.seam)
	# awake, it is seen through any weather
	(st.seam as StandardMaterial3D).disable_fog = float(s.seam) > 1.0
	(st.seam as StandardMaterial3D).albedo_color = Color("#5fe0c8") if float(s.seam) > 1.0 else Color(0.08, 0.1, 0.1)
	var old := a.get_node_or_null("HLWeather")
	if old:
		old.free()
	if str(s.weather) != "":
		_weather(a, str(s.weather))

## Turns a structure's light to a colour and a strength (nothing: it reads as dead glass).
static func _set_lamp(m: StandardMaterial3D, c: Color, energy: float) -> void:
	m.emission = c
	m.emission_energy_multiplier = energy
	m.albedo_color = c if energy > 0.0 else Color(0.05, 0.055, 0.06)

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
