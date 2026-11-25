class_name AbilityShrine
extends Area3D
## Yetenek sunağı (M5): dokununca yetenek açılır (GameState.unlock_ability), kaydedilir ve
## "yetenek kazanma" anı gösterilir (docs/08). Yetenek zaten varsa sunak sönük durur.

const GROUP: StringName = &"ability_shrine"

@export var ability_id: StringName = &"whip_grapple"
@export var color: Color = Color("e8a33d")

var _orb: MeshInstance3D
var _light: OmniLight3D
var _time: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = Layers.PLAYER
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 3.0, 3.0)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3.UP * 1.5
	add_child(col)
	_build_visual()
	_refresh()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	if _orb.visible:
		_orb.position.y = 1.6 + sin(_time * 2.0) * 0.12


func _refresh() -> void:
	var taken := GameState.has_ability(ability_id)
	_orb.visible = not taken
	_light.light_energy = 0.4 if taken else 2.5


func _on_body_entered(body: Node3D) -> void:
	if not body is Player or GameState.has_ability(ability_id):
		return
	GameState.unlock_ability(ability_id)
	GameState.autosave()
	_refresh()


func _build_visual() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("4a3550")
	var base := CylinderMesh.new()
	base.top_radius = 0.6
	base.bottom_radius = 0.8
	base.height = 1.0
	base.material = stone
	var base_mi := MeshInstance3D.new()
	base_mi.mesh = base
	base_mi.position = Vector3.UP * 0.5
	add_child(base_mi)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	var orb := SphereMesh.new()
	orb.radius = 0.35
	orb.height = 0.7
	orb.material = mat
	_orb = MeshInstance3D.new()
	_orb.mesh = orb
	_orb.position = Vector3.UP * 1.6
	add_child(_orb)
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.omni_range = 6.0
	_light.position = Vector3.UP * 1.8
	add_child(_light)
