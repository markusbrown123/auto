class_name DragonSkin
extends RefCounted
## A generated, auto-rigged dragon model driven by the procedural DragonRig's controls.
## The auto-rigger's bone names are only partly meaningful, so limbs, tail and wings are found by where they are.

var root: Node3D
var skel: Skeleton3D
var ok := false
var _g := {}                # bone index -> global rest
var _neck: Array = []       # bone indices, base to head
var _tail: Array = []
var _fore := {}             # "r"/"l" -> limb root bone
var _wings: Array = []      # [bone, side]
var _hind := {}             # "r"/"l" -> hind limb root bone
var _jaw := -1              # the bone that carries the lower jaw, if the rig has one
var _to_skel := Basis.IDENTITY     # rig body space -> skeleton space
var _fwd := Vector3.FORWARD        # the model's own forward, in skeleton space

static func attach(parent: Node3D, path: String) -> DragonSkin:
	if not ResourceLoader.exists(path):
		return null
	var d := DragonSkin.new()
	d.root = (load(path) as PackedScene).instantiate()
	parent.add_child(d.root)
	var found: Array = d.root.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		d.root.queue_free()
		return null
	d.skel = found[0]
	d._analyse()
	return d if d.ok else null

func _chain_up(i: int, n: int) -> Array:
	var out: Array = []
	while i >= 0 and out.size() < n:
		out.push_front(i)
		i = skel.get_bone_parent(i)
	return out

func _tip_of(i: int) -> int:
	# follow the first child down to the end of the chain
	var kids := skel.get_bone_children(i)
	while not kids.is_empty():
		i = kids[0]
		kids = skel.get_bone_children(i)
	return i

