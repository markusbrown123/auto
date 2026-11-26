class_name Generations
extends RefCounted
## The three generations of one house (docs/GENERATIONS_DATA.md, docs/GENERATIONAL_CAMPAIGN_BRIEF.md). Rules only.
## Tables are in data/generations.json (tools/gen_regions.py).
##
## A save holds four layers. Nothing of the first is ever changed by a transition.
##   PROFILE     the family's: everything the profile held before this layer (gear and its records, gold, materials,
##               mastery, combos and their use, lore, secrets, completion, level and attributes), plus `family`.
##   GENERATION  `generations`: one record for each of the house who has stood before the gates, kept for good.
##   WORLD       `world`: {facts {typed fact: generation it happened in}, cleared {region: [generations]}}; the
##               live road state of the present generation stays where it always was (cleared, flags, defeated).
##   CAMPAIGN    `campaign`: {generation, transition, history, monarch, inheritance, left_weapon, echo, ending, legacy}.
## In these three subtrees a whole number is always stored as an integer, in memory as on disk (_norm), so a save
## read back is the save that was written.

const ECHO_BLOWS := 0.115         # share of the kept one's own health a plain cut of the echo takes, after armour
const ECHO_SECONDS := 90.0        # how long the kept one's own blade would need, cutting without pause

static func data() -> Dictionary:
	return Encounters.data()

static func def(i: int) -> Dictionary:
	return data().generations[clampi(i, 1, 3) - 1]

# ================================================================ shape
static func blank_campaign(gen: int = 2) -> Dictionary:
	return {"generation": gen, "transition": {}, "history": [], "monarch": {}, "inheritance": {}, "left_weapon": {}, "echo": {},
		"ending": "", "legacy": 0}

static func blank_world() -> Dictionary:
	return {"facts": {}, "cleared": {}}

static func blank_stats() -> Dictionary:
	return {"fights": 0, "wins": 0, "defeats": 0, "parries": 0, "perfect_parries": 0, "dodges": 0, "perfect_dodges": 0, "blocks": 0,
		"hits_taken": 0, "dealt": 0, "taken": 0, "time": 0}

static func blank_record(i: int, body: String = "m", name: String = "") -> Dictionary:
	var d := def(i)
	return {"index": i, "role": str(d.role), "body": body, "name": name, "chapter": str(d.chapter), "year": int(d.year), "fate": "alive",
		"cause": "", "context": {}, "loadout": {}, "deeds": {"guardians": [], "routes": [], "regions": [], "discoveries": []},
		"stats": blank_stats(), "authored": false, "migrated": false}

## The first of the house as the story tells it, for a journey that begins with the second (today's New Journey,
## and every save from before this layer): fallen, in the forebear's own kit.
static func _forebear_record(body: String, migrated: bool) -> Dictionary:
	var r := blank_record(1, body)
	var fb: Dictionary = data().forebear
	r.fate = str(def(1).fate)
	r.cause = "sealed_hall"
	r.authored = true
	r.migrated = migrated
	r.loadout = {"weapon": {"id": str(fb.weapon)}, "equipped": {"weapon": str(fb.weapon)}, "level": int(fb.level)}
	return r

## Makes sure a profile carries the three layers (a profile built by hand, or one from before them, may not).
## A profile without them is a journey of the second generation with the first recorded as fallen.
static func ensure(p: Dictionary) -> void:
	if not (p.get("family") is Dictionary):
		p["family"] = {"name": str(data().house), "emblem": "oath"}
	if not (p.get("world") is Dictionary):
		p["world"] = {}
	for k: String in blank_world():
		if not (p.world.get(k) is Dictionary):
			p.world[k] = {}
	if not (p.get("campaign") is Dictionary):
		p["campaign"] = {}
	var base := blank_campaign()
	for k: String in base:
		if not p.campaign.has(k):
			p.campaign[k] = base[k]
	if not (p.get("generations") is Array) or p.generations.is_empty():
		p["generations"] = []
		var g := int(p.campaign.generation)
		for i: int in range(1, g + 1):
			p.generations.append(_forebear_record(str(p.get("body", "m")), false) if i == 1 and g > 1 else blank_record(i, str(p.get("body", "m")), str(p.get("name", ""))))

## A new journey's layers. `start` is 2 for today's New Journey (the first generation is the filmed opening) or 1 when
## the first generation is to be played through fall() and inherit().
static func begin(p: Dictionary, start: int = 2) -> void:
	p["campaign"] = blank_campaign(clampi(start, 1, 2))
	p["world"] = blank_world()
	p["generations"] = []
	p.erase("family")
	ensure(p)
	_norm(p)

static func gen(p: Dictionary = Game.profile) -> int:
	return clampi(int(p.get("campaign", {}).get("generation", 2)), 1, 3)

static func current(p: Dictionary = Game.profile) -> Dictionary:
	ensure(p)
	return record(gen(p), p)

