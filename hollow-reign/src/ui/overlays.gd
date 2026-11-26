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
	c.add_child(_centered(name.to_upper(), 15, UI.DIM, "head"))
	return c

static func _centre(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c

## What was won. `r` is Game.on_victory()'s summary; it may also carry "new_combos" (ids) and "lore" (ids).
static func victory(parent: Node, foe: Dictionary, r: Dictionary, sim: DuelSim, done: Callable) -> void:
	var v := _shell(parent, 0.62)
	v.custom_minimum_size.x = 640
	v.add_theme_constant_override("separation", 6)
	v.add_child(_centered("GUARDIAN ENDED" if foe.boss else "IT IS DONE", 40 if foe.boss else 30, UI.GOLD, "title"))
	v.add_child(_centered(foe.name, 21, UI.SILVER, "head"))
	v.add_child(_centre(UI.ornament(420)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	row.add_child(_tally("+%d" % int(r.xp), "experience"))
	row.add_child(_tally("+%d" % int(r.gold), "gold", UI.GOLD))
	row.add_child(_tally("+%d" % int(r.shards), "shard" if int(r.shards) == 1 else "shards", UI.FROST.lerp(UI.BONE, 0.4)))
	v.add_child(UI.spacer(4))
	if int(r.levels) > 0:
		v.add_child(_centered("Level %d reached.  %d points to spend." % [Game.profile.level, Game.profile.attr_points], 21, UI.GOLD, "bold"))
		Sfx.play("levelup", -3.0)
	for id in r.items:
		var it: Dictionary = Db.item(id)
		v.add_child(_centered("Found:  " + str(it.name), 21, Db.rarity_color(it), "bold"))
	var mats: Array = []
	for m: String in r.get("materials", {}):
		mats.append("%d %s" % [int(r.materials[m]), Db.material_name(m)])
	if not mats.is_empty():
		v.add_child(_centered("Salvaged:  " + ",  ".join(mats), 18, UI.BONE))
	for id in r.get("discoveries", []):
		v.add_child(_centered("Word of something:  %s" % Game.item_hint(id), 17, UI.SILVER))
	for id in r.mastered:
		v.add_child(_centered("Mastered:  %s.  One more point to spend." % Db.item(id).name, 19, UI.GOLD))
	for id in r.get("new_combos", []):
		if Db.combo_by_id.has(id):
			v.add_child(_centered("Sequence found:  %s" % Db.combo_by_id[id].name, 19, UI.BONE, "bold"))
	for id in r.get("lore", []):
		if Db.lore_by_id.has(id):
			v.add_child(_centered("Record:  %s" % Db.lore_by_id[id].title, 19, UI.BONE, "bold"))
	v.add_child(UI.spacer(2))
	v.add_child(UI.rule())
	v.add_child(_centered("%d parries, %d of them perfect   ·   %d dodges   ·   %d blows taken   ·   longest chain %d" % [sim.stats.parries, sim.stats.perfect_parries, sim.stats.dodges, sim.stats.hits_taken, sim.stats.max_combo], 16, UI.DIM))
	var b := UI.button("Continue", 22, 260)
	b.pressed.connect(func():
		v.get_meta("layer").queue_free()
		done.call())
	_button_row(v).add_child(b)

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
