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
const SIZE := 1.5                                # drawn half again over life size (about 20 cm): it has to read on a phone at duel distance
const HOME := Vector3(0.62, 1.8, 0.24)           # rig space: sword side, above the shoulder, a little behind
const HOME_TUCK := Vector3(0.44, 1.78, 0.2)
const DOCK := Vector3(0.1, 0.16, 0.2)            # chest space: on the back plate, right of the spine
const LOD_AT := 3.2                              # metres from the camera where the low model takes over
const WAKE_TIME := 2.6
const RISE := 1.25                               # metres it lifts from where it lay (wake() can ask for another height)
const AMBER := Color(1.0, 0.78, 0.48)

static var _manifest := {}

var state: int = State.FOLLOW
var rig: Node3D                                  # the FighterRig it keeps station on (null: it holds where it is)
var foe: Node3D                                  # in a duel: what it watches and must not hide (found by itself)
var lamp: OmniLight3D
var attention := 0.0                             # 0 idle .. 1 attentive: seam parted, vanes lifted
var glow := 0.0                                  # what the light shows now (0 dark .. about 2 on a loud syllable)

var _info := {}
var _tilt: Node3D
var _core: Node3D
var _lower: Node3D
var _ring: Node3D
var _fins: Array = []
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

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(DIR + "witness_manifest.json")) == OK:
			_manifest = j.data
	return _manifest

func _init() -> void:
	top_level = true

# ================================================================ construction
func build(variant: String = "") -> void:
	if variant == "":
		variant = str(manifest().get("_chosen", "plumb"))
	_info = manifest().get(variant, {})
	_mat_seam = _light_mat()
	_mat_dash = _light_mat()
	_tilt = Node3D.new()
	_tilt.scale = Vector3.ONE * SIZE
	add_child(_tilt)
	_core = Node3D.new()
	_tilt.add_child(_core)
	_part(variant, "shell_a", _core)
	_part(variant, "light", _core)
	_lower = Node3D.new()
	_core.add_child(_lower)
	_part(variant, "shell_b", _lower)
	for m: Dictionary in _info.get("fins", []):
		var hinge := Node3D.new()
		hinge.position = Vector3(m.at[0], m.at[1], m.at[2])
		hinge.rotation_degrees = Vector3(0, float(m.yaw), 0)
		_lower.add_child(hinge)
		var vane := Node3D.new()
		hinge.add_child(vane)
		_part(variant, "fin", vane)
		_fins.append([vane, float(m.lean)])
	_ring = Node3D.new()
	_ring.position.y = float(_info.get("ring_y", 0.0))
	_tilt.add_child(_ring)
	_part(variant, "ring", _ring)
	lamp = OmniLight3D.new()
	lamp.light_color = AMBER
	lamp.omni_range = 0.7
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
func _part(variant: String, part: String, parent: Node3D) -> void:
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
					mi.set_surface_override_material(s, _mat_dash if part == "ring" else _mat_seam)

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
	global_position = at + Vector3(0, 0.027 * SIZE, 0)
	_placed = true
	_vel = Vector3.ZERO
	_tilt.basis = (Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, deg_to_rad(84.0))).scaled(Vector3.ONE * SIZE)
	_ring_q = Quaternion(Vector3.RIGHT, deg_to_rad(64.0))
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
			_tilt.basis = _tilt.basis.orthonormalized().slerp(Basis.IDENTITY, clampf(dt * 3.0 * smoothstep(1.0, 1.6, t), 0.0, 1.0)).scaled(Vector3.ONE * SIZE)
			if t >= WAKE_TIME:
				state = State.FOLLOW
				_state_t = 0.0
				_vel = Vector3.ZERO
				_tilt.basis = Basis.IDENTITY.scaled(Vector3.ONE * SIZE)
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
			_tilt.basis = _tilt.basis.orthonormalized().slerp(Basis.IDENTITY, clampf(dt * 6.0, 0.0, 1.0)).scaled(Vector3.ONE * SIZE)
			_follow(dt, calm)
	# attention and the halo
	var target := _target()
	if state == State.FOLLOW:
		attention = move_toward(attention, 1.0 if (target != Vector3.INF or talk) else 0.0, dt * 2.5)
	var want := Quaternion.IDENTITY
	if state == State.STOWED:
		want = Quaternion.IDENTITY
	elif target != Vector3.INF:
		var d := target - _ring.global_position
		var flat := Vector2(d.x, d.z).length()
		var yaw := atan2(-d.x, -d.z)
		var lean := clampf(deg_to_rad(26.0) + atan2(d.y, maxf(flat, 0.01)) * 0.6, deg_to_rad(-8.0), deg_to_rad(58.0))
		want = Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, -lean)
	elif not calm:
		# nothing to look at: the halo wanders, slowly, like a level settling
		want = Quaternion(Vector3.UP, _clock * 0.45) * Quaternion(Vector3.RIGHT, deg_to_rad(9.0))
	else:
		want = Quaternion(Vector3.RIGHT, deg_to_rad(6.0))
	_ring_q = _ring_q.slerp(want, 1.0 - exp(-dt * (7.0 if target != Vector3.INF else 2.5)))
	if not calm and state == State.FOLLOW:
		_core.rotation.y = wrapf(_core.rotation.y + dt * (0.35 + 0.5 * attention), 0.0, TAU)
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
var _rise := RISE

