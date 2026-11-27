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
const HALO := Color(1.0, 0.72, 0.34)

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
var _moving: Array = []       # [node, rest Transform3D, slide, breathe, talk, turn (degrees), talk_turn, look, look q] per part that moves
var _pitch_max := deg_to_rad(30.0)   # how far the body itself tips to look up or down (manifest "tilt": an upright body stays upright)
var _bank_max := 0.3
var _flare_all := false
var _flare_d := 0.2
const HALO_MIN_PX := 0.062       # a ball's halo is never drawn narrower than this share of the picture's height
var _presence_max := DUEL_PRESENCE
var _trail_cfg := [1.7, 3.6, 0.42, 0.30]      # speed where the wisp begins, where it is full, width in radii, opacity (manifest "trail")
var _glow_k := 1.0            # how bright this variant's light is drawn (manifest "glow")
var _flare: MeshInstance3D    # a soft bloom on the lamp, seen only from where the lamp points
var _flare_mat: StandardMaterial3D
var _looker: Node3D           # the part that turns by itself to what it looks at (manifest "look"), if any
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_pts: Array = []
var _trail_on := 0.0
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
		if p.has("slide") or p.has("breathe") or p.has("talk") or p.has("turn") or p.has("talk_turn") or p.has("look"):
			var lk = p.get("look")
			var look := Vector2(deg_to_rad(float(lk[0])), deg_to_rad(float(lk[1]))) if lk is Array and lk.size() == 2 else Vector2.ZERO
			_moving.append([n, rest, _v3(p.get("slide")), _v3(p.get("breathe")), _v3(p.get("talk")), _v3(p.get("turn")), _v3(p.get("talk_turn")), look, Quaternion.IDENTITY])
			if look != Vector2.ZERO:
				_looker = n
	_glow_k = float(_info.get("glow", 1.0))
	_flare_all = bool(_info.get("flare_all", false))
	_presence_max = float(_info.get("presence", DUEL_PRESENCE))
	var tc = _info.get("trail")
	if tc is Array and tc.size() == 4:
		_trail_cfg = tc
	var tl = _info.get("tilt")
	if tl is Array and tl.size() == 2:
		_pitch_max = deg_to_rad(float(tl[0]))
		_bank_max = deg_to_rad(float(tl[1]))
	lamp = OmniLight3D.new()
	lamp.light_color = AMBER
	lamp.omni_range = float(_info.get("lamp_range", 0.9))
	lamp.light_energy = 0.0
	lamp.shadow_enabled = false
	add_child(lamp)
	if _info.has("flare"):
		_build_flare(float(_info.flare))
	_build_trail()
	_apply(0.0)

## The lamp's bloom: a soft disc in front of the pane that always faces the camera and fades as the lamp turns away,
## so that at the far edge of a fight one can still tell where the Witness is looking.
func _build_flare(d: float) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.42))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_flare_mat = StandardMaterial3D.new()
	_flare_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flare_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# (a ball's halo is mixed, not added: added light vanishes against a bright sky, and the halo is what finds it)
	_flare_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if _flare_all else BaseMaterial3D.BLEND_MODE_ADD
	_flare_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_flare_mat.billboard_keep_scale = true
	_flare_mat.albedo_texture = tex
	_flare_mat.albedo_color = Color(AMBER, 0.0)
	_flare_d = d
	var q := QuadMesh.new()
	q.size = Vector2(d, d)
	_flare = MeshInstance3D.new()
	_flare.mesh = q
	_flare.material_override = _flare_mat
	_flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flare.position = Vector3.ZERO if _flare_all else Vector3(0, 0, -0.045)
	(_looker if _looker != null else _core).add_child(_flare)

## A faint ribbon behind it when it darts (never with reduced motion): its last few positions, fading.
func _build_trail() -> void:
	_trail_mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	_trail.material_override = m
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.top_level = true
	add_child(_trail)

const TRAIL_N := 16

