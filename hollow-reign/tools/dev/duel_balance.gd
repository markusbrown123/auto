extends Node
## Dev: bot-vs-foe balance table through the real rules.  godot --headless --path . res://tools/dev/duel_balance.tscn -- [--foes=a,b] [--n=20]
func _ready() -> void:
	var foes := ["hollow_soldier", "banneret", "pike_sergeant", "rampart_brute", "gate_colossus", "ashen_sentinel"]
	var n := 20
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--foes="):
			foes = Array(arg.trim_prefix("--foes=").split(","))
		if arg.begins_with("--n="):
			n = int(arg.trim_prefix("--n="))
	var st: Dictionary = Stats.compute(Game.default_profile(), Db.items, Db.classes)
	print("player: hp %.0f sta %.0f regen %.1f atk %.1f swing %.2f cost %.1f block_eff %.2f shield %d/%.1fs" % [st.max_hp, st.max_stamina, st.stamina_regen, st.attack, st.swing_time, st.swing_cost, st.block_eff, st.shield_blocks, st.shield_regen])
	print("%-16s %-8s %5s %7s %6s %6s %6s %6s %6s" % ["foe", "bot", "win%", "time", "hp%", "cuts", "cut/s", "blocks", "gbrk"])
	for foe: String in foes:
		for style: int in [DuelBot.Style.SKILLED, DuelBot.Style.SLOPPY, DuelBot.Style.TURTLE, DuelBot.Style.SPAM]:
			var wins := 0
			var time := 0.0
			var hp := 0.0
			var cuts := 0.0
			var blocks := 0.0
			var gb := 0.0
			for i: int in n:
				var s := DuelSim.new()
				s.setup(st, Db.foes[foe], 1000 + i * 7, {"combos": Db.combos})
				var bot := DuelBot.new(s, style, 50 + i)
				var k := 0
				while not s.over and k < 60 * 600:
					bot.tick(1.0 / 60.0)
					s.tick(1.0 / 60.0)
					k += 1
				if s.b_state == DuelSim.B.DEAD:
					wins += 1
					time += s.time
					hp += s.pl.hp / s.pl.max_hp
				cuts += s.cuts_landed
				blocks += s.stats.blocks
				gb += float(s.stats.get("guard_breaks", 0))
			print("%-16s %-8s %5.0f %7.1f %6.0f %6.1f %6.2f %6.1f %6.1f" % [foe, ["skilled", "spam", "turtle", "sloppy"][style], 100.0 * wins / n, time / maxf(1, wins), 100.0 * hp / maxf(1, wins), cuts / n, 0.0, blocks / n, gb / n])
	get_tree().quit()
