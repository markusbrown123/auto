extends Node
## The three generations:  godot --headless --path . res://tests/generations.tscn
## Save version 3 and its migration, the two canonical falls, what is inherited, the echo of the second generation,
## the encounter director, the three meetings with the Monarch, the endings and the legacy journey.
## The campaign test plays the real rules with the real sim (the economy simulation's own player, tools/econ_sim.gd).
var passed := 0
var failed := 0

## Everything that is the family's: none of it may change at a transition.
const FAMILY := ["inventory", "upgrades", "mods", "edge", "mastery", "mastered", "mastery_taught", "gold", "shards", "materials", "combos", "combo_uses",
	"lore", "secrets", "secret_lore", "feats", "completion", "quests_done", "challenges_done", "level", "xp", "attrs", "attr_points", "discovered",
	"seen", "favourites", "cosmetics", "heraldry", "family", "endings", "deaths", "defeated", "rewards", "sold", "heard", "tutorial_done", "ng"]

func ok(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", what)

func _ready() -> void:
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_generations_test"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	wipe()
	for t: String in ["t_data", "t_migration", "t_new_journey", "t_falls_and_defeats", "t_bodies", "t_director", "t_monarch", "t_echo", "t_endings",
			"t_companion", "t_campaign"]:
		print("• ", t)
		call(t)
	wipe()
	print("\n%d passed, %d failed" % [passed, failed])
	print("generations: %s" % ("PASS" if failed == 0 else "%d FAILED" % failed))
	get_tree().quit(1 if failed > 0 else 0)

func wipe() -> void:
	for n: int in [1, 2, 3]:
		for ext: String in ["json", "bak", "tmp"]:
			if FileAccess.file_exists(Game.slot_file(n, ext)):
				DirAccess.remove_absolute(Game.slot_file(n, ext))
	Game.slot = 1

func fresh(start: int = 2, body: String = "m", weapon: String = "w_rusted_sword") -> void:
	wipe()
	Game.new_game("#123456", body, weapon, start)
	Game.profile.rewards.seed = 4242
	Game.rng.seed = 4242

func fixture(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/%s.json" % name))

## The profile as text, without the two things that move by themselves.
func snap(p: Dictionary = Game.profile) -> String:
	var c: Dictionary = p.duplicate(true)
	c.erase("last_played")
	c.erase("playtime")
	return JSON.stringify(c)

func family(p: Dictionary = Game.profile) -> String:
	var c := {}
	for k: String in FAMILY:
		c[k] = p.get(k)
	return JSON.stringify(c)

func canon(p: Dictionary = Game.profile) -> String:
	return JSON.stringify([p.generations, p.world, p.campaign])

## Saved and read back, the profile is the one that was saved.
func round_trips(what: String) -> void:
	Game.save()
	var before := snap()
	ok(Game.load_game(), what + ": loads")
	ok(snap() == before, what + ": saved and read back, it is the same save")
	if snap() != before:
		diff(JSON.parse_string(before), JSON.parse_string(snap()), "", before, snap())

## Where two things that should be the same are not (to the first few places).
var _diffs := 0
func diff(a: Variant, b: Variant, path: String, ta: String = "", tb: String = "") -> void:
	if a is Dictionary and b is Dictionary:
		for k in a:
			diff(a[k], b.get(k), path + "/" + str(k))
		for k in b:
			if not a.has(k):
				diff(null, b[k], path + "/" + str(k))
	elif a is Array and b is Array and a.size() == b.size():
		for i: int in a.size():
			diff(a[i], b[i], path + "/" + str(i))
	elif JSON.stringify(a) != JSON.stringify(b) and _diffs < 12:
		_diffs += 1
		print("    differs at %s: %s | %s" % [path, JSON.stringify(a).left(80), JSON.stringify(b).left(80)])
	if path == "" and ta != "" and _diffs < 12:
		for i: int in mini(ta.length(), tb.length()):
			if ta[i] != tb[i]:
				print("    text differs: …%s | …%s" % [ta.substr(maxi(0, i - 40), 70), tb.substr(maxi(0, i - 40), 70)])
				break

func fight(st: Dictionary, foe: String, style: int, sd: int, limit: float = 300.0) -> DuelSim:
	var s := DuelSim.new()
	s.setup(st, Db.foes[foe], sd, {"combos": Db.combos})
	var bot := DuelBot.new(s, style, sd)
	while s.time < limit and not s.over:
		bot.tick(1.0 / 60.0)
		s.tick(1.0 / 60.0)
	return s

func won(s: DuelSim) -> bool:
	return s.b_state == DuelSim.B.DEAD

## Slowest-to-read blow of a foe, in seconds, at the pace it is thrown.
func tightest(f: Dictionary) -> float:
	var out := 100.0
	for ph: Dictionary in f.phases:
		for c: Dictionary in ph.combos:
			for i: int in c.attacks.size():
				out = minf(out, (float(c.attacks[i].windup) + (float(c.gap) if i > 0 else 0.0)) / float(ph.speed))
	return out

# ------------------------------------------------------------------ data
func t_data() -> void:
	var d: Dictionary = Generations.data()
	ok(d.generations.size() == 3 and d.generations[0].year == 0 and d.generations[1].year == 22 and d.generations[2].year == 46, "three generations at +0, +22 and +46 years")
	ok(d.generations.map(func(g): return g.role) == ["first", "second", "heir"], "the roles are first, second, heir")
	ok(Game.SAVE_VERSION == 3, "the save is version 3")
	ok(Db.foes.size() >= 52, "the roster is whole")
	var roster := 0
	for id: String in Db.foes:
		roster += 0 if Db.foes[id].get("variant", false) else 1
	ok(roster == 52, "the 52 foes of the roster are untouched; another generation's cast is apart from them")
	for id: String in Encounters.all_cast():
		var f := Encounters.foe(id, Game.default_profile())
		ok(not f.is_empty() and Db.foes.has(id) and f.get("variant", false), "%s is built and can be fought" % id)
		ok(tightest(f) >= 0.45, "%s: every blow can be read (%.2fs)" % [id, tightest(f)])
		ok(id == "the_kept" or Db.foes.has(str(f.base)), "%s stands on an existing foe" % id)
	var traits := ["frenzy", "block_tax", "marks", "mark_mult", "parry_open", "dodge_open", "lifesteal"]
	for id: String in Encounters.all_cast():
		for k: String in Db.foes[id].get("traits", {}):
			ok(traits.has(k), "%s: trait `%s` is one the duel knows" % [id, k])
	for r: Dictionary in d.records:
		ok(r.has("need") and str(r.name) != "", "record %s is complete" % r.id)
	for m: String in d.mortals:
		ok(Db.foes.has(m), "mortal %s is on the roster" % m)

# ------------------------------------------------------------------ migration
func t_migration() -> void:
	for name: String in ["save_v0", "save_v1_early", "save_v1", "save_v2"]:
		var old := fixture(name)
		var m := Game._migrate(fixture(name))
		var finished: bool = not old.get("endings", []).is_empty() or int(old.get("ng", 0)) > 0
		ok(int(m.version) == 3, "%s: version 3" % name)
		ok(m.campaign.generation == (3 if finished else 2), "%s: lands in generation %d" % [name, 3 if finished else 2])
		ok(m.generations.size() == m.campaign.generation and m.generations[0].fate == "fallen" and m.generations[0].authored, "%s: the first is recorded as fallen" % name)
		ok(m.flags.has("gen1_complete") and m.campaign.monarch.has("1"), "%s: the first generation's opening is marked seen" % name)
		ok(m.generations[-1].fate == "alive" and m.campaign.transition.is_empty(), "%s: the one on the road is alive, and no transition is pending" % name)
		ok(typeof(m.campaign.generation) == TYPE_INT and typeof(m.generations[0].year) == TYPE_INT, "%s: whole numbers are integers" % name)
		# nothing earned is lost
		ok(m.gold == int(old.gold) and m.level == int(old.level) and m.shards == int(old.get("shards", 0)), "%s: gold, level and shards are kept" % name)
		var held: Array = old.inventory if old.has("inventory") else old.items.keys().filter(func(id): return old.items[id].get("owned", false))
		var all := true
		for id in held:
			all = all and m.inventory.has(Db.canon(str(id)))
		ok(all and m.inventory.size() >= held.size(), "%s: every item is kept" % name)
		ok(m.cleared == old.cleared and m.lore.size() == old.get("lore", []).size() and m.combos.size() >= old.get("combos", []).size(), "%s: roads, records and combinations are kept" % name)
		for foe: String in old.defeated:
			all = all and m.defeated.has(foe)
		ok(all, "%s: every victory is kept" % name)
		for region: String in old.cleared:
			ok(m.world.cleared.has(region) and m.generations[-1].deeds.regions.has(region), "%s: clearing %s is a deed of the one who did it" % [name, region])
		ok(not old.defeated.has("ashen_sentinel") or m.world.facts.has("slain:ashen_sentinel"), "%s: a guardian that fell is a fact of the world" % name)
		ok(not old.get("flags", {}).has("courtyard_gate") or m.world.facts.has("route_opened:courtyard"), "%s: a gate that was opened is a fact of the world" % name)
		# idempotent, and stable through the file
		var again := Game._migrate(m.duplicate(true))
		ok(snap(again) == snap(m), "%s: migrating twice changes nothing" % name)
		var packed: Dictionary = JSON.parse_string(JSON.stringify(Game._pack(m)))
		ok(snap(Game._migrate(packed)) == snap(m), "%s: written and read back, it is the same" % name)
		wipe()
		var f := FileAccess.open(Game.slot_file(1), FileAccess.WRITE)
		f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/%s.json" % name))
		f.close()
		ok(Game.load_game() and Game.generation() == (3 if finished else 2), "%s: loads from the file" % name)
		round_trips(name)
		ok(Game.lineage().people.size() == Game.generation(), "%s: the lineage lists everyone" % name)
		ok(not Game.echo_foe().is_empty() and Game.echo_foe().default, "%s: with no snapshot the echo is the default one" % name)
	# the mid-campaign save, in detail
	var v2 := Game._migrate(fixture("save_v2"))
	ok(v2.campaign.generation == 2 and v2.campaign.ending == "" and Generations.canon_open(v2), "save_v2: the second generation, in progress")
	ok(v2.generations[1].body == "f" and v2.generations[1].deeds.guardians.has("cathedral_beast") and v2.generations[1].deeds.routes.has("courtyard"), "save_v2: its deeds are the second's")
	ok(Encounters.unlocked("crypt", v2) and not Encounters.unlocked("citadel", v2), "save_v2: the road is where it was")
	ok(Generations.fall(v2, 2, "saved_the_records") and Generations.inherit(v2), "save_v2: it can go on to the second fall and the last heir")
	# the finished one
	var v1 := Game._migrate(fixture("save_v1"))
	ok(v1.campaign.generation == 3 and v1.campaign.ending == "cities" and v1.campaign.legacy == 1 and not Generations.canon_open(v1), "save_v1: the story was finished; it is a legacy journey")
	ok(v1.generations[1].fate == "kept" and v1.generations[1].authored and v1.campaign.monarch["3"].won, "save_v1: the second is recorded as kept, the Monarch as beaten")
	ok(v1.defeated.has("future_foe"), "save_v1: an id this version does not know is still there")
	# a version 3 save is only tidied
	if not FileAccess.file_exists("res://tests/fixtures/save_v3.json"):
		return
	var v3 := fixture("save_v3")
	var m3 := Game._migrate(fixture("save_v3"))
	ok(int(v3.version) == 3 and JSON.stringify(m3.campaign) == JSON.stringify(Generations._whole(v3.campaign)) and JSON.stringify(m3.generations) == JSON.stringify(Generations._whole(v3.generations)),
		"save_v3: a save that already has its generations keeps them exactly")
	ok(m3.campaign.generation == 3 and m3.campaign.echo.weapon.id == v3.campaign.echo.weapon.id and m3.generations.size() == 3, "save_v3: the last heir, with the echo's snapshot")

# ------------------------------------------------------------------ today's New Journey
func t_new_journey() -> void:
	fresh()
	ok(Game.generation() == 2 and Game.profile.generations.size() == 2, "a new journey is the second generation's")
	ok(Game.generation_record(1).fate == "fallen" and Game.generation_record(1).authored and Game.generation_record(2).fate == "alive", "the first is already fallen")
	ok(Game.region_unlocked("courtyard") and not Game.region_unlocked("blackwood"), "the road is gated as it was")
	Game.start_run("courtyard")
	ok(JSON.stringify(Game.stage_options()) == JSON.stringify(Game.run_stage().options), "its stops are the road's own")
	ok(Game.stage_options()[0].foe == "hollow_soldier" and not Game.stage_options()[0].has("was"), "its foes are the roster's own")
	for r: Dictionary in Db.regions:
		for i: int in r.stages.size():
			ok(Encounters.options(2, str(r.id), i) == r.stages[i].options, "generation II, %s stop %d: untouched" % [r.id, i]) if i == 0 else null
	ok(Game.witness_state() == "imprisoned", "the Witness is not yet found")
	Game.profile.flags["witness_found"] = true
	ok(Game.witness_state() == "found", "then it is")
	# the opening's own scene reports through the flags it has always set
	Game.profile.flags["gen1_complete"] = true
	Game.profile.flags["gen1_clash"] = "ahead"
	Game.profile.name = "Aldric"
	Game.save()
	ok(Game.monarch(1).record.get("result", "") == "ahead" and Generations.has_record("measure_of_him"), "the first clash is recorded from the opening's flags, and what it taught")
	ok(Game.generation_record().name == "Aldric" and Game.lineage().people[1].display == "Aldric" and Game.lineage().people[0].display == "The First", "the lineage names them")
	ok(Game.slot_summary(1).generation == 2 and Game.slot_summary(1).generation_title == "The Broken Crown", "the slot list knows the generation")
	round_trips("a new journey")

# ------------------------------------------------------------------ exactly two falls; a defeat is not one
func t_falls_and_defeats() -> void:
	fresh(1)
	ok(Game.generation() == 1 and Game.profile.generations.size() == 1, "a journey can begin with the first")
	ok(not Game.fall(2, "x") and not Game.fall(3, "x") and not Game.fall(0, "x") and not Game.inherit(), "nobody falls out of turn, and nobody inherits from the living")
	var before := canon()
	# ordinary defeats, as many as you like
	for i: int in 6:
		Game.start_run("throne")
		var o: Dictionary = Game.stage_options()[0]
		var s := DuelSim.new()
		s.setup(Game.fighter_stats(), Db.foes["forgotten_monarch"], 3 + i, {})
		while not s.over:
			s.tick(1.0 / 60.0)             # nobody at the controls: the knight is cut down
		ok(s.p_state == DuelSim.P.DEAD, "an ordinary defeat (%d)" % i) if i == 0 else null
		Secrets.duel_ended(o, false, s)
		Game.on_death()
	ok(Game.generation() == 1 and Game.transition_pending().is_empty() and Game.profile.generations.size() == 1 and Game.generation_record().fate == "alive",
		"six defeats later it is the same generation, alive, with no transition")
	ok(Game.generation_record().stats.defeats == 6 and Game.profile.deaths == 6, "the defeats are counted, and that is all they do")
	var c: Array = JSON.parse_string(before)
	var now: Array = JSON.parse_string(canon())
	ok(JSON.stringify(c[1]) == JSON.stringify(now[1]) and JSON.stringify(c[2]) == JSON.stringify(now[2]), "the world and the campaign are untouched by defeat")
	ok(Game.fall(1, "sealed_hall", {"clash": "ahead"}), "the first falls")
	ok(not Game.fall(1, "again") and not Game.fall(2, "early"), "and falls only once; the second cannot fall before taking up the road")
	ok(Game.transition_pending().get("state", "") == "fallen" and Game.generation() == 1, "until someone inherits, the transition is pending")
	for i: int in 3:
		Game.on_death()
	ok(Game.generation() == 1 and Game.transition_pending().to == 2, "a defeat during it changes nothing")
	ok(Game.inherit() and Game.generation() == 2 and not Game.inherit(), "the second inherits, once")
	ok(not Game.fall(1, "again") and Game.fall(2, "saved_the_records") and not Game.fall(2, "again"), "the second falls, once")
	ok(Game.inherit({"name": "Third"}) and Game.generation() == 3, "the last heir inherits")
	ok(not Game.fall(3, "never") and not Game.fall(2, "again") and not Game.inherit(), "there is no third fall")
	for i: int in 4:
		Game.on_death()
	ok(Game.generation() == 3 and Game.profile.campaign.history.size() == 2, "exactly two transitions, whatever happens after")
	ok(Game.profile.generations.map(func(r): return r.fate) == ["fallen", "kept", "alive"], "fallen, kept, alive")
	round_trips("after both falls")

# ------------------------------------------------------------------ both lineages
func t_bodies() -> void:
	var want := {"m": [["Father", "Son", "Grandson"], ["Grandfather", "Father", "Yourself"]], "f": [["Mother", "Daughter", "Granddaughter"], ["Grandmother", "Mother", "Yourself"]]}
	for body: String in ["m", "f"]:
		fresh(2, body)
		Game.save()
		ok(Game.generation_record(1).body == body, "%s: the forebear is of the same lineage" % body)
		Game.fall(2, "saved_the_records")
		Game.inherit()
		var people: Array = Game.lineage().people
		ok(people.map(func(x): return x.relation) == want[body][0], "%s: %s" % [body, ", ".join(want[body][0])])
		ok(people.map(func(x): return x.kin) == want[body][1], "%s: to the heir they are %s" % [body, ", ".join(want[body][1])])
		ok(people[0].relation_words == {"m": "Father", "f": "Mother"} and people[2].relation_words == {"m": "Grandson", "f": "Granddaughter"}, "%s: both words are given for each" % body)
		ok(people.map(func(x): return x.years_ago) == [46, 24, 0] and people.map(func(x): return x.year) == [0, 22, 46], "%s: the years" % body)
	# a lineage may change body between generations
	fresh(2, "m")
	Game.fall(2, "saved_the_records")
	Game.inherit({"body": "f", "name": "Ysolde"})
	ok(Game.profile.body == "f" and Game.lineage().people[2].relation == "Granddaughter" and Game.lineage().people[1].relation == "Son" and Game.lineage().people[2].display == "Ysolde",
		"the heir may be a granddaughter of a son")

# ------------------------------------------------------------------ the director
func world(gen: int, slain: Array) -> Dictionary:
	var p := Game.default_profile()
	p.campaign.generation = gen
	if gen == 3:
		p.generations.append(Generations.blank_record(3))
	for id: String in slain:
		p.world.facts["slain:" + id] = 2
		p.defeated[id] = 1
	return p

func t_director() -> void:
	var sealed := {1: ["cathedral", "crypt", "roost", "citadel", "deep"], 2: [], 3: []}
	var gen2_guardians := ["ashen_sentinel", "hollow_executioner", "crimson_widow", "cathedral_beast", "gravewarden", "frostbound_king", "pale_huntsman",
		"cinder_wyrm", "rimewyrm", "azhurion", "devourer"]
	for case: Array in [[1, []], [2, []], [3, []], [3, gen2_guardians], [3, ["ashen_sentinel", "hollow_executioner", "cathedral_beast", "gravewarden", "frostbound_king"]]]:
		var gen: int = case[0]
		var p := world(gen, case[1])
		if gen == 3:
			p.world.facts["monarch_felled:3"] = 3
		var tag := "generation %d%s" % [gen, "" if case[1].is_empty() else " (%d fell before)" % case[1].size()]
		var every := true
		var none_sealed := true
		var no_ghosts := true
		var fights := 0
		for r: Dictionary in Db.regions:
			var shut: bool = sealed[gen].has(r.id)
			ok(Encounters.sealed(gen, str(r.id), p) == shut, "%s: %s is %s" % [tag, r.id, "sealed" if shut else "not sealed"])
			for i: int in r.stages.size():
				var opts: Array = Encounters.stop(gen, str(r.id), i, p).options
				none_sealed = none_sealed and (not shut or opts.is_empty())
				every = every and (shut or not opts.is_empty())
				for o: Dictionary in opts:
					if not o.has("foe"):
						continue
					fights += 1
					every = every and Db.foes.has(str(o.foe)) and (Db.foes.has(Encounters.base_of(str(o.foe))) or str(o.foe) == "the_kept")
					var who := Encounters.individual(str(o.was))
					if gen == 3 and case[1].has(who):
						no_ghosts = false
						print("    %s stands again at %s %d" % [who, r.id, i])
		ok(every, "%s: every stop resolves, and every foe is one that exists" % tag)
		ok(none_sealed, "%s: a sealed region gives no stop" % tag)
		ok(no_ghosts, "%s: nobody who fell in an earlier generation stands again" % tag)
		ok(fights > 0, "%s: there is someone to fight (%d places)" % [tag, fights])
	# the first generation: a short slice
	var p1 := world(1, [])
	var slice: Array = Encounters.route(1, "throne", p1)
	ok(slice.map(func(e): return e.foe) == ["royal_gatekeeper", "monarch_i"], "generation I: the gatekeeper, then the Monarch")
	ok(Encounters.route(1, "courtyard", p1).is_empty() and Encounters.access(1, "courtyard", p1).state == "passed", "generation I: the courtyard is walked through")
	ok(Encounters.access(1, "cathedral", p1).state == "sealed" and Encounters.access(1, "crypt", p1).state == "shut" and Encounters.access(1, "roost", p1).state == "distant", "generation I: sealed, shut, distant")
	# the third: guardians replaced, with a reason; the ones that were spared may still be there
	var all := world(3, gen2_guardians)
	var none := world(3, [])
	ok(Encounters.guardian(3, "courtyard", all).id == "the_kept" and Encounters.guardian(3, "courtyard", all).why != "", "generation III: the echo keeps the Courtyard, and the world says why")
	ok(Encounters.guardian(3, "blackwood", all).id == "awakened_beast" and Encounters.guardian(3, "cathedral", all).id == "laboratory_guardian", "generation III: the Awakened Beast and the Laboratory Guardian")
	ok(Encounters.guardian(3, "citadel", none).id == "rimewyrm_g3" and Encounters.guardian(3, "citadel", all).id == "white_brood", "generation III: Skeldra if she lives, her brood if she does not")
	ok(Encounters.guardian(3, "roost", none).id == "cinder_wyrm_g3" and Encounters.guardian(3, "roost", world(3, ["cinder_wyrm"])).id == "azhurion_g3" and Encounters.guardian(3, "roost", all).is_empty(),
		"generation III: the dragon hunt follows who is left")
	ok(Encounters.guardian(3, "crypt", none).id == "devourer_g3" and Encounters.guardian(3, "crypt", all).is_empty(), "generation III: the way down leads to the Devourer, once")
	ok(Encounters.guardian(3, "throne", all).id == "monarch_iii", "generation III: the Monarch, who is not mortal")
	for v: String in ["awakened_beast", "laboratory_guardian", "white_brood", "monarch_iii", "monarch_i"]:
		ok(Encounters.why(v) != "", "%s has a recorded reason" % v)
	ok(Encounters.route(3, "courtyard", all).size() < Encounters.route(2, "courtyard", all).size() and Encounters.route(3, "throne", all).size() < Encounters.route(2, "throne", all).size(),
		"generation III has fewer fights on a road than generation II")
	# region access in the third
	ok(Encounters.unlocked("courtyard", all) and not Encounters.unlocked("blackwood", all) and not Encounters.unlocked("throne", all), "generation III: the Courtyard first")
	all.cleared = ["courtyard"]
	ok(Encounters.unlocked("blackwood", all) and Encounters.unlocked("cathedral", all) and Encounters.unlocked("citadel", all) and not Encounters.unlocked("throne", all), "then three roads in any order")
	all.cleared = ["courtyard", "blackwood", "citadel"]
	ok(Encounters.unlocked("throne", all), "two of the three open the throne")
	ok(not Encounters.unlocked("deep", all) and Encounters.access(3, "deep", all).state == "sealed", "the facility under the throne is sealed until the Monarch falls")
	all.world.facts["monarch_felled:3"] = 3
	ok(Encounters.unlocked("deep", all), "and open after")
	# tuned copies: stronger than what they are copied from, the same foe otherwise
	var a: Dictionary = Db.foes.hollow_soldier
	var b := Encounters.foe("hollow_soldier_g3", all)
	ok(b.hp > a.hp * 2 and b.gold > a.gold and b.rig.weapon == a.rig.weapon and b.reward_as == "hollow_soldier" and not b.boss, "a generation III copy is the same foe, brought up to the end of the road")
	ok(Db.foes.hollow_soldier.hp == a.hp, "and the original is not touched")
	# through the game: a run in the third generation
	fresh()
	Game.profile.flags["courtyard_gate"] = true
	Game.fall(2, "saved_the_records")
	Game.inherit()
	Game.start_run("courtyard")
	ok(Game.stage_options()[0].foe == "pike_sergeant_g3" and Game.stage_options()[0].was == "pike_sergeant", "generation III through the game: a recruit at the Breach")
	Game.run.stage = 3
	ok(Game.stage_options().all(func(o): return o.type != "lever"), "a gate the second opened stays open")
	Game.run.stage = 6
	ok(Game.stage_options()[0].foe == "the_kept" and Db.foes.has("the_kept"), "the echo stands in the Inner Ward")
	ok(Game.shortcut_open("courtyard"), "and the short way is still there")
	var pct_before: float = Game.completion().pct
	Encounters.foe("monarch_iii")
	ok(is_equal_approx(Game.completion().pct, pct_before), "another generation's cast does not change what completion counts")

# ------------------------------------------------------------------ the three meetings
func t_monarch() -> void:
	fresh()
	var base := JSON.stringify(Db.foes.forgotten_monarch)
	var m1 := Encounters.foe("monarch_i")
	ok(m1.phases.size() == 1 and m1.boss and m1.has("clash") and m1.xp == 0 and m1.gold == 0, "generation I: one phase, a clash, nothing to win")
	# nobody dies to an ordinary blow in the clash: even with no hand on the controls the forebear outlives it
	var s := DuelSim.new()
	s.setup(Game.fighter_stats(1), m1, 5, {})
	while s.time < float(m1.clash.release) and not s.over:
		s.tick(1.0 / 60.0)
	ok(s.p_state != DuelSim.P.DEAD, "generation I: the story ends the clash before the forebear can be killed (%.0f%% left, untouched controls)" % (100.0 * s.pl.hp / s.pl.max_hp))
	ok(Game.monarch(2).foe == "forgotten_monarch" and Game.monarch(2).choices == ["press", "records"] and float(Game.monarch(2).threshold.at) == float(Db.foes.forgotten_monarch.phases[2].at),
		"generation II: the existing Monarch; the choice is offered where his last phase begins")
	ok(JSON.stringify(Db.foes.forgotten_monarch) == base, "the existing Monarch is not altered")
	# a player who wins is recorded as having won, and is paid
	ok(not Game.monarch_won(2), "not beaten yet")
	Game.start_run("throne")
	var gold: int = Game.profile.gold
	var r := Game.on_victory("forgotten_monarch", 50.0)
	ok(Game.monarch_won(2) and Game.has_fact("monarch_bested:2") and Generations.has_record("the_crown_can_bleed"), "generation II: a win is recorded as a win, and is a record of the house")
	ok(Game.profile.gold > gold and r.xp > 0 and r.core and not r.items.is_empty(), "and it pays what beating him pays")
	Game.record_monarch(2, {"choice": "press"})
	ok(Game.monarch_won(2) and Game.monarch(2).record.choice == "press", "the choice is kept beside it")
	Game.record_monarch(2, {"won": false, "choice": "records"})
	ok(Game.monarch_won(2), "a win, once recorded, is not unrecorded")
	Game.fall(2, "saved_the_records", {"choice": "records"})
	ok(Game.monarch_won(2) and Game.monarch(2).record.choice == "records" and Game.generation_record(2).fate == "kept", "he falls saving the records all the same")
	Game.inherit()
	# generation III: three named phases; what the family gathered weakens the last
	var m3 := Encounters.foe("monarch_iii")
	ok(m3.phases.map(func(ph): return ph.name) == ["The Sovereign", "The Ancient Crown", "The Last Defense"] and float(m3.phases[2].revive) > 0.0, "generation III: the Sovereign, the Ancient Crown, the Last Defense")
	var held: int = m3.records_held
	var revive: float = m3.phases[2].revive
	Game.profile.lore = range(30)
	Game.profile.defeated["devourer"] = 1
	Game.profile.defeated["the_kept"] = 1
	var richer := Encounters.foe("monarch_iii")
	ok(richer.records_held == held + 3 and float(richer.phases[2].revive) < revive and float(richer.traits.lifesteal) < float(m3.traits.lifesteal) and float(richer.traits.parry_open) > float(m3.traits.parry_open),
		"every record gathered weakens his restoration (%d held: stands again at %.0f%%; %d held: %.0f%%)" % [held, revive * 100.0, richer.records_held, float(richer.phases[2].revive) * 100.0])
	var bare := Game.default_profile()
	bare.campaign.generation = 3
	bare.generations[0].fate = "alive"
	var worst := Encounters.foe("monarch_iii", bare)
	ok(worst.records_held == 0 and is_equal_approx(float(worst.phases[2].revive), 0.6), "with nothing gathered he comes back at more than half")
	Encounters.foe("monarch_iii")
	ok(Game.monarch(3).foe == "monarch_iii" and not Game.monarch_won(3) and not Game.region_unlocked("deep"), "generation III: not yet beaten")
	Game.start_run("throne")
	Game.on_victory("monarch_iii", 40.0)
	ok(Game.monarch_won(3) and Game.has_fact("monarch_felled:3") and Game.region_unlocked("deep"), "beating him opens what is under the throne")
	ok(Game.profile.defeated.get("forgotten_monarch", 0) == 1 and Game.profile.defeated.get("monarch_iii", 0) == 1, "the two victories are two records")

# ------------------------------------------------------------------ the echo
func first_of(slot: String, cls: String = "", weight: String = "") -> String:
	for it: Dictionary in Db.item_list:
		if it.slot == slot and (cls == "" or it.get("cls", "") == cls) and (weight == "" or it.get("weight", "") == weight) and int(it.get("ng_min", 0)) == 0:
			return str(it.id)
	return ""

## A second generation at its fall: {weapon class, shield or not, armour family, attributes, combos by use, habits}.
func build(b: Dictionary) -> void:
	fresh()
	var p: Dictionary = Game.profile
	p.level = int(b.level)
	for k: String in b.attrs:
		p.attrs[k] = b.attrs[k]
	var gear: Array = [b.weapon]
	if b.get("shield", "") != "":
		gear.append(b.shield)
	for it: Dictionary in Db.item_list:
		if it.get("family", "") == b.family and Db.ARMOUR_SLOTS.has(it.slot):
			gear.append(str(it.id))
	p.equipped.shield = null
	for id: String in gear:
		Game.grant_item(id)
		Game.equip(id)
		p.upgrades[id] = int(b.up)
	p.mods[b.weapon] = {"grip": 2, "ore": 2, "ore_id": "m_iron"}
	for id: String in b.combos:
		if not p.combos.has(id):
			p.combos.append(id)
		p.combo_uses[id] = int(b.combos[id])
	var s: Dictionary = Game.generation_record().stats
	for k: String in b.habits:
		s[k] = int(b.habits[k])
	p.name = str(b.name)
	Game.save()

func t_echo() -> void:
	var builds := [
		{"name": "Light", "weapon": "w_dawnline", "shield": "s_plank", "family": "crownless", "up": 2, "level": 10, "attrs": {"health": 8, "strength": 6, "dex": 14, "endurance": 10},
			"combos": {"double_slash": 40, "rising_fang": 22, "mirror_step": 9, "riposte": 3}, "habits": {"parries": 20, "dodges": 70, "blocks": 10}},
		{"name": "Heavy", "weapon": first_of("weapon", "greatsword"), "family": "frostwarden", "up": 4, "level": 16, "attrs": {"health": 16, "strength": 18, "dex": 5, "endurance": 12, "defense": 8},
			"combos": {"colossus": 30, "tidebreaker": 12, "falling_crown": 11, "armor_splitter": 4}, "habits": {"parries": 10, "dodges": 10, "blocks": 0}},
		{"name": "Twin", "weapon": first_of("weapon", "dual"), "family": "widow", "up": 3, "level": 13, "attrs": {"health": 10, "strength": 8, "dex": 16, "endurance": 14},
			"combos": {"twin_fang": 50, "whirlwind": 31, "double_slash": 12, "reversal": 6, "serpents_path": 5, "eternal_edge": 1}, "habits": {"parries": 60, "dodges": 30, "blocks": 0}},
		{"name": "Shieldless", "weapon": "w_knight_sword", "family": "gravekeeper", "up": 3, "level": 12, "attrs": {"health": 12, "strength": 12, "dex": 10, "endurance": 10, "defense": 5},
			"combos": {"riposte": 25, "crossbreaker": 18, "armor_splitter": 9}, "habits": {"parries": 80, "dodges": 15, "blocks": 0}},
	]
	var prints := {}
	for b: Dictionary in builds:
		ok(b.weapon != "", "%s: there is such a weapon" % b.name)
		build(b)
		var worn: Dictionary = Game.profile.equipped.duplicate()
		ok(Game.fall(2, "saved_the_records"), "%s: the second falls" % b.name)
		var shot: Dictionary = Game.profile.campaign.echo
		ok(shot.weapon.id == b.weapon and shot.weapon.level == b.up and shot.weapon.mods == {"grip": 2, "ore": 2, "ore_id": "m_iron"} and shot.body == "m" and shot.name == b.name,
			"%s: the snapshot has the weapon, its level, its mods and ore, the body and the name" % b.name)
		ok(JSON.stringify(shot.equipped) == JSON.stringify(worn) and shot.look.size() == worn.size() and shot.shield == b.get("shield", ""), "%s: and every slot as it was worn" % b.name)
		var top: String = b.combos.keys()[0]
		ok(shot.combos[0] == [top, b.combos[top]] and shot.combos.size() == mini(5, b.combos.size()), "%s: its favourite combinations, most used first, with their counts" % b.name)
		ok(is_equal_approx(float(shot.habits.parry) + float(shot.habits.dodge) + float(shot.habits.block), 1.0), "%s: and how it defended" % b.name)
		ok(float(shot.stats.attack) > 0.0 and float(shot.stats.max_hp) > 0.0, "%s: and its numbers at that moment" % b.name)
		Game.inherit()
		var frozen := JSON.stringify(Game.profile.campaign.echo)
		var f := Game.echo_foe()
		var text := JSON.stringify(f)
		ok(JSON.stringify(Game.echo_foe()) == text, "%s: the same snapshot gives the same foe" % b.name)
		# what the heir does afterwards does not reach back
		Game.profile.combo_uses["double_slash"] = 9999
		Game.profile.gold += 5000
		Game.grant_item("w_knight_sword")
		Game.equip("w_knight_sword")
		ok(JSON.stringify(Game.profile.campaign.echo) == frozen and JSON.stringify(Game.echo_foe()) == text, "%s: the snapshot is frozen" % b.name)
		Game.equip(str(b.weapon))
		Game.save()
		Game.load_game()
		ok(JSON.stringify(Game.echo_foe()) == text, "%s: and survives the save" % b.name)
		prints[b.name] = text
		# the shape of a foe
		for k: String in ["id", "name", "title", "cls", "region", "boss", "hp", "armor", "posture", "poise", "patience", "adapt", "idle", "weak", "xp", "gold", "loot", "rig", "music", "punish", "phases", "press", "footwork", "traits"]:
			ok(f.has(k), "%s: the echo has `%s`" % [b.name, k]) if not f.has(k) else null
		ok(f.id == "the_kept" and f.boss and f.phases.size() == 3 and f.phases[0].at == 1.0 and Db.foes.the_kept == f, "%s: a guardian in three phases, ready for the duel" % b.name)
		ok(tightest(f) >= 0.45, "%s: every blow can be read (%.2fs)" % [b.name, tightest(f)])
		var ids: Array = []
		for ph: Dictionary in f.phases:
			for c: Dictionary in ph.combos:
				ids.append(str(c.id))
		for id: String in b.combos.keys().slice(0, 5):
			ok(ids.has(id), "%s: it throws %s" % [b.name, id])
		var mine: Dictionary = Db.combo_by_id[top]
		var theirs: Dictionary = f.phases[0].combos.filter(func(c): return c.id == top)[0]
		ok(theirs.attacks.map(func(a): return a.dir) == mine.seq, "%s: with the same cuts in the same order" % b.name)
		ok(f.look.equipped.weapon == b.weapon and f.look.weapon.mods.ore == 2 and f.look.body == "m" and f.rig is Dictionary and not f.rig.is_empty() and f.rig.witness == false,
			"%s: it is dressed as the second was (`look` and `rig`)" % b.name)
		# fair but hard: the skilled bot always wins with what was inherited; mashing does not; it is never over at once
		var st := Game.stats()
		var wins := 0
		var quickest := 999.0
		var hurt := 0.0
		for sd: int in [11, 12, 13, 14]:
			var s := fight(st, "the_kept", DuelBot.Style.SKILLED, sd)
			wins += 1 if won(s) else 0
			quickest = minf(quickest, s.time)
			hurt += float(s.stats.taken)
		ok(wins == 4, "%s: the skilled bot wins every time (%d of 4)" % [b.name, wins])
		ok(quickest >= 25.0, "%s: and never quickly (fastest %.0fs)" % [b.name, quickest])
		var mashed := 0
		for sd: int in [21, 22, 23]:
			mashed += 1 if won(fight(st, "the_kept", DuelBot.Style.SPAM, sd)) else 0
		ok(mashed == 0, "%s: mashing does not beat it (%d of 3)" % [b.name, mashed])
		print("    %-10s hp %5d  blow %2d  %s  skilled: %d/4, fastest %.0fs, %.0f damage taken a fight; mashing: %d/3" % [b.name, f.hp, f.phases[0].combos[0].attacks[0].dmg, str(f.traits), wins, quickest, hurt / 4.0, mashed])
	ok(prints.values().size() == 4 and prints.Light != prints.Heavy and prints.Twin != prints.Shieldless and prints.Light != prints.Twin, "different snapshots give different echoes")
	ok(JSON.parse_string(prints.Heavy).traits.has("block_tax") and JSON.parse_string(prints.Twin).traits.has("dodge_open") and JSON.parse_string(prints.Shieldless).traits.has("parry_open"),
		"how it fights follows the weapon and the habits")
	# no snapshot: the default, from the starting kit
	fresh()
	var d := Game.echo_foe()
	ok(d.default and d.look.equipped.weapon == "w_rusted_sword" and d.phases.size() == 3 and tightest(d) >= 0.45, "with no snapshot the echo wears the starting kit")
	ok(won(fight(Game.stats(), "the_kept", DuelBot.Style.SKILLED, 5)), "and can be beaten with it")

# ------------------------------------------------------------------ endings, and what a legacy journey may not touch
func t_endings() -> void:
	fresh()
	ok(Game.endings().map(func(e): return e.open) == [true, true, false], "two endings are always open; the third is not")
	Game.profile.defeated["devourer"] = 1
	Game.profile.cleared.append("roost")
	Game.profile.lore = range(29)
	ok(not Game.can_divide_crown(), "twenty-nine records are not enough")
	Game.profile.lore = range(30)
	ok(Game.can_divide_crown(), "the second generation, as the game stands today: the three old conditions divide the Crown")
	Game.save()
	ok(Game.inheritance().filter(func(r): return r.held and r.ending).size() == 3, "they are three of the family's records now")
	Game.fall(2, "saved_the_records")
	Game.inherit()
	ok(Game.profile.cleared.is_empty() and Generations.has_record("siege_engine"), "what the second gathered is still gathered when the roads are walked again")
	ok(not Game.can_divide_crown() and not Generations.has_record("one_who_was_kept"), "the last heir must also have faced the Kept")
	Game.echo_foe()
	Game.start_run("courtyard")
	Game.on_victory("the_kept", 30.0)
	ok(Game.can_divide_crown() and Generations.has_record("one_who_was_kept") and Game.endings()[2].open, "and then the third ending is open")
	Game.save()
	ok(Game.profile.campaign.inheritance.one_who_was_kept == 3 and Game.profile.campaign.inheritance.siege_engine == 2 and Game.profile.campaign.inheritance.first_oath == 2,
		"each record remembers which generation gathered it")
	# the canon, then a legacy journey
	Game.choose_ending("cities")
	ok(Game.profile.campaign.ending == "cities" and Game.endings()[2].chosen and not Generations.canon_open(Game.profile), "the ending chosen is the canon's")
	var kept := canon()
	var lineage := JSON.stringify(Game.lineage().people)
	var inv: int = Game.profile.inventory.size()
	Game.start_ng_plus()
	ok(Game.on_legacy_journey() and Game.profile.ng == 1 and Game.profile.cleared.is_empty() and Game.profile.inventory.size() == inv, "a legacy journey: the world turns over, everything is kept")
	ok(Encounters.generation() == 2 and Game.generation() == 3, "it walks the second generation's roads, as the heir")
	Game.start_run("courtyard")
	ok(Game.stage_options()[0].foe == "hollow_soldier", "against the roster's own foes")
	for foe: String in ["hollow_soldier", "ashen_sentinel", "forgotten_monarch", "devourer"]:
		var s := fight(Game.stats(), foe, DuelBot.Style.SKILLED, 3, 5.0)
		Secrets.duel_ended({"foe": foe}, true, s)
		Game.on_victory(foe, 50.0)
	Game.complete_region()
	Game.profile.flags["blackwood_bridge"] = true
	Game.profile.lore.append(999)
	ok(not Game.fall(2, "no") and not Game.fall(3, "no") and not Game.inherit() and not Game.add_fact("released:rimewyrm"), "nobody falls on a legacy journey, and no fact is added")
	Game.choose_ending("silence")
	Game.record_monarch(2, {"won": true})
	Game.save()
	var after: Array = JSON.parse_string(canon())
	var before: Array = JSON.parse_string(kept)
	before[2].legacy = 1
	diff(before, after, "canon")
	ok(JSON.stringify(after) == JSON.stringify(before), "the lineage, the world's facts and the canon's ending are exactly as they were (only the count of legacy journeys moved)")
	ok(JSON.stringify(Game.lineage().people) == lineage and Game.lineage().legacy == 1 and Game.lineage().ending == "cities", "the lineage screen shows the same three, and the ending first chosen")
	ok(Game.profile.endings == ["cities", "silence"] and Game.profile.flags.last_ending == "silence", "the legacy journey's own ending is kept apart")
	round_trips("a legacy journey")

# ------------------------------------------------------------------ who says what, by generation
func t_companion() -> void:
	fresh()
	var keep: Dictionary = Story.data.duplicate(true)
	Story.data.scenes["w_test_g3"] = {"lines": [], "once": false}
	Story.data.scenes["w_test"] = {"lines": [], "once": false}
	Story.data.scenes["kept_g3_intro"] = {"lines": [], "once": false}
	Story.data.companion["gen"] = {"3": {"stage": {"courtyard": {"0": ["w_test"]}}, "boss": {"the_kept": {"approach": ["w_test"], "victory": []}}}}
	Story.data.speech["the_kept"] = "C"
	Story.data.foe_voice["the_kept"] = "kept"
	Game.profile.flags["witness_found"] = true
	Companion.reset_cooldown()
	var second: Array = Companion.pick_stage("courtyard", 0)
	ok(Companion.scene_for("w_test") == "w_test" and not second.has("w_test") and not second.has("w_test_g3"), "the second generation hears its own lines")
	ok(Companion.speech("hollow_soldier") == "A" and Companion.speech("forgotten_monarch") == Companion.speech("monarch_iii") and Companion.voice_key("monarch_iii") == Companion.voice_key("forgotten_monarch"),
		"another generation's cast speaks as the foe it is cast from")
	Game.fall(2, "saved_the_records")
	Game.inherit()
	Companion.reset_cooldown()
	ok(Companion.scene_for("w_test") == "w_test_g3", "a scene tagged for the third generation replaces the plain one")
	ok(Companion.pick_stage("courtyard", 0).has("w_test_g3"), "the third generation's own table is used at a stop")
	ok(Companion.pick_boss_approach("the_kept") == ["w_test_g3"], "and before a guardian")
	ok(Companion.speech("the_kept") == "C" and Companion.voice_key("the_kept") == "kept_g3", "a voice key tagged for the generation is used when its scenes exist")
	ok(Game.witness_state() == "returning", "the Witness returns with the heir")
	Story.data = keep

# ------------------------------------------------------------------ the whole campaign, with the real sim
func t_campaign() -> void:
	wipe()
	var econ: Node = load("res://tools/econ_sim.gd").new()
	econ.style = DuelBot.Style.SKILLED
	econ.quiet = true
	econ.track = true
	econ.seed_base = 7
	Game.new_game("#3d0f0f", "m", "w_dawnline", 1)
	Game.profile.rewards.seed = 7
	Game.rng.seed = 7
	Game.profile.name = "Aldric"
	# ---- generation I: the gatekeeper, the clash, the fall
	var slice: Array = Encounters.route(1, "throne")
	var g := fight(Game.fighter_stats(1), str(slice[0].foe), DuelBot.Style.SLOPPY, 7)
	ok(won(g), "I: the forebear beats the Royal Gatekeeper, even played carelessly (%.0fs)" % g.time)
	Secrets.duel_ended({"foe": str(slice[0].foe)}, true, g)
	var clash := fight(Game.fighter_stats(1), str(slice[1].foe), DuelBot.Style.SLOPPY, 7, float(Db.foes[slice[1].foe].clash.release))
	ok(clash.p_state != DuelSim.P.DEAD and not won(clash), "I: the clash is neither won nor lost on health (%.0f%% left)" % (100.0 * clash.pl.hp / clash.pl.max_hp))
	round_trips("before the first fall")
	var fam := family()
	var blade := Game.item_record("w_dawnline")
	ok(Game.fall(1, "sealed_hall", {"clash": "ahead"}), "I: the first falls")
	ok(family() == fam, "I: nothing the family holds changed at the fall")
	round_trips("after the first fall")
	ok(Game.inherit(), "II: the second takes up the road")
	round_trips("after the second inherits")
	ok(family() == fam and Game.profile.body == "m" and Game.profile.name == "Aldric", "II: nothing the family holds changed at the inheritance")
	var left := Game.fallen_weapon()
	ok(left.id == "w_dawnline" and left.left_where_it_fell and not left.taken and left.generation == 1 and left.where == "engine_block", "II: the sword lies where it dropped")
	ok(Game.owns("w_dawnline") and Game.profile.equipped.weapon == "w_dawnline" and Game.item_record("w_dawnline") == blade, "II: skip the scene and the heir simply has it, the same record")
	ok(Game.take_fallen_weapon().taken and Game.fallen_weapon().taken and Game.item_record("w_dawnline") == blade, "II: taking it up changes nothing about it")
	ok(Game.generation_record(1).fate == "fallen" and Game.generation_record(1).stats.wins == 1 and Generations.has_record("first_oath") and Generations.has_record("measure_of_him"),
		"II: the first is recorded: fate, fights, and what they sent")
	# ---- generation II: today's campaign
	var deaths := 0
	for r: String in econ.ORDER:
		econ.play_region(r)
		deaths += int(econ.row.deaths)
		ok(Game.generation() == 2 and Game.transition_pending().is_empty(), "II: %s cleared (%d fights, %d defeats); still the second generation" % [r, econ.row.fights, econ.row.deaths])
	ok(Game.game_complete() and Game.monarch_won(2), "II: the skilled player beat the Monarch, and it is recorded")
	ok(Game.profile.deaths == deaths, "II: %d ordinary defeats, none of which advanced anything" % deaths)
	var rec2 := Game.generation_record(2)
	print("    II: guardians %d, regions %d, routes %d, wins %d" % [rec2.deeds.guardians.size(), rec2.deeds.regions.size(), rec2.deeds.routes.size(), rec2.stats.wins])
	ok(rec2.deeds.guardians.has("ashen_sentinel") and rec2.deeds.guardians.has("forgotten_monarch") and rec2.deeds.regions.size() == 8 and rec2.deeds.routes.size() >= 6 and rec2.stats.wins >= 30,
		"II: its deeds and its fights are its own")
	ok(Game.generation_record(1).deeds.guardians.is_empty(), "II: and not the first's")
	var uses: Dictionary = Game.profile.combo_uses.duplicate()
	ok(not uses.is_empty(), "II: combinations were used and counted")
	var w := str(Game.profile.equipped.weapon)
	var record := Game.item_record(w)
	var mods := JSON.stringify(Game.weapon_mods(w))
	var worn := JSON.stringify(Game.profile.equipped)
	var st_before := JSON.stringify(Game.stats())
	round_trips("before the second fall")
	fam = family()
	ok(Game.fall(2, "saved_the_records", {"choice": "records"}), "II: the second falls saving the records")
	ok(family() == fam, "II: nothing the family holds changed at the fall")
	round_trips("after the second fall")
	ok(Game.inherit({"name": "Maren"}), "III: the last heir takes up the road")
	round_trips("after the heir inherits")
	if OS.get_cmdline_user_args().has("--write_fixture"):
		# a save of the last heir with the echo's snapshot, kept for the migrations still to come
		var out := FileAccess.open("res://tests/fixtures/save_v3.json", FileAccess.WRITE)
		out.store_string(FileAccess.get_file_as_string(Game.slot_file(1)))
		out.close()
		print("    wrote tests/fixtures/save_v3.json")
	var fam3 := family()
	ok(fam3 == fam, "III: everything is inherited exactly: gear, gold, materials, mastery, combinations and their use, records, completion")
	ok(JSON.stringify(Game.profile.equipped) == worn and JSON.stringify(Game.stats()) == st_before, "III: the heir wears what the second wore, with the same numbers")
	ok(Game.item_record(w) == record and JSON.stringify(Game.weapon_mods(w)) == mods and Game.fallen_weapon().id == w and Game.fallen_weapon().record.level == record.level and Game.fallen_weapon().generation == 2,
		"III: the second's weapon is the same record: level, mods, mastery")
	ok(Game.profile.cleared.is_empty() and Generations.cleared_ever().size() == 8 and Game.shop_progress() == 8, "III: the roads are to be walked again, and Orren's stock is where it was")
	ok(Game.shortcut_open("courtyard") and Game.has_fact("route_opened:courtyard") and Game.has_fact("slain:ashen_sentinel") and Game.witness_state() == "returning", "III: what the second did to the world is still done")
	ok(Game.profile.name == "Maren" and Game.lineage().people.map(func(x): return x.display) == ["The First", "Aldric", "Maren"], "III: three of the house")
	# the echo is the second, as the player left them
	var echo := Game.echo_foe()
	ok(not echo.default and echo.look.equipped.weapon == w and JSON.stringify(echo.look.equipped) == worn and echo.look.name == "Aldric", "III: the echo wears exactly what the second wore")
	var top := ""
	for id: String in uses:
		if top == "" or uses[id] > uses[top]:
			top = id
	ok(echo.favourites[0][0] == top and echo.favourites[0][1] == uses[top], "III: and fights with the combination the player used most (%s, %d times)" % [top, uses.get(top, 0)])
	ok(int(echo.habits.seen) > 0, "III: and its habits come from the second's own fights")
	# ---- generation III: the faster pass
	var inv_before: Array = Game.profile.inventory.duplicate()
	var cores: Dictionary = Game.profile.rewards.cores.duplicate()
	Game.start_run("courtyard")
	Game.run.stage = 1
	for o: Dictionary in Game.stage_options():
		if o.type == "treasure":
			ok(Game.open_treasure(o).items.is_empty(), "III: a chest the second emptied gives nothing twice")
	Game.run = {}
	var fights3 := 0
	for r: String in econ.G3_MAIN + econ.G3_SIDE:
		ok(Game.region_unlocked(r), "III: %s is open when its turn comes" % r)
		econ.play_region(r)
		fights3 += int(econ.row.fights)
		ok(Game.generation() == 3, "III: %s cleared (%d fights, %d defeats)" % [r, econ.row.fights, econ.row.deaths])
	ok(Game.monarch_won(3) and Game.profile.defeated.has("the_kept") and Game.game_complete(), "III: the Kept and the Monarch are beaten")
	ok(fights3 < int(rec2.stats.fights), "III: a faster pass (%d fights against %d)" % [fights3, rec2.stats.fights])
	var seen := {}
	var dup := false
	for id: String in Game.profile.inventory:
		dup = dup or seen.has(id)
		seen[id] = true
	ok(not dup and inv_before.all(func(id): return Game.owns(id)), "III: no item twice, and nothing the second held is gone")
	for foe: String in cores:
		ok(Game.profile.rewards.cores[foe] == cores[foe], "III: %s paid its core once" % foe) if Game.profile.rewards.cores[foe] != cores[foe] else null
	ok(Game.profile.rewards.cores.has("the_kept") and Game.profile.rewards.cores.has("monarch_iii"), "III: its own guardians pay their own")
	var rec3 := Game.generation_record(3)
	ok(rec3.deeds.guardians.has("the_kept") and rec3.deeds.guardians.has("monarch_iii") and not rec3.deeds.guardians.has("ashen_sentinel") and Game.generation_record(2).deeds.guardians.has("ashen_sentinel"),
		"III: deeds are credited to whoever did them")
	print("    III: completion %.1f%%, courtyard stops %d" % [Game.completion().pct, Secrets.stops_walked("courtyard")])
	ok(Game.completion().pct > 0.0 and Secrets.stops_walked("courtyard") == 7, "III: completion goes on counting across generations")
	# ---- the endings, and after
	ok(Game.can_divide_crown() == (Game.profile.lore.size() >= 30), "III: the third ending needs only the records now (%d held)" % Game.profile.lore.size())
	Game.profile.lore = range(30)
	ok(Game.endings().map(func(e): return e.open) == [true, true, true], "III: with them, all three endings are open")
	Game.choose_ending("steward")
	round_trips("after the ending")
	var kept := canon()
	Game.start_legacy_journey()
	econ.play_region("courtyard")
	var after: Array = JSON.parse_string(canon())
	var before: Array = JSON.parse_string(kept)
	before[2].legacy = 1
	ok(JSON.stringify(after) == JSON.stringify(before) and Game.lineage().ending == "steward", "after: a legacy journey leaves the three generations and their ending as they were")
	round_trips("on a legacy journey")
	econ.free()
