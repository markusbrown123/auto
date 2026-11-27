class_name WitnessDrone
extends Node3D
## The Witness: a small floating instrument that keeps station at the knight's sword-side shoulder.
## Built by tools/witness_gen.py (assets/models/witness/, see docs/CHARACTER_BIBLE.md). Self-contained: give it a
## rig with attach() and it follows, keeps clear of the blade, the shield, the body and the duel camera's view of
## the foe, turns its halo to what it looks at, and pulses its light with its own lines (Story.speaker).
##
##   build(variant := "")        make the model (the chosen variant by default)
##   attach(rig)                 follow this FighterRig (need not be its child)
##   look_at_point(p) / idle()   attention: a world point / nothing in particular
##   speaking(on)                force the speech pulse (otherwise it follows Story)
##   dormant(at) / wake()        dark and lying where it was left / lights in turn, rises, then follows
##   stowed(on)                  docked on the back plate, dark: for a scene that needs it out of frame
##   tuck(on)                    kept close in to the shoulder (cinematic close shots)
## One small unshadowed light at most (`lamp`); everything else is two emissive materials.

signal woke

enum State { DORMANT, WAKING, FOLLOW, STOWED }

const DIR := "res://assets/models/witness/"
const HOME := Vector3(0.66, 1.84, 0.26)          # rig space: sword side, above the shoulder, a little behind
const HOME_TUCK := Vector3(0.5, 1.8, 0.22)
const DOCK := Vector3(0.1, 0.16, 0.26)           # chest space: on the back plate, right of the spine
const LOD_AT := 3.2                              # metres from the camera where the low model takes over
const WAKE_TIME := 2.6
const RISE := 1.25                               # metres it lifts from where it lay (wake() can ask for another height)
const AMBER := Color(1.0, 0.78, 0.48)

static var _manifest := {}

var state: int = State.FOLLOW
var rig: Node3D                                  # the FighterRig it keeps station on (null: it holds where it is)
var foe: Node3D                                  # in a duel: what it watches and must not hide (found by itself)
var lamp: OmniLight3D
var attention := 0.0                             # 0 idle .. 1 attentive: panels parted
var glow := 0.0                                  # what the light shows now (0 dark .. about 2 on a loud syllable)
var size := 1.0                                  # how much over life size this variant is drawn (manifest)
var radius := 0.1                                # metres from its centre to its furthest panel, as drawn

var _info := {}
var _tilt: Node3D             # the whole model: scale, and the pose it lies in when dormant
var _core: Node3D             # the body: spins slowly (aim "halo") or turns its front to the target (aim "body")
var _ring: Node3D             # the parts of group "halo": tip toward the target when the aim is "halo"
var _aim_body := false
var _moving: Array = []       # [node, rest Transform3D, slide, breathe, talk, turn (degrees)] per part that moves
var _mat_seam: StandardMaterial3D
var _mat_dash: StandardMaterial3D
var _vel := Vector3.ZERO
var _placed := false
var _clock := 0.0
var _state_t := 0.0
var _from := Vector3.ZERO
var _look := Vector3.INF
var _look_left := 0.0
var _forced_speech := false
var _was_speaking := false
var _flash := 0.0
var _level := 0.0
var _tucked := false
var _ring_q := Quaternion.IDENTITY
var _body_q := Quaternion.IDENTITY

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(DIR + "witness_manifest.json")) == OK:
			_manifest = j.data
	return _manifest

## The variant the game draws: the manifest's choice, or `--witnessvar=<name>` (dev: "plumb" is the first design).
static func chosen() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--witnessvar="):
			return a.get_slice("=", 1)
	return str(manifest().get("_chosen", "plumb"))

func _init() -> void:
	top_level = true

