class_name CourtRoute
extends Node3D
## The Fallen Courtyard as one continuous place (docs/TRAVERSAL_PLAN.md, MASTER_REQUIREMENTS Addenda 7 §2 §6, 8 §5):
## a hillside causeway along a sea cliff, a bridge over a ravine with its falls, the damaged outer wall and its breach,
## the rubble yard with the guardhouse and the stair to the wall-walk, the barbican, the winch yard and the inner gate,
## the gate passage with the murder hole off it, the chapel court, and the inner ward under the keep. About 255 m from
## the hillside door to the Sentinel's ward, rising 8 m. Every stop of the road (data/regions.json `anchor`) is a flat
## place in it; the road screen (src/ui/explore.gd) walks the knight between them along `leg()`.
##
## Built in code from the far-future kit (src/world/future.gd: bulkheads, spires, merged by material) and its props
## (env_fu_*, env_road_*, env_rubble, env_statue_head, env_banner), on a ground of its own (court_ground.gdshader).
## Streamed: five sections, each under its own node and merged by material; the two either side of the knight's are
## kept, the rest are freed. A section is built a little at a time (a few milliseconds a frame) while it is still a
## section or more ahead, behind a wall or a turn, and shown when it is complete. A far layer (the sea, the mountains,
## the sky, the keep and its spires, the colossus on the ridge) is built once and stays.
##
## Floors are data (`FLOORS`): what is drawn as paving, ramps and stairs is what `ground_y` answers, so the feet and
## the geometry cannot disagree.
##
## HOOKS for the other stages (search for "HOOK"):
##   Stage 1: ENTRY is where the awakening chamber's exit passage comes out on the hillside; the Witness follow API
##            belongs at `witness_hook()`.
##   Stage 3B: `foe_spots()`, the chests/levers placed by Explore._world_props, the portcullises (`gates`).

const SEA := -42.0
## HOOK(Stage 1): the hand-off point. The awakening chamber's exit passage ends at this door in the rock face; the
## knight comes out of it facing ENTRY_YAW (down the causeway, -Z). Until Stage 1 delivers the passage, the door is a
## blast door in the hillside (`_entry_door`) and the walk out starts here.
const ENTRY := Vector3(0, 0, 56)
const ENTRY_YAW := 0.0
## Where a journey begun at the winch gate (the shortcut) comes in: just inside the postern at the head of the lane.
const SHORTCUT_IN := Vector3(-13.0, 5.5, -138.5)
const MONUMENT := Vector3(7.0, 3.2, -88.5)        # the fallen head in the rubble yard (Explore._find_witness)
## Fallback anchors [x, y, z, yaw]; data/regions.json (tools/gen_regions.py) is the source.
const ANCHORS := [[0.0, 3.0, -68.0, 0.0], [0.0, 3.2, -92.0, 0.0], [0.0, 4.5, -116.5, 0.0], [0.0, 5.5, -141.0, 0.0],
	[0.0, 5.5, -152.0, 0.0], [0.0, 6.2, -184.0, 22.0], [0.0, 8.0, -206.0, 0.0]]
## Sections by z (from, to): hill, outer wall and rubble yard, barbican, winch yard and gate passage, chapel and ward.
const SECTIONS := [[72.0, -62.0], [-62.0, -110.0], [-110.0, -137.0], [-137.0, -176.0], [-176.0, -300.0]]
const KEEP := 2                   # sections behind the knight's that are kept built
const AHEAD := 3                  # and ahead of it (built before they can be seen: behind the outer wall, the barbican)
const BUDGET_US := 4000           # microseconds a frame a section may take while it builds in the background

## Walkable floors: [x0, x1, za, zb, ha, hb, steps, axis, surface]. Height runs from ha at za (or x0 when axis is "x")
## to hb at zb (or x1); steps > 0 quantises it into treads.
const FLOORS := [
	# the bridge over the ravine
	[2.2, 6.8, -33.5, -52.5, 2.62, 2.92, 0, "z", "metal"],
	# the terrace in front of the outer wall, the rubble of the breach, the yard
	[-14.0, 15.0, -56.0, -75.0, 3.0, 3.0, 0, "z", "stone"],
	[-4.5, 4.5, -75.0, -77.6, 3.0, 3.75, 0, "z", "stone"],
	[-4.5, 4.5, -77.6, -80.5, 3.75, 3.2, 0, "z", "stone"],
	[-16.0, 15.5, -80.5, -106.0, 3.2, 3.2, 0, "z", "stone"],
	# the stair to the wall-walk, the wall-walk, the stair down into the barbican's forecourt
	[12.0, 14.5, -95.0, -109.5, 3.2, 7.8, 23, "z", "stone"],
	[12.0, 15.5, -109.5, -117.0, 7.8, 7.8, 0, "z", "stone"],
	[5.0, 12.0, -114.5, -117.0, 4.5, 7.8, 16, "x", "stone"],
	# up to the forecourt, the forecourt, the barbican's passage
	[-9.0, 11.0, -106.0, -112.0, 3.2, 4.5, 0, "z", "stone"],
	[-12.0, 12.0, -112.0, -127.0, 4.5, 4.5, 0, "z", "stone"],
	[-2.6, 2.6, -127.0, -137.0, 4.5, 5.5, 0, "z", "stone"],
	# the lane behind the barbican, from the yard up to the postern (the winch gate's shortcut)
	[-15.5, -11.0, -106.0, -137.0, 3.2, 5.5, 0, "z", "stone"],
	# the winch yard, the inner gate, the passage, the murder hole and the gap into it
	[-15.5, 12.0, -137.0, -157.0, 5.5, 5.5, 0, "z", "stone"],
	[-3.0, 3.0, -157.0, -159.0, 5.5, 5.5, 0, "z", "stone"],
	[-3.0, 3.0, -159.0, -176.0, 5.5, 6.2, 0, "z", "stone"],
	[3.0, 7.8, -160.8, -166.0, 5.68, 5.68, 0, "z", "stone"],
	# the chapel court, the steps, the inner ward
	[-12.0, 12.0, -176.0, -192.0, 6.2, 6.2, 0, "z", "stone"],
	[-10.0, 10.0, -192.0, -198.0, 6.2, 8.0, 9, "z", "stone"],
	[-21.0, 21.0, -198.0, -240.0, 8.0, 8.0, 0, "z", "stone"],
]
## The spine of the hill road: [z, height]. The natural ground follows it near the road.
const SPINE := [[80.0, -0.2], [56.0, 0.0], [44.0, 0.2], [14.0, 0.8], [0.0, 1.4], [-20.0, 2.0], [-34.0, 2.62], [-52.0, 2.92], [-56.0, 3.0], [-300.0, 3.0]]
const RAVINE_Z := -43.0

## The ways on from each stop: "stage|label" (the way's label) or "stage|" (any other). World (x, z); the height is
## the ground's. The first point is where the knight is when the way begins (a marker, a chest, the foe's place).
const LEGS := {
	"intro": [[0.0, 56.0], [0.4, 44.0], [1.6, 31.0], [5.0, 18.0], [9.0, 4.0], [10.5, -10.0], [8.0, -22.0], [5.0, -30.5], [4.6, -35.0], [4.3, -51.0], [2.5, -57.0], [0.6, -63.0], [0.0, -68.0]],
	"0|": [[0.0, -73.5], [0.0, -77.5], [0.0, -82.0], [-0.5, -88.0], [0.0, -92.0]],
	"1|The Guardhouse": [[-12.6, -101.0], [-9.4, -101.0], [-7.0, -101.2], [-4.0, -105.0], [-1.0, -110.0], [0.0, -113.0], [0.0, -116.5]],
	"1|The Rampart Stair": [[1.3, -97.5], [9.5, -95.0], [13.25, -95.6], [13.25, -109.5], [13.6, -113.5], [13.0, -115.75], [12.0, -115.75], [5.0, -115.75], [2.0, -116.4], [0.0, -116.5]],
	"1|": [[0.0, -98.0], [0.0, -106.0], [0.0, -112.0], [0.0, -116.5]],
	"2|": [[0.0, -122.0], [0.0, -128.0], [0.0, -136.0], [0.0, -141.0]],
	"3|": [[0.0, -146.0], [0.0, -152.0]],
	"4|The Murder Hole": [[5.0, -163.4], [3.0, -163.3], [1.2, -164.6], [0.0, -170.0], [0.0, -176.0], [0.0, -184.0]],
	"4|": [[0.0, -158.0], [0.0, -166.0], [0.0, -176.0], [0.0, -184.0]],
	"5|": [[0.0, -189.0], [0.0, -192.0], [0.0, -198.0], [0.0, -206.0]],
	"shortcut": [[-13.0, -138.5], [-8.0, -143.0], [-2.0, -147.5], [0.0, -152.0]],
}
## Where an interaction of a stop stands in the world (in place of the road screen's own placement beside a marker):
## prop: the thing (x, z); stand: where the knight stands to use it; via: what is walked through on the way there.
const SPOTS := {
	"1|The Guardhouse": {"prop": [-14.0, -101.0], "stand": [-12.6, -101.0], "via": [[-3.0, -97.5], [-7.0, -101.2], [-9.4, -101.0]]},
	"3|Turn the Winch": {"prop": [-6.6, -144.5], "stand": [-5.0, -144.5], "via": []},
	"3|The Well": {"prop": [6.6, -144.5], "stand": [5.0, -144.5], "via": []},
	"4|The Murder Hole": {"prop": [6.7, -163.4], "stand": [5.0, -163.4], "via": [[1.5, -158.0], [2.0, -163.3], [3.4, -163.3]]},
	"5|Kneel": {"prop": [-8.7, -187.0], "stand": [-6.7, -186.6], "via": []},
}
## How far ahead (local -z) of a stop's anchor its pouches may lie, where a wall closes the place in.
const POUCH_REACH := {4: 3.8, 3: 5.0}

