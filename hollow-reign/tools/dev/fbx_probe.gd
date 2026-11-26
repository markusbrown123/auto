extends SceneTree
## dev: print what one FBX holds (skeleton, rest, clips). Usage: godot --headless --path . --script tools/dev/fbx_probe.gd -- <file.fbx>
func _init() -> void:
	var p: String = OS.get_cmdline_user_args()[0]
	var doc := FBXDocument.new()
	var st := FBXState.new()
	print("read: ", doc.append_from_file(p, st))
	var scene: Node = doc.generate_scene(st)
	scene.print_tree_pretty()
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var t := Transform3D.IDENTITY
	var c: Node = sk
	while c != scene and c != null:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	print("skel to root: ", t)
	for i in sk.get_bone_count():
		print(i, " ", sk.get_bone_name(i), " par=", sk.get_bone_parent(i), " rest_g=", (t * sk.get_bone_global_rest(i)).origin, " scale=", sk.get_bone_rest(i).basis.get_scale())
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	for n in ap.get_animation_list():
		var a := ap.get_animation(n)
		print("clip '", n, "' len=", a.length, " tracks=", a.get_track_count())
		for ti in a.get_track_count():
			print("   ", a.track_get_path(ti), " type=", a.track_get_type(ti), " keys=", a.track_get_key_count(ti))
	quit()
