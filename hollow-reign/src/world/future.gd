class_name Future
extends RefCounted
## The duel regions as the far future left them (owner's direction: "the land is natural, everything built on it is
## futuristic, nothing medieval"). One shared kit serves every region:
##   - eleven generated props (assets/models/env_fu_*.glb, about 2,300 to 5,700 triangles each) drawn with
##     future_prop.gdshader, which turns the light lines painted in their textures into the region's own light;
##   - shapes built here and merged by material into a handful of meshes (bulkhead walls, spires, monoliths, ribs,
##     rings, masts, conduits), drawn with future_built.gdshader (panel lines, rain streaks, the region's grime);
##   - a floor shader (future_ground.gdshader): a deck of plates round the duelling ring, the region's land beyond.
## Arena.build() asks `handles()` and, if so, calls `floor()` and `build()` in place of its own floor and layout.
## The arena's size, the duelling ring, the theme table and the hooks other code uses (`theme`, `env`, `sun`,
## `fires`, `tint()`) are untouched. `--oldworld` (a dev flag) loads the earlier medieval layouts instead.

static var old_world: bool = OS.get_cmdline_user_args().has("--oldworld")

const MODEL := "res://assets/models/env_%s.glb"
const LAYOUTS := ["ruin", "forest", "nave", "facade", "vault", "hall", "throne"]
## A region's materials. deck/band/seam: the floor's plates, inlaid alloy and light. pale/alloy: built surfaces.
## land: which ground texture is the land (assets/textures/floor_<land>), tinted by land_a/land_b; land_amt 0 uses only
## its grain. deck_r: the deck's radius (100: the whole floor). lost: how much of it the land has taken back.
## grime: what gathers at the foot of things. prop: tint on the generated props.
const LOOKS := {
	"courtyard": {"deck": "#72746f", "band": "#2a2e32", "seam": "#7fe6f4", "pale": "#a9aba3", "alloy": "#4c5258", "land": "blackwood", "land_a": "#3c5620", "land_b": "#6c7034",
		"land_amt": 0.08, "deck_r": 8.4, "lost": 0.3, "grime": "#3c4a1e", "grime_h": 1.3, "prop": "#ffffff", "lamp": "#ffc27a"},
	"blackwood": {"deck": "#2e342d", "band": "#141a16", "seam": "#c8e07a", "pale": "#6c7466", "alloy": "#2e342e", "land": "blackwood", "land_a": "#8c9478", "land_b": "#a8a684",
		"land_amt": 1.0, "deck_r": 6.6, "lost": 0.8, "lit_e": 1.8, "grime": "#243016", "grime_h": 2.4, "prop": "#93a086", "lamp": "#c8d86a"},
	"cathedral": {"lit_e": 1.5, "deck": "#4a443e", "band": "#1c1816", "seam": "#ff8a3a", "pale": "#6e645a", "alloy": "#2e2926", "land": "roost", "land_a": "#8a827a", "land_b": "#a89c90",
		"land_amt": 0.8, "deck_r": 100.0, "lost": 0.55, "grime": "#161312", "grime_h": 2.6, "prop": "#8e8276", "lamp": "#ff8a3a"},
	"cathedral_steps": {"lit_e": 1.5, "deck": "#4a443e", "band": "#1c1816", "seam": "#ff8a3a", "pale": "#6e645a", "alloy": "#2e2926", "land": "roost", "land_a": "#8a827a", "land_b": "#a89c90",
		"land_amt": 0.8, "deck_r": 100.0, "lost": 0.4, "grime": "#161312", "grime_h": 2.2, "prop": "#8e8276", "lamp": "#ff8a3a"},
	"crypt": {"lit_e": 1.6, "deck": "#46544e", "band": "#18201e", "seam": "#66f0c8", "pale": "#63766e", "alloy": "#26302d", "land": "crypt", "land_a": "#8c9c94", "land_b": "#a0b0a4",
		"land_amt": 1.0, "deck_r": 100.0, "lost": 0.45, "grime": "#14261e", "grime_h": 1.8, "prop": "#86a096", "lamp": "#66f0c8", "wet": 1.0},
	"citadel": {"deck": "#9ca8b4", "band": "#2c3440", "seam": "#8adcff", "pale": "#aab6c2", "alloy": "#3e4854", "land": "citadel", "land_a": "#b4c0cc", "land_b": "#d0d8e0",
		"land_amt": 1.0, "deck_r": 9.0, "lost": 0.35, "grime": "#c4d2e0", "grime_h": 1.0, "prop": "#c8d4e4", "lamp": "#8adcff", "snow": 0.75},
	# the opening's two interiors only borrow the kit's props (Arena._layout_chamber, _layout_command)
	"chamber": {"seam": "#5fe0c8", "prop": "#b4b6ae"},
	"command": {"seam": "#ffc27a", "prop": "#c4c6c0"},
	"throne": {"lit_e": 1.6, "deck": "#3e3934", "band": "#151210", "seam": "#ffcc66", "pale": "#5c554c", "alloy": "#221f1c", "land": "throne", "land_a": "#8c8478", "land_b": "#a09480",
		"land_amt": 1.0, "deck_r": 100.0, "lost": 0.0, "grime": "#100e0c", "grime_h": 0.9, "prop": "#968a7a", "lamp": "#ffc860"},
}
## Which light a prop's own texture was painted with (future_prop.gdshader `key`): cyan unless listed.
const AMBER_LIT := ["fu_throne"]
const COARSE := ["road_gate_future", "fu_tower", "bw_giant_tree"]
const DUEL_LOOKS := ["courtyard", "blackwood", "cathedral", "cathedral_steps", "crypt", "citadel", "throne"]

## The Performance preset: fewer shadow casters, coarser detail levels, and the costliest extras left out.
static func low() -> bool:
	return int(Game.settings.quality) == 0

static func handles(layout: String, theme_id: String) -> bool:
	return not old_world and LAYOUTS.has(layout) and DUEL_LOOKS.has(theme_id) and PropModel.exists(MODEL % "fu_pylon")

# ================================================================ materials
static func _look(a: Arena) -> Dictionary:
	return LOOKS[a.get_meta("future_look")]

static func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

## A built surface in this region: `kind` "pale" (matte ceramic) or "alloy" (brushed, darker).
static func built(a: Arena, kind: String) -> ShaderMaterial:
	var id: String = a.get_meta("future_look")
	var key := "fubuilt_%s_%s" % [id, kind]
	if Look._cache.has(key):
		return Look._cache[key]
	var lk: Dictionary = LOOKS[id]
	var sheet := Highland._panels()
	var m := ShaderMaterial.new()
	m.shader = load("res://src/world/future_built.gdshader")
	m.set_shader_parameter("panel_tex", sheet[0])
	m.set_shader_parameter("panel_n", sheet[1])
	m.set_shader_parameter("noise_tex", Highland._noise_tex())
	m.set_shader_parameter("tint", Color(str(lk[kind])))
	m.set_shader_parameter("metal", 0.12 if kind == "pale" else 0.5)
	m.set_shader_parameter("rough", 0.62 if kind == "pale" else 0.5)
	m.set_shader_parameter("scale", 0.07 if kind == "pale" else 0.06)
	m.set_shader_parameter("plate", 0.85 if kind == "pale" else 0.4)
	m.set_shader_parameter("grime", Color(str(lk.grime)))
	m.set_shader_parameter("grime_h", float(lk.grime_h))
	m.set_shader_parameter("snow", float(lk.get("snow", 0.0)))
	Look._cache[key] = m
	return m

## The generated props' material for this region (one for each source material and region).
static func _prop_mat(a: Arena, src: BaseMaterial3D, id: String) -> ShaderMaterial:
	var look_id: String = a.get_meta("future_look")
	var key := "fuprop_%d_%s" % [src.get_instance_id(), look_id]
	if Look._cache.has(key):
		return Look._cache[key]
	var lk: Dictionary = LOOKS[look_id]
	var m := ShaderMaterial.new()
	m.shader = load("res://src/world/future_prop.gdshader")
	m.set_shader_parameter("albedo_tex", src.albedo_texture)
	if src.normal_texture:
		m.set_shader_parameter("normal_tex", src.normal_texture)
	var orm: Texture2D = src.roughness_texture if src.roughness_texture else src.metallic_texture
	if orm:
		m.set_shader_parameter("orm_tex", orm)
	m.set_shader_parameter("tint", Color(str(lk.prop)))
	m.set_shader_parameter("seam", Color(str(lk.seam)))
	m.set_shader_parameter("snow", float(lk.get("snow", 0.0)))
	if id in AMBER_LIT:
		m.set_shader_parameter("key", Vector3(1.0, 0.1, -1.25))
		m.set_shader_parameter("key_lo", 0.3)
		m.set_shader_parameter("key_hi", 0.5)
	Look._cache[key] = m
	return m

