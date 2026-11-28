class_name Awakening
extends Node3D
## The awakening chamber (Stage 1 of docs/AAA_STAGES.md; the room is src/world/chamber.gd).
## The chosen knight lies in the stasis cradle. The seal lets go and the cage swings back; Lyra speaks through the
## grille; the knight comes to (head, a first breath, the hands) and gets up the way a body in armour does after
## years (the get-up clip, slowed: onto a side, a hand on the bed, a knee, up). The sword they chose stands in the
## holder beside the cradle, lit; the one interaction is to take it up: the knight walks to it, reaches, closes the
## hand on the grip and draws it up out of the clamps, and from that moment it is in the hand.
## The door will not open. Beside it, in a maintenance housing, something flickers as the knight passes: the
## Witness, dormant. A tap wakes it; it rises out of its cup, speaks, and the door answers to it. Then out, through
## the passage, with the Witness ahead, to the outer doorway (Chamber.EXIT_END): the hand-off to the world.
##
## Taps: the sword, the housing; a tap otherwise moves a line of dialogue on.
## Hand-off (Stage 3): `reached_exit(knight, witness)` fires at Chamber.EXIT_END. With `handoff` true the scene stops
## there and leaves both standing (the caller takes over and calls skip() when it is done with the scene); otherwise
## it fades to white and emits `finished`, which is what the Approach expects today.

signal finished
signal reached_exit(knight: CineActor, witness: WitnessDrone)

const SEAT := Vector3(0, 0, 1.78)      # the foot of the cradle (Prologue: where the forebear sits down)
const WALK := FighterRig.ROAD_SPEED   # metres a second
const GETUP := "getup"                # the get-up clip (Explosive, MIT; tools/bake_anims.gd)
const GETUP_RATE := 0.72              # slowed: a body in armour after years
const GETUP_END := 3.95               # seconds into the clip where the knight stands

var auto := false                # dev captures: the prompts answer themselves
var start_at := ""               # dev captures: "sword" (standing, the ring up), "door" (sword in hand, before the door)
var handoff := false
var arena: Arena
var cam: CineCam
var knight: CineActor
var drone: WitnessDrone
var ui: CanvasLayer
var _veil: ColorRect
var _key: SpotLight3D
var _lyra: OmniLight3D
var _rack: Node3D
var _rack_sword: Node3D          # the knight's own weapon, a copy of what is in their hand, standing in the holder
var _rack_light: SpotLight3D
var _hilt := Vector3.ZERO        # world: the standing sword's grip point
var _hilt_top := Vector3.ZERO    # world: the top of its hilt (the ring is drawn here)
var _prompt: Control
var _prompt_at := Vector3.ZERO
var _over := false
var _clock := 0.0
var _taken := false
var _woke_it := false
var _wlamp: OmniLight3D
var _wlens: StandardMaterial3D
var _flicker := 0.15             # how hard the housing's lamp is trying (0.15 dormant, 1 woken)
# procedural layers over the rig, applied after it each frame (this node's process_priority puts it after the knight)
var _lay := 0.0                  # 0..1: the lying-knight layer (head, chest, hands) is shown
var _lift := 0.0                 # radians: the head lifted off the bed
var _turn := 0.0                 # radians: the head turned toward the voice
var _breath := 0.0               # radians: the chest's first breath
var _curl_r := 0.12
var _curl_l := 0.12
var _look := Vector3.INF         # standing: a point the head turns to
var _look_w := 0.0
var _reach_w := 0.0              # 0..1: the sword hand is placed by IK on `_reach_at`, closed round `_reach_dir`
var _reach_at := Vector3.ZERO
var _reach_dir := Vector3.DOWN
var _reach_curl := -1.0          # <0: leave the fingers to the rig
var _held := false               # the standing copy rides the hand
var _held_o := Transform3D.IDENTITY
var _held_k := 0.0               # 0..1: from the grip as taken to the rig's own way of holding it
var _lean := 0.0                 # radians: the chest bowed toward what the hand reaches for

func _ready() -> void:
	process_priority = 100
	arena = Arena.new()
	add_child(arena)
	arena.build("chamber")
	_lyra = arena.get_node("Lyra")
	_rack = arena.get_node("Rack")
	_key = arena.get_node("Key")
	_rack_light = arena.get_node("RackLight")
	_wlamp = arena.get_node("WitnessLamp")
	var lens := arena.get_node_or_null("Housing/HousingLens") as MeshInstance3D
	if lens:
		_wlens = lens.material_override as StandardMaterial3D
	Chamber.lock_door_now(arena)
	knight = CineActor.knight(self)
	knight.set_armed(false)
	knight.footsteps = true
	knight.position = Chamber.LIE_AT
	knight.rotation.y = PI
	knight.hold(GETUP, 0.0)
	knight.time_scale = 0.0          # held on the clip's first frame: lying on the bed
	_lay = 1.0
	_stand_sword()
	_dormant_witness()
	cam = CineCam.new()
	add_child(cam)
	ui = CanvasLayer.new()
	ui.layer = 40
	add_child(ui)
	_veil = UI.full(ColorRect.new())
	_veil.color = Color(0.01, 0.01, 0.012, 1.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_veil)
	_key.light_energy = 0.0
	Sfx.ambience("crypt")
	Sfx.music("", 1.0)
	_run()

