class_name Aftermath
extends CineScene
## After the last duel (Generation III). No victory screen: the hall, and the quiet in it. The Monarch is down at the
## foot of his own dais and nothing stands him up. The machines run down. Then the Witness remembers a door, and a
## seam of light opens in the wall beside the throne.
##   1  wide, low, the length of the hall: the heir standing, the Monarch down, the engines dark   (silence)
##   2  the empty throne, held
##   3  the Witness at the heir's shoulder: "There is a door. Not from this side of the wall."
##   4  the wall beside the dais parts on white; the heir walks into it
## It ends on white, which is where the Facility begins.
## Dev: hold_at = "hall" | "throne" | "door".

const DOOR := Vector3(-5.6, 0, -13.6)

var arena: Arena
var hall: FinalHall
var hero: CineActor
var monarch: FighterRig
var _leaves: Array = []
var _door_light: OmniLight3D

func _ready() -> void:
	begin()
	arena = Arena.new()
	add_child(arena)
	arena.build("throne")
	arena.env.ambient_light_energy = 1.2
	hall = FinalHall.dress(arena)
	hall.set_level(2, true)
	hero = CineActor.knight(self)
	hero.footsteps = true
	hero.position = Vector3(0.4, 0, 0.8)
	monarch = FighterRig.new()
	add_child(monarch)
	monarch.build(CineActor.foe_look("forgotten_monarch"), true)
	monarch.position = Vector3(0.2, 0, -5.2)
	monarch.rotation.y = PI
	monarch.die(1.0)
	# the door the Witness remembers: two leaves in the wall by the dais, shut, with nothing to show they are a door
	var metal := Look.flat(Color("#2a2c2e"), 0.5, 0.85)
	arena.box(Vector3(3.6, 5.2, 0.5), DOOR + Vector3(0, 2.6, -0.5), Look.glow(Color("#fff4e0"), 4.5))
	for sx: float in [-1.0, 1.0]:
		var leaf := arena.box(Vector3(1.7, 5.0, 0.4), DOOR + Vector3(sx * 0.85, 2.5, 0), metal)
		OldMake.box(leaf, Vector3(1.3, 0.08, 0.06), Vector3(0, 1.2, 0.22), metal)
		OldMake.box(leaf, Vector3(1.3, 0.08, 0.06), Vector3(0, -1.2, 0.22), metal)
		OldMake.torus(leaf, 0.42, 0.05, Vector3(-sx * 0.55, 0, 0.2), metal, 24, 6).rotation.x = PI * 0.5
		_leaves.append(leaf)
	OldMake.portal(arena, DOOR + Vector3(0, 0, 0.1), 3.5, 5.0, FinalHall.lamp(FinalHall.TEAL, 0.5), metal)
	_door_light = OmniLight3D.new()
	_door_light.light_color = Color("#fff0d8")
	_door_light.light_energy = 0.0
	_door_light.omni_range = 14.0
	_door_light.position = DOOR + Vector3(0, 2.4, 1.2)
	arena.add_child(_door_light)
	Sfx.ambience("wind")
	Sfx.music("", 0.5)
	_run()

func _run() -> void:
	# 1: nothing is said, nothing is counted
	cam.cut(Vector3(2.4, 0.6, 7.4), Vector3(0.0, 1.4, -6.0), 40.0)
	cam.move(Vector3(2.0, 0.7, 6.4), Vector3(0.0, 1.5, -6.0), 12.0)
	cards.fade(0.0, 2.4)
	if not await _w(2.6):
		return
	hall.run_down(6.0)
	if _held("hall"):
		return
	if not await _w(5.4):
		return
	# 2: the seat he never left for long
	cam.cut(Vector3(0.0, 2.2, -5.0), Vector3(0.0, 4.2, -18.0), 34.0)
	cam.move(Vector3(0.0, 2.3, -6.2), Vector3(0.0, 4.4, -18.0), 9.0)
	if _held("throne"):
		return
	if not await _w(5.0):
		return
	# 3: the Witness
	var hip: Vector3 = hero.drone.global_position if hero.drone != null else hero.position + Vector3(0.24, 0.72, 0.06)
	cam.cut(hip + Vector3(0.95, 0.12, 0.75), hip, 30.0)
	if not await _w(0.8):
		return
	if not await _say("final_door"):
		return
	# 4: the wall beside the dais
	cam.cut(Vector3(-4.0, 1.6, -8.4), DOOR + Vector3(0, 2.3, 0), 50.0)
	cam.move(Vector3(-4.3, 1.6, -9.0), DOOR + Vector3(0, 2.3, 0), 8.0)
	Sfx.play("guard_break", -8.0, 0.5)
	Sfx.play("shield_scrape", -9.0, 0.5)
	for i in 2:
		var leaf: MeshInstance3D = _leaves[i]
		leaf.create_tween().tween_property(leaf, "position:x", leaf.position.x + (-1.75 if i == 0 else 1.75), 3.4).set_trans(Tween.TRANS_SINE)
	create_tween().tween_property(_door_light, "light_energy", 7.0, 3.4)
	hero.position = Vector3(-2.6, 0, -6.6)
	walk(hero, DOOR + Vector3(-0.4, 0, 2.6), 1.2)
	if not await _w(3.6):
		return
	if _held("door"):
		return
	cards.fade(1.0, 2.6, true)
	await walk(hero, DOOR + Vector3(0, 0, -0.4), 1.35).finished
	if _over:
		return
	_end()

func _closing() -> void:
	if cards:
		cards.veil.color = Color(1.0, 0.97, 0.9, 1.0)
