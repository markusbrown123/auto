extends Node3D
## Dev: locomotion and idle measurements on the real skinned knight, plus a lit test course for normal-speed recordings.
## The rig is moved exactly as the road and the explore stops move it (its origin set each frame at FighterRig.ROAD_SPEED,
## its yaw turned toward the way it goes), so what is measured is what those screens show.
##
##   godot --headless --path . res://src/dev/loco_probe.tscn -- --probe=idle|guard|walk|course [--body=f] [--secs=20]
##       idle    20 s standing out of combat (the road, the stops, the story scenes)
##       guard   20 s in the duel's guard (combat_steps)
##       tired   the duel's guard after a burst of cuts and dodges (exertion), 20 s
##       walk    straight walks with stops, a turn on the spot (90 and 180 degrees), a bend while walking
##       course  walk + a 12 degree ramp up and down + a flight of stairs up and down (also the recording course)
##   with a window and --write-movie the same course is filmed by the road's follow camera (CamFollow) at normal speed.
## Prints one block of numbers per probe (see docs/ANIMATION_LIBRARY.md "Locomotion pass").

var _args := {}
var rig: FighterRig
var cam: Camera3D
var follow: CamFollow
var _t := 0.0
var _plan: Array = []          # [t_start, kind, data]
var _probe := "idle"
var _secs := 20.0
var _log: Array = []           # per frame samples
var _heading := 0.0
var _pos := Vector3.ZERO
var _speed := 0.0
var _turn_to := 0.0
var _turn_rate := 0.0
var _walls: Array = []

const RAMP_DEG := 12.0
const STAIR_RISE := 0.16
const STAIR_RUN := 0.32

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_probe = str(_args.get("probe", "idle"))
	_secs = float(_args.get("secs", "20"))
	Game.save_dir_override = "user://loco_probe_tmp"
	Game.profile = Game.default_profile()
	Game.profile.body = str(_args.get("body", "m"))
	_room()
	rig = (CineActor.new() if _args.has("actor") else FighterRig.new())
	add_child(rig)
	rig.build(Duel.player_look(), false)
	rig.footsteps = true
	rig.ground = Callable(self, "_gy")
	rig.combat_steps = _probe in ["guard", "tired"]
	rig.walking = false
	_pos = Vector3(0, 0, 4.0)
	rig.position = _pos
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 46.0
	cam.make_current()
	follow = CamFollow.new()
	follow.cam = cam
	follow.target = rig
	follow.offset = Vector3(1.0, 1.45, 3.6)
	follow.look_ahead = Vector3(-0.2, 1.25, -2.6)
	add_child(follow)
	if _probe in ["walk", "course"]:
		_build_plan()
		follow.measure = true
		follow.avoid = FighterRig.loco
	else:
		# standing: a still three-quarter view from in front, chest to boots, to judge breathing and weight
		follow.enabled = false
		cam.fov = 34.0
		cam.global_position = _pos + Vector3(1.7, 1.45, -2.9)
		cam.look_at(_pos + Vector3(0, 1.05, 0))
	if _probe == "tired":
		_exert()

## Exertion as the duel leaves it: a run of cuts, two sidesteps and a roll, then the guard is held.
func _exert() -> void:
	for i in 5:
		get_tree().create_timer(0.2 + i * 0.7).timeout.connect(func(): rig.swing(Vector2(1 if i % 2 == 0 else -1, 0), 0.5))
	get_tree().create_timer(3.9).timeout.connect(func(): rig.dodge(1.0))
	get_tree().create_timer(4.8).timeout.connect(func(): rig.dodge(-1.0))
	get_tree().create_timer(5.6).timeout.connect(func(): rig.dodge(1.0); get_tree().create_timer(0.08).timeout.connect(func(): rig.roll(1.0)))
	get_tree().create_timer(6.0).timeout.connect(func(): rig.hurt())

