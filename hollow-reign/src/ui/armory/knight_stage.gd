class_name KnightStage
extends RefCounted
## The display stage the armoury and the shop put the knight on: a dark seamless cove behind and under the figure
## (so the gear reads against something plain), a soft pool of light at its feet, and a camera that fits the whole
## knight into one rectangle of the screen and never lets it spill under the panels beside it.
## Drag turns the knight, pinch / wheel / the + and - buttons zoom toward the part being looked at.
## Nothing here touches the save; it only places nodes under the backdrop and moves its camera.

const MOODS := {
	# the armoury: a clean, cool, evenly lit studio
	"studio": {"back_in": Color(0.15, 0.155, 0.17), "back_out": Color(0.018, 0.019, 0.023), "floor_in": Color(0.2, 0.2, 0.215),
		"floor_out": Color(0.012, 0.012, 0.015), "ring": Color(0.72, 0.62, 0.42, 0.55)},
	# the shop: dark and moody, a warm ember glow behind the figure
	"forge": {"back_in": Color(0.17, 0.085, 0.04), "back_out": Color(0.012, 0.008, 0.007), "floor_in": Color(0.16, 0.095, 0.055),
		"floor_out": Color(0.008, 0.006, 0.005), "ring": Color(0.95, 0.55, 0.22, 0.5)},
}
const ZOOM_MIN := 0.32            # closest: about a third of the whole-body distance
const ZOOM_MAX := 1.0
const FOV := 36.0

const BACK_SHADER := "shader_type spatial;\nrender_mode unshaded, fog_disabled, shadows_disabled;\nuniform vec4 c_in : source_color;\nuniform vec4 c_out : source_color;\nvarying vec3 wp;\nvoid vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment() {\n\tfloat d = length(vec2(wp.x * 0.55, (wp.y - 1.15) * 0.8));\n\tALBEDO = mix(c_in.rgb, c_out.rgb, smoothstep(0.0, 1.6, d));\n}\n"
const FLOOR_SHADER := "shader_type spatial;\nrender_mode unshaded, fog_disabled, shadows_disabled;\nuniform vec4 c_in : source_color;\nuniform vec4 c_out : source_color;\nuniform vec4 ring : source_color;\nvarying vec3 wp;\nvoid vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment() {\n\tfloat r = length(wp.xz * vec2(1.0, 1.25));\n\tvec3 c = mix(c_in.rgb, c_out.rgb, smoothstep(0.15, 2.4, r));\n\tc *= mix(0.35, 1.0, smoothstep(0.08, 0.42, r));\n\tfloat line = 1.0 - smoothstep(0.0, 0.012, abs(r - 0.78));\n\tc = mix(c, ring.rgb, line * ring.a);\n\t// the far floor fades into the back wall, so there is no horizon line\n\tc = mix(c, c_out.rgb, smoothstep(-0.6, -2.4, wp.z));\n\tALBEDO = c;\n}\n"

var backdrop: Backdrop
var root: Node3D
var zoom := 1.0
var yaw_user := 0.0
var _touches := {}
var _pinch0 := 0.0
var _focus_p := Vector3(0, 0.95, 0)
var _arena_hidden: Array = []

func _init(bd: Backdrop, mood: String = "studio") -> void:
	backdrop = bd
	var m: Dictionary = MOODS.get(mood, MOODS.studio)
	root = Node3D.new()
	root.name = "KnightStage"
	bd.add_child(root)
	var back := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(16, 9)
	back.mesh = q
	back.position = Vector3(0, 3.2, -2.6)
	back.material_override = _mat(BACK_SHADER, m)
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(back)
	var fl := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(16, 9)
	fl.mesh = p
	fl.position = Vector3(0, 0.004, 1.9)
	fl.material_override = _mat(FLOOR_SHADER, m)
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fl)
	# the place's own scenery would stand in front of the cove: it is put away while the stage is up (the light stays)
	if bd.arena:
		for c in bd.arena.get_children():
			if c is GeometryInstance3D and c.visible:
				c.visible = false
				_arena_hidden.append(c)
			elif c is Node3D and not (c is Light3D) and c.visible and not c.find_children("*", "GeometryInstance3D", true, false).is_empty():
				c.visible = false
				_arena_hidden.append(c)
	if bd.props:
		bd.props.visible = false

