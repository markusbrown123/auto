class_name EndingScene
extends CineScene
## The three endings, each a short directed scene in the engine (they were text panels). All three begin in the
## Crown's chamber beneath the throne: the heir at the coupling, the racks of stored minds either side, the Crown
## turning at the end of them. What is done at the coupling is the ending:
##   "silence"  The Final Silence   the coupling is drawn. The racks go dark from the far end, the Crown runs down and
##                                  stops, Lyra is gone mid-chamber. Then the high road at first light, and no bells.
##   "steward"  The Last Steward    the Crown's light turns to the heir. Then the throne hall: the pylons wake down its
##                                  length as the heir walks to the dais and stands before the seat.
##   "cities"   The Free Cities     the Crown comes apart into three rings that draw away from one another, each its
##                                  own colour, and the racks take those colours row by row. A door opens on daylight,
##                                  and someone is standing in it.
## Lines: scenes ending_<id> in data/dialogue.json (subtitles; voice ids exist, nothing is recorded).
## The camera set-ups each ending has cut to are listed in `shots` as they happen.
## Dev: hold_at = "coupling" | "crown" | "last".

const TITLES := {"silence": "THE FINAL SILENCE", "steward": "THE LAST STEWARD", "cities": "THE FREE CITIES"}
const TEAL := Color("#5fe0c8")
const GOLD := Color("#ffd890")
const COUPLING := Vector3(0, 0, -6.0)
const CROWN_AT := Vector3(0, 9.5, -46.0)
const PARTS := [Color("#5fe0c8"), Color("#ffb45a"), Color("#b07aff")]

var id := "silence"
var shots: Array = []
var arena: Arena
var hero: CineActor
var set_a: Node3D                 # the Crown's chamber
var set_b: Node3D                 # where the ending ends (the road, or the hall), built when it is cut to
var _racks: Array = []            # lamp materials, nearest row first
var _crown: Node3D
var _crown_rings: Array = []      # three ring nodes, outermost first
var _crown_mats: Array = []
var _crown_light: OmniLight3D
var _spin := 1.0
var _wheel: Node3D
var _door_light: OmniLight3D
var _figure: Node3D

static func make(ending: String) -> EndingScene:
	var e := EndingScene.new()
	e.id = ending if TITLES.has(ending) else "silence"
	return e

func _ready() -> void:
	begin()
	_chamber()
	Sfx.ambience("crypt")
	Sfx.music_for("explore_deep", "menu", 3.0)
	_run()

# ================================================================ the set
func _chamber() -> void:
	set_a = Node3D.new()
	add_child(set_a)
	arena = Arena.new()
	set_a.add_child(arena)
	arena.build("deep")
	arena.env.fog_density = 0.01
	arena.env.ambient_light_energy = 1.25
	for c: Node in arena.get_children():
		if c is Node3D and not c is Light3D and not c is WorldEnvironment and absf((c as Node3D).position.x) < 9.0 and (c as Node3D).position.z < 4.0 and (c as Node3D).position.length() > 0.5:
			c.queue_free()
	var metal := OldMake.metal()
	for row: int in 6:
		var z := -4.0 - row * 6.2
		var m := FinalHall.lamp(TEAL if row % 3 != 2 else Color("#ffb45a"), 2.2)
		for sx: float in [-1.0, 1.0]:
			OldMake.rack(arena, Vector3(sx * (6.6 + row * 0.35), 0, z), Vector3(1.3, 9.0, 4.4), m, 8, -sx, row * 2 + int(sx))
		_racks.append(m)
	# the Crown: three rings one inside another, turning against each other, and its light
	_crown = Node3D.new()
	arena.add_child(_crown)
	_crown.position = CROWN_AT
	for k: int in 3:
		var m2 := FinalHall.lamp(GOLD, 5.0)
		_crown_mats.append(m2)
		_crown_rings.append(OldMake.ring(_crown, 8.6 - k * 2.5, 0.7 - k * 0.14, m2, 13 - k * 3, true, metal))
	_crown_light = OmniLight3D.new()
	_crown_light.light_color = GOLD
	_crown_light.light_energy = 8.0
	_crown_light.omni_range = 46.0
	_crown_light.omni_attenuation = 0.7
	_crown_light.position = Vector3(0, 0, 4.0)
	_crown.add_child(_crown_light)
	# the coupling: a pedestal on the chamber's axis with a hand-wheel on it, and the lines that run from it to the Crown
	var ped := Node3D.new()
	arena.add_child(ped)
	ped.position = COUPLING
	OldMake.cyl(ped, 0.5, 0.62, 0.2, Vector3(0, 0.1, 0), metal, 10)
	OldMake.cyl(ped, 0.16, 0.24, 1.0, Vector3(0, 0.7, 0), metal, 8)
	OldMake.box(ped, Vector3(0.7, 0.1, 0.45), Vector3(0, 1.22, 0), metal, Vector3(0.35, 0, 0))
	_wheel = Node3D.new()
	ped.add_child(_wheel)
	_wheel.position = Vector3(0, 1.32, 0.05)
	_wheel.rotation.x = 0.35
	OldMake.torus(_wheel, 0.24, 0.03, Vector3.ZERO, metal, 20, 6)
	for k2: int in 3:
		OldMake.box(_wheel, Vector3(0.46, 0.03, 0.04), Vector3.ZERO, metal, Vector3(0, PI * k2 / 3.0, 0))
	OldMake.box(ped, Vector3(0.5, 0.03, 0.05), Vector3(0, 1.2, 0.22), FinalHall.lamp(GOLD, 2.0), Vector3(0.35, 0, 0))
	for sx2: float in [-1.0, 1.0]:
		OldMake.pipe(arena, COUPLING + Vector3(sx2 * 0.5, 0.08, -0.4), Vector3(sx2 * 2.4, 0.08, -40.0), 0.09, metal)
	var key := OmniLight3D.new()
	key.light_color = Color("#d8f2ec")
	key.light_energy = 1.5
	key.omni_range = 8.0
	key.position = COUPLING + Vector3(1.6, 2.6, 2.4)
	arena.add_child(key)
	hero = CineActor.knight(self)
	hero.footsteps = true
	hero.position = Vector3(0.3, 0, 3.6)
	hero.rotation.y = 0.0

