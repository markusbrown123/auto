class_name CombatDemo
extends Node
## Dev driver for the combat-freedom review (`-- --demo=<foe> --skip_intro --combat=<path of log>`): plays, by synthetic
## touch through the real swipe recogniser and pads, a staged sequence of the moments the rules turn on, and writes a
## per-frame log (inputs, sim events, where the knight's blade tip is on screen) from which the delay between a swipe
## and the blade moving, and the rate of cuts, are measured. Moments, in order: a flurry of eight mixed swipes in an
## opening · three cuts at a raised guard · a plain block · a parry and its counter · a perfect block · a guard break ·
## an unblockable blow, warned and dodged.
var duel: Duel
var log_path := ""
var _f := 0
var _lines: PackedStringArray = []
var _ev: PackedStringArray = []
var _plan: Array = []         # [frame, Callable]
var _mark := ""
const VEC := {"L": Vector2(-1, 0), "R": Vector2(1, 0), "U": Vector2(0, -1), "D": Vector2(0, 1), "UL": Vector2(-1, -1), "UR": Vector2(1, -1), "DL": Vector2(-1, 1), "DR": Vector2(1, 1)}
const FLURRY := ["L", "UR", "D", "R", "UL", "DR", "U", "DL"]

func _init(d: Duel, path: String) -> void:
	duel = d
	log_path = path
	process_priority = -10         # before the duel in the frame, as a finger is

func _ready() -> void:
	duel.sim.ev.connect(func(n: StringName, d: Dictionary):
		var extra := ""
		for k: String in ["dir", "result", "perfect", "why", "counter", "rift", "combo", "read", "dmg", "left"]:
			if d.has(k):
				extra += " %s=%s" % [k, str(d[k])]
		_ev.append(str(n) + extra))
	duel.hud.swipe.connect(func(dir: String, _v: Vector2): _ev.append("SWIPED dir=" + dir))
	var s := duel.sim
	s.b_state = DuelSim.B.IDLE
	s.b_t = 1.0e6
	var f := 45
	var every := 8                 # frames between the flurry's swipes (`--flurry_every=5` swipes faster than the blade can cut)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--combat_only="):
			only = arg.trim_prefix("--combat_only=").split(",")
		if arg.begins_with("--flurry_every="):
			every = int(arg.trim_prefix("--flurry_every="))
	# 1. the flurry: the foe is broken open, eight swipes in eight directions
	if _want("flurry"):
		_at(f, func(): _say("flurry"); s.opening_from = "break"; s._poise_break("cut"))
		for i: int in 8:
			_at(f + 12 + i * every, _swipe.bind(FLURRY[i]))
		f += 12 + 8 * every + 40
		_at(f, func(): _hold_idle())
		f += 20
	if _want("guard"):
		f = _seg_guard(f)
	if _want("counter"):
		f = _seg_counter(f)
	if _want("perfect"):
		f = _seg_perfect(f)
	if _want("break"):
		f = _seg_break(f)
	if _want("unblockable"):
		f = _seg_unblockable(f)
	_at(f, func(): _say("end"); _hold_idle(); _save())

var only: PackedStringArray = []
func _want(seg: String) -> bool:
	return only.is_empty() or only.has(seg)

func _seg_guard(f: int) -> int:
	var s := duel.sim
	# 2. cuts at a raised guard (the third brings the punish), 3. which is blocked
	_at(f, func(): _say("guard"))
	for i: int in 3:
		_at(f + 5 + i * 12, _swipe.bind(["R", "L", "D"][i]))
	f += 5 + 3 * 12
	_at(f, func(): _say("block"); _block(true))
	f += 45
	_at(f, func(): _block(false); _hold_idle())
	return f + 25

func _seg_counter(f: int) -> int:
	var s := duel.sim
	# 4. a parry, then the counter along the shown line, then two free cuts off it
	_at(f, func(): _say("counter"); _attack(_cut("L")))
	_at(f + 2, func(): _when_impact(0.17, func(): _swipe(DuelSim.parry_dir_for("L"))))
	f += 46
	_at(f, func(): _swipe(s.rift_dir if s.rift_dir != "" else "R"))
	_at(f + 7, func(): _swipe("U" if s.rift_dir != "U" else "D"))
	_at(f + 14, func(): _swipe("L" if s.rift_dir != "L" else "R"))
	f += 55
	_at(f, func(): _hold_idle())
	return f + 20

