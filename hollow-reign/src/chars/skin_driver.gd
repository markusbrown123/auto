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
var pole_l := Vector3(-0.7, -0.8, 0.35)      # where the left elbow falls (rig body space): outward and down; a strapped shield wants it further out
var parts: ArmorParts         # the armour worn over this body (FighterRig dresses it); tint, flash and rim reach it too

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
	if parts:
		parts.set_param(&"tint", t)

func flash(v: float) -> void:
	if is_equal_approx(v, _flash_v):
		return
	_flash_v = v
	Look.set_param(root, &"flash", Color(1, 0.9, 0.8) * (v * 0.22))
	if parts:
		parts.set_param(&"flash", Color(1, 0.9, 0.8) * (v * 0.22))

## A faint fresnel edge in the arena's light so the figure reads against a dark background.
func rim(c: Color, strength: float = 1.0) -> void:
	Look.set_param(root, &"rim_color", Color(c.r * strength, c.g * strength, c.b * strength))
	if parts:
		parts.set_param(&"rim_color", Color(c.r * strength, c.g * strength, c.b * strength))

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
	_back = back
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
	if clip_w > 0.0 and (not whole or clip_look):
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
	var hl := _limb("LeftArm", "LeftForeArm", "LeftHand", tl, q * pole_l, 0.985, ELBOW_MIN)
	if whole:
		# whole-body clips (falling, dying) carry the arms too; the weapons follow the real hands
		_overlay(true)
		if clip_roll != 0.0 and roll_chest:
			# a two-handed grip: the whole chest is turned about the line to the opponent, carrying both arms together, so
			# the second hand stays on the handle (turned at the sword shoulder alone it was taken 30-50 cm off it)
			var fwd_c := (q * Vector3(0, 0, 1)).normalized()
			var gc := skel.get_bone_global_pose(bone["Spine2"])
			skel.set_bone_global_pose(bone["Spine2"], Transform3D(Basis(fwd_c, clip_roll * clip_w) * gc.basis, gc.origin))
		elif clip_roll != 0.0 and arm_r > 0.0:
			# the sword arm turned about the line to the opponent, so the cut travels the way that was swiped
			var fwd_axis := (q * Vector3(0, 0, 1)).normalized()
			for part: Array in [["RightShoulder", ROLL_CLAVICLE], ["RightArm", 1.0 - ROLL_CLAVICLE]]:
				if bone.has(part[0]):
					var g := skel.get_bone_global_pose(bone[part[0]])
					skel.set_bone_global_pose(bone[part[0]], Transform3D(Basis(fwd_axis, clip_roll * arm_r * clip_w * float(part[1])) * g.basis, g.origin))
		clip_axis = {"Right": hand_axis("Right"), "Left": hand_axis("Left")}
	# (an authored cut or guard is a standing figure: grounded by its feet, like the procedural pose, not by every
	# part of it as a fall is, or a long skirt rigid to the hips would lift the whole fighter off the floor)
	var fallen := whole and not clip_look
	_ground(back, q, fallen, bool(j.get("settle", false)), whole and clip_look)
	if _xf_left > 0.0:
		# (an arm pinned to a contact point is not eased: it is solved again to its target on the eased trunk)
		var pin_r := float(j.get("follow_r", 1.0)) <= 0.0
		var pin_l := float(j.get("follow_l", 1.0)) <= 0.0
		_xf_apply(float(j.get("dt", 0.0)), pin_r, pin_l)
		if pin_r:
			_limb("RightArm", "RightForeArm", "RightHand", tr, q * Vector3(0.7, -0.8, 0.35), 0.985, ELBOW_MIN)
		if pin_l:
			_limb("LeftArm", "LeftForeArm", "LeftHand", tl, q * pole_l, 0.985, ELBOW_MIN)
		_ground(back, q, whole and not clip_look, true, true, whole and clip_look)
	if foot_fix.is_valid():
		foot_fix.call()      # the rig places the feet: planted in the world, on the ground under them
	hr = skel.get_bone_global_pose(bone["RightHand"]).origin
	hl = skel.get_bone_global_pose(bone["LeftHand"]).origin
	return {"r": back * _palm("Right", hr), "l": back * _palm("Left", hl)}

