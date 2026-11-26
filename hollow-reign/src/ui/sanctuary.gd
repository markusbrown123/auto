class_name Sanctuary
extends Node
## The hub between runs: choose a road, manage equipment, visit the
## blacksmith, spend attribute points, change settings.

signal set_out(region_id: String, use_shortcut: bool)
signal quit_to_title

const TABS := ["Journey", "Armory", "Blacksmith", "Character", "Settings"]

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

func _ready() -> void:
	backdrop = Backdrop.new()
	add_child(backdrop)
	backdrop.build("sanctuary")
	backdrop.move_camera(Vector3(2.5, 1.45, 3.4), Vector3(1.15, 1.05, 0), true)
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
	var panel := UI.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
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
		Story.play("rebirth_%d" % (randi() % 6))
	elif Game.profile.cleared.has("courtyard"):
		Story.play("sanctuary_return")

func _on_profile() -> void:
	backdrop.refresh_knight()
	show_tab(tab)

func show_tab(t: String) -> void:
	tab = t
	for k in tab_buttons:
		tab_buttons[k].add_theme_color_override("font_color", UI.GOLD if k == t else UI.BONE)
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	var p: Dictionary = Game.profile
	purse.text = "LV %d      %d GOLD      %d SHARDS" % [p.level, p.gold, p.shards]
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
	var col := Db.rarity_color(it)
	b.add_theme_color_override("font_color", col)
	var sb := UI.box(Color(0.06, 0.06, 0.07, 0.85), UI.GOLD if selected else Color(0.2, 0.19, 0.17), 1, 2, 10)
	sb.border_width_left = 4
	sb.border_color = col if not selected else UI.GOLD
	b.add_theme_stylebox_override("normal", sb)
	return b

func _tab_armory() -> void:
	var slots := _row()
	slots.add_theme_constant_override("separation", 4)
	content.add_child(slots)
	for s in Db.SLOTS:
		var b := UI.button(Db.SLOT_NAME[s], 12, 0)
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if s == sel_slot:
			b.add_theme_color_override("font_color", UI.GOLD)
		b.pressed.connect(func():
			sel_slot = s
			sel_item = ""
			show_tab("Armory"))
		slots.add_child(b)
	var cols := _row()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cols)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.x = 290
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	sc.add_child(list)
	var equipped = Game.profile.equipped[sel_slot]
	var owned: Array = []
	for id in Game.profile.inventory:
		var it: Dictionary = Db.item(id)
		if it.get("slot", "") == sel_slot:
			owned.append(it)
	owned.sort_custom(func(a, b): return Stats.item_power(a, Game.upgrade_level(a.id)) + Db.rarity_rank(a) * 0.01 > Stats.item_power(b, Game.upgrade_level(b.id)) + Db.rarity_rank(b) * 0.01)
	if sel_item == "" or Db.item(sel_item).get("slot", "") != sel_slot:
		sel_item = str(equipped) if equipped != null else (owned[0].id if not owned.is_empty() else "")
	for it in owned:
		var b := _item_button(it, it.id == sel_item, "   ◆" if it.id == equipped else "")
		b.pressed.connect(func():
			sel_item = it.id
			show_tab("Armory"))
		list.add_child(b)
	if owned.is_empty():
		list.add_child(_wrap("Nothing of this kind yet. The road provides.", 18))
	var det := VBoxContainer.new()
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.add_theme_constant_override("separation", 5)
	cols.add_child(det)
	if sel_item == "":
		return
	_item_detail(det, Db.item(sel_item), true)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	det.add_child(sp)
	if sel_item == equipped:
		if sel_slot != "weapon":
			var un := UI.button("Remove", 18, 220)
			un.pressed.connect(func(): Game.unequip(sel_slot))
			det.add_child(un)
	else:
		var eq := UI.button("Equip", 20, 220)
		eq.pressed.connect(func():
			Sfx.play("ui_confirm", -4.0)
			Game.equip(sel_item))
		det.add_child(eq)

