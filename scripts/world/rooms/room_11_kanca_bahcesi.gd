extends GreyboxRoom
## "Kanca Bahçesi" (M5) — tek fikir: Kamçı Kancası ile sarmaşıksız uçurumu aşmak.
## 22 m uçurum, hiç sallanma sarmaşığı yok: yalnızca kanca çiçekleri. Kancasız geçilemez
## (zıplama ≈ 6 m) → yetenek kapısı. İki yönde de kanca gerekir (RoomDoor.requires).


func _build() -> void:
	backdrop(-11.0, 40.0, -8.0, 22.0, C_ROOT)
	platform(-11.0, 4.0, 0.0, 2.0, C_BARK, 4.0)            # batı kıyısı
	platform(26.0, 40.0, 1.0, 3.0, C_BARK, 4.0)            # doğu kıyısı
	grapple_flower(Vector3(9.0, 7.5, 0.0))
	grapple_flower(Vector3(16.0, 8.0, 0.0))
	grapple_flower(Vector3(22.5, 8.5, 0.0))
	glow(Vector3(-8.0, 0.4, -1.5))
	glow(Vector3(33.0, 1.4, -1.5))
