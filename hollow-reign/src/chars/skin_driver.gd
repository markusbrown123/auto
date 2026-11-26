class_name SkinDriver
extends RefCounted
## Drives a rigged character model (Mixamo-style skeleton) from FighterRig's
## procedural control points, so generated models inherit every attack arc,
## dodge and stagger without any authored animation clips.
## All maths is done in the skeleton's own space; limbs are solved with
## two-bone IK using the model's real bone lengths, so hands and feet land
## exactly on their targets.

const HEIGHT := 1.95          # metres, to match the procedural rig's proportions
const ELBOW_MIN := 0.7        # radians: an elbow is never folded tighter than this
const KNEE := 0.075           # metres from a knee joint to the outside of the knee
const SOLE := 0.012           # metres kept between the measured sole and the floor (the measured points are a sample)

var root: Node3D              # the instanced model
var skel: Skeleton3D
var bone := {}                # short name -> index
var rest := {}                # short name -> global rest Transform3D
var ok := false

static func attach(parent: Node3D, path: String) -> SkinDriver:
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null
	var d := SkinDriver.new()
	d.root = scene.instantiate()
	parent.add_child(d.root)
	d.skel = d._find_skeleton(d.root)
	if d.skel == null:
		d.root.queue_free()
		return null
	for i in d.skel.get_bone_count():
		var n := d.skel.get_bone_name(i)
		var short := n.get_slice(":", n.get_slice_count(":") - 1).trim_prefix("mixamorig_").trim_prefix("mixamorig")
		d.bone[short] = i
		d.rest[short] = d.skel.get_bone_global_rest(i)
	for need in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand",
			"LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]:
		if not d.bone.has(need):
			push_warning("skin %s lacks bone %s" % [path, need])
			d.root.queue_free()
			return null
	d._fit()
	d._measure(path)
	d.ok = true
	return d

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null

## Scale to the rig's height and turn the model to face -Z.
func _fit() -> void:
	var top: float = rest["Head"].origin.y + (rest["Head"].origin.y - rest["Neck"].origin.y) * 2.2
	var skel_scale: float = (root.global_transform.affine_inverse() * skel.global_transform).basis.get_scale().y
	root.scale = Vector3.ONE * (HEIGHT / maxf(top * skel_scale, 0.01))
	var toe: Vector3 = rest["LeftToeBase"].origin - rest["LeftFoot"].origin if bone.has("LeftToeBase") else Vector3(0, 0, 1)
	var fwd := (root.global_transform.basis.inverse() * skel.global_transform.basis * Vector3(toe.x, 0, toe.z)).normalized()
	root.rotation.y = atan2(-fwd.x, -fwd.z) * -1.0 + (0.0)
	# verify and correct: the model's forward must end up on -Z
	var check := Basis(Vector3.UP, root.rotation.y) * fwd
	if check.z > -0.9:
		root.rotation.y = -root.rotation.y
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# generated PBR: clamp metal and gloss, own materials per fighter (tint, flash and rim are per instance)
	Look.sanitise(root, "character", true)

func tint(c: Color, amount: float = 0.45) -> void:
	var m: float = maxf(maxf(c.r, c.g), maxf(c.b, 0.01))
	var t := Color.WHITE.lerp(Color(c.r / m, c.g / m, c.b / m), amount)
	Look.set_param(root, &"tint", t)

func flash(v: float) -> void:
	if is_equal_approx(v, _flash_v):
		return
	_flash_v = v
	Look.set_param(root, &"flash", Color(1, 0.9, 0.8) * (v * 0.22))

## A faint fresnel edge in the arena's light so the figure reads against a dark background.
func rim(c: Color, strength: float = 1.0) -> void:
	Look.set_param(root, &"rim_color", Color(c.r * strength, c.g * strength, c.b * strength))

var _flash_v := 0.0

func _pose_bone(name: String, basis: Basis, origin: Vector3) -> void:
	skel.set_bone_global_pose(bone[name], Transform3D(basis.orthonormalized(), origin))

func _fk_origin(name: String) -> Vector3:
	var i: int = bone[name]
	return (skel.get_bone_global_pose(skel.get_bone_parent(i)) * skel.get_bone_rest(i)).origin

