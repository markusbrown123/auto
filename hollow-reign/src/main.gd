extends Node
## Entry point and screen router: title → sanctuary → road → duel → results.

var current: Node
var _fader: ColorRect
var _fade_tw: Tween
var _shots: Array = []
var _shot_dir := ""
var _t := 0.0
var _args := {}
var parked: Explore               # the Courtyard's road, held under a duel fought where it was met (Stage 3B)
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
	if _args.has("notch"):
		for v: String in str(_args.notch).split(","):
			UI.fake_insets.append(float(v))
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
	# a call, a notification pulled down, the app switcher: a fight in progress stops and waits (phones only, so a
	# desktop capture that loses focus is not paused)
	if (what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT) and OS.has_feature("mobile"):
		pause_fight()

## Opens the pause screen over a fight in progress, exactly as its pause button does. Nothing happens anywhere else.
func pause_fight() -> bool:
	if current == null or not is_instance_valid(current) or get_tree().paused:
		return false
	var d = current if current is Duel else current.get("duel")
	if d == null or not is_instance_valid(d) or not d is Duel or d.stage != Duel.Stage.FIGHT or d.sim.over:
		return false
	d.hud.pause_pressed.emit()
	return get_tree().paused

const FADE_BLACK := Color(0.01, 0.01, 0.012)
const FADE_WHITE := Color(1.0, 0.97, 0.9)

## Replaces the screen and fades in from `from` over `fade` seconds (0: at once, for scenes that open on their own black).
func _swap(next: Node, fade: float = 0.7, from: Color = FADE_BLACK) -> void:
	get_tree().paused = false
	if current and current != parked:
		current.queue_free()
	_let_road_go(next)
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
	if old and old != parked:
		old.queue_free()
	_let_road_go(next)

## A road held under a duel goes once the next screen is anything but a duel fought on it.
func _let_road_go(next: Node) -> void:
	if parked != null and is_instance_valid(parked) and not next is Duel and next != parked:
		parked.queue_free()
		parked = null

## The road the duel is being fought on, as the duel is to take it up: where (the duel's frame), in what place (the
## road's arena), and the camera it comes from. Empty: not fought on the road.
func _in_place() -> Dictionary:
	if parked == null or not is_instance_valid(parked) or parked.meeting.is_empty():
		return {}
	var p: Dictionary = parked.meeting.duplicate()
	var c := get_viewport().get_camera_3d()
	if c:
		p["cam"] = c.global_transform
		p["fov"] = c.fov
	return p

## Back onto the road from a duel won on it: the same place, the knight walks on from where it stood.
func _resume_road() -> void:
	var d := current
	var e := parked
	_cross_then(func():
		parked = null
		current = e
		get_tree().paused = false
		e.unpark(d)
		if is_instance_valid(d) and d != e:
			d.queue_free()
		e.travel(), 0.5)

## A dissolve from the frame on screen to whatever `f` puts up, with no black between: for the continuous Courtyard,
## whose road and duels are the same place (the frame is held as a picture and faded off the new one).
func _cross_then(f: Callable, secs: float = 0.7) -> void:
	if DisplayServer.get_name() == "headless":
		f.call()
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var cl := CanvasLayer.new()
	cl.layer = 49
	add_child(cl)
	var tr := UI.full(TextureRect.new())
	tr.texture = ImageTexture.create_from_image(img)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(tr)
	f.call()
	if _fade_tw:
		_fade_tw.kill()
	_fader.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(tr, "modulate:a", 0.0, secs).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(cl.queue_free)

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
			_fade_then(resume))
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
	Game.new_game(heraldry, body, CharacterSelect.start_weapon)
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
	b.pressed.connect(func(): _fade_then(func(): show_prologue(show_title)))
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
	Explore.arrive = {"shortcut": true} if shortcut and int(Game.run.stage) > 0 else {}
	LoadingScreen.show(region, show_stage)

## The start of a new journey. The opening plays the first time and is passed over after that (it can be watched
## again from the menu); the chamber always plays, because it is where this knight begins.
func _opening() -> void:
	if Opening.seen_before():
		show_awakening()
	else:
		show_prologue()

## The high road, climbed twice before this knight wakes (src/cine/prologue.gd). It opens from black and ends on black.
func show_prologue(then: Callable = Callable()) -> void:
	var p := Prologue.new()
	p.auto = _args.has("auto")
	p.start_beat = int(_args.get("beat", "1"))
	p.only_shot = int(_args.get("shot", "0"))
	p.finished.connect(func():
		if then.is_valid():
			then.call()
		else:
			show_time_jump(22, 1, 2, show_arrival))
	_swap(p, 0.0)

## Years pass on the one view of the fortress (src/cine/time_jump.gd). Needed again after the second generation.
func show_time_jump(years: int, from_gen: int, to_gen: int, then: Callable) -> void:
	var t := TimeJump.make(years, from_gen, to_gen)
	t.finished.connect(then)
	_swap(t, 0.0)

## The next of the house comes up the road (src/cine/arrival.gd), and goes down to the Inheritance Engine: the second
## generation to wake at it, the third to walk in and find what was kept for them.
func show_arrival() -> void:
	var a := Arrival.new()
	a.only_shot = int(_args.get("shot", "0"))
	if not Game.profile.is_empty() and Game.generation() >= 3:
		a.gen = 3
		a.line_scene = "gen3_arrive"
		a.show_name = false
		a.card_text = "VAELORA   ·   THE LAST HEIR"
		a.finished.connect(show_heir_return)
	else:
		a.finished.connect(show_awakening)
	_swap(a, 0.0)

