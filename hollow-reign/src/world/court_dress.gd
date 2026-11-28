class_name CourtDress
extends RefCounted
## The continuous Courtyard's environment detail (Stage 3C; docs/GRAPHICS_BIBLE.md "Stage 3C"). The route
## (src/world/court_route.gd) lays the place out; this file makes it a fortress somebody held and lost:
##   - its masonry: through Future.Kit's court mode (src/world/future.gd `_court_*`) the kit's walls, towers, beacons,
##     masts and the keep's door are built as coursed stone with plinths, string courses, corbelled parapets, merlons,
##     arrow slits and buttresses, round towers with slate cones, iron braziers, lantern posts, banner poles and a
##     gate of three orders; the materials are swapped for court_stone.gdshader (block pattern, chipped arrises, rain
##     streaks, earth and moss at the foot, wet toward the sea) and its flagstone variant for the paving;
##   - its dressing (`dress`, called by Kit.commit for each section and for the far layer): per wall, fallen masonry,
##     ivy, stains, weeds, chains, torch brackets and the odd banner along its foot and face; per place, what was left:
##     barrels, crates, carts, racks, scaffolding, barricades, the dead of old fights with their weapons, bones,
##     candles, graves, broken paving; the hillside door is a carved portal in the rock; the keep has a face (windows,
##     a rose, a gallery, banners, crenels) and its gate has statues and two lit braziers; the kneeling colossus is
##     chained where it knelt, with the weapons of those who tried it heaped round it.
## Cheap by construction: no new textures (the shaders work out their patterns; the grain is the rock texture the
## route already loads), everything merged by material into a few meshes per section, small things in 24 m cells with
## visibility ranges, only the big pieces cast shadows, two new lights (the keep gate's braziers).
## Nothing stands in a way the knight walks, a stop's fighting ring, a foe's entrance or an interaction (`blocked`).
## `--nodress` (dev) turns all of it off and gives the route as Stage 3A built it.
##
## Hook: none needed in court_route.gd: Future.Kit sees that its host is a CourtRoute section ("SectionN") or the
## far layer ("Far") and calls `dress` from `commit`. `build(route, i, host)` is the same thing callable by hand.

const CELL := 40.0
## What the small made things are drawn as (court_prop.gdshader): the material, the vertex alpha that tells it what
## it is (0 wood, 0.5 bone or rag, 1 iron), a tint.
const PROPS := {"wood": 0.0, "bone": 0.5, "iron": 1.0, "dark": 0.5}
const FIRE := Color("#ff9a48")

static var _mats := {}
static var _lut: ImageTexture
static var _rings: Array = []

static func off() -> bool:
	return OS.get_cmdline_user_args().has("--nodress")

## Whether a kit building under `host` is the continuous Courtyard (a section or its far layer).
static func wanted(host: Node) -> bool:
	if host == null or not is_instance_valid(host) or off() or not host.get_parent() is CourtRoute:
		return false
	var nm := String(host.name)
	return nm == "Far" or nm.begins_with("Section")

# ================================================================ materials
## The strip along the route that the shaders read: spine height, sea-cliff x, the way's middle x (court_common).
static func lut() -> Texture2D:
	if _lut != null:
		return _lut
	var img := Image.create(512, 1, false, Image.FORMAT_RGBF)
	for i in 512:
		var z := 90.0 - 400.0 * (float(i) + 0.5) / 512.0
		img.set_pixel(i, 0, Color(CourtRoute.spine(z), CourtRoute.cliff_x(z), CourtRoute._road_x(z)))
	_lut = ImageTexture.create_from_image(img)
	return _lut

static func _stone(tint: String, tint_b: String, course: float, block: float, extra: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://src/world/court_stone.gdshader")
	m.set_shader_parameter("grain_tex", Future._tex("res://assets/textures/floor_roost.jpg"))
	m.set_shader_parameter("grain_n", Future._tex("res://assets/textures/floor_roost_n.png"))
	m.set_shader_parameter("noise_tex", Highland._noise_tex())
	m.set_shader_parameter("route_lut", lut())
	m.set_shader_parameter("tint", Color(tint))
	m.set_shader_parameter("tint_b", Color(tint_b))
	m.set_shader_parameter("course", course)
	m.set_shader_parameter("block", block)
	m.set_shader_parameter("sea_level", CourtRoute.SEA)
	m.set_shader_parameter("future_x", 150.0)
	for k: String in extra:
		m.set_shader_parameter(k, extra[k])
	return m

static func mat(nm: String) -> Material:
	if _mats.has(nm):
		return _mats[nm]
	var m: Material
	match nm:
		"stone": m = _stone("#99938a", "#83837f", 0.56, 1.15)
		"trim": m = _stone("#77726a", "#686967", 0.42, 0.85, {"vary": 0.12, "moss_amt": 0.8})
		"roof": m = _stone("#3e434a", "#363a40", 0.26, 0.42, {"vary": 0.25, "grain": 0.35, "bevel": 0.03, "mortar": 0.012, "moss_amt": 0.7})
		"pave": m = _stone("#7f7a71", "#6d6c67", 0.5, 1.0, {"paving": 1.0, "moss_amt": 1.0, "vary": 0.3, "grain": 0.75})
		"tread": m = _stone("#7d786f", "#6d6c67", 0.6, 1.0, {"paving": 1.0, "moss_amt": 0.5, "vary": 0.26, "grain": 0.75})
		"rubble": m = _stone("#9c968b", "#83837e", 0.3, 0.5, {"vary": 0.3, "bevel": 0.04, "dirt_h": 0.7})
		"props":
			var pr := ShaderMaterial.new()
			pr.shader = load("res://src/world/court_prop.gdshader")
			pr.set_shader_parameter("noise_tex", Highland._noise_tex())
			m = pr
		"cloth", "cloth_kit":
			var c := ShaderMaterial.new()
			c.shader = load("res://src/world/court_cloth.gdshader")
			c.set_shader_parameter("noise_tex", Highland._noise_tex())
			if nm == "cloth_kit":
				c.set_shader_parameter("kit_dye", 1.0)
			m = c
		"ivy":
			var iv := ShaderMaterial.new()
			iv.shader = load("res://src/world/court_ivy.gdshader")
			iv.set_shader_parameter("noise_tex", Highland._noise_tex())
			m = iv
		"flame":
			var f := ShaderMaterial.new()
			f.shader = load("res://src/world/court_flame.gdshader")
			f.set_shader_parameter("noise_tex", Highland._noise_tex())
			m = f
		"decal":
			var d := ShaderMaterial.new()
			d.shader = load("res://src/world/court_decal.gdshader")
			d.set_shader_parameter("noise_tex", Highland._noise_tex())
			m = d
		"coal": m = Look.glow(Color("#ff6a24"), 2.2)
		"window": m = Look.glow(Color("#d89a58"), 0.9)
		"dark": m = Look.flat(Color("#0b0b0c"), 0.95)
	_mats[nm] = m
	return m

## The material a court kit commits a tool with (null: the kit's own).
static func kit_mat(nm: String, a: Arena) -> Material:
	match nm:
		"pale", "pale_far": return mat("stone")
		"alloy", "alloy_far": return mat("trim")
		"roof", "wood", "iron", "flame", "coal": return mat(nm)
		"cloth": return mat("cloth_kit")
		"machine":
			var key := "court_machine"
			if not _mats.has(key):
				var mm: ShaderMaterial = Future.built(a, "alloy").duplicate()
				mm.set_shader_parameter("tint", Color("#3c4044"))
				_mats[key] = mm
			return _mats[key]
		"lit": return _glow("lit", Color(str(Future.LOOKS.courtyard.seam)).darkened(0.55), 0.8)
		"lit2": return _glow("lit2", Color("#9fe8f0").darkened(0.45), 0.8)
		"dim": return _glow("dim", Color(str(Future.LOOKS.courtyard.seam)).darkened(0.7), 0.45)
		"lamp": return _glow("lamp", Color("#ffb468"), 2.4)
	return null

static func _glow(key: String, c: Color, e: float) -> Material:
	if not _mats.has("glow_" + key):
		_mats["glow_" + key] = Look.glow(c, e)
	return _mats["glow_" + key]

## Before a court kit commits: the route's paving, treads, road and well take the flagstone material; the ground
## shader learns where the way is.
static func retexture(host: Node3D) -> void:
	for nm: String in ["Pave", "Treads", "Road", "Well"]:
		var mi := host.get_node_or_null(nm) as MeshInstance3D
		if mi != null:
			mi.material_override = mat("tread" if nm == "Treads" else "pave")
	var route := host.get_parent() as CourtRoute
	if route != null:
		var g := route._mat("ground") as ShaderMaterial
		if g != null:
			g.set_shader_parameter("route_lut", lut())
			g.set_shader_parameter("has_lut", 1.0)
			# the route's crags: drawn as the land's own rock (strata, lichen, moss on their tops), not flat dark stone
			if not _mats.has("crag"):
				var c: ShaderMaterial = g.duplicate()
				c.set_shader_parameter("turf_bias", 0.14)
				c.set_shader_parameter("rock_tint", Color("#b4ada2"))
				_mats["crag"] = c
			var rock := route._mat("rock")
			for mm: MultiMeshInstance3D in host.find_children("*", "MultiMeshInstance3D", false, false):
				if mm.material_override == rock:
					mm.material_override = _mats["crag"]

# ================================================================ keeping the ways clear
static func _clear_init() -> void:
	if not _rings.is_empty():
		return
	for i in CourtRoute.ANCHORS.size():
		var a := CourtRoute.anchor(i)
		_rings.append([Vector2(a.x, a.z), 8.5])        # the stop's fighting ring and its camera
	var fs: Dictionary = CourtRoute.foe_spots()
	for k: int in fs:
		var f: Vector3 = fs[k].from
		_rings.append([Vector2(f.x, f.z), 2.8])
	for key: String in CourtRoute.SPOTS:
		var s: Dictionary = CourtRoute.SPOTS[key]
		_rings.append([Vector2(float(s.prop[0]), float(s.prop[1])), 2.0])
		_rings.append([Vector2(float(s.stand[0]), float(s.stand[1])), 2.0])
		for v: Array in s.via:
			_rings.append([Vector2(float(v[0]), float(v[1])), 1.6])
	# Stage 3B's encounters (read by name so either file can change without breaking the other): the duel's middle
	# ("meet") and its camera, the foe's post, its patrol beat, the way it comes out, a barricade
	var cm: Dictionary = (load("res://src/world/court_route.gd") as Script).get_script_constant_map()
	var enc: Dictionary = cm.get("ENCOUNTERS", {})
	for st: int in enc:
		var e: Dictionary = enc[st]
		var all: Array = [e]
		for alt: Dictionary in (e.get("by_foe", {}) as Dictionary).values():
			all.append(alt)
		for ee: Dictionary in all:
			if ee.has("meet"):
				_rings.append([Vector2(float(ee.meet[0]), float(ee.meet[1])), 8.0])
			for k2: String in ["post", "barricade"]:
				if ee.has(k2):
					_rings.append([Vector2(float(ee[k2][0]), float(ee[k2][1])), 2.6])
			for k3: String in ["beat", "out"]:
				var pts: Array = ee.get(k3, [])
				for j in pts.size():
					var a := Vector2(float(pts[j][0]), float(pts[j][1]))
					var b := a if j == pts.size() - 1 else Vector2(float(pts[j + 1][0]), float(pts[j + 1][1]))
					var steps := maxi(1, int(a.distance_to(b)))
					for q in steps + 1:
						_rings.append([a.lerp(b, float(q) / steps), 2.0])
	_rings.append([Vector2(CourtRoute.ENTRY.x, CourtRoute.ENTRY.z), 3.0])
	_rings.append([Vector2(CourtRoute.SHORTCUT_IN.x, CourtRoute.SHORTCUT_IN.z), 2.5])
	_rings.append([Vector2(CourtRoute.MONUMENT.x, CourtRoute.MONUMENT.z), 3.2])

## Whether something of radius `r` at (x, z) would stand in a way, a fighting ring, an entrance or an interaction.
static func blocked(x: float, z: float, r: float = 0.5) -> bool:
	_clear_init()
	var p := Vector2(x, z)
	for ring: Array in _rings:
		if p.distance_to(ring[0]) < float(ring[1]) + r:
			return true
	if x > -15.8 - r and x < -10.7 + r and z < -104.0 and z > -138.5:
		return true                                    # the lane up to the postern
	return CourtRoute.near_way(x, z, 1.9 + r)

# ================================================================ merged geometry
## Triangles of one material, built straight into arrays (much quicker than a SurfaceTool per box).
class Batch:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var c := PackedColorArray()
	var size2 := Vector2.ONE

	func tri(a: Vector3, b: Vector3, d: Vector3, nn: Vector3, ua: Vector2, ub: Vector2, ud: Vector2, col: Color) -> void:
		if (b - a).cross(d - a).dot(nn) > 0.0:
			var t := b
			b = d
			d = t
			var tu := ub
			ub = ud
			ud = tu
		v.append(a)
		v.append(b)
		v.append(d)
		uv.append(ua)
		uv.append(ub)
		uv.append(ud)
		for i in 3:
			n.append(nn)
			c.append(col)
			uv2.append(size2)

	func quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, nn: Vector3, col: Color) -> void:
		tri(p0, p1, p2, nn, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), col)
		tri(p0, p2, p3, nn, Vector2(0, 1), Vector2(1, 0), Vector2(0, 0), col)

	func box(size: Vector3, xf: Transform3D, col: Color = Color.WHITE) -> void:
		var h := size * 0.5
		var nb := xf.basis.inverse().transposed()
		for ax in 3:
			for sg: float in [-1.0, 1.0]:
				var nl := Vector3.ZERO
				nl[ax] = sg
				var u := Vector3.ZERO
				u[(ax + 1) % 3] = h[(ax + 1) % 3]
				var w := Vector3.ZERO
				w[(ax + 2) % 3] = h[(ax + 2) % 3]
				var ce := nl * h[ax]
				quad(xf * (ce - u - w), xf * (ce + u - w), xf * (ce + u + w), xf * (ce - u + w), (nb * nl).normalized(), col)

	## A tapered prism standing on the origin of `xf` along its y: `sides` faces, `r0` at the foot, `r1` at the top.
	func prism(xf: Transform3D, r0: float, r1: float, h: float, sides: int, col: Color = Color.WHITE, caps: bool = true) -> void:
		var nb := xf.basis.inverse().transposed()
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var am := (a0 + a1) * 0.5
			var p0 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
			var p1 := Vector3(cos(a1) * r0, 0, sin(a1) * r0)
			var p2 := Vector3(cos(a1) * r1, h, sin(a1) * r1)
			var p3 := Vector3(cos(a0) * r1, h, sin(a0) * r1)
			var nl := Vector3(cos(am) * h, r0 - r1, sin(am) * h).normalized()
			quad(xf * p0, xf * p1, xf * p2, xf * p3, (nb * nl).normalized(), col)
			if caps:
				if r1 > 0.001:
					tri(xf * Vector3(0, h, 0), xf * p3, xf * p2, (nb * Vector3.UP).normalized(), Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0), col)
				tri(xf * Vector3.ZERO, xf * p0, xf * p1, (nb * Vector3.DOWN).normalized(), Vector2(0.5, 0.5), Vector2(0, 1), Vector2(1, 1), col)

	## A beam from one point to another, `w` by `d` across.
	func beam(a: Vector3, b: Vector3, w: float, d: float = -1.0, col: Color = Color.WHITE) -> void:
		var ax := b - a
		if ax.length() < 0.001:
			return
		box(Vector3(w, ax.length(), d if d > 0.0 else w), Transform3D(Basis(Quaternion(Vector3.UP, ax.normalized())), (a + b) * 0.5), col)

	## A flat grid hanging from `top_left` along `right` (its width) and `down` (its drop): UV 0..1, y 0 at the top.
	func card(top_left: Vector3, right: Vector3, down: Vector3, cols: int, rows: int, col: Color) -> void:
		var nn := right.cross(down).normalized()
		size2 = Vector2(right.length(), down.length())
		for j in rows:
			for i in cols:
				var u0 := float(i) / cols
				var u1 := float(i + 1) / cols
				var v0 := float(j) / rows
				var v1 := float(j + 1) / rows
				var q0 := top_left + right * u0 + down * v0
				var q1 := top_left + right * u1 + down * v0
				var q2 := top_left + right * u1 + down * v1
				var q3 := top_left + right * u0 + down * v1
				tri(q0, q1, q2, nn, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), col)
				tri(q0, q2, q3, nn, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1), col)
		size2 = Vector2.ONE

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_COLOR] = c
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m

