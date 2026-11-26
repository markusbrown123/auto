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

func tint(c: Color, amount: float = 0.45) -> void:
	var m: float = maxf(maxf(c.r, c.g), maxf(c.b, 0.01))
	var t := Color.WHITE.lerp(Color(c.r / m, c.g / m, c.b / m), amount)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat = mi.get_active_material(s)
			if mat is BaseMaterial3D:
				var dup: BaseMaterial3D = mat.duplicate()
				dup.albedo_color = t
				mi.set_surface_override_material(s, dup)

func flash(v: float) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat = mi.get_surface_override_material(s)
			if mat is BaseMaterial3D:
				mat.emission_enabled = v > 0.0
				mat.emission = Color(1, 0.9, 0.8)
				mat.emission_energy_multiplier = v * 0.25

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
	_overlay(false)
	# arms: elbows fall outward and down
	var hr := _limb("RightArm", "RightForeArm", "RightHand", to_skel * j.hand_r, q * Vector3(0.7, -0.8, 0.35))
	var hl := _limb("LeftArm", "LeftForeArm", "LeftHand", to_skel * j.hand_l, q * Vector3(-0.7, -0.8, 0.35))
	# legs: knees forward, feet flat
	for side in [["Right", "r", 0.15], ["Left", "l", -0.15]]:
		var ankle := _limb(side[0] + "UpLeg", side[0] + "Leg", side[0] + "Foot", to_skel * j["ankle_" + side[1]], q * Vector3(side[2], 0.1, -1))
		_pose_bone(side[0] + "Foot", rest[side[0] + "Foot"].basis, ankle)
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
static var _lib: AnimationLibrary
static var _lib_rest: Dictionary
static var _tracks: Dictionary = {}      # clip -> {bone: track index}, plus "_pos" for the hip position
const ARM_BONES := ["Shoulder", "Arm", "ForeArm", "Hand"]

static func has_clip(n: String) -> bool:
	if _lib == null and ResourceLoader.exists("res://assets/anim/humanoid.res"):
		_lib = load("res://assets/anim/humanoid.res")
		_lib_rest = _lib.get_meta("rest", {})
	return _lib != null and _lib.has_animation(n)

static func clip_length(n: String) -> float:
	return _lib.get_animation(n).length if has_clip(n) else 0.0

func _is_arm(b: String) -> bool:
	return b.begins_with("Left") or b.begins_with("Right") if (b.contains("Hand") or b.contains("Arm") or b.contains("Shoulder")) else false

func _overlay(arms: bool) -> void:
	if clip_w <= 0.0 or not has_clip(clip):
		return
	var a: Animation = _lib.get_animation(clip)
	if not _tracks.has(clip):
		var m := {}
		for t in a.get_track_count():
			var b := str(a.track_get_path(t)).get_slice(":", 1)
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
				m["_pos"] = t
			else:
				m[b] = t
		_tracks[clip] = m
	var map: Dictionary = _tracks[clip]
	var t := fposmod(clip_t, a.length) if a.loop_mode != Animation.LOOP_NONE else clampf(clip_t, 0.0, a.length)
	for b in map:
		if b == "_pos" or not bone.has(b) or _is_arm(b) != arms:
			continue
		var i: int = bone[b]
		var q: Quaternion = a.rotation_track_interpolate(map[b], t)
		# carry the motion across skeletons with different rest poses as a change from rest
		if _lib_rest.has(b):
			q = skel.get_bone_rest(i).basis.get_rotation_quaternion() * (_lib_rest[b] as Transform3D).basis.get_rotation_quaternion().inverse() * q
		skel.set_bone_pose_rotation(i, skel.get_bone_pose_rotation(i).slerp(q, clip_w))
	if not arms and map.has("_pos") and _lib_rest.has("Hips"):
		# hip height (and, for whole-body clips, travel) scaled to this skeleton's leg length
		var src: Vector3 = (_lib_rest["Hips"] as Transform3D).origin
		var k: float = rest["Hips"].origin.y / maxf(src.y, 0.001)
		var d: Vector3 = (a.position_track_interpolate(map["_pos"], t) - (src if not clip_full else a.position_track_interpolate(map["_pos"], 0.0))) * k
		if not clip_full:
			d.x = 0.0
			d.z = 0.0
		var i2: int = bone["Hips"]
		var base: Vector3 = skel.get_bone_pose_position(i2)
		if clip_full:
			base = base.lerp(Vector3(base.x, rest["Hips"].origin.y + (a.position_track_interpolate(map["_pos"], 0.0).y - src.y) * k, base.z), clip_w)
		skel.set_bone_pose_position(i2, base + d * clip_w)

## The grip sits in the palm, not at the wrist.
func _palm(side: String, wrist: Vector3) -> Vector3:
	var mid := side + "HandMiddle1"
	if not bone.has(mid):
		return wrist
	return wrist.lerp(skel.get_bone_global_pose(bone[mid]).origin, 0.75)
