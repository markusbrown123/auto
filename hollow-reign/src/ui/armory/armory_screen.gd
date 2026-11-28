class_name ArmoryScreen
extends Control
## The armoury (equipment screen). The knight stands full height in the middle of the screen on a clean, lit
## display stage (KnightStage), and nothing is ever drawn over it: the equipment slots are icon tiles in a column
## down each side of the figure (armour on the left, hands and trinkets on the right), the collection of the open
## slot is a swipe row in the panel at the far left, and the comparison against what is worn is the panel at the
## far right. Drag turns the knight, pinch / wheel / + - zoom toward the part being looked at.
## Nothing here writes to the save except Equip, Remove, Favourite and Sort; browsing dresses the backdrop's
## knight from `Game.trial_profile` (a copy).
##
## One function shows an item on the knight: `apply_preview(slot, id)`.

## The two columns of slot tiles, from the head down; every slot of Db.EQUIP_SLOTS has a tile.
const LEFT_COL := ["helm", "shoulders", "chest", "gauntlets", "legs", "boots"]
const RIGHT_COL := ["weapon", "shield", "offhand", "ring", "relic"]
const RAIL := LEFT_COL + RIGHT_COL
const TITLE := {"weapon": "Weapons", "shield": "Shields", "offhand": "Off Hand", "helm": "Helms", "chest": "Cuirasses", "shoulders": "Pauldrons",
	"gauntlets": "Gauntlets", "legs": "Greaves", "boots": "Boots", "ring": "Rings", "relic": "Relics"}
const GOOD := Color("#8fb37a")
const BAD := Color("#c2574a")
const FOV := 36.0
const UPGRADABLE := ["weapon", "shield", "helm", "chest", "shoulders", "gauntlets", "legs", "boots"]
## For each slot: [the bone a close-up goes to, the knight's facing (radians; 0 faces the camera, more shows its
## right side), stance ("rest": arms down; "arms": the weapon's guard)]. Entering a slot always shows the whole
## knight, turned to show that part; the close-up (Close Up, a double tap, or zooming) goes to the bone.
const FOCUS := {
	"": ["", 0.0, ""],
	"helm": ["Head", 0.25, "rest"],
	"chest": ["Spine2", 0.2, "rest"],
	"shoulders": ["RightArm", 0.45, "rest"],
	"gauntlets": ["RightForeArm", 0.3, "rest"],
	"legs": ["RightLeg", 0.25, "rest"],
	"boots": ["RightFoot", 0.3, "rest"],
	"weapon": ["RightHand", 0.55, "arms"],
	"shield": ["LeftForeArm", -0.8, "arms"],
	"offhand": ["LeftHand", -0.5, "arms"],
	"ring": ["RightHand", 0.2, "rest"],
	"relic": ["", 0.2, "rest"],
}
const CLOSE_ZOOM := 0.42           # how near Close Up goes (KnightStage.zoom)
const IDLE := {"sword": "ss_idle", "axe": "ss_idle", "greatsword": "th_idle", "dual": "dw_idle"}
const PACK := {"sword": "ss", "axe": "ss", "greatsword": "th", "dual": "dw"}
## Cuts looked at on the knight and found to start and end in the stance; the metadata rule below is the fallback.
const ATTACK_PREFER := {"ss": "ss_cut_r_high", "th": "th_cut_dl2", "dw": "dw_cut_r"}
const TILE_W := 78.0

var host: Node                    # the Sanctuary (open_forge, refresh_purse, layer)
var backdrop: Backdrop
var slot := "weapon"
var entries: Array = []
var previewing := ""              # the item the knight wears that is not equipped ("" = the equipped look)
var compare_on := false
var last_change := ""            # what the last apply_preview changed on the figure
var focused := false              # the camera is close on the slot's part (false: the whole knight)
var carousel: ItemCarousel
var inspect: ArmoryInspect
var stage_view: KnightStage

var _rail := {}
var _cols: Array = []
var _title: Label
var _count: Label
var _sort: Button
var _grid_btn: Button
var _grid: Control
var _name: Label
var _meta: HBoxContainer
var _state: Label
var _note: Label
var _extra: Label                 # set progress, an unmet requirement, a keen edge
var _stats: VBoxContainer
var _stats_head: Label
var _mastery: HBoxContainer
var _equip: Button
var _upgrade: Button
var _compare: Button
var _inspect_btn: Button
var _fav: Button
var _fav_star: InvGlyph
var _pad: Control
var _acts: Control
var _foot: Control
var _tag: Label
var _act: Button
var _focus_btn: Button
var _detail_due := -1.0           # seconds until the stat block is brought up to date
var _preview_due := -1.0          # seconds until the knight is dressed in the middle item
var _preview_want := ""
var _preview_paths: Array = []
var _preview_animate := false
var _applied_id := "?"
var _preview_waiting := false
var _last_settle := -10.0
var _rapid := false
var _clock := 0.0
var _first_frame := true
var _clip_meta := {}
var _demo: Array = []
var _demo_drag := {}

func _init(sanctuary: Node, bd: Backdrop, start_slot: String, start_item: String = "") -> void:
	host = sanctuary
	backdrop = bd
	slot = start_slot if RAIL.has(start_slot) else "weapon"
	if start_item != "" and RAIL.has(str(Db.item(start_item).get("slot", ""))):
		slot = str(Db.item(start_item).slot)
	set_meta("start_item", start_item)

func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v = JSON.parse_string(FileAccess.get_file_as_string("res://assets/anim/clip_meta.json"))
	if v is Dictionary:
		_clip_meta = v.get("clips", {})
	_build()
	# the knight: the armoury's own rig, studio light, a longer lens, on the display stage
	backdrop.rig_script = ArmoryRig
	backdrop.cam_speed = 5.0
	backdrop.cam_drift = 0.12
	backdrop.cam_fov = FOV
	backdrop.studio(true, -1.0, int(Game.settings.get("quality", 2)) > 0)
	stage_view = KnightStage.new(backdrop, "studio")
	backdrop.refresh_knight()
	_rig_ready()
	_enter_slot(slot, str(get_meta("start_item")))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--armory_demo="):
			for step: String in a.trim_prefix("--armory_demo=").split(",", false):
				var f := step.split(":")
				if f.size() >= 2:
					_demo.append([float(f[0]), f[1], f[2] if f.size() > 2 else "", f[3] if f.size() > 3 else ""])