var arena: Arena
var far: Node3D
var sections := {}               # index -> Node3D (in the tree; hidden until complete)
var _done := {}                  # index -> true once built
var _queue: Array = []           # section indices waiting to be built in the background
var _building := -1
var _sync := false
var _t0 := 0
var _mats := {}
var _noise: FastNoiseLite
var gates := {}                  # name -> Node3D: the portcullises (Stage 3B animates them)
var focus := Vector3.ZERO
var zone := -1                   # the section the knight is in
var built_log: Array = []        # [section, frames it took, ms] (tests, the report)
var freed_log: Array = []

## Whether the continuous Courtyard can be built (the kit's models are present and the old world was not asked for).
static func available() -> bool:
	return not Future.old_world and PropModel.exists(Future.MODEL % "fu_pylon") and not OS.get_cmdline_user_args().has("--oldroad")

# ================================================================ data
static func anchor(stage: int) -> Vector3:
	var a: Array = _anchor_row(stage)
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

static func anchor_yaw(stage: int) -> float:
	return deg_to_rad(float(_anchor_row(stage)[3]))

static func _anchor_row(stage: int) -> Array:
	var r: Dictionary = Db.region_by_id.get("courtyard", {})
	var st: Array = r.get("stages", [])
	if stage >= 0 and stage < st.size() and (st[stage] as Dictionary).get("anchor") is Array:
		return st[stage].anchor
	return ANCHORS[clampi(stage, 0, ANCHORS.size() - 1)]

static func section_of(z: float) -> int:
	for i in SECTIONS.size():
		if z <= float(SECTIONS[i][0]) and z > float(SECTIONS[i][1]):
			return i
	return 0 if z > 0.0 else SECTIONS.size() - 1

## The way on from `stage` by the option labelled `label` (or the stop's ordinary way), as world points on the ground.
static func leg_points(stage: int, label: String) -> Array:
	var key := "%d|%s" % [stage, label]
	if stage < 0:
		key = label
	var src: Array = LEGS.get(key, LEGS.get("%d|" % stage, []))
	var out: Array = []
	for p: Array in src:
		out.append(Vector3(float(p[0]), 0, float(p[1])))
	return out

static func spot(stage: int, label: String) -> Dictionary:
	var s: Dictionary = SPOTS.get("%d|%s" % [stage, label], {})
	if s.is_empty():
		return {}
	var via: Array = []
	for p: Array in s.via:
		via.append(Vector3(float(p[0]), 0, float(p[1])))
	return {"prop": Vector3(float(s.prop[0]), 0, float(s.prop[1])), "stand": Vector3(float(s.stand[0]), 0, float(s.stand[1])), "via": via}

## The floor rectangle under (x, z), or an empty array.
static func floor_at(x: float, z: float) -> Array:
	var best: Array = []
	var best_h := -1e9
	for f: Array in FLOORS:
		var x0 := float(f[0])
		var x1 := float(f[1])
		var z0 := minf(float(f[2]), float(f[3]))
		var z1 := maxf(float(f[2]), float(f[3]))
		if x < x0 or x > x1 or z < z0 or z > z1:
			continue
		var h := _floor_h(f, x, z)
		if h > best_h:
			best_h = h
			best = f
	return best

static func _floor_h(f: Array, x: float, z: float) -> float:
	var u: float
	if str(f[7]) == "x":
		u = inverse_lerp(float(f[0]), float(f[1]), x)
	else:
		u = inverse_lerp(float(f[2]), float(f[3]), z)
	u = clampf(u, 0.0, 1.0)
	var n := int(f[6])
	if n > 0:
		u = minf(floorf(u * n) / float(n - 1), 1.0) if n > 1 else 1.0
	return lerpf(float(f[4]), float(f[5]), u)

static func spine(z: float) -> float:
	for i in SPINE.size() - 1:
		var a: Array = SPINE[i]
		var b: Array = SPINE[i + 1]
		if z <= float(a[0]) and z >= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), inverse_lerp(float(a[0]), float(b[0]), z))
	return float(SPINE[-1][1]) if z < 0.0 else float(SPINE[0][1])

static func cliff_x(z: float) -> float:
	return 18.0 + 3.0 * sin(z * 0.045) + (6.0 if z < -60.0 else 0.0)

static var _n: FastNoiseLite
static func _nz(x: float, z: float) -> float:
	if _n == null:
		_n = FastNoiseLite.new()
		_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_n.frequency = 0.035
		_n.fractal_octaves = 3
		_n.seed = 771
	return _n.get_noise_2d(x, z)

## The natural ground: the road's spine, hills rising to the west, the land falling to the sea cliff in the east,
## the ravine across the road with its falls at the west end. Under the fortress it lies below the paving.
static func terrain(x: float, z: float) -> float:
	var base := spine(z)
	var h := base - 0.06
	var w := maxf(0.0, -x - 8.0)
	h += w * 0.42 + w * w * 0.0045
	if x > 6.0:
		h -= (x - 6.0) * 0.07
	var road := absf(x - _road_x(z))
	h += _nz(x, z) * 1.1 * smoothstep(3.0, 9.0, road)
	# the ravine: a gorge across the road, its floor 15 m down, closing in to the west where the falls come down
	var across := absf(z - RAVINE_Z)
	var gorge := (1.0 - smoothstep(5.5, 9.5, across + maxf(0.0, -x - 30.0) * 0.5)) * smoothstep(-46.0, -34.0, x)
	h = lerpf(h, -12.0 + across * 0.4 + _nz(x * 2.0, z * 2.0) * 0.8, gorge)
	# the sea cliff
	var c := smoothstep(cliff_x(z) - 1.0, cliff_x(z) + 4.5, x)
	h = lerpf(h, SEA - 4.0, c)
	if z < -55.0 and x > -17.0 and x < 18.5:
		h = minf(h, base - 0.3)       # inside the walls the yards are paved
	return h

static func _road_x(z: float) -> float:
	var pts: Array = LEGS.intro
	if z >= float(pts[0][1]):
		return float(pts[0][0])
	for i in pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		if z <= float(a[1]) and z >= float(b[1]):
			return lerpf(float(a[0]), float(b[0]), inverse_lerp(float(a[1]), float(b[1]), z))
	return 0.0

## The height the knight stands at: a floor where there is one, the natural ground elsewhere.
static func ground_y(x: float, z: float) -> float:
	var f := floor_at(x, z)
	if not f.is_empty():
		return _floor_h(f, x, z)
	return terrain(x, z)

## What is underfoot, for the footfalls.
static func surface_at(p: Vector3) -> String:
	var f := floor_at(p.x, p.z)
	if not f.is_empty():
		return str(f[8])
	return "grass"

## A walkable line through `pts` (world, any y): corners rounded by at most a metre, sampled every quarter metre,
## each point on the ground.
static func path(pts: Array) -> PackedVector3Array:
	var round_pts: Array = []
	for i in pts.size():
		var p: Vector3 = pts[i]
		if i == 0 or i == pts.size() - 1:
			round_pts.append(p)
			continue
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i + 1]
		var ca := minf(1.0, a.distance_to(p) * 0.3)
		var cb := minf(1.0, b.distance_to(p) * 0.3)
		var pa := p + (a - p).normalized() * ca
		var pb := p + (b - p).normalized() * cb
		for k in 5:
			var t := float(k) / 4.0
			round_pts.append(pa.lerp(p, t).lerp(p.lerp(pb, t), t))
	var out := PackedVector3Array()
	for i in round_pts.size() - 1:
		var a2: Vector3 = round_pts[i]
		var b2: Vector3 = round_pts[i + 1]
		var n := maxi(1, int(ceil(Vector2(a2.x, a2.z).distance_to(Vector2(b2.x, b2.z)) / 0.25)))
		for k in n:
			var q := a2.lerp(b2, float(k) / n)
			out.append(Vector3(q.x, ground_y(q.x, q.z), q.z))
	var last: Vector3 = round_pts[-1]
	out.append(Vector3(last.x, ground_y(last.x, last.z), last.z))
	return out

static func path_length(p: PackedVector3Array) -> float:
	var d := 0.0
	for i in p.size() - 1:
		d += p[i].distance_to(p[i + 1])
	return d

# ================================================================ the place
## Builds the light and the air (the Courtyard's own theme), the far layer, and the sections round `at` at once.
func setup(at: Vector3) -> void:
	arena = Arena.new()
	arena.name = "RouteArena"
	add_child(arena)
	arena._theme_id = "courtyard"
	arena.theme = Arena.THEMES["courtyard"]
	arena.rng.seed = hash("court_route")
	arena.mat_stone = Look.stone(Color(arena.theme.stone))
	arena.mat_dark = Look.flat(Color(arena.theme.stone).darkened(0.3), 1.0)
	arena.set_meta("future_look", "courtyard")
	arena._environment()
	arena.sun.directional_shadow_max_distance = 40.0
	arena.env.fog_density = 0.0028
	far = Node3D.new()
	far.name = "Far"
	add_child(far)
	_far_layer()
	_sync = true
	_focus(at, true)
	_sync = false
	if get_parent() is Backdrop:
		(get_parent() as Backdrop).arena = arena

## Called every frame with where the knight is: keeps the sections either side built, frees the rest, and moves the
## air from place to place.
func _focus(at: Vector3, now: bool = false) -> void:
	focus = at
	var z := section_of(at.z)
	if z != zone or now:
		zone = z
		for i in SECTIONS.size():
			var want := i - z <= AHEAD and z - i <= KEEP
			if want and not sections.has(i):
				_queue.append(i)
				_prefetch(i)
			elif not want and sections.has(i) and _done.has(i):
				freed_log.append(i)
				var gone: Node3D = sections[i]
				arena.fires = arena.fires.filter(func(f: Array) -> bool: return is_instance_valid(f[0]) and not gone.is_ancestor_of(f[0]))
				gone.queue_free()
				sections.erase(i)
				_done.erase(i)
		# nearest first
		_queue.sort_custom(func(a: int, b: int): return absi(a - z) < absi(b - z))
	if now:
		while not _queue.is_empty():
			await _build(_queue.pop_front())

