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
	s.setup(Stats.compute(p, Db.items, Db.classes), Db.foes[foe], seed_value, opts)
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
	for t in ["t_data", "t_parry", "t_dodge", "t_block", "t_attack", "t_punish", "t_phases", "t_adaptive", "t_elements", "t_seams", "t_drain", "t_revive", "t_bots", "t_progression", "t_save", "t_runs"]:
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
