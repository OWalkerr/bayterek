class_name SpiritLantern
extends Node3D
## Tavandan asılı ruh kandili (süs, çarpışmasız). Düğüm konumu = asıldığı nokta; kandil `drop` m
## aşağıda ince bir ipe bağlı, yavaşça salınır ve turkuaz ışık nefes alır. Model: prop_spirit_lantern.

const GROUP: StringName = &"spirit_lantern"
const MODEL_PATH: String = "res://assets/models/props/prop_spirit_lantern.glb"

@export var drop: float = 0.8
@export var light_color: Color = Color("4fb3a9")
@export var light_energy: float = 1.2
@export var light_range: float = 4.5
## Salınım genliği (derece) ve hızı (rad/sn).
@export var sway_deg: float = 4.0
@export var sway_speed: float = 1.1

var pivot: Node3D
var model: ModelVisual
var light: OmniLight3D
var _time: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_phase = fposmod(global_position.x * 2.3, TAU)
	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	var cord_mat := StandardMaterial3D.new()
	cord_mat.albedo_color = Color("3a2838")
	var cord := CylinderMesh.new()
	cord.top_radius = 0.015
	cord.bottom_radius = 0.015
	cord.height = drop
	cord.radial_segments = 6
	cord.material = cord_mat
	var cord_mi := MeshInstance3D.new()
	cord_mi.mesh = cord
	cord_mi.position = Vector3.DOWN * drop * 0.5
	pivot.add_child(cord_mi)
	var body := Node3D.new()
	body.position = Vector3.DOWN * (drop + 0.6)   # model boyu 0.6 m, tabanı orijinde
	pivot.add_child(body)
	if ResourceLoader.exists(MODEL_PATH):
		model = ModelVisual.spawn(body, MODEL_PATH, Vector3.BACK)
	light = OmniLight3D.new()
	light.light_color = light_color
	light.light_energy = light_energy
	light.omni_range = light_range
	light.position = Vector3.UP * 0.25
	body.add_child(light)


func _process(delta: float) -> void:
	_time += delta
	var t := _time * sway_speed + _phase
	pivot.rotation = Vector3(deg_to_rad(sway_deg) * 0.4 * sin(t * 0.7), 0.0, deg_to_rad(sway_deg) * sin(t))
	light.light_energy = light_energy * (1.0 + 0.15 * sin(_time * 1.6 + _phase))
