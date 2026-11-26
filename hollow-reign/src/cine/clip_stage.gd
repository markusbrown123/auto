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
var cam_mode := ""
var _noise := FastNoiseLite.new()

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--take="):
			take = a.trim_prefix("--take=")
	Game.profile = Game.default_profile()
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
	if take == "travel":
		# a chest by the fallen column: seen on the walk in, out of frame once the duel begins
		arena.prop("chest", 0.75, Vector3(-2.9, 0, 8.6), 160.0)
	_script_take()
	events.sort_custom(func(a, b): return a[0] < b[0])
	_camera(0.0)

func at(time: float, c: Callable) -> void:
	events.append([PRE + time, c])

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

func _camera(dt: float) -> void:
	var u := clampf((t - PRE) / length, 0.0, 1.0)
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
	if t >= PRE + length + 0.1:
		get_tree().quit()
