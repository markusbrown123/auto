class_name Prologue
extends Node3D
## Generation I, "The First Oath": the short playable opening. The player's forebear (the Father, or the Mother
## for a woman's lineage) climbs the high road, stands before the Forgotten Monarch, fights the royal guardian
## sent to show them out, reaches for the sealed records, crosses blades with the Monarch himself, and gives up
## the way out to send what they found into the Inheritance Engine.
##
##   beat 1  the road       six designed shots; the recorded narrator over them, then the new narration
##   beat 2  the throne     the exchange with the Monarch; the guardian steps out
##   beat 3  the guardian   a real duel (the game's own), winnable, retried if lost; it teaches cut and guard
##   beat 4  the records    the reach for the seal, and a real clash with the Monarch. The story takes it from the
##                          player while they are doing well: on a cut that lands, once a few have, the hall is
##                          sealed. It is not lost on health and the fight is not rigged.
##   beat 5  the fall       the chamber behind the seal (the Inheritance Engine: the same room the heir wakes in).
##                          The forebear drives the sword into its block to send the records, and dies where the
##                          heir will come to. The sword stays in the block: it is the item the heir takes up.
##
## Both duels are the game's own Duel. For their length Game.profile is the forebear's (so the knight on screen
## and the numbers are theirs) and anything saved goes to a scratch folder, never to a save slot.
## SKIP passes over the beat on show. A later new journey does not play this at all (Opening.SEEN_FILE).

signal finished

const GUARDIAN := "throne_guard"          # who plays the Royal Gatekeeper
const CLASH_MIN := 9.0                    # the clash is the player's for at least this long;
const CLASH_CUTS := 4                     # then the cut that makes this many landed is the one the story answers
const CLASH_TIME := 32.0                  # (or this long, for a player who lands none)
const CLASH_FLOOR := 0.25                 # safety only: the forebear is never let die to an ordinary blow here
## The first of the house: a veteran in the garrison's weathered silver and a practical shield. The sword is not
## in this list: it is the very item the player's knight will carry (see forebear()).
const KIT := ["s_garrison", "a_garrison_helm", "a_garrison_chest", "a_garrison_gauntlets", "a_garrison_legs"]
## What that kit is seen as (appearance only, the numbers stay the garrison's): the plain closed helm and gauntlets
## of the road with the garrison's cuirass and greaves, and a round gatehouse shield. Sleek, and weathered: TINT darkens
## the silver of every piece.
const SEEN_AS := ["a_worn_helm", "a_worn_gauntlets", "s_round"]
const TINT := Color(0.78, 0.8, 0.84)
const SEAL := Vector3(6.2, 0, -8.2)       # where the records are, in the hall
const MONARCH_AT := Vector3(0, 0, -8.6)
## The hall of the first generation: the command hall of the old civilisation, for the scenes and for both duels.
const HALL := "command"

var auto := false                 # dev captures and recordings: a bot fights
var start_beat := 1
var only_shot := 0                # dev: hold on one shot of the road (1-6)
var beat := 0
var road: HighRoad
var hall: Node3D                  # the throne hall and whoever stands in it
var cam: CineCam
var hero: CineActor
var monarch: FighterRig
var guard: FighterRig
var duel: Duel
var cards: CineCards
var clash_result := ""            # how the clash stood when the story cut it: "ahead", "behind" or "even"
var _token := 0
var _over := false
var _clock := 0.0
var _fight_t := 0.0
var _cuts := 0                    # cuts the player has landed in the clash
var _kept := {}                   # what a duel borrows from Game, to give back
var _seal_light: OmniLight3D
var _alarm: OmniLight3D
var _seat: CineSeat               # holds the Monarch seated until he rises
var _placed := {}                 # foe id -> the arena its data names, while a duel here borrows another

func _ready() -> void:
	cards = CineCards.new()
	add_child(cards)
	cards.skip_pressed.connect(skip_beat)
	Highland.warm()
	_begin(clampi(start_beat, 1, 5))

func _exit_tree() -> void:
	_give_back()

## The forebear's body follows the lineage the player chose.
static func body() -> String:
	return str(Game.profile.get("body", "m")) if not Game.profile.is_empty() else "m"

