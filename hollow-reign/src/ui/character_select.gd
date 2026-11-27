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
const SPOT := {"m": Vector3(-2.4, 0, 0.6), "f": Vector3(2.4, 0, 0.6)}
const FACING := PI * 0.94
const BLADE_TURN := 0.9

var body := "m"
var heraldry := "#3d0f0f"
var backdrop: Backdrop
var rigs := {}
var _turn := {"m": 0.0, "f": 0.0}
var _v: VBoxContainer
var _name: LineEdit
var _typed := ""
## The blade the knight wakes holding: one of Db.equipment.basic_swords. Read by whoever starts the journey
## (Game.new_game's third argument) after `confirmed`.
static var start_weapon := "w_rusted_sword"
var weapon := "w_rusted_sword"
var step := 0                     # 0: body, name, cloak · 1: the blade
var carousel: ItemCarousel
var _blade := {}                  # the labels and bars of step 1, refilled as the row moves
var _sword_stats := {}
var _demo: Array = []
var _clock := 0.0

func setup(b: Backdrop) -> void:
	backdrop = b
	_held = weapon
	start_weapon = "w_rusted_sword"
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
	p.equipped.weapon = weapon
	Game.profile = p
	var look: Dictionary = Duel.player_look()
	Game.profile = keep
	return look

## The knights take up the sword in the middle of the row (O6): only the hands are changed, so the pose is kept.
var _held := "w_rusted_sword"
func _hold_weapon() -> void:
	if _held == weapon:
		return
	_held = weapon
	for b: String in rigs:
		var rig: FighterRig = rigs[b]
		if is_instance_valid(rig):
			var look := _look(b)
			rig.cfg = look
			rig.set_weapon(str(look.weapon), look)
			rig.set_shield(look.get("shield"))

## Height left for a column inside the safe area with `extra` units of margin.
func _room(extra: float) -> float:
	var s := UI.safe_margins(get_viewport())
	return 720.0 - float(s.t) - float(s.b) - extra * 2.0

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
	var m := UI.margin(get_viewport(), 12)
	add_child(m)
	_v = VBoxContainer.new()
	_v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_v.add_theme_constant_override("separation", 6)
	_v.custom_minimum_size.x = 600
	m.add_child(_v)
	var hint := UI.label("Drag to turn", 17, Color(1, 1, 1, 0.45))
	hint.size_flags_horizontal = Control.SIZE_SHRINK_END
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	m.add_child(hint)
	_fill()
	# capture harness: --step=blade [--sword=<id>] [--cs_demo=<t>:<sword id>,...]
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		if kv[0] == "sword" and kv.size() > 1 and Db.equipment.basic_swords.has(Db.canon(kv[1])):
			weapon = Db.canon(kv[1])
		elif kv[0] == "step" and kv.size() > 1 and kv[1] == "blade":
			step = 1
		elif kv[0] == "cs_demo" and kv.size() > 1:
			for st: String in kv[1].split(",", false):
				_demo.append([float(st.get_slice(":", 0)), st.get_slice(":", 1)])
	if step == 1:
		_fill()

func _on_drag(e: InputEvent) -> void:
	if e is InputEventScreenDrag and rigs.has(body):
		_turn[body] = float(_turn[body]) + e.relative.x * 0.012

func _process(delta: float) -> void:
	_clock += delta
	while not _demo.is_empty() and _clock >= float(_demo[0][0]) and carousel:
		carousel.go_to(Db.equipment.basic_swords.find(Db.canon(str(_demo.pop_front()[1]))))
	for b: String in rigs:
		var rig: FighterRig = rigs[b]
		if is_instance_valid(rig):
			# at the sword row the knight stands a little side-on, so the flat of the blade it holds can be seen
			rig.rotation.y = lerp_angle(rig.rotation.y, FACING + float(_turn[b]) + (BLADE_TURN if step == 1 else 0.0), 1.0 - exp(-delta * 10.0))

