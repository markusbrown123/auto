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
var parts: ArmorParts         # the armour worn over the skin, piece by piece (look "parts"); null: the skin's own mesh shows
## Dev: `--oldlook` restores the whole-suit swap and the first generation of weapon models, for comparison.
static var old_look: bool = OS.get_cmdline_user_args().has("--oldlook")
var _ankle := {}
var hunch := 0.0
var arm_scale := 1.0


const RELIC_YAW := -35.0                              # degrees: the old mask's front (+X) turned to face right and a little back
## Dev: `--oldrelic` hangs the first Witness (the mask at the hip) in place of the drone, for comparison.
static var old_relic: bool = OS.get_cmdline_user_args().has("--oldrelic")
var drone: WitnessDrone       # the Witness, when this look has one (look flag "witness")

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
		if old_relic:
			# dev comparison only: the first Witness, a mask hung at the right hip (the model's own front is +X)
			_relic = PropModel.scenery(body, "res://assets/models/witness_relic.glb", 0.4, Vector3(0.24, 0.66, 0.06), RELIC_YAW)
		else:
			# the Witness keeps station at the sword-side shoulder: its own node, which follows and looks after itself
			drone = WitnessDrone.new()
			add_child(drone)
			drone.build()
			drone.attach(self)
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
			if cfg.get("parts") is Dictionary and not old_look:
				wear_parts(cfg.parts)
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

## Real armour: dresses the body from a loadout {body, helm, chest, shoulders, arms, legs, boots -> suit id}
## (Duel.player_look builds it from what is equipped). The first call hides the skin's own mesh; later calls swap only
## the pieces that changed (the Armory's previews). The floor contact, the blade's clearances and the volumes an
## opponent's blade meets are measured again from what is worn. False when this skin cannot wear parts.
func wear_parts(loadout: Dictionary) -> bool:
	if skin == null or old_look:
		return false
	var b := str(loadout.get("body", "m"))
	if str(cfg.get("skin", "")) != ArmorParts.host_path(b) or not ArmorParts.has_part(b, ArmorParts.host, "chest"):
		return false          # the parts are bound to the base body's skeleton and to no other
	var wear := ArmorParts.resolve(loadout)
	if parts == null:
		parts = ArmorParts.dress(skin.skel, b, wear)
		for mi: MeshInstance3D in parts.nodes.values():
			mi.lod_bias = 1.0
	else:
		parts.wear_all(wear)
	skin.measure_parts(parts)
	return true

func has_parts() -> bool:
	return parts != null

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
	_gear = str(look.get("gear", "")) if not old_look and kind != "claws" and GearModel.exists(str(look.get("gear", ""))) else ""
	if kind == "claws" and look.has("skin"):
		weapon_len = 0.45          # the model's own claws are the weapon
	elif _gear != "":
		# hand-modelled gear is already in the rig's conventions and in metres: placed by its manifest, never measured
		var h := GearModel.hold(_gear)
		var ws := float(look.get("weapon_scale", 1.0))      # (a foe's own scaling of what it carries)
		for k: String in ["scale", "len", "pommel", "off_hand", "half"]:
			h[k] = float(h[k]) * ws
		_gear_hold = h
		var low := int(Game.settings.get("quality", 1)) == 0
		for n: Node3D in ([weapon_r, weapon_l] if dual else [weapon_r]):
			var g := GearModel.spawn(_gear, 9.0, low, look.get("gear_mod", {}))
			var left := n == weapon_l
			# a pair is one model and its mirror image; the knuckle side of every hilt is +X here
			g.transform = Transform3D(Basis(Vector3.UP, float(h.turn)).scaled(Vector3(-float(h.scale) if left else float(h.scale), float(h.scale), float(h.scale))), Vector3.ZERO)
			n.add_child(g)
		weapon_len = float(h.len)
		_warn_overlay = StandardMaterial3D.new()
		_warn_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_warn_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_warn_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_warn_overlay.albedo_color = Color(1.0, 0.1, 0.03, 0.0)
		for n2 in [weapon_r, weapon_l]:
			for mi in n2.find_children("*", "MeshInstance3D", true, false):
				mi.material_overlay = _warn_overlay
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
	# how far the handle runs below the grip point, and where on it the off hand of a two-handed grip closes
	var g := float(PropModel.GRIP.get(kind, 0.11))
	_pommel = weapon_len * g / (1.0 - g) if PropModel.exists(model) and kind != "claws" else 0.14
	_off_grip = clampf(_pommel * 0.62, 0.1, 0.22)
	_blade_half = 0.11 if kind in ["axe", "cleaver"] else (0.05 if kind in ["greatsword", "glaive"] else 0.025)
	if _gear != "":
		# the manifest's own measurements: where the pommel ends, where the second hand closes, how wide the blade is
		var h2 := _gear_hold
		_pommel = float(h2.pommel)
		_off_grip = float(h2.off_hand) if two_handed else clampf(_pommel * 0.62, 0.08, 0.22)
		_blade_half = float(h2.half)
	_present_stop()
	if dual or two_handed:
		set_shield(null)

var _gear_hold := {}
var _gear := ""                # the hand-modelled piece in the sword hand (GearModel id), "" for a fitted or built weapon
var _pommel := 0.14
var _blade_half := 0.025      # half the width of the blade or axe head: what must also clear the body
var _off_grip := 0.2

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
	_sh_gear = ""
	_sh_c = Vector3.ZERO
	_sh_hw = 0.27
	_sh_hh = 0.41
	var sg := str(look.get("gear", ""))
	if not old_look and GearModel.exists(sg):
		# a hand-modelled shield: its origin is the grip bar, its face is -Z, the arm strap is toward -X
		var h := GearModel.hold(sg)
		var g := GearModel.spawn(sg, 9.0, int(Game.settings.get("quality", 1)) == 0)
		g.scale = Vector3.ONE * float(h.scale)
		shield.add_child(g)
		_sh_gear = sg
		_sh_c = h.centre
		_sh_hw = float(h.hw)
		_sh_hh = float(h.hh)
		return
	if PropModel.exists(str(look.get("model", ""))) and PropModel.shield(shield, str(look.model), 0.82, not old_look):
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(str(look.get("color", "#4a3a2a")))
	m.metallic = 0.4
	m.roughness = 0.6
	var face := _cyl(shield, 0.3, 0.3, 0.04, Vector3.ZERO, m, 6)
	face.rotation.x = PI / 2
	face.scale = Vector3(0.85, 1.25, 1.0)
	var rim := _cyl(shield, 0.07, 0.07, 0.07, Vector3(0, 0, -0.03), mat_metal, 10)      # the boss, on the face (-Z)
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
	_au_begin("thrust" if (kind == "thrust" or kind == "lunge") else _au_label(), maxf(windup - swing * 0.5, 0.0), windup, "")

## Player attack: a short rise then the cut. Contact is at 60% of `time`.
## `finish` names the kind of combo this cut completes ("" for an ordinary cut): each kind has its own body.
var _finish := ""
const FINISH_CLIP := {"Heavy": "sword_attack", "Guard-breaking": "shield_dash", "Counter": "lunge", "Armour-piercing": "lunge",
	"Critical": "cut_c", "Finisher": "cut_c", "Fast": ""}
func swing(dir: Vector2, time: float, finish: String = "") -> void:
	if _present == "recall":
		_present_stop()        # a cut thrown while the weapon is still forming: it is whole at once
	_finish = finish
	_pin_t = 0.0
	_brace_t = 0.0
	_arc_dir = Vector3(dir.x * mirror, dir.y, 0).normalized()
	_swing = time * 0.5
	_go(Mode.WINDUP, time * 0.6)
	_root_target = Vector3(0, 0, -0.25)
	if mirror > 0.0:
		if _clock - _au_hist_t > 1.6:
			_au_hist.clear()
		_au_hist_t = _clock
		_au_hist.append(_au_label())
		if _au_hist.size() > 6:
			_au_hist.pop_front()
	_au_begin(_au_label(), 0.0, time * 0.6, finish)
	if finish != "":
		_au_hist.clear()

var _parry_t := 0.0
func parry(dir: Vector2) -> void:
	_parry_t = 0.5
	_arc_dir = Vector3(dir.x * mirror, dir.y, 0).normalized()
	_swing = 0.16
	_finish = ""
	_au_stop()
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
## (Measured on the rig: the hand is carried forward by the arc, by the step into the cut and by the lean of the body;
## the last fifth of the blade is what should meet the opponent, not its middle.)
func reach() -> float:
	if not _au.is_empty():
		return (float(_au.reach) + (AU_STEP if mirror > 0.0 else AU_STEP_FOE)) * scale.x
	# (a foe winds up leaning back and has stepped in less by the middle of its cut than the player has)
	return (0.05 + 0.5 * arm_scale + REACH_STEP - (0.15 if mirror < 0.0 else 0.0) + weapon_len * 0.8) * scale.x

const REACH_STEP := 0.4       # metres the step and lean of a cut carry the sword hand forward

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
	if not _au.is_empty():
		# an authored cut is stopped where the rules settled it: at its contact pose, not on its way through
		if float(_au.freeze) < 0.0:
			_au.freeze = minf(_au_time(_au_t), float(_au.tc))
		_solve(0.0)
		return
	var ap := _arc_point(-0.12, 0.0)
	_pin_hand = ap[0]
	_pin_blade = ap[1]
	_pin_t = hold
	_solve(0.0)