## A profile for the forebear: a seasoned knight in their own kit.
static func forebear() -> Dictionary:
	var p: Dictionary = Game.default_profile()
	p.body = body()
	p.heraldry = str(Game.profile.get("heraldry", "#1f2f4a")) if not Game.profile.is_empty() else "#1f2f4a"
	p.tutorial_done = true
	p.level = 12
	p.attrs = {"health": 14, "strength": 16, "dex": 9, "endurance": 12, "defense": 6, "crit": 2, "resist": 0}
	for slot: String in ["shield", "helm", "chest", "gauntlets", "legs"]:
		p.equipped[slot] = null
	for id: String in KIT:
		if Db.items.has(id):
			if not p.inventory.has(id):
				p.inventory.append(id)
			p.equipped[str(Db.item(id).slot)] = id
	for id: String in SEEN_AS:
		if Db.items.has(id) and p.equipped.get(str(Db.item(id).slot)) != null:
			if not p.inventory.has(id):
				p.inventory.append(id)
			p.cosmetics[str(Db.item(id).slot)] = {"look_as": id}
	# the sword is the heir's own: the same item, with whatever has been done to it (blade tier, mods, edge)
	var sword := inherited_sword()
	if not p.inventory.has(sword):
		p.inventory.append(sword)
	p.equipped.weapon = sword
	if not Game.profile.is_empty():
		for rec: String in ["upgrades", "mods", "edge"]:
			if Game.profile.get(rec, {}).has(sword):
				p[rec][sword] = Game.profile[rec][sword]
	return p

## The item that passes down: what the player's knight has in hand, if it is a one-handed sword a shield goes with.
static func inherited_sword() -> String:
	if not Game.profile.is_empty():
		var id := str(Game.profile.equipped.get("weapon", ""))
		if Db.items.has(id) and str(Db.item(id).get("cls", "")) == "sword":
			return id
	return "w_knight_sword"

## How the forebear looks, by the same code that dresses the player's knight.
static func forebear_look() -> Dictionary:
	var real: Dictionary = Game.profile
	Game.profile = forebear()
	var look: Dictionary = Duel.player_look()
	Game.profile = real
	return look

## Weathers a rig built from that look: the armour's silver gone dull and dark with years of road.
static func weather(rig: FighterRig) -> void:
	if rig != null and rig.parts != null:
		rig.parts.set_param(&"tint", TINT)

# ================================================================ plumbing
func _w(t: float, me: int) -> bool:
	await get_tree().create_timer(t).timeout
	return me == _token and not _over

## Which line of the scene being spoken is on screen (99 when nothing is).
func _now(id: String) -> int:
	if not Story.busy:
		return 99
	var lines: Array = Story.data.scenes[id].lines
	for k in lines.size():
		if str(Story.data.lines[lines[k]].text) == Story._text.text:
			return k
	return -1

func _until(id: String, i: int, me: int) -> bool:
	while me == _token and not _over and Story.busy and _now(id) < i:
		await get_tree().process_frame
	return me == _token and not _over

func _spoken(me: int) -> bool:
	while me == _token and not _over and Story.busy:
		await get_tree().process_frame
	return me == _token and not _over

func _clear() -> void:
	if duel:
		duel.free()
		duel = null
	_give_back()
	if road:
		road.free()
		road = null
	if hall:
		hall.free()
		hall = null
	cam = null
	hero = null
	monarch = null
	guard = null
	_seal_light = null
	_alarm = null

func _begin(b: int) -> void:
	_token += 1
	beat = b
	Story.stop()
	cards.clear()
	cards.veil.color = Color(0.01, 0.01, 0.012, 1.0)
	_clear()
	match b:
		1: _beat_road(_token)
		2: _beat_throne(_token)
		3: _beat_guardian(_token)
		4: _beat_records(_token)
		5: _beat_fall(_token)
		_: _end()

## SKIP: on to the next beat.
func skip_beat() -> void:
	if _over:
		return
	Sfx.play("ui_confirm", -8.0)
	_begin(beat + 1)

## Ends the whole of it now (tests, and the last beat running out).
func skip() -> void:
	_end()

