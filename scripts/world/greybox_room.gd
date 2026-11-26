class_name GreyboxRoom
extends Room
## Kodla kurulan greybox oda. Oda sahnesinin (.tscn) kök script'i bundan türer ve `_build()` içinde
## yardımcılarla (box/vine/climb/rotten/glow/goal/cave_zone…) geometriyi kurar. Kimlik, harita
## hücresi ve kapılar .tscn'dedir (Room). M7'de sanat gelince aynı .tscn'e modeller eklenir.

signal goal_reached

const C_BARK := Color("6b4a2f")
const C_ROOT := Color("4a3550")
const C_MOSS := Color("5e8c4a")
const C_CAVE := Color("2b1e3f")
const C_GLOW := Color("4fb3a9")
const C_SAP := Color("e8a33d")
const C_SKY := Color("f4efe3")
## Çevre seti modelleri (Tripo; ölçek import'ta).
const E_ARCH := "res://assets/models/environment/env_root_arch_4m_a.glb"
const E_ROCK := "res://assets/models/environment/env_rock_2m_a.glb"
const E_PLATFORM := "res://assets/models/environment/env_root_platform_4m_a.glb"
const E_CAVE_MOUTH := "res://assets/models/environment/env_cave_mouth_6m_a.glb"
const E_BRIDGE := "res://assets/models/environment/env_root_bridge_6m_a.glb"
const E_LEDGE := "res://assets/models/environment/env_root_ledge_1m_a.glb"
## Süs propları (docs/11 §3).
const P_TOTEM := "res://assets/models/props/prop_totem_stone.glb"
const P_LANTERN := "res://assets/models/props/prop_spirit_lantern.glb"
## Arka duvar kutularının grubu (ParallaxBackdrop görüntülerini gizler).
const BACKDROP_GROUP: StringName = &"backdrop_wall"

var goal: RoomGoal = null
## Otomatik sınırlara eklenen pay (m).
var bounds_margin: float = 1.0
## Otomatik giydirme (ot, eğrelti, sarkan kök, spor; RoomDressing). Alt sınıf _build içinde kapatabilir.
var dressing_enabled: bool = true
var dressing: RoomDressing
## Parallax arka plan ön ayarı (ParallaxBackdrop.PRESETS; boş = kapalı). Alt sınıf _build içinde değiştirir.
var parallax_preset: StringName = &"kokdibi"
var parallax: ParallaxBackdrop
## Parallax kurulunca arka duvar kutularının görüntüsü gizlensin mi. Arkasında sır saklayan
## (illusion_box ile örtülen) odalar false yapar: duvar kalır, parallax yalnız üstünde görünür.
var parallax_hides_backdrops: bool = true
## Kutular dokulu mu (false = düz renk greybox). Doku tekrarı: 1/m.
var skin_boxes: bool = true
var skin_scale: float = 0.14
## Doku gri tonunun kutu rengine etkisi (0 = düz renk, 1 = tam).
var skin_contrast: float = 1.1

## Kutu yüzü dokusu: kodla üretilen dikişsiz, boyalı görünümlü kök/kaya gürültüsü (gri; rengi kutu verir).
## Bütün odalar paylaşır. Gerçek dikişsiz doku gelirse burası `load(...)` olur (docs/07 §6.1).
static var _skin_texture: Texture2D = null


func _ready() -> void:
	_build()
	if bounds.size == Vector3.ZERO:
		bounds = compute_bounds()
	if dressing_enabled:
		dressing = RoomDressing.dress(self)
	if parallax_preset != &"" and ParallaxBackdrop.has_textures(parallax_preset):
		parallax = ParallaxBackdrop.build(self, parallax_preset)


## Odadaki tüm statik kutuların birleşik AABB'si (+ pay).
func compute_bounds() -> AABB:
	var result := AABB()
	var first := true
	for child: Node in get_children():
		var body := child as StaticBody3D
		if body == null:
			continue
		for c: Node in body.get_children():
			var col := c as CollisionShape3D
			if col == null or not col.shape is BoxShape3D:
				continue
			var size := (col.shape as BoxShape3D).size
			var box := AABB(body.position - size * 0.5, size)
			result = box if first else result.merge(box)
			first = false
	return result.grow(bounds_margin)


func side_rail(z: float, x_min: float, x_max: float) -> SideRail:
	var rail := SideRail.new()
	rail.position = Vector3((x_min + x_max) * 0.5, 0.0, z)
	rail.x_min = x_min
	rail.x_max = x_max
	add_child(rail)
	return rail


## Alt sınıflar geometriyi burada kurar.
func _build() -> void:
	pass


# ---------------------------------------------------------------- Yardımcılar

