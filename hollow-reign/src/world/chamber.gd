class_name Chamber
extends RefCounted
## The awakening chamber (the Inheritance Engine's room), rebuilt for Stage 1 of docs/AAA_STAGES.md.
## Arena theme "chamber" calls build(); every scene that uses the room (Awakening, HeirReturn, Prologue's fall) finds
## it here. Owner's brief: an ancient far-future facility abandoned for decades, with Souls decay: real structure,
## worn metal, dust and corrosion, restrained light that still shows the knight and the room, no glowing strips.
##
## What is in it, and what each thing is for (plan view: the door is at -Z, the camera usually on the +Z side):
##   - twelve bays between gunmetal ribs that rise up the wall and over into a vault, meeting at the oculus, a ring
##     housing with the room's one working lamp (the key light) and the bundle of life-support lines that drops from
##     it to the cradle;
##   - the stasis cradle in the middle: a bed set flush in the deck under a cage of restraint hoops (node "Hoops",
##     swings back to open), side rails, a head unit with its canisters and gauges, the seal clamps round it with
##     their lamps, the lines from the oculus and the floor trenches into the head unit, and a console at its side;
##   - the sword holder beside it (node "Rack"): a stepped plinth with a slotted block and two clamp arms
##     ("ClampL"/"ClampR") that let go of the blade, in front of an engraved bronze frame with its own small lamp;
##   - the Witness's maintenance housing in the wall left of the door ("Housing": "HousingCover" slides up,
##     "HousingClamps" open), with a failing lamp ("WitnessLamp");
##   - Lyra's grille ("Lyra", the light behind it) in the next bay;
##   - the door: a heavy slab ("Door", closed at y 1.65, open at y 5.2, as Prologue drops it) behind lock bars
##     ("DoorBars") in a bulkhead portal, a status lamp over it ("DoorLamp");
##   - beyond it a short passage (ribbed, cabled, a fallen ceiling plate) to an outer doorway open on daylight
##     ("Daylight", "DoorGlow"): the hand-off to the world (EXIT_END; see docs/STAGE1_HANDOFF in the report).
## Two dead stasis pods (the kit's env_fu_pod) stand in bays: the others who did not wake.
## Geometry is built here and merged by material into a few meshes (one draw each); the moving parts are their own.

const R := 6.2                 # inner line of the wall plating
const WALL_H := 4.2
const CROWN := 6.5             # height of the oculus ring
const OCULUS_R := 1.35
const BAYS := 12
const DOOR_BAY := 6            # at -Z
const HOUSING_BAY := 7         # left of the door, seen from inside
const GRILLE_BAY := 8
const CRADLE_AT := Vector3(0, 0, 0.35)       # the middle of the bed; head end toward -Z
const BED_LEN := 2.3
const BED_W := 1.45
## Where the knight's rig stands while lying in the cradle (feet toward +Z; Awakening calibrates the pose on it).
const LIE_AT := Vector3(0, 0.035, 0.05)
const HOLDER_AT := Vector3(2.05, 0, -0.55)
const HOLDER_YAW := -52.0                    # its front turned toward the foot of the cradle (degrees, 0 faces +Z)
const SLOT_TOP := 0.3                        # the blade's point stands in the block's slot at this height
const DOOR_Z := -R
const DOOR_W := 2.4
const DOOR_H := 3.3
const PASSAGE_END := -12.6
## Where the passage meets the outer doorway: the hand-off to the world, facing out (-Z). Stage 3 joins here.
const EXIT_END := Transform3D(Basis.IDENTITY, Vector3(0, 0, -12.2))
## Points a walk out of the room follows, from just inside the door to EXIT_END.
const EXIT_PATH := [Vector3(0, 0, -4.9), Vector3(0, 0, -7.2), Vector3(0, 0, -12.2)]

static func bay_dir(i: int) -> Vector3:
	var a := TAU * float(i) / BAYS
	return Vector3(sin(a), 0, cos(a))

## The point in front of the Witness's housing where the instrument lies (world).
static func housing_cup() -> Vector3:
	var d := bay_dir(HOUSING_BAY)
	return d * (R - 0.42) + Vector3(0, 1.32, 0)

static func grille_at() -> Vector3:
	return bay_dir(GRILLE_BAY) * (R - 0.12) + Vector3(0, 2.55, 0)

# ================================================================ materials
static var _scratch: Texture2D

