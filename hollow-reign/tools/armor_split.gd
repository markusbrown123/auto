extends SceneTree
## Offline: turns the full-body knight suits into equipment parts on ONE shared body per sex (docs/MODULAR_ARMOR.md).
##   1. conform  every suit's mesh is re-fitted to the base knight's skeleton (knight_m / knight_f): each bone's share of
##               the mesh is moved so that its joint sits on the base joint, turned to the base limb's direction and
##               stretched along the limb to the base limb's length. After this every suit uses the base Skin as it is.
##   2. de-spike optional (--despike=suit,suit or "all"): thin protrusions are pulled back toward the limb they stand on.
##   3. split    six parts by skin weight (helm, chest, shoulders, arms, legs, boots), cut along the line where the
##               part's weight equals its neighbour's (triangles are cut, not just sorted), with an overlap band.
## Writes assets/models/parts/<body>_<suit>_<slot>.res (ArrayMesh, no material), <body>_<suit>_mat.res (material)
## and <body>_under.res (the base body without its helmet: a dark undersuit shown under mixed parts).
## Run:  Godot --headless --path . -s tools/armor_split.gd -- [--only=m_frost,f_ash] [--margin=0.22] [--out=dir] [--despike=all] [--tag=_ds]
const SUITS := ["crownless", "base", "garrison", "ash", "black", "vigil", "frost", "regal", "wyrm", "hollow"]
## The suit whose skeleton and body every other suit is fitted to (--host=base restores the first study's choice).
## "crownless" is the sleek benchmark knight (knight_<body>_v3.glb): flat boots, compact visored helm, undersuit gaps.
var host_suit := "crownless"
const SLOTS := ["helm", "chest", "shoulders", "arms", "legs", "boots"]
const CHILD := {"Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head",
	"LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand",
	"LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "RightUpLeg": "RightLeg", "RightLeg": "RightFoot"}

var args := {}
var out_dir := "res://assets/models/parts/"

static func short(n: String) -> String:
	return n.get_slice(":", n.get_slice_count(":") - 1).trim_prefix("mixamorig_").trim_prefix("mixamorig")

static func region(b: String) -> int:
	if b in ["Head", "HeadTop_End", "Neck"]:
		return 0
	if b.contains("ForeArm") or b.contains("Hand"):
		return 3
	if b.ends_with("Shoulder") or b.ends_with("Arm"):
		return 2
	if b.begins_with("Spine"):
		return 1
	if b.contains("Foot") or b.contains("Toe"):
		return 5
	return 4          # Hips, UpLeg, Leg

## The bone whose fit a bone's vertices follow: a hand, a foot and a head move as one piece.
static func driver(b: String) -> String:
	for side: String in ["Left", "Right"]:
		if b.begins_with(side + "Hand"):
			return side + "Hand"
		if b.begins_with(side + "Toe"):
			return side + "Foot"
	return "Head" if b == "HeadTop_End" else b

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out_dir = str(args.get("out", out_dir))
	host_suit = str(args.get("host", host_suit))
	if not out_dir.ends_with("/"):
		out_dir += "/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var only: PackedStringArray = str(args.get("only", "")).split(",", false)
	var spike: PackedStringArray = str(args.get("despike", "")).split(",", false)
	var margin := float(args.get("margin", "0.22"))
	var tag := str(args.get("tag", ""))
	for body: String in ["m", "f"]:
		var host := _read(body, host_suit)
		var hull := {}
		for suit: String in SUITS:
			var id := "%s_%s" % [body, suit]
			var wanted := only.is_empty() or only.has(id)
			if not wanted and (tag != "" or args.has("nohull")):
				continue
			var t0 := Time.get_ticks_msec()
			var src := host if suit == host_suit else _read(body, suit)
			var m := _conform(src, host)
			if tag == "" and not args.has("nohull"):
				_hull_add(hull, m, host)
			if not wanted:
				continue
			var moved := 0
			if spike.has("all") or spike.has(id) or spike.has(suit):
				moved = _despike(m, host, float(args.get("spike_k", "1.0")))
			var total := 0
			var line := ""
			for r in SLOTS.size():
				var part := _part(m, r, margin)
				total += part.idx.size() / 3
				line += "%s %d  " % [SLOTS[r], part.idx.size() / 3]
				_save(part, "%s%s%s_%s.res" % [out_dir, id, tag, SLOTS[r]], id)
			if suit == host_suit and tag == "":
				# the Skin every part is bound with: the base skeleton's own rest pose, bone by name
				var sk := Skin.new()
				for i in (host.names as Array).size():
					sk.add_named_bind(host.full[i], (host.rest[host.names[i]] as Transform3D).affine_inverse())
				ResourceSaver.save(sk, "%s%s_skin.res" % [out_dir, body])
			if tag == "":
				_save_material(src, "%s%s_mat.res" % [out_dir, id])
			print("%s%s: %d tris in -> parts %d tris (%s) despiked verts=%d  %d ms" % [id, tag, m.idx.size() / 3, total, line, moved, Time.get_ticks_msec() - t0])
		if tag == "" and not args.has("nohull"):
			# the undersuit: the base body without head and hands, drawn in to lie inside every suit
			var u := _conform(host, host)
			var inside := _hull_apply(hull, u, host)
			var f := PackedFloat32Array()
			f.resize(u.pos.size())
			for v in u.pos.size():
				f[v] = -u.ex[v]
			var under := _clip(u, f, -0.5, PackedInt32Array())
			_save(under, "%s%s_under.res" % [out_dir, body], body + "_under")
			print("%s_under: %d tris, %d of %d vertices drawn in" % [body, under.idx.size() / 3, inside, u.pos.size()])
	quit()

# ---------------------------------------------------------------- reading
func _read(body: String, suit: String) -> Dictionary:
	var path := "res://assets/models/knight_%s%s.glb" % [body, "" if suit == "base" else ("_v3" if suit == "crownless" else "_" + suit)]
	var root: Node = (load(path) as PackedScene).instantiate()
	var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var d := {"rest": {}, "path": path}
	for i in skel.get_bone_count():
		d.rest[short(skel.get_bone_name(i))] = skel.get_bone_global_rest(i)
	var names: Array = []          # skin bind index -> short bone name
	var full: Array = []
	var fix: Array = []            # skin bind index -> rest * bind (identity when the mesh is stored in its rest pose)
	var dev := 0.0
	for b in mi.skin.get_bind_count():
		var bi := mi.skin.get_bind_bone(b)
		if bi < 0:
			bi = skel.find_bone(mi.skin.get_bind_name(b))
		names.append(short(skel.get_bone_name(bi)))
		full.append(skel.get_bone_name(bi))
		var x: Transform3D = skel.get_bone_global_rest(bi) * mi.skin.get_bind_pose(b)
		fix.append(x)
		dev = maxf(dev, x.origin.length() + (x.basis.x - Vector3.RIGHT).length() + (x.basis.y - Vector3.UP).length())
	d["names"] = names
	d["full"] = full
	d["fix"] = fix
	var arr := mi.mesh.surface_get_arrays(0)
	d["pos"] = arr[Mesh.ARRAY_VERTEX]
	d["nrm"] = arr[Mesh.ARRAY_NORMAL]
	d["tan"] = arr[Mesh.ARRAY_TANGENT]
	d["uv"] = arr[Mesh.ARRAY_TEX_UV]
	d["bones"] = arr[Mesh.ARRAY_BONES]
	d["weights"] = arr[Mesh.ARRAY_WEIGHTS]
	d["idx"] = arr[Mesh.ARRAY_INDEX]
	d["material"] = mi.mesh.surface_get_material(0)
	var toe: Vector3 = (d.rest["LeftToeBase"] as Transform3D).origin - (d.rest["LeftFoot"] as Transform3D).origin
	if args.has("v"):
		print("  read %s: bind deviates from rest by %.5f, toe direction %s" % [path.get_file(), dev, str(Vector3(toe.x, 0, toe.z).normalized().snapped(Vector3.ONE * 0.01))])
	root.free()
	return d

# ---------------------------------------------------------------- conform
## The affine map that carries what a donor bone holds onto the host's bone.
func _bone_map(b: String, s: Dictionary, h: Dictionary, k: float) -> Transform3D:
	var jd: Vector3 = (s.rest[b] as Transform3D).origin
	var jh: Vector3 = (h.rest[b] as Transform3D).origin
	var m := Basis.IDENTITY.scaled(Vector3.ONE * k)
	if CHILD.has(b):
		var cd: Vector3 = (s.rest[CHILD[b]] as Transform3D).origin - jd
		var ch: Vector3 = (h.rest[CHILD[b]] as Transform3D).origin - jh
		var dd := cd.normalized()
		var st := clampf(ch.length() / maxf(cd.length(), 0.0001), 0.8, 1.25)
		# k across the limb, `st` along it
		var sb := Basis(Vector3.RIGHT * k + dd * (st - k) * dd.x, Vector3.UP * k + dd * (st - k) * dd.y, Vector3.BACK * k + dd * (st - k) * dd.z)
		m = Basis(Quaternion(dd, ch.normalized())) * sb
	elif b.ends_with("Hand"):
		var fore := b.replace("Hand", "ForeArm")
		var dd2: Vector3 = (jd - (s.rest[fore] as Transform3D).origin).normalized()
		var dh2: Vector3 = (jh - (h.rest[fore] as Transform3D).origin).normalized()
		m = Basis(Quaternion(dd2, dh2)) * m
	elif b.ends_with("Foot"):
		# the sole stays on the floor: height is scaled so that the donor's floor is the host's floor
		var toe := b.replace("Foot", "ToeBase")
		var td: Vector3 = (s.rest[toe] as Transform3D).origin - jd
		var th: Vector3 = (h.rest[toe] as Transform3D).origin - jh
		var yaw := atan2(th.x, th.z) - atan2(td.x, td.z)
		m = Basis(Vector3.UP, yaw) * Basis.IDENTITY.scaled(Vector3(k, clampf(jh.y / maxf(jd.y, 0.0001), 0.7, 1.4), k))
	return Transform3D(m, jh - m * jd)

func _conform(s: Dictionary, h: Dictionary) -> Dictionary:
	var k: float = (h.rest["Neck"] as Transform3D).origin.y / (s.rest["Neck"] as Transform3D).origin.y
	var maps: Array = []
	var rots: Array = []
	var reg := PackedInt32Array()
	var remap := PackedInt32Array()       # donor bind index -> host bind index
	for i in (s.names as Array).size():
		var b: String = s.names[i]
		var mp := _bone_map(driver(b), s, h, k) if s != h else Transform3D.IDENTITY
		maps.append(mp * (s.fix[i] as Transform3D))
		rots.append(mp.basis.orthonormalized())
		reg.append(region(b))
		remap.append((h.names as Array).find(b))
	var n: int = (s.pos as PackedVector3Array).size()
	var o := {"pos": PackedVector3Array(), "nrm": PackedVector3Array(), "tan": PackedFloat32Array(), "uv": s.uv, "bones": PackedInt32Array(),
		"weights": s.weights, "idx": s.idx, "rw": PackedFloat32Array(), "top": PackedInt32Array(), "ex": PackedFloat32Array()}
	o.ex.resize(n)
	var excl := PackedInt32Array()
	for b2: String in s.names:
		excl.append(1 if (driver(b2) in ["Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot"]) else 0)
	o.pos.resize(n); o.nrm.resize(n); o.tan.resize(n * 4); o.bones.resize(n * 4); o.rw.resize(n * 6); o.top.resize(n)
	var sp: PackedVector3Array = s.pos
	var sn: PackedVector3Array = s.nrm
	var stn: PackedFloat32Array = s.tan
	var sb: PackedInt32Array = s.bones
	var sw: PackedFloat32Array = s.weights
	for v in n:
		var p := Vector3.ZERO
		var nn := Vector3.ZERO
		var tt := Vector3.ZERO
		var t0 := Vector3(stn[v * 4], stn[v * 4 + 1], stn[v * 4 + 2])
		var best := 0
		for j in 4:
			var w := sw[v * 4 + j]
			var bi := sb[v * 4 + j]
			o.bones[v * 4 + j] = remap[bi]
			if w <= 0.0:
				continue
			p += (maps[bi] as Transform3D) * sp[v] * w
			nn += (rots[bi] as Basis) * sn[v] * w
			tt += (rots[bi] as Basis) * t0 * w
			o.rw[v * 6 + reg[bi]] += w
			o.ex[v] += w * excl[bi]
			if w > sw[v * 4 + best]:
				best = j
		o.pos[v] = p
		o.nrm[v] = nn.normalized()
		tt = tt.normalized()
		o.tan[v * 4] = tt.x; o.tan[v * 4 + 1] = tt.y; o.tan[v * 4 + 2] = tt.z; o.tan[v * 4 + 3] = stn[v * 4 + 3]
		o.top[v] = remap[sb[v * 4 + best]]
	return o

# ---------------------------------------------------------------- inner hull (undersuit)
const HULL_BIN := 0.0125
const HULL_SECTORS := 12

## The cell a vertex lies in: its bone, how far along the bone, and which way round it. Returns [key, radius, foot point, radial unit].
func _cell(m: Dictionary, h: Dictionary, v: int) -> Array:
	var names: Array = h.names
	var b: String = driver(names[m.top[v]])
	var j: Vector3 = (h.rest[b] as Transform3D).origin
	var axis := Vector3.UP
	if CHILD.has(b):
		axis = ((h.rest[CHILD[b]] as Transform3D).origin - j).normalized()
	elif b.ends_with("Foot"):
		var toe: Vector3 = (h.rest[b.replace("Foot", "ToeBase")] as Transform3D).origin - j
		axis = Vector3(toe.x, 0, toe.z).normalized()
	var e1 := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.UP).normalized()
	var e2 := axis.cross(e1)
	var d: Vector3 = (m.pos[v] as Vector3) - j
	var along := d.dot(axis)
	var radial := d - axis * along
	var sector := int(floor((atan2(radial.dot(e2), radial.dot(e1)) + PI) / TAU * HULL_SECTORS)) % HULL_SECTORS
	return [Vector3i((names as Array).find(b), int(floor(along / HULL_BIN)), sector), radial.length(), j + axis * along, radial.normalized(), along, axis]

