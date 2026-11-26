class_name Duel
extends Node3D
## One fight: owns the simulation and presents it (rigs, camera, effects,
## sound, haptics, HUD). Emits `finished` when the duel is decided.

signal finished(won: bool, sim: DuelSim)

enum Stage { INTRO, FIGHT, FINISHER, DEATH, DONE }

var sim := DuelSim.new()
var bot: DuelBot
var foe: Dictionary
var arena: Arena
var player_rig: FighterRig
var foe_rig              # FighterRig or DragonRig: same interface
var cam: Camera3D
var hud: DuelHud
var stage: int = Stage.INTRO
var gap := 3.0

var _freeze := 0.0
var _slow := 0.0
var _trauma := 0.0
var _clock := 0.0
var _stage_t := 0.0
var _cam_side := 0.0
var _cam_zoom := 0.0
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _whoosh_at := -1.0
var _whoosh_heavy := false
var _blade_base_emission := Color.BLACK
var _blade_had_emission := false
var _intro_card: Control
var _noise := FastNoiseLite.new()
var _sparks: Array = []
var fx: Fx                    # pooled contact effects (src/fx/fx.gd)
var _result_sent := false
## Footwork. The fighters stand on a line through the arena's centre; the line turns as they circle,
## and each has an offset along it for advancing, giving ground and being driven back.
var ring := 0.0
var ring_cam := 0.0
var ring_dir := 1.0
var f_back := 0.6
var f_back_t := 0.6
var p_back := 0.0
var p_back_t := 0.0
var p_side := 0.0             # sideways distance the knight is off the line, mid-sidestep
var p_side_owed := 0.0        # sidestep still to be taken
var training := false
var _glinted := false
## Onboarding: learn by doing. Each step waits for the thing itself to be done once.
var _lesson := -1
var _lesson_count := 0
## Each lesson: what to do in a few big words, why in one plain line, and the stroke to draw (if any).
const LESSONS := [
	["SWIPE TO STRIKE", "Drag a finger across your foe, any direction. Land three cuts.", ["R"]],
	["LEFT, THEN RIGHT", "Two cuts in a pattern end in a harder blow. There are more patterns to find.", ["L", "R"]],
	["PARRY", "It is about to cut at you. Swipe INTO the blow as its blade glints.", []],
	["DODGE", "Tap an arrow as the blow comes. Tap it twice to roll clear.", []],
	["BLOCK", "Hold the shield and let the blow land on it.", []],
]
## What the defence just bought, said the moment it works, so cause and effect are unmistakable.
const LESSON_PAYOFF := {2: ["PARRIED", "A parry throws its guard wide open."], 3: ["IT MISSED", "A dodge leaves it off balance."], 4: ["BLOCKED", "Blocking gives you a chance to attack."]}
var _lesson_strike := false      # the defence worked; now the lesson waits for the answering cut
func _lesson_defended(step: int) -> void:
	if _lesson != step or _lesson_strike:
		return
	_lesson_strike = true
	Sfx.play("loot", -8.0, 1.4)
	hud.lesson_text(str(LESSON_PAYOFF[step][0]) + "  ·  SWIPE TO STRIKE", str(LESSON_PAYOFF[step][1]), ["R"], true)

func _lesson_done(step: int) -> void:
	if _lesson != step:
		return
	_lesson += 1
	_lesson_count = 0
	_lesson_strike = false
	Sfx.play("loot", -6.0, 1.2)
	if _lesson >= LESSONS.size():
		_lesson = -1
		hud.lesson_text("", "", [])
		hud.toast("THE OLD LESSONS HOLD", UI.GOLD, 1.4)
		await get_tree().create_timer(1.8).timeout
		_result_sent = true
		stage = Stage.DONE
		finished.emit(true, sim)      # no death, no last words: the real fight follows
		return
	if _lesson == 2:
		sim.lesson_fights = true
		sim.b_t = 0.8
	hud.lesson_text(str(LESSONS[_lesson][0]), str(LESSONS[_lesson][1]), LESSONS[_lesson][2])
var foot := {"circle": 0.08, "keep": 0.7}
var _can_step := true
var _voice_key := ""
var _intro_talk := false


