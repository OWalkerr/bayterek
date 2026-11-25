class_name Player
extends CharacterBody3D
## Alpay — oyuncu kontrolcüsü.
## Yan modda (2.5D) Z ekseni raya kilitlidir; derinlik modunda X-Z serbesttir.
## Sallanma fizik motoruna değil, kinematik sarkaç hesabına dayanır (docs/03_MECHANICS.md §2.2).

enum State { GROUND, AIR, SWING, CLIMB, CINEMATIC }

const HAND_HEIGHT: float = 1.45
## Tırmanırken elin sarmaşık uçlarına ne kadar yaklaşabileceği.
const CLIMB_END_MARGIN: float = 0.15

@export var tuning: PlayerTuning

var state: State = State.AIR:
	set(value):
		if value == state:
			return
		state = value
		EventBus.player_state_changed.emit(value)

var rail_z: float = 0.0
## Son bırakmanın mükemmel olup olmadığı (debug HUD + testler için).
var last_release_perfect: bool = false

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _jump_held: bool = false
var _input_lock_timer: float = 0.0

# Sallanma durumu
var _anchor: VineAnchor = null
var _last_anchor: VineAnchor = null
var _regrab_timer: float = 0.0
var _swing_axis: Vector3 = Vector3.RIGHT
var _swing_angle: float = 0.0
var _swing_omega: float = 0.0
var _rope_length: float = 3.0

# Tırmanma durumu
var _climb_vine: ClimbVine = null
var _last_climb_vine: ClimbVine = null
var _climb_regrab_timer: float = 0.0

var _last_safe_position: Vector3 = Vector3.ZERO
var _facing_yaw: float = PI * 0.5

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	if tuning == null:
		tuning = PlayerTuning.new()
	add_to_group(&"player")
	_last_safe_position = global_position
	rail_z = global_position.z


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	match state:
		State.GROUND, State.AIR:
			_process_platforming(delta)
		State.SWING:
			_process_swing(delta)
		State.CLIMB:
			_process_climb(delta)
		State.CINEMATIC:
			velocity = Vector3.ZERO
	_update_visual(delta)
	_check_fall_out()


# ---------------------------------------------------------------- Genel API

func is_swinging() -> bool:
	return state == State.SWING


func is_climbing() -> bool:
	return state == State.CLIMB


func get_current_anchor() -> VineAnchor:
	return _anchor


func get_current_climb_vine() -> ClimbVine:
	return _climb_vine


## Dikeye göre sarkaç açısı (radyan); sallanmıyorsa 0.
func get_swing_angle() -> float:
	return _swing_angle if state == State.SWING else 0.0


## Açısal hız (rad/sn); sallanmıyorsa 0.
func get_swing_omega() -> float:
	return _swing_omega if state == State.SWING else 0.0


func get_rope_length() -> float:
	return _rope_length


func get_coyote_timer() -> float:
	return _coyote_timer


func get_jump_buffer_timer() -> float:
	return _jump_buffer_timer


func get_last_safe_position() -> Vector3:
	return _last_safe_position


func set_cinematic(enabled: bool) -> void:
	if enabled:
		_detach_all()
		state = State.CINEMATIC
	else:
		state = State.AIR


func respawn(at: Vector3) -> void:
	_detach_all()
	global_position = at
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	state = State.AIR
	EventBus.player_respawned.emit(at)


## Oda değişiminde: konumu ve güvenli noktayı sıfırlar.
func place_at(at: Vector3) -> void:
	respawn(at)
	_last_safe_position = at
	rail_z = at.z
	_last_anchor = null
	_last_climb_vine = null


func _detach_all() -> void:
	if state == State.SWING:
		_release_swing(false)
	elif state == State.CLIMB:
		_release_climb(Vector3.ZERO, false)


# ---------------------------------------------------------------- Zamanlayıcılar

func _update_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_regrab_timer = maxf(_regrab_timer - delta, 0.0)
	_climb_regrab_timer = maxf(_climb_regrab_timer - delta, 0.0)
	_input_lock_timer = maxf(_input_lock_timer - delta, 0.0)
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_timer = tuning.jump_buffer


func _get_move_input() -> Vector2:
	# x: sağ(+) / sol(-), y: yukarı/ileri(+) / aşağı/geri(-)
	return Input.get_vector(&"move_left", &"move_right", &"move_down", &"move_up")


