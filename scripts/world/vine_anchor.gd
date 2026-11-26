class_name VineAnchor
extends Node3D
## Sallanma sarmaşığı. Düğüm konumu = sarmaşığın tutturulduğu nokta (dal/kök).
## Sarmaşık `vine_length` kadar aşağı sarkar; oyuncu bu çizginin herhangi bir yerinden tutunabilir.

const GROUP: StringName = &"vine_anchor"

@export var vine_length: float = 3.0
@export var enabled: bool = true
@export var vine_color: Color = Color("5e8c4a")
@export var idle_sway: float = 0.12
@export var idle_sway_speed: float = 1.3

var _grabbed: bool = false
var _time: float = 0.0
var _vine_mesh: MeshInstance3D
var _knot: MeshInstance3D
var _vine_material: StandardMaterial3D
var _hand_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group(GROUP)
	_time = randf() * TAU
	_build_visual()
	_set_vine_end(global_position + Vector3.DOWN * vine_length)


func _process(delta: float) -> void:
	_time += delta
	if _grabbed:
		return
	var sway := Vector3(sin(_time * idle_sway_speed) * idle_sway, 0.0, 0.0)
	_set_vine_end(global_position + Vector3.DOWN * vine_length + sway + _hand_offset)


## Bir noktanın sarmaşık çizgisine (tutturma noktası → uç) en kısa mesafesi.
func distance_to_vine(point: Vector3) -> float:
	var a := global_position
	var b := global_position + Vector3.DOWN * vine_length
	var ab := b - a
	var t := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point.distance_to(a + ab * t)


func is_grabbed() -> bool:
	return _grabbed


func set_grabbed(value: bool) -> void:
	if value == _grabbed:
		return
	_grabbed = value
	_on_grab_changed(value)


## Rengi çalışma zamanında değişen sarmaşıklar (RottenVine) stilize edilmez.
func _vine_color_changes() -> bool:
	return false


## Alt sınıflar (ör. RottenVine) için kanca.
func _on_grab_changed(_value: bool) -> void:
	pass


func update_vine_visual(hand_position: Vector3) -> void:
	_set_vine_end(hand_position + _hand_offset)


func _build_visual() -> void:
	_vine_material = StandardMaterial3D.new()
	_vine_material.albedo_color = vine_color
	_vine_material.roughness = 0.9
	if _vine_color_changes():
		_vine_material.set_meta(Stylizer.META_SKIP, true)

	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.05
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.material = _vine_material
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
	_knot = MeshInstance3D.new()
	_knot.mesh = knot
	add_child(_knot)


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