func _hull_add(hull: Dictionary, m: Dictionary, h: Dictionary) -> void:
	var cells := {}
	var span := {}
	for v in (m.pos as PackedVector3Array).size():
		var c := _cell(m, h, v)
		if not span.has(c[0].x):
			span[c[0].x] = []
		(span[c[0].x] as Array).append(c[4])
		if not cells.has(c[0]):
			cells[c[0]] = []
		(cells[c[0]] as Array).append(c[1])
	for key: Vector3i in cells:
		var rs: Array = cells[key]
		if rs.size() < 3:
			continue
		rs.sort()
		var r: float = rs[int(rs.size() * 0.35)]
		hull[key] = minf(float(hull.get(key, 1e9)), r)
	# how far along each bone this suit's share of the mesh reaches: the undersuit keeps to the shortest reach of all
	for bi: int in span:
		var a: Array = span[bi]
		a.sort()
		var lo_k := Vector3i(bi, 0, -1)
		var hi_k := Vector3i(bi, 0, -2)
		hull[lo_k] = maxf(float(hull.get(lo_k, -1e9)), float(a[int(a.size() * 0.03)]))
		hull[hi_k] = minf(float(hull.get(hi_k, 1e9)), float(a[int(a.size() * 0.97)]))

func _hull_apply(hull: Dictionary, m: Dictionary, h: Dictionary) -> int:
	var moved := 0
	for v in (m.pos as PackedVector3Array).size():
		var c := _cell(m, h, v)
		var key: Vector3i = c[0]
		var lo: float = hull.get(Vector3i(key.x, 0, -1), -1e9)
		var hi: float = hull.get(Vector3i(key.x, 0, -2), 1e9)
		if float(c[4]) < lo or float(c[4]) > hi:
			m.pos[v] += (c[5] as Vector3) * (clampf(float(c[4]), lo, hi) - float(c[4]))
			c = _cell(m, h, v)
			key = c[0]
		# the limit here and in the cells round it, so the surface does not step from cell to cell
		var lim := 0.0
		var cnt := 0.0
		for da: int in [-1, 0, 1]:
			for ds: int in [-1, 0, 1]:
				var k2 := Vector3i(key.x, key.y + da, (key.z + ds + HULL_SECTORS) % HULL_SECTORS)
				if hull.has(k2):
					var w := 2.0 if (da == 0 and ds == 0) else 1.0
					lim += float(hull[k2]) * w
					cnt += w
		if cnt == 0.0:
			continue
		lim = lim / cnt * 0.85
		if float(c[1]) > lim:
			m.pos[v] = (c[2] as Vector3) + (c[3] as Vector3) * lim
			moved += 1
	_renormal(m)
	return moved

