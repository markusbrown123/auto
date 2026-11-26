class_name DuelHud
extends CanvasLayer
## Combat interface: deliberately sparse so the eye stays on the enemy.

signal dodge(side: int)
signal block(down: bool)
signal swipe(dir: String, vec: Vector2)
signal pause_pressed
signal surge_pressed
signal relic_pressed

## A multi-touch aware round button (hold or tap).
class Pad extends Control:
	signal down
	signal up
	var icon := "left"
	var held := false
	var charge := -1.0        # 0..1 draws a filling ring (surge and relic); -1 = plain button
	var tint := UI.GOLD
	var _idx := -1
	var glow := 0.0           # 1 while pressed, fades after release
	## Lesson only: "" or how this pad is being demonstrated: "tap", "hold" (ring fills while held), "double" (two pulses, x2).
	var teach := ""
	var _teach_t := 0.0
	var _hold_t := 0.0
	const HOLD_FULL := 0.7
	## The shield pad only: how many blows the shield will still stop (`pips_left` of `pips`), drawn as small
	## diamonds over the pad so they fade with it. `notice` lights the pad for a moment when the count changes.
	var pips := 0
	var pips_left := 0
	var notice := 0.0
	var _pip_t := 9.0         # seconds since the count last changed
	var _pip_at := -1         # the pip that changed
	var _pip_gain := false
	var _hit_t := 9.0         # seconds since a blow landed on a spent shield
	func set_pips(left: int, of: int, struck_spent: bool = false, quiet: bool = false) -> void:
		var was := pips_left
		pips = of
		pips_left = clampi(left, 0, of)
		if not quiet and pips_left != was:
			_pip_gain = pips_left > was
			_pip_at = pips_left - 1 if _pip_gain else pips_left
			_pip_t = 0.0
			notice = 1.0
		if struck_spent and not quiet:
			_hit_t = 0.0
			notice = 1.0
		queue_redraw()
	func _process(dt: float) -> void:
		# near-invisible at rest, fully lit under the thumb, fading back afterwards
		glow = 1.0 if held else maxf(0.0, glow - dt * 2.2)
		if pips > 0:
			_pip_t += dt
			_hit_t += dt
			# a change is held bright for a moment, then lets go; a spent shield never quite goes dark
			notice = maxf(0.0, notice - dt * 0.8)
			glow = maxf(glow, minf(1.0, notice * 1.6))
			if pips_left == 0:
				glow = maxf(glow, 0.45)
		var rest: float = float(Game.settings.get("pad_opacity", 0.2))
		if charge >= 1.0:
			rest = maxf(rest, 0.8)      # a full burst or flame announces itself
		if teach != "":
			# being taught: fully lit whatever the pad-opacity setting says
			_teach_t += dt
			_hold_t = _hold_t + dt if held else 0.0
			modulate.a = 1.0
			queue_redraw()
			return
		var a := lerpf(rest, 1.0, glow * glow * (3.0 - 2.0 * glow))
		if not is_equal_approx(a, modulate.a) or glow > 0.0:
			modulate.a = a
			queue_redraw()
	func _init(kind: String, diameter: float) -> void:
		icon = kind
		custom_minimum_size = Vector2(diameter, diameter)
		size = custom_minimum_size
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch:
			if e.pressed and _idx < 0:
				_idx = e.index
				held = true
				down.emit()
				queue_redraw()
			elif not e.pressed and e.index == _idx:
				release()
			accept_event()
		elif e is InputEventScreenDrag:
			accept_event()
	func release() -> void:
		if _idx >= 0:
			_idx = -1
			held = false
			up.emit()
			queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5 - 2.0
		var broken: bool = pips > 0 and pips_left == 0
		draw_circle(c, r, Color(0.04, 0.04, 0.05, 0.62 if not held else 0.85))
		draw_arc(c, r, 0, TAU, 48, (UI.CRIMSON.lightened(0.25) if broken else (UI.GOLD if held else UI.GOLD_DIM)), 2.0, true)
		if pips > 0:
			_draw_pips(c, r, broken)
		if glow > 0.0 and not broken:
			draw_arc(c, r - 3.0, 0, TAU, 48, Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, 0.45 * glow), 6.0, true)
			draw_circle(c, r - 6.0, Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, 0.12 * glow))
		if teach != "":
			_draw_teach(c, r)
		var col := UI.GOLD if held else UI.BONE
		if broken:
			col = Color(0.5, 0.42, 0.4)
		if charge >= 0.0:
			var full := charge >= 1.0
			col = tint if full else Color(0.45, 0.44, 0.42)
			draw_arc(c, r - 5.0, -PI / 2, -PI / 2 + TAU * clampf(charge, 0.0, 1.0), 48, tint, 5.0 if full else 3.5, true)
			if full:
				draw_circle(c, r - 12.0, Color(tint.r, tint.g, tint.b, 0.16 + 0.1 * sin(Time.get_ticks_msec() / 160.0)))
		var s := r * 0.42
		match icon:
			"left", "right":
				var k := -1.0 if icon == "left" else 1.0
				for off: float in [-0.22, 0.22]:
					var o := c + Vector2(off * r * k + k * s * 0.15, 0)
					draw_polyline(PackedVector2Array([o + Vector2(-k * s * 0.5, -s), o + Vector2(k * s * 0.5, 0), o + Vector2(-k * s * 0.5, s)]), col, 3.0, true)
			"surge":
				# a burst: eight short rays
				for i in 8:
					var a := TAU * i / 8.0
					var d := Vector2(cos(a), sin(a))
					draw_line(c + d * s * 0.35, c + d * s * (1.1 if i % 2 == 0 else 0.8), col, 3.0, true)
			"relic":
				# a flame-shaped drop
				draw_polyline(PackedVector2Array([c + Vector2(0, -s * 1.2), c + Vector2(s * 0.7, s * 0.2), c + Vector2(0, s * 1.0), c + Vector2(-s * 0.7, s * 0.2), c + Vector2(0, -s * 1.2)]), col, 3.0, true)
				draw_line(c + Vector2(0, -s * 0.2), c + Vector2(0, s * 0.5), col, 2.0, true)
				draw_line(c + Vector2(-s * 0.3, s * 0.15), c + Vector2(s * 0.3, s * 0.15), col, 2.0, true)
			"shield":
				var pts := PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(s, s * 0.2), c + Vector2(0, s * 1.25), c + Vector2(-s, s * 0.2), c + Vector2(-s, -s)])
				draw_polyline(pts, col, 3.0, true)
				if broken:
					# spent: a crack down the face instead of the boss line
					var crack := UI.CRIMSON.lightened(0.35)
					draw_polyline(PackedVector2Array([c + Vector2(s * 0.25, -s), c + Vector2(-s * 0.2, -s * 0.35), c + Vector2(s * 0.22, s * 0.05), c + Vector2(-s * 0.12, s * 0.55), c + Vector2(0, s * 1.2)]), crack, 2.5, true)
					draw_line(c + Vector2(-s * 0.2, -s * 0.35), c + Vector2(-s * 0.7, -s * 0.15), crack, 2.0, true)
				else:
					draw_line(c + Vector2(0, -s), c + Vector2(0, s * 1.2), col, 1.5, true)

	## The blows the shield will still stop: diamonds on an arc over the pad. A used one is an outline; one coming
	## back swells into place; the one just lost flares and empties. With reduced motion they simply change.
	func _draw_pips(c: Vector2, r: float, broken: bool) -> void:
		var still: bool = bool(Game.settings.get("reduce_motion", false))
		var step := 0.3
		var a0 := -PI * 0.5 - step * (pips - 1) * 0.5
		var shake := Vector2.ZERO
		if _hit_t < 0.3 and not still:
			shake = Vector2(sin(_hit_t * 70.0) * 3.0 * (1.0 - _hit_t / 0.3), 0)
		for i in pips:
			var a := a0 + step * i
			var at := c + Vector2(cos(a), sin(a)) * (r + 13.0) + shake
			var d := 6.5
			var full := i < pips_left
			var col := UI.BONE.lerp(UI.GOLD, 0.45)
			if i == _pip_at and _pip_t < 0.45 and not still:
				var u := _pip_t / 0.45
				if _pip_gain:
					d *= lerpf(1.9, 1.0, u * u * (3.0 - 2.0 * u))
					col = Color.WHITE.lerp(col, u)
				else:
					# the lost one: a white flare that empties
					draw_circle(at, d * (1.0 + 1.6 * u), Color(1, 1, 1, 0.35 * (1.0 - u)))
			var pts := PackedVector2Array([at + Vector2(0, -d), at + Vector2(d, 0), at + Vector2(0, d), at + Vector2(-d, 0)])
			if full:
				draw_colored_polygon(pts, col)
			else:
				draw_colored_polygon(pts, Color(0.03, 0.03, 0.04, 0.7))
				pts.append(pts[0])
				draw_polyline(pts, UI.CRIMSON.lightened(0.3) if broken else Color(0.6, 0.57, 0.5, 0.8), 1.5, true)

	## The demonstration around a pad: a pulsing ring, plus a filling ring for "hold" or a double pulse and "x2" for a roll.
	func _draw_teach(c: Vector2, r: float) -> void:
		var hot := Color(1.0, 0.92, 0.6)
		var font := UI.font("title")
		draw_circle(c, r - 3.0, Color(hot.r, hot.g, hot.b, 0.16))
		draw_arc(c, r, 0, TAU, 64, hot, 3.0, true)
		var word := "TAP"
		match teach:
			"hold":
				word = "HOLD"
				var u := fmod(_teach_t, 1.1) / 1.1
				if not held:
					draw_arc(c, r + 6.0 + 16.0 * u, 0, TAU, 64, Color(hot.r, hot.g, hot.b, 0.9 * (1.0 - u)), 4.0, true)
				# the ring that fills while the thumb stays down
				draw_arc(c, r + 12.0, 0, TAU, 64, Color(0, 0, 0, 0.55), 9.0, true)
				draw_arc(c, r + 12.0, -PI / 2, -PI / 2 + TAU * clampf(_hold_t / HOLD_FULL, 0.0, 1.0), 64, Color("#8fe39a") if _hold_t >= HOLD_FULL else hot, 7.0, true)
			"double":
				word = "TAP ×2"
				# two quick pulses, a short rest, and again
				var t := fmod(_teach_t, 1.0)
				for start: float in [0.0, 0.28]:
					var u2 := (t - start) / 0.24
					if u2 >= 0.0 and u2 <= 1.0:
						draw_arc(c, r + 4.0 + 22.0 * u2, 0, TAU, 64, Color(hot.r, hot.g, hot.b, 1.0 - u2), 6.0, true)
						draw_circle(c, r - 3.0, Color(hot.r, hot.g, hot.b, 0.35 * (1.0 - u2)))
			_:
				var u3 := fmod(_teach_t, 0.9) / 0.9
				draw_arc(c, r + 6.0 + 18.0 * u3, 0, TAU, 64, Color(hot.r, hot.g, hot.b, 0.9 * (1.0 - u3)), 4.0, true)
		var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var at := c + Vector2(-w * 0.5, -r - 30.0)
		draw_string_outline(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 8, Color(0, 0, 0, 0.85))
		draw_string(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, hot)

