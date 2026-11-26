class_name WorldMap
extends Control
## The map of Vaelora: drawn in code as a parchment sheet in a brass frame, with the faint survey lines of
## whoever drew it first. Roads appear as regions open; a region the knight has not reached has no name.

signal closed
signal set_out(region_id: String, use_shortcut: bool)

## Where things are on the sheet, 0..1. The Sanctuary is where the knight wakes; it is not a region.
const PLACE := {
	"sanctuary": Vector2(0.13, 0.80),
	"courtyard": Vector2(0.25, 0.63),
	"blackwood": Vector2(0.44, 0.76),
	"cathedral": Vector2(0.57, 0.53),
	"crypt": Vector2(0.40, 0.33),
	"roost": Vector2(0.17, 0.37),
	"citadel": Vector2(0.63, 0.19),
	"throne": Vector2(0.85, 0.36),
	"deep": Vector2(0.80, 0.60),
}
## The road to a region is drawn from the region that unlocks it, except where the ground says otherwise.
const ROAD_FROM := {"courtyard": "sanctuary", "deep": "throne"}

var selected := ""
var sheet: Control
var card: VBoxContainer
var _buttons := {}
var _clock := 0.0

func _ready() -> void:
	UI.apply(self)
	UI.full(self)
	var dim: ColorRect = UI.full(ColorRect.new())
	dim.color = Color(0.01, 0.01, 0.015, 0.8)
	add_child(dim)
	var m := UI.margin(get_viewport(), 22)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)
	v.add_child(UI.header("Vaelora", func(): closed.emit(), "%d of %d guardians ended" % [_guardians_ended(), Db.regions.size()]))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	sheet = Control.new()
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.size_flags_stretch_ratio = 1.75
	sheet.clip_contents = true
	sheet.draw.connect(_draw_sheet)
	sheet.resized.connect(_place_buttons)
	h.add_child(sheet)
	var p := UI.panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size.x = 380
	h.add_child(p)
	UI.corners(p, UI.GOLD_DIM.lightened(0.2))
	card = VBoxContainer.new()
	card.add_theme_constant_override("separation", 7)
	p.add_child(card)
	for r in Db.regions:
		if Game.region_unlocked(r.id):
			var b := Button.new()
			b.flat = true
			for st: String in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
			b.custom_minimum_size = Vector2(72, 72)
			b.size = Vector2(72, 72)
			b.pressed.connect(func():
				Sfx.play("ui_tap", -6.0)
				select(r.id))
			sheet.add_child(b)
			_buttons[r.id] = b
	select(here() if here() != "sanctuary" else str(Game.furthest_region().id))

func _guardians_ended() -> int:
	var n := 0
	for r in Db.regions:
		n += 1 if Game.profile.cleared.has(r.id) else 0
	return n

## Where the knight is: on a road if a journey is under way, otherwise at the sanctuary.
func here() -> String:
	return str(Game.run.region) if Game.run.has("region") else "sanctuary"

func _at(id: String) -> Vector2:
	return Vector2(PLACE[id]) * sheet.size

func _place_buttons() -> void:
	for id: String in _buttons:
		_buttons[id].position = _at(id) - Vector2(36, 36)
	sheet.queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	if UI.motion() > 0.0:
		sheet.queue_redraw()

func select(id: String) -> void:
	selected = id
	sheet.queue_redraw()
	_fill_card()

# ---------------------------------------------------------------- the chapter card
func chapter_of(id: String) -> String:
	var n := 0
	for r in Db.regions:
		if not r.get("optional", false):
			n += 1
		if r.id == id:
			return "A side road" if r.get("optional", false) else "Chapter %s" % UI.roman(n)
	return ""

func records(id: String) -> Vector2i:
	var have := 0
	var all := 0
	for l in Db.lore:
		if str(l.region) == id:
			all += 1
			have += 1 if Game.profile.lore.has(l.id) else 0
	return Vector2i(have, all)

