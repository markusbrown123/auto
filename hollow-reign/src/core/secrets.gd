class_name Secrets
extends RefCounted
## Secrets, side missions and completion (docs/SECRETS_AND_COMPLETION.md). Rules only: what exists, when it can be
## found, what it gives, and how much of the kingdom has been seen. Content is data/secrets.json, the "side" list in
## data/quests.json and the "hidden" list in data/lore.json, all written by tools/gen_secrets.py.
##
## State lives in the profile: `secrets` {id: true}, `secret_lore` [hidden record ids], `feats` {key: count} and
## `completion` {stops: {region: [stop indexes walked]}, milestones, finishes, trophies, titles, title, shop}.
## None of it is touched by New Game Plus.

static var _d: Dictionary = {}
static var by_id: Dictionary = {}
static var side: Array = []
static var side_by_id: Dictionary = {}
static var hidden: Array = []
static var hidden_by_id: Dictionary = {}
static var notes: Array = []          ## what was found away from a road stop (in a duel): shown at the next stop
static var _seen := {}                ## what has been observed of the duel in progress

# ================================================================ data
static func data() -> Dictionary:
	if _d.is_empty():
		_d = JSON.parse_string(FileAccess.get_file_as_string("res://data/secrets.json"))
		for s: Dictionary in _d.secrets:
			by_id[s.id] = s
		side = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json")).get("side", [])
		for q: Dictionary in side:
			side_by_id[q.id] = q
		hidden = JSON.parse_string(FileAccess.get_file_as_string("res://data/lore.json")).get("hidden", [])
		for l: Dictionary in hidden:
			hidden_by_id[l.id] = l
	return _d

static func list() -> Array:
	return data().secrets

static func blank() -> Dictionary:
	return {"stops": {}, "milestones": [], "finishes": [], "trophies": [], "titles": [], "title": "", "shop": []}

## Makes sure a profile carries every key of the layer (a profile built by hand in a test or a dev screen may not).
static func ensure(p: Dictionary) -> void:
	for k: String in ["secrets", "feats"]:
		if not (p.get(k) is Dictionary):
			p[k] = {}
	if not (p.get("secret_lore") is Array):
		p["secret_lore"] = []
	if not (p.get("completion") is Dictionary):
		p["completion"] = {}
	var base := blank()
	for k: String in base:
		if not p.completion.has(k):
			p.completion[k] = base[k]

static func found(id: String, p: Dictionary = Game.profile) -> bool:
	return p.get("secrets", {}).has(id)

static func feat_count(key: String, p: Dictionary = Game.profile) -> int:
	return int(p.get("feats", {}).get(key, 0))

static func add_feat(key: String, n: int = 1, p: Dictionary = Game.profile) -> void:
	ensure(p)
	p.feats[key] = feat_count(key, p) + n

# ================================================================ conditions
## Whether the conditions under `when` hold: defeated [foe ids], flag, equipped (item id), witness, ng_min,
## secret (another secret already found), quest (a task claimed), feat (a deed done at least once).
static func cond(when: Dictionary, p: Dictionary = Game.profile) -> bool:
	for f: String in when.get("defeated", []):
		if not p.get("defeated", {}).has(f):
			return false
	if when.has("flag") and not p.get("flags", {}).has(when.flag):
		return false
	if when.has("equipped") and not p.equipped.values().has(when.equipped):
		return false
	if when.get("witness", false) and not p.get("flags", {}).has("witness_found"):
		return false
	if int(p.get("ng", 0)) < int(when.get("ng_min", 0)):
		return false
	if when.has("secret") and not found(str(when.secret), p):
		return false
	if when.has("quest") and not p.get("quests_done", []).has(when.quest):
		return false
	if when.has("feat") and feat_count(str(when.feat), p) <= 0:
		return false
	return true

static func open_now(s: Dictionary, p: Dictionary = Game.profile) -> bool:
	return cond(s.get("when", {}), p)

## The secrets a road stop can still give: not yet found, and found at a stop (a deed in a duel is not).
static func at_stop(region: String, stage: int, p: Dictionary = Game.profile) -> Array:
	var out: Array = []
	for s: Dictionary in list():
		if str(s.region) == region and int(s.stage) == stage and not found(str(s.id), p) and str(s.trigger.type) != "feat":
			out.append(s)
	return out

## Things at a stop that can be touched and only say something (the tell of a secret that is earned elsewhere).
static func clues_at(region: String, stage: int) -> Array:
	var out: Array = []
	for c: Dictionary in data().get("clues", []):
		if str(c.region) == region and int(c.stage) == stage:
			out.append(c)
	return out

