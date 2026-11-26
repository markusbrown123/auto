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
	func _process(dt: float) -> void:
		# near-invisible at rest, fully lit under the thumb, fading back afterwards
		glow = 1.0 if held else maxf(0.0, glow - dt * 2.2)
		var rest: float = float(Game.settings.get("pad_opacity", 0.2))
		if charge >= 1.0:
			rest = maxf(rest, 0.8)      # a full burst or flame announces itself
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
		draw_circle(c, r, Color(0.04, 0.04, 0.05, 0.62 if not held else 0.85))
		draw_arc(c, r, 0, TAU, 48, UI.GOLD if held else UI.GOLD_DIM, 2.0, true)
		if glow > 0.0:
			draw_arc(c, r - 3.0, 0, TAU, 48, Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, 0.45 * glow), 6.0, true)
			draw_circle(c, r - 6.0, Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, 0.12 * glow))
		var col := UI.GOLD if held else UI.BONE
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
				draw_line(c + Vector2(0, -s), c + Vector2(0, s * 1.2), col, 1.5, true)

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
var _toast_tw: Tween
var _sub_tw: Tween
var _phase_pips: HBoxContainer

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
	posture_bar = UI.bar(UI.GOLD, 4)
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

func update_bars(sim: DuelSim, dt: float) -> void:
	boss_bar.max_value = sim.b_hp_max
	boss_bar.value = sim.b_hp
	boss_ghost.max_value = sim.b_hp_max
	boss_ghost.value = maxf(sim.b_hp, lerpf(boss_ghost.value, sim.b_hp, 1.0 - exp(-dt * 2.5)))
	posture_bar.max_value = float(sim.bd.posture)
	posture_bar.value = sim.b_posture if sim.b_state != DuelSim.B.STAGGER else posture_bar.max_value
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

func lesson_text(t: String) -> void:
	if _train_head:
		_train_head.text = t
		_train_head.add_theme_font_size_override("font_size", 22)
		_train_head.add_theme_color_override("font_color", UI.BONE)

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
