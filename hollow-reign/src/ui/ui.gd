class_name UI
extends RefCounted
## Shared look for every screen: colours, type, and small widget factories.

const GOLD := Color("#b89b5e")
const GOLD_DIM := Color("#6e5d3a")
const BONE := Color("#d8d2c4")
const DIM := Color("#8a857a")
const BLOOD := Color("#8a1f1f")
const INK := Color("#0b0b0d")
const PANEL := Color(0.045, 0.045, 0.055, 0.92)
const STAMINA := Color("#6f8f5a")
const FROST := Color("#7fd4ff")

static var _fonts := {}

static func font(kind: String) -> Font:
	if not _fonts.has(kind):
		var path: String = {
			"title": "res://assets/fonts/cinzel-latin-700-normal.woff2",
			"head": "res://assets/fonts/cinzel-latin-400-normal.woff2",
			"body": "res://assets/fonts/eb-garamond-latin-400-normal.woff2",
			"bold": "res://assets/fonts/eb-garamond-latin-600-normal.woff2",
		}[kind]
		_fonts[kind] = load(path)
	return _fonts[kind]

static func label(text: String, size: int = 22, color: Color = BONE, kind: String = "body") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func title(text: String, size: int = 30, color: Color = GOLD) -> Label:
	var l := label(text.to_upper(), size, color, "head")
	return l

static func box(bg: Color = PANEL, border: Color = GOLD_DIM, width: int = 1, radius: int = 2, pad: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s

static func panel(bg: Color = PANEL, border: Color = GOLD_DIM) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border))
	return p

static func button(text: String, size: int = 22, min_w: float = 240.0) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.add_theme_font_override("font", font("head"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", BONE)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.35, 0.34, 0.32))
	b.add_theme_stylebox_override("normal", box(Color(0.06, 0.06, 0.07, 0.85), GOLD_DIM, 1, 2, 12))
	b.add_theme_stylebox_override("hover", box(Color(0.1, 0.09, 0.08, 0.9), GOLD, 1, 2, 12))
	b.add_theme_stylebox_override("pressed", box(Color(0.16, 0.13, 0.08, 0.95), GOLD, 2, 2, 12))
	b.add_theme_stylebox_override("disabled", box(Color(0.04, 0.04, 0.045, 0.7), Color(0.2, 0.2, 0.2), 1, 2, 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(min_w, 52)
	b.pressed.connect(func(): Sfx.play("ui_tap", -6.0))
	return b

static func bar(color: Color, height: float = 10.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.65)
	bg.border_color = Color(0.3, 0.27, 0.2, 0.9)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_border_width_all(1)
	fg.border_color = Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

static func rule(color: Color = GOLD_DIM) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func spacer(h: float = 10.0, w: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

## Margins that keep content clear of the notch / home indicator.
static func safe_margins(vp: Viewport) -> Dictionary:
	var out := {"l": 24.0, "r": 24.0, "t": 16.0, "b": 16.0}
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or not OS.has_feature("mobile"):
		return out
	var safe := DisplayServer.get_display_safe_area()
	var k: float = vp.get_visible_rect().size.x / float(win.x)
	out.l = maxf(out.l, safe.position.x * k + 8.0)
	out.t = maxf(out.t, safe.position.y * k + 8.0)
	out.r = maxf(out.r, (win.x - safe.end.x) * k + 8.0)
	out.b = maxf(out.b, (win.y - safe.end.y) * k + 8.0)
	return out

static func margin(vp: Viewport, extra: float = 0.0) -> MarginContainer:
	var m := MarginContainer.new()
	var s := safe_margins(vp)
	m.add_theme_constant_override("margin_left", int(s.l + extra))
	m.add_theme_constant_override("margin_right", int(s.r + extra))
	m.add_theme_constant_override("margin_top", int(s.t + extra))
	m.add_theme_constant_override("margin_bottom", int(s.b + extra))
	full(m)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m
