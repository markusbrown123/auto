class_name RouteKit
extends RefCounted
## The things on the Courtyard's road that move when they are used or met (Stage 3B): the chests, the winch with its
## crank, ratchet and running chain, the barricade in the gate passage and how it gives way, the guard post's door.
## Built from primitives merged by material in the far-future kit's own materials (src/world/future.gd Kit: ceramic
## plate, brushed alloy, a lit seam), one merged set per moving part so the part can be turned or slid on its own.
## Also `Reach`: the knight's hand placed by IK on what it uses (the way src/cine/awakening.gd takes up the sword).
##
## Sounds are the game's own events (src/core/sfx.gd): nobody here has listened to how they sit together.

# ---------------------------------------------------------------- shapes
static func _cyl(sf: SurfaceTool, r_top: float, r_bot: float, h: float, xf: Transform3D, seg: int = 12) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	sf.append_from(c, 0, xf)

static func _torus(sf: SurfaceTool, r_in: float, r_out: float, xf: Transform3D) -> void:
	var t := TorusMesh.new()
	t.inner_radius = r_in
	t.outer_radius = r_out
	t.rings = 10
	t.ring_segments = 6
	sf.append_from(t, 0, xf)

static func _x(at: Vector3, b: Basis = Basis.IDENTITY) -> Transform3D:
	return Transform3D(b, at)

static func _kit(arena: Arena, n: Node3D) -> Future.Kit:
	return Future.Kit.new(arena, n)

## Commits a kit in the Courtyard's own materials (Stage 3C's CourtDress: stone, trim, wood, iron) so that what is used
## on the road is of the same make as the walls round it; the far-future kit's own where the dressing is off.
static func _commit(k: Future.Kit) -> void:
	if CourtDress.off() or str(k.a.get_meta("future_look", "")) != "courtyard":
		k.commit()
		return
	for nm: String in k.tools:
		var m: Material = CourtDress.kit_mat(nm, k.a)
		if m == null:
			m = Look.flat(Color("#0c0d0e"), 0.8, 0.2) if nm == "dark" else Future.built(k.a, "alloy")
		Highland._commit(k.into, "Fu_" + nm, k.tools[nm], m, nm in ["pale", "alloy", "wood", "iron"])


# ---------------------------------------------------------------- the chest
## A strongbox of the old garrison: a ceramic case on alloy feet, banded and cornered in alloy, a lock plate with a
## lit seam, and a barrel lid on a hinge at the back ("Lid": rotation.x -1.9 is open). Its front faces +Z.
static func chest(parent: Node3D, arena: Arena, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "Chest"
	parent.add_child(n)
	n.position = at
	var k := _kit(arena, n)
	var p := k.tool("wood")
	var a := k.tool("iron")
	Future._box(p, Vector3(0.9, 0.44, 0.54), Vector3(0, 0.3, 0))
	# the plinth and feet
	Future._box(a, Vector3(0.96, 0.06, 0.6), Vector3(0, 0.08, 0))
	for sx: float in [-0.4, 0.4]:
		for sz: float in [-0.22, 0.22]:
			Future._box(a, Vector3(0.12, 0.08, 0.12), Vector3(sx, 0.03, sz))
	# bands, corners, handles at the ends
	for x: float in [-0.28, 0.28]:
		Future._box(a, Vector3(0.07, 0.46, 0.57), Vector3(x, 0.31, 0))
	for sx2: float in [-1.0, 1.0]:
		for sz2: float in [-1.0, 1.0]:
			Future._box(a, Vector3(0.08, 0.46, 0.08), Vector3(sx2 * 0.43, 0.31, sz2 * 0.25))
		_torus(a, 0.045, 0.07, _x(Vector3(sx2 * 0.465, 0.38, 0), Basis(Vector3.FORWARD, PI * 0.5)))
	# the lock plate and its seam
	Future._box(a, Vector3(0.16, 0.16, 0.03), Vector3(0, 0.42, 0.28))
	Future._box(k.tool("lit"), Vector3(0.012, 0.08, 0.012), Vector3(0, 0.42, 0.297))
	# inside: dark, and something in it that catches the light
	Future._box(k.tool("dark"), Vector3(0.8, 0.02, 0.44), Vector3(0, 0.505, 0))
	Future._box(k.tool("dim"), Vector3(0.22, 0.04, 0.14), Vector3(0.1, 0.52, -0.04), Basis(Vector3.UP, 0.4))
	_commit(k)
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.52, -0.27)
	n.add_child(lid)
	var kl := _kit(arena, lid)
	var lp := kl.tool("wood")
	var la := kl.tool("iron")
	Future._box(lp, Vector3(0.9, 0.06, 0.54), Vector3(0, 0.03, 0.27))
	_cyl(lp, 0.27, 0.27, 0.9, _x(Vector3(0, 0.03, 0.27), Basis(Vector3.FORWARD, PI * 0.5) * Basis().scaled(Vector3(0.42, 1.0, 1.0))), 14)
	for x2: float in [-0.28, 0.28]:
		_cyl(la, 0.285, 0.285, 0.07, _x(Vector3(x2, 0.03, 0.27), Basis(Vector3.FORWARD, PI * 0.5) * Basis().scaled(Vector3(0.43, 1.0, 1.0))), 14)
	for sx3: float in [-0.43, 0.43]:
		Future._box(la, Vector3(0.08, 0.14, 0.56), Vector3(sx3, 0.05, 0.27))
	# the hasp that drops over the lock
	Future._box(la, Vector3(0.1, 0.12, 0.03), Vector3(0, -0.04, 0.555))
	_commit(kl)
	n.set_meta("kind", "treasure")
	return n

