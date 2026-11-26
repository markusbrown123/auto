class_name CineScene
extends Node3D
## What the directed story scenes of the later generations share: the cards and SKIP, a camera, waiting on time and
## on a spoken line, and one way of ending. A scene builds itself in _ready(), calls begin(), and runs from _run().
## However it ends (played through or skipped), _closing() is called exactly once before `finished`:
## anything the story must have done by then (a fall recorded, a blade taken) belongs there.

signal finished

var cards: CineCards
var cam: CineCam
var auto := false                 # dev captures and tests: prompts answer themselves
var hold_at := ""                 # dev captures: a named moment to stop on (each scene lists its own)
var _over := false
var _clock := 0.0

func begin() -> void:
	cards = CineCards.new()
	add_child(cards)
	cards.skip_pressed.connect(skip)
	cam = CineCam.new()
	add_child(cam)

func _w(t: float) -> bool:
	await get_tree().create_timer(t).timeout
	return not _over

## Which line of the scene being spoken is on screen (99 when nothing is being said).
func _now(id: String) -> int:
	if not Story.busy:
		return 99
	var lines: Array = Story.data.scenes[id].lines
	for k in lines.size():
		if str(Story.data.lines[lines[k]].text) == Story._text.text:
			return k
	return -1

## Waits until line `i` of scene `id` is on screen (or the scene is over).
func _line(id: String, i: int) -> bool:
	while not _over and Story.busy and _now(id) < i:
		await get_tree().process_frame
	return not _over

func _spoken() -> bool:
	while not _over and Story.busy:
		await get_tree().process_frame
	return not _over

## Says a scene and waits for it.
func _say(id: String) -> bool:
	Story.play(id, true)
	return await _spoken()

## Dev captures: true when the scene should stop here for good (the frame is held; SKIP still ends it).
func _held(moment: String) -> bool:
	if hold_at != moment:
		return false
	cards.veil.color.a = 0.0
	return true

func walk(who: FighterRig, to: Vector3, speed: float = 1.35) -> Tween:
	var d := to - who.position
	who.rotation.y = atan2(-d.x, -d.z)
	who.walking = true
	var tw := who.create_tween()
	tw.tween_property(who, "position", to, maxf(d.length() / speed, 0.05))
	tw.tween_callback(func(): who.walking = false)
	return tw

func face(who: Node3D, point: Vector3, time: float) -> void:
	var d := point - who.position
	var yaw := atan2(-d.x, -d.z)
	var from := who.rotation.y
	who.create_tween().tween_property(who, "rotation:y", from + wrapf(yaw - from, -PI, PI), time).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	_clock += delta

func skip() -> void:
	_end()

func _end() -> void:
	if _over:
		return
	_over = true
	Story.stop()
	if cards:
		cards.veil.color = Color(0.01, 0.01, 0.012, 1.0)
	_closing()
	finished.emit()

func _exit_tree() -> void:
	_over = true                  # freed without ending (the router moved on): nothing is recorded; Continue takes it up again

## What must be true however the scene ended. Called once.
func _closing() -> void:
	pass
