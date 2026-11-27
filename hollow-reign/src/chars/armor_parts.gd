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
	"cloth": 1.0, "cloth_dark": 0.045, "tone": Color(1, 1, 1)}
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
	return true

func _own_material(suit: String) -> ShaderMaterial:
	if _mats.has(suit):
		return _mats[suit]
	var src := _material(body, suit)
	var m: ShaderMaterial = src.duplicate() if src else ShaderMaterial.new()
	var f := finish_of(suit) if _finish else FINISH_OLD
	for k: String in f:
		m.set_shader_parameter("tint" if k == "tone" else k, f[k])
	for k3: StringName in _params:
		if k3 != &"tint":
			m.set_shader_parameter(k3, _params[k3])
	_mats[suit] = m
	return m

## Same meaning as Look.set_param for a whole-suit model: tint, flash, rim_color on every worn part.
func set_param(param: StringName, value: Variant) -> void:
	_params[param] = value
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