func _end() -> void:
	if _over:
		return
	_over = true
	_token += 1
	Story.stop()
	cards.veil.color = Color(0.01, 0.01, 0.012, 1.0)
	_clear()
	Opening.mark_seen()
	# the hook the generational campaign reads: the first of the house has fallen, and what they sent was received
	if not Game.profile.is_empty():
		Game.profile.flags["gen1_complete"] = true
		Game.profile.flags["gen1_clash"] = clash_result
		Game.profile.flags["inherited_weapon"] = inherited_sword()
	finished.emit()

func _process(delta: float) -> void:
	_clock += delta
	if duel and is_instance_valid(duel):
		_duel_tick(delta)
	if _alarm:
		_alarm.light_energy = 3.0 + 2.5 * sin(_clock * 5.0)

# ================================================================ beat 1: the road
func _beat_road(me: int) -> void:
	road = HighRoad.new()
	add_child(road)
	road.setup(1)
	weather(road.walker(forebear_look()))
	Sfx.music_for("theme", "menu", 2.0)
	if only_shot > 0:
		cards.veil.color.a = 0.0
		road.shot(only_shot)
		return
	road.shot(1)
	cards.fade(0.0, 2.0)
	if not await _w(2.4, me):
		return
	cards.show_card("VAELORA   ·   THE FIRST OATH", 3.4)
	Story.play("opening", true)
	if not await _w(3.0, me):
		return
	road.stride(HighRoad.VISTA_S, HighRoad.VISTA_S + 8.0 * HighRoad.WALK)
	if not await _until("opening", 2, me):
		return
	# one shot to a line or so of the narrator; none held longer than it is worth
	for step: Array in [[2, 3], [3, 4], [4, 5], [5, 99]]:
		road.shot(int(step[0]))
		var hold := float(HighRoad.HOLD[int(step[0])])
		var left := hold
		while left > 0.0 and me == _token and not _over and (left > hold - 5.5 or _now("opening") < int(step[1])):
			await get_tree().process_frame
			left -= get_process_delta_time()
		if me != _token or _over:
			return
	Story.stop()
	road.shot(6)
	Story.play("gen1_open", true)
	if not await _w(float(HighRoad.HOLD[6]), me):
		return
	if not await _spoken(me):
		return
	await cards.fade(1.0, 0.5)
	if me == _token and not _over:
		_begin(2)

# ================================================================ the hall
func _hall(with_guard: bool) -> void:
	hall = Node3D.new()
	add_child(hall)
	var arena := Arena.new()
	hall.add_child(arena)
	arena.build(HALL)
	# the hall at its height: warm, bright, the fires fed (as the old opening lit it)
	arena.env.ambient_light_energy = 2.2
	arena.env.tonemap_exposure = 1.75
	var crown := OmniLight3D.new()
	crown.light_color = Color("#ffd890")
	crown.light_energy = 3.2
	crown.omni_range = 9.0
	crown.position = MONARCH_AT + Vector3(1.2, 3.4, 2.6)
	hall.add_child(crown)
	cam = CineCam.new()
	hall.add_child(cam)
	hero = CineActor.new()
	hall.add_child(hero)
	hero.build(forebear_look(), false)
	weather(hero)
	hero.footsteps = true
	monarch = FighterRig.new()
	hall.add_child(monarch)
	monarch.build(CineActor.foe_look("forgotten_monarch"), true)
	monarch.position = MONARCH_AT
	monarch.rotation.y = PI
	monarch.time_scale = 0.5
	_enthrone(arena)
	if with_guard:
		guard = FighterRig.new()
		hall.add_child(guard)
		guard.build(CineActor.foe_look(GUARDIAN), true)
		guard.position = Vector3(4.6, 0, -5.4)
		guard.rotation.y = PI * 0.5
		guard.time_scale = 0.5
	# the sealed records: a panel in the wall of the hall that is not stone
	var metal := Look.flat(Color("#2a2c2e"), 0.45, 0.85)
	arena.box(Vector3(1.6, 2.8, 0.5), SEAL + Vector3(1.2, 1.4, 0), metal, Vector3(0, -70, 0))
	arena.box(Vector3(0.9, 1.5, 0.52), SEAL + Vector3(1.15, 1.55, 0.02), Look.glow(Color("#5fe0c8"), 1.6), Vector3(0, -70, 0))
	_seal_light = OmniLight3D.new()
	_seal_light.light_color = Color("#5fe0c8")
	_seal_light.light_energy = 0.9
	_seal_light.omni_range = 6.0
	_seal_light.position = SEAL + Vector3(0.2, 1.7, 0.3)
	hall.add_child(_seal_light)
	Sfx.ambience("")