func _fill() -> void:
	for c in _v.get_children():
		_v.remove_child(c)
		c.queue_free()
	carousel = null
	if step == 1:
		_fill_blade()
		return
	_v.add_child(UI.title("Who Wakes", 32))
	_v.add_child(UI.ornament(600))
	var forms := HBoxContainer.new()
	forms.add_theme_constant_override("separation", 10)
	_v.add_child(forms)
	var desc := ""
	for row: Array in BODIES:
		var fb := UI.button(row[1], 22, 295)
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
	_v.add_child(UI.wrapped(desc, 22, UI.BONE, 600))
	_v.add_child(UI.wrapped("Both wake with the same strength, the same reach and the same chances. Only the body differs.", 18, UI.SILVER, 600))
	_v.add_child(UI.spacer(2))
	_v.add_child(UI.label("BURIED WITH", 18, UI.GOLD_DIM.lightened(0.3), "head"))
	var eq: Dictionary = Game.default_profile().equipped
	var names: Array = []
	for slot: String in Db.SLOTS:
		if eq.get(slot) != null:
			names.append(str(Db.item(str(eq[slot])).get("name", eq[slot])))
	_v.add_child(UI.wrapped("  ·  ".join(names), 18, UI.BONE, 600))
	_v.add_child(UI.spacer(2))
	# the name and the cloak side by side, so every control keeps a full-height touch target on a short screen
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 16)
	_v.add_child(pair)
	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 4)
	pair.add_child(name_col)
	name_col.add_child(UI.label("YOUR NAME", 18, UI.GOLD_DIM.lightened(0.3), "head"))
	_name = LineEdit.new()
	_name.placeholder_text = "Unbound"
	_name.max_length = 16
	_name.text = _typed
	_name.custom_minimum_size = Vector2(240, UI.TAP)
	_name.text_changed.connect(func(t: String): _typed = t)
	name_col.add_child(_name)
	var cloak_col := VBoxContainer.new()
	cloak_col.add_theme_constant_override("separation", 4)
	pair.add_child(cloak_col)
	cloak_col.add_child(UI.label("THE CLOAK YOU WERE BURIED IN", 18, UI.GOLD_DIM.lightened(0.3), "head"))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	cloak_col.add_child(row2)
	for h: Array in HERALDRY:
		var b := Button.new()
		b.custom_minimum_size = Vector2(62, UI.TAP)
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
	_v.add_child(UI.spacer(6))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 20)
	_v.add_child(btns)
	var back := UI.button("Back", 20, 160)
	back.pressed.connect(func(): closed.emit())
	btns.add_child(back)
	var go := UI.button("Choose a Blade", 22, 420)
	go.pressed.connect(func():
		step = 1
		_fill())
	btns.add_child(go)

# ================================================================ the blade
## The duel's own numbers for a newly woken knight holding this sword.
func _stats_for(id: String) -> Dictionary:
	if not _sword_stats.has(id):
		var p := Game.default_profile()
		p.equipped.weapon = id
		_sword_stats[id] = Stats.compute(p, Db.items, Db.classes)
	return _sword_stats[id]