## Batches by material, by 24 m cell for small things, and by whether they cast a shadow.
class Bins:
	var sets := {}

	## The batch for material `m` at `p`; `cell` false keeps it in one piece for the section (architecture).
	func at(m: String, p: Vector3, cell: bool = true, cast: bool = false) -> Batch:
		var key := "%s|%s|%s" % [m, "s" if cast else "", "%d,%d" % [floori(p.x / CourtDress.CELL), floori(p.z / CourtDress.CELL)] if cell else "-"]
		if not sets.has(key):
			sets[key] = [m, cell, cast, Batch.new()]
		return sets[key][3]

	func commit(parent: Node3D) -> int:
		# wood, iron, bone and dark pieces share one material: their batches are joined here, each vertex told what
		# it is by its alpha; what casts a shadow is joined across cells
		var groups := {}
		for key: String in sets:
			var s: Array = sets[key]
			var bt: Batch = s[3]
			if bt.v.is_empty():
				continue
			var m := str(s[0])
			var cell := bool(s[1])
			if CourtDress.PROPS.has(m):
				var kind: float = CourtDress.PROPS[m]
				var dark := m == "dark"
				for i in bt.c.size():
					var col := bt.c[i]
					if dark:
						col = Color(0.06, 0.06, 0.065)
					col.a = kind
					bt.c[i] = col
				m = "props"
			if bool(s[2]) or m != "props":
				cell = false
			var gk := "%s|%s|%s" % [m, "s" if bool(s[2]) else "", key.get_slice("|", 2) if cell else "-"]
			if not groups.has(gk):
				groups[gk] = [m, cell, bool(s[2]), Batch.new()]
			var g: Batch = groups[gk][3]
			g.v.append_array(bt.v)
			g.n.append_array(bt.n)
			g.uv.append_array(bt.uv)
			g.uv2.append_array(bt.uv2)
			g.c.append_array(bt.c)
		var tris := 0
		var by := {}
		for gk2: String in groups:
			var s2: Array = groups[gk2]
			var bt2: Batch = s2[3]
			tris += bt2.v.size() / 3
			by[str(s2[0])] = int(by.get(str(s2[0]), 0)) + bt2.v.size() / 3
			var mi := MeshInstance3D.new()
			mi.name = "Dress_" + str(s2[0])
			mi.mesh = bt2.mesh()
			mi.material_override = CourtDress.mat(str(s2[0]))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(s2[2]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var reach := 0.0
			match str(s2[0]):
				"props": reach = 58.0 if bool(s2[1]) else 0.0
				"decal": reach = 48.0
				"ivy": reach = 85.0
				"rubble": reach = 75.0
				"coal", "flame": reach = 90.0
			if reach > 0.0:
				mi.visibility_range_end = reach
				mi.visibility_range_end_margin = 6.0
			parent.add_child(mi)
		if OS.get_cmdline_user_args().has("--routecost"):
			print("DRESS %s: %d meshes, %d triangles %s" % [parent.get_parent().name, groups.size(), tris, str(by)])
		return tris

## A court kit's wood, iron and dark tools, joined into one mesh in the props material (fewer draws).
static func merge_kit(k: Future.Kit) -> void:
	var bt := Batch.new()
	for nm: String in ["wood", "iron", "dark"]:
		if not k.tools.has(nm):
			continue
		var arr: Array = (k.tools[nm] as SurfaceTool).commit_to_arrays()
		k.tools.erase(nm)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx = arr[Mesh.ARRAY_INDEX]
		var col := Color(0.06, 0.06, 0.065) if nm == "dark" else Color.WHITE
		col.a = PROPS[nm]
		var order: PackedInt32Array = idx if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0 else PackedInt32Array(range(verts.size()))
		for i in order:
			bt.v.append(verts[i])
			bt.n.append(norms[i] if norms.size() > i else Vector3.UP)
			bt.uv.append(Vector2.ZERO)
			bt.uv2.append(Vector2.ONE)
			bt.c.append(col)
	if bt.v.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.name = "Fu_props"
	mi.mesh = bt.mesh()
	mi.material_override = mat("props")
	k.into.add_child(mi)

# ================================================================ the hook
## Called by Future.Kit.commit when a court kit has committed its own meshes.
static func dress(k: Future.Kit) -> void:
	var host := k.into
	var route := host.get_parent() as CourtRoute
	if route == null:
		return
	if OS.get_cmdline_user_args().has("--routecost"):
		var kt := 0
		var parts := {}
		for mi: MeshInstance3D in host.find_children("Fu_*", "MeshInstance3D", false, false):
			var t := mi.mesh.get_faces().size() / 3
			kt += t
			parts[String(mi.name)] = t
		print("KIT %s: %d triangles %s" % [host.name, kt, str(parts)])
	if OS.get_cmdline_user_args().has("--dressbare"):
		return                                      # dev: the masonry without the dressing (cost comparisons)
	if String(host.name) == "Far":
		_far(route, host, k.walls)
	else:
		build(route, int(String(host.name).substr(7)), host, k.walls)

static func _yield(route: CourtRoute) -> void:
	if route != null and is_instance_valid(route) and not route._sync:
		await route._tick()

## Dresses section `i` of `route` under `host` (a node "Dress" that shows when it is complete).
static func build(route: CourtRoute, i: int, host: Node3D, walls: Array = []) -> void:
	if host.has_node("Dress"):
		return
	var d := Node3D.new()
	d.name = "Dress"
	d.visible = route._sync
	host.add_child(d)
	var f0 := Engine.get_process_frames()
	var t0 := Time.get_ticks_usec()
	var B := Bins.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7300 + i * 31
	var weeds: Array = []
	if i == 1:
		# the keep gate's statues are read on a thread well before the ward is built
		var sp := Future.MODEL % "statue"
		if ResourceLoader.exists(sp) and not ResourceLoader.has_cached(sp):
			ResourceLoader.load_threaded_request(sp)
	for w: Dictionary in walls:
		if not bool(w.far):
			_dress_wall(B, rng, w, i, weeds)
		await _yield(route)
		if not is_instance_valid(d):
			return
	for bw: Array in BOX_WALLS.get(i, []):
		_dress_box_wall(B, rng, bw, i, weeds)
	await _yield(route)
	if not is_instance_valid(d):
		return
	match i:
		0: _hill(B, rng, route, d, weeds)
		1: _outer(B, rng, route, d, weeds)
		2: _barbican(B, rng, route, d, weeds)
		3: _winch(B, rng, route, d, weeds)
		4: await _ward(B, rng, route, host, d, weeds)
	await _yield(route)
	if not is_instance_valid(d):
		return
	var tris := B.commit(d)
	_weeds(route, d, weeds)
	d.set_meta("tris", tris)
	d.visible = true
	if OS.get_cmdline_user_args().has("--routecost"):
		print("DRESS TIME section %d: %d ms wall clock over %d frames (sync %s)" % [i, (Time.get_ticks_usec() - t0) / 1000, Engine.get_process_frames() - f0, str(route._sync)])

# ================================================================ pieces
## Dev (`--dresscam=x,y,z,yaw,pitch` in degrees): a still camera that takes over the view a second after the place is
## built, for before/after pictures of what the road's own camera never turns to (the hillside door, the keep).
static func _devcam(route: CourtRoute) -> void:
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--dresscam="):
			continue
		var v := a.trim_prefix("--dresscam=").split(",")
		if v.size() < 5:
			return
		var cam := Camera3D.new()
		cam.name = "DressCam"
		cam.fov = 55.0
		cam.far = 4000.0
		route.add_child(cam)
		cam.position = Vector3(float(v[0]), float(v[1]), float(v[2]))
		cam.rotation_degrees = Vector3(float(v[4]), float(v[3]), 0)
		for t: float in [0.5, 1.0, 2.0, 4.0]:
			route.get_tree().create_timer(t).timeout.connect(func():
				if is_instance_valid(cam):
					cam.make_current()
					route.update(cam.position))
		return

## Small stones and chips scattered over a yard, off the ways.
static func _chips(B: Bins, rng: RandomNumberGenerator, x0: float, x1: float, z0: float, z1: float, count: int) -> void:
	for i in count:
		var x := rng.randf_range(x0, x1)
		var z := rng.randf_range(z0, z1)
		if blocked(x, z, 0.1) or CourtRoute.floor_at(x, z).is_empty():
			continue
		var s := rng.randf_range(0.07, 0.2)
		var q := Vector3(x, _gy(x, z) + s * 0.2, z)
		B.at("rubble", q).box(Vector3(s * 1.4, s * 0.6, s), _xf(q, rng.randf() * TAU, rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)), _shade(rng, 0.6, 0.95))

static func _gy(x: float, z: float) -> float:
	return CourtRoute.ground_y(x, z)

static func _on(x: float, z: float, lift: float = 0.0) -> Vector3:
	return Vector3(x, _gy(x, z) + lift, z)

static func _xf(at: Vector3, yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), at)

static func _shade(rng: RandomNumberGenerator, lo: float = 0.8, hi: float = 1.1) -> Color:
	var s := rng.randf_range(lo, hi)
	return Color(s, s * rng.randf_range(0.97, 1.02), s * rng.randf_range(0.95, 1.02))

## A fallen block of masonry, half in the ground.
static func _block(B: Bins, rng: RandomNumberGenerator, p: Vector3, s: float) -> void:
	var size := Vector3(s * rng.randf_range(0.9, 1.6), s * rng.randf_range(0.55, 0.9), s * rng.randf_range(0.7, 1.1))
	B.at("rubble", p).box(size, _xf(p + Vector3(0, size.y * 0.25, 0), rng.randf() * TAU, rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35)), _shade(rng, 0.75, 1.05))

