class_name DuelSim
extends RefCounted
## Pure-logic duel simulation. No nodes, no rendering: the presentation layer
## listens to `ev` and reads state. Everything here is unit-testable headless.

signal ev(name: StringName, d: Dictionary)

const DIRS := {
	"L": Vector2(-1, 0), "R": Vector2(1, 0), "U": Vector2(0, 1), "D": Vector2(0, -1),
	"UL": Vector2(-0.7071, 0.7071), "UR": Vector2(0.7071, 0.7071),
	"DL": Vector2(-0.7071, -0.7071), "DR": Vector2(0.7071, -0.7071),
}

# --- tuning (seconds) -------------------------------------------------------
const PARRY_WINDOW := 0.30
const PARRY_PERFECT := 0.12
const PARRY_LOCK := 0.28        # how long a parry swing commits the player
const PARRY_WHIFF := 0.25       # extra recovery when the parry meets nothing
const PARRY_COST := 6.0
const DODGE_TIME := 0.55
const DODGE_IFRAME_START := 0.03
const DODGE_IFRAME_END := 0.42
const DODGE_PERFECT := 0.20
const DODGE_COST := 14.0
const HURT_TIME := 0.42
const STUN_TIME := 1.3
const BUFFER_TIME := 0.18
const STAMINA_DELAY := 0.7
const ADVANCE_TIME := 0.35
const STAGGER_PARRY := 1.9
const STAGGER_BREAK := 3.2
const SHIFT_TIME := 2.4
const COMBO_STEP := 0.12
const COMBO_MAX := 6
const RIFT_MULT := 1.6
const DRAIN_STAMINA := 28.0

enum P { FREE, SWING, PARRY, DODGE, HURT, STUN, ADVANCE, DEAD }
enum B { IDLE, WINDUP, RECOVER, STAGGER, SHIFT, DEAD }

var rng := RandomNumberGenerator.new()
var time := 0.0
var over := false
var assist := 1.0   # >1 widens timing windows (accessibility setting)

# player
var pl := {}
var p_state: int = P.FREE
var p_t := 0.0           # time left in state
var p_elapsed := 0.0     # time spent in state
var p_block := false
var p_dodge_side := 0
var p_swing := {}        # pending attack swing {dir, contact, landed}
var p_parry := {}        # {t, dir}
var p_buffer := {}       # {kind, arg, t}
var p_regen_wait := 0.0
var p_combo := 0
var p_last_dir := ""
var p_counter := false   # next hit boosted (earned by perfect dodge)
var p_frost := 0.0
var p_frostbite := 0.0
var p_burn := 0.0

# boss
var bd := {}
var b_hp := 0.0
var b_hp_max := 0.0
var b_posture := 0.0
var b_state: int = B.IDLE
var b_t := 0.0
var b_phase := 0
var b_far := false
var b_combo := {}
var b_idx := 0
var b_attack := {}
var b_windup_total := 0.0
var b_last_combo := ""
var b_reckless := 0
var b_dmg_mult := 1.0
var b_speed := 1.0
var b_opening_crit := false
## Surge: a meter earned by fighting well; spend it to stun the foe outright.
var surge := 0.0
## Relic: charges slowly over the fight; spend it to mend wounds.
var relic := 0.0
const SURGE_MAX := 100.0
const RELIC_MAX := 100.0
const RELIC_RATE := 3.4          # per second: full in about half a minute
const RELIC_HEAL := 0.35
const SURGE_STUN := 2.6
## Three-cut patterns that end in a named, heavier blow.
const COMBOS := {
	"Cross Cut": [["L", "R", "L"], ["R", "L", "R"], 1.5],
	"Hammerfall": [["U", "D", "U"], ["D", "U", "D"], 1.6],
	"Sundering": [["L", "R", "D"], ["R", "L", "D"], 1.75],
	"Skyward": [["DL", "DR", "U"], ["DR", "DL", "U"], 1.75],
}
var p_hist: Array = []
var rift_dir := ""       # the seam in the foe's guard: cut along it for a telling blow
var rift_count := 0
var habits := {"block": 0.0, "dodge_l": 0.0, "dodge_r": 0.0, "parry": 0.0}
var stats := {"dealt": 0.0, "taken": 0.0, "parries": 0, "perfect_parries": 0, "dodges": 0, "perfect_dodges": 0, "blocks": 0, "hits_taken": 0, "max_combo": 0, "rifts": 0, "surges": 0, "relics": 0, "named": 0}


