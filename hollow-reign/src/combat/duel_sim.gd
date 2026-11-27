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
## A second tap on the same side during a sidestep turns it into a roll: further, safe for longer, dearer.
const ROLL_WINDOW := 0.3
const ROLL_EXTRA_TIME := 0.35
const ROLL_EXTRA_COST := 8.0
const HURT_TIME := 0.42
const STUN_TIME := 1.3
const BUFFER_TIME := 0.18
## Free cutting. A cut's time is the weapon's swing stat; its blade lands at CONTACT_FRAC of it, and from CANCEL_FRAC
## on, the rest (the recovery) is cut short by a queued swipe or dodge, or by the shield going up: so a flurry lands
## one cut every swing_time * CANCEL_FRAC seconds (0.22 s with a 0.26 s sword, 0.39 s with a 0.46 s greatsword).
## One input is queued, the latest wins, and one queued during a cut never goes stale before that cut's cancel frame.
const CONTACT_FRAC := 0.6
const CANCEL_FRAC := 0.85
const BUFFER_SWING := 0.75
const COMBO_PAUSE := 0.9         # seconds without a cut landing after which the variety count starts over
const COMBO_POISE := 0.15        # more poise wear per cut for each step of the variety count
const TIRED_MULT := 0.5          # a cut thrown without the stamina for it still lands, at this share of its damage,
const TIRED_SLOW := 1.4          # and takes this much longer
const COUNTER_MULT := 2.0        # the first cut along the shown line in an opening a parry earned (in place of RIFT_MULT)
const WHIFF_CHIP := 0.06         # share of attack a parry cut that met no blade still scores off the foe's guard
const GUARD_BREAK_STUN := 0.9    # seconds the knight reels when the guard is broken
const GUARD_BREAK_DMG := 0.5     # share of the blow that lands through a broken guard
const BLOCK_SHIELD_COST := 0.5   # share of a block's stamina cost paid while the shield still has a charge to take the blow
const BLOCK_LATE := 0.25         # a shield raised this soon after a blow has landed was raised too late
const STAMINA_DELAY := 0.7
const ADVANCE_TIME := 0.35
const STAGGER_PARRY := 1.9
const STAGGER_BREAK := 3.2
const SHIFT_TIME := 2.4
const COMBO_STEP := 0.12
const COMBO_MAX := 6
const RIFT_MULT := 1.6
const DRAIN_STAMINA := 28.0
## Poise: what a foe's composure is worth (bosses.json "poise"). Successful defences wear it down;
## only when it is gone does the foe break open. A defence that does not break it buys a short recovery.
const POISE_PARRY_PERFECT := 45.0
const POISE_PARRY := 28.0
const POISE_DODGE_PERFECT := 22.0
const POISE_DODGE := 12.0
const POISE_BLOCK_TIMED := 25.0
const POISE_BLOCK := 6.0
const POISE_CUT := 3.0           # each cut landed in an opening
const POISE_REGEN := 2.0         # per second, only while it stands unpressed (IDLE)
const SHORT_RECOVER := 0.42      # share of a combo's own `recover` the foe stands open after an unbroken string
const SHORT_RECOVER_MIN := 0.5   # never less than one cut's worth
const RIPOSTE_TIME := 1.0        # a perfect parry cuts the string short: room for a cut or two, not a full opening
const PRESS_IDLE_MIN := 0.25     # "pressure": the pause before it chains straight into another string
const PRESS_IDLE_MAX := 0.45
## Blade struggle: now and then a parried heavy blow locks blades; rapid taps decide it.
const STRUGGLE_CHANCE := 0.3
const STRUGGLE_TIME := 2.2
const STRUGGLE_COOLDOWN := 20.0
const STRUGGLE_STUN := 0.7
const STRUGGLE_DMG := 0.5        # share of the locked blow's damage taken on losing

enum P { FREE, SWING, PARRY, DODGE, HURT, STUN, ADVANCE, DEAD, STRUGGLE }
enum B { IDLE, WINDUP, RECOVER, STAGGER, SHIFT, DEAD, STRUGGLE }

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
var p_roll := false
var p_swing := {}        # pending attack swing {dir, contact, landed}
var p_parry := {}        # {t, dir}
var p_buffer := {}       # {kind, arg, t}
var p_regen_wait := 0.0
var p_combo := 0
var p_last_dir := ""
var p_same := 0          # cuts thrown along the same line running
var _countered := false  # the counter of this opening has been taken
var _last_hit_t := -9.0  # when a blow last landed on the knight
var _queued_open := false    # the queued swipe now being thrown was made while the foe stood open
var _shield_reset := false   # a shield beaten down comes back whole once the knight has recovered from the break
var p_counter := false   # next hit boosted (earned by perfect dodge)
var p_frost := 0.0
var p_frostbite := 0.0
var p_burn := 0.0

