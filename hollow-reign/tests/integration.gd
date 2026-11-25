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
		ok(s.content.get_child_count() > 0, "sanctuary tab %s" % tab)
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
