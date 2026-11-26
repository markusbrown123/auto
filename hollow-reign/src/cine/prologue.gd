class_name Prologue
extends Node3D
## The prologue: the high road to the Ring-Gate, climbed twice before the player's own knight ever wakes.
##
##   Beat 1  the ninth year of the Silence. Corvan Marrek, an old soldier, walks the road at dawn (six designed
##           shots, the narrator over them), meets the Ashen Sentinel at the gate and fights him: a real duel, the
##           game's own, which cannot be won. He falls.
##   Beat 2  the fourteenth year. The same road in autumn weather. His daughter Tessaly climbs it, passes his
##           sword at the dead tree, and falls at the same gate. Directed, short.
##   Beat 3  the nineteenth year. The road in snow, nobody on it, two swords at the tree, and the gate awake.
##           Then black: the chamber under that gate is the next scene (Awakening).
##
## Nothing here is the player's knight. "SKIP" (top right) passes over the beat on show; a later new journey does
## not play the prologue at all (Opening.SEEN_FILE, the same mark the old opening used).

signal finished

const WALK := 1.38                # metres a second
const DUEL_NG := 8                # how far beyond the old knight the Sentinel is (the duel's own "ng" scaling)
const DUEL_CAP := 38.0            # seconds of fighting after which the next blow that comes is the last
const CARDS := ["THE NINTH YEAR OF THE SILENCE", "THE FOURTEENTH YEAR", "THE NINETEENTH YEAR"]
## The two who climbed first, as profiles the knight's own look code can dress (Duel.player_look).
const FATHER := {"body": "m", "heraldry": "#1f2f4a", "kit": ["w_knight_sword", "s_garrison", "a_garrison_helm", "a_garrison_chest", "a_garrison_gauntlets", "a_garrison_legs"]}
const SISTER := {"body": "f", "heraldry": "#1f2f4a", "kit": ["w_knight_sword", "a_black_helm", "a_black_chest", "a_black_gauntlets", "a_black_legs"]}

var auto := false                 # dev captures and recordings: a bot fights the duel
var start_beat := 1               # dev: 1 the walk, 2 the second fall, 3 the winter and the hand-off
var only_shot := 0                # dev: hold on one shot of the walk (1-7)
var beat := 0
var stage: Node3D                 # everything of the place on show; freed between beats
var arena: Arena
var cam: CineCam
var hero: CineActor
var foe: FighterRig
var duel: Duel
var ui: CanvasLayer
var _veil: ColorRect
var _logo: Control
var _card: Label
var _hint: Label
var _skip: Button
var _token := 0
var _over := false
var _s := 0.0                     # where the walker is on the road
var _on_road := false
var _clock := 0.0
var _fight_t := 0.0
var _kept := {}                   # what the duel borrows from Game, to give back

func _ready() -> void:
	ui = CanvasLayer.new()
	ui.layer = 70
	add_child(ui)
	_veil = UI.full(ColorRect.new())
	_veil.color = Color(0.01, 0.01, 0.012, 1.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_veil)
	_build_cards()
	Highland.warm()
	_begin(clampi(start_beat, 1, 3))

func _exit_tree() -> void:
	_give_back()