func setup(foe_id: String, opts: Dictionary = {}) -> void:
	foe = Db.foes[foe_id]
	var region: Dictionary = Db.region_by_id.get(foe.region, Db.regions[0])
	arena = Arena.new()
	add_child(arena)
	arena.build(Arena.theme_for(region.theme, str(foe.get("arena", ""))))
	fx = Fx.new()
	add_child(fx)
	fx.ground = Color(arena.theme.floor)
	gap = 2.5 + (float(foe.rig.scale) - 1.0) * 1.5

	player_rig = FighterRig.new()
	add_child(player_rig)
	player_rig.build(player_look(), false)
	player_rig.position = Vector3(0, 0, gap * 0.5)
	foe_rig = DragonRig.new() if str(foe.rig.get("kind", "")) == "dragon" else FighterRig.new()
	add_child(foe_rig)
	var foe_look: Dictionary = foe.rig.duplicate()
	# a generated model for this foe, or for its class, replaces the primitive body when present
	for candidate in ["res://assets/models/%s.glb" % foe_id, "res://assets/models/cls_%s.glb" % str(foe.get("cls", "")).to_lower().replace("-", "_")]:
		if ResourceLoader.exists(candidate):
			foe_look["skin"] = candidate
			if not foe.boss:
				foe_look["skin_tint"] = foe.rig.get("metal", "#888888")
			break
	var carried: String = BOSS_WEAPON.get(foe_id, FOE_WEAPON.get(str(foe.rig.get("weapon", "")), ""))
	if carried != "":
		foe_look.merge(weapon_model(carried))
	foe_rig.build(foe_look, true)
	foe_rig.position = Vector3(0, 0, -gap * 0.5)
	foe_rig.rotation.y = PI
	foot = foe.get("footwork", foot)
	# dragons ride the same turning line as everyone else: they circle, close and give ground too
	_can_step = true
	player_rig.walking = true
	player_rig.combat_steps = true
	if foe_rig is FighterRig:
		foe_rig.walking = true
		foe_rig.combat_steps = true
	f_back = float(foot.keep)
	f_back_t = f_back

	# the key follows the fight; its colour and strength are the region's (Arena.THEMES key / key_e)
	var key := SpotLight3D.new()
	key.light_color = Color(str(arena.light("key")))
	key.light_energy = float(arena.light("key_e"))
	key.light_specular = 0.6
	key.spot_range = 18.0
	key.spot_angle = 40.0
	key.spot_attenuation = 0.6
	key.shadow_enabled = false
	add_child(key)
	key.position = Vector3(4.5, 6.5, 4.0)
	key.look_at(Vector3(0, 1.2, 0))
	fx.follow_key(key, player_rig, foe_rig)
	# generated bodies: clamp gloss (dragons are not loaded through SkinDriver) and edge them in the region's light
	var rim_c := Color(str(arena.light("rim"))) * (float(arena.light("rim_e")) * 0.4)
	for rig: Node in [player_rig, foe_rig]:
		var sk = rig.get("skin")
		if sk != null and sk.get("root") != null:
			Look.sanitise(sk.root, "character", true)
			Look.set_param(sk.root, &"rim_color", Color(rim_c.r, rim_c.g, rim_c.b))
	cam = Camera3D.new()
	cam.fov = 58.0
	cam.near = 0.1
	cam.far = 120.0
	add_child(cam)
	cam.make_current()

	hud = DuelHud.new()
	add_child(hud)
	hud.set_foe(foe)
	hud.swipe.connect(func(d, _v): if stage == Stage.FIGHT: sim.input_swipe(d))
	hud.dodge.connect(func(s): if stage == Stage.FIGHT: sim.input_dodge(s))
	hud.block.connect(_on_block)
	hud.surge_pressed.connect(func(): if stage == Stage.FIGHT: sim.input_surge())
	hud.relic_pressed.connect(func(): if stage == Stage.FIGHT: sim.input_relic())
	hud.root.modulate.a = 0.0

	var o := opts.duplicate()
	o["assist"] = 1.3 if Game.settings.assist else 1.0
	o["combos"] = Db.combos
	training = bool(opts.get("training", false)) or bool(opts.get("lesson", false))
	_lesson = 0 if opts.get("lesson", false) else -1
	sim.setup(Game.stats(), foe, int(opts.get("seed", 0)), o)
	sim.ev.connect(_on_ev)
	if opts.get("autoplay", false):
		bot = DuelBot.new(sim, int(opts.get("bot_style", DuelBot.Style.SLOPPY)), 5)
	Sfx.ambience(str(region.amb))
	Sfx.music_for("boss_" + foe_id, str(foe.music))
	_noise.frequency = 2.0
	_begin_intro(bool(opts.get("skip_intro", false)) or training)
	player_rig.footsteps = true
	if foe_rig is FighterRig:
		foe_rig.footsteps = true
	if _lesson >= 0:
		hud.show_training()
		hud.lesson_text(str(LESSONS[0][0]), str(LESSONS[0][1]), LESSONS[0][2])
		foe_rig.recover()
	elif training:
		hud.show_training()
		foe_rig.recover()

## Weapons that share another weapon's model, recoloured (their own concept could not be generated).
const MODEL_ALIAS := {"w_censer_sword": ["w_vigil_edge", "#e0b060"], "w_monarch": ["w_starfall", "#f0d080"],
	"w_woodcutter": ["w_headsman", "#b0b4b8"], "w_oath_axe": ["w_headsman", "#c04040"]}
## What each kind of foe carries when it has no item of its own.
const FOE_WEAPON := {"sword": "w_knight_sword", "greatsword": "w_crypt_great", "axe": "w_headsman", "cleaver": "w_headsman", "dual": "w_pilgrim_blades"}
const BOSS_WEAPON := {"ashen_sentinel": "w_ashen_great", "hollow_executioner": "w_headsman", "crimson_widow": "w_twin_fangs", "gravewarden": "w_crypt_great",
	"frostbound_king": "w_frost_great", "forgotten_monarch": "w_monarch", "pale_huntsman": "w_woodcutter"}

static func weapon_model(item_id: String) -> Dictionary:
	var alias: Array = MODEL_ALIAS.get(item_id, [item_id, null])
	var out := {"weapon_model": "res://assets/models/%s.glb" % alias[0]}
	if alias[1] != null:
		out["weapon_tint"] = alias[1]
	return out