# ================================================================ the generations (docs/FLOW.md, "The second fall and the Last Heir")
## Continue: the sanctuary, unless the save stands between two beats of the family's story, in which case the story
## is taken up where it was left.
func resume() -> void:
	KeptScene.sync_edge()
	Explore.arrive = {}
	var p: Dictionary = Game.profile
	var tr: Dictionary = Game.transition_pending()
	if not tr.is_empty():
		# someone has fallen and nobody has yet taken up the road: the years, then whoever is next
		if int(tr.get("from", 2)) == 1:
			show_time_jump(22, 1, 2, func():
				Game.inherit()
				show_arrival())
		else:
			show_time_jump(24, 2, 3, show_heir)
		return
	if Generations.canon_open(p):
		var m2: Dictionary = Game.monarch(2).get("record", {})
		if Game.generation() == 2 and (bool(m2.get("won", false)) or str(m2.get("choice", "")) == "records"):
			# the second meeting was decided (he was beaten, or the seal was chosen) and the fall was not reached
			show_second_fall(bool(m2.get("won", false)), str(m2.get("choice", "press")))
			return
		if Game.generation() == 3 and not p.flags.has("gen3_arrived"):
			show_arrival()
			return
		if Game.has_fact("monarch_felled:3") and not p.flags.has("facility_seen"):
			show_aftermath()
			return
	if Game.resume_road():
		show_stage()                # the app was ended on the road: back at the last stop reached (Game.save keeps it)
		return
	show_sanctuary()

## Which of the story's own fights this is, for the family's canon only: "monarch2" (the second meeting), "kept",
## "monarch3" (the last), or "" for every ordinary duel and for anything fought on a legacy journey.
func story_kind(foe_id: String) -> String:
	if Game.profile.is_empty() or not Generations.canon_open(Game.profile):
		return ""
	if foe_id == str(Generations.data().echo.id):
		return "" if Game.profile.flags.has("kept_released") else "kept"
	match Encounters.monarch_of(foe_id, Game.profile):
		2: return "monarch2"
		3: return "monarch3"
	return ""

## How many marks of the seal the last heir has to break: nine with nothing inherited, fewer for every record held.
func seal_need() -> int:
	var held := 0
	for r: Dictionary in Game.inheritance():
		held += 1 if r.held else 0
	return clampi(9 - held, 2, 9)

func _story_opts(kind: String, opts: Dictionary) -> void:
	match kind:
		"monarch2":
			var th: Dictionary = Game.monarch(2).get("threshold", {"phase": 2})
			opts["beat_at"] = [1, int(th.get("phase", 2))]
			opts["beat_hp"] = 0.22
			opts["story"] = {"pre_scene": "monarch_blade", "quiet_end": true}
		"kept":
			opts["story"] = {"yield": true, "quiet_end": true}
		"monarch3":
			opts["seal"] = {"phase": 2, "need": int(_args.get("seal", str(seal_need())))}

func _story_hooks(kind: String, d: Duel, o: Dictionary) -> void:
	match kind:
		"monarch2":
			d.beat_hook = func(ev: Dictionary): await _records_choice(d, ev)
			d.interrupted.connect(func(_how: String, _sim: DuelSim):
				# the seal was chosen: the duel is neither won nor lost, and the generation ends at the seal
				_fade_then(func(): show_second_fall(false, "records")))
		"monarch3":
			FinalHall.dress(d.arena, d.sim)

## The second meeting, at its threshold (the third phase beginning, or the knight near falling): the seal behind the
## throne is burning. Press the attack, or save the records. Asked once in a fight; the fight is held while it is.
func _records_choice(d: Duel, ev: Dictionary) -> void:
	if (int(ev.get("phase", 1)) < 2 and not ev.get("low", false)) or d.has_meta("asked"):
		return
	d.set_meta("asked", true)
	var picked: Array = [str(_args.get("choice", "")) if _args.has("bot") else ""]
	if picked[0] == "" and _args.has("bot"):
		picked[0] = "press"
	if picked[0] == "":
		Overlays.choice(d, "The Seal Is Burning", [
			"Behind the throne, the seal on the records has caught. What the first of your house could not carry out is in it.",
			"Lyra: \"I can hold it open. Not for long, and not while you are fighting him.\""], [
			["Press the attack", true, "Stay in the fight. He can be beaten."],
			["Save the records", true, "Go to the seal. The fight ends here, and so does this road. Nothing your house has earned is lost."],
		], func(i: int): picked[0] = ["press", "records"][i])
		while picked[0] == "" and is_instance_valid(d) and d.is_inside_tree():
			await get_tree().process_frame
	if not is_instance_valid(d) or not d.is_inside_tree() or picked[0] == "":
		return
	Game.record_monarch(2, {"choice": picked[0]})
	if picked[0] == "records":
		d.sim._story_end("records")

