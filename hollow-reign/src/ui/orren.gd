class_name Orren
extends Node3D
## Orren, the armourer, in his workshop (Workshop builds the room round him). The rigged model
## (assets/models/merchant_v1.glb) is posed through SkinDriver.drive() every frame from control points this script
## works out: there is no authored clip for a smith's work, so his work is procedural, over the library's `idle` for
## the weight in his legs and hips.
##
## Between customers he goes round his own small routine, each piece taken up from where it lies and put back there:
##   hammer   the hammer and tongs from the anvil's side: a bar held on the anvil and struck (sparks, a ring of metal)
##   inspect  a finished blade from the rack beside him, raised and turned in the light, sighted down its edge
##   wipe     the rag from his belt, hands worked clean in it
##   lean     both hands on the anvil, weight forward, watching the knight
## When he speaks (Story.speaker == "orren") he puts down what he holds, faces the knight and talks: the head and the
## free hand move with the loudness of his own recorded line (ENV, measured from assets/audio/vo/orren_*.ogg, 50 ms
## steps), since the model has no jaw to open, and each line has its own business: on "older than my whole line"
## he points at the knight's sword, on "I just remind it" he takes up the hammer and taps the anvil with the words, and
## the line about caring for a blade is said to a blade he holds, his eyes on it, not on the knight; on his first
## line his look goes down the knight's kit and back, and he beckons once. (Plain business, no comic beats.)
## He greets the knight when the shop opens.

signal struck(at: Vector3)          # the hammer met the bar (world position): the workshop answers with sparks and sound