static func player_look() -> Dictionary:
	var eq: Dictionary = Game.profile.equipped
	var chest: Dictionary = Db.item(eq.chest) if eq.chest != null else {}
	var helm: Dictionary = Db.item(eq.helm) if eq.helm != null else {}
	var weapon: Dictionary = Db.item(eq.weapon)
	var look := {
		"scale": 1.0, "bulk": 1.0, "cape": true, "eye": "#000000",
		"metal": chest.get("look", {}).get("metal", "#4a4038"),
		"cloth": Game.profile.heraldry,
		"helm": "great",
		"weapon": weapon.cls,
		"skin": "res://assets/models/knight_%s.glb" % str(Game.profile.get("body", "m")),
		"witness": bool(Game.profile.flags.get("witness", false)) or bool(Game.profile.flags.get("witness_found", false)),
		"skin_tint": chest.get("look", {}).get("metal", "#aeb2b8"),
	}
	var set_id: String = helm.get("look", {}).get("set", "")
	if eq.helm == null:
		look.helm = "hood"
	elif set_id in ["worn", "garrison", "black"]:
		look.helm = "kettle" if set_id != "black" else "great"
	elif set_id in ["regal", "hollow"]:
		look.helm = "crown"
	for k in ["metal", "glow", "curved"]:
		if weapon.get("look", {}).has(k):
			look["blade" if k == "metal" else k] = weapon.look[k]
	look.merge(weapon_model(str(weapon.id)))
	if eq.shield != null:
		look["shield"] = Db.item(eq.shield).get("look", {}).duplicate()
		look["shield"]["model"] = "res://assets/models/%s.glb" % str(eq.shield)
	if set_id in ["ash", "frost"]:
		look["ember" if set_id == "ash" else "frost"] = true
		look["eye"] = "#ff6a2a" if set_id == "ash" else "#7fd4ff"
	return look


# ================================================================ stages
func _begin_intro(skip: bool) -> void:
	stage = Stage.INTRO
	_stage_t = 0.0
	if skip or not foe.boss:
		_begin_fight()
		return
	Sfx.play("bell", -4.0)
	# who may speak is data (dialogue.json "speech"): creatures have no voice key, and the companions set the scene instead
	_voice_key = Companion.voice_key(str(foe.id))
	if Story.pending(_voice_key + "_intro") or not Companion.pick_boss_approach(str(foe.id)).is_empty():
		# first meeting: they speak before steel is drawn, and the fight waits for them
		_intro_talk = true
		foe_rig.guard()
		_speak_then_fight()
		return
	if Story.has_scene(_voice_key + "_retry"):
		Story.play(_voice_key + "_retry")
	_intro_card = UI.full(Control.new())
	_intro_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_card.gui_input.connect(func(e):
		if e is InputEventScreenTouch and e.pressed and _stage_t > 0.6:
			_begin_fight())
	hud.add_child(_intro_card)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	v.offset_top = -230
	v.offset_bottom = -70
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_card.add_child(v)
	var n := UI.title(foe.name, 46, UI.BONE)
	n.add_theme_font_override("font", UI.font("title"))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t := UI.title(foe.title, 18, UI.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var q := UI.label(foe.get("intro", ""), 22, UI.DIM)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for c in [t, n, q]:
		c.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		c.add_theme_constant_override("shadow_offset_y", 2)
		v.add_child(c)
	_intro_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_intro_card, "modulate:a", 1.0, 0.9)
	foe_rig.roar()
	get_tree().create_timer(0.9).timeout.connect(func(): _creature("roar", -2.0))

func _speak_then_fight() -> void:
	await get_tree().create_timer(1.2).timeout
	await Companion.on_boss_approach(str(foe.id))
	await Story.play(_voice_key + "_intro")
	if not is_inside_tree():
		return
	foe_rig.roar()
	_creature("roar", -2.0)
	hud.toast(str(foe.name).to_upper(), UI.BONE, 1.6)
	await get_tree().create_timer(1.7).timeout
	_intro_talk = false
	_begin_fight()

func _begin_fight() -> void:
	if stage == Stage.FIGHT:
		return
	stage = Stage.FIGHT
	_stage_t = 0.0
	Companion.enter_combat(self)
	if _intro_card:
		var card := _intro_card
		_intro_card = null
		var tw := create_tween()
		tw.tween_property(card, "modulate:a", 0.0, 0.3)
		tw.tween_callback(card.queue_free)
	foe_rig.guard()
	hud.set_combat_visible(true)

func _on_block(down: bool) -> void:
	sim.input_block(down and stage == Stage.FIGHT)
	player_rig.blocking = down and stage == Stage.FIGHT

func _unhandled_key_input(e: InputEvent) -> void:
	# desktop testing: arrows cut, A/D dodge, space blocks
	if stage != Stage.FIGHT or not e is InputEventKey or e.echo:
		return
	var k: int = e.keycode
	if k == KEY_SPACE:
		_on_block(e.pressed)
	if not e.pressed:
		return
	match k:
		KEY_LEFT: sim.input_swipe("L")
		KEY_RIGHT: sim.input_swipe("R")
		KEY_UP: sim.input_swipe("U")
		KEY_DOWN: sim.input_swipe("D")
		KEY_Q: sim.input_surge()
		KEY_E: sim.input_relic()
		KEY_A: sim.input_dodge(-1)
		KEY_D: sim.input_dodge(1)


