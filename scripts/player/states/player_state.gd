class_name PlayerState
extends RefCounted
## Oyuncu durumlarının tabanı. Player bağlamdır (girdi, zamanlayıcılar, güvenli nokta);
## durum nesneleri kendi verisini tutar ve `physics_update` içinde oyuncuyu hareket ettirir.
## Durum değişimi her zaman `player.change_state()` ile yapılır.

var player: Player


func _init(owner_player: Player) -> void:
	player = owner_player


func tuning() -> PlayerTuning:
	return player.tuning


func enter(_previous: int) -> void:
	pass


func exit(_next: int) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


## Saldırıya izin var mı (PlayerCombat sorar).
func can_attack() -> bool:
	return false
