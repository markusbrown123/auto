class_name SwipeInput
extends Control
## Turns touches into eight-way swipes. A swipe fires the moment the finger
## has travelled far and fast enough — not on release — so cuts feel immediate.
## Slow drags and short jitters are ignored, so resting a thumb is safe.

signal swiped(dir: String, vec: Vector2)

const NAMES := ["R", "UR", "U", "UL", "L", "DL", "D", "DR"]
var min_dist_frac := 0.085     # of the shorter screen side
var max_time := 0.35           # the distance must be covered within this
var min_speed_frac := 0.55     # screen-heights per second
var _touch := {}               # index -> {pos, t, path:[...]}

# ---- the on-screen trail of a finger or the mouse (drawn by this control, which lies in the HUD layer above the 3D view)
# One trail per finger, each a fixed ring of recent touch points. The points are smoothed (cubic Hermite, tangents from
# the neighbouring points) and drawn as a strip of quads: the head, at the finger, is the wide end; it tapers to a point
# at the tail; a thin brighter core runs down the middle. Points older than TRAIL_LIFE drop off the tail, and a trail
# whose finger has lifted fades out over TRAIL_FADE. Nothing here reads or changes the swipe recognition below.
const TRAIL_CAP := 28           # raw points kept per finger
const TRAIL_SLOTS := 5          # fingers drawn at once
const TRAIL_LIFE := 0.30        # seconds a point stays on the tail
const TRAIL_FADE := 0.30        # seconds for a released trail to go
const TRAIL_WIDTH := 50.0       # at the head, in the 720-high design space
const TRAIL_ALPHA := 0.4        # of the body at the head
const TRAIL_SUB := 3            # smoothed samples per raw segment
const TRAIL_MIN_STEP := 2.0     # a point nearer than this to the last is not kept (a resting thumb leaves nothing)
var _tr_idx: PackedInt32Array = PackedInt32Array()
var _tr_pts := PackedVector2Array()      # TRAIL_SLOTS rings of TRAIL_CAP points, slot after slot
var _tr_ts := PackedFloat32Array()       # the game time of each
var _tr_head := PackedInt32Array()
var _tr_n := PackedInt32Array()
var _tr_rel := PackedFloat32Array()      # game time the finger lifted, -1 while down
# scratch for one trail's samples, reused every frame
var _sp := PackedVector2Array()
var _sl := PackedVector2Array()
var _sr := PackedVector2Array()
var _sc := PackedFloat32Array()
var _quad := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _quad_c := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
var _quad_uv := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _trails_live := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_tr_idx.resize(TRAIL_SLOTS)
	_tr_idx.fill(-1)
	_tr_head.resize(TRAIL_SLOTS)
	_tr_n.resize(TRAIL_SLOTS)
	_tr_rel.resize(TRAIL_SLOTS)
	_tr_rel.fill(-1.0)
	_tr_pts.resize(TRAIL_SLOTS * TRAIL_CAP)
	_tr_ts.resize(TRAIL_SLOTS * TRAIL_CAP)
	var m := TRAIL_CAP * TRAIL_SUB + 1
	_sp.resize(m)
	_sl.resize(m)
	_sr.resize(m)
	_sc.resize(m)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touch[e.index] = {"pos": e.position, "t": _now(), "last": Vector2.ZERO}
			_trail_begin(e.index, e.position)
		else:
			_touch.erase(e.index)
			_trail_end(e.index)
	elif e is InputEventScreenDrag and _touch.has(e.index):
		_trail_add(e.index, e.position)
		var s: Dictionary = _touch[e.index]
		var d: Vector2 = e.position - s.pos
		var dt: float = _now() - s.t
		var side: float = minf(size.x, size.y)
		if dt > max_time:
			# too slow to be a cut: re-anchor so a later flick still counts
			s.pos = e.position
			s.t = _now()
			return
		var sens: float = clampf(float(Game.settings.get("swipe_sens", 1.0)), 0.5, 1.5)      # higher = shorter, slower strokes count
		if d.length() >= side * min_dist_frac / sens and d.length() / maxf(dt, 0.001) >= side * min_speed_frac / sens:
			var v := Vector2(d.x, -d.y).normalized()
			# One stroke is one cut, however long it is. Without lifting the
			# finger, only a clear change of direction (a zig-zag) chains another.
			if s.last == Vector2.ZERO or v.dot(s.last) < 0.3:
				swiped.emit(quantize(v), v)
				s.last = v
			s.pos = e.position
			s.t = _now()

