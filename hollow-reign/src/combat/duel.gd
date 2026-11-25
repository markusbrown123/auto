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
var _result_sent := false


func setup(foe_id: String, opts: Dictionary = {}) -> void:
	foe = Db.foes[foe_id]
	var region: Dictionary = Db.region_by_id.get(foe.region, Db.regions[0])
	arena = Arena.new()
	add_child(arena)
	arena.build(Arena.theme_for(region.theme, str(foe.get("arena", ""))))
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
	foe_rig.build(foe_look, true)
	foe_rig.position = Vector3(0, 0, -gap * 0.5)
	foe_rig.rotation.y = PI
	_blade_had_emission = foe_rig.mat_blade.emission_enabled
	_blade_base_emission = foe_rig.mat_blade.emission

	var key := SpotLight3D.new()
	key.light_color = Color(arena.theme.sun).lerp(Color.WHITE, 0.5)
	key.light_energy = 5.0
	key.spot_range = 16.0
	key.spot_angle = 42.0
	key.spot_attenuation = 0.6
	key.shadow_enabled = false
	add_child(key)
	key.position = Vector3(4.5, 6.5, 4.0)
	key.look_at(Vector3(0, 1.2, 0))
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
	hud.root.modulate.a = 0.0

	var o := opts.duplicate()
	o["assist"] = 1.3 if Game.settings.assist else 1.0
	sim.setup(Game.stats(), foe, int(opts.get("seed", 0)), o)
	sim.ev.connect(_on_ev)
	if opts.get("autoplay", false):
		bot = DuelBot.new(sim, int(opts.get("bot_style", DuelBot.Style.SLOPPY)), 5)
	Sfx.ambience(str(region.amb))
	Sfx.music(str(foe.music))
	_noise.frequency = 2.0
	_begin_intro(bool(opts.get("skip_intro", false)))

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
	if eq.shield != null:
		look["shield"] = Db.item(eq.shield).get("look", {})
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
	get_tree().create_timer(0.9).timeout.connect(func(): Sfx.play("roar", -2.0, 0.9 / maxf(float(foe.rig.scale) * 0.75, 0.8)))

func _begin_fight() -> void:
	if stage == Stage.FIGHT:
		return
	stage = Stage.FIGHT
	_stage_t = 0.0
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
	match stage:
		Stage.INTRO:
			if _stage_t > 4.6:
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
	_camera(delta)
	_trauma = maxf(0.0, _trauma - delta * 1.8)

func _finish(won: bool) -> void:
	if _result_sent:
		return
	_result_sent = true
	stage = Stage.DONE
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
			var a := 1.3 - _stage_t * 0.19
			var r := 2.4 + float(foe.rig.scale) * 1.6
			pos = Vector3(sin(a) * r, 0.5 + _stage_t * 0.2, -pz + cos(a) * r)
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
			pos = Vector3(1.15 + _cam_side, 1.62, pz + 1.55 - _cam_zoom * 0.5)
			look = Vector3(0.38 + _cam_side * 0.4, foe_h * 0.82, -pz)
			fov = 64.0 - _cam_zoom * 5.0
	var k := 1.0 - exp(-delta * rate)
	if _cam_pos == Vector3.ZERO:
		k = 1.0
	_cam_pos = _cam_pos.lerp(pos, k)
	_cam_look = _cam_look.lerp(look, k)
	cam.fov = lerpf(cam.fov, fov, k)
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
func sparks(at: Vector3, dir: Vector3, amount: int = 18, color: Color = Color(1.0, 0.75, 0.4), speed: float = 5.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.45
	p.mesh = _spark_mesh()
	p.material_override = Look.particle(color)
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = 38.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	p.damping_min = 1.0
	p.damping_max = 3.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 0.3, 0.05, 0))
	p.color_ramp = g
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
	# a brief flash of light sells the impact
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 3.0
	l.omni_range = 4.0
	add_child(l)
	l.global_position = at
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.18)
	tw.tween_callback(l.queue_free)

var _spark_m: QuadMesh
func _spark_mesh() -> QuadMesh:
	if _spark_m == null:
		_spark_m = QuadMesh.new()
		_spark_m.size = Vector2(0.07, 0.07)
	return _spark_m

func _screen_to_world_dir(d: String) -> Vector3:
	var v := DuelSim.dir_vec(d)
	return Vector3(v.x, v.y, 0)

