class_name Awakening
extends Node3D
## The resurrection chamber. The chosen knight comes to on the floor by the cradle, a voice in the wall
## speaks, the knight stands, takes up the sword that was left for them, and walks out through the door
## that opens. It ends walking away from the camera into daylight, which is where the Approach begins.
##
## One interaction: the sword. Everything else plays by itself; a tap moves a line of dialogue on.

signal finished

const SEAT := Vector3(0, 0, 1.78)
const STAND := Vector3(0, 0, 2.15)
const GRILLE := Vector3(-2.6, 2.4, -4.2)
const WALK := 1.35               # metres a second

var auto := false                # dev captures: the prompt answers itself
var start_at := ""               # dev captures: "sword" opens on the standing knight and the prompt
var arena: Arena
var cam: CineCam
var knight: CineActor
var ui: CanvasLayer
var _veil: ColorRect
var _key: SpotLight3D
var _lyra: OmniLight3D
var _rack: Node3D
var _rack_sword: Node3D
var _rack_light: OmniLight3D
var _prompt: Control
var _over := false
var _clock := 0.0
var _taken := false

func _ready() -> void:
	arena = Arena.new()
	add_child(arena)
	arena.build("chamber")
	_lyra = arena.get_node("Lyra")
	_rack = arena.get_node("Rack")
	knight = CineActor.knight(self)
	knight.set_armed(false)
	knight.footsteps = true
	knight.position = SEAT
	knight.rotation.y = PI
	knight.hold("wounded", 0.0)
	_stand_sword()
	cam = CineCam.new()
	add_child(cam)
	# one light, straight down on the cradle: the only thing in the dark at first
	_key = SpotLight3D.new()
	_key.light_color = Color("#ffd9a0")
	_key.light_energy = 0.0
	_key.spot_range = 9.0
	_key.spot_angle = 38.0
	_key.spot_attenuation = 0.8
	_key.shadow_enabled = true
	_key.position = Vector3(0.6, 5.0, 3.4)
	add_child(_key)
	_key.look_at(Vector3(0, 0.6, 1.6))
	ui = CanvasLayer.new()
	ui.layer = 40
	add_child(ui)
	_veil = UI.full(ColorRect.new())
	_veil.color = Color(0.01, 0.01, 0.012, 1.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_veil)
	Sfx.ambience("crypt")
	Sfx.music("", 1.0)
	_run()

## The equipped weapon, point down in the block.
func _stand_sword() -> void:
	_rack_sword = Node3D.new()
	_rack.add_child(_rack_sword)
	var look: Dictionary = knight.cfg
	var length := 1.0
	var model := str(look.get("weapon_model", ""))
	if PropModel.exists(model):
		length = PropModel.weapon(_rack_sword, model, str(look.get("weapon", "sword")), look.get("weapon_tint"), float(look.get("weapon_scale", 1.0)))
	else:
		knight._weapon_mesh(_rack_sword, str(look.get("weapon", "sword")), look)
		length = knight.weapon_len
	_rack_sword.rotation = Vector3(PI, 0.4, 0.06)
	_rack_sword.position = Vector3(0, 0.42 + length * 0.86, 0)
	_rack_light = OmniLight3D.new()
	_rack_light.light_color = Color("#ffc878")
	_rack_light.light_energy = 0.0
	_rack_light.omni_range = 3.2
	_rack_light.position = Vector3(-0.5, 1.5, 0.6)
	_rack.add_child(_rack_light)

