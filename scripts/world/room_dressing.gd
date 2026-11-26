class_name RoomDressing
extends Node3D
## Oda giydirme (docs/08 "Ortam canlılığı"): greybox odanın kutularını okuyup otomatik süsler.
##  - Yürünebilir yüzeylere ot öbeği, eğrelti ve küçük parlayan mantar (koridorun arkasında yoğun,
##    önünde seyrek). Rüzgârda sallanır, oyuncu yanından geçince yana eğilir (stilize shader rüzgârı).
##  - Tavan ve sarkıntıların altına sarkan kök saçakları (uçları rüzgârda salınır) + arada düşen yaprak.
##  - Oda boyunca süzülen sporlar / ateşböcekleri; mantar ışıkları yavaşça nefes alır.
## Hepsi çarpışmasız ve oynanış koridorunu kapatmaz. Oda kimliğinden tohumlu → her açılışta aynı düzen.
## GreyboxRoom._ready sonunda kurulur; `enabled = false` olan odalar (ör. boss kuyusu) atlanabilir.

const FOLIAGE_GROUP: StringName = &"foliage"
const C_GRASS := Color("5e8c4a")
const C_GRASS_DARK := Color("3f6a3a")
const C_FERN := Color("4f8a5a")
const C_ROOT_STRAND := Color("4a3428")
const C_SHROOM := Color("4fb3a9")

## Kullanıcının ürettiği çevre seti (docs/11). Dosya yoksa ilgili adım atlanır (prosedürel yedek kalır).
const ENV := "res://assets/models/environment/"
const M_FLOOR := ENV + "env_root_floor_4m_a.glb"
const M_GRASS := ENV + "env_grass_tuft_05m_a.glb"
const M_FERN := ENV + "env_fern_1m_a.glb"
const M_SHROOM := ENV + "env_mushroom_cluster_1m_a.glb"
const M_CEILING := ENV + "env_ceiling_roots_4m_a.glb"
const M_CURTAIN := ENV + "env_vine_curtain_4m_a.glb"
const M_BRANCH := ENV + "env_branch_3m_a.glb"
const M_PILLAR := ENV + "env_root_pillar_6m_a.glb"
const M_ROCK_S := ENV + "env_rock_1m_b.glb"
const M_PLATFORM_S := ENV + "env_root_platform_2m_a.glb"
const M_WALL := ENV + "env_root_wall_4m_a.glb"

@export var grass_spacing: float = 0.85
@export var max_tufts: int = 140
@export var max_strands: int = 40
@export var mote_color: Color = Color("7fe0d2")
## Model yerleşim sınırları (web bütçesi: eğrelti 19k, perde 15k üçgen → az sayıda).
@export var skin_floors: bool = true
@export var max_floor_tiles: int = 18
@export var max_grass_models: int = 8
@export var max_ferns: int = 3
@export var max_shroom_models: int = 3
@export var max_ceiling_models: int = 4
@export var max_curtains: int = 1
@export var max_branches: int = 3
@export var max_pillars: int = 3
@export var max_wall_pieces: int = 3
## Zemin karosunun renk çarpanı (Tripo yosunu bölge paletinde fazla açık kalıyor).
@export var floor_tint: Color = Color(0.62, 0.68, 0.64)

var room: GreyboxRoom
var tuft_count: int = 0
var strand_count: int = 0
## Yerleştirilen model sayıları (testler ve bütçe için): {"floor": n, "grass": n, ...}
var model_counts: Dictionary = {}
var motes: CPUParticles3D
var _wind_mats: Array[ShaderMaterial] = []
var _glow_lights: Array[OmniLight3D] = []
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0
var _player: Node3D

static var _mesh_cache: Dictionary = {}
## Model yolu + rüzgâr modu → bu odanın rüzgârlı materyali (oda başına; itiş noktası odaya özel)
var _model_wind_mats: Dictionary = {}
var _boxes: Array[AABB] = []
var _backdrops: Array[AABB] = []


static func dress(target: GreyboxRoom) -> RoomDressing:
	var d := RoomDressing.new()
	d.name = "Dressing"
	d.room = target
	target.add_child(d)
	d._build()
	return d


