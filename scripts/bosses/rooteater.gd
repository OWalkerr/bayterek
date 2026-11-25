class_name Rooteater
extends Node3D
## B1 — Kökyiyen (docs/04). Düğüm konumu = arena merkezi (zemin). Faz denetleyicisi + eylem döngüsü.
##
## Faz 1 (DEPTH): GÖMÜLÜ → ÇATLAK (oyuncunun altında uyarı) → FIRLAMA (sütun hasarı) → AÇIKTA
##   (sırtındaki çürük kesesi vurulabilir; yavaşça oyuncuya döner → kese arkada kalır, etrafından dolaş)
##   → SÜPÜRME UYARISI (halka) → SÜPÜRME (yerdeysen hasar; zıpla) → GÖMÜLME.
## Faz 2: aynı döngü daha hızlı; süpürme tüm arenayı kaplar (zıpla ya da tavan sarmaşığına tutun);
##   her döngüde Spor Şişkini çağırır.
## Faz 3 (SIDE kovalamaca): tavan çöker → oyuncu kuyunun dibine; ağız yükselir (RisingMaw);
##   tepede kök kayasına kanca → kaya ağza düşer → yenilgi.
## Tüm süreler @export; uyarılar ≥ 0.4 sn (docs/04 telegraph kuralı).

signal phase_changed(phase: int)
signal defeated

enum Phase { DORMANT, INTRO, ONE, TWO, CHASE, FINALE, DEFEATED }
enum Action { IDLE, BURROWED, TELEGRAPH, ERUPT, EXPOSED, SWEEP_TELL, SWEEP, BURROW }

@export_group("Arena")
@export var arena_radius: float = 10.0
@export var body_radius: float = 1.3
@export var body_height: float = 7.0
@export var sac_height: float = 2.0
@export var sac_offset: float = 1.5

@export_group("Faz 1")
@export var p1_burrowed_time: float = 0.8
@export var p1_telegraph_time: float = 1.0
@export var p1_exposed_time: float = 2.8
@export var p1_turn_speed_deg: float = 40.0
@export var p1_sweep_radius: float = 6.0
@export var sac_hp: int = 8

@export_group("Faz 2")
@export var p2_burrowed_time: float = 0.5
@export var p2_telegraph_time: float = 0.8
@export var p2_exposed_time: float = 3.0
@export var p2_turn_speed_deg: float = 50.0
@export var p2_sweep_radius: float = 14.0
@export var p2_bloaters_per_cycle: int = 2
@export var p2_max_bloaters: int = 3
## Şişkinlerin süzülme yüksekliği: ileri kamçının erişebileceği kadar alçak (derinlikte yukarı
## vuruş yok — W "ileri" demek).
@export var p2_bloater_height: float = 1.8

@export_group("Ortak")
@export var intro_time: float = 2.5
@export var erupt_time: float = 0.5
@export var sweep_tell_time: float = 0.7
@export var sweep_time: float = 0.35
@export var sweep_height: float = 1.0
@export var burrow_time: float = 0.6
@export var phase_transition_time: float = 1.5

var phase: Phase = Phase.DORMANT
var action: Action = Action.IDLE
var player: Player
var room: GreyboxRoom
## Faz 3 kurulumu için oda sağlar: kuyu dibi, ağız, kaya.
var chase_start: Vector3
var maw: RisingMaw
var rock: RootRock
var chase_floor: Node3D

var weak_points: Array[BossWeakPoint] = []
var cycles: int = 0

var _timer: float = 0.0
var _target: Vector3 = Vector3.ZERO
var _rise: float = 0.0
var _yaw: float = 0.0
var _body: Node3D
var _body_mesh: MeshInstance3D
var _crack: MeshInstance3D
var _sweep_ring: MeshInstance3D
var _body_hazard: BossHazard
var _erupt_hazard: BossHazard
var _sweep_hazard: BossHazard
var _bloaters: Array[Node] = []


