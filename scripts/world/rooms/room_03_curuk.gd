extends GreyboxRoom
## Oda 3 — "Çürük Geçit": tek fikir = durmadan akmak. Çürük sarmaşıklar 1.5 sn'de kopar;
## ortada tek bir sağlam sarmaşık "nefes" noktası; sonda tırmanma sarmaşığıyla hedefe çıkış.


func _build() -> void:
	room_id = &"curuk"
	display_name = "Çürük Geçit"
	idea = "Çürük sarmaşıklar: beklemek yok, akış zorunlu"
	spawn_point = Vector3(-5.0, 0.5, 0.0)

	backdrop(-10.0, 42.0, -6.0, 26.0, C_CAVE)
	platform(-10.0, 2.0, 0.0, 2.0, C_BARK, 4.0)

	rotten_vine(Vector3(5.5, 6.5, 0.0), 3.2)
	rotten_vine(Vector3(11.5, 9.0, 0.0), 3.5)
	vine(Vector3(17.5, 11.5, 0.0), 3.5)                   # sağlam: nefes
	rotten_vine(Vector3(23.5, 14.0, 0.0), 3.5)

	climb_vine(Vector3(29.0, 21.0, 0.0), 8.0)             # y 13 → 21
	platform(31.0, 40.0, 19.5, 1.0, C_MOSS, 4.0)
	glow(Vector3(17.5, 6.0, -2.0), C_GLOW)
	place_goal(Vector3(36.0, 19.5, 0.0))
