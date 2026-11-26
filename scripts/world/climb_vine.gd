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
	# Gövde: birbirine sarılmış iki ince sap (tek düz çubuk yerine örgü hissi)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = vine_color
	mat.roughness = 0.9
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.07
	cyl.height = vine_length
	cyl.radial_segments = 6
	cyl.rings = maxi(2, int(vine_length * 2.0))
	cyl.material = mat
	for k in 2:
		var stem := MeshInstance3D.new()
		stem.mesh = cyl
		stem.position = Vector3((k * 2 - 1) * 0.035, -vine_length * 0.5, 0.0)
		stem.rotation.y = k * PI
		stem.rotation.z = (k * 2 - 1) * 0.01
		add_child(stem)

	# Yapraklar: tırmanılabilir olduğunu okunur kılan yassı, sivri uçlu yapraklar (elips + hafif kıvrım).
	# Konum ve açı sarmaşığın konumundan tohumlu → her açılışta aynı.
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = vine_color.lightened(0.12)
	leaf_mat.roughness = 0.85
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 0.5
	leaf_mesh.height = 1.0
	leaf_mesh.radial_segments = 8
	leaf_mesh.rings = 4
	leaf_mesh.material = leaf_mat
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(position.x * 10.0), int(position.y * 10.0)))
	var count := int(vine_length / leaf_spacing)
	for i in count:
		var side := 1.0 if i % 2 == 0 else -1.0
		var pivot := Node3D.new()
		pivot.position = Vector3(0.0, -leaf_spacing * (i + 0.5) + rng.randf_range(-0.12, 0.12), 0.0)
		pivot.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.5, 0.5), side * rng.randf_range(0.3, 0.55))
		add_child(pivot)
		var leaf := MeshInstance3D.new()
		leaf.mesh = leaf_mesh
		var length := rng.randf_range(0.42, 0.55)
		# Elips: uzun eksen dışarı doğru, kameraya bakan düzlemde yassı; sapın yanından başlar
		leaf.scale = Vector3(length, length * 0.42, 0.04)
		leaf.position = Vector3(side * length * 0.5, 0.0, 0.0)
		pivot.add_child(leaf)
