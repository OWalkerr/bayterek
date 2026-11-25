extends GreyboxRoom
## "Kökyiyen Eşiği" (M5) — boss odasından hemen önce Ocak (docs/02 kuralı). Doğuda kök kapısı →
## Kökyiyen'in İni (M6). Zeminde nabız gibi atan çatlak ışıkları (uyarı).


func _build() -> void:
	backdrop(-9.0, 22.0, -2.0, 16.0, C_CAVE)
	platform(-9.0, 22.0, 0.0, 2.0, C_BARK, 4.0)
	platform(20.0, 23.0, 0.0, 2.0, C_BARK, 4.0)
	box(Vector3(6.5, 12.5, 0.0), Vector3(31.0, 1.0, 4.0), C_CAVE)     # tavan
	# Kök kapısı (M6'da açıldı): çerçeve kalır, ortası geçit
	box(Vector3(20.0, 7.5, 0.0), Vector3(2.0, 5.0, 4.0), C_ROOT)      # lento y 5 → 10
	for y: float in [6.0, 8.5]:
		box(Vector3(18.6, y, 0.0), Vector3(0.8, 0.6, 3.6), C_SAP.darkened(0.5))
	var sign := Label3D.new()
	var beaten: bool = GameState.get_flag("kokyiyen_ini/boss_defeated", false)
	sign.text = "Kökyiyen'in İni\n(yenildi)" if beaten else "Kökyiyen'in İni"
	sign.font_size = 56
	sign.outline_size = 12
	sign.modulate = C_SKY
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(16.0, 4.5, 1.0)
	add_child(sign)
	glow(Vector3(12.0, 0.3, -1.0), Color("5a1e5c"))
	glow(Vector3(15.0, 0.3, 1.0), Color("5a1e5c"))
