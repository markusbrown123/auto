extends Node3D
## Dev: every piece of equipment on the preview knight, for clipping, wrong placement and missing textures.
## The knight is the armoury's (ArmoryRig, the authored idle it stands in on that screen), dressed down exactly the
## armoury's path: Game.trial_profile -> Duel.player_look -> wear_parts / set_weapon / set_shield on a standing knight
## (a rebuild only when the body itself changes). Each piece is put on over the kit `--base` describes; then the
## representative whole combinations (every set complete, mixed sets, each weapon class with and without a shield).
## For each it saves FRONT / SIDE / BACK into contact sheets and prints one line of measurements:
##   low     lowest skinned vertex (cm; below -2 sinks into the floor, above +3 floats)
##   blade   body vertices within 3.5 cm of the blade (idle stance, and the worst frame of the armoury's preview cut)
##   shield  body vertices inside the shield board (idle and holding the block the armoury previews)
##   seams   ring mismatch at neck / shoulder / elbow / waist / ankle (cm, PartsBench._seam) in the idle pose; flagged
##           when more than 3 cm above the same seam on the starting kit (the base suit's own parts, which fit)
##   tex     part surfaces whose shader has a texture slot left empty; `nomesh` a worn slot with no mesh
## `!!` marks a value past its limit.
##
##   xvfb-run -a -s "-screen 0 960x440x24" godot --path . --rendering-method mobile --resolution 960x440 --fixed-fps 30 \
##       res://tools/dev/equip_sheet.tscn -- --out=<dir> --body=m|f [--only=items|combos] [--slots=helm,weapon] [--noshots]

const VIEWS := [["front", 0.0], ["side", PI * 0.5], ["back", PI]]
const ARMOUR := ["helm", "chest", "shoulders", "gauntlets", "legs", "boots"]
const LIMITS := {"sink": -2.0, "float": 3.0, "blade": 6, "shield": 6, "seam": 3.0}
var base_seams := {}

var args := {}
var body := "m"
var out := ""
var rig: ArmoryRig
var cam: Camera3D
var look_now := {}
var label: Label
var sub: Label
var shots := true
var pr: Node                 # pose_review.gd, borrowed for its skinned-vertex sampling
var bench: Node              # parts_bench.gd, borrowed for its seam rings
var report: Array = []
var flagged: Array = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	body = str(args.get("body", "m"))
	out = str(args.get("out", "user://equip_sheet"))
	shots = not args.has("noshots") and DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(out)
	Game.save_dir_override = OS.get_cache_dir() + "/hollow_reign_equip_sheet"
	DirAccess.make_dir_recursive_absolute(Game.save_dir_override)
	Game.profile = Game.default_profile()
	Game.profile.body = body
	_room()
	pr = load("res://src/dev/pose_review.gd").new()
	bench = load("res://src/dev/parts_bench.gd").new()
	_run()

func _room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.31, 0.33)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.77, 0.8)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.4
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -150, 0)
	fill.light_energy = 0.6
	add_child(fill)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	fl.mesh = pm
	fl.material_override = Look.flat(Color(0.22, 0.23, 0.25), 0.95)
	add_child(fl)
	cam = Camera3D.new()
	cam.fov = 24.0
	add_child(cam)
	cam.make_current()
	var cl := CanvasLayer.new()
	add_child(cl)
	label = Label.new()
	label.position = Vector2(8, 4)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	cl.add_child(label)
	sub = Label.new()
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	sub.add_theme_constant_override("outline_size", 4)
	sub.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	sub.position = Vector2(8, 0)
	sub.offset_top = -40
	sub.offset_bottom = -4
	cl.add_child(sub)

# ---------------------------------------------------------------- dressing, as the armoury does it
func _look_for(p: Dictionary) -> Dictionary:
	var real := Game.profile
	Game.profile = p
	var look := Duel.player_look()
	Game.profile = real
	return look