var _back := Transform3D.IDENTITY      # skeleton space -> rig body space, as of the last drive()

# ---------------------------------------------------------------- change of pose without a pop
## A change from one source of pose to another (guard to an authored cut, one cut to the next, a cut back to guard)
## is eased from the pose the skeleton had on the frame before: call crossfade() before the next drive().
var _xf_left := 0.0
var _xf_dur := 0.0
var _xf_rot := {}             # bone name -> local rotation when the change began
var _xf_hips := Vector3.ZERO

func crossfade(dur: float) -> void:
	_xf_rot.clear()
	for b: String in CLIP_BONES:
		if bone.has(b):
			_xf_rot[b] = skel.get_bone_pose_rotation(bone[b])
	_xf_hips = skel.get_bone_pose_position(bone["Hips"])
	_xf_dur = maxf(dur, 0.001)
	_xf_left = _xf_dur

## How far the change of pose has come: 0 at its first frame, 1 when the new pose stands alone.
func xf_u() -> float:
	return 1.0 if _xf_left <= 0.0 else smoothstep(0.0, 1.0, 1.0 - _xf_left / _xf_dur)

func _xf_apply(dt: float, skip_r: bool = false, skip_l: bool = false) -> void:
	_xf_left = maxf(0.0, _xf_left - dt)
	var u := xf_u()
	if u >= 1.0:
		return
	for b: String in _xf_rot:
		if _is_arm(b) and ((skip_r and b.begins_with("Right")) or (skip_l and b.begins_with("Left"))):
			continue
		var i: int = bone[b]
		skel.set_bone_pose_rotation(i, (_xf_rot[b] as Quaternion).slerp(skel.get_bone_pose_rotation(i), u))
	var hi: int = bone["Hips"]
	skel.set_bone_pose_position(hi, _xf_hips.lerp(skel.get_bone_pose_position(hi), u))

# ---------------------------------------------------------------- a clip's sword hand without posing the skeleton
var _chain := {}              # side -> bone names from the hips out to the hand