## Blade struggle: one large temporary target. A touch anywhere in its area is a tap.
class Struggle extends Control:
	signal tapped
	var need := 1
	var n := 0
	var total := 1.0
	var left := 0.0
	var active := false
	var _kick := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
	func begin(need_taps: int, time: float) -> void:
		need = maxi(1, need_taps)
		n = 0
		total = time
		left = time
		active = true
		visible = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		queue_redraw()
	func progress(taps: int) -> void:
		n = taps
		_kick = 1.0
		queue_redraw()
	func finish() -> void:
		active = false
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _gui_input(e: InputEvent) -> void:
		if not active:
			return
		if e is InputEventScreenTouch:
			if e.pressed:
				tapped.emit()
			accept_event()
		elif e is InputEventScreenDrag:
			accept_event()
	func _process(dt: float) -> void:
		if active:
			left = maxf(0.0, left - dt)
			_kick = maxf(0.0, _kick - dt * 7.0)
			queue_redraw()
	func _draw() -> void:
		if not active:
			return
		var c := size * Vector2(0.5, 0.6)
		var r := minf(size.x, size.y) * 0.17 + 8.0 * _kick
		var hot := Color(1.0, 0.9, 0.58)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 70.0)
		draw_circle(c, r, Color(0.03, 0.03, 0.04, 0.5))
		draw_circle(c, r - 14.0, Color(hot.r, hot.g, hot.b, 0.08 + 0.14 * _kick))
		# time left: a pale ring that runs out
		draw_arc(c, r + 12.0, -PI / 2, -PI / 2 + TAU * clampf(left / maxf(total, 0.01), 0.0, 1.0), 72, Color(1, 1, 1, 0.75), 3.0, true)
		# progress: a thick ring that fills with each tap
		draw_arc(c, r, 0, TAU, 72, Color(0, 0, 0, 0.6), 13.0, true)
		draw_arc(c, r, -PI / 2, -PI / 2 + TAU * clampf(float(n) / float(need), 0.0, 1.0), 72, hot, 10.0, true)
		draw_arc(c, r - 12.0 - 5.0 * pulse, 0, TAU, 72, Color(hot.r, hot.g, hot.b, 0.35 + 0.4 * pulse), 2.0, true)
		var font := UI.font("title")
		var fs := int(r * 0.52)
		var w := font.get_string_size("TAP", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := c + Vector2(-w * 0.5, fs * 0.36)
		draw_string_outline(font, at, "TAP", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.85))
		draw_string(font, at, "TAP", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1).lerp(hot, 1.0 - _kick))