# ================================================================ frame
func _process(delta: float) -> void:
	_clock += delta
	_stage_t += delta
	var dt := minf(delta, 0.05)
	var ts := 1.0
	if _freeze > 0.0:
		_freeze -= delta
		ts = 0.03
	elif _slow > 0.0:
		_slow -= delta
		ts = 0.35
	player_rig.time_scale = ts
	foe_rig.time_scale = ts
	# the tell is on the blade itself: a glint as the blow commits, so timing can be read without any prompt
	if stage == Stage.FIGHT and sim.b_state == DuelSim.B.WINDUP and foe_rig is FighterRig:
		if sim.b_t <= 0.32 and not _glinted:
			_glinted = true
			var g := OmniLight3D.new()
			g.light_color = Color(1.0, 0.95, 0.8) if not sim.b_attack.get("unblockable", false) else Color(1.0, 0.3, 0.2)
			g.light_energy = 5.0
			g.omni_range = 1.6
			add_child(g)
			g.global_position = foe_rig.blade_mid()
			sparks(foe_rig.blade_tip(), Vector3.UP, 3, g.light_color, 1.2)
			var tw := create_tween()
			tw.tween_property(g, "light_energy", 0.0, 0.28)
			tw.tween_callback(g.queue_free)
	else:
		_glinted = false
	if stage == Stage.FIGHT:
		Sfx.set_intensity("danger" if sim.pl.hp < sim.pl.max_hp * 0.3 else "combat")
	elif stage == Stage.DONE:
		Sfx.set_intensity("explore", 1.5)
	match stage:
		Stage.INTRO:
			if _stage_t > 4.6 and not _intro_talk:
				_begin_fight()
		Stage.FIGHT:
			if bot:
				bot.tick(dt * ts)
			sim.tick(dt * ts)
			if _whoosh_at >= 0.0 and sim.time >= _whoosh_at:
				_whoosh_at = -1.0
				Sfx.play("swing_heavy" if _whoosh_heavy else "swing", -2.0, 0.85 if _whoosh_heavy else 0.9)
			hud.update_bars(sim, delta)
			if sim.rift_dir != "":
				hud.rift.position = cam.unproject_position(foe_rig.chest_point()) - hud.rift.size * 0.5
		Stage.FINISHER:
			if _stage_t > 3.4:
				_finish(true)
		Stage.DEATH:
			if _stage_t > 3.0:
				_finish(false)
	_footwork(delta * ts)
	_camera(delta)
	_trauma = maxf(0.0, _trauma - delta * 1.8)

## Moves the pair: circling while the foe looks for an opening, stepping in to strike, giving ground when hurt.
func _footwork(dt: float) -> void:
	if not _can_step:
		return
	if stage == Stage.FIGHT:
		var late := 1.5 if sim.b_phase >= 1 else 1.0
		match sim.b_state:
			DuelSim.B.IDLE:
				# prowling: turn about the player, holding its preferred distance
				ring += ring_dir * float(foot.circle) * late * dt
				f_back_t = (1.7 if sim.b_far else float(foot.keep) / late)
			DuelSim.B.WINDUP:
				# step to exactly striking distance, so the blade arrives where the knight is
				f_back_t = clampf(foe_rig.reach() + 0.22 - gap - p_back, -1.0, 1.4) if foe_rig is FighterRig else 0.05
			DuelSim.B.RECOVER:
				f_back_t = 1.7 if sim.b_far else 0.1
			DuelSim.B.SHIFT:
				f_back_t = 1.2
		p_back_t = lerpf(p_back_t, 0.0, 1.0 - exp(-dt * 1.6))
		f_back_t = minf(f_back_t, 2.2)
	f_back = lerpf(f_back, f_back_t, 1.0 - exp(-dt * (5.0 if f_back_t < f_back else 3.0)))
	p_back = lerpf(p_back, p_back_t, 1.0 - exp(-dt * 6.0))
	# sidestep: the knight leaves the line quickly, then the line swings round to where they now stand,
	# so the foe has to turn to find them and the camera follows the new angle
	var step := p_side_owed * (1.0 - exp(-dt * 14.0))
	p_side_owed -= step
	p_side += step
	var turn := p_side * (1.0 - exp(-dt * 3.2))
	p_side -= turn
	ring += turn / maxf(gap * 0.5 + p_back, 0.6)      # exact for where the knight stands, so nothing slides back
	p_side_owed = clampf(p_side_owed, -2.8, 2.8)
	ring_cam = lerp_angle(ring_cam, ring, 1.0 - exp(-dt * 2.2))
	var axis := Vector3(sin(ring), 0, cos(ring))
	var perp := Vector3(cos(ring), 0, -sin(ring))
	player_rig.position = axis * (gap * 0.5 + p_back) + perp * p_side
	foe_rig.position = -axis * (gap * 0.5 + f_back)
	var to_foe: Vector3 = foe_rig.position - player_rig.position
	player_rig.rotation.y = atan2(-to_foe.x, -to_foe.z)
	# the foe turns to face at its own pace: heavy things are slow to come about
	foe_rig.rotation.y = lerp_angle(foe_rig.rotation.y, atan2(to_foe.x, to_foe.z), 1.0 - exp(-dt * 7.0))

func _finish(won: bool) -> void:
	if _result_sent:
		return
	_result_sent = true
	stage = Stage.DONE
	Companion.leave_combat()
	if won:
		# last words, what the dead leave behind, and then what the companions make of it
		if _voice_key != "":
			await Story.play(_voice_key + "_death")
			await Story.play(_voice_key + "_memory")
		await Companion.on_victory(str(foe.id))
		if not is_inside_tree():
			return
	finished.emit(won, sim)