func update(at: Vector3) -> void:
	_focus(at)

func _process(dt: float) -> void:
	if _building < 0 and not _queue.is_empty():
		_build(_queue.pop_front())
	_air(dt)

## Waits a frame when this frame's share of building is spent (never while building at once).
func _tick() -> void:
	if _sync:
		return
	if Time.get_ticks_usec() - _t0 > BUDGET_US:
		await get_tree().process_frame
		_t0 = Time.get_ticks_usec()

func _build(i: int) -> void:
	if sections.has(i):
		return
	_building = i
	var n := Node3D.new()
	n.name = "Section%d" % i
	n.visible = _sync
	add_child(n)
	sections[i] = n
	var f0 := Engine.get_process_frames()
	var ms0 := Time.get_ticks_msec()
	_t0 = Time.get_ticks_usec()
	var k := Future.Kit.new(arena, n)
	var pave := Highland._flat_tool()
	var steps := Highland._flat_tool()
	match i:
		0: await _hill(n, k)
		1: await _outer(n, k)
		2: await _barbican(n, k)
		3: await _winch(n, k)
		4: await _ward(n, k)
	if not is_instance_valid(n):
		_building = -1
		return
	await _floors(i, pave, steps)
	await _terrain(n, i)
	Highland._commit(n, "Pave", pave, _mat("pave"), false)
	Highland._commit(n, "Treads", steps, _mat("tread"), true)
	k.commit()
	_tune(n)
	n.visible = true
	_done[i] = true
	built_log.append([i, Engine.get_process_frames() - f0, Time.get_ticks_msec() - ms0])
	_building = -1

## Reads a section's models on a thread before it is built.
func _prefetch(i: int) -> void:
	for id: String in _models(i):
		var p := Future.MODEL % id
		if ResourceLoader.exists(p) and not ResourceLoader.has_cached(p):
			ResourceLoader.load_threaded_request(p)

func _models(i: int) -> Array:
	match i:
		0: return ["road_dead_tree", "fu_husk", "fu_wreck", "fu_pylon"]
		1: return ["rubble", "statue_head", "fu_wall", "fu_wreck", "fu_pylon"]
		2: return ["fu_tower", "banner", "fu_pylon"]
		3: return ["fu_engine", "fu_core"]
		4: return ["fu_colossus", "fu_engine", "fu_pylon", "fu_husk", "fu_tower"]
	return []

## Stands a kit model in a section (waiting for its thread read if it is still being read).
func _prop(n: Node3D, id: String, h: float, pos: Vector3, yaw: float, sink: float = 0.03, cast: int = 0) -> Node3D:
	var p := Future.MODEL % id
	if not _sync and ResourceLoader.exists(p) and ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		while ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
	await _tick()
	if not is_instance_valid(n):
		return null
	Future.into = n
	var r := Future.prop(arena, id, h, pos, yaw, sink, cast)
	Future.into = null
	return r

func _lamp(n: Node3D, at: Vector3, c: Color, e: float, reach: float, fire: bool = false) -> OmniLight3D:
	Future.into = n
	var l := Future.lamp(arena, at, c, e, reach, fire)
	Future.into = null
	l.distance_fade_enabled = true
	l.distance_fade_begin = 34.0
	l.distance_fade_length = 8.0
	return l

## Small things are not drawn from far off; big ones keep their coarse detail early (the kit's LODs).
func _tune(n: Node3D) -> void:
	for g: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
		var aabb := g.get_aabb()
		var size := aabb.size.length() * maxf(g.global_transform.basis.get_scale().x, 0.01)
		if size < 3.0:
			g.visibility_range_end = 48.0
			g.visibility_range_end_margin = 6.0
		elif size < 9.0:
			g.visibility_range_end = 110.0
			g.visibility_range_end_margin = 10.0
		if g is MeshInstance3D:
			(g as MeshInstance3D).lod_bias = minf((g as MeshInstance3D).lod_bias, 0.5)

func _occluder(n: Node3D, centre: Vector3, size: Vector3) -> void:
	var o := OccluderInstance3D.new()
	var b := BoxOccluder3D.new()
	b.size = size
	o.occluder = b
	o.position = centre
	n.add_child(o)

# ---------------------------------------------------------------- materials
func _mat(kind: String) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m: Material
	match kind:
		"pave":
			var s: ShaderMaterial = Future.built(arena, "pale").duplicate()
			s.set_shader_parameter("tint", Color("#7f7d74"))
			s.set_shader_parameter("scale", 0.11)
			s.set_shader_parameter("grime_h", 0.25)
			m = s
		"tread":
			var s2: ShaderMaterial = Future.built(arena, "alloy").duplicate()
			s2.set_shader_parameter("tint", Color("#6c7072"))
			m = s2
		"ground":
			var g := ShaderMaterial.new()
			g.shader = load("res://src/world/court_ground.gdshader")
			g.set_shader_parameter("noise_tex", Highland._noise_tex())
			g.set_shader_parameter("turf_tex", Future._tex("res://assets/textures/floor_blackwood.jpg"))
			g.set_shader_parameter("turf_n", Future._tex("res://assets/textures/floor_blackwood_n.png"))
			g.set_shader_parameter("rock_tex", Future._tex("res://assets/textures/floor_roost.jpg"))
			g.set_shader_parameter("rock_n", Future._tex("res://assets/textures/floor_roost_n.png"))
			g.set_shader_parameter("sea_level", SEA)
			m = g
		"rock":
			var r := StandardMaterial3D.new()
			r.albedo_texture = Future._tex("res://assets/textures/floor_roost.jpg")
			r.albedo_color = Color("#9a958c")
			r.uv1_triplanar = true
			r.uv1_world_triplanar = true
			r.uv1_scale = Vector3(0.12, 0.12, 0.12)
			r.normal_enabled = true
			r.normal_texture = Future._tex("res://assets/textures/floor_roost_n.png")
			r.roughness = 0.95
			r.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			m = r
		"water":
			var w := ShaderMaterial.new()
			w.shader = load("res://src/world/highland_water.gdshader")
			w.set_shader_parameter("noise_tex", Highland._noise_tex())
			w.set_shader_parameter("sun_dir", Highland._sun_dir(arena.theme.sun_rot))
			m = w
		"grass":
			var gm := ShaderMaterial.new()
			gm.shader = load("res://src/fx/grass_sway.gdshader")
			gm.set_shader_parameter("albedo_tex", Look.grass())
			m = gm
		"iron":
			m = Look.flat(Color("#2c2f33"), 0.55, 0.7)
		"wood":
			m = Look.flat(Color("#3b2d22"), 0.9)
	_mats[kind] = m
	return m

# ---------------------------------------------------------------- shared shapes
## A slab between four top corners (x0..x1, z0..z1) with its own heights, down to `bottom`.
static func _slab(sf: SurfaceTool, x0: float, x1: float, z0: float, z1: float, h00: float, h10: float, h01: float, h11: float, bottom: float) -> void:
	var t := [Vector3(x0, h00, z0), Vector3(x1, h10, z0), Vector3(x1, h11, z1), Vector3(x0, h01, z1)]
	var b := [Vector3(x0, bottom, z0), Vector3(x1, bottom, z0), Vector3(x1, bottom, z1), Vector3(x0, bottom, z1)]
	var mid := Vector3((x0 + x1) * 0.5, ((h00 + h11) * 0.5 + bottom) * 0.5, (z0 + z1) * 0.5)
	var quads := [[t[0], t[1], t[2], t[3]], [b[0], b[1], t[1], t[0]], [b[1], b[2], t[2], t[1]], [b[2], b[3], t[3], t[2]], [b[3], b[0], t[0], t[3]]]
	for qi in quads.size():
		var q: Array = quads[qi]
		var fc: Vector3 = ((q[0] as Vector3) + (q[1] as Vector3) + (q[2] as Vector3) + (q[3] as Vector3)) * 0.25
		var out: Vector3 = Vector3.UP if qi == 0 else Vector3(fc.x - mid.x, 0, fc.z - mid.z).normalized()
		for tri: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			var p0: Vector3 = tri[0]
			var p1: Vector3 = tri[1]
			var p2: Vector3 = tri[2]
			if (p1 - p0).cross(p2 - p0).dot(out) > 0.0:
				var sw := p1
				p1 = p2
				p2 = sw
			for v: Vector3 in [p0, p1, p2]:
				sf.set_normal(out)
				sf.add_vertex(v)

func _floors(section: int, pave: SurfaceTool, steps: SurfaceTool) -> void:
	var z_hi := float(SECTIONS[section][0])
	var z_lo := float(SECTIONS[section][1])
	for f: Array in FLOORS:
		var zc := (float(f[2]) + float(f[3])) * 0.5
		if zc > z_hi or zc <= z_lo:
			continue
		await _tick()
		var x0 := float(f[0])
		var x1 := float(f[1])
		var za := float(f[2])
		var zb := float(f[3])
		var n := int(f[6])
		var bottom := minf(float(f[4]), float(f[5])) - 1.6
		if section == 0:
			bottom = -14.0       # the bridge's deck stands on its own piers; this is its girder
		if n > 0:
			# treads: one slab per step, the riser faces drawn by the slab's own sides
			for s in n:
				var u0 := float(s) / n
				var u1 := float(s + 1) / n
				var h := lerpf(float(f[4]), float(f[5]), minf(float(s) / float(maxi(n - 1, 1)), 1.0))
				if str(f[7]) == "x":
					_slab(steps, lerpf(x0, x1, u0), lerpf(x0, x1, u1), za, zb, h, h, h, h, bottom)
				else:
					_slab(steps, x0, x1, lerpf(za, zb, u0), lerpf(za, zb, u1), h, h, h, h, bottom)
		else:
			var ha := float(f[4])
			var hb := float(f[5])
			if str(f[7]) == "x":
				_slab(pave, x0, x1, za, zb, ha, hb, ha, hb, bottom)
			else:
				_slab(pave, x0, x1, za, zb, ha, ha, hb, hb, bottom)

