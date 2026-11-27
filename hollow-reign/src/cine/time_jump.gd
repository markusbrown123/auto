class_name TimeJump
extends Node3D
## Years pass on the high road. The one view of the fortress, as one generation left it; the count of years;
## the weather closes over it and opens again on the same view as the next generation finds it.
## Reusable: TimeJump.make(22, 1, 2) after the first death, TimeJump.make(24, 2, 3) after the second.

signal finished

const WORDS := {22: "TWENTY-TWO YEARS", 24: "TWENTY-FOUR YEARS"}

var years := 22
var from_gen := 1
var to_gen := 2
var road: HighRoad
var cards: CineCards
var still: TextureRect            # the last generation's frame, dissolved over the next one's
var shown_gen := 0                # which generation's state the road is in
var veil_max := 0.0               # the thickest the weather got (tests)
var _over := false

const MUSIC := "theme"
const VEIL_PEAK := 0.34           # the most the weather ever covers: the fortress is always readable through it
const DISSOLVE := 3.4

static func make(n_years: int, from_generation: int, to_generation: int) -> TimeJump:
	var t := TimeJump.new()
	t.years = n_years
	t.from_gen = from_generation
	t.to_gen = to_generation
	return t

func _ready() -> void:
	cards = CineCards.new()
	add_child(cards)
	cards.skip_pressed.connect(skip)
	# the picture as the last generation left it, held under the cards while the live view changes beneath it
	var layer := CanvasLayer.new()
	layer.layer = 69
	add_child(layer)
	still = TextureRect.new()
	still.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_SCALE
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	still.visible = false
	layer.add_child(still)
	road = HighRoad.new()
	add_child(road)
	road.setup(from_gen)
	shown_gen = from_gen
	var v := HighRoad.vista()
	road.cam.cut(v[0], v[1], v[2])
	# the family's theme carries the years (the arrival that follows asks for the same cue, so it runs on unbroken)
	Sfx.music_for(MUSIC, "menu", 2.0)
	_run()

## The years pass over a picture, never over a blank frame: the fortress as it was, the count of years laid over
## it, and the same view dissolving into what the years have made of it while a little weather crosses.
func _run() -> void:
	cards.fade(0.0, 1.2)
	if not await _w(2.2):
		return
	cards.show_card(str(WORDS.get(years, "%d YEARS" % years)), 6.2)
	if not await _w(1.8):
		return
	_freeze()
	Highland.generation(road.arena, to_gen)
	shown_gen = to_gen
	_weather(VEIL_PEAK, 1.3, from_gen)
	var tw := create_tween()
	tw.tween_property(still, "modulate:a", 0.0, DISSOLVE).set_trans(Tween.TRANS_SINE)
	if not await _w(1.3):
		return
	await _weather(0.0, DISSOLVE - 1.3, to_gen)
	if _over:
		return
	still.visible = false
	# the aged view, and a slow push toward the gate the next of the house will walk to
	var v := HighRoad.vista()
	road.cam.move(v[0] + Vector3(0.3, 0.5, -1.6), v[1] + Vector3(0.0, 1.5, 0.0), 9.0)
	if not await _w(3.6):
		return
	await cards.fade(1.0, 0.5)
	_end()

## Keeps the frame on screen as a still, so the place can change under it and show through as the still fades.
func _freeze() -> void:
	var tex := get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		return                    # no picture to hold (a headless run): the weather alone covers the change
	still.texture = ImageTexture.create_from_image(img)
	still.modulate.a = 1.0
	still.visible = true

## The colour of a generation's weather: its haze, a little toward its sky.
func _air(g: int) -> Color:
	var s: Dictionary = Highland.SEASONS[clampi(g, 1, Highland.SEASONS.size()) - 1]
	return Color(str(s.fog)).lerp(Color(str(s.horizon)), 0.35).darkened(0.12)

func _weather(to: float, time: float, g: int) -> void:
	veil_max = maxf(veil_max, to)
	cards.veil.color = Color(_air(g), cards.veil.color.a)
	var tw := create_tween()
	tw.tween_property(cards.veil, "color:a", to, time).set_trans(Tween.TRANS_SINE)
	await tw.finished

func _w(t: float) -> bool:
	await get_tree().create_timer(t).timeout
	return not _over

func skip() -> void:
	_end()

func _end() -> void:
	if _over:
		return
	_over = true
	cards.veil.color = Color(0.01, 0.01, 0.012, 1.0)
	finished.emit()
