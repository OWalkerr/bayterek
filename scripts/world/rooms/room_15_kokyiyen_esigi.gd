extends GreyboxRoom
## "Kökyiyen Eşiği" (M5) — boss odasından hemen önce Ocak (docs/02 kuralı). Doğuda mühürlü
## kök kapısı: Kökyiyen'in İni M6'da açılır. Zeminde nabız gibi atan çatlak ışıkları (uyarı).


func _build() -> void:
	backdrop(-9.0, 22.0, -2.0, 16.0, C_CAVE)
	platform(-9.0, 22.0, 0.0, 2.0, C_BARK, 4.0)
	box(Vector3(6.5, 12.5, 0.0), Vector3(31.0, 1.0, 4.0), C_CAVE)     # tavan
	# Mühürlü kapı: kalın kök örgüsü
	box(Vector3(20.0, 5.0, 0.0), Vector3(2.0, 10.0, 4.0), C_ROOT)
	for y: float in [1.5, 4.0, 6.5, 9.0]:
		box(Vector3(18.6, y, 0.0), Vector3(0.8, 0.6, 3.6), C_SAP.darkened(0.5))
	var sign := Label3D.new()
	sign.text = "Kökyiyen'in İni\n(mühürlü — M6)"
	sign.font_size = 56
	sign.outline_size = 12
	sign.modulate = C_SKY
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(16.0, 4.5, 1.0)
	add_child(sign)
	glow(Vector3(12.0, 0.3, -1.0), Color("5a1e5c"))
	glow(Vector3(15.0, 0.3, 1.0), Color("5a1e5c"))