func _seg_perfect(f: int) -> int:
	# 5. a perfect block
	_at(f, func(): _say("perfect"); _attack(_cut("R")))
	_at(f + 2, func(): _when_impact(0.12, func(): _block(true)))
	f += 60
	_at(f, func(): _block(false); _hold_idle())
	return f + 20

func _seg_break(f: int) -> int:
	var s := duel.sim
	# 6. a guard break: the shield has nothing left
	_at(f, func(): _say("break"); s.p_shield = 0; duel.hud.shield_charges({"left": 0, "max": s.p_shield_max}); _attack(_cut("L")); _block(true))
	f += 75
	_at(f, func(): _block(false); _hold_idle())
	return f + 20

func _seg_unblockable(f: int) -> int:
	# 7. an unblockable blow: warned, then dodged
	_at(f, func():
		_say("unblockable")
		var a := _cut("R")
		a["unblockable"] = true
		a["parry"] = false
		a["windup"] = 1.5
		a["kind"] = "lunge"
		_attack(a))
	_at(f + 2, func(): _when_impact(0.25, func(): _pad(duel.hud.pad_r)))
	return f + 90

func _at(frame: int, c: Callable) -> void:
	_plan.append([frame, c])

func _say(what: String) -> void:
	_mark = what
	_ev.append("MARK " + what)

func _hold_idle() -> void:
	var s := duel.sim
	if s.over:
		return
	s._end_opening()
	s.b_poise = s.b_poise_max
	s._go_idle(1.0e6)

func _cut(dir: String) -> Dictionary:
	return {"dir": dir, "windup": 1.1, "dmg": 20, "swing": 0.3, "guard": 26, "parry": true, "unblockable": false, "element": null, "kind": "slash", "dodge": "any"}

func _attack(a: Dictionary) -> void:
	duel.sim._start_combo({"id": "demo", "attacks": [a], "recover": 2.6, "tags": [], "gap": 0.15}, true)

var _waits: Array = []        # [seconds before impact, Callable]
func _when_impact(before: float, c: Callable) -> void:
	_waits.append([before, c])

func _win(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _win(pos)
	e.pressed = pressed
	Input.parse_input_event(e)

func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = _win(pos)
	e.relative = rel
	Input.parse_input_event(e)

## One quick stroke across the foe: finger down this frame, across over the next two, up.
func _swipe(dir: String) -> void:
	_ev.append("TOUCH dir=" + dir)
	var size := get_viewport().get_visible_rect().size
	var v: Vector2 = (VEC[dir] as Vector2).normalized() * size.y * 0.42
	var a := size * Vector2(0.5, 0.45) - v * 0.5
	_touch(0, a, true)
	await get_tree().process_frame
	_drag(0, a + v * 0.5, v * 0.5)
	await get_tree().process_frame
	_drag(0, a + v, v * 0.5)
	_touch(0, a + v, false)

func _block(down: bool) -> void:
	_ev.append("BLOCKPAD " + ("down" if down else "up"))
	_touch(1, duel.hud.pad_block.get_global_rect().get_center(), down)

func _pad(p: Control) -> void:
	_ev.append("PAD")
	var at := p.get_global_rect().get_center()
	_touch(2, at, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_touch(2, at, false)

func _process(_dt: float) -> void:
	if duel == null or not is_instance_valid(duel) or duel.stage != Duel.Stage.FIGHT:
		return
	_f += 1
	while not _plan.is_empty() and _f >= int(_plan[0][0]):
		(_plan.pop_front()[1] as Callable).call()
	var s := duel.sim
	if s.b_state == DuelSim.B.WINDUP:
		for w: Array in _waits.duplicate():
			if s.b_t <= float(w[0]):
				_waits.erase(w)
				(w[1] as Callable).call()
	else:
		_waits.clear()
	# where the blade tip is on screen (the frame's pose is one behind: the rigs move after this node)
	var tip: Vector2 = duel.cam.unproject_position(duel.player_rig.blade_tip())
	var hand: Vector2 = duel.cam.unproject_position(duel.player_rig.weapon_r.global_position)
	_lines.append("%d\t%.3f\t%s\t%.1f\t%.1f\t%.1f\t%.1f\t%d\t%d\t%s" % [Engine.get_process_frames(), s.time, _mark, tip.x, tip.y, hand.x, hand.y, s.p_state, s.b_state, " | ".join(_ev)])
	_ev.clear()

func _save() -> void:
	if log_path == "" or log_path == "1":
		return
	var fa := FileAccess.open(log_path, FileAccess.WRITE)
	if fa:
		fa.store_string("\n".join(_lines) + "\n")
		fa.close()
