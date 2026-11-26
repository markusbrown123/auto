class_name Opening
extends Node3D
## The opening: the fall of the immortal kingdoms in six shots, one to a line of the narrator, all in one
## hall that is first lit and full, and then dark and empty. It says what happened and not what it was.
## About forty seconds. Any tap after two seconds ends it.

signal finished

const SEEN_FILE := "user://opening_seen"
const SKIP_AFTER := 2.0
## Who stands in the hall: guardians and their guard, as shapes against the light.
const ROW_R := ["frostbound_king", "throne_guard", "gravewarden", "crypt_warden"]
const ROW_L := ["forgotten_monarch", "glacier_brute", "hollow_executioner", "throne_guard"]

var arena: Arena
var cam: CineCam
var ui: CanvasLayer
var figures: Array = []
var _veil: ColorRect
var _hint: Label
var _over := false
var _clock := 0.0
var _mob: OmniLight3D            # the light of the crowd at the doors
var _wake: Array = []            # [light, mesh material, delay]: the machines that come back on
var _wake_t := -1.0
var _throne_glow: OmniLight3D

static func seen_before() -> bool:
	return FileAccess.file_exists(Game._p(SEEN_FILE))

static func mark_seen() -> void:
	var f := FileAccess.open(Game._p(SEEN_FILE), FileAccess.WRITE)
	if f:
		f.store_string("1")

func _ready() -> void:
	arena = Arena.new()
	add_child(arena)
	arena.build("throne")
	cam = CineCam.new()
	add_child(cam)
	_people()
	_machines()
	_mob = OmniLight3D.new()
	_mob.light_color = Color("#ff5a22")
	_mob.light_energy = 0.0
	_mob.omni_range = 26.0
	_mob.omni_attenuation = 0.8
	_mob.position = Vector3(0, 2.2, 15.0)
	add_child(_mob)
	_throne_glow = OmniLight3D.new()
	_throne_glow.light_color = Color("#ffd890")
	_throne_glow.light_energy = 0.0
	_throne_glow.omni_range = 22.0
	_throne_glow.position = Vector3(0, 6.0, -13.0)
	add_child(_throne_glow)
	ui = CanvasLayer.new()
	ui.layer = 70                # over the subtitles, so one tap anywhere is the skip
	add_child(ui)
	_veil = UI.full(ColorRect.new())
	_veil.color = Color(0.01, 0.01, 0.012, 1.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_veil.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed and _clock >= SKIP_AFTER:
			skip())
	ui.add_child(_veil)
	_hint = UI.label("TAP TO SKIP", 13, UI.DIM, "bold")
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_hint.offset_left = -150
	_hint.offset_top = 22
	_hint.offset_right = -28
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.0
	ui.add_child(_hint)
	var tw := create_tween()
	tw.tween_interval(SKIP_AFTER)
	tw.tween_property(_hint, "modulate:a", 0.55, 0.6)
	Sfx.ambience("")
	Sfx.music_for("theme", "menu", 2.0)
	_grade(1.0, 0.0)
	_run()

func _people() -> void:
	for row: Array in [[ROW_R, 1.0], [ROW_L, -1.0]]:
		var ids: Array = row[0]
		for i in ids.size():
			var id: String = ids[i]
			if not Db.foes.has(id):
				continue
			var look := CineActor.foe_look(id)
			look["scale"] = minf(float(look.get("scale", 1.0)), 1.3)
			var f := FighterRig.new()
			add_child(f)
			f.build(look, true)
			f.time_scale = 0.35          # they stand; they do not fidget
			f.position = Vector3(row[1] * 3.3, 0, 4.5 - i * 3.4)
			f.rotation.y = PI - row[1] * 1.15      # turned in toward the aisle
			figures.append(f)

## Lamps set into the floor of the aisle, dead until the last line.
func _machines() -> void:
	for i in 9:
		for sx: float in [-1.0, 1.0]:
			var mat := Look.glow(Color("#5fe0c8") if i % 3 != 2 else Color("#ffb45a"), 0.0)
			mat.albedo_color = Color(0.03, 0.03, 0.03)
			var m := arena.box(Vector3(0.12, 0.05, 1.1), Vector3(sx * 1.25, 0.03, 6.0 - i * 2.2), mat)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var l: OmniLight3D = null
			if sx > 0.0 and i % 2 == 0:
				l = OmniLight3D.new()
				l.light_color = mat.emission
				l.light_energy = 0.0
				l.omni_range = 5.0
				l.position = Vector3(0, 0.5, 6.0 - i * 2.2)
				add_child(l)
			_wake.append([l, mat, i * 0.22])

