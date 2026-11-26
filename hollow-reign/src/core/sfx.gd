extends Node
## Sound effects, ambience and crossfading music. All audio is original,
## synthesized by tools/gen_audio.py.

const VARIANTS := {"swing": 3, "clash": 3, "hit_armor": 2, "hit_flesh": 2, "block": 2, "roar": 3, "footstep": 2}
## Mix buses and the setting that scales each, with a fixed trim so the layers sit in order:
## dialogue on top, then combat, interface, music, ambience underneath.
const BUSES := ["Music", "Dialogue", "Combat", "Ambience", "Interface", "Cinematics"]
const BUS_SETTING := {"Music": "music", "Dialogue": "voice", "Combat": "sfx", "Ambience": "sfx", "Interface": "sfx", "Cinematics": "sfx"}
const BUS_TRIM := {"Music": -3.0, "Dialogue": 0.0, "Combat": -1.0, "Ambience": -7.0, "Interface": -5.0, "Cinematics": -2.0}
const INTERFACE_SOUNDS := ["loot", "levelup", "ui_tap", "ui_back", "bell"]
const AMBIENT_SOUNDS := ["footstep"]
var _cache := {}
var _pool: Array = []
var _next := 0
var _music: Array = []
var _music_i := 0
var _music_name := ""
var _amb: AudioStreamPlayer
var _amb_name := ""
var _layer: AudioStreamPlayer
var _layer_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# six mix buses; a limiter on the master keeps stacked impacts from clipping
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -1.0
		lim.threshold_db = -6.0
		AudioServer.add_bus_effect(0, lim)
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Combat"
		add_child(p)
		_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -60.0
		add_child(m)
		_music.append(m)
	_layer = AudioStreamPlayer.new()
	_layer.bus = "Music"
	_layer.volume_db = -60.0
	add_child(_layer)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "Ambience"
	_amb.volume_db = -8.0
	add_child(_amb)
	Game.apply_settings()

func _stream(path: String, loop: bool = false) -> AudioStream:
	if not _cache.has(path):
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s is AudioStreamOggVorbis and loop:
			s.loop = true
		_cache[path] = s
	return _cache[path]

func play(sound: String, vol_db: float = 0.0, pitch: float = 1.0, jitter: float = 0.06) -> void:
	var file := sound
	if VARIANTS.has(sound):
		file = "%s_%d" % [sound, randi_range(1, VARIANTS[sound])]
	var s := _stream("res://assets/audio/sfx/%s.wav" % file)
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.bus = "Interface" if INTERFACE_SOUNDS.has(sound) else ("Ambience" if AMBIENT_SOUNDS.has(sound) else "Combat")
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(1.0 - jitter, 1.0 + jitter)
	p.play()

## Picks a bespoke track when one has been produced, else the fallback.
func music_for(preferred: String, fallback: String, fade: float = 1.5) -> void:
	music(preferred if ResourceLoader.exists("res://assets/audio/music/%s.ogg" % preferred) else fallback, fade)

func music(track: String, fade: float = 1.5) -> void:
	if track == _music_name:
		return
	_music_name = track
	set_layer("", 0.5)
	var old: AudioStreamPlayer = _music[_music_i]
	_music_i = 1 - _music_i
	var cur: AudioStreamPlayer = _music[_music_i]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -60.0, fade)
	if track != "":
		var s := _stream("res://assets/audio/music/%s.ogg" % track, true)
		if s:
			cur.stream = s
			cur.volume_db = -40.0
			cur.play()
			tw.tween_property(cur, "volume_db", -5.0, fade)
	tw.chain().tween_callback(old.stop)

## A second track played in sync over the current one (boss phase intensity).
func set_layer(track: String, fade: float = 1.2) -> void:
	if _layer_tween:
		_layer_tween.kill()
	_layer_tween = create_tween()
	if track == "":
		_layer_tween.tween_property(_layer, "volume_db", -60.0, fade)
		_layer_tween.tween_callback(_layer.stop)
		return
	var s := _stream("res://assets/audio/music/%s.ogg" % track, true)
	if s == null:
		return
	_layer.stream = s
	_layer.volume_db = -40.0
	_layer.play(_music[_music_i].get_playback_position())
	_layer_tween.tween_property(_layer, "volume_db", -5.0, fade)
	_layer_tween.parallel().tween_property(_music[_music_i], "volume_db", -14.0, fade)

func ambience(track: String) -> void:
	if track == _amb_name:
		return
	_amb_name = track
	_amb.stop()
	if track != "":
		var s := _stream("res://assets/audio/amb/%s.ogg" % track, true)
		if s:
			_amb.stream = s
			_amb.play()