const MODEL := "res://assets/models/merchant_v1.glb"
const HEIGHT := 1.8                 # metres; SkinDriver fits every model to 1.95
const ACTS := ["hammer", "inspect", "wipe", "lean"]
const ACT_LEN := {"hammer": [7.0, 10.0], "inspect": [5.0, 7.0], "wipe": [3.0, 4.0], "lean": [5.0, 8.0], "greet": [2.2, 2.2]}
const ENV_STEP := 0.05
## Loudness of each recorded line, 0..1 per 50 ms (from ffmpeg RMS, normalised to the line's 95th percentile).
const ENV := {
	"orren_intro_01": [0.01, 0.06, 0.06, 0.06, 0.07, 0.06, 0.05, 0.04, 0.04, 0.08, 0.09, 0.09, 0.1, 1, 1, 0.73, 0.29, 0.99, 0.92, 1, 0.87, 0.86, 1, 0.78, 0.7, 0.92, 0.87, 0.31, 0.15, 0.38, 0.37, 0.85, 0.63, 0.55, 0.56, 0.47, 0.36, 0.04, 0.39, 0.4, 0.32, 0.12, 0.01, 0.05, 0.02, 0.01, 0.04, 0.07, 0.08, 0.08, 0.06, 0.04, 0.01, 0.13, 0.12, 0.88, 1, 0.81, 0.12, 0.04, 0.01, 0.02, 0.08, 0.13, 0.18, 0.25, 0.28, 0.33, 0.08, 0.02, 0.04, 0.35, 0.82, 0.82, 0.9, 0.73, 0.97, 1, 0.91, 0.63, 0.75, 0.84, 0.91, 0.5, 0.16, 0.36, 0.55, 0.99, 0.65, 0.65, 0.57, 0.55, 0.13, 0.39, 0.51, 0.24, 0.05, 0.03, 0.15, 0.09, 0.05, 0.03, 0.04, 0.04, 0.52, 1, 0.76, 0.14, 0.03, 0.01, 0, 0, 0, 0, 0],
	"orren_intro_02": [0, 0.06, 0.1, 0.2, 0.27, 1, 0.67, 0.14, 0.07, 0.04, 0.03, 0.52, 0.92, 0.99, 0.79, 0.3, 0.07, 0.08, 0.09, 0.52, 0.86, 0.76, 0.88, 0.8, 0.55, 0.5, 0.25, 0.04, 0.04, 0.1, 0.12, 0.14, 0.16, 0.33, 0.29, 0.07, 0.66, 1, 0.93, 0.54, 0.17, 0.11, 0.09, 0.58, 0.88, 0.63, 0.66, 0.65, 0.37, 0.58, 0.79, 0.52, 0.71, 0.88, 1, 0.66, 0.34, 0.75, 0.79, 0.49, 0.48, 0.88, 0.82, 0.85, 0.82, 0.91, 0.84, 1, 0.66, 0.61, 0.12, 0.21, 0.36, 1, 1, 0.78, 1, 0.52, 0.54, 0.2, 0.49, 0.68, 0.8, 0.47, 0.21, 0.37, 0.63, 0.77, 0.74, 0.7, 0.35, 0.27, 0.32, 0.06, 0.02, 0.05, 0.06, 0.06, 0.04, 0.03, 0.01, 0.01, 0.02, 0.04, 0.38, 0.48, 0.49, 0.71, 0.57, 0.13, 0.15, 0.61, 0.37, 0.34, 0.56, 0.58, 0.51, 0.09, 0.25, 0.14, 0.03, 0.04, 0.09, 0.07, 0.03, 0.01, 0, 0, 0, 0, 0, 0],
	"orren_intro_03": [0.01, 0.11, 0.15, 0.22, 0.69, 0.73, 0.22, 0.07, 0.02, 0.04, 0.07, 0.08, 0.07, 0.13, 0.09, 0.14, 0.34, 0.68, 1, 1, 0.66, 0.79, 0.79, 1, 0.99, 0.84, 0.61, 0.54, 0.59, 1, 0.98, 1, 0.8, 0.72, 0.4, 0.68, 1, 0.8, 0.62, 0.16, 0.45, 0.64, 0.43, 0.49, 0.44, 0.23, 0.11, 0.16, 0.21, 0.02, 0.03, 0.03, 0.04, 0.03, 0.03, 0.04, 0.48, 1, 1, 0.95, 0.81, 0.97, 0.8, 0.8, 0.57, 0.72, 0.8, 0.7, 0.67, 0.76, 0.67, 0.88, 0.83, 0.7, 0.59, 0.59, 0.55, 0.19, 0.51, 0.29, 0.06, 0.45, 0.56, 0.47, 0.52, 0.48, 0.32, 0.13, 0.02, 0.11, 0.12, 0.05, 0.01, 0.01, 0, 0.05, 0.32, 0.85, 1, 0.76, 0.44, 1, 0.63, 0.09, 0.44, 0.6, 0.79, 0.62, 0.85, 0.98, 0.7, 0.48, 0.27, 0.25, 0.23, 0.06, 0.07, 0.11, 0.05, 0.05, 0.02, 0.02, 0.01, 0.01, 0.01, 0.02, 0.02, 0.02, 0.29, 0.85, 0.13, 0.04, 0.01, 0.05, 0.21, 0.2, 0.23, 0.22, 0.27, 0.43, 0.06, 0.14, 0.68, 1, 0.73, 0.49, 0.55, 0.89, 0.84, 0.66, 0.56, 0.38, 0.99, 0.96, 1, 0.73, 0.65, 0.33, 0.39, 0.79, 0.75, 0.56, 0.15, 0.33, 0.56, 0.51, 0.53, 0.41, 0.19, 0.12, 0.13, 0.19, 0.05, 0.01, 0.02, 0.03, 0.03, 0.02, 0.02, 0.01, 0.07, 0.31, 0.88, 0.92, 1, 0.71, 0.68, 0.19, 0.88, 0.94, 0.69, 0.64, 0.66, 0.65, 0.51, 0.37, 0.39, 0.67, 0.6, 0.63, 0.64, 0.54, 0.5, 0.53, 0.58, 0.31, 0.27, 0.26, 0.05, 0.07, 0.45, 0.47, 0.5, 0.6, 0.75, 0.68, 0.23, 0.04, 0.08, 0.13, 0.08, 0.02, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.23, 0.92, 0.72, 0.81, 0.62, 0.34, 0.22, 0.37, 0.33, 0.16, 0.03, 0.04, 0.16, 0.3, 0.53, 0.5, 0.53, 0.33],
	"orren_idle_01": [0, 0.04, 0.12, 0.54, 1, 0.34, 0.08, 0.03, 0.02, 0.09, 0.14, 0.16, 0.21, 0.29, 0.05, 0.01, 0.14, 1, 0.81, 0.17, 0.32, 0.73, 0.7, 0.27, 0.11, 0.09, 0.48, 0.91, 0.83, 1, 0.74, 1, 1, 0.63, 0.66, 0.65, 0.77, 0.84, 0.94, 0.89, 0.74, 0.57, 0.76, 0.66, 0.17, 0.06, 0.11, 1, 0.67, 0.22, 0.12, 0.53, 0.6, 0.5, 0.35, 0.33, 0.48, 0.39, 0.36, 0.4, 0.69, 0.69, 0.25, 0.64, 0.53, 0.57, 0.54, 0.53, 0.52, 0.32, 0.34, 0.57, 0.37, 0.06, 0.29, 0.29, 0.25, 0.16, 0.14, 0.07, 0.03, 0.03, 0.04, 0.05, 0.05, 0.03, 0.02, 0.01, 0.51, 1, 0.97, 1, 0.23, 0.08, 0.91, 0.86, 0.71, 1, 0.72, 0.74, 0.68, 0.92, 0.58, 0.47, 0.28, 0.18, 0.7, 1, 0.86, 0.59, 0.56, 0.99, 0.6, 0.15, 0.1, 0.92, 0.74, 0.35, 0.34, 0.55, 0.89, 1, 0.81, 0.47, 0.6, 0.86, 0.39, 0.44, 0.28, 0.28, 0.38, 0.16, 0.1, 0.12, 0.13, 0.03, 0, 0, 0, 0, 0, 0.02, 0.03, 0.04, 0.45, 0.9, 0.26, 0.04, 0.02, 0.01, 0.05, 0.1, 0.14, 0.13, 0.13, 0.22, 0.13, 0.02, 0.73, 0.98, 0.84, 0.15, 0.55, 0.87, 0.69, 0.15, 0.17, 0.06, 0.72, 1, 0.71, 0.72, 0.67, 0.89, 0.95, 0.79, 0.77, 0.68, 0.64, 0.72, 1, 0.98, 1, 1, 0.9, 0.38, 0.3, 0.05, 0.05, 0.43, 0.72, 0.33, 0.05, 0.36, 0.57, 0.58, 0.37, 0.31, 0.49, 0.34, 0.35, 0.48, 0.76, 0.91, 0.38, 0.69, 0.65, 0.53, 0.74, 0.55, 0.6, 0.49, 0.39, 0.51, 0.47, 0.05, 0.2, 0.23, 0.14, 0.07, 0.05, 0.03, 0.03, 0.02, 0.02, 0.02, 0.02, 0.01, 0.01, 0, 0.01, 0.3, 0.63, 0.77, 0.35, 0.07, 0.69, 0.59, 0.46, 0.71, 0.63, 0.66, 0.57, 0.33, 0.23, 0.92, 0.77, 0.5, 0.35, 0.33, 0.92, 0.95, 0.64, 0.55, 0.59, 0.56, 0.07, 0.07, 0.03, 0],
}