## Puts the backdrop back as the other tabs expect it: the equipped look, the ordinary rig, no studio light.
func leave() -> void:
	if inspect and is_instance_valid(inspect):
		inspect.queue_free()
	previewing = ""
	ItemModel.clear()
	if stage_view:
		stage_view.close()
		stage_view = null
	backdrop.rig_script = null
	backdrop.studio(false)
	backdrop.cam_speed = 1.6
	backdrop.cam_drift = 1.0
	backdrop.cam_fov = 50.0
	backdrop.refresh_knight()

# ================================================================ building
func _btn(text: String, w: float, size: int = 20) -> Button:
	var b := UI.button(text, size, w)
	b.focus_mode = Control.FOCUS_NONE
	return b

func _side_panel() -> PanelContainer:
	var p := UI.panel(Color(0.025, 0.025, 0.03, 0.9), Color(0.26, 0.24, 0.19))
	p.get_theme_stylebox("panel").set_content_margin_all(8)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = 1.0
	p.custom_minimum_size.x = 300
	UI.corners(p, UI.GOLD_DIM, 10.0)
	return p

func _clipped(text: String, size: int, color: Color, kind: String = "body") -> Label:
	var l := UI.label(text, size, color, kind)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full(row)
	add_child(row)
	# ---------------- far left: the collection of the open slot
	var lp := _side_panel()
	row.add_child(lp)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lp.add_child(left)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_title = UI.title("", 22)
	head.add_child(_title)
	_count = _clipped("", 20, UI.DIM)
	head.add_child(_count)
	left.add_child(head)
	var case := UI.panel(Color(0.012, 0.012, 0.016, 0.9), Color(0.2, 0.19, 0.16))
	case.get_theme_stylebox("panel").set_content_margin_all(1)
	case.size_flags_vertical = Control.SIZE_EXPAND_FILL
	case.custom_minimum_size.y = 110     # the least it can be while a spoken line lifts the hub's bottom edge on a phone
	left.add_child(case)
	carousel = ItemCarousel.new()
	carousel.body = str(Game.profile.get("body", "m"))
	case.add_child(carousel)
	carousel.centred.connect(_on_centred)
	carousel.settled.connect(_on_settled)
	carousel.tapped.connect(func(_i: int): _open_inspect())
	_name = _clipped("", 24, UI.BONE, "head")
	left.add_child(_name)
	_meta = HBoxContainer.new()
	_meta.add_theme_constant_override("separation", 8)
	_meta.custom_minimum_size.y = 26
	left.add_child(_meta)
	_note = _clipped("", 20, UI.DIM)
	left.add_child(_note)
	_extra = _clipped("", 20, UI.GOLD_DIM.lightened(0.25))
	left.add_child(_extra)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	left.add_child(tools)
	_sort = _btn("", 0, 16)
	_sort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sort.clip_text = true
	_sort.pressed.connect(func():
		var mode := str(Game.profile.get("inv_sort", "equipped"))
		Game.set_sort(Game.SORTS[(Game.SORTS.find(mode) + 1) % Game.SORTS.size()])
		_enter_slot(slot, _centre_id()))
	tools.add_child(_sort)
	_grid_btn = _btn("Grid", 84, 16)
	_grid_btn.pressed.connect(func(): _show_grid(_grid == null))
	tools.add_child(_grid_btn)
	_fav = _btn("", 64)
	_fav.tooltip_text = "Favourite: cannot be sold"
	_fav_star = InvGlyph.new("star", UI.DIM, 0, 26.0)
	_fav_star.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_fav_star.offset_left = -13
	_fav_star.offset_right = 13
	_fav_star.offset_top = -13
	_fav_star.offset_bottom = 13
	_fav.add_child(_fav_star)
	_fav.pressed.connect(func():
		Game.toggle_favourite(_centre_id())
		_sync_flags()
		_fill_detail())
	tools.add_child(_fav)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 6)
	left.add_child(acts)
	_acts = acts
	_equip = _btn("Equip", 0, 22)
	_equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equip.pressed.connect(_do_equip)
	acts.add_child(_equip)
	_upgrade = _btn("Upgrade", 146, 18)
	_upgrade.tooltip_text = "Take it to Orren's forge"
	_upgrade.pressed.connect(func():
		var id := _centre_id()
		if not Game.owns(id) and Game.buy_price(id) > 0:
			host.call("open_shop", id)
		else:
			host.call("open_forge", id))
	acts.add_child(_upgrade)
	# ---------------- the two columns of slot tiles either side of the knight
	for col: Array in [LEFT_COL, RIGHT_COL]:
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 8)
		c.alignment = BoxContainer.ALIGNMENT_CENTER
		c.custom_minimum_size.x = TILE_W
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cols.append(c)
		for s: String in col:
			c.add_child(_tile(s, col == LEFT_COL))
		c.resized.connect(_size_tiles.bind(c))
		if col == LEFT_COL:
			row.add_child(c)
			# ---------------- the middle: the knight, unobstructed; only its own controls sit under its feet
			_pad = Control.new()
			_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_pad.size_flags_stretch_ratio = 1.35
			_pad.mouse_filter = Control.MOUSE_FILTER_STOP
			_pad.gui_input.connect(_pad_input)
			row.add_child(_pad)
			_build_foot()
		else:
			row.add_child(c)
	# ---------------- far right: what it does against what is worn, and the ways on from here
	var rp := _side_panel()
	row.add_child(rp)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rp.add_child(right)
	_tag = _clipped("", 20, UI.GOLD, "head")
	right.add_child(_tag)
	_state = _clipped("", 20, UI.BONE, "bold")
	right.add_child(_state)
	right.add_child(UI.rule(Color(0.3, 0.27, 0.2)))
	_stats_head = _clipped("", 17, UI.DIM, "head")
	right.add_child(_stats_head)
	var psc := ScrollContainer.new()
	psc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	psc.custom_minimum_size.y = 60
	psc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(psc)
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", -4)
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	psc.add_child(_stats)
	_mastery = HBoxContainer.new()
	_mastery.add_theme_constant_override("separation", 8)
	right.add_child(_mastery)
	var racts := HBoxContainer.new()
	racts.add_theme_constant_override("separation", 6)
	right.add_child(racts)
	_compare = _btn("Compare", 0, 20)
	_compare.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compare.tooltip_text = "Equipped figures beside these"
	_compare.pressed.connect(func():
		compare_on = not compare_on
		_fill_detail())
	racts.add_child(_compare)
	_inspect_btn = _btn("Inspect", 0, 20)
	_inspect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspect_btn.tooltip_text = "The piece alone, close, to turn"
	_inspect_btn.pressed.connect(_open_inspect)
	racts.add_child(_inspect_btn)

