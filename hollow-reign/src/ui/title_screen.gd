class_name TitleScreen
extends Node
## The main menu: the player's own knight, breathing, in the fallen courtyard, with the camera drifting.
## The other front-end screens (journeys, who wakes, the map, the chronicle, credits, settings) open over
## the same scene, so nothing is rebuilt to move between them.

signal continue_game
signal new_game(heraldry: String, body: String)
signal open_screen(which: String)          # "character", "equipment", "training": the router's screens
signal set_out(region_id: String, use_shortcut: bool)

const HERALDRY := CharacterSelect.HERALDRY
## The plate under Continue, in reading order (two columns). Whatever `entries()` does not offer is left out.
const SECONDARY := ["World Map", "Legacies", "Character", "Equipment", "Chronicle", "Training", "Settings", "Credits"]
const PLATE_W := 500.0
const CAM_POS := Vector3(-0.6, 1.0, 4.4)
const CAM_LOOK := Vector3(0.2, 1.75, -3.0)
## Backdrop mode (off by default): the menu over the high road, the knight small on it, looking up at the Ring-Gate.
static var vista := false

var backdrop: Backdrop
var layer: CanvasLayer
var menu: VBoxContainer
var heraldry := "#3d0f0f"
var body := "m"
var knight_name := ""
var _menu_root: Control
var _panel: Control                # the screen open over the menu, if any
var _shade: TextureRect
var _new_confirmed := false
var _target_slot := 1              # where a new journey will be written, once it is confirmed

func _ready() -> void:
	UI.apply(self)
	# the knight on the menu is the player's own: the most recent journey, as equipped
	if Game.profile.is_empty() and Game.has_save():
		Game.load_slot(Game.latest_slot())
	backdrop = Backdrop.new()
	add_child(backdrop)
	backdrop.build("highland" if vista else "courtyard")
	_pose_knight()
	backdrop.move_camera(CAM_POS, CAM_LOOK, true)
	if vista:
		_vista()
	_motes()
	Sfx.music_for("theme", "menu")
	Sfx.ambience("wind")
	layer = CanvasLayer.new()
	add_child(layer)
	_shade = UI.shade(0.88, 0.66)
	layer.add_child(_shade)
	_menu_root = UI.margin(get_viewport(), 20)
	layer.add_child(_menu_root)
	menu = VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.add_theme_constant_override("separation", 0)
	_menu_root.add_child(menu)
	var ver := UI.label("v" + str(ProjectSettings.get_setting("application/config/version")), 18, Color(1, 1, 1, 0.3))
	ver.size_flags_horizontal = Control.SIZE_SHRINK_END
	ver.size_flags_vertical = Control.SIZE_SHRINK_END
	_menu_root.add_child(ver)
	_main()
	UI.slide_in(_menu_root, Vector2(-30, 0), 0.7, 0.25)

func _pose_knight() -> void:
	if backdrop.rig:
		backdrop.rig.rotation.y = PI * 0.15
		backdrop.rig.position = Vector3(1.4, 0, 0)

## The vista backdrop: the prologue's opening shot, with the player's own knight standing on the road.
func _vista() -> void:
	var v := HighRoad.vista()
	var at := Highland.road(30.0)
	if backdrop.rig:
		backdrop.rig.position = at
		backdrop.rig.rotation.y = Highland.road_yaw(30.0)
	Highland.generation(backdrop.arena, int(Game.profile.get("flags", {}).get("generation", 2)) if not Game.profile.is_empty() else 1)
	backdrop.key.visible = false
	backdrop.cam.far = 6000.0
	backdrop.cam_fov = v[2]
	backdrop.cam_drift = 2.0
	backdrop.move_camera(v[0], v[1], true)

## Dust in the light and a few embers off the braziers, close to the camera.
func _motes() -> void:
	for kind: int in 2:
		var p := CPUParticles3D.new()
		p.amount = 36 if kind == 0 else 10
		p.lifetime = 9.0 if kind == 0 else 5.0
		p.preprocess = 9.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(4.5, 1.5, 2.0)
		p.position = Vector3(0.8, 1.6, -0.6)       # kept well in front of the camera, so no mote fills the screen
		p.direction = Vector3(0.4, 1.0 if kind == 1 else 0.15, 0.1)
		p.spread = 50.0
		p.gravity = Vector3.ZERO
		p.initial_velocity_min = 0.03 if kind == 0 else 0.2
		p.initial_velocity_max = 0.12 if kind == 0 else 0.45
		var q := QuadMesh.new()
		q.size = Vector2.ONE * (0.03 if kind == 0 else 0.04)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color(1.0, 0.95, 0.82) if kind == 0 else Color(1.0, 0.55, 0.2)
		var dot := GradientTexture2D.new()
		dot.gradient = Gradient.new()
		dot.gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		dot.fill = GradientTexture2D.FILL_RADIAL
		dot.fill_from = Vector2(0.5, 0.5)
		dot.fill_to = Vector2(1.0, 0.5)
		dot.width = 16
		dot.height = 16
		mat.albedo_texture = dot
		q.material = mat
		p.mesh = q
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.55 if kind == 0 else 0.9), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		p.color_ramp = g
		p.speed_scale = UI.motion() * 0.9 + 0.1
		backdrop.add_child(p)

