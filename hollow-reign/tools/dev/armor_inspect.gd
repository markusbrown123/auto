extends SceneTree
## Dev: prints skeleton, mesh, material and proportion facts for every knight suit (docs/MODULAR_ARMOR.md).
## Run: Godot --headless --path . -s tools/dev/armor_inspect.gd
const SUITS := ["", "garrison", "ash", "black", "vigil", "frost", "regal", "wyrm", "hollow"]
const KEY := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
	"LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase"]

func _short(n: String) -> String:
	return n.get_slice(":", n.get_slice_count(":") - 1).trim_prefix("mixamorig_").trim_prefix("mixamorig")

func _init() -> void:
	var ref := {}
	for body: String in ["m", "f"]:
		for suit: String in SUITS:
			var id := "knight_%s%s" % [body, ("_" + suit) if suit != "" else ""]
			var root: Node = (load("res://assets/models/%s.glb" % id) as PackedScene).instantiate()
			var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
			var mis: Array = root.find_children("*", "MeshInstance3D", true, false)
			var names: Array = []
			var rest := {}
			for i in skel.get_bone_count():
				names.append(_short(skel.get_bone_name(i)))
				rest[names[i]] = skel.get_bone_global_rest(i)
			var tris := 0
			var verts := 0
			var surf := 0
			var tex := ""
			var lo := Vector3.ONE * 1e9
			var hi := -lo
			var nb := 0
			for mi: MeshInstance3D in mis:
				for s in mi.mesh.get_surface_count():
					surf += 1
					var arr := mi.mesh.surface_get_arrays(s)
					var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					verts += pos.size()
					tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
					nb = (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() / pos.size()
					for p in pos:
						lo = lo.min(p)
						hi = hi.max(p)
					var m: BaseMaterial3D = mi.mesh.surface_get_material(s)
					tex = "alb %s nrm %s orm %s rough=%.2f metal=%.2f" % [m.albedo_texture.get_size() if m.albedo_texture else "-",
						m.normal_texture.get_size() if m.normal_texture else "-", m.roughness_texture.get_size() if m.roughness_texture else "-", m.roughness, m.metallic]
			var sk_scale: Vector3 = skel.transform.basis.get_scale()
			print("== %s  meshes=%d surfaces=%d verts=%d tris=%d weights/vert=%d bones=%d binds=%d  skel_scale=%.3f mesh_xf=%s" % [id, mis.size(), surf, verts, tris, nb,
				skel.get_bone_count(), (mis[0] as MeshInstance3D).skin.get_bind_count(), sk_scale.y, str((mis[0] as MeshInstance3D).transform.basis.get_scale())])
			print("   ", tex, "  aabb size=", (hi - lo).snapped(Vector3.ONE * 0.001), " min_y=", snappedf(lo.y, 0.001))
			var h: float = hi.y - lo.y
			var up: float = (rest["LeftForeArm"].origin - rest["LeftArm"].origin).length()
			var fore: float = (rest["LeftHand"].origin - rest["LeftForeArm"].origin).length()
			var thigh: float = (rest["LeftLeg"].origin - rest["LeftUpLeg"].origin).length()
			var shin: float = (rest["LeftFoot"].origin - rest["LeftLeg"].origin).length()
			var armdir: Vector3 = (rest["LeftForeArm"].origin - rest["LeftArm"].origin).normalized()
			print("   per height: width=%.3f depth=%.3f shoulders=%.3f hips_y=%.3f neck_y=%.3f head_y=%.3f uparm=%.3f fore=%.3f thigh=%.3f shin=%.3f hipw=%.3f arm_drop_deg=%.1f" % [
				(hi.x - lo.x) / h, (hi.z - lo.z) / h, rest["LeftArm"].origin.distance_to(rest["RightArm"].origin) / h, (rest["Hips"].origin.y - lo.y) / h,
				(rest["Neck"].origin.y - lo.y) / h, (rest["Head"].origin.y - lo.y) / h, up / h, fore / h, thigh / h, shin / h,
				rest["LeftUpLeg"].origin.distance_to(rest["RightUpLeg"].origin) / h, rad_to_deg(asin(-armdir.y))])
			if suit == "":
				ref[body] = {"names": names, "rest": rest, "h": h, "lo": lo}
				print("   bones: ", ", ".join(names))
				var ident := 0
				for i in skel.get_bone_count():
					if skel.get_bone_global_rest(i).basis.is_equal_approx(Basis.IDENTITY):
						ident += 1
				print("   bones with identity global rest basis: %d of %d" % [ident, skel.get_bone_count()])
			var r0: Dictionary = ref[body]
			var same_names: bool = names == r0.names
			var worst := 0.0
			var worst_b := ""
			var worst_rot := 0.0
			var line := ""
			for b: String in names:
				if not r0.rest.has(b):
					continue
				var a: Vector3 = ((rest[b] as Transform3D).origin - lo) / h
				var c: Vector3 = ((r0.rest[b] as Transform3D).origin - (r0.lo as Vector3)) / float(r0.h)
				var d: float = a.distance_to(c) * 195.0       # cm on a 1.95 m knight
				if d > worst:
					worst = d
					worst_b = b
				var q := ((rest[b] as Transform3D).basis.orthonormalized() * (r0.rest[b] as Transform3D).basis.orthonormalized().inverse()).get_rotation_quaternion()
				worst_rot = maxf(worst_rot, rad_to_deg(q.get_angle()))
				if KEY.has(b):
					line += "%s %.1f  " % [b, d]
			print("   vs base knight_%s: same bone list=%s  worst joint offset %.1f cm (%s)  worst rest-basis difference %.1f deg" % [body, same_names, worst, worst_b, worst_rot])
			print("   joint offsets cm: ", line)
			root.free()
	quit()