func _tile(s: String, left_side: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(TILE_W, UI.TAP)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = str(TITLE[s])
	b.set_meta("left", left_side)
	var g := InvGlyph.new(s, UI.DIM, 0, 32.0)
	g.name = "Glyph"
	g.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	g.offset_left = -16
	g.offset_right = 16
	g.offset_top = -19
	g.offset_bottom = 13
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(g)
	# the worn piece's forge level, small, under the icon
	var lv := UI.label("", 14, UI.DIM, "bold")
	lv.name = "Level"
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lv.offset_top = -20
	lv.offset_bottom = -1
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lv)
	b.pressed.connect(func():
		Sfx.play("ui_tap", -6.0)
		if s == slot:
			_set_focus(not focused)
		else:
			_enter_slot(s))
	_rail[s] = b
	return b

## The tiles are square when there is room and never shorter than a finger.
func _size_tiles(c: VBoxContainer) -> void:
	var n := c.get_child_count()
	if n == 0:
		return
	var h := clampf((c.size.y - 8.0 * (n - 1)) / n, UI.TAP, TILE_W)
	for t: Control in c.get_children():
		t.custom_minimum_size.y = h

func _build_foot() -> void:
	var foot := HBoxContainer.new()
	_foot = foot
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 6)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.add_child(foot)
	_act = _btn("Attack", 120, 18)
	_act.pressed.connect(func():
		if slot == "shield":
			preview_block()
		else:
			preview_attack())
	foot.add_child(_act)
	_focus_btn = _btn("Close Up", 140, 18)
	_focus_btn.pressed.connect(func(): _set_focus(not focused))
	foot.add_child(_focus_btn)
	for z: Array in [["−", 1.18], ["+", 1.0 / 1.18]]:
		var zb := _btn(str(z[0]), 60, 26)
		zb.tooltip_text = "Zoom out" if z[1] > 1.0 else "Zoom in"
		zb.pressed.connect(func():
			stage_view.zoom_by(float(z[1]))
			focused = stage_view.zoom < 0.99
			_focus_btn.text = "FULL BODY" if focused else "CLOSE UP")
		foot.add_child(zb)

# ================================================================ the collection
func _entry(id: String) -> Dictionary:
	var it: Dictionary = Db.item(id)
	var own := Game.owns(id)
	# never come across: a silhouette, no name, and the line that says where such a thing might be had
	var unknown: bool = Game.item_state(id) == "undiscovered"
	var kind: String = str(Db.classes[it.cls].name) if it.slot == "weapon" else str(Db.SLOT_NAME[it.slot])
	var st := state_of(id)
	return {"id": id, "slot": str(it.slot), "name": ("Unknown " + kind) if unknown else str(it.name),
		"color": Db.rarity_color(it) if own else Db.rarity_color(it).lerp(Color(0.35, 0.35, 0.37), 0.55),
		"metal": str(it.get("look", {}).get("metal", it.get("look", {}).get("color", "#b8b4aa"))),
		"locked": not own, "dark": unknown, "equipped": Game.is_equipped(id), "fav": Game.is_favourite(id),
		"badge": str(st[0]) if str(st[3]) != "equipped" else "", "badge_col": st[1]}

## How an item stands for this knight, one of five plain states, as [short tag, colour, glyph, state id]:
## equipped, owned, for sale and affordable, for sale and too dear, locked (with no price, or not yet found).
static func state_of(id: String) -> Array:
	if Game.is_equipped(id):
		return ["EQUIPPED", UI.GOLD, "", "equipped"]
	if Game.owns(id):
		return ["OWNED", UI.BONE, "", "owned"]
	if Game.item_state(id) == "undiscovered":
		return ["UNKNOWN", UI.DIM, "lock", "locked"]
	var price := Game.buy_price(id)
	if price > 0:
		var gold := int(Game.profile.get("gold", 0))
		if gold >= price:
			return ["FOR SALE · %d GOLD" % price, GOOD, "", "affordable"]
		return ["%d GOLD · %d SHORT" % [price, price - gold], BAD, "", "dear"]
	return ["LOCKED", UI.GOLD_DIM.lightened(0.3), "lock", "locked"]

## What is held, in the chosen order, then what this journey has still to offer: the pieces already come across
## (in Orren's stock, seen, heard of) by rank, then the ones never met, as silhouettes.
func _build_entries() -> Array:
	var out: Array = []
	for id: String in Game.sorted_items([slot]):
		out.append(_entry(id))
	var rest: Array = []
	for it in Db.item_list:
		if it.slot == slot and not Game.owns(it.id) and (int(it.get("ng_min", 0)) <= int(Game.profile.get("ng", 0)) or Game.is_discovered(str(it.id))):
			rest.append(it)
	rest.sort_custom(func(a, b):
		var da := Game.is_discovered(str(a.id))
		var db := Game.is_discovered(str(b.id))
		return da and not db if da != db else Db.rarity_rank(a) < Db.rarity_rank(b))
	for it in rest:
		out.append(_entry(str(it.id)))
	return out