## The blow has landed on a body at `world_point` (the duel may call this on a hit; the rig also finds the moment
## itself, see `auto_bite`). The blade is held where it meets the near side of that body, then drawn back.
func bite(world_point: Vector3, hold: float = BITE_HOLD) -> void:
	if _pin_t > 0.0 or mode == Mode.DEAD:
		return
	if not _au.is_empty():
		if float(_au.freeze) < 0.0:
			_au.freeze = _au_time(_au_t)
			_go(Mode.FOLLOW, hold + 0.22)
		return
	var local: Vector3 = body.to_local(world_point)
	# the near side: a little toward this fighter and toward the side the cut comes from
	var target := local + Vector3(0, 0, 0.1) - _arc_dir * 0.12
	var hand := _hand
	var dir := target - hand
	if dir.length() < 0.2:
		return
	_pin_hand = hand
	_pin_blade = dir.normalized()
	_pin_t = hold
	_go(Mode.FOLLOW, hold + 0.22)
	_solve(0.0)

const BITE_HOLD := 0.13
const BITE_FROM := 0.0
var auto_bite := true         # cuts and thrusts stop in the first body they reach
var _target_cache: Array = []
var _target_frame := -1

## Other fighters standing with this one (the duel's two rigs are siblings), as world-space capsules [a, b, r].
func _targets() -> Array:
	var f := Engine.get_process_frames()
	if f == _target_frame:
		return _target_cache
	_target_frame = f
	_target_cache = []
	var par := get_parent()
	if par == null:
		return _target_cache
	for c in par.get_children():
		if c != self and c is Node3D and c.has_method("hit_caps") and (c as Node3D).visible \
				and (c as Node3D).global_position.distance_to(global_position) < 9.0:
			_target_cache.append_array(c.call("hit_caps"))
	return _target_cache

## This fighter's body for an opponent's blade: trunk and head, in world space.
func hit_caps() -> Array:
	if mode == Mode.DEAD:
		return []
	var g := body.global_transform
	var k := scale.x
	if skin and skin.ok:
		var hb: Array = skin.ball("Head")
		var guard_caps: Array = []
		if shield and (blocking or _brace_t > 0.0):
			var sc := shield.global_transform * _sh_c
			guard_caps.append([sc, sc, maxf(0.3, minf(_sh_hw, _sh_hh) * 1.1) * k])      # a raised shield is met first
		if _parry_t > 0.0:
			# a blade thrown up in a parry is met before the body behind it
			var wt := weapon_r.global_transform
			guard_caps.append([wt * Vector3(0, weapon_len * 0.15, 0), wt * Vector3(0, weapon_len, 0), 0.09 * k])
		return guard_caps + [[g * skin.point("Hips"), g * skin.point("Neck"), minf(float(skin.ball("Hips")[1]), 0.24) * 0.8 * k], [g * (hb[0] as Vector3), g * (hb[0] as Vector3), float(hb[1]) * 0.8 * k]]
	return [[pelvis.global_position, chest.global_transform * Vector3(0, 0.3, 0), 0.19 * bulk * k], [head.global_position, head.global_position, 0.13 * k]]

## Whether a blade held at `hand` along `dir` (rig body space) is inside one of the capsules (world space).
## `from` and `depth`: the part of the blade tested, and how far inside the capsule's surface counts as a bite.
func _blade_in(hand: Vector3, dir: Vector3, caps: Array, from: float = 0.3, depth: float = 0.3) -> bool:
	var g := body.global_transform
	var a := g * (hand + dir * weapon_len * from)
	var b := g * (hand + dir * weapon_len)
	for c: Array in caps:
		var ca: Vector3 = c[0]
		var cb2: Vector3 = c[1]
		var d: float
		if ca.is_equal_approx(cb2):
			d = Geometry3D.get_closest_point_to_segment(ca, a, b).distance_to(ca)
		else:
			var cp := Geometry3D.get_closest_points_between_segments(a, b, ca, cb2)
			d = cp[0].distance_to(cp[1])
		if d < float(c[2]) * (1.0 - depth):
			return true
	return false

## Put the shield where the blow lands.
func brace(world_point: Vector3, hold: float = 0.3) -> void:
	var local: Vector3 = body.to_local(world_point)
	var shoulder := Vector3(-0.25, 1.35, 0.0)
	var max_reach := (UPPER + FORE) * arm_scale - 0.06
	_brace_at = shoulder + (local - shoulder).limit_length(max_reach)
	_brace_at.z = minf(_brace_at.z, -0.25)
	_brace_t = hold
	_hand_l = _brace_at
	_au_brace = 0.0
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
	_parry_t = maxf(0.0, _parry_t - dt)
	_au_tick(dt)
	_present_tick(dt)
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

func _out_of_helm(p: Vector3) -> Vector3:
	var helm := Vector3(0, 1.74 - hunch * 0.3, 0.04)
	var off := p - helm
	if off.length() < 0.38:
		off.z = minf(off.z, -0.02)
		return helm + off.normalized() * 0.38
	return p

## The low end of a rising or falling cut stops short of pointing back at the wielder: past this angle from straight
## ahead the hand would be drawn into the belly and the blade into the wielder's own legs and the floor.
const ARC_LOW := 1.12
func _arc_low(angle: float) -> float:
	var steep := clampf((absf(_arc_dir.y) - 0.3) / 0.4, 0.0, 1.0)
	if steep <= 0.0 or _arc_dir.y * sin(angle) >= 0.0 or absf(angle) <= ARC_LOW:
		return angle
	return lerpf(angle, signf(angle) * ARC_LOW, steep)

