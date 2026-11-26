class_name ArmoryInspect
extends Control
## One item, full screen: the piece itself to turn freely (drag) and bring closer (pinch or wheel),
## beside its figures, its mastery and its history. Opened from the armoury; any tap on Close ends it.

var entry: Dictionary
var body := "m"
var note := ""
var _piece: Node3D
var _cam: Camera3D
var _yaw := 0.6
var _pitch := 0.0
var _dist := 2.7
var _touches := {}
var _pinch0 := 0.0
var _clock := 0.0
var _touched := false

func _init(e: Dictionary, knight_body: String, honest_note: String) -> void:
	entry = e
	body = knight_body
	note = honest_note

func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := UI.full(ColorRect.new())
	bg.color = Color(0.012, 0.012, 0.016, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var m := UI.margin(get_viewport(), 10)
	add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(row)
	var it: Dictionary = Db.item(str(entry.id))
	var col: Color = entry.color
	# --- the piece
	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_stretch_ratio = 1.25
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.gui_input.connect(_stage_input)
	row.add_child(stage)
	_piece = ItemModel.build(it, body, bool(entry.get("dark", false))) if ItemModel.ready(ItemModel.paths(it, body)) else null
	if _piece:
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var q := int(Game.settings.get("quality", 2))
		svc.stretch_shrink = 2 if q == 0 else 1
		UI.full(svc)
		stage.add_child(svc)
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_DISABLED if q == 0 else Viewport.MSAA_4X
		vp.positional_shadow_atlas_size = 0
		svc.add_child(vp)
		var we := WorldEnvironment.new()
		we.environment = ItemModel.studio_env()
		vp.add_child(we)
		_cam = Camera3D.new()
		_cam.fov = 30.0
		vp.add_child(_cam)
		var key := DirectionalLight3D.new()
		key.light_color = Color("#ffe2b8")
		key.light_energy = 2.4
		key.rotation_degrees = Vector3(-38, -32, 0)
		vp.add_child(key)
		if q > 0:
			var rim := DirectionalLight3D.new()
			var glow = it.get("look", {}).get("glow")
			rim.light_color = Color(str(glow)).lerp(Color.WHITE, 0.25) if glow != null and not entry.get("dark", false) else Color("#7f9cc8")
			rim.light_energy = 1.4
			rim.rotation_degrees = Vector3(-18, 155, 0)
			vp.add_child(rim)
		vp.add_child(_piece)
	else:
		var mark := Control.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.full(mark)
		stage.add_child(mark)
		mark.draw.connect(func():
			var c := mark.size * 0.5
			var r := minf(mark.size.x, mark.size.y) * 0.3
			mark.draw_circle(c, r, Color(0.055, 0.055, 0.065))
			mark.draw_arc(c, r, 0, TAU, 64, col, 4.0, true)
			mark.draw_arc(c, r * 0.88, 0, TAU, 64, Color(col, 0.3), 1.5, true)
			var metal: Color = Color(str(entry.get("metal", "#b8b4aa"))).lerp(Color("#d8d2c4"), 0.45)
			InvGlyph.paint(mark, "lock" if entry.get("dark", false) else str(entry.slot), c - Vector2(r, r) * 0.55, r * 1.1, metal))
	var hint := UI.label("Drag to turn  ·  pinch to bring closer" if _piece else "No model of its own", 22, UI.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stage.add_child(hint)
	# --- what it is
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	row.add_child(side)
	var top := HBoxContainer.new()
	side.add_child(top)
	var lvl := Game.upgrade_level(str(it.id))
	var ttl := UI.title(str(entry.name) + ("  +%d" % lvl if lvl > 0 else ""), 28, col)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ttl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(ttl)
	var close := UI.button("Close", 20, 130)
	close.custom_minimum_size.y = 58
	close.pressed.connect(queue_free)
	top.add_child(close)
	var kind := HBoxContainer.new()
	kind.add_theme_constant_override("separation", 10)
	kind.add_child(InvGlyph.new("pips", col, Game.rarity_pips(it), 15.0))
	kind.add_child(UI.label("%s · %s" % [Game.rarity_name(it), Db.classes[it.cls].name if it.slot == "weapon" else Db.SLOT_NAME[it.slot]], 22, col))
	side.add_child(kind)
	side.add_child(UI.rule())
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	sc.add_child(v)
	var own := Game.owns(str(it.id))
	if own or not entry.get("dark", false):
		for line in Stats.item_lines(it, lvl, Db.classes):
			_kv(v, str(line[0]) if not (it.slot == "weapon" and str(line[0]) == "Stamina") else "Stamina a swing", str(line[1]))
		if it.slot == "weapon":
			# every clean hit wears the same amount off a foe's guard, so quicker weapons press harder
			_kv(v, "Guard damage", "4 a hit · %.0f a second" % (4.0 / float(Db.classes[it.cls].swing)))
		v.add_child(UI.rule())
	if own or not entry.get("dark", false):
		var id := str(it.id)
		if Game.requirement_text(id) != "":
			var met := Game.meets_requirements(id)
			v.add_child(UI.wrapped("Asks for %s%s" % [Game.requirement_text(id), "" if met else ": usable without, but it costs you (weapons hit softer and tire; armour slows your recovery)"], 22, UI.DIM if met else Color("#c2574a")))
		if own and it.slot == "weapon" and it.has("mods"):
			var w := Game.weapon_mods(id)
			_kv(v, "Forge work", "Blade %d/%d · Grip %d/%d · %s" % [int(w.blade), int(w.max.blade), int(w.grip), int(w.max.grip),
				["Iron", "Steel", str(Db.equipment.mods.ores.get(str(w.ore_id), {}).get("name", "Ore")), "Cored"][clampi(int(w.ore), 0, 3)]])
			if int(w.edge) > 0:
				_kv(v, "Keen edge", "%d fight%s left" % [int(w.edge), "" if int(w.edge) == 1 else "s"])
		if it.has("weight") and Db.equipment.weights.has(it.weight):
			v.add_child(UI.wrapped("%s. %s" % [Db.equipment.weights[it.weight].name, Db.equipment.weights[it.weight].text], 22, UI.DIM))
		var fam: Dictionary = Db.family(it)
		if Db.ARMOUR_SLOTS.has(str(it.slot)) and not fam.is_empty() and it.get("set_piece", true):
			var worn := 0
			for st: Dictionary in Game.set_status():
				if str(st.family) == str(it.family):
					worn = int(st.pieces)
			_kv(v, "%s set" % str(fam.name), "%d of 6 worn" % worn)
			for t: Dictionary in fam.set:
				v.add_child(UI.wrapped("%d pieces  ·  %s" % [int(t.pieces), str(t.text)], 22, UI.GOLD if worn >= int(t.pieces) else UI.DIM))
		v.add_child(UI.rule())
	if note != "":
		v.add_child(UI.wrapped(note, 22, UI.GOLD_DIM))
	if own:
		_mastery(v, it)
		var hist := Game.item_history(str(it.id))
		if note != hist[0]:
			v.add_child(UI.wrapped(hist[0], 22, UI.BONE))
		if hist.size() > 1:
			v.add_child(UI.wrapped(hist[1], 22, UI.BONE))
	elif not entry.get("dark", false):
		v.add_child(UI.wrapped(str(it.get("desc", "")), 22, UI.BONE))
	UI.fade_in(self, 0.2)

func _kv(parent: Control, k: String, val: String) -> void:
	var row := HBoxContainer.new()
	var kl := UI.label(k, 22, UI.DIM)
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(kl)
	row.add_child(UI.label(val, 22, UI.BONE, "bold"))
	parent.add_child(row)

func _mastery(v: VBoxContainer, it: Dictionary) -> void:
	var need := Stats.mastery_needed(it)
	var have := Game.mastery_points(str(it.id))
	var tier := Game.mastery_tier(str(it.id))
	_kv(v, "MASTERY", "Mastered" if tier == 3 else "%d of %d fights" % [have, need])
	var bar := UI.bar(UI.GOLD, 6)
	bar.max_value = need
	bar.value = have
	v.add_child(bar)
	for t: int in ([1, 2, 3] if it.slot == "weapon" else [3]):
		var at := Game.mastery_threshold(it, t)
		var done := tier >= t
		var text := "%s  %s" % [["", "I", "II", "III"][t], Game.mastery_tier_text(it, t)]
		if not done:
			text += "  ·  %d more" % (at - have)
		v.add_child(UI.wrapped(text, 22, UI.GOLD if done else UI.DIM))
	v.add_child(UI.rule())

func _stage_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
		else:
			_touches.erase(e.index)
		_pinch0 = 0.0
	elif e is InputEventScreenDrag:
		_touched = true
		_touches[e.index] = e.position
		if _touches.size() >= 2:
			var k: Array = _touches.keys()
			var dist: float = (_touches[k[0]] as Vector2).distance_to(_touches[k[1]])
			if _pinch0 > 0.0 and dist > 1.0:
				_dist = clampf(_dist * _pinch0 / dist, 1.2, 4.5)
			_pinch0 = dist
		else:
			_yaw = wrapf(_yaw + e.relative.x * 0.012, -PI, PI)
			_pitch = clampf(_pitch + e.relative.y * 0.01, -1.2, 1.2)
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_dist = clampf(_dist * (0.9 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 1.2, 4.5)
	elif e is InputEventMagnifyGesture:
		_dist = clampf(_dist / e.factor, 1.2, 4.5)

func _process(delta: float) -> void:
	_clock += delta
	if _piece == null:
		return
	if not _touched and not Game.settings.reduce_motion:
		_yaw = wrapf(_yaw + delta * 0.4, -PI, PI)      # turns by itself until it is taken hold of
	(_piece.get_node("Tilt/Pivot") as Node3D).rotation.y = _yaw
	_piece.rotation.x = _pitch
	_cam.position = Vector3(0, 0, _dist)
