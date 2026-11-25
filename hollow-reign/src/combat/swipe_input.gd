class_name SwipeInput
extends Control
## Turns touches into eight-way swipes. A swipe fires the moment the finger
## has travelled far and fast enough — not on release — so cuts feel immediate.
## Slow drags and short jitters are ignored, so resting a thumb is safe.

signal swiped(dir: String, vec: Vector2)

const NAMES := ["R", "UR", "U", "UL", "L", "DL", "D", "DR"]
var min_dist_frac := 0.085     # of the shorter screen side
var max_time := 0.35           # the distance must be covered within this
var min_speed_frac := 0.55     # screen-heights per second
var _touch := {}               # index -> {pos, t, path:[...]}
var trail_points: Array = []   # for the on-screen slash streak

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touch[e.index] = {"pos": e.position, "t": _now()}
		else:
			_touch.erase(e.index)
	elif e is InputEventScreenDrag and _touch.has(e.index):
		var s: Dictionary = _touch[e.index]
		var d: Vector2 = e.position - s.pos
		var dt: float = _now() - s.t
		var side: float = minf(size.x, size.y)
		if dt > max_time:
			# too slow to be a cut: re-anchor so a later flick still counts
			s.pos = e.position
			s.t = _now()
			return
		if d.length() >= side * min_dist_frac and d.length() / maxf(dt, 0.001) >= side * min_speed_frac:
			var v := Vector2(d.x, -d.y).normalized()
			swiped.emit(quantize(v), v)
			trail_points = [s.pos, e.position + d * 0.8]
			# re-anchor: a zig-zag without lifting the finger chains cuts
			s.pos = e.position
			s.t = _now()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func quantize(v: Vector2) -> String:
	var a := fposmod(atan2(v.y, v.x), TAU)
	return NAMES[int(round(a / (TAU / 8.0))) % 8]