## A heap of fallen masonry and chips round `p`.
static func _heap(B: Bins, rng: RandomNumberGenerator, p: Vector3, radius: float, count: int) -> void:
	for i in count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius
		var q := Vector3(p.x + cos(a) * r, 0, p.z + sin(a) * r)
		q.y = _gy(q.x, q.z) + (1.0 - r / maxf(radius, 0.01)) * radius * 0.25
		_block(B, rng, q, rng.randf_range(0.18, 0.6) * (1.2 - r / maxf(radius, 0.01) * 0.5))

static func _barrel(B: Bins, rng: RandomNumberGenerator, p: Vector3, lying: bool = false) -> void:
	var col := _shade(rng, 0.75, 1.1)
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p)
	if lying:
		xf = Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, PI * 0.5), p + Vector3(0, 0.3, 0)) * Transform3D(Basis.IDENTITY, Vector3(0, -0.42, 0))
	var wb := B.at("wood", p)
	var ib := B.at("iron", p)
	wb.prism(xf, 0.27, 0.32, 0.42, 9, col)
	wb.prism(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.42, 0)), 0.32, 0.27, 0.42, 9, col)
	for y: float in [0.12, 0.72]:
		var r := lerpf(0.275, 0.32, 1.0 - absf(y - 0.42) / 0.42) + 0.012
		ib.prism(xf * Transform3D(Basis.IDENTITY, Vector3(0, y - 0.03, 0)), r, r, 0.06, 9, Color(0.8, 0.75, 0.7), false)

static func _crate(B: Bins, rng: RandomNumberGenerator, p: Vector3, s: float, yaw: float) -> void:
	var col := _shade(rng, 0.8, 1.15)
	var wb := B.at("wood", p)
	var xf := _xf(p + Vector3(0, s * 0.5, 0), yaw)
	wb.box(Vector3(s, s, s), xf, col)
	var dk := col.darkened(0.3)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			wb.box(Vector3(0.07, s + 0.02, 0.07), xf * Transform3D(Basis.IDENTITY, Vector3(sx * s * 0.48, 0, sz * s * 0.48)), dk)
	for sx2: float in [-1.0, 1.0]:
		wb.box(Vector3(0.06, s * 1.3, 0.05), xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.25), Vector3(sx2 * s * 0.51, 0, 0)), dk)

static func _cart(B: Bins, rng: RandomNumberGenerator, p: Vector3, yaw: float, broken: bool) -> void:
	var roll := 0.22 if broken else 0.0
	var base := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, roll), p + Vector3(0, -0.2 if broken else 0.0, 0))
	var wb := B.at("wood", p, true, true)
	var ib := B.at("iron", p)
	var col := _shade(rng, 0.7, 0.95)
	wb.box(Vector3(1.3, 0.1, 2.3), base * _xf(Vector3(0, 0.78, 0)), col)
	for sx: float in [-1.0, 1.0]:
		wb.box(Vector3(0.07, 0.42, 2.3), base * _xf(Vector3(sx * 0.62, 1.02, 0)), col.darkened(0.1))
		for zz: float in [-1.0, 0.0, 1.0]:
			wb.box(Vector3(0.08, 0.5, 0.08), base * _xf(Vector3(sx * 0.62, 0.98, zz * 1.05)), col.darkened(0.25))
	wb.box(Vector3(1.3, 0.42, 0.07), base * _xf(Vector3(0, 1.02, -1.12)), col)
	# the shafts down on the ground in front, the axle, the wheels (one off and lying, if broken)
	for sx2: float in [-0.4, 0.4]:
		wb.beam(base * Vector3(sx2, 0.7, 1.1), base * Vector3(sx2 * 1.3, 0.08, 2.9), 0.09, -1.0, col.darkened(0.15))
	ib.box(Vector3(1.75, 0.08, 0.08), base * _xf(Vector3(0, 0.55, -0.2)), Color.WHITE)
	for sx3: float in [-1.0, 1.0]:
		var wheel := base * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(sx3 * 0.82, 0.55, -0.2))
		if broken and sx3 > 0.0:
			wheel = Transform3D(Basis(Vector3.UP, yaw), p + Basis(Vector3.UP, yaw) * Vector3(1.6, 0.0, 0.8))
		wb.prism(wheel * Transform3D(Basis.IDENTITY, Vector3(0, -0.04, 0)), 0.56, 0.56, 0.08, 14, col.darkened(0.2))
		ib.prism(wheel * Transform3D(Basis.IDENTITY, Vector3(0, -0.05, 0)), 0.585, 0.585, 0.1, 14, Color.WHITE, false)
		ib.prism(wheel * Transform3D(Basis.IDENTITY, Vector3(0, -0.08, 0)), 0.12, 0.12, 0.16, 8)

static func _rack(B: Bins, rng: RandomNumberGenerator, p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var wb := B.at("wood", p, true, true)
	var ib := B.at("iron", p)
	var col := _shade(rng, 0.7, 0.9)
	for sx: float in [-0.9, 0.9]:
		wb.beam(p + b * Vector3(sx, 0, -0.35), p + b * Vector3(sx, 1.5, 0), 0.08, -1.0, col)
		wb.beam(p + b * Vector3(sx, 0, 0.35), p + b * Vector3(sx, 1.5, 0), 0.08, -1.0, col)
	wb.box(Vector3(1.95, 0.07, 0.07), Transform3D(b, p + b * Vector3(0, 1.45, 0)), col)
	wb.box(Vector3(1.95, 0.06, 0.06), Transform3D(b, p + b * Vector3(0, 0.45, 0.24)), col)
	for i in rng.randi_range(3, 6):
		var x := -0.75 + i * 0.3
		if rng.randf() < 0.6:
			# a spear leaning in the rack
			var foot := p + b * Vector3(x, 0.02, 0.34)
			var top := p + b * Vector3(x + rng.randf_range(-0.1, 0.1), 2.35, -0.12)
			wb.beam(foot, top, 0.035, -1.0, col.lightened(0.1))
			ib.beam(top, top + (top - foot).normalized() * 0.26, 0.05, 0.012)
		else:
			# a sword hung point down
			var hilt := p + b * Vector3(x, 1.4, 0.05)
			ib.box(Vector3(0.05, 0.85, 0.012), Transform3D(b, hilt + Vector3(0, -0.45, 0)), Color(1.1, 1.1, 1.1))
			ib.box(Vector3(0.22, 0.03, 0.03), Transform3D(b, hilt + Vector3(0, -0.02, 0)))
	if rng.randf() < 0.6:
		# one fallen out of it
		var f0 := p + b * Vector3(rng.randf_range(-0.4, 0.4), 0.03, 0.9)
		wb.beam(f0, f0 + b * Vector3(1.9, 0.02, 0.3), 0.035, -1.0, col)

## A dead man-at-arms of an old fight, in what was left of his harness: "sit" against a wall (back to `yaw`'s -z),
## "prone" face down, or "back".
static func _corpse(B: Bins, rng: RandomNumberGenerator, p: Vector3, yaw: float, pose: String) -> void:
	var ib := B.at("iron", p)
	var rag := B.at("bone", p)
	var bone := B.at("bone", p)
	var steel := Color(0.85, 0.85, 0.88) * rng.randf_range(0.7, 1.0)
	var cloth := [Color(0.45, 0.12, 0.08), Color(0.2, 0.22, 0.3), Color(0.3, 0.28, 0.2)][rng.randi() % 3] as Color
	var root := Transform3D(Basis(Vector3.UP, yaw), p)
	var parts: Array = []   # [batch, size, local transform, colour]
	match pose:
		"sit":
			var lean := Basis(Vector3.RIGHT, -0.28) * Basis(Vector3.FORWARD, rng.randf_range(-0.25, 0.25))
			parts.append([ib, Vector3(0.36, 0.2, 0.28), Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0.2)), steel])
			parts.append([ib, Vector3(0.42, 0.55, 0.27), Transform3D(lean, Vector3(0, 0.45, 0.08)), steel])
			parts.append([rag, Vector3(0.36, 0.5, 0.04), Transform3D(lean, Vector3(0, 0.38, 0.23)), cloth])
			parts.append([ib, Vector3(0.24, 0.27, 0.26), Transform3D(Basis(Vector3.RIGHT, 0.5) * Basis(Vector3.FORWARD, rng.randf_range(-0.6, 0.6)), Vector3(rng.randf_range(-0.08, 0.08), 0.78, 0.16)), steel * 0.9])
			for sx: float in [-1.0, 1.0]:
				var knee := rng.randf() < 0.5
				parts.append([ib, Vector3(0.15, 0.15, 0.5), Transform3D(Basis(Vector3.RIGHT, -0.5 if knee else 0.0), Vector3(sx * 0.12, 0.2 if knee else 0.1, 0.55)), steel])
				parts.append([ib, Vector3(0.13, 0.13, 0.48), Transform3D(Basis(Vector3.RIGHT, 0.6 if knee else 0.0), Vector3(sx * 0.12, 0.2 if knee else 0.08, 0.95 if knee else 1.02)), steel])
				parts.append([ib, Vector3(0.11, 0.34, 0.11), Transform3D(Basis(Vector3.FORWARD, sx * 0.15), Vector3(sx * 0.27, 0.4, 0.12)), steel])
				parts.append([ib, Vector3(0.1, 0.1, 0.32), Transform3D(Basis.IDENTITY, Vector3(sx * 0.25, 0.24, 0.35)), steel])
		_:
			var up := pose == "back"
			parts.append([ib, Vector3(0.42, 0.24, 0.6), Transform3D(Basis.IDENTITY, Vector3(0, 0.13, 0)), steel])
			parts.append([rag, Vector3(0.36, 0.04, 0.55), Transform3D(Basis.IDENTITY, Vector3(0, 0.26 if up else 0.005, -0.05)), cloth])
			parts.append([ib, Vector3(0.26, 0.24, 0.28), Transform3D(Basis(Vector3.FORWARD, rng.randf_range(-0.7, 0.7)), Vector3(rng.randf_range(-0.06, 0.06), 0.12, 0.46)), steel * 0.9])
			parts.append([ib, Vector3(0.34, 0.18, 0.22), Transform3D(Basis.IDENTITY, Vector3(0, 0.1, -0.38)), steel])
			for sx: float in [-1.0, 1.0]:
				var spread := rng.randf_range(0.0, 0.35)
				parts.append([ib, Vector3(0.15, 0.14, 0.95), Transform3D(Basis(Vector3.UP, sx * spread), Vector3(sx * (0.13 + spread * 0.3), 0.08, -0.92)), steel])
				var reach := rng.randf_range(-0.4, 1.2)
				parts.append([ib, Vector3(0.11, 0.11, 0.62), Transform3D(Basis(Vector3.UP, sx * reach), Vector3(sx * (0.3 + absf(reach) * 0.15), 0.07, 0.2 + reach * 0.12)), steel])
	for pt: Array in parts:
		(pt[0] as Batch).box(pt[1], root * (pt[2] as Transform3D), pt[3])
	# his sword and his shield, near him
	var sw := root * Vector3(rng.randf_range(0.4, 0.8) * (1.0 if rng.randf() < 0.5 else -1.0), 0.02, rng.randf_range(0.0, 0.9))
	var sy := rng.randf() * TAU
	ib.box(Vector3(0.055, 0.012, 0.95), _xf(sw, sy), Color(1.15, 1.15, 1.2))
	ib.box(Vector3(0.24, 0.035, 0.035), _xf(sw + Basis(Vector3.UP, sy) * Vector3(0, 0.01, 0.48), sy))
	if rng.randf() < 0.65:
		var sh := root * Vector3(rng.randf_range(-0.9, 0.9), 0.0, rng.randf_range(-0.5, 0.4))
		ib.prism(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.0, 0.25)), sh + Vector3(0, 0.02, 0)), 0.38, 0.33, 0.05, 10, cloth.lightened(0.15))
	if rng.randf() < 0.4:
		_bones(B, rng, root * Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)), 3)
	_decal(B, root * Vector3(0, 0, 0.2), 1.6, Color(0.16, 0.06, 0.05, 0.5), rng)

static func _bones(B: Bins, rng: RandomNumberGenerator, p: Vector3, count: int, skull: bool = true) -> void:
	var bb := B.at("bone", p)
	for i in count:
		var q := p + Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.45, 0.45))
		q.y = _gy(q.x, q.z) + 0.02
		bb.box(Vector3(0.035, 0.035, rng.randf_range(0.18, 0.45)), _xf(q, rng.randf() * TAU, rng.randf_range(-0.15, 0.15)), _shade(rng, 0.75, 1.0))
	if skull:
		var s := Vector3(p.x + rng.randf_range(-0.3, 0.3), 0, p.z + rng.randf_range(-0.3, 0.3))
		s.y = _gy(s.x, s.z)
		bb.prism(_xf(s, rng.randf() * TAU, rng.randf_range(-0.4, 0.4), rng.randf_range(-0.3, 0.3)), 0.085, 0.07, 0.17, 7, _shade(rng, 0.8, 1.0))

