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
	# centred inside the safe area, so nothing is under the notch or the home indicator
	var m := UI.margin(parent.get_viewport() if parent.is_inside_tree() else null, -8.0)
	layer.add_child(m)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(center)
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
## Three columns. Left: everything worn, each with its mastery bar filling by what this fight taught. Centre: the
## banner, the level bar filling, what was salvaged, any new piece on a card of its own (Compare, Inspect; a
## Legendary or a Relic later and more slowly, with its model turning), what Orren can now sell. Right: the gold won
## counting into the purse. It all runs in under two seconds and a tap anywhere finishes it at once; Continue is
## there from the first frame. Nothing spins or bursts.
static func victory(parent: Node, foe: Dictionary, r: Dictionary, sim: DuelSim, done: Callable) -> void:
	var v := _shell(parent, 0.86)
	var layer: CanvasLayer = v.get_meta("layer")
	var still: bool = bool(Game.settings.get("reduce_motion", false))
	if parent.get("hud") is CanvasLayer:
		(parent.get("hud") as CanvasLayer).visible = false       # the fight's bars are done with; the banner stands where they were
	var tweens: Array = []
	var run := func(delay: float) -> Tween:
		var tw := layer.create_tween()
		tw.tween_interval(maxf(delay, 0.001))
		tweens.append(tw)
		return tw
	# a tap on the ground behind finishes every count and reveal
	var bg: Control = layer.get_child(0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			for tw: Tween in tweens:
				if tw.is_valid():
					tw.custom_step(60.0))
	layer.set_meta("tweens", tweens)
	var items: Array = r.get("items_new", r.get("items", [])).duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--reveal="):                    # capture harness: show the reveal of this item
			items.append(Db.canon(a.trim_prefix("--reveal=")))
	var p: Dictionary = Game.profile
	v.custom_minimum_size.x = 1180
	v.add_theme_constant_override("separation", 6)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	v.add_child(cols)
	# ------------------------------------------------ left: what was worn, and what the fight taught it
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 310
	left.add_theme_constant_override("separation", 3)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cols.add_child(left)
	left.add_child(UI.label("MASTERY", 18, UI.DIM, "head"))
	left.add_child(UI.rule(Color(0.3, 0.27, 0.2)))
	var gain: int = 2 if foe.boss else 1
	var n := 0
	for slot_name: String in Db.EQUIP_SLOTS:
		var id = p.equipped.get(slot_name)
		if id == null or Db.item(str(id)).is_empty():
			continue
		var it: Dictionary = Db.item(str(id))
		var need := Stats.mastery_needed(it)
		var after := Game.mastery_points(str(id))
		var before: int = after if (p.mastered.has(id) and not r.mastered.has(id)) else maxi(0, after - gain)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		left.add_child(row)
		row.add_child(InvGlyph.new(slot_name, Db.rarity_color(it), 0, 24.0))
		var rv := VBoxContainer.new()
		rv.add_theme_constant_override("separation", -3)
		rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rv)
		var top := HBoxContainer.new()
		var nm := UI.label(str(it.name), 22, Db.rarity_color(it).lerp(UI.BONE, 0.3))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		top.add_child(nm)
		var mark := ""
		for mu: Dictionary in r.get("mastery_ups", []):
			if str(mu.id) == str(id):
				mark = "MARK " + UI.roman(int(mu.tier))
		var cnt := UI.label("Mastered" if after >= need and mark == "" else (mark if mark != "" else "%d/%d" % [after, need]), 22, UI.GOLD if after >= need or mark != "" else UI.DIM, "bold" if mark != "" else "body")
		top.add_child(cnt)
		rv.add_child(top)
		var bar := UI.bar(UI.GOLD if after > before else UI.GOLD_DIM, 6)
		bar.max_value = need
		bar.value = after if still else before
		rv.add_child(bar)
		if not still and after > before:
			run.call(0.35 + 0.07 * n).tween_property(bar, "value", float(after), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		n += 1
	# ------------------------------------------------ centre: the banner, the level, the spoils
	var mid := VBoxContainer.new()
	mid.custom_minimum_size.x = 560
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 5)
	cols.add_child(mid)
	mid.add_child(_centered("GUARDIAN ENDED" if foe.boss else "VICTORY", 40, UI.GOLD, "title"))
	mid.add_child(_centered(foe.name, 22, UI.SILVER, "head"))
	mid.add_child(_centre(UI.ornament(420)))
	var lvl_row := HBoxContainer.new()
	lvl_row.add_theme_constant_override("separation", 10)
	mid.add_child(lvl_row)
	var lvl_l := UI.label("LEVEL %d" % int(p.level), 22, UI.GOLD if int(r.levels) > 0 else UI.BONE, "head")
	lvl_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lvl_row.add_child(lvl_l)
	lvl_row.add_child(UI.label("+%d experience" % int(r.xp), 22, UI.BONE, "bold"))
	lvl_row.add_child(UI.label("·", 22, UI.DIM))
	lvl_row.add_child(UI.label("+%d shard%s" % [int(r.shards), "" if int(r.shards) == 1 else "s"], 22, UI.FROST.lerp(UI.BONE, 0.4), "bold"))
	var xp := UI.bar(UI.GOLD, 10)
	xp.max_value = Stats.xp_for_level(int(p.level))
	xp.value = float(int(p.xp))
	mid.add_child(xp)
	if not still:
		xp.value = 0.0 if int(r.levels) > 0 else maxf(0.0, float(int(p.xp) - int(r.xp)))
		run.call(0.3).tween_property(xp, "value", float(int(p.xp)), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if int(r.levels) > 0:
		mid.add_child(_centered("Level %d reached.  %d point%s to spend." % [p.level, p.attr_points, "" if int(p.attr_points) == 1 else "s"], 22, UI.GOLD, "bold"))
		Sfx.play("levelup", -3.0)
	# --- salvage: one plate a material
	var mats: Dictionary = r.get("materials", {})
	if not mats.is_empty():
		var mrow := HBoxContainer.new()
		mrow.alignment = BoxContainer.ALIGNMENT_CENTER
		mrow.add_theme_constant_override("separation", 8)
		mid.add_child(mrow)
		mrow.add_child(UI.label("SALVAGED", 18, UI.DIM, "head"))
		for m: String in mats:
			var chip := UI.panel(Color(0.05, 0.05, 0.06, 0.9), UI.GOLD_DIM if m == "m_core" else Color(0.26, 0.24, 0.19))
			chip.get_theme_stylebox("panel").set_content_margin_all(3)
			chip.get_theme_stylebox("panel").content_margin_left = 12
			chip.get_theme_stylebox("panel").content_margin_right = 12
			chip.add_child(UI.label("%d  %s" % [int(mats[m]), Db.material_name(m)], 22, UI.GOLD if m == "m_core" else UI.BONE, "bold"))
			mrow.add_child(chip)
	# --- new pieces and the lines under them share what height is left: a rich win scrolls, the button never moves
	var low := VBoxContainer.new()
	low.add_theme_constant_override("separation", 5)
	low.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var low_h := 0.0
	# --- new pieces: a card each, revealed after the counts
	var delay := 0.7
	for id: String in items:
		var it: Dictionary = Db.item(id)
		if it.is_empty():
			continue
		var grand: bool = Db.rarity_rank(it) >= 3
		var card := _item_card(layer, it, grand)
		low.add_child(card)
		low_h += 195.0 if grand else 91.0
		if not still:
			card.modulate.a = 0.0
			var tw2: Tween = run.call(delay + (0.4 if grand else 0.0))
			tw2.tween_callback(func(): Sfx.play("loot", -4.0 if grand else -8.0))
			tw2.tween_property(card, "modulate:a", 1.0, 1.2 if grand else 0.4).set_trans(Tween.TRANS_SINE)
			delay += 1.4 if grand else 0.4
	# --- everything else, in lines; a long list scrolls instead of pushing the button off the screen
	var lines: Array = []       # [text, colour, kind]
	for id in r.get("shop_unlocks", []):
		var si: Dictionary = Db.item(id)
		lines.append(["New in the shop:  %s  ·  %d gold" % [si.name, int(si.get("price", 0))], Db.rarity_color(si).lerp(UI.BONE, 0.25), "bold"])
	if int(r.get("compensation", {}).get("gold", 0)) > 0:
		lines.append(["You hold what it carried already: its worth in gold and ore instead.", UI.BONE, "body"])
	for mu: Dictionary in r.get("mastery_ups", []):
		if int(mu.tier) < 3:
			lines.append(["%s, mark %s:  %s" % [Db.item(str(mu.id)).name, UI.roman(int(mu.tier)), str(mu.text)], UI.GOLD.lerp(UI.BONE, 0.4), "body"])
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
	for l: Array in lines:
		var lab := _centered(str(l[0]), 22, l[1], str(l[2]))
		lab.custom_minimum_size.x = 540
		low.add_child(lab)
		low_h += 36.0 if str(l[0]).length() < 58 else 66.0
	if low.get_child_count() > 0:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var safe := UI.safe_margins(layer.get_viewport())
		sc.custom_minimum_size = Vector2(560, minf(low_h + 4.0, 318.0 - maxf(0.0, float(safe.t) + float(safe.b) - 48.0)))
		sc.add_child(low)
		mid.add_child(sc)
	# ------------------------------------------------ right: the gold won, counting into the purse
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 250
	right.add_theme_constant_override("separation", 0)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cols.add_child(right)
	var won := int(r.gold)
	var total := int(p.gold)
	right.add_child(_centered("GOLD WON", 18, UI.DIM, "head"))
	var won_l := _centered("+%d" % won, 54, UI.GOLD, "head")
	right.add_child(won_l)
	right.add_child(_centre(UI.ornament(220)))
	right.add_child(UI.spacer(6))
	right.add_child(_centered("YOUR PURSE", 18, UI.DIM, "head"))
	var purse_l := _centered("%d" % total, 36, UI.BONE, "head")
	right.add_child(purse_l)
	if not still and won > 0:
		# the pouch empties into the purse: one figure falls as the other rises
		purse_l.text = "%d" % (total - won)
		var twg: Tween = run.call(0.6)
		twg.tween_method(func(g: float):
			won_l.text = "+%d" % int(roundf(float(won) - g))
			purse_l.text = "%d" % (total - won + int(roundf(g))), 0.0, float(won), clampf(float(won) / 500.0, 0.5, 1.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		twg.tween_callback(func():
			won_l.text = "+%d" % won
			purse_l.add_theme_color_override("font_color", UI.GOLD))
	# ------------------------------------------------ the fight's own figures, and on
	v.add_child(UI.rule())
	v.add_child(_centered("%d parries, %d of them perfect   ·   %d dodges   ·   %d blows taken   ·   longest chain %d" % [sim.stats.parries, sim.stats.perfect_parries, sim.stats.dodges, sim.stats.hits_taken, sim.stats.max_combo], 20, UI.DIM))
	var b := UI.button("Continue", 22, 300)
	b.custom_minimum_size.y = 60
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
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	p.add_child(outer)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	outer.add_child(h)
	if grand:
		var st := ItemStage.new()
		st.body = str(Game.profile.get("body", "m"))
		st.custom_minimum_size = Vector2(170, 170)
		st.spin_speed = 0.35
		h.add_child(st)
		st.show_item(id)
	else:
		var g := InvGlyph.new(str(it.slot), col, 0, 34.0)
		g.custom_minimum_size = Vector2(38, 34)
		h.add_child(g)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tv)
	if grand:
		tv.add_child(UI.label("TAKEN FROM THE FALLEN", 18, UI.DIM, "head"))
	var nm := UI.title(("" if grand else "New:  ") + str(it.name), 26 if grand else 22, col)
	if not grand:
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if grand:
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size.x = 150
	tv.add_child(nm)
	tv.add_child(GearUI.kind_row(it, col))
	var btns := BoxContainer.new()
	btns.vertical = grand
	btns.add_theme_constant_override("separation", 4)
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(btns)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", -3)
	grid.visible = false
	outer.add_child(grid)
	var cmp := UI.button("Compare", 18, 136)
	cmp.pressed.connect(func():
		grid.visible = not grid.visible
		cmp.add_theme_color_override("font_color", UI.GOLD if grid.visible else UI.BONE)
		if grid.visible and grid.get_child_count() == 0:
			for row in Game.compare(str(it.slot), id):
				if grid.get_child_count() < 4 and (int(row.better) != 0 or row.now_text != row.then_text):
					grid.add_child(GearUI.effect(row))
			if grid.get_child_count() == 0:
				grid.add_child(UI.label("No change against what you wear", 22, UI.DIM)))
	btns.add_child(cmp)
	var ins := UI.button("Inspect", 18, 136)
	ins.pressed.connect(func():
		var view := ArmoryInspect.new(GearUI.inspect_entry(id), str(Game.profile.get("body", "m")), str(it.get("desc", "")))
		layer.add_child(view))
	btns.add_child(ins)
	return p

## The knight fell (an ordinary defeat; the two authored falls of the house have scenes of their own and never come
## here). The picture has already faded to black (Duel.DEATH_FADE). Near-black ground, a small sword mark between two thin
## rules, YOU HAVE FALLEN in wide-tracked capitals, a line in italics, then RETRY FROM CHECKPOINT and RETURN TO MAIN MENU.
## `actions`: "retry" (the road again from the last checkpoint) and "menu" (save, and the title); `done` stands in for
## whichever is missing. `foe` and `summary` are kept for the callers' sake and are not shown: nothing is lost.
static func death(parent: Node, _foe: Dictionary, _summary: Dictionary, done: Callable, actions: Dictionary = {}) -> void:
	var v := _shell(parent, 1.0)
	v.custom_minimum_size.x = 720
	v.add_theme_constant_override("separation", 6)
	# the sword between two rules
	var mark := HBoxContainer.new()
	mark.alignment = BoxContainer.ALIGNMENT_CENTER
	mark.add_theme_constant_override("separation", 18)
	mark.custom_minimum_size = Vector2(420, 64)
	for i: int in 3:
		if i == 1:
			mark.add_child(_sword_mark())
		else:
			var r := UI.rule(Color(UI.GOLD_DIM, 0.8))
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			mark.add_child(r)
	v.add_child(_centre(mark))
	v.add_child(UI.spacer(14))
	var t := _centered("YOU HAVE FALLEN", 54, UI.GOLD, "title")
	var tracked := FontVariation.new()
	tracked.base_font = UI.font("title")
	tracked.spacing_glyph = 12
	t.add_theme_font_override("font", tracked)
	v.add_child(t)
	v.add_child(UI.spacer(2))
	v.add_child(_centre(_italic("Your journey is not yet over.", 26, UI.BONE.darkened(0.12))))
	v.add_child(UI.spacer(34))
	var close := func(f: Callable):
		for c in v.find_children("*", "Button", true, false):
			(c as Button).disabled = true
		v.get_meta("layer").queue_free()
		f.call()
	var r := UI.button("Retry from checkpoint", 24, 470)
	r.custom_minimum_size.y = 72
	r.add_theme_color_override("font_color", UI.GOLD)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.pressed.connect(func(): close.call(actions.get("retry", done)))
	v.add_child(r)
	v.add_child(UI.spacer(4))
	var m := UI.menu_item("Return to main menu", 20, 380)
	m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.pressed.connect(func(): close.call(actions.get("menu", done)))
	v.add_child(m)

## One line of the body face slanted to the right (the game has no italic file): drawn under a skew about the baseline.
static func _italic(text: String, size: int, color: Color) -> Control:
	var f: Font = UI.font("body")
	var sz := UI.text_size(size)
	var ext := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
	var c := Control.new()
	c.custom_minimum_size = Vector2(ext.x + 14.0, f.get_height(sz) + 6.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("text", text)
	c.draw.connect(func():
		var base := f.get_ascent(sz) + 3.0
		var k := 0.22
		c.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-k, 1), Vector2(k * base, 0)))
		c.draw_string(f, Vector2(5, base + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.75))
		c.draw_string(f, Vector2(5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, color))
	return c

## A small upright sword, drawn in code: pommel, grip, cross-guard, blade to a point.
static func _sword_mark() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(26, 64)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var x := c.size.x * 0.5
		var col := UI.GOLD
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 3.5, 6), Vector2(x + 3.5, 41), Vector2(x - 3.5, 41), Vector2(x - 3.5, 6)]), col)
		c.draw_line(Vector2(x, 8), Vector2(x, 40), Color(0.1, 0.08, 0.04, 0.55), 1.0)        # the fuller
		c.draw_rect(Rect2(x - 12, 41, 24, 3.5), col)
		c.draw_rect(Rect2(x - 2, 44.5, 4, 14), col.darkened(0.25))
		c.draw_circle(Vector2(x, 61), 3.0, col))
	return c

static var _pause_layer: CanvasLayer     # the pause panel on screen, if any: one at a time (a second one outlived Resume)

static func pause(parent: Node, resume: Callable, abandon: Callable) -> void:
	if is_instance_valid(_pause_layer) and _pause_layer.is_inside_tree() and not _pause_layer.is_queued_for_deletion():
		return
	parent.get_tree().paused = true
	var v := _shell(parent, 0.8)
	_pause_layer = v.get_meta("layer")
	v.custom_minimum_size.x = 840
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
		v.add_child(_centered(str(o[2]), 18, UI.DIM))

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
