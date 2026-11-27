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
	_voices()
	await _campaign()
	await _scenes()
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
	ok(Game.SAVE_VERSION == 5 and Game.profile.road == {} and Game.profile.pouches == {}, "save version 5: a new journey has no road in progress and no pouches taken")
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
	ok(int(v3.version) == 3 and not v3.has("road") and int(m3.version) == 5 and m3.road == {} and m3.pouches == {} and int(m3.gold) == int(v3.gold) and m3.inventory.size() > 0,
		"save_v3: brought to version 5 with no road and no pouches taken, nothing else changed")
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

# ---------------------------------------------------------------- which take a line plays
func _voices() -> void:
	Game.new_game("#3d0f0f", "f")
	var kept_line := ""
	var heir_line := ""
	var shared := ""
	for id: String in Story.data.lines:
		var l: Dictionary = Story.data.lines[id]
		if bool(l.get("by_body", false)) and kept_line == "":
			kept_line = id
		if str(l.get("cast", "")) == "heir" and heir_line == "":
			heir_line = id
		if str(l.speaker) == "lyra" and shared == "" and ResourceLoader.exists(Story.VO + id + ".ogg"):
			shared = id
	ok(kept_line != "" and Story.audio_path(kept_line).ends_with("_f.ogg") and ResourceLoader.exists(Story.audio_path(kept_line)), "voices: in a woman's lineage the Kept speaks with her take (%s)" % Story.audio_path(kept_line).get_file())
	Game.profile.body = "m"
	ok(Story.audio_path(kept_line).ends_with("_m.ogg"), "voices: and in a man's with his")
	Game.profile.body = "x"
	ok(Story.audio_path(kept_line) == Story.VO + kept_line + ".ogg", "voices: a by_body line with no take for the body falls back to the plain file")
	Game.profile.body = "f"
	ok(heir_line != "" and Story.audio_path(heir_line).ends_with("_f.ogg") and ResourceLoader.exists(Story.audio_path(heir_line)), "voices: the heir's own lines resolve by body (%s)" % Story.audio_path(heir_line).get_file())
	var fore := ""
	for id: String in Story.data.lines:
		if str(Story.data.lines[id].get("cast", "")) == "forebear" and fore == "":
			fore = id
	ok(fore != "" and Story.audio_path(fore).ends_with("_f.ogg") and ResourceLoader.exists(Story.audio_path(fore)), "voices: and the forebear's (%s)" % Story.audio_path(fore).get_file())
	# the third generation looks for its own take first, and plays the shared one until there is one
	ok(Game.generation() == 2 and Story.take_candidates(shared) == [Story.VO + shared + ".ogg"], "voices: before the third generation a shared line has one place to be")
	Game.profile.campaign.generation = 3
	var c: Array = Story.take_candidates(shared)
	ok(Game.generation() == 3 and c[0] == Story.VO + shared + "_g3.ogg" and Story.audio_path(shared) == Story.VO + shared + ".ogg", "voices: the last heir's generation asks for <line>_g3 first and falls back to the shared take")
	var cp: Array = Story.take_candidates(heir_line)
	ok(cp[0].ends_with("_g3_f.ogg") and cp[1].ends_with("_g3.ogg") and cp[2].ends_with("_f.ogg"), "voices: for the knight's lines, <line>_g3_<body>, then <line>_g3, then the shared take")
	Game.new_game()

# ---------------------------------------------------------------- Generation III: the choice, the Kept, the late roads
func _heir() -> void:
	Game.new_game()
	Game.profile.tutorial_done = true
	Game.fall(2, "saved_the_records", {"choice": "records"})
	Game.inherit({"name": "Test", "body": "m"})