static func record(i: int, p: Dictionary = Game.profile) -> Dictionary:
	for r: Dictionary in p.get("generations", []):
		if int(r.index) == i:
			return r
	return {}

## The canon is the three generations and the ending first chosen. Once that is chosen, or the world has turned over
## (a legacy journey), nothing below writes to it again.
static func canon_open(p: Dictionary = Game.profile) -> bool:
	return int(p.get("ng", 0)) == 0 and str(p.get("campaign", {}).get("ending", "")) == ""

static func add_fact(fact: String, p: Dictionary = Game.profile) -> bool:
	ensure(p)
	if not canon_open(p) or p.world.facts.has(fact):
		return false
	p.world.facts[fact] = gen(p)
	return true

# ================================================================ whole numbers stay whole
static func _whole(v: Variant) -> Variant:
	if v is float and v == floorf(v) and absf(v) < 1.0e15:
		return int(v)
	if v is Dictionary:
		for k in v:
			v[k] = _whole(v[k])
	elif v is Array:
		for i: int in v.size():
			v[i] = _whole(v[i])
	return v

static func _norm(p: Dictionary) -> void:
	if p.get("flags") is Dictionary and p.flags.has("generation"):
		p.flags["generation"] = int(p.flags.generation)        # the scenes' own marker (src/cine/arrival.gd)
	for k: String in ["campaign", "world", "generations", "family"]:
		if p.has(k):
			p[k] = _whole(p[k])

# ================================================================ migration
## Brings a profile from before this layer (save versions 0 to 2) into it. A journey still on the road becomes the
## second generation in progress, with the first recorded as fallen and its opening marked seen. A journey that had
## already chosen an ending, or turned the world over, is the last heir's, with both before them recorded.
## Safe on its own output: a profile that already has a campaign is only checked and tidied.
static func migrate(v: Dictionary) -> void:
	if v.get("campaign") is Dictionary and v.get("generations") is Array and not v.generations.is_empty():
		ensure(v)
		_norm(v)
		return
	var body := str(v.get("body", "m"))
	var done: bool = not v.get("endings", []).is_empty() or int(v.get("ng", 0)) > 0 or v.get("flags", {}).has("last_ending")
	v["campaign"] = blank_campaign(3 if done else 2)
	v["world"] = blank_world()
	v["generations"] = [_forebear_record(body, true)]
	v.campaign.monarch["1"] = {"fought": true, "result": "", "migrated": true}
	v.flags["gen1_complete"] = true
	var mine := blank_record(3 if done else 2, body, str(v.get("name", "")))
	mine.migrated = true
	if done:
		var second := blank_record(2, body)
		second.fate = str(def(2).fate)
		second.cause = "saved_the_records"
		second.authored = true
		second.migrated = true
		v.generations.append(second)
		v.campaign.monarch["2"] = {"fought": false, "won": false, "migrated": true}
		v.campaign.history = [{"from": 1, "to": 2, "cause": "sealed_hall", "migrated": true}, {"from": 2, "to": 3, "cause": "saved_the_records", "migrated": true}]
		v.campaign.legacy = int(v.get("ng", 0))
	else:
		v.campaign.history = [{"from": 1, "to": 2, "cause": "sealed_hall", "migrated": true}]
	v.generations.append(mine)
	ensure(v)
	# what the journey has done is the deeds of the one who did it; then the canon is closed if it was finished
	_credit(v)
	if v.get("defeated", {}).has("forgotten_monarch"):
		v.campaign.monarch[str(int(mine.index))] = {"fought": true, "won": true, "migrated": true}
		if done:
			v.world.facts["monarch_felled:3"] = 3
	_gather(v)
	if done:
		var ends: Array = v.get("endings", [])
		v.campaign.ending = str(v.get("flags", {}).get("last_ending", ends[-1] if not ends.is_empty() else "silence"))
	_norm(v)

# ================================================================ deeds, facts, records (kept up on every save)
static func _all_deeds(p: Dictionary, key: String) -> Array:
	var out: Array = []
	for r: Dictionary in p.generations:
		out.append_array(r.deeds.get(key, []))
	return out

## Attributes whatever the profile shows and no generation has yet been credited with to the present one.
static func _credit(p: Dictionary) -> void:
	var rec := record(gen(p), p)
	if rec.is_empty():
		return
	var g := gen(p)
	var known: Array = _all_deeds(p, "guardians")
	for id: String in p.get("defeated", {}):
		if Encounters.is_guardian(id) and not known.has(id):
			rec.deeds.guardians.append(id)
			var who := Encounters.individual(id)
			if not p.world.facts.has("slain:" + who):
				p.world.facts["slain:" + who] = g
	known = _all_deeds(p, "routes")
	for r: Dictionary in Db.regions:
		if p.get("flags", {}).has(r.shortcut.flag) and not known.has(r.id):
			rec.deeds.routes.append(r.id)
			p.world.facts["route_opened:" + str(r.id)] = g
	for id: String in p.get("cleared", []):
		if not rec.deeds.regions.has(id):
			rec.deeds.regions.append(id)
		if not p.world.cleared.has(id):
			p.world.cleared[id] = []
		if not p.world.cleared[id].has(g):
			p.world.cleared[id].append(g)
		if not p.world.facts.has("cleared:" + id):
			p.world.facts["cleared:" + id] = g
	known = _all_deeds(p, "discoveries")
	for id in p.get("lore", []):
		if not known.has("lore:" + str(id)):
			rec.deeds.discoveries.append("lore:" + str(id))
	for id: String in p.get("secrets", {}):
		if not known.has("secret:" + id):
			rec.deeds.discoveries.append("secret:" + id)

