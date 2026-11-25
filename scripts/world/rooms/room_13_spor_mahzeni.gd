extends GreyboxRoom
## "Spor Mahzeni" (M5) — tek fikir: kalabalığı kancayla aşmak ya da dövüşmek.
## Zemin boyunca Sürüngenler, ortada üç Şişkin bulutu; tavandaki kanca çiçeği üstlerinden geçirir.


func _build() -> void:
	backdrop(-11.0, 41.0, -2.0, 16.0, C_CAVE)
	platform(-11.0, 41.0, 0.0, 2.0, C_BARK, 4.0)
	box(Vector3(15.0, 14.5, 0.0), Vector3(52.0, 1.0, 4.0), C_CAVE)     # tavan
	crawler(Vector3(6.0, 0.1, 0.0), -1.0)
	crawler(Vector3(32.0, 0.1, 0.0), 1.0)
	bloater(Vector3(17.0, 2.6, 0.0))
	bloater(Vector3(20.5, 3.4, 0.0))
	bloater(Vector3(24.0, 2.6, 0.0))
	grapple_flower(Vector3(20.5, 11.0, 0.0))
	glow(Vector3(-8.0, 0.4, -1.5))
	glow(Vector3(38.0, 0.4, -1.5))