func _aim(name: String, child: String, origin: Vector3, dir: Vector3) -> void:
	var r: Transform3D = rest[name]
	var rest_dir: Vector3 = (rest[child].origin - r.origin).normalized()
	_pose_bone(name, Basis(Quaternion(rest_dir, dir.normalized())) * r.basis, origin)

func _ik(a: Vector3, b: Vector3, la: float, lb: float, pole: Vector3) -> Vector3:
	var d := b - a
	var dist := clampf(d.length(), 0.001, la + lb - 0.0005)
	var n := d.normalized()
	var x := (la * la - lb * lb + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(la * la - x * x, 0.0))
	var perp := (pole - n * pole.dot(n)).normalized()
	return a + n * x + perp * h

func _limb(up: String, mid: String, end: String, target: Vector3, pole: Vector3, max_stretch: float = 1.0, min_bend: float = 0.0) -> Vector3:
	var a := _fk_origin(up)
	var la: float = (rest[mid].origin - rest[up].origin).length()
	var lb: float = (rest[end].origin - rest[mid].origin).length()
	var reach := (target - a).limit_length((la + lb) * max_stretch - 0.001)
	if min_bend > 0.0:
		# a joint is never folded tighter than this angle: the target is eased away from the limb's root
		var least := sqrt(la * la + lb * lb - 2.0 * la * lb * cos(min_bend))
		if reach.length() < least:
			reach = (reach.normalized() if reach.length() > 0.001 else pole.normalized()) * least
	var t := a + reach
	var m := _ik(a, t, la, lb, pole)
	_aim(up, mid, a, m - a)
	_aim(mid, end, m, t - m)
	return t