## A spear or a broken pole driven into the ground, leaning.
static func _spear(B: Bins, rng: RandomNumberGenerator, p: Vector3, banner: bool = false) -> void:
	var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.45, 0.45), rng.randf() * TAU, rng.randf_range(-0.45, 0.45)))
	var foot := p - tilt * Vector3(0, 0.3, 0)
	var length := rng.randf_range(1.4, 2.4)
	var top := foot + tilt * Vector3(0, length, 0)
	B.at("wood", p).beam(foot, top, 0.04, -1.0, _shade(rng, 0.8, 1.0))
	if rng.randf() < 0.75:
		B.at("iron", p).beam(top, top + tilt * Vector3(0, 0.28, 0), 0.055, 0.014)
	if banner:
		B.at("cloth", p, false).card(top - tilt * Vector3(0.02, 0.1, 0), tilt * Vector3(0.0, 0.0, 0.7), tilt * Vector3(0, -0.9, 0) + Vector3(0, -0.05, 0), 2, 4, Color(0.42, 0.1, 0.07, rng.randf()))

## A spray of arrows stuck in the turf.
static func _arrows(B: Bins, rng: RandomNumberGenerator, p: Vector3, count: int) -> void:
	var wb := B.at("wood", p)
	var bb := B.at("bone", p)
	var lean := Vector3(rng.randf_range(-0.5, 0.5), 1.0, rng.randf_range(-0.5, 0.5)).normalized()
	for i in count:
		var q := p + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
		q.y = _gy(q.x, q.z) - 0.1
		var d := (lean + Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))).normalized()
		var t := q + d * rng.randf_range(0.45, 0.65)
		wb.beam(q, t, 0.014, -1.0, Color(0.9, 0.85, 0.75))
		bb.beam(t - d * 0.12, t, 0.05, 0.006, Color(0.8, 0.78, 0.72))

## Iron chain from `a` to `b`, sagging `sag` metres in the middle; `link` is the size of a link.
static func _chain(B: Bins, a: Vector3, b: Vector3, sag: float, link: float = 0.11, cell: bool = true) -> void:
	var ib := B.at("iron", (a + b) * 0.5, cell)
	var length := a.distance_to(b) + absf(sag) * 1.2
	var count := maxi(2, int(length / (link * 0.82)))
	var prev := a
	for i in count:
		var t := float(i + 1) / count
		var q := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var dir := q - prev
		if dir.length() > 0.001:
			var bas := Basis(Quaternion(Vector3.UP, dir.normalized())) * Basis(Vector3.UP, PI * 0.5 * (i % 2))
			ib.box(Vector3(link * 0.36, link, link * 0.14), Transform3D(bas, (prev + q) * 0.5), Color(0.85, 0.8, 0.75))
		prev = q

## A brazier of iron standing on the ground with its fire (the kit's brazier, but placed by the dressing).
static func _brazier(B: Bins, p: Vector3, h: float, lit: bool) -> void:
	var ib := B.at("iron", p, false, true)
	var bowl := h * 0.52
	for i in 3:
		var d := Vector3(sin(i * TAU / 3.0), 0, cos(i * TAU / 3.0))
		ib.beam(p + d * 0.42, p + d * 0.16 + Vector3(0, bowl, 0), 0.055)
	ib.prism(Transform3D(Basis.IDENTITY, p + Vector3(0, bowl, 0)), 0.18, 0.5, 0.34, 8)
	ib.prism(Transform3D(Basis.IDENTITY, p + Vector3(0, bowl + 0.31, 0)), 0.54, 0.54, 0.06, 8, Color.WHITE, false)
	if not lit:
		B.at("rubble", p).prism(Transform3D(Basis.IDENTITY, p + Vector3(0, bowl + 0.2, 0)), 0.42, 0.36, 0.1, 8, Color(0.25, 0.23, 0.22))
		return
	B.at("coal", p, false).prism(Transform3D(Basis.IDENTITY, p + Vector3(0, bowl + 0.2, 0)), 0.44, 0.38, 0.12, 8)
	var fh := maxf(h - bowl, 0.9) * 1.05
	for c in 3:
		var r := Basis(Vector3.UP, c * PI / 3.0) * Vector3(0.39, 0, 0)
		B.at("flame", p, false).card(p + Vector3(0, bowl + 0.25 + fh, 0) - r, r * 2.0, Vector3(0, -fh, 0), 1, 1, Color.WHITE)

## A stain on the ground.
static func _decal(B: Bins, p: Vector3, s: float, col: Color, rng: RandomNumberGenerator) -> void:
	var r := Basis(Vector3.UP, rng.randf() * TAU)
	var x := r * Vector3(s * rng.randf_range(0.6, 1.0), 0, 0)
	var z := r * Vector3(0, 0, s * rng.randf_range(0.6, 1.0))
	var c := p - x * 0.5 - z * 0.5
	var y := _gy(p.x, p.z) + 0.025
	B.at("decal", p).card(Vector3(c.x, y, c.z), x, z, 1, 1, col)

## Ivy on a face: a card `w` wide hanging `h` from `top` (the middle of its top edge), across `right`, flat on a
## face whose outward normal is `face`.
static func _ivy(B: Bins, rng: RandomNumberGenerator, top: Vector3, right: Vector3, down: Vector3, face: Vector3) -> void:
	var t := top + face * 0.04 - right * 0.5
	var col := Color(rng.randf(), rng.randf_range(0.0, 1.0), 0.0, 1.0)
	var bt := B.at("ivy", top)
	bt.card(t, right, down, 2, 3, col)

## Scaffolding against a wall: poles in two rows along `dir` from `p` for `length`, standing out along `out`,
## `levels` decks of planks (some missing), braces, a ladder.
static func _scaffold(B: Bins, rng: RandomNumberGenerator, p: Vector3, dir: Vector3, out: Vector3, length: float, levels: int) -> void:
	var wb := B.at("wood", p, true, true)
	var col := Color(0.92, 0.88, 0.8)
	var bays := maxi(1, int(round(length / 2.0)))
	var step := length / bays
	var lh := 1.95
	var top := lh * levels + 1.0
	for i in bays + 1:
		for row: float in [0.35, 1.6]:
			var f := p + dir * i * step + out * row
			f.y = _gy(f.x, f.z) - 0.1
			wb.beam(f, f + Vector3(rng.randf_range(-0.05, 0.05), top + rng.randf_range(-0.3, 0.4), rng.randf_range(-0.05, 0.05)), 0.11, -1.0, _shade(rng, 0.8, 1.05) * col)
	for lv in levels:
		var y := p.y + lh * (lv + 1)
		for row2: float in [0.35, 1.6]:
			var a := p + out * row2 + Vector3(0, y - p.y, 0) - dir * 0.2
			wb.beam(a, a + dir * (length + 0.4), 0.09, -1.0, col * 0.9)
		for i2 in bays + 1:
			var a2 := p + dir * i2 * step + Vector3(0, y - p.y + 0.06, 0)
			wb.beam(a2 + out * 0.1, a2 + out * 1.85, 0.08, -1.0, col * 0.85)
		# planks, a few missing
		for k in 5:
			if rng.randf() < 0.18:
				continue
			var pc := p + dir * length * 0.5 + out * (0.4 + k * 0.28) + Vector3(0, y - p.y + 0.13, 0)
			wb.box(Vector3(0.26, 0.04, length * rng.randf_range(0.8, 0.98)), Transform3D(Basis(dir, Vector3.UP, dir.cross(Vector3.UP)).orthonormalized() * Basis(Vector3.UP, PI * 0.5), pc), _shade(rng, 0.75, 1.0) * col)
		# a brace across the outer face of each bay
		for i3 in bays:
			var b0 := p + dir * i3 * step + out * 1.62 + Vector3(0, y - p.y - lh, 0)
			wb.beam(b0, b0 + dir * step + Vector3(0, lh, 0), 0.06, -1.0, col * 0.8)
	# a ladder at one end
	var l0 := p + dir * -0.6 + out * 1.0
	l0.y = _gy(l0.x, l0.z)
	var l1 := l0 + Vector3(0, lh * levels + 0.6, 0) + dir * 0.45
	for sx: float in [-0.22, 0.22]:
		wb.beam(l0 + out * sx, l1 + out * sx, 0.06, -1.0, col)
	for r in int(l0.distance_to(l1) / 0.32):
		var q := l0.lerp(l1, (r + 0.5) * 0.32 / l0.distance_to(l1))
		wb.beam(q - out * 0.22, q + out * 0.22, 0.035, -1.0, col * 0.85)

## A row of sharpened stakes through a log (a barricade), from `a` to `b`.
static func _barricade(B: Bins, rng: RandomNumberGenerator, a: Vector3, b: Vector3) -> void:
	var wb := B.at("wood", (a + b) * 0.5, true, true)
	var d := (b - a)
	var lift := Vector3(0, 0.55, 0)
	wb.beam(a + lift, b + lift, 0.26, -1.0, Color(0.75, 0.7, 0.62))
	var side := Vector3(-d.z, 0, d.x).normalized()
	var n := int(d.length() / 0.55)
	for i in n:
		var c := a.lerp(b, (i + 0.5) / n) + lift
		var s := 1.0 if i % 2 == 0 else -1.0
		var tip := side * s * 1.0 + Vector3(0, 0.9, 0)
		wb.beam(c - tip * 0.55, c + tip * 0.75, 0.08, -1.0, _shade(rng, 0.8, 1.0))

## Upright stones of a dry-stone field wall along `pts`, two or three courses, broken here and there.
static func _drywall(B: Bins, rng: RandomNumberGenerator, pts: Array) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d := Vector3(b.x - a.x, 0, b.z - a.z)
		var n := int(d.length() / 0.55)
		var yaw := atan2(d.x, d.z)
		for j in n:
			var t := (j + rng.randf_range(0.3, 0.7)) / n
			var q := a.lerp(b, t)
			var courses := rng.randi_range(0, 3)
			for c in courses:
				var s := Vector3(0.45, 0.26, 0.6) * rng.randf_range(0.75, 1.2)
				var pp := Vector3(q.x, _gy(q.x, q.z) + 0.11 + c * 0.24, q.z)
				B.at("rubble", pp).box(s, _xf(pp, yaw + rng.randf_range(-0.25, 0.25), rng.randf_range(-0.1, 0.1), rng.randf_range(-0.12, 0.12)), _shade(rng, 0.65, 0.95))

## A heap of stones with a sword driven into its top (somebody buried a friend by the road).
static func _cairn(B: Bins, rng: RandomNumberGenerator, p: Vector3) -> void:
	for i in 12:
		var r := (1.0 - i / 12.0) * 0.75
		var a := rng.randf() * TAU
		var q := Vector3(p.x + cos(a) * r, 0, p.z + sin(a) * r)
		q.y = _gy(q.x, q.z) + i * 0.06
		_block(B, rng, q, 0.32)
	var t := p + Vector3(0, _gy(p.x, p.z) - p.y + 0.6, 0)
	var ib := B.at("iron", p)
	var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.1, 0.1), rng.randf() * TAU, rng.randf_range(-0.12, 0.12)))
	ib.box(Vector3(0.06, 1.0, 0.014), Transform3D(tilt, t + tilt * Vector3(0, 0.3, 0)), Color(1.1, 1.1, 1.15))
	ib.box(Vector3(0.3, 0.04, 0.04), Transform3D(tilt, t + tilt * Vector3(0, 0.82, 0)))
	B.at("wood", p).box(Vector3(0.04, 0.22, 0.04), Transform3D(tilt, t + tilt * Vector3(0, 0.95, 0)), Color(0.5, 0.4, 0.35))

static func _candles(B: Bins, rng: RandomNumberGenerator, p: Vector3, count: int, spread: float) -> void:
	for i in count:
		var q := p + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread * 0.6, spread * 0.6))
		q.y = _gy(q.x, q.z)
		var h := rng.randf_range(0.08, 0.34)
		var r := rng.randf_range(0.025, 0.05)
		B.at("bone", q).prism(Transform3D(Basis.IDENTITY, q), r * 1.1, r, h, 6, Color(1.05, 1.0, 0.9))
		if rng.randf() < 0.7:
			B.at("flame", q, false).card(q + Vector3(-0.035, h + 0.13, 0), Vector3(0.07, 0, 0), Vector3(0, -0.13, 0), 1, 1, Color.WHITE)
	_decal(B, p, spread * 2.6, Color(0.82, 0.78, 0.68, 0.45), rng)

static func _grave(B: Bins, rng: RandomNumberGenerator, p: Vector3, yaw: float) -> void:
	var fallen := rng.randf() < 0.25
	var s := Vector3(0.62, 0.95, 0.16) * rng.randf_range(0.85, 1.15)
	var xf := _xf(p + Vector3(0, s.y * 0.42, 0), yaw + rng.randf_range(-0.15, 0.15), rng.randf_range(-0.18, 0.12), rng.randf_range(-0.1, 0.1))
	if fallen:
		xf = _xf(p + Vector3(0, 0.07, 0), yaw, PI * 0.5 - 0.05, rng.randf_range(-0.2, 0.2))
	B.at("rubble", p).box(s, xf, _shade(rng, 0.7, 0.95))
	B.at("rubble", p).box(Vector3(0.7, 0.08, 1.6), _xf(p + Vector3(0, 0.0, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.9), yaw, 0.0, rng.randf_range(-0.04, 0.04)), _shade(rng, 0.6, 0.8))

