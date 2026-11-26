class_name Chronicle
extends Control
## What the knight has found out: records read, sequences learned, guardians ended, endings seen,
## and (when the Witness is travelling with the knight) the stories it has told.

signal closed

const ENDING_NAME := {"silence": "The Final Silence", "steward": "The Last Steward", "cities": "The Free Cities"}
const ENDING_LINE := {
	"silence": "The Crown was disconnected, and everything it held went quiet.",
	"steward": "The Crown was taken up, to be worn differently.",
	"cities": "The Crown was divided, so that nobody could rule it.",
}
const DIR_WORD := {"L": "Left", "R": "Right", "U": "Up", "D": "Down"}

var tab := "Records"
var _tabs: HBoxContainer
var _body: VBoxContainer
var _scroll: ScrollContainer

func _init(start_tab: String = "Records") -> void:
	tab = start_tab

func tabs() -> Array:
	var out := ["Records", "Sequences", "Guardians", "Endings"]
	if has_node("/root/Companion") and get_node("/root/Companion").has_method("archive"):
		out.append("Stories")
	return out

func _ready() -> void:
	UI.apply(self)
	UI.full(self)
	var dim: ColorRect = UI.full(ColorRect.new())
	dim.color = Color(0.01, 0.01, 0.015, 0.82)
	add_child(dim)
	var m := UI.margin(get_viewport(), 26)
	add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size.x = 900
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.add_child(col)
	col.add_child(UI.header("Chronicle", func(): closed.emit()))
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	col.add_child(_tabs)
	var p := UI.panel()
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size.x = 900
	col.add_child(p)
	UI.corners(p, UI.GOLD_DIM.lightened(0.2))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(_scroll)
	var pad := MarginContainer.new()      # keeps the text clear of the scroll hairline
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 16)
	_scroll.add_child(pad)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	pad.add_child(_body)
	if not tabs().has(tab):
		tab = "Records"
	show_tab(tab)

func show_tab(t: String) -> void:
	tab = t
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	for name_: String in tabs():
		var b := UI.button(name_, 17, 150)
		b.custom_minimum_size.y = 44
		if name_ == tab:
			b.add_theme_color_override("font_color", UI.GOLD)
			b.add_theme_stylebox_override("normal", UI._button_box("hover"))
		b.pressed.connect(func(): show_tab(name_))
		_tabs.add_child(b)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_scroll.scroll_vertical = 0
	call("_tab_" + t.to_lower())
	UI.stagger(_body, 0.02, 0.22)

func _head(text: String, note: String = "") -> void:
	var h := HBoxContainer.new()
	h.add_child(UI.title(text, 21, UI.GOLD))
	var gap := UI.spacer(0)
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(gap)
	if note != "":
		h.add_child(UI.label(note, 18, UI.DIM))
	_body.add_child(h)
	_body.add_child(UI.rule())

func _entry(heading: String, text: String, heading_color: Color = UI.BONE) -> void:
	_body.add_child(UI.label(heading, 20, heading_color, "bold"))
	if text != "":
		_body.add_child(UI.wrapped(text, 19, UI.DIM.lightened(0.25), 820))
	_body.add_child(UI.spacer(4))

func _tab_records() -> void:
	var total := 0
	for r in Db.regions:
		if not Game.region_unlocked(r.id):
			continue
		var found: Array = []
		var all := 0
		for l in Db.lore:
			if str(l.region) == str(r.id):
				all += 1
				if Game.profile.lore.has(l.id):
					found.append(l)
		total += found.size()
		_head(str(r.name), "%d of %d" % [found.size(), all])
		for l in found:
			_entry(str(l.title), str(l.text), UI.BONE)
		if found.size() < all:
			var left := all - found.size()
			_body.add_child(UI.label("%d record%s here still unread." % [left, "" if left == 1 else "s"], 18, UI.DIM))
		_body.add_child(UI.spacer(10))
	_body.add_child(UI.label("%d of %d records recovered. Roads not yet walked are not listed." % [total, Db.lore.size()], 18, UI.GOLD_DIM.lightened(0.3)))

func _tab_sequences() -> void:
	var known := 0
	for c in Db.combos:
		known += 1 if Game.profile.combos.has(c.id) else 0
	_head("Sequences", "%d of %d found" % [known, Db.combos.size()])
	for c in Db.combos:
		if Game.profile.combos.has(c.id):
			var steps: Array = []
			for d in c.seq:
				steps.append(str(DIR_WORD.get(str(d), str(d))))
			var uses := int(Game.profile.combo_uses.get(c.id, 0))
			_entry("%s   ·   %s" % [c.name, "  ›  ".join(steps)], "%s  %s%s" % [c.get("kind", ""), c.get("use", ""), ("   Used %d times." % uses) if uses > 0 else ""], UI.BONE)
		else:
			_entry("Not yet found", "", UI.DIM)

func _tab_guardians() -> void:
	var bosses: Array = []
	var ended := 0
	for id: String in Db.foes:
		if Db.foes[id].boss:
			bosses.append(Db.foes[id])
			ended += 1 if Game.profile.defeated.has(id) else 0
	_head("Guardians", "%d of %d ended" % [ended, bosses.size()])
	for f in bosses:
		if Game.profile.defeated.has(f.id):
			var n := int(Game.profile.defeated[f.id])
			_entry(str(f.name), "Ended%s." % ("" if n <= 1 else " %d times" % n), UI.GOLD)
		else:
			_entry("Not yet met", "", UI.DIM)

func _tab_endings() -> void:
	_head("Endings", "%d of %d seen" % [Game.profile.endings.size(), ENDING_NAME.size()])
	for id: String in ENDING_NAME:
		if Game.profile.endings.has(id):
			_entry(str(ENDING_NAME[id]), str(ENDING_LINE[id]), UI.GOLD)
		else:
			_entry("Not yet seen", "", UI.DIM)
	if int(Game.profile.ng) > 0:
		_body.add_child(UI.label("The kingdom has been walked %d time%s over." % [int(Game.profile.ng), "" if int(Game.profile.ng) == 1 else "s"], 18, UI.GOLD_DIM.lightened(0.3)))

func _tab_stories() -> void:
	var list = get_node("/root/Companion").archive()
	var n: int = list.size() if (list is Array or list is Dictionary) else 0
	_head("Stories", "%d heard" % n)
	if n == 0:
		_body.add_child(UI.label("Nothing has been told yet.", 19, UI.DIM))
		return
	if list is Dictionary:
		for k in list:
			_story(list[k], str(k))
	else:
		for s in list:
			_story(s, "")

func _story(s, fallback: String) -> void:
	if s is Dictionary:
		var heading := str(s.get("title", s.get("name", s.get("id", fallback))))
		var text = s.get("lines", s.get("text", s.get("summary", "")))
		if text is Array:
			# each line as it was spoken, with who spoke it
			var parts: Array = []
			for line in text:
				if line is Dictionary:
					var who := str(line.get("name", ""))
					parts.append(("%s:  " % who if who != "" else "") + str(line.get("text", "")))
				else:
					parts.append(str(line))
			text = "\n".join(parts)
		_entry(heading, str(text), UI.BONE)
	else:
		_entry(str(s) if fallback == "" else fallback, "" if fallback == "" else str(s))
