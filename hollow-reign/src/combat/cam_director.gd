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

const PRIORITY := {"exchange": 1, "phase": 3, "clash": 4, "struggle": 5, "story_beat": 5, "reveal": 6}
## Combat framing per class of foe. side/back: metres to the knight's sword side / behind the knight;
## y: camera height; fov; look_h: where on the foe to aim, as a multiple of its nominal height;
## look_x: sideways aim (negative puts the foe further right of the knight); wide: how much the
## cinematic shots open up for it.
const CLASS := {
	"humanoid": {"side": 1.9, "back": 0.7, "y": 1.0, "fov": 54.0, "look_h": 1.05, "look_x": 0.0, "wide": 1.0},
	"giant": {"side": 1.85, "back": 0.9, "y": 0.85, "fov": 60.0, "look_h": 1.0, "look_x": 0.0, "wide": 1.0},
	"dragon": {"side": 2.6, "back": 1.2, "y": 0.6, "fov": 54.0, "look_h": 0.55, "look_x": 0.0, "wide": 1.5},
}
const ARENA_R := 6.4          # some arenas stand scenery from about 7 m out: stay inside it
const MIN_Y := 0.25
## Rolls and sidesteps (docs/CAMERA_BIBLE.md "The move shot"). `--oldrollcam` films what was there before.
static var old_roll: bool = OS.get_cmdline_user_args().has("--oldrollcam")
const AXIS_TIME := 0.34       # seconds: smoothing time of the camera's swing about the duel (critically damped)
const KEEP_OUT := 0.9         # metres: no joint of either fighter comes nearer the lens than this
const MOVE_MIN := 3.2         # metres from the lens to the knight's hips while they roll or sidestep, at least
const REST_MIN := 1.5         # and the rest of the time

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
var _wide_amt := 1.0          # how far it opens: 1 for a roll, less for a sidestep (the knight stays on their feet)
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
var _KB := Vector3.ZERO       # where the knight's body really is on the floor (ring frame): mid-roll it is not at _K
var _FB := Vector3.ZERO       # and the foe's
var _kp := PackedVector3Array()      # the knight's joints, sword point and shield (world)
var _fp := PackedVector3Array()      # the foe's
var _ax_v := 0.0              # angular speed of the swing about the duel
var _floor := REST_MIN        # the least distance from lens to knight in force now
var _lat := 0.0               # metres the lens has gone sideways with a knight ahead of the turn


