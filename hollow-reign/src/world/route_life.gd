class_name RouteLife
extends Node
## Who lives on the Courtyard's road (Stage 3B; data: CourtRoute.ENCOUNTERS). Every foe the road will meet is in the
## place from the moment the road is opened, doing what it was left doing: a sentry walking the line of the breach, a
## guard in the stair-foot post's door, the banneret at attention under his banner, the last defender behind the
## barricade in the gate passage (or the gate's guardian sitting dormant there), the Sentinel at his post in the inner
## ward. Each is shown with the section of the place it stands in (built out of sight, like its walls), so nothing
## appears in view. When it is met it enters as itself (`meet`), and the duel is fought where they meet. What falls
## there stays there for the rest of this run (`bodies`), until the road is opened again from a checkpoint.
##
## Cheap: a foe far from the knight, or in a section not yet built, is not processed (its pose is held); bodies are
## held poses with no processing and no physics.

const ACTIVE_M := 62.0            # metres from the knight inside which an inhabitant moves
const PATROL_SPEED := 1.05
const PAUSE := 2.6                # seconds a sentry stands at each end of its line
const FOE_STEPS_M := 11.0         # its footfalls are heard only this near (the game's sounds are not placed in space)

var ex: Explore
var foes := {}                    # stage -> CineActor
var props := {}                   # stage -> Node3D (the barricade)
var seats := {}                   # stage -> Node3D (what the dormant guardian sits on)
var state := {}                   # stage -> "post" | "meeting" | "met"
var _beat := {}                   # stage -> {"i": point index, "wait": seconds}
var _walks := {}                  # stage -> {"pts": Array, "speed": float, "done": Callable}
var laid: Array = []              # bodies lying in this place (nodes)
var notes: Array = []             # anything stood while it could be seen (tests)

## What lies on the road this run: {run, stage, foe, pos, yaw}. Static: it outlives the screen (a walk on after a
## duel keeps the screen; a rebuild of the road in the same run lays them down again).
static var bodies: Array = []

static func run_key() -> String:
	return "%s|%s" % [str(Game.run.get("region", "")), str(Game.run.get("seed", ""))]

## The bodies of this run that still lie: a Retry or Continue from a checkpoint stands everything from it again.
static func bodies_now() -> Array:
	var key := run_key()
	var st := int(Game.run.get("stage", 0))
	bodies = bodies.filter(func(b: Dictionary) -> bool: return str(b.run) == key)
	return bodies.filter(func(b: Dictionary) -> bool: return int(b.stage) < st or bool(b.get("kept", false)))

static func fallen(stage: int) -> bool:
	var key := run_key()
	for b: Dictionary in bodies:
		if str(b.run) == key and int(b.stage) == stage:
			return true
	return false

func _init(e: Explore) -> void:
	ex = e
	name = "RouteLife"

## The fight of a stop, as it is offered (its foe drawn from the stop's pool for this run).
static func fight_of(stage: int) -> Dictionary:
	for o: Dictionary in Explore._options_at(stage):
		if str(o.type) in ["fight", "boss"] and o.has("foe") and Db.foes.has(str(o.foe)):
			return o
	return {}

## Stands everyone from `from_stage` on where they are, and lays down whoever already fell this run.
func setup(from_stage: int) -> void:
	var lying := bodies_now()
	var key := run_key()
	bodies = bodies.filter(func(b: Dictionary) -> bool: return str(b.run) == key and lying.has(b))
	for b: Dictionary in lying:
		_lay_again(b)
	var k := ex.backdrop.rig.position if ex.backdrop and ex.backdrop.rig else CourtRoute.anchor(from_stage)
	for st: int in CourtRoute.ENCOUNTERS:
		if st >= from_stage and not fallen(st):
			var p: Array = CourtRoute.ENCOUNTERS[st].post
			# (those near enough to be seen from where the road opens are stood at once, behind its opening)
			stand(st, Vector2(k.x, k.z).distance_to(Vector2(float(p[0]), float(p[1]))) < 50.0)