var skin: SkinDriver
var body: Node3D
var knight_at := Vector3.ZERO       # where the knight stands (world): he looks there when he greets and talks
var anvil_top := Vector3.ZERO       # world point on the anvil face where the bar lies
var props := {}                     # name -> {node, rest (global Transform3D), held (side or "")}
var act := "lean"
var _t := 0.0
var _len := 6.0
var _rng := RandomNumberGenerator.new()
var _cur := {}                      # the control points as shown (eased toward the targets)
var _clip_t := 0.0
var _line := ""
var _talk_t := 0.0
var _beat_prev := 0.0
var _swing_hit := false
var _scale := 1.0
var _queue: Array = []

func _ready() -> void:
	_rng.randomize()
	body = Node3D.new()
	add_child(body)
	skin = SkinDriver.attach(body, MODEL)
	if skin == null:
		return
	_scale = HEIGHT / SkinDriver.HEIGHT
	scale = Vector3.ONE * _scale
	Story.line_started.connect(_on_line)
	_cur = _pose_for("lean", 0.0)
	set_act("greet")

func _exit_tree() -> void:
	if Story.line_started.is_connected(_on_line):
		Story.line_started.disconnect(_on_line)

func _on_line(who: String, line_id: String) -> void:
	if who == "orren":
		_line = line_id
		_talk_t = 0.0

