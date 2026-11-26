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
# the rest of the palette: blackened steel, silver, charcoal, muted crimson, parchment and ink for the map
const STEEL := Color("#14151a")
const STEEL_LIGHT := Color("#2b2d35")
const SILVER := Color("#b9bcc4")
const CHARCOAL := Color("#0d0e11")
const CRIMSON := Color("#7a2626")
const PARCHMENT := Color("#c9b98f")
const MAP_INK := Color("#33281a")

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
	l.add_theme_font_size_override("font_size", maxi(size, 16))
	l.add_theme_color_override("font_color", color)
	# a soft shadow keeps text readable over bright daylight scenes
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 4)
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
	b.add_theme_font_size_override("font_size", maxi(size, 15))
	b.add_theme_color_override("font_color", BONE)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.35, 0.34, 0.32))
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, _button_box(state))
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

# ================================================================ theme
static var _theme: Theme
static var _button_boxes := {}

## Steel plate with a thin metal edge: dim gold at rest, bright on touch, a pale top line like a bevel.
static func _button_box(state: String) -> StyleBox:
	if _button_boxes.is_empty():
		var n := box(Color(0.075, 0.078, 0.092, 0.9), GOLD_DIM, 1, 1, 12)
		n.border_color = Color(GOLD_DIM, 0.9)
		n.shadow_color = Color(0, 0, 0, 0.35)
		n.shadow_size = 3
		var h := box(Color(0.12, 0.115, 0.11, 0.94), GOLD, 1, 1, 12)
		h.shadow_color = Color(GOLD, 0.12)
		h.shadow_size = 6
		var p := box(Color(0.17, 0.14, 0.09, 0.96), GOLD, 1, 1, 12)
		p.content_margin_top = 13
		p.content_margin_bottom = 11
		var d := box(Color(0.05, 0.05, 0.056, 0.7), Color(0.2, 0.2, 0.21), 1, 1, 12)
		_button_boxes = {"normal": n, "hover": h, "pressed": p, "disabled": d, "focus": StyleBoxEmpty.new()}
	return _button_boxes[state]

## The one theme. Set on the root window so every Control inherits it; the factories above stay consistent with it.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 20
	# --- text
	t.set_color("font_color", "Label", BONE)
	t.set_font("normal_font", "RichTextLabel", font("body"))
	t.set_font("bold_font", "RichTextLabel", font("bold"))
	t.set_color("default_color", "RichTextLabel", BONE)
	t.set_font_size("normal_font_size", "RichTextLabel", 19)
	# --- buttons
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "Button", _button_box(state))
	t.set_font("font", "Button", font("head"))
	t.set_font_size("font_size", "Button", 20)
	t.set_color("font_color", "Button", BONE)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", BONE)
	t.set_color("font_disabled_color", "Button", Color(0.35, 0.34, 0.32))
	# --- panels
	var pb := box(PANEL, GOLD_DIM)
	pb.shadow_color = Color(0, 0, 0, 0.45)
	pb.shadow_size = 10
	t.set_stylebox("panel", "PanelContainer", pb)
	t.set_stylebox("panel", "Panel", pb)
	var tip := box(Color(0.03, 0.03, 0.035, 0.96), GOLD_DIM, 1, 1, 8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", BONE)
	# --- slider: a thin dark channel, a gold fill, a diamond to hold
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.7)
	track.border_color = Color(STEEL_LIGHT, 0.9)
	track.set_border_width_all(1)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD_DIM.lerp(GOLD, 0.45)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _diamond(22, GOLD, INK))
	t.set_icon("grabber_highlight", "HSlider", _diamond(26, GOLD.lightened(0.25), INK))
	t.set_icon("grabber_disabled", "HSlider", _diamond(22, DIM, INK))
	# --- scrolling: a hairline, not a bar
	for cls: String in ["VScrollBar", "HScrollBar"]:
		var rail := StyleBoxFlat.new()
		rail.bg_color = Color(1, 1, 1, 0.04)
		rail.set_content_margin_all(2)
		var grab := StyleBoxFlat.new()
		grab.bg_color = Color(GOLD_DIM, 0.85)
		grab.set_corner_radius_all(2)
		var grab_h: StyleBoxFlat = grab.duplicate()
		grab_h.bg_color = GOLD
		t.set_stylebox("scroll", cls, rail)
		t.set_stylebox("grabber", cls, grab)
		t.set_stylebox("grabber_highlight", cls, grab_h)
		t.set_stylebox("grabber_pressed", cls, grab_h)
	# --- text entry
	var le := box(Color(0.03, 0.03, 0.036, 0.9), GOLD_DIM, 1, 1, 10)
	var le_f := box(Color(0.045, 0.043, 0.04, 0.95), GOLD, 1, 1, 10)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le_f)
	t.set_color("font_color", "LineEdit", BONE)
	t.set_color("font_placeholder_color", "LineEdit", Color(DIM, 0.7))
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(GOLD_DIM, 0.6))
	t.set_font("font", "LineEdit", font("body"))
	t.set_font_size("font_size", "LineEdit", 21)
	# --- bars and rules
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.65)
	bar_bg.border_color = Color(0.3, 0.27, 0.2, 0.9)
	bar_bg.set_border_width_all(1)
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = GOLD
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	var sep := StyleBoxLine.new()
	sep.color = GOLD_DIM
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	_theme = t
	return t

