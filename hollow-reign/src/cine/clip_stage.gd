extends Node3D
## Films one "take" of the Sentinel duel from the real scene for the cinematic
## combat mode. Run with Godot's movie writer:
##   godot --path . --write-movie take.avi --fixed-fps 30 res://src/cine/clip_stage.tscn -- --take=a_parry
## Every take is deterministic and starts from one of two shared poses (READY or
## OPEN) at a multiple of the loop period, so separately filmed clips join on
## identical frames. tools/render_clips.sh cuts the takes into clips.

const P := 3.0            # loop period: every clip boundary sits on a multiple of this
const PRE := 3.0          # pre-roll before the recorded part (discarded when cutting)

## Attack definitions shared with data/cine_sentinel.json (times in seconds from clip start).
const ATTACKS := {
	"a": {"dir": Vector2(0, -1), "kind": "slam", "start": 0.5, "windup": 1.5, "swing": 0.34, "branch": 1.65, "parry": Vector2(0, 1), "dodge": 1.0},
	"b": {"dir": Vector2(-1, 0), "kind": "slash", "start": 0.5, "windup": 1.3, "swing": 0.30, "branch": 1.45, "parry": Vector2(1, 0), "dodge": -1.0},
}

var arena: Arena
var knight: FighterRig
var foe: FighterRig
var cam: Camera3D
var take := "idle"
var t := 0.0
var events: Array = []        # [time, Callable], sorted
var length := 3.0
var gap := 3.0
var cam_base := Vector3.ZERO
var cam_look := Vector3.ZERO
var cam_kick := 0.0
## The Courtyard road: where the knight stands at each of the seven stops, and what they are looking toward.
const ROAD := [
	[Vector3(0.0, 0, 12.5), Vector3(0.0, 1.2, 2.0)],
	[Vector3(-5.0, 0, 9.0), Vector3(-12.0, 1.4, -2.0)],
	[Vector3(-8.0, 0, 5.0), Vector3(-6.0, 1.6, -10.0)],
	[Vector3(7.0, 0, 6.5), Vector3(12.0, 1.4, -3.0)],
	[Vector3(2.0, 0, -5.0), Vector3(0.0, 2.5, -15.0)],
	[Vector3(-7.5, 0, -2.0), Vector3(-9.0, 2.5, -9.0)],
]
var road_i := -1
var road_anchors: Array = []
var cam_mode := ""
var _walk_from := Vector3.ZERO
var _walk_to := Vector3.ZERO
var _road_from: Array = []
var _road_to: Array = []
var _exported := false
var _noise := FastNoiseLite.new()

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--take="):
			take = a.trim_prefix("--take=")
	Game.profile = Game.default_profile()
	for a2 in OS.get_cmdline_user_args():
		if a2.begins_with("--body="):
			Game.profile.body = a2.trim_prefix("--body=")
	for id in ["w_knight_sword", "s_garrison"]:
		Game.profile.inventory.append(id)
		Game.profile.equipped[Db.item(id).slot] = id
	var f: Dictionary = Db.foes["ashen_sentinel"]
	arena = Arena.new()
	add_child(arena)
	arena.build("courtyard")
	arena.set_process(false)      # steady firelight: flicker would not match across cuts
	gap = 2.5 + (float(f.rig.scale) - 1.0) * 1.5
	knight = FighterRig.new()
	add_child(knight)
	knight.build(Duel.player_look(), false)
	knight.position = Vector3(0, 0, gap * 0.5)
	foe = FighterRig.new()
	add_child(foe)
	var look: Dictionary = f.rig.duplicate()
	look["skin"] = "res://assets/models/ashen_sentinel.glb"
	look.merge(Duel.weapon_model("w_ashen_great"))
	foe.build(look, true)
	foe.position = Vector3(0, 0, -gap * 0.5)
	foe.rotation.y = PI
	for r in [knight, foe]:
		r.loop_period = P
	var key := SpotLight3D.new()
	key.light_color = Color(arena.theme.sun).lerp(Color.WHITE, 0.5)
	key.light_energy = 5.0
	key.spot_range = 16.0
	key.spot_angle = 42.0
	add_child(key)
	key.position = Vector3(4.5, 6.5, 4.0)
	key.look_at(Vector3(0, 1.2, 0))
	cam = Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	cam.make_current()
	var pz := gap * 0.5
	var foe_h := 1.4 * float(f.rig.scale)
	cam_base = Vector3(1.15, 1.62, pz + 1.55)
	cam_look = Vector3(0.38, foe_h * 0.82, -pz)
	if take.begins_with("road_"):
		road_i = int(take.trim_prefix("road_"))
		foe.visible = road_i == 6        # he waits in the inner ward; the road only reaches him at the end
		_dress_road()
	if take == "travel":
		# a chest by the fallen column: seen on the walk in, out of frame once the duel begins
		arena.prop("chest", 0.75, Vector3(-2.9, 0, 8.6), 160.0)
	_script_take()
	events.sort_custom(func(a, b): return a[0] < b[0])
	_camera(0.0)

