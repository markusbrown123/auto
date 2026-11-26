class_name CineCourtyard
extends Node
## A short example of cinematic exploration: still views with selectable
## hotspots, joined by a prerecorded travel sequence, leading into the Sentinel
## encounter. The pictures are prerendered; destinations, hotspots, rewards and
## progression are all code.

signal encounter            # the player chose to face the Sentinel
signal turned_back

const STILLS := "res://assets/video/stills/"
## Hotspots are in normalised picture coordinates (0..1), so they hold on any screen shape.
const VIEWS := {
	"outer": {"still": "courtyard_outer.jpg", "prompt": "The outer ward. He is still at his post, at the far end.",
		"spots": [
			{"id": "go_ward", "at": Vector2(0.51, 0.60), "label": "The Inner Ward", "hint": "Cross the ward"},
			{"id": "chest", "at": Vector2(0.19, 0.76), "label": "A Chest", "hint": "By the fallen column"}]},
	"ward": {"still": "courtyard_ward.jpg", "prompt": "The inner ward.",
		"spots": [{"id": "fight", "at": Vector2(0.47, 0.48), "label": "The Ashen Sentinel", "hint": "State your allegiance"}]},
}
const CHEST := {"flag": "cine_courtyard_chest", "gold": 60, "shards": 1, "items": ["r_iron"]}

var layer: CanvasLayer
var picture: TextureRect
var player: CinePlayer
var ui: Control
var view := "outer"
var _travelling := false
var _skip := false

static func available() -> bool:
	return CineDuel.available() and FileAccess.file_exists("res://assets/video/sentinel_travel.ogv") and ResourceLoader.exists(STILLS + "courtyard_outer.jpg")

func _ready() -> void:
	layer = CanvasLayer.new()
	add_child(layer)
	var bg := UI.full(ColorRect.new())
	bg.color = Color.BLACK
	layer.add_child(bg)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	UI.full(picture)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(picture)
	player = CinePlayer.new()
	player.prefix = "sentinel_"
	player.lengths = {"travel": 6.0}
	player.visible = false
	layer.add_child(player)
	player.advanced.connect(_on_travel_time)
	ui = UI.full(Control.new())
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	Sfx.ambience("wind")
	Sfx.music_for("explore_courtyard", "menu")
	# the walk is shown once; after a defeat the player wakes already inside
	show_view("ward" if Game.profile.flags.has("cine_courtyard_arrived") else "outer")

func show_view(id: String) -> void:
	view = id
	var v: Dictionary = VIEWS[id]
	picture.texture = load(STILLS + v.still)
	picture.visible = true
	player.visible = false
	for c in ui.get_children():
		c.queue_free()
	var m := UI.margin(get_viewport(), 10)
	ui.add_child(m)
	var prompt := UI.label(v.prompt, 24, UI.BONE)
	prompt.size_flags_vertical = Control.SIZE_SHRINK_END
	m.add_child(prompt)
	var back := UI.button("Turn Back", 14, 150)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func(): turned_back.emit())
	m.add_child(back)
	for s in v.spots:
		if s.id == "chest" and Game.profile.flags.has(CHEST.flag):
			continue
		ui.add_child(_spot(s))
	if id == "outer":
		player.prepare(["travel"])       # have the walk's first frame ready before it is asked for

## Where a normalised picture point lands on screen, given the cover-fit of a 16:9 image.
func _to_screen(n: Vector2) -> Vector2:
	var view_size := get_viewport().get_visible_rect().size
	var k := maxf(view_size.x / 16.0, view_size.y / 9.0)
	var pic := Vector2(16.0, 9.0) * k
	return (view_size - pic) * 0.5 + n * pic

func _spot(s: Dictionary) -> Control:
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(150, 150)
	b.size = Vector2(150, 150)
	b.position = _to_screen(s.at) - b.size * 0.5
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ring := HotRing.new()
	UI.full(ring)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ring)
	var l := UI.title(s.label, 17, UI.BONE)
	l.position = Vector2(-60, 112)
	l.size = Vector2(270, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(l)
	var h := UI.label(s.hint, 16, UI.DIM)
	h.position = Vector2(-60, 134)
	h.size = Vector2(270, 22)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(h)
	b.pressed.connect(func(): _choose(str(s.id), b))
	return b

class HotRing extends Control:
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var pulse := 0.5 + 0.5 * sin(t * 2.6)
		draw_arc(c, 30.0 + pulse * 5.0, 0, TAU, 40, Color(0.62, 0.82, 1.0, 0.85), 3.0, true)
		draw_arc(c, 42.0 + pulse * 9.0, 0, TAU, 40, Color(0.62, 0.82, 1.0, 0.25), 2.0, true)
		draw_circle(c, 5.0, Color(0.8, 0.92, 1.0, 0.9))

func _choose(id: String, b: Control) -> void:
	if _travelling:
		return
	Sfx.play("ui_confirm", -4.0)
	match id:
		"go_ward":
			_travel()
		"chest":
			_open_chest(b)
		"fight":
			_face_sentinel()

func _open_chest(b: Control) -> void:
	if Game.profile.flags.has(CHEST.flag):
		return                      # already taken: opening it twice gives nothing twice
	Game.profile.flags[CHEST.flag] = true
	Game.profile.gold += int(CHEST.gold)
	Game.profile.shards += int(CHEST.shards)
	var lines: Array = []
	for id in CHEST.items:
		if Game.grant_item(id):
			lines.append([Db.item(id).name, Db.rarity_color(Db.item(id))])
	lines.append("%d gold" % CHEST.gold)
	lines.append("%d shard" % CHEST.shards)
	Game.save()
	Sfx.play("loot", 0.0)
	b.queue_free()
	Overlays.message(self, "A Chest", lines, "Take", func(): pass)

func _travel() -> void:
	_travelling = true
	_skip = false
	for c in ui.get_children():
		c.queue_free()
	# tap anywhere to skip; skipping loses nothing, it only shortens the walk
	var catcher := UI.full(Control.new())
	catcher.gui_input.connect(func(e):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed and player.active and player.active.stream_position > 0.4:
			_skip = true)
	ui.add_child(catcher)
	var hint := UI.label("Tap to skip", 16, Color(1, 1, 1, 0.5))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -130
	hint.offset_top = -40
	ui.add_child(hint)
	player.visible = true
	player.show_clip("travel", false)
	for i in 3:
		get_tree().create_timer(0.5 + i * 0.9).timeout.connect(func(): if _travelling: Sfx.play("footstep", -5.0))
	_travel_t = 0.0

var _travel_t := 0.0
func _on_travel_time(dt: float) -> void:
	if not _travelling:
		return
	_travel_t += dt
	if picture.visible and _travel_t > 0.05:
		picture.visible = false
	if _travel_t >= 6.0 or _skip:
		_travelling = false
		Game.profile.flags["cine_courtyard_arrived"] = true
		Game.save()
		show_view("ward")
		if Story.pending("courtyard_6"):
			Story.play("courtyard_6")

func _face_sentinel() -> void:
	_travelling = true
	for c in ui.get_children():
		c.queue_free()
	Story.stop()
	encounter.emit()