# ================================================================ the floor
static func floor(a: Arena, theme_id: String) -> void:
	a.set_meta("future_look", theme_id)
	var lk: Dictionary = LOOKS[theme_id]
	var sheet := Highland._panels()
	var m := ShaderMaterial.new()
	m.shader = load("res://src/world/future_ground.gdshader")
	m.set_shader_parameter("noise_tex", Highland._noise_tex())
	m.set_shader_parameter("panel_tex", sheet[0])
	m.set_shader_parameter("panel_n", sheet[1])
	m.set_shader_parameter("land_tex", _tex("res://assets/textures/floor_%s.jpg" % lk.land))
	m.set_shader_parameter("land_n", _tex("res://assets/textures/floor_%s_n.png" % lk.land))
	for k: String in ["deck", "band", "seam", "land_a", "land_b"]:
		m.set_shader_parameter(k, Color(str(lk[k])))
	m.set_shader_parameter("land_tex_amt", float(lk.land_amt))
	m.set_shader_parameter("deck_r", float(lk.deck_r))
	m.set_shader_parameter("lost", float(lk.lost))
	m.set_shader_parameter("snow", float(lk.get("snow", 0.0)) * 0.8)
	m.set_shader_parameter("wet", float(lk.get("wet", 0.0)))
	var p := PlaneMesh.new()
	p.size = Vector2(90, 90)
	var mi := MeshInstance3D.new()
	mi.name = "FuFloor"
	mi.mesh = p
	mi.material_override = m
	a.add_child(mi)
	a.set_meta("future_floor", m)

static func build(a: Arena, theme_id: String) -> void:
	a.set_meta("future_look", theme_id)
	var k := Kit.new(a)
	match str(a.theme.layout):
		"ruin": _court(a, k)
		"forest": _grove(a, k)
		"nave": _archive(a, k)
		"vault": _vault(a, k)
		"hall": _hall(a, k)
		"throne": _throne(a, k)
		"facade": _steps(a, k)
	k.commit()

# ================================================================ the kit: what is merged
## Collects what a layout builds, by material, and commits each as one mesh. "pale" and "alloy" cast shadows;
## "pale_far" and "alloy_far" do not (anything away from the ring); "lit" is the region's light, "lit2" the old
## machines' own pale cyan, "dim" a light that is nearly out.
class Kit:
	var a: Arena
	var lk: Dictionary
	var tools := {}
	var rng := RandomNumberGenerator.new()

	func _init(arena: Arena) -> void:
		a = arena
		lk = Future.LOOKS[a.get_meta("future_look")]
		rng.seed = hash(str(a.get_meta("future_look")) + "future")

	func tool(nm: String) -> SurfaceTool:
		if not tools.has(nm):
			tools[nm] = Highland._flat_tool()
		return tools[nm]

	func pale(far: bool = true) -> SurfaceTool:
		return tool("pale_far" if far else "pale")

	func alloy(far: bool = true) -> SurfaceTool:
		return tool("alloy_far" if far else "alloy")

	func seam() -> Color:
		return Color(str(lk.seam))

	func commit() -> void:
		for nm: String in tools:
			var mat: Material
			match nm:
				"bark": mat = Look.stone(Color("#2a241e"), 0.5, 0.95, "bark")
				"ice": mat = Look.flat(Color("#a8d0e8"), 0.14, 0.2)
				"snow": mat = Look.flat(Color("#d4dde8"), 0.95)
				"dark": mat = Look.flat(Color("#0c0d0e"), 0.8, 0.2)
				"lit": mat = Look.glow(seam(), float(lk.get("lit_e", 2.4)))
				"lit2": mat = Look.glow(Color("#9fe8f0"), 1.8)
				"dim": mat = Look.glow(seam().darkened(0.45), 0.7)
				"lamp": mat = Look.glow(Color(str(lk.lamp)).lerp(Color.WHITE, 0.25), 3.2)
				_: mat = Future.built(a, "pale" if nm.begins_with("pale") else "alloy")
			Highland._commit(a, "Fu_" + nm, tools[nm], mat, nm == "pale" or nm == "alloy")