## Whether what an inheritance record asks has come about.
static func record_met(r: Dictionary, p: Dictionary) -> bool:
	var need: Dictionary = r.need
	if need.has("fallen") and str(record(int(need.fallen), p).get("fate", "alive")) == "alive":
		return false
	if need.has("clash") and not str(p.campaign.monarch.get("1", {}).get("result", "")) in ["ahead", "won"]:
		return false
	if need.has("monarch_won") and not bool(p.campaign.monarch.get(str(int(need.monarch_won)), {}).get("won", false)):
		return false
	if need.has("lore") and p.get("lore", []).size() < int(need.lore):
		return false
	for id: String in need.get("cleared", []):
		if not ever_cleared(id, p):
			return false
	for id: String in need.get("defeated", []):
		if not p.get("defeated", {}).has(id):
			return false
	return true

static func _gather(p: Dictionary) -> void:
	for r: Dictionary in data().records:
		if not p.campaign.inheritance.has(r.id) and record_met(r, p):
			p.campaign.inheritance[r.id] = gen(p)

## Called on every save. Credits deeds, records facts and gathers inheritance records while the canon is open.
static func sync(p: Dictionary) -> void:
	if p.is_empty() or not p.has("equipped"):
		return
	ensure(p)
	# what the opening's own scene reports through the flags it has always set (src/cine/prologue.gd)
	if p.flags.has("gen1_complete") and not p.campaign.monarch.has("1"):
		p.campaign.monarch["1"] = {"fought": true, "result": str(p.flags.get("gen1_clash", ""))}
	if canon_open(p):
		# the one on the road is whoever the profile says they are; an authored forebear is of the same lineage
		var rec := record(gen(p), p)
		if int(rec.index) >= 2:
			rec.name = str(p.get("name", ""))        # the first is never the player's named knight
		rec.body = str(p.get("body", "m"))
		for r: Dictionary in p.generations:
			if r.authored and not r.migrated and int(r.index) < int(rec.index):
				r.body = rec.body
		_credit(p)
		_gather(p)
	_norm(p)

static func ever_cleared(region: String, p: Dictionary = Game.profile) -> bool:
	return p.get("cleared", []).has(region) or p.get("world", {}).get("cleared", {}).has(region)

## Regions cleared by anyone of the house, in the order the regions are listed.
static func cleared_ever(p: Dictionary = Game.profile) -> Array:
	var out: Array = []
	for r: Dictionary in Db.regions:
		if ever_cleared(str(r.id), p):
			out.append(str(r.id))
	return out

## Inheritance records held: gathered and stored, or met at this moment.
static func has_record(id: String, p: Dictionary = Game.profile) -> bool:
	if p.get("campaign", {}).get("inheritance", {}).has(id):
		return true
	for r: Dictionary in data().records:
		if str(r.id) == id:
			return record_met(r, p) if p.get("campaign") is Dictionary else false
	return false

## [{id, name, text, held, generation (0 while not held), auto, ending}] in the order of the data.
static func records(p: Dictionary = Game.profile) -> Array:
	ensure(p)
	var out: Array = []
	for r: Dictionary in data().records:
		out.append({"id": str(r.id), "name": str(r.name), "text": str(r.text), "held": has_record(str(r.id), p),
			"generation": int(p.campaign.inheritance.get(r.id, 0)), "auto": bool(r.get("auto", false)), "ending": bool(r.get("ending", false))})
	return out

# ================================================================ fights
## Called when any duel is decided (Secrets.duel_ended): the present generation's own tally, and through it the
## defensive habits the echo is built from.
static func note_duel(p: Dictionary, won: bool, sim: DuelSim) -> void:
	if p.is_empty() or sim == null or not canon_open(p):
		return
	var s: Dictionary = current(p).stats
	s.fights += 1
	s["wins" if won else "defeats"] += 1
	for k: String in ["parries", "perfect_parries", "dodges", "perfect_dodges", "blocks", "hits_taken"]:
		s[k] = int(s[k]) + int(sim.stats.get(k, 0))
	s.dealt = roundi(float(s.dealt) + float(sim.stats.get("dealt", 0.0)))
	s.taken = roundi(float(s.taken) + float(sim.stats.get("taken", 0.0)))
	s.time = roundi(float(s.time) + sim.time)

