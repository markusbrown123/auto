extends Node
## The three-generation campaign through the real router, with bots and skips:
##   godot --headless --path . res://tests/campaign.tscn
## New Legacy → Generation I → the years → Generation II → the second meeting (won; left for the seal; lost) → the fall
## → the years → the heir → the blade that was left → the Kept in the saved loadout → the last duel and its seal →
## the door, the facility → each ending (the third gated) → a legacy journey. Saved and loaded at every transition,
## Continue from every checkpoint, both bodies, and a migrated version-2 save.
## Scenes are skipped and the bot's blade is weighted so the run stays short: what is checked is the flow and the
## records, not the balance (tests/tests.gd and tests/generations.gd hold that).
var failed := 0
var m: Node

func ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		print("        (on screen: %s; buttons: %s)" % [m.current.get_script().get_global_name() if m != null and m.current != null and m.current.get_script() != null else "-",
			str(m.find_children("*", "Button", true, false).filter(func(b): return b.text != "" and b.is_visible_in_tree()).map(func(b): return b.text)).left(160) if m != null else ""])
	if not cond:
		failed += 1

func frames(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame

## Waits (up to `limit` seconds of game time) until `cond` holds, hurrying any speech along.
func until(cond: Callable, limit: float = 60.0) -> bool:
	var t := 0.0
	var n := 0
	while t < limit or n < int(limit * 30.0):       # game seconds, and never fewer frames than that many would take
		if cond.call():
			return true
		if Story.busy:
			Story._skip = true
		await get_tree().process_frame
		t += get_process_delta_time()
		n += 1
	return cond.call()

func press(text: String) -> bool:
	for b: Button in m.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree() and not b.disabled and not b.is_queued_for_deletion():
			b.pressed.emit()
			return true
	return false

func button(text: String) -> Button:
	for b: Button in m.find_children("*", "Button", true, false):
		if b.text == text and not b.is_queued_for_deletion():
			return b
	return null

func skip_scene() -> void:
	if m.current != null and m.current.has_method("skip"):
		m.current.skip()
	await frames(3)

## The save on disk is the profile in memory, and reading it back changes nothing.
func saved_and_loaded(label: String) -> void:
	Game.save()
	var before := JSON.stringify(Game.profile, "", true)
	var run: Dictionary = Game.run
	var good := Game.load_slot(Game.slot)
	Game.run = run
	ok(good and JSON.stringify(Game.profile, "", true) == before, "save/load %s: the save read back is the save written" % label)

func layer_of(p: Dictionary) -> Dictionary:
	# what a transition must not touch (the family's own)
	var out := {}
	for k: String in ["gold", "shards", "level", "xp", "attrs", "attr_points", "inventory", "upgrades", "mods", "edge", "mastery", "mastered", "materials",
			"combos", "combo_uses", "lore", "defeated", "heraldry", "secrets", "discovered"]:
		if p.has(k):
			out[k] = p[k].duplicate(true) if (p[k] is Dictionary or p[k] is Array) else p[k]
	return out

func _ready() -> void:
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_campaign"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	for n in range(1, Game.SLOT_COUNT + 1):
		Game.delete_slot(n)
	Engine.time_scale = 8.0
	m = load("res://src/main.tscn").instantiate()
	add_child(m)
	await frames()
	m._args["bot"] = "1"
	m._args["auto"] = "1"
	var seals := {}
	var looks := {}
	await journey("f", "win", seals, looks)
	await journey("m", "records", seals, looks)
	ok(looks.has("f") and looks.has("m") and looks.f != looks.m, "two different saves give two different Kept (%s / %s)" % [str(looks.get("f", "")).left(60), str(looks.get("m", "")).left(60)])
	ok(int(seals.get("f", 0)) < int(seals.get("m", 0)), "what the house gathered shortens the seal: %d marks for the house that beat him, %d for the one that did not" % [int(seals.get("f", 0)), int(seals.get("m", 0))])
	await migrated()
	Story.stop()
	print("\ncampaign: %s" % ("PASS" if failed == 0 else "%d FAILED" % failed))
	get_tree().quit(1 if failed > 0 else 0)

## Starts a story duel through the router and waits for steel. Returns the Duel (or null).
func begin_duel(o: Dictionary, weight: float) -> Duel:
	m.start_duel(o)
	await frames(3)
	if m.current is KeptScene:
		return null
	await until(func(): return m.current is Duel and m.current.stage == Duel.Stage.FIGHT, 120.0)
	if not m.current is Duel:
		return null
	var d: Duel = m.current
	d.sim.pl.attack = float(d.sim.pl.attack) * weight
	d.sim.pl.max_hp = float(d.sim.pl.max_hp) * 30.0
	d.sim.pl.hp = d.sim.pl.max_hp
	return d

func journey(body: String, variant: String, seals: Dictionary, looks: Dictionary) -> void:
	print("• the %s's line, the second %s" % ["daughter" if body == "f" else "son", "beats him" if variant == "win" else "leaves the fight for the seal"])
	if FileAccess.file_exists(Game._p(Opening.SEEN_FILE)):
		DirAccess.remove_absolute(Game._p(Opening.SEEN_FILE))
	Game.slot = 1 if body == "f" else 2
	m._new_journey("#16332c" if body == "f" else "#1c2240", body, "Maren" if body == "f" else "Aldric")
	await until(func(): return m.current is Prologue, 10.0)
	ok(m.current is Prologue and Game.generation() == 2 and str(Game.generation_record(1).fate) == "fallen", "New Legacy opens on Generation I; the save is the second generation's, the first recorded as fallen")
	if m.current is Prologue:
		m.current.skip()
	await frames(3)
	ok(m.current is TimeJump and m.current.years == 22, "Generation I leads to twenty-two years")
	await skip_scene()
	ok(m.current is Arrival and m.current.gen == 2, "then the second generation's arrival")
	await skip_scene()
	ok(m.current is Awakening, "then the Inheritance Engine")
	await skip_scene()
	ok(m.current is Approach, "then the walk out")
	await skip_scene()
	ok(m.current is Explore and str(Game.run.region) == "courtyard" and Game.profile.body == body, "Generation II's road begins in the Courtyard (%s)" % body)
	await saved_and_loaded("at the start of Generation II")
	# ---- the second generation walks its road (the roads themselves are tests/integration.gd's and tests/generations.gd's)
	var p: Dictionary = Game.profile
	p.tutorial_done = true
	var kit: Array = ["w_knight_sword", "s_garrison", "a_garrison_helm", "a_garrison_chest", "a_garrison_gauntlets", "a_garrison_legs"] if body == "f" else ["w_ashen_great", "a_frost_helm", "a_black_chest", "a_regal_gauntlets", "a_ash_legs"]
	for id: String in kit:
		Game.grant_item(id)
		Game.equip(id)
	var blade := str(p.equipped.weapon)
	p.upgrades[blade] = 3
	p.mods[blade] = {"grip": 2, "ore": 1, "ore_id": ""}
	for k: String in ["health", "strength", "dex", "endurance"]:
		p.attrs[k] = 20
	p.level = 18
	p.gold = 5000
	for c: Dictionary in Db.combos.slice(0, 4):
		if not p.combos.has(c.id):
			p.combos.append(c.id)
		p.combo_uses[c.id] = 12 - p.combos.find(c.id)
	p.flags["witness_found"] = true
	for r: String in ["courtyard", "blackwood", "cathedral", "crypt", "citadel"]:
		Game.start_run(r)
		Game.complete_region()
	for f: String in ["ashen_sentinel", "hollow_executioner", "cathedral_beast", "gravewarden", "frostbound_king"]:
		p.defeated[f] = 1
	ok(Game.region_unlocked("throne") and m.story_kind("forgotten_monarch") == "monarch2", "the Throne is open, and its guardian is the second meeting")
	var worn: Dictionary = Duel.player_look()
	var weapon_before: Dictionary = Generations._weapon_record(blade, p)
	Game.start_run("throne")
	Game.run.stage = 6
	var o: Dictionary = Game.stage_options()[0]
	ok(str(o.foe) == "forgotten_monarch", "the last stop of the Throne is the Monarch")
	# ---- an ordinary defeat first: it is a defeat, and the family's story does not move
	var deaths := int(p.deaths)
	m._args["choice"] = "press"
	var d: Duel = await begin_duel(o, 1.0)
	ok(d != null and d.story.get("pre_scene", "") == "monarch_blade" and d.sim.beat_at.has(2) and d.sim.beat_hp > 0.0 and Game.profile.flags.has("scene_monarch_blade"), "the second meeting: \"That blade.\" first, and a beat at the threshold")
	if d != null:
		d.sim.pl.hp = 1.0
		d.sim._damage_player(999999.0, true)
		await until(func(): return button("Return to sanctuary") != null, 30.0)
		ok(Game.generation() == 2 and Game.transition_pending().is_empty() and int(Game.profile.deaths) == deaths + 1 and not Game.monarch_won(2) and str(Game.generation_record(2).fate) == "alive",
			"lost to him: an ordinary defeat. Nobody falls, nothing is inherited, the road is taken again")
		var said := ""
		for l: Label in m.find_children("*", "Label", true, false):
			said += l.text + " "
		ok(said.contains("THE REIGN ENDURES") and not said.to_lower().contains("generation") and not said.to_lower().contains("heir"), "the defeat screen says nothing of the lineage")
		press("Return to sanctuary")
		await until(func(): return m.current is Sanctuary, 10.0)
		ok(m.current is Sanctuary, "and the knight is back at the sanctuary")
	# ---- the second meeting, for real
	Game.start_run("throne")
	Game.run.stage = 6
	var gold := int(Game.profile.gold)
	var family := layer_of(Game.profile)
	if variant == "win":
		m._args["choice"] = "press"
		d = await begin_duel(o, 60.0)
		await until(func(): return button("Continue") != null or not m.current is Duel, 400.0)
		ok(d != null and d.has_meta("asked") and str(Game.monarch(2).record.get("choice", "")) == "press", "at the threshold the choice was put, and the fight pressed")
		ok(Game.monarch_won(2) and Game.has_fact("monarch_bested:2") and int(Game.profile.gold) > gold and int(Game.profile.defeated.get("forgotten_monarch", 0)) == 1 and button("Continue") != null,
			"he was beaten: the win is recorded, the rewards are paid (+%d gold) and shown" % (int(Game.profile.gold) - gold))
		ok(Game.generation() == 2 and Game.transition_pending().is_empty(), "and the generation has not yet fallen")
		family = layer_of(Game.profile)
		await saved_and_loaded("after the win, before the fall")
		press("Continue")
		await until(func(): return m.current is SecondFall, 10.0)
		ok(m.current is SecondFall and m.current.won and m.current.monarch != null, "then the hall's machines stand him up: the second fall, told as a win")
		# Continue from here (the app closed between the win and the fall) comes back to the same scene
		m.resume()
		await frames(3)
		ok(m.current is SecondFall and m.current.won, "Continue after the win and before the fall: the fall, as a win")
	else:
		# the knight is nearly down: the seal is offered then too, and this one goes to it
		m._args["choice"] = "records"
		d = await begin_duel(o, 1.0)
		if d != null:
			d.sim.pl.hp = float(d.sim.pl.max_hp) * 0.15
		await until(func(): return m.current is SecondFall, 60.0)
		ok(d != null and d.sim.interrupted == "records" and d.sim.p_state != DuelSim.P.DEAD and d.sim.b_state != DuelSim.B.DEAD, "near falling, the seal was offered and chosen: the duel was left, not lost")
		ok(m.current is SecondFall and not m.current.won and str(m.current.choice) == "records" and not Game.monarch_won(2) and str(Game.monarch(2).record.get("choice", "")) == "records",
			"the second fall, told as it was: he was not beaten, and nobody says he was")
		ok(int(Game.profile.gold) == gold, "no reward is paid for a fight that was left")
		m.resume()
		await frames(3)
		ok(m.current is SecondFall and not m.current.won, "Continue after the choice and before the fall: the fall")
	await saved_and_loaded("before the second fall")
	ok(Game.transition_pending().is_empty(), "nothing has fallen until the scene says so")
	await skip_scene()
	var tr: Dictionary = Game.transition_pending()
	ok(str(tr.get("state", "")) == "fallen" and int(tr.get("from", 0)) == 2 and str(Game.generation_record(2).fate) == "kept" and Game.generation() == 2, "the second fall is recorded (skipped or played): fallen, to be answered by the third")
	ok(Game.monarch_won(2) == (variant == "win") and bool(Game.generation_record(2).context.get("won", false)) == (variant == "win"), "and it remembers honestly whether he had been beaten (%s)" % str(variant == "win"))
	ok(Game.generation_record(2).deeds.regions.has("throne") == (variant == "win"), "the Throne's road counts as cleared only for the one who beat its guardian")
	var echo: Dictionary = Game.profile.campaign.echo
	ok(str(echo.weapon.id) == blade and int(echo.weapon.level) == 3 and int(echo.weapon.mods.grip) == 2 and str(echo.equipped.chest) == str(kit[2] if body == "m" else kit[3]), "the snapshot of the second is what was worn and carried (%s +3)" % blade)
	ok(m.current is TimeJump and m.current.years == 24 and m.current.from_gen == 2 and m.current.to_gen == 3, "then twenty-four years")
	await saved_and_loaded("between the fall and the inheritance")
	m.resume()
	await frames(3)
	ok(m.current is TimeJump and m.current.years == 24, "Continue between the fall and the inheritance: the years, then the heir")
	# three ordinary defeats here change nothing either
	await skip_scene()
	ok(m.current is HeirReturn.Naming, "the heir is asked for a name, and nothing else")
	if m.current is HeirReturn.Naming:
		m.current._field.text = "Ilse" if body == "f" else "Corin"
		m.current.answer()
	await until(func(): return m.current is Arrival, 10.0)
	var heir: Dictionary = Game.generation_record(3)
	ok(Game.generation() == 3 and Game.transition_pending().is_empty() and str(heir.name) in ["Ilse", "Corin"] and str(heir.body) == body and str(Game.profile.body) == body, "the Last Heir: %s, of the same line (%s)" % [str(heir.name), body])
	ok(layer_of(Game.profile) == family, "nothing the family earned was lost at the transition (gold, gear and its records, mastery, combos, lore)")
	ok(Game.profile.cleared.is_empty() and Game.profile.flags.has("witness_found"), "the roads are to be walked again; the Witness comes with the heir")
	ok(m.current is Arrival and m.current.gen == 3 and int(m.current.road.arena.get_meta("generation", 0)) == 3 and m.current.line_scene == "gen3_arrive" and not m.current.show_name, "the heir's arrival: the winter road, their own lines, no title card")
	await saved_and_loaded("after the inheritance")
	m.resume()
	await frames(3)
	ok(m.current is Arrival and m.current.gen == 3, "Continue after the inheritance and before the road: the arrival")
	await skip_scene()
	ok(m.current is HeirReturn, "then the Inheritance Engine, walked into")
	var left: Dictionary = Game.fallen_weapon()
	ok(str(left.id) == blade and not left.taken and left.record == weapon_before and m.current is HeirReturn and m.current._rack_sword.visible, "the blade that was left stands in the block: the same record (tier, mods, edge, mastery)")
	if m.current is HeirReturn:
		await until(func(): return not m.current is HeirReturn or m.current._taken, 60.0)
	await skip_scene()
	ok(bool(Game.fallen_weapon().taken) and str(Game.profile.equipped.weapon) == blade and Generations._weapon_record(blade, Game.profile) == weapon_before, "taken up: it is in the heir's hand, as it was")
	ok(m.current is Approach and str(Game.run.get("region", "")) == "courtyard" and Game.profile.flags.has("gen3_arrived"), "and the road begins in the Courtyard")
	await skip_scene()
	ok(m.current is Explore, "Generation III's first stop")
	await saved_and_loaded("at the start of Generation III")
	m.resume()
	await frames(3)
	ok(m.current is Sanctuary, "Continue on the road: the sanctuary, as always")
	# ---- Generation III: the map, the roads, the Kept
	var wm := WorldMap.new()
	add_child(wm)
	await frames()
	var texts := ""
	for r: Dictionary in Db.regions:
		if Game.region_unlocked(r.id):
			wm.select(str(r.id))
			for l: Label in wm.card.find_children("*", "Label", true, false):
				texts += l.text + "|"
	ok(Game.region_unlocked("courtyard") and not Game.region_unlocked("blackwood") and not Game.region_unlocked("deep") and texts.contains("The Last Heir") and not texts.contains("Ashen Sentinel"),
		"the map is the last heir's: only the Courtyard is open, and its card does not name the second generation's guardian")
	wm.queue_free()
	var ch := Chronicle.new("Lineage")
	add_child(ch)
	await frames(3)
	var page := ""
	for l: Label in ch.find_children("*", "Label", true, false):
		page += l.text + "|"
	ok(page.contains("House") and page.contains("THE FIRST OATH") and page.contains("THE BROKEN CROWN") and page.contains("THE LAST HEIR") and page.contains(str(Db.item(blade).name)) and ch.find_children("*", "SubViewport", true, false).size() == 3,
		"the Lineage page: three of the house, each standing in what they wore, the second's blade named")
	ch.queue_free()
	var t := TitleScreen.new()
	add_child(t)
	await frames()
	var labels: Array = t.entries().map(func(e): return str(e[0]))
	ok(labels.has("Continue") and labels.has("New Legacy") and not labels.has("New Journey") and t.status_line().contains("The Last Heir"), "the menu: Continue, New Legacy; the status line names the generation")
	var sum: Dictionary = Game.slot_summary(Game.slot)
	ok(int(sum.generation) == 3 and str(sum.generation_title) == "The Last Heir" and str(sum.family) != "", "the slot summary carries generation, chapter title and family")
	t.queue_free()
	await frames()
	for r: Dictionary in Db.regions:
		if not Game.region_unlocked(r.id):
			continue
		Game.start_run(r.id)
		for i in r.stages.size():
			Game.run.stage = i
			var e := Explore.new()
			add_child(e)
			await frames(1)
			e.queue_free()
	await frames()
	Game.start_run("courtyard")
	Game.run.stage = 6
	o = Game.stage_options()[0]
	ok(str(o.foe) == "the_kept" and m.story_kind("the_kept") == "kept", "the Inner Ward: a guardian in the Sentinel's post, and it is the Kept")
	var kept_before := int(Game.profile.gold)
	await begin_duel(o, 1.0)
	ok(m.current is KeptScene and m.current.mode == "reveal", "first meeting: the reveal is staged before the duel")
	if m.current is KeptScene:
		var kr: FighterRig = m.current.kept
		ok(kr.cfg.get("parts", {}) == worn.get("parts", {}) and str(kr.cfg.get("gear", kr.cfg.get("weapon_model", ""))) == str(worn.get("gear", worn.get("weapon_model", ""))) and kr.has_parts(),
			"it wears what the second wore, and carries what the second carried %s" % str(kr.cfg.get("parts", {})))
		looks[body] = str(kr.cfg.get("parts", {})) + str(kr.cfg.get("gear", ""))
	await skip_scene()
	await until(func(): return m.current is Duel and m.current.stage == Duel.Stage.FIGHT, 120.0)
	ok(m.current is Duel and str(m.current.foe.id) == "the_kept" and Game.profile.flags.has("kept_revealed"), "then the duel")
	if m.current is Duel:
		d = m.current
		var fr: FighterRig = d.foe_rig
		ok(fr.has_parts() and fr.cfg.get("parts", {}) == worn.get("parts", {}) and fr.parts.worn.get("chest") == worn.parts.chest and (fr.shield != null) == worn.has("shield"),
			"in the duel it is dressed through the player's own parts and gear path (chest %s, shield %s)" % [str(fr.parts.worn.get("chest")), str(fr.shield != null)])
		var fav: Array = Game.profile.campaign.echo.combos
		ok(not fav.is_empty() and d.foe.phases[0].combos.any(func(c): return str(c.id).contains(str(fav[0][0]))) and d.story.get("yield", false), "it fights with the combinations the second used most, and it will yield, not die")
		d.sim.pl.attack = float(d.sim.pl.attack) * 40.0
		d.sim.pl.max_hp = float(d.sim.pl.max_hp) * 30.0
		d.sim.pl.hp = d.sim.pl.max_hp
		await until(func(): return m.current is KeptScene, 400.0)
		ok(m.current is KeptScene and m.current.mode == "after" and Game.profile.defeated.has("the_kept"), "beaten, it is not cut down: the aftermath is the story's")
		await skip_scene()
		await until(func(): return button("Continue") != null, 20.0)
		var edge: Dictionary = Generations._weapon_record("w_seconds_edge", Game.profile)
		ok(Game.owns("w_seconds_edge") and int(edge.level) == 3 and int(edge.mods.grip) == 2 and str(Db.item("w_seconds_edge").cls) == str(Db.item(blade).cls) and str(Db.item("w_seconds_edge").name) == "The Second's Edge",
			"it gives The Second's Edge: a copy of the second's blade (%s) with its forge work" % str(Db.item(blade).cls))
		ok(int(Game.profile.gold) > kept_before and Game.inheritance().any(func(r): return str(r.id) == "one_who_was_kept" and r.held), "with its reward, and the record One Who Was Kept")
		press("Continue")
		await until(func(): return m.current is Sanctuary, 20.0)
		ok(m.current is Sanctuary and Game.profile.cleared.has("courtyard") and Game.region_unlocked("blackwood") and Game.region_unlocked("cathedral") and not Game.region_unlocked("throne"),
			"the Courtyard is cleared: the roads beyond open, the Throne not yet")
		press("Rest")
	await saved_and_loaded("after the Kept")
	ok(m.story_kind("the_kept") == "", "let go, it is not staged a second time")
	# ---- two of the three roads, then the last meeting
	for r: String in ["blackwood", "cathedral"]:
		ok(Encounters.region_info(r).guardian.id in ["awakened_beast", "laboratory_guardian"], "%s is kept by %s now" % [r, str(Encounters.region_info(r).guardian.name)])
		Game.start_run(r)
		Game.complete_region()
	ok(Game.region_unlocked("throne") and not Game.region_unlocked("deep"), "two of three is enough for the Throne; the Deep is sealed")
	Game.start_run("throne")
	Game.run.stage = 6
	o = Game.stage_options()[0]
	var need: int = m.seal_need()
	seals[body] = need
	d = await begin_duel(o, 25.0)
	ok(d != null and str(d.foe.id) == "monarch_iii" and d.foe.phases.size() == 3 and d.sim.seal.get("need", 0) == need and d.arena.find_children("*", "FinalHall", true, false).size() == 1 and Game.profile.flags.has("scene_monarch_g3_intro"),
		"the last meeting: three phases, the hall with its machinery showing, his lines, a seal of %d" % need)
	if d != null:
		var hall: FinalHall = d.arena.find_children("*", "FinalHall", true, false)[0]
		var seen := {"phases": [], "seal": 0, "restored": 0, "broken": 0}
		d.sim.ev.connect(func(n: StringName, e: Dictionary):
			if n == &"phase_change":
				seen.phases.append(int(e.phase))
			elif n == &"seal":
				seen.seal += 1
			elif n == &"restored":
				seen.restored += 1
			elif n == &"seal_broken":
				seen.broken += 1)
		await until(func(): return d.sim.b_phase == 2 and d.sim.b_state != DuelSim.B.SHIFT, 400.0)
		ok(seen.phases == [1, 2] and d.sim.seal_need == need and d.hud._seal_row != null and d.hud._seal_row.text.begins_with("RESTORATION") and hall.level == 2 and d.hud.boss_name.text.contains("THE LAST DEFENSE"),
			"phase three: the seal is on the HUD, the engines are lit, the phase is named")
		await until(func(): return not m.current is Duel or d.stage == Duel.Stage.DONE, 600.0)
		ok(d.sim.b_state == DuelSim.B.DEAD and d.sim.seal_left == 0 and seen.broken == 1 and seen.seal >= 2, "he is ended by breaking what restores him (%d seal events, stood up again %d time%s)" % [seen.seal, seen.restored, "" if seen.restored == 1 else "s"])
	await until(func(): return m.current is Aftermath, 60.0)
	var overlay := false
	for l: Label in m.find_children("*", "Label", true, false):
		overlay = overlay or l.text.to_upper().contains("VICTOR") or l.text.contains("experience")
	ok(m.current is Aftermath and not overlay and button("Continue") == null, "no victory screen after it: the hall, and the quiet")
	ok(Game.has_fact("monarch_felled:3") and Game.monarch_won(3) and Game.region_unlocked("deep") and Game.profile.cleared.has("throne"), "he is felled; the door under the throne is open")
	await saved_and_loaded("after the last duel")
	m.resume()
	await frames(3)
	ok(m.current is Aftermath, "Continue after the last duel and before the door: the aftermath")
	await skip_scene()
	ok(m.current is Facility and m.current._rings.size() >= 10 and m.current._racks.size() >= 6, "the door opens on the facility: a shaft of rings, racks, the Crown")
	await skip_scene()
	await until(func(): return m.current is Sanctuary and button("Go on") != null, 20.0)
	ok(m.current is Sanctuary and Game.profile.flags.has("facility_seen") and button("Go on") != null, "afterwards, and only then, what the duel gave is told")
	press("Go on")
	await until(func(): return button("Not yet") != null, 10.0)
	var divide := button("Divide it")
	ok(button("Disconnect it") != null and button("Take it up") != null and divide != null and divide.disabled and button("Not yet") != null, "the Crown: two endings open, the third not yet earned, and the choice may wait")
	press("Not yet")
	await frames(3)
	ok(str(Game.profile.campaign.ending) == "" and Generations.canon_open(Game.profile), "left for later: nothing is chosen")
	m.resume()
	await frames(3)
	ok(m.current is Sanctuary, "Continue after the facility: the sanctuary")
	# the Deep's road ends at the Crown too
	var deep: Dictionary = Encounters.region_info("deep")
	ok(bool(deep.open) and int(deep.fights) > 0, "the Deep's endgame encounters are open (%d fights)" % int(deep.fights))
	Game.start_run("deep")
	Game.run.stage = Db.region_by_id["deep"].stages.size() - 1
	m._region_done()
	await until(func(): return button("Not yet") != null, 20.0)
	ok(button("Not yet") != null, "clearing the road under the throne comes to the choice again")
	# ---- the three endings, each from the same save
	Game.save()
	var at_crown := FileAccess.get_file_as_string(Game.slot_file(Game.slot))
	for id: String in ["silence", "steward", "cities"]:
		restore(at_crown)
		if id == "cities":
			ok(not Game.can_divide_crown(), "The Free Cities is shut without the side roads")
			for l: Dictionary in Db.lore.slice(0, Game.LORE_FOR_DIVIDE):
				if not Game.profile.lore.has(l.id):
					Game.profile.lore.append(l.id)
			Game.start_run("roost")
			Game.complete_region()
			Game.profile.defeated["devourer"] = 1
			Generations.sync(Game.profile)
			ok(Game.can_divide_crown(), "and opens with the records, the Roost, the Devourer, and the Kept let go")
			var without: Dictionary = Game.profile.duplicate(true)
			without.defeated.erase("the_kept")
			without.campaign.inheritance.erase("one_who_was_kept")
			Generations.sync(without)
			ok(not Generations.ending_open("cities", without), "but not for an heir who never faced the Kept")
		m.show_sanctuary()
		m._ending()
		await until(func(): return button(str(m.ENDINGS[id][1])) != null, 10.0)
		ok(press(str(m.ENDINGS[id][1])), "the last heir chooses: %s" % str(m.ENDINGS[id][0]))
		await frames(3)
		ok(str(Game.profile.campaign.ending) == id and Game.has_fact("ending:" + id) and Game.profile.endings.has(id) and not Generations.canon_open(Game.profile), "%s is the canon's ending" % id)
		press("Continue")
		await frames(3)
		press("Rest")
		await frames(3)
		if id != "cities":
			continue
		# ---- a legacy journey: outside the three generations
		var canon := JSON.stringify([Game.profile.generations, Game.profile.world, Game.profile.campaign.ending, Game.profile.campaign.monarch])
		Game.start_legacy_journey()
		ok(Game.on_legacy_journey() and m.story_kind("forgotten_monarch") == "" and m.story_kind("the_kept") == "", "a legacy journey: the roads again, and none of the family's scenes")
		Game.start_run("throne")
		Game.on_victory("forgotten_monarch", 50.0)
		Game.choose_ending("silence")
		ok(JSON.stringify([Game.profile.generations, Game.profile.world, Game.profile.campaign.ending, Game.profile.campaign.monarch]) == canon, "nothing it does is written into the lineage or the canon's ending")
		await saved_and_loaded("on a legacy journey")

## A version-2 save from the middle of the old campaign carries on as the second generation, and reaches the heir.
func migrated() -> void:
	print("• a migrated version-2 save")
	Game.slot = 3
	Game.run = {}
	var raw := FileAccess.get_file_as_string("res://tests/fixtures/save_v2.json")
	var f := FileAccess.open(Game.slot_file(3), FileAccess.WRITE)
	f.store_string(raw)
	f.close()
	Game.profile = {}
	ok(Game.load_slot(3) and Game.generation() == 2 and Generations.canon_open(Game.profile) and str(Game.generation_record(1).fate) == "fallen" and Game.profile.cleared.has("cathedral"),
		"it loads as Generation II in progress, with what it had done")
	m.resume()
	await frames(3)
	ok(m.current is Sanctuary, "Continue: the sanctuary")
	ok(m.story_kind("forgotten_monarch") == "monarch2", "its throne is the second meeting, not the old ending")
	var inv: Array = Game.profile.inventory.duplicate()
	Game.start_run("throne")
	Game.run.stage = 6
	m._args["choice"] = "records"
	var d: Duel = await begin_duel(Game.stage_options()[0], 1.0)
	if d != null:
		d.sim.pl.hp = float(d.sim.pl.max_hp) * 0.1
	await until(func(): return m.current is SecondFall, 60.0)
	await skip_scene()
	await skip_scene()
	if m.current is HeirReturn.Naming:
		m.current.answer()
	await until(func(): return m.current is Arrival, 10.0)
	ok(Game.generation() == 3 and Game.profile.inventory == inv and str(Game.generation_record(2).fate) == "kept", "it falls at the seal and is inherited, with everything it owned")
	Game.start_run("courtyard")
	Game.run.stage = 6
	ok(str(Game.stage_options()[0].foe) == "the_kept" and str(Db.foes["the_kept"].look.equipped.shield) == "s_tower", "and its Kept carries the migrated save's own shield")
	await saved_and_loaded("migrated, in Generation III")

## Puts a save file's text back in the slot and loads it.
func restore(text: String) -> void:
	var f := FileAccess.open(Game.slot_file(Game.slot), FileAccess.WRITE)
	f.store_string(text)
	f.close()
	for ext: String in ["bak", "tmp"]:
		if FileAccess.file_exists(Game.slot_file(Game.slot, ext)):
			DirAccess.remove_absolute(Game.slot_file(Game.slot, ext))
	Game.run = {}
	Game.load_slot(Game.slot)