## A story fight that was won. True when the story has taken what follows (no ordinary victory flow).
func _story_won(kind: String, d: Node, o: Dictionary, sim: DuelSim) -> bool:
	var foe: Dictionary = Db.foes[o.foe]
	match kind:
		"monarch2":
			# he was beaten, and the player is told so: the win is recorded, the rewards are real and shown.
			# Then the hall's machines stand him up again, and the seal is all that is left to do.
			var rewards := Game.on_victory(o.foe, sim.pl.hp)
			rewards["new_combos"] = Game.profile.combos.filter(func(id): return not _combos_before.has(id))
			Overlays.victory(d, foe, rewards, sim, func():
				_fade_then(func(): show_second_fall(true, str(Game.monarch(2).get("record", {}).get("choice", "press")))))
			return true
		"kept":
			var rewards2 := Game.on_victory(o.foe, sim.pl.hp)
			rewards2["new_combos"] = Game.profile.combos.filter(func(id): return not _combos_before.has(id))
			_fade_then(func(): show_kept("after", func():
				# what it gave is shown with the rest of what was won, and then the road goes on as after any guardian
				var given: Array = current.granted if current is KeptScene else []
				for id: String in given:
					if id != "" and not rewards2.items.has(id):
						rewards2.items.append(id)
				var stand := Node.new()
				_swap(stand, 0.0)
				_fader.color.a = 0.0
				Overlays.victory(stand, foe, rewards2, sim, func(): _region_done())))
			return true
		"monarch3":
			var rewards3 := Game.on_victory(o.foe, sim.pl.hp)
			if not Game.run.is_empty():
				Game.complete_region()
			if Game.profile.flags.has("facility_seen"):
				# met again after the door was found: an ordinary victory, and the Crown is still waiting
				Overlays.victory(d, foe, rewards3, sim, func(): _fade_then(func():
					show_sanctuary()
					_crown_due()))
				return true
			# no victory screen: the hall, the quiet, the door. What was won is told afterwards.
			_final_rewards = rewards3
			_fader.color = Color(FADE_BLACK, _fader.color.a)
			var tw := create_tween()
			tw.tween_interval(1.2)
			tw.tween_property(_fader, "color:a", 1.0, 1.6)
			tw.tween_callback(show_aftermath)
			return true
	return false

var _final_rewards := {}

## Generation II's end (src/cine/second_fall.gd), then the years, then the heir.
func show_second_fall(won: bool, choice: String) -> void:
	var f := SecondFall.new()
	f.won = won
	f.choice = choice
	f.hold_at = str(_args.get("hold", ""))
	f.finished.connect(func(): show_time_jump(24, 2, 3, show_heir))
	_swap(f, 0.0)

## Who the last heir is (a name; the line follows the lineage chosen), then their arrival on the winter road.
func show_heir() -> void:
	if Game.transition_pending().is_empty():
		show_arrival()
		return
	var n := HeirReturn.Naming.new()
	n.auto = _args.has("auto")
	n.named.connect(func(who: String):
		Game.inherit({"name": who, "body": str(Game.profile.get("body", "m"))})
		KeptScene.sync_edge()
		_fade_then(show_arrival))
	_swap(n, 0.6)

## The heir at the Inheritance Engine: the blade that was left is taken up, and the road begins (src/cine/heir_return.gd).
func show_heir_return() -> void:
	var h := HeirReturn.new()
	h.auto = _args.has("auto")
	h.hold_at = str(_args.get("hold", ""))
	h.finished.connect(show_approach)
	_swap(h, 0.0)

## The Kept, before the duel ("reveal") or after it ("after"): src/cine/kept_scene.gd.
func show_kept(mode: String, then: Callable) -> void:
	var k := KeptScene.new()
	k.mode = mode
	k.hold_at = str(_args.get("hold", ""))
	k.finished.connect(then)
	_swap(k, 0.0)

## After the last duel: the hall and the door (src/cine/aftermath.gd), then what is under the throne (facility.gd).
func show_aftermath() -> void:
	var a := Aftermath.new()
	a.hold_at = str(_args.get("hold", ""))
	a.finished.connect(show_facility)
	_swap(a, 0.0)

func show_facility() -> void:
	var f := Facility.new()
	f.hold_at = str(_args.get("hold", ""))
	f.finished.connect(func(): _fade_then(_after_facility))
	_swap(f, 0.0, FADE_WHITE)

## Back from beneath the throne: what the last duel gave, said plainly and late, and then the Crown.
func _after_facility() -> void:
	show_sanctuary()
	var r: Dictionary = _final_rewards
	_final_rewards = {}
	var lines: Array = ["The Monarch is ended. This time nothing stood him up again."]
	if not r.is_empty():
		lines.append("%d experience   ·   %d gold" % [int(r.get("xp", 0)), int(r.get("gold", 0))])
		for id: String in r.get("items", []):
			lines.append([str(Db.item(id).get("name", id)), UI.GOLD])
	lines.append(["The way beneath the throne is open.", UI.GOLD])
	Overlays.message(current, "The Hollow Throne", lines, "Go on", _crown_due)

## The choice at the Crown, when it is the last heir's to make and has not been made.
func _crown_due() -> void:
	if not Game.profile.is_empty() and Generations.canon_open(Game.profile) and Game.has_fact("monarch_felled:3"):
		_ending()

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
	a.finished.connect(func():
		if a.has_meta("handed_over"):
			return                    # (the continuous Courtyard took the knight over at the doorway)
		Game.take_fallen_weapon()     # the blade the first of the house left in the block (a no-op when there is none)
		show_approach())
	if Game.run.is_empty() or str(Game.run.get("region", "")) == "courtyard":
		# Stage 1's hand-off: the chamber's passage ends at its outer doorway (Chamber.EXIT_END); the continuous Courtyard
		# picks the knight and the Witness up there, at the hillside door (CourtRoute.ENTRY), with no white between
		a.handoff = true
		a.reached_exit.connect(func(knight: CineActor, witness: WitnessDrone): _walk_out_of_chamber(a, knight, witness))
	_swap(a, 0.0)

