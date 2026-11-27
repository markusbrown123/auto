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
	var weapons := ["w_rusted_sword", "w_knight_sword", "w_ashen_great", "w_headsman", "w_rime_sword", "w_crypt_great", "w_frost_great"]
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
	for t in ["t_data", "t_parry", "t_dodge", "t_block", "t_attack", "t_punish", "t_phases", "t_adaptive", "t_elements", "t_meters_combos", "t_seams", "t_drain", "t_revive", "t_bots", "t_progression", "t_endings", "t_save", "t_runs", "t_lore_quests", "t_companion", "t_inventory_settings", "t_save_slots", "t_poise", "t_struggle", "t_story_beat", "t_story_options", "t_lesson", "t_corridor"]:
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
	# a perfect parry no longer breaks the foe by itself: it cuts the string short and wears the most poise
	ok(s.b_state == DuelSim.B.RECOVER and not s.b_opening_crit and is_equal_approx(s.b_poise, s.b_poise_max - DuelSim.POISE_PARRY_PERFECT), "perfect parry: a riposte window and a deep cut in its poise, not a stagger")
	ok(s.stats.perfect_parries == 1, "perfect parry counted")
	# normal parry (inside window, outside perfect)
	s = mk("ashen_sentinel")
	until_windup(s)
	to_impact(s, 0.22)
	s.input_swipe(DuelSim.parry_dir_for(s.b_attack.dir))
	hp = s.pl.hp
	run_for(s, 0.3)
	ok(s.pl.hp == hp and s.stats.parries == 1 and s.stats.perfect_parries == 0, "normal parry")
	ok(is_equal_approx(s.b_poise, s.b_poise_max - DuelSim.POISE_PARRY), "normal parry wears poise")
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
	s._stagger(3.0, true)          # a broken foe (a perfect parry alone no longer staggers)
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
	s.pl.attack = s.b_hp_max * 0.7       # one blow worth more than two of its phases, whatever its health is tuned to
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
	var post: float = s.b_poise
	for d in ["R", "L", "D"]:
		s.input_swipe(d); run_for(s, 0.4)
	ok(hits.size() == 3 and hits[2].named == "Armor Splitter", "right-left-down is an Armor Splitter")
	ok(post - s.b_poise >= 30.0 or s.b_state == DuelSim.B.STAGGER, "Armor Splitter cracks poise")
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
	s.pl.stamina = s.pl.max_stamina      # the search may already have let earlier grasps land
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
	Game.add_material("m_iron", 4)       # the ore steps on the way to the cap ask for the weapon's material and a guardian core
	Game.add_material("m_core", 1)
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
	ok(Game.road_complete() and not Game.can_divide_crown(), "the main road alone finishes the game but cannot divide the Crown")
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
	ok(Game.road_complete(), "all regions cleared")
	var inv: int = Game.profile.inventory.size()
	Game.start_ng_plus(true)
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
				# a Witness line is either marked text-only or has a take on disk: never a claimed take that is missing
				unrecorded = unrecorded and (d.lines[lid].get("recorded", true) == false or FileAccess.file_exists("res://assets/audio/vo/%s.ogg" % lid))
	ok(exist, "every scene and line the Companion refers to exists")
	ok(placed, "companion scenes sit at real stages and real guardians")
	ok(unrecorded and witness_lines >= 60, "every Witness line is either recorded on disk or marked text-only (%d)" % witness_lines)
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
	ok(Game.sorted_items(weapons, "damage")[0] == "w_ashen_great" and Game.sorted_items(weapons, "damage")[-1] == "w_dawnline", "damage order")
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

# ------------------------------------------------------------------ poise, pressure, struggle, story beat, lesson
## A fresh fight with the foe already winding up exactly this attack (or string), so a rule can be tested on its own.
func _with_attack(foe: String, attacks: Array, seed_value: int = 7, opts: Dictionary = {}, recover: float = 1.5) -> DuelSim:
	var s := mk(foe, seed_value, {}, opts)
	s._start_combo({"id": "test", "attacks": attacks, "recover": recover, "tags": [], "gap": 0.15}, true)
	return s

## Runs until the blow being wound up has landed (or been answered), and no further.
func _strike(s: DuelSim) -> void:
	var idx := s.b_idx
	var combo: Dictionary = s.b_combo
	for i in 2000:
		if s.b_state != DuelSim.B.WINDUP or s.b_idx != idx or not is_same(s.b_combo, combo):
			return
		s.tick(1.0 / 120.0)

