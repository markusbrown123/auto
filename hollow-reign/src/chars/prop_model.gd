class_name PropModel
extends RefCounted
## Fits a generated weapon or shield model to the rig's conventions:
## weapons run along +Y with the grip at the origin and the flat of the blade
## facing Z; shields face Z, centred. Works from the mesh's own extents, so it
## does not matter which way the generator happened to orient the object.

const LENGTH := {"sword": 1.12, "greatsword": 1.75, "axe": 1.1, "cleaver": 1.3, "dual": 0.9, "glaive": 2.3}
## where along its length the hand holds it (0 = pommel end)
const GRIP := {"sword": 0.11, "greatsword": 0.13, "axe": 0.2, "cleaver": 0.2, "dual": 0.13, "glaive": 0.5}
## classes whose wide end is the business end rather than the hilt
const HEAD_HEAVY := ["axe", "cleaver"]

static var _fit_cache := {}

static func exists(path: String) -> bool:
	return path != "" and ResourceLoader.exists(path)

static func _instance(path: String) -> Node3D:
	var scene: PackedScene = load(path)
	return scene.instantiate() if scene else null

static func _verts(root: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = _to_root(mi, root)
		for s in mi.mesh.get_surface_count():
			var arr: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var step: int = maxi(1, arr.size() / 3000)
			for i in range(0, arr.size(), step):
				out.append(xf * arr[i])
	if root is MeshInstance3D and root.mesh:
		for s in root.mesh.get_surface_count():
			out.append_array(root.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	return out

static func _to_root(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root and cur != null:
		if cur is Node3D:
			xf = cur.transform * xf
		cur = cur.get_parent()
	return xf

## Returns {basis, lo, hi}: a rotation taking the model's long/mid/thin axes to Y/X/Z, and its bounds after it.
static func _frame(path: String, root: Node3D, flip_wide_to: String) -> Dictionary:
	var key := path + flip_wide_to
	if _fit_cache.has(key):
		return _fit_cache[key]
	var v := _verts(root)
	var lo := Vector3.ONE * 1e9
	var hi := Vector3.ONE * -1e9
	for p in v:
		lo = lo.min(p)
		hi = hi.max(p)
	var ext := hi - lo
	var order := [0, 1, 2]
	order.sort_custom(func(a, b): return ext[a] > ext[b])
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	# rows of the basis: long axis -> Y, mid -> X, thin -> Z
	var basis := Basis(axes[order[1]], axes[order[0]], axes[order[2]]).transposed()
	if basis.determinant() < 0.0:
		basis = Basis(-axes[order[1]], axes[order[0]], axes[order[2]]).transposed()
	var lo2 := Vector3.ONE * 1e9
	var hi2 := Vector3.ONE * -1e9
	var pts := PackedVector3Array()
	for p in v:
		var q := basis * p
		pts.append(q)
		lo2 = lo2.min(q)
		hi2 = hi2.max(q)
	if flip_wide_to != "":
		# which end is wider? swords carry their width (the guard) low; axes carry it high
		var len := hi2.y - lo2.y
		var low_w := 0.0
		var high_w := 0.0
		var mid_x := (lo2.x + hi2.x) * 0.5
		for q in pts:
			var u := (q.y - lo2.y) / maxf(len, 0.001)
			if u < 0.3:
				low_w = maxf(low_w, absf(q.x - mid_x))
			elif u > 0.7:
				high_w = maxf(high_w, absf(q.x - mid_x))
		var wide_is_high := high_w > low_w * 1.15
		var wide_is_low := low_w > high_w * 1.15
		if (flip_wide_to == "low" and wide_is_high) or (flip_wide_to == "high" and wide_is_low):
			basis = Basis(Vector3.BACK, PI) * basis
			var a := Basis(Vector3.BACK, PI) * lo2
			var b := Basis(Vector3.BACK, PI) * hi2
			lo2 = a.min(b)
			hi2 = a.max(b)
	var out := {"basis": basis, "lo": lo2, "hi": hi2}
	_fit_cache[key] = out
	return out

static func _tint(root: Node3D, c: Color) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat = mi.get_active_material(s)
			if mat is BaseMaterial3D:
				var dup: BaseMaterial3D = mat.duplicate()
				dup.albedo_color = c
				mi.set_surface_override_material(s, dup)

## Adds the weapon under `parent`. Returns the usable blade length beyond the grip, or 0 on failure.
static func weapon(parent: Node3D, path: String, cls: String, tint = null, length_scale: float = 1.0) -> float:
	var root := _instance(path)
	if root == null:
		return 0.0
	var f := _frame(path, root, "high" if cls in HEAD_HEAVY else ("" if cls == "glaive" else "low"))
	var len: float = f.hi.y - f.lo.y
	var want: float = float(LENGTH.get(cls, 1.1)) * length_scale
	var k := want / maxf(len, 0.001)
	var grip: float = float(GRIP.get(cls, 0.11))
	var centre := Vector3((f.lo.x + f.hi.x) * 0.5, f.lo.y + len * grip, (f.lo.z + f.hi.z) * 0.5)
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.add_child(root)
	root.transform = Transform3D(f.basis.scaled(Vector3.ONE * k), -(centre * k))
	root.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), -(centre * k)) * Transform3D(f.basis, Vector3.ZERO)
	if tint != null:
		_tint(root, Color(str(tint)))
	return want * (1.0 - grip)

static func shield(parent: Node3D, path: String, height: float = 0.82) -> bool:
	var root := _instance(path)
	if root == null:
		return false
	var f := _frame(path, root, "")
	var k := height / maxf(f.hi.y - f.lo.y, 0.001)
	var centre: Vector3 = (f.lo + f.hi) * 0.5
	parent.add_child(root)
	root.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), -(centre * k)) * Transform3D(f.basis, Vector3.ZERO)
	return true
