class_name ShopScreen
extends Control
## Orren's counter: what he sells (and what he will sell later, shown locked with the line that says when),
## a stall of shards and ore, and what he will buy. The left is the list, the right the piece itself turning,
## its figures against what is worn, and the one button that spends gold.
## Browsing writes nothing: only Buy, the stall's buttons, Sell and Equip change the journey.

const MODES := ["Wares", "Materials", "Sell"]
const FILTERS := [["All", []], ["Blades", ["weapon"]], ["Shields", ["shield"]], ["Armour", ["helm", "chest", "shoulders", "gauntlets", "legs", "boots"]], ["Trinkets", ["ring", "relic"]]]
const CONFIRM_FROM := 500          # a purchase at or above this, or taking most of the purse, asks first

var host: Node                     # the Sanctuary (layer, backdrop)
var mode := "Wares"
var filter := 0
var sel := ""                      # the item in the detail panel
var bought := ""                   # the item just bought: the panel offers Equip / Inspect for it
var rows: Array = []               # what the list shows now (catalogue entries, or ids when selling)
var stage: ItemStage
var buy_btn: Button
var sell_btn: Button
var dialog: Control
var inspect: ArmoryInspect

var _modes: HBoxContainer
var _filters: HBoxContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _detail: VBoxContainer
var _info: VBoxContainer
var _right: Control
var _buttons := {}

func _init(sanctuary: Node, start_mode: String = "Wares", start_item: String = "") -> void:
	host = sanctuary
	mode = start_mode if MODES.has(start_mode) else "Wares"
	sel = start_item

func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scrim := UI.full(ColorRect.new())
	scrim.color = Color(0.01, 0.01, 0.014, 0.74)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.offset_left = -40
	scrim.offset_right = 40
	scrim.offset_bottom = 40
	add_child(scrim)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	UI.full(row)
	add_child(row)
	# --- the list
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	_modes = HBoxContainer.new()
	_modes.add_theme_constant_override("separation", 6)
	left.add_child(_modes)
	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override("separation", 4)
	left.add_child(_filters)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)
	# --- the piece
	var p := UI.panel(Color(0.03, 0.03, 0.036, 0.9), Color(0.3, 0.27, 0.2))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = 1.12
	row.add_child(p)
	_right = p
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 4)
	p.add_child(_detail)
	stage = ItemStage.new()
	stage.body = str(Game.profile.get("body", "m"))
	stage.custom_minimum_size.y = 210
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(stage)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 3)
	_detail.add_child(_info)
	UI.corners(p, UI.GOLD_DIM, 12.0)
	refresh()

func leave() -> void:
	if inspect and is_instance_valid(inspect):
		inspect.queue_free()
	if dialog and is_instance_valid(dialog):
		dialog.queue_free()
	ItemModel.clear()

## The journey changed (a purchase, a sale, anything): the lists are read again; the selection is kept when it can be.
func on_profile() -> void:
	refresh()

# ================================================================ the list
func catalogue() -> Array:
	var out: Array = Game.shop_catalog()
	# one-of-a-kind pieces sold to him can be had back
	for it in Game.shop_stock():
		if it.get("buyback", false):
			out.append({"id": it.id, "item": Db.item(it.id), "price": int(it.price), "available": true, "affordable": int(Game.profile.gold) >= int(it.price),
				"unlock_text": "", "slot": it.slot, "buyback": true})
	var want: Array = FILTERS[filter][1]
	return out.filter(func(e): return want.is_empty() or want.has(e.slot))

func refresh() -> void:
	GearUI.clear(_modes)
	for m: String in MODES:
		var b := GearUI.chip(m, m == mode, 150)
		b.pressed.connect(func(): set_mode(m))
		_modes.add_child(b)
	GearUI.clear(_filters)
	_filters.visible = mode == "Wares"
	for i in FILTERS.size():
		var fb := GearUI.chip(str(FILTERS[i][0]), i == filter, 0, 16)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.pressed.connect(func():
			filter = i
			refresh())
		_filters.add_child(fb)
	GearUI.clear(_list)
	_buttons.clear()
	_right.visible = mode != "Materials"
	match mode:
		"Wares": _fill_wares()
		"Materials": _fill_materials()
		"Sell": _fill_sell()
	_fill_detail()

