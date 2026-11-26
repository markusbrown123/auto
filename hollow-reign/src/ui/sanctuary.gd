class_name Sanctuary
extends Node
## The hub between runs: choose a road, manage equipment, visit the
## blacksmith, spend attribute points, change settings.

signal set_out(region_id: String, use_shortcut: bool)
signal quit_to_title
signal train

const TABS := ["Journey", "Armory", "Blacksmith", "Character", "Journal", "Settings"]
const GOOD := Color("#8fb37a")
const BAD := Color("#c2574a")
const CAM_POS := Vector3(2.5, 1.45, 3.4)
const CAM_LOOK := Vector3(1.15, 1.05, 0)

var backdrop: Backdrop
var layer: CanvasLayer
var content: Control
var purse: Label
var tab := "Journey"
var tab_buttons := {}
var sel_region := ""
var sel_slot := "weapon"
var sel_item := ""
var smith_mode := "Upgrade"
var frame: Control              # everything drawn over the backdrop; hidden while the forge works
var stage: Control              # the open space beside the panel, where the knight stands
var armory: ArmoryScreen        # the equipment screen (src/ui/armory/), alive only while its tab is open
var _panel: Control             # the right-hand panel the other tabs fill; the armoury uses the whole width instead
var _smith_focus := ""          # item the armoury sent to the forge: listed first there
var _forging := false
var _sell_confirm := ""
var _dev := {}                  # capture harness: --item=<id> --mastery=<n> --smith=<mode> --forge=<id>

func _ready() -> void:
	backdrop = Backdrop.new()
	add_child(backdrop)
	backdrop.build("sanctuary")
	backdrop.move_camera(CAM_POS, CAM_LOOK, true)
	Game.sync_mastery()
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		if kv[0] in ["item", "smith", "forge", "mastery"] and kv.size() > 1:
			_dev[kv[0]] = kv[1]
	if _dev.has("mastery") and _dev.has("item"):
		Game.profile.mastery[str(_dev.item)] = int(_dev.mastery)
		Game.sync_mastery()
	smith_mode = str(_dev.get("smith", smith_mode))
	if _dev.has("forge"):
		get_tree().create_timer(1.2).timeout.connect(func(): _forge(str(_dev.forge)))
	Sfx.music_for("hub", "sanctuary")
	Sfx.ambience("fire")
	layer = CanvasLayer.new()
	add_child(layer)
	var m := UI.margin(get_viewport(), 6)
	layer.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	frame = m
	# --- top navigation
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	v.add_child(nav)
	for t in TABS:
		var b := UI.button(t, 17, 150)
		b.custom_minimum_size.y = 44
		b.pressed.connect(func(): show_tab(t))
		nav.add_child(b)
		tab_buttons[t] = b
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.add_child(gap)
	purse = UI.label("", 19, UI.GOLD, "bold")
	purse.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav.add_child(purse)
	# --- body: the knight stands on the left, the panel is on the right
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(body)
	var left := Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.62
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(left)
	stage = left
	var panel := UI.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	_panel = panel
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	Game.profile_changed.connect(_on_profile)
	for r in Db.regions:
		if Game.region_unlocked(r.id):
			sel_region = r.id
	show_tab("Journey")
	_greet()

func _greet() -> void:
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or Story.busy:
		return
	if Game.just_died:
		Game.just_died = false
		# the returns are written as a progression: play them in order, then stay on the last
		Story.play("rebirth_%d" % clampi(int(Game.profile.deaths) - 1, 0, 5))
	elif Game.profile.cleared.has("courtyard"):
		Story.play("sanctuary_return")

func _on_profile() -> void:
	if _forging:
		return       # the forge sequence is on screen; the tab is rebuilt when it ends
	if tab == "Armory" and armory:
		# the armoury keeps its place in the row: it refreshes itself rather than being rebuilt
		_purse()
		armory.on_profile()
		return
	backdrop.refresh_knight()
	show_tab(tab)

func _purse() -> void:
	var p: Dictionary = Game.profile
	purse.text = "LV %d      %d GOLD      %d SHARDS" % [p.level, p.gold, p.shards]

## From the armoury's Upgrade: the forge, with that item at the head of the list.
func open_forge(id: String) -> void:
	smith_mode = "Upgrade"
	_smith_focus = id
	show_tab("Blacksmith")