# ---------------------------------------------------------------- de-spike
## Pulls thin protrusions back toward the body, without deleting anything (so there are no holes to cap).
##  - limbs and trunk: for every bone the distance of its vertices from the bone's axis is measured in rings along the
##    bone; a vertex standing further out than the ring's typical surface (a percentile of the radii times a tolerance)
##    is moved in to that radius. Fins, blades and scales standing off a limb collapse onto the plate under them.
##  - head and shoulder caps: measured as a ball instead (an ellipsoid fitted to the bulk of the part), because a crest
##    or a pauldron horn points along the bone, not away from it.
## The moved vertices are then relaxed toward their neighbours so the collapsed spike does not leave a crumpled patch.
## The texture is not touched: a collapsed spike leaves its paint (a streak or a blotch) on the plate.
const SPIKE_TOL := {"Head": 1.2, "Neck": 1.25, "Spine2": 1.22, "Spine1": 1.22, "Spine": 1.25, "Hips": 1.3, "Shoulder": 1.22, "Arm": 1.3, "ForeArm": 1.28, "Hand": 1.6, "UpLeg": 1.28, "Leg": 1.25, "Foot": 9.0}

func _despike(m: Dictionary, h: Dictionary, strength: float) -> int:
	var names: Array = h.names
	var before: PackedVector3Array = (m.pos as PackedVector3Array).duplicate()
	var groups := {}        # host bind index -> [vertex]
	for v in (m.pos as PackedVector3Array).size():
		var key := (names as Array).find(driver(names[m.top[v]]))
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(v)
	var moved := {}
	for key: int in groups:
		var b: String = names[key]
		var tol := 0.0
		for suffix: String in ["ForeArm", "Shoulder", "UpLeg", "Arm", "Leg", "Hand", "Foot"]:
			if b.ends_with(suffix):
				tol = SPIKE_TOL[suffix]
				break
		if tol == 0.0:
			tol = SPIKE_TOL.get(b, 1.3)
		tol = 1.0 + (tol - 1.0) / maxf(strength, 0.01)
		var vs: Array = groups[key]
		if b == "Head" or b.ends_with("Shoulder"):
			_despike_ball(m, vs, tol, moved)
			continue
		var j: Vector3 = (h.rest[b] as Transform3D).origin
		var axis := Vector3.UP
		if CHILD.has(b):
			axis = ((h.rest[CHILD[b]] as Transform3D).origin - j).normalized()
		elif b.ends_with("Hand"):
			axis = (j - (h.rest[b.replace("Hand", "ForeArm")] as Transform3D).origin).normalized()
		var bins := {}
		for v: int in vs:
			var d: Vector3 = m.pos[v] - j
			var along := d.dot(axis)
			var bin := int(floor(along / 0.02))
			if not bins.has(bin):
				bins[bin] = []
			(bins[bin] as Array).append([(d - axis * along).length(), v])
		var med := {}
		for bin: int in bins:
			var rs: Array = []
			for e: Array in bins[bin]:
				rs.append(e[0])
			rs.sort()
			med[bin] = float(rs[int(rs.size() * 0.6)])
		for bin: int in bins:
			# the limit follows the limb's taper: the typical radius here and in the rings either side
			var lim: float = med[bin]
			var cnt := 1.0
			for nb: int in [bin - 2, bin - 1, bin + 1, bin + 2]:
				if med.has(nb):
					lim += float(med[nb])
					cnt += 1.0
			lim = lim / cnt * tol
			for e2: Array in bins[bin]:
				if float(e2[0]) > lim and lim > 0.004:
					var v2: int = e2[1]
					var d2: Vector3 = m.pos[v2] - j
					var along2 := d2.dot(axis)
					var radial := d2 - axis * along2
					m.pos[v2] = j + axis * along2 + radial.normalized() * (lim + (float(e2[0]) - lim) * 0.06)
					moved[v2] = true
	if not moved.is_empty():
		_relax(m, before, moved)
		_renormal(m)
	return moved.size()

