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
			_touch[e.index] = {"pos": e.position, "t": _now(), "last": Vector2.ZERO}
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
		var sens: float = clampf(float(Game.settings.get("swipe_sens", 1.0)), 0.5, 1.5)      # higher = shorter, slower strokes count
		if d.length() >= side * min_dist_frac / sens and d.length() / maxf(dt, 0.001) >= side * min_speed_frac / sens:
			var v := Vector2(d.x, -d.y).normalized()
			# One stroke is one cut, however long it is. Without lifting the
			# finger, only a clear change of direction (a zig-zag) chains another.
			if s.last == Vector2.ZERO or v.dot(s.last) < 0.3:
				swiped.emit(quantize(v), v)
				trail_points = [s.pos, e.position + d * 0.8]
				s.last = v
			s.pos = e.position
			s.t = _now()

var _clock := 0.0               # game time, not the wall clock: a stroke is judged by frames played, so a slow machine (or a test) reads it the same way

func _process(delta: float) -> void:
	_clock += minf(delta, 0.1)    # one long hitch must not expire a stroke that was quick in the player's hand

func _now() -> float:
	return _clock

static func quantize(v: Vector2) -> String:
	var a := fposmod(atan2(v.y, v.x), TAU)
	return NAMES[int(round(a / (TAU / 8.0))) % 8]