func _arc_point(theta: float, lag: float) -> Array:
	var f := Vector3(0, 0, -1)
	var d := _arc_dir
	lag = _arc_low(theta + lag) - _arc_low(theta)
	theta = _arc_low(theta)
	# the follow-through ends with the blade out to the side, not wrapped back round the wielder's own shoulder
	# (a two-handed grip cannot follow it there at all)
	lag = minf(theta + lag, 1.4 if two_handed else 1.8) - theta
	var c := Vector3(0.05 * signf(d.x) * -0.0, 1.34 - hunch * 0.25, -0.05)
	var r := 0.5 * arm_scale
	var p := c + (f * cos(theta) + d * sin(theta)) * r
	# horizontal cuts are carried at shoulder height in the wind-up so they read clearly
	p.y += 0.22 * (1.0 - absf(d.y)) * clampf(-theta / ARC_MAX, 0.0, 1.0)
	# keep the arm in front of the body
	p.z = minf(p.z, 0.1)
	# and the hand out of the wielder's own head: an overhead wind-up passes above and in front of the helm, not through it
	p = _out_of_helm(p)
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
			var full_cut := _dur > 0.17
			var bitten := false
			if full_cut and auto_bite and _pin_t <= 0.0 and dt > 0.0 and _au.is_empty():
				# The arc is walked in small steps from where it was last frame: the first step at which the blade is in
				# an opponent's body is where the cut stops. It bites there; it does not sail on through to the far side.
				var u_from := clampf((_t - dt) / _dur, 0.0, 1.0)
				var targets := _targets()
				if not targets.is_empty():
					for i in range(1, 7):
						var ui := lerpf(u_from, u2, i / 6.0)
						if ui < BITE_FROM:
							continue      # the rules settle a blow at the middle of the arc: a parry or a block pins the blade first
						var api := _arc_point(lerpf(-ARC_MAX, ARC_MAX * 0.9, ui), lerpf(-0.5, 0.45, ui))
						if _blade_in(api[0], api[1], targets):
							u2 = ui
							bitten = true
							break
			_theta = lerpf(-ARC_MAX if full_cut else -0.9, ARC_MAX * 0.9 if full_cut else 0.35, u2)
			var ap2 := _arc_point(_theta, lerpf(-0.5, 0.45, u2))
			hand_t = ap2[0]
			blade_t = ap2[1]
			direct = true
			lean_t = 0.28 + hunch
			twist_t = -_arc_dir.x * 0.5 * (u2 * 2.0 - 1.0)
			crouch_t = 0.1
			if bitten:
				_pin_hand = ap2[0]
				_pin_blade = ap2[1]
				_pin_t = BITE_HOLD
				_go(Mode.FOLLOW, BITE_HOLD + 0.22)
			elif u2 >= 1.0:
				_go(Mode.FOLLOW, 0.3)
		Mode.THRUST:
			var u3 := clampf(_t / _dur, 0.0, 1.0)
			var thrust_to := Vector3(0.12, 1.2 - hunch * 0.2, -0.78 * arm_scale)
			blade_t = Vector3(-0.05, 0.08, -1).normalized()
			var stuck := false
			if auto_bite and _pin_t <= 0.0 and dt > 0.0 and _au.is_empty():
				# the point goes in a hand's breadth and stops; the rest of the lunge is not driven through the body
				var u_from2 := clampf((_t - dt) / _dur, 0.0, 1.0)
				var targets2 := _targets()
				if not targets2.is_empty():
					for i in range(1, 7):
						var ui2 := lerpf(u_from2, u3, i / 6.0)
						if ui2 >= BITE_FROM and _blade_in(_thrust_from.lerp(thrust_to, ease(ui2, 0.4)), blade_t, targets2, 0.75, 0.35):
							u3 = ui2
							stuck = true
							break
			hand_t = _thrust_from.lerp(thrust_to, ease(u3, 0.4))
			direct = true
			lean_t = 0.35 + hunch
			twist_t = -0.3
			crouch_t = 0.14
			if stuck:
				_pin_hand = hand_t
				_pin_blade = blade_t
				_pin_t = BITE_HOLD
				_go(Mode.FOLLOW, BITE_HOLD + 0.22)
			elif u3 >= 1.0:
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
	if _sheath_w > 0.5 and mode == Mode.GUARD:
		hand_t = Vector3(0.33, 0.9, -0.04)
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
	_au_update(dt)
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
		hl = hr - _blade * _off_grip
	elif dual:
		hl = _out_of_helm(Vector3(-_hand.x, _hand.y - 0.04, _hand.z + 0.05))
		if absf(_hand.x) < 0.14:
			# both hands on the centre line (an overhead or rising cut): the off hand keeps to its own side
			hl.x = -0.14 - 0.5 * (0.14 - absf(_hand.x))
		if mode == Mode.STRIKE:
			# the second blade follows a beat behind, crossing the first
			var ap := _arc_point(_theta - 0.55, -0.4)
			hl = ap[0] + Vector3(-0.12 * signf(_arc_dir.x + 0.01), -0.1, 0.04)
			bl = ap[1]
	elif has_shield:
		hl = Vector3(-0.05, 1.3, -0.42) if blocking else Vector3(-0.3, 1.08, -0.24)
		if _sh_gear != "" and not blocking:
			# a strapped shield faces where the outside of the forearm faces: the forearm is carried across the body
			hl = Vector3(-0.08, 1.15, -0.37)
		if _brace_t > 0.0:
			# the shield goes to where the blow lands, then is driven back toward the body by it
			_brace_t -= get_process_delta_time() * time_scale
			var k := clampf(_brace_t / 0.3, 0.0, 1.0)
			hl = _brace_at + Vector3(0, -0.04, 0.16) * (1.0 - k)
	else:
		hl = Vector3(-0.32, 0.86, -0.05)
	if _walk_amount > 0.01 and not two_handed and not blocking:
		hl = hl.lerp(Vector3(-0.34, 0.95, -0.08 + 0.12 * sin(_walk_phase)), _walk_amount)
	# a cut wound up across the body: the shield swings open to the side, out of the sword arm's way
	var across := 0.0
	if has_shield and not blocking and _brace_t <= 0.0 and mode in [Mode.WINDUP, Mode.STRIKE, Mode.FOLLOW, Mode.GUARD]:
		across = clampf((0.12 - _hand.x) / 0.45, 0.0, 1.0)
		# low when the sword passes high, high and forward when it passes low: the blade never has to go through the shield arm
		hl = hl.lerp(Vector3(-0.5, 1.46, -0.14) if (_arc_dir.x < -0.3 and _arc_dir.y < -0.3) else (Vector3(-0.52, 1.0, -0.2) if _sh_gear != "" else Vector3(-0.56, 0.92, 0.04)), across)
	_shield_open = lerpf(_shield_open, across, 0.4)
	_hand_l = _out_of_helm(_hand_l.lerp(hl, 0.4)) if not two_handed else hl
	_blade_l = _blade_l.lerp(bl, 0.4).normalized()
	var hl2 := sh_l + (_hand_l - sh_l).limit_length(reach)
	_arm("l", sh_l, hl2, Vector3(-0.7, -0.8, 0.35))
	weapon_l.transform = Transform3D(_basis_y(_blade_l, Vector3(0, 0, -1) if absf(_blade_l.z) < 0.9 else Vector3.RIGHT), hl2)
	if shield:
		shield.transform = Transform3D(Basis.from_euler(Vector3(0.1, lerpf(0.35, 1.25, _shield_open) if not blocking else 0.05, 0)), hl2 + Vector3(-0.02, 0, -0.07))
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
		_au_apply()
		var pinned := _pin_t > 0.0 or _brace_t > 0.0
		var hands: Dictionary = skin.drive({"pelvis": pel + Vector3(0, 0.06, 0), "pelvis_rot": Basis.from_euler(pelvis.rotation), "chest_rot": cb,
			"head_rot": Basis.from_euler(head.rotation), "hand_r": hr, "hand_l": hl2, "ankle_r": _ankle.r, "ankle_l": _ankle.l,
			"follow_r": 0.0 if _pin_t > 0.0 else 1.0, "follow_l": 0.0 if pinned else 1.0, "settle": true, "dt": get_process_delta_time() * time_scale})
		_fit_props(hands)
		if _relic:
			# hung from the belt just outside whatever armour this suit has at the hip; it turns and travels with the hips
			var ht: Basis = skin.turn("Hips")
			var out: float = maxf(skin.extent("Hips", Vector3.RIGHT), skin.extent("RightUpLeg", Vector3.RIGHT) + (skin.point("RightUpLeg") - skin.point("Hips")).dot(ht.x)) + 0.035
			_relic.transform = Transform3D(ht * Basis(Vector3.UP, deg_to_rad(RELIC_YAW)), skin.point("Hips") + ht * Vector3(out, -0.36, 0.05))