## A paving slab lifted and broken (roots, frost or a falling stone did it).
static func _slab(B: Bins, rng: RandomNumberGenerator, p: Vector3) -> void:
	for k in rng.randi_range(1, 3):
		var q := p + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
		B.at("rubble", q).box(Vector3(rng.randf_range(0.5, 1.0), 0.13, rng.randf_range(0.45, 0.85)), _xf(Vector3(q.x, _gy(q.x, q.z) + 0.03, q.z), rng.randf() * TAU, rng.randf_range(-0.22, 0.22), rng.randf_range(-0.22, 0.22)), _shade(rng, 0.7, 0.92))

static func _weeds(route: CourtRoute, d: Node3D, pts: Array) -> void:
	if pts.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var blade := QuadMesh.new()
	blade.size = Vector2(0.55, 0.5)
	blade.center_offset = Vector3(0, 0.24, 0)
	mm.mesh = blade
	mm.instance_count = pts.size() * 2
	for i in pts.size():
		var q: Vector3 = pts[i]
		var yaw := float(i) * 1.7
		var s := 0.55 + fposmod(float(i) * 0.37, 0.6)
		for j in 2:
			mm.set_instance_transform(i * 2 + j, Transform3D(Basis(Vector3.UP, yaw + j * PI * 0.5).scaled(Vector3.ONE * s), q))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Dress_weeds"
	mi.multimesh = mm
	mi.material_override = route._mat("grass")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 50.0
	d.add_child(mi)

# ================================================================ along the walls
## The walls the route builds as plain boxes, per section: [x0, z0, x1, z1, foot height, height, open side x, z,
## merlons on top]. (The kit's walls are recorded as they are laid; see Future._court_wall.)
const BOX_WALLS := {
	1: [[15.6, -77.5, 15.6, -88.5, 3.2, 6.6, -1.0, 0.0, false], [-16.0, -95.75, -7.8, -95.75, 3.2, 4.2, 0.0, 1.0, false],
		[-7.75, -95.9, -7.75, -99.1, 3.2, 4.2, 1.0, 0.0, false], [-7.75, -102.9, -7.75, -106.0, 3.2, 4.2, 1.0, 0.0, false]],
	2: [[-15.0, -128.3, -9.0, -128.3, 4.5, 6.0, 0.0, 1.0, true], [8.8, -128.3, 13.2, -128.3, 4.5, 6.0, 0.0, 1.0, true],
		[-5.8, -125.95, -2.6, -125.95, 4.5, 5.6, 0.0, 1.0, false], [2.6, -125.95, 5.8, -125.95, 4.5, 5.6, 0.0, 1.0, false]],
	3: [[-16.0, -157.0, -3.0, -157.0, 5.5, 9.0, 0.0, 1.0, true], [3.0, -157.0, 16.0, -157.0, 5.5, 9.0, 0.0, 1.0, true]],
	4: [[-12.9, -177.4, -3.5, -177.4, 6.2, 7.0, 0.0, -1.0, true], [3.5, -177.4, 12.9, -177.4, 6.2, 7.0, 0.0, -1.0, true],
		[-21.5, -198.5, -11.5, -198.5, 8.0, 12.0, 0.0, -1.0, true], [11.5, -198.5, 21.5, -198.5, 8.0, 12.0, 0.0, -1.0, true]],
}

## What gathers along one bay of a wall's foot and grows on its face. `foot`: the bay's middle at the wall's face,
## on the ground; `dir` along the wall; `face` the open side; `w` the bay's width; `h` its height; `broken` whether
## its top came down; `up` the face's own up (a leaning wall's).
static func _bay(B: Bins, rng: RandomNumberGenerator, foot: Vector3, dir: Vector3, face: Vector3, w: float, h: float, broken: bool, up: Vector3, sec: int, weeds: Array) -> void:
	var ivy_p := 0.5 if sec == 4 else 0.34
	# ivy, hanging from the top or climbing from the foot
	if rng.randf() < ivy_p and h > 2.5:
		var iw := w * rng.randf_range(0.55, 1.0)
		var ih := h * rng.randf_range(0.35, 0.85)
		var along := rng.randf_range(-0.25, 0.25) * w
		var from_top := rng.randf() < 0.6
		var top := foot + dir * along + up * ((h - 0.05) if from_top else ih)
		_ivy(B, rng, top, dir * iw, -up * ih, face)
	var p := foot + face * rng.randf_range(0.55, 1.2) + dir * rng.randf_range(-0.3, 0.3) * w
	if blocked(p.x, p.z, 0.6):
		return
	p.y = _gy(p.x, p.z)
	# damp and earth along the foot, stains run down the face
	if rng.randf() < 0.7:
		_decal(B, p - face * 0.3, rng.randf_range(1.4, 2.6), Color(0.1, 0.1, 0.075, 0.55), rng)
	for k in rng.randi_range(1, 4):
		var q := foot + face * rng.randf_range(0.1, 0.5) + dir * rng.randf_range(-0.5, 0.5) * w
		q.y = _gy(q.x, q.z) - 0.03
		weeds.append(q)
	if broken:
		_heap(B, rng, p + face * 0.4, rng.randf_range(1.2, 2.0), rng.randi_range(7, 12))
		return
	var r := rng.randf()
	if r < 0.32:
		_heap(B, rng, p, rng.randf_range(0.5, 1.0), rng.randi_range(2, 5))
	elif r < 0.42:
		_barrel(B, rng, p, rng.randf() < 0.3)
		if rng.randf() < 0.6:
			_barrel(B, rng, p + dir * 0.7 + face * rng.randf_range(-0.1, 0.2))
		if rng.randf() < 0.5:
			_crate(B, rng, p - dir * 0.8, rng.randf_range(0.5, 0.75), rng.randf() * PI)
	elif r < 0.5:
		_corpse(B, rng, p - face * 0.15, atan2(face.x, face.z), "sit")
	elif r < 0.62:
		_bones(B, rng, p, rng.randi_range(2, 5), rng.randf() < 0.5)
	elif r < 0.68:
		_crate(B, rng, p, rng.randf_range(0.55, 0.8), rng.randf() * PI)
	# a chain hung from the wall-head, a torch bracket
	if rng.randf() < 0.1 and h > 4.0:
		var c0 := foot + dir * rng.randf_range(-0.3, 0.3) * w + up * (h - 0.6) + face * 0.12
		_chain(B, c0, c0 - up * rng.randf_range(1.5, h * 0.6), 0.0, 0.1)
	if rng.randf() < 0.14 and h > 3.0:
		var t0 := foot + up * 2.3 + face * 0.05 + dir * rng.randf_range(-0.3, 0.3) * w
		B.at("iron", t0).box(Vector3(0.06, 0.06, 0.35), Transform3D(Basis(Vector3.UP, atan2(face.x, face.z)) * Basis(Vector3.RIGHT, -0.6), t0 + face * 0.12 + Vector3(0, 0.08, 0)))
		B.at("iron", t0).prism(Transform3D(Basis.IDENTITY, t0 + face * 0.28 + Vector3(0, 0.15, 0)), 0.04, 0.08, 0.16, 6)

## A kit-built curtain wall (recorded by Future._court_wall).
static func _dress_wall(B: Bins, rng: RandomNumberGenerator, w: Dictionary, sec: int, weeds: Array) -> void:
	var from: Vector3 = w.from
	var dir: Vector3 = w.dir
	var out: Vector3 = w.out
	var seg: float = w.seg
	var th: float = w.th
	var b: Basis = w.b
	var tops: Array = w.tops
	var face := -out
	var flat_dir := Vector3(dir.x, 0, dir.z).normalized()
	for i in tops.size():
		var t := float(tops[i])
		var foot := from + dir * (i + 0.5) * seg + face * (th * 0.5)
		foot.y = _gy(foot.x, foot.z)
		# (the buttress stands at each end of a bay: keep to its middle)
		_bay(B, rng, foot, flat_dir, face, seg - 1.6, absf(t), t < 0.0, b.y.normalized(), sec, weeds)
		# the outer face gets ivy and stains too, less often
		if rng.randf() < 0.22:
			var of := from + dir * (i + 0.5) * seg + out * (th * 0.5 + 0.02)
			of.y = from.y + dir.y * (i + 0.5) * seg
			var ih := absf(t) * rng.randf_range(0.3, 0.7)
			_ivy(B, rng, of + b.y.normalized() * (absf(t) - 0.1), flat_dir * seg * 0.8, -b.y.normalized() * ih, out)

## A wall the route built as a box (BOX_WALLS).
static func _dress_box_wall(B: Bins, rng: RandomNumberGenerator, bw: Array, sec: int, weeds: Array) -> void:
	var a := Vector3(float(bw[0]), float(bw[4]), float(bw[1]))
	var e := Vector3(float(bw[2]), float(bw[4]), float(bw[3]))
	var h := float(bw[5])
	var face := Vector3(float(bw[6]), 0, float(bw[7]))
	var dir := (e - a).normalized()
	var length := a.distance_to(e)
	var n := maxi(1, int(round(length / 3.2)))
	var seg := length / n
	for i in n:
		var foot := a + dir * (i + 0.5) * seg + face * 0.01
		foot.y = _gy(foot.x - face.x * 0.3, foot.z - face.z * 0.3)
		_bay(B, rng, foot, dir, face, seg, h, false, Vector3.UP, sec, weeds)
	if bool(bw[8]):
		# crenels on the wall-head, a corbelled band under them
		var top := a.y + h
		var m := int(length / 1.3)
		var sb := B.at("stone", a, false, true)
		var yaw := atan2(dir.x, dir.z)
		for j in m:
			if rng.randf() < 0.1:
				continue
			var mh := rng.randf_range(0.8, 1.0)
			sb.box(Vector3(0.6, mh, 0.72), _xf(a + dir * (j + 0.5) * length / m + Vector3(0, top + mh * 0.5, 0) + face * 0.25, yaw), Color.WHITE)
		B.at("trim", a, false, true).box(Vector3(0.6, 0.3, length + 0.1), _xf((a + e) * 0.5 + Vector3(0, top - 0.3, 0) + face * 0.12, yaw))

# ================================================================ the places
## 0. The hillside door, the causeway, the bridge, the terrace before the breach.
static func _hill(B: Bins, rng: RandomNumberGenerator, route: CourtRoute, d: Node3D, weeds: Array) -> void:
	_portal(B, rng)
	# by the road: waymarkers, the field wall on the hill side, the dead of an old fight, the cart they had, cairns
	var p := CourtRoute.path(CourtRoute.leg_points(-1, "intro"))
	var marks := 0
	for i in range(24, p.size() - 30, 40):
		var a: Vector3 = p[i]
		var b: Vector3 = p[mini(i + 4, p.size() - 1)]
		var fw := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var side := Vector3(-fw.z, 0, fw.x)
		var sx := -1.0 if marks % 2 == 0 else 1.0
		var q := a + side * sx * 3.0
		if not blocked(q.x, q.z, 0.3) and CourtRoute.floor_at(q.x, q.z).is_empty():
			var y := _gy(q.x, q.z)
			B.at("rubble", q).box(Vector3(0.42, 1.3, 0.3), _xf(Vector3(q.x, y + 0.5, q.z), atan2(fw.x, fw.z) + rng.randf_range(-0.2, 0.2), rng.randf_range(-0.12, 0.12), rng.randf_range(-0.1, 0.1)), _shade(rng, 0.7, 0.9))
		marks += 1
	# the field wall, west of the road from the door down to the ravine
	var wall: Array = []
	var z := 44.0
	while z > -26.0:
		var x := CourtRoute._road_x(z) - 5.2 - sin(z * 0.08) * 0.8
		wall.append(Vector3(x, 0, z))
		z -= 3.0
	var parts: Array = []
	for i2 in wall.size() - 1:
		if rng.randf() < 0.75:
			parts.append([wall[i2], wall[i2 + 1]])
	for pr: Array in parts:
		_drywall(B, rng, pr)
	# the fight on the causeway: the dead, spears in the turf, arrows, a cart on its side in the ditch
	for c: Array in [[-3.6, 24.0, "prone"], [6.2, 12.0, "back"], [-1.8, 3.0, "prone"], [14.0, -4.0, "back"], [5.5, -18.0, "prone"]]:
		var cp := Vector3(float(c[0]), 0, float(c[1]))
		if blocked(cp.x, cp.z, 0.8):
			cp.x += -2.5 if cp.x < CourtRoute._road_x(cp.z) else 2.5
		if not blocked(cp.x, cp.z, 0.8):
			_corpse(B, rng, _on(cp.x, cp.z), rng.randf() * TAU, str(c[2]))
	for s: Array in [[-3.0, 27.0], [-4.4, 21.5], [7.0, 14.0], [-2.6, 8.0], [-3.4, 0.0], [13.5, -1.0], [3.4, -14.0], [12.5, -12.0], [-2.4, 14.0]]:
		if not blocked(float(s[0]), float(s[1]), 0.3):
			_spear(B, rng, _on(float(s[0]), float(s[1])), rng.randf() < 0.25)
	for ar: Array in [[-4.0, 18.0], [5.0, 9.0], [-2.8, 4.5], [11.0, -8.0], [3.0, -20.0], [7.0, 22.0]]:
		if not blocked(float(ar[0]), float(ar[1]), 0.8):
			_arrows(B, rng, _on(float(ar[0]), float(ar[1])), rng.randi_range(5, 9))
	if not blocked(-4.8, 30.0, 1.8):
		_cart(B, rng, _on(-4.8, 30.0), 0.9, true)
	for cn: Array in [[-7.5, 12.5], [12.5, -20.0]]:
		if not blocked(float(cn[0]), float(cn[1]), 0.9):
			_cairn(B, rng, _on(float(cn[0]), float(cn[1])))
	# the bridge: a parapet of stone on each side, broken in places, corbels under the deck's edge
	for sx2: float in [2.45, 6.55]:
		var zz := -33.6
		while zz > -52.4:
			var len2 := rng.randf_range(1.2, 2.2)
			if rng.randf() > 0.2:
				var y2 := _gy(sx2, zz - len2 * 0.5)
				var hh := rng.randf_range(0.55, 0.85)
				B.at("trim", Vector3(sx2, 0, zz), false, true).box(Vector3(0.36, hh, len2 - 0.1), _xf(Vector3(sx2, y2 + hh * 0.5, zz - len2 * 0.5)), _shade(rng, 0.85, 1.0))
			zz -= len2
		for zc in range(-34, -53, -2):
			B.at("trim", Vector3(sx2, 0, float(zc)), false).box(Vector3(0.5, 0.6, 0.5), _xf(Vector3(sx2 + (-0.3 if sx2 < 4.0 else 0.3), _gy(4.5, float(zc)) - 0.65, float(zc))))
	# the terrace before the breach: a siege that failed (a ram, a ladder against the wall, scaffolding where they
	# tried to mend it from outside, their dead)
	_ram(B, rng, _on(10.5, -64.5), 0.5)
	var la := _on(-9.5, -73.4)
	var lb := Vector3(-9.2, 3.0 + 7.4, -75.6)
	for sx3: float in [-0.3, 0.3]:
		B.at("wood", la, true, true).beam(la + Vector3(sx3, 0, 0), lb + Vector3(sx3, 0, 0), 0.08, -1.0, Color(0.8, 0.75, 0.68))
	for r in 20:
		var q2 := la.lerp(lb, (r + 0.5) / 20.0)
		B.at("wood", la, true, true).beam(q2 - Vector3(0.3, 0, 0), q2 + Vector3(0.3, 0, 0), 0.05, -1.0, Color(0.75, 0.7, 0.62))
	_scaffold(B, rng, Vector3(-27.0, 3.0, -75.3), Vector3(1, 0, 0), Vector3(0, 0, 1), 8.0, 3)
	for c2: Array in [[-11.5, -70.5, "back"], [9.5, -71.5, "prone"], [-6.0, -61.0, "prone"], [12.5, -60.0, "back"]]:
		if not blocked(float(c2[0]), float(c2[1]), 0.8):
			_corpse(B, rng, _on(float(c2[0]), float(c2[1])), rng.randf() * TAU, str(c2[2]))
	for ar2: Array in [[-10.5, -66.0], [8.0, -58.5], [-12.5, -61.5]]:
		if not blocked(float(ar2[0]), float(ar2[1]), 0.8):
			_arrows(B, rng, _on(float(ar2[0]), float(ar2[1])), 8)
	if not blocked(-12.8, -64.0, 0.4):
		_spear(B, rng, _on(-12.8, -64.0), true)

