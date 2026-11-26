class_name CineFight
extends RefCounted
## Live rules for a duel presented with prerecorded clips. The footage is only
## the picture: input windows, stamina, health, damage, phases, victory and
## defeat are all decided here, in presentation time.
##
## Time only moves when the presentation layer reports that frames were shown
## (`advance(dt)`), so a stalled or missing video freezes the input window and
## the fight with it. Each action is resolved once and each blow lands once, at
## its clip's impact marker.

signal play(clip: String, looping: bool)       # show this clip now
signal prepare(clips: Array)                   # these may be needed next: get their first frames ready
signal ev(name: StringName, d: Dictionary)     # feedback for HUD / audio / haptics
signal finished(won: bool)

enum S { INTRO, READY, TELE, OUTCOME, OPEN, COUNTER, RECOVER, VICTORY, DEFEAT, DONE }

var def: Dictionary
var rng := RandomNumberGenerator.new()
var state: int = S.INTRO
var t := 0.0                 # presentation time inside the current clip
var clip := ""
var clip_len := 0.0

var hp := 0.0
var hp_max := 0.0
var stamina := 0.0
var stamina_max := 0.0
var mitigation := 0.0
var attack := 10.0
var boss_hp := 0.0
var boss_hp_max := 0.0
var phase := 1
var block_held := false

var exchange: Dictionary = {}
var chosen := ""             # outcome locked in for the current exchange ("" = none yet)
var perfect := false
var _applied := false        # the current clip's blow has landed
var _wait := 0.0
var _last_exchange := ""
var _bonus := 1.0
var _counter_used := false
var stats := {"parries": 0, "dodges": 0, "blocks": 0, "hits_taken": 0, "counters": 0, "early": 0, "wrong": 0, "exchanges": 0}

func setup(definition: Dictionary, player: Dictionary, seed_value: int = 0, start_hp: float = -1.0) -> void:
	def = definition
	rng.seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec())
	hp_max = float(player.max_hp)
	hp = hp_max if start_hp <= 0.0 else minf(start_hp, hp_max)
	stamina_max = float(player.max_stamina)
	stamina = stamina_max
	mitigation = float(player.mitigation)
	attack = float(player.attack)
	boss_hp_max = attack * 3.0 * float(def.boss_hits_to_kill)
	boss_hp = boss_hp_max

func start(skip_intro: bool = false) -> void:
	if skip_intro:
		_enter_ready()
	else:
		_show(S.INTRO, str(def.intro.clip), false)
		prepare.emit(["idle"])

# ---------------------------------------------------------------- helpers
func _show(s: int, c: String, looping: bool) -> void:
	state = s
	clip = c
	clip_len = float(def.clips[c])
	t = 0.0
	_applied = false
	play.emit(c, looping)

func _emit(n: StringName, d: Dictionary = {}) -> void:
	ev.emit(n, d)

func window_open() -> bool:
	return state == S.TELE and chosen == "" and t >= float(exchange.window[0]) and t <= float(exchange.window[1])

func time_to_branch() -> float:
	return float(exchange.window[1]) - t if state == S.TELE else -1.0

func _spend(v: float) -> bool:
	if stamina < v:
		_emit(&"exhausted")
		return false
	stamina -= v
	return true

# ---------------------------------------------------------------- input
func input_block(down: bool) -> void:
	block_held = down

func input_swipe(dir: String) -> void:
	_input("swipe:" + dir)

func input_dodge(side: int) -> void:
	_input("dodge:" + ("L" if side < 0 else "R"))

func _input(key: String) -> void:
	match state:
		S.TELE:
			if chosen != "":
				return                       # already answered: one resolution per exchange
			if t < float(exchange.window[0]):
				# too soon to read the blow: costs a little, and may be tried again
				stats.early += 1
				stamina = maxf(0.0, stamina - float(def.stamina.early))
				_emit(&"early", {"key": key})
				return
			if t > float(exchange.window[1]):
				return
			var result: String = exchange.inputs.get(key, "")
			if result == "" or result == "block":
				chosen = "hit"
				stats.wrong += 1
				_emit(&"answer", {"key": key, "result": "wrong"})
				return
			if not _spend(float(def.stamina[result])):
				return
			chosen = result
			perfect = t >= float(exchange.perfect_from)
			_emit(&"answer", {"key": key, "result": result, "perfect": perfect})
		S.OPEN:
			if not key.begins_with("swipe:") or _counter_used:
				return
			if not _spend(float(def.stamina.counter)):
				return                       # a failed attack costs nothing but the chance
			_counter_used = true
			stats.counters += 1
			var dmg := attack * 3.0 * _bonus
			_emit(&"answer", {"key": key, "result": "counter"})
			if boss_hp - dmg <= 0.0:
				_pending_damage = boss_hp
				_show(S.VICTORY, str(def.open.victory.clip), false)
			else:
				_pending_damage = dmg
				_show(S.COUNTER, str(def.open.counter.clip), false)
				prepare.emit(["idle", "a_tele", "b_tele"])
		S.READY:
			if key.begins_with("swipe:"):
				# no opening: the cut is turned aside. It costs stamina, never health.
				stamina = maxf(0.0, stamina - float(def.stamina.early))
				_emit(&"no_opening")