func _draw_trail(dt: float, calm: bool) -> void:
	var speed := _vel.length()
	var want := 0.0 if (calm or state != State.FOLLOW) else smoothstep(float(_trail_cfg[0]), float(_trail_cfg[1]), speed)
	_trail_on = lerpf(_trail_on, want, 1.0 - exp(-dt * (10.0 if want > _trail_on else 2.5)))
	if _trail_pts.is_empty() or (_trail_pts[0] as Vector3).distance_to(global_position) > 0.05:
		_trail_pts.push_front(global_position)
		if _trail_pts.size() > TRAIL_N:
			_trail_pts.resize(TRAIL_N)
	_trail_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if _trail_on < 0.02 or _trail_pts.size() < 3 or cam == null:
		return
	_trail.global_transform = Transform3D.IDENTITY
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _trail_pts.size()
	for i: int in n:
		var p: Vector3 = _trail_pts[i]
		var along: Vector3 = ((_trail_pts[maxi(i - 1, 0)] as Vector3) - (_trail_pts[mini(i + 1, n - 1)] as Vector3))
		var side := along.cross(cam.global_position - p).normalized()
		var u := float(i) / float(n - 1)
		var w := radius * float(_trail_cfg[2]) * (1.0 - u) * (0.35 + 0.65 * minf(1.0, u * 5.0))
		var c := Color(AMBER, float(_trail_cfg[3]) * _trail_on * (1.0 - u) * (1.0 - u))
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_add_vertex(p + side * w)
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_add_vertex(p - side * w)
	_trail_mesh.surface_end()

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
	_sim = null
	_foe_down = false
	# a cinematic's actor keeps it tucked at the shoulder unless the scene frees it: roam(true), tuck(false)
	if to != null and to.get_script() != null and str((to.get_script() as Script).get_global_name()) == "CineActor":
		roaming = false
		_tucked = true

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
			var pitch := clampf(atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.01)), -_pitch_max, _pitch_max)
			bq = Quaternion(Vector3.UP, atan2(-d.x, -d.z)) * Quaternion(Vector3.RIGHT, pitch)
		elif Vector2(_vel.x, _vel.z).length() > 0.7:
			bq = Quaternion(Vector3.UP, atan2(-_vel.x, -_vel.z))      # under way: nose first
		elif rig != null:
			# nothing to look at: it faces the way the knight faces, and looks about a little
			var sway := 0.0 if calm else sin(_clock * 0.47) * 0.42 + sin(_clock * 1.13) * 0.08
			bq = Quaternion(Vector3.UP, rig.global_rotation.y + sway) * Quaternion(Vector3.RIGHT, 0.0 if calm else sin(_clock * 0.31) * 0.1)
		_body_q = _body_q.slerp(bq, 1.0 - exp(-dt * (6.0 if target != Vector3.INF else 2.2)))
		# it banks a little into the way it is travelling
		var bank := 0.0 if calm else clampf(-_vel.dot(Basis(_body_q).x) * 0.12, -_bank_max, _bank_max)
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
	# at the far edge of a fight it is drawn a third larger, so that it still reads at that distance
	_presence = lerpf(_presence, _presence_max if (foe != null and rig != null and _free_now()) else 1.0, 1.0 - exp(-dt * 2.0))
	_core.scale = Vector3.ONE * _presence
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
	_aim_lookers(dt, target, calm)
	_apply(dt)
	_draw_trail(dt, calm)

## The lamp leads: it turns to the target before the body has come round, and looks about by itself when idle.
func _aim_lookers(dt: float, target: Vector3, calm: bool) -> void:
	for m: Array in _moving:
		var lim: Vector2 = m[7]
		if lim == Vector2.ZERO:
			continue
		var want := Quaternion.IDENTITY
		if state == State.FOLLOW or state == State.WAKING:
			if target != Vector3.INF:
				var d: Vector3 = _core.global_transform.basis.orthonormalized().inverse() * (target - (m[0] as Node3D).global_position)
				var yaw := clampf(atan2(-d.x, -d.z), -lim.x, lim.x)
				var pitch := clampf(atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.01)), -lim.y, lim.y)
				want = Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, pitch)
			elif not calm and state == State.FOLLOW:
				want = Quaternion(Vector3.UP, sin(_clock * 0.53 + 0.8) * 0.5 * lim.x) * Quaternion(Vector3.RIGHT, sin(_clock * 0.37) * 0.3 * lim.y)
		m[8] = (m[8] as Quaternion).slerp(want, 1.0 - exp(-dt * (11.0 if target != Vector3.INF else 2.0)))