# ---------------------------------------------------------------- the course
## The ground: flat, then (course) a 12 degree ramp up, a level top, a ramp down, flat, a flight of stairs up and down.
## Laid along -Z from z = 4, x = 0 (the walk probe uses only the flat part, off to the side at x = -6).
func _gy(x: float, z: float) -> float:
	if x < -3.0:
		return 0.0
	var d := 4.0 - z      # metres along the course
	var t := tan(deg_to_rad(RAMP_DEG))
	var h := 0.0
	# ramp up 10..16, top 16..19, ramp down 19..25
	h += clampf(d - 10.0, 0.0, 6.0) * t - clampf(d - 19.0, 0.0, 6.0) * t
	# stairs up from 30: 6 steps, a landing, 6 down
	if d > 30.0:
		var n_up := clampi(int(floor((d - 30.0) / STAIR_RUN)) + 1, 0, 6)
		var n_dn := clampi(int(floor((d - 30.0 - 6 * STAIR_RUN - 1.6) / STAIR_RUN)) + 1, 0, 6)
		h += (n_up - n_dn) * STAIR_RISE
	return h

func _build_plan() -> void:
	# [seconds, what]: stand, walk metres, turn degrees on the spot, bend degrees while walking
	if _probe == "walk":
		_pos = Vector3(-6.0, 0, 4.0)
		_plan = [[2.0, "stand"], [6.0, "walk"], [1.5, "stand"], [90.0, "turn"], [1.0, "stand"], [5.0, "walk"], [1.2, "stand"],
			[180.0, "turn"], [1.0, "stand"], [3.0, "walk"], [60.0, "bend"], [3.0, "walk"], [-45.0, "bend"], [2.0, "walk"], [2.0, "stand"]]
	else:
		_pos = Vector3(0, 0, 4.0)
		_plan = [[2.0, "stand"], [9.0, "walk"], [6.0, "walk"], [3.0, "walk"], [6.0, "walk"], [4.0, "walk"], [1.2, "stand"], [3.0, "walk"],
			[1.92 + 1.6 + 1.92 + 1.5, "walk"], [1.5, "stand"], [180.0, "turn"], [1.0, "stand"], [3.0, "walk"], [2.0, "stand"]]
	rig.position = _pos
	_secs = 0.0
	for p: Array in _plan:
		var amount: float = p[0]
		match str(p[1]):
			"stand": _secs += amount
			"walk": _secs += amount / FighterRig.ROAD_SPEED
			"turn": _secs += absf(amount) / 150.0 + 0.3
			"bend": _secs += 0.0
	_secs += 0.5

var _step := 0
var _left := 0.0
var _step_init := false
func _advance(dt: float) -> void:
	if _plan.is_empty():
		return
	if not _step_init:
		_step_init = true
		if _step >= _plan.size():
			_speed = 0.0
			rig.walking = false
			return
		var p: Array = _plan[_step]
		match str(p[1]):
			"stand":
				_left = p[0]
				_speed = 0.0
				rig.walking = false
			"walk":
				_left = float(p[0]) / FighterRig.ROAD_SPEED
				_speed = FighterRig.ROAD_SPEED
				rig.walking = true
			"turn":
				# on the spot, as a screen turns the knight to face a way before setting off (about 150 degrees a second)
				_turn_to = _heading + deg_to_rad(float(p[0]))
				_left = absf(float(p[0])) / 150.0 + 0.3
				_speed = 0.0
				rig.walking = false
			"bend":
				# a bend in the way while walking: the heading turns over about two metres
				_turn_to = _heading + deg_to_rad(float(p[0]))
				_left = 0.0
	var p2: Array = _plan[mini(_step, _plan.size() - 1)]
	if str(p2[1]) == "turn":
		var u := 1.0 - exp(-dt * 7.0)
		_heading = lerp_angle(_heading, _turn_to, u)
	elif absf(wrapf(_turn_to - _heading, -PI, PI)) > 0.001 and _speed > 0.0:
		_heading = move_toward(_heading, _turn_to, dt * 0.55)
	var fwd := Vector3(-sin(_heading), 0, -cos(_heading))
	_pos += fwd * _speed * dt
	_pos.y = _gy(_pos.x, _pos.z)
	rig.position = _pos
	rig.rotation.y = _heading
	_left -= dt
	if _left <= 0.0:
		_step += 1
		_step_init = false

