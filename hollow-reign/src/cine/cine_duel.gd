class_name CineDuel
extends Node
## The Ashen Sentinel duel presented with prerecorded clips (an experiment).
## Footage from assets/video is the picture; CineFight holds the rules; the
## normal HUD, audio, haptics, subtitles and save systems sit on top, live.
## If any clip is missing the duel is not started: `unavailable` fires and the
## caller falls back to the real-time duel.

signal finished(won: bool, sim: DuelSim)
signal unavailable

const DEF_PATH := "res://data/cine_sentinel.json"

var def: Dictionary
var fight := CineFight.new()
var player: CinePlayer
var hud: DuelHud
var foe: Dictionary
var _cue_for := ""
var _whooshed := false
var _result_sent := false
var _hitstop := 0.0
var _memory_armed := false
var input_log: Array = []      # [what, msec from input to acknowledgement]

static func available() -> bool:
	if not FileAccess.file_exists(DEF_PATH):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(DEF_PATH))
	for c in d.clips:
		var p := "%s%s%s.ogv" % [d.video_dir, d.prefix, c]
		if not (ResourceLoader.exists(p) or FileAccess.file_exists(p)):
			return false
	return true

func setup(opts: Dictionary = {}) -> void:
	def = JSON.parse_string(FileAccess.get_file_as_string(DEF_PATH))
	foe = Db.foes[def.foe]
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	player = CinePlayer.new()
	player.video_dir = def.video_dir
	player.prefix = def.prefix
	player.lengths = def.clips
	layer.add_child(player)
	hud = DuelHud.new()
	add_child(hud)
	hud.set_foe(foe)
	hud.swipe.connect(func(d, _v): _act("swipe", func(): fight.input_swipe(d)))
	hud.dodge.connect(func(s): _act("dodge", func(): fight.input_dodge(s)))
	hud.block.connect(func(down): fight.input_block(down))
	hud.root.modulate.a = 0.0
	fight.play.connect(player.show_clip)
	fight.prepare.connect(player.prepare)
	fight.ev.connect(_on_ev)
	fight.finished.connect(_on_finished)
	player.advanced.connect(_on_advanced)
	player.media_missing.connect(func(_c): unavailable.emit())
	player.stall_changed.connect(func(on): if on: hud.toast("…", UI.DIM, 0.3))
	fight.setup(def, Game.stats(), int(opts.get("seed", 0)), float(opts.get("start_hp", -1.0)))
	Sfx.ambience("wind")
	Sfx.music_for("boss_" + str(def.foe), str(foe.music))
	fight.start(bool(opts.get("skip_intro", false)))
	if fight.state == CineFight.S.INTRO:
		_speak_intro()
	else:
		hud.set_combat_visible(true)

func _speak_intro() -> void:
	await get_tree().create_timer(1.0).timeout
	if Story.pending("sentinel_intro"):
		Story.play("sentinel_intro")
	elif Story.has_scene("sentinel_retry"):
		Story.play("sentinel_retry")