## Called on every victory (Game.on_victory): the meetings with the Monarch record themselves.
static func note_victory(p: Dictionary, foe_id: String) -> void:
	ensure(p)
	var m := Encounters.monarch_of(foe_id, p)
	if m == 0 or not canon_open(p) or m != gen(p):
		return
	note_monarch(p, m, {"won": true})

## Records how a meeting with the Monarch stood. `result` may carry: won (the player beat him in the fight), choice
## ("press" or "records"), result (Generation I: "ahead", "behind", "even"), and anything else a scene wants kept.
## A win, once recorded, is never unrecorded.
static func note_monarch(p: Dictionary, generation: int, result: Dictionary) -> void:
	ensure(p)
	if not canon_open(p):
		return
	var key := str(generation)
	var m: Dictionary = p.campaign.monarch.get(key, {})
	var had: bool = bool(m.get("won", false))
	for k: String in result:
		m[k] = result[k]
	m["fought"] = true
	m["won"] = had or bool(m.get("won", false))
	p.campaign.monarch[key] = m
	if m.won:
		p.world.facts["monarch_bested:" + key] = generation
		if generation == 3:
			p.world.facts["monarch_felled:3"] = 3
	_gather(p)
	_norm(p)

static func monarch(generation: int, p: Dictionary = Game.profile) -> Dictionary:
	var out: Dictionary = data().monarch[str(clampi(generation, 1, 3))].duplicate(true)
	out["record"] = p.get("campaign", {}).get("monarch", {}).get(str(generation), {})
	return out

## The Monarch's last form: what the family learned decides how much his restoration is still worth. With every
## record gathered he is stood up once, weakly, and can no longer feed; with none he comes back at more than half.
static func monarch_final(f: Dictionary, v: Dictionary, p: Dictionary) -> void:
	var all: Array = data().records
	var held := 0
	for r: Dictionary in all:
		held += 1 if has_record(str(r.id), p) else 0
	var k := float(held) / maxf(1.0, float(all.size()))
	var r: Dictionary = v.get("records", {})
	if r.has("revive"):
		f.phases[-1]["revive"] = snappedf(lerpf(float(r.revive[0]), float(r.revive[1]), k), 0.01)
	for t: String in ["lifesteal", "parry_open"]:
		if r.has(t):
			f.traits[t] = snappedf(lerpf(float(r[t][0]), float(r[t][1]), k), 0.01)
	f["records_held"] = held

# ================================================================ loadouts
## What one of the house was carrying and wearing: enough to show them again, and to build the echo.
static func loadout(p: Dictionary) -> Dictionary:
	var w: String = str(p.equipped.weapon) if p.equipped.get("weapon") != null else ""
	var ups := {}
	for slot: String in p.equipped:
		var id = p.equipped[slot]
		if id != null and int(p.get("upgrades", {}).get(id, 0)) > 0:
			ups[id] = int(p.upgrades[id])
	return {"level": int(p.level), "attrs": p.attrs.duplicate(), "equipped": p.equipped.duplicate(), "look": Game.appearance_loadout(p),
		"cosmetics": p.get("cosmetics", {}).duplicate(true), "upgrades": ups, "heraldry": str(p.get("heraldry", "")),
		"weapon": _weapon_record(w, p), "shield": str(p.equipped.shield) if p.equipped.get("shield") != null else ""}

## The whole of what the save holds about one weapon: {id, cls, level, mods {grip, ore, ore_id}, edge, mastery_xp, mastered}.
static func _weapon_record(id: String, p: Dictionary) -> Dictionary:
	if id == "":
		return {}
	var m: Dictionary = p.get("mods", {}).get(id, {})
	return {"id": id, "cls": str(Db.item(id).get("cls", "sword")), "level": int(p.get("upgrades", {}).get(id, 0)),
		"mods": {"grip": int(m.get("grip", 0)), "ore": int(m.get("ore", 0)), "ore_id": str(m.get("ore_id", ""))},
		"edge": int(p.get("edge", {}).get(id, 0)), "mastery_xp": int(p.get("mastery", {}).get(id, 0)), "mastered": p.get("mastered", []).has(id)}

