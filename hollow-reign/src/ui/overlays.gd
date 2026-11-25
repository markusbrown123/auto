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

static func victory(parent: Node, foe: Dictionary, r: Dictionary, sim: DuelSim, done: Callable) -> void:
	var v := _shell(parent, 0.6)
	v.add_child(_centered("GUARDIAN FELLED" if foe.boss else "FOE SLAIN", 40 if foe.boss else 30, UI.GOLD, "title"))
	v.add_child(_centered(foe.name, 22, UI.BONE, "head"))
	v.add_child(UI.rule())
	v.add_child(_centered("+%d xp        +%d gold        +%d shard%s" % [r.xp, r.gold, r.shards, "" if r.shards == 1 else "s"], 22, UI.BONE, "bold"))
	if r.levels > 0:
		v.add_child(_centered("Level %d reached  ·  %d points to spend" % [Game.profile.level, Game.profile.attr_points], 21, UI.GOLD, "bold"))
		Sfx.play("levelup", -3.0)
	for id in r.items:
		var it: Dictionary = Db.item(id)
		v.add_child(_centered("Found:  " + it.name, 22, Db.rarity_color(it), "bold"))
	for id in r.mastered:
		v.add_child(_centered("Mastered:  %s   (+1 point)" % Db.item(id).name, 19, UI.GOLD))
	v.add_child(_centered("%d parries (%d perfect)   ·   %d dodges   ·   %d blows taken   ·   best chain %d" % [sim.stats.parries, sim.stats.perfect_parries, sim.stats.dodges, sim.stats.hits_taken, sim.stats.max_combo], 16, UI.DIM))
	var b := UI.button("Continue", 22, 260)
	b.pressed.connect(func():
		v.get_meta("layer").queue_free()
		done.call())
	_button_row(v).add_child(b)

static func death(parent: Node, foe: Dictionary, summary: Dictionary, done: Callable) -> void:
	var v := _shell(parent, 0.82)
	v.add_child(_centered("THE REIGN ENDURES", 44, UI.BLOOD.lightened(0.15), "title"))
	v.add_child(_centered("%s stands. You wake in the sanctuary, as you always do." % foe.name, 21, UI.DIM))
	v.add_child(UI.rule())
	var kept := "Nothing was lost."
	if int(summary.get("xp", 0)) > 0 or not summary.get("found", []).is_empty():
		kept = "Kept:  %d xp,  %d gold" % [summary.get("xp", 0), summary.get("gold", 0)]
		if not summary.get("found", []).is_empty():
			kept += ",  %d item%s" % [summary.found.size(), "" if summary.found.size() == 1 else "s"]
	v.add_child(_centered(kept, 20, UI.BONE, "bold"))
	v.add_child(_centered("What you learned of its rhythm is yours as well.", 17, UI.DIM))
	var b := UI.button("Rise", 22, 260)
	b.pressed.connect(func():
		v.get_meta("layer").queue_free()
		done.call())
	_button_row(v).add_child(b)

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