## The way out of the awakening chamber, as the world sees it: a portal cut into the hillside, three receding
## orders of dressed stone under a lintel with a carved roundel, the facility's ribbed passage behind it (the frames
## and plates of chamber.gd's passage, its dark beyond), a torn leaf of the old door leaning in the mouth.
static func _portal(B: Bins, rng: RandomNumberGenerator) -> void:
	var z0 := 56.75                                  # the face of the rock
	var hw := 1.35
	var h := 3.4
	var st := B.at("stone", Vector3(0, 0, z0), false, true)
	var tr := B.at("trim", Vector3(0, 0, z0), false, true)
	for o in 3:
		var x := hw + 0.27 + o * 0.5
		var zz := z0 + 0.95 - o * 0.42
		var oh := h + 0.35 + o * 0.42
		for sx: float in [-1.0, 1.0]:
			(st if o != 1 else tr).box(Vector3(0.54, oh, 1.0), _xf(Vector3(sx * x, oh * 0.5 - 0.05, zz)), Color.WHITE)
		(st if o != 1 else tr).box(Vector3(x * 2.0 + 0.54, 0.44, 1.0), _xf(Vector3(0, oh + 0.17, zz)), Color.WHITE)
	# the lintel, the roundel over it, the hewn blocks either side that the rock grows over
	tr.box(Vector3(6.4, 0.9, 1.4), _xf(Vector3(0, h + 1.85, z0 + 0.25)), Color(0.9, 0.9, 0.9))
	st.box(Vector3(4.2, 2.0, 0.9), _xf(Vector3(0, h + 3.2, z0 + 0.6)), Color.WHITE)
	tr.prism(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, h + 3.25, z0 + 0.1)), 0.8, 0.8, 0.12, 14, Color.WHITE)
	B.at("dark", Vector3.ZERO, false).prism(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, h + 3.25, z0 + 0.0)), 0.55, 0.55, 0.06, 14)
	for k in 6:
		var ang := k * TAU / 6.0
		tr.box(Vector3(0.08, 0.55, 0.08), _xf(Vector3(cos(ang) * 0.3, h + 3.25 + sin(ang) * 0.3, z0 - 0.08), 0.0, 0.0, ang + PI * 0.5), Color.WHITE)
	for sx2: float in [-1.0, 1.0]:
		for k2 in 4:
			var bs := Vector3(rng.randf_range(1.2, 2.0), rng.randf_range(1.0, 1.8), rng.randf_range(1.2, 2.0))
			var bp := Vector3(sx2 * rng.randf_range(3.4, 4.6), k2 * 1.4 + bs.y * 0.4, z0 + 0.6 + rng.randf_range(0.0, 0.8))
			st.box(bs, _xf(bp, rng.randf_range(-0.15, 0.15), rng.randf_range(-0.08, 0.08), rng.randf_range(-0.1, 0.1)), _shade(rng, 0.8, 1.0))
	# the passage behind: plated walls, frames every metre and a half, a low roof, the dark (chamber.gd's make)
	var ib := B.at("iron", Vector3(0, 0, z0), false)
	var dk := B.at("dark", Vector3.ZERO, false)
	for sx3: float in [-1.0, 1.0]:
		dk.box(Vector3(0.2, h, 3.4), _xf(Vector3(sx3 * (hw + 0.1), h * 0.5, z0 + 1.6)))
		for f in 3:
			var fz := z0 + 1.0 + f * 1.0
			ib.box(Vector3(0.24, h - 0.1, 0.22), _xf(Vector3(sx3 * (hw - 0.1), (h - 0.1) * 0.5, fz)), Color(0.55, 0.55, 0.58))
			ib.box(Vector3(0.06, 1.4, 0.8), _xf(Vector3(sx3 * (hw - 0.02), 1.5, fz + 0.5), 0.0, 0.0, sx3 * (0.18 if f == 1 else 0.0)), Color(0.7, 0.7, 0.72))
	for f2 in 3:
		ib.box(Vector3(hw * 2.0, 0.26, 0.22), _xf(Vector3(0, h - 0.13, z0 + 1.0 + f2 * 1.0)), Color(0.55, 0.55, 0.58))
	dk.box(Vector3(hw * 2.4, 0.3, 3.4), _xf(Vector3(0, h + 0.1, z0 + 1.6)))
	# the torn leaf, leaning in the mouth
	ib.box(Vector3(1.2, 2.8, 0.1), _xf(Vector3(hw - 0.55, 1.42, z0 + 0.55), deg_to_rad(-38.0), 0.0, deg_to_rad(-9.0)), Color(0.75, 0.75, 0.78))
	# moss and ivy over the head of it, earth washed down in front
	_ivy(B, rng, Vector3(-1.4, h + 4.2, z0 + 0.13), Vector3(2.6, 0, 0), Vector3(0, -2.4, 0), Vector3(0, 0, -1))
	_ivy(B, rng, Vector3(3.6, h + 2.0, z0 + 0.08), Vector3(1.6, 0, 0), Vector3(0, -3.4, 0), Vector3(0, 0, -1))
	_decal(B, Vector3(0, 0, z0 - 0.9), 3.4, Color(0.17, 0.14, 0.1, 0.6), rng)

## A battering ram under its broken roof, abandoned.
static func _ram(B: Bins, rng: RandomNumberGenerator, p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var wb := B.at("wood", p, true, true)
	var ib := B.at("iron", p)
	wb.prism(Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), p + b * Vector3(0, 1.1, -2.2)), 0.3, 0.27, 4.6, 8, Color(0.7, 0.62, 0.55))
	ib.prism(Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), p + b * Vector3(0, 1.1, 2.4)), 0.33, 0.12, 0.6, 8)
	for sz: float in [-1.4, 1.4]:
		for sx: float in [-0.9, 0.9]:
			wb.beam(p + b * Vector3(sx, 0, sz), p + b * Vector3(sx * 0.3, 2.3, sz), 0.14, -1.0, Color(0.8, 0.72, 0.62))
		ib.beam(p + b * Vector3(0, 2.25, sz), p + b * Vector3(0, 1.4, sz), 0.04)
		wb.prism(Transform3D(b * Basis(Vector3.FORWARD, PI * 0.5), p + b * Vector3(1.05, 0.45, sz)), 0.45, 0.45, 0.1, 12, Color(0.6, 0.55, 0.5))
	wb.box(Vector3(0.18, 0.18, 3.4), Transform3D(b, p + b * Vector3(0, 2.35, 0)), Color(0.8, 0.72, 0.62))
	for k in 7:
		if rng.randf() < 0.4:
			continue
		var sx2 := -1.0 if k % 2 == 0 else 1.0
		wb.box(Vector3(1.3, 0.05, 0.3), Transform3D(b * Basis(Vector3.FORWARD, sx2 * 0.55), p + b * Vector3(sx2 * 0.55, 2.0, -1.5 + k * 0.45)), _shade(rng, 0.7, 0.95))

## 1. The outer wall, the rubble yard, the guardhouse front, the curtain and its wall-walk.
static func _outer(B: Bins, rng: RandomNumberGenerator, route: CourtRoute, d: Node3D, weeds: Array) -> void:
	# the curtain's crenels and its corbelled wall-head
	var st := B.at("stone", Vector3(16, 0, -100), false, true)
	var z := -77.4
	while z > -125.0:
		if rng.randf() > 0.1:
			var mh := rng.randf_range(0.75, 0.95)
			st.box(Vector3(0.62, mh, 0.78), _xf(Vector3(16.85, 9.8 + mh * 0.5, z)), Color.WHITE)
		z -= 1.35
	B.at("trim", Vector3(16, 0, -100), false, true).box(Vector3(0.5, 0.3, 48.0), _xf(Vector3(15.5, 9.55, -101.0)))
	# shoring at the torn ends of the breach, scaffolding on the curtain where they tried to raise it again
	for sx: float in [-1.0, 1.0]:
		var foot := _on(sx * 6.6, -80.2)
		if not blocked(foot.x, foot.z, 0.3):
			B.at("wood", foot, true, true).beam(foot, Vector3(sx * 5.4, 7.4, -77.6), 0.2, -1.0, Color(0.75, 0.7, 0.62))
			B.at("wood", foot, true, true).beam(foot + Vector3(sx * 0.7, 0, 0.2), Vector3(sx * 5.4, 5.2, -77.6), 0.18, -1.0, Color(0.7, 0.66, 0.6))
	_scaffold(B, rng, Vector3(15.3, 3.2, -79.6), Vector3(0, 0, -1), Vector3(-1, 0, 0), 7.6, 2)
	# stores in the north-west corner, a cart, the rack by the guardhouse door, the dead
	for bp: Array in [[-15.0, -80.4], [-14.3, -80.6], [-15.1, -81.2], [-14.4, -81.4]]:
		_barrel(B, rng, _on(float(bp[0]), float(bp[1])))
	_barrel(B, rng, _on(-13.2, -80.9), true)
	_crate(B, rng, _on(-12.4, -80.3), 0.75, 0.3)
	_crate(B, rng, _on(-12.5, -80.4, 0.75), 0.6, 0.9)
	_crate(B, rng, _on(-15.4, -83.0), 0.7, 0.1)
	if not blocked(-10.0, -81.8, 1.6):
		_cart(B, rng, _on(-10.0, -81.8), 1.9, false)
	_rack(B, rng, _on(-7.15, -97.6), PI * 0.5)
	for c: Array in [[-5.6, -83.0, "prone", 0.0], [14.85, -78.6, "sit", -PI * 0.5], [-16.0, -93.5, "sit", PI * 0.5], [9.5, -104.5, "back", 0.0]]:
		if not blocked(float(c[0]), float(c[1]), 0.6):
			_corpse(B, rng, _on(float(c[0]), float(c[1])), float(c[3]) if str(c[2]) == "sit" else rng.randf() * TAU, str(c[2]))
	for ar: Array in [[-8.0, -86.0], [10.0, -82.5], [-11.5, -89.0]]:
		if not blocked(float(ar[0]), float(ar[1]), 0.8):
			_arrows(B, rng, _on(float(ar[0]), float(ar[1])), 6)
	# lifted, broken paving and old blood on the flags
	for i in 16:
		var x := rng.randf_range(-15.0, 14.5)
		var zz := rng.randf_range(-81.0, -105.5)
		if not blocked(x, zz, 0.9):
			_slab(B, rng, Vector3(x, 0, zz))
	for i2 in 10:
		var x2 := rng.randf_range(-14.0, 14.0)
		var z2 := rng.randf_range(-79.0, -105.0)
		_decal(B, Vector3(x2, 0, z2), rng.randf_range(1.0, 2.6), [Color(0.16, 0.06, 0.05, 0.45), Color(0.09, 0.08, 0.06, 0.5), Color(0.14, 0.17, 0.07, 0.5)][i2 % 3], rng)
	# soot round the braziers
	for sx2: float in [-1.0, 1.0]:
		_decal(B, Vector3(sx2 * 5.5, 0, -88.0 + sx2 * 2.0), 2.2, Color(0.04, 0.035, 0.03, 0.75), rng)
	_chips(B, rng, -15.5, 15.0, -60.0, -106.0, 160)