## The light of the hall: `life` 1 at its height (warm, bright, fires lit), 0 long dead (cold, dim, fogged).
func _grade(life: float, time: float) -> void:
	var t: Dictionary = arena.theme
	var env := arena.env
	var to := {
		"tonemap_exposure": lerpf(0.85, 1.75, life),
		"ambient_light_energy": lerpf(0.55, 2.1, life),
		"ambient_light_color": Color("#27323e").lerp(Color("#7a5a3a"), life),
		"fog_light_color": Color("#0c1118").lerp(Color("#5a3a1c"), life),
		"fog_density": lerpf(0.03, 0.008, life),
	}
	var sun_c := Color("#7f9fc8").lerp(Color("#ffd9a0"), life)
	var sun_e := lerpf(0.35, 2.4, life)
	for f: Array in arena.fires:
		f[1] = lerpf(0.0, 3.4, life)
	for p in arena.find_children("*", "CPUParticles3D", true, false):
		if (p as CPUParticles3D).lifetime < 1.0:          # the flames; the dust stays
			(p as CPUParticles3D).emitting = life > 0.3
	if time <= 0.0:
		for k: String in to:
			env.set(k, to[k])
		arena.sun.light_color = sun_c
		arena.sun.light_energy = sun_e
		return
	var tw := create_tween().set_parallel(true)
	for k: String in to:
		tw.tween_property(env, k, to[k], time)
	tw.tween_property(arena.sun, "light_color", sun_c, time)
	tw.tween_property(arena.sun, "light_energy", sun_e, time)

# ================================================================ the shots
func _run() -> void:
	# 1. the hall at its height, seen from the doors
	cam.cut(Vector3(0.0, 7.5, 17.0), Vector3(0, 5.2, -16.0), 52.0)
	cam.move(Vector3(0.0, 5.6, 11.5), Vector3(0, 5.0, -16.0), 9.0)
	create_tween().tween_property(_throne_glow, "light_energy", 3.5, 2.0)
	create_tween().tween_property(_veil, "color:a", 0.0, 1.6)
	await _wait(1.3)
	if _over:
		return
	Story.play("opening", true)
	await _line(1)
	if _over:
		return
	# 2. "Then men became gods": from the floor, up at the seat they made
	cam.cut(Vector3(2.2, 0.5, -5.0), Vector3(0.0, 6.0, -17.5), 46.0)
	cam.move(Vector3(1.4, 0.7, -6.6), Vector3(0.0, 7.4, -17.5), 5.0)
	await _line(2)
	if _over:
		return
	# 3. bodies that could not grow old: along the line of them, each a shape against the fire
	cam.cut(Vector3(-0.9, 1.5, 7.4), Vector3(4.2, 1.75, 3.6), 38.0)
	cam.move(Vector3(-0.9, 1.6, -3.2), Vector3(4.2, 1.85, -6.4), 10.5, -1.0, Tween.TRANS_LINEAR)
	await _line(3)
	if _over:
		return
	# 4. the people they ruled: a red light from the doors behind us, growing
	cam.drift = 0.07
	cam.cut(Vector3(0.4, 1.3, 13.5), Vector3(0, 2.6, -8.0), 44.0)
	cam.move(Vector3(0.0, 1.5, 9.6), Vector3(0, 2.4, -8.0), 6.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_mob, "light_energy", 9.0, 4.6).set_ease(Tween.EASE_IN)
	tw.tween_property(arena.env, "fog_light_color", Color("#6a1c0c"), 4.6)
	tw.tween_property(_throne_glow, "light_energy", 0.8, 4.0)
	await _line(4)
	if _over:
		return
	# 5. the same hall, three hundred years on
	await _dip(func():
		cam.drift = 0.02
		_mob.light_energy = 0.0
		_throne_glow.light_energy = 0.0
		_grade(0.0, 0.0)
		for f: FighterRig in figures:
			f.time_scale = 30.0          # they are long fallen by the time we look again
			f.die(1.0 if f.position.x > 0.0 else -1.0)
		cam.cut(Vector3(0.0, 5.4, 11.0), Vector3(0, 4.6, -16.0), 52.0)
		cam.move(Vector3(0.0, 6.6, 15.5), Vector3(0, 4.4, -16.0), 6.5))
	if _over:
		return
	for f: FighterRig in figures:
		f.time_scale = 1.0
	await _wait_line(4.6, 5)
	if _over:
		return
	#    …and one of them, where it fell
	var fallen: FighterRig = figures[1] if figures.size() > 1 else null
	if fallen:
		var p := fallen.global_position
		cam.cut(p + Vector3(-2.6, 0.45, 2.2), p + Vector3(0.2, 0.3, 0.2), 36.0)
		cam.move(p + Vector3(-2.2, 0.6, 2.9), p + Vector3(0.2, 0.3, 0.2), 6.0)
	await _line(5)
	if _over:
		return
	# 6. "We were wrong": in the dark, down the length of the floor, something is switching itself back on
	cam.cut(Vector3(0.0, 0.42, 9.0), Vector3(0, 2.6, -16.0), 44.0)
	cam.move(Vector3(0.0, 0.6, 7.0), Vector3(0, 3.4, -16.0), 5.0)
	_wake_t = 0.0
	Sfx.play("levelup", -10.0, 0.5)
	create_tween().tween_property(_throne_glow, "light_color", Color("#5fe0c8"), 0.1)
	create_tween().tween_property(_throne_glow, "light_energy", 5.0, 2.4).set_delay(2.0)
	await _story_end()
	await _wait(2.6)
	if _over:
		return
	# cut to black: the next light is the chamber's
	Sfx.music("", 1.2)
	var out := create_tween()
	out.tween_property(_veil, "color:a", 1.0, 0.3)
	await out.finished
	_end()

