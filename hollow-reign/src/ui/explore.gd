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
	var region := Game.run_region()
	var stage: int = Game.run.stage
	angle = bearing(stage)
	Game.save()                   # the road is saved at every stop reached: an app ended in the background comes back here
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
	Sfx.ambience(str(region.amb))
	Sfx.music_for("explore_" + str(region.id), "menu")
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
		backdrop.add_prop("marker", at)
		markers.append(at)
		_stand_foe(opts[i], at)
		row.add_child(_card(opts[i], i))
	_scatter_pouches(frame, int(Game.run_stage().get("pouches", 1)))
	_place_secrets(frame)
	WitnessDrone.set_points(self, _witness_points())      # what the Witness may drift over to and look at
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
	return v.rotated(Vector3.UP, a)

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
	var foe: Dictionary = Db.foes[str(o.foe)]
	var files: Array = CineActor.foe_files(str(o.foe))
	if o.type != "fight" or str(foe.rig.get("kind", "")) == "dragon":
		_read_ahead(files, Callable())
		return
	_read_ahead(files, func():
		var f := FighterRig.new()
		backdrop.props.add_child(f)
		f.build(CineActor.foe_look(str(o.foe)), true)
		f.position = at + _at(angle, Vector3(0, 0, -FOE_BEYOND))
		f.rotation.y = angle + PI
		f.time_scale = 0.6
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
		var at := _at(angle, Vector3(side * rng.randf_range(2.2, 4.2) - 0.3, 0, rng.randf_range(-6.5, -2.0)))
		if Game.pouch_taken(i):
			continue
		var prop := backdrop.add_prop("pouch", at)
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
	_tick_secrets(_dt)
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
	var ui: Control = layer.get_child(0)
	return ui.visible and ui.modulate.a > 0.5 and not _staging and not _leaving

func _choose(o: Dictionary, index: int = 0) -> void:
	_idle = 0.0
	if _aside:
		_aside = false
		Story.stop()              # the player has heard enough: the remark gives way to what they chose
	match o.type:
		"fight", "boss":
			if index < foes.size() and foes[index] != null:
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
	var mx := 0.9
	if index < markers.size():
		mx = (markers[index] as Vector3).rotated(Vector3.UP, -angle).x + 3.0
	var spot := _at(angle, Vector3(mx, 0, -2.4))
	var prop: Node3D = _shrine(spot) if o.type == "shrine" else backdrop.add_prop(o.type, spot)
	prop.rotation.y = angle
	if o.type == "shrine":
		backdrop.move_camera(spot + _at(angle, Vector3(2.0, 1.25, 3.7)), spot + Vector3(0, 1.25, 0))      # the whole monument, ring and all
	else:
		backdrop.move_camera(spot + _at(angle, Vector3(1.7, 1.3, 2.8)), spot + Vector3(0, 0.6, 0))
	var verb: String = {"treasure": "Open", "shrine": "Rest", "lever": "Pull"}[o.type]
	var l2 := CanvasLayer.new()
	add_child(l2)
	var c := UI.full(CenterContainer.new())
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l2.add_child(c)
	var b := UI.button(verb, 24, 220)
	c.add_child(b)
	b.modulate.a = 0.0
	create_tween().tween_property(b, "modulate:a", 1.0, 0.5).set_delay(0.9)
	b.pressed.connect(func():
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
	match o.type:
		"treasure":
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
			create_tween().tween_property(prop.get_node("Arm"), "rotation:z", -0.6, 0.5).set_trans(Tween.TRANS_BACK)
			Sfx.play("guard_break", -8.0, 0.7)
			Game.pull_lever(o)
			heading = "A Way Opens"
			lines.append("%s will stay open." % Game.run_region().shortcut.label)
			lines.append("You may begin from here when you return.")
	await get_tree().create_timer(0.9).timeout
	Overlays.message(self, heading, lines, "Onward", func(): _walk_then(_way, func(): moved_on.emit(), true))

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
			var node := _tell(str(places[i].tell), at)
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
		var node := _tell(str(c.tell), _at(angle, Vector3(float(c.pos[0]) - 0.3, 0, float(c.pos[1]))))
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
