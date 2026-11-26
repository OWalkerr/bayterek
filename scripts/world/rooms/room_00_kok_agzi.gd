extends GreyboxRoom
## Oda 0 — "Kök Ağzı" (M0 prototip odası): sallanma + mağara (DEPTH) + yukarı sarmaşık zinciri.
## Düzen (yan görünüm, Z=0 rayı):
##   Başlangıç zemini → çukur üstünde 2 sarmaşık → mağara ağzı (DEPTH) → basamaklar → yukarı zincir → ışık


func _build() -> void:
	# Zeminler (üst yüzey y=0)
	box(Vector3(-1.0, -1.0, 0.0), Vector3(18.0, 2.0, 4.0), C_BARK)     # x: -10 → 8
	box(Vector3(34.0, -1.0, 0.0), Vector3(32.0, 2.0, 4.0), C_BARK)     # x: 18 → 50
	box(Vector3(13.0, -9.0, 0.0), Vector3(10.0, 2.0, 4.0), C_ROOT)     # çukur tabanı

	# Arka duvar (mağara ağzında boşluk var: x 22 → 30)
	box(Vector3(6.0, 12.0, -3.5), Vector3(32.0, 30.0, 1.0), C_ROOT)
	box(Vector3(42.0, 12.0, -3.5), Vector3(24.0, 30.0, 1.0), C_ROOT)
	box(Vector3(26.0, 18.0, -3.5), Vector3(8.0, 18.0, 1.0), C_ROOT)    # mağara ağzının üstü

	# Kocabaş: başlangıç zemininin arkasında dinlenir (eğitim: "Alpay, Kocabaş ile oynar", docs/01)
	var kocabas := KocabasNpc.new()
	kocabas.position = Vector3(-5.5, 0.0, -1.9)
	kocabas.facing = 1.0
	add_child(kocabas)

	# Çukur üstündeki sarmaşıklar
	vine(Vector3(11.0, 6.5, 0.0), 3.2)
	vine(Vector3(15.5, 7.0, 0.0), 3.2)

	# Mağara (DEPTH modu): x 22 → 30, z -3 → -24
	box(Vector3(26.0, -1.0, -13.5), Vector3(8.0, 2.0, 23.0), C_CAVE)   # zemin (ana zeminle birleşik)
	box(Vector3(21.5, 4.0, -14.0), Vector3(1.0, 10.0, 22.0), C_CAVE)   # sol duvar
	box(Vector3(30.5, 4.0, -14.0), Vector3(1.0, 10.0, 22.0), C_CAVE)   # sağ duvar
	box(Vector3(26.0, 9.5, -14.0), Vector3(10.0, 1.0, 22.0), C_CAVE)   # tavan
	box(Vector3(26.0, 4.0, -25.5), Vector3(10.0, 10.0, 1.0), C_CAVE)   # dip
	box(Vector3(26.0, 1.0, -12.0), Vector3(2.0, 2.0, 2.0), C_ROOT)     # mağara içi engel
	vine(Vector3(26.0, 8.8, -18.0), 3.5)                               # mağara içi sarmaşık
	glow(Vector3(23.0, 0.4, -8.0))
	glow(Vector3(29.0, 0.4, -15.0))
	glow(Vector3(24.5, 0.4, -22.0))
	glow(Vector3(26.0, 0.5, -23.5), C_SAP)                             # "hazine": Kut parçası yeri

	var zone := camera_zone(Vector3(26.0, 3.0, -11.0), Vector3(5.0, 8.0, 26.0))
	zone.name = "CaveZone"

	# Basamaklar
	box(Vector3(35.0, 2.25, 0.0), Vector3(3.0, 0.5, 3.0), C_MOSS)
	box(Vector3(39.0, 4.5, 0.0), Vector3(3.0, 0.5, 3.0), C_MOSS)
	box(Vector3(35.5, 6.75, 0.0), Vector3(3.0, 0.5, 3.0), C_MOSS)

	# Yukarı sarmaşık zinciri
	vine(Vector3(40.0, 12.5, 0.0), 3.5)
	vine(Vector3(45.0, 15.0, 0.0), 3.5)
	vine(Vector3(50.0, 17.5, 0.0), 3.5)

	# Varış çıkıntısı + gök ışığı (hedef)
	box(Vector3(56.0, 15.75, 0.0), Vector3(6.0, 0.5, 3.0), C_MOSS)
	place_goal(Vector3(57.5, 16.0, 0.0))

	# M7 sanat: mağara ağzını çerçeveleyen kök kemer, kayalar, arka planda süzülen kök platform
	decor(E_CAVE_MOUTH, Vector3(26.0, 0.0, -3.0), 0.0, 1.35)
	decor(E_ROCK, Vector3(-8.5, 0.0, -2.3), 20.0)
	decor(E_ROCK, Vector3(46.0, 0.0, -2.4), -35.0, 0.8)
	decor(E_PLATFORM, Vector3(4.0, 8.5, -2.9), 10.0)
	# sis: çukurun dibi ve mağaranın derinliği
	fog(Vector3(13.0, -8.0, 0.0), Vector3(10.0, 2.5, 4.0))
	fog(Vector3(26.0, 0.0, -17.0), Vector3(7.0, 1.4, 12.0))
