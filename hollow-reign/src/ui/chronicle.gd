class_name Chronicle
extends Control
## What the knight has found out: records read, sequences learned, guardians ended, endings seen,
## and (when the Witness is travelling with the knight) the stories it has told.

signal closed

const ENDING_NAME := {"silence": "The Final Silence", "steward": "The Last Steward", "cities": "The Free Cities"}
const ENDING_LINE := {
	"silence": "The Crown was disconnected, and everything it held went quiet.",
	"steward": "The Crown was taken up, to be worn differently.",
	"cities": "The Crown was divided, so that nobody could rule it.",
}
const DIR_WORD := {"L": "Left", "R": "Right", "U": "Up", "D": "Down", "UL": "Up-left", "UR": "Up-right", "DL": "Down-left", "DR": "Down-right"}

var tab := "Records"
var _tabs: HBoxContainer
var _body: VBoxContainer
var _scroll: ScrollContainer

func _init(start_tab: String = "Records") -> void:
	tab = start_tab

func tabs() -> Array:
	var out := ["Lineage", "Records", "Sequences", "Guardians", "Endings", "Completion"]
	if has_node("/root/Companion") and get_node("/root/Companion").has_method("archive"):
		out.append("Stories")
	return out

func _ready() -> void:
	UI.apply(self)
	UI.full(self)
	var dim: ColorRect = UI.full(ColorRect.new())
	dim.color = Color(0.01, 0.01, 0.015, 0.82)
	add_child(dim)
	var m := UI.margin(get_viewport(), 26)
	add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size.x = 900
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.add_child(col)
	col.add_child(UI.header("Chronicle", func(): closed.emit()))
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	col.add_child(_tabs)
	var p := UI.panel()
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size.x = 900
	col.add_child(p)
	UI.corners(p, UI.GOLD_DIM.lightened(0.2))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(_scroll)
	var pad := MarginContainer.new()      # keeps the text clear of the scroll hairline
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 16)
	_scroll.add_child(pad)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	pad.add_child(_body)
	if not tabs().has(tab):
		tab = "Records"
	show_tab(tab)

func show_tab(t: String) -> void:
	tab = t
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	for name_: String in tabs():
		var b := UI.button(name_, 17, 120)
		b.custom_minimum_size.y = 44
		if name_ == tab:
			b.add_theme_color_override("font_color", UI.GOLD)
			b.add_theme_stylebox_override("normal", UI._button_box("hover"))
		b.pressed.connect(func(): show_tab(name_))
		_tabs.add_child(b)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_scroll.scroll_vertical = 0
	call("_tab_" + t.to_lower())
	UI.stagger(_body, 0.02, 0.22)

func _head(text: String, note: String = "") -> void:
	var h := HBoxContainer.new()
	h.add_child(UI.title(text, 21, UI.GOLD))
	var gap := UI.spacer(0)
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(gap)
	if note != "":
		h.add_child(UI.label(note, 18, UI.DIM))
	_body.add_child(h)
	_body.add_child(UI.rule())

func _entry(heading: String, text: String, heading_color: Color = UI.BONE) -> void:
	_body.add_child(UI.label(heading, 20, heading_color, "bold"))
	if text != "":
		_body.add_child(UI.wrapped(text, 19, UI.DIM.lightened(0.25), 820))
	_body.add_child(UI.spacer(4))