func _campaign() -> void:
	_heir()
	ok(Game.generation() == 3 and Generations.canon_open(Game.profile), "(the last heir, the story open)")
	# the ending choice cannot be skipped from the sanctuary
	Game.profile.cleared = ["courtyard", "blackwood", "cathedral", "throne"]
	Game.add_fact("monarch_felled:3")
	ok(Game.road_complete() and not Game.game_complete(), "the Monarch felled and \"Not yet\" answered: the road is done, the story is not, and nothing offers the next cycle")
	var before := JSON.stringify([Game.profile.ng, Game.profile.cleared, Game.profile.campaign])
	ok(not Game.start_ng_plus() and not Game.start_legacy_journey() and JSON.stringify([Game.profile.ng, Game.profile.cleared, Game.profile.campaign]) == before,
		"asking for the next cycle with no ending chosen is refused and changes nothing")
	var s := Sanctuary.new()
	add_child(s)
	await frames(2)
	s.show_tab("Journey")
	await frames(2)
	var again := false
	for b: Button in s.find_children("*", "Button", true, false):
		again = again or b.text.begins_with("Return Again")
	ok(not again, "the sanctuary's Journey tab has no \"Return Again\" while the Crown is undecided")
	s.queue_free()
	await frames()
	Game.choose_ending("steward")
	ok(Game.game_complete() and Game.start_legacy_journey() and Game.on_legacy_journey(), "once an ending is chosen the legacy journey is offered and begins")
	# a second-generation knight who beats the Monarch cannot skip the third generation either
	Game.new_game()
	Game.profile.cleared = ["courtyard", "blackwood", "cathedral", "crypt", "citadel", "throne"]
	ok(Game.road_complete() and not Game.game_complete() and not Game.start_ng_plus() and Game.profile.ng == 0, "nor can the second generation turn the world over past the heir")
	# the Kept, once let go, does not stand again
	_heir()
	Game.echo_foe()
	var last: Array = Encounters.options(3, "courtyard", 6)
	ok(last.size() == 1 and str(last[0].get("foe", "")) == "the_kept", "the Kept stands in the Inner Ward")
	Game.profile.defeated["the_kept"] = 1
	Game.profile.flags["kept_released"] = true
	Game.save()                    # (as KeptScene.grant_edge does: the fact is written with the save)
	ok(Game.has_fact("released:the_kept"), "letting the Kept go is a fact of the world")
	last = Encounters.options(3, "courtyard", 6)
	ok(last.size() == 1 and str(last[0].type) == "pass" and not last[0].has("foe"), "walked again, the post is empty: the Kept does not reappear (%s)" % str(last[0].get("hint", "")))
	Game.start_run("courtyard")
	Game.run.stage = 6
	ok(Game.stage_options().size() == 1 and str(Game.stage_options()[0].type) == "pass" and Encounters.guardian(3, "courtyard").is_empty(), "and the road offers only the way on")
	Game.run = {}
	Game.profile = {}
	ok(Game.load_game() and Game.has_fact("released:the_kept") and str(Encounters.options(3, "courtyard", 6)[0].type) == "pass", "it stays so after a load")
	# King's Remnant is the one-handed sword its model is
	var kr: Dictionary = Db.item("w_throneshard")
	ok(str(kr.cls) == "sword" and not bool(Db.classes[kr.cls].two_handed) and str(kr.get("gear_id", "")) == "kings_remnant", "King's Remnant is classed as the one-handed sword it is modelled as")
	Game.new_game()
	Game.grant_item("w_throneshard")
	Game.profile.attrs.strength = 20
	Game.profile.attrs.dex = 20
	var shield = Game.profile.equipped.shield
	ok(Game.equip("w_throneshard") and Game.profile.equipped.shield == shield and shield != null, "and wielding it leaves the shield on the arm")
	var between: bool = int(Db.item("w_rime_sword").damage) < int(kr.damage) and int(kr.damage) < int(Db.item("w_monarch").damage)
	ok(between, "its edge sits between the Rimeglass Sabre and the Monarch's own (%d)" % int(kr.damage))
	# the Awakened Beast has its own fight
	var beast: Dictionary = Encounters.foe("awakened_beast")
	var base: Dictionary = Db.foes["maulbeast"]
	var mine := {}
	var theirs := {}
	for ph: Dictionary in beast.phases:
		for c: Dictionary in ph.combos:
			mine[str(c.id)] = true
	for c: Dictionary in base.phases[0].combos:
		theirs[str(c.id)] = true
	var own := 0
	for cid: String in mine:
		own += 0 if theirs.has(cid) else 1
	ok(beast.phases.size() == 3 and float(beast.phases[1].at) < 1.0 and float(beast.phases[2].at) < float(beast.phases[1].at) and own >= 7,
		"the Awakened Beast fights in three phases with %d patterns the Maulbeast never had" % own)
	var fair := true
	var quick := 9.0
	for ph: Dictionary in beast.phases:
		for c: Dictionary in ph.combos:
			for a: Dictionary in c.attacks:
				fair = fair and (bool(a.parry) or str(a.dodge) != "none" or not bool(a.unblockable))
				quick = minf(quick, float(a.windup) / float(ph.speed))
	ok(fair and quick >= 0.33, "every blow of it has an answer and can be read (quickest %.2f s)" % quick)
	ok(str(beast.phases[1].get("roar", "")) != "" and beast.boss, "its change of temper is told")
	# late-game balance: a careless but competent player (the sloppy bot) neither walks through the late guardians nor is
	# walled by them; the skilled bot always can win. Same seeds every run: the rules are deterministic.
	_heir()
	var builds := {}
	for gen: int in [2, 3]:
		# what the house holds late in each generation (tools/econ_sim.sh --generations): the heir has had longer at the forge
		var late := Game.default_profile()
		late.level = 14 if gen == 2 else 17
		late.attrs = {"health": 14, "strength": 12, "dex": 9, "endurance": 9, "defense": 8, "crit": 2, "resist": 2} if gen == 2 else {"health": 19, "strength": 15, "dex": 11, "endurance": 11, "defense": 12, "crit": 3, "resist": 3}
		for id: String in ["w_monarch", "s_rime", "a_wyrm_helm", "a_hollow_chest", "a_wyrm_gauntlets", "a_hollow_legs"]:
			if Db.items.has(id):
				late.inventory.append(id)
				late.equipped[str(Db.item(id).slot)] = id
				late.upgrades[id] = 4 if gen == 2 else 5
		builds[gen] = Stats.compute(late, Db.items, Db.classes)
	for foe_id: String in ["forgotten_monarch", "frostbound_king", "monarch_iii", "awakened_beast", "laboratory_guardian"]:
		var f: Dictionary = Encounters.foe(foe_id) if not Db.foes.has(foe_id) else Db.foes[foe_id]
		var st: Dictionary = builds[3 if int(f.get("gen", 2)) == 3 else 2]
		var t_sum := 0.0
		var wins := 0
		var hurt := 0.0
		for sd: int in [21, 22, 23, 24]:
			var sim := DuelSim.new()
			sim.setup(st, f, sd, {"combos": Db.combos})
			var bot := DuelBot.new(sim, DuelBot.Style.SLOPPY, sd)
			for i: int in 400 * 60:
				bot.tick(1.0 / 60.0)
				sim.tick(1.0 / 60.0)
				if sim.over:
					break
			t_sum += sim.time
			wins += 1 if sim.b_state == DuelSim.B.DEAD else 0
			hurt += float(sim.stats.taken) / float(sim.pl.max_hp)
		var skilled := DuelSim.new()
		skilled.setup(st, f, 31, {"combos": Db.combos})
		var sb := DuelBot.new(skilled, DuelBot.Style.SKILLED, 31)
		for i: int in 400 * 60:
			sb.tick(1.0 / 60.0)
			skilled.tick(1.0 / 60.0)
			if skilled.over:
				break
		ok(t_sum / 4.0 >= 40.0 and t_sum / 4.0 <= 240.0 and hurt / 4.0 >= 0.25 and wins >= 1 and skilled.b_state == DuelSim.B.DEAD,
			"balance, %s: a late knight's fight lasts %.0f s on average, costs %.0f%% of their health, is won %d times in 4 carelessly, and always with care" % [foe_id, t_sum / 4.0, 100.0 * hurt / 4.0, wins])
	Game.new_game()