# boss
var bd := {}
var b_hp := 0.0
var b_hp_max := 0.0
var b_poise := 0.0             # what is left of its composure; 0 = broken
var b_poise_max := 1.0
var s_need := 0                # blade struggle: taps needed, taps made
var s_taps := 0
var force_struggle := false    # dev/tests: every eligible parry locks blades
var paused := false            # a story beat holds the whole fight exactly where it is
var _struggle_last := -99.0
var _beat_sent := false
## Story beats: the phase indices at whose start `story_beat {foe, phase}` is sent (opts or the foe's `beat_at`;
## [1] when neither says), and a share of the player's health at which one is sent too (`beat_hp`, `low: true`).
var beat_at: Array = [1]
var beat_hp := 0.0
var _beats := {}
## A story-ended fight (opts or the foe's `end_on {cuts, not_before, release, floor}`): the duel is handed back to
## the story on the cut that makes `cuts` landed once `not_before` seconds have passed ("ahead"), or at `release`
## seconds ("even" with a cut landed, "behind" with none), or when a blow would take the player under `floor` of
## their health. It is neither won nor lost: `interrupted` says how it stood, and `story_end {how}` is sent once.
var end_on := {}
var interrupted := ""
var cuts_landed := 0
## The seal: a phase's restoration, undone by what the player does in that phase. `seal {phase, need, parry,
## perfect, rift, fell, marked, disables}` (opts, or `seal` on the phase itself). While it holds, a foe felled in
## that phase is stood up again at the phase's `revive` share; each parry, each cut along the seam and each time it
## is felled wears the seal down; once it is gone the traits in `disables` (lifesteal) stop and it can die.
var seal := {}
var seal_need := 0
var seal_left := 0
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
## The combo library (data/combos.json), filtered to the weapon in hand. Set by setup().
var combos: Array = []
var training := false
var lesson_fights := true    # in a lesson: false holds the foe open (cutting practice), true lets it attack
var lesson := false          # onboarding: the foe attacks plainly and nothing can die
var _last_cut_t := 0.0
var opening_from := ""        # what earned the current opening: "parry", "perfect", "dodge", "break", "surge", ""
var _last_combo_id := ""
var p_block_dropped := -9.0
var p_block_fresh := true
var p_block_since := -9.0     # when the shield went up, for timed blocks
## Blocking. A blockable blow caught on a raised guard costs NO health: it costs stamina (`guard` of the blow, less
## `block_eff`; BLOCK_SHIELD_COST of that behind a shield with a charge left) and one of the shield's charges (`shield_blocks`, player stat; 0 = no count, as with a two-handed
## blade). One charge returns for every `shield_regen` seconds the guard is down. A guard raised within PERFECT_BLOCK
## of the blow (from rest) is a perfect block: no cost at all, more poise wear, a longer opening after the string.
## With no charge left, or not the stamina to pay, the guard BREAKS: GUARD_BREAK_DMG of the blow lands and the knight
## reels for GUARD_BREAK_STUN (a shield beaten down this way is whole again when the knight recovers). An unblockable blow ignores the guard and is announced when it is wound up.
## Events: `block {attack, cost, left}`, `perfect_block {attack}`, `guard_break {attack, why: "shield"|"stamina", dmg}`,
## `block_failed {why: "unblockable"|"busy"|"late"}`, `parry_failed {why: "dir"|"late"|"unparryable"}`,
## `unblockable_warning {attack, windup}`, and `shield_charges {left, max}`.
var p_shield := 0
var p_shield_max := 0
var p_shield_idle := 0.0
var p_move_cost := 1.0        # player stat `dodge_cost`: what the shield on the arm does to the price of a dodge or roll
var p_guard_dmg := 1.0        # player stat `guard_dmg`: what a cut does to a raised guard, and to poise
const PERFECT_BLOCK := 0.22
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
	p_shield_max = int(pl.get("shield_blocks", 0))
	p_shield = p_shield_max
	p_shield_idle = 0.0
	p_move_cost = float(pl.get("dodge_cost", 1.0))
	p_guard_dmg = float(pl.get("guard_dmg", 1.0))
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
	b_poise_max = maxf(1.0, float(boss.get("poise", boss.get("posture", 100.0))))
	b_poise = b_poise_max
	beat_at = opts.get("beat_at", boss.get("beat_at", [1]))
	beat_hp = float(opts.get("beat_hp", boss.get("beat_hp", 0.0)))
	end_on = opts.get("end_on", boss.get("end_on", {}))
	seal = opts.get("seal", {})
	_arm_seal()
	combos = []
	for c in opts.get("combos", []):
		if c.cls.is_empty() or c.cls.has(str(pl.get("weapon_cls", "sword"))):
			combos.append(c)
	if opts.get("lesson", false):
		lesson = true
		lesson_fights = false
	if opts.get("training", false) or lesson:
		# practice: the foe stands open and cannot be killed
		b_state = B.RECOVER
		b_t = 1.0e9
		b_hp_max = 1.0e9
		b_hp = b_hp_max
		training = true


# ============================================================ helpers / queries
func phase() -> Dictionary:
	return bd.phases[b_phase]

func boss_open() -> bool:
	return b_state == B.RECOVER or b_state == B.STAGGER

func poise_frac() -> float:
	return clampf(b_poise / b_poise_max, 0.0, 1.0)

## Blades can only lock with something that holds a blade: not dragons, not things with claws.
func struggle_capable() -> bool:
	return str(bd.rig.get("kind", "")) != "dragon" and str(bd.rig.get("weapon", "")) != "claws"

## A committed, weighty blow: a slam, or a long-wound cut or sweep.
static func heavy_attack(a: Dictionary) -> bool:
	var kind := str(a.get("kind", ""))
	return kind == "slam" or (kind in ["slash", "sweep"] and float(a.windup) >= 1.2)