# ================================================================ the two canonical falls
## One of the house falls, at an authored moment. Only the present generation can fall, only the first and the second
## ever do, and each only once: anything else returns false and changes nothing. Nothing in the profile is taken.
## `context` may carry: weapon (the blade that was in hand, if not the one equipped), where (the spot it lies),
## clash (Generation I: how the clash stood), choice / won (Generation II: what was chosen, whether he was beaten).
static func fall(p: Dictionary, generation: int, cause: String, context: Dictionary = {}) -> bool:
	if p.is_empty():
		return false
	ensure(p)
	var c: Dictionary = p.campaign
	if not canon_open(p) or generation != int(c.generation) or generation > 2 or not c.transition.is_empty():
		return false
	var rec := record(generation, p)
	if rec.is_empty() or str(rec.fate) != "alive":
		return false
	# the blade in hand: it stays in the family's keeping whatever happens next
	var w := Db.canon(str(context.get("weapon", p.equipped.weapon if p.equipped.get("weapon") != null else "")))
	if w != "" and Db.items.has(w) and not p.inventory.has(w):
		p.inventory.append(w)
		p.discovered[w] = true
	rec.loadout = loadout(p)
	if generation == 1:
		# the first is fought with the forebear's own sheet; what is recorded of them is that, and the sword
		var fb: Dictionary = data().forebear
		rec.loadout = {"level": int(fb.level), "attrs": fb.attrs.duplicate(), "equipped": {"weapon": w}, "look": {"weapon": w},
			"cosmetics": {}, "upgrades": {}, "heraldry": str(p.get("heraldry", "")), "weapon": _weapon_record(w, p), "shield": ""}
		note_monarch(p, 1, {"result": str(context.get("clash", p.flags.get("gen1_clash", "")))})
		p.flags["gen1_complete"] = true
	else:
		c.echo = snapshot(p)
		var how := {"choice": str(context.get("choice", "records"))}
		if context.has("won"):
			how["won"] = bool(context.won)
		note_monarch(p, 2, how)
	rec.fate = str(def(generation).fate)
	if generation == 2:
		rec.name = str(p.get("name", ""))
		rec.body = str(p.get("body", "m"))
	rec.cause = cause
	rec.context = context.duplicate(true)
	c.left_weapon = {"id": w, "generation": generation, "taken": false, "left_where_it_fell": true,
		"where": str(context.get("where", "engine_block" if generation == 1 else "throne_seal")), "record": _weapon_record(w, p)}
	_credit(p)
	c.transition = {"state": "fallen", "from": generation, "to": generation + 1, "cause": cause}
	_gather(p)
	_norm(p)
	return true

## The next of the house takes up the road. Needs a fall that has not yet been answered. `who` may carry body, name
## and heraldry; without them the heir is of the same lineage. Everything the family holds is theirs as it was; the
## loadout is what the one before them wore, with the blade that was left in their hand.
static func inherit(p: Dictionary, who: Dictionary = {}) -> bool:
	if p.is_empty():
		return false
	ensure(p)
	var c: Dictionary = p.campaign
	if str(c.transition.get("state", "")) != "fallen":
		return false
	var from := int(c.transition.from)
	var to := from + 1
	_credit(p)
	var rec := blank_record(to, str(who.get("body", p.get("body", "m"))), str(who.get("name", "" if from == 2 else p.get("name", ""))))
	p.generations.append(rec)
	p.body = rec.body
	p.name = rec.name
	if who.has("heraldry"):
		p.heraldry = str(who.heraldry)
	# the road is walked again by someone new: its regions are to be cleared afresh, its opened ways stay open
	p.cleared = []
	var w := str(c.left_weapon.get("id", ""))
	if w != "" and p.inventory.has(w) and not Db.item(w).is_empty():
		p.equipped.weapon = w
		if Db.classes[Db.item(w).cls].two_handed:
			p.equipped.shield = null
	if to == 3:
		p.flags["witness_found"] = true          # it was carried home; it returns with the heir
	p.flags["generation"] = to
	c.history.append({"from": from, "to": to, "cause": str(c.transition.get("cause", "")), "year": int(def(to).year)})
	c.generation = to
	c.transition = {}
	_norm(p)
	return true

## The blade the one before left where they fell: {id, generation, taken, left_where_it_fell, where, record} or {}.
static func fallen_weapon(p: Dictionary = Game.profile) -> Dictionary:
	return p.get("campaign", {}).get("left_weapon", {})

## Where the Witness stands for the present generation: "imprisoned", "found" or "returning".
static func witness(p: Dictionary = Game.profile) -> String:
	if gen(p) >= 3:
		return "returning"
	return "found" if gen(p) == 2 and p.get("flags", {}).has("witness_found") else "imprisoned"

# ================================================================ the echo
## The second of the house as they stood when they fell: frozen, and never changed afterwards.
static func snapshot(p: Dictionary) -> Dictionary:
	var st := Stats.compute(p, Db.items, Db.classes)
	var out := loadout(p)
	out["generation"] = gen(p)
	out["body"] = str(p.get("body", "m"))
	out["name"] = str(p.get("name", ""))
	out["known"] = p.get("combos", []).duplicate()
	var keep := {}
	for k: String in ["max_hp", "max_stamina", "attack", "swing_time", "mitigation", "defense", "block_eff", "crit_mult"]:
		keep[k] = snappedf(float(st[k]), 0.001)
	out["stats"] = keep
	# the combinations that hand reached for most, with how often (ties in the order they are taught)
	var rows: Array = []
	for i: int in Db.combos.size():
		var id := str(Db.combos[i].id)
		if int(p.get("combo_uses", {}).get(id, 0)) > 0:
			rows.append([int(p.combo_uses[id]), i, id])
	rows.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
	out["combos"] = rows.slice(0, int(data().echo.combos)).map(func(r): return [r[2], r[0]])
	var s: Dictionary = record(gen(p), p).get("stats", blank_stats())
	var total := float(int(s.parries) + int(s.dodges) + int(s.blocks))
	out["habits"] = {"parry": snappedf(float(s.parries) / total, 0.001), "dodge": snappedf(float(s.dodges) / total, 0.001),
		"block": snappedf(float(s.blocks) / total, 0.001), "seen": int(total)} if total > 0.0 else {"parry": 0, "dodge": 0, "block": 0, "seen": 0}
	return _whole(out)