## The id of the subtitle scene of a secret ("" when its speaker cannot speak yet).
static func line_scene(s: Dictionary) -> String:
	var id := "sx_" + str(s.id)
	if not Story.has_scene(id):
		return ""
	if str(s.say.speaker) == "witness" and not Game.profile.get("flags", {}).has("witness_found"):
		return ""
	return id

# ================================================================ finding and paying
## Pays a reward of this layer and returns the lines a screen shows for it. Gold, shards, materials, an item
## (never a duplicate: gold instead), a hidden record, a finish, a trophy for the sanctuary, a title, a blade
## Orren will stock, a rest.
static func grant(reward: Dictionary, p: Dictionary = Game.profile) -> Array:
	ensure(p)
	var lines: Array = []
	if int(reward.get("gold", 0)) > 0:
		p.gold += int(reward.gold)
		lines.append("%d gold" % int(reward.gold))
	if int(reward.get("shards", 0)) > 0:
		p.shards += int(reward.shards)
		lines.append("%d shard%s" % [int(reward.shards), "" if int(reward.shards) == 1 else "s"])
	for m: String in reward.get("materials", {}):
		p.materials[m] = int(p.materials.get(m, 0)) + int(reward.materials[m])
		lines.append("%d %s" % [int(reward.materials[m]), Db.material_name(m)])
	if reward.has("lore") and hidden_by_id.has(reward.lore) and not p.secret_lore.has(reward.lore):
		p.secret_lore.append(reward.lore)
		lines.append("Record  ·  " + str(hidden_by_id[reward.lore].title))
	for pair: Array in [["finish", "finishes", "Finish"], ["trophy", "trophies", "For the sanctuary"], ["title", "titles", "Title"]]:
		if reward.has(pair[0]) and not p.completion[pair[1]].has(reward[pair[0]]):
			p.completion[pair[1]].append(reward[pair[0]])
			lines.append("%s  ·  %s" % [pair[2], label_of(str(pair[0]), str(reward[pair[0]]))])
	if reward.has("title") and str(p.completion.title) == "":
		p.completion.title = reward.title
	for id: String in reward.get("shop", []):
		if not p.completion.shop.has(id):
			p.completion.shop.append(id)
			lines.append("Orren will sell  ·  " + str(Db.item(id).get("name", id)))
	if reward.get("heal", false) and not Game.run.is_empty():
		Game.run.hp = Game.stats().max_hp
		lines.append("Wounds close.")
	return lines

static func label_of(kind: String, id: String) -> String:
	match kind:
		"finish": return str(data().finishes.get(id, id))
		"trophy": return str(data().trophies.get(id, {}).get("name", id))
		"title": return str(data().titles.get(id, id))
	return id

## Marks a secret found and pays it, once. Returns {} when it is unknown or already found, else
## {id, name, found (the line of description), lines (the reward, as text)}.
static func find(id: String) -> Dictionary:
	data()
	var p: Dictionary = Game.profile
	if p.is_empty() or not by_id.has(id) or found(id, p):
		return {}
	ensure(p)
	var s: Dictionary = by_id[id]
	p.secrets[id] = true
	if str(s.trigger.type) == "wait":
		add_feat("listened", 1, p)
	var out := {"id": id, "name": str(s.name), "found": str(s.found), "lines": grant(s.reward, p)}
	Game.save()
	Game.profile_changed.emit()
	return out