## The natural ground of a section: a height field in 2 m cells over the section's reach, with normals from the
## field itself.
func _terrain(n: Node3D, section: int) -> void:
	var z0 := float(SECTIONS[section][1]) - 2.0
	var z1 := float(SECTIONS[section][0]) + 2.0
	if section == SECTIONS.size() - 1:
		z0 = -262.0
	var x0 := -90.0
	var x1 := 44.0
	var cell := 2.0
	var nx := int((x1 - x0) / cell) + 1
	var nz := int((z1 - z0) / cell) + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for j in nz:
		await _tick()
		for i2 in nx:
			var x := x0 + i2 * cell
			var z := z0 + j * cell
			var h := terrain(x, z)
			verts.append(Vector3(x, h, z))
			var dx := terrain(x + 1.0, z) - terrain(x - 1.0, z)
			var dz := terrain(x, z + 1.0) - terrain(x, z - 1.0)
			norms.append(Vector3(-dx, 2.0, -dz).normalized())
	for j in nz - 1:
		for i2 in nx - 1:
			var a := j * nx + i2
			idx.append_array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = _mat("ground")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)

## Tufts of grass on the gentle turf of a rectangle, off the road and off the paving.
func _tufts(n: Node3D, x0: float, x1: float, z0: float, z1: float, count: int, seed_n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var blade := QuadMesh.new()
	blade.size = Vector2(0.55, 0.5)
	blade.center_offset = Vector3(0, 0.24, 0)
	mm.mesh = blade
	count = int(count * (0.6 if Future.low() else 1.0))
	var xf: Array = []
	for i in count:
		var x := rng.randf_range(x0, x1)
		var z := rng.randf_range(z0, z1)
		if not floor_at(x, z).is_empty() or absf(x - _road_x(z)) < 1.8:
			continue
		var h := terrain(x, z)
		if absf(terrain(x + 1.0, z) - h) > 0.6 or absf(terrain(x, z + 1.0) - h) > 0.6 or h < SEA + 6.0:
			continue
		var yaw := rng.randf() * PI
		var s := rng.randf_range(0.6, 1.5)
		for j in 2:
			xf.append(Transform3D(Basis(Vector3.UP, yaw + j * PI * 0.5).scaled(Vector3.ONE * s), Vector3(x, h - 0.04, z)))
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Tufts"
	mi.multimesh = mm
	mi.material_override = _mat("grass")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 60.0
	n.add_child(mi)

## Whether (x, z) is on or beside a way the knight walks, or in a stop's own place (kept clear of clutter).
static func near_way(x: float, z: float, clear: float = 1.9) -> bool:
	for i in ANCHORS.size():
		var a := anchor(i)
		if absf(x - a.x) < 5.0 and z < a.z + 5.0 and z > a.z - 7.0:
			return true
	for key: String in LEGS:
		var pts: Array = LEGS[key]
		for j in pts.size() - 1:
			var p0 := Vector2(float(pts[j][0]), float(pts[j][1]))
			var p1 := Vector2(float(pts[j + 1][0]), float(pts[j + 1][1]))
			var ab := p1 - p0
			var t := clampf((Vector2(x, z) - p0).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if (p0 + ab * t).distance_to(Vector2(x, z)) < clear:
				return true
	return false

## What has gathered on the paving of a yard since nobody swept it: turf in the joints and along the walls, broken
## stone, never on a way the knight walks or in a stop's own place.
func _clutter(n: Node3D, x0: float, x1: float, z0: float, z1: float, seed_n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var area := absf((x1 - x0) * (z1 - z0))
	var rocks: Array = []
	var grass: Array = []
	for i in int(area * 0.5):
		var x := rng.randf_range(x0, x1)
		var z := rng.randf_range(minf(z0, z1), maxf(z0, z1))
		var f := floor_at(x, z)
		if f.is_empty() or int(f[6]) > 0 or absf(float(f[4]) - float(f[5])) > 0.01 or near_way(x, z):
			continue
		var y := ground_y(x, z)
		# along the walls more than in the open
		var edge := minf(minf(x - x0, x1 - x), minf(absf(z - z0), absf(z1 - z)))
		if edge > 3.0 and rng.randf() < 0.7:
			continue
		if rng.randf() < 0.3:
			var s := rng.randf_range(0.12, 0.45)
			rocks.append(_rock_at(rng, Vector3(x, y - s * 0.3, z), Vector3(s * 1.4, s * 0.7, s)))
		else:
			var yaw := rng.randf() * PI
			var sc := rng.randf_range(0.5, 1.1)
			for j in 2:
				grass.append(Transform3D(Basis(Vector3.UP, yaw + j * PI * 0.5).scaled(Vector3.ONE * sc), Vector3(x, y - 0.02, z)))
	_rocks(n, rocks)
	if grass.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var blade := QuadMesh.new()
	blade.size = Vector2(0.55, 0.5)
	blade.center_offset = Vector3(0, 0.24, 0)
	mm.mesh = blade
	mm.instance_count = grass.size()
	for i in grass.size():
		mm.set_instance_transform(i, grass[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "JointTurf"
	mi.multimesh = mm
	mi.material_override = _mat("grass")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 50.0
	n.add_child(mi)

## Rock: faceted stones in one batch for a section.
func _rocks(n: Node3D, xf: Array) -> void:
	if xf.is_empty():
		return
	var mesh := Highland._crag_mesh(17)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Rocks"
	mi.multimesh = mm
	mi.material_override = _mat("rock")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)

static func _rock_at(rng: RandomNumberGenerator, at: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))).scaled(size), at)

## Water laid along `pts` (world points on the ground), `w` wide; steep runs foam.
func _water(n: Node3D, pts: Array, w: float, lift: float = 0.12) -> void:
	var sf := SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	var along := 0.0
	for i in pts.size():
		var p: Vector3 = pts[i]
		var q: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var o: Vector3 = pts[maxi(i - 1, 0)]
		var d := Vector2(q.x - o.x, q.z - o.z).normalized()
		var side := Vector3(-d.y, 0, d.x) * w * 0.5
		var steep := clampf(absf(p.y - q.y) / maxf(Vector2(p.x, p.z).distance_to(Vector2(q.x, q.z)), 0.01) / 1.1, 0.0, 1.0) if i < pts.size() - 1 else 1.0
		rows.append([p + side + Vector3(0, lift + steep * 0.4, 0), p - side + Vector3(0, lift + steep * 0.4, 0), along, steep])
		if i < pts.size() - 1:
			along += p.distance_to(q)
	for i in rows.size() - 1:
		var r0: Array = rows[i]
		var r1: Array = rows[i + 1]
		for tri: Array in [[[r0[0], 0.0, r0], [r0[1], 1.0, r0], [r1[0], 0.0, r1]], [[r0[1], 1.0, r0], [r1[1], 1.0, r1], [r1[0], 0.0, r1]]]:
			for v: Array in tri:
				var row: Array = v[2]
				sf.set_color(Color(float(row[3]), 0, 0, 1))
				sf.set_uv(Vector2(float(v[1]), float(row[2])))
				sf.set_normal(Vector3.UP)
				sf.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = sf.commit()
	mi.material_override = _mat("water")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)

## A portcullis: a grid of bars in a gate `w` wide and `h` high at `at` (middle of its sill), across x. Raised (up in
## its slot) when `open`. Its node is kept in `gates` for whoever animates it (Stage 3B).
func _portcullis(n: Node3D, gate: String, at: Vector3, w: float, h: float, open: bool) -> Node3D:
	var g := Node3D.new()
	g.name = "Gate_" + gate
	n.add_child(g)
	g.position = at + Vector3(0, h * 0.92 if open else 0.0, 0)
	var sf := Highland._flat_tool()
	var bars := int(w / 0.34)
	for i in bars + 1:
		Future._box(sf, Vector3(0.07, h, 0.07), Vector3(-w * 0.5 + i * w / bars, h * 0.5, 0))
	for j in int(h / 0.5):
		Future._box(sf, Vector3(w, 0.06, 0.1), Vector3(0, 0.3 + j * 0.5, 0))
	Highland._commit(g, "Bars", sf, _mat("iron"), true)
	g.set_meta("open", open)
	g.set_meta("rise", h * 0.92)
	gates[gate] = g
	return g