## Worn-metal wear: short bright scratches, some in bunches, on a dark sheet (tiles).
static func _scratches() -> Texture2D:
	if _scratch != null:
		return _scratch
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_L8)
	img.fill(Color(0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	for i in 520:
		var p := Vector2(rng.randf() * size, rng.randf() * size)
		var ang := rng.randf() * TAU if rng.randf() < 0.4 else rng.randf_range(-0.35, 0.35)
		var l := rng.randf_range(4.0, 26.0) if rng.randf() < 0.85 else rng.randf_range(30.0, 70.0)
		var v := rng.randf_range(0.35, 1.0)
		for s in int(l):
			var q := p + Vector2(cos(ang), sin(ang)) * s
			var x := posmod(int(q.x), size)
			var y := posmod(int(q.y), size)
			img.set_pixel(x, y, Color(maxf(img.get_pixel(x, y).r, v), 0, 0))
	img.generate_mipmaps()
	_scratch = ImageTexture.create_from_image(img)
	return _scratch

static func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

## One of the room's surfaces. kind: plate (wall plating), dark (gunmetal structure), bronze, ceramic (the makers'
## pale ceramic), cable (rubber and cloth), floor (the deck).
static func mat(kind: String) -> ShaderMaterial:
	var key := "chamber_" + kind
	if Look._cache.has(key):
		return Look._cache[key]
	var sheet := Highland._panels()
	var m := ShaderMaterial.new()
	m.shader = load("res://src/world/chamber_surface.gdshader")
	m.set_shader_parameter("panel_tex", sheet[0])
	m.set_shader_parameter("panel_n", sheet[1])
	m.set_shader_parameter("noise_tex", Highland._noise_tex())
	m.set_shader_parameter("scratch_tex", _scratches())
	var worn := kind in ["plate", "floor", "bronze"]
	m.set_shader_parameter("grain_tex", _tex("res://assets/models/gear/tex/%s_a.png" % ("worn" if worn else "steel")))
	m.set_shader_parameter("grain_n", _tex("res://assets/models/gear/tex/%s_n.png" % ("worn" if worn else "steel")))
	var p: Dictionary = {
		"plate": {"tint": Color("#6d7272"), "metal": 0.5, "rough": 0.56, "panel_scale": 0.18, "panel_amt": 0.35, "dust_amt": 0.75, "rust_amt": 0.5},
		"dark": {"tint": Color("#3b3e40"), "metal": 0.62, "rough": 0.5, "panel_scale": 0.5, "panel_amt": 0.35, "dust_amt": 0.8, "rust_amt": 0.4},
		"bronze": {"tint": Color("#7a6142"), "metal": 0.78, "rough": 0.48, "panel_scale": 0.6, "panel_amt": 0.0, "dust_amt": 0.55, "rust_amt": 0.35,
			"rust": Color("#3c5248")},
		"ceramic": {"tint": Color("#8c897f"), "metal": 0.08, "rough": 0.62, "panel_scale": 0.3, "panel_amt": 0.2, "dust_amt": 0.6, "rust_amt": 0.22,
			"scratch_amt": 0.3, "rust": Color("#4a3c2c")},
		"cable": {"tint": Color("#202122"), "metal": 0.1, "rough": 0.72, "panel_scale": 1.0, "panel_amt": 0.0, "dust_amt": 0.85, "rust_amt": 0.0, "scratch_amt": 0.15},
		"floor": {"tint": Color("#5d5f5c"), "metal": 0.42, "rough": 0.62, "panel_scale": 0.26, "panel_amt": 0.9, "dust_amt": 0.62, "rust_amt": 0.25, "floor_mode": 1.0,
			"grain_scale": 0.7},
	}[kind]
	for k: String in p:
		m.set_shader_parameter(k, p[k])
	Look._cache[key] = m
	return m

## A small lens or lamp face: the only things in the room that give light of their own (never a strip).
static func lamp_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := Look.glow(c, energy)
	return m

# ================================================================ geometry
## Merged geometry by material: one SurfaceTool each, committed at the end (one draw per material).
class Kit:
	var tools := {}
	func sf(kind: String) -> SurfaceTool:
		if not tools.has(kind):
			var s := SurfaceTool.new()
			s.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[kind] = s
		return tools[kind]
	func commit(parent: Node3D, prefix: String, shadows: Array) -> void:
		for kind: String in tools:
			var mi := MeshInstance3D.new()
			mi.name = prefix + kind.capitalize()
			mi.mesh = (tools[kind] as SurfaceTool).commit()
			mi.material_override = Chamber.mat(kind)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind in shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
		tools.clear()

static func _tri(sf: SurfaceTool, p: Vector3, q: Vector3, r: Vector3, away: Vector3) -> void:
	Highland._tri(sf, p, q, r, away)

static func _quad(sf: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, away: Vector3) -> void:
	_tri(sf, a, b, c, away)
	_tri(sf, a, c, d, away)

## A box with chamfered edges (flat-shaded, so every edge catches a highlight): size, placed by `xf`.
static func bevel(sf: SurfaceTool, size: Vector3, xf: Transform3D, b: float = 0.025) -> void:
	var h := size * 0.5
	b = minf(b, minf(h.x, minf(h.y, h.z)) * 0.45)
	var pts := {}
	for sx: int in [-1, 1]:
		for sy: int in [-1, 1]:
			for sz: int in [-1, 1]:
				pts[Vector3i(sx, sy, sz)] = [xf * Vector3(sx * h.x, sy * (h.y - b), sz * (h.z - b)),
					xf * Vector3(sx * (h.x - b), sy * h.y, sz * (h.z - b)), xf * Vector3(sx * (h.x - b), sy * (h.y - b), sz * h.z)]
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for k in 3:
		for s: int in [-1, 1]:
			var q: Array = []
			for u: int in [-1, 1]:
				for v: int in [-1, 1]:
					var c := [0, 0, 0]
					c[k] = s
					c[(k + 1) % 3] = u
					c[(k + 2) % 3] = v
					q.append(pts[Vector3i(c[0], c[1], c[2])][k])
			_quad(sf, q[0], q[1], q[3], q[2], xf.basis * ((axes[k] as Vector3) * s))
	for pr: Array in [[0, 1, 2], [0, 2, 1], [1, 2, 0]]:
		for s1: int in [-1, 1]:
			for s2: int in [-1, 1]:
				var c0 := [0, 0, 0]
				c0[pr[0]] = s1
				c0[pr[1]] = s2
				c0[pr[2]] = -1
				var c1 := c0.duplicate()
				c1[pr[2]] = 1
				var k0 := Vector3i(c0[0], c0[1], c0[2])
				var k1 := Vector3i(c1[0], c1[1], c1[2])
				_quad(sf, pts[k0][pr[0]], pts[k1][pr[0]], pts[k1][pr[1]], pts[k0][pr[1]], xf.basis * ((axes[pr[0]] as Vector3) * s1 + (axes[pr[1]] as Vector3) * s2))
	for kk: Vector3i in pts:
		_tri(sf, pts[kk][0], pts[kk][1], pts[kk][2], xf.basis * Vector3(kk))

## A primitive mesh (cylinder, sphere) added as plain triangles with normals, so it can share a SurfaceTool with the
## code-built shapes (which carry normals only; append_from would bring a different vertex format).
static func prim(sf: SurfaceTool, m: PrimitiveMesh, xf: Transform3D) -> void:
	var arr := m.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	for i in idx.size():
		sf.set_normal((nb * n[idx[i]]).normalized())
		sf.add_vertex(xf * v[idx[i]])

## A smooth tube along a polyline (cables, pipes, hoops). `r_end` tapers it.
static func tube(sf: SurfaceTool, pts: Array, r: float, sides: int = 6, r_end: float = -1.0) -> void:
	var n := pts.size()
	if n < 2:
		return
	var t0: Vector3 = ((pts[1] as Vector3) - (pts[0] as Vector3)).normalized()
	var nrm := t0.cross(Vector3.UP)
	if nrm.length() < 0.05:
		nrm = t0.cross(Vector3.RIGHT)
	nrm = nrm.normalized()
	var rings: Array = []
	var norms: Array = []
	for i in n:
		var t: Vector3
		if i == 0:
			t = t0
		elif i == n - 1:
			t = ((pts[n - 1] as Vector3) - (pts[n - 2] as Vector3)).normalized()
		else:
			t = ((pts[i + 1] as Vector3) - (pts[i - 1] as Vector3)).normalized()
		nrm = (nrm - t * nrm.dot(t)).normalized()
		var bn := t.cross(nrm)
		var rr := r if r_end < 0.0 else lerpf(r, r_end, float(i) / float(n - 1))
		var ring := PackedVector3Array()
		var nr := PackedVector3Array()
		for k in sides:
			var ang := TAU * k / sides
			var d := nrm * cos(ang) + bn * sin(ang)
			ring.append((pts[i] as Vector3) + d * rr)
			nr.append(d)
		rings.append(ring)
		norms.append(nr)
	for i in n - 1:
		var a: PackedVector3Array = rings[i]
		var b: PackedVector3Array = rings[i + 1]
		var na: PackedVector3Array = norms[i]
		var nb: PackedVector3Array = norms[i + 1]
		for k in sides:
			var k2 := (k + 1) % sides
			_tri_s(sf, a[k], b[k], b[k2], na[k], nb[k], nb[k2])
			_tri_s(sf, a[k], b[k2], a[k2], na[k], nb[k2], na[k2])

## A triangle with its own vertex normals, wound to face the way they point.
static func _tri_s(sf: SurfaceTool, p: Vector3, q: Vector3, r: Vector3, np: Vector3, nq: Vector3, nr: Vector3) -> void:
	var face := (q - p).cross(r - p)
	if face.dot(np + nq + nr) < 0.0:
		var t := q
		q = r
		r = t
		var tn := nq
		nq = nr
		nr = tn
	for v: Array in [[p, np], [r, nr], [q, nq]]:
		sf.set_normal(v[1])
		sf.add_vertex(v[0])

## A cubic curve sampled into `n` + 1 points.
static func bez(a: Vector3, c1: Vector3, c2: Vector3, b: Vector3, n: int = 12) -> Array:
	var out: Array = []
	for i in n + 1:
		var t := float(i) / n
		var u := 1.0 - t
		out.append(a * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + b * t * t * t)
	return out

## A cable hanging between two points.
static func hang(a: Vector3, b: Vector3, sag: float, n: int = 14) -> Array:
	var out: Array = []
	for i in n + 1:
		var t := float(i) / n
		out.append(a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	return out

## A cable lying across the floor between two points, wandering a little (radius r: it rests on the deck).
static func lying(a: Vector3, b: Vector3, r: float, wander: float, seed_n: int, n: int = 16) -> Array:
	var out: Array = []
	var side := Vector3(-(b.z - a.z), 0, b.x - a.x).normalized()
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t) + side * wander * sin(t * PI * 2.0 + seed_n) * sin(t * PI)
		var lift := lerpf(a.y, b.y, pow(t, 4.0)) if b.y > a.y else lerpf(a.y, b.y, 1.0 - pow(1.0 - t, 4.0))
		p.y = maxf(r, lift) if (t > 0.05 and t < 0.95) else p.y
		p.y = maxf(p.y, r)
		out.append(p)
	return out

## A ring of `n` points (radius r, height y) between two angles (radians, 0 at +Z).
static func arc_pts(r: float, y: float, a0: float, a1: float, n: int) -> Array:
	var out: Array = []
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		out.append(Vector3(sin(a) * r, y, cos(a) * r))
	return out

static func _xf(at: Vector3, yaw_deg: float = 0.0, pitch_deg: float = 0.0, roll_deg: float = 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), deg_to_rad(roll_deg)), EULER_ORDER_YXZ), at)

## The frame of a bay: origin on the wall line at the floor, +Z out of the wall into the room, +X along it.
static func bay_xf(i: int, inset: float = 0.0) -> Transform3D:
	var d := bay_dir(i)
	var yaw := atan2(-d.x, -d.z)            # facing the room's middle
	return Transform3D(Basis(Vector3.UP, yaw), d * (R - inset))

# ================================================================ the room
static func build(a: Arena) -> void:
	# the arena's default floor and duelling ring are not part of this room
	for c: Node in a.get_children():
		if c is MeshInstance3D:
			c.queue_free()
	a.set_meta("future_look", "chamber")
	var k := Kit.new()
	_floor(a, k)
	_walls(a, k)
	_vault(a, k)
	_cradle(a, k)
	_console(k)
	_holder(a, k)
	_housing(a, k)
	_grille(a, k)
	_door(a, k)
	_passage(a, k)
	_pods(a)
	k.commit(a, "Chamber", ["dark", "ceramic", "bronze"])
	_lights(a)