var _dash := 0.0
var _presence := 1.0
const DUEL_PRESENCE := 1.32
var _wave := 0.0
var _rise := RISE

func _apply(_dt: float) -> void:
	if state == State.DORMANT:
		_dash = 0.0
	_mat_seam.emission_energy_multiplier = glow * 2.2 * _glow_k
	_mat_dash.emission_energy_multiplier = _dash * 2.2 * _glow_k
	_mat_seam.albedo_color = Color(0.16, 0.14, 0.12).lerp(Color(1.0, 0.9, 0.74), clampf(glow, 0.0, 1.0))
	_mat_dash.albedo_color = Color(0.16, 0.14, 0.12).lerp(Color(1.0, 0.9, 0.74), clampf(_dash, 0.0, 1.0))
	lamp.light_energy = 0.3 * glow * _glow_k
	lamp.visible = glow > 0.05
	if _looker != null:
		lamp.position = to_local(_looker.global_transform * Vector3(0, 0, -0.07)) if is_inside_tree() else Vector3.ZERO
	if _flare != null:
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		var facing := 0.0
		if _flare_all:
			facing = 1.0
			if cam != null and cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
				# far away the halo keeps its width on screen (the ball does not grow: the light does)
				var depth := maxf((global_position - cam.global_position).dot(-cam.global_transform.basis.z), 0.3)
				var want := HALO_MIN_PX * 2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5)
				_flare.scale = Vector3.ONE * maxf(1.0, want / maxf(_flare_d * _flare.get_parent_node_3d().global_transform.basis.get_scale().x, 0.001))
		elif cam != null:
			var fwd := -_flare.get_parent_node_3d().global_transform.basis.z.normalized()
			facing = clampf(fwd.dot((cam.global_position - _flare.global_position).normalized()), 0.0, 1.0)
		_flare_mat.albedo_color = Color(HALO if _flare_all else AMBER, clampf(0.55 * glow * facing * facing, 0.0, 0.9))
		_flare.visible = glow > 0.05 and facing > 0.02
	# the panels: parted by attention, breathing when idle, nudged by the voice
	for m: Array in _moving:
		var rest: Transform3D = m[1]
		var off: Vector3 = (m[2] as Vector3) * attention + (m[3] as Vector3) * _wave + (m[4] as Vector3) * _level
		var turn: Vector3 = ((m[5] as Vector3) * attention + (m[6] as Vector3) * _level) * (PI / 180.0)
		(m[0] as Node3D).transform = Transform3D(rest.basis * Basis.from_euler(turn, EULER_ORDER_YXZ) * Basis(m[8] as Quaternion), rest.origin + rest.basis * off)
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

## What it looks at: a point it was given; the knight while either of them speaks; the thing it is inspecting; in a
## duel whoever is attacking (the foe otherwise, and the foe where it lies once it is down).
func _target() -> Vector3:
	if _look != Vector3.INF:
		return _look
	var story := get_node_or_null("/root/Story")
	var who := str(story.get("speaker")) if story != null and story.get("speaker") != null else ""
	if rig != null and (_forced_speech or who == "witness" or who == "player") and foe == null:
		return rig.global_transform * Vector3(0, 1.74, 0)
	if foe != null:
		if _foe_down:
			return foe.global_position + Vector3(0, 0.4, 0)
		var m = rig.get("mode") if rig != null else null
		var fm = foe.get("mode")
		var foe_busy: bool = fm != null and int(fm) in [FighterRig.Mode.WINDUP, FighterRig.Mode.STRIKE, FighterRig.Mode.THRUST_WINDUP, FighterRig.Mode.THRUST]
		if not foe_busy and m != null and int(m) in [FighterRig.Mode.WINDUP, FighterRig.Mode.STRIKE, FighterRig.Mode.THRUST_WINDUP, FighterRig.Mode.THRUST]:
			return rig.global_transform * Vector3(0, 1.4, 0)
		return foe.global_position + Vector3(0, 1.45 * foe.scale.y, 0)
	if rig != null and _free_now() and _beat == "inspect" and _poi != Vector3.INF:
		return _poi + Vector3(0, 0.2, 0)
	return Vector3.INF

