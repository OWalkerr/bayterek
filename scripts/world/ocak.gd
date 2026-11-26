class_name Ocak
extends Area3D
## Kayıt noktası "Ocak" (docs/02): yanında yerdeyken YUKARI (W) → dinlen.
## Dinlenme: can dolar, son Ocak olarak işaretlenir, oyun kaydedilir, oda yeniden yüklenip
## düşmanlar yeniden doğar. Ölümde oyuncu son Ocak'ta tam canla dirilir (karar 2026-11-25).

const GROUP: StringName = &"ocak"
const MODEL_PATH: String = "res://assets/models/props/prop_ocak.glb"

@export var ocak_id: StringName = &"ocak"
@export var radius: float = 1.6
## Dinlenme anı (kontrol kilitli kısa oturma), sn.
@export var rest_time: float = 0.8
@export var fire_color: Color = Color("e8a33d")

var _player_inside: Player = null
var _prompt: Label3D
var _light: OmniLight3D
var _flame: Node3D
var _time: float = 0.0
var model: ModelVisual
var fire: CPUParticles3D
var embers: CPUParticles3D
var smoke: CPUParticles3D


func _ready() -> void:
	add_to_group(GROUP)
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = Layers.PLAYER
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 3.0
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3.UP * 1.5
	add_child(col)
	_build_visual()
	body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			_player_inside = b as Player)
	body_exited.connect(func(b: Node3D) -> void:
		if b == _player_inside:
			_player_inside = null)


## Ölümde/devam ederken oyuncunun konacağı yer.
func get_respawn_position() -> Vector3:
	return global_position + Vector3(1.0, 0.1, 0.0)


func is_player_near() -> bool:
	return _player_inside != null and is_instance_valid(_player_inside)


func _physics_process(_delta: float) -> void:
	_prompt.visible = is_player_near()
	if not is_player_near():
		return
	var p := _player_inside
	if p.state == Player.State.GROUND and Input.is_action_just_pressed(&"move_up"):
		rest()


func _process(delta: float) -> void:
	_time += delta
	# Titrek ateş ışığı: üç frekans + hafif konum oynaması (gölgeler canlı)
	_light.light_energy = 2.2 + sin(_time * 9.0) * 0.25 + sin(_time * 23.0) * 0.12 + sin(_time * 3.7) * 0.15
	_light.position = Vector3(sin(_time * 7.0) * 0.05, 1.0 + sin(_time * 5.0) * 0.04, cos(_time * 6.0) * 0.05)
	_flame.scale = Vector3.ONE * (1.0 + sin(_time * 11.0) * 0.06)


func rest() -> void:
	var room := get_parent() as Room
	if room == null:
		return
	GameState.rest_at(room.room_id, ocak_id)
	EventBus.ocak_rested.emit(room.room_id, ocak_id)
	SceneRouter.rest_at_ocak(room.room_id, ocak_id, rest_time)


func _build_visual() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		_build_model_visual()
		return
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color("4a3550")
	var ring := CylinderMesh.new()
	ring.top_radius = 0.7
	ring.bottom_radius = 0.8
	ring.height = 0.3
	ring.material = stone_mat
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = ring
	ring_mi.position = Vector3.UP * 0.15
	add_child(ring_mi)
	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = fire_color
	fire_mat.emission_enabled = true
	fire_mat.emission = fire_color
	fire_mat.emission_energy_multiplier = 3.0
	var flame := SphereMesh.new()
	flame.radius = 0.35
	flame.height = 0.9
	flame.material = fire_mat
	_flame = MeshInstance3D.new()
	_flame.mesh = flame
	_flame.position = Vector3.UP * 0.6
	add_child(_flame)
	_add_light_and_prompt()


## Model (taş halka, boy 0.56 m) + hareketli ateş: alev, kıvılcım, duman parçacıkları + iç parıltı.
func _build_model_visual() -> void:
	model = ModelVisual.spawn(self, MODEL_PATH, Vector3.BACK)
	_flame = Node3D.new()
	_flame.position = Vector3.UP * 0.35
	add_child(_flame)
	fire = FxLibrary.fire(1.0)
	fire.emitting = true
	_flame.add_child(fire)
	embers = FxLibrary.embers(1.0)
	embers.emitting = true
	embers.position = Vector3.UP * 0.3
	_flame.add_child(embers)
	smoke = FxLibrary.smoke(1.0)
	smoke.emitting = true
	smoke.position = Vector3.UP * 0.9
	_flame.add_child(smoke)
	# Közlerin sıcak çekirdeği (sabit, yumuşak)
	var core_mat := FxLibrary.particle_material(true).duplicate() as StandardMaterial3D
	core_mat.vertex_color_use_as_albedo = false
	core_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	core_mat.albedo_color = Color(1.0, 0.6, 0.2, 0.8)
	var core := QuadMesh.new()
	core.size = Vector2(1.0, 0.7)
	core.material = core_mat
	var core_mi := MeshInstance3D.new()
	core_mi.mesh = core
	core_mi.position = Vector3.UP * 0.05
	_flame.add_child(core_mi)
	_add_light_and_prompt()


func _add_light_and_prompt() -> void:
	_light = OmniLight3D.new()
	_light.light_color = fire_color
	_light.omni_range = 7.0
	_light.position = Vector3.UP * 1.0
	add_child(_light)
	_prompt = Label3D.new()
	_prompt.text = "W · Dinlen"
	_prompt.font_size = 48
	_prompt.outline_size = 12
	_prompt.modulate = Color("f4efe3")
	_prompt.outline_modulate = Color("2b1e3f")
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.position = Vector3.UP * 2.4
	_prompt.visible = false
	add_child(_prompt)