## Taps needed to win a struggle: more against bosses, big foes and later journeys; fewer with assist on.
func struggle_need() -> int:
	var n := 6.0 + (2.0 if bd.get("boss", false) else 0.0) + floorf(maxf(0.0, float(bd.rig.get("scale", 1.0)) - 1.0) / 0.25) + (b_dmg_mult - 1.0) / 0.35
	return clampi(roundi(n / assist), 5, 11)

## The single plain cut the lesson foe throws.
func lesson_attack() -> Dictionary:
	for c in phase().combos:
		if c.attacks.size() == 1 and not c.attacks[0].unblockable and c.get("range", "near") != "far":
			return c.attacks[0]
	return {}

## Lesson only: the ring a step is about to name is full when the step begins, and for the relic's step the knight
## is a little hurt so that mending shows. Does nothing outside the lesson.
func lesson_charge(what: String) -> void:
	if not lesson:
		return
	if what == "surge":
		surge = SURGE_MAX
	elif what == "relic":
		relic = RELIC_MAX
		pl.hp = minf(pl.hp, float(pl.max_hp) * 0.7)

## Lesson only: stand the foe open for cutting practice, or set it attacking again.
func lesson_hold(open: bool) -> void:
	if not lesson or b_state == B.STRUGGLE:
		return
	lesson_fights = not open
	b_far = false
	if open:
		b_state = B.RECOVER
		b_t = 1.0e9
		b_opening_crit = false
		_emit(&"boss_recover", {"time": b_t, "far": false})
	else:
		_end_opening()
		_go_idle(0.8)

func time_to_impact() -> float:
	return b_t if b_state == B.WINDUP else -1.0

func speed() -> float:
	# frenzy: the more it bleeds, the faster it comes
	return float(phase().get("speed", 1.0)) * b_speed * (1.0 + trait_v("frenzy") * (1.0 - b_hp / maxf(b_hp_max, 1.0)))

## Per-foe rule changes (bosses.json "traits"), 0 when the foe has none:
## frenzy, block_tax, marks + mark_mult, parry_open, dodge_open, lifesteal.
var marks := 0
func trait_v(key: String) -> float:
	if seal_need > 0 and seal_left <= 0 and key in seal_now().get("disables", ["lifesteal"]):
		return 0.0                    # the seal is broken: what it fed no longer feeds
	var own: Dictionary = bd.phases[b_phase].get("traits", {}) if bd.has("phases") else {}
	if own.has(key):
		return float(own[key])        # a phase may carry its own rules (phases[i].traits)
	return float(bd.get("traits", {}).get(key, 0.0))

## The seal that belongs to the phase being fought ({} for none).
func seal_now() -> Dictionary:
	if not seal.is_empty() and int(seal.get("phase", -1)) == b_phase:
		return seal
	return bd.phases[b_phase].get("seal", {}) if bd.has("phases") else {}

func seal_active() -> bool:
	return seal_need > 0 and seal_left > 0

func _arm_seal() -> void:
	var s := seal_now()
	seal_need = 0 if training else maxi(0, int(s.get("need", 0)))
	seal_left = seal_need
	if seal_need > 0:
		_emit(&"seal", {"left": seal_left, "need": seal_need, "from": "start"})

## Wears the seal down by `n`. Sends `seal {left, need, from}` and, when none is left, `seal_broken`.
func _seal_hit(n: int, from: String) -> void:
	if not seal_active() or n <= 0:
		return
	seal_left = maxi(0, seal_left - n)
	stats["seals"] = int(stats.get("seals", 0)) + 1
	_emit(&"seal", {"left": seal_left, "need": seal_need, "from": from})
	if seal_left <= 0:
		_emit(&"seal_broken", {"from": from})

func _story_end(how: String) -> void:
	if over:
		return
	interrupted = how
	over = true
	_emit(&"story_end", {"how": how, "cuts": cuts_landed, "time": time})

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
	if down and not p_block:
		# only a raise from rest can be a timed block: fluttering the shield earns nothing
		p_block_fresh = time - p_block_dropped >= 0.4
		p_block_since = time
		if time - _last_hit_t <= BLOCK_LATE and not over:
			_emit(&"block_failed", {"why": "late"})
	elif not down and p_block:
		p_block_dropped = time
	p_block = down

## Would adding `dir` to the cuts so far still be the start of a known combo?
func _continues_combo(dir: String) -> bool:
	var want: Array = p_hist + [dir]
	for c in combos:
		var seq: Array = c.seq
		for start in range(maxi(0, want.size() - seq.size()), want.size() - 1):
			var tail: Array = want.slice(start)
			if tail.size() <= seq.size() and seq.slice(0, tail.size()) == tail:
				return true
	return false

## After `done` has landed, is some longer combo still reachable from the cuts so far?
func _could_extend(done: Dictionary) -> bool:
	for c in combos:
		var seq: Array = c.seq
		if seq.size() <= done.seq.size():
			continue
		for k in range(2, mini(p_hist.size(), seq.size() - 1) + 1):
			if p_hist.slice(p_hist.size() - k) == seq.slice(0, k):
				return true
	return false

## The longest combo whose whole sequence is the tail of the cuts so far.
func _completed_combo() -> Dictionary:
	var best := {}
	for c in combos:
		var seq: Array = c.seq
		if p_hist.size() >= seq.size() and p_hist.slice(p_hist.size() - seq.size()) == seq:
			if best.is_empty() or seq.size() > best.seq.size():
				best = c
	return best

