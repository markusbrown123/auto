extends Node
## The companions on the road: the Witness (the mask at the knight's belt) and
## Lyra. Chooses which of their lines an event deserves and plays it through
## Story. The lines and the tables that place them are in data/dialogue.json
## under "companion", "speech" and "foe_voice" (written by tools/gen_dialogue.py).
##
## Rules kept here, so no screen has to know them:
## - a scene is heard once and never again, death or no death (profile.heard);
## - unprompted remarks keep a cooldown between them;
## - Game.settings "chatter" = false silences everything that is not essential;
## - nothing is said while a duel is being fought;
## - the Witness says nothing until its discovery scene has played.

const FOUND_FLAG := "witness_found"
const MAX_REMARKS_PER_STOP := 2

var cooldown := 20.0          ## seconds between unprompted remarks
var _last_remark_ms := -1000000
var _duel: WeakRef = null

# ================================================================ data
func _c() -> Dictionary:
	return Story.data.get("companion", {})

func _scene(id: String) -> Dictionary:
	return Story.data.get("scenes", {}).get(id, {})

## "A" creature (no human speech), "B" a few short lines, "C" directed dialogue, "D" fragments only.
func speech(foe_id: String) -> String:
	return str(Story.data.get("speech", {}).get(foe_id, "A"))

## Prefix of a foe's own scenes (<key>_intro, _retry, _death, _memory); "" for anything that does not speak.
func voice_key(foe_id: String) -> String:
	if speech(foe_id) == "A":
		return ""
	return str(Story.data.get("foe_voice", {}).get(foe_id, ""))

func discovery_id() -> String:
	return str(_c().get("discovery", {}).get("scene", ""))

func title(id: String) -> String:
	return str(_scene(id).get("title", id.capitalize()))

func speakers(id: String) -> Array:
	var out: Array = []
	for lid: String in _scene(id).get("lines", []):
		var who := str(Story.data.lines[lid].speaker)
		if not out.has(who):
			out.append(who)
	return out

func essential(id: String) -> bool:
	return bool(_scene(id).get("essential", false))

# ================================================================ state
func witness_found() -> bool:
	return not Game.profile.is_empty() and Game.profile.flags.has(FOUND_FLAG)

func chatter_on() -> bool:
	return bool(Game.settings.get("chatter", true))

func heard(id: String) -> bool:
	if Game.profile.is_empty():
		return false
	return Game.profile.get("heard", []).has(id) or (bool(_scene(id).get("once", true)) and Story.seen(id))

func mark_heard(id: String) -> void:
	if Game.profile.is_empty():
		return
	if not Game.profile.has("heard"):
		Game.profile["heard"] = []
	if not Game.profile.heard.has(id):
		Game.profile.heard.append(id)
	if id == discovery_id():
		Game.profile.flags[FOUND_FLAG] = true

## The duel calls these as steel is drawn and when the fight is decided.
func enter_combat(duel: Node) -> void:
	_duel = weakref(duel)

func leave_combat() -> void:
	_duel = null

func in_combat() -> bool:
	if _duel == null:
		return false
	var d = _duel.get_ref()
	return d != null and (d as Node).is_inside_tree()

func cooling() -> bool:
	return float(Time.get_ticks_msec() - _last_remark_ms) < cooldown * 1000.0

func note_spoken() -> void:
	_last_remark_ms = Time.get_ticks_msec()

func reset_cooldown() -> void:
	_last_remark_ms = -1000000

## Whether a scene may be played now. Prompted scenes (a boss, a victory) ignore the cooldown.
func _wanted(id: String, prompted: bool) -> bool:
	if not Story.has_scene(id) or heard(id) or in_combat():
		return false
	if id != discovery_id() and speakers(id).has("witness") and not witness_found():
		return false
	if essential(id):
		return true
	return chatter_on() and (prompted or not cooling())

