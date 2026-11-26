class_name ItemCarousel
extends Control
## A horizontal collection of items that follows the finger: drag moves the row 1:1, letting go carries on
## with the speed of the flick and comes to rest on the nearest item, neighbours show at the sides smaller and
## fainter, and the one in the middle turns slowly. Tap a neighbour to bring it to the middle.
##
## Every 3D piece is drawn by ONE small SubViewport laid over the control (never one per item); only the pieces
## within two places of the middle exist as nodes, built from scenes loaded in the background (`ItemModel`) and
## kept in a short most-recently-used list. Until a piece has loaded, and for items with no model at all
## (helms, gauntlets, greaves, rings, relics), a drawn medallion stands in its place.
##
## An entry is {id, slot, name, color, metal, locked, dark, equipped, fav}; the owner fills `entries` through `set_entries`.

signal centred(index: int)        # the item nearest the middle changed (fires often during a flick)
signal settled(index: int)        # the row has come to rest on this item
signal tapped(index: int)         # the middle item was tapped

const WORLD_H := 1.3              # world units from top to bottom of the viewport at the item plane
const FOV := 30.0
const NODES := 7                  # built pieces kept alive
const FADE_SHADER := "shader_type canvas_item;\nuniform float edge = 0.5;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tfloat d = abs(UV.x - 0.5) * 2.0;\n\tc.a *= 1.0 - smoothstep(edge, 1.0, d) * 0.9;\n\tCOLOR = c;\n}\n"

var entries: Array = []
var body := "m"
var pos := 0.0                    # where the row is, in items (2.5 = halfway between the third and fourth)
var vel := 0.0                    # items per second
var index := 0                    # the item nearest the middle
var spin := 0.6                   # the middle piece's turn, radians
var res_scale := 1.0              # viewport pixels per screen pixel (lowered on the Performance preset)
var moving := false

var _target := 0.0
var _touch := -1
var _dragging := false
var _press_x := 0.0
var _last_x := 0.0
var _samples: Array = []          # [time, x] of the last moments of a drag, for the flick speed
var _clock := 0.0
var _vp: SubViewport
var _view: TextureRect
var _over: Control
var _world: Node3D
var _nodes := {}                  # entry key -> Node3D (built piece)
var _recent: Array = []           # keys, least recently used first
var _placed := {}                 # key -> true for pieces in the world this frame
var _was_settled := true

func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.positional_shadow_atlas_size = 0
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#4a4640")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var cam := Camera3D.new()
	cam.fov = FOV
	cam.position = Vector3(0, 0, WORLD_H / (2.0 * tan(deg_to_rad(FOV * 0.5))))
	_vp.add_child(cam)
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffe2b8")
	key.light_energy = 2.3
	key.rotation_degrees = Vector3(-38, -32, 0)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.name = "Rim"
	rim.light_color = Color("#7f9cc8")
	rim.light_energy = 1.3
	rim.rotation_degrees = Vector3(-18, 155, 0)
	_vp.add_child(rim)
	_world = Node3D.new()
	_vp.add_child(_world)
	_view = TextureRect.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.texture = _vp.get_texture()
	var sh := Shader.new()
	sh.code = FADE_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_view.material = sm
	UI.full(_view)
	add_child(_view)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full(_over)
	add_child(_over)
	_over.draw.connect(_draw_over)
	resized.connect(_fit)

func _ready() -> void:
	var q := int(Game.settings.get("quality", 2))
	res_scale = 0.7 if q == 0 else 1.0
	_vp.msaa_3d = Viewport.MSAA_DISABLED if q == 0 else Viewport.MSAA_2X
	(_vp.get_node("Rim") as DirectionalLight3D).visible = q > 0
	_fit()

func _fit() -> void:
	_vp.size = Vector2i(maxi(8, int(size.x * res_scale)), maxi(8, int(size.y * res_scale)))

# ---------------------------------------------------------------- contents
func set_entries(list: Array, at: int = 0) -> void:
	entries = list
	for k: String in _nodes:
		(_nodes[k] as Node3D).queue_free()
	_nodes.clear()
	_recent.clear()
	_placed.clear()
	jump(at)

