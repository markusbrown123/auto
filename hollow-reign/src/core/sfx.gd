extends Node
## Sound effects, ambience and crossfading music, mixed on six buses. All audio is original:
## effects are synthesised by tools/gen_audio.py; four music cues and all speech are generated.

## Flat variant sets for the sounds that have no pool of their own (picked without repeating the last one).
const VARIANTS := {"roar": 3, "armor": 3}
## Combat and footstep one-shots. Every file in these pools starts with PREROLL seconds of silence (tools/gen_audio_combat.py),
## so a start offset of 0..PREROLL is sample-accurate and costs no attack. pool -> [file format, variants,
## pitch jitter (+/- fraction), volume jitter (+/- dB), voice family].
const PREROLL := 0.004
const POOLS := {
	"clash": ["clash_%d", 6, 0.025, 1.0, "metal"], "block": ["block_%d", 4, 0.025, 1.0, "metal"],
	"parry": ["parry_%d", 3, 0.02, 0.8, "parry"], "guard_break": ["guard_break_%d", 3, 0.025, 1.0, "break"],
	"hit_armor": ["hit_armor_%d", 4, 0.03, 1.0, "hit"], "hit_flesh": ["hit_flesh_%d", 4, 0.04, 1.0, "flesh"],
	"whoosh_light": ["whoosh_light_%d", 3, 0.07, 1.5, "whoosh"], "whoosh_med": ["whoosh_med_%d", 3, 0.07, 1.5, "whoosh"],
	"whoosh_heavy": ["whoosh_heavy_%d", 3, 0.06, 1.5, "whoosh"],
	"thump": ["thump_%d", 3, 0.04, 1.0, "layer"], "crack": ["crack_%d", 3, 0.03, 1.0, "layer"],
	"rattle": ["rattle_%d", 3, 0.04, 1.5, "layer"], "swell": ["swell_%d", 3, 0.03, 1.0, "layer"],
	"jingle": ["jingle_%d", 4, 0.05, 2.0, "layer"],
	"step_stone": ["step_stone_%d", 6, 0.05, 1.0, "step"], "step_metal": ["step_metal_%d", 6, 0.05, 1.0, "step"],
	"step_grass": ["step_grass_%d", 6, 0.05, 1.0, "step"], "step_snow": ["step_snow_%d", 6, 0.05, 1.0, "step"],
	"step_water": ["step_water_%d", 6, 0.05, 1.0, "step"],
	# generated slots (tools/sfx_buy.py): count 0 = none required; whatever numbered files exist are used (see _n)
	"shield_hit": ["shield_hit_%d", 0, 0.03, 1.0, "shield"], "draw": ["draw_%d", 0, 0.03, 1.0, "foley"],
	"sheath": ["sheath_%d", 0, 0.03, 1.0, "foley"], "body_fall": ["body_fall_%d", 0, 0.03, 1.0, "fall"],
	"rustle": ["rustle_%d", 0, 0.05, 1.5, "foley"], "roll": ["roll_%d", 0, 0.04, 1.0, "foley"],
}
## Voice families: [most voices at once (the oldest is stolen), minimum seconds between event starts].
## Rapid swipes therefore cannot stack into a wall, and one footstep call cannot become two steps.
const FAMILIES := {"metal": [4, 0.04], "parry": [2, 0.12], "break": [2, 0.2], "hit": [4, 0.04], "flesh": [4, 0.04],
	"whoosh": [3, 0.07], "layer": [8, 0.0], "step": [2, 0.08],
	"shield": [3, 0.06], "foley": [3, 0.08], "fall": [2, 0.3]}
