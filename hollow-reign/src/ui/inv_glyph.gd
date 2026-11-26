class_name InvGlyph
extends Control
## Small drawn marks for the inventory, so meaning never rests on colour or on a font having the glyph:
## "pips" (rarity: n of 5 diamonds filled), "up" / "down" (comparison arrows), "star" (favourite), "lock",
## "marks" (mastery: n of `total` bars filled), and one outline per equipment slot ("weapon", "shield", "helm",
## "chest", "gauntlets", "legs", "ring", "relic"). `paint` draws the same marks on any other canvas item.

var kind := "pips"
var count := 0
var color := Color.WHITE
var total := 3

func _init(k: String, c: Color, n: int = 0, px: float = 14.0) -> void:
	kind = k
	color = c
	count = n
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(px * (4.1 if k == "pips" else (2.9 if k == "marks" else 1.0)), px)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _draw() -> void:
	paint(self, kind, Vector2.ZERO, size.y, color, count, total)

static func _poly(ci: CanvasItem, at: Vector2, h: float, pts: Array, c: Color, w: float, closed: bool = true) -> void:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(at + p * h)
	if closed:
		out.append(out[0])
	ci.draw_polyline(out, c, w, true)

## Draws mark `k` with its top-left corner at `at`, `h` pixels tall.
static func paint(ci: CanvasItem, k: String, at: Vector2, h: float, color: Color, count: int = 0, total: int = 3) -> void:
	var w := maxf(1.4, h * 0.07)
	match k:
		"pips":
			for i in 5:
				var c := at + Vector2(h * 0.4 + i * h * 0.8, h * 0.5)
				var r := h * 0.34
				var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
				if i < count:
					ci.draw_colored_polygon(pts, color)
				else:
					pts.append(pts[0])
					ci.draw_polyline(pts, Color(color, 0.35), 1.0, true)
		"marks":
			for i in total:
				var r := Rect2(at + Vector2(i * h * 0.95, h * 0.12), Vector2(h * 0.7, h * 0.76))
				if i < count:
					ci.draw_rect(r, color)
				else:
					ci.draw_rect(r, Color(color, 0.4), false, 1.2)
		"up":
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(h * 0.5, h * 0.12), at + Vector2(h * 0.95, h * 0.85), at + Vector2(h * 0.05, h * 0.85)]), color)
		"down":
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(h * 0.05, h * 0.15), at + Vector2(h * 0.95, h * 0.15), at + Vector2(h * 0.5, h * 0.88)]), color)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + i * PI / 5.0
				pts.append(at + Vector2(h * 0.5, h * 0.52) + Vector2(cos(a), sin(a)) * h * (0.5 if i % 2 == 0 else 0.21))
			if count > 0:
				ci.draw_colored_polygon(pts, color)
			else:
				pts.append(pts[0])
				ci.draw_polyline(pts, color, 1.2, true)
		"lock":
			ci.draw_rect(Rect2(at + Vector2(h * 0.18, h * 0.45), Vector2(h * 0.64, h * 0.5)), color)
			ci.draw_arc(at + Vector2(h * 0.5, h * 0.45), h * 0.22, PI, TAU, 10, color, maxf(1.6, h * 0.09), true)
		"weapon":
			ci.draw_line(at + Vector2(0.2, 0.8) * h, at + Vector2(0.88, 0.12) * h, color, w * 1.5, true)
			ci.draw_line(at + Vector2(0.2, 0.52) * h, at + Vector2(0.48, 0.8) * h, color, w * 1.3, true)
			ci.draw_line(at + Vector2(0.08, 0.92) * h, at + Vector2(0.26, 0.74) * h, color, w * 2.2, true)
		"shield":
			_poly(ci, at, h, [Vector2(0.14, 0.1), Vector2(0.86, 0.1), Vector2(0.86, 0.5), Vector2(0.5, 0.95), Vector2(0.14, 0.5)], color, w)
			ci.draw_line(at + Vector2(0.5, 0.1) * h, at + Vector2(0.5, 0.95) * h, Color(color, 0.6), w * 0.7, true)
		"helm":
			ci.draw_arc(at + Vector2(0.5, 0.5) * h, h * 0.36, PI, TAU, 14, color, w, true)
			_poly(ci, at, h, [Vector2(0.14, 0.5), Vector2(0.14, 0.9), Vector2(0.4, 0.9), Vector2(0.5, 0.74), Vector2(0.6, 0.9), Vector2(0.86, 0.9), Vector2(0.86, 0.5)], color, w, false)
			ci.draw_line(at + Vector2(0.3, 0.56) * h, at + Vector2(0.7, 0.56) * h, color, w * 1.3, true)
		"chest":
			_poly(ci, at, h, [Vector2(0.3, 0.08), Vector2(0.42, 0.2), Vector2(0.58, 0.2), Vector2(0.7, 0.08), Vector2(0.92, 0.24), Vector2(0.8, 0.44),
				Vector2(0.76, 0.92), Vector2(0.24, 0.92), Vector2(0.2, 0.44), Vector2(0.08, 0.24)], color, w)
			ci.draw_line(at + Vector2(0.5, 0.3) * h, at + Vector2(0.5, 0.9) * h, Color(color, 0.6), w * 0.7, true)
		"gauntlets":
			_poly(ci, at, h, [Vector2(0.3, 0.95), Vector2(0.3, 0.6), Vector2(0.2, 0.34), Vector2(0.34, 0.3), Vector2(0.4, 0.44), Vector2(0.4, 0.1),
				Vector2(0.78, 0.1), Vector2(0.78, 0.6), Vector2(0.7, 0.95)], color, w)
			ci.draw_line(at + Vector2(0.3, 0.68) * h, at + Vector2(0.76, 0.68) * h, Color(color, 0.6), w * 0.7, true)
		"legs":
			_poly(ci, at, h, [Vector2(0.34, 0.05), Vector2(0.66, 0.05), Vector2(0.62, 0.7), Vector2(0.9, 0.84), Vector2(0.9, 0.95), Vector2(0.3, 0.95), Vector2(0.38, 0.6)], color, w)
			ci.draw_line(at + Vector2(0.36, 0.3) * h, at + Vector2(0.65, 0.3) * h, Color(color, 0.6), w * 0.7, true)
		"ring":
			ci.draw_arc(at + Vector2(0.5, 0.6) * h, h * 0.3, 0, TAU, 20, color, w * 1.2, true)
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0.5, 0.06) * h, at + Vector2(0.64, 0.22) * h, at + Vector2(0.5, 0.38) * h, at + Vector2(0.36, 0.22) * h]), color)
		"relic":
			_poly(ci, at, h, [Vector2(0.5, 0.05), Vector2(0.84, 0.4), Vector2(0.5, 0.95), Vector2(0.16, 0.4)], color, w)
			_poly(ci, at, h, [Vector2(0.16, 0.4), Vector2(0.5, 0.52), Vector2(0.84, 0.4)], Color(color, 0.6), w * 0.7, false)
			ci.draw_line(at + Vector2(0.5, 0.52) * h, at + Vector2(0.5, 0.95) * h, Color(color, 0.6), w * 0.7, true)
		"shoulders":
			ci.draw_arc(at + Vector2(0.5, 0.62) * h, h * 0.42, PI, TAU, 16, color, w, true)
			ci.draw_arc(at + Vector2(0.5, 0.62) * h, h * 0.26, PI, TAU, 12, Color(color, 0.6), w * 0.7, true)
			_poly(ci, at, h, [Vector2(0.08, 0.62), Vector2(0.14, 0.9), Vector2(0.86, 0.9), Vector2(0.92, 0.62)], color, w, false)
		"boots":
			_poly(ci, at, h, [Vector2(0.3, 0.06), Vector2(0.62, 0.06), Vector2(0.6, 0.58), Vector2(0.92, 0.76), Vector2(0.92, 0.94), Vector2(0.26, 0.94)], color, w)
			ci.draw_line(at + Vector2(0.26, 0.8) * h, at + Vector2(0.92, 0.8) * h, Color(color, 0.6), w * 0.7, true)
		"keen":
			# a whetted edge: a blade's point with a glint off it
			_poly(ci, at, h, [Vector2(0.12, 0.92), Vector2(0.3, 0.4), Vector2(0.78, 0.08), Vector2(0.5, 0.62)], color, w)
			ci.draw_line(at + Vector2(0.66, 0.5) * h, at + Vector2(0.94, 0.5) * h, color, w, true)
			ci.draw_line(at + Vector2(0.8, 0.36) * h, at + Vector2(0.8, 0.64) * h, color, w, true)
