class_name PromptDemo
extends Node
## Dev (`--screen=prompts`): shows the swipe prompt line over the training duel, one direction every 1.5 s
## (R, UR, U, UL, L, DL, D, DR in parry gold), then an unblockable one (red, R) and a counter-cut seam (amber, UL).
## Capture at 2.6 + 1.5 * i seconds, i = 0..9.

const DIRS := ["R", "UR", "U", "UL", "L", "DL", "D", "DR"]
var _f := 0

func _process(_delta: float) -> void:
	_f += 1
	if _f < 60 or (_f - 60) % 45 != 0:
		return
	var i := (_f - 60) / 45
	var d: Duel = get_parent().current as Duel
	if d == null or d.hud == null or i > 9:
		return
	d.hud.cue.clear()
	d.hud.rift.show_dir("")
	if i < 8:
		d.hud.cue.show_cue("parry", DuelSim.dir_vec(DIRS[i]), "", false, 6.0)
	elif i == 8:
		d.hud.cue.show_cue("parry", DuelSim.dir_vec("R"), "", true, 6.0)
	else:
		d.hud.rift.show_dir("UL")
