class_name GearUI
extends RefCounted
## Small pieces the shop, the forge and the reward screen share: a cost written out with what is missing,
## comparison rows with their arrows, a list row for an item. Everything reads `Game`; nothing here writes.

const GOOD := Color("#8fb37a")
const BAD := Color("#c2574a")
const TEXT := 22

static func clear(c: Node) -> void:
	for k in c.get_children():
		c.remove_child(k)
		k.queue_free()

## "80 gold · 2 shards · 4 Old Iron (have 1)": each part red when the purse does not cover it.
static func cost_flow(cost: Dictionary, size: int = TEXT) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", -2)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts: Array = []        # [text, lacking]
	if int(cost.get("gold", 0)) > 0:
		parts.append(["%d gold" % int(cost.gold), int(Game.profile.gold) < int(cost.gold)])
	if int(cost.get("shards", 0)) > 0:
		var n := int(cost.shards)
		parts.append(["%d shard%s" % [n, "" if n == 1 else "s"] + ("" if int(Game.profile.shards) >= n else " (have %d)" % int(Game.profile.shards)), int(Game.profile.shards) < n])
	for m: String in cost.get("materials", {}):
		var need := int(cost.materials[m])
		var have := Game.material_count(m)
		parts.append(["%d %s" % [need, Db.material_name(m)] + ("" if have >= need else " (have %d)" % have), have < need])
	for i in parts.size():
		if i > 0:
			f.add_child(UI.label("·", size, UI.DIM))
		f.add_child(UI.label(str(parts[i][0]), size, BAD if parts[i][1] else UI.GOLD, "bold"))
	return f

## What buying the missing shards and materials from Orren would cost, as a line; "" when nothing is missing.
static func shortfall_text(cost: Dictionary) -> String:
	var lack := Game.shortfall_price(cost)
	if lack > 0:
		return "Orren sells what is missing for %d gold" % lack
	if lack < 0:
		return "Part of this cannot be bought: it is found on the road"
	return ""

## One comparison row: "Damage  15.8 → 17.4 ▲". `r` is a Game.compare()-style row.
static func effect(r: Dictionary, size: int = TEXT) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = GOOD if int(r.get("better", 0)) > 0 else (BAD if int(r.get("better", 0)) < 0 else UI.BONE)
	h.add_child(UI.label(str(r.label), size, UI.DIM))
	h.add_child(UI.label("%s → %s" % [r.now_text, r.then_text], size, col, "bold"))
	if int(r.get("better", 0)) != 0:
		h.add_child(InvGlyph.new("up" if int(r.better) > 0 else "down", col, 0, 13.0))
	return h

## A plain "label  a → b" row in the same shape, for figures that are not in the duel's table (an item's own power).
static func plain_row(label: String, a: String, b: String, better: int = 1) -> Dictionary:
	return {"label": label, "now_text": a, "then_text": b, "better": better}

## A row of a list: a rank stripe, the slot's mark, the name, and whatever the caller adds at the right (see `right`).
static func item_row(it: Dictionary, selected: bool, dim: bool = false, title: String = "") -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = UI.TAP
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = title if title != "" else str(it.get("name", "?"))
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_font_override("font", UI.font("bold"))
	b.add_theme_font_size_override("font_size", TEXT)
	var col: Color = Db.rarity_color(it)
	if dim:
		col = col.lerp(Color(0.36, 0.36, 0.38), 0.55)
	for cname: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cname, col)
	for state: String in ["normal", "hover", "pressed"]:
		var sb := UI.box(Color(0.1, 0.09, 0.07, 0.95) if selected else Color(0.055, 0.055, 0.065, 0.9), UI.GOLD if selected else Color(0.2, 0.19, 0.17), 1, 2, 8)
		sb.border_width_left = 4
		if not selected:
			sb.border_color = col
		sb.content_margin_left = 48
		sb.content_margin_right = 150
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var g := InvGlyph.new(str(it.get("slot", "weapon")), Color(col, 0.9), 0, 26.0)
	g.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	g.offset_left = 14
	g.offset_right = 40
	g.offset_top = -13
	g.offset_bottom = 13
	b.add_child(g)
	b.pressed.connect(func(): Sfx.play("ui_tap", -6.0))
	return b

## Something at the right-hand end of an `item_row`: a price, a state, a reason.
static func right(row: Button, text: String, color: Color, glyph: String = "") -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.alignment = BoxContainer.ALIGNMENT_END
	h.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	h.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	h.grow_vertical = Control.GROW_DIRECTION_BOTH
	h.offset_right = -12
	if glyph != "":
		h.add_child(InvGlyph.new(glyph, color, 1, 18.0))
	h.add_child(UI.label(text, TEXT, color, "bold"))
	row.add_child(h)

## "Rare · Shield · Heavy" with the rank's diamonds in front.
static func kind_row(it: Dictionary, col: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(InvGlyph.new("pips", col, Game.rarity_pips(it), 15.0))
	var bits: Array = [Game.rarity_name(it), str(Db.classes[it.cls].name) if it.slot == "weapon" else str(Db.SLOT_NAME.get(it.slot, it.slot))]
	if it.has("weight") and Db.equipment.weights.has(it.weight):
		bits.append(str(Db.equipment.weights[it.weight].name))
	h.add_child(UI.label(" · ".join(bits), TEXT, col))
	return h

## The entry ArmoryInspect wants for an item.
static func inspect_entry(id: String) -> Dictionary:
	var it: Dictionary = Db.item(id)
	return {"id": id, "slot": str(it.slot), "name": str(it.name), "color": Db.rarity_color(it),
		"metal": str(it.get("look", {}).get("metal", it.get("look", {}).get("color", "#b8b4aa"))), "locked": not Game.owns(id), "dark": false}

## A mode / filter chip.
static func chip(text: String, on: bool, w: float = 0.0, size: int = 17) -> Button:
	var b := UI.button(text, size, w)
	b.custom_minimum_size.y = UI.TAP
	b.focus_mode = Control.FOCUS_NONE
	if on:
		b.add_theme_color_override("font_color", UI.GOLD)
		b.add_theme_stylebox_override("normal", UI._button_box("hover"))
	return b
