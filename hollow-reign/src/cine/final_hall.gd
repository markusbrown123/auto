class_name FinalHall
extends Node3D
## The throne hall with its machinery showing (Generation III): set dressing laid over the `throne` arena from boxes
## and emissive strips, and the way it answers the last fight. Nothing here is a new model.
##   level 0  the floor stands open: slots of machine light down the aisle, pylons at the walls, dark racks by the throne
##   level 1  The Ancient Crown: the slots brighten, the pylons wake one after another
##   level 2  The Last Defense: the two restoration engines by the dais come on; each mark of the seal broken puts out
##            one of their rings; with the seal gone they go dark, and at the end everything runs down
## FinalHall.dress(arena, sim) builds it and follows the sim's events. FinalHall.seal_panel() is the sealed-records
## panel of the hall in the earlier generations (the same construction Generation I's scene uses).

const TEAL := Color("#5fe0c8")
const VIOLET := Color("#b07aff")
const ENGINE_AT := [Vector3(-3.9, 0, -9.6), Vector3(3.9, 0, -9.6)]

var arena: Arena
var level := 0
var _slots: Array = []            # StandardMaterial3D of the floor slots
var _pylons: Array = []           # [material, light]
var _rings: Array = []            # StandardMaterial3D of the engine rings, bottom to top, both engines interleaved
var _racks: Array = []            # StandardMaterial3D, the racks of lights by the throne
var _engine_lights: Array = []
var _clock := 0.0
var _ring_on := 0

static func dress(a: Arena, sim: DuelSim = null) -> FinalHall:
	var f := FinalHall.new()
	f.arena = a
	a.add_child(f)
	f._build()
	if sim != null:
		sim.ev.connect(f._on_ev)
	return f

## The sealed records in the wall of the hall: a metal panel with a lit face, and its light. Returns the light.
static func seal_panel(a: Arena, at: Vector3) -> OmniLight3D:
	var metal := Look.flat(Color("#2a2c2e"), 0.45, 0.85)
	a.box(Vector3(1.6, 2.8, 0.5), at + Vector3(1.2, 1.4, 0), metal, Vector3(0, -70, 0))
	var face := a.box(Vector3(0.9, 1.5, 0.52), at + Vector3(1.15, 1.55, 0.02), Look.glow(TEAL, 1.6), Vector3(0, -70, 0))
	face.name = "SealFace"
	var l := OmniLight3D.new()
	l.light_color = TEAL
	l.light_energy = 0.9
	l.omni_range = 6.0
	l.position = at + Vector3(0.2, 1.7, 0.3)
	a.add_child(l)
	return l

## A lamp whose brightness can be turned: dark when its energy is 0 (Look.glow is unshaded, and is lit at any energy).
static func lamp(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r * 0.06, c.g * 0.06, c.b * 0.06)
	m.roughness = 0.6
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m

func _glow_mat(c: Color, e: float) -> StandardMaterial3D:
	return FinalHall.lamp(c, e)

