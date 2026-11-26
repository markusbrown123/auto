class_name SettingsPanel
extends RefCounted
## Settings rows in headed groups, shared by the sanctuary tab, the title screen and the pause menu.
## Every row writes Game.settings, applies it and saves at once; rows update in place so the list
## does not jump back to the top.

## [key, label, kind, hint]. kind: an Array of choices, "toggle", "slider", or [min, max] for a ranged slider.
## A row whose key starts with "#" is a section header.
const ROWS := [
	["#", "Graphics"],
	["quality", "Quality", ["Performance", "Balanced", "High"], "Resolution, anti-aliasing, shadows, particle counts and model detail"],
	["fps", "Frame rate", [30, 60, 120], "Higher rates use more battery"],
	["#", "Audio"],
	["master", "Master", "slider", ""],
	["music", "Music", "slider", ""],
	["dialogue", "Dialogue", "slider", ""],
	["combat", "Combat effects", "slider", "Also sets interface sounds"],
	["ambience", "Ambience", "slider", ""],
	["#", "Controls"],
	["pad_opacity", "Control visibility", "slider", "How visible the dodge and shield buttons are at rest. Zero hides them; they still work."],
	["swipe_sens", "Swipe sensitivity", [0.5, 1.5], "Higher means a shorter, slower stroke counts as a cut"],
	["haptic_strength", "Haptic strength", "slider", "Vibration on impacts. Zero turns it off."],
	["hints", "Combat prompts", "toggle", "Show the parry direction and timing ring"],
	["#", "Accessibility"],
	["sub_size", "Subtitle size", ["Small", "Medium", "Large"], ""],
	["sub_bg", "Subtitle backing", "toggle", "A dark band behind spoken lines"],
	["shake", "Camera shake", "slider", "Lower for a steadier view"],
	["reduce_flash", "Reduce flashes", "toggle", "Softens full-screen hit flashes"],
	["reduce_motion", "Reduce motion", "toggle", "Stills drifting cameras and turning previews in menus"],
	["assist", "Forgiving timing", "toggle", "Widens parry and dodge windows by 30%"],
	["chatter", "Companion remarks", "toggle", "Unprompted lines from your companions on the road"],
	["#", "In testing"],
	["cine_road", "Cinematic exploration", "toggle", "Fallen Courtyard: filmed walks and views, real-time duels"],
	["cine", "Cinematic duel", "toggle", "Ashen Sentinel only: prerecorded footage, live rules"],
]
## Choice rows whose stored value is the index of the choice rather than the choice itself.
const BY_INDEX := ["quality", "sub_size"]

## Fills `v` with every row. `refresh` is kept for callers that rebuild their screen; rows no longer need it.
## `to_title`, when given, adds a "Return to title" button to the last section.
static func fill(v: VBoxContainer, _refresh: Callable = Callable(), to_title: Callable = Callable()) -> void:
	if not (v.get_parent() is ScrollContainer):
		# a caller that gave a plain column gets a scrolling one inside it: the list is taller than a screen
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(620, 400)
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		v.add_child(sc)
		var inner := VBoxContainer.new()
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_theme_constant_override("separation", 5)
		sc.add_child(inner)
		v = inner
	for r in ROWS:
		if str(r[0]) == "#":
			_header(v, r[1])
			continue
		var key: String = r[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_theme_constant_override("separation", -4)
		names.add_child(UI.label(r[1], 19, UI.BONE, "bold"))
		if r[3] != "":
			var hint := UI.label(r[3], 16, UI.DIM)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			names.add_child(hint)
		row.add_child(names)
		if r[2] is Array and r[2].size() == 2 and r[2][0] is float:
			_slider(row, key, r[2][0], r[2][1])
		elif r[2] is Array:
			var opts: Array = r[2]
			var buttons: Array = []
			for i in opts.size():
				var val = i if BY_INDEX.has(key) else opts[i]
				var b := UI.button(str(opts[i]), 13, 0 if opts.size() > 2 and str(opts[i]).length() > 4 else 80)
				b.custom_minimum_size.y = 40
				b.set_meta("val", val)
				buttons.append(b)
				b.pressed.connect(func():
					_apply(key, val)
					for other: Button in buttons:
						other.add_theme_color_override("font_color", UI.GOLD if other.get_meta("val") == Game.settings[key] else UI.BONE))
				b.add_theme_color_override("font_color", UI.GOLD if Game.settings[key] == val else UI.BONE)
				row.add_child(b)
		elif r[2] == "toggle":
			var b := UI.button("On" if Game.settings[key] else "Off", 14, 96)
			b.custom_minimum_size.y = 40
			b.add_theme_color_override("font_color", UI.GOLD if Game.settings[key] else UI.BONE)
			b.pressed.connect(func():
				_apply(key, not Game.settings[key])
				b.text = "ON" if Game.settings[key] else "OFF"
				b.add_theme_color_override("font_color", UI.GOLD if Game.settings[key] else UI.BONE))
			row.add_child(b)
		else:
			_slider(row, key, 0.0, 1.0)
		v.add_child(row)
	_header(v, "Other")
	var other := HBoxContainer.new()
	other.add_theme_constant_override("separation", 8)
	v.add_child(other)
	for doc in [["Privacy policy", "privacy"], ["Credits", "credits"]]:
		var b := UI.button(doc[0], 14, 0)
		b.custom_minimum_size.y = 42
		b.pressed.connect(func(): show_text(v, doc[0], legal(doc[1])))
		other.add_child(b)
	if to_title.is_valid():
		var gap := UI.spacer(0)
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		other.add_child(gap)
		var quit := UI.button("Return to title", 14, 0)
		quit.custom_minimum_size.y = 42
		quit.pressed.connect(to_title)
		other.add_child(quit)

static func _header(v: VBoxContainer, text: String) -> void:
	if v.get_child_count() > 0:
		v.add_child(UI.spacer(6))
	v.add_child(UI.title(text, 17, UI.GOLD))
	v.add_child(UI.rule())

static func _slider(row: HBoxContainer, key: String, lo: float, hi: float) -> void:
	var val := UI.label("", 17, UI.DIM)
	val.custom_minimum_size.x = 52
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.text = "%d%%" % roundi(float(Game.settings[key]) * 100.0)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = Game.settings[key]
	s.custom_minimum_size = Vector2(220, 40)
	s.value_changed.connect(func(x: float):
		_apply(key, x)
		val.text = "%d%%" % roundi(x * 100.0))
	row.add_child(s)
	row.add_child(val)

static func _apply(key: String, val, _refresh: Callable = Callable()) -> void:
	Game.settings[key] = val
	Game.apply_settings()
	Game.save_settings()

## Text from data/legal.json ("privacy" or "credits").
static func legal(which: String) -> String:
	var v = JSON.parse_string(FileAccess.get_file_as_string("res://data/legal.json"))
	return str(v.get(which, "")) if v is Dictionary else ""

## A full-screen reading panel over whatever screen `from` belongs to.
static func show_text(from: Node, heading: String, body: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	from.get_tree().root.add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	UI.full(shade)
	layer.add_child(shade)
	var m := UI.margin(from.get_viewport(), 30)
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(m)
	var p := UI.panel()
	m.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	p.add_child(col)
	col.add_child(UI.title(heading, 22))
	col.add_child(UI.rule())
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	var text := UI.label(body, 18, UI.BONE)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(text)
	var close := UI.button("Close", 16, 200)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(layer.queue_free)
	col.add_child(close)
