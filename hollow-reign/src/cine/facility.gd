class_name Facility
extends CineScene
## Beneath the throne: the door the Witness remembered opens on a shaft, and the shaft on the Eternal Crown's
## facility. A short directed descent, built from boxes, emissive strips and the Hollow Deep's kit:
##   1  behind the heir on a lift plate, the shaft falling away below: rings of the old make, dark
##   2  from the shaft wall: the plate small, the rings turning as it passes, their lights waking one after another
##   3  looking up: the way back, a long way off
##   4  the floor of it: two great leaves part, and beyond them the racks wake row by row, and the Crown's ring turns
## Lyra: "This was never merely a kingdom." / "Then what was it?" / "A means of keeping one alive."
## The world moves, not the lift: everything hangs from `shaft`, which rises past the plate.
## Sets flags.facility_seen (also when skipped). Dev: hold_at = "shaft" | "rings" | "floor" | "crown".

const DEPTH := 66.0
const RING_GAP := 5.5
const RING_R := 7.5
const TEAL := Color("#5fe0c8")
const VIOLET := Color("#b07aff")

var shaft: Node3D
var arena: Arena
var hero: CineActor
var _rings: Array = []            # {node, mat, y, lit, spin}
var _racks: Array = []            # materials, nearest row first
var _leaves: Array = []
var _crown: Node3D
var _crown_mat: StandardMaterial3D
var _crown_light: OmniLight3D
var _descending := false