# ---------------------------------------------------------------- where it goes
## It is free. Out of a fight it roams: a loose orbit of the knight, a look ahead down the road, a visit to
## whatever is of interest at this stop, and it comes round in front of the knight to speak. In a fight it keeps to
## the far edge of the ring (beyond the fighters as the camera sees them, above their heads) and answers what
## happens. roam(false), tuck(true), a cinematic's actor, or the knight's death put it back at the shoulder.
var roaming := true
var _beat := "orbit"          # orbit | scout | inspect | pause
var _beat_t := 0.0
var _goal := Vector3.ZERO
var _orbit_a := 0.7
var _orbit_dir := 1.0
var _poi := Vector3.INF       # what it is inspecting
var _poi_last := Vector3.INF
var _rig_was := Vector3.INF
var _rig_speed := 0.0
var _rng := RandomNumberGenerator.new()
var _sim: Object              # the duel's rules, for its events and the knight's health
var _dart_t := 0.0            # a heavy blow is coming: it has backed off
var _dip_t := 0.0             # a parry or a broken guard: it has come in to see
var _foe_down := false
var mood := ""                # what it is doing now (dev: logged and shown by the path plot)

static var _points: Array = []
static var _points_of: WeakRef

## The things worth a look at this stop (world points). `by` is the screen that owns them: they lapse with it.
static func set_points(by: Node, pts: Array) -> void:
	_points = pts
	_points_of = weakref(by)

func roam(on: bool) -> void:
	roaming = on

func _free_now() -> bool:
	if not roaming or _tucked or rig == null:
		return false
	return int(rig.get("mode")) != FighterRig.Mode.DEAD

func _follow(dt: float, calm: bool) -> void:
	if rig == null:
		# found but not yet with anyone: it holds where it rose
		if not calm:
			global_position.y += sin(_clock * 1.7) * 0.012 * dt
		return
	var k: float = rig.scale.y
	_rig_speed = lerpf(_rig_speed, (rig.global_position.distance_to(_rig_was) / maxf(dt, 0.001)) if _rig_was != Vector3.INF else 0.0, 0.1)
	_rig_was = rig.global_position
	_dart_t -= dt
	_dip_t -= dt
	_connect_duel()
	var st: Array
	if not _free_now():
		st = _shoulder(calm)
	elif foe != null:
		st = _duel_station(calm)
	else:
		st = _roam_station(dt, calm)
	var to: Vector3 = st[0]
	var stiff: float = st[1]
	to = _clear_body(to, k)
	to = _clear_view(to)
	to.y = maxf(to.y, 0.5)
	if not _placed or global_position.distance_to(to) > 14.0 * k:
		global_position = to
		_vel = Vector3.ZERO
		_placed = true
		return
	# a critically damped spring: it arrives a little late and never overshoots; a soft one makes the long eased arcs
	_vel += ((to - global_position) * stiff - _vel * 2.0 * sqrt(stiff)) * dt
	global_position += _vel * dt
	global_position = _clear_body(global_position, k)
	var lens := get_viewport().get_camera_3d() if is_inside_tree() else null
	if lens != null and lens.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var q := _clear_lens(global_position, lens, _free_now())
		if q != global_position:
			# a cut put the lens on top of it, or its way led past it: out at once, and it keeps no speed toward the lens
			var push := (q - global_position).normalized()
			_vel -= push * minf(_vel.dot(push), 0.0)
			global_position = q
	_log()