## The Monarch is found seated on the throne the command hall is built round (Arena._layout_command), in the pose
## CineSeat holds him in until he rises.
func _enthrone(_arena: Arena) -> void:
	_seat = CineSeat.make(monarch, 0.6 * monarch.scale.y)

## He stands up out of the throne, and only then walks.
func _rise_and_walk(to: Vector3, speed: float) -> void:
	if _seat == null:
		_walk(monarch, to, speed)
		return
	var who := monarch
	var tw := who.create_tween()
	tw.tween_property(_seat, "amount", 0.0, 1.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _walk(who, to, speed))

## The door of the Engine's room comes down and is barred: slab, dust, the light beyond it cut off, the alarm.
func _seal(arena: Arena, door: Node3D) -> void:
	Sfx.play("shield_scrape", -6.0, 0.5)
	var drop := door.create_tween()
	drop.tween_property(door, "position:y", 1.65, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_callback(func():
		Sfx.play("guard_break", -2.0, 0.55)
		Sfx.play("bell", -8.0, 0.6)
		(arena.get_node("DoorGlow") as OmniLight3D).light_energy = 0.0
		(arena.get_node("Daylight") as Node3D).visible = false
		if _alarm:
			_alarm.visible = true
		# what the slab throws up off the floor
		var dust := CPUParticles3D.new()
		dust.one_shot = true
		dust.explosiveness = 0.92
		dust.amount = 26
		dust.lifetime = 1.6
		dust.mesh = arena._quad(0.7)
		dust.material_override = Look.particle(Color(0.62, 0.6, 0.56, 0.5), false)
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dust.emission_box_extents = Vector3(1.0, 0.05, 0.1)
		dust.direction = Vector3(0, 0.5, 1.0)
		dust.spread = 55.0
		dust.gravity = Vector3(0, -0.6, 0)
		dust.initial_velocity_min = 0.8
		dust.initial_velocity_max = 3.2
		dust.scale_amount_min = 0.5
		dust.scale_amount_max = 1.6
		dust.color_ramp = arena._fade(Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0))
		dust.position = Vector3(0, 0.1, door.position.z + 0.3)
		hall.add_child(dust)
		dust.emitting = true
		# the jolt of it in the camera
		if cam:
			var keep := cam.drift
			cam.drift = 0.2
			cam.create_tween().tween_property(cam, "drift", keep, 0.5)
		# and the bars that run across the slab from either jamb
		for row: Array in [[0.9, -1.0], [2.3, 1.0]]:
			var bar := arena.box(Vector3(1.9, 0.2, 0.16), Vector3(float(row[1]) * 2.6, float(row[0]), door.position.z + 0.2), Look.flat(Color("#1a1c1e"), 0.5, 0.8))
			var lamp := arena.box(Vector3(0.3, 0.07, 0.18), Vector3.ZERO, Look.glow(Color("#ff4a22"), 3.0))
			arena.remove_child(lamp)
			bar.add_child(lamp)
			var run := bar.create_tween()
			run.tween_interval(0.18)
			run.tween_property(bar, "position:x", float(row[1]) * 0.1, 0.32).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			run.tween_callback(func(): Sfx.play("armor", -5.0, 0.6)))

