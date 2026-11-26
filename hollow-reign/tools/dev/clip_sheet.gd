extends Node3D
## Dev tool: contact sheet of baked clips on a game character, through the game's own rig (FighterRig + SkinDriver),
## whole body driven by the clip. One row per clip and view; tiles at the clip's measured swing times
## (assets/anim/clip_meta.json) or evenly spaced.
## Usage: godot --path . res://tools/dev/clip_sheet.tscn -- --clips=a,b --out=<png> [--views=front,side] [--model=knight_m_ash]
##        [--weapon=sword|greatsword|dual] [--n=6] [--tile=320x360]
var TILE := Vector2i(320, 360)

func _ready() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			args[a.trim_prefix("--").get_slice("=", 0)] = a.get_slice("=", 1)
	var clips: PackedStringArray = str(args.get("clips", "idle")).split(",")
	var views: PackedStringArray = str(args.get("views", "front,side")).split(",")
	var n := int(args.get("n", "6"))
	if args.has("tile"):
		TILE = Vector2i(int(str(args.tile).get_slice("x", 0)), int(str(args.tile).get_slice("x", 1)))
	var meta: Dictionary = {}
	if FileAccess.file_exists("res://assets/anim/clip_meta.json"):
		meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/anim/clip_meta.json")).clips
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.42, 0.45, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 150, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.31, 0.33)
	floor_mi.material_override = fm
	add_child(floor_mi)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.make_current()
	var rig := FighterRig.new()
	add_child(rig)
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_dev_sheet"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	Game.profile = Game.default_profile()
	var look: Dictionary = Duel.player_look()
	look["skin"] = "res://assets/models/%s.glb" % str(args.get("model", "knight_m_ash"))
	if args.has("weapon"):
		look["weapon"] = args.weapon
	rig.build(look, false)
	rig.walking = false
	rig.time_scale = 0.0
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.position = Vector2(330, 8)
	var cl := CanvasLayer.new()
	add_child(cl)
	cl.add_child(lbl)
	var sheet := Image.create(TILE.x * n, TILE.y * clips.size() * views.size(), false, Image.FORMAT_RGB8)
	var row := 0
	for c: String in clips:
		if not SkinDriver.has_clip(c):
			push_error("no clip " + c)
			continue
		var length := SkinDriver.clip_length(c)
		var times: Array = []
		var m: Dictionary = meta.get(c, {})
		var mark := -1
		if m.has("hits") and n >= 4:
			# through the first swing: from just before it starts to its end, the contact frame among them, then the clip's end
			var h: Dictionary = m.hits[int(args.get("hit", "0")) % (m.hits as Array).size()]
			var t0 := maxf(0.0, float(h.start) - 0.1)
			for i in n - 1:
				times.append(lerpf(t0, float(h.end), float(i) / (n - 2)))
			for i in times.size():
				if mark < 0 or absf(float(times[i]) - float(h.contact)) < absf(float(times[mark]) - float(h.contact)):
					mark = i
			times[mark] = float(h.contact)
			times.append(length)
		else:
			for i in n:
				times.append(length * i / maxf(n - 1, 1))
		rig.test_clip = c
		for v: String in views:
			cam.position = Vector3(0, 1.15, -4.3) if v == "front" else (Vector3(4.3, 1.15, 0) if v == "side" else Vector3(-3.4, 1.4, -3.9))
			cam.look_at(Vector3(0, 1.0, 0))
			for i in times.size():
				lbl.text = "%s  %s  t=%.2f%s" % [c, v, times[i], "  CONTACT" if i == mark else ""]
				for f in 12:
					rig.set("_clock", float(times[i]))
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				var sq := img.get_region(Rect2i((img.get_width() - 640) / 2, 0, 640, 720))
				sq.resize(TILE.x, TILE.y, Image.INTERPOLATE_BILINEAR)
				sheet.blit_rect(sq, Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * i, TILE.y * row))
			row += 1
	sheet.save_png(str(args.get("out", "sheet.png")))
	print("sheet: ", args.get("out", "sheet.png"))
	get_tree().quit()