## Raises a portcullis that is down (the winch was turned). Stage 3B gives it its sound and its weight.
func open_gate(gate: String, secs: float = 3.0) -> void:
	var g: Node3D = gates.get(gate)
	if g == null or not is_instance_valid(g) or bool(g.get_meta("open", false)):
		return
	g.set_meta("open", true)
	create_tween().tween_property(g, "position:y", g.position.y + float(g.get_meta("rise")), secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ================================================================ the far layer (built once, always there)
func _far_layer() -> void:
	# the sea: a plane from the foot of the cliff to the horizon
	var sea := ShaderMaterial.new()
	sea.shader = load("res://src/world/highland_sea.gdshader")
	sea.set_shader_parameter("noise_tex", Highland._noise_tex())
	var img := Image.create(1, 1, false, Image.FORMAT_RF)
	img.set_pixel(0, 0, Color(-200.0, 0, 0))
	sea.set_shader_parameter("height_tex", ImageTexture.create_from_image(img))
	sea.set_shader_parameter("land_rect", Vector4(-2000, -2000, 1.0 / 4000.0, 1.0 / 4000.0))
	sea.set_shader_parameter("sea_level", SEA)
	sea.set_shader_parameter("sun_dir", Highland._sun_dir(arena.theme.sun_rot))
	sea.set_shader_parameter("haze", Color(arena.theme.horizon))
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400, 3000)
	var smi := MeshInstance3D.new()
	smi.name = "Sea"
	smi.mesh = pm
	smi.material_override = sea
	smi.position = Vector3(1210, SEA, -100)
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far.add_child(smi)
	# the far hills to the west: a coarse field beyond the sections' ground
	var sf := SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell := 12.0
	for j in 40:
		for i in 26:
			var x := -400.0 + i * cell
			var z := 120.0 - j * cell
			if x > -96.0 and x + cell < 50.0 and z < 74.0 and z - cell > -262.0:
				continue
			var q := [Vector3(x, terrain(x, z), z), Vector3(x + cell, terrain(x + cell, z), z), Vector3(x + cell, terrain(x + cell, z - cell), z - cell), Vector3(x, terrain(x, z - cell), z - cell)]
			for k2: int in [0, 2, 1, 0, 3, 2]:
				sf.add_vertex(q[k2])
	sf.generate_normals()
	var hm := MeshInstance3D.new()
	hm.name = "FarHills"
	hm.mesh = sf.commit()
	hm.material_override = _mat("ground")
	hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far.add_child(hm)
	# mountains all round and the sky that is not Earth's, brought out to the size of the whole route
	Future.into = far
	Future.ranges(arena, 0.7)
	Future.into = null
	var rg: Node3D = far.get_node_or_null("FuRanges")
	if rg:
		rg.position = Vector3(-60, -30, -90)
		rg.scale = Vector3(7.0, 5.5, 7.0)
		(rg as GeometryInstance3D).extra_cull_margin = 2000.0
	Future.sky(arena)
	for nm: String in ["FuPlanet", "FuOrbit"]:
		var s: Node3D = arena.get_node_or_null(nm)
		if s:
			s.reparent(far, false)
			s.position = s.position * 6.0 + Vector3(0, 0, -90)
			s.scale *= 6.0
	# the keep, its spires, the colossus on the ridge, the broken tether in the sea: what is seen ahead and behind
	var k := Future.Kit.new(arena, far)
	var keep_c := Vector3(0, 8.0, -256)
	Future.bulkhead(k, Vector3(-24, 8.0, -244), Vector3(24, 8.0, -244), 26.0, true, 0.05, 4.0, keep_c)
	Future._box(k.pale(true), Vector3(46, 30, 22), keep_c + Vector3(0, 15, -2))
	Future._box(k.alloy(true), Vector3(48, 2.0, 24), keep_c + Vector3(0, 30.5, -2))
	Future._box(k.pale(true), Vector3(30, 12, 16), keep_c + Vector3(0, 37.5, -4))
	Future._box(k.tool("lit"), Vector3(26, 0.25, 0.3), keep_c + Vector3(0, 26.0, 9.1))
	# the keep's face: setback bands, buttresses, slit windows with a little of the old light left in them
	for y2: float in [9.0, 18.0, 27.0]:
		Future._box(k.alloy(true), Vector3(47.0, 0.9, 1.2), keep_c + Vector3(0, y2, 9.4))
	for xb in range(-21, 22, 6):
		Future._box(k.alloy(true), Vector3(1.4, 30.0, 2.4), keep_c + Vector3(float(xb), 15.0, 9.6))
		for y3: float in [12.5, 21.5]:
			Future._box(k.tool("dim" if (xb + int(y3)) % 4 != 0 else "lit"), Vector3(0.5, 3.2, 0.2), keep_c + Vector3(float(xb) + 3.0, y3, 9.05))
	for sx: float in [-1.0, 1.0]:
		Future.spire(k, keep_c + Vector3(sx * 24.0, 0, 2.0), 52.0, 5.0, true, sx > 0.0, 0.3)
	Future.spire(k, keep_c + Vector3(-6, 30, -6), 46.0, 4.0, true, false, 0.9)
	Future.ring(k, keep_c + Vector3(0, 38.0, 9.0), 9.0, 0.8, 0.5, TAU - 0.5, true)
	Future.spire(k, Vector3(-62, 18, -170), 60.0, 5.6, true, false, 0.4)
	Future.spire(k, Vector3(-48, 14, -90), 34.0, 3.8, true, true, 1.1)
	# the broken tether far out in the sea
	var at := Vector3(240, SEA, -300)
	var y := 0.0
	for t: Array in [[10.0, 6.0, 90.0], [6.0, 3.6, 130.0], [3.6, 2.6, 120.0]]:
		Highland._prism(k.pale(true), at + Vector3(0, y, 0), float(t[0]), float(t[1]), float(t[2]), 6, 0.3)
		y += float(t[2])
		Highland._prism(k.alloy(true), at + Vector3(0, y - 1.0, 0), float(t[1]) * 1.2, float(t[1]) * 1.2, 2.0, 6, 0.3)
	k.commit()
	Future.into = far
	var col := Future.prop(arena, "fu_colossus", 46.0, Vector3(-150, terrain(-150, -120) - 3.0, -120), 70.0, 0.04, 0)
	Future.into = null
	if col:
		for mi: MeshInstance3D in col.find_children("*", "MeshInstance3D", true, false):
			mi.lod_bias = 0.1
	for g: GeometryInstance3D in far.find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_occluder(far, keep_c + Vector3(0, 15, -2), Vector3(44, 28, 20))

# ================================================================ the sections
## 0. The hillside: the door the knight comes out of, the causeway along the sea cliff, the ravine and its falls, the
## bridge, the dead trees and a dead walker by the road. Ahead the outer wall, the keep and the spires; behind the door.
func _hill(n: Node3D, k: Future.Kit) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4101
	_entry_door(n, k)
	# the road: worn slabs laid along the causeway, a hand above the turf, a kerb of light every 12 m
	var lane := Highland._flat_tool()
	var p := path(leg_points(-1, "intro"))
	for i in range(0, p.size() - 8, 8):
		var a: Vector3 = p[i]
		var b: Vector3 = p[i + 8]
		if floor_at(a.x, a.z).size() > 0:
			continue
		var dir := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var bas := Basis(Vector3.UP, atan2(-dir.x, -dir.z))
		var mid := (a + b) * 0.5
		Future._box(lane, Vector3(2.6 + rng.randf_range(-0.15, 0.15), 0.1, a.distance_to(b) + 0.06), mid + Vector3(0, 0.0, 0), bas * Basis(Vector3.RIGHT, atan2(a.y - b.y, 2.0)))
		if i % 48 == 0:
			for sx: float in [-1.0, 1.0]:
				var mp := mid + bas * Vector3(sx * 2.1, 0, 0)
				mp.y = terrain(mp.x, mp.z)
				Future.mast(k, mp, 2.4, true, 0.35)
		await _tick()
	Highland._commit(n, "Road", lane, _mat("pave"), false)
	# the ravine: the falls off the west hill, the stream across the gorge floor, over the sea cliff in one fall
	var falls: Array = []
	var x := -46.0
	while x < cliff_x(RAVINE_Z) + 7.0:
		var z := RAVINE_Z + sin(x * 0.11) * 1.2
		falls.append(Vector3(x, terrain(x, z), z))
		x += 1.0 if x < -26.0 or x > cliff_x(RAVINE_Z) - 2.0 else 2.0
	_water(n, falls, 3.0)
	await _tick()
	# the bridge's piers and rails (its deck is a floor)
	for z2: float in [-36.0, -43.0, -50.0]:
		Future._box(k.alloy(false), Vector3(0.8, 16.0, 0.8), Vector3(2.4, -5.0, z2))
		Future._box(k.alloy(false), Vector3(0.8, 16.0, 0.8), Vector3(6.6, -5.0, z2))
	for sx2: float in [2.3, 6.7]:
		Future._box(k.alloy(true), Vector3(0.12, 0.12, 19.0), Vector3(sx2, 3.7, -43.0))
		for z3 in range(-52, -33, 3):
			Future._box(k.alloy(true), Vector3(0.12, 0.95, 0.12), Vector3(sx2, 3.2, float(z3)))
		Future._box(k.tool("lamp"), Vector3(0.18, 0.18, 0.18), Vector3(sx2, 3.85, -33.8))
		Future._box(k.tool("lamp"), Vector3(0.18, 0.18, 0.18), Vector3(sx2, 3.95, -52.2))
	_lamp(n, Vector3(4.5, 4.4, -34.0), Color("#ffd29a"), 0.8, 6.0)
	# the cliff's broken lip and stacks in the sea; outcrops on the hill
	var rocks: Array = []
	var zc := 66.0
	while zc > -62.0:
		var cx := cliff_x(zc) + rng.randf_range(-1.5, 2.5)
		var s := rng.randf_range(1.8, 4.2)
		rocks.append(_rock_at(rng, Vector3(cx, terrain(cx, zc) - s * 0.3, zc), Vector3(s * 1.4, s, s * 1.2)))
		zc -= rng.randf_range(7.0, 13.0)
	for st: Array in [[52.0, 10.0, 8.0, 30.0], [70.0, -30.0, 10.0, 42.0], [44.0, -70.0, 6.0, 22.0], [90.0, 30.0, 9.0, 26.0]]:
		rocks.append(_rock_at(rng, Vector3(float(st[0]), SEA - 4.0, float(st[1])), Vector3(float(st[2]), float(st[3]), float(st[2]) * 0.9)))
	for i in 26:
		var rx := rng.randf_range(-70.0, -12.0)
		var rz := rng.randf_range(-58.0, 64.0)
		var rs := rng.randf_range(0.8, 3.0)
		rocks.append(_rock_at(rng, Vector3(rx, terrain(rx, rz) - rs * 0.35, rz), Vector3(rs * 1.3, rs * 0.8, rs)))
	# the ravine's walls
	for i in 10:
		var wx := rng.randf_range(-36.0, 16.0)
		for side: float in [-1.0, 1.0]:
			var wz := RAVINE_Z + side * rng.randf_range(5.0, 7.0)
			var ws := rng.randf_range(2.0, 3.5)
			rocks.append(_rock_at(rng, Vector3(wx, terrain(wx, wz) - ws * 0.6, wz), Vector3(ws * 1.5, ws * 1.3, ws)))
	_rocks(n, rocks)
	await _tick()
	# what lies by the road: two dead trees, a dead walker against a slab, a fallen length of ring in the turf
	await _prop(n, "road_dead_tree", 7.5, Vector3(-9.0, terrain(-9.0, 10.0), 10.0), 120.0, 0.0, 1)
	await _prop(n, "road_dead_tree", 6.0, Vector3(15.0, terrain(15.0, -16.0), -16.0), 30.0, 0.0, 0)
	await _prop(n, "fu_husk", 2.2, Vector3(-5.0, terrain(-5.0, -24.0), -24.0), 70.0, 0.05, 1)
	await _prop(n, "fu_wreck", 3.2, Vector3(-18.0, terrain(-18.0, 24.0), 24.0), 160.0, 0.08, 0)
	await _prop(n, "fu_pylon", 4.6, Vector3(-7.0, terrain(-7.0, -58.0), -58.0), 40.0, 0.04, 0)
	_tufts(n, -60.0, 16.0, -62.0, 66.0, 1500, 77)
	_lamp(n, Vector3(0.0, 2.6, 53.0), Color("#9ff0e0"), 1.0, 7.0)