## The sword is in the block: sparks off the stone, the block's light and the room's machines answering it.
func _driven(arena: Arena, rack: Node3D) -> void:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.amount = 22
	sparks.lifetime = 0.7
	sparks.mesh = arena._quad(0.06)
	sparks.material_override = Look.particle(Color(0.6, 1.0, 0.92))
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.gravity = Vector3(0, -6.0, 0)
	sparks.initial_velocity_min = 1.5
	sparks.initial_velocity_max = 4.5
	sparks.position = rack.position + Vector3(0, 0.55, 0)
	hall.add_child(sparks)
	sparks.emitting = true
	if arena.has_meta("machine_light"):
		var m: StandardMaterial3D = arena.get_meta("machine_light")
		var base := m.emission_energy_multiplier
		var tw := create_tween()
		tw.tween_property(m, "emission_energy_multiplier", base * 3.5, 0.35)
		tw.tween_property(m, "emission_energy_multiplier", base * 1.4, 2.4)
	if cam:
		var keep := cam.drift
		cam.drift = 0.12
		cam.create_tween().tween_property(cam, "drift", keep, 0.4)

func _walk(who: FighterRig, to: Vector3, speed: float = HighRoad.WALK) -> Tween:
	var d := to - who.position
	who.rotation.y = atan2(-d.x, -d.z)
	who.walking = true
	var tw := who.create_tween()
	tw.tween_property(who, "position", to, d.length() / speed)
	tw.tween_callback(func(): who.walking = false)
	return tw

func _face(who: Node3D, point: Vector3, time: float) -> void:
	var d := point - who.position
	var yaw := atan2(-d.x, -d.z)
	var from := who.rotation.y
	who.create_tween().tween_property(who, "rotation:y", from + wrapf(yaw - from, -PI, PI), time).set_trans(Tween.TRANS_SINE)

# ---------------------------------------------------------------- beat 2: before the throne
func _beat_throne(me: int) -> void:
	_hall(true)
	Sfx.music_for("boss_forgotten_monarch", "final", 2.5)
	hero.position = Vector3(0, 0, 13.5)
	_walk(hero, Vector3(0, 0, 1.6))
	# down the length of the hall behind the one who has come to ask
	cam.cut(Vector3(1.4, 2.3, 18.0), Vector3(0, 3.2, -14.0), 44.0)
	cam.move(Vector3(1.0, 1.9, 8.5), Vector3(0, 3.4, -14.0), 8.6)
	cards.fade(0.0, 1.0)
	if not await _w(8.4, me):
		return
	Story.play("gen1_throne", true)
	for i in 4:
		if not await _until("gen1_throne", i, me):
			return
		if i % 2 == 0:
			# the forebear, from the Monarch's side
			cam.cut(Vector3(-1.5, 1.55, -1.6), Vector3(0.1, 1.5, 1.6), 36.0)
			cam.move(Vector3(-1.3, 1.55, -1.3), Vector3(0.1, 1.5, 1.6), 5.0)
		else:
			# the Monarch, from below
			cam.cut(Vector3(2.0, 0.7, -4.6), MONARCH_AT + Vector3(0, 1.55, 0), 40.0)
			cam.move(Vector3(1.6, 0.8, -5.2), MONARCH_AT + Vector3(0, 1.65, 0), 6.0)
	if not await _spoken(me):
		return
	# "Show the warden out": the guardian leaves the wall, and turns
	Story.play("gen1_guard", true)
	guard.time_scale = 1.0
	cam.cut(Vector3(2.2, 0.4, -0.6), Vector3(3.2, 1.9, -4.6), 40.0)
	cam.move(Vector3(1.6, 0.45, 0.2), Vector3(0.3, 2.0, -1.8), 4.2)
	await _walk(guard, Vector3(0.3, 0, -1.7), 1.1).finished
	if me != _token or _over:
		return
	Sfx.play("armor", -4.0, 0.7)
	_face(guard, hero.position, 1.1)
	if not await _w(1.6, me):
		return
	await cards.fade(1.0, 0.35)
	if me == _token and not _over:
		_begin(3)

# ================================================================ the duels
## Puts the forebear in the player's place for a duel, and remembers what to give back.
func _borrow() -> void:
	if not _kept.is_empty():
		return
	_kept = {"profile": Game.profile, "dir": Game.save_dir_override, "run": Game.run}
	var mine := forebear()
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_prologue"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	Game.profile = mine

## Gives Game back what a duel borrowed. Safe to call twice.
func _give_back() -> void:
	for id: String in _placed:
		if _placed[id] == null:
			Db.foes[id].erase("arena")
		else:
			Db.foes[id]["arena"] = _placed[id]
	_placed = {}
	if _kept.is_empty():
		return
	Game.profile = _kept.profile
	Game.save_dir_override = _kept.dir
	Game.run = _kept.run
	_kept = {}