## `j` holds control points in the parent (rig body) space:
## pelvis, pelvis_rot, chest_rot, head_rot (Basis), hand_r, hand_l, ankle_r, ankle_l (Vector3).
## Optional: follow_r / follow_l (0..1: how far each hand target rides with its shoulder when an authored clip moves the torso),
## settle (bool: a body that has fallen is lowered onto the floor as well as lifted out of it).
## Returns the hands' final positions in that same space: {r, l}.
func drive(j: Dictionary) -> Dictionary:
	var to_skel: Transform3D = (root.transform * (root.global_transform.affine_inverse() * skel.global_transform)).affine_inverse()
	var q := to_skel.basis.orthonormalized()
	var qi := q.inverse()
	var conv := func(b: Basis) -> Basis: return q * b * qi
	var hips_rot: Basis = conv.call(j.pelvis_rot)
	var chest_rot: Basis = conv.call(j.chest_rot)
	_pose_bone("Hips", hips_rot * rest["Hips"].basis, to_skel * j.pelvis)
	var hq := hips_rot.get_rotation_quaternion()
	var cq := chest_rot.get_rotation_quaternion()
	var k := 0.0
	for s in ["Spine", "Spine1", "Spine2"]:
		k += 1.0 / 3.0
		_pose_bone(s, Basis(hq.slerp(cq, k)) * rest[s].basis, _fk_origin(s))
	var head_rot: Basis = chest_rot * conv.call(j.head_rot)
	_pose_bone("Neck", Basis(cq.slerp(head_rot.get_rotation_quaternion(), 0.5)) * rest["Neck"].basis, _fk_origin("Neck"))
	_pose_bone("Head", head_rot * rest["Head"].basis, _fk_origin("Head"))
	var sh_r0 := _fk_origin("RightArm")
	var sh_l0 := _fk_origin("LeftArm")
	# legs: knees forward, feet flat
	for side in [["Right", "r", 0.15], ["Left", "l", -0.15]]:
		var ankle := _limb(side[0] + "UpLeg", side[0] + "Leg", side[0] + "Foot", to_skel * j["ankle_" + side[1]], q * Vector3(side[2], 0.1, -1))
		_pose_bone(side[0] + "Foot", rest[side[0] + "Foot"].basis, ankle)
	var ank0 := {"Right": (to_skel * j.ankle_r).y, "Left": (to_skel * j.ankle_l).y}
	_clip_ankle.clear()
	_overlay(false)
	var back := to_skel.affine_inverse()
	var whole := clip_full and clip_w > 0.0
	if clip_w > 0.0 and clip_w < 0.98:
		# A clip mixed in by turning each bone part of the way does not put the feet part of the way: a foot the clip
		# plants and the procedural pose plants ends up in the air or under the floor. Put each ankle at the height
		# that lies between the two poses' own heights, and solve the leg again to it.
		for side: String in _clip_ankle:
			var fi: int = bone[side + "Foot"]
			var f := skel.get_bone_global_pose(fi)
			var want_y := lerpf(float(ank0[side]), float(_clip_ankle[side]), clip_w)
			if absf(want_y - f.origin.y) > 0.0005:
				var hip: Vector3 = skel.get_bone_global_pose(bone[side + "UpLeg"]).origin
				var knee: Vector3 = skel.get_bone_global_pose(bone[side + "Leg"]).origin
				var pole := knee - hip.lerp(f.origin, 0.5)
				if pole.length() < 0.02 * (knee - hip).length():
					pole = q * Vector3(0.15 if side == "Right" else -0.15, 0.1, -1)
				var o := _limb(side + "UpLeg", side + "Leg", side + "Foot", Vector3(f.origin.x, want_y, f.origin.z), pole)
				skel.set_bone_global_pose(fi, Transform3D(f.basis, o))
	_plant(back, q, whole)
	if clip_w > 0.0 and not whole:
		# eyes on the opponent: a body clip turns the trunk, the head keeps the procedural aim as far as the neck allows
		var chest_now: Basis = skel.get_bone_global_pose(bone["Spine2"]).basis.orthonormalized() * (rest["Spine2"] as Transform3D).basis.orthonormalized().inverse()
		var rel := (chest_now.inverse() * head_rot).get_rotation_quaternion()
		var ang := rel.get_angle()
		if ang > PI:
			ang = TAU - ang
		var look: Basis = head_rot if ang <= NECK_TURN else chest_now * Basis(Quaternion.IDENTITY.slerp(rel, NECK_TURN / ang))
		_pose_bone("Neck", Basis(chest_now.get_rotation_quaternion().slerp(look.get_rotation_quaternion(), 0.5)) * rest["Neck"].basis, _fk_origin("Neck"))
		_pose_bone("Head", look * rest["Head"].basis, _fk_origin("Head"))
	# arms: elbows fall outward and down. When an authored clip has carried the torso away from where the procedural
	# pose had it, the hand targets ride with the shoulders, so an arm is neither folded into the chest nor pulled straight.
	var tr: Vector3 = to_skel * j.hand_r + (_fk_origin("RightArm") - sh_r0) * float(j.get("follow_r", 1.0))
	var tl: Vector3 = to_skel * j.hand_l + (_fk_origin("LeftArm") - sh_l0) * float(j.get("follow_l", 1.0))
	# a hand (or a claw) does not go into the floor
	for side: String in ["Right", "Left"]:
		var hb: Vector3 = back * (tr if side == "Right" else tl)
		var least: float = float(ball(side + "Hand", back)[1]) * 0.9
		if hb.y < least:
			hb.y = least
			if side == "Right":
				tr = to_skel * hb
			else:
				tl = to_skel * hb
	var hr := _limb("RightArm", "RightForeArm", "RightHand", tr, q * Vector3(0.7, -0.8, 0.35), 0.985, ELBOW_MIN)
	var hl := _limb("LeftArm", "LeftForeArm", "LeftHand", tl, q * Vector3(-0.7, -0.8, 0.35), 0.985, ELBOW_MIN)
	if whole:
		# whole-body clips (falling, dying) carry the arms too; the weapons follow the real hands
		_overlay(true)
	_ground(back, q, whole, bool(j.get("settle", false)))
	hr = skel.get_bone_global_pose(bone["RightHand"]).origin
	hl = skel.get_bone_global_pose(bone["LeftHand"]).origin
	_back = back
	return {"r": back * _palm("Right", hr), "l": back * _palm("Left", hl)}

var _back := Transform3D.IDENTITY      # skeleton space -> rig body space, as of the last drive()
var _clip_ankle := {}                  # "Left"/"Right" -> the ankle's height in the clip's own pose (skeleton space)

## Where a bone is, in rig body space (after drive()).
func point(name: String) -> Vector3:
	return _back * skel.get_bone_global_pose(bone[name]).origin

