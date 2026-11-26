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
var _over := false

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
	road = HighRoad.new()
	add_child(road)
	road.setup(from_gen)
	var v := HighRoad.vista()
	road.cam.cut(v[0], v[1], v[2])
	Sfx.music("", 2.0)
	_run()

func _run() -> void:
	cards.fade(0.0, 1.4)
	if not await _w(2.6):
		return
	cards.show_card(str(WORDS.get(years, "%d YEARS" % years)), 4.4)
	if not await _w(1.4):
		return
	# the weather closes over the road, and when it opens the years have been at it
	await cards.fade(1.0, 1.5, true)
	if _over:
		return
	Highland.generation(road.arena, to_gen)
	if not await _w(0.5):
		return
	await cards.fade(0.0, 2.2, true)
	if not await _w(2.6):
		return
	await cards.fade(1.0, 0.5)
	_end()

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