func _sync_flags() -> void:
	for i in entries.size():
		var e: Dictionary = entries[i]
		var fresh := _entry(str(e.id))
		if fresh.locked != e.locked:
			# bought or found while the screen was open: the list is rebuilt around it
			_enter_slot(slot, _centre_id())
			return
		e.equipped = fresh.equipped
		e.fav = fresh.fav
	carousel.refresh()
	_paint_rail()

func _centre_id() -> String:
	return str(entries[carousel.index].id) if carousel and carousel.index < entries.size() else ""

func _centre_item() -> Dictionary:
	return Db.item(_centre_id())

func _enter_slot(s: String, want_item: String = "") -> void:
	var changed := s != slot
	slot = s
	_show_grid(false)
	entries = _build_entries()
	carousel.keep = 7
	carousel.zoom = 1.2 if slot == "weapon" else 1.08       # the middle piece is shown large
	carousel.drop = 0.0
	ItemModel.keep = 10
	var at := 0
	var equipped = Game.profile.equipped.get(slot)
	for i in entries.size():
		if str(entries[i].id) == want_item or (want_item == "" and equipped != null and str(entries[i].id) == str(equipped)):
			at = i
	carousel.set_entries(entries, at)
	_title.text = str(TITLE[slot]).to_upper()
	var held := 0
	for e: Dictionary in entries:
		if not e.locked:
			held += 1
	_count.text = "%d of %d held" % [held, entries.size()] if not entries.is_empty() else ""
	_sort.text = "SORT: " + str(Game.SORT_NAME[str(Game.profile.get("inv_sort", "equipped"))]).to_upper()
	_act.visible = slot in ["weapon", "shield"]
	_act.text = "BLOCK" if slot == "shield" else "ATTACK"
	_act.tooltip_text = "Preview a block" if slot == "shield" else "Preview a cut"
	_paint_rail()
	_fill_light()
	_fill_detail()
	if stage_view:
		stage_view.yaw_user = 0.0
	if changed or _first_frame:
		focused = false
	_preview_now(_centre_id(), false)
	_apply_stance()
	_set_focus(focused)

func _paint_rail() -> void:
	for s: String in _rail:
		var b: Button = _rail[s]
		var id = Game.profile.equipped.get(s)
		var edge: Color = Db.rarity_color(Db.item(str(id))) if id != null else Color(0.24, 0.23, 0.21)
		# the worn piece's rank colours the edge that faces the knight; the open slot is ringed in gold
		var toward := "border_width_right" if bool(b.get_meta("left")) else "border_width_left"
		for state in ["normal", "hover", "pressed", "disabled"]:
			var sb := UI.box(Color(0.04, 0.04, 0.05, 0.88) if s != slot else Color(0.12, 0.1, 0.07, 0.96), UI.GOLD if s == slot else Color(0.2, 0.19, 0.17), 2 if s == slot else 1, 3, 2)
			sb.set(toward, 5)
			if s != slot:
				sb.border_color = edge
			b.add_theme_stylebox_override(state, sb)
		var g: InvGlyph = b.get_node("Glyph")
		g.color = UI.GOLD if s == slot else (UI.BONE if id != null else Color(0.4, 0.38, 0.35))
		g.queue_redraw()
		var lv: Label = b.get_node("Level")
		var n := Game.upgrade_level(str(id)) if id != null else 0
		lv.text = ("+%d" % n) if n > 0 else ("—" if id == null and s != "offhand" else "")
		b.tooltip_text = str(TITLE[s]) + (": " + str(Db.item(str(id)).name) if id != null else ": nothing worn")

# ---------------------------------------------------------------- grid
func _show_grid(on: bool) -> void:
	if _grid:
		_grid.queue_free()
		_grid = null
	if _grid_btn:
		_grid_btn.add_theme_color_override("font_color", UI.GOLD if on else UI.BONE)
	if not on:
		return
	var p := UI.panel(Color(0.03, 0.03, 0.036, 0.97), UI.GOLD_DIM)
	p.get_theme_stylebox("panel").set_content_margin_all(8)
	UI.full(p)
	p.get_theme_stylebox("panel").content_margin_top = 8
	carousel.get_parent().add_child(p)
	carousel.get_parent().move_child(p, carousel.get_index() + 1)
	_grid = p
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	sc.add_child(flow)
	for i in entries.size():
		var e: Dictionary = entries[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(maxf(140.0, (carousel.size.x - 34.0) / 2.0 - 6.0), 60)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.focus_mode = Control.FOCUS_NONE
		b.text = str(e.name)
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UI.font("bold"))
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", e.color)
		for state in ["normal", "hover", "pressed"]:
			var sb := UI.box(Color(0.06, 0.06, 0.07, 0.9), UI.GOLD if i == carousel.index else Color(0.2, 0.19, 0.17), 1, 2, 8)
			sb.border_width_left = 4
			sb.content_margin_left = 44
			if i != carousel.index:
				sb.border_color = e.color
			b.add_theme_stylebox_override(state, sb)
		var g := InvGlyph.new("lock" if e.locked else str(e.slot), Color(e.color, 0.9), 0, 26.0)
		g.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		g.offset_left = 12
		g.offset_right = 38
		g.offset_top = -13
		g.offset_bottom = 13
		b.add_child(g)
		b.pressed.connect(func():
			Sfx.play("ui_tap", -6.0)
			_show_grid(false)
			carousel.jump(i)
			_on_centred(i)
			_on_settled(i))
		flow.add_child(b)

# ================================================================ what is in the middle
func _on_centred(_i: int) -> void:
	_fill_light()
	_detail_due = 0.12
	# a finger resting on an item for a moment is as good as letting go of it
	_preview_due = 0.4
	_preview_want = _centre_id()

func _on_settled(_i: int) -> void:
	_rapid = _clock - _last_settle < 0.7
	_last_settle = _clock
	_fill_light()
	_fill_detail()
	_detail_due = -1.0
	_preview_want = _centre_id()
	_preview_due = 0.06