func _part(size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := arena.box(size, pos, mat, rot)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _build() -> void:
	var metal := Look.flat(Color("#232527"), 0.5, 0.85)
	var pit := Look.flat(Color("#050607"), 0.95, 0.0)
	# the floor stands open: two long slots down the aisle and the cross-cuts between them, light coming up out of each
	for sx: float in [-1.0, 1.0]:
		_part(Vector3(0.62, 0.03, 23.0), Vector3(sx * 3.1, 0.015, -0.5), pit)
		var m := _glow_mat(TEAL, 0.9)
		_part(Vector3(0.07, 0.035, 22.6), Vector3(sx * 3.1, 0.02, -0.5), m)
		_slots.append(m)
		for k in 2:
			_part(Vector3(0.08, 0.05, 23.0), Vector3(sx * (3.1 + (0.36 if k == 0 else -0.36)), 0.03, -0.5), metal)
	for i in 5:
		var z := 9.0 - i * 4.6
		for sx2: float in [-1.0, 1.0]:
			_part(Vector3(2.6, 0.03, 0.5), Vector3(sx2 * 4.7, 0.015, z), pit)
			var m2 := _glow_mat(TEAL, 0.9)
			_part(Vector3(2.4, 0.035, 0.06), Vector3(sx2 * 4.7, 0.02, z), m2)
			_slots.append(m2)
	# the plates that covered it, lifted and left leaning
	_part(Vector3(1.9, 0.12, 2.6), Vector3(-6.3, 0.5, 6.4), metal, Vector3(0, 12, 58))
	_part(Vector3(1.9, 0.12, 2.6), Vector3(6.5, 0.45, -2.6), metal, Vector3(0, -20, -62))
	# pylons risen out of the floor along both walls, each with two bands of light
	var n := 0
	for i in 4:
		for sx3: float in [-1.0, 1.0]:
			var at := Vector3(sx3 * 6.6, 0, 8.0 - i * 5.4)
			_part(Vector3(0.8, 3.4, 0.8), at + Vector3(0, 1.7, 0), metal, Vector3(0, 12.0 * sx3, 0))
			_part(Vector3(1.05, 0.3, 1.05), at + Vector3(0, 0.15, 0), metal, Vector3(0, 12.0 * sx3, 0))
			var band := _glow_mat(TEAL, 0.35)
			_part(Vector3(0.84, 0.09, 0.84), at + Vector3(0, 2.5, 0), band, Vector3(0, 12.0 * sx3, 0))
			_part(Vector3(0.84, 0.06, 0.84), at + Vector3(0, 1.3, 0), band, Vector3(0, 12.0 * sx3, 0))
			arena.cyl(0.07, 0.07, 6.0, at + Vector3(sx3 * 0.2, 6.2, 0), metal, 6)
			var l: OmniLight3D = null
			if n % 3 == 0:
				l = OmniLight3D.new()
				l.light_color = TEAL
				l.light_energy = 0.25
				l.omni_range = 6.5
				l.position = at + Vector3(-sx3 * 0.9, 2.0, 0)
				arena.add_child(l)
			_pylons.append([band, l])
			n += 1
	# racks of small lights either side of the throne: most of them dark
	arena.rng.seed = 77
	for sx4: float in [-1.0, 1.0]:
		_part(Vector3(4.6, 6.6, 0.5), Vector3(sx4 * 7.4, 3.5, -15.4), metal, Vector3(0, -24.0 * sx4, 0))
		for row in 9:
			var lit: bool = arena.rng.randf() < 0.55
			var m3 := _glow_mat(TEAL if row % 4 != 1 else Color("#ffb45a"), 1.4 if lit else 0.05)
			var b := Basis(Vector3.UP, deg_to_rad(-24.0 * sx4))
			_part(Vector3(3.9 * (0.4 + arena.rng.randf() * 0.6), 0.08, 0.06), Vector3(sx4 * 7.4, 0.8 + row * 0.66, -15.4) + b * Vector3(0, 0, 0.3), m3, Vector3(0, -24.0 * sx4, 0))
			_racks.append(m3)
	# the restoration engines at the foot of the dais (OldMake): dark until they are needed. Each carries six rings of
	# light on its shaft, a flywheel and two rams; pipe runs go from each up the dais to the seat they feed.
	var built: Array = []
	for e: Vector3 in ENGINE_AT:
		var eng: Dictionary = OldMake.engine(arena, e, VIOLET, 6, 5.6)
		built.append(eng)
		_engine_lights.append(eng.light)
		var sx5 := signf(e.x)
		for k3 in 3:
			OldMake.pipe(arena, e + Vector3(-sx5 * 0.5, 0.5 + k3 * 0.45, -0.3), Vector3(sx5 * (1.5 - k3 * 0.35), 1.6 + k3 * 0.5, -13.4), 0.07 + 0.02 * k3, metal)
	for k2 in 6:
		for eng2: Dictionary in built:
			_rings.append(eng2.rings[k2])
	# the hall is roofed: ribs of the old make spring from the walls, and above them is dark, not sky
	OldMake.vault(arena, 19.0, 6.5, 12.5, 13.0, -19.0, 8)
	if PropModel.exists("res://assets/models/env_de_conduit.glb"):
		arena.prop("de_conduit", 6.5, Vector3(-10.5, 0, -11.5), 30.0)
		arena.prop("de_conduit", 5.5, Vector3(10.8, 0, -3.0), 205.0)
	set_level(0, true)

func _fade(m: StandardMaterial3D, to: float, time: float, delay: float = 0.0) -> void:
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(m, "emission_energy_multiplier", to, time)

## 0 the floor open, 1 the Ancient Crown, 2 the Last Defense.
func set_level(l: int, at_once: bool = false) -> void:
	level = l
	var t := 0.0 if at_once else 1.2
	for m: StandardMaterial3D in _slots:
		_fade(m, [0.7, 1.8, 1.2][clampi(l, 0, 2)], maxf(t, 0.01))
	for i in _pylons.size():
		var e: float = [0.35, 2.4, 2.4][clampi(l, 0, 2)]
		_fade(_pylons[i][0], e, 0.5 if not at_once else 0.01, 0.0 if at_once else 0.22 * i)      # one after another, down the hall
		if _pylons[i][1] != null:
			var tw := create_tween()
			tw.tween_interval(0.0 if at_once else 0.22 * i)
			tw.tween_property(_pylons[i][1], "light_energy", [0.25, 1.1, 0.9][clampi(l, 0, 2)], 0.6)
	if l >= 2:
		show_seal(_rings.size() / 2, _rings.size() / 2)
		for el: OmniLight3D in _engine_lights:
			create_tween().tween_property(el, "light_energy", 2.6, 1.4)
		if not at_once:
			Sfx.play("levelup", -8.0, 0.45)

## The engines carry the seal: of `need` marks, `left` are still lit (spread over their six rings).
func show_seal(left: int, need: int) -> void:
	var pairs := _rings.size() / 2
	var on := 0 if need <= 0 else ceili(float(pairs) * float(left) / float(need))
	_ring_on = on
	for k in pairs:
		for s in 2:
			_fade(_rings[k * 2 + s], 3.2 if k < on else 0.0, 0.35)

func broken() -> void:
	show_seal(0, 1)
	for el: OmniLight3D in _engine_lights:
		create_tween().tween_property(el, "light_energy", 0.0, 0.8)

## Everything runs down: what is left on is the little that was always on.
func run_down(time: float = 4.0) -> void:
	broken()
	for m: StandardMaterial3D in _slots:
		_fade(m, 0.25, time)
	for i in _pylons.size():
		_fade(_pylons[i][0], 0.08, time * 0.6, 0.15 * i)
		if _pylons[i][1] != null:
			create_tween().tween_property(_pylons[i][1], "light_energy", 0.05, time)
	for i in _racks.size():
		if i % 3 != 0:
			_fade(_racks[i], 0.03, time * 0.5, 0.12 * i)

func _on_ev(n: StringName, d: Dictionary) -> void:
	match n:
		&"phase_change":
			set_level(int(d.phase))
		&"seal":
			if level < 2:
				set_level(2)
			show_seal(int(d.left), int(d.need))
		&"seal_broken":
			broken()
		&"restored":
			for el: OmniLight3D in _engine_lights:
				el.light_energy = 6.0
				create_tween().tween_property(el, "light_energy", 2.6, 1.2)
		&"boss_dead":
			run_down()

func _process(delta: float) -> void:
	_clock += delta
	if level >= 2 and _ring_on > 0:
		for i in _engine_lights.size():
			_engine_lights[i].position.y = 2.6 + sin(_clock * 2.2 + i) * 0.5
