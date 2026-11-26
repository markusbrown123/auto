class_name GearBench
extends Node3D
## Dev viewer for the hand-modelled equipment: studio light, dark backdrop, one piece large and turning.
##   --screen=gearbench [--item=<id in gear_manifest.json>]
##     --yaw=<deg>        hold this angle instead of turning        --tilt=<deg>  lean toward the camera
##     --focus=<y>[,<x>]  aim at a point on the piece (metres from its origin)   --dist=<m>  camera distance
##     --upright          swords stand instead of lying along the frame          --lod       the low model
##     --palm             a 9 cm bar beside the grip (the width of a palm)
##     --tour             one view a second from t = 1: flat, turned, hilt close-up, engraving close-up
##                        (shields: front, rear, grip close-up, rim close-up)
##     --blade_tier=0-3 --grip_tier=0-3 --ore=steel|silver|graphite|bronze|frost --dull   forge state (basic swords)
##     --awake            light channels on               --silhouette   flat black on a pale ground
##     --recall           Recall and dismissal, looping   --strip   stills of Recall at rising progress [--steps=0.1,0.5,..]
##     --cheap            the Performance / reduced-motion path of Recall
##     --compare          the old Wayfarer model beside the new one
##     --lineup[=swords|shields]  the collection upright, side by side      --mods  forge progression of --item
##     --hand             in the knight's hand (the piece replaces what the rig carries, in this viewer only)

var args := {}
var pivot: Node3D
var spinner: Node3D
var item: Node3D
var cam: Camera3D
var _fixed := false
var _t := 0.0
var _loop: Array = []          # nodes Recall plays on
var _views: Array = []
var _view_i := -1
var _info := {}
var _shield := false

func _init(a: Dictionary = {}) -> void:
	args = a

func _ready() -> void:
	_studio()
	var id := str(args.get("item", "wayfarer"))
	if args.has("hand"):
		_in_hand(id)
	elif args.has("compare"):
		_compare()
	elif args.has("lineup"):
		_lineup(str(args.lineup))
	elif args.has("mods"):
		_mods(id)
	elif args.has("strip"):
		_strip(id)
	else:
		_single(id)
	if args.has("silhouette"):
		var black := StandardMaterial3D.new()
		black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		black.albedo_color = Color(0.02, 0.02, 0.025)
		for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
			if not mi.has_meta("shell"):
				mi.material_override = black

func _studio() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	# an even soft-box all the way round, floor included: a flat blade always has something to reflect, so it
	# shows a gradient at every angle instead of dropping to black when it faces down
	sky_mat.sky_top_color = Color(0.5, 0.53, 0.6)
	sky_mat.sky_horizon_color = Color(0.74, 0.76, 0.8)
	sky_mat.ground_horizon_color = Color(0.62, 0.63, 0.66)
	sky_mat.ground_bottom_color = Color(0.3, 0.31, 0.34)
	sky_mat.sky_curve = 0.35
	sky_mat.ground_curve = 0.25
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	# the sky lights the metal; a dark shell hides it from the camera
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	var shell := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 40.0
	sph.height = 80.0
	sph.radial_segments = 16
	sph.rings = 8
	shell.mesh = sph
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.78, 0.79, 0.8) if args.has("silhouette") else Color(0.028, 0.03, 0.036)
	dark.cull_mode = BaseMaterial3D.CULL_FRONT
	shell.material_override = dark
	shell.set_meta("shell", true)
	add_child(shell)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.53, 0.6)
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# the same curve and glow as the arenas, so what is judged here is what the game shows
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 3.0
	env.tonemap_exposure = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	for l: Array in [[Vector3(-38, -32, 0), Color(1.0, 0.97, 0.92), 1.1], [Vector3(-12, 55, 0), Color(0.7, 0.8, 1.0), 0.4], [Vector3(-25, 165, 0), Color(1.0, 0.9, 0.78), 0.8]]:
		var d := DirectionalLight3D.new()
		d.rotation_degrees = l[0]
		d.light_color = l[1]
		d.light_energy = l[2]
		add_child(d)

func _camera(at: Vector3, dist: float, fov: float = 30.0, from: Vector3 = Vector3(0, 0, 1)) -> Camera3D:
	if cam == null:
		cam = Camera3D.new()
		add_child(cam)
		cam.make_current()
	cam.fov = fov
	cam.near = 0.02
	cam.position = at + from.normalized() * dist
	cam.look_at(at)
	return cam

func _is_shield(id: String) -> bool:
	return str(GearModel.info(id).get("class", "")) == "shield"

func _mod() -> Dictionary:
	var m := {}
	for k: String in ["blade_tier", "grip_tier"]:
		if args.has(k):
			m[k] = int(args[k])
	if args.has("ore"):
		m["ore"] = str(args.ore)
	if args.has("dull"):
		m["sharpened"] = false
	return m