func show_tab(t: String) -> void:
	tab = t
	for k in tab_buttons:
		tab_buttons[k].add_theme_color_override("font_color", UI.GOLD if k == t else UI.BONE)
	if armory:
		armory.leave()
		armory = null
	for holder: Control in [content, stage]:
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
	_panel.visible = t != "Armory"
	backdrop.knight_yaw = PI * 0.92
	backdrop.turn_knight(0.0)
	if t != "Armory":
		backdrop.move_camera(CAM_POS, CAM_LOOK, bool(Game.settings.reduce_motion))
	_purse()
	call("_tab_" + t.to_lower())

func _scroll() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v

func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	return h

func _wrap(text: String, size: int = 19, color: Color = UI.DIM) -> Label:
	var l := UI.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

# ================================================================ Journey
func _tab_journey() -> void:
	var ng: int = Game.profile.ng
	content.add_child(UI.title("The Road" if ng == 0 else "The Road  ·  Return %d" % ng, 24))
	var cols := _row()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cols)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	list.custom_minimum_size.x = 290
	cols.add_child(list)
	var i := 0
	for r in Db.regions:
		i += 1
		var open: bool = Game.region_unlocked(r.id)
		var done: bool = Game.profile.cleared.has(r.id)
		var b := UI.button(("%s  %s" % [["I", "II", "III", "IV", "V", "VI", "VII", "VIII"][i - 1], r.name]) if open else "—  Unknown", 15, 290)
		b.custom_minimum_size.y = 40
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not open
		if done:
			b.add_theme_color_override("font_color", UI.GOLD_DIM)
		if r.id == sel_region:
			b.add_theme_color_override("font_color", UI.GOLD)
		b.pressed.connect(func():
			sel_region = r.id
			show_tab("Journey"))
		list.add_child(b)
	if Game.game_complete():
		var again := UI.button("Return Again  (NG+%d)" % (ng + 1), 15, 290)
		again.pressed.connect(func():
			Game.start_ng_plus()
			sel_region = "courtyard"
			show_tab("Journey"))
		list.add_child(again)
	# detail
	var det := VBoxContainer.new()
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.add_theme_constant_override("separation", 8)
	cols.add_child(det)
	var r: Dictionary = Db.region_by_id[sel_region]
	det.add_child(UI.title(r.name, 22, UI.BONE))
	det.add_child(_wrap(r.blurb, 20))
	det.add_child(UI.rule())
	var boss_id := ""
	for o in r.stages[-1].options:
		if o.type == "boss":
			boss_id = o.foe
	var beaten: bool = Game.profile.defeated.has(boss_id)
	det.add_child(UI.label("Guardian:  %s" % (Db.foes[boss_id].name if beaten else "unknown"), 18, UI.BONE if beaten else UI.DIM))
	det.add_child(UI.label("Cleared" if Game.profile.cleared.has(r.id) else "Uncleared", 18, UI.GOLD if Game.profile.cleared.has(r.id) else UI.DIM))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	det.add_child(sp)
	var go := UI.button("Set Out", 22, 260)
	go.pressed.connect(func(): set_out.emit(sel_region, false))
	det.add_child(go)
	if Game.shortcut_open(sel_region):
		var sc := UI.button("By " + r.shortcut.label, 16, 260)
		sc.pressed.connect(func(): set_out.emit(sel_region, true))
		det.add_child(sc)