func _ready() -> void:
	_build()
	_set_rise(0.0)


# ---------------------------------------------------------------- Genel API

func start_fight(target_player: Player) -> void:
	if phase != Phase.DORMANT:
		return
	player = target_player
	_set_phase(Phase.INTRO)
	_target = Vector3.ZERO
	_body.position = Vector3.ZERO
	action = Action.ERUPT
	_timer = intro_time
	player.set_cinematic(true)
	EventBus.boss_intro.emit(&"BOSS_ROOTEATER_NAME", &"BOSS_ROOTEATER_TITLE")


func get_active_weak_point() -> BossWeakPoint:
	var idx := 0 if phase == Phase.ONE else 1
	if phase != Phase.ONE and phase != Phase.TWO:
		return null
	return weak_points[idx]


func is_exposed() -> bool:
	return action == Action.EXPOSED


func get_body_position() -> Vector3:
	return _body.global_position


func get_crack_position() -> Vector3:
	return _crack.global_position


func is_telegraphing() -> bool:
	return action == Action.TELEGRAPH


func is_sweep_telling() -> bool:
	return action == Action.SWEEP_TELL


func is_sweeping() -> bool:
	return action == Action.SWEEP


## Mevcut eylemin kalan süresi (bot/test ve ileride ses/ışık ipuçları için).
func get_action_time_left() -> float:
	return _timer


func current_sweep_radius() -> float:
	return p2_sweep_radius if phase == Phase.TWO else p1_sweep_radius


# ---------------------------------------------------------------- Döngü

func _physics_process(delta: float) -> void:
	if delta <= 0.0 or phase == Phase.DORMANT or phase == Phase.DEFEATED:
		return
	_timer -= delta
	match phase:
		Phase.INTRO:
			_set_rise(clampf(1.0 - _timer / intro_time * 1.5, 0.0, 1.0))
			if _timer <= 0.0:
				player.set_cinematic(false)
				_set_phase(Phase.ONE)
				_begin(Action.BURROW)
		Phase.ONE, Phase.TWO:
			_update_cycle(delta)
		Phase.CHASE, Phase.FINALE:
			pass


func _update_cycle(delta: float) -> void:
	match action:
		Action.BURROWED:
			if _timer <= 0.0:
				_target = _clamp_to_arena(player.global_position - global_position)
				_crack.position = Vector3(_target.x, 0.03, _target.z)
				_crack.visible = true
				_begin(Action.TELEGRAPH)
		Action.TELEGRAPH:
			var pulse := 1.0 + 0.25 * sin(_timer * 30.0)
			_crack.scale = Vector3(pulse, 1.0, pulse)
			if _timer <= 0.0:
				_crack.visible = false
				_body.position = _target
				_yaw = _yaw_towards_player() + PI   # kese oyuncudan uzakta başlar
				_erupt_hazard.position = _target
				_erupt_hazard.active = true
				_begin(Action.ERUPT)
		Action.ERUPT:
			_set_rise(1.0 - _timer / erupt_time)
			if _timer <= 0.0:
				_erupt_hazard.active = false
				_set_rise(1.0)
				get_active_weak_point().exposed = true
				_begin(Action.EXPOSED)
		Action.EXPOSED:
			var turn := deg_to_rad(p2_turn_speed_deg if phase == Phase.TWO else p1_turn_speed_deg) * delta
			_yaw = rotate_toward(_yaw, _yaw_towards_player(), turn)
			if _timer <= 0.0:
				get_active_weak_point().exposed = false
				_sweep_ring.scale = Vector3.ONE * current_sweep_radius()
				_sweep_ring.position = Vector3(_body.position.x, 0.05, _body.position.z)
				_sweep_ring.visible = true
				_begin(Action.SWEEP_TELL)
		Action.SWEEP_TELL:
			if _timer <= 0.0:
				_sweep_ring.visible = false
				_sweep_hazard.position = _body.position
				_sweep_hazard.set_cylinder(current_sweep_radius(), sweep_height, Color(0.79, 0.85, 0.23, 0.35))
				_sweep_hazard.active = true
				_begin(Action.SWEEP)
		Action.SWEEP:
			if _timer <= 0.0:
				_sweep_hazard.active = false
				_begin(Action.BURROW)
		Action.BURROW:
			_set_rise(_timer / burrow_time)
			if _timer <= 0.0:
				_set_rise(0.0)
				cycles += 1
				if phase == Phase.TWO:
					_spawn_bloaters()
				_begin(Action.BURROWED)
	_update_weak_point_transform()


