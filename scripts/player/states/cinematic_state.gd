class_name PlayerCinematicState
extends PlayerState
## Sinematik sırasında oyuncu kilitli (CutsceneDirector, M8).


func physics_update(_delta: float) -> void:
	player.velocity = Vector3.ZERO
