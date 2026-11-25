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

var state: State = State.WALK
var direction: float = 1.0
var _rail_z: float = 0.0


func _enemy_ready() -> void:
	direction = signf(start_direction) if start_direction != 0.0 else 1.0
	_rail_z = global_position.z
	floor_snap_length = 0.3


func _build_visual() -> void:
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
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.6, 0.8)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.3, 0.0)
	add_child(col)
	hurtbox_size = Vector3(1.2, 0.8, 1.0)
	hurtbox_offset = Vector3(0.0, 0.4, 0.0)


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
	visual.scale.x = direction


func _floor_ahead() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(direction * edge_probe, 0.4, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.0, Layers.WORLD)
	return not space.intersect_ray(q).is_empty()
