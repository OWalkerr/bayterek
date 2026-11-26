class_name SporeBloater
extends Enemy
## Spor Şişkini (docs/04): havada süzülür, oyuncu yaklaşınca yavaşça yatayda ona sürüklenir,
## vurulunca patlar ve zehirli spor bulutu bırakır. "Mesafeni koruyabiliyor musun?"
## Kamçı menzili (2.5 m) bulut yarıçapından (1.8 m) uzun → uzaktan vurmak güvenli.
## Durumlar: IDLE (süzülme), DRIFT (oyuncuya sürüklenme), STAGGER.

enum State { IDLE, DRIFT, STAGGER }

const CLOUD_SCRIPT: Script = preload("res://scripts/enemies/spore_cloud.gd")

@export var aggro_range: float = 6.0
@export var drift_speed: float = 1.0
@export var bob_height: float = 0.25
@export var bob_speed: float = 2.0
## Yuvasından en fazla bu kadar uzaklaşır.
@export var leash: float = 5.0

const MODEL_PATH: String = "res://assets/models/enemies/enm_spore_bloater.glb"

## Nefes (ölçek nabzı) genliği ve hızı; vurulunca şişme.
@export var breathe_amount: float = 0.06
@export var breathe_speed: float = 2.4

var state: State = State.IDLE
var model: ModelVisual
var _time: float = 0.0
var _swell: float = 0.0


func _enemy_ready() -> void:
	max_hp = 1
	hp = 1
	_time = randf() * TAU


func _build_visual() -> void:
	hurtbox_size = Vector3(1.1, 1.1, 1.1)
	hurtbox_offset = Vector3.ZERO
	if ResourceLoader.exists(MODEL_PATH):
		# Rigsiz model (boy 1.1 m, orijin dipte) → gövde merkezi düğüm konumuna gelsin
		model = ModelVisual.spawn(visual, MODEL_PATH, Vector3.BACK, true)
		model.position = Vector3.DOWN * 0.55
		return
	var body := SphereMesh.new()
	body.radius = 0.5
	body.height = 1.0
	_mesh(body, Color("7a3a7c"), Vector3.ZERO)
	for offset: Vector3 in [Vector3(0.3, 0.25, 0.3), Vector3(-0.3, 0.1, 0.32), Vector3(0.0, -0.3, 0.35)]:
		var spot := SphereMesh.new()
		spot.radius = 0.1
		spot.height = 0.2
		_mesh(spot, Color("c9d93b"), offset, true)


## Yordamsal: nefes alır gibi şişip söner (dikeyde tersine: ezil-uza), yalpalar, oyuncuya doğru
## sürüklenirken o yana eğilir; vurulunca bir an şişer (patlamadan önceki okunur an).
func _process(delta: float) -> void:
	if model == null or delta <= 0.0:
		return
	_swell = move_toward(_swell, 0.0, delta * 3.0)
	var b := sin(_time * breathe_speed) * breathe_amount
	var s := 1.0 + _swell * 0.35
	visual.scale = Vector3(s * (1.0 + b), s * (1.0 - b * 0.8), s * (1.0 + b))
	var lean := clampf(-velocity.x * 0.25, -0.35, 0.35)
	visual.rotation.z = lerpf(visual.rotation.z, lean + sin(_time * 1.3) * 0.08, minf(1.0, delta * 4.0))
	visual.rotation.x = sin(_time * 1.1 + 1.0) * 0.06


func _on_hit(_damage: int, _from: Vector3) -> void:
	_swell = 1.0


func _enemy_physics(delta: float) -> void:
	_time += delta
	var player := _find_player()
	if is_staggered():
		state = State.STAGGER
	elif player != null and player.global_position.distance_to(global_position) < aggro_range:
		state = State.DRIFT
	else:
		state = State.IDLE

	var target_x := home_position.x
	match state:
		State.DRIFT:
			target_x = clampf(player.global_position.x, home_position.x - leash, home_position.x + leash)
		State.STAGGER:
			velocity = velocity.move_toward(Vector3.ZERO, 10.0 * delta)
	if state != State.STAGGER:
		var target_y := home_position.y + sin(_time * bob_speed) * bob_height
		velocity.x = clampf((target_x - global_position.x) * 2.0, -drift_speed, drift_speed)
		velocity.y = (target_y - global_position.y) * 4.0
		velocity.z = (home_position.z - global_position.z) * 4.0
	move_and_slide()


func _on_die() -> void:
	var cloud := CLOUD_SCRIPT.new() as Node3D
	get_parent().add_child(cloud)
	cloud.global_position = global_position