func at(time: float, c: Callable) -> void:
	events.append([PRE + time, c])

func _road_pose(i: int) -> Array:
	# [knight position, facing, camera position, camera look] for stop i
	if i >= ROAD.size():
		return [Vector3(0, 0, gap * 0.5), Vector3(0, 0, -1), cam_base, cam_look]
	if i < 0:
		# before the first stop: outside the breach, looking in
		var first: Array = _road_pose(0)
		return [first[0] + Vector3(1.5, 0, 9.0), Vector3(0, 0, -1), first[2] + Vector3(3.0, 2.2, 10.0), first[3] + Vector3(0, 1.5, 0)]
	var spot: Vector3 = ROAD[i][0]
	var target: Vector3 = ROAD[i][1]
	var dir := Vector3(target.x - spot.x, 0, target.z - spot.z).normalized()
	var right := dir.cross(Vector3.UP)
	return [spot, dir, spot - dir * 2.5 + right * 0.95 + Vector3(0, 1.72, 0), spot + dir * 6.0 + Vector3(0, 1.35, 0)]

## Puts each choice at this stop into the picture: a chest, a lever, a shrine light, or a path marker.
func _dress_road() -> void:
	var stage: Dictionary = Db.region_by_id["courtyard"].stages[road_i]
	var pose: Array = _road_pose(road_i)
	var right: Vector3 = pose[1].cross(Vector3.UP)
	var n: int = stage.options.size()
	for k in n:
		var o: Dictionary = stage.options[k]
		var at: Vector3 = pose[0] + pose[1] * (5.2 if road_i < 6 else 0.0) + right * (float(k) - (n - 1) * 0.5) * 4.2
		if road_i == 6:
			at = Vector3(0, 0, -gap * 0.5)
		at.y = 0.0
		road_anchors.append(at + Vector3(0, 0.9 if road_i < 6 else 2.0, 0))
		match str(o.type):
			"treasure":
				arena.prop("chest", 0.75, at, rad_to_deg(atan2(pose[1].x, pose[1].z)) + 180.0)
			"shrine":
				arena.prop("brazier", 1.5, at, 0.0)
				arena.fire(at + Vector3(0, 1.4, 0), 1.8, 7.0, false)
			"lever":
				var back := Backdrop.new()
				add_child(back)
				back.arena = arena
				back.props = Node3D.new()
				back.add_child(back.props)
				back.add_prop("lever", at).rotation.y = atan2(pose[1].x, pose[1].z)
				back.set_process(false)
			"fight":
				var back2 := Backdrop.new()
				add_child(back2)
				back2.arena = arena
				back2.props = Node3D.new()
				back2.add_child(back2.props)
				back2.add_prop("marker", at)
				back2.set_process(false)

func _open_preroll() -> void:
	# the shared OPEN pose: the Sentinel reeling, the knight ready
	events.append([1.0, foe.stagger])