## Item card with a side-by-side comparison against what is equipped.
func _item_detail(det: VBoxContainer, it: Dictionary, compare: bool) -> void:
	var lvl := Game.upgrade_level(it.id)
	det.add_child(UI.title(it.name + (" +%d" % lvl if lvl > 0 else ""), 20, Db.rarity_color(it)))
	var kind: String = str(it.rarity).capitalize() + " " + (Db.classes[it.cls].name if it.slot == "weapon" else Db.SLOT_NAME[it.slot])
	det.add_child(UI.label(kind, 16, UI.DIM))
	for line in Stats.item_lines(it, lvl, Db.classes):
		var row := _row()
		var k := UI.label(str(line[0]), 18, UI.DIM)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k)
		row.add_child(UI.label(str(line[1]), 18, UI.BONE, "bold"))
		det.add_child(row)
	det.add_child(UI.rule())
	if compare and Game.owns(it.id):
		# what actually changes if you put it on
		var now := Game.stats()
		var trial: Dictionary = Game.profile.duplicate(true)
		trial.equipped[it.slot] = it.id
		if it.slot == "weapon" and Db.classes[it.cls].two_handed:
			trial.equipped.shield = null
		var then := Stats.compute(trial, Db.items, Db.classes)
		for row_def in [["Attack", "attack", 1.0, ""], ["Guard vs. damage", "mitigation", 100.0, "%"], ["Health", "max_hp", 1.0, ""], ["Stamina", "max_stamina", 1.0, ""], ["Swing time", "swing_time", 1.0, "s"]]:
			var a: float = float(now[row_def[1]]) * row_def[2]
			var b: float = float(then[row_def[1]]) * row_def[2]
			if is_equal_approx(a, b):
				continue
			var better := b > a if row_def[1] != "swing_time" else b < a
			var row := _row()
			var k := UI.label(row_def[0], 17, UI.DIM)
			k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(k)
			var fmt := "%.2f%s  →  %.2f%s" if row_def[1] == "swing_time" else "%.0f%s  →  %.0f%s"
			row.add_child(UI.label(fmt % [a, row_def[3], b, row_def[3]], 17, Color("#8fb37a") if better else Color("#c2574a"), "bold"))
			det.add_child(row)
	if Game.owns(it.id):
		var need := Stats.mastery_needed(it)
		var have: int = mini(int(Game.profile.mastery.get(it.id, 0)), need)
		var mastered: bool = Game.profile.mastered.has(it.id)
		det.add_child(UI.label("Mastered" if mastered else "Mastery  %d / %d" % [have, need], 16, UI.GOLD if mastered else UI.DIM))
	det.add_child(_wrap(it.desc, 18, UI.DIM))

# ================================================================ Blacksmith
func _tab_blacksmith() -> void:
	if Story.pending("orren_intro"):
		Story.play("orren_intro")
	elif randf() < 0.25 and not Story.busy:
		Story.play("orren_idle")
	content.add_child(UI.title("Orren's Forge", 22))
	var modes := _row()
	content.add_child(modes)
	for mname in ["Upgrade", "Wares"]:
		var b := UI.button(mname, 15, 150)
		b.custom_minimum_size.y = 40
		if mname == smith_mode:
			b.add_theme_color_override("font_color", UI.GOLD)
		b.pressed.connect(func():
			smith_mode = mname
			show_tab("Blacksmith"))
		modes.add_child(b)
	var list := _scroll()
	if smith_mode == "Upgrade":
		var owned: Array = []
		for id in Game.profile.inventory:
			var it: Dictionary = Db.item(id)
			if it.slot in ["weapon", "shield", "helm", "chest", "gauntlets", "legs"]:
				owned.append(it)
		owned.sort_custom(func(a, b): return (Game.profile.equipped[a.slot] == a.id) and not (Game.profile.equipped[b.slot] == b.id))
		for it in owned:
			var lvl := Game.upgrade_level(it.id)
			var row := _row()
			var b := _item_button(it, false, "   ◆" if Game.profile.equipped[it.slot] == it.id else "")
			b.disabled = false
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
				up.pressed.connect(func():
					Sfx.play("clash", -6.0, 1.3)
					Game.upgrade(it.id))
				row.add_child(up)
			list.add_child(row)
	else:
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

# ================================================================ Settings
func _tab_settings() -> void:
	SettingsPanel.fill(_scroll(), func(): show_tab("Settings"))
	var quit := UI.button("Return to Title", 16, 240)
	quit.pressed.connect(func(): quit_to_title.emit())
	content.add_child(quit)