func setup(player: Dictionary, boss: Dictionary, seed_value: int = 0, opts: Dictionary = {}) -> void:
	rng.seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec())
	pl = player.duplicate(true)
	pl["hp"] = float(opts.get("start_hp", pl.max_hp))
	pl["stamina"] = float(pl.max_stamina)
	bd = boss
	var ng: int = opts.get("ng", 0)
	assist = opts.get("assist", 1.0)
	b_hp_max = float(boss.hp) * (1.0 + 0.6 * ng)
	b_hp = b_hp_max
	b_dmg_mult = 1.0 + 0.35 * ng
	b_speed = minf(1.0 + 0.05 * ng, 1.25)
	b_state = B.IDLE
	b_t = 1.6
	b_phase = 0


# ============================================================ helpers / queries
func phase() -> Dictionary:
	return bd.phases[b_phase]

func boss_open() -> bool:
	return b_state == B.RECOVER or b_state == B.STAGGER

func time_to_impact() -> float:
	return b_t if b_state == B.WINDUP else -1.0

func speed() -> float:
	return float(phase().get("speed", 1.0)) * b_speed

func _emit(n: StringName, d: Dictionary = {}) -> void:
	ev.emit(n, d)

static func dir_vec(d: String) -> Vector2:
	return DIRS.get(d, Vector2.ZERO)

## 2 = squarely against the blow, 1 = glancing but acceptable, 0 = wrong.
static func parry_quality(swipe: String, attack_dir: String) -> int:
	var dot := dir_vec(swipe).dot(-dir_vec(attack_dir))
	if dot > 0.9:
		return 2
	if dot > 0.6:
		return 1
	return 0

## The swipe that squarely parries an attack travelling in `attack_dir`.
static func parry_dir_for(attack_dir: String) -> String:
	var want := -dir_vec(attack_dir)
	for k in DIRS:
		if DIRS[k].dot(want) > 0.9:
			return k
	return "U"


# ============================================================ input
func input_block(down: bool) -> void:
	p_block = down

func input_swipe(dir: String) -> void:
	if over:
		return
	if p_state != P.FREE:
		p_buffer = {"kind": "swipe", "arg": dir, "t": time}
		return
	if b_state == B.WINDUP:
		if pl.stamina < PARRY_COST:
			_emit(&"exhausted")
			return
		_spend(PARRY_COST)
		p_parry = {"t": time, "dir": dir}
		_set_p(P.PARRY, PARRY_LOCK)
		_emit(&"player_parry_swing", {"dir": dir})
		return
	if b_far:
		_set_p(P.ADVANCE, ADVANCE_TIME)
		_emit(&"player_advance")
		return
	if pl.stamina < pl.swing_cost:
		_emit(&"exhausted")
		return
	_spend(pl.swing_cost)
	p_swing = {"dir": dir, "contact": pl.swing_time * 0.6, "landed": false}
	_set_p(P.SWING, pl.swing_time)
	_emit(&"player_swing", {"dir": dir, "time": pl.swing_time})

func _gain_surge(v: float) -> void:
	var was := surge
	surge = minf(SURGE_MAX, surge + v)
	if was < SURGE_MAX and surge >= SURGE_MAX:
		_emit(&"surge_ready")

## Unleash the surge: whatever the foe was doing, it is broken open.
func input_surge() -> bool:
	if over or surge < SURGE_MAX or b_state == B.SHIFT or b_state == B.DEAD or p_state == P.DEAD or p_state == P.STUN:
		return false
	surge = 0.0
	stats.surges += 1
	_emit(&"surge")
	_stagger(SURGE_STUN, false)
	return true

