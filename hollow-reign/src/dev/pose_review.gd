extends Node3D
## Dev: animation QA. One rig in a neutral lit room on a floor grid; every state is played, measured on the real
## skinned vertices every frame (lowest point, blade through the wielder, shield through the body, joint angles),
## and rendered FRONT / SIDE / BACK into one sheet per state.
##
##   xvfb-run -a -s "-screen 0 420x470x24" godot --path . --rendering-method mobile --resolution 420x470 --fixed-fps 30 \
##       res://src/dev/pose_review.tscn -- --out=<dir> [--model=<glb>] [--body=f] [--gear=w_x,s_y] [--foe=<foe id>]
##       [--witness] [--poses=guard,cut_R,...] [--t=0.1,0.2] [--clip=<authored clip>] [--zoom=1.0] [--aim=x,y,z] [--tag=name]
##   --versus=<foe id> [--dirs=R,D] [--gap=m] [--nobite]   two fighters at the duel's striking distance, frames round contact
##   --relic                                              the old Witness relic (the mask) alone from four sides
##   --drone[=plumb,reed,lens] [--attend] [--speak] [--dark]   the Witness drone: one row per variant, beside the knight
##                                                        and close (front, side, top); attentive / speaking / unlit
##   --dronecheck                                         prints the drone's least distance to blade, shield and body
##                                                        through every cut, a block, a sidestep, rolls (headless is fine)
## With --headless and --noshots it only prints the measurements (not for --versus or --relic).
## A line per state: worst value @ time. `low`/`float` lowest skinned vertex (min / max over the state), `tip` `rim` weapon
## and shield against the floor, `blade` `blade_l` body vertices within 3.5 cm of a blade, `shield` body vertices inside
## the shield board, `bshield` blade samples inside it, knee and elbow angles, `offhand` distance from a two-handed grip.
## `!!` marks a value past its limit.

const VIEWS := [["front", Vector3(0, 0, -1)], ["side", Vector3(1, 0, 0)], ["back", Vector3(0, 0, 1)]]
const DIRS := {"R": Vector2(1, 0), "L": Vector2(-1, 0), "U": Vector2(0, 1), "D": Vector2(0, -1),
	"UR": Vector2(0.7, 0.7), "UL": Vector2(-0.7, 0.7), "DR": Vector2(0.7, -0.7), "DL": Vector2(-0.7, -0.7)}

var _args := {}
var rig: Node3D
var cam: Camera3D
var _is_dragon := false
var _as_foe := false
var _look := {}
var _parts: Array = []        # per skinned mesh: {mi, skel, pos, bones, weights, nb, dom, binds}
var _dom_names: Array = []
var _out := ""
var _tag := ""
var _vel := Vector3.ZERO
var _zoom := 1.0
var _floor: MeshInstance3D
var _mid := Vector3.ZERO      # centre of the figure on the floor, for the cameras

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_out = str(_args.get("out", "user://pose_review"))
	DirAccess.make_dir_recursive_absolute(_out)
	_zoom = float(_args.get("zoom", "1.0"))
	_room()
	if _args.has("relic"):
		_relic_sheet()
		return
	_make_look()
	if _args.has("drone"):
		_drone_sheet()
		return
	if _args.has("dronecheck"):
		_drone_check()
		return
	if _args.has("versus"):
		_versus()
		return
	if _args.has("clipscan"):
		_clipscan()
		return
	_run()

## Every cut of every attack clip of one pack ("ss", "th", "dw"), measured on THIS skeleton with the weapon in hand:
## the line the blade tip travels across the contact frame as seen from behind (degrees, 0 = to the fighter's right,
## 90 = up) and the swipe that is nearest, how much of that travel is across the view rather than along it, how far
## the chest is turned from the opponent at the start of the cut and at contact, and how far ahead the blade reaches.
func _clipscan() -> void:
	_fresh()
	for i in 4:
		await get_tree().process_frame
	var fr: FighterRig = rig
	var names: Array = []
	FighterRig.clip_meta("")
	for n: String in FighterRig._au_meta:
		if n.begins_with(str(_args.clipscan) + "_") and (FighterRig._au_meta[n].get("hits", []) as Array).size() > 0:
			names.append(n)
	names.sort()
	print("== clip scan %s on %s, weapon %.2f m" % [str(_args.clipscan), _tag, fr.weapon_len])
	for n: String in names:
		var hits: Array = FighterRig._au_meta[n].hits
		for hi in hits.size():
			var h: Dictionary = hits[hi]
			var tc := float(h.contact)
			var ts := minf(float(h.start), tc - 0.1)
			tc = fr.au_contact(n, maxf(ts, 0.0), maxf(float(h.end), tc + 0.05))
			ts = minf(ts, tc - 0.08)
			var a0: Dictionary = fr.skin.clip_hand(n, maxf(tc - 0.07, ts))
			var a1: Dictionary = fr.skin.clip_hand(n, minf(tc + 0.04, float(h.end)))
			var c: Dictionary = fr.skin.clip_hand(n, tc)
			var s0: Dictionary = fr.skin.clip_hand(n, maxf(ts, 0.0))
			var v: Vector3 = (a1.p + a1.axis * fr.weapon_len) - (a0.p + a0.axis * fr.weapon_len)
			var ang := rad_to_deg(atan2(v.y, v.x))
			var lab: String = ["R", "UR", "U", "UL", "L", "DL", "D", "DR"][posmod(int(round(ang / 45.0)), 8)]
			var yaw := func(d: Dictionary) -> float: return rad_to_deg(atan2((d.chest as Vector3).x, -(d.chest as Vector3).z))
			var worst := 0.0
			var t := maxf(ts, 0.0)
			while t <= float(h.end) + 0.3:
				worst = maxf(worst, absf(float(yaw.call(fr.skin.clip_hand(n, t)))))
				t += 0.033
			print("%-16s hit%d meta=%-6s rig=%-2s %4.0f deg  across=%.2f  speed=%.1f  yaw start %4.0f contact %4.0f worst %4.0f  reach %.2f  hand y %.2f  t %.2f>%.2f>%.2f/%.2f" % [n, hi, str(h.swipe), lab, ang,
				Vector2(v.x, v.y).length() / maxf(v.length(), 0.001), v.length() / 0.11, float(yaw.call(s0)), float(yaw.call(c)), worst,
				-(c.p.z + c.axis.z * fr.weapon_len * 0.8), float(c.p.y), ts, tc, float(h.end), float(FighterRig._au_meta[n].length)])
	get_tree().quit()