## At the sword-side shoulder (the first behaviour): held there for directed shots, and where it goes when the knight falls.
func _shoulder(calm: bool) -> Array:
	mood = "shoulder"
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
			mood = "fallen"
		_:
			if bool(rig.get("blocking")):
				local += Vector3(0.06, 0.1, 0.2)
	if not calm and mode != FighterRig.Mode.DEAD:
		local += Vector3(sin(_clock * 0.83 + 1.3) * 0.012, sin(_clock * 1.7) * 0.022 + sin(_clock * 0.9 + 1.0) * 0.008, cos(_clock * 0.61) * 0.01)
	return [rig.global_transform * local, stiff]

## Out of a fight. Returns [where to, how stiffly].
func _roam_station(dt: float, calm: bool) -> Array:
	var here: Transform3D = rig.global_transform
	var bob := Vector3.ZERO if calm else Vector3(0, sin(_clock * 1.6) * 0.035 + sin(_clock * 0.7 + 1.0) * 0.02, 0)
	var story := get_node_or_null("/root/Story")
	var who := str(story.get("speaker")) if story != null and story.get("speaker") != null else ""
	if _forced_speech or who == "witness" or who == "player":
		# it comes round in front of the knight to talk, and faces them
		mood = "address"
		_beat_t = 0.6
		_beat = "orbit"
		return [here * Vector3(0.5, 1.62, -1.3) + bob, 9.0]
	if _rig_speed > 0.5:
		# the knight is moving on: it leads, ahead and to the sword side
		mood = "lead"
		_beat_t = 0.8
		_beat = "orbit"
		return [here * Vector3(0.9 + (0.0 if calm else sin(_clock * 0.6) * 0.3), 1.95, -1.9) + bob, 7.0]
	_beat_t -= dt
	if _beat_t <= 0.0:
		_next_beat(calm)
	match _beat:
		"scout", "pause":
			pass
		"inspect":
			if _poi == Vector3.INF or _poi.distance_to(rig.global_position) > 11.0:
				_beat_t = 0.0
			else:
				# beside and above it, on the knight's side: never on top of the thing itself
				var side := rig.global_position - _poi
				side.y = 0.0
				_goal = _poi + side.normalized() * 0.55 + Vector3(0, 1.05, 0)
				if global_position.distance_to(_goal) < 0.5:
					mood = "scan"
					_flash = maxf(_flash, 0.35 + 0.3 * sin(_clock * 6.0))      # its light works over the thing
		_:
			_orbit_a += dt * (0.16 if calm else 0.3) * _orbit_dir
			var ring := 1.7 + 0.25 * sin(_clock * 0.37)
			var away := _away_from_lens()
			if away != Vector3.ZERO:
				# the lens is watching: it sweeps to and fro round the side of the knight the camera is NOT on, and
				# never crosses between the knight and the lens (a full circle put it in the camera's face each lap)
				_goal = rig.global_position + away.rotated(Vector3.UP, sin(_orbit_a) * 1.95) * ring * rig.scale.y + Vector3(0, 1.95 * rig.scale.y, 0)
			else:
				_goal = here * (Vector3(sin(_orbit_a), 0, -cos(_orbit_a)) * ring + Vector3(0, 1.95, 0))
	if _goal.distance_to(rig.global_position) > 7.0:
		_beat_t = 0.0
	return [_goal + bob, 3.2 if calm else 5.5]

## The level direction from the lens to the knight (zero when there is no perspective camera, or it is overhead).
func _away_from_lens() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or cam.projection != Camera3D.PROJECTION_PERSPECTIVE or rig == null:
		return Vector3.ZERO
	var d := rig.global_position - cam.global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.4 else Vector3.ZERO