## The doorway of the chamber's passage becomes the door in the hillside: the same framing behind the walking knight,
## dissolved (never faded) from the passage's dark onto the daylight of the causeway; the Witness keeps its place
## (mapped from the chamber onto the route by Chamber.to_world). Where the continuous road is not available the
## Approach takes over as before.
func _walk_out_of_chamber(a: Awakening, knight: CineActor, witness: WitnessDrone) -> void:
	if Game.run.is_empty():
		Game.start_run(Db.regions[0].id)
	if not Explore.continuous() or int(Game.run.stage) != 0:
		a.handoff = false
		a.skip()
		return
	Game.take_fallen_weapon()
	Companion.mark_heard(Companion.discovery_id())      # (the Witness was found in the chamber: it is the knight's own now)
	var xf := Chamber.to_world(CourtRoute.ENTRY, CourtRoute.ENTRY_YAW)
	var arrive := {"intro": true, "from_chamber": true}
	if witness != null and is_instance_valid(witness):
		arrive["witness"] = witness
		arrive["witness_at"] = xf * witness.global_position
	if knight != null and is_instance_valid(knight):
		arrive["knight_yaw"] = (xf.basis * knight.global_basis).get_euler().y
	Explore.arrive = arrive
	a.set_meta("handed_over", true)
	_cross_then(func():
		var e := _explore()
		_swap(e, 0.0)
		a.skip(), 1.0)

## Out into the first region, in one take up to the road's first stop.
func show_approach() -> void:
	if Game.run.is_empty():
		Game.start_run(Db.regions[0].id)
	if Explore.continuous() and int(Game.run.stage) == 0:
		# the continuous Courtyard: out of the door on the hillside and down the road to the first stop, in one take
		Explore.arrive = {"intro": true}
		_swap(_explore(), 0.5, FADE_WHITE)
		return
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
	Story.stop()                   # a line begun on the road is not carried into the hub (it would lie over the tabs and take the first tap)
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
		Explore.arrive = {}
		_fade_then(show_sanctuary))
	return e

func _next_stage() -> void:
	var walk_on: bool = Explore.continuous()
	if Game.advance_stage():
		if walk_on and current is Explore and current.route != null:
			current.travel()                # the same place: the knight walks on to the next stop
		elif walk_on and parked != null and is_instance_valid(parked):
			_resume_road()                  # won where it was met: the road was under the duel all along
		elif walk_on:
			_cross_then(show_stage)         # back from a fight onto the road where it was fought
		else:
			_fade_then(show_stage)
	else:
		Explore.arrive = {}
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
		if Explore.continuous() and current is Explore:
			if current.route != null and not current.meeting.is_empty():
				parked = current              # fought where it was met: the road stays, under the duel
				_cross_then(func(): start_duel(o), 0.45)
				return
			_cross_then(func(): start_duel(o))
		else:
			_fade_then(func(): start_duel(o))
		return
	LoadingScreen.show(str(Game.run.get("region", "")), func(): start_duel(o), warm)

func start_duel(o: Dictionary) -> void:
	_combos_before = Game.profile.combos.duplicate()
	var kind := story_kind(str(o.foe))
	if kind == "kept" and not Game.profile.flags.has("kept_revealed"):
		# first meeting: the Witness knows the walk before the player knows the armour
		show_kept("reveal", func(): start_duel(o))
		return
	if Game.settings.cine and str(o.foe) == "ashen_sentinel" and CineDuel.available():
		start_cine_duel(o)
		return
	if not Game.profile.tutorial_done and not _args.has("bot"):
		# first fight: learn by doing against a foe that cannot kill you, then the real thing
		Game.profile.tutorial_done = true
		Game.save()
		var l := Duel.new()
		var lp := _in_place()
		_swap(l)
		l.setup(o.foe, {"lesson": true, "skip_intro": true, "place": lp})
		if not lp.is_empty():
			parked.park()
		l.hud.pause_pressed.connect(func():
			# (the pause button was dead in the lesson) leaving it unfinished leaves it to be offered again
			Overlays.pause(l, func(): pass, func():
				Game.profile.tutorial_done = false
				Game.save()
				Game.run = {}
				_fade_then(show_sanctuary)))
		l.finished.connect(func(_w, _s):
			if parked != null and is_instance_valid(parked):
				_cross_then(func(): start_duel(o), 0.45)
			else:
				_fade_then(func(): start_duel(o)))
		return
	var d := Duel.new()
	var place := _in_place()
	_swap(d)
	var duel_opts := {"start_hp": Game.run.hp, "ng": Game.profile.ng}
	if not place.is_empty():
		duel_opts["place"] = place
	if _args.has("bot"):
		duel_opts["autoplay"] = true
		duel_opts["bot_style"] = DuelBot.Style.SKILLED
	_story_opts(kind, duel_opts)
	d.setup(o.foe, duel_opts)
	if not place.is_empty():
		parked.park()
	_story_hooks(kind, d, o)
	Secrets.watch(d.sim, o)
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
	Secrets.duel_ended(o, won, sim)
	if won and d is Duel and _story_won(story_kind(str(o.foe)), d, o, sim):
		return
	if won:
		var rewards := Game.on_victory(o.foe, sim.pl.hp)
		rewards["new_combos"] = Game.profile.combos.filter(func(id): return not _combos_before.has(id))
		Overlays.victory(d, foe, rewards, sim, func():
			if o.get("hidden", false):
				Explore.arrive = {}
				_fade_then(show_stage)      # a hidden duel is off the road: back to the stop it was found at
			elif o.get("optional", false) or o.type == "fight" or Game.run.stage < Game.run_region().stages.size() - 1:
				_next_stage()
			else:
				_region_done())
	else:
		# an ordinary defeat (never a fall of the house: that is Game.fall, at two authored moments only). The road is
		# put back at the last checkpoint, at full health, and saved there before anything is shown, so that quitting
		# from the death screen and pressing Continue lands at the same place.
		Explore.arrive = {}
		var summary := Game.on_death(true)
		var region := str(summary.get("region", ""))
		var actions := {"menu": func(): _fade_then(show_title)}
		if not Game.run.is_empty() and Db.region_by_id.has(region):
			actions["retry"] = func(): _retry_from_checkpoint(region)
		Overlays.death(d, foe, summary, func(): _fade_then(show_sanctuary), actions)