# ================================================================ the page furniture
func _build_cards() -> void:
	# the game's mark, as the menu sets it: the name, a rule, a line under it
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	v.offset_top = 92
	v.offset_left = 70
	v.offset_right = 760
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UI.label("HOLLOW REIGN", 76, UI.BONE, "title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	t.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(t)
	var orn := UI.ornament(470, UI.GOLD)
	orn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(orn)
	for c in v.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.modulate.a = 0.0
	ui.add_child(v)
	_logo = v
	_card = UI.title("", 22, UI.BONE)
	_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_card.offset_left = 64
	_card.offset_top = -150
	_card.offset_right = 900
	_card.offset_bottom = -110
	_card.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_card.add_theme_constant_override("shadow_offset_y", 2)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	ui.add_child(_card)
	_hint = UI.title("", 20, UI.GOLD)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.offset_left = -400
	_hint.offset_right = 400
	_hint.offset_top = 96
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.0
	ui.add_child(_hint)
	_skip = UI.menu_item("SKIP  ›", 15, 110)
	_skip.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip.add_theme_color_override("font_color", UI.BONE)
	_skip.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_skip.add_theme_constant_override("outline_size", 5)
	_skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_skip.offset_left = -170
	_skip.offset_top = 14
	_skip.offset_right = -24
	_skip.offset_bottom = 62
	_skip.modulate.a = 0.0
	_skip.pressed.connect(skip_beat)
	ui.add_child(_skip)
	create_tween().tween_property(_skip, "modulate:a", 0.6, 0.8).set_delay(2.0)

func _show_card(text: String, hold: float) -> void:
	_card.text = text
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.8)
	tw.tween_interval(hold)
	tw.tween_property(_card, "modulate:a", 0.0, 0.8)