func _process(delta: float) -> void:
	super(delta)
	for k: int in _crown_rings.size():
		if is_instance_valid(_crown_rings[k]):
			(_crown_rings[k] as Node3D).rotation.z += delta * _spin * [0.06, -0.14, 0.24][k]

func _shot(name: String, pos: Vector3, look: Vector3, fov: float) -> void:
	shots.append(name)
	cam.cut(pos, look, fov)

# ================================================================ what is common, then each
func _run() -> void:
	# the chamber, and the heir going down it to the coupling
	_shot("chamber", Vector3(2.6, 1.5, 9.0), Vector3(0.0, 5.0, -30.0), 46.0)
	cam.move(Vector3(2.0, 1.7, 7.4), Vector3(0.0, 5.6, -30.0), 9.0)
	cards.fade(0.0, 1.6)
	walk(hero, COUPLING + Vector3(0.05, 0, 0.95), FighterRig.ROAD_SPEED)
	if not await _w(4.2):
		return
	Story.play("ending_" + id, true)
	_shot("coupling", COUPLING + Vector3(1.5, 1.45, 2.3), COUPLING + Vector3(0, 1.25, 0), 36.0)
	cam.move(COUPLING + Vector3(1.2, 1.5, 2.0), COUPLING + Vector3(0, 1.3, 0), 8.0)
	if _held("coupling"):
		return
	match id:
		"steward":
			await _steward()
		"cities":
			await _cities()
		_:
			await _silence()
	if _over or (hold_at != "" and hold_at != "last"):
		return
	cards.show_card(str(TITLES[id]), 4.0)
	if _held("last"):
		cards.card.modulate.a = 1.0
		return
	if not await _spoken():
		return
	if not await _w(3.2):
		return
	await cards.fade(1.0, 2.0)
	_end()

## The hand goes to the wheel, and the wheel turns.
func _turn_wheel(turns: float, time: float) -> void:
	hero.set_armed(false)
	Sfx.play("shield_scrape", -9.0, 0.5)
	create_tween().tween_property(_wheel, "rotation:y", TAU * turns, time).set_trans(Tween.TRANS_SINE)

# ---------------------------------------------------------------- The Final Silence
func _silence() -> void:
	if not await _line("ending_silence", 1):
		return
	_shot("heir", COUPLING + Vector3(-0.9, 1.5, -1.5), hero.position + Vector3(0, 1.5, 0), 34.0)
	if not await _line("ending_silence", 2):
		return
	_turn_wheel(-1.5, 3.0)
	_shot("racks", Vector3(-1.6, 2.4, -1.0), Vector3(1.5, 4.5, -40.0), 44.0)
	cam.move(Vector3(-1.2, 3.0, -3.0), Vector3(1.0, 6.0, -40.0), 11.0)
	Sfx.play("guard_break", -8.0, 0.4)
	# from the far end toward us: each row, then the Crown
	for i: int in _racks.size():
		var tw := create_tween()
		tw.tween_interval(0.5 + 0.55 * (_racks.size() - 1 - i))
		tw.tween_property(_racks[i], "emission_energy_multiplier", 0.0, 0.7)
	for m: StandardMaterial3D in _crown_mats:
		create_tween().tween_property(m, "emission_energy_multiplier", 0.0, 5.0)
	create_tween().tween_property(_crown_light, "light_energy", 0.0, 5.0)
	create_tween().tween_property(self, "_spin", 0.0, 5.5)
	Sfx.music("", 4.0)
	if _held("crown"):
		return
	if not await _line("ending_silence", 3):
		return
	_shot("witness", hero.position + Vector3(1.1, 1.55, 1.0), hero.position + Vector3(0.1, 1.5, 0), 32.0)
	if not await _line("ending_silence", 4):
		return
	# morning, on the road the three of them walked
	await cards.fade(1.0, 1.2)
	if _over:
		return
	_to_road()
	_shot("road", cam.pos, cam.at, cam.fov)
	await cards.fade(0.0, 2.4)