# ================================================================ construction
static func _v3(a, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	return Vector3(a[0], a[1], a[2]) if a is Array and a.size() == 3 else fallback

func build(variant: String = "") -> void:
	if variant == "" or not manifest().has(variant):
		variant = chosen()
	_info = manifest().get(variant, {})
	size = float(_info.get("size", 1.0))
	var ext := (_v3(_info.get("hi"), Vector3.ONE * 0.1) - _v3(_info.get("lo"), Vector3.ONE * -0.1)) * 0.5
	radius = maxf(ext.x, maxf(ext.y, ext.z)) * size
	_aim_body = str(_info.get("aim", "halo")) == "body"
	_mat_seam = _light_mat()
	_mat_dash = _light_mat()
	_tilt = Node3D.new()
	_tilt.scale = Vector3.ONE * size
	add_child(_tilt)
	_core = Node3D.new()
	_tilt.add_child(_core)
	_ring = Node3D.new()
	_ring.position.y = float(_info.get("ring_y", 0.0))
	_tilt.add_child(_ring)
	var by_mesh := {}
	for p: Dictionary in _info.get("parts", []):
		var parent: Node3D = _ring if str(p.get("group", "")) == "halo" else _core
		if p.has("under") and by_mesh.has(p.under):
			parent = by_mesh[p.under]
		var n := Node3D.new()
		parent.add_child(n)
		var rot := _v3(p.get("rot")) * (PI / 180.0)
		var rest := Transform3D(Basis.from_euler(rot, EULER_ORDER_YXZ).scaled_local(_v3(p.get("scale"), Vector3.ONE)), _v3(p.get("at")))
		n.transform = rest
		_part(variant, str(p.mesh), n, str(p.get("lit", "")) == "dash", rest.basis.determinant() < 0.0)
		by_mesh[p.mesh] = n
		if p.has("slide") or p.has("breathe") or p.has("talk") or p.has("turn"):
			_moving.append([n, rest, _v3(p.get("slide")), _v3(p.get("breathe")), _v3(p.get("talk")), _v3(p.get("turn"))])
	lamp = OmniLight3D.new()
	lamp.light_color = AMBER
	lamp.omni_range = 0.9
	lamp.light_energy = 0.0
	lamp.shadow_enabled = false
	add_child(lamp)
	_apply(0.0)

func _light_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.14, 0.12)
	m.roughness = 0.5
	m.emission_enabled = true
	m.emission = AMBER
	m.emission_energy_multiplier = 0.0
	return m

## One part at both detail levels under `parent`; its "light" surface is given this drone's own material.
## A mirrored twin (negative scale) is drawn two-sided, since mirroring turns its faces inside out.
func _part(variant: String, part: String, parent: Node3D, dash: bool, mirrored: bool) -> void:
	for lod: int in 2:
		var path := "%s%s_%s%s.glb" % [DIR, variant, part, "_lod" if lod == 1 else ""]
		if not ResourceLoader.exists(path):
			continue
		var n: Node3D = (load(path) as PackedScene).instantiate()
		parent.add_child(n)
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if lod == 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if lod == 0:
				mi.visibility_range_end = LOD_AT
			else:
				mi.visibility_range_begin = LOD_AT
			for s: int in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if mat != null and mat.resource_name == "light":
					mi.set_surface_override_material(s, _mat_dash if dash else _mat_seam)
				elif mirrored and mat is BaseMaterial3D:
					var two: BaseMaterial3D = mat.duplicate()
					two.cull_mode = BaseMaterial3D.CULL_DISABLED
					mi.set_surface_override_material(s, two)

# ================================================================ what it is asked to do
func attach(to: Node3D) -> void:
	rig = to
	foe = null

## Turn the halo to a point in the world, for `hold` seconds (0: until idle() or another call).
func look_at_point(p: Vector3, hold: float = 0.0) -> void:
	_look = p
	_look_left = hold if hold > 0.0 else INF

func idle() -> void:
	_look = Vector3.INF
	_look_left = 0.0

func speaking(on: bool) -> void:
	_forced_speech = on

func tuck(on: bool) -> void:
	_tucked = on

## Dark and lying on its side at `at` (a point on the ground), as it is before it is found.
func dormant(at: Vector3, yaw: float = 0.0) -> void:
	state = State.DORMANT
	rig = null
	global_position = at + Vector3(0, float(_info.get("lie", 0.03)) * size, 0)
	_placed = true
	_vel = Vector3.ZERO
	_tilt.basis = (Basis(Vector3.UP, yaw) * Basis.from_euler(_v3(_info.get("lie_rot"), Vector3(0, 0, 84)) * (PI / 180.0))).scaled(Vector3.ONE * size)
	_ring_q = Quaternion(Vector3.RIGHT, deg_to_rad(64.0))
	_body_q = Quaternion.IDENTITY
	attention = 0.0
	glow = 0.0
	_apply(0.0)

