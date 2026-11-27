extends Node3D
## Dev: the high road's landmarks from a free camera. xvfb-run godot --path . res://src/dev/sights_view.tscn -- --out=<dir> [--quality=0]
## Writes fall.png, tether.png, colossus.png, bridge.png (camera positions are placed from the road's own coordinates).
func _ready() -> void:
	var out := "user://sights"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		if a.begins_with("--quality="):
			Game.settings.quality = int(a.trim_prefix("--quality="))
	DirAccess.make_dir_recursive_absolute(out)
	var arena := Arena.new()
	add_child(arena)
	arena.build("highland")
	Highland.generation(arena, 1)
	var cam := Camera3D.new()
	cam.far = 6000.0
	cam.fov = 50.0
	add_child(cam)
	cam.make_current()
	var rx := Highland._road_x(HighlandSights.FALL_Z)
	var sc := Highland.road_at_z(HighlandSights.FALL_Z)
	var end: Vector2 = Highland.stream[Highland.stream.size() - 1] if not Highland.stream.is_empty() else Vector2.ZERO
	var lipv: Vector2 = Highland.stream[maxi(Highland.stream.size() - 25, 0)] if not Highland.stream.is_empty() else Vector2.ZERO
	print("stream: %d points, ends at (%.0f, %.0f), starts falling near (%.0f, %.0f)" % [Highland.stream.size(), end.x, end.y, lipv.x, lipv.y])
	var shots := {
		"bridge": [Highland.road(sc - 9.0) + Vector3(2.5, 2.0, 0), Highland.road(sc) + Vector3(0, 0.5, 0)],
		"fall": [Vector3(end.x + 70.0, Highland.SEA + 25.0, end.y + 10.0), Vector3(end.x - 10.0, Highland.SEA + 22.0, end.y)],
		"fall_top": [Vector3(lipv.x - 25.0, Highland.height(lipv.x - 25.0, lipv.y) + 6.0, lipv.y + 8.0), Vector3(lipv.x + 12.0, Highland.height(lipv.x + 12.0, lipv.y) - 8.0, lipv.y)],
		"tether": [Highland.road(Highland.road_at_z(420.0)) + Vector3(0, 1.7, 0), Vector3(HighlandSights.TETHER_AT.x, 300.0, HighlandSights.TETHER_AT.y)],
		"colossus": [Highland.road(Highland.road_at_z(300.0)) + Vector3(0, 1.7, 0), Highland.on_ground(rx - 82.0, HighlandSights.COLOSSUS_Z) + Vector3(0, 25, 0)],
	}
	for k: String in shots:
		cam.position = shots[k][0]
		cam.look_at(shots[k][1])
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, k])
	get_tree().quit()
