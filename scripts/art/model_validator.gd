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
## Bilinen modellerin beklenen boyu (m) ve toleransı (docs/07: Alpay 1.6, Kocabaş ~3, Kökyiyen 12–15).
const EXPECTED_HEIGHT: Dictionary = {
	"alpay": [1.6, 0.15],
	"kocabas": [3.0, 0.25],
	"kokyiyen": [13.5, 0.12],
	"rot_crawler": [0.6, 0.4],
	"spore_bloater": [1.0, 0.4],
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
	var kind := kind_of(path)
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []
	var stats := measure(root)
	if kind == &"":
		errors.append("Tür öneki yok (char_/npc_/enm_/boss_/prop_/env_): %s" % path.get_file())
	else:
		var budget: Array = BUDGETS[kind]
		if stats["triangles"] > budget[1]:
			errors.append("Üçgen bütçesi aşıldı: %d > %d" % [stats["triangles"], budget[1]])
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
	if kind == &"char" or kind == &"npc":
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
	lines.append("    üçgen %d · mesh %d · materyal %d · doku %d px · boy %.2f m · kemik %d · bakış %s" % [
			s["triangles"], s["meshes"], s["materials"], s["max_texture"], s["height"], s["bones"], s["facing"]])
	for e: String in r["errors"]:
		lines.append("    HATA: " + e)
	for w: String in r["warnings"]:
		lines.append("    uyarı: " + w)
	return "\n".join(lines)