## The seam lights, then the dash on the halo, the vanes lift, and it rises and rights itself. `woke` when done.
func wake(rise: float = RISE) -> void:
	if state != State.DORMANT and state != State.STOWED:
		return
	_rise = rise
	_from = global_position
	state = State.WAKING
	_state_t = 0.0

func stowed(on: bool = true) -> void:
	if on:
		state = State.STOWED
	elif state == State.STOWED:
		state = State.FOLLOW

func is_speaking() -> bool:
	if _forced_speech:
		return true
	var story := get_node_or_null("/root/Story")
	return story != null and story.get("speaker") == "witness"

# ================================================================ per frame
func _calm() -> bool:
	var game := get_node_or_null("/root/Game")
	return game != null and bool(game.settings.get("reduce_motion", false))

func _process(delta: float) -> void:
	if _tilt == null:
		return
	var dt := minf(delta, 0.05)
	_clock += dt
	_state_t += dt
	if rig != null and not is_instance_valid(rig):
		rig = null
	if foe != null and not is_instance_valid(foe):
		foe = null
	if rig != null and foe == null and rig.get_parent() != null:
		var f = rig.get_parent().get("foe_rig")
		if f is Node3D and f != rig:
			foe = f
	_look_left -= dt
	if _look_left <= 0.0:
		_look = Vector3.INF
	var calm := _calm()
	var talk := is_speaking()
	if talk and not _was_speaking:
		_flash = 1.0                 # the start of a line: one bright breath, no sound
	_was_speaking = talk
	_flash = maxf(0.0, _flash - dt * 2.4)
	_level = lerpf(_level, _voice() if talk else 0.0, 1.0 - exp(-dt * 18.0))
	var seam_on := 1.0
	var dash_on := 1.0
	match state:
		State.DORMANT:
			_apply(dt)
			return
		State.WAKING:
			var t := _state_t
			# the seam catches twice before it holds; the dash follows; then it lifts and rights itself
			seam_on = clampf(t / 0.5, 0.0, 1.0) * (0.25 if (t > 0.18 and t < 0.3) else 1.0)
			dash_on = clampf((t - 0.7) / 0.25, 0.0, 1.0)
			attention = clampf((t - 0.95) / 0.4, 0.0, 1.0)
			var u := smoothstep(1.05, WAKE_TIME, t)
			global_position = _from + Vector3(0, _rise * u, 0)
			_tilt.basis = _tilt.basis.orthonormalized().slerp(Basis.IDENTITY, clampf(dt * 3.0 * smoothstep(1.0, 1.6, t), 0.0, 1.0)).scaled(Vector3.ONE * size)
			if t >= WAKE_TIME:
				state = State.FOLLOW
				_state_t = 0.0
				_vel = Vector3.ZERO
				_tilt.basis = Basis.IDENTITY.scaled(Vector3.ONE * size)
				woke.emit()
		State.STOWED:
			if rig != null:
				var chest: Node3D = rig.get("chest")
				var to: Vector3 = chest.global_transform * DOCK if chest != null else rig.global_transform * Vector3(0.1, 1.5, 0.22)
				global_position = to if not _placed else global_position.lerp(to, 1.0 - exp(-dt * 14.0))
				_placed = true
			attention = move_toward(attention, 0.0, dt * 3.0)
			seam_on = 0.12
			dash_on = 0.0
		State.FOLLOW:
			_tilt.basis = _tilt.basis.orthonormalized().slerp(Basis.IDENTITY, clampf(dt * 6.0, 0.0, 1.0)).scaled(Vector3.ONE * size)
			_follow(dt, calm)
	# attention, and what does the looking: the halo, or the whole body
	var target := _target()
	if state == State.FOLLOW:
		attention = move_toward(attention, 1.0 if (target != Vector3.INF or talk) else 0.0, dt * 2.5)
	if _aim_body:
		var bq := _body_q
		if state == State.STOWED:
			bq = Quaternion(Vector3.UP, rig.global_rotation.y) if rig != null else _body_q
		elif target != Vector3.INF:
			var d := target - global_position
			var pitch := clampf(atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.01)), deg_to_rad(-30.0), deg_to_rad(30.0))
			bq = Quaternion(Vector3.UP, atan2(-d.x, -d.z)) * Quaternion(Vector3.RIGHT, pitch)
		elif rig != null:
			# nothing to look at: it faces the way the knight faces, and looks about a little
			var sway := 0.0 if calm else sin(_clock * 0.47) * 0.42 + sin(_clock * 1.13) * 0.08
			bq = Quaternion(Vector3.UP, rig.global_rotation.y + sway) * Quaternion(Vector3.RIGHT, 0.0 if calm else sin(_clock * 0.31) * 0.1)
		_body_q = _body_q.slerp(bq, 1.0 - exp(-dt * (6.0 if target != Vector3.INF else 2.2)))
		# it banks a little into the way it is travelling
		var bank := 0.0 if calm else clampf(-_vel.dot(Basis(_body_q).x) * 0.12, -0.3, 0.3)
		_core.quaternion = _body_q * Quaternion(Vector3.FORWARD, bank)
	else:
		var want := Quaternion.IDENTITY
		if state == State.STOWED:
			want = Quaternion.IDENTITY
		elif target != Vector3.INF:
			var d2 := target - _ring.global_position
			var lean := clampf(deg_to_rad(26.0) + atan2(d2.y, maxf(Vector2(d2.x, d2.z).length(), 0.01)) * 0.6, deg_to_rad(-8.0), deg_to_rad(58.0))
			want = Quaternion(Vector3.UP, atan2(-d2.x, -d2.z)) * Quaternion(Vector3.RIGHT, -lean)
		elif not calm:
			# nothing to look at: the halo wanders, slowly, like a level settling
			want = Quaternion(Vector3.UP, _clock * 0.45) * Quaternion(Vector3.RIGHT, deg_to_rad(9.0))
		else:
			want = Quaternion(Vector3.RIGHT, deg_to_rad(6.0))
		_ring_q = _ring_q.slerp(want, 1.0 - exp(-dt * (7.0 if target != Vector3.INF else 2.5)))
		if not calm and state == State.FOLLOW:
			_core.rotation.y = wrapf(_core.rotation.y + dt * (0.35 + 0.5 * attention), 0.0, TAU)
	_wave = 0.0 if (calm or state != State.FOLLOW) else 0.5 + 0.5 * sin(_clock * 1.5)
	var base := 0.0
	if state != State.STOWED:
		base = 0.5 + 0.3 * attention
		if talk:
			base = 0.55 + 1.25 * _level
		if rig != null and rig.get("mode") == FighterRig.Mode.DEAD:
			base = 0.12
	else:
		base = 1.0
	glow = base * seam_on + 1.3 * _flash
	_dash = base * dash_on + 1.3 * _flash
	_apply(dt)