func stand(st: int, now: bool = false) -> void:
	if foes.has(st) or state.has(st):
		return
	var o := fight_of(st)
	if o.is_empty():
		return
	var id := str(o.foe)
	if str(Db.foes[id].rig.get("kind", "")) == "dragon":
		return
	var m := ex.get_parent()
	if m != null and m.has_method("story_kind") and str(m.story_kind(id)) != "":
		return                     # a foe of the family's story keeps its own staged meeting
	var e := CourtRoute.encounter(st, id)
	if e.is_empty():
		return
	state[st] = "post"
	var at := _ground(e.post)
	if e.has("barricade"):
		var bpos := _ground(e.barricade)
		props[st] = RouteKit.barricade(ex.backdrop.props, ex.route.arena, bpos, 5.4)
	var build := func():
		if not is_instance_valid(ex) or not ex.is_inside_tree() or ex.backdrop == null:
			return
		var f := CineActor.new()
		f.name = "Foe%d" % st
		ex.backdrop.props.add_child(f)
		f.build(CineActor.foe_look(id), true)
		f.set_meta("foe", id)
		f.position = at
		f.rotation.y = deg_to_rad(float(e.yaw))
		f.time_scale = 0.8
		f.ground = CourtRoute.ground_y
		f.footsteps = false
		if str(e.how) == "wake":
			_seat(st, f, at)
			f.hold("sit_idle", 0.0)
			f.time_scale = 0.35
		f.visible = _built(at)
		if f.visible and not now and ex._seen(at):
			notes.append("stop %d: %s stood in view" % [st + 1, id])
			f.visible = false
		foes[st] = f
		_beat[st] = {"i": 1, "wait": 0.0}
	if now:
		build.call()
	else:
		ex._read_ahead(CineActor.foe_files(id), build)

func _ground(p: Array) -> Vector3:
	var x := float(p[0])
	var z := float(p[1])
	return Vector3(x, CourtRoute.ground_y(x, z), z)

func _built(p: Vector3) -> bool:
	return ex.route != null and ex.route._done.has(CourtRoute.section_of(p.z))

## What the dormant guardian sits on: a fallen block of the gate's facing, in the passage.
func _seat(st: int, f: FighterRig, at: Vector3) -> void:
	var n := Node3D.new()
	n.name = "Seat%d" % st
	ex.backdrop.props.add_child(n)
	var back := Basis(Vector3.UP, f.rotation.y) * Vector3(0, 0, -1)
	n.position = at - back * 0.25
	n.rotation.y = f.rotation.y + 0.12
	var k := Future.Kit.new(ex.route.arena, n)
	var h := 0.46 * f.scale.y
	Future._box(k.pale(false), Vector3(1.5, h, 1.1), Vector3(0, h * 0.5, 0), Basis(Vector3.FORWARD, 0.04))
	Future._box(k.alloy(false), Vector3(1.56, 0.12, 0.2), Vector3(0, h - 0.04, 0.45))
	RouteKit._commit(k)
	seats[st] = n

## Called every frame with where the knight is.
func tick(dt: float, knight: Vector3) -> void:
	for st: int in foes:
		var f: CineActor = foes[st]
		if not is_instance_valid(f):
			continue
		var built := _built(f.global_position)
		if not f.visible and built and (state.get(st, "") != "post" or not ex._seen(f.global_position)):
			f.visible = true
		elif not built:
			f.visible = false
		var near := f.global_position.distance_to(knight) < ACTIVE_M and f.visible
		f.process_mode = Node.PROCESS_MODE_INHERIT if near or state.get(st, "") != "post" else Node.PROCESS_MODE_DISABLED
		f.footsteps = f.global_position.distance_to(knight) < FOE_STEPS_M
		if _walks.has(st):
			_walk_tick(st, f, dt)
		elif near and state.get(st, "") == "post":
			_post_tick(st, f, dt)
	for st2: int in props:
		var p: Node3D = props[st2]
		if is_instance_valid(p):
			p.visible = _built(p.global_position)
	for st3: int in seats:
		var s: Node3D = seats[st3]
		if is_instance_valid(s):
			s.visible = _built(s.global_position)

