extends GreyboxRoom
## "Üst Kökler" (M5) — Ocak Odası'nın tavanından (kanca kapısı) çıkılan koridor.
## Tek fikir: **derinlik sırrı** (Sütun 4). Koridorun sonu yandan bakınca kapalı bir duvar;
## ama son birkaç metrede kamera derinliğe döner ve duvarın bir kısmının sahte olduğu görülür:
## arkasındaki geçit Gizli Oda'ya (Kut parçası) iner. İpucu: duvarın dibinden sızan ışık.

const SECRET_X1: float = 33.0
const SECRET_X2: float = 37.0

var _illusion: MeshInstance3D


## Kamera derinliğe dönünce sahte duvar kaybolur ("bu dünyanın arkası da varmış").
func _process(_delta: float) -> void:
	if _illusion != null:
		_illusion.visible = CameraDirector.is_side_mode()


func _build() -> void:
	# Arka duvar: sır bölümü (x 33 → 37) çarpışmasız "sahte" duvar
	backdrop(-12.0, SECRET_X1, -2.0, 14.0, C_ROOT)
	backdrop(SECRET_X2, 42.0, -2.0, 14.0, C_ROOT)
	_illusion = illusion_box(Vector3((SECRET_X1 + SECRET_X2) * 0.5, 6.0, -3.5), Vector3(SECRET_X2 - SECRET_X1, 16.0, 1.0), C_ROOT)
	# Zemin: batıda aşağı açıklık (x -2 → 2, Ocak Odası'na iner)
	platform(-12.0, -2.0, 0.0, 2.0, C_BARK, 4.0)
	platform(2.0, 42.0, 0.0, 2.0, C_BARK, 4.0)
	box(Vector3(-12.5, 7.0, 0.0), Vector3(1.0, 14.0, 4.0), C_ROOT)    # batı duvarı
	box(Vector3(41.5, 7.0, 0.0), Vector3(1.0, 14.0, 4.0), C_ROOT)     # doğu duvarı (çıkmaz)
	box(Vector3(15.0, 13.5, 0.0), Vector3(56.0, 1.0, 4.0), C_ROOT)    # tavan
	# Koridor: bir Şişkin + bir Sürüngen
	bloater(Vector3(22.0, 3.0, 0.0))
	crawler(Vector3(28.0, 0.1, 0.0), -1.0)
	# Sır: geçit (z -4 → -14) + ipucu ışığı
	box(Vector3((SECRET_X1 + SECRET_X2) * 0.5, -1.0, -8.5), Vector3(SECRET_X2 - SECRET_X1, 2.0, 13.0), C_CAVE)  # z -15 → -2 (ana zeminle birleşik)
	box(Vector3(SECRET_X1 - 0.5, 3.0, -9.0), Vector3(1.0, 6.0, 12.0), C_CAVE)
	box(Vector3(SECRET_X2 + 0.5, 3.0, -9.0), Vector3(1.0, 6.0, 12.0), C_CAVE)
	box(Vector3((SECRET_X1 + SECRET_X2) * 0.5, 6.5, -9.0), Vector3(SECRET_X2 - SECRET_X1 + 2.0, 1.0, 12.0), C_CAVE)
	glow(Vector3(35.0, 0.3, -2.6), C_SAP)                             # duvar dibinden sızan ışık
	glow(Vector3(35.0, 0.3, -12.0), C_SAP)
	camera_zone(Vector3((SECRET_X1 + SECRET_X2) * 0.5, -3.5, -6.5),
			Vector3(SECRET_X2 - SECRET_X1, 20.0, 17.0), CameraRig.Mode.DEPTH, 0.8)
