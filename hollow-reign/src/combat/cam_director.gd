class_name CamDirector
extends RefCounted
## The duel's cinematographer: owns the Camera3D pose every frame (docs/CAMERA_BIBLE.md).
##
## Every shot is a small function returning {pos, look, fov, roll, rate} in the duel's *ring frame*:
## the knight stands at +Z, the foe at -Z facing +Z, +X is the knight's sword side. The finished pose
## is rotated by Basis(UP, duel.ring_cam), so every shot follows the fight as it circles.
## The camera stays on the +X side of the fighters' line throughout, so the knight is always
## screen-left and the foe screen-right, in every shot.
##
## Base state (COMBAT / GUARD / OPENING) is chosen each frame from the sim. `cue()` asks for a
## higher-priority shot for a while. During the fight every change is an ease; hard cuts happen only
## in the INTRO / FINISHER / DEATH stages.

const PRIORITY := {"exchange": 1, "phase": 3, "clash": 4, "struggle": 5, "reveal": 6}
## Combat framing per class of foe. side/back: metres to the knight's sword side / behind the knight;
## y: camera height; fov; look_h: where on the foe to aim, as a multiple of its nominal height;
## look_x: sideways aim (negative puts the foe further right of the knight); wide: how much the
## cinematic shots open up for it.
const CLASS := {
	"humanoid": {"side": 1.3, "back": 1.15, "y": 0.55, "fov": 60.0, "look_h": 0.92, "look_x": -0.15, "wide": 1.0},
	"giant": {"side": 1.45, "back": 1.3, "y": 0.4, "fov": 66.0, "look_h": 1.06, "look_x": -0.2, "wide": 1.0},
	"dragon": {"side": 2.1, "back": 2.6, "y": 0.45, "fov": 72.0, "look_h": 0.8, "look_x": -0.3, "wide": 1.5},
}
const ARENA_R := 8.4          # the arena is about 9 m across its radius: stay inside the props
const MIN_Y := 0.25

var duel: Duel
var cam: Camera3D

var shot := ""                # the shot on screen now
var shot_t := 0.0             # seconds it has been on
var _pos := Vector3.ZERO      # smoothed pose, ring frame
var _look := Vector3.ZERO
var _roll := 0.0
var _started := false
var _cue := ""
var _cue_left := 0.0
var _cue_params := {}
var _tight := 0.0             # 0..1, blows being exchanged: framing tightens
var _tight_left := 0.0
var _wide := 0.0              # 0..1, a roll or big sidestep: framing opens out, then comes back
var _wide_left := 0.0
var cls := "humanoid"         # which CLASS row this foe uses
var _side := 0.0              # drift with the knight's dodges
var _settle := 0.0            # seconds left of the slow settle out of a cinematic into combat
var _ended := ""              # "win" / "loss" once a finisher or death has played
var _noise := FastNoiseLite.new()
# per-frame context
var _K := Vector3.ZERO        # knight's feet, ring frame
var _F := Vector3.ZERO        # foe's feet
var _H := 1.4                 # height to look at on the foe
var _S := 1.0                 # foe scale
var _big := 1.0               # how much room the foe needs (dragons: long as well as tall)
var _dragon := false
var _calm := false            # reduce_motion


func _init(d: Duel, c: Camera3D) -> void:
	duel = d
	cam = c
	_noise.frequency = 2.0


## Ask for a shot. `clash` {at: world point, perfect: bool}, `struggle` {on: bool}, `phase` {},
## `exchange` {} (a blow landed either way: tighten), `reveal` {t: seconds} (intro: back to the low reveal).
func cue(name: String, params: Dictionary = {}) -> void:
	var calm := bool(Game.settings.get("reduce_motion", false))
	match name:
		"exchange":
			if not calm:
				_tight_left = 0.7
			return
		"reposition":
			_wide_left = float(params.get("t", 0.8))
			return
		"struggle":
			if bool(params.get("on", true)):
				_take("struggle", 600.0, params)
			elif _cue == "struggle":
				_cue_left = 0.0
			return
		"clash":
			if calm:
				return      # no punch-ins
			_take("clash", 0.4 if params.get("perfect", false) else 0.3, params)
		"phase":
			_take("phase", 1.5, params)
		"reveal":
			_take("reveal", float(params.get("t", 1.7)), params)

func _take(name: String, dur: float, params: Dictionary) -> void:
	if _cue_left > 0.0 and int(PRIORITY[_cue]) > int(PRIORITY[name]):
		return
	_cue = name
	_cue_left = dur
	_cue_params = params