func _set_foe_blade_warning(on: bool) -> void:
	var m: StandardMaterial3D = foe_rig.mat_blade
	if on:
		m.emission_enabled = true
		m.emission = Color(1.0, 0.12, 0.05)
		m.emission_energy_multiplier = 3.0
	else:
		m.emission_enabled = _blade_had_emission
		m.emission = _blade_base_emission
		m.emission_energy_multiplier = 0.9


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
			elif d.index == 0 and a.kind == "slam" and foe.boss:
				Sfx.play("roar", -9.0, 1.1)
		&"boss_strike":
			_on_strike(d)
		&"player_swing":
			player_rig.swing(DuelSim.dir_vec(d.dir), d.time)
			Sfx.play("swing", -4.0, 1.25 - float(d.time) * 0.8)
		&"player_parry_swing":
			player_rig.parry(DuelSim.dir_vec(d.dir))
			Sfx.play("swing", -9.0, 1.3)
		&"player_dodge":
			player_rig.dodge(float(d.side))
			Sfx.play("dodge", -3.0)
		&"player_advance":
			Sfx.play("footstep", -4.0)
		&"exhausted":
			hud.flash_stamina()
		&"rift":
			hud.rift.show_dir(d.dir)
		&"boss_hit":
			var at: Vector3 = foe_rig.chest_point() + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.3), 0.35)
			var crit: bool = d.get("crit", false) or d.get("rift", false)
			if d.get("rift", false):
				Sfx.play("clash", -5.0, 1.5)
				hud.rift.burst()
			sparks(at, _screen_to_world_dir(d.dir) + Vector3(0, 0.3, 0.8), 22 if crit else 12, Color(1.0, 0.8, 0.5) if not d.get("weak", false) else Color(0.6, 0.85, 1.0), 6.0)
			foe_rig.flash(1.0 if crit else 0.6)
			Sfx.play("hit_armor", -2.0 if crit else -5.0, 1.0 + 0.04 * int(d.get("combo", 1)))
			if crit:
				Sfx.play("hit_flesh", -6.0)
			hitstop(0.07 if crit else 0.045)
			shake(0.22 if crit else 0.12)
			Game.haptic(18 if crit else 10, 0.5)
			hud.combo(int(d.get("combo", 1)))
		&"deflected":
			sparks(foe_rig.blade_mid(), Vector3(0, 0.6, 1), 8, Color(1, 0.9, 0.7), 4.0)
			Sfx.play("clash", -8.0, 1.25)
			foe_rig.flash(0.25)
			shake(0.08)
		&"boss_stagger":
			foe_rig.stagger()
			hud.cue.clear()
			_set_foe_blade_warning(false)
			Sfx.play("stagger", -2.0)
			if d.get("break", false):
				hud.toast("POSTURE BROKEN", UI.GOLD, 1.0)
				shake(0.5)
				_slow = 0.35
		&"boss_recover":
			foe_rig.recover()
			foe_rig.set_far(d.far)
			_set_foe_blade_warning(false)
		&"boss_idle":
			foe_rig.guard()
			foe_rig.set_far(d.far)
		&"boss_retreat":
			foe_rig.set_far(true)
			Sfx.play("dodge", -6.0, 0.8)
		&"boss_close":
			foe_rig.set_far(false)
		&"phase_change":
			foe_rig.roar()
			hud.cue.clear()
			_set_foe_blade_warning(false)
			Sfx.play("roar", 0.0, 0.8)
			Sfx.play("bell", -6.0)
			if str(foe.music) == "combat_a":
				Sfx.set_layer("combat_b")
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
				sparks(player_rig.chest_point(), foe_rig.chest_point() - player_rig.chest_point(), 26, Color(0.75, 0.5, 1.0), 9.0)
			elif d.status == "frostbite":
				hud.toast("FROSTBITTEN", UI.FROST, 1.0)
				Sfx.play("frost", -3.0)
			else:
				Sfx.play("ember_burst", -8.0)
		&"boss_dead":
			_begin_finisher(d)
		&"player_dead":
			_begin_death()

func _on_strike(d: Dictionary) -> void:
	var a: Dictionary = d.attack
	var heavy := float(a.dmg) >= 30.0
	hud.cue.clear()
	_set_foe_blade_warning(false)
	var meet := player_rig.chest_point().lerp(foe_rig.blade_mid(), 0.45) + Vector3(0, 0.1, 0)
	match d.result:
		"parried":
			player_rig.guard()
			sparks(meet, Vector3(0, 0.8, 0.6), 34 if d.perfect else 16, Color(1.0, 0.85, 0.55), 7.0 if d.perfect else 5.0)
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
			sparks(meet, Vector3(0, 0.5, 1), 8, Color(1, 0.8, 0.6), 3.5)
			Sfx.play("block", 0.0)
			shake(0.3 if heavy else 0.18)
			hitstop(0.04)
			Game.haptic(22, 0.6)
		"guard_break":
			sparks(meet, Vector3(0, 0.5, 1), 20, Color(1, 0.7, 0.4), 5.0)
			Sfx.play("guard_break", 0.0)
			player_rig.hurt()
			player_rig.blocking = false
			hud.toast("GUARD BROKEN", Color("#d23a2a"), 0.9)
			hud.hurt_flash(0.35)
			shake(0.7)
			hitstop(0.09)
			Game.haptic(70, 1.0)
		"hit":
			sparks(player_rig.chest_point(), Vector3(0, 0.6, 1), 14, Color(0.8, 0.12, 0.08), 4.0)
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
