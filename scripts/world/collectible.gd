class_name Collectible
extends Area3D
## Kalıcı toplanabilir (docs/02): alınınca GameState bayrağı "oda_id/nesne_id" yazılır ve
## bir daha doğmaz (oda yeniden yüklense de, kayıttan dönülse de). Şimdilik tür: Kut Parçası.

const GROUP: StringName = &"collectible"

@export var pickup_id: StringName = &"pickup"
@export var kind: StringName = &"kut_shard"
@export var color: Color = Color("e8a33d")
@export var spin_speed: float = 1.6

var _mesh: MeshInstance3D
var _taken: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	var room := get_parent() as Room
	if room != null and GameState.get_flag(room.flag_key(pickup_id), false):
		queue_free()
		return
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = Layers.PLAYER
	var shape := SphereShape3D.new()
	shape.radius = 0.8
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	var prism := PrismMesh.new()
	prism.size = Vector3(0.45, 0.7, 0.45)
	prism.material = mat
	_mesh = MeshInstance3D.new()
	_mesh.mesh = prism
	add_child(_mesh)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 4.0
	add_child(light)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _mesh != null:
		_mesh.rotate_y(spin_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	if _taken or not body is Player:
		return
	var room := get_parent() as Room
	if room == null:
		return
	_taken = true
	GameState.set_flag(room.flag_key(pickup_id), true)
	if kind == &"kut_shard":
		GameState.kut_shards += 1
	EventBus.collectible_picked.emit(room.room_id, pickup_id, kind)
	GameState.autosave()
	queue_free()
