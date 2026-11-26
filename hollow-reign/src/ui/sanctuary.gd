class_name Sanctuary
extends Node
## The hub between runs: choose a road, manage equipment, visit the
## blacksmith, spend attribute points, change settings.

signal set_out(region_id: String, use_shortcut: bool)
signal quit_to_title
signal train

const TABS := ["Journey", "Armory", "Shop", "Blacksmith", "Character", "Journal", "Settings"]
const TAB_LABEL := {"Blacksmith": "Forge"}     # the tab keeps its name for callers; the bar shows the shorter word
const WIDE := ["Armory", "Shop", "Blacksmith"]  # tabs that use the whole width instead of the right-hand panel
const GOOD := Color("#8fb37a")
const BAD := Color("#c2574a")
const CAM_POS := Vector3(2.5, 1.45, 3.4)
const CAM_LOOK := Vector3(1.15, 1.05, 0)

var backdrop: Backdrop
var layer: CanvasLayer
var content: Control
var purse: Label
var screen: Control             # the shop or the forge (src/ui/shop_screen.gd, forge_screen.gd), alive only while its tab is open
var shop_mode := "Wares"
var _gold_shown := -1.0         # the figure the purse is showing while it counts to the real one
var _gold_tw: Tween
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
var _dev := {}                  # capture harness: --item=<id> --mastery=<n> --smith=<mode> --forge=<id>

func _ready() -> void:
	backdrop = Backdrop.new()
	add_child(backdrop)
	backdrop.build("sanctuary")
	backdrop.move_camera(CAM_POS, CAM_LOOK, true)
	Game.sync_mastery()
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		if kv[0] in ["item", "smith", "forge", "mastery", "shopmode", "gold", "mats", "edge", "mods", "quiet"] and kv.size() > 1:
			_dev[kv[0]] = kv[1]
	if _dev.has("mastery") and _dev.has("item"):
		Game.profile.mastery[str(_dev.item)] = int(_dev.mastery)
		Game.sync_mastery()
	smith_mode = str(_dev.get("smith", smith_mode))
	shop_mode = str(_dev.get("shopmode", shop_mode))
	_dev_state()
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
		var b := UI.button(str(TAB_LABEL.get(t, t)), 17, 122)
		b.custom_minimum_size.y = 44
		b.pressed.connect(func(): show_tab(t))
		nav.add_child(b)
		tab_buttons[t] = b
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.add_child(gap)
	purse = UI.label("", 22, UI.GOLD, "bold")
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

## While somebody is speaking the whole hub draws its bottom edge up above the subtitle, so a line is never read
## across the buttons (the armoury's actions, the shop's Buy) and they are never hidden by it.
const SPEECH_LIFT := 122.0
var _lift := 0.0
var _base_bottom := -1

func _process(delta: float) -> void:
	if frame == null:
		return
	if _base_bottom < 0:
		_base_bottom = frame.get_theme_constant("margin_bottom")
	var want: float = SPEECH_LIFT if Story.busy else 0.0
	if is_equal_approx(_lift, want):
		return
	_lift = want if bool(Game.settings.reduce_motion) or absf(_lift - want) < 0.5 else lerpf(_lift, want, 1.0 - exp(-delta * 9.0))
	frame.add_theme_constant_override("margin_bottom", _base_bottom + int(_lift))

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
	if tab in ["Shop", "Blacksmith"] and screen:
		# the shop and the forge keep their place too
		_purse()
		backdrop.refresh_knight()
		screen.call("on_profile")
		return
	backdrop.refresh_knight()
	show_tab(tab)