## With a generated body: the weapons and shield are fitted to the real hands after the skeleton is posed.
## The blade is kept out of the wielder's own head, trunk and thighs and off the floor; the hand closes round the
## handle; the off hand of a two-handed grip is brought onto it; the shield never goes under the floor.
var _shield_open := 0.0
var _shield_local := Transform3D.IDENTITY      # the shield against the forearm, as last held in guard
var _whole_w := 0.0
func _fit_props(hands: Dictionary) -> void:
	var whole := skin.clip_full and skin.clip_w > 0.0
	_whole_w = lerpf(_whole_w, 1.0 if whole else 0.0, 0.35)
	skin.pole_l = Vector3(-1.0, -0.42, 0.3) if (shield and _sh_gear != "") else Vector3(-0.7, -0.8, 0.35)      # (a strapped shield: elbow out)
	var caps := _body_caps()
	if shield:
		var fore := skin.frame("LeftForeArm")
		var held := Transform3D(shield.transform.basis, hands.l + Vector3(-0.02, 0, -0.07))
		var strap := _sh_gear != ""
		var grip_at := Vector3.ZERO
		if strap:
			# A shield with a grip and a strap is worn, not floated: the hand closes on the bar, the forearm lies in the
			# strap, so the board follows the forearm exactly (its own +X runs from the elbow to the hand) and stays as
			# upright as that allows. Its face (-Z) is then the outside of the forearm, away from the bearer.
			var x := (skin.point("LeftHand") - fore.origin).normalized()
			var up := Vector3.UP + Vector3(0, 0, 1) * x.y      # an arm let hang carries the board on its side, face outward
			up = up - x * up.dot(x)
			up = up.normalized() if up.length() > 0.05 else Vector3(0, 0, -1)
			# thrown about by a fall, a roll or a blow (clips made without a shield), the forearm is turned in its strap
			# so that the board faces away from the chest instead of cutting through it
			var body_w := _whole_w if (_au_state == "" or mode == Mode.DEAD) else 0.0
			if body_w > 0.01:
				var out := fore.origin.lerp(skin.point("LeftHand"), 0.6) - skin.point("Spine2")
				out = out - x * out.dot(x)
				if out.length() > 0.02:
					var up_b := (-out.normalized()).cross(x).normalized()
					up = (up.slerp(up_b, body_w) if up.dot(up_b) > -0.98 else up_b).normalized()
					up = (up - x * up.dot(x)).normalized()
			grip_at = _on_forearm(skin.grip("Left", up), x)
			held = Transform3D(Basis(x, up, x.cross(up)), grip_at)
		elif _whole_w < 0.01:
			_shield_local = fore.affine_inverse() * held
		else:
			# strapped to the forearm: where a whole-body clip takes the arm, the shield goes
			var strapped := fore * _shield_local
			if mode != Mode.DEAD:
				# thrown about by a roll or a blow, the board stays on the outside of the forearm, facing away from the chest
				var hand_at: Vector3 = skin.point("LeftHand")
				var axis := (hand_at - fore.origin).normalized()
				var mid := fore.origin.lerp(hand_at, 0.6)
				var out := mid - skin.point("Spine2")
				out = out - axis * out.dot(axis)
				if out.length() > 0.02:
					out = out.normalized()
					var up := Vector3.UP - out * out.y
					up = up.normalized() if up.length() > 0.2 else axis
					strapped = Transform3D(Basis(up.cross(-out).normalized(), up, -out), mid + out * 0.07)
			held = held.interpolate_with(strapped, _whole_w)
		# the board is kept off the head and trunk: moved away from them by however far its nearest point is inside
		var board := Transform3D(held.basis, held * _sh_c)
		var board0 := board.origin
		for c2: Array in _arm_caps("Right") + [caps[2], caps[4], caps[0], caps[1]]:
			var q2: Vector3 = Geometry3D.get_closest_point_to_segment(board.origin, c2[0], c2[1])
			var l2 := board.affine_inverse() * q2
			var e2 := l2.x * l2.x / (_sh_hw * _sh_hw + 0.005) + l2.y * l2.y / (_sh_hh * _sh_hh + 0.008)
			var on_board := board * (Vector3(l2.x, l2.y, 0) / maxf(1.0, sqrt(e2)))
			var r2: float = float(c2[2]) + 0.02
			var v2 := on_board - q2
			if v2.length() < r2:
				var away := v2.normalized() if v2.length() > 0.005 else -board.basis.z.normalized()
				board.origin += away * (r2 - v2.length())
		# no part of the rim under the floor
		var low := 1e9
		for c: Vector3 in SHIELD_RIM:
			low = minf(low, (board * Vector3(c.x * _sh_hw / 0.27, c.y * _sh_hh / 0.41, 0)).y)
		if low < 0.015:
			board.origin.y += 0.015 - low
		var shift := board.origin - board0
		if strap and shift.length() > 0.003:
			# the arm goes with the board it is strapped to (the hand never leaves the bar)
			shift = shift.limit_length(0.16 if _whole_w < 0.5 else 0.3)
			shift.y = maxf(shift.y, 0.07 - hands.l.y)      # (the hand is not pushed into the floor)
			skin.reach_hand("Left", hands.l + shift)
			var x2 := (skin.point("LeftHand") - skin.point("LeftForeArm")).normalized()
			var up2 := held.basis.y - x2 * held.basis.y.dot(x2)
			up2 = up2.normalized() if up2.length() > 0.05 else held.basis.y
			held = Transform3D(Basis(x2, up2, x2.cross(up2)), _on_forearm(skin.grip("Left", up2), x2))
		else:
			held.origin += shift
		shield.transform = held
	# --- right hand
	var dir: Vector3 = weapon_r.transform.basis.y
	var carried := skin.hand_axis("Right")
	var au_arm := whole and _au_state != "" and skin.arm_r > 0.0
	if au_arm:
		# an authored cut: the blade is where the clip's own hand holds it, from the first frame
		dir = skin.clip_axis.get("Right", carried)
	elif _whole_w > 0.01 and carried != Vector3.ZERO and _pin_t <= 0.0 and _au_state == "":
		# a whole-body clip (a fall, a hit, a roll) throws the arm: the weapon goes with the hand, not with the old aim
		dir = dir.slerp(carried, _whole_w) if dir.dot(carried) > -0.99 else carried
	if skin.xf_u() < 1.0 and _pin_t <= 0.0:
		dir = _xf_dir_r.slerp(dir, skin.xf_u()) if _xf_dir_r.dot(dir) > -0.99 else dir
	if _pin_t <= 0.0:
		# (on the broad-shouldered base body a blade brought back over the shoulder also has to clear its own upper arm)
		dir = _clear_blade(hands.r, dir, weapon_len, caps + ([] if two_handed else _arm_caps("Left")) + ([_arm_caps("Right")[0]] if parts != null and not two_handed else []))
	if shield and _pin_t <= 0.0:
		dir = _clear_shield(hands.r, dir, weapon_len)
	dir = _off_floor(hands.r, dir, weapon_len, _pommel)
	var pr: Vector3 = skin.grip("Right", dir)
	var dir2 := _off_floor(pr, dir, weapon_len, _pommel)
	if not dir2.is_equal_approx(dir):
		dir = dir2
		pr = skin.grip("Right", dir)
	weapon_r.transform = Transform3D(_held_basis("Right", dir), pr)
	_last_dir_r = dir
	# --- left hand
	if two_handed:
		weapon_l.position = pr
		if mode != Mode.DEAD and _sheath_w <= 0.0:
			skin.reach_hand("Left", pr - dir * _off_grip)
			skin.grip("Left", dir)
	elif dual:
		var dl: Vector3 = weapon_l.transform.basis.y
		var carried_l := skin.hand_axis("Left")
		if whole and _au_state != "" and skin.arm_l > 0.0:
			dl = skin.clip_axis.get("Left", carried_l)
		elif _whole_w > 0.01 and carried_l != Vector3.ZERO and _au_state == "":
			dl = dl.slerp(carried_l, _whole_w) if dl.dot(carried_l) > -0.99 else carried_l
		if skin.xf_u() < 1.0:
			dl = _xf_dir_l.slerp(dl, skin.xf_u()) if _xf_dir_l.dot(dl) > -0.99 else dl
		_last_dir_l = dl
		dl = _clear_blade(hands.l, dl, weapon_len, caps + _arm_caps("Right"))
		dl = _off_floor(hands.l, dl, weapon_len, _pommel)
		var pl: Vector3 = skin.grip("Left", dl)
		var dl2 := _off_floor(pl, dl, weapon_len, _pommel)
		if not dl2.is_equal_approx(dl):
			dl = dl2
			pl = skin.grip("Left", dl)
		weapon_l.transform = Transform3D(_held_basis("Left", dl), pl)
	else:
		weapon_l.position = hands.l
	_fit_sheath()
	_fit_fingers()

## The grip bar of a strapped shield lies on the forearm's own line, in the middle of the fist: the point where the
## hand closes, moved onto that line (the board then stands clear of the forearm by the depth of its grip posts).
func _on_forearm(grip_at: Vector3, x: Vector3) -> Vector3:
	var w: Vector3 = skin.point("LeftHand")
	return w + x * maxf((grip_at - w).dot(x), 0.05)

## How a held weapon is turned about its own length. Hand-modelled gear has a true edge and a knuckle side (+X):
## it lies over the knuckles of the hand that holds it, so a cut leads with the edge and a knuckle bow guards the
## fingers. (A mirrored left-hand blade has its knuckle side on -X.) Fitted and built weapons keep the old rule.
func _held_basis(side: String, dir: Vector3) -> Basis:
	if _gear != "" and skin.grip_fwd.has(side):
		var f: Vector3 = skin.grip_fwd[side]
		var x := f - dir * f.dot(dir)
		if x.length() > 0.1:
			x = x.normalized() * (-1.0 if side == "Left" else 1.0)
			return Basis(x, dir, x.cross(dir))
	return _basis_y(dir, Vector3(0, 0, -1) if absf(dir.z) < 0.9 else Vector3.RIGHT)

## Hands close on what they hold (only on a fighter carrying the new equipment: other models keep their own hands).
var _curl_r := 1.0
var _curl_l := 1.0
func _fit_fingers() -> void:
	if parts == null and _gear == "" and _sh_gear == "":
		return
	if str(cfg.get("weapon", "")) == "claws":
		return
	var away := _sheath_w >= 1.0 and _draw_dir == 0
	var grab := 1.0
	if _draw_dir != 0:
		var u := clampf(_draw_t / AU_DRAW_TIME, 0.0, 1.0)
		grab = smoothstep(DRAW_GRAB - 0.14, DRAW_GRAB, u if _draw_dir > 0 else 1.0 - u)
	var want_r := (0.22 if away else lerpf(0.22, 1.0, grab)) * (1.0 - 0.85 * _present_open())
	var want_l := want_r if (dual or two_handed) else (1.0 if shield else 0.22)
	if shield and _present == "recall" and _present_shield:
		want_l = 1.0 - 0.85 * _present_open()
	_curl_r = lerpf(_curl_r, want_r, 0.4)
	_curl_l = lerpf(_curl_l, want_l, 0.4)
	skin.curl("Right", _curl_r)
	skin.curl("Left", _curl_l)

## The shield's board in its own space: where its centre is from the grip, and half its width and height.
var _sh_gear := ""
var _sh_c := Vector3.ZERO
var _sh_hw := 0.27
var _sh_hh := 0.41

const SHIELD_RIM := [Vector3(0.27, 0.41, 0), Vector3(-0.27, 0.41, 0), Vector3(0.27, -0.41, 0), Vector3(-0.27, -0.41, 0), Vector3(0, -0.41, 0), Vector3(0, 0.41, 0)]

## The wielder's own body as a few capsules [a, b, radius] in rig body space: head, trunk, thighs.
func _body_caps() -> Array:
	var head_b: Array = skin.ball("Head")
	var hips: Vector3 = skin.point("Hips")
	var neck: Vector3 = skin.point("Neck")
	var trunk_r: float = minf(float(skin.ball("Hips")[1]), 0.24) * 0.9
	var out: Array = [[head_b[0], head_b[0], float(head_b[1]) * 1.2], [hips, neck, trunk_r]]
	for side: String in ["Left", "Right"]:
		var knee: Vector3 = skin.point(side + "Leg")
		out.append([skin.point(side + "UpLeg"), knee, trunk_r * 0.5])
		out.append([knee, skin.point(side + "Foot"), trunk_r * 0.5])
	return out

## The arm on one side, for the blade held in the other hand.
func _arm_caps(side: String) -> Array:
	var el: Vector3 = skin.point(side + "ForeArm")
	return [[skin.point(side + "Arm"), el, 0.08], [el, skin.point(side + "Hand"), 0.075]]

