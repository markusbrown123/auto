class_name InvGlyph
extends Control
## Small drawn marks for the inventory, so meaning never rests on colour or on a font having the glyph:
## "pips" (rarity: n of 5 diamonds filled), "up" / "down" (comparison arrows), "star" (favourite), "lock".

var kind := "pips"
var count := 0
var color := Color.WHITE

func _init(k: String, c: Color, n: int = 0, px: float = 14.0) -> void:
	kind = k
	color = c
	count = n
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(px * (4.1 if k == "pips" else 1.0), px)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _draw() -> void:
	var h := size.y
	match kind:
		"pips":
			for i in 5:
				var c := Vector2(h * 0.4 + i * h * 0.8, h * 0.5)
				var r := h * 0.34
				var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
				if i < count:
					draw_colored_polygon(pts, color)
				else:
					pts.append(pts[0])
					draw_polyline(pts, Color(color, 0.35), 1.0, true)
		"up":
			draw_colored_polygon(PackedVector2Array([Vector2(h * 0.5, h * 0.12), Vector2(h * 0.95, h * 0.85), Vector2(h * 0.05, h * 0.85)]), color)
		"down":
			draw_colored_polygon(PackedVector2Array([Vector2(h * 0.05, h * 0.15), Vector2(h * 0.95, h * 0.15), Vector2(h * 0.5, h * 0.88)]), color)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + i * PI / 5.0
				pts.append(Vector2(h * 0.5, h * 0.52) + Vector2(cos(a), sin(a)) * h * (0.5 if i % 2 == 0 else 0.21))
			if count > 0:
				draw_colored_polygon(pts, color)
			else:
				pts.append(pts[0])
				draw_polyline(pts, color, 1.2, true)
		"lock":
			draw_rect(Rect2(h * 0.18, h * 0.45, h * 0.64, h * 0.5), color)
			draw_arc(Vector2(h * 0.5, h * 0.45), h * 0.22, PI, TAU, 10, color, 1.6, true)