## Move one hand's palm to `target` (rig body space) after the pose is solved: an off hand onto a two-handed grip.
func reach_hand(side: String, target: Vector3) -> Vector3:
	var to_skel := _back.affine_inverse()
	var wrist: Vector3 = skel.get_bone_global_pose(bone[side + "Hand"]).origin
	var off := _palm(side, wrist) - wrist
	var pole := to_skel.basis.orthonormalized() * Vector3(0.7 if side == "Right" else -0.7, -0.8, 0.35)
	var w := _limb(side + "Arm", side + "ForeArm", side + "Hand", to_skel * target - off, pole, 0.985, ELBOW_MIN)
	return _back * _palm(side, w)

# ---------------------------------------------------------------- hands
var _grip_axis := {}      # side -> [across the palm toward the index finger, along the knuckles, out of the palm] at rest

func _grip_rest(side: String) -> Array:
	if _grip_axis.has(side):
		return _grip_axis[side]
	var out: Array = []
	if bone.has(side + "HandIndex1") and bone.has(side + "HandPinky1") and bone.has(side + "HandMiddle1"):
		var t0: Vector3 = (rest[side + "HandIndex1"].origin - rest[side + "HandPinky1"].origin).normalized()
		var f0: Vector3 = rest[side + "HandMiddle1"].origin - rest[side + "Hand"].origin
		var hand_len := f0.length()
		f0 = (f0 - t0 * f0.dot(t0)).normalized()
		var n0 := t0.cross(f0)
		if n0.y > 0.0:
			n0 = -n0          # the palm faces the floor in a T- or A-pose
		out = [t0, f0, n0, hand_len]
	_grip_axis[side] = out
	return out

## Close the hand's frame round a handle that runs along `dir` (rig body space): the handle lies across the palm and
## leaves it on the thumb side, the knuckles stay as nearly in line with the forearm as that allows.
## Returns where the handle's grip point is (rig body space).
func grip(side: String, dir: Vector3) -> Vector3:
	var hi: int = bone[side + "Hand"]
	var h := skel.get_bone_global_pose(hi)
	var ax := _grip_rest(side)
	if ax.is_empty():
		return _back * _palm(side, h.origin)
	var rb: Basis = (rest[side + "Hand"] as Transform3D).basis.orthonormalized()
	var t1 := (_back.basis.inverse() * dir).normalized()
	var fore: Vector3 = (h.origin - skel.get_bone_global_pose(bone[side + "ForeArm"]).origin).normalized()
	var f1 := fore - t1 * fore.dot(t1)
	if f1.length() < 0.3:
		# the blade runs nearly along the forearm (a thrust): lean on the hand's present knuckle line as well
		var cur_f: Vector3 = h.basis.orthonormalized() * (rb.inverse() * (ax[1] as Vector3))
		f1 += (cur_f - t1 * cur_f.dot(t1)) * (0.3 - f1.length())
	if f1.length() < 0.001:
		return _back * _palm(side, h.origin)
	f1 = f1.normalized()
	var t0: Vector3 = ax[0]
	var f0: Vector3 = ax[1]
	var rot := Basis(t1, f1, t1.cross(f1)) * Basis(t0, f0, t0.cross(f0)).inverse()
	skel.set_bone_global_pose(hi, Transform3D(rot * rb, h.origin))
	return _back * (_palm(side, h.origin) + rot * (ax[2] as Vector3) * (float(ax[3]) * 0.3))

## The way a handle held in this hand points (rig body space), from the hand's present pose: for whole-body clips,
## where the hand is carried by the clip and the weapon must go with it.
func hand_axis(side: String) -> Vector3:
	var ax := _grip_rest(side)
	if ax.is_empty():
		return Vector3.ZERO
	var h := skel.get_bone_global_pose(bone[side + "Hand"])
	return (_back.basis * (h.basis.orthonormalized() * ((rest[side + "Hand"] as Transform3D).basis.orthonormalized().inverse() * (ax[0] as Vector3)))).normalized()

