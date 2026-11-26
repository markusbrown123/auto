class_name FighterRig
extends Node3D
## Procedurally built and procedurally animated armoured fighter.
## The body is a set of segments driven by a few control points (pelvis, chest,
## hands, feet) with analytic two-bone IK, so every attack direction is an
## exact, readable arc and new enemies are just a parameter dictionary.
## Local space: forward is -Z, right is +X.

enum Mode { GUARD, WINDUP, STRIKE, FOLLOW, RECOVER, STAGGER, HURT, DODGE, DEAD, ROAR, THRUST_WINDUP, THRUST }

const UPPER := 0.31
const FORE := 0.30
const THIGH := 0.46
const SHIN := 0.48
const ARC_MAX := 1.75

var cfg: Dictionary = {}
var mirror := 1.0            # +1 player (seen from behind), -1 foe (seen from the front)
var mode: int = Mode.GUARD
var two_handed := false
var has_shield := false
var dual := false
var blocking := false
var weapon_len := 1.0
var time_scale := 1.0

# animation state
var _t := 0.0                 # time in current mode
var _dur := 1.0
var _swing := 0.3
var _arc_dir := Vector3.RIGHT
var _theta := 0.0
var _hand := Vector3(0.22, 1.05, -0.32)
var _blade := Vector3(-0.2, 0.92, -0.33).normalized()
var _hand_l := Vector3(-0.25, 1.1, -0.28)
var _blade_l := Vector3(0.2, 0.92, -0.33).normalized()
var _root := Vector3.ZERO      # rig-local offset (dodges, lunges, knock-back)
var _root_target := Vector3.ZERO
var _lean := 0.0
var _twist := 0.0
var _crouch := 0.0
var _dodge_side := 0.0
var _clock := 0.0
var _flash := 0.0
var _far := 0.0               # extra stand-off distance (foe retreats)
var _far_target := 0.0
var _death_dir := 1.0
var _thrust_from := Vector3.ZERO

# nodes
var body: Node3D
var chest: Node3D
var head: Node3D
var pelvis: Node3D
var _relic: Node3D
var seg := {}                 # name -> Node3D limb segment
var weapon_r: Node3D
var weapon_l: Node3D
var shield: Node3D
var trail: MeshInstance3D
var trail_mesh: ImmediateMesh
var cape: MeshInstance3D
var cape_mesh: ImmediateMesh
var _cape_pts: Array = []
var _trail_pts: Array = []
var mat_metal: StandardMaterial3D
var mat_cloth: StandardMaterial3D
var mat_dark: StandardMaterial3D
var mat_glow: StandardMaterial3D
var mat_blade: StandardMaterial3D
var eye_light: OmniLight3D
var bulk := 1.0
var _warn_overlay: StandardMaterial3D
var _base_glow = null
var skin: SkinDriver          # optional rigged model replacing the primitive body
var _ankle := {}
var hunch := 0.0
var arm_scale := 1.0


# ================================================================ construction
func build(config: Dictionary, as_foe: bool) -> void:
	cfg = config
	mirror = -1.0 if as_foe else 1.0
	bulk = float(cfg.get("bulk", 1.0))
	hunch = float(cfg.get("hunch", 0.0))
	arm_scale = 1.25 if cfg.get("weapon", "sword") == "claws" else 1.0
	scale = Vector3.ONE * float(cfg.get("scale", 1.0))
	_materials()
	body = Node3D.new()
	add_child(body)
	pelvis = Node3D.new()
	body.add_child(pelvis)
	if cfg.get("witness", false):
		# the Witness rides behind the right hip, face outward
		# (a child of the body, not of the pelvis node: the primitive pelvis is hidden when a generated model is worn)
		var relic := PropModel.scenery(body, "res://assets/models/witness_relic.glb", 0.4, Vector3(0.2, 0.9, 0.1), 215.0)
		_relic = relic
		if relic:
			var eye := OmniLight3D.new()
			eye.light_color = Color("#ffb347")
			eye.light_energy = 0.4
			eye.omni_range = 0.9
			eye.position = Vector3(0, 0.2, 0.0)
			relic.add_child(eye)
			# the mask itself is lifted out of shadow and its eyes burn amber: an artefact, not a dark lump
			for mi in relic.find_children("*", "MeshInstance3D", true, false):
				var ov := StandardMaterial3D.new()
				ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ov.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				ov.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				ov.albedo_color = Color(1.0, 0.72, 0.35, 0.035)
				(mi as MeshInstance3D).material_overlay = ov
			for ex: float in [-0.028, 0.028]:
				var e := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.011
				sm.height = 0.022
				e.mesh = sm
				var em := StandardMaterial3D.new()
				em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				em.albedo_color = Color(1.0, 0.75, 0.3)
				em.emission_enabled = true
				em.emission = Color(1.0, 0.7, 0.25)
				em.emission_energy_multiplier = 3.0
				e.material_override = em
				e.position = Vector3(ex, 0.235, 0.075)
				relic.add_child(e)
	_box(pelvis, Vector3(0.36 * bulk, 0.18, 0.24 * bulk), Vector3(0, 0.02, 0), mat_metal)
	_fauld()
	chest = Node3D.new()
	body.add_child(chest)
	_torso()
	head = Node3D.new()
	chest.add_child(head)
	head.position = Vector3(0, 0.47, -0.02 - hunch * 0.12)
	_helm(str(cfg.get("helm", "great")))
	for side in ["r", "l"]:
		seg["upper_" + side] = _limb(UPPER * arm_scale, 0.082 * bulk, 0.066 * bulk, mat_metal)
		seg["fore_" + side] = _limb(FORE * arm_scale, 0.07 * bulk, 0.056 * bulk, mat_metal)
		seg["thigh_" + side] = _limb(THIGH, 0.125 * bulk, 0.09 * bulk, mat_metal)
		seg["shin_" + side] = _limb(SHIN, 0.095 * bulk, 0.068 * bulk, mat_metal)
		var foot := Node3D.new()
		body.add_child(foot)
		_box(foot, Vector3(0.14 * bulk, 0.1, 0.3), Vector3(0, 0.05, -0.06), mat_metal)
		seg["foot_" + side] = foot
		# knee cop and elbow couter read as armour joints
		_sphere(seg["shin_" + side], 0.105 * bulk, Vector3(0, 0, -0.02), mat_metal)
		_sphere(seg["fore_" + side], 0.085 * bulk, Vector3.ZERO, mat_metal)
		# gauntlet cuff
		_cyl(seg["fore_" + side], 0.085 * bulk, 0.07 * bulk, 0.16, Vector3(0, FORE * arm_scale - 0.1, 0), mat_metal)
		_sphere(seg["fore_" + side], 0.07 * bulk, Vector3(0, FORE * arm_scale, 0), mat_dark)
	if cfg.get("wraith", false):
		# soul-eaters do not walk: a ragged shroud hangs where legs would be
		for side in ["r", "l"]:
			for part in ["thigh_", "shin_", "foot_"]:
				seg[part + side].visible = false
		var shroud := _cyl(pelvis, 0.2 * bulk, 0.42 * bulk, 1.0, Vector3(0, -0.45, 0.05), mat_cloth, 9)
		shroud.scale.z = 0.85
		for i in 7:
			var a := TAU * i / 7.0
			var rag := _cyl(pelvis, 0.07, 0.0, 0.5, Vector3(cos(a) * 0.33 * bulk, -1.1, sin(a) * 0.3 * bulk + 0.05), mat_cloth, 4)
			rag.rotation.z = cos(a) * 0.2
	weapon_r = Node3D.new()
	body.add_child(weapon_r)
	weapon_l = Node3D.new()
	body.add_child(weapon_l)
	set_weapon(str(cfg.get("weapon", "sword")), cfg)
	if cfg.has("shield"):
		set_shield(cfg.shield)
	_build_trail()
	if cfg.has("skin"):
		skin = SkinDriver.attach(body, str(cfg.skin))
		if skin:
			# the model replaces the primitive body; weapons, shield and trail stay
			pelvis.visible = false
			chest.visible = false
			for k in seg:
				seg[k].visible = false
			if cfg.has("skin_tint"):
				skin.tint(Color(str(cfg.skin_tint)))
	if cfg.get("cape", false) and skin == null:
		_build_cape()
	var eye := Color(str(cfg.get("eye", "#000000")))
	if as_foe and eye.v > 0.05:
		eye_light = OmniLight3D.new()
		eye_light.light_color = eye
		eye_light.light_energy = 0.6
		eye_light.omni_range = 1.6
		head.add_child(eye_light)
		eye_light.position = Vector3(0, 0, -0.25)
	_solve(0.0)

