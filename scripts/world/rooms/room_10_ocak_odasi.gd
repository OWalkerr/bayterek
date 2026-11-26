extends GreyboxRoom
## "Ocak Odası" — Kök Dibi'nin merkez odası (M4). Yeni oyun burada başlar; Ocak'ta dinlenilir.
## Batı kapısı → Tırmanma Kuyusu (alt), doğu kapısı → Çürük Yuvası, tavan → Üst Kökler (kanca).
## Yukarıda görünür hedef: tavan açıklığındaki kanca çiçeği ve gök ışığı (docs/02 Kural 2 + kapı kuralı).


func _build() -> void:
	parallax_preset = &"sky"   # tavan açıklığından gök deliği görünür (Umay ipucu)
	backdrop(-13.0, 13.0, -2.0, 14.0, C_ROOT)
	platform(-13.0, 13.0, 0.0, 2.0, C_BARK, 4.0)
	box(Vector3(-12.0, 8.5, 0.0), Vector3(2.0, 11.0, 4.0), C_ROOT)    # sol duvar (kapının üstü, y 3 →)
	box(Vector3(12.0, 8.5, 0.0), Vector3(2.0, 11.0, 4.0), C_ROOT)     # sağ duvar
	box(Vector3(-8.0, 13.5, 0.0), Vector3(6.0, 1.0, 4.0), C_ROOT)     # tavan (x -5 → 5 açık)
	box(Vector3(8.0, 13.5, 0.0), Vector3(6.0, 1.0, 4.0), C_ROOT)
	# Yukarı kapı (M5): en baştan görünen ama kancasız ulaşılamayan çiçek → Üst Kökler.
	# Sarmaşık tepesinden (el ≈ 9.85 m) çiçek 7.2 m → kanca menzilinde; zıplama ≈ 11.7 m < kapı 14 m.
	climb_vine(Vector3(-6.0, 10.0, 0.0), 9.0)
	grapple_flower(Vector3(-1.0, 15.0, 0.0))
	glow(Vector3(0.0, 13.0, -1.5), C_SKY)                             # yukarıdaki ışık
	glow(Vector3(-9.0, 0.4, -1.5))
	glow(Vector3(9.0, 0.4, -1.5))
	# M7 sanat: Ocak'ın arkasında kök kemer (ocak köşesi), kenarlarda kayalar; zeminde ince sis
	decor(E_ARCH, Vector3(0.0, 0.0, -2.7), 0.0, 1.3)
	decor(E_ROCK, Vector3(-9.8, 0.0, -2.2), 40.0, 0.9)
	decor(E_ROCK, Vector3(10.0, 0.0, -2.3), -20.0, 0.7)
	fog(Vector3(-7.0, 0.0, -0.3), Vector3(6.0, 1.0, 3.0))
	fog(Vector3(7.0, 0.0, -0.3), Vector3(6.0, 1.0, 3.0))
	# Varlık seti 2: Ocak'ın iki yanında mangal, duvarlarda meşale, tavandan asılı ruh kandilleri
	brazier(Vector3(-4.5, 0.0, -1.6))
	brazier(Vector3(4.5, 0.0, -1.6))
	torch(Vector3(-10.95, 4.0, -1.2), 90.0)
	torch(Vector3(10.95, 4.0, -1.2), -90.0)
	spirit_lantern(Vector3(-8.0, 13.0, -1.0), 1.2)
	spirit_lantern(Vector3(8.5, 13.0, -1.2), 0.7)
