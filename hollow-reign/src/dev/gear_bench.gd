class_name GearBench
extends Node3D
## Dev viewer for the hand-modelled equipment: studio light, dark backdrop, one piece large and turning.
##   --screen=gearbench [--item=wayfarer|oathbreaker|eternal_edge|shield_heater|shield_round]
##     --yaw=<deg>        hold this angle instead of turning        --tilt=<deg>  lean toward the camera
##     --focus=<y>[,<x>]  aim at a point on the piece (metres from its origin)   --dist=<m>  camera distance
##     --upright          swords stand instead of lying along the frame          --lod       the low model
##     --palm             a 9 cm bar beside the grip (the width of a palm)
##     --recall           Recall and dismissal, looping      --strip   stills of Recall at rising progress [--steps=0.1,0.5,..]
##     --cheap            the Performance / reduced-motion path of Recall
##     --compare          the old Wayfarer model beside the new one              --lineup    all five
##     --hand             in the knight's hand (the piece replaces what the rig carries, in this viewer only)

const ITEMS := ["wayfarer", "oathbreaker", "eternal_edge", "shield_heater", "shield_round"]
var args := {}
var spinner: Node3D
var item: Node3D
var _fixed := false
var _t := 0.0
var _loop: Array = []          # nodes Recall plays on
var _phase := 0

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
		_lineup()
	elif args.has("strip"):
		_strip(id)
	else:
		_single(id)

func _studio() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	# a soft-box: bright band at the horizon, dimmer overhead, dark floor (seen only in reflections)
	sky_mat.sky_top_color = Color(0.46, 0.5, 0.58)
	sky_mat.sky_horizon_color = Color(0.8, 0.82, 0.86)
	sky_mat.ground_horizon_color = Color(0.5, 0.5, 0.52)
	sky_mat.ground_bottom_color = Color(0.12, 0.12, 0.14)
	sky_mat.sky_curve = 0.25
	sky_mat.ground_curve = 0.12
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
	dark.albedo_color = Color(0.028, 0.03, 0.036)
	dark.cull_mode = BaseMaterial3D.CULL_FRONT
	shell.material_override = dark
	add_child(shell)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.53, 0.6)
	env.ambient_light_energy = 0.55
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
	for l: Array in [[Vector3(-38, -32, 0), Color(1.0, 0.97, 0.92), 1.5], [Vector3(-12, 55, 0), Color(0.7, 0.8, 1.0), 0.55], [Vector3(-25, 165, 0), Color(1.0, 0.9, 0.78), 1.1]]:
		var d := DirectionalLight3D.new()
		d.rotation_degrees = l[0]
		d.light_color = l[1]
		d.light_energy = l[2]
		add_child(d)

func _camera(at: Vector3, dist: float, fov: float = 30.0, from: Vector3 = Vector3(0, 0, 1)) -> Camera3D:
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = fov
	cam.near = 0.02
	cam.position = at + from.normalized() * dist
	cam.look_at(at)
	cam.make_current()
	return cam

func _is_shield(id: String) -> bool:
	return str(GearModel.info(id).get("class", "")) == "shield"

func _spawn(id: String) -> Node3D:
	var n := GearModel.spawn(id, 0.0, args.has("lod"))
	if n == null:
		push_error("gearbench: no such item " + id)
		n = Node3D.new()
	return n