## Name, rank and marks: cheap, done every time the middle item changes.
func _fill_light() -> void:
	for c in _meta.get_children():
		_meta.remove_child(c)
		c.queue_free()
	if entries.is_empty():
		_name.text = str(TITLE[slot]).to_upper()
		_name.add_theme_color_override("font_color", UI.DIM)
		_note.text = empty_note(slot)
		_extra.text = ""
		_state.text = ""
		GearUI.clear(_mastery)
		return
	var e: Dictionary = entries[carousel.index]
	var it: Dictionary = Db.item(str(e.id))
	var lvl := Game.upgrade_level(str(e.id))
	_name.text = str(e.name).to_upper() + ("  +%d" % lvl if lvl > 0 else "")
	_name.add_theme_color_override("font_color", e.color)
	_meta.add_child(InvGlyph.new("pips", e.color, Game.rarity_pips(it), 15.0))
	var kind: String = "%s · %s" % [Game.rarity_name(it), Db.classes[it.cls].name if it.slot == "weapon" else Db.SLOT_NAME[it.slot]]
	if it.has("weight") and Db.equipment.weights.has(it.weight) and not e.dark:
		kind += " · " + str(Db.equipment.weights[it.weight].name)
	var kl := _clipped(kind if not e.dark else "Not yet found", 20, e.color)
	_meta.add_child(kl)
	_fill_mastery(e, it, lvl)
	var st := state_of(str(e.id))
	_state.text = str(st[0])
	_state.add_theme_color_override("font_color", st[1])
	_note.text = note_for(it)
	_note.add_theme_color_override("font_color", UI.GOLD_DIM.lightened(0.2) if e.locked else UI.DIM)
	var ex := extra_for(it)
	_extra.text = str(ex[0])
	_extra.add_theme_color_override("font_color", ex[1])

## One honest line about the item: how to come by it when it is not held, otherwise what putting it on really changes.
const PART_WORD := {"helm": "helm", "chest": "cuirass", "shoulders": "pauldrons", "arms": "gauntlets", "legs": "leg armour", "boots": "boots"}

## What an armour piece really changes on the knight. Each piece with a mesh (`part_ready`) is its own geometry on
## the figure (ArmorParts), whatever else is worn; two suits have pieces that only go together (ArmorParts.LINKED).
static func part_note(it: Dictionary) -> String:
	if not bool(it.get("part_ready", false)) or FighterRig.old_look:
		return "No piece of its own yet: changes statistics, not the knight's appearance"
	var part_slot := str(it.get("part_slot", it.slot))
	var with: Array = ArmorParts.needs(str(it.get("part", "")), part_slot)
	if with.is_empty():
		return "Worn as its own piece: changes the knight's %s" % str(PART_WORD.get(part_slot, part_slot))
	if str(ArmorParts.LINK_POLICY.get(str(it.part), "bring")) == "bring":
		return "Worn with its %s: the two are one piece" % str(PART_WORD.get(str(with[0]), str(with[0])))
	return "Shown over its own %s only: over another, that suit's %s are worn" % [str(PART_WORD.get(str(with[0]), str(with[0]))), str(PART_WORD.get(part_slot, part_slot))]