## Spend the relic's charge to close wounds.
func input_relic() -> bool:
	if over or relic < RELIC_MAX or p_state == P.DEAD or pl.hp >= pl.max_hp:
		return false
	relic = 0.0
	stats.relics += 1
	var heal: float = float(pl.max_hp) * RELIC_HEAL
	pl.hp = minf(pl.max_hp, pl.hp + heal)
	p_burn = 0.0
	_emit(&"relic", {"heal": heal})
	return true

func input_dodge(side: int) -> void:
	if over:
		return
	if p_state != P.FREE:
		p_buffer = {"kind": "dodge", "arg": side, "t": time}
		return
	if pl.stamina < 1.0:
		_emit(&"exhausted")
		return
	_spend(DODGE_COST)
	p_dodge_side = side
	_set_p(P.DODGE, DODGE_TIME)
	_emit(&"player_dodge", {"side": side})


# ============================================================ tick
func tick(dt: float) -> void:
	if over:
		return
	time += dt
	if relic < RELIC_MAX:
		relic = minf(RELIC_MAX, relic + RELIC_RATE * dt)
		if relic >= RELIC_MAX:
			_emit(&"relic_ready")
	_tick_player(dt)
	_tick_boss(dt)

func _set_p(s: int, t: float) -> void:
	p_state = s
	p_t = t
	p_elapsed = 0.0

func _spend(amount: float) -> void:
	pl.stamina = maxf(0.0, pl.stamina - amount)
	p_regen_wait = STAMINA_DELAY * (1.6 if pl.stamina <= 0.0 else 1.0)

func _tick_player(dt: float) -> void:
	if p_state == P.DEAD:
		return
	# statuses
	if p_frostbite > 0.0:
		p_frostbite -= dt
		if p_frostbite <= 0.0:
			_emit(&"status_end", {"status": "frostbite"})
	else:
		p_frost = maxf(0.0, p_frost - 4.0 * dt)
	if p_burn > 0.0:
		p_burn -= dt
		_damage_player(pl.max_hp * 0.02 * dt, true)
		if p_state == P.DEAD:
			return
	# stamina
	if p_regen_wait > 0.0:
		p_regen_wait -= dt
	elif pl.stamina < pl.max_stamina:
		var rate: float = pl.stamina_regen
		if p_block and p_state == P.FREE:
			rate *= 0.25
		if p_frostbite > 0.0:
			rate *= 0.4
		pl.stamina = minf(pl.max_stamina, pl.stamina + rate * dt)
	# state timers
	if p_state == P.FREE:
		return
	p_elapsed += dt
	p_t -= dt
	if p_state == P.SWING and not p_swing.landed and p_elapsed >= p_swing.contact:
		p_swing.landed = true
		_resolve_player_hit(p_swing.dir)
	if p_t <= 0.0:
		var was := p_state
		if was == P.PARRY and not p_parry.is_empty():
			# the parry swing ended without meeting a blade: overcommitted
			p_parry = {}
			_spend(4.0)
			_set_p(P.HURT, PARRY_WHIFF)
			_emit(&"parry_whiff")
			return
		if was == P.ADVANCE:
			b_far = false
		_set_p(P.FREE, 0.0)
		if not p_buffer.is_empty() and time - p_buffer.t <= BUFFER_TIME:
			var b := p_buffer
			p_buffer = {}
			if b.kind == "swipe":
				input_swipe(b.arg)
			else:
				input_dodge(b.arg)
		p_buffer = {}