func _materials() -> void:
	var metal := Color(str(cfg.get("metal", "#6a6a6c")))
	mat_metal = StandardMaterial3D.new()
	mat_metal.albedo_color = metal
	mat_metal.metallic = 0.72
	mat_metal.roughness = 0.36
	mat_metal.roughness_texture = Look.grime()
	mat_metal.uv1_triplanar = true
	mat_metal.uv1_scale = Vector3.ONE * 2.2
	mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = metal.darkened(0.45)
	mat_dark.metallic = 0.3
	mat_dark.roughness = 0.8
	mat_cloth = StandardMaterial3D.new()
	mat_cloth.albedo_color = Color(str(cfg.get("cloth", "#2a1a14")))
	mat_cloth.roughness = 0.95
	mat_cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_glow = StandardMaterial3D.new()
	var eye := Color(str(cfg.get("eye", "#ff8040")))
	mat_glow.albedo_color = eye
	mat_glow.emission_enabled = true
	mat_glow.emission = eye
	mat_glow.emission_energy_multiplier = 3.0
	mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.material_override = mat
	parent.add_child(m)
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(parent, b, pos, mat)

func _sphere(parent: Node3D, r: float, pos: Vector3, mat: Material, squash: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	var m := _mi(parent, s, pos, mat)
	m.scale = squash
	return m

func _cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, mat: Material, sides: int = 12) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return _mi(parent, c, pos, mat)

## A limb segment whose local +Y runs from its joint to the next one.
func _limb(length: float, r0: float, r1: float, mat: Material) -> Node3D:
	var n := Node3D.new()
	body.add_child(n)
	_cyl(n, r1, r0, length, Vector3(0, length * 0.5, 0), mat, 10)
	return n

func _fauld() -> void:
	# skirt of plates / cloth below the waist
	var long: bool = cfg.get("skirt", false) or cfg.get("apron", false)
	var h := 0.62 if long else 0.26
	var m := _cyl(pelvis, 0.21 * bulk, (0.34 if long else 0.27) * bulk, h, Vector3(0, -h * 0.5 + 0.06, 0), mat_cloth if long else mat_dark, 10)
	m.scale.z = 0.8

func _torso() -> void:
	var w := 0.245 * bulk
	var cuirass := _cyl(chest, w * 1.12, w * 0.82, 0.46, Vector3(0, 0.1, 0), mat_metal, 12)
	cuirass.scale.z = 0.78
	var belly := _cyl(chest, w * 0.8, w * 0.86, 0.2, Vector3(0, -0.2, 0), mat_dark, 12)
	belly.scale.z = 0.75
	_cyl(chest, 0.085 * bulk, 0.11 * bulk, 0.1, Vector3(0, 0.36, 0), mat_metal, 10)   # gorget
	var ridge := _box(chest, Vector3(0.03, 0.4, 0.05), Vector3(0, 0.12, -w * 0.8), mat_metal)
	ridge.rotation.x = -0.1
	var belt := _cyl(chest, w * 0.88, w * 0.9, 0.06, Vector3(0, -0.29, 0), mat_cloth, 12)
	belt.scale.z = 0.78
	# tabard down the front
	var tab := _box(chest, Vector3(0.2 * bulk, 0.62, 0.012), Vector3(0, -0.12, -w * 0.72 - 0.012), mat_cloth)
	tab.rotation.x = 0.06
	for sx: float in [-1.0, 1.0]:
		var p := _sphere(chest, 0.15 * bulk, Vector3(sx * (w + 0.05), 0.27, 0), mat_metal, Vector3(1.2, 0.62, 1.15))
		p.rotation.z = -sx * 0.35
		var lame := _sphere(chest, 0.13 * bulk, Vector3(sx * (w + 0.1), 0.17, 0), mat_dark, Vector3(1.0, 0.6, 1.05))
		lame.rotation.z = -sx * 0.7
		if cfg.get("regal", false) or cfg.get("horns", false) or bulk > 1.2:
			var spike := _cyl(chest, 0.0, 0.04 * bulk, 0.2, Vector3(sx * (w + 0.14), 0.36, 0), mat_metal, 6)
			spike.rotation.z = -sx * 0.7
	if cfg.get("maw", false):
		# the hollow where it keeps what it has eaten
		_sphere(chest, w * 0.62, Vector3(0, 0.08, -w * 0.5), mat_glow, Vector3(1.0, 1.25, 0.5))
		for i in 8:
			var a := TAU * i / 8.0
			var fang := _cyl(chest, 0.0, 0.028, 0.16, Vector3(cos(a) * w * 0.55, 0.08 + sin(a) * w * 0.7, -w * 0.72), mat_cloth, 4)
			fang.rotation = Vector3(-PI / 2, 0, 0)
			fang.rotation.z = a + PI / 2
	if cfg.get("ember", false) or cfg.get("frost", false):
		# glowing seam in the breastplate
		var seam := _box(chest, Vector3(0.02, 0.3, 0.02), Vector3(0.03, 0.1, -w * 0.78), mat_glow)
		seam.rotation.z = 0.25