# ================================================================ Armory
func _item_button(it: Dictionary, selected: bool, suffix: String = "") -> Button:
	var lvl := Game.upgrade_level(it.id)
	var name_text: String = it.name + (" +%d" % lvl if lvl > 0 else "")
	var b := UI.button(name_text + suffix, 15, 0)
	b.text = name_text + suffix
	b.add_theme_font_override("font", UI.font("bold"))
	b.add_theme_font_size_override("font_size", 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 42
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	var col := Db.rarity_color(it)
	b.add_theme_color_override("font_color", col)
	var sb := UI.box(Color(0.06, 0.06, 0.07, 0.85), UI.GOLD if selected else Color(0.2, 0.19, 0.17), 1, 2, 10)
	sb.border_width_left = 4
	sb.border_color = col if not selected else UI.GOLD
	sb.content_margin_right = 78
	b.add_theme_stylebox_override("normal", sb)
	# rarity as a count of marks, and the favourite star: neither depends on colour alone
	var marks := HBoxContainer.new()
	marks.add_theme_constant_override("separation", 4)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	marks.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	marks.offset_right = -8
	if Game.is_favourite(it.id):
		marks.add_child(InvGlyph.new("star", UI.GOLD, 1, 13.0))
	marks.add_child(InvGlyph.new("pips", col, Game.rarity_pips(it), 11.0))
	b.add_child(marks)
	return b

func _sort_button() -> Button:
	var mode := str(Game.profile.get("inv_sort", "equipped"))
	var b := UI.button("Sort: " + Game.SORT_NAME[mode], 14, 230)
	b.custom_minimum_size.y = 38
	b.pressed.connect(func():
		Game.set_sort(Game.SORTS[(Game.SORTS.find(mode) + 1) % Game.SORTS.size()])
		show_tab(tab))
	return b

## The equipment screen is its own scene (src/ui/armory/armory_screen.gd): a swipe carousel of the collection
## and the live knight wearing a preview. It fills the whole body of the hub; the right-hand panel is hidden for it.
func _tab_armory() -> void:
	var item := ""
	if _dev.has("item"):
		item = str(_dev.item)
		_dev.erase("item")
	armory = ArmoryScreen.new(self, backdrop, sel_slot, item)
	stage.add_child(armory)

func _fav_button(id: String, width: float) -> Button:
	var on := Game.is_favourite(id)
	var fav := UI.button("    Favourite" if width > 100 else "", 14, width)
	fav.custom_minimum_size.y = 46
	fav.tooltip_text = "A favourite cannot be sold"
	if on:
		fav.add_theme_color_override("font_color", UI.GOLD)
	var star := InvGlyph.new("star", UI.GOLD if on else UI.DIM, 1 if on else 0, 16.0)
	star.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if width > 100 else Control.PRESET_CENTER)
	star.offset_left = 14 if width > 100 else -8
	star.offset_right = star.offset_left + 16
	star.offset_top = -8
	star.offset_bottom = 8
	fav.add_child(star)
	fav.pressed.connect(func():
		Game.toggle_favourite(id)
		show_tab(tab))
	return fav

# ================================================================ Blacksmith
## Orren speaks the first time, then only now and then: at most once per two fights survived or lost.
func _orren_remark() -> void:
	if Story.busy:
		return
	var mark: int = int(Game.profile.deaths)
	for f in Game.profile.defeated:
		mark += int(Game.profile.defeated[f])
	if Story.pending("orren_intro"):
		Game.profile.flags["orren_spoke"] = mark
		Story.play("orren_intro")
	elif Story.has_scene("orren_idle") and mark >= int(Game.profile.flags.get("orren_spoke", -2)) + 2:
		Game.profile.flags["orren_spoke"] = mark
		Story.play("orren_idle")