func _resolve_player_hit(dir: String) -> void:
	if b_state == B.DEAD:
		return
	if boss_open():
		var mult := 1.0
		if p_last_dir != "" and dir == p_last_dir:
			mult = 0.45   # predictable: the same cut twice glances off
		else:
			p_combo = mini(p_combo + 1, COMBO_MAX)
			mult = 1.0 + COMBO_STEP * (p_combo - 1)
		p_last_dir = dir
		stats.max_combo = maxi(stats.max_combo, p_combo)
		var crit := b_opening_crit
		if crit:
			mult *= pl.crit_mult
		if p_counter:
			mult *= 1.5
			p_counter = false
		# named combos: the third cut of a known pattern lands much harder
		p_hist.append(dir)
		var named := ""
		if p_hist.size() >= 3:
			var last: Array = p_hist.slice(p_hist.size() - 3)
			for cname in COMBOS:
				if last == COMBOS[cname][0] or last == COMBOS[cname][1]:
					named = cname
					mult *= float(COMBOS[cname][2])
					stats.named += 1
					p_hist.clear()
					break
		var on_rift := rift_dir != "" and dir == rift_dir
		if on_rift:
			mult *= RIFT_MULT
			stats.rifts += 1
		var elem: bool = pl.element != null and pl.element == bd.get("weak")
		if elem:
			mult *= 1.25
		var dmg: float = pl.attack * mult * (1.0 - float(bd.get("armor", 0.0))) * rng.randf_range(0.95, 1.05)
		_gain_surge(7.0 + (6.0 if named != "" else 0.0))
		_damage_boss(dmg, {"dir": dir, "crit": crit, "combo": p_combo, "weak": elem, "rift": on_rift, "named": named})
		if on_rift and boss_open():
			_next_rift()
	elif b_state == B.SHIFT:
		_emit(&"deflected", {"dir": dir, "dmg": 0.0})
	else:
		# boss is guarding: chip damage, and recklessness is remembered
		var chip: float = pl.attack * 0.12
		b_reckless += 1
		_spend(pl.swing_cost * 0.75)   # the recoil off a raised guard is tiring
		_emit(&"deflected", {"dir": dir, "dmg": chip})
		_damage_boss(chip, {"dir": dir, "chip": true})
		if b_state == B.IDLE and b_reckless >= int(bd.get("patience", 3)):
			b_reckless = 0
			_start_combo({"id": "punish", "attacks": [bd.punish], "recover": 0.9, "tags": [], "gap": 0.1}, true)

func _damage_boss(dmg: float, info: Dictionary) -> void:
	var floor_hp := 0.0
	if b_phase + 1 < bd.phases.size():
		floor_hp = b_hp_max * float(bd.phases[b_phase + 1].at)
	b_hp = maxf(floor_hp, b_hp - dmg)
	stats.dealt += dmg
	info["dmg"] = dmg
	info["hp"] = b_hp
	if not info.get("chip", false):
		_emit(&"boss_hit", info)
		_add_posture(4.0)
	if b_hp <= floor_hp and b_phase + 1 < bd.phases.size():
		b_phase += 1
		var revive: float = float(phase().get("revive", 0.0))
		if revive > 0.0:
			# it falls, and gets up again
			b_hp = b_hp_max * revive
		b_state = B.SHIFT
		b_t = SHIFT_TIME
		b_posture = 0.0
		b_far = false
		_end_opening()
		_emit(&"phase_change", {"phase": b_phase, "roar": phase().get("roar", ""), "revive": float(phase().get("revive", 0.0)) > 0.0})
	elif b_hp <= 0.0:
		b_state = B.DEAD
		over = true
		_emit(&"boss_dead", {"dir": info.get("dir", "D")})

func _add_posture(v: float) -> void:
	if b_state == B.STAGGER or b_state == B.SHIFT or b_state == B.DEAD:
		return
	b_posture += v
	if b_posture >= float(bd.posture):
		b_posture = 0.0
		_stagger(STAGGER_BREAK, true)

func _stagger(t: float, broke: bool) -> void:
	b_state = B.STAGGER
	b_t = t
	b_opening_crit = true
	b_far = false
	_emit(&"boss_stagger", {"time": t, "break": broke})
	_next_rift()

## Each opening shows a seam; striking along it opens the next one elsewhere.
func _next_rift() -> void:
	var keys: Array = DIRS.keys()
	var pick: String = rift_dir
	while pick == rift_dir or pick == p_last_dir:
		pick = keys[rng.randi() % keys.size()]
	rift_dir = pick
	rift_count += 1
	_emit(&"rift", {"dir": rift_dir})

func _end_opening() -> void:
	if rift_dir != "":
		rift_dir = ""
		_emit(&"rift", {"dir": ""})
	p_hist.clear()
	p_combo = 0
	p_last_dir = ""
	b_opening_crit = false