func _camera(delta: float) -> void:
	var pz := gap * 0.5
	var foe_h := 1.4 * float(foe.rig.scale) * (1.0 - float(foe.rig.get("hunch", 0.0)) * 0.3)
	var pos: Vector3
	var look: Vector3
	var fov := 58.0
	var rate := 6.0
	match stage:
		Stage.INTRO:
			# low orbit around the foe: let the silhouette land
			# sweeps from the foe's flank round to the knight's shoulder
			var a := 1.3 - minf(_stage_t, 4.6) * 0.19
			var r := 2.4 + float(foe.rig.scale) * 1.6
			pos = Vector3(sin(a) * r, 0.5 + minf(_stage_t, 4.6) * 0.2, -pz + cos(a) * r)
			look = Vector3(0, foe_h * 0.85, -pz)
			fov = 42.0
			rate = 30.0
		Stage.FINISHER:
			var a2 := 1.15 - _stage_t * 0.12
			pos = Vector3(sin(a2) * 3.6, 1.1, cos(a2) * 3.6 * 0.6)
			look = Vector3(0, 1.1, -pz * 0.5)
			fov = 46.0
			rate = 5.0
		Stage.DEATH, Stage.DONE:
			pos = Vector3(1.6, 3.4 + _stage_t * 0.25, pz + 3.2)
			look = Vector3(0, 0.6, pz)
			fov = 50.0
			rate = 1.6
		_:
			# over the right shoulder; drifts with dodges, leans in on openings
			var side_t := player_rig._root.x * 0.6
			_cam_side = lerpf(_cam_side, side_t, 1.0 - exp(-delta * 5.0))
			var zoom_t := 0.0
			if sim.boss_open():
				zoom_t = 0.5
			elif sim.b_state == DuelSim.B.WINDUP and sim.b_attack.get("kind", "") in ["slam", "sweep"]:
				zoom_t = -0.35
			if sim.b_far:
				zoom_t -= 0.3
			_cam_zoom = lerpf(_cam_zoom, zoom_t, 1.0 - exp(-delta * 2.5))
			# stays behind and to the side of wherever the knight actually stands, so the knight never hides the foe
			# low at the knight's flank and looking up: the knight sits in the lower corner, the foe towers over the frame
			var tall := clampf(foe_h / 1.6, 1.0, 2.2)
			pos = Vector3(1.45 + _cam_side + p_side * 0.6, 0.42 + 0.06 * tall, pz + p_back + 1.3 - _cam_zoom * 0.35)
			look = Vector3(-0.25 + _cam_side * 0.4, foe_h * (0.98 + 0.04 * tall), -pz - f_back * 0.6)
			fov = 64.0 - _cam_zoom * 5.0
	var k := 1.0 - exp(-delta * rate)
	if _cam_pos == Vector3.ZERO:
		k = 1.0
	cam.fov = lerpf(cam.fov, fov, k)
	# the camera rides the fight's turning axis, a little behind it
	var turn := Basis(Vector3.UP, ring_cam)
	_cam_pos = _cam_pos.lerp(turn * pos, k)
	_cam_look = _cam_look.lerp(turn * look, k)
	var shake := _trauma * _trauma * float(Game.settings.shake)
	var off := Vector3(_noise.get_noise_2d(_clock * 60.0, 0.0), _noise.get_noise_2d(0.0, _clock * 60.0), 0) * 0.16 * shake
	cam.position = _cam_pos + off
	cam.look_at(_cam_look + off * 0.5)
	cam.rotation.z += _noise.get_noise_2d(_clock * 50.0, 9.0) * 0.035 * shake

func shake(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)

func hitstop(t: float) -> void:
	_freeze = maxf(_freeze, t)


# ================================================================ effects
## Kept as the duel's entry point; the work is done by the pooled emitters in Fx.
func sparks(at: Vector3, dir: Vector3, amount: int = 18, color: Color = Color(1.0, 0.75, 0.4), speed: float = 5.0) -> void:
	fx.sparks(at, dir, amount, color, speed)

## Where on the ground a body stands.
func _feet(rig: Node3D) -> Vector3:
	var c: Vector3 = rig.chest_point()
	return Vector3(c.x, 0.0, c.z)

## The way sparks leave a deflected blow: back against its travel across the screen, upward, and a little away from the camera.
func _deflect_dir(a: Dictionary) -> Vector3:
	var v := DuelSim.dir_vec(str(a.get("dir", "")))
	return cam.global_basis.x * (-v.x * 0.9) + Vector3.UP * (0.55 + 0.3 * absf(v.y)) - cam.global_basis.z * 0.25

## The point on the player's blade nearest the foe's body: where a landed cut actually touches.
func _cut_point() -> Vector3:
	var a0: Vector3 = player_rig.weapon_r.global_position
	var a1: Vector3 = player_rig.blade_tip()
	var c: Vector3 = foe_rig.chest_point()
	var ab := a1 - a0
	var t := clampf((c - a0).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.35, 1.0)
	# on the body's surface, on the side the blade comes from: the rig's blade may be a frame short of the
	# torso when the sim calls the hit, and sparks must not hang in the air beside it
	return c + (a0 + ab * t - c).limit_length(0.3 * float(foe.rig.scale))

func _screen_to_world_dir(d: String) -> Vector3:
	var v := DuelSim.dir_vec(d)
	return Vector3(v.x, v.y, 0)

func _set_foe_blade_warning(on: bool) -> void:
	foe_rig.set_blade_warning(on)