var _dash := 0.0
var _wave := 0.0
var _rise := RISE

func _apply(_dt: float) -> void:
	if state == State.DORMANT:
		_dash = 0.0
	_mat_seam.emission_energy_multiplier = glow * 2.2
	_mat_dash.emission_energy_multiplier = _dash * 2.2
	_mat_seam.albedo_color = Color(0.16, 0.14, 0.12).lerp(Color(1.0, 0.9, 0.74), clampf(glow, 0.0, 1.0))
	_mat_dash.albedo_color = Color(0.16, 0.14, 0.12).lerp(Color(1.0, 0.9, 0.74), clampf(_dash, 0.0, 1.0))
	lamp.light_energy = 0.3 * glow
	lamp.visible = glow > 0.05
	# the panels: parted by attention, breathing when idle, nudged by the voice
	for m: Array in _moving:
		var rest: Transform3D = m[1]
		var off: Vector3 = (m[2] as Vector3) * attention + (m[3] as Vector3) * _wave + (m[4] as Vector3) * _level
		var turn: Vector3 = (m[5] as Vector3) * (attention * PI / 180.0)
		(m[0] as Node3D).transform = Transform3D(rest.basis * Basis.from_euler(turn, EULER_ORDER_YXZ), rest.origin + rest.basis * off)
	if not _aim_body:
		_ring.quaternion = _ring_q

