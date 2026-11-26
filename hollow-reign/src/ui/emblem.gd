class_name Emblem
extends Control
## The game's mark, drawn in code: an open ring (a crown with nobody under it), three tines, and a blade through it.
## With `turning` set it is the loading mark: the ring's gap travels round while work is being done.

var color := UI.GOLD
var turning := false
var _a := 0.0

func _init(size_px: float = 96.0, tint: Color = UI.GOLD, spin: bool = false) -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	color = tint
	turning = spin
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_process(turning)

func _process(delta: float) -> void:
	_a += delta * 1.7
	queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var r := s * 0.34
	var w := maxf(1.5, s * 0.028)
	# the ring, open at the top (or wherever the gap has travelled to)
	var gap := 0.55
	var start := -PI * 0.5 + gap * 0.5 + _a
	draw_arc(c, r, start, start + TAU - gap, 48, color, w, true)
	draw_arc(c, r * 0.8, start + 0.5, start + TAU - gap - 0.5, 40, Color(color, 0.4), maxf(1.0, w * 0.5), true)
	if turning:
		return
	# three tines above the gap
	for i in 3:
		var x := (i - 1) * r * 0.5
		var h := r * (0.62 if i == 1 else 0.42)
		var base := c + Vector2(x, -r * (1.0 if i == 1 else 0.86))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 1.6, 0), base + Vector2(0, -h), base + Vector2(w * 1.6, 0)]), color)
	# the blade: down through the ring, point below it
	var top := c + Vector2(0, -r * 0.42)
	var tip := c + Vector2(0, r * 1.42)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-w * 1.1, 0), top + Vector2(w * 1.1, 0), tip + Vector2(w * 0.6, -r * 0.3), tip, tip + Vector2(-w * 0.6, -r * 0.3)]), color)
	draw_line(top + Vector2(-r * 0.36, 0), top + Vector2(r * 0.36, 0), color, w * 1.3, true)
	draw_circle(top + Vector2(0, -w * 2.6), w * 1.3, color)