func note_for(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	var id := str(it.id)
	if not Game.owns(id):
		match Game.item_state(id):
			"undiscovered":
				return "Unknown · " + (Game.item_hint(id) if Game.item_hint(id) != "" else "Not yet found")
		var price := Game.buy_price(id)
		if price > 0:
			return "Locked · Orren sells this for %d gold" % price
		if int(it.get("price", 0)) > 0 and str(it.get("unlock_text", "")) != "":
			return "Locked · %d gold · %s" % [int(it.price), str(it.unlock_text)]
		return "Locked · " + (Game.item_hint(id) if Game.item_hint(id) != "" else "Not yet found")
	match str(it.slot):
		"chest", "helm", "gauntlets", "legs", "shoulders", "boots":
			return part_note(it)
		"ring", "relic":
			return "Worn unseen: changes statistics only"
		"weapon", "shield":
			if Duel.MODEL_ALIAS.has(id) and (ItemModel.gear_id(it) == "" or FighterRig.old_look):
				return "Shown with a borrowed blade until its own is forged"
	return str(it.get("desc", ""))

## A second line, when there is something to say: a requirement not met, a keen edge, how far a set has come.
## Returns [text, colour].
func extra_for(it: Dictionary) -> Array:
	if it.is_empty() or Game.item_state(str(it.id)) == "undiscovered":
		return ["", UI.DIM]
	var id := str(it.id)
	if Game.requirement_text(id) != "" and not Game.meets_requirements(id):
		return ["Asks for %s · usable without, at a cost" % Game.requirement_text(id), BAD]
	if it.slot == "weapon" and Game.owns(id):
		var w := Game.weapon_mods(id)
		var bits: Array = []
		if int(w.edge) > 0:
			bits.append("Keen edge: %d fight%s left" % [int(w.edge), "" if int(w.edge) == 1 else "s"])
		if int(w.grip) > 0 or int(w.ore) > 0:
			bits.append("Grip %s · %s" % [UI.roman(int(w.grip)) if int(w.grip) > 0 else "0", ["Iron", "Steel", str(Db.equipment.mods.ores.get(str(w.ore_id), {}).get("name", "Ore")), "Cored"][clampi(int(w.ore), 0, 3)]])
		return [" · ".join(bits), GOOD if int(w.edge) > 0 else UI.DIM]
	if Db.ARMOUR_SLOTS.has(str(it.slot)) and it.has("family") and it.get("set_piece", true):
		# the set as it would stand with this piece on
		for st: Dictionary in Game.set_status(Game.preview_profile(str(it.slot), id)):
			if str(st.family) != str(it.family):
				continue
			var marks: Array = []
			var next := ""
			for t: Dictionary in st.tiers:
				marks.append("%d %s" % [int(t.pieces), "✓" if t.active else "–"])
				if not t.active and next == "":
					next = "at %d: %s" % [int(t.pieces), str(t.text)]
			return ["%s set %d of 6 with this  ·  %s%s" % [st.name, int(st.pieces), "  ".join(marks), ("  ·  " + next) if next != "" else ""], UI.GOLD_DIM.lightened(0.3)]
	return ["", UI.DIM]

func _stat_row(k: String, v: String, col: Color = UI.BONE, better: int = 0, delta: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kl := UI.label(k, 22, UI.DIM)
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kl.clip_text = true
	kl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(kl)
	row.add_child(UI.label(v, 22, col, "bold"))
	if better != 0:
		row.add_child(InvGlyph.new("up" if better > 0 else "down", col, 0, 13.0))
	if delta != "":
		var dl := UI.label(delta, 20, col, "bold")
		dl.custom_minimum_size.x = 64
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(dl)
	_stats.add_child(row)

func _delta_text(r: Dictionary) -> String:
	var mag := absf(float(r.delta))
	var sg := "+" if float(r.delta) > 0.0 else "−"
	match str(r.key):
		"swing_time": return sg + "%.2fs" % mag
		"crit_mult": return sg + "%.2f" % mag
		"attack": return sg + "%.1f" % mag
		"block_eff", "mitigation": return sg + "%.0f%%" % mag
		"shield_regen": return sg + "%.1fs" % mag
	return sg + "%.0f" % mag

## The stat block: always against what is equipped. A green up-arrow is better and a red down-arrow worse
## whichever way the figure itself moved (a quicker swing is an up-arrow with a minus).
func _fill_detail() -> void:
	for c in _stats.get_children():
		_stats.remove_child(c)
		c.queue_free()
	_compare.add_theme_color_override("font_color", UI.GOLD if compare_on else UI.BONE)
	if entries.is_empty():
		_stats_head.text = ""
		_tag.text = ""
		for b: Button in [_equip, _upgrade, _compare, _inspect_btn, _fav]:
			b.disabled = true
		return
	var e: Dictionary = entries[carousel.index]
	var id := str(e.id)
	var it: Dictionary = Db.item(id)
	var own: bool = not e.locked
	var worn := Game.is_equipped(id)
	if worn:
		_stats_head.text = "EQUIPPED · ITS OWN FIGURES"
		for line in Stats.item_lines(it, Game.upgrade_level(id), Db.classes):
			_stat_row(str(line[0]) if not (it.slot == "weapon" and str(line[0]) == "Stamina") else "Stamina a swing", str(line[1]))
	else:
		var worn_id = Game.profile.equipped.get(slot)
		_stats_head.text = ("AGAINST %s" % str(Db.item(str(worn_id)).name).to_upper()) if worn_id != null else "AGAINST AN EMPTY SLOT"
		if compare_on:
			_stats_head.text += " · EQUIPPED → THIS"
		var any := false
		for r in Game.compare(id):
			var changed: bool = int(r.better) != 0 or r.now_text != r.then_text
			if not changed and not (compare_on and float(r.now) != 0.0):
				continue
			any = any or changed
			var col: Color = GOOD if int(r.better) > 0 else (BAD if int(r.better) < 0 else UI.BONE)
			if compare_on:
				_stat_row(str(r.label), "%s → %s" % [r.now_text, r.then_text], col if changed else UI.DIM, int(r.better))
			else:
				_stat_row(str(r.label), str(r.then_text), col, int(r.better), _delta_text(r) if int(r.better) != 0 else "")
		if not any and not compare_on:
			_stat_row("No change to your numbers", "")
	# --- what can be done with it
	_equip.disabled = not own or (worn and slot == "weapon")
	_equip.text = "LOCKED" if not own else (("EQUIPPED" if slot == "weapon" else "REMOVE") if worn else "EQUIP")
	_upgrade.disabled = not own or slot not in UPGRADABLE or (slot != "weapon" and Game.upgrade_level(id) >= Stats.MAX_UPGRADE)
	_upgrade.text = "PERFECTED" if own and slot in UPGRADABLE and slot != "weapon" and Game.upgrade_level(id) >= Stats.MAX_UPGRADE else "UPGRADE"
	_upgrade.tooltip_text = "Take it to Orren's forge"
	if not own and Game.buy_price(id) > 0:
		# a piece Orren sells: the way to it is his counter
		_upgrade.disabled = false
		_upgrade.text = "TO THE SHOP"
		_upgrade.tooltip_text = "Orren sells this for %d gold" % Game.buy_price(id)
	_compare.disabled = worn
	_inspect_btn.disabled = false
	_fav.disabled = not own
	var fav := Game.is_favourite(id)
	_fav_star.color = UI.GOLD if fav else UI.DIM
	_fav_star.count = 1 if fav else 0
	_fav_star.queue_redraw()

func _do_equip() -> void:
	var id := _centre_id()
	if id == "" or not Game.owns(id):
		return
	Sfx.play("ui_confirm", -4.0)
	if Game.is_equipped(id):
		Game.unequip(slot)
	else:
		Game.equip(id)

## The profile changed (equip, remove, purchase, upgrade): flags and the knight follow; the row keeps its place.
func on_profile() -> void:
	_sync_flags()
	_fill_light()
	_fill_detail()
	_preview_now(_centre_id(), false)

# ================================================================ the knight
func _rig() -> ArmoryRig:
	return backdrop.rig as ArmoryRig

func _rig_ready() -> void:
	var r := _rig()
	if r == null:
		return
	r.motion = 0.0 if Game.settings.reduce_motion else 1.0
	_apply_stance()
	r._solve(0.0)

func _weapon_class() -> String:
	return str(backdrop.look_now.get("weapon", "sword"))

## The breathing idle: the weapon class's own stance when the hands are what is being looked at,
## and a plain stand, arms down and shield by the side, when the armour is.
func _apply_stance() -> void:
	var r := _rig()
	if r == null:
		return
	var stance: String = FOCUS[slot][2]
	var clip: String = str(IDLE.get(_weapon_class(), "ss_idle"))
	if stance == "rest" and SkinDriver.has_clip("idle"):
		clip = "idle"
	r.idle_clip = clip if SkinDriver.has_clip(clip) else ""

## THE one place an item is put on the knight for looking at. `id` "" (or the equipped piece) shows what is equipped.
## Returns what changed on the figure: "" nothing visible, "weapon", "shield", "hands" or "body".
func apply_preview(preview_slot: String, id: String) -> String:
	var it: Dictionary = Db.item(id)
	var trial := {}
	if id != "" and not it.is_empty() and str(it.slot) == preview_slot and not Game.is_equipped(id):
		trial = Game.trial_profile(id)
		previewing = id
	else:
		previewing = ""
	var changed := backdrop.dress_knight(trial)
	if id != _applied_id or changed != "":
		last_change = changed      # (dressing in the same piece twice changes nothing the second time)
	_applied_id = id
	if changed == "body":
		_rig_ready()
	else:
		_apply_stance()
	_tag.text = ("ON THE KNIGHT: PREVIEW" if previewing != "" else "ON THE KNIGHT: EQUIPPED") if not entries.is_empty() else ""
	_tag.add_theme_color_override("font_color", UI.GOLD if previewing != "" else UI.DIM)
	return changed

## Dresses the knight in `id` once its models are in memory (loaded in the background; the row never waits for it).
func _preview_now(id: String, animate: bool) -> void:
	_preview_want = id
	_preview_animate = animate
	_preview_due = -1.0
	_preview_paths = _paths_for(id)
	_preview_waiting = true
	if ItemModel.ready(_preview_paths):
		_finish_preview()

func _paths_for(id: String) -> Array:
	return preview_paths(id)

## The model files the knight needs in memory before it can be dressed in `id` (loaded in the background).
static func preview_paths(id: String) -> Array:
	var it: Dictionary = Db.item(id)
	if it.is_empty():
		return []
	var out: Array = []
	var body := str(Game.profile.get("body", "m"))
	# (what the knight is dressed from: the rig still draws the older hand-held models)
	if Db.ARMOUR_SLOTS.has(str(it.slot)):
		out.append_array(ItemModel.paths(it, body))
	elif it.slot == "weapon":
		out.append(str(Duel.weapon_model(str(it.id)).weapon_model))
	elif it.slot == "shield":
		out.append("res://assets/models/%s.glb" % str(it.id))
	return out.filter(func(p): return ResourceLoader.exists(p))

func _finish_preview() -> void:
	var id := _preview_want
	_preview_waiting = false
	_preview_paths = []
	var before_cls := _weapon_class()
	var changed := apply_preview(slot, id)
	if not _preview_animate or changed == "" or changed == "body" or Game.settings.reduce_motion or _rapid:
		return
	# a deliberate change of what is in the hands: Recall for the advanced pieces, otherwise a short lower-and-raise
	var it: Dictionary = Db.item(id)
	if is_advanced(it) and play_recall(id):
		return
	var r := _rig()
	if r:
		if changed != "shield" and before_cls == _weapon_class() and PACK.get(before_cls, "") == "ss" and SkinDriver.has_clip("ss_unsheath"):
			var n := SkinDriver.clip_length("ss_unsheath")
			r.play_once("ss_unsheath", maxf(0.0, n - 0.45), n)
		else:
			r.dip()

static func is_advanced(it: Dictionary) -> bool:
	return bool(it.get("advanced", false)) or bool(it.get("recall", false)) or str(it.get("rarity", "")) == "legendary"

## The Recall presentation for advanced pieces, when that effect exists (`src/fx/recall.gd`, static
## `play(rig, item_id, short)`). Returns false when it does not, and the caller falls back to the short swap.
func play_recall(item_id: String) -> bool:
	var path := "res://src/fx/recall.gd"
	if not ResourceLoader.exists(path) or _rig() == null:
		return false
	var script = load(path)
	if not (script is Script):
		return false
	for m in (script as Script).get_script_method_list():
		if str(m.name) == "play" and (int(m.flags) & METHOD_FLAG_STATIC) != 0 and (m.args as Array).size() >= 2:
			script.callv("play", [_rig(), item_id, true].slice(0, (m.args as Array).size()))
			return true
	return false

## A cut for the weapon in hand: the preferred clip for its pack, else the shortest attack in the metadata
## that winds up from the stance and recovers to it without travelling.
func attack_clip(cls: String) -> String:
	var pack: String = str(PACK.get(cls, "ss"))
	var pref: String = str(ATTACK_PREFER.get(pack, ""))
	if SkinDriver.has_clip(pref) and str(_clip_meta.get(pref, {}).get("kind", "attack")) == "attack":
		return pref
	var best := ""
	var best_len := 1e9
	for n: String in _clip_meta:
		var m: Dictionary = _clip_meta[n]
		if str(m.get("pack", "")) != pack or str(m.get("kind", "")) != "attack" or bool(m.get("root_motion", false)):
			continue
		if float(m.get("hip_travel", 0.0)) > 0.5 or m.get("windup") == null or float(m.windup) < 0.25 or float(m.get("recovery", 0.0)) < 0.3:
			continue
		if float(m.length) < best_len and SkinDriver.has_clip(n):
			best = n
			best_len = float(m.length)
	return best if best != "" else ("sword_attack" if SkinDriver.has_clip("sword_attack") else "")

func preview_attack() -> bool:
	var r := _rig()
	var clip := attack_clip(_weapon_class())
	if r == null or clip == "":
		return false
	r.idle_clip = str(IDLE.get(_weapon_class(), "ss_idle"))
	var ok := r.play_once(clip)
	var wind: float = float(_clip_meta.get(clip, {}).get("windup", 0.3)) if _clip_meta.get(clip, {}).get("windup") != null else 0.3
	get_tree().create_timer(wind).timeout.connect(func(): Sfx.play("swing", -8.0))
	_after_act()
	return ok

func preview_block() -> bool:
	var r := _rig()
	if r == null or not r.has_shield:
		return false
	r.idle_clip = "ss_idle"
	var ok := r.play_once("ss_block", 0.0, -1.0, "ss_block_idle", 1.3)
	Sfx.play("armor", -10.0)
	_after_act()
	return ok

func _after_act() -> void:
	var r := _rig()
	if r and not r.act_finished.is_connected(_apply_stance):
		r.act_finished.connect(_apply_stance)

## Mastery of the piece in the middle, in the right-hand panel: the marks, how far, and its forge level.
func _fill_mastery(e: Dictionary, it: Dictionary, lvl: int) -> void:
	GearUI.clear(_mastery)
	if e.locked or it.is_empty():
		return
	var tier := Game.mastery_tier(str(e.id))
	var marks := InvGlyph.new("marks", UI.GOLD, tier if it.slot == "weapon" else (1 if tier == 3 else 0), 16.0)
	marks.total = 3 if it.slot == "weapon" else 1
	marks.custom_minimum_size.x = 16.0 * (2.9 if it.slot == "weapon" else 1.0)
	_mastery.add_child(UI.label("Mastery", 20, UI.DIM))
	_mastery.add_child(marks)
	_mastery.add_child(UI.label("%d/%d" % [Game.mastery_points(str(e.id)), Stats.mastery_needed(it)], 20, UI.GOLD if tier == 3 else UI.BONE))
	if slot in UPGRADABLE:
		_mastery.add_child(UI.label("· Forged +%d/%d" % [lvl, Stats.MAX_UPGRADE], 20, UI.DIM))

## What an empty slot says (only the off hand is empty for every knight: nothing is made for it yet).
static func empty_note(s: String) -> String:
	if s == "offhand":
		var w = Game.profile.get("equipped", {}).get("weapon")
		if w != null and str(Db.item(str(w)).get("cls", "")) == "dual":
			return "Your paired blades fill both hands"
		return "Nothing is made for the off hand yet"
	return "Nothing of this kind yet. The road provides."

# ---------------------------------------------------------------- camera
## Close up on the slot's part (true) or the whole knight (false). The knight is turned to show the part either way.
func _set_focus(on: bool) -> void:
	focused = on and str(FOCUS[slot][0]) != ""
	if stage_view:
		stage_view.zoom = CLOSE_ZOOM if focused else 1.0
	_focus_btn.text = "FULL BODY" if focused else "CLOSE UP"
	_focus_btn.disabled = str(FOCUS[slot][0]) == ""
	backdrop.knight_yaw = wrapf(PI + float(FOCUS[slot][1]) + (stage_view.yaw_user if stage_view else 0.0), -PI, PI)
	backdrop.turn_knight(0.0)

## The rectangle the knight must fill: the middle of the screen between the two columns of tiles, above its buttons.
func stage_rect() -> Rect2:
	var r := _pad.get_global_rect()
	var foot_h := _foot.size.y + 10.0 if _foot else 70.0
	r.size.y -= foot_h
	r.position.y += 4.0
	r.size.y -= 4.0
	return r

func _aim(snap: bool) -> void:
	if stage_view == null:
		return
	stage_view.aim(stage_rect(), get_viewport().get_visible_rect().size, str(FOCUS[slot][0]), snap)

func _pad_input(e: InputEvent) -> void:
	if stage_view == null:
		return
	if stage_view.handle(e) == "double":
		_set_focus(not focused)
		return
	focused = stage_view.zoom < 0.99
	_focus_btn.text = "FULL BODY" if focused else "CLOSE UP"

# ---------------------------------------------------------------- inspect
func _open_inspect() -> void:
	if entries.is_empty() or (inspect and is_instance_valid(inspect)):
		return
	var e: Dictionary = entries[carousel.index]
	inspect = ArmoryInspect.new(e, str(Game.profile.get("body", "m")), note_for(Db.item(str(e.id))))
	(host.get("layer") as Node).add_child(inspect)

# ================================================================ per frame
func _process(delta: float) -> void:
	_clock += delta
	if _detail_due >= 0.0:
		_detail_due -= delta
		if _detail_due < 0.0:
			_fill_detail()
	if _preview_due >= 0.0:
		_preview_due -= delta
		if _preview_due < 0.0:
			_preview_now(_preview_want, true)
	if _preview_waiting and ItemModel.ready(_preview_paths):
		_finish_preview()
	_aim(_first_frame)
	_first_frame = false
	_run_demo(delta)

# ================================================================ scripted input for captures
## --armory_demo=<t>:<action>[:<a>[:<b>]],...   e.g. 2:slot:chest,4:drag:-320:0.5,7:attack
##   slot:<slot>  item:<id>  goto:<index>  drag:<pixels>:<seconds> (a whole swipe)  hold:<pixels>:<seconds> (finger stays down)
##   release  compare  inspect  close  attack  block  grid  equip  fav  sort  focus  full  zoom:<factor>  turn:<radians>  upgrade
func _run_demo(delta: float) -> void:
	if not _demo_drag.is_empty():
		var g: Dictionary = _demo_drag
		g.t += delta
		var u := clampf(float(g.t) / maxf(float(g.dur), 0.01), 0.0, 1.0)
		carousel.drag_move(float(g.x0) + float(g.px) * u)
		if u >= 1.0:
			if bool(g.release):
				carousel.drag_end(float(g.x0) + float(g.px))
			_demo_drag = {}
	while not _demo.is_empty() and _clock >= float(_demo[0][0]):
		var st: Array = _demo.pop_front()
		var a := str(st[2])
		match str(st[1]):
			"slot": _enter_slot(a)
			"item":
				for i in entries.size():
					if str(entries[i].id) == a:
						carousel.go_to(i)
			"goto": carousel.go_to(int(a))
			"drag", "hold":
				var x0 := carousel.size.x * 0.5
				carousel.drag_begin(x0)
				_demo_drag = {"x0": x0, "px": float(a), "dur": float(st[3]) if str(st[3]) != "" else 0.4, "t": 0.0, "release": str(st[1]) == "drag"}
			"release": carousel.drag_end(carousel._last_x)
			"compare": _compare.pressed.emit()
			"inspect": _open_inspect()
			"close":
				if inspect and is_instance_valid(inspect):
					inspect.queue_free()
			"attack": preview_attack()
			"block": preview_block()
			"grid": _show_grid(_grid == null)
			"equip": _do_equip()
			"fav": _fav.pressed.emit()
			"sort": _sort.pressed.emit()
			"focus": _set_focus(true)
			"full": _set_focus(false)
			"zoom":
				stage_view.zoom = clampf(float(a), KnightStage.ZOOM_MIN, KnightStage.ZOOM_MAX)
				focused = stage_view.zoom < 0.99
			"turn": stage_view.turn(float(a))
			"upgrade": _upgrade.pressed.emit()
