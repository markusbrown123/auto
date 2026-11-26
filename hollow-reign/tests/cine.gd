extends Node
## Rules tests for the cinematic duel:  godot --headless --path . res://tests/cine.tscn
## The fight is driven with a simulated presentation clock; no video is needed.
var passed := 0
var failed := 0
var def: Dictionary

func ok(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", what)

func mk(only: String = "", seed_value: int = 3) -> CineFight:
	var d: Dictionary = def.duplicate(true)
	if only != "":
		d.exchanges = d.exchanges.filter(func(e): return e.id == only)
	var f := CineFight.new()
	f.setup(d, Stats.compute(Game.default_profile(), Db.items, Db.classes), seed_value)
	f.start(true)
	return f

func step(f: CineFight, seconds: float, dt: float = 1.0 / 30.0) -> void:
	var n := int(round(seconds / dt))
	for i in n:
		f.advance(dt)

func to_state(f: CineFight, s: int, limit: float = 30.0) -> void:
	var t := 0.0
	while f.state != s and t < limit:
		f.advance(1.0 / 30.0)
		t += 1.0 / 30.0

func to_window(f: CineFight, late: bool = false) -> void:
	to_state(f, CineFight.S.TELE)
	var target: float = float(f.exchange.perfect_from) + 0.05 if late else float(f.exchange.window[0]) + 0.05
	while f.t < target:
		f.advance(1.0 / 60.0)

func _ready() -> void:
	def = JSON.parse_string(FileAccess.get_file_as_string("res://data/cine_sentinel.json"))
	for t in ["t_data", "t_parry", "t_wrong_early_late", "t_repeat", "t_dodge", "t_block", "t_counter", "t_failed_offence", "t_stall_and_steps", "t_victory_defeat", "t_phase"]:
		print("• ", t)
		call(t)
	print("\ncine: %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

func t_data() -> void:
	var P := 3.0
	for e in def.exchanges:
		ok(def.clips.has(e.tele), "telegraph clip listed: %s" % e.tele)
		ok(float(e.window[0]) < float(e.window[1]) and is_equal_approx(float(e.window[1]), float(def.clips[e.tele])), "%s window closes on the branch point" % e.id)
		ok(float(e.perfect_from) > float(e.window[0]) and float(e.perfect_from) < float(e.window[1]), "%s perfect band inside window" % e.id)
		ok(float(e.window[1]) - float(e.window[0]) <= 0.8, "%s: at most 0.8s between an accepted input and its outcome" % e.id)
		for k in ["parry", "dodge", "block", "hit"]:
			var o: Dictionary = e.outcomes[k]
			ok(def.clips.has(o.clip), "%s/%s clip listed" % [e.id, k])
			# telegraph + outcome must land on a loop boundary, or the join into the next clip would jump
			ok(is_zero_approx(fmod(float(def.clips[e.tele]) + float(def.clips[o.clip]), P)), "%s/%s ends on a loop boundary" % [e.id, k])
			ok(def.poses.has(o.exit), "%s/%s exits into a shared pose" % [e.id, k])
			ok(float(o.impact) < float(def.clips[o.clip]), "%s/%s impact marker inside clip" % [e.id, k])
		ok(e.inputs.values().has("parry") and e.inputs.values().has("dodge"), "%s can be parried and dodged" % e.id)
	for c in ["idle", "open", "counter", "recover"]:
		ok(is_zero_approx(fmod(float(def.clips[c]), P)), "%s is a whole number of loop periods" % c)
	ok(def.clips.size() <= 20, "clip library stays small (%d)" % def.clips.size())

func t_parry() -> void:
	var f := mk("overhead")
	var plays: Array = []
	f.play.connect(func(c, _l): plays.append(c))
	to_window(f)
	var hp := f.hp
	var st := f.stamina
	f.input_swipe("U")
	ok(f.chosen == "parry" and not f.perfect, "parry accepted in window")
	ok(is_equal_approx(f.stamina, st - 6.0), "parry costs 6 stamina")
	to_state(f, CineFight.S.OPEN)
	ok(plays == ["a_tele", "a_parry", "open"], "plays telegraph, parry, opening: %s" % str(plays))
	ok(f.hp == hp and f.stats.parries == 1, "parry takes no damage")
	f = mk("overhead")
	to_window(f, true)
	f.input_swipe("U")
	ok(f.perfect, "late-window parry is perfect")
	f = mk("sweep")
	to_window(f)
	f.input_swipe("U")
	ok(f.chosen == "hit", "the sweep needs a different direction")

func t_wrong_early_late() -> void:
	var f := mk("overhead")
	to_state(f, CineFight.S.TELE)
	f.advance(0.2)
	var st := f.stamina
	f.input_swipe("U")
	ok(f.chosen == "" and f.stats.early == 1 and is_equal_approx(f.stamina, st - 3.0), "too early: small cost, no answer")
	to_window(f)
	f.input_swipe("U")
	ok(f.chosen == "parry", "an early miss can still be followed by a good answer")
	# wrong direction
	f = mk("overhead")
	to_window(f)
	var hp := f.hp
	f.input_swipe("D")
	to_state(f, CineFight.S.READY)
	var expect: float = 28.0 * (1.0 - f.mitigation)
	ok(is_equal_approx(f.hp, hp - expect), "wrong answer: exactly one blow of %.1f (lost %.1f)" % [expect, hp - f.hp])
	# no answer at all
	f = mk("overhead")
	to_state(f, CineFight.S.TELE)
	hp = f.hp
	to_state(f, CineFight.S.READY)
	ok(is_equal_approx(f.hp, hp - expect) and f.stats.hits_taken == 1, "no answer: hit once")
	# late: after the branch point nothing can change the outcome
	f = mk("overhead")
	to_state(f, CineFight.S.OUTCOME)
	f.input_swipe("U")
	f.input_dodge(1)
	ok(f.chosen == "hit", "input after the branch is ignored")

func t_repeat() -> void:
	var f := mk("overhead")
	to_window(f)
	f.input_swipe("U")
	var st := f.stamina
	for i in 6:
		f.input_swipe(["D", "L", "U", "R"][i % 4])
		f.input_dodge(1)
	ok(f.chosen == "parry" and f.stamina == st, "one resolution per exchange: extra swipes change nothing")

func t_dodge() -> void:
	var f := mk("sweep")
	to_window(f)
	var hp := f.hp
	var st := f.stamina
	f.input_dodge(-1)
	ok(f.chosen == "dodge" and is_equal_approx(f.stamina, st - 14.0), "dodging away from the sweep")
	to_state(f, CineFight.S.OPEN)
	ok(f.hp == hp and f.stats.dodges == 1, "dodge avoids damage and opens the foe")
	f = mk("sweep")
	to_window(f)
	f.input_dodge(1)
	ok(f.chosen == "hit", "dodging into the sweep is hit")
	f = mk("overhead")
	to_window(f)
	f.input_dodge(1)
	ok(f.chosen == "dodge", "the overhead can be dodged either way")

func t_block() -> void:
	var f := mk("overhead")
	to_state(f, CineFight.S.TELE)
	f.input_block(true)
	var hp := f.hp
	var st := f.stamina
	to_state(f, CineFight.S.OUTCOME)
	ok(f.chosen == "block" and is_equal_approx(f.stamina, st - 36.0), "held shield blocks at the branch, for 36 stamina")
	to_state(f, CineFight.S.READY)
	ok(f.hp > hp - 3.0 and f.hp < hp and f.stats.blocks == 1, "block lets a little through and gives no opening")
	f = mk("overhead")
	to_state(f, CineFight.S.TELE)
	f.input_block(true)
	f.stamina = 5.0
	hp = f.hp
	to_state(f, CineFight.S.READY)
	ok(f.hp < hp - 10.0, "blocking without stamina breaks the guard")

func _open(f: CineFight) -> void:
	to_window(f)
	f.input_swipe("U" if f.exchange.id == "overhead" else "R")
	to_state(f, CineFight.S.OPEN)

func t_counter() -> void:
	var f := mk("overhead")
	_open(f)
	var bhp := f.boss_hp
	var hits := [0]
	f.ev.connect(func(n, _d): if n == &"boss_hit": hits[0] += 1)
	f.input_swipe("L")
	ok(f.state == CineFight.S.COUNTER, "a swipe in the opening starts the counter")
	ok(f.boss_hp == bhp, "damage waits for the visible impact")
	f.input_swipe("R")
	f.input_swipe("L")
	to_state(f, CineFight.S.READY)
	ok(hits[0] == 1 and is_equal_approx(f.boss_hp, bhp - f.attack * 3.0), "the counter lands exactly once")
	var f2 := mk("overhead")
	to_window(f2, true)
	f2.input_swipe("U")
	to_state(f2, CineFight.S.OPEN)
	bhp = f2.boss_hp
	f2.input_swipe("L")
	to_state(f2, CineFight.S.READY)
	ok(is_equal_approx(f2.boss_hp, bhp - f2.attack * 4.5), "a perfect defence makes the counter hit 1.5x")

func t_failed_offence() -> void:
	# a missed chance to attack must never hurt the player
	var f := mk("overhead")
	_open(f)
	var hp := f.hp
	var plays: Array = []
	f.play.connect(func(c, _l): plays.append(c))
	to_state(f, CineFight.S.READY)
	ok(plays.has("recover") and f.hp == hp, "an unused opening closes without harm")
	var st := f.stamina
	f.input_swipe("L")
	ok(f.hp == hp and f.stamina < st and f.state == CineFight.S.READY, "attacking a guarding foe costs stamina, not health")
	_open(f)
	f.stamina = 2.0
	f.input_swipe("L")
	ok(f.state == CineFight.S.OPEN and f.hp == hp, "too tired to counter: nothing happens, nothing is lost")

func t_stall_and_steps() -> void:
	var f := mk("overhead")
	to_window(f)
	var snapshot := [f.t, f.hp, f.stamina, f.state]
	# a stalled video presents no frames, so no time is reported: the window must stay open
	for i in 300:
		f.advance(0.0)
	ok([f.t, f.hp, f.stamina, f.state] == snapshot and f.window_open(), "no frames shown, no time passes: a stall cannot cost health")
	f.input_swipe("U")
	ok(f.chosen == "parry", "the answer still counts after the stall")
	# coarse and fine clocks give the same result
	var results: Array = []
	for dt in [1.0 / 120.0, 1.0 / 30.0, 0.25]:
		var g := mk("overhead", 9)
		to_state(g, CineFight.S.TELE)
		var guard := 0
		while g.state != CineFight.S.READY and guard < 4000:
			g.advance(dt)
			guard += 1
		results.append(snappedf(g.hp, 0.01))
	ok(results[0] == results[1] and results[1] == results[2], "a blow lands once whatever the frame rate: %s" % str(results))

func t_victory_defeat() -> void:
	var f := mk("overhead")
	var ends: Array = []
	f.finished.connect(func(w): ends.append(w))
	var plays: Array = []
	f.play.connect(func(c, _l): plays.append(c))
	var guard := 0
	while f.state != CineFight.S.DONE and guard < 40:
		_open(f)
		f.input_swipe("L")
		to_state(f, CineFight.S.READY, 8.0)
		guard += 1
	ok(ends == [true] and plays[-1] == "victory" and f.boss_hp == 0.0, "the last counter plays the finish and ends the duel once")
	ok(guard >= 5 and guard <= 7, "a clean duel is about six exchanges (%d)" % guard)
	for i in 100:
		f.advance(0.1)
	f.input_swipe("L")
	ok(ends.size() == 1, "nothing fires again after the end")
	# defeat
	f = mk("overhead")
	ends.clear()
	plays.clear()
	f.finished.connect(func(w): ends.append(w))
	f.play.connect(func(c, _l): plays.append(c))
	f.hp = 5.0
	to_state(f, CineFight.S.DONE, 30.0)
	ok(ends == [false] and plays[-1] == "defeat" and plays[-2] == "a_hit", "a fatal blow plays the hit, then the defeat, once")
	# restart is simply a new fight
	var g := mk("overhead")
	ok(g.hp == g.hp_max and g.boss_hp == g.boss_hp_max and g.state == CineFight.S.READY, "a restart begins clean")

func t_phase() -> void:
	var f := mk("overhead")
	var phases := [0]
	f.ev.connect(func(n, _d): if n == &"phase": phases[0] += 1)
	for i in 3:
		_open(f)
		f.input_swipe("L")
		to_state(f, CineFight.S.READY, 8.0)
	ok(f.phase == 2 and phases[0] == 1, "the second phase begins once, at half health")
	to_window(f)
	var hp := f.hp
	f.input_swipe("D")
	to_state(f, CineFight.S.READY)
	ok(is_equal_approx(hp - f.hp, 28.0 * 1.25 * (1.0 - f.mitigation)), "second-phase blows hit a quarter harder")