func _helm(kind: String) -> void:
	var r := 0.14
	match kind:
		"great":
			_cyl(head, r * 0.95, r * 1.05, 0.3, Vector3(0, 0.02, 0), mat_metal, 12)
			_sphere(head, r * 0.95, Vector3(0, 0.15, 0), mat_metal, Vector3(1, 0.55, 1))
			_box(head, Vector3(0.17, 0.016, 0.03), Vector3(0, 0.05, -r * 0.98), mat_glow)
			_box(head, Vector3(0.016, 0.2, 0.03), Vector3(0, -0.02, -r * 1.0), mat_dark)
		"kettle":
			_sphere(head, r, Vector3(0, 0.03, 0), mat_metal, Vector3(1, 1.05, 1))
			_cyl(head, r * 1.3, r * 1.4, 0.025, Vector3(0, 0.07, 0), mat_metal, 14)
			_box(head, Vector3(0.12, 0.018, 0.03), Vector3(0, 0.0, -r * 0.95), mat_glow)
		"hood":
			_sphere(head, r * 1.12, Vector3(0, 0.03, 0.01), mat_cloth, Vector3(1, 1.12, 1.1))
			var tip := _cyl(head, 0.0, r * 0.8, 0.26, Vector3(0, 0.18, 0.08), mat_cloth, 8)
			tip.rotation.x = -0.9
			_sphere(head, r * 0.8, Vector3(0, 0.0, -0.05), mat_dark)
			for sx: float in [-1.0, 1.0]:
				_sphere(head, 0.016, Vector3(sx * 0.04, 0.02, -r * 0.82), mat_glow)
			_cyl(head, r * 1.3, r * 1.6, 0.14, Vector3(0, -0.14, 0.0), mat_cloth, 10)
		"veil":
			_sphere(head, r, Vector3(0, 0.03, 0), mat_metal, Vector3(0.95, 1.1, 1))
			var veil := _cyl(head, r * 0.9, r * 1.5, 0.42, Vector3(0, -0.1, 0.03), mat_cloth, 10)
			veil.scale.z = 1.1
			for sx: float in [-1.0, 1.0]:
				_sphere(head, 0.014, Vector3(sx * 0.038, 0.04, -r * 0.96), mat_glow)
			var comb := _cyl(head, 0.0, 0.05, 0.22, Vector3(0, 0.22, 0.0), mat_metal, 4)
			comb.scale.x = 0.25
		"beast":
			_sphere(head, r * 1.25, Vector3(0, 0.02, 0), mat_dark, Vector3(1.05, 0.95, 1.2))
			_box(head, Vector3(0.16, 0.12, 0.24), Vector3(0, -0.04, -0.19), mat_dark)      # snout
			_box(head, Vector3(0.2, 0.05, 0.2), Vector3(0, 0.07, -0.1), mat_metal)        # brow plate
			for sx: float in [-1.0, 1.0]:
				_sphere(head, 0.022, Vector3(sx * 0.06, 0.03, -0.2), mat_glow)
				var tusk := _cyl(head, 0.0, 0.018, 0.1, Vector3(sx * 0.06, -0.09, -0.28), mat_cloth, 5)
				tusk.rotation.x = PI
		"crown", _:
			_sphere(head, r, Vector3(0, 0.03, 0), mat_metal, Vector3(0.95, 1.12, 1.0))
			_box(head, Vector3(0.15, 0.016, 0.03), Vector3(0, 0.03, -r * 0.93), mat_glow)
			_cyl(head, r * 1.08, r * 1.02, 0.05, Vector3(0, 0.12, 0), mat_metal, 12)
			for i in 8:
				var a := TAU * i / 8.0
				var sp := _cyl(head, 0.0, 0.02, 0.16 if i % 2 == 0 else 0.1, Vector3(sin(a) * r, 0.2, cos(a) * r), mat_glow if cfg.get("regal", false) else mat_metal, 4)
				sp.rotation = Vector3(cos(a) * 0.25, 0, -sin(a) * 0.25)
	if cfg.get("crest", "") == "plume":
		var plume := _box(head, Vector3(0.03, 0.2, 0.3), Vector3(0, 0.26, 0.04), mat_cloth)
		plume.rotation.x = 0.3
	if cfg.get("horns", false) or cfg.get("antlers", false):
		var horn_mat := mat_cloth if cfg.get("antlers", false) else mat_dark
		for sx: float in [-1.0, 1.0]:
			var base := Vector3(sx * 0.11, 0.1, 0.0)
			var h1 := _cyl(head, 0.022, 0.04, 0.26, base + Vector3(sx * 0.1, 0.08, 0), horn_mat, 6)
			h1.rotation.z = -sx * 1.0
			var h2 := _cyl(head, 0.0, 0.024, 0.3, base + Vector3(sx * 0.24, 0.26, -0.03), horn_mat, 6)
			h2.rotation = Vector3(-0.25, 0, -sx * 0.2)
			if cfg.get("antlers", false):
				var h3 := _cyl(head, 0.0, 0.016, 0.2, base + Vector3(sx * 0.15, 0.22, 0.02), horn_mat, 5)
				h3.rotation.z = sx * 0.5


# ---------------------------------------------------------------- weapons
func _clear(n: Node3D) -> void:
	for c in n.get_children():
		c.queue_free()

func set_weapon(kind: String, look: Dictionary = {}) -> void:
	_clear(weapon_r)
	_clear(weapon_l)
	two_handed = kind == "greatsword" or kind == "glaive"
	dual = kind == "dual" or kind == "claws"
	mat_blade = StandardMaterial3D.new()
	var metal := Color(str(look.get("blade", look.get("metal", "#9a9aa0"))))
	if not look.has("blade"):
		metal = metal.lightened(0.25)
	mat_blade.albedo_color = metal
	mat_blade.metallic = 0.95
	mat_blade.roughness = 0.28
	var glow = look.get("weapon_glow", look.get("glow"))
	_base_glow = glow
	if glow != null:
		mat_blade.emission_enabled = true
		mat_blade.emission = Color(str(glow))
		mat_blade.emission_energy_multiplier = 0.9
	_warn_overlay = null
	var model: String = str(look.get("weapon_model", ""))
	if kind == "claws" and look.has("skin"):
		weapon_len = 0.45          # the model's own claws are the weapon
	elif PropModel.exists(model):
		var ls: float = float(look.get("weapon_scale", 1.0))
		weapon_len = PropModel.weapon(weapon_r, model, kind, look.get("weapon_tint"), ls)
		if dual:
			PropModel.weapon(weapon_l, model, kind, look.get("weapon_tint"), ls)
		# a red glow laid over the model marks an unblockable blow
		_warn_overlay = StandardMaterial3D.new()
		_warn_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_warn_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_warn_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_warn_overlay.albedo_color = Color(1.0, 0.1, 0.03, 0.0)
		for n in [weapon_r, weapon_l]:
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				mi.material_overlay = _warn_overlay
	else:
		_weapon_mesh(weapon_r, kind, look)
		if dual:
			_weapon_mesh(weapon_l, kind, look)
	if dual or two_handed:
		set_shield(null)

func _weapon_mesh(n: Node3D, kind: String, look: Dictionary) -> void:
	match kind:
		"greatsword":
			weapon_len = 1.55
			_box(n, Vector3(0.11, 1.2, 0.022), Vector3(0, 0.82, 0), mat_blade)
			var tip := _cyl(n, 0.0, 0.078, 0.2, Vector3(0, 1.52, 0), mat_blade, 4)
			tip.scale.z = 0.2
			tip.rotation.y = PI / 4
			_box(n, Vector3(0.4, 0.04, 0.05), Vector3(0, 0.2, 0), mat_metal)
			_cyl(n, 0.022, 0.022, 0.42, Vector3(0, -0.02, 0), mat_dark, 6)
			_sphere(n, 0.045, Vector3(0, -0.25, 0), mat_metal)
		"glaive":
			# a blade at each end of a long haft
			weapon_len = 1.15
			_cyl(n, 0.022, 0.022, 1.7, Vector3(0, 0.1, 0), mat_dark, 6)
			for e: float in [1.0, -1.0]:
				_box(n, Vector3(0.09, 0.5, 0.018), Vector3(0, 0.1 + e * 1.05, 0), mat_blade)
				var gt := _cyl(n, 0.0 if e > 0 else 0.062, 0.062 if e > 0 else 0.0, 0.16, Vector3(0, 0.1 + e * 1.38, 0), mat_blade, 4)
				gt.scale.z = 0.22
				gt.rotation.y = PI / 4
				_box(n, Vector3(0.16, 0.03, 0.04), Vector3(0, 0.1 + e * 0.8, 0), mat_metal)
		"cleaver":
			weapon_len = 1.25
			_box(n, Vector3(0.28, 0.72, 0.03), Vector3(0.08, 0.78, 0), mat_blade)
			_box(n, Vector3(0.1, 0.12, 0.03), Vector3(0.17, 1.2, 0), mat_blade)
			_cyl(n, 0.026, 0.03, 0.6, Vector3(0, 0.12, 0), mat_dark, 6)
		"axe":
			weapon_len = 1.05
			_cyl(n, 0.02, 0.024, 1.0, Vector3(0, 0.35, 0), mat_dark, 6)
			_box(n, Vector3(0.26, 0.24, 0.025), Vector3(0.13, 0.74, 0), mat_blade)
			var edge := _cyl(n, 0.17, 0.17, 0.02, Vector3(0.24, 0.74, 0), mat_blade, 12)
			edge.rotation.x = PI / 2
			edge.scale.x = 0.5
		"dual":
			weapon_len = 0.85
			# curved blade: three angled sections
			var p := Vector3(0, 0.1, 0)
			for i in 3:
				var sec := _box(n, Vector3(0.055 - i * 0.01, 0.27, 0.014), p + Vector3(0.02 * i * i, 0.13, 0), mat_blade)
				sec.rotation.z = -0.16 * i
				p += Vector3(0.045 * i, 0.25, 0)
			_box(n, Vector3(0.14, 0.03, 0.04), Vector3(0, 0.09, 0), mat_metal)
			_cyl(n, 0.018, 0.018, 0.2, Vector3(0, -0.02, 0), mat_dark, 6)
		"claws":
			weapon_len = 0.55
			for i in 3:
				var c := _cyl(n, 0.0, 0.03, 0.5, Vector3((i - 1) * 0.07, 0.3, 0), mat_blade, 5)
				c.rotation.z = -(i - 1) * 0.14
				c.rotation.x = -0.25
			_sphere(n, 0.11, Vector3.ZERO, mat_dark)
		_:
			weapon_len = 1.05
			_box(n, Vector3(0.062, 0.8, 0.016), Vector3(0, 0.55, 0), mat_blade)
			var tip2 := _cyl(n, 0.0, 0.044, 0.14, Vector3(0, 1.02, 0), mat_blade, 4)
			tip2.scale.z = 0.25
			tip2.rotation.y = PI / 4
			_box(n, Vector3(0.24, 0.03, 0.04), Vector3(0, 0.13, 0), mat_metal)
			_cyl(n, 0.018, 0.018, 0.2, Vector3(0, 0.02, 0), mat_dark, 6)
			_sphere(n, 0.03, Vector3(0, -0.09, 0), mat_metal)

