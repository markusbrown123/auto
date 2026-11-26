class_name KeptScene
extends CineScene
## The Kept (Generation III, the Inner Ward of the Fallen Courtyard): the guardian standing in the Ashen Sentinel's old
## post is the second generation, kept by the Monarch's machinery. It wears what the player wore and carries what the
## player carried (Db.foes["the_kept"].rig, built from the snapshot taken at the second fall).
##   mode "reveal"  before the duel: a figure across the ward with its back to us; the Witness at the heir's hip knows
##                  the walk; the figure turns; the card; the few words it has. Then the duel's own intro.
##   mode "after"   after it is beaten (the duel ends on a yield, not a killing blow): level, no camera move. It
##                  lowers the sword and holds it out, hilt first. Its light goes out standing up.
## The blade it gives is "The Second's Edge": KeptScene.grant_edge() (also called in _closing, so a skip gives it too).
## Dev: hold_at = "back" | "hip" | "turn" | "offer".

const EDGE := "w_seconds_edge"
const POST := Vector3(0, 0, -3.4)

var mode := "reveal"
var arena: Arena
var hero: CineActor
var kept: FighterRig
var granted: Array = []            # ids given by this scene (mode "after")

# ================================================================ the blade it gives
## Lays the snapshot's weapon over the data's plain entry for The Second's Edge, so the item is a copy of the blade
## the second generation carried (its class, its numbers, its model), under its own name. Safe to call at any time;
## with no snapshot it is a copy of the starting sword.
static func sync_edge(p: Dictionary = Game.profile) -> void:
	if not Db.items.has(EDGE):
		return
	var snap: Dictionary = Generations.echo_snapshot(p) if not p.is_empty() else {}
	var src_id := str(snap.get("weapon", {}).get("id", "w_rusted_sword"))
	var src: Dictionary = Db.item(src_id)
	if src.is_empty() or src_id == EDGE:
		return
	var it: Dictionary = Db.items[EDGE]
	for k: String in ["cls", "damage", "crit", "element", "look", "visual", "model", "gear_id", "gear_ready", "weight", "req", "advanced", "family", "mat"]:
		if src.has(k):
			it[k] = src[k].duplicate(true) if (src[k] is Dictionary or src[k] is Array) else src[k]
		else:
			it.erase(k)
	it["copy_of"] = src_id

## Gives The Second's Edge once, with the forge work the second generation's blade carried (tier, grip, ore, edge).
## Returns the id when it was given now, "" when it was already held.
static func grant_edge() -> String:
	if Game.profile.is_empty() or not Db.items.has(EDGE):
		return ""
	sync_edge()
	if Game.owns(EDGE):
		return ""
	Game.grant_item(EDGE)
	var w: Dictionary = Generations.echo_snapshot(Game.profile).get("weapon", {})
	if int(w.get("level", 0)) > 0:
		Game.profile.upgrades[EDGE] = int(w.level)
	var mods: Dictionary = w.get("mods", {})
	if int(mods.get("grip", 0)) > 0 or int(mods.get("ore", 0)) > 0:
		Game.profile.mods[EDGE] = {"grip": int(mods.get("grip", 0)), "ore": int(mods.get("ore", 0)), "ore_id": str(mods.get("ore_id", ""))}
	if int(w.get("edge", 0)) > 0:
		Game.profile.edge[EDGE] = int(w.edge)
	Game.profile.flags["kept_released"] = true
	Game.save()
	return EDGE

## How the Kept is drawn: its saved look, through the same path the duel dresses a foe by.
static func kept_look() -> Dictionary:
	if not Db.foes.has("the_kept"):
		Game.echo_foe()
	return CineActor.foe_look("the_kept")

# ================================================================ the scene
func _ready() -> void:
	begin()
	var foe: Dictionary = Db.foes["the_kept"] if Db.foes.has("the_kept") else Game.echo_foe()
	var region: Dictionary = Db.region_by_id[str(foe.region)]
	arena = Arena.new()
	add_child(arena)
	arena.build(Arena.theme_for(region.theme, str(foe.get("arena", ""))))
	hero = CineActor.knight(self)
	hero.footsteps = true
	kept = FighterRig.new()
	add_child(kept)
	kept.build(kept_look(), true)
	kept.position = POST
	Sfx.ambience(str(region.amb))
	Sfx.music("", 1.5)                # no music: the ward, and the wind in it
	if mode == "after":
		_after()
	else:
		_reveal()