func set_mode(m: String) -> void:
	mode = m
	bought = ""
	sel = ""
	_scroll.scroll_vertical = 0
	refresh()

func select(id: String) -> void:
	if id != bought:
		bought = ""
	sel = id
	for k: String in _buttons:
		_paint_row(_buttons[k], k == sel)
	_fill_detail()

func _paint_row(b: Button, on: bool) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
		sb.bg_color = Color(0.1, 0.09, 0.07, 0.95) if on else Color(0.055, 0.055, 0.065, 0.9)
		sb.border_color = UI.GOLD if on else b.get_theme_color("font_color")
		if not on:
			sb.set_border_width_all(1)
			sb.border_width_left = 4
		b.add_theme_stylebox_override(state, sb)

func _fill_wares() -> void:
	rows = catalogue()
	if rows.is_empty():
		_list.add_child(UI.wrapped("Orren has nothing of this kind left to sell you. What remains must be taken.", GearUI.TEXT, UI.DIM, 400))
	var ids: Array = rows.map(func(e): return str(e.id))
	if bought == "" and not ids.has(sel):
		sel = str(ids[0]) if not ids.is_empty() else ""
	for e: Dictionary in rows:
		var b := GearUI.item_row(e.item, str(e.id) == sel, not e.available)
		if not e.available:
			GearUI.right(b, "%d" % int(e.price), Color(0.5, 0.48, 0.44), "lock")
		else:
			GearUI.right(b, ("%d" % int(e.price)) + (" · back" if e.get("buyback", false) else ""), UI.GOLD if e.affordable else GearUI.BAD.lerp(UI.DIM, 0.35))
		b.pressed.connect(func(): select(str(e.id)))
		_list.add_child(b)
		_buttons[str(e.id)] = b

func _fill_sell() -> void:
	rows = Game.sorted_items()
	if not rows.has(sel):
		sel = str(rows[0]) if not rows.is_empty() else ""
	for id: String in rows:
		var it: Dictionary = Db.item(id)
		if it.is_empty():
			continue
		var lvl := Game.upgrade_level(id)
		var why := Game.sell_block(id)
		var b := GearUI.item_row(it, id == sel, why != "", str(it.name) + (" +%d" % lvl if lvl > 0 else ""))
		if why != "":
			GearUI.right(b, why, UI.GOLD_DIM.lightened(0.15))
		else:
			GearUI.right(b, "+%d" % Game.sell_price(id), UI.GOLD)
		b.pressed.connect(func(): select(id))
		_list.add_child(b)
		_buttons[id] = b

func _fill_materials() -> void:
	_list.add_child(UI.wrapped("Shards and ore for the forge. Orren sells the ore of any region you have cleared; he buys none of it back.", GearUI.TEXT, UI.DIM, 500))
	for m: Dictionary in Game.materials_list():
		var id := str(m.id)
		var price := Game.material_price(id)
		var card := UI.panel(Color(0.045, 0.045, 0.055, 0.92), Color(0.22, 0.2, 0.16))
		card.get_theme_stylebox("panel").set_content_margin_all(10)
		_list.add_child(card)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		card.add_child(h)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		top.add_child(UI.label(str(m.name), 24, UI.BONE, "bold"))
		top.add_child(UI.label("held %d" % int(m.count), GearUI.TEXT, UI.GOLD if int(m.count) > 0 else UI.DIM))
		v.add_child(top)
		var desc := UI.wrapped(str(m.desc), GearUI.TEXT, UI.DIM)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(desc)
		if price <= 0:
			var why := "One to a guardian. Never sold." if id == "m_core" else "Not stocked yet. Clear the land it comes from."
			var no := UI.wrapped(why, GearUI.TEXT, UI.GOLD_DIM.lightened(0.15), 300)
			no.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			no.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(no)
			continue
		for n: int in [1, 5]:
			var b := UI.button("%d for %d" % [n, price * n], 17, 150)
			b.custom_minimum_size.y = 56
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.focus_mode = Control.FOCUS_NONE
			b.disabled = int(Game.profile.gold) < price * n
			b.tooltip_text = "Not enough gold" if b.disabled else ""
			b.pressed.connect(func():
				if Game.buy_material(id, n):
					Sfx.play("loot", -5.0))
			h.add_child(b)
			_buttons["%s×%d" % [id, n]] = b