var _clock := 0.0               # game time, not the wall clock: a stroke is judged by frames played, so a slow machine (or a test) reads it the same way

func _process(delta: float) -> void:
	_clock += minf(delta, 0.1)    # one long hitch must not expire a stroke that was quick in the player's hand
	if _trails_live:
		_trails_tick()
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _tr_idx.size() == TRAIL_SLOTS:
		for i: int in TRAIL_SLOTS:        # a trail must not hang over the pause screen
			_tr_idx[i] = -1
			_tr_n[i] = 0
		_trails_live = false
		queue_redraw()

# ---------------------------------------------------------------- the trail
func _trail_slot(index: int) -> int:
	for i: int in TRAIL_SLOTS:
		if _tr_idx[i] == index and _tr_rel[i] < 0.0:
			return i
	return -1

func _trail_begin(index: int, pos: Vector2) -> void:
	var slot := -1
	for i: int in TRAIL_SLOTS:       # a free slot, else the one that has been fading longest
		if _tr_n[i] == 0:
			slot = i
			break
	if slot < 0:
		slot = 0
		for i: int in TRAIL_SLOTS:
			if _tr_rel[i] >= 0.0 and (_tr_rel[slot] < 0.0 or _tr_rel[i] < _tr_rel[slot]):
				slot = i
	_tr_idx[slot] = index
	_tr_head[slot] = 0
	_tr_n[slot] = 0
	_tr_rel[slot] = -1.0
	_trail_push(slot, pos)
	_trails_live = true

func _trail_add(index: int, pos: Vector2) -> void:
	var slot := _trail_slot(index)
	if slot >= 0:
		_trail_push(slot, pos)
		_trails_live = true
	else:
		_trail_begin(index, pos)        # (its slot was given to another finger while this one rested)

func _trail_end(index: int) -> void:
	var slot := _trail_slot(index)
	if slot >= 0:
		_tr_rel[slot] = _clock

func _trail_push(slot: int, pos: Vector2) -> void:
	var n := _tr_n[slot]
	var head := _tr_head[slot]
	var base := slot * TRAIL_CAP
	if n > 0 and _tr_pts[base + (head + n - 1) % TRAIL_CAP].distance_to(pos) < TRAIL_MIN_STEP:
		_tr_ts[base + (head + n - 1) % TRAIL_CAP] = _clock       # (the head stays where it is; it is freshened)
		return
	if n == TRAIL_CAP:
		head = (head + 1) % TRAIL_CAP
		n -= 1
	var at := base + (head + n) % TRAIL_CAP
	_tr_pts[at] = pos
	_tr_ts[at] = _clock
	_tr_head[slot] = head
	_tr_n[slot] = n + 1

## Drops points that have outlived the tail, and ends a released trail that has faded.
func _trails_tick() -> void:
	var any := false
	for i: int in TRAIL_SLOTS:
		var n := _tr_n[i]
		if n == 0:
			continue
		while n > 0 and _clock - _tr_ts[i * TRAIL_CAP + _tr_head[i]] > TRAIL_LIFE:
			_tr_head[i] = (_tr_head[i] + 1) % TRAIL_CAP
			n -= 1
		_tr_n[i] = n
		if _tr_rel[i] >= 0.0 and _clock - _tr_rel[i] >= TRAIL_FADE:
			_tr_n[i] = 0
			_tr_idx[i] = -1
			_tr_rel[i] = -1.0
		elif n > 0:
			any = true
	_trails_live = any

func _draw() -> void:
	for i: int in TRAIL_SLOTS:
		if _tr_n[i] >= 2:
			_draw_trail(i)