func update(delta: float, trauma: float, clock: float) -> void:
	_calm = bool(Game.settings.get("reduce_motion", false))
	_context()
	_cue_left = maxf(0.0, _cue_left - delta)
	_tight_left = maxf(0.0, _tight_left - delta)
	_settle = maxf(0.0, _settle - delta)
	_wide_left = maxf(0.0, _wide_left - delta)
	_wide = lerpf(_wide, 1.0 if _wide_left > 0.0 else 0.0, 1.0 - exp(-delta * (5.0 if _wide_left > 0.0 else 2.0)))
	_tight = lerpf(_tight, 1.0 if _tight_left > 0.0 else 0.0, 1.0 - exp(-delta * 5.0))
	_side = lerpf(_side, duel.player_rig._root.x * 0.6, 1.0 - exp(-delta * 5.0))

	var name := _choose()
	var cut := false
	if name != shot:
		# hard cuts only inside the cinematic stages; into and during the fight, always ease
		cut = duel.stage != Duel.Stage.FIGHT and not (duel.stage == Duel.Stage.DONE and _ended == "")
		if shot in ["establish", "reveal", "close_up", "ots", "reverse"] and duel.stage == Duel.Stage.FIGHT:
			_settle = 1.4
		shot = name
		shot_t = 0.0
	shot_t += delta
	var s: Dictionary = call("_shot_" + shot)
	var pos: Vector3 = s.pos
	var look: Vector3 = s.look
	var rate := float(s.get("rate", 6.0))
	if _settle > 0.0:
		rate = minf(rate, 3.0)
	if _calm:
		rate *= 0.6
	if duel.stage == Duel.Stage.FIGHT:
		# never cross the line of action: stay on the knight's sword side of the line between the fighters
		var u := clampf(inverse_lerp(_F.z, _K.z, pos.z), 0.0, 1.3)
		pos.x = maxf(pos.x, lerpf(_F.x, _K.x, u) + 0.7)
	var k := 1.0 - exp(-delta * rate)
	if cut or not _started:
		k = 1.0
		_started = true
	_pos = _pos.lerp(pos, k)
	_look = _look.lerp(look, k)
	_roll = lerpf(_roll, float(s.get("roll", 0.0)), k)
	cam.fov = lerpf(cam.fov, float(s.fov), k)

	var turn := Basis(Vector3.UP, duel.ring_cam)
	var wp := turn * _pos
	# stay inside the arena's props and above the floor
	var flat := Vector2(wp.x, wp.z)
	if flat.length() > ARENA_R:
		flat = flat.normalized() * ARENA_R
	wp = Vector3(flat.x, maxf(wp.y, MIN_Y), flat.y)
	var shake := trauma * trauma * float(Game.settings.shake)
	var off := Vector3(_noise.get_noise_2d(clock * 60.0, 0.0), _noise.get_noise_2d(0.0, clock * 60.0), 0) * 0.16 * shake
	cam.position = wp + off
	cam.look_at(turn * _look + off * 0.5)
	cam.rotation.z += _roll + _noise.get_noise_2d(clock * 50.0, 9.0) * 0.035 * shake


func _context() -> void:
	var foe: Dictionary = duel.foe
	var pz := duel.gap * 0.5
	_S = float(foe.rig.scale)
	_dragon = duel.foe_rig is DragonRig
	cls = "dragon" if _dragon else ("giant" if _S >= 1.3 or str(foe.get("cls", "")) in ["Heavy", "Giant"] else "humanoid")
	_big = _S * float(CLASS[cls].wide)
	_H = 1.4 * _S * (1.0 - float(foe.rig.get("hunch", 0.0)) * 0.3)
	_K = Vector3(duel.p_side, 0, pz + duel.p_back)
	_F = Vector3(0, 0, -pz - duel.f_back)

## World point to ring frame.
func _ring(world: Vector3) -> Vector3:
	return Basis(Vector3.UP, -duel.ring_cam) * world

func _foe_head() -> Vector3:
	var h: Vector3 = _ring(duel.foe_rig.head.global_position) if duel.foe_rig.get("head") != null else _F + Vector3(0, _H * 1.15, 0)
	if h.y < 0.3:      # not posed yet
		h = _F + Vector3(0, _H * 1.15, 0)
	return h

func _mid(y: float) -> Vector3:
	var m := _K.lerp(_F, 0.5)
	return Vector3(m.x, y, m.z)


