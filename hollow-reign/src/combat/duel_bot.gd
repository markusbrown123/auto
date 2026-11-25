class_name DuelBot
extends RefCounted
## Scripted players. Used by the tests to prove fairness, and by the
## screenshot/attract mode to drive a duel without a human.

enum Style { SKILLED, SPAM, TURTLE, SLOPPY }

var sim: DuelSim
var style: int = Style.SKILLED
var rng := RandomNumberGenerator.new()
var _plan := {}          # response planned for the current telegraphed attack
var _next_attack := 0.0
var _alt := 0
var _spam_t := 0.0
const CUTS := ["L", "R", "D", "UL", "DR", "U"]

func _init(s: DuelSim, st: int = Style.SKILLED, seed_value: int = 1) -> void:
	sim = s
	style = st
	rng.seed = seed_value
	sim.ev.connect(_on_ev)

func _on_ev(n: StringName, d: Dictionary) -> void:
	if n != &"boss_telegraph" or style == Style.SPAM:
		return
	var a: Dictionary = d.attack
	var impact: float = sim.time + float(d.windup)
	var lead := 0.07
	if style == Style.SLOPPY:
		lead = rng.randf_range(0.02, 0.42)   # human-ish timing error
	if style == Style.TURTLE:
		_plan = {"kind": "block", "at": impact - 0.3}
	elif a.parry:
		_plan = {"kind": "parry", "dir": DuelSim.parry_dir_for(a.dir), "at": impact - lead}
	elif a.dodge != "none":
		_plan = {"kind": "dodge", "side": 1 if a.dodge == "R" else -1, "at": impact - lead - 0.05}
	else:
		_plan = {"kind": "block", "at": impact - 0.3}

func tick(dt: float) -> void:
	if sim.over:
		return
	if style == Style.SPAM:
		_spam_t -= dt
		if _spam_t <= 0.0:
			_spam_t = 0.14
			sim.input_swipe("L")
		return
	var want_block := style == Style.TURTLE and not sim.boss_open()
	if not _plan.is_empty():
		if _plan.kind == "block":
			want_block = sim.time >= float(_plan.at) and sim.b_state == DuelSim.B.WINDUP
			if sim.b_state != DuelSim.B.WINDUP:
				_plan = {}
		elif sim.time >= float(_plan.at):
			if _plan.kind == "parry":
				sim.input_swipe(_plan.dir)
			else:
				sim.input_dodge(_plan.side)
			_plan = {}
	sim.input_block(want_block)
	if sim.boss_open() and sim.p_state == DuelSim.P.FREE and sim.time >= _next_attack:
		if sim.pl.stamina > sim.pl.swing_cost:
			_alt = (_alt + 1) % CUTS.size()
			sim.input_swipe(CUTS[_alt])
			_next_attack = sim.time + 0.02
	elif sim.b_far and sim.b_state == DuelSim.B.IDLE and sim.p_state == DuelSim.P.FREE and style != Style.TURTLE:
		pass   # wait for the lunge rather than walk into it
