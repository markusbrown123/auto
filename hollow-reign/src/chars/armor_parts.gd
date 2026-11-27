class_name ArmorParts
extends RefCounted
## Real equipment on one shared body: a knight dressed from separately swappable armour parts, each cut from one of
## the full-body suits and re-fitted offline to the base knight's skeleton by tools/armor_split.gd.
## See docs/MODULAR_ARMOR.md for what the existing suits can and cannot do.
##
##   var parts := ArmorParts.dress(skin_driver.skel, "m", {"helm": "frost", "chest": "black", "shoulders": "black",
##       "arms": "regal", "legs": "ash", "boots": "vigil"})
##   parts.wear("helm", "garrison")        # a swap: one cached mesh assigned to one MeshInstance3D
##   parts.set_param(&"tint", Color(...))  # same shader parameters as Look.set_param (tint, flash, rim_color)
##
## The skeleton must be the base knight's of that body (assets/models/knight_m.glb / knight_f.glb): every part is
## stored in that skeleton's rest pose and bound with the one shared Skin, so no per-part retargeting happens here.
const DIR := "res://assets/models/parts/"
const SLOTS := ["helm", "chest", "shoulders", "arms", "legs", "boots"]
const SUITS := ["crownless", "base", "garrison", "ash", "black", "vigil", "frost", "regal", "wyrm", "hollow"]
## The suit every part is fitted to: its model is the body the rig drives (host_path), its own six parts are what an
## empty slot wears (there is no bare head, hand or foot), and the undersuit is its body drawn in.
## "crownless" = the sleek benchmark knights (knight_<body>_v3.glb). tools/armor_split.gd --host must agree.
static var host := "crownless"

## The model whose skeleton the parts are bound to: the skin a rig that wears parts must attach.
static func host_path(b: String) -> String:
	return "res://assets/models/knight_%s%s.glb" % [b, "_v3" if host == "crownless" else ""]
## Parts that only look right next to another part of the same suit (docs/MODULAR_ARMOR.md): suit -> {slot: [slots that
## must be the same suit]}. An equipment screen should show such a piece as "worn with ..." and not as a free piece.
##   vigil helm     is a hood whose mantle is the shoulders part: alone it ends in a torn hem in the air
##   garrison shoulders carry the top of the breastplate: on another chest that plate ends in a ragged edge
const LINKED := {
	"vigil": {"helm": ["shoulders"]},
	"garrison": {"shoulders": ["chest"]},
}
## Surface correction per suit for src/fx/armor_part.gdshader (docs/MODULAR_ARMOR.md, material study). The generated
## roughness maps sit in one narrow glossy band and paint the undersuit as glossy as the plate: roughness is spread
## and lifted, metal capped, near-black albedo turned into matt cloth. `tone` multiplies the colour.
const FINISH_DEFAULT := {"rough_min": 0.4, "rough_max": 1.0, "rough_pivot": 0.38, "rough_gain": 1.7, "rough_lift": 0.17, "metal_max": 0.72, "spec": 0.3,
	"cloth": 1.0, "cloth_dark": 0.045, "tone": Color(1, 1, 1),
	"coat": 0.0, "coat_color": Color(0.86, 0.84, 0.79), "coat_metal": 0.06, "coat_rough": 0.62, "wear": 0.0, "wear_edge": 1.0, "wear_color": Color(0.075, 0.07, 0.066),
	"motif": 0.0, "visor": 0.0, "edge_shine": 0.0}
## The benchmark suit's refinish (the owner, 2026-11-27: "paler grey, more detail like armor but still futuristic,
## stronger design of shapes circles, logos, cyan and maybe pink with girl, with a clean glow and effect").
## Material and a few light effects only; the meshes are as generated. Everything the owner may want nudged is here:
##   coat_color    the plate, a pale cool grey: paler (0.78, 0.80, 0.83), darker (0.56, 0.58, 0.62), warmer (0.72, 0.70, 0.66).
##                 It is lit hard in the Armory and in daylight: much above 0.8 burns out.
##   coat_rough    0.35 polished .. 0.6 matte;   coat_metal 0 ceramic .. 0.6 steel;   edge_shine 0 .. 0.4 lit edges
##   wear          0 none .. 1: how dark the suit's own creases and panel seams are drawn (its sculpted detail)
##   wear_edge     0 none .. 1: chipped edges, scuffs and mottling (off: the brief is clean)
##   motif         0 none .. 1: the inlaid designs;  motif_dark their metal;  motif_energy how bright their lines of light
##   visor         brightness of the lit eye slot (0 off)
##   GLOW          every light on the suit, one colour per body: visor, lines, hip seam, vents, cast light
##   FX_*          the live effects (cast light, vents)
## `--chrome` (or ArmorParts.chrome = true before a knight is dressed) puts the generated chrome back, all of it.
const FINISH_COAT := {"coat": 1.0, "coat_color": Color(0.70, 0.72, 0.755), "coat_metal": 0.2, "coat_rough": 0.44, "edge_shine": 0.2,
	"wear": 0.85, "wear_edge": 0.0, "wear_color": Color(0.085, 0.085, 0.09), "spec": 0.5,
	"motif": 1.0, "motif_dark": Color(0.13, 0.13, 0.14), "motif_energy": 2.2, "visor": 4.5}