# ================================================================ hidden duels
## The foe of a hidden duel: an existing foe's rig, model and patterns, retuned (and, for the mirror, dressed and
## weighted from the knight as they stand now). It is added to Db.foes when asked for, so the ordinary duel path
## can fight it; it is never a guardian and never on a road's list.
static func challenger(id: String) -> Dictionary:
	var c: Dictionary = data().challengers.get(id, {})
	if c.is_empty() or not Db.foes.has(str(c.base)):
		return {}
	var f: Dictionary = Db.foes[str(c.base)].duplicate(true)
	f.id = id
	f.name = str(c.name)
	f.title = str(c.get("title", ""))
	f.boss = false
	f["hidden"] = true
	f.hp = roundi(float(f.hp) * float(c.get("hp", 1.0)))
	f.xp = roundi(float(f.xp) * float(c.get("xp", 1.0)))
	f.gold = roundi(float(f.gold) * float(c.get("gold", 1.0)))
	f.loot = []
	f["traits"] = c.get("traits", {}).duplicate()
	if int(c.get("phases", 0)) > 0:
		f.phases = f.phases.slice(0, int(c.phases))
	var dmg := 1.0
	if c.get("mirror", false) and not Game.profile.is_empty():
		# your own loadout: it looks as you look, takes about as long to cut down as you would, and hits like your blade
		var st := Game.stats()
		f.rig = Duel.player_look()
		f.rig["witness"] = false
		f.cls = "Reflection"          # no class model of that name: the rig keeps the knight's own
		f.hp = roundi(clampf(float(st.max_hp) * 5.0, float(f.hp) * 0.6, float(f.hp) * 1.4))
		var base_dmg := float(f.punish.dmg)
		dmg = clampf(float(st.get("damage", base_dmg)) * 0.9, base_dmg * 0.7, base_dmg * 1.3) / maxf(1.0, base_dmg)
	for k: String in c.get("rig", {}):
		f.rig[k] = c.rig[k]
	f.punish.dmg = roundi(float(f.punish.dmg) * dmg)
	for ph: Dictionary in f.phases:
		var slowest := 100.0          # a blow must stay readable however it is tuned (tests: 0.45 s)
		for combo: Dictionary in ph.combos:
			for i: int in combo.attacks.size():
				var a: Dictionary = combo.attacks[i]
				a.dmg = roundi(float(a.dmg) * dmg)
				slowest = minf(slowest, float(a.windup) + (float(combo.gap) if i > 0 else 0.0))
		ph.speed = minf(float(ph.speed) * float(c.get("speed", 1.0)), slowest / 0.46)
	Db.foes[id] = f
	return f

## The way-onward entry a hidden duel is started with (the same shape the road's own fights use).
static func duel_option(s: Dictionary) -> Dictionary:
	var id := str(s.trigger.challenger)
	challenger(id)
	return {"type": "fight", "foe": id, "label": str(s.name), "hint": "", "hidden": true, "secret": str(s.id)}

## Called as a duel begins: notes how the first blow of the foe is met.
static func watch(sim: DuelSim, _o: Dictionary) -> void:
	_seen = {"first": ""}
	var seen := _seen
	sim.ev.connect(func(n: StringName, e: Dictionary):
		if n == &"boss_strike" and str(seen.first) == "":
			seen.first = str(e.get("result", "")))

## Called when a duel is decided, before its rewards: records the deeds missions and secrets ask about, and finds
## whatever that fight was hiding. Returns the secrets found ([{id, name, found, lines}]); they are also kept in
## `notes` for the next road stop to show.
static func duel_ended(o: Dictionary, won: bool, sim: DuelSim) -> Array:
	data()
	var p: Dictionary = Game.profile
	var out: Array = []
	if p.is_empty():
		return out
	ensure(p)
	var foe := str(o.get("foe", ""))
	if str(_seen.get("first", "")) == "parried":
		add_feat("parry_first:" + foe, 1, p)
	_seen = {}
	add_feat("perfect_parries", int(sim.stats.get("perfect_parries", 0)), p)
	if not won:
		return out
	add_feat("win:" + foe, 1, p)
	var w: Dictionary = Db.item(str(p.equipped.weapon)) if p.equipped.weapon != null else {}
	if not w.is_empty():
		add_feat("win_item:" + str(w.id), 1, p)
		add_feat("win_cls:" + str(w.cls), 1, p)
	if int(sim.stats.get("hits_taken", 0)) == 0:
		add_feat("flawless:" + foe, 1, p)
		add_feat("flawless_wins", 1, p)
	if p.equipped.get("shield") == null:
		add_feat("noshield:" + foe, 1, p)
	if int(sim.stats.get("parries", 0)) >= 3 and int(sim.stats.parries) == int(sim.stats.get("perfect_parries", 0)):
		add_feat("perfect:" + foe, 1, p)
	var ids: Array = []
	if o.has("secret"):
		ids.append(str(o.secret))
	for s: Dictionary in list():
		if str(s.trigger.type) == "feat" and feat_count(str(s.trigger.feat), p) > 0 and open_now(s, p):
			ids.append(str(s.id))
	for id: String in ids:
		var got := find(id)
		if not got.is_empty():
			out.append(got)
			notes.append(got)
	return out

static func take_notes() -> Array:
	var out := notes
	notes = []
	return out

# ================================================================ side missions
## A task by id: one of the eight in Db.quests, or a side mission. {} when unknown.
static func quest_def(id: String) -> Dictionary:
	data()
	return Db.quest_by_id.get(id, side_by_id.get(id, {}))