func _init(d: Duel, c: Camera3D) -> void:
	duel = d
	cam = c
	_noise.frequency = 2.0
	dev_seen()


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
			_wide_amt = float(params.get("amt", 1.0))
			return
		"struggle":
			if bool(params.get("on", true)):
				_take("struggle", 600.0, params)
			elif _cue == "struggle":
				_cue_left = 0.0
			return
		"story_beat":
			if bool(params.get("on", true)):
				_take("story_beat", 600.0, params)
			elif _cue == "story_beat":
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
	if not old_roll and duel.stage == Duel.Stage.FIGHT and duel.player_rig.mode == FighterRig.Mode.DODGE:
		_wide_left = maxf(_wide_left, 0.2)      # (a roll in slowed time outlasts the cue: the move shot holds until the knight is up)
	if old_roll:
		_wide = lerpf(_wide, 1.0 if _wide_left > 0.0 else 0.0, 1.0 - exp(-delta * (5.0 if _wide_left > 0.0 else 2.0)))
	else:
		_wide = lerpf(_wide, _wide_amt if _wide_left > 0.0 else 0.0, 1.0 - exp(-delta * (6.0 if _wide_left > 0.0 else 2.0)))
	_tight = lerpf(_tight, 1.0 if _tight_left > 0.0 else 0.0, 1.0 - exp(-delta * 5.0))
	_side = lerpf(_side, duel.player_rig._root.x * 0.6, 1.0 - exp(-delta * 5.0))

	var name := _choose()
	if _dev != "":
		name = _dev_hook(name, delta)
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
		var lk := _K if old_roll else _KB
		var lf := _F if old_roll else _FB
		var u := clampf(inverse_lerp(lf.z, lk.z, pos.z), 0.0, 1.3)
		pos.x = maxf(pos.x, lerpf(lf.x, lk.x, u) + 0.7)
	var k := 1.0 - exp(-delta * rate)
	if cut or not _started:
		k = 1.0
		_started = true
	_pos = _pos.lerp(pos, k)
	_look = _look.lerp(look, k)
	_roll = lerpf(_roll, float(s.get("roll", 0.0)), k)
	cam.fov = lerpf(cam.fov, float(s.fov), k)
	var at := _pos
	if _moving():
		# A quick sidestep gets ahead of the turn. The lens goes sideways with the knight's hips, less a dead band
		# (so it does not sway with a guard) and not the whole way (with reduce_motion less than half): the knight is
		# seen to cross a little of the frame, never as far as the foe. This is not eased: it is the knight's own motion.
		var ahead := signf(_KB.x) * maxf(absf(_KB.x) - 0.15, 0.0) * (0.4 if _calm else 0.85)
		_lat = lerpf(_lat, ahead, 1.0 - exp(-delta * 30.0))
		at.x += _lat
		# the eased pose trails the knight's own speed: it may not trail them into the lens
		at = _stand_off(at, _floor)
		_look = _keep_knight(at, _look, cam.fov)
	else:
		_lat = 0.0

	var turn := Basis(Vector3.UP, duel.ring_cam)
	var wp := turn * at
	if _moving():
		wp = _keep_out(wp)
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
	if _log != null:
		_log_frame(delta)


# ================================================================ rolls and sidesteps
## True while the fight's own framing is on and the roll/dodge pass is in force.
func _moving() -> bool:
	return not old_roll and duel.stage == Duel.Stage.FIGHT and shot in ["combat", "guard", "opening", "clash"]

## The camera's swing about the duel (`Duel.ring_cam`), called from the duel's footwork. `target` is the angle the
## line between the fighters will have once the sidestep or roll in hand is over, so the camera sets off with the
## knight and arrives with them: one eased turn, critically damped (no jump at the start, no overshoot at the end).
func axis(dt: float, target: float) -> float:
	var st := AXIS_TIME * (1.6 if bool(Game.settings.get("reduce_motion", false)) else 1.0)
	var om := 2.0 / st
	var x := om * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := wrapf(duel.ring_cam - target, -PI, PI)
	var temp := (_ax_v + om * change) * dt
	_ax_v = (_ax_v - om * temp) * e
	var out := change + temp
	out *= e
	if (change > 0.0) != (out > 0.0):      # never past where it is going
		out = 0.0
		_ax_v = 0.0
	return target + out

