class_name ModelValidator
extends RefCounted
## AI modelleri için otomatik kalite kontrolü (docs/07 "Blender Temizlik" + "Kalite Kontrol").
## Ölçer: üçgen sayısı, doku boyutu, materyal sayısı, boy (1 birim = 1 m), orijin (ayak tabanı ortası),
## bakış yönü (+Z, insansı iskeletlerde ayak/parmak kemiğinden), insansıda Mixamo uyumlu iskelet.
## Tür dosya önekinden okunur (docs/07 isimlendirme): char_, npc_, enm_, boss_, prop_, env_.
## Kullanım: tests/model_check.tscn (assets/models altındaki her modeli tarar).

## tür -> [en az üçgen, en çok üçgen, en büyük doku kenarı]
const BUDGETS: Dictionary = {
	&"char": [15000, 25000, 2048],
	&"npc": [8000, 15000, 1024],
	&"enm": [5000, 15000, 1024],
	&"boss": [30000, 60000, 2048],
	&"prop": [500, 5000, 1024],
	&"env": [1000, 8000, 1024],
}
## Bütçe istisnaları (ad → en çok üçgen): kullanıcı onayıyla, sahnede sınırlı adette kullanılan "kahraman" parçalar.
## Eğrelti: oda başına ≤ 3; sarmaşık perdesi: oda başına ≤ 1 (RoomDressing / oda script'i). Yeniden üretimde 8k hedeflenir.
const TRI_OVERRIDES: Dictionary = {
	"fern_1m_a": 20000,
	"vine_curtain_4m_a": 16000,
}
## Bilinen modellerin beklenen boyu (m) ve toleransı (docs/07: Alpay 1.6, Kocabaş ~3, Kökyiyen 12–15).
const EXPECTED_HEIGHT: Dictionary = {
	"alpay": [1.6, 0.15],
	"kocabas": [3.0, 0.25],
	"kokyiyen": [8.0, 0.15],          # arena tavanı 12.5 m → dikilmiş gövde ≈ 8 m (karar 2026-11-26)
	"rot_crawler": [0.6, 0.4],
	"spore_bloater": [1.0, 0.4],
	"trap_flower": [1.5, 0.3],
	"root_snake": [0.9, 0.4],
	"grapple_flower": [0.8, 0.3],
}
## Mixamo/insansı iskelette bulunması gereken kemikler (önekten bağımsız aranır).
const HUMANOID_BONES: Array[String] = ["Hips", "Spine", "Head", "LeftArm", "RightArm", "LeftHand",
		"RightHand", "LeftUpLeg", "RightUpLeg", "LeftFoot", "RightFoot"]
const ORIGIN_TOLERANCE: float = 0.05     # boyun %5'i
const CENTER_TOLERANCE: float = 0.25     # genişliğin %25'i
const MAX_MATERIALS: int = 2
const MODEL_EXTENSIONS: Array[String] = ["glb", "gltf", "fbx"]


## Dosya adından tür: "char_alpay.glb" → &"char". Bilinmiyorsa &"".
static func kind_of(path: String) -> StringName:
	var base := path.get_file().get_basename()
	var prefix := base.get_slice("_", 0)
	return StringName(prefix) if BUDGETS.has(StringName(prefix)) else &""


## Model adı (önek sonrası): "enm_rot_crawler_a" → "rot_crawler_a"
static func name_of(path: String) -> String:
	var base := path.get_file().get_basename()
	var i := base.find("_")
	return base.substr(i + 1) if i >= 0 else base


