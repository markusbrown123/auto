class_name SecondFall
extends CineScene
## Generation II's end, "The Broken Crown": the second of the house secures the records behind the throne and is cut
## down doing it. Played in the throne hall straight after the duel with the Monarch, however that duel stood:
##   won = true    the player beat him. He is down; the hall's machines turn over and stand him up again
##                 ("I am not the thing that is keeping me."). Then the seal is the only thing left to do.
##   won = false   the player left the fight for the seal (choice "records") while it was still being fought.
## Either way: the seal burns, the knight goes to it and drives the blade in, the three lines, the blow. The camera
## stays on the Monarch from his first line on; nothing is shown of what is done with the one who fell.
## Then black, the family's mark, the narrator.
##
## The fall itself is Game.fall(2, …): recorded at the blow, or in _closing() if the scene is skipped or cut short.
## A win also clears the Throne's road for this generation first (the guardian was beaten).
## Dev: hold_at = "choice" | "rise" | "seal" | "fall" | "mark".

const SEAL := Vector3(6.2, 0, -8.2)

var won := false
var choice := "records"
var hall: Arena
var hero: CineActor
var monarch: CineActor
var _seal: OmniLight3D
var _fallen := false
var _burning := false
var _floor: Array = []

func _ready() -> void:
	begin()
	hall = Arena.new()
	add_child(hall)
	hall.build("throne")
	hall.env.ambient_light_energy = 1.7
	hall.env.tonemap_exposure = 1.35
	_seal = FinalHall.seal_panel(hall, SEAL)
	# the seal's housing: a frame of the old make round the panel, pipe runs up the wall from it, and a light on the
	# knight's side of it so that what is done there is seen (it was a dark figure at a wall panel)
	var frame := OldMake.portal(hall, SEAL + Vector3(1.2, 0, 0), 1.9, 3.0, FinalHall.lamp(FinalHall.TEAL, 1.2))
	frame.rotation.y = deg_to_rad(-70.0)
	for k in 4:
		OldMake.pipe(hall, SEAL + Vector3(1.5, 3.9, -0.4 + k * 0.28), SEAL + Vector3(2.2 + k * 0.2, 9.0, -1.2 + k * 0.4), 0.07, OldMake.metal())
	var fill := OmniLight3D.new()
	fill.light_color = Color("#ffe2c0")
	fill.light_energy = 1.5
	fill.omni_range = 7.0
	fill.position = SEAL + Vector3(-2.2, 2.4, 2.2)
	hall.add_child(fill)
	# under the paving, what keeps him: dark here, and seen only when it wakes
	for i in 7:
		var m := FinalHall.lamp(FinalHall.TEAL, 0.0)
		var strip := hall.box(Vector3(5.6, 0.03, 0.05), Vector3(0, 0.02, 4.0 - i * 2.2), m)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_floor.append(m)
	hero = CineActor.knight(self)
	hero.footsteps = true
	hero.position = Vector3(0.5, 0, 1.3)
	monarch = CineActor.new()
	add_child(monarch)
	monarch.build(CineActor.foe_look("forgotten_monarch"), true)
	monarch.position = Vector3(0, 0, -2.3)
	monarch.rotation.y = PI
	Sfx.ambience("wind")
	Sfx.music("", 1.5)
	_run()

func _process(delta: float) -> void:
	super(delta)
	if _burning and _seal:
		_seal.light_energy = 3.2 + 1.6 * sin(_clock * 11.0) + 0.9 * sin(_clock * 23.0)