func _choose() -> String:
	var sim: DuelSim = duel.sim
	match duel.stage:
		Duel.Stage.INTRO:
			return _intro_shot()
		Duel.Stage.FINISHER:
			_ended = "win"
			var t := duel._stage_t
			return "finish_blow" if t < 1.25 else ("finish_fall" if t < 2.4 else "victory")
		Duel.Stage.DEATH:
			_ended = "loss"
			return "death_fall" if duel._stage_t < 1.2 else "defeat"
		Duel.Stage.DONE:
			return "victory" if _ended == "win" else ("defeat" if _ended == "loss" else "combat")
	if _cue_left > 0.0 and _cue != "reveal":
		return _cue
	if sim.boss_open():
		return "opening"
	if sim.b_state == DuelSim.B.WINDUP:
		var a: Dictionary = sim.b_attack
		if str(a.get("kind", "")) in ["slam", "sweep", "breath"] or float(a.get("dmg", 0.0)) >= 30.0:
			return "guard"
	return "combat"

## Establishing wide, low reveal of the foe, close-up, over the shoulder; the fight then eases to combat.
## The silent intro lasts 4.6 s (Duel._process); a spoken one lasts as long as the scene, so after the
## opening three shots it plays shot / reverse-shot on whoever is speaking.
func _intro_shot() -> String:
	var t := duel._stage_t
	if _cue_left > 0.0 and _cue == "reveal":
		return "reveal"
	if not duel._intro_talk:
		return "establish" if t < 1.3 else ("reveal" if t < 2.6 else ("close_up" if t < 3.6 else "ots"))
	if t < 2.4:
		return "establish"
	if t < 4.6:
		return "reveal"
	if t < 6.4:
		return "close_up"
	if shot in ["ots", "reverse"] and shot_t < 1.6:
		return shot      # no cut shorter than this
	var who := ""
	if Story.busy and Story.get("_name") != null:
		who = str(Story._name.text).to_lower().strip_edges()
	if who != "" and not str(duel.foe.name).to_lower().contains(who) and not who.contains(str(duel.foe.name).to_lower()):
		return "reverse"      # someone on the knight's side of the line is speaking
	return "ots"


# ================================================================ shots (ring frame)
## Wide and high from behind the knight's sword side: both figures and the ground between them. Slow drift in.
func _shot_establish() -> Dictionary:
	var d := shot_t * (0.0 if _calm else 0.22)
	return {"pos": Vector3(3.4 + 1.1 * _big - d * 0.5, 2.3 + 0.7 * _big, _K.z + 3.4 + 0.9 * _big - d),
		"look": _mid(0.5 * _H), "fov": 50.0, "rate": 30.0}

## Near the ground in front of the foe, looking up its body. Rises a little.
func _shot_reveal() -> Dictionary:
	var d := shot_t * (0.0 if _calm else 0.12)
	return {"pos": _F + Vector3(0.75 * _big, 0.3 + d, 1.55 * _big + 0.35 - d * 0.5),
		"look": _F + Vector3(0, _H * 0.92, 0), "fov": 54.0, "roll": 0.04, "rate": 30.0}

## The foe's helm (or a dragon's head). Slow push.
func _shot_close_up() -> Dictionary:
	var h := _foe_head()
	var d := shot_t * (0.0 if _calm else 0.1)
	return {"pos": h + Vector3(0.55 * _big, -0.14 * _big, (1.35 - d) * _big), "look": h, "fov": 34.0, "rate": 30.0}

## Over the knight's sword shoulder at the foe.
func _shot_ots() -> Dictionary:
	return {"pos": _K + Vector3(0.62, 1.5, 1.05 + 0.25 * (_big - 1.0)), "look": _F + Vector3(0.3, _H * 0.9, 0), "fov": 46.0, "rate": 30.0}

## Over the foe's shoulder at the knight, from the same side of the line.
func _shot_reverse() -> Dictionary:
	return {"pos": _F + Vector3(0.75 * _big, _H * 1.05 + 0.2, -1.0 * _big), "look": _K + Vector3(-0.3, 1.25, 0), "fov": 44.0, "rate": 30.0}