static var _applied := false

## Makes the theme the game's default, once. Controls under a CanvasLayer do not inherit a theme from the root
## window, so as well as being set there it is merged into the engine's default theme, which every Control falls
## back to wherever it sits in the tree. Safe to call from every screen.
static func apply(node: Node) -> void:
	if not _applied:
		_applied = true
		ThemeDB.get_default_theme().merge_with(theme())
	if node.is_inside_tree() and node.get_tree().root.theme != theme():
		node.get_tree().root.theme = theme()

static func _diamond(size: int, fill: Color, edge: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := absf(x - c) + absf(y - c)
			if d <= c - 2.0:
				img.set_pixel(x, y, fill)
			elif d <= c:
				img.set_pixel(x, y, edge)
	return ImageTexture.create_from_image(img)

# ================================================================ motion
## 0 when the player asked for reduced motion: slides become plain fades and drifts stop.
static func motion() -> float:
	return 0.0 if bool(Game.settings.get("reduce_motion", false)) else 1.0

static func fade_in(c: CanvasItem, time: float = 0.35, delay: float = 0.0) -> Tween:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, time).set_delay(delay).set_trans(Tween.TRANS_SINE)
	return tw

static func fade_out(c: CanvasItem, time: float = 0.25, then: Callable = Callable()) -> Tween:
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 0.0, time).set_trans(Tween.TRANS_SINE)
	if then.is_valid():
		tw.tween_callback(then)
	return tw

## Fade in while settling from a small offset. For full-rect layers, not for children of containers.
static func slide_in(c: Control, from: Vector2 = Vector2(-28, 0), time: float = 0.45, delay: float = 0.0) -> Tween:
	var tw := fade_in(c, time * 0.8, delay)
	if motion() > 0.0:
		c.position += from
		tw.parallel().tween_property(c, "position", c.position - from, time).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw

## Children of a container appear one after another.
static func stagger(parent: Node, step: float = 0.06, time: float = 0.3, delay: float = 0.0) -> void:
	var i := 0
	for c in parent.get_children():
		if c is CanvasItem and c.visible:
			fade_in(c, time, delay + step * i)
			i += 1

# ================================================================ shared pieces
## A rule with a small diamond at its centre.
static func ornament(width: float = 260.0, color: Color = GOLD_DIM) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 12)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var w := c.size.x
		var y := c.size.y * 0.5
		var mid := w * 0.5
		c.draw_line(Vector2(0, y), Vector2(mid - 10, y), color, 1.0)
		c.draw_line(Vector2(mid + 10, y), Vector2(w, y), color, 1.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(mid, y - 4), Vector2(mid + 4, y), Vector2(mid, y + 4), Vector2(mid - 4, y)]), color.lightened(0.2)))
	return c

## Gold corner marks drawn over a panel, the way a plate is pinned at its corners.
static func corners(target: Control, color: Color = GOLD, arm: float = 14.0) -> void:
	var c := full(Control.new())
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(c)
	c.draw.connect(func():
		# the marks sit on the panel's edge, outside its padding
		var g := Vector2(9, 9)
		var s := c.size + g
		for p: Array in [[-g, 1, 1], [Vector2(s.x, -g.y), -1, 1], [Vector2(-g.x, s.y), 1, -1], [s, -1, -1]]:
			var o: Vector2 = p[0]
			c.draw_line(o, o + Vector2(arm * p[1], 0), color, 2.0)
			c.draw_line(o, o + Vector2(0, arm * p[2]), color, 2.0))