## The house: everyone of it who has stood before the gates (Game.lineage()), oldest first. Who they were to the one
## now on the road, when, what became of them, what they carried and wore (shown on the knight itself, drawn by the
## same code that dresses the player), and what they did. Reading it changes nothing.
const FATE_WORD := {"alive": "On the road", "fallen": "Fell", "kept": "Fell beneath the throne"}
const CAUSE_LINE := {"sealed_hall": "Sealed in the hall, sending out what was found.", "saved_the_records": "Cut down at the seal, with the records secured."}
func _tab_lineage() -> void:
	var l: Dictionary = Game.lineage()
	if l.is_empty():
		_body.add_child(UI.label("Nobody of the house has yet set out.", 19, UI.DIM))
		return
	var held := 0
	for r: Dictionary in l.records:
		held += 1 if r.held else 0
	_head("House %s" % str(l.house), "%d of %d inheritance records" % [held, l.records.size()])
	for who: Dictionary in l.people:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		_body.add_child(row)
		row.add_child(_portrait(who))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var kin := str(who.kin)
		v.add_child(UI.label(("%s   ·   %s" % [str(who.chapter), "you" if who.current else "your " + kin.to_lower()]).to_upper(), 15, UI.GOLD_DIM.lightened(0.3), "head"))
		var named: String = str(who.display) if str(who.name) != "" else str(who.ordinal).capitalize()
		v.add_child(UI.title("%s, %s" % [named, str(who.ordinal)] if str(who.name) != "" else named, 24, UI.GOLD if who.current else UI.BONE))
		var when: String = "now" if int(who.years_ago) == 0 else "%d years ago" % int(who.years_ago)
		var fate := str(FATE_WORD.get(str(who.fate), str(who.fate).capitalize()))
		if str(who.fate) == "kept" and Game.generation() >= 3 and (Game.profile.flags.has("kept_revealed") or Game.profile.defeated.has("the_kept")):
			fate = "Kept by the throne" if not Game.profile.defeated.has("the_kept") else "Kept by the throne, and let go"
		v.add_child(UI.label("The %s   ·   %s   ·   %s" % [str(who.relation).to_lower(), when, fate], 18, UI.BONE))
		if CAUSE_LINE.has(str(who.cause)):
			v.add_child(UI.wrapped(str(CAUSE_LINE[str(who.cause)]), 17, UI.DIM.lightened(0.25), 600))
		# what they carried
		var lo: Dictionary = who.loadout
		var gear: Array = []
		var w: Dictionary = lo.get("weapon", {})
		if not w.is_empty() and Db.items.has(str(w.id)):
			var forge: Array = []
			if int(w.get("level", 0)) > 0:
				forge.append("+%d" % int(w.level))
			var mods: Dictionary = w.get("mods", {})
			if int(mods.get("grip", 0)) > 0:
				forge.append("grip %s" % UI.roman(int(mods.grip)))
			if int(mods.get("ore", 0)) > 0:
				forge.append("ore %s" % UI.roman(int(mods.ore)))
			gear.append(str(Db.item(str(w.id)).name) + (" (%s)" % ", ".join(forge) if not forge.is_empty() else ""))
		for slot: String in Db.EQUIP_SLOTS:
			var id = lo.get("equipped", {}).get(slot)
			if slot != "weapon" and id != null and Db.items.has(str(id)):
				gear.append(str(Db.item(str(id)).name))
		if not gear.is_empty():
			v.add_child(UI.wrapped("Carried:  " + "  ·  ".join(gear), 17, UI.BONE, 600))
		var left: Dictionary = who.weapon_left
		if not left.is_empty() and Db.items.has(str(left.id)):
			v.add_child(UI.wrapped("The blade stayed where it fell%s." % ("; the next of the house took it up" if left.get("taken", false) else ""), 17, UI.GOLD_DIM.lightened(0.3), 600))
		# what they did
		var d: Dictionary = who.deeds
		var deeds: Array = []
		if not d.guardians.is_empty():
			deeds.append("Guardians ended:  " + ", ".join(d.guardians.map(func(g): return str(g.name))))
		if not d.regions.is_empty():
			deeds.append("Roads cleared:  " + ", ".join(d.regions.map(func(g): return str(g.name))))
		if not d.routes.is_empty():
			deeds.append("Ways opened:  " + ", ".join(d.routes.map(func(g): return str(g.name))))
		if int(d.lore) + int(d.secrets) > 0:
			deeds.append("%d record%s read, %d secret%s found" % [int(d.lore), "" if int(d.lore) == 1 else "s", int(d.secrets), "" if int(d.secrets) == 1 else "s"])
		var st: Dictionary = who.stats
		if int(st.get("fights", 0)) > 0:
			deeds.append("%d fights, %d won" % [int(st.fights), int(st.wins)])
		if deeds.is_empty():
			deeds.append("What they did was not written down." if who.authored else "Nothing yet.")
		for line: String in deeds:
			v.add_child(UI.wrapped(line, 17, UI.DIM.lightened(0.25), 600))
		_body.add_child(UI.spacer(6))
		_body.add_child(UI.rule())
		_body.add_child(UI.spacer(6))
	_head("What the house holds")
	for r: Dictionary in l.records:
		_entry(str(r.name) if r.held else "Not yet gathered", str(r.text) if r.held else "", UI.GOLD if r.held else UI.DIM)
	if str(l.ending) != "":
		_body.add_child(UI.label("The house's story ended with %s." % str(ENDING_NAME.get(str(l.ending), l.ending)), 18, UI.GOLD_DIM.lightened(0.3)))

