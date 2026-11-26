class_name KocabasNpc
extends Node3D
## Kocabaş (docs/01): dev kök kaplumbağası, Alpay'ın koruyucusu. Eğitim odasında (Kök Ağzı)
## oyun alanının arkasında dinlenir. Yordamsal canlılık: nefes (kabuk yavaşça kalkıp iner),
## boyun + kafa oyuncuyu izler (sınırlı açı), ara sıra kafa sallar / ön ayağını kıpırdatır, kuyruk.
## Çarpışmasız; oynanışa karışmaz.

const MODEL_PATH: String = "res://assets/models/characters/npc_kocabas.glb"

## +1 sağa, -1 sola bakar.
@export var facing: float = -1.0
@export var look_range: float = 14.0
@export var max_neck_yaw: float = 0.7
@export var breathe_speed: float = 0.9

var model: ModelVisual
var _time: float = 0.0
var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
var _nod_timer: float = 3.0
var _nod: float = 0.0
var _b := {}


func _ready() -> void:
	if not ResourceLoader.exists(MODEL_PATH):
		return
	model = ModelVisual.spawn(self, MODEL_PATH, Vector3.RIGHT)
	model.face_x(facing, true)
	for n: String in ["tripo__Root", "tripo__Spine_1", "tripo__Head_0", "tripo__Head_1", "tripo__0_Left_Limb_0",
			"tripo__0_Right_Limb_0", "tripo__0_Left_Limb_1", "bone_18", "bone_19"]:
		_b[n] = model.bone(n)
	_time = randf() * 10.0


func _process(delta: float) -> void:
	if model == null or delta <= 0.0:
		return
	_time += delta
	var side := Vector3.BACK
	var up := Vector3.UP
	# Nefes: kabuk (kök kemik) hafif kalkar, öne-arkaya çok az yalpalar
	var br := sin(_time * breathe_speed)
	model.pivot.position.y = br * 0.025
	model.add_rotation(_b["tripo__Root"], side, br * 0.012)
	# Oyuncuyu izle: hedef yön model uzayına çevrilir (model +X'e bakıyor)
	var yaw_t := sin(_time * 0.3) * 0.25
	var pitch_t := 0.0
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	if p != null:
		var head_world := model.bone_world_position(_b["tripo__Head_0"])
		var to := p.global_position + Vector3.UP * 1.0 - head_world
		if to.length() < look_range:
			var local := (model.pivot.global_transform.basis.orthonormalized().inverse() * to)
			yaw_t = clampf(atan2(-local.z, local.x), -max_neck_yaw, max_neck_yaw)
			pitch_t = clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.5, 0.4)
	_look_yaw = lerpf(_look_yaw, yaw_t, minf(1.0, delta * 1.5))
	_look_pitch = lerpf(_look_pitch, pitch_t, minf(1.0, delta * 1.5))
	model.add_rotation(_b["tripo__Spine_1"], up, _look_yaw * 0.6)
	model.add_rotation(_b["tripo__Head_0"], up, _look_yaw * 0.4)
	model.add_rotation(_b["tripo__Spine_1"], side, _look_pitch * 0.5)
	model.add_rotation(_b["tripo__Head_0"], side, _look_pitch * 0.5)
	# Ara sıra yavaş baş sallama (onaylar gibi) + ön ayak kıpırtısı
	_nod_timer -= delta
	if _nod_timer <= 0.0:
		_nod_timer = randf_range(4.0, 8.0)
		_nod = 1.0
	_nod = move_toward(_nod, 0.0, delta * 0.8)
	var nod := sin((1.0 - _nod) * TAU) * 0.18 * _nod
	model.add_rotation(_b["tripo__Head_1"], side, nod)
	model.add_rotation(_b["tripo__0_Left_Limb_0"], side, sin(_time * 0.5) * 0.04)
	model.add_rotation(_b["tripo__0_Left_Limb_1"], side, maxf(0.0, sin(_time * 0.5 - 1.0)) * 0.06)
	model.add_rotation(_b["bone_18"], up, sin(_time * 1.2) * 0.2)
	model.add_rotation(_b["bone_19"], up, sin(_time * 1.2 - 0.8) * 0.3)
	model.apply_pose()
