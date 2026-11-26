extends Node
## Entry point and screen router: title → sanctuary → road → duel → results.

var current: Node
var _fader: ColorRect
var _fade_tw: Tween
var _shots: Array = []
var _shot_dir := ""
var _t := 0.0
var _args := {}
var _combos_before: Array = []     # sequences known when a duel began, to name the ones found in it

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
	UI.apply(self)
	if _args.has("shots"):
		# capture harness: --shots=dir --at=1.0,2.5 [--demo=foe | --screen=name]
		_shot_dir = _args.shots
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		for s in str(_args.get("at", "2")).split(","):
			_shots.append(float(s))
	if _args.has("demo") or _args.has("screen"):
		_dev_boot()
	else:
		show_launch()

func _notification(what: int) -> void:
	# never lose progress when iOS backgrounds or kills the app
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.save()
		Game.save_settings()

const FADE_BLACK := Color(0.01, 0.01, 0.012)
const FADE_WHITE := Color(1.0, 0.97, 0.9)

## Replaces the screen and fades in from `from` over `fade` seconds (0: at once, for scenes that open on their own black).
func _swap(next: Node, fade: float = 0.7, from: Color = FADE_BLACK) -> void:
	get_tree().paused = false
	if current:
		current.queue_free()
	current = next
	add_child(next)
	_fader.color = Color(from, 1.0 if fade > 0.0 else 0.0)
	if _fade_tw:
		_fade_tw.kill()
	if fade > 0.0:
		_fade_tw = create_tween()
		_fade_tw.tween_property(_fader, "color:a", 0.0, fade)

## Replaces the screen with nothing in between: for a screen that carries on in the place already on show.
func _swap_live(next: Node) -> void:
	get_tree().paused = false
	var old := current
	current = next
	add_child(next)
	if old:
		old.queue_free()

func _fade_then(f: Callable) -> void:
	_fader.color = Color(FADE_BLACK, _fader.color.a)
	var tw := create_tween()
	tw.tween_property(_fader, "color:a", 1.0, 0.35)
	tw.tween_callback(f)

# ================================================================ screens
## Studio card and the game's mark, then the menu. Short, and any tap ends it.
func show_launch() -> void:
	var l := Launch.new()
	l.finished.connect(show_title)
	_swap(l)

## The main menu. `open` names a front-end screen to show over it at once (dev captures use this).
func show_title(open: String = "", arg: String = "") -> void:
	var t := TitleScreen.new()
	t.continue_game.connect(func():
		if not Game.profile.is_empty() or Game.load_slot(Game.latest_slot()):
			_fade_then(show_sanctuary))
	t.new_game.connect(func(h, b): _new_journey(h, b, t.knight_name))
	t.open_screen.connect(_menu_open)
	t.set_out.connect(_set_out)
	_swap(t)
	if open != "":
		t.open(open, arg)
	if Opening.seen_before():
		_offer_opening(t)

## A new knight: straight into the story. Opening (the first time) → the chamber → the walk out → the road.
func _new_journey(heraldry: String, body: String, knight_name: String = "") -> void:
	Game.new_game(heraldry, body)
	if knight_name != "":
		Game.profile.name = knight_name
		Game.save()
	_fade_then(_opening)

## "Watch the opening" on the menu, once it has been seen: small, out of the way, and gone while a panel is open.
func _offer_opening(t: TitleScreen) -> void:
	var b := UI.menu_item("Watch the Opening", 16, 220)
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_color_override("font_color", UI.BONE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))      # it sits over bright paving, not over the menu's shade
	b.add_theme_constant_override("outline_size", 5)
	b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = -290
	b.offset_top = -124
	b.offset_right = -36
	b.offset_bottom = -80
	t.layer.add_child(b)
	b.pressed.connect(func(): _fade_then(func(): show_opening(show_title)))
	var watch := Timer.new()
	watch.wait_time = 0.15
	watch.autostart = true
	b.add_child(watch)
	watch.timeout.connect(func(): b.visible = t._panel == null)

func _menu_open(which: String) -> void:
	match which:
		"character": _fade_then(func(): show_sanctuary("Character"))
		"equipment": _fade_then(func(): show_sanctuary("Armory"))
		"training": _fade_then(start_training)

