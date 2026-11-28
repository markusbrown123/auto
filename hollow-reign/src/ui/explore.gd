class_name Explore
extends Node
## One stop along a region's road: a slow camera move through the place,
## a line of description, and the ways onward.

signal fight(option: Dictionary)
signal moved_on
signal turned_back

var backdrop: Backdrop
var layer: CanvasLayer
var cards: VBoxContainer
var prompt: Label
var hp_bar: ProgressBar
var angle := 0.0
var markers: Array = []       # world positions of each option's path marker
var pouches: Array = []       # [prop, button]
var _leaving := false
var adopted: Backdrop         # a place already built and on screen (the Approach hands its own over): no rebuild, no cut
var foes: Array = []          # the figure standing at each fight's marker, or null
var _staging := false         # a staged moment has the camera; the choices wait
var relic: Node3D             # the Witness lying dormant in its plinth, while it is being found (a WitnessDrone)
var spots: Array = []         # hidden things at this stop: {node, button, secret, index, lamp}
var _idle := 0.0              # seconds stood here without doing anything (some places answer that)
var _order: Dictionary = {}   # secret id -> the inscriptions touched so far, in order
var _clock := 0.0
var witness_shots: Array = []   # the set-ups the Witness's first scene has cut to, in order (tests, captures)

const CAM_POS := Vector3(1.3, 1.7, 4.2)
const CAM_LOOK := Vector3(-0.3, 1.25, -4.0)

## Each stage looks across the arena from its own bearing.
static func bearing(stage: int) -> float:
	return stage * 0.85 - 0.4

func _ready() -> void:
	var stage: int = Game.run.stage
	angle = bearing(stage)
	Game.save()                   # the road is saved at every stop reached: an app ended in the background comes back here
	if continuous():
		_route_ready()
		return
	var region := Game.run_region()
	if adopted:
		# the knight has just walked in, in this very place: keep it, and let the camera settle from where it is
		backdrop = adopted
		if backdrop.get_parent():
			backdrop.get_parent().remove_child(backdrop)
		add_child(backdrop)
		backdrop.cam.make_current()
		backdrop.rig.rotation.y = angle
		backdrop.rig.walking = false
		backdrop.move_camera(_at(angle, CAM_POS), _at(angle, CAM_LOOK))
	else:
		backdrop = Backdrop.new()
		add_child(backdrop)
		backdrop.build(region.theme)
		# arriving pans from the last stage's bearing
		var prev := angle - 0.85
		backdrop.rig.rotation.y = angle
		backdrop.move_camera(_at(prev, Vector3(1.3, 1.9, 5.2)), _at(prev, Vector3(0, 1.3, -4.0)), true)
		backdrop.move_camera(_at(angle, CAM_POS), _at(angle, CAM_LOOK), Game.settings.reduce_motion)
		if not Game.settings.reduce_motion:
			# the arrival is a slow turn of the view onto the road, not a swing: it starts gently, gathers, and settles
			backdrop.cam_speed = 0.55
			create_tween().tween_property(backdrop, "cam_speed", 1.6, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_open_stop()

## One stop's screen: its title and health, its line, the ways onward marked in the place and as cards, what lies
## about (pouches, secrets), and whoever waits on a way. In the continuous Courtyard it is opened again, in the same
## place, at every stop the knight walks to.
func _open_stop() -> void:
	var region := Game.run_region()
	var stage: int = Game.run.stage
	Sfx.ambience(str(region.amb))
	Sfx.music_for("explore_" + str(region.id), "menu")
	_leaving = false
	if route:
		_reset_stop()
	layer = CanvasLayer.new()
	add_child(layer)
	var m := UI.margin(get_viewport(), 8)
	layer.add_child(m)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(frame)
	var head := VBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	head.add_theme_constant_override("separation", 2)
	frame.add_child(head)
	head.add_child(UI.title(region.name, 24))
	var pips := ""
	for i in region.stages.size():
		pips += "◆ " if i < stage else ("◇ " if i > stage else "❖ ")
	head.add_child(UI.label(pips, 18, UI.GOLD_DIM))
	hp_bar = UI.bar(Color("#9a2a2a"), 10)
	hp_bar.custom_minimum_size.x = 230
	hp_bar.max_value = Game.stats().max_hp
	hp_bar.value = Game.run.hp
	head.add_child(hp_bar)
	for l in Game.find_lore(region.id, stage):
		head.add_child(UI.label("Record found  ·  " + str(l.title), 15, UI.GOLD))
	var back := UI.button("Turn Back", 14, 150)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -150
	back.pressed.connect(func():
		if _shown():
			turned_back.emit()
			if Game.run.is_empty():
				Game.save())          # the road was left: it is not taken up again on Continue
	frame.add_child(back)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 10)
	frame.add_child(bottom)
	# a stop the director tells differently for this generation has no line of the second generation's over it
	var retold: bool = Game.generation() != 2 and Encounters.data().stops.get(str(Game.generation()), {}).get(str(region.id), {}).has(str(stage))
	prompt = UI.label("" if retold else str(Game.run_stage().prompt), 24, UI.BONE)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	prompt.add_theme_constant_override("shadow_offset_y", 2)
	bottom.add_child(prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bottom.add_child(row)
	var opts := Game.stage_options()
	for i in opts.size():
		# each way onward is marked on the ground ahead, left to right
		var x := (float(i) - (opts.size() - 1) * 0.5) * 3.2
		if opts[i].has("foe"):
			x = clear_x(x - 0.3) + 0.3
		var at := _at(angle, Vector3(x - 0.3, 0, -4.6))
		backdrop.add_prop("marker", at).set_meta("stop_ui", true)
		markers.append(at)
		_stand_foe(opts[i], at)
		row.add_child(_card(opts[i], i))
	_scatter_pouches(frame, int(Game.run_stage().get("pouches", 1)))
	_place_secrets(frame)
	WitnessDrone.set_points(self, _witness_points())      # what the Witness may drift over to and look at
	if route:
		_witness_ahead(stage)
	for note: Dictionary in Secrets.take_notes():
		head.add_child(UI.label("Secret found  ·  " + str(note.name), 15, UI.GOLD))
		_banner(note)
	layer.get_child(0).modulate.a = 0.0
	var said: Array = Companion.pick_stage(str(region.id), stage)
	if not said.is_empty():
		# let the place and the voice land first; the choices appear once the line is done
		await get_tree().create_timer(1.4).timeout
		if not is_inside_tree():
			return
		if said.has(Companion.discovery_id()) and _monument() != Vector3.INF:
			await _find_witness(str(region.id), stage)
		elif said.any(func(id: String): return Companion.essential(id)):
			await Companion.on_stage(str(region.id), stage)
		else:
			# a remark on the place does not hold the road up: the ways onward come up under it after a moment, the
			# words sit above them, and choosing a way ends the remark (it is said again another time)
			_aside = true
			_say_aside(str(region.id), stage)
			await get_tree().create_timer(CHOICES_AFTER).timeout
		if not is_inside_tree():
			return
	create_tween().tween_property(layer.get_child(0), "modulate:a", 1.0, 0.9).set_delay(0.3)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--walk="):          # dev captures: walk on through a way's marker after a few seconds, with the footfalls logged
			FighterRig.log_feet = true
			FighterRig.foot_log.clear()
			await get_tree().create_timer(3.0).timeout
			var t0 := Engine.get_process_frames()
			_walk_then(int(arg.trim_prefix("--walk=")), func():
				var line := "FEETLOG %d footfalls, frames: %s" % [FighterRig.foot_log.size(), str(FighterRig.foot_log)]
				print(line)
				if OS.get_environment("FEETLOG") != "":
					var f := FileAccess.open(OS.get_environment("FEETLOG"), FileAccess.WRITE)
					f.store_line(line)
					f.store_line("walk began at frame %d" % t0), true)
		if arg.begins_with("--choose="):          # dev captures: take a way onward by its index, as a tap would
			await get_tree().create_timer(2.0).timeout
			var o: Array = Game.stage_options()
			var i := int(arg.trim_prefix("--choose="))
			if is_inside_tree() and i < o.size():
				_choose(o[i], i)

const CHOICES_AFTER := 1.6      # seconds of a companion's remark before the ways onward appear under it
const ASIDE_LIFT := 236.0       # how far above the foot of the screen its words sit: clear of the prompt and the cards
var _aside := false             # a remark is being made over the choices

func _say_aside(region_id: String, stage: int) -> void:
	await Companion.on_stage_aside(region_id, stage, ASIDE_LIFT)
	_aside = false

func _at(a: float, v: Vector3) -> Vector3:
	return origin + v.rotated(Vector3.UP, a)

## A direction or an offset in the stop's own frame (no origin).
func _rot(v: Vector3) -> Vector3:
	return v.rotated(Vector3.UP, angle)

## The walking corridor of a stop (`Corridor`): from a few metres behind the knight (where the camera trails) to a way's
## marker, for each way onward; and, at the first stop, the line the knight has walked in on. Props the place builds
## after this are kept out of these lanes (Backdrop.build calls it before it builds the place).
static func road_lanes(a: float, with_approach: bool) -> void:
	Corridor.lanes.clear()
	var back := Vector3(0, 0, 5.5).rotated(Vector3.UP, a)
	var opts: Array = Game.stage_options()
	for i in opts.size():
		var x := (float(i) - (opts.size() - 1) * 0.5) * 3.2
		if opts[i].has("foe"):
			x = clear_x(x - 0.3) + 0.3
		Corridor.add(back, Vector3(x - 0.3, 0, -4.9).rotated(Vector3.UP, a))
	if with_approach:
		Corridor.add(Vector3(0, 0, 17.0).rotated(Vector3.UP, a), Vector3.ZERO, 2.0)

## Where across the road a way's marker may be so that whoever waits on it (1.6 m beyond the marker) is not hidden
## behind the knight: seen from the stop's camera, the two must be at least CLEAR_DEG apart. With two ways onward the
## left one used to stand exactly on the line from the lens through the knight's back. Moved outward, never across.
const CLEAR_DEG := 9.5
const FOE_BEYOND := 1.6
static func clear_x(x: float) -> float:
	var z := -4.6 - FOE_BEYOND
	var knight := rad_to_deg(atan2(0.0 - CAM_POS.x, CAM_POS.z))
	var foe := rad_to_deg(atan2(x - CAM_POS.x, CAM_POS.z - z))
	if absf(foe - knight) >= CLEAR_DEG:
		return x
	var side := -1.0 if foe <= knight + 0.5 else 1.0
	return CAM_POS.x + tan(deg_to_rad(knight + side * CLEAR_DEG)) * (CAM_POS.z - z)

# ---------------------------------------------------------------- what waits on the road
## The foe of a fight stands at its marker, so the way onward shows what is on it. Guardians keep their entrance
## for the duel. Its files are read on a thread first, so neither this nor the duel after it has to stop the picture.
static var _kept: Array = []          # models read ahead, held so the duel finds them loaded

func _stand_foe(o: Dictionary, at: Vector3) -> void:
	var index := foes.size()
	foes.append(null)
	if not o.has("foe") or not Db.foes.has(str(o.foe)):
		return
	if route:
		# (the continuous Courtyard's foes are in the place from the start, where they were left: RouteLife)
		if life and str(o.get("type", "")) in ["fight", "boss"]:
			foes[index] = life.foe_at(int(Game.run.stage))
			if foes[index] == null:
				_want["fight"] = index         # still being read: handed over when it stands
		return
	var foe: Dictionary = Db.foes[str(o.foe)]
	var files: Array = CineActor.foe_files(str(o.foe))
	if o.type != "fight" or str(foe.rig.get("kind", "")) == "dragon":
		_read_ahead(files, Callable())
		return
	_read_ahead(files, func():
		if not is_inside_tree() or backdrop == null:
			return
		var f := FighterRig.new()
		backdrop.props.add_child(f)
		f.build(CineActor.foe_look(str(o.foe)), true)
		f.position = at + _rot(Vector3(0, 0, -FOE_BEYOND))
		f.rotation.y = angle + PI
		f.time_scale = 0.6
		if route:
			f.ground = CourtRoute.ground_y
		if index < foes.size():
			foes[index] = f)

func _read_ahead(files: Array, then: Callable) -> void:
	var pending: Array = []
	for p: String in files:
		if ResourceLoader.exists(p) and not ResourceLoader.has_cached(p) and ResourceLoader.load_threaded_request(p) == OK:
			pending.append(p)
	while not pending.is_empty():
		await get_tree().process_frame
		if not is_inside_tree():
			return
		for p: String in pending.duplicate():
			if ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_kept.append(ResourceLoader.load_threaded_get(p))
				pending.erase(p)
	while _kept.size() > 8:
		_kept.pop_front()
	if then.is_valid():
		then.call()

# ---------------------------------------------------------------- the Witness is found
## Where the fallen monument lies in this place (INF where the place has none).
func _monument() -> Vector3:
	if route:
		return CourtRoute.MONUMENT if PropModel.exists("res://assets/models/env_statue_head.glb") else Vector3.INF
	if backdrop.arena._theme_id == "courtyard" and PropModel.exists("res://assets/models/env_statue_head.glb"):
		return Vector3(6.4, 0, -2.4)
	return Vector3.INF

## The camera goes to the fallen monument. A hatch in the plinth beside it, shut since before the road was laid,
## slides back in its own dust; the instrument lying inside lights (seam, then halo), rises, turns its halo to the
## knight and speaks; when they are done it crosses to the knight's shoulder, where it stays from here on.
func _find_witness(region_id: String, stage: int) -> void:
	_staging = true
	var m := _monument()
	var from := (backdrop.rig.position - m).normalized()
	var side := from.rotated(Vector3.UP, -0.9)
	var rest := m + side * 1.7 + from * 0.25      # clear of the fallen stone, on open paving
	var yaw := atan2(side.x, side.z)
	# the door Lyra finds: a machined hatch set flush in the paving at the monument's foot. Never medieval: a dark
	# plate in a thin bright frame, over a shallow lined recess.
	var plinth := Node3D.new()
	plinth.position = rest
	plinth.rotation.y = yaw
	backdrop.props.add_child(plinth)
	var alloy := StandardMaterial3D.new()
	alloy.albedo_color = Color(0.62, 0.63, 0.66)
	alloy.metallic = 0.9
	alloy.roughness = 0.42
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color(0.13, 0.135, 0.15)
	plate.metallic = 0.8
	plate.roughness = 0.5
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.035)
	dark.metallic = 0.6
	dark.roughness = 0.4
	for spec: Array in [[Vector3(0.66, 0.02, 0.42), Vector3(0, 0.01, 0), alloy], [Vector3(0.6, 0.006, 0.36), Vector3(0, 0.021, 0), dark], [Vector3(0.6, 0.022, 0.36), Vector3(0, 0.07, 0), plate]]:
		var bm := BoxMesh.new()
		bm.size = spec[0]
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = spec[2]
		mi.position = spec[1]
		plinth.add_child(mi)
	var hatch: MeshInstance3D = plinth.get_child(2)
	var d0 := WitnessDrone.new()
	backdrop.props.add_child(d0)
	d0.build()
	d0.dormant(rest + Vector3(0, 0.024, 0), yaw + 0.5)
	relic = d0
	var dust := CPUParticles3D.new()
	dust.emitting = false
	dust.one_shot = true
	dust.amount = 28
	dust.lifetime = 1.6
	dust.explosiveness = 0.7
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.3, 0.02, 0.2)
	dust.direction = Vector3(0, 1, 0)
	dust.spread = 60.0
	dust.initial_velocity_min = 0.15
	dust.initial_velocity_max = 0.5
	dust.gravity = Vector3(0, -0.5, 0)
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.2
	var puff := QuadMesh.new()
	puff.size = Vector2(0.09, 0.09)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.albedo_color = Color(0.62, 0.58, 0.52, 0.3)
	var soft := GradientTexture2D.new()      # a round, soft-edged mote, not a square
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(0.5, 0.0)
	soft.width = 32
	soft.height = 32
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	soft.gradient = fade
	pm.albedo_texture = soft
	puff.material = pm
	dust.mesh = puff
	dust.position = Vector3(0, 0.08, 0)
	plinth.add_child(dust)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffc98a")
	lamp.light_energy = 0.0
	lamp.omni_range = 2.6
	lamp.position = rest + Vector3(0, 0.3, 0)
	backdrop.props.add_child(lamp)
	var keep_pos := backdrop.cam_pos
	var keep_look := backdrop.cam_look
	backdrop.move_camera(rest + side * 1.05 + from * 0.7 + Vector3(0, 0.75, 0), rest + Vector3(0, 0.5, 0))
	var d := m - backdrop.rig.position
	create_tween().tween_property(backdrop.rig, "rotation:y", atan2(-d.x, -d.z), 0.8).set_trans(Tween.TRANS_SINE)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(func():
		Sfx.play("levelup", -12.0, 0.7)
		dust.emitting = true)
	tw.tween_property(hatch, "position:x", 0.66, 1.3).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(lamp, "light_energy", 0.5, 1.3)
	# it wakes on its own first word, not before: "from the dark"
	# four set-ups, cut on each change of voice (one shot used to hold for the whole conversation, 48 s): the hatch
	# (Lyra finds it), the instrument (its own lines), the knight past it (their questions), and the two of them
	# with the fallen monument (Lyra again, and the last word). All from one side of the line between them.
	var knight := backdrop.rig.position
	var to_k := (knight - rest).normalized()
	var perp := to_k.rotated(Vector3.UP, PI * 0.5)
	var mid := rest.lerp(knight, 0.5)
	if (keep_pos - mid).dot(perp) < 0.0:
		perp = -perp
	var span := (knight - rest).length()
	var shots := {
		"instrument": [rest + to_k * 1.5 + perp * 0.65 + Vector3(0, 1.0, 0), rest + Vector3(0, 0.72, 0)],      # the open hatch and the risen instrument both in frame
		"knight": [rest - to_k * 0.95 + perp * 0.6 + Vector3(0, 1.3, 0), knight + Vector3(0, 1.45, 0)],
		"pair": [mid + perp * (2.6 + span * 0.45) + Vector3(0, 1.2, 0), mid + Vector3(0, 1.0, 0)],
	}
	witness_shots = ["hatch"]
	var last_who := [""]
	var on_line := func(who: String, _lid: String):
		if who == "witness" and is_instance_valid(d0) and d0.state == WitnessDrone.State.DORMANT:
			d0.wake(0.95)
			d0.look_at_point(backdrop.rig.position + Vector3(0, 1.7, 0))
			create_tween().tween_property(lamp, "light_energy", 1.5, 1.2)
		if who == last_who[0]:
			return
		var take := "pair" if who == "lyra" or (who == "witness" and last_who[0] == "lyra" and witness_shots.size() > 2) else ("knight" if who == "player" else "instrument")
		last_who[0] = who
		if witness_shots.size() == 1 and who == "lyra":
			return                    # the first line is hers, over the hatch opening
		witness_shots.append(take)
		backdrop.move_camera(shots[take][0], shots[take][1], true)
		if take == "pair":
			backdrop.move_camera(shots[take][0] - perp * 0.5, shots[take][1])      # a slow push while they talk
	Story.line_started.connect(on_line)
	await Companion.on_stage(region_id, stage)
	Story.line_started.disconnect(on_line)
	if not is_inside_tree():
		return
	Sfx.play("loot", -4.0)
	var out := create_tween()
	out.tween_property(lamp, "light_energy", 0.0, 0.6)
	out.tween_callback(lamp.queue_free)
	backdrop.move_camera(keep_pos, keep_look)
	if Companion.witness_found():
		# it crosses to the shoulder; the knight is then rebuilt with the Witness as its own
		if d0.state == WitnessDrone.State.DORMANT:
			d0.wake()
		d0.idle()
		d0.state = WitnessDrone.State.FOLLOW
		d0.attach(backdrop.rig)
		await get_tree().create_timer(1.2).timeout
		if not is_inside_tree():
			return
		var pos := backdrop.rig.position
		backdrop.refresh_knight()
		backdrop.rig.position = pos
		backdrop.rig.rotation.y = angle
		_knight_setup()
	if relic:
		relic.queue_free()
		relic = null
	_staging = false