## Flags on the entries changed (equipped, favourite, owned); pieces whose darkness changed are rebuilt.
func refresh() -> void:
	queue_redraw()
	_over.queue_redraw()

func jump(i: int) -> void:
	index = clampi(i, 0, maxi(entries.size() - 1, 0))
	pos = float(index)
	_target = pos
	vel = 0.0
	moving = false
	_was_settled = true
	queue_redraw()
	_over.queue_redraw()

func go_to(i: int) -> void:
	_target = float(clampi(i, 0, maxi(entries.size() - 1, 0)))
	if Game.settings.reduce_motion:
		pos = _target
	_wake()

func spacing() -> float:
	return clampf(size.x * 0.37, 150.0, 300.0)

func _key(e: Dictionary) -> String:
	return "%s|%s|%s" % [str(e.id), body, "d" if e.get("dark", false) else ""]

# ---------------------------------------------------------------- touch
func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed and _touch == -1:
			_touch = e.index
			drag_begin(e.position.x)
		elif not e.pressed and e.index == _touch:
			_touch = -1
			drag_end(e.position.x)
		accept_event()
	elif e is InputEventScreenDrag and e.index == _touch:
		drag_move(e.position.x)
		accept_event()
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		go_to(int(roundf(_target)) + (1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1))
		accept_event()

## The three steps of a drag, in this control's own pixels. The touch handler calls them, and so does the
## capture script, so a scripted swipe goes down exactly the path a finger does.
func drag_begin(x: float) -> void:
	_press_x = x
	_last_x = x
	_dragging = false
	_samples = [[_clock, x]]
	vel = 0.0
	_target = pos            # a finger on the row stops it where it is

func drag_move(x: float) -> void:
	if not _dragging and absf(x - _press_x) < 9.0:
		return
	if not _dragging:
		_dragging = true
		_last_x = x
	var d := (x - _last_x) / spacing()
	_last_x = x
	# past either end the row gives, but only a third as far as the finger goes
	if (pos <= 0.0 and d > 0.0) or (pos >= float(entries.size() - 1) and d < 0.0):
		d *= 0.33
	pos -= d
	_target = pos
	_samples.append([_clock, x])
	while _samples.size() > 2 and _clock - float(_samples[0][0]) > 0.09:
		_samples.pop_front()
	_wake()
	_note_centre()

func drag_end(x: float) -> void:
	if not _dragging:
		# a tap: which item was under it?
		var off := int(roundf((x - size.x * 0.5) / spacing() + (pos - roundf(pos))))
		var i := int(roundf(pos)) + off
		if off == 0 and i == index and absf(pos - roundf(pos)) < 0.05:
			tapped.emit(index)
		elif i >= 0 and i < entries.size():
			Sfx.play("ui_tap", -8.0)
			go_to(i)
		else:
			go_to(int(roundf(pos)))
		return
	_dragging = false
	var v := 0.0
	if _samples.size() >= 2:
		var dt: float = float(_samples[-1][0]) - float(_samples[0][0])
		if dt > 0.005 and _clock - float(_samples[-1][0]) < 0.08:
			v = -(float(_samples[-1][1]) - float(_samples[0][1])) / spacing() / dt
	vel = clampf(v, -30.0, 30.0)
	# where the flick would coast to under friction alone, then the nearest item to that
	var rest := pos + vel / 5.0
	_target = float(clampi(int(roundf(rest)), 0, maxi(entries.size() - 1, 0)))
	if Game.settings.reduce_motion:
		pos = _target
		vel = 0.0
	_wake()

func _wake() -> void:
	moving = true
	_was_settled = false
	set_process(true)

func _note_centre() -> void:
	var i := clampi(int(roundf(pos)), 0, maxi(entries.size() - 1, 0))
	if i != index:
		index = i
		Sfx.play("ui_tap", -16.0, 1.3)
		centred.emit(index)

# ---------------------------------------------------------------- motion
func _process(delta: float) -> void:
	_clock += delta
	if not Game.settings.reduce_motion:
		spin = wrapf(spin + delta * 0.55, -PI, PI)
	if not _dragging and not _was_settled:
		# a critically damped spring to the resting item: carries the flick's speed in, never overshoots twice
		var k := 150.0
		var c := 2.0 * sqrt(k)
		var steps := maxi(1, int(ceilf(delta / 0.008)))
		var h := delta / steps
		for i in steps:
			vel += (-k * (pos - _target) - c * vel) * h
			pos += vel * h
		_note_centre()
		if absf(pos - _target) < 0.003 and absf(vel) < 0.05:
			pos = _target
			vel = 0.0
			moving = false
			_was_settled = true
			_note_centre()
			settled.emit(index)
	_layout()
	queue_redraw()
	_over.queue_redraw()

