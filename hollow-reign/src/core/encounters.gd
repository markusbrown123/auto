class_name Encounters
extends RefCounted
## The encounter director (docs/GENERATIONS_DATA.md). For a generation, a region and a stop it says who stands there
## and what the ways onward are, from the authored tables in data/generations.json (tools/gen_regions.py), the
## generational variants in data/bosses.json (tools/gen_bosses.py) and the world's recorded facts.
##
## Generation II is the roads of data/regions.json exactly as they are: nothing here changes them. Generations I and
## III are told as differences from those roads, stop by stop, so a stop keeps its number in every generation.
## Reads only: nothing here changes a profile. Foes it casts are built in memory and added to Db.foes when asked for
## (as Secrets.challenger does), so the ordinary duel path can fight them.

const OPEN_STATES := ["open", "passed"]
static var _d: Dictionary = {}
static var variants: Dictionary = {}

# ================================================================ data
static func data() -> Dictionary:
	if _d.is_empty():
		_d = JSON.parse_string(FileAccess.get_file_as_string("res://data/generations.json"))
		for v: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses.json")).get("variants", []):
			variants[v.id] = v
	return _d

## The generation whose table is in force: the protagonist's, except that a legacy journey (after the story) walks
## Generation II's roads, as New Game Plus always has.
static func generation(p: Dictionary = Game.profile) -> int:
	if p.is_empty() or int(p.get("ng", 0)) > 0:
		return 2
	return clampi(int(p.get("campaign", {}).get("generation", 2)), 1, 3)

static func has_fact(fact: String, p: Dictionary = Game.profile) -> bool:
	return p.get("world", {}).get("facts", {}).has(fact)

## The generation a fact was recorded in, 0 when it never was.
static func fact_gen(fact: String, p: Dictionary = Game.profile) -> int:
	return int(p.get("world", {}).get("facts", {}).get(fact, 0))

## The roster foe behind an id: a variant's base, a tuned copy's original, or the id itself.
static func base_of(id: String) -> String:
	data()
	if variants.has(id):
		return str(variants[id].base)
	return base_of(id.trim_suffix("_g3")) if id.ends_with("_g3") else id

## The individual an id stands for when the world remembers it: the echo and authored variants are themselves,
## a tuned copy is the one it was copied from.
static func individual(id: String) -> String:
	data()
	if id == str(_d.echo.id) or variants.has(id):
		return id
	return id.trim_suffix("_g3") if id.ends_with("_g3") else id

static func is_guardian(id: String) -> bool:
	data()
	if id == str(_d.echo.id):
		return true
	if variants.has(id):
		return bool(variants[id].get("boss", false))
	var b := individual(id)
	return Db.foes.has(b) and bool(Db.foes[b].boss)

## Which of the three meetings with the Monarch this foe is (0 when it is not him).
static func monarch_of(id: String, p: Dictionary = Game.profile) -> int:
	data()
	if variants.has(id):
		return int(variants[id].get("monarch", 0))
	return generation(p) if id == "forgotten_monarch" else 0

# ================================================================ where a generation may go
## {state, open, optional, why}. `state` is open, passed, locked (the road to it is not yet walked), sealed, shut,
## distant or unknown; `open` is whether a run can set out there now.
static func access(gen: int, region: String, p: Dictionary = Game.profile) -> Dictionary:
	var r: Dictionary = Db.region_by_id[region]
	var cleared: Array = p.get("cleared", [])
	if gen == 2:
		var ok: bool = r.requires == null or cleared.has(r.requires)
		return {"state": "open" if ok else "locked", "open": ok, "optional": bool(r.get("optional", false)), "why": ""}
	var a: Dictionary = data().access.get(str(gen), {}).get(region, {"state": "sealed"})
	var state := str(a.get("state", "sealed"))
	var out := {"state": state, "open": OPEN_STATES.has(state), "optional": bool(a.get("optional", false)), "why": str(a.get("why", ""))}
	if not out.open:
		return out
	if a.has("needs_fact") and not has_fact(str(a.needs_fact), p):
		out.state = str(a.get("sealed_as", "sealed"))
		out.open = false
		return out
	var ok := true
	for need: String in a.get("requires", []):
		ok = ok and cleared.has(need)
	if a.has("requires_any"):
		var n := 0
		for need: String in a.requires_any.of:
			n += 1 if cleared.has(need) else 0
		ok = ok and n >= int(a.requires_any.count)
	if not ok:
		out.state = "locked"
		out.open = false
	return out

