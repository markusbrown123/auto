extends Node3D
## Dev (Stage 1): the awakening chamber from fixed cameras, with the knight lying in the cradle and the sword on its
## holder, and the frame's cost after each shot. Writes <out>/<view>.png.
##   xvfb-run godot --path . --rendering-method mobile res://src/dev/chamber_view.tscn -- --out=<dir> [--views=a,b] [--oldchamber]
##   [--clip=getup --t=0.0] (the knight's held clip and time) [--body=m|f]
const VIEWS := {
	"room": [Vector3(1.6, 2.2, 5.3), Vector3(-0.2, 1.4, -3.5), 56.0],
	"door": [Vector3(-0.6, 1.7, 0.6), Vector3(0.0, 1.8, -6.2), 54.0],
	"cradle": [Vector3(1.9, 1.5, 2.6), Vector3(0.0, 0.4, 0.2), 46.0],
	"face": [Vector3(0.8, 0.45, 2.4), Vector3(0.0, 0.3, -0.3), 40.0],
	"sword": [Vector3(0.6, 1.5, 1.6), Vector3(2.05, 0.9, -0.55), 46.0],
	"housing": [Vector3(-1.2, 1.55, -3.0), Vector3(-2.95, 1.25, -5.1), 46.0],
	"left": [Vector3(2.5, 2.0, 2.0), Vector3(-5.0, 1.8, -1.5), 60.0],
	"right": [Vector3(-2.5, 2.0, 2.4), Vector3(5.0, 1.6, -1.0), 60.0],
	"up": [Vector3(0.5, 1.2, 3.5), Vector3(0.0, 6.0, -1.0), 70.0],
	"passage": [Vector3(0.3, 1.6, -4.0), Vector3(0.0, 1.4, -12.0), 56.0],
}

func _ready() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			args[a.trim_prefix("--").get_slice("=", 0)] = a.get_slice("=", 1) if a.contains("=") else ""
	var out := str(args.get("out", "user://chamber"))
	DirAccess.make_dir_recursive_absolute(out)
	Game.profile = Game.default_profile()
	Game.profile.body = str(args.get("body", "m"))
	Generations.begin(Game.profile, 2)
	var arena := Arena.new()
	add_child(arena)
	arena.build("chamber")
	if args.has("open"):
		Chamber.door_open_now(arena)
		Chamber.seal_open_now(arena)
	else:
		Chamber.lock_door_now(arena)
	var knight: CineActor = null
	if not args.has("noknight"):
		knight = CineActor.new()
		add_child(knight)
		knight.build(Duel.player_look(), false)
		knight.set_armed(false)
		knight.position = Chamber.LIE_AT if not Arena.old_chamber else Awakening.SEAT
		knight.rotation.y = float(args.get("yaw", str(PI)))
		var clip := str(args.get("clip", "getup"))
		knight.hold(clip, 0.0)
		knight._ta = float(args.get("t", "0.0"))
		knight.time_scale = 0.0 if not args.has("play") else 1.0
	var cam := Camera3D.new()
	cam.far = 200.0
	add_child(cam)
	cam.make_current()
	var views: PackedStringArray = str(args.get("views", ",".join(VIEWS.keys()))).split(",")
	for i in 6:
		await get_tree().process_frame
	if knight != null and knight.skin != null:
		var s := knight.skin
		for b: String in ["Hips", "Head", "RightHand", "LeftHand", "LeftFoot", "RightFoot"]:
			var p: Vector3 = s.skel.global_transform * s.skel.get_bone_global_pose(s.bone[b]).origin
			print("bone %s at %s" % [b, p])
	for v: String in views:
		var spec: Array = VIEWS[v]
		cam.position = spec[0]
		cam.look_at(spec[1])
		cam.fov = spec[2]
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, v])
		print("view %s draw_calls=%d primitives=%d objects=%d video_mem=%.1fMB" % [v,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	get_tree().quit()
