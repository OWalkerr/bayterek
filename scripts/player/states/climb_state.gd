class_name PlayerClimbState
extends PlayerState
## Tırmanma sarmaşığı (docs/03 §2.3): yukarı/aşağı, yana zıplama, yukarı sıçrama.

## Tırmanırken elin sarmaşık uçlarına ne kadar yaklaşabileceği.
const END_MARGIN: float = 0.15

var vine: ClimbVine = null
var last_vine: ClimbVine = null


func begin(new_vine: ClimbVine) -> void:
	vine = new_vine
	var p := player
	p.velocity = Vector3.ZERO
	p.jump_buffer_timer = 0.0
	p.jump_held = false
	p.change_state(Player.State.CLIMB)
	EventBus.climb_started.emit(vine)


func physics_update(delta: float) -> void:
	if not is_instance_valid(vine) or not vine.enabled:
		release(Vector3.ZERO, false)
		return
	var t := tuning()
	var p := player
	var input := p.get_move_input()
	var hand_y := p.get_hand_position().y
	var top_y := vine.get_top().y - END_MARGIN
	var bottom_y := vine.get_bottom().y + END_MARGIN

	# Zıplama: yön tuşu basılıysa yana, değilse yukarı sıçrama
	if p.jump_buffer_timer > 0.0:
		p.jump_buffer_timer = 0.0
		var dir := p.input_to_world(Vector2(input.x, 0.0 if CameraDirector.is_side_mode() else input.y))
		var jump_vel := Vector3.UP * t.get_climb_jump_velocity()
		if dir.length() > 0.3:
			jump_vel += dir.normalized() * t.climb_jump_speed_x
			p.input_lock_timer = t.climb_jump_lock
		release(jump_vel, true)
		return

	# Aşağı basılıyken alt uca gelindiyse bırak
	if input.y < -0.5 and hand_y <= bottom_y + 0.01:
		release(Vector3.ZERO, false)
		return

	var climb_dir := input.y
	if climb_dir > 0.0 and hand_y >= top_y:
		climb_dir = 0.0
	var target_y := clampf(hand_y + climb_dir * t.climb_speed * delta, bottom_y, top_y)

	# Gövdeyi sarmaşığa doğru yumuşakça hizala; dikeyde hedefe git
	var vine_point := vine.get_top()
	var target := Vector3(vine_point.x, target_y - Player.HAND_HEIGHT,
			p.rail_z if CameraDirector.is_side_mode() else vine_point.z)
	var to_target := target - p.global_position
	var snap := minf(1.0, t.rail_pull * delta * 2.0)
	p.velocity = Vector3(to_target.x * snap, to_target.y, to_target.z * snap) / delta
	p.move_and_slide()

	# Aşağı inerken yere değdiyse sarmaşıktan in
	if p.is_on_floor() and input.y < -0.5:
		release(Vector3.ZERO, false)


func release(new_velocity: Vector3, jumped: bool) -> void:
	var p := player
	var released := vine
	p.velocity = new_velocity
	last_vine = released
	p.climb_regrab_timer = tuning().climb_regrab_cooldown
	vine = null
	p.jump_held = jumped
	p.coyote_timer = 0.0
	p.change_state(Player.State.AIR)
	EventBus.climb_ended.emit(released, jumped)
