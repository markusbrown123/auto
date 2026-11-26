extends SceneTree
## Bakes skeletal clips from several libraries into one compact, skeleton-independent library.
## Each bone's motion is stored as a model-space rotation away from its rest pose, in a canonical frame
## (character faces -Z, Y up), so any humanoid with the standard bone names can play it whatever its own
## rest pose or bone axes. Output: assets/anim/humanoid.res. Sources live in art/ (not shipped).
## Usage: godot --headless --path . --script tools/bake_anims.gd
const FPS := 30.0
const BONES := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
	"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand",
	"LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]
const CHILD := {"LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand",
	"LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "LeftFoot": "LeftToeBase", "RightUpLeg": "RightLeg", "RightLeg": "RightFoot", "RightFoot": "RightToeBase",
	"Hips": "Spine", "Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head"}
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

func _init() -> void:
	var lib := AnimationLibrary.new()
	for src: String in SOURCES:
		var kind: String = SOURCES[src][0]
		var want: Dictionary = SOURCES[src][1]
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(src, st) != OK:
			push_error("cannot read " + src)
			continue
		var scene: Node = doc.generate_scene(st)
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
		var hip_h: float = rest_g["Hips"].origin.y
		var rest_dir := {}
		for b: String in CHILD:
			rest_dir[b] = (canon * (rest_g[CHILD[b]].origin - rest_g[b].origin)).normalized()
		for clip: String in want:
			if not ap.has_animation(clip):
				push_error("%s has no clip %s" % [src, clip])
				continue
			var a: Animation = ap.get_animation(clip)
			# per-bone local tracks in the source clip
			var rot_t := {}
			var pos_t := {}
			for t in a.get_track_count():
				var bi := sk.find_bone(str(a.track_get_path(t)).get_slice(":", 1))
				if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
					rot_t[bi] = t
				elif a.track_get_type(t) == Animation.TYPE_POSITION_3D:
					pos_t[bi] = t
			var out := Animation.new()
			out.length = a.length
			out.loop_mode = Animation.LOOP_LINEAR if want[clip][1] else Animation.LOOP_NONE
			out.set_meta("rest_dir", rest_dir)
			var tracks := {}
			for b: String in BONES:
				var ti := out.add_track(Animation.TYPE_ROTATION_3D)
				out.track_set_path(ti, NodePath("S:" + b))
				tracks[b] = ti
			var pt := out.add_track(Animation.TYPE_POSITION_3D)
			out.track_set_path(pt, NodePath("S:Hips"))
			var steps := maxi(1, int(ceil(a.length * FPS)))
			var hip0 := Vector3.ZERO
			for s in steps + 1:
				var time := minf(a.length, s / FPS)
				# global pose of every bone at this instant, composed by hand
				var g: Array = []
				g.resize(sk.get_bone_count())
				for i in sk.get_bone_count():
					var l := sk.get_bone_rest(i)
					if rot_t.has(i):
						l.basis = Basis(a.rotation_track_interpolate(rot_t[i], time)) * Basis.from_scale(l.basis.get_scale())
					if pos_t.has(i):
						l.origin = a.position_track_interpolate(pos_t[i], time)
					var par := sk.get_bone_parent(i)
					g[i] = (g[par] * l) if par >= 0 else l
				for b: String in BONES:
					var gp: Transform3D = model * (g[idx[b]] as Transform3D)
					var d: Basis = gp.basis.orthonormalized() * (rest_g[b] as Transform3D).basis.orthonormalized().inverse()
					out.rotation_track_insert_key(tracks[b], time, (canon * d * canon.inverse()).get_rotation_quaternion())
				var hp: Vector3 = canon * (model * (g[idx["Hips"]] as Transform3D)).origin / hip_h
				if s == 0:
					hip0 = hp
				# x,z: travel from the first frame, in hip heights; y: hip height as a fraction of standing height
				out.position_track_insert_key(pt, time, Vector3(hp.x - hip0.x, hp.y, hp.z - hip0.z))
			lib.add_animation(want[clip][0], out)
			print("%-12s %5.2fs  from %s" % [want[clip][0], a.length, src.get_file()])
		scene.free()
	DirAccess.make_dir_recursive_absolute("res://assets/anim")
	print("save: ", ResourceSaver.save(lib, "res://assets/anim/humanoid.res", ResourceSaver.FLAG_COMPRESS), "  clips: ", lib.get_animation_list().size())
	quit()
