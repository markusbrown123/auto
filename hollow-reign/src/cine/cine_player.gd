class_name CinePlayer
extends Control
## Seamless playback of short prerecorded clips with branching.
## Godot's stock player only decodes Ogg Theora, and starting a stream takes a
## few frames, so every clip that may be needed next is "armed" in advance:
## started, held on its first decoded frame, and kept invisible. A branch then
## only un-pauses an already-decoded stream, with a two-frame dissolve.
##
## `advanced(dt)` reports how much footage was actually presented. Everything
## that depends on time listens to that, never to the wall clock, so a stall or
## a pause freezes the fight instead of desynchronising it.

signal advanced(dt: float)
signal media_missing(clip: String)
signal stall_changed(stalled: bool)

const DISSOLVE := 0.066

var video_dir := "res://assets/video/"
var prefix := ""
var lengths := {}
var active: VideoStreamPlayer
var active_clip := ""
var active_loop := false
var armed := {}               # clip -> VideoStreamPlayer held on its first frame
var _arming: Array = []       # players started but with no frame shown yet
var _fading: Array = []       # [player, time left]
var _last_pos := 0.0
var _still := 0.0
var stalled := false
var held := false             # paused by the game (menu, app in background, hit-stop)
var metrics := {"branches": 0, "unarmed_branches": 0, "max_branch_ms": 0.0, "sum_branch_ms": 0.0, "stalls": 0, "peak_players": 0, "branch_ms": []}
var _switch_usec := 0
var _awaiting_first := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	UI.full(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	resized.connect(_fit_all)

func path(clip: String) -> String:
	return "%s%s%s.ogv" % [video_dir, prefix, clip]

func has(clip: String) -> bool:
	return ResourceLoader.exists(path(clip)) or FileAccess.file_exists(path(clip))

func _make(clip: String) -> VideoStreamPlayer:
	if not has(clip):
		media_missing.emit(clip)
		return null
	var p := VideoStreamPlayer.new()
	var s := VideoStreamTheora.new()
	s.file = path(clip)
	p.stream = s
	p.bus = "Cinematics"
	p.expand = true
	p.volume_db = -80.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.modulate.a = 0.0
	add_child(p)
	_fit(p)
	p.play()
	if Sfx.logging():
		Sfx.alog("video", path(clip).get_file(), p.bus, p.volume_db)
	metrics.peak_players = maxi(metrics.peak_players, get_child_count() - 1)
	return p

## Cover the screen on phone-shaped displays; letterbox on squarer ones so attack cues are never cropped.
func _fit(p: Control) -> void:
	var view := size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var va := view.x / view.y
	var a := 16.0 / 9.0
	var w: float
	var h: float
	if va >= 1.6:
		# cover: fill the width or height, crop the other slightly
		if va > a:
			w = view.x
			h = w / a
		else:
			h = view.y
			w = h * a
	else:
		w = view.x
		h = w / a
	p.size = Vector2(w, h)
	p.position = (view - p.size) * 0.5

func _fit_all() -> void:
	for c in get_children():
		if c is VideoStreamPlayer:
			_fit(c)

## Get these clips' first frames decoded and waiting. Anything armed but no longer wanted is released.
func prepare(clips: Array) -> void:
	for c in armed.keys():
		if not clips.has(c):
			armed[c].queue_free()
			_arming.erase(armed[c])
			armed.erase(c)
	for c in clips:
		if armed.has(c):
			continue
		var p := _make(c)
		if p:
			armed[c] = p
			_arming.append(p)

func is_armed(clip: String) -> bool:
	return armed.has(clip) and not _arming.has(armed[clip])

func show_clip(clip: String, looping: bool) -> void:
	var p: VideoStreamPlayer = armed.get(clip)
	metrics.branches += 1
	if p == null or _arming.has(p):
		metrics.unarmed_branches += 1
	if p == null:
		p = _make(clip)
		if p == null:
			return
	armed.erase(clip)
	_arming.erase(p)
	if active:
		_fading.append([active, DISSOLVE])
	active = p
	active_clip = clip
	active_loop = looping
	move_child(p, get_child_count() - 1)
	p.modulate.a = 1.0
	p.paused = held
	_last_pos = p.stream_position
	_still = 0.0
	_switch_usec = Time.get_ticks_usec()
	_awaiting_first = true
	if looping:
		prepare(armed.keys() + [clip])     # a second copy, ready for the loop point

func hold(on: bool) -> void:
	held = on
	_awaiting_first = false      # a pause is not a slow branch: do not time across it
	if active:
		active.paused = on

func _process(delta: float) -> void:
	# arming: the moment a stream has shown its first frame, freeze it there
	for p in _arming.duplicate():
		if is_instance_valid(p) and p.stream_position > 0.0:
			p.paused = true
			_arming.erase(p)
	for f in _fading.duplicate():
		f[1] -= delta
		if is_instance_valid(f[0]):
			f[0].modulate.a = clampf(f[1] / DISSOLVE, 0.0, 1.0)
			if f[1] <= 0.0:
				f[0].queue_free()
				_fading.erase(f)
		else:
			_fading.erase(f)
	if active == null or held:
		return
	var pos := active.stream_position
	var d := pos - _last_pos
	var length: float = float(lengths.get(active_clip, 0.0))
	if d > 0.0:
		if _awaiting_first:
			_awaiting_first = false
			var ms := (Time.get_ticks_usec() - _switch_usec) / 1000.0
			metrics.max_branch_ms = maxf(metrics.max_branch_ms, ms)
			metrics.sum_branch_ms += ms
			metrics.branch_ms.append(ms)
		_last_pos = pos
		_still = 0.0
		if stalled:
			stalled = false
			stall_changed.emit(false)
		advanced.emit(d)
	elif not active.is_playing() or (length > 0.0 and pos >= length - 0.05):
		# the stream has run out a frame short of its nominal length: let time finish the clip
		advanced.emit(delta)
	else:
		_still += delta
		if _still > 0.3 and not stalled:
			stalled = true
			metrics.stalls += 1
			stall_changed.emit(true)
	if active_loop and length > 0.0 and pos >= length - 0.04 and armed.has(active_clip):
		var again := active_clip
		show_clip(again, true)