## HOOK(Stage 1): the way out of the awakening chamber. A blast door in a rock face, its seam lit, standing open on
## the dark of the passage behind it. Replace with the chamber's real exit when Stage 1 hands it over.
func _entry_door(n: Node3D, k: Future.Kit) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var rocks: Array = []
	for i in 9:
		var sx := (float(i) - 4.0) * 4.2
		var s := rng.randf_range(5.0, 8.0)
		rocks.append(_rock_at(rng, Vector3(sx, terrain(sx, 62.0) - 1.0, 62.0 + absf(sx) * 0.3), Vector3(s * 1.1, s * 1.5, s)))
	_rocks(n, rocks)
	var at := Vector3(0, 0, 58.6)
	for sx2: float in [-1.0, 1.0]:
		Highland._beam(k.alloy(false), at + Vector3(sx2 * 2.4, -0.2, 0), at + Vector3(sx2 * 2.0, 5.2, 0), 0.9, 1.4)
		Future._box(k.pale(false), Vector3(1.1, 4.6, 0.3), at + Vector3(sx2 * 2.35, 2.3, -0.3))
	Future._box(k.alloy(false), Vector3(6.6, 1.0, 1.6), at + Vector3(0, 5.4, 0))
	Future._box(k.tool("dark"), Vector3(3.4, 4.6, 0.2), at + Vector3(0, 2.3, 1.2))
	Future._box(k.tool("lit"), Vector3(4.0, 0.08, 0.06), at + Vector3(0, 4.95, -0.82))
	for sx3: float in [-1.0, 1.0]:
		Future._box(k.tool("lit"), Vector3(0.08, 4.4, 0.06), at + Vector3(sx3 * 1.75, 2.3, -0.5))

## 1. The outer wall and its breach, the rubble yard, the guardhouse (a room of its own), the stair to the wall-walk,
## the fallen head in the rubble, the lane to the postern.
func _outer(n: Node3D, k: Future.Kit) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5202
	var yard := Vector3(0, 3.2, -92)
	# the outer wall, broken in the middle where the plates came down into the yard
	Future.bulkhead(k, Vector3(-40, 3.0, -76.5), Vector3(-4.6, 3.0, -76.5), 9.0, false, 0.15, 6.0, yard)
	Future.bulkhead(k, Vector3(4.6, 3.0, -76.5), Vector3(24, 3.0, -76.5), 9.0, false, 0.15, 6.0, yard)
	for sx: float in [-1.0, 1.0]:
		# the torn ends of the wall at the breach, and the plates that came down
		Future._box(k.alloy(false), Vector3(1.2, 6.0, 1.6), Vector3(sx * 5.2, 6.0, -76.5), Basis(Vector3.FORWARD, sx * 0.12))
		Future._box(k.pale(false), Vector3(3.0, 0.5, 2.4), Vector3(sx * 3.2, 3.5, -78.6), Basis.from_euler(Vector3(0.3, sx * 0.5, sx * 0.25)))
	_occluder(n, Vector3(-22.0, 7.5, -76.5), Vector3(34, 9, 1.2))
	_occluder(n, Vector3(14.0, 7.5, -76.5), Vector3(19, 9, 1.2))
	await _prop(n, "rubble", 2.6, Vector3(-3.9, 3.0, -78.6), 30.0, 0.1, 1)
	await _prop(n, "rubble", 2.2, Vector3(4.2, 3.0, -78.0), 200.0, 0.1, 1)
	await _prop(n, "rubble", 1.5, Vector3(-2.6, 3.0, -75.4), 120.0, 0.1, 1)
	await _prop(n, "rubble", 1.2, Vector3(2.8, 3.2, -81.2), 280.0, 0.1, 1)
	await _prop(n, "rubble", 1.1, Vector3(-9.0, 3.2, -85.0), 110.0, 0.1)
	await _prop(n, "rubble", 1.4, Vector3(9.5, 3.2, -103.0), 300.0, 0.1)
	# the yard's west wall, and the east curtain the wall-walk runs on
	Future.bulkhead(k, Vector3(-17.0, 3.2, -77.0), Vector3(-17.0, 3.2, -96.0), 7.0, false, 0.1, 5.0, yard)
	Future._box(k.pale(false), Vector3(1.6, 6.6, 50.0), Vector3(16.4, 6.5, -101.0))
	Future._box(k.alloy(false), Vector3(0.5, 1.2, 50.0), Vector3(15.7, 8.4, -101.0))
	for z in range(-80, -124, -4):
		Future._box(k.alloy(false), Vector3(0.8, 1.6, 0.6), Vector3(15.8, 9.0, float(z)))
	for z2 in range(-82, -124, -6):
		Future._box(k.alloy(false), Vector3(1.0, 7.0, 0.8), Vector3(15.2, 6.7, float(z2)))
	Future._box(k.tool("lit"), Vector3(0.06, 0.07, 44.0), Vector3(15.55, 7.0, -101.0))
	_occluder(n, Vector3(16.4, 6.5, -101.0), Vector3(1.4, 6.4, 48.0))
	# the stair's side wall and the wall-walk's inner rail
	Future._box(k.alloy(false), Vector3(0.4, 1.0, 7.5), Vector3(11.8, 8.3, -113.25))
	Future._box(k.pale(false), Vector3(0.6, 2.6, 12.0), Vector3(11.6, 4.2, -103.5))
	await _tick()
	# the guardhouse: a room of its own, its door hanging from one hinge (x -16..-8, z -96..-106)
	var gh := Vector3(-12.0, 3.2, -101.0)
	var wall := k.pale(false)
	Future._box(wall, Vector3(8.4, 4.2, 0.5), gh + Vector3(0, 2.1, 5.0))
	Future._box(wall, Vector3(8.4, 4.2, 0.5), gh + Vector3(0, 2.1, -5.0))
	Future._box(wall, Vector3(0.5, 4.2, 10.4), gh + Vector3(-4.0, 2.1, 0))
	Future._box(wall, Vector3(0.5, 4.2, 4.0), gh + Vector3(4.0, 2.1, 3.1))
	Future._box(wall, Vector3(0.5, 4.2, 4.0), gh + Vector3(4.0, 2.1, -3.1))
	Future._box(wall, Vector3(0.5, 1.0, 2.2), gh + Vector3(4.0, 3.7, 0))
	Future._box(k.alloy(false), Vector3(9.2, 0.5, 11.2), gh + Vector3(0, 4.4, 0), Basis(Vector3.RIGHT, 0.04))
	Future._box(k.tool("dark"), Vector3(0.1, 3.0, 1.1), gh + Vector3(4.6, 1.5, 1.45), Basis(Vector3.UP, 1.1))
	for z3: float in [-3.6, 3.6]:
		Future.console(k, gh + Vector3(-2.6, 0, z3), 90.0, 2.0)
	Future._box(k.tool("dim"), Vector3(0.06, 0.6, 1.4), gh + Vector3(-3.7, 2.6, 0))
	_lamp(n, gh + Vector3(-1.0, 3.3, 0), Color("#ffc890"), 1.2, 6.5)
	_occluder(n, gh + Vector3(0, 2.1, 0), Vector3(7.4, 3.8, 9.4))
	# the fallen head in the rubble (where the Witness is found), the old wall lengths, a wreck
	await _prop(n, "statue_head", 2.4, MONUMENT + Vector3(0.6, 0, -0.4), -50.0, 0.04, 1)
	await _prop(n, "fu_wall", 5.8, Vector3(-13.0, 3.2, -86.0), 90.0, 0.03, 1)
	await _prop(n, "fu_wreck", 2.4, Vector3(6.5, 3.2, -82.5), 140.0, 0.05, 1)
	await _prop(n, "fu_pylon", 4.2, Vector3(-6.0, 3.2, -104.5), 20.0, 0.03, 1)
	for sx4: float in [-1.0, 1.0]:
		Future.beacon(k, Vector3(sx4 * 5.5, 3.2, -88.0 + sx4 * 2.0), 2.4, sx4 * 15.0)
	_lamp(n, Vector3(-5.5, 5.3, -90.0), Color(arena.theme.fire), 1.6, 8.0, true)
	_lamp(n, Vector3(5.5, 5.3, -86.0), Color(arena.theme.fire), 1.6, 8.0, true)
	# the lane up behind the barbican, to the postern of the winch yard
	Future.bulkhead(k, Vector3(-17.0, 3.2, -96.0), Vector3(-17.0, 4.5, -137.0), 6.5, false, 0.1, 4.0, Vector3(-13, 4, -120))
	var rocks: Array = []
	for i in 14:
		var rx := rng.randf_range(-12.0, 12.0)
		var rz := rng.randf_range(-81.0, -104.0)
		if absf(rx) < 3.5 or (rx > 10.0 and rz < -94.0):
			continue
		var rs := rng.randf_range(0.3, 0.8)
		rocks.append(_rock_at(rng, Vector3(rx, 3.2 - rs * 0.2, rz), Vector3(rs * 1.4, rs * 0.7, rs)))
	# the fallen plates' broken stone heaped in the breach, either side of the way through
	for i in 16:
		var side := -1.0 if i % 2 == 0 else 1.0
		var bx := side * rng.randf_range(1.8, 5.0)
		var bz := rng.randf_range(-74.5, -81.0)
		var bs := rng.randf_range(0.35, 1.0)
		rocks.append(_rock_at(rng, Vector3(bx, ground_y(bx, bz) - bs * 0.25, bz), Vector3(bs * 1.5, bs * 0.8, bs * 1.1)))
	_rocks(n, rocks)
	_tufts(n, -60.0, 30.0, -62.0, -110.0, 500, 78)
	_clutter(n, -16.0, 15.5, -56.0, -106.0, 61)