## Never in the camera's face: kept out of an upright cylinder round the lens, wide where the lens looks (so that
## it is never more than LENS_MAX of the picture's height tall) and narrow behind it. It slides round, it does not jump.
const LENS_MAX := 0.14
func _clear_lens(p: Vector3, cam: Camera3D, free: bool) -> Vector3:
	var c := cam.global_position
	var off := p - c
	off.y = 0.0
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	var front := 1.5
	# (when the knight has fallen it lies low beside them, where a close camera would find it filling the frame:
	# that, at hip height, is the likeliest "large thing on the hip" in a close shot, so it keeps the wide berth then too)
	if free or (rig != null and is_instance_valid(rig) and rig.get("mode") != null and int(rig.get("mode")) == FighterRig.Mode.DEAD):
		front = clampf(2.6 * radius * _presence / (LENS_MAX * 2.0 * tan(deg_to_rad(cam.fov) * 0.5)), 1.2, 4.6)      # (2.6: vanes and weight stand outside `radius`)
	var d := off.length()
	var facing := off.dot(fwd.normalized()) / maxf(d, 0.001) if fwd.length() > 0.05 else 1.0
	var need := lerpf(0.9, front, smoothstep(-0.3, 0.5, facing))
	if absf(p.y - c.y) > need or d >= need:
		return p
	var dir := (off / d) if d > 0.01 else fwd.normalized()
	return Vector3(c.x, p.y, c.z) + dir * need

func _next_beat(calm: bool) -> void:
	var pts: Array = []
	if _points_of != null and _points_of.get_ref() != null and (_points_of.get_ref() as Node).is_inside_tree():
		for p in _points:
			if p is Vector3 and p.distance_to(rig.global_position) < 10.0 and p.distance_to(_poi_last) > 0.5:
				pts.append(p)
	var r := _rng.randf()
	if _beat != "pause" and not calm and r < 0.3:
		# a hesitation: it stops where it is, as if something had caught it
		_beat = "pause"
		mood = "pause"
		_goal = global_position
		_beat_t = _rng.randf_range(0.4, 0.9)
	elif not calm and not pts.is_empty() and r < 0.72:
		_beat = "inspect"
		mood = "inspect"
		_poi = pts[_rng.randi() % pts.size()]
		_poi_last = _poi
		_beat_t = _rng.randf_range(4.0, 5.5)
	elif not calm and r < 0.86:
		_beat = "scout"
		mood = "scout"
		_goal = rig.global_transform * Vector3(_rng.randf_range(-1.4, 1.4), _rng.randf_range(1.6, 2.2), -_rng.randf_range(2.6, 4.2))
		_beat_t = _rng.randf_range(2.8, 4.2)
	else:
		_beat = "orbit"
		mood = "orbit"
		_orbit_dir = -1.0 if _rng.randf() < 0.4 else 1.0
		_beat_t = _rng.randf_range(4.0, 7.0)

# ---------------------------------------------------------------- in a fight
func _connect_duel() -> void:
	if foe == null or _sim != null:
		return
	var d := rig.get_parent()
	var sim = d.get("sim") if d != null else null
	if sim is Object and sim.has_signal("ev"):
		_sim = sim
		sim.connect("ev", _on_duel_ev)

func _on_duel_ev(n: StringName, d: Dictionary) -> void:
	match n:
		&"boss_telegraph":
			# a blow is coming: out of the space between them, and well back from a heavy one
			var a: Dictionary = d.get("attack", {})
			var heavy: bool = bool(a.get("unblockable", false)) or str(a.get("kind", "")) in ["slam", "sweep", "breath", "heavy"]
			_dart_t = float(d.get("windup", 0.6)) + (0.9 if heavy else 0.45)
			_dart_heavy = heavy
			_dip_t = 0.0
		&"deflected", &"poise_break", &"boss_stagger":
			_dip_t = 1.1
			_dart_t = 0.0
			_flash = 1.0
		&"boss_dead":
			_foe_down = true
			_flash = 1.0
		&"restored", &"phase_change":
			_foe_down = false
			_dart_t = 1.2
			_dart_heavy = true
var _dart_heavy := false