# ---------------------------------------------------------------- shapes
static func _box(sf: SurfaceTool, size: Vector3, at: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var b := BoxMesh.new()
	b.size = size
	sf.append_from(b, 0, Transform3D(basis, at))

static func _yaw(deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(deg))

## A bulkhead wall from `from` to `to` on the ground: tall plates leaning back from the arena between alloy ribs, a
## flat cap, a kerb, and a line of light under the cap on some plates. `gaps` is the chance a plate is down.
static func bulkhead(k: Kit, from: Vector3, to: Vector3, h: float, far: bool = true, gaps: float = 0.0, lean: float = 7.0) -> void:
	var dir := (to - from).normalized()
	var out := Vector3(-dir.z, 0, dir.x)
	if out.dot(from + to) < 0.0:
		var t := from
		from = to
		to = t
		dir = -dir
		out = -out
	var b := Basis(dir, deg_to_rad(lean)) * Basis(dir, Vector3.UP, out)
	var length := from.distance_to(to)
	var n := maxi(1, int(round(length / 3.4)))
	var seg := length / n
	var pale := k.pale(far)
	var alloy := k.alloy(far)
	for i in n:
		var foot := from + dir * (i + 0.5) * seg
		var down := k.rng.randf() < gaps
		var ph := h * (k.rng.randf_range(0.28, 0.5) if down else k.rng.randf_range(0.94, 1.0))
		_box(pale, Vector3(seg - 0.1, ph, 0.5), foot + b * Vector3(0, ph * 0.5, 0), b)
		# the plate's own bevelled head, and the cap over it
		_box(alloy, Vector3(seg - 0.02, 0.28, 0.72), foot + b * Vector3(0, ph + 0.12, 0), b)
		if not down and k.rng.randf() < 0.7:
			_box(k.tool("lit"), Vector3(seg * 0.62, 0.07, 0.05), foot + b * Vector3(0, ph - 0.55, -0.27), b)
		if not down and i % 2 == 0:
			# a recessed service panel low on the plate
			_box(alloy, Vector3(seg * 0.34, ph * 0.3, 0.08), foot + b * Vector3(seg * 0.12, ph * 0.3, -0.26), b)
			_box(k.tool("dim"), Vector3(0.05, ph * 0.18, 0.03), foot + b * Vector3(seg * 0.12, ph * 0.3, -0.31), b)
	for i in n + 1:
		var foot2 := from + dir * i * seg
		var rh := h * 1.04 + 0.3
		_box(alloy, Vector3(0.46, rh, 1.0), foot2 + b * Vector3(0, rh * 0.5, 0.05), b)
		# a buttress foot to each rib, on the arena's side
		_box(alloy, Vector3(0.5, 0.7, 1.0), foot2 + Vector3(0, 0.35, 0) - out * 0.7, Basis(dir, Vector3.UP, out))
	_box(alloy, Vector3(length + 0.4, 0.3, 1.3), (from + to) * 0.5 + Vector3(0, 0.15, 0) - out * 0.1, Basis(dir, Vector3.UP, out))

## A standing monolith built in code (the far cousin of env_fu_pylon): a four-sided taper with a seam of light.
static func monolith(k: Kit, at: Vector3, h: float, w: float, yaw: float = 0.0, far: bool = true) -> void:
	var turn := deg_to_rad(yaw) + PI * 0.25
	Highland._prism(k.pale(far), at, w * 0.72, w * 0.4, h, 4, turn, Vector3(1, 1, 0.6))
	Highland._prism(k.alloy(far), at, w * 0.95, w * 0.8, h * 0.1, 4, turn, Vector3(1, 1, 0.75))
	Highland._prism(k.alloy(far), at + Vector3(0, h, 0), w * 0.42, w * 0.3, h * 0.04, 4, turn, Vector3(1, 1, 0.6))
	var face := _yaw(yaw) * Vector3(0, 0, 1)
	var f0 := w * lerpf(0.72, 0.4, 0.14) * 0.6 * 0.7071 + 0.01
	var f1 := w * lerpf(0.72, 0.4, 0.86) * 0.6 * 0.7071 + 0.01
	Highland._beam(k.tool("lit"), at + face * f0 + Vector3(0, h * 0.14, 0), at + face * f1 + Vector3(0, h * 0.86, 0), 0.07 * w, 0.05)

## A spire: a hexagonal taper in three setbacks with alloy collars, slits of light up its faces and fins near the head.
static func spire(k: Kit, at: Vector3, h: float, r: float, far: bool = true, broken: bool = false, turn: float = 0.0) -> void:
	var pale := k.pale(far)
	var alloy := k.alloy(far)
	var y := 0.0
	var tiers := [[r, r * 0.8, h * 0.44], [r * 0.7, r * 0.52, h * 0.32], [r * 0.42, r * (0.3 if broken else 0.1), h * (0.12 if broken else 0.24)]]
	for ti in tiers.size():
		var t: Array = tiers[ti]
		Highland._prism(pale, at + Vector3(0, y, 0), t[0], t[1], t[2], 6, turn)
		for f in 3:
			if ti == 2:
				continue
			var ang := turn + PI / 6.0 + (f * 2 + ti) * PI / 3.0
			var d := Vector3(sin(ang), 0, cos(ang)) * 0.866
			var r0: float = lerpf(t[0], t[1], 0.25)
			var r1: float = lerpf(t[0], t[1], 0.8)
			Highland._beam(k.tool("lit" if (f + ti) % 3 != 0 else "dim"), at + d * (r0 + 0.03) + Vector3(0, y + float(t[2]) * 0.25, 0), at + d * (r1 + 0.03) + Vector3(0, y + float(t[2]) * 0.8, 0), r * 0.07, 0.05)
		y += float(t[2])
		Highland._prism(alloy, at + Vector3(0, y - h * 0.008, 0), float(t[1]) * 1.14, float(t[1]) * 1.14, h * 0.016, 6, turn)
	# fins cantilevered off the second collar
	var fy := h * 0.76
	for f2 in 3:
		var ang2 := turn + f2 * TAU / 3.0
		var d2 := Vector3(sin(ang2), 0, cos(ang2))
		Highland._beam(alloy, at + d2 * r * 0.45 + Vector3(0, fy, 0), at + d2 * r * 1.25 + Vector3(0, fy + h * 0.05, 0), r * 0.1, r * 0.34)
	if broken:
		# the head is gone: ribs stand out of the stump
		for f3 in 4:
			var ang3 := turn + f3 * TAU / 4.0 + 0.4
			var d3 := Vector3(sin(ang3), 0, cos(ang3)) * r * 0.24
			Highland._beam(alloy, at + d3 + Vector3(0, y, 0), at + d3 * 1.2 + Vector3(0, y + h * k.rng.randf_range(0.04, 0.1), 0), r * 0.06)

## A mast with a blade of light at its head (the kit's lamp post and pennant): steady, the region's own lamp colour.
static func mast(k: Kit, at: Vector3, h: float, far: bool = true, blade: float = 1.0) -> void:
	var alloy := k.alloy(far)
	Highland._prism(alloy, at, 0.09, 0.05, h, 5)
	Highland._prism(alloy, at, 0.26, 0.12, 0.22, 5)
	_box(k.tool("lamp"), Vector3(0.07, 1.25 * blade, 0.2), at + Vector3(0, h - 0.75 * blade, 0))
	for sx: float in [-1.0, 1.0]:
		_box(k.pale(far), Vector3(0.035, 1.5 * blade, 0.3), at + Vector3(sx * 0.075, h - 0.72 * blade, 0))

## A standing beacon: a short mast, a ceramic collar, a tall light element between two blades.
static func beacon(k: Kit, at: Vector3, h: float, yaw: float = 0.0) -> void:
	var b := _yaw(yaw)
	var alloy := k.alloy(false)
	for i in 3:
		var d := b * Vector3(sin(i * TAU / 3.0), 0, cos(i * TAU / 3.0))
		Highland._beam(alloy, at + d * 0.42 + Vector3(0, 0.02, 0), at + Vector3(0, 0.34, 0), 0.07)
	Highland._prism(alloy, at + Vector3(0, 0.25, 0), 0.07, 0.05, h * 0.62, 6)
	Highland._prism(alloy, at + Vector3(0, h * 0.62 + 0.2, 0), 0.06, 0.15, 0.14, 6)
	var y0 := h * 0.62 + 0.34
	var lh := h - y0
	_box(k.tool("lamp"), Vector3(0.11, lh * 0.9, 0.11), at + Vector3(0, y0 + lh * 0.47, 0), b)
	for sx: float in [-1.0, 1.0]:
		_box(k.pale(false), Vector3(0.04, lh, 0.24), at + b * Vector3(sx * 0.13, y0 + lh * 0.5, 0), b)
	_box(alloy, Vector3(0.34, 0.05, 0.28), at + Vector3(0, h + 0.02, 0), b)

## A conduit lying on the ground from one point to another, in straight runs with collars.
static func conduit(k: Kit, pts: Array, r: float = 0.16) -> void:
	var alloy := k.alloy(true)
	for i in pts.size() - 1:
		var p0: Vector3 = pts[i] + Vector3(0, r * 0.8, 0)
		var p1: Vector3 = pts[i + 1] + Vector3(0, r * 0.8, 0)
		var c := CylinderMesh.new()
		c.top_radius = r
		c.bottom_radius = r
		c.height = p0.distance_to(p1)
		c.radial_segments = 6
		c.rings = 1
		var q := Basis(Quaternion(Vector3.UP, (p1 - p0).normalized()))
		alloy.append_from(c, 0, Transform3D(q, (p0 + p1) * 0.5))
		_box(k.pale(true), Vector3(r * 2.6, r * 2.6, r * 2.6), p0, q)
	_box(k.pale(true), Vector3(r * 2.6, r * 2.6, r * 2.6), (pts[pts.size() - 1] as Vector3) + Vector3(0, r * 0.8, 0))

## A pair of leaning ribs across a hall at depth z, meeting overhead (or not, where the roof is gone), with a column
## of light let into the inner face of each leg.
static func ribs(k: Kit, z: float, half: float, h: float, whole: bool = true, far: bool = true, lit: String = "lit") -> void:
	var alloy := k.alloy(far)
	for sx: float in [-1.0, 1.0]:
		var top := Vector3(sx * (half - h * 0.14), h * 0.74, z)
		Highland._beam(alloy, Vector3(sx * half, 0, z), top, 0.9, 1.3)
		_box(k.pale(far), Vector3(1.4, 1.0, 1.8), Vector3(sx * (half + 0.1), 0.5, z))
		Highland._beam(k.tool(lit), Vector3(sx * (half - 0.5), 1.2, z), top + Vector3(-sx * 0.46, -0.5, 0), 0.1, 0.3)
		if whole:
			var knee := Vector3(sx * half * 0.46, h * 0.95, z)
			Highland._beam(alloy, top + Vector3(0, -0.3, 0), knee, 0.75, 1.15)
			Highland._beam(alloy, knee + Vector3(sx * 0.2, -0.1, 0), Vector3(0, h, z), 0.65, 1.05)
		else:
			# a stump of the haunch, torn off
			Highland._beam(alloy, top + Vector3(0, -0.3, 0), top + Vector3(-sx * k.rng.randf_range(0.8, 2.2), k.rng.randf_range(0.8, 1.8), 0), 0.75, 1.15)

## A ring of the makers' ceramic standing on end at `at` (its centre), facing along z, with a channel of light in it.
static func ring(k: Kit, at: Vector3, r: float, thick: float, a0: float = 0.5, a1: float = TAU - 0.5, far: bool = true) -> void:
	var sec := PackedVector2Array([Vector2(-thick, -thick * 0.8), Vector2(-thick, thick * 0.8), Vector2(-thick * 0.55, thick * 1.2), Vector2(thick * 0.55, thick * 1.2), Vector2(thick, thick * 0.8), Vector2(thick, -thick * 0.8)])
	var chan := PackedVector2Array([Vector2(-thick * 1.12, -thick * 0.22), Vector2(-thick * 1.12, thick * 0.22), Vector2(-thick * 0.96, thick * 0.22), Vector2(-thick * 0.96, -thick * 0.22)])
	var ring_sf := Highland._flat_tool()
	var chan_sf := Highland._flat_tool()
	Highland._arc(ring_sf, r, a0, a1, sec, 36)
	Highland._arc(chan_sf, r, a0 + 0.08, a1 - 0.08, chan, 36)
	Highland._commit(k.a, "FuRing", ring_sf, built(k.a, "pale"), not far).position = at
	Highland._commit(k.a, "FuRingLight", chan_sf, Look.glow(k.seam(), float(k.lk.get("lit_e", 2.4))), false).position = at

# ---------------------------------------------------------------- props, lights, land
## Stands a kit model on the ground at `pos`, `height` tall, its front turned to `yaw` degrees (0 faces +Z, the
## camera's side; 90 faces +X; see `toward`). `sink` lowers it into the ground
## (the generated props carry a skirt of their own turf). Shadows: only pieces near the ring that are tall enough to
## throw one worth a second draw, unless `cast` says otherwise (1 on, 0 off).
static func prop(a: Arena, id: String, height: float, pos: Vector3, yaw: float = 0.0, sink: float = 0.0, cast: int = -1) -> Node3D:
	var path := MODEL % id
	if not PropModel.exists(path):
		return null
	var root := PropModel._instance(path)
	if root == null:
		return null
	var key := path + "#scenery"
	if not PropModel._fit_cache.has(key):
		var lo := Vector3.ONE * 1e9
		var hi := Vector3.ONE * -1e9
		for p: Vector3 in PropModel._verts(root):
			lo = lo.min(p)
			hi = hi.max(p)
		PropModel._fit_cache[key] = [lo, hi]
	var lo2: Vector3 = PropModel._fit_cache[key][0]
	var hi2: Vector3 = PropModel._fit_cache[key][1]
	var s := height / maxf(hi2.y - lo2.y, 0.001)
	var holder := Node3D.new()
	holder.name = "Fu_" + id
	a.add_child(holder)
	holder.position = pos
	var kit := id.begins_with("fu_") or id.begins_with("road_gate")
	# the generated kit's models face +X as they come
	holder.rotation_degrees.y = yaw - (90.0 if kit else 0.0)
	holder.add_child(root)
	root.scale = Vector3.ONE * s
	root.position = -Vector3((lo2.x + hi2.x) * 0.5, lo2.y, (lo2.z + hi2.z) * 0.5) * s - Vector3(0, sink * height, 0)
	var d := Vector2(pos.x, pos.z).length()
	var perf := low()
	var shadows := cast == 1 or (cast == -1 and d < (10.5 if perf else 14.0) and height >= 2.5)
	if not kit:
		Look.sanitise(root, PropModel.scenery_class(path))
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if kit:
			for si in mi.mesh.get_surface_count():
				var src := mi.get_active_material(si) as BaseMaterial3D
				if src != null and src.albedo_texture != null:
					mi.set_surface_override_material(si, _prop_mat(a, src, id))
		# background: coarser detail early, and coarser still away from the ring
		mi.lod_bias = (0.4 if d < 12.0 else 0.2) * (0.45 if perf else 1.0)
		if id in COARSE:
			# big, simple shapes a long way back: their coarsest levels hold the silhouette, the texture does the rest
			mi.lod_bias = 0.05 if perf else 0.1
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return holder

## The yaw that turns a prop at `pos` to face `at` (the ring by default), plus `off` degrees.
static func toward(pos: Vector3, off: float = 0.0, at: Vector3 = Vector3.ZERO) -> float:
	return rad_to_deg(atan2(at.x - pos.x, at.z - pos.z)) + off

## A light that belongs to a machine. `fire` true joins the arena's flickering fires (theme hook: the opening and the
## phase stains dim and recolour those).
static func lamp(a: Arena, at: Vector3, c: Color, energy: float, reach: float, fire: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.3
	l.position = at
	a.add_child(l)
	if fire:
		a.fires.append([l, energy, a.rng.randf() * 10.0])
	return l

## Tufts of grass on the land outside the deck (never on it, and never in the lane the camera backs down).
static func tufts(a: Arena, count: int, r0: float, r1: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var blade := QuadMesh.new()
	blade.size = Vector2(0.5, 0.45)
	blade.center_offset = Vector3(0, 0.22, 0)
	mm.mesh = blade
	count = int(count * (0.6 if int(Game.settings.quality) == 0 else 1.0))
	mm.instance_count = count * 2
	var n := 0
	for i in count:
		var ang := a.rng.randf() * TAU
		var d := lerpf(r0, r1, sqrt(a.rng.randf()))
		var p := Vector3(cos(ang) * d, 0, sin(ang) * d)
		if absf(p.x) < 2.6 and p.z > 0.0 and d < 14.0:
			p.x = signf(p.x + 0.001) * a.rng.randf_range(2.8, 6.0)
		var yaw := a.rng.randf() * PI
		var s := a.rng.randf_range(0.6, 1.5)
		for j in 2:
			mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, yaw + j * PI * 0.5).scaled(Vector3.ONE * s), p))
			n += 1
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/fx/grass_sway.gdshader")
	mat.set_shader_parameter("albedo_tex", Look.grass())
	var mi := MultiMeshInstance3D.new()
	mi.name = "FuTufts"
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(mi)