## Bir model sahnesini doğrular. Sonuç: {path, kind, ok, errors, warnings, stats}
static func validate_scene(root: Node3D, path: String) -> Dictionary:
	if path.get_file().begins_with("anim_"):
		return validate_animation(root, path)
	var kind := kind_of(path)
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []
	var stats := measure(root)
	if kind == &"":
		errors.append("Tür öneki yok (char_/npc_/enm_/boss_/prop_/env_): %s" % path.get_file())
	else:
		var budget: Array = BUDGETS[kind]
		var max_tris: int = TRI_OVERRIDES.get(name_of(path), budget[1])
		if stats["triangles"] > max_tris:
			errors.append("Üçgen bütçesi aşıldı: %d > %d" % [stats["triangles"], max_tris])
		elif max_tris > budget[1] and stats["triangles"] > budget[1]:
			warnings.append("Bütçe istisnası: %d üçgen (> %d) — sahnede sınırlı adet" % [stats["triangles"], budget[1]])
		elif stats["triangles"] < budget[0]:
			warnings.append("Üçgen sayısı bütçenin altında (%d < %d) — siluet yeterli mi?" % [stats["triangles"], budget[0]])
		if stats["max_texture"] > budget[2]:
			errors.append("Doku çok büyük: %d px > %d px" % [stats["max_texture"], budget[2]])
	if stats["meshes"] == 0:
		errors.append("Model mesh içermiyor")
		return _result(path, kind, errors, warnings, stats)
	if stats["materials"] > MAX_MATERIALS:
		warnings.append("Materyal sayısı %d (hedef ≤ %d, doku atlası önerilir)" % [stats["materials"], MAX_MATERIALS])

	var aabb: AABB = stats["aabb"]
	var height := aabb.size.y
	if absf(aabb.position.y) > maxf(height * ORIGIN_TOLERANCE, 0.02):
		errors.append("Orijin ayak tabanında değil: taban y = %.3f m (0 olmalı)" % aabb.position.y)
	var center := aabb.get_center()
	if absf(center.x) > maxf(aabb.size.x * CENTER_TOLERANCE, 0.05) or absf(center.z) > maxf(aabb.size.z * CENTER_TOLERANCE, 0.05):
		errors.append("Orijin yatayda ortada değil: merkez (%.2f, %.2f)" % [center.x, center.z])
	for key: String in EXPECTED_HEIGHT.keys():
		if name_of(path).begins_with(key):
			var expected: Array = EXPECTED_HEIGHT[key]
			if absf(height - float(expected[0])) > float(expected[0]) * float(expected[1]):
				errors.append("Boy %.2f m; beklenen %.2f m ±%%%d (ölçek 1 birim = 1 m mi?)" % [height, expected[0], int(float(expected[1]) * 100.0)])
	if kind == &"npc" and not stats["has_skeleton"]:
		errors.append("NPC iskeletsiz (otomatik rig gerekli)")
	if kind == &"char":
		var missing: PackedStringArray = stats["missing_humanoid_bones"]
		if not stats["has_skeleton"]:
			errors.append("İnsansı model iskeletsiz (Mixamo/otomatik rig gerekli)")
		elif not missing.is_empty():
			errors.append("Mixamo uyumlu kemik eksik: %s" % ", ".join(missing))
		match stats["facing"]:
			"-Z": errors.append("Model -Z'ye bakıyor (+Z olmalı) — Blender'da 180° çevir")
			"+X", "-X": errors.append("Model yana (%s) bakıyor (+Z olmalı)" % stats["facing"])
			"?": warnings.append("Bakış yönü iskeletten ölçülemedi — +Z olduğundan emin ol")
	return _result(path, kind, errors, warnings, stats)


