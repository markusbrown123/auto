extends Node3D
## Dev tool: plays every clip in an animation GLB and saves stills, to see what was actually delivered.
## Usage: godot --path . res://tools/dev/anim_sheet.tscn -- <glb> <outdir>
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(a[0], st)
	var m: Node3D = doc.generate_scene(st)
	add_child(m)
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	var hb := 0
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with("Head"):
			hb = i
	var head_y: float = (sk.global_transform * sk.get_bone_global_rest(hb)).origin.y
	print(sk.get_bone_name(hb), " ", sk.get_bone_name(0))
	print("head at ", head_y, " hips rest ", sk.get_bone_rest(0))
	m.scale *= 1.6 / head_y
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(1.9, 1.2, 2.6)
	cam.look_at(Vector3(0, 0.9, 0))
	var l := DirectionalLight3D.new()
	add_child(l)
	l.rotation_degrees = Vector3(-40, 40, 0)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	g.mesh = pm
	add_child(g)
	DirAccess.make_dir_recursive_absolute(a[1])
	for n in ap.get_animation_list():
		var an := ap.get_animation(n)
		print(n, " len=", an.length, " loop=", an.loop_mode)
		ap.play(n)
		ap.pause()
		for i in 8:
			ap.seek(an.length * i / 8.0, true)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [a[1], n, i])
	get_tree().quit()
