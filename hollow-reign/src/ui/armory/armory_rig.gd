class_name ArmoryRig
extends FighterRig
## The knight as it stands in the armoury: the same rig as in a duel, but played from authored whole-body
## clips chosen by the screen (a breathing idle for the weapon class, a preview cut, a block) instead of
## by a fight. Only the choice of clip is replaced; posing, grips and prop fitting are the rig's own.

signal act_finished

var idle_clip := ""          # looping; "" leaves the rig's own guard pose
var motion := 1.0            # 0 freezes the idle (reduced motion)
var _cur := ""
var _cur_t := 0.0
var _w := 0.0
var _act := ""               # a clip played once over the idle
var _act_t := 0.0
var _act_from := 0.0
var _act_to := 0.0
var _hold := ""              # a looping clip held after the act (a raised shield)
var _hold_left := 0.0
var _dip := 0.0              # seconds left of a lower-and-raise (a short weapon change)
const DIP := 0.42

## The rig carries a shield with its decorated face toward the wielder's own body: right for the duel, where the
## camera stands behind the knight, and wrong here, where the knight is seen from the front (the plain back and its
## grip would face the viewer, with the hand apparently on the shield's face). Here the board is turned about.
func set_shield(look) -> void:
	super(look)
	if shield and look != null and PropModel.exists(str(look.get("model", ""))) and shield.get_child_count() > 0:
		var m: Node3D = shield.get_child(0)
		m.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * m.transform

## Plays `clip` once (optionally only [from, to] seconds of it), then `hold` looping for `hold_time`, then the idle.
func play_once(clip: String, from: float = 0.0, to: float = -1.0, hold: String = "", hold_time: float = 0.0) -> bool:
	if not SkinDriver.has_clip(clip):
		return false
	_act = clip
	_act_from = from
	_act_to = SkinDriver.clip_length(clip) if to < 0.0 else to
	_act_t = from
	_hold = hold if SkinDriver.has_clip(hold) else ""
	_hold_left = hold_time
	return true

func stop_act() -> void:
	_act = ""
	_hold_left = 0.0

## The short weapon change: the stance sinks out of the clip and comes back up with the new piece in hand.
func dip() -> void:
	_dip = DIP

func acting() -> bool:
	return _act != "" or _hold_left > 0.0 or _dip > 0.0

func _pick_clip() -> void:
	var dt := get_process_delta_time() * time_scale
	var want := idle_clip
	var t := _clock * motion
	var target_w := 1.0
	if _act != "":
		_act_t += dt
		want = _act
		t = _act_t
		if _act_t >= _act_to:
			_act = ""
			if _hold == "" or _hold_left <= 0.0:
				act_finished.emit()
	elif _hold_left > 0.0:
		_hold_left -= dt
		want = _hold
		t = _clock
		if _hold_left <= 0.0:
			act_finished.emit()
	if _dip > 0.0:
		_dip -= dt
		# down to a third of the clip and back: the arms pass through the rig's own low guard
		target_w = 0.3 + 0.7 * absf(_dip / DIP * 2.0 - 1.0)
	if want == "" or not SkinDriver.has_clip(want):
		_w = 0.0
		skin.clip_w = 0.0
		return
	if want != _cur:
		# a change of clip: the new one comes in quickly from most of the way, so there is no held pose between them
		_w = minf(_w, 0.55) if _cur != "" else 1.0
		_cur = want
	_w = lerpf(_w, target_w, 1.0 - exp(-dt * 14.0)) if dt > 0.0 else _w
	if _dip > 0.0:
		_w = minf(_w, target_w)
	skin.clip = want
	skin.clip_t = t
	skin.clip_full = true
	skin.clip_travel = 0.0
	skin.clip_w = clampf(_w, 0.0, 1.0)