## Named events: the first layer is the sound itself (it takes the retrigger gap), the rest are added with an
## optional delay "at" (s), a "vol" trim (dB), a minimum "min" intensity and a "chance".
const EVENTS := {
	"clash": [{"pool": "clash"}, {"pool": "thump", "vol": -8.0, "min": 0.6}],
	"block": [{"pool": "block"}],
	# a cut turned on a foe's raised guard: a thin, high ring with the rattle of the recoil, under the parry's clash
	"deflect": [{"pool": "clash"}, {"pool": "rattle", "vol": -5.0, "at": 0.03}, {"pool": "crack", "vol": -12.0}],
	"parry": [{"pool": "parry"}, {"pool": "swell", "vol": -5.0, "at": 0.03, "chance": 0.85}],
	"guard_break": [{"pool": "guard_break"}, {"pool": "crack", "vol": -2.0}, {"pool": "rattle", "vol": -4.0, "at": 0.09}],
	"hit_armor": [{"pool": "hit_armor"}, {"pool": "thump", "vol": -9.0, "min": 0.9, "chance": 0.6}],
	"hit_flesh": [{"pool": "hit_flesh"}],
	"swing": [{"pool": "@whoosh"}],
	"shield_hit": [{"pool": "shield_hit"}], "draw": [{"pool": "draw"}], "sheath": [{"pool": "sheath"}],
	"body_fall": [{"pool": "body_fall"}], "rustle": [{"pool": "rustle"}], "roll": [{"pool": "roll"}],
}
const SURFACES := {"stone": "stone", "rock": "stone", "metal": "metal", "metal_deck": "metal", "deck": "metal", "grass": "grass",
	"earth": "grass", "dirt": "grass", "grass_earth": "grass", "snow": "snow", "water": "water", "water_shallow": "water", "shallow": "water"}
## Mix buses and the setting that scales each, with a fixed trim so the layers sit in order:
## dialogue on top, then combat, interface, music, ambience underneath.
const BUSES := ["Music", "Dialogue", "Combat", "Ambience", "Interface", "Cinematics"]
## Five sliders over six buses: Interface follows Combat effects; Cinematics follows only the Master
## slider, which sits on the Master bus itself (see Game.apply_settings / Game.bus_level).
const BUS_SETTING := {"Music": "music", "Dialogue": "dialogue", "Combat": "combat", "Ambience": "ambience", "Interface": "combat", "Cinematics": "master"}
const BUS_TRIM := {"Music": -3.0, "Dialogue": 0.0, "Combat": -1.0, "Ambience": -7.0, "Interface": -5.0, "Cinematics": -2.0}
const INTERFACE_SOUNDS := ["loot", "levelup", "ui_tap", "ui_back", "ui_confirm"]
const AMBIENT_SOUNDS := ["bell"]
const CINEMATIC_SOUNDS := ["victory", "death", "finisher"]      # stingers that belong to the staged moments
var _cache := {}
var _pool: Array = []
var _counts := {}               # pool -> number of numbered files found (see _n)
var _last := {}                 # pool or sound -> last variant played
var _voices: Array = []         # {p, fam, t0, end} for every voice believed to be sounding (ms)
var _gate_at := {}              # voice family -> ms of the last event start
var _pan_side := 1.0
## Surface under the characters' feet for `play("footstep")` and `footstep("")`; set by whoever owns the scene.
var default_surface := "stone"
var _music: Array = []
var _music_i := 0
var _music_name := ""
var _amb: AudioStreamPlayer
var _amb_name := ""
var _layer: AudioStreamPlayer
var _layer_tween: Tween
## Dev: `-- --audiolog=<file>` writes one line for every sound start (and every footstep request) to that file:
## game clock, kind, name/file, bus, volume, pitch, who asked (`log_who`, set by the caller) and the calling stack.
## Off by default; nothing is computed while it is off.
var _alog: FileAccess
var _alog_t := 0.0              # game clock since launch, seconds (scaled delta, so it is the clock a fixed-fps run keeps)
var log_who := ""               # dev: the caller of the next logged sound names itself here (a rig's path and state)

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
	# whooshes are panned by sending them through two side buses that feed Combat
	for side: Array in [["CombatL", -0.35], ["CombatR", 0.35]]:
		if AudioServer.get_bus_index(side[0]) < 0:
			AudioServer.add_bus()
			var bi := AudioServer.bus_count - 1
			AudioServer.set_bus_name(bi, side[0])
			AudioServer.set_bus_send(bi, "Combat")
			var pn := AudioEffectPanner.new()
			pn.pan = side[1]
			AudioServer.add_bus_effect(bi, pn)
	for i in 24:
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
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--audiolog="):
			_alog = FileAccess.open(a.trim_prefix("--audiolog="), FileAccess.WRITE)
			if _alog:
				_alog.store_line("t\tframe\tkind\tname\tbus\tvol_db\tpitch\twho\tstack")