func _scale_at(o: float) -> float:
	var a := absf(o)
	return lerpf(1.0, 0.6, minf(a, 1.0)) - 0.1 * clampf(a - 1.0, 0.0, 1.0)

func _alpha_at(o: float) -> float:
	return clampf(1.0 - 0.5 * minf(absf(o), 1.0) - 0.35 * clampf(absf(o) - 1.0, 0.0, 1.0), 0.0, 1.0)

## Puts the pieces near the middle into the viewport's world and takes the rest out.
func _layout() -> void:
	if entries.is_empty() or size.y < 8.0:
		for k: String in _placed:
			_unplace(k)
		_placed.clear()
		return
	var ppu := size.y / WORLD_H          # screen pixels per world unit at the item plane
	var seen := {}
	var lo := int(floorf(pos)) - 2
	for i in range(maxi(lo, 0), mini(lo + 6, entries.size())):
		var e: Dictionary = entries[i]
		var o := float(i) - pos
		var paths: Array = ItemModel.paths(Db.item(str(e.id)), body)
		if paths.is_empty() or absf(o) > 2.2:
			continue
		var k := _key(e)
		if not _nodes.has(k):
			# load only what is near, and no more than two files at a time, so a long flick does not queue the whole collection
			if absf(o) <= 1.6 and (ItemModel.known(paths) or ItemModel.loading() < 2) and ItemModel.ready(paths):
				var n := ItemModel.build(Db.item(str(e.id)), body, bool(e.get("dark", false)))
				if n:
					_nodes[k] = n
			if not _nodes.has(k):
				continue
		_recent.erase(k)
		_recent.append(k)
		var node: Node3D = _nodes[k]
		if node.get_parent() == null:
			_world.add_child(node)
		seen[k] = true
		var s := _scale_at(o)
		node.position = Vector3(o * spacing() / ppu, -0.02, -0.6 * minf(absf(o), 2.0))
		# the push back in depth is undone in size, so the 2D marks and the 3D pieces agree on where things are
		var depth: float = (WORLD_H / (2.0 * tan(deg_to_rad(FOV * 0.5))) + 0.6 * minf(absf(o), 2.0)) / (WORLD_H / (2.0 * tan(deg_to_rad(FOV * 0.5))))
		node.position.x *= depth
		node.position.y *= depth
		node.scale = Vector3.ONE * s * depth
		var pivot: Node3D = node.get_node("Tilt/Pivot")
		# the middle piece turns; a neighbour rests at a three-quarter view and eases into the turn as it arrives
		var near := clampf(1.0 - absf(o), 0.0, 1.0)
		pivot.rotation.y = lerp_angle(0.5, spin, near * near)
	for k: String in _placed:
		if not seen.has(k):
			_unplace(k)
	_placed = seen
	while _recent.size() > NODES:
		var old: String = _recent.pop_front()
		if _nodes.has(old) and not seen.has(old):
			(_nodes[old] as Node3D).queue_free()
			_nodes.erase(old)

func _unplace(k: String) -> void:
	if _nodes.has(k):
		var n: Node3D = _nodes[k]
		if n.get_parent():
			n.get_parent().remove_child(n)

func has_piece(i: int) -> bool:
	return i >= 0 and i < entries.size() and _placed.has(_key(entries[i]))

func _exit_tree() -> void:
	for k: String in _nodes:
		var n: Node3D = _nodes[k]
		if n.get_parent() == null:
			n.free()
	_nodes.clear()