func _script_take() -> void:
	var parts := take.split("_")
	if ATTACKS.has(parts[0]) and parts.size() == 2:
		var A: Dictionary = ATTACKS[parts[0]]
		length = 6.0
		var impact: float = A.start + A.windup
		at(A.start, func(): foe.telegraph(A.dir, A.windup, A.swing, A.kind))
		match parts[1]:
			"parry":
				at(impact - 0.12, func(): knight.parry(A.parry))
				at(impact, func():
					_sparks(knight.chest_point().lerp(foe.blade_mid(), 0.45), Color(1.0, 0.85, 0.55), 30)
					foe.stagger()
					knight.guard()
					cam_kick = 0.35)
			"dodge":
				at(impact - 0.28, func(): knight.dodge(A.dodge))
				at(impact + 0.4, foe.stagger)
			"block":
				at(impact - 0.33, func(): knight.blocking = true)
				at(impact, func():
					_sparks(knight.chest_point() + Vector3(-0.15, 0.1, -0.45), Color(1.0, 0.8, 0.6), 14)
					knight.flash(0.5)
					cam_kick = 0.3)
				at(impact + 0.7, func(): knight.blocking = false)
				at(impact + 0.9, foe.guard)
			"hit":
				at(impact, func():
					_sparks(knight.chest_point(), Color(0.85, 0.15, 0.1), 16)
					knight.hurt()
					cam_kick = 0.7)
				at(impact + 0.9, foe.guard)
		return
	match take:
		"idle":
			length = P
		"open":
			_open_preroll()
			length = P
		"counter":
			_open_preroll()
			length = P
			at(0.15, func(): knight.swing(Vector2(-0.7, -0.7), 0.5))
			at(0.45, func():
				_sparks(foe.chest_point() + Vector3(0, 0, 0.4), Color(1.0, 0.8, 0.5), 26)
				foe.flash(1.0)
				cam_kick = 0.3)
			at(0.9, foe.guard)
		"recover":
			_open_preroll()
			length = P
			at(0.2, foe.guard)
		"victory":
			_open_preroll()
			length = 6.0
			cam_mode = "victory"
			at(0.3, func(): knight.swing(Vector2(-0.7, -0.7), 0.6))
			at(0.68, func():
				_sparks(foe.chest_point(), Color(1.0, 0.5, 0.2), 60)
				foe.flash(1.0)
				foe.die(-1.0)
				cam_kick = 0.8)
		"defeat":
			length = 4.5
			cam_mode = "defeat"
			at(0.15, func(): knight.die(1.0))
		"road_0", "road_1", "road_2", "road_3", "road_4", "road_5", "road_6":
			length = 6.0
			cam_mode = "road"
			var from: Array = _road_pose(road_i - 1)
			var to: Array = _road_pose(road_i)
			# walk at FighterRig.ROAD_SPEED (it was 2-5 m/s): the walk covers only what that pace allows in the clip, so the
			# clip opens part-way along the path, camera carried with the knight
			var reach := FighterRig.ROAD_SPEED * (length * 0.8 - WALK_RAMP)
			if (to[0] as Vector3).distance_to(from[0]) > reach:
				var shift: Vector3 = (to[0] as Vector3) - ((to[0] as Vector3) - (from[0] as Vector3)).normalized() * reach - (from[0] as Vector3)
				from = [from[0] + shift, from[1], from[2] + shift, from[3] + shift]
			knight.position = from[0]
			knight.rotation.y = atan2(-from[1].x, -from[1].z)
			knight.walking = true
			_walk_from = from[0]
			_walk_to = to[0]
			_road_from = from
			_road_to = to
		"walktest":
			length = 5.0
			cam_mode = "walktest"
			knight.position = Vector3(0, 0, gap * 0.5 + 6.0)
			knight.walking = true
			_walk_from = knight.position
			_walk_to = Vector3(0, 0, gap * 0.5)
		"travel":
			# the walk across the ward, as one unbroken camera move ending on the combat camera
			length = 6.0
			cam_mode = "travel"
		"intro":
			length = 6.0
			cam_mode = "intro"
			at(1.2, foe.roar)

func _sparks(pos: Vector3, color: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.45
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	p.mesh = q
	p.material_override = Look.particle(color)
	p.direction = Vector3(0, 0.8, 0.6)
	p.spread = 40.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -9.0, 0)
	p.use_fixed_seed = true
	p.seed = 7
	add_child(p)
	p.global_position = pos
	p.emitting = true
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 3.0
	l.omni_range = 4.0
	add_child(l)
	l.global_position = pos
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.18)
	tw.tween_callback(l.queue_free)

const WALK_RAMP := 0.6    # seconds to get up to, and down from, walking pace