## The far edge of the ring. Returns [where to, how stiffly].
func _duel_station(calm: bool) -> Array:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var a: Vector3 = rig.global_position
	var b: Vector3 = foe.global_position
	var mid := (a + b) * 0.5
	mid.y = 0.0
	var far := Vector3(0, 0, -1)
	if cam != null:
		far = mid - cam.global_position
		far.y = 0.0
		far = far.normalized() if far.length() > 0.1 else Vector3(0, 0, -1)
	var lat := far.cross(Vector3.UP)
	var to_knight := signf((a - mid).dot(lat))
	if to_knight == 0.0:
		to_knight = 1.0
	var head := 1.95 * maxf(1.0, foe.scale.y)
	var low := false
	if _sim != null:
		var pl = _sim.get("pl")
		low = pl is Dictionary and float(pl.get("hp", 1.0)) < 0.3 * float(pl.get("max_hp", 1.0))
	if _foe_down:
		mood = "over_foe"
		return [b + Vector3(0, 1.5 * maxf(1.0, foe.scale.y) + 0.5, 0) + far * 0.5, 6.0]
	var ang := sin(_clock * (0.11 if calm else 0.23)) * 1.0
	var r := 1.6 + 0.25 * sin(_clock * 0.41)      # just beyond the fighters: near enough to read, never nearer than they are
	var h := head + 0.45 + (0.0 if calm else sin(_clock * 1.6) * 0.05)
	var stiff := 4.0 if calm else 7.0
	mood = "ring"
	if low:
		# the knight is hurt: it stays by them, just beyond and above
		mood = "near_knight"
		return [a + far * 0.95 + lat * to_knight * 0.35 + Vector3(0, 2.15, 0), stiff]
	if not calm and _dart_t > 0.0:
		# back, and round to the knight's outer side: nothing of it between the fighters while the blow is read
		mood = "dart"
		ang = to_knight * 0.5
		r += 1.5 if _dart_heavy else 0.8
		h += 0.4
		stiff = 26.0
	elif not calm and _dip_t > 0.0:
		mood = "dip"
		ang = -to_knight * 0.35
		r -= 0.8
		h -= 0.2
		stiff = 18.0
	return [mid + (far * cos(ang) + lat * sin(ang)) * r + Vector3(0, h, 0), stiff]

# ---------------------------------------------------------------- keeping clear
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

## Kept in the picture's clear part: inside the frame; under the bars and tabs along the top; above the subtitles
## and the cards along the bottom; in a duel clear of the pads by its own width on screen, and never between the
## camera and either fighter; on the road never on top of a thing that can be touched.
func _clear_view(p: Vector3) -> Vector3:
	if not is_inside_tree():
		return p
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return p
	var view := get_viewport().get_visible_rect().size
	var duel := foe != null
	var free := _free_now()
	p = _clear_lens(p, cam, free)
	var c := cam.global_position
	if duel:
		# out of the lines from the lens to the fighters (beyond them it cannot cover them: only nearer counts)
		var home := p
		for who: Node3D in [foe, rig]:
			var fs: float = who.scale.y
			for h: float in [0.5, 1.1, 1.7]:
				var f: Vector3 = who.global_position + Vector3(0, h * fs, 0)
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
				if who == rig and not free:
					continue                     # at the shoulder it is beside the knight by design
				if (p - near).length() < need:
					var dir := (home - near).normalized() if (home - near).length() > 0.01 else Vector3.UP
					p = near + (dir + Vector3.UP * 0.4).normalized() * need
	if cam.is_position_behind(p):
		return p
	var depth := maxf((p - c).dot(-cam.global_transform.basis.z), 0.3)
	var per_px := 2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5) / maxf(view.y, 1.0)
	var m := minf(radius / per_px, view.y * 0.2) + 14.0      # its own half-width on screen, and a little air
	var s := cam.unproject_position(p)
	var to := s
	if not free and not duel:
		# held at a shoulder outside a fight: only kept from under a row of tabs
		var top0 := minf(44.0 + m, view.y * 0.16)
		if s.x > 0.0 and s.x < view.x and s.y < top0 and s.y > -200.0:
			p -= cam.global_transform.basis.y * (top0 - s.y) * per_px
		return p
	var story := get_node_or_null("/root/Story")
	var top := (64.0 if duel else 96.0) + m
	var bottom := view.y - (112.0 if duel else (215.0 if story != null and bool(story.get("busy")) else 150.0)) - m
	to.y = clampf(to.y, top, maxf(top, bottom))
	to.x = clampf(to.x, m, view.x - m)
	if duel:
		if to.x < 168.0 + m and to.y < 130.0 + m:                           # the two charge pads, top left
			if 168.0 + m - to.x < 130.0 + m - to.y:
				to.x = 168.0 + m
			else:
				to.y = 130.0 + m
		if to.x > view.x - 64.0 - m and to.y < 88.0 + m:                   # the pause button, top right
			to.x = view.x - 64.0 - m
	elif _points_of != null and _points_of.get_ref() != null:
		for q in _points:
			if q is Vector3 and not cam.is_position_behind(q):
				var sq := cam.unproject_position(q)
				if to.distance_to(sq) < m + 30.0:                              # something that can be touched: above it, not on it
					to.y = sq.y - (m + 30.0)
	if not duel:
		# a menu's panel is opaque: beside it, on the side with more room, never behind it
		for r: Rect2 in _menu_rects(view):
			var g := r.grow(m)
			if g.has_point(to):
				var left := g.position.x
				var right := view.x - g.end.x
				if left >= right and left > 2.0 * m:
					to.x = g.position.x
				elif right > 2.0 * m:
					to.x = g.end.x
				elif g.position.y > 2.0 * m:
					to.y = g.position.y
	var shift := (cam.global_transform.basis.x * (to.x - s.x) - cam.global_transform.basis.y * (to.y - s.y)) * per_px
	return p + shift.limit_length(3.0)