## Hidden coin: small, off the path, and only yours if you spot and tap it. Where each lies depends on the stop
## alone (never on how often the knight has fallen), and one that has been taken is gone for that heir: walking the
## road again after a defeat does not put it back (Game.pouch_taken).
func _scatter_pouches(frame: Control, n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d" % [Game.run.region, Game.run.stage])
	for i in n:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var reach := 6.5 if not route else float(CourtRoute.POUCH_REACH.get(int(Game.run.stage), 6.5))
		var at := _at(angle, Vector3(side * rng.randf_range(2.2, 4.2) - 0.3, 0, rng.randf_range(-reach, -2.0)))
		if Game.pouch_taken(i):
			continue
		var prop: Node3D = _world_pouches.get("%d|%d" % [int(Game.run.stage), i]) if route else null
		if prop == null or not is_instance_valid(prop):
			prop = backdrop.add_prop("pouch", at)
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(84, 84)
		b.size = Vector2(84, 84)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		frame.add_child(b)
		frame.move_child(b, 0)
		b.pressed.connect(func(): _take_pouch(prop, b, i))
		pouches.append([prop, b])

func _take_pouch(prop: Node3D, b: Button, index: int = 0) -> void:
	_idle = 0.0
	var amount := Game.take_pouch(index)
	if amount <= 0:
		return
	Sfx.play("loot", -2.0)
	var l := UI.label("+%d gold" % amount, 22, UI.GOLD, "bold")
	l.position = b.position + Vector2(10, 10)
	b.get_parent().add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(l.queue_free)
	for e in pouches:
		if e[0] == prop:
			pouches.erase(e)
			break
	prop.queue_free()
	b.queue_free()

func _process(_dt: float) -> void:
	if _in_duel:
		return                    # held under the duel fought here: it is not this screen's turn
	_tick_secrets(_dt)
	if _action != null and is_instance_valid(_action):
		_place_action()
	if route:
		_route_tick(_dt)
		if _meet_cam:
			_meet_cam_tick(_dt)
		elif not _room.is_empty():
			_room_cam_tick()
	_follow_cam()
	# keep each pouch's tap target over its place in the world
	for e in pouches:
		var p: Vector3 = e[0].global_position + Vector3(0, 0.15, 0)
		e[1].visible = not backdrop.cam.is_position_behind(p)
		e[1].position = backdrop.cam.unproject_position(p) - e[1].size * 0.5 - e[1].get_parent().global_position

## The knight walks to the chosen marker before the scene changes, at the pace of the walk clip (FighterRig.ROAD_SPEED),
## turning onto the line to it as they go; a way that is not a fight is walked on through, past the marker.
func _walk_then(index: int, then: Callable, through: bool = false) -> void:
	if _leaving:
		return
	_leaving = true
	if route and through:
		# the way on is walked from here along the road itself (travel), not to the marker and through it
		create_tween().tween_property(layer.get_child(0), "modulate:a", 0.0, 0.4)
		then.call()
		return
	var rig := backdrop.rig
	var to: Vector3 = markers[index] if index < markers.size() else _at(angle, Vector3(0, 0, -4.0))
	var dir := to - rig.position
	dir.y = 0.0
	var go := dir.length() * (1.0 if through else 0.85) + (2.2 if through else 0.0)
	var step := dir.normalized()
	var yaw := atan2(-dir.x, -dir.z)
	var from := rig.position
	var turn_from := rig.rotation.y
	rig.walking = true
	rig.footsteps = true
	_walk = {"u": 0.0}
	var dur := FighterRig.road_time(go)
	var tw := create_tween()
	# (the body does its own easing: it gathers way over the first part of a second and settles over the last; the
	# origin is carried at the clip's own pace, so the stride and the ground agree)
	tw.tween_method(func(u: float):
		_walk.u = u
		rig.position = from + step * go * u
		rig.rotation.y = lerp_angle(turn_from, yaw, smoothstep(0.0, 0.3, u)), 0.0, 1.0, dur)
	tw.tween_callback(func():
		rig.walking = false
		_walk = {}
		then.call())

## The camera that goes with the knight down the road: behind and to the sword side, low, looking a little ahead of
## them so there is room in front for the road; it drifts round and up as the walk goes on. No cuts, and nothing but
## the corridor (kept clear of props) is crossed by it. With Reduce motion the offsets are fixed.
var _walk := {}
var _cam_pull := 1.0              # 1: the follow camera at its own distance; less: brought in front of something in the way
var _way := 0                     # which way onward the stop's last interaction was at
func _follow_cam() -> void:
	if _walk.is_empty() or backdrop == null or backdrop.rig == null:
		return
	if route:
		if not _meet_cam and _room.is_empty():
			_route_cam()
		return
	var rig := backdrop.rig
	var u: float = float(_walk.u) if not Game.settings.reduce_motion else 0.0
	var b := Basis(Vector3.UP, rig.rotation.y)
	var back := b * Vector3(1.4 - 0.9 * u, 1.3 + 0.35 * u, 3.5 + 0.9 * u)
	var ahead := b * Vector3(-0.25, 1.2, -2.8)
	backdrop.cam_fov = 46.0
	backdrop.cam_speed = 1.7
	var eye := rig.position + back
	if FighterRig.loco:
		# nothing drawn comes between the camera and the knight: it is brought in, quickly, in front of what would
		var head := rig.position + Vector3(0, 1.6 * rig.scale.y, 0)
		var clear := CamFollow.clear_from(rig, [head, rig.position + Vector3(0, 1.15 * rig.scale.y, 0)], eye, 0.9)
		_cam_pull = lerpf(_cam_pull, clear, 0.5 if clear < _cam_pull else 0.03)
		eye = head.lerp(eye, _cam_pull)
		if _cam_pull < 0.98:
			backdrop.cam_speed = 7.0
	backdrop.move_camera(eye, rig.position + ahead)

## The foe on the road is shown before steel is drawn: the knight starts toward it, and the camera goes low
## and looks up at what is waiting. The duel opens on the same two figures facing each other.
func _reveal_then(index: int, then: Callable) -> void:
	if _leaving:
		return
	_leaving = true
	create_tween().tween_property(layer.get_child(0), "modulate:a", 0.0, 0.3)
	var rig := backdrop.rig
	var foe: FighterRig = foes[index]
	var dir := foe.position - rig.position
	var step := dir.normalized()
	var side := step.rotated(Vector3.UP, PI * 0.5)
	rig.rotation.y = atan2(-dir.x, -dir.z)
	rig.walking = true
	rig.footsteps = true
	foe.rotation.y = atan2(dir.x, dir.z)
	foe.time_scale = 1.0
	if route:
		# after the fight the knight walks on from where it was fought
		arrive = {"from": int(Game.run.stage), "label": _left_label, "at": foe.position}
	var tw := create_tween()
	tw.tween_property(rig, "position", rig.position + dir * 0.3, FighterRig.road_time(dir.length() * 0.3))
	# past the knight, low, and to the side they are not walking on: nothing of theirs crosses the lens
	backdrop.move_camera(foe.position - step * 2.3 - side * 1.2 + Vector3(0, 0.5, 0), foe.position + Vector3(0, 1.3 * foe.scale.y, 0))
	Sfx.play("armor", -6.0, 0.8)
	tw.tween_callback(then)

func _card(o: Dictionary, index: int = 0) -> Button:
	var tag: String = {"fight": "A foe", "boss": "The guardian", "treasure": "A cache", "shrine": "Respite", "lever": "A mechanism", "pass": "Onward"}[o.type]
	if o.get("optional", false):
		tag = "A hunt  ·  optional"
	if o.has("foe"):
		# name the kind of fight ahead, so the right weapon can be in hand
		tag += "  ·  " + str(Db.foes[o.foe].get("cls", ""))
	var b := UI.button("", 18, 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 114
	var v := VBoxContainer.new()
	UI.full(v)
	v.offset_left = 16
	v.offset_top = 10
	v.offset_right = -16
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	b.add_child(v)
	v.add_child(UI.label(tag.to_upper(), 13, UI.BLOOD.lightened(0.3) if o.type in ["fight", "boss"] else UI.GOLD_DIM, "bold"))
	v.add_child(UI.title(o.label, 20, UI.BONE))
	v.add_child(UI.label(o.hint, 17, UI.DIM))
	b.pressed.connect(func():
		if _shown():
			_choose(o, index))
	return b

## The choices are on screen: not faded out for a line being spoken or a staged moment. A faded control still takes
## touches, so a tap low on the screen during the Witness's scene or a discovery would otherwise pick a way unseen.
func _shown() -> bool:
	if layer == null or not is_instance_valid(layer):
		return false
	var ui: Control = layer.get_child(0)
	return ui.visible and ui.modulate.a > 0.5 and not _staging and not _leaving

func _choose(o: Dictionary, index: int = 0) -> void:
	_idle = 0.0
	_left_label = str(o.get("label", ""))
	if route and o.type in ["fight", "boss"] and not (index < foes.size() and foes[index] != null):
		arrive = {"from": int(Game.run.stage), "label": _left_label, "at": markers[index] if index < markers.size() else backdrop.rig.position}
	if _aside:
		_aside = false
		Story.stop()              # the player has heard enough: the remark gives way to what they chose
	match o.type:
		"fight", "boss":
			if route and life and index < foes.size() and foes[index] != null and is_instance_valid(foes[index]):
				_meet_then(index, o)
			elif index < foes.size() and foes[index] != null:
				_reveal_then(index, func(): fight.emit(o))
			else:
				_walk_then(index, func(): fight.emit(o))
		"pass":
			_walk_then(index, func(): moved_on.emit(), true)
		_:
			_interact(o, index)

func _interact(o: Dictionary, index: int = 0) -> void:
	layer.get_child(0).visible = false
	# (set to the side of the line to its marker, so the knight walks on past it afterwards and not through it)
	_way = index
	var prop: Node3D
	if route:
		prop = await _route_interact(o, index)
		if not is_inside_tree():
			return
	else:
		var mx := 0.9
		if index < markers.size():
			mx = ((markers[index] as Vector3) - origin).rotated(Vector3.UP, -angle).x + 3.0
		var spot := _at(angle, Vector3(mx, 0, -2.4))
		prop = _shrine(spot) if o.type == "shrine" else backdrop.add_prop(o.type, spot)
		prop.rotation.y = angle
		if o.type == "shrine":
			backdrop.move_camera(spot + _rot(Vector3(2.0, 1.25, 3.7)), spot + Vector3(0, 1.25, 0))      # the whole monument, ring and all
		else:
			backdrop.move_camera(spot + _rot(Vector3(1.7, 1.3, 2.8)), spot + Vector3(0, 0.6, 0))
	var verb: String = {"treasure": "Open", "shrine": "Rest", "lever": "Pull"}[o.type]
	var l2 := CanvasLayer.new()
	add_child(l2)
	var b := UI.button(verb, 24, 220)
	if route:
		# (on the road the button is set beside the thing, never over it: see _place_action)
		var holder := UI.full(Control.new())
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l2.add_child(holder)
		holder.add_child(b)
		b.reset_size()
		_action = b
		_action_prop = prop
		if not prop.has_meta("kind"):
			prop.set_meta("kind", str(o.type))
		_place_action()
	else:
		var c := UI.full(CenterContainer.new())
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l2.add_child(c)
		c.add_child(b)
	b.modulate.a = 0.0
	create_tween().tween_property(b, "modulate:a", 1.0, 0.5).set_delay(0.9)
	b.pressed.connect(func():
		_action = null
		l2.queue_free()
		_resolve(o, prop))

## The wayside shrine: a monument of this kingdom's own, built here from turned stone. Three worn steps, a leaning
## six-sided stele banded where hands have polished it, the kingdom's ring cut from one stone and set in its head
## (the Ring-Gate, small enough to pray to), and inside the ring the light that Lyra says is not a candle: a rod of
## the old make that has burned for three hundred years. An offering bowl and the stones people left stand before it.
func _shrine(at: Vector3) -> Node3D:
	var n := Node3D.new()
	backdrop.props.add_child(n)
	n.position = at
	n.name = "Shrine"
	var stone := Look.stone(Color("#6a655c"))
	var worn := Look.stone(Color("#8a8478"), 0.5, 0.7)
	var dark := Look.stone(Color("#3c3a36"))
	var alloy := Look.flat(Color("#9aa0a8"), 0.3, 0.9)
	var fire := Color(backdrop.arena.theme.fire)
	var cyl := func(r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, sides: int = 12, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
		var m := CylinderMesh.new()
		m.top_radius = r_top
		m.bottom_radius = r_bot
		m.height = h
		m.radial_segments = sides
		m.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.position = pos
		mi.rotation = rot
		mi.material_override = mat
		n.add_child(mi)
		return mi
	# the steps, each a little off true
	cyl.call(0.98, 1.05, 0.14, Vector3(0, 0.07, 0), stone, 14)
	cyl.call(0.76, 0.8, 0.14, Vector3(0.02, 0.21, -0.02), worn, 14, Vector3(0, 0.3, 0))
	cyl.call(0.56, 0.6, 0.13, Vector3(0, 0.345, -0.05), stone, 12, Vector3(0, 0.7, 0))
	# the stele: six-sided, tapering, leaning a hand's width out of true
	var lean := Vector3(0.035, 0.52, -0.02)
	cyl.call(0.2, 0.3, 1.55, Vector3(0, 1.18, -0.12), stone, 6, lean)
	for band: Array in [[0.62, 0.3], [1.05, 0.262], [1.5, 0.235]]:
		cyl.call(float(band[1]), float(band[1]) + 0.012, 0.07, Vector3(0.0, float(band[0]), -0.12), worn if band[0] > 1.0 else dark, 6, lean)
	cyl.call(0.26, 0.21, 0.09, Vector3(0.03, 1.99, -0.12), dark, 6, lean)
	# the ring in its head, and a chip out of it where something struck
	var ring := TorusMesh.new()
	ring.inner_radius = 0.25
	ring.outer_radius = 0.37
	ring.rings = 28
	ring.ring_segments = 8
	var rm := MeshInstance3D.new()
	rm.mesh = ring
	rm.rotation = Vector3(PI * 0.5, 0, 0)
	rm.scale = Vector3(1, 0.55, 1)
	rm.position = Vector3(0.04, 2.36, -0.12)
	rm.material_override = worn
	n.add_child(rm)
	_tbox(n, Vector3(0.12, 0.1, 0.16), Vector3(0.3, 2.56, -0.12), dark, Vector3(0.3, 0.2, 0.7))
	# the light that is not a candle: a rod of the old make standing in the ring
	cyl.call(0.012, 0.016, 0.3, Vector3(0.04, 2.27, -0.12), alloy, 8)
	var flame := SphereMesh.new()
	flame.radius = 0.035
	flame.height = 0.11
	var fm := MeshInstance3D.new()
	fm.mesh = flame
	fm.position = Vector3(0.04, 2.46, -0.12)
	fm.material_override = Look.glow(fire.lerp(Color(1, 0.95, 0.85), 0.4), 4.0)
	n.add_child(fm)
	# what people left: a shallow bowl on the second step, and stones set down beside it
	cyl.call(0.2, 0.09, 0.1, Vector3(0.0, 0.33, 0.52), dark, 12)
	cyl.call(0.17, 0.17, 0.012, Vector3(0.0, 0.375, 0.52), Look.flat(Color("#1a1612"), 0.3, 0.2), 12)
	for st: Array in [[-0.42, 0.6, 0.09], [-0.3, 0.68, 0.06], [0.38, 0.62, 0.08], [0.5, 0.5, 0.05], [0.28, 0.72, 0.045]]:
		var sm := SphereMesh.new()
		sm.radius = float(st[2])
		sm.height = float(st[2]) * 1.3
		sm.radial_segments = 8
		sm.rings = 4
		var si := MeshInstance3D.new()
		si.mesh = sm
		si.position = Vector3(float(st[0]), 0.28 + float(st[2]) * 0.5, float(st[1]))
		si.material_override = worn if float(st[2]) > 0.07 else dark
		n.add_child(si)
	var l := OmniLight3D.new()
	l.light_color = fire.lerp(Color(1, 0.96, 0.9), 0.55)      # a small warm light, not a wash: the stone keeps its own grey
	l.light_energy = 0.7
	l.omni_range = 3.2
	l.position = Vector3(0.04, 2.4, 0.5)
	n.add_child(l)
	return n

func _resolve(o: Dictionary, prop: Node3D) -> void:
	var lines: Array = []
	var heading := ""
	if route:
		await _act(o, prop)           # the knight does it: lid, crank, the stone (and the gate rises with the crank)
		if not is_inside_tree():
			return
	match o.type:
		"treasure":
			if not route:
				create_tween().tween_property(prop.get_node("Lid"), "rotation:x", -1.9, 0.6).set_trans(Tween.TRANS_BACK)
			Sfx.play("loot", 0.0)
			var got := Game.open_treasure(o)
			heading = o.label
			for id in got.items:
				lines.append([Db.item(id).name, Db.rarity_color(Db.item(id))])
			if got.gold > 0:
				lines.append("%d gold" % got.gold)
			if got.shards > 0:
				lines.append("%d shard%s" % [got.shards, "" if got.shards == 1 else "s"])
			if lines.is_empty():
				lines.append("Already emptied.")
		"shrine":
			Sfx.play("levelup", -6.0, 0.8)
			var heal := Game.rest_at_shrine()
			heading = "Respite"
			lines.append("Wounds close.  +%d health" % int(heal))
		"lever":
			if prop.get_node_or_null("Arm"):
				create_tween().tween_property(prop.get_node("Arm"), "rotation:z", -0.6, 0.5).set_trans(Tween.TRANS_BACK)
				Sfx.play("guard_break", -8.0, 0.7)
			Game.pull_lever(o)
			if route and str(o.get("flag", "")) == "courtyard_gate":
				route.open_gate("inner")
				route.open_gate("postern", 4.0)
			heading = "A Way Opens"
			lines.append("%s will stay open." % Game.run_region().shortcut.label)
			lines.append("You may begin from here when you return.")
	await get_tree().create_timer(0.9).timeout
	Overlays.message(self, heading, lines, "Onward", func():
		if route and life and life.blocks(int(Game.run.stage)):
			_back_to_stop()           # the way on runs past whoever is still standing there: back to them first
		else:
			_walk_then(_way, func(): moved_on.emit(), true))

## The knight comes back out to the stop (from a room off it) and the stop is opened again with what is left there.
func _back_to_stop() -> void:
	var sp := CourtRoute.spot(int(Game.run.stage), _left_label)
	var back: Array = (sp.get("via", []) as Array).duplicate()
	back.reverse()
	back.append(origin)
	_walk_path(back, func():
		if is_inside_tree():
			_open_stop())

# ---------------------------------------------------------------- secrets (rules in Secrets, content in data/secrets.json)
## Something slightly off, set down in the place: small, unlabelled, and only yours if you notice it and touch it.
## A secret whose time has not come is either not there at all, or there and mute (`locked_text`).
func _place_secrets(frame: Control) -> void:
	for s: Dictionary in Secrets.at_stop(str(Game.run.region), int(Game.run.stage)):
		var kind := str(s.trigger.type)
		if kind == "wait":
			continue
		if not Secrets.open_now(s) and not s.has("locked_text"):
			continue
		if kind == "duel" and not Game.profile.tutorial_done:
			continue
		var places: Array = s.trigger.spots if kind == "sequence" else [{"tell": s.tell, "pos": s.pos}]
		for i: int in places.size():
			var at := _at(angle, Vector3(float(places[i].pos[0]) - 0.3, 0, float(places[i].pos[1])))
			var node := _tell_kept("%d|%s|%d" % [int(Game.run.stage), str(s.get("id", "")), i], str(places[i].tell), at)
			if frame == null:
				continue
			var b := Button.new()
			b.flat = true
			b.custom_minimum_size = Vector2(96, 96)
			b.size = Vector2(96, 96)
			b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			frame.add_child(b)
			frame.move_child(b, 0)
			var spot := {"node": node, "button": b, "secret": s, "index": i, "lamp": node.get_node_or_null("Lamp")}
			b.pressed.connect(func(): _touch(spot))
			spots.append(spot)
	# things that only speak when touched: the tell of something that is earned elsewhere
	for c: Dictionary in Secrets.clues_at(str(Game.run.region), int(Game.run.stage)):
		var node := _tell_kept("%d|clue|%s" % [int(Game.run.stage), str(c.get("tell", ""))], str(c.tell), _at(angle, Vector3(float(c.pos[0]) - 0.3, 0, float(c.pos[1]))))
		if frame == null:
			continue
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(96, 96)
		b.size = Vector2(96, 96)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		frame.add_child(b)
		frame.move_child(b, 0)
		var text := str(c.text)
		b.pressed.connect(func():
			if _quiet():
				_idle = 0.0
				_whisper(text))
		spots.append({"node": node, "button": b, "secret": {}, "index": 0, "lamp": node.get_node_or_null("Lamp"), "clue": true})

func _tbox(n: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	n.add_child(mi)
	return mi

## The thing itself, built from boxes and one faint light that breathes. Each is meant to read as part of the place
## at a glance and as wrong on a second look.
func _tell(kind: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	backdrop.props.add_child(n)
	n.position = at
	n.rotation.y = angle
	var stone := Look.stone(Color("#6a665e"))
	var pale := Look.stone(Color("#9a958a"))
	var dark := Look.flat(Color("#1c1a18"), 0.7)
	var wood := Look.flat(Color("#3a2a1c"), 0.85)
	var steel := Look.flat(Color("#9aa0a8"), 0.35, 0.9)
	var glow_c := Color(backdrop.arena.theme.fire)
	var lamp_at := Vector3(0, 0.35, 0.25)
	var lamp_e := 0.5
	match kind:
		"stone":
			# one flagstone paler than its neighbours, and not lying flat
			_tbox(n, Vector3(0.75, 0.05, 0.6), Vector3(0, 0.02, 0), stone)
			_tbox(n, Vector3(0.62, 0.07, 0.5), Vector3(0.02, 0.07, 0), pale, Vector3(0.07, 0.3, 0.05))
			_tbox(n, Vector3(0.5, 0.03, 0.03), Vector3(0, 0.045, 0.26), dark)
		"candle":
			glow_c = Color("#9fd0ff")
			_tbox(n, Vector3(0.3, 0.06, 0.3), Vector3(0, 0.03, 0), stone)
			_tbox(n, Vector3(0.06, 0.24, 0.06), Vector3(0, 0.18, 0), Look.flat(Color("#d8cfb8")))
			_tbox(n, Vector3(0.03, 0.06, 0.03), Vector3(0, 0.33, 0), Look.glow(glow_c, 3.0))
			lamp_at = Vector3(0, 0.45, 0)
			lamp_e = 0.9
		"scroll":
			_tbox(n, Vector3(0.45, 0.3, 0.35), Vector3(-0.26, 0.15, 0), stone, Vector3(0, 0.4, 0))
			_tbox(n, Vector3(0.4, 0.24, 0.3), Vector3(0.24, 0.12, 0.03), stone, Vector3(0, -0.3, 0.1))
			_tbox(n, Vector3(0.07, 0.07, 0.3), Vector3(0, 0.1, 0.1), Look.flat(Color("#c9b98f"), 0.9), Vector3(0.2, 0.2, 0))
			lamp_e = 0.35
		"lantern":
			# the one lantern on the road that is not lit
			_tbox(n, Vector3(0.07, 1.0, 0.07), Vector3(0, 0.5, 0), wood)
			_tbox(n, Vector3(0.3, 0.05, 0.05), Vector3(0.12, 0.98, 0), wood)
			_tbox(n, Vector3(0.16, 0.22, 0.16), Vector3(0.24, 0.82, 0), dark)
			_tbox(n, Vector3(0.08, 0.1, 0.08), Vector3(0.24, 0.82, 0), Look.flat(Color("#5a6a60"), 0.3))
			lamp_at = Vector3(0.24, 0.6, 0.2)
			lamp_e = 0.15
			glow_c = Color("#b6ff7a")
		"three_stones":
			for i: int in 3:
				_tbox(n, Vector3(0.3, 0.2, 0.26), Vector3((i - 1) * 0.42, 0.1, 0), dark if i == 1 else pale, Vector3(0, i * 0.5, 0.05))
			lamp_e = 0.3
		"blade":
			_tbox(n, Vector3(0.4, 0.22, 0.34), Vector3(0, 0.11, 0), stone, Vector3(0, 0.5, 0))
			_tbox(n, Vector3(0.05, 0.75, 0.012), Vector3(0, 0.55, 0), steel, Vector3(0, 0.6, 0.12))
			_tbox(n, Vector3(0.2, 0.03, 0.03), Vector3(0.03, 0.8, 0), dark, Vector3(0, 0.6, 0.12))
			lamp_at = Vector3(0.2, 0.7, 0.3)
			lamp_e = 0.45
			glow_c = Color("#dfe6f0")
		"ice":
			# a slab of black ice that shows the knight a little too well
			glow_c = Color("#8fdcff")
			var ice := Look.flat(Color("#0c141c"), 0.05, 0.6)
			_tbox(n, Vector3(1.0, 2.0, 0.14), Vector3(0, 1.0, 0), ice, Vector3(0.04, 0, 0))
			_tbox(n, Vector3(0.9, 1.9, 0.02), Vector3(0, 1.0, 0.08), Look.glow(Color("#16303f"), 0.5), Vector3(0.04, 0, 0))
			lamp_at = Vector3(0, 1.1, 0.7)
			lamp_e = 0.6
		"gaudy":
			# enormous, gilded, and propped where the looters left it
			var gilt := Look.flat(Color("#d9b84a"), 0.25, 1.0)
			_tbox(n, Vector3(0.5, 0.5, 0.4), Vector3(0.3, 0.25, -0.1), wood)
			_tbox(n, Vector3(0.2, 1.7, 0.04), Vector3(0, 0.95, 0), gilt, Vector3(0, 0, 0.3))
			_tbox(n, Vector3(0.7, 0.1, 0.1), Vector3(-0.42, 1.62, 0), gilt, Vector3(0, 0, 0.3))
			_tbox(n, Vector3(0.14, 0.14, 0.14), Vector3(-0.56, 2.0, 0), Look.flat(Color("#8a1f2a"), 0.2, 0.3), Vector3(0, 0, 0.3))
			lamp_at = Vector3(0, 1.2, 0.6)
			lamp_e = 0.5
			glow_c = Color("#ffe2a0")
		_:
			# marker posts, told apart by shape alone: tall, short, leaning, split
			var h := 1.5 if kind == "post_tall" else (0.6 if kind == "post_short" else 1.0)
			if kind == "post_split":
				_tbox(n, Vector3(0.07, h, 0.12), Vector3(-0.07, h * 0.5, 0), wood, Vector3(0, 0, 0.09))
				_tbox(n, Vector3(0.07, h, 0.12), Vector3(0.07, h * 0.5, 0), wood, Vector3(0, 0, -0.09))
			else:
				_tbox(n, Vector3(0.14, h, 0.14), Vector3(0.2 if kind == "post_lean" else 0.0, h * 0.48, 0), wood, Vector3(0, 0, -0.42 if kind == "post_lean" else 0.0))
			_tbox(n, Vector3(0.1, 0.06, 0.1), Vector3(0, 0.03, 0), dark)
			lamp_at = Vector3(0, minf(h, 0.9), 0.3)
			lamp_e = 0.0
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = glow_c
	lamp.light_energy = lamp_e
	lamp.omni_range = 1.8
	lamp.position = lamp_at
	lamp.set_meta("base", lamp_e)
	n.add_child(lamp)
	return n

func _quiet() -> bool:
	if layer == null or not is_instance_valid(layer):
		return false
	var ui: Control = layer.get_child(0)
	return ui.visible and ui.modulate.a > 0.95 and not _leaving and not _staging and (not Story.busy or _aside)

func _tick_secrets(dt: float) -> void:
	_clock += dt
	for e: Dictionary in spots:
		if not is_instance_valid(e.node):
			continue
		var p: Vector3 = e.node.global_position + Vector3(0, 0.35, 0)
		e.button.visible = not backdrop.cam.is_position_behind(p)
		e.button.position = backdrop.cam.unproject_position(p) - e.button.size * 0.5 - e.button.get_parent().global_position
		if e.lamp != null and not e.has("lit"):
			e.lamp.light_energy = float(e.lamp.get_meta("base")) * (0.65 + 0.35 * sin(_clock * 1.3 + float(e.index)))
	if not _quiet() or Game.run.is_empty():      # (the road has just been left: Turn Back empties the run while this stop fades out)
		return
	_idle += dt
	# some places only answer someone who stays
	for s: Dictionary in Secrets.at_stop(str(Game.run.region), int(Game.run.stage)):
		if str(s.trigger.type) == "wait" and _idle >= float(s.trigger.seconds) and Secrets.open_now(s):
			_discover(s, _at(angle, Vector3(-0.3, 0.6, -5.5)), false)
			return

func _touch(spot: Dictionary) -> void:
	if not _quiet():
		return
	_idle = 0.0
	var s: Dictionary = spot.secret
	if not Secrets.open_now(s):
		_whisper(str(s.get("locked_text", "")))
		return
	match str(s.trigger.type):
		"sequence":
			var so_far: Array = _order.get(s.id, [])
			var order: Array = s.trigger.order
			if int(order[so_far.size()]) == int(spot.index):
				so_far.append(spot.index)
				_order[s.id] = so_far
				spot["lit"] = true
				Sfx.play("levelup", -14.0, 1.0 + 0.12 * so_far.size())
				create_tween().tween_property(spot.lamp, "light_energy", 1.4, 0.4)
				if so_far.size() == order.size():
					_discover(s, spot.node.position)
			else:
				# wrong: they go dark, and it starts again
				_order[s.id] = []
				Sfx.play("guard_break", -16.0, 0.6)
				for e: Dictionary in spots:
					if e.secret == s:
						e.erase("lit")
				_whisper("It goes cold under your hand. Not that one, not yet.")
		"duel":
			_challenge(s, spot.node.position)
		_:
			_discover(s, spot.node.position)

## A line of plain text over the prompt, for a thing that will not answer yet.
func _whisper(text: String) -> void:
	if text == "":
		return
	var l := UI.label(text, 19, UI.DIM.lightened(0.3))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 760
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.offset_top = 150
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	prompt.get_parent().get_parent().add_child(l)
	l.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.0 + text.length() / 30.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

## The camera eases over to what was noticed, a light comes up on it, one of the companions says a line (subtitle
## only: none of these lines is recorded), and what it was is named.
func _discover(s: Dictionary, at: Vector3, close: bool = true) -> void:
	if _staging or _leaving:
		return
	_staging = true
	if _aside:
		_aside = false
		Story.stop()
	_idle = 0.0
	var ui: Control = layer.get_child(0)
	create_tween().tween_property(ui, "modulate:a", 0.0, 0.3)
	var keep_pos := backdrop.cam_pos
	var keep_look := backdrop.cam_look
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffcf8a")
	lamp.light_energy = 0.0
	lamp.omni_range = 3.0
	lamp.position = Vector3(at.x, 0.9, at.z)
	backdrop.props.add_child(lamp)
	if close:
		var from := backdrop.cam_pos - at
		from.y = 0.0
		from = from.normalized()
		backdrop.move_camera(at + from * 2.4 + Vector3(0, 1.05, 0), at + Vector3(0, 0.3, 0))
	else:
		backdrop.move_camera(backdrop.cam_pos + (at - backdrop.cam_pos) * 0.12, at)
	Sfx.play("levelup", -12.0, 0.7)
	create_tween().tween_property(lamp, "light_energy", 1.8, 1.0)
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree():
		return
	var got := Game.find_secret(str(s.id))
	var scene := Secrets.line_scene(s)
	if scene != "":
		Companion.mark_heard(scene)
		await Story.play(scene, true)
		if not is_inside_tree():
			return
	if not got.is_empty():
		Sfx.play("loot", -4.0)
		await _banner(got)
		if not is_inside_tree():
			return
	for e: Dictionary in spots.duplicate():
		if e.secret == s:
			e.button.queue_free()
			spots.erase(e)
	if hp_bar != null and not Game.run.is_empty():
		hp_bar.value = Game.run.hp
	var out := create_tween()
	out.tween_property(lamp, "light_energy", 0.0, 0.8)
	out.tween_callback(lamp.queue_free)
	backdrop.move_camera(keep_pos, keep_look)
	create_tween().tween_property(ui, "modulate:a", 1.0, 0.6).set_delay(0.5)
	_staging = false

## Names what was found and what it gave, at the top of the screen, and goes.
func _banner(got: Dictionary) -> void:
	var l2 := CanvasLayer.new()
	l2.layer = 5
	add_child(l2)
	# a dark plate behind the words: the place behind them is too busy to read against
	var plate := UI.panel(Color(0.02, 0.02, 0.03, 0.8), UI.GOLD_DIM)
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.offset_top = 56
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l2.add_child(plate)
	var pad := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 18 if side in ["left", "right"] else 10)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(pad)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(v)
	var parts: Array = [UI.label("A SECRET OF THE ROAD", 14, UI.GOLD_DIM.lightened(0.35), "bold"), UI.title(str(got.name), 32, UI.GOLD),
		UI.wrapped(str(got.found), 19, UI.BONE, 760)]
	for line in got.lines:
		parts.append(UI.label(str(line), 17, UI.GOLD_DIM.lightened(0.4)))
	for c: Label in parts:
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		c.add_theme_constant_override("shadow_offset_y", 2)
		v.add_child(c)
	plate.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(plate, "modulate:a", 1.0, 0.5)
	tw.tween_interval(3.6)
	tw.tween_property(plate, "modulate:a", 0.0, 0.7)
	tw.tween_callback(l2.queue_free)
	await tw.finished

## A hidden duel: the camera goes to what was touched, the line is said, and steel is drawn through the same door
## as any fight on the road. Winning it finds the secret; the road is where it was afterwards.
func _challenge(s: Dictionary, at: Vector3) -> void:
	if _staging or _leaving:
		return
	_staging = true
	if _aside:
		_aside = false
		Story.stop()
	create_tween().tween_property(layer.get_child(0), "modulate:a", 0.0, 0.3)
	var from := backdrop.cam_pos - at
	from.y = 0.0
	backdrop.move_camera(at + from.normalized() * 3.2 + Vector3(0, 1.3, 0), at + Vector3(0, 1.0, 0))
	Sfx.play("armor", -6.0, 0.7)
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	var scene := Secrets.line_scene(s)
	if scene != "":
		Companion.mark_heard(scene)
		await Story.play(scene, true)
		if not is_inside_tree():
			return
	_leaving = true
	arrive = {}              # a hidden duel comes back to this very stop
	fight.emit(Secrets.duel_option(s))

## Dev captures: find the named secret of this stop after `after` seconds, as a touch would.
func dev_tap(id: String, after: float) -> void:
	await get_tree().create_timer(after).timeout
	while is_inside_tree() and not _quiet():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	for e: Dictionary in spots:
		if str(e.secret.get("id", "")) == id and str(e.secret.trigger.type) != "sequence":
			_touch(e)
			return
	if Secrets.by_id.has(id):
		_discover(Secrets.by_id[id], _at(angle, Vector3(-0.3, 0.6, -5.5)), false)

## What is worth the Witness's curiosity at this stop: each way onward, and anything hidden that can be touched.
func _witness_points() -> Array:
	var pts: Array = markers.duplicate()
	for e: Dictionary in spots:
		var n = e.get("node")
		if n is Node3D and is_instance_valid(n):
			pts.append((n as Node3D).global_position if (n as Node3D).is_inside_tree() else (n as Node3D).position)
	return pts

# ================================================================ the continuous Courtyard (docs/TRAVERSAL_PLAN.md)
## In the Courtyard the road is one place (src/world/court_route.gd): this screen builds it once, stands the knight
## at the anchor of `Game.run.stage` (or walks them in, see `arrive`), and from then on walks them along the road
## from stop to stop at FighterRig.ROAD_SPEED with the camera behind them. A stop is where the walk pauses for the
## choices; nothing is rebuilt and nothing fades between stops. Other regions keep the stop-by-stop screen above.

## How the next road screen of the Courtyard begins (set before the screen is made, emptied when it is read):
## {} at the anchor of run.stage (Retry, Continue, a hidden duel's return); {"intro": true} out of the door on the
## hillside; {"shortcut": true} through the winch gate; {"from": stage, "label": way, "at": where} on from the place
## a fight was won.
static var arrive := {}
signal _path_done
var route: CourtRoute
var origin := Vector3.ZERO        # the stop's anchor (the old screens stand at the world's origin)
var _left_label := ""             # the way the knight took from this stop
var _staged := {}                 # "stage|option index" -> the foe standing there (hidden until out of sight)
var _want := {}                   # "stage|option index" -> this stop's foe slot waiting for one still being read
var _props := {}                  # "stage|label" -> the chest, lever or shrine standing in the place
var _left_foes: Array = []        # foes of stops already left (they stay where they stood)
var _path := PackedVector3Array()
var _path_cum := PackedFloat32Array()
var _path_d := 0.0
var _path_then := Callable()
var _cam_yaw := 0.0
var _interacted := false          # the knight has just used a chest, the winch or the shrine (see _walk_path)
var _snap_cam := false
var _cam_side := 1.0               # which shoulder the road camera is over (1: the sword side)
var _cam_x := 1.0
var _walking_in := false
var _cost_t := 0.0
var _cost := false
var _occl_was := false
var walked := 0.0                 # metres walked on this screen (tests, the report)
var _path_then_is_interaction := false
var life: RouteLife               # who lives on the road (Stage 3B): every foe in the place from the start
var meeting := {}                 # the fight met on the road, while it is fought there: {stage, foe, xf, arena}
var _in_duel := false             # this screen is held under a duel fought where it was met (Main.parked)
var _meet_cam := false            # the camera is watching a meeting, not following the walk
var _meet_foe: Node3D
var _shake := 0.0
var _room := {}                   # the authored camera of a room the knight is in (guardhouse, murder hole)
var _reach: RouteKit.Reach

## Whether this road is walked as one continuous place: the Courtyard, with its kit present, the filmed road off.
static func continuous() -> bool:
	return not Game.run.is_empty() and str(Game.run.get("region", "")) == "courtyard" and CourtRoute.available() \
		and not (Game.settings.cine_road and CineRoad.available("courtyard"))

func _route_ready() -> void:
	var stage: int = int(Game.run.stage)
	_cost = OS.get_cmdline_user_args().has("--routecost")
	angle = CourtRoute.anchor_yaw(stage)
	origin = CourtRoute.anchor(stage)
	var how: Dictionary = arrive
	arrive = {}
	var start := origin
	var leg: Array = []
	if how.has("intro") and stage == 0:
		start = CourtRoute.ENTRY      # HOOK(Stage 1): the chamber's exit passage ends here
		leg = CourtRoute.leg_points(-1, "intro")
	elif how.has("shortcut"):
		start = CourtRoute.SHORTCUT_IN
		leg = CourtRoute.leg_points(-1, "shortcut")
	elif how.has("from") and int(how.from) == stage - 1:
		start = how.at
		leg = CourtRoute.leg_points(stage - 1, str(how.label))
	route = CourtRoute.new()
	route.name = "Route"
	backdrop = route.make_backdrop()
	add_child(backdrop)
	route.setup(start)
	backdrop.refresh_knight()
	_knight_setup()
	backdrop.cam.make_current()
	_occl_was = get_viewport().use_occlusion_culling
	get_viewport().use_occlusion_culling = true
	_world_props()
	var rig := backdrop.rig
	rig.position = Vector3(start.x, CourtRoute.ground_y(start.x, start.z), start.z)
	# everyone the road will meet from here is in the place now, where they were left (the screen opens behind a
	# transition; each is shown with the section it stands in)
	life = RouteLife.new(self)
	add_child(life)
	life.setup(stage)
	_pouches_all()
	_tells_all()
	if leg.is_empty():
		rig.rotation.y = angle
		backdrop.cam_fov = 50.0
		backdrop.move_camera(_at(angle, CAM_POS), _at(angle, CAM_LOOK), true)
		_open_stop()
		return
	if leg.size() > 1 and Vector2(start.x, start.z).distance_to(Vector2(leg[0].x, leg[0].z)) < 0.8:
		leg.pop_front()
	var first: Vector3 = leg[0]
	rig.rotation.y = atan2(-(first.x - start.x), -(first.z - start.z))
	if how.has("knight_yaw"):
		rig.rotation.y = float(how.knight_yaw)
	_cam_yaw = rig.rotation.y
	var b := Basis(Vector3.UP, _cam_yaw)
	backdrop.cam_fov = 48.0
	if how.has("from_chamber"):
		# Stage 1's hand-off: the framing the chamber's passage ended on (behind, close, a little high), out in daylight
		backdrop.cam_fov = 50.0
		backdrop.move_camera(rig.position + b * Vector3(0.3, 1.8, 2.7), rig.position + b * Vector3(0.0, 1.35, -3.0), true)
	else:
		backdrop.move_camera(rig.position + b * Vector3(0.9, 1.6, 3.9), rig.position + b * Vector3(-0.2, 1.3, -3.0), true)
	# the Witness comes out of the passage with the knight: it keeps its place and its motion (WitnessDrone.continue_from)
	var w0 = how.get("witness")
	if w0 is WitnessDrone and is_instance_valid(w0) and rig.drone != null:
		rig.drone.continue_from(w0)
		rig.drone.global_position = how.get("witness_at", rig.drone.global_position)
	Sfx.ambience(str(Game.run_region().amb))
	Sfx.music_for("explore_courtyard", "menu", 2.5)
	_walking_in = true
	_walk_path(leg, func():
		_walking_in = false
		# the line spoken on the way out (the Awakening's) is let finish before the choices come up
		var left := 14.0
		while Story.busy and left > 0.0 and is_inside_tree():
			await get_tree().process_frame
			left -= get_process_delta_time()
		if is_inside_tree():
			_open_stop())

func _exit_tree() -> void:
	if route and is_inside_tree():
		get_viewport().use_occlusion_culling = _occl_was

## The knight stands on the place's own ground (feet, slope, what is underfoot).
func _knight_setup() -> void:
	if route == null or backdrop.rig == null:
		return
	backdrop.rig.ground = CourtRoute.ground_y
	backdrop.rig.surface_id = CourtRoute.surface_at(backdrop.rig.position)

## Ends the walk in (dev captures, tests, a player who taps SKIP): the knight is put at the stop.
func skip() -> void:
	if not _path.is_empty():
		Story.stop()
		_path_d = _path_cum[_path_cum.size() - 1]

## The road is walked on to the stop `Game.run.stage` (already advanced by the router) by the way just taken.
func travel() -> void:
	var stage: int = int(Game.run.stage)
	var leg := CourtRoute.leg_points(stage - 1, _left_label)
	angle = CourtRoute.anchor_yaw(stage)
	origin = CourtRoute.anchor(stage)
	if layer:
		create_tween().tween_property(layer.get_child(0), "modulate:a", 0.0, 0.4)
	_walk_path(leg, _open_stop)

## What the last stop left on the screen is taken away (its foes stay standing where they were).
func _reset_stop() -> void:
	Game.save()
	if layer and is_instance_valid(layer):
		layer.queue_free()
	for c: Node in backdrop.props.get_children():
		if c.has_meta("stop_ui"):
			c.queue_free()
	for e: Array in pouches:
		if is_instance_valid(e[0]) and not route:
			e[0].queue_free()            # (on the road a pouch not taken stays lying where it lay)
	for sp: Dictionary in spots:
		if is_instance_valid(sp.get("node")) and not route:
			sp.node.queue_free()        # (on the road what is lying about stays where it lies)
	for f in foes:
		if f != null and is_instance_valid(f):
			_left_foes.append(f)
	markers.clear()
	pouches.clear()
	spots.clear()
	foes.clear()
	_want.clear()
	_order.clear()
	_idle = 0.0
	_aside = false
	_staging = false
	if _cost:
		get_tree().create_timer(2.5).timeout.connect(func():
			if is_inside_tree():
				print("ROUTECOST stop %d at %s: %s" % [int(Game.run.stage) + 1, str(backdrop.rig.position.snapped(Vector3.ONE * 0.1)), CourtRoute.cost_line()]))

## Walks the knight from where they are through `points` (world; heights are the ground's), then calls `then`.
func _walk_path(points: Array, then: Callable) -> void:
	_leaving = true
	var rig := backdrop.rig
	var pts: Array = [rig.position]
	pts.append_array(points)
	pts = _around(pts)
	if not _room.is_empty():
		_interacted = false
	_path = CourtRoute.path(pts)
	_path_cum = PackedFloat32Array()
	var d := 0.0
	_path_cum.append(0.0)
	for i in _path.size() - 1:
		d += _path[i].distance_to(_path[i + 1])
		_path_cum.append(d)
	_path_d = 0.0
	_path_then = then
	_cam_yaw = rig.rotation.y if _walk.is_empty() else _cam_yaw
	if _interacted and _path.size() > 4 and _room.is_empty():
		# walking away from a thing just used: the camera is put behind the way out at once rather than swung round
		# through the walls to get there (a room keeps its own camera until the knight is out of it: _room_cam_tick)
		_interacted = false
		var d0 := _path[mini(8, _path.size() - 1)] - _path[0]
		_cam_yaw = atan2(-d0.x, -d0.z)
		_snap_cam = true
	rig.walking = true
	rig.footsteps = true
	_walk = {"u": 0.0}

func _sample(d: float) -> Vector3:
	var n := _path_cum.size()
	if n == 0:
		return backdrop.rig.position
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _path_cum[mid] <= d:
			lo = mid
		else:
			hi = mid
	var seg := maxf(_path_cum[hi] - _path_cum[lo], 0.0001)
	return _path[lo].lerp(_path[hi], clampf((d - _path_cum[lo]) / seg, 0.0, 1.0))

func _route_tick(dt: float) -> void:
	if backdrop == null or backdrop.rig == null:
		return
	var rig := backdrop.rig
	if not _path.is_empty():
		var total: float = _path_cum[_path_cum.size() - 1]
		var step := FighterRig.ROAD_SPEED * dt
		_path_d = minf(_path_d + step, total)
		walked += step
		var p := _sample(_path_d)
		var ahead := _sample(minf(_path_d + 1.1, total))
		rig.position = p
		var dir := ahead - p
		if Vector2(dir.x, dir.z).length() > 0.05:
			rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-dt * 4.5))
		_walk.u = _path_d / maxf(total, 0.01)
		rig.surface_id = CourtRoute.surface_at(p)
		if _cost:
			_cost_t += dt
			if _cost_t > 2.0:
				_cost_t = 0.0
				print("ROUTECOST walk at %s (section %d): %s" % [str(p.snapped(Vector3.ONE * 0.1)), route.zone, CourtRoute.cost_line()])
		if _path_d >= total:
			_path = PackedVector3Array()
			_path_cum = PackedFloat32Array()
			rig.walking = false
			_walk = {}
			if not _meet_cam and _room.is_empty() and not _path_then_is_interaction:
				# the knight settles facing the way the stop looks
				create_tween().tween_property(rig, "rotation:y", rig.rotation.y + wrapf(angle - rig.rotation.y, -PI, PI), 0.8).set_trans(Tween.TRANS_SINE)
				backdrop.cam_speed = 0.8
				create_tween().tween_property(backdrop, "cam_speed", 1.6, 3.0)
				backdrop.move_camera(_at(angle, CAM_POS), _at(angle, CAM_LOOK))
			var then := _path_then
			_path_then = Callable()
			_path_done.emit()
			if then.is_valid():
				then.call()
	route.update(rig.position)
	if life:
		life.tick(dt, rig.position)
		if _want.has("fight") and int(_want.fight) < foes.size() and life.foe_at(int(Game.run.stage)) != null:
			foes[int(_want.fight)] = life.foe_at(int(Game.run.stage))
			_want.erase("fight")

## Whether a figure standing at `p` would be seen from the camera now (in the frame, near enough, nothing between).
func _seen(p: Vector3) -> bool:
	var cam := backdrop.cam
	var head := p + Vector3(0, 1.3, 0)
	if cam.global_position.distance_to(head) > 90.0:
		return false
	if not cam.is_position_in_frustum(head) and not cam.is_position_in_frustum(p + Vector3(0, 0.2, 0)):
		return false
	return not _blocked(head) or not _blocked(p + Vector3(0, 0.4, 0))

func _blocked(p: Vector3) -> bool:
	return not CamFollow.sight_clear(backdrop.rig, [p], backdrop.cam.global_position)

## The camera that walks with the knight down the road: behind and to the sword side, a little above, looking ahead
## along the way; it comes round behind a turn slowly, and in front of anything that would come between.
func _route_cam() -> void:
	var rig := backdrop.rig
	var dt := get_process_delta_time()
	_cam_yaw = lerp_angle(_cam_yaw, rig.rotation.y, 1.0 - exp(-dt * 1.4))
	var b := Basis(Vector3.UP, _cam_yaw)
	var u: float = float(_walk.get("u", 0.0)) if not Game.settings.reduce_motion else 0.0
	var head := rig.position + Vector3(0, 1.6 * rig.scale.y, 0)
	var pts: Array = [head, rig.position + Vector3(0, 1.15 * rig.scale.y, 0)]
	# the sword side by default; where a wall stands close on that side (the wall-walk, the passage) the camera goes
	# over to the other shoulder, slowly, and comes back only when the sword side is clearly open again
	var want_side := _cam_side
	var right := CamFollow.clear_from(rig, pts, rig.position + b * Vector3(1.05, 1.6, 3.9), 0.9)
	var left := CamFollow.clear_from(rig, pts, rig.position + b * Vector3(-1.05, 1.6, 3.9), 0.9)
	if _cam_side > 0.0 and right < 0.7 and left > right + 0.2:
		want_side = -1.0
	elif _cam_side < 0.0 and right > 0.95:
		want_side = 1.0
	_cam_side = want_side
	_cam_x = lerpf(_cam_x, _cam_side, 1.0 - exp(-get_process_delta_time() * 1.2))
	var eye := rig.position + b * Vector3((1.05 - 0.3 * u) * _cam_x, 1.55 + 0.15 * u, 3.9)
	var look := rig.position + b * Vector3(-0.25 * _cam_x, 1.25, -3.2)
	backdrop.cam_fov = 48.0
	backdrop.cam_speed = 2.4
	var clear := CamFollow.clear_from(rig, pts, eye, 0.9)
	_cam_pull = lerpf(_cam_pull, clear, 0.5 if clear < _cam_pull else 0.03)
	eye = head.lerp(eye, _cam_pull)
	if _cam_pull < 0.98:
		# (in a tight place the glide itself would carry the lens through the wall it is avoiding: it is all but set)
		backdrop.cam_speed = 7.0 if _cam_pull > 0.8 else 24.0
	backdrop.move_camera(eye, look, _snap_cam)
	_snap_cam = false

## A point in the frame of another stop of the road.
static func _frame_at(stage: int, v: Vector3) -> Vector3:
	return CourtRoute.anchor(stage) + v.rotated(Vector3.UP, CourtRoute.anchor_yaw(stage))

static func _options_at(stage: int) -> Array:
	var keep: int = int(Game.run.stage)
	Game.run.stage = stage
	var o: Array = Game.stage_options()
	Game.run.stage = keep
	return o

static func _marker_x(opts: Array, i: int) -> float:
	var x := (float(i) - (opts.size() - 1) * 0.5) * 3.2
	if opts[i].has("foe"):
		x = clear_x(x - 0.3) + 0.3
	return x - 0.3

## The foes of a stop of the road are stood where they will be met, before the knight gets there: at once when `now`
## (the screen is being opened behind a transition), otherwise hidden until the place is out of the camera's sight.
func _stage_foes(stage: int, now: bool) -> void:
	var n: int = Game.run_region().stages.size()
	if stage < 0 or stage >= n:
		return
	var opts := _options_at(stage)
	for i in opts.size():
		var o: Dictionary = opts[i]
		var key := "%d|%d" % [stage, i]
		if _staged.has(key) or o.type != "fight" or not o.has("foe") or not Db.foes.has(str(o.foe)):
			continue
		if str(Db.foes[str(o.foe)].rig.get("kind", "")) == "dragon":
			continue
		_staged[key] = null
		var fx: float = float(CourtRoute.FOE_X.get(stage, _marker_x(opts, i))) if i == 0 else _marker_x(opts, i)
		var at := _frame_at(stage, Vector3(fx, 0, -4.6 - FOE_BEYOND))
		at.y = CourtRoute.ground_y(at.x, at.z)
		var yaw := CourtRoute.anchor_yaw(stage) + PI
		var foe_id := str(o.foe)
		_read_ahead(CineActor.foe_files(foe_id), func():
			if not is_inside_tree() or backdrop == null:
				return
			var f := FighterRig.new()
			backdrop.props.add_child(f)
			f.build(CineActor.foe_look(foe_id), true)
			f.position = at
			f.rotation.y = yaw
			f.time_scale = 0.6
			f.ground = CourtRoute.ground_y
			f.visible = now or not _seen(at)
			_staged[key] = f
			if _want.has(key) and stage == int(Game.run.stage) and int(_want[key]) < foes.size():
				foes[int(_want[key])] = f
				f.visible = true
				_want.erase(key))

## The chests, levers and the shrine of the whole road stand in the place from the start, opened or pulled already
## if they were; using one walks the knight to it.
func _world_props() -> void:
	var n: int = Game.run_region().stages.size()
	for i in n:
		var opts := _options_at(i)
		var raw: Array = Game.run_region().stages[i].options
		var seen := {}
		var list: Array = []
		for j in opts.size():
			list.append([opts[j], j, opts.size(), opts])
		for o2: Dictionary in raw:
			list.append([o2, -1, 0, []])
		for e: Array in list:
			var o: Dictionary = e[0]
			if not o.type in ["treasure", "lever", "shrine"] or seen.has(str(o.label)):
				continue
			var sp := CourtRoute.spot(i, str(o.label))
			if int(e[1]) < 0 and sp.is_empty():
				continue
			seen[str(o.label)] = true
			var at: Vector3
			var face := CourtRoute.anchor_yaw(i)
			if not sp.is_empty():
				at = sp.prop
				face = atan2(sp.stand.x - at.x, sp.stand.z - at.z)
			else:
				at = _frame_at(i, Vector3(_marker_x(e[3], int(e[1])) + 3.0, 0, -2.4))
			at.y = CourtRoute.ground_y(at.x, at.z)
			var prop: Node3D
			match str(o.type):
				"shrine": prop = _shrine(at)
				"treasure": prop = RouteKit.chest(backdrop.props, route.arena, at)
				"lever":
					if str(o.get("flag", "")) == "courtyard_gate":
						prop = RouteKit.winch(backdrop.props, route.arena, at, Vector3(-10.0, 7.6, -144.5))
						face = 0.0
					else:
						prop = backdrop.add_prop("lever", at)
			prop.set_meta("kind", str(o.type))
			prop.rotation.y = face
			var keep: int = int(Game.run.stage)
			Game.run.stage = i
			var looted: bool = o.type == "treasure" and Game.profile.get("flags", {}).has(Game._chest_flag(o))
			Game.run.stage = keep
			if looted and prop.get_node_or_null("Lid"):
				prop.get_node("Lid").rotation.x = -1.9
			if o.type == "lever" and Game.profile.get("flags", {}).has(str(o.get("flag", ""))) and prop.get_node_or_null("Arm"):
				prop.get_node("Arm").rotation.z = -0.6
			_props["%d|%s" % [i, str(o.label)]] = prop

## Using a chest, a lever or the shrine of the road: the knight walks to it (into the guardhouse, through the gap
## into the murder hole), the camera frames it, and the thing standing there is the one that is used.
func _route_interact(o: Dictionary, index: int) -> Node3D:
	var stage: int = int(Game.run.stage)
	var key := "%d|%s" % [stage, str(o.label)]
	var prop: Node3D = _props.get(key)
	var sp := CourtRoute.spot(stage, str(o.label))
	if prop == null or not is_instance_valid(prop):
		var mx := 0.9
		if index < markers.size():
			mx = ((markers[index] as Vector3) - origin).rotated(Vector3.UP, -angle).x + 3.0
		var at := _at(angle, Vector3(mx, 0, -2.4))
		prop = _shrine(at) if o.type == "shrine" else backdrop.add_prop(str(o.type), at)
		prop.rotation.y = angle
		_props[key] = prop
	var stand: Vector3 = sp.stand if not sp.is_empty() else prop.global_position + _rot(Vector3(-0.2, 0, 1.3))
	var via: Array = sp.get("via", [])
	var walk: Array = via.duplicate()
	walk.append(stand)
	# the Witness goes on ahead to look at it; a room's own camera takes the knight once they are over its threshold
	_witness_inspect(prop.global_position + Vector3(0, 0.9, 0), 4.0)
	if sp.has("room"):
		_room = (sp.room as Dictionary).duplicate()
		_room["stand"] = stand
	_path_then_is_interaction = true
	_walk_path(walk, Callable())
	await _path_done
	_path_then_is_interaction = false
	if not is_inside_tree():
		return prop
	_leaving = false
	_interacted = true
	var to := prop.global_position - backdrop.rig.position
	create_tween().tween_property(backdrop.rig, "rotation:y", backdrop.rig.rotation.y + wrapf(atan2(-to.x, -to.z) - backdrop.rig.rotation.y, -PI, PI), 0.6)
	if not _room.is_empty():
		return prop                   # (the room's camera already has them both)
	var back := (stand - prop.global_position)
	back.y = 0.0
	back = back.normalized()
	var side := back.rotated(Vector3.UP, PI * 0.5)
	var tall: bool = o.type == "shrine"
	var p0 := prop.global_position
	# from beside the knight, never through them: of the two sides, the one whose line to the thing passes furthest
	# from the knight's chest, then brought in front of any wall
	var chest := backdrop.rig.position + Vector3(0, 1.2, 0)
	var eye := Vector3.ZERO
	var best := -1.0
	for sgn: float in [1.0, -1.0]:
		var e2 := p0 + back * (3.0 if tall else 2.7) + side * sgn * (1.6 if tall else 1.9) + Vector3(0, 1.5 if tall else 1.55, 0)
		var look := p0 + back * 0.8 + Vector3(0, 1.1, 0)      # (just in front of the thing, or it would block its own view)
		var seg := e2 - look
		var t := clampf((chest - look).dot(seg) / seg.length_squared(), 0.0, 1.0)
		var gap := (look + seg * t).distance_to(chest)
		var c2 := CamFollow.clear_from(backdrop.rig, [look], e2, 0.9)
		var score := gap * 2.0 + c2
		if score > best:
			best = score
			eye = look.lerp(e2, c2)
	backdrop.cam_speed = 1.6
	backdrop.move_camera(eye, p0 + Vector3(0, 1.25 if tall else 0.6, 0))
	return prop

# ================================================================ Stage 3B: meeting them, fighting where they meet
## A fight on the road is met where its foe is: the foe comes as itself (RouteLife.meet: off its line, out of its door,
## through its barricade, up from where it sat), the knight walks up to where it will stand, the camera watches from
## over the knight's shoulder, and the duel opens on that very spot (Main.start_duel with `meeting`, Duel.place).
func _meet_then(index: int, o: Dictionary) -> void:
	if _leaving:
		return
	_leaving = true
	create_tween().tween_property(layer.get_child(0), "modulate:a", 0.0, 0.3)
	var st := int(Game.run.stage)
	var foe_id := str(o.foe)
	var so: Array = Duel.stand_off(Db.foes[foe_id])
	var fr := CourtRoute.duel_frame(CourtRoute.encounter(st, foe_id), float(so[0]), float(so[1]))
	var rig := backdrop.rig
	_meet_foe = foes[index]
	_meet_cam = true
	backdrop.cam_speed = 1.6
	_witness_inspect(_meet_foe.global_position + Vector3(0, 1.4, 0), 3.0)
	var done := {"foe": false}
	(func():
		await life.meet(st, fr.foe, rig)
		done.foe = true).call()
	_walk_path([fr.knight], Callable())
	await _path_done
	if not is_inside_tree():
		return
	# the knight squares up to them
	create_tween().tween_property(rig, "rotation:y", rig.rotation.y + wrapf(float(fr.yaw) - rig.rotation.y, -PI, PI), 0.5).set_trans(Tween.TRANS_SINE)
	var left := 40.0
	while not done.foe and left > 0.0 and is_inside_tree():
		await get_tree().process_frame
		left -= get_process_delta_time()
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return
	meeting = {"stage": st, "foe": foe_id, "xf": fr.xf, "arena": route.arena}
	fight.emit(o)

## Over the knight's shoulder, onto whoever is coming: both in the frame, the foe on the far side of it.
func _meet_cam_tick(dt: float) -> void:
	var rig := backdrop.rig
	var f := _meet_foe
	if f == null or not is_instance_valid(f):
		return
	var to := f.global_position - rig.position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.2 else -rig.global_transform.basis.z
	var side := Vector3(-dir.z, 0, dir.x)
	var head := rig.position + Vector3(0, 1.6, 0)
	var far := clampf(to.length() / 10.0, 0.0, 1.0)
	var eye := rig.position - dir * (3.1 + far) + side * 1.15 + Vector3(0, 1.7 + 0.4 * far, 0)
	var big := maxf(f.scale.y, 1.0)
	var clear := CamFollow.clear_from(rig, [head, rig.position + Vector3(0, 1.1, 0)], eye, 0.9)
	eye = head.lerp(eye, clear)
	var look := rig.position.lerp(f.global_position, 0.6) + Vector3(0, 1.2 * big, 0)
	_shake = maxf(0.0, _shake - dt * 1.6)
	var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.08
	backdrop.cam_fov = 46.0
	backdrop.cam_speed = 2.2
	backdrop.move_camera(eye + off, look + off * 0.5)

## A jolt of the camera (something heavy gave way near by).
func shake_cam(amount: float) -> void:
	_shake = maxf(_shake, amount)

## Held under the duel fought here (Main.start_duel): the duel's own figures stand where these two stood.
func park() -> void:
	_in_duel = true
	_meet_cam = false
	if layer and is_instance_valid(layer):
		layer.visible = false
	backdrop.rig.visible = false
	if _meet_foe and is_instance_valid(_meet_foe):
		_meet_foe.visible = false

## Back from a duel won here: the fallen foe stays where it fell, the knight walks on from where it stood, the
## Witness from where it was, the camera from where the duel's was.
func unpark(d: Node) -> void:
	_in_duel = false
	var st := int(meeting.get("stage", int(Game.run.stage) - 1))
	var foe_id := str(meeting.get("foe", ""))
	meeting = {}
	var rig := backdrop.rig
	if d is Duel and is_instance_valid(d):
		var du: Duel = d
		life.lay_down(st, du.foe_rig, foe_id)
		rig.global_position = du.player_rig.global_position
		rig.rotation.y = du.player_rig.global_rotation.y
		if rig.drone and du.player_rig.drone and is_instance_valid(du.player_rig.drone):
			rig.drone.continue_from(du.player_rig.drone)
		backdrop.cam_fov = du.cam.fov
		backdrop.cam.fov = du.cam.fov
		backdrop.move_camera(du.cam.global_position, du.cam.global_position - du.cam.global_basis.z * 4.0, true)
	elif _meet_foe and is_instance_valid(_meet_foe):
		_meet_foe.visible = true
	_cam_yaw = rig.rotation.y
	rig.visible = true
	backdrop.cam.make_current()
	_meet_foe = null
	var env: Environment = route.arena.env
	env.ambient_light_color = Color(route.arena.theme.amb)
	env.fog_light_color = Color(route.arena.theme.fog)
	Sfx.ambience(str(Game.run_region().amb))
	Sfx.music_for("explore_courtyard", "menu", 2.5)

# ---------------------------------------------------------------- rooms: the camera that is in there with the knight
## Inside a room (the guardhouse, the murder hole) the follow camera would be behind the door jamb or in the knight's
## back: the camera is in the room's own corner instead, from the moment the knight is over the threshold, and gives
## the knight back to the follow camera once they are well out of it again.
func _room_cam_tick() -> void:
	var rig := backdrop.rig
	var door: Vector3 = _room.door
	var stand: Vector3 = _room.stand
	var inward := Vector3(stand.x - door.x, 0, stand.z - door.z).normalized()
	var inside := Vector3(rig.position.x - door.x, 0, rig.position.z - door.z).dot(inward) > 0.25
	if inside:
		var first := not bool(_room.get("in", false))
		_room["in"] = true
		var chest := rig.position + Vector3(0, 1.25, 0)
		var look: Vector3 = chest.lerp(_room.look, 0.25 if not _walk.is_empty() else 0.6)
		backdrop.cam_fov = 54.0
		backdrop.cam_speed = 3.0
		backdrop.move_camera(_room.eye, look, first)
		return
	if bool(_room.get("in", false)) and Vector2(rig.position.x - door.x, rig.position.z - door.z).length() > 2.4:
		_room = {}
		_cam_yaw = rig.rotation.y
		return
	if not _walk.is_empty():
		_route_cam()

# ---------------------------------------------------------------- the knight's hands on what it uses
## The knight uses the thing in front of it: the sword put up, the hand to the lid, the crank or the stone, and what it
## does (the lid comes up, the crank turns and the gate rises, the shrine's light swells). Returns once it is done.
func _act(o: Dictionary, prop: Node3D) -> void:
	var rig := backdrop.rig
	if _reach and is_instance_valid(_reach):
		_reach.queue_free()
	_reach = RouteKit.Reach.new(rig)
	rig.add_child(_reach)
	var put := rig.sheath()
	if put > 0.0:
		await get_tree().create_timer(put).timeout
	if not is_inside_tree():
		return
	var r := _reach
	match str(o.type):
		"treasure":
			_witness_inspect(prop.global_position + Vector3(0, 0.8, 0), 3.0)
			var lid: Node3D = prop.get_node_or_null("Lid")
			r.dir = prop.global_basis.x
			r.curl = 0.75
			r.at = func() -> Vector3: return (lid.global_transform * Vector3(0, 0.0, 0.56)) if is_instance_valid(lid) else prop.global_position
			var tw := create_tween().set_parallel(true)
			tw.tween_property(r, "w", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
			tw.tween_property(r, "lean", 0.42, 0.6).set_trans(Tween.TRANS_SINE)
			tw.tween_property(r, "look_w", 0.8, 0.5)
			await tw.finished
			if lid and lid.rotation.x > -1.0:
				await RouteKit.open_chest(prop).finished
			var back := create_tween().set_parallel(true)
			back.tween_property(r, "w", 0.0, 0.55).set_trans(Tween.TRANS_SINE)
			back.tween_property(r, "lean", 0.12, 0.6).set_trans(Tween.TRANS_SINE)
			await back.finished
		"lever":
			var winch := prop.get_node_or_null("Crank") != null
			if not winch:
				return
			r.dir = prop.global_basis.x
			r.curl = 0.95
			r.at = func() -> Vector3: return RouteKit.handle_at(prop)
			var tw2 := create_tween().set_parallel(true)
			tw2.tween_property(r, "w", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
			tw2.tween_property(r, "lean", 0.18, 0.55)
			tw2.tween_property(r, "look_w", 0.6, 0.5)
			await tw2.finished
			# the crank goes round, the pawl clicks, the chain runs; the gate across the yard comes up with it
			var secs := 4.6
			var turn := RouteKit.turn_winch(prop, 4.0, secs, func(u: float): r.lean = 0.18 + 0.1 * sin(u * 4.0 * TAU))
			get_tree().create_timer(0.6).timeout.connect(func():
				if route:
					route.open_gate("inner", secs)
					route.open_gate("postern", secs + 0.8, true))
			# the camera stands back to take in the winch, the knight at it, and the gate rising beyond
			get_tree().create_timer(1.1).timeout.connect(func():
				if is_inside_tree() and route:
					backdrop.cam_speed = 0.9
					backdrop.cam_fov = 50.0
					backdrop.move_camera(Vector3(-3.6, 7.7, -139.2), Vector3(-2.6, 7.6, -152.0)))
			get_tree().create_timer(1.6).timeout.connect(func():
				_witness_inspect(Vector3(-2.0, 7.8, -152.4), 4.0))
			await turn.finished
			var back2 := create_tween().set_parallel(true)
			back2.tween_property(r, "w", 0.0, 0.5)
			back2.tween_property(r, "lean", 0.0, 0.5)
			back2.tween_property(r, "look_w", 0.0, 0.5)
			await back2.finished
			await get_tree().create_timer(0.8).timeout
		"shrine":
			# a hand on the stone under the ring, the head bowed; the light that is not a candle answers
			r.dir = Vector3.UP
			r.curl = 0.1
			r.at = prop.global_transform * Vector3(0.0, 1.25, 0.24)
			var tw3 := create_tween().set_parallel(true)
			tw3.tween_property(r, "w", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
			tw3.tween_property(r, "lean", 0.3, 0.9).set_trans(Tween.TRANS_SINE)
			await tw3.finished
			for l: Node in prop.get_children():
				if l is OmniLight3D:
					var e0: float = (l as OmniLight3D).light_energy
					var lt := create_tween()
					lt.tween_property(l, "light_energy", e0 * 2.6, 1.0).set_trans(Tween.TRANS_SINE)
					lt.tween_property(l, "light_energy", e0, 1.6).set_trans(Tween.TRANS_SINE)
			Sfx.play("swell", -10.0, 0.7)
			await get_tree().create_timer(1.6).timeout
			var back3 := create_tween().set_parallel(true)
			back3.tween_property(r, "w", 0.0, 0.7)
			back3.tween_property(r, "lean", 0.0, 0.8)
			await back3.finished
	if is_inside_tree() and rig.is_sheathed():
		rig.draw()

func _witness_inspect(p: Vector3, hold: float = 4.0) -> void:
	var rig := backdrop.rig if backdrop else null
	if rig and rig.drone and is_instance_valid(rig.drone):
		rig.drone.inspect(p, hold)

## At a fork, or where something is worth a look, the Witness goes on ahead to it before the knight chooses.
func _witness_ahead(stage: int) -> void:
	var pts: Array = []
	match stage:
		# (it goes no further than about ten metres from the knight: WitnessDrone keeps company)
		1: pts = [Vector3(-6.2, 5.0, -99.0), Vector3(9.0, 5.4, -95.4)]        # toward the guardhouse door, then the foot of the stair
		3: pts = [Vector3(-6.4, 6.9, -144.5), Vector3(0, 7.8, -150.5)]        # the winch, then the gate it holds
		4: pts = [Vector3(2.0, 7.0, -159.6)]                                  # toward the gap into the murder hole
		5: pts = [CourtRoute.anchor(5) + Vector3(-8.6, 2.2, -3.0)]            # the chapel's light
		6: pts = [Vector3(0, 10.0, -211.0)]                                   # the one at his post
	var t := 2.2
	for p: Vector3 in pts:
		get_tree().create_timer(t).timeout.connect(func():
			if is_inside_tree() and not _in_duel:
				_witness_inspect(p, 3.4))
		t += 3.6

# ---------------------------------------------------------------- the action button stays off the thing it acts on
var _action: Button
var _action_prop: Node3D
const ACTION_BOX := {"treasure": [Vector3(-0.55, 0.0, -0.75), Vector3(0.55, 1.15, 0.45)], "lever": [Vector3(-1.0, 0.0, -0.8), Vector3(0.6, 1.8, 0.8)],
	"shrine": [Vector3(-1.1, 0.0, -1.1), Vector3(1.1, 2.7, 1.1)]}

## Where the thing being used is on screen (viewport pixels).
func prop_rect() -> Rect2:
	if _action_prop == null or not is_instance_valid(_action_prop):
		return Rect2()
	var cam := backdrop.cam
	var box: Array = ACTION_BOX.get(str(_action_prop.get_meta("kind", "treasure")), ACTION_BOX.treasure)
	var lo: Vector3 = box[0]
	var hi: Vector3 = box[1]
	var r := Rect2()
	var first := true
	for i in 8:
		var c := Vector3(hi.x if i & 1 else lo.x, hi.y if i & 2 else lo.y, hi.z if i & 4 else lo.z)
		var w := _action_prop.global_transform * c
		if cam.is_position_behind(w):
			continue
		var s2 := cam.unproject_position(w)
		if first:
			r = Rect2(s2, Vector2.ZERO)
			first = false
		else:
			r = r.expand(s2)
	return r

func _place_action() -> void:
	if _action == null or not is_instance_valid(_action):
		return
	var vs := get_viewport().get_visible_rect().size
	var avoid := prop_rect().grow(18.0)
	var sz := _action.size
	var m := 28.0
	var cx := avoid.get_center().x if avoid.size != Vector2.ZERO else vs.x * 0.5
	var far_x := m if cx > vs.x * 0.5 else vs.x - sz.x - m
	var near_x := vs.x - sz.x - far_x
	var low := vs.y - sz.y - m * 1.6
	var cands: Array = [Vector2(far_x, low), Vector2((vs.x - sz.x) * 0.5, low), Vector2(near_x, low), Vector2(far_x, vs.y * 0.5 - sz.y * 0.5),
		Vector2(far_x, m * 3.4), Vector2(near_x, m * 3.4)]
	var pick: Vector2 = cands[0]
	for c: Vector2 in cands:
		if not Rect2(c, sz).intersects(avoid):
			pick = c
			break
	_action.position = _action.position.lerp(pick, 0.25) if _action.has_meta("placed") else pick
	_action.set_meta("placed", true)

# ---------------------------------------------------------------- the coin lying about: there before the stop is
## Every stop's pouches lie in the place from the start (each stop's taking is only offered there).
var _world_pouches := {}
func _pouches_all() -> void:
	var n: int = Game.run_region().stages.size()
	var keep: int = int(Game.run.stage)
	for st in n:
		Game.run.stage = st
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|%d" % [Game.run.region, st])
		var count := int(Game.run_stage().get("pouches", 1))
		for i in count:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var reach := float(CourtRoute.POUCH_REACH.get(st, 6.5))
			var v := Vector3(side * rng.randf_range(2.2, 4.2) - 0.3, 0, rng.randf_range(-reach, -2.0))
			if Game.pouch_taken(i):
				continue
			var at := _frame_at(st, v)
			at.y = CourtRoute.ground_y(at.x, at.z)
			_world_pouches["%d|%d" % [st, i]] = backdrop.add_prop("pouch", at)
	Game.run.stage = keep

## The way walked goes round whoever lies on it (the knight does not walk over the fallen).
func _around(pts: Array) -> Array:
	if life == null or life.laid.is_empty() or pts.size() < 2:
		return pts
	var out: Array = [pts[0]]
	for i in range(1, pts.size()):
		var a: Vector3 = out[out.size() - 1]
		var b: Vector3 = pts[i]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		if ab.length() > 0.5:
			for body: Node3D in life.laid:
				if not is_instance_valid(body):
					continue
				var c: Vector3 = (body as FighterRig).chest_point() if body is FighterRig else body.global_position
				var ac := Vector2(c.x - a.x, c.z - a.z)
				var t := clampf(ac.dot(ab) / ab.length_squared(), 0.0, 1.0)
				var near := Vector2(a.x, a.z) + ab * t
				var d := near.distance_to(Vector2(c.x, c.z))
				if d < 1.15 and t > 0.04 and t < 0.96:
					var away := (near - Vector2(c.x, c.z))
					if away.length() < 0.05:
						away = Vector2(-ab.y, ab.x)
					var p2 := Vector2(c.x, c.z) + away.normalized() * 1.35
					out.append(Vector3(p2.x, 0, p2.y))
					break
		out.append(b)
	return out

# ---------------------------------------------------------------- what lies about is there before the stop is reached
var _tells := {}
## On the road a secret's tell (or a clue's) is laid once, with the place, and found there again when its stop is.
func _tell_kept(key: String, kind: String, at: Vector3) -> Node3D:
	if route and _tells.has(key) and is_instance_valid(_tells[key]):
		return _tells[key]
	var n := _tell(kind, at)
	if route:
		_tells[key] = n
	return n

## Lays every stop's tells in the place as the road is opened (each is only touchable at its own stop).
func _tells_all() -> void:
	var keep := [int(Game.run.stage), origin, angle]
	for st in Game.run_region().stages.size():
		Game.run.stage = st
		origin = CourtRoute.anchor(st)
		angle = CourtRoute.anchor_yaw(st)
		_place_secrets(null)
	Game.run.stage = keep[0]
	origin = keep[1]
	angle = keep[2]
