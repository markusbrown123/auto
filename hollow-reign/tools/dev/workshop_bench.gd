extends Node3D
## Dev tool: Orren's workshop on its own, a camera on Orren (or the whole room), a still every second while he goes
## through each of his actions in turn (and, with "talk", one of his lines played so the talking can be judged).
## Usage: godot --path . res://tools/dev/workshop_bench.tscn -- <outdir> [orren|wide] [acts, e.g. greet,hammer,inspect,wipe,lean] [talk]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.015, 0.012)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.25, 0.2, 0.17)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var ws := Workshop.new()
	add_child(ws)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 38.0
	var view := a[1] if a.size() > 1 else "orren"
	if view == "wide":
		cam.position = Vector3(1.6, 1.7, 3.2)
		cam.look_at(Vector3(-1.4, 1.1, -3.2))
		cam.fov = 60.0
	else:
		cam.position = Workshop.ORREN_AT + Vector3(0.9, 1.45, 2.3)
		cam.look_at(Workshop.ORREN_AT + Vector3(0, 1.15, 0))
	var acts: Array = Array(a[2].split(",")) if a.size() > 2 else ["greet", "hammer", "inspect", "wipe", "lean"]
	DirAccess.make_dir_recursive_absolute(a[0])
	await get_tree().process_frame
	if a.size() > 3 and a[3] == "talk":
		Story.play("orren_intro", true, true)
	var n := 0
	for act: String in acts:
		ws.orren.set_act(act)
		ws.orren._len = 99.0
		for i in 4:
			for f in 30:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%02d_%s_%d.png" % [a[0], n, act, i])
			n += 1
	get_tree().quit()
