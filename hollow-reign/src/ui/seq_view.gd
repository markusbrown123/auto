class_name SeqView
extends Control
## Draws a cut sequence as a row of small arrows. Used by the journal and the training ground.

var seq: Array = []
var color := UI.BONE
var lit := 0              # how many arrows from the left are drawn bright; -1 = all
var cell := 30.0

func _init(sequence: Array = [], cell_size: float = 30.0, col: Color = UI.BONE) -> void:
	cell = cell_size
	color = col
	lit = -1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_seq(sequence)

func show_seq(sequence: Array, bright: int = -1) -> void:
	seq = sequence
	lit = bright
	custom_minimum_size = Vector2(cell * maxi(1, seq.size()), cell)
	queue_redraw()

func _draw() -> void:
	for i in seq.size():
		var v: Vector2 = DuelSim.dir_vec(str(seq[i]))
		v.y = -v.y
		v = v.normalized()
		var c := Vector2(cell * (i + 0.5), cell * 0.5)
		var r := cell * 0.34
		var col := color if (lit < 0 or i < lit) else Color(color.r, color.g, color.b, 0.3)
		var tip := c + v * r
		var side := Vector2(-v.y, v.x)
		draw_line(c - v * r, tip, col, 2.5, true)
		draw_line(tip, tip - v * r * 0.7 + side * r * 0.5, col, 2.5, true)
		draw_line(tip, tip - v * r * 0.7 - side * r * 0.5, col, 2.5, true)