## 2. The barbican: its gate arch, machicolations and crenels, the chains, the forecourt's barricade and stores.
static func _barbican(B: Bins, rng: RandomNumberGenerator, route: CourtRoute, d: Node3D, weeds: Array) -> void:
	var zf := -125.75
	var st := B.at("stone", Vector3(0, 0, -126), false, true)
	var tr := B.at("trim", Vector3(0, 0, -126), false, true)
	_arch(st, tr, Vector3(0, 4.5, zf), 2.6, 3.5, 5.5)
	# the portcullis's grooves, the murder slots and machicolations over the gate, crenels on the block
	for sx: float in [-1.0, 1.0]:
		tr.box(Vector3(0.22, 5.4, 0.3), _xf(Vector3(sx * 2.72, 7.2, zf + 0.05)))
	for j in 9:
		tr.box(Vector3(0.36, 0.7, 0.75), _xf(Vector3(-4.0 + j * 1.0, 13.35, zf + 0.25)))
		B.at("dark", Vector3.ZERO, false).box(Vector3(0.36, 0.06, 0.3), _xf(Vector3(-3.5 + j * 1.0, 13.62, zf + 0.42)))
	st.box(Vector3(9.4, 0.9, 0.5), _xf(Vector3(0, 14.05, zf + 0.6)))
	for k in 8:
		st.box(Vector3(0.6, 0.85, 0.5), _xf(Vector3(-4.1 + k * 1.17, 14.92, zf + 0.6)))
	for side: float in [-1.0, 1.0]:
		for k2 in 8:
			st.box(Vector3(0.5, 0.85, 0.6), _xf(Vector3(side * 4.55, 14.92, -126.6 - k2 * 1.2)))
	# chains hung either side of the arch, a banner on the east tower (the west has its own)
	for sx2: float in [-1.0, 1.0]:
		_chain(B, Vector3(sx2 * 2.0, 9.9, zf + 0.35), Vector3(sx2 * 3.9, 9.6, zf + 0.35), 1.2, 0.12, false)
	B.at("cloth", Vector3(6.2, 0, -127), false).card(Vector3(5.5, 14.2, -127.6), Vector3(1.4, 0, 0), Vector3(0, -5.2, 0), 2, 8, Color(0.36, 0.08, 0.06, 0.8))
	B.at("iron", Vector3(6.2, 0, -127), false).box(Vector3(1.8, 0.1, 0.1), _xf(Vector3(6.2, 14.25, -127.65)))
	# the forecourt: a barricade, the rack, stores, a cart, the dead, soot
	_barricade(B, rng, _on(6.2, -121.4), _on(10.6, -123.2))
	_rack(B, rng, _on(-11.6, -127.4), 0.0)
	for bp: Array in [[11.4, -127.0], [12.1, -126.6], [11.8, -125.9]]:
		_barrel(B, rng, _on(float(bp[0]), float(bp[1])))
	_crate(B, rng, _on(10.3, -126.9), 0.7, 0.2)
	if not blocked(-10.6, -121.6, 1.6):
		_cart(B, rng, _on(-10.6, -121.6), -0.6, true)
	for c: Array in [[7.4, -124.6, "prone"], [-8.4, -125.5, "back"], [9.8, -119.2, "back"]]:
		if not blocked(float(c[0]), float(c[1]), 0.6):
			_corpse(B, rng, _on(float(c[0]), float(c[1])), rng.randf() * TAU, str(c[2]))
	for i in 10:
		var x := rng.randf_range(-11.5, 11.5)
		var z := rng.randf_range(-112.5, -125.5)
		if not blocked(x, z, 0.9):
			_slab(B, rng, Vector3(x, 0, z))
		_decal(B, Vector3(rng.randf_range(-11.0, 11.0), 0, rng.randf_range(-113.0, -125.0)), rng.randf_range(1.0, 2.4), Color(0.09, 0.08, 0.06, 0.45), rng)
	for sx3: float in [-1.0, 1.0]:
		_decal(B, Vector3(sx3 * 4.6, 0, -125.4), 2.0, Color(0.04, 0.035, 0.03, 0.75), rng)
	_chips(B, rng, -12.0, 12.0, -106.0, -127.0, 90)

## A pointed arch of voussoirs on a face at `at` (the middle of the opening's sill): opening `hw` either side,
## springing at `spring` above the sill, its head at `head`; the spandrels filled to the head.
static func _arch(st: Batch, tr: Batch, at: Vector3, hw: float, spring: float, head: float) -> void:
	var rise := head - spring
	# two arcs, each centred on the far side of the middle so they meet in a point at `head`
	var cx := (hw * hw - rise * rise) / (2.0 * hw)
	var r := hw - cx
	var top_a := atan2(rise, -cx) if cx < 0.0 else asin(clampf(rise / r, 0.0, 1.0))
	for sx: float in [-1.0, 1.0]:
		var c := Vector3(at.x - sx * cx, at.y + spring, at.z)
		var segs := 7
		for v in segs:
			var a0 := top_a * float(v) / segs
			var a1 := top_a * float(v + 1) / segs
			var p0 := c + Vector3(sx * r * cos(a0), r * sin(a0), 0)
			var p1 := c + Vector3(sx * r * cos(a1), r * sin(a1), 0)
			tr.beam(p0, p1, 0.5, 0.42)
			# the spandrel over this voussoir, up to the head
			var mid := (p0 + p1) * 0.5
			var fill := at.y + head + 0.5 - mid.y
			if fill > 0.05:
				st.box(Vector3(absf(p1.x - p0.x) + 0.08, fill, 0.32), _xf(Vector3(mid.x, mid.y + fill * 0.5, at.z - 0.05)))
		tr.box(Vector3(0.7, 0.3, 0.5), _xf(Vector3(at.x + sx * (hw + 0.1), at.y + spring, at.z)))

## 3. The winch yard and the inner gate, the passage.
static func _winch(B: Bins, rng: RandomNumberGenerator, route: CourtRoute, d: Node3D, weeds: Array) -> void:
	var st := B.at("stone", Vector3(0, 0, -157), false, true)
	var tr := B.at("trim", Vector3(0, 0, -157), false, true)
	_arch(st, tr, Vector3(0, 5.5, -156.75), 2.9, 3.6, 5.8)
	# the winch's chain along its beam to the gate, wrapped on the drum
	_chain(B, Vector3(-10.0, 7.65, -145.0), Vector3(-2.9, 9.0, -157.0), 0.25, 0.14, false)
	for k in 5:
		B.at("iron", Vector3(-10, 0, -145), false).prism(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-10.0, 6.9, -145.9 + k * 0.42)), 0.8, 0.8, 0.1, 14, Color(0.8, 0.75, 0.7), false)
	# the well's frame, its rope and bucket
	var wb := B.at("wood", Vector3(8.2, 0, -144.5), false, true)
	for sz: float in [-1.35, 1.35]:
		wb.beam(Vector3(8.2, 5.5, -144.5 + sz), Vector3(8.2, 8.2, -144.5 + sz * 0.8), 0.14, -1.0, Color(0.8, 0.72, 0.62))
	wb.prism(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(8.2, 7.95, -145.7)), 0.12, 0.12, 2.4, 8, Color(0.75, 0.7, 0.62))
	wb.beam(Vector3(8.2, 7.9, -144.5), Vector3(8.2, 7.0, -144.5), 0.025, -1.0, Color(0.9, 0.85, 0.7))
	wb.prism(Transform3D(Basis.IDENTITY, Vector3(8.2, 6.7, -144.5)), 0.15, 0.18, 0.3, 8, Color(0.7, 0.64, 0.56))
	# stores, firewood, a cart, the dead, scaffolding on the inner wall's east half
	for i in 6:
		var lg := Vector3(-13.6, 5.5 + 0.14 + (i % 3) * 0.24, -151.0 - (i / 3) * 0.3)
		B.at("wood", lg).prism(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), lg + Vector3(0.9, 0, 0)), 0.13, 0.12, 1.8, 7, _shade(rng, 0.6, 0.9))
	for bp: Array in [[-14.6, -153.3], [-13.9, -153.6], [-14.7, -154.2]]:
		_barrel(B, rng, _on(float(bp[0]), float(bp[1])))
	_crate(B, rng, _on(-12.6, -154.3), 0.7, 0.4)
	if not blocked(10.2, -139.8, 1.6):
		_cart(B, rng, _on(10.2, -139.8), PI * 0.5, false)
	_scaffold(B, rng, Vector3(9.0, 5.5, -156.85), Vector3(1, 0, 0), Vector3(0, 0, 1), 5.5, 3)
	for c: Array in [[-14.9, -147.0, "sit", PI * 0.5], [11.3, -150.5, "sit", -PI * 0.5], [5.5, -138.6, "back", 0.0]]:
		if not blocked(float(c[0]), float(c[1]), 0.6):
			_corpse(B, rng, _on(float(c[0]), float(c[1])), float(c[3]) if str(c[2]) == "sit" else rng.randf() * TAU, str(c[2]))
	for i2 in 8:
		var x := rng.randf_range(-15.0, 11.5)
		var z := rng.randf_range(-138.0, -156.0)
		if not blocked(x, z, 0.9):
			_slab(B, rng, Vector3(x, 0, z))
		_decal(B, Vector3(rng.randf_range(-15.0, 11.5), 0, rng.randf_range(-138.0, -156.0)), rng.randf_range(1.0, 2.4), Color(0.08, 0.08, 0.06, 0.5), rng)
	_chips(B, rng, -15.5, 12.0, -137.0, -157.0, 90)
	# the passage: transverse arches on pilasters between the roof's slabs, chains, bones in the corners, one dead
	for zp: float in [-162.4, -170.4, -174.4]:
		for sx: float in [-1.0, 1.0]:
			if sx > 0.0 and zp > -167.0:
				continue
			var y0 := _gy(0.0, zp)
			tr.box(Vector3(0.36, 12.1 - y0, 0.6), _xf(Vector3(sx * 2.82, (12.1 + y0) * 0.5, zp)))
		tr.box(Vector3(6.0, 0.5, 0.62), _xf(Vector3(0, 11.85, zp)))
	for zc: float in [-164.5, -168.5, -172.5]:
		_chain(B, Vector3(rng.randf_range(-1.6, 1.6), 12.0, zc), Vector3(rng.randf_range(-1.6, 1.6), 12.0, zc - 1.2), 1.4, 0.1)
	_bones(B, rng, Vector3(-2.5, 0, -160.5), 4)
	_bones(B, rng, Vector3(2.4, 0, -175.0), 3)
	_corpse(B, rng, _on(-2.45, -172.5), PI * 0.5, "sit")