## The country round an open arena: two ranges of hills inside the duel camera's far plane (120 m), drawn by their
## own light and thinned by hand (highland_far.gdshader), so they do not wash out in the arena's fog.
static func ranges(a: Arena, snowy: float = 0.0) -> void:
	var crest := FastNoiseLite.new()
	crest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	crest.frequency = 1.0
	crest.fractal_octaves = 2
	crest.seed = 23
	var sf := SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer: Array in [[82.0, 0.28, 17.0, 3.0, 0.2], [100.0, 0.55, 36.0, 11.0, 1.0]]:
		var radius := float(layer[0])
		var n := 96
		var rows: Array = []
		for i in n + 1:
			var az := TAU * float(i % n) / float(n)
			var c := Vector2(cos(az), sin(az))
			var ridged := 1.0 - absf(crest.get_noise_2d(c.x * 1.6 + float(layer[3]), c.y * 1.6))
			var top := float(layer[2]) * (0.25 + 0.75 * ridged * ridged) * (0.7 + 0.5 * crest.get_noise_2d(c.x * 0.8 + 9.0, c.y * 0.8 + float(layer[3])))
			var wob := crest.get_noise_2d(c.x * 4.0, c.y * 4.0 + float(layer[3]))
			var dir := Vector3(c.x, 0, c.y)
			rows.append([dir * radius + Vector3(0, top, 0), dir * (radius - top * (0.5 + 0.3 * wob)) + Vector3(0, top * (0.5 + 0.2 * wob), 0), dir * (radius - top * 1.4 - 8.0) + Vector3(0, -7.0, 0)])
		var col := Color(0, float(layer[4]) * snowy, 0, float(layer[1]))
		for i in n:
			for r in 2:
				var quad := [[rows[i][r], 1.0 - 0.5 * r], [rows[i + 1][r], 1.0 - 0.5 * r], [rows[i + 1][r + 1], 0.5 - 0.5 * r], [rows[i][r + 1], 0.5 - 0.5 * r]]
				for q: int in [0, 1, 2, 0, 2, 3]:
					sf.set_color(col)
					sf.set_uv(Vector2(float(i) / float(n), quad[q][1]))
					sf.add_vertex(quad[q][0])
	sf.generate_normals()
	var th: Dictionary = a.theme
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/world/highland_far.gdshader")
	mat.set_shader_parameter("lit", Color(str(th.sun)).lerp(Color("#6f7a52"), 0.62))
	mat.set_shader_parameter("shade", Color(str(th.amb)).darkened(0.45))
	mat.set_shader_parameter("haze", Color(str(th.horizon)).lerp(Color(str(th.fog)), 0.5))
	mat.set_shader_parameter("rim", Color(str(th.sun)))
	mat.set_shader_parameter("sun_dir", Highland._sun_dir(th.sun_rot))
	mat.set_shader_parameter("snow", 0.0)
	var mi := MeshInstance3D.new()
	mi.name = "FuRanges"
	mi.mesh = sf.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(mi)

## The sky that is not Earth's, brought inside the duel camera's far plane: the banded planet low over the hills and
## the arc of the orbital ring (the high road's own shaders). Two draws.
static func sky(a: Arena, strength: float = 0.85, az: float = -24.0, elev: float = 17.0) -> void:
	var th: Dictionary = a.theme
	var dir := Vector3(sin(deg_to_rad(az)) * cos(deg_to_rad(elev)), sin(deg_to_rad(elev)), -cos(deg_to_rad(az)) * cos(deg_to_rad(elev)))
	var card := QuadMesh.new()
	card.size = Vector2(40, 40)
	var planet := ShaderMaterial.new()
	planet.shader = load("res://src/world/highland_planet.gdshader")
	planet.set_shader_parameter("noise_tex", Highland._noise_tex())
	planet.set_shader_parameter("lit", Color(str(th.horizon)).lerp(Color("#ffe6c2"), 0.6))
	planet.set_shader_parameter("band", Color(str(th.sky)).lerp(Color("#a8705c"), 0.55))
	planet.set_shader_parameter("strength", strength)
	var pmi := MeshInstance3D.new()
	pmi.name = "FuPlanet"
	pmi.mesh = card
	pmi.material_override = planet
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pmi.sorting_offset = -200.0
	a.add_child(pmi)
	pmi.position = dir * 108.0
	pmi.look_at(Vector3.ZERO, Vector3.UP, true)
	planet.set_shader_parameter("light", pmi.global_basis.inverse() * Highland._sun_dir(th.sun_rot))
	var arc_mat := ShaderMaterial.new()
	arc_mat.shader = load("res://src/world/highland_skyline.gdshader")
	arc_mat.set_shader_parameter("noise_tex", Highland._noise_tex())
	arc_mat.set_shader_parameter("strength", strength)
	var u := Vector3(0.94, 0, -0.34).normalized()
	var v := Vector3(0.22, 0.78, 0.59).normalized()
	v = (v - u * v.dot(u)).normalized()
	var arc := SurfaceTool.new()
	arc.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band: Array in [[1.5, 1.0, Color(0.95, 0.93, 0.88, 0.85)], [9.0, 0.0, Color(0.7, 0.75, 0.85, 0.1)]]:
		Highland._ribbon(arc, func(t: float) -> Vector3: return (u * cos(t * PI) + v * sin(t * PI)) * 110.0,
			func(_t: float) -> Vector3: return u.cross(v).normalized(), float(band[0]), 96, band[2], float(band[1]))
	var ami := Highland._sky_mesh(a, "FuOrbit", arc.commit(), arc_mat, -190.0)
	ami.custom_aabb = AABB(Vector3(-130, -20, -130), Vector3(260, 160, 260))

