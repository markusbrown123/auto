class_name SliceBot
extends Node
## Dev: an automated first-time player for the first-boss slice (`-- --screen=slice`). It starts at the launch
## screen and plays to the Ashen Sentinel's fall through the real screens: every button is pressed by a synthetic
## touch at its centre (through `Input`, the path a finger takes), every cut, parry, dodge and block in a fight is a
## touch on the duel's own surface. Nothing is skipped unless asked. Every step is logged with the game's clock.
##
##   --body=m|f        who wakes                       --weapon=<id>     one of Db.equipment.basic_swords
##   --die=1,boss      lose the first ordinary fight and/or the Sentinel once, then set out again
##   --fast            press SKIP on every story beat (the duels on the road are still fought)
##   --until=<step>    stop after: menu | arrival | quit (back at the main menu after the sanctuary visit)
##   --forge_first     visit the forge before the shop (the purse reaches one piece of work or one purchase, not both)
##   --road=<stop>     skip the story: a new second-generation knight on the Courtyard's road at that stop (0 to 6), for the
##                     death screen and the checkpoint (with --die=1 for the first fight, --die=boss for the Sentinel)
##   --until=retry     (with --road) stop a few seconds after the road is taken up again from the checkpoint
##   --resume          a second launch: Continue from the save the last run left (checks that it persisted), then
##                     the rest of the road and the guardian
##   --log=<file>      where the step log goes (default: <save dir>/slice.log)
##   --snaps=<dir>     save a frame every --snap_every seconds (default 4) of game time
##   --audit           list small touch targets, small text and controls outside the safe area for each screen
##
## A tap that does not reach its button (something lies over it) is logged as TAP MISSED and the button's handler is
## called so the run can go on. A step that does not come within its time is logged as STUCK with what is on screen.

const TAP_MIN := 60.0          # smallest side of a touch target, in reference (720-high) units
const TEXT_MIN := 22           # smallest text, same units

var main: Node
var args := {}
var gt := 0.0                  # the game's clock, seconds
var _wall0 := 0
var _log: FileAccess
var _step := ""
var _snap_dir := ""
var _snap_next := 0.0
var _snap_n := 0
var _audit := {}               # "screen | what" -> true
var _missed := 0
var _stuck := 0
var _peaks := {}               # bus name -> [peak db, sum of linear peaks, frames]
var _black := 0.0              # seconds the fader has been fully dark
var _black_max := 0.0

# ---- the fight in hand
var _duel_id := 0
var _plan := {}
var _next_cut := 0.0
var _alt := 0
var _busy := false             # a stroke is being drawn
var _block_down := false
var _die_now := false
var _seq_i := 0
var _tap_t := 0.0
var fights := 0
var deaths := 0
var _die := []
var _assist := false           # after too many unplanned deaths the sim's own bot takes over, and the log says so
const CUTS := ["L", "R", "D", "UL", "DR", "U"]
const VEC := {"R": Vector2(1, 0), "UR": Vector2(1, -1), "U": Vector2(0, -1), "UL": Vector2(-1, -1), "L": Vector2(-1, 0), "DL": Vector2(-1, 1), "D": Vector2(0, 1), "DR": Vector2(1, 1)}

func _init(m: Node, a: Dictionary) -> void:
	main = m
	args = a
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_wall0 = Time.get_ticks_msec()
	var path: String = str(args.get("log", Game.save_dir_override + "/slice.log"))
	_log = FileAccess.open(path, FileAccess.READ_WRITE if args.has("resume") and FileAccess.file_exists(path) else FileAccess.WRITE)
	if _log:
		_log.seek_end()
	_snap_dir = str(args.get("snaps", ""))
	if _snap_dir != "":
		DirAccess.make_dir_recursive_absolute(_snap_dir)
	_die = Array(str(args.get("die", "")).split(",", false))
	_run()

func say(text: String) -> void:
	var line := "[%7.1fs game | %6.0fs wall] %s" % [gt, (Time.get_ticks_msec() - _wall0) / 1000.0, text]
	print(line)
	if _log:
		_log.store_line(line)
		_log.flush()

func step(s: String) -> void:
	_meter_report()
	_step = s
	say("STEP " + s)

# ================================================================ clock, frames, audio levels
func _process(delta: float) -> void:
	gt += delta
	if _snap_dir != "" and gt >= _snap_next:
		_snap_next = gt + float(args.get("snap_every", "4"))
		_snap("")
	for i in AudioServer.bus_count:
		var n := AudioServer.get_bus_name(i)
		var db := maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0))
		if not _peaks.has(n):
			_peaks[n] = [-200.0, 0.0, 0]
		_peaks[n][0] = maxf(_peaks[n][0], db)
		_peaks[n][1] += db_to_linear(db)
		_peaks[n][2] += 1
	var f: ColorRect = main._fader
	if f.color.a > 0.98:
		_black += delta
		_black_max = maxf(_black_max, _black)
	else:
		if _black > 3.0:
			say("  HELD FRAME %.1f s behind the fader (%s)" % [_black, _step])
		_black = 0.0
	_fight(delta)

func _meter_report() -> void:
	if _peaks.is_empty() or _step == "":
		return
	var bits: Array = []
	for n: String in _peaks:
		var p: Array = _peaks[n]
		if int(p[2]) > 0:
			bits.append("%s peak %.1f mean %.1f dB" % [n, float(p[0]), linear_to_db(maxf(float(p[1]) / float(p[2]), 0.00001))])
	say("  audio during '%s': %s" % [_step, "; ".join(bits)])
	_peaks.clear()