## The standard view: low at the knight's sword flank, looking up, so the knight sits in the lower
## left corner and the foe towers. `back` widens (metres), `round` swings toward side-on.
func _combat(back: float, round: float, lift: float, dfov: float) -> Dictionary:
	var c: Dictionary = CLASS[cls]
	var far := 0.1 if duel.sim.b_far else 0.0
	back += far - 0.18 * _tight + 0.7 * _wide
	return {"pos": Vector3(float(c.side) + _side + duel.p_side * 0.6 + round + 0.25 * _wide, float(c.y) + lift + 0.1 * _wide, _K.z + float(c.back) + back),
		"look": Vector3(float(c.look_x) + _side * 0.4, _H * float(c.look_h), _F.z + duel.f_back * 0.4),
		"fov": float(c.fov) + dfov - 2.5 * _tight + 3.0 * _wide, "rate": 6.0}

func _shot_combat() -> Dictionary:
	return _combat(0.0, 0.0, 0.0, 0.0)

## A heavy blow, slam, sweep or breath is coming: wider and lower so the whole telegraph reads.
func _shot_guard() -> Dictionary:
	var s := _combat(0.45, 0.1, -0.08, 4.0)
	s.rate = 4.0
	return s

## The foe is open: swing further round to the knight's side and push in, so the knight's cuts read across the frame.
func _shot_opening() -> Dictionary:
	var s := _combat(-0.35, 0.55, 0.12, -5.0)
	s.look = Vector3(-0.1, _H * 0.82, _F.z + 0.3)
	s.rate = 3.5
	return s

## Parry / perfect block: punch in at the crossed blades, then the base shot takes over again.
func _shot_clash() -> Dictionary:
	var s := _shot_combat()
	var at: Vector3 = _ring(_cue_params.get("at", duel.player_rig.chest_point()))
	var strong := 0.42 if _cue_params.get("perfect", false) else 0.32
	s.pos = (s.pos as Vector3).lerp(at + Vector3(0.5, -0.1, 0.3), strong)
	s.look = (s.look as Vector3).lerp(at, 0.6)
	s.fov = float(s.fov) - (8.0 if _cue_params.get("perfect", false) else 6.0)
	s.rate = 16.0
	return s

## Blade lock: close two-shot from the side at blade height.
func _shot_struggle() -> Dictionary:
	var m := _mid(1.15 + 0.1 * (_S - 1.0))
	return {"pos": m + Vector3(1.9 + 0.5 * _big, -0.15, 0.45), "look": m, "fov": 48.0, "roll": -0.03, "rate": 5.0}

## Phase change: a low hero angle on the foe.
func _shot_phase() -> Dictionary:
	return {"pos": _F + Vector3(1.0 + 0.5 * _big, 0.32, 1.5 + 1.1 * _big), "look": _F + Vector3(0, _H * 1.0, 0),
		"fov": 56.0, "roll": 0.05, "rate": 4.5}

## The killing blow: side-on and wide, both figures whole.
func _shot_finish_blow() -> Dictionary:
	var d := shot_t * (0.0 if _calm else 0.25)
	return {"pos": _mid(0.95) + Vector3(3.3 + 1.3 * _big - d, 0, 0.5), "look": _mid(0.95 + 0.2 * (_big - 1.0)), "fov": 48.0, "rate": 30.0}

## The fall: low, close to the foe.
func _shot_finish_fall() -> Dictionary:
	return {"pos": _F + Vector3(1.5 * _big, 0.3, 1.7 * _big), "look": _F + Vector3(0, _H * 0.55, 0), "fov": 52.0, "roll": 0.06, "rate": 30.0}

## Victory: a slow rise behind the knight, the fallen foe beyond.
func _shot_victory() -> Dictionary:
	var d := shot_t * (0.05 if _calm else 0.3)
	return {"pos": _K + Vector3(1.0, 0.9 + d, 2.3 + d * 0.5), "look": _K.lerp(_F, 0.55) + Vector3(0, 0.9, 0), "fov": 50.0, "rate": 30.0}

## The knight goes down: low and side-on, close.
func _shot_death_fall() -> Dictionary:
	return {"pos": _K + Vector3(2.3, 0.4, 0.9), "look": _K + Vector3(0, 0.7, 0), "fov": 50.0, "roll": -0.05, "rate": 30.0}

## Defeat: from the ground beside the fallen knight, the foe looming over.
func _shot_defeat() -> Dictionary:
	var d := minf(shot_t, 6.0) * (0.0 if _calm else 0.06)
	return {"pos": _K + Vector3(1.1, 0.3, 1.5 - d), "look": _F + Vector3(0, _H * 0.95, 0), "fov": 58.0, "roll": 0.03, "rate": 30.0}