func _spawn(id: String, mod: Dictionary = {}) -> Node3D:
	var n := GearModel.spawn(id, 0.0, args.has("lod"), mod if not mod.is_empty() else _mod())
	if n == null:
		push_error("gearbench: no such item " + id)
		n = Node3D.new()
	if args.has("awake"):
		GearModel.awaken(n, true)
	return n

func _single(id: String) -> void:
	_info = GearModel.info(id)
	_shield = _is_shield(id)
	pivot = Node3D.new()
	add_child(pivot)
	spinner = Node3D.new()
	pivot.add_child(spinner)
	item = _spawn(id)
	spinner.add_child(item)
	var v := {}
	for k: String in ["yaw", "tilt", "focus", "dist"]:
		if args.has(k):
			v[k] = args[k]
	if args.has("tour"):
		if _shield:
			_views = [{"yaw": 200}, {"yaw": 28}, {"yaw": 38, "tilt": -8, "focus": "0,-0.09", "dist": 0.5}, {"yaw": 215, "focus": "0.12,-0.3", "dist": 0.3}]
		else:
			var tip := float(_info.get("tip", 1.0))
			var pom := float(_info.get("pommel", 0.1))
			var span := float(_info.get("guard_span", 0.2))
			_views = [{"yaw": 12, "tilt": 14}, {"yaw": -38, "tilt": -12},
				{"yaw": 14, "tilt": 10, "focus": str(0.03 - pom * 0.35), "dist": str(maxf(0.36, maxf((pom + 0.22) * 1.25, span * 2.6)))},
				{"yaw": 10, "tilt": 8, "focus": str(tip * 0.3), "dist": "0.2"}]
	else:
		_view(v)
	if args.has("palm") and not _shield:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.004, 0.09, 0.004)
		bar.mesh = bm
		bar.material_override = Look.glow(Color(0.3, 1.0, 0.45), 1.0)
		bar.position = Vector3(0.0, 0.0, 0.03)
		item.add_child(bar)
	if args.has("recall"):
		_loop = [item]
		_cycle()

func _view(v: Dictionary) -> void:
	var lo := _v3(_info.get("lo", [0, 0, 0]))
	var hi := _v3(_info.get("hi", [0, 1, 0]))
	var mid := (lo + hi) * 0.5
	var size := (hi - lo).length()
	var focus := mid
	if v.has("focus"):
		var f := str(v.focus).split(",")
		focus = Vector3(float(f[1]) if f.size() > 1 else mid.x, float(f[0]), mid.z if _shield else 0.0)
	item.position = -Vector3(mid.x if _shield else 0.0, focus.y if not _shield else mid.y, mid.z if _shield else 0.0)
	var look_at := Vector3.ZERO
	pivot.rotation_degrees = Vector3.ZERO
	if _shield:
		look_at = Vector3(focus.x - mid.x, focus.y - mid.y, 0) if v.has("focus") else Vector3.ZERO
	elif not args.has("upright"):
		pivot.rotation_degrees.z = -90.0
	pivot.rotation_degrees.x = float(v.get("tilt", 0))
	var fit := size / (0.5 if _shield or args.has("upright") else 0.82)
	_camera(look_at, float(v.get("dist", fit)))
	_fixed = v.has("yaw")
	if _fixed:
		spinner.rotation_degrees.y = float(v.yaw)

func _cycle() -> void:
	# summon, rest, dismiss, rest, for ever
	var opts := {"cheap": true} if args.has("cheap") else {}
	if args.has("short"):
		opts["short"] = true
	while is_inside_tree():
		for n: Node3D in _loop:
			Recall.summon(n, opts)
		await get_tree().create_timer(2.0).timeout
		for n: Node3D in _loop:
			Recall.dismiss(n, opts)
		await get_tree().create_timer(1.6).timeout

func _strip(id: String) -> void:
	var steps: Array = [0.1, 0.28, 0.46, 0.64, 0.8, 0.9, 1.0]
	if args.has("steps"):
		steps = Array(str(args.steps).split(",")).map(func(x: String) -> float: return float(x))
	var info := GearModel.info(id)
	var lo := _v3(info.get("lo", [0, 0, 0]))
	var hi := _v3(info.get("hi", [0, 1, 0]))
	var shield := _is_shield(id)
	var gap := (hi.x - lo.x) * (1.12 if shield else 1.5)
	for i in steps.size():
		var n := _spawn(id)
		GearModel.awaken(n, true)
		add_child(n)
		n.position = Vector3((i - (steps.size() - 1) * 0.5) * gap, -(lo.y + hi.y) * 0.5, 0) - Vector3((lo.x + hi.x) * 0.5, 0, 0)
		n.rotation_degrees.y = float(args.get("yaw", "20"))
		if steps[i] < 1.0:
			Recall.hold(n, steps[i], {"cheap": args.has("cheap")})
		_label("%.2f" % steps[i], Vector3(n.position.x + (lo.x + hi.x) * 0.5, -(hi.y - lo.y) * 0.56, 0), 0.0009 * maxf(1.0, (hi.y - lo.y)))
	var w := gap * steps.size()
	_camera(Vector3.ZERO, maxf(w / 0.9, (hi.y - lo.y) / 0.5) * float(args.get("zoom", "1")))