func _fill_blade() -> void:
	var swords: Array = Db.equipment.basic_swords
	_v.add_child(UI.title("The Blade You Wake Holding", 26))
	var case := UI.panel(Color(0.02, 0.02, 0.026, 0.8), Color(0.3, 0.27, 0.2))
	case.get_theme_stylebox("panel").set_content_margin_all(1)
	case.custom_minimum_size = Vector2(600, clampf(_room(12.0) - 372.0, 150.0, 280.0))     # what the rest leaves
	_v.add_child(case)
	carousel = ItemCarousel.new()
	carousel.zoom = 1.3
	var entries: Array = []
	for id: String in swords:
		var it: Dictionary = Db.item(id)
		entries.append({"id": id, "slot": "weapon", "name": str(it.name), "color": Db.rarity_color(it).lerp(UI.BONE, 0.35), "metal": "#b8b4aa",
			"locked": false, "dark": false, "equipped": false, "fav": false, "mod": {"blade_tier": 0, "grip_tier": 0, "ore": "iron", "keen": false}})
	case.add_child(carousel)
	carousel.set_entries(entries, maxi(swords.find(weapon), 0))
	carousel.centred.connect(func(_i: int): _blade_detail())
	carousel.settled.connect(func(_i: int):
		_blade_detail()
		_hold_weapon())
	UI.corners(case, UI.GOLD_DIM, 12.0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_v.add_child(head)
	var nm := UI.title("", 26, UI.BONE)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	var role := UI.label("", 22, UI.GOLD, "head")
	head.add_child(role)
	var text := UI.wrapped("", 22, UI.BONE, 600)
	text.custom_minimum_size.y = 56
	_v.add_child(text)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 2)
	_v.add_child(grid)
	var bars := {}
	for k: Array in [["attack", "Damage"], ["swing_time", "Speed"], ["swing_cost", "Economy"], ["crit_mult", "Stagger"]]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.custom_minimum_size.x = 288
		var top := HBoxContainer.new()
		var kl := UI.label(str(k[1]).to_upper(), 22, UI.DIM, "head")
		kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(kl)
		var val := UI.label("", 22, UI.BONE, "bold")
		top.add_child(val)
		cell.add_child(top)
		var bar := UI.bar(UI.GOLD_DIM.lerp(UI.GOLD, 0.5), 8)
		bar.max_value = 1.0
		cell.add_child(bar)
		grid.add_child(cell)
		bars[k[0]] = [bar, val]
	var extra := UI.wrapped("", 22, UI.GOLD_DIM.lightened(0.25), 600)
	_v.add_child(extra)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 20)
	_v.add_child(btns)
	var back := UI.button("Back", 20, 160)
	back.pressed.connect(func():
		step = 0
		_fill())
	btns.add_child(back)
	var go := UI.button("Rise", 22, 420)
	go.pressed.connect(func():
		Sfx.play("ui_confirm", -3.0)
		start_weapon = weapon
		confirmed.emit(heraldry, body, _typed.strip_edges()))
	btns.add_child(go)
	_blade = {"name": nm, "role": role, "text": text, "bars": bars, "extra": extra}
	_blade_detail()
	_hold_weapon()

## The bars are each sword against the best of the four, fuller always the better: every figure is one the duel reads.
func _blade_detail() -> void:
	if carousel == null or _blade.is_empty():
		return
	var swords: Array = Db.equipment.basic_swords
	weapon = str(swords[clampi(carousel.index, 0, swords.size() - 1)])
	var it: Dictionary = Db.item(weapon)
	var st := _stats_for(weapon)
	(_blade.name as Label).text = str(it.name).to_upper()
	(_blade.role as Label).text = str(it.get("role", "")).to_upper()
	var rt := str(it.get("role_text", it.get("desc", "")))
	(_blade.text as Label).text = rt.get_slice(": ", 1).capitalize().left(1) + rt.get_slice(": ", 1).substr(1) if rt.contains(": ") else rt
	var price_lo := 1 << 30
	var price_hi := 0
	for id: String in swords:
		if id != weapon:
			price_lo = mini(price_lo, int(Db.item(id).price))
			price_hi = maxi(price_hi, int(Db.item(id).price))
	for key: String in _blade.bars:
		var best := 0.0
		var lower: bool = key in ["swing_time", "swing_cost"]
		for id: String in swords:
			var v: float = float(_stats_for(id)[key])
			best = maxf(best, 1.0 / v if lower else v)
		var mine: float = float(st[key])
		var bar: ProgressBar = _blade.bars[key][0]
		var frac: float = (1.0 / mine if lower else mine) / best
		if Game.settings.reduce_motion:
			bar.value = frac
		else:
			create_tween().tween_property(bar, "value", frac, 0.25).set_trans(Tween.TRANS_SINE)
		(_blade.bars[key][1] as Label).text = {"attack": "%.1f" % mine, "swing_time": "%.2fs a cut" % mine, "swing_cost": "%.1f stamina" % mine, "crit_mult": "×%.2f" % mine}[key]
	var bits: Array = []
	if float(st.guard_dmg) != 1.0:
		bits.append("Guard damage ×%.1f" % float(st.guard_dmg))
	if st.element != null:
		bits.append("%s edge" % str(st.element).capitalize())
	bits.append("Orren sells the other three: %d to %d gold" % [price_lo, price_hi])
	(_blade.extra as Label).text = "  ·  ".join(bits)

## Takes the two knights away again and gives the scene back.
func leave() -> void:
	for k: String in rigs:
		if is_instance_valid(rigs[k]):
			rigs[k].queue_free()
	rigs.clear()
	if backdrop and backdrop.rig:
		backdrop.rig.visible = true
