extends Node3D
## Oyun kabuğu (main.tscn kökü): ortam, oyuncu, kamera, debug HUD ve greybox oda yükleyici.
## Odalar `scripts/world/rooms/` altında GreyboxRoom alt sınıfları; 0–3 tuşlarıyla değişir.
## M4'te SceneRouter + gerçek Room/RoomDoor sistemiyle değiştirilecek.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ROOM_SCRIPTS: Array[Script] = [
	preload("res://scripts/world/rooms/room_00_kok_agzi.gd"),
	preload("res://scripts/world/rooms/room_01_savrulma.gd"),
	preload("res://scripts/world/rooms/room_02_tirmanma.gd"),
	preload("res://scripts/world/rooms/room_03_curuk.gd"),
]
const ROOM_NAMES: PackedStringArray = ["Kök Ağzı", "Savrulma Zinciri", "Tırmanma Kuyusu", "Çürük Geçit"]
## Başlangıç odası (M0 testleri Kök Ağzı koordinatlarını kullanır).
@export var start_room: int = 0

var player: Player
var rig: CameraRig
var hud: DebugHud
var room: GreyboxRoom
var room_index: int = -1


func _ready() -> void:
	_build_environment()
	_spawn_player()
	_build_camera()
	hud = DebugHud.new()
	add_child(hud)
	hud.setup(player, ROOM_NAMES)
	hud.room_requested.connect(load_room)
	EventBus.vine_released.connect(_on_vine_released)
	load_room(start_room)
	hud.show_room_menu(true)


func _physics_process(_delta: float) -> void:
	var moving := player.velocity.length() > 0.5 and player.is_on_floor()
	if moving:
		hud.start_room_timer()
		if hud.is_room_menu_visible():
			hud.show_room_menu(false)
	if Input.is_action_just_pressed(&"restart_room"):
		load_room(room_index)


func load_room(index: int) -> void:
	index = clampi(index, 0, ROOM_SCRIPTS.size() - 1)
	if room != null:
		remove_child(room)
		room.queue_free()
	room = ROOM_SCRIPTS[index].new() as GreyboxRoom
	room.name = "Room"
	room_index = index
	add_child(room)
	room.goal_reached.connect(_on_goal_reached)
	player.place_at(room.spawn_point)
	CameraDirector.reset_to_side()
	hud.show_room_menu(false)
	hud.on_room_loaded(index, room)
	GameState.current_room = room.room_id
	EventBus.room_changed.emit(room.room_id)


func _on_goal_reached() -> void:
	var key := "m1_best/%s" % room.room_id
	var best: float = GameState.get_flag(key, 0.0)
	if best <= 0.0 or hud.room_time < best:
		best = hud.room_time
		GameState.set_flag(key, best)
	hud.on_goal(best)
	EventBus.room_goal_reached.emit(room.room_id, hud.room_time)


func _on_vine_released(_anchor: Node3D, perfect: bool) -> void:
	if not perfect:
		return
	var spark := ReleaseSpark.new()
	add_child(spark)
	spark.global_position = player.global_position + Vector3.UP * Player.HAND_HEIGHT


# ---------------------------------------------------------------- Ortam

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("1d2a44")
	sky_mat.sky_horizon_color = Color("4a5d7a")
	sky_mat.ground_bottom_color = Color("120c1c")
	sky_mat.ground_horizon_color = Color("2b1e3f")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color("3a2d55")
	env.fog_density = 0.008
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_color = Color("ffe2b0")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)


# ---------------------------------------------------------------- Oyuncu & kamera

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as Player
	add_child(player)


func _build_camera() -> void:
	rig = CameraRig.new()
	rig.name = "CameraRig"
	rig.target = player
	add_child(rig)