func _label(text: String, at: Vector3, px: float = 0.0008) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.pixel_size = px
	lab.position = at
	lab.modulate = Color(0.25, 0.26, 0.3) if args.has("silhouette") else Color(0.7, 0.73, 0.8)
	add_child(lab)

func _compare() -> void:
	var old := Node3D.new()
	add_child(old)
	PropModel.weapon(old, "res://assets/models/%s.glb" % str(args.get("old", "w_rusted_sword")), "sword")
	var new_ := _spawn(str(args.get("item", "wayfarer")))
	add_child(new_)
	var yaw := float(args.get("yaw", "25"))
	for e: Array in [[old, 0.1, "OLD  w_rusted_sword.glb (image-to-3D, fitted by PropModel)"], [new_, -0.2, "NEW  gear/wayfarer.glb (modelled)"]]:
		var n: Node3D = e[0]
		n.rotation_degrees = Vector3(0, 0, -90)
		n.rotate_object_local(Vector3.UP, deg_to_rad(yaw))
		n.position = Vector3(-0.42, e[1], 0)
		_label(e[2], Vector3(0.05, float(e[1]) + (0.17 if float(e[1]) > 0 else 0.09), 0))
	_camera(Vector3(float(args.get("focus", "0.06")), 0, 0), float(args.get("dist", "1.42")))
	if args.has("recall"):
		# the effect on a generated model fitted by PropModel as well as on a modelled one
		_loop = [old, new_]
		_cycle()

## The collection standing side by side, pommels on one line. Twin Relics shows both of its pair.
func _lineup(which: String) -> void:
	var list: Array = []
	if which != "shields":
		for id: String in GearModel.ids("sword"):
			list.append([id, 1.0])
			if GearModel.info(id).get("pair", false):
				list.append([id, -1.0])
	if which != "swords":
		for id: String in GearModel.ids("shield"):
			list.append([id, 1.0])
	var x := 0.0
	var top := 0.0
	var nodes: Array = []
	for e: Array in list:
		var info := GearModel.info(e[0])
		var lo := _v3(info.get("lo", [0, 0, 0]))
		var hi := _v3(info.get("hi", [0, 1, 0]))
		var shield := _is_shield(e[0])
		var w := hi.x - lo.x
		var n := _spawn(e[0])
		add_child(n)
		n.scale.x = e[1]
		var yaw := float(args.get("yaw", "0"))
		x += w * 0.5 + (0.05 if shield else 0.035)
		if shield:
			n.rotation_degrees.y = 180.0 + yaw
			n.position = Vector3(x + (lo.x + hi.x) * 0.5, -lo.y, 0)
		else:
			n.rotation_degrees.y = yaw
			n.position = Vector3(x - (lo.x + hi.x) * 0.5 * float(e[1]), -lo.y, 0)
		nodes.append(n)
		if e[1] > 0.0:
			_label(str(info.get("name", e[0])) + ("\n" + str(info.get("role", "")) if args.has("roles") else ""), Vector3(x, -0.06, 0), 0.0011)
		x += w * 0.5 + (0.05 if shield else 0.035)
		top = maxf(top, hi.y - lo.y)
	for n: Node3D in nodes:
		n.position.x -= x * 0.5
	for c in get_children():
		if c is Label3D:
			c.position.x -= x * 0.5
	_camera(Vector3(0, top * 0.5 - 0.03, 0), maxf(x / 0.92, (top + 0.14) / 0.52))

