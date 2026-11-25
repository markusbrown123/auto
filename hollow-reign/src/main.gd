extends Node
## Entry point and screen router.

var current: Node
var _shots: Array = []
var _shot_dir := ""
var _t := 0.0

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("shots"):
		# capture harness: --shots=dir --at=1.0,2.5 [--demo=foe_id]
		_shot_dir = args.shots
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		for s in str(args.get("at", "2")).split(","):
			_shots.append(float(s))
	if args.has("demo"):
		if Game.profile.is_empty():
			Game.profile = Game.default_profile()
		if args.has("gear"):
			for id in str(args.gear).split(","):
				Game.profile.inventory.append(id)
				Game.equip(id)
		var d := Duel.new()
		add_child(d)
		d.setup(args.demo, {"autoplay": true, "seed": int(args.get("seed", "3")), "skip_intro": args.has("skip_intro"), "bot_style": int(args.get("bot", "3"))})
		d.finished.connect(func(won, _s): print("duel finished won=", won))
		current = d

func _process(delta: float) -> void:
	if _shot_dir == "":
		return
	_t += delta
	if not _shots.is_empty() and _t >= _shots[0]:
		var t: float = _shots.pop_front()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/shot_%05.1f.png" % [_shot_dir, t])
		if _shots.is_empty():
			get_tree().quit()