func _ready() -> void:
	begin()
	shaft = Node3D.new()
	add_child(shaft)
	# the floor of it is the Hollow Deep's own ground, sixty metres down
	arena = Arena.new()
	shaft.add_child(arena)
	arena.build("deep")
	arena.position.y = -DEPTH
	arena.env.fog_density = 0.012
	arena.env.ambient_light_energy = 1.3
	# the way ahead is kept clear of the Deep's own rocks and growths: what is beyond the leaves has to be seen
	for c: Node in arena.get_children():
		if c is Node3D and not c is Light3D and not c is WorldEnvironment and absf((c as Node3D).position.x) < 8.0 and (c as Node3D).position.z < -3.0 and (c as Node3D).position.length() > 0.5:
			c.queue_free()
	var metal := Look.flat(Color("#1f2224"), 0.5, 0.85)
	# the shaft: rings of the old make, each with a band of machine light, alternate ones turning
	var n := int(DEPTH / RING_GAP)
	for k in n:
		var ring := Node3D.new()
		shaft.add_child(ring)
		ring.position.y = -3.0 - k * RING_GAP
		var mat := Look.glow(TEAL if k % 4 != 3 else VIOLET, 0.0)
		for s in 14:
			var a := TAU * s / 14.0
			if (s + k) % 7 == 3:
				continue          # a gap in each, so the rings are seen to turn
			var dir := Vector3(sin(a), 0, cos(a))
			var seg := _box(ring, Vector3(TAU * RING_R / 14.0 + 0.1, 1.5, 0.7), dir * RING_R, metal, a)
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_box(ring, Vector3(TAU * RING_R / 14.0 - 0.5, 0.12, 0.1), dir * (RING_R - 0.4) + Vector3(0, 0.25, 0), mat, a)
		for s2 in 4:
			var a2 := TAU * s2 / 4.0 + k * 0.5
			_box(ring, Vector3(0.5, RING_GAP, 0.5), Vector3(sin(a2), 0, cos(a2)) * (RING_R + 0.6) + Vector3(0, -RING_GAP * 0.5, 0), metal, a2)
		_rings.append({"node": ring, "mat": mat, "y": ring.position.y, "lit": false, "spin": (0.09 if k % 2 == 0 else -0.06)})
	# the lift plate and the one standing on it (these do not move)
	var plate := Node3D.new()
	add_child(plate)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.3
	cm.bottom_radius = 2.5
	cm.height = 0.3
	cm.radial_segments = 20
	disc.mesh = cm
	disc.material_override = metal
	disc.position.y = -0.15
	plate.add_child(disc)
	for s3 in 8:
		var a3 := TAU * s3 / 8.0
		_box(plate, Vector3(0.5, 0.05, 0.12), Vector3(sin(a3), 0, cos(a3)) * 2.0 + Vector3(0, 0.02, 0), Look.glow(TEAL, 1.6), a3)
	var pl := OmniLight3D.new()
	pl.light_color = Color("#bfeee6")
	pl.light_energy = 1.6
	pl.omni_range = 7.0
	pl.position = Vector3(0.8, 2.6, 1.2)
	plate.add_child(pl)
	hero = CineActor.knight(self)
	hero.position = Vector3(0, 0, 0.3)
	hero.rotation.y = 0.0
	# the floor: two great leaves across the way, and behind them what the Monarch kept one part of
	for sx: float in [-1.0, 1.0]:
		var leaf := _box(arena, Vector3(7.0, 13.0, 0.9), Vector3(sx * 3.5, 6.5, -11.0), metal, 0.0)
		_box(leaf, Vector3(0.14, 11.0, 0.08), Vector3(-sx * 3.2, 0, 0.5), Look.glow(TEAL, 1.2), 0.0)
		_leaves.append(leaf)
	for sx2: float in [-1.0, 1.0]:
		_box(arena, Vector3(3.0, 16.0, 2.0), Vector3(sx2 * 8.6, 8.0, -11.0), metal, 0.0)
	_box(arena, Vector3(20.0, 3.0, 2.0), Vector3(0, 14.5, -11.0), metal, 0.0)
	# racks of stored light, row behind row, into the dark
	for row in 9:
		var z := -17.0 - row * 6.5
		var m := Look.glow(TEAL if row % 3 != 2 else Color("#ffb45a"), 0.0)
		for sx3: float in [-1.0, 1.0]:
			_box(arena, Vector3(1.2, 11.0, 4.6), Vector3(sx3 * (7.5 + row * 0.5), 5.5, z), metal, 0.0)
			for line in 9:
				_box(arena, Vector3(0.08, 0.1, 4.0), Vector3(sx3 * (6.86 + row * 0.5), 1.0 + line * 1.1, z), m, 0.0)
		_racks.append(m)
	# the Crown: a ring the height of a tower at the end of it, and the light in the middle of it
	_crown = Node3D.new()
	arena.add_child(_crown)
	_crown.position = Vector3(0, 13.0, -80.0)
	_crown_mat = Look.glow(Color("#ffd890"), 0.0)
	for s4 in 28:
		var a4 := TAU * s4 / 28.0
		var p := Vector3(sin(a4), cos(a4), 0) * 11.0
		var seg2 := _box(_crown, Vector3(2.7, 1.5, 1.6), p, metal, 0.0)
		seg2.rotation.z = -a4
		if s4 % 2 == 0:
			var lamp := _box(_crown, Vector3(1.6, 0.25, 0.2), p * 0.93 + Vector3(0, 0, 0.9), _crown_mat, 0.0)
			lamp.rotation.z = -a4
	_crown_light = OmniLight3D.new()
	_crown_light.light_color = Color("#ffd890")
	_crown_light.light_energy = 0.0
	_crown_light.omni_range = 60.0
	_crown_light.omni_attenuation = 0.7
	_crown_light.position = Vector3(0, 0, 4.0)
	_crown.add_child(_crown_light)
	Sfx.ambience("crypt")
	Sfx.music_for("explore_deep", "menu", 4.0)
	_run()

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, yaw: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi

func _process(delta: float) -> void:
	super(delta)
	for r: Dictionary in _rings:
		(r.node as Node3D).rotation.y += float(r.spin) * delta * (1.0 if _descending else 0.25)
		# a ring wakes as the plate comes down to it
		if not r.lit and shaft.position.y + float(r.y) > -11.0:
			r.lit = true
			create_tween().tween_property(r.mat, "emission_energy_multiplier", 2.6, 0.7)
			if _descending:
				Sfx.play("ui_tap", -16.0, 0.5)
	if _crown:
		_crown.rotation.z += delta * 0.05

func _run() -> void:
	# 1: behind the heir, the shaft below
	cam.cut(Vector3(1.1, 2.5, 3.6), Vector3(0.0, -4.0, -3.0), 50.0)
	cam.move(Vector3(0.9, 2.2, 3.3), Vector3(0.0, -6.0, -2.4), 8.0)
	cards.fade(0.0, 2.2, true)
	if not await _w(1.6):
		return
	_descending = true
	Sfx.play("shield_scrape", -10.0, 0.45)
	var down := create_tween()
	down.tween_property(shaft, "position:y", DEPTH, 21.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	down.tween_callback(func(): _descending = false)
	if _held("shaft"):
		down.kill()
		shaft.position.y = 14.0
		return
	if not await _w(4.4):
		return
	# 2: from the wall of the shaft
	cam.cut(Vector3(5.6, 0.9, 3.4), Vector3(0.0, 1.0, 0.0), 44.0)
	cam.move(Vector3(5.2, 1.6, 2.4), Vector3(0.0, 0.9, 0.0), 7.0)
	if _held("rings"):
		down.kill()
		shaft.position.y = 30.0
		return
	if not await _w(6.2):
		return
	# 3: the way back
	cam.cut(Vector3(1.6, 0.5, 1.2), Vector3(0.0, 14.0, -0.6), 52.0)
	cam.move(Vector3(1.3, 0.6, 1.0), Vector3(0.0, 14.0, -0.4), 6.0)
	if not await _w(2.0):
		return
	Story.play("facility", true)          # timed so that her last line lands as the floor of it opens
	if not await _w(2.6):
		return
	# 4: the floor of it
	cam.cut(Vector3(2.4, 1.9, 5.6), Vector3(0.0, 2.4, -11.0), 46.0)
	cam.move(Vector3(1.9, 2.2, 4.6), Vector3(0.0, 4.5, -11.0), 9.0)
	while _descending and not _over:
		await get_tree().process_frame
	if _over:
		return
	if _held("floor"):
		return
	Sfx.play("guard_break", -6.0, 0.45)
	Sfx.play("shield_scrape", -8.0, 0.4)
	for i in 2:
		var leaf: MeshInstance3D = _leaves[i]
		leaf.create_tween().tween_property(leaf, "position:x", leaf.position.x + (-6.6 if i == 0 else 6.6), 5.0).set_trans(Tween.TRANS_SINE)
	if not await _w(2.2):
		return
	# the racks wake, nearest first; then the Crown
	for i2 in _racks.size():
		var tw := create_tween()
		tw.tween_interval(0.38 * i2)
		tw.tween_property(_racks[i2], "emission_energy_multiplier", 2.4, 0.6)
	var wake := create_tween()
	wake.tween_interval(0.38 * _racks.size())
	wake.tween_property(_crown_mat, "emission_energy_multiplier", 5.0, 2.4)
	wake.parallel().tween_property(_crown_light, "light_energy", 7.0, 2.4)
	cam.move(Vector3(0.6, 4.2, 1.6), Vector3(0.0, 9.0, -50.0), 10.0, 42.0)
	walk(hero, Vector3(0, 0, -3.4), 1.0)
	if not await _w(6.4):
		return
	if not await _spoken():
		return
	cards.show_card("THE ETERNAL CROWN", 3.6)
	if _held("crown"):
		cards.card.modulate.a = 1.0
		return
	if not await _w(5.0):
		return
	await cards.fade(1.0, 1.6)
	_end()

func _closing() -> void:
	if not Game.profile.is_empty():
		Game.profile.flags["facility_seen"] = true
		Game.save()