# ---------------------------------------------------------------- drawing
func _draw() -> void:
	if entries.is_empty():
		return
	var cy := size.y * 0.5
	var lo := int(floorf(pos)) - 2
	for i in range(maxi(lo, 0), mini(lo + 6, entries.size())):
		var e: Dictionary = entries[i]
		var o := float(i) - pos
		var s := _scale_at(o)
		var a := _alpha_at(o)
		var c := Vector2(size.x * 0.5 + o * spacing(), cy)
		var col: Color = e.color
		# a pool of light under the piece: rarity for the one in the middle
		var near := clampf(1.0 - absf(o), 0.0, 1.0)
		var rx := size.y * 0.44 * s
		for ring in 5:
			var f := 1.0 - ring / 5.0
			draw_set_transform(c + Vector2(0, size.y * 0.36 * s), 0.0, Vector2(1.0, 0.2))
			draw_circle(Vector2.ZERO, rx * f, Color(col.lerp(Color.WHITE, 0.15), (0.035 + 0.05 * near) * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not has_piece(i):
			_medallion(c, size.y * 0.3 * s, e, a)

func _medallion(c: Vector2, r: float, e: Dictionary, a: float) -> void:
	var col: Color = e.color
	var dark: bool = e.get("dark", false)
	draw_circle(c, r, Color(0.055, 0.055, 0.065, 0.95 * a))
	draw_arc(c, r, 0, TAU, 48, Color(col if not dark else Color(0.3, 0.3, 0.32), a), maxf(2.0, r * 0.045), true)
	draw_arc(c, r * 0.86, 0, TAU, 48, Color(col, 0.3 * a), 1.0, true)
	var metal: Color = Color(str(e.get("metal", "#b8b4aa"))).lerp(Color("#d8d2c4"), 0.45)
	var g := r * 1.05
	InvGlyph.paint(self, str(e.slot), c - Vector2(g, g) * 0.5, g, Color(metal if not dark else Color(0.26, 0.26, 0.28), a))

## Marks over the pieces: names of the neighbours, a lock on what is not owned, the worn piece's tag, the favourite star.
func _draw_over() -> void:
	if entries.is_empty():
		var f0 := UI.font("body")
		_over.draw_string(f0, Vector2(0, size.y * 0.5), "Nothing of this kind yet. The road provides.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, UI.DIM)
		return
	var font := UI.font("bold")
	var lo := int(floorf(pos)) - 2
	for i in range(maxi(lo, 0), mini(lo + 6, entries.size())):
		var e: Dictionary = entries[i]
		var o := float(i) - pos
		var s := _scale_at(o)
		var a := _alpha_at(o)
		var c := Vector2(size.x * 0.5 + o * spacing(), size.y * 0.5)
		var near := clampf(1.0 - absf(o), 0.0, 1.0)
		if e.get("locked", false):
			var h := 30.0 * s
			_over.draw_circle(c + Vector2(0, -size.y * 0.02), h * 0.95, Color(0.03, 0.03, 0.04, 0.72 * a))
			InvGlyph.paint(_over, "lock", c + Vector2(-h * 0.5, -size.y * 0.02 - h * 0.55), h, Color(0.82, 0.78, 0.7, a))
		if near < 0.75:
			# a neighbour carries its own name; the middle one's is written large below the row
			var w := spacing() * 0.95
			var na := a * (1.0 - near / 0.75)
			_over.draw_string(font, c + Vector2(-w * 0.5, size.y * 0.47), str(e.name), HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(e.color, na), TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL)
		var top := c + Vector2(0, -size.y * 0.5 + 6.0 + 16.0 * (1.0 - s))
		if e.get("equipped", false):
			var tw := 118.0 * s
			_over.draw_rect(Rect2(top + Vector2(-tw * 0.5, 0), Vector2(tw, 26.0 * s)), Color(0.05, 0.05, 0.06, 0.85 * a))
			_over.draw_rect(Rect2(top + Vector2(-tw * 0.5, 0), Vector2(tw, 26.0 * s)), Color(UI.GOLD, 0.8 * a), false, 1.0)
			_over.draw_string(UI.font("head"), top + Vector2(-tw * 0.5, 20.0 * s), "EQUIPPED", HORIZONTAL_ALIGNMENT_CENTER, tw, int(18 * s), Color(UI.GOLD, a))
		if e.get("fav", false):
			var sh := 22.0 * s
			InvGlyph.paint(_over, "star", c + Vector2(size.y * 0.3 * s, -size.y * 0.36 * s), sh, Color(UI.GOLD, a), 1)