## Every accepted touch is acknowledged in the same frame it arrives, before the footage reacts.
func _act(kind: String, apply: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	Game.haptic(8, 0.35)
	apply.call()
	input_log.append([kind, (Time.get_ticks_usec() - t0) / 1000.0])

func _on_advanced(dt: float) -> void:
	fight.advance(dt)

func _process(delta: float) -> void:
	if _hitstop > 0.0:
		_hitstop -= delta
		if _hitstop <= 0.0:
			player.hold(false)
	hud.boss_bar.max_value = fight.boss_hp_max
	hud.boss_bar.value = fight.boss_hp
	hud.boss_ghost.max_value = fight.boss_hp_max
	hud.boss_ghost.value = maxf(fight.boss_hp, lerpf(hud.boss_ghost.value, fight.boss_hp, 1.0 - exp(-delta * 2.5)))
	hud.posture_bar.max_value = 1.0
	hud.posture_bar.value = 1.0 if fight.state == CineFight.S.OPEN else 0.0
	hud.hp_bar.max_value = fight.hp_max
	hud.hp_bar.value = fight.hp
	hud.st_bar.max_value = fight.stamina_max
	hud.st_bar.value = fight.stamina
	if fight.state == CineFight.S.TELE:
		var e: Dictionary = fight.exchange
		# the prompt appears when the window opens and its ring closes on the branch point
		if fight.window_open() and _cue_for != e.id + str(fight.stats.exchanges):
			_cue_for = e.id + str(fight.stats.exchanges)
			var left := fight.time_to_branch()
			hud.cue.show_cue("parry", DuelSim.dir_vec(str(e.cue.parry)), "", false, left)
		if not _whooshed and fight.time_to_branch() < -0.0 + 0.05:
			_whooshed = true
		if not _whooshed and fight.t >= float(e.window[1]) - 0.12:
			_whooshed = true
			Sfx.play("swing_heavy", -2.0, 0.85)
	if fight.state == CineFight.S.VICTORY and not _memory_armed and player.has("memory"):
		_memory_armed = true
		player.prepare(["memory"])       # the scene that follows the last words: have it decoded in advance
	if fight.state != CineFight.S.INTRO and hud.root.modulate.a == 0.0 and not _result_sent:
		hud.set_combat_visible(true)

func hitstop(t: float) -> void:
	_hitstop = t
	player.hold(true)

func _on_ev(n: StringName, d: Dictionary) -> void:
	match n:
		&"telegraph":
			_whooshed = false
		&"early":
			hud.toast("TOO SOON", UI.DIM, 0.35)
			Sfx.play("ui_back", -6.0)
		&"answer":
			hud.cue.clear()
			match d.result:
				"wrong":
					Sfx.play("ui_back", -4.0)
				"counter":
					Sfx.play("swing", -3.0, 1.1)
				_:
					Sfx.play("swing", -8.0, 1.3)
		&"no_opening":
			hud.toast("NO OPENING", UI.DIM, 0.35)
			hud.flash_stamina()
		&"exhausted":
			hud.flash_stamina()
		&"guard_break":
			hud.toast("GUARD BROKEN", Color("#d23a2a"), 0.9)
		&"branch":
			hud.cue.clear()
		&"impact":
			match d.outcome:
				"parry":
					Sfx.play("clash", 0.0)
					if d.perfect:
						Sfx.play("parry_perfect", -1.0)
						hud.toast("PERFECT PARRY")
					hitstop(0.10 if d.perfect else 0.05)
					Game.haptic(35 if d.perfect else 18, 0.9)
				"dodge":
					Sfx.play("dodge", -2.0)
					if d.perfect:
						hud.toast("PERFECT DODGE", UI.BONE)
				"block":
					Sfx.play("block", 0.0)
					Game.haptic(22, 0.6)
				"hit":
					Sfx.play("hit_armor", 0.0, 0.9)
					Sfx.play("hit_flesh", -2.0)
					hud.hurt_flash(0.5)
					hitstop(0.06)
					Game.haptic(60, 1.0)
		&"opening":
			hud.toast("OPENING", UI.GOLD, 0.7)
			Sfx.play("stagger", -3.0)
		&"boss_hit":
			Sfx.play("hit_armor", -1.0)
			Sfx.play("hit_flesh", -6.0)
			hitstop(0.07)
			Game.haptic(20, 0.6)
		&"phase":
			hud.toast("THE SENTINEL BURNS", Color("#ff8a3a"), 1.2)
			Sfx.play("roar", -2.0, 0.8)
			if str(foe.music) == "combat_a":
				Sfx.set_layer("combat_b")

func _on_finished(won: bool) -> void:
	if _result_sent:
		return
	_result_sent = true
	hud.set_combat_visible(false, 0.3)
	if won:
		Sfx.play("victory", -2.0)
		await Story.play("sentinel_death")
		if player.has("memory") and Story.pending("sentinel_memory"):
			# what the record shows: the same ward, three hundred years ago
			player.lengths["memory"] = 5.0
			player.show_clip("memory", false)
		await Story.play("sentinel_memory")
	else:
		Sfx.play("death", 0.0)
	if not is_inside_tree():
		return
	# the rest of the game reads results from a DuelSim: hand it an equivalent summary
	var sim := DuelSim.new()
	sim.pl = {"hp": fight.hp, "max_hp": fight.hp_max}
	sim.stats.parries = fight.stats.parries
	sim.stats.dodges = fight.stats.dodges
	sim.stats.blocks = fight.stats.blocks
	sim.stats.hits_taken = fight.stats.hits_taken
	sim.stats.max_combo = fight.stats.counters
	finished.emit(won, sim)
