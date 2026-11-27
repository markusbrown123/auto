class_name HighlandSights
extends RefCounted
## What the high road is walked for: the landmarks that are seen from far off and then passed, and the work that makes the
## path look laid rather than worn. Built into the Highland arena after its wayside (Highland.build).
##
##   the Colossus   a guardian of the makers, kneeling on the moor west of the climb, the size of a cathedral
##                  (the far-future kit's own `fu_colossus`, drawn big, no shadows)
##   the Tether     a broken orbital tether: a slender tower standing in the sea off the cliff, rising through both decks
##                  of cloud and ending in torn ribs, its cable hanging from the break
##   the Falls      a stream that crosses the road under a footbridge and goes over the cliff in one fall to the sea
##   the kerbs      a laid edge along both sides of the road (whole in the first generation, broken after it)
##
## Everything is placed by the road's own coordinates, so it stays where it was meant to be if the road is moved.
## Nothing here is in the walking corridor (Corridor.HALF either side of the road's middle line).

const FALL_Z := 388.0          # where the stream crosses the road (the road's z)
const COLOSSUS_Z := 284.0
const TETHER_AT := Vector2(214.0, 352.0)
const TETHER_TALL := 640.0
const COLOSSUS_TALL := 58.0

static var off: bool = OS.get_cmdline_user_args().has("--nosights")      # dev: the road as it was before the traversal pass

static func build(a: Arena, st: Dictionary) -> void:
	if off:
		return
	a.set_meta("future_look", "courtyard")      # the kit's props take the region's colour from this
	_kerbs(a, st)
	_falls(a, st)
	_tether(a, st)
	_colossus(a, st)

# ---------------------------------------------------------------- the laid edge
static func _kerbs(a: Arena, st: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4412
	var whole := Highland._flat_tool()
	var broken := Highland._flat_tool()
	var s := 5.0
	var n := 0
	var end := Highland.road_length() - 26.0
	while s < end:
		for side: float in [-1.0, 1.0]:
			var p0 := Highland.road(s, side * 1.52)
			var p1 := Highland.road(s + 2.8, side * 1.52)
			var d := p1 - p0
			var len := d.length()
			var box := BoxMesh.new()
			box.size = Vector3(0.18, 0.15, len)
			var xf := Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), (p0 + p1) * 0.5 + Vector3(0, 0.03, 0))
			whole.append_from(box, 0, xf)
			# after the fall of the kingdom a stone in three is gone or turned over
			if rng.randf() > 0.34:
				if rng.randf() < 0.18:
					xf = Transform3D(xf.basis * Basis.from_euler(Vector3(0.0, 0.0, 0.5)), xf.origin + Vector3(side * 0.12, 0.0, 0.0))
				broken.append_from(box, 0, xf)
		s += 3.0
		n += 1
	var mat := Highland.built(Color("#b4b8b6"), 0.15, 0.55, 0.16)
	st.kept.append(Highland._commit(a, "HLKerb", whole, mat, false))
	st.ruin.append(Highland._commit(a, "HLKerbBroken", broken, mat, false))

# ---------------------------------------------------------------- the falls
## A ribbon of water laid on the ground along `pts` (x, z), `width` wide (a function of the distance along), lifted just
## off the ground; the colour channel carries how steep it is there, which the shader turns to foam.
static func _ribbon(pts: Array, width: Callable) -> ArrayMesh:
	var sf := SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	var along := 0.0
	for i in pts.size():
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[mini(i + 1, pts.size() - 1)]
		var o: Vector2 = pts[maxi(i - 1, 0)]
		var d := (q - o).normalized()
		var side := Vector2(-d.y, d.x)
		var y := Highland.height(p.x, p.y)
		var y2 := Highland.height(q.x, q.y)
		var steep := clampf(absf(y - y2) / maxf(p.distance_to(q), 0.01) / 1.1, 0.0, 1.0) if i < pts.size() - 1 else 1.0
		var w: float = width.call(along) * 0.5
		var lift := 0.14 + steep * 0.55
		var a0 := p + side * w
		var b0 := p - side * w
		rows.append([Vector3(a0.x, Highland.height(a0.x, a0.y) + lift, a0.y), Vector3(b0.x, Highland.height(b0.x, b0.y) + lift, b0.y), along, steep])
		if i < pts.size() - 1:
			along += p.distance_to(q)
	for i in rows.size() - 1:
		var r0: Array = rows[i]
		var r1: Array = rows[i + 1]
		for tri: Array in [[[r0[0], 0.0, r0], [r0[1], 1.0, r0], [r1[0], 0.0, r1]], [[r0[1], 1.0, r0], [r1[1], 1.0, r1], [r1[0], 0.0, r1]]]:
			for v: Array in tri:
				var row: Array = v[2]
				sf.set_color(Color(float(row[3]), 0, 0, 1))
				sf.set_uv(Vector2(float(v[1]), float(row[2])))
				sf.set_normal(Vector3.UP)
				sf.add_vertex(v[0])
	return sf.commit()