## Marks the weapon as carrying an unblockable blow (red glow), or clears it.
func set_blade_warning(on: bool) -> void:
	if _warn_overlay:
		_warn_overlay.albedo_color.a = 0.6 if on else 0.0
		return
	mat_blade.emission_enabled = on or _base_glow != null
	mat_blade.emission = Color(1.0, 0.12, 0.05) if on else (Color(str(_base_glow)) if _base_glow != null else Color.BLACK)
	mat_blade.emission_energy_multiplier = 3.0 if on else 0.9

func set_shield(look) -> void:
	if shield:
		shield.queue_free()
		shield = null
	has_shield = look != null and not two_handed and not dual
	if not has_shield:
		return
	shield = Node3D.new()
	body.add_child(shield)
	if PropModel.exists(str(look.get("model", ""))) and PropModel.shield(shield, str(look.model)):
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(str(look.get("color", "#4a3a2a")))
	m.metallic = 0.4
	m.roughness = 0.6
	var face := _cyl(shield, 0.3, 0.3, 0.04, Vector3.ZERO, m, 6)
	face.rotation.x = PI / 2
	face.scale = Vector3(0.85, 1.25, 1.0)
	var rim := _cyl(shield, 0.07, 0.07, 0.07, Vector3(0, 0, -0.02), mat_metal, 10)
	rim.rotation.x = PI / 2

func set_armor_color(metal: Color, cloth: Color) -> void:
	mat_metal.albedo_color = metal
	mat_dark.albedo_color = metal.darkened(0.55)
	mat_cloth.albedo_color = cloth


# ---------------------------------------------------------------- trail / cape
func _build_trail() -> void:
	trail_mesh = ImmediateMesh.new()
	trail = MeshInstance3D.new()
	trail.mesh = trail_mesh
	trail.top_level = true
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.extra_cull_margin = 4.0
	trail.material_override = Fx.ribbon_material()
	add_child(trail)

func _build_cape() -> void:
	cape_mesh = ImmediateMesh.new()
	cape = MeshInstance3D.new()
	cape.mesh = cape_mesh
	cape.top_level = true
	cape.material_override = mat_cloth
	add_child(cape)


# ================================================================ actions
func _go(m: int, dur: float = 1.0) -> void:
	mode = m
	_t = 0.0
	_dur = maxf(dur, 0.01)

func guard() -> void:
	if mode != Mode.DEAD:
		_go(Mode.GUARD)
		_root_target = Vector3.ZERO

## Wind up an attack that will land `windup` seconds from now, travelling in
## screen direction `dir` (x right, y up). `swing` is how long the blow itself takes.
func telegraph(dir: Vector2, windup: float, swing: float, kind: String = "slash") -> void:
	_pin_t = 0.0
	_finish = ""
	_arc_dir = Vector3(dir.x * mirror, dir.y, 0).normalized()
	_swing = swing
	if kind == "thrust" or kind == "lunge":
		_go(Mode.THRUST_WINDUP, windup)
	else:
		_go(Mode.WINDUP, windup)
	_root_target = Vector3(0, 0, 0.18)

## Player attack: a short rise then the cut. Contact is at 60% of `time`.
## `finish` names the kind of combo this cut completes ("" for an ordinary cut): each kind has its own body.
var _finish := ""
const FINISH_CLIP := {"Heavy": "sword_attack", "Guard-breaking": "shield_dash", "Counter": "lunge", "Armour-piercing": "lunge",
	"Critical": "cut_c", "Finisher": "cut_c", "Fast": ""}
func swing(dir: Vector2, time: float, finish: String = "") -> void:
	_finish = finish
	_pin_t = 0.0
	_brace_t = 0.0
	_arc_dir = Vector3(dir.x * mirror, dir.y, 0).normalized()
	_swing = time * 0.5
	_go(Mode.WINDUP, time * 0.6)
	_root_target = Vector3(0, 0, -0.25)

func parry(dir: Vector2) -> void:
	_arc_dir = Vector3(dir.x * mirror, dir.y, 0).normalized()
	_swing = 0.16
	_finish = ""
	_go(Mode.STRIKE, 0.16)
	_theta = -0.9

func recover() -> void:
	if mode != Mode.DEAD:
		_go(Mode.RECOVER)
		_root_target = Vector3(0, 0, -0.1)

func stagger() -> void:
	_pin_t = 0.0
	if mode != Mode.DEAD:
		_go(Mode.STAGGER)
		_root_target = Vector3(0, 0, 0.45)

func hurt() -> void:
	_pin_t = 0.0
	_brace_t = 0.0
	if mode != Mode.DEAD:
		_go(Mode.HURT, 0.4)
		_root_target = Vector3(0, 0, 0.3)
		_flash = 1.0

func flash(v: float = 1.0) -> void:
	_flash = v

## How far in front of its own centre this fighter's blade reaches at the middle of a cut, in world units.
func reach() -> float:
	return (0.05 + 0.5 * arm_scale + weapon_len * 0.8) * scale.x

var _pin_t := 0.0
var _pin_hand := Vector3.ZERO
var _pin_blade := Vector3.UP
var _brace_t := 0.0
var _brace_at := Vector3.ZERO

## Hold the blade for `hold` seconds so that it crosses `world_point` — where another weapon is.
func clash(world_point: Vector3, hold: float = 0.2) -> void:
	var local: Vector3 = body.to_local(world_point)
	var shoulder := Vector3(0.25, 1.35, 0.0)
	var dir := Vector3(-0.3 * signf(local.x + 0.001), 0.85, -0.4).normalized()
	var hand := local - dir * weapon_len * 0.55
	var max_reach := (UPPER + FORE) * arm_scale - 0.03
	if (hand - shoulder).length() > max_reach:
		hand = shoulder + (hand - shoulder).normalized() * max_reach
		dir = (local - hand).normalized()
	_pin_hand = hand
	_pin_blade = dir
	_pin_t = hold
	_solve(0.0)      # take the pose now, so the contact shows during the hit-stop

