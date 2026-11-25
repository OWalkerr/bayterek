class_name ClimbVine
extends Node3D
## Tırmanma sarmaşığı: düğüm konumu = sarmaşığın ÜST ucu; `vine_length` kadar dikey aşağı iner.
## Oyuncu üzerinde yukarı/aşağı tırmanır, yana zıplayarak ayrılır (docs/03 §2.1).

const GROUP: StringName = &"climb_vine"

@export var vine_length: float = 6.0
@export var enabled: bool = true
@export var vine_color: Color = Color("3f7a3a")
@export var leaf_spacing: float = 0.9


func _ready() -> void:
	add_to_group(GROUP)
	_build_visual()


func get_top() -> Vector3:
	return global_position


func get_bottom() -> Vector3:
	return global_position + Vector3.DOWN * vine_length


## El noktasının sarmaşık çizgisine en kısa mesafesi.
func distance_to_vine(point: Vector3) -> float:
	return point.distance_to(closest_point(point))


func closest_point(point: Vector3) -> Vector3:
	var top := get_top()
	var y := clampf(point.y, top.y - vine_length, top.y)
	return Vector3(top.x, y, top.z)


func _build_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = vine_color
	mat.roughness = 0.9
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.08
	cyl.height = vine_length
	cyl.radial_segments = 6
	cyl.material = mat
	var stem := MeshInstance3D.new()
	stem.mesh = cyl
	stem.position = Vector3.DOWN * vine_length * 0.5
	add_child(stem)

	# Yapraklar: tırmanılabilir olduğunu okunur kılan küçük çıkıntılar
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = vine_color.lightened(0.25)
	var leaf_mesh := BoxMesh.new()
	leaf_mesh.size = Vector3(0.35, 0.08, 0.12)
	leaf_mesh.material = leaf_mat
	var count := int(vine_length / leaf_spacing)
	for i in count:
		var leaf := MeshInstance3D.new()
		leaf.mesh = leaf_mesh
		var side := 1.0 if i % 2 == 0 else -1.0
		leaf.position = Vector3(side * 0.16, -leaf_spacing * (i + 0.5), 0.0)
		leaf.rotation.z = side * 0.4
		add_child(leaf)