func _despike_ball(m: Dictionary, vs: Array, tol: float, moved: Dictionary) -> void:
	var xs: Array = []
	var ys: Array = []
	var zs: Array = []
	for v: int in vs:
		var p: Vector3 = m.pos[v]
		xs.append(p.x); ys.append(p.y); zs.append(p.z)
	xs.sort(); ys.sort(); zs.sort()
	var n := xs.size()
	if n < 50:
		return
	var lo := Vector3(xs[int(n * 0.15)], ys[int(n * 0.15)], zs[int(n * 0.15)])
	var hi := Vector3(xs[int(n * 0.85)], ys[int(n * 0.85)], zs[int(n * 0.85)])
	var c := (lo + hi) * 0.5
	var sc := ((hi - lo) * 0.5).max(Vector3.ONE * 0.003)
	var rs: Array = []
	for v2: int in vs:
		rs.append((((m.pos[v2] as Vector3) - c) / sc).length())
	var sorted := rs.duplicate()
	sorted.sort()
	var lim: float = float(sorted[int(n * 0.6)]) * tol
	for i in vs.size():
		if float(rs[i]) > lim:
			var q: Vector3 = ((m.pos[vs[i]] as Vector3) - c) / sc
			m.pos[vs[i]] = c + q.normalized() * (lim + (float(rs[i]) - lim) * 0.06) * sc
			moved[vs[i]] = true

