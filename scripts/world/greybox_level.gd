extends Node3D
## Oyun kabuğu (main.tscn kökü): ortam, oyuncu, kamera, HUD'lar, harita ve SceneRouter'ın "host"u
## (oda sahnesini takar/çıkarır, oyuncuyu yerleştirir). Oda geçişlerini SceneRouter yönetir.
## Açılışta arka planda Kök Ağzı yüklenir ve menü açılır: Yeni Oyun / Devam / geliştirici odaları (0–7).

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
## Açılışta yüklenen geliştirici odası (M0–M3 testleri Kök Ağzı koordinatlarını kullanır).
@export var start_room: int = 0
## Can bitince dirilmeden önce bekleme.
@export var death_restart_delay: float = 1.2

var player: Player
var rig: CameraRig
var hud: DebugHud
var room: GreyboxRoom
var room_index: int = -1
var game_hud: GameHud
var map_screen: MapScreen
var ability_toast: AbilityToast
var boss_card: BossCard
var story_card: StoryCard
var _death_timer: float = -1.0


func _ready() -> void:
	_build_environment()
	_spawn_player()
	_build_camera()
	hud = DebugHud.new()
	add_child(hud)
	hud.setup(player, RoomRegistry.DEV_ROOM_NAMES)
	hud.room_requested.connect(load_room)
	hud.new_game_requested.connect(new_game)
	hud.continue_requested.connect(continue_game)
	game_hud = GameHud.new()
	add_child(game_hud)
	map_screen = MapScreen.new()
	add_child(map_screen)
	ability_toast = AbilityToast.new()
	add_child(ability_toast)
	boss_card = BossCard.new()
	add_child(boss_card)
	story_card = StoryCard.new()
	add_child(story_card)
	EventBus.boss_phase_message.connect(func(text: String) -> void: hud.flash_message(text, 1.5))
	EventBus.boss_defeated.connect(func(_id: StringName) -> void:
		hud.flash_message("KÖKYİYEN düştü!", 2.0))
	EventBus.vine_released.connect(_on_vine_released)
	EventBus.player_died.connect(_on_player_died)
	EventBus.game_saved.connect(func(_s: int) -> void: hud.show_save_icon())
	EventBus.ocak_rested.connect(func(_r: StringName, _o: StringName) -> void:
		hud.flash_message("Ocak — dinlendin, kaydedildi", 1.5))
	EventBus.collectible_picked.connect(func(_r: StringName, _p: StringName, _k: StringName) -> void:
		hud.flash_message("Kut parçası! (%d)" % GameState.kut_shards, 1.5))
	SceneRouter.register_host(self)
	load_room(start_room)
	hud.show_room_menu(true, GameState.has_save())


func _physics_process(delta: float) -> void:
	if _death_timer >= 0.0:
		_death_timer -= delta
		if _death_timer < 0.0:
			SceneRouter.respawn_at_last_ocak()
	var moving := player.velocity.length() > 0.5 and player.is_on_floor()
	if moving:
		hud.start_room_timer()
		if hud.is_room_menu_visible():
			hud.show_room_menu(false)
	if Input.is_action_just_pressed(&"restart_room") and room != null:
		SceneRouter.enter_room_immediate(room.room_id)


# ---------------------------------------------------------------- Oyun akışı

## Yeni oyun: durum sıfırlanır, kayıt silinir, Ocak Odası'ndan başlanır.
func new_game() -> void:
	GameState.reset()
	GameState.autosave_enabled = true
	GameState.delete_save()
	SceneRouter.enter_room_immediate(RoomRegistry.START_ROOM)
	GameState.reset_health()
	GameState.autosave()
	hud.show_room_menu(false)


## Devam: kayıt yüklenir, son Ocak'ta (yoksa son odanın başında) dirilinir.
func continue_game() -> void:
	if not GameState.load_game():
		new_game()
		return
	GameState.autosave_enabled = true
	SceneRouter.respawn_at_last_ocak()
	hud.show_room_menu(false)


## Geliştirici oda seçici (0–7) — kayıt almaz, canı doldurur. Testler bunu kullanır.
func load_room(index: int) -> void:
	index = clampi(index, 0, RoomRegistry.DEV_ROOMS.size() - 1)
	GameState.autosave_enabled = false
	var id: StringName = RoomRegistry.DEV_ROOMS[index]
	for ability: StringName in RoomRegistry.DEV_GRANTS.get(id, []):
		GameState.unlock_ability(ability)
	for key: String in RoomRegistry.DEV_RESET_FLAGS:
		GameState.flags.erase(key)
	SceneRouter.enter_room_immediate(id)
	room_index = index
	GameState.reset_health()
	hud.show_room_menu(false)


# ---------------------------------------------------------------- SceneRouter host API

func swap_room(packed: PackedScene) -> Room:
	if room != null:
		remove_child(room)
		room.queue_free()
	room = packed.instantiate() as GreyboxRoom
	room.name = "Room"
	add_child(room)
	room.goal_reached.connect(_on_goal_reached)
	_death_timer = -1.0
	room_index = RoomRegistry.DEV_ROOMS.find(room.room_id)
	hud.on_room_loaded(room_index, room)
	return room


func place_player(at: Vector3, velocity: Vector3) -> void:
	player.place_at(at)
	player.velocity = velocity


# ---------------------------------------------------------------- Olaylar

func _on_goal_reached() -> void:
	if hud.room_time <= 0.0:
		return
	var key := "m1_best/%s" % room.room_id
	var best: float = GameState.get_flag(key, 0.0)
	if best <= 0.0 or hud.room_time < best:
		best = hud.room_time
		GameState.set_flag(key, best)
	hud.on_goal(best)
	EventBus.room_goal_reached.emit(room.room_id, hud.room_time)


func _on_player_died() -> void:
	hud.flash_message("Alpay düştü…", death_restart_delay)
	_death_timer = death_restart_delay


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
