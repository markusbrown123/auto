class_name ShopScreen
extends Control
## Orren's counter: what he sells (and what he will sell later, shown locked with the line that says when),
## a stall of shards and ore, and what he will buy.
## Left: the wares as a row to flick through, the middle one large and turning, its neighbours smaller and dimmed
## (`ItemCarousel`, the armoury's). Right: the gold held, the piece's name and rank, its mastery, the two or three
## figures that matter most against what is worn, Compare for the rest, and the price beside one large Buy.
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
var carousel: ItemCarousel
var compare_on := false            # every changed figure instead of the three that matter most
var buy_btn: Button
var sell_btn: Button
var dialog: Control
var inspect: ArmoryInspect

var _modes: HBoxContainer
var _filters: HBoxContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _case: Control
var _info: VBoxContainer
var _right: Control
var _buttons := {}
var _ids: Array = []               # the ids in the row, in order
var _bought_at := 0
var _demo: Array = []
var _clock := 0.0

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
	# --- the wares
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.25
	row.add_child(left)
	_modes = HBoxContainer.new()
	_modes.add_theme_constant_override("separation", 6)
	left.add_child(_modes)
	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override("separation", 4)
	left.add_child(_filters)
	var case := UI.panel(Color(0.02, 0.02, 0.026, 0.86), Color(0.3, 0.27, 0.2))
	case.get_theme_stylebox("panel").set_content_margin_all(1)
	case.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(case)
	_case = case
	carousel = ItemCarousel.new()
	carousel.body = str(Game.profile.get("body", "m"))
	carousel.zoom = 1.3
	case.add_child(carousel)
	carousel.centred.connect(func(_i: int): _on_centre())
	carousel.settled.connect(func(_i: int): _on_centre())
	carousel.tapped.connect(func(_i: int): open_inspect())
	UI.corners(case, UI.GOLD_DIM, 12.0)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)
	# --- the counter
	var p := UI.panel(Color(0.03, 0.03, 0.036, 0.92), Color(0.3, 0.27, 0.2))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(p)
	_right = p
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 3)
	p.add_child(_info)
	UI.corners(p, UI.GOLD_DIM, 12.0)
	refresh()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shop_demo="):
			for st: String in a.trim_prefix("--shop_demo=").split(",", false):
				var f := st.split(":")
				if f.size() >= 2:
					_demo.append([float(f[0]), f[1], f[2] if f.size() > 2 else ""])

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
			bought = ""
			refresh())
		_filters.add_child(fb)
	GearUI.clear(_list)
	_buttons.clear()
	_case.visible = mode != "Materials"
	_scroll.visible = mode == "Materials"
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
	compare_on = false
	_ids = []
	refresh()

## Brings an item to the middle of the row (at once: this is the screen's own doing, not a finger's).
func select(id: String) -> void:
	if not _ids.has(id):
		return
	if id != bought:
		bought = ""
	sel = id
	if _ids.has(id):
		carousel.jump(_ids.find(id))
	_fill_detail()

func _on_centre() -> void:
	var id := str(_ids[carousel.index]) if carousel.index < _ids.size() else ""
	if id == sel:
		return
	if id != bought:
		bought = ""
	sel = id
	_fill_detail()

func _row_entry(id: String, locked: bool) -> Dictionary:
	var it: Dictionary = Db.item(id)
	return {"id": id, "slot": str(it.slot), "name": str(it.name), "color": Db.rarity_color(it) if not locked else Db.rarity_color(it).lerp(Color(0.35, 0.35, 0.37), 0.5),
		"metal": str(it.get("look", {}).get("metal", it.get("look", {}).get("color", "#b8b4aa"))), "locked": locked, "dark": false,
		"equipped": Game.is_equipped(id), "fav": Game.is_favourite(id)}

## Fills the row. It is rebuilt only when what it holds has changed, so a purchase or a sale does not throw the
## pieces away and build them again.
func _set_row(ids: Array, entries: Array) -> void:
	if ids != _ids or carousel.entries.size() != entries.size():
		_ids = ids
		if not ids.has(sel):
			sel = str(ids[clampi(carousel.index, 0, ids.size() - 1)]) if not ids.is_empty() else ""
		carousel.keep = 5
		carousel.set_entries(entries, maxi(ids.find(sel), 0))
	else:
		for i in entries.size():
			carousel.entries[i] = entries[i]
		carousel.refresh()

func _fill_wares() -> void:
	rows = catalogue()
	var ids: Array = rows.map(func(e): return str(e.id))
	# the piece just bought stays where it stood until the player moves on
	if bought != "" and not ids.has(bought):
		var at := clampi(_bought_at, 0, rows.size())
		rows.insert(at, {"id": bought, "item": Db.item(bought), "price": 0, "available": true, "affordable": true, "unlock_text": "", "slot": Db.item(bought).slot, "owned": true})
		ids.insert(at, bought)
	_set_row(ids, rows.map(func(e): return _row_entry(str(e.id), not e.available)))