## Two fighters at duelling distance: the knight cuts the foe, then the foe cuts the knight; frames around contact.
##   --versus=<foe id> [--gap=2.6] [--nobite] [--dirs=R,D]
func _versus() -> void:
	var foe: Dictionary = Db.foes[str(_args.versus)]
	var look2: Dictionary = foe.rig.duplicate()
	for candidate in ["res://assets/models/%s.glb" % str(_args.versus), "res://assets/models/cls_%s.glb" % str(foe.get("cls", "")).to_lower().replace("-", "_")]:
		if ResourceLoader.exists(candidate) and str(foe.rig.get("kind", "")) != "dragon":
			look2["skin"] = candidate
			break
	var carried: String = Duel.BOSS_WEAPON.get(str(_args.versus), Duel.FOE_WEAPON.get(str(foe.rig.get("weapon", "")), ""))
	if carried != "":
		look2.merge(Duel.weapon_model(carried))
	var dragon := str(foe.rig.get("kind", "")) == "dragon"
	var gap := float(_args.get("gap", str(2.5 + (float(foe.rig.scale) - 1.0) * 1.5)))
	for d: String in str(_args.get("dirs", "R,D")).split(","):
		for who in 2:
			for c in get_children():
				if c is FighterRig or c is DragonRig:
					c.free()
			var a := FighterRig.new()
			add_child(a)
			a.build(_look, false)
			a.position = Vector3(0, 0, gap * 0.5)
			a.walking = true
			a.combat_steps = true
			var b: Node3D = DragonRig.new() if dragon else FighterRig.new()
			add_child(b)
			b.call("build", look2, true)
			b.position = Vector3(0, 0, -gap * 0.5)
			b.rotation.y = PI
			if not _args.has("gap"):
				# the duel steps the attacker to exactly striking distance (Duel._footwork)
				gap = (a.reach() + 0.18 * float(foe.rig.scale)) if who == 0 else ((float(b.call("reach")) + 0.22) if b is FighterRig else gap)
				a.position.z = gap * 0.5
				b.position.z = -gap * 0.5
			if _args.has("nobite"):
				a.auto_bite = false
				if b is FighterRig:
					b.auto_bite = false
			rig = a
			for i in 14:
				await get_tree().process_frame
			var times: Array = [0.3, 0.37, 0.43, 0.5] if who == 0 else [0.78, 0.86, 0.93, 1.0]
			if who == 0:
				a.swing(DIRS[d], float(_args.get("swing", "0.55")))
				if not _args.has("gap"):
					gap = a.reach() + 0.18 * float(foe.rig.scale)
					a.position.z = gap * 0.5
					b.position.z = -gap * 0.5
			else:
				b.call("telegraph", DIRS[d], 0.8, 0.3, "bite" if dragon and d == "D" else "slash")
			var t := 0.0
			var tiles: Array = []
			while not times.is_empty():
				await get_tree().process_frame
				var att: Node3D = a if who == 0 else b
				if att is FighterRig and (att as FighterRig).is_striking():
					var fwd: Vector3 = -att.global_transform.basis.z.normalized()
					print("reach %s t=%.2f mid=%.2f tip=%.2f hand=%.2f  rig.reach()=%.2f gap=%.2f" % ["knight" if who == 0 else "foe", t, (att.call("blade_mid") - att.global_position).dot(fwd), (att.call("blade_tip") - att.global_position).dot(fwd), ((att as FighterRig).weapon_r.global_position - att.global_position).dot(fwd), float(att.call("reach")), gap])
				if t >= float(times[0]) - 0.001:
					times.pop_front()
					a.time_scale = 0.0
					b.set("time_scale", 0.0)
					for v: Vector3 in [Vector3(1, 0, 0), Vector3(0.6, 0.5, 0.65)]:
						cam.size = (3.3 + gap * 0.5) * maxf(1.0, float(foe.rig.scale) * 0.75) / _zoom
						var centre := Vector3(0, cam.size * 0.36, 0)
						cam.position = centre + v.normalized() * 30.0
						cam.look_at(centre)
						_floor.position = Vector3(0, -3.0, 0)
						await RenderingServer.frame_post_draw
						await RenderingServer.frame_post_draw
						tiles.append(get_viewport().get_texture().get_image())
					a.time_scale = 1.0
					b.set("time_scale", 1.0)
					await get_tree().process_frame
				t += 1.0 / 30.0
			var w: int = tiles[0].get_width()
			var h: int = tiles[0].get_height()
			var sheet := Image.create(w * 4, h * 2, false, Image.FORMAT_RGB8)
			for i in tiles.size():
				(tiles[i] as Image).convert(Image.FORMAT_RGB8)
				sheet.blit_rect(tiles[i], Rect2i(0, 0, w, h), Vector2i((i / 2) * w, (i % 2) * h))
			sheet.save_png("%s/versus_%s__%s_%s%s.png" % [_out, str(_args.versus), "knight_cuts" if who == 0 else "foe_cuts", d, "_nobite" if _args.has("nobite") else ""])
	get_tree().quit()