func _mat(code: String, m: Dictionary) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("c_in", m.back_in if code == BACK_SHADER else m.floor_in)
	sm.set_shader_parameter("c_out", m.back_out if code == BACK_SHADER else m.floor_out)
	sm.set_shader_parameter("ring", m.ring)
	return sm

## Takes the stage down and gives the place its scenery back.
func close() -> void:
	for c in _arena_hidden:
		if is_instance_valid(c):
			c.visible = true
	_arena_hidden.clear()
	if backdrop and is_instance_valid(backdrop) and backdrop.props:
		backdrop.props.visible = true
	if root and is_instance_valid(root):
		root.queue_free()
	root = null

## Height of the top of the knight's head above the floor (world metres).
func knight_top() -> float:
	var r := backdrop.rig
	if r and r.skin and r.skin.bone.has("Head"):
		return (r.body.global_transform * r.skin.point("Head")).y + 0.2
	return 1.95

## World position of a bone of the knight ("" = the middle of the figure).
func bone_point(bone: String) -> Vector3:
	var r := backdrop.rig
	if bone != "" and r and r.skin and r.skin.bone.has(bone):
		return r.body.global_transform * r.skin.point(bone)
	return Vector3(0, knight_top() * 0.5, 0)

## Points the camera so the whole knight (feet to crown, with a little air) fills `rect` (canvas pixels of a
## `vs`-sized screen). As the zoom closes in, `bone` is drawn toward the middle of the rect.
func aim(rect: Rect2, vs: Vector2, bone: String, snap: bool) -> void:
	if rect.size.y < 16.0 or rect.size.x < 16.0:
		return
	var top := knight_top()
	var y0 := -0.06
	var y1 := top + 0.1
	# fit the height, and the width too (an arm and a shield out to the side need about 0.62 of the height)
	var ppm := minf(rect.size.y / (y1 - y0), rect.size.x / ((y1 - y0) * 0.62))
	var t := tan(deg_to_rad(FOV * 0.5))
	var hh_full := vs.y * 0.5 / ppm                     # half the screen's height in metres at the knight
	var d_full := hh_full / t
	var full_mid := Vector3(0, (y0 + y1) * 0.5, 0)
	# where the whole figure's middle sits on screen when fitted: the rect's centre
	var p := bone_point(bone) if bone != "" else full_mid
	var u := clampf((ZOOM_MAX - zoom) / (ZOOM_MAX - ZOOM_MIN), 0.0, 1.0)
	var aim_p := full_mid.lerp(p, u)
	_focus_p = aim_p if snap else _focus_p.lerp(aim_p, 0.5)
	var hh := hh_full * zoom
	var hw := hh * vs.x / vs.y
	var c := rect.get_center()
	var cx := _focus_p.x - (c.x - vs.x * 0.5) * 2.0 * hw / vs.x
	var cy := _focus_p.y + (c.y - vs.y * 0.5) * 2.0 * hh / vs.y
	var d := d_full * zoom
	backdrop.cam_fov = FOV
	backdrop.move_camera(Vector3(cx, cy, _focus_p.z + d), Vector3(cx, cy, _focus_p.z), snap or bool(Game.settings.reduce_motion))

func zoom_by(f: float) -> void:
	zoom = clampf(zoom * f, ZOOM_MIN, ZOOM_MAX)

## Drag turns, two fingers pinch, the wheel and a trackpad pinch zoom. Returns "double" for a double tap, "" otherwise.
func handle(e: InputEvent) -> String:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
			if e.double_tap:
				return "double"
		else:
			_touches.erase(e.index)
		_pinch0 = 0.0
	elif e is InputEventScreenDrag:
		_touches[e.index] = e.position
		if _touches.size() >= 2:
			var k: Array = _touches.keys()
			var dist: float = (_touches[k[0]] as Vector2).distance_to(_touches[k[1]])
			if _pinch0 > 0.0 and dist > 1.0:
				zoom_by(_pinch0 / dist)
			_pinch0 = dist
		else:
			turn(e.relative.x * 0.012)
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_by(0.9 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1)
	elif e is InputEventMagnifyGesture:
		zoom_by(1.0 / e.factor)
	return ""

func turn(by: float) -> void:
	yaw_user = wrapf(yaw_user + by, -PI, PI)
	backdrop.turn_knight(by)