# ================================================================ the regions
## The Fallen Courtyard: the landing court of a hill fortress. A deck of plates in the turf, the blast door behind
## the foe between leaning bulkheads, spires beyond them, a guardian machine that knelt down here and never got up,
## an engine in the grass, and a planet over the hills.
static func _court(a: Arena, k: Kit) -> void:
	a.sun.directional_shadow_max_distance = 45.0
	if OS.get_environment("FU_CHECK") != "":
		_check(a, k)
		return
	var lamp_c := Color(str(k.lk.lamp))
	# the gate and the wall it stands in
	prop(a, "road_gate_future", 12.5, Vector3(0, 0, -20.5), 0.0, 0.0, 0)
	bulkhead(k, Vector3(-23, 0, -19.5), Vector3(-6.0, 0, -19.5), 7.6, true, 0.12)
	bulkhead(k, Vector3(6.0, 0, -19.5), Vector3(23, 0, -19.5), 7.6, true, 0.12)
	bulkhead(k, Vector3(-23, 0, -19.5), Vector3(-23, 0, 15.0), 6.8, true, 0.2)
	bulkhead(k, Vector3(23, 0, -19.5), Vector3(23, 0, 13.0), 6.8, true, 0.2)
	bulkhead(k, Vector3(-23, 0, 21.0), Vector3(-2.5, 0, 21.0), 6.4, true, 0.25)
	bulkhead(k, Vector3(4.5, 0, 21.0), Vector3(23, 0, 21.0), 6.0, true, 0.25)
	# two broken lengths of an older wall stand inside it, one to each side
	prop(a, "fu_wall", 6.6, Vector3(-17.2, 0, -2.0), 90.0, 0.03)
	prop(a, "fu_wall", 5.8, Vector3(17.6, 0, 1.0), -90.0, 0.03)
	# spires: two of the kit's behind the wall, the rest built
	prop(a, "fu_tower", 22.0, Vector3(-18.5, 0, -29.0), 20.0, 0.02, 0)
	prop(a, "fu_tower", 18.0, Vector3(20.5, 0, -28.5), -40.0, 0.02, 0)
	spire(k, Vector3(-38, 0, -42), 46.0, 5.0, true, false, 0.3)
	spire(k, Vector3(7, 0, -54), 60.0, 6.0, true, false, 0.9)
	spire(k, Vector3(42, 0, -38), 38.0, 4.4, true, true, 0.1)
	spire(k, Vector3(-29, 0, 29), 24.0, 3.2, true, true, 0.5)
	spire(k, Vector3(31, 0, 26), 30.0, 3.6, true, false, 1.3)
	spire(k, Vector3(-48, 0, 6), 34.0, 4.0, true, false, 0.7)
	spire(k, Vector3(50, 0, -4), 28.0, 3.6, true, false, 0.2)
	# the guardian that knelt, and the engine in the grass
	var gp := Vector3(-11.6, 0, -10.6)
	prop(a, "fu_colossus", 7.6, gp, toward(gp, -8.0), 0.02, 1)
	var ep := Vector3(11.6, 0, -9.8)
	prop(a, "fu_engine", 4.2, ep, toward(ep, 20.0), 0.06, 0)
	conduit(k, [Vector3(14.0, 0, -12.0), Vector3(15.5, 0, -15.0), Vector3(15.5, 0, -18.9)], 0.2)
	conduit(k, [Vector3(8.2, 0, -11.6), Vector3(5.8, 0, -14.0), Vector3(8.4, 0, -18.9)], 0.14)
	# pylons where the court's pillars stood
	for py: Array in [[-7.6, -4.8, 4.4, 10.0], [7.7, -5.0, 3.8, -15.0], [11.4, 2.0, 5.6, 0.0], [-14.0, 9.5, 4.6, 20.0], [14.5, 11.5, 4.0, -10.0]]:
		var pp := Vector3(py[0], 0, py[1])
		prop(a, "fu_pylon", py[2], pp, toward(pp, py[3]), 0.03)
	lamp(a, Vector3(10.4, 2.6, 1.8), Color("#6fc8ff"), 1.4, 6.0)
	# what else is lying about
	prop(a, "fu_wreck", 2.6, Vector3(-8.4, 0, 3.4), 150.0, 0.05, 0)
	var hp := Vector3(8.2, 0, -1.4)
	prop(a, "fu_husk", 2.0, hp, toward(hp, 25.0), 0.05)
	prop(a, "fu_wreck", 3.4, Vector3(5.0, 0, 15.0), -20.0, 0.05)
	if not low():
		var e2 := Vector3(-7.0, 0, 14.0)
		prop(a, "fu_engine", 3.0, e2, toward(e2, -30.0), 0.08)
	# the land's own: one old tree (the high road's)
	# (not on the Performance preset: it is 8,300 triangles, and behind the camera for most of a fight)
	if not low():
		var t1 := prop(a, "road_dead_tree", 8.0, Vector3(-11.5, 0, 7.6), 110.0, 0.0, 0)
		if t1:
			for mi: MeshInstance3D in t1.find_children("*", "MeshInstance3D", true, false):
				mi.lod_bias = 0.25
	# beacons either side of the foe (the court's two fires), and masts with blades of light along the wall
	for sx: float in [-1.0, 1.0]:
		beacon(k, Vector3(sx * 4.2, 0, -7.4), 2.5, sx * 20.0)
		lamp(a, Vector3(sx * 4.2, 2.1, -7.4), Color(a.theme.fire), 2.0, 9.0, true)
		mast(k, Vector3(sx * 9.6, 0, -17.6), 7.5)
		mast(k, Vector3(sx * 21.0, 0, 9.0 - sx * 2.0), 6.5)
	mast(k, Vector3(-4.0, 0, 18.5), 6.0)
	lamp(a, Vector3(0, 6.0, -14.0), lamp_c, 1.2, 12.0)
	tufts(a, 420, 9.2, 22.0)
	ranges(a, 0.6)
	sky(a)

## Dev (FU_CHECK=1): every kit prop in a row, unturned, to see which way each one faces.
static func _check(a: Arena, _k: Kit) -> void:
	var ids := ["fu_pylon", "fu_tower", "fu_wall", "fu_colossus", "fu_engine", "fu_wreck", "fu_core", "fu_husk", "fu_throne", "fu_cradle", "fu_pod"]
	if OS.get_environment("FU_CHECK") != "1":
		ids = Array(OS.get_environment("FU_CHECK").split(","))
	for i in ids.size():
		prop(a, ids[i], 3.2, Vector3((i - 5) * 3.6, 0, -9.0 - absf(i - 5) * 0.4), 0.0)

# ---------------------------------------------------------------- more shapes, for the other regions
## A colossal trunk built in code: a taper with buttress roots, in bark. The Blackwood's wall of trees.
static func trunk(k: Kit, at: Vector3, h: float, r: float) -> void:
	var sf := k.tool("bark")
	var turn := k.rng.randf() * TAU
	Highland._prism(sf, at + Vector3(0, -0.5, 0), r, r * 0.62, h, 9, turn)
	for i in 5:
		var ang := turn + i * TAU / 5.0 + k.rng.randf_range(-0.3, 0.3)
		var d := Vector3(sin(ang), 0, cos(ang))
		var c := CylinderMesh.new()
		c.bottom_radius = r * 0.42
		c.top_radius = r * 0.12
		c.height = r * 2.6
		c.radial_segments = 6
		c.rings = 1
		sf.append_from(c, 0, Transform3D(Basis(Quaternion(Vector3.UP, (Vector3.UP * 1.0 - d * 0.75).normalized())), at + d * r * 1.15 + Vector3(0, r * 0.75, 0)))
	# two dead boughs, high up
	for j in 2:
		var ang2 := turn + 1.0 + j * 2.6
		var d2 := Vector3(sin(ang2), 0.35, cos(ang2)).normalized()
		var from := at + Vector3(0, h * k.rng.randf_range(0.5, 0.75), 0) + d2 * r * 0.5
		Highland._beam(sf, from, from + d2 * r * k.rng.randf_range(2.5, 4.5), r * 0.22)

