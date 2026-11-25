class_name PlayerSwingState
extends PlayerState
## Kinematik sarkaç (docs/03 §2.2). Tutunma anında hız açısal hıza çevrilir; bırakmada
## teğet hız × boost (+ zıplama bonusu, + mükemmel bırakma bonusu).

var anchor: VineAnchor = null
var last_anchor: VineAnchor = null
var axis: Vector3 = Vector3.RIGHT
var angle: float = 0.0
var omega: float = 0.0
var rope_length: float = 3.0


func can_attack() -> bool:
	return true


func begin(new_anchor: VineAnchor) -> void:
	anchor = new_anchor
	var t := tuning()
	var p := player
	var hand := p.get_hand_position()
	var offset := hand - anchor.global_position
	rope_length = clampf(offset.length(), t.min_rope, t.max_rope)

	if CameraDirector.is_side_mode():
		axis = Vector3.RIGHT
	else:
		var flat := Vector3(offset.x, 0.0, offset.z)
		if flat.length() < 0.1:
			flat = Vector3(p.velocity.x, 0.0, p.velocity.z)
		if flat.length() < 0.1:
			flat = Vector3.RIGHT
		axis = flat.normalized()

	angle = atan2(offset.dot(axis), -offset.y)
	# Momentum korunur: mevcut hız, sarkacın teğetine izdüşürülüp açısal hıza çevrilir.
	omega = p.velocity.dot(tangent()) / rope_length
	p.jump_buffer_timer = 0.0
	p.change_state(Player.State.SWING)
	anchor.set_grabbed(true)
	EventBus.vine_grabbed.emit(anchor)


func tangent() -> Vector3:
	return axis * cos(angle) + Vector3.UP * sin(angle)


## Sarmaşıktaki anlık çizgisel hız (m/s).
func get_speed() -> float:
	return absf(omega) * rope_length


func physics_update(delta: float) -> void:
	if not is_instance_valid(anchor) or not anchor.enabled:
		release(false)
		return
	var t := tuning()
	var p := player

	var input := p.get_move_input()
	var push: float
	if CameraDirector.is_side_mode():
		push = input.x
		# Yukarı/aşağı ile ip kısalt/uzat
		rope_length = clampf(rope_length - input.y * t.rope_reel_speed * delta,
				t.min_rope, t.max_rope)
	else:
		push = p.input_to_world(input).dot(axis)

	var alpha := -(t.swing_gravity / rope_length) * sin(angle)
	alpha += push * t.swing_pump * cos(angle) / rope_length
	alpha -= t.swing_damping * omega
	omega += alpha * delta

	var max_angle := deg_to_rad(t.swing_max_angle_deg)
	angle += omega * delta
	if absf(angle) > max_angle:
		angle = clampf(angle, -max_angle, max_angle)
		omega = 0.0

	var hand_target := anchor.global_position \
			+ (axis * sin(angle) - Vector3.UP * cos(angle)) * rope_length
	var body_target := hand_target - Vector3.UP * Player.HAND_HEIGHT
	p.velocity = (body_target - p.global_position) / delta
	p.move_and_slide()

	if p.get_slide_collision_count() > 0:
		# Duvara/zemine çarptı: sekme + açıyı gerçek konuma göre düzelt
		omega *= t.swing_bounce
		var real_offset := p.get_hand_position() - anchor.global_position
		angle = atan2(real_offset.dot(axis), -real_offset.y)
		if p.is_on_floor():
			release(false)
			return

	anchor.update_vine_visual(p.get_hand_position())

	if p.jump_buffer_timer > 0.0:
		p.jump_buffer_timer = 0.0
		release(true)
	elif not t.auto_grab and not Input.is_action_pressed(&"grab"):
		release(false)


## Salınımın ileri-yukarı kolunda (açı ile açısal hız aynı işaretli) ve
## tuning'deki açı aralığındaysa "mükemmel bırakma" sayılır.
func is_in_perfect_window() -> bool:
	var t := tuning()
	var angle_deg := rad_to_deg(absf(angle))
	return signf(angle) == signf(omega) and absf(omega) > 0.01 \
			and angle_deg >= t.perfect_release_min_deg \
			and angle_deg <= t.perfect_release_max_deg


func release(jumped: bool) -> void:
	var t := tuning()
	var p := player
	var released := anchor
	var speed := omega * rope_length
	var perfect := jumped and is_in_perfect_window()

	p.velocity = tangent() * speed * t.release_boost
	if perfect:
		p.velocity *= t.perfect_release_bonus
	if jumped:
		p.velocity.y += t.release_jump_bonus

	p.last_release_perfect = perfect
	last_anchor = released
	p.regrab_timer = t.regrab_cooldown
	anchor = null
	p.jump_held = false
	p.coyote_timer = 0.0
	p.change_state(Player.State.AIR)
	if is_instance_valid(released):
		released.set_grabbed(false)
	EventBus.vine_released.emit(released, perfect)