## The blow has been stopped: hold the blade at the point of the cut where it reaches furthest forward,
## instead of letting it sweep on through whatever stopped it.
func halt(hold: float = 0.2) -> void:
	var ap := _arc_point(-0.12, 0.0)
	_pin_hand = ap[0]
	_pin_blade = ap[1]
	_pin_t = hold
	_solve(0.0)

## Put the shield where the blow lands.
func brace(world_point: Vector3, hold: float = 0.3) -> void:
	var local: Vector3 = body.to_local(world_point)
	var shoulder := Vector3(-0.25, 1.35, 0.0)
	var max_reach := (UPPER + FORE) * arm_scale - 0.06
	_brace_at = shoulder + (local - shoulder).limit_length(max_reach)
	_brace_at.z = minf(_brace_at.z, -0.25)
	_brace_t = hold
	_hand_l = _brace_at
	_solve(0.0)

func dodge(side: float) -> void:
	_dodge_side = side
	_rolling = false
	_go(Mode.DODGE, 0.5)

## Turn the sidestep in progress into a roll.
var _rolling := false
func roll(side: float) -> void:
	_dodge_side = side
	_rolling = true
	_go(Mode.DODGE, 0.84)      # ends as the rules free the knight, not before

func roar() -> void:
	_go(Mode.ROAR, 2.0)
	_root_target = Vector3.ZERO

func die(dir: float = 1.0) -> void:
	_pin_t = 0.0
	_brace_t = 0.0
	_death_dir = dir
	_go(Mode.DEAD, 1.6)

func set_far(far: bool) -> void:
	_far_target = 1.5 if far else 0.0

func is_striking() -> bool:
	return mode == Mode.STRIKE or mode == Mode.THRUST

func blade_tip() -> Vector3:
	return weapon_r.global_transform * Vector3(0, weapon_len, 0)

func blade_mid() -> Vector3:
	return weapon_r.global_transform * Vector3(0, weapon_len * 0.6, 0)

func chest_point() -> Vector3:
	return chest.global_position


## Walking: whoever moves the rig just changes its position; the stride follows the distance covered.
var walking := false
var _walk_phase := 0.0
var _walk_amount := 0.0       # 0 standing .. 1 full stride, eased so starts and stops are not abrupt
var _last_world := Vector3.ZERO
var _prev_world := Vector3.ZERO
var _step_dir := Vector3(0, 0, -1)   # which way the feet are travelling, in the rig's own space
var footsteps := false                # play a footfall as each foot lands
var _step_i := 0
var combat_steps := false            # in a duel: short steps in any direction, guard kept up
const STRIDE := 0.78          # metres per step
const WALK_CYCLES := 1.0      # full left-right cycles in the authored walk clip
var test_clip := ""           # dev: play one clip on the whole body
var use_clips := true         # authored skeletal clips over the procedural pose, where the skeleton suits them

## When filming clips every idle oscillation is snapped to a harmonic of
## `loop_period`, so the pose at the end of a loop equals the pose at its start.
var loop_period := 0.0

func _osc(f: float, cosine: bool = false) -> float:
	if loop_period > 0.0:
		f = TAU / loop_period * maxf(1.0, roundf(f * loop_period / TAU))
	return cos(_clock * f) if cosine else sin(_clock * f)

# ================================================================ per-frame
func _process(delta: float) -> void:
	var dt := delta * time_scale
	_clock += dt
	_t += dt
	# stride phase advances with ground actually covered, so feet never slide
	var moved := global_position.distance_to(_last_world) / maxf(scale.x, 0.01)
	_last_world = global_position
	if walking and moved < 1.0:
		_walk_phase += moved / (STRIDE * (0.62 if combat_steps else 1.0)) * PI
		if moved > 0.0004:
			var local := global_transform.basis.inverse() * (global_position - _prev_world)
			local.y = 0.0
			if local.length() > 0.00001:
				_step_dir = _step_dir.lerp(local.normalized(), 0.25).normalized()
	_prev_world = global_position
	# a footfall each time a foot comes down, heard on the frame it lands
	var step_i := int(floor(_walk_phase / PI))
	if step_i != _step_i:
		_step_i = step_i
		if footsteps and _walk_amount > 0.35 and mode != Mode.DODGE and moved < 0.12:
			Sfx.play("footstep", (-9.0 if combat_steps else -6.0) + 3.0 * (bulk - 1.0), 1.0 / maxf(0.7, scale.x))
			Sfx.play("armor", -17.0 + 4.0 * (bulk - 1.0), 1.0 / maxf(0.7, scale.x), 0.12)      # plates shift with every step
	_walk_amount = lerpf(_walk_amount, 1.0 if (walking and moved > 0.0005) else 0.0, 1.0 - exp(-dt * 7.0))
	_solve(dt)

func _arc_point(theta: float, lag: float) -> Array:
	var f := Vector3(0, 0, -1)
	var d := _arc_dir
	var c := Vector3(0.05 * signf(d.x) * -0.0, 1.34 - hunch * 0.25, -0.05)
	var r := 0.5 * arm_scale
	var p := c + (f * cos(theta) + d * sin(theta)) * r
	# horizontal cuts are carried at shoulder height in the wind-up so they read clearly
	p.y += 0.22 * (1.0 - absf(d.y)) * clampf(-theta / ARC_MAX, 0.0, 1.0)
	# keep the arm in front of the body
	p.z = minf(p.z, 0.1)
	var b := (f * cos(theta + lag) + d * sin(theta + lag)).normalized()
	return [p, b]