## Forge progression of one basic sword: each track at its ends, then the blade metals.
func _mods(id: String) -> void:
	var rows := [
		[{"blade_tier": 0, "grip_tier": 0, "sharpened": false}, "new\nblade 0  grip 0"],
		[{"blade_tier": 1, "grip_tier": 0, "sharpened": false}, "blade 1"],
		[{"blade_tier": 2, "grip_tier": 0, "sharpened": false}, "blade 2"],
		[{"blade_tier": 3, "grip_tier": 0, "sharpened": false}, "blade 3"],
		[{"blade_tier": 0, "grip_tier": 1, "sharpened": false}, "grip 1"],
		[{"blade_tier": 0, "grip_tier": 2, "sharpened": false}, "grip 2"],
		[{"blade_tier": 0, "grip_tier": 3, "sharpened": false}, "grip 3"],
		[{"blade_tier": 3, "grip_tier": 3, "sharpened": true}, "3 / 3\nsharpened"],
		[{"blade_tier": 3, "grip_tier": 3, "sharpened": true, "ore": "silver"}, "silver"],
		[{"blade_tier": 3, "grip_tier": 3, "sharpened": true, "ore": "graphite"}, "graphite"],
		[{"blade_tier": 3, "grip_tier": 3, "sharpened": true, "ore": "bronze"}, "bronze"],
		[{"blade_tier": 3, "grip_tier": 3, "sharpened": true, "ore": "frost"}, "frost"],
	]
	var info := GearModel.info(id)
	var lo := _v3(info.get("lo", [0, 0, 0]))
	var hi := _v3(info.get("hi", [0, 1, 0]))
	var gap := maxf(hi.x - lo.x, 0.1) * 1.18
	var zoom := args.has("zoom")
	if zoom:
		rows = [rows[0], rows[7], rows[10]]
	for i in rows.size():
		var n := _spawn(id, rows[i][0])
		add_child(n)
		n.rotation_degrees.y = float(args.get("yaw", "14"))
		n.position = Vector3((i - (rows.size() - 1) * 0.5) * gap, 0, 0)
		_label(rows[i][1], Vector3(n.position.x, lo.y - 0.05, 0), 0.0007 if zoom else 0.0011)
	if zoom:
		# the lower third: grips, guards and the foot of each blade
		_camera(Vector3(0, 0.07, 0), gap * rows.size() / 0.9)
	else:
		_camera(Vector3(0, (lo.y + hi.y) * 0.5 - 0.03, 0), maxf(gap * rows.size() / 0.92, (hi.y - lo.y + 0.12) / 0.52))

## The piece in the knight's hand, by replacing what the rig built (nothing outside this viewer changes).
##   --with=<shield id>  also carry this shield (one-handed swords)     --centre  hang the shield by its board
##   centre, as the rig does today, instead of putting its grip in the hand      --block  raise the guard
##   --lifesize          1:1 instead of the manifest's rig_scale
func _in_hand(id: String) -> void:
	var shield_id := id if _is_shield(id) else str(args.get("with", ""))
	var sword_id := id if not _is_shield(id) else str(args.get("with", "wayfarer"))
	var info := GearModel.info(sword_id)
	Game.profile.body = str(args.get("body", "m"))
	var rig := FighterRig.new()
	add_child(rig)
	var look: Dictionary = Duel.player_look()
	var cls := str(info.get("class", "sword"))
	look["weapon"] = cls if cls != "dual" else "sword"
	look["cape"] = false
	look.erase("weapon_model")
	if shield_id != "":
		look["shield"] = {"color": "#30363c"}
	else:
		look.erase("shield")
	rig.build(look, false)
	rig.rotation_degrees.y = float(args.get("yaw", "150"))
	var k := 1.0 if args.has("lifesize") else float(info.get("rig_scale", 1.0))
	await get_tree().process_frame
	if shield_id == "" and rig.shield:
		rig.set_shield(null)
	if shield_id != "" and rig.shield:
		for c in rig.shield.get_children():
			c.queue_free()
		var s := GearModel.spawn(shield_id, 0.0)
		s.scale = Vector3.ONE * k
		# the rig's shield node sits 7 cm ahead of the hand and stands for the middle of the board
		s.position = -_v3(GearModel.info(shield_id).get("board_centre", [0, 0, 0])) if args.has("centre") else Vector3(0.02, 0.0, 0.07)
		rig.shield.add_child(s)
		if _is_shield(id):
			item = s
	for c in rig.weapon_r.get_children():
		c.queue_free()
	var w := _spawn(sword_id)
	w.scale = Vector3.ONE * k
	rig.weapon_r.add_child(w)
	rig.weapon_len = float(info.get("tip", 1.0)) * k
	rig._pommel = float(info.get("pommel", 0.14)) * k
	if info.has("off_hand"):
		rig._off_grip = -float(info.off_hand) * k
	if not _is_shield(id):
		item = w
	if args.has("block"):
		rig.blocking = true
	var f := str(args.get("focus", "1.05")).split(",")
	var at := Vector3(float(f[1]) if f.size() > 1 else 0.0, float(f[0]), 0)
	_camera(at, float(args.get("dist", "2.6")), 30.0, Vector3(0.0, 0.12, 1.0))
	if args.has("recall"):
		_loop = [item]
		_cycle()

func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func _process(delta: float) -> void:
	_t += delta
	if not _views.is_empty():
		var i := clampi(int(_t) - 1, 0, _views.size() - 1)
		if i != _view_i:
			_view_i = i
			_view(_views[i])
	if spinner and not _fixed:
		spinner.rotation.y = _t * deg_to_rad(float(args.get("spin", "40")))