func _clear() -> void:
	for c in menu.get_children():
		menu.remove_child(c)
		c.queue_free()

func _logo() -> void:
	var t := UI.label("HOLLOW REIGN", 64, UI.BONE, "title")
	t.add_theme_constant_override("outline_size", 0)
	menu.add_child(t)
	menu.add_child(UI.ornament(470, UI.GOLD_DIM.lightened(0.15)))
	menu.add_child(UI.title("Three hundred years of silence", 18, UI.GOLD))

## The small line under the logo: who is waiting, and where they had got to.
func status_line() -> String:
	if Game.profile.is_empty() or not Game.has_save():
		return ""
	var r := Game.furthest_region()
	var n := 0
	for x in Db.regions:
		if not x.get("optional", false):
			n += 1
		if x.id == r.id:
			break
	var who: String = str(Game.profile.get("name", ""))
	var chapter: String = "a side road" if r.get("optional", false) else "Chapter %s" % UI.roman(n)
	# which of the house is on the road comes first: the family's story is the save
	var gen := Game.generation()
	var of_house: String = "%s   ·   " % str(Generations.def(gen).chapter)
	if gen != 2:
		chapter = "Generation %s" % UI.roman(gen)
		for x2 in Db.regions:
			if Game.region_unlocked(x2.id) and not Game.profile.cleared.has(x2.id) and not x2.get("optional", false):
				r = x2
				break
	return "%s%sLevel %d   ·   %s, %s" % [of_house, (who + "   ·   ") if who != "" else "", int(Game.profile.level), chapter, r.name]

## The entries that make sense right now, as [label, action].
func entries() -> Array:
	var saved := Game.has_save() and not Game.profile.is_empty()
	var out: Array = []
	if saved:
		out.append(["Continue", func(): continue_game.emit()])
	out.append(["New Legacy", _new])
	if saved:
		out.append(["Legacies", func(): _slots("load")])
		out.append(["Character", func(): open_screen.emit("character")])
		out.append(["Equipment", func(): open_screen.emit("equipment")])
		out.append(["World Map", func(): open("map")])
		out.append(["Chronicle", func(): open("chronicle")])
		out.append(["Training", func(): open_screen.emit("training")])
	out.append(["Settings", _settings])
	out.append(["Credits", func(): open("credits")])
	return out

func _main() -> void:
	_close_panel()
	if Game.profile.is_empty() and Game.has_save():
		Game.load_slot(Game.latest_slot())
		backdrop.refresh_knight()
		_pose_knight()
	_clear()
	_logo()
	var line := status_line()
	menu.add_child(UI.spacer(10))
	if line != "":
		menu.add_child(UI.label(line, 18, UI.SILVER))
	menu.add_child(UI.spacer(10))
	var list := entries()
	if list.size() <= 4:
		# the first launch: three entries, each a row a thumb can find
		for i in list.size():
			var e: Array = list[i]
			var b := UI.menu_item(e[0], 26 if i == 0 else 22, 330)
			b.custom_minimum_size.y = 68 if i == 0 else 62
			if i == 0:
				b.add_theme_color_override("font_color", UI.GOLD.lightened(0.2))
			b.pressed.connect(e[1])
			menu.add_child(b)
		return
	# a journey exists. Continue stands alone and large; the rest of the journey's screens are a plate of two columns
	# under it; New Legacy is last, apart from both and dimmer, and asks before it does anything (O3).
	var by_name := {}
	for e: Array in list:
		by_name[str(e[0])] = e[1]
	var go := UI.button("Continue", 28, PLATE_W)
	go.custom_minimum_size.y = 76
	go.add_theme_color_override("font_color", UI.GOLD.lightened(0.2))
	go.add_theme_stylebox_override("normal", UI._button_box("hover"))
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go.pressed.connect(by_name["Continue"])
	menu.add_child(go)
	menu.add_child(UI.spacer(10))
	var plate := UI.panel(Color(0.03, 0.03, 0.036, 0.6), Color(UI.GOLD_DIM, 0.55))
	plate.get_theme_stylebox("panel").set_content_margin_all(6)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu.add_child(plate)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	plate.add_child(grid)
	for label: String in SECONDARY:
		if by_name.has(label):
			var b := UI.menu_item(label, 22, (PLATE_W - 18.0) * 0.5)
			b.pressed.connect(by_name[label])
			grid.add_child(b)
	menu.add_child(UI.spacer(12))
	var fresh := UI.menu_item("New Legacy", 22, 0)
	fresh.add_theme_color_override("font_color", UI.DIM.lightened(0.15))
	fresh.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fresh.pressed.connect(by_name["New Legacy"])
	menu.add_child(fresh)