func _solve(dt: float) -> void:
	var k := 1.0 - exp(-dt * 12.0)
	var slow := 1.0 - exp(-dt * 5.0)
	var hand_t := Vector3(0.24, 1.02 - hunch * 0.3, -0.34)
	var blade_t := Vector3(-0.28, 0.88, -0.38).normalized()
	var lean_t := 0.06 + hunch
	var twist_t := -0.25
	var crouch_t := 0.04 + hunch * 0.1
	var direct := false
	var breathe := _osc(1.7) * 0.012
	match mode:
		Mode.GUARD:
			hand_t.y += breathe
			if two_handed:
				# long blades are held at the hip with the point forward and up at the foe, clear of the wielder's own head
				hand_t = Vector3(0.2, 0.9 + breathe, -0.32)
				blade_t = Vector3(-0.18, 0.5, -0.85).normalized()
		Mode.WINDUP:
			var rise := minf(_dur * 0.5, 0.5)
			var sweep_start := _dur - _swing * 0.5
			if _t < sweep_start:
				var u := clampf(_t / rise, 0.0, 1.0)
				u = 1.0 - pow(1.0 - u, 3.0)
				_theta = lerpf(_theta, -ARC_MAX * u - 0.12 * clampf((_t - rise) / maxf(sweep_start - rise, 0.01), 0.0, 1.0), 1.0 - exp(-dt * 14.0))
				var ap := _arc_point(_theta, -0.55)
				hand_t = ap[0]
				blade_t = ap[1]
				# the held blade trembles slightly: the tell before a delayed blow
				if _t > rise:
					hand_t += Vector3(_osc(31.0), _osc(27.0, true), 0) * 0.006
				lean_t = -0.1 + hunch
				twist_t = _arc_dir.x * 0.55
				crouch_t = 0.07
			else:
				_go(Mode.STRIKE, _swing)
				_theta = -ARC_MAX
				_root_target = Vector3(0, 0, -0.35)
		Mode.THRUST_WINDUP:
			var sweep_start2 := _dur - _swing * 0.5
			hand_t = Vector3(0.3, 1.22 - hunch * 0.2, 0.1)
			blade_t = Vector3(-0.1, 0.05, -1).normalized()
			if _t > minf(_dur * 0.5, 0.5):
				hand_t += Vector3(_osc(31.0), _osc(27.0, true), 0) * 0.006
			lean_t = -0.12 + hunch
			twist_t = 0.6
			crouch_t = 0.12
			if _t >= sweep_start2:
				_go(Mode.THRUST, _swing)
				_thrust_from = _hand
				_root_target = Vector3(0, 0, -0.7)
	match mode:
		Mode.STRIKE:
			var u2 := clampf(_t / _dur, 0.0, 1.0)
			_theta = lerpf(-ARC_MAX if _dur > 0.17 else -0.9, ARC_MAX * 0.9 if _dur > 0.17 else 0.35, u2)
			var ap2 := _arc_point(_theta, lerpf(-0.5, 0.45, u2))
			hand_t = ap2[0]
			blade_t = ap2[1]
			direct = true
			lean_t = 0.28 + hunch
			twist_t = -_arc_dir.x * 0.5 * (u2 * 2.0 - 1.0)
			crouch_t = 0.1
			if u2 >= 1.0:
				_go(Mode.FOLLOW, 0.3)
		Mode.THRUST:
			var u3 := clampf(_t / _dur, 0.0, 1.0)
			hand_t = _thrust_from.lerp(Vector3(0.12, 1.2 - hunch * 0.2, -0.78 * arm_scale), ease(u3, 0.4))
			blade_t = Vector3(-0.05, 0.08, -1).normalized()
			direct = true
			lean_t = 0.35 + hunch
			twist_t = -0.3
			crouch_t = 0.14
			if u3 >= 1.0:
				_go(Mode.FOLLOW, 0.3)
		Mode.FOLLOW:
			hand_t = _hand
			blade_t = _blade
			lean_t = 0.22 + hunch
			twist_t = _twist
			crouch_t = 0.1
			if _t >= _dur:
				_go(Mode.GUARD)
				_root_target = Vector3.ZERO
		Mode.RECOVER:
			# spent: weapon low and wide, chest heaving — this is the opening
			hand_t = Vector3(0.42, 0.62, -0.25)
			blade_t = Vector3(0.35, -0.75, -0.55).normalized()
			lean_t = 0.42 + hunch + _osc(5.0) * 0.03
			twist_t = 0.1
			crouch_t = 0.16
		Mode.STAGGER:
			hand_t = Vector3(0.5, 0.75 + _osc(3.0) * 0.04, 0.05)
			blade_t = Vector3(0.7, -0.6, 0.2).normalized()
			lean_t = -0.22 + _osc(2.3) * 0.08
			twist_t = 0.35 + _osc(1.7) * 0.15
			crouch_t = 0.22
		Mode.HURT:
			lean_t = -0.25
			twist_t = 0.4
			crouch_t = 0.12
			if _t >= _dur:
				guard()
		Mode.DODGE:
			var u4 := clampf(_t / _dur, 0.0, 1.0)
			var hop := sin(u4 * PI)
			_root_target = Vector3(_dodge_side * 0.95 * hop, 0, 0.12 * hop)
			lean_t = 0.15
			twist_t = -_dodge_side * 0.35 * hop
			crouch_t = 0.06 + 0.16 * hop
			if u4 >= 1.0:
				guard()
		Mode.ROAR:
			var u5 := clampf(_t / _dur, 0.0, 1.0)
			hand_t = Vector3(0.55, 1.5, 0.0)
			blade_t = Vector3(0.5, 0.85, 0.1).normalized()
			lean_t = -0.35 * sin(u5 * PI) + hunch * 0.5
			twist_t = _osc(20.0) * 0.03
			crouch_t = 0.0
			if u5 >= 1.0:
				guard()
		Mode.DEAD:
			var u6 := clampf(_t / _dur, 0.0, 1.0)
			var fall := ease(u6, 2.2)
			hand_t = Vector3(0.45, 0.5 - 0.4 * fall, 0.0)
			blade_t = Vector3(0.8, -0.3, 0.3).normalized()
			lean_t = lerpf(-0.2, 1.35, fall)
			twist_t = 0.3 * _death_dir
			crouch_t = lerpf(0.2, 0.72, fall)
			_root_target = Vector3(0, 0, 0.3)
	if _walk_amount > 0.01 and combat_steps:
		# fighting footwork: the guard stays up, the body sinks and sways a little into each step
		crouch_t += 0.03 * _walk_amount * absf(cos(_walk_phase))
		twist_t += 0.05 * _walk_amount * sin(_walk_phase)
	elif _walk_amount > 0.01 and mode == Mode.GUARD:
		# sword carried low at the side, shoulders counter-swinging against the legs
		var w := _walk_amount
		var sw := sin(_walk_phase)
		hand_t = hand_t.lerp(Vector3(0.34, 0.92, -0.06 - 0.10 * sw), w)
		blade_t = blade_t.lerp(Vector3(0.12, -0.42, -0.9).normalized(), w).normalized()
		twist_t = lerpf(twist_t, 0.14 * sw, w)
		lean_t = lerpf(lean_t, 0.10, w)
		crouch_t = lerpf(crouch_t, 0.03 + 0.035 * absf(cos(_walk_phase)), w)
	if blocking and (mode == Mode.GUARD or mode == Mode.HURT):
		lean_t = 0.14
		crouch_t = 0.12
		twist_t = 0.25
	# --- smooth toward targets
	if direct:
		_hand = hand_t
		_blade = blade_t
	else:
		_hand = _hand.lerp(hand_t, k)
		_blade = _blade.lerp(blade_t, k).normalized()
	_lean = lerpf(_lean, lean_t, slow * 1.6)
	_twist = lerpf(_twist, twist_t, slow * 1.6)
	_crouch = lerpf(_crouch, crouch_t, slow * 1.4)
	_far = lerpf(_far, _far_target, 1.0 - exp(-dt * 4.0))
	_root = _root.lerp(_root_target + Vector3(0, 0, _far), 1.0 - exp(-dt * (16.0 if mode == Mode.DODGE else 9.0)))
	_pose()
	_update_trail()
	_update_cape(dt)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 7.0)
		mat_metal.emission_enabled = _flash > 0.0
		mat_metal.emission = Color(1, 0.9, 0.8)
		mat_metal.emission_energy_multiplier = _flash * 0.09
		if skin:
			skin.flash(_flash)