## What each does while nobody has come: the sentry walks its line and stops at each end to look out.
func _post_tick(st: int, f: CineActor, dt: float) -> void:
	var e := CourtRoute.encounter(st, str(f.get_meta("foe")))
	if str(e.how) != "patrol":
		return
	var b: Dictionary = _beat[st]
	if float(b.wait) > 0.0:
		b.wait = float(b.wait) - dt
		f.walking = false
		return
	var pts: Array = e.beat
	var to := _ground(pts[int(b.i)])
	var d := to - f.position
	d.y = 0.0
	if d.length() < 0.05:
		b.i = (int(b.i) + 1) % pts.size()
		b.wait = PAUSE
		f.walking = false
		# at the end of its line it turns to look out over the breach, the way it was set to watch
		create_tween().tween_property(f, "rotation:y", f.rotation.y + wrapf(PI - f.rotation.y, -PI, PI), 1.2).set_trans(Tween.TRANS_SINE)
		return
	f.walking = true
	var step := minf(PATROL_SPEED * dt, d.length())
	f.position += d.normalized() * step
	f.position.y = CourtRoute.ground_y(f.position.x, f.position.z)
	f.rotation.y = lerp_angle(f.rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-dt * 4.0))

func _walk_tick(st: int, f: CineActor, dt: float) -> void:
	var w: Dictionary = _walks[st]
	var pts: Array = w.pts
	if pts.is_empty():
		_walks.erase(st)
		f.walking = false
		if (w.done as Callable).is_valid():
			(w.done as Callable).call()
		return
	var to: Vector3 = pts[0]
	var d := to - f.position
	d.y = 0.0
	var step := float(w.speed) * dt
	if d.length() <= step:
		f.position = Vector3(to.x, CourtRoute.ground_y(to.x, to.z), to.z)
		pts.pop_front()
		return
	f.walking = true
	f.position += d.normalized() * step
	f.position.y = CourtRoute.ground_y(f.position.x, f.position.z)
	f.rotation.y = lerp_angle(f.rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-dt * 5.0))

signal _arrived(st: int)

func _walk_to(st: int, pts: Array, speed: float) -> void:
	var f: CineActor = foes[st]
	f.process_mode = Node.PROCESS_MODE_INHERIT
	_walks[st] = {"pts": pts, "speed": speed, "done": func(): _arrived.emit(st)}
	while _walks.has(st) and is_instance_valid(f):
		await get_tree().process_frame

func _face(f: Node3D, p: Vector3, secs: float) -> void:
	var d := p - f.global_position
	var to := atan2(-d.x, -d.z)
	var tw := create_tween()
	tw.tween_property(f, "rotation:y", f.rotation.y + wrapf(to - f.rotation.y, -PI, PI), secs).set_trans(Tween.TRANS_SINE)
	await tw.finished