## One tap in a blade struggle. Enough of them before the time runs out wins it.
func input_struggle_tap() -> void:
	if over or paused or b_state != B.STRUGGLE:
		return
	s_taps += 1
	_emit(&"struggle_tap", {"n": s_taps, "need": s_need})
	if s_taps >= s_need:
		_end_struggle(true)

func input_swipe(dir: String) -> void:
	if over or p_state == P.STRUGGLE:
		return
	if p_state != P.FREE:
		p_buffer = {"kind": "swipe", "arg": dir, "t": time, "open": boss_open()}
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
	# a cut is always thrown: without the stamina for it, it is a tired one (slower, weaker), never a refusal
	var tired: bool = pl.stamina < pl.swing_cost
	var st: float = float(pl.swing_time) * (TIRED_SLOW if tired else 1.0)
	if tired:
		_emit(&"exhausted")
		if pl.stamina > 0.0:
			_spend(pl.stamina)
	else:
		_spend(pl.swing_cost)
	p_swing = {"dir": dir, "contact": st * CONTACT_FRAC, "cancel": st * CANCEL_FRAC, "landed": false, "tired": tired, "grace": boss_open() or _queued_open}
	_set_p(P.SWING, st)
	# if this cut would complete a combo, say which kind, so the body can throw its signature finish
	var finish := ""
	if boss_open():
		p_hist.append(dir)
		finish = str(_completed_combo().get("kind", ""))
		p_hist.pop_back()
	_emit(&"player_swing", {"dir": dir, "time": st, "finish": finish, "tired": tired, "open": boss_open()})

func _gain_surge(v: float) -> void:
	var was := surge
	surge = minf(SURGE_MAX, surge + v)
	if was < SURGE_MAX and surge >= SURGE_MAX:
		_emit(&"surge_ready")

## Unleash the surge: whatever the foe was doing, it is broken open.
func input_surge() -> bool:
	if over or surge < SURGE_MAX or b_state == B.SHIFT or b_state == B.DEAD or b_state == B.STRUGGLE or p_state == P.DEAD or p_state == P.STUN:
		return false
	surge = 0.0
	opening_from = "surge"
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
	if over or p_state == P.STRUGGLE:
		return
	if p_state == P.DODGE and p_roll:
		return                        # nothing chains out of a roll: it has to end first
	if p_state == P.DODGE and side == p_dodge_side and not p_roll and p_elapsed <= ROLL_WINDOW and pl.stamina >= ROLL_EXTRA_COST * p_move_cost:
		p_roll = true
		p_t += ROLL_EXTRA_TIME
		_spend(ROLL_EXTRA_COST * p_move_cost)
		stats["rolls"] = int(stats.get("rolls", 0)) + 1
		_emit(&"player_roll", {"side": side})
		return
	if p_state != P.FREE:
		p_buffer = {"kind": "dodge", "arg": side, "t": time}
		return
	if pl.stamina < 1.0:
		_emit(&"exhausted")
		return
	_spend(DODGE_COST * p_move_cost)
	p_roll = false
	p_dodge_side = side
	_set_p(P.DODGE, DODGE_TIME)
	_emit(&"player_dodge", {"side": side})


# ============================================================ tick
func tick(dt: float) -> void:
	if over or paused:
		return
	time += dt
	if relic < RELIC_MAX:
		relic = minf(RELIC_MAX, relic + RELIC_RATE * dt)
		if relic >= RELIC_MAX:
			_emit(&"relic_ready")
	_tick_player(dt)
	_tick_boss(dt)
	if over:
		return
	if not end_on.is_empty() and time >= float(end_on.get("release", 1.0e9)):
		_story_end("even" if cuts_landed > 0 else "behind")
	elif beat_hp > 0.0 and not _beats.has("low") and pl.hp <= float(pl.max_hp) * beat_hp and bd.get("boss", false) and not training:
		_beats["low"] = true
		_emit(&"story_beat", {"foe": str(bd.id), "phase": b_phase, "low": true})

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
	# a spent or worn shield comes back while the guard is down
	if p_shield < p_shield_max and not p_block:
		p_shield_idle += dt
		if p_shield_idle >= float(pl.get("shield_regen", 4.0)):
			p_shield_idle = 0.0
			p_shield += 1
			_emit(&"shield_charges", {"left": p_shield, "max": p_shield_max})
	# state timers
	if p_state == P.FREE:
		return
	p_elapsed += dt
	p_t -= dt
	if p_state == P.SWING and not p_swing.landed and p_elapsed >= p_swing.contact:
		p_swing.landed = true
		_resolve_player_hit(p_swing.dir)
	if p_state == P.SWING and p_swing.landed and p_elapsed >= float(p_swing.cancel) and (p_block or not p_buffer.is_empty()):
		p_t = 0.0                     # the cancel frame: what is queued (or the shield) cuts the recovery short
	if p_t <= 0.0:
		var was := p_state
		if was == P.PARRY and not p_parry.is_empty():
			# the parry cut ended without meeting a blade: overcommitted. It is still a cut: it rings off the foe's guard.
			var wdir := str(p_parry.dir)
			p_parry = {}
			_spend(4.0)
			_set_p(P.HURT, PARRY_WHIFF)
			_emit(&"parry_whiff", {"dir": wdir})
			if b_state == B.WINDUP or b_state == B.IDLE:
				var wchip: float = pl.attack * WHIFF_CHIP * p_guard_dmg
				_emit(&"deflected", {"dir": wdir, "dmg": wchip, "whiff": true})
				_damage_boss(wchip, {"dir": wdir, "chip": true})
			return
		if was == P.ADVANCE:
			b_far = false
		if was == P.STUN and _shield_reset:
			# the board is back on the arm after a break: the break itself was the price
			_shield_reset = false
			p_shield = p_shield_max
			p_shield_idle = 0.0
			_emit(&"shield_charges", {"left": p_shield, "max": p_shield_max})
		_set_p(P.FREE, 0.0)
		if not p_buffer.is_empty() and time - p_buffer.t <= (BUFFER_SWING if was == P.SWING else BUFFER_TIME):
			var b := p_buffer
			p_buffer = {}
			if b.kind == "swipe":
				_queued_open = b.get("open", false)
				input_swipe(b.arg)
				_queued_open = false
			else:
				input_dodge(b.arg)
		p_buffer = {}

