class_name CineActor
extends FighterRig
## A fighter rig for the story scenes. Everything the duel rig does it still does; on top of that it can
## hold an authored whole-body clip (seated and hurt, standing at ease), cross-fade from one to another
## slowly enough to read as an action, and go unarmed with its arms swinging as it walks.

var armed := true                 # false: sword and shield are not in the hands yet
var _a := ""                      # the clip held underneath
var _b := ""                      # the clip being faded in over it
var _ta := 0.0
var _tb := 0.0
var _mix := 0.0
var _mix_rate := 1.0
var _w := 0.0                     # how much of the held clips shows over the rig's own pose
var _w_to := 0.0
var _w_rate := 2.0

func _init() -> void:
	rest_carry = true             # in the story scenes a standing knight carries the sword low, not in a guard

## Builds the player's knight exactly as the duel does, with whatever is equipped.
static func knight(parent: Node) -> CineActor:
	var a := CineActor.new()
	parent.add_child(a)
	a.build(Duel.player_look(), false)
	return a

## What a foe looks like in a duel (its own model or its class's, and the weapon it carries), for showing it elsewhere.
static func foe_look(foe_id: String) -> Dictionary:
	var foe: Dictionary = Db.foes[foe_id]
	var look: Dictionary = foe.rig.duplicate()
	for candidate: String in ["res://assets/models/%s.glb" % foe_id, "res://assets/models/cls_%s.glb" % str(foe.get("cls", "")).to_lower().replace("-", "_")]:
		if ResourceLoader.exists(candidate):
			look["skin"] = candidate
			if not foe.boss:
				look["skin_tint"] = foe.rig.get("metal", "#888888")
			break
	Duel.dress_foe(look)
	var carried: String = Duel.BOSS_WEAPON.get(foe_id, Duel.FOE_WEAPON.get(str(foe.rig.get("weapon", "")), ""))
	if carried != "":
		look.merge(Duel.weapon_model(carried))
	return look

## The model files a duel against this foe will need, for reading ahead of time.
static func foe_files(foe_id: String) -> Array:
	var foe: Dictionary = Db.foes.get(foe_id, {})
	return ["res://assets/models/knight_%s.glb" % str(Game.profile.get("body", "m")), "res://assets/models/%s.glb" % foe_id,
		"res://assets/models/cls_%s.glb" % str(foe.get("cls", "")).to_lower().replace("-", "_")]

## Holds a whole-body clip, easing into it over `blend` seconds from whatever is showing.
func hold(clip: String, blend: float = 0.6) -> void:
	if not SkinDriver.has_clip(clip):
		return
	if _w <= 0.01 and _w_to <= 0.0:
		_a = clip
		_b = ""
		_ta = 0.0
		_mix = 0.0
	else:
		if _b != "" and _mix > 0.5:
			_a = _b
			_ta = _tb
		_b = clip
		_tb = 0.0
		_mix = 0.0
		_mix_rate = 1.0 / maxf(blend, 0.01)
	_w_to = 1.0
	_w_rate = 1.0 / maxf(blend, 0.01)
	if blend <= 0.0:
		_w = 1.0

## Back to the rig's own pose (guard, walk) over `blend` seconds.
func release(blend: float = 0.5) -> void:
	_w_to = 0.0
	_w_rate = 1.0 / maxf(blend, 0.01)

func holding() -> bool:
	return _w_to > 0.0

func set_armed(on: bool) -> void:
	armed = on
	weapon_r.visible = on
	weapon_l.visible = on
	if shield:
		shield.visible = on

func _process(delta: float) -> void:
	super(delta)
	if skin == null:
		return
	var dt := delta * time_scale
	_ta += dt
	_tb += dt
	_w = move_toward(_w, _w_to, dt * _w_rate)
	if _b != "":
		_mix = move_toward(_mix, 1.0, dt * _mix_rate)
		if _mix >= 1.0:
			_a = _b
			_ta = _tb
			_b = ""
			_mix = 0.0
	var keep := [skin.clip, skin.clip_t, skin.clip_w, skin.clip_full]
	var touched := false
	if not armed and _walk_amount > 0.01 and SkinDriver.has_clip("walk"):
		# empty hands swing with the stride instead of holding a guard
		_layer("walk", _walk_phase / TAU * SkinDriver.clip_length("walk") / WALK_CYCLES, _walk_amount, true)
		touched = true
	if _w > 0.0 and _a != "":
		var w := smoothstep(0.0, 1.0, _w)
		_layer(_a, _ta, w, false)
		if _b != "":
			_layer(_b, _tb, w * smoothstep(0.0, 1.0, _mix), false)
		touched = true
	skin.clip = keep[0]
	skin.clip_t = keep[1]
	skin.clip_w = keep[2]
	skin.clip_full = keep[3]
	if touched and armed:
		# the weapons ride the hands the clips have just moved
		var back: Transform3D = skin.root.transform * (skin.root.global_transform.affine_inverse() * skin.skel.global_transform)
		weapon_r.position = back * skin._palm("Right", skin.skel.get_bone_global_pose(skin.bone["RightHand"]).origin)
		weapon_l.position = back * skin._palm("Left", skin.skel.get_bone_global_pose(skin.bone["LeftHand"]).origin)
		if shield:
			shield.position = weapon_l.position + Vector3(-0.02, 0, -0.07)

func _layer(clip: String, t: float, w: float, arms_only: bool) -> void:
	skin.clip = clip
	skin.clip_t = t
	skin.clip_w = w
	skin.clip_full = true
	if not arms_only:
		skin._overlay(false)
	skin._overlay(true)