func _single(id: String) -> void:
	var info := GearModel.info(id)
	var lo := _v3(info.get("lo", [0, 0, 0]))
	var hi := _v3(info.get("hi", [0, 1, 0]))
	var mid := (lo + hi) * 0.5
	var shield := _is_shield(id)
	var pivot := Node3D.new()
	add_child(pivot)
	spinner = Node3D.new()
	pivot.add_child(spinner)
	item = _spawn(id)
	spinner.add_child(item)
	var size := (hi - lo).length()
	var focus := mid
	if args.has("focus"):
		var f := str(args.focus).split(",")
		focus = Vector3(float(f[1]) if f.size() > 1 else mid.x, float(f[0]), mid.z if shield else 0.0)
	item.position = -Vector3(mid.x if shield else 0.0, focus.y if not shield else mid.y, mid.z if shield else 0.0)
	var look_at := Vector3.ZERO
	if shield:
		look_at = Vector3(focus.x - mid.x, focus.y - mid.y, 0) if args.has("focus") else Vector3.ZERO
	elif not args.has("upright"):
		pivot.rotation_degrees.z = -90.0
	pivot.rotation_degrees.x = float(args.get("tilt", "0"))
	var fit := size / (0.5 if shield or args.has("upright") else 0.82)
	_camera(look_at, float(args.get("dist", str(fit))))
	if args.has("yaw"):
		_fixed = true
		spinner.rotation_degrees.y = float(args.yaw)
	if args.has("palm") and not shield:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.004, 0.09, 0.004)
		bar.mesh = bm
		bar.material_override = Look.glow(Color(0.3, 1.0, 0.45), 1.0)
		bar.position = Vector3(0.0, 0.0, 0.03)
		item.add_child(bar)
		bar.set_meta("no_recall", true)
	if args.has("recall"):
		_loop = [item]
		_cycle()

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
		add_child(n)
		n.position = Vector3((i - (steps.size() - 1) * 0.5) * gap, -(lo.y + hi.y) * 0.5, 0) - Vector3((lo.x + hi.x) * 0.5, 0, 0)
		n.rotation_degrees.y = float(args.get("yaw", "20"))
		if steps[i] < 1.0:
			Recall.hold(n, steps[i], {"cheap": args.has("cheap")})
		var lab := Label3D.new()
		lab.text = "%.2f" % steps[i]
		lab.pixel_size = 0.0009 * maxf(1.0, (hi.y - lo.y))
		lab.position = Vector3(n.position.x + (lo.x + hi.x) * 0.5, -(hi.y - lo.y) * 0.56, 0)
		lab.modulate = Color(0.6, 0.63, 0.7)
		add_child(lab)
	var w := gap * steps.size()
	_camera(Vector3.ZERO, maxf(w / 0.9, (hi.y - lo.y) / 0.5) * float(args.get("zoom", "1")))

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
		var lab := Label3D.new()
		lab.text = e[2]
		lab.pixel_size = 0.0008
		lab.position = Vector3(0.05, float(e[1]) + (0.17 if float(e[1]) > 0 else 0.09), 0)
		lab.modulate = Color(0.7, 0.73, 0.8)
		add_child(lab)
	_camera(Vector3(float(args.get("focus", "0.06")), 0, 0), float(args.get("dist", "1.42")))
	if args.has("recall"):
		# the effect on a generated model fitted by PropModel as well as on a modelled one
		_loop = [old, new_]
		_cycle()

func _lineup() -> void:
	var xs := [-1.05, -0.72, -0.4, 0.2, 0.95]
	for i in ITEMS.size():
		var n := _spawn(ITEMS[i])
		add_child(n)
		var info := GearModel.info(ITEMS[i])
		var lo := _v3(info.get("lo", [0, 0, 0]))
		var hi := _v3(info.get("hi", [0, 1, 0]))
		if _is_shield(ITEMS[i]):
			n.position = Vector3(xs[i] - (lo.x + hi.x) * 0.5, 0.35 - (lo.y + hi.y) * 0.5, 0)
			n.rotation_degrees.y = 180.0 + float(args.get("yaw", "-25"))
		else:
			n.position = Vector3(xs[i], -0.34 - lo.y, 0)
			n.rotation_degrees.y = float(args.get("yaw", "-25"))
	_camera(Vector3(0, 0.35, 0), 3.3)

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
	look["weapon"] = str(info.get("class", "sword"))
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
	var w := GearModel.spawn(sword_id, 0.0)
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
	if spinner and not _fixed:
		spinner.rotation.y = _t * deg_to_rad(float(args.get("spin", "40")))