func _build() -> void:
	_rng.seed = hash(String(room.room_id))
	var grass := _wind_material(C_GRASS, 0.07, 0.5, 1.8)
	var grass_dark := _wind_material(C_GRASS_DARK, 0.06, 0.5, 1.5)
	var fern := _wind_material(C_FERN, 0.09, 0.9, 1.2)
	var strand := _wind_material(C_ROOT_STRAND, 0.12, -2.0, 1.0, 0.7)
	var shroom := StandardMaterial3D.new()
	shroom.albedo_color = C_SHROOM.darkened(0.3)
	shroom.emission_enabled = true
	shroom.emission = C_SHROOM
	shroom.emission_energy_multiplier = 1.6
	var shroom_mat := Stylizer.stylize_material(shroom)
	var ceilings: Array[AABB] = []
	_boxes.clear()
	_backdrops.clear()
	for child: Node in room.get_children():
		var body := child as StaticBody3D
		if body == null or body.collision_layer == 0:
			continue
		for c: Node in body.get_children():
			var col := c as CollisionShape3D
			if col == null or not col.shape is BoxShape3D:
				continue
			var size := (col.shape as BoxShape3D).size
			var box := AABB(body.position - size * 0.5, size)
			if box.position.z + box.size.z < -2.6:
				_backdrops.append(box)
				continue    # arka plan duvarı
			_boxes.append(box)
			_scatter_top(box, grass, grass_dark, fern, shroom_mat)
			if box.size.x >= 2.0 and box.position.y > 2.5:
				ceilings.append(box)
	for box: AABB in ceilings:
		_hang_strands(box, strand)
	_place_models()
	_add_motes()
	for n: Node in room.get_children():
		if n is OmniLight3D:
			_glow_lights.append(n as OmniLight3D)
			n.set_meta(&"base_energy", (n as OmniLight3D).light_energy)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	var push := _player.global_position if _player != null else Vector3(0, -1000, 0)
	for m: ShaderMaterial in _wind_mats:
		m.set_shader_parameter(&"push_origin", push)
	for i in _glow_lights.size():
		var l := _glow_lights[i]
		if is_instance_valid(l):
			var base: float = l.get_meta(&"base_energy", 1.5)
			l.light_energy = base * (1.0 + 0.12 * sin(_time * 1.3 + i * 1.7) + 0.05 * sin(_time * 3.1 + i))


# ---------------------------------------------------------------- Yerleştirme

func _scatter_top(box: AABB, grass: Material, grass_dark: Material, fern: Material, shroom: Material) -> void:
	var top := box.position.y + box.size.y
	var z_back := box.position.z + 0.35
	var z_front := box.position.z + box.size.z - 0.35
	var deep := box.size.z > 6.0     # mağara / arena zemini: tüm yüzeye serpiştir
	var x := box.position.x + _rng.randf_range(0.2, grass_spacing)
	while x < box.position.x + box.size.x - 0.2 and tuft_count < max_tufts:
		var rows: Array[float] = []
		if deep:
			# Mağara / arena: derinlik kamerası zeminin üstünden bakar → orta alan boş kalır,
			# bitkiler yalnız kenarlara (yan duvar dipleri) ve arka kenara serpiştirilir.
			var near_x_edge := x - box.position.x < 1.3 or box.position.x + box.size.x - x < 1.3
			for k in int(box.size.z / 2.5):
				var z := _rng.randf_range(z_back, z_front)
				if near_x_edge or z < z_back + 1.2:
					rows.append(z)
		else:
			rows.append(_rng.randf_range(z_back, minf(z_back + 0.9, -0.7)))      # arka sıra (yoğun)
			if _rng.randf() < 0.22:
				rows.append(_rng.randf_range(maxf(z_front - 0.5, 0.9), z_front))  # ön sıra (seyrek)
		for z: float in rows:
			if z > z_front or z < z_back:
				continue
			var roll := _rng.randf()
			var at := Vector3(x + _rng.randf_range(-0.2, 0.2), top, z)
			if roll < 0.62:
				_place(_grass_mesh(), grass if _rng.randf() < 0.6 else grass_dark, at, _rng.randf_range(0.7, 1.3))
			elif roll < 0.9:
				_place(_fern_mesh(), fern, at, _rng.randf_range(0.7, 1.2))
			else:
				_place(_shroom_mesh(), shroom, at, _rng.randf_range(0.6, 1.1))
			tuft_count += 1
		x += grass_spacing * _rng.randf_range(0.7, 1.4)