func _resolve_player_hit(dir: String) -> void:
	if b_state == B.DEAD:
		return
	if boss_open():
		# every cut in an opening lands at least its plain damage, whatever its line. Variety is the bonus: each cut
		# along a new line raises the count; the same line a second time holds it; a third time running (or a pause)
		# starts it over. A known combo may call for a repeated line without losing anything.
		if p_combo > 0 and time - _last_cut_t > COMBO_PAUSE:
			p_combo = 0
			p_same = 0
			p_last_dir = ""
		p_same = p_same + 1 if dir == p_last_dir else 1
		if p_same == 1 or p_last_dir == "" or _continues_combo(dir):
			p_combo = mini(p_combo + 1, COMBO_MAX)
		elif p_same > 2:
			p_combo = 1
		p_combo = maxi(p_combo, 1)
		var mult := 1.0 + COMBO_STEP * (p_combo - 1)
		var tired: bool = p_swing.get("tired", false)
		if tired:
			mult *= TIRED_MULT
		p_last_dir = dir
		stats.max_combo = maxi(stats.max_combo, p_combo)
		var crit := b_opening_crit
		if crit:
			mult *= pl.crit_mult
		if p_counter:
			mult *= 1.5
			p_counter = false
		# combos: the last cut of a known sequence lands as that combo's finishing blow
		p_hist.append(dir)
		_last_cut_t = time
		var named := ""
		var combo_id := ""
		var pierce := false
		var extra_posture := 0.0
		var done := _completed_combo()
		if not done.is_empty() and pl.stamina < float(done.get("stamina_cost", 0)):
			done = {}                 # too spent to throw it: it lands as an ordinary cut
		if not done.is_empty():
			named = done.name
			combo_id = done.id
			var again: bool = combo_id == _last_combo_id
			_last_combo_id = combo_id
			# the same combo twice running in one opening is read: most of its extra weight is lost
			mult *= (1.0 + (float(done.mult) - 1.0) * 0.35) if again else float(done.mult)
			if opening_from == "dodge":
				mult *= float(done.get("after_dodge", 1.0))
			if opening_from in ["parry", "perfect"]:
				mult *= float(done.get("after_parry", 1.0))
			if b_state == B.STAGGER:
				mult *= float(done.get("on_stagger", 1.0)) * float(done.get("crit_bonus", 1.0))
			pierce = bool(done.get("pierce", false))
			extra_posture = float(done.get("posture", 0))
			pl.stamina = clampf(pl.stamina + (0.0 if again else float(done.get("stamina_back", 0))) - float(done.get("stamina_cost", 0)), 0.0, pl.max_stamina)
			stats.named += 1
			if not _could_extend(done):
				p_hist.clear()        # finished: the same tail cannot be cashed in again
		# the shown line is the special chance, never the only way in: along it the cut is a telling blow, and the first
		# such cut of an opening that a parry earned is the counter
		var on_rift := rift_dir != "" and dir == rift_dir
		var counter := on_rift and not _countered and opening_from in ["parry", "perfect"]
		if on_rift:
			mult *= COUNTER_MULT if counter else RIFT_MULT
			if counter:
				_countered = true
				stats["counters"] = int(stats.get("counters", 0)) + 1
			stats.rifts += 1
			_seal_hit(int(seal_now().get("rift", 1)), "rift")
		var elem: bool = pl.element != null and pl.element == bd.get("weak")
		if elem:
			mult *= 1.25
		var dmg: float = pl.attack * mult * (1.0 - (0.0 if pierce else float(bd.get("armor", 0.0)))) * rng.randf_range(0.95, 1.05)
		_gain_surge(7.0 + (6.0 if named != "" else 0.0))
		_damage_boss(dmg, {"dir": dir, "crit": crit, "combo": p_combo, "weak": elem, "rift": on_rift, "counter": counter, "tired": tired, "same": p_same, "named": named, "combo_id": combo_id})
		if extra_posture > 0.0 and b_state == B.RECOVER and _wear_poise(extra_posture, "cut"):
			_poise_break("cut")
		if on_rift and boss_open():
			_next_rift()
	elif b_state == B.SHIFT:
		_emit(&"deflected", {"dir": dir, "dmg": 0.0})
	else:
		# boss is guarding: chip damage, and recklessness is remembered
		var chip: float = pl.attack * 0.12 * p_guard_dmg
		# (a cut begun while the foe stood open, landing as its guard closes, is the tail of a flurry, not recklessness)
		if not p_swing.get("grace", false):
			b_reckless += 1
			_spend(pl.swing_cost * 0.25)   # the recoil off a raised guard is tiring
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
		cuts_landed += 1
		_emit(&"boss_hit", info)
		if b_state == B.RECOVER and _wear_poise(POISE_CUT * p_guard_dmg * (1.0 + COMBO_POISE * maxi(0, p_combo - 1)), "cut"):
			_poise_break("cut")
	if b_hp <= floor_hp and b_phase + 1 < bd.phases.size():
		b_phase += 1
		var revive: float = float(phase().get("revive", 0.0))
		if revive > 0.0:
			# it falls, and gets up again
			b_hp = b_hp_max * revive
		b_state = B.SHIFT
		b_t = SHIFT_TIME
		b_poise = b_poise_max
		_emit(&"poise", {"frac": 1.0, "from": "phase"})
		b_far = false
		_end_opening()
		_emit(&"phase_change", {"phase": b_phase, "roar": phase().get("roar", ""), "revive": float(phase().get("revive", 0.0)) > 0.0})
		_arm_seal()
	elif b_hp <= 0.0:
		if seal_active():
			_seal_hit(int(seal_now().get("fell", 2)), "felled")      # felling it costs the machinery too
		if seal_active():
			# the seal still holds: it is stood up again, and the fight goes on
			b_hp = b_hp_max * float(seal_now().get("restore", phase().get("revive", 0.3)))
			b_state = B.SHIFT
			b_t = SHIFT_TIME
			b_poise = b_poise_max
			b_far = false
			_end_opening()
			stats["restored"] = int(stats.get("restored", 0)) + 1
			_emit(&"restored", {"hp": b_hp, "left": seal_left, "need": seal_need})
			return
		b_state = B.DEAD
		over = true
		_emit(&"boss_dead", {"dir": info.get("dir", "D")})
	if not over and not end_on.is_empty() and not info.get("chip", false) and cuts_landed >= int(end_on.get("cuts", 1 << 30)) and time >= float(end_on.get("not_before", 0.0)):
		_story_end("ahead")           # the story answers a cut that lands, not a health bar

