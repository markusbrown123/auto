class_name Showcase
extends Node
## Dev driver for demonstration recordings: plays one kind of action on purpose so it can be reviewed.
## Modes: cuts, combos (use in training); parry, block, timed, dodge, roll (use in a duel).
var duel: Duel
var mode := ""
var _t := 0.0
var _i := 0
var _acted := false
var _queue: Array = []        # [time, direction]
const DIRS8 := ["L", "R", "U", "D", "UL", "UR", "DL", "DR"]

func _init(d: Duel, m: String) -> void:
	duel = d
	mode = m
	if mode == "cuts":
		for i in 8:
			_queue.append([1.5 + i * 1.1, DIRS8[i]])
	elif mode == "combos":
		var t := 1.5
		for c in d.sim.combos:
			for dir: String in c.seq:
				_queue.append([t, dir])
				t += 0.62
			t += 1.9

func _process(dt: float) -> void:
	if duel == null or not is_instance_valid(duel) or duel.stage != Duel.Stage.FIGHT:
		return
	_t += dt
	var s: DuelSim = duel.sim
	while not _queue.is_empty() and _t >= float(_queue[0][0]):
		s.input_swipe(str(_queue.pop_front()[1]))
	if mode in ["cuts", "combos"]:
		return
	if s.b_state != DuelSim.B.WINDUP:
		if _acted and mode in ["block", "timed"]:
			duel._on_block(false)
		_acted = false
		if s.boss_open() and mode in ["parry", "dodge", "roll"] and int(_t * 2.5) != _i:
			_i = int(_t * 2.5)
			s.input_swipe(s.rift_dir if s.rift_dir != "" else DIRS8[_i % 8])
		return
	var a: Dictionary = s.b_attack
	match mode:
		"parry":
			if not _acted and s.b_t <= 0.1:
				_acted = true
				s.input_swipe(DuelSim.parry_dir_for(a.dir))
		"block":
			if not _acted and s.b_t <= 0.6:
				_acted = true
				duel._on_block(true)
		"timed":
			if not _acted and s.b_t <= 0.12:
				_acted = true
				duel._on_block(true)
		"dodge", "roll":
			var side := -1 if str(a.dodge) == "L" else 1
			if OS.get_cmdline_user_args().has("--side=L") or OS.get_cmdline_user_args().has("--side=R"):
				side = -1 if OS.get_cmdline_user_args().has("--side=L") else 1      # dev: every dodge or roll to one side
			if not _acted and s.b_t <= 0.22:
				_acted = true
				s.input_dodge(side)
				if mode == "roll":
					get_tree().create_timer(0.08).timeout.connect(func(): s.input_dodge(side))
