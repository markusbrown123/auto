class_name SaveSlots
extends Control
## The three journeys. In "load" mode a used slot is resumed; in "new" mode a slot is chosen for a new journey
## (an occupied one asks before it is overwritten). Deleting always asks.

signal closed
signal chosen(slot: int)          # load mode: resume this slot. new mode: begin a new journey here.

const BODY_NAME := {"m": "The Knight", "f": "The Blade"}

var mode := "load"
var _row: HBoxContainer

func _init(screen_mode: String = "load") -> void:
	mode = screen_mode

func _ready() -> void:
	UI.apply(self)
	UI.full(self)
	var dim: ColorRect = UI.full(ColorRect.new())
	dim.color = Color(0.01, 0.01, 0.015, 0.74)
	add_child(dim)
	var m := UI.margin(get_viewport(), 28)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	m.add_child(v)
	v.add_child(UI.header("Legacies" if mode == "load" else "Choose a place for the new legacy", func(): closed.emit(),
		"Three may be kept." if mode == "load" else "An occupied place is overwritten."))
	v.add_child(UI.rule())
	var mid := CenterContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(mid)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 22)
	mid.add_child(_row)
	_fill()

func _fill() -> void:
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	var latest := Game.latest_slot()
	for n in range(1, Game.SLOT_COUNT + 1):
		_row.add_child(_card(n, Game.slot_summary(n), n == latest))

func _card(n: int, s: Dictionary, latest: bool) -> Control:
	var used := not s.is_empty()
	var p := UI.panel(Color(0.045, 0.047, 0.056, 0.95), UI.GOLD if latest else UI.GOLD_DIM)
	p.custom_minimum_size = Vector2(340, 500)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	top.add_child(UI.label("JOURNEY %s" % UI.roman(n), 17, UI.GOLD_DIM.lightened(0.25), "head"))
	var gap := UI.spacer(0)
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	if latest:
		top.add_child(UI.label("LAST PLAYED", 15, UI.GOLD, "head"))
	if not used:
		var hole := UI.spacer(110)
		v.add_child(hole)
		var e := UI.title("Empty", 28, UI.DIM)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(e)
		var note := UI.wrapped("Nobody has woken here yet.", 19, UI.DIM, 300)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(note)
		var fill := UI.spacer(0)
		fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(fill)
		if mode == "new":
			var b := UI.button("Begin here", 19, 300)
			b.pressed.connect(func(): chosen.emit(n))
			v.add_child(b)
		return p
	# heraldry: the cloak colour as a band, so journeys can be told apart at a glance
	var band := ColorRect.new()
	band.color = Color(str(s.heraldry)).lightened(0.08)
	band.custom_minimum_size = Vector2(0, 5)
	v.add_child(UI.spacer(4))
	v.add_child(band)
	v.add_child(UI.spacer(6))
	var who: String = str(s.name) if str(s.name) != "" else str(BODY_NAME.get(s.body, "The Knight"))
	v.add_child(UI.title(who, 26, UI.BONE))
	var sub: String = "Level %d" % int(s.level)
	if str(s.name) != "":
		sub = "%s  ·  %s" % [BODY_NAME.get(s.body, "The Knight"), sub]
	if int(s.ng) > 0:
		sub += "  ·  Journey +%d" % int(s.ng)
	v.add_child(UI.label(sub, 20, UI.GOLD, "bold"))
	v.add_child(UI.spacer(8))
	v.add_child(UI.rule())
	v.add_child(UI.spacer(8))
	# whose journey it is: the house, which of its three generations is on the road, and how far along
	var gen_line := "%s  ·  %s" % [UI.roman(int(s.get("generation", 2))), str(s.get("generation_title", ""))]
	var house := ("House %s" % str(s.family)) if str(s.get("family", "")) != "" else ""
	for pair: Array in [["Generation", gen_line + (("\n" + house) if house != "" else "")], ["Road", str(s.chapter)], ["Weapon", str(s.weapon)], ["Time walked", UI.playtime(float(s.playtime))], ["Last played", UI.when(float(s.last_played))]]:
		v.add_child(UI.label(str(pair[0]).to_upper(), 14, UI.DIM, "head"))
		var val := UI.wrapped(str(pair[1]), 20, UI.BONE, 300)
		v.add_child(val)
		v.add_child(UI.spacer(2))
	var fill2 := UI.spacer(0)
	fill2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill2)
	var go := UI.button("Resume" if mode == "load" else "Overwrite", 19, 300)
	go.pressed.connect(func():
		if mode == "load":
			chosen.emit(n)
		else:
			UI.confirm(self, "Overwrite this journey?", "%s, level %d, will be gone for good. A new journey begins in its place." % [who, int(s.level)],
				"Overwrite", func(): chosen.emit(n), "Keep it", true))
	v.add_child(go)
	v.add_child(UI.spacer(6))
	var del := UI.button("Delete", 16, 300)
	del.custom_minimum_size.y = 44
	del.add_theme_color_override("font_color", UI.BLOOD.lightened(0.3))
	del.pressed.connect(func():
		UI.confirm(self, "Delete this journey?", "%s, level %d, %s walked. This cannot be undone." % [who, int(s.level), UI.playtime(float(s.playtime))],
			"Delete", func():
				Game.delete_slot(n)
				_fill(), "Keep it", true))
	v.add_child(del)
	return p