# ---------------------------------------------------------------- the deck
static func _floor(a: Arena, k: Kit) -> void:
	var p := PlaneMesh.new()
	p.size = Vector2(16, 26)
	var mi := MeshInstance3D.new()
	mi.name = "Deck"
	mi.mesh = p
	mi.position = Vector3(0, 0, -4.0)
	mi.material_override = mat("floor")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(mi)
	var dark := k.sf("dark")
	var bronze := k.sf("bronze")
	var cable := k.sf("cable")
	# the seal: a bronze ring let into the deck round the cradle, and the inner ring of the bed's well
	tube(bronze, arc_pts(1.75, 0.012, 0.0, TAU, 48).map(func(v: Vector3) -> Vector3: return v + CRADLE_AT * Vector3(1, 0, 1)), 0.035, 5)
	tube(dark, arc_pts(1.62, 0.008, 0.0, TAU, 48).map(func(v: Vector3) -> Vector3: return v + CRADLE_AT * Vector3(1, 0, 1)), 0.03, 4)
	# trenches from the cradle out to the machine bays (left and right), a grating over each, cables in them
	for sx: float in [-1.0, 1.0]:
		var x0 := sx * 1.85
		var x1 := sx * (R - 0.5)
		var len := absf(x1 - x0)
		var cx := (x0 + x1) * 0.5
		bevel(dark, Vector3(len, 0.02, 0.62), _xf(Vector3(cx, 0.0, CRADLE_AT.z - 0.3)), 0.005)
		for g in int(len / 0.16):
			bevel(dark, Vector3(0.035, 0.035, 0.56), _xf(Vector3(x0 + sx * (0.08 + g * 0.16), 0.02, CRADLE_AT.z - 0.3)), 0.008)
		for rail: float in [-0.3, 0.3]:
			bevel(bronze, Vector3(len, 0.03, 0.05), _xf(Vector3(cx, 0.015, CRADLE_AT.z - 0.3 + rail)), 0.008)
		for c in 2:
			var zc := CRADLE_AT.z - 0.42 + c * 0.24
			tube(cable, lying(Vector3(x1, 0.04, zc + 0.05), Vector3(sx * 0.9, 0.3, CRADLE_AT.z - 0.95 + c * 0.1), 0.045, 0.12, c + int(sx * 3.0)), 0.045, 6)
	# loose cables: from the console to the foot of the cradle, and one torn and lying on its own
	tube(cable, lying(Vector3(-1.55, 0.3, 1.45), Vector3(-0.62, 0.22, CRADLE_AT.z + 0.6), 0.03, 0.25, 4), 0.03, 6)
	tube(cable, lying(Vector3(-1.4, 0.03, 1.55), Vector3(-2.9, 0.03, 3.2), 0.03, 0.4, 7), 0.03, 6)
	tube(cable, lying(Vector3(3.6, 0.04, 2.6), Vector3(4.8, 0.04, 0.5), 0.04, 0.5, 2), 0.04, 6)
	# deck plates come up where the floor has settled; scraps of plating fallen from the collapsed bay
	bevel(k.sf("plate"), Vector3(0.9, 0.04, 0.7), _xf(Vector3(-3.4, 0.05, 2.4), 18.0, 0.0, 4.0), 0.01)
	var fall := bay_dir(5) * (R - 1.0)
	for i in 6:
		var rng := RandomNumberGenerator.new()
		rng.seed = 300 + i
		var at := fall + Vector3(rng.randf_range(-0.9, 0.9), 0.0, rng.randf_range(-0.6, 0.6))
		bevel(k.sf("plate" if i % 2 == 0 else "dark"), Vector3(rng.randf_range(0.3, 0.9), 0.05, rng.randf_range(0.2, 0.6)),
			_xf(at + Vector3(0, 0.05 + i * 0.012, 0), rng.randf_range(0, 180), rng.randf_range(-8, 14), rng.randf_range(-10, 10)), 0.01)

# ---------------------------------------------------------------- walls
static func _walls(a: Arena, k: Kit) -> void:
	var plate := k.sf("plate")
	var dark := k.sf("dark")
	var bronze := k.sf("bronze")
	var cable := k.sf("cable")
	var w := 2.0 * R * sin(PI / BAYS)            # chord of one bay
	for i in BAYS:
		var bx := bay_xf(i)
		# the shell behind everything (not across the doorway: the passage opens there)
		if i != DOOR_BAY:
			bevel(dark, Vector3(w + 0.2, WALL_H + 0.3, 0.25), bx * _xf(Vector3(0, (WALL_H + 0.3) * 0.5, -0.42)), 0.02)
		if i != DOOR_BAY:
			# skirting: a heavy plate, leaning out at its foot
			bevel(dark, Vector3(w - 0.38, 0.5, 0.26), bx * _xf(Vector3(0, 0.25, 0.04), 0.0, -6.0), 0.03)
			# the cornice under the vault
			bevel(dark, Vector3(w - 0.3, 0.24, 0.34), bx * _xf(Vector3(0, WALL_H - 0.12, 0.0)), 0.04)
			bevel(plate, Vector3(w - 0.3, 0.1, 0.22), bx * _xf(Vector3(0, WALL_H - 0.32, 0.04)), 0.02)
		match i:
			DOOR_BAY:
				pass
			HOUSING_BAY:
				_plates(k, bx, w, i, [0, 1, 4, 5])      # the housing stands in the lower middle
			GRILLE_BAY:
				_plates(k, bx, w, i, [])
			3:
				# the ceremonial wall behind the sword: engraved bronze in a dark frame
				_plates(k, bx, w, i, [])
				bevel(dark, Vector3(1.4, 2.4, 0.12), bx * _xf(Vector3(0, 2.0, 0.02)), 0.04)
				bevel(bronze, Vector3(1.1, 2.0, 0.06), bx * _xf(Vector3(0, 2.0, 0.1)), 0.02)
				for r in 9:
					bevel(dark, Vector3(0.9, 0.02, 0.02), bx * _xf(Vector3(0, 1.15 + r * 0.21, 0.135)), 0.005)
			5:
				# collapsed: plates fallen away, the cable runs behind hanging out
				_plates(k, bx, w, i, [0, 1, 2, 3, 5])
				bevel(plate, Vector3(1.2, 1.1, 0.06), bx * _xf(Vector3(0.55, 0.62, 0.35), 8.0, 32.0, -6.0), 0.02)
				for c in 5:
					var x := -0.9 + c * 0.42
					tube(cable, hang(bx * Vector3(x, 3.3, -0.2), bx * Vector3(x * 0.6 + 0.1, 0.05, 0.55 + c * 0.08), -0.25 - c * 0.08, 12), 0.035 + c * 0.006, 6)
			_:
				_plates(k, bx, w, i, [] if i % 3 != 1 else [3])
		# two pipes and a cable tray round the room at the top of the wall, on brackets (not across the door)
		if i != DOOR_BAY:
			bevel(dark, Vector3(0.08, 0.5, 0.3), bx * _xf(Vector3(-w * 0.32, 3.55, -0.08)), 0.015)
			bevel(dark, Vector3(0.08, 0.5, 0.3), bx * _xf(Vector3(w * 0.32, 3.55, -0.08)), 0.015)
	# the pipe runs (curved meshes, round the room, broken at the door)
	var a0 := -PI + 0.3
	var a1 := PI - 0.3
	tube(dark, arc_pts(R - 0.12, 3.42, a0, a1, 96), 0.07, 8)
	tube(bronze, arc_pts(R - 0.1, 3.68, a0, a1, 96), 0.045, 6)
	tube(cable, arc_pts(R - 0.2, 3.75, a0, a1, 96), 0.03, 5)
	# the ribs: gunmetal columns at the bay joints, with a bronze shoe and a row of bolts
	for i in BAYS:
		var ang := TAU * (i + 0.5) / BAYS
		var d := Vector3(sin(ang), 0, cos(ang))
		var bx := Transform3D(Basis(Vector3.UP, atan2(-d.x, -d.z)), d * R)
		if i == DOOR_BAY - 1 or i == DOOR_BAY:
			continue            # the door's portal stands there
		bevel(dark, Vector3(0.34, WALL_H, 0.46), bx * _xf(Vector3(0, WALL_H * 0.5, 0.05)), 0.05)
		bevel(dark, Vector3(0.2, WALL_H - 0.2, 0.1), bx * _xf(Vector3(0, WALL_H * 0.5, 0.3)), 0.03)
		bevel(bronze, Vector3(0.44, 0.34, 0.56), bx * _xf(Vector3(0, 0.17, 0.06)), 0.04)
		for b in 7:
			for s: float in [-1.0, 1.0]:
				bevel(dark, Vector3(0.04, 0.04, 0.03), bx * _xf(Vector3(s * 0.12, 0.7 + b * 0.48, 0.29)), 0.01)

## The plating of one bay: two columns, three rows of plates with chamfers, set off the shell; `missing` lists the
## plates (0..5, row by row from the floor) that are gone (pipes show behind) or that are something else's place.
static func _plates(k: Kit, bx: Transform3D, w: float, bay: int, missing: Array) -> void:
	var plate := k.sf("plate")
	var dark := k.sf("dark")
	var rng := RandomNumberGenerator.new()
	rng.seed = 90 + bay
	var cw := (w - 0.5) * 0.5
	var heights := [[0.55, 1.15], [1.75, 1.0], [2.8, 0.9]]
	for row in 3:
		for col in 2:
			var idx := row * 2 + col
			var x := (col - 0.5) * (cw + 0.05)
			var y: float = heights[row][0] + heights[row][1] * 0.5
			if idx in missing:
				if bay != HOUSING_BAY and bay != GRILLE_BAY and bay != 3:
					# what is behind a plate that came off: three pipes and a junction
					for p in 3:
						tube(dark, [bx * Vector3(x - 0.3 + p * 0.3, y - 0.55, -0.22), bx * Vector3(x - 0.3 + p * 0.3, y + 0.55, -0.22)], 0.05, 6)
					bevel(dark, Vector3(0.5, 0.22, 0.16), bx * _xf(Vector3(x, y, -0.18)), 0.03)
				continue
			var tilt := rng.randf_range(-1.5, 1.5) if rng.randf() < 0.3 else 0.0
			bevel(plate, Vector3(cw, heights[row][1] - 0.06, 0.1), bx * _xf(Vector3(x, y, -0.05), 0.0, rng.randf_range(-1.0, 1.0), tilt), 0.03)
			# a raised inner panel on some, a recessed seam on others
			if rng.randf() < 0.55:
				bevel(plate, Vector3(cw - 0.22, heights[row][1] - 0.3, 0.04), bx * _xf(Vector3(x, y, 0.02)), 0.015)
			else:
				bevel(dark, Vector3(cw - 0.18, 0.03, 0.03), bx * _xf(Vector3(x, y - (heights[row][1] - 0.06) * 0.25, 0.005)), 0.008)