## Moved vertices settle toward the average of their neighbours (never outward of where the clamp put them is not
## enforced: three gentle passes only). Vertices doubled along UV seams move together.
func _relax(m: Dictionary, before: PackedVector3Array, moved: Dictionary) -> void:
	var gid := {}
	var of := PackedInt32Array()
	of.resize(before.size())
	for v in before.size():
		var k := Vector3i(before[v] * 20000.0)
		if not gid.has(k):
			gid[k] = gid.size()
		of[v] = gid[k]
	var gpos: Array = []
	gpos.resize(gid.size())
	var gmoved := {}
	for v in before.size():
		gpos[of[v]] = m.pos[v]
		if moved.has(v):
			gmoved[of[v]] = true
	var nbr := {}
	var idx: PackedInt32Array = m.idx
	for t in range(0, idx.size(), 3):
		for e in 3:
			var a := of[idx[t + e]]
			var b := of[idx[t + (e + 1) % 3]]
			if gmoved.has(a):
				if not nbr.has(a):
					nbr[a] = {}
				nbr[a][b] = true
			if gmoved.has(b):
				if not nbr.has(b):
					nbr[b] = {}
				nbr[b][a] = true
	for pass_i in 3:
		var next := {}
		for g: int in nbr:
			var avg := Vector3.ZERO
			for o: int in nbr[g]:
				avg += gpos[o]
			next[g] = (gpos[g] as Vector3).lerp(avg / float((nbr[g] as Dictionary).size()), 0.5)
		for g2: int in next:
			gpos[g2] = next[g2]
	for v in before.size():
		if gmoved.has(of[v]):
			m.pos[v] = gpos[of[v]]