func _analyse() -> void:
	var n := skel.get_bone_count()
	var head_tip := -1
	var limb_roots: Array = []
	for i in n:
		_g[i] = skel.get_bone_global_rest(i)
		var nm := skel.get_bone_name(i)
		if nm.contains("Head_") and (head_tip < 0 or nm > skel.get_bone_name(head_tip)):
			head_tip = i
		if nm.ends_with("Limb_0"):
			limb_roots.append(i)
	if head_tip < 0 or limb_roots.size() < 4:
		push_warning("dragon skin: skeleton not understood")
		return
	var centre := Vector3.ZERO
	for i in limb_roots:
		centre += (_g[i] as Transform3D).origin / limb_roots.size()
	# forward runs along the spine: from the hind pair of legs to the fore pair. The head only decides which end is the front
	# (a long neck held to one side would otherwise turn the whole body).
	var f: Vector3 = (_g[head_tip] as Transform3D).origin - centre
	var best_d := 1.0e9
	var mate := 1
	for k in range(1, 4):
		var dd: float = ((_g[limb_roots[0]] as Transform3D).origin - (_g[limb_roots[k]] as Transform3D).origin).length()
		if dd < best_d:
			best_d = dd
			mate = k
	var pair_a: Vector3 = ((_g[limb_roots[0]] as Transform3D).origin + (_g[limb_roots[mate]] as Transform3D).origin) * 0.5
	var pair_b := Vector3.ZERO
	for k in range(1, 4):
		if k != mate:
			pair_b += (_g[limb_roots[k]] as Transform3D).origin * 0.5
	var axis := pair_a - pair_b
	axis = Vector3(axis.x, 0, axis.z)
	if axis.length() > 0.01:
		f = axis * signf(axis.dot(f))
	_fwd = Vector3(f.x, 0, f.z).normalized()
	var right := _fwd.cross(Vector3.UP).normalized()
	# forelegs: the two limb roots furthest forward
	limb_roots.sort_custom(func(a, b): return ((_g[a] as Transform3D).origin - centre).dot(_fwd) > ((_g[b] as Transform3D).origin - centre).dot(_fwd))
	for i in [limb_roots[0], limb_roots[1]]:
		_fore["r" if ((_g[i] as Transform3D).origin - centre).dot(right) > 0.0 else "l"] = i
	for i in [limb_roots[2], limb_roots[3]]:
		_hind["r" if ((_g[i] as Transform3D).origin - centre).dot(right) > 0.0 else "l"] = i
	# the neck is the chain behind the head, but not the part of the spine that carries legs or wings: turning that
	# to aim the head would swing the whole body
	_neck = []
	for nb: int in _chain_up(head_tip, 5):
		var carries := false
		for lr: int in limb_roots:
			if _under(lr, nb):
				carries = true
		if not carries:
			_neck.append(nb)
	if _neck.is_empty():
		_neck = [head_tip]
	# jaw: a side branch off the head chain that hangs below it and reaches forward
	var best_jaw := 0.0
	for hb in _neck.slice(maxi(0, _neck.size() - 3)):
		for kid in skel.get_bone_children(hb):
			if _neck.has(kid):
				continue
			var is_trunk := false
			for lr2: int in limb_roots:
				if _under(lr2, kid):
					is_trunk = true
			if is_trunk:
				continue
			var tipj: Vector3 = (_g[_tip_of(kid)] as Transform3D).origin
			var basej: Vector3 = (_g[hb] as Transform3D).origin
			var score := (basej.y - tipj.y) * 2.0 + (tipj - basej).dot(_fwd)
			if tipj.y < basej.y and score > best_jaw:
				best_jaw = score
				_jaw = kid
	# tail: the chain whose tip is furthest back; wings: chains whose tips are highest and off-centre
	var best_back := 0.0
	var tail_tip := -1
	var ground := 1.0e9
	for i in n:
		var p: Vector3 = (_g[i] as Transform3D).origin
		ground = minf(ground, p.y)
		if skel.get_bone_children(i).is_empty():
			var back := -(p - centre).dot(_fwd)
			if back > best_back:
				best_back = back
				tail_tip = i
	if tail_tip >= 0:
		_tail = _chain_up(tail_tip, 6)
	for i in n:
		var nm2 := skel.get_bone_name(i)
		var par := skel.get_bone_parent(i)
		if nm2.begins_with("bone_") and par >= 0 and not skel.get_bone_name(par).begins_with("bone_") and not _tail.has(i):
			var tip: Vector3 = (_g[_tip_of(i)] as Transform3D).origin
			# (horns and crests also rise from the head: a wing hangs from the trunk and is a chain of several bones)
			var on_head := _neck.has(par) or skel.get_bone_name(par).contains("Head_")
			if tip.y > centre.y + 0.05 and absf((tip - centre).dot(right)) > 0.02 and not on_head and _depth(i) >= 3:
				_wings.append([i, signf((tip - centre).dot(right))])
	# The auto-rigger does not always name a leg as one. Any other chain that hangs from the trunk, off-centre, and
	# reaches the ground is a leg too: it must be counted as one when the body comes down.
	var legs: Array = limb_roots.duplicate()
	var leg_top: float = (_g[limb_roots[0]] as Transform3D).origin.y
	for i in n:
		var par2 := skel.get_bone_parent(i)
		if par2 < 0 or legs.has(i) or _tail.has(i) or _neck.has(i):
			continue
		var taken := false
		for lr0: int in legs:
			if _under(i, lr0):
				taken = true
		for w0 in _wings:
			if _under(i, w0[0]):
				taken = true
		for t0: int in _tail:
			if _under(i, t0):
				taken = true
		if taken or _depth(i) < 3:
			continue
		var top0: Vector3 = (_g[i] as Transform3D).origin
		var tip0: Vector3 = (_g[_tip_of(i)] as Transform3D).origin
		if top0.y - ground > 0.5 * (leg_top - ground) and tip0.y - ground < 0.2 * (leg_top - ground) and absf((tip0 - centre).dot(right)) > 0.02:
			var carries_leg := false
			for lr1: int in limb_roots:
				if _under(lr1, i):
					carries_leg = true
			if not carries_leg:
				legs.append(i)
				_extra.append([i, "r" if (tip0 - centre).dot(right) > 0.0 else "l"])
	limb_roots = legs
	# the ground is where the soles of the feet are, not where the lowest bone is: measured on the mesh itself
	var measured := _measure(limb_roots)
	if measured.has("ground"):
		ground = measured.ground
	# paws: the joint low on each leg that the foot hangs from, kept level when the leg swings
	for lr3: int in limb_roots:
		var top_y: float = (_g[lr3] as Transform3D).origin.y
		var b3: int = lr3
		var paw := -1
		while true:
			var next := -1
			var kids3 := skel.get_bone_children(b3)
			for kid2 in kids3:
				if skel.get_bone_name(kid2).contains("Limb_"):
					next = kid2
					break
			if next < 0 and not kids3.is_empty() and not skel.get_bone_name(lr3).contains("Limb_"):
				next = kids3[0]
			if next < 0:
				break
			b3 = next
			if paw < 0 and (_g[b3] as Transform3D).origin.y - ground < 0.22 * (top_y - ground):
				paw = b3
		_paw[lr3] = paw
	# wings: how high each is held at rest (radians above level), its span, and its bones
	for w2 in _wings:
		var wr: Vector3 = (_g[w2[0]] as Transform3D).origin
		var far := wr
		var span := 0.0
		var under_w: Array = []
		for bi3 in n:
			if _under(bi3, w2[0]) and bi3 != w2[0]:
				under_w.append(bi3)
				var bp: Vector3 = (_g[bi3] as Transform3D).origin
				span = maxf(span, bp.distance_to(wr))
				if absf((bp - wr).dot(right)) > absf((far - wr).dot(right)):
					far = bp
		_wing_info[w2[0]] = [atan2(far.y - wr.y, maxf(absf((far - wr).dot(right)), 0.0001)), span, under_w]
	# fit: shoulders at the procedural dragon's shoulder height, facing -Z
	var shoulder: Vector3 = ((_g[_fore.values()[0]] as Transform3D).origin + (_g[_fore.values()[-1]] as Transform3D).origin) * 0.5
	var rel: Transform3D = root.global_transform.affine_inverse() * skel.global_transform
	var k: float = 1.6 / maxf((shoulder.y - ground) * rel.basis.get_scale().y, 0.001)
	_belly = (float(measured.get("belly", ground)) - ground) * rel.basis.get_scale().y * k
	_ground = ground
	_unit = rel.basis.get_scale().y * k
	for lr5: int in limb_roots:
		var under: Array = []
		for bi2 in n:
			if _under(bi2, lr5) and bi2 != lr5:
				under.append(bi2)
		_limb_bones[lr5] = under
	for lr4: int in limb_roots:
		_leg_h[lr4] = ((_g[lr4] as Transform3D).origin.y - ground) * rel.basis.get_scale().y * k
	root.scale = Vector3.ONE * k
	var fw_root: Vector3 = (rel.basis * _fwd).normalized()
	root.rotation.y = atan2(fw_root.x, fw_root.z) + PI
	if (Basis(Vector3.UP, root.rotation.y) * fw_root).z > -0.9:
		root.rotation.y = -atan2(fw_root.x, fw_root.z) + PI
	var sh_body: Vector3 = root.transform * (rel * shoulder)
	root.position += Vector3(0, 1.6, 0.4) - sh_body
	_to_skel = (root.transform.basis * rel.basis).orthonormalized().inverse()
	_root_at = root.position
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ok = true