func _to_road() -> void:
	set_a.queue_free()
	var road := HighRoad.new()
	add_child(road)
	set_b = road
	road.setup(3)
	cam.queue_free()
	cam = road.cam                 # the road follows its own camera (sky, sea and far hills move with it)
	cam.make_current()
	var v := HighRoad.vista()
	hero.position = Highland.road(HighRoad.VISTA_S)
	hero.rotation.y = Highland.road_yaw(HighRoad.VISTA_S)
	hero.ground = Highland.height
	hero.set_armed(false)
	cam.cut(v[0], v[1], v[2])
	cam.move(v[0] + Vector3(0.3, 0.6, -1.4), v[1] + Vector3(0, 2.0, 0), 14.0)
	# first light: the engine's colour is out of the sky
	if road.arena.env != null:
		road.arena.env.ambient_light_energy *= 1.15
	Sfx.ambience("wind")

# ---------------------------------------------------------------- The Last Steward
func _steward() -> void:
	_turn_wheel(0.5, 2.0)
	if not await _w(1.6):
		return
	# the Crown answers: its light comes down the chamber to the one at the coupling
	_shot("crown", Vector3(0.9, 1.0, -3.2), CROWN_AT + Vector3(0, -1.0, 0), 40.0)
	cam.move(Vector3(0.7, 1.2, -5.0), CROWN_AT, 9.0)
	for m: StandardMaterial3D in _crown_mats:
		create_tween().tween_property(m, "emission_energy_multiplier", 9.0, 2.5)
	create_tween().tween_property(_crown_light, "light_energy", 14.0, 2.5)
	for i: int in _racks.size():
		var tw := create_tween()
		tw.tween_interval(0.3 * (_racks.size() - 1 - i))
		tw.tween_property(_racks[i], "emission_energy_multiplier", 4.0, 0.4)
		tw.tween_property(_racks[i], "emission_energy_multiplier", 2.4, 0.8)
	if _held("crown"):
		return
	if not await _line("ending_steward", 1):
		return
	_shot("heir", COUPLING + Vector3(-0.8, 1.45, -1.6), hero.position + Vector3(0, 1.5, 0), 34.0)
	if not await _line("ending_steward", 2):
		return
	_shot("witness", hero.position + Vector3(1.1, 1.55, 1.0), hero.position + Vector3(0.1, 1.5, 0), 32.0)
	if not await _line("ending_steward", 3):
		return
	await cards.fade(1.0, 1.0)
	if _over:
		return
	# the hall above: the heir walks its length to the seat, and the kingdom's lights come on behind them
	set_a.queue_free()
	var hall_arena := Arena.new()
	add_child(hall_arena)
	set_b = hall_arena
	hall_arena.build("throne")
	hall_arena.env.ambient_light_energy = 2.0
	hall_arena.env.tonemap_exposure = 1.3
	var warm := OmniLight3D.new()                 # on the one before the seat: this is their hall now
	warm.light_color = Color("#ffe6c0")
	warm.light_energy = 2.2
	warm.omni_range = 9.0
	warm.position = Vector3(-1.6, 3.0, -4.6)
	hall_arena.add_child(warm)
	var hall := FinalHall.dress(hall_arena)
	hall.run_down(0.01)
	hero.set_armed(true)
	hero.position = Vector3(0, 0, 9.0)
	_shot("hall", Vector3(2.6, 0.8, 12.5), Vector3(0.0, 3.2, -14.0), 44.0)
	cam.move(Vector3(1.8, 1.4, 6.0), Vector3(0.0, 3.6, -14.0), 16.0)
	Sfx.music_for("theme", "menu", 3.0)
	cards.fade(0.0, 1.6)
	var up := walk(hero, Vector3(0, 0, -7.5), FighterRig.ROAD_SPEED)
	if not await _w(1.6):
		return
	hall.set_level(1)              # the pylons wake one after another down the hall
	await up.finished
	if _over:
		return
	face(hero, Vector3(0, 0, 9.0), 1.6)        # before the seat, and turned to the hall: not yet sat in it
	_shot("seat", Vector3(-1.4, 1.1, -3.6), hero.position + Vector3(0, 1.7, 0), 36.0)
	cam.move(Vector3(-1.1, 1.3, -2.6), hero.position + Vector3(0, 1.9, -2.0), 9.0)

