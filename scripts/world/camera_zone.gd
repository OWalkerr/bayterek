class_name CameraZone
extends Area3D
## Oyuncu girince kamera modunu değiştirir (ör. mağara ağzında DEPTH), çıkınca SIDE'a döner.

@export var mode: CameraRig.Mode = CameraRig.Mode.DEPTH
@export var transition_duration: float = 1.0
@export var depth_yaw_degrees: float = 0.0
## Çarpışma şekli yoksa bu boyutta kutu oluşturulur.
@export var size: Vector3 = Vector3(6, 6, 6)


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = Layers.PLAYER
	if get_child_count() == 0 or not _has_shape():
		var shape := BoxShape3D.new()
		shape.size = size
		var col := CollisionShape3D.new()
		col.shape = shape
		add_child(col)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _has_shape() -> bool:
	for child: Node in get_children():
		if child is CollisionShape3D:
			return true
	return false


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		CameraDirector.set_mode(mode, transition_duration, depth_yaw_degrees)


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		CameraDirector.set_mode(CameraRig.Mode.SIDE, transition_duration)
