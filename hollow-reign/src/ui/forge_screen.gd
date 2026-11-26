class_name ForgeScreen
extends Control
## Orren's bench. Left: what can be worked. Middle: the piece itself, turning, in the forge state it really has
## (the engraving of its blade tier, its grip, the colour of its ore, a polished edge while it is keen).
## Right: a weapon's four tracks (Blade, Grip, Ore, Sharpen), or the one level a shield or an armour piece has,
## each with where it stands, what the next step does to the duel's numbers, and what it costs in gold, shards and
## material with what is missing. The work itself is asked of the Sanctuary (`forge_work`), which pays, saves and
## plays the short sequence. Nothing here writes.

const WORK_SLOTS := ["weapon", "shield", "helm", "chest", "shoulders", "gauntlets", "legs", "boots"]
const TRACKS := ["blade", "grip", "ore", "sharpen"]
const VERB := {"blade": "Reforge", "grip": "Rewrap", "ore": "Smelt", "sharpen": "Sharpen", "": "Temper"}

var host: Node
var mode := "Work"                 # or "Patterns"
var sel := ""
var ore_pick := ""                 # the region ore chosen for the second ore tier
var stage: ItemStage
var track_btn := {}                # track ("" for the level of a shield or armour piece) -> Button

var _list: VBoxContainer
var _mid: VBoxContainer
var _tracks: VBoxContainer
var _modes: HBoxContainer
var _scroll: ScrollContainer
static var _demo: Array = []
static var _demo_read := false
static var _demo_clock := 0.0

func _init(sanctuary: Node, focus: String = "") -> void:
	host = sanctuary
	sel = focus

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
	row.add_theme_constant_override("separation", 10)
	UI.full(row)
	add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size.x = 310
	row.add_child(left)
	_modes = HBoxContainer.new()
	_modes.add_theme_constant_override("separation", 6)
	left.add_child(_modes)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)
	var p := UI.panel(Color(0.03, 0.03, 0.036, 0.9), Color(0.3, 0.27, 0.2))
	p.get_theme_stylebox("panel").set_content_margin_all(10)
	p.custom_minimum_size.x = 290
	row.add_child(p)
	_mid = VBoxContainer.new()
	_mid.add_theme_constant_override("separation", 2)
	p.add_child(_mid)
	stage = ItemStage.new()
	stage.body = str(Game.profile.get("body", "m"))
	stage.upright = true
	stage.custom_minimum_size = Vector2(270, 250)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mid.add_child(stage)
	UI.corners(p, UI.GOLD_DIM, 12.0)
	var tsc := ScrollContainer.new()
	tsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(tsc)
	_tracks = VBoxContainer.new()
	_tracks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tracks.add_theme_constant_override("separation", 4)
	tsc.add_child(_tracks)
	if not _demo_read:
		_demo_read = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--forge_demo="):
				for st: String in a.trim_prefix("--forge_demo=").split(",", false):
					var f := st.split(":")
					if f.size() >= 2:
						_demo.append([float(f[0]), f[1], f[2] if f.size() > 2 else "", f[3] if f.size() > 3 else ""])
	refresh()

func leave() -> void:
	ItemModel.clear()

func on_profile() -> void:
	refresh()

func workable() -> Array:
	var ids: Array = Game.sorted_items(WORK_SLOTS)
	var focus := str(host.get("_smith_focus")) if host else ""
	if ids.has(focus):
		ids.erase(focus)
		ids.push_front(focus)
	return ids

func select(id: String) -> void:
	sel = id
	ore_pick = ""
	refresh()