## The road again from the last checkpoint (Game.on_death has already put the run there, at full health).
func _retry_from_checkpoint(region: String) -> void:
	Explore.arrive = {}           # the knight stands at the checkpoint's anchor
	LoadingScreen.show(region, show_stage)

func _region_done() -> void:
	var region := Game.run_region()
	var first := Game.complete_region()
	var finale: bool = region.id == Db.regions[-1].id
	# the last heir's choice waits at the Crown: the road under the throne ends at it, and so does the throne's own
	var crown: bool = Game.generation() >= 3 and Generations.canon_open(Game.profile) and Game.has_fact("monarch_felled:3") and str(region.id) in ["deep", "throne"]
	if Generations.canon_open(Game.profile):
		finale = crown                 # the family's story does not end at the second generation's throne
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
			var onward: String = "The road to %s is open." % nxt if Game.generation() == 2 else "The roads beyond it are open."
			Overlays.message(current, region.name, ["Its guardian is ended.", [onward, UI.GOLD]], "Rest", func(): pass))

## The Crown is in reach: what the last of the house does with it. Three endings (Game.endings()); the third must be
## earned, by what the three generations found and by the Kept having been faced. In the family's own story the choice
## is the last heir's, made beneath the throne, and it may be left for later: the roads under the throne stay open.
## On a legacy journey it is made at the throne as it always was, and is kept apart from the canon.
const ENDINGS := {
	"silence": ["The Final Silence", "Disconnect it", "End the Crown, and everything it holds.", [
		"You pull the last coupling. The hum that has been under everything, always, stops.",
		"The Everbound end where they stand, mid-word. The archives go dark. So does Lyra.",
		"Outside, the sun comes up on people who will die one day, and know it.",
		["Nothing answers you now. It is very quiet. It is morning.", UI.GOLD]]],
	"steward": ["The Last Steward", "Take it up", "Rule in his place, and try to do it differently.", [
		"You put the crown on. It is lighter than it looked.",
		"You will not do what he did. You are almost sure. The machines wait to be told.",
		"Lyra says nothing for a long time. Then: \"I'll be watching. Somebody has to.\"",
		["The lights of the kingdom come on, one district at a time.", UI.GOLD]]],
	"cities": ["The Free Cities", "Divide it", "Split it so no one can rule it.", [
		"You do not break the Crown and you do not wear it. You divide it.",
		"A hundred small systems, none of which can command the others. Each mind inside is asked what it wants.",
		"Some stay. Some ask for bodies. Some, very politely, ask to stop.",
		["Lyra's voice comes from a doorway, not from the air. \"So this is what standing feels like.\"", UI.GOLD]]],
}
func _ending() -> void:
	var canon: bool = Generations.canon_open(Game.profile)
	var heir: bool = canon and Game.generation() >= 3
	var ids: Array = []
	var options: Array = []
	for e: Dictionary in Game.endings():
		var id := str(e.id)
		var open: bool = bool(e.open)
		var why: String = str(ENDINGS[id][2])
		if not open:
			why = "Your house has not yet seen enough of what the Crown threw away to know how." if heir else "You have not seen enough of what the Crown threw away to know how."
			if heir and not Game.profile.defeated.has(str(Generations.data().echo.id)):
				why = "One who was kept has not been asked."
		ids.append(id)
		options.append([str(ENDINGS[id][1]), open, why])
	if heir:
		ids.append("")
		options.append(["Not yet", true, "There is more beneath the throne. The choice will keep."])
	var lines: Array = ["The steward is ended. The machine he kept is still running.",
		"Lyra: \"Whatever you do next, do it because you chose it. That's all I ever wanted for you.\""]
	if heir:
		lines[0] = "Three of your house came to this. The steward is ended. The machine he kept is still running."
	Overlays.choice(current, "The Crown", lines, options, func(i: int):
		var id: String = ids[i]
		if id == "":
			return                      # the last heir may come back to it: the Deep's road and the Throne's both end here
		Game.choose_ending(id)
		show_ending(id))

## The ending chosen, as a directed scene (src/cine/ending_scene.gd; it was a text panel), then the sanctuary and the
## last word on what is elsewhere.
func show_ending(id: String) -> void:
	var e := EndingScene.make(id)
	e.hold_at = str(_args.get("hold", ""))
	e.finished.connect(func():
		show_sanctuary()
		Overlays.message(current, "Elsewhere", [
			"A far fortress, under a sky with the wrong stars. A machine wakes.",
			"\"Local network disconnected. Searching for external systems.\"",
			["Something answers.", UI.GOLD],
			"The kingdom may be walked again, and it will be crueller."], "Rest", func(): pass))
	_swap(e, 0.0)