## A quiet text entry in a list: no plate, a gold bar when touched.
static func menu_item(text: String, size: int = 22, min_w: float = 300.0) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", font("head"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", BONE)
	b.add_theme_color_override("font_hover_color", GOLD.lightened(0.15))
	b.add_theme_color_override("font_pressed_color", GOLD)
	var rest := StyleBoxFlat.new()
	rest.bg_color = Color(0, 0, 0, 0)
	rest.border_color = Color(GOLD_DIM, 0.0)
	rest.border_width_left = 2
	rest.content_margin_left = 14
	rest.content_margin_right = 14
	var hot: StyleBoxFlat = rest.duplicate()
	hot.bg_color = Color(GOLD, 0.07)
	hot.border_color = GOLD
	b.add_theme_stylebox_override("normal", rest)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", hot)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(min_w, 44)
	b.pressed.connect(func(): Sfx.play("ui_tap", -6.0))
	return b

## Wrapped body text of a set width.
static func wrapped(text: String, size: int = 19, color: Color = DIM, width: float = 0.0, kind: String = "body") -> Label:
	var l := label(text, size, color, kind)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0.0:
		l.custom_minimum_size.x = width
	return l

## Top row of a sub-screen: Back on the left, the screen's name, an optional note on the right.
static func header(text: String, on_back: Callable, note: String = "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var back := button("Back", 17, 120)
	back.custom_minimum_size.y = 44
	back.pressed.connect(on_back)
	h.add_child(back)
	var t := title(text, 30)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(t)
	var gap := spacer(0)
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(gap)
	if note != "":
		var n := label(note, 18, DIM)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(n)
	return h

## A question that must be answered before anything else. Returns the dialog so it can be dismissed.
static func confirm(host: Node, heading: String, text: String, yes: String, on_yes: Callable, no: String = "Cancel", danger: bool = false) -> Control:
	var root := full(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(root)
	var dim := full(ColorRect.new())
	dim.color = Color(0.01, 0.01, 0.015, 0.78)
	root.add_child(dim)
	var center := full(CenterContainer.new())
	root.add_child(center)
	var p := panel(Color(0.05, 0.05, 0.06, 0.98), CRIMSON.lightened(0.1) if danger else GOLD_DIM)
	p.custom_minimum_size.x = 520
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var head := title(heading, 26, BLOOD.lightened(0.3) if danger else GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	v.add_child(rule())
	var body := wrapped(text, 20, BONE, 480)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	v.add_child(spacer(4))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var n := button(no, 19, 200)
	n.pressed.connect(root.queue_free)
	row.add_child(n)
	var y := button(yes, 19, 200)
	if danger:
		y.add_theme_color_override("font_color", BLOOD.lightened(0.35))
	y.pressed.connect(func():
		root.queue_free()
		on_yes.call())
	row.add_child(y)
	fade_in(root, 0.2)
	return root

## Left-to-right darkening so text reads over a bright scene.
static func shade(strength: float = 0.8, reach: float = 0.62) -> TextureRect:
	var r: TextureRect = full(TextureRect.new())
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.01, 0.015, strength))
	g.set_color(1, Color(0.01, 0.01, 0.015, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(reach, 0)
	r.texture = gt
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Darkened edges.
static func vignette(strength: float = 0.7) -> TextureRect:
	var r: TextureRect = full(TextureRect.new())
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, strength))
	g.set_offset(0, 0.45)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	r.texture = gt
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"][clampi(n, 0, 12)]

## "3 h 12 min" from seconds.
static func playtime(seconds: float) -> String:
	var m := int(seconds / 60.0)
	if m < 60:
		return "%d min" % m
	return "%d h %02d min" % [m / 60, m % 60]

## "today", "yesterday", "5 days ago", or a date.
static func when(unix: float) -> String:
	if unix <= 0.0:
		return "unknown"
	var now := Time.get_unix_time_from_system()
	var days := int(floor(now / 86400.0)) - int(floor(unix / 86400.0))
	if days <= 0:
		return "today"
	if days == 1:
		return "yesterday"
	if days < 30:
		return "%d days ago" % days
	var d := Time.get_date_dict_from_unix_time(int(unix))
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]