## Where a whole-body clip puts a hand at time `t` on this skeleton, by forward kinematics over the arm's chain:
## {p: grip point, axis: the way a handle held in it points, chest: the way the chest faces, hips: the way the hips face},
## all in rig body space. `roll` as `clip_roll`. Used to choose and aim cuts and to know how far a cut reaches.
func clip_hand(cn: String, t: float, side: String = "Right", roll: float = 0.0, travel: float = 1.0) -> Dictionary:
	if not has_clip(cn):
		return {}
	if not _canon_ready:
		_prepare_canon()
	var a: Animation = _lib.get_animation(cn)
	var map := _track_map(cn)
	var src_dir: Dictionary = a.get_meta("rest_dir", {})
	t = fposmod(t, a.length) if a.loop_mode != Animation.LOOP_NONE else clampf(t, 0.0, a.length)
	if not _chain.has(side):
		var names: Array = []
		var i: int = bone[side + "Hand"]
		while i >= 0:
			var n := skel.get_bone_name(i)
			names.push_front(n.get_slice(":", n.get_slice_count(":") - 1).trim_prefix("mixamorig_").trim_prefix("mixamorig"))
			if names[0] == "Hips":
				break
			i = skel.get_bone_parent(i)
		_chain[side] = names
	var cb := _canon.inverse()
	var to_skel := _back.affine_inverse()
	var fwd_axis := (to_skel.basis.orthonormalized() * Vector3(0, 0, 1)).normalized()
	var h: float = rest["Hips"].origin.y
	var o := to_skel * Vector3.ZERO
	var d_par := Basis.IDENTITY
	var extra := Basis.IDENTITY
	var prev := ""
	var out := {}
	for b: String in _chain[side]:
		if prev == "":
			if map.has("_pos"):
				var hp: Vector3 = a.position_track_interpolate(map["_pos"], t)
				o = Vector3(o.x, hp.y * h, o.z) + cb * Vector3(hp.x, 0, hp.z) * h * travel
			else:
				o.y = h
		else:
			o += d_par * (rest[b].origin - rest[prev].origin)
		if roll != 0.0 and roll_chest and b == "Spine2":
			extra = Basis(fwd_axis, roll) * extra
		elif roll != 0.0 and not roll_chest and side == "Right" and (b == "RightShoulder" or b == "RightArm"):
			extra = Basis(fwd_axis, roll * (ROLL_CLAVICLE if b == "RightShoulder" else 1.0 - ROLL_CLAVICLE)) * extra
		if map.has(b):
			var d := Basis(a.rotation_track_interpolate(map[b], t))
			if _my_dir.has(b) and src_dir.has(b):
				d = d * Basis(Quaternion(_my_dir[b], src_dir[b]))
			d_par = extra * (cb * d * _canon)
		if b == "Hips" or b == "Spine2":
			out["hips" if b == "Hips" else "chest"] = (_back.basis.orthonormalized() * (d_par * (to_skel.basis.orthonormalized() * Vector3(0, 0, -1)))).normalized()
		prev = b
	var ax := _grip_rest(side)
	var palm := o
	var axis := Vector3.ZERO
	if not ax.is_empty():
		axis = (_back.basis.orthonormalized() * (d_par * (ax[0] as Vector3))).normalized()
		palm = o + d_par * ((rest[side + "HandMiddle1"].origin - rest[side + "Hand"].origin) * 0.75)
	out["p"] = _back * palm
	out["axis"] = axis
	return out

func _track_map(cn: String) -> Dictionary:
	if not _tracks.has(cn):
		var a: Animation = _lib.get_animation(cn)
		var m := {}
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
				m["_pos"] = t
			else:
				m[str(a.track_get_path(t)).get_slice(":", 1)] = t
		_tracks[cn] = m
	return _tracks[cn]
var _clip_ankle := {}                  # "Left"/"Right" -> the ankle's height in the clip's own pose (skeleton space)

## Where a bone is, in rig body space (after drive()).
func point(name: String) -> Vector3:
	return _back * skel.get_bone_global_pose(bone[name]).origin

## Move one hand's palm to `target` (rig body space) after the pose is solved: an off hand onto a two-handed grip.
func reach_hand(side: String, target: Vector3) -> Vector3:
	var to_skel := _back.affine_inverse()
	var wrist: Vector3 = skel.get_bone_global_pose(bone[side + "Hand"]).origin
	var off := _palm(side, wrist) - wrist
	var pole := to_skel.basis.orthonormalized() * (Vector3(0.7, -0.8, 0.35) if side == "Right" else pole_l)
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
	grip_fwd[side] = (_back.basis.orthonormalized() * f1).normalized()
	skel.set_bone_global_pose(hi, Transform3D(rot * rb, h.origin))
	return _back * (_palm(side, h.origin) + rot * (ax[2] as Vector3) * (float(ax[3]) * 0.3))

var grip_fwd := {}        # side -> the way the knuckles of a hand closed by grip() face (rig body space): a held edge leads that way