# ---------------------------------------------------------------- the vault and the oculus
static func _vault(a: Arena, k: Kit) -> void:
	var dark := k.sf("dark")
	var plate := k.sf("plate")
	var bronze := k.sf("bronze")
	var cable := k.sf("cable")
	# the curve every rib follows, in (out from the middle, up) coordinates
	var prof := func(t: float) -> Vector2:
		var ang := t * PI * 0.5
		return Vector2(OCULUS_R + 0.15 + (R - OCULUS_R - 0.15) * cos(ang), WALL_H + (CROWN - WALL_H) * sin(ang))
	var steps := 10
	for i in BAYS:
		var ang := TAU * (i + 0.5) / BAYS
		var d := Vector3(sin(ang), 0, cos(ang))
		var pts: Array = []
		for s in steps + 1:
			var v: Vector2 = prof.call(float(s) / steps)
			pts.append(d * (v.x - 0.05) + Vector3(0, v.y - 0.12, 0))
		tube(dark, pts, 0.17, 6)
		# the vault's skin between this rib and the next: plates set back above the ribs
		var bng := TAU * (i + 1.5) / BAYS
		var e := Vector3(sin(bng), 0, cos(bng))
		for s in steps:
			var v0: Vector2 = prof.call(float(s) / steps)
			var v1: Vector2 = prof.call(float(s + 1) / steps)
			var p00 := d * v0.x + Vector3(0, v0.y + 0.1, 0)
			var p01 := e * v0.x + Vector3(0, v0.y + 0.1, 0)
			var p10 := d * v1.x + Vector3(0, v1.y + 0.1, 0)
			var p11 := e * v1.x + Vector3(0, v1.y + 0.1, 0)
			_quad(plate if (s + i) % 4 != 0 else dark, p00, p01, p11, p10, Vector3(0, CROWN - 2.0, 0) - (p00 + p11) * 0.5)
		# a cross rib halfway up each bay
		var vm: Vector2 = prof.call(0.45)
		tube(dark, arc_pts(vm.x - 0.04, vm.y - 0.06, ang, bng, 6), 0.08, 5)
	# the oculus: a ring, and the hub that hangs in it with the lamp
	tube(dark, arc_pts(OCULUS_R, CROWN - 0.05, 0.0, TAU, 40), 0.2, 8)
	tube(bronze, arc_pts(OCULUS_R - 0.2, CROWN - 0.15, 0.0, TAU, 40), 0.05, 6)
	var cap := CylinderMesh.new()
	cap.top_radius = OCULUS_R + 0.1
	cap.bottom_radius = OCULUS_R + 0.1
	cap.height = 0.2
	cap.radial_segments = 24
	cap.rings = 1
	prim(dark, cap, _xf(Vector3(0, CROWN + 0.35, 0)))
	var hub := CylinderMesh.new()
	hub.top_radius = 0.55
	hub.bottom_radius = 0.7
	hub.height = 0.7
	hub.radial_segments = 16
	hub.rings = 1
	prim(dark, hub, _xf(Vector3(0, CROWN - 0.55, CRADLE_AT.z * 0.5)))
	bevel(plate, Vector3(0.9, 0.12, 0.9), _xf(Vector3(0, CROWN - 0.92, CRADLE_AT.z * 0.5), 45.0), 0.04)
	for s in 6:
		var aa := TAU * s / 6.0
		var o := Vector3(sin(aa), 0, cos(aa))
		tube(dark, [o * 0.6 + Vector3(0, CROWN - 0.4, CRADLE_AT.z * 0.5), o * (OCULUS_R - 0.05) + Vector3(0, CROWN - 0.05, 0)], 0.05, 5)
	# the life-support lines: from the hub down to the cradle's head unit, hanging in a loose bundle
	for c in 5:
		var aa2 := TAU * c / 5.0 + 0.3
		var top := Vector3(sin(aa2) * 0.35, CROWN - 0.85, CRADLE_AT.z * 0.5 + cos(aa2) * 0.35)
		var bot := CRADLE_AT + Vector3(-0.3 + c * 0.15, 1.38, -BED_LEN * 0.5 - 0.42)
		tube(cable, bez(top, top + Vector3(0, -1.6, 0), bot + Vector3(0, 1.4, -0.3), bot, 16), 0.04 + 0.008 * (c % 2), 6)

# ---------------------------------------------------------------- the cradle
static func _cradle(a: Arena, k: Kit) -> void:
	var root := Node3D.new()
	root.name = "Cradle"
	root.position = CRADLE_AT
	a.add_child(root)
	var x := Transform3D(Basis.IDENTITY, CRADLE_AT)
	var dark := k.sf("dark")
	var cer := k.sf("ceramic")
	var bronze := k.sf("bronze")
	var cable := k.sf("cable")
	var half := BED_LEN * 0.5
	# the bed: a frame flush with the deck, the articulated plates the body lies on, side rails
	bevel(dark, Vector3(BED_W + 0.3, 0.06, BED_LEN + 0.3), x * _xf(Vector3(0, 0.0, 0)), 0.02)
	for s in 5:
		var z := -half + 0.2 + s * (BED_LEN - 0.4) / 4.0
		bevel(cer, Vector3(BED_W - 0.12, 0.05, (BED_LEN - 0.4) / 4.0 - 0.04), x * _xf(Vector3(0, 0.015, z)), 0.02)
	for sx: float in [-1.0, 1.0]:
		bevel(cer, Vector3(0.1, 0.26, BED_LEN + 0.1), x * _xf(Vector3(sx * (BED_W * 0.5 + 0.12), 0.13, 0)), 0.035)
		bevel(dark, Vector3(0.06, 0.05, BED_LEN - 0.2), x * _xf(Vector3(sx * (BED_W * 0.5 + 0.12), 0.29, 0)), 0.015)
		# the hinge blocks the restraint cage turns on
		bevel(bronze, Vector3(0.16, 0.2, 0.22), x * _xf(Vector3(sx * (BED_W * 0.5 + 0.13), 0.33, -half + 0.12)), 0.03)
	# wrist and ankle cuffs, open
	for sx2: float in [-1.0, 1.0]:
		for z2: float in [0.05, 0.95]:
			tube(bronze, arc_pts(0.07, 0.0, 0.0, PI * 1.2, 8).map(func(v: Vector3) -> Vector3: return x * (Vector3(v.x, v.z, 0) + Vector3(sx2 * 0.36, 0.1, z2))), 0.014, 5)
	# the head unit: a cabinet at the head of the bed, canisters with bronze bands, gauges, the lines going in
	var hx := x * _xf(Vector3(0, 0, -half - 0.42))
	bevel(dark, Vector3(1.25, 1.15, 0.6), hx * _xf(Vector3(0, 0.575, 0)), 0.05)
	bevel(cer, Vector3(1.1, 0.32, 0.5), hx * _xf(Vector3(0, 1.31, 0.02)), 0.06)
	bevel(cer, Vector3(0.9, 0.5, 0.08), hx * _xf(Vector3(0, 0.62, 0.32), 0.0, -8.0), 0.03)
	for c in 3:
		var cx := -0.38 + c * 0.38
		var can := CylinderMesh.new()
		can.top_radius = 0.11
		can.bottom_radius = 0.11
		can.height = 0.62
		can.radial_segments = 12
		can.rings = 1
		prim(cer, can, hx * _xf(Vector3(cx, 1.6, -0.12)))
		for band: float in [1.36, 1.84]:
			tube(bronze, arc_pts(0.115, band, 0.0, TAU, 12).map(func(v: Vector3) -> Vector3: return hx * (v + Vector3(cx, 0, -0.12))), 0.014, 4)
		tube(cable, bez(hx * Vector3(cx, 1.92, -0.12), hx * Vector3(cx, 2.15, -0.1), hx * Vector3(cx * 0.5, 2.1, 0.25), hx * Vector3(cx * 0.4, 1.47, 0.22), 8), 0.025, 5)
	# gauges on the cabinet's face toward the bed: bronze rims, dark faces, one needle each
	for g in 2:
		var gx := -0.3 + g * 0.6
		tube(bronze, arc_pts(0.09, 0.0, 0.0, TAU, 14).map(func(v: Vector3) -> Vector3: return hx * (Vector3(v.x, v.z, 0) + Vector3(gx, 0.98, 0.31))), 0.018, 5)
		bevel(dark, Vector3(0.012, 0.07, 0.008), hx * _xf(Vector3(gx, 0.99, 0.325), 0.0, 0.0, 40.0 - g * 70.0), 0.003)
	# lines from the cabinet's sides down into the bed and out along the trenches
	for sx3: float in [-1.0, 1.0]:
		tube(cable, bez(hx * Vector3(sx3 * 0.62, 0.55, 0.0), hx * Vector3(sx3 * 0.9, 0.4, 0.1), x * Vector3(sx3 * 0.85, 0.15, -half + 0.6), x * Vector3(sx3 * 0.66, 0.2, -half + 0.9), 10), 0.04, 6)
	# the seal clamps round the bed, each with its lamp (lit while the seal holds)
	var clamps: Array = []
	for c2 in 6:
		var ca := TAU * (c2 + 0.5) / 6.0
		var cd := Vector3(sin(ca), 0, cos(ca) * 1.35)
		var at := CRADLE_AT + cd.normalized() * 1.62
		var yaw := rad_to_deg(atan2(cd.x, cd.z))
		bevel(dark, Vector3(0.3, 0.16, 0.34), _xf(at + Vector3(0, 0.08, 0), yaw), 0.04)
		bevel(bronze, Vector3(0.2, 0.06, 0.24), _xf(at + Vector3(0, 0.18, 0), yaw), 0.02)
		clamps.append(at + Vector3(0, 0.215, 0))
	var seal_mat := lamp_mat(Color("#ffb46a"), 1.6)
	var lens := SphereMesh.new()
	lens.radius = 0.035
	lens.height = 0.04
	lens.radial_segments = 10
	lens.rings = 4
	var ls := SurfaceTool.new()
	ls.begin(Mesh.PRIMITIVE_TRIANGLES)
	for at2: Vector3 in clamps:
		ls.append_from(lens, 0, Transform3D(Basis.IDENTITY, at2))
	var lmi := MeshInstance3D.new()
	lmi.name = "SealLamps"
	lmi.mesh = ls.commit()
	lmi.material_override = seal_mat
	lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(lmi)
	# the restraint cage: five hoops over the bed on a common axle at its head; turns back to open ("Hoops")
	var hinge := Node3D.new()
	hinge.name = "Hoops"
	hinge.position = Vector3(0, 0.33, -half + 0.12)
	root.add_child(hinge)
	var hs := SurfaceTool.new()
	hs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hd := SurfaceTool.new()
	hd.begin(Mesh.PRIMITIVE_TRIANGLES)
	tube(hd, [Vector3(-BED_W * 0.5 - 0.13, 0, 0), Vector3(BED_W * 0.5 + 0.13, 0, 0)], 0.045, 8)
	for sx4: float in [-1.0, 1.0]:
		tube(hd, [Vector3(sx4 * (BED_W * 0.5 + 0.1), 0, 0), Vector3(sx4 * (BED_W * 0.5 + 0.1), 0.02, BED_LEN - 0.4)], 0.03, 6)
	for hcount in 4:
		var z3 := 0.42 + hcount * 0.48
		var hp: Array = []
		for s2 in 13:
			var t2 := float(s2) / 12.0
			var ha := PI * t2
			hp.append(Vector3(-cos(ha) * (BED_W * 0.5 + 0.1), sin(ha) * 0.62, z3))
		tube(hs, hp, 0.034, 6)
		bevel(hd, Vector3(0.14, 0.05, 0.1), _xf(Vector3(0, 0.62, z3)), 0.015)
	var hmi := MeshInstance3D.new()
	hmi.name = "HoopsBronze"
	hmi.mesh = hs.commit()
	hmi.material_override = mat("bronze")
	hinge.add_child(hmi)
	var hdi := MeshInstance3D.new()
	hdi.name = "HoopsFrame"
	hdi.mesh = hd.commit()
	hdi.material_override = mat("dark")
	hinge.add_child(hdi)