## Turn a blade about the hand that holds it until it is clear of the body.
func _clear_blade(hand: Vector3, dir: Vector3, length: float, caps: Array) -> Vector3:
	for pass_i in 2:
		for c: Array in caps:
			var from := hand + dir * length * 0.2      # the first part of the blade is at the hand, which may rest on the body
			var tip := hand + dir * length
			var a: Vector3 = c[0]
			var b: Vector3 = c[1]
			var r: float = float(c[2]) + _blade_half + (AU_CLEAR if _au_state != "" else 0.0)
			var p: Vector3
			var q: Vector3
			if a.is_equal_approx(b):
				q = a
				p = Geometry3D.get_closest_point_to_segment(a, from, tip)
			else:
				var cp := Geometry3D.get_closest_points_between_segments(from, tip, a, b)
				p = cp[0]
				q = cp[1]
			var qh: Vector3 = Geometry3D.get_closest_point_to_segment(hand, a, b)
			if hand.distance_to(qh) < r and hand.distance_to(qh) > 0.001:
				# the hand itself rests on this part of the body: the blade at least does not point into it
				var nh := (hand - qh).normalized()
				if dir.dot(nh) < 0.05:
					dir = (dir + nh * (0.05 - dir.dot(nh))).normalized()
				continue
			var d := p.distance_to(q)
			if d < r:
				var n := (p - q) / d if d > 0.001 else Vector3(0, 0, -1)
				var moved := q + n * (r + 0.01)
				if (moved - hand).length() > 0.05:
					dir = (moved - hand).normalized()
	return dir

## A blade does not pass through the wielder's own shield: its point stays on the side of the board the hand is on.
func _clear_shield(hand: Vector3, dir: Vector3, length: float) -> Vector3:
	var st := Transform3D(shield.transform.basis, shield.transform * _sh_c)
	var n := st.basis.z.normalized()
	var tip := hand + dir * length
	var dh := (hand - st.origin).dot(n)
	var dt := (tip - st.origin).dot(n)
	if absf(dh) < 0.02 or dh * dt > 0.0:
		return dir
	var cross := st.affine_inverse() * hand.lerp(tip, dh / (dh - dt))
	if cross.x * cross.x / (_sh_hw * _sh_hw + 0.017) + cross.y * cross.y / (_sh_hh * _sh_hh + 0.032) > 1.0:
		return dir
	return (tip + n * (signf(dh) * 0.03 - dt) - hand).normalized()

## Tilt a blade just enough that neither its point nor its pommel is under the floor.
func _off_floor(hand: Vector3, dir: Vector3, length: float, pommel: float) -> Vector3:
	var floor_y := 0.02
	var lo := clampf((floor_y - hand.y) / maxf(length, 0.01), -1.0, 1.0)
	var hi := clampf((hand.y - floor_y) / maxf(pommel, 0.01), -1.0, 1.0)
	if dir.y >= lo and dir.y <= hi:
		return dir
	var y := clampf(dir.y, lo, maxf(lo, hi))
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() < 0.001:
		flat = Vector3(0, 0, -1)
	return flat.normalized() * sqrt(maxf(1.0 - y * y, 0.0)) + Vector3.UP * y

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


# ================================================================ authored attacks
## Cuts, thrusts and foes' blows are played from the bought whole-body clips (`ss_` sword and shield, `th_` two-handed,
## `dw_` dual) instead of the procedural sword arm. The state machine above still runs underneath and owns the timing
## (which is the rule simulation's): the clip is time-warped so that its own contact frame falls on the hit instant,
## its long wind-up is cut away, and a small roll of the sword arm makes the blade travel the way that was swiped.
## `--noauthored` (or `FighterRig.authored = false`) plays the old procedural arm, for comparison.
static var authored: bool = not OS.get_cmdline_user_args().has("--noauthored")
static var _au_meta := {}

const AU_STEP := 0.2          # metres the player's step into a cut has carried the body forward by the hit
const AU_STEP_FOE := 0.05
const AU_ROLL_MAX := 1.0     # radians the sword arm may be rolled to put a clip's cut on the swiped line
const AU_IN := 0.09           # seconds a player's cut takes to come in from the pose before it
const AU_IN_FOE := 0.2
const AU_OUT := 0.22

## clip, index into its `hits` (clip_meta.json), options: arm_l 0 keeps the shield arm on its own guard, roll false
## leaves the clip's own line. Swipe names are in the fighter's own frame (a foe facing the camera swaps left and right).
const AU_CUTS := {
	"ss": {
		"R": ["ss_cut_r_high", 0], "L": ["ss_cut_l", 0], "D": ["ss_cut_d", 0], "DL": ["ss_cut_dl", 0], "DR": ["ss_cut_dr2", 0],
		"U": ["th_cut_u", 0, {"arm_l": 0.0}], "UL": ["th_cut_u", 0, {"arm_l": 0.0}], "UR": ["ss_cut_r_high", 0],
		"thrust": ["ss_thrust2", 0]},
	"th": {
		"R": ["th_cut_r2", 0], "L": ["th_cut_l", 0], "D": ["th_cut_d", 0], "DL": ["th_cut_l", 0], "DR": ["th_cut_dr", 0],
		"U": ["th_cut_u", 0], "UL": ["th_cut_u", 0], "UR": [["th_cut_u", 0], ["th_cut_r2", 0]], "thrust": ["th_combo_thrust", 2]},
	"dw": {
		"R": ["dw_cut_r", 0], "L": ["dw_double", 0], "D": ["dw_cut_dr", 0], "DL": ["dw_cut_dl", 0], "DR": ["dw_cross", 2],
		"U": ["th_cut_u", 0], "UL": ["th_cut_u", 0], "UR": ["dw_cut_r", 0], "thrust": ["dw_flurry", 0]},
}

static func clip_meta(n: String) -> Dictionary:
	if _au_meta.is_empty():
		var v = JSON.parse_string(FileAccess.get_file_as_string("res://assets/anim/clip_meta.json"))
		_au_meta = v.get("clips", {}) if v is Dictionary else {"_": {}}
	return _au_meta.get(n, {})

## Which of the packs' sets this fighter's weapon is swung with ("" none: claws stay procedural).
func au_set() -> String:
	var w := str(cfg.get("weapon", "sword"))
	if w == "claws":
		return ""
	return "th" if two_handed else ("dw" if dual else "ss")

var _au := {}                 # the authored attack in progress (empty: none)
var _au_t := 0.0              # seconds since it began
var _au_state := ""           # what the authored layer is showing: "", "cut"
var _xf_dir_r := Vector3.UP
var _xf_dir_l := Vector3.UP
var _last_dir_r := Vector3.UP
var _last_dir_l := Vector3.UP

func _au_label() -> String:
	var a := atan2(_arc_dir.y, _arc_dir.x)
	return ["R", "UR", "U", "UL", "L", "DL", "D", "DR"][posmod(int(round(a / (PI / 4.0))), 8)]

## The clip for a swipe: [clip, hit index, options] or [] to stay procedural.
func _au_pick(label: String, finish_kind: String) -> Array:
	var tbl: Dictionary = AU_CUTS.get(au_set(), {})
	var spec: Array = tbl.get(label, [])
	if mirror < 0.0 or combo_book.is_empty() or _au_hist.size() < 2:
		return spec
	# a known combo in progress: from its second cut on, each cut is the one written for that place in that combo
	var rows_for: Dictionary = AU_COMBOS.get(au_set(), {})
	var top := 0
	for c: Dictionary in combo_book:
		var rows: Array = rows_for.get(str(c.id), [])
		var seq: Array = c.seq
		for k in range(mini(seq.size(), _au_hist.size()), 1, -1):
			if _au_hist.slice(_au_hist.size() - k) == seq.slice(0, k):
				# the combo this cut completes (the duel names its kind) outranks a longer one merely begun
				var score := k + (100 if k == seq.size() and finish_kind != "" and str(c.kind) == finish_kind else 0)
				if score > top and k - 1 < rows.size() and rows[k - 1] != null:
					top = score
					spec = rows[k - 1]
				break
	return spec

func _xfade(dur: float) -> void:
	_xf_dir_r = _last_dir_r
	_xf_dir_l = _last_dir_l
	skin.crossfade(dur)

## `strike_from` and `hit_at`: seconds from now at which the blade starts into the blow and at which it lands.
func _au_begin(label: String, strike_from: float, hit_at: float, finish: String) -> void:
	_au_stop()
	if not authored or skin == null or not skin.ok or test_clip != "" or not use_clips:
		return
	var pick := _au_pick(label, finish)
	if pick.is_empty():
		return
	# (several clips may be offered for one swipe: the one whose blade ends nearest the swiped line is played)
	var best := {}
	for cand: Array in (pick if pick[0] is Array else [pick]):
		_au_build(cand, label, strike_from, hit_at)
		if not _au.is_empty() and (best.is_empty() or float(_au.err) < float(best.err) - 0.12):
			best = _au
	_au = best
	if _au.is_empty():
		return
	_au_t = 0.0
	_au_state = "cut"
	_xfade(minf(AU_IN, float(_au.hit) * 0.45) if strike_from <= 0.05 else minf(AU_IN_FOE, strike_from * 0.5))