## 2. The barbican: two towers and the gate between them under a banner, its forecourt, the down-stair from the
## wall-walk. The block hides what is beyond it from the yard.
func _barbican(n: Node3D, k: Future.Kit) -> void:
	var c := Vector3(0, 4.5, -131.0)
	for sx: float in [-1.0, 1.0]:
		Future.spire(k, c + Vector3(sx * 6.2, 0, 0), 17.0, 3.4, false, sx > 0.0, 0.52)
	Future._box(k.pale(false), Vector3(8.8, 4.0, 10.0), c + Vector3(0, 7.5, 0))
	for sx2: float in [-1.0, 1.0]:
		Future._box(k.pale(false), Vector3(3.2, 5.6, 10.0), c + Vector3(sx2 * 4.2, 2.8, 0))
	Future._box(k.alloy(false), Vector3(9.4, 0.6, 10.6), c + Vector3(0, 9.7, 0))
	Future._box(k.alloy(false), Vector3(5.6, 0.7, 0.8), c + Vector3(0, 5.6, 4.8))
	Future._box(k.tool("lit"), Vector3(4.4, 0.08, 0.06), c + Vector3(0, 5.2, 5.25))
	# the flank walls out to the curtain and the lane
	Future._box(k.pale(false), Vector3(6.0, 6.0, 1.4), c + Vector3(-12.0, 3.0, 2.0))
	Future._box(k.pale(false), Vector3(4.4, 6.0, 1.4), c + Vector3(11.0, 3.0, 2.0))
	_occluder(n, c + Vector3(0, 5.0, 0), Vector3(14.0, 10.0, 9.0))
	_clutter(n, -12.0, 12.0, -106.0, -127.0, 62)
	# the banner that still flies, hung on the face of the west tower beside the gate (the banneret stands under it)
	await _prop(n, "banner", 4.6, c + Vector3(-4.2, 1.4, 5.4), 0.0, 0.0, 0)
	Future._box(k.alloy(false), Vector3(2.0, 0.16, 0.5), c + Vector3(-4.2, 6.1, 5.3))
	for sx3: float in [-1.0, 1.0]:
		Future.beacon(k, Vector3(sx3 * 4.6, 4.5, -125.4), 2.5, sx3 * 20.0)
		_lamp(n, Vector3(sx3 * 4.6, 6.6, -125.4), Color(arena.theme.fire), 1.8, 8.0, true)
	await _prop(n, "fu_pylon", 4.0, Vector3(-9.5, 4.5, -116.0), 30.0, 0.03, 1)
	# the stair down from the wall-walk: its outer wall
	Future._box(k.pale(false), Vector3(8.0, 4.0, 0.6), Vector3(8.5, 6.5, -117.4))
	Future._box(k.alloy(false), Vector3(7.6, 0.5, 0.3), Vector3(8.5, 6.6, -114.4), Basis(Vector3.FORWARD, -0.44))
	_lamp(n, c + Vector3(0, 3.2, -1.0), Color("#ffc890"), 1.0, 6.0)

## 3. The winch yard: the winch-house with its drum and chain, the well, the postern (the winch gate) and the inner
## wall with its gate and portcullis, the gate passage under its murder holes, and the hidden room off it.
func _winch(n: Node3D, k: Future.Kit) -> void:
	var open: bool = Game.profile.get("flags", {}).has("courtyard_gate") if not Game.profile.is_empty() else false
	var c := Vector3(0, 5.5, -147.0)
	# the yard's walls
	Future.bulkhead(k, Vector3(-16.0, 5.5, -139.0), Vector3(-16.0, 5.5, -157.0), 7.0, false, 0.1, 4.0, c)
	Future.bulkhead(k, Vector3(12.5, 5.5, -137.0), Vector3(12.5, 5.5, -157.0), 7.0, false, 0.1, 4.0, c)
	# the inner wall and its gate
	for sx: float in [-1.0, 1.0]:
		Future._box(k.pale(false), Vector3(13.0, 9.0, 2.0), Vector3(sx * 9.5, 10.0, -158.0))
		Future._box(k.alloy(false), Vector3(1.4, 10.0, 2.6), Vector3(sx * 3.6, 10.5, -158.0))
	Future._box(k.pale(false), Vector3(6.0, 3.2, 2.0), Vector3(0, 12.9, -158.0))
	Future._box(k.tool("lit"), Vector3(5.0, 0.08, 0.06), Vector3(0, 11.3, -156.95))
	_occluder(n, Vector3(-9.5, 10.0, -158.0), Vector3(12.6, 8.6, 1.6))
	_occluder(n, Vector3(9.5, 10.0, -158.0), Vector3(12.6, 8.6, 1.6))
	_portcullis(n, "inner", Vector3(0, 5.5, -157.2), 5.8, 5.6, open)
	# the postern at the head of the lane: the winch gate
	_portcullis(n, "postern", Vector3(-13.25, 5.5, -137.6), 4.4, 4.0, open)
	Future._box(k.alloy(false), Vector3(5.6, 1.2, 1.2), Vector3(-13.25, 10.0, -137.6))
	# the winch-house: open to the yard, a drum on its axle, the chain running to the gate
	var wh := Vector3(-9.0, 5.5, -144.5)
	Future._box(k.pale(false), Vector3(0.5, 4.6, 8.4), wh + Vector3(-3.0, 2.3, 0))
	Future._box(k.pale(false), Vector3(6.0, 4.6, 0.5), wh + Vector3(0, 2.3, 4.2))
	Future._box(k.pale(false), Vector3(6.0, 4.6, 0.5), wh + Vector3(0, 2.3, -4.2))
	Future._box(k.alloy(false), Vector3(6.8, 0.5, 9.2), wh + Vector3(0, 4.8, 0))
	var drum := Highland._flat_tool()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.75
	cy.bottom_radius = 0.75
	cy.height = 3.2
	cy.radial_segments = 14
	drum.append_from(cy, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), wh + Vector3(-1.0, 1.4, 0)))
	Future._box(drum, Vector3(0.3, 1.6, 0.3), wh + Vector3(-1.0, 0.7, 1.7))
	Future._box(drum, Vector3(0.3, 1.6, 0.3), wh + Vector3(-1.0, 0.7, -1.7))
	Highland._commit(n, "Drum", drum, _mat("iron"), true)
	Highland._beam(k.alloy(false), wh + Vector3(-1.0, 2.1, -0.5), Vector3(-2.9, 9.0, -157.0), 0.12)
	_lamp(n, wh + Vector3(1.0, 3.6, 0), Color("#ffc890"), 1.0, 6.0)
	# the well
	var well := Highland._flat_tool()
	var ring := CylinderMesh.new()
	ring.top_radius = 1.1
	ring.bottom_radius = 1.2
	ring.height = 0.9
	ring.radial_segments = 16
	well.append_from(ring, 0, Transform3D(Basis.IDENTITY, Vector3(8.2, 5.95, -144.5)))
	Highland._commit(n, "Well", well, _mat("pave"), true)
	var water := Highland._flat_tool()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.95
	disc.bottom_radius = 0.95
	disc.height = 0.02
	water.append_from(disc, 0, Transform3D(Basis.IDENTITY, Vector3(8.2, 6.3, -144.5)))
	Highland._commit(n, "WellWater", water, Look.flat(Color("#102026"), 0.1, 0.2), false)
	await _prop(n, "fu_engine", 2.8, Vector3(8.6, 5.5, -152.0), 210.0, 0.06, 1)
	_clutter(n, -15.5, 12.0, -137.0, -157.0, 63)
	await _tick()
	# the gate passage: walls, a roof with its murder holes, lamps
	for sx2: float in [-1.0, 1.0]:
		Future._box(k.pale(false), Vector3(0.8, 6.4, 17.0), Vector3(sx2 * 3.4, 8.9, -167.5))
		Future._box(k.alloy(false), Vector3(0.3, 0.1, 16.0), Vector3(sx2 * 2.95, 8.2, -167.5))
		_occluder(n, Vector3(sx2 * 3.4, 8.9, -167.5), Vector3(0.6, 6.0, 16.0))
	for j in 4:
		var z := -160.5 - j * 4.0
		Future._box(k.alloy(false), Vector3(7.6, 0.8, 3.0), Vector3(0, 12.4, z))
		Future._box(k.tool("lit2"), Vector3(0.05, 0.05, 2.2), Vector3(-2.9, 8.2, z))
	_occluder(n, Vector3(0, 12.6, -167.5), Vector3(7.0, 0.6, 16.0))
	_lamp(n, Vector3(0, 10.0, -162.0), Color("#9fe8f0"), 0.9, 7.0)
	_lamp(n, Vector3(0, 10.2, -172.0), Color("#9fe8f0"), 0.9, 7.0)
	# the murder hole: a loose stone pushed aside, a low room behind it with a ladder up to the holes in the roof
	var mh := Vector3(5.4, 5.68, -163.4)
	Future._box(k.pale(false), Vector3(5.2, 3.0, 0.4), mh + Vector3(0, 1.5, 2.8))
	Future._box(k.pale(false), Vector3(5.2, 3.0, 0.4), mh + Vector3(0, 1.5, -2.8))
	Future._box(k.pale(false), Vector3(0.4, 3.0, 5.6), mh + Vector3(2.6, 1.5, 0))
	Future._box(k.alloy(false), Vector3(5.6, 0.4, 6.0), mh + Vector3(0, 3.2, 0))
	Future._box(k.pale(false), Vector3(0.9, 0.9, 0.35), Vector3(3.6, 6.1, -161.9), Basis(Vector3.UP, 0.7))
	for r in 8:
		Future._box(_mat_tool(k, "wood"), Vector3(0.9, 0.06, 0.06), mh + Vector3(1.6, 0.35 + r * 0.36, -2.3))
	_lamp(n, mh + Vector3(0, 2.2, 0), Color("#ffb070"), 0.7, 4.0)