## Rig (deri ağırlığı) analizi. Her kemik için: etkilediği köşe sayısı (ağırlık > 0.3), bu köşelerin
## kemiğe ortalama uzaklığı (model boyuna oranla), "Left/Right" adlı kemiklerde karşı tarafa sızma.
## Sonuç: {bones: [...], dead: [...], leaks: [...], far: [...], unweighted: int, vertices: int, errors, warnings}
static func rig_report(root: Node3D) -> Dictionary:
	var out := {"bones": [], "dead": [], "leaks": [], "far": [], "unweighted": 0, "vertices": 0,
			"errors": PackedStringArray(), "warnings": PackedStringArray()}
	var mi: MeshInstance3D = null
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).skin != null:
			mi = n as MeshInstance3D
			break
	if mi == null:
		return out
	var skeleton := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if skeleton == null:
		return out
	var skin := mi.skin
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones_arr: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var nv := verts.size()
	out["vertices"] = nv
	if nv == 0 or bones_arr.size() == 0:
		return out
	var per := bones_arr.size() / nv
	var aabb := mi.mesh.get_aabb()
	var size := aabb.size.length()
	var center := aabb.get_center()
	# bağ (bind) indeksi → kemik konumu (mesh uzayında) ve adı
	var bind_pos: Array[Vector3] = []
	var bind_name: Array[String] = []
	for b in skin.get_bind_count():
		bind_pos.append(skin.get_bind_pose(b).affine_inverse().origin)
		var name := skin.get_bind_name(b)
		if name == &"" and skin.get_bind_bone(b) >= 0:
			name = skeleton.get_bone_name(skin.get_bind_bone(b))
		bind_name.append(String(name))
	var count: Array[int] = []
	var sum_dist: Array[float] = []
	var sum_pos: Array[Vector3] = []
	count.resize(bind_pos.size())
	sum_dist.resize(bind_pos.size())
	sum_pos.resize(bind_pos.size())
	for b in bind_pos.size():
		count[b] = 0
		sum_dist[b] = 0.0
		sum_pos[b] = Vector3.ZERO
	var unweighted := 0
	for v in nv:
		var total := 0.0
		for k in per:
			var w := weights[v * per + k]
			total += w
			var b := bones_arr[v * per + k]
			if w > 0.3 and b >= 0 and b < bind_pos.size():
				count[b] += 1
				sum_dist[b] += verts[v].distance_to(bind_pos[b])
				sum_pos[b] += verts[v]
		if total < 0.01:
			unweighted += 1
	out["unweighted"] = unweighted
	# Sol/sağ ekseni: "Left" kemiklerin ortalama konumu ile "Right" olanların farkı
	var left := Vector3.ZERO
	var right := Vector3.ZERO
	var nl := 0
	var nr := 0
	for b in bind_pos.size():
		if bind_name[b].contains("Left"):
			left += bind_pos[b]
			nl += 1
		elif bind_name[b].contains("Right"):
			right += bind_pos[b]
			nr += 1
	var lr_axis := Vector3.ZERO
	if nl > 0 and nr > 0:
		lr_axis = (left / nl - right / nr).normalized()
	for b in bind_pos.size():
		var info := {"name": bind_name[b], "verts": count[b]}
		if count[b] == 0:
			(out["dead"] as Array).append(bind_name[b])
		else:
			var avg := sum_dist[b] / count[b] / size
			info["avg_dist"] = avg
			if avg > 0.35:
				(out["far"] as Array).append("%s (%.0f%%)" % [bind_name[b], avg * 100.0])
			if lr_axis != Vector3.ZERO and (bind_name[b].contains("Left") or bind_name[b].contains("Right")):
				var side := (sum_pos[b] / count[b] - center).dot(lr_axis)
				var expect := 1.0 if bind_name[b].contains("Left") else -1.0
				var bone_side := (bind_pos[b] - center).dot(lr_axis)
				if side * expect < -0.02 * size and bone_side * expect > 0.0:
					(out["leaks"] as Array).append(bind_name[b])
		(out["bones"] as Array).append(info)
	if unweighted > 0:
		(out["errors"] as PackedStringArray).append("%d köşe hiçbir kemiğe bağlı değil (animasyonda yerinde kalır)" % unweighted)
	if not (out["leaks"] as Array).is_empty():
		(out["errors"] as PackedStringArray).append("Sol/sağ ağırlık sızıntısı: %s" % ", ".join(out["leaks"]))
	if not (out["far"] as Array).is_empty():
		(out["warnings"] as PackedStringArray).append("Uzak köşeleri taşıyan kemik: %s" % ", ".join(out["far"]))
	if not (out["dead"] as Array).is_empty():
		(out["warnings"] as PackedStringArray).append("Hiç köşe taşımayan kemik: %d (%s)" % [(out["dead"] as Array).size(),
				", ".join((out["dead"] as Array).slice(0, 8))])
	return out