# ------------------------------------------------------------ boss
func _tick_boss(dt: float) -> void:
	if b_state == B.DEAD or p_state == P.DEAD:
		return
	b_t -= dt
	match b_state:
		B.IDLE:
			b_posture = maxf(0.0, b_posture - 3.0 * dt)
			if b_t <= 0.0:
				_start_combo(_choose_combo(), false)
		B.WINDUP:
			if b_t <= 0.0:
				_resolve_strike()
		B.RECOVER, B.STAGGER:
			if b_t <= 0.0:
				_end_opening()
				_go_idle()
		B.SHIFT:
			if b_t <= 0.0:
				_emit(&"phase_ready", {"phase": b_phase})
				_go_idle(0.6)

func _go_idle(t: float = -1.0) -> void:
	b_state = B.IDLE
	var idle: Array = bd.idle
	b_t = t if t >= 0.0 else rng.randf_range(idle[0], idle[1]) / speed()
	_emit(&"boss_idle", {"far": b_far})

func _share(k: String) -> float:
	var total := 0.0
	for h in habits:
		total += habits[h]
	return 0.0 if total < 0.5 else habits[k] / total

func combo_weight(c: Dictionary) -> float:
	var w := float(c.w)
	if c.id == b_last_combo:
		w *= 0.3
	var adapt := float(bd.get("adapt", 1.0)) * 2.0
	for tag in c.tags:
		match tag:
			"anti_block": w *= 1.0 + adapt * _share("block")
			"anti_dodge": w *= 1.0 + adapt * (_share("dodge_l") + _share("dodge_r"))
			"anti_parry": w *= 1.0 + adapt * _share("parry")
	return w

func _choose_combo() -> Dictionary:
	for h in habits:
		habits[h] *= 0.85
	var want := "far" if b_far else "near"
	var pool: Array = []
	var total := 0.0
	for c in phase().combos:
		var r: String = c.get("range", "near")
		if r != want and r != "any":
			continue
		var w := combo_weight(c)
		pool.append([c, w])
		total += w
	if pool.is_empty():
		# nothing reaches from here: close the distance and pick again
		b_far = false
		_emit(&"boss_close")
		return _choose_combo()
	var roll := rng.randf() * total
	for e in pool:
		roll -= e[1]
		if roll <= 0.0:
			return e[0]
	return pool[-1][0]

func _start_combo(c: Dictionary, punish: bool) -> void:
	b_combo = c
	b_idx = 0
	if not punish:
		b_last_combo = c.id
		b_reckless = 0
	_emit(&"boss_combo", {"id": c.id, "punish": punish})
	_start_attack()

func _start_attack() -> void:
	b_attack = b_combo.attacks[b_idx]
	var w: float = float(b_attack.windup) / speed()
	if b_idx > 0:
		w += float(b_combo.get("gap", 0.15))
	b_state = B.WINDUP
	b_t = w
	b_windup_total = w
	_emit(&"boss_telegraph", {"attack": b_attack, "windup": w, "index": b_idx, "count": b_combo.attacks.size()})