static func _falls(a: Arena, st: Dictionary) -> void:
	var rx := Highland._road_x(FALL_Z)
	# the stream: from a spring on the moor, across the road, to the lip of the cliff, and over
	var pts: Array = []
	var t := -46.0
	var lip := -1.0
	while t < 150.0:
		var x := rx + t
		var z := FALL_Z + sin(t * 0.085) * 3.2 + t * 0.06
		var g := Highland.height(x, z)
		if g < Highland.SEA + 2.0:
			break
		if lip < 0.0 and x > Highland.cliff_x(z) + 3.0:
			lip = float(pts.size())
		pts.append(Vector2(x, z))
		t += 1.2 if lip < 0.0 else 0.8
	if pts.size() < 10:
		return
	Highland.stream = PackedVector2Array()
	for q: Vector2 in pts:
		Highland.stream.append(q)
	var width := func(along: float) -> float: return 2.0 + 0.8 * smoothstep(40.0, 120.0, along)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/world/highland_water.gdshader")
	mat.set_shader_parameter("noise_tex", Highland._noise_tex())
	var mi := MeshInstance3D.new()
	mi.name = "HLFalls"
	mi.mesh = _ribbon(pts, width)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 40.0
	a.add_child(mi)
	st["water"] = mat
	st.sunlit.append(mat)
	# the footbridge where the road crosses it: a slab raised a hand above the ground, with a rail and a light at each end
	var sc := Highland.road_at_z(FALL_Z)
	var deck := Highland._flat_tool()
	var posts := Highland._flat_tool()
	var lights := Highland._flat_tool()
	var b0 := Highland.road(sc - 2.6)
	var b1 := Highland.road(sc + 2.6)
	var yaw := Basis.looking_at((b1 - b0).normalized(), Vector3.UP)
	var mid := (b0 + b1) * 0.5
	var slab := BoxMesh.new()
	slab.size = Vector3(3.1, 0.3, 5.4)
	deck.append_from(slab, 0, Transform3D(yaw, mid + Vector3(0, 0.14, 0)))
	for side: float in [-1.0, 1.0]:
		var rail := BoxMesh.new()
		rail.size = Vector3(0.1, 0.1, 5.4)
		posts.append_from(rail, 0, Transform3D(yaw, mid + yaw * Vector3(side * 1.5, 0.92, 0)))
		for e: float in [-2.5, 0.0, 2.5]:
			var post := BoxMesh.new()
			post.size = Vector3(0.12, 0.84, 0.12)
			posts.append_from(post, 0, Transform3D(yaw, mid + yaw * Vector3(side * 1.5, 0.56, e)))
		var lamp := BoxMesh.new()
		lamp.size = Vector3(0.16, 0.16, 0.16)
		lights.append_from(lamp, 0, Transform3D(yaw, mid + yaw * Vector3(side * 1.5, 1.04, -2.5)))
		lights.append_from(lamp, 0, Transform3D(yaw, mid + yaw * Vector3(side * 1.5, 1.04, 2.5)))
	var deck_mat := Highland.built(Color("#b4b8b6"), 0.15, 0.55, 0.16)
	Highland._commit(a, "HLBridge", deck, deck_mat, true)
	Highland._commit(a, "HLBridgeRail", posts, Highland.built(Color("#7c838a"), 0.55, 0.45, 0.35), false)
	var lamp_mat := Highland._lamp(Color("#9ff0e0"), 2.2)
	Highland._commit(a, "HLBridgeLights", lights, lamp_mat, false)
	st.lamps.append([lamp_mat, Color("#9ff0e0"), 2.2])
	# mist where it lands
	if lip > 0.0:
		var foot: Vector2 = pts[pts.size() - 1]
		var mist := CPUParticles3D.new()
		mist.name = "HLFallsMist"
		mist.amount = int(26 * Game.particle_scale())
		mist.lifetime = 3.4
		mist.preprocess = 3.4
		mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		mist.emission_sphere_radius = 3.5
		mist.direction = Vector3(0.35, 1.0, 0.0)
		mist.spread = 25.0
		mist.initial_velocity_min = 0.8
		mist.initial_velocity_max = 2.4
		mist.gravity = Vector3.ZERO
		mist.scale_amount_min = 9.0
		mist.scale_amount_max = 16.0
		var puff := QuadMesh.new()
		puff.size = Vector2(1, 1)
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		pm.albedo_color = Color(0.9, 0.94, 0.98, 0.16)
		var soft := GradientTexture2D.new()
		soft.fill = GradientTexture2D.FILL_RADIAL
		soft.fill_from = Vector2(0.5, 0.5)
		soft.fill_to = Vector2(0.5, 0.0)
		soft.width = 32
		soft.height = 32
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, 1, 1, 0))
		soft.gradient = fade
		pm.albedo_texture = soft
		puff.material = pm
		mist.mesh = puff
		mist.position = Vector3(foot.x + 2.0, Highland.SEA + 3.0, foot.y)
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		a.add_child(mist)