func _fill_sell() -> void:
	rows = Game.sorted_items().filter(func(id): return not Db.item(id).is_empty())
	_set_row(rows.duplicate(), rows.map(func(id): return _row_entry(str(id), false)))

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
	# --- the purse, always at the top
	var purse := HBoxContainer.new()
	purse.add_theme_constant_override("separation", 10)
	var pl := UI.label("YOU HOLD", 18, UI.DIM, "head")
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	purse.add_child(pl)
	purse.add_child(UI.label("%d gold" % int(Game.profile.gold), 26, UI.GOLD, "head"))
	_info.add_child(purse)
	_info.add_child(UI.rule(Color(0.3, 0.27, 0.2)))
	var it: Dictionary = Db.item(sel)
	if it.is_empty():
		_info.add_child(_line("Orren has nothing of this kind left to sell you. What remains must be taken." if mode == "Wares" else "Nothing to sell.", UI.DIM))
		return
	var col: Color = Db.rarity_color(it)
	var lvl := Game.upgrade_level(sel) if Game.owns(sel) else 0
	var ttl := UI.title(str(it.name) + ("  +%d" % lvl if lvl > 0 else ""), 28, col)
	ttl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_child(ttl)
	_info.add_child(GearUI.kind_row(it, col))
	_mastery_line(it)
	if sel == bought:
		_after_purchase(it)
	elif mode == "Sell":
		_sell_detail(it)
	else:
		_ware_detail(it)

## Mastery: how far it has come if it is held, what it takes if it is not.
func _mastery_line(it: Dictionary) -> void:
	var need := Stats.mastery_needed(it)
	var have := Game.mastery_points(sel) if Game.owns(sel) else 0
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(UI.label("Mastery", GearUI.TEXT, UI.DIM))
	var bar := UI.bar(UI.GOLD, 8)
	bar.max_value = need
	bar.value = have
	bar.custom_minimum_size.x = 150
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	h.add_child(UI.label("%d of %d fights" % [have, need], GearUI.TEXT, UI.GOLD if have >= need else UI.BONE))
	_info.add_child(h)

func _spacer() -> void:
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(sp)

## Against what is worn: the three figures that matter most, or with Compare every one that changes.
func _compare_block(id: String) -> void:
	var it: Dictionary = Db.item(id)
	var worn = Game.profile.equipped.get(str(it.slot))
	var head := HBoxContainer.new()
	var hl := UI.label("AGAINST %s" % str(Db.item(str(worn)).name).to_upper() if worn != null else "AGAINST AN EMPTY SLOT", 18, UI.DIM, "head")
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.clip_text = true
	head.add_child(hl)
	_info.add_child(head)
	var changed: Array = Game.compare(str(it.slot), id).filter(func(r): return int(r.better) != 0 or r.now_text != r.then_text)
	var grid := GridContainer.new()
	grid.columns = 2 if compare_on else 1
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", -3)
	_info.add_child(grid)
	for r in changed.slice(0, 8 if compare_on else 3):
		grid.add_child(GearUI.effect(r))
	if changed.is_empty():
		grid.add_child(UI.label("No change to your numbers", GearUI.TEXT, UI.DIM))
	if changed.size() > 3:
		var cmp := GearUI.chip("Compare" if not compare_on else "Fewer", compare_on, 150)
		cmp.pressed.connect(func():
			compare_on = not compare_on
			_fill_detail())
		head.add_child(cmp)
	if Game.requirement_text(id) != "" and not Game.meets_requirements(id):
		_info.add_child(_line("Asks for %s: usable without, at a cost" % Game.requirement_text(id), GearUI.BAD))

## The one large button of the panel, with the figure it spends or earns beside it.
func _deal(amount: String, amount_col: Color, sub: String, text: String, enabled: bool, size: int = 26) -> Button:
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	_info.add_child(foot)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", -6)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if amount != "":
		pv.add_child(UI.label(amount, 36, amount_col, "head"))
	if sub != "":
		pv.add_child(_line(sub, UI.DIM))
	foot.add_child(pv)
	var b := UI.button(text, size, 250)
	b.custom_minimum_size.y = 76
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.disabled = not enabled
	if enabled:
		var sb := UI.box(Color(0.2, 0.16, 0.08, 0.96), UI.GOLD, 2, 2, 12)
		sb.shadow_color = Color(UI.GOLD, 0.18)
		sb.shadow_size = 8
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_color_override("font_color", Color("#f2dfa8"))
	foot.add_child(b)
	return b