func _fight(foe_id: String, opts: Dictionary) -> void:
	_borrow()
	# the duel is fought where the scene was played: the first generation's hall, not the ruin it becomes
	if not _placed.has(foe_id):
		_placed[foe_id] = Db.foes[foe_id].get("arena")
	Db.foes[foe_id]["arena"] = HALL
	duel = Duel.new()
	add_child(duel)
	if auto:
		opts["autoplay"] = true
		opts["bot_style"] = DuelBot.Style.SKILLED
	opts["skip_intro"] = true
	duel.setup(foe_id, opts)
	# the duel's own pause button (it did nothing here): Resume, or Yield, which passes over this beat as SKIP does
	var paused_duel := duel
	duel.hud.pause_pressed.connect(func():
		if is_instance_valid(paused_duel) and paused_duel.stage == Duel.Stage.FIGHT:
			Overlays.pause(paused_duel, func(): pass, skip_beat))
	weather(duel.player_rig)
	_fight_t = 0.0
	_cuts = 0
	duel.sim.ev.connect(_on_duel_ev)

## One line of instruction, in the fight's own terms, as the moment for it comes.
func _duel_tick(delta: float) -> void:
	if duel.stage != Duel.Stage.FIGHT:
		cards.say("", delta)
		return
	_fight_t += delta
	var sim := duel.sim
	if beat == 3:
		if sim.b_state == DuelSim.B.WINDUP:
			cards.say("HOLD YOUR SHIELD UP  ·  OR SWIPE INTO THE BLOW TO TURN IT", delta)
		elif sim.b_state == DuelSim.B.RECOVER or sim.b_state == DuelSim.B.STAGGER:
			cards.say("HE IS OPEN  ·  SWIPE ACROSS HIM TO CUT", delta)
		else:
			cards.say("", delta)
		return
	cards.say("", delta)
	# the clash with the Monarch: a player who lands nothing is not kept there for ever, nor let die to a stray blow
	if _fight_t >= CLASH_TIME or float(sim.pl.hp) / maxf(float(sim.pl.max_hp), 1.0) <= CLASH_FLOOR:
		_take_clash("even" if _cuts > 0 else "behind")

## The story's blow comes on the player's own: the cut that lands, once enough have. Doing well is what triggers it.
func _on_duel_ev(n: StringName, _e: Dictionary) -> void:
	if beat != 4 or duel == null or n != &"boss_hit":
		return
	_cuts += 1
	if _cuts >= CLASH_CUTS and _fight_t >= CLASH_MIN:
		_take_clash("ahead")

func _take_clash(how: String) -> void:
	if duel == null:
		return
	clash_result = how
	duel.sim.paused = true
	var d := duel
	duel = null
	_sealed(d, _token)

# ---------------------------------------------------------------- beat 3: the royal guardian
func _beat_guardian(me: int) -> void:
	_fight(GUARDIAN, {"seed": 5})
	duel.finished.connect(func(won: bool, _sim: DuelSim): _guardian_done(won, me))
	cards.fade(0.0, 0.7)

func _guardian_done(won: bool, me: int) -> void:
	if me != _token or _over:
		return
	await cards.fade(1.0, 0.5)
	if me != _token or _over:
		return
	# an ordinary defeat is an ordinary defeat: the fight is taken again, and the family's story does not move
	_begin(4 if won else 3)

