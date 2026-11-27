extends Node
## Dialogue and subtitles. Scenes and lines live in data/dialogue.json; voiced
## audio, when present, is at assets/audio/vo/<line id>[_m|_f].ogg. Every line
## is always subtitled, voiced or not.

signal scene_finished(id: String)
## A line has begun (the Witness drone pulses its light with its own lines).
signal line_started(speaker: String, line_id: String)

var data := {}
var busy := false
var speaker := ""             ## who is speaking now ("" between lines and when nothing plays)
var _layer: CanvasLayer
var _name: Label
var _text: Label
var _catcher: Control             # takes the tap that passes over a line; out of the way for a line spoken as an aside
var _player: AudioStreamPlayer
var _skip := false
var _token := 0
var _box: VBoxContainer           # the name and the words
var _shade: Control
var last_finished := ""           ## the scene that last played to its end (one cut short by stop() is not it)
const BOX_TOP := -150.0
const BOX_BOTTOM := -34.0

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
	_catcher = catcher
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
	_box = v
	_shade = shade
	_name = UI.title("", 15, UI.GOLD)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_name)
	_text = UI.label("", Game.subtitle_size(), UI.BONE)
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

const VO := "res://assets/audio/vo/"

## The take a line is spoken with. The knight's lines (and the forebear's and the heir's, which are the knight's by
## another cast) and any line marked `by_body` (the Kept, who was the player's own second knight) have one take for
## each lineage: <line>_m / <line>_f. A `by_body` line whose take for this body is missing falls back to <line>.ogg.
## In the third generation a take suffixed `_g3` is used where one exists (<line>_g3[_m|_f].ogg), so the Last Heir
## can be given their own readings of the shared scenes later with no change here; until then the shared take plays.
func audio_path(line_id: String) -> String:
	var c := take_candidates(line_id)
	for path: String in c:
		if ResourceLoader.exists(path):
			return path
	return c[c.size() - 2] if bool(data.lines[line_id].get("by_body", false)) else c[c.size() - 1]

## Every file that could hold this line now, best first.
func take_candidates(line_id: String) -> Array:
	var line: Dictionary = data.lines[line_id]
	var by_body: bool = bool(line.get("by_body", false))
	var suffix := ""
	if line.speaker == "player" or by_body:
		suffix = "_" + str(Game.profile.get("body", "m"))
	var out: Array = []
	if not Game.profile.is_empty() and Game.generation() >= 3:
		out.append("%s%s_g3%s.ogg" % [VO, line_id, suffix])
		if suffix != "":
			out.append("%s%s_g3.ogg" % [VO, line_id])
	out.append("%s%s%s.ogg" % [VO, line_id, suffix])
	if by_body:
		out.append("%s%s.ogg" % [VO, line_id])
	return out

func stop() -> void:
	_token += 1
	_player.stop()
	_layer.visible = false
	busy = false
	speaker = ""
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
## `aside`: a remark made while the player is doing something else (a greeting in the sanctuary, a taunt as a
## fight starts). It cannot be tapped past and it takes no touches: otherwise the first press on Buy, or the first
## cut, would be spent on the line instead.
## `lift`: the words sit this many units higher than usual, outlined instead of on the dark band, clear of
## controls at the foot of the screen (the road's choices are offered while a companion is still talking).
## `late`: a once-only scene is recorded as seen when it ends, not as it begins (one cut short can be said again).
func play(id: String, force: bool = false, aside: bool = false, lift: float = 0.0, late: bool = false) -> void:
	if not has_scene(id) or (not force and not pending(id)):
		return
	if busy:
		stop()
	busy = true
	_box.offset_top = BOX_TOP - lift
	_box.offset_bottom = BOX_BOTTOM - lift
	_shade.visible = lift <= 0.0
	_text.add_theme_constant_override("outline_size", 7 if lift > 0.0 else 0)
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_name.add_theme_constant_override("outline_size", 5 if lift > 0.0 else 0)
	_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE if aside else Control.MOUSE_FILTER_STOP
	_token += 1
	var mine := _token
	if not late and not Game.profile.is_empty() and bool(data.scenes[id].get("once", true)):
		Game.profile.flags["scene_" + id] = true
	_layer.visible = true
	_duck(true)
	for lid in data.scenes[id].lines:
		var line: Dictionary = data.lines[lid]
		var who: String = line.speaker
		speaker = who
		line_started.emit(who, lid)
		_name.text = str(data.names.get(who, "")).to_upper()
		_name.visible = _name.text != ""
		_text.text = line.text
		_text.add_theme_color_override("font_color", Color("#bfd8e8") if who in ["lyra", "archivist"] else UI.BONE)
		_text.modulate.a = 0.0
		create_tween().tween_property(_text, "modulate:a", 1.0, 0.25)
		var hold: float = 1.4 + float(str(line.text).length()) / 15.0
		var path := audio_path(lid)
		# a line marked "recorded": false is text only: never play a stale take left under the same id
		if bool(line.get("recorded", true)) and ResourceLoader.exists(path):
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
	speaker = ""
	_duck(false)
	last_finished = id
	if late and not Game.profile.is_empty() and bool(data.scenes[id].get("once", true)):
		Game.profile.flags["scene_" + id] = true
	scene_finished.emit(id)