## How a bone has been turned from its rest pose, as a rotation in rig body space.
func turn(name: String) -> Basis:
	var r := _back.basis.orthonormalized()
	return r * (skel.get_bone_global_pose(bone[name]).basis.orthonormalized() * (rest[name] as Transform3D).basis.orthonormalized().inverse()) * r.inverse()

## How far what the named bone carries reaches from the bone along `dir` (rig body space, the model at rest), in metres.
func extent(name: String, dir: Vector3) -> float:
	var pts: PackedVector3Array = _contact.get(name, PackedVector3Array())
	var t: Transform3D = _back * Transform3D((rest[name] as Transform3D).basis, Vector3.ZERO)
	var m := 0.0
	for p in pts:
		m = maxf(m, (t.basis * p).dot(dir))
	return m

## A bone's frame in rig body space (no scale).
func frame(name: String) -> Transform3D:
	var g := skel.get_bone_global_pose(bone[name])
	return Transform3D((_back.basis.orthonormalized() * g.basis.orthonormalized()), _back * g.origin)

## A rough ball round what the named bone carries: [centre, radius] in rig body space.
var _ball := {}
func ball(name: String, back: Transform3D = _back) -> Array:
	if not _ball.has(name):
		var pts: PackedVector3Array = _contact.get(name, PackedVector3Array())
		var c := Vector3.ZERO
		for p in pts:
			c += p / maxf(pts.size(), 1)
		var mean := 0.0
		var far := 0.0
		for p in pts:
			mean += c.distance_to(p) / maxf(pts.size(), 1)
			far = maxf(far, c.distance_to(p))
		_ball[name] = [c, lerpf(mean, far, 0.5)]
	var e: Array = _ball[name]
	return [back * (skel.get_bone_global_pose(bone[name]) * (e[0] as Vector3)), float(e[1]) * back.basis.get_scale().y]

