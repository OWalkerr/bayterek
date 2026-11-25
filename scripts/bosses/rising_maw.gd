class_name RisingMaw
extends Node3D
## Faz 3 kovalamacası: Kökyiyen'in ağzı kuyunun dibinden yükselir (yan mod).
## Öldürmez (karar 2026-11-25): değerse 1 yaprak + oyuncu yukarı fırlatılır + ağız 1.5 sn duraklar
## ve 3 m geri çekilir (fırlatılan oyuncu tekrar düşse bile ağza değmez → ölüm döngüsü yok).
## Kuyu zemini ağız gelene kadar durur. Lastik bant: oyuncu çok yukardaysa hızlanır, çok yakınsa yavaşlar.

signal reached_top

@export var width: float = 16.0
@export var base_speed: float = 2.2
@export var far_speed: float = 4.0
@export var near_speed: float = 1.0
@export var far_gap: float = 14.0
@export var near_gap: float = 4.0
@export var hit_bounce: float = 16.0
@export var hit_pause: float = 1.5
@export var hit_drop: float = 3.0
## Ağzın durduğu en üst yükseklik (tepe çıkıntısının hemen altı).
@export var stop_y: float = 33.0

var running: bool = false
## Kuyu zemini: ağız ona ulaşınca kırılır (oyuncuya tırmanmaya başlamak için ≈ 3 sn verir).
var floor_body: Node3D = null
var floor_y: float = 0.0
var top_y: float = -6.0
var _pause: float = 0.0
var _hazard: BossHazard
var _mesh: MeshInstance3D
var _player: Player


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("5a1e5c")
	mat.emission_enabled = true
	mat.emission = Color("c9d93b")
	mat.emission_energy_multiplier = 0.4
	var box := BoxMesh.new()
	box.size = Vector3(width, 20.0, 4.0)
	box.material = mat
	_mesh = MeshInstance3D.new()
	_mesh.mesh = box
	_mesh.position = Vector3.DOWN * 10.0
	add_child(_mesh)
	_hazard = BossHazard.new()
	add_child(_hazard)
	_hazard.set_box(Vector3(width, 1.6, 4.0), Vector3.DOWN * 0.6)
	_hazard.player_hit.connect(_on_player_hit)
	_hazard.active = false
	position.y = top_y


func start(player: Player) -> void:
	_player = player
	running = true
	_hazard.active = true


func stop() -> void:
	running = false
	_hazard.active = false


func current_speed() -> float:
	if _player == null:
		return base_speed
	var gap := _player.global_position.y - top_y
	if gap > far_gap:
		return far_speed
	if gap < near_gap:
		return near_speed
	return base_speed


func _physics_process(delta: float) -> void:
	if not running:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	top_y = minf(top_y + current_speed() * delta, stop_y)
	position.y = top_y
	if is_instance_valid(floor_body) and top_y >= floor_y - 0.3:
		floor_body.queue_free()
		floor_body = null
		EventBus.boss_phase_message.emit("Zemin çöktü — tırman!")
	if top_y >= stop_y:
		reached_top.emit()


func _on_player_hit(p: Player) -> void:
	p.velocity.y = hit_bounce
	_pause = hit_pause
	top_y -= hit_drop
	position.y = top_y