func _snap(tag: String) -> void:
	if _snap_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(640, int(640.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
	_snap_n += 1
	img.save_jpg("%s/%04d_%05.0f%s.jpg" % [_snap_dir, _snap_n, gt, ("_" + tag) if tag != "" else ""], 0.8)

func _wait(sec: float) -> void:
	var to := gt + sec
	while gt < to:
		await get_tree().process_frame

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Waits for `cond`; logs STUCK (with what is on screen) if it does not come in `timeout` game seconds.
func _until(cond: Callable, timeout: float, what: String) -> bool:
	var to := gt + timeout
	while gt < to:
		if cond.call():
			return true
		await get_tree().process_frame
	_stuck += 1
	say("STUCK waiting for %s after %.0f s (screen %s). On screen: %s" % [what, timeout, _screen(), ", ".join(_texts())])
	_snap("stuck")
	return false

func _screen() -> String:
	var c: Node = main.current
	if c == null or not is_instance_valid(c):
		return "none"
	var s: Script = c.get_script()
	return s.get_global_name() if s else c.get_class()

# ================================================================ touches
func _win(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _win(pos)
	e.pressed = pressed
	Input.parse_input_event(e)

func _drag(index: int, pos: Vector2, rel: Vector2 = Vector2.ZERO) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = _win(pos)
	e.relative = rel
	Input.parse_input_event(e)

func _tap_at(pos: Vector2, index: int = 3) -> void:
	_touch(index, pos, true)
	await _frames(2)
	_touch(index, pos, false)
	await _frames(1)

func _shown(c: Control) -> bool:
	if not is_instance_valid(c) or not c.is_visible_in_tree():
		return false
	var n: Node = c
	var a := 1.0
	while n != null:
		if n is CanvasItem:
			a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	return a > 0.3

func _buttons() -> Array:
	var out: Array = []
	for b: Button in main.find_children("*", "Button", true, false):
		if _shown(b) and not b.disabled:
			out.append(b)
	return out

func _label_of(b: Button) -> String:
	if b.text != "":
		return b.text
	for l in b.find_children("*", "Label", true, false):
		if (l as Label).text != "" and (l as Label).get_theme_font_size("font_size") >= 18:
			return (l as Label).text
	return b.tooltip_text

func _texts() -> Array:
	var out: Array = []
	for b: Button in _buttons():
		var t := _label_of(b)
		if t != "":
			out.append("[" + t + "]")
	return out

func _find(text: String, part: bool = false) -> Button:
	var best: Button = null
	for b: Button in _buttons():
		var t := _label_of(b)
		if t.nocasecmp_to(text) == 0 or (part and t.containsn(text)):
			best = b            # the last one found is the one drawn on top
	return best

## Taps a control as a finger would. Returns false (and says so) if the touch did not arrive.
func tap(b: Control, what: String = "") -> bool:
	if not is_instance_valid(b):
		say("  TAP FAILED: %s is gone" % what)
		return false
	if what == "" and b is Button:
		what = _label_of(b)
	var sc := b.get_parent()
	while sc != null and not sc is ScrollContainer:
		sc = sc.get_parent()
	if sc is ScrollContainer and not (sc as ScrollContainer).get_global_rect().encloses(b.get_global_rect()):
		(sc as ScrollContainer).ensure_control_visible(b)
		say("  (scrolled to reach '%s')" % what)
		await _frames(2)
	var hit := [false]
	var cb := func(): hit[0] = true
	if b is BaseButton:
		(b as BaseButton).pressed.connect(cb)
	var at := b.get_global_rect().get_center()
	var r := b.get_global_rect()
	say("  tap '%s' at (%d, %d), target %d x %d" % [what, at.x, at.y, r.size.x, r.size.y])
	_touch(3, at, true)
	await _frames(2)
	_touch(3, at, false)
	await _frames(2)
	if is_instance_valid(b) and not b is BaseButton:
		return true
	if is_instance_valid(b) and (b as BaseButton).pressed.is_connected(cb):
		(b as BaseButton).pressed.disconnect(cb)
	if not hit[0]:
		_missed += 1
		var over := get_viewport().gui_get_hovered_control()
		say("  TAP MISSED: '%s' did not receive the touch (under: %s). Calling its handler." % [what, str(over.get_path()) if over else "nothing"])
		if is_instance_valid(b):
			(b as BaseButton).pressed.emit()
		return false
	return true

func press(text: String, timeout: float = 20.0, part: bool = false) -> bool:
	if not await _until(func(): return _find(text, part) != null, timeout, "button '%s'" % text):
		return false
	await _wait(0.4)                 # a person reads before pressing
	var b := _find(text, part)
	if b == null:
		return false
	await tap(b)
	return true

# ================================================================ layout audit
func audit(tag: String = "") -> void:
	if not args.has("audit"):
		return
	var scr := _screen() + ((":" + tag) if tag != "" else "")
	var view := get_viewport().get_visible_rect()
	var s := UI.safe_margins(get_viewport())
	var safe := Rect2(view.position + Vector2(float(s.l) - 8.0, float(s.t) - 8.0), view.size - Vector2(float(s.l) + float(s.r) - 16.0, float(s.t) + float(s.b) - 16.0))
	for b: Button in _buttons():
		var r := b.get_global_rect()
		var t := _label_of(b)
		if minf(r.size.x, r.size.y) < TAP_MIN - 0.5:
			_note("%s | small target %d x %d: [%s]" % [scr, r.size.x, r.size.y, t])
		if not view.grow(1.0).encloses(r):
			_note("%s | off screen: [%s] at %s" % [scr, t, str(r)])
		elif not safe.grow(1.0).encloses(r):
			_note("%s | outside the safe area: [%s] at %s" % [scr, t, str(r)])
	for l: Label in main.find_children("*", "Label", true, false):
		if not _shown(l) or l.text.strip_edges() == "":
			continue
		var px := l.get_theme_font_size("font_size")
		var r2 := l.get_global_rect()
		if px < TEXT_MIN:
			_note("%s | small text %d px: \"%s\"" % [scr, px, l.text.left(40).replace("\n", " ")])
		if not view.grow(2.0).encloses(r2) and r2.size.x < view.size.x:
			_note("%s | text off screen: \"%s\" at %s" % [scr, l.text.left(40).replace("\n", " "), str(r2)])
		elif l.clip_text == false and l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.get_minimum_size().x > r2.size.x + 2.0:
			_note("%s | text wider than its box: \"%s\"" % [scr, l.text.left(40)])

func _note(s: String) -> void:
	if not _audit.has(s):
		_audit[s] = true
		say("  AUDIT " + s)

# ================================================================ the fight, by touch
func duel() -> Duel:
	var c: Node = main.current
	if c == null or not is_instance_valid(c):
		return null
	if c is Duel:
		return c
	var d = c.get("duel")
	if d != null and is_instance_valid(d) and d is Duel:
		return d
	return null

func _centre() -> Vector2:
	return get_viewport().get_visible_rect().size * Vector2(0.5, 0.45)

## One stroke across the foe: down, across in two moves, up. About a tenth of a second, as a quick finger is.
func swipe(dir: String) -> void:
	if _busy:
		return
	_busy = true
	var v: Vector2 = (VEC[dir] as Vector2).normalized() * 230.0
	var a := _centre() - v * 0.5
	_touch(0, a, true)
	await get_tree().process_frame
	_drag(0, a + v * 0.5, v * 0.5)
	await get_tree().process_frame
	_drag(0, a + v, v * 0.5)
	await get_tree().process_frame
	_touch(0, a + v, false)
	_busy = false

func _pad_tap(p: Control, index: int = 2) -> void:
	var at := p.get_global_rect().get_center()
	_touch(index, at, true)
	await _frames(2)
	_touch(index, at, false)

func _hold_block(d: Duel, down: bool) -> void:
	if down == _block_down:
		return
	_block_down = down
	_touch(1, d.hud.pad_block.get_global_rect().get_center(), down)

func _on_ev(n: StringName, e: Dictionary, d: Duel) -> void:
	if n == &"struggle_start":
		_tap_t = 0.3
		_plan = {}
		return
	if n != &"boss_telegraph":
		return
	var a: Dictionary = e.attack
	var impact: float = d.sim.time + float(e.windup)
	var kind := d._lesson_kind() if d._lesson >= 0 else ""
	if kind == "block" or (kind == "" and not a.parry and str(a.dodge) == "none"):
		_plan = {"kind": "block", "at": impact - 0.35}
	elif kind == "dodge" or kind == "roll" or (kind == "" and not a.parry):
		_plan = {"kind": kind if kind != "" else "dodge", "side": 1 if str(a.dodge) == "R" else -1, "at": impact - 0.2}
	else:
		_plan = {"kind": "parry", "dir": DuelSim.parry_dir_for(a.dir), "at": impact - 0.2}

func _fight(delta: float) -> void:
	var d := duel()
	if d == null or get_tree().paused:
		return
	if d.get_instance_id() != _duel_id:
		_duel_id = d.get_instance_id()
		_plan = {}
		_block_down = false
		_seq_i = 0
		_next_cut = 0.0
		d.sim.ev.connect(func(n: StringName, e: Dictionary): _on_ev(n, e, d))
		say("  duel begins: %s%s (knight %d hp)" % [str(d.foe.get("name", "?")), "  [the lesson]" if d._lesson >= 0 or d.sim.lesson else "", int(d.sim.pl.hp)])
		if _assist and d.bot == null and not d.sim.lesson:
			d.bot = DuelBot.new(d.sim, DuelBot.Style.SKILLED, 3)
			say("  (assist: the sim's own bot fights this one)")
	if d.stage != Duel.Stage.FIGHT or d.sim.over or d.sim.paused or d.bot != null:
		if _block_down:
			_hold_block(d, false)
		return
	var sim := d.sim
	if _die_now:
		return                        # stands and takes it
	if sim.b_state == DuelSim.B.STRUGGLE:
		_tap_t -= delta
		if _tap_t <= 0.0:
			_tap_t = 0.11
			_touch(4, _centre() + Vector2(0, 60), true)
			_touch(4, _centre() + Vector2(0, 60), false)
		return
	var kind := d._lesson_kind() if d._lesson >= 0 else ""
	# the meters, as a player would spend them
	if kind == "" and sim.surge >= DuelSim.SURGE_MAX and sim.b_state == DuelSim.B.IDLE and sim.p_state == DuelSim.P.FREE and not _busy:
		_pad_tap(d.hud.pad_surge)
	if kind == "" and sim.relic >= DuelSim.RELIC_MAX and sim.pl.hp < sim.pl.max_hp * 0.55:
		_pad_tap(d.hud.pad_relic)
	var want_block := false
	if not _plan.is_empty():
		if _plan.kind == "block":
			want_block = sim.time >= float(_plan.at) and sim.b_state == DuelSim.B.WINDUP
			if sim.b_state != DuelSim.B.WINDUP:
				_plan = {}
		elif sim.time >= float(_plan.at):
			var p := _plan
			_plan = {}
			if p.kind == "parry":
				swipe(str(p.dir))
			else:
				var pad: Control = d.hud.pad_r if int(p.side) > 0 else d.hud.pad_l
				_pad_tap(pad)
				if p.kind == "roll":
					get_tree().create_timer(0.16).timeout.connect(func(): _pad_tap(pad, 5))
	_hold_block(d, want_block)
	# free cutting: in an opening the next stroke is drawn while the last cut is still recovering, so it is queued and
	# fires on the cancel frame (the lesson's steps keep their own unhurried pace)
	var queue_ok: bool = d._lesson < 0 and sim.boss_open() and sim.p_state == DuelSim.P.SWING and sim.p_swing.get("landed", false) and sim.p_buffer.is_empty()
	if _busy or (sim.p_state != DuelSim.P.FREE and not queue_ok) or sim.time < _next_cut:
		return
	if d._lesson >= 0:
		if d._lesson_strike:
			swipe("R")
			_next_cut = sim.time + 0.5
		elif kind == "cuts":
			swipe("R" if _alt % 2 == 0 else "L")
			_alt += 1
			_next_cut = sim.time + 0.7
		elif kind.begins_with("combo:"):
			var seq: Array = d._lesson_demo(d._lesson)[0]
			swipe(str(seq[_seq_i % seq.size()]))
			_seq_i += 1
			_next_cut = sim.time + (0.55 if _seq_i % seq.size() != 0 else 1.6)
		elif kind == "stamina" and not d._lesson_low:
			swipe("L" if _alt % 2 == 0 else "R")
			_alt += 1
			_next_cut = sim.time + 0.45
		return
	_seq_i = 0
	if sim.boss_open() and sim.pl.stamina > sim.pl.swing_cost:
		_alt = (_alt + 1) % CUTS.size()
		var cut: String = CUTS[_alt]
		if sim.rift_dir != "":
			cut = sim.rift_dir
		elif cut == sim.p_last_dir:
			cut = CUTS[(_alt + 1) % CUTS.size()]
		swipe(cut)
		_next_cut = sim.time + 0.06

# ================================================================ the slice
func _run() -> void:
	await _frames(3)
	if not args.has("resume"):
		for n in range(1, Game.SLOT_COUNT + 1):
			if not args.has("keep"):
				Game.delete_slot(n)
		for f: String in [Opening.SEEN_FILE, Launch.SEEN_FILE]:
			if not args.has("keep") and FileAccess.file_exists(Game._p(f)):
				DirAccess.remove_absolute(Game._p(f))
	Game.profile = {}
	Game.run = {}
	if args.has("road"):
		await _from_road(int(args.road))
		await _end()
		return
	say("slice run: body=%s weapon=%s die=%s window=%s safe margins=%s preset=%s" % [args.get("body", "m"), args.get("weapon", "default"), str(_die),
		str(DisplayServer.window_get_size()), str(UI.safe_margins(get_viewport())), str(Game.graphics().name)])
	step("launch")
	var t0 := gt
	main.show_launch()
	await _wait(0.6)
	audit()
	await _until(func(): return main.current is TitleScreen, 12.0, "the main menu")
	say("  launch screen took %.1f s" % (gt - t0))
	step("main menu")
	await _wait(1.6)
	audit()
	if args.has("resume"):
		await _resume()
		await _end()
		return
	await press("New Legacy")
	await _wait(0.8)
	if _find("Begin here") != null:
		step("save slot")
		audit()
		await press("Begin here")
	step("character select")
	await _until(func(): return _find("Choose a Blade") != null, 10.0, "character select")
	audit("body")
	if str(args.get("body", "m")) == "f":
		await press("The Blade")
		await _wait(1.5)
	var cs: CharacterSelect = (main.current as TitleScreen)._panel
	# the name: tap the field, type
	await tap(cs._name, "name field")
	for ch: String in ("Maren" if str(args.get("body", "m")) == "m" else "Ysolde"):
		var k := InputEventKey.new()
		k.unicode = ch.unicode_at(0)
		k.keycode = OS.find_keycode_from_string(ch.to_upper())
		k.pressed = true
		Input.parse_input_event(k)
		await _frames(2)
	if cs._typed == "":
		say("  DEFECT the name field took no typing after a tap")
	else:
		say("  name typed: %s" % cs._typed)
	await _wait(0.6)
	await press("Choose a Blade")
	step("starting sword")
	await _until(func(): return _find("Rise") != null and cs.carousel != null, 8.0, "the sword picker")
	await _wait(1.0)
	audit("blade")
	var want: String = Db.canon(str(args.get("weapon", "w_dawnline")))
	var swords: Array = Db.equipment.basic_swords
	var tries := 0
	while cs.carousel != null and str(swords[cs.carousel.index]) != want and tries < 8:
		tries += 1
		var r := cs.carousel.get_global_rect()
		var dirx := -1.0 if swords.find(want) > cs.carousel.index else 1.0
		var a := r.get_center() - Vector2(dirx * 70.0, 0)
		_touch(0, a, true)
		for i in 6:
			await _frames(1)
			_drag(0, a + Vector2(dirx * 24.0 * (i + 1), 0), Vector2(dirx * 24.0, 0))
		await _frames(1)
		_touch(0, a + Vector2(dirx * 144.0, 0), false)
		await _wait(1.3)
	say("  sword in the middle: %s (wanted %s, %d drags)" % [str(swords[cs.carousel.index]), want, tries])
	if str(swords[cs.carousel.index]) != want:
		say("  DEFECT the sword row did not reach %s by dragging" % want)
		cs.carousel.go_to(swords.find(want))
		await _wait(1.2)
	await press("Rise")
	say("  saved? slot %d exists=%s  weapon=%s body=%s name=%s" % [Game.slot, str(Game.slot_exists(Game.slot)), str(Game.profile.equipped.weapon), str(Game.profile.body), str(Game.profile.get("name", ""))])
	if str(args.get("until", "")) == "menu":
		await _end()
		return
	await _story_to_road()
	if str(args.get("until", "")) == "arrival":
		await _end()
		return
	await _road()
	await _end()

func _skip_if_fast() -> void:
	if not args.has("fast"):
		return
	var b := _find("SKIP", true)
	if b != null and duel() == null:
		await tap(b)
		await _wait(0.6)

## Generation I, the years, the arrival, the Engine, the walk out: watched, fought where it is fought.
func _story_to_road() -> void:
	step("generation I")
	await _until(func(): return main.current is Prologue, 20.0, "Generation I")
	var beat := -1
	var seen := ""
	while not (main.current is Explore):
		await _wait(0.25)
		var c: Node = main.current
		var name := _screen()
		if name != seen:
			seen = name
			match name:
				"TimeJump": step("time jump")
				"Arrival": step("the heir's arrival")
				"Awakening": step("awakening at the Inheritance Engine")
				"Approach": step("approach")
			audit()
		if c is Prologue and int(c.beat) != beat:
			beat = int(c.beat)
			step("generation I, beat %d" % beat)
		if c is Awakening and c._prompt != null and _shown(c._prompt) and c._prompt.modulate.a > 0.9:
			say("  the prompt is up: %s" % str(c._prompt.label))
			audit("prompt")
			await _wait(1.0)
			await tap(c._prompt, "TAKE UP YOUR SWORD")
			await _wait(2.0)
		var d := duel()
		if d != null and d.stage == Duel.Stage.FIGHT:
			audit("duel")
		await _skip_if_fast()
		if gt > 1500.0:
			say("STUCK the story did not reach the road in 25 minutes (screen %s)" % name)
			_stuck += 1
			return
	step("first stop of the road")
	say("  the knight holds %s; profile generation %d; opening seen=%s" % [str(Game.profile.equipped.weapon), Game.generation(), str(Opening.seen_before())])

var _turned_back := false
var _halt := false               # --until=quit: the run ends at the main menu, for a second launch to take up
var _boss_done := false

## The Courtyard's road by touch: the first leg, a visit to the sanctuary, the rest, the guardian.
func _road() -> void:
	var last := ""
	var idle := 0.0
	while not (_boss_done and main.current is Sanctuary):
		if _halt:
			return
		await _wait(0.3)
		idle += 0.3
		var c: Node = main.current
		var here := _screen()
		if here != last:
			last = here
			idle = 0.0
		if idle > 240.0:
			say("STUCK on %s for four minutes. On screen: %s" % [here, ", ".join(_texts())])
			_stuck += 1
			_snap("stuck")
			return
		if c is Explore:
			if await _stop(c):
				idle = 0.0
		elif c is Duel:
			if await _in_duel(c):
				idle = 0.0
		elif c is Sanctuary:
			idle = 0.0
			await _sanctuary(c)
		else:
			# a loading screen, a fade, a message over something
			for t: String in ["Onward", "Rest", "Continue", "Rise"]:
				var b := _find(t)
				if b != null:
					await tap(b)
					break
	if _halt:
		return
	step("after the guardian")
	await _after_boss()

## One stop: look round, take what is lying there, choose a way. Returns true if something was done.
func _stop(e: Explore) -> bool:
	if e._leaving or e._staging or Story.busy or e.layer.get_child(0).modulate.a < 0.95 or not e.layer.get_child(0).visible:
		for t: String in ["Open", "Pull", "Rest", "Onward"]:
			var b0 := _find(t)
			if b0 != null:
				audit("interact")
				await _wait(0.8)
				await tap(b0)
				return true
		return false
	var stage: int = int(Game.run.stage)
	step("courtyard stop %d: %s" % [stage + 1, str(Game.run_stage().prompt).left(60)])
	say("  health %d / %d, gold %d, level %d" % [int(Game.run.hp), int(Game.stats().max_hp), int(Game.profile.gold), int(Game.profile.level)])
	await _wait(1.2)
	audit("stop")
	_snap("stop%d" % (stage + 1))
	# the coin lying off the path, and anything odd in the place
	for pr: Array in e.pouches.duplicate():
		var pb: Button = pr[1]
		if is_instance_valid(pb) and pb.visible:
			var g := int(Game.profile.gold)
			await tap(pb, "a pouch")
			await _wait(0.5)
			say("  pouch: gold %d -> %d" % [g, int(Game.profile.gold)])
	for sp: Dictionary in e.spots.duplicate():
		var sb: Button = sp.button
		if is_instance_valid(sb) and sb.visible and get_viewport().get_visible_rect().has_point(sb.get_global_rect().get_center()):
			var before: int = Game.profile.get("secrets", {}).size() if Game.profile.get("secrets") is Dictionary else 0
			await tap(sb, "something odd (%s)" % str(sp.secret.get("id", "a clue")))
			await _wait(2.5)
			await _until(func(): return not is_instance_valid(e) or (not e._staging and not Story.busy), 60.0, "the discovery to play out")
			await _wait(1.0)
			var b1 := _find("Onward")
			if b1 == null:
				b1 = _find("Continue")
			if b1 != null and e.layer.get_child(0).modulate.a < 0.95:
				await tap(b1)
			say("  secrets known: %d -> %d" % [before, Game.profile.get("secrets", {}).size() if Game.profile.get("secrets") is Dictionary else 0])
	if not is_instance_valid(e) or e._leaving or main.current != e:
		return true
	if stage == 4 and not _turned_back and not args.has("no_sanctuary"):
		_turned_back = true
		step("turning back to the sanctuary")
		await press("Turn Back")
		return true
	var opts: Array = Game.stage_options()
	var pick := 0
	var want := {1: "treasure", 3: "lever", 4: "fight"}
	for i in opts.size():
		if str(opts[i].type) == str(want.get(stage, "")):
			pick = i
	var label: String = str(opts[pick].label)
	say("  ways onward: %s; taking '%s' (%s)" % [str(opts.map(func(o): return o.label)), label, str(opts[pick].type)])
	var card := _find(label)
	if card == null:
		say("  DEFECT no card on screen for '%s'" % label)
		e._choose(opts[pick], pick)
	else:
		await tap(card, label)
	await _wait(1.0)
	return true

## Dev: begins on the Courtyard's road at `stop` with a fresh knight, with nothing before it played.
func _from_road(stop: int) -> void:
	var want: String = Db.canon(str(args.get("weapon", "w_dawnline")))
	Game.new_game("#3d0f0f", str(args.get("body", "m")), want, 2)
	Game.profile.tutorial_done = true
	Game.profile.flags["gen2_arrived"] = true
	Game.start_run("courtyard")
	Game.run.stage = stop
	Game.run.checkpoint = Game.checkpoint_at_or_before("courtyard", stop)
	step("on the road at stop %d (checkpoint %d)" % [stop + 1, int(Game.run.checkpoint)])
	main.show_stage()
	await _road()

var _in_fight := 0
var _paused_once := false

func _in_duel(d: Duel) -> bool:
	if d.get_instance_id() != _in_fight:
		_in_fight = d.get_instance_id()
		var boss: bool = str(d.foe.get("id", "")) == "ashen_sentinel" and not d.sim.lesson
		if not d.sim.lesson:
			fights += 1
		_die_now = not d.sim.lesson and ((boss and _die.has("boss")) or (not boss and _die.has(str(fights))))
		if _die_now:
			_die.erase("boss" if boss else str(fights))
		step("duel %d: %s%s%s" % [fights, str(d.foe.get("name", "")), " (the lesson)" if d.sim.lesson else "", " — meaning to lose" if _die_now else ""])
		_fight_watch(d)
		return true
	if d.stage == Duel.Stage.FIGHT and not _paused_once and not args.has("road") and not d.sim.lesson and d.sim.time > 6.0 and not get_tree().paused:
		_paused_once = true
		say("  pausing mid-fight")
		audit("fight")
		_hold_block(d, false)
		var pb := _find("II")
		if pb == null:
			say("  DEFECT no pause button found")
			return true
		await tap(pb)
		await _wait(1.5)
		say("  paused=%s; on screen: %s" % [str(get_tree().paused), ", ".join(_texts())])
		audit("pause")
		_snap("pause")
		var t_sim := d.sim.time
		await _wait(1.5)
		if d.sim.time > t_sim + 0.05:
			say("  DEFECT the fight ran on behind the pause screen (%.2f s)" % (d.sim.time - t_sim))
		await press("Resume")
		await _wait(0.5)
		say("  resumed; paused=%s" % str(get_tree().paused))
		return true
	for t: String in ["Continue", "Retry from checkpoint", "Rise"]:
		var b := _find(t)
		if b != null and d.stage != Duel.Stage.FIGHT:
			await _wait(2.4)                 # read the screen
			audit("result")
			_snap("result")
			var p: Dictionary = Game.profile
			say("  result screen up: [%s]. gold %d, level %d, xp %d, inventory %d, deaths %d" % [t, int(p.gold), int(p.level), int(p.xp), p.inventory.size(), int(p.deaths)])
			if t == "Retry from checkpoint":
				deaths += 1
				if str(args.get("until", "")) == "retry":
					_retry_then_halt()
				_die_now = false
				if deaths > 3 + (2 if args.has("die") else 0) and not _assist:
					_assist = true
					say("  too many defeats by touch: the sim's bot will fight from here (noted as an assist)")
			await tap(b)
			await _wait(1.0)
			return true
	return false

## --until=retry: lets the road be walked on from the checkpoint for a while, then ends the run.
func _retry_then_halt() -> void:
	await get_tree().create_timer(1.0).timeout
	await _until(func(): return main.current is Explore, 60.0, "the road at the checkpoint")
	say("  retried: on the road at stop %d with %d of %d health" % [int(Game.run.stage) + 1, int(Game.run.hp), int(Game.stats().max_hp)])
	await _wait(14.0)
	_halt = true

## Logs a fight's own story: its length, the phases, how it ended.
func _fight_watch(d: Duel) -> void:
	var t0 := gt
	var phases: Array = []
	var counts := {"parried": 0, "blocked": 0, "dodged": 0, "hit": 0, "boss_hit": 0}
	d.sim.ev.connect(func(n: StringName, e: Dictionary):
		if n == &"phase":
			phases.append("%.0fs" % (gt - t0))
			say("  phase change at %.0f s into the fight (knight %d hp, foe %d hp)" % [gt - t0, int(d.sim.pl.hp), int(d.sim.b_hp)])
		var k := str(e.get("result", "")) if n == &"boss_strike" else str(n)
		if counts.has(k):
			counts[k] += 1)
	d.finished.connect(func(won: bool, sim: DuelSim):
		say("  duel over after %.0f s: %s. knight %d / %d hp. parried %d, blocked %d, dodged %d, blows taken %d, cuts landed %d" % [gt - t0, "WON" if won else "LOST",
			int(sim.pl.hp), int(sim.pl.max_hp), counts.parried, counts.blocked, counts.dodged, counts.hit, counts.boss_hit])
		if won and str(d.foe.get("id", "")) == "ashen_sentinel" and not sim.lesson:
			_boss_done = true)
	var max_gap := 0.0
	while is_instance_valid(d) and d.stage != Duel.Stage.DONE and not d.sim.over:
		await get_tree().process_frame
		if not is_instance_valid(d) or not is_instance_valid(d.player_rig) or not is_instance_valid(d.foe_rig):
			break
		if d.stage == Duel.Stage.FIGHT:
			var g: float = (d.player_rig.global_position - d.foe_rig.global_position).length()
			max_gap = maxf(max_gap, g)
			var cam := get_viewport().get_camera_3d()
			if cam and cam.is_position_behind(d.player_rig.global_position + Vector3(0, 1, 0)) and Engine.get_process_frames() % 30 == 0:
				say("  NOTE the knight is behind the camera at %.0f s" % (gt - t0))
	say("  widest gap between the fighters: %.1f m" % max_gap)

var _visited := false

func _sanctuary(s: Sanctuary) -> void:
	if _visited:
		# back here after a defeat, or after the guardian
		if _boss_done:
			return
		await _wait(2.0)
		for t: String in ["Rest", "Continue"]:
			var b := _find(t)
			if b != null:
				await tap(b)
		await _set_out(s)
		return
	_visited = true
	step("sanctuary")
	await _wait(2.5)
	audit("journey")
	_snap("sanctuary")
	say("  tabs: %s. purse: %s" % [", ".join(_texts()), s.purse.text])
	# ---- Armory: put on what the road gave
	step("sanctuary: Armory")
	await tap(s.tab_buttons["Armory"])
	await _wait(3.0)
	audit("armory")
	_snap("armory")
	say("  on screen: %s" % ", ".join(_texts()))
	var worn: Dictionary = Game.profile.equipped.duplicate()
	for id: String in Game.profile.inventory:
		var it: Dictionary = Db.item(id)
		if not Game.is_equipped(id) and str(it.get("slot", "")) in ["gauntlets", "helm"]:
			if s.armory != null:
				s.armory._enter_slot(str(it.slot), id)
				await _wait(2.0)
			break
	var eq := _find("Equip")
	if eq != null:
		await tap(eq)
		await _wait(1.5)
	say("  equipped before %s" % str(worn))
	say("  equipped after  %s" % str(Game.profile.equipped))
	_snap("armory2")
	if args.has("forge_first"):
		await _forge_visit(s)
		await _shop_visit(s)
	else:
		await _shop_visit(s)
		await _forge_visit(s)
	# ---- leave by the menu and come back by Continue
	if not args.has("no_quit"):
		step("sanctuary: Settings, quit to the menu")
		await tap(s.tab_buttons["Settings"])
		await _wait(2.0)
		audit("settings")
		_snap("settings")
		var q := _find("Return to title")
		if q == null:
			say("  DEFECT no way to the main menu from the sanctuary. On screen: %s" % ", ".join(_texts()))
		else:
			await tap(q)
			await _until(func(): return main.current is TitleScreen, 10.0, "the main menu")
			step("main menu again")
			await _wait(2.0)
			audit("returning")
			_snap("menu2")
			say("  menu: %s  ·  status line: %s" % [", ".join(_texts()), (main.current as TitleScreen).status_line()])
			if str(args.get("until", "")) == "quit":
				_halt = true
				return
			await press("Continue")
			await _until(func(): return main.current is Sanctuary, 15.0, "the sanctuary after Continue")
			step("sanctuary after Continue")
			await _wait(2.0)
			if main.current is Sanctuary:
				await _set_out(main.current)
			return
	await _set_out(s)

func _shop_visit(s: Sanctuary) -> void:
	# ---- Shop: buy the dearest thing the purse reaches
	step("sanctuary: Shop")
	await tap(s.tab_buttons["Shop"])
	await _wait(3.0)
	audit("shop")
	_snap("shop")
	say("  on screen: %s" % ", ".join(_texts()))
	var gold := int(Game.profile.gold)
	if s.screen is ShopScreen:
		var shop: ShopScreen = s.screen
		var best := ""
		var best_p := 0
		for e: Dictionary in shop.catalogue():
			var p := int(e.price)
			if bool(e.available) and not Game.owns(str(e.id)) and p <= gold and p > best_p:
				best = str(e.id)
				best_p = p
		say("  gold %d; catalogue %d entries; dearest within reach: %s (%d)" % [gold, shop.catalogue().size(), best, best_p])
		if best != "":
			shop.select(best)
			await _wait(1.5)
			var bb := _find("Buy")
			if bb == null:
				say("  DEFECT no Buy button for an item the purse can pay for")
			else:
				await tap(bb)
				await _wait(1.0)
				var yes := _find("Buy")
				if yes != null and shop.dialog != null and is_instance_valid(shop.dialog):
					audit("confirm")
					await tap(yes)
					await _wait(1.0)
				say("  bought %s? owns=%s gold %d -> %d; purse shows '%s'" % [best, str(Game.owns(best)), gold, int(Game.profile.gold), s.purse.text])
				await _wait(1.6)
				say("  purse label after the count: '%s'" % s.purse.text)
				_snap("bought")
				var e2 := _find("Equip")
				if e2 != null:
					await tap(e2)
					await _wait(1.0)
					say("  equipped now: %s" % str(Game.profile.equipped))

func _forge_visit(s: Sanctuary) -> void:
	# ---- Forge: one piece of work if it can be paid for
	step("sanctuary: Forge")
	await tap(s.tab_buttons["Blacksmith"])
	await _wait(3.0)
	audit("forge")
	_snap("forge")
	say("  on screen: %s" % ", ".join(_texts()))
	var done_work := false
	for verb: String in ["Sharpen", "Temper", "Reforge", "Rewrap", "Smelt"]:
		var fb := _find(verb)
		if fb != null:
			var g2 := int(Game.profile.gold)
			await tap(fb)
			await _wait(1.0)
			# the work is shown at the anvil; its result waits for a tap
			await _until(func(): return _find("Continue") != null, 30.0, "the forge's result")
			await _wait(1.5)
			_snap("forge_result")
			audit("forge result")
			var fin := _find("Continue")
			if fin != null:
				await tap(fin)
			await _wait(1.5)
			say("  forge '%s': gold %d -> %d; weapon mods %s" % [verb, g2, int(Game.profile.gold), str(Game.weapon_mods(str(Game.profile.equipped.weapon)))])
			_snap("forged")
			done_work = true
			break
	if not done_work:
		say("  nothing at the forge could be paid for (gold %d, shards %d, materials %s)" % [int(Game.profile.gold), int(Game.profile.shards), str(Game.profile.get("materials", {}))])
	await _until(func(): return s.frame.visible and not s._forging, 30.0, "the forge to finish")

func _set_out(s: Sanctuary) -> void:
	if s.tab != "Journey":
		await tap(s.tab_buttons["Journey"])
		await _wait(1.5)
	audit("journey2")
	var by := _find("By ", true)
	say("  setting out: %s" % ("by the short way" if by != null else "from the first stop (no short way open)"))
	var t0 := gt
	var w0 := Time.get_ticks_msec()
	if by != null:
		await tap(by)
	else:
		await press("Set Out")
	await _until(func(): return main.current is Explore, 40.0, "the road")
	say("  loading took %.1f s of game time (%.1f s wall)" % [gt - t0, (Time.get_ticks_msec() - w0) / 1000.0])

func _after_boss() -> void:
	await _until(func(): return main.current is Sanctuary, 60.0, "the sanctuary after the guardian")
	await _wait(2.5)
	_snap("after_boss")
	audit("after boss")
	say("  on screen: %s" % ", ".join(_texts()))
	var p: Dictionary = Game.profile
	say("  cleared %s; defeated %s; gold %d; level %d; inventory %s" % [str(p.cleared), str(p.defeated), int(p.gold), int(p.level), str(p.inventory)])
	var rest := _find("Rest")
	if rest != null:
		await tap(rest)
		await _wait(1.5)
	if main.current is Sanctuary:
		var s: Sanctuary = main.current
		say("  what comes next: regions open: %s" % str(Db.regions.filter(func(r): return Game.region_unlocked(r.id)).map(func(r): return r.id)))
		_snap("next")
		audit("next")

func _resume() -> void:
	step("second launch: Continue")
	var t: TitleScreen = main.current
	say("  save present=%s; menu: %s; status: %s" % [str(Game.has_save()), ", ".join(_texts()), t.status_line()])
	if _find("Continue") == null:
		say("  DEFECT no Continue on a second launch: the save did not persist")
		return
	await press("Continue")
	await _until(func(): return not (main.current is TitleScreen), 15.0, "something after Continue")
	await _wait(3.0)
	var p: Dictionary = Game.profile
	say("  landed on %s. cleared %s, defeated %s, gold %d, level %d, weapon %s, body %s, name %s" % [_screen(), str(p.cleared), str(p.defeated), int(p.gold), int(p.level), str(p.equipped.weapon), str(p.body), str(p.get("name", ""))])
	_snap("resumed")
	if main.current is Sanctuary and not p.cleared.has("courtyard"):
		# the second half of the slice, from the save: out by the short way, the rest of the road, the guardian
		_turned_back = true
		await _sanctuary(main.current)
		await _road()

func _end() -> void:
	_meter_report()
	var keys: Array = _audit.keys()
	keys.sort()
	say("SLICE RUN ENDED at step '%s'. fights %d, defeats %d, taps missed %d, stuck %d, longest held frame %.1f s, assist %s, audit notes %d" % [_step, fights, deaths, _missed, _stuck, _black_max, str(_assist), keys.size()])
	await _wait(1.0)
	get_tree().quit()