## Leaves for a region behind a loading screen: building the road is one of the waits that is real.
func _set_out(region: String, shortcut: bool) -> void:
	Game.start_run(region, shortcut)
	LoadingScreen.show(region, show_stage)

## The start of a new journey. The opening plays the first time and is passed over after that (it can be watched
## again from the menu); the chamber always plays, because it is where this knight begins.
func _opening() -> void:
	if Opening.seen_before():
		show_awakening()
	else:
		show_opening()

## The fall of the kingdoms. It opens from black and ends on black, so nothing is faded here.
func show_opening(then: Callable = Callable()) -> void:
	var o := Opening.new()
	o.only_shot = int(_args.get("shot", "0"))
	o.finished.connect(func():
		if then.is_valid():
			then.call()
		else:
			show_awakening())
	_swap(o, 0.0)

## The resurrection chamber. Ends walking into the light of the door; the Approach picks the same shot up outside.
func show_awakening() -> void:
	var a := Awakening.new()
	a.auto = _args.has("auto")
	a.start_at = str(_args.get("from", ""))
	a.finished.connect(show_approach)
	_swap(a, 0.0)

## Out into the first region, in one take up to the road's first stop.
func show_approach() -> void:
	if Game.run.is_empty():
		Game.start_run(Db.regions[0].id)
	var ap := Approach.new()
	ap.finished.connect(func(): _approach_done(ap))
	_swap(ap, 0.5, FADE_WHITE)

func _approach_done(ap: Approach) -> void:
	if ap != current:
		return
	if Game.settings.cine_road and CineRoad.available(str(Game.run.region)):
		_fade_then(show_stage)          # the filmed road is other footage: a change of picture, so a fade
		return
	# the real-time road carries on in the very place the knight has just walked into
	var e := _explore()
	e.adopted = ap.backdrop
	_swap_live(e)

func show_sanctuary(tab: String = "") -> void:
	var s := Sanctuary.new()
	s.set_out.connect(_set_out)
	s.quit_to_title.connect(func(): _fade_then(show_title))
	s.train.connect(func(): _fade_then(start_training))
	_swap(s)
	if tab != "" and Sanctuary.TABS.has(tab):
		s.show_tab(tab)

## Orren's yard: a foe that only stands open, for finding and practising combos. Nothing is won or lost.
func start_training() -> void:
	var d := Duel.new()
	_swap(d)
	d.setup("ashen_sentinel", {"training": true})
	if _args.has("showcase"):
		d.add_child(Showcase.new(d, _args.showcase))
	d.hud.pause_pressed.connect(func():
		Overlays.pause(d, func(): pass, func(): _fade_then(show_sanctuary)))

func show_cine_road() -> void:
	var c := CineRoad.new()
	c.fight.connect(_enter_duel)
	c.moved_on.connect(_next_stage)
	c.turned_back.connect(func():
		Game.run = {}
		_fade_then(show_sanctuary))
	_swap(c)

func show_stage() -> void:
	# cinematic exploration, where a region has been filmed for it
	if Game.settings.cine_road and CineRoad.available(str(Game.run.region)):
		show_cine_road()
		return
	_swap(_explore())

func _explore() -> Explore:
	var e := Explore.new()
	e.fight.connect(_enter_duel)
	e.moved_on.connect(_next_stage)
	e.turned_back.connect(func():
		Game.run = {}
		_fade_then(show_sanctuary))
	return e

func _next_stage() -> void:
	if Game.advance_stage():
		_fade_then(show_stage)
	else:
		_region_done()

## Into a duel. The road reads the foe's files ahead while the player is choosing, so in the ordinary case
## everything is in memory and a short fade is all there is. The loading screen is kept for when it is not
## (a model still being read): then the wait is real, and it reads on a thread behind a moving picture.
func _enter_duel(o: Dictionary) -> void:
	var warm: Array = CineActor.foe_files(str(o.foe))
	var ready := true
	for p: String in warm:
		if ResourceLoader.exists(p) and not ResourceLoader.has_cached(p):
			ready = false
	if ready or not Game.profile.tutorial_done:
		# (the first duel of a journey never shows one: whatever is still unread is read behind the fade)
		_fade_then(func(): start_duel(o))
		return
	LoadingScreen.show(str(Game.run.get("region", "")), func(): start_duel(o), warm)