func _au_build(spec: Array, label: String, strike_from: float, hit_at: float) -> void:
	_au = {}
	if not SkinDriver.has_clip(str(spec[0])):
		return
	var m := clip_meta(str(spec[0]))
	var hits: Array = m.get("hits", [])
	if int(spec[1]) >= hits.size():
		return
	var opt: Dictionary = spec[2] if spec.size() > 2 else {}
	var h: Dictionary = hits[int(spec[1])]
	var tc := float(h.contact)
	var ts := minf(float(h.start), tc - 0.1)
	if opt.has("start"):
		ts = float(opt.start)
	ts = maxf(ts, 0.0)
	var te := maxf(float(h.end), tc + 0.05)
	if not opt.has("contact"):
		tc = au_contact(str(spec[0]), ts, te)
	else:
		tc = float(opt.contact)
	ts = minf(ts, tc - 0.08)
	# what follows the cut: its own recovery, but never the next cut of a chain
	var t_out := float(m.get("length", te))
	if int(spec[1]) + 1 < hits.size():
		t_out = minf(t_out, float(hits[int(spec[1]) + 1].start) - 0.05)
	t_out = clampf(te + 0.5, te, maxf(t_out, te))
	var n := str(spec[0])
	# the packs are showy: what follows a cut is played only until the fighter would turn side-on to the opponent,
	# and a foe's warning pose reaches back into the clip's own wind-up only as far as the chest still faces forward
	var tq := tc
	while tq < t_out:
		tq += 0.033
		# (nor on to where the hand comes back beside the wielder's own neck with the blade over the shoulder)
		if absf(_au_yaw(n, tq)) > AU_YAW_MAX or (tq > tc + 0.1 and (skin.clip_hand(n, tq).p as Vector3).distance_to(Vector3(0, 1.58, 0.0)) < 0.36):
			t_out = maxf(tc + 0.03, tq - 0.033)
			break
	te = minf(te, t_out)
	# the wound-up pose: the moment before the cut at which the blade is furthest back along the line it will travel
	# (high for a falling cut, out to the left for a cut to the right). A foe holds it for the whole warning; the
	# player's cut starts just before it.
	var want := Vector3(0, 0, -1) if label == "thrust" else Vector3(_arc_dir.x, _arc_dir.y, 0)
	var apex := ts
	var least := 1e9
	tq = tc - 0.06
	while tq >= maxf(0.0, minf(ts, tc - 0.3) - 0.2):
		var hd: Dictionary = skin.clip_hand(n, tq)
		var c: Vector3 = hd.get("chest", Vector3(0, 0, -1))
		var sc: float = (hd.p + hd.axis * weapon_len * 0.8 - Vector3(0, 1.4, 0)).dot(want)
		if absf(atan2(c.x, -c.z)) < 1.75 and sc < least - 0.03:
			least = sc
			apex = tq
		tq -= 1.0 / 30.0
	var pre := apex
	if strike_from > 0.05:
		ts = apex
		while pre > maxf(0.0, apex - 0.3) and absf(_au_yaw(n, pre - 0.033)) < AU_YAW_MAX:
			pre -= 0.033
		pre = maxf(pre, 0.0)
	else:
		ts = clampf(apex - 0.1, minf(ts, apex), apex)
	_au = {"clip": n, "ts": ts, "tc": tc, "te": te, "t_out": t_out, "pre": pre,
		"from": strike_from, "hit": maxf(hit_at, strike_from + 0.02), "roll": 0.0, "freeze": -1.0, "arm_l": float(opt.get("arm_l", 1.0)),
		"reach": 1.0, "travel": 1.0 if float(m.get("hip_travel", 0.0)) < 0.8 else 0.0, "label": label, "linger": float(opt.get("linger", 0.0)), "err": 0.0}
	if label != "thrust" and opt.get("roll", true):
		# the line the blade tip travels across the hit, as it will be seen: over the last frames before the hit instant
		# (the trunk's own turn carries the blade too, so the roll is found in a few steps, not in one)
		var roll := 0.0
		for i in 5:
			var a0: Dictionary = skin.clip_hand(n, _au_time(float(_au.hit) - 0.07), "Right", roll)
			var a1: Dictionary = skin.clip_hand(n, _au_time(float(_au.hit) + 0.035), "Right", roll)
			var v: Vector3 = (a1.p + a1.axis * weapon_len) - (a0.p + a0.axis * weapon_len)
			var v2 := Vector2(v.x, v.y)
			if v2.length() < 0.04:
				break
			_au.err = absf(v2.angle_to(Vector2(_arc_dir.x, _arc_dir.y)))
			if i == 4:
				break
			roll = clampf(roll + v2.angle_to(Vector2(_arc_dir.x, _arc_dir.y)) * 0.85, -AU_ROLL_MAX, AU_ROLL_MAX)
		_au.roll = roll if absf(roll) >= 0.07 else 0.0
	var hc: Dictionary = skin.clip_hand(n, tc, "Right", float(_au.roll))
	_au.reach = -(hc.p.z + hc.axis.z * weapon_len * 0.8)

## Clip time for a moment of the attack. The warning window eases into the wound-up pose and holds there; the blow
## runs from there to the clip's contact frame, arriving at the hit instant; what follows plays at the clip's own pace.
func _au_time(tau: float) -> float:
	var from := float(_au.from)
	var hit := float(_au.hit)
	if tau < from:
		var u := clampf(tau / maxf(from, 0.001), 0.0, 1.0)
		return lerpf(float(_au.pre), float(_au.ts), 1.0 - pow(1.0 - u, 3.0))
	if tau < hit:
		var u2 := (tau - from) / (hit - from)
		return lerpf(float(_au.ts), float(_au.tc), pow(u2, 1.5))
	return minf(float(_au.tc) + (tau - hit) * 1.2, float(_au.t_out))

## The moment of a cut at which the blade is where the opponent stands: when the far part of the blade reaches
## furthest ahead of the fighter. (The bake's own `contact` is when the tip is fastest, which for a level cut on
## this rig is after the blade has already swept past the centre.)
static var _au_tc := {}
func au_contact(n: String, ts: float, te: float) -> float:
	var key := "%s|%.2f|%.2f|%.1f|%s" % [n, ts, te, weapon_len, str(cfg.get("skin", ""))]
	if _au_tc.has(key):
		return _au_tc[key]
	var best := ts
	var far := -1e9
	var t := ts
	while t <= te + 0.001:
		var hd: Dictionary = skin.clip_hand(n, t)
		var r: float = -(hd.p.z + hd.axis.z * weapon_len * 0.8)
		if r > far:
			far = r
			best = t
		t += 1.0 / 60.0
	_au_tc[key] = best
	return best

const AU_CLEAR := 0.04        # metres more a blade is kept from the wielder's own armour in authored poses, which bring it close
const AU_YAW_MAX := 1.3       # radians the chest may be turned from the opponent in what is played of a clip

func _au_yaw(n: String, t: float) -> float:
	var c: Vector3 = skin.clip_hand(n, t).get("chest", Vector3(0, 0, -1))
	return atan2(c.x, -c.z)

func _au_stop() -> void:
	if _au.is_empty():
		return
	_au = {}
	_au_state = ""
	_clip_w = 0.0
	if skin:
		_xfade(AU_OUT)

func _au_update(dt: float) -> void:
	if _au.is_empty():
		return
	if not (mode in [Mode.WINDUP, Mode.STRIKE, Mode.FOLLOW, Mode.THRUST_WINDUP, Mode.THRUST]):
		# a combo's last cut that met nothing is followed through to its own recovery before the guard comes back
		if mode != Mode.GUARD or blocking or float(_au.freeze) >= 0.0 or _au_t > float(_au.hit) + _swing * 0.5 + 0.3 + float(_au.linger) \
				or _au_time(_au_t) >= float(_au.t_out) - 0.001:
			_au_stop()
			return
	var prev := _au_t
	_au_t += dt
	if float(_au.freeze) >= 0.0 or dt <= 0.0 or not auto_bite or _pin_t > 0.0 or _au_t <= float(_au.from):
		return
	# the blade stops in the first body it meets, as the procedural cut does: the clip is walked in small steps
	var targets := _targets()
	if targets.is_empty():
		return
	var thrust: bool = str(_au.label) == "thrust"
	for i in range(1, 7):
		var tau := lerpf(maxf(prev, float(_au.from)), _au_t, i / 6.0)
		var ct := _au_time(tau)
		if ct > float(_au.te) + 0.1:
			break
		var hd: Dictionary = skin.clip_hand(str(_au.clip), ct, "Right", float(_au.roll), float(_au.travel))
		if _blade_in(hd.p, hd.axis, targets, 0.75 if thrust else 0.3, 0.35 if thrust else 0.3):
			_au.freeze = ct
			_go(Mode.FOLLOW, BITE_HOLD + 0.22 + float(_au.linger) * 0.4)      # a finishing blow stays in a moment longer
			break

func _au_apply() -> void:
	skin.arm_r = 1.0
	skin.arm_l = 1.0
	skin.clip_look = false
	skin.clip_roll = 0.0
	if _au.is_empty():
		_au_other()
		return
	skin.clip = str(_au.clip)
	skin.clip_t = float(_au.freeze) if float(_au.freeze) >= 0.0 else _au_time(_au_t)
	skin.clip_full = true
	skin.clip_w = 1.0
	skin.clip_travel = float(_au.travel)
	skin.clip_look = true
	skin.clip_roll = float(_au.roll)
	skin.arm_r = 0.0 if _pin_t > 0.0 else 1.0
	skin.arm_l = 0.0 if _brace_t > 0.0 else float(_au.arm_l)


