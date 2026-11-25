class_name Explore
extends Node
## One stop along a region's road: a slow camera move through the place,
## a line of description, and the ways onward.

signal fight(option: Dictionary)
signal moved_on
signal turned_back

var backdrop: Backdrop
var layer: CanvasLayer
var cards: VBoxContainer
var prompt: Label
var hp_bar: ProgressBar
var angle := 0.0

func _ready() -> void:
	var region := Game.run_region()
	var stage: int = Game.run.stage
	backdrop = Backdrop.new()
	add_child(backdrop)
	backdrop.build(region.theme)
	# each stage looks across the arena from a new bearing; arriving pans from the last one
	angle = stage * 0.85 - 0.4
	var prev := angle - 0.85
	backdrop.rig.rotation.y = angle
	backdrop.move_camera(_at(prev, Vector3(1.3, 1.9, 5.2)), _at(prev, Vector3(0, 1.3, -4.0)), true)
	backdrop.move_camera(_at(angle, Vector3(1.3, 1.7, 4.2)), _at(angle, Vector3(-0.3, 1.25, -4.0)))
	Sfx.ambience(str(region.amb))
	Sfx.music("menu")
	Sfx.play("footstep", -6.0)
	layer = CanvasLayer.new()
	add_child(layer)
	var m := UI.margin(get_viewport(), 8)
	layer.add_child(m)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(frame)
	var head := VBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	head.add_theme_constant_override("separation", 2)
	frame.add_child(head)
	head.add_child(UI.title(region.name, 24))
	var pips := ""
	for i in region.stages.size():
		pips += "◆ " if i < stage else ("◇ " if i > stage else "❖ ")
	head.add_child(UI.label(pips, 18, UI.GOLD_DIM))
	hp_bar = UI.bar(Color("#9a2a2a"), 10)
	hp_bar.custom_minimum_size.x = 230
	hp_bar.max_value = Game.stats().max_hp
	hp_bar.value = Game.run.hp
	head.add_child(hp_bar)
	var back := UI.button("Turn Back", 14, 150)
	back.custom_minimum_size.y = 40
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -150
	back.pressed.connect(func(): turned_back.emit())
	frame.add_child(back)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 10)
	frame.add_child(bottom)
	prompt = UI.label(Game.run_stage().prompt, 24, UI.BONE)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	prompt.add_theme_constant_override("shadow_offset_y", 2)
	bottom.add_child(prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bottom.add_child(row)
	for o in Game.stage_options():
		row.add_child(_card(o))
	layer.get_child(0).modulate.a = 0.0
	create_tween().tween_property(layer.get_child(0), "modulate:a", 1.0, 0.9).set_delay(0.5)

func _at(a: float, v: Vector3) -> Vector3:
	return v.rotated(Vector3.UP, a)

func _card(o: Dictionary) -> Button:
	var tag: String = {"fight": "A foe", "boss": "The guardian", "treasure": "A cache", "shrine": "Respite", "lever": "A mechanism", "pass": "Onward"}[o.type]
	if o.get("optional", false):
		tag = "A hunter  ·  optional"
	var b := UI.button("", 18, 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 104
	var v := VBoxContainer.new()
	UI.full(v)
	v.offset_left = 16
	v.offset_top = 10
	v.offset_right = -16
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	b.add_child(v)
	v.add_child(UI.label(tag.to_upper(), 13, UI.BLOOD.lightened(0.3) if o.type in ["fight", "boss"] else UI.GOLD_DIM, "bold"))
	v.add_child(UI.title(o.label, 20, UI.BONE))
	v.add_child(UI.label(o.hint, 17, UI.DIM))
	b.pressed.connect(func(): _choose(o))
	return b

func _choose(o: Dictionary) -> void:
	match o.type:
		"fight", "boss":
			fight.emit(o)
		"pass":
			moved_on.emit()
		_:
			_interact(o)

func _interact(o: Dictionary) -> void:
	layer.get_child(0).visible = false
	var spot := _at(angle, Vector3(0.9, 0, -2.4))
	var prop := backdrop.add_prop(o.type, spot)
	prop.rotation.y = angle
	backdrop.move_camera(_at(angle, Vector3(2.6, 1.3, 0.4)), spot + Vector3(0, 0.6, 0))
	var verb: String = {"treasure": "Open", "shrine": "Rest", "lever": "Pull"}[o.type]
	var l2 := CanvasLayer.new()
	add_child(l2)
	var c := UI.full(CenterContainer.new())
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l2.add_child(c)
	var b := UI.button(verb, 24, 220)
	c.add_child(b)
	b.modulate.a = 0.0
	create_tween().tween_property(b, "modulate:a", 1.0, 0.5).set_delay(0.9)
	b.pressed.connect(func():
		l2.queue_free()
		_resolve(o, prop))

func _resolve(o: Dictionary, prop: Node3D) -> void:
	var lines: Array = []
	var heading := ""
	match o.type:
		"treasure":
			create_tween().tween_property(prop.get_node("Lid"), "rotation:x", -1.9, 0.6).set_trans(Tween.TRANS_BACK)
			Sfx.play("loot", 0.0)
			var got := Game.open_treasure(o)
			heading = o.label
			for id in got.items:
				lines.append([Db.item(id).name, Db.rarity_color(Db.item(id))])
			if got.gold > 0:
				lines.append("%d gold" % got.gold)
			if got.shards > 0:
				lines.append("%d shard%s" % [got.shards, "" if got.shards == 1 else "s"])
			if lines.is_empty():
				lines.append("Already emptied.")
		"shrine":
			Sfx.play("levelup", -6.0, 0.8)
			var heal := Game.rest_at_shrine()
			heading = "Respite"
			lines.append("Wounds close.  +%d health" % int(heal))
		"lever":
			create_tween().tween_property(prop.get_node("Arm"), "rotation:z", -0.6, 0.5).set_trans(Tween.TRANS_BACK)
			Sfx.play("guard_break", -8.0, 0.7)
			Game.pull_lever(o)
			heading = "A Way Opens"
			lines.append("%s will stay open." % Game.run_region().shortcut.label)
			lines.append("You may begin from here when you return.")
	await get_tree().create_timer(0.9).timeout
	Overlays.message(self, heading, lines, "Onward", func(): moved_on.emit())
