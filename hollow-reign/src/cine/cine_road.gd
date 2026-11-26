class_name CineRoad
extends Node
## Cinematic exploration for a whole region: each stop is a prerendered walk
## followed by a still view with selectable hotspots. Only the pictures are
## recorded. What the choices are, what they give, flags, saves and what
## happens next all come from the same region data and Game code as the
## real-time road, so nothing can be earned twice or lost by skipping.

signal fight(option: Dictionary)
signal moved_on
signal turned_back

const DATA := "res://data/cine_%s.json"
const STILLS := "res://assets/video/stills/"

var data: Dictionary
var stop: Dictionary
var layer: CanvasLayer
var picture: TextureRect
var player: CinePlayer
var ui: Control
var _travelling := false
var _travel_t := 0.0
var _skip := false
var _busy := false

static func available(region_id: String) -> bool:
	var p := DATA % region_id
	if not FileAccess.file_exists(p):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (d is Dictionary) or d.stops.size() < Db.region_by_id[region_id].stages.size():
		return false
	for s in d.stops:
		if not FileAccess.file_exists("res://assets/video/%s_%s.ogv" % [region_id, s.clip]) or not ResourceLoader.exists(STILLS + str(s.still)):
			return false
	return true

func _ready() -> void:
	var region := Game.run_region()
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA % region.id))
	stop = data.stops[int(Game.run.stage)]
	layer = CanvasLayer.new()
	# footage exists per body: show the knight the player actually chose, when that film has been made
	var body := str(Game.profile.get("body", "m"))
	var alt_clip := "%s_%s" % [body, str(stop.clip)]
	var alt_still := str(stop.still).replace("_stop_", "_%s_stop_" % body)
	if body != "m" and FileAccess.file_exists("res://assets/video/%s_%s.ogv" % [region.id, alt_clip]) and ResourceLoader.exists(STILLS + alt_still):
		stop = stop.duplicate()
		stop.clip = alt_clip
		stop.still = alt_still
	add_child(layer)
	var bg := UI.full(ColorRect.new())
	bg.color = Color.BLACK
	layer.add_child(bg)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	UI.full(picture)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture = load(STILLS + str(stop.still))
	layer.add_child(picture)
	player = CinePlayer.new()
	player.prefix = str(region.id) + "_"
	player.lengths = {str(stop.clip): float(data.clip_len)}
	layer.add_child(player)
	player.advanced.connect(_on_travel_time)
	player.media_missing.connect(func(_c): _arrive())
	ui = UI.full(Control.new())
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	Sfx.ambience(str(region.amb))
	Sfx.music_for("explore_" + str(region.id), "menu")
	# each walk plays in full once; after that (a retry, a return) the player arrives at once
	var seen_flag := "cine_road_%s_%d" % [region.id, int(Game.run.stage)]
	if Game.profile.flags.has(seen_flag):
		player.visible = false
		_arrive()
	else:
		Game.profile.flags[seen_flag] = true
		_travel()

func _travel() -> void:
	_travelling = true
	_travel_t = 0.0
	picture.visible = false
	var catcher := UI.full(Control.new())
	catcher.gui_input.connect(func(e):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed and _travel_t > 0.4:
			_skip = true)
	ui.add_child(catcher)
	var hint := UI.label("Tap to skip", 16, Color(1, 1, 1, 0.5))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -130
	hint.offset_top = -40
	ui.add_child(hint)
	player.show_clip(str(stop.clip), false)
	for i in 5:
		get_tree().create_timer(0.6 + i * 0.85).timeout.connect(func(): if _travelling: Sfx.play("footstep", -5.0))

func _on_travel_time(dt: float) -> void:
	if not _travelling:
		return
	_travel_t += dt
	if _travel_t >= float(data.clip_len) - 0.05 or _skip:
		_arrive()

func _arrive() -> void:
	_travelling = false
	picture.visible = true
	# the still is the walk's last frame, so swapping to it is invisible
	var fade := create_tween()
	fade.tween_property(player, "modulate:a", 0.0, 0.12 if _skip else 0.01)
	fade.tween_callback(func(): player.visible = false)
	for c in ui.get_children():
		c.queue_free()
	var region := Game.run_region()
	var stage: int = Game.run.stage
	if not Companion.pick_stage(str(region.id), stage).is_empty():
		await get_tree().create_timer(0.4).timeout
		await Companion.on_stage(str(region.id), stage)
		if not is_inside_tree():
			return
	_build_ui()

## Where a normalised picture point lands on screen, given the cover-fit of a 16:9 image.
func _to_screen(n: Vector2) -> Vector2:
	var view_size := get_viewport().get_visible_rect().size
	var k := maxf(view_size.x / 16.0, view_size.y / 9.0)
	var pic := Vector2(16.0, 9.0) * k
	return (view_size - pic) * 0.5 + n * pic