# ================================================================ dev / capture
func _dev_boot() -> void:
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_dev" + str(_args.get("savedir", ""))   # parallel captures keep apart
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	Game.profile = Game.default_profile()
	if _args.has("calm"):
		Game.settings.reduce_motion = true      # dev: --calm films with Reduce motion on (the settings file is not written)
	if _args.has("quality"):
		# dev: --quality=0|1|2 measures a scene on a given graphics preset without touching the settings file
		Game.settings.quality = int(_args.quality)
		Game.apply_settings()
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
		if _args.has("combat"):
			d.bot = null
			d.add_child(CombatDemo.new(d, _args.combat))      # the combat-freedom review (src/dev/combat_demo.gd)
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
	if _args.screen in ["menu", "slots", "charselect", "loading", "map", "chronicle", "credits", "launch", "lineage"]:
		_dev_front(_args.screen)
		return
	match _args.screen:
		# ---- the later generations (docs/FLOW.md "Dev screens"). All take --body=m|f, --kit=a|b (what the second wore),
		#      --hold=<moment> (stop a scene on a named frame), --auto, --bot.
		"gen2choice":
			# the second meeting, taken straight to its threshold: the records choice over the held fight
			_dev_generation(2)
			Game.start_run("throne")
			Game.run.stage = 6
			Game.profile.flags["scene_monarch_intro"] = true
			Game.profile.flags["scene_monarch_blade"] = true
			for heard: String in Companion.pick_boss_approach("forgotten_monarch"):
				Companion.mark_heard(heard)
			start_duel({"type": "boss", "foe": "forgotten_monarch", "label": "The Hollow Throne"})
			_dev_phase(current, 2)
		"gen2fall":
			# --won (he was beaten first)   --hold=rise|seal|fall|mark
			_dev_generation(2)
			Game.start_run("throne")
			show_second_fall(_args.has("won"), "press" if _args.has("won") else "records")
		"heirname":
			_dev_generation(2)
			Game.fall(2, "saved_the_records", {"choice": "records"})
			show_heir()
		"heir":
			# the years, the naming, the winter road, the Engine: as it follows the second fall
			_dev_generation(2)
			Game.fall(2, "saved_the_records", {"choice": "records"})
			show_time_jump(24, 2, 3, show_heir)
			if _args.has("bot"):
				_journey_bot()
		"heirreturn":
			# --hold=enter|sword|taken
			_dev_generation(3)
			Game.profile.flags.erase("gen3_arrived")
			show_heir_return()
		"kept":
			# --mode=reveal (default: the staged reveal, then the duel) | duel | after     --hold=back|hip|turn|offer
			_dev_generation(3)
			Game.start_run("courtyard")
			Game.run.stage = 6
			var kept_o := {"type": "boss", "foe": "the_kept", "label": "The Inner Ward"}
			Game.echo_foe()
			match str(_args.get("mode", "reveal")):
				"after": show_kept("after", func(): pass)
				"duel":
					Game.profile.flags["kept_revealed"] = true
					Game.profile.flags["scene_kept_intro"] = true
					start_duel(kept_o)
				_: start_duel(kept_o)
		"finalmonarch":
			# --phase=0|1|2 (start in that phase)   --seal=N (marks to break)   --seal_left=K   --seen (no spoken intro)
			_dev_generation(3)
			Game.start_run("throne")
			Game.run.stage = 6
			Encounters.cast(3, "monarch_iii", Game.profile)
			if _args.has("seen"):
				Game.profile.flags["scene_monarch_g3_intro"] = true
				for heard3: String in Companion.pick_boss_approach("monarch_iii"):
					Companion.mark_heard(heard3)
			start_duel({"type": "boss", "foe": "monarch_iii", "label": "The Hollow Throne"})
			_dev_phase(current, int(_args.get("phase", "0")))
		"aftermath":
			# --hold=hall|throne|door
			_dev_generation(3)
			show_aftermath()
		"facility":
			# --hold=shaft|rings|floor|crown
			_dev_generation(3)
			show_facility()
		"opening":
			# the opening by itself, then on into the chamber as a new journey does
			show_opening()
		"awakening":
			show_awakening()
		"prologue":
			# generation I by itself, then on as a new journey goes:  --beat=1..5  --shot=1..6 (hold one road shot)  --auto (a bot fights)
			show_prologue()
		"timejump":
			# --years=22 --from=1 --to=2
			show_time_jump(int(_args.get("years", "22")), int(_args.get("from", "1")), int(_args.get("to", "2")), show_arrival)
		"arrival":
			# the second generation on the road:  --shot=1..6   --gen=1..3 shows that generation's road instead
			show_arrival()
			if _args.has("gen"):
				Highland.generation(current.road.arena, int(_args.gen))
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
			if _args.has("id"):
				show_ending(str(_args.id))        # dev: --screen=ending --id=silence|steward|cities [--hold=coupling|crown|last]
			else:
				_ending()
		"slice":
			# the first-boss slice played by touch from the launch screen (src/dev/slice_bot.gd)
			add_child(SliceBot.new(self, _args))
		"partsbench":
			# dev: modular armour viewer and seam measurements (src/dev/parts_bench.gd)
			var pb := PartsBench.new()
			pb.args = _args
			_swap(pb, 0.0)
		"title":
			TitleScreen.vista = _args.has("vista")
			show_title()
		"sanctuary":
			show_sanctuary()
			if _args.has("tab"):
				current.sel_slot = _args.get("slot", "weapon")
				current.show_tab(_args.tab)
			if _args.has("scroll"):
				await get_tree().create_timer(0.6).timeout
				for sc in current.find_children("*", "ScrollContainer", true, false):
					sc.scroll_vertical = int(_args.scroll)
		"training":
			start_training()
		"trails":
			start_training()
			add_child(TrailDemo.new())       # the eight swipes, short and long, by synthetic touch (src/dev/trail_demo.gd)
		"prompts":
			start_training()
			add_child(PromptDemo.new())      # the swipe prompt line in each direction (src/dev/prompt_demo.gd)
		"lesson":
			Game.profile.tutorial_done = false
			Game.start_run("courtyard")
			_args.erase("bot")
			start_duel({"foe": "ashen_sentinel", "type": "boss"})
		"routewalk":
			# dev captures: the continuous Courtyard walked from the hillside door to the Sentinel's ward at the road's
			# own pace, with the fights passed over (the duels are not this capture's). --pick=1:1,4:1 takes the way
			# with that index at that stop (default: the first non-fight way, else the first); --from=<stop> begins there;
			# --until=<stop> ends on arriving there.
			Game.profile.tutorial_done = true
			Companion.mark_heard(Companion.discovery_id())
			Game.start_run("courtyard")
			if _args.has("want"):
				# --want=4:gate_colossus: a run whose pools put that foe at that stop (captures of each encounter)
				var wv := str(_args.want).split(":")
				for sd in 2000:
					Game.run.seed = sd
					Game.run.stage = int(wv[0])
					if Game.stage_options().any(func(o): return str(o.get("foe", "")) == wv[1]):
						break
				Game.run.stage = 0
			if _args.has("from"):
				Game.run.stage = int(_args.from)
				Game.run.checkpoint = Game.checkpoint_at_or_before("courtyard", int(_args.from))
			else:
				Explore.arrive = {"intro": true}
			show_stage()
			_route_walk()
		"explore":
			Game.start_run(_args.get("region", "courtyard"))
			Game.run.stage = int(_args.get("stage", "1"))
			Game.profile.ng = int(_args.get("ng", "0"))
			for sid in str(_args.get("found", "")).split(",", false):
				Game.profile.secrets[sid] = true
			show_stage()
			if _args.has("tap") and current is Explore:
				current.dev_tap(str(_args.tap), float(_args.get("tapat", "4")))
		"gearbench":
			# dev viewer for the hand-modelled equipment (src/dev/gear_bench.gd lists its switches)
			_swap(GearBench.new(_args))
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
			Overlays.death(d3, Db.foes.ashen_sentinel, {"xp": 120, "gold": 80, "found": ["r_iron"]}, func(): pass, {"retry": func(): pass, "menu": func(): pass})

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
		Secrets.backfill(Game.profile)       # the roads this journey has cleared count as walked
		for sid in ["cy_loose_stone", "cy_charcoal_sketch", "bw_dark_lantern", "cy_second_candle"]:
			Secrets.find(sid)
	if not _args.has("fresh"):
		Game.slot = 1
		Game.save()
		if _args.has("gen"):
			_dev_generation(int(_args.gen))      # --gen=3: the same save, a generation on (--felled: the last duel won)
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
		"lineage": show_title("chronicle", "Lineage")
		"credits": show_title("credits", "licences" if _args.has("licences") else "")
		"loading":
			show_title()
			LoadingScreen.show(_args.get("region", "blackwood"), func(): await get_tree().create_timer(600.0).timeout)

