class_name ForgeSeq
extends Control
## Orren at work: the piece on the anvil, three hammer blows with sparks, then what changed.
## The upgrade itself is already paid for and saved before this starts, so a tap skips straight
## to the result and nothing is lost if the game closes mid-way.

signal finished

const HIT_AT := [1.0, 1.6, 2.2]
const REVEAL_AT := 3.0
const SPOT := Vector3(-1.5, 0.0, 1.0)

var backdrop: Backdrop
var item: Dictionary
var level := 0
var rows: Array = []            # [label, before, after, delta text]
var _t := 0.0
var _hits := 0
var _revealed := false
var _piece: Node3D
var _sparks: CPUParticles3D
var _flash: OmniLight3D
var _cam: Array = []
var _hint: Label

func _init(bd: Backdrop, item_id: String, new_level: int, stat_rows: Array) -> void:
	backdrop = bd
	item = Db.item(item_id)
	level = new_level
	rows = stat_rows

func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var anvil := backdrop.forge_spot(SPOT)
	var top: Node3D = anvil.get_node("Top")
	_piece = Node3D.new()
	top.add_child(_piece)
	var slot: String = item.slot
	var placed := false
	if slot == "weapon":
		var m: Dictionary = Duel.weapon_model(str(item.id))
		if PropModel.exists(m.weapon_model):
			var cls: String = item.cls
			var holder := Node3D.new()
			_piece.add_child(holder)
			# along the anvil's face, flat side down
			holder.basis = Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, -PI * 0.5)
			var k := 0.8
			var len: float = float(PropModel.LENGTH.get(cls, 1.1)) * k
			holder.position = Vector3(-len * (0.5 - float(PropModel.GRIP.get(cls, 0.11))), 0.02, 0)
			placed = PropModel.weapon(holder, m.weapon_model, cls, m.get("weapon_tint"), k) > 0.0
	elif slot == "shield":
		var holder := Node3D.new()
		_piece.add_child(holder)
		holder.basis = Basis(Vector3.RIGHT, -PI * 0.5)
		holder.position.y = 0.05
		placed = PropModel.shield(holder, "res://assets/models/%s.glb" % str(item.id), 0.5)
	if not placed:
		# armour has no model of its own yet: a plate of its metal stands in
		var plate := BoxMesh.new()
		plate.size = Vector3(0.34, 0.04, 0.2)
		var mi := MeshInstance3D.new()
		mi.mesh = plate
		mi.position.y = 0.02
		mi.material_override = Look.flat(Color(str(item.get("look", {}).get("metal", "#8a8a8c"))), 0.4, 0.9)
		_piece.add_child(mi)
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = maxi(6, int(30.0 * Game.particle_scale()))
	_sparks.lifetime = 0.55
	_sparks.explosiveness = 0.95
	_sparks.direction = Vector3(0, 1, 0.3)
	_sparks.spread = 55.0
	_sparks.initial_velocity_min = 1.6
	_sparks.initial_velocity_max = 4.2
	_sparks.gravity = Vector3(0, -9.0, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.036, 0.036)
	_sparks.mesh = q
	_sparks.material_override = Look.particle(Color("#ffb648"))
	_sparks.position = Vector3(0.05, 0.06, 0)
	top.add_child(_sparks)
	_flash = OmniLight3D.new()
	_flash.light_color = Color("#ffc878")
	_flash.light_energy = 0.0
	_flash.omni_range = 3.5
	_flash.position = Vector3(0.05, 0.35, 0.15)
	top.add_child(_flash)
	_cam = [backdrop.cam_pos, backdrop.cam_look]
	backdrop.move_camera(SPOT + Vector3(0.5, 1.4, 1.3), SPOT + Vector3(0.25, 0.8, 0.0), bool(Game.settings.reduce_motion))
	var m2 := UI.margin(get_viewport(), 10)
	add_child(m2)
	_hint = UI.label("Tap to skip", 17, UI.DIM)
	_hint.size_flags_horizontal = Control.SIZE_SHRINK_END
	_hint.size_flags_vertical = Control.SIZE_SHRINK_END
	m2.add_child(_hint)
	var head := UI.title("Orren's Forge", 22)
	head.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	m2.add_child(head)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch and e.pressed and not _revealed:
		_t = REVEAL_AT
		accept_event()

func _process(delta: float) -> void:
	_t += delta
	_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 22.0)
	if _revealed:
		return
	while _hits < HIT_AT.size() and _t >= HIT_AT[_hits] and _t < REVEAL_AT:
		_sparks.restart()
		_flash.light_energy = 2.5 if Game.settings.reduce_flash else 7.0
		Sfx.play("clash", -5.0, 0.86 + 0.09 * _hits)
		Game.haptic(25, 0.5)
		_hits += 1
	if _t >= REVEAL_AT:
		_reveal()

func _reveal() -> void:
	_revealed = true
	_hint.visible = false
	Sfx.play("ui_confirm", -4.0)
	# to the right of the anvil, so the piece stays in view
	var side := UI.margin(get_viewport(), 40)
	add_child(side)
	var p := UI.panel()
	p.custom_minimum_size.x = 430
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UI.label("Improved", 16, UI.DIM))
	v.add_child(UI.title("%s +%d" % [item.name, level], 22, Db.rarity_color(item)))
	v.add_child(UI.rule())
	for r in rows:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var k := UI.label(str(r[0]), 18, UI.DIM)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(k)
		h.add_child(UI.label("%s  →  %s" % [r[1], r[2]], 18, UI.BONE, "bold"))
		h.add_child(InvGlyph.new("up", Color("#8fb37a")))
		h.add_child(UI.label(str(r[3]), 18, Color("#8fb37a"), "bold"))
		v.add_child(h)
	if level >= Stats.MAX_UPGRADE:
		v.add_child(UI.label("Perfected. Orren can do no more for it.", 17, UI.GOLD))
	v.add_child(UI.spacer(4))
	var b := UI.button("Continue", 18, 220)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_finish)
	v.add_child(b)
	p.modulate.a = 0.0
	create_tween().tween_property(p, "modulate:a", 1.0, 0.01 if Game.settings.reduce_motion else 0.3)

func _finish() -> void:
	_piece.queue_free()
	_sparks.queue_free()
	_flash.queue_free()
	backdrop.move_camera(_cam[0], _cam[1], bool(Game.settings.reduce_motion))
	finished.emit()
	queue_free()
