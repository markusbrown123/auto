class_name SkinDriver
extends RefCounted
## Drives a rigged character model (Mixamo-style skeleton) from FighterRig's
## procedural control points, so generated models inherit every attack arc,
## dodge and stagger without any authored animation clips.
## All maths is done in the skeleton's own space; limbs are solved with
## two-bone IK using the model's real bone lengths, so hands and feet land
## exactly on their targets.

const HEIGHT := 1.95          # metres, to match the procedural rig's proportions

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

func _limb(up: String, mid: String, end: String, target: Vector3, pole: Vector3) -> Vector3:
	var a := _fk_origin(up)
	var la: float = (rest[mid].origin - rest[up].origin).length()
	var lb: float = (rest[end].origin - rest[mid].origin).length()
	var reach := (target - a).limit_length(la + lb - 0.001)
	var t := a + reach
	var m := _ik(a, t, la, lb, pole)
	_aim(up, mid, a, m - a)
	_aim(mid, end, m, t - m)
	return t

## `j` holds control points in the parent (rig body) space:
## pelvis, pelvis_rot, chest_rot, head_rot (Basis), hand_r, hand_l, ankle_r, ankle_l (Vector3).
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
	# legs: knees forward, feet flat
	for side in [["Right", "r", 0.15], ["Left", "l", -0.15]]:
		var ankle := _limb(side[0] + "UpLeg", side[0] + "Leg", side[0] + "Foot", to_skel * j["ankle_" + side[1]], q * Vector3(side[2], 0.1, -1))
		_pose_bone(side[0] + "Foot", rest[side[0] + "Foot"].basis, ankle)
	_overlay(false)
	# arms: elbows fall outward and down
	var hr := _limb("RightArm", "RightForeArm", "RightHand", to_skel * j.hand_r, q * Vector3(0.7, -0.8, 0.35))
	var hl := _limb("LeftArm", "LeftForeArm", "LeftHand", to_skel * j.hand_l, q * Vector3(-0.7, -0.8, 0.35))
	var back := to_skel.affine_inverse()
	if clip_full and clip_w > 0.0:
		# whole-body clips (falling, dying) carry the arms too; the weapons follow the real hands
		_overlay(true)
		hr = skel.get_bone_global_pose(bone["RightHand"]).origin
		hl = skel.get_bone_global_pose(bone["LeftHand"]).origin
	return {"r": back * _palm("Right", hr), "l": back * _palm("Left", hl)}

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
		var i: int = bone[b]
		var cur_b: Basis = skel.get_bone_global_pose(i).basis.orthonormalized()
		var origin: Vector3 = skel.get_bone_global_pose(i).origin if b == "Hips" else _fk_origin(b)
		skel.set_bone_global_pose(i, Transform3D(Basis(cur_b.get_rotation_quaternion().slerp(target.get_rotation_quaternion(), clip_w)), origin))

## The grip sits in the palm, not at the wrist.
func _palm(side: String, wrist: Vector3) -> Vector3:
	var mid := side + "HandMiddle1"
	if not bone.has(mid):
		return wrist
	return wrist.lerp(skel.get_bone_global_pose(bone[mid]).origin, 0.75)