func _build_ui() -> void:
	var region := Game.run_region()
	var stage: int = Game.run.stage
	var m := UI.margin(get_viewport(), 10)
	ui.add_child(m)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(frame)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(head)
	head.add_child(UI.title(region.name, 24))
	var pips := ""
	for i in region.stages.size():
		pips += "◆ " if i < stage else ("◇ " if i > stage else "❖ ")
	head.add_child(UI.label(pips, 18, UI.GOLD_DIM))
	var hp := UI.bar(Color("#9a2a2a"), 10)
	hp.custom_minimum_size.x = 230
	hp.max_value = Game.stats().max_hp
	hp.value = Game.run.hp
	head.add_child(hp)
	for l in Game.find_lore(region.id, stage):
		head.add_child(UI.label("Record found  ·  " + str(l.title), 15, UI.GOLD))
	var back := UI.button("Turn Back", 14, 150)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -150
	back.pressed.connect(func(): turned_back.emit())
	frame.add_child(back)
	var prompt := UI.label(Game.run_stage().prompt, 23, UI.BONE)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frame.add_child(prompt)
	# the choices: the same ones the real-time road offers, placed where they were filmed
	var all_opts: Array = Game.run_stage().options
	var shown := Game.stage_options()
	for o in shown:
		var idx := -1
		for i in all_opts.size():
			if all_opts[i].label == o.label:
				idx = i
		var at := Vector2(0.5, 0.62)
		if idx >= 0 and idx < stop.spots.size():
			at = Vector2(float(stop.spots[idx][0]), float(stop.spots[idx][1]))
		at = at.clamp(Vector2(0.08, 0.2), Vector2(0.92, 0.72))
		ui.add_child(_spot(o, at))
	ui.modulate.a = 0.0
	create_tween().tween_property(ui, "modulate:a", 1.0, 0.5)

func _spot(o: Dictionary, at: Vector2) -> Control:
	var tag: String = {"fight": "A foe", "boss": "The guardian", "treasure": "A cache", "shrine": "Respite", "lever": "A mechanism", "pass": "Onward"}[o.type]
	if o.has("foe"):
		tag += "  ·  " + str(Db.foes[o.foe].get("cls", ""))
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(150, 150)
	b.size = Vector2(150, 150)
	b.position = _to_screen(at) - b.size * 0.5
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ring := HotRing.new()
	ring.hostile = o.type in ["fight", "boss"]
	UI.full(ring)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ring)
	var y := 108.0
	for row in [[tag.to_upper(), 13, UI.BLOOD.lightened(0.35) if ring.hostile else UI.GOLD, "bold"], [str(o.label).to_upper(), 18, UI.BONE, "head"], [str(o.hint), 16, UI.DIM, "body"]]:
		var l := UI.label(row[0], row[1], row[2], row[3])
		l.position = Vector2(-90, y)
		l.size = Vector2(330, 24)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(l)
		y += 22.0
	b.pressed.connect(func(): _choose(o))
	return b

class HotRing extends Control:
	var t := 0.0
	var hostile := false
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var pulse := 0.5 + 0.5 * sin(t * 2.6)
		var col := Color(1.0, 0.55, 0.45) if hostile else Color(0.62, 0.82, 1.0)
		draw_arc(c, 30.0 + pulse * 5.0, 0, TAU, 40, Color(col.r, col.g, col.b, 0.85), 3.0, true)
		draw_arc(c, 42.0 + pulse * 9.0, 0, TAU, 40, Color(col.r, col.g, col.b, 0.25), 2.0, true)
		draw_circle(c, 5.0, Color(col.r, col.g, col.b, 0.9))

func _choose(o: Dictionary) -> void:
	if _busy or _travelling:
		return
	_busy = true
	Sfx.play("ui_confirm", -4.0)
	Story.stop()
	var lines: Array = []
	var heading := str(o.label)
	match str(o.type):
		"fight", "boss":
			fight.emit(o)
			return
		"pass":
			moved_on.emit()
			return
		"treasure":
			Sfx.play("loot", 0.0)
			var got := Game.open_treasure(o)
			for id in got.items:
				lines.append([Db.item(id).name, Db.rarity_color(Db.item(id))])
			if got.gold > 0:
				lines.append("%d gold" % got.gold)
			if got.shards > 0:
				lines.append("%d shard%s" % [got.shards, "" if got.shards == 1 else "s"])
			if lines.is_empty():
				lines.append("Already emptied.")
		"shrine":
			Sfx.play("levelup", -6.0, 0.8)
			heading = "Respite"
			lines.append("Wounds close.  +%d health" % int(Game.rest_at_shrine()))
		"lever":
			Sfx.play("guard_break", -8.0, 0.7)
			Game.pull_lever(o)
			heading = "A Way Opens"
			lines.append("%s will stay open." % Game.run_region().shortcut.label)
			lines.append("You may begin from here when you return.")
	Overlays.message(self, heading, lines, "Onward", func(): moved_on.emit())