func _tab_blacksmith() -> void:
	_orren_remark()
	var head := _row()
	content.add_child(head)
	var ttl := UI.title("Orren's Forge", 22)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ttl)
	if smith_mode != "Wares":
		head.add_child(_sort_button())
	var modes := _row()
	content.add_child(modes)
	for mname in ["Upgrade", "Wares", "Sell"]:
		var b := UI.button(mname, 15, 150)
		b.custom_minimum_size.y = 40
		if mname == smith_mode:
			b.add_theme_color_override("font_color", UI.GOLD)
		b.pressed.connect(func():
			smith_mode = mname
			_sell_confirm = ""
			show_tab("Blacksmith"))
		modes.add_child(b)
	var list := _scroll()
	if smith_mode == "Upgrade":
		var upgradable: Array = Game.sorted_items(["weapon", "shield", "helm", "chest", "gauntlets", "legs"])
		if upgradable.has(_smith_focus):
			upgradable.erase(_smith_focus)
			upgradable.push_front(_smith_focus)
		for id: String in upgradable:
			var it: Dictionary = Db.item(id)
			var lvl := Game.upgrade_level(it.id)
			var row := _row()
			var b := _item_button(it, id == _smith_focus, "   ◆" if Game.is_equipped(id) else "")
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(b)
			if lvl >= Stats.MAX_UPGRADE:
				var mx := UI.label("PERFECTED", 15, UI.GOLD, "bold")
				mx.custom_minimum_size.x = 210
				mx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				row.add_child(mx)
			else:
				var c := Stats.upgrade_cost(it, lvl)
				var up := UI.button("%d g  ·  %d sh" % [c.gold, c.shards], 14, 210)
				up.custom_minimum_size.y = 42
				up.disabled = not Game.can_upgrade(it.id)
				up.pressed.connect(func(): _forge(id))
				row.add_child(up)
			list.add_child(row)
	elif smith_mode == "Wares":
		var stock := Game.shop_stock()
		if stock.is_empty():
			list.add_child(_wrap("The smith has nothing left to sell you. What remains must be taken.", 19))
		for it in stock:
			var row := _row()
			var b := _item_button(it, false, "   %s" % Db.SLOT_NAME[it.slot].to_lower())
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(b)
			var buy := UI.button("%d g" % it.price, 14, 140)
			buy.custom_minimum_size.y = 42
			buy.disabled = Game.profile.gold < int(it.price)
			buy.pressed.connect(func():
				Sfx.play("loot", -3.0)
				Game.buy(it.id))
			row.add_child(buy)
			list.add_child(row)
	else:
		list.add_child(_wrap("Orren buys what you will not carry. He will not take what you wear, or anything you have marked as a favourite.", 17))
		for id: String in Game.sorted_items():
			var it: Dictionary = Db.item(id)
			var row := _row()
			var b := _item_button(it, false, "   ◆" if Game.is_equipped(id) else "")
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(b)
			row.add_child(_fav_button(id, 46))
			var why := Game.sell_block(id)
			if why != "":
				var kept := UI.label(why.to_upper(), 15, UI.GOLD_DIM, "bold")
				kept.custom_minimum_size.x = 170
				kept.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				row.add_child(kept)
			else:
				var asking := _sell_confirm == id
				var sell := UI.button("Sure?  %d g" % Game.sell_price(id) if asking else "Sell  %d g" % Game.sell_price(id), 14, 170)
				sell.custom_minimum_size.y = 42
				if asking:
					sell.add_theme_color_override("font_color", BAD)
				sell.pressed.connect(func():
					if _sell_confirm == id:
						_sell_confirm = ""
						Sfx.play("loot", -3.0)
						Game.sell(id)
					else:
						_sell_confirm = id
						show_tab("Blacksmith"))
				row.add_child(sell)
			list.add_child(row)

## What the upgrade changed, as [label, before, after, +delta] rows for the forge's reveal.
func _upgrade_rows(it: Dictionary, lvl: int, before: Dictionary, after: Dictionary) -> Array:
	var rows: Array = []
	var a := 1.0 + 0.1 * lvl
	var b := 1.0 + 0.1 * (lvl + 1)
	if it.slot == "weapon":
		rows.append(["Damage", "%.1f" % (float(it.damage) * a), "%.1f" % (float(it.damage) * b), "+%.1f" % (float(it.damage) * 0.1)])
	elif float(it.get("defense", 0)) > 0.0:
		rows.append(["Defence", "%.1f" % (float(it.defense) * a), "%.1f" % (float(it.defense) * b), "+%.1f" % (float(it.defense) * 0.1)])
	if it.slot == "shield":
		rows.append(["Guard", "%.0f%%" % ((float(it.block) + 0.03 * lvl) * 100.0), "%.0f%%" % ((float(it.block) + 0.03 * (lvl + 1)) * 100.0), "+3%"])
	if Game.is_equipped(it.id):
		if it.slot == "weapon":
			rows.append(["Your attack", "%.1f" % before.attack, "%.1f" % after.attack, "+%.1f" % (float(after.attack) - float(before.attack))])
		else:
			rows.append(["Damage guarded", "%.1f%%" % (float(before.mitigation) * 100.0), "%.1f%%" % (float(after.mitigation) * 100.0), "+%.1f%%" % ((float(after.mitigation) - float(before.mitigation)) * 100.0)])
	return rows

func _forge(id: String) -> void:
	if _forging or not Game.can_upgrade(id):
		return
	var it: Dictionary = Db.item(id)
	var lvl := Game.upgrade_level(id)
	var before := Game.stats()
	_forging = true
	Game.upgrade(id)        # paid for and saved now; the sequence is only the telling of it
	var rows := _upgrade_rows(it, lvl, before, Game.stats())
	frame.visible = false
	var seq := ForgeSeq.new(backdrop, id, lvl + 1, rows)
	layer.add_child(seq)
	await seq.finished
	_forging = false
	if not is_inside_tree():
		return
	frame.visible = true
	show_tab("Blacksmith")