## The equipped weapon, point down in the holder: a copy of the very model the knight's hand carries (whatever the
## character select chose, and however it is drawn: gear model or kit model), so the one taken up is the one held.
func _stand_sword() -> void:
	_rack_sword = knight.weapon_r.duplicate()
	add_child(_rack_sword)
	_rack_sword.top_level = true
	_rack_sword.visible = true
	# how far the blade runs below the grip, from the model itself (+Y is along the blade in the weapon's frame)
	var lo := 0.0
	var hi := 0.0
	for mi: MeshInstance3D in _rack_sword.find_children("*", "MeshInstance3D", true, false):
		var into := (_rack_sword.global_transform.affine_inverse() * mi.global_transform) if mi.is_inside_tree() else _rel(mi, _rack_sword)
		var box := into * mi.get_aabb()
		lo = minf(lo, box.position.y)
		hi = maxf(hi, box.end.y)
	if hi <= 0.05:
		hi = maxf(knight.weapon_len, 0.7)
	var point: Node3D = _rack.get_node("SwordPoint")
	var face := Basis(Vector3.UP, deg_to_rad(Chamber.HOLDER_YAW))
	# blade down, its edge turned across the holder (flat toward the knight's approach)
	var b := face * Basis(Vector3.FORWARD, PI) * Basis(Vector3.UP, PI * 0.5)
	_hilt = point.global_position + Vector3(0, hi - 0.03, 0)
	_hilt_top = _hilt + Vector3(0, -lo, 0)
	_rack_sword.global_transform = Transform3D(b, _hilt)