var _paw := {}              # limb root -> paw joint (or -1)
var _leg_h := {}            # limb root -> its height above the ground, rig units
var _belly := 0.5           # how far the belly hangs above the ground, rig units
var _root_at := Vector3.ZERO
var _ground := 0.0          # the soles' height at rest, skeleton units
var _unit := 1.0            # rig units per skeleton unit
var _limb_bones := {}       # limb root -> every bone below it
var _extra: Array = []      # legs the rigger did not name: [root bone, "r"/"l"]
var _wing_info := {}        # wing root -> [radians held above level at rest, span, bones below it]
var _hang := {}             # leg bone -> how far its flesh hangs below the joint at rest, skeleton units

func _under(i: int, ancestor: int) -> bool:
	while i >= 0:
		if i == ancestor:
			return true
		i = skel.get_bone_parent(i)
	return false

func _depth(i: int) -> int:
	var n := 1
	var kids := skel.get_bone_children(i)
	while not kids.is_empty():
		n += 1
		kids = skel.get_bone_children(kids[0])
	return n

## From the mesh at rest: the height of the lowest point of the feet (the ground) and of the trunk (the belly).
func _measure(limb_roots: Array) -> Dictionary:
	var ground := 1e9
	var belly := 1e9
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.mesh == null:
			continue
		var binds: Array = []
		for b in mi.skin.get_bind_count():
			var bi := mi.skin.get_bind_bone(b)
			if bi < 0:
				bi = skel.find_bone(mi.skin.get_bind_name(b))
			var kind := 0      # 0 other, 1 leg, 2 trunk
			if bi >= 0:
				for lr: int in limb_roots:
					if _under(bi, lr):
						kind = 1
				if kind == 0:
					var carries := false
					for lr2: int in limb_roots:
						if _under(lr2, bi):
							carries = true
					if carries:
						kind = 2
			binds.append([kind, (skel.get_bone_global_rest(bi) * mi.skin.get_bind_pose(b)) if bi >= 0 else Transform3D.IDENTITY, bi])
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null or pos.is_empty():
				continue
			var nb: int = bones.size() / pos.size()
			var step: int = maxi(1, pos.size() / 20000)
			for i in range(0, pos.size(), step):
				var top := 0
				for k in range(1, nb):
					if weights[i * nb + k] > weights[i * nb + top]:
						top = k
				var bind: Array = binds[bones[i * nb + top]]
				var y: float = ((bind[1] as Transform3D) * pos[i]).y
				if int(bind[0]) == 1:
					ground = minf(ground, y)
					# how far below its own joint each leg bone's flesh hangs, at rest
					var bj: int = bind[2]
					_hang[bj] = maxf(float(_hang.get(bj, 0.0)), (_g[bj] as Transform3D).origin.y - y)
				elif int(bind[0]) == 2:
					belly = minf(belly, y)
	var out := {}
	if ground < 1e8:
		out["ground"] = ground
	if belly < 1e8:
		out["belly"] = belly
	return out

