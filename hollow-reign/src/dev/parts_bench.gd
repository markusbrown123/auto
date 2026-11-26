class_name PartsBench
extends Node3D
## Dev viewer and measuring bench for modular armour (ArmorParts, docs/MODULAR_ARMOR.md).  --screen=partsbench
##   knights    --body=m --helm=frost --chest=black --shoulders=black --arms=regal --legs=ash --boots=vigil
##              [--set=<suit> default for every slot] [--clip=<name>] [--yaws=0,180] [--cam=full|upper|neck|shoulder|elbow|waist|ankle]
##              [--nounder] [--oldfinish] [--noweapon] [--orig=<suit>: the unsplit suit model on the rig instead] [--tag=_ds]
##   turnaround --turn=<suit> [--split: assembled from its six parts] [--tag=_ds] [--oldfinish]   front, side, back in the rest pose
##   measure    --measure --parts_dir=<dir of parts cut with --margin=0>   prints seam mismatch tables and quits
var args := {}
var rigs: Array = []
var parts: Array = []
var cam: Camera3D
var _focus := ""
var _dist := 6.0

const SEAMS := [["neck", "helm", "chest"], ["shoulder", "chest", "shoulders"], ["elbow", "shoulders", "arms"], ["waist", "chest", "legs"], ["ankle", "legs", "boots"]]
const FOCUS := {"neck": ["Neck", 1.25], "shoulder": ["RightArm", 1.3], "elbow": ["RightForeArm", 1.2], "waist": ["Hips", 1.6], "ankle": ["RightFoot", 1.25], "upper": ["Spine2", 2.9]}

func _ready() -> void:
	_studio()
	if args.has("measure"):
		_measure()
	elif args.has("turn"):
		_turnaround()
	else:
		_knights()

func _studio() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.43, 0.45)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 32, 0)
	key.light_energy = 1.5
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -140, 0)
	fill.light_energy = 0.55
	add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	floor_mi.material_override = Look.flat(Color(0.33, 0.34, 0.36), 0.95)
	add_child(floor_mi)
	cam = Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.position = Vector3(0, 1.05, 6.2)
	cam.make_current()

func _loadout() -> Dictionary:
	var base := str(args.get("set", "base"))
	var tag := str(args.get("tag", ""))
	var out := {}
	for slot: String in ArmorParts.SLOTS:
		var suit := str(args.get(slot, args.get("chest", base) if slot == "shoulders" else base))
		out[slot] = "" if suit == "none" else suit + tag
	return out