func _process(delta: float) -> void:
	_alog_t += delta
	if _alog and floori(_alog_t) != floori(_alog_t - delta):
		# once a second: every rig in the tree that could put a foot down, and what it is doing
		var rigs: Array = []
		for n: Node in get_tree().root.find_children("*", "Node3D", true, false):
			if n.has_method("_log_name") and bool(n.get("footsteps")):
				rigs.append(n.call("_log_name", "-"))
		alog("rigs", str(rigs.size()), "", 0.0, 1.0)
		for r: String in rigs:
			_alog.store_line("\t\trig\t%s" % r)

func logging() -> bool:
	return _alog != null

## Dev: one line of the audio log (see `_alog`). Callers outside this script use it for the players they own.
func alog(kind: String, name: String, bus: String = "", vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if _alog == null:
		return
	var st: Array = []
	for f: Dictionary in get_stack().slice(1):
		if str(f.source).ends_with("sfx.gd"):
			continue
		st.append("%s:%d %s" % [str(f.source).get_file(), int(f.line), str(f.function)])
		if st.size() >= 5:
			break
	_alog.store_line("%.3f\t%d\t%s\t%s\t%s\t%.1f\t%.3f\t%s\t%s" % [_alog_t, Engine.get_process_frames(), kind, name, bus, vol_db, pitch, log_who, " < ".join(st)])
	_alog.flush()

func _stream(path: String, loop: bool = false) -> AudioStream:
	if not _cache.has(path):
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s is AudioStreamOggVorbis and loop:
			s.loop = true
		_cache[path] = s
	return _cache[path]

## Public entry point used everywhere. Old names keep working: combat names go through `event`, "footstep" through
## `footstep`. jitter < 0 uses the pool's own pitch jitter (0.06 for flat sounds).
func play(sound: String, vol_db: float = 0.0, pitch: float = 1.0, jitter: float = -1.0) -> void:
	if sound == "footstep":
		footstep("", 1.0, vol_db, pitch, false)
		return
	if sound == "swing" or sound == "swing_heavy":
		# the caller's pitch said how hard the swing was (fast and thin or slow and heavy); the whoosh tier carries that now
		var inten := 1.4 if sound == "swing_heavy" else (0.4 if pitch >= 1.15 else (1.4 if pitch < 0.78 else 1.0))
		event("swing", inten, vol_db, pow(pitch, 0.5), jitter)
		return
	if sound == "parry_perfect":
		sound = "parry"
	if EVENTS.has(sound) and _n(str(EVENTS[sound][0].pool)) > 0:     # "roll" keeps its old single file until roll_1.wav exists
		event(sound, 1.0, vol_db, pitch, jitter)
		return
	var file := sound
	if VARIANTS.has(sound):
		file = "%s_%d" % [sound, _pick(sound, VARIANTS[sound])]
	var s := _stream("res://assets/audio/sfx/%s.wav" % file)
	if s == null:
		return
	var j := 0.06 if jitter < 0.0 else jitter
	var pt := pitch * randf_range(1.0 - j, 1.0 + j)
	var p := _voice("misc", _now(), int(s.get_length() / pt * 1000.0) + 30)
	p.stream = s
	p.bus = "Interface" if INTERFACE_SOUNDS.has(sound) else ("Ambience" if AMBIENT_SOUNDS.has(sound) else ("Cinematics" if CINEMATIC_SOUNDS.has(sound) else "Combat"))
	p.volume_db = vol_db
	p.pitch_scale = pt
	p.play()
	if _alog:
		alog("sfx", file, p.bus, vol_db, pt)

## A named combat event: `intensity` 0.1-2 (1 is a normal strike) scales level, nudges pitch down when harder and
## decides which layers and, for "swing", which whoosh weight (under 0.6 light, over 1.25 heavy) play. Returns false
## when the retrigger gap of its voice family swallowed it.
func event(sound: String, intensity: float = 1.0, vol_db: float = 0.0, pitch: float = 1.0, jitter: float = -1.0) -> bool:
	if not EVENTS.has(sound):
		return false
	intensity = clampf(intensity, 0.1, 2.0)
	var layers: Array = EVENTS[sound]
	var pool := _resolve(layers[0].pool, intensity)
	if _n(pool) < 1:
		return false
	if not _gate(POOLS[pool][4], _now()):
		return false
	var whoosh := str(layers[0].pool) == "@whoosh"
	var v := vol_db + clampf(linear_to_db(intensity), -18.0, 6.0)
	var pt := pitch if whoosh else pitch * pow(intensity, -0.1)
	var pan := 0.0
	if whoosh:
		_pan_side = -_pan_side
		pan = _pan_side * randf_range(0.2, 0.7)
	for k in layers.size():
		var lay: Dictionary = layers[k]
		if k > 0 and (intensity < float(lay.get("min", 0.0)) or randf() > float(lay.get("chance", 1.0))):
			continue
		var lp_name := pool if k == 0 else _resolve(lay.pool, intensity)
		if _n(lp_name) < 1:
			continue
		var idx := _pick(lp_name, _n(lp_name))
		var lv := v + float(lay.get("vol", 0.0))
		var at := float(lay.get("at", 0.0))
		if at > 0.0:
			get_tree().create_timer(at).timeout.connect(_launch.bind(lp_name, idx, lv, pt, jitter, pan))
		else:
			_launch(lp_name, idx, lv, pt, jitter, pan)
	return true

## One footstep: heel thud, scuff and surface texture are in the file; an armoured (heavy) character may add a quiet
## armour jingle. Exactly one step sound per call: a call inside the step family's retrigger gap is dropped.
## surface: stone, metal (deck), grass (earth), snow, water (shallow); "" uses `default_surface`.
## weight: 1 is a normal armoured knight, bigger is heavier (louder, lower, jingles more).
func footstep(surface: String = "", weight: float = 1.0, vol_db: float = 0.0, pitch: float = 1.0, jingle: bool = true) -> bool:
	var key := surface.to_lower().replace(" ", "_").replace("/", "_").replace("-", "_")
	var sf: String = SURFACES.get(key, SURFACES.get(default_surface, "stone"))
	var pool := "step_" + sf
	if not _gate("step", _now()):
		if _alog:
			alog("step_gated", pool, "", vol_db, pitch)
		return false
	weight = clampf(weight, 0.4, 2.5)
	var v := vol_db + 6.0 * (weight - 1.0)
	var pt := pitch * pow(weight, -0.35)
	_launch(pool, _pick(pool, _n(pool)), v, pt, -1.0, 0.0)
	_gate_at["step"] = _now()   # a cold stream load inside _launch must not count against the retrigger gap
	if jingle and weight >= 0.9 and randf() < clampf(0.2 + 0.4 * (weight - 0.9), 0.0, 0.6):
		_launch("jingle", _pick("jingle", _n("jingle")), v - 20.0, pitch * randf_range(0.9, 1.1), -1.0, 0.0)
	return true

## Number of variants of a pool: the listed count, or more when higher-numbered files exist (generated extras:
## tools/sfx_buy.py writes clash_7.wav and so on). Counted once; numbered files must be contiguous.
func _n(pool: String) -> int:
	if not POOLS.has(pool):
		return 1
	if not _counts.has(pool):
		var n := int(POOLS[pool][1])
		while ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % (str(POOLS[pool][0]) % (n + 1))):
			n += 1
		_counts[pool] = n
	return _counts[pool]

