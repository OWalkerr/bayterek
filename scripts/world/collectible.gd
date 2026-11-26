class_name Collectible
extends Area3D
## Kalıcı toplanabilir (docs/02): alınınca GameState bayrağı "oda_id/nesne_id" yazılır ve
## bir daha doğmaz (oda yeniden yüklense de, kayıttan dönülse de). Şimdilik tür: Kut Parçası.

const GROUP: StringName = &"collectible"
const MODEL_PATH: String = "res://assets/models/props/prop_kut_shard.glb"

@export var pickup_id: StringName = &"pickup"
@export var kind: StringName = &"kut_shard"
@export var color: Color = Color("e8a33d")
@export var spin_speed: float = 1.6

## Dönen görsel (model ya da greybox prizma).
var _mesh: Node3D
var model: ModelVisual
var _time: float = 0.0
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
	if kind == &"kut_shard" and ResourceLoader.exists(MODEL_PATH):
		# Model 0.5 m, tabanı orijinde → alanın ortasına gelsin diye yarı boy aşağı
		_mesh = Node3D.new()
		add_child(_mesh)
		model = ModelVisual.spawn(_mesh, MODEL_PATH, Vector3.BACK)
		model.position = Vector3.DOWN * 0.25
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
		var prism := PrismMesh.new()
		prism.size = Vector3(0.45, 0.7, 0.45)
		prism.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = prism
		_mesh = mi
		add_child(_mesh)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 4.0
	add_child(light)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	if _mesh != null:
		_mesh.rotate_y(spin_speed * delta)
		_mesh.position.y = sin(_time * 2.2) * 0.08


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