## How loud the line is now, 0..1: the dialogue bus's own level, or a spoken rhythm where nothing is audible.
func _voice() -> float:
	var idx := AudioServer.get_bus_index("Dialogue")
	var lin := 0.0
	if idx >= 0:
		lin = db_to_linear(maxf(AudioServer.get_bus_peak_volume_left_db(idx, 0), -80.0))
	if lin < 0.004:
		return 0.25 + 0.75 * absf(sin(_clock * 8.3)) * (0.55 + 0.45 * sin(_clock * 2.9))
	return clampf(lin * 2.4, 0.0, 1.0)

## What the halo is turned to: a point it was given; the knight while either of them speaks; the foe in a duel.
func _target() -> Vector3:
	if _look != Vector3.INF:
		return _look
	var story := get_node_or_null("/root/Story")
	var who := str(story.get("speaker")) if story != null and story.get("speaker") != null else ""
	if rig != null and (_forced_speech or who == "witness" or who == "player") and foe == null:
		return rig.global_transform * Vector3(0, 1.74, 0)
	if foe != null:
		return foe.global_position + Vector3(0, 1.45 * foe.scale.y, 0)
	return Vector3.INF

# ---------------------------------------------------------------- keeping station
func _follow(dt: float, calm: bool) -> void:
	if rig == null:
		# found but not yet at a shoulder: it holds where it rose
		if not calm:
			global_position.y += sin(_clock * 1.7) * 0.012 * dt
		return
	var local := HOME_TUCK if _tucked else HOME
	var stiff := 34.0
	var mode: int = int(rig.get("mode"))
	var root: Vector3 = rig.get("_root")
	local += Vector3(root.x, 0.0, root.z)
	match mode:
		FighterRig.Mode.WINDUP, FighterRig.Mode.STRIKE, FighterRig.Mode.FOLLOW, FighterRig.Mode.THRUST_WINDUP, FighterRig.Mode.THRUST:
			local += Vector3(0.04, 0.1, 0.42)      # a cut is coming or passing: back and a little up, out of its plane
			stiff = 70.0
		FighterRig.Mode.DODGE:
			local += Vector3(0.0, 0.12, 0.24)      # over the roll, not through it
		FighterRig.Mode.STAGGER, FighterRig.Mode.HURT:
			local += Vector3(0.06, 0.08, 0.26)
		FighterRig.Mode.DEAD:
			local = Vector3(0.42, 0.62, 0.3)       # it comes down to the one who fell
			stiff = 6.0
		_:
			if bool(rig.get("blocking")):
				local += Vector3(0.06, 0.1, 0.2)
	if not calm and mode != FighterRig.Mode.DEAD:
		local += Vector3(sin(_clock * 0.83 + 1.3) * 0.012, sin(_clock * 1.7) * 0.022 + sin(_clock * 0.9 + 1.0) * 0.008, cos(_clock * 0.61) * 0.01)
	var k: float = rig.scale.y
	var to: Vector3 = rig.global_transform * local
	to = _clear_body(to, k)
	to = _clear_view(to)
	if not _placed or global_position.distance_to(to) > 3.0 * k:
		global_position = to
		_vel = Vector3.ZERO
		_placed = true
		return
	# a critically damped spring: it arrives a little late and never overshoots
	_vel += ((to - global_position) * stiff - _vel * 2.0 * sqrt(stiff)) * dt
	global_position += _vel * dt
	global_position = _clear_body(global_position, k)

