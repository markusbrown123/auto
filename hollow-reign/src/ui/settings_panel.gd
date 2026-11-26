class_name SettingsPanel
extends RefCounted
## Settings rows, shared by the sanctuary tab and the pause menu.

const ROWS := [
	["quality", "Graphics", ["Performance", "Balanced", "Quality"], "Resolution scale and anti-aliasing"],
	["fps", "Frame rate", [30, 60, 120], "Higher rates use more battery"],
	["music", "Music", "slider", ""],
	["sfx", "Sound", "slider", ""],
	["voice", "Voices", "slider", ""],
	["haptics", "Haptics", "toggle", "Vibration on impacts"],
	["shake", "Camera shake", "slider", ""],
	["hints", "Combat prompts", "toggle", "Show the parry direction and timing ring"],
	["assist", "Forgiving timing", "toggle", "Widens parry and dodge windows by 30%"],
	["reduce_flash", "Reduce flashes", "toggle", "Softens full-screen hit flashes"],
]

static func fill(v: VBoxContainer, refresh: Callable) -> void:
	for r in ROWS:
		var key: String = r[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_theme_constant_override("separation", -4)
		names.add_child(UI.label(r[1], 19, UI.BONE, "bold"))
		if r[3] != "":
			names.add_child(UI.label(r[3], 14, UI.DIM))
		row.add_child(names)
		if r[2] is Array:
			var opts: Array = r[2]
			for i in opts.size():
				var val = i if key == "quality" else opts[i]
				var b := UI.button(str(opts[i]), 13, 96)
				b.custom_minimum_size.y = 40
				if Game.settings[key] == val:
					b.add_theme_color_override("font_color", UI.GOLD)
				b.pressed.connect(func(): _apply(key, val, refresh))
				row.add_child(b)
		elif r[2] == "toggle":
			var b := UI.button("On" if Game.settings[key] else "Off", 14, 96)
			b.custom_minimum_size.y = 40
			if Game.settings[key]:
				b.add_theme_color_override("font_color", UI.GOLD)
			b.pressed.connect(func(): _apply(key, not Game.settings[key], refresh))
			row.add_child(b)
		else:
			var s := HSlider.new()
			s.min_value = 0.0
			s.max_value = 1.0
			s.step = 0.05
			s.value = Game.settings[key]
			s.custom_minimum_size = Vector2(240, 40)
			s.value_changed.connect(func(x):
				Game.settings[key] = x
				Game.apply_settings()
				Game.save_settings())
			row.add_child(s)
		v.add_child(row)

static func _apply(key: String, val, refresh: Callable) -> void:
	Game.settings[key] = val
	Game.apply_settings()
	Game.save_settings()
	refresh.call()
