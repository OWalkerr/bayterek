extends GreyboxRoom
## Oda 1 — "Savrulma Zinciri": tek fikir = sarmaşıktan sarmaşığa momentumu koruyarak geçmek.
## Yere basmadan 4 sarmaşık; son boşluk "mükemmel bırakma" ile rahat, normal bırakmayla zor.
## Çukurun dibi yok: düşen başlangıca döner (düşük ölüm cezası).


func _build() -> void:
	room_id = &"savrulma"
	display_name = "Savrulma Zinciri"
	idea = "Yere basmadan sarmaşık zinciri; ritim ve mükemmel bırakma"
	spawn_point = Vector3(-5.0, 0.5, 0.0)

	backdrop(-10.0, 42.0, -6.0, 24.0)
	platform(-10.0, 2.0, 0.0, 2.0, C_BARK, 4.0)          # başlangıç

	# Yükselen zincir: aralık 6 m (docs/02: tipik 4–7 m), her sarmaşık 2.5 m yukarıda.
	# Bırakma zıplama bonusu (+6 m/s) yayı yukarı taşır; bir sonraki sarmaşık yayın tepesine denk gelir.
	vine(Vector3(5.5, 6.5, 0.0), 3.2)
	vine(Vector3(11.5, 9.0, 0.0), 3.5)
	vine(Vector3(17.5, 11.5, 0.0), 3.5)
	vine(Vector3(23.5, 14.0, 0.0), 3.5)

	# Varış çıkıntısı
	platform(28.0, 38.0, 13.0, 1.0, C_MOSS, 4.0)
	glow(Vector3(29.0, 13.4, -1.0))
	place_goal(Vector3(34.0, 13.0, 0.0))