## The console at the cradle's side: a lectern with a slanted face, a dim readout, keys and a lever.
static func _console(k: Kit) -> void:
	var at := Vector3(-1.55, 0, 1.25)
	var x := _xf(at, -62.0)
	bevel(k.sf("dark"), Vector3(0.42, 0.86, 0.36), x * _xf(Vector3(0, 0.43, 0)), 0.04)
	bevel(k.sf("dark"), Vector3(0.6, 0.1, 0.5), x * _xf(Vector3(0, 0.05, 0)), 0.03)
	bevel(k.sf("ceramic"), Vector3(0.72, 0.08, 0.5), x * _xf(Vector3(0, 0.96, 0.03), 0.0, 32.0), 0.03)
	for b in 5:
		bevel(k.sf("bronze"), Vector3(0.06, 0.03, 0.05), x * _xf(Vector3(-0.22 + b * 0.11, 1.0, 0.18) + Vector3(0, -0.06, 0.0), 0.0, 32.0), 0.008)
	tube(k.sf("bronze"), [x * Vector3(0.3, 0.98, -0.1), x * Vector3(0.33, 1.22, -0.02)], 0.015, 5)
	var knob := SphereMesh.new()
	knob.radius = 0.035
	knob.height = 0.07
	knob.radial_segments = 8
	knob.rings = 4
	prim(k.sf("dark"), knob, x * _xf(Vector3(0.33, 1.24, -0.015)))

## The readout on the console: a small dim panel of the makers' circuit pattern (unshaded, low).
static func _readout(a: Arena) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.22)
	var mi := MeshInstance3D.new()
	mi.name = "Readout"
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _tex("res://assets/models/gear/tex/eng_circuit_a.png")
	m.albedo_color = Color(0.32, 0.46, 0.44)
	m.uv1_scale = Vector3(1.0, 0.45, 1.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var x := _xf(Vector3(-1.55, 0, 1.25), -62.0) * _xf(Vector3(0, 1.005, 0.03), 0.0, 32.0 - 90.0)
	mi.transform = x
	a.add_child(mi)

# ---------------------------------------------------------------- the sword holder
static func _holder(a: Arena, k: Kit) -> void:
	var rack := Node3D.new()
	rack.name = "Rack"
	rack.position = HOLDER_AT
	rack.rotation_degrees.y = HOLDER_YAW
	a.add_child(rack)
	var x := Transform3D(rack.transform.basis, HOLDER_AT)
	var dark := k.sf("dark")
	var bronze := k.sf("bronze")
	var cer := k.sf("ceramic")
	# a stepped round plinth
	for st: Array in [[0.62, 0.0, 0.07, "dark"], [0.5, 0.07, 0.07, "bronze"], [0.36, 0.14, 0.06, "dark"]]:
		var c := CylinderMesh.new()
		c.top_radius = st[0] - 0.02
		c.bottom_radius = st[0]
		c.height = st[2]
		c.radial_segments = 24
		c.rings = 1
		prim(k.sf(st[3]), c, x * _xf(Vector3(0, float(st[1]) + float(st[2]) * 0.5, 0)))
	# the slotted block the point stands in
	bevel(dark, Vector3(0.24, SLOT_TOP - 0.2, 0.3), x * _xf(Vector3(0, 0.2 + (SLOT_TOP - 0.2) * 0.5, 0)), 0.04)
	bevel(bronze, Vector3(0.28, 0.04, 0.34), x * _xf(Vector3(0, SLOT_TOP - 0.01, 0)), 0.012)
	# the frame behind: two posts and an arched head, engraved bronze between, a hood over the lamp
	var back := -0.42
	for sx: float in [-1.0, 1.0]:
		bevel(dark, Vector3(0.12, 2.15, 0.14), x * _xf(Vector3(sx * 0.42, 1.075 + 0.2, back)), 0.03)
	var arch: Array = []
	for s in 11:
		var t := float(s) / 10.0
		arch.append(x * Vector3(-0.42 + 0.84 * t, 2.35 + sin(t * PI) * 0.22, back))
	tube(dark, arch, 0.07, 6)
	bevel(bronze, Vector3(0.66, 1.7, 0.03), x * _xf(Vector3(0, 1.3, back + 0.02)), 0.01)
	for r in 6:
		bevel(dark, Vector3(0.56, 0.015, 0.012), x * _xf(Vector3(0, 0.62 + r * 0.27, back + 0.04)), 0.004)
	# the lamp: a hooded head on an arm that reaches forward from the arch, so its light falls on the blade's face
	tube(dark, bez(x * Vector3(0, 2.5, back), x * Vector3(0, 2.75, back + 0.2), x * Vector3(0, 2.7, 0.45), x * Vector3(0, 2.45, 0.62), 10), 0.03, 6)
	bevel(cer, Vector3(0.26, 0.12, 0.3), x * _xf(Vector3(0, 2.42, 0.66), 0.0, 38.0), 0.03)
	# the clamp arms: they rise from the plinth and close on the blade; they part when it is taken
	for sx2: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ClampL" if sx2 < 0.0 else "ClampR"
		arm.position = Vector3(sx2 * 0.2, 0.2, 0)
		rack.add_child(arm)
		var asf := SurfaceTool.new()
		asf.begin(Mesh.PRIMITIVE_TRIANGLES)
		tube(asf, bez(Vector3.ZERO, Vector3(sx2 * 0.12, 0.2, 0), Vector3(sx2 * 0.06, 0.42, 0), Vector3(-sx2 * 0.13, 0.5, 0), 10), 0.028, 6)
		bevel(asf, Vector3(0.05, 0.12, 0.08), _xf(Vector3(-sx2 * 0.155, 0.5, 0)), 0.012)
		var ami := MeshInstance3D.new()
		ami.mesh = asf.commit()
		ami.material_override = mat("bronze")
		arm.add_child(ami)
	# the point of the blade stands here (Awakening stands the sword on it)
	var spot := Node3D.new()
	spot.name = "SwordPoint"
	spot.position = Vector3(0, SLOT_TOP, 0)
	rack.add_child(spot)

# ---------------------------------------------------------------- the Witness's housing
static func _housing(a: Arena, k: Kit) -> void:
	var bx := bay_xf(HOUSING_BAY)
	var dark := k.sf("dark")
	var cer := k.sf("ceramic")
	var bronze := k.sf("bronze")
	var cable := k.sf("cable")
	var root := Node3D.new()
	root.name = "Housing"
	root.transform = bx * _xf(Vector3(0, 0, 0.42))
	a.add_child(root)
	# a maintenance cradle bolted to the wall: a ribbed back plate, a rounded ceramic body half sunk in it, a round
	# opening with a bronze rim, and in it the cup the instrument was left in
	bevel(dark, Vector3(1.0, 2.0, 0.16), bx * _xf(Vector3(0, 1.3, 0.0)), 0.05)
	for r in 5:
		bevel(dark, Vector3(1.08, 0.06, 0.06), bx * _xf(Vector3(0, 0.45 + r * 0.42, 0.1)), 0.015)
	var body := CapsuleMesh.new()
	body.radius = 0.3
	body.height = 1.25
	body.radial_segments = 20
	body.rings = 6
	prim(cer, body, bx * Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.72)), Vector3(0, 1.3, 0.16)))
	tube(bronze, arc_pts(0.17, 0.0, 0.0, TAU, 24).map(func(v: Vector3) -> Vector3: return bx * (Vector3(v.x, v.z, 0) + Vector3(0, 1.3, 0.385))), 0.025, 6)
	var hole := CylinderMesh.new()
	hole.top_radius = 0.16
	hole.bottom_radius = 0.16
	hole.height = 0.04
	hole.radial_segments = 20
	hole.rings = 1
	prim(dark, hole, bx * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.3, 0.37)))
	var cup := SphereMesh.new()
	cup.radius = 0.09
	cup.height = 0.09
	cup.is_hemisphere = true
	cup.radial_segments = 14
	cup.rings = 5
	prim(dark, cup, bx * Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 1.27, 0.42)))
	tube(bronze, arc_pts(0.1, 0.0, 0.0, TAU, 16).map(func(v: Vector3) -> Vector3: return bx * (v + Vector3(0, 1.275, 0.42))), 0.012, 5)
	# a lens over the opening's crown, cracked, and a plate of the makers' engraving under it
	bevel(bronze, Vector3(0.26, 0.12, 0.04), bx * _xf(Vector3(0, 0.82, 0.36), 0.0, -12.0), 0.012)
	# its feed: a conduit up the wall from the trench, cables in at the top
	tube(dark, [bx * Vector3(0.38, 0.0, 0.12), bx * Vector3(0.38, 0.9, 0.12), bx * Vector3(0.3, 1.0, 0.2)], 0.05, 6)
	tube(cable, bez(bx * Vector3(-0.12, 1.86, 0.2), bx * Vector3(-0.15, 2.3, 0.25), bx * Vector3(-0.35, 2.9, 0.0), bx * Vector3(-0.42, 3.4, -0.15), 10), 0.03, 6)
	tube(cable, bez(bx * Vector3(0.12, 1.86, 0.2), bx * Vector3(0.18, 2.4, 0.3), bx * Vector3(0.4, 3.0, 0.0), bx * Vector3(0.5, 3.4, -0.15), 10), 0.025, 6)
	# the failing lamp under the cup: a small lens that flickers (Awakening drives it)
	var lens := MeshInstance3D.new()
	lens.name = "HousingLens"
	var lm := SphereMesh.new()
	lm.radius = 0.028
	lm.height = 0.03
	lm.radial_segments = 10
	lm.rings = 4
	lens.mesh = lm
	lens.material_override = lamp_mat(Color("#ffb060"), 0.6)
	lens.position = Vector3(0, 1.55, -0.07)
	root.add_child(lens)
	# the cover that closes over the cup (slides up into the body to open) and the two prongs that hold the instrument
	var cover := MeshInstance3D.new()
	cover.name = "HousingCover"
	var cs := SurfaceTool.new()
	cs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lid := SphereMesh.new()
	lid.radius = 0.17
	lid.height = 0.17
	lid.is_hemisphere = true
	lid.radial_segments = 20
	lid.rings = 5
	prim(cs, lid, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.0, 1.0, 0.45)), Vector3.ZERO))
	tube(cs, arc_pts(0.165, 0.0, 0.0, TAU, 20).map(func(v: Vector3) -> Vector3: return Vector3(v.x, v.z, 0.0)), 0.012, 5)
	cover.mesh = cs.commit()
	cover.material_override = mat("ceramic")
	cover.position = Vector3(0, 1.3, 0.0)
	root.add_child(cover)
	var prongs := Node3D.new()
	prongs.name = "HousingClamps"
	prongs.position = Vector3(0, 1.27, 0.0)
	root.add_child(prongs)
	for sx: float in [-1.0, 1.0]:
		var p := MeshInstance3D.new()
		p.name = "Prong" + ("L" if sx < 0.0 else "R")
		var ps := SurfaceTool.new()
		ps.begin(Mesh.PRIMITIVE_TRIANGLES)
		tube(ps, bez(Vector3(sx * 0.13, -0.05, -0.02), Vector3(sx * 0.13, 0.0, 0.02), Vector3(sx * 0.1, 0.02, 0.03), Vector3(sx * 0.06, 0.0, 0.03), 6), 0.011, 5)
		p.mesh = ps.commit()
		p.material_override = mat("bronze")
		prongs.add_child(p)