## The purse counts to its new figure when gold is earned or spent, and warms for a moment.
func _purse() -> void:
	var p: Dictionary = Game.profile
	var gold := float(int(p.gold))
	if _gold_shown < 0.0 or bool(Game.settings.reduce_motion) or is_equal_approx(gold, _gold_shown):
		if _gold_tw:
			_gold_tw.kill()
		_gold_shown = gold
		_purse_text(gold)
		return
	if _gold_tw:
		_gold_tw.kill()
	purse.add_theme_color_override("font_color", Color("#f2dfa8") if gold > _gold_shown else Color("#d9a58a"))
	_gold_tw = create_tween()
	_gold_tw.tween_method(_purse_text, _gold_shown, gold, clampf(absf(gold - _gold_shown) / 400.0, 0.35, 0.9)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_gold_tw.tween_callback(func(): purse.add_theme_color_override("font_color", UI.GOLD))

func _purse_text(gold: float) -> void:
	_gold_shown = gold
	purse.text = "%d GOLD      %d SHARDS" % [int(roundf(gold)), int(Game.profile.shards)]

## From the armoury's Upgrade: the forge, with that item at the head of the list.
func open_forge(id: String) -> void:
	smith_mode = "Upgrade"
	_smith_focus = id
	show_tab("Blacksmith")

## Capture harness: a known purse and bench.  --gold=<n>  --mats=<id>:<n>,...  --edge=<weapon id>:<fights>
##   --mods=<weapon id>:<track>[:<ore>],...   (forge work applied at once, paid for from a purse topped up for it)
func _dev_state() -> void:
	if _dev.has("quiet"):
		Game.profile.flags["scene_orren_intro"] = true
		Game.profile.flags["orren_spoke"] = 99999
		Game.profile.flags["scene_sanctuary_return"] = true
	if _dev.has("gold"):
		Game.profile.gold = int(_dev.gold)
	for kv: String in str(_dev.get("mats", "")).split(",", false):
		Game.add_material(kv.get_slice(":", 0), int(kv.get_slice(":", 1)))
	for step: String in str(_dev.get("mods", "")).split(",", false):
		var f := step.split(":")
		var keep: Array = [Game.profile.gold, Game.profile.shards, Game.profile.materials.duplicate()]
		Game.profile.gold = 99999
		Game.profile.shards = 99
		for m: String in Db.materials:
			Game.profile.materials[m] = 99
		Game.mod(f[0], f[1], f[2] if f.size() > 2 else "")
		Game.profile.gold = keep[0]
		Game.profile.shards = keep[1]
		Game.profile.materials = keep[2]
	if _dev.has("edge"):
		Game.profile.edge[str(_dev.edge).get_slice(":", 0)] = int(str(_dev.edge).get_slice(":", 1))

func show_tab(t: String) -> void:
	tab = t
	for k in tab_buttons:
		tab_buttons[k].add_theme_color_override("font_color", UI.GOLD if k == t else UI.BONE)
	if armory:
		armory.leave()
		armory = null
	if screen:
		screen.call("leave")
		screen = null
	for holder: Control in [content, stage]:
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
	_panel.visible = not WIDE.has(t)
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
## The equipment screen is its own scene (src/ui/armory/armory_screen.gd): a swipe carousel of the collection
## and the live knight wearing a preview. It fills the whole body of the hub; the right-hand panel is hidden for it.
func _tab_armory() -> void:
	var item := ""
	if _dev.has("item"):
		item = str(_dev.item)
		_dev.erase("item")
	armory = ArmoryScreen.new(self, backdrop, sel_slot, item)
	stage.add_child(armory)

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
	var fs := ForgeScreen.new(self, _smith_focus)
	if smith_mode == "Patterns":
		fs.mode = "Patterns"
	screen = fs
	stage.add_child(fs)

## Orren's counter: wares (with what is still locked), the materials stall, and what he buys.
func _tab_shop() -> void:
	_orren_remark()
	var item := ""
	if _dev.has("item"):
		item = str(_dev.item)
		_dev.erase("item")
	var sh := ShopScreen.new(self, shop_mode, item)
	screen = sh
	stage.add_child(sh)

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
		if it.has("blocks") and (lvl + 1) / 2 > lvl / 2:
			rows.append(["Blocks", str(int(it.blocks) + lvl / 2), str(int(it.blocks) + (lvl + 1) / 2), "+1"])
	if Game.is_equipped(it.id):
		if it.slot == "weapon":
			rows.append(["Your attack", "%.1f" % before.attack, "%.1f" % after.attack, "+%.1f" % (float(after.attack) - float(before.attack))])
		else:
			rows.append(["Damage guarded", "%.1f%%" % (float(before.mitigation) * 100.0), "%.1f%%" % (float(after.mitigation) * 100.0), "+%.1f%%" % ((float(after.mitigation) - float(before.mitigation)) * 100.0)])
	return rows

## The old one-button upgrade (a weapon's next blade tier, taking the ore step with it when it must).
func _forge(id: String) -> void:
	if _forging or not Game.can_upgrade(id):
		return
	var it: Dictionary = Db.item(id)
	var lvl := Game.upgrade_level(id)
	var before := Game.stats()
	var mod_before = ItemModel.gear_mod(it) if it.slot == "weapon" else {}
	_forging = true
	_smith_focus = id
	Game.upgrade(id)        # paid for and saved now; the sequence is only the telling of it
	var rows := _upgrade_rows(it, lvl, before, Game.stats())
	await _play_forge(ForgeSeq.new(backdrop, id, lvl + 1, rows, mod_before))

## One step of forge work, asked for by the forge screen: `track` is "blade", "grip", "ore" or "sharpen" for a
## weapon, "" for the level of a shield or an armour piece. Paid for and saved before the sequence plays.
func forge_work(id: String, track: String = "", ore_id: String = "") -> bool:
	if track == "":
		if _forging or not Game.can_upgrade(id):
			return false
		_forge(id)
		return true
	if _forging or not Game.can_mod(id, track, ore_id):
		return false
	var it: Dictionary = Db.item(id)
	var rule: Dictionary = Db.equipment.mods[track]
	var rows: Array = Game.mod_preview(id, track, ore_id)
	var mod_before = ItemModel.gear_mod(it)
	_forging = true
	_smith_focus = id
	Game.mod(id, track, ore_id)
	var w := Game.weapon_mods(id)
	var what := ""
	var line := ""
	match track:
		"blade", "grip": what = "%s %s" % [rule.name, UI.roman(int(w[track]))]
		"ore":
			what = "Plain iron" if int(w.ore) == 0 else ("Steel" if int(w.ore) == 1 else str(Db.equipment.mods.ores.get(str(w.ore_id), {}).get("name", "Ore")) + (", cored" if int(w.ore) == 3 else ""))
			if int(w.ore) == 2:
				line = str(Db.equipment.mods.ores.get(str(w.ore_id), {}).get("text", ""))
		"sharpen":
			what = "A keen edge"
			line = "For the next %d fights, win or lose." % int(w.edge)
	if rows.is_empty() and line == "":
		line = str(rule.text)
	_play_forge(ForgeSeq.new(backdrop, id, "%s · %s" % [it.name, what], rows.slice(0, 4), mod_before, line))
	return true

func _play_forge(seq: ForgeSeq) -> void:
	frame.visible = false
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
	qhead.add_child(UI.label("%d of %d done" % [p.quests_done.size(), Game.journal_quests().size()], 18, UI.DIM))
	for q in Game.journal_quests():
		var done: bool = p.quests_done.has(q.id)
		var qrow := _row()
		v.add_child(qrow)
		var qv := VBoxContainer.new()
		qv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qv.add_theme_constant_override("separation", -3)
		qrow.add_child(qv)
		var qtitle := _row()
		qtitle.add_child(UI.label(str(q.name), 20, UI.DIM if done else UI.GOLD, "bold"))
		qtitle.add_child(UI.label(str(q.giver).to_upper() + ("  ·  IN PASSING" if q.get("side", false) else ""), 13, UI.DIM))
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