## Opens a chest: the hasp lifts, the lid comes up on its hinge with a little weight and settles back on its stay.
static func open_chest(n: Node3D) -> Tween:
	var lid: Node3D = n.get_node("Lid")
	Sfx.play("rattle", -10.0, 1.3)
	var tw := n.create_tween()
	tw.tween_property(lid, "rotation:x", -0.08, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): Sfx.play("crack", -16.0, 0.55))
	tw.tween_property(lid, "rotation:x", -2.0, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): Sfx.play("thump", -12.0, 1.1))
	tw.tween_property(lid, "rotation:x", -1.9, 0.25).set_trans(Tween.TRANS_SINE)
	# what is inside lights as the lid comes off it
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.5)
	l.light_energy = 0.0
	l.omni_range = 1.6
	l.position = Vector3(0, 0.75, 0.1)
	n.add_child(l)
	n.create_tween().tween_property(l, "light_energy", 0.7, 1.2).set_delay(0.5)
	return tw

# ---------------------------------------------------------------- the winch
## The windlass of the gate chain: an alloy frame with a gearbox, a crank wheel turned toward the yard with a handle
## on its rim ("Crank", turning about local X), a ratchet wheel and its pawl ("Pawl"), and the chain that runs from the
## gearbox up to the drum ("Chain": its links slide along it). Built at `at` facing +X (the yard); `drum` is where the
## chain goes up to (world).
static func winch(parent: Node3D, arena: Arena, at: Vector3, drum: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "Winch"
	parent.add_child(n)
	n.position = at
	var k := _kit(arena, n)
	var a := k.tool("iron")
	var p := k.pale(false)
	var wd := k.tool("wood")
	# the bed, two uprights, a cross-tie
	Future._box(p, Vector3(1.2, 0.16, 1.5), Vector3(-0.35, 0.08, 0))
	for sz: float in [-0.62, 0.62]:
		Future._box(a, Vector3(0.16, 1.35, 0.16), Vector3(-0.5, 0.75, sz))
		Highland._beam(a, Vector3(-0.95, 0.16, sz), Vector3(-0.5, 1.2, sz), 0.06)
	Future._box(wd, Vector3(0.16, 0.14, 1.4), Vector3(-0.5, 1.42, 0))
	# the gearbox on the axle, the axle out to the crank
	Future._box(a, Vector3(0.5, 0.56, 0.5), Vector3(-0.55, 1.05, 0))
	Future._box(a, Vector3(0.54, 0.08, 0.54), Vector3(-0.55, 1.36, 0))
	Future._box(k.tool("dim"), Vector3(0.02, 0.06, 0.3), Vector3(-0.29, 1.18, 0))
	_cyl(a, 0.05, 0.05, 0.5, _x(Vector3(-0.1, 1.05, 0), Basis(Vector3.FORWARD, PI * 0.5)), 10)
	# the sprocket on top that the chain comes off
	_cyl(a, 0.16, 0.16, 0.1, _x(Vector3(-0.55, 1.5, 0), Basis(Vector3.RIGHT, PI * 0.5)), 12)
	_commit(k)
	# the crank: a spoked wheel facing the yard, a handle on its rim
	var crank := Node3D.new()
	crank.name = "Crank"
	crank.position = Vector3(0.16, 1.05, 0)
	n.add_child(crank)
	var kc := _kit(arena, crank)
	var ca := kc.tool("iron")
	_torus(ca, 0.38, 0.44, _x(Vector3.ZERO, Basis(Vector3.FORWARD, PI * 0.5)))
	for i in 6:
		var ang := i * TAU / 6.0
		Future._box(ca, Vector3(0.04, 0.8, 0.05), Vector3.ZERO, Basis(Vector3.RIGHT, ang))
	_cyl(ca, 0.09, 0.09, 0.1, _x(Vector3.ZERO, Basis(Vector3.FORWARD, PI * 0.5)), 12)
	# the handle: a short arm out from the rim, a grip at its end (pointing at the yard)
	_cyl(ca, 0.025, 0.025, 0.2, _x(Vector3(0.1, 0.41, 0), Basis(Vector3.FORWARD, PI * 0.5)), 8)
	_cyl(kc.tool("wood"), 0.034, 0.034, 0.16, _x(Vector3(0.28, 0.41, 0), Basis(Vector3.FORWARD, PI * 0.5)), 10)
	_commit(kc)
	# the ratchet beside the gearbox, and its pawl
	var rat := Node3D.new()
	rat.name = "Ratchet"
	rat.position = Vector3(-0.55, 1.05, 0.3)
	n.add_child(rat)
	var kr := _kit(arena, rat)
	_cyl(kr.tool("iron"), 0.16, 0.16, 0.05, _x(Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5)), 12)
	for i2 in 10:
		var b2 := Basis(Vector3.BACK, i2 * TAU / 10.0)
		Future._box(kr.tool("iron"), Vector3(0.05, 0.06, 0.05), b2 * Vector3(0, 0.18, 0), b2 * Basis(Vector3.BACK, 0.4))
	_commit(kr)
	var pawl := Node3D.new()
	pawl.name = "Pawl"
	pawl.position = Vector3(-0.3, 1.3, 0.33)
	n.add_child(pawl)
	var kp := _kit(arena, pawl)
	Future._box(kp.tool("iron"), Vector3(0.24, 0.04, 0.03), Vector3(-0.1, -0.04, 0), Basis(Vector3.BACK, -0.5))
	_commit(kp)
	# the chain from the sprocket up to the drum: links along the line, slid along it as it runs
	var from := Vector3(-0.55, 1.62, 0)
	var to := drum - at
	var chain := Node3D.new()
	chain.name = "Chain"
	chain.position = from
	n.add_child(chain)
	var dir := (to - from)
	var span := dir.length()
	var b := Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT)
	chain.basis = b
	var kch := _kit(arena, chain)
	var pitch := 0.11
	var links := int(span / pitch)
	for j in links + 2:
		var lb := Basis(Vector3.FORWARD, (PI * 0.5) if j % 2 == 0 else 0.0) * Basis(Vector3.RIGHT, PI * 0.5)
		_torus(kch.tool("iron"), 0.022, 0.045, _x(Vector3(0, 0, -j * pitch), lb.scaled(Vector3(1.0, 1.0, 1.6))))
	_commit(kch)
	chain.set_meta("pitch", pitch * 2.0)
	chain.set_meta("base", from)
	n.set_meta("kind", "lever")
	return n

