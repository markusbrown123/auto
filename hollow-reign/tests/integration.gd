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
	#await _gear_on_rig()
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


# ---------------------------------------------------------------- real equipment on the rig
func _wear(ids: Array) -> void:
	for id: String in ids:
		if not Game.owns(id):
			Game.profile.inventory.append(id)
		Game.equip(id)

func _gear_on_rig() -> void:
	var keep: Dictionary = Game.profile.duplicate(true)
	# every equippable item resolves to something drawn, or says honestly that it is not
	var unresolved: Array = []
	for it: Dictionary in Db.item_list:
		var slot := str(it.slot)
		if Db.ARMOUR_SLOTS.has(slot):
			var ps := str(it.get("part_slot", ""))
			if not (bool(it.get("part_ready", false)) and ArmorParts.has_part("m", str(it.part), ps) and ArmorParts.has_part("f", str(it.part), ps)):
				unresolved.append(it.id)
		elif slot in ["weapon", "shield"]:
			var g := str(it.get("gear_id", ""))
			var has_gear := g != "" and GearModel.exists(g)
			var has_old: bool = str(it.get("visual", "")) in ["model", "alias"] and ResourceLoader.exists("res://assets/models/%s.glb" % str(it.get("model", "")))
			if not (has_gear or has_old or str(it.get("visual", "")) == "none"):
				unresolved.append(it.id)
			if str(it.get("visual", "")) == "none" and (has_gear or has_old):
				unresolved.append(it.id)
		elif str(it.get("visual", "")) != "none":
			unresolved.append(it.id)
	ok(unresolved.is_empty(), "every equippable item resolves to a part, a model or an honest 'none' %s" % str(unresolved))
	# a new game starts in the sleek base knight
	var look: Dictionary = Duel.player_look()
	ok(look.get("skin", "") == ArmorParts.host_path(str(Game.profile.body)) and look.get("parts", {}).get("chest", "") == "crownless", "a new knight is the base body in Crownless plate")
	ok(str(look.get("gear", "")) == "wayfarer" and str(look.get("shield", {}).get("gear", "")) == "shield_heater", "the starting sword and shield are the hand-modelled ones")
	# mixed armour: one suit per slot, empty slots the base body's piece
	_wear(["a_frost_helm", "a_black_chest", "a_regal_gauntlets", "a_ash_legs"])
	look = Duel.player_look()
	var p: Dictionary = look.get("parts", {})
	ok(p.get("helm") == "frost" and p.get("chest") == "black" and p.get("arms") == "regal" and p.get("legs") == "ash" and p.get("shoulders") == "crownless" and p.get("boots") == "crownless",
		"player_look gives a part per slot for mixed gear %s" % str(p))
	_wear(["a_vigil_helm", "a_garrison_shoulders"])
	p = Duel.player_look().get("parts", {})
	ok(p.get("helm") == "vigil" and p.get("shoulders") == "vigil", "the Vigil hood brings its mantle")
	_wear(["a_frost_helm"])
	p = Duel.player_look().get("parts", {})
	ok(p.get("shoulders") != "garrison", "Garrison pauldrons give way over another cuirass (%s)" % str(p.get("shoulders")))
	_wear(["a_garrison_chest"])
	ok(Duel.player_look().get("parts", {}).get("shoulders") == "garrison", "and are worn over their own")
	Game.profile.cosmetics = {"helm": {"finish": "", "accent": "", "look_as": "a_black_helm"}}
	_wear(["a_black_helm", "a_frost_helm"])
	ok(Duel.player_look().get("parts", {}).get("helm") == "black", "a cosmetic 'look as' is what is drawn")
	Game.profile.cosmetics = {}
	# the rig wears them, and its volumes are measured from what is worn
	Game.profile = keep.duplicate(true)
	var plain := FighterRig.new()
	add_child(plain)
	plain.build(Duel.player_look(), false)
	ok(plain.has_parts() and plain.parts.worn.get("helm") == "crownless" and plain.skin.parts == plain.parts, "the rig dresses the body from the loadout")
	var hidden := 0
	for mi: MeshInstance3D in plain.skin.root.find_children("*", "MeshInstance3D", true, false):
		if not mi.name.begins_with("part_") and mi.visible:
			hidden += 1
	ok(hidden == 0, "the body's own mesh is hidden under the parts")
	var head0: float = plain.skin.extent("Head", Vector3.UP)
	var sh0: float = float(plain.skin.ball("LeftArm")[1])
	_wear(["a_frost_helm", "a_wyrm_shoulders"])
	var spiky := FighterRig.new()
	add_child(spiky)
	spiky.build(Duel.player_look(), false)
	ok(spiky.skin.extent("Head", Vector3.UP) > head0 + 0.02 and float(spiky.skin.ball("LeftArm")[1]) > sh0 + 0.01,
		"rig bounds include the worn parts (crowned helm %.2f > %.2f, horned pauldron %.2f > %.2f)" % [spiky.skin.extent("Head", Vector3.UP), head0, float(spiky.skin.ball("LeftArm")[1]), sh0])
	ok(plain.wear_parts(spiky.cfg.parts) and is_equal_approx(plain.skin.extent("Head", Vector3.UP), spiky.skin.extent("Head", Vector3.UP)), "a piece swapped on a standing knight is measured again")
	plain.skin.flash(1.0)
	ok(plain.parts._params.has(&"flash"), "flash reaches the worn parts")
	# gear models: reach, pommel and shield board come from the manifest
	var h := GearModel.hold("wayfarer")
	ok(is_equal_approx(plain.weapon_len, float(GearModel.info("wayfarer").tip) * GearModel.rig_scale("wayfarer")) and is_equal_approx(plain._pommel, float(h.pommel)), "the sword's length and pommel are the manifest's")
	ok(is_equal_approx(plain.reach(), 0.05 + 0.5 + FighterRig.REACH_STEP + plain.weapon_len * 0.8), "reach() is fed by the gear model's length")
	ok(plain.shield != null and is_equal_approx(plain._sh_hh, float(GearModel.info("shield_heater").height) * 0.5 * GearModel.rig_scale("shield_heater")), "the shield board is the manifest's")
	Game.profile = keep.duplicate(true)
	_wear(["w_oath_axe"])
	var great := FighterRig.new()
	add_child(great)
	great.build(Duel.player_look(), false)
	ok(great.two_handed and great.reach() > plain.reach() + 0.3 and is_equal_approx(great._off_grip, float(GearModel.hold("oathbreaker").off_hand)), "the greatsword reaches further and its second hand is where the manifest puts it")
	Game.profile = keep.duplicate(true)
	_wear(["w_twin_relics"])
	var twin := FighterRig.new()
	add_child(twin)
	twin.build(Duel.player_look(), false)
	var lg: Node3D = twin.weapon_l.get_child(0) if twin.weapon_l.get_child_count() > 0 else null
	ok(twin.dual and lg != null and lg.transform.basis.determinant() < 0.0 and (twin.weapon_r.get_child(0) as Node3D).transform.basis.determinant() > 0.0, "Twin Relics are one blade and its mirror image")
	# Recall for the advanced pieces, a draw (or nothing) for the rest
	await get_tree().process_frame
	ok(bool(twin.cfg.get("advanced", false)) and twin.present_weapon("auto", {"key": "test_foe"}) > 0.6, "an advanced weapon is recalled in full the first time")
	var recalls := 0
	for c in twin.weapon_r.get_children():
		if c is Recall:
			recalls += 1
	ok(recalls == 1, "Recall runs on the weapon in the hand")
	ok(twin.present_weapon("auto", {"key": "test_foe"}) <= 0.55, "and in its short form when the same foe is met again")
	twin.swing(Vector2(1, 0), 0.3)
	recalls = 0
	for c in twin.weapon_r.get_children():
		if c is Recall and not c.is_queued_for_deletion():
			recalls += 1
	ok(recalls == 0, "a cut thrown meanwhile finishes it")
	ok(not bool(plain.cfg.get("advanced", false)) and plain.present_weapon("auto", {"quick": true}) == 0.0 and not plain.is_sheathed(), "an ordinary sword is simply in the hand when there is no intro")
	ok(plain.present_weapon("auto", {}) > 0.0, "and is drawn when there is one")
	for r: Node in [plain, spiky, great, twin]:
		r.queue_free()
	Game.profile = keep
