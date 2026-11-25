extends Node
## Touch-input suite. Needs a real window (GUI input is not dispatched in
## --headless mode), so tools/test.sh runs it under xvfb when available:
##   godot --path . res://tests/touch.tscn
## Pushes synthetic multi-touch events through the viewport and checks that
## they drive the duel exactly as fingers would.
var failed := 0

func ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		failed += 1

func _ready() -> void:
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_itest"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	Game.new_game()
	# --- real touch events drive the fight (no bot)
	var dt := Duel.new()
	add_child(dt)
	dt.setup("hollow_soldier", {"skip_intro": true, "seed": 2})
	await get_tree().create_timer(0.6).timeout
	var got: Array = []
	dt.hud.swipe.connect(func(dir, _v): got.append(dir))
	var size := get_viewport().get_visible_rect().size
	var mid := size * 0.5
	for case in [[Vector2(-220, 0), "L"], [Vector2(200, 0), "R"], [Vector2(0, -200), "U"], [Vector2(160, 160), "DR"]]:
		_touch(0, mid, true)
		await get_tree().process_frame
		_drag(0, mid + case[0] * 0.5)
		_drag(0, mid + case[0])
		_touch(0, mid + case[0], false)
		await get_tree().create_timer(0.45).timeout
	ok(got == ["L", "R", "U", "DR"], "touch swipes are recognised: %s" % str(got))
	# a zig-zag without lifting chains two cuts
	got.clear()
	_touch(0, mid, true)
	await get_tree().process_frame
	_drag(0, mid + Vector2(-200, 0))
	await get_tree().process_frame
	_drag(0, mid + Vector2(0, 0))
	_touch(0, mid, false)
	ok(got == ["L", "R"], "a zig-zag chains cuts without lifting: %s" % str(got))
	await get_tree().create_timer(0.8).timeout
	# a slow drag must not count as a cut
	got.clear()
	_touch(0, mid, true)
	for i in 12:
		await get_tree().create_timer(0.06).timeout
		_drag(0, mid + Vector2(i * 14.0, 0))
	_touch(0, mid, false)
	ok(got.is_empty(), "a slow drag is ignored")
	# tiny jitter must not count either
	_touch(0, mid, true)
	_drag(0, mid + Vector2(12, 5))
	_touch(0, mid, false)
	ok(got.is_empty(), "a short jitter is ignored")
	# dodge pad, then hold-to-block with a second finger swiping at the same time
	var pad_r: Vector2 = dt.hud.pad_r.get_global_rect().get_center()
	var pad_b: Vector2 = dt.hud.pad_block.get_global_rect().get_center()
	dt.sim.b_t = 30.0
	dt.sim.b_state = DuelSim.B.IDLE
	await get_tree().create_timer(0.5).timeout
	_touch(0, pad_r, true)
	await get_tree().process_frame
	ok(dt.sim.p_state == DuelSim.P.DODGE and dt.sim.p_dodge_side == 1, "dodge button dodges right")
	_touch(0, pad_r, false)
	# software rendering runs slower than real time: wait on the simulation, not the clock
	while dt.sim.p_state != DuelSim.P.FREE:
		await get_tree().process_frame
	_touch(1, pad_b, true)
	await get_tree().process_frame
	ok(dt.sim.p_block and dt.player_rig.blocking, "holding the shield button blocks")
	_touch(2, mid, true)
	await get_tree().process_frame
	_drag(2, mid + Vector2(-200, 0))
	await get_tree().process_frame
	ok(dt.sim.p_block and dt.sim.p_state == DuelSim.P.SWING, "a second finger can cut while the first holds block (state %d, far %s, stamina %.0f, got %s)" % [dt.sim.p_state, dt.sim.b_far, dt.sim.pl.stamina, str(got)])
	_touch(2, mid + Vector2(-200, 0), false)
	_touch(1, pad_b, false)
	await get_tree().process_frame
	ok(not dt.sim.p_block, "releasing the shield button lowers the guard")
	dt.queue_free()
	await get_tree().process_frame
	print("\ntouch: %s" % ("PASS" if failed == 0 else "%d FAILED" % failed))
	get_tree().quit(1 if failed > 0 else 0)

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	get_viewport().push_input(e)

func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	get_viewport().push_input(e)