## A prop he works with: lies at `rest` (world) until his hand takes it up.
func add_prop(name: String, node: Node3D) -> void:
	props[name] = {"node": node, "rest": node.global_transform, "held": ""}

func set_act(a: String) -> void:
	act = a
	_t = 0.0
	var r: Array = ACT_LEN.get(a, [5.0, 7.0])
	_len = _rng.randf_range(float(r[0]), float(r[1]))
	_swing_hit = false

func _next_act() -> String:
	if _queue.is_empty():
		_queue = ACTS.duplicate()
		_queue.shuffle()
		if _queue[0] == act:
			_queue.push_back(_queue.pop_front())
	return _queue.pop_front()

func talking() -> bool:
	return Story.busy and Story.speaker == "orren"

## How loud his line is now, 0..1.
func voice() -> float:
	if not talking():
		return 0.0
	var p: AudioStreamPlayer = Story.get("_player")
	var env: Array = ENV.get(_line, [])
	if env.is_empty() or p == null or not p.playing:
		# a line with no recording (or a rewritten one, its old take no longer matching): a plain speaking rhythm,
		# phrases of about a second and a half with a breath between, so the head still goes with the words
		var ph := fmod(_talk_t, 1.8)
		return 0.0 if ph > 1.45 else 0.55 + 0.35 * absf(sin(_talk_t * 6.3)) * smoothstep(0.0, 0.15, ph)
	var at := p.get_playback_position()
	var i := int(at / ENV_STEP)
	if i < 0 or i >= env.size() - 1:
		return 0.0
	return lerpf(float(env[i]), float(env[i + 1]), fmod(at, ENV_STEP) / ENV_STEP)

func _process(delta: float) -> void:
	if skin == null:
		return
	_t += delta
	_talk_t += delta
	_clip_t += delta
	if talking():
		if act != "talk":
			set_act("talk")
	elif act == "talk":
		set_act("lean")
		_len = 2.5
	elif _t >= _len:
		set_act(_next_act())
	var want := _pose_for(act, _t)
	_reach_for(want)
	# eased toward the targets: an action's pose arrives over about half a second, the hammer's swing is its own
	var k := 1.0 - exp(-delta * (14.0 if act == "hammer" and _t > 0.8 else 4.0))
	for key: String in want:
		var v = want[key]
		if not _cur.has(key):
			_cur[key] = v
		elif v is Vector3:
			_cur[key] = (_cur[key] as Vector3).lerp(v, k)
		elif v is Basis:
			_cur[key] = Basis((_cur[key] as Basis).get_rotation_quaternion().slerp(v.get_rotation_quaternion(), k))
		elif v is float:
			_cur[key] = lerpf(float(_cur[key]), v, k)
	rotation.y = lerp_angle(rotation.y, float(_cur.yaw), 1.0 - exp(-delta * 3.0))
	skin.clip = "idle"
	skin.clip_t = _clip_t * 0.45
	skin.clip_w = 0.45
	skin.clip_full = false
	var hands: Dictionary = skin.drive({"pelvis": _cur.pelvis, "pelvis_rot": _cur.pelvis_rot, "chest_rot": _cur.chest_rot,
		"head_rot": _cur.head_rot, "hand_r": _cur.hand_r, "hand_l": _cur.hand_l, "ankle_r": Vector3(0.11, 0.08, 0.02),
		"ankle_l": Vector3(-0.11, 0.08, -0.05), "settle": false, "dt": delta})
	_hold_props(hands)

# ---------------------------------------------------------------- poses
## Rig body space (the model's own frame before his scale): y up, the way he faces is -Z, his right is +X.
func _local(world: Vector3) -> Vector3:
	return body.global_transform.affine_inverse() * world