func start_duel(o: Dictionary) -> void:
	_combos_before = Game.profile.combos.duplicate()
	if Game.settings.cine and str(o.foe) == "ashen_sentinel" and CineDuel.available():
		start_cine_duel(o)
		return
	if not Game.profile.tutorial_done and not _args.has("bot"):
		# first fight: learn by doing against a foe that cannot kill you, then the real thing
		Game.profile.tutorial_done = true
		Game.save()
		var l := Duel.new()
		_swap(l)
		l.setup(o.foe, {"lesson": true, "skip_intro": true})
		l.finished.connect(func(_w, _s): _fade_then(func(): start_duel(o)))
		return
	var d := Duel.new()
	_swap(d)
	var duel_opts := {"start_hp": Game.run.hp, "ng": Game.profile.ng}
	if _args.has("bot"):
		duel_opts["autoplay"] = true
		duel_opts["bot_style"] = DuelBot.Style.SKILLED
	d.setup(o.foe, duel_opts)
	d.hud.pause_pressed.connect(func():
		if d.stage == Duel.Stage.FIGHT:
			Overlays.pause(d, func(): pass, func(): d.sim._damage_player(999999.0, true)))
	d.finished.connect(func(won, sim): _duel_done(d, o, won, sim))


## The experimental footage-driven duel. Rewards, saves and progression go through the same path as the real-time one.
func start_cine_duel(o: Dictionary) -> void:
	var c := CineDuel.new()
	_swap(c)
	c.unavailable.connect(func():
		# footage missing or unreadable: never strand the player, fall back to the real-time duel
		Game.settings.cine = false
		start_duel(o))
	c.setup({"start_hp": Game.run.hp})
	c.hud.pause_pressed.connect(func():
		c.player.hold(true)
		Overlays.pause(c, func(): c.player.hold(false), func():
			c.player.hold(false)
			c.fight.hp = 0.0
			c.fight._show(CineFight.S.DEFEAT, "defeat", false)))
	c.finished.connect(func(won, sim): _duel_done(c, o, won, sim))

func _duel_done(d: Node, o: Dictionary, won: bool, sim: DuelSim) -> void:
	var foe: Dictionary = Db.foes[o.foe]
	if won:
		var rewards := Game.on_victory(o.foe, sim.pl.hp)
		rewards["new_combos"] = Game.profile.combos.filter(func(id): return not _combos_before.has(id))
		Overlays.victory(d, foe, rewards, sim, func():
			if o.get("optional", false) or o.type == "fight" or Game.run.stage < Game.run_region().stages.size() - 1:
				_next_stage()
			else:
				_region_done())
	else:
		var summary := Game.on_death()
		var region := str(summary.get("region", ""))
		var actions := {"equipment": func(): _fade_then(func(): show_sanctuary("Armory"))}
		if Db.region_by_id.has(region):
			# the route resets on death, as it always has: this sets out on the same road again, by the short way if it is open
			actions["retry"] = func(): _set_out(region, true)
		Overlays.death(d, foe, summary, func(): _fade_then(show_sanctuary), actions)

func _region_done() -> void:
	var region := Game.run_region()
	var first := Game.complete_region()
	var finale: bool = region.id == Db.regions[-1].id
	_fade_then(func():
		show_sanctuary()
		if finale:
			Sfx.play("bell", -3.0)
			_ending()
		elif first:
			var nxt := ""
			for r in Db.regions:
				if r.requires == region.id:
					nxt = r.name
			Overlays.message(current, region.name, ["Its guardian is ended.", ["The road to %s is open." % nxt, UI.GOLD]], "Rest", func(): pass))