# ================================================================ the piece
func _entry(id: String) -> Dictionary:
	for e in rows:
		if e is Dictionary and str(e.id) == id:
			return e
	return {}

func _line(text: String, color: Color = UI.BONE, kind: String = "body") -> Label:
	var l := UI.wrapped(text, GearUI.TEXT, color, 0.0, kind)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _fill_detail() -> void:
	GearUI.clear(_info)
	buy_btn = null
	sell_btn = null
	if mode == "Materials":
		return
	var it: Dictionary = Db.item(sel)
	if it.is_empty():
		stage.show_item("")
		_info.add_child(_line("Nothing chosen.", UI.DIM))
		return
	stage.show_item(sel)
	var col: Color = Db.rarity_color(it)
	var lvl := Game.upgrade_level(sel) if Game.owns(sel) else 0
	var ttl := UI.title(str(it.name) + ("  +%d" % lvl if lvl > 0 else ""), 26, col)
	ttl.clip_text = true
	ttl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_info.add_child(ttl)
	_info.add_child(GearUI.kind_row(it, col))
	if sel == bought:
		_after_purchase(it)
	elif mode == "Sell":
		_sell_detail(it)
	else:
		_ware_detail(it)

## Against what is worn: only the rows that change, the same rows the armoury shows.
func _compare_block(id: String, limit: int = 6) -> void:
	var it: Dictionary = Db.item(id)
	var worn = Game.profile.equipped.get(str(it.slot))
	var head := "AGAINST %s" % str(Db.item(str(worn)).name).to_upper() if worn != null else "AGAINST AN EMPTY SLOT"
	_info.add_child(UI.label(head, 18, UI.DIM, "head"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", -3)
	_info.add_child(grid)
	var n := 0
	for r in Game.compare(str(it.slot), id):
		if n >= limit or (int(r.better) == 0 and r.now_text == r.then_text):
			continue
		grid.add_child(GearUI.effect(r))
		n += 1
	if n == 0:
		grid.add_child(UI.label("No change to your numbers", GearUI.TEXT, UI.DIM))
	if Game.requirement_text(id) != "" and not Game.meets_requirements(id):
		_info.add_child(_line("Asks for %s: usable without, at a cost" % Game.requirement_text(id), GearUI.BAD))

func _ware_detail(it: Dictionary) -> void:
	var e := _entry(sel)
	if e.is_empty():
		return
	var price := int(e.price)
	if not e.available:
		# a goal: seen, priced, not yet for sale. The line never names the guardian.
		var lock := HBoxContainer.new()
		lock.add_theme_constant_override("separation", 8)
		lock.add_child(InvGlyph.new("lock", UI.GOLD_DIM.lightened(0.3), 1, 20.0))
		lock.add_child(_line(str(e.unlock_text) if str(e.unlock_text) != "" else "Not for sale yet.", UI.GOLD_DIM.lightened(0.3), "bold"))
		_info.add_child(lock)
	_compare_block(sel, 6 if e.available else 4)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	_info.add_child(foot)
	var gold := int(Game.profile.gold)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", -4)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_child(UI.label("%d gold" % price, 28, UI.GOLD if gold >= price else GearUI.BAD.lerp(UI.BONE, 0.25), "head"))
	pv.add_child(UI.label("You hold %d" % gold + ("" if gold >= price else "  ·  %d short" % (price - gold)), GearUI.TEXT, UI.DIM))
	foot.add_child(pv)
	buy_btn = UI.button("Buy", 22, 230)
	buy_btn.custom_minimum_size.y = 60
	buy_btn.focus_mode = Control.FOCUS_NONE
	buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not e.available:
		buy_btn.text = "LOCKED"
		buy_btn.disabled = true
	elif gold < price:
		buy_btn.text = "NOT ENOUGH GOLD"
		buy_btn.add_theme_font_size_override("font_size", 17)
		buy_btn.disabled = true
	buy_btn.pressed.connect(func(): ask_buy(sel))
	foot.add_child(buy_btn)

func _sell_detail(it: Dictionary) -> void:
	var why := Game.sell_block(sel)
	for line in Stats.item_lines(it, Game.upgrade_level(sel), Db.classes).slice(0, 4):
		var h := HBoxContainer.new()
		var k := UI.label(str(line[0]), GearUI.TEXT, UI.DIM)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(k)
		h.add_child(UI.label(str(line[1]), GearUI.TEXT, UI.BONE, "bold"))
		_info.add_child(h)
	var reason := {"Equipped": "You are wearing it. Take it off in the armoury first.", "Favourite": "Marked as a favourite. Unmark it in the armoury to sell.",
		"Keepsake": "A keepsake. Orren will not take it.", "Not for sale": "The blade you woke with. It stays.",
		"Last weapon": "Your only weapon. Orren will not leave you unarmed.", "Last one-handed blade": "Your only one-handed blade: a shield needs one."}
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	_info.add_child(foot)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", -4)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(pv)
	if why != "":
		pv.add_child(_line(str(reason.get(why, why + ".")), UI.GOLD_DIM.lightened(0.3)))
	else:
		pv.add_child(UI.label("+%d gold" % Game.sell_price(sel), 28, UI.GOLD, "head"))
		var back := "He keeps it: it can be bought back for %d." % int(ceil(Game.sell_price(sel) * float(Db.equipment.buyback_rate))) if int(it.get("price", 0)) <= 0 or not Game.shop_unlocked(it) else "He stocks these: it can be bought again."
		pv.add_child(_line(back, UI.DIM))
	sell_btn = UI.button("Sell" if why == "" else why, 22 if why == "" else 17, 230)
	sell_btn.custom_minimum_size.y = 60
	sell_btn.focus_mode = Control.FOCUS_NONE
	sell_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sell_btn.disabled = why != ""
	sell_btn.pressed.connect(func(): ask_sell(sel))
	foot.add_child(sell_btn)

func _after_purchase(it: Dictionary) -> void:
	_info.add_child(_line("Yours. Orren wraps the hilt and says nothing more about it.", UI.GOLD, "bold"))
	if not Game.is_equipped(sel):
		_compare_block(sel, 4)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	_info.add_child(foot)
	var eq := UI.button("Equipped" if Game.is_equipped(sel) else "Equip", 22, 0)
	eq.custom_minimum_size.y = 60
	eq.focus_mode = Control.FOCUS_NONE
	eq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eq.disabled = Game.is_equipped(sel)
	eq.pressed.connect(func():
		Sfx.play("ui_confirm", -4.0)
		Game.equip(sel))
	foot.add_child(eq)
	buy_btn = eq
	var ins := UI.button("Inspect", 20, 170)
	ins.custom_minimum_size.y = 60
	ins.focus_mode = Control.FOCUS_NONE
	ins.pressed.connect(open_inspect)
	foot.add_child(ins)
	var on := UI.button("Keep Browsing", 17, 190)
	on.custom_minimum_size.y = 60
	on.focus_mode = Control.FOCUS_NONE
	on.pressed.connect(func():
		bought = ""
		sel = ""
		refresh())
	foot.add_child(on)

func open_inspect() -> void:
	if sel == "" or (inspect and is_instance_valid(inspect)):
		return
	inspect = ArmoryInspect.new(GearUI.inspect_entry(sel), str(Game.profile.get("body", "m")), str(Db.item(sel).get("desc", "")))
	(host.get("layer") as Node).add_child(inspect)

# ================================================================ spending
## Buy, asking first when it is a large part of the purse. Returns true when a question was put instead of buying.
func ask_buy(id: String) -> bool:
	var price := Game.buy_price(id)
	if price <= 0 or Game.owns(id) or int(Game.profile.gold) < price:
		return false
	if price >= CONFIRM_FROM or price * 2 > int(Game.profile.gold):
		dialog = UI.confirm(host.get("layer"), "Buy " + str(Db.item(id).name), "%d gold. You hold %d and will have %d left." % [price, int(Game.profile.gold), int(Game.profile.gold) - price],
			"Buy", func(): buy(id))
		return true
	buy(id)
	return false

func buy(id: String) -> bool:
	bought = id
	sel = id
	if not Game.buy(id):          # (the profile change it announces rebuilds the lists, with `bought` already set)
		bought = ""
		return false
	Sfx.play("loot", -3.0)
	return true

func ask_sell(id: String) -> void:
	if Game.sell_block(id) != "":
		return
	dialog = UI.confirm(host.get("layer"), "Sell " + str(Db.item(id).name), "Orren gives %d gold. Its forge work goes with it." % Game.sell_price(id), "Sell", func():
		if Game.sell(id):
			Sfx.play("loot", -3.0))