# ---------------------------------------------------------------- Lyra's grille
static func _grille(a: Arena, k: Kit) -> void:
	var bx := bay_xf(GRILLE_BAY)
	var g := Vector3(0, 2.55, 0.12)
	bevel(k.sf("dark"), Vector3(1.0, 1.0, 0.16), bx * _xf(g + Vector3(0, 0, -0.06)), 0.05)
	tube(k.sf("bronze"), arc_pts(0.38, 0.0, 0.0, TAU, 28).map(func(v: Vector3) -> Vector3: return bx * (Vector3(v.x, v.z, 0) + g + Vector3(0, 0, 0.04))), 0.035, 6)
	for s in 7:
		var y := -0.27 + s * 0.09
		var half := sqrt(maxf(0.0, 0.34 * 0.34 - y * y))
		bevel(k.sf("dark"), Vector3(half * 2.0, 0.025, 0.05), bx * _xf(g + Vector3(0, y, 0.03), 0.0, 25.0), 0.006)
	tube(k.sf("cable"), bez(bx * (g + Vector3(0.3, 0.4, -0.02)), bx * (g + Vector3(0.5, 0.9, 0.0)), bx * (g + Vector3(0.4, 1.0, -0.2)), bx * (g + Vector3(0.6, 1.2, -0.3)), 8), 0.025, 5)

# ---------------------------------------------------------------- the door
static func _door(a: Arena, k: Kit) -> void:
	var dark := k.sf("dark")
	var plate := k.sf("plate")
	var bronze := k.sf("bronze")
	var z := DOOR_Z
	var hw := DOOR_W * 0.5
	# the portal: two massive chamfered jambs, the lintel with the slab's housing above it, an engraved bronze lintel plate
	for sx: float in [-1.0, 1.0]:
		bevel(dark, Vector3(0.6, WALL_H + 0.2, 1.1), _xf(Vector3(sx * (hw + 0.3), (WALL_H + 0.2) * 0.5, z + 0.05)), 0.08)
		bevel(plate, Vector3(0.38, DOOR_H - 0.3, 0.06), _xf(Vector3(sx * (hw + 0.32), DOOR_H * 0.5 + 0.1, z + 0.62)), 0.02)
		bevel(bronze, Vector3(0.66, 0.3, 1.16), _xf(Vector3(sx * (hw + 0.3), 0.15, z + 0.05)), 0.04)
		for b in 6:
			bevel(dark, Vector3(0.05, 0.05, 0.04), _xf(Vector3(sx * (hw + 0.12), 0.5 + b * 0.5, z + 0.62)), 0.012)
	bevel(dark, Vector3(DOOR_W + 1.3, WALL_H + 1.4 - DOOR_H, 1.1), _xf(Vector3(0, DOOR_H + (WALL_H + 1.4 - DOOR_H) * 0.5, z + 0.05)), 0.08)
	bevel(bronze, Vector3(DOOR_W + 0.4, 0.34, 0.08), _xf(Vector3(0, DOOR_H + 0.3, z + 0.62)), 0.03)
	bevel(dark, Vector3(DOOR_W + 0.2, 0.06, 0.04), _xf(Vector3(0, DOOR_H + 0.3, z + 0.67)), 0.01)
	# the slab: heavy, ribbed, with a bronze lock rail; it runs in the jambs' grooves
	var slab := Node3D.new()
	slab.name = "Door"
	slab.position = Vector3(0, 1.65, z)
	a.add_child(slab)
	var ss := SurfaceTool.new()
	ss.begin(Mesh.PRIMITIVE_TRIANGLES)
	bevel(ss, Vector3(DOOR_W + 0.1, DOOR_H, 0.3), Transform3D.IDENTITY, 0.04)
	var sd := SurfaceTool.new()
	sd.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in 4:
		bevel(sd, Vector3(DOOR_W - 0.2, 0.14, 0.12), _xf(Vector3(0, -1.2 + r * 0.8, 0.18)), 0.03)
	for sx2: float in [-1.0, 1.0]:
		bevel(sd, Vector3(0.16, DOOR_H - 0.3, 0.1), _xf(Vector3(sx2 * (hw - 0.25), 0, 0.17)), 0.03)
	var smi := MeshInstance3D.new()
	smi.name = "Slab"
	smi.mesh = ss.commit()
	smi.material_override = mat("plate")
	slab.add_child(smi)
	var sdi := MeshInstance3D.new()
	sdi.name = "SlabRibs"
	sdi.mesh = sd.commit()
	sdi.material_override = mat("dark")
	slab.add_child(sdi)
	# lock bars across it, in brackets on the jambs: they draw back into the jambs before the slab can rise
	var bars := Node3D.new()
	bars.name = "DoorBars"
	bars.position = Vector3(0, 0, z + 0.42)
	a.add_child(bars)
	# (two half-bars at each height, meeting in the middle; drawn back they run into the jambs and behind the plating)
	var bs := SurfaceTool.new()
	bs.begin(Mesh.PRIMITIVE_TRIANGLES)
	bevel(bs, Vector3(hw + 0.04, 0.12, 0.1), Transform3D.IDENTITY, 0.03)
	bevel(bs, Vector3(0.1, 0.18, 0.14), _xf(Vector3(-(hw + 0.04) * 0.5 + 0.06, 0, 0.0)), 0.02)
	var bar_mesh := bs.commit()
	for b2 in 2:
		for sx4: float in [-1.0, 1.0]:
			var bar := MeshInstance3D.new()
			bar.name = "Bar%d%s" % [b2, "L" if sx4 < 0.0 else "R"]
			bar.mesh = bar_mesh
			bar.material_override = mat("bronze")
			bar.rotation_degrees.y = 0.0 if sx4 < 0.0 else 180.0
			bar.set_meta("shut_x", sx4 * (hw * 0.5 + 0.02))
			bar.set_meta("open_x", sx4 * (hw * 0.5 + 1.32))
			bar.position = Vector3(float(bar.get_meta("open_x")), 1.0 + b2 * 1.25, 0)      # drawn back: lock_door_now() runs them across
			bars.add_child(bar)
	for b3 in 2:
		for sx3: float in [-1.0, 1.0]:
			bevel(dark, Vector3(0.22, 0.26, 0.2), _xf(Vector3(sx3 * (hw + 0.12), 1.0 + b3 * 1.25, z + 0.48)), 0.03)
	# the status lamp over the door
	var lamp := MeshInstance3D.new()
	lamp.name = "DoorLampLens"
	var lm := SphereMesh.new()
	lm.radius = 0.06
	lm.height = 0.07
	lm.radial_segments = 12
	lm.rings = 5
	lamp.mesh = lm
	lamp.material_override = lamp_mat(Color("#ff7a3a"), 1.8)
	lamp.position = Vector3(0, DOOR_H + 0.62, z + 0.66)
	a.add_child(lamp)
	bevel(dark, Vector3(0.24, 0.16, 0.12), _xf(Vector3(0, DOOR_H + 0.7, z + 0.62)), 0.03)