## Wears the foe's poise down by `v`. True when that leaves none: the caller decides when it breaks.
func _wear_poise(v: float, from: String) -> bool:
	if b_state == B.STAGGER or b_state == B.SHIFT or b_state == B.DEAD:
		return false
	if training and (not lesson or not lesson_fights):
		return false                # a practice dummy has no composure to lose
	b_poise = maxf(0.0, b_poise - v)
	_emit(&"poise", {"frac": poise_frac(), "from": from})
	return b_poise <= 0.0

## Poise is gone: the long opening. It comes back whole when the foe recovers.
func _poise_break(from: String) -> void:
	b_poise = 0.0
	stats["breaks"] = int(stats.get("breaks", 0)) + 1
	_emit(&"poise_break", {"from": from})
	_stagger(STAGGER_BREAK, true)

func _begin_struggle() -> void:
	_struggle_last = time
	s_need = struggle_need()
	s_taps = 0
	p_buffer = {}
	b_state = B.STRUGGLE
	b_t = STRUGGLE_TIME
	_set_p(P.STRUGGLE, 1.0e9)
	stats["struggles"] = int(stats.get("struggles", 0)) + 1
	_emit(&"struggle_start", {"need": s_need, "time": STRUGGLE_TIME})

func _end_struggle(won: bool) -> void:
	_set_p(P.FREE, 0.0)
	p_buffer = {}
	_emit(&"struggle_end", {"won": won})
	if won:
		stats["struggles_won"] = int(stats.get("struggles_won", 0)) + 1
		_gain_surge(12.0)
		opening_from = "parry"
		_poise_break("struggle")
		return
	# overpowered: shoved back, briefly stunned, and the foe takes the initiative again
	_end_opening()
	b_state = B.IDLE
	b_t = 0.9
	_damage_player(float(b_attack.dmg) * b_dmg_mult * STRUGGLE_DMG)
	if p_state != P.DEAD:
		_set_p(P.STUN, STRUGGLE_STUN)
		_emit(&"boss_idle", {"far": b_far})

func _stagger(t: float, broke: bool) -> void:
	if opening_from == "":
		opening_from = "break" if broke else "perfect"
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
	_last_combo_id = ""
	opening_from = ""
	p_combo = 0
	p_last_dir = ""
	p_same = 0
	_countered = false
	b_opening_crit = false


