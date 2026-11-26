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
	_neck = _chain_up(head_tip, 5)
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
			if tip.y > centre.y + 0.05 and absf((tip - centre).dot(right)) > 0.02:
				_wings.append([i, signf((tip - centre).dot(right))])
	# fit: shoulders at the procedural dragon's shoulder height, facing -Z
	var shoulder: Vector3 = ((_g[_fore.values()[0]] as Transform3D).origin + (_g[_fore.values()[-1]] as Transform3D).origin) * 0.5
	var rel: Transform3D = root.global_transform.affine_inverse() * skel.global_transform
	var k: float = 1.6 / maxf((shoulder.y - ground) * rel.basis.get_scale().y, 0.001)
	root.scale = Vector3.ONE * k
	var fw_root: Vector3 = (rel.basis * _fwd).normalized()
	root.rotation.y = atan2(fw_root.x, fw_root.z) + PI
	if (Basis(Vector3.UP, root.rotation.y) * fw_root).z > -0.9:
		root.rotation.y = -atan2(fw_root.x, fw_root.z) + PI
	var sh_body: Vector3 = root.transform * (rel * shoulder)
	root.position += Vector3(0, 1.6, 0.4) - sh_body
	_to_skel = (root.transform.basis * rel.basis).orthonormalized().inverse()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ok = true

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
	for side: String in _fore:
		var sx := 1.0 if side == "r" else -1.0
		if sx == float(c.claw_side) and float(c.claw) > 0.01:
			var cl: float = c.claw
			_turn(_fore[side], Basis(Vector3.UP, -sx * float(c.claw_x) * 0.9 * cl) * Basis(Vector3.RIGHT, 1.25 * cl * (1.0 - 0.5 * float(c.claw_x))))
	for k in _tail.size():
		var u := float(k) / maxf(_tail.size() - 1, 1)
		_turn(_tail[k], Basis(Vector3.UP, sin(float(c.clock) * 1.4 + u * 3.0) * 0.16))
	for w in _wings:
		_turn(w[0], Basis(Vector3.FORWARD, float(w[1]) * (float(c.spread) * 0.55 + float(c.flap))))
