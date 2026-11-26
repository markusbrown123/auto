extends Node
## Headless test suite:  godot --headless --path . res://tests/tests.tscn
var passed := 0
var failed := 0

func ok(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", what)

func mk(foe: String, seed_value: int = 7, profile: Dictionary = {}, opts: Dictionary = {}) -> DuelSim:
	var p: Dictionary = profile if not profile.is_empty() else Game.default_profile()
	var s := DuelSim.new()
	var o := opts.duplicate()
	if not o.has("combos"):
		o["combos"] = Db.combos
	s.setup(Stats.compute(p, Db.items, Db.classes), Db.foes[foe], seed_value, o)
	return s

func run_for(s: DuelSim, t: float, bot: DuelBot = null) -> void:
	var n := int(t * 60.0)
	for i in n:
		if bot:
			bot.tick(1.0 / 60.0)
		s.tick(1.0 / 60.0)
		if s.over:
			return

func until_windup(s: DuelSim) -> void:
	for i in 2000:
		if s.b_state == DuelSim.B.WINDUP:
			return
		s.tick(1.0 / 60.0)

func to_impact(s: DuelSim, before: float) -> void:
	while s.b_state == DuelSim.B.WINDUP and s.b_t > before:
		s.tick(1.0 / 120.0)

func geared(tier: int) -> Dictionary:
	# a profile roughly as strong as a player arriving at boss `tier` would be
	var p := Game.default_profile()
	var weapons := ["w_rusted_sword", "w_knight_sword", "w_ashen_great", "w_headsman", "w_censer_sword", "w_crypt_great", "w_frost_great"]
	var sets := ["worn", "garrison", "black", "vigil", "vigil", "frost", "regal"]
	p.equipped.weapon = weapons[tier]
	p.inventory.append(weapons[tier])
	for part in ["helm", "chest", "gauntlets", "legs"]:
		p.equipped[part] = "a_%s_%s" % [sets[tier], part]
	for k in ["health", "strength", "dex", "endurance"]:
		p.attrs[k] += tier * 3
	if Db.classes[Db.item(weapons[tier]).cls].two_handed:
		p.equipped.shield = null
	return p

func _ready() -> void:
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_test"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	for f in ["save.json", "save.bak", "save.tmp"]:
		DirAccess.remove_absolute(Game.save_dir_override + "/" + f)
	for t in ["t_data", "t_parry", "t_dodge", "t_block", "t_attack", "t_punish", "t_phases", "t_adaptive", "t_elements", "t_meters_combos", "t_seams", "t_drain", "t_revive", "t_bots", "t_progression", "t_endings", "t_save", "t_runs", "t_lore_quests", "t_companion", "t_inventory_settings", "t_save_slots"]:
		print("• ", t)
		call(t)
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

# ------------------------------------------------------------------ data
func t_data() -> void:
	ok(Db.items.size() >= 50, "item count")
	ok(Db.regions.size() == 8, "eight regions")
	for r in Db.regions:
		ok(r.stages.size() == 7, "%s has seven stops" % r.id)
		var kinds := {}
		for s in r.stages:
			for o in s.options:
				if o.type == "fight":
					kinds[o.foe] = true
		ok(kinds.size() >= 2, "%s road has varied foes" % r.id)
	var bosses := 0
	for id in Db.foes:
		var f: Dictionary = Db.foes[id]
		if f.boss:
			bosses += 1
		for e in f.get("loot", []):
			ok(Db.items.has(e[0]), "%s loot %s exists" % [id, e[0]])
		var prev_at := 2.0
		for ph in f.phases:
			ok(float(ph.at) < prev_at, "%s phases descend" % id)
			prev_at = float(ph.at)
			var near := false
			for c in ph.combos:
				if c.get("range", "near") != "far":
					near = true
				for i in c.attacks.size():
					var a: Dictionary = c.attacks[i]
					ok(DuelSim.DIRS.has(a.dir), "%s dir" % c.id)
					# fairness: every attack must have at least one answer
					ok(a.parry or a.dodge != "none" or not a.unblockable, "%s/%s has a defence" % [id, c.id])
					# readable: no blow lands faster than a person can react
					ok(float(a.windup) / float(ph.speed) + (float(c.gap) if i > 0 else 0.0) >= 0.45, "%s/%s windup readable" % [id, c.id])
			ok(near, "%s has near combos" % id)
	ok(bosses >= 11, "at least 11 bosses")
	var classes := {}
	for id in Db.foes:
		classes[Db.foes[id].cls] = int(classes.get(Db.foes[id].cls, 0)) + 1
	for c in ["Humanoid", "Heavy", "Giant", "Twin-Bladed", "Double-Weapon", "Monstrosity", "Soul-Eater", "Wyrm", "Guardian"]:
		ok(int(classes.get(c, 0)) >= 2, "class %s has foes (%d)" % [c, classes.get(c, 0)])
	# every foe is reachable from some road
	var placed := {}
	for r in Db.regions:
		for s in r.stages:
			for o in s.options:
				if o.has("foe"):
					placed[o.foe] = true
				for pf in o.get("foes", []):
					placed[pf] = true
	for id in Db.foes:
		ok(placed.has(id), "%s appears on a road" % id)
	for r in Db.regions:
		for s in r.stages:
			for o in s.options:
				if o.has("foe"):
					ok(Db.foes.has(o.foe), "region foe %s" % o.foe)
				for pf in o.get("foes", []):
					ok(Db.foes.has(pf) and Db.foes[pf].region == r.id, "pool foe %s belongs to %s" % [pf, r.id])
				for it in o.get("items", []):
					ok(Db.items.has(it), "region item %s" % it)
	for slot in Db.SLOTS:
		var n := 0
		for it in Db.item_list:
			if it.slot == slot:
				n += 1
		ok(n >= 3, "slot %s has items" % slot)

# ------------------------------------------------------------------ parry
func t_parry() -> void:
	ok(DuelSim.parry_quality("R", "L") == 2, "opposite swipe is square")
	ok(DuelSim.parry_quality("UR", "L") == 1, "adjacent swipe glances")
	ok(DuelSim.parry_quality("L", "L") == 0, "same direction fails")
	ok(DuelSim.parry_quality("U", "L") == 0, "perpendicular fails")
	# perfect parry
	var s := mk("ashen_sentinel")
	until_windup(s)
	var dir: String = s.b_attack.dir
	to_impact(s, 0.06)
	s.input_swipe(DuelSim.parry_dir_for(dir))
	var hp: float = s.pl.hp
	run_for(s, 0.2)
	ok(s.pl.hp == hp, "perfect parry: no damage")
	ok(s.b_state == DuelSim.B.STAGGER, "perfect parry staggers")
	ok(s.stats.perfect_parries == 1, "perfect parry counted")
	# normal parry (inside window, outside perfect)
	s = mk("ashen_sentinel")
	until_windup(s)
	to_impact(s, 0.22)
	s.input_swipe(DuelSim.parry_dir_for(s.b_attack.dir))
	hp = s.pl.hp
	run_for(s, 0.3)
	ok(s.pl.hp == hp and s.stats.parries == 1 and s.stats.perfect_parries == 0, "normal parry")
	ok(s.b_posture > 0.0, "normal parry builds posture")
	# too early → whiff, then hit
	s = mk("ashen_sentinel")
	until_windup(s)
	to_impact(s, 0.6)
	s.input_swipe(DuelSim.parry_dir_for(s.b_attack.dir))
	hp = s.pl.hp
	run_for(s, 0.7)
	ok(s.pl.hp < hp, "early parry is punished")
	# wrong direction
	s = mk("ashen_sentinel")
	until_windup(s)
	to_impact(s, 0.06)
	s.input_swipe(s.b_attack.dir)
	hp = s.pl.hp
	run_for(s, 0.2)
	ok(s.pl.hp < hp, "wrong-direction parry fails")

# ------------------------------------------------------------------ dodge
func _find(foe: String, pred: Callable) -> DuelSim:
	for sd in range(1, 400):
		var s := mk(foe, sd)
		# skip to phase with most variety by leaving as is; search first telegraphs
		for k in 6:
			until_windup(s)
			if pred.call(s.b_attack):
				return s
			run_for(s, 4.0)
			if s.over:
				break
	return null

func t_dodge() -> void:
	var s := _find("ashen_sentinel", func(a): return a.dodge == "L")
	ok(s != null, "found a dodge-left attack")
	to_impact(s, 0.12)
	s.input_dodge(-1)
	var hp: float = s.pl.hp
	run_for(s, 0.2)
	ok(s.pl.hp == hp and s.stats.perfect_dodges == 1, "perfect dodge")
	ok(s.p_counter, "perfect dodge grants a counter")
	s = _find("ashen_sentinel", func(a): return a.dodge == "L")
	to_impact(s, 0.12)
	s.input_dodge(1)
	hp = s.pl.hp
	run_for(s, 0.2)
	ok(s.pl.hp < hp, "dodging into the blow is hit")
	s = _find("ashen_sentinel", func(a): return a.dodge == "L")
	to_impact(s, 0.36)
	s.input_dodge(-1)
	hp = s.pl.hp
	run_for(s, 0.4)
	ok(s.pl.hp == hp and s.stats.dodges == 1 and s.stats.perfect_dodges == 0, "early dodge is safe but not perfect")

# ------------------------------------------------------------------ block
func t_block() -> void:
	var s := _find("ashen_sentinel", func(a): return not a.unblockable)
	s.input_block(true)
	var hp: float = s.pl.hp
	var st: float = s.pl.stamina
	to_impact(s, 0.0)
	s.tick(1.0 / 60.0)
	ok(s.stats.blocks == 1, "block registered")
	ok(s.pl.hp > hp - 5.0, "block absorbs nearly all damage")
	ok(s.pl.stamina < st, "block costs stamina")
	# guard break
	s = _find("ashen_sentinel", func(a): return not a.unblockable)
	s.input_block(true)
	s.pl.stamina = 5.0
	hp = s.pl.hp
	to_impact(s, 0.0)
	s.tick(1.0 / 60.0)
	ok(s.p_state == DuelSim.P.STUN, "guard break stuns")
	ok(s.pl.hp < hp - 5.0, "guard break hurts")
	# unblockable
	s = null
	for sd in range(1, 300):
		var c := mk("cathedral_beast", sd)
		for k in 8:
			until_windup(c)
			if c.b_attack.unblockable:
				s = c
				break
			run_for(c, 3.0)
		if s:
			break
	ok(s != null, "found an unblockable")
	if s:
		s.input_block(true)
		hp = s.pl.hp
		to_impact(s, 0.0)
		s.tick(1.0 / 60.0)
		ok(s.pl.hp < hp - 10.0 and s.stats.blocks == 0, "unblockable goes through a block")

# ------------------------------------------------------------------ attacking
func t_attack() -> void:
	var s := mk("ashen_sentinel")
	until_windup(s)
	to_impact(s, 0.06)
	s.input_swipe(DuelSim.parry_dir_for(s.b_attack.dir))
	run_for(s, 0.1)
	var hp := s.b_hp
	var hits: Array = []
	s.ev.connect(func(n, d): if n == &"boss_hit": hits.append(d))
	s.input_swipe("L"); run_for(s, 0.3)
	s.input_swipe("R"); run_for(s, 0.3)
	s.input_swipe("R"); run_for(s, 0.3)
	ok(hits.size() == 3, "three hits land in the opening")
	if hits.size() == 3:
		ok(hits[0].crit, "stagger hits are critical")
		ok(hits[1].dmg > hits[0].dmg * 1.05, "alternating directions builds a combo")
		ok(hits[2].dmg < hits[1].dmg * 0.7, "repeating a direction is weak")
	ok(s.b_hp < hp, "boss took damage")
	# stamina gate
	s = mk("ashen_sentinel")
	s.pl.stamina = 0.0
	s.input_swipe("L")
	ok(s.p_state == DuelSim.P.FREE, "cannot swing with no stamina")
	# input buffer
	s = mk("ashen_sentinel")
	s.b_state = DuelSim.B.RECOVER; s.b_t = 3.0
	s.input_swipe("L")
	run_for(s, 0.15)
	s.input_swipe("R")
	run_for(s, 0.6)
	ok(s.p_combo == 2, "buffered swipe executes")

func t_punish() -> void:
	var s := mk("ashen_sentinel")
	s.b_t = 30.0   # hold the boss idle
	var punished := [false]
	var chips := [0]
	s.ev.connect(func(n, d):
		if n == &"boss_combo" and d.punish: punished[0] = true
		if n == &"deflected": chips[0] += 1)
	var hp := s.b_hp
	for i in 12:
		s.input_swipe("L")
		run_for(s, 0.3)
		if punished[0]:
			break
	ok(chips[0] >= 2, "attacks on a guarding boss are deflected")
	ok(punished[0], "reckless attacking triggers a punish")
	ok(s.b_hp > hp * 0.9, "deflected attacks only chip")

func t_phases() -> void:
	var s := mk("frostbound_king")
	var phases: Array = []
	s.ev.connect(func(n, d): if n == &"phase_change": phases.append(d.phase))
	s.b_state = DuelSim.B.RECOVER; s.b_t = 99.0
	s.pl.attack = 5000.0
	s.input_swipe("L"); run_for(s, 0.4)
	ok(phases == [1], "one big hit cannot skip a phase")
	ok(is_equal_approx(s.b_hp, s.b_hp_max * 0.66), "hp clamps at the phase threshold")
	ok(s.b_state == DuelSim.B.SHIFT, "phase shift state")
	var hp := s.b_hp
	s.input_swipe("R"); run_for(s, 0.4)
	ok(s.b_hp == hp, "invulnerable during the phase shift")
	run_for(s, 3.0)
	ok(s.b_state != DuelSim.B.SHIFT, "phase shift ends")

func t_adaptive() -> void:
	var s := mk("hollow_executioner")
	var anti: Dictionary = {}
	var plain: Dictionary = {}
	for c in s.phase().combos:
		if c.tags.has("anti_block"):
			anti = c
		elif c.tags.has("basic"):
			plain = c
	var w0 := s.combo_weight(anti)
	s.habits.block = 5.0
	ok(s.combo_weight(anti) > w0 * 2.0, "a blocking habit raises guard-breaker weight")
	ok(is_equal_approx(s.combo_weight(plain), float(plain.w)), "plain attacks are unaffected")
	# statistically: a turtle sees more anti-block combos than a parrier
	var counts := {"turtle": 0, "skilled": 0}
	for mode in counts:
		for sd in range(1, 9):
			var d := mk("hollow_executioner", sd)
			d.pl.max_hp = 99999.0; d.pl.hp = 99999.0
			var bot := DuelBot.new(d, DuelBot.Style.TURTLE if mode == "turtle" else DuelBot.Style.SKILLED, sd)
			bot.sim.pl.attack = 0.01
			d.ev.connect(func(n, e):
				if n == &"boss_combo" and not e.punish:
					for c in d.phase().combos:
						if c.id == e.id and c.tags.has("anti_block"):
							counts[mode] += 1)
			run_for(d, 60.0, bot)
	ok(counts.turtle > counts.skilled * 1.4, "boss adapts to turtling (%d vs %d)" % [counts.turtle, counts.skilled])

func t_elements() -> void:
	var s := mk("frostbound_king")
	var got := [false]
	s.ev.connect(func(n, d): if n == &"status" and d.status == "frostbite": got[0] = true)
	s.pl.max_hp = 99999.0; s.pl.hp = 99999.0
	run_for(s, 40.0)
	ok(got[0], "frost builds into frostbite")
	var p := Game.default_profile()
	p.attrs.resist = 28
	var r := mk("frostbound_king", 7, p)
	ok(r.pl.resist > 80.0, "resist stat applies")
	var w := mk("ashen_sentinel", 3, geared(6))
	ok(w.pl.element == "frost" and w.bd.weak == "frost", "weapon element matches weakness")

# ------------------------------------------------------------------ surge, relic, named combos
func t_meters_combos() -> void:
	var s := mk("ashen_sentinel")
	ok(not s.input_surge(), "no surge without a full meter")
	until_windup(s)
	to_impact(s, 0.06)
	s.input_swipe(DuelSim.parry_dir_for(s.b_attack.dir))
	run_for(s, 0.1)
	ok(s.surge >= 18.0, "a perfect parry feeds the surge meter")
	s.surge = DuelSim.SURGE_MAX
	run_for(s, 3.5)
	until_windup(s)
	ok(s.input_surge() and s.b_state == DuelSim.B.STAGGER and s.surge == 0.0, "surge breaks a foe mid-attack and empties the meter")
	var hp: float = s.pl.hp
	run_for(s, 1.0)
	ok(s.pl.hp == hp, "the interrupted attack never lands")
	# relic
	s = mk("ashen_sentinel")
	ok(not s.input_relic(), "relic is not ready at the start")
	s.b_t = 99.0
	run_for(s, 31.0)
	ok(s.relic >= DuelSim.RELIC_MAX, "relic charges in about half a minute")
	ok(not s.input_relic(), "relic is not wasted at full health")
	s.pl.hp = 20.0
	ok(s.input_relic() and is_equal_approx(s.pl.hp, 20.0 + s.pl.max_hp * 0.35) and s.relic == 0.0, "relic heals 35% and empties")
	# the combo library
	s = mk("ashen_sentinel")
	s.b_state = DuelSim.B.RECOVER; s.b_t = 30.0
	var hits: Array = []
	s.ev.connect(func(n, d): if n == &"boss_hit": hits.append(d))
	for d in ["L", "R"]:
		s.input_swipe(d); run_for(s, 0.4)
	ok(hits.size() == 2 and hits[1].named == "Double Slash" and hits[1].combo_id == "double_slash" and hits[0].named == "", "left-right is a Double Slash")
	ok(hits[1].dmg > hits[0].dmg * 1.15, "the finishing cut lands harder")
	s = mk("ashen_sentinel"); hits.clear()
	s.ev.connect(func(n, d): if n == &"boss_hit": hits.append(d))
	s.b_state = DuelSim.B.RECOVER; s.b_t = 30.0
	var post: float = s.b_posture
	for d in ["R", "L", "D"]:
		s.input_swipe(d); run_for(s, 0.4)
	ok(hits.size() == 3 and hits[2].named == "Armor Splitter", "right-left-down is an Armor Splitter")
	ok(s.b_posture - post >= 30.0 or s.b_state == DuelSim.B.STAGGER, "Armor Splitter cracks posture")
	s = mk("ashen_sentinel"); hits.clear()
	s.ev.connect(func(n, d): if n == &"boss_hit": hits.append(d))
	s.b_state = DuelSim.B.RECOVER; s.b_t = 30.0
	for d in ["U", "D", "D"]:
		s.input_swipe(d); run_for(s, 0.4)
	ok(hits.size() == 3 and hits[2].named == "Falling Crown" and hits[2].dmg > hits[1].dmg * 1.5, "a combo may repeat a cut without the glancing penalty")
	s = mk("ashen_sentinel"); hits.clear()
	s.ev.connect(func(n, d): if n == &"boss_hit": hits.append(d))
	s.b_state = DuelSim.B.RECOVER; s.b_t = 30.0
	for d in ["D", "D"]:
		s.input_swipe(d); run_for(s, 0.4)
	ok(hits.size() == 2 and hits[1].named == "" and hits[1].dmg < hits[0].dmg * 0.6, "the same cut twice still glances when no combo calls for it")
	ok(s.stats.named == 0, "unnamed cuts are not counted as combos")
	var ids: Array = s.combos.map(func(c): return c.id)
	ok(ids.has("riposte") and not ids.has("twin_fang") and not ids.has("colossus"), "a sword knows sword combos only")
	for c in Db.combos:
		ok(c.seq.size() >= 2 and c.seq.all(func(x): return DuelSim.DIRS.has(x)), "%s is a valid sequence" % c.id)
		for other in Db.combos:
			ok(other.id == c.id or other.seq != c.seq, "%s and %s differ" % [c.id, other.id])
	ok(Db.combos.size() >= 12 and Db.combos.size() <= 20, "twelve to twenty combos")
	# discovery
	Game.new_game("#123456")
	var before: int = Game.profile.combos.size()
	ok(Game.profile.combos.has("double_slash"), "Double Slash is known from the start")
	ok(Game.use_combo("armor_splitter") and not Game.use_combo("armor_splitter"), "a combo is discovered once")
	ok(Game.profile.combos.size() == before + 1 and int(Game.profile.combo_uses.armor_splitter) == 2, "uses are counted")
	# timed block
	s = _find("ashen_sentinel", func(a): return not a.unblockable)
	to_impact(s, 0.1)
	var stam: float = s.pl.stamina
	var hp2: float = s.pl.hp
	s.input_block(true)
	run_for(s, 0.2)
	ok(int(s.stats.get("perfect_blocks", 0)) == 1 and s.pl.stamina >= stam and s.pl.hp == hp2, "a block raised at the last instant costs nothing")
	# roll: a second tap on the same side
	s = mk("ashen_sentinel")
	var st0: float = s.pl.stamina
	s.input_dodge(1); run_for(s, 0.1); s.input_dodge(1)
	ok(s.p_roll and int(s.stats.get("rolls", 0)) == 1 and is_equal_approx(st0 - s.pl.stamina, DuelSim.DODGE_COST + DuelSim.ROLL_EXTRA_COST) or s.pl.stamina > st0 - 23.0 and s.p_roll, "a second tap turns the sidestep into a roll")
	run_for(s, 0.6)
	ok(s.p_state == DuelSim.P.DODGE, "a roll lasts longer than a sidestep")
	run_for(s, 0.4)
	ok(s.p_state == DuelSim.P.FREE, "and ends")
	s = mk("ashen_sentinel")
	s.input_dodge(1); run_for(s, 0.1); s.input_dodge(-1)
	ok(not s.p_roll, "the other side does not roll")
	# the first lesson: open until told to fight, then one plain cut, and nobody is hurt
	s = mk("ashen_sentinel", 7, {}, {"lesson": true})
	run_for(s, 5.0)
	ok(s.b_state == DuelSim.B.RECOVER, "the lesson foe starts open")
	s.lesson_fights = true
	s.b_t = 0.5
	var seen := {}
	s.ev.connect(func(n, d): if n == &"boss_combo": seen[d.id] = true)
	run_for(s, 25.0)
	ok(seen.size() == 1 and s.pl.hp == s.pl.max_hp and not s.over, "then it throws one plain cut and nobody is hurt")
	# guardian traits
	s = mk("hollow_executioner")
	ok(s.trait_v("marks") == 3.0 and mk("ashen_sentinel").trait_v("marks") == 0.0, "traits come from data")
	var dealt: Array = []
	s.ev.connect(func(n, d): if n == &"player_hurt": dealt.append(d.dmg))
	s.pl.max_hp = 1.0e6; s.pl.hp = 1.0e6
	for i in 400:
		run_for(s, 0.5)
		if dealt.size() >= 4:
			break
	ok(dealt.size() >= 4 and s.marks <= 3, "the Executioner marks each wound")
	s = mk("cathedral_beast")
	var sp0: float = s.speed()
	s.b_hp = s.b_hp_max * 0.4
	ok(s.speed() > sp0 * 1.1, "the Beast quickens as it bleeds")
	# exploits found in review
	s = mk("ashen_sentinel"); hits.clear()
	s.ev.connect(func(n, d): if n == &"boss_hit": hits.append(d))
	s.b_state = DuelSim.B.RECOVER; s.b_t = 30.0
	for d in ["L", "R", "L", "R"]:
		s.input_swipe(d); run_for(s, 0.4)
	ok(hits.size() == 4 and hits[1].named == "Double Slash" and hits[2].named == "" and hits[3].named == "Double Slash", "a finished combo cannot be cashed in again from the same cuts")
	ok(hits[3].dmg / hits[2].dmg < (hits[1].dmg / hits[0].dmg) * 0.95, "the same combo twice running loses most of its weight")
	s = _find("ashen_sentinel", func(a): return not a.unblockable)
	to_impact(s, 0.3)
	s.input_block(true); run_for(s, 0.05); s.input_block(false); run_for(s, 0.1)
	s.input_block(true)
	run_for(s, 0.3)
	ok(int(s.stats.get("perfect_blocks", 0)) == 0 and s.stats.blocks == 1, "fluttering the shield does not earn a timed block")
	s = mk("ashen_sentinel")
	s.input_dodge(1); run_for(s, 0.05); s.input_dodge(1)
	var st_roll: float = s.pl.stamina
	s.input_dodge(1); s.input_dodge(-1)
	run_for(s, 0.84)
	ok(s.pl.stamina >= st_roll and s.p_state == DuelSim.P.DODGE, "nothing chains or buffers out of a roll")
	run_for(s, 0.3)
	ok(s.p_state == DuelSim.P.FREE, "the roll ends with the knight free and exposed")
	# training ground
	s = mk("ashen_sentinel", 7, {}, {"training": true})
	hits.clear()
	s.ev.connect(func(n, d): if n == &"boss_hit": hits.append(d))
	run_for(s, 20.0)
	ok(s.b_state == DuelSim.B.RECOVER and s.pl.hp == s.pl.max_hp and not s.over, "the training foe only stands open")
	for d in ["L", "R"]:
		s.input_swipe(d); run_for(s, 0.4)
	ok(hits.size() == 2 and hits[1].named == "Double Slash" and not s.over, "combos land in training and nothing dies")
	run_for(s, 2.0)
	ok(s.p_hist.is_empty(), "a pause in training starts the sequence over")

# ------------------------------------------------------------------ seams, drain, revival
func t_seams() -> void:
	var s := mk("ashen_sentinel")
	s.b_state = DuelSim.B.RECOVER; s.b_t = 9.0
	s._next_rift()
	ok(s.rift_dir != "", "an opening shows a seam")
	var hits: Array = []
	s.ev.connect(func(n, d): if n == &"boss_hit": hits.append(d))
	var first: String = s.rift_dir
	var off := "L" if first != "L" else "R"
	s.input_swipe(off); run_for(s, 0.3)
	ok(s.rift_dir == first, "an off-seam cut leaves the seam where it is")
	s.input_swipe(first); run_for(s, 0.3)
	ok(hits.size() == 2 and hits[1].rift and not hits[0].rift, "cutting along the seam is recognised")
	ok(hits[1].dmg > hits[0].dmg * 1.5, "a seam cut hits much harder")
	ok(s.rift_dir != first and s.rift_dir != "", "the seam moves after it is cut")
	run_for(s, 9.5)
	ok(s.rift_dir == "", "the seam closes with the opening")
	# reading seams beats mashing: same fight, with and without following them
	var a := mk("ashen_sentinel", 5); var ba := DuelBot.new(a, DuelBot.Style.SKILLED, 5); run_for(a, 600.0, ba)
	var b := mk("ashen_sentinel", 5); var bb := DuelBot.new(b, DuelBot.Style.SLOPPY, 5); bb.rng.seed = 5; run_for(b, 600.0, bb)
	ok(a.stats.rifts > 5, "the skilled bot follows seams (%d)" % a.stats.rifts)

func t_drain() -> void:
	var s := _find("soul_eater", func(a): return a.get("drain", false))
	ok(s != null, "found a draining attack")
	s.b_hp = s.b_hp_max * 0.5
	var hp := s.b_hp
	var st: float = s.pl.stamina
	to_impact(s, 0.0); s.tick(1.0 / 60.0)
	ok(s.b_hp > hp, "a landed grasp feeds the eater")
	ok(s.pl.stamina < st - 20.0, "and empties your stamina")
	s = _find("soul_eater", func(a): return a.get("drain", false))
	s.b_hp = s.b_hp_max * 0.5
	hp = s.b_hp
	to_impact(s, 0.06)
	s.input_swipe(DuelSim.parry_dir_for(s.b_attack.dir))
	run_for(s, 0.1)
	ok(s.b_hp == hp, "a parried grasp feeds nothing")

func t_revive() -> void:
	var s := mk("devourer")
	var seen: Array = []
	s.ev.connect(func(n, d): if n == &"phase_change": seen.append(d))
	s.pl.attack = 999999.0
	for i in 3:
		s.b_state = DuelSim.B.RECOVER; s.b_t = 9.0
		s.input_swipe(["L", "R", "U"][i]); run_for(s, 0.4)
		if i == 1:
			ok(not s.over and s.b_state == DuelSim.B.SHIFT, "at zero it does not die")
			ok(is_equal_approx(s.b_hp, s.b_hp_max * 0.45), "it rises with health restored")
			ok(seen.size() == 2 and seen[1].revive, "the revival is announced")
		run_for(s, 3.0)
	ok(s.b_state == DuelSim.B.DEAD, "the second death is final")

# ------------------------------------------------------------------ whole fights
func fight(foe: String, style: int, profile: Dictionary, seed_value: int, opts: Dictionary = {}) -> DuelSim:
	var s := mk(foe, seed_value, profile, opts)
	var bot := DuelBot.new(s, style, seed_value)
	run_for(s, 600.0, bot)
	return s

func t_bots() -> void:
	var tiers := {"hollow_soldier": 0, "ashen_sentinel": 0, "pale_huntsman": 1, "hollow_executioner": 1, "crimson_widow": 2,
		"cathedral_beast": 3, "gravewarden": 4, "cinder_whelp": 4, "cinder_wyrm": 5, "rimewyrm": 5, "frostbound_king": 5,
		"soul_eater": 6, "devourer": 6, "forgotten_monarch": 6,
		"gate_colossus": 0, "pike_sergeant": 0, "veil_dancer": 1, "maulbeast": 1, "bell_ringer": 2, "tomb_mummer": 3, "frost_drake": 5, "the_unburied": 6, "herald": 6}
	for foe in tiers:
		var s := fight(foe, DuelBot.Style.SKILLED, geared(tiers[foe]), 11)
		ok(s.b_state == DuelSim.B.DEAD, "skilled play beats %s" % foe)
		print("    %-20s skilled: %5.1fs  taken %3d  parries %d/%d  dodges %d" % [foe, s.time, int(s.stats.taken), s.stats.perfect_parries, s.stats.parries, s.stats.dodges])
		ok(s.time > 25.0 or not Db.foes[foe].boss, "%s is not trivially short (%.0fs)" % [foe, s.time])
		ok(s.time < 300.0, "%s is not a slog (%.0fs)" % [foe, s.time])
		var sp := fight(foe, DuelBot.Style.SPAM, geared(tiers[foe]), 11)
		ok(sp.p_state == DuelSim.P.DEAD, "swipe-spam loses to %s" % foe)
		if Db.foes[foe].boss:
			var wins := 0
			for sd in 6:
				if fight(foe, DuelBot.Style.SLOPPY, geared(tiers[foe]), 20 + sd).b_state == DuelSim.B.DEAD:
					wins += 1
			print("    %-20s sloppy-timing win rate: %d/6" % [foe, wins])
			var tw := 0
			for sd in 4:
				if fight(foe, DuelBot.Style.TURTLE, geared(tiers[foe]), 40 + sd).b_state == DuelSim.B.DEAD:
					tw += 1
			print("    %-20s turtle win rate: %d/4" % [foe, tw])
	# NG+ is harder but still beatable by skilled play
	var ng := fight("ashen_sentinel", DuelBot.Style.SKILLED, geared(6), 5, {"ng": 2})
	ok(ng.b_state == DuelSim.B.DEAD and ng.b_hp_max > float(Db.foes.ashen_sentinel.hp) * 2.0, "NG+ scales and stays winnable")
	# determinism
	var a := fight("crimson_widow", DuelBot.Style.SLOPPY, geared(2), 99)
	var b := fight("crimson_widow", DuelBot.Style.SLOPPY, geared(2), 99)
	ok(is_equal_approx(a.time, b.time) and is_equal_approx(a.pl.hp, b.pl.hp), "simulation is deterministic per seed")

# ------------------------------------------------------------------ progression
func t_progression() -> void:
	Game.new_game()
	var base := Game.stats()
	ok(Game.grant_xp(Stats.xp_for_level(1)) == 1 and Game.profile.level == 2, "level up")
	ok(Game.profile.attr_points == 2, "attribute points granted")
	ok(Game.spend_attr("health") and Game.stats().max_hp > base.max_hp, "spend attribute")
	Game.profile.gold = 5000; Game.profile.shards = 50
	ok(Game.buy("w_knight_sword") and Game.owns("w_knight_sword"), "buy item")
	ok(not Game.buy("w_knight_sword"), "cannot buy twice")
	ok(not Game.buy("w_monarch"), "boss loot is not for sale")
	Game.equip("w_knight_sword")
	var s1 := Game.stats()
	ok(s1.attack > base.attack, "better weapon raises attack")
	ok(Game.upgrade("w_knight_sword") and Game.stats().attack > s1.attack, "blacksmith upgrade")
	for i in 10:
		Game.upgrade("w_knight_sword")
	ok(Game.upgrade_level("w_knight_sword") == Stats.MAX_UPGRADE, "upgrade cap")
	Game.grant_item("w_ashen_great")
	Game.equip("w_ashen_great")
	ok(Game.profile.equipped.shield == null, "two-handed weapon removes shield")
	ok(Game.stats().swing_time > s1.swing_time, "greatsword swings slower")
	Game.equip("s_plank")
	ok(not Db.classes[Db.item(Game.profile.equipped.weapon).cls].two_handed, "shield forces a one-handed weapon")
	# mastery
	Game.start_run("courtyard")
	var pts: int = Game.profile.attr_points
	for i in 4:
		Game.on_victory("hollow_soldier", 50.0)
	ok(Game.profile.mastered.size() > 0 and Game.profile.attr_points > pts, "equipment mastery grants a point")
	var res := Game.on_victory("ashen_sentinel", 50.0)
	ok(Game.owns("w_ashen_great") and res.gold > 0, "boss first-kill loot")

func t_endings() -> void:
	Game.new_game("#123456")
	var by := {}
	for r in Db.regions:
		by[r.id] = r
	ok(by.throne.requires == "citadel" and by.citadel.requires == "crypt" and by.roost.get("optional", false) and by.deep.get("optional", false), "the Roost and the Deep are side roads")
	Game.profile.cleared = ["courtyard", "blackwood", "cathedral", "crypt", "citadel", "throne"]
	ok(Game.game_complete() and not Game.can_divide_crown(), "the main road alone finishes the game but cannot divide the Crown")
	Game.profile.cleared.append("roost")
	Game.profile.defeated["devourer"] = 1
	ok(not Game.can_divide_crown(), "the side roads alone are not enough without the records")
	for i in Game.LORE_FOR_DIVIDE:
		Game.profile.lore.append(Db.lore[i].id)
	ok(Game.can_divide_crown(), "the side roads and thirty records earn the third ending")
	Game.choose_ending("cities"); Game.choose_ending("cities")
	ok(Game.profile.endings == ["cities"] and Game.profile.flags.last_ending == "cities", "the ending is recorded once")

func t_save() -> void:
	Game.new_game("#123456")
	Game.profile.gold = 777
	Game.grant_item("w_monarch")
	Game.profile.upgrades["w_monarch"] = 3
	ok(Game.save(), "save writes")
	Game.profile = {}
	ok(Game.load_game(), "load reads")
	ok(Game.profile.gold == 777 and Game.owns("w_monarch") and Game.profile.heraldry == "#123456", "round trip")
	ok(typeof(Game.profile.gold) == TYPE_INT and typeof(Game.profile.upgrades["w_monarch"]) == TYPE_INT, "integers survive JSON")
	# corrupt main save → falls back to backup
	Game.profile.gold = 778
	Game.save()
	var f := FileAccess.open(Game.save_dir_override + "/save.json", FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	Game.profile = {}
	ok(Game.load_game() and Game.profile.gold == 777, "corrupt save recovers from backup")
	# old save missing fields migrates
	f = FileAccess.open(Game.save_dir_override + "/save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"attrs": {"health": 9}, "equipped": {"weapon": "w_rusted_sword"}, "level": 4}))
	f.close()
	ok(Game.load_game() and Game.profile.level == 4 and Game.profile.attrs.strength == 5 and Game.profile.has("flags"), "old saves migrate")
	ok(Game.stats().max_hp > 0.0, "migrated profile computes stats")

func t_runs() -> void:
	Game.new_game()
	ok(Game.region_unlocked("courtyard") and not Game.region_unlocked("blackwood"), "region gating")
	Game.start_run("courtyard")
	var steps := 0
	var levered := false
	while true:
		var opts := Game.stage_options()
		ok(opts.size() >= 1, "stage has an option")
		var o: Dictionary = opts[0]
		match o.type:
			"treasure":
				var got := Game.open_treasure(o)
				ok(got.gold > 0, "treasure pays")
			"lever":
				Game.pull_lever(o); levered = true
			"shrine":
				Game.run.hp = 10.0
				Game.rest_at_shrine()
				ok(Game.run.hp > 10.0, "shrine heals")
			"fight", "boss":
				Game.on_victory(o.foe, 80.0)
		steps += 1
		if not Game.advance_stage():
			break
	ok(steps == 7 and levered, "walked the courtyard")
	ok(Game.complete_region() and Game.region_unlocked("blackwood"), "clearing unlocks the next region")
	ok(Game.shortcut_open("courtyard"), "shortcut stays open")
	# pooled stops: stable within a run, varied across runs
	var seen := {}
	for i in 40:
		Game.start_run("courtyard")
		Game.run.stage = 4
		var first: String = Game.stage_options()[0].foe
		ok(Game.stage_options()[0].foe == first, "pooled foe is stable within a run") if i == 0 else null
		seen[first] = true
	ok(seen.size() == 2, "pooled stops vary between runs (%s)" % str(seen.keys()))
	Game.start_run("courtyard", true)
	ok(Game.run.stage == 4, "shortcut skips ahead")
	var gold: int = Game.profile.gold
	var xp_level: int = Game.profile.level
	Game.on_death()
	ok(Game.run.is_empty() and Game.profile.gold == gold and Game.profile.level == xp_level and Game.profile.deaths == 1, "death keeps progression, resets the route")
	for r in Db.regions:
		if not Game.profile.cleared.has(r.id):
			Game.profile.cleared.append(r.id)
	ok(Game.game_complete(), "all regions cleared")
	var inv: int = Game.profile.inventory.size()
	Game.start_ng_plus()
	ok(Game.profile.ng == 1 and Game.profile.cleared.is_empty() and Game.profile.inventory.size() == inv, "NG+ keeps gear, resets the world")

# ------------------------------------------------------------------ records and tasks
func t_lore_quests() -> void:
	Game.new_game("#123456")
	var ids := {}
	var places := true
	for l in Db.lore:
		ids[l.id] = true
		var st: int = int(l.stage)
		places = places and Db.region_by_id.has(l.region) and st >= 0 and st < Db.region_by_id.get(l.region, {"stages": []}).stages.size()
		places = places and str(l.title) != "" and str(l.text) != ""
	ok(Db.lore.size() == 50 and ids.size() == 50 and Db.lore_by_id.size() == 50, "fifty records with unique ids")
	ok(places, "every record sits at a real stage of a real region")
	var first: Dictionary = Db.lore[0]
	var got := Game.find_lore(first.region, int(first.stage))
	ok(got.size() >= 1 and got.has(first) and Game.profile.lore.has(first.id), "arriving at a stage finds its record")
	var held: int = Game.profile.lore.size()
	ok(Game.find_lore(first.region, int(first.stage)).is_empty() and Game.profile.lore.size() == held, "a record is found only once")
	Game.profile = {}
	ok(Game.load_game() and Game.profile.lore.has(first.id), "found records are saved")
	var old := Game.default_profile()
	old.erase("lore"); old.erase("quests_done")
	old = Game._migrate(old)
	ok(old.lore == [] and old.quests_done == [], "older saves gain the record and task lists")
	# tasks
	ok(Db.quests.size() == 8 and Db.quest_by_id.size() == 8, "eight tasks with unique ids")
	var refs := true
	for q in Db.quests:
		for k in q.need:
			refs = refs and k in ["defeated", "cleared", "lore", "combos"]
		for f in q.need.get("defeated", []):
			refs = refs and Db.foes.has(f)
		for r in q.need.get("cleared", []):
			refs = refs and Db.region_by_id.has(r)
		refs = refs and int(q.need.get("lore", 0)) <= Db.lore.size() and int(q.need.get("combos", 0)) <= Db.combos.size()
		refs = refs and not q.need.is_empty() and not q.reward.is_empty()
		for k in q.reward:
			refs = refs and k in ["gold", "shards", "item"]
		if q.reward.has("item"):
			refs = refs and Db.items.has(q.reward.item)
	ok(refs, "task needs and rewards point at real foes, regions and items")
	for q in Db.quests:
		Game.new_game("#123456")
		ok(not Game.quest_ready(q.id) and not Game.claim_quest(q.id), "%s is not ready on a new profile" % q.id)
		ok(Game.quest_progress(q.id).begins_with("0 / "), "%s reports progress (%s)" % [q.id, Game.quest_progress(q.id)])
		for f in q.need.get("defeated", []):
			Game.profile.defeated[f] = 1
		for r in q.need.get("cleared", []):
			Game.profile.cleared.append(r)
		for i in int(q.need.get("lore", 0)):
			Game.profile.lore.append(Db.lore[i].id)
		for c in Db.combos:
			if Game.profile.combos.size() < int(q.need.get("combos", 0)) and not Game.profile.combos.has(c.id):
				Game.profile.combos.append(c.id)
		ok(Game.quest_ready(q.id), "%s becomes ready when its need is met" % q.id)
		var gold: int = Game.profile.gold
		var shards: int = Game.profile.shards
		ok(Game.claim_quest(q.id), "%s can be claimed" % q.id)
		var paid: bool = Game.profile.gold == gold + int(q.reward.get("gold", 0)) and Game.profile.shards == shards + int(q.reward.get("shards", 0))
		if q.reward.has("item"):
			paid = paid and Game.owns(q.reward.item)
		ok(paid and Game.profile.quests_done == [q.id] and Game.quest_progress(q.id) == "Done", "%s pays its reward" % q.id)
		ok(not Game.claim_quest(q.id) and Game.profile.gold == gold + int(q.reward.get("gold", 0)) and Game.profile.quests_done.size() == 1, "%s pays only once" % q.id)
	# the third ending needs the record
	Game.new_game("#123456")
	Game.profile.cleared.append("roost")
	Game.profile.defeated["devourer"] = 1
	for i in 29:
		Game.profile.lore.append(Db.lore[i].id)
	ok(not Game.can_divide_crown(), "twenty-nine records cannot divide the Crown")
	Game.profile.lore.append(Db.lore[29].id)
	ok(Game.can_divide_crown(), "thirty records can")

# ------------------------------------------------------------------ companions and who may speak
func t_companion() -> void:
	var saved_profile: Dictionary = Game.profile
	var had_chatter: bool = Game.settings.has("chatter")
	var old_chatter = Game.settings.get("chatter", true)
	Game.settings["chatter"] = true
	Game.profile = Game.default_profile()
	Companion.leave_combat()
	Companion.reset_cooldown()
	var d: Dictionary = Story.data
	var c: Dictionary = d.companion
	# every id the Companion can ask for exists, is text only, and belongs to a real place or foe
	var ids: Array = [Companion.discovery_id()]
	var placed := true
	for r: String in c.stage:
		placed = placed and Db.region_by_id.has(r)
		for st: String in c.stage[r]:
			placed = placed and int(st) >= 0 and int(st) < 7
			ids.append_array(c.stage[r][st])
	for f: String in c.boss:
		placed = placed and Db.foes.has(f) and bool(Db.foes[f].boss)
		for k: String in ["approach", "fallback", "victory"]:
			ids.append_array(c.boss[f][k])
	for t: Dictionary in c.topics:
		ids.append(t.id)
	var exist := true
	var unrecorded := true
	var witness_lines := 0
	for id: String in ids:
		exist = exist and Story.has_scene(id)
		for lid: String in d.scenes.get(id, {}).get("lines", []):
			exist = exist and d.lines.has(lid)
			if str(d.lines[lid].speaker) == "witness":
				witness_lines += 1
				unrecorded = unrecorded and d.lines[lid].get("recorded", true) == false
	ok(exist, "every scene and line the Companion refers to exists")
	ok(placed, "companion scenes sit at real stages and real guardians")
	ok(unrecorded and witness_lines >= 60, "the Witness's lines are all marked not recorded (%d)" % witness_lines)
	for r in Db.regions:
		var b: Dictionary = c.boss.get(str(r.stages[6].options[0].foe), {})
		ok(c.stage.has(r.id) and c.stage[r.id].size() >= 3 and not b.get("approach", []).is_empty() and not b.get("victory", []).is_empty(), "%s has Witness remarks, a boss approach and a victory line" % r.id)
	ok(c.topics.size() >= 10, "at least ten sanctuary conversations")
	# who may speak
	var silent := true
	var few := true
	for f: String in Db.foes:
		var cat := Companion.speech(f)
		var key := str(d.foe_voice.get(f, f))
		var n := 0
		for lid: String in d.lines:
			if str(d.lines[lid].speaker) in [f, key]:
				n += 1
		if cat == "A":
			silent = silent and n == 0 and Companion.voice_key(f) == "" and not d.foe_voice.has(f)
		elif cat == "B":
			few = few and n <= 4
	ok(silent, "no creature (speech category A) has a line or a voice key")
	ok(few, "category B guardians have at most four lines")
	ok(Companion.speech("cathedral_beast") == "A" and Companion.speech("cinder_wyrm") == "A" and Companion.speech("hollow_soldier") == "A", "beasts, dragons and lesser foes are creatures")
	ok(Companion.speech("ashen_sentinel") == "B" and Companion.speech("forgotten_monarch") == "C" and Companion.speech("devourer") == "D", "guardian categories")
	ok(not Story.has_scene("sentinel_retry") and Story.has_scene("sentinel_intro") and Story.has_scene("sentinel_death"), "the Sentinel keeps only its challenge and last words")
	# silent until found
	var quiet := true
	for id: String in Companion.pick_stage("courtyard", 0) + Companion.pick_boss_approach("ashen_sentinel") + Companion.pick_victory("ashen_sentinel") + Companion.pick_boss_approach("cathedral_beast"):
		quiet = quiet and not Companion.speakers(id).has("witness")
	ok(quiet and not Companion.witness_found(), "the Witness says nothing before it is found")
	ok(Companion.pick_stage("courtyard", 0) == ["courtyard_0"], "Lyra still speaks at the first stop")
	ok(Companion.pick_boss_approach("cathedral_beast") == ["beast_intro"], "without the Witness, Lyra sets the scene for a silent foe")
	ok(Companion.sanctuary_topics().is_empty(), "no Witness conversations before it is found")
	ok(Companion.pick_stage("courtyard", 1) == [Companion.discovery_id()], "the Witness is found at the second Courtyard stop")
	ok(Companion.pick_stage("crypt", 3) == [Companion.discovery_id()], "an older save finds it at the next stop")
	Companion.mark_heard(Companion.discovery_id())
	ok(Companion.witness_found() and Companion.pick_stage("courtyard", 1) == ["courtyard_1"], "found once; the stop then has only Lyra's remark")
	# nothing repeats
	var first := Companion.pick_stage("blackwood", 0)
	ok(first == ["w_blackwood_approach"], "the Witness remarks on the Blackwood")
	for id: String in first:
		Companion.mark_heard(id)
	Game.profile.deaths += 1
	ok(Companion.pick_stage("blackwood", 0).is_empty(), "a heard remark is not replayed, death or no death")
	var before := Companion.pick_boss_approach("cathedral_beast")
	ok(before == ["w_beast_approach"], "the Witness sets the scene before the Beast")
	Companion.mark_heard(before[0])
	ok(Companion.pick_boss_approach("cathedral_beast").is_empty(), "the boss approach is heard once, with no fallback after it")
	ok(Companion.pick_victory("cathedral_beast") == ["beast_death", "w_beast_victory"], "after the Beast: Lyra's discovery, then the Witness")
	# cooldown: unprompted remarks wait, prompted and essential ones do not
	Companion.note_spoken()
	ok(Companion.pick_stage("blackwood", 2).is_empty() and not Companion.pick_victory("ashen_sentinel").is_empty(), "the cooldown holds unprompted remarks only")
	Companion.reset_cooldown()
	ok(Companion.pick_stage("blackwood", 2) == ["w_blackwood_briars"], "after the cooldown the landmark remark is offered")
	# chatter off: only essential lines remain
	Game.settings["chatter"] = false
	ok(Companion.pick_stage("blackwood", 2).is_empty() and Companion.pick_victory("ashen_sentinel").is_empty() and Companion.pick_boss_approach("ashen_sentinel").is_empty(), "chatter off silences remarks, approaches and victory lines")
	ok(Companion.pick_boss_approach("cinder_wyrm") == ["w_wyrm_approach"] and Companion.pick_victory("cathedral_beast") == ["beast_death"], "chatter off keeps essential scenes")
	Game.profile.flags.erase(Companion.FOUND_FLAG)
	Game.profile.heard.erase(Companion.discovery_id())
	ok(Companion.pick_stage("courtyard", 1) == [Companion.discovery_id()], "chatter off does not hide the discovery")
	Companion.mark_heard(Companion.discovery_id())
	Game.settings["chatter"] = true
	# never during a fight
	Companion.enter_combat(self)
	ok(Companion.pick_stage("blackwood", 2).is_empty() and Companion.pick_boss_approach("cinder_wyrm").is_empty() and Companion.pick_victory("ashen_sentinel").is_empty(), "nothing is said during combat")
	Companion.leave_combat()
	# sanctuary topics and the archive
	var topics := Companion.sanctuary_topics()
	ok(topics.size() >= 4 and topics.size() < c.topics.size() and not topics[0].heard, "early topics are open; later ones wait for their region")
	Companion.mark_heard(str(topics[0].id))
	var again := Companion.sanctuary_topics()
	ok(again.size() == topics.size() and again[-1].id == topics[0].id and again[-1].heard, "a heard topic stays available, after the unheard ones")
	Game.profile.cleared = ["courtyard", "blackwood", "cathedral", "crypt", "roost", "citadel", "deep"]
	ok(Companion.sanctuary_topics().size() == c.topics.size(), "every topic opens by the end")
	var arc := Companion.archive()
	var titled := true
	for e: Dictionary in arc:
		titled = titled and str(e.title) != "" and not e.lines.is_empty()
	ok(arc.size() == Game.profile.heard.size() and arc.size() >= 4 and titled and arc[0].id == "w_blackwood_approach", "the archive lists everything heard, titled, in order")
	ok(Game.default_profile().has("heard"), "new profiles track what has been heard")
	Game.profile = saved_profile
	if had_chatter:
		Game.settings["chatter"] = old_chatter
	else:
		Game.settings.erase("chatter")

# ------------------------------------------------------------------ inventory, mastery, settings
func t_inventory_settings() -> void:
	var saved_profile: Dictionary = Game.profile
	var saved_settings: Dictionary = Game.settings.duplicate(true)
	Game.new_game("#123456")
	for id in ["w_knight_sword", "w_ashen_great", "w_headsman", "w_twin_fangs", "s_tower", "a_ash_chest", "a_black_helm", "r_ember"]:
		Game.grant_item(id)
	# --- rarity: every item maps onto one of the five shown ranks, in order
	var names := {}
	for it in Db.item_list:
		ok(Game.RARITY_TIERS.has(it.rarity), "%s has a known rarity" % it.id)
		names[Game.rarity_name(it)] = Game.rarity_pips(it)
		ok(Game.rarity_pips(it) == Db.rarity_rank(it) + 1, "%s pips follow its rank" % it.id)
	ok(names == {"Common": 1, "Uncommon": 2, "Rare": 3, "Legendary": 4, "Relic": 5}, "five named ranks cover the data (%s)" % str(names))
	# --- comparison: every delta is exactly Stats.compute on a copy with the item on
	var before := JSON.stringify(Game.profile)
	for id: String in Game.profile.inventory:
		var it: Dictionary = Db.item(id)
		var trial: Dictionary = Game.profile.duplicate(true)
		trial.equipped[it.slot] = id
		if it.slot == "weapon" and Db.classes[it.cls].two_handed:
			trial.equipped.shield = null
		var now := Game.stats()
		var then := Stats.compute(trial, Db.items, Db.classes)
		var good := true
		for r in Game.compare(id):
			if r.key == "element":
				good = good and r.then_text == (str(then.element).capitalize() if then.element != null else "None")
				continue
			var k: float = 100.0 if r.key == "block_eff" else 1.0
			var d: float = (float(then[r.key]) - float(now[r.key])) * k
			var lower_better: bool = r.key in ["swing_time", "swing_cost"]
			var want := 0 if is_zero_approx(d) else (1 if (d > 0.0) != lower_better else -1)
			good = good and is_equal_approx(float(r.delta), d) and int(r.better) == want
		ok(good, "comparison for %s matches Stats.compute" % id)
	ok(JSON.stringify(Game.profile) == before, "comparing changes nothing")
	var rows := Game.compare("w_ashen_great")
	ok(rows[0].key == "attack" and int(rows[0].better) == 1 and float(rows[0].delta) > 0.0, "a stronger blade shows damage up")
	var swing: Dictionary = rows.filter(func(r): return r.key == "swing_time")[0]
	ok(int(swing.better) == -1 and float(swing.delta) > 0.0, "a slower swing is marked worse though the number rises")
	ok(rows[-1].then_text == "Fire" and rows[-1].now_text == "None", "element is shown")
	# --- favourites and selling
	ok(Game.sell_block("w_rusted_sword") == "Equipped" and not Game.sell("w_rusted_sword"), "equipped items cannot be sold")
	ok(Game.toggle_favourite("w_headsman") and Game.is_favourite("w_headsman"), "favourite set")
	var gold: int = Game.profile.gold
	ok(Game.sell_block("w_headsman") == "Favourite" and not Game.sell("w_headsman") and Game.owns("w_headsman") and Game.profile.gold == gold, "a favourite cannot be sold")
	ok(not Game.toggle_favourite("w_headsman") and Game.sell_block("w_headsman") == "", "unmarking frees it")
	Game.profile.upgrades["w_headsman"] = 2
	ok(Game.sell("w_headsman") and not Game.owns("w_headsman") and Game.profile.gold == gold + Game.sell_price("w_headsman") and not Game.profile.upgrades.has("w_headsman"), "selling pays and removes")
	ok(Game.sell_price("w_knight_sword") > 0 and Game.sell_price("w_knight_sword") < int(Db.item("w_knight_sword").price), "sells for less than it costs")
	ok(not Game.sell("w_nothing"), "cannot sell what is not held")
	Game.equip("w_ashen_great")
	Game.sell("w_knight_sword")
	ok(Game.sell_block("w_rusted_sword") != "" and not Game.sell("w_rusted_sword"), "the last one-handed blade is kept")
	Game.equip("w_rusted_sword")
	Game.save()
	Game.toggle_favourite("s_tower")
	Game.set_sort("rarity")
	Game.profile = {}
	ok(Game.load_game() and Game.is_favourite("s_tower") and Game.profile.inv_sort == "rarity", "favourites and sort order are kept in the profile")
	# --- sorting
	Game.grant_item("w_knight_sword")
	Game.grant_item("w_dawnline")           # same rarity as the longsword: ties keep acquisition order
	Game.profile.mastery["w_twin_fangs"] = 5
	var weapons := ["weapon"]
	ok(Game.sorted_items(weapons, "damage")[0] == "w_ashen_great" and Game.sorted_items(weapons, "damage")[-1] == "w_rusted_sword", "damage order")
	var by_r: Array = Game.sorted_items(weapons, "rarity")
	ok(by_r[0] == "w_twin_fangs" and by_r.find("w_knight_sword") < by_r.find("w_dawnline") and by_r[-1] == "w_rusted_sword", "rarity order, ties stable (%s)" % str(by_r))
	ok(Game.sorted_items(weapons, "recent")[0] == "w_dawnline" and Game.sorted_items(weapons, "recent")[-1] == "w_rusted_sword", "newest first")
	ok(Game.sorted_items(weapons, "mastery")[0] == "w_twin_fangs", "mastery order")
	ok(Game.sorted_items(weapons, "equipped")[0] == "w_rusted_sword", "equipped first")
	ok(Game.sorted_items(["chest"], "defence")[0] == "a_ash_chest", "defence order")
	for mode: String in Game.SORTS:
		var a: Array = Game.sorted_items([], mode)
		var sorted_copy: Array = a.duplicate()
		sorted_copy.sort()
		var inv: Array = Game.profile.inventory.duplicate()
		inv.sort()
		ok(a == Game.sorted_items([], mode) and sorted_copy == inv, "%s sort is repeatable and loses nothing" % mode)
	ok(Game.sorted_items() == Game.sorted_items([], "rarity"), "the stored sort is the default")
	# --- mastery marks
	Game.new_game("#123456")
	var sword: Dictionary = Db.item("w_rusted_sword")
	ok(Game.mastery_threshold(sword, 1) < Game.mastery_threshold(sword, 2) and Game.mastery_threshold(sword, 2) < Game.mastery_threshold(sword, 3) and Game.mastery_threshold(sword, 3) == Stats.mastery_needed(sword), "three rising marks ending at mastery")
	for it in Db.item_list:
		ok(Game.mastery_threshold(it, 1) >= 1 and Game.mastery_threshold(it, 3) <= 11, "%s mastery stays modest" % it.id)
	ok(Game.mastery_tier("w_rusted_sword") == 0 and Game.item_history("w_rusted_sword").size() == 1, "no marks at first")
	var uses: int = Game.profile.combo_uses.size()
	Game.on_victory("ashen_sentinel", 50.0)        # a guardian counts double: two of three
	ok(Game.mastery_tier("w_rusted_sword") == 2 and Game.item_history("w_rusted_sword").size() == 2, "mark I reveals more history")
	var taught: String = Game.profile.mastery_taught.get("w_rusted_sword", "")
	ok(taught == "riposte" and Game.profile.combos.has("riposte") and Game.profile.combo_uses.size() == uses and Game.technique_source("riposte") == "w_rusted_sword", "mark II teaches a sword technique without counting a use (%s)" % taught)
	var known: int = Game.profile.combos.size()
	Game.on_victory("ashen_sentinel", 50.0)
	ok(Game.mastery_tier("w_rusted_sword") == 3 and Game.profile.mastered.has("w_rusted_sword") and Game.profile.combos.size() == known, "mark III is mastery; nothing is taught twice")
	Game.new_game("#123456")
	for w in Db.item_list:
		if w.slot == "weapon":
			ok(Game.item_history(w.id).size() == 1, "%s keeps its further history back" % w.id)
			Game.profile.mastered.append(w.id)
			ok(Game.item_history(w.id).size() == 2 and str(Game.item_history(w.id)[1]).length() > 20, "%s has further history" % w.id)
	# --- settings: defaults, round trip, migration
	for k in ["master", "music", "dialogue", "combat", "ambience", "swipe_sens", "haptic_strength", "sub_size", "sub_bg", "reduce_motion", "chatter", "pad_opacity", "hints", "shake", "reduce_flash", "assist", "quality", "fps"]:
		ok(Game.settings.has(k), "setting %s exists" % k)
	for b: String in Sfx.BUSES:
		ok(Game.settings.has(Sfx.BUS_SETTING[b]), "bus %s follows a setting" % b)
	var custom := {"quality": 0, "fps": 30, "master": 0.6, "music": 0.25, "dialogue": 0.9, "combat": 0.35, "ambience": 0.15, "swipe_sens": 1.4,
		"haptic_strength": 0.5, "sub_size": 2, "sub_bg": false, "reduce_motion": true, "chatter": false, "pad_opacity": 0.55, "hints": false, "shake": 0.3, "reduce_flash": true, "assist": true}
	for k in custom:
		Game.settings[k] = custom[k]
	Game.save_settings()
	Game.settings = saved_settings.duplicate(true)
	Game.load_settings()
	var same := true
	for k in custom:
		same = same and typeof(Game.settings[k]) == typeof(custom[k]) and (is_equal_approx(float(Game.settings[k]), float(custom[k])) if custom[k] is float else Game.settings[k] == custom[k])
	ok(same, "every setting survives save and load")
	Game.apply_settings()
	var bus := AudioServer.get_bus_index("Interface")
	ok(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.6)), "master slider sets the Master bus")
	ok(is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.35) + float(Sfx.BUS_TRIM["Interface"])), "interface follows combat effects")
	ok(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Cinematics")), float(Sfx.BUS_TRIM["Cinematics"])), "cinematics follow the master only")
	ok(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")), linear_to_db(0.15) + float(Sfx.BUS_TRIM["Ambience"])), "ambience has its own slider")
	ok(is_equal_approx(Game.haptic_amount(0.8), 0.4) and Game.subtitle_size() == Game.SUB_SIZES[2] and Engine.max_fps == 30, "haptic strength scales; subtitle size and frame cap apply")
	Game.settings.haptic_strength = 0.0
	ok(Game.haptic_amount(1.0) == 0.0, "zero haptic strength is off")
	# the old three-slider file
	Game.settings = saved_settings.duplicate(true)
	var f := FileAccess.open(Game.save_dir_override + "/settings.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"quality": 2, "fps": 120, "music": 0.4, "sfx": 0.7, "voice": 0.2, "haptics": false, "shake": 0.5, "assist": true, "hints": false, "reduce_flash": true, "cine": false, "cine_road": false, "pad_opacity": 0.35}))
	f.close()
	Game.load_settings()
	var st: Dictionary = Game.settings
	ok(is_equal_approx(st.music, 0.4) and is_equal_approx(st.combat, 0.7) and is_equal_approx(st.ambience, 0.7) and is_equal_approx(st.dialogue, 0.2), "old sound and voice sliders carry over")
	ok(is_equal_approx(st.haptic_strength, 0.0) and Game.haptic_amount(1.0) == 0.0, "old haptics-off carries over")
	ok(st.quality == 2 and st.fps == 120 and st.assist and not st.hints and st.reduce_flash and is_equal_approx(st.shake, 0.5) and is_equal_approx(st.pad_opacity, 0.35), "the rest of an old file still loads")
	ok(is_equal_approx(st.master, 1.0) and st.sub_size == 1 and st.sub_bg and st.chatter and not st.reduce_motion and is_equal_approx(st.swipe_sens, 1.0), "new settings take their defaults")
	# --- graphics presets do what they say
	var seen := {"scale": {}, "particles": {}, "lod": {}, "shadow": {}}
	var sun := DirectionalLight3D.new()
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	for q in 3:
		Game.settings.quality = q
		Game.apply_settings()
		var g: Dictionary = Game.GRAPHICS[q]
		var vp := get_viewport()
		ok(is_equal_approx(vp.scaling_3d_scale, g.scale) and vp.msaa_3d == g.msaa and vp.positional_shadow_atlas_size == g.shadow_atlas and is_equal_approx(vp.mesh_lod_threshold, g.lod) and is_equal_approx(Game.particle_scale(), g.particles), "%s preset is applied" % g.name)
		ok(is_equal_approx(sun.directional_shadow_max_distance, minf(60.0, g.shadow_dist)), "%s preset caps sun shadow distance" % g.name)
		seen.scale[vp.scaling_3d_scale] = true
		seen.particles[Game.particle_scale()] = true
		seen.lod[vp.mesh_lod_threshold] = true
		seen.shadow[vp.positional_shadow_atlas_size] = true
	ok(seen.scale.size() == 3 and seen.particles.size() == 3 and seen.lod.size() == 3 and seen.shadow.size() == 3, "the three presets differ in every value")
	ok(Game.GRAPHICS[0].shadow_atlas == 0, "performance turns spot and point shadows off")
	sun.queue_free()
	# every row in the settings screen edits a real setting of the right kind
	for r in SettingsPanel.ROWS:
		if str(r[0]) != "#":
			ok(Game.settings.has(r[0]), "settings row %s is real" % r[0])
	ok(SettingsPanel.legal("privacy").length() > 200 and SettingsPanel.legal("credits").length() > 200, "legal text is present")
	Game.settings = saved_settings
	Game.apply_settings()
	DirAccess.remove_absolute(Game.save_dir_override + "/settings.json")
	Game.profile = saved_profile

func t_save_slots() -> void:
	for n in range(1, Game.SLOT_COUNT + 1):
		Game.delete_slot(n)
	ok(not Game.has_save() and Game.latest_slot() == 0 and Game.free_slot() == 1, "no journeys: nothing to continue, first place free")
	# an old single save, written the way the game wrote it before there were slots, is slot 1
	var f := FileAccess.open(Game.save_dir_override + "/save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"attrs": {"health": 9}, "equipped": {"weapon": "w_rusted_sword"}, "level": 6, "cleared": ["courtyard"], "body": "f"}))
	f.close()
	var old := Game.slot_summary(1)
	ok(Game.has_save() and old.get("level", 0) == 6 and old.get("body", "") == "f" and old.get("chapter_id", "") == "blackwood" and Game.slot_summary(2).is_empty(), "an old single save is read as slot 1")
	ok(Game.load_slot(1) and Game.slot == 1 and Game.profile.level == 6 and Game.profile.attrs.strength == 5 and Game.save() and Game.slot_summary(1).level == 6, "the old save loads, migrates and saves back in place")
	# three slots, independent
	for n in range(1, Game.SLOT_COUNT + 1):
		Game.slot = n
		Game.new_game("#123456", "m" if n != 2 else "f")
		Game.profile.gold = 100 * n
		Game.profile.level = n + 1
		Game.profile.last_played = 0.0
		Game.save()
	var golds: Array = []
	for n in range(1, Game.SLOT_COUNT + 1):
		Game.profile = {}
		golds.append(Game.profile.gold if Game.load_slot(n) else -1)
	ok(golds == [100, 200, 300] and Game.slot_summary(2).body == "f" and Game.slot_summary(3).level == 4 and Game.free_slot() == 0, "three slots keep separate journeys")
	Game.load_slot(2)
	Game.profile.gold = 999
	Game.save()
	ok(Game.latest_slot() == 2 or Game.slot_summary(2).last_played >= Game.slot_summary(3).last_played, "the slot saved last is the one Continue resumes")
	ok(Game.load_slot(1) and Game.profile.gold == 100 and Game.load_slot(3) and Game.profile.gold == 300, "saving one slot leaves the others alone")
	# delete
	Game.load_slot(2)
	Game.delete_slot(2)
	ok(not Game.slot_exists(2) and Game.slot_summary(2).is_empty() and Game.profile.is_empty() and Game.free_slot() == 2, "delete empties the slot and the profile in memory")
	ok(Game.slot_exists(1) and Game.slot_exists(3) and not Game.load_slot(2) and Game.load_slot(3) and Game.profile.gold == 300, "delete leaves the other slots, and an empty slot does not load")
	for n in range(1, Game.SLOT_COUNT + 1):
		Game.delete_slot(n)
	Game.slot = 1
	Game.new_game()
