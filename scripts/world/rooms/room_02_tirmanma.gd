extends GreyboxRoom
## Oda 2 — "Tırmanma Kuyusu": tek fikir = tırmanma sarmaşıkları arasında yana zıplayarak yükselmek.
## Dikey kuyu; ortada dinlenme çıkıntısı, en üstte bir sallanma sarmaşığıyla hedefe savrulma.


func _build() -> void:
	room_id = &"tirmanma"
	display_name = "Tırmanma Kuyusu"
	idea = "Tırmanma sarmaşıkları arası yana zıplama, yukarı = umut"
	spawn_point = Vector3(-2.0, 0.5, 0.0)

	backdrop(-6.0, 16.0, -1.0, 34.0)
	platform(-6.0, 16.0, 0.0, 2.0, C_BARK, 4.0)           # kuyu tabanı
	box(Vector3(-5.5, 16.0, 0.0), Vector3(1.0, 34.0, 4.0), C_ROOT)   # sol duvar
	box(Vector3(15.5, 16.0, 0.0), Vector3(1.0, 34.0, 4.0), C_ROOT)   # sağ duvar

	climb_vine(Vector3(0.0, 8.0, 0.0), 7.0)               # A: y 1 → 8
	climb_vine(Vector3(4.5, 13.0, 0.0), 7.0)              # B: y 6 → 13
	platform(8.0, 15.0, 11.0, 0.5)                        # dinlenme çıkıntısı (B'nin sağında)
	climb_vine(Vector3(0.0, 19.0, 0.0), 7.0)              # C: y 12 → 19
	climb_vine(Vector3(4.5, 24.0, 0.0), 6.0)              # D: y 18 → 24

	# Tepede: D'den sağa sallanma sarmaşığı → yukarı savrulup hedef çıkıntısına
	vine(Vector3(7.5, 29.5, 0.0), 4.0)
	platform(12.0, 15.0, 27.0, 0.5)
	glow(Vector3(-4.6, 10.0, -1.0))
	glow(Vector3(14.6, 20.0, -1.0))
	place_goal(Vector3(13.5, 27.0, 0.0))
