class_name CamFollow
extends Node
## A camera that goes with a walking figure: behind and to one side of it, turned with it, damped so that neither a
## stride nor a step nor a turn shakes the frame, and pulled in front of anything that comes between it and the
## figure's head and chest (a pillar, a wall, a tree). Usable by the road, the explore stops and the story walks:
## set `cam`, `target`, `offset` (metres in the target's own facing: x right, y up, z back) and `look_ahead`.
##
## Obstruction is tested against what is drawn, not physics (the game has no colliders): `RenderingServer.instances_cull_ray`
## gives the meshes whose bounds the sight line crosses, and each is tested exactly on its triangles (a TriangleMesh per
## mesh, made once and kept). Thin things (a mesh whose bounds are under 12 cm across) and the figure itself never count.

var cam: Camera3D
var target: Node3D
var offset := Vector3(1.0, 1.45, 3.6)
var look_ahead := Vector3(-0.2, 1.25, -2.6)
var follow_time := 0.55        # seconds the camera takes to catch up with where the figure has gone (a damped spring)
var turn_time := 0.9           # seconds it takes to come round behind a figure that has turned
var height_time := 0.8         # seconds it takes to follow a change of ground height (steps, a slope): no bob per stair
var avoid := true              # pull in in front of whatever blocks the view
var measure := false           # count blocked frames even with `avoid` off (before/after measurements)
var min_dist := 0.9            # never closer to the head than this when pulled in
var enabled := true

# what happened (for the probe and --camlog)
var blocked_frames := 0        # frames in which the wanted place was blocked from the head or chest
var seen_blocked := 0          # frames in which the camera's actual place was still blocked
var pull_ins := 0              # times the camera began to pull in

var _p := Vector3.ZERO
var _v := Vector3.ZERO
var _yaw := 0.0
var _y := 0.0
var _pull := 1.0               # 1: at the wanted distance; less: pulled in toward the head
var _was_blocked := false
var _swing := 0.0              # radians the camera has swung round the figure to see past something close to it
var _swing_to := 0.0
var _ok := false

func snap() -> void:
	_ok = false

func _process(delta: float) -> void:
	if not enabled or cam == null or target == null or not is_instance_valid(target) or delta <= 0.0:
		return
	var gp := target.global_position
	if not _ok:
		_p = gp
		_v = Vector3.ZERO
		_yaw = target.global_rotation.y
		_y = gp.y
		_pull = 1.0
		_ok = true
	# the figure's place, as a critically damped mass (no stride bob reaches it: it follows the origin, not the hips)
	var w := 4.0 / maxf(follow_time, 0.05)
	_v += ((Vector3(gp.x, 0, gp.z) - Vector3(_p.x, 0, _p.z)) * w * w - _v * 2.0 * w) * delta
	_p += _v * delta
	_y = lerpf(_y, gp.y, 1.0 - exp(-delta * 3.0 / maxf(height_time, 0.05)))
	_yaw = lerp_angle(_yaw, target.global_rotation.y, 1.0 - exp(-delta * 3.0 / maxf(turn_time, 0.05)))
	var base := Vector3(_p.x, _y, _p.z)
	var head := base + Vector3(0, 1.6 * target.scale.y, 0)
	var chest := base + Vector3(0, 1.15 * target.scale.y, 0)
	# (the shoulders as well as the middle: a post that covers half the body is in the way before it reaches the head)
	var side := Basis(Vector3.UP, _yaw) * Vector3(0.28 * target.scale.y, 0, 0)
	var look := base + Basis(Vector3.UP, _yaw) * look_ahead
	var want_pull := 1.0
	if avoid or measure:
		var clear0 := clear_from(target, [head, chest, chest + side, chest - side], base + Basis(Vector3.UP, _yaw) * offset, min_dist)
		if clear0 < 0.999:
			blocked_frames += 1
			if not _was_blocked:
				pull_ins += 1
		_was_blocked = clear0 < 0.999
		if avoid:
			# something too near the figure to be stepped in front of: the camera swings round it instead (the nearest
			# side first, at most 50 degrees), and back behind once the way is clear
			if clear0 >= 0.999:
				_swing_to = 0.0
			elif not _clear_at(head, chest, base, _swing_to):
				for cand: float in [_swing_to, 0.45, -0.45, 0.9, -0.9]:
					if _clear_at(head, chest, base, cand):
						_swing_to = cand
						break
			_swing = lerpf(_swing, _swing_to, 1.0 - exp(-delta * 3.0))
			want_pull = clear_from(target, [head, chest, chest + side, chest - side], base + Basis(Vector3.UP, _yaw + _swing) * offset, min_dist)
	var eye := base + Basis(Vector3.UP, _yaw + _swing) * offset
	# in quickly (a frame or two), out again slowly so that a pillar going by does not pump the lens
	_pull = lerpf(_pull, want_pull, 1.0 - exp(-delta * (18.0 if want_pull < _pull else 1.6)))
	var at := head.lerp(eye, _pull)
	cam.global_position = at
	if not at.is_equal_approx(look):
		cam.look_at(look)
	if (avoid or measure) and not sight_clear(target, [head], at):
		seen_blocked += 1