# ================================================================ Character
func _tab_character() -> void:
	var p: Dictionary = Game.profile
	var head := _row()
	content.add_child(head)
	var t := UI.title("Level %d" % p.level, 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UI.label("%d / %d xp" % [p.xp, Stats.xp_for_level(p.level)], 18, UI.DIM))
	var xp := UI.bar(UI.GOLD, 5)
	xp.max_value = Stats.xp_for_level(p.level)
	xp.value = p.xp
	content.add_child(xp)
	var pts: int = p.attr_points
	content.add_child(UI.label("%d point%s to spend" % [pts, "" if pts == 1 else "s"] if pts > 0 else "No points to spend. Levels and mastered gear grant more.", 18, UI.GOLD if pts > 0 else UI.DIM))
	var cols := _row()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cols)
	var attrs := VBoxContainer.new()
	attrs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attrs.add_theme_constant_override("separation", 4)
	cols.add_child(attrs)
	for a in Db.ATTRS:
		var row := _row()
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_theme_constant_override("separation", -4)
		names.add_child(UI.label(Db.ATTR_NAME[a], 19, UI.BONE, "bold"))
		names.add_child(UI.label(Db.ATTR_DESC[a], 14, UI.DIM))
		row.add_child(names)
		var val := UI.label(str(p.attrs[a]), 22, UI.GOLD, "bold")
		val.custom_minimum_size.x = 40
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		var plus := UI.button("+", 20, 46)
		plus.custom_minimum_size.y = 42
		plus.disabled = pts <= 0
		plus.pressed.connect(func(): Game.spend_attr(a))
		row.add_child(plus)
		attrs.add_child(row)
	var st := Game.stats()
	var derived := VBoxContainer.new()
	derived.custom_minimum_size.x = 230
	derived.add_theme_constant_override("separation", 3)
	cols.add_child(derived)
	for d in [["Health", "%.0f" % st.max_hp], ["Stamina", "%.0f" % st.max_stamina], ["Attack", "%.1f" % st.attack], ["Swing", "%.2fs" % st.swing_time],
			["Damage guarded", "%.0f%%" % (st.mitigation * 100.0)], ["Stagger damage", "×%.2f" % st.crit_mult], ["Resistance", "%.0f" % st.resist],
			["Falls", str(p.deaths)], ["Guardians slain", str(_bosses_slain())]]:
		var row := _row()
		var k := UI.label(d[0], 17, UI.DIM)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k)
		row.add_child(UI.label(d[1], 17, UI.BONE, "bold"))
		derived.add_child(row)

func _bosses_slain() -> int:
	var n := 0
	for id in Game.profile.defeated:
		if Db.foes[id].boss:
			n += 1
	return n