## Where the crank's handle is now (world), for the hand.
static func handle_at(n: Node3D) -> Vector3:
	var c: Node3D = n.get_node("Crank")
	return c.global_transform * Vector3(0.3, 0.41, 0)

## Turns the crank `turns` times over `secs`: the pawl clicks over each tooth, the chain runs up toward the drum, and
## `each(u)` is called with how far through the turning it is (the gate rises with it).
static func turn_winch(n: Node3D, turns: float, secs: float, each: Callable = Callable()) -> Tween:
	var crank: Node3D = n.get_node("Crank")
	var rat: Node3D = n.get_node("Ratchet")
	var pawl: Node3D = n.get_node("Pawl")
	var chain: Node3D = n.get_node("Chain")
	var base: Vector3 = chain.get_meta("base")
	var pitch: float = float(chain.get_meta("pitch"))
	var r0 := crank.rotation.x
	var st := {"tooth": 0}
	Sfx.play("thump", -10.0, 0.7)
	var tw := n.create_tween()
	tw.tween_method(func(u: float):
		var ang := r0 + u * turns * TAU
		crank.rotation.x = ang
		rat.rotation.z = -u * turns * TAU * 0.5
		var tooth := int(u * turns * 10.0 * 0.5)
		if tooth != int(st.tooth):
			st.tooth = tooth
			pawl.rotation.z = 0.25
			n.create_tween().tween_property(pawl, "rotation:z", 0.0, 0.08)
			Sfx.play("crack", -17.0, 1.7 + randf() * 0.2)
			if tooth % 3 == 0:
				Sfx.play("rattle", -13.0, 0.7)
		# the links slide up the line by what has been wound (it reads as the chain running; one pitch repeats)
		chain.position = base + chain.basis * Vector3(0, 0, -fposmod(u * turns * 0.9, pitch))
		if each.is_valid():
			each.call(u), 0.0, 1.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

# ---------------------------------------------------------------- the barricade in the gate passage
## What the last defenders heaped across the passage: wall plates torn off and stood on end, alloy beams lashed across
## them, a wrecked crate, rubble at the foot. Each piece is its own node ("Piece0".."PieceN") with where it is thrown
## to when it gives way ("to": position, "rot": rotation), all clear of the way through the middle. `w` is its width
## across X; it faces +Z (the winch yard).
static func barricade(parent: Node3D, arena: Arena, at: Vector3, w: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Barricade"
	parent.add_child(n)
	n.position = at
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# [kind, size, position, rotation (deg), thrown to (local), thrown rotation (deg)]
	var pieces := [
		["plate", Vector3(1.5, 1.7, 0.12), Vector3(-1.45, 0.85, 0.0), Vector3(-6, 8, 4), Vector3(-2.0, 0.12, 1.4), Vector3(-90, 30, 0)],
		["plate", Vector3(1.4, 1.55, 0.12), Vector3(0.0, 0.78, 0.15), Vector3(4, -3, -3), Vector3(-1.55, 0.1, 3.4), Vector3(-92, -8, 6)],
		["plate", Vector3(1.5, 1.8, 0.12), Vector3(1.45, 0.9, -0.05), Vector3(-3, -10, -5), Vector3(1.9, 0.12, 2.2), Vector3(-88, 15, -4)],
		["beam", Vector3(0.14, 0.14, w + 0.4), Vector3(0.0, 1.15, 0.32), Vector3(0, 90, 6), Vector3(-2.05, 0.08, 4.6), Vector3(0, 3, 0)],
		["beam", Vector3(0.14, 0.14, w + 0.2), Vector3(0.1, 0.5, 0.34), Vector3(0, 90, -4), Vector3(1.75, 0.08, 4.2), Vector3(0, -4, 0)],
		["crate", Vector3(0.8, 0.7, 0.7), Vector3(-1.9, 0.35, 0.7), Vector3(0, 20, 0), Vector3(-2.15, 0.35, 0.9), Vector3(0, 34, 0)],
		["crate", Vector3(0.6, 0.55, 0.6), Vector3(1.0, 1.85, -0.1), Vector3(0, -15, 8), Vector3(2.1, 0.28, 5.4), Vector3(0, 60, 90)],
	]
	for i in pieces.size():
		var e: Array = pieces[i]
		var pn := Node3D.new()
		pn.name = "Piece%d" % i
		pn.position = e[2]
		pn.rotation_degrees = e[3]
		pn.set_meta("to", e[4])
		pn.set_meta("rot", e[5])
		n.add_child(pn)
		var k := _kit(arena, pn)
		var sz: Vector3 = e[1]
		match str(e[0]):
			"plate":
				Future._box(k.pale(false), sz, Vector3.ZERO)
				Future._box(k.alloy(false), Vector3(sz.x + 0.04, 0.1, sz.z + 0.04), Vector3(0, sz.y * 0.5 - 0.05, 0))
				Future._box(k.alloy(false), Vector3(0.08, sz.y, sz.z + 0.03), Vector3(sz.x * 0.5 - 0.04, 0, 0))
				# a torn corner and the old bolt holes
				Future._box(k.tool("dark"), Vector3(0.05, 0.05, sz.z + 0.02), Vector3(-sz.x * 0.3, sz.y * 0.3, 0))
			"beam":
				Future._box(k.tool("wood"), sz, Vector3.ZERO)
				for t in 3:
					Future._box(k.tool("dark"), Vector3(sz.x + 0.03, sz.y + 0.03, 0.06), Vector3(0, 0, (t - 1) * sz.z * 0.32))
			"crate":
				Future._box(k.tool("wood"), sz * 0.96, Vector3.ZERO)
				for sx: float in [-1.0, 1.0]:
					Future._box(k.tool("iron"), Vector3(0.06, sz.y, sz.z + 0.02), Vector3(sx * (sz.x * 0.5 - 0.03), 0, 0))
				Future._box(k.tool("iron"), Vector3(sz.x + 0.02, 0.06, sz.z + 0.02), Vector3(0, sz.y * 0.5 - 0.03, 0))
		_commit(k)
	# rubble at its foot: stays where it is
	var kr := _kit(arena, n)
	for j in 9:
		var rx := rng.randf_range(-w * 0.5, w * 0.5)
		if absf(rx) < 0.8:
			rx = signf(rx + 0.01) * rng.randf_range(0.8, w * 0.5)
		var s := rng.randf_range(0.12, 0.3)
		Future._box(kr.pale(false), Vector3(s * 1.4, s, s * 1.1), Vector3(rx, s * 0.4, rng.randf_range(-0.4, 0.8)), Basis.from_euler(Vector3(rng.randf(), rng.randf() * 3.0, rng.randf())))
	_commit(kr)
	return n

## Lies a barricade down as it was left once broken (a load of a run that already broke it).
static func broken(n: Node3D) -> void:
	for c: Node in n.get_children():
		if c is Node3D and c.has_meta("to"):
			(c as Node3D).position = c.get_meta("to")
			(c as Node3D).rotation_degrees = c.get_meta("rot")
	n.set_meta("broken", true)

## The barricade gives way: each piece is thrown out and down and comes to rest where it lands (no physics), dust.
static func smash(n: Node3D) -> void:
	if n.get_meta("broken", false):
		return
	n.set_meta("broken", true)
	Sfx.play("guard_break", -2.0, 0.7)
	Sfx.play("crack", -4.0, 0.6)
	var i := 0
	for c: Node in n.get_children():
		if not (c is Node3D and c.has_meta("to")):
			continue
		var pn: Node3D = c
		var to: Vector3 = pn.get_meta("to")
		var mid := pn.position.lerp(to, 0.5) + Vector3(0, 0.9 + 0.3 * (i % 3), 0)
		var dur := 0.55 + 0.08 * i
		var a0 := pn.position
		var tw := n.create_tween().set_parallel(true)
		tw.tween_method(func(u: float):
			# a throw: out along the line and over a low arc, landing where it is to lie
			pn.position = a0.lerp(mid, u).lerp(mid.lerp(to, u), u), 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(pn, "rotation_degrees", pn.get_meta("rot"), dur).set_trans(Tween.TRANS_SINE)
		var vol := -8.0 - i
		n.get_tree().create_timer(dur).timeout.connect(func(): Sfx.play("thump", vol, 0.85))
		i += 1
	var dust := CPUParticles3D.new()
	dust.one_shot = true
	dust.emitting = true
	dust.amount = 36 if Future.low() else 60
	dust.lifetime = 2.2
	dust.explosiveness = 0.85
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(2.2, 0.8, 0.5)
	dust.direction = Vector3(0, 0.4, 1)
	dust.spread = 60.0
	dust.initial_velocity_min = 0.6
	dust.initial_velocity_max = 2.2
	dust.gravity = Vector3(0, -0.4, 0)
	dust.damping_min = 1.0
	dust.damping_max = 2.0
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	q.material = Look.particle(Color(0.62, 0.6, 0.56, 0.5))
	dust.mesh = q
	dust.position = Vector3(0, 0.9, 0.3)
	n.add_child(dust)
	n.get_tree().create_timer(3.0).timeout.connect(dust.queue_free)

# ---------------------------------------------------------------- the knight's hand on a thing
## Places the knight's right hand by IK on what it uses (a point, or a Callable giving one each frame), with a lean of
## the body toward it and the head turned to it; runs after the rig's own pose (process_priority 100, as the
## Awakening's layers do). `w` 0..1 is how much of it is laid on; tween it.
class Reach extends Node:
	var rig: FighterRig
	var at = Vector3.ZERO          # Vector3, or Callable -> Vector3 (world)
	var dir := Vector3.FORWARD     # the way the closed hand's grip runs (world)
	var w := 0.0
	var lean := 0.0
	var curl := 0.6
	var look_w := 0.0

	func _init(r: FighterRig) -> void:
		rig = r
		process_priority = 100
		name = "Reach"

	func target() -> Vector3:
		return (at as Callable).call() if at is Callable else at

	func _process(_dt: float) -> void:
		if rig == null or not is_instance_valid(rig):
			queue_free()
			return
		var s = rig.skin
		if s == null or not s.ok or rig.body == null or (w <= 0.001 and lean <= 0.001 and look_w <= 0.001):
			return
		var sk: Skeleton3D = s.skel
		var p := target()
		if lean > 0.001:
			var right := (-rig.global_transform.basis.z).cross(Vector3.UP).normalized()
			_turn(s, "Spine1", right, -lean * 0.5)
			_turn(s, "Spine2", right, -lean * 0.5)
		if look_w > 0.001:
			var head: Vector3 = sk.global_transform * sk.get_bone_global_pose(s.bone["Head"]).origin
			var fwd := -rig.global_transform.basis.z
			var d := p - head
			var yaw := clampf(wrapf(atan2(-d.x, -d.z) - atan2(-fwd.x, -fwd.z), -PI, PI), -1.0, 1.0) * look_w
			var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.7, 0.45) * look_w
			var right2 := fwd.cross(Vector3.UP).normalized()
			_turn(s, "Neck", Vector3.UP, yaw * 0.4)
			_turn(s, "Head", Vector3.UP, yaw * 0.6)
			_turn(s, "Head", right2, pitch * 0.7)
		if w > 0.001:
			var body: Transform3D = rig.body.global_transform
			var inv := body.affine_inverse()
			var wrist: Vector3 = sk.get_bone_global_pose(s.bone["RightHand"]).origin
			var palm0: Vector3 = s._back * s._palm("Right", wrist)
			var axis0: Vector3 = s.hand_axis("Right")
			var dir_b := (body.basis.inverse() * dir).normalized()
			var k := smoothstep(0.0, 1.0, w)
			var g := dir_b if axis0 == Vector3.ZERO or axis0.dot(dir_b) < -0.95 else axis0.slerp(dir_b, k).normalized()
			s.grip_at("Right", palm0.lerp(inv * p, k), g)
			s.curl("Right", lerpf(0.15, curl, k))

	func _turn(s, b: String, axis_world: Vector3, ang: float) -> void:
		if absf(ang) < 0.0001 or not s.bone.has(b):
			return
		var sk: Skeleton3D = s.skel
		var i: int = s.bone[b]
		var ax := (sk.global_transform.basis.inverse() * axis_world).normalized()
		var g := sk.get_bone_global_pose(i)
		sk.set_bone_global_pose(i, Transform3D(Basis(ax, ang) * g.basis, g.origin))