## Never in the blade, the shield or the knight: pushed out of each to a clear distance.
func _clear_body(p: Vector3, k: float) -> Vector3:
	var w: Node3D = rig.get("weapon_r")
	if w != null and w.is_inside_tree() and w.is_visible_in_tree():
		var a: Vector3 = w.global_position
		var b: Vector3 = w.global_transform * Vector3(0, float(rig.get("weapon_len")), 0)
		var near := Geometry3D.get_closest_point_to_segment(p, a, b)
		p = _push(p, near, (0.2 + radius) * k)
	var sh: Node3D = rig.get("shield")
	if sh != null and sh.is_inside_tree() and sh.is_visible_in_tree():
		p = _push(p, sh.global_position, (0.36 + radius) * k)
	var body: Node3D = rig.get("body")
	if body != null:
		var axis := body.global_position
		var top := axis + Vector3(0, 1.8 * k, 0)
		p = _push(p, Geometry3D.get_closest_point_to_segment(p, axis + Vector3(0, 0.3 * k, 0), top), (0.32 + radius) * k)
	return p

func _push(p: Vector3, from: Vector3, clear: float) -> Vector3:
	var off := p - from
	var d := off.length()
	if d >= clear:
		return p
	var dir := (off / d) if d > 0.001 else Vector3.UP
	dir = (dir + Vector3.UP * 0.5).normalized()      # when it must give way it goes up, not down into the arc
	return from + dir * clear

## Kept in the picture's clear part. Always: under the bars and tabs along the top of the screen. In a duel also:
## never nearer the lens than DUEL_NEAR (where it would loom), inside the frame, clear of the pads by its own
## width on screen, and not between the camera and the foe.
const DUEL_NEAR := 1.7
func _clear_view(p: Vector3) -> Vector3:
	if not is_inside_tree():
		return p
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return p
	var c := cam.global_position
	var view := get_viewport().get_visible_rect().size
	if foe == null:
		if cam.is_position_behind(p):
			return p
		var s0 := cam.unproject_position(p)
		var depth0 := (p - c).dot(-cam.global_transform.basis.z)
		var px0 := 2.0 * depth0 * tan(deg_to_rad(cam.fov) * 0.5) / maxf(view.y, 1.0)
		var top0 := minf(44.0 + radius / maxf(px0, 0.0001) + 12.0, view.y * 0.16)
		if s0.x > 0.0 and s0.x < view.x and s0.y < top0 and s0.y > -200.0:
			p -= cam.global_transform.basis.y * (top0 - s0.y) * px0
		return p
	var home := p
	var away := p - c
	if away.length() < DUEL_NEAR:
		p = c + away.normalized() * DUEL_NEAR if away.length() > 0.01 else p
	if not cam.is_position_behind(p):
		var depth := maxf((p - c).dot(-cam.global_transform.basis.z), 0.3)
		var per_px := 2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5) / maxf(view.y, 1.0)
		var m := radius / per_px + 16.0                 # its own half-width on screen, and a little air
		var s := cam.unproject_position(p)
		var to := s
		to.y = clampf(to.y, 64.0 + m, view.y - 112.0 - m)                  # the bars above, the row of pads below
		to.x = clampf(to.x, m, view.x - m)
		if to.x < 168.0 + m and to.y < 130.0 + m:                           # the two charge pads, top left
			if 168.0 + m - to.x < 130.0 + m - to.y:
				to.x = 168.0 + m
			else:
				to.y = 130.0 + m
		if to.x > view.x - 64.0 - m and to.y < 64.0 + 24.0 + m:           # the pause button, top right
			to.x = view.x - 64.0 - m
		var shift := (cam.global_transform.basis.x * (to.x - s.x) - cam.global_transform.basis.y * (to.y - s.y)) * per_px
		p += shift.limit_length(1.6)
	var fs: float = foe.scale.y
	for h: float in [0.5, 1.1, 1.7]:
		var f: Vector3 = foe.global_position + Vector3(0, h * fs, 0)
		var d := f - c
		var len := d.length()
		if len < 0.2:
			continue
		d /= len
		var t := (p - c).dot(d)
		if t < 0.05 or t > len:
			continue
		var near := c + d * t
		var need := 0.5 * fs * t / len + radius + 0.04
		var off := p - near
		if off.length() < need:
			# out of the line, toward where it came from (the knight's side), never across to the far side
			var dir := (home - near).normalized() if (home - near).length() > 0.01 else Vector3.UP
			p = near + (dir + Vector3.UP * 0.4).normalized() * need
	return p