static func unlocked(region: String, p: Dictionary = Game.profile) -> bool:
	return bool(access(generation(p), region, p).open)

## A region a generation can never enter, whatever it does (locked by progress is not sealed).
static func sealed(gen: int, region: String, p: Dictionary = Game.profile) -> bool:
	return not str(access(gen, region, p).state) in ["open", "passed", "locked"]

# ================================================================ the ways onward at a stop
## A mortal individual that fell in an earlier generation does not stand again.
static func may_stand(gen: int, foe_id: String, p: Dictionary = Game.profile) -> bool:
	var who := individual(foe_id)
	if not data().mortals.has(who) and not (variants.has(who) and variants[who].get("mortal", false)):
		return true
	var at := fact_gen("slain:" + who, p)
	return at == 0 or at >= gen

## The options of a stop, in the shape regions.json uses. Generation II: the road's own. [] for a region that
## generation cannot enter. Foes are named as authored: cast() gives the one that is actually fought.
static func options(gen: int, region: String, stage: int, p: Dictionary = Game.profile) -> Array:
	var base: Array = Db.region_by_id[region].stages[stage].options
	if gen == 2:
		return base
	if sealed(gen, region, p):
		return []
	var t: Dictionary = data().stops.get(str(gen), {}).get(region, {})
	var out: Array = []
	if not t.has(str(stage)):
		if gen == 1:
			return [_pass("Walk On", "Nobody bars the way.")]
		for o: Dictionary in base:
			if not o.has("foe") or may_stand(gen, str(o.foe), p):
				out.append(o)
	else:
		for o: Dictionary in t[str(stage)]:
			if o.has("when") and not has_fact(str(o.when), p):
				continue
			if o.has("unless") and has_fact(str(o.unless), p):
				continue
			if o.has("foe") and not may_stand(gen, str(o.foe), p):
				continue
			if o.has("keep"):
				for b: Dictionary in base:
					if str(b.label) == str(o.keep):
						out.append(b)
			else:
				out.append(o)
	if out.is_empty():
		out.append(_pass("Press On", "Nothing stands here now."))
	return out

static func _pass(label: String, hint: String) -> Dictionary:
	return {"type": "pass", "label": label, "hint": hint}

## The foe an authored id is fought as in this generation: itself in Generation II and for anything already a
## variant; in Generation III a copy brought up to the end of the road (`<id>_g3`). Always an id that is in Db.foes.
static func cast(gen: int, foe_id: String, p: Dictionary = Game.profile) -> String:
	data()
	if foe_id == str(_d.echo.id) or variants.has(foe_id):
		return foe_id if not foe(foe_id, p).is_empty() else ""
	if gen == 3 and Db.foes.has(foe_id) and not Db.foes[foe_id].get("variant", false):
		return foe_id + "_g3" if not foe(foe_id + "_g3", p).is_empty() else ""
	return foe_id if Db.foes.has(foe_id) else ""

## One stop, resolved: {options (foes cast, each fight carrying `was` = the authored id and `why` where the world
## explains it), state}. Pools are left for Game.stage_options, which fixes them for the run.
static func stop(gen: int, region: String, stage: int, p: Dictionary = Game.profile) -> Dictionary:
	var out: Array = []
	for o: Dictionary in options(gen, region, stage, p):
		if o.has("foe"):
			var c: Dictionary = o.duplicate()
			c["was"] = str(o.foe)
			c.foe = cast(gen, str(o.foe), p)
			c["why"] = why(str(o.foe))
			if o.has("foes"):
				c.foes = o.foes.map(func(id): return cast(gen, str(id), p))
			out.append(c)
		else:
			out.append(o)
	return {"options": out, "state": str(access(gen, region, p).state)}