func _reveal() -> void:
	# K1: across the ward to the Sentinel's post. A figure with its back to us, in armour the player knows.
	kept.rotation.y = 0.0             # facing away from the gate, as a foe faces +Z when turned to PI
	kept.time_scale = 0.35
	hero.position = Vector3(0.7, 0, 9.5)
	hero.rotation.y = 0.0
	cam.cut(Vector3(2.6, 1.5, 12.2), POST + Vector3(0, 1.2, 0), 36.0)
	cam.move(Vector3(2.2, 1.45, 11.0), POST + Vector3(0, 1.25, 0), 9.0)
	cards.fade(0.0, 1.4)
	walk(hero, Vector3(0.7, 0, 5.6), 1.2)
	if not await _w(3.6):
		return
	if _held("back"):
		return
	# K2: the mask at the heir's hip
	Story.play("kept_approach", true)
	Companion.mark_heard("kept_approach")
	hero.walking = false
	var hip := hero.position + Vector3(0.24, 0.72, 0.06)
	cam.cut(hip + Vector3(0.95, 0.12, 0.75), hip, 30.0)
	cam.move(hip + Vector3(0.85, 0.16, 0.6), hip, 8.0)
	var ember := OmniLight3D.new()
	ember.light_color = Color("#ffb347")
	ember.light_energy = 0.9
	ember.omni_range = 1.4
	ember.position = hip + Vector3(0.12, 0.0, 0.1)
	add_child(ember)
	var gutter := create_tween().set_loops()
	gutter.tween_property(ember, "light_energy", 0.25, 0.22)
	gutter.tween_property(ember, "light_energy", 1.1, 0.3)
	if _held("hip"):
		return
	if not await _line("kept_approach", 1):
		return
	cam.cut(Vector3(2.0, 1.5, 8.6), POST + Vector3(0, 1.25, 0), 30.0)
	cam.move(Vector3(1.8, 1.5, 8.0), POST + Vector3(0, 1.25, 0), 6.0)
	if not await _line("kept_approach", 2):
		return
	cam.cut(hip + Vector3(0.95, 0.12, 0.75), hip, 30.0)
	if not await _spoken():
		return
	gutter.kill()
	ember.queue_free()
	# K3: it turns. Low, from the floor: the framing the Throne Guard had in the first generation.
	kept.time_scale = 1.0
	cam.cut(POST + Vector3(1.9, 0.4, 2.9), POST + Vector3(0, 1.45, 0), 40.0)
	cam.move(POST + Vector3(1.5, 0.45, 3.3), POST + Vector3(0, 1.5, 0), 5.0)
	Sfx.play("armor", -4.0, 0.7)
	kept.create_tween().tween_property(kept, "rotation:y", PI, 1.6).set_trans(Tween.TRANS_SINE)
	if not await _w(1.9):
		return
	kept.guard()
	cards.show_card(str(Db.foes["the_kept"].name).to_upper(), 3.0)
	Sfx.play("bell", -6.0, 0.7)
	if _held("turn"):
		cards.card.modulate.a = 1.0
		return
	if not await _w(1.6):
		return
	Story.play("kept_intro", true)
	if not Game.profile.is_empty():
		Game.profile.flags["scene_kept_intro"] = true
	if not await _line("kept_intro", 1):
		return
	cam.cut(hero.position + Vector3(-0.9, 1.5, -1.5), hero.position + Vector3(0, 1.45, 0), 34.0)
	if not await _line("kept_intro", 2):
		return
	cam.cut(POST + Vector3(0.8, 1.5, 1.7), POST + Vector3(0, 1.55, 0), 30.0)
	cam.move(POST + Vector3(0.7, 1.52, 1.5), POST + Vector3(0, 1.55, 0), 5.0)
	if not await _spoken():
		return
	if not await _w(0.6):
		return
	await cards.fade(1.0, 0.4)
	_end()

func _after() -> void:
	# K4: level, both in frame, and the camera does not move
	cam.drift = 0.0
	kept.rotation.y = PI
	kept.position = Vector3(0, 0, -1.1)
	hero.position = Vector3(0, 0, 1.1)
	hero.rotation.y = 0.0
	hero.guard()
	kept.recover()
	cam.cut(Vector3(4.3, 1.25, 0.0), Vector3(0, 1.15, 0), 36.0)
	cards.fade(0.0, 1.2)
	if not await _w(2.2):
		return
	Story.play("kept_after", true)
	if not await _line("kept_after", 1):
		return
	# hilt first: the blade leaves its hand and crosses the space between them
	var blade := Node3D.new()
	add_child(blade)
	var look: Dictionary = kept.cfg
	var model := str(look.get("weapon_model", ""))
	if PropModel.exists(model):
		PropModel.weapon(blade, model, str(look.get("weapon", "sword")), look.get("weapon_tint"), float(look.get("weapon_scale", 1.0)))
	else:
		kept._weapon_mesh(blade, str(look.get("weapon", "sword")), look)
	blade.rotation = Vector3(deg_to_rad(-90.0), 0, 0)         # along the line between them, point toward the Kept
	blade.position = Vector3(0.05, 1.12, -0.75)
	kept.weapon_r.visible = false
	Sfx.play("armor", -8.0, 0.8)
	create_tween().tween_property(blade, "position:z", -0.1, 2.4).set_trans(Tween.TRANS_SINE)
	if _held("offer"):
		return
	if not await _line("kept_after", 2):
		return
	granted = [grant_edge()] if grant_edge_due() else []
	Sfx.play("loot", -4.0)
	create_tween().tween_property(blade, "position:z", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
	# its light goes out, and it is still standing
	if kept.eye_light:
		create_tween().tween_property(kept.eye_light, "light_energy", 0.0, 2.4)
	kept.time_scale = 0.15
	if not await _spoken():
		return
	kept.time_scale = 0.0
	if not await _w(2.4):
		return
	await cards.fade(1.0, 1.2)
	_end()

func grant_edge_due() -> bool:
	return not Game.profile.is_empty() and not Game.owns(EDGE)

func _closing() -> void:
	if mode == "after":
		if grant_edge_due():
			granted = [grant_edge()]
	elif not Game.profile.is_empty():
		Game.profile.flags["kept_revealed"] = true
		Game.profile.flags["scene_kept_intro"] = true
		Companion.mark_heard("kept_approach")