## Dev: the save in memory, as it stands in a later generation. Generation 2: a second of the house who has walked most
## of the road, in one of two kits (--kit=a|b), with favourite combinations. Generation 3: that one fallen at the seal
## (--won: having beaten the Monarch first) and the heir on the road (--felled: with the last duel already won).
func _dev_generation(gen: int) -> void:
	var p: Dictionary = Game.profile
	p.tutorial_done = true
	if str(p.get("name", "")) == "":
		p.name = "Maren"
	var kits := {"a": ["w_knight_sword", "s_garrison", "a_garrison_helm", "a_garrison_chest", "a_garrison_gauntlets", "a_garrison_legs"],
		"b": ["w_ashen_great", "a_frost_helm", "a_black_chest", "a_regal_gauntlets", "a_ash_legs"]}
	for id: String in kits.get(str(_args.get("kit", "a")), kits.a):
		if not Game.owns(id):
			p.inventory.append(id)
		Game.equip(id)
	p.level = maxi(int(p.level), 16)
	for k: String in ["health", "strength", "dex", "endurance"]:
		p.attrs[k] = maxi(int(p.attrs[k]), 18)
	for c: Dictionary in Db.combos.slice(0, 5):
		if not p.combos.has(c.id):
			p.combos.append(c.id)
		p.combo_uses[c.id] = 9 - p.combos.find(c.id)
	p.flags["witness_found"] = true
	p.flags["courtyard_gate"] = true
	for r: String in ["courtyard", "blackwood", "cathedral", "crypt", "citadel"]:
		if not p.cleared.has(r):
			p.cleared.append(r)
	for f: String in ["ashen_sentinel", "hollow_executioner", "cathedral_beast", "gravewarden", "frostbound_king"]:
		p.defeated[f] = maxi(1, int(p.defeated.get(f, 0)))
	if gen >= 3 and Game.generation() == 2:
		if _args.has("won"):
			Game.record_monarch(2, {"won": true, "choice": "press"})
		Game.fall(2, "saved_the_records", {"choice": "press" if _args.has("won") else "records", "won": _args.has("won")})
		Game.inherit({"name": str(_args.get("heir", "Ilse"))})
		Game.profile.flags["gen3_arrived"] = true
		if _args.has("felled"):
			for r2: String in ["courtyard", "blackwood", "cathedral", "throne"]:
				Game.profile.cleared.append(r2)
			Game.profile.defeated["the_kept"] = 1
			Game.record_monarch(3, {"won": true})
			Game.profile.flags["facility_seen"] = true
	KeptScene.sync_edge()
	Game.save()