func _dress(p: Dictionary) -> String:
	var look := _look_for(p)
	if rig == null:
		_rebuild(look)
		return "body"
	var hand_keys := ["weapon", "weapon_model", "weapon_tint", "blade", "glow", "curved", "shield", "gear", "gear_mod", "advanced"]
	var a: Dictionary = look.duplicate()
	var b: Dictionary = look_now.duplicate()
	for k: String in hand_keys + ["helm", "ember", "frost", "eye", "metal", "parts"]:
		a.erase(k)
		b.erase(k)
	if a != b:
		_rebuild(look)
		return "body"
	if look.get("parts") != look_now.get("parts"):
		rig.wear_parts(look.parts)
	var wchg := false
	for k: String in hand_keys:
		if k != "shield" and look.get(k) != look_now.get(k):
			wchg = true
	var schg: bool = look.get("shield") != look_now.get("shield")
	look_now = look
	rig.cfg = look
	if wchg:
		rig.set_weapon(str(look.weapon), look)
	if wchg or schg:
		rig.set_shield(look.get("shield"))
	return "hands"

func _rebuild(look: Dictionary) -> void:
	if rig:
		rig.free()
	rig = ArmoryRig.new()
	add_child(rig)
	rig.build(look, false)
	rig.motion = 0.0
	look_now = look

func _stance(weapon_slot: bool) -> void:
	var cls := str(look_now.get("weapon", "sword"))
	var clip: String = str(ArmoryScreen.IDLE.get(cls, "ss_idle")) if weapon_slot else "idle"
	rig.idle_clip = clip if SkinDriver.has_clip(clip) else ""
	rig.stop_act()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

# ---------------------------------------------------------------- measuring
func _measure(weapon_slot: bool) -> Dictionary:
	var m := {}
	pr.rig = rig
	pr._collect()
	var sk: Array = pr._skinned()
	var pts: PackedVector3Array = sk[0]
	var names: Array = sk[1]
	var lo := 1e9
	for v: Vector3 in pts:
		lo = minf(lo, v.y)
	m.low = lo * 100.0 if not pts.is_empty() else 0.0
	m.blade = _blade(pts, names)
	m.shield = _shield(pts, names)
	# seams between the six parts
	var seams := {}
	if rig.parts:
		var lo2: Dictionary = rig.parts.worn
		for seam: Array in bench.SEAMS:
			if str(lo2.get(seam[1], "")) == "" or str(lo2.get(seam[2], "")) == "":
				continue
			bench.args = {"body": body}
			var r: Array = bench._seam(body, lo2, seam, rig.skin.skel)
			seams[seam[0]] = float(r[0])
	m.seams = seams
	# empty texture slots and missing meshes
	var tex := 0
	var nomesh: Array = []
	if rig.parts:
		for s: String in rig.parts.worn:
			if str(rig.parts.worn[s]) == "" or not rig.parts.nodes.has(s) or (rig.parts.nodes[s] as MeshInstance3D).mesh == null:
				nomesh.append(s)
		for mi: MeshInstance3D in rig.parts.nodes.values():
			if not mi.visible:
				continue
			var mat = mi.get_surface_override_material(0)
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader:
				for u: Dictionary in (mat as ShaderMaterial).shader.get_shader_uniform_list():
					if int(u.get("type", 0)) == TYPE_OBJECT and str(u.get("hint_string", "")).contains("Texture") and (mat as ShaderMaterial).get_shader_parameter(u.name) == null:
						tex += 1
			elif mat == null:
				tex += 1
	for n: Node3D in [rig.weapon_r, rig.shield]:
		if n and n.get_child_count() > 0 and n.find_children("*", "MeshInstance3D", true, false).is_empty():
			nomesh.append(n.name)
	m.tex = tex
	m.nomesh = nomesh
	return m

