class_name ItemStage
extends Control
## One item, turning slowly in a small viewport of its own: the shop's and the forge's preview, the reward reveal.
## The piece is built by `ItemModel` (the hand-modelled gear where it exists, with its forge state), loaded in the
## background; an item with no model is a drawn medallion. A drag turns it. One SubViewport, freed with the control.

var item_id := ""
var body := "m"
var dark := false
var mod = null                    # a forge state to show instead of the profile's ({blade_tier, grip_tier, ore, keen})
var dist := 2.3                   # camera distance; the piece is about 1.3 units long
var spin_speed := 0.5
var upright := false              # a tall, narrow stage: blades stand nearly on end and the camera steps back to fit them
var has_piece := false
var _vp: SubViewport
var _view: TextureRect
var _cam: Camera3D
var _piece: Node3D
var _yaw := 0.6
var _touched := false
var _want := false
var _paths: Array = []
var _built := ""
var _sway := false                # blades turn to and fro across their flat instead of all the way round
var _clock := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.positional_shadow_atlas_size = 0
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	var we := WorldEnvironment.new()
	we.environment = ItemModel.studio_env()
	_vp.add_child(we)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_vp.add_child(_cam)
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffe2b8")
	key.light_energy = 2.8
	key.rotation_degrees = Vector3(-38, -32, 0)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.name = "Rim"
	rim.light_color = Color("#7f9cc8")
	rim.light_energy = 1.3
	rim.rotation_degrees = Vector3(-18, 155, 0)
	_vp.add_child(rim)
	_view = TextureRect.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.texture = _vp.get_texture()
	UI.full(_view)
	add_child(_view)
	resized.connect(_fit)

func _ready() -> void:
	var q := int(Game.settings.get("quality", 2))
	_vp.msaa_3d = Viewport.MSAA_DISABLED if q == 0 else Viewport.MSAA_2X
	(_vp.get_node("Rim") as DirectionalLight3D).visible = q > 0
	_fit()

func _fit() -> void:
	var k := 0.7 if int(Game.settings.get("quality", 2)) == 0 else 1.0
	_vp.size = Vector2i(maxi(8, int(size.x * k)), maxi(8, int(size.y * k)))

## Shows this item ("" clears). `forge_state` overrides the profile's mods; `silhouette` gives the unlit shape.
func show_item(id: String, forge_state = null, silhouette: bool = false) -> void:
	var it: Dictionary = Db.item(id)
	var key := "%s|%s|%s" % [id, "d" if silhouette else "", ItemModel.sig(it, forge_state)]
	if key == _built:
		return
	_built = key
	item_id = id
	mod = forge_state
	dark = silhouette
	_paths = ItemModel.paths(it, body, mod) if not it.is_empty() else []
	_want = not _paths.is_empty()
	if not _want:
		_drop()
	queue_redraw()
	if _want and ItemModel.ready(_paths):
		_make()

func _drop() -> void:
	if _piece:
		_piece.queue_free()
		_piece = null
	has_piece = false

func _make() -> void:
	_want = false
	_drop()
	_piece = ItemModel.build(Db.item(item_id), body, dark, mod)
	if _piece:
		_vp.add_child(_piece)
		has_piece = true
		_sway = str(Db.item(item_id).get("slot", "")) == "weapon"
		if upright and _sway:
			(_piece.get_node("Tilt") as Node3D).rotation.z *= 0.35
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenDrag:
		_touched = true
		_yaw = wrapf(_yaw + e.relative.x * 0.012, -PI, PI)
		accept_event()

func _process(delta: float) -> void:
	if _want and ItemModel.ready(_paths):
		_make()
	if _piece == null:
		return
	if not _touched and not Game.settings.reduce_motion:
		_clock += delta
		# a blade seen edge-on is a line: it sways across its flat, where the engraving is; everything else goes round
		_yaw = ItemModel.SWAY * sin(_clock * spin_speed * 1.6 + 0.6) if _sway else wrapf(_yaw + delta * spin_speed, -PI, PI)
	(_piece.get_node("Tilt/Pivot") as Node3D).rotation.y = _yaw
	_cam.position = Vector3(0, 0, dist * (1.2 if upright else 1.0))

func _draw() -> void:
	# a pool of light under the piece, in the item's rank colour; a medallion when there is nothing to turn
	var it: Dictionary = Db.item(item_id)
	if it.is_empty():
		return
	var col: Color = Db.rarity_color(it)
	var c := size * 0.5
	for ring in 5:
		var f := 1.0 - ring / 5.0
		draw_set_transform(c + Vector2(0, size.y * 0.38), 0.0, Vector2(1.0, 0.2))
		draw_circle(Vector2.ZERO, minf(size.x, size.y) * 0.46 * f, Color(col.lerp(Color.WHITE, 0.15), 0.07))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if has_piece or _want:
		return
	var r := minf(size.x, size.y) * 0.32
	draw_circle(c, r, Color(0.055, 0.055, 0.065, 0.95))
	draw_arc(c, r, 0, TAU, 48, col if not dark else Color(0.3, 0.3, 0.32), maxf(2.0, r * 0.045), true)
	draw_arc(c, r * 0.86, 0, TAU, 48, Color(col, 0.3), 1.0, true)
	var metal: Color = Color(str(it.get("look", {}).get("metal", it.get("look", {}).get("color", "#b8b4aa")))).lerp(Color("#d8d2c4"), 0.45)
	InvGlyph.paint(self, str(it.slot), c - Vector2(r, r) * 0.52, r * 1.04, metal if not dark else Color(0.26, 0.26, 0.28))