## Close a hand round a handle along `dir` with its grip point (what grip() returns) at `at` (rig body space): the hand is
## closed, then the wrist is moved by what is still missing and the arm solved to it again, a few times (closing the hand
## turns it about the wrist, which carries the grip off a target reached with the open hand). Returns the grip point.
func grip_at(side: String, at: Vector3, dir: Vector3, tries: int = 6) -> Vector3:
	var to_skel := _back.affine_inverse()
	var pole := to_skel.basis.orthonormalized() * (Vector3(0.7, -0.8, 0.35) if side == "Right" else pole_l)
	var names: Array = [side + "Arm", side + "ForeArm", side + "Hand"]
	var got := grip(side, dir)
	var best_e := (at - got).length()
	var best: Array = []
	for b: String in names:
		best.append(skel.get_bone_pose_rotation(bone[b]))
	var best_got := got
	var step := 1.0
	for i in tries:
		var err := at - got
		if err.length() < 0.006:
			break
		var wrist: Vector3 = skel.get_bone_global_pose(bone[side + "Hand"]).origin
		_limb(side + "Arm", side + "ForeArm", side + "Hand", wrist + to_skel.basis * err * step, pole, 0.985, ELBOW_MIN)
		got = grip(side, dir)
		var e := (at - got).length()
		if e < best_e:
			best_e = e
			best_got = got
			for k in names.size():
				best[k] = skel.get_bone_pose_rotation(bone[names[k]])
		else:
			step *= 0.5      # (closing the hand turns it with the forearm: where that overshoots, smaller steps)
	for k in names.size():
		skel.set_bone_pose_rotation(bone[names[k]], best[k])
	return best_got

# ---------------------------------------------------------------- fingers
## A hand closed round a handle or a shield's grip bar: every finger joint is turned toward the palm, the thumb
## across it. `amount` 0 is the model's own open hand, 1 a fist round a grip about 3 cm thick.
const FINGERS := ["Index", "Middle", "Ring", "Pinky"]
const CURL := [1.25, 1.45, 0.9]      # radians at the knuckle, the middle joint and the last joint of a closed finger
const CURL_THUMB := [0.55, 0.5, 0.7]
var _curl := {}               # side -> amount last applied
var _curl_axis := {}          # bone name -> the joint's bending axis in the bone's own rest frame