## A six-sided column with an alloy foot and head and a band of light let into it at head height.
static func column(k: Kit, at: Vector3, h: float, r: float, far: bool = true, lit: String = "lit") -> void:
	Highland._prism(k.pale(far), at, r, r * 0.9, h, 6)
	Highland._prism(k.alloy(far), at, r * 1.5, r * 1.15, 0.5, 6)
	Highland._prism(k.alloy(far), at + Vector3(0, h - 0.5, 0), r * 1.1, r * 1.5, 0.5, 6)
	Highland._prism(k.tool(lit), at + Vector3(0, 2.5, 0), r * 0.97, r * 0.96, 0.14, 6)
	Highland._prism(k.alloy(far), at + Vector3(0, 2.25, 0), r * 1.03, r * 1.03, 0.2, 6)

## A cluster of ice crystals: the land's own, where the cold has come through the deck.
static func crystals(k: Kit, at: Vector3, tall: float) -> void:
	var sf := k.tool("ice")
	for i in 6:
		var ang := k.rng.randf() * TAU
		var off := Vector3(sin(ang), 0, cos(ang)) * k.rng.randf_range(0.0, tall * 0.28)
		var hh := tall * k.rng.randf_range(0.4, 1.0)
		var c := CylinderMesh.new()
		c.bottom_radius = hh * 0.16
		c.top_radius = 0.0
		c.height = hh
		c.radial_segments = 5
		c.rings = 1
		var tilt := (Vector3.UP + off * 0.5 / maxf(tall, 0.1)).normalized()
		sf.append_from(c, 0, Transform3D(Basis(Quaternion(Vector3.UP, tilt)), at + off + tilt * hh * 0.45))