func _now() -> int:
	return Time.get_ticks_msec()

func _resolve(pool: String, intensity: float) -> String:
	if pool == "@whoosh":
		return "whoosh_light" if intensity < 0.6 else ("whoosh_heavy" if intensity > 1.25 else "whoosh_med")
	return pool

## A variant number 1..count that is never the one played last for this key.
func _pick(key: String, count: int) -> int:
	var last := int(_last.get(key, 0))
	var i := randi_range(1, count)
	if count > 1 and last >= 1 and last <= count:
		i = randi_range(1, count - 1)
		if i >= last:
			i += 1
	_last[key] = i
	return i

## True when the family may start another event now; records the start.
func _gate(fam: String, now: int) -> bool:
	var gap := int(float(FAMILIES[fam][1]) * 1000.0) if FAMILIES.has(fam) else 0
	if now - int(_gate_at.get(fam, -1000000)) < gap:
		return false
	_gate_at[fam] = now
	return true

func _active(fam: String, now: int) -> int:
	var n := 0
	for v: Dictionary in _voices:
		if v.end > now and v.fam == fam:
			n += 1
	return n

## Hands out a player for a new voice. A family at its limit loses its oldest voice; with no free player the oldest
## voice of any family goes.
func _voice(fam: String, now: int, dur_ms: int) -> AudioStreamPlayer:
	var live: Array = []
	for v: Dictionary in _voices:
		if v.end > now:
			live.append(v)
	_voices = live
	var cap := int(FAMILIES[fam][0]) if FAMILIES.has(fam) else 999
	while _active(fam, now) >= cap:
		_steal(fam)
	var used := {}
	for v: Dictionary in _voices:
		used[v.p] = true
	var p: AudioStreamPlayer = null
	for q: AudioStreamPlayer in _pool:
		if not used.has(q):
			p = q
			break
	if p == null:
		p = _steal("")
	_voices.append({"p": p, "fam": fam, "t0": now, "end": now + dur_ms})
	return p