func curl(side: String, amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if is_equal_approx(float(_curl.get(side, 0.0)), amount):
		return
	var ax := _grip_rest(side)
	if ax.is_empty():
		return
	_curl[side] = amount
	var palm: Vector3 = ax[2]
	for f: String in FINGERS + ["Thumb"]:
		# what a closing joint moves its finger toward: into the palm; the thumb across the palm toward the little finger
		var toward: Vector3 = palm if f != "Thumb" else (palm * 0.6 - (ax[0] as Vector3) * 0.5 + (ax[1] as Vector3) * 0.45).normalized()
		for j in 3:
			var bn := "%sHand%s%d" % [side, f, j + 1]
			var cn := "%sHand%s%d" % [side, f, j + 2]
			if not bone.has(bn):
				continue
			if not _curl_axis.has(bn):
				var d: Vector3 = ((rest[cn] as Transform3D).origin - (rest[bn] as Transform3D).origin) if rest.has(cn) else (ax[1] as Vector3)
				var axis := d.normalized().cross(toward)
				axis = axis.normalized() if axis.length() > 0.05 else (ax[0] as Vector3)
				_curl_axis[bn] = ((rest[bn] as Transform3D).basis.orthonormalized().inverse() * axis).normalized()
			var ang: float = float((CURL_THUMB if f == "Thumb" else CURL)[j]) * amount
			var i: int = bone[bn]
			skel.set_bone_pose_rotation(i, skel.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion(_curl_axis[bn] as Vector3, ang))

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
	var best := _best_new()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		_scan(mi, best)
	_contact_cache[path] = _best_points(best)
	_contact = _contact_cache[path]

## The armour parts worn over this skeleton become what touches the floor, what a blade must clear and what an
## opponent's blade meets: the outermost points are measured on the worn part meshes instead of the hidden body.
## Each part is measured once (cached by mesh); a change of one piece only merges the cached results again.
func measure_parts(p: ArmorParts) -> void:
	parts = p
	if p == null:
		return
	var key := "parts|%s|%s" % [p.body, str(p.worn)]
	if not _contact_cache.has(key):
		var best := _best_new()
		for slot: String in p.nodes:
			var mi: MeshInstance3D = p.nodes[slot]
			if not mi.visible or mi.mesh == null:
				continue
			var id := mi.mesh.get_instance_id()
			if not _part_best.has(id):
				var one := _best_new()
				_scan(mi, one)
				_part_best[id] = one
			var got: Dictionary = _part_best[id]
			for nm: String in got:
				var into: Array = best[nm]
				var from: Array = got[nm]
				for di in into.size():
					if float(from[di][0]) > float(into[di][0]):
						into[di] = from[di]
		_contact_cache[key] = _best_points(best)
	_contact = _contact_cache[key]
	_ball.clear()

static var _part_best := {}      # part mesh instance id -> its own outermost points per bone
static var _dirs: Array = []

static func _measure_dirs() -> Array:
	if _dirs.is_empty():
		for x: float in [-1.0, 0.0, 1.0]:
			for y: float in [-1.0, 0.0, 1.0]:
				for z: float in [-1.0, 0.0, 1.0]:
					var d := Vector3(x, y, z)
					if d.length() > 0.5 and (d.length() < 1.1 or d.length() > 1.6 or y < 0.0):
						_dirs.append(d.normalized())
	return _dirs

func _best_new() -> Dictionary:
	var best := {}
	for nm2: String in CONTACT_BONES:
		var a: Array = []
		for d2 in _measure_dirs():
			a.append([-1e9, Vector3.ZERO])
		best[nm2] = a
	return best

var _group := {}              # bone index -> the contact bone that carries it

## Adds one skinned mesh's outermost points (skeleton space, rest pose) to `best`.
func _scan(mi: MeshInstance3D, best: Dictionary) -> void:
	if mi.skin == null or mi.mesh == null:
		return
	if _group.is_empty():
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
			_group[i] = nm
	var dirs := _measure_dirs()
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
			var nm3: String = _group.get(int(bind[0]), "")
			if nm3 == "":
				continue
			var p: Vector3 = (bind[1] as Transform3D) * pos[i]      # skeleton space, rest pose
			var slots: Array = best[nm3]
			for di in dirs.size():
				var sc: float = p.dot(dirs[di])
				if sc > float(slots[di][0]):
					slots[di] = [sc, p]

func _best_points(best: Dictionary) -> Dictionary:
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
	return out

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
func _ground(back: Transform3D, q: Basis, whole: bool, settle: bool, standing_clip: bool = false, hold_hips: bool = true) -> void:
	var low := 1e9
	if standing_clip and hold_hips and not whole:
		# a clip that sinks the hips further than the skirt or fauld hanging from them allows: the hips are held up
		# and both legs solved again to where the feet already stand
		var hang0 := 0.0
		for nm0: String in ["Hips", "LeftUpLeg", "RightUpLeg"]:
			hang0 = minf(hang0, _low(nm0, back))
		if hang0 < -0.03:
			var feet := {}
			for side: String in ["Left", "Right"]:
				feet[side] = skel.get_bone_global_pose(bone[side + "Foot"])
			var h0 := skel.get_bone_global_pose(bone["Hips"])
			var up0 := (q * Vector3.UP).normalized()
			var rise: float = minf(-0.03 - hang0, 0.3) / back.basis.get_scale().y
			# (no further than the legs can follow with the feet still on the floor)
			for side: String in ["Left", "Right"]:
				var d: Vector3 = (feet[side] as Transform3D).origin - skel.get_bone_global_pose(bone[side + "UpLeg"]).origin
				var leg: float = ((rest[side + "Leg"].origin - rest[side + "UpLeg"].origin).length() + (rest[side + "Foot"].origin - rest[side + "Leg"].origin).length()) * 0.985
				var flat2: float = d.length_squared() - d.dot(up0) * d.dot(up0)
				rise = minf(rise, maxf(0.0, sqrt(maxf(leg * leg - flat2, 0.0)) - absf(d.dot(up0))))
			skel.set_bone_global_pose(bone["Hips"], Transform3D(h0.basis, h0.origin + up0 * rise))
			for side: String in ["Left", "Right"]:
				var hip: Vector3 = skel.get_bone_global_pose(bone[side + "UpLeg"]).origin
				var knee: Vector3 = skel.get_bone_global_pose(bone[side + "Leg"]).origin
				var f: Transform3D = feet[side]
				var pole := knee - hip.lerp(f.origin, 0.5)
				if pole.length() < 0.02 * (knee - hip).length():
					pole = q * Vector3(0.15 if side == "Right" else -0.15, 0.1, -1)
				var o := _limb(side + "UpLeg", side + "Leg", side + "Foot", f.origin, pole)
				skel.set_bone_global_pose(bone[side + "Foot"], Transform3D(f.basis, o))
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
		if standing_clip:
			# the clip's own feet are not re-planted one by one: the figure stands on whichever is lower
			for nm3: String in ["LeftFoot", "RightFoot"]:
				low = minf(low, _low(nm3, back))
	if low > 1e8:
		return
	low -= SOLE
	if low < 0.0 or (settle and (whole or standing_clip) and low > 0.0):
		var hi: int = bone["Hips"]
		var cur := skel.get_bone_global_pose(hi)
		var lift := -low * (clip_w if low > 0.0 and not standing_clip else 1.0)
		skel.set_bone_global_pose(hi, Transform3D(cur.basis, cur.origin + (q * Vector3.UP).normalized() * (lift / back.basis.get_scale().y)))

# ---------------------------------------------------------------- authored clips
## Authored skeletal motion (assets/anim/humanoid.res) layered over the procedural pose.
## The rig sets these each frame; weight 0 leaves the procedural pose untouched.
var clip := ""
var clip_t := 0.0
var clip_w := 0.0
var clip_full := false        # false: body and legs only, sword and shield arms stay on IK
var clip_travel := 1.0        # how much of a whole-body clip's own travel to apply
var arm_r := 1.0              # share of a whole-body clip the sword arm takes; 0 leaves it on IK (a pinned blade)
var arm_l := 1.0              # the same for the shield / off arm (a braced shield)
var clip_look := false        # whole-body clip, but the head is still turned to the opponent as far as the neck allows
var clip_roll := 0.0          # radians the sword arm is turned about the line to the opponent (+ lifts a rightward cut)
var clip_axis := {}           # "Right"/"Left" -> the way the clip itself points a handle in that hand, this frame
var roll_chest := false       # `clip_roll` is taken at the chest (both arms together, a two-handed grip), not the sword arm
const ROLL_CLAVICLE := 0.3    # share of `clip_roll` taken at the collar bone; the rest at the shoulder joint
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
	var map := _track_map(clip)
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
		var bw := clip_w
		if arms:
			bw *= arm_r if b.begins_with("Right") else arm_l
			if bw <= 0.0:
				continue
		var mixed := Basis(cur_b.get_rotation_quaternion().slerp(target.get_rotation_quaternion(), bw))
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

# ---------------------------------------------------------------- feet placed by the rig
## Called at the end of drive(), before the hands are read: the rig puts each foot where it must stand in the world
## (a planted foot stays put while the body moves over it; a foot on a slope stands on the ground under it).
var foot_fix := Callable()

## The way the toes point, as a turn about the vertical in rig body space (0 = straight ahead, -Z).
func foot_yaw(side: String) -> float:
	if not bone.has(side + "ToeBase"):
		return 0.0
	var d: Vector3 = _back.basis * (skel.get_bone_global_pose(bone[side + "ToeBase"]).origin - skel.get_bone_global_pose(bone[side + "Foot"]).origin)
	return atan2(-d.x, -d.z)

## Hip joint to ankle with the leg straight, in rig body space metres.
func leg_len(side: String) -> float:
	return ((rest[side + "Leg"].origin - rest[side + "UpLeg"].origin).length() + (rest[side + "Foot"].origin - rest[side + "Leg"].origin).length()) * _back.basis.get_scale().y

## How high the ankle is when this foot stands flat on the floor (rig body space metres).
func ankle_height(side: String) -> float:
	var pts: PackedVector3Array = _contact.get(side + "Foot", PackedVector3Array())
	if pts.is_empty():
		return rest[side + "Foot"].origin.y * _back.basis.get_scale().y
	return SOLE - _low_with(pts, _back.basis * (rest[side + "Foot"] as Transform3D).basis.orthonormalized())

## Move the hips (and all they carry) by `d`, rig body space.
func shift_hips(d: Vector3) -> void:
	var hi: int = bone["Hips"]
	var cur := skel.get_bone_global_pose(hi)
	skel.set_bone_global_pose(hi, Transform3D(cur.basis, cur.origin + _back.affine_inverse().basis * d))

func _leg_to(side: String, ankle: Vector3, basis: Basis) -> void:
	var fi: int = bone[side + "Foot"]
	var hip: Vector3 = skel.get_bone_global_pose(bone[side + "UpLeg"]).origin
	var knee: Vector3 = skel.get_bone_global_pose(bone[side + "Leg"]).origin
	var f: Vector3 = skel.get_bone_global_pose(fi).origin
	var pole := knee - hip.lerp(f, 0.5)
	var fwd := _back.affine_inverse().basis.orthonormalized() * Vector3(0.15 if side == "Right" else -0.15, 0.1, -1)
	if pole.length() < 0.05 * (knee - hip).length():
		pole = fwd
	else:
		pole = pole.normalized() + fwd * 0.35      # (a knee never swings round behind the leg as the foot is moved)
	var o := _limb(side + "UpLeg", side + "Leg", side + "Foot", ankle, pole)
	skel.set_bone_global_pose(fi, Transform3D(basis, o))

## A foot stood flat: its sole at `at` (rig body space; `at.y` is the height of the ground there), raised by `lift`,
## turned `yaw_add` radians about the vertical from where the pose has it and tipped `pitch` (toes up) for a slope.
func step_foot(side: String, at: Vector3, lift: float = 0.0, yaw_add: float = 0.0, pitch: float = 0.0) -> void:
	var to_skel := _back.affine_inverse()
	var q := to_skel.basis.orthonormalized()
	var up := (q * Vector3.UP).normalized()
	var cur := skel.get_bone_global_pose(bone[side + "Foot"]).basis.orthonormalized()
	var rb: Basis = (rest[side + "Foot"] as Transform3D).basis.orthonormalized()
	var dq := (cur * rb.inverse()).get_rotation_quaternion()
	var along := up * Vector3(dq.x, dq.y, dq.z).dot(up)
	var tw := Quaternion(along.x, along.y, along.z, dq.w)
	tw = tw.normalized() if tw.length_squared() > 0.0001 else Quaternion.IDENTITY
	var flat := Basis(up, yaw_add) * Basis(tw) * rb
	var pts: PackedVector3Array = _contact.get(side + "Foot", PackedVector3Array())
	var h: float = (SOLE - _low_with(pts, _back.basis * flat)) if not pts.is_empty() else ankle_height(side)
	if pitch != 0.0 and bone.has(side + "ToeBase"):
		var toe: Vector3 = flat * rb.inverse() * (rest[side + "ToeBase"].origin - rest[side + "Foot"].origin)
		var axis := toe.cross(up)
		if axis.length() > 0.001:
			flat = Basis(axis.normalized(), pitch) * flat
	_leg_to(side, to_skel * Vector3(at.x, at.y + lift + h, at.z), flat)
	if bone.has(side + "ToeBase"):
		# (a foot stood flat has its toes flat: a walk clip that has stopped leaves them as it last bent them)
		var ti: int = bone[side + "ToeBase"]
		skel.set_bone_pose_rotation(ti, skel.get_bone_rest(ti).basis.get_rotation_quaternion())

## A foot kept as the pose has it (heel strike, toe-off) but with its ankle at `ankle` (rig body space), tipped `pitch`.
func move_foot(side: String, ankle: Vector3, pitch: float = 0.0) -> void:
	var to_skel := _back.affine_inverse()
	var b := skel.get_bone_global_pose(bone[side + "Foot"]).basis
	if pitch != 0.0 and bone.has(side + "ToeBase"):
		var up := (to_skel.basis.orthonormalized() * Vector3.UP).normalized()
		var toe: Vector3 = skel.get_bone_global_pose(bone[side + "ToeBase"]).origin - skel.get_bone_global_pose(bone[side + "Foot"]).origin
		var axis := Vector3(toe.x, 0, toe.z).cross(up) if absf(up.y) > 0.9 else toe.cross(up)
		if axis.length() > 0.001:
			b = Basis(axis.normalized(), pitch) * b
	_leg_to(side, to_skel * ankle, b)

# ---------------------------------------------------------------- a clip's own travel
## How far along its own travel a root-motion clip is at `t` (0 at the start, 1 where it ends up); time itself for a
## clip that goes nowhere.
static func clip_travel_frac(cn: String, t: float) -> float:
	if not has_clip(cn):
		return 0.0
	var a: Animation = _lib.get_animation(cn)
	var ti := a.find_track(NodePath("_pos"), Animation.TYPE_POSITION_3D)
	if ti < 0:
		for i in a.get_track_count():
			if a.track_get_type(i) == Animation.TYPE_POSITION_3D:
				ti = i
	var u := clampf(t / maxf(a.length, 0.001), 0.0, 1.0)
	if ti < 0:
		return u
	var p0: Vector3 = a.position_track_interpolate(ti, 0.0)
	var p1: Vector3 = a.position_track_interpolate(ti, a.length)
	var all := Vector2(p1.x - p0.x, p1.z - p0.z)
	if all.length() < 0.2:
		return u
	var p: Vector3 = a.position_track_interpolate(ti, clampf(t, 0.0, a.length))
	return clampf(Vector2(p.x - p0.x, p.z - p0.z).dot(all) / all.length_squared(), 0.0, 1.0)

## Metres of ground one whole cycle of an in-place walk clip covers on this skeleton: what each foot sweeps back
## under the body while it is down, both feet together.
var _stride := {}
func clip_stride(cn: String) -> float:
	if _stride.has(cn):
		return _stride[cn]
	var out := 1.5
	if has_clip(cn):
		if not _canon_ready:
			_prepare_canon()
		var a: Animation = _lib.get_animation(cn)
		var map := _track_map(cn)
		var src_dir: Dictionary = a.get_meta("rest_dir", {})
		out = 0.0
		for side: String in ["Left", "Right"]:
			var lo := 1e9
			var hi := -1e9
			for i in 32:
				var t := a.length * i / 32.0
				var o := Vector3.ZERO
				var d_par := Basis.IDENTITY
				var prev := ""
				for b: String in ["Hips", side + "UpLeg", side + "Leg", side + "Foot"]:
					if prev != "":
						o += d_par * (rest[b].origin - rest[prev].origin)
					if map.has(b):
						var d := Basis(a.rotation_track_interpolate(map[b], t))
						if _my_dir.has(b) and src_dir.has(b):
							d = d * Basis(Quaternion(_my_dir[b], src_dir[b]))
						d_par = d * _canon
					prev = b
				lo = minf(lo, o.z)      # (canonical frame: the fighter faces -Z)
				hi = maxf(hi, o.z)
			out += (hi - lo) * root.scale.y * (root.global_transform.affine_inverse() * skel.global_transform).basis.get_scale().y
	_stride[cn] = maxf(out, 0.3)
	return _stride[cn]
