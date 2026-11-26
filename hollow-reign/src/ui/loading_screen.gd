class_name LoadingScreen
extends Node
## Covers a transition that really takes time: a still of the place, a slow drift, one line to read, and a mark
## that turns while the work is being done. There is no percentage because none would be true.
##   await LoadingScreen.show("blackwood", func(): show_stage())
## `what` is a region id or an arena theme. `work` builds the next screen; it may be a coroutine.
## `warm` lists resources to load on a thread first, which is the part of the wait that can be made smooth.

const MIN_TIME := 1.1           # long enough not to flash; the line stays readable because it is one sentence
const STILL_SIZE := Vector2i(960, 540)

static var _stills := {}        # theme -> Texture2D, rendered once per session
static var _tips: Array = []
static var _last_tip := ""

var layer: CanvasLayer
var _what := ""
var _root: Control
var _still: TextureRect
var _clock := 0.0

static func show(what: String, work: Callable, warm: Array = []) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var ls := LoadingScreen.new()
	ls._what = what
	ls.process_mode = Node.PROCESS_MODE_ALWAYS
	# deferred, so it can be asked for from inside another node's _ready
	tree.root.add_child.call_deferred(ls)
	await ls.ready
	await ls._run(work, warm)

## One line the player is allowed to read: any combat tip, or a note about somewhere already reached.
static func pick_tip(profile: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	if _tips.is_empty():
		var v = JSON.parse_string(FileAccess.get_file_as_string("res://data/loading_tips.json"))
		if v is Dictionary:
			_tips = v.get("tips", [])
	var ok: Array = []
	for t in _tips:
		if tip_allowed(t, profile) and str(t.text) != _last_tip:
			ok.append(t)
	if ok.is_empty():
		return {"kind": "tip", "text": ""}
	var i: int = rng.randi_range(0, ok.size() - 1) if rng else randi() % ok.size()
	_last_tip = str(ok[i].text)
	return ok[i]

static func tip_allowed(t: Dictionary, profile: Dictionary) -> bool:
	if str(t.get("kind", "tip")) != "lore" or t.get("after") == null:
		return true
	var id := str(t.after)
	if not Db.region_by_id.has(id):
		return false
	var req = Db.region_by_id[id].requires
	return req == null or profile.get("cleared", []).has(req)

func _region() -> Dictionary:
	return Db.region_by_id.get(_what, {})

func _theme_id() -> String:
	var r := _region()
	var t: String = str(r.get("theme", _what))
	return t if Arena.THEMES.has(t) else "sanctuary"

func _build() -> void:
	layer = CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_root = UI.full(Control.new())
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UI.theme()
	layer.add_child(_root)
	var bg: ColorRect = UI.full(ColorRect.new())
	bg.color = Color(0.02, 0.02, 0.026)
	_root.add_child(bg)
	_still = UI.full(TextureRect.new())
	_still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_still.modulate = Color(0.8, 0.8, 0.84, 0.0)
	_still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_still)
	# dust in the light
	var dust := CPUParticles2D.new()
	var vp := get_viewport().get_visible_rect().size
	dust.position = vp * 0.5
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = vp * 0.55
	dust.amount = 46
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.direction = Vector2(-0.6, -1)
	dust.spread = 35.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 6.0
	dust.initial_velocity_max = 20.0
	dust.scale_amount_min = 1.2
	dust.scale_amount_max = 3.2
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 0.93, 0.78, 0.0), Color(1, 0.93, 0.78, 0.3), Color(1, 0.93, 0.78, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	dust.color_ramp = fade
	dust.speed_scale = UI.motion() * 0.9 + 0.1
	_root.add_child(dust)
	_root.add_child(UI.vignette(0.85))
	var low := UI.shade(0.9, 0.0)
	(low.texture as GradientTexture2D).fill_from = Vector2(0, 1)
	(low.texture as GradientTexture2D).fill_to = Vector2(0, 0.45)
	_root.add_child(low)
	var m := UI.margin(get_viewport(), 40)
	_root.add_child(m)
	# where we are going, top left
	var r := _region()
	if not r.is_empty():
		var head := VBoxContainer.new()
		head.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		head.add_theme_constant_override("separation", 4)
		head.add_child(UI.title(str(r.name), 30, UI.BONE))
		head.add_child(UI.ornament(260))
		m.add_child(head)
	# the line, bottom left
	var tip := pick_tip(Game.profile if not Game.profile.is_empty() else Game.default_profile())
	if str(tip.text) != "":
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		words.size_flags_vertical = Control.SIZE_SHRINK_END
		words.add_theme_constant_override("separation", 4)
		words.add_child(UI.label("A RECORD" if str(tip.kind) == "lore" else "REMEMBER", 15, UI.GOLD, "head"))
		words.add_child(UI.wrapped(str(tip.text), 23, UI.BONE, 780))
		m.add_child(words)
	# the mark, bottom right: it turns while there is work, and that is all it claims
	var mark := Emblem.new(54, UI.GOLD, true)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_END
	mark.size_flags_vertical = Control.SIZE_SHRINK_END
	m.add_child(mark)

func _process(delta: float) -> void:
	if _still == null:
		return
	_clock += delta * UI.motion()
	# a slow drift, larger than the screen so no edge shows
	_still.pivot_offset = _still.size * 0.5
	_still.scale = Vector2.ONE * (1.07 + 0.012 * sin(_clock * 0.25))
	_still.position = Vector2(sin(_clock * 0.19) * 16.0, cos(_clock * 0.15) * 9.0)

## An existing piece of art for this place, if the build has one.
func _art() -> Texture2D:
	if _what == "courtyard" or _theme_id() == "courtyard":
		var pre := "courtyard_f_stop" if str(Game.profile.get("body", "m")) == "f" else "courtyard_stop"
		var n := randi() % 7
		for i in 7:
			var path := "res://assets/video/stills/%s_%d.jpg" % [pre, (n + i) % 7]
			if ResourceLoader.exists(path):
				return load(path)
	return null

## Otherwise the place itself, built once off-screen and kept as a picture.
func _render_still() -> void:
	var id := _theme_id()
	if DisplayServer.get_name() == "headless":
		return
	if not _stills.has(id):
		var sv := SubViewport.new()
		sv.size = STILL_SIZE
		sv.own_world_3d = true
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sv)
		var b := Backdrop.new()
		sv.add_child(b)
		b.build(id, false)
		b.set_process(false)
		b.cam.position = Vector3(0.6, 1.5, 6.5)
		b.cam.look_at(Vector3(-0.3, 1.9, -4.0))
		for i in 3:
			await RenderingServer.frame_post_draw
		var img := sv.get_texture().get_image()
		sv.queue_free()
		if img == null or img.is_empty():
			return
		_stills[id] = ImageTexture.create_from_image(img)
	_still.texture = _stills[id]

