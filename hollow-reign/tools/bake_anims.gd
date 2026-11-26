extends SceneTree
## Bakes skeletal clips from several libraries into one compact, skeleton-independent library.
## Each bone's motion is stored as a model-space rotation away from its rest pose, in a canonical frame
## (character faces -Z, Y up), so any humanoid with the standard bone names can play it whatever its own
## rest pose or bone axes. Output: assets/anim/humanoid.res. Sources live in art/ (not shipped).
## Usage: godot --headless --path . --script tools/bake_anims.gd
##   -- --catalogue=<out.json>   instead of baking, measure every FBX of the bought packs (length, swings) into a JSON file
## The bought Game Dev Hero packs (FBX, Mixamo skeleton) are read straight from art/anim_src/gamedevhero/ (git-ignored:
## the licence forbids passing the source files on). Which of their clips are baked, and under what names, is listed in
## tools/anim_pack_clips.json. For those clips the tool also measures each swing of the right-hand blade and writes
## assets/anim/clip_meta.json (see docs/ANIMATION_LIBRARY.md).
const FPS := 30.0
const BONES := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
	"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand",
	"LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]
const CHILD := {"LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand",
	"LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "LeftFoot": "LeftToeBase", "RightUpLeg": "RightLeg", "RightLeg": "RightFoot", "RightFoot": "RightToeBase",
	"Hips": "Spine", "Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head"}
## Hands: only where the source has Mixamo finger bones (the bought packs). Lets a player line its own rest hand up with the source's.
const HAND_CHILD := {"LeftHand": "LeftHandMiddle1", "RightHand": "RightHandMiddle1"}
const GDH := "art/anim_src/gamedevhero/"
## pack prefix -> [folder of in-place clips, file name prefix]
const PACKS := {
	"ss": ["SwordShieldV3/SwordShieldV3_Mixamo/IP/", "A_SwordSwordAnimV3_"],
	"th": ["TwoHandedSwordAnimationV3/TwoHandedSwordAnimationV3_Mixamo/IP/", "AS_TwoHandedSwordAnimV3_"],
	"dw": ["DualSwordAnimationV1/DualSwordAnimationV1_Mixamo/IP/", "AS_DualSwordAnimV1_"],
}
const PACK_LIST := "res://tools/anim_pack_clips.json"
const META_OUT := "res://assets/anim/clip_meta.json"
const BLADE := 0.85           # blade length used for measuring swings, in hip heights
const UAL := {"Hips": "pelvis", "Spine": "spine_01", "Spine1": "spine_02", "Spine2": "spine_03", "Neck": "neck_01", "Head": "Head",
	"LeftShoulder": "clavicle_l", "LeftArm": "upperarm_l", "LeftForeArm": "lowerarm_l", "LeftHand": "hand_l",
	"RightShoulder": "clavicle_r", "RightArm": "upperarm_r", "RightForeArm": "lowerarm_r", "RightHand": "hand_r",
	"LeftUpLeg": "thigh_l", "LeftLeg": "calf_l", "LeftFoot": "foot_l", "LeftToeBase": "ball_l",
	"RightUpLeg": "thigh_r", "RightLeg": "calf_r", "RightFoot": "foot_r", "RightToeBase": "ball_r"}
const EXP := {"Hips": "B_Pelvis", "Spine": "B_Spine", "Spine1": "B_Spine1", "Spine2": "B_Spine2", "Neck": "B_Neck", "Head": "B_Head",
	"LeftShoulder": "B_L_Clavicle", "LeftArm": "B_L_UpperArm", "LeftForeArm": "B_L_Forearm", "LeftHand": "B_L_Hand",
	"RightShoulder": "B_R_Clavicle", "RightArm": "B_R_UpperArm", "RightForeArm": "B_R_Forearm", "RightHand": "B_R_Hand",
	"LeftUpLeg": "B_L_Thigh", "LeftLeg": "B_L_Calf", "LeftFoot": "B_L_Foot", "LeftToeBase": "B_L_Toe0",
	"RightUpLeg": "B_R_Thigh", "RightLeg": "B_R_Calf", "RightFoot": "B_R_Foot", "RightToeBase": "B_R_Toe0"}