## Normals again from the faces after vertices have moved (welded by position, so UV seams stay smooth).
func _renormal(m: Dictionary) -> void:
	var pos: PackedVector3Array = m.pos
	var idx: PackedInt32Array = m.idx
	var acc := {}
	for t in range(0, idx.size(), 3):
		var a := pos[idx[t]]
		var b := pos[idx[t + 1]]
		var c := pos[idx[t + 2]]
		var fn := (c - a).cross(b - a)
		for p: Vector3 in [a, b, c]:
			var key := Vector3i(p * 20000.0)
			acc[key] = (acc.get(key, Vector3.ZERO) as Vector3) + fn
	for v in pos.size():
		var n: Vector3 = acc.get(Vector3i(pos[v] * 20000.0), Vector3.ZERO)
		if n.length_squared() > 1e-16:
			# keep the old normal's side: the winding convention is whatever the source used
			var nn := n.normalized()
			m.nrm[v] = nn if nn.dot(m.nrm[v]) >= 0.0 else -nn

# ---------------------------------------------------------------- split
func _part(m: Dictionary, r: int, margin: float) -> Dictionary:
	var n: int = (m.pos as PackedVector3Array).size()
	var f := PackedFloat32Array()
	var other := PackedInt32Array()
	f.resize(n)
	other.resize(n)
	var rw: PackedFloat32Array = m.rw
	for v in n:
		var best := -1.0
		var bo := 0
		for q in 6:
			if q != r and rw[v * 6 + q] > best:
				best = rw[v * 6 + q]
				bo = q
		f[v] = rw[v * 6 + r] - best
		other[v] = bo
	return _clip(m, f, -margin, other)

