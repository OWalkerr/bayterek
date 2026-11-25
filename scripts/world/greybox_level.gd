extends Node3D
## M0 greybox test seviyesi — kodla kurulur, böylece sanat gelmeden hareket/kamera denenebilir.
## Düzen (yan görünüm, Z=0 rayı):
##   Başlangıç zemini → çukur üstünde 2 sarmaşık → mağara ağzı (DEPTH) → basamaklar → yukarı sarmaşık zinciri → ışık
## M5'te el yapımı oda sahneleriyle (scenes/world/regions/kok_dibi/rooms) değiştirilecek.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SPAWN: Vector3 = Vector3(-6.0, 0.5, 0.0)

const C_BARK := Color("6b4a2f")
const C_ROOT := Color("4a3550")
const C_MOSS := Color("5e8c4a")
const C_CAVE := Color("2b1e3f")
const C_GLOW := Color("4fb3a9")
const C_SAP := Color("e8a33d")

var player: Player
var rig: CameraRig


func _ready() -> void:
	_build_environment()
	_build_level()
	_spawn_player()
	_build_camera()
	_build_debug_hud()


# ---------------------------------------------------------------- Ortam

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("1d2a44")
	sky_mat.sky_horizon_color = Color("4a5d7a")
	sky_mat.ground_bottom_color = Color("120c1c")
	sky_mat.ground_horizon_color = Color("2b1e3f")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color("3a2d55")
	env.fog_density = 0.008
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_color = Color("ffe2b0")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)


# ---------------------------------------------------------------- Seviye

func _build_level() -> void:
	# Zeminler (üst yüzey y=0)
	_box(Vector3(-1.0, -1.0, 0.0), Vector3(18.0, 2.0, 4.0), C_BARK)     # x: -10 → 8
	_box(Vector3(34.0, -1.0, 0.0), Vector3(32.0, 2.0, 4.0), C_BARK)     # x: 18 → 50
	_box(Vector3(13.0, -9.0, 0.0), Vector3(10.0, 2.0, 4.0), C_ROOT)     # çukur tabanı (düşülürse geri dönüş)

	# Arka duvar (mağara ağzında boşluk var: x 22 → 30)
	_box(Vector3(6.0, 12.0, -3.5), Vector3(32.0, 30.0, 1.0), C_ROOT)
	_box(Vector3(42.0, 12.0, -3.5), Vector3(24.0, 30.0, 1.0), C_ROOT)
	_box(Vector3(26.0, 18.0, -3.5), Vector3(8.0, 18.0, 1.0), C_ROOT)    # mağara ağzının üstü

	# Çukur üstündeki sarmaşıklar
	_vine(Vector3(11.0, 6.5, 0.0), 3.2)
	_vine(Vector3(15.5, 7.0, 0.0), 3.2)

	# Mağara (DEPTH modu): x 22 → 30, z -3 → -24
	_box(Vector3(26.0, -1.0, -13.5), Vector3(8.0, 2.0, 23.0), C_CAVE)   # zemin (z -25 → -2, ana zeminle birleşik)
	_box(Vector3(21.5, 4.0, -14.0), Vector3(1.0, 10.0, 22.0), C_CAVE)   # sol duvar
	_box(Vector3(30.5, 4.0, -14.0), Vector3(1.0, 10.0, 22.0), C_CAVE)   # sağ duvar
	_box(Vector3(26.0, 9.5, -14.0), Vector3(10.0, 1.0, 22.0), C_CAVE)   # tavan
	_box(Vector3(26.0, 4.0, -25.5), Vector3(10.0, 10.0, 1.0), C_CAVE)   # dip
	_box(Vector3(26.0, 1.0, -12.0), Vector3(2.0, 2.0, 2.0), C_ROOT)     # mağara içi engel
	_vine(Vector3(26.0, 8.8, -18.0), 3.5)                               # mağara içi sarmaşık
	_glow(Vector3(23.0, 0.4, -8.0))
	_glow(Vector3(29.0, 0.4, -15.0))
	_glow(Vector3(24.5, 0.4, -22.0))
	_glow_box(Vector3(26.0, 0.5, -23.5), C_SAP)                         # "hazine": Kut parçası yeri

	var zone := CameraZone.new()
	zone.name = "CaveZone"
	zone.size = Vector3(5.0, 8.0, 26.0)
	zone.position = Vector3(26.0, 3.0, -11.0)
	zone.transition_duration = 1.0
	add_child(zone)

	# Basamaklar
	_box(Vector3(35.0, 2.25, 0.0), Vector3(3.0, 0.5, 3.0), C_MOSS)
	_box(Vector3(39.0, 4.5, 0.0), Vector3(3.0, 0.5, 3.0), C_MOSS)
	_box(Vector3(35.5, 6.75, 0.0), Vector3(3.0, 0.5, 3.0), C_MOSS)

	# Yukarı sarmaşık zinciri
	_vine(Vector3(40.0, 12.5, 0.0), 3.5)
	_vine(Vector3(45.0, 15.0, 0.0), 3.5)
	_vine(Vector3(50.0, 17.5, 0.0), 3.5)

	# Varış çıkıntısı + gök ışığı
	_box(Vector3(56.0, 15.75, 0.0), Vector3(6.0, 0.5, 3.0), C_MOSS)
	_glow_box(Vector3(57.5, 16.6, 0.0), Color("f4efe3"))


func _box(center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	add_child(body)
	return body


func _vine(anchor_position: Vector3, length: float) -> VineAnchor:
	var vine := VineAnchor.new()
	vine.vine_length = length
	vine.position = anchor_position
	add_child(vine)
	return vine


func _glow(at: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = C_GLOW
	mat.emission_enabled = true
	mat.emission = C_GLOW
	mat.emission_energy_multiplier = 2.5
	var cap := SphereMesh.new()
	cap.radius = 0.4
	cap.height = 0.5
	cap.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cap
	mi.position = at
	add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = C_GLOW
	light.light_energy = 1.5
	light.omni_range = 6.0
	light.position = at + Vector3.UP * 0.6
	add_child(light)


func _glow_box(at: Vector3, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 0.6, 0.6)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.rotation_degrees = Vector3(45.0, 45.0, 0.0)
	add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.position = at
	add_child(light)


# ---------------------------------------------------------------- Oyuncu & kamera

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as Player
	player.position = SPAWN
	add_child(player)


func _build_camera() -> void:
	rig = CameraRig.new()
	rig.name = "CameraRig"
	rig.target = player
	add_child(rig)


# ---------------------------------------------------------------- Debug HUD

var _debug_label: Label


func _build_debug_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_debug_label = Label.new()
	_debug_label.position = Vector2(24.0, 20.0)
	_debug_label.add_theme_font_size_override(&"font_size", 22)
	_debug_label.add_theme_color_override(&"font_color", Color("f4efe3"))
	_debug_label.add_theme_color_override(&"font_outline_color", Color("2b1e3f"))
	_debug_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_debug_label)


func _process(_delta: float) -> void:
	if _debug_label == null or player == null:
		return
	if Input.is_action_just_pressed(&"toggle_debug"):
		_debug_label.visible = not _debug_label.visible
	var mode_name := "SIDE" if CameraDirector.is_side_mode() else "DEPTH"
	_debug_label.text = "BAYTEREK — M0 greybox\n" \
		+ "Durum: %s   Kamera: %s   Hız: %.1f m/s\n" % [
			Player.State.keys()[player.state], mode_name, player.velocity.length()] \
		+ "A/D hareket · Space zıpla/bırak · W/S ip kısalt-uzat (mağarada ileri-geri) · F1 gizle"