func _dress(skel: Skeleton3D, loadout: Dictionary) -> ArmorParts:
	var p := ArmorParts.dress(skel, str(args.get("body", "m")), loadout, {"under": not args.has("nounder"), "finish": not args.has("oldfinish")})
	if args.has("underlime") and p.under:
		(p.under.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("cloth", Color(0.2, 1.0, 0.1))
	return p

# ---------------------------------------------------------------- knights on the game's rig
func _rig(yaw_deg: float, x: float) -> FighterRig:
	var body := str(args.get("body", "m"))
	Game.profile.body = body
	var rig := FighterRig.new()
	add_child(rig)
	var look: Dictionary = Duel.player_look()
	look["skin"] = "res://assets/models/knight_%s%s.glb" % [body, ("_" + str(args.orig)) if args.has("orig") and str(args.orig) != "base" else ""]
	look.erase("skin_tint")
	rig.build(look, false)
	rig.rotation.y = PI + deg_to_rad(yaw_deg)
	rig.position.x = x
	if args.has("clip"):
		rig.test_clip = str(args.clip)
	if args.has("noweapon"):
		for n: Node3D in [rig.weapon_r, rig.weapon_l, rig.shield]:
			if n:
				n.visible = false
	return rig

func _knights() -> void:
	var yaws: PackedStringArray = str(args.get("yaws", "0")).split(",")
	var gap := float(args.get("gap", "1.5"))
	for i in yaws.size():
		var rig := _rig(float(yaws[i]), (i - (yaws.size() - 1) * 0.5) * gap)
		rigs.append(rig)
		if rig.skin and not args.has("orig"):
			var p := _dress(rig.skin.skel, _loadout())
			parts.append(p)
			if i == 0:
				print("partsbench loadout=", p.worn, " cost=", p.cost())
	_focus = str(args.get("cam", "full"))
	_dist = float(args.get("dist", str(4.6 + 1.6 * yaws.size())))

func _process(_dt: float) -> void:
	if rigs.is_empty():
		return
	var rig: FighterRig = rigs[0]
	if FOCUS.has(_focus) and rig.skin:
		var e: Array = FOCUS[_focus]
		var at: Vector3 = rig.skin.skel.global_transform * rig.skin.skel.get_bone_global_pose(rig.skin.bone[e[0]]).origin
		if _focus in ["neck", "waist", "upper"]:
			at.x = rig.global_position.x
		var side := Vector3(0.25, 0.1, 1.0).normalized() if not args.has("camback") else Vector3(-0.25, 0.1, -1.0).normalized()
		cam.fov = 30.0
		cam.global_position = at + side * float(args.get("dist", str(e[1])))
		cam.look_at(at)
	else:
		cam.position = Vector3(0, 1.05, _dist)
		cam.look_at(Vector3(0, 1.0, 0))

# ---------------------------------------------------------------- turnaround (rest pose, three views)
func _turnaround() -> void:
	var body := str(args.get("body", "m"))
	var suit := str(args.turn)
	var split := args.has("split") or args.has("tag")
	var i := 0
	for yaw: float in [-90.0, 0.0, 90.0]:
		var path := "res://assets/models/knight_%s%s.glb" % [body, "" if (split or suit == "base") else "_" + suit]
		var root: Node3D = (load(path) as PackedScene).instantiate()
		add_child(root)
		root.scale = Vector3.ONE * 1.9
		root.rotation_degrees.y = yaw
		root.position.x = (i - 1) * 1.25
		i += 1
		if split:
			var lo := {}
			for slot: String in ArmorParts.SLOTS:
				lo[slot] = str(args.get(slot, suit)) + str(args.get("tag", ""))
			var p := _dress(root.find_children("*", "Skeleton3D", true, false)[0], lo)
			if i == 1:
				print("partsbench turn=", suit, " cost=", p.cost())
		else:
			Look.sanitise(root, "character", true)
			if not args.has("oldfinish"):
				var f := ArmorParts.finish_of(suit)
				for k: String in ["rough_min", "rough_max", "metal_max", "spec"]:
					Look.set_param(root, StringName(k), f[k])
				Look.set_param(root, &"tint", f.tone)
	cam.position = Vector3(0, 0.98, float(args.get("dist", "5.6")))
	cam.look_at(Vector3(0, 0.96, 0))

# ---------------------------------------------------------------- measuring
var _arr := {}

func _ring(body: String, suit: String, slot: String, toward: String, skel: Skeleton3D, from_dir: String = "") -> PackedVector3Array:
	var keep := ArmorParts.dir
	if from_dir != "":
		ArmorParts.dir = from_dir
	var key := "%s%s_%s_%s" % [ArmorParts.dir, body, suit, slot]
	var mesh: ArrayMesh = _arr[key][0] if _arr.has(key) else load("%s%s_%s_%s.res" % [ArmorParts.dir, body, suit, slot])
	ArmorParts.dir = keep
	if not _arr.has(key):
		_arr[key] = [mesh, mesh.surface_get_arrays(0)]
	var a: Array = _arr[key][1]
	var rings: Dictionary = mesh.get_meta("rings", {})
	var out := PackedVector3Array()
	if not rings.has(toward):
		return out
	var skin := ArmorParts.skin_of(body)
	var xf: Array = []
	for b in skin.get_bind_count():
		xf.append(skel.get_bone_global_pose(skel.find_bone(skin.get_bind_name(b))) * skin.get_bind_pose(b))
	var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var s: float = skel.global_transform.basis.get_scale().y * 100.0       # centimetres on the knight as the game scales it
	for v: int in rings[toward]:
		var p := Vector3.ZERO
		for j in 4:
			if weights[v * 4 + j] > 0.0:
				p += (xf[bones[v * 4 + j]] as Transform3D) * pos[v] * weights[v * 4 + j]
		out.append(p * s)
	return out

## [mean distance to the other ring, worst (95th percentile), how far ring A stands outside ring B] in cm.
func _mismatch(a: PackedVector3Array, b: PackedVector3Array) -> Array:
	if a.is_empty() or b.is_empty():
		return [-1.0, -1.0, 0.0]
	var ds: Array = []
	var c := Vector3.ZERO
	for pair: Array in [[a, b], [b, a]]:
		for p: Vector3 in pair[0]:
			var best := 1e9
			for q: Vector3 in pair[1]:
				best = minf(best, p.distance_squared_to(q))
			ds.append(sqrt(best))
			c += p / float(a.size() + b.size())
	ds.sort()
	var mean := 0.0
	for d: float in ds:
		mean += d / ds.size()
	var ra := 0.0
	var rb := 0.0
	for p2: Vector3 in a:
		ra += p2.distance_to(c) / a.size()
	for q2: Vector3 in b:
		rb += q2.distance_to(c) / b.size()
	return [mean, float(ds[int(ds.size() * 0.95)]), ra - rb]

func _seam(body: String, lo: Dictionary, seam: Array, skel: Skeleton3D) -> Array:
	return _mismatch(_ring(body, lo[seam[1]], seam[1], seam[2], skel), _ring(body, lo[seam[2]], seam[2], seam[1], skel))

func _measure() -> void:
	var body := str(args.get("body", "m"))
	ArmorParts.dir = str(args.get("parts_dir", ArmorParts.DIR))
	var rig := _rig(0.0, 0.0)
	rigs.append(rig)
	var skel: Skeleton3D = rig.skin.skel
	var suits: Array = ArmorParts.SUITS
	# the overlap band the shipped parts carry past the true seam line
	print("== body %s: overlap band of the shipped parts past the seam line, cm (mean over suits)" % body)
	var rest_pose := {}
	for i in skel.get_bone_count():
		rest_pose[i] = skel.get_bone_pose(i)
		skel.reset_bone_pose(i)
	for seam: Array in SEAMS:
		var w := 0.0
		for suit: String in suits:
			w += float(_mismatch(_ring(body, suit, seam[1], seam[2], skel), _ring(body, suit, seam[1], seam[2], skel, ArmorParts.DIR))[0]) / suits.size()
			w += float(_mismatch(_ring(body, suit, seam[2], seam[1], skel), _ring(body, suit, seam[2], seam[1], skel, ArmorParts.DIR))[0]) / suits.size()
		print("   %-9s both bands together %.1f cm" % [seam[0], w])
	# every ordered pair of suits at each seam, rest pose
	print("== body %s: seam ring mismatch at rest, every pair of different suits (cm: mean / worst-pair mean / mean of the 95th percentile)" % body)
	var per_suit := {}
	for seam2: Array in SEAMS:
		var sum := 0.0
		var worst := 0.0
		var p95 := 0.0
		var n := 0
		for x: String in suits:
			for y: String in suits:
				if x == y:
					continue
				var r := _mismatch(_ring(body, x, seam2[1], seam2[2], skel), _ring(body, y, seam2[2], seam2[1], skel))
				sum += float(r[0]); p95 += float(r[1]); n += 1
				worst = maxf(worst, float(r[0]))
				for s: String in [x, y]:
					var k := s + "/" + str(seam2[0])
					per_suit[k] = float(per_suit.get(k, 0.0)) + float(r[0]) / (2.0 * (suits.size() - 1))
		print("   %-9s %.1f / %.1f / %.1f" % [seam2[0], sum / n, worst, p95 / n])
	print("== body %s: mean mismatch per suit against all other suits, cm" % body)
	for s2: String in suits:
		var line := "   %-9s" % s2
		for seam3: Array in SEAMS:
			line += " %s %.1f " % [seam3[0], float(per_suit[s2 + "/" + str(seam3[0])])]
		print(line)
	for i2 in skel.get_bone_count():
		skel.set_bone_pose(i2, rest_pose[i2])
	# chosen mixes in motion
	var mixes: Array = [
		{"helm": "frost", "chest": "black", "shoulders": "black", "arms": "regal", "legs": "ash", "boots": "vigil"},
		{"helm": "garrison", "chest": "hollow", "shoulders": "garrison", "arms": "black", "legs": "hollow", "boots": "base"},
		{"helm": "base", "chest": "ash", "shoulders": "wyrm", "arms": "frost", "legs": "garrison", "boots": "black"},
		{"helm": "hollow", "chest": "regal", "shoulders": "vigil", "arms": "ash", "legs": "black", "boots": "garrison"},
		{"helm": "black", "chest": "base", "shoulders": "base", "arms": "garrison", "legs": "base", "boots": "hollow"},
		{"helm": "frost", "chest": "frost", "shoulders": "frost", "arms": "frost", "legs": "frost", "boots": "frost"},
	]
	print("== body %s: chosen mixes in motion (cm, mean ring mismatch: rest-like guard / worst frame of th_overhead / worst frame of ss_walk_f / worst frame of ss_dodge_l)" % body)
	var table := {}
	for pose: String in ["", "th_overhead", "ss_walk_f", "ss_dodge_l"]:
		rig.test_clip = pose
		rig._clock = 0.0
		var frames := 1 if pose == "" else 14
		var span: float = SkinDriver.clip_length(pose) if pose != "" else 0.0
		for fi in frames:
			if pose != "":
				rig._clock = span * (fi + 0.5) / frames
			for w2 in 3:
				await get_tree().process_frame
			for mi in mixes.size():
				for seam4: Array in SEAMS:
					var r2 := _seam(body, mixes[mi], seam4, skel)
					var k2 := "%d/%s/%s" % [mi, seam4[0], pose]
					table[k2] = maxf(float(table.get(k2, 0.0)), float(r2[0]))
	for mi2 in mixes.size():
		var m: Dictionary = mixes[mi2]
		print("   mix %d: helm %s, chest %s, shoulders %s, arms %s, legs %s, boots %s" % [mi2 + 1, m.helm, m.chest, m.shoulders, m.arms, m.legs, m.boots])
		for seam5: Array in SEAMS:
			print("      %-9s %.1f / %.1f / %.1f / %.1f" % [seam5[0], table["%d/%s/" % [mi2, seam5[0]]], table["%d/%s/th_overhead" % [mi2, seam5[0]]],
				table["%d/%s/ss_walk_f" % [mi2, seam5[0]]], table["%d/%s/ss_dodge_l" % [mi2, seam5[0]]]])
	get_tree().quit()