## The parry / dodge prompt with a closing timing ring.
class Cue extends Control:
	var vec := Vector2.RIGHT
	var kind := ""           # "", "parry", "dodge"
	var dodge_side := "any"
	var danger := false
	var total := 1.0
	var left := 0.0
	func show_cue(k: String, v: Vector2, side: String, red: bool, windup: float) -> void:
		kind = k
		vec = v
		dodge_side = side
		danger = red
		total = windup
		left = windup
		queue_redraw()
	func clear() -> void:
		kind = ""
		queue_redraw()
	func _process(dt: float) -> void:
		if kind != "":
			left -= dt
			if left < -0.15:
				kind = ""
			queue_redraw()
	func _draw() -> void:
		if kind == "":
			return
		var c := size * 0.5
		var col := Color("#d23a2a") if danger else UI.GOLD
		var u := clampf(left / maxf(total, 0.01), 0.0, 1.0)
		var near := left < 0.3
		var a := 0.4 if not near else 0.95
		col.a = a
		var r0 := 24.0
		draw_arc(c, r0, 0, TAU, 40, Color(col.r, col.g, col.b, a * 0.5), 2.0, true)
		draw_arc(c, r0 + 46.0 * u, 0, TAU, 48, col, 2.5 if not near else 4.0, true)
		if kind == "parry":
			var d := Vector2(vec.x, -vec.y)
			var tip := c + d * 22.0
			var tail := c - d * 22.0
			var n := Vector2(-d.y, d.x)
			draw_line(tail, tip, col, 5.0, true)
			draw_polyline(PackedVector2Array([tip - d * 14.0 + n * 12.0, tip, tip - d * 14.0 - n * 12.0]), col, 5.0, true)
		else:
			for k: float in [-1.0, 1.0]:
				if (dodge_side == "L" and k > 0) or (dodge_side == "R" and k < 0):
					continue
				var o := c + Vector2(k * 10.0, 0)
				draw_polyline(PackedVector2Array([o + Vector2(-k * 7.0, -13.0), o + Vector2(k * 7.0, 0), o + Vector2(-k * 7.0, 13.0)]), col, 5.0, true)
			if dodge_side == "none":
				draw_line(c + Vector2(-14, -14), c + Vector2(14, 14), col, 5.0, true)
				draw_line(c + Vector2(14, -14), c + Vector2(-14, 14), col, 5.0, true)