func _turn(i: int, r: Basis) -> void:
	# rotate one bone (and with it everything below) about its own joint, by a rotation given in rig space
	var g := skel.get_bone_global_pose(i)
	var rs := _to_skel * r * _to_skel.inverse()
	skel.set_bone_global_pose(i, Transform3D(rs * g.basis, g.origin))

## Controls from the procedural rig, all in its body space:
## aim (unit vector the head points along), reach (-1 pulled back .. 1 lunging), claw 0..1, claw_side ±1, claw_x 0..1,
## spread 0..1, flap (radians), clock (seconds), sink 0..1.
func drive(c: Dictionary) -> void:
	skel.reset_bone_poses()
	var aim: Vector3 = c.aim
	var yaw := atan2(-aim.x, -aim.z)
	var pitch := asin(clampf(aim.y, -1.0, 1.0))
	var nn := float(_neck.size())
	for i in _neck:
		_turn(i, Basis(Vector3.UP, yaw / nn) * Basis(Vector3.RIGHT, (pitch + float(c.reach) * 0.25) / nn))
	if _jaw >= 0 and float(c.get("jaw", 0.0)) > 0.01:
		_turn(_jaw, Basis(Vector3.RIGHT, -0.7 * float(c.jaw)))      # the mouth opens for bites, roars and breath
	# walking: a diagonal gait, each leg swinging from its root as the body covers ground
	var wa: float = c.get("walk_amt", 0.0)
	if wa > 0.01:
		var ph: float = c.get("walk", 0.0)
		for side: String in _fore:
			var sgn := 1.0 if side == "r" else -1.0
			if not (sgn == float(c.claw_side) and float(c.claw) > 0.01):
				_swing(_fore[side], sin(ph) * sgn * 0.32 * wa)
		for side2: String in _hind:
			_swing(_hind[side2], -sin(ph) * (1.0 if side2 == "r" else -1.0) * 0.28 * wa)
	# breathing: the whole chest rises a little
	if not _neck.is_empty():
		_turn(_neck[0], Basis(Vector3.RIGHT, sin(float(c.clock) * 1.3) * 0.025))
	for side: String in _fore:
		var sx := 1.0 if side == "r" else -1.0
		if sx == float(c.claw_side) and float(c.claw) > 0.01:
			var cl: float = c.claw
			var lift := Basis(Vector3.RIGHT, 1.25 * cl * (1.0 - 0.5 * float(c.claw_x)))
			_turn(_fore[side], Basis(Vector3.UP, -sx * float(c.claw_x) * 0.9 * cl) * lift)
			# the paw stays level as the leg comes up: its claws and spurs sweep forward, they are not driven into the floor
			if int(_paw.get(_fore[side], -1)) >= 0:
				_turn(_paw[_fore[side]], lift.inverse())
	for k in _tail.size():
		var u := float(k) / maxf(_tail.size() - 1, 1)
		_turn(_tail[k], Basis(Vector3.UP, sin(float(c.clock) * 1.4 + u * 3.0) * 0.16))
	# dying: the body comes down onto its belly and the legs splay out from under it, instead of the whole animal
	# sinking through the floor on straight legs
	var sink: float = c.get("sink", 0.0)
	var drop := sink * _belly * 0.94
	root.position = _root_at - Vector3(0, drop, 0)
	if drop > 0.001:
		# the floor, in the skeleton's own heights, has come up by the drop
		var floor_y := _ground + drop / maxf(_unit, 0.0001)
		for group: Dictionary in [_fore, _hind]:
			for side3: String in group:
				_splay(group[side3], side3, drop, floor_y)
		for ex: Array in _extra:
			_splay(ex[0], ex[1], drop, floor_y)
	# Wings: each model holds them differently at rest (raised in a V, or already level). Spread means level with the
	# shoulders and a little above, whatever the rest pose was; and no wing bone is ever turned down into the floor.
	var floor_w := _ground + drop / maxf(_unit, 0.0001)
	for w in _wings:
		var wi: int = w[0]
		var info: Array = _wing_info.get(wi, [0.5, 1.0, []])
		var turn_down := (float(info[0]) - 0.18) * float(c.spread) + float(c.flap)
		_turn(wi, Basis(Vector3.FORWARD, float(w[1]) * turn_down))
		var low_w := 1e9
		for b7: int in info[2]:
			low_w = minf(low_w, skel.get_bone_global_pose(b7).origin.y)
		var need := floor_w + float(info[1]) * 0.06 - low_w
		if need > 0.0:
			_turn(wi, Basis(Vector3.FORWARD, -float(w[1]) * asin(clampf(need / maxf(float(info[1]), 0.001), 0.0, 1.0))))
	# Whatever the legs are doing (a stride, a raised claw, a sprawl), no foot is left under the floor:
	# the animal rides up by however far the lowest one would be in it.
	var lowest := 1e9
	for lr6: int in _limb_bones:
		for b6: int in _limb_bones[lr6]:
			lowest = minf(lowest, skel.get_bone_global_pose(b6).origin.y - float(_hang.get(b6, 0.0)))
	var floor_now := _ground + drop / maxf(_unit, 0.0001)
	if lowest < floor_now:
		root.position.y += (floor_now - lowest) * _unit

