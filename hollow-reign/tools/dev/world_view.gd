extends Node3D
## Dev tool: builds one duel arena with no fighters and saves stills from given cameras, to look at a region's
## scenery from every side. Usage: tools/dev/world_view.sh --theme=courtyard --out=<dir> [--quality=0]
##   [--cams="x,y,z,lx,ly,lz;..."]  (default: the duel's opening view, its reverse, both sides and a high one)
var _cams: Array = []
var _out := "shots/world_view"
var _theme := "courtyard"
var _cam: Camera3D
var _i := 0
var _wait := 0

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--theme="):
			_theme = a.get_slice("=", 1)
		elif a.begins_with("--out="):
			_out = a.get_slice("=", 1)
		elif a.begins_with("--quality="):
			Game.settings.quality = int(a.get_slice("=", 1))
			Game.apply_settings()
		elif a.begins_with("--cams="):
			for c: String in a.get_slice("=", 1).split(";"):
				var v := c.split_floats(",")
				_cams.append([Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5])])
	if _cams.is_empty():
		_cams = [[Vector3(1.6, 1.5, 5.6), Vector3(-0.4, 1.3, -2.0)], [Vector3(-1.6, 1.5, -5.6), Vector3(0.4, 1.3, 2.0)],
			[Vector3(5.8, 1.4, 0.8), Vector3(-2.0, 1.4, -0.6)], [Vector3(-5.8, 1.4, -0.8), Vector3(2.0, 1.4, 0.6)], [Vector3(0, 9.0, 13.0), Vector3(0, 1.0, -4.0)]]
	DirAccess.make_dir_recursive_absolute(_out)
	var arena := Arena.new()
	add_child(arena)
	arena.build(_theme)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.far = 120.0
	add_child(_cam)
	_cam.make_current()
	_place()

func _place() -> void:
	_cam.position = _cams[_i][0]
	_cam.look_at(_cams[_i][1])
	_wait = 12

func _process(_d: float) -> void:
	_wait -= 1
	if _wait > 0:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [_out, _theme, _i])
	print("%s cam %d draw_calls=%d primitives=%d video_mem=%.1fMB" % [_theme, _i, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	_i += 1
	if _i >= _cams.size():
		get_tree().quit()
		set_process(false)
		return
	_place()