const U1 := "art/anim_src/quaternius_ual1/extracted/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb"
const U2 := "art/anim_src/quaternius_ual2/extracted/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb"
const EX := "art/anim_src/explosive_rpg_free/extracted/Unarmed.glb"
## source file -> [bone map ("" = Mixamo names), {clip in file: [name in game, loops]}]
var SOURCES := {
	"art/anim/knight_set_b.glb": ["", {"fall": ["fall", false], "dive": ["dive", false], "hurt": ["wounded", true]}],
	U1: ["ual", {"Walk_Loop": ["walk", true], "Jog_Fwd_Loop": ["jog", true], "Sprint_Loop": ["sprint", true], "Idle_Loop": ["idle", true],
		"Sword_Idle": ["sword_idle", true], "Sword_Attack": ["sword_attack", false], "Roll": ["roll_fwd", false], "Death01": ["death", false],
		"Hit_Chest": ["hit_chest", false], "Hit_Head": ["hit_head", false]}],
	U2: ["ual", {"Sword_Regular_A": ["cut_a", false], "Sword_Regular_A_Rec": ["cut_a_rec", false], "Sword_Regular_B": ["cut_b", false], "Sword_Regular_B_Rec": ["cut_b_rec", false],
		"Sword_Regular_C": ["cut_c", false], "Sword_Regular_Combo": ["combo3", false], "Sword_Heavy_Combo": ["heavy_combo", false], "Sword_Dash": ["lunge", false],
		"Sword_Block": ["sword_block", false], "Idle_Shield_Loop": ["shield_idle", true], "Shield_OneShot": ["shield_bash", false], "Shield_Dash": ["shield_dash", false],
		"Idle_Shield_Break": ["guard_break", false], "Hit_Knockback": ["knockback", false]}],
	EX: ["exp", {"UnarmedRollLeft": ["roll_l", false], "UnarmedRollRight": ["roll_r", false], "UnarmedRollBackward": ["roll_back", false],
		"UnarmedDodgeLeft": ["step_l", false], "UnarmedDodgeRight": ["step_r", false], "UnarmedDodgeBackward": ["step_back", false],
		"UnarmedGetHitF1": ["hit_f", false], "UnarmedGetHitB1": ["hit_b", false], "UnarmedGetHitL1": ["hit_l", false], "UnarmedGetHitR1": ["hit_r", false],
		"UnarmedStunned": ["stunned", true], "UnarmedBlockGetHit1": ["block_hit", false], "UnarmedKnockdown1": ["knockdown", false], "UnarmedDeath1": ["death_b", false]}],
}