## Whether a side mission has been offered yet (`after`: cleared, secret, lore, defeated, witness).
static func mission_open(q: Dictionary, p: Dictionary = Game.profile) -> bool:
	var a: Dictionary = q.get("after", {})
	if a.has("cleared") and not (p.cleared.has(a.cleared) or stops_walked(str(a.cleared), p) >= 7):
		return false
	if a.has("lore") and not p.lore.has(a.lore):
		return false
	if a.has("defeated") and not p.defeated.has(a.defeated):
		return false
	return cond({"secret": a.secret} if a.has("secret") else {}, p) and cond({"witness": a.get("witness", false)}, p)

## Everything the Journal lists under Tasks: the eight, then the side missions offered so far (or already done).
static func journal_quests(p: Dictionary = Game.profile) -> Array:
	data()
	var out: Array = Db.quests.duplicate()
	for q: Dictionary in side:
		if mission_open(q, p) or p.get("quests_done", []).has(q.id):
			out.append(q)
	return out

static func all_quests() -> Array:
	data()
	return Db.quests + side

## The conditions only side missions use, as [have, need, noun] (Game._quest_parts adds them to its own).
static func quest_parts(need: Dictionary, p: Dictionary = Game.profile) -> Array:
	var parts: Array = []
	for m: String in need.get("materials", {}):
		parts.append([mini(int(p.get("materials", {}).get(m, 0)), int(need.materials[m])), int(need.materials[m]), Db.material_name(m)])
	for k: String in need.get("feats", {}):
		parts.append([mini(feat_count(k, p), int(need.feats[k])), int(need.feats[k]), feat_noun(k)])
	if need.has("secrets"):
		parts.append([mini(p.get("secrets", {}).size(), int(need.secrets)), int(need.secrets), "secrets"])
	for r: String in need.get("secrets_in", {}):
		parts.append([mini(count_secrets(r, p)[0], int(need.secrets_in[r])), int(need.secrets_in[r]), "secrets here"])
	return parts

static func feat_noun(key: String) -> String:
	if key.begins_with("win_item:"):
		return "wins with " + str(Db.item(key.get_slice(":", 1)).get("name", "it"))
	return {"listened": "places heard out", "flawless_wins": "unmarked wins", "perfect_parries": "perfect parries"}.get(key, "deeds")

## What claiming takes and gives beyond gold, shards and an item (Game.claim_quest pays those).
static func settle_quest(q: Dictionary, p: Dictionary = Game.profile) -> void:
	for m: String in q.need.get("materials", {}):
		p.materials[m] = maxi(0, int(p.materials.get(m, 0)) - int(q.need.materials[m]))
	var extra: Dictionary = q.reward.duplicate()
	for k: String in ["gold", "shards", "item"]:
		extra.erase(k)
	grant(extra, p)

# ================================================================ completion
static func stops_walked(region: String, p: Dictionary = Game.profile) -> int:
	return p.get("completion", {}).get("stops", {}).get(region, []).size()

static func mark_stop(region: String, stage: int, p: Dictionary = Game.profile) -> void:
	ensure(p)
	if not p.completion.stops.has(region):
		p.completion.stops[region] = []
	if not p.completion.stops[region].has(stage):
		p.completion.stops[region].append(stage)

## [found, all] secrets of a region ("" for everywhere).
static func count_secrets(region: String, p: Dictionary = Game.profile) -> Array:
	var n := 0
	var all := 0
	for s: Dictionary in list():
		if region == "" or str(s.region) == region:
			all += 1
			n += 1 if found(str(s.id), p) else 0
	return [n, all]

## Everything that is counted, each thing once: [{cat, id, region ("" when it belongs to no road), done, hint}].
## The hint is what may be said about it while it is missing, and never how to get it.
static func things(p: Dictionary = Game.profile) -> Array:
	var c: Dictionary = data().completion
	var out: Array = []
	for r: Dictionary in Db.regions:
		var walked: Array = p.get("completion", {}).get("stops", {}).get(r.id, [])
		for i: int in r.stages.size():
			out.append({"cat": "stops", "id": "%s:%d" % [r.id, i], "region": str(r.id), "done": walked.has(i) or walked.has(float(i)), "hint": str(c.hints.stops)})
	for id: String in Db.foes:
		if Db.foes[id].boss:
			out.append({"cat": "guardians", "id": id, "region": str(Db.foes[id].region), "done": p.get("defeated", {}).has(id), "hint": str(c.hints.guardians)})
	for s: Dictionary in list():
		out.append({"cat": "secrets", "id": str(s.id), "region": str(s.region), "done": found(str(s.id), p), "hint": str(s.hint)})
	for q: Dictionary in all_quests():
		out.append({"cat": "missions", "id": str(q.id), "region": "", "done": p.get("quests_done", []).has(q.id), "hint": str(c.hints.missions)})
	for l: Dictionary in Db.lore:
		out.append({"cat": "lore", "id": str(l.id), "region": str(l.region), "done": p.get("lore", []).has(l.id), "hint": str(c.hints.lore)})
	return out

