extends GreyboxRoom
## "Çiçek Kuyusu" (M5) — tek fikir: tırmanma + kanca birlikte (dikey, yukarı = umut).
## Tırmanma sarmaşığı → kanca çiçeği → ikinci sarmaşık → kanca çiçeği → tepe çıkıntısı.
## Kancasız yalnızca ilk sarmaşığın tepesine (≈ 11 m) çıkılır; tepe kapısı 22.5 m.


func _build() -> void:
	backdrop(-7.0, 11.0, -1.0, 30.0, C_ROOT)
	platform(-7.0, 11.0, 0.0, 2.0, C_BARK, 4.0)
	box(Vector3(-6.5, 16.5, 0.0), Vector3(1.0, 27.0, 4.0), C_ROOT)    # sol duvar y 3 → 30 (altta kapı)
	box(Vector3(10.5, 11.25, 0.0), Vector3(1.0, 22.5, 4.0), C_ROOT)   # sağ duvar y 0 → 22.5
	box(Vector3(10.5, 27.75, 0.0), Vector3(1.0, 4.5, 4.0), C_ROOT)    # sağ duvar y 25.5 → 30 (arada kapı)
	climb_vine(Vector3(-2.0, 9.0, 0.0), 8.0)                          # A: y 1 → 9
	grapple_flower(Vector3(3.5, 13.5, 0.0))
	climb_vine(Vector3(7.0, 21.0, 0.0), 9.0)                          # B: y 12 → 21
	# Çiçek 2 sarkaç dibi ≈ 20 m; ileri kolda bırakınca yay ≈ 24 m'ye çıkar → 22.5 m çıkıntıya rahat iniş
	grapple_flower(Vector3(2.0, 26.0, 0.0))
	platform(6.5, 10.0, 22.5, 0.5, C_MOSS)                            # tepe çıkıntısı (B tepesinden çiçek 2 görüşü açık kalsın)
	glow(Vector3(-5.6, 12.0, -0.5))
	glow(Vector3(9.6, 23.0, -0.5), C_SAP)