func _fill_card() -> void:
	for c in card.get_children():
		card.remove_child(c)
		c.queue_free()
	var r: Dictionary = Db.region_by_id.get(selected, {})
	if r.is_empty():
		return
	var cleared: bool = Game.profile.cleared.has(r.id)
	card.add_child(UI.label(chapter_of(r.id).to_upper(), 16, UI.GOLD, "head"))
	card.add_child(UI.wrapped(str(r.name).to_upper(), 26, UI.BONE, 340, "head"))
	card.add_child(UI.ornament(340))
	card.add_child(UI.wrapped(str(r.blurb), 19, UI.BONE, 340))
	card.add_child(UI.spacer(2))
	var last: Dictionary = r.stages[-1].options[-1]
	card.add_child(UI.label("OBJECTIVE", 15, UI.GOLD_DIM.lightened(0.3), "head"))
	if cleared:
		card.add_child(UI.wrapped("%s is ended. The road beyond is open." % str(Db.foes[last.foe].name), 19, UI.STAMINA.lightened(0.25), 340))
	else:
		card.add_child(UI.wrapped("Reach %s and end what guards it." % str(last.label), 19, UI.BONE, 340))
	var rec := records(str(r.id))
	if rec.y > 0:
		card.add_child(UI.label("RECORDS", 15, UI.GOLD_DIM.lightened(0.3), "head"))
		card.add_child(UI.label("%d of %d found here" % [rec.x, rec.y], 19, UI.GOLD if rec.x == rec.y else UI.BONE))
	var side: Array = []
	for st in r.stages:
		for o in st.options:
			if o.get("optional", false) and o.has("foe"):
				side.append("%s  —  %s" % [o.label, ("%s, ended" % Db.foes[o.foe].name) if Game.profile.defeated.has(o.foe) else "something waits off the road"])
	if not side.is_empty():
		card.add_child(UI.label("OFF THE ROAD", 15, UI.GOLD_DIM.lightened(0.3), "head"))
		for s: String in side:
			card.add_child(UI.wrapped(s, 18, UI.BONE, 340))
	var fill := UI.spacer(0)
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(fill)
	if Game.shortcut_open(str(r.id)):
		var sc := UI.button("By %s" % str(r.shortcut.label), 17, 340)
		sc.custom_minimum_size.y = 46
		sc.pressed.connect(func(): set_out.emit(str(r.id), true))
		card.add_child(sc)
	var go := UI.button("Set out", 22, 340)
	go.pressed.connect(func():
		Sfx.play("ui_confirm", -3.0)
		set_out.emit(str(r.id), false))
	card.add_child(go)
	UI.stagger(card, 0.03, 0.25)

# ---------------------------------------------------------------- the sheet
const SEA := Color("#9c9070")
const LAND := Color("#cdbe95")
const LAND_EDGE := Color("#5a4a30")
const BRASS := Color("#8c6c2e")
const TECH := Color(0.16, 0.42, 0.44, 0.26)

## The coast, clockwise, 0..1. Roughened when drawn.
const COAST := [
	Vector2(0.05, 0.82), Vector2(0.03, 0.70), Vector2(0.07, 0.56), Vector2(0.05, 0.42), Vector2(0.08, 0.30), Vector2(0.17, 0.24),
	Vector2(0.27, 0.16), Vector2(0.34, 0.09), Vector2(0.44, 0.05), Vector2(0.58, 0.04), Vector2(0.72, 0.07), Vector2(0.84, 0.13),
	Vector2(0.94, 0.22), Vector2(0.97, 0.38), Vector2(0.94, 0.52), Vector2(0.96, 0.64), Vector2(0.92, 0.76), Vector2(0.84, 0.82),
	Vector2(0.70, 0.84), Vector2(0.58, 0.89), Vector2(0.43, 0.90), Vector2(0.31, 0.87), Vector2(0.20, 0.89), Vector2(0.10, 0.87),
]