func _hang_strands(box: AABB, mat: Material) -> void:
	var bottom := box.position.y
	var x := box.position.x + _rng.randf_range(0.3, 1.2)
	var z := clampf(box.position.z + 0.3, -1.6, 1.0)
	var any := false
	while x < box.position.x + box.size.x - 0.3 and strand_count < max_strands:
		var len := _rng.randf_range(0.8, 2.4)
		_place(_strand_mesh(), mat, Vector3(x, bottom, z + _rng.randf_range(0.0, 0.3)), 1.0,
				Vector3(1.0, len / 2.0, 1.0))
		strand_count += 1
		any = true
		x += _rng.randf_range(0.9, 2.2)
	if any:
		var leaves := FxLibrary.falling_leaves(Vector3(box.size.x, 0.5, 1.0), Color("6a9a50"),
				clampi(int(box.size.x / 3.0), 2, 8))
		leaves.position = Vector3(box.get_center().x, bottom - 0.3, z)
		leaves.emitting = true
		add_child(leaves)


func _add_motes() -> void:
	var b := room.bounds if room.bounds.size != Vector3.ZERO else room.compute_bounds()
	var vol := Vector3(b.size.x, minf(b.size.y, 14.0), minf(b.size.z, 6.0))
	var amount := clampi(int(vol.x * vol.y * 0.08), 12, 60)
	motes = FxLibrary.motes(vol, mote_color, amount)
	motes.position = Vector3(b.get_center().x, b.position.y + vol.y * 0.5, clampf(b.get_center().z, -1.5, 0.5))
	motes.emitting = true
	add_child(motes)
	var gold := FxLibrary.motes(vol, Color("e8c36d"), maxi(4, amount / 6), 0.09)
	gold.position = motes.position
	gold.emitting = true
	add_child(gold)