# ---------------------------------------------------------------- the passage out
static func _passage(a: Arena, k: Kit) -> void:
	var dark := k.sf("dark")
	var plate := k.sf("plate")
	var bronze := k.sf("bronze")
	var cable := k.sf("cable")
	var z0 := DOOR_Z - 0.5
	var z1 := PASSAGE_END
	var hw := 1.3
	var h := 3.3
	var len := z0 - z1
	var mid := (z0 + z1) * 0.5
	for sx: float in [-1.0, 1.0]:
		bevel(dark, Vector3(0.3, h + 0.4, len), _xf(Vector3(sx * (hw + 0.35), (h + 0.4) * 0.5, mid)), 0.03)
		# wall plates in a run, one hanging off
		var n := int(len / 1.2)
		for p in n:
			var zz := z0 - 0.6 - p * 1.2
			var off := p == 2 and sx > 0.0
			bevel(plate, Vector3(0.08, 1.6, 1.1), _xf(Vector3(sx * (hw + 0.12), 1.5, zz), 0.0, 0.0, (14.0 if off else 0.0) * sx), 0.02)
			bevel(plate, Vector3(0.08, 0.7, 1.1), _xf(Vector3(sx * (hw + 0.12), 0.38, zz)), 0.02)
		# pipes along both walls
		tube(dark, [Vector3(sx * (hw + 0.05), 2.55, z0), Vector3(sx * (hw + 0.05), 2.55, z1)], 0.06, 8)
		tube(bronze, [Vector3(sx * (hw + 0.0), 2.75, z0), Vector3(sx * (hw + 0.0), 2.75, z1)], 0.035, 6)
	bevel(dark, Vector3(hw * 2.0 + 1.0, 0.3, len), _xf(Vector3(0, h + 0.15, mid)), 0.03)
	for p2 in int(len / 1.2):
		bevel(plate, Vector3(hw * 2.0 - 0.1, 0.06, 1.1), _xf(Vector3(0, h - 0.03, z0 - 0.6 - p2 * 1.2)), 0.02)
	# frames across it every 1.6 m
	var f := z0 - 0.4
	while f > z1 + 0.3:
		for sx2: float in [-1.0, 1.0]:
			bevel(dark, Vector3(0.24, h, 0.3), _xf(Vector3(sx2 * (hw - 0.05), h * 0.5, f)), 0.04)
		bevel(dark, Vector3(hw * 2.0, 0.3, 0.3), _xf(Vector3(0, h - 0.15, f)), 0.04)
		f -= 1.6
	# a cable sagging across the ceiling, a fallen ceiling plate leaning on the wall, debris
	tube(cable, hang(Vector3(-hw, 3.0, z0 - 2.0), Vector3(hw, 2.9, z0 - 3.4), 0.6), 0.035, 6)
	tube(cable, hang(Vector3(-hw, 2.8, z0 - 4.0), Vector3(-0.3, 0.04, z0 - 4.8), -0.2), 0.03, 6)
	bevel(plate, Vector3(1.1, 0.06, 1.0), _xf(Vector3(-hw + 0.35, 0.55, z0 - 3.9), 10.0, 0.0, 62.0), 0.02)
	# the outer doorway: its frame, and one leaf of an old door torn half off
	for sx3: float in [-1.0, 1.0]:
		bevel(dark, Vector3(0.5, h + 0.4, 0.7), _xf(Vector3(sx3 * (hw - 0.1), (h + 0.4) * 0.5, z1)), 0.06)
	bevel(dark, Vector3(hw * 2.0 + 0.4, 0.6, 0.7), _xf(Vector3(0, h + 0.1, z1)), 0.06)
	bevel(plate, Vector3(1.2, 2.8, 0.12), _xf(Vector3(hw - 0.55, 1.45, z1 + 0.5), -48.0, 0.0, -9.0), 0.03)
	# daylight beyond (Prologue and Awakening use "Daylight" and "DoorGlow")
	var day := MeshInstance3D.new()
	day.name = "Daylight"
	var q := BoxMesh.new()
	q.size = Vector3(hw * 2.0 - 0.6, h - 0.3, 0.1)
	day.mesh = q
	day.material_override = Look.glow(Color("#f6eedc"), 3.2)
	day.position = Vector3(0, (h - 0.3) * 0.5, z1 - 0.6)
	day.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(day)

# ---------------------------------------------------------------- the others
static func _pods(a: Arena) -> void:
	if Future.old_world:
		return
	for spec: Array in [[4, 2.5], [9, 2.4]]:
		var d := bay_dir(int(spec[0]))
		var yaw := rad_to_deg(atan2(-d.x, -d.z))
		var pod := Future.prop(a, "fu_pod", float(spec[1]), d * (R - 0.75), yaw, 0.0, 0)
		if pod == null:
			continue
		pod.name = "Pod%d" % int(spec[0])
		# the kit paints its light lines cyan: here they are dead
		for mi: MeshInstance3D in pod.find_children("*", "MeshInstance3D", true, false):
			for si in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(si) as ShaderMaterial
				if m != null:
					m.set_shader_parameter("seam", Color(0.12, 0.08, 0.05))
					m.set_shader_parameter("tint", Color(0.62, 0.6, 0.56))