# ================================================================ sim events
func _on_ev(n: StringName, d: Dictionary) -> void:
	match n:
		&"boss_telegraph":
			var a: Dictionary = d.attack
			foe_rig.telegraph(DuelSim.dir_vec(a.dir), d.windup, a.swing, a.kind)
			hud.show_cue(a, d.windup)
			_whoosh_at = sim.time + float(d.windup) - float(a.swing) * 0.6
			_whoosh_heavy = float(foe.rig.scale) > 1.3 or a.kind == "slam"
			_set_foe_blade_warning(a.unblockable)
			if a.unblockable:
				Sfx.play("telegraph_unblockable", -3.0)
				Game.haptic(30, 0.4)
			elif a.kind == "breath":
				Sfx.play("dragon_frost" if str(a.get("element", "")) == "frost" else "dragon_fire", -1.0)      # the gout itself
			elif d.index == 0:
				_creature("effort" if a.kind != "slam" else "growl", -8.0, 1.2)      # it commits with its voice as well as its body
		&"boss_strike":
			_on_strike(d)
		&"boss_combo":
			if randf() < 0.5:
				ring_dir = -ring_dir       # comes at you from the other side
		&"player_swing":
			# step in until the blade will reach the body
			p_back_t = clampf(player_rig.reach() + 0.18 * float(foe.rig.scale) - gap - f_back, -1.1, 0.3)
			player_rig.swing(DuelSim.dir_vec(d.dir), d.time, str(d.get("finish", "")))
			Sfx.play("swing", -4.0, 1.25 - float(d.time) * 0.8)
		&"player_parry_swing":
			player_rig.parry(DuelSim.dir_vec(d.dir))
			Sfx.play("swing", -9.0, 1.3)
		&"player_dodge":
			p_side_owed += float(d.side) * 1.25     # a real step across the ground, not a lean
			player_rig.dodge(float(d.side))
			fx.dust(_feet(player_rig), 5, null, 0.8)
			Sfx.play("dodge", -3.0)
		&"player_roll":
			p_side_owed += float(d.side) * 1.3      # the roll carries on past where the sidestep would have stopped
			player_rig.roll(float(d.side))
			fx.dust(_feet(player_rig), 8)
			Sfx.play("roll", -2.0)
		&"marks":
			if int(d.n) >= int(d.of):
				hud.toast("SENTENCED", Color("#d23a2a"), 1.2)
				Sfx.play("bell", -4.0, 0.7)
			elif int(d.n) > 0:
				hud.toast("MARKED  %d / %d" % [int(d.n), int(d.of)], Color("#c98a6a"), 0.8)
		&"combo_reset":
			hud.training_cuts([], "")
		&"player_advance":
			Sfx.play("footstep", -4.0)
		&"exhausted":
			hud.flash_stamina()
		&"rift":
			hud.rift.show_dir(d.dir)
		&"surge_ready":
			Sfx.play("loot", -4.0, 0.8)
			Game.haptic(20, 0.5)
		&"relic_ready":
			Sfx.play("loot", -8.0, 1.3)
		&"surge":
			hud.toast("SURGE", Color("#ffb347"), 0.9)
			Sfx.play("ember_burst", -1.0)
			Sfx.play("parry_perfect", -4.0, 0.8)
			sparks(foe_rig.chest_point(), Vector3(0, 0.6, 1), 50, Color(1.0, 0.7, 0.3), 8.0)
			hud.cue.clear()
			_set_foe_blade_warning(false)
			shake(0.6)
			_slow = 0.4
			Game.haptic(80, 1.0)
		&"relic":
			hud.toast("MENDED", Color("#7fd4ff"), 0.8)
			Sfx.play("levelup", -6.0, 1.2)
			sparks(player_rig.chest_point(), Vector3.UP, 30, Color(0.5, 0.85, 1.0), 3.0)
			player_rig.flash(0.6)
		&"boss_hit":
			f_back_t = minf(f_back_t + 0.16, 1.5)      # each blow drives it back a pace
			if d.get("crit", false) or str(d.get("named", "")) != "":
				_creature("pain", -5.0, 0.9)
			f_back += 0.05
			var at: Vector3 = _cut_point()
			var crit: bool = d.get("crit", false) or d.get("rift", false)
			if d.get("rift", false):
				Sfx.play("clash", -5.0, 1.5)
				hud.rift.burst()
			var cut: Vector2 = DuelSim.dir_vec(str(d.dir))
			sparks(at, cam.global_basis.x * cut.x - cam.global_basis.y * cut.y * 0.6 + Vector3(0, 0.35, 0) + cam.global_basis.z * 0.3, Fx.BUDGET.hit if crit else 10, Color(1.0, 0.8, 0.5) if not d.get("weak", false) else Color(0.6, 0.85, 1.0), 5.0)
			if d.get("rift", false):
				fx.element("rift", at)
			var p_elem = sim.pl.get("element") if sim.get("pl") is Dictionary else null
			if p_elem != null:
				fx.element(str(p_elem), at, Vector3.UP)
			foe_rig.flash(1.0 if crit else 0.6)
			Sfx.play("hit_armor", -2.0 if crit else -5.0, 1.0 + 0.04 * int(d.get("combo", 1)))
			if crit:
				Sfx.play("hit_flesh", -6.0)
			hitstop(0.07 if crit else 0.045)
			shake(0.22 if crit else 0.12)
			Game.haptic(18 if crit else 10, 0.5)
			hud.combo(int(d.get("combo", 1)))
			if _lesson >= 2 and _lesson_strike:
				_lesson_done(_lesson)      # the answering cut landed: lesson learned
			if _lesson == 0:
				_lesson_count += 1
				if _lesson_count >= 3:
					_lesson_done(0)
			elif _lesson == 1 and str(d.get("named", "")) != "":
				_lesson_done(1)
			if training:
				hud.training_cuts(sim.p_hist.slice(maxi(0, sim.p_hist.size() - 5)), str(d.get("named", "")))
			if str(d.get("named", "")) != "":
				if Game.use_combo(str(d.get("combo_id", ""))):
					hud.toast("DISCOVERED  ·  " + str(d.named).to_upper(), UI.GOLD, 1.6)
					Sfx.play("parry_perfect", -4.0, 0.8)
				else:
					hud.toast(str(d.named).to_upper(), UI.BONE, 0.7)
				Sfx.play("clash", -3.0, 0.8)
				shake(0.25)
				hitstop(0.09)
		&"deflected":
			sparks(foe_rig.blade_mid(), Vector3(0, 0.6, 1), 8, Color(1, 0.9, 0.7), 4.0)
			Sfx.play("clash", -8.0, 1.25)
			foe_rig.flash(0.25)
			shake(0.08)
		&"boss_stagger":
			f_back_t = 1.0                 # reels away; the player follows in
			p_back_t = -0.55
			foe_rig.stagger()
			fx.dust(_feet(foe_rig), 7)
			hud.cue.clear()
			_set_foe_blade_warning(false)
			Sfx.play("stagger", -2.0)
			if d.get("break", false):
				hud.toast("POSTURE BROKEN", UI.GOLD, 1.0)
				shake(0.5)
				_slow = 0.35
		&"boss_recover":
			foe_rig.recover()
			if not _can_step:
				foe_rig.set_far(d.far)
			_set_foe_blade_warning(false)
		&"boss_idle":
			foe_rig.guard()
			if not _can_step:
				foe_rig.set_far(d.far)
		&"boss_retreat":
			if not _can_step:
				foe_rig.set_far(true)
			Sfx.play("dodge", -6.0, 0.8)
		&"boss_close":
			if not _can_step:
				foe_rig.set_far(false)
		&"phase_change":
			foe_rig.roar()
			hud.cue.clear()
			_set_foe_blade_warning(false)
			_creature("roar", 0.0)
			Sfx.play("bell", -6.0)
			if Sfx.current_music() == "combat_a":
				Sfx.set_layer("combat_b")      # the layer was written against this cue only
			var eye := Color(str(foe.rig.get("eye", "#ff6a2a")))
			arena.tint(eye, 0.3 * int(d.phase))
			sparks(foe_rig.chest_point(), Vector3.UP, 40, eye, 7.0)
			shake(0.7)
			Game.haptic(120, 0.8)
			if str(d.roar) != "":
				hud.subtitle(d.roar, 4.2 if d.get("revive", false) else 3.2)
			if d.get("revive", false):
				hud.toast("IT RISES", Color("#c08aff"), 1.4)
		&"status":
			if d.status == "drain":
				hud.toast("DRAINED", Color("#c08aff"), 0.8)
				hud.flash_stamina()
				Sfx.play("frost", -4.0, 0.6)
				fx.element("drain", player_rig.chest_point())
			elif d.status == "frostbite":
				hud.toast("FROSTBITTEN", UI.FROST, 1.0)
				Sfx.play("frost", -3.0)
			else:
				Sfx.play("ember_burst", -8.0)
		&"boss_dead":
			_creature("death", 0.0)
			_begin_finisher(d)
		&"player_dead":
			_begin_death()