## The seam in an open foe's guard: a glowing line to cut along.
class Rift extends Control:
	var vec := Vector2.ZERO
	var _pulse := 0.0
	var _burst := 0.0
	func show_dir(d: String) -> void:
		vec = DuelSim.dir_vec(d) if d != "" else Vector2.ZERO
		visible = d != ""
		_pulse = 0.0
		queue_redraw()
	func burst() -> void:
		_burst = 1.0
	func _process(dt: float) -> void:
		if visible:
			_pulse += dt
			_burst = maxf(0.0, _burst - dt * 4.0)
			queue_redraw()
	func _draw() -> void:
		if vec == Vector2.ZERO:
			return
		var c := size * 0.5
		var d := Vector2(vec.x, -vec.y)
		var n := Vector2(-d.y, d.x)
		var grow := minf(_pulse / 0.12, 1.0)
		var len := 58.0 * grow + _burst * 24.0      # a seam of light in the guard, not a signpost
		var a := 0.75 + 0.25 * sin(_pulse * 9.0)
		var col := Color(1.0, 0.86, 0.5, a)
		draw_line(c - d * len, c + d * len, Color(1.0, 0.6, 0.2, a * 0.18), 9.0, true)
		draw_line(c - d * len, c + d * len, col, 2.0, true)
		draw_line(c - d * len, c + d * len, Color(1, 1, 1, a), 1.5, true)
		var tip := c + d * (len + 6.0)
		draw_polyline(PackedVector2Array([tip - d * 11.0 + n * 7.0, tip, tip - d * 11.0 - n * 7.0]), col, 2.0, true)
		draw_circle(c - d * len, 2.5, col)

var root: Control
var rift: Rift
var swipe_input: SwipeInput
var boss_bar: ProgressBar
var boss_ghost: ProgressBar
var posture_bar: ProgressBar
var boss_name: Label
var hp_bar: ProgressBar
var st_bar: ProgressBar
var status_label: Label
var toast_label: Label
var sub_label: Label
var combo_label: Label
var cue: Cue
var vignette: ColorRect
var streak: Line2D
var pad_l: Pad
var pad_r: Pad
var pad_block: Pad
var pad_surge: Pad
var pad_relic: Pad
var controls: Control
var struggle: Struggle
var _struggle_cb := Callable()
var _poise_t := 0.0
var _toast_tw: Tween
var _sub_tw: Tween
var _phase_pips: HBoxContainer
var keen_mark: Control          # shown while the equipped blade's sharpened edge lasts