## One of the house, standing, in what they wore: a small view of its own, built by the rig the game fights with.
func _portrait(who: Dictionary) -> Control:
	var frame := SubViewportContainer.new()
	frame.custom_minimum_size = Vector2(190, 250)
	frame.stretch = true
	var vp := SubViewport.new()
	vp.size = Vector2i(190, 250)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.add_child(vp)
	var rig := FighterRig.new()
	vp.add_child(rig)
	var look := lineage_look(who)
	rig.ready.connect(func():          # dressed once it stands in the tree: the rig measures itself in world space
		rig.build(look, false)
		rig.rotation.y = PI * 0.9)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.position = Vector3(0.0, 1.05, 3.1)
	cam.fov = 38.0
	cam.look_at_from_position(cam.position, Vector3(0, 1.0, 0))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#8a8f99")
	e.ambient_light_energy = 1.1
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.8
	key.rotation_degrees = Vector3(-35, 30, 0)
	vp.add_child(key)
	return frame

## How one of the house looked, from their recorded loadout, by the code that dresses the player (the profile in
## memory is stood in for during the call, as the echo's rig is built).
static func lineage_look(who: Dictionary) -> Dictionary:
	var lo: Dictionary = who.get("loadout", {})
	var keep: Dictionary = Game.profile
	var stand := Game.default_profile()
	stand["body"] = str(who.get("body", "m"))
	stand["heraldry"] = str(lo.get("heraldry", keep.get("heraldry", stand.heraldry))) if str(lo.get("heraldry", "")) != "" else str(keep.get("heraldry", stand.heraldry))
	stand["cosmetics"] = lo.get("cosmetics", {}).duplicate(true)
	stand["inventory"] = []
	var eq: Dictionary = lo.get("equipped", {})
	if int(who.get("index", 2)) == 1 and eq.size() <= 1:
		# the first is recorded by their sword alone: they wore the garrison's silver (Prologue.KIT)
		eq = {"weapon": eq.get("weapon", "w_knight_sword")}
		for id: String in Prologue.KIT:
			if Db.items.has(id):
				eq[str(Db.item(id).slot)] = id
	for slot: String in stand.equipped:
		var id = eq.get(slot)
		stand.equipped[slot] = id if id != null and Db.items.has(str(id)) else null
		if stand.equipped[slot] != null:
			stand.inventory.append(stand.equipped[slot])
	if stand.equipped.weapon == null:
		stand.equipped.weapon = "w_rusted_sword"
	var w: Dictionary = lo.get("weapon", {})
	if not w.is_empty() and w.has("mods"):
		stand["mods"] = {str(w.id): w.mods.duplicate()}
	Game.profile = stand
	var look: Dictionary = Duel.player_look()
	Game.profile = keep
	look["witness"] = false
	return look

