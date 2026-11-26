class_name Overlays
extends RefCounted
## Full-screen result and pause panels.

static func _shell(parent: Node, dim: float = 0.72) -> VBoxContainer:
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	var bg := UI.full(ColorRect.new())
	bg.color = Color(0.01, 0.01, 0.015, dim)
	layer.add_child(bg)
	var center := UI.full(CenterContainer.new())
	layer.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size.x = 560
	center.add_child(v)
	bg.modulate.a = 0.0
	v.modulate.a = 0.0
	var tw := layer.create_tween().set_parallel(true)
	tw.tween_property(bg, "modulate:a", 1.0, 0.5)
	tw.tween_property(v, "modulate:a", 1.0, 0.7).set_delay(0.2)
	v.set_meta("layer", layer)
	return v

static func _centered(text: String, size: int, color: Color, kind: String = "body") -> Label:
	var l := UI.label(text, size, color, kind)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func _button_row(v: VBoxContainer) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(UI.spacer(8))
	v.add_child(h)
	return h

## A figure and its name, for the row of what was won.
static func _tally(value: String, name: String, color: Color = UI.BONE) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", -4)
	c.custom_minimum_size.x = 150
	c.add_child(_centered(value, 34, color, "head"))
	c.add_child(_centered(name.to_upper(), 16, UI.DIM, "head"))
	return c