## What this foe sounds like when it is not a person: "dragon", "beast", "guardian" or "" (plain roar set).
func _voice_kind() -> String:
	if str(foe.rig.get("kind", "")) == "dragon":
		return "dragon"
	if str(foe.id) == "cathedral_beast" or str(foe.get("cls", "")) in ["Monstrosity", "Soul-Eater"]:
		return "beast"
	if str(foe.id) in ["ashen_sentinel", "hollow_executioner", "gravewarden"] or str(foe.get("cls", "")) in ["Heavy", "Giant", "Guardian"]:
		return "guardian"
	return ""

## A creature sound, pitched to the creature's size. `what`: roar, growl, pain, death, effort, breath.
var _voice_quiet_until := 0.0
func _creature(what: String, vol: float = 0.0, gap: float = 0.0) -> void:
	if _clock < _voice_quiet_until:
		return
	_voice_quiet_until = _clock + gap
	var kind := _voice_kind()
	var pitch := 0.95 / maxf(float(foe.rig.scale) * 0.6, 0.8)
	var table := {
		"dragon": {"roar": ["dragon_roar_1", "dragon_roar_2"], "growl": ["dragon_growl_1", "dragon_growl_2"], "pain": ["dragon_pain_1", "dragon_pain_2"], "death": ["dragon_death"], "effort": ["dragon_growl_1"], "breath": ["dragon_breath"]},
		"beast": {"roar": ["beast_threat"], "growl": ["beast_growl_1", "beast_growl_2"], "pain": ["beast_pain"], "death": ["beast_death"], "effort": ["beast_lunge"], "breath": ["beast_breath"]},
		"guardian": {"roar": ["guardian_effort_2"], "growl": ["guardian_breath"], "pain": ["guardian_pain"], "death": ["guardian_death"], "effort": ["guardian_effort_1", "guardian_effort_2"], "breath": ["guardian_breath"]},
	}
	if table.has(kind) and table[kind].has(what):
		var set: Array = table[kind][what]
		Sfx.play(str(set[randi() % set.size()]), vol, pitch if kind != "guardian" else 1.0)
	elif what in ["roar", "death"]:
		Sfx.play("roar", vol, 0.9 / maxf(float(foe.rig.scale) * 0.75, 0.8))