const GLOW := {"m": Color(0.25, 0.9, 1.0), "f": Color(1.0, 0.3, 0.72)}
const FX_LIGHT := 0.06         # energy of the two small lights the visor and the breast cast (0 off)
const FX_LIGHT_RANGE := 0.9    # metres
const FX_VENT := 0.3           # how much of the vents' full flow is idle wisp (0 none); a dodge or roll opens them fully for a moment
const FX_VENT_ALPHA := 0.13    # how visible the vapour is
## Where the designs sit on each body (heights as a share of the body's height; printed by tools/armor_split.gd --v).
const BODY_MARKS := {
	"m": {"chest_y": 0.745, "back_span": Vector2(0.665, 0.825), "visor_y": 0.931, "visor_half": 0.011},
	"f": {"chest_y": 0.798, "back_span": Vector2(0.735, 0.845), "visor_y": 0.935, "visor_half": 0.013},
}
static var chrome: bool = OS.get_cmdline_user_args().has("--chrome")
const FINISH := {
	# third pass ("too spiky, excessively shiny... generic"): every older family sits a step rougher and a step less
	# mirror-like than the study left it; the benchmark knights ("crownless") keep the default
	"base": {"rough_lift": 0.21, "metal_max": 0.68},
	"black": {"rough_pivot": 0.31, "rough_lift": 0.24, "metal_max": 0.46, "cloth_dark": 0.02},      # lacquer: satin, not wet
	"garrison": {"rough_pivot": 0.34, "rough_lift": 0.23, "metal_max": 0.68},
	"frost": {"rough_pivot": 0.34, "rough_lift": 0.23, "metal_max": 0.64, "cloth": 0.0, "tone": Color(0.86, 0.88, 0.92)},
	"hollow": {"rough_pivot": 0.37, "rough_lift": 0.23, "metal_max": 0.56},
	"vigil": {"rough_pivot": 0.5, "rough_lift": 0.14, "rough_gain": 1.2, "metal_max": 0.62},
	"wyrm": {"rough_pivot": 0.5, "rough_lift": 0.13, "rough_gain": 1.2, "metal_max": 0.6},
	"regal": {"rough_pivot": 0.44, "rough_lift": 0.18, "metal_max": 0.62},
	"ash": {"rough_pivot": 0.42, "rough_lift": 0.18, "metal_max": 0.64},
}
## What the game uses today on whole-suit models (Look.SURFACE.character through pbr_clamp): for before/after captures.
const FINISH_OLD := {"rough_min": 0.33, "rough_max": 1.0, "rough_pivot": 0.38, "rough_gain": 1.0, "rough_lift": 0.0, "metal_max": 0.85, "spec": 0.35,
	"cloth": 0.0, "cloth_dark": 0.045, "tone": Color(1, 1, 1)}

static var dir := DIR                 # dev: another directory of parts (measurements use a set cut without overlap)
static var _mesh := {}                # "m_frost_helm" -> ArrayMesh or null
static var _mat := {}                 # "m_frost" -> ShaderMaterial (shared source; each knight gets its own copies)
static var _skin := {}                # body -> Skin
static var _under_shader: Shader

var skel: Skeleton3D
var body := "m"
var worn := {}                        # slot -> suit id
var nodes := {}                       # slot -> MeshInstance3D
var under: MeshInstance3D             # dark undersuit: the base body from the neck down, drawn slightly shrunk
var flex: MeshInstance3D              # flex-armour over the host suit's bare hips, shown while the host's legs are worn
var _flex_mat: ShaderMaterial
var _mats := {}                       # suit id -> this knight's own ShaderMaterial
var _params := {}                     # shader parameters set on every part (tint, flash, rim_color)
var _hidden: Array = []               # the skeleton's own meshes, hidden while parts are worn

