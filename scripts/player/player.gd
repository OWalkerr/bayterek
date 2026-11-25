class_name Player
extends CharacterBody3D
## Alpay — oyuncu kontrolcüsü.
## Yan modda (2.5D) Z ekseni raya kilitlidir; derinlik modunda X-Z serbesttir.
## Sallanma fizik motoruna değil, kinematik sarkaç hesabına dayanır (docs/03_MECHANICS.md §2.2).

enum State { GROUND, AIR, SWING, CINEMATIC }

const HAND_HEIGHT: float = 1.45

@export var tuning: PlayerTuning

var state: State = State.AIR:
	set(value):
		if value == state:
			return
		state = value
		EventBus.player_state_changed.emit(value)

var rail_z: float = 0.0

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _jump_held: bool = false

# Sallanma durumu
var _anchor: VineAnchor = null
var _last_anchor: VineAnchor = null
var _regrab_timer: float = 0.0
var _swing_axis: Vector3 = Vector3.RIGHT
var _swing_angle: float = 0.0
var _swing_omega: float = 0.0
var _rope_length: float = 3.0

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
		State.CINEMATIC:
			velocity = Vector3.ZERO
	_update_visual(delta)
	_check_fall_out()


# ---------------------------------------------------------------- Genel API

func is_swinging() -> bool:
	return state == State.SWING


func get_current_anchor() -> VineAnchor:
	return _anchor


func set_cinematic(enabled: bool) -> void:
	if enabled:
		if state == State.SWING:
			_release_swing(false)
		state = State.CINEMATIC
	else:
		state = State.AIR


func respawn(at: Vector3) -> void:
	if state == State.SWING:
		_release_swing(false)
	global_position = at
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	state = State.AIR
	EventBus.player_respawned.emit(at)


# ---------------------------------------------------------------- Zamanlayıcılar

func _update_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_regrab_timer = maxf(_regrab_timer - delta, 0.0)
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

	# Yatay hız
	var desired := _input_to_world(input) * tuning.run_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate: float
	if desired.length_squared() > 0.0001:
		rate = tuning.ground_accel
	else:
		rate = tuning.ground_decel
	if not on_floor:
		rate *= tuning.air_control
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
		_try_grab_vine()


# ---------------------------------------------------------------- Sallanma

func _try_grab_vine() -> void:
	if not tuning.auto_grab and not Input.is_action_pressed(&"grab"):
		return
	var hand := global_position + Vector3.UP * HAND_HEIGHT
	var best: VineAnchor = null
	var best_distance := tuning.grab_radius
	for node: Node in get_tree().get_nodes_in_group(VineAnchor.GROUP):
		var anchor := node as VineAnchor
		if anchor == null or not anchor.enabled:
			continue
		if anchor == _last_anchor and _regrab_timer > 0.0:
			continue
		var d := anchor.distance_to_vine(hand)
		if d < best_distance:
			best_distance = d
			best = anchor
	if best != null:
		_start_swing(best)


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
		_swing_omega *= -0.25
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


func _release_swing(jumped: bool) -> void:
	var anchor := _anchor
	var tangent := _swing_tangent()
	var speed := _swing_omega * _rope_length
	# "Mükemmel bırakma": salınımın ileri-yukarı kolunda, 35°–70° aralığında
	var angle_deg := rad_to_deg(absf(_swing_angle))
	var perfect := jumped and signf(_swing_angle) == signf(_swing_omega) \
			and angle_deg >= 35.0 and angle_deg <= 70.0

	velocity = tangent * speed * tuning.release_boost
	if perfect:
		velocity *= tuning.perfect_release_bonus
	if jumped:
		velocity.y += tuning.release_jump_bonus

	_last_anchor = anchor
	_regrab_timer = tuning.regrab_cooldown
	_anchor = null
	_jump_held = false
	state = State.AIR
	if is_instance_valid(anchor):
		anchor.set_grabbed(false)
	EventBus.vine_released.emit(anchor, perfect)


# ---------------------------------------------------------------- Görsel / güvenlik

func _update_visual(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if state == State.SWING:
		horizontal = _swing_axis * signf(_swing_omega)
	if horizontal.length() > 0.5:
		# Model +Z'ye bakar (docs/07_ART_PIPELINE.md)
		_facing_yaw = atan2(horizontal.x, horizontal.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, _facing_yaw, minf(1.0, 14.0 * delta))


func _check_fall_out() -> void:
	if global_position.y < tuning.kill_y:
		respawn(_last_safe_position + Vector3.UP * 0.2)