# ---------------------------------------------------------------- the endings and the built machinery
func _scenes() -> void:
	_heir()
	for id: String in ["silence", "steward", "cities"]:
		ok(Story.has_scene("ending_" + id) and Story.data.scenes["ending_" + id].lines.size() >= 5, "ending %s: its lines exist, each with a voice id" % id)
		var unrec := true
		for lid: String in Story.data.scenes["ending_" + id].lines:
			unrec = unrec and Story.data.lines[lid].get("recorded", true) == false and str(Story.data.lines[lid].text) != ""
		ok(unrec, "ending %s: subtitles only for now (marked not recorded, so no stale take plays)" % id)
		var e := EndingScene.make(id)
		add_child(e)
		var done := [false]
		e.finished.connect(func(): done[0] = true)
		var t := 0.0
		while t < 200.0 and not done[0]:
			if Story.busy:
				Story._skip = true
			await get_tree().process_frame
			t += get_process_delta_time()
		var distinct := {}
		for sname: String in e.shots:
			distinct[sname] = true
		ok(done[0] and distinct.size() >= 5 and is_instance_valid(e.hero), "ending %s plays through as a scene: %d camera set-ups (%s), the heir in it" % [id, distinct.size(), str(e.shots)])
		ok(id != "silence" or e.set_b is HighRoad, "The Final Silence ends on the high road") if id == "silence" else null
		ok(e.set_b is Arena and (e.set_b as Arena)._theme_id == "throne", "The Last Steward ends in the throne hall") if id == "steward" else null
		ok(is_instance_valid(e._figure) and e._door_light != null, "The Free Cities ends on a doorway with someone standing in it") if id == "cities" else null
		e.queue_free()
		Story.stop()
		await frames(3)
	# a skipped ending still ends once
	var e2 := EndingScene.make("cities")
	add_child(e2)
	var n := [0]
	e2.finished.connect(func(): n[0] += 1)
	await frames(2)
	e2.skip()
	e2.skip()
	ok(n[0] == 1, "an ending skipped ends once")
	e2.queue_free()
	await frames(2)
	# the machinery is built, not boxed
	var host := Node3D.new()
	add_child(host)
	var lamp := FinalHall.lamp(Color("#5fe0c8"), 1.0)
	var ring := OldMake.ring(host, 6.0, 0.5, lamp)
	var tori := 0
	for mi: MeshInstance3D in ring.find_children("*", "MeshInstance3D", true, false):
		tori += 1 if mi.mesh is TorusMesh else 0
	var eng: Dictionary = OldMake.engine(host, Vector3.ZERO, Color("#b07aff"))
	var rack := OldMake.rack(host, Vector3(3, 0, 0), Vector3(1.3, 9.0, 4.4), lamp)
	var vault := OldMake.vault(host, 19.0, 6.5, 12.5, 13.0, -19.0, 8)
	var shadows := 0
	for mi: MeshInstance3D in vault.find_children("*", "MeshInstance3D", true, false):
		shadows += 1 if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 0
	ok(tori >= 2 and eng.rings.size() == 6 and eng.light is OmniLight3D and rack.get_child_count() > 40 and vault.get_child_count() > 80 and shadows == 0,
		"old-make machinery: rings are true rings, an engine carries six lamp rings, a rack has its cells, the vault's ribs cast no shadow on the fight")
	host.queue_free()
	var a := Arena.new()
	add_child(a)
	a.build("throne")
	var hall := FinalHall.dress(a)
	ok(hall._rings.size() == 12 and hall._engine_lights.size() == 2, "the final hall's engines still carry the seal's twelve rings")
	hall.show_seal(2, 4)
	ok(hall._ring_on == 3, "and still count the seal down")
	a.queue_free()
	for scene: Node in [Facility.new(), Aftermath.new(), SecondFall.new()]:
		add_child(scene)
		await frames(3)
		ok(scene.cam != null and scene.cam.current, "%s builds with the new dressing" % scene.get_script().get_global_name())
		scene.queue_free()
		await frames(2)
	Game.new_game()
