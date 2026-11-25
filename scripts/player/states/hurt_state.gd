class_name PlayerHurtState
extends PlayerState
## Hasar alınca kısa kontrolsüz geri itilme (docs/03 §3). Sonra AIR'e döner.

var _timer: float = 0.0


func begin(knockback: Vector3) -> void:
	player.velocity = knockback
	_timer = tuning().hurt_stun_time
	player.change_state(Player.State.HURT)


func physics_update(delta: float) -> void:
	var p := player
	_timer -= delta
	p.apply_gravity(delta)
	if CameraDirector.is_side_mode():
		p.velocity.z = (p.rail_z - p.global_position.z) * tuning().rail_pull
	p.move_and_slide()
	if _timer <= 0.0:
		p.change_state(Player.State.AIR)