## Bükme testi: her kemik sırayla `angle_deg` döndürülür, mesh CPU'da deri ağırlıklarıyla deforme edilir
## (GPU ile aynı formül: Σ w · kemik_global_poz · bağ_pozu · köşe) ve üçgen kenarlarının uzama oranına bakılır.
## Kötü ağırlıkta mesh yırtılır / sivri çıkar → oran büyür. Sonuç: {worst: float, worst_bone, bad: [[kemik, oran]]}
static func bend_test(root: Node3D, angle_deg: float = 30.0, bad_ratio: float = 2.5) -> Dictionary:
	var out := {"worst": 1.0, "worst_bone": "", "bad": []}
	var mi: MeshInstance3D = null
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).skin != null:
			mi = n as MeshInstance3D
			break
	if mi == null:
		return out
	var skeleton := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if skeleton == null:
		return out
	var skin := mi.skin
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones_arr: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nv := verts.size()
	if nv == 0 or bones_arr.is_empty():
		return out
	var per := bones_arr.size() / nv
	var bind_bone: Array[int] = []
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(b))
		bind_bone.append(bone)
	# Kenarlar (benzersiz değil — yeterli) ve dinlenme uzunlukları
	var edges := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		edges.append_array([idx[t], idx[t + 1], idx[t + 1], idx[t + 2], idx[t + 2], idx[t]])
	# Dinlenme pozunda deri uygulanmış kenar uzunlukları (taban). Bağ pozu dinlenmeyle birebir
	# örtüşmeyebilir (ör. ölçekli GLB); oranı bu tabana göre almak bunu nötrler.
	var base := _skin_vertices(skeleton, skin, bind_bone, verts, bones_arr, weights, per)
	var rest_len := PackedFloat32Array()
	rest_len.resize(edges.size() / 2)
	for e in rest_len.size():
		rest_len[e] = base[edges[e * 2]].distance_to(base[edges[e * 2 + 1]])
	var size := mi.mesh.get_aabb().size.length()
	var min_len := size * 0.002
	for test_bone in skeleton.get_bone_count():
		if skeleton.get_bone_parent(test_bone) < 0:
			continue   # kök: tüm modeli katı döndürür, anlamsız
		var posed := _skin_vertices(skeleton, skin, bind_bone, verts, bones_arr, weights, per, test_bone, deg_to_rad(angle_deg))
		var worst := 1.0
		var torn := 0
		for e in rest_len.size():
			if rest_len[e] < min_len:
				continue
			var r := posed[edges[e * 2]].distance_to(posed[edges[e * 2 + 1]]) / rest_len[e]
			worst = maxf(worst, r)
			if r > 1.6:
				torn += 1
		var torn_frac := float(torn) / float(rest_len.size())
		if torn_frac > float(out.get("worst_torn", 0.0)):
			out["worst_torn"] = torn_frac
			out["worst_torn_bone"] = skeleton.get_bone_name(test_bone)
		(out.get_or_add("per_bone", []) as Array).append([skeleton.get_bone_name(test_bone), worst, torn_frac])
		var moved := 0.0
		for v in range(0, nv, 7):
			moved = maxf(moved, posed[v].distance_to(base[v]))
		out["max_move"] = maxf(float(out.get("max_move", 0.0)), moved / size)
		if worst > float(out["worst"]):
			out["worst"] = worst
			out["worst_bone"] = skeleton.get_bone_name(test_bone)
		if worst > bad_ratio:
			(out["bad"] as Array).append([skeleton.get_bone_name(test_bone), worst])
	return out


