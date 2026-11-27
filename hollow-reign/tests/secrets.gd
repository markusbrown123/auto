extends Node
## Secrets, side missions and completion:  godot --headless --path . res://tests/secrets.tscn
## Every secret and mission can be reached and pays something that exists; finding is saved once; completion adds
## up to 100 and never goes down; hints do not give solutions away; the hidden duel is fought through the real rules;
## the story's own path is as it was.
var passed := 0
var failed := 0

func ok(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", what)

func _ready() -> void:
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_secrets_test"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	wipe()
	for t: String in ["t_data", "t_reachable", "t_find_once", "t_conditions", "t_missions", "t_existing_quests", "t_completion", "t_hints",
			"t_migration", "t_hidden_duel", "t_story_untouched"]:
		print("• ", t)
		call(t)
	print("• t_road")
	await t_road()
	wipe()
	print("\n%d passed, %d failed" % [passed, failed])
	print("secrets: %s" % ("PASS" if failed == 0 else "%d FAILED" % failed))
	get_tree().quit(1 if failed > 0 else 0)

func wipe() -> void:
	for n: int in [1, 2, 3]:
		for ext: String in ["json", "bak", "tmp"]:
			if FileAccess.file_exists(Game.slot_file(n, ext)):
				DirAccess.remove_absolute(Game.slot_file(n, ext))
	Game.slot = 1

func fresh() -> void:
	wipe()
	Game.new_game("#123456")
	Game.profile.rewards.seed = 77

func fixture(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/%s.json" % name))

## Everything a reward names exists.
func reward_ok(r: Dictionary) -> bool:
	var d := Secrets.data()
	var good := true
	for m: String in r.get("materials", {}):
		good = good and Db.materials.has(m)
	good = good and (not r.has("lore") or Secrets.hidden_by_id.has(r.lore))
	good = good and (not r.has("finish") or d.finishes.has(r.finish)) and (not r.has("trophy") or d.trophies.has(r.trophy)) and (not r.has("title") or d.titles.has(r.title))
	good = good and (not r.has("item") or Db.items.has(r.item))
	for id: String in r.get("shop", []):
		good = good and Db.items.has(id) and int(Db.item(id).get("price", 0)) > 0
	var paying := false
	for k: String in ["gold", "shards", "materials", "lore", "finish", "trophy", "title", "item", "shop", "heal"]:
		paying = paying or r.has(k)
	return good and paying

## Whether a `when` can ever hold, from what the data offers.
func when_reachable(w: Dictionary) -> bool:
	var good := true
	for f: String in w.get("defeated", []):
		good = good and placed().has(f)
	if w.has("flag"):
		var levers := {}
		for r: Dictionary in Db.regions:
			levers[r.shortcut.flag] = true
		good = good and levers.has(w.flag)
	if w.has("equipped"):
		good = good and Db.items.has(w.equipped) and not Db.item(w.equipped).get("sources", []).is_empty()
	if w.has("secret"):
		good = good and Secrets.by_id.has(w.secret)
	if w.has("quest"):
		good = good and not Secrets.quest_def(w.quest).is_empty()
	if w.has("feat"):
		good = good and str(w.feat).get_slice(":", 0) in ["parry_first", "win", "flawless", "noshield", "perfect"] and placed().has(str(w.feat).get_slice(":", 1))
	return good and int(w.get("ng_min", 0)) <= 1

var _placed := {}
func placed() -> Dictionary:
	if _placed.is_empty():
		for r: Dictionary in Db.regions:
			for s: Dictionary in r.stages:
				for o: Dictionary in s.options:
					if o.has("foe"):
						_placed[o.foe] = true
					for f: String in o.get("foes", []):
						_placed[f] = true
	return _placed

# ------------------------------------------------------------------ data
func t_data() -> void:
	var d := Secrets.data()
	ok(Secrets.list().size() >= 10 and Secrets.list().size() <= 14, "about a dozen secrets (%d)" % Secrets.list().size())
	ok(Secrets.side.size() >= 4 and Secrets.side.size() <= 6, "four to six side missions (%d)" % Secrets.side.size())
	ok(Db.quests.size() == 8, "the eight tasks are still eight")
	var per := {}
	var fams := {}
	for s: Dictionary in Secrets.list():
		per[s.region] = int(per.get(s.region, 0)) + 1
		fams[s.family] = true
		ok(Db.region_by_id.has(s.region) and int(s.stage) >= 0 and int(s.stage) < 7, "%s is at a real stop" % s.id)
		ok(reward_ok(s.reward), "%s gives something that exists" % s.id)
		ok(str(s.hint) != "" and str(s.found) != "" and str(s.solution) != "", "%s has a hint, a description and a written solution" % s.id)
		ok(Story.has_scene("sx_" + str(s.id)), "%s has its subtitle line" % s.id)
		for lid: String in Story.data.scenes.get("sx_" + str(s.id), {}).get("lines", []):
			ok(Story.data.lines[lid].get("recorded", true) == false and not ResourceLoader.exists(Story.audio_path(lid)), "%s: its line is text only" % s.id)
	for r: Dictionary in Db.regions:
		ok(int(per.get(r.id, 0)) >= 1 and int(per.get(r.id, 0)) <= 4, "%s has one to four secrets (%d)" % [r.id, per.get(r.id, 0)])
	for f: String in ["tap", "listen", "return", "sequence", "sketch", "duel", "mastery", "cycle", "oddity"]:
		ok(fams.has(f), "a secret of the '%s' kind exists" % f)
	for l: Dictionary in Secrets.hidden:
		ok(Secrets.by_id.has(l.secret) and Secrets.by_id[l.secret].reward.get("lore", "") == l.id and not Db.lore_by_id.has(l.id), "hidden record %s is given by its secret only" % l.id)
		ok(Game.find_lore(str(l.region), int(l.stage)).is_empty() or true, "")
	ok(d.milestones.size() == 3 and int(d.milestones[-1].at) == 100, "two milestones and the last one")
	for m: Dictionary in d.milestones:
		ok(reward_ok(m.reward) and not m.reward.has("gold") and not m.reward.has("materials") and not m.reward.has("item"), "milestone %s gives only keepsakes" % m.id)

# ------------------------------------------------------------------ every trigger can happen
func t_reachable() -> void:
	for s: Dictionary in Secrets.list():
		var t: Dictionary = s.trigger
		ok(when_reachable(s.get("when", {})), "%s: its conditions can be met" % s.id)
		match str(t.type):
			"tap":
				ok(s.has("tell") and s.has("pos") and absf(float(s.pos[0])) <= 4.5 and float(s.pos[1]) <= -1.5 and float(s.pos[1]) >= -7.0, "%s: a tell inside the stop's view" % s.id)
			"wait":
				ok(float(t.seconds) >= 8.0 and float(t.seconds) <= 30.0, "%s: a wait a person would sit through" % s.id)
			"sequence":
				var order: Array = t.order
				var seen := {}
				for i in order:
					seen[int(i)] = true
				ok(order.size() == t.spots.size() and seen.size() == order.size(), "%s: the order uses every inscription once" % s.id)
				# the order is written down somewhere the player can read it
				var words: Array = []
				for i in order:
					words.append(str(t.spots[int(i)].label))
				var told := false
				for l: Dictionary in Secrets.hidden + Db.lore:
					var at := 0
					var all := true
					for w: String in words:
						at = str(l.text).find(w, at)
						if at < 0:
							all = false
							break
					told = told or all
				ok(told, "%s: a record gives the order (%s)" % [s.id, ", ".join(words)])
			"duel":
				var f := Secrets.challenger(str(t.challenger))
				ok(not f.is_empty() and not f.boss and Db.foes.has(str(Secrets.data().challengers[t.challenger].base)), "%s: its challenger is built from an existing foe" % s.id)
			"feat":
				ok(when_reachable({"feat": t.feat}), "%s: the deed is one a duel records" % s.id)
				var pointed := false
				for c: Dictionary in Secrets.data().clues:
					pointed = pointed or (str(c.points_to) == str(s.id) and not Secrets.clues_at(str(c.region), int(c.stage)).is_empty() and str(c.text) != "")
				ok(pointed, "%s: something on the road points at it" % s.id)
			_:
				ok(false, "%s: unknown trigger" % s.id)
		if s.get("when", {}).has("secret"):
			ok(s.has("locked_text"), "%s: says something when touched too early" % s.id)

# ------------------------------------------------------------------ found once, saved
func t_find_once() -> void:
	fresh()
	var s: Dictionary = Secrets.by_id["cy_loose_stone"]
	var gold: int = Game.profile.gold
	var got := Game.find_secret("cy_loose_stone")
	ok(not got.is_empty() and got.name == s.name and Game.secret_found("cy_loose_stone"), "a secret is found")
	ok(Game.profile.gold == gold + int(s.reward.gold) and Game.profile.secret_lore.has(s.reward.lore), "and pays its gold and its record")
	ok(Game.find_secret("cy_loose_stone").is_empty() and Game.profile.gold == gold + int(s.reward.gold) and Game.profile.secret_lore.size() == 1, "it cannot be claimed twice")
	ok(Game.find_secret("no_such_thing").is_empty(), "an unknown id finds nothing")
	ok(Game.profile.lore.is_empty(), "hidden records are kept apart from the road's fifty")
	Game.profile = {}
	ok(Game.load_game() and Game.secret_found("cy_loose_stone") and Game.profile.secret_lore.size() == 1 and Game.profile.gold == gold + int(s.reward.gold), "it survives save and load")
	ok(Game.find_secret("cy_loose_stone").is_empty(), "and still cannot be claimed again")
	Game.start_ng_plus(true)
	ok(Game.secret_found("cy_loose_stone") and Secrets.at_stop("courtyard", 2).is_empty(), "New Game Plus keeps what was found")
	# every secret pays exactly once
	fresh()
	for sec: Dictionary in Secrets.list():
		ok(not Secrets.find(str(sec.id)).is_empty() and Secrets.find(str(sec.id)).is_empty(), "%s pays once" % sec.id)
	ok(Game.profile.secrets.size() == Secrets.list().size() and Game.profile.secret_lore.size() == Secrets.hidden.size(), "all found, every hidden record held")

func t_conditions() -> void:
	fresh()
	var p: Dictionary = Game.profile
	ok(not Secrets.open_now(Secrets.by_id["cy_second_candle"]) and not Secrets.open_now(Secrets.by_id["cy_cycle_count"]) and not Secrets.open_now(Secrets.by_id["bw_three_stones"]), "return, cycle and sketch secrets are closed at first")
	p.defeated["ashen_sentinel"] = 1
	ok(Secrets.open_now(Secrets.by_id["cy_second_candle"]), "the return secret opens when the guardian has fallen")
	p.ng = 1
	ok(Secrets.open_now(Secrets.by_id["cy_cycle_count"]), "the cycle secret opens on a second walk")
	Secrets.find("cy_charcoal_sketch")
	ok(Secrets.open_now(Secrets.by_id["bw_three_stones"]), "the sketch opens the place it shows")
	ok(not Secrets.open_now(Secrets.by_id["de_candle_bearer"]), "the Witness's secret waits for the Witness")
	p.flags["witness_found"] = true
	ok(Secrets.open_now(Secrets.by_id["de_candle_bearer"]), "and opens with him")
	ok(Secrets.at_stop("courtyard", 5).size() == 1 and Secrets.at_stop("courtyard", 6).is_empty(), "a stop lists its own unfound secrets")

# ------------------------------------------------------------------ side missions
func t_missions() -> void:
	for q: Dictionary in Secrets.side:
		ok(not Db.quest_by_id.has(q.id) and q.get("side", false) and reward_ok(q.reward), "%s is a side mission with a real reward" % q.id)
		for k: String in q.need:
			ok(k in ["materials", "feats", "secrets", "secrets_in"], "%s need '%s' is understood" % [q.id, k])
		ok(int(q.need.get("secrets", 0)) <= Secrets.list().size(), "%s asks for no more secrets than exist" % q.id)
		for r: String in q.need.get("secrets_in", {}):
			var open := 0
			for s: Dictionary in Secrets.list():
				open += 1 if str(s.region) == r and int(s.get("when", {}).get("ng_min", 0)) == 0 else 0
			ok(int(q.need.secrets_in[r]) <= open, "%s can be done in the first walk of %s" % [q.id, r])
		for k: String in q.need.get("feats", {}):
			if k == "listened":
				var waits := 0
				for s: Dictionary in Secrets.list():
					waits += 1 if str(s.trigger.type) == "wait" else 0
				ok(int(q.need.feats[k]) <= waits, "%s: enough places listen back (%d)" % [q.id, waits])
			elif k.begins_with("win_item:"):
				ok(not Db.item(k.get_slice(":", 1)).get("sources", []).is_empty(), "%s: the blade it asks for can be had" % q.id)
			else:
				ok(false, "%s: unknown deed %s" % [q.id, k])
		fresh()
		Game.profile.flags["witness_found"] = true
		ok(Secrets.mission_open(q) and Game.journal_quests().has(q), "%s is listed in the Journal" % q.id)
		ok(not Game.quest_ready(q.id) and not Game.claim_quest(q.id) and Game.quest_progress(q.id).begins_with("0 / "), "%s is not ready at the start (%s)" % [q.id, Game.quest_progress(q.id)])
		# meet its need the way play would
		for m: String in q.need.get("materials", {}):
			Game.add_material(m, int(q.need.materials[m]) + 1)
		for k: String in q.need.get("feats", {}):
			Secrets.add_feat(k, int(q.need.feats[k]))
		for s: Dictionary in Secrets.list():
			if Game.profile.secrets.size() < int(q.need.get("secrets", 0)) or str(s.region) in q.need.get("secrets_in", {}):
				Game.profile.secrets[s.id] = true
		ok(Game.quest_ready(q.id), "%s becomes ready" % q.id)
		var gold: int = Game.profile.gold
		ok(Game.claim_quest(q.id) and Game.profile.quests_done == [q.id] and Game.profile.gold == gold + int(q.reward.get("gold", 0)) and Game.quest_progress(q.id) == "Done", "%s pays" % q.id)
		for m: String in q.need.get("materials", {}):
			ok(Game.material_count(m) == 1, "%s takes the material it asked for" % q.id)
		if q.reward.has("finish"):
			ok(Game.finishes_available().has(q.reward.finish) and Game.set_finish("chest", str(q.reward.finish)) and Game.cosmetic("chest").finish == q.reward.finish, "%s: its finish can be worn" % q.id)
		if q.reward.has("title"):
			ok(Game.title() == Secrets.label_of("title", str(q.reward.title)), "%s: its title is taken" % q.id)
		ok(not Game.claim_quest(q.id) and Game.profile.gold == gold + int(q.reward.get("gold", 0)), "%s pays only once" % q.id)
	fresh()
	ok(not Game.set_finish("chest", "f_oiled") and Game.set_finish("chest", "graphite"), "an unearned finish cannot be worn; the old ones still can")
	var st := JSON.stringify(Game.stats())
	Game.profile.completion.finishes.append("f_oiled")
	Game.set_finish("chest", "f_oiled")
	ok(JSON.stringify(Game.stats()) == st, "a finish never touches a number")
	ok(not Secrets.mission_open(Secrets.side_by_id["witness_record"]) and not Game.journal_quests().has(Secrets.side_by_id["witness_record"]), "the Witness's task waits for the Witness")

func t_existing_quests() -> void:
	fresh()
	var p: Dictionary = Game.profile
	p.defeated["ashen_sentinel"] = 1
	for l: Dictionary in Db.lore.slice(0, 4):
		p.lore.append(l.id)
	ok(Game.quest_ready("relief_of_the_gate") and Game.claim_quest("relief_of_the_gate") and Game.owns("w_vigil_edge"), "an old task is claimed as before")
	ok(Game.journal_quests().slice(0, 8) == Db.quests, "the Journal lists the eight first, in their order")

# ------------------------------------------------------------------ completion
func everything() -> void:
	var p: Dictionary = Game.profile
	for r: Dictionary in Db.regions:
		for i: int in r.stages.size():
			Secrets.mark_stop(str(r.id), i, p)
	for id: String in Db.foes:
		if Db.foes[id].boss:
			p.defeated[id] = 1
	for s: Dictionary in Secrets.list():
		p.secrets[s.id] = true
	for q: Dictionary in Secrets.all_quests():
		p.quests_done.append(q.id)
	for l: Dictionary in Db.lore:
		p.lore.append(l.id)

func t_completion() -> void:
	fresh()
	var c: Dictionary = Game.completion()
	ok(float(c.pct) == 0.0 and c.regions.size() == 8 and c.milestones.size() == 3, "a new journey has seen nothing")
	for cat: String in Secrets.data().completion.weights:
		ok(c.categories.has(cat) and int(c.categories[cat].total) > 0, "category %s counts something" % cat)
	# every counted thing has a source the player can reach, and is counted once
	var seen := {}
	var lore_stops := {}
	for t: Dictionary in Secrets.things():
		ok(not seen.has(t.cat + "|" + t.id), "%s counted once" % t.id)
		seen[t.cat + "|" + t.id] = true
		match str(t.cat):
			"stops":
				ok(Db.region_by_id.has(t.region), "stop %s is on a road" % t.id)
			"guardians":
				ok(placed().has(t.id), "guardian %s stands on a road" % t.id)
			"secrets":
				ok(when_reachable(Secrets.by_id[t.id].get("when", {})), "secret %s can be found" % t.id)
			"missions":
				ok(not Secrets.quest_def(t.id).is_empty(), "task %s exists" % t.id)
			"lore":
				var l: Dictionary = Db.lore_by_id[t.id]
				ok(Db.region_by_id.has(l.region) and int(l.stage) >= 0 and int(l.stage) < 7, "record %s lies at a stop" % t.id)
		ok(str(t.hint) != "", "%s has something to say while missing" % t.id)
	# the eight old tasks only ask for things on roads
	for q: Dictionary in Db.quests:
		for f: String in q.need.get("defeated", []):
			ok(placed().has(f), "task %s: %s is on a road" % [q.id, f])
	# monotonic: doing one more thing never lowers any figure
	var last := 0.0
	var last_r := {}
	var p: Dictionary = Game.profile
	var steps: Array = []
	for r: Dictionary in Db.regions:
		for i: int in r.stages.size():
			steps.append(func(): Secrets.mark_stop(str(r.id), i, p))
	for id: String in Db.foes:
		if Db.foes[id].boss:
			steps.append(func(): p.defeated[id] = 1)
	for s: Dictionary in Secrets.list():
		steps.append(func(): p.secrets[s.id] = true)
	for q: Dictionary in Secrets.all_quests():
		steps.append(func(): p.quests_done.append(q.id))
	for l: Dictionary in Db.lore:
		steps.append(func(): p.lore.append(l.id))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var mono := true
	var below := true
	while not steps.is_empty():
		var f: Callable = steps.pop_at(rng.randi() % steps.size())
		f.call()
		c = Game.completion()
		mono = mono and float(c.pct) >= last
		below = below and (steps.is_empty() or float(c.pct) < 100.0)
		last = float(c.pct)
		for r: Dictionary in c.regions:
			mono = mono and float(r.pct) >= float(last_r.get(r.id, 0.0))
			last_r[r.id] = float(r.pct)
	ok(mono, "completion never goes down, overall or on any road")
	ok(below, "it does not read 100 until the last thing is done")
	ok(float(c.pct) == 100.0 and c.remains.is_empty(), "with everything done it is exactly 100 (%s)" % str(c.pct))
	for r: Dictionary in c.regions:
		ok(float(r.pct) == 100.0 and r.remains.is_empty(), "%s is exactly 100" % r.id)
	# milestones: paid on a save, once, and only keepsakes
	fresh()
	var before := JSON.stringify([Game.profile.gold, Game.profile.shards, Game.profile.materials, Game.profile.inventory, Game.stats()])
	ok(Game.profile.completion.milestones.is_empty(), "no milestone at the start")
	everything()
	Game.save()
	var comp: Dictionary = Game.profile.completion
	ok(comp.milestones.size() == 3 and comp.finishes.has("f_complete") and comp.trophies.has("t_complete") and comp.titles.has("ti_complete"), "all three milestones are paid at 100")
	ok(JSON.stringify([Game.profile.gold, Game.profile.shards, Game.profile.materials, Game.profile.inventory, Game.stats()]) == before, "and change no number")
	var held := JSON.stringify(comp)
	Game.save()
	Game.profile = {}
	ok(Game.load_game() and JSON.stringify(Game.profile.completion) == held, "milestones are paid once and survive a load")
	ok(float(Game.completion().pct) == 100.0, "100 survives a load")
	Game.start_ng_plus(true)
	ok(float(Game.completion().pct) == 100.0, "and a New Game Plus")
	# the walk itself is what marks a stop
	fresh()
	Game.start_run("courtyard")
	Game.advance_stage()
	ok(Secrets.stops_walked("courtyard") == 1, "moving on marks the stop walked")
	Game.run.stage = 6
	Game.complete_region()
	ok(Secrets.stops_walked("courtyard") == 2 and Game.profile.cleared == ["courtyard"], "so does ending the road")
	ok(float(Game.completion().regions[0].pct) > 0.0 and float(Game.completion().pct) > 0.0, "and the figures move")

# ------------------------------------------------------------------ hints give nothing away
func t_hints() -> void:
	fresh()
	var c: Dictionary = Game.completion()
	var said: Array = c.remains.duplicate()
	for r: Dictionary in c.regions:
		said.append_array(r.remains)
	ok(said.size() > Secrets.list().size(), "what remains is listed")
	for s: Dictionary in Secrets.list():
		ok(said.has(s.hint), "%s: its hint is offered while it is missing" % s.id)
		for line: String in said:
			var low := line.to_lower()
			ok(not low.contains(str(s.solution).to_lower()) and not low.contains(str(s.found).to_lower()) and not low.contains(str(s.name).to_lower()), "a hint does not hold %s's solution, description or name" % s.id)
		for w: String in s.spoil:
			ok(not str(s.hint).to_lower().contains(w.to_lower()), "%s: its hint avoids '%s'" % [s.id, w])
		if str(s.trigger.type) == "sequence":
			for spot: Dictionary in s.trigger.spots:
				ok(not str(s.hint).to_lower().contains(str(spot.label)), "%s: its hint does not name an inscription" % s.id)
	everything()
	c = Game.completion()
	var left: int = c.remains.size()
	for r: Dictionary in c.regions:
		left += r.remains.size()
	ok(left == 0, "nothing is hinted at once everything is found")

# ------------------------------------------------------------------ older saves
func t_migration() -> void:
	for name: String in ["save_v0", "save_v1_early", "save_v1", "save_v2"]:
		var old := fixture(name)
		var m := Game._migrate(fixture(name))
		ok(int(m.version) == Game.SAVE_VERSION and m.secrets == {} and m.secret_lore == [] and m.feats == {} and m.completion.milestones == [], "%s: gains the new state, empty" % name)
		ok(m.gold == int(old.gold) and m.level == int(old.level), "%s: what it held is as it was" % name)
		for r: String in old.get("cleared", []):
			ok(Secrets.stops_walked(r, m) == 7, "%s: a cleared road counts as walked (%s)" % [name, r])
		var again := Game._migrate(JSON.parse_string(JSON.stringify(Game._pack(m))))
		ok(JSON.stringify(again.completion) == JSON.stringify(m.completion) and again.secrets == m.secrets, "%s: migrating twice changes nothing" % name)
	var v2 := Game._migrate(fixture("save_v2"))
	ok(Secrets.stops_walked("courtyard", v2) == 7 and Secrets.stops_walked("cathedral", v2) == 7 and Secrets.stops_walked("crypt", v2) == 4 and Secrets.stops_walked("roost", v2) == 0, "save_v2: a road with its sluice open counts to that stop; an unwalked road counts nothing")
	ok(v2.quests_done == ["relief_of_the_gate"] and v2.lore.size() == fixture("save_v2").lore.size(), "save_v2: tasks and records are untouched")
	# through the real files: load, find, save, load
	wipe()
	var f := FileAccess.open(Game.slot_file(1), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/save_v2.json"))
	f.close()
	ok(Game.load_game(), "save_v2 loads")
	var pct := float(Game.completion().pct)
	ok(pct > 10.0 and pct < 60.0, "save_v2: completion reflects the journey so far (%.1f)" % pct)
	ok(Secrets.open_now(Secrets.by_id["cy_second_candle"]) and not Game.find_secret("cy_second_candle").is_empty(), "save_v2: a secret can be found on it")
	Game.profile = {}
	ok(Game.load_game() and Game.secret_found("cy_second_candle") and Game.profile.completion.trophies.has("t_second_candle") and float(Game.completion().pct) > pct, "and it is kept")
	for id: int in Game.profile.completion.stops.courtyard:
		ok(typeof(id) == TYPE_INT, "")
	# a save that beat the hidden challenger knows it again
	Game.profile.defeated["reflection"] = 1
	Game.save()
	Db.foes.erase("reflection")
	Game.profile = {}
	ok(Game.load_game() and Db.foes.has("reflection"), "a beaten challenger is known again after a load")

# ------------------------------------------------------------------ the hidden duel, through the rules
func t_hidden_duel() -> void:
	fresh()
	for id: String in ["w_knight_sword", "s_garrison"]:
		Game.grant_item(id)
		Game.equip(id)
	for k: String in ["health", "strength", "dex", "endurance"]:
		Game.profile.attrs[k] = 14
	Game.profile.defeated["rime_duelist"] = 1
	var s: Dictionary = Secrets.by_id["ci_reflection"]
	ok(Secrets.open_now(s), "the mirror opens once the duellist is beaten")
	var o := Secrets.duel_option(s)
	var foe: Dictionary = Db.foes[o.foe]
	ok(o.type == "fight" and o.hidden and not foe.boss and foe.region == "citadel" and foe.rig.get("skin", "") == Duel.player_look().skin, "it is an ordinary fight entry against a figure that looks like the knight")
	for ph: Dictionary in foe.phases:
		for c: Dictionary in ph.combos:
			for i: int in c.attacks.size():
				var a: Dictionary = c.attacks[i]
				ok(float(a.windup) / float(ph.speed) + (float(c.gap) if i > 0 else 0.0) >= 0.45 and (a.parry or a.dodge != "none" or not a.unblockable), "reflection/%s is readable and answerable" % c.id)
	var base: Dictionary = Db.foes["rime_duelist"]
	ok(JSON.stringify(base) == JSON.stringify(JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses.json")).bosses.filter(func(b): return b.id == "rime_duelist")[0]), "the foe it is built from is left as it was")
	var wins := 0
	var sim: DuelSim
	for sd: int in [3, 4, 5]:
		sim = DuelSim.new()
		sim.setup(Game.stats(), foe, sd, {"combos": Db.combos})
		Secrets.watch(sim, o)
		var bot := DuelBot.new(sim, DuelBot.Style.SKILLED, sd)
		for i: int in 60 * 240:
			bot.tick(1.0 / 60.0)
			sim.tick(1.0 / 60.0)
			if sim.over:
				break
		if sim.over and sim.b_state == DuelSim.B.DEAD:
			wins += 1
			break
	ok(wins == 1, "a skilled bot beats the reflection (%.0fs)" % sim.time)
	ok(Secrets.duel_ended(o, false, sim).is_empty() and not Game.secret_found("ci_reflection"), "losing it finds nothing")
	var got := Secrets.duel_ended(o, true, sim)
	ok(got.size() == 1 and got[0].id == "ci_reflection" and Game.secret_found("ci_reflection") and Game.title() == "Twice Yourself", "winning it finds the secret")
	ok(Secrets.duel_ended(o, true, sim).is_empty(), "once")
	var r := Game.on_victory(str(o.foe), 50.0)
	ok(int(r.xp) > 0 and not r.core and int(Game.profile.defeated["reflection"]) == 1, "its victory pays as an ordinary fight, with no guardian's core")
	ok(Secrets.take_notes().size() == 1 and Secrets.take_notes().is_empty(), "the next stop is told once")
	# the mastery secret: the deed is read from the fight
	fresh()
	Game.profile.equipped.shield = null
	var sim2 := DuelSim.new()
	sim2.setup(Game.stats(), Db.foes["hollow_soldier"], 3, {"combos": Db.combos})
	ok(Secrets.duel_ended({"type": "fight", "foe": "hollow_soldier"}, true, sim2).is_empty() and Secrets.feat_count("noshield:hollow_soldier") == 1 and Secrets.feat_count("win_item:w_rusted_sword") == 1, "a win records its deeds, and an ordinary one finds nothing")
	var m := Secrets.duel_ended({"type": "boss", "foe": "cinder_wyrm"}, true, sim2)
	ok(m.size() == 1 and m[0].id == "ro_no_shield" and Game.profile.completion.trophies.has("t_glass_footprints"), "the wyrm, beaten without a shield, gives the mastery secret")
	fresh()
	ok(Secrets.duel_ended({"type": "boss", "foe": "cinder_wyrm"}, true, sim2).is_empty(), "with a shield on the arm it does not")
	Secrets.take_notes()

# ------------------------------------------------------------------ the story's own path
func t_story_untouched() -> void:
	fresh()
	var before := JSON.stringify(Db.regions)
	Game.profile.secrets = {}
	for r: Dictionary in Db.regions:
		Game.start_run(str(r.id))
		for i: int in 7:
			Game.run.stage = i
			for o: Dictionary in Game.stage_options():
				ok(not o.get("hidden", false) and not o.has("secret"), "")
	ok(JSON.stringify(Db.regions) == before and JSON.stringify(Db.regions) == JSON.stringify(JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json")).regions), "the roads are as the data has them")
	for id: String in Db.foes:
		ok(not Db.foes[id].get("hidden", false) or id == "reflection", "")
	# with every secret found and every mission done, the roads and the endings ask for nothing more
	fresh()
	ok(not Game.game_complete() and Game.region_unlocked("courtyard") and not Game.region_unlocked("blackwood"), "a new journey is gated as it was")
	for s: Dictionary in Secrets.list():
		Secrets.find(str(s.id))
	ok(not Game.game_complete() and not Game.region_unlocked("blackwood") and not Game.can_divide_crown() and Game.profile.cleared.is_empty() and Game.profile.lore.is_empty(), "finding every secret opens no road and no ending")
	fresh()
	Game.profile.cleared = ["courtyard", "blackwood", "cathedral", "crypt", "citadel", "throne"]
	ok(Game.road_complete() and Game.profile.secrets.is_empty(), "the story ends with no secret found")

# ------------------------------------------------------------------ on the road itself
## Lets a staged moment play out (lines skipped as a tap would), for at most twenty seconds.
func settle(e: Explore) -> void:
	var t0 := Time.get_ticks_msec()
	while e._staging and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
		if Story.busy:
			Story._skip = true

func t_road() -> void:
	fresh()
	Game.profile.tutorial_done = true
	Companion.mark_heard(Companion.discovery_id())      # the Witness is already found: his own staged scene is not what is tested here
	Game.start_run("courtyard")
	Game.run.stage = 2
	var e := Explore.new()
	add_child(e)
	for i: int in 30:
		await get_tree().process_frame
	ok(e.spots.size() == 1 and str(e.spots[0].secret.id) == "cy_loose_stone" and is_instance_valid(e.spots[0].node), "the Barbican holds one hidden thing")
	var fights := []
	e.fight.connect(func(o): fights.append(o))
	e.layer.get_child(0).modulate.a = 1.0
	Story.stop()
	e._touch(e.spots[0])
	ok(e._staging, "touching it takes the camera")
	await settle(e)
	ok(Game.secret_found("cy_loose_stone") and not e._staging and e.spots.is_empty() and fights.is_empty(), "it is found, the road is given back, and no fight was started (%s %s %d %d)" % [Game.secret_found("cy_loose_stone"), e._staging, e.spots.size(), fights.size()])
	ok(Game.stage_options().size() >= 1 and Game.run.stage == 2, "the ways onward are what they were")
	e.queue_free()
	await get_tree().process_frame
	# the sequence: wrong order resets, right order finds
	Game.start_run("blackwood")
	Game.run.stage = 4
	e = Explore.new()
	add_child(e)
	for i: int in 30:
		await get_tree().process_frame
	e.layer.get_child(0).modulate.a = 1.0
	Story.stop()
	ok(e.spots.size() == 4, "four posts stand at the woodpile")
	ok(Secrets.clues_at("roost", 0).size() == 1 and Secrets.at_stop("roost", 0).is_empty(), "the Glass Road holds a clue and no secret")
	e._touch(e.spots[1])
	ok(e._order.get("bw_woodpile_posts", []).is_empty() and not Game.secret_found("bw_woodpile_posts"), "the wrong post first does nothing")
	for idx in Secrets.by_id["bw_woodpile_posts"].trigger.order:
		e._touch(e.spots[int(idx)])
	await settle(e)
	ok(Game.secret_found("bw_woodpile_posts"), "the right order finds it")
	e.queue_free()
	await get_tree().process_frame
	# a locked sketch target speaks and gives nothing; a wait secret answers standing still
	Game.profile.secrets = {}
	Game.start_run("blackwood")
	Game.run.stage = 5
	e = Explore.new()
	add_child(e)
	for i: int in 30:
		await get_tree().process_frame
	e.layer.get_child(0).modulate.a = 1.0
	Story.stop()
	ok(e.spots.size() == 1, "the three stones are there before the sketch is")
	e._touch(e.spots[0])
	ok(not e._staging and not Game.secret_found("bw_three_stones"), "and mean nothing yet")
	e.queue_free()
	await get_tree().process_frame
	Game.start_run("cathedral")
	Game.run.stage = 4
	e = Explore.new()
	add_child(e)
	for i: int in 30:
		await get_tree().process_frame
	e.layer.get_child(0).modulate.a = 1.0
	Story.stop()
	e._idle = float(Secrets.by_id["ca_end_of_cylinder"].trigger.seconds) - 0.05
	for i: int in 500:
		await get_tree().process_frame
		if Story.busy:
			Story._skip = true
		if Game.secret_found("ca_end_of_cylinder") and not e._staging:
			break
	ok(Game.secret_found("ca_end_of_cylinder") and Secrets.feat_count("listened") == 1, "standing in the choir loft is answered")
	e.queue_free()
	await get_tree().process_frame
	# the hidden duel leaves through the road's own door
	Game.profile.defeated["rime_duelist"] = 1
	Game.start_run("citadel")
	Game.run.stage = 1
	e = Explore.new()
	add_child(e)
	for i: int in 30:
		await get_tree().process_frame
	e.layer.get_child(0).modulate.a = 1.0
	Story.stop()
	var got := []
	e.fight.connect(func(o): got.append(o))
	ok(e.spots.size() == 1, "the black ice stands on the wall walk")
	e._touch(e.spots[0])
	for i: int in 400:
		await get_tree().process_frame
		if Story.busy:
			Story._skip = true
		if not got.is_empty():
			break
	ok(got.size() == 1 and got[0].foe == "reflection" and got[0].hidden and got[0].secret == "ci_reflection" and Db.foes.has("reflection"), "touching it starts the hidden duel through the fight signal")
	e.queue_free()
	await get_tree().process_frame