# ================================================================ choosing
## Scene ids that arriving at this stop would play now, in order.
func pick_stage(region_id: String, stage: int) -> Array:
	if Game.profile.is_empty() or in_combat():
		return []
	var disc: Dictionary = _c().get("discovery", {})
	var d := discovery_id()
	# found where it was left; a save that is already past that stop finds it at the next one
	var due: bool = region_id != str(disc.get("region", "")) or stage >= int(disc.get("stage", 0))
	if d != "" and due and not witness_found() and _wanted(d, true):
		return [d]
	var out: Array = []
	var ids: Array = ["%s_%d" % [region_id, stage]]          # Lyra's remark on the place, where one exists
	ids.append_array(_c().get("stage", {}).get(region_id, {}).get(str(stage), []))
	for id: String in ids:
		if out.size() < MAX_REMARKS_PER_STOP and _wanted(id, false):
			out.append(id)
	return out

## What is said before a guardian: context from the Witness, or Lyra's older line where the Witness cannot give it.
func pick_boss_approach(foe_id: String) -> Array:
	var b: Dictionary = _c().get("boss", {}).get(foe_id, {})
	var out: Array = []
	for id: String in b.get("approach", []):
		if _wanted(id, true):
			out.append(id)
	if out.is_empty():
		for id: String in b.get("fallback", []):
			var covered := false
			for a: String in b.get("approach", []):
				covered = covered or heard(a)
			if not covered and _wanted(id, true):
				out.append(id)
	return out

func pick_victory(foe_id: String) -> Array:
	var out: Array = []
	for id: String in _c().get("boss", {}).get(foe_id, {}).get("victory", []):
		if _wanted(id, true):
			out.append(id)
	return out

# ================================================================ events
func _say(ids: Array) -> void:
	for id: String in ids:
		if in_combat() or (Story.busy and not essential(id)):
			continue
		mark_heard(id)
		await Story.play(id, true)
	if not ids.is_empty():
		note_spoken()

## Arriving at a stop on a region's road. Await it to hold the choices back until the words are done.
func on_stage(region_id: String, stage: int) -> void:
	await _say(pick_stage(region_id, stage))

## Before a guardian's own first words (or instead of them, for a creature). Await it.
func on_boss_approach(foe_id: String) -> void:
	await _say(pick_boss_approach(foe_id))

## After the guardian's last words and memory record.
func on_victory(foe_id: String) -> void:
	await _say(pick_victory(foe_id))

# ================================================================ sanctuary and archive
## Optional conversations open to the player now: [{id, title, heard, speakers}], unheard first.
func sanctuary_topics() -> Array:
	var fresh: Array = []
	var old: Array = []
	if Game.profile.is_empty() or not witness_found():
		return fresh
	for t: Dictionary in _c().get("topics", []):
		var id := str(t.id)
		if not Story.has_scene(id) or (t.has("after") and not Game.profile.cleared.has(t.after)):
			continue
		var e := {"id": id, "title": title(id), "heard": heard(id), "speakers": speakers(id)}
		if e.heard:
			old.append(e)
		else:
			fresh.append(e)
	return fresh + old

## The player asked for it, so it plays whether heard before or not. Await it.
func play_topic(id: String) -> void:
	if in_combat() or not Story.has_scene(id) or (speakers(id).has("witness") and not witness_found()):
		return
	mark_heard(id)
	await Story.play(id, true)

## Everything heard so far, in the order it was heard:
## [{id, title, kind, speakers, lines: [{speaker, name, text}]}].
func archive() -> Array:
	var out: Array = []
	if Game.profile.is_empty():
		return out
	for id: String in Game.profile.get("heard", []):
		if not Story.has_scene(id):
			continue
		var lines: Array = []
		for lid: String in _scene(id).lines:
			var l: Dictionary = Story.data.lines[lid]
			lines.append({"speaker": l.speaker, "name": str(Story.data.names.get(l.speaker, "")), "text": l.text})
		out.append({"id": id, "title": title(id), "kind": str(_scene(id).get("kind", "")), "speakers": speakers(id), "lines": lines})
	return out
