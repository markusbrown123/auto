class_name HeirReturn
extends CineScene
## Generation III comes down to the Inheritance Engine. Nobody wakes on the floor this time: the heir walks in through
## the door the second generation left by. The cradle is empty. In the block stands the blade the second of the house
## carried to the throne: the Engine keeps what the house earns, and has called it home (the same item, with every
## record it had; Game.take_fallen_weapon() when it is taken up). Lyra: "I kept all of it. I could not keep them."
## One interaction, as in the Awakening: TAKE UP YOUR SWORD. Then out, into the white of the door, and the Approach.
##
## HeirReturn.Naming is the short step before it: who the last heir is. The line follows the lineage the player chose
## (grandson or granddaughter); only a name is asked.
## Dev: hold_at = "enter" | "sword" | "taken".

const WALK := FighterRig.ROAD_SPEED

var arena: Arena
var knight: CineActor
var _rack: Node3D
var _rack_sword: Node3D
var _rack_light: OmniLight3D
var _lyra: OmniLight3D
var _prompt: Button
var _taken := false

func _ready() -> void:
	begin()
	arena = Arena.new()
	add_child(arena)
	arena.build("chamber")
	arena.env.ambient_light_energy = 1.25
	_lyra = arena.get_node("Lyra")
	_rack = arena.get_node("Rack")
	# the door stands open, as it was left
	(arena.get_node("Door") as Node3D).position.y = 5.2
	(arena.get_node("DoorGlow") as OmniLight3D).light_energy = 5.0
	knight = CineActor.knight(self)
	knight.set_armed(false)
	knight.footsteps = true
	knight.position = Vector3(0, 0, -9.4)
	knight.rotation.y = PI
	_stand_sword()
	var key := SpotLight3D.new()
	key.light_color = Color("#ffd9a0")
	key.light_energy = 3.4
	key.spot_range = 10.0
	key.spot_angle = 44.0
	key.position = Vector3(0.6, 5.0, 3.0)
	add_child(key)
	key.look_at(Vector3(1.2, 0.6, 0.0))
	Sfx.ambience("crypt")
	Sfx.music("", 1.5)
	_run()

## The blade that was left, point down in the block: drawn as the heir's own look draws it.
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
	_rack_light.light_color = Color("#7fe6d8")
	_rack_light.light_energy = 1.6
	_rack_light.omni_range = 3.4
	_rack_light.position = Vector3(-0.5, 1.5, 0.6)
	_rack.add_child(_rack_light)

func _process(delta: float) -> void:
	super(delta)
	if _lyra:
		var speaking: bool = Story.busy and Story._name.text == "LYRA"
		_lyra.light_energy = lerpf(_lyra.light_energy, (2.2 + sin(_clock * 9.0) * 0.5) if speaking else 0.35, 1.0 - exp(-delta * 6.0))
	if _rack_light and not _taken:
		_rack_light.light_energy = 1.6 + 0.5 * sin(_clock * 2.4)
	if _prompt and cam:
		var p: Vector3 = _rack.global_position + Vector3(0, 0.95, 0)
		_prompt.visible = not cam.is_position_behind(p)
		_prompt.position = cam.unproject_position(p) - _prompt.size * 0.5

func _run() -> void:
	# from inside the room, toward the open door: a figure against the light
	cam.cut(Vector3(1.9, 1.5, 4.9), Vector3(0.0, 1.3, -5.0), 42.0)
	cam.move(Vector3(1.5, 1.45, 4.3), Vector3(0.2, 1.2, -3.0), 9.0)
	cards.fade(0.0, 1.4)
	await walk(knight, Vector3(0, 0, -3.2), WALK).finished
	if _over:
		return
	if _held("enter"):
		return
	await walk(knight, Vector3(0.9, 0, 1.4), WALK).finished
	if _over:
		return
	face(knight, Vector3(0, 0, 0.0), 0.7)
	# the cradle, with nobody at its foot
	# (clear of the machine pylon that stands at about (-1.64, 4.93): from further out the camera ended inside it, and
	# its amber band filled the frame)
	cam.cut(Vector3(-1.9, 1.15, 4.0), Vector3(0.2, 0.7, 0.9), 40.0)
	cam.move(Vector3(-1.5, 1.2, 4.2), Vector3(0.4, 0.8, 0.4), 8.0)
	if not await _w(1.2):
		return
	if not await _say("gen3_engine"):
		return
	# the block, and what stands in it
	face(knight, _rack.position, 0.8)
	cam.cut(Vector3(1.1, 2.35, 5.15), Vector3(0.9, 1.0, -1.0), 52.0)
	Sfx.play("levelup", -12.0, 0.7)
	if not await _w(0.9):
		return
	_offer()