## Dinlenme pozundan, `test_bone` yerel X ekseninde `angle` döndürülmüş hâlde deri uygulanmış köşeler.
## Global pozlar elle hesaplanır (ağaç dışındaki Skeleton3D pozları güncellemez).
static func _skin_vertices(skeleton: Skeleton3D, skin: Skin, bind_bone: Array[int], verts: PackedVector3Array,
		bones_arr: PackedInt32Array, weights: PackedFloat32Array, per: int, test_bone: int = -1, angle: float = 0.0) -> PackedVector3Array:
	var count := skeleton.get_bone_count()
	var global: Array[Transform3D] = []
	global.resize(count)
	var done := PackedByteArray()
	done.resize(count)
	for b in count:
		_bone_global(skeleton, b, test_bone, angle, global, done)
	var palette: Array[Transform3D] = []
	for b in bind_bone.size():
		var gb := bind_bone[b]
		palette.append(global[gb] * skin.get_bind_pose(b) if gb >= 0 else Transform3D.IDENTITY)
	var posed := PackedVector3Array()
	posed.resize(verts.size())
	for v in verts.size():
		var p := Vector3.ZERO
		var wsum := 0.0
		for k in per:
			var w := weights[v * per + k]
			if w <= 0.0:
				continue
			p += (palette[bones_arr[v * per + k]] * verts[v]) * w
			wsum += w
		posed[v] = p / wsum if wsum > 0.0 else verts[v]
	return posed


static func _bone_global(skeleton: Skeleton3D, b: int, test_bone: int, angle: float, global: Array[Transform3D], done: PackedByteArray) -> Transform3D:
	if done[b] == 1:
		return global[b]
	var local := skeleton.get_bone_rest(b)
	if b == test_bone:
		local.basis = local.basis * Basis(Vector3.RIGHT, angle)
	var parent := skeleton.get_bone_parent(b)
	global[b] = (_bone_global(skeleton, parent, test_bone, angle, global, done) * local) if parent >= 0 else local
	done[b] = 1
	return global[b]


## Yalnız animasyon dosyası (anim_<karakter>_<durum>.fbx, Mixamo "Without Skin"): insansı iskelet +
## en az bir klip olmalı; mesh beklenmez ("With Skin" ise uyarı); iskelet Y-yukarı değilse uyarı
## (oyunda atlanır, model klibi kullanılır).
static func validate_animation(root: Node3D, path: String) -> Dictionary:
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []
	var stats := measure(root)
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips := player.get_animation_list().size() if player != null else 0
	stats["clips"] = clips
	if not stats["has_skeleton"]:
		errors.append("Animasyon dosyasında iskelet yok")
	elif not (stats["missing_humanoid_bones"] as PackedStringArray).is_empty():
		errors.append("Mixamo kemiği eksik: %s" % ", ".join(stats["missing_humanoid_bones"]))
	if clips == 0:
		errors.append("Animasyon klibi yok")
	if stats["meshes"] > 0:
		warnings.append("Mesh içeriyor ('With Skin' indirilmiş) — animasyon için 'Without Skin' yeterli")
	var sk := root.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk != null:
		var hips := _find_bone(sk, "Hips")
		if hips >= 0:
			var o := sk.get_bone_rest(hips).origin
			if o.y < o.length() * 0.7:
				warnings.append("İskelet Y-yukarı değil — oyunda bu klip atlanır (Without Skin indir)")
	return _result(path, &"anim", errors, warnings, stats)


static func _result(path: String, kind: StringName, errors: PackedStringArray, warnings: PackedStringArray, stats: Dictionary) -> Dictionary:
	return {"path": path, "kind": kind, "ok": errors.is_empty(), "errors": errors, "warnings": warnings, "stats": stats}


## Ölçümler: üçgen, mesh, materyal, en büyük doku, kök uzayında AABB, iskelet bilgisi, bakış yönü.
static func measure(root: Node3D) -> Dictionary:
	var tris := 0
	var meshes := 0
	var materials: Dictionary = {}
	var max_tex := 0
	var aabb := AABB()
	var first := true
	var skeleton: Skeleton3D = null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		if n is Skeleton3D and skeleton == null:
			skeleton = n as Skeleton3D
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		meshes += 1
		var to_root := _relative_transform(root, mi)
		var box := to_root * mi.mesh.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
		for s in mi.mesh.get_surface_count():
			tris += _surface_triangles(mi.mesh, s)
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if mat != null:
				materials[mat.get_instance_id()] = true
				max_tex = maxi(max_tex, _max_texture(mat))
	var missing: PackedStringArray = []
	var facing := "?"
	if skeleton != null:
		for bone: String in HUMANOID_BONES:
			if _find_bone(skeleton, bone) < 0:
				missing.append(bone)
		facing = _facing_from_skeleton(skeleton, _relative_transform(root, skeleton).basis)
	return {"triangles": tris, "meshes": meshes, "materials": materials.size(), "max_texture": max_tex,
			"aabb": aabb, "height": aabb.size.y, "has_skeleton": skeleton != null,
			"bones": skeleton.get_bone_count() if skeleton != null else 0,
			"missing_humanoid_bones": missing, "facing": facing}