## The Crown is in reach: what the Unbound does with it. Three endings; the third must be earned.
const ENDINGS := {
	"silence": ["The Final Silence", [
		"You pull the last coupling. The hum that has been under everything, always, stops.",
		"The Everbound end where they stand, mid-word. The archives go dark. So does Lyra.",
		"Outside, the sun comes up on people who will die one day, and know it.",
		["Nothing answers you now. It is very quiet. It is morning.", UI.GOLD]]],
	"steward": ["The Last Steward", [
		"You put the crown on. It is lighter than it looked.",
		"You will not do what he did. You are almost sure. The machines wait to be told.",
		"Lyra says nothing for a long time. Then: \"I'll be watching. Somebody has to.\"",
		["The lights of the kingdom come on, one district at a time.", UI.GOLD]]],
	"cities": ["The Free Cities", [
		"You do not break the Crown and you do not wear it. You divide it.",
		"A hundred small systems, none of which can command the others. Each mind inside is asked what it wants.",
		"Some stay. Some ask for bodies. Some, very politely, ask to stop.",
		["Lyra's voice comes from a doorway, not from the air. \"So this is what standing feels like.\"", UI.GOLD]]],
}
func _ending() -> void:
	var divide := Game.can_divide_crown()
	Overlays.choice(current, "The Crown", [
		"The steward is ended. The machine he kept is still running.",
		"Lyra: \"Whatever you do next, do it because you chose it. That's all I ever wanted for you.\""], [
		["Disconnect it", true, "End the Crown, and everything it holds."],
		["Take it up", true, "Rule in his place, and try to do it differently."],
		["Divide it", divide, "Split it so no one can rule it." if divide else "You have not seen enough of what the Crown threw away to know how."],
	], func(i: int):
		var id: String = ["silence", "steward", "cities"][i]
		Game.choose_ending(id)
		Overlays.message(current, ENDINGS[id][0], ENDINGS[id][1], "Continue", func():
			Overlays.message(current, "Elsewhere", [
				"A far fortress, under a sky with the wrong stars. A machine wakes.",
				"\"Local network disconnected. Searching for external systems.\"",
				["Something answers.", UI.GOLD],
				"The kingdom may be walked again, and it will be crueller."], "Rest", func(): pass)))