func _steal(fam: String) -> AudioStreamPlayer:
	for i in _voices.size():
		var v: Dictionary = _voices[i]
		if fam == "" or v.fam == fam:
			v.p.stop()
			_voices.remove_at(i)
			return v.p
	return _pool[0]

func _launch(pool: String, idx: int, vol_db: float, pitch: float, jitter: float, pan: float) -> void:
	var spec: Array = POOLS[pool]
	var s := _stream("res://assets/audio/sfx/%s.wav" % (str(spec[0]) % idx))
	if s == null:
		return
	var j: float = float(spec[2]) if jitter < 0.0 else jitter
	var pt := pitch * randf_range(1.0 - j, 1.0 + j)
	var p := _voice(spec[4], _now(), int(s.get_length() / pt * 1000.0) + 30)
	p.stream = s
	p.bus = "CombatL" if pan < -0.15 else ("CombatR" if pan > 0.15 else "Combat")
	p.volume_db = vol_db + randf_range(-float(spec[3]), float(spec[3]))
	p.pitch_scale = pt
	p.play(randf() * PREROLL * 0.9)
	if _alog:
		alog("pool", str(spec[0]) % idx, p.bus, p.volume_db, pt)

## Picks a bespoke track when one has been produced, else the fallback.
func music_for(preferred: String, fallback: String, fade: float = 1.5) -> void:
	music(preferred if ResourceLoader.exists("res://assets/audio/music/%s.ogg" % preferred) else fallback, fade)

func music(track: String, fade: float = 1.5) -> void:
	if track == _music_name:
		return
	_music_name = track
	if _alog:
		alog("music", track, "Music", -5.0)
	set_intensity("explore" if (track.begins_with("explore") or track == "menu") else "combat")
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
## Adaptive music: the same cue is opened up, held back or muffled as the fight changes.
## "explore" soft and distant · "combat" full · "danger" muffled, as if heard through blood.
const INTENSITY := {"explore": [5200.0], "combat": [20000.0], "danger": [1500.0]}
var _intensity := ""
var _filter: AudioEffectLowPassFilter
func set_intensity(state: String, fade: float = 0.8) -> void:
	if state == _intensity or not INTENSITY.has(state):
		return
	_intensity = state
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	if _filter == null:
		_filter = AudioEffectLowPassFilter.new()
		_filter.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(idx, _filter)
	create_tween().tween_property(_filter, "cutoff_hz", float(INTENSITY[state][0]), fade)

func current_music() -> String:
	return _music_name

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
	if _alog:
		alog("music_layer", track, "Music", -5.0)
	_layer.volume_db = -40.0
	_layer.play(_music[_music_i].get_playback_position())
	_layer_tween.tween_property(_layer, "volume_db", -5.0, fade)
	_layer_tween.parallel().tween_property(_music[_music_i], "volume_db", -14.0, fade)

func ambience(track: String) -> void:
	if track == _amb_name:
		return
	_amb_name = track
	if _alog:
		alog("ambience", track, "Ambience", _amb.volume_db)
	_amb.stop()
	if track != "":
		var s := _stream("res://assets/audio/amb/%s.ogg" % track, true)
		if s:
			_amb.stream = s
			_amb.play()