func _blade(pts: PackedVector3Array, names: Array) -> int:
	var worst := 0
	for wn: Array in [[rig.weapon_r, ["RightHand", "RightForeArm"]], [rig.weapon_l, ["LeftHand", "LeftForeArm"]]]:
		var w: Node3D = wn[0]
		if w == null or w.get_child_count() == 0 or not w.is_visible_in_tree():
			continue
		var gt := w.global_transform
		var a := gt * Vector3(0, rig.weapon_len * 0.14, 0)
		var b := gt * Vector3(0, rig.weapon_len, 0)
		var n := 0
		for i in pts.size():
			var nm: String = names[i]
			if nm.begins_with("RightHand") or nm.begins_with("LeftHand") or (wn[1] as Array).has(nm):
				continue
			if rig.two_handed and (nm == "LeftForeArm" or nm == "RightForeArm"):
				continue
			if pr._seg_dist(pts[i], a, b) < 0.035 * rig.scale.x:
				n += 1
		worst = maxi(worst, n)
	return worst

func _shield(pts: PackedVector3Array, names: Array) -> int:
	if rig.shield == null or not rig.shield.is_visible_in_tree() or rig.shield.get_child_count() == 0:
		return 0
	var st := Transform3D(rig.shield.global_transform.basis, rig.shield.global_transform * rig._sh_c)
	var inv := st.affine_inverse()
	var ex: float = rig._sh_hw * rig._sh_hw * 0.82
	var ey: float = rig._sh_hh * rig._sh_hh * 0.78
	var n := 0
	for i in pts.size():
		var nm: String = names[i]
		if nm.begins_with("Left") or nm.begins_with("RightHand") or nm == "RightForeArm":
			continue
		var l := inv * pts[i]
		if absf(l.z) < 0.03 and l.x * l.x / ex + l.y * l.y / ey < 1.0:
			n += 1
	return n

## The worst of a clip played through (the armoury's preview cut or block), sampled every few frames.
func _through(clip: String, hold: String = "") -> Dictionary:
	var worst := {"blade": 0, "shield": 0}
	if not SkinDriver.has_clip(clip):
		return worst
	rig.motion = 1.0
	rig.play_once(clip, 0.0, -1.0, hold, 0.6 if hold != "" else 0.0)
	var n := int(SkinDriver.clip_length(clip) * 30.0) + (18 if hold != "" else 0)
	for f in range(0, n, 3):
		await _frames(3)
		pr.rig = rig
		pr._collect()
		var sk: Array = pr._skinned()
		worst.blade = maxi(int(worst.blade), _blade(sk[0], sk[1]))
		worst.shield = maxi(int(worst.shield), _shield(sk[0], sk[1]))
	rig.stop_act()
	rig.motion = 0.0
	return worst

# ---------------------------------------------------------------- capture
var _sheet := {}             # sheet name -> [Image cells]

func _capture(sheet: String, title: String, line: String, bad: bool) -> void:
	label.text = title
	sub.text = line
	sub.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if bad else Color(0.85, 0.9, 0.85))
	if not shots:
		return
	var cells: Array = []
	var top := rig.skin.point("Head").y + 0.25 if rig.skin and rig.skin.bone.has("Head") else 2.0
	for v: Array in VIEWS:
		rig.rotation.y = float(v[1])
		var mid := Vector3(0, top * 0.5, 0)
		var d := (top + 0.3) * 0.5 / tan(deg_to_rad(cam.fov * 0.5))
		cam.position = mid + Vector3(0, 0, d)
		cam.look_at(mid)
		await _frames(2)
		await RenderingServer.frame_post_draw
		cells.append(get_viewport().get_texture().get_image())
	rig.rotation.y = 0.0
	if not _sheet.has(sheet):
		_sheet[sheet] = []
	_sheet[sheet].append(cells)