func _tab_records() -> void:
	var total := 0
	for r in Db.regions:
		if not Game.region_unlocked(r.id):
			continue
		var found: Array = []
		var all := 0
		for l in Db.lore:
			if str(l.region) == str(r.id):
				all += 1
				if Game.profile.lore.has(l.id):
					found.append(l)
		total += found.size()
		_head(str(r.name), "%d of %d" % [found.size(), all])
		for l in found:
			_entry(str(l.title), str(l.text), UI.BONE)
		# records that only a secret of this road gives: listed once found, never counted as missing
		for l in Secrets.hidden:
			if str(l.region) == str(r.id) and Game.profile.get("secret_lore", []).has(l.id):
				_entry(str(l.title) + "   ·   found off the road", str(l.text), UI.GOLD)
		if found.size() < all:
			var left := all - found.size()
			_body.add_child(UI.label("%d record%s here still unread." % [left, "" if left == 1 else "s"], 18, UI.DIM))
		_body.add_child(UI.spacer(10))
	_body.add_child(UI.label("%d of %d records recovered. Roads not yet walked are not listed." % [total, Db.lore.size()], 18, UI.GOLD_DIM.lightened(0.3)))

func _tab_sequences() -> void:
	var known := 0
	for c in Db.combos:
		known += 1 if Game.profile.combos.has(c.id) else 0
	_head("Sequences", "%d of %d found" % [known, Db.combos.size()])
	for c in Db.combos:
		if Game.profile.combos.has(c.id):
			var steps: Array = []
			for d in c.seq:
				steps.append(str(DIR_WORD.get(str(d), str(d))))
			var uses := int(Game.profile.combo_uses.get(c.id, 0))
			_entry("%s   ·   %s" % [c.name, "  ›  ".join(steps)], "%s.  %s%s" % [c.get("kind", "Sequence"), c.get("use", ""), ("   Used %d time%s." % [uses, "" if uses == 1 else "s"]) if uses > 0 else ""], UI.BONE)
		else:
			_entry("Not yet found", "", UI.DIM)

func _tab_guardians() -> void:
	var bosses: Array = []
	var ended := 0
	for id: String in Db.foes:
		if Db.foes[id].boss:
			bosses.append(Db.foes[id])
			ended += 1 if Game.profile.defeated.has(id) else 0
	_head("Guardians", "%d of %d ended" % [ended, bosses.size()])
	for f in bosses:
		if Game.profile.defeated.has(f.id):
			var n := int(Game.profile.defeated[f.id])
			_entry(str(f.name), "Ended%s." % ("" if n <= 1 else " %d times" % n), UI.GOLD)
		else:
			_entry("Not yet met", "", UI.DIM)

func _tab_endings() -> void:
	_head("Endings", "%d of %d seen" % [Game.profile.endings.size(), ENDING_NAME.size()])
	for id: String in ENDING_NAME:
		if Game.profile.endings.has(id):
			_entry(str(ENDING_NAME[id]), str(ENDING_LINE[id]), UI.GOLD)
		else:
			_entry("Not yet seen", "", UI.DIM)
	if int(Game.profile.ng) > 0:
		_body.add_child(UI.label("The kingdom has been walked %d time%s over." % [int(Game.profile.ng), "" if int(Game.profile.ng) == 1 else "s"], 18, UI.GOLD_DIM.lightened(0.3)))

func _tab_stories() -> void:
	var list = get_node("/root/Companion").archive()
	var n: int = list.size() if (list is Array or list is Dictionary) else 0
	_head("Stories", "%d heard" % n)
	if n == 0:
		_body.add_child(UI.label("Nothing has been told yet.", 19, UI.DIM))
		return
	if list is Dictionary:
		for k in list:
			_story(list[k], str(k))
	else:
		for s in list:
			_story(s, "")