# ---------------------------------------------------------------- data
static func has_part(b: String, suit: String, slot: String) -> bool:
	return ResourceLoader.exists("%s%s_%s_%s.res" % [dir, b, suit, slot])

## The slots that must hold the same suit for `slot` of `suit` to look right; empty for a freely mixable piece.
static func needs(suit: String, slot: String) -> Array:
	return LINKED.get(suit.get_slice("_", 0), {}).get(slot, [])

## What a linked piece does when its companion slot holds another suit: "bring" puts the companion on as well (the
## Vigil hood comes with its mantle), "yield" gives way to the companion's suit (Garrison pauldrons carry the top of
## the Garrison breastplate, so on another cuirass that cuirass's own pauldrons are worn).
const LINK_POLICY := {"vigil": "bring", "garrison": "yield"}

## A loadout as it can really be worn: empty slots take the base body's own piece (there is no bare head, hand or
## foot), a piece whose mesh does not exist falls back to it, and linked pieces are settled by LINK_POLICY.
static func resolve(loadout: Dictionary) -> Dictionary:
	var b := str(loadout.get("body", "m"))
	var out := {}
	for slot: String in SLOTS:
		var suit := str(loadout.get(slot, ""))
		out[slot] = suit if suit != "" and has_part(b, suit, slot) else host
	for slot: String in SLOTS:
		var suit: String = out[slot]
		for other: String in needs(suit, slot):
			if out[other] == suit:
				continue
			if str(LINK_POLICY.get(suit.get_slice("_", 0), "bring")) == "bring" and has_part(b, suit, other):
				out[other] = suit
			else:
				out[slot] = out[other] if has_part(b, out[other], slot) else host
	return out

## True when every worn piece has the companions it needs.
func is_clean() -> bool:
	for slot: String in worn:
		for other: String in needs(str(worn[slot]), slot):
			if worn.get(other, "") != worn[slot]:
				return false
	return true

static func mesh_of(b: String, suit: String, slot: String) -> ArrayMesh:
	var key := "%s_%s_%s" % [b, suit, slot]
	if not _mesh.has(key):
		var path := "%s%s.res" % [dir, key]
		_mesh[key] = load(path) if ResourceLoader.exists(path) else null
	return _mesh[key]

static func skin_of(b: String) -> Skin:
	if not _skin.has(b):
		_skin[b] = load("%s%s_skin.res" % [dir, b])
	return _skin[b]

static func finish_of(suit: String) -> Dictionary:
	var f: Dictionary = FINISH_DEFAULT.duplicate()
	f.merge(FINISH.get(suit.get_slice("_", 0), {}), true)
	if suit.get_slice("_", 0) == "crownless" and not chrome:
		f.merge(FINISH_COAT, true)
	return f

static func _material(b: String, suit: String) -> ShaderMaterial:
	var key := "%s_%s" % [b, suit.get_slice("_", 0)]      # (a suffix names a variant of the same suit's meshes)
	if not _mat.has(key):
		var path := "%s%s_mat.res" % [dir, key]
		_mat[key] = load(path) if ResourceLoader.exists(path) else null
	return _mat[key]

## Drops every cached mesh and material (call when leaving the armoury if memory matters).
static func flush() -> void:
	_mesh.clear()
	_mat.clear()
	_skin.clear()

# ---------------------------------------------------------------- dressing
## Dresses a base-knight skeleton. `loadout` maps slot -> suit id; a missing or empty slot is left bare (undersuit).
## opts: under (bool, default true) show the undersuit; finish (bool, default true) use the corrected surface ranges.
static func dress(skeleton: Skeleton3D, b: String, loadout: Dictionary, opts: Dictionary = {}) -> ArmorParts:
	var p := ArmorParts.new()
	p.skel = skeleton
	p.body = b
	p._finish = bool(opts.get("finish", true))
	for mi: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", true, false):
		if mi.visible:
			mi.visible = false
			p._hidden.append(mi)
	if bool(opts.get("under", true)):
		p._build_under()
	p.wear_all(loadout)
	return p

var _finish := true

func wear_all(loadout: Dictionary) -> void:
	for slot: String in SLOTS:
		wear(slot, str(loadout.get(slot, "")))