func _ready() -> void:
	layer = 5
	root = UI.full(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	vignette = UI.full(ColorRect.new())
	vignette.color = Color(0.5, 0.02, 0.02, 0.0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)
	swipe_input = SwipeInput.new()
	root.add_child(swipe_input)
	swipe_input.swiped.connect(func(d, v):
		swipe.emit(d, v)
		_streak())
	streak = Line2D.new()
	streak.width = 5.0
	streak.default_color = Color(1, 0.95, 0.85, 0.0)
	streak.begin_cap_mode = Line2D.LINE_CAP_ROUND
	streak.end_cap_mode = Line2D.LINE_CAP_ROUND
	var wc := Curve.new()
	wc.add_point(Vector2(0, 0.1))
	wc.add_point(Vector2(0.7, 1.0))
	wc.add_point(Vector2(1, 0.0))
	streak.width_curve = wc
	root.add_child(streak)

	# under the pads and the pause button, over the swipe area: any touch that is not on a pad is a tap
	struggle = Struggle.new()
	UI.full(struggle)
	root.add_child(struggle)
	struggle.tapped.connect(func():
		if _struggle_cb.is_valid():
			_struggle_cb.call())
	rift = Rift.new()
	rift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rift.size = Vector2(260, 260)
	rift.visible = false
	root.add_child(rift)
	var m := UI.margin(get_viewport())
	root.add_child(m)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(frame)

	# --- foe: name, health, posture
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.anchor_left = 0.27
	top.anchor_right = 0.73
	top.offset_left = 0
	top.offset_right = 0
	top.add_theme_constant_override("separation", 3)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(top)
	boss_name = UI.title("", 19, UI.BONE)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(boss_name)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, 12)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(stack)
	boss_ghost = UI.full(UI.bar(Color("#c9b27a"), 12))
	stack.add_child(boss_ghost)
	boss_bar = UI.full(UI.bar(UI.BLOOD, 12))
	boss_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	stack.add_child(boss_bar)
	# poise: full while the foe is composed, worn down by every good defence, gone when it breaks
	posture_bar = UI.bar(Color("#d5dbe2"), 5)
	posture_bar.max_value = 1.0
	posture_bar.value = 1.0
	top.add_child(posture_bar)
	_phase_pips = HBoxContainer.new()
	_phase_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	_phase_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_phase_pips)

	# --- player: health, stamina
	var pl := VBoxContainer.new()
	pl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	pl.custom_minimum_size = Vector2(250, 0)
	pl.add_theme_constant_override("separation", 4)
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(pl)
	hp_bar = UI.bar(Color("#9a2a2a"), 12)
	pl.add_child(hp_bar)
	st_bar = UI.bar(UI.STAMINA, 7)
	pl.add_child(st_bar)
	status_label = UI.label("", 16, UI.FROST, "bold")
	pl.add_child(status_label)

	# a sharpened edge: a small mark beside the bars for as long as it lasts
	var keen := HBoxContainer.new()
	keen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	keen.offset_left = 260
	keen.offset_top = -6
	keen.add_theme_constant_override("separation", 4)
	keen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keen.add_child(InvGlyph.new("keen", Color("#e8dcc0"), 0, 20.0))
	keen.add_child(UI.label("KEEN", 22, Color("#e8dcc0"), "head"))
	keen.modulate.a = 0.8
	frame.add_child(keen)
	keen_mark = keen
	set_keen(not Game.profile.is_empty() and Game.profile.equipped.get("weapon") != null and int(Game.weapon_mods(str(Game.profile.equipped.weapon)).edge) > 0)

	var pause := UI.button("II", 18, 52)
	pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause.offset_left = -52
	pause.pressed.connect(func(): pause_pressed.emit())
	frame.add_child(pause)

	# --- touch controls
	controls = Control.new()
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full(controls)
	frame.add_child(controls)
	pad_l = Pad.new("left", 104)
	pad_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pad_l.offset_top = -112
	pad_l.offset_bottom = -8
	pad_l.offset_right = 104
	controls.add_child(pad_l)
	pad_r = Pad.new("right", 104)
	pad_r.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	pad_r.offset_top = -112
	pad_r.offset_bottom = -8
	pad_r.offset_left = -104
	controls.add_child(pad_r)
	pad_block = Pad.new("shield", 104)
	pad_block.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	pad_block.offset_top = -112
	pad_block.offset_bottom = -8
	pad_block.offset_left = -52
	pad_block.offset_right = 52
	controls.add_child(pad_block)
	pad_surge = Pad.new("surge", 78)
	pad_surge.charge = 0.0
	pad_surge.tint = Color("#ffb347")
	pad_surge.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	pad_surge.offset_top = 52
	pad_surge.offset_bottom = 130
	pad_surge.offset_right = 78
	controls.add_child(pad_surge)
	pad_relic = Pad.new("relic", 78)
	pad_relic.charge = 0.0
	pad_relic.tint = Color("#7fd4ff")
	pad_relic.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	pad_relic.offset_top = 52
	pad_relic.offset_bottom = 130
	pad_relic.offset_left = 90
	pad_relic.offset_right = 168
	controls.add_child(pad_relic)
	pad_surge.down.connect(func(): surge_pressed.emit())
	pad_relic.down.connect(func(): relic_pressed.emit())
	pad_l.down.connect(func(): dodge.emit(-1))
	pad_r.down.connect(func(): dodge.emit(1))
	pad_block.down.connect(func(): block.emit(true))
	pad_block.up.connect(func(): block.emit(false))

	# --- prompts and text
	cue = Cue.new()
	cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cue.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cue.custom_minimum_size = Vector2(220, 220)
	cue.offset_left = -110
	cue.offset_right = 110
	cue.offset_top = 30
	cue.offset_bottom = 250
	frame.add_child(cue)
	toast_label = UI.title("", 30, UI.GOLD)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.anchor_left = 0.0
	toast_label.anchor_right = 1.0
	toast_label.offset_left = 0
	toast_label.offset_right = 0
	toast_label.offset_top = 96
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0
	frame.add_child(toast_label)
	combo_label = UI.title("", 24, UI.BONE)
	combo_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	combo_label.offset_left = -220
	combo_label.offset_top = -80
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	frame.add_child(combo_label)
	sub_label = UI.label("", 24, UI.BONE, "body")
	sub_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	sub_label.anchor_left = 0.12
	sub_label.anchor_right = 0.88
	sub_label.offset_left = 0
	sub_label.offset_right = 0
	sub_label.offset_top = -190
	sub_label.offset_bottom = -130
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	sub_label.add_theme_constant_override("shadow_offset_y", 2)
	sub_label.modulate.a = 0.0
	frame.add_child(sub_label)