func _pose() -> void:
	body.position = _root
	var pel := Vector3(0, 0.96 - _crouch * 0.6, 0)
	if cfg.get("wraith", false):
		pel.y += 0.22 + sin(_clock * 1.9) * 0.07
	pelvis.position = pel
	pelvis.rotation = Vector3(-_lean * 0.3, _twist * 0.3, 0)
	var cb := Basis.from_euler(Vector3(-_lean, _twist, 0))
	var chest_pos := pel + cb * Vector3(0, 0.42, 0)
	chest.transform = Transform3D(cb, chest_pos)
	head.rotation = Vector3(_lean * 0.75, -_twist * 0.8, 0)
	var sw := 0.245 * bulk + 0.05
	var sh_r := chest_pos + cb * Vector3(sw, 0.24, 0)
	var sh_l := chest_pos + cb * Vector3(-sw, 0.24, 0)
	# --- right arm + weapon
	var reach := (UPPER + FORE) * arm_scale - 0.015
	if _pin_t > 0.0:
		# contact: for a moment the blade is held exactly where it met the other weapon
		_pin_t -= get_process_delta_time() * time_scale
		_hand = _pin_hand
		_blade = _pin_blade
	var hr := sh_r + (_hand - sh_r).limit_length(reach)
	_arm("r", sh_r, hr, Vector3(0.7, -0.8, 0.35))
	weapon_r.transform = Transform3D(_basis_y(_blade, Vector3(0, 0, -1) if absf(_blade.z) < 0.9 else Vector3.RIGHT), hr)
	# --- left arm
	var hl: Vector3
	var bl := Vector3(_blade.x * -1.0, _blade.y, _blade.z)
	if two_handed:
		hl = hr - _blade * 0.2
	elif dual:
		hl = Vector3(-_hand.x, _hand.y - 0.04, _hand.z + 0.05)
		if mode == Mode.STRIKE:
			# the second blade follows a beat behind, crossing the first
			var ap := _arc_point(_theta - 0.55, -0.4)
			hl = ap[0] + Vector3(-0.12 * signf(_arc_dir.x + 0.01), -0.1, 0.04)
			bl = ap[1]
	elif has_shield:
		hl = Vector3(-0.05, 1.3, -0.42) if blocking else Vector3(-0.3, 1.08, -0.24)
		if _brace_t > 0.0:
			# the shield goes to where the blow lands, then is driven back toward the body by it
			_brace_t -= get_process_delta_time() * time_scale
			var k := clampf(_brace_t / 0.3, 0.0, 1.0)
			hl = _brace_at + Vector3(0, -0.04, 0.16) * (1.0 - k)
	else:
		hl = Vector3(-0.32, 0.86, -0.05)
	if _walk_amount > 0.01 and not two_handed and not blocking:
		hl = hl.lerp(Vector3(-0.34, 0.95, -0.08 + 0.12 * sin(_walk_phase)), _walk_amount)
	_hand_l = _hand_l.lerp(hl, 0.4) if not two_handed else hl
	_blade_l = _blade_l.lerp(bl, 0.4).normalized()
	var hl2 := sh_l + (_hand_l - sh_l).limit_length(reach)
	_arm("l", sh_l, hl2, Vector3(-0.7, -0.8, 0.35))
	weapon_l.transform = Transform3D(_basis_y(_blade_l, Vector3(0, 0, -1) if absf(_blade_l.z) < 0.9 else Vector3.RIGHT), hl2)
	if shield:
		shield.transform = Transform3D(Basis.from_euler(Vector3(0.1, 0.35 if not blocking else 0.05, 0)), hl2 + Vector3(-0.02, 0, -0.07))
	# --- legs (feet stay planted in world space while the body shifts)
	var stance := 0.22 + 0.12 * bulk
	var f_r := Vector3(stance, 0, 0.16) - Vector3(_root.x * 0.35, 0, _root.z * 0.3)
	var f_l := Vector3(-stance, 0, -0.2) - Vector3(_root.x * 0.35, 0, _root.z * 0.3)
	if mode == Mode.DEAD:
		f_r.z += 0.25
		f_l.z += 0.1
	if _walk_amount > 0.01:
		# each foot: planted and sliding back under the body for half the cycle, lifted and swung forward for the other half
		var w2 := _walk_amount
		var half := STRIDE * (0.31 if combat_steps else 0.5)
		var narrow := (stance if combat_steps else 0.13 * bulk)
		var lift := 0.09 if combat_steps else 0.14
		# stride along whichever way the body is travelling: forward, back or sideways
		var along := _step_dir * half
		var wr := Vector3(narrow, maxf(0.0, -sin(_walk_phase)) * lift, 0.16 if combat_steps else 0.0) + along * cos(_walk_phase)
		var wl := Vector3(-narrow, maxf(0.0, sin(_walk_phase)) * lift, -0.2 if combat_steps else 0.0) - along * cos(_walk_phase)
		f_r = f_r.lerp(wr, w2)
		f_l = f_l.lerp(wl, w2)
	_leg("r", pel + Vector3(0.12 * bulk, -0.04, 0), f_r)
	_leg("l", pel + Vector3(-0.12 * bulk, -0.04, 0), f_l)
	if skin:
		# authored motion where it exists: the walk cycle out of combat, and the fall when killed
		_pick_clip()
		if _relic:
			_relic.position = pel + Vector3(0.19, -0.03, 0.11)      # behind the sword-side hip, where the duel camera sees it; moves with the hips
		var hands: Dictionary = skin.drive({"pelvis": pel + Vector3(0, 0.06, 0), "pelvis_rot": Basis.from_euler(pelvis.rotation), "chest_rot": cb,
			"head_rot": Basis.from_euler(head.rotation), "hand_r": hr, "hand_l": hl2, "ankle_r": _ankle.r, "ankle_l": _ankle.l})
		# weapons ride the model's real hands
		weapon_r.position = hands.r
		weapon_l.position = hands.l
		if shield:
			shield.position = hands.l + Vector3(-0.02, 0, -0.07)
			if mode == Mode.DEAD and skin.clip_w > 0.0:
				# the shield goes down with the arm and ends flat on the stones
				var u := clampf(_t / 1.6, 0.0, 1.0)
				shield.rotation = Vector3(lerpf(0.1, -1.45, u), 0.35, 0.0)
				shield.position.y = maxf(shield.position.y, 0.06)

## Chooses the authored clip for the body in the current state. The sword and shield arms stay on IK
## unless the clip is a whole-body one (falls, hit reactions), so cuts keep the direction that was swiped.
var _clip_w := 0.0
func _pick_clip() -> void:
	var n := ""
	var t := 0.0
	var w := 0.0
	var full := false
	var dtt := get_process_delta_time() * time_scale
	skin.clip_travel = 1.0
	if test_clip != "":
		n = test_clip; t = _clock; w = 1.0; full = true
	elif not use_clips:
		pass
	else:
		match mode:
			Mode.DEAD:
				n = "death"; t = _t; w = 1.0; full = true
			Mode.HURT:
				n = "hit_chest"; t = _t; w = 0.85; full = true
			Mode.STAGGER:
				n = "stunned"; t = _clock; w = 0.7
			Mode.DODGE:
				if _rolling:
					n = "roll_r" if _dodge_side * mirror > 0.0 else "roll_l"
					full = true
				else:
					n = "step_r" if _dodge_side * mirror > 0.0 else "step_l"
				t = clampf(_t / maxf(_dur, 0.01), 0.0, 1.0) * SkinDriver.clip_length(n); w = 0.95 if _rolling else 0.9
				skin.clip_travel = 0.0      # the duel moves the body; the clip only shapes it
			Mode.WINDUP, Mode.STRIKE, Mode.FOLLOW:
				n = "sword_attack" if _arc_dir.y < -0.7 else ("cut_a" if _arc_dir.x < 0.0 else "cut_b")
				if two_handed:
					# long blades are swung from the hips with the whole body behind them
					n = "cut_c" if absf(_arc_dir.x) > 0.5 else "sword_attack"
				var sig: String = FINISH_CLIP.get(_finish, "")
				if sig != "" and SkinDriver.has_clip(sig):
					n = sig          # a combo's last cut is thrown with its own, larger body movement
				var u := clampf(_t / maxf(_dur, 0.01), 0.0, 1.0)
				var p := u * 0.4 if mode == Mode.WINDUP else (0.4 + u * 0.25 if mode == Mode.STRIKE else 0.65 + u * 0.35)
				t = p * SkinDriver.clip_length(n); w = 0.65
			Mode.GUARD:
				if _walk_amount > 0.01 and not combat_steps:
					n = "walk"; t = _walk_phase / TAU * SkinDriver.clip_length("walk") / WALK_CYCLES; w = _walk_amount
				elif combat_steps:
					n = "shield_idle" if has_shield else "sword_idle"
					t = _clock; w = 0.55 * (1.0 - _walk_amount)
	if n == "" or not SkinDriver.has_clip(n):
		w = 0.0
	elif n != skin.clip:
		_clip_w = 0.0 if skin.clip_w > 0.3 and not full else _clip_w * 0.5      # change of clip: fade the new one in
	if w > 0.0:
		skin.clip = n
		skin.clip_t = t
		skin.clip_full = full
	_clip_w = lerpf(_clip_w, w, 1.0 - exp(-dtt * (22.0 if full else 12.0))) if dtt > 0.0 else _clip_w
	skin.clip_w = _clip_w if test_clip == "" else 1.0

