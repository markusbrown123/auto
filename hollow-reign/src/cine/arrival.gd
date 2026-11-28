class_name Arrival
extends Node3D
## The second generation arrives. The same view of the fortress, twenty-two years on, and on the road the player's
## own knight in whatever they wear: one line, the game's name, and the walk up to the gate their parent went
## through. It ends at the foot of the ring; under it is the Inheritance Engine (Awakening).

signal finished

var road: HighRoad
var cards: CineCards
var only_shot := 0                # dev: hold on one shot of the walk (1-6)
var gen := 2
var line_scene := ""              # the scene spoken on arriving ("" = the second generation's own line)
var show_name := true             # the game's name over the road (the second generation's arrival only)
var card_text := ""               # a chapter card under the first shot ("" = none)
var _over := false

func _ready() -> void:
	cards = CineCards.new()
	add_child(cards)
	cards.skip_pressed.connect(skip)
	road = HighRoad.new()
	add_child(road)
	road.setup(gen)
	road.walker(Duel.player_look())
	if not Game.profile.is_empty():
		Game.profile.flags["generation"] = gen
	Sfx.music_for("theme", "menu", 2.0)
	_run()

func _run() -> void:
	if only_shot > 0:
		cards.veil.color.a = 0.0
		road.shot(only_shot)
		if only_shot == 1:
			cards.logo.modulate.a = 1.0
		return
	road.shot(1)
	cards.fade(0.0, 1.6)
	if not await _w(2.4):
		return
	var line := line_scene if line_scene != "" else "gen2_arrive_" + str(Game.profile.get("body", "m"))
	if card_text != "":
		cards.show_card(card_text, 3.4)
	Story.play(line, true)
	while Story.busy and not _over:
		await get_tree().process_frame
	if _over:
		return
	# they set off, and the game's name comes up over the road
	# (the road's own stride, so the next shot's stride stops it: a tween of our own on `road.s` outlived this walk by a
	# frame, and the next shot's walk then took its start from it and ran the walker 300 m in 12 s at 25 m/s, six
	# footfalls a second)
	road.stride(road.s, 30.0 + 6.5 * HighRoad.WALK)
	if show_name:
		cards.show_item(cards.logo, 3.6)
	if not await _w(6.4):
		return
	for i: int in [3, 4, 5, 6]:
		road.shot(i)
		if not await _w(float(HighRoad.HOLD[i]) - (2.0 if i != 6 else 0.5)):
			return
	await cards.fade(1.0, 0.6)
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
	Story.stop()
	cards.veil.color = Color(0.01, 0.01, 0.012, 1.0)
	finished.emit()