## The Witness relic on its own, as the rig places it (0.4 m tall, no turn), from -Z, +X, +Z and above,
## with a red ball 5 cm out along +Z so the mask's real front can be told.
func _relic_sheet() -> void:
	var r := PropModel.scenery(self, "res://assets/models/witness_relic.glb", 0.4, Vector3.ZERO, 0.0)
	var mark := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.01
	sm.height = 0.02
	mark.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(1, 0, 0)
	mark.material_override = mm
	mark.position = Vector3(0, 0.2, 0.15)
	add_child(mark)
	if _args.has("eyes"):
		var e: PackedStringArray = str(_args.eyes).split(",")
		for sx: float in [-1.0, 1.0]:
			var m2 := MeshInstance3D.new()
			m2.mesh = sm
			var gm := StandardMaterial3D.new()
			gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			gm.albedo_color = Color(0, 1, 0)
			m2.material_override = gm
			m2.position = Vector3(sx * float(e[0]), float(e[1]), float(e[2]))
			add_child(m2)
	_floor.visible = false
	var tiles: Array = []
	for v: Vector3 in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0.001)]:
		cam.size = 0.6
		cam.position = Vector3(0, 0.2, 0) + v.normalized() * 5.0
		cam.look_at(Vector3(0, 0.2, 0))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		tiles.append(get_viewport().get_texture().get_image())
	var w: int = tiles[0].get_width()
	var h: int = tiles[0].get_height()
	var sheet := Image.create(w * 4, h, false, Image.FORMAT_RGB8)
	for i in 4:
		(tiles[i] as Image).convert(Image.FORMAT_RGB8)
		sheet.blit_rect(tiles[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	sheet.save_png("%s/relic.png" % _out)
	print("relic ", r)
	get_tree().quit()

## The Witness drone against the knight's own motion (works with --headless): every cut, a block, a sidestep and a
## roll are played, and each frame the drone's centre is measured against the blade (hand to tip), the shield and
## the body's axis. Prints the least distance of each per state; `!!` under 0.16 m (the halo's radius plus a margin).
func _drone_check() -> void:
	_look["witness"] = true
	_fresh()
	var r: FighterRig = rig
	var d: WitnessDrone = r.drone
	if d == null:
		print("dronecheck: no drone on this look")
		get_tree().quit()
		return
	var acts: Array = [["guard", func(): r.guard(), 1.5]]
	for k: String in DIRS:
		acts.append(["cut_" + k, func(): r.swing(DIRS[k], 0.3), 1.0])
	acts.append(["block", func(): r.blocking = true, 1.2])
	acts.append(["dodge_r", func(): r.dodge(1.0), 0.9])
	acts.append(["roll_r", func(): r.roll(1.0), 1.1])
	acts.append(["roll_l", func(): r.roll(-1.0), 1.1])
	acts.append(["hurt", func(): r.hurt(), 0.9])
	var worst := 9.0
	for a: Array in acts:
		r.blocking = false
		r.guard()
		for i in 20:
			await get_tree().process_frame
		(a[1] as Callable).call()
		var lo := [9.0, 9.0, 9.0]
		var far := 0.0
		var t := 0.0
		while t < float(a[2]):
			await get_tree().process_frame
			t += get_process_delta_time()
			var p := d.global_position
			lo[0] = minf(lo[0], p.distance_to(Geometry3D.get_closest_point_to_segment(p, r.weapon_r.global_position, r.blade_tip())))
			if r.shield != null and r.shield.is_visible_in_tree():
				lo[1] = minf(lo[1], p.distance_to(r.shield.global_position))
			lo[2] = minf(lo[2], Vector2(p.x - r.body.global_position.x, p.z - r.body.global_position.z).length() if p.y < 1.9 else 9.0)
			far = maxf(far, p.distance_to(r.global_transform * WitnessDrone.HOME))
		worst = minf(worst, minf(lo[0], minf(lo[1], lo[2])))
		print("  %-9s blade %.2f  shield %.2f  body %.2f  strayed %.2f%s" % [a[0], lo[0], lo[1], lo[2], far, "  !!" if minf(lo[0], minf(lo[1], lo[2])) < 0.16 else ""])
	print("dronecheck: least clearance %.2f m" % worst)
	get_tree().quit()

## The Witness drone, a row per variant: at the knight's shoulder (three-quarter view from the front), then alone
## from the front (-Z), the side (+X) and above. Written to <out>/drone[_<tag>].png.
func _drone_sheet() -> void:
	var names: PackedStringArray = str(_args.drone).split(",", false)
	if names.size() == 0 or names[0] == "1":
		names = PackedStringArray(["plumb", "reed", "lens"])
	_look["witness"] = false
	_fresh()
	if rig is FighterRig:
		rig.guard()
	var rows: Array = []
	for v: String in names:
		var d := WitnessDrone.new()
		add_child(d)
		d.build(v)
		d.attach(rig)
		if _args.has("attend"):
			d.look_at_point(Vector3(0.3, 1.6, -3.0))
		if _args.has("speak"):
			d.speaking(true)
		if _args.has("dark"):
			d.stowed(true)
			d.rig = null
			d.global_position = rig.global_transform * WitnessDrone.HOME
		for i in 50:
			await get_tree().process_frame
		var at := d.global_position
		var tiles: Array = []
		var shots := [[Vector3(-0.55, 0.12, -1.0), Vector3(0.15, 1.1, 0), 2.3], [Vector3(0, 0, -1), at, 0.24], [Vector3(1, 0, 0), at, 0.24], [Vector3(0, 1, -0.001), at, 0.24]]
		for sh: Array in shots:
			rig.visible = sh[2] > 1.0
			_floor.visible = sh[2] > 1.0
			cam.size = sh[2]
			cam.position = (sh[1] as Vector3) + (sh[0] as Vector3).normalized() * (5.0 if sh[2] > 1.0 else 2.0)      # close shots inside the detail model's range
			cam.look_at(sh[1])
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			tiles.append(img)
		rows.append(tiles)
		rig.visible = true
		d.free()
	var w: int = rows[0][0].get_width()
	var h: int = rows[0][0].get_height()
	var sheet := Image.create(w * 4, h * rows.size(), false, Image.FORMAT_RGB8)
	for r in rows.size():
		for i in 4:
			sheet.blit_rect(rows[r][i], Rect2i(0, 0, w, h), Vector2i(i * w, r * h))
	sheet.save_png("%s/drone%s.png" % [_out, ("_" + str(_args.tag)) if _args.has("tag") else ""])
	print("drone sheet ", names)
	get_tree().quit()

func _room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.38, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.87, 0.9)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.3
	add_child(sun)
	# floor: a translucent slab below y = 0, seen edge-on, so anything under the floor shows dimmed below a crisp line
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(0.1, 0.12, 0.16, 0.62)
	var bm := BoxMesh.new()
	bm.size = Vector3(44, 6, 44)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = bm
	floor_mi.material_override = fm
	floor_mi.position.y = -3.0
	add_child(floor_mi)
	_floor = floor_mi
	# metre marks on the floor
	for i in range(-6, 7):
		for axis in 2:
			var lm := BoxMesh.new()
			lm.size = Vector3(0.012, 0.004, 44.0) if axis == 0 else Vector3(44.0, 0.004, 0.012)
			var l := MeshInstance3D.new()
			l.mesh = lm
			var m2 := StandardMaterial3D.new()
			m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m2.albedo_color = Color(0.95, 0.85, 0.3)
			l.material_override = m2
			l.position = Vector3(i, 0.0, 0) if axis == 0 else Vector3(0, 0.0, i)
			add_child(l)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1
	cam.far = 80.0
	add_child(cam)
	cam.make_current()

func _make_look() -> void:
	Game.save_dir_override = "user://pose_review_tmp"
	Game.profile = Game.default_profile()
	Game.profile.body = str(_args.get("body", "m"))
	if _args.has("witness"):
		Game.profile.flags["witness_found"] = true
	for id in str(_args.get("gear", "")).split(",", false):
		if not Game.owns(id):
			Game.profile.inventory.append(id)
		Game.equip(id)
	if _args.has("foe"):
		var foe_id := str(_args.foe)
		var foe: Dictionary = Db.foes[foe_id]
		_is_dragon = str(foe.rig.get("kind", "")) == "dragon"
		_as_foe = true
		_look = foe.rig.duplicate()
		for candidate in ["res://assets/models/%s.glb" % foe_id, "res://assets/models/cls_%s.glb" % str(foe.get("cls", "")).to_lower().replace("-", "_")]:
			if ResourceLoader.exists(candidate) and not _is_dragon:
				_look["skin"] = candidate
				break
		var carried: String = Duel.BOSS_WEAPON.get(foe_id, Duel.FOE_WEAPON.get(str(foe.rig.get("weapon", "")), ""))
		if carried != "":
			_look.merge(Duel.weapon_model(carried))
		_tag = foe_id
	else:
		# --wear=helm:frost,chest:black,arms:regal,...  armour by suit (items a_<suit>_<slot>; "worn" is the starting plate)
		for kv: String in str(_args.get("wear", "")).split(",", false):
			var slot := kv.get_slice(":", 0)
			var wid := "a_%s_%s" % [kv.get_slice(":", 1), "gauntlets" if slot == "arms" else slot]
			if not Db.item(wid).is_empty():
				if not Game.owns(wid):
					Game.profile.inventory.append(wid)
				Game.profile.equipped[str(Db.item(wid).slot)] = wid
		for id2: String in str(_args.get("unequip", "")).split(",", false):
			Game.profile.equipped[id2] = null
		# --forge=blade:5,grip:3,ore:2,ore_id:m_scale,edge:3   the equipped weapon's forge state (Game.weapon_mods)
		if _args.has("forge"):
			var wid2 := str(Game.profile.equipped.weapon)
			var mods := {}
			for kv2: String in str(_args.forge).split(",", false):
				var k2 := kv2.get_slice(":", 0)
				var v2 := kv2.get_slice(":", 1)
				if k2 == "blade":
					Game.profile.upgrades[wid2] = int(v2)
				elif k2 == "edge":
					Game.profile.edge[wid2] = int(v2)
				elif k2 == "ore_id":
					mods[k2] = v2
				else:
					mods[k2] = int(v2)
			Game.profile.mods[wid2] = mods
		_look = Duel.player_look()
		_tag = "knight_" + str(Game.profile.body)
		if _args.has("gear"):
			_tag += "_" + str(_args.gear).replace(",", "+")
	if _args.has("model"):
		_look["skin"] = "res://assets/models/%s.glb" % str(_args.model)
		_tag = str(_args.model) + ("" if not _args.has("gear") else "_" + str(_args.gear).replace(",", "+"))
	if _args.has("witness"):
		_tag += "_witness"
	if _args.has("tag"):
		_tag = str(_args.tag)
	if _args.has("noskin"):
		_look.erase("skin")

func _fresh() -> void:
	if rig:
		rig.free()
	rig = DragonRig.new() if _is_dragon else FighterRig.new()
	add_child(rig)
	rig.call("build", _look, _as_foe)
	_vel = Vector3.ZERO
	if not _is_dragon:
		rig.walking = true
		rig.combat_steps = true
	_collect()

# ---------------------------------------------------------------- states
func _poses() -> Array:
	var p: Array = []
	if _is_dragon:
		p.append(["guard", func(): pass, 1.2, [1.0]])
		p.append(["walk", func(): _vel = Vector3(0.9, 0, -0.5), 1.6, [0.8, 1.2]])
		for d: String in ["R", "L", "D"]:
			p.append(["slash_" + d, func(): rig.telegraph(DIRS[d], 0.9, 0.35, "slash"), 1.5, [0.6, 0.9, 1.05]])
		p.append(["bite", func(): rig.telegraph(DIRS["D"], 0.9, 0.35, "bite"), 1.5, [0.6, 0.95, 1.1]])
		p.append(["claw_R", func(): rig.telegraph(DIRS["R"], 0.9, 0.35, "sweep"), 1.5, [0.6, 0.9, 1.05]])
		p.append(["claw_L", func(): rig.telegraph(DIRS["L"], 0.9, 0.35, "sweep"), 1.5, [0.6, 0.9, 1.05]])
		p.append(["breath", func(): rig.telegraph(DIRS["R"], 0.9, 0.6, "breath"), 1.8, [0.6, 1.0, 1.3]])
		p.append(["recover", func(): rig.recover(), 1.2, [1.0]])
		p.append(["stagger", func(): rig.stagger(), 1.2, [1.0]])
		p.append(["roar", func(): rig.roar(), 2.0, [0.6, 1.1]])
		p.append(["far", func(): rig.set_far(true), 2.5, [1.0, 2.2]])
		p.append(["die", func(): rig.die(), 3.0, [0.8, 1.6, 2.8]])
		return p
	if _args.has("clip"):
		# one authored clip at full weight on the whole body, four moments through it
		var cn := str(_args.clip)
		var cl := SkinDriver.clip_length(cn)
		return [["clip_" + cn, func(): rig.combat_steps = false; rig.walking = false; rig.set("_clock", 0.0); rig.test_clip = cn, cl, [cl * 0.2, cl * 0.45, cl * 0.7, cl * 0.95]]]
	var sw := float(_args.get("swing", "0.55"))
	p.append(["guard", func(): pass, 1.4, [1.2]])
	p.append(["block", func(): rig.blocking = true, 1.0, [0.8]])
	p.append(["step_side", func(): _vel = Vector3(0.9, 0, 0), 1.3, [0.6, 0.85, 1.1]])
	p.append(["step_back", func(): _vel = Vector3(0, 0, 0.9), 1.3, [0.6, 0.85, 1.1]])
	p.append(["walk", func(): rig.combat_steps = false; _vel = Vector3(0, 0, -1.4), 2.2, [1.2, 1.45, 1.7, 1.95]])
	if _as_foe:
		for d: String in DIRS:
			p.append(["tel_" + d, func(): rig.telegraph(DIRS[d], 0.8, 0.3, "slash"), 1.5, [0.55, 0.8, 0.95], {"dir": DIRS[d], "hit": 0.8, "from": 0.65}])
		p.append(["thrust", func(): rig.telegraph(DIRS["D"], 0.8, 0.3, "thrust"), 1.5, [0.55, 0.85, 1.0]])
		p.append(["halt", func(): rig.telegraph(DIRS["R"], 0.5, 0.3, "slash"); _later(0.5, func(): rig.halt(0.3)), 1.0, [0.52, 0.7]])
		p.append(["roar", func(): rig.roar(), 2.0, [0.6, 1.1]])
	else:
		for d: String in DIRS:
			p.append(["cut_" + d, func(): rig.swing(DIRS[d], sw), 0.55 + sw, [sw * 0.3, sw * 0.6, sw * 0.6 + 0.12], {"dir": DIRS[d], "hit": sw * 0.6, "from": 0.0}])
		for f: String in ["Heavy", "Guard-breaking", "Counter", "Critical"]:
			p.append(["fin_" + f, func(): rig.swing(DIRS["R"], 0.7, f), 1.3, [0.36, 0.6, 0.84]])
		p.append(["parry", func(): rig.parry(DIRS["L"]), 0.6, [0.08, 0.2]])
		p.append(["clash", func(): rig.clash(rig.global_transform * Vector3(0.1, 1.5, -0.8), 0.3), 0.5, [0.1]])
		p.append(["brace", func(): rig.blocking = true; _later(0.4, func(): rig.brace(rig.global_transform * Vector3(-0.1, 1.3, -0.7), 0.3)), 0.9, [0.45, 0.7]])
		p.append(["dodge_r", func(): rig.dodge(1.0), 0.7, [0.15, 0.3, 0.45]])
		p.append(["dodge_l", func(): rig.dodge(-1.0), 0.7, [0.15, 0.3, 0.45]])
		p.append(["roll_r", func(): rig.roll(1.0), 1.0, [0.2, 0.42, 0.64]])
		p.append(["roll_l", func(): rig.roll(-1.0), 1.0, [0.2, 0.42, 0.64]])
	if only_has("sheath") or only_has("draw") or only_has("preview_attack") or only_has("preview_block"):
		p.append(["sheath", func(): rig.sheath(), 1.3, [0.15, 0.36, 0.5, 0.7, 1.1]])
		p.append(["draw", func(): rig.sheath(true); _later(0.3, func(): rig.draw()), 1.5, [0.25, 0.5, 0.66, 0.8, 1.0, 1.3]])
		p.append(["preview_attack", func(): rig.preview_attack("DR"), 1.2, [0.12, 0.3, 0.45, 0.9]])
		p.append(["preview_block", func(): rig.preview_block(0.6), 1.2, [0.3, 0.55, 1.1]])
	if only_has("recall") or only_has("recall_short") or only_has("present"):
		# the weapon coming to the hand: Recall (hand open, hilt first, hand closes), and whatever present_weapon picks
		p.append(["recall", func(): rig.weapon_r.visible = false; _later(0.2, func(): rig.present_weapon("recall")), 1.5, [0.22, 0.4, 0.55, 0.7, 0.9, 1.3]])
		p.append(["recall_short", func(): rig.weapon_r.visible = false; _later(0.2, func(): rig.present_weapon("recall_short")), 1.0, [0.22, 0.35, 0.5, 0.75]])
		p.append(["present", func(): rig.present_weapon("auto", {}), 1.5, [0.1, 0.35, 0.55, 0.75, 1.0, 1.4]])
	p.append(["recover", func(): rig.recover(), 1.2, [1.0]])
	p.append(["stagger", func(): rig.stagger(), 1.4, [0.5, 1.2]])
	p.append(["hurt", func(): rig.hurt(), 0.6, [0.1, 0.25]])
	p.append(["die_a", func(): rig.die(1.0), 3.2, [0.5, 1.0, 1.6, 3.0]])
	p.append(["die_b", func(): rig.die(-1.0), 3.2, [1.0, 3.0]])
	return p

func only_has(n: String) -> bool:
	return str(_args.get("poses", "")).split(",", false).has(n)

var _timers: Array = []
func _later(t: float, f: Callable) -> void:
	_timers.append([t, f])

func _run() -> void:
	var only: PackedStringArray = str(_args.get("poses", "")).split(",", false)
	var shots := not _args.has("noshots")
	print("== pose review: %s%s" % [_tag, " (foe)" if _as_foe else ""])
	for pose: Array in _poses():
		if not only.is_empty() and not only.has(str(pose[0])):
			continue
		_fresh()
		# settle into guard first, as in a fight
		for i in 12:
			await get_tree().process_frame
		_timers.clear()
		_cur = pose[4] if pose.size() > 4 else {}
		_track.clear()
		_track.append([0.0, _tip_local(), 0.0])
		(pose[1] as Callable).call()
		var t := 0.0
		var todo: Array = (pose[3] as Array).duplicate()
		if _args.has("t"):
			todo.clear()
			for ts: String in str(_args.t).split(",", false):
				todo.append(float(ts))
		var tiles: Array = []
		var stat := {}
		while t < float(pose[2]):
			await get_tree().process_frame      # the rig solved the previous frame; measure that, then move on
			if t > 0.0:
				_audit(stat, t)
			if shots and not todo.is_empty() and t + 1.0 / float(_args.get("fps", "30")) >= float(todo[0]) - 0.001:
				todo.pop_front()
				rig.time_scale = 0.0
				for v: Array in VIEWS:
					_aim_cam(v[1])
					await RenderingServer.frame_post_draw
					await RenderingServer.frame_post_draw
					tiles.append(get_viewport().get_texture().get_image())
				rig.time_scale = 1.0
				await get_tree().process_frame
			var dt := 1.0 / float(_args.get("fps", "30"))
			t += dt
			rig.position += _vel * dt * rig.scale.x
			for tm: Array in _timers.duplicate():
				if t >= float(tm[0]):
					_timers.erase(tm)
					(tm[1] as Callable).call()
		_motion(stat)
		_report(str(pose[0]), stat)
		if shots and not tiles.is_empty():
			var w: int = tiles[0].get_width()
			var h: int = tiles[0].get_height()
			var sheet := Image.create(w * 3, h * (tiles.size() / 3), false, Image.FORMAT_RGB8)
			for i in tiles.size():
				var im: Image = tiles[i]
				im.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % 3) * w, (i / 3) * h))
			sheet.save_png("%s/%s__%s.png" % [_out, _tag, pose[0]])
	get_tree().quit()