## A drift of snow against something: a low mound.
static func drift(k: Kit, at: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var sp := SphereMesh.new()
	sp.radius = 0.5
	sp.height = 1.0
	sp.radial_segments = 10
	sp.rings = 5
	k.tool("snow").append_from(sp, 0, Transform3D(_yaw(yaw).scaled(size), at))

## A console: a low desk of alloy with a sloped face and a strip of readouts, most of them dead.
static func console(k: Kit, at: Vector3, yaw: float, w: float = 2.6) -> void:
	var b := _yaw(yaw)
	_box(k.alloy(true), Vector3(w, 0.8, 0.7), at + Vector3(0, 0.4, 0), b)
	_box(k.pale(true), Vector3(w * 0.96, 0.08, 0.6), at + b * Vector3(0, 0.92, 0.08), b * Basis(Vector3.RIGHT, deg_to_rad(18.0)))
	_box(k.tool("dim"), Vector3(w * 0.5, 0.04, 0.05), at + b * Vector3(-w * 0.15, 0.76, 0.36), b)

## A wall of flat plates for an interior: from `from` to `to`, `h` tall, with a slot of light in every other bay.
static func plates(k: Kit, from: Vector3, to: Vector3, h: float, slots: String = "dim") -> void:
	var dir := (to - from).normalized()
	var out := Vector3(-dir.z, 0, dir.x)
	if out.dot(from + to) < 0.0:
		out = -out
	var b := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
	var length := from.distance_to(to)
	var n := maxi(1, int(round(length / 6.0)))
	var seg := length / n
	_box(k.alloy(true), Vector3(length, h, 0.6), (from + to) * 0.5 + Vector3(0, h * 0.5, 0) + out * 0.3, b)
	for i in n:
		var mid := from + dir * (i + 0.5) * seg
		_box(k.pale(true), Vector3(seg * 0.7, h * 0.3, 0.12), mid + Vector3(0, h * 0.2, 0) - out * 0.02, b)
		if slots != "" and i % 2 == 0:
			_box(k.tool(slots), Vector3(0.3, h * 0.42, 0.08), mid + Vector3(0, h * 0.62, 0) - out * 0.03, b)
			_box(k.alloy(true), Vector3(1.1, 0.25, 0.3), mid + Vector3(0, h * 0.4, 0) - out * 0.1, b)

## A door in an interior wall at `at` (the middle of its sill), facing +Z: frame, two dark leaves, a seam of light.
static func door(k: Kit, at: Vector3, w: float, h: float) -> void:
	var alloy := k.alloy(true)
	for sx: float in [-1.0, 1.0]:
		Highland._beam(alloy, at + Vector3(sx * (w * 0.5 + 0.5), 0, 0.2), at + Vector3(sx * (w * 0.42 + 0.4), h + 0.3, 0.2), 0.9, 1.1)
		_box(k.tool("dark"), Vector3(w * 0.5 - 0.06, h, 0.3), at + Vector3(sx * w * 0.25, h * 0.5, 0))
	_box(alloy, Vector3(w + 1.8, 0.8, 1.2), at + Vector3(0, h + 0.5, 0.2))
	_box(k.tool("lit"), Vector3(0.09, h * 0.9, 0.06), at + Vector3(0, h * 0.5, 0.17))
	_box(k.tool("lit"), Vector3(w * 0.6, 0.08, 0.06), at + Vector3(0, h + 0.2, 0.82))

# ================================================================ the other regions
## The Blackwood: the forest has had this place for a long time. The trees are the land's and stay; what stood among
## them was a machine shrine, and it is still giving off its sick light. A guardian went down on one knee between
## the trunks; the deck is almost all gone under leaf mould.
static func _grove(a: Arena, k: Kit) -> void:
	a.sun.directional_shadow_max_distance = 40.0
	var fire := Color(a.theme.fire)
	# the wall of trunks: three of the generated giants where the eye goes, the rest built
	# (each has a hollow under its roots; it is turned away from the ring so it does not read as a doorway)
	for t: Array in [[-13.5, -15.0, 26.0], [15.0, -13.5, 24.0]]:
		var tp := Vector3(t[0], -0.6, t[1])
		prop(a, "bw_giant_tree", t[2], tp, toward(tp, 180.0), 0.0, 0)
	for t2: Array in [[-18.5, 12.5, 30.0, 2.6], [-19.5, -8.5, 24.0, 1.5], [20.0, -7.5, 22.0, 1.4], [9.0, 20.0, 24.0, 1.5], [1.5, -22.0, 34.0, 2.6], [-22.5, -3.0, 28.0, 2.2], [22.0, -1.0, 30.0, 2.4], [16.5, 14.5, 26.0, 2.0], [0.0, 23.0, 28.0, 2.3], [-31.0, -22.0, 40.0, 3.2],
			[30.0, -24.0, 42.0, 3.4], [-34.0, 8.0, 36.0, 3.0], [34.0, 10.0, 38.0, 3.1], [-8.0, -27.0, 36.0, 2.6], [12.0, -30.0, 40.0, 3.0], [-24.0, 24.0, 34.0, 2.8], [26.0, 26.0, 34.0, 2.7]]:
		trunk(k, Vector3(t2[0], 0, t2[1]), t2[2], t2[3])
	# the shrine was a machine
	prop(a, "fu_core", 5.4, Vector3(0.5, 0, -12.2), 0.0, 0.04, 1)
	lamp(a, Vector3(0.5, 2.8, -10.0), fire, 2.0, 10.0, true)
	var gp := Vector3(11.5, 0, -10.5)
	prop(a, "fu_colossus", 7.0, gp, toward(gp, 10.0), 0.03)
	var sp := Vector3(-7.4, 0, -4.4)
	prop(a, "fu_pylon", 4.6, sp, toward(sp, 15.0), 0.04)
	lamp(a, Vector3(-6.4, 2.2, -3.6), Color("#7dffb0"), 1.2, 5.0)
	prop(a, "fu_wreck", 4.6, Vector3(-10.5, 0, -9.5), 130.0, 0.06)
	var hp := Vector3(-9.6, 0, 4.6)
	prop(a, "fu_husk", 2.2, hp, toward(hp, -20.0), 0.06)
	var pp := Vector3(13.2, 0, 8.6)
	prop(a, "fu_pod", 5.0, pp, toward(pp), 0.04)
	var ep := Vector3(9.4, 0, 1.6)
	prop(a, "fu_engine", 2.6, ep, toward(ep, 70.0), 0.1)
	prop(a, "fu_wreck", 3.0, Vector3(6.0, 0, 15.0), -30.0, 0.06)
	# lengths of the old enclosure still standing between the trunks
	bulkhead(k, Vector3(-21.0, 0, -18.0), Vector3(-8.0, 0, -21.0), 6.0, true, 0.45)
	bulkhead(k, Vector3(8.0, 0, -20.5), Vector3(20.0, 0, -16.0), 5.6, true, 0.45)
	bulkhead(k, Vector3(-23.0, 0, 2.0), Vector3(-21.0, 0, 16.0), 5.0, true, 0.5)
	bulkhead(k, Vector3(22.0, 0, 4.0), Vector3(19.0, 0, 17.0), 5.0, true, 0.5)
	# the lanterns are beacons now, and still lit
	var posts := [Vector3(-4.4, 0, -6.8), Vector3(4.6, 0, -6.4), Vector3(-7.6, 0, 1.6), Vector3(7.0, 0, 6.2), Vector3(-2.6, 0, 12.0)]
	for i in posts.size():
		beacon(k, posts[i], 3.2, i * 40.0)
		if i < 4:
			lamp(a, (posts[i] as Vector3) + Vector3(0, 2.7, 0), fire, 1.8, 8.0, true)
	conduit(k, [Vector3(2.4, 0, -11.0), Vector3(6.5, 0, -9.5), Vector3(9.0, 0, -9.0)], 0.16)
	tufts(a, 380, 7.6, 21.0)

## The Cathedral of Ash: an archive hall that burned. Leaning ribs march to the core behind the foe, half of them
## without their roof; the walls are plate with slots of ember light; a guardian kneels by the core where the
## statues stood, and the floor is soot and fallen ash over the deck.
static func _archive(a: Arena, k: Kit) -> void:
	a.sun.directional_shadow_max_distance = 40.0
	var fire := Color(a.theme.fire)
	for i in 6:
		ribs(k, 10.0 - i * 6.5, 9.6, 15.0, i % 3 != 1, true, "lit" if i % 2 == 0 else "dim")
	for sx: float in [-1.0, 1.0]:
		plates(k, Vector3(sx * 11.6, 0, 16.0), Vector3(sx * 11.6, 0, -26.0), 13.0)
	plates(k, Vector3(-11.6, 0, -26.0), Vector3(11.6, 0, -26.0), 16.0, "")
	plates(k, Vector3(-11.6, 0, 19.0), Vector3(11.6, 0, 19.0), 12.0, "")
	door(k, Vector3(0, 0, 18.6), 4.0, 6.0)
	# the core where the altar stood, in a ring let into the end wall
	prop(a, "fu_core", 7.4, Vector3(0, 0, -17.5), 0.0, 0.03, 1)
	ring(k, Vector3(0, 7.2, -25.0), 7.0, 0.7, 0.9, TAU - 0.9)
	lamp(a, Vector3(0, 3.6, -14.6), fire, 2.4, 12.0, true)
	var gp := Vector3(-6.4, 0, -13.2)
	prop(a, "fu_colossus", 6.4, gp, toward(gp, -10.0), 0.03)
	var pp := Vector3(6.6, 0, -14.4)
	prop(a, "fu_pod", 5.4, pp, toward(pp, 10.0), 0.03)
	var ep := Vector3(-9.3, 0, 0.3)
	prop(a, "fu_engine", 2.5, ep, 180.0, 0.08)
	var hp := Vector3(7.8, 0, 3.2)
	prop(a, "fu_husk", 1.9, hp, toward(hp, 30.0), 0.06)
	prop(a, "fu_wreck", 2.4, Vector3(8.6, 0, -8.2), 40.0, 0.06)
	# two beacons where the censers hung
	for b: Vector3 in [Vector3(5.2, 0, -5.5), Vector3(-4.8, 0, 6.5)]:
		beacon(k, b, 3.0, 30.0)
		lamp(a, b + Vector3(0, 2.6, 0), fire, 1.5, 7.0, true)
	# reading desks where the pews were
	for i2 in 4:
		for sx2: float in [-1.0, 1.0]:
			console(k, Vector3(sx2 * 5.2 + k.rng.randf_range(-0.3, 0.3), 0, 9.2 + i2 * 2.5), 180.0 + k.rng.randf_range(-10.0, 10.0))
	# a rib that came down across the far end, and a roof beam
	Highland._beam(k.alloy(true), Vector3(9.2, 8.5, -4.0), Vector3(8.4, 0.4, -11.5), 0.8, 1.2)
	Highland._beam(k.alloy(true), Vector3(9.0, 0.5, 12.5), Vector3(3.0, 0.5, 15.5), 0.7, 1.1)
	conduit(k, [Vector3(2.8, 0, -16.0), Vector3(9.0, 0, -13.0), Vector3(10.8, 0, -6.0)], 0.2)

## The steps before the Cathedral: the deck climbs in broad treads to a blast door in a bulkhead front, spires behind.
static func _steps(a: Arena, k: Kit) -> void:
	a.sun.directional_shadow_max_distance = 40.0
	var fire := Color(a.theme.fire)
	for i in 8:
		_box(k.pale(true), Vector3(26, 0.3, 1.2), Vector3(0, 0.15 + i * 0.3, -8.0 - i * 1.2))
		if i % 2 == 0:
			_box(k.tool("dim"), Vector3(18, 0.04, 0.05), Vector3(0, 0.31 + i * 0.3, -7.42 - i * 1.2))
	_box(k.pale(true), Vector3(34, 2.4, 14), Vector3(0, 1.2, -24.2))
	prop(a, "road_gate_future", 13.0, Vector3(0, 2.4, -24.0), 0.0, 0.0, 0)
	bulkhead(k, Vector3(-26, 0, -19.0), Vector3(-7.0, 0, -19.0), 14.0, true, 0.0, 4.0)
	bulkhead(k, Vector3(7.0, 0, -19.0), Vector3(26, 0, -19.0), 14.0, true, 0.0, 4.0)
	for sx: float in [-1.0, 1.0]:
		spire(k, Vector3(sx * 15.0, 0, -27.0), 38.0, 4.2, true, sx > 0.0, 0.4)
		beacon(k, Vector3(sx * 4.0, 0, -5.5), 2.8, 0.0)
		lamp(a, Vector3(sx * 4.0, 2.3, -5.5), fire, 2.6, 9.0, true)
		var pp := Vector3(sx * 7.2, 0, -2.4)
		prop(a, "fu_pylon", 3.6, pp, toward(pp), 0.04)
		bulkhead(k, Vector3(sx * 24.0, 0, -19.0), Vector3(sx * 22.0, 0, 16.0), 8.0, true, 0.3)
	spire(k, Vector3(0, 0, -44.0), 56.0, 5.6, true, false, 0.2)
	bulkhead(k, Vector3(-22.0, 0, 19.0), Vector3(-3.0, 0, 21.0), 7.0, true, 0.3)
	bulkhead(k, Vector3(5.0, 0, 21.0), Vector3(22.0, 0, 19.0), 6.4, true, 0.3)
	spire(k, Vector3(-30.0, 0, 30.0), 30.0, 3.6, true, true, 0.8)
	spire(k, Vector3(34.0, 0, 22.0), 36.0, 4.0, true, false, 0.1)
	spire(k, Vector3(-44.0, 0, -8.0), 34.0, 4.0, true, false, 0.5)
	ranges(a, 0.0)
	var gp := Vector3(-12.5, 0, 4.0)
	prop(a, "fu_colossus", 6.0, gp, toward(gp), 0.03)
	prop(a, "fu_wreck", 3.0, Vector3(11.0, 0, 6.0), 200.0, 0.06)

## The Sunken Crypt: a stasis vault, flooded. Columns with a band of corpse-light, pods standing along the walls and
## cradles lying open on the floor where the tombs were, the vault's core behind the foe, water over half the deck.
static func _vault(a: Arena, k: Kit) -> void:
	a.sun.directional_shadow_max_distance = 36.0
	var fire := Color(a.theme.fire)
	for i in 5:
		for sx: float in [-1.0, 1.0]:
			column(k, Vector3(sx * 7.6, 0, 9.0 - i * 6.0), 6.6, 0.75, false, "lit" if (i + int(sx)) % 2 == 0 else "dim")
		# a beam across the vault on each pair
		_box(k.alloy(true), Vector3(17.0, 0.7, 1.0), Vector3(0, 6.95, 9.0 - i * 6.0))
	_box(k.alloy(true), Vector3(29.0, 0.5, 38.0), Vector3(0, 7.55, -1.0))
	for sx2: float in [-1.0, 1.0]:
		plates(k, Vector3(sx2 * 13.6, 0, 18.0), Vector3(sx2 * 13.6, 0, -20.0), 7.4)
	plates(k, Vector3(-13.6, 0, -20.0), Vector3(13.6, 0, -20.0), 7.4, "")
	plates(k, Vector3(-13.6, 0, 18.0), Vector3(13.6, 0, 18.0), 7.4, "")
	door(k, Vector3(0, 0, 17.6), 3.6, 5.0)
	prop(a, "fu_core", 6.0, Vector3(0, 0, -14.6), 0.0, 0.03, 1)
	lamp(a, Vector3(0, 3.0, -12.0), fire, 1.8, 10.0, true)
	# the sleepers: pods along the walls, cradles on the floor
	for p: Array in [[-11.3, -9.0], [11.3, -3.0], [-11.3, 3.0], [11.3, 9.0]]:
		prop(a, "fu_pod", 5.0, Vector3(p[0], 0, p[1]), 90.0 if float(p[0]) < 0.0 else -90.0, 0.03, 0)
	for c: Array in [[-5.4, -8.0, 20.0, 1.7], [5.6, -8.6, -15.0, 1.7], [-10.0, 9.6, 80.0, 1.5]]:
		prop(a, "fu_cradle", c[3], Vector3(c[0], 0, c[1]), c[2], 0.04, 0)
	var hp := Vector3(7.2, 0, -2.6)
	prop(a, "fu_husk", 1.7, hp, toward(hp, -30.0), 0.06)
	prop(a, "fu_wreck", 2.2, Vector3(-7.2, 0, 4.6), 100.0, 0.08)
	var posts := [Vector3(-3.8, 0, -6.4), Vector3(4.0, 0, -6.2), Vector3(-6.6, 0, -0.4), Vector3(6.8, 0, 6.0)]
	for i2 in posts.size():
		beacon(k, posts[i2], 2.8, i2 * 50.0)
		lamp(a, (posts[i2] as Vector3) + Vector3(0, 2.4, 0), fire, 1.3, 6.5, true)
	conduit(k, [Vector3(-2.6, 0, -13.6), Vector3(-9.0, 0, -12.0), Vector3(-11.0, 0, -10.0)], 0.16)
	conduit(k, [Vector3(2.6, 0, -13.6), Vector3(9.5, 0, -10.0), Vector3(11.0, 0, -4.4)], 0.16)

## The Frozen Citadel: a hall of standing monoliths open to the snow, the seat of its last king iced into the machine
## behind it, a guardian under a drift, ice coming up through the deck.
static func _hall(a: Arena, k: Kit) -> void:
	a.sun.directional_shadow_max_distance = 45.0
	var fire := Color(a.theme.fire)
	for i in 5:
		for sx: float in [-1.0, 1.0]:
			var at := Vector3(sx * 8.2, 0, 10.0 - i * 6.2)
			monolith(k, at, 12.0 - absf(i - 2.0) * 0.8, 2.2, 90.0 * -sx, false)
			drift(k, at + Vector3(sx * 0.6, 0.1, 0.9), Vector3(3.6, 0.9, 3.0), i * 40.0)
	# the seat, and the halo of the machine it is part of
	prop(a, "fu_throne", 7.0, Vector3(0, 0, -15.5), 0.0, 0.02, 1)
	ring(k, Vector3(0, 7.0, -19.0), 6.4, 0.6, 0.7, TAU - 0.7)
	lamp(a, Vector3(0, 4.0, -12.5), Color("#8adcff"), 1.6, 10.0)
	prop(a, "road_gate_future", 10.0, Vector3(0, 0, 20.5), 180.0, 0.0, 0)
	bulkhead(k, Vector3(-17.0, 0, -21.0), Vector3(17.0, 0, -21.0), 9.5, true, 0.1)
	bulkhead(k, Vector3(-17.0, 0, -21.0), Vector3(-17.0, 0, 19.0), 7.5, true, 0.2)
	bulkhead(k, Vector3(17.0, 0, -21.0), Vector3(17.0, 0, 19.0), 7.5, true, 0.2)
	bulkhead(k, Vector3(-17.0, 0, 19.5), Vector3(-7.5, 0, 19.5), 7.0, true, 0.2)
	bulkhead(k, Vector3(7.5, 0, 19.5), Vector3(17.0, 0, 19.5), 7.0, true, 0.2)
	var gp := Vector3(7.4, 0, -12.6)
	prop(a, "fu_colossus", 6.4, gp, toward(gp, 15.0), 0.04)
	drift(k, gp + Vector3(1.5, 0.2, 1.0), Vector3(7.0, 1.6, 5.0), 30.0)
	var pp := Vector3(-7.6, 0, -11.6)
	prop(a, "fu_pylon", 5.0, pp, toward(pp), 0.04)
	prop(a, "fu_wreck", 2.6, Vector3(-11.5, 0, 6.0), 70.0, 0.08)
	prop(a, "fu_engine", 3.0, Vector3(12.0, 0, 3.0), -90.0, 0.1)
	for sh: Array in [[-10.8, -5.0, 4.4], [11.2, -4.0, 3.4], [-10.5, 13.0, 3.0], [6.4, -8.6, 2.4], [12.5, 12.0, 3.6]]:
		crystals(k, Vector3(sh[0], 0, sh[1]), sh[2])
	lamp(a, Vector3(-10.4, 1.4, -4.6), Color("#7fe0ff"), 1.0, 6.0)
	for b: Vector3 in [Vector3(-4.6, 0, -5.5), Vector3(4.6, 0, -5.5), Vector3(-4.6, 0, 6.5), Vector3(4.6, 0, 6.5)]:
		beacon(k, b, 3.2, 0.0)
		lamp(a, b + Vector3(0, 2.7, 0), fire, 1.5, 8.0, true)
	for d: Array in [[-15.0, -17.0, 9.0, 2.2, 6.0], [14.0, -18.0, 10.0, 2.0, 5.0], [-15.5, 2.0, 5.0, 1.6, 9.0], [15.5, 9.0, 5.0, 1.8, 8.0], [-3.0, 17.5, 9.0, 1.4, 4.0], [0.0, -19.5, 12.0, 1.6, 3.5]]:
		drift(k, Vector3(d[0], 0.1, d[1]), Vector3(d[2], d[3], d[4]))
	for sp: Array in [[-26.0, -30.0, 44.0, 4.4, false], [22.0, -34.0, 54.0, 5.2, false], [36.0, -6.0, 32.0, 3.8, true], [-34.0, 10.0, 36.0, 4.0, false]]:
		spire(k, Vector3(sp[0], 0, sp[1]), sp[2], sp[3], true, sp[4], 0.5)
	ranges(a, 1.0)
	sky(a, 0.6, -150.0, 24.0)

## The Hollow Throne: the last hall. Whole ribs with columns of dull gold light, the machine's ring on end behind the
## seat, the seat itself on a dais in its mouth, two guardians that never left their posts.
static func _throne(a: Arena, k: Kit) -> void:
	a.sun.directional_shadow_max_distance = 45.0
	var fire := Color(a.theme.fire)
	for i in 7:
		ribs(k, 14.0 - i * 6.0, 9.8, 16.0, true, true, "lit")
		if i % 2 == 1:
			for sx: float in [-1.0, 1.0]:
				mast(k, Vector3(sx * 7.2, 0, 14.0 - i * 6.0), 8.5, true, 1.6)
	for sx2: float in [-1.0, 1.0]:
		plates(k, Vector3(sx2 * 11.8, 0, 19.0), Vector3(sx2 * 11.8, 0, -27.0), 14.0)
		# the roof's two slopes
		_box(k.alloy(true), Vector3(7.6, 0.5, 46.0), Vector3(sx2 * 7.3, 13.6, -4.0), Basis(Vector3(0, 0, 1), deg_to_rad(sx2 * -40.0)))
	_box(k.alloy(true), Vector3(10.0, 0.5, 46.0), Vector3(0, 16.2, -4.0))
	plates(k, Vector3(-11.8, 0, -27.0), Vector3(11.8, 0, -27.0), 17.0, "")
	plates(k, Vector3(-11.8, 0, 19.0), Vector3(11.8, 0, 19.0), 14.0, "")
	door(k, Vector3(0, 0, 18.6), 4.4, 7.0)
	# the dais, the seat, the ring
	for s in 3:
		_box(k.pale(true), Vector3(8.6 - s * 1.0, 0.3, 7.0 - s * 1.2), Vector3(0, 0.15 + s * 0.3, -18.0))
	prop(a, "fu_throne", 8.4, Vector3(0, 0.9, -18.6), 0.0, 0.0, 1)
	ring(k, Vector3(0, 8.0, -22.0), 7.4, 0.75, 0.75, TAU - 0.75)
	lamp(a, Vector3(0, 6.5, -14.5), fire, 3.0, 16.0, true)
	for sx3: float in [-1.0, 1.0]:
		# the two guardians kneel either side of the seat, back from the floor the story's scenes are played on
		var gp := Vector3(sx3 * 7.0, 0, -19.4)
		prop(a, "fu_colossus", 5.4, gp, toward(gp, sx3 * 8.0, Vector3(0, 0, -4.0)), 0.02)
		_box(k.tool("dim"), Vector3(0.06, 0.03, 32.0), Vector3(sx3 * 3.3, 0.012, 2.0))
		Highland._beam(k.alloy(true), Vector3(sx3 * 3.4, 2.0, -21.0), Vector3(sx3 * 10.6, 7.0, -23.0), 0.5)
	prop(a, "fu_wreck", 3.0, Vector3(-7.9, 0, 5.0), 40.0, 0.06)
	prop(a, "fu_wreck", 2.4, Vector3(8.6, 0, -0.9), 160.0, 0.06)
	for b: Vector3 in [Vector3(-4.4, 0, -6.0), Vector3(4.4, 0, -6.0), Vector3(-4.4, 0, 5.0), Vector3(4.4, 0, 5.0)]:
		beacon(k, b, 2.6, 0.0)
		lamp(a, b + Vector3(0, 2.2, 0), fire, 1.8, 8.5, true)