# ------------------------------------------------------------ boss
func _tick_boss(dt: float) -> void:
	if b_state == B.DEAD or p_state == P.DEAD:
		return
	b_t -= dt
	match b_state:
		B.STRUGGLE:
			if b_t <= 0.0:
				_end_struggle(false)
		B.IDLE:
			b_poise = minf(b_poise_max, b_poise + POISE_REGEN * dt)
			if b_t <= 0.0:
				_start_combo(_choose_combo(), false)
		B.WINDUP:
			if b_t <= 0.0:
				_resolve_strike()
		B.RECOVER, B.STAGGER:
			if training and (not lesson or not lesson_fights):
				b_t = 1.0e9
				if not p_hist.is_empty() and time - _last_cut_t > 1.5:
					p_hist.clear()      # a pause starts the sequence over
					p_combo = 0
					p_last_dir = ""
					opening_from = ""
					_emit(&"combo_reset")
				if b_state == B.STAGGER:
					b_state = B.RECOVER
					b_opening_crit = false
					_emit(&"boss_recover")
			if b_t <= 0.0:
				var broken := b_state == B.STAGGER
				_end_opening()
				if broken:
					b_poise = b_poise_max           # it gathers itself
					_emit(&"poise", {"frac": 1.0, "from": "recover"})
					_go_idle()
				elif not b_far and not lesson and rng.randf() < press():
					# pressure: no breathing space, straight into the next string
					_emit(&"boss_press")
					_go_idle(rng.randf_range(PRESS_IDLE_MIN, PRESS_IDLE_MAX))
				else:
					_go_idle()
		B.SHIFT:
			if b_t <= 0.0:
				_emit(&"phase_ready", {"phase": b_phase})
				_go_idle(0.6)
				if beat_at.has(b_phase) and not _beats.has(b_phase) and bd.get("boss", false) and not training:
					# a listed phase begins: the presentation may stop the fight here for a few words, or a choice
					_beats[b_phase] = true
					_beat_sent = true
					_emit(&"story_beat", {"foe": str(bd.id), "phase": b_phase})

## How likely the foe is to chain straight into another string after an unbroken one (bosses.json "press").
func press() -> float:
	return minf(0.85, float(bd.get("press", 0.5)) + 0.1 * b_phase)

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
	if lesson:
		# the lesson foe throws one plain, slow cut, over and over
		for c in phase().combos:
			if c.attacks.size() == 1 and not c.attacks[0].unblockable and c.get("range", "near") != "far":
				return c
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
	if b_attack.unblockable:
		_emit(&"unblockable_warning", {"attack": b_attack, "windup": w})