func _rough(pts: Array, amount: float, seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedVector2Array()
	for i in pts.size():
		var a: Vector2 = Vector2(pts[i]) * sheet.size
		var b: Vector2 = Vector2(pts[(i + 1) % pts.size()]) * sheet.size
		var normal := (b - a).orthogonal().normalized()
		for k in 5:
			var t := k / 5.0
			out.append(a.lerp(b, t) + normal * rng.randf_range(-amount, amount) * (0.0 if k == 0 else 1.0))
	return out

func _draw_sheet() -> void:
	var s := sheet.size
	var ink := UI.MAP_INK
	sheet.draw_rect(Rect2(Vector2.ZERO, s), SEA)
	# survey lines: a grid, and range rings from the one place everything was measured from
	var step := s.y / 9.0
	var x := step * 0.5
	while x < s.x:
		sheet.draw_line(Vector2(x, 0), Vector2(x, s.y), TECH, 1.0)
		x += step
	var y := step * 0.5
	while y < s.y:
		sheet.draw_line(Vector2(0, y), Vector2(s.x, y), TECH, 1.0)
		y += step
	var hub := _at("throne")
	for i in range(1, 7):
		sheet.draw_arc(hub, step * 1.15 * i, 0, TAU, 72, TECH, 1.0, true)
	for i in 12:
		var d := Vector2.from_angle(i * TAU / 12.0)
		sheet.draw_line(hub + d * step * 0.6, hub + d * step * 7.0, Color(TECH, 0.14), 1.0)
	# the land
	var coast := _rough(COAST, s.y * 0.012, 7)
	sheet.draw_colored_polygon(coast, LAND)
	var closed_coast := coast.duplicate()
	closed_coast.append(coast[0])
	sheet.draw_polyline(closed_coast, LAND_EDGE, 2.0, true)
	var shore := PackedVector2Array()
	for p in closed_coast:
		shore.append(s * 0.5 + (p - s * 0.5) * 1.025)
	sheet.draw_polyline(shore, Color(LAND_EDGE, 0.28), 1.0, true)
	# the river: down from the northern range, through the low ground, out to the south coast
	var river := PackedVector2Array()
	for i in 22:
		var t := i / 21.0
		var base := Vector2(lerpf(0.55, 0.37, t) + sin(t * 9.0) * 0.022, lerpf(0.12, 0.895, t))
		river.append(base * s)
	sheet.draw_polyline(river, Color(0.30, 0.40, 0.44, 0.75), 3.0, true)
	sheet.draw_polyline(river, Color(0.62, 0.70, 0.70, 0.5), 1.0, true)
	_terrain(ink)
	# roads: only to places that are open
	for r in Db.regions:
		if not Game.region_unlocked(r.id):
			continue
		var from: String = ROAD_FROM.get(r.id, str(r.requires))
		_road(_at(from), _at(str(r.id)), r.get("optional", false))
	# the next places, known only as a mark where a road must go
	for r in Db.regions:
		if Game.region_unlocked(r.id):
			continue
		if r.requires != null and Game.region_unlocked(str(r.requires)):
			var p := _at(str(r.id))
			sheet.draw_arc(p, 9.0, 0, TAU, 20, Color(ink, 0.35), 1.5, true)
			sheet.draw_string(UI.font("head"), p + Vector2(-5, 26), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(ink, 0.45))
	# the sanctuary
	var sp := _at("sanctuary")
	sheet.draw_colored_polygon(PackedVector2Array([sp + Vector2(-9, 4), sp + Vector2(-9, -5), sp + Vector2(0, -14), sp + Vector2(9, -5), sp + Vector2(9, 4)]), ink)
	sheet.draw_rect(Rect2(sp + Vector2(-2.5, -3), Vector2(5, 7)), LAND)
	_name(sp + Vector2(0, 26), "The Sanctuary", 15, Color(ink, 0.85))
	# the regions that are open
	for r in Db.regions:
		if Game.region_unlocked(r.id):
			_marker(r)
	# where the knight is
	var hp := _at(here())
	var bob := sin(_clock * 2.2) * 2.0 * UI.motion()
	var foot := hp + Vector2(15, -12)
	sheet.draw_line(foot, foot + Vector2(0, -26 + bob), ink, 2.0, true)
	sheet.draw_colored_polygon(PackedVector2Array([foot + Vector2(1, -26 + bob), foot + Vector2(18, -21 + bob), foot + Vector2(1, -15 + bob)]), UI.CRIMSON.lightened(0.12))
	_ornaments(ink)
	# the frame: brass, twice, with pinned corners
	sheet.draw_rect(Rect2(Vector2(1, 1), s - Vector2(2, 2)), BRASS.darkened(0.45), false, 4.0)
	sheet.draw_rect(Rect2(Vector2(7, 7), s - Vector2(14, 14)), Color(BRASS, 0.9), false, 1.5)
	for c: Vector2 in [Vector2(7, 7), Vector2(s.x - 7, 7), Vector2(7, s.y - 7), s - Vector2(7, 7)]:
		sheet.draw_circle(c, 4.5, BRASS.lightened(0.15))
		sheet.draw_circle(c, 2.0, BRASS.darkened(0.5))
	# aged edges
	for i in 5:
		sheet.draw_rect(Rect2(Vector2.ONE * i * 5, s - Vector2.ONE * i * 10), Color(0.16, 0.11, 0.05, 0.07), false, 6.0)

func _name(at: Vector2, text: String, size: int, color: Color) -> void:
	var f := UI.font("head")
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(clampf(at.x - w * 0.5, 16.0, sheet.size.x - w - 16.0), at.y)
	# a slip of parchment under the name, so it reads over trees, roads and water
	var plate := Rect2(p + Vector2(-6, -size), Vector2(w + 12, size + 7))
	sheet.draw_rect(plate, Color(LAND.lightened(0.12), 0.9))
	sheet.draw_rect(plate, Color(LAND_EDGE, 0.45), false, 1.0)
	sheet.draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _road(a: Vector2, b: Vector2, optional: bool) -> void:
	# a slight bow, so roads read as travelled rather than ruled
	var mid := (a + b) * 0.5 + (b - a).orthogonal().normalized() * (a.distance_to(b) * 0.08)
	var pts := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	var col := Color(BRASS.darkened(0.35), 0.95)
	if optional:
		for i in range(0, 24, 2):
			sheet.draw_line(pts[i], pts[i + 1], Color(UI.CRIMSON.darkened(0.1), 0.85), 2.0, true)
	else:
		sheet.draw_polyline(pts, Color(LAND_EDGE, 0.35), 5.0, true)
		sheet.draw_polyline(pts, col, 2.0, true)

func _marker(r: Dictionary) -> void:
	var p := _at(str(r.id))
	var ink := UI.MAP_INK
	var optional: bool = r.get("optional", false)
	var cleared: bool = Game.profile.cleared.has(r.id)
	var rim := UI.CRIMSON if optional else BRASS
	if str(r.id) == selected:
		var pulse := 1.0 + 0.08 * sin(_clock * 3.0) * UI.motion()
		sheet.draw_arc(p, 19.0 * pulse, 0, TAU, 40, Color(UI.GOLD.lightened(0.2), 0.95), 2.5, true)
		sheet.draw_arc(p, 23.0 * pulse, 0, TAU, 40, Color(ink, 0.5), 1.0, true)
	if optional:
		# a side road is a diamond
		var d := PackedVector2Array([p + Vector2(0, -13), p + Vector2(13, 0), p + Vector2(0, 13), p + Vector2(-13, 0)])
		sheet.draw_colored_polygon(d, ink if cleared else LAND.lightened(0.1))
		d.append(d[0])
		sheet.draw_polyline(d, rim, 2.5, true)
	else:
		sheet.draw_circle(p, 12.0, ink if cleared else LAND.lightened(0.1))
		sheet.draw_arc(p, 12.0, 0, TAU, 32, rim, 2.5, true)
	if cleared:
		# its guardian is ended: crossed blades
		sheet.draw_line(p + Vector2(-6, -6), p + Vector2(6, 6), UI.GOLD.lightened(0.2), 2.0, true)
		sheet.draw_line(p + Vector2(6, -6), p + Vector2(-6, 6), UI.GOLD.lightened(0.2), 2.0, true)
	else:
		sheet.draw_circle(p, 3.5, rim.darkened(0.2))
	_name(p + Vector2(0, 38), str(r.name), 16, ink)

## Small drawings that say what kind of country it is. Only where the knight has been.
func _terrain(ink: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var u := sheet.size.y / 100.0
	var seen := func(id: String) -> bool: return Game.region_unlocked(id)
	# the northern range is visible from everywhere: it is drawn always, faint until reached
	var range_a := 1.0 if seen.call("citadel") else 0.4
	for i in 16:
		var p := Vector2(rng.randf_range(0.48, 0.80), rng.randf_range(0.08, 0.27)) * sheet.size
		if p.distance_to(_at("citadel")) < u * 5.0:
			continue
		_peak(p, u * rng.randf_range(2.6, 4.4), Color(ink, 0.75 * range_a), true)
	# the forest
	if seen.call("blackwood"):
		for i in 34:
			var p := (Vector2(PLACE.blackwood) + Vector2(rng.randf_range(-0.11, 0.11), rng.randf_range(-0.12, 0.10))) * sheet.size
			if p.distance_to(_at("blackwood")) < u * 4.5:
				continue
			var h := u * rng.randf_range(1.6, 2.6)
			sheet.draw_line(p, p + Vector2(0, -h * 0.5), Color(ink, 0.7), 1.0)
			sheet.draw_colored_polygon(PackedVector2Array([p + Vector2(-h * 0.45, -h * 0.4), p + Vector2(0, -h * 1.5), p + Vector2(h * 0.45, -h * 0.4)]), Color(0.20, 0.27, 0.17, 0.8))
	# broken walls by the gate
	if seen.call("courtyard"):
		for off: Vector2 in [Vector2(-5.5, -3.5), Vector2(5.0, -4.5)]:
			var p := _at("courtyard") + off * u
			for k in 3:
				sheet.draw_rect(Rect2(p + Vector2(k * u * 0.9 - u * 1.3, -u * (1.2 + (k % 2) * 0.6)), Vector2(u * 0.7, u * (1.2 + (k % 2) * 0.6))), Color(ink, 0.6))
	# the cathedral: a spire, and smoke that has not stopped
	if seen.call("cathedral"):
		var p := _at("cathedral") + Vector2(-5.5, -1.5) * u
		sheet.draw_colored_polygon(PackedVector2Array([p + Vector2(-u, 0), p + Vector2(-u, -u * 2.2), p + Vector2(0, -u * 5.0), p + Vector2(u, -u * 2.2), p + Vector2(u, 0)]), Color(ink, 0.7))
		for k in 3:
			sheet.draw_arc(p + Vector2(u * (0.8 + k * 0.9), -u * (5.6 + k * 0.9)), u * (0.7 + k * 0.25), PI * 0.9, PI * 2.1, 10, Color(UI.CRIMSON, 0.55), 1.5, true)
	# the crypt: low arches at the waterline
	if seen.call("crypt"):
		for k in 3:
			var p := _at("crypt") + Vector2(-7.0 + k * 2.2, 0.5 + (k % 2) * 1.2) * u
			sheet.draw_arc(p, u * 0.9, PI, TAU, 10, Color(ink, 0.65), 1.5, true)
			sheet.draw_line(p + Vector2(-u * 1.3, u * 0.5), p + Vector2(u * 1.3, u * 0.5), Color(0.30, 0.40, 0.44, 0.7), 1.0)
	# the roost: a broken cone, burning
	if seen.call("roost"):
		var p := _at("roost") + Vector2(-6.5, 1.0) * u
		_peak(p, u * 4.2, Color(ink, 0.8), false)
		for k in 3:
			sheet.draw_line(p + Vector2((k - 1) * u * 0.7, -u * 4.4), p + Vector2((k - 1) * u * 1.4, -u * (5.8 + (k % 2))), Color(UI.CRIMSON.lightened(0.1), 0.8), 1.5, true)
	# the throne: a tall hall on a rise
	if seen.call("throne"):
		var p := _at("throne") + Vector2(5.5, -1.0) * u
		sheet.draw_rect(Rect2(p + Vector2(-u * 1.2, -u * 3.6), Vector2(u * 2.4, u * 3.6)), Color(ink, 0.7))
		for k in 3:
			sheet.draw_colored_polygon(PackedVector2Array([p + Vector2((k - 1) * u * 0.9 - u * 0.4, -u * 3.6), p + Vector2((k - 1) * u * 0.9, -u * (4.8 + (1 - absi(k - 1)) * 0.7)), p + Vector2((k - 1) * u * 0.9 + u * 0.4, -u * 3.6)]), Color(ink, 0.7))
	# the deep: rings going down
	if seen.call("deep"):
		for k in 4:
			sheet.draw_arc(_at("deep") + Vector2(0, k * u * 0.25), u * (5.4 - k * 0.9), 0.15, PI - 0.15, 18, Color(ink, 0.25 + k * 0.1), 1.0, true)

func _peak(p: Vector2, h: float, col: Color, snow: bool) -> void:
	var a := p + Vector2(-h * 0.7, 0)
	var top := p + Vector2(0, -h)
	var b := p + Vector2(h * 0.7, 0)
	sheet.draw_polyline(PackedVector2Array([a, top, b]), col, 1.5, true)
	sheet.draw_line(top, p + Vector2(h * 0.12, -h * 0.25), Color(col, col.a * 0.6), 1.0, true)
	sheet.draw_line(top + Vector2(h * 0.2, h * 0.3), p + Vector2(h * 0.38, -h * 0.1), Color(col, col.a * 0.45), 1.0, true)
	if snow:
		sheet.draw_colored_polygon(PackedVector2Array([top, top + Vector2(-h * 0.2, h * 0.29), top + Vector2(0, h * 0.2), top + Vector2(h * 0.2, h * 0.29)]), Color(0.93, 0.93, 0.9, col.a))

func _ornaments(ink: Color) -> void:
	var s := sheet.size
	# the name of the country
	var f := UI.font("title")
	sheet.draw_string(f, Vector2(26, 46), "VAELORA", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(ink, 0.9))
	sheet.draw_line(Vector2(26, 54), Vector2(176, 54), Color(BRASS.darkened(0.2), 0.9), 1.5)
	sheet.draw_string(UI.font("body"), Vector2(26, 72), "as surveyed, and as it stands", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(ink, 0.7))
	# a compass, bottom right
	var c := s - Vector2(52, 56)
	sheet.draw_arc(c, 22.0, 0, TAU, 32, Color(ink, 0.6), 1.0, true)
	for i in 4:
		var d := Vector2.from_angle(i * PI * 0.5 - PI * 0.5)
		var side := d.orthogonal() * 4.0
		sheet.draw_colored_polygon(PackedVector2Array([c + d * (30.0 if i == 0 else 22.0), c + side, c - side]), Color(ink, 0.85) if i == 0 else Color(ink, 0.45))
	sheet.draw_string(UI.font("head"), c + Vector2(-5, -34), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ink, 0.8))
	# the key, bottom left
	var k := Vector2(26, s.y - 22)
	sheet.draw_arc(k + Vector2(6, -5), 6.0, 0, TAU, 16, BRASS, 2.0, true)
	sheet.draw_string(UI.font("body"), k + Vector2(18, 0), "the road", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(ink, 0.8))
	var k2 := k + Vector2(96, 0)
	var dd := PackedVector2Array([k2 + Vector2(6, -11), k2 + Vector2(12, -5), k2 + Vector2(6, 1), k2 + Vector2(0, -5), k2 + Vector2(6, -11)])
	sheet.draw_polyline(dd, UI.CRIMSON, 2.0, true)
	sheet.draw_string(UI.font("body"), k2 + Vector2(18, 0), "a side road", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(ink, 0.8))
	var k3 := k2 + Vector2(112, 0)
	sheet.draw_circle(k3 + Vector2(6, -5), 6.0, ink)
	sheet.draw_line(k3 + Vector2(3, -8), k3 + Vector2(9, -2), UI.GOLD.lightened(0.2), 1.5)
	sheet.draw_line(k3 + Vector2(9, -8), k3 + Vector2(3, -2), UI.GOLD.lightened(0.2), 1.5)
	sheet.draw_string(UI.font("body"), k3 + Vector2(18, 0), "guardian ended", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(ink, 0.8))