func _aim_cam(dir: Vector3) -> void:
	var s: float = rig.scale.x
	var centre: Vector3 = Vector3(_mid.x, 0, _mid.z) + Vector3(0, (1.6 if _is_dragon else 0.95) * s, 0)
	if _args.has("aim"):
		var a: PackedStringArray = str(_args.aim).split(",")
		centre = Vector3(_mid.x, 0, _mid.z) + Vector3(float(a[0]), float(a[1]), float(a[2])) * s
	cam.size = (9.5 if _is_dragon else 2.75) * s / _zoom
	cam.position = centre + dir * 30.0
	cam.look_at(centre)
	_floor.position = Vector3(centre.x, -3.0, centre.z)

# ---------------------------------------------------------------- measurement
func _collect() -> void:
	_parts.clear()
	_dom_names.clear()
	for mi: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.mesh == null or not mi.visible or mi.name == "part_under":
			continue          # (what is drawn: the worn armour parts, not the body hidden under them)
		var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if skel == null:
			continue
		var binds: Array = []
		for b in mi.skin.get_bind_count():
			var bi := mi.skin.get_bind_bone(b)
			if bi < 0:
				bi = skel.find_bone(mi.skin.get_bind_name(b))
			binds.append([bi, mi.skin.get_bind_pose(b)])
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			if bones == null or pos.is_empty():
				continue
			var nb: int = bones.size() / pos.size()
			var step: int = maxi(1, pos.size() / (5000 / (6 if mi.name.begins_with("part_") else 1)))      # (six parts are sampled as densely as one suit)
			var p2 := PackedVector3Array()
			var b2 := PackedInt32Array()
			var w2 := PackedFloat32Array()
			var dom := PackedInt32Array()
			for i in range(0, pos.size(), step):
				p2.append(pos[i])
				var best := 0
				for k in nb:
					b2.append(int(bones[i * nb + k]))
					w2.append(float(weights[i * nb + k]))
					if float(weights[i * nb + k]) > float(weights[i * nb + best]):
						best = k
				dom.append(int(binds[int(bones[i * nb + best])][0]))
			_parts.append({"mi": mi, "skel": skel, "pos": p2, "bones": b2, "weights": w2, "nb": nb, "dom": dom, "binds": binds})