static func _rel(n: Node3D, up_to: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != up_to:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

## The Witness lies dark in its cup in the housing, behind the closed lid.
func _dormant_witness() -> void:
	drone = WitnessDrone.new()
	add_child(drone)
	drone.build()
	drone.dormant(Chamber.housing_cup() + Vector3(0, -0.05, 0), deg_to_rad(30.0))

# ================================================================ the scene
func _run() -> void:
	if start_at == "sword" or start_at == "door":
		_stand_now()
		_rack_light.light_energy = 3.0
		_key.light_energy = 3.2
		_veil.color.a = 0.0
		Story.stop()
		if start_at == "sword":
			_frame_sword()
			_face_to(_rack.position, 0.9)
			_offer_sword()
		else:
			_rack_sword.visible = false
			knight.set_armed(true)
			_hide_shield()
			knight.position = Vector3(0.4, 0, -2.6)
			knight.rotation.y = 0.0
			_to_door()
		return
	# 1. dark; the clamp lamps of the seal, then the oculus lamp comes up on a figure lying in the cradle
	cam.cut(Vector3(-1.15, 0.62, 0.55), Vector3(0.05, 0.22, -0.45), 38.0)
	cam.move(Vector3(-1.05, 0.66, 0.7), Vector3(0.05, 0.24, -0.45), 8.0)
	create_tween().tween_property(_veil, "color:a", 0.0, 2.4)
	create_tween().tween_property(_key, "light_energy", 5.0, 3.2).set_trans(Tween.TRANS_SINE)
	await _wait(2.6)
	if _over:
		return
	# 2. the seal lets go: a thud through the deck, the clamp lamps die, the cage swings back off the bed
	Sfx.play("thump", -4.0, 0.5)
	Sfx.play("rattle", -12.0, 0.55)
	Chamber.release_seal(arena, 2.6)
	_puff(Chamber.CRADLE_AT + Vector3(0, 0.1, 0), 1.2)
	cam.cut(Vector3(1.85, 1.35, 1.9), Vector3(0.0, 0.35, -0.2), 44.0)
	cam.move(Vector3(1.6, 1.15, 1.55), Vector3(0.0, 0.32, -0.25), 4.0)
	await _wait(0.6)
	Sfx.play("swell", -10.0, 0.5)
	await _wait(2.2)
	if _over:
		return
	# 3. "Can you hear me?": a first breath, the fingers, the head comes off the bed toward the voice
	cam.cut(Vector3(-1.05, 0.62, -1.15), Vector3(0.1, 0.25, -0.5), 36.0)
	cam.move(Vector3(-0.95, 0.68, -1.0), Vector3(0.1, 0.28, -0.5), 6.0)
	Story.play("awakening", true)
	knight.breath_hold = 0.6           # the first breaths after years: heard and seen, until the knight is up (Stage 2 API)
	var w := create_tween()
	w.tween_property(self, "_breath", 0.16, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	w.parallel().tween_property(self, "_curl_r", 0.75, 0.5).set_delay(0.5)
	w.tween_property(self, "_breath", 0.05, 1.6).set_trans(Tween.TRANS_SINE)
	w.parallel().tween_property(self, "_curl_l", 0.6, 0.6)
	w.parallel().tween_property(self, "_lift", 0.28, 1.6).set_trans(Tween.TRANS_SINE)
	w.tween_property(self, "_turn", -0.45, 1.4).set_trans(Tween.TRANS_SINE)
	w.parallel().tween_property(self, "_curl_r", 0.35, 1.0)
	await _line(1)
	if _over:
		return
	# 4. "Who are you?" ... "Someone who has been waiting a very long time": the knight gets up
	await _line(2)
	if _over:
		return
	cam.cut(Vector3(2.2, 1.25, 2.45), Vector3(0.0, 0.75, -0.1), 44.0)
	cam.move(Vector3(2.3, 1.55, 2.9), Vector3(0.0, 1.15, 0.0), 6.0)
	await _get_up()
	if _over:
		return
	await _line(3)
	if _over:
		return
	# 5. "What happened here?": the knight looks for the voice; over the shoulder to the grille
	var grille := Chamber.grille_at()
	_face_to(grille, 1.6)
	_look = grille
	create_tween().tween_property(self, "_look_w", 1.0, 1.2)
	await _line(4)
	if _over:
		return
	var ots := _over_shoulder(knight.position + Vector3(0, 1.7, 0), grille, 1.5, 0.5)
	cam.cut(ots[0], ots[1], 40.0)
	cam.move(ots[0] + (ots[1] - ots[0]).normalized() * 0.3, ots[1], 4.5)
	await _line(5)
	if _over:
		return
	# and the reverse: the face, the grille's light on it
	var face := knight.position + Vector3(0, 1.62, 0)
	var rev := face + (grille - face).normalized() * 1.25 + Vector3(0, -0.05, 0)
	rev += (grille - face).normalized().cross(Vector3.UP) * 0.25
	cam.cut(rev, face, 34.0)
	cam.move(rev + (face - rev).normalized() * 0.15, face, 4.0)
	await _line(6)
	if _over:
		return
	# 6. "Then it worked": the holder lights; the whole room, the sword in its cradle beside the machine
	Sfx.music_for("hub", "sanctuary", 2.5)
	create_tween().tween_property(_rack_light, "light_energy", 3.0, 1.8).set_trans(Tween.TRANS_SINE)
	Sfx.play("swell", -14.0, 0.7)
	_frame_sword()
	_look = _hilt
	await _story_end()
	if _over:
		return
	_face_to(_rack.position, 1.0)
	_offer_sword()

## The shot the sword is offered in: past the knight to the holder, the whole of it lit.
func _frame_sword() -> void:
	cam.cut(Vector3(-1.25, 1.8, 3.55), Vector3(1.15, 1.0, -0.4), 50.0)
	cam.move(Vector3(-0.95, 1.7, 3.35), Vector3(1.25, 1.0, -0.45), 6.0)

## Gets up out of the cradle on the get-up clip, slowed; the lying layer hands over to it as it starts.
func _get_up() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_lay", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	knight.time_scale = GETUP_RATE
	knight._ta = 0.0
	Sfx.play("rustle", -6.0, 0.8)
	Sfx.play("armor", -10.0, 0.8)
	var t := 0.0
	var rattled := false
	while not _over and knight._ta < GETUP_END:
		await get_tree().process_frame
		t += get_process_delta_time()
		if not rattled and knight._ta > 2.0:
			rattled = true
			Sfx.play("armor", -9.0, 0.9)
	if _over:
		return
	# standing: the rig's own stance takes over from the clip's last frame
	knight.time_scale = 1.0
	knight.release(1.1)
	create_tween().tween_property(knight, "breath_hold", 0.25, 2.0)
	await _wait(0.9)
	get_tree().create_timer(2.5).timeout.connect(func(): knight.breath_hold = -1.0)

## Straight to standing at the foot of the bed (dev starts).
func _stand_now() -> void:
	knight.release(0.0)
	knight._w = 0.0
	knight.time_scale = 1.0
	knight.position = Chamber.LIE_AT * Vector3(1, 0, 1)
	_lay = 0.0
	Chamber.seal_open_now(arena)

# ---------------------------------------------------------------- the sword
func _offer_sword() -> void:
	_prompt = _Hotspot.new()
	_prompt.label = "TAKE UP YOUR SWORD" if not knight.dual else "TAKE UP YOUR BLADES"
	_prompt_at = _hilt_top + Vector3(0, 0.06, 0)
	ui.add_child(_prompt)
	ui.move_child(_prompt, 0)
	_prompt.modulate.a = 0.0
	create_tween().tween_property(_prompt, "modulate:a", 1.0, 0.5)
	_prompt.pressed.connect(_take_sword)
	if auto:
		await _wait(1.6)
		_take_sword()

func _drop_prompt() -> void:
	if _prompt:
		var p := _prompt
		_prompt = null
		var tw := create_tween()
		tw.tween_property(p, "modulate:a", 0.0, 0.25)
		tw.tween_callback(p.queue_free)

func _take_sword() -> void:
	if _taken or _over:
		return
	_taken = true
	Sfx.play("ui_confirm", -4.0)
	_drop_prompt()
	# the knight walks to it; the camera waits low beside the holder, looking across the hilt
	var face := Basis(Vector3.UP, deg_to_rad(Chamber.HOLDER_YAW))
	var front := face * Vector3(0, 0, 1)
	var side := face * Vector3(1, 0, 0)
	var spot: Vector3 = Vector3(_hilt.x, 0, _hilt.z) + front * 0.56 + side * 0.12
	var wait_at: Vector3 = _hilt + side * 1.35 + front * 0.55 + Vector3(0, -0.1, 0)
	cam.move(wait_at, knight.position.lerp(spot, 0.7) + Vector3(0, 1.25, 0), 2.4, 44.0)
	_look_w = 0.0
	await _walk_to(spot)
	if _over:
		return
	knight.walking = false
	_face_to(_rack.position, 0.5)
	_look = _hilt
	_look_w = 0.8
	cam.move(wait_at + front * 0.15, _hilt + (spot - _hilt) * 0.35 + Vector3(0, 0.1, 0), 3.0, 40.0)
	await _wait(0.55)
	if _over:
		return
	# the reach: a bow over it, the hand to the grip, the fingers close
	_reach_at = _hilt
	_reach_dir = _rack_sword.global_transform.basis.y.normalized()
	_reach_curl = 0.15
	var r := create_tween()
	r.tween_property(self, "_reach_w", 1.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	r.parallel().tween_property(self, "_lean", 0.16, 0.85).set_trans(Tween.TRANS_SINE)
	r.tween_property(self, "_reach_curl", 1.0, 0.22)
	await r.finished
	if _over:
		return
	# the grip: from here the blade is in the hand
	_held = true
	_held_o = _hand_xf().affine_inverse() * _rack_sword.global_transform
	knight.set_armed(true)
	knight.weapon_r.visible = false
	_hide_shield()
	Sfx.play("rattle", -9.0, 0.8)
	Chamber.open_clamps(arena, 0.4)
	Sfx.play("thump", -12.0, 0.9)
	await _wait(0.35)
	if _over:
		return
	# drawn up out of the holder: the camera low and in front, the light on the blade
	Sfx.play("draw", -4.0, 0.9)
	var up := create_tween()
	up.tween_property(self, "_reach_at", _hilt + Vector3(0, 0.42, 0) + front * 0.1, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	up.parallel().tween_property(self, "_lean", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	var low := Vector3(spot.x, 0, spot.z) + front * 1.55 - side * 0.55 + Vector3(0, 0.75, 0)
	cam.cut(low, knight.position + Vector3(0, 1.3, 0) - front * 0.25, 36.0)
	cam.move(low + front * 0.25 + Vector3(0, 0.1, 0), knight.position + Vector3(0, 1.4, 0) - front * 0.25, 3.0)
	var flare := create_tween()
	flare.tween_property(_rack_light, "light_energy", 6.0, 0.5)
	flare.tween_property(_rack_light, "light_energy", 1.2, 1.6)
	await up.finished
	if _over:
		return
	await _wait(0.5)
	# the hand comes back to the knight's own carry, the blade with it, and settles into the rig's hold
	var back := create_tween()
	back.tween_property(self, "_reach_w", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(self, "_held_k", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	await back.finished
	if _over:
		return
	_held = false
	_reach_curl = -1.0
	_rack_sword.visible = false
	knight.weapon_r.visible = true
	_look_w = 0.0
	await _wait(0.6)
	if _over:
		return
	_to_door()

## The hand's frame (world): the sword rides it once it is taken.
func _hand_xf() -> Transform3D:
	var s := knight.skin
	if s == null:
		return knight.weapon_r.global_transform
	return s.skel.global_transform * s.skel.get_bone_global_pose(s.bone["RightHand"])

func _hide_shield() -> void:
	# (the shield is not in this room: it is taken up with the rest of the kit outside; nothing appears on the arm here)
	if knight.shield:
		knight.shield.visible = false
	if knight.dual and knight.weapon_l:
		knight.weapon_l.visible = false

# ---------------------------------------------------------------- the door, and what is beside it
## To the door, past the housing (its lamp catches as the knight goes by); the door will not open.
func _to_door() -> void:
	var by_housing := Vector3(-0.9, 0, -3.5)
	var at_door := Vector3(0.15, 0, -4.55)
	cam.ride(knight, Vector3(0.85, 1.7, 3.1), Vector3(0.0, 1.35, -3.0))
	cam.fov = 48.0
	# round the head of the cradle (its machine and the opened cage), then along the wall toward the door
	if knight.position.x > 0.8:
		await _walk_to(Vector3(1.45, 0, -2.5))
		if _over:
			return
	await _walk_to(by_housing)
	if _over:
		return
	# it notices: the housing's lamp catches as the knight passes
	create_tween().tween_property(self, "_flicker", 0.55, 0.4)
	Sfx.play("crack", -18.0, 1.6)
	await _walk_to(at_door, 0.5)
	if _over:
		return
	knight.walking = false
	cam.let_go()
	# the door does not answer: the lamp over it stays red, the bars knock in their brackets
	var door_view := at_door + Vector3(1.3, 1.45, 1.9)
	cam.move(door_view, Vector3(-0.2, 1.7, Chamber.DOOR_Z), 1.6, 46.0)
	await _wait(0.7)
	if _over:
		return
	Sfx.play("thump", -6.0, 0.7)
	Sfx.play("rattle", -8.0, 0.65)
	_knock_bars()
	_blink_door_lamp()
	await _wait(1.2)
	if _over:
		return
	# and in the housing beside it, the light comes and goes, harder
	create_tween().tween_property(self, "_flicker", 1.0, 0.6)
	var cup := Chamber.housing_cup()
	_face_to(cup, 1.0)
	_look = cup
	_look_w = 1.0
	var ots := _over_shoulder(knight.position + Vector3(0, 1.7, 0), cup, 1.35, -0.45)
	cam.cut(ots[0], ots[1], 42.0)
	cam.move(ots[0] + (cup - ots[0]).normalized() * 0.35, cup, 4.0)
	Story.play("witness_call", true)
	await _story_end()
	if _over:
		return
	_offer_witness()

func _knock_bars() -> void:
	var bars := arena.get_node_or_null("DoorBars") as Node3D
	if bars:
		var tw := create_tween()
		for i in 3:
			tw.tween_property(bars, "position:z", bars.position.z + 0.025, 0.05)
			tw.tween_property(bars, "position:z", bars.position.z, 0.09)

func _blink_door_lamp() -> void:
	var lamp := arena.get_node_or_null("DoorLampLens") as MeshInstance3D
	var dl := arena.get_node_or_null("DoorLamp") as OmniLight3D
	if lamp == null or dl == null:
		return
	var m := lamp.material_override as StandardMaterial3D
	var tw := create_tween()
	for i in 3:
		tw.tween_property(m, "emission_energy_multiplier", 4.0, 0.08)
		tw.parallel().tween_property(dl, "light_energy", 1.4, 0.08)
		tw.tween_property(m, "emission_energy_multiplier", 1.8, 0.3)
		tw.parallel().tween_property(dl, "light_energy", 0.3, 0.3)

func _offer_witness() -> void:
	_prompt = _Hotspot.new()
	_prompt.label = "WAKE IT"
	_prompt_at = Chamber.housing_cup() + Vector3(0, 0.05, 0)
	ui.add_child(_prompt)
	ui.move_child(_prompt, 0)
	_prompt.modulate.a = 0.0
	create_tween().tween_property(_prompt, "modulate:a", 1.0, 0.5)
	_prompt.pressed.connect(_wake_witness)
	if auto:
		await _wait(1.6)
		_wake_witness()

func _wake_witness() -> void:
	if _woke_it or _over:
		return
	_woke_it = true
	Sfx.play("ui_confirm", -4.0)
	_drop_prompt()
	_mark_found()
	var cup := Chamber.housing_cup()
	var inward := -Chamber.bay_dir(Chamber.HOUSING_BAY)
	var spot := Vector3(cup.x, 0, cup.z) + inward * 0.62 + inward.cross(Vector3.UP) * 0.1
	await _walk_to(spot)
	if _over:
		return
	knight.walking = false
	_face_to(cup, 0.5)
	# close on the housing, the knight's hand coming into frame
	var side := inward.cross(Vector3.UP)
	var close := cup + inward * 0.95 - side * 0.55 + Vector3(0, 0.12, 0)
	cam.cut(close, cup + Vector3(0, -0.02, 0), 38.0)
	cam.move(close + (cup - close) * 0.12, cup, 5.0)
	# the hand on the lid; it gives, and slides up into the body
	_reach_at = cup + inward * 0.12 + Vector3(0, 0.02, 0)
	_reach_dir = side
	_reach_curl = 0.25
	var r := create_tween()
	r.tween_property(self, "_reach_w", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	r.parallel().tween_property(self, "_lean", 0.08, 0.7)
	await r.finished
	if _over:
		return
	var lid := arena.get_node_or_null("Housing/HousingCover") as Node3D
	if lid:
		create_tween().tween_property(lid, "position:y", lid.position.y + 0.36, 0.9).set_trans(Tween.TRANS_SINE).set_delay(0.15)
	Sfx.play("rattle", -12.0, 1.3)
	Sfx.play("swell", -12.0, 1.2)
	_puff(cup + inward * 0.1, 0.4)
	var back := create_tween()
	back.tween_property(self, "_reach_w", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_delay(0.3)
	back.parallel().tween_property(self, "_lean", 0.0, 0.8).set_delay(0.3)
	await _wait(1.3)
	if _over:
		return
	# it speaks from its cup, lit, before it moves
	var on_line := func(who: String, lid_id: String): _witness_line(who, lid_id)
	Story.line_started.connect(on_line)
	Story.play("witness_chamber", true)
	await _story_end()
	if Story.line_started.is_connected(on_line):
		Story.line_started.disconnect(on_line)
	if _over:
		return
	_open_door()

## What the Witness does on each line of its scene.
func _witness_line(who: String, line_id: String) -> void:
	if _over:
		return
	var cup := Chamber.housing_cup()
	var inward := -Chamber.bay_dir(Chamber.HOUSING_BAY)
	var side := inward.cross(Vector3.UP)
	var head := knight.position + Vector3(0, 1.66, 0)
	match line_id:
		"witness_discovery_02":
			# "Ah. At last.": the seam catches, it lifts a finger's breadth in its cup, its ring turns to the knight
			drone.wake(0.035)
			drone.look_at_point(head)
			_flicker = 0.0
			Sfx.play("swell", -12.0, 1.6)
		"witness_discovery_03", "witness_discovery_06":
			var face := head
			var p := face + (cup - face).normalized() * 0.95 + side * 0.2
			cam.cut(p, face, 34.0)
		"witness_discovery_04", "witness_discovery_05":
			var c2 := cup + inward * 0.8 + side * 0.4 + Vector3(0, 0.05, 0)
			cam.cut(c2, drone.global_position, 36.0)
			cam.move(c2 + (drone.global_position - c2) * 0.1, drone.global_position, 5.0)
		"witness_discovery_07":
			# "Lift me down": the knight's hand to the prongs; they open; it comes up and out of the cup
			_reach_at = cup + inward * 0.06
			_reach_dir = side
			_reach_curl = 0.4
			var r := create_tween()
			r.tween_property(self, "_reach_w", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
			r.tween_callback(func():
				_open_prongs()
				Sfx.play("rattle", -12.0, 1.5)
				drone.fly_to(cup + inward * 0.42 + Vector3(0, 0.3, 0)))
			r.tween_property(self, "_reach_w", 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_delay(0.3)
			var two := cup.lerp(knight.position, 0.5) + side * 1.9 + inward * 0.6 + Vector3(0, 1.45, 0)
			cam.cut(two, cup.lerp(head, 0.5) + Vector3(0, -0.1, 0), 44.0)
			cam.move(two - side * 0.25, cup.lerp(head, 0.5) + Vector3(0, -0.1, 0), 6.0)
		"witness_discovery_08":
			# Lyra: it turns its ring to the grille
			drone.look_at_point(Chamber.grille_at(), 3.0)
		"witness_discovery_09":
			drone.look_at_point(head)
		"witness_chamber_01":
			# the cradle, and the knight it kept
			drone.look_at_point(Chamber.CRADLE_AT + Vector3(0, 0.4, 0), 2.2)
			var p2 := head + Vector3(0, -0.15, 0) - (Chamber.CRADLE_AT - head).normalized() * 1.2 + side * 0.4
			cam.move(p2, drone.global_position.lerp(head, 0.5), 3.0, 42.0)
		"witness_chamber_02":
			# "This door answers to the old seals": it goes to the lock
			drone.idle()
			drone.fly_to(Vector3(0.0, 1.75, Chamber.DOOR_Z + 0.85))
			cam.move(knight.position + Vector3(1.6, 1.5, 1.7), Vector3(-0.1, 1.6, Chamber.DOOR_Z), 2.5, 50.0)

func _open_prongs() -> void:
	var pr := arena.get_node_or_null("Housing/HousingClamps") as Node3D
	if pr == null:
		return
	for p: Node3D in pr.get_children():
		var s := -1.0 if p.name.ends_with("L") else 1.0
		create_tween().tween_property(p, "rotation_degrees:y", s * -55.0, 0.35).set_trans(Tween.TRANS_BACK)

## The Witness at the lock: it scans, the bars draw back, the slab rises, the daylight comes in. Then it comes to the
## knight's shoulder, and they go.
func _open_door() -> void:
	drone.look_at_point(Vector3(0, 1.4, Chamber.DOOR_Z + 0.45), 1.4)
	drone.speaking(true)
	await _wait(0.9)
	drone.speaking(false)
	if _over:
		return
	Sfx.play("thump", -5.0, 0.6)
	Sfx.play("rattle", -9.0, 0.7)
	var t := Chamber.open_door(arena, 3.4)
	create_tween().tween_callback(func(): Sfx.play("shield_scrape", -8.0, 0.45)).set_delay(0.9)
	create_tween().tween_callback(func(): Sfx.play("guard_break", -12.0, 0.5)).set_delay(t)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(arena.env, "fog_light_color", Color("#5a5e56"), t)
	tw.tween_property(arena.env, "ambient_light_energy", 1.6, t)
	_face_to(Vector3(0, 0, Chamber.DOOR_Z), 0.9)
	cam.move(knight.position + Vector3(-1.2, 1.25, 2.3), Vector3(0.1, 2.0, Chamber.DOOR_Z), t, 50.0)
	await _wait(t * 0.6)
	if _over:
		return
	# it comes back to the knight, and stays: from here it follows (roams, leads, looks)
	drone.idle()
	drone.attach(knight)
	drone.roam(true)
	drone.tuck(false)
	await _wait(t * 0.4 + 0.3)
	if _over:
		return
	_leave()

## Out through the door and down the passage, the camera behind, the Witness ahead; to the outer doorway.
func _leave() -> void:
	Story.play("first_road", true)
	cam.ride(knight, Vector3(0.75, 1.62, 3.3), Vector3(0.1, 1.3, -3.0))
	cam.fov = 46.0
	for i in Chamber.EXIT_PATH.size():
		var p: Vector3 = Chamber.EXIT_PATH[i]
		var last := i == Chamber.EXIT_PATH.size() - 1
		if last and not handoff:
			var d := knight.position.distance_to(p)
			var tw2 := create_tween()
			tw2.tween_interval(maxf(0.0, d / WALK - 1.4))
			tw2.tween_callback(func(): _veil.color = Color(1.0, 0.97, 0.9, 0.0))
			tw2.tween_property(_veil, "color:a", 1.0, 0.9)
		await _walk_to(p, 0.5)
		if _over:
			return
	knight.walking = false
	reached_exit.emit(knight, drone)
	if handoff:
		return
	_end()

## The scene's Witness is the one the profile now carries (a save made after this has found it).
func _mark_found() -> void:
	if Game.profile.is_empty():
		return
	Companion.mark_heard(Companion.discovery_id())          # (sets the profile's witness_found flag)

# ================================================================ helpers
func _face_to(point: Vector3, time: float) -> void:
	var d := point - knight.position
	var yaw := atan2(-d.x, -d.z)
	var from := knight.rotation.y
	create_tween().tween_property(knight, "rotation:y", from + wrapf(yaw - from, -PI, PI), time).set_trans(Tween.TRANS_SINE)

func _walk_to(point: Vector3, turn: float = 0.45) -> void:
	_face_to(point, turn)
	knight.walking = true
	var d := knight.position.distance_to(point)
	var tw := create_tween()
	tw.tween_property(knight, "position", point, d / WALK)
	await tw.finished

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

## [camera, look]: behind and beside `from` (a head), looking at `to`; `side` + is to the right of the line.
func _over_shoulder(from: Vector3, to: Vector3, back: float, side: float) -> Array:
	var d := to - from
	d.y = 0.0
	d = d.normalized()
	var right := d.cross(Vector3.UP)
	return [from - d * back + right * side + Vector3(0, 0.08, 0), to]

## A small cloud of dust off a surface that has just moved.
func _puff(at: Vector3, size: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = int(24 * size) + 6
	p.lifetime = 2.2
	p.explosiveness = 0.75
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6 * size
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.35
	p.gravity = Vector3(0, -0.06, 0)
	p.damping_min = 0.4
	p.damping_max = 0.8
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	q.material = Look.particle(Color(0.6, 0.57, 0.5, 0.22), false)
	p.mesh = q
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)

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

# ================================================================ per frame
func _process(delta: float) -> void:
	_clock += delta
	# the grille brightens while she is speaking
	var speaking: bool = Story.busy and Story.speaker == "lyra"
	_lyra.light_energy = lerpf(_lyra.light_energy, (1.4 + sin(_clock * 9.0) * 0.35) if speaking else 0.12, 1.0 - exp(-delta * 6.0))
	# the housing's failing lamp: it stutters, more when the knight is near or it has been noticed
	if _wlamp:
		var near := clampf(1.0 - knight.global_position.distance_to(Chamber.housing_cup()) / 3.5, 0.0, 1.0)
		var k := maxf(_flicker, near * 0.6) if _flicker > 0.0 else 0.0
		var stutter := 1.0 if fmod(_clock * (3.0 + k * 9.0), 1.0) < 0.35 + 0.3 * sin(_clock * 13.0) else 0.15
		_wlamp.light_energy = k * stutter * 0.6
		if _wlens:
			_wlens.emission_energy_multiplier = 0.2 + k * stutter * 2.4
	if _prompt:
		_prompt.visible = not cam.is_position_behind(_prompt_at)
		_prompt.position = cam.unproject_position(_prompt_at) - _prompt.size * 0.5
	_drive_body()

## The layers over the rig's pose: the waking body on the bed, the head turned to what it looks at, the bow and the
## hand placed on what it reaches for, the sword riding the hand.
func _drive_body() -> void:
	var s := knight.skin if knight else null
	if s == null or not s.ok:
		return
	var sk := s.skel
	var xs := sk.global_transform
	if _lay > 0.001:
		var lat := ((xs * _bone_at(s, "RightArm")) - (xs * _bone_at(s, "LeftArm"))).normalized()
		var spine := ((xs * _bone_at(s, "Head")) - (xs * _bone_at(s, "Neck"))).normalized()
		_turn_bone(s, "Spine2", lat, -_breath * _lay)
		_turn_bone(s, "Neck", lat, -_lift * 0.5 * _lay)
		_turn_bone(s, "Head", lat, -_lift * 0.5 * _lay)
		_turn_bone(s, "Head", spine, _turn * _lay)
		s.curl("Right", lerpf(0.12, _curl_r, _lay))
		s.curl("Left", lerpf(0.12, _curl_l, _lay))
	if _look_w > 0.001 and _look != Vector3.INF and _lay <= 0.001:
		var head := xs * _bone_at(s, "Head")
		var fwd := -knight.global_transform.basis.z
		var d := (_look - head)
		var yaw := clampf(wrapf(atan2(-d.x, -d.z) - atan2(-fwd.x, -fwd.z), -PI, PI), -1.0, 1.0) * _look_w
		var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.6, 0.45) * _look_w
		var right := fwd.cross(Vector3.UP).normalized()
		_turn_bone(s, "Neck", Vector3.UP, yaw * 0.4)
		_turn_bone(s, "Head", Vector3.UP, yaw * 0.6)
		_turn_bone(s, "Head", right, pitch * 0.7)
	if _lean > 0.001:
		var right2 := (-knight.global_transform.basis.z).cross(Vector3.UP).normalized()
		_turn_bone(s, "Spine1", right2, -_lean * 0.5)
		_turn_bone(s, "Spine2", right2, -_lean * 0.5)
	if _reach_w > 0.001:
		var body := knight.body.global_transform
		var inv := body.affine_inverse()
		var wrist: Vector3 = sk.get_bone_global_pose(s.bone["RightHand"]).origin
		var palm0: Vector3 = s._back * s._palm("Right", wrist)
		var axis0 := s.hand_axis("Right")
		var dir_b := (body.basis.inverse() * _reach_dir).normalized()
		var w := smoothstep(0.0, 1.0, _reach_w)
		var dir := dir_b if axis0 == Vector3.ZERO or axis0.dot(dir_b) < -0.95 else axis0.slerp(dir_b, w).normalized()
		s.grip_at("Right", palm0.lerp(inv * _reach_at, w), dir)
	if _reach_curl >= 0.0:
		s.curl("Right", _reach_curl)
	if _held:
		var h := _hand_xf()
		var o := _held_o
		if _held_k > 0.0:
			o = _held_o.interpolate_with(h.affine_inverse() * knight.weapon_r.global_transform, smoothstep(0.0, 1.0, _held_k))
		_rack_sword.global_transform = h * o

func _bone_at(s: SkinDriver, b: String) -> Vector3:
	return s.skel.get_bone_global_pose(s.bone[b]).origin

## Turns a bone (and so everything it carries) about a world axis.
func _turn_bone(s: SkinDriver, b: String, axis_world: Vector3, ang: float) -> void:
	if absf(ang) < 0.0001 or not s.bone.has(b):
		return
	var i: int = s.bone[b]
	var ax := (s.skel.global_transform.basis.inverse() * axis_world).normalized()
	var g := s.skel.get_bone_global_pose(i)
	s.skel.set_bone_global_pose(i, Transform3D(Basis(ax, ang) * g.basis, g.origin))

## Ends the scene now (tests, dev captures, or the caller after a hand-off).
func skip() -> void:
	if _over:
		return
	Story.stop()
	_mark_found()
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