func _run(work: Callable, warm: Array) -> void:
	_build()
	var t0 := Time.get_ticks_msec()
	var art := _art()
	if art:
		_still.texture = art
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.3)
	await tw.finished
	if art == null:
		await _render_still()
	if _still.texture:
		create_tween().tween_property(_still, "modulate:a", 1.0, 0.5)
	# the part that can be done without stopping the picture
	var pending: Array = []
	for p in warm:
		if ResourceLoader.exists(str(p)) and not ResourceLoader.has_cached(str(p)) and ResourceLoader.load_threaded_request(str(p)) == OK:
			pending.append(str(p))
	var kept: Array = []
	while not pending.is_empty():
		await get_tree().process_frame
		for p: String in pending.duplicate():
			if ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				kept.append(ResourceLoader.load_threaded_get(p))
				pending.erase(p)
	await get_tree().process_frame
	await get_tree().process_frame
	# the part that cannot: the picture holds for as long as this really takes
	if work.is_valid():
		await work.call()
	var left := MIN_TIME - (Time.get_ticks_msec() - t0) / 1000.0
	if left > 0.0:
		await get_tree().create_timer(left, true, false, true).timeout
	kept.clear()
	var out := create_tween()
	out.tween_property(_root, "modulate:a", 0.0, 0.45)
	await out.finished
	queue_free()