func _place(mesh: Mesh, mat: Material, at: Vector3, s: float, stretch: Vector3 = Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	mi.rotation.y = _rng.randf() * TAU
	mi.scale = stretch * s
	mi.add_to_group(FOLIAGE_GROUP)
	add_child(mi)


func _wind_material(color: Color, strength: float, height: float, speed: float, push: float = 0.5) -> ShaderMaterial:
	var std := StandardMaterial3D.new()
	std.albedo_color = color
	std.set_meta(Stylizer.META_WIND, {"strength": strength, "height": height, "speed": speed, "push": push})
	var sm := Stylizer.stylize_material(std) as ShaderMaterial
	_wind_mats.append(sm)
	return sm


# ---------------------------------------------------------------- Çevre seti modelleri

## Kutuları sınıflandırır ve modelleri yerleştirir:
##  zemin kaplaması (yürünen yüzey, tavan değil) · ot/eğrelti/mantar modelleri (rüzgârlı) ·
##  tavan kök kütleleri + sarmaşık perdesi (sarkık rüzgâr) · duvar dalları · arka plan sütunları/kayalar.
func _place_models() -> void:
	var b := room.bounds if room.bounds.size != Vector3.ZERO else room.compute_bounds()
	var room_top := b.end.y
	var floors: Array[AABB] = []
	var ceils: Array[AABB] = []
	var walls: Array[AABB] = []
	for box: AABB in _boxes:
		var is_ceiling := box.size.x >= 2.0 and box.size.y <= 2.5 and box.end.y >= room_top - 2.5 and box.position.y > 2.5
		if is_ceiling:
			ceils.append(box)
		elif box.size.x >= 2.0 and box.size.z <= 6.0 and box.size.z >= 2.0:
			floors.append(box)
		elif box.size.x <= 2.0 and box.size.y >= 6.0:
			walls.append(box)
	if skin_floors:
		for box: AABB in floors:
			_skin_floor(box)
	# yürünen yüzeylere kahraman bitkiler (arka sıra, koridoru kapatmaz)
	var spots: Array[Vector3] = []
	for box: AABB in floors:
		var x := box.position.x + 1.0
		while x < box.end.x - 1.0:
			spots.append(Vector3(x + _rng.randf_range(-0.6, 0.6), box.end.y, clampf(box.position.z + 0.45, -1.7, -0.9)))
			x += _rng.randf_range(2.5, 4.5)
	_shuffle(spots)
	var i := 0
	for n in max_grass_models:
		if i >= spots.size():
			break
		_model(M_GRASS, &"grass", spots[i], _rng.randf() * TAU, _rng.randf_range(0.8, 1.3), &"up", 0.08)
		i += 1
	for n in max_ferns:
		if i >= spots.size():
			break
		_model(M_FERN, &"fern", spots[i], _rng.randf() * TAU, _rng.randf_range(0.9, 1.3), &"up", 0.1)
		i += 1
	for n in max_shroom_models:
		if i >= spots.size():
			break
		var m := _model(M_SHROOM, &"shroom", spots[i], _rng.randf() * TAU, _rng.randf_range(0.6, 1.0), &"up", 0.02)
		if m != null:
			var l := OmniLight3D.new()
			l.light_color = C_SHROOM
			l.light_energy = 0.9
			l.omni_range = 3.0
			l.position = Vector3.UP * 0.6
			m.add_child(l)
			_glow_lights.append(l)
			l.set_meta(&"base_energy", l.light_energy)
		i += 1
	# tavanlar: kök kütlesi (alt yüze asılı) + bir sarmaşık perdesi
	var c_spots: Array[Vector3] = []
	for box: AABB in ceils:
		var x := box.position.x + 2.0
		while x < box.end.x - 1.5:
			c_spots.append(Vector3(x, box.position.y, clampf(box.position.z + 0.6, -1.8, -1.0)))
			x += _rng.randf_range(5.0, 9.0)
	_shuffle(c_spots)
	var ci := 0
	for n in max_ceiling_models:
		if ci >= c_spots.size():
			break
		_hang_model(M_CEILING, &"ceiling", c_spots[ci], _rng.randf_range(0.6, 0.9))
		ci += 1
	for n in max_curtains:
		if ci >= c_spots.size():
			break
		_hang_model(M_CURTAIN, &"curtain", c_spots[ci] + Vector3(0.0, 0.0, -0.3), _rng.randf_range(0.8, 1.0))
		ci += 1
	# duvar dalları: duvarın odaya bakan yüzünden dışarı (arka planda)
	var w_spots: Array = []
	for box: AABB in walls:
		var inward := 1.0 if box.get_center().x < b.get_center().x else -1.0
		var face_x := box.end.x if inward > 0.0 else box.position.x
		var y := box.position.y + 2.5
		while y < box.end.y - 1.0:
			w_spots.append([Vector3(face_x, y, -1.4), inward])
			y += _rng.randf_range(4.0, 7.0)
	_shuffle(w_spots)
	for n in mini(max_branches, w_spots.size()):
		var at: Vector3 = w_spots[n][0]
		var inward: float = w_spots[n][1]
		# Dal modeli +X boyunca uzanıyor, tabanı -X ucunda → odaya doğru dönsün
		var m := _model(M_BRANCH, &"branch", at + Vector3(inward * 1.4, -0.3, 0.0), 0.0 if inward > 0.0 else PI, 1.0, &"up", 0.04)
		if m != null:
			m.rotation.z = inward * 0.15
	# arka plan: kök sütunları + küçük kayalar (oyuncu koridorunun arkasında)
	var bx := b.position.x + _rng.randf_range(2.0, 6.0)
	var pillars := 0
	var floor_y := _floor_height_at(b)
	while bx < b.end.x - 2.0 and pillars < max_pillars:
		if _model(M_PILLAR, &"pillar", Vector3(bx, floor_y, -2.75), _rng.randf() * TAU, 1.0, &"none") != null:
			pillars += 1
		bx += _rng.randf_range(10.0, 18.0)
	# arka duvarın dibinde kök duvarı kümeleri (derinlik + doku)
	var wall_spots: Array[Vector3] = []
	for bd: AABB in _backdrops:
		if bd.size.x < 4.0:
			continue
		var x := bd.position.x + 3.0
		while x < bd.end.x - 3.0:
			wall_spots.append(Vector3(x, maxf(bd.position.y, floor_y - 0.5), bd.end.z + 0.15))
			x += _rng.randf_range(6.0, 11.0)
	_shuffle(wall_spots)
	for n in mini(max_wall_pieces, wall_spots.size()):
		_model(M_WALL, &"wall", wall_spots[n], _rng.randf_range(-0.15, 0.15), _rng.randf_range(0.7, 1.0), &"none")
	for box: AABB in floors.slice(0, 2):
		_model(M_ROCK_S, &"rock", Vector3(_rng.randf_range(box.position.x + 1.0, box.end.x - 1.0), box.end.y,
				clampf(box.position.z + 0.5, -1.8, -1.0)), _rng.randf() * TAU, _rng.randf_range(0.6, 1.0), &"none")


## Zemin kutusunun üstünü kök/yosun karolarıyla kaplar (x boyunca ölçeklenen 4 m karolar).
## Küçük süzülen platformlar (≤ 3.2 m) ise altından kök sarkan 2 m platform modeliyle giydirilir.
func _skin_floor(box: AABB) -> void:
	if box.size.x <= 3.2 and box.size.y <= 1.2 and ResourceLoader.exists(M_PLATFORM_S):
		var pm := _model(M_PLATFORM_S, &"platform", Vector3(box.get_center().x, 0.0, box.get_center().z), 0.0, 1.0, &"none")
		if pm != null:
			var h := _model_height(M_PLATFORM_S)
			pm.scale = Vector3(box.size.x / 2.0, 1.0, box.size.z / 1.55)
			pm.position.y = box.end.y + 0.03 - h
		return
	if not ResourceLoader.exists(M_FLOOR):
		return
	var n := maxi(1, int(round(box.size.x / 4.0)))
	var sx := box.size.x / (n * 4.0)
	var sz := box.size.z / 4.0
	var sy := minf(box.size.y, 1.05) / 1.05
	for k in n:
		if int(model_counts.get(&"floor", 0)) >= max_floor_tiles:
			return
		var at := Vector3(box.position.x + (k + 0.5) * 4.0 * sx, box.end.y - 1.05 * sy + 0.03, box.get_center().z)
		# Karolar %12 üst üste biner (dikiş çizgisi kalmaz), her biri rastgele 0/180° çevrilir (tekrar kırılır)
		var m := _model(M_FLOOR, &"floor", at, PI if _rng.randf() < 0.5 else 0.0, 1.0, &"tint", 0.0, floor_tint)
		if m != null:
			m.scale = Vector3(sx * 1.12, sy * _rng.randf_range(0.97, 1.03), sz)


func _floor_height_at(b: AABB) -> float:
	var best := b.position.y
	for box: AABB in _boxes:
		if box.size.x >= 4.0 and box.end.y <= b.position.y + 3.0:
			best = maxf(best, box.end.y)
	return best


func _hang_model(path: String, kind: StringName, ceiling_point: Vector3, s: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var h := _model_height(path) * s
	return _model(path, kind, ceiling_point + Vector3.DOWN * h, _rng.randf_range(-0.3, 0.3), s, &"hang", 0.06)


## Model örneği + (isteğe bağlı) rüzgârlı materyal. mode: &"up" dikilen, &"hang" sarkan, &"none" katı.
func _model(path: String, kind: StringName, at: Vector3, yaw: float, s: float, mode: StringName, strength: float = 0.06,
		tint: Color = Color.WHITE) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	inst.position = at
	inst.rotation.y = yaw
	inst.scale = Vector3.ONE * s
	add_child(inst)
	for n: Node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if mode != &"none" else mi.cast_shadow
		if mode == &"none":
			continue
		mi.material_override = _model_wind_material(path, mode, mi, strength, tint)
		if mode != &"tint":
			mi.add_to_group(FOLIAGE_GROUP)
	Stylizer.apply(inst)
	model_counts[kind] = int(model_counts.get(kind, 0)) + 1
	return inst


## mode &"tint": rüzgârsız, yalnız renk çarpanlı kopya.
func _model_wind_material(path: String, mode: StringName, mi: MeshInstance3D, strength: float,
		tint: Color = Color.WHITE) -> ShaderMaterial:
	var key := path + String(mode)
	if _model_wind_mats.has(key):
		return _model_wind_mats[key]
	var src := mi.get_active_material(0) as StandardMaterial3D
	var std := (src.duplicate() as StandardMaterial3D) if src != null else StandardMaterial3D.new()
	std.albedo_color = std.albedo_color * tint
	if mode == &"tint":
		var tm := Stylizer.stylize_material(std) as ShaderMaterial
		_model_wind_mats[key] = tm
		return tm
	var a := mi.mesh.get_aabb()
	var w := {"strength": strength, "speed": 1.4, "push": 0.45}
	if mode == &"hang":
		w["base"] = a.end.y
		w["height"] = -a.size.y
	else:
		w["base"] = a.position.y
		w["height"] = a.size.y
	std.set_meta(Stylizer.META_WIND, w)
	var sm := Stylizer.stylize_material(std) as ShaderMaterial
	_wind_mats.append(sm)
	_model_wind_mats[key] = sm
	return sm


static var _height_cache: Dictionary = {}


static func _model_height(path: String) -> float:
	if _height_cache.has(path):
		return _height_cache[path]
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	var h: float = (ModelValidator.measure(inst)["aabb"] as AABB).size.y
	inst.free()
	_height_cache[path] = h
	return h


func _shuffle(arr: Array) -> void:
	for k in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, k)
		var t: Variant = arr[k]
		arr[k] = arr[j]
		arr[j] = t


# ---------------------------------------------------------------- Kodla üretilen örgüler (önbellekli)

## İki yüzlü (shader cull_back) şerit üçgenleri: her üçgen iki yönde eklenir.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.set_normal(-n)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


## Eğri, sivrilen şerit (yaprak/ot): kökten `dir` yönüne `length`, uca doğru daralır ve eğilir.
static func _blade(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, width: float, bend: float, segs: int) -> void:
	var side := dir.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var prev_l := base - side * width * 0.5
	var prev_r := base + side * width * 0.5
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := base + dir * length * t + Vector3.DOWN * bend * t * t
		var w := width * (1.0 - t) * 0.5
		var l := p - side * w
		var r := p + side * w
		_tri(st, prev_l, prev_r, r)
		_tri(st, prev_l, r, l)
		prev_l = l
		prev_r = r


static func _grass_mesh() -> Mesh:
	if _mesh_cache.has("grass"):
		return _mesh_cache["grass"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 9:
		var a := rng.randf() * TAU
		var tilt := rng.randf_range(0.15, 0.45)
		var dir := Vector3(cos(a) * tilt, 1.0, sin(a) * tilt).normalized()
		_blade(st, Vector3(cos(a), 0.0, sin(a)) * 0.08, dir, rng.randf_range(0.3, 0.55), 0.07, 0.06, 3)
	var m := st.commit()
	_mesh_cache["grass"] = m
	return m


static func _fern_mesh() -> Mesh:
	if _mesh_cache.has("fern"):
		return _mesh_cache["fern"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var dir := Vector3(cos(a) * 0.8, 0.75, sin(a) * 0.8).normalized()
		_blade(st, Vector3.ZERO, dir, 0.85, 0.22, 0.35, 5)
	var m := st.commit()
	_mesh_cache["fern"] = m
	return m


static func _shroom_mesh() -> Mesh:
	if _mesh_cache.has("shroom"):
		return _mesh_cache["shroom"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var caps := [[Vector3(0.0, 0.0, 0.0), 0.28, 0.11], [Vector3(0.12, 0.0, 0.06), 0.18, 0.07], [Vector3(-0.1, 0.0, 0.08), 0.14, 0.06]]
	for c: Array in caps:
		var base: Vector3 = c[0]
		var h: float = c[1]
		var r: float = c[2]
		var top := base + Vector3.UP * h
		for k in 6:
			var a0 := TAU * k / 6.0
			var a1 := TAU * (k + 1) / 6.0
			var e0 := top + Vector3(cos(a0), -0.35, sin(a0)) * r
			var e1 := top + Vector3(cos(a1), -0.35, sin(a1)) * r
			_tri(st, top + Vector3.UP * r * 0.45, e1, e0)
			_tri(st, base + Vector3(cos(a0), 0, sin(a0)) * r * 0.2, base + Vector3(cos(a1), 0, sin(a1)) * r * 0.2, top)
	var m := st.commit()
	_mesh_cache["shroom"] = m
	return m


## Sarkan kök saçağı: tepeden (y=0) aşağı 2 m, hafif S kıvrımlı ana iplik + iki ince yan iplik.
static func _strand_mesh() -> Mesh:
	if _mesh_cache.has("strand"):
		return _mesh_cache["strand"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_blade(st, Vector3.ZERO, Vector3.DOWN, 2.0, 0.2, 0.0, 6)
	_blade(st, Vector3(0.03, -0.2, 0.0), Vector3(0.25, -1.0, 0.1).normalized(), 1.2, 0.06, 0.0, 4)
	_blade(st, Vector3(-0.03, -0.4, 0.0), Vector3(-0.2, -1.0, -0.1).normalized(), 0.9, 0.05, 0.0, 3)
	# ikinci yüz (dik açıda) → her açıdan dolgun görünür
	var rot := Basis(Vector3.UP, PI * 0.5)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	_blade(st2, Vector3.ZERO, Vector3.DOWN, 2.0, 0.2, 0.0, 6)
	var m := st.commit()
	var arr := st2.commit().surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i in verts.size():
		verts[i] = rot * verts[i]
		norms[i] = rot * norms[i]
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	var st3 := SurfaceTool.new()
	st3.create_from(m, 0)
	var merged := st3.commit()
	merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mesh_cache["strand"] = merged
	return merged