## 4. The chapel court, the steps, the inner ward and the kneeling colossus, the keep's gate.
static func _ward(B: Bins, rng: RandomNumberGenerator, route: CourtRoute, host: Node3D, d: Node3D, weeds: Array) -> void:
	# chapel court: graves along the east wall, candles in the alcove, a toppled statue
	for i in 5:
		var gp := Vector3(9.4, 6.2, -177.6 - i * 3.2)
		if not blocked(gp.x, gp.z, 0.5):
			_grave(B, rng, gp, -PI * 0.5)
	_candles(B, rng, Vector3(-11.05, 6.2, -185.6), 7, 0.3)
	_candles(B, rng, Vector3(-11.05, 6.2, -188.4), 6, 0.3)
	_bones(B, rng, Vector3(-11.0, 6.2, -187.0), 2, true)
	_decal(B, Vector3(-9.4, 0, -187.0), 3.2, Color(0.05, 0.045, 0.04, 0.4), rng)
	var lying = await route._prop(host, "statue", 3.6, Vector3(-11.8, 6.2, -179.4), 90.0, 0.0, 0)
	if lying != null and is_instance_valid(lying):
		# toppled: lying along the north wall, its feet to the west
		(lying as Node3D).rotate_object_local(Vector3.RIGHT, PI * 0.5 - 0.06)
		(lying as Node3D).position.y += 0.8
	_heap(B, rng, Vector3(-8.2, 6.2, -179.0), 1.0, 5)
	# the gatehouse ruin's wall-head over the steps: broken springers of the arch that was, chains hanging
	for sx: float in [-1.0, 1.0]:
		for k in 4:
			B.at("trim", Vector3(0, 0, -198), false, true).box(Vector3(0.9, 1.0, 1.6), _xf(Vector3(sx * (11.0 - k * 0.55), 17.2 + k * 0.7, -197.5), 0.0, 0.0, sx * (0.15 + k * 0.12)))
		_chain(B, Vector3(sx * 5.0, 19.55, -197.0), Vector3(sx * 6.4, 19.55, -197.0), 5.0, 0.16, false)
		_chain(B, Vector3(sx * 2.2, 19.55, -198.2), Vector3(sx * 2.0, 15.5, -198.2), 0.0, 0.16, false)
	# the kneeling colossus: chained where it knelt, the floor broken round it, the weapons of the dead heaped at it
	var col := Vector3(-13.5, 8.0, -224.0)
	var front := Vector3(sin(deg_to_rad(60.0)), 0, cos(deg_to_rad(60.0)))
	for k2 in 5:
		var ang := deg_to_rad(20.0 + k2 * 72.0)
		var ring := col + Vector3(cos(ang), 0, sin(ang)) * 5.2
		if blocked(ring.x, ring.z, 0.4):
			continue
		B.at("iron", ring, false).prism(Transform3D(Basis.IDENTITY, ring), 0.3, 0.26, 0.2, 10)
		B.at("iron", ring, false).prism(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), ring + Vector3(0, 0.35, 0.03)), 0.22, 0.22, 0.06, 10, Color.WHITE, false)
		var on_it := col + Vector3(cos(ang), 0, sin(ang)) * 1.6 + Vector3(0, rng.randf_range(3.0, 5.2), 0)
		_chain(B, ring + Vector3(0, 0.3, 0), on_it, 0.9, 0.2, false)
	for k3 in 22:
		var a2 := rng.randf() * TAU
		var r2 := rng.randf_range(3.6, 6.4)
		var q := col + Vector3(cos(a2) * r2, 0, sin(a2) * r2)
		if not blocked(q.x, q.z, 0.6):
			B.at("rubble", q).box(Vector3(rng.randf_range(0.7, 1.2), 0.16, rng.randf_range(0.6, 1.0)), _xf(q + Vector3(0, 0.05, 0), rng.randf() * TAU, rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25)), _shade(rng, 0.65, 0.9))
	var heap := col + front * 3.4
	for k4 in 9:
		var hp := heap + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
		if k4 % 3 == 0:
			_spear(B, rng, hp)
		else:
			var sy := rng.randf() * TAU
			B.at("iron", hp).box(Vector3(0.055, 0.012, 0.95), _xf(hp + Vector3(0, 0.03 + k4 * 0.02, 0), sy, rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)), Color(1.1, 1.1, 1.15))
	for k5 in 4:
		var shp := heap + Vector3(rng.randf_range(-1.4, 1.4), 0.05, rng.randf_range(-1.4, 1.4))
		B.at("iron", shp).prism(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.0, 0.5)), shp), 0.4, 0.35, 0.05, 10, [Color(0.45, 0.14, 0.1), Color(0.25, 0.27, 0.34)][k5 % 2])
	_candles(B, rng, col + front * 2.0 + Vector3(0.6, 0, 0.0), 9, 0.6)
	_bones(B, rng, heap + Vector3(1.0, 0, 1.2), 5)
	_decal(B, col, 9.0, Color(0.1, 0.13, 0.06, 0.55), rng)
	# the dead of the ward: those who came for the keep and met its guardian
	for c: Array in [[-17.0, -205.0, "back"], [-15.5, -232.0, "prone"], [16.5, -207.0, "prone"], [17.5, -228.0, "back"], [-9.5, -236.0, "prone"], [10.8, -237.5, "back"], [-19.6, -214.0, "sit"], [20.2, -219.0, "sit"]]:
		if blocked(float(c[0]), float(c[1]), 0.6):
			continue
		var yaw := rng.randf() * TAU
		if str(c[2]) == "sit":
			yaw = PI * 0.5 if float(c[0]) < 0.0 else -PI * 0.5
		_corpse(B, rng, _on(float(c[0]), float(c[1])), yaw, str(c[2]))
	for s: Array in [[-11.0, -210.0], [12.0, -212.0], [-6.5, -233.0], [6.0, -231.0], [14.5, -226.0], [-16.5, -219.0]]:
		if not blocked(float(s[0]), float(s[1]), 0.3):
			_spear(B, rng, _on(float(s[0]), float(s[1])), rng.randf() < 0.3)
	for i2 in 14:
		var x := rng.randf_range(-20.0, 20.0)
		var z := rng.randf_range(-200.0, -239.0)
		if not blocked(x, z, 0.9):
			_slab(B, rng, Vector3(x, 0, z))
		_decal(B, Vector3(rng.randf_range(-20.0, 20.0), 0, rng.randf_range(-200.0, -239.0)), rng.randf_range(1.2, 3.0), [Color(0.16, 0.06, 0.05, 0.45), Color(0.08, 0.08, 0.06, 0.5)][i2 % 2], rng)
	_scaffold(B, rng, Vector3(-18.9, 8.0, -200.2), Vector3(0, 0, -1), Vector3(1, 0, 0), 6.5, 3)
	_chips(B, rng, -12.0, 12.0, -176.0, -192.0, 60)
	_chips(B, rng, -21.0, 21.0, -198.0, -240.0, 200)
	for sx2: float in [-1.0, 1.0]:
		_decal(B, Vector3(sx2 * 4.2, 0, -216.0), 2.2, Color(0.04, 0.035, 0.03, 0.75), rng)
	# the keep's gate: its statues, two braziers lit, banners from the wall-walks of the ward
	for sx3: float in [-1.0, 1.0]:
		var pl := Vector3(sx3 * 7.4, 8.0, -241.4)
		B.at("stone", pl, false, true).box(Vector3(2.5, 1.0, 2.5), _xf(pl + Vector3(0, 0.5, 0)))
		B.at("trim", pl, false, true).box(Vector3(2.8, 0.25, 2.8), _xf(pl + Vector3(0, 1.1, 0)))
		await route._prop(host, "statue", 7.2, pl + Vector3(0, 1.2, 0), sx3 * -8.0, 0.0, 1)
		var bz := Vector3(sx3 * 4.6, 8.0, -239.2)
		_brazier(B, bz, 2.3, true)
		route._lamp(host, bz + Vector3(0, 2.2, 0), FIRE, 1.7, 9.0, true)
		_decal(B, bz, 2.2, Color(0.04, 0.035, 0.03, 0.75), rng)
	for bn: Array in [[-21.0, -210.0, 1.0], [-21.0, -229.0, 1.0], [21.0, -213.0, -1.0], [21.0, -231.0, -1.0]]:
		var bx := float(bn[0]) + float(bn[2]) * 0.82
		var bzz := float(bn[1])
		B.at("iron", Vector3(bx, 0, bzz), false).box(Vector3(0.1, 0.1, 1.8), _xf(Vector3(bx + float(bn[2]) * 0.1, 16.6, bzz)))
		B.at("cloth", Vector3(bx, 0, bzz), false).card(Vector3(bx + float(bn[2]) * 0.16, 16.5, bzz - 0.75), Vector3(0, 0, 1.5), Vector3(0, -6.5, 0), 2, 10, Color([0.36, 0.2][int(bzz) % 2], 0.08, 0.06, rng.randf()))

## The keep's face in the far layer (built once): windows, a rose, a gallery over the gate, banners, crenels.
static func _far(route: CourtRoute, host: Node3D, walls: Array) -> void:
	if host.has_node("Dress"):
		return
	_devcam(route)
	var d := Node3D.new()
	d.name = "Dress"
	host.add_child(d)
	var B := Bins.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7299
	var kc := Vector3(0, 8.0, -256.0)
	var st := B.at("stone", kc, false)
	var tr := B.at("trim", kc, false)
	var face: Dictionary = {}
	for w: Dictionary in walls:
		if float(w.h) > 20.0:
			face = w
	if not face.is_empty():
		var b: Basis = face.b
		var from: Vector3 = face.from
		var dir: Vector3 = face.dir
		var out: Vector3 = face.out
		var th: float = face.th
		var length := from.distance_to(face.to)
		var up := b.y.normalized()
		# windows: two rows of lancets between the pilasters, a few still holding a little light
		for row: Array in [[12.0, 3.0], [18.5, 3.6]]:
			var k := 0
			var x := 3.4
			while x < length - 3.0:
				var c0 := from + dir * x + up * float(row[0]) + out * (th * 0.5)
				if absf((c0 - kc).x) > 4.6:
					var wh := float(row[1])
					var lit := rng.randf() < 0.18
					B.at("window" if lit else "dark", c0, false).box(Vector3(0.75, wh, 0.1), Transform3D(b, c0 + out * 0.02))
					for sx: float in [-1.0, 1.0]:
						tr.box(Vector3(0.22, wh + 0.3, 0.3), Transform3D(b, c0 + dir * sx * 0.5 + out * 0.08))
						tr.box(Vector3(0.62, 0.22, 0.3), Transform3D(b * Basis(Vector3.FORWARD, sx * 0.62), c0 + up * (wh * 0.5 + 0.2) + dir * sx * 0.2 + out * 0.08))
					tr.box(Vector3(1.0, 0.18, 0.45), Transform3D(b, c0 - up * (wh * 0.5 + 0.1) + out * 0.12))
				x += 3.4 * (2 if k % 3 == 2 else 1)
				k += 1
		# the rose over the gate, the gallery on corbels under it, crenels on the wall-head
		var rc := Vector3(kc.x, from.y, from.z) + up * 15.6 + out * (th * 0.5 + 0.05)
		tr.prism(Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), rc - out * 0.2), 2.8, 2.8, 0.5, 20, Color.WHITE)
		B.at("dark", rc, false).prism(Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), rc + out * 0.08), 2.35, 2.35, 0.05, 20)
		B.at("window", rc, false).prism(Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), rc + out * 0.1), 0.55, 0.55, 0.04, 12)
		for k2 in 8:
			var ang := k2 * TAU / 8.0
			tr.box(Vector3(0.16, 2.2, 0.16), Transform3D(b * Basis(Vector3.FORWARD, ang), rc + (dir * cos(ang + PI * 0.5) + up * sin(ang + PI * 0.5)) * 1.3 + out * 0.15))
		var gy := 11.0
		var gc := Vector3(kc.x, from.y, from.z) + up * gy + out * (th * 0.5)
		for j in 9:
			tr.box(Vector3(0.4, 0.9, 0.9), Transform3D(b, gc + dir * (-4.0 + j * 1.0) + out * 0.45 - up * 0.3))
		st.box(Vector3(9.6, 0.4, 1.4), Transform3D(b, gc + out * 0.7 + up * 0.25))
		for j2 in 12:
			st.box(Vector3(0.14, 0.9, 0.14), Transform3D(b, gc + dir * (-4.4 + j2 * 0.8) + out * 1.3 + up * 0.85))
		tr.box(Vector3(9.6, 0.16, 0.2), Transform3D(b, gc + out * 1.3 + up * 1.36))
		# banners from the wall-head
		for bx: float in [-17.0, -9.0, 9.0, 17.0]:
			var tp := Vector3(kc.x + bx, from.y, from.z) + up * 24.6 + out * (th * 0.5 + 0.3)
			B.at("iron", tp, false).box(Vector3(2.6, 0.14, 0.14), Transform3D(b, tp + up * 0.08))
			B.at("cloth", tp, false).card(tp - dir * 1.1, dir * 2.2, -up * 12.0, 2, 12, Color(0.32, 0.07, 0.05, 0.3 if absf(bx) > 10.0 else 0.8))
		# ivy climbing the face from the ward
		for iv in 5:
			var ix := rng.randf_range(2.0, length - 2.0)
			var ih := rng.randf_range(5.0, 11.0)
			var it := from + dir * ix + up * ih + out * (th * 0.5)
			if absf((it - kc).x) < 6.0:
				continue
			_ivy(B, rng, it, dir * rng.randf_range(3.0, 5.0), -up * ih, out)
	# crenels on the keep's two blocks
	for blk: Array in [[23.0, 38.0, -247.1, -269.0], [15.0, 43.5, -252.1, -268.0]]:
		var hx := float(blk[0])
		var y := float(blk[1])
		var zf := float(blk[2])
		var zb := float(blk[3])
		var m := int(hx * 2.0 / 1.6)
		for j3 in m:
			st.box(Vector3(0.9, 1.1, 0.7), _xf(Vector3(-hx + (j3 + 0.5) * hx * 2.0 / m, y + 0.55, zf - 0.35)))
		for side: float in [-1.0, 1.0]:
			var mz := int((zf - zb) / 1.6)
			for j4 in mz:
				st.box(Vector3(0.7, 1.1, 0.9), _xf(Vector3(side * (hx - 0.35), y + 0.55, zf - (j4 + 0.5) * (zf - zb) / mz)))
		tr.box(Vector3(hx * 2.0 + 0.5, 0.45, 0.6), _xf(Vector3(0, y - 0.4, zf + 0.15)))
	B.commit(d)
	for g: GeometryInstance3D in d.find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
