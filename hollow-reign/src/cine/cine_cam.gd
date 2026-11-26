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
		var b := Basis(Vector3.UP, follow.rotation.y)
		return [follow.global_position + b * pos, follow.global_position + b * at]
	return [pos, at]

func _place() -> void:
	var f := _frame()
	var sway := Vector3(sin(_clock * 0.31) * drift, sin(_clock * 0.43) * drift * 0.5, cos(_clock * 0.23) * drift)
	if Game.settings.reduce_motion:
		sway = Vector3.ZERO
	global_position = f[0] + sway
	if not global_position.is_equal_approx(f[1]):
		look_at(f[1])

func _process(delta: float) -> void:
	_clock += delta
	_place()
