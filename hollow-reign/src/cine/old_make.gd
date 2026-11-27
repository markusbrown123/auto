class_name OldMake
extends RefCounted
## Machinery of the old make, built in code from turned and extruded shapes (no model files): the great rings, the
## racks of stored minds, the restoration engines, pipe runs, the ribs of a vault and a framed door. The story scenes
## under the throne (facility.gd, final_hall.gd, second_fall.gd, aftermath.gd, ending_scene.gd) are dressed from it,
## so the same construction is seen wherever the Crown's works show.
## Lamps are FinalHall.lamp materials: dark at energy 0, so a scene can wake them and run them down.

static func metal(c: Color = Color("#22262a"), rough: float = 0.42) -> StandardMaterial3D:
	return Look.flat(c, rough, 0.9)

static func _add(parent: Node, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(parent, m, pos, mat, rot)

static func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, sides: int = 12, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	return _add(parent, m, pos, mat, rot)

static func torus(parent: Node, radius: float, tube: float, pos: Vector3, mat: Material, around: int = 48, across: int = 10) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = maxf(radius - tube, 0.01)
	m.outer_radius = radius + tube
	m.rings = around
	m.ring_segments = across
	return _add(parent, m, pos, mat)

## A pipe from `a` to `b` (in the parent's space).
static func pipe(parent: Node, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var d := b - a
	var mi := cyl(parent, r, r, maxf(d.length(), 0.01), a + d * 0.5, mat, 8)
	if d.length() > 0.001:
		var up := d.normalized()
		var side := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
		mi.basis = Basis(side, up, side.cross(up))
	return mi

## A great ring: a true torus with a band of machine light let into its inner face and clamps bolted round it (one
## gap in their spacing, so the ring is seen to turn). It lies flat (about Y) or, `standing`, faces down the hall
## (about Z). Spin the returned node about that axis.
static func ring(parent: Node, radius: float, tube: float, lamp_mat: Material, clamps: int = 9, standing: bool = false, body: Material = null) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var hold := Node3D.new()
	n.add_child(hold)
	if standing:
		hold.rotation.x = PI * 0.5
	var mat: Material = body if body != null else metal()
	torus(hold, radius, tube, Vector3.ZERO, mat)
	var band := torus(hold, radius - tube * 0.86, tube * 0.3, Vector3.ZERO, lamp_mat, 48, 6)
	band.scale.y = 0.5
	for i: int in clamps + 1:
		if i == 2:
			continue
		var a := TAU * i / float(clamps + 1)
		var dir := Vector3(sin(a), 0, cos(a))
		box(hold, Vector3(tube * 1.5, tube * 2.5, tube * 2.9), dir * radius, mat, Vector3(0, a, 0))
		box(hold, Vector3(tube * 0.5, tube * 0.3, tube * 0.5), dir * (radius - tube * 1.25) + Vector3(0, tube * 0.9, 0), lamp_mat, Vector3(0, a, 0))
	return n

## A rack of stored minds: four posts, shelves, a row of cells on each shelf with its strip of light (some cells
## pulled), cable runs off the top. `size` is its whole box; it stands on y = 0 at `pos`, long side along z.
static func rack(parent: Node, pos: Vector3, size: Vector3, lamp_mat: Material, shelves: int = 9, face: float = 1.0, seed_value: int = 1) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = pos
	var mat := metal()
	var dark := metal(Color("#101214"), 0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			box(n, Vector3(0.14, size.y, 0.14), Vector3(sx * (size.x * 0.5 - 0.07), size.y * 0.5, sz * (size.z * 0.5 - 0.07)), mat)
	box(n, Vector3(size.x * 0.82, size.y * 0.96, size.z * 0.94), Vector3(-face * size.x * 0.06, size.y * 0.5, 0), dark)
	box(n, Vector3(size.x + 0.16, 0.2, size.z + 0.16), Vector3(0, size.y + 0.1, 0), mat)
	box(n, Vector3(size.x + 0.1, 0.24, size.z + 0.1), Vector3(0, 0.12, 0), mat)
	var gap := (size.y - 0.6) / float(shelves)
	for s: int in shelves:
		var y := 0.5 + s * gap
		box(n, Vector3(size.x * 0.96, 0.05, size.z * 0.98), Vector3(0, y, 0), mat)
		# the cells of this shelf: little drawers standing proud of the face, and the strip that reads them
		var cells := 6
		for c: int in cells:
			if rng.randf() < 0.16:
				continue              # pulled
			var z := (float(c) - (cells - 1) * 0.5) * size.z * 0.94 / cells
			box(n, Vector3(0.1, gap * 0.52, size.z * 0.94 / cells * 0.8), Vector3(face * (size.x * 0.5 - 0.02), y + gap * 0.42, z), mat)
		box(n, Vector3(0.05, 0.06, size.z * 0.9), Vector3(face * (size.x * 0.5 + 0.04), y + gap * 0.1, 0), lamp_mat)
	for k: int in 3:
		var z2 := (k - 1) * size.z * 0.3
		pipe(n, Vector3(0, size.y + 0.2, z2), Vector3(-face * 0.9, size.y + 2.6 + k * 0.4, z2 * 0.6), 0.06, dark)
	return n

## A restoration engine: a plinth, a drum, a shaft through a stack of rings of light, a flywheel, and two rams braced
## against the floor. Returns {node, rings: [lamp materials, bottom to top], light}.
static func engine(parent: Node, pos: Vector3, lamp_color: Color, rings: int = 6, height: float = 5.6) -> Dictionary:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = pos
	var mat := metal()
	var dark := metal(Color("#121416"), 0.6)
	cyl(n, 0.78, 0.95, 0.36, Vector3(0, 0.18, 0), mat, 12)
	cyl(n, 0.62, 0.7, 0.5, Vector3(0, 0.6, 0), dark, 12)
	cyl(n, 0.2, 0.2, height - 0.8, Vector3(0, 0.8 + (height - 0.8) * 0.5, 0), mat, 10)
	cyl(n, 0.66, 0.3, 0.42, Vector3(0, height + 0.1, 0), mat, 12)
	torus(n, 0.92, 0.07, Vector3(0, height * 0.52, 0), mat, 32, 6)
	var mats: Array = []
	for k: int in rings:
		var m := FinalHall.lamp(lamp_color, 0.0)
		var y := 1.05 + k * (height - 1.7) / float(maxi(rings - 1, 1))
		torus(n, 0.5 - k * 0.018, 0.07, Vector3(0, y, 0), m, 28, 6)
		cyl(n, 0.3, 0.3, 0.1, Vector3(0, y, 0), dark, 10)
		mats.append(m)
	for sx: float in [-1.0, 1.0]:
		pipe(n, Vector3(sx * 0.95, 0.1, 0.55), Vector3(sx * 0.3, height * 0.55, 0.1), 0.07, mat)
		pipe(n, Vector3(sx * 0.95, 0.1, 0.55), Vector3(sx * 0.62, height * 0.3, 0.26), 0.1, dark)
		box(n, Vector3(0.32, 0.16, 0.32), Vector3(sx * 0.95, 0.08, 0.55), mat)
	var l := OmniLight3D.new()
	l.light_color = lamp_color
	l.light_energy = 0.0
	l.omni_range = 9.0
	l.position = Vector3(0, height * 0.46, 0.9)
	n.add_child(l)
	return {"node": n, "rings": mats, "light": l}

## The ribs of a vault over a hall `width` wide, springing at `spring` and rising to `crown`, one arch every
## (z0 - z1) / (count - 1) metres, with a dark soffit above them so no sky shows. Nothing here casts a shadow.
static func vault(parent: Node, width: float, spring: float, crown: float, z0: float, z1: float, count: int, mat: Material = null) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var rib: Material = mat if mat != null else metal(Color("#1a1c1f"), 0.6)
	var soffit := Look.flat(Color("#060708"), 0.95, 0.0)
	var segs := 9
	for i: int in count:
		var z := lerpf(z0, z1, float(i) / float(maxi(count - 1, 1)))
		var last := Vector3.ZERO
		for s: int in segs + 1:
			var a := PI * float(s) / float(segs)
			var p := Vector3(-cos(a) * width * 0.5, spring + sin(a) * (crown - spring), z)
			if s > 0:
				var d := p - last
				box(n, Vector3(d.length() + 0.12, 0.42, 0.5), last + d * 0.5, rib, Vector3(0, 0, atan2(d.y, d.x)))
			last = p
		for sx: float in [-1.0, 1.0]:
			box(n, Vector3(0.5, spring, 0.6), Vector3(sx * width * 0.5, spring * 0.5, z), rib)
	# the ridge, and the purlins between the ribs
	box(n, Vector3(0.36, 0.36, absf(z0 - z1) + 1.0), Vector3(0, crown - 0.1, (z0 + z1) * 0.5), rib)
	for sx2: float in [-1.0, 1.0]:
		box(n, Vector3(0.26, 0.26, absf(z0 - z1) + 1.0), Vector3(sx2 * width * 0.3, spring + (crown - spring) * 0.8, (z0 + z1) * 0.5), rib)
	box(n, Vector3(width + 8.0, 0.3, absf(z0 - z1) + 14.0), Vector3(0, crown + 0.9, (z0 + z1) * 0.5), soffit)
	for sx3: float in [-1.0, 1.0]:
		box(n, Vector3(0.3, crown + 1.0, absf(z0 - z1) + 14.0), Vector3(sx3 * (width * 0.5 + 3.6), (crown + 1.0) * 0.5, (z0 + z1) * 0.5), soffit)
	return n

## A door of the old make: jambs with a bevel, a lintel carrying a small ring, a sill, and a strip of light up each
## jamb. `w` and `h` are the clear opening; it stands on y = 0 facing +z. Returns the node (leaves are the scene's).
static func portal(parent: Node, pos: Vector3, w: float, h: float, lamp_mat: Material, mat: Material = null) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = pos
	var m: Material = mat if mat != null else metal(Color("#2a2c2e"), 0.5)
	for sx: float in [-1.0, 1.0]:
		box(n, Vector3(0.6, h + 0.8, 0.8), Vector3(sx * (w * 0.5 + 0.3), (h + 0.8) * 0.5, 0), m)
		box(n, Vector3(0.3, h + 0.2, 0.5), Vector3(sx * (w * 0.5 + 0.02), (h + 0.2) * 0.5, 0.3), m, Vector3(0, -sx * 0.5, 0))
		box(n, Vector3(0.06, h - 0.4, 0.06), Vector3(sx * (w * 0.5 + 0.3), h * 0.5, 0.42), lamp_mat)
		box(n, Vector3(0.9, 0.5, 1.0), Vector3(sx * (w * 0.5 + 0.3), 0.25, 0), m)
	box(n, Vector3(w + 1.8, 0.7, 0.9), Vector3(0, h + 0.75, 0), m)
	box(n, Vector3(w + 1.0, 0.24, 1.1), Vector3(0, h + 0.28, 0), m)
	box(n, Vector3(w + 1.2, 0.1, 1.0), Vector3(0, 0.05, 0), m)
	var crest := ring(n, 0.62, 0.09, lamp_mat, 5, true, m)
	crest.position = Vector3(0, h + 1.75, 0.1)
	return n
