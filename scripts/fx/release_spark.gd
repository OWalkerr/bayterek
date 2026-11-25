class_name ReleaseSpark
extends Node3D
## "Mükemmel bırakma" ışıltısı: kısa süre büyüyüp sönen altın ışık (docs/08 Juice listesi).

@export var duration: float = 0.4
@export var color: Color = Color("e8a33d")
@export var max_scale: float = 1.6
@export var light_energy: float = 4.0

var _t: float = 0.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _light: OmniLight3D


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 4.0
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	sphere.radial_segments = 12
	sphere.rings = 6
	sphere.material = _mat
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	add_child(_mesh)
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.omni_range = 5.0
	_light.light_energy = light_energy
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / duration, 0.0, 1.0)
	_mesh.scale = Vector3.ONE * lerpf(0.4, max_scale, k)
	_mat.albedo_color.a = 1.0 - k
	_light.light_energy = light_energy * (1.0 - k)
	if k >= 1.0:
		queue_free()
