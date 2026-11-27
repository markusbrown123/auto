class_name CineCards
extends CanvasLayer
## What is laid over the story scenes: a veil to fade through, the game's name, a card for a year or a chapter,
## one line of instruction, the family's mark, and SKIP.

signal skip_pressed

var veil: ColorRect
var logo: Control
var card: Label
var hint: Label
var emblem: Control
var skip: Button

func _init() -> void:
	layer = 70
	veil = UI.full(ColorRect.new())
	veil.color = Color(0.01, 0.01, 0.012, 1.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	# the game's mark, as the menu sets it: the name and a rule under it
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	v.offset_top = 92
	v.offset_left = 70
	v.offset_right = 760
	v.add_theme_constant_override("separation", 2)
	var t := UI.label("HOLLOW REIGN", 76, UI.BONE, "title")
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	t.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(t)
	var orn := UI.ornament(470, UI.GOLD)
	orn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(orn)
	logo = v
	card = UI.title("", 34, UI.BONE)
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	card.offset_left = 70
	card.offset_top = -190
	card.offset_right = 1000
	card.offset_bottom = -120
	hint = UI.title("", 24, UI.GOLD)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint.offset_left = -520
	hint.offset_right = 520
	hint.offset_top = 150                 # under the duel's own toasts ("DOUBLE SLASH"), which sit at 96 to 136
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for l: Label in [card, hint]:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_y", 2)
	emblem = Emblem.new(210.0, UI.GOLD)
	emblem.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	emblem.offset_left = -105
	emblem.offset_right = 105
	emblem.offset_top = -150
	emblem.offset_bottom = 60
	for c: Control in [logo, card, hint, emblem]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in c.get_children():
			if k is Control:
				(k as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.modulate.a = 0.0
		add_child(c)
	skip = UI.menu_item("SKIP  ›", 15, 110)
	skip.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip.add_theme_color_override("font_color", UI.BONE)
	skip.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	skip.add_theme_constant_override("outline_size", 5)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	# clear of a phone's notch and rounded corner, and tall enough for a thumb (the word stays small)
	var inset: float = float(UI.safe_margins(null).r)
	skip.offset_left = -146 - inset
	skip.offset_top = 86                 # below a duel's pause button, which is in this corner
	skip.offset_right = -inset
	skip.offset_bottom = 146
	skip.modulate.a = 0.0
	skip.pressed.connect(func(): skip_pressed.emit())
	add_child(skip)

func _ready() -> void:
	create_tween().tween_property(skip, "modulate:a", 0.6, 0.8).set_delay(2.0)

func clear() -> void:
	for c: Control in [logo, card, hint, emblem]:
		c.modulate.a = 0.0

## Fades the veil to `to` (0 clear, 1 covered) over `time`; `tint` chooses black or the white of weather and years.
func fade(to: float, time: float, white: bool = false) -> void:
	veil.color = Color(1.0, 0.97, 0.9, veil.color.a) if white else Color(0.01, 0.01, 0.012, veil.color.a)
	var tw := create_tween()
	tw.tween_property(veil, "color:a", to, time)
	await tw.finished

func show_card(text: String, hold: float) -> void:
	card.text = text
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.8)
	tw.tween_interval(hold)
	tw.tween_property(card, "modulate:a", 0.0, 0.8)

func show_item(c: Control, hold: float, rise: float = 1.4) -> void:
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, rise)
	tw.tween_interval(hold)
	tw.tween_property(c, "modulate:a", 0.0, 1.0)

## One line of instruction over a fight: shown while `text` is not empty.
func say(text: String, delta: float) -> void:
	if text != "" and hint.text != text:
		hint.text = text
	hint.modulate.a = move_toward(hint.modulate.a, 0.95 if text != "" else 0.0, delta * 4.0)