func _to_root(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != root and c != null:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

func _open(src: String) -> Node:
	var fbx := src.get_extension().to_lower() == "fbx"
	var doc: GLTFDocument = FBXDocument.new() if fbx else GLTFDocument.new()
	var st: GLTFState = FBXState.new() if fbx else GLTFState.new()
	if doc.append_from_file(src, st) != OK:
		push_error("cannot read " + src)
		return null
	return doc.generate_scene(st)

## Everything about a source skeleton that does not change from clip to clip.
func _prepare(scene: Node, kind: String, src: String) -> Dictionary:
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var model: Transform3D = _to_root(sk, scene)
	# which skeleton bone plays each standard bone
	var idx := {}
	for b: String in BONES:
		var want_name: String = b if kind == "" else (UAL[b] if kind == "ual" else EXP[b])
		for i in sk.get_bone_count():
			var n := sk.get_bone_name(i)
			var bare := n.trim_prefix("mixamorig_").trim_prefix("mixamorig:").trim_prefix("mixamorig")
			if (kind == "" and bare == want_name) or (kind != "" and n == want_name):
				idx[b] = i
		if not idx.has(b):
			push_error("%s lacks %s" % [src, b])
	# rest pose in model space, and the turn that makes this model face -Z
	var rest_g := {}
	for b: String in BONES:
		rest_g[b] = model * sk.get_bone_global_rest(idx[b])
	var toe: Vector3 = rest_g["LeftToeBase"].origin - rest_g["LeftFoot"].origin
	var canon := Basis(Vector3.UP, atan2(toe.x, toe.z) * -1.0 + PI)      # rotates the model's forward onto -Z
	if (canon * Vector3(toe.x, 0, toe.z).normalized()).z > -0.9:
		canon = Basis(Vector3.UP, -(atan2(toe.x, toe.z) * -1.0 + PI))
	var rest_dir := {}
	for b: String in CHILD:
		rest_dir[b] = (canon * (rest_g[CHILD[b]].origin - rest_g[b].origin)).normalized()
	# blade axis of each hand at rest (across the palm toward the index finger, as SkinDriver.hand_axis has it)
	var blade := {}
	if kind == "":
		for side: String in ["Left", "Right"]:
			var mid := sk.find_bone(side + "HandMiddle1")
			var ind := sk.find_bone(side + "HandIndex1")
			var pin := sk.find_bone(side + "HandPinky1")
			if mid >= 0:
				rest_dir[side + "Hand"] = (canon * ((model * sk.get_bone_global_rest(mid)).origin - rest_g[side + "Hand"].origin)).normalized()
			if ind >= 0 and pin >= 0:
				blade[side] = (canon * ((model * sk.get_bone_global_rest(ind)).origin - (model * sk.get_bone_global_rest(pin)).origin)).normalized()
	return {"sk": sk, "ap": ap, "model": model, "idx": idx, "rest_g": rest_g, "canon": canon, "hip_h": rest_g["Hips"].origin.y, "rest_dir": rest_dir, "blade": blade}

## One clip -> [baked Animation, samples]. Samples (canonical frame, hip heights): t, hand_r, hand_l, tip_r, tip_l, hip.
func _bake(c: Dictionary, a: Animation, loops: bool, from: float = 0.0, to: float = -1.0) -> Array:
	var sk: Skeleton3D = c.sk
	var model: Transform3D = c.model
	var canon: Basis = c.canon
	var idx: Dictionary = c.idx
	var rest_g: Dictionary = c.rest_g
	var hip_h: float = c.hip_h
	# per-bone local tracks in the source clip
	var rot_t := {}
	var pos_t := {}
	for t in a.get_track_count():
		var bi := sk.find_bone(str(a.track_get_path(t)).get_slice(":", 1))
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			rot_t[bi] = t
		elif a.track_get_type(t) == Animation.TYPE_POSITION_3D:
			pos_t[bi] = t
	var span := (a.length if to < 0.0 else minf(to, a.length)) - from      # (a part of a clip: one cut out of a longer chain)
	var out := Animation.new()
	out.length = span
	out.loop_mode = Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE
	out.set_meta("rest_dir", c.rest_dir)
	var tracks := {}
	for b: String in BONES:
		var ti := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(ti, NodePath("S:" + b))
		tracks[b] = ti
	var pt := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(pt, NodePath("S:Hips"))
	var steps := maxi(1, int(ceil(span * FPS)))
	var hip0 := Vector3.ZERO
	var sm := {"t": [], "hand_r": [], "hand_l": [], "tip_r": [], "tip_l": [], "hip": []}
	for s in steps + 1:
		var time := minf(span, s / FPS)
		var st := from + time      # time in the source clip
		# global pose of every bone at this instant, composed by hand
		var g: Array = []
		g.resize(sk.get_bone_count())
		for i in sk.get_bone_count():
			var l := sk.get_bone_rest(i)
			if rot_t.has(i):
				l.basis = Basis(a.rotation_track_interpolate(rot_t[i], st)) * Basis.from_scale(l.basis.get_scale())
			if pos_t.has(i):
				l.origin = a.position_track_interpolate(pos_t[i], st)
			var par := sk.get_bone_parent(i)
			g[i] = (g[par] * l) if par >= 0 else l
		var turn := {}
		for b: String in BONES:
			var gp: Transform3D = model * (g[idx[b]] as Transform3D)
			var d: Basis = gp.basis.orthonormalized() * (rest_g[b] as Transform3D).basis.orthonormalized().inverse()
			var q := (canon * d * canon.inverse()).get_rotation_quaternion()
			turn[b] = q
			out.rotation_track_insert_key(tracks[b], time, q)
		var hp: Vector3 = canon * (model * (g[idx["Hips"]] as Transform3D)).origin / hip_h
		if s == 0:
			hip0 = hp
		# x,z: travel from the first frame, in hip heights; y: hip height as a fraction of standing height
		out.position_track_insert_key(pt, time, Vector3(hp.x - hip0.x, hp.y, hp.z - hip0.z))
		sm.t.append(time)
		sm.hip.append(Vector3(hp.x - hip0.x, hp.y, hp.z - hip0.z))
		for side: String in ["Left", "Right"]:
			var k := "r" if side == "Right" else "l"
			var h: Vector3 = canon * (model * (g[idx[side + "Hand"]] as Transform3D)).origin / hip_h
			sm["hand_" + k].append(h)
			if c.blade.has(side):
				sm["tip_" + k].append(h + (turn[side + "Hand"] as Quaternion) * (c.blade[side] as Vector3) * BLADE)
	return [out, sm]

func _speed(p: Array, t: Array) -> Array:
	var raw: Array = []
	for i in p.size():
		var a := maxi(i - 1, 0)
		var b := mini(i + 1, p.size() - 1)
		raw.append(((p[b] as Vector3) - (p[a] as Vector3)).length() / maxf(float(t[b]) - float(t[a]), 0.001))
	var v: Array = []
	for i in raw.size():
		v.append((float(raw[maxi(i - 1, 0)]) + float(raw[i]) * 2.0 + float(raw[mini(i + 1, raw.size() - 1)])) / 4.0)
	return v

func _r(x: float) -> float:
	return snappedf(x, 0.01)

## The cut a swing reads as, from where its blade tip goes. x: to the fighter's own right, y: up, z: toward the opponent.
func _label(d: Vector3) -> String:
	if d.z > 0.8:
		return "thrust"
	var ang := rad_to_deg(atan2(d.y, d.x))
	return ["R", "UR", "U", "UL", "L", "DL", "D", "DR"][posmod(int(round(ang / 45.0)), 8)]

## Each cut of a blade: the stretch in which the tip is out in front of the body and moving fast (a fast move with the
## blade beside or behind the body is a wind-up or a return, not a cut). start: the blade begins to move toward the cut;
## contact: the tip is fastest while in front; end: the blade has slowed again; dir: which way the tip goes while in front.
const REACH := 0.6            # hip heights the tip must be ahead of the hips to count as in front
const OVERHEAD := 1.9         # ... and no higher than this (hip heights; a head is at about 1.75): above it the blade is being carried round, not cutting
func _swings(sm: Dictionary, k: String) -> Array:
	var tip: Array = sm["tip_" + k]
	var t: Array = sm.t
	if tip.size() < 5:
		return []
	var v := _speed(tip, t)
	var hv := _speed(sm["hand_" + k], t)
	var front: Array = []
	var fwd: Array = []
	var top := 0.0
	for i in v.size():
		var f: float = -((tip[i] as Vector3).z - (sm.hip[i] as Vector3).z)
		fwd.append(f)
		front.append(f > REACH and (tip[i] as Vector3).y < OVERHEAD and float(v[i]) > 6.0)
		if front[i]:
			top = maxf(top, v[i])
	var hits: Array = []
	var i := 0
	while i < v.size():
		if not front[i]:
			i += 1
			continue
		var j := i
		while j + 1 < v.size() and (front[j + 1] or (j + 2 < v.size() and front[j + 2]) or (j + 3 < v.size() and front[j + 3])):
			j += 1
		var pk := i
		for q in range(i, j + 1):
			if float(v[q]) > float(v[pk]):
				pk = q
		if j - i >= 1 and float(v[pk]) >= maxf(10.0, top * 0.45):
			var a := pk
			while a > 0 and float(v[a]) > float(v[pk]) * 0.25:
				a -= 1
			var b := pk
			while b < v.size() - 1 and float(v[b]) > float(v[pk]) * 0.25:
				b += 1
			var dir := Vector3.ZERO
			for q in range(i, mini(j + 1, v.size() - 1)):
				dir += ((tip[q + 1] as Vector3) - (tip[q] as Vector3)) * float(v[q])
			dir = dir.normalized()
			var own := Vector3(dir.x, dir.y, -dir.z)
			var hp := a
			for q in range(a, b + 1):
				if float(hv[q]) > float(hv[hp]):
					hp = q
			var at: Vector3 = (tip[pk] as Vector3) - (sm.hip[pk] as Vector3) * Vector3(1, 0, 1)
			if not hits.is_empty() and float(t[a]) < float(hits[-1].end):
				a = mini(pk, int(round(float(hits[-1].end) * FPS)))
			hits.append({"start": _r(t[a]), "contact": _r(t[pk]), "end": _r(t[b]), "front": [_r(t[i]), _r(t[j])], "hand_peak": _r(t[hp]), "tip_speed": _r(v[pk]),
				"dir": [_r(own.x), _r(own.y), _r(own.z)], "swipe": _label(own), "at": [_r(at.x), _r(at.y), _r(-at.z)]})
		i = j + 1
	# thrusts: the point is driven out ahead of the body without the tip ever being fast across it
	for q in range(2, fwd.size() - 1):
		if float(fwd[q]) < 1.1 or float(fwd[q]) < float(fwd[q - 1]) or float(fwd[q]) <= float(fwd[q + 1]) or absf((tip[q] as Vector3).x - (sm.hip[q] as Vector3).x) > 0.7:
			continue
		var a2 := q
		while a2 > 0 and float(fwd[a2 - 1]) < float(fwd[a2]) and q - a2 < 18:
			a2 -= 1
		var rise: float = float(fwd[q]) - float(fwd[a2])
		if rise < 0.5:
			continue
		var c2 := a2
		while float(fwd[c2]) < float(fwd[a2]) + rise * 0.9:
			c2 += 1
		var clash := false
		for h: Dictionary in hits:
			if float(t[q]) >= float(h.start) - 0.1 and float(t[a2]) <= float(h.end) + 0.1:
				clash = true
		if clash:
			continue
		var d2: Vector3 = ((tip[q] as Vector3) - (tip[a2] as Vector3)).normalized()
		var at2: Vector3 = (tip[c2] as Vector3) - (sm.hip[c2] as Vector3) * Vector3(1, 0, 1)
		hits.append({"start": _r(t[a2]), "contact": _r(t[c2]), "end": _r(t[q]), "front": [_r(t[c2]), _r(t[q])], "hand_peak": _r(t[c2]), "tip_speed": _r(v[c2]),
			"dir": [_r(d2.x), _r(d2.y), _r(-d2.z)], "swipe": "thrust", "at": [_r(at2.x), _r(at2.y), _r(-at2.z)]})
	hits.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.contact) < float(y.contact))
	# cuts that run into one another (a spin, a flurry): each ends where the next one comes in front, and starts where the last left it
	for n in range(1, hits.size()):
		var prev: Dictionary = hits[n - 1]
		var cur: Dictionary = hits[n]
		prev.end = _r(clampf(prev.end, prev.front[1], maxf(prev.front[1], cur.front[0])))
		cur.start = _r(clampf(cur.start, minf(prev.front[1], cur.front[0]), cur.front[0]))
	return hits