func _mat_tool(k: Future.Kit, nm: String) -> SurfaceTool:
	return k.tool("dark") if nm == "wood" else k.alloy(false)

## 4. The chapel court with its alcove against the keep's outer wall, the steps up into the inner ward, and the
## ward itself: the kneeling guardian, an engine in the deck, pylons and beacons, the front of the keep.
func _ward(n: Node3D, k: Future.Kit) -> void:
	var c := Vector3(0, 8.0, -218.0)
	# the chapel court's walls
	Future.bulkhead(k, Vector3(-12.8, 6.2, -176.0), Vector3(-12.8, 6.2, -192.0), 7.4, false, 0.0, 3.0, Vector3(0, 6, -184))
	Future.bulkhead(k, Vector3(12.8, 6.2, -176.0), Vector3(12.8, 6.2, -192.0), 7.4, false, 0.0, 3.0, Vector3(0, 6, -184))
	for sx: float in [-1.0, 1.0]:
		Future._box(k.pale(false), Vector3(9.4, 7.0, 1.6), Vector3(sx * 8.2, 9.7, -176.6))
	# the alcove: three walls, ribs over it, a seat of stone, light from the old make
	var al := Vector3(-9.0, 6.2, -187.0)
	Future._box(k.pale(false), Vector3(0.6, 5.0, 7.0), al + Vector3(-2.9, 2.5, 0))
	Future._box(k.pale(false), Vector3(5.0, 5.0, 0.6), al + Vector3(-0.5, 2.5, 3.3))
	Future._box(k.pale(false), Vector3(5.0, 5.0, 0.6), al + Vector3(-0.5, 2.5, -3.3))
	for zr: float in [-2.0, 0.0, 2.0]:
		Highland._beam(k.alloy(false), al + Vector3(-2.7, 3.2, zr), al + Vector3(1.2, 5.4, zr), 0.3, 0.4)
	Future._box(k.alloy(false), Vector3(5.6, 0.4, 7.4), al + Vector3(-0.6, 5.5, 0), Basis(Vector3.FORWARD, -0.2))
	Future._box(k.tool("dim"), Vector3(0.05, 2.6, 0.08), al + Vector3(-2.55, 2.6, 0))
	_lamp(n, al + Vector3(0.6, 2.8, 0), Color("#ffcf9a"), 1.1, 6.0)
	# the steps' side blocks and beacons
	for sx2: float in [-1.0, 1.0]:
		Future._box(k.alloy(false), Vector3(1.4, 2.4, 6.4), Vector3(sx2 * 10.7, 7.2, -195.0))
		Future.beacon(k, Vector3(sx2 * 10.7, 8.4, -195.0), 2.2, 0.0)
	await _tick()
	# the ward's walls, the gatehouse ruin the embers drift from, the front of the keep
	Future.bulkhead(k, Vector3(-21.5, 8.0, -198.0), Vector3(-21.5, 8.0, -240.0), 9.5, false, 0.2, 6.0, c)
	Future.bulkhead(k, Vector3(21.5, 8.0, -198.0), Vector3(21.5, 8.0, -240.0), 9.5, false, 0.2, 6.0, c)
	for sx3: float in [-1.0, 1.0]:
		Future._box(k.pale(false), Vector3(10.0, 12.0, 2.0), Vector3(sx3 * 16.5, 14.0, -197.5))
	_occluder(n, Vector3(-16.5, 14.0, -197.5), Vector3(9.6, 11.6, 1.6))
	_occluder(n, Vector3(16.5, 14.0, -197.5), Vector3(9.6, 11.6, 1.6))
	Future._box(k.alloy(false), Vector3(16.0, 2.0, 3.0), Vector3(0, 20.6, -197.5))
	_clutter(n, -12.0, 12.0, -176.0, -192.0, 64)
	_clutter(n, -21.0, 21.0, -198.0, -240.0, 65)
	await _prop(n, "fu_colossus", 7.6, Vector3(-13.5, 8.0, -224.0), 60.0, 0.02, 1)
	await _prop(n, "fu_engine", 4.0, Vector3(13.5, 8.0, -222.0), -60.0, 0.06, 0)
	await _prop(n, "fu_husk", 2.0, Vector3(9.0, 8.0, -205.0), -30.0, 0.05, 1)
	for py: Array in [[-8.0, -214.0, 4.4, 10.0], [8.0, -215.0, 3.8, -15.0], [-15.0, -206.0, 4.6, 20.0], [15.0, -232.0, 4.0, -10.0]]:
		await _prop(n, "fu_pylon", float(py[2]), Vector3(float(py[0]), 8.0, float(py[1])), float(py[3]) + 180.0, 0.03, 0)
	for sx4: float in [-1.0, 1.0]:
		Future.beacon(k, Vector3(sx4 * 4.2, 8.0, -216.0), 2.5, sx4 * 20.0)
		_lamp(n, Vector3(sx4 * 4.2, 10.1, -216.0), Color(arena.theme.fire), 2.0, 9.0, true)
		Future.mast(k, Vector3(sx4 * 18.0, 8.0, -236.0), 7.5)
	await _prop(n, "fu_tower", 18.0, Vector3(-18.0, 8.0, -246.0), 20.0, 0.02, 0)
	Future.door(k, Vector3(0, 8.0, -243.2), 6.0, 7.0)
	# embers from the gatehouse ruin (the Sentinel's post)
	var em := CPUParticles3D.new()
	em.amount = 24 if Future.low() else 40
	em.lifetime = 5.0
	em.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	em.emission_box_extents = Vector3(10, 0.5, 8)
	em.direction = Vector3(0, 1, 0)
	em.spread = 30.0
	em.initial_velocity_min = 0.2
	em.initial_velocity_max = 0.6
	em.gravity = Vector3(0.1, 0.05, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	q.material = Look.particle(Color(arena.theme.fire))
	em.mesh = q
	em.position = Vector3(0, 8.4, -220.0)
	n.add_child(em)

# ================================================================ the air of each place
## Fog and light drift toward each place's own: clear and wide on the hill, closer in the yards, dim in the passage,
## warm and hazed in the ward.
const AIR := [
	{"fog": 0.0024, "fog_c": "#b4c6d4", "amb": 0.95, "sun": 2.1},
	{"fog": 0.0045, "fog_c": "#a8bccc", "amb": 0.95, "sun": 2.1},
	{"fog": 0.005, "fog_c": "#a4b4c0", "amb": 0.92, "sun": 2.0},
	{"fog": 0.007, "fog_c": "#8c9aa6", "amb": 0.85, "sun": 1.9},
	{"fog": 0.006, "fog_c": "#b8a898", "amb": 0.9, "sun": 2.0},
]
func _air(dt: float) -> void:
	if arena == null or arena.env == null:
		return
	var a: Dictionary = AIR[clampi(zone, 0, AIR.size() - 1)]
	var k := 1.0 - exp(-dt * 0.6)
	arena.env.fog_density = lerpf(arena.env.fog_density, float(a.fog), k)
	arena.env.fog_light_color = arena.env.fog_light_color.lerp(Color(str(a.fog_c)), k)
	arena.env.ambient_light_energy = lerpf(arena.env.ambient_light_energy, float(a.amb), k)
	arena.sun.light_energy = lerpf(arena.sun.light_energy, float(a.sun), k)

# ================================================================ the road screen's place
## (Call before `setup`: the place is built in the tree; `setup` gives the Backdrop its arena.)
## A Backdrop standing in this place: the knight (dressed as equipped), the camera, the key light; the route is its
## arena, so everything that reads `backdrop.arena` (theme, fire colour) reads the Courtyard's.
func make_backdrop() -> Backdrop:
	var bd := Backdrop.new()
	bd.add_child(self)
	bd._theme = "courtyard"
	bd.props = Node3D.new()
	bd.props.name = "Props"
	bd.add_child(bd.props)
	bd.key = SpotLight3D.new()
	bd.key.light_energy = 0.0
	bd.add_child(bd.key)
	bd.cam = Camera3D.new()
	bd.cam.fov = 50.0
	bd.cam.far = 4000.0
	bd.add_child(bd.cam)
	return bd

## HOOK(Stage 1): where the Witness's follow behaviour plugs in once it has a companion API (it flies ahead to the
## next stop's points of interest; Explore passes it `WitnessDrone.set_points` today).
func witness_hook() -> Array:
	return [MONUMENT]

## HOOK(Stage 3B): where each fight of the road is met (the stop's anchor and the way the foe will come from).
static func foe_spots() -> Dictionary:
	return {0: {"enter": "climbs the breach rubble", "from": Vector3(0, 3.75, -78.5)},
		1: {"enter": "drops from the wall-walk", "from": Vector3(13.0, 7.8, -111.0)},
		2: {"enter": "steps out of the barbican door", "from": Vector3(0, 4.5, -128.0)},
		4: {"enter": "the portcullis is raised by the winch; marches out of the passage", "from": Vector3(0, 5.6, -166.0)},
		6: {"enter": "rises from kneeling", "from": Vector3(0, 8.0, -212.2)}}

## The render cost of the frame just drawn (software renderer here; nothing has run on a phone).
static func cost_line() -> String:
	return "draws=%d primitives=%d objects=%d video_mem=%.1fMB" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0]