func _begin(next: Action) -> void:
	action = next
	var two := phase == Phase.TWO
	match next:
		Action.BURROWED: _timer = p2_burrowed_time if two else p1_burrowed_time
		Action.TELEGRAPH: _timer = p2_telegraph_time if two else p1_telegraph_time
		Action.ERUPT: _timer = erupt_time
		Action.EXPOSED: _timer = p2_exposed_time if two else p1_exposed_time
		Action.SWEEP_TELL: _timer = sweep_tell_time
		Action.SWEEP: _timer = sweep_time
		Action.BURROW: _timer = burrow_time
		_: _timer = 0.0


func _on_weak_point_died() -> void:
	if phase == Phase.ONE:
		_end_exposure()
		_set_phase(Phase.TWO)
		TimeScale.request(&"boss_roar", 0.6, 0.5)
		_begin(Action.BURROW)
		_timer = phase_transition_time
	elif phase == Phase.TWO:
		_end_exposure()
		_start_chase()


func _end_exposure() -> void:
	_erupt_hazard.active = false
	_sweep_hazard.active = false
	_sweep_ring.visible = false
	_crack.visible = false


# ---------------------------------------------------------------- Faz 3

func _start_chase() -> void:
	_set_phase(Phase.CHASE)
	action = Action.IDLE
	_set_rise(0.0)
	_body_hazard.active = false
	for b: Node in _bloaters:
		if is_instance_valid(b):
			b.queue_free()
	_bloaters.clear()
	EventBus.boss_phase_message.emit("Tavan çöküyor!")
	await get_tree().create_timer(0.6, true, false, true).timeout
	if not is_inside_tree():
		return
	await SceneRouter.move_player_with_fade(chase_start)
	if not is_inside_tree() or phase != Phase.CHASE:
		return
	maw.floor_body = chase_floor
	maw.floor_y = chase_floor.global_position.y + 0.5 if is_instance_valid(chase_floor) else 0.0
	maw.start(player)
	rock.pulled.connect(_on_rock_pulled, CONNECT_ONE_SHOT)


func _on_rock_pulled() -> void:
	if phase != Phase.CHASE:
		return
	_set_phase(Phase.FINALE)
	maw.stop()
	if player.is_swinging():
		player.swing_state.release(false)
	rock.enabled = false
	var tween := create_tween()
	tween.tween_property(rock, ^"global_position", Vector3(rock.global_position.x, maw.top_y, 0.0), 0.6)
	await tween.finished
	TimeScale.request(&"boss_defeat", 0.4, 0.8)
	rock.visible = false
	var sink := create_tween()
	sink.tween_property(maw, ^"position:y", maw.position.y - 12.0, 1.2)
	await sink.finished
	_set_phase(Phase.DEFEATED)
	defeated.emit()


# ---------------------------------------------------------------- Yardımcılar

func _set_phase(p: Phase) -> void:
	phase = p
	phase_changed.emit(p)
	EventBus.boss_phase_changed.emit(&"rooteater", p)


func _set_rise(t: float) -> void:
	_rise = clampf(t, 0.0, 1.0)
	var h := body_height * _rise
	_body.visible = _rise > 0.02
	_body_mesh.scale = Vector3(1.0, maxf(_rise, 0.01), 1.0)
	_body_mesh.position = Vector3.UP * h * 0.5
	_body_hazard.position = _body.position
	_body_hazard.active = _rise > 0.3 and (phase == Phase.ONE or phase == Phase.TWO or phase == Phase.INTRO)