## Puts one part on (or takes it off with suit ""). Returns false when that part does not exist.
func wear(slot: String, suit: String) -> bool:
	if worn.get(slot, "") == suit and (suit == "" or nodes.has(slot)):
		return true
	var mesh: ArrayMesh = mesh_of(body, suit, slot) if suit != "" else null
	if mesh == null:
		if nodes.has(slot):
			(nodes[slot] as MeshInstance3D).visible = false
		if slot == "legs":
			_show_flex(false)
		worn[slot] = ""
		return suit == ""
	var mi: MeshInstance3D = nodes.get(slot)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "part_" + slot
		mi.skin = skin_of(body)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		skel.add_child(mi)
		mi.skeleton = mi.get_path_to(skel)
		nodes[slot] = mi
	mi.mesh = mesh
	mi.visible = true
	mi.set_surface_override_material(0, _own_material(suit))
	worn[slot] = suit
	if slot == "legs":
		_show_flex(suit == host)
	if slot == "chest" or slot == "helm":
		_show_fx()
	return true

# ---------------------------------------------------------------- live effects on the refinished suit
## Light and air, kept small: two unshadowed lights (the visor's and the breast's, in the body's glow colour) and three
## vents (behind each shoulder and at the nape) that leak a thin wisp of vapour and open for a moment on vent()
## (FighterRig calls it on a dodge or a roll). Eight small particles a vent at most. No vents with reduced motion; neither
## vents nor lights on the Performance preset. Only while the benchmark suit's breastplate is worn, and never with --chrome.
var _fx: Array = []                 # every effect node
var _vents: Array = []              # GPUParticles3D
var _vent_gen := 0

static func _setting(key: String, fallback: Variant) -> Variant:
	var loop := Engine.get_main_loop()
	var game: Node = (loop as SceneTree).root.get_node_or_null("Game") if loop is SceneTree else null
	if game == null:
		return fallback
	var st = game.get("settings")
	return st.get(key, fallback) if st is Dictionary else fallback

func _bone(short: String) -> int:
	for i: int in skel.get_bone_count():
		var n := skel.get_bone_name(i)
		if n == short or n.ends_with(":" + short) or n.ends_with("_" + short) or n == "mixamorig" + short:
			return i
	return -1

## A node riding on a bone, placed at `at` in the skeleton's own rest space (the body 1 tall, facing +X).
func _on_bone(short: String, at: Vector3, node: Node3D) -> bool:
	var bi := _bone(short)
	if bi < 0:
		return false
	var ba := BoneAttachment3D.new()
	ba.bone_idx = bi
	skel.add_child(ba)
	ba.add_child(node)
	node.transform = skel.get_bone_global_rest(bi).affine_inverse() * Transform3D(Basis.IDENTITY, at)
	_fx.append(ba)
	return true

func _show_fx() -> void:
	var on: bool = not chrome and _finish and worn.get("chest", "") == host
	if on and _fx.is_empty():
		_build_fx()
	for n: Node3D in _fx:
		n.visible = on

func _build_fx() -> void:
	var quality := int(_setting("quality", 1))
	if quality <= 0:
		return
	var glow: Color = GLOW.get(body, GLOW.m)
	var marks: Dictionary = BODY_MARKS.get(body, BODY_MARKS.m)
	if FX_LIGHT > 0.0:
		for spot: Array in [["Head", Vector3(0.11, float(marks.visor_y), 0.0)], ["Spine2", Vector3(0.14, float(marks.chest_y), 0.0)]]:
			var l := OmniLight3D.new()
			l.light_color = glow
			l.light_energy = FX_LIGHT
			l.omni_range = FX_LIGHT_RANGE
			l.shadow_enabled = false
			if not _on_bone(str(spot[0]), spot[1], l):
				l.free()
	if FX_VENT <= 0.0 or bool(_setting("reduce_motion", false)):
		return
	var span: Vector2 = marks.back_span
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(-1.0, 0.9, 0.0)          # back and up, in the body's own space
	mat.spread = 16.0
	mat.initial_velocity_min = 0.16
	mat.initial_velocity_max = 0.3
	mat.gravity = Vector3(0, 0.22, 0)
	mat.damping_min = 0.25
	mat.damping_max = 0.5
	mat.scale_min = 0.6
	mat.scale_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.35))
	grow.add_point(Vector2(1, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	mat.scale_curve = grow_tex
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.add_point(0.18, Color(1, 1, 1, 1.0))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	mat.color_ramp = fade_tex
	var puff := Gradient.new()
	puff.set_color(0, Color(1, 1, 1, 1))
	puff.set_color(1, Color(1, 1, 1, 0))
	var puff_tex := GradientTexture2D.new()
	puff_tex.gradient = puff
	puff_tex.fill = GradientTexture2D.FILL_RADIAL
	puff_tex.fill_from = Vector2(0.5, 0.5)
	puff_tex.fill_to = Vector2(1.0, 0.5)
	puff_tex.width = 32
	puff_tex.height = 32
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw.vertex_color_use_as_albedo = true
	draw.albedo_texture = puff_tex
	draw.albedo_color = Color(glow.lerp(Color(1, 1, 1), 0.55), FX_VENT_ALPHA)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.085, 0.085)
	quad.material = draw
	for at: Vector3 in [Vector3(-0.07, span.y - 0.005, 0.075), Vector3(-0.07, span.y - 0.005, -0.075), Vector3(-0.06, span.y + 0.035, 0.0)]:
		var g := GPUParticles3D.new()
		g.amount = 8
		g.lifetime = 1.1
		g.randomness = 0.6
		g.local_coords = false
		g.process_material = mat
		g.draw_pass_1 = quad
		g.amount_ratio = FX_VENT
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
		if _on_bone("Spine2", at, g):
			_vents.append(g)
		else:
			g.free()

## The vents open fully for a moment (a dodge, a roll), then settle back to their idle wisp.
func vent(seconds: float = 0.9) -> void:
	if _vents.is_empty() or not is_instance_valid(skel) or not skel.is_inside_tree():
		return
	_vent_gen += 1
	var gen := _vent_gen
	for g: GPUParticles3D in _vents:
		g.amount_ratio = 1.0
	skel.get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if gen == _vent_gen:
			for g2: GPUParticles3D in _vents:
				if is_instance_valid(g2):
					g2.amount_ratio = FX_VENT)