## A fighter's joints, the point of its weapon and what it carries (world): what the lens must keep clear of.
func _points(rig: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var sk = rig.get("skin")
	if sk != null and sk.ok and sk.skel != null:
		var x: Transform3D = sk.skel.global_transform
		for i: int in sk.skel.get_bone_count():
			out.append(x * sk.skel.get_bone_global_pose(i).origin)
	else:
		out.append(rig.global_position)
		out.append(rig.chest_point())
		if rig.get("head") != null:
			out.append(rig.head.global_position)
	out.append(rig.blade_tip())
	for n: String in ["weapon_r", "weapon_l", "shield"]:
		var node = rig.get(n)
		if node != null and node is Node3D and node.is_visible_in_tree():
			out.append(node.global_position)
	return out

## Where a body stands on the floor (ring frame): under its hips when it has a skeleton.
func _body_at(rig: Node3D) -> Vector3:
	var w: Vector3 = rig.global_position
	var sk = rig.get("skin")
	if sk != null and sk.ok and sk.skel != null and sk is SkinDriver and sk.bone.has("Hips"):
		w = sk.skel.global_transform * sk.skel.get_bone_global_pose(int(sk.bone["Hips"])).origin
	var r := _ring(w)
	return Vector3(r.x, 0, r.z)

## `pos` (ring frame) moved away from the knight's body until it is `least` metres off across the floor: away from
## them and out to the sword side in equal parts, so that stepping back does not bring the knight in front of the foe.
func _stand_off(pos: Vector3, least: float) -> Vector3:
	var d := Vector2(pos.x - _KB.x, pos.z - _KB.z)
	if d.length() >= least or d.length() < 0.01:
		return pos
	var dir := (d.normalized() + Vector2(0.7, 0.0)).normalized()
	# the point along `dir` from `pos` that is `least` from the knight
	var b := d.dot(dir)
	var go := -b + sqrt(maxf(b * b - d.length_squared() + least * least, 0.0))
	return Vector3(pos.x + dir.x * go, pos.y, pos.z + dir.y * go)

## Keep-out: if a joint of either fighter is within KEEP_OUT of the lens (world), the lens backs away from it and rises.
func _keep_out(wp: Vector3) -> Vector3:
	for pass_i: int in 2:
		var near := 1e9
		var at := Vector3.ZERO
		for pts: PackedVector3Array in [_kp, _fp]:
			for p: Vector3 in pts:
				var d := wp.distance_to(p)
				if d < near:
					near = d
					at = p
		if near >= KEEP_OUT or near < 0.001:
			break
		var away := wp - at
		away.y = absf(away.y) + 0.35 * away.length()
		wp += away.normalized() * (KEEP_OUT - near)
	return wp

## How far across the floor the knight must be from the lens for their feet to be in the frame.
func _feet_dist(pos: Vector3, look: Vector3, fov: float) -> float:
	var flat := Vector2(look.x - pos.x, look.z - pos.z).length()
	var pitch := atan2(look.y - pos.y, maxf(flat, 0.1))
	var down := deg_to_rad(fov) * 0.5 - pitch
	return pos.y / tan(clampf(down, 0.12, 1.2))


# ================================================================ dev: measuring the move shot
## `--camlog=<file>`: one line a frame of the fight (CSV): f (frame), t, mv (2 in a roll or sidestep, 1 in its settle), near (m, nearest
## joint of either fighter to the lens), kx0 ky0 kx1 ky1 (the knight's box on screen, 0..1, unclipped), kin (share of
## the knight's joints inside the frame less a 2% margin), kh (height of the box, share of the frame), fvis (share of
## the foe's joints in the frame and not behind the knight's box), lag (degrees the knight is round from the camera's
## axis), cv (m/s the lens moves), yv (degrees a second it turns), fov.
var _log: FileAccess = _log_open()
var _log_p := Vector3.ZERO
var _log_yaw := 0.0
var _log_n := 0
static func _log_open() -> FileAccess:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--camlog="):
			var f := FileAccess.open(a.trim_prefix("--camlog="), FileAccess.WRITE)
			if f != null:
				f.store_line("f,t,mv,near,kx0,ky0,kx1,ky1,kin,kh,fvis,lag,cv,yv,fov")
			return f
	return null

func _log_frame(delta: float) -> void:
	if duel.stage != Duel.Stage.FIGHT or delta <= 0.0:
		return
	var kp := _points(duel.player_rig)
	var fp := _points(duel.foe_rig)
	var vs := cam.get_viewport().get_visible_rect().size
	var near := 1e9
	for pts: PackedVector3Array in [kp, fp]:
		for p: Vector3 in pts:
			near = minf(near, cam.global_position.distance_to(p))
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	var inside := 0
	var right := cam.global_basis.x
	var sk = duel.player_rig.get("skin")
	var body_n: int = sk.skel.get_bone_count() if (sk != null and sk.ok and sk.skel != null) else kp.size()
	for i: int in body_n:      # (the body: the sword's point and the shield are not counted)
		var p := kp[i]
		var ok := not cam.is_position_behind(p)
		var s := cam.unproject_position(p) / vs if ok else Vector2(-9, -9)
		if ok and s.x > 0.02 and s.x < 0.98 and s.y > 0.02 and s.y < 0.98:
			inside += 1
		# a joint is the middle of a limb: the box is taken a hand's breadth wider all round
		for o: Vector3 in [Vector3(0, 0.13, 0), Vector3(0, -minf(0.1, p.y), 0), right * 0.13, right * -0.13]:
			var q := p + o
			var sq := (cam.unproject_position(q) / vs) if not cam.is_position_behind(q) else Vector2(-9, 9)
			lo = Vector2(minf(lo.x, sq.x), minf(lo.y, sq.y))
			hi = Vector2(maxf(hi.x, sq.x), maxf(hi.y, sq.y))
	var seen := 0
	for p: Vector3 in fp:
		if cam.is_position_behind(p):
			continue
		var s := cam.unproject_position(p) / vs
		if s.x > 0.0 and s.x < 1.0 and s.y > 0.0 and s.y < 1.0 and not Rect2(lo, hi - lo).has_point(s):
			seen += 1
	var kw := duel.player_rig.global_position
	if sk != null and sk.ok and sk.bone.has("Hips"):
		kw = sk.skel.global_transform * sk.skel.get_bone_global_pose(int(sk.bone["Hips"])).origin
	var lag := rad_to_deg(wrapf(atan2(kw.x, kw.z) - duel.ring_cam, -PI, PI))
	var yaw := cam.global_rotation.y
	var mv := 2 if duel.player_rig.mode == FighterRig.Mode.DODGE else (1 if (_wide_left > 0.0 or _wide > 0.25) else 0)
	if _log_n > 0:
		_log.store_line("%d,%.3f,%d,%.2f,%.3f,%.3f,%.3f,%.3f,%.2f,%.3f,%.2f,%.1f,%.2f,%.1f,%.1f" % [Engine.get_process_frames(), duel.sim.time, mv, near, lo.x, lo.y, hi.x, hi.y,
			float(inside) / maxf(body_n, 1.0), hi.y - lo.y, float(seen) / maxf(fp.size(), 1.0), lag,
			cam.global_position.distance_to(_log_p) / delta, rad_to_deg(absf(wrapf(yaw - _log_yaw, -PI, PI))) / delta, cam.fov])
		if _log_n % 30 == 0:
			_log.flush()
	_log_n += 1
	_log_p = cam.global_position
	_log_yaw = yaw


## Dev only (capture harness): HR_CAM_DEV="shot=struggle" holds a shot during the fight;
## "kill@3" / "die@3" leaves the foe / the knight on a sliver of health 3 s into the fight, so the ending can be filmed.
var _dev := OS.get_environment("HR_CAM_DEV")
var _dev_t := 0.0
func dev_seen() -> void:
	if _dev == "seen" or OS.has_environment("HR_CAM_SEEN"):
		Game.profile.flags["scene_" + Companion.voice_key(str(duel.foe.id)) + "_intro"] = true
func _dev_hook(name: String, delta: float) -> String:
	if duel.stage != Duel.Stage.FIGHT:
		return name
	_dev_t += delta
	if _dev.begins_with("shot="):
		return _dev.trim_prefix("shot=")
	var at := float(_dev.get_slice("@", 1))
	if _dev_t >= at:
		if _dev.begins_with("kill"):
			duel.sim.b_hp = minf(duel.sim.b_hp, 1.0)
		elif _dev.begins_with("die"):
			duel.sim.pl.hp = minf(float(duel.sim.pl.hp), 1.0)
	return name

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
	_KB = _K
	_FB = _F
	if not old_roll and duel.stage == Duel.Stage.FIGHT:
		_kp = _points(duel.player_rig)
		_fp = _points(duel.foe_rig)
		_KB = _body_at(duel.player_rig)
		_FB = _body_at(duel.foe_rig)

## World point to ring frame.
func _ring(world: Vector3) -> Vector3:
	return Basis(Vector3.UP, -duel.ring_cam) * world

## A rig's head in the ring frame: the skinned model's head bone when it has one, else the procedural head.
func _head_of(rig: Node3D, fallback: Vector3) -> Vector3:
	var sk = rig.get("skin")
	if sk != null and sk.ok and sk.skel != null:
		var i := -1
		if sk is SkinDriver and sk.bone.has("Head"):
			i = int(sk.bone["Head"])
		elif sk is DragonSkin and not sk._neck.is_empty():
			i = int(sk._neck[sk._neck.size() - 1])
		if i >= 0:
			var w: Vector3 = sk.skel.global_transform * sk.skel.get_bone_global_pose(i).origin
			if w.y > 0.3:
				return _ring(w)
	var h: Vector3 = _ring(rig.head.global_position) if rig.get("head") != null else fallback
	return h if h.y > 0.3 else fallback

func _foe_head() -> Vector3:
	return _head_of(duel.foe_rig, _F + Vector3(0, _H * 1.15, 0))

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
			return "finish_blow" if t < 1.25 else ("finish_fall" if t < 2.4 else _after_shot())
		Duel.Stage.DEATH:
			_ended = "loss"
			return "death_fall" if duel._stage_t < 1.2 else "defeat"
		Duel.Stage.DONE:
			return _after_shot() if _ended == "win" else ("defeat" if _ended == "loss" else "combat")
	if _cue_left > 0.0 and _cue != "reveal":
		return _cue
	if sim.boss_open():
		return "opening"
	if sim.b_state == DuelSim.B.WINDUP:
		var a: Dictionary = sim.b_attack
		if str(a.get("kind", "")) in ["slam", "sweep", "breath"] or float(a.get("dmg", 0.0)) >= 30.0:
			return "guard"
	return "combat"

## After the fall, while last words, the record and the companions are heard: a cut for each voice, each of them
## close (the foe where it lies, the knight's answer, the record over the knight's shoulder, the knight and the
## Witness), instead of one shot that drew back for as long as anyone spoke. No cut is shorter than AFTER_MIN.
const AFTER_MIN := 1.3
const AFTER_SHOTS := ["victory", "victory_fallen", "victory_knight", "victory_record", "victory_pair"]
func _after_shot() -> String:
	var want := "victory"
	var who := str(Story.speaker) if Story.busy else ""
	if who == "player":
		want = "victory_knight"
	elif who in ["archivist", "lyra"]:
		want = "victory_record"
	elif who == "witness":
		want = "victory_pair"
	elif who != "":
		want = "victory_fallen"
	if shot in AFTER_SHOTS and shot != want and shot_t < AFTER_MIN:
		return shot
	return want

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
	return {"pos": Vector3(3.0 + 0.9 * _big - d * 0.5, 1.7 + 0.6 * _big, _K.z + 2.2 + 0.7 * _big - d),
		"look": _mid(0.55 * _H), "fov": 56.0, "rate": 30.0}

## Near the ground in front of the foe, looking up its body. Rises a little.
func _shot_reveal() -> Dictionary:
	var d := shot_t * (0.0 if _calm else 0.12)
	return {"pos": _F + Vector3(0.7 * _big, 0.3 + d, 1.4 * _big + 0.35 - d * 0.5),
		"look": _F + Vector3(0, _H * 0.9, 0), "fov": 48.0, "roll": 0.04, "rate": 30.0}

## The foe's helm (or a dragon's head). Slow push.
func _shot_close_up() -> Dictionary:
	var h := _foe_head()
	var d := shot_t * (0.0 if _calm else 0.1)
	return {"pos": h + Vector3(0.8 * _big, 0.1 * _big, (1.25 - d) * _big), "look": h, "fov": 32.0, "rate": 30.0}

## Over the knight's sword shoulder at the foe.
func _shot_ots() -> Dictionary:
	return {"pos": _K + Vector3(0.62, 1.5, 1.05 + 0.25 * (_big - 1.0)), "look": _F + Vector3(0.3, _H * 0.9, 0), "fov": 46.0, "rate": 30.0}

## Over the foe's shoulder at the knight, from the same side of the line.
func _shot_reverse() -> Dictionary:
	var h := _foe_head()
	return {"pos": h + Vector3(0.55 * _big, 0.15 * _S, -0.45 * _S), "look": _K + Vector3(-0.3, 1.25, 0), "fov": 44.0, "rate": 30.0}

## The standard view: low at the knight's sword flank, looking up, so the knight sits in the lower
## left corner and the foe towers. `back` widens (metres), `round` swings toward side-on.
func _combat(back: float, round: float, lift: float, dfov: float) -> Dictionary:
	var c: Dictionary = CLASS[cls]
	if OS.has_environment("HR_CAM"):      # dev tuning: side,back,y,fov,look_h,look_x
		var v := OS.get_environment("HR_CAM").split_floats(",")
		c = {"side": v[0], "back": v[1], "y": v[2], "fov": v[3], "look_h": v[4], "look_x": v[5]}
	if duel.sim.b_far:
		dfov -= 5.0      # it has backed off: hold it large with the lens, not by chasing it
	if not old_roll:
		return _combat_move(c, back - 0.18 * _tight, round, lift, dfov - 2.5 * _tight)
	back += -0.18 * _tight + 0.7 * _wide
	var pos := Vector3(float(c.side) + _side + duel.p_side * 0.6 + round + 0.25 * _wide, float(c.y) + lift + 0.1 * _wide, _K.z + float(c.back) + back)
	var look := Vector3(float(c.look_x) + _side * 0.4, _H * float(c.look_h), _F.z + duel.f_back * 0.4)
	var fov := float(c.fov) + dfov - 2.5 * _tight + 3.0 * _wide
	return {"pos": pos, "look": _keep_knight(pos, look, fov), "fov": fov, "rate": 6.0}

## The same view, written so that a roll or a sidestep reads (the move shot). The camera's station is fixed in the
## frame of `Duel.ring_cam`, which swings to the new line in one eased turn (`axis`), so the station does not chase
## the knight sideways. While the knight moves (`_wide`) the lens stands further off from where their body really
## is, far enough that their feet are in the frame, opens a little, and turns its aim to hold the whole figure.
func _combat_move(c: Dictionary, back: float, round: float, lift: float, dfov: float) -> Dictionary:
	var w := smoothstep(0.0, 1.0, _wide)
	var pos := Vector3(float(c.side) + round, float(c.y) + lift, duel.gap * 0.5 + duel.p_back + float(c.back) + back)
	var look := Vector3(float(c.look_x), _H * float(c.look_h), _F.z + duel.f_back * 0.4)
	var fov := float(c.fov) + dfov + (0.0 if _calm else 4.0 * w)
	# (the aim comes down to just above the lens's own height for the move: the floor under the knight comes into the
	# frame with a short step back instead of a long one, and the foe is tall enough to stay in it. The knight is off
	# to one side of the aim, where the frame's lower edge meets the floor further out, and a tumbling body is long.)
	look.y = lerpf(look.y, minf(look.y, pos.y - 0.1), w)
	_floor = lerpf(REST_MIN, maxf(MOVE_MIN, _feet_dist(pos, look, fov) * 1.3 + (0.4 if _calm else 0.6)), w)
	pos = _stand_off(pos, _floor)
	return {"pos": pos, "look": _keep_knight(pos, look, fov), "fov": fov, "rate": lerpf(6.0, 12.0, w)}

## Turns the aim toward the knight just enough that a sidestep or a shove never carries them out of the frame.
func _keep_knight(pos: Vector3, look: Vector3, fov: float) -> Vector3:
	var vp := cam.get_viewport()
	var aspect := 16.0 / 9.0
	if vp != null:
		var sz := vp.get_visible_rect().size
		aspect = sz.x / maxf(sz.y, 1.0)
	var half := atan(tan(deg_to_rad(fov) * 0.5) * aspect)
	var to_l := Vector2(look.x - pos.x, look.z - pos.z)
	var kb := _K if old_roll else _KB
	var to_k := Vector2(kb.x - pos.x, kb.z - pos.z)
	var over := absf(to_l.angle_to(to_k)) - half * 0.92
	if not old_roll:
		# the middle of the body, so in a roll or a sidestep the margin is the body's own half-width
		over += smoothstep(0.0, 1.0, _wide) * atan(0.85 / maxf(to_k.length(), 0.5))
	if over <= 0.0:
		return look
	var r := to_l.rotated(signf(to_l.angle_to(to_k)) * over)
	return Vector3(pos.x + r.x, look.y, pos.z + r.y)

func _shot_combat() -> Dictionary:
	return _combat(0.0, 0.0, 0.0, 0.0)

## A heavy blow, slam, sweep or breath is coming: wider and lower so the whole telegraph reads.
func _shot_guard() -> Dictionary:
	var s := _combat(0.45, 0.1, -0.08, 4.0)
	s.rate = 4.0 if old_roll else lerpf(4.0, 12.0, smoothstep(0.0, 1.0, _wide))
	return s

## The foe is open: swing further round to the knight's side and push in, so the knight's cuts read across the frame.
func _shot_opening() -> Dictionary:
	var s := _combat(-0.35, 0.55, 0.12, -5.0)
	var look := Vector3(-0.1, _H * 0.82, _F.z + 0.3)
	var rate := 3.5
	if not old_roll:
		# (a roll that ends in the foe's opening: the move shot's level aim, its hold on the knight and its pace win
		# while the knight is still moving)
		var w := smoothstep(0.0, 1.0, _wide)
		look.y = lerpf(look.y, minf(look.y, (s.pos as Vector3).y - 0.1), w)
		look = _keep_knight(s.pos, look, float(s.fov))
		rate = lerpf(rate, 7.0, w)
	s.look = look
	s.rate = rate
	return s

## The fight stops for them to speak (Duel._story_beat): over the shoulder at the foe, eased, held until they finish.
func _shot_story_beat() -> Dictionary:
	var s := _shot_ots()
	s.rate = 3.0
	return s

## Parry / perfect block: punch in at the crossed blades, then the base shot takes over again.
func _shot_clash() -> Dictionary:
	var s := _shot_combat()
	var at: Vector3 = _ring(_cue_params.get("at", duel.player_rig.chest_point()))
	var strong := 0.36 if _cue_params.get("perfect", false) else 0.28
	s.pos = (s.pos as Vector3).lerp(at + Vector3(0.5, -0.1, 0.3), strong)
	s.look = (s.look as Vector3).lerp(at, 0.45)
	s.fov = float(s.fov) - (8.0 if _cue_params.get("perfect", false) else 6.0)
	s.rate = 16.0
	return s

## Blade lock: close two-shot from the side at blade height.
func _shot_struggle() -> Dictionary:
	var m := _mid(1.15 + 0.1 * (_S - 1.0))
	return {"pos": m + Vector3(2.1 + 0.7 * _big, -0.15, 0.45), "look": m, "fov": 48.0, "roll": -0.03, "rate": 5.0}

## Phase change: a low hero angle on the foe, from the ground at the knight's flank: the foe towers, and the knight
## (whose fight goes on through it) stays in the near corner of the frame, never behind the lens.
func _shot_phase() -> Dictionary:
	return {"pos": _K + Vector3(0.9 + 0.2 * _big, 0.3, 1.5 + 0.3 * _big), "look": _F + Vector3(0, _H * 0.95, 0),
		"fov": 54.0, "roll": 0.05, "rate": 4.5}

## The killing blow: side-on and wide, both figures whole.
func _shot_finish_blow() -> Dictionary:
	var d := shot_t * (0.0 if _calm else 0.25)
	return {"pos": _mid(0.9) + Vector3(2.3 + 0.9 * _big - d, 0, 0.5), "look": _mid(0.95 + 0.25 * (_big - 1.0)), "fov": 46.0, "rate": 30.0}

## The fall: low, close to the foe.
func _shot_finish_fall() -> Dictionary:
	return {"pos": _F + Vector3(1.5 * _big, 0.3, 1.7 * _big), "look": _F + Vector3(0, _H * 0.55, 0), "fov": 52.0, "roll": 0.06, "rate": 30.0}

## Victory: a short rise behind the knight, the fallen foe beyond. The rise ends (it used to go on for as long as
## anyone spoke, until the knight was a few pixels high).
const VICTORY_RISE := 2.6
func _shot_victory() -> Dictionary:
	var d := minf(shot_t, VICTORY_RISE) * (0.05 if _calm else 0.22)
	return {"pos": _K + Vector3(1.0, 1.0 + d, 2.1 + d * 0.5), "look": _K.lerp(_F, 0.55) + Vector3(0, 0.9, 0), "fov": 48.0, "rate": 30.0}

## Where the beaten foe lies (ring frame, on the floor).
func _fallen_at() -> Vector3:
	return _body_at(duel.foe_rig) if is_instance_valid(duel.foe_rig) else _F

## Its last words: low and close to where it lies.
func _shot_victory_fallen() -> Dictionary:
	var f := _fallen_at()
	var d := minf(shot_t, 8.0) * (0.0 if _calm else 0.04)
	return {"pos": f + Vector3(1.1 * _big, 0.5, (1.5 - d) * _big), "look": f + Vector3(0, 0.3 * _S, 0), "fov": 40.0, "roll": 0.03, "rate": 30.0}

## The knight's answer: chest up, from the foe's side of the line.
func _shot_victory_knight() -> Dictionary:
	return {"pos": _K + Vector3(0.75, 1.42, -1.55), "look": _K + Vector3(0, 1.45, 0), "fov": 38.0, "rate": 30.0}

## What the dead leave behind, read out: over the knight's shoulder, down at the fallen, pushing slowly in.
func _shot_victory_record() -> Dictionary:
	var f := _fallen_at()
	var d := minf(shot_t, 12.0) * (0.0 if _calm else 0.035)
	return {"pos": _K + Vector3(0.7, 1.62, 1.25 - d), "look": f + Vector3(0, 0.35 * _S, 0), "fov": 42.0, "rate": 30.0}

## The companion's word on it: the knight from the sword side, waist up, room at the shoulder for the Witness.
func _shot_victory_pair() -> Dictionary:
	return {"pos": _K + Vector3(1.9, 1.35, 0.5), "look": _K + Vector3(-0.1, 1.3, -0.2), "fov": 40.0, "rate": 30.0}

## The knight goes down: low and side-on, close.
func _shot_death_fall() -> Dictionary:
	return {"pos": _K + Vector3(2.5, 0.4, 1.3), "look": _K.lerp(_F, 0.3) + Vector3(0, 0.8, 0), "fov": 52.0, "roll": -0.05, "rate": 30.0}

## Defeat: from the ground beside the fallen knight, the foe looming over.
func _shot_defeat() -> Dictionary:
	var d := minf(shot_t, 6.0) * (0.0 if _calm else 0.06)
	return {"pos": _K + Vector3(0.9, 0.3, 1.9 - d), "look": _F + Vector3(-0.2, _H * 0.8, 0), "fov": 40.0, "roll": 0.03, "rate": 30.0}