# ================================================================ the scene
func _run() -> void:
	if start_at == "sword":
		knight.position = STAND
		knight.hold("idle", 0.0)
		_key.light_energy = 3.2
		_rack_light.light_energy = 2.2
		_veil.color.a = 0.0
		cam.cut(Vector3(1.2, 2.3, 6.0), Vector3(0.9, 1.0, -1.0), 50.0)
		_turn_to(_rack.position, 0.9)
		_offer_sword()
		return
	# low and close on a figure that is not moving
	cam.cut(Vector3(0.75, 0.42, 3.45), Vector3(0.0, 0.72, 1.7), 40.0)
	cam.move(Vector3(0.95, 0.5, 3.75), Vector3(0.0, 0.78, 1.7), 7.0)
	create_tween().tween_property(_veil, "color:a", 0.0, 2.2)
	create_tween().tween_property(_key, "light_energy", 6.5, 3.0)
	await _wait(2.0)
	if _over:
		return
	Story.play("awakening", true)
	await _line(2)
	if _over:
		return
	# "Someone who has been waiting a very long time": the knight gets up, and the camera gives them room
	knight.hold("idle", 2.6)
	create_tween().tween_property(knight, "position", STAND, 2.6).set_trans(Tween.TRANS_SINE)
	cam.move(Vector3(1.55, 1.3, 5.0), Vector3(0.0, 1.12, 2.1), 3.8, 42.0)
	create_tween().tween_property(_key, "light_energy", 3.2, 3.0)
	await _line(3)
	if _over:
		return
	# the knight looks for the voice
	_turn_to(GRILLE, 1.5)
	await _line(4)
	if _over:
		return
	# over the shoulder, toward the grille she speaks through
	cam.cut(Vector3(0.75, 1.72, 3.55), Vector3(-1.5, 1.75, -2.0), 40.0)
	cam.move(Vector3(0.55, 1.72, 3.4), Vector3(-1.7, 1.85, -2.0), 4.0)
	await _line(5)
	if _over:
		return
	# and the reverse: the face
	cam.cut(Vector3(-0.85, 1.5, 0.35), Vector3(0.0, 1.5, 2.15), 34.0)
	cam.move(Vector3(-0.7, 1.52, 0.6), Vector3(0.0, 1.52, 2.15), 4.0)
	await _line(6)
	if _over:
		return
	# "Then it worked": the whole room, the sword in its block, the door at the back
	cam.cut(Vector3(0.7, 2.5, 6.0), Vector3(0.8, 1.0, -1.0), 50.0)
	cam.move(Vector3(1.2, 2.3, 6.0), Vector3(0.9, 1.0, -1.0), 6.0)
	Sfx.music_for("hub", "sanctuary", 2.5)
	create_tween().tween_property(_rack_light, "light_energy", 2.2, 1.6)
	await _story_end()
	if _over:
		return
	_turn_to(_rack.position, 0.9)
	_offer_sword()

func _offer_sword() -> void:
	_prompt = _Hotspot.new()
	_prompt.label = "TAKE UP YOUR SWORD" if not knight.dual else "TAKE UP YOUR BLADES"
	ui.add_child(_prompt)
	ui.move_child(_prompt, 0)
	_prompt.modulate.a = 0.0
	create_tween().tween_property(_prompt, "modulate:a", 1.0, 0.5)
	_prompt.pressed.connect(_take_sword)
	if auto:
		await _wait(1.6)
		_take_sword()

func _take_sword() -> void:
	if _taken or _over:
		return
	_taken = true
	Sfx.play("ui_confirm", -4.0)
	if _prompt:
		var p := _prompt
		_prompt = null
		var tw := create_tween()
		tw.tween_property(p, "modulate:a", 0.0, 0.25)
		tw.tween_callback(p.queue_free)
	# the knight walks to it; the camera waits by the block
	var spot: Vector3 = _rack.position + (knight.position - _rack.position).normalized() * 0.95
	cam.move(Vector3(4.55, 1.35, 1.55), _rack.position + Vector3(-0.3, 1.05, 0.2), 2.6, 44.0)
	knight.release(0.35)
	await _walk_to(spot)
	if _over:
		return
	knight.walking = false
	await _wait(0.45)
	if _over:
		return
	# steel in the hand
	_rack_sword.visible = false
	knight.set_armed(true)
	Sfx.play("swing", -6.0, 0.8)
	Sfx.play("armor", -8.0)
	_rack_light.light_energy = 5.0
	create_tween().tween_property(_rack_light, "light_energy", 0.8, 0.9)
	cam.move(Vector3(4.35, 1.4, 1.2), knight.position + Vector3(0, 1.2, 0), 1.6)
	await _wait(1.3)
	if _over:
		return
	_leave()

