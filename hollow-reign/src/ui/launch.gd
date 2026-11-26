class_name Launch
extends Node
## What the player sees first: a studio card, then the game's mark, then the menu.
## Under four seconds, any tap skips it, and after the first launch only the mark is shown, briefly.

signal finished

const STUDIO := "Cairnlight Workshop"      # a text mark only; no real company is meant. Change it here.
const STUDIO_LINE := "an independent work"
const SEEN_FILE := "user://launched"

var layer: CanvasLayer
var _done := false
var _card: Control
var _mark: Control

static func seen_before() -> bool:
	return FileAccess.file_exists(Game._p(SEEN_FILE))

## Total length in seconds, so the router and the tests can check the promise.
static func length(first: bool) -> float:
	return 3.6 if first else 1.7

func _ready() -> void:
	UI.apply(self)
	var first := not seen_before()
	layer = CanvasLayer.new()
	add_child(layer)
	var bg: ColorRect = UI.full(ColorRect.new())
	bg.color = Color(0.012, 0.012, 0.016)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch or e is InputEventMouseButton or e is InputEventKey) and e.is_pressed():
			_finish())
	layer.add_child(bg)
	_card = _center([UI.label(STUDIO.to_upper(), 30, UI.SILVER, "head"), UI.ornament(220, UI.GOLD_DIM), UI.label(STUDIO_LINE, 18, UI.DIM)])
	_mark = _center([Emblem.new(150), UI.spacer(6), UI.label("HOLLOW REIGN", 46, UI.BONE, "title"), UI.ornament(300, UI.GOLD_DIM)])
	_card.modulate.a = 0.0
	_mark.modulate.a = 0.0
	var tw := create_tween()
	if first:
		tw.tween_property(_card, "modulate:a", 1.0, 0.35)
		tw.tween_interval(0.85)
		tw.tween_property(_card, "modulate:a", 0.0, 0.3)
		tw.tween_property(_mark, "modulate:a", 1.0, 0.5)
		tw.tween_interval(1.2)
	else:
		tw.tween_property(_mark, "modulate:a", 1.0, 0.4)
		tw.tween_interval(0.9)
	tw.tween_property(_mark, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_finish)
	var f := FileAccess.open(Game._p(SEEN_FILE), FileAccess.WRITE)
	if f:
		f.store_string("1")

func _center(parts: Array) -> Control:
	var c: CenterContainer = UI.full(CenterContainer.new())
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(c)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	for p: Control in parts:
		p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if p is Label:
			p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(p)
	return c

func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