var _pending_damage := 0.0

# ---------------------------------------------------------------- time
## Called by the presentation layer with the time that was actually shown.
func advance(dt: float) -> void:
	if state == S.DONE or dt <= 0.0:
		return
	t += dt
	if state != S.TELE and state != S.OUTCOME:
		stamina = minf(stamina_max, stamina + float(def.stamina.max_regen_per_s) * dt * (0.3 if block_held else 1.0))
	match state:
		S.INTRO:
			if t >= clip_len:
				_enter_ready()
		S.READY:
			if t >= _wait:
				_begin_exchange()
		S.TELE:
			if t >= float(exchange.window[1]):
				_branch()
		S.OUTCOME:
			var o: Dictionary = exchange.outcomes[chosen]
			if not _applied and t >= float(o.impact):
				_applied = true
				_land(o)
			if t >= clip_len:
				_after_outcome(o)
		S.OPEN:
			if t >= float(def.open.max_time):
				_show(S.RECOVER, str(def.open.recover.clip), false)
				prepare.emit(["idle", "a_tele", "b_tele"])
		S.COUNTER:
			if not _applied and t >= float(def.open.counter.impact):
				_applied = true
				_hurt_boss()
			if t >= clip_len:
				_enter_ready()
		S.RECOVER:
			if t >= clip_len:
				_enter_ready()
		S.VICTORY:
			if not _applied and t >= float(def.open.victory.impact):
				_applied = true
				_hurt_boss()
			if t >= clip_len:
				_finish(true)
		S.DEFEAT:
			if t >= clip_len:
				_finish(false)

func _finish(won: bool) -> void:
	if state == S.DONE:
		return
	state = S.DONE
	finished.emit(won)

func _enter_ready() -> void:
	var waits: Array = def.ready_waits
	_wait = float(waits[0]) if phase >= 2 else float(waits[rng.randi() % waits.size()])
	_show(S.READY, "idle", true)
	prepare.emit(["a_tele", "b_tele", "idle"])

func _begin_exchange() -> void:
	var pool: Array = def.exchanges
	var total := 0.0
	for e in pool:
		total += float(e.weight) * (0.35 if e.id == _last_exchange else 1.0)
	var roll := rng.randf() * total
	exchange = pool[-1]
	for e in pool:
		roll -= float(e.weight) * (0.35 if e.id == _last_exchange else 1.0)
		if roll <= 0.0:
			exchange = e
			break
	_last_exchange = exchange.id
	chosen = ""
	perfect = false
	stats.exchanges += 1
	_show(S.TELE, str(exchange.tele), false)
	var likely: Array = []
	for k in exchange.outcomes:
		likely.append(exchange.outcomes[k].clip)
	prepare.emit(likely)
	_emit(&"telegraph", {"exchange": exchange})

func _branch() -> void:
	if chosen == "":
		if block_held and exchange.inputs.has("block"):
			var cost := float(exchange.guard)
			if stamina >= cost:
				stamina -= cost
				chosen = "block"
			else:
				stamina = 0.0
				chosen = "hit"
				_emit(&"guard_break")
		else:
			chosen = "hit"
	var o: Dictionary = exchange.outcomes[chosen]
	_emit(&"branch", {"outcome": chosen, "perfect": perfect})
	_show(S.OUTCOME, str(o.clip), false)
	prepare.emit(["open", "counter", "recover", "victory"] if str(o.exit) == "open" else ["idle", "defeat", "a_tele", "b_tele"])

func _land(o: Dictionary) -> void:
	match chosen:
		"parry":
			stats.parries += 1
		"dodge":
			stats.dodges += 1
		"block":
			stats.blocks += 1
			hp = maxf(1.0, hp - float(exchange.damage) * 0.08)
		"hit":
			stats.hits_taken += 1
			var dmg := float(exchange.damage) * (1.25 if phase >= 2 else 1.0) * (1.0 - mitigation)
			hp = maxf(0.0, hp - dmg)
	_emit(&"impact", {"outcome": chosen, "perfect": perfect, "sfx": o.get("sfx", ""), "hp": hp})

func _after_outcome(o: Dictionary) -> void:
	if hp <= 0.0:
		_show(S.DEFEAT, str(def.defeat.clip), false)
		return
	if str(o.exit) == "open":
		_bonus = 1.5 if perfect else 1.0
		_counter_used = false
		_show(S.OPEN, str(def.open.clip), true)
		prepare.emit(["counter", "recover", "victory"])
		_emit(&"opening", {"perfect": perfect})
	else:
		_enter_ready()

func _hurt_boss() -> void:
	boss_hp = maxf(0.0, boss_hp - _pending_damage)
	var dealt := _pending_damage
	_pending_damage = 0.0
	if phase == 1 and boss_hp > 0.0 and boss_hp <= boss_hp_max * float(def.phase2_at):
		phase = 2
		_emit(&"phase", {"phase": 2})
	_emit(&"boss_hit", {"dmg": dealt, "hp": boss_hp, "crit": _bonus > 1.0})