## Whether, swung `swing` radians round the figure, the camera (pulled in as far as it may be) sees head and chest.
func _clear_at(head: Vector3, chest: Vector3, base: Vector3, swing: float) -> bool:
	var e := base + Basis(Vector3.UP, _yaw + swing) * offset
	var c := clear_from(target, [head, chest], e, min_dist)
	return sight_clear(target, [head, chest], head.lerp(e, c))

# ---------------------------------------------------------------- the test, for any camera
static var _tri := {}          # mesh RID -> TriangleMesh (null: not tested, too big)
const MAX_FACES := 60000       # meshes with more triangles than this are not tested (built once each: a hitch)
const MAX_TESTS := 8           # meshes tested exactly per sight line

## The share (0..1) of the way from the figure's head to `eye` that the camera can stand at and still see every one of
## `points` (head, chest) with nothing drawn in between; 1 when nothing blocks. `min_dist`: metres from the head it is
## never brought nearer than.
static func clear_from(figure: Node3D, points: Array, eye: Vector3, min_dist: float = 0.9) -> float:
	var head: Vector3 = points[0]
	var full := head.distance_to(eye)
	if full < 0.01:
		return 1.0
	var best := 1.0
	for p: Vector3 in points:
		var hit := _first_hit(figure, p, eye)
		if hit >= 0.0:
			# stand a little in front of what was hit, measured from the head along the camera's own line
			var d := clampf(hit * p.distance_to(eye) - 0.25, min_dist, full)
			best = minf(best, d / full)
	return best

## Whether every one of `points` can be seen from `eye` with nothing drawn in between.
static func sight_clear(figure: Node3D, points: Array, eye: Vector3) -> bool:
	for p: Vector3 in points:
		if _first_hit(figure, p, eye) >= 0.0:
			return false
	return true

## How far along from `a` to `b` (0..1) the first drawn surface lies, or -1.
static func _first_hit(figure: Node3D, a: Vector3, b: Vector3) -> float:
	var w := figure.get_world_3d()
	if w == null:
		return -1.0
	var best := -1.0
	var tested := 0
	for id: int in RenderingServer.instances_cull_ray(a, b, w.scenario):
		if tested >= MAX_TESTS:
			break
		var o := instance_from_id(id)
		var mi := o as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		if mi == figure or figure.is_ancestor_of(mi) or mi.skin != null:
			continue      # (the figure itself, and other characters: a foe in front of the lens is framing, not scenery)
		var bb := mi.get_aabb()
		var sc := mi.global_transform.basis.get_scale()
		if minf(minf(bb.size.x * sc.x, bb.size.y * sc.y), bb.size.z * sc.z) < 0.12 and maxf(maxf(bb.size.x * sc.x, bb.size.y * sc.y), bb.size.z * sc.z) < 1.0:
			continue      # (a rope, a blade of grass, a small prop: not a wall)
		if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or mi.transparency > 0.5:
			continue
		var key := mi.mesh.get_rid()
		if _tri.has(key) and _tri[key] == null:
			continue
		var tm: TriangleMesh = _tri.get(key)
		if tm == null:
			var faces := 0
			for si in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(si)
				var idx = arr[Mesh.ARRAY_INDEX]
				faces += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			tm = mi.mesh.generate_triangle_mesh() if faces <= MAX_FACES else null
			_tri[key] = tm      # (a mesh too big to test, a whole terrain, is remembered as untested and passed over)
			if tm == null:
				continue
		tested += 1
		var inv := mi.global_transform.affine_inverse()
		var la := inv * a
		var lb := inv * b
		var r: Dictionary = tm.intersect_segment(la, lb)
		if r.is_empty():
			continue
		var f := la.distance_to(r.position) / maxf(la.distance_to(lb), 0.0001)
		if best < 0.0 or f < best:
			best = f
	return best
