extends Node
## Entry point and screen router: title → sanctuary → road → duel → results.

var current: Node
var _fader: ColorRect
var _fade_tw: Tween
var _shots: Array = []
var _shot_dir := ""
var _t := 0.0
var _args := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var fl := CanvasLayer.new()
	fl.layer = 50
	add_child(fl)
	_fader = UI.full(ColorRect.new())
	_fader.color = Color(0.01, 0.01, 0.012, 1.0)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(_fader)
	if _args.has("shots"):
		# capture harness: --shots=dir --at=1.0,2.5 [--demo=foe | --screen=name]
		_shot_dir = _args.shots
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		for s in str(_args.get("at", "2")).split(","):
			_shots.append(float(s))
	if _args.has("demo") or _args.has("screen"):
		_dev_boot()
	else:
		show_title()

func _notification(what: int) -> void:
	# never lose progress when iOS backgrounds or kills the app
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.save()
		Game.save_settings()

func _swap(next: Node) -> void:
	get_tree().paused = false
	if current:
		current.queue_free()
	current = next
	add_child(next)
	_fader.color.a = 1.0
	if _fade_tw:
		_fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_property(_fader, "color:a", 0.0, 0.7)

func _fade_then(f: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(_fader, "color:a", 1.0, 0.35)
	tw.tween_callback(f)

# ================================================================ screens
func show_title() -> void:
	var t := TitleScreen.new()
	t.continue_game.connect(func():
		if Game.load_game():
			_fade_then(show_sanctuary))
	t.new_game.connect(func(h, b):
		Game.new_game(h, b)
		_fade_then(_opening))
	_swap(t)

func _opening() -> void:
	# darkness and the narrator; then the chamber, and a voice in the walls
	show_sanctuary()
	var s: Sanctuary = current
	s.layer.visible = false
	s.backdrop.move_camera(Vector3(0.4, 1.0, 1.6), Vector3(1.0, 1.5, 0), true)
	if _fade_tw:
		_fade_tw.kill()
	_fader.color.a = 1.0
	Sfx.music_for("theme", "menu")
	await get_tree().create_timer(1.2).timeout
	await Story.play("opening")
	create_tween().tween_property(_fader, "color:a", 0.0, 2.5)
	s.backdrop.move_camera(Vector3(2.5, 1.45, 3.4), Vector3(1.15, 1.05, 0))
	await get_tree().create_timer(1.6).timeout
	await Story.play("awakening")
	await Story.play("first_road")
	if is_instance_valid(s):
		s.layer.visible = true
		Sfx.music_for("hub", "sanctuary")

func show_sanctuary() -> void:
	var s := Sanctuary.new()
	s.set_out.connect(func(region, shortcut):
		Game.start_run(region, shortcut)
		_fade_then(show_stage))
	s.quit_to_title.connect(func(): _fade_then(show_title))
	_swap(s)

func show_stage() -> void:
	var e := Explore.new()
	e.fight.connect(func(o): _fade_then(func(): start_duel(o)))
	e.moved_on.connect(_next_stage)
	e.turned_back.connect(func():
		Game.run = {}
		_fade_then(show_sanctuary))
	_swap(e)

func _next_stage() -> void:
	if Game.advance_stage():
		_fade_then(show_stage)
	else:
		_region_done()

func start_duel(o: Dictionary) -> void:
	var d := Duel.new()
	_swap(d)
	d.setup(o.foe, {"start_hp": Game.run.hp, "ng": Game.profile.ng})
	d.hud.pause_pressed.connect(func():
		if d.stage == Duel.Stage.FIGHT:
			Overlays.pause(d, func(): pass, func(): d.sim._damage_player(999999.0, true)))
	d.finished.connect(func(won, sim): _duel_done(d, o, won, sim))
	if not Game.profile.tutorial_done:
		Game.profile.tutorial_done = true
		d.set_process(false)
		Overlays.message(d, "The Old Lessons", [
			"Swipe to cut — but only when your foe is open. A raised guard turns every blow.",
			"Swipe against an incoming strike to parry it. The ring closes as the blow lands.",
			"The arrows step aside. The shield holds, while your stamina lasts.",
			"When a foe is open, a bright seam shows in its guard. Cut along it.",
			["A perfect parry breaks their guard. That is your moment.", UI.GOLD]], "Begin", func(): d.set_process(true))

func _duel_done(d: Duel, o: Dictionary, won: bool, sim: DuelSim) -> void:
	var foe: Dictionary = Db.foes[o.foe]
	if won:
		var rewards := Game.on_victory(o.foe, sim.pl.hp)
		Overlays.victory(d, foe, rewards, sim, func():
			if o.get("optional", false) or o.type == "fight" or Game.run.stage < Game.run_region().stages.size() - 1:
				_next_stage()
			else:
				_region_done())
	else:
		var summary := Game.on_death()
		Overlays.death(d, foe, summary, func(): _fade_then(show_sanctuary))

func _region_done() -> void:
	var region := Game.run_region()
	var first := Game.complete_region()
	var finale: bool = region.id == Db.regions[-1].id
	_fade_then(func():
		show_sanctuary()
		if finale:
			Sfx.play("bell", -3.0)
			Overlays.message(current, "The Throne Is Empty", [
				"The crown lies where it fell. Nobody reaches for it.",
				"Outside, for the first time in an age, it begins to rain.",
				"You wake in the sanctuary. The candle is still burning.",
				["The kingdom may be walked again, and it will be crueller.", UI.GOLD]], "Rest", func(): pass)
		elif first:
			var nxt := ""
			for r in Db.regions:
				if r.requires == region.id:
					nxt = r.name
			Overlays.message(current, region.name, ["Its guardian is ended.", ["The road to %s is open." % nxt, UI.GOLD]], "Rest", func(): pass))

# ================================================================ dev / capture
func _dev_boot() -> void:
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_dev"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	Game.profile = Game.default_profile()
	if _args.has("rich"):
		Game.profile.gold = 4200
		Game.profile.shards = 30
		Game.profile.level = 14
		Game.profile.attr_points = 3
		Game.profile.cleared = ["courtyard", "blackwood", "cathedral"]
		Game.profile.flags = {"courtyard_gate": true}
		Game.profile.defeated = {"ashen_sentinel": 1, "hollow_executioner": 1, "cathedral_beast": 1}
		for id in ["w_knight_sword", "w_ashen_great", "w_headsman", "w_twin_fangs", "w_censer_sword", "s_garrison", "s_tower", "a_ash_chest", "a_black_helm", "a_vigil_chest", "a_garrison_legs", "r_ember", "x_bell"]:
			Game.profile.inventory.append(id)
	Game.profile.body = _args.get("body", "m")
	for id in str(_args.get("gear", "")).split(",", false):
		if not Game.owns(id):
			Game.profile.inventory.append(id)
		Game.equip(id)
	if _args.has("demo"):
		Game.profile.tutorial_done = true
		var d := Duel.new()
		_swap(d)
		d.setup(_args.demo, {"autoplay": true, "seed": int(_args.get("seed", "3")), "skip_intro": _args.has("skip_intro"), "bot_style": int(_args.get("bot", "3"))})
		d.finished.connect(func(won, _s): print("duel finished won=", won))
		return
	match _args.screen:
		"title": show_title()
		"sanctuary":
			show_sanctuary()
			if _args.has("tab"):
				current.sel_slot = _args.get("slot", "weapon")
				current.show_tab(_args.tab)
		"explore":
			Game.start_run(_args.get("region", "courtyard"))
			Game.run.stage = int(_args.get("stage", "1"))
			show_stage()
		"victory":
			Game.start_run("courtyard")
			var d2 := Duel.new()
			_swap(d2)
			d2.setup("ashen_sentinel", {"skip_intro": true})
			d2.set_process(false)
			Overlays.victory(d2, Db.foes.ashen_sentinel, Game.on_victory("ashen_sentinel", 60.0), d2.sim, func(): pass)
		"death":
			Game.start_run("courtyard")
			var d3 := Duel.new()
			_swap(d3)
			d3.setup("ashen_sentinel", {"skip_intro": true})
			d3.sim._damage_player(99999.0, true)
			Overlays.death(d3, Db.foes.ashen_sentinel, {"xp": 120, "gold": 80, "found": ["r_iron"]}, func(): pass)

func _process(delta: float) -> void:
	if _shot_dir == "":
		return
	_t += delta
	if not _shots.is_empty() and _t >= _shots[0]:
		var t: float = _shots.pop_front()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%04.1f.png" % [_shot_dir, _args.get("name", "shot"), t])
		print("render t=%.1f draw_calls=%d primitives=%d objects=%d video_mem=%.1fMB nodes=%d" % [t,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		if _shots.is_empty():
			get_tree().quit()