# ---------------------------------------------------------------- measuring
func _bone_w(n: String) -> Vector3:
	var sk: Skeleton3D = rig.skin.skel
	return sk.global_transform * sk.get_bone_global_pose(rig.skin.bone[n]).origin

func _process(delta: float) -> void:
	var dt := delta
	if _t == 0.0:
		_t = 0.000001
	_t += dt
	# (measured before this frame's move: the pose the rig solved last frame, with the transform it solved it under)
	if _t > 0.7 and rig.skin != null:
		_sample(dt)
	_advance(dt)
	if _t >= _secs + 0.7:
		_report()
		get_tree().quit()

func _sample(dt: float) -> void:
	var s := {"t": _t, "dt": dt}
	var inv := rig.global_transform.affine_inverse()
	for n: String in ["Spine2", "Head", "LeftArm", "RightArm", "Hips", "LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]:
		s[n] = _bone_w(n)
		s[n + "_l"] = inv * s[n]
	s["amt"] = rig._walk_amount
	s["clip"] = rig.skin.clip
	s["clip_t"] = rig.skin.clip_t
	s["clip_w"] = rig.skin.clip_w
	s["yaw"] = rig.rotation.y
	var hb: Basis = rig.skin.skel.global_transform.basis * rig.skin.skel.get_bone_global_pose(rig.skin.bone["Hips"]).basis
	var hf := hb * (rig.skin.rest["Hips"] as Transform3D).basis.inverse() * Vector3(0, 0, -1)
	s["hyaw"] = atan2(-hf.x, -hf.z)
	s["pos"] = rig.global_position
	if _args.has("trace") and _t >= float(str(_args.trace).get_slice(":", 0)) and _t <= float(str(_args.trace).get_slice(":", 1)):
		print("    t %.2f rig %.1f off %.1f lag %.1f hips %.1f mode %d amt %.2f clip %s w %.2f hipsY %.3f gy %.2f lagY %.3f drop %.3f visgy %.3f bodyY %.3f L %s R %s" % [_t, rad_to_deg(rig.rotation.y), rad_to_deg(rig._face_off), rad_to_deg(rig._lag_yaw), rad_to_deg(s.hyaw), rig._feet_mode(), rig._walk_amount, rig.skin.clip, rig.skin.clip_w, (s.Hips as Vector3).y, _gy(rig.position.x, rig.position.z), rig._lag.y, rig._ft_drop, rig._vis_gy, rig.body.global_position.y, str(Vector3(s.LeftFoot).snapped(Vector3.ONE * 0.01)), str(Vector3(s.RightFoot).snapped(Vector3.ONE * 0.01))]); if _args.has("feet"): print("      fw ", rig._fw.get("Left", {}), " ft ", rig._ft.get("Left", {}))
	s["cam"] = cam.global_position
	_log.append(s)

func _detrend_p2p(key: String, axis: int) -> float:
	# peak to peak of one coordinate after a linear trend is taken out (cm)
	var n := _log.size()
	if n < 3:
		return 0.0
	var a: float = (_log[0][key] as Vector3)[axis]
	var b: float = (_log[n - 1][key] as Vector3)[axis]
	var lo := 1e9
	var hi := -1e9
	for i in n:
		var v: float = (_log[i][key] as Vector3)[axis] - lerpf(a, b, float(i) / (n - 1))
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return (hi - lo) * 100.0

func _period(key: String, axis: int) -> float:
	# mean time between upward crossings of the mean (after a 0.25 s smoothing), seconds
	var n := _log.size()
	var mean := 0.0
	for i in n:
		mean += (_log[i][key] as Vector3)[axis]
	mean /= n
	var cross: Array = []
	var prev := 0.0
	var sm := 0.0
	for i in n:
		var v: float = (_log[i][key] as Vector3)[axis] - mean
		sm = lerpf(sm, v, 0.25)
		if i > 8 and prev < 0.0 and sm >= 0.0:
			cross.append(float(_log[i].t))
		prev = sm
	if cross.size() < 2:
		return 0.0
	return (float(cross[-1]) - float(cross[0])) / (cross.size() - 1)

func _report() -> void:
	print("== loco probe: %s body=%s frames=%d" % [_probe, Game.profile.body, _log.size()])
	if _probe in ["idle", "guard", "tired"]:
		var from := 8.0 if _probe == "tired" else 0.0
		if from > 0.0:
			var keep: Array = []
			for s: Dictionary in _log:
				if float(s.t) >= from:
					keep.append(s)
			var early: Array = []
			for s: Dictionary in _log:
				if float(s.t) < from + 4.0 and float(s.t) >= from:
					early.append(s)
			var all := _log
			_log = early
			print("  first 4 s after the exertion:")
			_idle_block()
			_log = keep.slice(keep.size() - mini(keep.size(), 240))
			print("  last 8 s:")
			_idle_block()
			_log = all
		else:
			_idle_block()
		return
	_walk_block()

func _idle_block() -> void:
	for n: String in ["Spine2", "Head", "LeftArm", "RightArm", "Hips"]:
		var k := n + "_l"
		print("  %-8s p2p cm  x %.2f  y %.2f  z %.2f   period(y) %.2f s" % [n, _detrend_p2p(k, 0), _detrend_p2p(k, 1), _detrend_p2p(k, 2), _period(k, 1)])
	var clip_n := ""
	for s: Dictionary in _log:
		if float(s.clip_w) > 0.05:
			clip_n = str(s.clip)
	print("  clip under the pose: %s" % (clip_n if clip_n != "" else "(none: procedural)"))
	var fl := 0
	for e in Sfx._breath_log:
		fl += 1
	print("  breath sounds asked for: %d" % fl)

func _walk_block() -> void:
	# contacts: a foot is down while its ankle is within 3 cm of its standing height over the ground under it
	var rest_h := {}
	for side: String in ["Left", "Right"]:
		# (the ankle's height over the ground with the foot flat in the stride: the 5th percentile while walking)
		var hs: Array = []
		for s0: Dictionary in _log:
			if float(s0.amt) > 0.9:
				var a0: Vector3 = s0[side + "Foot"]
				hs.append(a0.y - _gy(a0.x, a0.z))
		hs.sort()
		rest_h[side] = hs[int(hs.size() * 0.05)] if not hs.is_empty() else 0.1
	var slides: Array = []
	var plants: Array = []           # [t, side, pos]
	var worst_slide := 0.0
	var worst_at := 0.0
	var steps_moving := 0
	for side: String in ["Left", "Right"]:
		var down := false
		var acc := 0.0
		var last := Vector3.ZERO
		for s: Dictionary in _log:
			var a: Vector3 = s[side + "Foot"]
			var is_down: bool = a.y - _gy(a.x, a.z) < float(rest_h[side]) + 0.03
			if is_down and not down:
				acc = 0.0
				plants.append([float(s.t), side, a, float(s.amt)])
			elif is_down and down:
				acc += Vector2(a.x - last.x, a.z - last.z).length()
			elif not is_down and down:
				slides.append([acc, float(s.t), side])
				if _args.has("verbose") and acc > 0.03:
					print("    slide %.1f cm %s ending %.2f s amt %.2f clip %s" % [acc * 100.0, side, float(s.t), float(s.amt), str(s.clip)])
				if acc > worst_slide:
					worst_slide = acc
					worst_at = float(s.t)
			down = is_down
			last = a
		if down:
			slides.append([acc, _t, side])
	plants.sort_custom(func(x, y): return x[0] < y[0])
	var step_lens: Array = []
	for i in range(1, plants.size()):
		if plants[i][1] != plants[i - 1][1] and float(plants[i][3]) > 0.8:
			step_lens.append(Vector2((plants[i][2] as Vector3).x - (plants[i - 1][2] as Vector3).x, (plants[i][2] as Vector3).z - (plants[i - 1][2] as Vector3).z).length())
	var sl_sorted := slides.map(func(x): return float(x[0]) * 100.0)
	sl_sorted.sort()
	var med: float = sl_sorted[sl_sorted.size() / 2] if not sl_sorted.is_empty() else 0.0
	var p90: float = sl_sorted[int(sl_sorted.size() * 0.9)] if not sl_sorted.is_empty() else 0.0
	var over3 := 0
	for v: float in sl_sorted:
		if v > 3.0:
			over3 += 1
	print("  foot slide per plant (cm): median %.1f  90%% %.1f  worst %.1f @ %.1f s   plants over 3 cm: %d of %d" % [med, p90, worst_slide * 100.0, worst_at, over3, sl_sorted.size()])
	var sm := 0.0
	for v: float in step_lens:
		sm += v
	print("  step length at full stride (m): mean %.2f over %d steps (ROAD_SPEED %.2f m/s)" % [sm / maxf(step_lens.size(), 1), step_lens.size(), FighterRig.ROAD_SPEED])
	# cadence and the clip's pace against the ground's
	var walk_t := 0.0
	var clip_adv := 0.0
	var ground := 0.0
	var in_place := 0.0
	var glide := 0.0
	for i in range(1, _log.size()):
		var s: Dictionary = _log[i]
		var p: Dictionary = _log[i - 1]
		var hv := Vector2((s.Hips as Vector3).x - (p.Hips as Vector3).x, (s.Hips as Vector3).z - (p.Hips as Vector3).z).length() / float(s.dt)
		if str(s.clip) == "walk" and str(p.clip) == "walk" and float(s.amt) > 0.9:
			var d := float(s.clip_t) - float(p.clip_t)
			if d > -0.5 and d < 0.5:
				clip_adv += d
				walk_t += float(s.dt)
				ground += Vector2((s.pos as Vector3).x - (p.pos as Vector3).x, (s.pos as Vector3).z - (p.pos as Vector3).z).length()
		if float(s.amt) > 0.3 and hv < 0.2:
			in_place += float(s.dt)
		if float(s.amt) < 0.15 and hv > 0.35:
			glide += float(s.dt)
	var cyc := rig.skin.clip_ground_stride("walk")
	print("  walk clip: whole sweep %.2f m a cycle, planted-foot travel %.2f m a cycle (%.2f m/s at its own pace)" % [rig.skin.clip_stride("walk"), cyc, cyc / SkinDriver.clip_length("walk")])
	var clip_len := SkinDriver.clip_length("walk")
	if walk_t > 0.0:
		var rate := clip_adv / walk_t
		var want := (ground / walk_t) / maxf(cyc, 0.01) * clip_len
		print("  walk clip played at %.2fx its own speed; the ground covered asks for %.2fx (clip cycle %.2f m in %.2f s)  -> rate/ground %.2f" % [rate, want, cyc, clip_len, rate / maxf(want, 0.001)])
		print("  cadence %.0f steps a minute" % (plants.filter(func(x): return float(x[3]) > 0.8).size() / maxf(walk_t, 0.01) * 60.0))
	print("  walking in place (stride on, hips < 0.2 m/s): %.2f s   gliding (stride off, hips > 0.35 m/s): %.2f s" % [in_place, glide])
	# turns: the hips' facing against the rig's, frame to frame
	var worst_yaw := 0.0
	var worst_yaw_t := 0.0
	var lag := 0.0
	for i in range(1, _log.size()):
		var d2 := absf(wrapf(float(_log[i].hyaw) - float(_log[i - 1].hyaw), -PI, PI))
		if _args.has("verbose") and d2 > deg_to_rad(8.0):
			print("    hips turn %.1f deg @ %.2f s (rig yaw %.1f, hips %.1f)" % [rad_to_deg(d2), float(_log[i].t), rad_to_deg(float(_log[i].yaw)), rad_to_deg(float(_log[i].hyaw))])
		if d2 > worst_yaw:
			worst_yaw = d2
			worst_yaw_t = float(_log[i].t)
		lag = maxf(lag, absf(wrapf(float(_log[i].hyaw) - float(_log[i].yaw), -PI, PI)))
	print("  hips turn: worst %.1f deg in one frame @ %.1f s (%.0f deg/s); most the hips trail the rig's facing %.0f deg" % [rad_to_deg(worst_yaw), worst_yaw_t, rad_to_deg(worst_yaw) / float(_log[1].dt), rad_to_deg(lag)])
	# the hips' height over the ground (slopes and steps): the biggest change in one frame
	var worst_dy := 0.0
	var worst_dy_t := 0.0
	for i in range(1, _log.size()):
		var dy := absf((_log[i].Hips as Vector3).y - (_log[i - 1].Hips as Vector3).y)
		if dy > worst_dy:
			worst_dy = dy
			worst_dy_t = float(_log[i].t)
	print("  hips height: worst jump %.1f cm in one frame @ %.1f s" % [worst_dy * 100.0, worst_dy_t])
	if _probe == "course":
		var sink := 0.0
		var sink_t := 0.0
		for s: Dictionary in _log:
			for side: String in ["Left", "Right"]:
				var a: Vector3 = s[side + "Foot"]
				var toe: Vector3 = s[side + "ToeBase"]
				var sk := float(rest_h[side]) - (minf(a.y - _gy(a.x, a.z), toe.y - _gy(toe.x, toe.z) + float(rest_h[side]) * 0.5))
				if sk > sink:
					sink = sk
					sink_t = float(s.t)
					if _args.has("verbose"):
						print("    sink %s ankle %s g %.2f toe %s g %.2f rest %.3f" % [side, str(a), _gy(a.x, a.z), str(toe), _gy(toe.x, toe.z), float(rest_h[side])])
		print("  most a foot goes under the course (ankle or toe): %.1f cm @ %.1f s" % [sink * 100.0, sink_t])
	if follow:
		print("  camera: %d obstruction frames, %d pull-ins" % [follow.blocked_frames, follow.pull_ins])

# ---------------------------------------------------------------- the room
func _room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.34, 0.37, 0.41)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.86)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 30, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	# the course as a mesh: strips across it at the height `_gy` gives, checkered every half metre
	var sf := SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := 8.0
	while z > -40.0:
		var z2 := z - 0.04
		for x0 in range(-10, 4):
			var x1 := float(x0)
			var x2 := x1 + 1.0
			var c := Color(0.42, 0.42, 0.38) if (int(floor(-z * 2.0)) + x0) % 2 == 0 else Color(0.33, 0.34, 0.31)
			for v: Vector3 in [Vector3(x1, _gy(x1, z), z), Vector3(x2, _gy(x2 - 0.001, z), z), Vector3(x2, _gy(x2 - 0.001, z2), z2),
					Vector3(x1, _gy(x1, z), z), Vector3(x2, _gy(x2 - 0.001, z2), z2), Vector3(x1, _gy(x1, z2), z2)]:
				sf.set_color(c)
				sf.add_vertex(v)
			# the risers of a step: a vertical face where the height jumps
			var ha := _gy(x1 + 0.5, z)
			var hb := _gy(x1 + 0.5, z2)
			if absf(ha - hb) > 0.05:
				for v2: Vector3 in [Vector3(x1, minf(ha, hb), z2), Vector3(x2, minf(ha, hb), z2), Vector3(x2, maxf(ha, hb), z2),
						Vector3(x1, minf(ha, hb), z2), Vector3(x2, maxf(ha, hb), z2), Vector3(x1, maxf(ha, hb), z2)]:
					sf.set_color(Color(0.28, 0.28, 0.26))
					sf.add_vertex(v2)
		z = z2
	sf.generate_normals()
	var gm := MeshInstance3D.new()
	gm.mesh = sf.commit()
	var gmat := StandardMaterial3D.new()
	gmat.vertex_color_use_as_albedo = true
	gmat.roughness = 0.9
	gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	gm.material_override = gmat
	add_child(gm)
	# pillars beside the way (things that come between a trailing camera and the knight)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.5, 0.47, 0.42)
	# (those at 0.95 m to the right stand between the trailing camera and the knight for a second or two as they pass)
	for zp: float in [0.0, -7.0, -13.0, -22.0, -28.0]:
		for xp: float in [0.95 if int(zp) % 2 == 0 else 1.9, -1.9, -5.05 if int(zp) % 2 == 0 else -4.1]:
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.6, 3.2, 0.6)
			b.mesh = bm
			b.material_override = pm
			b.position = Vector3(xp, _gy(0, zp) + 1.6, zp)
			add_child(b)
			_walls.append(b)