func _look_basis(world: Vector3, extra_pitch: float = 0.0) -> Basis:
	# (`world` is where someone stands: he looks at their face)
	var d := _local(world + Vector3(0, 1.65, 0)) - Vector3(0, 1.75, 0)
	var yaw := clampf(atan2(-d.x, -d.z), -0.9, 0.9)
	var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.6, 0.4) + extra_pitch
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)

func _yaw_to(world: Vector3) -> float:
	var d := world - global_position
	return atan2(-d.x, -d.z)

func _pose_for(a: String, t: float) -> Dictionary:
	var breathe := sin(_clip_t * TAU / 4.2) * 0.006
	var p := {"pelvis": Vector3(0, 1.0, 0), "pelvis_rot": Basis(), "chest_rot": Basis(Vector3.RIGHT, -0.06),
		"head_rot": Basis(), "hand_r": Vector3(0.25, 0.97 + breathe, -0.02), "hand_l": Vector3(-0.25, 0.97 + breathe, -0.02),
		"yaw": _yaw_to(knight_at), "grip_r": 0.25, "grip_l": 0.25}
	var to_knight := _yaw_to(knight_at)
	var anvil := _local(anvil_top) if anvil_top != Vector3.ZERO else Vector3(0, 0.85, -0.7)
	match a:
		"hammer":
			# a slow lift and a quick fall, every 1.4 s; between blows the bar is turned with the tongs
			p.yaw = to_knight
			var cyc := fmod(maxf(t - 0.8, 0.0), 1.4) / 1.4
			var up := smoothstep(0.0, 0.62, cyc) * (1.0 - smoothstep(0.66, 0.76, cyc))
			p.chest_rot = Basis(Vector3.RIGHT, -0.32 + up * 0.12) * Basis(Vector3.UP, 0.12)
			p.pelvis = Vector3(0, 0.97, 0.04)
			p.head_rot = Basis(Vector3.RIGHT, -0.38)
			var strike := anvil + Vector3(0.06, 0.24, 0.12)
			p.hand_r = strike.lerp(Vector3(0.24, 1.62, -0.18), up)
			p.hand_l = anvil + Vector3(-0.2, 0.2, 0.22) + Vector3(0, 0.015 * sin(t * 2.0), 0)
			p.grip_r = 1.0
			p.grip_l = 1.0
			if t > 0.8 and cyc > 0.74 and cyc < 0.8 and not _swing_hit:
				_swing_hit = true
				struck.emit(anvil_top)
			elif cyc < 0.5:
				_swing_hit = false
		"inspect":
			# the blade raised in both hands, turned slowly, sighted down
			p.yaw = to_knight + 0.55
			var turn := sin(t * 0.9) * 0.25
			p.chest_rot = Basis(Vector3.RIGHT, 0.02) * Basis(Vector3.UP, -0.2)
			p.hand_r = Vector3(0.14, 1.28, -0.34)
			p.hand_l = Vector3(-0.06, 1.52 + turn * 0.1, -0.52)
			p.head_rot = Basis(Vector3.UP, -0.25 + turn * 0.3) * Basis(Vector3.RIGHT, 0.12) * Basis(Vector3.FORWARD, 0.18)
			p.grip_r = 1.0
			p.grip_l = 0.45
		"wipe":
			# hands worked together in the rag at the belt, then a look up
			var w := t * 5.0
			p.hand_r = Vector3(0.05 + 0.035 * cos(w), 1.08 + 0.025 * sin(w), -0.3)
			p.hand_l = Vector3(-0.05 - 0.035 * cos(w + 1.2), 1.07 + 0.025 * sin(w + 1.2), -0.31)
			p.head_rot = Basis(Vector3.RIGHT, -0.42 if t < _len - 1.2 else -0.05)
			p.chest_rot = Basis(Vector3.RIGHT, -0.12)
			p.grip_r = 0.55
			p.grip_l = 0.55
		"lean":
			# both hands on the anvil's face, weight forward, watching the knight
			p.yaw = to_knight
			p.pelvis = Vector3(0, 0.97, 0.1)
			p.chest_rot = Basis(Vector3.RIGHT, -0.42)
			p.hand_r = anvil + Vector3(0.18, 0.06, 0.08)
			p.hand_l = anvil + Vector3(-0.2, 0.06, 0.06)
			p.head_rot = _look_basis(knight_at, 0.2) * Basis(Vector3.FORWARD, 0.06 * sin(t * 0.5))
			p.grip_l = 0.2
			p.grip_r = 0.2
		"greet":
			# looks up from the work, a lift of the hand and a nod
			p.yaw = to_knight
			var lift := smoothstep(0.2, 0.6, t) * (1.0 - smoothstep(1.4, 2.0, t))
			p.hand_r = p.hand_r.lerp(Vector3(0.36, 1.5, -0.34), lift)
			p.head_rot = _look_basis(knight_at) * Basis(Vector3.RIGHT, -0.18 * smoothstep(0.7, 0.95, t) * (1.0 - smoothstep(1.0, 1.4, t)))
			p.grip_r = 0.15
		"talk":
			# faces the knight; the head and the right hand go with his own voice
			p.yaw = to_knight
			var v := voice()
			_beat_prev = lerpf(_beat_prev, v, 0.25)
			p.chest_rot = Basis(Vector3.RIGHT, -0.08 - _beat_prev * 0.05)
			p.head_rot = _look_basis(knight_at) * Basis(Vector3.RIGHT, -0.1 * _beat_prev + 0.04 * sin(_talk_t * 2.3)) * Basis(Vector3.FORWARD, 0.07 * sin(_talk_t * 0.9))
			p.hand_r = Vector3(0.3, 1.14 + _beat_prev * 0.22, -0.34 - _beat_prev * 0.12)
			p.hand_l = anvil + Vector3(-0.22, 0.05, 0.2) if anvil.z > -0.9 else p.hand_l
			p.grip_r = 0.1
			# each line has its own business (TALK_HOLDS says what is in the hand for it)
			match _line:
				"orren_intro_01":
					# "So you're the one she woke. Come here. Let's see what you've brought me.": a look that goes down
					# the knight's kit and back up (a craftsman sizing up a job), one short beckon of the free hand
					var down := smoothstep(0.6, 1.4, _talk_t) * (1.0 - smoothstep(2.2, 3.0, _talk_t))
					p.head_rot = _look_basis(knight_at, -0.55 * down) * Basis(Vector3.RIGHT, -0.1 * _beat_prev)
					var beck := smoothstep(2.6, 3.0, _talk_t) * (1.0 - smoothstep(3.7, 4.2, _talk_t))
					p.hand_r = p.hand_r.lerp(Vector3(0.26, 1.2 + 0.05 * sin(_talk_t * 7.0) * beck, -0.46), beck)
					p.grip_r = lerpf(0.1, 0.45, beck)
				"orren_intro_02":
					# "That sword's older than my whole line": a finger toward the knight's sword hand
					var at := _local(knight_at + Vector3(0.3, 1.0, 0.0))
					var reach := (at - Vector3(0.2, 1.4, 0)).normalized()
					p.hand_r = Vector3(0.2, 1.4, 0).lerp(Vector3(0.2, 1.4, 0) + reach * 0.62, smoothstep(0.4, 1.2, _talk_t) * (1.0 - smoothstep(3.6, 4.4, _talk_t)))
					p.grip_r = 0.55
				"orren_intro_03":
					# "Bring me shards and coin ... I just remind it": the hammer taken up, tapped on the anvil with the words
					p.hand_r = anvil + Vector3(0.1, 0.26 + _beat_prev * 0.2, 0.12)
					p.grip_r = 1.0
				"orren_idle_01":
					# "A fine blade's no use if you don't know how to care for it.": said to the work, not the knight:
					# the blade held across him, his eyes on it, the thumb of the free hand drawn slowly along the flat
					p.yaw = to_knight + 0.45
					p.chest_rot = Basis(Vector3.RIGHT, -0.12) * Basis(Vector3.UP, -0.15)
					p.hand_r = Vector3(0.16, 1.22, -0.34)
					var along := 0.5 - 0.5 * cos(_talk_t * 1.1)
					p.hand_l = Vector3(0.02, 1.3, -0.4).lerp(Vector3(-0.1, 1.46, -0.56), along)
					p.head_rot = Basis(Vector3.UP, -0.2) * Basis(Vector3.RIGHT, -0.32 - 0.04 * _beat_prev)
					p.grip_r = 1.0
					p.grip_l = 0.3
	return p

