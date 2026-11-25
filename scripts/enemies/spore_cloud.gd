class_name SporeCloud
extends Area3D
## Spor Şişkini patlayınca kalan zehirli bulut. `arm_time` boyunca büyür (okunur uyarı,
## docs/04: telegraph), sonra `lifetime` boyunca içindeki oyuncuya hasar verir.

const GROUP: StringName = &"spore_cloud"

@export var radius: float = 1.8
@export var arm_time: float = 0.3
@export var lifetime: float = 2.0
@export var damage: int = 1
@export var color: Color = Color("c9d93b")

var _t: float = 0.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = Layers.HAZARD
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false
	var shape := SphereShape3D.new()
	shape.radius = radius
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(color, 0.35)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.material = _mat
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	add_child(_mesh)


func is_armed() -> bool:
	return _t >= arm_time


func _physics_process(delta: float) -> void:
	_t += delta
	var grow := clampf(_t / arm_time, 0.2, 1.0)
	_mesh.scale = Vector3.ONE * grow
	var fade := clampf((arm_time + lifetime - _t) / 0.4, 0.0, 1.0)
	_mat.albedo_color.a = 0.35 * fade
	if is_armed():
		for body: Node3D in get_overlapping_bodies():
			var player := body as Player
			if player != null:
				player.take_damage(damage, global_position)
	if _t >= arm_time + lifetime:
		queue_free()
