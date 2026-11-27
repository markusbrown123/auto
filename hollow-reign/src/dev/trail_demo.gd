class_name TrailDemo
extends Node
## Dev (`--screen=trails`): draws the eight swipes by synthetic touch over the training duel, a short one and a long
## one in each direction, one every PERIOD frames, and holds the finger at the end so a capture shows the whole trail.
## Capture at 2.0 + 0.2 + i * PERIOD / 30 seconds (i = 0..15: short R, UR, U, UL, L, DL, D, DR, then the long ones).
## The finger lifts at frame 8 of a stroke: a capture 0.1 s later shows the fade.

const DIRS := [Vector2(1, 0), Vector2(1, -1), Vector2(0, -1), Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]
const PERIOD := 36
const FIRST := 60                  # frames before the first stroke
var _f := 0

func _win(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p

func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = _win(pos)
	e.pressed = pressed
	Input.parse_input_event(e)

func _drag(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = _win(pos)
	e.relative = rel
	Input.parse_input_event(e)

func _process(_delta: float) -> void:
	_f += 1
	if _f < FIRST:
		return
	var i := (_f - FIRST) / PERIOD
	var k := (_f - FIRST) % PERIOD
	if i >= 16:
		return
	var dir: Vector2 = (DIRS[i % 8] as Vector2).normalized()
	var length := 150.0 if i < 8 else 380.0
	var v := dir * length
	var size := get_viewport().get_visible_rect().size
	var a := size * Vector2(0.5, 0.46) - v * 0.5
	if k == 0:
		_touch(a, true)
	elif k <= 4:
		var step := v / 8.0       # two moves a frame, four frames: a quick flick
		_drag(a + step * (2 * k - 1), step)
		_drag(a + step * (2 * k), step)
	elif k == 8:
		_touch(a + v, false)
