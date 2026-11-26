class_name InvPreview
extends SubViewportContainer
## A slowly turning 3D view of one weapon or shield in its own small world, lit like a display
## case: one warm key, one cool rim, very little fill. Drag across it to turn the piece.

static var angle := 0.6          # shared, so the piece does not snap back when the list rebuilds

var vp: SubViewport
var pivot: Node3D
var ok := false

func _init(item_id: String, height: float = 180.0) -> void:
	stretch = true
	custom_minimum_size = Vector2(0, height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.positional_shadow_atlas_size = 0
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.022, 0.022, 0.028)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#4a4640")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var it: Dictionary = Db.item(item_id)
	var tilt := Node3D.new()
	vp.add_child(tilt)
	pivot = Node3D.new()
	tilt.add_child(pivot)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var extent := 1.0
	if it.get("slot", "") == "weapon":
		var cls: String = it.cls
		var m: Dictionary = Duel.weapon_model(item_id)
		var path: String = m.weapon_model
		if not PropModel.exists(path):
			return
		var len: float = float(PropModel.LENGTH.get(cls, 1.1))
		var grip: float = float(PropModel.GRIP.get(cls, 0.11))
		var n: int = 2 if cls == "dual" else 1
		for i in n:
			var holder := Node3D.new()
			# centre the piece on the turning axis; a pair is laid crossed, the second reversed
			var arm := Node3D.new()
			pivot.add_child(arm)
			arm.rotation.z = 0.0 if n == 1 else (0.16 if i == 0 else PI - 0.16)
			arm.add_child(holder)
			holder.position = Vector3(0, -len * (0.5 - grip), 0.03 * i)
			PropModel.weapon(holder, path, cls, m.get("weapon_tint"))
		tilt.rotation.z = -PI * (0.42 if n == 1 else 0.5)      # lying along the frame, point to the right and a little up
		extent = len
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		ok = true
	elif it.get("slot", "") == "shield":
		var path := "res://assets/models/%s.glb" % item_id
		if not PropModel.exists(path) or not PropModel.shield(pivot, path, 0.82):
			return
		extent = 0.82
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		ok = true
	else:
		return
	cam.position = Vector3(0, 0, extent * 1.18 / (2.0 * tan(deg_to_rad(15.0))))
	var key := SpotLight3D.new()
	key.light_color = Color("#ffe2b8")
	key.light_energy = 7.0
	key.spot_range = 9.0
	key.spot_angle = 38.0
	key.shadow_enabled = false
	vp.add_child(key)
	key.look_at_from_position(Vector3(-extent * 0.9, extent * 1.1, extent * 1.6), Vector3.ZERO)
	var rim := DirectionalLight3D.new()
	var glow = it.get("look", {}).get("glow")
	rim.light_color = Color(str(glow)).lerp(Color.WHITE, 0.25) if glow != null else Color("#7f9cc8")
	rim.light_energy = 1.1
	rim.rotation_degrees = Vector3(-18, 155, 0)
	vp.add_child(rim)
	pivot.rotation.y = angle

func _process(delta: float) -> void:
	if pivot and not Game.settings.reduce_motion:
		angle = wrapf(angle + delta * 0.45, -PI, PI)
		pivot.rotation.y = angle

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenDrag and pivot:
		angle = wrapf(angle + e.relative.x * 0.012, -PI, PI)
		pivot.rotation.y = angle
		accept_event()