func set_foe(foe: Dictionary) -> void:
	boss_name.text = str(foe.name).to_upper() + ("" if foe.boss else "   ·   " + str(foe.get("cls", "")).to_upper())
	for c in _phase_pips.get_children():
		c.queue_free()

func set_combat_visible(on: bool, time: float = 0.4) -> void:
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0 if on else 0.0, time)
	controls.visible = on or controls.visible
	swipe_input.mouse_filter = Control.MOUSE_FILTER_PASS if on else Control.MOUSE_FILTER_IGNORE

func set_keen(on: bool) -> void:
	keen_mark.visible = on

## The sim's `shield_charges {left, max, spent}`: the pips by the shield pad follow it. Reaching none is said once
## ("SHIELD SPENT"); a blow caught on a spent shield shakes the pad; a block coming back swells into place.
func shield_charges(d: Dictionary) -> void:
	var left := int(d.get("left", 0))
	var was := pad_block.pips_left
	pad_block.set_pips(left, int(d.get("max", 0)), bool(d.get("spent", false)))
	if left == 0 and was > 0:
		toast("SHIELD SPENT", UI.CRIMSON.lightened(0.4), 0.6)
		Game.haptic(30, 0.5)

func update_bars(sim: DuelSim, dt: float) -> void:
	if pad_block.pips != sim.p_shield_max:
		pad_block.set_pips(sim.p_shield, sim.p_shield_max, false, true)      # the fight's shield, before any blow
	boss_bar.max_value = sim.b_hp_max
	boss_bar.value = sim.b_hp
	boss_ghost.max_value = sim.b_hp_max
	boss_ghost.value = maxf(sim.b_hp, lerpf(boss_ghost.value, sim.b_hp, 1.0 - exp(-dt * 2.5)))
	_poise_t += dt
	posture_bar.max_value = 1.0
	if sim.b_state == DuelSim.B.STAGGER:
		# broken: the meter turns gold and runs down with the opening
		posture_bar.value = clampf(sim.b_t / DuelSim.STAGGER_BREAK, 0.0, 1.0)
		posture_bar.modulate = Color(1.0, 0.78, 0.3).lerp(Color(1.6, 1.4, 0.9), 0.5 + 0.5 * sin(_poise_t * 14.0))
	else:
		var f := sim.poise_frac()
		posture_bar.value = lerpf(posture_bar.value, f, 1.0 - exp(-dt * 14.0))
		# nearly gone: it warms and flickers, so a break is seen coming
		posture_bar.modulate = Color.WHITE if f > 0.35 else Color(1.0, 0.8, 0.45).lerp(Color(1.5, 1.1, 0.6), 0.5 + 0.5 * sin(_poise_t * 9.0))
	pad_surge.charge = sim.surge / DuelSim.SURGE_MAX
	pad_relic.charge = sim.relic / DuelSim.RELIC_MAX
	pad_surge.queue_redraw()
	pad_relic.queue_redraw()
	hp_bar.max_value = sim.pl.max_hp
	hp_bar.value = sim.pl.hp
	st_bar.max_value = sim.pl.max_stamina
	st_bar.value = sim.pl.stamina
	var st := ""
	if sim.p_frostbite > 0.0:
		st = "FROSTBITTEN"
	elif sim.p_frost > 30.0:
		st = "FROST " + "·".repeat(int(sim.p_frost / 25.0))
	elif sim.p_burn > 0.0:
		st = "BURNING"
	status_label.text = st
	status_label.add_theme_color_override("font_color", UI.FROST if sim.p_burn <= 0.0 or sim.p_frostbite > 0.0 else Color("#ff8a3a"))