## Distance fraction for a walk of constant speed with a WALK_RAMP ease at each end; w is the fraction of the walk's time.
func _trapezoid(w: float) -> float:
	var af := WALK_RAMP / (length * 0.8)
	var vmax := 1.0 / (1.0 - af)
	if w < af:
		return 0.5 * vmax * w * w / af
	if w < 1.0 - af:
		return 0.5 * vmax * af + vmax * (w - af)
	return 1.0 - 0.5 * vmax * (1.0 - w) * (1.0 - w) / af

func _camera(dt: float) -> void:
	var u := clampf((t - PRE) / length, 0.0, 1.0)
	if _walk_to != Vector3.ZERO:
		var wu := clampf((t - PRE - 0.3) / (length * 0.8), 0.0, 1.0)
		knight.position = _walk_from.lerp(_walk_to, _trapezoid(wu))
		if cam_mode == "road":
			# turn to the way being walked, then to what this stop looks at
			var heading := (_walk_to - _walk_from).normalized()
			var face: Vector3 = heading.lerp(_road_to[1], smoothstep(0.75, 1.0, wu)) if wu > 0.02 else _road_from[1].lerp(heading, smoothstep(0.0, 0.02, wu) )
			knight.rotation.y = lerp_angle(knight.rotation.y, atan2(-face.x, -face.z), 0.12)
		if wu >= 1.0:
			knight.walking = false
	var pos := cam_base
	var look := cam_look
	var pz := gap * 0.5
	match cam_mode:
		"intro":
			# sweep from the Sentinel's flank round to the combat camera, arriving early and holding
			var k := ease(clampf(u / 0.8, 0.0, 1.0), -2.0)
			var a := lerpf(1.25, 0.0, k)
			var r := 6.0
			var orbit := Vector3(sin(a) * r, 0.7 + k * 0.9, -pz + cos(a) * r * 0.9)
			pos = orbit.lerp(cam_base, k * k)
			look = Vector3(0, 1.9, -pz).lerp(cam_look, k)
		"travel":
			var k2 := ease(clampf(u / 0.9, 0.0, 1.0), -2.2)
			pos = (cam_base + Vector3(2.6, 1.3, 11.0)).lerp(cam_base, k2)
			look = (cam_look + Vector3(-1.2, 0.6, 0.0)).lerp(cam_look, k2)
		"road":
			var ck := smoothstep(0.0, 1.0, clampf(u / 0.92, 0.0, 1.0))
			pos = (_road_from[2] as Vector3).lerp(_road_to[2], ck)
			look = (_road_from[3] as Vector3).lerp(_road_to[3], ck)
		"walktest":
			pos = knight.position + Vector3(3.6, 1.3, 0.6)
			look = knight.position + Vector3(0, 1.0, -0.4)
		"victory":
			pos = cam_base + Vector3(-0.9, 0.15, -0.9) * ease(u, 0.5)
			look = cam_look + Vector3(0, -0.7, 0) * ease(u, 0.5)
		"defeat":
			pos = cam_base + Vector3(0.3, 1.6, 0.9) * ease(u, 0.6)
			look = cam_look.lerp(Vector3(0, 0.5, pz), ease(u, 0.6))
	cam_kick = maxf(0.0, cam_kick - dt * 2.6)
	var shake := cam_kick * cam_kick
	var off := Vector3(_noise.get_noise_2d(t * 70.0, 0.0), _noise.get_noise_2d(0.0, t * 70.0), 0) * 0.12 * shake
	cam.position = pos + off
	cam.look_at(look + off * 0.5)

func _process(delta: float) -> void:
	t += delta
	while not events.is_empty() and t >= events[0][0]:
		var e: Array = events.pop_front()
		e[1].call()
	_camera(delta)
	if road_i >= 0 and not _exported and t >= PRE + length - 0.05:
		# record where each choice sits in the final frame, so the game can put its hotspots there
		_exported = true
		var size := get_viewport().get_visible_rect().size
		var spots: Array = []
		for a in road_anchors:
			var sp := cam.unproject_position(a)
			spots.append([snappedf(sp.x / size.x, 0.001), snappedf(sp.y / size.y, 0.001)])
		var f := FileAccess.open("res://art/takes/road_%d.json" % road_i, FileAccess.WRITE)
		f.store_string(JSON.stringify({"stage": road_i, "spots": spots}))
		f.close()
	if t >= PRE + length + 0.1:
		get_tree().quit()