func _update_weak_point_transform() -> void:
	_body.rotation.y = _yaw
	for i in weak_points.size():
		var wp := weak_points[i]
		# Kese gövdenin "sırtında": bakış yönünün tersinde
		var back := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
		wp.global_position = _body.global_position + back * sac_offset + Vector3.UP * (sac_height + 0.6 * i)


func _yaw_towards_player() -> float:
	var to := player.global_position - _body.global_position
	return atan2(to.x, to.z)


func _clamp_to_arena(local: Vector3) -> Vector3:
	var flat := Vector3(local.x, 0.0, local.z)
	if flat.length() > arena_radius - 1.5:
		flat = flat.normalized() * (arena_radius - 1.5)
	return flat


func _spawn_bloaters() -> void:
	# Ölü/silinmiş Şişkinleri ayıkla (serbest bırakılmış nesneye lambda ile dokunmak hata verir)
	var alive: Array[Node] = []
	for b: Variant in _bloaters:
		if is_instance_valid(b) and not (b as Enemy).is_dead():
			alive.append(b as Node)
	_bloaters = alive
	for i in p2_bloaters_per_cycle:
		if _bloaters.size() >= p2_max_bloaters:
			break
		var e := SporeBloater.new()
		var ang := randf() * TAU
		e.position = global_position - room.global_position + Vector3(cos(ang), 0.0, sin(ang)) * (arena_radius - 3.0) \
				+ Vector3.UP * p2_bloater_height
		room.add_child(e)
		_bloaters.append(e)


func _build() -> void:
	_body = Node3D.new()
	add_child(_body)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("4a2a4a")
	mat.roughness = 0.8
	var cyl := CylinderMesh.new()
	cyl.top_radius = body_radius * 0.8
	cyl.bottom_radius = body_radius
	cyl.height = body_height
	cyl.material = mat
	_body_mesh = MeshInstance3D.new()
	_body_mesh.mesh = cyl
	_body.add_child(_body_mesh)
	# Ağız/göz: bakış yönünde iki sarı göz (gövdeyle birlikte döner)
	for side: float in [-0.45, 0.45]:
		var eye_mat := StandardMaterial3D.new()
		eye_mat.albedo_color = Color("c9d93b")
		eye_mat.emission_enabled = true
		eye_mat.emission = Color("c9d93b")
		eye_mat.emission_energy_multiplier = 3.0
		var eye := SphereMesh.new()
		eye.radius = 0.2
		eye.height = 0.4
		eye.material = eye_mat
		var eye_mi := MeshInstance3D.new()
		eye_mi.mesh = eye
		eye_mi.position = Vector3(side, 0.9, body_radius * 0.85)
		_body_mesh.add_child(eye_mi)

	_body_hazard = BossHazard.new()
	add_child(_body_hazard)
	_body_hazard.set_cylinder(body_radius, body_height)
	_erupt_hazard = BossHazard.new()
	add_child(_erupt_hazard)
	_erupt_hazard.set_cylinder(body_radius + 0.3, body_height)
	_sweep_hazard = BossHazard.new()
	_sweep_hazard.show_when_active = true
	add_child(_sweep_hazard)

	_crack = _disc(Color("e8a33d"), 1.6)
	_sweep_ring = _disc(Color(0.79, 0.85, 0.23, 0.45), 1.0)

	for i in 2:
		var wp := BossWeakPoint.new()
		wp.max_hp = sac_hp
		wp.respawn_time = -1.0
		wp.name = "Sac%d" % i
		add_child(wp)
		wp.died.connect(_on_weak_point_died)
		weak_points.append(wp)


func _disc(color: Color, radius: float) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(color, 1.0)
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.05
	cyl.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.visible = false
	add_child(mi)
	return mi
