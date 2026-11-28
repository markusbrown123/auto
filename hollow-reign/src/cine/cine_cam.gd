class_name CineCam
extends Camera3D
## The camera for the in-engine story scenes: a position and a point to look at, both eased, with a
## little handheld drift. It can also ride with a moving figure (a walking track).

var pos := Vector3(0, 1.5, 4)
var at := Vector3(0, 1.2, 0)
var drift := 0.02                 # metres of slow sway; 0 for a locked-off shot
var follow: Node3D                # when set, `pos` and `at` are offsets from this node (in its own facing)
var _clock := 0.0
var _tw: Tween
## Locomotion pass: riding with a walker, the camera turns with them through a damped yaw (a bend in the road swings
## the frame round smoothly, a stride never shakes it) and is pulled in front of anything drawn between it and their
## head or chest (CamFollow.clear_from). `subject`: a figure to keep clear for a shot that does not ride (optional).
## `--oldloco` keeps the rigid ride and no pull-in.
var avoid := true
var subject: Node3D
var ride_turn := 0.6              # seconds the ride's yaw takes to follow the walker's turn
var _ride_yaw := 0.0
var _ride_ok := false
var _pull := 1.0
var blocked_frames := 0           # dev: frames whose wanted place was blocked from the figure
var _frames := 0
var seen_blocked := 0             # dev: frames in which the camera, where it ended up, still could not see the head
## Dev: `--camlog` counts blocked frames (also under --oldloco, where nothing is done about them) and prints them.
static var camlog: bool = OS.get_cmdline_user_args().has("--camlog")

func _ready() -> void:
	fov = 45.0
	near = 0.08
	far = 600.0
	make_current()

## A hard cut to a new framing.
func cut(p: Vector3, look: Vector3, fov_deg: float = -1.0) -> void:
	if _tw:
		_tw.kill()
	pos = p
	at = look
	if fov_deg > 0.0:
		fov = fov_deg
	_place()

## Eases to a new framing over `dur` seconds.
func move(p: Vector3, look: Vector3, dur: float, fov_deg: float = -1.0, trans: int = Tween.TRANS_SINE) -> Tween:
	if _tw:
		_tw.kill()
	_tw = create_tween().set_parallel(true).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_property(self, "pos", p, dur)
	_tw.tween_property(self, "at", look, dur)
	if fov_deg > 0.0:
		_tw.tween_property(self, "fov", fov_deg, dur)
	return _tw

## Rides with `n`: from now on `pos` and `at` are measured from it, turned with it.
func ride(n: Node3D, p: Vector3, look: Vector3) -> void:
	if _tw:
		_tw.kill()
	follow = n
	pos = p
	at = look
	_ride_ok = false
	_pull = 1.0
	_place()

## Lets go of the figure, keeping the framing it has at this moment.
func let_go() -> void:
	if follow:
		var f := _frame()
		follow = null
		pos = f[0]
		at = f[1]

func _frame() -> Array:
	if follow and is_instance_valid(follow):
		var yaw := follow.rotation.y
		if FighterRig.loco and _ride_ok:
			yaw = _ride_yaw
		var b := Basis(Vector3.UP, yaw)
		return [follow.global_position + b * pos, follow.global_position + b * at]
	return [pos, at]

## How far along from the figure's head to `eye` the camera may stand with nothing drawn in between (1: all the way).
func _clear(eye: Vector3) -> float:
	var who: Node3D = follow if (follow and is_instance_valid(follow)) else (subject if subject and is_instance_valid(subject) else null)
	if who == null or not ((avoid and FighterRig.loco) or camlog):
		return 1.0
	var head := who.global_position + Vector3(0, 1.6 * who.scale.y, 0)
	var c := CamFollow.clear_from(who, [head, who.global_position + Vector3(0, 1.15 * who.scale.y, 0)], eye, 0.9)
	_frames += 1
	if c < 0.999:
		blocked_frames += 1
		if camlog:
			print("camlog %s blocked at %.2f s (clear %.2f)" % [get_path(), _clock, c])
	return c if (avoid and FighterRig.loco) else 1.0

func _place(dt: float = 0.0) -> void:
	var f := _frame()
	var dr := drift
	if FighterRig.loco and follow and is_instance_valid(follow):
		dr = minf(dr, 0.03)      # (riding with a walker the frame is held steady: the walk is the movement in it)
	var sway := Vector3(sin(_clock * 0.31) * dr, sin(_clock * 0.43) * dr * 0.5, cos(_clock * 0.23) * dr)
	if Game.settings.reduce_motion:
		sway = Vector3.ZERO
	var eye: Vector3 = f[0]
	var c := _clear(eye)
	# (in at once, out again over a second or so: a post going by does not pump the lens)
	_pull = c if dt <= 0.0 else lerpf(_pull, c, 1.0 - exp(-dt * (18.0 if c < _pull else 1.6)))
	if _pull < 0.999:
		var who: Node3D = follow if (follow and is_instance_valid(follow)) else subject
		var head := who.global_position + Vector3(0, 1.6 * who.scale.y, 0)
		eye = head.lerp(eye, _pull)
	global_position = eye + sway
	if camlog and _ride_ok and follow and is_instance_valid(follow) and avoid and FighterRig.loco:
		if not CamFollow.sight_clear(follow, [follow.global_position + Vector3(0, 1.6 * follow.scale.y, 0)], global_position):
			seen_blocked += 1
	if not global_position.is_equal_approx(f[1]):
		look_at(f[1])

func _process(delta: float) -> void:
	_clock += delta
	if follow and is_instance_valid(follow):
		if not _ride_ok:
			_ride_yaw = follow.rotation.y
			_ride_ok = true
		_ride_yaw = lerp_angle(_ride_yaw, follow.rotation.y, 1.0 - exp(-delta * 3.0 / maxf(ride_turn, 0.05)))
	_place(delta)

func _exit_tree() -> void:
	if camlog:
		print("camlog %s: %d of %d ridden frames blocked where the shot wanted the camera; %d still blocked where it was put" % [name, blocked_frames, _frames, seen_blocked])