# ---------------------------------------------------------------- grounding
## The floor is y = 0 of the rig body space. Nothing the model is made of may go under it.
## For each bone that can touch the floor, a handful of the outermost points of the mesh it carries are kept in that
## bone's own space (measured once per model from the real skinned vertices), and tested after the pose is solved.
const CONTACT_BONES := ["Hips", "Spine2", "Head", "LeftShoulder", "RightShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand",
	"LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]
static var _contact_cache := {}
var _contact := {}            # short bone name -> PackedVector3Array, bone-local

func _measure(path: String) -> void:
	if _contact_cache.has(path):
		_contact = _contact_cache[path]
		return
	var group := {}
	for i in skel.get_bone_count():
		var b := i
		var nm := ""
		while b >= 0:
			var n := skel.get_bone_name(b)
			nm = n.get_slice(":", n.get_slice_count(":") - 1).trim_prefix("mixamorig_").trim_prefix("mixamorig")
			if CONTACT_BONES.has(nm):
				break
			nm = ""
			b = skel.get_bone_parent(b)
		group[i] = nm
	var dirs: Array = []
	for x: float in [-1.0, 0.0, 1.0]:
		for y: float in [-1.0, 0.0, 1.0]:
			for z: float in [-1.0, 0.0, 1.0]:
				var d := Vector3(x, y, z)
				if d.length() > 0.5 and (d.length() < 1.1 or d.length() > 1.6 or y < 0.0):
					dirs.append(d.normalized())
	var best := {}
	for nm2: String in CONTACT_BONES:
		var a: Array = []
		for d2 in dirs:
			a.append([-1e9, Vector3.ZERO])
		best[nm2] = a
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.mesh == null:
			continue
		var binds: Array = []
		for b2 in mi.skin.get_bind_count():
			var bi := mi.skin.get_bind_bone(b2)
			if bi < 0:
				bi = skel.find_bone(mi.skin.get_bind_name(b2))
			binds.append([bi, (skel.get_bone_global_rest(bi) * mi.skin.get_bind_pose(b2)) if bi >= 0 else Transform3D.IDENTITY])
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null or pos.is_empty():
				continue
			var nb: int = bones.size() / pos.size()
			var step: int = maxi(1, pos.size() / 16000)
			for i in range(0, pos.size(), step):
				var top := 0
				for k in range(1, nb):
					if weights[i * nb + k] > weights[i * nb + top]:
						top = k
				var bind: Array = binds[bones[i * nb + top]]
				var nm3: String = group.get(int(bind[0]), "")
				if nm3 == "":
					continue
				var p: Vector3 = (bind[1] as Transform3D) * pos[i]      # skeleton space, rest pose
				var slots: Array = best[nm3]
				for di in dirs.size():
					var sc: float = p.dot(dirs[di])
					if sc > float(slots[di][0]):
						slots[di] = [sc, p]
	var out := {}
	for nm4: String in CONTACT_BONES:
		var inv: Transform3D = (rest[nm4] as Transform3D).affine_inverse() if rest.has(nm4) else Transform3D.IDENTITY
		var pts := PackedVector3Array()
		for e: Array in best[nm4]:
			if float(e[0]) > -1e8:
				var lp: Vector3 = inv * (e[1] as Vector3)
				if not pts.has(lp):
					pts.append(lp)
		out[nm4] = pts
	_contact_cache[path] = out
	_contact = out

## Lowest point, in rig body space, of what the named bone carries in its present pose.
func _low(name: String, back: Transform3D) -> float:
	var pts: PackedVector3Array = _contact.get(name, PackedVector3Array())
	if pts.is_empty():
		return 1e9
	var t: Transform3D = back * skel.get_bone_global_pose(bone[name])
	var row := Vector3(t.basis.x.y, t.basis.y.y, t.basis.z.y)
	var m := 1e9
	for p in pts:
		m = minf(m, row.dot(p))
	return m + t.origin.y

func _low_with(pts: PackedVector3Array, basis: Basis) -> float:
	var row := Vector3(basis.x.y, basis.y.y, basis.z.y)
	var m := 1e9
	for p in pts:
		m = minf(m, row.dot(p))
	return m

## Feet: a foot near the floor lies flat on it, and no part of its sole goes under.
## The leg is solved again to the lifted ankle, keeping the knee on the side it was on.
func _plant(back: Transform3D, q: Basis, whole: bool) -> void:
	var up := (q * Vector3.UP).normalized()
	var s: float = back.basis.get_scale().y
	for side: String in ["Left", "Right"]:
		var pts: PackedVector3Array = _contact.get(side + "Foot", PackedVector3Array())
		if pts.is_empty():
			continue
		var fi: int = bone[side + "Foot"]
		var f := skel.get_bone_global_pose(fi)
		var cur := f.basis.orthonormalized()
		var rb: Basis = (rest[side + "Foot"] as Transform3D).basis.orthonormalized()
		# the turn about the vertical that the foot has taken, without its pitch and roll
		var dq := (cur * rb.inverse()).get_rotation_quaternion()
		var along := up * Vector3(dq.x, dq.y, dq.z).dot(up)
		var tw := Quaternion(along.x, along.y, along.z, dq.w)
		tw = tw.normalized() if tw.length_squared() > 0.0001 else Quaternion.IDENTITY
		var flat := Basis(tw) * rb
		var ank_y: float = (back * f.origin).y
		var h_flat := SOLE - _low_with(pts, back.basis * flat)
		var wf := 0.0 if whole else 1.0 - smoothstep(0.02, 0.12, ank_y - h_flat)
		var nb := Basis(cur.get_rotation_quaternion().slerp(flat.get_rotation_quaternion(), wf)) if wf > 0.0 else cur
		var low := ank_y + _low_with(pts, back.basis * nb) - SOLE
		var origin := f.origin
		if low < 0.0 and not whole:
			var hip: Vector3 = skel.get_bone_global_pose(bone[side + "UpLeg"]).origin
			var knee: Vector3 = skel.get_bone_global_pose(bone[side + "Leg"]).origin
			var pole := knee - hip.lerp(f.origin, 0.5)
			if pole.length() < 0.02 * (knee - hip).length():
				pole = q * Vector3(0.15 if side == "Right" else -0.15, 0.1, -1)
			origin = _limb(side + "UpLeg", side + "Leg", side + "Foot", f.origin + up * (-low / s), pole)
		if wf > 0.0 or origin != f.origin:
			skel.set_bone_global_pose(fi, Transform3D(nb, origin))

## Whole body: lift the hips until nothing is under the floor. Standing figures are tested at the feet and shins
## (a knee in a deep lunge); figures in a whole-body clip (falls, rolls, deaths) at every part.
func _ground(back: Transform3D, q: Basis, whole: bool, settle: bool) -> void:
	var low := 1e9
	if whole:
		for nm: String in _contact:
			low = minf(low, _low(nm, back))
	else:
		# the feet are already planted; what is left is a knee driven into the floor by a deep lunge
		for side: String in ["Left", "Right"]:
			low = minf(low, (back * skel.get_bone_global_pose(bone[side + "Leg"]).origin).y - KNEE)
		# and whatever hangs from the hips and thighs (a long skirt, a fauld), by a small amount at most
		var hang := 0.0
		for nm2: String in ["Hips", "LeftUpLeg", "RightUpLeg"]:
			hang = minf(hang, _low(nm2, back))
		low = minf(low, maxf(hang, -0.03))
	if low > 1e8:
		return
	low -= SOLE
	if low < 0.0 or (settle and whole and low > 0.0):
		var hi: int = bone["Hips"]
		var cur := skel.get_bone_global_pose(hi)
		var lift := -low * (clip_w if low > 0.0 else 1.0)
		skel.set_bone_global_pose(hi, Transform3D(cur.basis, cur.origin + (q * Vector3.UP).normalized() * (lift / back.basis.get_scale().y)))

# ---------------------------------------------------------------- authored clips
## Authored skeletal motion (assets/anim/humanoid.res) layered over the procedural pose.
## The rig sets these each frame; weight 0 leaves the procedural pose untouched.
var clip := ""
var clip_t := 0.0
var clip_w := 0.0
var clip_full := false        # false: body and legs only, sword and shield arms stay on IK
var clip_travel := 1.0        # how much of a whole-body clip's own travel to apply
static var _lib: AnimationLibrary
static var _tracks: Dictionary = {}      # clip -> {bone: track index}, plus "_pos" for the hips
## Parent-first order; the clips store each bone's model-space turn away from rest, facing -Z.
const CLIP_BONES := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
	"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand",
	"LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]
const TRUNK := ["Hips", "Spine", "Spine1", "Spine2"]
const TRUNK_YAW := 0.6        # radians a body clip may turn the trunk away from the procedural pose while the arms are on IK
const NECK_TURN := 1.05       # radians the head may be turned from the chest
const LIMB_CHILD := {"LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand",
	"LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "RightUpLeg": "RightLeg", "RightLeg": "RightFoot"}
var _canon := Basis.IDENTITY      # this skeleton's space -> canonical (facing -Z)
var _canon_ready := false
var _my_dir := {}                 # limb rest directions of this skeleton, canonical

static func has_clip(n: String) -> bool:
	if _lib == null and ResourceLoader.exists("res://assets/anim/humanoid.res"):
		_lib = load("res://assets/anim/humanoid.res")
	return _lib != null and _lib.has_animation(n)

static func clip_length(n: String) -> float:
	return _lib.get_animation(n).length if has_clip(n) else 0.0

func _is_arm(b: String) -> bool:
	return b.contains("Hand") or b.contains("Arm") or b.contains("Shoulder")

func _prepare_canon() -> void:
	_canon_ready = true
	var toe: Vector3 = (rest["LeftToeBase"].origin - rest["LeftFoot"].origin) if bone.has("LeftToeBase") else Vector3(0, 0, 1)
	var ang := -atan2(toe.x, toe.z) + PI
	_canon = Basis(Vector3.UP, ang)
	if (_canon * Vector3(toe.x, 0, toe.z).normalized()).z > -0.9:
		_canon = Basis(Vector3.UP, -ang)
	for b: String in LIMB_CHILD:
		if bone.has(b) and bone.has(LIMB_CHILD[b]):
			_my_dir[b] = (_canon * (rest[LIMB_CHILD[b]].origin - rest[b].origin)).normalized()

func _overlay(arms: bool) -> void:
	if clip_w <= 0.0 or not has_clip(clip):
		return
	if not _canon_ready:
		_prepare_canon()
	var a: Animation = _lib.get_animation(clip)
	if not _tracks.has(clip):
		var m := {}
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
				m["_pos"] = t
			else:
				m[str(a.track_get_path(t)).get_slice(":", 1)] = t
		_tracks[clip] = m
	var map: Dictionary = _tracks[clip]
	var src_dir: Dictionary = a.get_meta("rest_dir", {})
	var t := fposmod(clip_t, a.length) if a.loop_mode != Animation.LOOP_NONE else clampf(clip_t, 0.0, a.length)
	var back := _canon.inverse()
	var full_b := {}      # the clip's own turn of the hips and legs, at full weight
	var pre := {}         # the trunk as the procedural pose had it, before any bone of it is turned by the clip
	if not arms and not clip_full:
		for tb: String in TRUNK:
			pre[tb] = skel.get_bone_global_pose(bone[tb]).basis.orthonormalized()
	if not arms and map.has("_pos"):
		# hip height as a fraction of standing height; travel only for whole-body clips
		var hp: Vector3 = a.position_track_interpolate(map["_pos"], t)
		var h: float = rest["Hips"].origin.y
		var cur: Transform3D = skel.get_bone_global_pose(bone["Hips"])
		var want := Vector3(cur.origin.x, hp.y * h, cur.origin.z)
		if clip_full:
			want += back * Vector3(hp.x, 0, hp.z) * h * clip_travel
		skel.set_bone_global_pose(bone["Hips"], Transform3D(cur.basis, cur.origin.lerp(want, clip_w)))
	for b: String in CLIP_BONES:
		if not map.has(b) or not bone.has(b) or _is_arm(b) != arms:
			continue
		var d := Basis(a.rotation_track_interpolate(map[b], t))
		if _my_dir.has(b) and src_dir.has(b):
			# line this skeleton's limb up with the source's rest limb first (A-pose against T-pose)
			d = d * Basis(Quaternion(_my_dir[b], src_dir[b]))
		var target: Basis = back * d * _canon * rest[b].basis.orthonormalized()
		if not arms and (b == "Hips" or b.ends_with("UpLeg") or b.ends_with("Leg")):
			full_b[b] = target * (rest[b] as Transform3D).basis.orthonormalized().inverse()
		var i: int = bone[b]
		var cur_b: Basis = skel.get_bone_global_pose(i).basis.orthonormalized()
		var origin: Vector3 = skel.get_bone_global_pose(i).origin if b == "Hips" else _fk_origin(b)
		if pre.has(b):
			cur_b = pre[b]      # (a bone already carried round by its parent would otherwise be turned twice over)
		var mixed := Basis(cur_b.get_rotation_quaternion().slerp(target.get_rotation_quaternion(), clip_w))
		if pre.has(b):
			# The arms stay on IK toward targets set for a body that faces its opponent. A clip may coil the trunk for a
			# cut, but only so far: past this the sword arm would have to reach behind the back and through the shield.
			var dq := (mixed * cur_b.inverse()).get_rotation_quaternion()
			var yaw := 2.0 * atan2(dq.y, dq.w)
			yaw = wrapf(yaw, -PI, PI)
			if absf(yaw) > TRUNK_YAW:
				mixed = Basis(Vector3.UP, -(yaw - signf(yaw) * TRUNK_YAW)) * mixed
		skel.set_bone_global_pose(i, Transform3D(mixed, origin))
	if not arms and map.has("_pos") and full_b.has("Hips"):
		var hip_y: float = a.position_track_interpolate(map["_pos"], t).y * rest["Hips"].origin.y
		for side: String in ["Left", "Right"]:
			if full_b.has(side + "UpLeg") and full_b.has(side + "Leg"):
				_clip_ankle[side] = hip_y + ((full_b["Hips"] as Basis) * (rest[side + "UpLeg"].origin - rest["Hips"].origin)).y \
					+ ((full_b[side + "UpLeg"] as Basis) * (rest[side + "Leg"].origin - rest[side + "UpLeg"].origin)).y \
					+ ((full_b[side + "Leg"] as Basis) * (rest[side + "Foot"].origin - rest[side + "Leg"].origin)).y

## The grip sits in the palm, not at the wrist.
func _palm(side: String, wrist: Vector3) -> Vector3:
	var mid := side + "HandMiddle1"
	if not bone.has(mid):
		return wrist
	return wrist.lerp(skel.get_bone_global_pose(bone[mid]).origin, 0.75)