## The snapshot the echo is built from: the one taken at the second fall, or one of the starting kit when there is
## none (content skipped, or a save from before this layer).
static func echo_snapshot(p: Dictionary = Game.profile) -> Dictionary:
	var s: Dictionary = p.get("campaign", {}).get("echo", {})
	if not s.is_empty():
		return s
	var d := Game.default_profile()
	d["body"] = str(p.get("body", "m"))
	d["heraldry"] = str(p.get("heraldry", d.heraldry))
	d["campaign"] = blank_campaign()
	d["generations"] = [blank_record(1), blank_record(2)]
	var out := snapshot(d)
	out["default"] = true
	return out

static func _blow(dir: String, windup: float, dmg: float, extra: Dictionary = {}) -> Dictionary:
	var a := {"dir": dir, "windup": snappedf(windup, 0.01), "dmg": roundi(dmg), "swing": 0.3, "guard": roundi(dmg * 1.3), "parry": true, "unblockable": false,
		"element": null, "kind": "slash", "dodge": "L" if "L" in dir else ("R" if "R" in dir else "any")}
	a.merge(extra, true)
	return a

static func _string(id: String, w: int, attacks: Array, recover: float, tags: Array = ["basic"], gap: float = 0.15) -> Dictionary:
	return {"id": id, "w": w, "attacks": attacks, "recover": snappedf(recover, 0.01), "tags": tags, "range": "near", "retreat": false, "gap": gap}

## A combination of the player's as the echo throws it: the same directions in the same order, each telegraphed.
## The first blow is wound up in full; the rest follow at the pace of the blade that taught them.
static func _translate(c: Dictionary, blow: float, first: float, follow: float, scale: float = 1.0) -> Dictionary:
	var kind := str(c.get("kind", "Fast"))
	var seq: Array = c.seq
	var each: float = blow * scale * clampf(1.15 - 0.07 * seq.size(), 0.75, 1.05)
	var attacks: Array = []
	for i: int in seq.size():
		var last: bool = i == seq.size() - 1
		var extra := {}
		var wind := first if i == 0 else follow
		if i == 0 and kind == "Counter":
			wind = first + 0.75                      # held back, as a riposte is: it catches a parry thrown early
		if last and seq.size() >= 2 and kind in ["Heavy", "Finisher", "Guard-breaking"]:
			wind = maxf(wind, follow + 0.45)
			extra["kind"] = "slam" if "D" in str(seq[i]) else "thrust"
			extra["dmg"] = roundi(each * 1.35)
			if kind == "Guard-breaking":
				extra["guard"] = roundi(each * 4.0)
		attacks.append(_blow(str(seq[i]), wind, each, extra))
	var tags: Array = []
	if seq.size() >= 3:
		tags.append("anti_dodge")
	if kind == "Counter":
		tags.append("anti_parry")
	if kind == "Guard-breaking":
		tags.append("anti_block")
	if tags.is_empty():
		tags.append("basic")
	return _string(str(c.id), 3, attacks, 1.15 + 0.14 * seq.size(), tags)

