extends Node
## Headless check of the armoury (equipment screen):
##   godot --headless --path . res://tests/armory.tscn
## Browsing and previewing every item of every slot must leave the save file byte-identical and the profile
## untouched; Equip must change exactly one slot; locked items cannot be equipped; the scripted drag goes
## down the same path as a finger and comes to rest on an item.
var failed := 0

func ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		failed += 1

func settle(a: ArmoryScreen) -> void:
	for i in 4000:
		await get_tree().process_frame
		if not a.carousel.moving and a._preview_due < 0.0 and not a._preview_waiting and a._detail_due < 0.0:
			return
	ok(false, "the row came to rest")

## The profile without the two fields the clock changes by itself.
func snap() -> String:
	var p: Dictionary = Game.profile.duplicate(true)
	p.erase("playtime")
	p.erase("last_played")
	return var_to_str(p)

func _ready() -> void:
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_armory_test"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	Game.slot = 1
	Game.new_game()
	for id in ["w_knight_sword", "w_ashen_great", "w_headsman", "w_twin_fangs", "w_monarch", "s_garrison", "s_tower", "a_ash_chest", "a_black_helm",
			"a_vigil_chest", "a_garrison_legs", "r_ember", "x_bell"]:
		Game.grant_item(id)
	Game.equip("a_ash_chest")
	Game.equip("s_tower")
	ok(Game.save(), "the journey is saved before browsing")
	var file := Game.slot_file(1)
	var bytes_before := FileAccess.get_file_as_bytes(file)
	var profile_before := snap()
	ok(bytes_before.size() > 0, "the save file exists (%d bytes)" % bytes_before.size())
	Engine.time_scale = 4.0
	var s := Sanctuary.new()
	add_child(s)
	await get_tree().process_frame
	s.show_tab("Armory")
	await get_tree().process_frame
	var a: ArmoryScreen = s.armory
	ok(a != null and a.carousel != null, "the armoury opens")
	ok(s.backdrop.rig is ArmoryRig, "the knight is the armoury's rig")
	ok((s.backdrop.rig as ArmoryRig).idle_clip != "", "the knight breathes in an authored idle (%s)" % (s.backdrop.rig as ArmoryRig).idle_clip)
	var equipped_look: Dictionary = s.backdrop.knight_look()
	# --- every slot, every item: go to it, let the preview land
	var seen := 0
	var locked := 0
	var visible_change := {}
	for slot: String in ArmoryScreen.RAIL:
		a.apply_preview(a.slot, "")      # back to what is equipped, so a change is counted against the slot that made it
		a._enter_slot(slot)
		await settle(a)
		for i in a.entries.size():
			var e: Dictionary = a.entries[i]
			a.carousel.go_to(i)
			await settle(a)
			seen += 1
			var id := str(e.id)
			if a.carousel.index != i:
				ok(false, "%s is in the middle after go_to" % id)
			if not Game.is_equipped(id) and a.previewing != id:
				ok(false, "%s is the preview" % id)
			if Game.is_equipped(id) and a.previewing != "":
				ok(false, "the equipped %s is not called a preview" % id)
			if s.backdrop.look_now != s.backdrop.knight_look(Game.trial_profile(id) if not Game.is_equipped(id) else {}):
				ok(false, "the knight wears the preview of %s" % id)
			if a.previewing == id and a.last_change != "":
				visible_change[slot] = true
			if e.locked:
				locked += 1
				if not a._equip.disabled:
					ok(false, "Equip is disabled for the locked %s" % id)
				a._do_equip()
				if Game.is_equipped(id) or Game.owns(id):
					ok(false, "a locked item cannot be equipped (%s)" % id)
	var expect := 0
	for it in Db.item_list:
		if ArmoryScreen.RAIL.has(str(it.slot)) and int(it.get("ng_min", 0)) <= 0:
			expect += 1
	ok(seen == expect, "every item of this journey was brought to the middle and previewed (%d of %d)" % [seen, expect])
	ok(locked > 10, "items not yet held are shown locked (%d)" % locked)
	ok(visible_change.has("weapon") and visible_change.has("shield") and visible_change.has("chest"), "weapon, shield and chest previews change the knight (%s)" % str(visible_change.keys()))
	ok(not visible_change.has("helm") and not visible_change.has("gauntlets") and not visible_change.has("legs") and not visible_change.has("ring") and not visible_change.has("relic"),
		"helm, gauntlets, greaves, ring and relic previews change nothing that is seen (and the screen says so)")
	# --- a finger: drag follows 1:1, the flick carries on, the row rests on an item
	a._enter_slot("weapon")
	await settle(a)
	var c := a.carousel
	var start := c.index
	var x0 := c.size.x * 0.5
	c.drag_begin(x0)
	c.drag_move(x0 - 20.0)
	var p0 := c.pos
	c.drag_move(x0 - 20.0 - c.spacing())
	ok(absf((c.pos - p0) - 1.0) < 0.001, "a drag of one item's width moves the row exactly one item")
	ok(c.moving, "the row is moving under the finger")
	for i in 6:
		await get_tree().process_frame
		c.drag_move(x0 - 20.0 - c.spacing() - 40.0 * (i + 1))
	c.drag_end(x0 - 20.0 - c.spacing() - 240.0)
	await settle(a)
	ok(c.index > start + 1 and is_equal_approx(c.pos, float(c.index)), "after a flick the row rests on an item further along (%d → %d)" % [start, c.index])
	c.drag_begin(x0 + c.spacing())
	c.drag_end(x0 + c.spacing())
	await settle(a)
	ok(c.index > start + 2 or c.index == a.entries.size() - 1, "a tap on a neighbour brings it to the middle")
	# --- actions that must not write anything
	for i in a.entries.size():
		if str(a.entries[i].id) == "w_knight_sword":
			c.go_to(i)
	await settle(a)
	a._compare.pressed.emit()
	ok(a.compare_on and a._stats.get_child_count() > 0, "compare shows the equipped figures beside these")
	a._compare.pressed.emit()
	var swing_row := false
	for r in Game.compare("w_ashen_great"):
		if str(r.key) == "swing_time":
			swing_row = int(r.better) < 0 and float(r.delta) > 0.0
	ok(swing_row, "a slower swing is marked worse although the number is larger")
	ok(a.preview_attack(), "Preview Attack plays a cut (%s)" % a.attack_clip("sword"))
	ok((s.backdrop.rig as ArmoryRig).acting(), "the knight is in the cut")
	for i in 900:
		await get_tree().process_frame
		if not (s.backdrop.rig as ArmoryRig).acting():
			break
	ok(not (s.backdrop.rig as ArmoryRig).acting(), "and returns to the idle")
	ok(a.attack_clip("greatsword").begins_with("th_") and a.attack_clip("dual").begins_with("dw_"), "each weapon class has its own cut (%s, %s)" % [a.attack_clip("greatsword"), a.attack_clip("dual")])
	a._enter_slot("shield")
	await settle(a)
	ok(a.preview_block(), "Preview Block raises the shield")
	a._open_inspect()
	await get_tree().process_frame
	ok(a.inspect != null and is_instance_valid(a.inspect), "Inspect opens")
	a.inspect.queue_free()
	a._show_grid(true)
	await get_tree().process_frame
	ok(a._grid != null, "the grid view opens")
	a._show_grid(false)
	ok(not a.play_recall("w_monarch") or ResourceLoader.exists("res://src/fx/recall.gd"), "the Recall hook falls back when the effect is not there")
	# --- leaving puts the equipped look back and nothing was written
	a._enter_slot("weapon")
	c.go_to(a.entries.size() - 1)
	await settle(a)
	s.show_tab("Journey")
	await get_tree().process_frame
	ok(s.backdrop.look_now == equipped_look and not (s.backdrop.rig is ArmoryRig), "leaving the armoury restores the equipped knight")
	ok(snap() == profile_before, "browsing and previewing left the profile untouched")
	ok(FileAccess.get_file_as_bytes(file) == bytes_before, "and the save file byte-identical")
	# --- Equip commits, and changes exactly one slot
	s.show_tab("Armory")
	await get_tree().process_frame
	a = s.armory
	a._enter_slot("weapon")
	for i in a.entries.size():
		if str(a.entries[i].id) == "w_knight_sword":
			a.carousel.go_to(i)
	await settle(a)
	var before: Dictionary = Game.profile.equipped.duplicate()
	var inv_before: Array = Game.profile.inventory.duplicate()
	a._do_equip()
	await get_tree().process_frame
	var changed: Array = []
	for k in before:
		if before[k] != Game.profile.equipped[k]:
			changed.append(k)
	ok(changed == ["weapon"] and Game.profile.equipped.weapon == "w_knight_sword", "Equip changed exactly one slot (%s)" % str(changed))
	ok(Game.profile.inventory == inv_before, "and nothing else in the pack")
	ok(s.armory == a and a.carousel.index < a.entries.size() and str(a.entries[a.carousel.index].id) == "w_knight_sword", "the row kept its place after Equip")
	ok(a.previewing == "" and s.backdrop.look_now == s.backdrop.knight_look(), "the knight now wears it as equipped")
	ok(FileAccess.get_file_as_bytes(file) != bytes_before, "and it was saved")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(file))
	ok(saved is Dictionary and str(saved.get("equipped", saved.get("profile", {}).get("equipped", {})).get("weapon", "")) == "w_knight_sword", "the saved journey has the new weapon")
	# --- Upgrade hands the item to the forge
	a._upgrade.pressed.emit()
	await get_tree().process_frame
	ok(s.tab == "Blacksmith" and s._smith_focus == "w_knight_sword" and s.armory == null, "Upgrade opens the forge on that item")
	s.queue_free()
	await get_tree().process_frame
	print("\narmory: %s" % ("PASS" if failed == 0 else "%d FAILED" % failed))
	get_tree().quit(1 if failed > 0 else 0)