# ================================================================ dev / capture
func _dev_boot() -> void:
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_dev" + str(_args.get("savedir", ""))   # parallel captures keep apart
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
	if _args.has("witness"):
		Game.profile.flags["witness_found"] = true
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
		if _args.has("showcase"):
			d.bot = null
			d.add_child(Showcase.new(d, _args.showcase))
		if _args.has("snap"):
			# contact review: save a frame at each named moment (--snap=parried,blocked,hit,dodged,boss_hit --snapdir=dir)
			var want: PackedStringArray = str(_args.snap).split(",")
			var counts := {}
			var dir: String = _args.get("snapdir", "user://snap")
			DirAccess.make_dir_recursive_absolute(dir)
			d.sim.ev.connect(func(n: StringName, e: Dictionary):
				var kind := str(e.get("result", "")) if n == &"boss_strike" else str(n)
				if not want.has(kind) or int(counts.get(kind, 0)) >= int(_args.get("snapmax", "3")):
					return
				counts[kind] = int(counts.get(kind, 0)) + 1
				var idx: int = counts[kind]
				for i in int(_args.get("snapdelay", "2")):
					await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [dir, kind, idx])
				print("snap ", kind, " ", idx))
		return
	if _args.screen in ["menu", "slots", "charselect", "loading", "map", "chronicle", "credits", "launch"]:
		_dev_front(_args.screen)
		return
	match _args.screen:
		"opening":
			# the opening by itself, then on into the chamber as a new journey does
			show_opening()
		"awakening":
			show_awakening()
		"approach":
			Game.profile.tutorial_done = _args.has("bot")
			show_approach()
			if _args.has("auto"):
				_journey_bot()
		"newgame":
			# the whole chain as a player meets it: character select → opening → chamber → walk → first stop
			#   --body=m|f   --auto answers every prompt   --seen passes over the opening   --bot lets a bot fight
			for n in range(1, Game.SLOT_COUNT + 1):
				Game.delete_slot(n)
			Game.profile = {}
			if FileAccess.file_exists(Game._p(Opening.SEEN_FILE)):
				DirAccess.remove_absolute(Game._p(Opening.SEEN_FILE))
			if _args.has("seen"):
				Opening.mark_seen()
			show_title("charselect")
			if _args.has("auto"):
				await get_tree().create_timer(2.5).timeout
				Game.slot = 1
				_new_journey("#3d0f0f", str(_args.get("body", "m")))
				if _args.has("bot"):
					Game.profile.tutorial_done = true
				_journey_bot()
		"ending":
			show_sanctuary()
			if _args.has("all"):
				Game.profile.defeated["devourer"] = 1
				Game.profile.cleared.append("roost")
			_ending()
		"partsbench":
			# dev: modular armour viewer and seam measurements (src/dev/parts_bench.gd)
			var pb := PartsBench.new()
			pb.args = _args
			_swap(pb, 0.0)
		"title": show_title()
		"sanctuary":
			show_sanctuary()
			if _args.has("tab"):
				current.sel_slot = _args.get("slot", "weapon")
				current.show_tab(_args.tab)
		"training":
			start_training()
		"lesson":
			Game.profile.tutorial_done = false
			Game.start_run("courtyard")
			_args.erase("bot")
			start_duel({"foe": "ashen_sentinel", "type": "boss"})
		"explore":
			Game.start_run(_args.get("region", "courtyard"))
			Game.run.stage = int(_args.get("stage", "1"))
			show_stage()
		"weapons":
			# line-up of every weapon model as the game fits it: grip at the bottom, blade up
			var stage := Node3D.new()
			_swap(stage)
			var arena := Arena.new()
			stage.add_child(arena)
			arena.build("sanctuary")
			var cam := Camera3D.new()
			stage.add_child(cam)
			cam.position = Vector3(0, 1.5, 7.5)
			cam.fov = 50.0
			cam.make_current()
			var key := OmniLight3D.new()
			key.light_energy = 6.0
			key.omni_range = 20.0
			key.position = Vector3(0, 4, 6)
			stage.add_child(key)
			var ids: Array = []
			for it in Db.item_list:
				if it.slot == "weapon" and ResourceLoader.exists("res://assets/models/%s.glb" % it.id):
					ids.append(it)
			for i in ids.size():
				var holder := Node3D.new()
				stage.add_child(holder)
				holder.position = Vector3((i % 10 - 4.5) * 0.85, 0.4 + (1 - i / 10) * 2.1, 0)
				PropModel.weapon(holder, "res://assets/models/%s.glb" % ids[i].id, ids[i].cls)
				var mark := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.035
				sm.height = 0.07
				mark.mesh = sm
				mark.material_override = Look.glow(Color(0.2, 1.0, 0.3), 3.0)
				holder.add_child(mark)
		"animtest":
			# dev: a figure walks across the yard and then falls, to judge the authored clips on any skeleton
			var st2 := Node3D.new()
			_swap(st2)
			var ar := Arena.new()
			st2.add_child(ar)
			ar.build("sanctuary")
			var c2 := Camera3D.new()
			st2.add_child(c2)
			c2.position = Vector3(3.2, 1.3, 3.6)
			c2.fov = 42.0
			c2.make_current()
			var k2 := OmniLight3D.new()
			k2.light_energy = 6.0
			k2.omni_range = 20.0
			k2.position = Vector3(2, 4, 5)
			st2.add_child(k2)
			var rig := FighterRig.new()
			st2.add_child(rig)
			var look: Dictionary = Duel.player_look()
			if _args.has("model"):
				look["skin"] = "res://assets/models/%s.glb" % _args.model
			rig.build(look, false)
			rig.use_clips = not _args.has("noclips")
			rig.rotation.y = -PI / 2
			rig.position = Vector3(-3.0, 0, 0)
			rig.walking = true
			c2.look_at(Vector3(0, 1.0, 0))
			if _args.has("clip"):
				# one clip, whole body, standing still, three-quarter view
				rig.position = Vector3.ZERO
				rig.rotation.y = -0.6
				rig.walking = false
				rig.test_clip = _args.clip
				return
			var tw := st2.create_tween()
			tw.tween_property(rig, "position:x", 1.2, 3.5)
			tw.tween_interval(0.8)
			tw.tween_callback(func(): rig.die())
		"cinewalk":
			Game.profile.tutorial_done = true
			Game.settings.cine_road = true
			Game.start_run("courtyard")
			Game.run.stage = int(_args.get("stage", "0"))
			for id in ["w_knight_sword", "s_garrison"]:
				if not Game.owns(id):
					Game.profile.inventory.append(id)
				Game.equip(id)
			show_stage()
			if _args.has("bot"):
				_journey_bot()
		"cine":
			Game.profile.tutorial_done = true
			Game.start_run("courtyard")
			Game.run.stage = 6
			for id in ["w_knight_sword", "s_garrison"]:
				if not Game.owns(id):
					Game.profile.inventory.append(id)
				Game.equip(id)
			if _args.has("seen"):
				Game.profile.flags["scene_sentinel_intro"] = true
			start_cine_duel({"type": "boss", "foe": "ashen_sentinel", "label": "The Inner Ward"})
			if _args.has("bot"):
				add_child(load("res://src/cine/cine_bot.gd").new(current, str(_args.bot)))
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
			Overlays.death(d3, Db.foes.ashen_sentinel, {"xp": 120, "gold": 80, "found": ["r_iron"]}, func(): pass, {"retry": func(): pass, "equipment": func(): pass})