func _fade(to: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", to, time)
	await tw.finished

## Waits `t` seconds; false if the beat was skipped or the scene ended meanwhile.
func _w(t: float, me: int) -> bool:
	await get_tree().create_timer(t).timeout
	return me == _token and not _over

## Waits for the narrator (or whoever) to reach line `i` of scene `id`, or for the scene to end.
func _line(id: String, i: int, me: int) -> bool:
	while me == _token and not _over and Story.busy:
		var lines: Array = Story.data.scenes[id].lines
		var now := -1
		for k in lines.size():
			if str(Story.data.lines[lines[k]].text) == Story._text.text:
				now = k
		if now >= i:
			break
		await get_tree().process_frame
	return me == _token and not _over

# ================================================================ the place and the people
func _clear() -> void:
	_on_road = false
	if duel:
		duel.free()
		duel = null
	_give_back()
	if stage:
		stage.free()
		stage = null
	arena = null
	cam = null
	hero = null
	foe = null

func _build(season: int) -> void:
	_clear()
	stage = Node3D.new()
	add_child(stage)
	arena = Arena.new()
	stage.add_child(arena)
	arena.build("highland")
	Highland.generation(arena, season + 1)
	cam = CineCam.new()
	stage.add_child(cam)
	cam.far = 6000.0
	cam.drift = 0.03
	Sfx.ambience("wind")

## A profile for one of the two who climbed first: the default knight in their own kit.
static func profile_of(who: Dictionary) -> Dictionary:
	var p: Dictionary = Game.default_profile()
	p.body = who.body
	p.heraldry = who.heraldry
	p.tutorial_done = true
	for slot: String in ["shield", "helm", "chest", "gauntlets", "legs"]:
		p.equipped[slot] = null
	for id: String in who.kit:
		if Db.items.has(id):
			if not p.inventory.has(id):
				p.inventory.append(id)
			p.equipped[str(Db.item(id).slot)] = id
	return p

## How that profile looks, by the same code that dresses the player's knight.
static func look_of(who: Dictionary) -> Dictionary:
	var real: Dictionary = Game.profile
	Game.profile = profile_of(who)
	var look: Dictionary = Duel.player_look()
	Game.profile = real
	return look

func _actor(who: Dictionary) -> CineActor:
	var a := CineActor.new()
	stage.add_child(a)
	a.build(look_of(who), false)
	a.footsteps = true
	return a

func _sentinel(at: Vector3, yaw: float) -> void:
	foe = FighterRig.new()
	stage.add_child(foe)
	foe.build(CineActor.foe_look("ashen_sentinel"), true)
	foe.position = at
	foe.rotation.y = yaw
	foe.time_scale = 0.6

## Sets the walker going along the road from `a` to `b` (metres from its foot).
func _stride(a: float, b: float) -> void:
	_s = a
	_on_road = true
	hero.walking = true
	_place_hero()
	create_tween().tween_property(self, "_s", b, absf(b - a) / WALK)

func _place_hero() -> void:
	hero.position = Highland.road(_s)
	hero.rotation.y = Highland.road_yaw(_s)

func _process(delta: float) -> void:
	_clock += delta
	if _on_road and hero and is_instance_valid(hero):
		_place_hero()
	if arena and cam and is_instance_valid(cam):
		Highland.follow(arena, cam.global_position)
	if duel and is_instance_valid(duel):
		_duel_tick(delta)

# ================================================================ beats
func _begin(b: int) -> void:
	_token += 1
	beat = b
	Story.stop()
	_logo.modulate.a = 0.0
	_card.modulate.a = 0.0
	_hint.modulate.a = 0.0
	_veil.color.a = 1.0
	match b:
		1: _beat_walk(_token)
		2: _beat_second(_token)
		3: _beat_winter(_token)
		_: _end()

## SKIP: on to the next thing. The walk gives way to the duel, the duel to the second fall, that to the chamber.
func skip_beat() -> void:
	if _over:
		return
	Sfx.play("ui_confirm", -8.0)
	if beat == 1 and duel == null:
		_token += 1
		Story.stop()
		_veil.color.a = 1.0
		_logo.modulate.a = 0.0
		_card.modulate.a = 0.0
		_enter_duel(_token)
	elif beat == 1:
		_begin(2)
	else:
		_end()

## Ends the whole prologue now (tests, and the last beat running out).
func skip() -> void:
	_end()

func _end() -> void:
	if _over:
		return
	_over = true
	_token += 1
	Story.stop()
	_veil.color.a = 1.0
	_clear()
	Opening.mark_seen()
	finished.emit()

# ---------------------------------------------------------------- beat 1: the road, and Corvan
## One designed shot of the walk. Each sets the walker on his stretch of road and frames it.
func _shot(i: int) -> void:
	match i:
		1:  # the vista: a small figure, the road ahead of him, and the gate on the heights with the sun in it
			_s = 30.0
			_on_road = true
			hero.walking = false
			_place_hero()
			var h := hero.position
			var back := Highland.on_ground(h.x + 8.0, h.z + 34.0, 4.2)
			cam.cut(back, Vector3(-80.0, -14.0, 0.0), 27.0)
			cam.move(back + Vector3(-1.0, 0.5, -6.0), Vector3(-76.0, -12.0, 0.0), 13.0)
		2:  # low, through the grass, beside him: the sea and the light beyond
			_stride(118.0, 134.0)
			cam.ride(hero, Vector3(-4.8, 0.62, -2.4), Vector3(0.0, 1.25, -1.0))
			cam.fov = 40.0
		3:  # the climb, whole: the road folding up the slope, the walker small on it, the ring above
			var s3 := Highland.road_at_z(196.0)
			_stride(s3 - 20.0, s3 - 6.0)
			var eye := Highland.on_ground(-64.0, 262.0, 9.0)
			cam.cut(eye, Vector3(4.0, -16.0, 150.0), 38.0)
			cam.move(eye + Vector3(3.0, 1.0, -4.0), Vector3(4.0, -14.0, 150.0), 9.0)
		4:  # over his shoulder as he tops the rise: the gate's foot comes up out of the ground
			var s4 := Highland.road_at_z(108.0)
			_stride(s4 - 12.0, s4 + 3.0)
			cam.ride(hero, Vector3(0.62, 0.95, 2.5), Vector3(-0.25, 2.3, -8.0))
			cam.fov = 44.0
		5:  # passing the dead tree, the ring filling the sky behind it
			var s5 := Highland.tree_s()
			_stride(s5 - 7.0, s5 + 5.0)
			var t := Highland.road(s5, -5.5)
			var low := Highland.on_ground(t.x - 5.5, t.z + 12.0, 0.7)
			cam.cut(low, t + Vector3(3.5, 7.0, -16.0), 46.0)
			cam.move(low + Vector3(1.2, 0.15, -0.8), t + Vector3(3.5, 7.4, -16.0), 9.0)
		6:  # arrival: the court, the shut gate, and one figure standing in front of it
			var s6 := Highland.road_at_z(27.0)
			_stride(s6, Highland.road_length())
			cam.cut(Vector3(8.5, 5.4, 33.0), Vector3(-1.0, 4.5, -12.0), 44.0)
			cam.move(Vector3(6.5, 4.2, 27.0), Vector3(-1.0, 4.8, -12.0), 16.0)
		7:  # the Sentinel, from the ground: he turns
			_on_road = false
			hero.walking = false
			hero.position = Vector3(0.4, 0, 4.6)
			hero.rotation.y = 0.0
			cam.cut(Vector3(1.9, 0.38, 1.3), Vector3(-0.2, 2.6, -4.6), 40.0)
			cam.move(Vector3(1.5, 0.45, 2.0), Vector3(-0.1, 2.4, -4.6), 5.0)
			foe.time_scale = 1.0
			var tw := foe.create_tween()
			tw.tween_interval(0.9)
			tw.tween_callback(func(): Sfx.play("armor", -4.0, 0.7))
			tw.tween_property(foe, "rotation:y", PI, 1.9).set_trans(Tween.TRANS_SINE)

func _beat_walk(me: int) -> void:
	_build(0)
	hero = _actor(FATHER)
	_sentinel(Vector3(0, 0, -4.2), 0.0)
	Sfx.music_for("theme", "menu", 2.0)
	if only_shot > 0:
		_veil.color.a = 0.0
		_shot(only_shot)
		if only_shot == 1:
			_logo.modulate.a = 1.0
		return
	# 1: the vista and the game's name
	_shot(1)
	_fade(0.0, 2.0)
	create_tween().tween_property(_logo, "modulate:a", 1.0, 1.6).set_delay(0.9)
	if not await _w(5.2, me):
		return
	create_tween().tween_property(_logo, "modulate:a", 0.0, 1.0)
	_show_card(CARDS[0], 3.2)
	hero.walking = true
	create_tween().tween_property(self, "_s", 30.0 + 9.0 * WALK, 9.0)
	if not await _w(2.2, me):
		return
	Story.play("opening", true)
	if not await _line("opening", 1, me):
		return
	# 2-5: one shot to a line or two of the narrator, no shot held longer than it is worth
	for step: Array in [[2, 3, 9.5], [3, 4, 9.0], [4, 5, 10.5]]:
		_shot(int(step[0]))
		var left := float(step[2])
		while left > 0.0 and me == _token and not _over and (left > float(step[2]) - 5.0 or not Story.busy or _now("opening") < int(step[1])):
			await get_tree().process_frame
			left -= get_process_delta_time()
		if me != _token or _over:
			return
	_shot(5)
	if not await _w(7.5, me):
		return
	_shot(6)
	if not await _w(8.2, me):
		return
	_shot(7)
	if not await _w(3.9, me):
		return
	await _fade(1.0, 0.35)
	if me != _token or _over:
		return
	_enter_duel(me)

func _now(id: String) -> int:
	if not Story.busy:
		return 99
	var lines: Array = Story.data.scenes[id].lines
	for k in lines.size():
		if str(Story.data.lines[lines[k]].text) == Story._text.text:
			return k
	return -1

# ---------------------------------------------------------------- the duel that cannot be won
## The game's own duel, at the gate, with the old knight in the player's place. Nothing in src/combat is special-
## cased for it: the Sentinel is set beyond him with the duel's existing "ng" scaling, the place is chosen with the
## foe's existing "arena" field, and the knight is whoever Game.profile says, so for the length of the fight the
## profile is Corvan's and anything saved meanwhile goes to a scratch folder, never to a save slot.
func _enter_duel(me: int) -> void:
	Story.stop()
	_veil.color.a = 1.0
	if stage:
		stage.free()
		stage = null
	arena = null
	cam = null
	hero = null
	foe = null
	_on_road = false
	var sentinel: Dictionary = Db.foes["ashen_sentinel"]
	_kept = {"profile": Game.profile, "dir": Game.save_dir_override, "arena": sentinel.get("arena"), "run": Game.run}
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_prologue"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	Game.profile = profile_of(FATHER)
	sentinel["arena"] = "highland"
	duel = Duel.new()
	add_child(duel)
	var opts := {"ng": DUEL_NG, "seed": 11}
	if auto:
		opts["autoplay"] = true
		opts["bot_style"] = DuelBot.Style.SLOPPY
	duel.setup("ashen_sentinel", opts)
	if _kept.arena == null:
		sentinel.erase("arena")
	else:
		sentinel["arena"] = _kept.arena
	duel.cam.far = 6000.0
	arena = duel.arena
	_fight_t = 0.0
	duel.sim.ev.connect(_on_duel_ev)
	duel.finished.connect(func(_won: bool, _sim: DuelSim): _duel_over(me))
	_fade(0.0, 0.7)

## Gives Game back what the duel borrowed. Safe to call twice.
func _give_back() -> void:
	if _kept.is_empty():
		return
	Game.profile = _kept.profile
	Game.save_dir_override = _kept.dir
	Game.run = _kept.run
	_kept = {}

## What to do, said once each in the fight's own terms as the moment for it comes.
func _duel_tick(delta: float) -> void:
	if duel.stage != Duel.Stage.FIGHT:
		_say("")
		return
	_fight_t += delta
	var sim := duel.sim
	if sim.b_state == DuelSim.B.WINDUP:
		_say("SWIPE AGAINST HIS BLADE TO TURN IT")
	elif sim.b_state == DuelSim.B.RECOVER or sim.b_state == DuelSim.B.STAGGER:
		_say("HE IS OPEN  ·  SWIPE TO CUT")
	else:
		_say("")

func _say(text: String) -> void:
	if text != "" and _hint.text != text:
		_hint.text = text
	_hint.modulate.a = move_toward(_hint.modulate.a, 0.95 if text != "" else 0.0, get_process_delta_time() * 4.0)

## After long enough, the next blow he lands or has turned is the one that ends it: he was never going to tire.
func _on_duel_ev(n: StringName, _e: Dictionary) -> void:
	if n == &"boss_strike" and _fight_t >= DUEL_CAP and duel and duel.sim.pl.hp > 0.0:
		duel.sim._damage_player(999999.0, true)

func _duel_over(me: int) -> void:
	if me != _token or _over:
		return
	_hint.modulate.a = 0.0
	await _fade(1.0, 0.6)
	if me != _token or _over:
		return
	_begin(2)

# ---------------------------------------------------------------- beat 2: Tessaly, five years on
func _beat_second(me: int) -> void:
	_build(1)
	hero = _actor(SISTER)
	_sentinel(Vector3(0, 0, -1.6), PI)
	foe.time_scale = 1.0
	_cairn(1)
	Sfx.music("", 2.0)
	# the same view as the first: the same road, another year, another walker
	_shot(1)
	hero.walking = true
	create_tween().tween_property(self, "_s", 30.0 + 6.0 * WALK, 6.0)
	_show_card(CARDS[1], 2.6)
	_fade(0.0, 1.2)
	if not await _w(5.0, me):
		return
	# the tree, and what stands under it now
	var st := Highland.tree_s()
	_stride(st - 6.5, st - 0.4)
	var tree := Highland.road(st, -5.5)
	var mark := Highland.road(st, -2.3)
	cam.cut(mark + Vector3(3.6, 0.9, 3.4), mark + Vector3(-0.6, 0.9, -0.6), 40.0)
	cam.move(mark + Vector3(3.0, 1.0, 3.9), mark + Vector3(-0.6, 1.0, -0.6), 8.0)
	if not await _w(4.4, me):
		return
	hero.walking = false
	_turn(hero, tree, 0.9)
	Story.play("prologue_cairn", true)
	if not await _w(4.2, me):
		return
	# the gate: said and done in one wide shot, small against the ring
	Story.stop()
	_on_road = false
	hero.position = Vector3(0.2, 0, 2.3)
	hero.rotation.y = 0.0
	hero.walking = false
	cam.cut(Vector3(-8.5, 1.05, 11.5), Vector3(0.6, 3.4, -4.0), 42.0)
	cam.move(Vector3(-6.4, 1.1, 9.4), Vector3(0.4, 2.6, -3.0), 12.0)
	Story.play("prologue_gate", true)
	while me == _token and not _over and Story.busy:
		await get_tree().process_frame
	if me != _token or _over:
		return
	# one blow turned, and the next not
	foe.telegraph(Vector2(1, 0.2), 0.8, 0.3)
	if not await _w(0.72, me):
		return
	hero.parry(Vector2(-1, 0.2))
	Sfx.play("clash", -2.0)
	if not await _w(0.7, me):
		return
	foe.telegraph(Vector2(0, -1), 0.95, 0.32, "slam")
	if not await _w(1.05, me):
		return
	hero.die(1.0)
	Sfx.play("death", -2.0)
	foe.guard()
	if not await _w(2.6, me):
		return
	await _fade(1.0, 0.9)
	if me != _token or _over:
		return
	_begin(3)

# ---------------------------------------------------------------- beat 3: the nineteenth year
func _beat_winter(me: int) -> void:
	_build(2)
	_cairn(2)
	Sfx.music("", 1.0)
	# the vista a third time: no one on the road
	var h := Highland.road(30.0)
	var back := Highland.on_ground(h.x + 8.0, h.z + 34.0, 4.2)
	cam.cut(back, Vector3(-80.0, -14.0, 0.0), 27.0)
	cam.move(back + Vector3(-0.6, 0.3, -3.0), Vector3(-78.0, -12.0, 0.0), 8.0)
	_show_card(CARDS[2], 2.4)
	_fade(0.0, 1.2)
	if not await _w(4.4, me):
		return
	# two swords under the tree, and behind them the gate, lit from inside
	var st := Highland.tree_s()
	var mark := Highland.road(st, -2.3)
	cam.cut(mark + Vector3(2.2, 0.5, 4.4), mark + Vector3(-0.5, 2.6, -6.0), 40.0)
	cam.move(mark + Vector3(1.8, 0.55, 3.6), mark + Vector3(-0.5, 3.4, -6.0), 6.0)
	if not await _w(4.2, me):
		return
	await _fade(1.0, 1.1)
	if me != _token or _over:
		return
	_end()

# ---------------------------------------------------------------- small things
## The marker under the dead tree: a heap of stones with a sword standing in it for each of them who fell.
func _cairn(swords: int) -> void:
	var at := Highland.road(Highland.tree_s(), -2.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var stone := Look.stone(Color("#77726a"), 0.6)
	for i in 11:
		var b := BoxMesh.new()
		b.size = Vector3(rng.randf_range(0.22, 0.5), rng.randf_range(0.14, 0.3), rng.randf_range(0.22, 0.45))
		var mi := MeshInstance3D.new()
		mi.mesh = b
		mi.material_override = stone
		var ring := 0.55 if i < 7 else 0.2
		mi.position = at + Vector3(cos(i * 0.9) * ring * rng.randf_range(0.5, 1.0), (0.1 if i < 7 else 0.34) - 0.05, sin(i * 0.9) * ring * rng.randf_range(0.5, 1.0))
		mi.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		stage.add_child(mi)
	for k in swords:
		var holder := Node3D.new()
		stage.add_child(holder)
		var length := PropModel.weapon(holder, "res://assets/models/w_knight_sword.glb", "sword")
		holder.rotation = Vector3(PI + (0.12 if k == 0 else -0.16), 0.5 + k * 1.3, 0.07 if k == 0 else -0.1)
		holder.position = at + Vector3(-0.16 + k * 0.34, 0.3 + length * 0.78, 0.05 - k * 0.12)

func _turn(who: Node3D, point: Vector3, time: float) -> void:
	var d := point - who.position
	var yaw := atan2(-d.x, -d.z)
	var from := who.rotation.y
	create_tween().tween_property(who, "rotation:y", from + wrapf(yaw - from, -PI, PI), time).set_trans(Tween.TRANS_SINE)