func _story(s, fallback: String) -> void:
	if s is Dictionary:
		var heading := str(s.get("title", s.get("name", s.get("id", fallback))))
		var text = s.get("lines", s.get("text", s.get("summary", "")))
		if text is Array:
			# each line as it was spoken, with who spoke it
			var parts: Array = []
			for line in text:
				if line is Dictionary:
					var who := str(line.get("name", ""))
					parts.append(("%s:  " % who if who != "" else "") + str(line.get("text", "")))
				else:
					parts.append(str(line))
			text = "\n".join(parts)
		_entry(heading, str(text), UI.BONE)
	else:
		_entry(str(s) if fallback == "" else fallback, "" if fallback == "" else str(s))

## How much of the kingdom has been seen (Game.completion()): the figure, what it is made of, each road with a
## line or two about what is still there (never how to get it), and what the milestones give.
func _tab_completion() -> void:
	Secrets.data()
	var c: Dictionary = Game.completion()
	_head("The kingdom, seen", "%s%%" % _pct_text(float(c.pct)))
	var who := Game.title()
	if who != "":
		_body.add_child(UI.label("You are known as %s." % who, 19, UI.GOLD))
	_body.add_child(_meter(float(c.pct)))
	_body.add_child(_counts(c.categories, 18))
	for line: String in c.remains:
		_body.add_child(UI.wrapped("Something remains:  " + line, 18, UI.DIM.lightened(0.25), 820))
	_body.add_child(UI.spacer(8))
	for r: Dictionary in c.regions:
		if not r.unlocked:
			continue
		_head(str(r.name), "%s%%" % _pct_text(float(r.pct)))
		_body.add_child(_meter(float(r.pct)))
		_body.add_child(_counts(r.categories, 17))
		for line: String in r.remains:
			_body.add_child(UI.wrapped("Something remains here:  " + line, 17, UI.DIM.lightened(0.25), 820))
		_body.add_child(UI.spacer(8))
	_body.add_child(UI.label("Roads not yet reached are not listed.", 18, UI.GOLD_DIM.lightened(0.3)))
	_body.add_child(UI.spacer(8))
	_head("Milestones")
	for m: Dictionary in c.milestones:
		_entry("%d%%   ·   %s" % [int(m.at), "reached" if m.reached else "not yet"], "   ·   ".join(m.reward), UI.GOLD if m.reached else UI.DIM)
	var held: Array = Game.profile.get("completion", {}).get("trophies", [])
	if not held.is_empty():
		_head("Kept in the sanctuary", "%d" % held.size())
		for id: String in held:
			_entry(Secrets.label_of("trophy", id), str(Secrets.data().trophies.get(id, {}).get("text", "")), UI.BONE)

## "Stops walked 21 / 56" and the rest, each kept whole on its line.
func _counts(cats: Dictionary, size: int) -> Control:
	var flow := HFlowContainer.new()
	flow.custom_minimum_size.x = 820
	flow.add_theme_constant_override("h_separation", 26)
	flow.add_theme_constant_override("v_separation", 2)
	for cat: String in cats:
		var whole: bool = int(cats[cat].done) == int(cats[cat].total)
		flow.add_child(UI.label("%s  %d / %d" % [cats[cat].name, int(cats[cat].done), int(cats[cat].total)], size, UI.GOLD if whole else UI.BONE))
	return flow

func _pct_text(v: float) -> String:
	return "%d" % int(v) if is_equal_approx(v, roundf(v)) else "%.1f" % v

func _meter(pct: float) -> Control:
	var back := ColorRect.new()
	back.color = Color(1, 1, 1, 0.07)
	back.custom_minimum_size = Vector2(820, 8)
	var fill := ColorRect.new()
	fill.color = UI.GOLD
	fill.size = Vector2(820.0 * clampf(pct, 0.0, 100.0) / 100.0, 8)
	back.add_child(fill)
	return back