## Blade struggle: show the one big TAP target; `on_tap` is called for every touch in its area.
func struggle_begin(need: int, time: float, on_tap: Callable) -> void:
	_struggle_cb = on_tap
	cue.clear()
	struggle.begin(need, time)

func struggle_progress(n: int) -> void:
	struggle.progress(n)

func struggle_end() -> void:
	_struggle_cb = Callable()
	struggle.finish()

## Training ground: the cuts made so far, and the name of whatever they completed.
var _train_seq: SeqView
var _train_name: Label
var _train_head: Label
func show_training() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	v.anchor_left = 0.0
	v.anchor_right = 1.0
	v.offset_top = 150
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(v)
	var head := UI.label("TRAINING GROUND  ·  cut freely, pause to leave", 15, UI.DIM)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	_train_head = head
	_train_seq = SeqView.new([], 34.0, UI.BONE)
	_train_seq.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_train_seq)
	_train_name = UI.label("", 18, UI.GOLD, "bold")
	_train_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_train_name)

## Teaching: a few big words for what to do, one plain line for why, and (for cuts) the stroke itself drawn on screen.
## Only the lesson draws a stroke; ordinary fights never do.
class LessonStroke extends Control:
	var dirs: Array = []
	var _t := 0.0
	const STEP := 1.15        # seconds per stroke: the fingertip travels, rests at the end, and starts again
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(dt: float) -> void:
		_t += dt
		if not dirs.is_empty():
			queue_redraw()
	func _draw() -> void:
		if dirs.is_empty():
			return
		var n := dirs.size()
		var cycle := fmod(_t, STEP * n)
		var i := mini(int(cycle / STEP), n - 1)
		var u := clampf((cycle - i * STEP) / 0.75, 0.0, 1.0)
		var v: Vector2 = DuelSim.dir_vec(str(dirs[i]))
		v = Vector2(v.x, -v.y).normalized()
		var c := size * Vector2(0.5, 0.56)
		var half := minf(size.x, size.y) * 0.25
		var a := c - v * half
		var z := c + v * half
		var b := a.lerp(z, ease(u, 0.5))
		var side := Vector2(-v.y, v.x)
		var col := Color(1.0, 0.9, 0.6, 0.9)
		# the whole path is always there, faintly, so the gesture is never off screen
		draw_line(a, z, Color(0, 0, 0, 0.28), 16.0, true)
		draw_line(a, z, Color(1.0, 0.86, 0.5, 0.3), 8.0, true)
		draw_colored_polygon(PackedVector2Array([z + v * 36.0, z + side * 24.0, z - side * 24.0]), Color(1.0, 0.86, 0.5, 0.45))
		# the part already drawn, bright
		draw_line(a, b, Color(1.0, 0.8, 0.4, 0.22), 34.0, true)
		draw_line(a, b, col, 9.0, true)
		draw_circle(a, 7.0, Color(1, 1, 1, 0.55))
		# a soft fingertip leading the stroke
		var press := 1.0 + 0.25 * (1.0 - clampf(u / 0.15, 0.0, 1.0))
		draw_circle(b, 34.0 * press, Color(1, 1, 1, 0.14))
		draw_circle(b, 24.0 * press, Color(1.0, 0.96, 0.86, 0.42))
		draw_arc(b, 24.0 * press, 0, TAU, 40, Color(1, 1, 1, 0.85), 2.5, true)
		draw_circle(b, 6.0, Color(1, 1, 1, 0.9))
		# which cut of the sequence this is
		if n > 1:
			for k in n:
				var o := c + Vector2((k - (n - 1) * 0.5) * 26.0, half + 62.0)
				draw_circle(o, 8.0, Color(0, 0, 0, 0.5))
				draw_circle(o, 6.0, col if k == i else Color(1, 1, 1, 0.35 if k > i else 0.6))

var _train_sub: Label
var _stroke: LessonStroke
var _demo_pads := {}
## What the lesson is demonstrating right now: {"stroke": [dirs], "pads": {"left"|"right"|"block": "tap"|"hold"|"double", "stamina": "watch"}}.
func lesson_demo() -> Dictionary:
	return {"stroke": _stroke.dirs.duplicate() if _stroke else [], "pads": _demo_pads.duplicate()}