## One leg of a body that has come down by `drop`: rolled out sideways from its root until no joint of it is under the floor.
func _splay(lr: int, side: String, drop: float, floor_y: float) -> void:
	var paw: int = int(_paw.get(lr, -1))
	var base := skel.get_bone_global_pose(lr)
	var paw_base: Transform3D = skel.get_bone_pose(paw) if paw >= 0 else Transform3D.IDENTITY
	var a := acos(clampf(1.0 - drop / maxf(float(_leg_h.get(lr, 1.0)), 0.05), -1.0, 1.0))
	# a bent leg does not lift its foot as a straight one would: splay further until it is clear
	for attempt in 8:
		skel.set_bone_global_pose(lr, base)
		if paw >= 0:
			skel.set_bone_pose(paw, paw_base)
		var roll := Basis(Vector3.FORWARD, -a if side == "r" else a)
		_turn(lr, roll)
		if paw >= 0:
			_turn(paw, roll.inverse())
		var low := 1e9
		for b: int in _limb_bones.get(lr, []):
			low = minf(low, skel.get_bone_global_pose(b).origin.y)
		if low >= floor_y + float(_leg_h.get(lr, 1.0)) / maxf(_unit, 0.0001) * 0.03 or a >= 1.5:
			break
		a = minf(a + 0.14, 1.5)

## Swing a leg from its root, keeping the paw level so the toes do not dig into the floor.
func _swing(limb: int, angle: float) -> void:
	var r := Basis(Vector3.RIGHT, angle)
	_turn(limb, r)
	if int(_paw.get(limb, -1)) >= 0:
		_turn(_paw[limb], r.inverse())