# ---------------------------------------------------------------- beat 4: the records, and the Monarch
func _beat_records(me: int) -> void:
	_hall(false)
	Sfx.music_for("boss_forgotten_monarch", "final", 1.0)
	hero.position = Vector3(0.4, 0, 0.6)
	cam.cut(Vector3(-2.6, 1.5, 3.0), SEAL + Vector3(0, 1.5, 0), 42.0)
	cam.move(Vector3(-1.2, 1.5, 0.4), SEAL + Vector3(0, 1.5, 0), 5.0)
	_walk(hero, SEAL + Vector3(-2.6, 0, 1.8))
	create_tween().tween_property(_seal_light, "light_energy", 2.6, 3.0)
	cards.fade(0.0, 0.7)
	Story.play("gen1_records", true)
	if not await _until("gen1_records", 1, me):
		return
	# he comes down from the throne himself
	monarch.time_scale = 1.0
	cam.cut(Vector3(3.6, 0.5, -3.4), MONARCH_AT + Vector3(0, 2.0, 0), 38.0)
	cam.move(Vector3(3.9, 0.6, -2.6), Vector3(1.6, 2.0, -5.6), 4.0)
	_rise_and_walk(Vector3(2.4, 0, -5.2), 1.0)
	_face(hero, MONARCH_AT, 0.8)
	if not await _spoken(me):
		return
	if not await _w(0.5, me):
		return
	await cards.fade(1.0, 0.35)
	if me != _token or _over:
		return
	if hall:
		hall.free()
		hall = null
	_fight("forgotten_monarch", {"seed": 9})
	duel.finished.connect(func(won: bool, _sim: DuelSim):
		# the duel ran to its own end before the story reached its threshold (rare): a win is answered as "ahead",
		# a death is an ordinary defeat and the clash is taken again
		if me != _token or _over:
			return
		if won:
			clash_result = "ahead"
			_begin(5)
		else:
			_begin(4))
	cards.fade(0.0, 0.7)

## The story takes the clash: the Monarch does not finish it. He seals the hall.
func _sealed(d: Duel, me: int) -> void:
	Sfx.play("guard_break", -3.0, 0.6)
	Sfx.play("bell", -6.0, 0.7)
	await cards.fade(1.0, 0.45)
	if is_instance_valid(d):
		d.free()
	_give_back()
	if me != _token or _over:
		return
	_begin(5)

