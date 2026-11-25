extends GreyboxRoom
## Oda 5 — "Yankı Mağarası" (M3 derinlik odası). Tek fikir: "bu dünyanın arkası da varmış" (Sütun 4).
## Ön katmandan (Z=0) mağara ağzına girilir → kamera DEPTH'e döner → mağarada derinliğe yürü,
## uçurumu sarmaşıkla aş (sarkaç derinlik düzleminde) → sağdaki tünelden çık → kamera SIDE'a
## döner ama oyuncu **arka koridorda** (SideRail Z=-24) kalır → basamaklardan hedefe.
##
## Yerleşim (üstten, x sağa, z aşağı = derin):
##   z=0    ████ ön zemin x -10→18 ████ (mağara ağzı x 10→18)
##   z=-2…-10   mağara zemini
##   z=-10…-18  UÇURUM 8 m (zıplama ≈ 6 m → sarmaşık şart; x=14, z=-14)
##   z=-18…-30  arka zemin ──► tünel (z -26…-22) ──► arka koridor x 30→56 (SideRail Z=-24)

const CAVE_X1: float = 10.0
const CAVE_X2: float = 30.0
const BACK_RAIL_Z: float = -24.0


func _build() -> void:
	room_id = &"yanki"
	display_name = "Yankı Mağarası"
	idea = "Derinlik bir sırdır: mağaradan arka katmana çık"
	spawn_point = Vector3(-6.0, 0.5, 0.0)

	# Ön katman
	box(Vector3(4.0, -1.0, 0.0), Vector3(28.0, 2.0, 4.0), C_BARK)          # x -10 → 18
	box(Vector3(0.0, 8.0, -3.5), Vector3(20.0, 20.0, 1.0), C_ROOT)          # arka duvar (x -10 → 10)
	box(Vector3(14.0, 12.0, -3.5), Vector3(8.0, 12.0, 1.0), C_ROOT)         # ağzın üstü (y 6 → 18)
	glow(Vector3(9.0, 0.4, -2.0))

	# Mağara kabuğu
	box(Vector3(20.0, -1.0, -6.0), Vector3(20.0, 2.0, 8.0), C_CAVE)         # zemin z -2 → -10 (ön zeminle birleşik)
	box(Vector3(20.0, -1.0, -24.0), Vector3(20.0, 2.0, 12.0), C_CAVE)       # arka zemin z -18 → -30
	box(Vector3(CAVE_X1 - 0.5, 4.0, -16.0), Vector3(1.0, 10.0, 28.0), C_CAVE)   # sol duvar
	box(Vector3(CAVE_X2 + 0.5, 4.0, -12.0), Vector3(1.0, 10.0, 20.0), C_CAVE)   # sağ duvar z -2 → -22
	box(Vector3(CAVE_X2 + 0.5, 4.0, -28.5), Vector3(1.0, 10.0, 5.0), C_CAVE)    # sağ duvar z -26 → -31
	box(Vector3(CAVE_X2 + 0.5, 7.0, -24.0), Vector3(1.0, 4.0, 4.0), C_CAVE)     # tünel tavanı
	box(Vector3(20.0, 9.5, -16.0), Vector3(22.0, 1.0, 30.0), C_CAVE)        # tavan
	box(Vector3(20.0, 4.0, -30.5), Vector3(22.0, 10.0, 1.0), C_CAVE)        # dip duvar
	box(Vector3(24.0, 1.0, -6.0), Vector3(2.0, 2.0, 2.0), C_ROOT)           # sütun (etrafından dolaş)

	# Uçurum üstü sarmaşık (derinlik düzleminde sarkaç)
	vine(Vector3(14.0, 7.5, -14.0), 4.0)
	glow(Vector3(12.0, 0.4, -9.0))
	glow(Vector3(16.0, 0.4, -19.0))
	glow(Vector3(28.0, 0.5, -29.0), C_SAP)                                 # sır: köşedeki Öz ışığı
	crawler(Vector3(22.0, 0.1, -27.0), 1.0)

	# Bölge ön raya (Z=0) kadar uzanır: yan modda sağa yürüyen oyuncu ağza girince DEPTH başlar.
	# Aşağıda düşüş sınırına (kill_y) kadar iner: uçuruma düşerken kamera SIDE'a dönüp savrulmasın.
	var zone := camera_zone(Vector3((CAVE_X1 + CAVE_X2) * 0.5, -3.5, -14.5),
			Vector3(CAVE_X2 - CAVE_X1, 25.0, 33.0))
	zone.name = "CaveZone"

	# Arka koridor (SIDE, Z=-24): yandan bakınca ön katmanın "arkasında"
	side_rail(BACK_RAIL_Z, CAVE_X2, 60.0)
	box(Vector3(45.0, -1.0, BACK_RAIL_Z), Vector3(30.0, 2.0, 4.0), C_BARK)  # x 30 → 60
	box(Vector3(45.0, 8.0, BACK_RAIL_Z - 3.5), Vector3(30.0, 20.0, 1.0), C_ROOT)
	platform(40.0, 44.0, 1.5, 0.5, C_MOSS, 3.0).position.z = BACK_RAIL_Z
	platform(45.0, 49.0, 3.0, 0.5, C_MOSS, 3.0).position.z = BACK_RAIL_Z
	platform(50.0, 58.0, 4.5, 0.5, C_MOSS, 3.0).position.z = BACK_RAIL_Z
	place_goal(Vector3(55.0, 4.5, BACK_RAIL_Z))
