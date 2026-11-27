class_name CineSeat
extends Node
## Seats a rigged figure. There is no seated clip in the animation library, so this holds the pose over whatever the
## rig is doing: after the rig has posed its skeleton each frame, the hips are lowered to the seat, the thighs laid
## forward, the shins hung down and the feet set level, and the weapons are put back in the hands that moved.
## `amount` is how seated the figure is: tween it from 1 to 0 and they stand up.

var rig: FighterRig
var amount := 1.0
var seat := 0.56                  # how high the seat is above the rig's feet, metres
var back := 0.12                  # how far the hips go back into the chair, metres
var spread := 0.16                # how far the knees fall apart (0: thighs straight ahead)
var recline := 0.1                # radians the back leans into the chair

static func make(who: FighterRig, seat_height: float = 0.56) -> CineSeat:
	var s := CineSeat.new()
	s.rig = who
	s.seat = seat_height
	s.process_priority = 60       # after the rig (and anything riding it) has had its frame
	who.add_child(s)
	return s

func _process(_delta: float) -> void:
	if rig == null or rig.skin == null or amount <= 0.001:
		return
	var sk: SkinDriver = rig.skin
	var skel := sk.skel
	var k := smoothstep(0.0, 1.0, amount)
	# the skeleton's own axes: which way it faces, and how many of its units make a metre
	var toe := Vector3(0, 0, 1)
	if sk.bone.has("LeftToeBase"):
		toe = (sk.rest["LeftToeBase"] as Transform3D).origin - (sk.rest["LeftFoot"] as Transform3D).origin
	var fwd := Vector3(toe.x, 0, toe.z).normalized()
	var right := fwd.cross(Vector3.UP)
	var unit := maxf(skel.global_transform.basis.get_scale().y, 0.0001)
	var hips: int = sk.bone["Hips"]
	var hp := skel.get_bone_global_pose(hips)
	var to_feet: float = skel.global_position.y - rig.global_position.y
	var hip_rest: Transform3D = sk.rest["Hips"]
	var leg_rest: Transform3D = sk.rest["LeftUpLeg"]
	var want_y: float = (seat - to_feet) / unit + (hip_rest.origin.y - leg_rest.origin.y)
	hp.origin = hp.origin.lerp(Vector3(hp.origin.x, want_y, hp.origin.z) - fwd * (back / unit), k)
	hp.basis = Basis(right, -recline * k) * hp.basis
	skel.set_bone_global_pose(hips, hp)
	for side: Array in [["Left", -1.0], ["Right", 1.0]]:
		var out := right * float(side[1])
		_aim(skel, sk.bone[side[0] + "UpLeg"], sk.bone[side[0] + "Leg"], (fwd + out * spread + Vector3(0, -0.06, 0)).normalized(), k)
		_aim(skel, sk.bone[side[0] + "Leg"], sk.bone[side[0] + "Foot"], (Vector3.DOWN + fwd * 0.1 + out * spread * 0.4).normalized(), k)
		var foot: int = sk.bone[side[0] + "Foot"]
		var fp := skel.get_bone_global_pose(foot)
		fp.basis = fp.basis.slerp((sk.rest[side[0] + "Foot"] as Transform3D).basis, k)
		skel.set_bone_global_pose(foot, fp)
	# the weapons ride the hands the pose has just moved (as CineActor does for its clips)
	var into: Transform3D = sk.root.transform * (sk.root.global_transform.affine_inverse() * skel.global_transform)
	rig.weapon_r.position = into * sk._palm("Right", skel.get_bone_global_pose(sk.bone["RightHand"]).origin)
	rig.weapon_l.position = into * sk._palm("Left", skel.get_bone_global_pose(sk.bone["LeftHand"]).origin)
	if rig.shield:
		rig.shield.position = rig.weapon_l.position + Vector3(-0.02, 0, -0.07)

## Turns a bone so that it points from itself to its child along `dir` (skeleton space), `k` of the way.
func _aim(skel: Skeleton3D, b: int, child: int, dir: Vector3, k: float) -> void:
	var g := skel.get_bone_global_pose(b)
	var cur := (skel.get_bone_global_pose(child).origin - g.origin).normalized()
	if cur.is_equal_approx(dir) or cur.length() < 0.5:
		return
	var q := Quaternion(cur, dir)
	g.basis = Basis(Quaternion.IDENTITY.slerp(q, k)) * g.basis
	skel.set_bone_global_pose(b, g)
