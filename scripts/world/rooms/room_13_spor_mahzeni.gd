extends GreyboxRoom
## "Spor Mahzeni" (M5) — tek fikir: kalabalığı kancayla aşmak ya da dövüşmek.
## Zemin boyunca Sürüngenler, ortada üç Şişkin bulutu; tavandaki kanca çiçeği üstlerinden geçirir.
## M7: girişte alçak kök sarkıntısında iki Kapan Çiçek ("dikkat"), arka duvardan Kök Yılanı ("zamanlama").


func _build() -> void:
	backdrop(-11.0, 41.0, -2.0, 16.0, C_CAVE)
	platform(-11.0, 41.0, 0.0, 2.0, C_BARK, 4.0)
	box(Vector3(15.0, 14.5, 0.0), Vector3(52.0, 1.0, 4.0), C_CAVE)     # tavan
	box(Vector3(9.5, 6.0, 0.0), Vector3(6.0, 1.0, 4.0), C_ROOT)          # alçak kök sarkıntısı (alt yüz 5.5)
	trap_flower(Vector3(8.0, 5.5, 0.0))
	trap_flower(Vector3(11.0, 5.5, 0.0))
	root_snake(Vector3(28.0, 1.0, -1.9), Vector3.BACK)
	crawler(Vector3(6.0, 0.1, 0.0), -1.0)
	crawler(Vector3(32.0, 0.1, 0.0), 1.0)
	bloater(Vector3(17.0, 2.6, 0.0))
	bloater(Vector3(20.5, 3.4, 0.0))
	bloater(Vector3(24.0, 2.6, 0.0))
	grapple_flower(Vector3(20.5, 11.0, 0.0))
	glow(Vector3(-8.0, 0.4, -1.5))
	glow(Vector3(38.0, 0.4, -1.5))
	decor(E_ARCH, Vector3(-4.0, 0.0, -2.8), 0.0, 1.2)
	decor(E_ROCK, Vector3(34.0, 0.0, -2.2), 60.0)
	# spor sisi: Şişkinlerin altında yere çökmüş zehirli pus (görsel; hasar vermez)
	fog(Vector3(20.5, 0.0, 0.0), Vector3(12.0, 1.8, 3.6)).color = Color("b7a3c9")
