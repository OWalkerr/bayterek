class_name PlayerDeadState
extends PlayerState
## Can 0: oyuncu yere düşer ve kontrol kilitlenir. Oda yeniden başlatmayı kabuk yapar
## (EventBus.player_died). M4'te "son Ocak'a dön" olur.


func enter(_previous: int) -> void:
	player.velocity.x = 0.0
	player.velocity.z = 0.0


func physics_update(delta: float) -> void:
	var p := player
	if not p.is_on_floor():
		p.apply_gravity(delta)
	else:
		p.velocity.y = 0.0
	p.move_and_slide()
