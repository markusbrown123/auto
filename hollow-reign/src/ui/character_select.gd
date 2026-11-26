class_name CharacterSelect
extends Control
## Who wakes. Both knights stand in the scene behind the menu; the camera travels from one to the other,
## a drag turns the one in view. The two are the same in every number: the choice is a body and a voice.

signal closed
signal confirmed(heraldry: String, body: String, knight_name: String)

const HERALDRY := [["Oxblood", "#3d0f0f"], ["Ash", "#34322e"], ["Verdigris", "#16332c"], ["Dusk", "#1c2240"], ["Bone", "#8a8270"]]
const BODIES := [
	["m", "The Knight", "Broad in the shoulder and slow to anger. Whoever he was, he was buried standing."],
	["f", "The Blade", "Lean, exact, and very still. Whoever she was, somebody made sure she kept her sword."],
]
const SPOT := {"m": Vector3(-1.7, 0, 0.6), "f": Vector3(1.7, 0, 0.6)}
const FACING := PI * 0.94

var body := "m"
var heraldry := "#3d0f0f"
var backdrop: Backdrop
var rigs := {}
var _turn := {"m": 0.0, "f": 0.0}
var _v: VBoxContainer
var _name: LineEdit
var _typed := ""

func setup(b: Backdrop) -> void:
	backdrop = b
	if backdrop.rig:
		backdrop.rig.visible = false
	for row: Array in BODIES:
		var rig := FighterRig.new()
		backdrop.add_child(rig)
		rig.build(_look(row[0]), false)
		rig.position = SPOT[row[0]]
		rig.rotation.y = FACING
		rigs[row[0]] = rig
	_frame(true)

## The look of a newly woken knight of this body, in the starting equipment.
func _look(b: String) -> Dictionary:
	var keep: Dictionary = Game.profile
	var p := Game.default_profile()
	p.body = b
	p.heraldry = heraldry
	Game.profile = p
	var look: Dictionary = Duel.player_look()
	Game.profile = keep
	return look

func _frame(snap: bool = false) -> void:
	var at: Vector3 = SPOT[body]
	# the knight stands right of centre; the words are on the left
	backdrop.move_camera(at + Vector3(-0.95, 1.2, 3.5), at + Vector3(-0.75, 1.0, 0), snap)

func _ready() -> void:
	UI.apply(self)
	UI.full(self)
	add_child(UI.shade(0.94, 0.58))
	# everything not covered by a control turns the knight
	var drag: Control = UI.full(Control.new())
	drag.gui_input.connect(_on_drag)
	add_child(drag)
	var m := UI.margin(get_viewport(), 30)
	add_child(m)
	_v = VBoxContainer.new()
	_v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_v.add_theme_constant_override("separation", 8)
	_v.custom_minimum_size.x = 440
	m.add_child(_v)
	var hint := UI.label("Drag to turn", 17, Color(1, 1, 1, 0.45))
	hint.size_flags_horizontal = Control.SIZE_SHRINK_END
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	m.add_child(hint)
	_fill()

func _on_drag(e: InputEvent) -> void:
	if e is InputEventScreenDrag and rigs.has(body):
		_turn[body] = float(_turn[body]) + e.relative.x * 0.012

func _process(delta: float) -> void:
	for b: String in rigs:
		var rig: FighterRig = rigs[b]
		if is_instance_valid(rig):
			rig.rotation.y = lerp_angle(rig.rotation.y, FACING + float(_turn[b]), 1.0 - exp(-delta * 10.0))

func _fill() -> void:
	for c in _v.get_children():
		_v.remove_child(c)
		c.queue_free()
	_v.add_child(UI.title("Who Wakes", 32))
	_v.add_child(UI.ornament(440))
	var forms := HBoxContainer.new()
	forms.add_theme_constant_override("separation", 10)
	_v.add_child(forms)
	var desc := ""
	for row: Array in BODIES:
		var fb := UI.button(row[1], 19, 215)
		if row[0] == body:
			fb.add_theme_color_override("font_color", UI.GOLD)
			fb.add_theme_stylebox_override("normal", UI._button_box("hover"))
			desc = row[2]
		fb.pressed.connect(func():
			if body != row[0]:
				body = row[0]
				_frame()
				_fill())
		forms.add_child(fb)
	_v.add_child(UI.wrapped(desc, 20, UI.BONE, 440))
	_v.add_child(UI.wrapped("Both wake with the same strength, the same reach and the same chances. Only the body differs.", 18, UI.SILVER, 440))
	_v.add_child(UI.spacer(2))
	_v.add_child(UI.label("BURIED WITH", 15, UI.GOLD_DIM.lightened(0.3), "head"))
	var eq: Dictionary = Game.default_profile().equipped
	var names: Array = []
	for slot: String in Db.SLOTS:
		if eq.get(slot) != null:
			names.append(str(Db.item(str(eq[slot])).get("name", eq[slot])))
	_v.add_child(UI.wrapped("  ·  ".join(names), 18, UI.BONE, 440))
	_v.add_child(UI.spacer(2))
	_v.add_child(UI.label("A NAME, IF YOU REMEMBER ONE", 15, UI.GOLD_DIM.lightened(0.3), "head"))
	_name = LineEdit.new()
	_name.placeholder_text = "Unbound"
	_name.max_length = 16
	_name.text = _typed
	_name.custom_minimum_size = Vector2(440, 46)
	_name.text_changed.connect(func(t: String): _typed = t)
	_v.add_child(_name)
	_v.add_child(UI.spacer(2))
	_v.add_child(UI.label("THE CLOAK YOU WERE BURIED IN", 15, UI.GOLD_DIM.lightened(0.3), "head"))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	_v.add_child(row2)
	for h: Array in HERALDRY:
		var b := Button.new()
		b.custom_minimum_size = Vector2(80, 48)
		var on: bool = h[1] == heraldry
		b.add_theme_stylebox_override("normal", UI.box(Color(h[1]), UI.GOLD if on else UI.GOLD_DIM, 2 if on else 1, 1))
		b.add_theme_stylebox_override("hover", UI.box(Color(h[1]).lightened(0.1), UI.GOLD, 2, 1))
		b.add_theme_stylebox_override("pressed", UI.box(Color(h[1]), UI.GOLD, 2, 1))
		b.tooltip_text = h[0]
		b.pressed.connect(func():
			heraldry = h[1]
			for k: String in rigs:
				if rigs[k].mat_cloth:
					rigs[k].mat_cloth.albedo_color = Color(heraldry)
			Sfx.play("ui_tap", -6.0)
			_fill())
		row2.add_child(b)
	_v.add_child(UI.spacer(8))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	_v.add_child(btns)
	var back := UI.button("Back", 18, 140)
	back.pressed.connect(func(): closed.emit())
	btns.add_child(back)
	var go := UI.button("Rise", 22, 290)
	go.pressed.connect(func():
		Sfx.play("ui_confirm", -3.0)
		confirmed.emit(heraldry, body, _typed.strip_edges()))
	btns.add_child(go)

## Takes the two knights away again and gives the scene back.
func leave() -> void:
	for k: String in rigs:
		if is_instance_valid(rigs[k]):
			rigs[k].queue_free()
	rigs.clear()
	if backdrop and backdrop.rig:
		backdrop.rig.visible = true