# ================================================================ Journal
## Every combo the knight has found, and the shape of the ones still unfound.
func _tab_journal() -> void:
	var p: Dictionary = Game.profile
	var cls := str(Game.stats().get("weapon_cls", "sword"))
	# conversations with the companions: unheard first; each can be heard again from here
	if has_node("/root/Companion") and Companion.witness_found():
		var topics: Array = Companion.sanctuary_topics()
		if not topics.is_empty():
			var th := _row()
			content.add_child(th)
			th.add_child(UI.title("Talk", 22))
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 8)
			flow.add_theme_constant_override("v_separation", 6)
			content.add_child(flow)
			for tp in topics:
				var b := UI.button(str(tp.title), 14, 0)
				b.custom_minimum_size.y = 38
				if not bool(tp.heard):
					b.add_theme_color_override("font_color", UI.GOLD)
				b.pressed.connect(func():
					if not Story.busy:
						await Companion.play_topic(str(tp.id))
						if is_inside_tree() and tab == "Journal":
							show_tab("Journal"))
				flow.add_child(b)
	var head := _row()
	content.add_child(head)
	var t := UI.title("Combat Journal", 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var found := 0
	for c in Db.combos:
		if p.combos.has(c.id):
			found += 1
	head.add_child(UI.label("%d of %d found" % [found, Db.combos.size()], 18, UI.DIM))
	var tr := UI.button("Train with Orren", 16, 220)
	tr.pressed.connect(func(): train.emit())
	head.add_child(tr)
	content.add_child(_wrap("Sequences are found by cutting. End an opening with the right pattern and the last blow lands as something more.", 16))
	var v := _scroll()
	for c in Db.combos:
		var known: bool = p.combos.has(c.id)
		var usable: bool = c.cls.is_empty() or c.cls.has(cls)
		var row := _row()
		v.add_child(row)
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_theme_constant_override("separation", -3)
		row.add_child(names)
		if known:
			var title_row := _row()
			title_row.add_child(UI.label(str(c.name), 20, UI.GOLD if usable else UI.DIM, "bold"))
			title_row.add_child(UI.label(str(c.kind).to_upper(), 13, UI.DIM))
			names.add_child(title_row)
			names.add_child(_wrap(str(c.use), 15))
			var bits: Array = ["×%.2f damage" % float(c.mult)]
			if float(c.get("posture", 0)) > 0:
				bits.append("+%d posture" % int(c.posture))
			if float(c.get("stamina_cost", 0)) > 0:
				bits.append("−%d stamina" % int(c.stamina_cost))
			if float(c.get("stamina_back", 0)) > 0:
				bits.append("+%d stamina" % int(c.stamina_back))
			if c.get("pierce", false):
				bits.append("ignores armour")
			bits.append("used %d×" % int(p.combo_uses.get(c.id, 0)))
			var src := Game.technique_source(c.id)
			if src != "":
				bits.append("learned from mastery of %s" % Db.item(src).name)
			if not usable:
				bits.append("needs: " + ", ".join(c.cls))
			names.add_child(UI.label("  ·  ".join(bits), 14, UI.BONE))
			row.add_child(SeqView.new(c.seq, 30.0, UI.BONE if usable else UI.DIM))
		else:
			names.add_child(UI.label("Unfound", 20, UI.DIM, "bold"))
			var hint := "%d cuts  ·  %s" % [c.seq.size(), str(c.kind).to_lower()]
			if not c.cls.is_empty():
				hint += "  ·  " + ", ".join(c.cls) + " only"
			names.add_child(UI.label(hint, 14, UI.DIM))
	# ---- tasks
	v.add_child(UI.spacer(8))
	v.add_child(UI.rule())
	var qhead := _row()
	v.add_child(qhead)
	var qt := UI.title("Tasks", 22)
	qt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qhead.add_child(qt)
	qhead.add_child(UI.label("%d of %d done" % [p.quests_done.size(), Db.quests.size()], 18, UI.DIM))
	for q in Db.quests:
		var done: bool = p.quests_done.has(q.id)
		var qrow := _row()
		v.add_child(qrow)
		var qv := VBoxContainer.new()
		qv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qv.add_theme_constant_override("separation", -3)
		qrow.add_child(qv)
		var qtitle := _row()
		qtitle.add_child(UI.label(str(q.name), 20, UI.DIM if done else UI.GOLD, "bold"))
		qtitle.add_child(UI.label(str(q.giver).to_upper(), 13, UI.DIM))
		qv.add_child(qtitle)
		qv.add_child(_wrap(str(q.done_text if done else q.text), 15))
		qv.add_child(UI.label(Game.quest_progress(q.id), 14, UI.BONE))
		if not done and Game.quest_ready(q.id):
			var claim := UI.button("Claim", 16, 120)
			claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			claim.pressed.connect(func(): Game.claim_quest(q.id))
			qrow.add_child(claim)
	# ---- records
	v.add_child(UI.spacer(8))
	v.add_child(UI.rule())
	var rhead := _row()
	v.add_child(rhead)
	var rt := UI.title("Records", 22)
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rhead.add_child(rt)
	rhead.add_child(UI.label("%d of %d found" % [p.lore.size(), Db.lore.size()], 18, UI.DIM))
	for l in Db.lore:
		if p.lore.has(l.id):
			var lv := VBoxContainer.new()
			lv.add_theme_constant_override("separation", -3)
			v.add_child(lv)
			lv.add_child(UI.label(str(l.title), 19, UI.GOLD, "bold"))
			lv.add_child(_wrap(str(l.text), 15))
		else:
			v.add_child(UI.label("Unfound — " + str(Db.region_by_id[l.region].name), 15, UI.DIM))

# ================================================================ Settings
func _tab_settings() -> void:
	SettingsPanel.fill(_scroll(), func(): show_tab("Settings"), func(): quit_to_title.emit())
