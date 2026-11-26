class_name ModelVisual
extends Node3D
## AI modelini oyuna bağlayan görsel düğüm (docs/07 §7.7):
##  - GLB'yi yükler, stilize eder, isteğe bağlı materyalleri bu örneğe özel kopyalar (vuruş parlaması
##    bir düşmanda yanınca hepsinde yanmasın).
##  - Yön: modelin kendi "ileri" ekseni (`forward`, model uzayı) verilen dünya yönüne yumuşakça döner.
##    Yandan kamerada ölçek ile ayna (scale.x = -1) yerine gerçek dönüş → ışık ve normal bozulmaz.
##  - Yordamsal kemik animasyonu: her kare `add_rotation(kemik, eksen, açı)` ile ofsetler biriktirilir,
##    `apply_pose()` dinlenme pozu × ofset olarak iskelete yazar. Eksenler MODEL uzayında verilir
##    (ör. Vector3.UP = yaw), kemiğin kendi yerel eksenine çevrilir → Tripo kemik yönlerini bilmek gerekmez.

## Modelin kendi uzayında burnunun baktığı yön (Tripo dört ayaklılar çoğunlukla +X).
@export var forward: Vector3 = Vector3.FORWARD
## Dönüş hızı (rad/sn ~ üstel yumuşatma katsayısı).
@export var turn_speed: float = 10.0

var model: Node3D
var skeleton: Skeleton3D
var meshes: Array[MeshInstance3D] = []
## Model düğümünün yaw'ı (pivot).
var pivot: Node3D

var _rest_rot: Array[Quaternion] = []
var _bone_basis_inv: Array[Basis] = []    # iskelet uzayı → kemik yerel (dinlenme)
var _model_to_skel: Basis = Basis()
var _offsets: Dictionary = {}             # kemik → Quaternion (yerel)
var _touched: Dictionary = {}             # önceki karede değiştirilen kemikler
var _target_yaw: float = 0.0
var _materials: Array[ShaderMaterial] = []


## Kolay kurulum: `parent` altına model ekler.
static func spawn(parent: Node, path: String, model_forward: Vector3 = Vector3.FORWARD,
		unique_materials: bool = false) -> ModelVisual:
	var mv := ModelVisual.new()
	mv.name = "Model"
	mv.forward = model_forward
	parent.add_child(mv)
	mv.load_model(path, unique_materials)
	return mv


func load_model(path: String, unique_materials: bool = false) -> bool:
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("ModelVisual: yüklenemedi %s" % path)
		return false
	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	model = packed.instantiate() as Node3D
	pivot.add_child(model)
	Stylizer.apply(model)
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(n as MeshInstance3D)
	if unique_materials:
		_make_unique()
	_collect_materials()
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		skeleton = sks[0] as Skeleton3D
		_cache_bones()
	_target_yaw = 0.0
	return true


## Bu örneğin stilize materyalleri (vuruş parlaması, renk değişimi için).
func get_materials() -> Array[ShaderMaterial]:
	return _materials


func set_shader_param(param: StringName, value: Variant) -> void:
	for m: ShaderMaterial in _materials:
		m.set_shader_parameter(param, value)


## Yerel AABB (pivot dönüşü hariç, model ölçeği dahil).
func get_aabb() -> AABB:
	var r: Dictionary = ModelValidator.measure(model)
	return r["aabb"]


# ---------------------------------------------------------------- Yön

## Dünya yatay düzlemindeki `dir` yönüne bak (yumuşak). `instant` = hemen.
func face(dir: Vector3, instant: bool = false) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var parent_basis := global_transform.basis.orthonormalized()
	var local := parent_basis.inverse() * dir.normalized()
	_target_yaw = atan2(local.x, local.z) - atan2(forward.x, forward.z)
	if instant and pivot != null:
		pivot.rotation.y = _target_yaw


## Yandan görünüşte: +1 sağa (+X), -1 sola. Dönüş kameraya doğru (+Z üzerinden) yapılır,
## böylece hayvan dönerken yüzünü gösterir.
func face_x(sign_x: float, instant: bool = false) -> void:
	if sign_x == 0.0:
		return
	face(Vector3(signf(sign_x), 0.0, 0.0), instant)