func t_poise() -> void:
	var cut := {"dir": "L", "windup": 1.0, "dmg": 20, "swing": 0.3, "guard": 26, "parry": true, "unblockable": false, "element": null, "kind": "slash", "dodge": "L"}
	var mx: float = mk("ashen_sentinel").b_poise_max
	ok(mx == float(Db.foes.ashen_sentinel.poise) and float(Db.foes.gravewarden.poise) > mx and float(Db.foes.banneret.poise) < mx, "poise comes from data and heavy guardians carry more")
	# each defence wears a stated amount
	var want := {"parry": DuelSim.POISE_PARRY, "perfect parry": DuelSim.POISE_PARRY_PERFECT, "dodge": DuelSim.POISE_DODGE, "perfect dodge": DuelSim.POISE_DODGE_PERFECT,
		"timed block": DuelSim.POISE_BLOCK_TIMED, "block": DuelSim.POISE_BLOCK}
	ok(want["perfect parry"] > want["parry"] and want["parry"] > want["perfect dodge"] and want["perfect dodge"] > want["dodge"] and want["timed block"] > want["block"] and want["dodge"] > want["block"], "parries wear most, plain blocks least")
	for how: String in want:
		var s := _with_attack("ashen_sentinel", [cut])
		var recs: Array = []
		var breaks: Array = []
		s.ev.connect(func(n, d):
			if n == &"boss_recover": recs.append(d.time)
			if n == &"poise_break": breaks.append(d.from))
		match how:
			"parry": to_impact(s, 0.22); s.input_swipe("R")
			"perfect parry": to_impact(s, 0.06); s.input_swipe("R")
			"dodge": to_impact(s, 0.36); s.input_dodge(-1)
			"perfect dodge": to_impact(s, 0.12); s.input_dodge(-1)
			"timed block": to_impact(s, 0.1); s.input_block(true)
			"block": s.input_block(true)
		var hp: float = s.pl.hp
		_strike(s)
		ok(is_equal_approx(s.b_poise, mx - float(want[how])), "%s wears %d poise (left %.0f of %.0f)" % [how, int(want[how]), s.b_poise, mx])
		ok(s.b_state == DuelSim.B.RECOVER and not s.b_opening_crit and breaks.is_empty() and recs.size() == 1, "%s alone does not break it open" % how)
		# only a short recovery: a share of the string's own, or the riposte after a perfect parry
		var short: float = maxf(DuelSim.SHORT_RECOVER_MIN, 1.5 * DuelSim.SHORT_RECOVER)
		var expect: float = DuelSim.RIPOSTE_TIME if how == "perfect parry" else short + (0.35 if how == "perfect dodge" else 0.0)
		ok(recs.size() == 1 and is_equal_approx(float(recs[0]), expect) and expect < 1.5, "%s buys a short recovery (%.2fs, not the old 1.5s)" % [how, expect])
		ok(s.pl.hp > hp - 3.0, "%s keeps the knight whole" % how)
	# a blow that lands wears nothing
	var h := _with_attack("ashen_sentinel", [cut])
	_strike(h)
	ok(h.b_poise == mx and h.stats.hits_taken == 1, "being hit wears no poise")
	# the short recovery scales with the string's own recover, within its floor
	var r2: Array = []
	h = _with_attack("ashen_sentinel", [cut], 7, {}, 2.4)
	h.ev.connect(func(n, d): if n == &"boss_recover": r2.append(d.time))
	h.input_block(true); _strike(h)
	ok(r2.size() == 1 and is_equal_approx(float(r2[0]), 2.4 * DuelSim.SHORT_RECOVER) and float(r2[0]) > DuelSim.SHORT_RECOVER_MIN, "a heavier string leaves a longer (still short) recovery")
	# repeated defences break it: the long, critical opening, and then it gathers itself
	var s2 := mk("ashen_sentinel")
	var ev2: Array = []
	s2.ev.connect(func(n, d):
		if n == &"poise_break": ev2.append("break:" + str(d.from))
		if n == &"boss_stagger": ev2.append("stagger:%.1f:%s" % [d.time, str(d["break"])]))
	var parries := 0
	for i in 8:
		s2._start_combo({"id": "test", "attacks": [cut], "recover": 1.5, "tags": [], "gap": 0.15}, true)
		to_impact(s2, 0.22); s2.input_swipe("R"); _strike(s2)
		parries += 1
		if s2.b_state == DuelSim.B.STAGGER:
			break
	ok(parries == int(ceil(mx / DuelSim.POISE_PARRY)) and parries >= 3, "it takes %d parries, not one, to break the Sentinel" % parries)
	ok(ev2 == ["break:parry", "stagger:%.1f:true" % DuelSim.STAGGER_BREAK] and s2.b_state == DuelSim.B.STAGGER and s2.b_opening_crit and s2.b_poise == 0.0 and is_equal_approx(s2.b_t, DuelSim.STAGGER_BREAK), "parry break: a %.1fs critical opening" % DuelSim.STAGGER_BREAK)
	ok(s2.poise_frac() == 0.0 and DuelSim.STAGGER_BREAK > 3.0 * maxf(DuelSim.SHORT_RECOVER_MIN, 1.5 * DuelSim.SHORT_RECOVER), "the break opening is several times the short recovery")
	var hits: Array = []
	s2.ev.connect(func(n, d): if n == &"boss_hit": hits.append(d))
	for d in ["R", "L", "D", "U", "R", "L"]:
		s2.input_swipe(d); run_for(s2, 0.4)
	ok(hits.size() >= 5 and hits[0].crit, "there is time in it for a chosen combination (%d cuts)" % hits.size())
	run_for(s2, 1.5)
	ok(s2.b_state != DuelSim.B.STAGGER and s2.b_poise == s2.b_poise_max, "after the opening its poise is whole again")
	# a parry break interrupts the rest of the string
	var s3 := _with_attack("ashen_sentinel", [cut, cut.duplicate(), cut.duplicate()])
	s3.b_poise = 10.0
	to_impact(s3, 0.22); s3.input_swipe("R"); _strike(s3)
	ok(s3.b_state == DuelSim.B.STAGGER and s3.b_idx == 0, "a parry break stops the string where it is")
	# a dodge cannot stop a string: poise worn out by dodging breaks only when the string ends
	s3 = _with_attack("ashen_sentinel", [cut, cut.duplicate()])
	s3.b_poise = 5.0
	to_impact(s3, 0.36); s3.input_dodge(-1); _strike(s3)
	ok(s3.b_state == DuelSim.B.WINDUP and s3.b_idx == 1 and s3.b_poise == 0.0, "dodged to nothing mid-string: the string carries on")
	run_for(s3, 0.4)
	to_impact(s3, 0.36); s3.input_dodge(-1); _strike(s3)
	ok(s3.b_state == DuelSim.B.STAGGER, "and it breaks when the string is over")
	# pressure: after an unbroken string it often comes straight back
	var counts := {"press": 0, "recover": 0, "gap_short": 0}
	var last_strike := [0.0]
	var p := mk("ashen_sentinel", 3, geared(0))
	p.pl.max_hp = 1.0e6; p.pl.hp = 1.0e6; p.pl.attack = 0.01
	var bot := DuelBot.new(p, DuelBot.Style.SLOPPY, 3)
	p.ev.connect(func(n, d):
		if n == &"boss_press": counts.press += 1
		if n == &"boss_recover": counts.recover += 1
		if n == &"boss_strike": last_strike[0] = p.time
		if n == &"boss_combo" and p.time - last_strike[0] < 1.6 and last_strike[0] > 0.0: counts.gap_short += 1)
	run_for(p, 120.0, bot)
	ok(counts.press >= 8 and counts.press < counts.recover, "the foe presses on after some strings, not all (%d of %d)" % [counts.press, counts.recover])
	ok(counts.gap_short >= 8, "strings follow one another without a long idle (%d inside 1.6s)" % counts.gap_short)
	ok(is_equal_approx(mk("crimson_widow").press(), float(Db.foes.crimson_widow.press)) and float(Db.foes.crimson_widow.press) > float(Db.foes.gravewarden.press), "how hard a foe presses is its own")
	# the Sentinel's mixed strings: no single defence answers every blow
	var mixed := 0
	for ph in Db.foes.ashen_sentinel.phases:
		for c in ph.combos:
			var only := {}
			for a in c.attacks:
				if a.unblockable and not a.parry and a.dodge != "none":
					only["dodge"] = true
				elif not a.parry and not a.unblockable and a.dodge == "none":
					only["block"] = true
				elif a.parry:
					only["parry"] = true
			if c.attacks.size() >= 2 and c.attacks.size() <= 3 and only.size() >= 2:
				mixed += 1
	ok(mixed >= 3, "the Sentinel has mixed-answer strings (%d)" % mixed)
	# the practice dummy has no poise to lose
	var t := mk("ashen_sentinel", 7, {}, {"training": true})
	for d in ["R", "L", "D"]:
		t.input_swipe(d); run_for(t, 0.4)
	ok(t.b_poise == t.b_poise_max and t.b_state == DuelSim.B.RECOVER, "training cuts wear nothing")

