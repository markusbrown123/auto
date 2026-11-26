extends Node
## Plays the cinematic duel through real touch events, for recordings and
## playback tests. Scripts: "mixed" shows successes and failures on purpose;
## "clean" answers everything correctly.
var duel: CineDuel
var script_name := "mixed"
var plan := ["parry", "wrong", "dodge", "none", "parry", "block", "parry", "parry", "parry", "parry", "parry", "parry"]
var _done_for := -1
var _countered := -1
var _block_down := false

func _init(d: CineDuel, s: String) -> void:
	duel = d
	script_name = s

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	get_viewport().push_input(e)

func _swipe(dir: Vector2) -> void:
	var mid := get_viewport().get_visible_rect().size * Vector2(0.5, 0.45)
	_touch(0, mid, true)
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = mid + Vector2(dir.x, -dir.y) * 210.0
	get_viewport().push_input(d)
	_touch(0, d.position, false)

func _process(_dt: float) -> void:
	if not is_instance_valid(duel) or duel.fight.state == CineFight.S.DONE:
		return
	var f := duel.fight
	var n: int = f.stats.exchanges
	var want: String = "parry" if script_name == "clean" else plan[mini(n - 1, plan.size() - 1)] if n > 0 else "parry"
	if f.state == CineFight.S.TELE:
		if want == "block" and not _block_down:
			_block_down = true
			_touch(3, duel.hud.pad_block.get_global_rect().get_center(), true)
		if _done_for != n and f.window_open() and f.t >= float(f.exchange.perfect_from) - (0.0 if n % 2 == 0 else 0.25):
			_done_for = n
			var cue: String = f.exchange.cue.parry
			match want:
				"parry": _swipe(DuelSim.dir_vec(cue))
				"wrong": _swipe(-DuelSim.dir_vec(cue))
				"dodge":
					var side: String = f.exchange.cue.dodge
					var pad: Control = duel.hud.pad_r if side == "R" else duel.hud.pad_l
					_touch(1, pad.get_global_rect().get_center(), true)
					_touch(1, pad.get_global_rect().get_center(), false)
	elif _block_down and f.state != CineFight.S.OUTCOME:
		_block_down = false
		_touch(3, duel.hud.pad_block.get_global_rect().get_center(), false)
	if f.state == CineFight.S.OPEN and _countered != n and f.t > 0.5:
		_countered = n
		_swipe(Vector2(-0.7, -0.7))