func _measure(sm: Dictionary, length: float, after: float = 0.0) -> Dictionary:
	var m := {"length": _r(length), "frames": int(round(length * FPS))}
	var far := 0.0
	for h: Vector3 in sm.hip:
		far = maxf(far, Vector2(h.x, h.z).length())
	m["hip_travel"] = _r(far)
	var hr := _swings(sm, "r").filter(func(h: Dictionary) -> bool: return float(h.contact) >= after)      # (a back-swing that passes in front is not a cut)
	var hl := _swings(sm, "l").filter(func(h: Dictionary) -> bool: return float(h.contact) >= after)
	if not hr.is_empty():
		m["hits"] = hr
		m["windup"] = hr[0].start
		m["contact"] = hr[0].contact
		m["recovery"] = _r(length - float(hr[-1].end))
		m["swipe"] = hr[0].swipe
	if not hl.is_empty():
		m["hits_left"] = hl
	return m

func _catalogue(out_path: String) -> void:
	var res := {}
	for pre: String in PACKS:
		for sub: String in ["IP", "RM"]:
			var dir: String = GDH + (PACKS[pre][0] as String).replace("/IP/", "/" + sub + "/")
			var files := Array(DirAccess.get_files_at(dir))
			files.sort()
			var c := {}
			for f: String in files:
				if f.get_extension().to_lower() != "fbx":
					continue
				var scene := _open(dir + f)
				if scene == null:
					continue
				if c.is_empty():
					c = _prepare(scene, "", f)
				else:
					# same skeleton in every file of a pack: keep the measured rest, take this file's nodes
					c.sk = scene.find_children("*", "Skeleton3D", true, false)[0]
					c.ap = scene.find_children("*", "AnimationPlayer", true, false)[0]
				var ap: AnimationPlayer = c.ap
				var a: Animation = ap.get_animation(ap.get_animation_list()[0])
				var sm: Dictionary = _bake(c, a, false)[1]
				var m := _measure(sm, a.length)
				if sub == "IP" and f.contains("Attack") and not f.contains("React"):
					# the blade tip's path, for plotting: [right, up, toward the opponent]
					var path: Array = []
					for p: Vector3 in sm.tip_r:
						path.append([_r(p.x), _r(p.y), _r(-p.z)])
					m["tip_path"] = path
				res["%s/%s/%s" % [pre, sub, f.trim_prefix(PACKS[pre][1]).get_basename()]] = m
				scene.free()
			print(pre, " ", sub, " ", files.size())
	var fa := FileAccess.open(out_path, FileAccess.WRITE)
	fa.store_string(JSON.stringify(res, " "))
	fa.close()