func _write_sheets() -> void:
	for name: String in _sheet:
		var rows: Array = _sheet[name]
		if rows.is_empty():
			continue
		var cw: int = (rows[0][0] as Image).get_width()
		var ch: int = (rows[0][0] as Image).get_height()
		# a third of the viewport per view (the knight is in the middle third), two items side by side
		var vw := cw / 3
		var per := 2
		var w := per * 3 * vw + (per - 1) * 12
		var nrows := int(ceil(rows.size() / float(per)))
		var img := Image.create(w, nrows * ch, false, Image.FORMAT_RGB8)
		img.fill(Color(0.08, 0.08, 0.09))
		for i in rows.size():
			var x0 := (i % per) * (3 * vw + 12)
			var y0 := (i / per) * ch
			for j in 3:
				var src: Image = rows[i][j]
				src.convert(Image.FORMAT_RGB8)
				img.blit_rect(src, Rect2i(vw, 0, vw, ch), Vector2i(x0 + j * vw, y0))
				# the item's name and its measurements are drawn at the viewport's left edge: carry them over on the first view
				if j == 0:
					img.blit_rect(src, Rect2i(0, 0, mini(3 * vw, cw), 26), Vector2i(x0, y0))
					img.blit_rect(src, Rect2i(0, ch - 44, mini(3 * vw, cw), 44), Vector2i(x0, y0 + ch - 44))
		img.save_jpg("%s/%s_%s.jpg" % [out, body, name], 0.86)
		print("sheet ", name, " ", rows.size(), " entries")

# ---------------------------------------------------------------- the run
func _base_profile() -> Dictionary:
	var p: Dictionary = Game.default_profile()
	p.body = body
	p.attrs.strength = 20
	p.attrs.dex = 20
	return p

func _line(m: Dictionary, cut: Dictionary = {}) -> Array:
	var bits: Array = []
	var bad := false
	var low := float(m.low)
	var lowbad := low < LIMITS.sink or low > LIMITS.float
	bits.append("low %+.1f%s" % [low, " !!" if lowbad else ""])
	bad = bad or lowbad
	var bl: int = maxi(int(m.blade), int(cut.get("blade", 0)))
	if bl > 0 or not cut.is_empty():
		bits.append("blade %d/%d%s" % [int(m.blade), int(cut.get("blade", 0)), " !!" if bl > LIMITS.blade else ""])
		bad = bad or bl > LIMITS.blade
	var sh: int = maxi(int(m.shield), int(cut.get("shield", 0)))
	if sh > 0 or cut.has("shield"):
		bits.append("shield %d/%d%s" % [int(m.shield), int(cut.get("shield", 0)), " !!" if sh > LIMITS.shield else ""])
		bad = bad or sh > LIMITS.shield
	var sm: Array = []
	for k: String in m.seams:
		var v: float = m.seams[k]
		var over: bool = v > float(base_seams.get(k, 0.0)) + LIMITS.seam
		sm.append("%s %.1f%s" % [k, v, "!!" if over else ""])
		bad = bad or over
	if not sm.is_empty():
		bits.append("seams " + " ".join(sm))
	if int(m.tex) > 0 or not (m.nomesh as Array).is_empty():
		bits.append("tex %d nomesh %s !!" % [int(m.tex), str(m.nomesh)])
		bad = true
	return [" · ".join(bits), bad]

func _one(sheet: String, title: String, p: Dictionary, weapon_slot: bool, cut: String = "") -> void:
	_dress(p)
	_stance(weapon_slot)
	await _frames(3)
	var m := _measure(weapon_slot)
	var extra := {}
	if cut == "attack":
		extra = await _through(_attack_clip())
	elif cut == "block":
		extra = await _through("ss_block", "ss_block_idle")
	_stance(weapon_slot)
	await _frames(2)
	var l := _line(m, extra)
	var msg := "%s  %s" % [title, l[0]]
	print(("!! " if l[1] else "   ") + msg)
	report.append(msg)
	if l[1]:
		flagged.append(msg)
	await _capture(sheet, "%s · %s" % [body, title], str(l[0]), bool(l[1]))