func box(center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = box_material(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	add_child(body)
	return body


## Kutu materyali: düz renk + (skin_boxes açıksa) dünya uzayında üç düzlemli kök dokusu.
## Stylizer bunu stilize shader'ın use_triplanar yoluna çevirir.
func box_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	if skin_boxes:
		mat.albedo_texture = skin_texture()
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * skin_scale
		mat.set_meta(Stylizer.META_TRIPLANAR_MIX, 0.0)
		mat.set_meta(Stylizer.META_TRIPLANAR_CONTRAST, skin_contrast)
	return mat


static func skin_texture() -> Texture2D:
	if _skin_texture != null:
		return _skin_texture
	# Dikişsiz Voronoi (halka ızgara): yuvarlak taş/kök plakaları. Her plaka kendi tonunda, kenarlarda
	# pah + koyu oluk; içinde hafif boya lekesi. Gri üretilir, rengi kutu verir.
	const SIZE := 256
	const GRID := 7
	var rng := RandomNumberGenerator.new()
	rng.seed = 1907
	var pts: Array[Vector2] = []
	var tones: PackedFloat32Array = []
	for gy in GRID:
		for gx in GRID:
			pts.append(Vector2(gx + rng.randf_range(0.15, 0.85), gy + rng.randf_range(0.15, 0.85)))
			tones.append(rng.randf())
	var grain := FastNoiseLite.new()
	grain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	grain.seed = 3
	grain.frequency = 0.05
	var g_img := grain.get_seamless_image(SIZE, SIZE, false, false, 0.1, true)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	var cell := float(SIZE) / GRID
	for y in SIZE:
		for x in SIZE:
			var g := g_img.get_pixel(x, y).r
			# Hafif bükme: düz çizgili hücre kenarları organikleşir
			var pp := Vector2(x, y) / cell + Vector2(g - 0.5, 0.5 - g) * 0.35
			var cx := int(floor(pp.x))
			var cy := int(floor(pp.y))
			var f1 := 99.0
			var f2 := 99.0
			var tone := 0.0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var nx := cx + ox
					var ny := cy + oy
					var idx := posmod(ny, GRID) * GRID + posmod(nx, GRID)
					var pt := pts[idx] + Vector2(nx - posmod(nx, GRID), ny - posmod(ny, GRID))
					var d := pp.distance_to(pt)
					if d < f1:
						f2 = f1
						f1 = d
						tone = tones[idx]
					elif d < f2:
						f2 = d
			var edge := f2 - f1
			var v := lerpf(0.5, 0.78, tone) + (g - 0.5) * 0.14
			v *= lerpf(0.55, 1.0, smoothstep(0.04, 0.22, edge))   # pah
			v *= lerpf(0.35, 1.0, smoothstep(0.0, 0.05, edge))    # oluk
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	_skin_texture = ImageTexture.create_from_image(img)
	return _skin_texture


## Üst yüzeyi `top_y` olan, x1→x2 arası platform (derinlik `depth`).
func platform(x1: float, x2: float, top_y: float, thickness: float = 0.5,
		color: Color = C_MOSS, depth: float = 3.0) -> StaticBody3D:
	return box(Vector3((x1 + x2) * 0.5, top_y - thickness * 0.5, 0.0),
			Vector3(x2 - x1, thickness, depth), color)


## Arka plan duvarı (oyuncunun arkasında, -Z'de): ölçek ve yön hissi için.
## Parallax kurulan odalarda görüntüsü gizlenir (çarpışma ve oda sınırı kalır).
func backdrop(x1: float, x2: float, y1: float, y2: float, color: Color = C_ROOT) -> void:
	var b := box(Vector3((x1 + x2) * 0.5, (y1 + y2) * 0.5, -3.5), Vector3(x2 - x1, y2 - y1, 1.0), color)
	b.add_to_group(BACKDROP_GROUP)


## Görsel ama çarpışmasız kutu: yandan bakınca duvar gibi görünür, derinlikte içinden geçilir
## (derinlik sırrı, Sütun 4). Hafif farklı ton = dikkatli göze ipucu.
func illusion_box(center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = box_material(color.lightened(0.04))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = center
	mi.add_to_group(&"illusion_wall")
	add_child(mi)
	return mi


func grapple_flower(at: Vector3) -> GrappleFlower:
	var f := GrappleFlower.new()
	f.position = at
	add_child(f)
	return f


func vine(anchor_position: Vector3, length: float) -> VineAnchor:
	var v := VineAnchor.new()
	v.vine_length = length
	v.position = anchor_position
	add_child(v)
	return v


func rotten_vine(anchor_position: Vector3, length: float) -> RottenVine:
	var v := RottenVine.new()
	v.vine_length = length
	v.position = anchor_position
	add_child(v)
	return v


func climb_vine(top_position: Vector3, length: float) -> ClimbVine:
	var v := ClimbVine.new()
	v.vine_length = length
	v.position = top_position
	add_child(v)
	return v


func crawler(at: Vector3, direction: float = 1.0) -> RotCrawler:
	var e := RotCrawler.new()
	e.start_direction = direction
	e.position = at
	add_child(e)
	return e


func bloater(at: Vector3, respawn_seconds: float = -1.0) -> SporeBloater:
	var e := SporeBloater.new()
	e.respawn_time = respawn_seconds
	e.position = at
	add_child(e)
	return e


## Tavandan sarkan Kapan Çiçek; `ceiling_at` = tutturma noktası (tavanın alt yüzü).
func trap_flower(ceiling_at: Vector3) -> TrapFlower:
	var e := TrapFlower.new()
	e.position = ceiling_at
	add_child(e)
	return e


## Duvar deliğinden fırlayan Kök Yılanı. `hole_at` = delik ağzı, `out_dir` = fırlama yönü.
## Delik bir kök kütlesinin ön yüzünde durur (gövdenin geri kalanını kütle örter).
func root_snake(hole_at: Vector3, out_dir: Vector3 = Vector3.BACK, delay: float = 0.0) -> RootSnake:
	var depth := 3.2
	var mass := box(hole_at - out_dir.normalized() * depth * 0.5,
			Vector3(2.2, 2.4, depth) if absf(out_dir.z) > 0.5 else Vector3(depth, 2.4, 2.2), Color("3a2838"))
	mass.collision_layer = 0   # süs kütlesi: arka duvarın önünde, oyuncu koridorunda değil
	var e := RootSnake.new()
	e.out_dir = out_dir
	e.start_delay = delay
	e.position = hole_at
	add_child(e)
	return e


## Yerel sis öbeği: `floor_center` = öbeğin taban ortası (zemin üstü), `size` = genişlik/yükseklik/derinlik.
func fog(floor_center: Vector3, size: Vector3 = Vector3(8.0, 2.0, 3.0)) -> FogPatch:
	var f := FogPatch.new()
	f.size = size
	f.position = floor_center + Vector3.UP * size.y * 0.5
	add_child(f)
	return f


## Çarpışmasız süs modeli (çevre seti). `yaw_deg` Y dönüşü, `scale_mul` ek ölçek.
func decor(path: String, at: Vector3, yaw_deg: float = 0.0, scale_mul: float = 1.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	inst.position = at
	inst.rotation_degrees.y = yaw_deg
	inst.scale = Vector3.ONE * scale_mul
	add_child(inst)
	Stylizer.apply(inst)
	return inst


## Taş mangal (ateşli süs). `at` = ayak tabanı.
func brazier(at: Vector3) -> FireProp:
	var f := FireProp.new()
	f.kind = &"brazier"
	f.position = at
	add_child(f)
	return f


## Duvar meşalesi. `at` = duvar yüzündeki tutturma noktasının altı; `yaw_deg` odaya bakış (0 = +Z).
func torch(at: Vector3, yaw_deg: float = 0.0) -> FireProp:
	var f := FireProp.new()
	f.kind = &"torch"
	f.position = at
	f.rotation_degrees.y = yaw_deg
	add_child(f)
	return f


## Göktürk işaretli dikili taş (balbal), süs.
func totem(at: Vector3, yaw_deg: float = 0.0, scale_mul: float = 1.0) -> Node3D:
	return decor(P_TOTEM, at, yaw_deg, scale_mul)


## Tavandan asılı ruh kandili: `ceiling_at` = asıldığı nokta; hafifçe salınır, turkuaz ışık verir.
func spirit_lantern(ceiling_at: Vector3, drop: float = 0.8) -> SpiritLantern:
	var l := SpiritLantern.new()
	l.drop = drop
	l.position = ceiling_at
	add_child(l)
	return l


func glow(at: Vector3, color: Color = C_GLOW) -> void:
	# Zemindeki mantar ışıkları: mantar kümesi modeli varsa küre yerine o (ışık aynı kalır).
	# Odalar zemin ışığını "zemin + 0.4" yüksekliğine koyar (y'nin ondalığı .4); duvar/hava ışıkları küre kalır.
	var on_floor := absf(fposmod(at.y, 1.0) - 0.4) < 0.01
	if color == C_GLOW and on_floor and ResourceLoader.exists(RoomDressing.M_SHROOM):
		var shroom := decor(RoomDressing.M_SHROOM, at - Vector3.UP * 0.4, fposmod(at.x * 37.0 + at.z * 11.0, 360.0), 0.8)
		if shroom != null:
			shroom.add_to_group(&"glow_shroom")
		var l := OmniLight3D.new()
		l.light_color = color
		l.light_energy = 1.5
		l.omni_range = 6.0
		l.position = at + Vector3.UP * 0.6
		add_child(l)
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
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
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 6.0
	light.position = at + Vector3.UP * 0.6
	add_child(light)


## Odanın hedefi: ayak tabanı konumu `at`.
func place_goal(at: Vector3, color: Color = C_SKY) -> RoomGoal:
	goal = RoomGoal.new()
	goal.color = color
	goal.position = at
	add_child(goal)
	goal.reached.connect(func() -> void: goal_reached.emit())
	return goal


func camera_zone(center: Vector3, size: Vector3, mode: CameraRig.Mode = CameraRig.Mode.DEPTH,
		duration: float = 1.0) -> CameraZone:
	var zone := CameraZone.new()
	zone.size = size
	zone.position = center
	zone.mode = mode
	zone.transition_duration = duration
	add_child(zone)
	return zone