# ---------------------------------------------------------------- screens over the menu
## Opens one of the front-end screens by name. Used by the menu and by the dev `--screen=` switch.
func open(which: String, arg: String = "") -> void:
	match which:
		"slots": _slots(arg if arg != "" else "load")
		"charselect": _charselect()
		"map":
			var w := WorldMap.new()
			w.set_out.connect(func(region: String, shortcut: bool): set_out.emit(region, shortcut))
			_host(w)
			if arg != "" and Db.region_by_id.has(arg) and Game.region_unlocked(arg):
				w.select(arg)
		"chronicle": _host(Chronicle.new(arg if arg != "" else "Records"))
		"credits":
			var c := Credits.new()
			_host(c)
			if arg == "licences":
				c.show_licences()
		"settings": _settings()

func _host(c: Control) -> void:
	_close_panel()
	_menu_root.visible = false
	_panel = c
	layer.add_child(c)
	if c.has_signal("closed"):
		c.connect("closed", _main)
	UI.fade_in(c, 0.3)

func _close_panel() -> void:
	if _panel and is_instance_valid(_panel):
		if _panel is CharacterSelect:
			_panel.leave()
			backdrop.move_camera(CAM_POS, CAM_LOOK)
		_panel.queue_free()
	_panel = null
	_shade.visible = true
	if not _menu_root.visible:
		_menu_root.visible = true
		UI.fade_in(_menu_root, 0.3)

func _slots(mode: String) -> void:
	var s := SaveSlots.new(mode)
	s.chosen.connect(func(n: int):
		if mode == "load":
			if Game.load_slot(n):
				continue_game.emit()
		else:
			_target_slot = n
			_charselect())
	_host(s)

## New Journey: with a free place it goes straight to who wakes; with none the player picks what to overwrite.
func _new() -> void:
	if Game.has_save() and not Game.profile.is_empty() and not _new_confirmed:
		UI.confirm(layer, "A new legacy", "A legacy is already under way. Starting another does not end it: it takes a place of its own, and yours can be taken up again from Legacies." if Game.free_slot() != 0 else "A legacy is already under way and every place is taken. Starting another means choosing one to overwrite.", "Begin anew", func():
			_new_confirmed = true
			_new()
			_new_confirmed = false, "Keep my legacy")
		return
	var free := Game.free_slot()
	if free == 0:
		_slots("new")
		return
	_target_slot = free
	_charselect()

func _charselect() -> void:
	var cs := CharacterSelect.new()
	cs.heraldry = heraldry
	cs.body = body
	_host(cs)
	_shade.visible = false
	cs.setup(backdrop)
	cs.confirmed.connect(func(h: String, b: String, who: String):
		heraldry = h
		body = b
		knight_name = who
		# an overwritten journey leaves nothing behind, not even its backup
		Game.delete_slot(_target_slot)
		Game.slot = _target_slot
		new_game.emit(h, b))

func _settings() -> void:
	var root: Control = UI.full(Control.new())
	root.add_user_signal("closed")
	var dim: ColorRect = UI.full(ColorRect.new())
	dim.color = Color(0.01, 0.01, 0.015, 0.8)
	root.add_child(dim)
	var m := UI.margin(get_viewport(), 26)
	root.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size.x = 900
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.add_child(col)
	col.add_child(UI.header("Settings", _main))
	var p := UI.panel()
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(p)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 5)
	scroll.add_child(v)
	_refill_settings(v)
	_host(root)

## A changed row redraws the list in place, so the reader stays where they were.
func _refill_settings(v: VBoxContainer) -> void:
	SettingsPanel.fill(v, func():
		for c in v.get_children():
			v.remove_child(c)
			c.queue_free()
		_refill_settings(v))