## The foe of stop `st` comes to fight as itself, from where it is to `at` (the duel's opening place), facing `knight`
## (a Node3D: the knight, still walking up). Returns when it is there, in guard.
func meet(st: int, at: Vector3, knight: Node3D) -> void:
	var f: CineActor = foes.get(st)
	if f == null or not is_instance_valid(f):
		return
	state[st] = "meeting"
	f.visible = true
	f.process_mode = Node.PROCESS_MODE_INHERIT
	f.time_scale = 1.0
	var e := CourtRoute.encounter(st, str(f.get_meta("foe")))
	var outs: Array = []
	for p: Array in e.get("out", []):
		outs.append(_ground(p))
	outs.append(at)
	match str(e.how):
		"patrol":
			# it has seen them: it stops, turns, and comes off its line toward them
			_beat[st].wait = 99.0
			f.walking = false
			Sfx.play("armor", -9.0, 0.85)
			await _face(f, knight.global_position, 0.7)
			await get_tree().create_timer(0.35).timeout
		"door":
			# out of the post's door into the yard
			await _face(f, outs[0], 0.4)
			Sfx.play("armor", -9.0, 0.9)
		"banner":
			# it salutes first: the sword hand to the brow, held, and down; then it steps off from under the banner
			await _face(f, knight.global_position, 0.5)
			var r := RouteKit.Reach.new(f)
			f.add_child(r)
			r.curl = 0.2
			r.dir = Vector3.UP
			r.at = func() -> Vector3: return f.global_transform * Vector3(0.12, 1.66 * f.scale.y, -0.16)
			var tw := create_tween()
			tw.tween_property(r, "w", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
			tw.tween_interval(1.1)
			tw.tween_property(r, "w", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
			Sfx.play("armor", -10.0, 1.0)
			await tw.finished
			r.queue_free()
		"barricade":
			# up to the barricade from behind it, and through it
			var bar: Node3D = props.get(st)
			if bar != null and is_instance_valid(bar):
				var before := bar.global_position + Vector3(0.3, 0, -0.9)
				before.y = CourtRoute.ground_y(before.x, before.z)
				await _walk_to(st, [before], 1.3)
				await _face(f, bar.global_position + Vector3(0, 0, 3.0), 0.3)
				f.swing(Vector2(1.0, -0.3), 0.32)
				Sfx.play("swing_heavy", -4.0, 0.8)
				await get_tree().create_timer(0.3).timeout
				RouteKit.smash(bar)
				ex.shake_cam(0.35)
				await get_tree().create_timer(0.55).timeout
				f.recover()
		"wake":
			# the guardian left sitting in the passage stirs, gets up, and comes out of the gate
			Sfx.play("roar", -12.0, 0.55)
			f.time_scale = 0.8
			if SkinDriver.has_clip("sit_exit"):
				f.hold("sit_exit", 0.5)
				await get_tree().create_timer(maxf(SkinDriver.clip_length("sit_exit") / 0.8 - 0.5, 0.6)).timeout
			f.release(0.6)
			f.time_scale = 1.0
			await get_tree().create_timer(0.6).timeout
			f.roar()
			Sfx.play("thump", -6.0, 0.6)
			ex.shake_cam(0.25)
			await get_tree().create_timer(1.2).timeout
		"post":
			await _face(f, knight.global_position, 0.8)
	f.rest_carry = false
	var speed := 1.25 if f.scale.y < 1.2 else 1.05
	await _walk_to(st, outs, speed)
	if not is_instance_valid(f):
		return
	await _face(f, knight.global_position, 0.35)
	f.guard()
	state[st] = "met"

## The foe stood at a stop, if it is standing.
func foe_at(st: int) -> CineActor:
	var f = foes.get(st)
	return f if f != null and is_instance_valid(f) else null

## The rig that fought at stop `st` lies where it fell: it is moved into the place as it is, held after it has
## settled, and recorded for this run. The one that stood there before the duel is let go.
func lay_down(st: int, rig: Node3D, foe_id: String) -> void:
	var stood = foes.get(st)
	if stood != null and is_instance_valid(stood) and stood != rig:
		stood.queue_free()
	foes.erase(st)
	state.erase(st)
	if rig == null or not is_instance_valid(rig):
		return
	rig.reparent(ex.backdrop.props, true)
	rig.set_meta("body", st)
	laid.append(rig)
	var r := rig as FighterRig
	if r != null:
		r.footsteps = false
	bodies.append({"run": run_key(), "stage": st, "foe": foe_id, "pos": rig.global_position, "yaw": rig.global_rotation.y,
		"xf": rig.global_transform})
	# (it has fallen: once it has come to rest it is a held pose, no longer worked on)
	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(rig):
			rig.process_mode = Node.PROCESS_MODE_DISABLED)

## A body of this run laid again in a road opened anew (it fell before the checkpoint the road is opened at).
func _lay_again(b: Dictionary) -> void:
	var id := str(b.foe)
	if not Db.foes.has(id):
		return
	# (laid at once, behind the road's opening, so that it is lying there from the first frame)
	if ex.backdrop != null:
		var f := CineActor.new()
		f.name = "Body%d" % int(b.stage)
		ex.backdrop.props.add_child(f)
		f.build(CineActor.foe_look(id), true)
		f.global_transform = b.xf
		f.footsteps = false
		f.set_meta("body", int(b.stage))
		f.die(1.0)
		# the fall is played through at speed, out of sight behind the road's opening, then held
		f.time_scale = 12.0
		laid.append(f)
		ex.get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(f):
				f.process_mode = Node.PROCESS_MODE_DISABLED)
	var e := CourtRoute.encounter(int(b.stage), id)
	if e.has("barricade") and not props.has(int(b.stage)):
		var bar := RouteKit.barricade(ex.backdrop.props, ex.route.arena, _ground(e.barricade), 5.4)
		RouteKit.broken(bar)
		props[int(b.stage)] = bar

## Whether a foe still stands on the way on from stop `st` (its way runs past it).
func blocks(st: int) -> bool:
	var f := foe_at(st)
	return f != null and bool(CourtRoute.encounter(st, str(f.get_meta("foe"))).get("blocks", false))