# ================================================================ light
## A few shaped lights and a lifted ambient, so the room is dark without being black: the oculus key on the
## cradle, a small hooded spot on the sword, the failing lamps of the housing, the grille and the door, a cool bounce
## high in the room, and two caged maintenance lamps. Dust hangs in the key's beam.
static func _lights(a: Arena) -> void:
	var env := a.env
	env.ambient_light_color = Color("#3e4744")
	env.ambient_light_energy = 1.6
	env.fog_light_color = Color("#1e2624")
	env.fog_density = 0.028
	env.tonemap_exposure = 1.55
	a.sun.light_energy = 0.0
	a.sun.shadow_enabled = false
	_readout(a)
	var key := SpotLight3D.new()
	key.name = "Key"
	key.light_color = Color("#ffd9aa")
	key.light_energy = 5.0
	key.spot_range = 8.5
	key.spot_angle = 30.0
	key.spot_attenuation = 0.7
	key.shadow_enabled = true
	key.shadow_blur = 1.6
	key.position = Vector3(0.0, CROWN - 0.95, CRADLE_AT.z * 0.5)
	a.add_child(key)
	key.look_at(CRADLE_AT + Vector3(0.15, 0.2, 0.35))
	var rack := SpotLight3D.new()
	rack.name = "RackLight"
	rack.light_color = Color("#ffe2b8")
	rack.light_energy = 0.0
	rack.spot_range = 4.2
	rack.spot_angle = 26.0
	rack.spot_attenuation = 0.6
	rack.shadow_enabled = false
	var rx := Transform3D(Basis(Vector3.UP, deg_to_rad(HOLDER_YAW)), HOLDER_AT)
	rack.position = rx * Vector3(0, 2.36, 0.62)
	a.add_child(rack)
	rack.look_at(HOLDER_AT + Vector3(0, 0.85, 0))
	var ly := OmniLight3D.new()
	ly.name = "Lyra"
	ly.light_color = Color("#a8e6dc")
	ly.light_energy = 0.0
	ly.omni_range = 3.2
	ly.position = grille_at() - bay_dir(GRILLE_BAY) * 0.35
	a.add_child(ly)
	var wl := OmniLight3D.new()
	wl.name = "WitnessLamp"
	wl.light_color = Color("#ffb46a")
	wl.light_energy = 0.12
	wl.omni_range = 1.4
	wl.position = housing_cup() - bay_dir(HOUSING_BAY) * 0.15
	a.add_child(wl)
	var dl := OmniLight3D.new()
	dl.name = "DoorLamp"
	dl.light_color = Color("#ff9a5a")
	dl.light_energy = 0.3
	dl.omni_range = 3.2
	dl.position = Vector3(0, DOOR_H + 0.55, DOOR_Z + 0.9)
	a.add_child(dl)
	var dg := OmniLight3D.new()
	dg.name = "DoorGlow"
	dg.light_color = Color("#fff0d8")
	dg.light_energy = 0.0
	dg.omni_range = 9.0
	dg.omni_attenuation = 0.9
	dg.position = Vector3(0, 2.4, PASSAGE_END + 1.2)
	a.add_child(dg)
	var bounce := OmniLight3D.new()
	bounce.name = "Bounce"
	bounce.light_color = Color("#b4c4c0")
	bounce.light_energy = 0.7
	bounce.omni_range = 10.0
	bounce.omni_attenuation = 1.4
	bounce.light_specular = 0.15
	bounce.position = Vector3(0.6, 3.3, 2.2)
	a.add_child(bounce)
	for spec: Array in [[2, Color("#ffcf96")], [10, Color("#d8e6e0")]]:
		var bx := bay_xf(int(spec[0]))
		var m := OmniLight3D.new()
		m.name = "Maint%d" % int(spec[0])
		m.light_color = spec[1]
		m.light_energy = 1.1
		m.omni_range = 4.6
		m.position = bx * Vector3(0, 3.05, 0.45)
		a.add_child(m)
		# the fixture: a caged lamp on a bracket
		var cage := MeshInstance3D.new()
		var cs := SurfaceTool.new()
		cs.begin(Mesh.PRIMITIVE_TRIANGLES)
		bevel(cs, Vector3(0.2, 0.1, 0.24), _xf(Vector3(0, 0.12, -0.12)), 0.02)
		for s in 4:
			var aa := TAU * s / 4.0 + 0.4
			tube(cs, bez(Vector3(sin(aa) * 0.08, 0.08, cos(aa) * 0.08), Vector3(sin(aa) * 0.11, 0.0, cos(aa) * 0.11), Vector3(sin(aa) * 0.1, -0.12, cos(aa) * 0.1), Vector3(0, -0.15, 0), 5), 0.008, 4)
		cage.mesh = cs.commit()
		cage.material_override = mat("dark")
		cage.position = bx * Vector3(0, 3.1, 0.3)
		cage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		a.add_child(cage)
		var bulb := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.05
		bm.height = 0.1
		bm.radial_segments = 10
		bm.rings = 5
		bulb.mesh = bm
		bulb.material_override = lamp_mat(spec[1], 1.4)
		bulb.position = bx * Vector3(0, 3.06, 0.3)
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		a.add_child(bulb)
	shaft(a, "KeyShaft", key.position, CRADLE_AT + Vector3(0.1, 0.0, 0.3), 0.45, 1.9, Color("#ffd9aa"), 0.09)
	shaft(a, "DoorShaft", Vector3(0, 2.4, DOOR_Z - 0.4), Vector3(0, 0.0, DOOR_Z + 2.6), 2.2, 3.4, Color("#fff2dc"), 0.0)

## Dust hanging in a beam from `from` to `to` (a card that turns to the lens; see chamber_shaft.gdshader).
static func shaft(a: Arena, node_name: String, from: Vector3, to: Vector3, top_w: float, bottom_w: float, c: Color, strength: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := ShaderMaterial.new()
	m.shader = load("res://src/world/chamber_shaft.gdshader")
	m.set_shader_parameter("tint", c)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("top_w", top_w)
	m.set_shader_parameter("bottom_w", bottom_w)
	m.set_shader_parameter("noise_tex", Highland._noise_tex())
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var axis := to - from
	var side := axis.cross(Vector3.FORWARD if absf(axis.normalized().z) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(side, axis, side.cross(axis).normalized()), from)
	mi.custom_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	a.add_child(mi)
	return mi

# ================================================================ what the scenes do with it
## The seal lets go: the clamp lamps go out, the cage swings back off the bed. Returns the time it takes.
static func release_seal(a: Arena, time: float = 2.2) -> float:
	var lamps := a.get_node_or_null("SealLamps") as MeshInstance3D
	if lamps:
		var m := lamps.material_override as StandardMaterial3D
		var tw0 := a.create_tween()
		tw0.tween_property(m, "emission_energy_multiplier", 0.0, 0.5)
		tw0.parallel().tween_property(m, "albedo_color", Color(0.18, 0.12, 0.08), 0.5)
	var hoops := a.get_node_or_null("Cradle/Hoops") as Node3D
	if hoops:
		var tw := a.create_tween()
		tw.tween_interval(0.5)
		tw.tween_property(hoops, "rotation_degrees:x", -118.0, time - 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return time

static func seal_open_now(a: Arena) -> void:
	var hoops := a.get_node_or_null("Cradle/Hoops") as Node3D
	if hoops:
		hoops.rotation_degrees.x = -118.0
	var lamps := a.get_node_or_null("SealLamps") as MeshInstance3D
	if lamps:
		(lamps.material_override as StandardMaterial3D).emission_energy_multiplier = 0.0
		(lamps.material_override as StandardMaterial3D).albedo_color = Color(0.18, 0.12, 0.08)

## The holder lets go of the blade: the clamp arms swing apart.
static func open_clamps(a: Arena, time: float = 0.45) -> void:
	for n: String in ["Rack/ClampL", "Rack/ClampR"]:
		var c := a.get_node_or_null(n) as Node3D
		if c:
			var s := -1.0 if n.ends_with("L") else 1.0
			a.create_tween().tween_property(c, "rotation_degrees:z", s * -38.0, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The lock bars draw back into the jambs, then the slab rises into the lintel; the lamp over it turns pale and the
## daylight comes through. Returns the time it takes.
static func open_door(a: Arena, time: float = 3.2) -> float:
	var bars := a.get_node_or_null("DoorBars") as Node3D
	var door := a.get_node_or_null("Door") as Node3D
	var tw := a.create_tween()
	if bars:
		for b: Node3D in bars.get_children():
			tw.parallel().tween_property(b, "position:x", float(b.get_meta("open_x")), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.25)
	if door:
		tw.tween_property(door, "position:y", 5.2, time - 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var lamp := a.get_node_or_null("DoorLampLens") as MeshInstance3D
	var dl := a.get_node_or_null("DoorLamp") as OmniLight3D
	if lamp:
		var lm := lamp.material_override as StandardMaterial3D
		a.create_tween().tween_property(lm, "emission", Color("#e8f2e6"), 0.6)
	if dl:
		a.create_tween().tween_property(dl, "light_color", Color("#dcefe6"), 0.6)
	var glow := a.get_node_or_null("DoorGlow") as OmniLight3D
	if glow:
		a.create_tween().tween_property(glow, "light_energy", 3.2, time).set_delay(0.9)
	var sh := a.get_node_or_null("DoorShaft") as MeshInstance3D
	if sh:
		a.create_tween().tween_method(func(v: float): (sh.material_override as ShaderMaterial).set_shader_parameter("strength", v), 0.0, 0.07, time).set_delay(1.2)
	return time

## The door as it is left open (HeirReturn walks in through it).
static func door_open_now(a: Arena) -> void:
	var bars := a.get_node_or_null("DoorBars") as Node3D
	if bars:
		for b: Node3D in bars.get_children():
			b.position.x = float(b.get_meta("open_x"))
	var door := a.get_node_or_null("Door") as Node3D
	if door:
		door.position.y = 5.2
	var glow := a.get_node_or_null("DoorGlow") as OmniLight3D
	if glow:
		glow.light_energy = 3.2
	var lamp := a.get_node_or_null("DoorLampLens") as MeshInstance3D
	if lamp:
		(lamp.material_override as StandardMaterial3D).emission = Color("#e8f2e6")
	var sh := a.get_node_or_null("DoorShaft") as MeshInstance3D
	if sh:
		(sh.material_override as ShaderMaterial).set_shader_parameter("strength", 0.07)

## The lock bars run across the slab (the door as the Awakening finds it: shut and barred).
static func lock_door_now(a: Arena) -> void:
	var bars := a.get_node_or_null("DoorBars") as Node3D
	if bars:
		for b: Node3D in bars.get_children():
			b.position.x = float(b.get_meta("shut_x"))
	var door := a.get_node_or_null("Door") as Node3D
	if door:
		door.position.y = 1.65

## Stage 3 hand-off: the transform that carries a point of this room into a world whose door is at `entry`, facing
## `entry_yaw` (radians; 0 faces -Z), so that EXIT_END lands on it. E.g. CourtRoute: to_world(CourtRoute.ENTRY,
## CourtRoute.ENTRY_YAW) * knight.position is where the knight stands on the route when the passage ends.
static func to_world(entry: Vector3, entry_yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, entry_yaw), entry) * EXIT_END.affine_inverse()