# ---------------------------------------------------------------- beat 5: the fall
## Behind the seal: the Inheritance Engine. This is the `chamber` set, the room the heir wakes in (Awakening),
## and everything is left as that scene finds it: the sword in its block, and the place by the cradle.
func _beat_fall(me: int) -> void:
	hall = Node3D.new()
	add_child(hall)
	var arena := Arena.new()
	hall.add_child(arena)
	arena.build("chamber")
	arena.env.ambient_light_energy = 1.3
	var rack: Node3D = arena.get_node("Rack")
	(arena.get_node("Lyra") as OmniLight3D).light_energy = 0.6
	cam = CineCam.new()
	hall.add_child(cam)
	hero = CineActor.new()
	hall.add_child(hero)
	hero.build(forebear_look(), false)
	weather(hero)
	hero.footsteps = true
	# (the Monarch is not in the room: the door has come down between them, and he speaks through it)
	var key := SpotLight3D.new()
	key.light_color = Color("#ffd9a0")
	key.light_energy = 4.0
	key.spot_range = 10.0
	key.spot_angle = 42.0
	key.position = Vector3(0.6, 5.0, 3.4)
	hall.add_child(key)
	key.look_at(Vector3(1.4, 0.6, 0.2))
	_alarm = OmniLight3D.new()
	_alarm.light_color = Color("#ff4a22")
	_alarm.omni_range = 14.0
	_alarm.position = Vector3(0, 3.2, -5.0)
	hall.add_child(_alarm)
	_seal_light = OmniLight3D.new()
	_seal_light.light_color = Color("#5fe0c8")
	_seal_light.light_energy = 0.4
	_seal_light.omni_range = 7.0
	_seal_light.position = rack.position + Vector3(-0.5, 1.5, 0.6)
	hall.add_child(_seal_light)
	Sfx.ambience("crypt")
	Sfx.music("", 2.5)
	# the sealing, seen from inside: they come through the doorway with the hall's light behind them, and the slab
	# comes down at their heels, the bars run across it, and the only light left is the room's own
	hero.position = Vector3(0.15, 0, -5.6)
	var at_block: Vector3 = rack.position + Vector3(-0.75, 0, 0.6)
	var door: Node3D = arena.get_node("Door")
	door.position.y = 5.2
	_alarm.visible = false
	var beyond := arena.get_node("DoorGlow") as OmniLight3D
	beyond.light_color = Color("#ffc27a")
	beyond.light_energy = 3.2
	(arena.get_node("Daylight") as MeshInstance3D).material_override = Look.glow(Color("#ffb060"), 2.4)
	cam.cut(Vector3(-2.3, 1.05, -1.5), Vector3(0.3, 1.55, -6.2), 46.0)
	cam.move(Vector3(-2.6, 0.95, -0.9), Vector3(0.4, 1.45, -6.2), 3.2)
	cards.fade(0.0, 0.5)
	_walk(hero, Vector3(0.5, 0, -3.3), 1.5)
	if not await _w(1.35, me):
		return
	_seal(arena, door)
	if not await _w(1.7, me):
		return
	cam.cut(Vector3(4.9, 1.5, 2.4), rack.position + Vector3(-0.6, 1.1, 0.0), 44.0)
	cam.move(Vector3(4.5, 1.4, 1.6), rack.position + Vector3(-0.4, 1.1, 0.2), 6.0)
	await _walk(hero, at_block, 1.05).finished
	if me != _token or _over:
		return
	_face(hero, rack.position, 0.5)
	if not await _w(0.7, me):
		return
	# the sword leaves the hand: raised in both, and driven down into the block (the two-handed downward cut, at half
	# speed so that it is a deed and not a blow), seen from below the block's edge
	cam.cut(rack.position + Vector3(1.7, 0.5, 2.0), rack.position + Vector3(-0.35, 1.2, 0.15), 42.0)
	cam.move(rack.position + Vector3(1.35, 0.55, 1.7), rack.position + Vector3(-0.25, 1.0, 0.1), 2.4)
	var strike := "th_cut_d"
	if SkinDriver.has_clip(strike):
		hero.time_scale = 0.5
		hero.hold(strike, 0.2)
		if not await _w(1.0, me):
			return
		hero.time_scale = 1.0
	# the sword goes into the block, and stays there: what was found goes out through it
	_driven(arena, rack)
	hero.release(0.9)
	# the very blade from the hand (gear model or kit model, with whatever was done to it), point down in the block
	var blade: Node3D = hero.weapon_r.duplicate()
	rack.add_child(blade)
	blade.visible = true
	hero.set_armed(false)
	var length: float = maxf(hero.weapon_len, 0.6)
	blade.transform = Transform3D.IDENTITY
	blade.rotation = Vector3(PI, 0.4, 0.06)
	blade.position = Vector3(0, 0.42 + length * 0.86, 0)
	Sfx.play("swing", -6.0, 0.7)
	Sfx.play("levelup", -8.0, 0.5)
	var flare := create_tween()
	flare.tween_property(_seal_light, "light_energy", 14.0, 0.5)
	flare.tween_property(_seal_light, "light_energy", 3.5, 2.5)
	if not await _w(1.6, me):
		return
	# and then the few steps to the foot of the cradle, which is as far as there is
	Story.play("gen1_seal", true)
	await _walk(hero, Awakening.SEAT, 0.8).finished
	if me != _token or _over:
		return
	hero.create_tween().tween_property(hero, "rotation:y", PI, 1.2)
	hero.hold("wounded", 2.4)
	cam.cut(Vector3(-1.1, 1.2, 4.5), Vector3(0.3, 1.0, -2.0), 44.0)
	cam.move(Vector3(-0.8, 1.0, 4.3), Vector3(0.4, 0.9, -2.0), 9.0)
	if not await _until("gen1_seal", 2, me):
		return
	# the last word is the forebear's: low and close, where the heir will be found
	cam.cut(Vector3(0.75, 0.42, 3.45), Vector3(0.0, 0.72, 1.7), 40.0)
	cam.move(Vector3(0.95, 0.5, 3.75), Vector3(0.0, 0.78, 1.7), 7.0)
	if not await _spoken(me):
		return
	create_tween().tween_property(key, "light_energy", 0.0, 2.2)
	if not await _w(1.4, me):
		return
	await cards.fade(1.0, 1.4)
	if me != _token or _over:
		return
	_alarm = null
	# the family's mark, and what was written of them
	cards.show_item(cards.emblem, 6.0, 1.6)
	Story.play("gen1_close_" + body(), true)
	if not await _spoken(me):
		return
	if not await _w(1.4, me):
		return
	_end()
