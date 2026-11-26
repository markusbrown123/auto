extends Node
## Headless end-to-end check of the real scenes:
##   godot --headless --path . res://tests/integration.tscn
## Builds every screen, switches every tab, then plays whole duels with a bot
## through the actual Duel scene (rigs, HUD, effects, audio calls included).
var failed := 0

func ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		failed += 1

func _ready() -> void:
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_itest"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	Game.new_game()
	Game.profile.tutorial_done = true
	Engine.time_scale = 6.0
	# --- menus
	var t := TitleScreen.new()
	add_child(t)
	await get_tree().process_frame
	t._new()
	t._settings()
	t._main()
	ok(t.menu.get_child_count() >= 3, "title screen builds")
	t.queue_free()
	Game.profile.gold = 9000
	Game.profile.shards = 99
	Game.profile.attr_points = 2
	for it in Db.item_list:
		Game.grant_item(it.id)
	var s := Sanctuary.new()
	add_child(s)
	await get_tree().process_frame
	for tab in Sanctuary.TABS:
		s.show_tab(tab)
		await get_tree().process_frame
		ok(s.content.get_child_count() > 0 or (tab == "Armory" and s.armory != null) or (tab in ["Shop", "Blacksmith"] and s.screen != null), "sanctuary tab %s" % tab)
	for slot in Db.SLOTS:
		s.sel_slot = slot
		s.sel_item = ""
		s.show_tab("Armory")
	s.smith_mode = "Wares"
	s.show_tab("Blacksmith")
	# every weapon class and armour set can be worn and drawn
	for id in ["w_ashen_great", "w_twin_fangs", "w_headsman", "w_monarch", "a_regal_helm", "a_frost_chest", "s_rime"]:
		Game.equip(id)
		await get_tree().process_frame
	ok(s.backdrop.rig != null, "knight rebuilds with new equipment")
	s.queue_free()
	await get_tree().process_frame
	# --- every region's road, every stage
	for r in Db.regions:
		Game.start_run(r.id)
		for i in r.stages.size():
			Game.run.stage = i
			var e := Explore.new()
			add_child(e)
			await get_tree().process_frame
			e.queue_free()
		ok(true, "road: %s" % r.name)
	# --- the Witness is found at the Courtyard's second stop: staged at the fallen monument, then worn
	Game.new_game()
	Game.profile.tutorial_done = true
	Game.start_run("courtyard")
	Game.run.stage = 1
	var ew := Explore.new()
	add_child(ew)
	await get_tree().create_timer(3.0).timeout
	ok(ew._staging and ew.relic != null, "witness: the discovery is staged at the monument")
	var had_relic: bool = ew.relic != null
	for i in 2000:
		if not ew._staging:
			break
		Story._skip = true
		await get_tree().process_frame
	ok(had_relic and ew.relic == null and Companion.witness_found() and bool(ew.backdrop.rig.cfg.get("witness", false)),
		"witness: after the scene the mask is off the stones and on the knight")
	await get_tree().create_timer(2.0).timeout
	ok(ew.layer.get_child(0).modulate.a > 0.5, "witness: the choices return")
	ew.queue_free()
	Story.stop()
	await get_tree().process_frame
	# --- the filmed Courtyard road: every stop offers exactly the choices the region data offers
	if CineRoad.available("courtyard"):
		Game.new_game()
		Game.profile.tutorial_done = true
		Game.start_run("courtyard")
		var road_ok := true
		for i in Db.region_by_id["courtyard"].stages.size():
			Game.run.stage = i
			Game.profile.flags["cine_road_courtyard_%d" % i] = true      # arrive directly: video does not decode headless
			Game.profile.flags["scene_courtyard_%d" % i] = true
			var cr := CineRoad.new()
			add_child(cr)
			await get_tree().process_frame
			await get_tree().process_frame
			var spots := cr.ui.find_children("*", "Button", true, false).filter(func(b): return b.flat)
			if spots.size() != Game.stage_options().size():
				road_ok = false
				print("    stop %d: %d hotspots for %d options" % [i, spots.size(), Game.stage_options().size()])
			cr.queue_free()
			await get_tree().process_frame
		ok(road_ok, "cinematic road: hotspots match the region's choices at all seven stops")
		# a cache pays once, however it is reached
		Game.run.stage = 1
		var cr2 := CineRoad.new()
		add_child(cr2)
		await get_tree().process_frame
		await get_tree().process_frame
		var gold: int = Game.profile.gold
		var cache: Dictionary = Game.stage_options()[0]
		cr2._choose(cache)
		var after: int = Game.profile.gold
		cr2._busy = false
		cr2._choose(cache)
		ok(cache.type == "treasure" and after > gold and Game.profile.gold - after < after - gold and Game.owns("a_garrison_gauntlets"), "cinematic road: a cache gives its contents once")
		cr2.queue_free()
		await get_tree().process_frame
	# --- the story chain through the real router: New Journey → opening → chamber → walk → first stop
	if FileAccess.file_exists(Game._p(Opening.SEEN_FILE)):
		DirAccess.remove_absolute(Game._p(Opening.SEEN_FILE))
	var m: Node = load("res://src/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	m._new_journey("#16332c", "f")
	await get_tree().create_timer(1.2).timeout
	ok(m.current is Opening and Game.profile.body == "f", "new journey: opens on the opening")
	m.current.skip()
	await get_tree().process_frame
	await get_tree().process_frame
	ok(m.current is Awakening, "new journey: the opening, skipped, leads to the chamber")
	if m.current is Awakening:
		var kn: CineActor = m.current.knight
		ok(str(kn.cfg.skin).contains("knight_f") and str(kn.cfg.get("weapon_model", "")).contains(str(Game.profile.equipped.weapon)) and not kn.weapon_r.visible,
			"chamber: the chosen knight, with her own sword still in the block")
		m.current.skip()
	await get_tree().process_frame
	await get_tree().process_frame
	ok(m.current is Approach and str(Game.run.get("region", "")) == "courtyard" and int(Game.run.stage) == 0, "new journey: the chamber leads out into the Courtyard")
	var place: Node = m.current.backdrop if m.current is Approach else null
	if m.current is Approach:
		m.current.skip()
	await get_tree().process_frame
	await get_tree().process_frame
	ok(m.current is Explore and m.current.backdrop == place and is_instance_valid(place), "new journey: the walk ends on the first stop, in the same place (nothing rebuilt)")
	ok(Opening.seen_before(), "the opening is remembered as seen")
	var loading := func() -> bool:
		for c in get_tree().root.get_children():
			if c is LoadingScreen:
				return true
		return false
	ok(not loading.call(), "new journey: no loading screen on the way to the first stop")
	# the first duel: the road has read the foe ahead, so it is a fade and nothing else
	if m.current is Explore:
		for i in 600:
			if m.current.foes.size() > 0 and m.current.foes[0] != null:
				break
			await get_tree().process_frame
		ok(m.current.foes.size() > 0 and m.current.foes[0] != null, "first stop: the foe stands on the road")
		m._enter_duel(Game.stage_options()[0])
		await get_tree().process_frame
		var seen_loading: bool = loading.call()
		await get_tree().create_timer(1.5).timeout
		ok(not seen_loading and not loading.call() and m.current is Duel, "first duel: reached by a fade, with no loading screen")
	# a later new journey passes over the opening; Continue never replays either scene
	m._new_journey("#3d0f0f", "m")
	await get_tree().create_timer(1.2).timeout
	ok(m.current is Awakening, "a later new journey passes over the opening")
	Game.save()
	m.show_title()
	await get_tree().process_frame
	if m.current is TitleScreen:
		m.current.continue_game.emit()
	await get_tree().create_timer(1.2).timeout
	ok(m.current is Sanctuary, "continue: goes to the save, and replays neither opening nor chamber")
	Story.stop()
	m.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# --- whole duels through the real scene, every foe
	Game.new_game()
	for id in ["w_monarch", "a_regal_helm", "a_regal_chest", "a_regal_gauntlets", "a_regal_legs", "s_rime"]:
		Game.grant_item(id)
		Game.equip(id)
	for k in ["health", "strength", "dex", "endurance"]:
		Game.profile.attrs[k] = 22
	for foe_id in Db.foes:
		var d := Duel.new()
		add_child(d)
		d.setup(foe_id, {"autoplay": true, "bot_style": DuelBot.Style.SKILLED, "seed": 4, "skip_intro": true})
		var res: Array = await d.finished
		ok(res[0], "duel scene vs %s (%.0fs sim time)" % [foe_id, res[1].time])
		d.queue_free()
		await get_tree().process_frame
	# --- a lost duel reaches the death stage cleanly
	Game.new_game()
	var d2 := Duel.new()
	add_child(d2)
	d2.setup("forgotten_monarch", {"autoplay": true, "bot_style": DuelBot.Style.SPAM, "seed": 4})
	var res2: Array = await d2.finished
	ok(not res2[0], "defeat is reported")
	Overlays.death(d2, Db.foes.forgotten_monarch, Game.on_death(), func(): pass)
	Overlays.victory(d2, Db.foes.hollow_soldier, Game.on_victory("hollow_soldier", 10.0), d2.sim, func(): pass)
	await get_tree().process_frame
	d2.queue_free()
	print("\nintegration: %s" % ("PASS" if failed == 0 else "%d FAILED" % failed))
	get_tree().quit(1 if failed > 0 else 0)