func _apply(_dt: float) -> void:
	if state == State.DORMANT:
		_dash = 0.0
	_mat_seam.emission_energy_multiplier = glow * 2.2
	_mat_dash.emission_energy_multiplier = _dash * 2.2
	_mat_seam.albedo_color = Color(0.16, 0.14, 0.12).lerp(Color(1.0, 0.9, 0.74), clampf(glow, 0.0, 1.0))
	_mat_dash.albedo_color = Color(0.16, 0.14, 0.12).lerp(Color(1.0, 0.9, 0.74), clampf(_dash, 0.0, 1.0))
	lamp.light_energy = 0.22 * glow
	lamp.visible = glow > 0.05
	var ax: Array = _info.get("open_axis", [0, -1, 0])
	var open: float = float(_info.get("open_dist", 0.0)) * (attention + 0.35 * _level)
	_lower.position = Vector3(ax[0], ax[1], ax[2]) * open
	for f: Array in _fins:
		# laid along the taper at rest (lower end in), lifted outward when it attends
		(f[0] as Node3D).rotation_degrees.x = -float(f[1]) + float(_info.get("fin_open", 0.0)) * attention
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
		p = _push(p, near, 0.3 * k)
	var sh: Node3D = rig.get("shield")
	if sh != null and sh.is_inside_tree() and sh.is_visible_in_tree():
		p = _push(p, sh.global_position, 0.46 * k)
	var body: Node3D = rig.get("body")
	if body != null:
		var axis := body.global_position
		var top := axis + Vector3(0, 1.8 * k, 0)
		p = _push(p, Geometry3D.get_closest_point_to_segment(p, axis + Vector3(0, 0.3 * k, 0), top), 0.42 * k)
	return p

func _push(p: Vector3, from: Vector3, clear: float) -> Vector3:
	var off := p - from
	var d := off.length()
	if d >= clear:
		return p
	var dir := (off / d) if d > 0.001 else Vector3.UP
	dir = (dir + Vector3.UP * 0.5).normalized()      # when it must give way it goes up, not down into the arc
	return from + dir * clear

## In a duel: not between the camera and the foe, and not behind the pads at the corners of the screen.
func _clear_view(p: Vector3) -> Vector3:
	if foe == null or not is_inside_tree():
		return p
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return p
	var c := cam.global_position
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
		var need := 0.5 * fs * t / len + 0.12
		var off := p - near
		if off.length() < need:
			var dir := off.normalized() if off.length() > 0.005 else Vector3.UP
			p = near + (dir + Vector3.UP * 0.4).normalized() * need
	if cam.is_position_behind(p):
		return p
	var size := get_viewport().get_visible_rect().size
	var s := cam.unproject_position(p)
	var depth := (p - c).dot(-cam.global_transform.basis.z)
	var per_px := 2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5) / maxf(size.y, 1.0)
	var m := 34.0
	if s.x < 168.0 + m and s.y > 52.0 - m and s.y < 130.0 + m:       # the two charge pads, top left
		p += cam.global_transform.basis.x * (168.0 + m - s.x) * per_px
	if s.y < 64.0 + m + 12.0:                                          # the bars along the top
		p -= cam.global_transform.basis.y * (64.0 + m + 12.0 - s.y) * per_px
	if s.y > size.y - 112.0 - m:                                       # the row of pads along the bottom
		p += cam.global_transform.basis.y * (s.y - (size.y - 112.0 - m)) * per_px
	return p