func _offer() -> void:
	_prompt = Awakening._Hotspot.new()
	_prompt.label = "TAKE UP YOUR SWORD" if not knight.dual else "TAKE UP YOUR BLADES"
	cards.add_child(_prompt)
	cards.move_child(_prompt, 0)
	_prompt.modulate.a = 0.0
	create_tween().tween_property(_prompt, "modulate:a", 1.0, 0.5)
	_prompt.pressed.connect(_take)
	if hold_at == "sword":
		cards.veil.color.a = 0.0
		return
	if auto:
		if await _w(1.4):
			_take()

func _take() -> void:
	if _taken or _over:
		return
	_taken = true
	Sfx.play("ui_confirm", -4.0)
	if _prompt:
		_prompt.queue_free()
		_prompt = null
	var spot: Vector3 = _rack.position + (knight.position - _rack.position).normalized() * 0.95
	cam.move(Vector3(4.55, 1.35, 1.55), _rack.position + Vector3(-0.3, 1.05, 0.2), 2.6, 44.0)
	await walk(knight, spot, WALK).finished
	if _over:
		return
	if not await _w(0.4):
		return
	# steel in the hand: the very blade, with what was done to it
	take_sword()
	_rack_sword.visible = false
	knight.set_armed(true)
	Sfx.play("swing", -6.0, 0.8)
	Sfx.play("armor", -8.0)
	_rack_light.light_energy = 5.0
	create_tween().tween_property(_rack_light, "light_energy", 0.5, 0.9)
	cam.move(Vector3(4.35, 1.4, 1.2), knight.position + Vector3(0, 1.2, 0), 1.6)
	if not await _w(1.5):
		return
	if _held("taken"):
		return
	# and out the way they came, the camera behind them
	var out := Vector3(0, 0, -4.6)
	face(knight, out, 0.8)
	if not await _w(0.8):
		return
	cam.ride(knight, Vector3(0.75, 1.62, 3.3), Vector3(0.1, 1.3, -3.0))
	cam.fov = 46.0
	await walk(knight, out, WALK).finished
	if _over:
		return
	cards.fade(1.0, 2.6, true)
	await walk(knight, Vector3(0, 0, -9.8), WALK).finished
	if _over:
		return
	_end()

## The blade is taken up (recorded once: Game.take_fallen_weapon).
func take_sword() -> void:
	if not Game.profile.is_empty() and not Game.fallen_weapon().is_empty():
		Game.take_fallen_weapon()

func _closing() -> void:
	# skipping the scene does not leave the blade in the block: it is the heir's either way
	take_sword()
	if not Game.profile.is_empty():
		Game.profile.flags["gen3_arrived"] = true
		Game.save()
	if cards:
		cards.veil.color = Color(1.0, 0.97, 0.9, 1.0)       # the Approach opens out of the white of the door


## Who the last heir is: one field, over the family's mark. `named(name)` when it is answered.
class Naming extends Control:
	signal named(heir_name: String)
	var auto := false
	var _field: LineEdit

	func _ready() -> void:
		UI.apply(self)
		UI.full(self)
		var bg: ColorRect = UI.full(ColorRect.new())
		bg.color = Color(0.01, 0.01, 0.012, 1.0)
		add_child(bg)
		var centre: CenterContainer = UI.full(CenterContainer.new())
		add_child(centre)
		var v := VBoxContainer.new()
		v.custom_minimum_size.x = 520
		v.add_theme_constant_override("separation", 8)
		centre.add_child(v)
		var body := str(Game.profile.get("body", "m"))
		var who: Dictionary = Generations.def(3)
		var mark := Emblem.new(120.0, UI.GOLD)
		mark.custom_minimum_size = Vector2(120, 120)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(mark)
		for row: Array in [[str(who.chapter).to_upper(), 30, UI.BONE, "title"],
				["%s of the first of the house. Twenty-four years after the second fell." % str(who.relation[body]), 19, UI.DIM, "body"],
				["Raised on the story of two graves, one of which is empty.", 19, UI.DIM, "body"]]:
			var l := UI.label(str(row[0]), int(row[1]), row[2], str(row[3]))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
		v.add_child(UI.spacer(6))
		var cap := UI.label("A NAME, IF THEY GAVE YOU ONE", 15, UI.GOLD_DIM.lightened(0.3), "head")
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cap)
		# the same field the first choosing of a knight uses (CharacterSelect): sixteen letters, and it may be left empty
		_field = LineEdit.new()
		_field.placeholder_text = "The Last"
		_field.max_length = 16
		_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_field.custom_minimum_size = Vector2(440, 46)
		_field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(_field)
		v.add_child(UI.spacer(6))
		var go := UI.button("Take up the road", 22, 300)
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		go.pressed.connect(answer)
		v.add_child(go)
		_field.text_submitted.connect(func(_t: String): answer())
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.8)
		if auto:
			get_tree().create_timer(1.2).timeout.connect(answer)

	var _answered := false
	func answer() -> void:
		if _answered:
			return
		_answered = true
		named.emit(_field.text.strip_edges())
