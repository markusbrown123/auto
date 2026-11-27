extends Node
## The campaign fix pass (docs/BUG_REGISTER.md, "Campaign fix pass"): each defect closed there, held fixed.
##   godot --headless --path . res://tests/fix_pass.tscn
## Also run at the end of tests/integration.gd (so tools/test.sh covers it).
var failed := 0
var embedded := false

func ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		failed += 1

func frames(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	if embedded:
		return
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_fixpass"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	for n in range(1, Game.SLOT_COUNT + 1):
		Game.delete_slot(n)
	Engine.time_scale = 6.0
	await run()
	print("\nfix pass: %s" % ("PASS" if failed == 0 else "%d FAILED" % failed))
	get_tree().quit(1 if failed > 0 else 0)

func run() -> void:
	print("• campaign fix pass")
	Game.new_game()
	Game.profile.tutorial_done = true
	await _slice_look()
	await _slice_road()
	await _slice_save()
	await _slice_camera()
	Story.stop()
	Game.run = {}

func fixture(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/%s.json" % name))

# ---------------------------------------------------------------- the Throne Guard, the shrine
func _slice_look() -> void:
	var look := CineActor.foe_look("throne_guard")
	ok(look.get("parts") is Dictionary and str(look.get("skin", "")) == ArmorParts.host_path("m") and not look.has("skin_tint"),
		"Throne Guard: its look names armour pieces on the base body, not the class's one-piece model")
	var g := FighterRig.new()
	add_child(g)
	g.build(look, true)
	ok(g.parts != null and str(g.parts.worn.get("helm", "")) == "regal" and str(g.parts.worn.get("chest", "")) == "regal" and g.parts.is_clean(),
		"Throne Guard: dressed from the modular parts (court helm and cuirass), no kettle helm")
	ok(str(g.cfg.get("helm", "")) != "kettle" and g.skin != null and not g.pelvis.visible, "Throne Guard: the primitive body and its helm are not drawn")
	g.queue_free()
	var gate: Dictionary = Encounters.foe("royal_gatekeeper")
	ok(gate.rig.get("parts") is Dictionary, "Royal Gatekeeper (Generation I) is the same dressed guardian")
	await frames()

# ---------------------------------------------------------------- the road
func _slice_road() -> void:
	# stop 5: with two ways onward the left one's foe stood on the line from the lens through the knight
	var cam := Explore.CAM_POS
	var knight_deg := rad_to_deg(atan2(-cam.x, cam.z))
	var worst := 999.0
	for n: int in [1, 2, 3]:
		for i: int in n:
			var x := Explore.clear_x((float(i) - (n - 1) * 0.5) * 3.2 - 0.3)
			var foe_deg := rad_to_deg(atan2(x - cam.x, cam.z + 4.6 + Explore.FOE_BEYOND))
			worst = minf(worst, absf(foe_deg - knight_deg))
	ok(worst >= Explore.CLEAR_DEG - 0.01, "road: no foe waits behind the knight's back, with one, two or three ways onward (nearest %.1f degrees)" % worst)
	ok(absf(Explore.clear_x(-0.3) + 0.3) < 0.3 and is_equal_approx(Explore.clear_x(2.9), 2.9) and Explore.clear_x(-1.9) < -1.9, "road: only the one that was hidden is moved, and outward")
	Game.start_run("courtyard")
	Game.run.stage = 4
	for id: String in ["courtyard_4", "w_courtyard_passage", Companion.discovery_id()]:
		Companion.mark_heard(id)
	var e := Explore.new()
	add_child(e)
	await get_tree().create_timer(1.0).timeout
	var hid := false
	for f in e.foes:
		if f != null:
			var p: Vector3 = (f as Node3D).position.rotated(Vector3.UP, -e.angle)
			hid = hid or absf(rad_to_deg(atan2(p.x - cam.x, cam.z - p.z)) - knight_deg) < Explore.CLEAR_DEG - 0.01
	ok(e.foes.size() == 2 and e.foes[0] != null and not hid, "road: at the gate passage the Rampart Breaker stands clear of the knight")
	e.queue_free()
	await frames()
	# stop 6: the shrine is a built monument
	Game.run.stage = 5
	Companion.mark_heard("courtyard_5")
	Companion.mark_heard("w_courtyard_candle")
	var e2 := Explore.new()
	add_child(e2)
	await frames(3)
	var shrine: Node3D = e2._shrine(Vector3(1, 0, -2))
	var kinds := {}
	for mi: MeshInstance3D in shrine.find_children("*", "MeshInstance3D", true, false):
		kinds[mi.mesh.get_class()] = int(kinds.get(mi.mesh.get_class(), 0)) + 1
	ok(shrine.get_child_count() >= 18 and kinds.has("TorusMesh") and int(kinds.get("CylinderMesh", 0)) >= 8 and int(kinds.get("BoxMesh", 0)) <= 1,
		"shrine: a stepped stele with the ring in its head, turned from stone (%d pieces, not a box)" % shrine.get_child_count())
	e2.queue_free()
	await frames()
	# stops 3 to 7: the ways onward come up under a companion's remark, and choosing ends it without spending it
	Game.new_game()
	Game.profile.tutorial_done = true
	Companion.mark_heard(Companion.discovery_id())
	Companion.reset_cooldown()
	Game.start_run("courtyard")
	Game.run.stage = 3
	var e3 := Explore.new()
	add_child(e3)
	var t := 0.0
	while t < 12.0 and not (e3._shown() and Story.busy):
		await get_tree().process_frame
		t += get_process_delta_time()
	ok(e3._shown() and Story.busy and e3._aside and t < 6.0, "road: the choices are up %.1f s after arriving, while the remark is still being made" % t)
	ok(Story._catcher.mouse_filter == Control.MOUSE_FILTER_IGNORE and Story._box.offset_bottom < -200.0, "road: the remark takes no touches and sits above the cards")
	var said: String = Companion.scene_for("courtyard_3")
	ok(not Companion.heard(said), "road: a remark still being made is not yet counted as heard")
	e3._choose(Game.stage_options()[0], 0)
	await frames(3)
	ok(not Story.busy and not Companion.heard(said), "road: choosing a way ends the remark, and it will be said another time")
	e3.queue_free()
	await frames()
	Story.play("orren_intro", true)
	ok(Story._box.offset_bottom == Story.BOX_BOTTOM and Story._shade.visible, "an ordinary line is back at the foot of the screen")
	Story.stop()
	# heard to the end, it is heard
	Game.run.stage = 3
	Companion.reset_cooldown()
	var e4 := Explore.new()
	add_child(e4)
	t = 0.0
	while t < 40.0 and not (Companion.heard(said) and not e4._aside):
		await get_tree().process_frame
		t += get_process_delta_time()
	ok(Companion.heard(said) and not e4._aside, "road: a remark heard to its end is not repeated")
	e4.queue_free()
	await frames()
	# the Witness's first scene: not one held shot
	Game.new_game()
	Game.profile.tutorial_done = true
	Game.start_run("courtyard")
	Game.run.stage = 1
	var ew := Explore.new()
	add_child(ew)
	t = 0.0
	while t < 90.0 and not (ew.witness_shots.size() > 1 and not ew._staging):
		await get_tree().process_frame
		t += get_process_delta_time()
	var distinct := {}
	for sname: String in ew.witness_shots:
		distinct[sname] = true
	ok(distinct.size() >= 4 and ew.witness_shots.size() >= 6, "the Witness's first scene cuts between %d set-ups (%d cuts: %s)" % [distinct.size(), ew.witness_shots.size() - 1, str(ew.witness_shots)])
	ew.queue_free()
	Story.stop()
	await frames()

# ---------------------------------------------------------------- pouches, the road in the save
func _slice_save() -> void:
	Game.new_game()
	Game.profile.tutorial_done = true
	Companion.mark_heard(Companion.discovery_id())
	Game.start_run("courtyard")
	var e := Explore.new()
	add_child(e)
	await frames(3)
	var n: int = e.pouches.size()
	var where: Vector3 = e.pouches[0][0].position if n > 0 else Vector3.ZERO
	var gold: int = Game.profile.gold
	if n > 0:
		e.pouches[0][1].pressed.emit()
	ok(n >= 1 and Game.profile.gold > gold and Game.pouch_taken(0), "pouch: found once and paid")
	var after: int = Game.profile.gold
	ok(Game.take_pouch(0) == 0 and Game.profile.gold == after, "pouch: the same one pays nothing a second time")
	e.queue_free()
	await frames()
	# a defeat, and the same road again: it is not back
	Game.on_death()
	Game.start_run("courtyard")
	var e2 := Explore.new()
	add_child(e2)
	await frames(3)
	ok(e2.pouches.size() == n - 1, "pouch (O7): after a defeat the pouch already taken has not come back (%d here, %d before)" % [e2.pouches.size(), n])
	e2.queue_free()
	await frames()
	# where they lie does not depend on how often the knight has died
	Game.profile.pouches = {}
	Game.start_run("courtyard")
	var e3 := Explore.new()
	add_child(e3)
	await frames(3)
	ok(e3.pouches.size() == n and e3.pouches[0][0].position.is_equal_approx(where), "pouch (O7): it lies where it lay before the defeat (the seed has no death count in it)")
	e3.queue_free()
	await frames()
	# O5: the road is saved at every stop, and Continue takes it up there
	Game.new_game()
	Game.profile.tutorial_done = true
	Companion.mark_heard(Companion.discovery_id())
	ok(Game.SAVE_VERSION == 4 and Game.profile.road == {} and Game.profile.pouches == {}, "save version 4: a new journey has no road in progress and no pouches taken")
	Game.start_run("courtyard")
	Game.run.stage = 2
	Game.run.hp = 61.0
	var e4 := Explore.new()
	add_child(e4)
	await frames(3)
	e4.queue_free()
	await frames()
	var gold4: int = Game.profile.gold
	Game.run = {}                      # the app is ended: nothing in memory survives
	ok(Game.load_game() and Game.run.is_empty() and str(Game.profile.road.get("region", "")) == "courtyard" and int(Game.profile.road.stage) == 2,
		"road (O5): the stop reached is in the save")
	ok(Game.resume_road() and str(Game.run.region) == "courtyard" and Game.run.stage == 2 and typeof(Game.run.stage) == TYPE_INT and is_equal_approx(float(Game.run.hp), 61.0) and Game.profile.gold == gold4,
		"road (O5): Continue stands the knight at that stop with the health they had, and gives nothing")
	# through the real router
	var m: Node = load("res://src/main.tscn").instantiate()
	add_child(m)
	await frames()
	Game.run = {}
	Game.load_game()
	m.resume()
	await get_tree().create_timer(2.5).timeout
	ok((m.current is Explore or m.current is CineRoad) and not Game.run.is_empty() and int(Game.run.stage) == 2, "road (O5): the router's Continue opens the road at stop 3, not the sanctuary")
	# a defeat ends the road: Continue is the sanctuary again
	Game.on_death()
	Game.load_game()
	ok(Game.profile.road == {} and not Game.resume_road(), "road: a defeat ends the road in the save too (the route resets, as it always has)")
	Game.start_run("courtyard")
	Game.save()
	Game.run = {}
	Game.save()
	Game.load_game()
	ok(not Game.resume_road(), "road: turning back leaves no road to resume")
	m.queue_free()
	await frames()
	# migration: a version-3 save has neither key; it gains both, empty, and loses nothing
	var v3 := fixture("save_v3")
	var m3 := Game._migrate(fixture("save_v3"))
	ok(int(v3.version) == 3 and not v3.has("road") and int(m3.version) == 4 and m3.road == {} and m3.pouches == {} and int(m3.gold) == int(v3.gold) and m3.inventory.size() > 0,
		"save_v3: brought to version 4 with no road and no pouches taken, nothing else changed")
	var v4 := fixture("save_v4")
	var m4 := Game._migrate(fixture("save_v4"))
	ok(int(v4.version) == 4 and str(m4.road.region) == "courtyard" and typeof(m4.road.stage) == TYPE_INT and int(m4.road.stage) == 4 and m4.pouches.size() >= 1,
		"save_v4 (fixture): a road in progress and its taken pouches are read back whole")
	var key: String = m4.pouches.keys()[0]
	ok(typeof(m4.pouches[key][0]) == TYPE_INT, "save_v4: pouch indexes are whole numbers again after JSON")
	var keep: Dictionary = Game.profile
	Game.profile = m4
	Game.run = {}
	ok(Game.resume_road() and Game.run.stage == 4 and Game.pouch_taken(0) and not Game.pouch_taken(1), "save_v4: resumed at the gate passage, its first pouch already taken")
	Game.run = {}
	m4.road = {"region": "nowhere", "stage": 2}
	ok(not Game.resume_road(), "a road the data does not know is not resumed")
	m4.road = {"region": "courtyard", "stage": 70}
	ok(not Game.resume_road() and Game._migrate(m4).road == {}, "nor a stop the road does not have")
	Game.profile = keep
	Game.run = {}

# ---------------------------------------------------------------- the duel camera
func _slice_camera() -> void:
	Game.new_game()
	Game.profile.tutorial_done = true
	var d := Duel.new()
	add_child(d)
	d.setup("ashen_sentinel", {"skip_intro": true, "seed": 3})
	await frames(4)
	var dir: CamDirector = d.director
	dir._context()
	# the phase shot keeps the knight in front of the lens
	var s: Dictionary = dir._shot_phase()
	var to_k: Vector3 = dir._K + Vector3(0, 1, 0) - s.pos
	var fwd: Vector3 = (s.look - s.pos).normalized()
	var off := rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(to_k.x, to_k.z)))
	ok(to_k.dot(fwd) > 0.5 and absf(off) < 38.0, "Sentinel: at a phase change the knight is in front of the camera and in the frame (%.0f degrees off its aim)" % absf(off))
	# after the fall: close, and it stays close however long they talk
	d.stage = Duel.Stage.DONE
	dir._ended = "win"
	dir.shot = "victory"
	dir.shot_t = 40.0
	var v: Dictionary = dir._shot_victory()
	ok((v.pos as Vector3).distance_to(dir._K) < 3.6, "after the Sentinel falls the camera stays within %.1f m of the knight, 40 s on (it used to climb away)" % (v.pos as Vector3).distance_to(dir._K))
	var seen := {}
	Story.busy = true
	for who: String in ["sentinel", "player", "archivist", "lyra", "witness", ""]:
		Story.speaker = who
		dir.shot_t = 5.0
		var name := dir._choose()
		dir.shot = name
		seen[name] = true
		var sh: Dictionary = dir.call("_shot_" + name)
		ok((sh.pos as Vector3).distance_to(dir._K) < 5.0 and float(sh.fov) <= 50.0, "after the fall, %s speaking: shot '%s', %.1f m from the knight" % [who if who != "" else "nobody", name, (sh.pos as Vector3).distance_to(dir._K)])
	Story.busy = false
	Story.speaker = ""
	ok(seen.size() >= 4, "after the fall the camera cuts between %d set-ups" % seen.size())
	dir.shot = "victory_fallen"
	dir.shot_t = 0.2
	Story.busy = true
	Story.speaker = "player"
	ok(dir._choose() == "victory_fallen", "no cut is shorter than %.1f s" % CamDirector.AFTER_MIN)
	Story.busy = false
	Story.speaker = ""
	ok(Duel.FINISH_HOLD < 3.0, "the pause between the blow and the first of the last words is shorter")
	d.queue_free()
	await frames()