# ---------------------------------------------------------------- flex armour over the host suit's hips
## The benchmark suit leaves the pelvis as bare black undersuit. Where its legs are worn, a copy of exactly that region
## of the body (cut and lifted 2 mm by tools/armor_split.gd, same skin weights, so the silhouette is the body's) is
## drawn as dark segmented flex-armour: graphite lames that follow the body, a slight sheen, fine grooves between
## them, and one thin seam of cold light along the belt line. No plate, no skirt, nothing that stands off.
const FLEX_CODE := "shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform vec3 base : source_color = vec3(0.115, 0.12, 0.135);      // dark steel: a step under the plate, well above the bare undersuit
uniform vec3 seam : source_color = vec3(0.55, 0.8, 1.0);
uniform float seam_energy = 0.7;
uniform float pitch = 0.0125;        // height of one lame, in body heights
uniform vec3 flash : source_color = vec3(0.0);
uniform vec3 rim_color : source_color = vec3(0.0);
void fragment() {
	// lames run round the body and dip toward the front, like the lines of the plates round them
	float f = UV2.x;
	float b = UV2.y / pitch + 1.1 * f * f * sign(f) * 0.5 + 0.9 * f;
	float cell = fract(b);
	float w = fwidth(b) * 1.2 + 0.03;
	float groove = 1.0 - smoothstep(0.0, w, min(cell, 1.0 - cell));
	float lit = 1.0 - smoothstep(0.0, w * 0.45, abs(b - 2.0));
	// each lame is a little lighter toward its upper edge
	float shade = mix(0.75, 1.25, cell);
	ALBEDO = base * shade * (1.0 - 0.8 * groove);
	ROUGHNESS = mix(0.52, 0.85, groove);
	METALLIC = 0.3 * (1.0 - groove);
	SPECULAR = 0.4;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 0.25;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = seam * seam_energy * lit + flash + rim_color * rim;
}"
static var _flex_shader: Shader

func _show_flex(on: bool) -> void:
	if not on:
		if flex != null:
			flex.visible = false
		return
	if flex == null:
		var path := "%s%s_%s_flex.res" % [dir, body, host]
		if not ResourceLoader.exists(path):
			return
		if _flex_shader == null:
			_flex_shader = Shader.new()
			_flex_shader.code = FLEX_CODE
		flex = MeshInstance3D.new()
		flex.name = "part_flex"
		flex.mesh = load(path)
		flex.skin = skin_of(body)
		flex.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		skel.add_child(flex)
		flex.skeleton = flex.get_path_to(skel)
		_flex_mat = ShaderMaterial.new()
		_flex_mat.shader = _flex_shader
		var src := _material(body, host)
		if src:
			_flex_mat.set_shader_parameter("normal_tex", src.get_shader_parameter("normal_tex"))
		for k: StringName in _params:
			if k != &"tint":
				_flex_mat.set_shader_parameter(k, _params[k])
		if not chrome:
			_flex_mat.set_shader_parameter("seam", GLOW.get(body, GLOW.m))
		flex.set_surface_override_material(0, _flex_mat)
	flex.visible = true