# ---------------------------------------------------------------- what he holds
## Which prop each action has in which hand.
const HOLDS := {"hammer": {"r": "hammer", "l": "tongs"}, "inspect": {"r": "blade"}, "wipe": {"r": "rag"}}
const TALK_HOLDS := {"orren_intro_03": {"r": "hammer"}, "orren_idle_01": {"r": "blade"}}

const PUT := 0.6       # seconds to carry a piece the new action has no use for back to where it lives
const TAKE := 0.6      # seconds to reach a piece where it lies and close the hand on it

func _wanted() -> Dictionary:
	return HOLDS.get(act, {}) if act != "talk" else TALK_HOLDS.get(_line, {})

func _held_by(side: String) -> String:
	for n: String in props:
		if props[n].held == side:
			return n
	return ""

## Nothing comes into his hand or leaves it by itself: at the start of an action a hand first carries back what it no
## longer needs and lays it where it lives, then goes to where the next piece lies and takes it up.
func _reach_for(pose: Dictionary) -> void:
	var need := _wanted()
	for side: String in ["r", "l"]:
		var has := _held_by(side)
		var pname := str(need.get(side, ""))
		var t0 := 0.0
		if has != "" and has != pname:
			if _t < PUT:
				pose["hand_" + side] = _local((props[has].rest as Transform3D).origin) + Vector3(0, 0.03, 0)
				pose["grip_" + side] = 1.0
				continue
			props[has].held = ""
			(props[has].node as Node3D).global_transform = props[has].rest
			t0 = PUT
		if pname != "" and props.has(pname) and props[pname].held == "":
			if _t < t0 + TAKE:
				pose["hand_" + side] = _local((props[pname].rest as Transform3D).origin) + Vector3(0, 0.03, 0)
				pose["grip_" + side] = 0.2 + 0.8 * smoothstep(t0 + TAKE * 0.7, t0 + TAKE, _t)
			else:
				props[pname].held = side