# ---------------------------------------------------------------- authored parry, block, draw and sheath
## Parry and block take the body (and the shield arm) from the packs' clips; the arm that makes the contact stays on
## its pin, so the blade still meets the foe's blade at the world point the duel gives (`clash`) and the shield still
## goes to the blow (`brace`). Dual blades have no such clips and stay procedural.
const AU_PARRY := {"ss": "ss_parry", "th": "th_parry"}
const AU_BLOCK := {"ss": "ss_block_idle", "th": "th_guard"}
const AU_BLOCK_HIT := {"ss": "ss_block_hit", "th": "th_block_hit_f"}
const AU_DRAW_TIME := 0.8     # seconds a draw or a sheathing takes
var _au_brace := 9.0          # seconds since the shield last took a blow
var _au_clock := 0.0          # time in the present authored state

func _au_tick(dt: float) -> void:
	_au_brace += dt
	_au_clock += dt
	if _draw_dir != 0:
		_draw_t += dt
		if _draw_t >= AU_DRAW_TIME:
			_sheath_w = 1.0 if _draw_dir < 0 else 0.0
			_draw_dir = 0
	if _preview_block > 0.0:
		_preview_block -= dt
		if _preview_block <= 0.0:
			blocking = false

func _au_other() -> void:
	var st := ""
	var n := ""
	var t := 0.0
	var k := au_set()
	if authored and use_clips and test_clip == "" and skin.ok and mode != Mode.DEAD:
		if _draw_dir != 0 and mode == Mode.GUARD:
			st = "draw"
			n = "ss_unsheath" if _draw_dir > 0 else "ss_sheath"
			t = _draw_t / AU_DRAW_TIME * SkinDriver.clip_length(n)
		elif _parry_t > 0.0 and mode in [Mode.STRIKE, Mode.GUARD] and AU_PARRY.has(k):
			st = "parry"
			n = AU_PARRY[k]
			t = (0.5 - _parry_t) * (1.6 if k == "ss" else 0.66)
		elif blocking and mode == Mode.GUARD and AU_BLOCK.has(k) and (has_shield or two_handed):
			if _au_brace < 0.5:
				st = "bhit"
				n = AU_BLOCK_HIT[k]
				t = _au_brace
			else:
				st = "block"
				n = AU_BLOCK[k]
				t = _clock
	if st != "" and not SkinDriver.has_clip(n):
		st = ""
	if st != _au_state:
		# a pinned arm is not eased: the contact pose is taken on the frame the duel asks for it
		_xfade(0.1 if st != "" else AU_OUT)
		_au_state = st
		_au_clock = 0.0
		_clip_w = 0.0
	if st == "":
		return
	skin.clip = n
	skin.clip_t = t
	skin.clip_full = true
	skin.clip_w = 1.0
	skin.clip_travel = 0.0
	skin.clip_look = true
	match st:
		"parry":
			skin.arm_r = 0.0
		"bhit":
			skin.arm_l = 0.0 if _brace_t > 0.0 else 1.0
			skin.arm_r = 0.0 if _pin_t > 0.0 else 1.0
		"block":
			skin.arm_r = 0.0 if _pin_t > 0.0 else 1.0

# --- draw / sheath
var _sheath_w := 0.0          # 1: the weapon hangs in its place on the body; 0: in the hand
var _draw_dir := 0            # +1 drawing, -1 sheathing, 0 neither
var _draw_t := 0.0
var _preview_block := 0.0
const DRAW_GRAB := 0.42       # share of the time at which the hand closes on the grip (draw) or lets it go (sheath)
const DRAW_FREE := 0.72       # share at which the blade has come round to the hand's own aim

func is_sheathed() -> bool:
	return _sheath_w >= 1.0 and _draw_dir == 0

## Put the weapon away: at the left hip for one-handed swords, across the back for long blades. The hand carries it
## there and only then lets go. Returns the seconds it takes. `instant` for setting a scene.
func sheath(instant: bool = false) -> float:
	if _recalls() and not instant and _sheath_w < 1.0 and _dismiss_t <= 0.0 and is_inside_tree():
		# a Recall weapon is not carried: it is taken apart in the hand
		_present_stop()
		for n: Node3D in _held_nodes(false):
			_dismiss_t = maxf(_dismiss_t, Recall.dismiss(n, {"short": true}).length())
		return _dismiss_t
	if skin == null or not skin.ok or instant or not authored:
		_sheath_w = 1.0
		_draw_dir = 0
		return 0.0
	if _sheath_w >= 1.0 or _draw_dir < 0:
		return 0.0
	_draw_dir = -1
	_draw_t = 0.0
	return AU_DRAW_TIME

## Take the weapon in hand: the hand goes to the grip first; the weapon does not move until the hand is on it.
func draw(instant: bool = false) -> float:
	if _recalls() and not instant and (_sheath_w > 0.0 or _dismiss_t > 0.0) and is_inside_tree():
		return present_weapon("recall_short")
	if _dismiss_t > 0.0 or not weapon_r.visible:
		_dismiss_t = 0.0
		for n: Node3D in _held_nodes(false):
			Recall.cancel(n)
			n.visible = true
	if skin == null or not skin.ok or instant or not authored:
		_sheath_w = 0.0
		_draw_dir = 0
		return 0.0
	if _sheath_w <= 0.0 or _draw_dir > 0:
		return 0.0
	_draw_dir = 1
	_draw_t = 0.0
	return AU_DRAW_TIME

# --- presenting the weapon: Recall for the advanced pieces, a draw from the hip or back for the rest
var _present := ""            # "recall" while a weapon or shield is materialising in the hand
var _present_t := 0.0
var _present_dur := 0.0
var _present_shield := false
var _dismiss_t := 0.0         # seconds left of a Recall weapon being taken apart in the hand
static var _presented := {}   # opts.key -> true once shown in this session (a foe met again gets the short form)
const PRESENT_OPEN := 0.3     # share of a Recall during which the receiving hand is open; it closes as the hilt forms
const PRESENT_CLOSE := 0.48

func _recalls() -> bool:
	return bool(cfg.get("advanced", false)) and not old_look

func _held_nodes(with_shield: bool) -> Array:
	var out: Array = [weapon_r]
	if dual:
		out.append(weapon_l)
	if with_shield and shield:
		out.append(shield)
	return out

## 0..1: how far the receiving hand is open at this moment of a Recall.
func _present_open() -> float:
	if _present != "recall" or _present_dur <= 0.0 or bool(Game.settings.get("reduce_motion", false)):
		return 0.0
	return 1.0 - smoothstep(PRESENT_OPEN, PRESENT_CLOSE, _present_t / _present_dur)

func _present_stop() -> void:
	if _present == "recall":
		for n: Node3D in _held_nodes(true):
			Recall.cancel(n)
			_awaken(n)
	_present = ""

func _awaken(n: Node3D) -> void:
	if _recalls() and n != shield:
		for c in n.get_children():
			if c is Node3D and not (c is Recall):
				GearModel.awaken(c, true)

## Brings the weapon to the hand the right way for what it is and returns the seconds it takes (never blocks: a cut
## thrown meanwhile simply finishes it).
##   "auto"          Recall for an advanced weapon, a draw for an ordinary one. opts.key (a foe id): the full Recall the
##                   first time that key is seen in a session, the short one after. opts.quick (no intro to fit in):
##                   the short Recall, and nothing at all for an ordinary weapon, which is simply in the hand.
##   "recall" / "recall_short"   the piece is rebuilt in the open hand, hilt first; the hand closes as the hilt forms
##   "draw"          from the hip or the back (FighterRig.draw)        "none"   in the hand at once
## opts.slot "shield": present the shield instead (the Armory). An advanced shield is summoned along with the weapon.
## Recall itself takes its shorter, plainer form on the Performance preset and with reduce_motion (Recall.reduced).
func present_weapon(style: String = "auto", opts: Dictionary = {}) -> float:
	_present_stop()
	var only_shield := str(opts.get("slot", "weapon")) == "shield"
	var sh_adv: bool = shield != null and cfg.get("shield") is Dictionary and bool(cfg.shield.get("advanced", false)) and not old_look
	if style == "auto":
		var key := str(opts.get("key", ""))
		var seen := key != "" and _presented.has(key)
		if key != "":
			_presented[key] = true
		var quick := bool(opts.get("quick", false))
		if _recalls() or (only_shield and sh_adv):
			style = "recall_short" if (seen or quick) else "recall"
		elif sh_adv:
			style = "draw_recall_shield" if not quick else "recall_shield"
		else:
			style = "none" if quick else "draw"
	if not is_inside_tree() or skin == null or not skin.ok:
		style = "none"
	_dismiss_t = 0.0
	var nodes: Array = []
	var dur := 0.0
	match style:
		"draw", "draw_recall_shield":
			for n: Node3D in _held_nodes(false):
				Recall.cancel(n)
				n.visible = true
			_sheath_w = 1.0
			_draw_dir = 0
			dur = draw()
			if style == "draw_recall_shield":
				nodes = [shield]
		"recall_shield":
			draw(true)
			nodes = [shield]
		"recall", "recall_short":
			draw(true)
			nodes = [shield] if only_shield else _held_nodes(sh_adv)
		_:
			draw(true)
			return 0.0
	for n: Node3D in nodes:
		if n == null:
			continue
		var r := Recall.summon(n, {"short": style != "recall"})
		_present = "recall"
		_present_t = 0.0
		_present_dur = maxf(_present_dur if n != nodes[0] else 0.0, r.length())
		_present_shield = nodes.has(shield)
	return maxf(dur, _present_dur if _present == "recall" else 0.0)

