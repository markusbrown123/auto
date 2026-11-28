extends Node3D
## Dev tool: a foe exactly as the story scenes and the duel dress it (CineActor.foe_look), turned to the camera,
## photographed standing, in guard and mid-swing from three sides. For judging a character model before and after a fix.
## Usage: godot --path . res://tools/dev/foe_bench.tscn -- <foe_id> <outdir> [skin glb under assets/models, no extension, or -]
##        [poses: all | guard,swing,seat,die]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var look: Dictionary = CineActor.foe_look(a[0])
	if a.size() > 2 and a[2] != "-":
		look["skin"] = "res://assets/models/%s.glb" % a[2]
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.17, 0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.58)
	add_child(env)
	var l := DirectionalLight3D.new()
	add_child(l)
	l.rotation_degrees = Vector3(-35, 30, 0)
	l.light_energy = 1.3
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	g.mesh = pm
	add_child(g)
	var rig := CineActor.new()
	add_child(rig)
	rig.build(look, true)
	rig.rotation.y = PI
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40.0
	var h := 1.95 * float(look.get("scale", 1.0))
	DirAccess.make_dir_recursive_absolute(a[1])
	var views := {"front": Vector3(0, h * 0.55, h * 2.0), "three": Vector3(h * 1.4, h * 0.6, h * 1.4), "side": Vector3(h * 2.0, h * 0.55, 0), "back": Vector3(0, h * 0.6, -h * 2.0)}
	var poses := ["guard", "swing", "seat", "die"] if a.size() <= 3 or a[3] == "all" else a[3].split(",")
	for pose: String in poses:
		match pose:
			"swing":
				rig.swing(Vector2(1, 0), 0.6)
			"seat":
				var seat := CineSeat.make(rig, 0.6 * rig.scale.y)
				seat.amount = 1.0
			"die":
				for c in rig.get_children():
					if c is CineSeat:
						c.queue_free()
				rig.die(1.0)
				for i in 90:
					await get_tree().process_frame
		for k: String in views:
			cam.position = views[k]
			cam.look_at(Vector3(0, h * (0.2 if pose == "die" else 0.5), 0))
			for i in (24 if k == "front" else 2):
				await get_tree().process_frame
			if pose == "swing" and k != "front":
				continue
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [a[1], pose, k])
	get_tree().quit()
