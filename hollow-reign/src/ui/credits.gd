class_name Credits
extends Control
## The credits roll by themselves and can be dragged. "Licences" shows the full licence texts,
## including the engine's own, which is read from the engine so that it is always the right one.

signal closed

const SPEED := 30.0             # pixels a second
const DATA := "res://data/credits.json"

var data := {}
var _scroll: ScrollContainer
var _col: VBoxContainer
var _pos := 0.0
var _hold := 1.2                # seconds before the roll starts or resumes after a touch
var _rolling := true

func _ready() -> void:
	UI.apply(self)
	UI.full(self)
	var v = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	data = v if v is Dictionary else {}
	var dim: ColorRect = UI.full(ColorRect.new())
	dim.color = Color(0.01, 0.01, 0.015, 0.88)
	add_child(dim)
	var m := UI.margin(get_viewport(), 26)
	add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	m.add_child(col)
	var head := UI.header("Credits", func(): closed.emit())
	col.add_child(head)
	var lic := UI.button("Licences", 17, 160)
	lic.custom_minimum_size.y = 44
	lic.pressed.connect(func(): show_licences() if _rolling else show_roll())
	head.add_child(lic)
	col.add_child(UI.rule())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.gui_input.connect(func(e: InputEvent):
		if e is InputEventScreenDrag or e is InputEventScreenTouch or e is InputEventMouseButton:
			_hold = 3.0)
	col.add_child(_scroll)
	_col = VBoxContainer.new()
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_theme_constant_override("separation", 6)
	_scroll.add_child(_col)
	set_meta("toggle", lic)
	show_roll()

func _clear() -> void:
	for c in _col.get_children():
		_col.remove_child(c)
		c.queue_free()
	_scroll.scroll_vertical = 0
	_pos = 0.0
	_hold = 1.2

func _line(text: String, size: int, color: Color, kind: String = "body") -> void:
	var l := UI.wrapped(text, size, color, 0.0, kind)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 760
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(l)

func show_roll() -> void:
	_rolling = true
	(get_meta("toggle") as Button).text = "LICENCES"
	_clear()
	_col.add_child(UI.spacer(60))
	var mark := Emblem.new(110)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(mark)
	_line("HOLLOW REIGN", 44, UI.BONE, "title")
	var orn := UI.ornament(300)
	orn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(orn)
	_col.add_child(UI.spacer(30))
	for s in data.get("sections", []):
		_line(str(s.heading).to_upper(), 22, UI.GOLD, "head")
		for l in s.lines:
			_line(str(l), 20, UI.BONE)
		_col.add_child(UI.spacer(26))
	_line("The full licence texts are under Licences, above.", 18, UI.DIM)
	_col.add_child(UI.spacer(40))
	_line("Thank you for walking it.", 22, UI.GOLD, "head")
	_col.add_child(UI.spacer(420))

func show_licences() -> void:
	_rolling = false
	(get_meta("toggle") as Button).text = "CREDITS"
	_clear()
	for l in data.get("licences", []):
		_block(str(l.title), str(l.text))
	_block("Godot Engine", Engine.get_license_text())
	# the engine's third-party notices: every component, who holds it, and under what
	var parts: Array = []
	for c in Engine.get_copyright_info():
		var holders: Array = []
		var kinds: Array = []
		for p in c.parts:
			for h in p.copyright:
				if not holders.has(str(h)):
					holders.append(str(h))
			if not kinds.has(str(p.license)):
				kinds.append(str(p.license))
		parts.append("%s  (%s)\n%s" % [c.name, ", ".join(kinds), "; ".join(holders.slice(0, 4)) + (" and others" if holders.size() > 4 else "")])
	_block("Third-party components of the engine", "\n\n".join(parts))
	var texts: Dictionary = Engine.get_license_info()
	var names := texts.keys()
	names.sort()
	for n: String in names:
		_block(n, str(texts[n]))

func _block(heading: String, text: String) -> void:
	var t := UI.title(heading, 21, UI.GOLD)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(t)
	_col.add_child(UI.rule())
	# long texts go in pieces, so no single label has to lay out thousands of lines
	var lines := text.split("\n")
	var i := 0
	while i < lines.size():
		var l := UI.wrapped("\n".join(lines.slice(i, i + 60)), 16, UI.DIM.lightened(0.3))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_col.add_child(l)
		i += 60
	_col.add_child(UI.spacer(22))

func _process(delta: float) -> void:
	if not _rolling:
		return
	if _hold > 0.0:
		_hold -= delta
		_pos = float(_scroll.scroll_vertical)
		return
	_pos += SPEED * delta
	_scroll.scroll_vertical = int(_pos)
	# at the end it simply stops, on the last line
	if _scroll.scroll_vertical < int(_pos) - 2:
		_pos = float(_scroll.scroll_vertical)