func _present_tick(dt: float) -> void:
	if _present == "recall":
		_present_t += dt
		if _present_t >= _present_dur + 0.05:
			for n: Node3D in _held_nodes(true):
				_awaken(n)
			_present = ""
	if _dismiss_t > 0.0:
		_dismiss_t -= dt
		if _dismiss_t <= 0.0:
			_sheath_w = 1.0
			_draw_dir = 0

## One cut for a screen that shows the fighter off (the Armory): `dir` a swipe name. Returns the seconds until the
## fighter is back in guard.
func preview_attack(dir: String = "R", time: float = 0.5) -> float:
	var lead := 0.0
	if _sheath_w > 0.0:
		draw(true)
	var v: Vector2 = {"R": Vector2(1, 0), "L": Vector2(-1, 0), "U": Vector2(0, 1), "D": Vector2(0, -1), "UR": Vector2(0.7, 0.7),
		"UL": Vector2(-0.7, 0.7), "DR": Vector2(0.7, -0.7), "DL": Vector2(-0.7, -0.7)}.get(dir, Vector2(1, 0))
	swing(v, time)
	return lead + time * 0.85 + 0.3 + AU_OUT

## Raise the guard for `hold` seconds, then lower it. Returns the seconds until the fighter is back in guard.
func preview_block(hold: float = 1.0) -> float:
	if _sheath_w > 0.0:
		draw(true)
	guard()
	blocking = true
	_preview_block = hold
	return hold + AU_OUT

## Where the weapon in the given hand hangs when it is put away, in rig body space: [grip point, the way the blade points].
func _holster(side: String) -> Array:
	if two_handed:
		var ct: Basis = skin.turn("Spine2")
		return [skin.point("Spine2") + ct * Vector3(0.2, 0.3, 0.17 + skin.extent("Spine2", Vector3(0, 0, 1)) * 0.5), (ct * Vector3(-0.42, -0.9, 0.08)).normalized()]
	var ht: Basis = skin.turn("Hips")
	var sx := -1.0 if side == "Right" else 1.0      # the right hand's sword hangs at the left hip
	var bone_n := "LeftUpLeg" if side == "Right" else "RightUpLeg"
	var out: float = maxf(skin.extent("Hips", Vector3(sx, 0, 0)), skin.extent(bone_n, Vector3(sx, 0, 0)) + absf((skin.point(bone_n) - skin.point("Hips")).dot(ht.x))) + 0.04
	return [skin.point("Hips") + ht * Vector3(sx * out, 0.04, -0.06), (ht * Vector3(sx * 0.1, -0.86, 0.5)).normalized()]

func _fit_sheath() -> void:
	if _sheath_w <= 0.0 and _draw_dir == 0:
		return
	var u := clampf(_draw_t / AU_DRAW_TIME, 0.0, 1.0) if _draw_dir != 0 else 0.0
	if _draw_dir < 0:
		u = 1.0 - u      # sheathing is the draw run backward
	# u: 0 the weapon hangs and the hand is away; DRAW_GRAB the hand is on the grip; DRAW_FREE the weapon is carried freely
	var on_grip := 0.0
	if _draw_dir != 0:
		on_grip = smoothstep(0.05, DRAW_GRAB, u) if u < DRAW_GRAB else 1.0 - smoothstep(DRAW_GRAB, DRAW_FREE, u)
	var freed := smoothstep(DRAW_GRAB, DRAW_FREE, u)
	for side: String in (["Right", "Left"] if dual else ["Right"]):
		var w: Node3D = weapon_r if side == "Right" else weapon_l
		var hs := _holster(side)
		var hpos: Vector3 = hs[0]
		var hdir := _off_floor(hpos, hs[1], weapon_len, _pommel)
		var in_hand := w.transform
		if on_grip > 0.0:
			# the hand goes to where the weapon is (or carries it back there); the weapon is not fetched to the hand
			var palm: Vector3 = skin.reach_hand(side, in_hand.origin.lerp(hpos, on_grip))
			in_hand.origin = palm
		var d := hdir.slerp(in_hand.basis.y.normalized(), freed) if hdir.dot(in_hand.basis.y) > -0.99 else hdir
		var pos := hpos.lerp(in_hand.origin, smoothstep(DRAW_GRAB, DRAW_GRAB + 0.06, u))
		if u >= DRAW_GRAB and u < 1.0:
			skin.grip(side, d)
		w.transform = Transform3D(_basis_y(d, Vector3(0, 0, -1) if absf(d.z) < 0.9 else Vector3.RIGHT), pos)
		if two_handed:
			weapon_l.position = pos

# ---------------------------------------------------------------- combos
var combo_book: Array = []    # the combos this fighter knows (`DuelSim.combos`: {id, seq, kind}); set by the duel
var _au_hist: Array = []      # swipes of the cuts thrown lately, oldest first
var _au_hist_t := -9.0

## Each combo's own choreography: per weapon set, per combo, the cut to throw at each place in its sequence
## (null: the ordinary cut for that swipe; the first cut is always the ordinary one, since nothing is yet known).
## `linger`: seconds the last cut is followed through (or held in the body) beyond an ordinary cut.
const AU_COMBOS := {
	"ss": {
		"double_slash": [null, ["ss_c8_2", 0, {"linger": 0.2}]],
		"riposte": [null, ["ss_fin_double", 0, {"linger": 0.35}]],
		"rising_fang": [null, null, ["ss_c4_2", 0, {"linger": 0.2}]],
		"armor_splitter": [null, null, ["ss_fin_cleave", 0, {"linger": 0.45}]],
		"crossbreaker": [null, null, ["ss_c8_3", 0, {"linger": 0.3}]],
		"mirror_step": [null, null, ["ss_c8_2", 0, {"linger": 0.2}]],
		"falling_crown": [null, ["ss_c4_1", 0], ["th_cut_d2", 0, {"arm_l": 0.0, "linger": 0.5}]],
		"reversal": [null, null, ["ss_cut_r2", 0], ["th_cut_u", 0, {"arm_l": 0.0, "linger": 0.35}]],
		"serpents_path": [null, null, null, ["ss_c7_3", 0, {"linger": 0.4}]],
		"eternal_edge": [null, ["ss_c8_2", 0], null, null, ["th_cut_d", 0, {"arm_l": 0.0, "linger": 0.55}]],
		"headsmans_due": [null, ["th_cut_d2", 0, {"arm_l": 0.0, "linger": 0.5}]],
		"timberfall": [null, ["ss_c8_2", 0], ["ss_fin_cleave", 0, {"linger": 0.5}]]},
	"th": {
		"double_slash": [null, ["th_cut_l", 1, {"linger": 0.2}]],
		"riposte": [null, ["th_cut_l", 1, {"linger": 0.3}]],
		"rising_fang": [null, null, ["th_cut_l", 1, {"linger": 0.2}]],
		"armor_splitter": [null, null, ["th_cut_d2", 0, {"linger": 0.45}]],
		"crossbreaker": [null, null, ["th_cut_dl2", 0, {"linger": 0.3}]],
		"mirror_step": [null, null, ["th_spin", 2, {"linger": 0.2}]],
		"falling_crown": [null, null, ["th_cut_d2", 0, {"linger": 0.5}]],
		"reversal": [null, null, ["th_cut_l", 1], ["th_cut_u", 0, {"linger": 0.35}]],
		"serpents_path": [null, null, null, ["th_overhead", 0, {"linger": 0.4}]],
		"eternal_edge": [null, null, null, null, ["th_cut_d2", 0, {"linger": 0.55}]],
		"colossus": [null, ["th_cut_d2", 0, {"linger": 0.5}]],
		"tidebreaker": [null, ["th_cut_l", 1], ["th_cut_d2", 0], ["th_cut_u", 0, {"linger": 0.45}]]},
	"dw": {
		"double_slash": [null, ["dw_a2", 1, {"linger": 0.2}]],
		"rising_fang": [null, null, ["dw_a2", 1, {"linger": 0.2}]],
		"armor_splitter": [null, null, ["dw_lunge", 0, {"linger": 0.4}]],
		"crossbreaker": [null, null, ["dw_x", 0, {"linger": 0.3}]],
		"mirror_step": [null, null, ["dw_x", 2, {"linger": 0.2}]],
		"falling_crown": [null, null, ["dw_lunge", 0, {"linger": 0.45}]],
		"reversal": [null, null, ["dw_a2", 1], null],
		"serpents_path": [null, null, null, ["dw_lunge", 0, {"linger": 0.4}]],
		"eternal_edge": [null, null, null, null, ["dw_lunge", 0, {"linger": 0.5}]],
		"twin_fang": [null, ["dw_a2", 1], ["dw_cut_l", 0], ["dw_cut_r", 0, {"linger": 0.3}]],
		"whirlwind": [null, ["dw_x", 2], null, ["dw_x", 0, {"linger": 0.35}]]},
}