func _resolve_strike() -> void:
	var a := b_attack
	var dmg: float = float(a.dmg) * b_dmg_mult
	var result := "hit"
	var perfect := false
	# --- dodge
	if p_state == P.DODGE and p_elapsed >= DODGE_IFRAME_START and p_elapsed <= DODGE_IFRAME_END * assist:
		var need: String = a.dodge
		var side := "L" if p_dodge_side < 0 else "R"
		if need == "any" or need == side:
			result = "dodged"
			perfect = p_elapsed <= DODGE_PERFECT * assist
	# --- parry
	if result == "hit" and p_state == P.PARRY and not p_parry.is_empty() and a.parry:
		var age: float = time - float(p_parry.t)
		var q := parry_quality(p_parry.dir, a.dir)
		if age <= PARRY_WINDOW * assist and q > 0:
			result = "parried"
			perfect = q == 2 and age <= PARRY_PERFECT * assist
	# --- block
	if result == "hit" and p_block and p_state == P.FREE and not a.unblockable:
		result = "blocked"
	match result:
		"dodged":
			_gain_surge(10.0 if perfect else 5.0)
			habits["dodge_l" if p_dodge_side < 0 else "dodge_r"] += 1.0
			stats.dodges += 1
			if perfect:
				stats.perfect_dodges += 1
				p_counter = true
				pl.stamina = minf(pl.max_stamina, pl.stamina + DODGE_COST)
		"parried":
			_gain_surge(18.0 if perfect else 9.0)
			p_parry = {}
			habits.parry += 1.0
			stats.parries += 1
			_set_p(P.FREE, 0.0)
			pl.stamina = minf(pl.max_stamina, pl.stamina + PARRY_COST)
			if perfect:
				stats.perfect_parries += 1
		"blocked":
			_gain_surge(4.0)
			habits.block += 1.0
			stats.blocks += 1
			var cost: float = float(a.guard) * (1.0 - float(pl.block_eff))
			var broke: bool = pl.stamina - cost <= 0.0
			_spend(cost)
			_apply_element(a, 0.5)
			if a.get("drain", false):
				_drain(dmg * 0.4)
			if broke:
				result = "guard_break"
				_damage_player(dmg * 0.5)
				if p_state != P.DEAD:
					_set_p(P.STUN, STUN_TIME)
			else:
				_damage_player(dmg * 0.08 * (1.0 - float(pl.block_eff)), true)
		"hit":
			_gain_surge(9.0)
			p_parry = {}
			stats.hits_taken += 1
			_apply_element(a, 1.0)
			if a.get("drain", false):
				_drain(dmg)
			_damage_player(dmg)
			if p_state != P.DEAD:
				_set_p(P.HURT, HURT_TIME)
			_end_opening()
	_emit(&"boss_strike", {"attack": a, "result": result, "perfect": perfect})
	if p_state == P.DEAD:
		return
	# --- what the boss does next
	if result == "parried":
		if perfect:
			_stagger(STAGGER_PARRY, false)
			return
		_add_posture(18.0)
		if b_state == B.STAGGER:
			return
	b_idx += 1
	if b_idx < b_combo.attacks.size():
		_start_attack()
		return
	var rec: float = float(b_combo.recover) / speed()
	if result == "dodged" and perfect:
		rec += 0.6
	if b_combo.get("retreat", false):
		b_far = true
		_emit(&"boss_retreat")
	b_state = B.RECOVER
	b_t = rec
	b_opening_crit = false
	_emit(&"boss_recover", {"time": rec, "far": b_far})
	if not b_far:
		_next_rift()

## Soul-eaters feed: a blow that lands restores them and empties you.
func _drain(amount: float) -> void:
	b_hp = minf(b_hp_max, b_hp + amount * 1.5)
	pl.stamina = maxf(0.0, pl.stamina - DRAIN_STAMINA)
	p_regen_wait = STAMINA_DELAY * 1.5
	_emit(&"status", {"status": "drain", "amount": amount})

func _apply_element(a: Dictionary, scale: float) -> void:
	var e = a.get("element")
	if e == null:
		return
	var through: float = scale * (1.0 - clampf(float(pl.resist) / 100.0, 0.0, 0.85))
	if e == "frost" and p_frostbite <= 0.0:
		p_frost += 40.0 * through
		if p_frost >= 100.0:
			p_frost = 0.0
			p_frostbite = 6.0
			_emit(&"status", {"status": "frostbite"})
	elif e == "fire" and through > 0.3:
		p_burn = 2.5 * through
		_emit(&"status", {"status": "burn"})

func _damage_player(raw: float, quiet: bool = false) -> void:
	var dmg: float = raw if quiet else raw * (1.0 - float(pl.mitigation))
	pl.hp = maxf(0.0, pl.hp - dmg)
	stats.taken += dmg
	if not quiet:
		_emit(&"player_hurt", {"dmg": dmg, "hp": pl.hp})
	if pl.hp <= 0.0:
		p_state = P.DEAD
		over = true
		_emit(&"player_dead")