func _short(skel: Skeleton3D, i: int) -> String:
	var n := skel.get_bone_name(i)
	return n.get_slice(":", n.get_slice_count(":") - 1).trim_prefix("mixamorig_").trim_prefix("mixamorig")

## World positions of the sampled skinned vertices, with the name of the bone that mostly carries each.
func _skinned() -> Array:
	var out_p := PackedVector3Array()
	var out_n: Array = []
	for part: Dictionary in _parts:
		var skel: Skeleton3D = part.skel
		var mats: Array = []
		var g: Transform3D = skel.global_transform
		for b: Array in part.binds:
			mats.append(g * skel.get_bone_global_pose(int(b[0])) * (b[1] as Transform3D))
		var nb: int = part.nb
		var pos: PackedVector3Array = part.pos
		var bones: PackedInt32Array = part.bones
		var weights: PackedFloat32Array = part.weights
		for i in pos.size():
			var v := Vector3.ZERO
			var wsum := 0.0
			for k in nb:
				var w := weights[i * nb + k]
				if w > 0.0:
					v += (mats[bones[i * nb + k]] as Transform3D * pos[i]) * w
					wsum += w
			out_p.append(v / maxf(wsum, 0.0001))
			out_n.append(_short(skel, part.dom[i]))
	return [out_p, out_n]