# ================================================================ helpers
func _dip(change: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 1.0, 0.35)
	tw.tween_callback(change)
	tw.tween_interval(0.45)
	tw.tween_property(_veil, "color:a", 0.0, 0.9)
	await get_tree().create_timer(0.85).timeout

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _line_now() -> int:
	if not Story.busy:
		return -1
	var lines: Array = Story.data.scenes["opening"].lines
	for i in lines.size():
		if str(Story.data.lines[lines[i]].text) == Story._text.text:
			return i
	return -1

func _line(i: int) -> void:
	while not _over and Story.busy and _line_now() < i:
		await get_tree().process_frame

## Waits `t` seconds, or less if the narrator has already reached line `i`.
func _wait_line(t: float, i: int) -> void:
	var left := t
	while not _over and left > 0.0 and Story.busy and _line_now() < i:
		await get_tree().process_frame
		left -= get_process_delta_time()

func _story_end() -> void:
	while not _over and Story.busy:
		await get_tree().process_frame

func _process(delta: float) -> void:
	_clock += delta
	if _mob.light_energy > 0.0:
		_mob.position.x = sin(_clock * 3.1) * 1.5
		_mob.omni_range = 26.0 + sin(_clock * 11.0) * 1.5
	if _wake_t >= 0.0:
		_wake_t += delta
		for w: Array in _wake:
			var k := clampf((_wake_t - float(w[2])) / 0.25, 0.0, 1.0)
			var pulse: float = k * (1.6 + 0.9 * sin(_clock * 5.0 - float(w[2]) * 6.0))
			(w[1] as StandardMaterial3D).emission_energy_multiplier = pulse * 2.2
			(w[1] as StandardMaterial3D).albedo_color = Color(0.03, 0.03, 0.03).lerp((w[1] as StandardMaterial3D).emission, clampf(pulse / 2.0, 0.0, 1.0))
			if w[0]:
				(w[0] as OmniLight3D).light_energy = pulse * 0.9

## Ends it now: a tap, a test, or a player who has seen it.
func skip() -> void:
	if _over:
		return
	Story.stop()
	Sfx.music("", 0.6)
	_end()

func _end() -> void:
	if _over:
		return
	_over = true
	_veil.color.a = 1.0
	mark_seen()
	finished.emit()