func refresh() -> void:
	GearUI.clear(_modes)
	for m: String in ["Work", "Patterns"]:
		var b := GearUI.chip(m, m == mode, 160)
		b.pressed.connect(func():
			mode = m
			refresh())
		_modes.add_child(b)
	GearUI.clear(_list)
	var ids := workable()
	if not ids.has(sel):
		sel = str(ids[0]) if not ids.is_empty() else ""
	for id: String in ids:
		var it: Dictionary = Db.item(id)
		var lvl := Game.upgrade_level(id)
		var b := GearUI.item_row(it, id == sel and mode == "Work", false, str(it.name) + (" +%d" % lvl if lvl > 0 else ""))
		(b.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_right = 34
		if Game.is_equipped(id):
			# worn: a gold diamond at the row's end
			var d := Control.new()
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			d.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
			d.offset_left = -28
			d.offset_right = -12
			d.offset_top = -8
			d.offset_bottom = 8
			d.draw.connect(func(): d.draw_colored_polygon(PackedVector2Array([Vector2(8, 1), Vector2(15, 8), Vector2(8, 15), Vector2(1, 8)]), UI.GOLD))
			b.add_child(d)
		b.pressed.connect(func():
			mode = "Work"
			select(id))
		_list.add_child(b)
	_fill_mid()
	GearUI.clear(_tracks)
	track_btn.clear()
	if mode == "Patterns":
		_fill_patterns()
	elif sel != "":
		if Db.item(sel).get("slot", "") == "weapon" and Db.item(sel).has("mods"):
			for t: String in TRACKS:
				_tracks.add_child(_track(t))
		else:
			_tracks.add_child(_level_strip())

# ================================================================ the piece and what is held
func _fill_mid() -> void:
	for c in _mid.get_children():
		if c != stage:
			_mid.remove_child(c)
			c.queue_free()
	var it: Dictionary = Db.item(sel)
	stage.show_item(sel if not it.is_empty() else "")
	if it.is_empty():
		return
	var col: Color = Db.rarity_color(it)
	var ttl := UI.title(str(it.name), 22, col)
	ttl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ttl.custom_minimum_size.x = 260
	_mid.add_child(ttl)
	if it.slot == "weapon" and it.has("mods"):
		var w := Game.weapon_mods(sel)
		var state := UI.wrapped("%s · %s" % [ore_name(w), "keen for %d more fight%s" % [int(w.edge), "" if int(w.edge) == 1 else "s"] if int(w.edge) > 0 else "edge unhoned"], GearUI.TEXT, GearUI.GOOD if int(w.edge) > 0 else UI.DIM, 260)
		_mid.add_child(state)
		if ItemModel.gear_id(it) == "":
			_mid.add_child(UI.wrapped("Its model does not show forge work yet.", GearUI.TEXT, UI.GOLD_DIM, 260))
	else:
		_mid.add_child(UI.label("Level %d of %d" % [Game.upgrade_level(sel), int(it.get("upgrade", {}).get("max", 0))], GearUI.TEXT, UI.DIM))
	_mid.add_child(UI.rule(Color(0.3, 0.27, 0.2)))
	_mid.add_child(UI.label("ON THE BENCH", 18, UI.DIM, "head"))
	var held: Array = []
	for m: Dictionary in Game.materials_list():
		if int(m.count) > 0 or str(m.id) == "shards":
			held.append("%d %s" % [int(m.count), str(m.name)])
	_mid.add_child(UI.wrapped(" · ".join(held), GearUI.TEXT, UI.BONE, 260))

func ore_name(w: Dictionary) -> String:
	match int(w.ore):
		0: return "Plain iron"
		1: return "Steel"
	var nm := str(Db.equipment.mods.ores.get(str(w.ore_id), {}).get("name", "Ore"))
	return nm if int(w.ore) == 2 else nm + ", cored"

# ================================================================ a strip
## One line of work: its name and where it stands, what the next step does, what it costs, and the button.
func _strip(title: String, at: int, cap: int, top: int, tier_note: String, effects: Array, cost: Dictionary, block: String, verb: String, on_press: Callable, extra: Control = null) -> PanelContainer:
	var p := UI.panel(Color(0.045, 0.045, 0.055, 0.94), Color(0.26, 0.24, 0.19))
	p.get_theme_stylebox("panel").set_content_margin_all(8)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(UI.title(title, 22, UI.GOLD))
	if top > 0:
		var marks := InvGlyph.new("marks", UI.GOLD, at, 16.0)
		marks.total = top
		marks.custom_minimum_size.x = 16.0 * 0.95 * top
		head.add_child(marks)
	if tier_note != "":
		head.add_child(UI.label(tier_note, GearUI.TEXT, UI.BONE))
	var fx := HFlowContainer.new()
	fx.add_theme_constant_override("h_separation", 18)
	fx.add_theme_constant_override("v_separation", -3)
	for e in effects:
		if e is Control:
			fx.add_child(e)
		else:
			var l := UI.label(str(e), GearUI.TEXT, UI.BONE)
			if str(e).length() > 34:
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size.x = 340
			fx.add_child(l)
	v.add_child(fx)
	if extra:
		v.add_child(extra)
	var done: bool = block == "Perfected"
	if not done and not cost.is_empty():
		v.add_child(GearUI.cost_flow(cost))
		var lack := GearUI.shortfall_text(cost)
		if lack != "":
			v.add_child(UI.label(lack, GearUI.TEXT, UI.GOLD_DIM.lightened(0.25)))
	var b := UI.button(verb if block == "" else block, 20 if block == "" else 16, 176)
	b.custom_minimum_size.y = 64
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.disabled = block != ""
	if done:
		b.add_theme_color_override("font_disabled_color", UI.GOLD_DIM.lightened(0.2))
	b.pressed.connect(on_press)
	h.add_child(b)
	return p

func _effects(rows: Array, limit: int = 3) -> Array:
	var out: Array = []
	for r in rows.slice(0, limit):
		out.append(GearUI.effect(r))
	return out

func _track(t: String) -> PanelContainer:
	var it: Dictionary = Db.item(sel)
	var w := Game.weapon_mods(sel)
	var rule: Dictionary = Db.equipment.mods[t]
	var worn := Game.is_equipped(sel)
	var extra: Control = null
	var ore := ""
	var at := 0
	var cap := 0
	var top := 0
	var tier_note := ""
	var fx: Array = []
	match t:
		"blade", "grip":
			at = int(w[t])
			top = int(w.max[t])
			cap = int(w.caps[t])
			tier_note = "%s of %s" % [UI.roman(at) if at > 0 else "0", UI.roman(top)]
			if at >= cap and at < top:
				tier_note += " · this ore allows no more"
		"ore":
			at = int(w.ore)
			top = int(w.max.ore)
			cap = top
			tier_note = ore_name(w)
			if at == 1:
				ore = _ore_default(it)
				extra = _ore_picker(ore)
		"sharpen":
			tier_note = "keen · %d fight%s left" % [int(w.edge), "" if int(w.edge) == 1 else "s"] if int(w.edge) > 0 else "lasts %d fights" % int(rule.fights)
	var block := Game.mod_block(sel, t, ore)
	if block == "Perfected":
		fx = ["Orren can do no more here."]
	elif t == "sharpen" and int(w.edge) > 0:
		fx = ["The edge is still keen: +%d%% damage. It cannot be stacked." % int(rule.damage_pct)]
	else:
		var rows: Array = Game.mod_preview(sel, t, ore) if worn else []
		fx = _effects(rows)
		if fx.is_empty():
			fx = [str(rule.text) + ("" if worn else " Equip it to see your own figures.")]
		if t == "ore" and at == 0:
			fx.append("Allows blade %s and grip %s." % [UI.roman(int(rule.blade_cap[1])), UI.roman(int(rule.grip_cap[1]))])
		elif t == "ore" and at >= 1 and at < top:
			fx.append("Allows blade %s and grip %s." % [UI.roman(int(rule.blade_cap[at + 1])), UI.roman(int(rule.grip_cap[at + 1]))])
	var strip := _strip(str(rule.name), at, cap, top, tier_note, fx, Game.mod_cost(sel, t, ore), block, str(VERB[t]),
		func(): host.call("forge_work", sel, t, ore), extra)
	track_btn[t] = strip.get_child(0).get_child(1)
	return strip

## The ore the picker starts on: the last one chosen, else the blade's own metal, else the first that can be paid for.
func _ore_default(it: Dictionary) -> String:
	var ores: Dictionary = Db.equipment.mods.ores
	if ores.has(ore_pick):
		return ore_pick
	var need: int = int(Db.equipment.mods.ore.ore_count)
	for id: String in ores:
		if Game.material_count(id) >= need:
			return id
	return str(it.get("mat", "m_iron")) if ores.has(str(it.get("mat", ""))) else str(ores.keys()[0])

## Which region's metal the blade is reforged in: each marks it differently.
func _ore_picker(current: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	v.add_child(h)
	var ores: Dictionary = Db.equipment.mods.ores
	for id: String in ores:
		var have := Game.material_count(id)
		var b := GearUI.chip(str(ores[id].name).get_slice(" ", str(ores[id].name).get_slice_count(" ") - 1).trim_suffix("steel"), id == current, 0, 15)
		for state: String in ["normal", "hover", "pressed"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
			sb.content_margin_left = 4
			sb.content_margin_right = 4
			b.add_theme_stylebox_override(state, sb)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 46
		if have <= 0 and id != current:
			b.add_theme_color_override("font_color", UI.DIM)
		var sw := ColorRect.new()
		sw.color = ItemModel.ore_color(id).lerp(Color(0.5, 0.5, 0.5), 0.0) * Color(0.62, 0.62, 0.62)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sw.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		sw.offset_top = -5
		sw.offset_left = 3
		sw.offset_right = -3
		sw.offset_bottom = -2
		b.add_child(sw)
		b.pressed.connect(func():
			ore_pick = id
			refresh())
		h.add_child(b)
	v.add_child(UI.label("%s: %s" % [str(ores[current].name), str(ores[current].text)], GearUI.TEXT, UI.BONE))
	return v

## A shield's or an armour piece's one track: its level.
func _level_strip() -> PanelContainer:
	var it: Dictionary = Db.item(sel)
	var pv: Dictionary = Game.upgrade_preview(sel)
	var lvl := int(pv.level)
	var block := str(pv.block)
	var fx: Array = []
	if block == "Perfected":
		fx = ["Orren can do no more for it."]
	elif block == "Cannot be worked":
		fx = ["Nothing Orren could do to it would change a blow."]
	else:
		fx = _effects(pv.rows, 4)
		if fx.is_empty():
			if float(pv.item_then) != float(pv.item_now):
				fx.append(GearUI.effect(GearUI.plain_row("Defence", "%.1f" % float(pv.item_now), "%.1f" % float(pv.item_then))))
			if it.slot == "shield":
				fx.append(GearUI.effect(GearUI.plain_row("Guard", "%.0f%%" % ((float(it.get("block", 0)) + 0.03 * lvl) * 100.0), "%.0f%%" % ((float(it.get("block", 0)) + 0.03 * (lvl + 1)) * 100.0))))
				if it.has("blocks") and (lvl + 1) / 2 > lvl / 2:
					fx.append(GearUI.effect(GearUI.plain_row("Blocks", str(int(it.blocks) + lvl / 2), str(int(it.blocks) + (lvl + 1) / 2))))
			fx.append("Put it on to see your own figures.")
		elif it.slot == "shield" and it.has("blocks") and (lvl + 1) / 2 == lvl / 2:
			fx.append("Every second level adds a block.")
	var strip := _strip("Temper", lvl, int(pv.max), int(pv.max), "level %d of %d" % [lvl, int(pv.max)], fx, pv.cost, block, str(VERB[""]), func(): host.call("forge_work", sel, "", ""))
	track_btn[""] = strip.get_child(0).get_child(1)
	return strip

# ================================================================ patterns and the challenge
func _fill_patterns() -> void:
	var stock: Array = Game.craft_stock()
	if stock.is_empty():
		_tracks.add_child(UI.wrapped("Orren has no pattern he could work from yet. They come with the lands you reach.", GearUI.TEXT, UI.DIM, 500))
	for it in stock:
		var id := str(it.id)
		var block := Game.craft_block(id)
		var kind := GearUI.kind_row(it, Db.rarity_color(it))
		var strip := _strip(str(it.name), 0, 0, 0, "", [kind, str(it.get("desc", ""))], it.craft, block, "Make", func():
			if Game.craft(id):
				Sfx.play("loot", -3.0))
		track_btn["craft:" + id] = strip.get_child(0).get_child(1)
		_tracks.add_child(strip)
	for cid: String in Db.challenges:
		if Game.profile.challenges_done.has(cid):
			continue
		var c: Dictionary = Db.challenges[cid]
		var ready := Game.challenge_ready(cid)
		var reward: Dictionary = Db.item(str(c.reward.get("item", "")))
		var lines: Array = [str(c.text)]
		if not reward.is_empty():
			lines.append("Orren will make: %s" % (str(reward.name) if Game.is_discovered(str(reward.id)) else "something he will not describe"))
		_tracks.add_child(_strip(str(c.name), 0, 0, 0, "a proving", lines, {}, "" if ready else "Not yet", "Claim", func(): Game.claim_challenge(cid)))

# ================================================================ scripted input for captures
## --forge_demo=<t>:<action>[:<a>[:<b>]],...   sel:<id>  mod:<track>[:<ore>] (with the sequence)  quick:<track>[:<ore>] (paid, no sequence)
##   ore:<id>  mode:<Work|Patterns>  skip (ends a running sequence)  done (presses Continue)
func _process(delta: float) -> void:
	_demo_clock += delta
	while not _demo.is_empty() and _demo_clock >= float(_demo[0][0]):
		var st: Array = _demo.pop_front()
		var a := str(st[2])
		match str(st[1]):
			"sel": select(a)
			"ore":
				ore_pick = a
				refresh()
			"mode":
				mode = a
				refresh()
			"mod": host.call("forge_work", sel, a if a != "level" else "", str(st[3]))
			"quick":
				if a == "level":
					Game.upgrade(sel)
				else:
					Game.mod(sel, a, str(st[3]))
			"skip", "done":
				for n in (host.get("layer") as Node).get_children():
					if n is ForgeSeq:
						if str(st[1]) == "skip":
							n._t = n.REVEAL_AT
						else:
							n._finish()