func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * u)

func _worse(stat: Dictionary, key: String, v: float, t: float, note: String = "", lower: bool = true) -> void:
	if not stat.has(key) or (v < float(stat[key][0]) if lower else v > float(stat[key][0])):
		stat[key] = [v, t, note]

var _cur := {}                # the state being played, if it is a cut: {dir, hit, from}
var _track: Array = []        # [t, blade tip in the rig's own space, chest yaw] per frame

func _tip_local() -> Vector3:
	if _is_dragon:
		return Vector3.ZERO
	return rig.global_transform.affine_inverse() * (rig as FighterRig).blade_tip()

## What the cut did, from the blade tip's path on this rig: `delay` seconds from the swipe to the tip having moved 3 cm,
## `dir_err` degrees between the tip's travel across the hit instant and the swipe (as seen from behind the fighter),
## `yaw` the furthest the chest turned from facing the opponent (degrees), `tipz` how far ahead the tip is at the hit.
func _motion(stat: Dictionary) -> void:
	if _cur.is_empty() or _track.size() < 4:
		return
	var p0: Vector3 = _track[0][1]
	for e: Array in _track:
		if (e[1] as Vector3).distance_to(p0) >= 0.03:
			stat["delay"] = [float(e[0]), 0.0, ""]
			break
	var hit: float = float(_cur.hit)
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var got := 0
	var yaw := 0.0
	for e: Array in _track:
		var t: float = e[0]
		if t >= float(_cur.from) and t <= hit + 0.25:
			yaw = maxf(yaw, absf(float(e[2])))
		if got == 0 and t >= hit - 0.07:
			a = e[1]
			got = 1
		if t <= hit + 0.035:
			b = e[1]
			if absf(t - hit) < 0.02:
				stat["tipz"] = [-(e[1] as Vector3).z, t, ""]
	var v := Vector2(b.x - a.x, b.y - a.y)
	var want: Vector2 = _cur.dir
	want.x *= (rig as FighterRig).mirror
	if v.length() > 0.02:
		stat["dir_err"] = [rad_to_deg(v.angle_to(want)), hit, ""]
	stat["yaw"] = [rad_to_deg(yaw), 0.0, ""]

