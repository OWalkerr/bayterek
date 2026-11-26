extends Node
## Oyun hissi (juice) yöneticisi: EventBus olaylarını dinler, ses + ekran sarsıntısı + kol titreşimi
## üretir (docs/08 §Juice). Oyun kodu bunu doğrudan çağırmaz; yalnızca olay yayınlar.
## Sesler SfxBank'tan (kodla üretilen geçici sesler ya da assets/audio/sfx/ altındaki dosyalar).

## Ses havuzu: aynı anda çalabilecek kısa ses sayısı.
@export var voices: int = 10
@export var sfx_volume_db: float = -6.0
@export var sfx_enabled: bool = true
## Her çalışta perde rastgele ± bu oran (aynı ses tekrar edince makineli tüfek gibi duyulmasın).
@export var pitch_jitter: float = 0.06
## Kol titreşimi açık mı.
@export var rumble_enabled: bool = true
## Sarsıntı travmaları (0..1).
@export var shake_hit: float = 0.12
@export var shake_kill: float = 0.22
@export var shake_hurt: float = 0.45
@export var shake_vine_break: float = 0.25
@export var shake_boss_phase: float = 0.6
@export var shake_boss_defeat: float = 0.8
## Sert iniş: bu düşüş hızından (m/s) sonra sarsıntı başlar, `land_shake_full` hızda `shake_land_max`.
@export var land_shake_speed: float = 13.0
@export var land_shake_full: float = 22.0
@export var shake_land_max: float = 0.3
## Sallanma rüzgârı: bu hızda (m/s) sessiz, `wind_full_speed`'de tam ses.
@export var wind_min_speed: float = 4.0
@export var wind_full_speed: float = 12.0
@export var wind_volume_db: float = -14.0

## Son çalınan sesler (testler için; en fazla 32).
var played: Array[StringName] = []

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _wind: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in voices:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_pool.append(p)
	_wind = AudioStreamPlayer.new()
	_wind.stream = SfxBank.get_stream(&"swing_wind")
	_wind.volume_db = -80.0
	add_child(_wind)
	# Sesleri açılışta üret (ilk zıplamada takılma olmasın)
	for n: StringName in SfxBank.NAMES:
		SfxBank.get_stream(n)

	EventBus.player_jumped.connect(func(_at: Vector3) -> void: play(&"jump", -4.0))
	EventBus.player_landed.connect(_on_landed)
	EventBus.player_footstep.connect(func(_at: Vector3) -> void: play(&"step", -10.0, 0.15))
	EventBus.player_attacked.connect(_on_attacked)
	EventBus.enemy_damaged.connect(_on_enemy_damaged)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_died.connect(func() -> void: play(&"rumble", -4.0))
	EventBus.player_healed.connect(func(_leaves: int) -> void: play(&"heal", -4.0, 0.0))
	EventBus.vine_grabbed.connect(func(_a: Node3D) -> void: play(&"grab", -6.0))
	EventBus.vine_released.connect(_on_vine_released)
	EventBus.vine_broken.connect(_on_vine_broken)
	EventBus.climb_started.connect(func(_v: Node3D) -> void: play(&"climb", -8.0))
	EventBus.climb_ended.connect(func(_v: Node3D, jumped: bool) -> void:
		if jumped:
			play(&"jump", -6.0))
	EventBus.grapple_attached.connect(func(_f: Node3D) -> void: play(&"grab", -3.0, 0.1))
	EventBus.collectible_picked.connect(func(_r: StringName, _p: StringName, _k: StringName) -> void:
		play(&"pickup", -3.0, 0.0))
	EventBus.ability_unlocked.connect(func(_id: StringName) -> void: play(&"perfect", -2.0, 0.0))
	EventBus.room_goal_reached.connect(func(_r: StringName, _t: float) -> void: play(&"pickup", -3.0, 0.0))
	EventBus.boss_phase_changed.connect(_on_boss_phase)
	EventBus.boss_defeated.connect(_on_boss_defeated)


func _process(_delta: float) -> void:
	_update_wind()


## Kısa ses çal. `jitter` < 0 → varsayılan pitch_jitter.
func play(sfx_name: StringName, volume_db: float = 0.0, jitter: float = -1.0) -> void:
	played.append(sfx_name)
	if played.size() > 32:
		played.pop_front()
	if not sfx_enabled or _pool.is_empty():
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = SfxBank.get_stream(sfx_name)
	p.volume_db = sfx_volume_db + volume_db
	var j := pitch_jitter if jitter < 0.0 else jitter
	p.pitch_scale = 1.0 + _rng.randf_range(-j, j)
	p.play()


func rumble(weak: float, strong: float, duration: float) -> void:
	if not rumble_enabled:
		return
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, duration)


func _update_wind() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player if is_inside_tree() else null
	var speed := 0.0
	if player != null and player.is_swinging():
		speed = player.velocity.length()
	var k := clampf((speed - wind_min_speed) / maxf(wind_full_speed - wind_min_speed, 0.01), 0.0, 1.0)
	if k <= 0.0:
		if _wind.playing:
			_wind.volume_db = move_toward(_wind.volume_db, -60.0, 3.0)
			if _wind.volume_db <= -59.0:
				_wind.stop()
		return
	if not _wind.playing and sfx_enabled:
		_wind.play()
	_wind.volume_db = sfx_volume_db + wind_volume_db + linear_to_db(k)
	_wind.pitch_scale = 0.8 + 0.5 * k


func _on_landed(fall_speed: float) -> void:
	play(&"land", lerpf(-12.0, 0.0, clampf(fall_speed / land_shake_full, 0.0, 1.0)))
	if fall_speed > land_shake_speed:
		var k := clampf((fall_speed - land_shake_speed) / maxf(land_shake_full - land_shake_speed, 0.01), 0.0, 1.0)
		CameraDirector.shake(lerpf(0.08, shake_land_max, k))
		rumble(0.2 * k, 0.4 * k, 0.12)


func _on_attacked(_kind: StringName, combo_index: int) -> void:
	play(&"whip", -4.0 + combo_index * 1.0)


func _on_enemy_damaged(_enemy: Node3D, amount: int) -> void:
	play(&"hit", -2.0 + amount)
	CameraDirector.shake(shake_hit * amount)
	rumble(0.3, 0.0, 0.06)


func _on_enemy_killed(_enemy: Node3D) -> void:
	play(&"kill", -2.0)
	CameraDirector.shake(shake_kill)
	rumble(0.2, 0.3, 0.12)


func _on_player_damaged(_amount: int, _leaves_left: int) -> void:
	play(&"hurt", -1.0)
	CameraDirector.shake(shake_hurt)
	rumble(0.5, 0.7, 0.25)


func _on_vine_released(_anchor: Node3D, perfect: bool) -> void:
	play(&"release", -6.0)
	if perfect:
		play(&"perfect", -6.0, 0.0)
		rumble(0.25, 0.0, 0.08)


func _on_vine_broken(_anchor: Node3D) -> void:
	play(&"break", -2.0)
	CameraDirector.shake(shake_vine_break)
	rumble(0.3, 0.4, 0.2)


func _on_boss_phase(_boss_id: StringName, _phase: int) -> void:
	play(&"rumble", 0.0, 0.03)
	CameraDirector.shake(shake_boss_phase)
	rumble(0.6, 0.9, 0.5)


func _on_boss_defeated(_boss_id: StringName) -> void:
	play(&"rumble", 0.0, 0.0)
	play(&"perfect", -2.0, 0.0)
	CameraDirector.shake(shake_boss_defeat)
	rumble(0.8, 1.0, 0.7)