func _own_material(suit: String) -> ShaderMaterial:
	if _mats.has(suit):
		return _mats[suit]
	var src := _material(body, suit)
	var m: ShaderMaterial = src.duplicate() if src else ShaderMaterial.new()
	var f := finish_of(suit) if _finish else FINISH_OLD
	for k: String in f:
		m.set_shader_parameter("tint" if k == "tone" else k, f[k])
	var marks: Dictionary = BODY_MARKS.get(body, {})
	for k2: String in marks:
		m.set_shader_parameter(k2, marks[k2])
	m.set_shader_parameter("glow_color", GLOW.get(body, GLOW.m))
	m.set_shader_parameter("fx", 0.0 if _setting("reduce_motion", false) else 1.0)
	for k3: StringName in _params:
		if k3 != &"tint":
			m.set_shader_parameter(k3, _params[k3])
	_mats[suit] = m
	return m

## Same meaning as Look.set_param for a whole-suit model: tint, flash, rim_color on every worn part.
func set_param(param: StringName, value: Variant) -> void:
	_params[param] = value
	if _flex_mat != null and param != &"tint":
		_flex_mat.set_shader_parameter(param, value)
	for suit: String in _mats:
		var v: Variant = value
		if param == &"tint" and _finish:
			var tone: Color = finish_of(suit).tone
			v = Color(value.r * tone.r, value.g * tone.g, value.b * tone.b, value.a)
		(_mats[suit] as ShaderMaterial).set_shader_parameter(param, v)

## Takes every part off and shows the skeleton's own mesh again.
func remove() -> void:
	for slot: String in nodes:
		(nodes[slot] as MeshInstance3D).queue_free()
	nodes.clear()
	worn.clear()
	if flex:
		flex.queue_free()
		flex = null
	for n: Node3D in _fx:
		if is_instance_valid(n):
			n.queue_free()
	_fx.clear()
	_vents.clear()
	if under:
		under.queue_free()
		under = null
	for mi: MeshInstance3D in _hidden:
		if is_instance_valid(mi):
			mi.visible = true
	_hidden.clear()

## What this knight costs to draw: {tris, surfaces, materials}.
func cost() -> Dictionary:
	var tris := 0
	var surfaces := 0
	var list: Array = nodes.values()
	if under:
		list.append(under)
	for mi: MeshInstance3D in list:
		if mi.visible and mi.mesh:
			surfaces += 1
			tris += (mi.mesh as ArrayMesh).surface_get_array_index_len(0) / 3
	var suits := {}
	for slot: String in worn:
		if worn[slot] != "":
			suits[worn[slot]] = true
	return {"tris": tris, "surfaces": surfaces, "materials": suits.size() + (1 if under else 0)}

# ---------------------------------------------------------------- undersuit
const UNDER_SHRINK := 0.002           # of body height (the parts are stored at height 1): about 4 mm on the knight
const UNDER_CODE := "shader_type spatial;
// The body under the armour: the base knight drawn a little smaller and in flat dark cloth, so a gap between two
// parts from different suits shows an undersuit and not the sky.
uniform float shrink = 0.006;
uniform vec3 cloth : source_color = vec3(0.035, 0.036, 0.04);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
void vertex() { VERTEX -= NORMAL * shrink; }
void fragment() {
	ALBEDO = cloth;
	ROUGHNESS = 0.82;
	METALLIC = 0.0;
	SPECULAR = 0.25;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 0.35;
}"

func _build_under() -> void:
	var path := "%s%s_under.res" % [dir, body]
	if not ResourceLoader.exists(path):
		return
	if _under_shader == null:
		_under_shader = Shader.new()
		_under_shader.code = UNDER_CODE
	under = MeshInstance3D.new()
	under.name = "part_under"
	under.mesh = load(path)
	under.skin = skin_of(body)
	skel.add_child(under)
	under.skeleton = under.get_path_to(skel)
	var m := ShaderMaterial.new()
	m.shader = _under_shader
	m.set_shader_parameter("shrink", UNDER_SHRINK)
	var base := _material(body, host)
	if base:
		m.set_shader_parameter("normal_tex", base.get_shader_parameter("normal_tex"))
	under.set_surface_override_material(0, m)
	under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