# ---------------------------------------------------------------- The Free Cities
func _cities() -> void:
	_turn_wheel(1.0, 2.6)
	if not await _line("ending_cities", 1):
		return
	# the Crown comes apart: three rings, three ways, three colours
	_shot("crown", Vector3(-1.2, 1.2, -3.4), CROWN_AT + Vector3(0, -1.5, 0), 46.0)
	cam.move(Vector3(-0.8, 1.6, -5.4), CROWN_AT + Vector3(0, -0.5, 0), 12.0)
	Sfx.play("guard_break", -8.0, 0.55)
	Sfx.play("levelup", -8.0, 0.6)
	var to := [Vector3(-13.0, 2.5, 3.0), Vector3(0, -1.0, -4.0), Vector3(12.0, 4.0, 5.0)]
	for k: int in _crown_rings.size():
		var ring: Node3D = _crown_rings[k]
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
		tw.tween_property(ring, "position", to[k], 5.5)
		tw.tween_property(ring, "scale", Vector3.ONE * [0.62, 1.15, 1.9][k], 5.5)
		tw.tween_property(ring, "rotation:y", [0.5, 0.0, -0.45][k], 5.5)
		var m: StandardMaterial3D = _crown_mats[k]
		create_tween().tween_property(m, "emission", PARTS[k], 4.0)
	create_tween().tween_property(_crown_light, "light_color", Color("#e8f0ff"), 4.0)
	for i: int in _racks.size():
		var tw2 := create_tween()
		tw2.tween_interval(0.8 + 0.45 * i)
		tw2.tween_property(_racks[i], "emission", PARTS[i % 3], 0.9)
	if _held("crown"):
		return
	if not await _line("ending_cities", 2):
		return
	_shot("witness", hero.position + Vector3(1.1, 1.55, 1.0), hero.position + Vector3(0.1, 1.5, 0), 32.0)
	if not await _line("ending_cities", 3):
		return
	# a door in the chamber wall, and daylight in it, and someone who was only ever a voice
	_doorway()
	# over the heir's shoulder, down the open floor to the door (clear of the racks)
	_shot("door", hero.position + Vector3(1.5, 1.6, -2.4), DOOR_AT + Vector3(0, 1.8, 0), 40.0)
	cam.move(hero.position + Vector3(1.0, 1.6, -1.6), DOOR_AT + Vector3(0, 1.7, 0), 10.0)
	face(hero, DOOR_AT, 1.4)
	create_tween().tween_property(_door_light, "light_energy", 9.0, 3.0)
	Sfx.music_for("theme", "menu", 3.0)

const DOOR_AT := Vector3(-7.6, 0, 1.6)      # in the chamber wall on the near side of the first rack, where it is seen

func _doorway() -> void:
	var to_heir := hero.position - DOOR_AT
	# nothing of the Deep's own (rock, crystal, growth) stands in the doorway or between it and the heir
	for mi: MeshInstance3D in arena.find_children("*", "MeshInstance3D", true, false):
		var at: Vector3 = mi.global_position
		if Vector2(at.x - DOOR_AT.x, at.z - DOOR_AT.z).length() < 4.2 and at.y > -0.5 and at.y < 6.0 and mi.get_aabb().size.y * mi.global_basis.get_scale().y > 0.35:
			mi.visible = false
	var frame := OldMake.portal(arena, DOOR_AT, 2.2, 3.6, FinalHall.lamp(PARTS[0], 1.6))
	frame.rotation.y = atan2(to_heir.x, to_heir.z)
	var day := OldMake.box(frame, Vector3(2.2, 3.6, 0.2), Vector3(0, 1.8, -0.5), Look.glow(Color("#fff2dc"), 5.0))
	day.name = "Daylight"
	_door_light = OmniLight3D.new()
	_door_light.light_color = Color("#fff0d8")
	_door_light.light_energy = 0.0
	_door_light.omni_range = 12.0
	_door_light.position = Vector3(0, 2.0, 1.6)
	frame.add_child(_door_light)
	# the one in the doorway: a figure against the light, standing on her own feet. No face is shown: a shape.
	var fig := CineActor.new()
	frame.add_child(fig)
	fig.build({"scale": 0.94, "bulk": 0.85, "metal": "#0c0d0e", "cloth": "#0c0d0e", "helm": "hood", "weapon": "sword", "eye": "#000000",
		"skin": "res://assets/models/knight_f.glb", "skin_tint": "#101112"}, false)
	fig.set_armed(false)
	fig.position = Vector3(0, 0, 0.3)
	fig.rotation.y = PI
	_figure = fig
