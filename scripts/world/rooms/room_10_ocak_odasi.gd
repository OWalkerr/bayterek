extends GreyboxRoom
## "Ocak Odası" — Kök Dibi'nin merkez odası (M4). Yeni oyun burada başlar; Ocak'ta dinlenilir.
## Batı kapısı → Tırmanma Kuyusu (alt), doğu kapısı → Çürük Yuvası. Yukarıda görünür hedef:
## kuyunun tepesinden süzülen gök ışığı (docs/02 Oda Kuralı 2).


func _build() -> void:
	backdrop(-13.0, 13.0, -2.0, 14.0, C_ROOT)
	platform(-13.0, 13.0, 0.0, 2.0, C_BARK, 4.0)
	box(Vector3(-12.0, 8.5, 0.0), Vector3(2.0, 11.0, 4.0), C_ROOT)    # sol duvar (kapının üstü, y 3 →)
	box(Vector3(12.0, 8.5, 0.0), Vector3(2.0, 11.0, 4.0), C_ROOT)     # sağ duvar
	box(Vector3(-7.0, 13.5, 0.0), Vector3(8.0, 1.0, 4.0), C_ROOT)     # tavan (ortası açık)
	box(Vector3(7.0, 13.5, 0.0), Vector3(8.0, 1.0, 4.0), C_ROOT)
	glow(Vector3(0.0, 13.0, -1.5), C_SKY)                             # yukarıdaki ışık
	glow(Vector3(-9.0, 0.4, -1.5))
	glow(Vector3(9.0, 0.4, -1.5))
