extends Node
## Headless check of the screens over the progression layer:
##   godot --headless --path . res://tests/shop_forge.tscn
## The starting-sword picker hands its choice to new_game; browsing the shop and the forge writes nothing; Buy
## changes gold and ownership exactly; a locked or unaffordable piece cannot be bought; every sell guard is a
## disabled button with its reason; forge work changes weapon_mods, the duel's numbers and the model shown;
## the HUD follows the sim's shield_charges; the victory screen shows what was won.
var failed := 0

func ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		failed += 1

func frames(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame

## The profile without the two fields the clock changes by itself.
func snap() -> String:
	var p: Dictionary = Game.profile.duplicate(true)
	p.erase("playtime")
	p.erase("last_played")
	return var_to_str(p)

func texts(root: Node) -> String:
	var out: Array = []
	for n in root.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	for n in root.find_children("*", "Button", true, false):
		out.append((n as Button).text)
	return "\n".join(out)

## Lets a forge sequence play out: skips to its reveal and presses Continue.
func finish_forge(s: Sanctuary) -> void:
	for i in 600:
		await get_tree().process_frame
		for n in s.layer.get_children():
			if n is ForgeSeq:
				n._t = n.REVEAL_AT
				await frames(3)
				n._finish()
				await frames(3)
				return
	ok(false, "the forge sequence played")

func _ready() -> void:
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_shop_forge_test"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	Game.slot = 1
	Game.settings.reduce_motion = false
	var basic: Array = Db.equipment.basic_swords
	# ================================================================ the picker
	Game.new_game()
	var bd := Backdrop.new()
	add_child(bd)
	bd.build("sanctuary")
	var cs := CharacterSelect.new()
	add_child(cs)
	cs.setup(bd)
	await frames()
	var got := []
	cs.confirmed.connect(func(h: String, b: String, _who: String):
		got.append(CharacterSelect.start_weapon)
		Game.new_game(h, b, CharacterSelect.start_weapon))
	cs.step = 1
	cs._fill()
	await frames()
	ok(cs.carousel != null and cs.carousel.entries.size() == 4, "the picker offers the four basic swords")
	var real := true
	for id: String in basic:
		real = real and ItemModel.gear_id(Db.item(id)) != "" and not ItemModel.paths(Db.item(id), "m", {"blade_tier": 0, "grip_tier": 0}).is_empty()
	ok(real, "each is drawn from its hand-modelled gear")
	cs.carousel.go_to(2)
	for i in 400:
		await get_tree().process_frame
		if not cs.carousel.moving:
			break
	ok(cs.weapon == str(basic[2]), "the sword in the middle is the choice (%s)" % cs.weapon)
	var st: Dictionary = cs._stats_for(cs.weapon)
	ok(texts(cs).contains("%.1f" % float(st.attack)) and texts(cs).contains("%.2fs" % float(st.swing_time)), "its bars carry the duel's own damage and swing time")
	for b in cs.find_children("*", "Button", true, false):
		if (b as Button).text == "RISE":
			(b as Button).pressed.emit()
	ok(got == [str(basic[2])] and Game.profile.equipped.weapon == str(basic[2]) and Game.owns(str(basic[2])), "Rise passes it to new_game: the knight wakes holding %s" % Db.item(str(basic[2])).name)
	ok(not Game.owns(str(basic[0])) and not Game.owns(str(basic[1])) and Game.buy_price(str(basic[0])) > 0, "the others are not held, and are for sale")
	cs.leave()
	cs.queue_free()
	bd.queue_free()
	await frames()
	# ================================================================ the shop
	Game.new_game()
	Game.profile.gold = 1000
	Game.profile.cleared = ["courtyard"]
	Game.profile.defeated = {"ashen_sentinel": 1}
	Game.profile.flags["scene_orren_intro"] = true
	Game.profile.flags["orren_spoke"] = 99999
	Game.profile.flags["scene_sanctuary_return"] = true      # (the hub's own greeting marks itself heard; not browsing)
	Game.grant_item("w_knight_sword")
	Game.grant_item("r_ember")
	Game.toggle_favourite("r_ember")
	ok(Game.save(), "the journey is saved before browsing")
	var file := Game.slot_file(1)
	var bytes_before := FileAccess.get_file_as_bytes(file)
	var before := snap()
	var s := Sanctuary.new()
	add_child(s)
	await frames()
	s.show_tab("Shop")
	await frames()
	var sh: ShopScreen = s.screen
	ok(sh != null and sh.carousel != null and sh.carousel.entries.size() > 5, "the shop opens with its wares in a row (%d)" % (sh.carousel.entries.size() if sh else 0))
	var locked_id := ""
	var seen := 0
	for e in sh.catalogue():
		sh.select(str(e.id))
		await get_tree().process_frame
		seen += 1
		if sh.buy_btn == null or sh.buy_btn.disabled != (not e.available or int(e.price) > 1000):
			ok(false, "Buy is offered only for what can be bought (%s)" % str(e.id))
		if not e.available and locked_id == "":
			locked_id = str(e.id)
			ok(str(e.unlock_text) != "" and texts(sh).contains(str(e.unlock_text)) and texts(sh).contains("%d gold" % int(e.price)), "a locked piece shows its price and when it opens (%s: %s)" % [Db.item(locked_id).name, e.unlock_text])
	for m: String in ["Materials", "Sell", "Wares"]:
		sh.set_mode(m)
		await get_tree().process_frame
	sh.set_mode("Sell")
	for id: String in Game.sorted_items():
		sh.select(id)
		await get_tree().process_frame
	sh.set_mode("Wares")
	s.show_tab("Blacksmith")
	await frames()
	var fs: ForgeScreen = s.screen
	for id: String in fs.workable():
		fs.select(id)
		await get_tree().process_frame
	fs.mode = "Patterns"
	fs.refresh()
	s.show_tab("Shop")
	await frames()
	sh = s.screen
	ok(seen > 5 and snap() == before, "browsing every ware, the stall, the sell list and the forge left the profile untouched")
	ok(FileAccess.get_file_as_bytes(file) == bytes_before, "and the save file byte-identical")
	# --- locked and unaffordable
	ok(locked_id != "", "there is a locked goal on show")
	sh.select(locked_id)
	ok(sh.buy_btn.disabled and not sh.ask_buy(locked_id) and not sh.buy(locked_id) and not Game.owns(locked_id) and int(Game.profile.gold) == 1000, "a locked piece cannot be bought")
	Game.profile.gold = 100
	sh.refresh()
	sh.select("w_dawnline")
	ok(sh.buy_btn.disabled and sh.buy_btn.text == "NOT ENOUGH GOLD" and not sh.ask_buy("w_dawnline") and not Game.owns("w_dawnline"), "nor one the purse does not cover, and the button says why")
	# --- a plain purchase
	Game.profile.gold = 1000
	sh.refresh()
	sh.select("w_dawnline")
	var price := Game.buy_price("w_dawnline")
	ok(not sh.buy_btn.disabled and sh.buy_btn.text == "BUY", "an affordable piece offers Buy")
	sh.buy_btn.pressed.emit()
	await get_tree().process_frame
	ok(Game.owns("w_dawnline") and int(Game.profile.gold) == 1000 - price and not (sh.dialog and is_instance_valid(sh.dialog)), "Buy took exactly its price (%d) and the piece is held" % price)
	ok(sh.bought == "w_dawnline" and sh.buy_btn != null and sh.buy_btn.text == "EQUIP" and texts(sh).contains("INSPECT"), "the counter then offers Equip and Inspect")
	ok(absf(s._gold_shown - 1000.0) < absf(float(price)) and s._gold_tw != null, "the purse counts down instead of jumping")
	sh.buy_btn.pressed.emit()
	await get_tree().process_frame
	ok(Game.profile.equipped.weapon == "w_dawnline", "Equip puts it on")
	Game.equip("w_rusted_sword")
	for i in 200:
		await get_tree().process_frame
	ok(is_equal_approx(s._gold_shown, float(int(Game.profile.gold))) and s.purse.text.contains(str(int(Game.profile.gold))), "and comes to rest on the real figure (%s)" % s.purse.text)
	# --- an expensive one asks first
	var dear := ""
	for e in sh.catalogue():
		if dear == "" and e.available and int(e.price) >= ShopScreen.CONFIRM_FROM and str(e.id) != "w_ashen_great":
			dear = str(e.id)
	var dear_price := Game.buy_price(dear)
	Game.profile.gold = dear_price + 50
	sh.refresh()
	sh.select(dear)
	ok(dear_price >= ShopScreen.CONFIRM_FROM and sh.ask_buy(dear) and sh.dialog != null and is_instance_valid(sh.dialog) and not Game.owns(dear), "an expensive piece (%d) asks before it is bought" % dear_price)
	var dbtns := sh.dialog.find_children("*", "Button", true, false)
	(dbtns[0] as Button).pressed.emit()
	await frames()
	ok(not Game.owns(dear) and int(Game.profile.gold) == dear_price + 50, "Cancel spends nothing")
	sh.ask_buy(dear)
	(sh.dialog.find_children("*", "Button", true, false)[1] as Button).pressed.emit()
	await frames()
	ok(Game.owns(dear) and int(Game.profile.gold) == 50, "confirming takes exactly its price")
	# --- the stall
	Game.profile.gold = 500
	var shards := int(Game.profile.shards)
	sh.set_mode("Materials")
	await get_tree().process_frame
	ok(sh._buttons.has("shards×1") and sh._buttons.has("m_iron×5") and not sh._buttons.has("m_core×1") and not sh._buttons.has("m_glass×1"), "the stall sells shards and the ore of a cleared land, never a core or an unreached ore")
	(sh._buttons["shards×1"] as Button).pressed.emit()
	await get_tree().process_frame
	ok(int(Game.profile.shards) == shards + 1 and int(Game.profile.gold) == 500 - Game.material_price("shards"), "one shard costs exactly its price")
	# --- selling: every guard is a disabled button with its reason
	sh.set_mode("Sell")
	await get_tree().process_frame
	var guards := {"w_rusted_sword": "EQUIPPED", "r_ember": "FAVOURITE"}
	for id: String in guards:
		sh.select(id)
		ok(sh.sell_btn.disabled and sh.sell_btn.text == guards[id] and Game.sell_block(id) != "", "%s cannot be sold: %s" % [Db.item(id).name, sh.sell_btn.text])
	Game.equip("w_dawnline")
	await frames()
	sh.select("w_rusted_sword")
	ok(sh.sell_btn.disabled and sh.sell_btn.text == "NOT FOR SALE", "the blade the knight woke with stays")
	sh.select("w_knight_sword")
	var gold0 := int(Game.profile.gold)
	var worth := Game.sell_price("w_knight_sword")
	ok(not sh.sell_btn.disabled and sh.sell_btn.text == "SELL", "a spare blade can be sold")
	sh.sell_btn.pressed.emit()
	ok(Game.owns("w_knight_sword") and sh.dialog != null and is_instance_valid(sh.dialog), "selling asks first")
	(sh.dialog.find_children("*", "Button", true, false)[1] as Button).pressed.emit()
	await frames()
	ok(not Game.owns("w_knight_sword") and int(Game.profile.gold) == gold0 + worth, "and pays exactly its worth (%d)" % worth)
	Game.equip("w_rusted_sword")
	# ================================================================ the forge
	Game.profile.gold = 3000
	Game.profile.shards = 40
	Game.profile.materials["m_silver"] = 6
	var wid := "w_rusted_sword"
	s.open_forge(wid)
	await frames()
	fs = s.screen
	ok(s.tab == "Blacksmith" and fs != null and fs.sel == wid, "open_forge(item) opens the forge on that item")
	ok(fs.track_btn.has("blade") and fs.track_btn.has("grip") and fs.track_btn.has("ore") and fs.track_btn.has("sharpen"), "a weapon shows its four tracks")
	var page := texts(fs)
	var c0: Dictionary = Game.mod_cost(wid, "blade")
	ok(page.contains("%d gold" % int(c0.gold)) and page.contains("%.1f → " % float(Game.stats().attack)), "with the next step's cost and its effect on the duel's numbers")
	var sig0 := ItemModel.sig(Db.item(wid))
	var path0: Array = ItemModel.paths(Db.item(wid))
	for track: String in ["blade", "grip", "ore", "sharpen"]:
		var w0: Dictionary = Game.weapon_mods(wid)
		var st0: Dictionary = Game.stats()
		var cost: Dictionary = Game.mod_cost(wid, track)
		var g0 := int(Game.profile.gold)
		ok(not (fs.track_btn[track] as Button).disabled, "%s can be worked" % track)
		(fs.track_btn[track] as Button).pressed.emit()
		await finish_forge(s)
		fs = s.screen
		var w1: Dictionary = Game.weapon_mods(wid)
		var st1: Dictionary = Game.stats()
		var moved: bool = {"blade": int(w1.blade) == int(w0.blade) + 1 and float(st1.attack) > float(st0.attack),
			"grip": int(w1.grip) == int(w0.grip) + 1 and float(st1.swing_time) < float(st0.swing_time) and float(st1.swing_cost) < float(st0.swing_cost),
			"ore": int(w1.ore) == int(w0.ore) + 1 and float(st1.attack) > float(st0.attack),
			"sharpen": int(w1.edge) == int(Db.equipment.mods.sharpen.fights) and float(st1.attack) > float(st0.attack)}[track]
		ok(moved and int(Game.profile.gold) == g0 - int(cost.gold), "%s: weapon_mods and the duel's numbers moved, for exactly %d gold" % [track, int(cost.gold)])
	var sig1 := ItemModel.sig(Db.item(wid))
	ok(sig1 != sig0 and ItemModel.paths(Db.item(wid)) != path0 and ItemModel.gear_mod(Db.item(wid)).keen, "the model follows: new blade and grip parts, steel, a polished edge (%s → %s)" % [sig0, sig1])
	ok(fs.stage._built.contains(sig1), "and the sword on the bench is rebuilt in that state")
	ok((fs.track_btn["sharpen"] as Button).disabled and (fs.track_btn["sharpen"] as Button).text == "STILL KEEN" and texts(fs).contains("3 fights left"), "Sharpen shows the fights left and cannot be stacked")
	# the second ore tier: a choice of metal, costed in that metal
	ok(int(Game.weapon_mods(wid).ore) == 1 and fs._ore_default(Db.item(wid)) == "m_silver", "the ore picker starts on a metal that is held")
	fs.ore_pick = "m_glass"
	fs.refresh()
	ok((fs.track_btn["ore"] as Button).disabled and texts(fs).contains("Hollow Glass (have 0)"), "an ore not held blocks the step and the cost says what is missing")
	fs.ore_pick = "m_silver"
	fs.refresh()
	var attack_before := float(Game.stats().crit_mult)
	(fs.track_btn["ore"] as Button).pressed.emit()
	await finish_forge(s)
	fs = s.screen
	ok(str(Game.weapon_mods(wid).ore_id) == "m_silver" and Game.material_count("m_silver") == 2 and float(Game.stats().crit_mult) > attack_before, "reforging in Grave Silver spends four of it and marks the blade")
	# blocked for want of gold
	Game.profile.gold = 0
	fs.refresh()
	ok((fs.track_btn["blade"] as Button).disabled and (fs.track_btn["blade"] as Button).text == "NOT ENOUGH GOLD", "without gold the button says so")
	var res = s.forge_work(wid, "blade")
	ok(res is bool and res == false and int(Game.weapon_mods(wid).blade) == 1, "and no work is done")
	# a shield: one level, and its cost shows the material it takes
	Game.profile.gold = 3000
	Game.grant_item("s_tower")
	Game.profile.upgrades["s_tower"] = 2
	fs.select("s_tower")
	await get_tree().process_frame
	var sc: Dictionary = Game.upgrade_cost("s_tower")
	ok(not sc.materials.is_empty() and fs.track_btn.has("") and texts(fs).contains("%d %s" % [int(sc.materials.values()[0]), Db.material_name(str(sc.materials.keys()[0]))]),
		"a shield's level shows the material it is charged (%s)" % str(sc.materials))
	Game.add_material(str(sc.materials.keys()[0]), 3)
	fs.refresh()
	(fs.track_btn[""] as Button).pressed.emit()
	await finish_forge(s)
	ok(Game.upgrade_level("s_tower") == 3, "and Temper raises it")
	s.queue_free()
	await frames()
	# ================================================================ the duel HUD
	var hud := DuelHud.new()
	add_child(hud)
	await frames()
	ok(hud.keen_mark.visible, "the HUD marks a keen edge while it lasts")
	hud.shield_charges({"left": 3, "max": 3})
	ok(hud.pad_block.pips == 3 and hud.pad_block.pips_left == 3, "shield_charges sets the pips by the shield pad")
	hud.shield_charges({"left": 2, "max": 3, "spent": false})
	ok(hud.pad_block.pips_left == 2 and hud.pad_block.notice > 0.0 and hud.toast_label.text != "SHIELD SPENT", "a block caught takes one and lights the pad")
	hud.shield_charges({"left": 1, "max": 3, "spent": false})
	hud.shield_charges({"left": 0, "max": 3, "spent": false})
	ok(hud.pad_block.pips_left == 0 and hud.toast_label.text == "SHIELD SPENT", "the last one gone says SHIELD SPENT")
	hud.toast_label.text = ""
	hud.shield_charges({"left": 0, "max": 3, "spent": true})
	ok(hud.toast_label.text == "" and hud.pad_block._hit_t == 0.0, "a blow on a spent shield shakes the pad without saying it again")
	hud.shield_charges({"left": 1, "max": 3})
	ok(hud.pad_block.pips_left == 1 and hud.pad_block._pip_gain, "a block coming back is animated in")
	hud.queue_free()
	Game.profile.edge.clear()
	var hud2 := DuelHud.new()
	add_child(hud2)
	await frames()
	ok(not hud2.keen_mark.visible, "no mark without a keen edge")
	hud2.queue_free()
	# the real path: the sim's event reaches the HUD through Duel._on_ev
	Game.equip("s_tower")
	Game.start_run("courtyard")
	var d := Duel.new()
	add_child(d)
	d.setup("ashen_sentinel", {"skip_intro": true})
	await frames()
	d.hud.update_bars(d.sim, 0.016)
	ok(d.sim.p_shield_max > 0 and d.hud.pad_block.pips == d.sim.p_shield_max and d.hud.pad_block.pips_left == d.sim.p_shield_max, "a duel opens with the shield's blocks shown (%d)" % d.sim.p_shield_max)
	d.sim.ev.emit(&"shield_charges", {"left": 1, "max": d.sim.p_shield_max, "spent": false})
	ok(d.hud.pad_block.pips_left == 1, "the sim's shield_charges event drives the pips")
	# ================================================================ the victory screen
	Game.profile.gold = 200
	Game.profile.defeated.erase("ashen_sentinel")       # its first fall: the guaranteed piece, and a blade opens in the shop
	var r: Dictionary = Game.on_victory("ashen_sentinel", 50.0)
	var went := [false]
	Overlays.victory(d, Db.foes.ashen_sentinel, r, d.sim, func(): went[0] = true)
	await frames()
	var ov: CanvasLayer = null
	for n in d.get_children():
		if n is CanvasLayer and n.has_meta("tweens"):
			ov = n
	var vt := texts(ov)
	ok(ov != null and vt.contains("GOLD WON") and vt.contains("MASTERY") and vt.contains("YOUR PURSE"), "the victory screen has its three columns")
	var mats_ok := true
	for m: String in r.materials:
		mats_ok = mats_ok and vt.contains("%d  %s" % [int(r.materials[m]), Db.material_name(m)])
	ok(not r.materials.is_empty() and mats_ok, "what was salvaged is shown (%s)" % str(r.materials))
	var shop_ok: bool = not r.shop_unlocks.is_empty()
	for id in r.shop_unlocks:
		shop_ok = shop_ok and vt.contains("New in the shop:  %s" % Db.item(id).name)
	ok(shop_ok, "and what Orren can now sell (%s)" % str(r.shop_unlocks))
	ok(not r.items_new.is_empty() and vt.contains(str(Db.item(str(r.items_new[0])).name).to_upper()) and vt.contains("COMPARE") and vt.contains("INSPECT"), "a new piece is revealed with Compare and Inspect (%s)" % str(r.items_new))
	ok(vt.contains(str(Db.item("w_rusted_sword").name)) and vt.contains(str(Db.item("s_tower").name)), "everything worn has its mastery bar")
	for tw: Tween in ov.get_meta("tweens"):
		if tw.is_valid():
			tw.custom_step(60.0)
	await frames()
	vt = texts(ov)
	ok(vt.contains("+%d" % int(r.gold)) and vt.contains("%d" % int(Game.profile.gold)), "a tap finishes the count: +%d into a purse of %d" % [int(r.gold), int(Game.profile.gold)])
	for b in ov.find_children("*", "Button", true, false):
		if (b as Button).text == "CONTINUE":
			(b as Button).pressed.emit()
	ok(went[0], "Continue moves on")
	d.queue_free()
	await frames()
	print("\nshop_forge: %s" % ("PASS" if failed == 0 else "%d FAILED" % failed))
	get_tree().quit(1 if failed > 0 else 0)