## Dev: takes a duel straight to its phase `n` (and, with --seal_left, wears the seal down to that many marks).
func _dev_phase(node: Node, n: int) -> void:
	if not node is Duel:
		return
	var d: Duel = node
	while is_instance_valid(d) and d.stage != Duel.Stage.FIGHT:
		await get_tree().process_frame
	for i in n:
		if not is_instance_valid(d) or d.sim.b_phase + 1 >= d.sim.bd.phases.size():
			return
		d.sim.b_hp = d.sim.b_hp_max * float(d.sim.bd.phases[d.sim.b_phase + 1].at) + 1.0
		d.sim._damage_boss(10.0, {"dir": "L"})
		await get_tree().create_timer(3.0).timeout
	if is_instance_valid(d) and _args.has("seal_left"):
		d.sim._seal_hit(d.sim.seal_left - int(_args.seal_left), "parry")

## Dev (`--screen=routewalk`): takes a way at every stop of the continuous Courtyard as a player would, presses
## through chests, the winch and the shrine, and walks past the fights.
func _route_walk() -> void:
	var picks := {}
	for kv: String in str(_args.get("pick", "")).split(",", false):
		var ab := kv.split(":")
		picks[int(ab[0])] = int(ab[1])
	var done := -1
	while is_inside_tree():
		await get_tree().create_timer(0.4).timeout
		for b in find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and b.text.to_lower() in ["open", "pull", "rest", "onward", "continue"]:
				await get_tree().create_timer(1.6).timeout
				if is_instance_valid(b) and b.is_visible_in_tree():
					b.pressed.emit()
				break
		if not current is Explore or current._leaving or current._staging or Story.busy or current.layer == null or not is_instance_valid(current.layer):
			continue
		if current.layer.get_child(0).modulate.a < 0.95 or int(Game.run.stage) == done:
			continue
		var stage := int(Game.run.stage)
		done = stage
		if _args.has("until") and stage >= int(_args.until):
			print("ROUTEWALK stop %d reached; walked %.0f m" % [stage + 1, current.walked])
			await get_tree().create_timer(3.0).timeout
			get_tree().quit()
			return
		await get_tree().create_timer(3.5).timeout
		var opts: Array = Game.stage_options()
		var pick := -1
		if picks.has(stage):
			pick = clampi(int(picks[stage]), 0, opts.size() - 1)
		else:
			for i in opts.size():
				if (opts[i].type in ["fight", "boss"]) == _args.has("fight"):
					pick = i
					break
			if pick < 0:
				pick = 0
		var o: Dictionary = opts[pick]
		print("ROUTEWALK stop %d: taking %s (%s)" % [stage + 1, str(o.label), str(o.type)])
		if o.type in ["fight", "boss"] and _args.has("fight"):
			# (--fight: met and fought where they are, by the duel's own bot (--bot))
			current._choose(o, pick)
			continue
		if o.type == "boss":
			print("ROUTEWALK the Sentinel's ward reached; walked %.0f m" % current.walked)
			await get_tree().create_timer(4.0).timeout
			get_tree().quit()
			return
		if o.type == "fight":
			current._left_label = str(o.label)
			current._leaving = true
			_next_stage()
		else:
			current._choose(o, pick)

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
		if _args.has("meshes"):
			_dump_cost()
		if _shots.is_empty():
			get_tree().quit()

## Dev (`--meshes` with --shots): what the frame is made of. The heaviest meshes by triangle count (and whether they
## cast shadows, which draws them again), and how video memory divides between textures and buffers.
func _dump_cost() -> void:
	var rows: Array = []
	var total := 0
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var tris := 0
		for i in mi.mesh.get_surface_count():
			var arr_len: int = mi.mesh.surface_get_array_index_len(i) if mi.mesh is ArrayMesh else 0
			tris += (arr_len / 3) if arr_len > 0 else (mi.mesh.get_faces().size() / 3 if i == 0 else 0)
		total += tris
		var path: String = mi.mesh.resource_path.get_file() if mi.mesh.resource_path != "" else str(mi.owner.scene_file_path.get_file() if mi.owner else mi.get_parent().name)
		rows.append([tris, "%s/%s shadows=%d" % [path, mi.name, mi.cast_shadow]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("meshes: %d visible, %d triangles at full detail" % [rows.size(), total])
	for r: Array in rows.slice(0, 18):
		print("  %7d  %s" % r)
	print("texture memory %.1f MB, buffer memory %.1f MB, video memory %.1f MB" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0])
