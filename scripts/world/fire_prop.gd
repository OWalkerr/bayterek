class_name FireProp
extends Node3D
## Yanan süs: taş mangal (`&"brazier"`) ya da duvar meşalesi (`&"torch"`). Çarpışmasız.
## Model (prop_brazier / prop_torch_wall) + kodla ateş (FxLibrary alev/kıvılcım/duman) + titreyen ışık
## (Ocak'taki ateşle aynı dil). Model yoksa basit greybox yedeği. Düğüm konumu = ayak tabanı (mangal)
## ya da duvara tutturma noktasının altı (meşale); meşale `rotation.y` ile odaya döndürülür.

const GROUP: StringName = &"fire_prop"
const BRAZIER_PATH: String = "res://assets/models/props/prop_brazier.glb"
const TORCH_PATH: String = "res://assets/models/props/prop_torch_wall.glb"

@export var kind: StringName = &"brazier"
@export var fire_color: Color = Color("e8a33d")
@export var light_energy: float = 1.8
@export var light_range: float = 6.5
## Alevin ayak tabanına göre yüksekliği ve ölçeği (tür başına varsayılan; 0 = varsayılanı kullan).
@export var flame_height: float = 0.0
@export var flame_scale: float = 0.0

var model: ModelVisual
var fire: CPUParticles3D
var embers: CPUParticles3D
var smoke: CPUParticles3D
var light: OmniLight3D
var _time: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_phase = fposmod(global_position.x * 1.7 + global_position.y * 0.9, TAU)
	var is_torch := kind == &"torch"
	var path := TORCH_PATH if is_torch else BRAZIER_PATH
	var h := flame_height if flame_height > 0.0 else (0.78 if is_torch else 0.72)
	var s := flame_scale if flame_scale > 0.0 else (0.45 if is_torch else 0.8)
	if ResourceLoader.exists(path):
		model = ModelVisual.spawn(self, path, Vector3.BACK)
	else:
		_build_fallback(is_torch, h)
	var flame := Node3D.new()
	flame.name = "Flame"
	flame.position = Vector3.UP * h
	add_child(flame)
	fire = FxLibrary.fire(s)
	fire.emitting = true
	flame.add_child(fire)
	embers = FxLibrary.embers(s)
	embers.emitting = true
	embers.position = Vector3.UP * 0.25 * s
	flame.add_child(embers)
	smoke = FxLibrary.smoke(s)
	smoke.emitting = true
	smoke.position = Vector3.UP * 0.8 * s
	flame.add_child(smoke)
	light = OmniLight3D.new()
	light.light_color = fire_color
	light.light_energy = light_energy
	light.omni_range = light_range
	light.position = Vector3.UP * (h + 0.3)
	add_child(light)


func _process(delta: float) -> void:
	_time += delta
	var t := _time + _phase
	light.light_energy = light_energy * (1.0 + sin(t * 9.0) * 0.11 + sin(t * 23.0) * 0.05 + sin(t * 3.7) * 0.07)


func _build_fallback(is_torch: bool, h: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("4a3550")
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.08 if is_torch else 0.45
	mesh.bottom_radius = 0.06 if is_torch else 0.3
	mesh.height = h
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3.UP * h * 0.5
	add_child(mi)