var _o: Dictionary
var _s: Dictionary
var _map: PackedInt32Array
var _edge: Dictionary
var _f: PackedFloat32Array
var _thr := 0.0
var _other: PackedInt32Array

## Keeps the part of the mesh where f > thr, cutting the triangles that cross the line.
func _clip(m: Dictionary, f: PackedFloat32Array, thr: float, other: PackedInt32Array) -> Dictionary:
	_s = m
	_f = f
	_thr = thr
	_other = other
	_o = {"pos": PackedVector3Array(), "nrm": PackedVector3Array(), "tan": PackedFloat32Array(), "uv": PackedVector2Array(), "bones": PackedInt32Array(),
		"weights": PackedFloat32Array(), "idx": PackedInt32Array(), "rings": {}}
	_map = PackedInt32Array()
	_map.resize(f.size())
	_map.fill(-1)
	_edge = {}
	var idx: PackedInt32Array = m.idx
	for t in range(0, idx.size(), 3):
		var a := idx[t]
		var b := idx[t + 1]
		var c := idx[t + 2]
		var ia := f[a] > thr
		var ib := f[b] > thr
		var ic := f[c] > thr
		var cnt := int(ia) + int(ib) + int(ic)
		if cnt == 0:
			continue
		if cnt == 3:
			_tri(_keep(a), _keep(b), _keep(c))
			continue
		# rotate so the odd one out comes first
		if cnt == 1:
			if ib:
				var x := a; a = b; b = c; c = x
			elif ic:
				var y := c; c = b; b = a; a = y
			_tri(_keep(a), _cut(a, b), _cut(a, c))
		else:
			if not ib:
				var x2 := a; a = b; b = c; c = x2
			elif not ic:
				var y2 := c; c = b; b = a; a = y2
			# a is outside, b and c inside
			var ab := _cut(b, a)
			var ac := _cut(c, a)
			_tri(ab, _keep(b), _keep(c))
			_tri(ab, _keep(c), ac)
	return _o

func _tri(a: int, b: int, c: int) -> void:
	_o.idx.append(a); _o.idx.append(b); _o.idx.append(c)

