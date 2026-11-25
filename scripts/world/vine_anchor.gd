class_name VineAnchor
extends Node3D
## Sallanma sarmaşığı. Düğüm konumu = sarmaşığın tutturulduğu nokta (dal/kök).
## Sarmaşık `vine_length` kadar aşağı sarkar; oyuncu bu çizginin herhangi bir yerinden tutunabilir.

const GROUP: StringName = &"vine_anchor"

@export var vine_length: float = 3.0
@export var enabled: bool = true
@export var vine_color: Color = Color("5e8c4a")
@export var idle_sway: float = 0.12

var _grabbed: bool = false
var _time: float = 0.0
var _vine_mesh: MeshInstance3D


func _ready() -> void:
	add_to_group(GROUP)
	_time = randf() * TAU
	_build_visual()
	_set_vine_end(global_position + Vector3.DOWN * vine_length)


func _process(delta: float) -> void:
	if _grabbed:
		return
	_time += delta
	var sway := Vector3(sin(_time * 1.3) * idle_sway, 0.0, 0.0)
	_set_vine_end(global_position + Vector3.DOWN * vine_length + sway)


## Bir noktanın sarmaşık çizgisine (tutturma noktası → uç) en kısa mesafesi.
func distance_to_vine(point: Vector3) -> float:
	var a := global_position
	var b := global_position + Vector3.DOWN * vine_length
	var ab := b - a
	var t := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point.distance_to(a + ab * t)


func set_grabbed(value: bool) -> void:
	_grabbed = value


func update_vine_visual(hand_position: Vector3) -> void:
	_set_vine_end(hand_position)


func _build_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = vine_color
	mat.roughness = 0.9

	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.05
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.material = mat
	_vine_mesh = MeshInstance3D.new()
	_vine_mesh.mesh = cyl
	_vine_mesh.top_level = true
	add_child(_vine_mesh)

	var knot_mat := StandardMaterial3D.new()
	knot_mat.albedo_color = Color("6b4a2f")
	var knot := SphereMesh.new()
	knot.radius = 0.22
	knot.height = 0.44
	knot.material = knot_mat
	var knot_instance := MeshInstance3D.new()
	knot_instance.mesh = knot
	add_child(knot_instance)


func _set_vine_end(end_point: Vector3) -> void:
	var start := global_position
	var dir := end_point - start
	var length := dir.length()
	if length < 0.01:
		return
	var y := dir / length
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	_vine_mesh.global_transform = Transform3D(Basis(x, y * length, z), start + dir * 0.5)