func _basis_y(y: Vector3, ref: Vector3) -> Basis:
	y = y.normalized()
	var x := y.cross(ref)
	if x.length_squared() < 0.0001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Basis(x, y, x.cross(y))

func _ik(a: Vector3, b: Vector3, la: float, lb: float, pole: Vector3) -> Vector3:
	var d := b - a
	var dist := clampf(d.length(), 0.02, la + lb - 0.001)
	var n := d.normalized()
	var x := (la * la - lb * lb + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(la * la - x * x, 0.0))
	var perp := (pole - n * pole.dot(n)).normalized()
	return a + n * x + perp * h

func _arm(side: String, shoulder: Vector3, hand: Vector3, pole: Vector3) -> void:
	var elbow := _ik(shoulder, hand, UPPER * arm_scale, FORE * arm_scale, pole)
	seg["upper_" + side].transform = Transform3D(_basis_y(elbow - shoulder, Vector3.FORWARD), shoulder)
	seg["fore_" + side].transform = Transform3D(_basis_y(hand - elbow, Vector3.FORWARD), elbow)

func _leg(side: String, hip: Vector3, foot: Vector3) -> void:
	var ankle := foot + Vector3(0, 0.08, 0)
	var total := THIGH + SHIN - 0.01
	if (ankle - hip).length() > total:
		ankle = hip + (ankle - hip).normalized() * total
	_ankle[side] = ankle
	var knee := _ik(hip, ankle, THIGH, SHIN, Vector3(0.15 if side == "r" else -0.15, 0.1, -1))
	seg["thigh_" + side].transform = Transform3D(_basis_y(knee - hip, Vector3.RIGHT), hip)
	seg["shin_" + side].transform = Transform3D(_basis_y(ankle - knee, Vector3.RIGHT), knee)
	seg["foot_" + side].position = Vector3(ankle.x, foot.y, ankle.z)
	seg["foot_" + side].rotation.y = 0.25 if side == "r" else -0.25

## A thin camera-facing ribbon along the path of the blade's tip (and a fainter one at 70% of its
## length), built from the last TRAIL_LIFE seconds of samples. Only fed while a cut or thrust is live;
## what is left ages out, so nothing remains ~0.12 s after the swing ends.
const TRAIL_LIFE := 0.12
func _update_trail() -> void:
	if trail_mesh == null:
		return
	if is_striking():
		var gt := weapon_r.global_transform
		_trail_pts.push_front([_clock, gt * Vector3(0, weapon_len, 0), gt * Vector3(0, weapon_len * 0.7, 0)])
	while not _trail_pts.is_empty() and (_clock - float(_trail_pts[-1][0]) > TRAIL_LIFE or _trail_pts.size() > 24):
		_trail_pts.pop_back()
	trail_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if _trail_pts.size() < 2 or cam == null:
		return
	var heavy := two_handed or scale.x > 1.3
	var col := Color(0.82, 0.87, 0.94)
	if mat_blade.emission_enabled:
		col = col.lerp(mat_blade.emission, 0.6)
	var width := (0.08 if heavy else 0.055) * scale.x
	var strength := 0.7 if heavy else 0.55
	var eye := cam.global_position
	var n := _trail_pts.size()
	for lane in 2:      # 0: the tip, 1: the 70% point (thinner and fainter)
		var w0 := width * (1.0 if lane == 0 else 0.5)
		var a0 := strength * (1.0 if lane == 0 else 0.4)
		trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var prev: Vector3 = _trail_pts[0][1 + lane]
		var side := Vector3.ZERO
		for i in n - 1:
			var p0: Vector3 = _trail_pts[maxi(i - 1, 0)][1 + lane]
			var p1: Vector3 = _trail_pts[i][1 + lane]
			var p2: Vector3 = _trail_pts[i + 1][1 + lane]
			var p3: Vector3 = _trail_pts[mini(i + 2, n - 1)][1 + lane]
			var t1: float = _trail_pts[i][0]
			var t2: float = _trail_pts[i + 1][0]
			for k in (4 if i == n - 2 else 3):
				var f := k / 3.0
				# Catmull-Rom between samples, so a 30 fps arc is still a curve
				var p := 0.5 * ((2.0 * p1) + (p2 - p0) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (3.0 * p1 - p0 - 3.0 * p2 + p3) * f * f * f)
				var u := clampf((_clock - lerpf(t1, t2, f)) / TRAIL_LIFE, 0.0, 1.0)
				var tan := p - prev if (i > 0 or k > 0) else p2 - p1
				var s := tan.cross(eye - p)
				if s.length_squared() > 1e-10:
					side = s.normalized()
				# a few centimetres at most, and never a broad band when the blade passes close to the camera
				var w := minf(w0, eye.distance_to(p) * 0.009) * (1.0 - u) * 0.5
				# the faster the edge travels, the thinner the light is spread
				var a := a0 * (1.0 - u) * (1.0 - u) * clampf(10.0 * maxf(t1 - t2, 0.001) / maxf(p1.distance_to(p2), 0.001), 0.3, 1.0)
				trail_mesh.surface_set_color(Color(col.r, col.g, col.b, a))
				trail_mesh.surface_set_uv(Vector2(0, u))
				trail_mesh.surface_add_vertex(p - side * w)
				trail_mesh.surface_set_uv(Vector2(1, u))
				trail_mesh.surface_add_vertex(p + side * w)
				prev = p
		trail_mesh.surface_end()

func _update_cape(dt: float) -> void:
	if cape_mesh == null:
		return
	var s := scale.x
	var gt := chest.global_transform
	var back := gt.basis.z.normalized()
	var w := (0.2 * bulk) * s
	var top := gt * Vector3(0, 0.3, 0.1)
	var segs := 6
	var seglen := 0.2 * s
	if _cape_pts.size() != segs + 1:
		_cape_pts.clear()
		for i in segs + 1:
			_cape_pts.append(top + Vector3.DOWN * seglen * i)
	_cape_pts[0] = top
	for i in range(1, segs + 1):
		var sway := Vector3(sin(_clock * 1.3 + i * 0.7) * 0.02, 0, cos(_clock * 0.9 + i) * 0.015) * s * i
		var want: Vector3 = _cape_pts[i - 1] + (Vector3.DOWN * 0.93 + back * 0.36).normalized() * seglen + sway
		_cape_pts[i] = _cape_pts[i].lerp(want, 1.0 - exp(-dt * (16.0 - i * 1.6)))
		var d: Vector3 = _cape_pts[i] - _cape_pts[i - 1]
		_cape_pts[i] = _cape_pts[i - 1] + d.normalized() * seglen
		_cape_pts[i].y = maxf(_cape_pts[i].y, global_position.y + 0.03)
	var right := gt.basis.x.normalized()
	cape_mesh.clear_surfaces()
	cape_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segs + 1:
		var ww := w * (1.0 + 0.1 * i)
		# ragged hem
		var hem := 0.06 * s if i == segs else 0.0
		cape_mesh.surface_set_normal(back)
		cape_mesh.surface_add_vertex(_cape_pts[i] - right * ww + Vector3.DOWN * hem)
		cape_mesh.surface_set_normal(back)
		cape_mesh.surface_add_vertex(_cape_pts[i] + right * ww)
	cape_mesh.surface_end()