static func _pct(tally: Dictionary, weights: Dictionary) -> float:
	var got := 0.0
	var of := 0.0
	var whole := true
	for cat: String in weights:
		if not tally.has(cat) or int(tally[cat].total) == 0:
			continue
		of += float(weights[cat])
		got += float(weights[cat]) * float(tally[cat].done) / float(tally[cat].total)
		whole = whole and int(tally[cat].done) == int(tally[cat].total)
	if of <= 0.0:
		return 0.0
	return 100.0 if whole else minf(99.9, floorf(got / of * 1000.0) / 10.0)

## How much of the kingdom has been seen:
##   {pct, categories {cat: {name, done, total}}, remains [hints for what belongs to no road],
##    regions [{id, name, pct, unlocked, categories, remains [hints]}], milestones [{id, at, reached, reward [labels]}]}
## Hidden records ride on their secrets and are not counted twice.
static func completion(p: Dictionary = Game.profile) -> Dictionary:
	var c: Dictionary = data().completion
	var cats := {}
	var regions := {}
	var region_list: Array = []
	for r: Dictionary in Db.regions:
		var entry := {"id": str(r.id), "name": str(r.name), "pct": 0.0, "categories": {}, "remains": [],
			"unlocked": r.requires == null or p.get("cleared", []).has(r.requires) or stops_walked(str(r.id), p) > 0}
		regions[r.id] = entry
		region_list.append(entry)
	var remains: Array = []
	for t: Dictionary in things(p):
		for tally: Dictionary in ([cats, regions[t.region].categories] if regions.has(t.region) else [cats]):
			if not tally.has(t.cat):
				tally[t.cat] = {"name": str(c.names[t.cat]), "done": 0, "total": 0}
			tally[t.cat].total += 1
			tally[t.cat].done += 1 if t.done else 0
		if not t.done:
			var into: Array = regions[t.region].remains if regions.has(t.region) else remains
			if not into.has(t.hint):
				into.append(t.hint)
	for entry: Dictionary in region_list:
		entry.pct = _pct(entry.categories, c.region_weights)
	var pct := _pct(cats, c.weights)
	var marks: Array = []
	for m: Dictionary in data().milestones:
		var labels: Array = []
		for k: String in ["finish", "trophy", "title"]:
			if m.reward.has(k):
				labels.append("%s: %s" % [{"finish": "Finish", "trophy": "For the sanctuary", "title": "Title"}[k], label_of(k, str(m.reward[k]))])
		marks.append({"id": str(m.id), "at": int(m.at), "reached": p.get("completion", {}).get("milestones", []).has(m.id), "reward": labels})
	return {"pct": pct, "categories": cats, "remains": remains, "regions": region_list, "milestones": marks}

## Pays any milestone the profile has reached and not yet been given. Called on every save; changes nothing else.
static func sync(p: Dictionary) -> void:
	if p.is_empty() or not (p.get("completion") is Dictionary) or not p.has("equipped"):
		return
	ensure(p)
	var due: Array = []
	for m: Dictionary in data().milestones:
		if not p.completion.milestones.has(m.id):
			due.append(m)
	if due.is_empty():
		return
	var pct: float = completion(p).pct
	for m: Dictionary in due:
		if pct >= float(m.at):
			p.completion.milestones.append(m.id)
			grant(m.reward, p)

## A save from before this layer: credit what it can be shown to have done. A road whose guardian has fallen was
## walked end to end at least once (the short way only opens from its fourth stop); a road with its mechanism
## turned was walked that far.
static func backfill(v: Dictionary) -> void:
	v["completion"] = blank()
	for r: Dictionary in Db.regions:
		var last: Dictionary = r.stages[-1].options[-1]
		var n := 0
		if v.get("cleared", []).has(r.id) or v.get("defeated", {}).has(last.get("foe", "-")):
			n = r.stages.size()
		elif v.get("flags", {}).has(r.shortcut.flag):
			n = int(r.shortcut.stage)
		if n > 0:
			v.completion.stops[r.id] = range(n)

## JSON gives numbers back as floats: restore the whole ones.
static func tidy(v: Dictionary) -> void:
	ensure(v)
	for k in v.feats:
		v.feats[k] = int(v.feats[k])
	for r in v.completion.stops:
		var arr: Array = []
		for i in v.completion.stops[r]:
			if not arr.has(int(i)):
				arr.append(int(i))
		v.completion.stops[r] = arr