## Why this one stands where another stood ("" when nobody asks).
static func why(foe_id: String) -> String:
	data()
	if variants.has(foe_id):
		return str(variants[foe_id].get("reason", ""))
	for m: String in _d.mortals:
		if str(_d.mortals[m].after) == foe_id:
			return str(_d.mortals[m].why)
	return ""

## Who keeps a region in a generation: {id, name, title, was (who kept it in Generation II), why} or {} for none.
static func guardian(gen: int, region: String, p: Dictionary = Game.profile) -> Dictionary:
	var last: int = Db.region_by_id[region].stages.size() - 1
	for o: Dictionary in stop(gen, region, last, p).options:
		if str(o.type) == "boss" and str(o.foe) != "":
			var f: Dictionary = Db.foes[o.foe]
			var before := ""
			for b: Dictionary in Db.region_by_id[region].stages[last].options:
				before = str(b.get("foe", before))
			return {"id": str(o.foe), "name": str(f.name), "title": str(f.get("title", "")), "was": before, "why": str(o.get("why", ""))}
	return {}

## Everything a map needs about one region now: {id, name, state, open, optional, why, guardian, fights}.
static func region_info(region: String, p: Dictionary = Game.profile) -> Dictionary:
	var gen := generation(p)
	var out := access(gen, region, p)
	out["id"] = region
	out["name"] = str(Db.region_by_id[region].name)
	out["guardian"] = {} if sealed(gen, region, p) else guardian(gen, region, p)
	out["fights"] = route(gen, region, p).size()
	return out

## The fights of a region in order, one per stop where there is one (the road first, then anything optional):
## [{region, stop, foe, type, optional, label}].
static func route(gen: int, region: String, p: Dictionary = Game.profile) -> Array:
	var out: Array = []
	if sealed(gen, region, p):
		return out
	for i: int in Db.region_by_id[region].stages.size():
		var opts: Array = stop(gen, region, i, p).options
		var free := false                       # is there a way past this stop without drawing steel?
		for o: Dictionary in opts:
			free = free or not o.has("foe")
		for o: Dictionary in opts:
			if o.has("foe"):
				out.append({"region": region, "stop": i, "foe": str(o.foe), "type": str(o.type), "label": str(o.label),
					"optional": bool(o.get("optional", false)) or free})
	return out

# ================================================================ casting
## Builds (or rebuilds) a generational foe and adds it to Db.foes: an authored variant, a Generation III copy
## (`<id>_g3`), the echo, or the Monarch's last form. {} for an id that is none of these.
static func foe(id: String, p: Dictionary = Game.profile) -> Dictionary:
	data()
	var f: Dictionary = {}
	if id == str(_d.echo.id):
		f = Generations.echo_foe(p)
	elif variants.has(id):
		f = _variant(variants[id])
		if int(variants[id].get("monarch", 0)) == 3:
			Generations.monarch_final(f, variants[id], p)
	elif id.ends_with("_g3"):
		var src := id.trim_suffix("_g3")
		if variants.has(src):
			f = _variant(variants[src])
		elif Db.foes.has(src):
			f = _tuned(src)
	if f.is_empty():
		return f
	f.id = id
	Db.foes[id] = f
	return f

static func _scale(f: Dictionary, hp: float, dmg: float, speed: float) -> void:
	f.hp = roundi(float(f.hp) * hp)
	f.punish.dmg = roundi(float(f.punish.dmg) * dmg)
	for ph: Dictionary in f.phases:
		var slowest := 100.0                   # a blow stays readable however it is tuned (tests: 0.45 s)
		for combo: Dictionary in ph.combos:
			for i: int in combo.attacks.size():
				var a: Dictionary = combo.attacks[i]
				a.dmg = roundi(float(a.dmg) * dmg)
				if a.has("guard"):
					a.guard = roundi(float(a.guard) * dmg)
				slowest = minf(slowest, float(a.windup) + (float(combo.gap) if i > 0 else 0.0))
		ph.speed = minf(float(ph.speed) * speed, slowest / 0.46)

