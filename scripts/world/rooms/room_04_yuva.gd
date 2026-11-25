extends GreyboxRoom
## Oda 4 — "Çürük Yuvası" (M2 savaş odası): kamçının üç fiili tek odada.
##  1) Zeminde Çürük Sürüngenler → 3'lü kombo ("Vurabiliyor musun?")
##  2) Çukur üstünde sallanma sarmaşığı + süzülen Spor Şişkini → Savrulma Saldırısı / mesafe
##  3) Yüksek çıkıntı zıplamayla erişilemez → tümsekten zıpla, sabit Şişkin'e aşağı vuruş = pogo
##     (Şişkin 4 sn'de yeniden doğar: soft-lock yok)


func _build() -> void:
	backdrop(-10.0, 50.0, -6.0, 18.0, C_CAVE)
	platform(-10.0, 12.0, 0.0, 2.0, C_BARK, 4.0)           # başlangıç zemini
	crawler(Vector3(6.0, 0.1, 0.0), -1.0)
	platform(12.0, 22.0, 1.5, 3.5, C_BARK, 4.0)            # basamak (1.5 m)
	crawler(Vector3(17.0, 1.6, 0.0), 1.0)

	# Çukur: sarmaşık + sürüklenen Şişkin
	vine(Vector3(26.0, 8.0, 0.0), 3.5)
	bloater(Vector3(27.0, 3.5, 0.0))

	platform(30.0, 40.0, 1.5, 3.5, C_BARK, 4.0)            # iniş
	crawler(Vector3(31.5, 1.6, 0.0), 1.0)

	# Pogo kapısı: tümsekten (3 m) zıplayınca ayak tepesi ≈ 5.2 m → Şişkin'in (3.8 m, isabet alanı
	# tepesi 4.35 m) rahatça üstüne çıkılır; aşağı vuruş pogo ile ≈ 7 m. Çıkıntı 6 m: normal zıplama yetmez.
	# Şişkin'in altı (3.25 m) ayakta duran oyuncunun başından (3.1 m) yüksek → altından geçmek güvenli.
	platform(33.0, 35.5, 3.0, 1.5, C_MOSS, 3.0)            # tümsek (1.5 m basamak)
	var gate := bloater(Vector3(38.5, 3.8, 0.0), 4.0)
	gate.aggro_range = 0.0
	platform(40.0, 48.0, 6.0, 4.5, C_MOSS, 4.0)
	glow(Vector3(39.0, 7.3, -1.5), C_SAP)
	place_goal(Vector3(45.0, 6.0, 0.0))