func _attack_clip() -> String:
	var cls := str(look_now.get("weapon", "sword"))
	var pref: String = str(ArmoryScreen.ATTACK_PREFER.get(str(ArmoryScreen.PACK.get(cls, "ss")), ""))
	return pref if SkinDriver.has_clip(pref) else "ss_cut_r_high"

func _run() -> void:
	await _frames(2)
	_dress(_base_profile())
	_stance(false)
	await _frames(3)
	base_seams = _measure(false).seams
	print("starting kit seams (cm): ", base_seams)
	var only := str(args.get("only", ""))
	var slots: Array = str(args.get("slots", ",".join(ARMOUR + ["weapon", "shield"]))).split(",", false)
	if only != "combos":
		for s: String in slots:
			for it: Dictionary in Db.item_list:
				if str(it.slot) != s:
					continue
				var p := _base_profile()
				p.inventory.append(it.id)
				p.equipped[s] = it.id
				if s == "weapon" and Db.classes[it.cls].two_handed:
					p.equipped.shield = null
				if s == "shield":
					p.equipped.weapon = "w_knight_sword"
				var hands := s in ["weapon", "shield"]
				await _one(s, "%s  %s" % [it.id, it.name], p, hands, "attack" if s == "weapon" else ("block" if s == "shield" else ""))
	if only != "items":
		# every set complete
		for fam: String in ["worn", "garrison", "black", "ash", "vigil", "frost", "regal", "hollow", "wyrm"]:
			var p := _base_profile()
			for s: String in ARMOUR:
				var id := "a_%s_%s" % [fam, s]
				if Db.items.has(id):
					p.equipped[s] = id
			await _one("sets", "set %s" % fam, p, false)
		# mixed sets (the parts bench's six mixes, in item terms)
		var mixes: Array = [
			{"helm": "frost", "chest": "black", "shoulders": "black", "gauntlets": "regal", "legs": "ash", "boots": "vigil"},
			{"helm": "garrison", "chest": "hollow", "shoulders": "garrison", "gauntlets": "black", "legs": "hollow", "boots": "worn"},
			{"helm": "worn", "chest": "ash", "shoulders": "wyrm", "gauntlets": "frost", "legs": "garrison", "boots": "black"},
			{"helm": "hollow", "chest": "regal", "shoulders": "vigil", "gauntlets": "ash", "legs": "black", "boots": "garrison"},
			{"helm": "black", "chest": "worn", "shoulders": "worn", "gauntlets": "garrison", "legs": "worn", "boots": "hollow"},
			{"helm": "wyrm", "chest": "frost", "shoulders": "regal", "gauntlets": "hollow", "legs": "wyrm", "boots": "ash"},
		]
		for i in mixes.size():
			var p2 := _base_profile()
			for s: String in mixes[i]:
				p2.equipped[s] = "a_%s_%s" % [mixes[i][s], s]
			await _one("mixes", "mix %d %s" % [i + 1, str(mixes[i].values())], p2, false)
		# the hands: a weapon of each class, with each shield where a shield can be held
		for w: String in ["w_knight_sword", "w_ashen_great", "w_headsman", "w_twin_fangs", "w_monarch"]:
			for sh in ([null] if Db.classes[Db.item(w).cls].two_handed or Db.item(w).cls == "dual" else ["s_plank", "s_tower", "s_scale"]):
				var p3 := _base_profile()
				p3.equipped.weapon = w
				p3.equipped.shield = sh
				for s2: String in ARMOUR:
					p3.equipped[s2] = "a_regal_" + s2
				await _one("hands", "%s + %s (regal set)" % [w, str(sh)], p3, true, "attack")
	_write_sheets()
	var f := FileAccess.open("%s/%s_report.txt" % [out, body], FileAccess.WRITE)
	f.store_string("body %s · limits %s\n\n%s\n\nflagged (%d):\n%s\n" % [body, str(LIMITS), "\n".join(report), flagged.size(), "\n".join(flagged)])
	f.close()
	print("equip_sheet %s: %d entries, %d flagged" % [body, report.size(), flagged.size()])
	get_tree().quit()
