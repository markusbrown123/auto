extends Node
## Playback test for the cinematic duel. Needs a real window (video does not
## decode in --headless):  godot --path . res://tests/cine_playback.tscn
## Plays a whole duel through real touch events and inspects what is actually
## on screen every frame: black frames, freezes, branch delays, pause safety,
## missing media.
var failed := 0
var duel: CineDuel
var frames := 0
var black := 0
var worst_frame_ms := 0.0
var _last_usec := 0
var _watch := false
var _last_img_hash := 0
var _same := 0
var longest_freeze := 0
var plays: Array = []
var hp_trace: Array = []

func ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		failed += 1

func _ready() -> void:
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_itest"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	Game.new_game()
	Game.profile.flags["scene_sentinel_intro"] = true
	for id in ["w_knight_sword", "s_garrison"]:
		Game.profile.inventory.append(id)
		Game.equip(id)
	ok(CineDuel.available(), "all footage is packaged")
	# --- missing media is reported, not played
	var probe := CinePlayer.new()
	add_child(probe)
	var missing: Array = []
	probe.media_missing.connect(func(c): missing.append(c))
	probe.show_clip("no_such_clip", false)
	ok(missing == ["no_such_clip"] and probe.active == null, "a missing clip is reported and nothing is shown")
	probe.queue_free()
	# --- a whole duel, driven by touch
	duel = CineDuel.new()
	add_child(duel)
	duel.setup({"seed": 5})
	duel.fight.play.connect(func(c, _l): plays.append(c))
	add_child(load("res://src/cine/cine_bot.gd").new(duel, "mixed"))
	await get_tree().create_timer(1.0).timeout
	_watch = true
	_last_usec = Time.get_ticks_usec()
	# --- pause in the middle of a telegraph: nothing may move
	while duel.fight.state != CineFight.S.TELE:
		await get_tree().process_frame
	duel.player.hold(true)
	var snap := [duel.fight.t, duel.fight.hp, duel.fight.state]
	_watch = false
	await get_tree().create_timer(1.2).timeout
	ok([duel.fight.t, duel.fight.hp, duel.fight.state] == snap, "paused for 1.2 s mid-telegraph: clock, health and state unchanged")
	duel.player.hold(false)
	_last_usec = Time.get_ticks_usec()
	_watch = true
	var res: Array = await duel.finished
	_watch = false
	var m: Dictionary = duel.player.metrics
	print("  clips played: ", plays.size(), "  ", str(plays).left(260))
	print("  frames inspected %d, black %d, longest identical run %d frames, worst frame %.0f ms" % [frames, black, longest_freeze, worst_frame_ms])
	var bm: Array = m.branch_ms.slice(1)
	bm.sort()
	print("  branches %d, not pre-armed %d, stalls %d, peak decoders %d" % [m.branches, m.unarmed_branches, m.stalls, m.peak_players])
	print("  branch to next new frame (ms): median %.0f, 90th pct %.0f, max %.0f  (one 30 fps frame is 33 ms)" % [bm[bm.size() / 2], bm[int(bm.size() * 0.9)], bm[-1]])
	var acks: Array = duel.input_log.map(func(e): return e[1])
	acks.sort()
	print("  inputs %d, touch-to-acknowledgement median %.2f ms, max %.2f ms" % [acks.size(), acks[acks.size() / 2], acks[-1]])
	print("  video frame is 30 fps; identical consecutive screen frames, longest run: %d (at ~60 fps screen refresh, 2 is expected)" % longest_freeze)
	print("  result won=%s  hp %.0f/%.0f  stats %s" % [res[0], duel.fight.hp, duel.fight.hp_max, str(duel.fight.stats)])
	print("  memory: peak static %.0f MB, video memory %.0f MB (desktop, software renderer)" % [OS.get_static_memory_peak_usage() / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	ok(res[0], "the scripted duel is won")
	ok(black == 0, "no black frames during the duel")
	ok(m.unarmed_branches <= 1, "every branch after the first clip was pre-armed")
	ok(m.stalls == 0, "no playback stalls")
	ok(duel.fight.stats.hits_taken == 2 and duel.fight.stats.parries >= 3 and duel.fight.stats.dodges == 1 and duel.fight.stats.blocks == 1, "the script's successes and failures all registered")
	ok(plays.has("a_hit") or plays.has("b_hit"), "a failed defence played its hit clip")
	ok(plays[-1] == "victory", "the duel ended on the finish")
	ok(duel.fight.hp < duel.fight.hp_max and duel.fight.hp > 0.0, "health reflects exactly the blows taken")
	print("\ncine playback: %s" % ("PASS" if failed == 0 else "%d FAILED" % failed))
	get_tree().quit(1 if failed > 0 else 0)

func _process(_dt: float) -> void:
	if not _watch or duel == null or duel.fight.state == CineFight.S.DONE or duel.player.held:
		_last_usec = Time.get_ticks_usec()
		return
	var now := Time.get_ticks_usec()
	worst_frame_ms = maxf(worst_frame_ms, (now - _last_usec) / 1000.0)
	_last_usec = now
	frames += 1
	var img := get_viewport().get_texture().get_image()
	img.resize(32, 18, Image.INTERPOLATE_BILINEAR)
	var sum := 0.0
	for y in range(4, 14):
		for x in range(8, 24):
			sum += img.get_pixel(x, y).get_luminance()
	if sum / 160.0 < 0.02:
		black += 1
	var h := hash(img.get_data())
	if h == _last_img_hash and duel.player.held == false:
		_same += 1
		longest_freeze = maxi(longest_freeze, _same + 1)
	else:
		_same = 0
	_last_img_hash = h