## The door opens, and the knight walks out into the light with the camera behind them.
func _leave() -> void:
	var door: Node3D = arena.get_node("Door")
	var glow: OmniLight3D = arena.get_node("DoorGlow")
	Sfx.play("guard_break", -8.0, 0.6)
	Sfx.play("shield_scrape", -10.0, 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(door, "position:y", 5.2, 2.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "light_energy", 7.0, 2.6)
	tw.tween_property(arena.env, "fog_light_color", Color("#8a8672"), 2.6)
	tw.tween_property(arena.env, "ambient_light_energy", 1.5, 2.6)
	Story.play("first_road", true)
	var out := Vector3(0, 0, -4.6)
	_turn_to(out, 0.9)
	await _wait(0.9)
	if _over:
		return
	# from here to the end of the Approach the camera stays behind the walking knight
	cam.ride(knight, Vector3(0.75, 1.62, 3.3), Vector3(0.1, 1.3, -3.0))
	cam.fov = 46.0
	await _wait(1.2)
	if _over:
		return
	await _walk_to(out)
	if _over:
		return
	var tw2 := create_tween()
	tw2.tween_interval(maxf(0.0, 5.2 / WALK - 0.5))
	tw2.tween_callback(func(): _veil.color = Color(1.0, 0.97, 0.9, 0.0))
	tw2.tween_property(_veil, "color:a", 1.0, 0.45)
	await _walk_to(Vector3(0, 0, -9.8), 0.25)
	if _over:
		return
	_end()

# ================================================================ helpers
func _turn_to(point: Vector3, time: float) -> void:
	var d := point - knight.position
	var yaw := atan2(-d.x, -d.z)
	var from := knight.rotation.y
	create_tween().tween_property(knight, "rotation:y", from + wrapf(yaw - from, -PI, PI), time).set_trans(Tween.TRANS_SINE)

func _walk_to(point: Vector3, turn: float = 0.45) -> void:
	_turn_to(point, turn)
	knight.walking = true
	var d := knight.position.distance_to(point)
	var tw := create_tween()
	tw.tween_property(knight, "position", point, d / WALK)
	await tw.finished

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

## Which line of the scene being spoken is on screen (-1: none).
func _line_now() -> int:
	if not Story.busy:
		return -1
	var shown: String = Story._text.text
	for id: String in ["awakening", "first_road"]:
		var lines: Array = Story.data.scenes[id].lines
		for i in lines.size():
			if str(Story.data.lines[lines[i]].text) == shown:
				return i
	return -1

func _line(i: int) -> void:
	while not _over and Story.busy and _line_now() < i:
		await get_tree().process_frame

func _story_end() -> void:
	while not _over and Story.busy:
		await get_tree().process_frame

func _process(delta: float) -> void:
	_clock += delta
	# the grille brightens while she is speaking
	var speaking: bool = Story.busy and Story._name.text == "LYRA"
	_lyra.light_energy = lerpf(_lyra.light_energy, (2.2 + sin(_clock * 9.0) * 0.5) if speaking else 0.35, 1.0 - exp(-delta * 6.0))
	if _prompt:
		var p: Vector3 = _rack.global_position + Vector3(0, 0.95, 0)
		_prompt.visible = not cam.is_position_behind(p)
		_prompt.position = cam.unproject_position(p) - _prompt.size * 0.5

## Ends the scene now (tests, dev captures).
func skip() -> void:
	if _over:
		return
	Story.stop()
	_end()

func _end() -> void:
	if _over:
		return
	_over = true
	finished.emit()

## The one thing to tap: a ring that breathes, and what it does.
class _Hotspot extends Button:
	var label := ""
	var _t := 0.0
	func _init() -> void:
		flat = true
		custom_minimum_size = Vector2(190, 190)
		size = Vector2(190, 190)
		for s: String in ["focus", "hover", "pressed", "normal"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var k := 0.5 + 0.5 * sin(_t * 3.2)
		draw_arc(c, 44.0 + k * 7.0, 0.0, TAU, 48, Color(UI.GOLD, 0.95), 2.5, true)
		draw_arc(c, 60.0 + k * 12.0, 0.0, TAU, 48, Color(UI.GOLD, 0.35 * (1.0 - k)), 1.5, true)
		var f := UI.font("title")
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string_outline(f, Vector2(c.x - w * 0.5, size.y - 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color(0, 0, 0, 0.9))
		draw_string(f, Vector2(c.x - w * 0.5, size.y - 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UI.BONE)