static func _centre(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c

## What was won. `r` is Game.on_victory()'s summary; it may also carry "new_combos" (ids) and "lore" (ids).
## Order: the tallies (gold counts up), what was salvaged, then anything new to hold: each new piece is revealed on
## a card of its own with Compare and Inspect (a Legendary or a Relic later and more slowly, with its model turning),
## then what Orren can now sell, what mastery opened, rumours, and the fight's own figures. Nothing spins or bursts.
static func victory(parent: Node, foe: Dictionary, r: Dictionary, sim: DuelSim, done: Callable) -> void:
	var v := _shell(parent, 0.66)
	var layer: CanvasLayer = v.get_meta("layer")
	var still: bool = bool(Game.settings.get("reduce_motion", false))
	var items: Array = r.get("items_new", r.get("items", [])).duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--reveal="):                    # capture harness: show the reveal of this item
			items.append(Db.canon(a.trim_prefix("--reveal=")))
	v.custom_minimum_size.x = 760
	v.add_theme_constant_override("separation", 5)
	v.add_child(_centered("GUARDIAN ENDED" if foe.boss else "IT IS DONE", 38 if foe.boss else 30, UI.GOLD, "title"))
	v.add_child(_centered(foe.name, 22, UI.SILVER, "head"))
	v.add_child(_centre(UI.ornament(420)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	row.add_child(_tally("+%d" % int(r.xp), "experience"))
	var gold_tally := _tally("+%d" % int(r.gold), "gold", UI.GOLD)
	row.add_child(gold_tally)
	if not still and int(r.gold) > 0:
		var gl: Label = gold_tally.get_child(0)
		gl.text = "+0"
		var tw := layer.create_tween()
		tw.tween_interval(0.55)
		tw.tween_method(func(g: float): gl.text = "+%d" % int(roundf(g)), 0.0, float(int(r.gold)), clampf(float(int(r.gold)) / 500.0, 0.5, 1.1)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	row.add_child(_tally("+%d" % int(r.shards), "shard" if int(r.shards) == 1 else "shards", UI.FROST.lerp(UI.BONE, 0.4)))
	# --- salvage: one plate a material
	var mats: Dictionary = r.get("materials", {})
	if not mats.is_empty():
		var mrow := HBoxContainer.new()
		mrow.alignment = BoxContainer.ALIGNMENT_CENTER
		mrow.add_theme_constant_override("separation", 8)
		v.add_child(mrow)
		mrow.add_child(UI.label("SALVAGED", 18, UI.DIM, "head"))
		for m: String in mats:
			var chip := UI.panel(Color(0.05, 0.05, 0.06, 0.9), UI.GOLD_DIM if m == "m_core" else Color(0.26, 0.24, 0.19))
			chip.get_theme_stylebox("panel").set_content_margin_all(4)
			chip.get_theme_stylebox("panel").content_margin_left = 12
			chip.get_theme_stylebox("panel").content_margin_right = 12
			chip.add_child(UI.label("%d  %s" % [int(mats[m]), Db.material_name(m)], 22, UI.GOLD if m == "m_core" else UI.BONE, "bold"))
			mrow.add_child(chip)
	# --- new pieces: a card each, revealed after the tallies
	var delay := 0.9
	for id: String in items:
		var it: Dictionary = Db.item(id)
		if it.is_empty():
			continue
		var grand: bool = Db.rarity_rank(it) >= 3
		var card := _item_card(layer, it, grand)
		v.add_child(card)
		if not still:
			card.modulate.a = 0.0
			var tw2 := layer.create_tween()
			tw2.tween_interval(delay + (0.5 if grand else 0.0))
			tw2.tween_callback(func(): Sfx.play("loot", -4.0 if grand else -8.0))
			tw2.tween_property(card, "modulate:a", 1.0, 1.3 if grand else 0.45).set_trans(Tween.TRANS_SINE)
			delay += 1.6 if grand else 0.5
	# --- everything else, in lines; a long list scrolls instead of pushing the button off the screen
	var lines: Array = []       # [text, colour, kind]
	if int(r.levels) > 0:
		lines.append(["Level %d reached.  %d points to spend." % [Game.profile.level, Game.profile.attr_points], UI.GOLD, "bold"])
		Sfx.play("levelup", -3.0)
	for id in r.get("shop_unlocks", []):
		var si: Dictionary = Db.item(id)
		lines.append(["New in the shop:  %s  ·  %d gold" % [si.name, int(si.get("price", 0))], Db.rarity_color(si).lerp(UI.BONE, 0.25), "bold"])
	var comp: Dictionary = r.get("compensation", {})
	if int(comp.get("gold", 0)) > 0:
		lines.append(["You hold what it carried already: its worth in gold and ore instead.", UI.BONE, "body"])
	for mu: Dictionary in r.get("mastery_ups", []):
		if not r.mastered.has(mu.id) or int(mu.tier) < 3:
			lines.append(["%s  ·  mark %s:  %s" % [Db.item(str(mu.id)).name, UI.roman(int(mu.tier)), str(mu.text)], UI.GOLD.lerp(UI.BONE, 0.4), "body"])
	for id in r.mastered:
		lines.append(["Mastered:  %s.  One more point to spend." % Db.item(id).name, UI.GOLD, "bold"])
	for id in r.get("discoveries", []):
		lines.append(["Word of something:  %s" % Game.item_hint(id), UI.SILVER, "body"])
	for id in r.get("new_combos", []):
		if Db.combo_by_id.has(id):
			lines.append(["Sequence found:  %s" % Db.combo_by_id[id].name, UI.BONE, "bold"])
	for id in r.get("lore", []):
		if Db.lore_by_id.has(id):
			lines.append(["Record:  %s" % Db.lore_by_id[id].title, UI.BONE, "bold"])
	if not lines.is_empty():
		var lv := VBoxContainer.new()
		lv.add_theme_constant_override("separation", 0)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for l: Array in lines:
			var lab := _centered(str(l[0]), 22, l[1], str(l[2]))
			lab.custom_minimum_size.x = 740
			lv.add_child(lab)
		var room: int = 5 if items.is_empty() else (3 if items.size() == 1 else 2)
		if lines.size() > room:
			var sc := ScrollContainer.new()
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			sc.custom_minimum_size = Vector2(760, room * 31 + 14)
			sc.add_child(lv)
			v.add_child(sc)
		else:
			v.add_child(lv)
	v.add_child(UI.rule())
	v.add_child(_centered("%d parries, %d of them perfect   ·   %d dodges   ·   %d blows taken   ·   longest chain %d" % [sim.stats.parries, sim.stats.perfect_parries, sim.stats.dodges, sim.stats.hits_taken, sim.stats.max_combo], 20, UI.DIM))
	var b := UI.button("Continue", 22, 260)
	b.pressed.connect(func():
		layer.queue_free()
		done.call())
	var br := _button_row(v)
	br.add_child(b)

## A newly won piece: its mark (or, for a Legendary or a Relic, the piece itself turning), its name and rank, and
## Compare (its figures against what is worn, opened in place) and Inspect.
static func _item_card(layer: CanvasLayer, it: Dictionary, grand: bool) -> Control:
	var id := str(it.id)
	var col: Color = Db.rarity_color(it)
	var p := UI.panel(Color(0.04, 0.04, 0.05, 0.94), col.lerp(UI.GOLD_DIM, 0.4))
	p.get_theme_stylebox("panel").set_content_margin_all(8)
	p.custom_minimum_size.x = 760
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	p.add_child(outer)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	outer.add_child(h)
	if grand:
		var st := ItemStage.new()
		st.body = str(Game.profile.get("body", "m"))
		st.custom_minimum_size = Vector2(230, 190)
		st.spin_speed = 0.35
		h.add_child(st)
		st.show_item(id)
	else:
		var g := InvGlyph.new(str(it.slot), col, 0, 40.0)
		g.custom_minimum_size = Vector2(52, 40)
		h.add_child(g)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tv)
	tv.add_child(UI.label("NEW" if not grand else "TAKEN FROM THE FALLEN", 18, UI.DIM, "head"))
	var nm := UI.title(str(it.name), 28 if grand else 24, col)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(nm)
	tv.add_child(GearUI.kind_row(it, col))
	if grand and str(it.get("desc", "")) != "":
		var d := UI.wrapped(str(it.desc), 22, UI.BONE)
		tv.add_child(d)
	var btns := BoxContainer.new()
	btns.vertical = grand
	btns.add_theme_constant_override("separation", 6)
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(btns)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", -3)
	grid.visible = false
	outer.add_child(grid)
	var cmp := UI.button("Compare", 18, 150)
	cmp.custom_minimum_size.y = 52
	cmp.pressed.connect(func():
		grid.visible = not grid.visible
		cmp.add_theme_color_override("font_color", UI.GOLD if grid.visible else UI.BONE)
		if grid.visible and grid.get_child_count() == 0:
			for row in Game.compare(str(it.slot), id):
				if grid.get_child_count() < 6 and (int(row.better) != 0 or row.now_text != row.then_text):
					grid.add_child(GearUI.effect(row))
			if grid.get_child_count() == 0:
				grid.add_child(UI.label("No change to your numbers against what you wear", 22, UI.DIM)))
	btns.add_child(cmp)
	var ins := UI.button("Inspect", 18, 150)
	ins.custom_minimum_size.y = 52
	ins.pressed.connect(func():
		var view := ArmoryInspect.new(GearUI.inspect_entry(id), str(Game.profile.get("body", "m")), str(it.get("desc", "")))
		layer.add_child(view))
	btns.add_child(ins)
	return p

## The knight fell. `done` returns to the sanctuary, as it always has. `actions` may add "retry" (set out on the
## same road again) and "equipment" (go and look at what is worn); each is shown only if given.
static func death(parent: Node, foe: Dictionary, summary: Dictionary, done: Callable, actions: Dictionary = {}) -> void:
	var v := _shell(parent, 0.84)
	v.custom_minimum_size.x = 640
	v.add_child(_centered("THE REIGN ENDURES", 42, UI.BLOOD.lightened(0.18), "title"))
	v.add_child(_centre(UI.ornament(420, UI.CRIMSON)))
	v.add_child(_centered("%s stands. You wake in the sanctuary, as you always do." % foe.name, 21, UI.SILVER))
	v.add_child(UI.spacer(4))
	var kept := "Nothing was lost."
	if int(summary.get("xp", 0)) > 0 or not summary.get("found", []).is_empty():
		kept = "Kept:  %d experience,  %d gold" % [summary.get("xp", 0), summary.get("gold", 0)]
		if not summary.get("found", []).is_empty():
			kept += ",  %d item%s" % [summary.found.size(), "" if summary.found.size() == 1 else "s"]
	v.add_child(_centered(kept, 20, UI.BONE, "bold"))
	v.add_child(_centered("What you learned of its rhythm is yours as well.", 17, UI.DIM))
	var h := _button_row(v)
	var close := func(f: Callable):
		v.get_meta("layer").queue_free()
		f.call()
	if actions.has("retry"):
		var r := UI.button("Set out again", 19, 210)
		r.pressed.connect(func(): close.call(actions.retry))
		h.add_child(r)
	var b := UI.button("Return to sanctuary" if not actions.is_empty() else "Rise", 19 if not actions.is_empty() else 22, 260)
	b.pressed.connect(func(): close.call(done))
	h.add_child(b)
	if actions.has("equipment"):
		var e := UI.button("Review equipment", 19, 230)
		e.pressed.connect(func(): close.call(actions.equipment))
		h.add_child(e)

static func pause(parent: Node, resume: Callable, abandon: Callable) -> void:
	parent.get_tree().paused = true
	var v := _shell(parent, 0.8)
	v.custom_minimum_size.x = 640
	_pause_fill(v, parent, resume, abandon)

static func _pause_fill(v: VBoxContainer, parent: Node, resume: Callable, abandon: Callable) -> void:
	for c in v.get_children():
		v.remove_child(c)
		c.queue_free()
	v.add_child(_centered("PAUSED", 34, UI.GOLD, "title"))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	v.add_child(rows)
	SettingsPanel.fill(rows, func(): _pause_fill(v, parent, resume, abandon))
	var h := _button_row(v)
	var close := func():
		parent.get_tree().paused = false
		v.get_meta("layer").queue_free()
	var r := UI.button("Resume", 20, 220)
	r.pressed.connect(func():
		close.call()
		resume.call())
	h.add_child(r)
	var a := UI.button("Yield", 20, 220)
	a.pressed.connect(func():
		close.call()
		abandon.call())
	h.add_child(a)

## A decision. `options` is [[label, enabled, note], ...]; `chosen` gets the index.
static func choice(parent: Node, heading: String, lines: Array, options: Array, chosen: Callable) -> void:
	var v := _shell(parent, 0.8)
	v.custom_minimum_size.x = 760
	v.add_child(_centered(heading, 32, UI.GOLD, "title"))
	v.add_child(UI.rule())
	for l in lines:
		v.add_child(_centered(str(l), 21, UI.BONE))
	v.add_child(UI.spacer(8))
	for i in options.size():
		var o: Array = options[i]
		var b := UI.button(str(o[0]), 21, 520)
		b.disabled = not bool(o[1])
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func():
			v.get_meta("layer").queue_free()
			chosen.call(i))
		v.add_child(b)
		v.add_child(_centered(str(o[2]), 15, UI.DIM))

static func message(parent: Node, heading: String, lines: Array, button: String, done: Callable, heading_color: Color = UI.GOLD) -> void:
	var v := _shell(parent, 0.66)
	v.add_child(_centered(heading, 32, heading_color, "title"))
	v.add_child(UI.rule())
	for l in lines:
		if l is Array:
			v.add_child(_centered(l[0], 22, l[1], "bold"))
		else:
			v.add_child(_centered(str(l), 21, UI.BONE))
	var b := UI.button(button, 22, 260)
	b.pressed.connect(func():
		v.get_meta("layer").queue_free()
		done.call())
	_button_row(v).add_child(b)
