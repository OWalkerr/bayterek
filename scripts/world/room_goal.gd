class_name RoomGoal
extends Area3D
## Odanın "dikey hedefi" (docs/02 Oda Kuralı 2): oyuncu değince `reached` yayar.
## Görsel: parlayan, dönen bir Öz kristali + ışık.

const GROUP: StringName = &"room_goal"
const MODEL_PATH: String = "res://assets/models/props/prop_oz_crystal.glb"

signal reached

@export var size: Vector3 = Vector3(1.5, 2.0, 3.0)
@export var color: Color = Color("f4efe3")
@export var spin_speed: float = 1.2

var _done: bool = false
## Dönen görsel (Öz kristali modeli ya da greybox küp).
var _crystal: Node3D
var model: ModelVisual


func _ready() -> void:
	add_to_group(GROUP)
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = Layers.PLAYER
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3.UP * size.y * 0.5
	add_child(col)

	if ResourceLoader.exists(MODEL_PATH):
		# Öz kristali (1.2 m, kök kaidesiyle) yerde durur, yavaşça döner
		_crystal = Node3D.new()
		add_child(_crystal)
		model = ModelVisual.spawn(_crystal, MODEL_PATH, Vector3.BACK)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.6, 0.6, 0.6)
		mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3.UP * 0.9
		mi.rotation_degrees = Vector3(45.0, 45.0, 0.0)
		_crystal = mi
		add_child(_crystal)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.position = Vector3.UP * 1.2
	add_child(light)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_crystal.rotate_y(spin_speed * delta)


func is_reached() -> bool:
	return _done


func _on_body_entered(body: Node3D) -> void:
	if _done or not body is Player:
		return
	_done = true
	reached.emit()
