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

var state: State = State.IDLE
var _time: float = 0.0


func _enemy_ready() -> void:
	max_hp = 1
	hp = 1
	_time = randf() * TAU


func _build_visual() -> void:
	var body := SphereMesh.new()
	body.radius = 0.5
	body.height = 1.0
	_mesh(body, Color("7a3a7c"), Vector3.ZERO)
	for offset: Vector3 in [Vector3(0.3, 0.25, 0.3), Vector3(-0.3, 0.1, 0.32), Vector3(0.0, -0.3, 0.35)]:
		var spot := SphereMesh.new()
		spot.radius = 0.1
		spot.height = 0.2
		_mesh(spot, Color("c9d93b"), offset, true)
	hurtbox_size = Vector3(1.1, 1.1, 1.1)
	hurtbox_offset = Vector3.ZERO


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