func _resolve_strike() -> void:
	var a := b_attack
	var dmg: float = float(a.dmg) * b_dmg_mult
	var sentenced := trait_v("marks") > 0.0 and marks >= int(trait_v("marks"))
	if sentenced:
		dmg *= maxf(1.0, trait_v("mark_mult"))      # the sentence, carried out
	var result := "hit"
	var perfect := false
	# --- dodge
	if p_state == P.DODGE and p_elapsed >= DODGE_IFRAME_START and p_elapsed <= minf(DODGE_IFRAME_END * assist, DODGE_TIME - 0.1) + (ROLL_EXTRA_TIME - 0.08 if p_roll else 0.0):
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
				pl.stamina = minf(pl.max_stamina, pl.stamina + DODGE_COST * p_move_cost)
		"parried":
			_gain_surge(18.0 if perfect else 9.0)
			p_parry = {}
			habits.parry += 1.0
			stats.parries += 1
			if not seal_now().get("marked", false) or a.get("seal", false):
				_seal_hit(int(seal_now().get("perfect", 2)) if perfect else int(seal_now().get("parry", 1)), "perfect" if perfect else "parry")
			_set_p(P.FREE, 0.0)
			pl.stamina = minf(pl.max_stamina, pl.stamina + PARRY_COST)
			if perfect:
				stats.perfect_parries += 1
		"blocked":
			_gain_surge(4.0)
			habits.block += 1.0
			stats.blocks += 1
			# a block raised at the last instant turns the blow for free and rattles the attacker
			var timed: bool = p_block_fresh and time - p_block_since <= PERFECT_BLOCK * assist
			var cost: float = 0.0 if timed else float(a.guard) * (1.0 - float(pl.block_eff)) * maxf(1.0, trait_v("block_tax"))
			if p_shield_max > 0 and p_shield > 0:
				cost *= BLOCK_SHIELD_COST     # the board takes the blow; the arm behind it takes less
			# what breaks a guard: no charge left on the shield, or not the stamina to hold the blow
			var why := ""
			if not timed:
				if p_shield_max > 0 and p_shield <= 0:
					why = "shield"
				elif pl.stamina - cost <= 0.0:
					why = "stamina"
			if timed:
				perfect = true
				stats["perfect_blocks"] = int(stats.get("perfect_blocks", 0)) + 1
				_gain_surge(8.0)
			elif p_shield_max > 0:
				# the shield's count: an untimed block uses one
				p_shield = maxi(0, p_shield - 1)
				p_shield_idle = 0.0
				_emit(&"shield_charges", {"left": p_shield, "max": p_shield_max, "spent": why == "shield"})
			_spend(cost)
			if a.get("drain", false):
				_drain(dmg * 0.4)
			if why != "":
				# guard break: part of the blow lands, and the knight reels
				result = "guard_break"
				stats["guard_breaks"] = int(stats.get("guard_breaks", 0)) + 1
				_apply_element(a, 0.5)
				var before: float = pl.hp
				_last_hit_t = time
				_damage_player(dmg * GUARD_BREAK_DMG)
				_emit(&"guard_break", {"attack": a, "why": why, "dmg": before - float(pl.hp)})
				if p_state != P.DEAD:
					_set_p(P.STUN, GUARD_BREAK_STUN)
					_shield_reset = why == "shield"
			else:
				# a held guard costs no health: frost still creeps through the board, fire does not catch
				if a.get("element") == "frost":
					_apply_element(a, 0.5)
				if timed:
					_emit(&"perfect_block", {"attack": a})
				else:
					_emit(&"block", {"attack": a, "cost": cost, "left": p_shield})
		"hit":
			_gain_surge(9.0)
			# what was tried and did not serve, said plainly
			if p_block and a.unblockable:
				_emit(&"block_failed", {"why": "unblockable"})
			elif p_block and p_state != P.FREE and p_state != P.DODGE:
				_emit(&"block_failed", {"why": "busy"})
			elif p_state == P.PARRY and not p_parry.is_empty():
				_emit(&"parry_failed", {"why": "unparryable" if not a.parry else ("dir" if parry_quality(str(p_parry.dir), str(a.dir)) == 0 else "late")})
			_last_hit_t = time
			p_parry = {}
			stats.hits_taken += 1
			_apply_element(a, 1.0)
			if a.get("drain", false):
				_drain(dmg)
			_damage_player(dmg)
			if trait_v("lifesteal") > 0.0:
				b_hp = minf(b_hp_max, b_hp + dmg * trait_v("lifesteal") * 6.0)
			if trait_v("marks") > 0.0:
				marks = 0 if sentenced else marks + 1
				_emit(&"marks", {"n": marks, "of": int(trait_v("marks"))})
			if p_state != P.DEAD:
				_set_p(P.HURT, HURT_TIME)
			_end_opening()
	_emit(&"boss_strike", {"attack": a, "result": result, "perfect": perfect})
	if p_state == P.DEAD:
		return
	# --- what the boss does next
	var wear := 0.0
	match result:
		"parried": wear = POISE_PARRY_PERFECT if perfect else POISE_PARRY
		"dodged": wear = POISE_DODGE_PERFECT if perfect else POISE_DODGE
		"blocked": wear = POISE_BLOCK_TIMED if perfect else POISE_BLOCK
	var broke: bool = wear > 0.0 and _wear_poise(wear, result)
	var defended: bool = result in ["parried", "dodged", "blocked"]
	if result == "parried":
		if perfect and marks > 0:
			marks = 0                                   # a perfect parry is an acquittal
			_emit(&"marks", {"n": 0, "of": int(trait_v("marks"))})
		if broke:
			# parry break: the blade is beaten aside and the rest of the string never comes
			opening_from = "perfect" if perfect else "parry"
			_poise_break("parry")
			return
		if _struggle_roll(a, perfect):
			_begin_struggle()
			return
		if perfect:
			# the string is cut short, but its guard is not broken: a riposte, not a feast
			_recover(1.0e9 if lesson else RIPOSTE_TIME / speed() * (trait_v("parry_open") if trait_v("parry_open") > 0.0 else 1.0), "perfect")
			return
	b_idx += 1
	if b_idx < b_combo.attacks.size():
		_start_attack()
		return
	if defended and b_poise <= 0.0:
		# worn out by the defences against this string: guard break
		opening_from = "dodge" if result == "dodged" else ("parry" if result == "parried" else "")
		_poise_break("dodge" if result == "dodged" else ("parry" if result == "parried" else "block"))
		return
	# not broken: only a short recovery, scaled by the string's own (the lesson foe keeps its full, patient one)
	var full: float = float(b_combo.recover) / speed()
	var rec: float = full if lesson else minf(full, maxf(SHORT_RECOVER_MIN, full * SHORT_RECOVER))
	if result in ["dodged", "blocked"] and perfect:
		rec += 0.35
	if result == "parried" and trait_v("parry_open") > 0.0:
		rec *= trait_v("parry_open")
	if result == "dodged" and trait_v("dodge_open") > 0.0:
		rec *= trait_v("dodge_open")
	if lesson and defended:
		rec = 1.0e9               # the lesson foe waits for the answering cut (DuelSim.lesson_hold(false) sets it going again)
	_recover(rec, "dodge" if result == "dodged" else ("parry" if result == "parried" else ""))

func _recover(rec: float, from: String) -> void:
	opening_from = from
	if b_combo.get("retreat", false):
		b_far = true
		_emit(&"boss_retreat")
	b_state = B.RECOVER
	b_t = rec
	b_opening_crit = false
	_emit(&"boss_recover", {"time": rec, "far": b_far})
	if not b_far:
		_next_rift()

## Decided when the parry lands, from the fight's own seed: never by reading input.
func _struggle_roll(a: Dictionary, perfect: bool) -> bool:
	if perfect or lesson or training or not struggle_capable() or not heavy_attack(a):
		return false
	if time - _struggle_last < STRUGGLE_COOLDOWN:
		return false
	return force_struggle or rng.randf() < STRUGGLE_CHANCE

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
	if lesson:
		dmg = minf(dmg, maxf(0.0, pl.hp - 1.0)) * 0.0      # nobody is hurt while learning
	if end_on.has("floor") and not over and pl.hp - dmg <= float(pl.max_hp) * float(end_on.floor):
		# a story-ended fight is never lost to an ordinary blow: the story takes it here instead
		var kept: float = maxf(1.0, minf(pl.hp, float(pl.max_hp) * float(end_on.floor)))
		stats.taken += pl.hp - kept
		pl.hp = kept
		_story_end("even" if cuts_landed > 0 else "behind")
		return
	pl.hp = maxf(0.0, pl.hp - dmg)
	stats.taken += dmg
	if not quiet:
		_emit(&"player_hurt", {"dmg": dmg, "hp": pl.hp})
	if pl.hp <= 0.0:
		p_state = P.DEAD
		over = true
		_emit(&"player_dead")