## The echo: a complete foe (the shape of an entry in bosses.json) built from the snapshot and nothing else, so the
## same snapshot always gives the same foe. It is added to Db.foes under the id in data/generations.json ("the_kept").
## `look` describes the loadout for whoever dresses it; `rig` is the knight's own look as it stood.
static func echo_foe(p: Dictionary = Game.profile) -> Dictionary:
	var e: Dictionary = data().echo
	var s := echo_snapshot(p)
	var st: Dictionary = s.stats
	var cls := str(s.weapon.get("cls", "sword"))
	var heavy: bool = cls in ["greatsword", "axe"]
	var dual: bool = cls == "dual"
	var shield: bool = str(s.shield) != ""
	var first := 1.05 if heavy else (0.8 if dual else 0.9)
	var follow := 0.72 if heavy else (0.55 if dual else 0.62)
	var weight := 1.25 if heavy else (0.82 if dual else 1.0)
	var blow: float = clampf(float(st.max_hp) * ECHO_BLOWS / maxf(0.35, 1.0 - float(st.mitigation)), 12.0, 64.0) * weight
	var hp: float = clampf(float(st.attack) / (float(st.swing_time) + 0.12) * ECHO_SECONDS, 2400.0, 17000.0)
	# what it throws: two plain cuts everyone can read, then the player's own favourites, most used first
	var favourites: Array = []
	for row: Array in s.combos:
		if Db.combo_by_id.has(row[0]):
			favourites.append(Db.combo_by_id[row[0]])
	for id in s.get("known", []):
		if favourites.size() < 2 and Db.combo_by_id.has(id) and not favourites.has(Db.combo_by_id[id]):
			var c: Dictionary = Db.combo_by_id[id]
			if c.cls.is_empty() or c.cls.has(cls):
				favourites.append(c)
	if favourites.is_empty():
		favourites.append(Db.combos[0])
	var basics: Array = [_string("cut_l", 2, [_blow("L", first, blow)], 1.25), _string("cut_r", 2, [_blow("R", first, blow)], 1.25),
		_string("cut_d", 1, [_blow("D", first + 0.15, blow * 1.2, {"kind": "slam"} if heavy else {})], 1.4)]
	var shove := _string("shove", 2, [_blow("U", first, blow * 0.7, {"guard": roundi(blow * 3.2), "kind": "thrust"})], 1.2, ["anti_block"])
	var phases: Array = []
	var marks: Array = [[1.0, 1.0, 2, ""], [0.62, 1.07, 4, "It changes its grip. You know the grip."],
		[0.3, 1.13, int(e.combos), "It stops defending. It fights the way you fought when you were sure."]]
	for m: Array in marks:
		var combos: Array = basics.duplicate(true)
		for i: int in mini(int(m[2]), favourites.size()):
			combos.append(_translate(favourites[i], blow, first, follow))
		if shield and float(m[0]) < 1.0:
			combos.append(shove.duplicate(true))
		if float(m[0]) <= 0.3:
			var sig := _translate(favourites[0], blow, first, follow, 1.15)        # the one it reached for most, in earnest
			sig.id = "signature"
			sig.w = 4
			combos.append(sig)
		var ph := {"at": m[0], "speed": m[1], "combos": combos}
		if str(m[3]) != "":
			ph["roar"] = m[3]
		phases.append(ph)
	# how it defends is how the player defended: a foe that parried a great deal is hard to open with a parry
	var h: Dictionary = s.get("habits", {})
	var traits := {}
	if float(h.get("parry", 0)) >= 0.45:
		traits["parry_open"] = 0.9
	if float(h.get("dodge", 0)) >= 0.45 or dual:
		traits["dodge_open"] = 0.8
	if float(h.get("block", 0)) >= 0.45 or heavy:
		traits["block_tax"] = 1.4
	var rig := _echo_rig(s)
	var music: String = str(Db.foes.get(str(e.get("music_as", "")), {}).get("music", "boss"))
	var f := {"id": str(e.id), "name": str(e.name), "title": str(e.title), "cls": "Kept", "region": str(e.region), "boss": true,
		"variant": true, "echo": true, "gen": 3, "hp": roundi(hp), "armor": 0.1, "posture": 140 if heavy else 110, "poise": 140 if heavy else 110,
		"patience": 2, "adapt": 1.0, "idle": [0.7, 1.3], "weak": null, "xp": 3200, "gold": 3600, "loot": [], "rig": rig, "music": music,
		"intro": str(e.intro), "punish": _blow("D", 0.5, blow * 0.9, {"swing": 0.25}), "phases": phases, "traits": traits,
		"press": 0.7 if dual else (0.4 if heavy else 0.55), "footwork": {"circle": 0.3 if dual else (0.06 if heavy else 0.14), "keep": 0.55 if dual else 0.8},
		"look": {"body": str(s.body), "name": str(s.name), "heraldry": str(s.heraldry), "equipped": s.equipped, "appearance": s.look,
			"cosmetics": s.cosmetics, "weapon": s.weapon, "shield": str(s.shield), "upgrades": s.upgrades},
		"favourites": s.combos, "habits": h, "default": bool(s.get("default", false))}
	Db.foes[f.id] = f
	return f

## The knight's own look as the snapshot had it, by the same code that dresses the player (Duel.player_look reads the
## profile in memory, so the snapshot stands in for it for the length of the call).
static func _echo_rig(s: Dictionary) -> Dictionary:
	var keep: Dictionary = Game.profile
	var stand := Game.default_profile()
	stand["body"] = str(s.body)
	stand["heraldry"] = str(s.heraldry) if str(s.heraldry) != "" else stand.heraldry
	stand["level"] = int(s.level)
	stand["attrs"] = s.attrs.duplicate()
	stand["cosmetics"] = s.cosmetics.duplicate(true)
	stand["upgrades"] = s.upgrades.duplicate()
	stand["inventory"] = []
	for slot: String in stand.equipped:
		stand.equipped[slot] = s.equipped.get(slot)
	for src: Dictionary in [s.equipped, s.look]:
		for slot: String in src:
			if src[slot] != null and not stand.inventory.has(src[slot]):
				stand.inventory.append(src[slot])
	if not s.weapon.is_empty():
		stand["mods"] = {str(s.weapon.id): s.weapon.mods.duplicate()}
	Game.profile = stand
	var rig: Dictionary = Duel.player_look()
	Game.profile = keep
	rig["witness"] = false
	rig["scale"] = float(rig.get("scale", 1.0))
	return rig