# ---------------------------------------------------------------- the tether
static func _tether(a: Arena, st: Dictionary) -> void:
	var at := Vector3(TETHER_AT.x, Highland.SEA - 1.0, TETHER_AT.y)
	var pale := Highland.built(Color("#cdd2d4"), 0.12, 0.6, 0.05)
	var alloy := Highland.built(Color("#6c747c"), 0.5, 0.5, 0.05)
	var body := Highland._flat_tool()
	var trim := Highland._flat_tool()
	var light := Highland._flat_tool()
	# a footing standing in the sea, then four tiers of the shaft, each stepped in, with a collar where it meets the next
	Highland._prism(trim, at - Vector3(0, 2.0, 0), 46.0, 30.0, 14.0, 10, 0.2)
	var y := 8.0
	var tiers := [[17.0, 10.0, 96.0], [10.0, 6.0, 150.0], [6.0, 4.0, 190.0], [4.0, 3.2, 150.0]]
	for i in tiers.size():
		var tr: Array = tiers[i]
		Highland._prism(body, at + Vector3(0, y, 0), float(tr[0]), float(tr[1]), float(tr[2]), 8, 0.2 + i * 0.1)
		# a band of light up three faces of the tier, and fins on the lowest
		for f in 3:
			var ang := 0.2 + i * 0.1 + PI / 8.0 + f * TAU / 3.0
			var d := Vector3(sin(ang), 0, cos(ang))
			var r0: float = float(tr[0]) * 0.93 + 0.1
			var r1: float = float(tr[1]) * 0.93 + 0.1
			Highland._beam(light, at + d * r0 + Vector3(0, y + float(tr[2]) * 0.06, 0), at + d * r1 + Vector3(0, y + float(tr[2]) * 0.94, 0), maxf(0.5, float(tr[1]) * 0.07), 0.5)
		y += float(tr[2])
		Highland._prism(trim, at + Vector3(0, y - 1.5, 0), float(tr[1]) * 1.18, float(tr[1]) * 1.18, 3.0, 8, 0.2 + i * 0.1)
	# the break: torn ribs stand out of the top, and a length of cable hangs from it, kinked, ending in nothing
	var top := at + Vector3(0, y, 0)
	for f in 5:
		var ang := f * TAU / 5.0 + 0.4
		var d := Vector3(sin(ang), 0, cos(ang))
		var h := 14.0 + 9.0 * float(f % 3)
		Highland._beam(trim, top + d * 1.6, top + d * 2.4 + Vector3(0, h, 0) + Vector3(d.z, 0, -d.x) * 1.5, 0.9, 0.9)
	var c0 := top + Vector3(2.6, -2.0, 0)
	var c1 := c0 + Vector3(9.0, -26.0, 3.0)
	var c2 := c1 + Vector3(-5.0, -40.0, 6.0)
	var c3 := c2 + Vector3(11.0, -52.0, -4.0)
	for seg: Array in [[c0, c1], [c1, c2], [c2, c3]]:
		Highland._beam(trim, seg[0], seg[1], 0.7, 0.7)
	Highland._beam(light, c3, c3 + Vector3(0.5, -3.0, 0.5), 0.5, 0.5)
	var far_mi := Highland._commit(a, "HLTether", body, pale, false)
	far_mi.custom_aabb = AABB(at - Vector3(60, 10, 60), Vector3(120, TETHER_TALL + 40.0, 120))
	Highland._commit(a, "HLTetherTrim", trim, alloy, false).custom_aabb = far_mi.custom_aabb
	var lamp := Highland._lamp(Color("#9ff0e0"), 2.6)
	Highland._commit(a, "HLTetherLight", light, lamp, false).custom_aabb = far_mi.custom_aabb
	st.lamps.append([lamp, Color("#9ff0e0"), 2.6])

# ---------------------------------------------------------------- the colossus
static func _colossus(a: Arena, st: Dictionary) -> void:
	var rx := Highland._road_x(COLOSSUS_Z)
	var x := rx - 82.0
	var pos := Highland.on_ground(x, COLOSSUS_Z)
	pos.y = maxf(pos.y, Highland.SEA + 12.0) - 0.8
	var toward := Highland.on_ground(rx, COLOSSUS_Z + 6.0)
	var yaw := Future.toward(pos, -10.0, toward)
	var m := Future.prop(a, "fu_colossus", COLOSSUS_TALL, pos, yaw, 0.03, 0)
	if m == null:
		return
	m.name = "HLColossus"