func _audit(stat: Dictionary, t: float) -> void:
	var s: float = rig.scale.x
	if not _is_dragon and (rig as FighterRig).skin:
		var f: Vector3 = (rig as FighterRig).skin.turn("Spine2") * Vector3(0, 0, -1)
		# (the rig has already taken the step that ends at t + one frame)
		_track.append([t + 1.0 / float(_args.get("fps", "30")), _tip_local(), atan2(f.x, -f.z)])
	if _args.has("motiononly"):
		return      # only the blade's path (fast enough to run at 120 frames a second)
	var sk: Array = _skinned()
	var pts: PackedVector3Array = sk[0]
	var names: Array = sk[1]
	var lo := 1e9
	var lo_n := ""
	var b_lo := Vector3.ONE * 1e9
	var b_hi := Vector3.ONE * -1e9
	for i in pts.size():
		b_lo = b_lo.min(pts[i])
		b_hi = b_hi.max(pts[i])
		if pts[i].y < lo:
			lo = pts[i].y
			lo_n = names[i]
	_mid = (b_lo + b_hi) * 0.5 if not pts.is_empty() else rig.global_position
	if not pts.is_empty():
		_worse(stat, "low", lo / s, t, lo_n)
		_worse(stat, "float", lo / s, t, lo_n, false)
	if _is_dragon:
		return
	var fr: FighterRig = rig
	# blade against the wielder's own body
	for wn: Array in [[fr.weapon_r, ["RightHand", "RightForeArm"]], [fr.weapon_l, ["LeftHand", "LeftForeArm"]]]:
		var w: Node3D = wn[0]
		if w.get_child_count() == 0:
			continue
		var gt := w.global_transform
		var a := gt * Vector3(0, fr.weapon_len * 0.14, 0)
		var b := gt * Vector3(0, fr.weapon_len, 0)
		var hits := {}
		var n := 0
		for i in pts.size():
			var nm: String = names[i]
			if nm.begins_with("RightHand") or nm.begins_with("LeftHand") or wn[1].has(nm):
				continue
			if fr.two_handed and (nm == "LeftForeArm" or nm == "RightForeArm"):
				continue
			if _seg_dist(pts[i], a, b) < 0.035 * s:
				n += 1
				hits[nm] = int(hits.get(nm, 0)) + 1
		_worse(stat, "blade" if w == fr.weapon_r else "blade_l", float(n), t, str(hits), false)
		_worse(stat, "tip", minf(b.y, (gt * Vector3(0, -fr.weapon_len * 0.12, 0)).y) / s, t)
	if fr.shield:
		# the board itself (a hand-modelled shield's origin is its grip bar; the board stands off it), at its real size
		var st := Transform3D(fr.shield.global_transform.basis, fr.shield.global_transform * fr._sh_c)
		var inv := st.affine_inverse()
		var ex: float = fr._sh_hw * fr._sh_hw * 0.82
		var ey: float = fr._sh_hh * fr._sh_hh * 0.78
		# the hand that holds it: skinned hand and finger vertices on the FACE side of the board (through the wood)
		var thru := 0
		for i in pts.size():
			if names[i].begins_with("LeftHand"):
				var lf := inv * pts[i]
				if lf.z < -0.012 and lf.x * lf.x / ex + lf.y * lf.y / ey < 1.0:
					thru += 1
		_worse(stat, "fingers", float(thru), t, "", false)
		var n2 := 0
		var hits2 := {}
		for i in pts.size():
			var nm2: String = names[i]
			if nm2.begins_with("Left") or nm2.begins_with("RightHand") or nm2 == "RightForeArm":
				continue
			var l := inv * pts[i]
			if absf(l.z) < 0.03 and l.x * l.x / ex + l.y * l.y / ey < 1.0:
				n2 += 1
				hits2[nm2] = int(hits2.get(nm2, 0)) + 1
		_worse(stat, "shield", float(n2), t, str(hits2), false)
		# the blade through the shield board: how much of its length lies inside the board
		var wt2 := fr.weapon_r.global_transform
		var inside := 0
		for i in 21:
			var bp2 := inv * (wt2 * Vector3(0, fr.weapon_len * (0.15 + 0.85 * i / 20.0), 0))
			if absf(bp2.z) < 0.025 and bp2.x * bp2.x / (ex * 1.13) + bp2.y * bp2.y / (ey * 1.15) < 1.0:
				inside += 1
		_worse(stat, "bshield", float(inside), t, "", false)
		var rim := 1e9
		for c: Vector3 in [Vector3(1, 1, 0), Vector3(-1, 1, 0), Vector3(1, -1, 0), Vector3(-1, -1, 0), Vector3(0, -1, 0)]:
			rim = minf(rim, (st * Vector3(c.x * fr._sh_hw, c.y * fr._sh_hh, 0)).y)
		_worse(stat, "rim", rim / s, t)
	if fr.skin:
		var d: SkinDriver = fr.skin
		var g := d.skel.global_transform
		var bp := func(n3: String) -> Vector3: return g * d.skel.get_bone_global_pose(d.bone[n3]).origin
		for side: String in ["Left", "Right"]:
			var hip: Vector3 = bp.call(side + "UpLeg")
			var knee: Vector3 = bp.call(side + "Leg")
			var ank: Vector3 = bp.call(side + "Foot")
			var ka := rad_to_deg((hip - knee).angle_to(ank - knee))
			_worse(stat, "knee_min", ka, t, side)
			# a knee that sits behind the hip-ankle line, seen along the pelvis' forward, bends the wrong way
			var fwd: Vector3 = (g.basis * d.skel.get_bone_global_pose(d.bone["Hips"]).basis * d.rest["Hips"].basis.inverse() * (d.rest["LeftToeBase"].origin - d.rest["LeftFoot"].origin if d.bone.has("LeftToeBase") else Vector3(0, 0, 1)))
			fwd.y = 0.0
			var mid := hip.lerp(ank, (knee - hip).dot(ank - hip) / maxf((ank - hip).length_squared(), 0.0001))
			if ka < 165.0:
				_worse(stat, "knee_back", (knee - mid).dot(fwd.normalized()) / s, t, side)
			var sh: Vector3 = bp.call(side + "Arm")
			var el: Vector3 = bp.call(side + "ForeArm")
			var ha: Vector3 = bp.call(side + "Hand")
			_worse(stat, "elbow_min", rad_to_deg((sh - el).angle_to(ha - el)), t, side)
			_worse(stat, "ankle_low", (ank.y - g.origin.y) / s - d.rest[side + "Foot"].origin.y * d.root.scale.y * (d.root.global_transform.affine_inverse() * d.skel.global_transform).basis.get_scale().y / 1.0, t, side)
		if fr.two_handed:
			var lh: Vector3 = fr.weapon_l.global_position
			var wt := fr.weapon_r.global_transform
			_worse(stat, "offhand", _seg_dist(lh, wt * Vector3(0, -0.35, 0), wt * Vector3(0, 0.05, 0)) / s, t, "", false)