func _process(delta: float) -> void:
	if pivot == null:
		return
	var cur := pivot.rotation.y
	var diff := wrapf(_target_yaw - cur, -PI, PI)
	# Tam 180° dönüşte kameraya (+Z) doğru dön: kısa yol belirsizse işareti seç.
	if absf(absf(diff) - PI) < 0.05:
		diff = absf(diff) * (1.0 if wrapf(cur, -PI, PI) <= 0.0 else -1.0)
	pivot.rotation.y = cur + diff * minf(1.0, turn_speed * delta)


# ---------------------------------------------------------------- Yordamsal kemik pozu

func bone(bone_name: String) -> int:
	return skeleton.find_bone(bone_name) if skeleton != null else -1


func has_bone(bone_name: String) -> bool:
	return bone(bone_name) >= 0


## Kemiği MODEL uzayındaki `axis` etrafında `angle` (rad) döndür (bu kare için birikir).
func add_rotation(bone_idx: int, axis: Vector3, angle: float) -> void:
	if bone_idx < 0 or skeleton == null or absf(angle) < 0.00001:
		return
	var axis_skel := (_model_to_skel * axis).normalized()
	var axis_local := (_bone_basis_inv[bone_idx] * axis_skel).normalized()
	var q := Quaternion(axis_local, angle)
	_offsets[bone_idx] = (_offsets.get(bone_idx, Quaternion()) as Quaternion) * q


## Birikmiş ofsetleri iskelete yazar; bu kare dokunulmayan ama önceden dokunulan kemikler dinlenmeye döner.
func apply_pose() -> void:
	if skeleton == null:
		return
	for b: int in _touched:
		if not _offsets.has(b):
			skeleton.set_bone_pose_rotation(b, _rest_rot[b])
	for b: int in _offsets:
		skeleton.set_bone_pose_rotation(b, _rest_rot[b] * (_offsets[b] as Quaternion))
	_touched = _offsets
	_offsets = {}


## Kemiğin model uzayındaki dinlenme konumu (ölçekli).
func bone_rest_position(bone_idx: int) -> Vector3:
	if bone_idx < 0 or skeleton == null:
		return Vector3.ZERO
	return _skel_to_model() * skeleton.get_bone_global_rest(bone_idx).origin


## Kemiğin şu anki dünya konumu.
func bone_world_position(bone_idx: int) -> Vector3:
	if bone_idx < 0 or skeleton == null:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx).origin


## Test/teşhis: kemiğin dinlenmeden sapma açısı (rad).
func bone_pose_angle(bone_idx: int) -> float:
	if bone_idx < 0 or skeleton == null:
		return 0.0
	return _rest_rot[bone_idx].angle_to(skeleton.get_bone_pose_rotation(bone_idx))


func _cache_bones() -> void:
	var to_model := _skel_to_model()
	_model_to_skel = to_model.basis.orthonormalized().inverse()
	_rest_rot.clear()
	_bone_basis_inv.clear()
	for b in skeleton.get_bone_count():
		_rest_rot.append(skeleton.get_bone_rest(b).basis.get_rotation_quaternion())
		_bone_basis_inv.append(skeleton.get_bone_global_rest(b).basis.orthonormalized().inverse())


func _skel_to_model() -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = skeleton
	while n != null and n != model:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	if model != null:
		t = Transform3D(model.transform.basis, Vector3.ZERO) * t
	return t


func _make_unique() -> void:
	for mi: MeshInstance3D in meshes:
		if mi.material_override != null:
			mi.material_override = mi.material_override.duplicate()
			continue
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i)
			if m != null:
				mi.set_surface_override_material(i, m.duplicate())


func _collect_materials() -> void:
	_materials.clear()
	for mi: MeshInstance3D in meshes:
		if mi.material_override is ShaderMaterial:
			_materials.append(mi.material_override as ShaderMaterial)
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m != null and not _materials.has(m):
				_materials.append(m)