func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--catalogue="):
			_catalogue(arg.get_slice("=", 1))
			quit()
			return
	var lib := AnimationLibrary.new()
	for src: String in SOURCES:
		var kind: String = SOURCES[src][0]
		var want: Dictionary = SOURCES[src][1]
		var scene := _open(src)
		if scene == null:
			continue
		var c := _prepare(scene, kind, src)
		c.rest_dir.erase("LeftHand")      # (the first libraries were baked without hand rest directions; kept so)
		c.rest_dir.erase("RightHand")
		var ap: AnimationPlayer = c.ap
		for clip: String in want:
			if not ap.has_animation(clip):
				push_error("%s has no clip %s" % [src, clip])
				continue
			var a: Animation = ap.get_animation(clip)
			lib.add_animation(want[clip][0], _bake(c, a, want[clip][1])[0])
			print("%-12s %5.2fs  from %s" % [want[clip][0], a.length, src.get_file()])
		scene.free()
	# the bought packs: one clip per FBX file
	var meta := {}
	var list: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK_LIST))
	for name: String in list:
		var e: Dictionary = list[name]
		var pre: String = name.get_slice("_", 0)
		var sub := "RM" if bool(e.get("rm", false)) else "IP"      # some moves exist only with root motion
		var src: String = GDH + (PACKS[pre][0] as String).replace("/IP/", "/" + sub + "/") + PACKS[pre][1] + e.src + "_" + sub + ".FBX"
		var scene := _open(src)
		if scene == null:
			continue
		var c := _prepare(scene, "", src)
		var ap: AnimationPlayer = c.ap
		var a: Animation = ap.get_animation(ap.get_animation_list()[0])
		var r := _bake(c, a, bool(e.get("loop", false)), float(e.get("from", 0.0)), float(e.get("to", -1.0)))
		var baked: Animation = r[0]
		lib.add_animation(name, baked)
		var m := _measure(r[1], baked.length, float(e.get("after", 0.0)))
		if pre == "th":
			m.erase("hits_left")      # (both hands are on the one sword)
		if e.has("from") or e.has("to"):
			m["source_range"] = [float(e.get("from", 0.0)), _r(float(e.get("from", 0.0)) + baked.length)]
		m["root_motion"] = sub == "RM"
		m["kind"] = e.kind
		m["pack"] = pre
		m["source"] = src.get_file()
		m["loop"] = bool(e.get("loop", false))
		for k: String in ["chain", "stage", "note", "seen", "use_for"]:
			if e.has(k):
				m[k] = e[k]
		if not ["attack", "combo", "finisher", "shield_attack"].has(e.kind):
			for k: String in ["hits", "hits_left", "windup", "contact", "recovery", "swipe"]:
				m.erase(k)
		meta[name] = m
		print("%-18s %5.2fs  from %s" % [name, baked.length, src.get_file()])
		scene.free()
	DirAccess.make_dir_recursive_absolute("res://assets/anim")
	var fa := FileAccess.open(META_OUT, FileAccess.WRITE)
	fa.store_string(JSON.stringify({"fps": FPS, "frame": "dir = [to the fighter's own right, up, toward the opponent]; times in seconds from the clip's start", "clips": meta}, " "))
	fa.close()
	print("save: ", ResourceSaver.save(lib, "res://assets/anim/humanoid.res", ResourceSaver.FLAG_COMPRESS), "  clips: ", lib.get_animation_list().size())
	quit()