## Girdiyi dünya uzayında yatay bir vektöre çevirir.
func _input_to_world(input: Vector2) -> Vector3:
	if CameraDirector.is_side_mode():
		return Vector3(input.x, 0.0, 0.0)
	var cam_basis: Basis = CameraDirector.get_input_basis()
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var dir := right * input.x + forward * input.y
	return dir.limit_length(1.0)


# ---------------------------------------------------------------- Yer / hava

func _process_platforming(delta: float) -> void:
	var input := _get_move_input()
	var on_floor := is_on_floor()

	if on_floor:
		_coyote_timer = tuning.coyote_time
		state = State.GROUND
	else:
		state = State.AIR

	# Yatay hız (tırmanmadan yana zıplamadan hemen sonra kısa süre girdi kilitli)
	if _input_lock_timer <= 0.0:
		var desired := _input_to_world(input) * tuning.run_speed
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		var rate: float
		if desired.length_squared() > 0.0001:
			rate = tuning.ground_accel
		else:
			rate = tuning.ground_decel
		if not on_floor:
			rate *= tuning.air_control
		# Momentum koruma: havada koşu hızının üstündeyken ve girdi aynı yöndeyse
		# hız koşu hızına kırpılmaz, yalnızca hafif sürtünmeyle azalır (Sütun 1).
		var overspeed := not on_floor and horizontal.length() > tuning.run_speed \
				and desired.length_squared() > 0.0001 and horizontal.dot(desired) > 0.0
		if overspeed:
			horizontal = horizontal.move_toward(
					horizontal.normalized() * tuning.run_speed, tuning.air_overspeed_drag * delta)
		else:
			horizontal = horizontal.move_toward(desired, rate * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z

	# Yan modda raya çekilme (derinlikten çıkışta yumuşak dönüş de buradan gelir)
	if CameraDirector.is_side_mode():
		velocity.z = (rail_z - global_position.z) * tuning.rail_pull

	# Zıplama (coyote time + jump buffer)
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = tuning.get_jump_velocity()
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_jump_held = true
		on_floor = false

	# Asimetrik yerçekimi
	if not on_floor:
		var g := tuning.gravity_up if velocity.y > 0.0 else tuning.gravity_down
		velocity.y = maxf(velocity.y - g * delta, -tuning.max_fall_speed)

	# Değişken zıplama: tuş erken bırakılırsa yükseliş kesilir
	if _jump_held and not Input.is_action_pressed(&"jump"):
		_jump_held = false
		if velocity.y > 0.0:
			velocity.y *= tuning.jump_cut
	if velocity.y <= 0.0:
		_jump_held = false

	move_and_slide()

	# Güvenli nokta yalnızca gerçek bir hareket sonrası zemindeyken güncellenir
	# (ışınlanma sonrası bayat is_on_floor değerine güvenilmez).
	if is_on_floor() and global_position.y > tuning.kill_y + 2.0:
		_last_safe_position = global_position
	else:
		_try_grab()


# ---------------------------------------------------------------- Tutunma seçimi

func _try_grab() -> void:
	if not tuning.auto_grab and not Input.is_action_pressed(&"grab"):
		return
	var hand := global_position + Vector3.UP * HAND_HEIGHT

	var best_swing: VineAnchor = null
	var best_swing_d := tuning.grab_radius
	for node: Node in get_tree().get_nodes_in_group(VineAnchor.GROUP):
		var anchor := node as VineAnchor
		if anchor == null or not anchor.enabled:
			continue
		if anchor == _last_anchor and _regrab_timer > 0.0:
			continue
		# Tutturma noktasının üstünden/yanından tutunma sarkaçta momentumu sıfırlar → izin yok
		if hand.y > anchor.global_position.y - tuning.grab_min_below_anchor:
			continue
		var d := anchor.distance_to_vine(hand)
		if d < best_swing_d:
			best_swing_d = d
			best_swing = anchor

	var best_climb: ClimbVine = null
	var best_climb_d := tuning.climb_grab_radius
	for node: Node in get_tree().get_nodes_in_group(ClimbVine.GROUP):
		var vine := node as ClimbVine
		if vine == null or not vine.enabled:
			continue
		if vine == _last_climb_vine and _climb_regrab_timer > 0.0:
			continue
		var d := vine.distance_to_vine(hand)
		if d < best_climb_d:
			best_climb_d = d
			best_climb = vine

	if best_climb != null and (best_swing == null or best_climb_d <= best_swing_d):
		_start_climb(best_climb)
	elif best_swing != null:
		_start_swing(best_swing)


# ---------------------------------------------------------------- Sallanma

func _start_swing(anchor: VineAnchor) -> void:
	_anchor = anchor
	var hand := global_position + Vector3.UP * HAND_HEIGHT
	var offset := hand - anchor.global_position
	_rope_length = clampf(offset.length(), tuning.min_rope, tuning.max_rope)

	if CameraDirector.is_side_mode():
		_swing_axis = Vector3.RIGHT
	else:
		var flat := Vector3(offset.x, 0.0, offset.z)
		if flat.length() < 0.1:
			flat = Vector3(velocity.x, 0.0, velocity.z)
		if flat.length() < 0.1:
			flat = Vector3.RIGHT
		_swing_axis = flat.normalized()

	_swing_angle = atan2(offset.dot(_swing_axis), -offset.y)
	# Momentum korunur: mevcut hız, sarkacın teğetine izdüşürülüp açısal hıza çevrilir.
	_swing_omega = velocity.dot(_swing_tangent()) / _rope_length
	_jump_buffer_timer = 0.0
	state = State.SWING
	anchor.set_grabbed(true)
	EventBus.vine_grabbed.emit(anchor)


func _swing_tangent() -> Vector3:
	return _swing_axis * cos(_swing_angle) + Vector3.UP * sin(_swing_angle)


func _process_swing(delta: float) -> void:
	if not is_instance_valid(_anchor) or not _anchor.enabled:
		_release_swing(false)
		return

	var input := _get_move_input()
	var push: float
	if CameraDirector.is_side_mode():
		push = input.x
		# Yukarı/aşağı ile ip kısalt/uzat
		_rope_length = clampf(_rope_length - input.y * tuning.rope_reel_speed * delta,
				tuning.min_rope, tuning.max_rope)
	else:
		push = _input_to_world(input).dot(_swing_axis)

	var alpha := -(tuning.swing_gravity / _rope_length) * sin(_swing_angle)
	alpha += push * tuning.swing_pump * cos(_swing_angle) / _rope_length
	alpha -= tuning.swing_damping * _swing_omega
	_swing_omega += alpha * delta

	var max_angle := deg_to_rad(tuning.swing_max_angle_deg)
	_swing_angle += _swing_omega * delta
	if absf(_swing_angle) > max_angle:
		_swing_angle = clampf(_swing_angle, -max_angle, max_angle)
		_swing_omega = 0.0

	var hand_target := _anchor.global_position \
			+ (_swing_axis * sin(_swing_angle) - Vector3.UP * cos(_swing_angle)) * _rope_length
	var body_target := hand_target - Vector3.UP * HAND_HEIGHT
	velocity = (body_target - global_position) / delta
	move_and_slide()

	if get_slide_collision_count() > 0:
		# Duvara/zemine çarptı: sekme + açıyı gerçek konuma göre düzelt
		_swing_omega *= tuning.swing_bounce
		var real_offset := global_position + Vector3.UP * HAND_HEIGHT - _anchor.global_position
		_swing_angle = atan2(real_offset.dot(_swing_axis), -real_offset.y)
		if is_on_floor():
			_release_swing(false)
			return

	_anchor.update_vine_visual(global_position + Vector3.UP * HAND_HEIGHT)

	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = 0.0
		_release_swing(true)
	elif not tuning.auto_grab and not Input.is_action_pressed(&"grab"):
		_release_swing(false)


## Salınımın ileri-yukarı kolunda (açı ile açısal hız aynı işaretli) ve
## tuning'deki açı aralığındaysa "mükemmel bırakma" sayılır.
func is_in_perfect_window() -> bool:
	if state != State.SWING:
		return false
	var angle_deg := rad_to_deg(absf(_swing_angle))
	return signf(_swing_angle) == signf(_swing_omega) and absf(_swing_omega) > 0.01 \
			and angle_deg >= tuning.perfect_release_min_deg \
			and angle_deg <= tuning.perfect_release_max_deg


func _release_swing(jumped: bool) -> void:
	var anchor := _anchor
	var tangent := _swing_tangent()
	var speed := _swing_omega * _rope_length
	var perfect := jumped and is_in_perfect_window()

	velocity = tangent * speed * tuning.release_boost
	if perfect:
		velocity *= tuning.perfect_release_bonus
	if jumped:
		velocity.y += tuning.release_jump_bonus

	last_release_perfect = perfect
	_last_anchor = anchor
	_regrab_timer = tuning.regrab_cooldown
	_anchor = null
	_jump_held = false
	_coyote_timer = 0.0
	state = State.AIR
	if is_instance_valid(anchor):
		anchor.set_grabbed(false)
	EventBus.vine_released.emit(anchor, perfect)


# ---------------------------------------------------------------- Tırmanma

func _start_climb(vine: ClimbVine) -> void:
	_climb_vine = vine
	velocity = Vector3.ZERO
	_jump_buffer_timer = 0.0
	_jump_held = false
	state = State.CLIMB
	EventBus.climb_started.emit(vine)


func _process_climb(delta: float) -> void:
	if not is_instance_valid(_climb_vine) or not _climb_vine.enabled:
		_release_climb(Vector3.ZERO, false)
		return

	var input := _get_move_input()
	var hand_y := global_position.y + HAND_HEIGHT
	var top_y := _climb_vine.get_top().y - CLIMB_END_MARGIN
	var bottom_y := _climb_vine.get_bottom().y + CLIMB_END_MARGIN

	# Zıplama: yön tuşu basılıysa yana, değilse yukarı sıçrama
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = 0.0
		var dir := _input_to_world(Vector2(input.x, 0.0 if CameraDirector.is_side_mode() else input.y))
		var jump_vel := Vector3.UP * tuning.get_climb_jump_velocity()
		if dir.length() > 0.3:
			jump_vel += dir.normalized() * tuning.climb_jump_speed_x
			_input_lock_timer = tuning.climb_jump_lock
		_release_climb(jump_vel, true)
		return

	# Aşağı basılıyken alt uca gelindiyse bırak
	if input.y < -0.5 and hand_y <= bottom_y + 0.01:
		_release_climb(Vector3.ZERO, false)
		return

	var climb_dir := input.y
	if climb_dir > 0.0 and hand_y >= top_y:
		climb_dir = 0.0
	var target_y := clampf(hand_y + climb_dir * tuning.climb_speed * delta, bottom_y, top_y)

	# Gövdeyi sarmaşığa doğru yumuşakça hizala; dikeyde hedefe git
	var vine_point := _climb_vine.get_top()
	var target := Vector3(vine_point.x, target_y - HAND_HEIGHT,
			rail_z if CameraDirector.is_side_mode() else vine_point.z)
	var to_target := target - global_position
	var snap := minf(1.0, tuning.rail_pull * delta * 2.0)
	velocity = Vector3(to_target.x * snap, to_target.y, to_target.z * snap) / delta
	move_and_slide()

	# Aşağı inerken yere değdiyse sarmaşıktan in
	if is_on_floor() and input.y < -0.5:
		_release_climb(Vector3.ZERO, false)


func _release_climb(new_velocity: Vector3, jumped: bool) -> void:
	var vine := _climb_vine
	velocity = new_velocity
	_last_climb_vine = vine
	_climb_regrab_timer = tuning.climb_regrab_cooldown
	_climb_vine = null
	_jump_held = jumped
	_coyote_timer = 0.0
	state = State.AIR
	EventBus.climb_ended.emit(vine, jumped)


# ---------------------------------------------------------------- Görsel / güvenlik

func _update_visual(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if state == State.SWING:
		horizontal = _swing_axis * signf(_swing_omega)
	elif state == State.CLIMB:
		horizontal = Vector3.ZERO
		_facing_yaw = PI   # sarmaşığa (kameradan uzağa) bakar
	if horizontal.length() > 0.5:
		# Model +Z'ye bakar (docs/07_ART_PIPELINE.md)
		_facing_yaw = atan2(horizontal.x, horizontal.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, _facing_yaw, minf(1.0, tuning.turn_speed * delta))


func _check_fall_out() -> void:
	if global_position.y < tuning.kill_y:
		respawn(_last_safe_position + Vector3.UP * 0.2)
