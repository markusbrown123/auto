class_name TitleScreen
extends Node
## Main menu over a live view of the fallen courtyard.

signal continue_game
signal new_game(heraldry: String, body: String)

const HERALDRY := [["Oxblood", "#3d0f0f"], ["Ash", "#34322e"], ["Verdigris", "#16332c"], ["Dusk", "#1c2240"], ["Bone", "#8a8270"]]
var backdrop: Backdrop
var layer: CanvasLayer
var menu: VBoxContainer
var heraldry := "#3d0f0f"
var body := "m"

func _ready() -> void:
	backdrop = Backdrop.new()
	add_child(backdrop)
	backdrop.build("courtyard")
	backdrop.rig.rotation.y = PI * 0.15
	backdrop.rig.position = Vector3(1.4, 0, 0)
	backdrop.move_camera(Vector3(-0.6, 1.0, 4.4), Vector3(0.2, 1.75, -3.0), true)
	Sfx.music("menu")
	Sfx.ambience("wind")
	layer = CanvasLayer.new()
	add_child(layer)
	var shade := UI.full(TextureRect.new())
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.78))
	g.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(0.62, 0)
	shade.texture = gt
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	var m := UI.margin(get_viewport(), 36)
	layer.add_child(m)
	menu = VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.add_theme_constant_override("separation", 10)
	m.add_child(menu)
	var ver := UI.label("v" + str(ProjectSettings.get_setting("application/config/version")), 14, Color(1, 1, 1, 0.3))
	ver.size_flags_horizontal = Control.SIZE_SHRINK_END
	ver.size_flags_vertical = Control.SIZE_SHRINK_END
	m.add_child(ver)
	_main()

func _clear() -> void:
	for c in menu.get_children():
		menu.remove_child(c)
		c.queue_free()

func _logo() -> void:
	var t := UI.label("ETERNAL EDGE", 68, UI.BONE, "title")
	t.add_theme_constant_override("outline_size", 0)
	menu.add_child(t)
	var sub := UI.title("Fall. Rise. Cut deeper.", 17, UI.GOLD)
	menu.add_child(sub)
	menu.add_child(UI.spacer(26))

func _main() -> void:
	_clear()
	_logo()
	if Game.has_save():
		var c := UI.button("Continue", 22, 300)
		c.pressed.connect(func(): continue_game.emit())
		menu.add_child(c)
	var n := UI.button("New Game", 22, 300)
	n.pressed.connect(_new)
	menu.add_child(n)
	var s := UI.button("Settings", 22, 300)
	s.pressed.connect(_settings)
	menu.add_child(s)

func _new() -> void:
	_clear()
	menu.add_child(UI.title("Who Wakes", 30))
	var forms := HBoxContainer.new()
	forms.add_theme_constant_override("separation", 8)
	menu.add_child(forms)
	for f in [["m", "The Knight"], ["f", "The Blade"]]:
		var fb := UI.button(f[1], 18, 190)
		if f[0] == body:
			fb.add_theme_color_override("font_color", UI.GOLD)
		fb.pressed.connect(func():
			body = f[0]
			_show_body()
			_new())
		forms.add_child(fb)
	menu.add_child(UI.title("Your Colours", 22))
	var note := UI.label("The cloak you were buried in. It is the only thing you remember choosing.", 20, UI.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 460
	menu.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	menu.add_child(row)
	for h in HERALDRY:
		var b := Button.new()
		b.custom_minimum_size = Vector2(84, 84)
		b.add_theme_stylebox_override("normal", UI.box(Color(h[1]), UI.GOLD if h[1] == heraldry else UI.GOLD_DIM, 3 if h[1] == heraldry else 1))
		b.add_theme_stylebox_override("hover", UI.box(Color(h[1]).lightened(0.1), UI.GOLD, 2))
		b.add_theme_stylebox_override("pressed", UI.box(Color(h[1]), UI.GOLD, 3))
		b.tooltip_text = h[0]
		b.pressed.connect(func():
			heraldry = h[1]
			backdrop.rig.mat_cloth.albedo_color = Color(heraldry)
			Sfx.play("ui_tap", -6.0)
			_new())
		row.add_child(b)
	if Game.has_save():
		menu.add_child(UI.label("Beginning anew replaces your existing journey.", 17, UI.BLOOD.lightened(0.25)))
	menu.add_child(UI.spacer(12))
	var go := UI.button("Rise", 22, 300)
	go.pressed.connect(func():
		Sfx.play("ui_confirm", -3.0)
		new_game.emit(heraldry, body))
	menu.add_child(go)
	var back := UI.button("Back", 18, 300)
	back.pressed.connect(_main)
	menu.add_child(back)

func _show_body() -> void:
	Game.profile = Game.default_profile() if Game.profile.is_empty() else Game.profile
	var keep: String = Game.profile.get("body", "m")
	Game.profile.body = body
	backdrop.refresh_knight()
	backdrop.rig.rotation.y = PI * 0.15
	backdrop.rig.position = Vector3(1.4, 0, 0)
	Game.profile.body = keep

func _settings() -> void:
	_clear()
	menu.add_child(UI.title("Settings", 30))
	var p := UI.panel()
	p.custom_minimum_size.x = 640
	menu.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	SettingsPanel.fill(v, _settings)
	var back := UI.button("Back", 18, 300)
	back.pressed.connect(_main)
	menu.add_child(back)
