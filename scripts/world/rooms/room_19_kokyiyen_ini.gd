extends GreyboxRoom
## "Kökyiyen'in İni" (M6) — boss odası. İki bölüm:
##  Arena (x 8 → 32, z -21 → 3): DEPTH kamera, Faz 1–2. Tavanda 4 sarmaşık (Faz 2 süpürmesinden kaçış).
##  Kuyu (x 60 → 76, ayrı): Faz 3 kovalamaca, SIDE. Tırmanma A → çiçek → tırmanma B → çiçek →
##  tırmanma C → tepe çıkıntısı → kök kayası (kanca) → kaya ağza düşer.
## Yenilince: bayrak, Kut parçası #3, can tam, Kocabaş'ın mesajı (hikaye anı), kapı açılır.

const BOSS_ID: StringName = &"boss_defeated"
const ARENA_CENTER: Vector3 = Vector3(20.0, 0.0, -9.0)
const CHASE_START: Vector3 = Vector3(68.0, 0.1, 0.0)

var boss: Rooteater
var trigger: Area3D
var _chase_floor: StaticBody3D


func _build() -> void:
	# ---- Arena
	box(Vector3(20.0, -1.0, -9.0), Vector3(26.0, 2.0, 26.0), C_CAVE)        # zemin x 7 → 33, z -22 → 4
	box(Vector3(4.0, -1.0, 0.0), Vector3(8.0, 2.0, 4.0), C_BARK)            # giriş koridoru x 0 → 8
	box(Vector3(7.5, 6.0, -12.0), Vector3(1.0, 14.0, 20.0), C_ROOT)         # batı duvarı z -22 → -2
	box(Vector3(32.5, 6.0, -9.0), Vector3(1.0, 14.0, 26.0), C_ROOT)         # doğu duvarı
	box(Vector3(20.0, 6.0, -22.0), Vector3(26.0, 14.0, 1.0), C_ROOT)        # arka duvar
	box(Vector3(20.0, 12.5, -9.0), Vector3(26.0, 1.0, 26.0), C_CAVE)        # tavan
	box(Vector3(0.0, 6.0, -3.5), Vector3(16.0, 16.0, 1.0), C_ROOT)          # koridor arka duvarı
	_invisible_wall(Vector3(20.0, 6.0, 4.0), Vector3(26.0, 14.0, 1.0))      # ön (kameraya açık) sınır
	for p: Vector3 in [Vector3(14.0, 8.0, -3.0), Vector3(26.0, 8.0, -3.0), Vector3(14.0, 8.0, -15.0), Vector3(26.0, 8.0, -15.0)]:
		vine(p, 4.5)
	glow(Vector3(9.0, 0.3, -20.0), Color("5a1e5c"))
	glow(Vector3(31.0, 0.3, -20.0), Color("5a1e5c"))
	camera_zone(Vector3(21.0, 3.0, -9.0), Vector3(22.0, 14.0, 26.0), CameraRig.Mode.DEPTH, 1.0)

	# ---- Kuyu (Faz 3)
	_chase_floor = box(Vector3(68.0, -0.5, 0.0), Vector3(16.0, 1.0, 4.0), C_CAVE)
	box(Vector3(59.5, 20.0, 0.0), Vector3(1.0, 48.0, 4.0), C_ROOT)
	box(Vector3(76.5, 20.0, 0.0), Vector3(1.0, 48.0, 4.0), C_ROOT)
	backdrop(59.0, 77.0, -6.0, 46.0, C_CAVE)
	climb_vine(Vector3(63.0, 12.0, 0.0), 11.0)        # A: y 1 → 12
	grapple_flower(Vector3(69.0, 16.0, 0.0))
	climb_vine(Vector3(73.0, 25.0, 0.0), 11.0)        # B: y 14 → 25
	grapple_flower(Vector3(68.0, 29.0, 0.0))
	climb_vine(Vector3(63.0, 35.0, 0.0), 9.0)         # C: y 26 → 35
	platform(64.5, 70.0, 35.0, 0.5, C_MOSS)           # tepe çıkıntısı
	var rock := RootRock.new()
	rock.position = Vector3(70.0, 41.0, 0.0)
	add_child(rock)
	var maw := RisingMaw.new()
	maw.position = Vector3(68.0, -6.0, 0.0)
	add_child(maw)

	if GameState.get_flag(flag_key(BOSS_ID), false):
		rock.visible = false
		rock.enabled = false
		_add_victory_marker()
		return

	boss = Rooteater.new()
	boss.name = "Rooteater"
	boss.position = ARENA_CENTER
	boss.room = self
	boss.chase_start = CHASE_START
	boss.chase_floor = _chase_floor
	boss.maw = maw
	boss.rock = rock
	add_child(boss)
	boss.defeated.connect(_on_boss_defeated)

	trigger = Area3D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = Layers.PLAYER
	var shape := BoxShape3D.new()
	shape.size = Vector3(16.0, 6.0, 22.0)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(21.0, 3.0, -9.0)
	trigger.add_child(col)
	add_child(trigger)
	trigger.body_entered.connect(_on_trigger)


func _on_trigger(body: Node3D) -> void:
	var p := body as Player
	if p == null or boss == null or boss.phase != Rooteater.Phase.DORMANT:
		return
	_set_doors_enabled(false)
	boss.start_fight(p)


func _set_doors_enabled(value: bool) -> void:
	for d: RoomDoor in get_doors():
		d.enabled = value


func _on_boss_defeated() -> void:
	GameState.set_flag(flag_key(BOSS_ID), true)
	GameState.set_flag(flag_key(&"kut_3"), true)
	GameState.kut_shards += 1
	GameState.reset_health()
	EventBus.boss_defeated.emit(&"rooteater")
	await SceneRouter.move_player_with_fade(Vector3(14.0, 0.1, -9.0))
	_set_doors_enabled(true)
	_add_victory_marker()
	GameState.autosave()
	EventBus.story_requested.emit(&"kocabas_first_message")


func _add_victory_marker() -> void:
	glow(ARENA_CENTER + Vector3(0.0, 0.5, 0.0), C_SAP)


func _invisible_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)