func _on_strike(d: Dictionary) -> void:
	var a: Dictionary = d.attack
	var heavy := float(a.dmg) >= 30.0
	hud.cue.clear()
	_set_foe_blade_warning(false)
	var meet := player_rig.chest_point().lerp(foe_rig.blade_mid(), 0.45) + Vector3(0, 0.1, 0)
	if foe_rig is FighterRig and str(d.result) in ["parried", "blocked", "guard_break"] and str(a.get("kind", "")) not in ["thrust", "lunge"]:
		foe_rig.halt(0.3 if d.result == "parried" else 0.2)
	if foe_rig is FighterRig:
		# the real point on the foe's blade nearest the knight, so contact is where it looks like it is
		var a0: Vector3 = foe_rig.weapon_r.global_position
		var a1: Vector3 = foe_rig.blade_tip()
		meet = a0.lerp(a1, 0.72)
	if _lesson >= 2:
		_lesson_defended({"parried": 2, "dodged": 3, "blocked": 4}.get(str(d.result), -9))
	# effects that belong to the blow itself, whatever came of it
	if str(a.get("kind", "")) == "slam":
		# where the blow comes down: beside the knight if it was dodged, otherwise just in front of the feet
		fx.chips(foe_rig.blade_tip() if str(d.result) == "dodged" else _feet(player_rig).lerp(_feet(foe_rig), 0.3))
	if a.get("element") != null and str(d.result) != "dodged":
		fx.element(str(a.element), meet if str(d.result) != "hit" else player_rig.chest_point(), _deflect_dir(a))
	match d.result:
		"parried":
			player_rig.guard()
			player_rig.clash(meet, 0.3 if d.perfect else 0.22)
			sparks(meet, _deflect_dir(a), Fx.BUDGET.perfect if d.perfect else Fx.BUDGET.parry, Color(1.0, 0.82, 0.5), 6.5 if d.perfect else 5.0)
			Sfx.play("clash", 0.0)
			shake(0.35 if d.perfect else 0.2)
			hitstop(0.13 if d.perfect else 0.06)
			Game.haptic(35 if d.perfect else 18, 0.9 if d.perfect else 0.6)
			if d.perfect:
				Sfx.play("parry_perfect", -1.0)
				hud.toast("PERFECT PARRY")
		"dodged":
			if d.perfect:
				hud.toast("PERFECT DODGE", UI.BONE)
				_slow = 0.28
				Game.haptic(15, 0.4)
		"blocked":
			player_rig.brace(meet, 0.34 if heavy else 0.26)
			sparks(meet, _deflect_dir(a), 10 if heavy else 7, Color(1, 0.8, 0.55), 3.5)
			fx.dust(_feet(player_rig), 7 if heavy else 4, null, 1.0 if heavy else 0.7)
			p_back_t = 0.75 if heavy else 0.4          # the blow shoves the player back across the stones
			Sfx.play("shield_heavy" if heavy else "block", 0.0)
			get_tree().create_timer(0.09).timeout.connect(func(): Sfx.play("shield_scrape", -9.0))      # the blade sliding off
			shake(0.3 if heavy else 0.18)
			hitstop(0.04)
			Game.haptic(22, 0.6)
		"guard_break":
			sparks(meet, _deflect_dir(a), Fx.BUDGET.hit, Color(1, 0.72, 0.4), 5.0)
			fx.dust(_feet(player_rig), 8)
			p_back_t = 1.1
			Sfx.play("guard_break", 0.0)
			player_rig.hurt()
			player_rig.blocking = false
			hud.toast("GUARD BROKEN", Color("#d23a2a"), 0.9)
			hud.hurt_flash(0.35)
			shake(0.7)
			hitstop(0.09)
			Game.haptic(70, 1.0)
		"hit":
			sparks(player_rig.chest_point(), _deflect_dir(a), 12, Color(0.8, 0.12, 0.08), 3.5)
			fx.dust(_feet(player_rig), 7 if heavy else 4)
			p_back_t = 0.95 if heavy else 0.55
			Sfx.play("hit_armor", 0.0, 0.9)
			Sfx.play("hit_flesh", -2.0)
			player_rig.hurt()
			hud.hurt_flash(0.55 if heavy else 0.4)
			shake(0.75 if heavy else 0.5)
			hitstop(0.07)
			Game.haptic(60 if heavy else 40, 1.0)
			if a.get("element") == "frost":
				Sfx.play("frost", -8.0)

func _begin_finisher(d: Dictionary) -> void:
	stage = Stage.FINISHER
	_stage_t = 0.0
	hud.set_combat_visible(false, 0.25)
	hud.cue.clear()
	hud.rift.show_dir("")
	_on_block(false)
	_slow = 1.2
	foe_rig.stagger()
	# the killing blow, then the fall
	get_tree().create_timer(0.35).timeout.connect(func():
		player_rig.swing(Vector2(-0.7, -0.7), 0.5)
		Sfx.play("finisher", 0.0))
	get_tree().create_timer(0.75).timeout.connect(func():
		var eye := Color(str(foe.rig.get("eye", "#ffb060")))
		sparks(foe_rig.chest_point(), Vector3(0, 1, 0.5), 60, eye, 8.0)
		foe_rig.flash(1.0)
		foe_rig.die(-1.0 if str(d.get("dir", "L")).contains("L") else 1.0)
		if foe_rig.eye_light:
			create_tween().tween_property(foe_rig.eye_light, "light_energy", 0.0, 1.5)
		shake(0.8)
		hitstop(0.16)
		Game.haptic(150, 1.0)
		Sfx.music("", 2.5)
		if foe.boss:
			Sfx.play("bell", -3.0, 0.8))
	get_tree().create_timer(1.6).timeout.connect(func(): Sfx.play("victory", -2.0))

func _begin_death() -> void:
	stage = Stage.DEATH
	_stage_t = 0.0
	hud.set_combat_visible(false, 0.3)
	hud.cue.clear()
	player_rig.blocking = false
	player_rig.die(1.0)
	foe_rig.guard()
	Sfx.play("death", 0.0)
	Sfx.music("", 2.0)
	Game.haptic(200, 1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(arena.env, "adjustment_saturation", 0.08, 2.2)
	tw.tween_property(arena.env, "tonemap_exposure", 0.55, 2.6)