static func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


static func _surface_triangles(mesh: Mesh, surface: int) -> int:
	if mesh is ArrayMesh or mesh is PrimitiveMesh:
		var arrays := mesh.surface_get_arrays(surface)
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			return (idx as PackedInt32Array).size() / 3
		return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return 0


static func _max_texture(mat: Material) -> int:
	var best := 0
	var std := mat as BaseMaterial3D
	if std != null:
		for tex: Texture2D in [std.albedo_texture, std.normal_texture, std.roughness_texture, std.emission_texture]:
			if tex != null:
				best = maxi(best, maxi(tex.get_width(), tex.get_height()))
	var sm := mat as ShaderMaterial
	if sm != null:
		var tex := sm.get_shader_parameter(&"albedo_texture") as Texture2D
		if tex != null:
			best = maxi(best, maxi(tex.get_width(), tex.get_height()))
	return best


## Önek (mixamorig:, mixamorig_, Armature_ …) fark etmeksizin kemik bul.
static func _find_bone(skeleton: Skeleton3D, bone: String) -> int:
	for i in skeleton.get_bone_count():
		var n := skeleton.get_bone_name(i)
		if n == bone or n.ends_with(":" + bone) or n.ends_with("_" + bone):
			return i
	return -1


## Ayak → parmak (ToeBase) vektörünün yönü = bakış yönü (modelin kök uzayında; iskeletin üst
## düğümlerindeki dönüşler dahil — ör. Tripo iskeleti -90° döndürülmüş bir düğümün altına koyar). Yoksa "?".
static func _facing_from_skeleton(skeleton: Skeleton3D, to_root: Basis = Basis.IDENTITY) -> String:
	var foot := _find_bone(skeleton, "LeftFoot")
	var toe := _find_bone(skeleton, "LeftToeBase")
	if foot < 0 or toe < 0:
		return "?"
	var d := to_root * (skeleton.get_bone_global_rest(toe).origin - skeleton.get_bone_global_rest(foot).origin)
	var flat := Vector2(d.x, d.z)
	if flat.length() < 0.001:
		return "?"
	if absf(flat.y) >= absf(flat.x):
		return "+Z" if flat.y > 0.0 else "-Z"
	return "+X" if flat.x > 0.0 else "-X"


## Klasördeki tüm modelleri bul (alt klasörler dahil).
static func find_models(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		out.append_array(find_models(dir_path.path_join(sub)))
	for file: String in dir.get_files():
		if MODEL_EXTENSIONS.has(file.get_extension().to_lower()):
			out.append(dir_path.path_join(file))
	return out


## Rapor satırları (Türkçe, insan okur).
static func format_report(r: Dictionary) -> String:
	var s: Dictionary = r["stats"]
	var lines: PackedStringArray = []
	lines.append("%s %s  [%s]" % ["✓" if r["ok"] else "✗", r["path"], r["kind"]])
	if r["kind"] == &"anim":
		lines.append("    animasyon · klip %d · kemik %d · mesh %d" % [s.get("clips", 0), s["bones"], s["meshes"]])
	else:
		lines.append("    üçgen %d · mesh %d · materyal %d · doku %d px · boy %.2f m · kemik %d · bakış %s" % [
				s["triangles"], s["meshes"], s["materials"], s["max_texture"], s["height"], s["bones"], s["facing"]])
	for e: String in r["errors"]:
		lines.append("    HATA: " + e)
	for w: String in r["warnings"]:
		lines.append("    uyarı: " + w)
	return "\n".join(lines)