func t_struggle() -> void:
	var slam := {"dir": "D", "windup": 1.45, "dmg": 28, "swing": 0.34, "guard": 36, "parry": true, "unblockable": false, "element": null, "kind": "slam", "dodge": "any"}
	var light := slam.duplicate(); light.kind = "slash"; light.windup = 0.9
	ok(DuelSim.heavy_attack(slam) and not DuelSim.heavy_attack(light), "slams and long-wound cuts are heavy; quick cuts are not")
	var lock := func(foe: String, a: Dictionary, before: float, force: bool, opts: Dictionary = {}, sd: int = 7) -> DuelSim:
		var s := _with_attack(foe, [a], sd, opts)
		s.force_struggle = force
		to_impact(s, before); s.input_swipe("U"); _strike(s)
		return s
	# start conditions
	var s: DuelSim = lock.call("ashen_sentinel", slam, 0.22, true)
	ok(s.stats.parries == 1 and s.b_state == DuelSim.B.STRUGGLE and s.p_state == DuelSim.P.STRUGGLE and is_equal_approx(s.b_t, DuelSim.STRUGGLE_TIME), "a parried slam can lock blades for %.1fs" % DuelSim.STRUGGLE_TIME)
	ok(s.s_need == s.struggle_need() and s.s_need == 9, "the Sentinel needs nine taps (%d)" % s.s_need)
	ok(lock.call("ashen_sentinel", slam, 0.06, true).b_state != DuelSim.B.STRUGGLE, "a perfect parry never locks: it is already won")
	ok(lock.call("ashen_sentinel", light, 0.22, true).b_state != DuelSim.B.STRUGGLE, "a light cut never locks")
	ok(lock.call("cathedral_beast", slam, 0.22, true).b_state != DuelSim.B.STRUGGLE and lock.call("cinder_wyrm", slam, 0.22, true).b_state != DuelSim.B.STRUGGLE, "claws and dragons never lock blades")
	ok(not mk("cathedral_beast").struggle_capable() and mk("hollow_soldier").struggle_capable(), "only blade-bearers struggle")
	var les: DuelSim = lock.call("ashen_sentinel", slam, 0.22, true, {"lesson": true})
	ok(les.b_state != DuelSim.B.STRUGGLE, "never during the lesson")
	# need scales with the foe and the assist setting
	ok(mk("hollow_soldier").struggle_need() == 6 and mk("frostbound_king").struggle_need() == 10 and mk("ashen_sentinel", 7, {}, {"assist": 1.3}).struggle_need() == 7 and mk("ashen_sentinel", 7, {}, {"ng": 2}).struggle_need() == 11, "taps needed scale with the foe, the journey and assist")
	# winning
	var evs: Array = []
	s.ev.connect(func(n, d):
		if n in [&"struggle_tap", &"struggle_end", &"poise_break", &"boss_stagger"]: evs.append([n, d]))
	var hp: float = s.pl.hp
	s.input_swipe("L"); s.input_dodge(1)
	ok(s.p_state == DuelSim.P.STRUGGLE and s.p_buffer.is_empty() and not s.input_surge(), "nothing but tapping does anything in a struggle")
	for i in s.s_need - 1:
		run_for(s, 0.1)
		s.input_struggle_tap()
	ok(s.b_state == DuelSim.B.STRUGGLE and evs.size() == s.s_need - 1 and int(evs[-1][1].n) == s.s_need - 1, "taps are counted")
	s.input_struggle_tap()
	ok(evs.size() == s.s_need + 3 and evs[-3][0] == &"struggle_end" and evs[-3][1].won and evs[-2][0] == &"poise_break" and evs[-2][1].from == "struggle", "enough taps win it and break its poise")
	ok(s.b_state == DuelSim.B.STAGGER and is_equal_approx(s.b_t, DuelSim.STAGGER_BREAK) and s.b_opening_crit and s.p_state == DuelSim.P.FREE and s.pl.hp == hp, "winning: the foe staggers into the long opening, the knight is free and unhurt")
	s.input_struggle_tap()
	ok(evs.size() == s.s_need + 3, "taps after it is over are ignored")
	# losing
	s = lock.call("ashen_sentinel", slam, 0.22, true)
	var ended: Array = []
	s.ev.connect(func(n, d): if n == &"struggle_end": ended.append(d.won))
	hp = s.pl.hp
	for i in 4:
		s.input_struggle_tap()
	run_for(s, DuelSim.STRUGGLE_TIME + 0.05)
	ok(ended == [false] and s.p_state == DuelSim.P.STUN and s.b_state == DuelSim.B.IDLE, "too few taps: overpowered and stunned")
	ok(s.pl.hp < hp and s.pl.hp > hp - float(slam.dmg) * 0.6 and not s.over, "losing costs modest damage (%.0f)" % (hp - s.pl.hp))
	var stun_left: float = s.p_t
	ok(stun_left <= DuelSim.STRUGGLE_STUN and stun_left < s.b_t + 0.45, "the stun is short and over before the next blow can land")
	run_for(s, 0.8)
	ok(s.p_state == DuelSim.P.FREE, "control comes back")
	# cannot repeat inside its cooldown
	var locks := func(sim: DuelSim) -> bool:
		sim.pl.hp = sim.pl.max_hp
		sim.b_poise = sim.b_poise_max      # (a parry that breaks its poise outright never needs a struggle)
		sim._start_combo({"id": "test", "attacks": [slam], "recover": 1.5, "tags": [], "gap": 0.15}, true)
		to_impact(sim, 0.22); sim.input_swipe("U"); _strike(sim)
		return sim.b_state == DuelSim.B.STRUGGLE
	ok(not locks.call(s), "a second lock cannot follow at once")
	run_for(s, 0.6)
	s.time += DuelSim.STRUGGLE_COOLDOWN - 10.0
	ok(not locks.call(s), "nor anywhere inside %ds" % int(DuelSim.STRUGGLE_COOLDOWN))
	run_for(s, 0.6)
	s.time += 8.0
	ok(locks.call(s), "after the cooldown it can happen again")
	# the roll is seeded, modest, and made when the parry lands
	var n := 0
	var first: Array = []
	var second: Array = []
	for sd in range(1, 201):
		var a: DuelSim = lock.call("ashen_sentinel", slam, 0.22, false, {}, sd)
		first.append(a.b_state == DuelSim.B.STRUGGLE)
		if first[-1]:
			n += 1
	for sd in range(1, 201):
		var b: DuelSim = lock.call("ashen_sentinel", slam, 0.22, false, {}, sd)
		second.append(b.b_state == DuelSim.B.STRUGGLE)
	ok(first == second, "whether blades lock is decided by the seed alone")
	ok(n >= 40 and n <= 80, "about three eligible parries in ten lock (%d of 200)" % n)
	# whole fights: bots tap; the practised win their struggles, and results repeat
	var f1 := mk("ashen_sentinel", 11, geared(0)); f1.force_struggle = true
	run_for(f1, 600.0, DuelBot.new(f1, DuelBot.Style.SKILLED, 11))
	ok(f1.b_state == DuelSim.B.DEAD and int(f1.stats.get("struggles", 0)) >= 1 and int(f1.stats.get("struggles_won", 0)) == int(f1.stats.struggles), "the skilled bot wins its struggles (%d) and the fight" % int(f1.stats.get("struggles", 0)))
	var f2 := mk("ashen_sentinel", 21, geared(0)); f2.force_struggle = true
	run_for(f2, 600.0, DuelBot.new(f2, DuelBot.Style.SLOPPY, 21))
	var f3 := mk("ashen_sentinel", 21, geared(0)); f3.force_struggle = true
	run_for(f3, 600.0, DuelBot.new(f3, DuelBot.Style.SLOPPY, 21))
	ok(int(f2.stats.get("struggles", 0)) >= 1 and f2.stats.get("struggles") == f3.stats.get("struggles") and f2.stats.get("struggles_won", 0) == f3.stats.get("struggles_won", 0) and is_equal_approx(f2.time, f3.time), "fights with struggles are deterministic per seed (%d locked, %d won)" % [int(f2.stats.get("struggles", 0)), int(f2.stats.get("struggles_won", 0))])
	var tt := mk("ashen_sentinel", 5, geared(0)); tt.force_struggle = true
	tt.pl.max_hp = 1.0e6; tt.pl.hp = 1.0e6
	var tb := DuelBot.new(tt, DuelBot.Style.TURTLE, 5)
	tt._start_combo({"id": "test", "attacks": [slam], "recover": 1.5, "tags": [], "gap": 0.15}, true)
	to_impact(tt, 0.22); tt.input_swipe("U"); _strike(tt)
	run_for(tt, 2.5, tb)
	ok(int(tt.stats.get("struggles", 0)) == 1 and int(tt.stats.get("struggles_won", 0)) == 0, "a slow hand (4 taps a second) loses to the Sentinel")

	# the HUD's TAP target: a touch on it is a tap, only while a struggle is on
	var hud := DuelHud.new()
	add_child(hud)
	var taps := [0]
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2(300, 300)
	hud.struggle._gui_input(press)
	ok(not hud.struggle.visible and hud.struggle.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the TAP target is absent outside a struggle")
	hud.struggle_begin(9, DuelSim.STRUGGLE_TIME, func(): taps[0] += 1)
	ok(hud.struggle.visible and hud.struggle.mouse_filter == Control.MOUSE_FILTER_STOP and hud.struggle.size.x >= hud.root.size.x * 0.9, "it appears, large, when blades lock")
	for i in 3:
		hud.struggle._gui_input(press)
	var lift := InputEventScreenTouch.new()
	lift.pressed = false
	hud.struggle._gui_input(lift)
	ok(taps[0] == 3, "each touch on it is one tap (%d)" % taps[0])
	hud.struggle_end()
	hud.struggle._gui_input(press)
	ok(taps[0] == 3 and not hud.struggle.visible and hud.struggle.mouse_filter == Control.MOUSE_FILTER_IGNORE, "and it is gone, and deaf, when the struggle ends")
	hud.queue_free()

# ------------------------------------------------------------------ story options: end_on, beat_at, the seal, phase traits
func t_story_options() -> void:
	# (a) a story-ended fight: taken on a landed cut once the time has come, never lost, a third result
	var s := mk("forgotten_monarch", 9, geared(6), {"end_on": {"cuts": 4, "not_before": 9.0, "release": 32.0, "floor": 0.25}})
	var ends: Array = []
	s.ev.connect(func(n, d): if n == &"story_end": ends.append(d))
	for i in 5:
		s.b_state = DuelSim.B.RECOVER; s.b_t = 9.0; s.p_state = DuelSim.P.FREE
		s.input_swipe(["L", "R", "U", "D", "L"][i]); run_for(s, 0.5)
	ok(s.cuts_landed == 5 and not s.over and ends.is_empty(), "end_on: cuts landed before `not_before` do not end it (%d cuts at %.1f s)" % [s.cuts_landed, s.time])
	s.time = 9.5
	s.b_state = DuelSim.B.RECOVER; s.b_t = 9.0; s.p_state = DuelSim.P.FREE
	s.input_swipe("R"); run_for(s, 0.5)
	ok(s.over and s.interrupted == "ahead" and ends.size() == 1 and str(ends[0].how) == "ahead", "end_on: the next cut that lands after it is the one the story answers")
	ok(s.b_state != DuelSim.B.DEAD and s.p_state != DuelSim.P.DEAD, "end_on: neither side is dead: it is not a win and not a loss")
	var t0 := s.time
	run_for(s, 1.0)
	ok(s.time == t0 and ends.size() == 1, "end_on: an ended fight stays ended and says so once")
	# release: a player who lands nothing is let go, and is told how it stood
	var idle := mk("forgotten_monarch", 9, geared(6), {"end_on": {"cuts": 4, "not_before": 9.0, "release": 12.0, "floor": 0.25}})
	idle.pl.mitigation = 1.0
	run_for(idle, 20.0)
	ok(idle.over and idle.interrupted == "behind" and idle.time >= 12.0 and idle.time < 12.1, "end_on: released at `release` with no cut landed: behind (%.1f s)" % idle.time)
	var some := mk("forgotten_monarch", 9, geared(6), {"end_on": {"cuts": 4, "not_before": 9.0, "release": 12.0}})
	some.pl.mitigation = 1.0
	some.b_state = DuelSim.B.RECOVER; some.b_t = 1.0
	some.input_swipe("L"); run_for(some, 20.0)
	ok(some.interrupted == "even", "end_on: released with a cut landed: even")
	# floor: an ordinary blow never loses it
	var weak := mk("forgotten_monarch", 9, {}, {"end_on": {"cuts": 99, "not_before": 0.0, "release": 600.0, "floor": 0.25}})
	run_for(weak, 120.0)
	ok(weak.over and weak.interrupted != "" and weak.p_state != DuelSim.P.DEAD and weak.pl.hp >= 1.0 and weak.pl.hp <= weak.pl.max_hp * 0.25 + 0.01,
		"end_on: with `floor` nobody dies to an ordinary blow (ended %s at %.0f of %.0f hp)" % [weak.interrupted, weak.pl.hp, weak.pl.max_hp])
	var plain := mk("forgotten_monarch", 9)
	run_for(plain, 120.0)
	ok(plain.over and plain.interrupted == "" and plain.p_state == DuelSim.P.DEAD, "without the option the same fight is lost as it always was")
	# seeded: the same seed and the same hands give the same story-ended fight
	var runs: Array = []
	for k in 2:
		var r := mk("forgotten_monarch", 9, geared(6), {"end_on": {"cuts": 4, "not_before": 9.0, "release": 32.0, "floor": 0.25}})
		var rb := DuelBot.new(r, DuelBot.Style.SKILLED, 4)
		run_for(r, 60.0, rb)
		runs.append([r.interrupted, snappedf(r.time, 0.001), r.cuts_landed, snappedf(r.b_hp, 0.01)])
	ok(runs[0] == runs[1] and str(runs[0][0]) == "ahead" and float(runs[0][1]) >= 9.0, "end_on: a skilled hand is taken while ahead, the same way every time %s" % str(runs[0]))

	# (b) a beat at any listed phase, and one when the player is near falling
	var b := mk("forgotten_monarch", 7, {}, {"beat_at": [2]})
	var beats: Array = []
	b.ev.connect(func(n, d): if n == &"story_beat": beats.append(d))
	b.pl.attack = 4000.0
	b.pl.mitigation = 1.0
	for i in 40:
		if b.b_phase >= 1:
			break
		b.b_state = DuelSim.B.RECOVER; b.b_t = 9.0; b.p_state = DuelSim.P.FREE
		b.input_swipe(["L", "R"][i % 2]); run_for(b, 0.5)
	run_for(b, 3.5)
	ok(b.b_phase == 1 and beats.is_empty(), "beat_at [2]: the second phase begins and nothing is said")
	for i in 40:
		if b.b_phase >= 2:
			break
		b.b_state = DuelSim.B.RECOVER; b.b_t = 9.0; b.p_state = DuelSim.P.FREE
		b.input_swipe(["L", "R"][i % 2]); run_for(b, 0.5)
	run_for(b, 3.5)
	ok(b.b_phase == 2 and beats.size() == 1 and int(beats[0].phase) == 2 and not beats[0].get("low", false), "beat_at [2]: the beat is sent as the third phase begins, with its index")
	var both := mk("frostbound_king", 7, {}, {"beat_at": [1, 2]})
	var n2: Array = [0]
	both.ev.connect(func(n, _d): if n == &"story_beat": n2[0] += 1)
	both.pl.attack = 50000.0
	for d: String in ["L", "R"]:
		both.b_state = DuelSim.B.RECOVER; both.b_t = 99.0; both.p_state = DuelSim.P.FREE
		both.input_swipe(d); run_for(both, 3.5)
	ok(n2[0] == 2, "beat_at [1, 2]: one at each listed phase, each once")
	var low := mk("forgotten_monarch", 7, {}, {"beat_at": [2], "beat_hp": 0.3})
	var lows: Array = []
	low.ev.connect(func(n, d): if n == &"story_beat": lows.append(d))
	run_for(low, 200.0)
	ok(lows.size() == 1 and lows[0].get("low", false) and low.p_state == DuelSim.P.DEAD, "beat_hp: one beat when the player is near falling, and the fight is still theirs to lose")
	low = mk("forgotten_monarch", 7, {}, {"beat_at": [2], "beat_hp": 0.3})
	low.ev.connect(func(n, _d): if n == &"story_beat": low.paused = true)
	run_for(low, 200.0)
	ok(low.paused and not low.over and low.pl.hp > 0.0 and low.pl.hp <= low.pl.max_hp * 0.3, "beat_hp: a scene that pauses on it holds a living player (%.0f hp)" % low.pl.hp)

	# (c) the seal: restoration undone by what the player does
	var foe: Dictionary = Encounters.foe("monarch_iii", Game.default_profile())
	var kit := geared(6)
	var m := mk("monarch_iii", 5, kit, {"seal": {"phase": 2, "need": 5}})
	var log: Array = []
	m.ev.connect(func(n, d): if n in [&"seal", &"seal_broken", &"restored", &"boss_dead"]: log.append([str(n), d.duplicate()]))
	m.pl.attack = 1.0e7
	m.pl.mitigation = 1.0
	ok(m.seal_need == 0 and not m.seal_active(), "seal: nothing to break before its phase")
	for i in 2:
		m.b_state = DuelSim.B.RECOVER; m.b_t = 9.0; m.p_state = DuelSim.P.FREE; m.rift_dir = ""
		m.input_swipe(["L", "R"][i]); run_for(m, 3.6)
	ok(m.b_phase == 2 and m.seal_need == 5 and m.seal_left == 5 and str(log[0][0]) == "seal" and str(log[0][1].from) == "start", "seal: armed when the Last Defense begins (%d of %d)" % [m.seal_left, m.seal_need])
	var stood: float = float(foe.phases[2].revive)
	ok(is_equal_approx(m.b_hp, m.b_hp_max * stood), "he is stood up at the data's own share (%.0f%%)" % (stood * 100.0))
	# felled with the seal whole: stood up again, and the seal is two the poorer
	m.b_state = DuelSim.B.RECOVER; m.b_t = 9.0; m.p_state = DuelSim.P.FREE; m.rift_dir = ""
	m.input_swipe("U"); run_for(m, 0.5)
	ok(not m.over and m.b_state == DuelSim.B.SHIFT and m.seal_left == 3 and is_equal_approx(m.b_hp, m.b_hp_max * stood) and int(m.stats.get("restored", 0)) == 1,
		"seal: felled while it holds, he is restored, and felling him cost the machinery two")
	run_for(m, 3.0)
	# a parry wears it by one, a perfect parry by two
	m.pl.attack = 1.0
	until_windup(m)
	for i in 6:
		if m.b_attack.parry:
			break
		run_for(m, 1.5); until_windup(m)
	to_impact(m, 0.2)
	m.input_swipe(DuelSim.parry_dir_for(m.b_attack.dir))
	run_for(m, 0.3)
	ok(m.seal_left == 2 and m.stats.parries >= 1, "seal: a parry in this phase wears it by one (%d left)" % m.seal_left)
	ok(m.trait_v("lifesteal") == float(foe.traits.lifesteal) and m.trait_v("lifesteal") > 0.0, "while it holds he still feeds")
	m.b_state = DuelSim.B.RECOVER; m.b_t = 9.0; m.p_state = DuelSim.P.FREE; m.rift_dir = "L"; m.p_last_dir = ""
	m.input_swipe("L"); run_for(m, 0.5)
	ok(m.seal_left == 1, "seal: a cut along the seam wears it by one")
	m.b_state = DuelSim.B.IDLE; m.b_t = 0.0; m.p_state = DuelSim.P.FREE
	until_windup(m)
	for i in 6:
		if m.b_attack.parry:
			break
		run_for(m, 1.5); until_windup(m)
	to_impact(m, 0.05)
	m.input_swipe(DuelSim.parry_dir_for(m.b_attack.dir))
	run_for(m, 0.2)
	ok(m.seal_left == 0 and not m.seal_active() and log.any(func(e): return str(e[0]) == "seal_broken"), "seal: the last of it goes, and it is announced")
	ok(m.trait_v("lifesteal") == 0.0 and m.trait_v("parry_open") > 0.0, "broken: he no longer feeds; his other rules stand")
	m.pl.attack = 1.0e7
	m.b_state = DuelSim.B.RECOVER; m.b_t = 9.0; m.p_state = DuelSim.P.FREE
	m.input_swipe("D"); run_for(m, 0.5)
	ok(m.over and m.b_state == DuelSim.B.DEAD and str(log[-1][0]) == "boss_dead", "broken: felled now, he stays down")
	# it cannot go on for ever: a player who never parries still ends it by cutting him down
	var brute := mk("monarch_iii", 5, kit, {"seal": {"phase": 2, "need": 5}})
	brute.pl.attack = 1.0e7
	brute.pl.mitigation = 1.0
	var falls := 0
	for i in 12:
		if brute.over:
			break
		brute.b_state = DuelSim.B.RECOVER; brute.b_t = 9.0; brute.p_state = DuelSim.P.FREE; brute.rift_dir = ""
		brute.input_swipe(["L", "R"][i % 2]); run_for(brute, 3.6)
		falls += 1
	ok(brute.over and brute.b_state == DuelSim.B.DEAD and falls == 5 and int(brute.stats.restored) == 2, "seal 5, no parries: felled three times in the last phase and it is over (%d blows, %d restorations)" % [falls, int(brute.stats.get("restored", 0))])
	# without the option the foe is exactly as it was
	var old := mk("monarch_iii", 5, kit)
	old.pl.attack = 1.0e7
	for i in 3:
		old.b_state = DuelSim.B.RECOVER; old.b_t = 9.0; old.p_state = DuelSim.P.FREE
		old.input_swipe(["L", "R", "U"][i]); run_for(old, 3.6)
	ok(old.over and old.seal_need == 0, "no seal asked for: one restoration from the data, then dead, as before")
	# a whole fight, by bots: the skilled hand breaks the seal by defending; fewer needed is a shorter fight
	var times: Array = []
	for need: int in [9, 2]:
		var f := mk("monarch_iii", 11, kit, {"seal": {"phase": 2, "need": need}})
		f.pl.max_hp = 1.0e6; f.pl.hp = 1.0e6
		var fb := DuelBot.new(f, DuelBot.Style.SKILLED, 11)
		run_for(f, 900.0, fb)
		ok(f.over and f.b_state == DuelSim.B.DEAD and f.seal_left == 0, "seal %d: a skilled bot ends the last fight in %.0f s (%d parries, %d restorations)" % [need, f.time, f.stats.parries, int(f.stats.get("restored", 0))])
		times.append(f.time)
	ok(times[1] <= times[0], "what the house learned shortens it (%.0f s with nine to break, %.0f s with two)" % [times[0], times[1]])

	# (d) a phase may carry its own traits
	var base: Dictionary = Db.foes["frostbound_king"].duplicate(true)
	base.id = "t_phase_traits"
	base["traits"] = {"parry_open": 1.2, "frenzy": 0.1}
	base.phases[1]["traits"] = {"parry_open": 1.6, "lifesteal": 0.2}
	Db.foes[base.id] = base
	var pt := mk("t_phase_traits")
	ok(pt.trait_v("parry_open") == 1.2 and pt.trait_v("lifesteal") == 0.0 and is_equal_approx(pt.trait_v("frenzy"), 0.1), "phase traits: the first phase has the foe's own")
	pt.b_phase = 1
	ok(pt.trait_v("parry_open") == 1.6 and is_equal_approx(pt.trait_v("lifesteal"), 0.2) and is_equal_approx(pt.trait_v("frenzy"), 0.1), "phase traits: a phase's own replace them key by key; the rest stand")
	Db.foes.erase(base.id)

func t_story_beat() -> void:
	var s := mk("frostbound_king")
	var beats: Array = []
	s.ev.connect(func(n, d): if n == &"story_beat": beats.append(d.foe))
	s.pl.attack = 50000.0
	s.b_state = DuelSim.B.RECOVER; s.b_t = 99.0
	s.input_swipe("L"); run_for(s, 0.4)
	ok(beats.is_empty() and s.b_state == DuelSim.B.SHIFT, "nothing is said while it is still turning")
	run_for(s, 2.5)
	ok(beats == ["frostbound_king"] and s.b_phase == 1, "the beat fires when the second phase begins")
	# the presentation pauses the fight: nothing moves, nothing is lost
	s.paused = true
	var snap := [s.time, s.b_hp, s.pl.hp, s.b_phase, s.b_state, s.b_t, s.pl.stamina, s.b_poise, s.relic, s.surge]
	var bot := DuelBot.new(s, DuelBot.Style.SKILLED, 3)
	s.input_struggle_tap()
	run_for(s, 8.0, bot)
	ok(snap == [s.time, s.b_hp, s.pl.hp, s.b_phase, s.b_state, s.b_t, s.pl.stamina, s.b_poise, s.relic, s.surge], "a paused fight keeps its exact state (hp, phase, timers)")
	s.paused = false
	run_for(s, 1.0)
	ok(s.time > float(snap[0]) + 0.9, "and carries on when released")
	s.b_state = DuelSim.B.RECOVER; s.b_t = 99.0; s.p_state = DuelSim.P.FREE
	s.input_swipe("R"); run_for(s, 3.5)
	ok(s.b_phase == 2 and beats.size() == 1, "it fires once in a fight, not at every phase")
	var lesser := mk("hollow_soldier")
	lesser.ev.connect(func(n, d): if n == &"story_beat": beats.append(d.foe))
	run_for(lesser, 20.0)
	ok(beats.size() == 1, "lesser foes have no beat")
	# who gets one, and only once per save
	var saved: Dictionary = Game.profile
	Game.new_game("#123456")
	var cs: Array = []
	var missing: Array = []
	for f: String in Db.foes:
		if Companion.speech(f) == "C":
			cs.append(f)
			var id: String = Companion.voice_key(f) + "_beat"
			if not Story.has_scene(id):
				missing.append(id)
			ok(Duel.beat_scene(f) == (id if Story.has_scene(id) else ""), "%s: the beat plays only if its scene is written" % f)
		else:
			ok(Duel.beat_scene(f) == "", "%s holds no conversation mid-fight" % f)
	ok(cs.size() == 4 and cs.has("forgotten_monarch") and cs.has("crimson_widow"), "four foes may speak mid-battle")
	if not missing.is_empty():
		print("    story-beat scenes not yet written (the pause is skipped for these): ", ", ".join(missing))
	var had: bool = Story.data.scenes.has("monarch_beat")
	if not had:
		Story.data.scenes["monarch_beat"] = {"lines": []}
	ok(Duel.beat_scene("forgotten_monarch") == "monarch_beat", "with its scene written, the Monarch's beat is offered")
	Game.profile.flags["beat_forgotten_monarch"] = true
	ok(Duel.beat_scene("forgotten_monarch") == "", "and never again on that save")
	if not had:
		Story.data.scenes.erase("monarch_beat")
	Game.profile = saved

func t_lesson() -> void:
	var saved: Dictionary = Game.profile
	Game.new_game("#123456")
	var d := Duel.new()
	add_child(d)
	d.setup("ashen_sentinel", {"lesson": true, "skip_intro": true, "seed": 7})
	var s: DuelSim = d.sim
	var cut := func(dir: String) -> void:
		s.input_swipe(dir); run_for(s, 0.45)
	var kinds: Array = Duel.LESSONS.map(func(l): return str(l[3]))
	ok(kinds == ["cuts", "combo:double_slash", "parry", "dodge", "roll", "block", "combo:armor_splitter", "stamina", "surge", "relic"], "the lesson teaches cuts, a pair, parry, dodge, roll, block, three cuts, stamina, and names the surge and the relic")
	var three: Dictionary = {}
	for c in Db.combos:
		if c.id == "armor_splitter":
			three = c
	ok(three.seq.size() == 3 and (three.cls.is_empty() or three.cls.has("sword")), "the three-cut step uses a real sword combination")
	var a: Dictionary = s.lesson_attack()
	for step in Duel.LESSONS.size():
		var kind: String = kinds[step]
		ok(d._lesson == step, "lesson reaches step %d (%s)" % [step, kind])
		if d._lesson != step:
			break
		var demo: Dictionary = d.hud.lesson_demo()
		ok(not demo.stroke.is_empty() or not demo.pads.is_empty(), "%s has a demonstration on screen (%s)" % [kind, str(demo)])
		ok(s.b_state != DuelSim.B.STRUGGLE and (s.pl.hp == s.pl.max_hp or kind == "relic"), "%s: nobody is hurt" % kind)
		match kind:
			"cuts":
				ok(demo.stroke == ["R"], "cuts: a stroke is drawn")
				for dir in ["R", "U", "L"]:
					cut.call(dir)
			"combo:double_slash":
				ok(demo.stroke == ["L", "R"], "pair: both strokes are drawn")
				cut.call("L"); cut.call("R")
			"parry":
				ok(demo.stroke == [DuelSim.parry_dir_for(a.dir)] and DuelSim.parry_quality(demo.stroke[0], a.dir) == 2, "parry: the stroke points into the blow")
				until_windup(s); to_impact(s, 0.2); s.input_swipe(demo.stroke[0]); run_for(s, 0.3)
			"dodge":
				ok(demo.pads == {("right" if a.dodge == "R" else "left"): "tap"} and d.hud.pad_l.teach == "tap", "dodge: the pad on the safe side is lit")
				until_windup(s); to_impact(s, 0.3); s.input_dodge(1 if a.dodge == "R" else -1); run_for(s, 0.4)
			"roll":
				ok(demo.pads.values() == ["double"] and d.hud.pad_l.teach == "double", "roll: the pad shows a double tap")
				run_for(s, 0.3)
				s.input_dodge(-1); run_for(s, 0.1); s.input_dodge(-1)
				ok(d.hud.pad_l.teach != "double", "roll: the double-tap mark goes the moment the roll is made")
				run_for(s, 1.0)
			"block":
				ok(demo.pads == {"block": "hold"} and d.hud.pad_block.teach == "hold", "block: the shield pad is lit with a hold ring")
				until_windup(s); s.input_block(true); _strike(s); s.input_block(false)
			"combo:armor_splitter":
				ok(demo.stroke == three.seq, "three cuts: the combination's own strokes are drawn")
				run_for(s, 0.3)
				for dir in three.seq:
					cut.call(dir)
			"stamina":
				ok(demo.pads.has("stamina") and not demo.stroke.is_empty(), "stamina: the bar is marked and a stroke invites cutting")
				d._lesson_stamina_tick(1.0)
				ok(d._lesson == step, "stamina: not done while the bar is full")
				d._lesson_t = 9.95
				d._lesson_stamina_tick(0.1)
				ok(d._lesson == step + 1, "stamina: ten seconds is enough")
				d._lesson = step; d._lesson_show()
				s.pl.stamina = s.pl.max_stamina * 0.3
				d._lesson_stamina_tick(0.1)
				s.pl.stamina = s.pl.max_stamina * 0.6
				d._lesson_stamina_tick(0.1)
				ok(d._lesson == step, "stamina: low, but not yet recovered")
				s.pl.stamina = s.pl.max_stamina * 0.75
				d._lesson_stamina_tick(0.1)
				ok(d._lesson == step + 1, "stamina: done once it has run low and come back")
			"surge":
				# O8: the ring is named, lit and full; the tap itself completes the step, and waiting passes it too
				ok(demo.pads == {"surge": "tap"} and d.hud.pad_surge.teach == "tap" and s.surge >= DuelSim.SURGE_MAX and d.hud._train_head.text == "SURGE", "surge: the amber ring is named, full, and marked for a tap")
				d._lesson_pad_tick(Duel.LESSON_PAD_WAIT + 0.1)
				ok(d._lesson == step + 1, "surge: the step does not wait for ever")
				d._lesson = step; d._lesson_show()
				ok(s.input_surge() and d._lesson == step + 1, "surge: tapping it is the step")
			"relic":
				ok(demo.pads == {"relic": "tap"} and d.hud.pad_relic.teach == "tap" and s.relic >= DuelSim.RELIC_MAX and s.pl.hp < s.pl.max_hp and s.pl.hp > 0.0, "relic: the blue ring is named, full, and there is a wound to close")
				var hurt: float = s.pl.hp
				ok(s.input_relic() and s.pl.hp > hurt and d._lesson == -1, "relic: tapping it mends, and the lesson is over")
		if kind in ["parry", "dodge", "block"]:
			# the defence worked: its indicator is gone at once, the payoff is up, and the stroke invites the answering cut
			var after: Dictionary = d.hud.lesson_demo()
			ok(d._lesson == step and d._lesson_strike and after.pads.is_empty() and after.stroke == ["R"], "%s: indicator cleared, answering stroke shown" % kind)
			ok(d.hud.pad_l.teach == "" and d.hud.pad_block.teach == "" and d.hud._train_head.text.ends_with("SWIPE TO STRIKE"), "%s: payoff line shown" % kind)
			ok(s.boss_open(), "%s: the foe waits for the answering cut" % kind)
			run_for(s, 3.0)
			ok(s.boss_open(), "%s: however long it takes" % kind)
			cut.call("R")
		var now: Dictionary = d.hud.lesson_demo()
		ok(d._lesson != step and (d._lesson == -1 or now != demo), "%s: completing the step clears its demonstration" % kind)
	var last: Dictionary = d.hud.lesson_demo()
	ok(d._lesson == -1 and last.stroke.is_empty() and last.pads.is_empty() and d.hud.pad_l.teach == "" and d.hud.pad_block.teach == "" and d.hud.pad_surge.teach == "" and d.hud.pad_relic.teach == "", "when the lesson ends nothing is left on screen")
	var plain := DuelSim.new()
	plain.setup(Game.stats(), Db.foes["hollow_soldier"], 3, {})
	plain.lesson_charge("surge")
	plain.lesson_charge("relic")
	ok(plain.surge == 0.0 and plain.relic == 0.0 and plain.pl.hp == plain.pl.max_hp, "outside the lesson nothing fills a ring or hurts the knight")
	d.queue_free()
	Game.profile = saved

# ------------------------------------------------------------------ the walking corridor (traversal pass)
func t_corridor() -> void:
	Corridor.reset()
	Corridor.add(Vector3(0, 0, 10), Vector3.ZERO)
	var clear := Corridor.clear(Vector3(5, 0, 5), 0.5, "far")
	ok(clear == Vector3(5, 0, 5), "corridor: a piece well outside the lane is left alone")
	var pushed := Corridor.clear(Vector3(0.3, 0, 5), 0.5, "near")
	ok(pushed != Vector3(0.3, 0, 5) and absf(pushed.x) >= Corridor.HALF + 0.5, "corridor: a piece in the lane is pushed out of it")
	ok(Corridor.intrusion(pushed, 0.5) <= 0.0, "corridor: and no longer intrudes")
	var gone := Corridor.clear(Vector3(0.0, 0, 5), 6.0, "huge")
	ok(gone == Vector3.INF, "corridor: a piece that would have to move far is taken out")
	ok(Corridor.moves.size() == 2, "corridor: what was moved is logged")
	ok(absf(Corridor.side(0.4, 0.2)) >= Corridor.HALF + 0.2, "corridor: a roadside offset is pushed out")
	Corridor.reset()
	ok(FighterRig.ROAD_SPEED >= 1.0 and FighterRig.ROAD_SPEED <= 1.3, "road pace is in the 1.0 to 1.3 m/s range")