# ================================================================ endings and legacy
## Whether an ending can be chosen now. The first two always can. Dividing the Crown needs every inheritance record
## marked for it that the house has had the chance to gather: one that belongs to a generation never played (the
## Kept, on a journey that has not reached the third; a save from before this layer) is not asked for.
static func ending_open(id: String, p: Dictionary = Game.profile) -> bool:
	for e: Dictionary in data().endings:
		if str(e.id) != id:
			continue
		if not e.need.has("records"):
			return true
		for r: Dictionary in data().records:
			if not r.get(str(e.need.records), false):
				continue
			var g := int(r.get("gen", 0))
			if g > 0 and (g > gen(p) or record(g, p).get("migrated", false) or not canon_open(p)):
				continue
			if not has_record(str(r.id), p):
				return false
		return true
	return false

static func endings(p: Dictionary = Game.profile) -> Array:
	var out: Array = []
	for e: Dictionary in data().endings:
		out.append({"id": str(e.id), "name": str(e.name), "open": ending_open(str(e.id), p), "chosen": str(p.get("campaign", {}).get("ending", "")) == str(e.id)})
	return out

## The first ending chosen is the canon's; choosing again on a legacy journey is kept apart (profile.endings).
static func note_ending(p: Dictionary, id: String) -> void:
	ensure(p)
	if canon_open(p):
		seal(p)
		p.campaign.ending = id
		p.world.facts["ending:" + id] = gen(p)
	_norm(p)

## The canon is about to close (an ending chosen, or the world turned over): the one on the road is credited one
## last time and set down as they stand, so the lineage shows them as they were then.
static func seal(p: Dictionary) -> void:
	ensure(p)
	if not canon_open(p):
		return
	sync(p)
	record(gen(p), p).loadout = loadout(p)
	_norm(p)

# ================================================================ lineage
## Everything a lineage screen needs, oldest first. Reads only.
##   {house, emblem, heraldry, generation (the present one), ending, legacy, records [...],
##    people [{index, role, ordinal, chapter, name, display, body, relation, relation_words {m, f}, kin (what they are
##             to the present one), year, years_ago, fate, cause, current, authored, loadout, deeds {guardians
##             [{id, name}], routes [{id, name}], regions [{id, name}], discoveries, lore, secrets}, stats, weapon_left}]}
static func lineage(p: Dictionary = Game.profile) -> Dictionary:
	if p.is_empty():
		return {}
	ensure(p)
	var now := gen(p)
	var people: Array = []
	for r: Dictionary in p.generations:
		var d := def(int(r.index))
		var body := str(r.body)
		var guardians: Array = []
		for id: String in r.deeds.guardians:
			var f: Dictionary = Db.foes.get(id, Db.foes.get(Encounters.base_of(id), {}))
			guardians.append({"id": id, "name": str(f.get("name", id.capitalize()))})
		var named := func(ids: Array) -> Array:
			return ids.map(func(id): return {"id": str(id), "name": str(Db.region_by_id.get(id, {}).get("name", id))})
		var lore := 0
		for x: String in r.deeds.discoveries:
			lore += 1 if x.begins_with("lore:") else 0
		var left: Dictionary = p.campaign.left_weapon if int(p.campaign.left_weapon.get("generation", 0)) == int(r.index) else {}
		people.append({"index": int(r.index), "role": str(r.role), "ordinal": str(d.ordinal), "chapter": str(r.chapter),
			"name": str(r.name), "display": str(r.name) if str(r.name) != "" else str(d.ordinal).capitalize(), "body": body,
			"relation": str(d.relation[body]), "relation_words": d.relation.duplicate(),
			"kin": str(data().kin[str(int(r.index) - now)][body]), "year": int(r.year), "years_ago": int(def(now).year) - int(r.year),
			"fate": str(r.fate), "cause": str(r.cause), "current": int(r.index) == now, "authored": bool(r.get("authored", false)),
			"loadout": r.loadout if int(r.index) != now or not canon_open(p) else loadout(p),
			"deeds": {"guardians": guardians, "routes": named.call(r.deeds.routes), "regions": named.call(r.deeds.regions),
				"discoveries": r.deeds.discoveries.size(), "lore": lore, "secrets": r.deeds.discoveries.size() - lore},
			"stats": r.stats, "weapon_left": left})
	return {"house": str(p.family.name), "emblem": str(p.family.emblem), "heraldry": str(p.get("heraldry", "")), "generation": now,
		"ending": str(p.campaign.ending), "legacy": int(p.get("ng", 0)), "records": records(p), "people": people}