func _hold_props(hands: Dictionary) -> void:
	for side: String in ["r", "l"]:
		var bone := "Right" if side == "r" else "Left"
		skin.curl(bone, float(_cur.get("grip_" + side, 0.25)))
		var pname := _held_by(side)
		if pname == "":
			continue
		var node: Node3D = props[pname].node
		var dir := _held_dir(pname)
		var grip_b: Vector3 = skin.grip(bone, dir)
		var at: Vector3 = body.global_transform * grip_b
		var y := (body.global_transform.basis * dir).normalized()
		var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
		node.global_transform = Transform3D(Basis(x, y, x.cross(y)).orthonormalized().scaled(node.global_transform.basis.get_scale()), at)

## The way a held prop's handle points (rig body space): from the fist toward its working end.
func _held_dir(pname: String) -> Vector3:
	match pname:
		"hammer":
			if act == "talk":
				return Vector3(-0.15, -0.5, -0.85).normalized()
			var cyc := fmod(maxf(_t - 0.8, 0.0), 1.4) / 1.4
			var up := smoothstep(0.0, 0.62, cyc) * (1.0 - smoothstep(0.66, 0.76, cyc))
			return Vector3(-0.15, -0.55, -0.82).lerp(Vector3(-0.1, 0.75, 0.6), up).normalized()
		"tongs":
			return Vector3(0.35, -0.45, -0.82).normalized()
		"blade":
			return Vector3(-0.3, 0.75, -0.55).rotated(Vector3.UP, sin(_t * 0.9) * 0.2).normalized()
		"rag":
			return Vector3(0.6, -0.7, -0.2).normalized()
	return Vector3.UP
