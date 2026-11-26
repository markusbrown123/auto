extends SceneTree
## Bakes the authored animation GLBs in art/anim/ into one compact AnimationLibrary (rotations only, plus
## the hip position), so the game ships the motion without a second copy of the mesh and textures.
## Usage: godot --headless --path . --script tools/bake_anims.gd
const SOURCES := ["art/anim/knight_set_a.glb", "art/anim/knight_set_b.glb"]
const LOOPS := ["idle", "walk", "run"]

func _short(n: String) -> String:
	return n.trim_prefix("mixamorig_").trim_prefix("mixamorig:").trim_prefix("mixamorig")

func _init() -> void:
	var lib := AnimationLibrary.new()
	var rest := {}
	for src in SOURCES:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(src, st) != OK:
			push_error("cannot read " + src)
			continue
		var scene: Node = doc.generate_scene(st)
		get_root().add_child(scene)
		var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		for i in sk.get_bone_count():
			rest[_short(sk.get_bone_name(i))] = sk.get_bone_rest(i)
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		for n in ap.get_animation_list():
			var a: Animation = ap.get_animation(n)
			var out := Animation.new()
			out.length = a.length
			out.loop_mode = Animation.LOOP_LINEAR if LOOPS.has(n) else Animation.LOOP_NONE
			for t in a.get_track_count():
				var bone := _short(str(a.track_get_path(t)).get_slice(":", 1))
				var type := a.track_get_type(t)
				if type == Animation.TYPE_ROTATION_3D:
					var ti := out.add_track(Animation.TYPE_ROTATION_3D)
					out.track_set_path(ti, NodePath("S:" + bone))
					for k in a.track_get_key_count(t):
						out.rotation_track_insert_key(ti, a.track_get_key_time(t, k), a.track_get_key_value(t, k))
				elif type == Animation.TYPE_POSITION_3D and bone == "Hips":
					var ti2 := out.add_track(Animation.TYPE_POSITION_3D)
					out.track_set_path(ti2, NodePath("S:Hips"))
					for k in a.track_get_key_count(t):
						out.position_track_insert_key(ti2, a.track_get_key_time(t, k), a.track_get_key_value(t, k))
			lib.add_animation(n, out)
			# report what the clip does, so stride and travel can be matched in the rig
			ap.play(n)
			var zs: Array = []
			var hip: Array = []
			for i in 13:
				ap.seek(a.length * i / 12.0, true)
				var lf := sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftFoot")).origin
				var hp := sk.get_bone_global_pose(sk.find_bone("mixamorig_Hips")).origin
				zs.append("%.2f" % (lf.z - hp.z))
				hip.append("(%.2f %.2f %.2f)" % [hp.x, hp.y, hp.z])
			print(n, " len=%.2f tracks=%d" % [a.length, out.get_track_count()], "\n  left foot z rel hips: ", " ".join(zs), "\n  hips: ", " ".join(hip))
		scene.queue_free()
	lib.set_meta("rest", rest)
	DirAccess.make_dir_recursive_absolute("res://assets/anim")
	print("save: ", ResourceSaver.save(lib, "res://assets/anim/humanoid.res", ResourceSaver.FLAG_COMPRESS))
	quit()