func _keep(v: int) -> int:
	if _map[v] >= 0:
		return _map[v]
	var i: int = _o.pos.size()
	_map[v] = i
	_o.pos.append(_s.pos[v])
	_o.nrm.append(_s.nrm[v])
	_o.uv.append(_s.uv[v])
	for j in 4:
		_o.tan.append(_s.tan[v * 4 + j])
		_o.bones.append(_s.bones[v * 4 + j])
		_o.weights.append(_s.weights[v * 4 + j])
	return i

## A new vertex on the edge from `a` (inside) to `b` (outside), where f crosses the threshold.
func _cut(a: int, b: int) -> int:
	var key := a * 1000003 + b
	if _edge.has(key):
		return _edge[key]
	var t := clampf((_thr - _f[a]) / (_f[b] - _f[a]), 0.0, 1.0)
	var i: int = _o.pos.size()
	_edge[key] = i
	_o.pos.append((_s.pos[a] as Vector3).lerp(_s.pos[b], t))
	_o.nrm.append((_s.nrm[a] as Vector3).lerp(_s.nrm[b], t).normalized())
	_o.uv.append((_s.uv[a] as Vector2).lerp(_s.uv[b], t))
	for j in 3:
		_o.tan.append(lerpf(_s.tan[a * 4 + j], _s.tan[b * 4 + j], t))
	_o.tan.append(_s.tan[a * 4 + 3])
	# the four strongest of the two ends' weights
	var w := {}
	for j in 4:
		var ba: int = _s.bones[a * 4 + j]
		var bb: int = _s.bones[b * 4 + j]
		w[ba] = float(w.get(ba, 0.0)) + _s.weights[a * 4 + j] * (1.0 - t)
		w[bb] = float(w.get(bb, 0.0)) + _s.weights[b * 4 + j] * t
	var ks: Array = w.keys()
	ks.sort_custom(func(x, y): return float(w[x]) > float(w[y]))
	var sum := 0.0
	for j in mini(4, ks.size()):
		sum += float(w[ks[j]])
	for j in 4:
		_o.bones.append(int(ks[j]) if j < ks.size() else 0)
		_o.weights.append(float(w[ks[j]]) / sum if j < ks.size() else 0.0)
	if not _other.is_empty():
		var seam: String = SLOTS[_other[b]]
		if not _o.rings.has(seam):
			_o.rings[seam] = []
		(_o.rings[seam] as Array).append(i)
	return i

# ---------------------------------------------------------------- writing
func _save(p: Dictionary, path: String, id: String) -> void:
	if (p.idx as PackedInt32Array).is_empty():
		push_warning("empty part " + path)
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = p.pos
	arr[Mesh.ARRAY_NORMAL] = p.nrm
	arr[Mesh.ARRAY_TANGENT] = p.tan
	arr[Mesh.ARRAY_TEX_UV] = p.uv
	arr[Mesh.ARRAY_BONES] = p.bones
	arr[Mesh.ARRAY_WEIGHTS] = p.weights
	arr[Mesh.ARRAY_INDEX] = p.idx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
	if not args.has("nolod"):
		im.generate_lods(25.0, 60.0, [])
	var mesh := im.get_mesh()
	mesh.set_meta("suit", id)
	if p.has("rings"):
		var rings := {}
		for k: String in p.rings:
			rings[k] = PackedInt32Array(p.rings[k])
		mesh.set_meta("rings", rings)
	var err := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("could not save %s (%d)" % [path, err])

## The suit's textures on the game's clamped-PBR shader, with the ranges this study settled on (see ArmorParts.FINISH).
func _save_material(s: Dictionary, path: String) -> void:
	var bm: BaseMaterial3D = s.material
	var sm := ShaderMaterial.new()
	sm.shader = load("res://src/fx/armor_part.gdshader")
	sm.set_shader_parameter("albedo_tex", bm.albedo_texture)
	sm.set_shader_parameter("normal_tex", bm.normal_texture)
	sm.set_shader_parameter("normal_scale", bm.normal_scale)
	sm.set_shader_parameter("orm_tex", bm.roughness_texture if bm.roughness_texture else bm.metallic_texture)
	ResourceSaver.save(sm, path)