static func _variant(v: Dictionary) -> Dictionary:
	var f: Dictionary = Db.foes[str(v.base)].duplicate(true)
	var own_model := "res://assets/models/%s.glb" % str(v.base)
	f["variant"] = true
	f["base"] = str(v.base)
	f["gen"] = int(v.get("gen", 0))
	f["reward_as"] = str(v.base)
	f.name = str(v.name)
	f.title = str(v.get("title", ""))
	f.boss = bool(v.get("boss", f.boss))
	if v.has("intro"):
		f["intro"] = str(v.intro)
	if v.get("phases") is Array and not v.phases.is_empty():
		if v.phases[0] is Dictionary:
			f.phases = v.phases.duplicate(true)
		else:
			var kept: Array = []
			for i in v.phases:
				kept.append(f.phases[int(i)])
			f.phases = kept
			f.phases[0].at = 1.0
	if v.has("traits"):
		f["traits"] = v.traits.duplicate()
	for k: String in v.get("rig", {}):
		f.rig[k] = v.rig[k]
	if ResourceLoader.exists(own_model) and not f.rig.has("skin"):
		f.rig["skin"] = own_model           # it is the same body: the duel looks for a model under the foe's own id
	if v.has("carry"):
		f.rig.merge(Duel.weapon_model(str(v.carry)), true)
	if f.boss and not Db.foes[str(v.base)].boss:
		f["poise"] = roundi(float(f.get("poise", 60)) * 1.6)
		f["music"] = "boss"
	_scale(f, float(v.get("hp", 1.0)), float(v.get("dmg", 1.0)), float(v.get("speed", 1.0)))
	f.xp = roundi(float(f.xp) * float(v.get("xp", 1.0)))
	f.gold = roundi(float(f.gold) * float(v.get("gold", 1.0)))
	f.loot = []
	if v.has("clash"):
		f["clash"] = v.clash.duplicate()
	return f

## A roster foe as Generation III meets it: the same foe, its numbers brought up to the end of the road.
static func _tuned(src: String) -> Dictionary:
	var f: Dictionary = Db.foes[src].duplicate(true)
	var t: Dictionary = data().tuning["3"]
	var r: Dictionary = t.regions.get(str(f.region), {"hp": 1.0, "dmg": 1.0, "xp": 1.0, "gold": 1.0})
	var hp := float(r.hp)
	var dmg := float(r.dmg)
	if f.boss:
		hp = clampf(float(t.boss_hp_target) / float(f.hp), float(t.boss_hp_range[0]), float(t.boss_hp_range[1]))
		dmg = 1.0 + (dmg - 1.0) * float(t.boss_dmg_share)
	f["variant"] = true
	f["base"] = src
	f["gen"] = 3
	f["reward_as"] = src
	f["shard_mult"] = float(t.get("shards", 1.0))
	var own_model := "res://assets/models/%s.glb" % src
	if ResourceLoader.exists(own_model) and not f.rig.has("skin"):
		f.rig["skin"] = own_model
	if Duel.BOSS_WEAPON.has(src):
		f.rig.merge(Duel.weapon_model(str(Duel.BOSS_WEAPON[src])), true)
	_scale(f, hp, dmg, 1.0)
	f.xp = roundi(float(f.xp) * (hp if f.boss else float(r.xp)))
	f.gold = roundi(float(f.gold) * (hp if f.boss else float(r.gold)))
	return f

## Every id the director can cast that is not on the roster, built: for tests and for reading files ahead.
static func all_cast() -> Array:
	data()
	var out: Array = [str(_d.echo.id)]
	out.append_array(variants.keys())
	return out