## The large opaque panels on screen now (a menu's page: a tenth of the picture or more, and at least a third of its
## height), looked up twice a second. Small cards and bars are not counted: the margins above already keep it off them.
var _ui_rects: Array = []
var _ui_next := 0.0
func _menu_rects(view: Vector2) -> Array:
	if _clock >= _ui_next:
		_ui_next = _clock + 0.5
		_ui_rects.clear()
		for c: Node in get_tree().root.find_children("*", "PanelContainer", true, false):
			var pc := c as Control
			if pc != null and pc.is_visible_in_tree():
				var r := pc.get_global_rect()
				if r.size.x * r.size.y > view.x * view.y * 0.1 and r.size.y > view.y * 0.33:
					_ui_rects.append(r)
	return _ui_rects

## Dev: HR_WITNESS_LOG=<file> writes ten lines a second: t, mood, drone x y z, knight x z, foe x z, camera x z,
## screen x y, view w h, on-screen half-width (tools/witness_plot.py draws them).
var _log_file: FileAccess
var _log_next := 0.0
func _log() -> void:
	if not OS.has_environment("HR_WITNESS_LOG") or _clock < _log_next or not is_inside_tree():
		return
	_log_next = _clock + 0.1
	if _log_file == null:
		_log_file = FileAccess.open(OS.get_environment("HR_WITNESS_LOG"), FileAccess.WRITE)
		if _log_file == null:
			return
	var cam := get_viewport().get_camera_3d()
	if cam == null or rig == null:
		return
	var p := global_position
	var s := cam.unproject_position(p) if not cam.is_position_behind(p) else Vector2(-999, -999)
	var view := get_viewport().get_visible_rect().size
	var depth := maxf((p - cam.global_position).dot(-cam.global_transform.basis.z), 0.3)
	var half := radius / (2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5) / maxf(view.y, 1.0))
	var f: Vector3 = foe.global_position if foe != null else Vector3(999, 0, 999)
	_log_file.store_line("%.2f %s %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.1f %.1f %.0f %.0f %.1f" % [_clock, mood if mood != "" else "-", p.x, p.y, p.z,
		rig.global_position.x, rig.global_position.z, f.x, f.z, cam.global_position.x, cam.global_position.z, s.x, s.y, view.x, view.y, half])
	_log_file.flush()