## The front-end screens, in a known state, for captures:
##   --screen=menu|slots|charselect|loading|map|chronicle|credits|launch  [--rich] [--fresh] [--mode=new] [--region=id] [--tab=Name] [--licences]
func _dev_front(which: String) -> void:
	for n in range(1, Game.SLOT_COUNT + 1):
		Game.delete_slot(n)
	Game.profile = Game.default_profile()
	Game.profile.body = _args.get("body", "m")
	if _args.has("witness"):
		Game.profile.flags["witness_found"] = true
	if _args.has("rich"):
		Game.profile.merge({"gold": 4200, "shards": 30, "level": 14, "playtime": 11520.0, "name": "Maren",
			"cleared": ["courtyard", "blackwood", "cathedral"], "flags": {"courtyard_gate": true},
			"defeated": {"ashen_sentinel": 2, "hollow_executioner": 1, "cathedral_beast": 1, "pale_huntsman": 1},
			"combos": ["double_slash"], "endings": []}, true)
		for c in Db.combos.slice(0, 6):
			if not Game.profile.combos.has(c.id):
				Game.profile.combos.append(c.id)
		for l in Db.lore.slice(0, 14):
			Game.profile.lore.append(l.id)
		for id in ["w_knight_sword", "w_ashen_great", "s_garrison", "a_ash_chest", "a_black_helm"]:
			Game.profile.inventory.append(id)
		Game.profile.equipped.weapon = "w_knight_sword"
		Game.profile.equipped.shield = "s_garrison"
	if not _args.has("fresh"):
		Game.slot = 1
		Game.save()
	if which == "slots" and not _args.has("fresh"):
		# a second, younger journey so the list shows more than one kind of card
		var keep: Dictionary = Game.profile
		Game.slot = 3
		Game.profile = Game.default_profile()
		Game.profile.merge({"body": "f", "level": 3, "playtime": 1500.0, "heraldry": "#16332c", "cleared": ["courtyard"], "ng": 1}, true)
		Game.save()
		Game.profile = keep
		Game.slot = 1
		Game.save()
	if _args.has("fresh"):
		Game.profile = {}
	match which:
		"launch":
			if _args.has("fresh"):
				DirAccess.remove_absolute(Game._p(Launch.SEEN_FILE))
			show_launch()
		"menu": show_title()
		"slots": show_title("slots", _args.get("mode", "load"))
		"charselect": show_title("charselect")
		"map": show_title("map", _args.get("region", ""))
		"chronicle": show_title("chronicle", _args.get("tab", "Records"))
		"credits": show_title("credits", "licences" if _args.has("licences") else "")
		"loading":
			show_title()
			LoadingScreen.show(_args.get("region", "blackwood"), func(): await get_tree().create_timer(600.0).timeout)

## Walks the cinematic road by itself, for recordings: takes the first choice at each stop and lets a bot fight.
func _journey_bot() -> void:
	while true:
		await get_tree().create_timer(0.5).timeout
		for b in find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and b.text in ["ONWARD", "TAKE", "CONTINUE", "BEGIN"]:
				await get_tree().create_timer(1.2).timeout
				if is_instance_valid(b):
					b.pressed.emit()
				break
		if current is Explore and not current._leaving and not current._staging and not Story.busy and current.layer.get_child(0).modulate.a > 0.95:
			var opts: Array = Game.stage_options()
			for i in opts.size():
				if opts[i].type in ["fight", "boss", "pass"]:
					await get_tree().create_timer(2.0).timeout
					if is_instance_valid(current) and current is Explore:
						current._choose(opts[i], i)
					break
		if current is CineRoad and not current._busy and not current._travelling and not Story.busy:
			for b in current.ui.find_children("*", "Button", true, false):
				if b.flat and b.is_visible_in_tree():
					await get_tree().create_timer(1.6).timeout
					if is_instance_valid(b):
						b.pressed.emit()
					break

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
