extends GreyboxRoom
## "Sunak Odası" (M5) — Kamçı Kancası burada kazanılır (bölge ortası, karar 2026-11-25).
## Sunağın üstünde ilk kanca çiçeği: yeteneği alır almaz denenecek küçük bir çıkıntı.


func _build() -> void:
	backdrop(-9.0, 15.0, -2.0, 16.0, C_CAVE)
	platform(-9.0, 15.0, 0.0, 2.0, C_BARK, 4.0)
	box(Vector3(3.0, 15.5, 0.0), Vector3(24.0, 1.0, 4.0), C_CAVE)      # tavan
	platform(9.0, 14.0, 5.5, 0.5, C_MOSS)                              # deneme çıkıntısı
	grapple_flower(Vector3(7.0, 10.0, 0.0))
	glow(Vector3(12.0, 5.9, -1.0), C_SAP)
	glow(Vector3(-6.0, 0.4, -1.5))
	# Varlık seti 2: sunağı balbal taşları ve mangallar çevreler
	totem(Vector3(-2.2, 0.0, -1.8), 15.0)
	totem(Vector3(6.2, 0.0, -1.8), -15.0, 0.9)
	brazier(Vector3(-0.6, 0.0, -1.3))
	brazier(Vector3(4.6, 0.0, -1.3))