## Take every demonstration off the screen at once (the moment the thing is done).
func lesson_demo_clear() -> void:
	_demo_pads = {}
	for p: Pad in [pad_l, pad_r, pad_block]:
		p.teach = ""
		p.queue_redraw()
	st_bar.modulate = Color.WHITE
	if _stroke:
		_stroke.dirs = []
		_stroke.queue_redraw()

func _process(_dt: float) -> void:
	if _demo_pads.has("stamina"):
		st_bar.modulate = Color.WHITE.lerp(Color(2.0, 2.0, 1.2), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 130.0))

func lesson_text(t: String, sub: String = "", stroke: Array = [], good: bool = false, pads: Dictionary = {}) -> void:
	if _train_head == null:
		return
	_train_head.text = t
	_train_head.add_theme_font_size_override("font_size", 40)
	_train_head.add_theme_color_override("font_color", Color("#8fe39a") if good else UI.GOLD)
	_train_head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_train_head.add_theme_constant_override("outline_size", 8)
	if _train_sub == null:
		_train_sub = UI.label("", 23, UI.BONE, "bold")
		_train_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_train_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_train_sub.add_theme_constant_override("outline_size", 6)
		_train_head.get_parent().add_child(_train_sub)
		_train_head.get_parent().move_child(_train_sub, _train_head.get_index() + 1)
		_stroke = LessonStroke.new()
		UI.full(_stroke)
		root.add_child(_stroke)
	_train_sub.text = sub
	lesson_demo_clear()
	_stroke.dirs = stroke
	_stroke._t = 0.0
	_stroke.queue_redraw()
	_demo_pads = pads.duplicate()
	var by_name := {"left": pad_l, "right": pad_r, "block": pad_block}
	for k: String in by_name:
		var p: Pad = by_name[k]
		p.teach = str(pads.get(k, ""))
		p._teach_t = 0.0
		p.queue_redraw()
	# a small pulse so a change of instruction is noticed
	_train_head.pivot_offset = _train_head.size * 0.5
	_train_head.scale = Vector2(1.15, 1.15)
	create_tween().tween_property(_train_head, "scale", Vector2.ONE, 0.18)

func training_cuts(cuts: Array, named: String) -> void:
	if _train_seq:
		_train_seq.show_seq(cuts)
		_train_name.text = named

func toast(text: String, color: Color = UI.GOLD, hold: float = 0.7) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	if _toast_tw:
		_toast_tw.kill()
	toast_label.modulate.a = 1.0
	toast_label.scale = Vector2(1.12, 1.12)
	toast_label.pivot_offset = toast_label.size * 0.5
	_toast_tw = create_tween()
	_toast_tw.tween_property(toast_label, "scale", Vector2.ONE, 0.12)
	_toast_tw.tween_interval(hold)
	_toast_tw.tween_property(toast_label, "modulate:a", 0.0, 0.35)

func subtitle(text: String, hold: float = 3.2) -> void:
	sub_label.text = text
	if _sub_tw:
		_sub_tw.kill()
	_sub_tw = create_tween()
	_sub_tw.tween_property(sub_label, "modulate:a", 1.0, 0.5)
	_sub_tw.tween_interval(hold)
	_sub_tw.tween_property(sub_label, "modulate:a", 0.0, 0.8)

func combo(n: int) -> void:
	combo_label.text = "" if n < 2 else "%d  HITS" % n
	combo_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(combo_label, "modulate:a", 0.0, 0.4)

func hurt_flash(strength: float = 0.5) -> void:
	if Game.settings.reduce_flash:
		strength *= 0.35
	vignette.color.a = strength
	create_tween().tween_property(vignette, "color:a", 0.0, 0.5)

func flash_stamina() -> void:
	st_bar.modulate = Color(2.2, 0.7, 0.7)
	create_tween().tween_property(st_bar, "modulate", Color.WHITE, 0.35)

func show_cue(attack: Dictionary, windup: float) -> void:
	if not Game.settings.get("hints", true):
		return
	if attack.parry:
		cue.show_cue("parry", DuelSim.dir_vec(DuelSim.parry_dir_for(attack.dir)), "", attack.unblockable, windup)
	else:
		cue.show_cue("dodge", Vector2.ZERO, attack.dodge, attack.unblockable, windup)

func _streak() -> void:
	var pts: Array = swipe_input.trail_points
	if pts.size() < 2:
		return
	streak.points = PackedVector2Array([pts[0], pts[0].lerp(pts[1], 0.5), pts[1]])
	streak.default_color = Color(1, 0.95, 0.85, 0.75)
	create_tween().tween_property(streak, "default_color:a", 0.0, 0.22)
