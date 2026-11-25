class_name PlayerMoveState
extends PlayerState
## GROUND + AIR: koşma, zıplama (coyote/buffer), değişken zıplama, asimetrik yerçekimi,
## havada momentum koruma ve havadayken sarmaşık yakalama.


func can_attack() -> bool:
	return true


func physics_update(delta: float) -> void:
	var t := tuning()
	var p := player
	var input := p.get_move_input()
	var on_floor := p.is_on_floor()

	if on_floor:
		p.coyote_timer = t.coyote_time
		p.change_state(Player.State.GROUND)
	else:
		p.change_state(Player.State.AIR)

	# Yatay hız (tırmanmadan yana zıplamadan hemen sonra kısa süre girdi kilitli)
	if p.input_lock_timer <= 0.0:
		var desired := p.input_to_world(input) * t.run_speed
		var horizontal := Vector3(p.velocity.x, 0.0, p.velocity.z)
		var rate: float
		if desired.length_squared() > 0.0001:
			rate = t.ground_accel
		else:
			rate = t.ground_decel
		if not on_floor:
			rate *= t.air_control
		# Momentum koruma: havada koşu hızının üstündeyken ve girdi aynı yöndeyse
		# hız koşu hızına kırpılmaz, yalnızca hafif sürtünmeyle azalır (Sütun 1).
		var overspeed := not on_floor and horizontal.length() > t.run_speed \
				and desired.length_squared() > 0.0001 and horizontal.dot(desired) > 0.0
		if overspeed:
			horizontal = horizontal.move_toward(
					horizontal.normalized() * t.run_speed, t.air_overspeed_drag * delta)
		else:
			horizontal = horizontal.move_toward(desired, rate * delta)
		p.velocity.x = horizontal.x
		p.velocity.z = horizontal.z

	# Yan modda raya çekilme (derinlikten çıkışta yumuşak dönüş de buradan gelir)
	if CameraDirector.is_side_mode():
		p.velocity.z = p.rail_velocity_z()

	# Zıplama (coyote time + jump buffer)
	if p.jump_buffer_timer > 0.0 and p.coyote_timer > 0.0:
		p.velocity.y = t.get_jump_velocity()
		p.jump_buffer_timer = 0.0
		p.coyote_timer = 0.0
		p.jump_held = true
		on_floor = false

	# Asimetrik yerçekimi
	if not on_floor:
		p.apply_gravity(delta)

	# Değişken zıplama: tuş erken bırakılırsa yükseliş kesilir
	if p.jump_held and not Input.is_action_pressed(&"jump"):
		p.jump_held = false
		if p.velocity.y > 0.0:
			p.velocity.y *= t.jump_cut
	if p.velocity.y <= 0.0:
		p.jump_held = false

	p.move_and_slide()

	# Güvenli nokta yalnızca gerçek bir hareket sonrası zemindeyken güncellenir
	# (ışınlanma sonrası bayat is_on_floor değerine güvenilmez).
	if p.is_on_floor() and p.global_position.y > t.kill_y + 2.0:
		p.mark_safe_position()
	else:
		p.try_grab()