func _run() -> void:
	if won:
		# he was beaten, and he is down. Nothing moves for a moment: the player is let have it.
		monarch.hold("wounded", 0.0)
		monarch.rotation.y = PI
		cam.cut(Vector3(3.4, 0.7, 2.9), Vector3(0.1, 0.7, -1.6), 40.0)
		cam.move(Vector3(3.0, 0.8, 2.3), Vector3(0.1, 0.8, -1.8), 9.0)
		cards.fade(0.0, 1.2)
		if not await _w(3.0):
			return
		# then the floor answers
		Sfx.play("levelup", -9.0, 0.45)
		for i in _floor.size():
			var tw := create_tween()
			tw.tween_interval(0.16 * i)
			tw.tween_property(_floor[i], "emission_energy_multiplier", 1.3, 0.5)
		hall.tint(FinalHall.TEAL, 0.18, 2.0)
		if not await _w(1.9):
			return
		monarch.hold("idle", 2.6)
		cam.cut(Vector3(1.3, 0.55, -0.2), monarch.position + Vector3(0, 1.5, 0), 38.0)
		cam.move(Vector3(1.0, 0.7, 0.3), monarch.position + Vector3(0, 2.0, 0), 5.0)
		if not await _w(2.4):
			return
		if _held("rise"):
			return
		if not await _say("monarch_restored"):
			return
		monarch.release(0.6)
		if not await _w(0.5):
			return
	else:
		monarch.guard()
		cam.cut(Vector3(-2.2, 1.5, 3.4), SEAL + Vector3(0, 1.5, 0), 42.0)
		cards.fade(0.0, 0.7)
		if not await _w(0.8):
			return
	# the seal burns: what the first could only send part of
	_burning = true
	_seal.light_color = Color("#ffb070")
	Sfx.play("ember_burst", -6.0)
	cam.cut(Vector3(-2.6, 1.5, 3.0), SEAL + Vector3(0, 1.5, 0), 42.0)
	cam.move(Vector3(-1.2, 1.5, 0.6), SEAL + Vector3(0, 1.5, 0), 5.0)
	Story.play("gen2_seal_burns", true)
	face(hero, SEAL, 0.5)
	if not await _w(0.7):
		return
	await walk(hero, SEAL + Vector3(-1.7, 0, 1.25), 2.0).finished
	if _over:
		return
	face(hero, SEAL + Vector3(1.2, 0, 0), 0.35)
	if not await _spoken():
		return
	# the blade goes into it, as the first one's went into the block
	hero.swing(Vector2(0.0, -1.0), 0.5)
	if not await _w(0.32):
		return
	_burning = false
	_seal.light_color = FinalHall.TEAL
	Sfx.play("swing", -5.0, 0.7)
	Sfx.play("levelup", -7.0, 0.5)
	var flare := create_tween()
	flare.tween_property(_seal, "light_energy", 16.0, 0.4)
	flare.tween_property(_seal, "light_energy", 5.0, 3.0)
	# the knight at the seal, and the Monarch coming between it and us
	walk(monarch, SEAL + Vector3(-4.3, 0, 3.4), 1.05)
	# (from the seal's own side of the hall: the Monarch crosses the left of the frame and does not hide the knight)
	cam.cut(Vector3(3.6, 1.3, 3.0), SEAL + Vector3(-0.6, 1.3, 0.6), 40.0)
	cam.move(Vector3(3.9, 1.25, 2.0), SEAL + Vector3(-0.6, 1.3, 0.6), 7.0)
	if _held("seal"):
		return
	Story.play("gen2_seal", true)
	if not await _line("gen2_seal", 1):
		return
	# from here the camera does not leave him
	cam.cut(hero.position + Vector3(-0.9, 0.55, 0.5), monarch.position + Vector3(0, 2.0, 0), 34.0)
	cam.follow = null
	cam.move(hero.position + Vector3(-1.1, 0.6, 0.8), SEAL + Vector3(-3.0, 2.0, 2.4), 6.0)
	if not await _spoken():
		return
	await walk(monarch, hero.position + Vector3(-1.3, 0, 1.5), 1.3).finished
	if _over:
		return
	face(monarch, hero.position, 0.2)
	cam.cut(monarch.position + Vector3(-2.1, 0.7, 3.0), monarch.position + Vector3(0, 2.0, 0), 34.0)       # from the hall, up at him: he stands between us and the seal
	monarch.telegraph(Vector2(-0.8, -0.5), 0.7, 0.3)
	if not await _w(0.72):
		return
	# the blow, and the transfer complete
	record_fall()
	Sfx.play("finisher", 0.0, 0.8)
	Sfx.play("bell", -5.0, 0.6)
	cards.veil.color = Color(1.0, 0.97, 0.9, 0.85)
	create_tween().tween_property(cards.veil, "color:a", 0.0, 0.5)
	create_tween().tween_property(_seal, "light_energy", 0.25, 1.8)
	monarch.guard()
	cam.move(cam.pos + Vector3(-0.3, 0.1, 0.5), monarch.position + Vector3(0, 2.0, 0), 5.0)
	if _held("fall"):
		return
	if not await _w(3.6):
		return
	await cards.fade(1.0, 1.4)
	if _over:
		return
	# the family's mark, and what was written of this one
	cards.show_item(cards.emblem, 6.0, 1.6)
	if _held("mark"):
		cards.emblem.modulate.a = 1.0
		cards.veil.color = Color(0.01, 0.01, 0.012, 1.0)
		return
	if not await _say("gen2_close"):
		return
	if not await _w(1.4):
		return
	_end()

## The second generation falls. Once; safe to call again.
func record_fall() -> void:
	if _fallen or Game.profile.is_empty():
		return
	_fallen = true
	if won and str(Game.run.get("region", "")) == "throne":
		Game.complete_region()        # he was beaten: this generation did clear the Throne's road
	Game.fall(2, "saved_the_records", {"choice": choice, "won": won})

func _closing() -> void:
	record_fall()