func _ware_detail(_it: Dictionary) -> void:
	var e := _entry(sel)
	if e.is_empty():
		return
	var price := int(e.price)
	var gold := int(Game.profile.gold)
	if not e.available:
		# a goal: seen, priced, not yet for sale. The line never names the guardian.
		var lock := HBoxContainer.new()
		lock.add_theme_constant_override("separation", 8)
		lock.add_child(InvGlyph.new("lock", UI.GOLD_DIM.lightened(0.3), 1, 20.0))
		lock.add_child(_line(str(e.unlock_text) if str(e.unlock_text) != "" else "Not for sale yet.", UI.GOLD_DIM.lightened(0.3), "bold"))
		_info.add_child(lock)
	elif e.get("buyback", false):
		_info.add_child(_line("Yours once. Orren kept it for you, at his price.", UI.GOLD_DIM.lightened(0.3)))
	_compare_block(sel)
	_spacer()
	var sub := "" if gold >= price or not e.available else "%d short" % (price - gold)
	buy_btn = _deal("%d gold" % price, UI.GOLD if gold >= price or not e.available else GearUI.BAD.lerp(UI.BONE, 0.25), sub,
		"Locked" if not e.available else ("Buy" if gold >= price else "Not enough gold"), e.available and gold >= price, 26 if e.available and gold >= price else 17)
	buy_btn.pressed.connect(func(): ask_buy(sel))

func _sell_detail(it: Dictionary) -> void:
	var why := Game.sell_block(sel)
	for line in Stats.item_lines(it, Game.upgrade_level(sel), Db.classes).slice(0, 3):
		var h := HBoxContainer.new()
		var k := UI.label(str(line[0]), GearUI.TEXT, UI.DIM)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(k)
		h.add_child(UI.label(str(line[1]), GearUI.TEXT, UI.BONE, "bold"))
		_info.add_child(h)
	var reason := {"Equipped": "You are wearing it. Take it off in the armoury first.", "Favourite": "Marked as a favourite. Unmark it in the armoury to sell.",
		"Keepsake": "A keepsake. Orren will not take it.", "Not for sale": "The blade you woke with. It stays.",
		"Last weapon": "Your only weapon. Orren will not leave you unarmed.", "Last one-handed blade": "Your only one-handed blade: a shield needs one."}
	_spacer()
	if why != "":
		sell_btn = _deal("", UI.DIM, str(reason.get(why, why + ".")), why, false, 17)
	else:
		var back := "He keeps it: it can be bought back for %d." % int(ceil(Game.sell_price(sel) * float(Db.equipment.buyback_rate))) if int(it.get("price", 0)) <= 0 or not Game.shop_unlocked(it) else "He stocks these: it can be bought again."
		sell_btn = _deal("+%d gold" % Game.sell_price(sel), UI.GOLD, back, "Sell", true)
	sell_btn.pressed.connect(func(): ask_sell(sel))

func _after_purchase(_it: Dictionary) -> void:
	_info.add_child(_line("Yours. Orren wraps the hilt and says nothing more about it.", UI.GOLD, "bold"))
	if not Game.is_equipped(sel):
		_compare_block(sel)
	_spacer()
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	_info.add_child(foot)
	var eq := UI.button("Equipped" if Game.is_equipped(sel) else "Equip", 24, 0)
	eq.custom_minimum_size.y = 76
	eq.focus_mode = Control.FOCUS_NONE
	eq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eq.disabled = Game.is_equipped(sel)
	eq.pressed.connect(func():
		Sfx.play("ui_confirm", -4.0)
		Game.equip(sel))
	foot.add_child(eq)
	buy_btn = eq
	var ins := UI.button("Inspect", 20, 160)
	ins.custom_minimum_size.y = 76
	ins.focus_mode = Control.FOCUS_NONE
	ins.pressed.connect(open_inspect)
	foot.add_child(ins)

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
	_bought_at = _ids.find(id)
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

# ================================================================ scripted input for captures
## --shop_demo=<t>:<action>[:<a>],...   sel:<id>  mode:<Wares|Materials|Sell>  filter:<n>  buy (as the button)  yes / no (the question)
##   sell  equip  inspect  close  mat:<id> (one unit)  scroll:<pixels>
func _process(delta: float) -> void:
	_clock += delta
	while not _demo.is_empty() and _clock >= float(_demo[0][0]):
		var st: Array = _demo.pop_front()
		var a := str(st[2])
		match str(st[1]):
			"sel": select(a)
			"mode": set_mode(a)
			"filter":
				filter = int(a)
				refresh()
			"buy": ask_buy(sel)
			"sell": ask_sell(sel)
			"yes", "no":
				if dialog and is_instance_valid(dialog):
					var btns := dialog.find_children("*", "Button", true, false)
					(btns[1 if str(st[1]) == "yes" else 0] as Button).pressed.emit()
			"equip": Game.equip(sel)
			"inspect": open_inspect()
			"close":
				if inspect and is_instance_valid(inspect):
					inspect.queue_free()
			"mat": Game.buy_material(a, 1)
			"drag":
				var x0 := carousel.size.x * 0.5
				carousel.drag_begin(x0)
				carousel.drag_move(x0 + float(a) * 0.5)
				carousel.drag_move(x0 + float(a))
			"release": carousel.drag_end(carousel._last_x)