## Smooths slot `i`'s points into samples, then draws the body (a strip of quads, translucent, wide at the head) and the core.
func _draw_trail(i: int) -> void:
	var n := _tr_n[i]
	var head := _tr_head[i]
	var base := i * TRAIL_CAP
	var fade := 1.0
	if _tr_rel[i] >= 0.0:
		fade = clampf(1.0 - (_clock - _tr_rel[i]) / TRAIL_FADE, 0.0, 1.0)
	# samples along a cubic Hermite through the points; the tangent at a point runs between its neighbours, at the length of the segment
	var ns := 0
	var total := 0.0
	for k: int in n - 1:
		var a: Vector2 = _tr_pts[base + (head + k) % TRAIL_CAP]
		var b: Vector2 = _tr_pts[base + (head + k + 1) % TRAIL_CAP]
		var prev: Vector2 = _tr_pts[base + (head + k - 1) % TRAIL_CAP] if k > 0 else a
		var next: Vector2 = _tr_pts[base + (head + k + 2) % TRAIL_CAP] if k < n - 2 else b
		var seg := a.distance_to(b)
		var m0 := (b - prev).normalized() * seg if k > 0 else (b - a)
		var m1 := (next - a).normalized() * seg if k < n - 2 else (b - a)
		for j: int in TRAIL_SUB:
			var u := float(j) / TRAIL_SUB
			var u2 := u * u
			var u3 := u2 * u
			_sp[ns] = a * (2.0 * u3 - 3.0 * u2 + 1.0) + m0 * (u3 - 2.0 * u2 + u) + b * (-2.0 * u3 + 3.0 * u2) + m1 * (u3 - u2)
			if ns > 0:
				total += _sp[ns].distance_to(_sp[ns - 1])
			_sc[ns] = total
			ns += 1
	_sp[ns] = _tr_pts[base + (head + n - 1) % TRAIL_CAP]
	total += _sp[ns].distance_to(_sp[ns - 1])
	_sc[ns] = total
	ns += 1
	if total < 1.0:
		return
	# the strip's two edges: a point of the tail has no width, the head has all of it (a hair less at the very tip, so the end is rounded)
	for j: int in ns:
		var t := _sc[j] / total
		var tan: Vector2 = (_sp[mini(j + 1, ns - 1)] - _sp[maxi(j - 1, 0)]).normalized()
		var w := TRAIL_WIDTH * pow(t, 0.8) * (1.0 - 0.3 * pow(t, 24.0)) * 0.5
		var nrm := Vector2(-tan.y, tan.x) * w
		_sl[j] = _sp[j] + nrm
		_sr[j] = _sp[j] - nrm
	for j: int in ns - 1:
		var a0 := TRAIL_ALPHA * (0.2 + 0.8 * pow(_sc[j] / total, 0.7)) * fade
		var a1 := TRAIL_ALPHA * (0.2 + 0.8 * pow(_sc[j + 1] / total, 0.7)) * fade
		_quad[0] = _sl[j]
		_quad[1] = _sl[j + 1]
		_quad[2] = _sr[j + 1]
		_quad[3] = _sr[j]
		_quad_c[0] = Color(1, 1, 1, a0)
		_quad_c[1] = Color(1, 1, 1, a1)
		_quad_c[2] = Color(1, 1, 1, a1)
		_quad_c[3] = Color(1, 1, 1, a0)
		draw_primitive(_quad, _quad_c, _quad_uv)
	for j: int in ns - 1:
		var t1 := _sc[j + 1] / total
		draw_line(_sp[j], _sp[j + 1], Color(0, 0, 0, 0.22 * t1 * fade), 3.5 + 2.5 * t1, true)       # a faint dark edge, so the core reads over bright ground
		draw_line(_sp[j], _sp[j + 1], Color(1, 1, 1, minf(1.0, 0.95 * pow(t1, 0.6)) * fade), 1.5 + 2.5 * t1, true)

func _now() -> float:
	return _clock

static func quantize(v: Vector2) -> String:
	var a := fposmod(atan2(v.y, v.x), TAU)
	return NAMES[int(round(a / (TAU / 8.0))) % 8]