func _report(pose: String, stat: Dictionary) -> void:
	var out := "%-16s" % pose
	var flags := ""
	for k: String in ["low", "float", "tip", "rim", "blade", "blade_l", "shield", "bshield", "fingers", "knee_min", "knee_back", "elbow_min", "ankle_low", "offhand", "delay", "dir_err", "yaw", "tipz"]:
		if not stat.has(k):
			continue
		var e: Array = stat[k]
		var v: float = e[0]
		var bad := false
		match k:
			"low": bad = v < -0.02
			"float": bad = v > 0.06 and not pose.begins_with("roll") and not pose == "far"
			"tip": bad = v < -0.01
			"rim": bad = v < -0.01
			"blade", "blade_l": bad = v >= 3.0
			"shield": bad = v >= 3.0
			"bshield": bad = v >= 1.0
			"fingers": bad = v >= 1.0
			"knee_min": bad = v < 35.0
			"knee_back": bad = v < -0.03
			"elbow_min": bad = v < 25.0
			"ankle_low": bad = v < -0.03
			"offhand": bad = v > 0.06
			"delay": bad = v > 0.085
			"dir_err": bad = absf(v) > 25.0
			"yaw": bad = v > 75.0
		out += " %s%s=%.2f@%.2f%s" % ["!!" if bad else "", k, v, float(e[1]), ("(" + str(e[2]) + ")") if str(e[2]) != "" and (bad or k == "low") else ""]
		if bad:
			flags += k + " "
	print(out)
