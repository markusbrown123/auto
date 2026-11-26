extends Node
## Dialogue and subtitles. Scenes and lines live in data/dialogue.json; voiced
## audio, when present, is at assets/audio/vo/<line id>[_m|_f].ogg. Every line
## is always subtitled, voiced or not.

signal scene_finished(id: String)

var data := {}
var busy := false
var _layer: CanvasLayer
var _name: Label
var _text: Label
var _player: AudioStreamPlayer
var _skip := false
var _token := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string("res://data/dialogue.json")) == OK:
		data = j.data
	_player = AudioStreamPlayer.new()
	_player.bus = "Dialogue"
	add_child(_player)
	_layer = CanvasLayer.new()
	_layer.layer = 60
	_layer.visible = false
	add_child(_layer)
	var catcher := UI.full(Control.new())
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(e):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			_skip = true)
	_layer.add_child(catcher)
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0, 0, 0, 0.82))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -210
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	v.anchor_left = 0.14
	v.anchor_right = 0.86
	v.offset_left = 0
	v.offset_right = 0
	v.offset_top = -150
	v.offset_bottom = -34
	v.alignment = BoxContainer.ALIGNMENT_END
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(v)
	_name = UI.title("", 15, UI.GOLD)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_name)
	_text = UI.label("", 25, UI.BONE)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_text)

func has_scene(id: String) -> bool:
	return data.get("scenes", {}).has(id)

func seen(id: String) -> bool:
	return not Game.profile.is_empty() and Game.profile.flags.has("scene_" + id)

## True when the scene exists and would actually play (not already seen, if it is a once-only scene).
func pending(id: String) -> bool:
	return has_scene(id) and not (bool(data.scenes[id].get("once", true)) and seen(id))

func audio_path(line_id: String) -> String:
	var line: Dictionary = data.lines[line_id]
	var suffix := ""
	if line.speaker == "player":
		suffix = "_" + str(Game.profile.get("body", "m"))
	return "res://assets/audio/vo/%s%s.ogg" % [line_id, suffix]

func stop() -> void:
	_token += 1
	_player.stop()
	_layer.visible = false
	busy = false
	_duck(false)

func _duck(on: bool) -> void:
	# speech pushes music and ambience down so the words stay on top
	for bus_name: String in ["Music", "Ambience"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			var base: float = linear_to_db(maxf(float(Game.settings[Sfx.BUS_SETTING[bus_name]]), 0.0001)) + float(Sfx.BUS_TRIM[bus_name])
			# ramp rather than jump: down quickly as the line starts, back up slowly after it
			var from: float = AudioServer.get_bus_volume_db(idx)
			var to: float = base - (9.0 if on else 0.0)
			var tw := create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_method(func(v: float): AudioServer.set_bus_volume_db(idx, v), from, to, 0.18 if on else 0.6)

## Plays a scene line by line. Await it to block, or call without await to let it run alongside play.
func play(id: String, force: bool = false) -> void:
	if not has_scene(id) or (not force and not pending(id)):
		return
	if busy:
		stop()
	busy = true
	_token += 1
	var mine := _token
	if not Game.profile.is_empty() and bool(data.scenes[id].get("once", true)):
		Game.profile.flags["scene_" + id] = true
	_layer.visible = true
	_duck(true)
	for lid in data.scenes[id].lines:
		var line: Dictionary = data.lines[lid]
		var who: String = line.speaker
		_name.text = str(data.names.get(who, "")).to_upper()
		_name.visible = _name.text != ""
		_text.text = line.text
		_text.add_theme_color_override("font_color", Color("#bfd8e8") if who in ["lyra", "archivist"] else UI.BONE)
		_text.modulate.a = 0.0
		create_tween().tween_property(_text, "modulate:a", 1.0, 0.25)
		var hold: float = 1.4 + float(str(line.text).length()) / 15.0
		var path := audio_path(lid)
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path)
			_player.stream = s
			_player.play()
			hold = s.get_length() + 0.45
		_skip = false
		var t := 0.0
		while t < hold and not _skip:
			await get_tree().process_frame
			if mine != _token:
				return
			t += get_process_delta_time()
		_player.stop()
	_layer.visible = false
	busy = false
	_duck(false)
	scene_finished.emit(id)
