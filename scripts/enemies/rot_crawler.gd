class_name RotCrawler
extends Enemy
## Çürük Sürüngen (docs/04): zeminde yürür, duvarda ve kenarda döner. "Vurabiliyor musun?"
## Durumlar: WALK (devriye), STAGGER (vurulunca kısa duraklama + geri itilme).

enum State { WALK, STAGGER }

@export var walk_speed: float = 2.0
@export var gravity: float = 30.0
## Kenar algılama: gövdenin bu kadar önünde zemin aranır.
@export var edge_probe: float = 0.6
@export var start_direction: float = 1.0

const MODEL_PATH: String = "res://assets/models/enemies/enm_rot_crawler.glb"

## Yürüyüş döngüsü: metre başına adım fazı (rad/m) ve genlikler (rad).
@export var stride_rate: float = 7.0
@export var leg_swing: float = 0.55
@export var spine_wave: float = 0.14
@export var tail_wave: float = 0.35

var state: State = State.WALK
var direction: float = 1.0
var model: ModelVisual
var _rail_z: float = 0.0
var _phase: float = 0.0
var _time: float = 0.0
var _b := {}


func _enemy_ready() -> void:
	direction = signf(start_direction) if start_direction != 0.0 else 1.0
	_rail_z = global_position.z
	floor_snap_length = 0.3
	if model != null:
		model.face_x(direction, true)


func _build_visual() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		# Model +X'e bakıyor (Tripo dört ayaklı); ölçek import'ta (boy 0.53 m, uzunluk 1.3 m)
		model = ModelVisual.spawn(visual, MODEL_PATH, Vector3.RIGHT, true)
		model.face_x(direction, true)
		for n: String in ["tripo__Spine_0", "tripo__Spine_1", "tripo__Head_0", "bone_13", "bone_14", "bone_15",
				"tripo__0_Left_Limb_0", "tripo__0_Left_Limb_1", "tripo__0_Right_Limb_0", "tripo__0_Right_Limb_1",
				"tripo__1_Left_Limb_0", "tripo__1_Left_Limb_1", "tripo__1_Right_Limb_0", "tripo__1_Right_Limb_1"]:
			_b[n] = model.bone(n)
	else:
		_build_greybox()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.6, 0.8)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.3, 0.0)
	add_child(col)
	hurtbox_size = Vector3(1.2, 0.8, 1.0)
	hurtbox_offset = Vector3(0.0, 0.4, 0.0)


func _build_greybox() -> void:
	var body := BoxMesh.new()
	body.size = Vector3(1.1, 0.6, 0.8)
	_mesh(body, Color("5a1e5c"), Vector3(0.0, 0.3, 0.0))
	var eye := SphereMesh.new()
	eye.radius = 0.09
	eye.height = 0.18
	_mesh(eye, Color("c9d93b"), Vector3(0.45, 0.45, 0.25), true)
	var eye2 := SphereMesh.new()
	eye2.radius = 0.09
	eye2.height = 0.18
	_mesh(eye2, Color("c9d93b"), Vector3(0.45, 0.45, -0.25), true)


func _enemy_physics(delta: float) -> void:
	state = State.STAGGER if is_staggered() else State.WALK
	match state:
		State.WALK:
			velocity.x = direction * walk_speed
		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	velocity.z = (_rail_z - global_position.z) * 10.0
	move_and_slide()

	if state == State.WALK and is_on_floor():
		if is_on_wall() or not _floor_ahead():
			direction = -direction
	if model != null:
		model.face_x(direction)
	else:
		visual.scale.x = direction


func _process(delta: float) -> void:
	if model == null or delta <= 0.0:
		return
	_time += delta
	_phase += absf(velocity.x) * stride_rate * delta / maxf(walk_speed, 0.1) * 2.0
	_animate()


## Yordamsal yürüyüş: çapraz adım (sol ön + sağ arka birlikte), omurga ve kuyruk dalgası,
## kafa salınımı; sersemleyince kafa geri kalkar. Eksenler model uzayında (+X ileri, +Y yukarı, Z yan).
func _animate() -> void:
	var walking := state == State.WALK and is_on_floor()
	var amp := 1.0 if walking else 0.25
	var p := _phase
	var side := Vector3.BACK    # Z ekseni: bacaklar X-Y düzleminde ileri-geri
	var up := Vector3.UP
	model.add_rotation(_b["tripo__0_Left_Limb_0"], side, sin(p) * leg_swing * amp)
	model.add_rotation(_b["tripo__1_Right_Limb_0"], side, sin(p) * leg_swing * amp)
	model.add_rotation(_b["tripo__0_Right_Limb_0"], side, -sin(p) * leg_swing * amp)
	model.add_rotation(_b["tripo__1_Left_Limb_0"], side, -sin(p) * leg_swing * amp)
	# diz: yalnız öne giderken bükülür (adım kaldırma)
	model.add_rotation(_b["tripo__0_Left_Limb_1"], side, maxf(0.0, cos(p)) * 0.5 * amp)
	model.add_rotation(_b["tripo__1_Right_Limb_1"], side, maxf(0.0, cos(p)) * 0.5 * amp)
	model.add_rotation(_b["tripo__0_Right_Limb_1"], side, maxf(0.0, -cos(p)) * 0.5 * amp)
	model.add_rotation(_b["tripo__1_Left_Limb_1"], side, maxf(0.0, -cos(p)) * 0.5 * amp)
	# omurga yana kıvrılır (kertenkele), kuyruk gecikmeli
	model.add_rotation(_b["tripo__Spine_0"], up, sin(p) * spine_wave * amp)
	model.add_rotation(_b["tripo__Spine_1"], up, -sin(p) * spine_wave * amp)
	model.add_rotation(_b["bone_13"], up, sin(p - 0.8) * tail_wave * 0.5 * amp)
	model.add_rotation(_b["bone_14"], up, sin(p - 1.6) * tail_wave * amp)
	model.add_rotation(_b["bone_15"], up, sin(p - 2.4) * tail_wave * amp)
	# kafa: hafif arama hareketi; sersemleyince geri kalkar
	var head_pitch := -0.45 if is_staggered() else sin(_time * 3.1) * 0.06
	model.add_rotation(_b["tripo__Head_0"], side, head_pitch)
	model.add_rotation(_b["tripo__Head_0"], up, sin(_time * 1.7) * 0.15)
	model.apply_pose()


## Test: model bağlı ve kemik oynuyor mu?
func get_model() -> ModelVisual:
	return model


func _floor_ahead() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(direction * edge_probe, 0.4, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.0, Layers.WORLD)
	return not space.intersect_ray(q).is_empty()
