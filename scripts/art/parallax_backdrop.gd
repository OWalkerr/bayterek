class_name ParallaxBackdrop
extends Node3D
## Bölge parallax arka planı (docs/11 §0, docs/07 §8): boyalı 2D katmanlar oyun düzleminin arkasında
## farklı derinliklerdeki dev düzlemlere yapıştırılır. Parallax gerçek 3D derinlikten doğar —
## kamera kayınca yakın katman hızlı, uzak katman yavaş akar; ek kaydırma kodu yok.
##  - Katmanlar ışıksız (unshaded) ve sissiz: renk boyamadan gelir, bölge sisi soldurmasın.
##  - Döşenen katmanlar yatayda UV ile tekrar eder; döşenmeyenler aynalı tekrar (dikiş görünmez).
##  - Ön plan (FG) şeritleri oyuncunun önünde (+Z), ekranın üst/alt kenarında kalır: X'te dünyaya
##    sabit (gerçek parallax), Y'de kamerayı izler.
##  - Derinlik (mağara) modunda yakın katmanlar ve FG gizlenir, yalnız uzak katmanlar kalır.
##  - Odanın arka duvar kutularının (GreyboxRoom.backdrop) yalnız görüntüsü gizlenir; çarpışma kalır.
## Kurulum: GreyboxRoom._ready → `ParallaxBackdrop.build(oda, ön_ayar)`. Dosya yoksa katman atlanır.

const GROUP: StringName = &"parallax_backdrop"
const BG := "res://assets/textures/backgrounds/"

enum Kind { TILED, SINGLE, SHAFTS, SKY_HOLE, FG_TOP, FG_BOTTOM }

## Katman tanımları. depth: oyun düzleminin arka sınırından geriye (m; FG için önüne).
## aspect: doku en/boy. add: toplamalı (siyah zeminli ışık katmanları). tint: renk çarpanı (koyu-mor →
## atmosferik uzaklık; oynanış katmanıyla yarışmasın). follow: dikeyde kamerayı izleme oranı
## (1 = ekrana sabit, 0 = dünyaya sabit) — görselin kompozisyonu (alt kenarı ekranın altında) korunur.
## depth_mode: derinlik (mağara) kamerasında da görünsün mü.
const LAYERS: Dictionary = {
	&"l0": {"tex": "bg_kokdibi_l0_far.jpg", "kind": Kind.TILED, "depth": 80.0, "aspect": 2.0,
			"add": false, "tint": Color(0.5, 0.46, 0.6), "follow": 0.9, "depth_mode": true},
	&"sky_hole": {"tex": "bg_kokdibi_sky_hole.png", "kind": Kind.SKY_HOLE, "depth": 60.0, "aspect": 1.0,
			"add": false, "tint": Color(0.85, 0.85, 0.9), "follow": 0.0, "depth_mode": true},
	&"l1": {"tex": "bg_kokdibi_l1_roots.png", "kind": Kind.TILED, "depth": 45.0, "aspect": 2.0,
			"add": false, "tint": Color(0.42, 0.38, 0.52), "follow": 0.8, "depth_mode": true},
	&"arena": {"tex": "bg_kokyiyen_arena.jpg", "kind": Kind.SINGLE, "depth": 35.0, "aspect": 2.0,
			"add": false, "tint": Color(0.55, 0.5, 0.62), "follow": 0.85, "depth_mode": true},
	&"cave_far": {"tex": "bg_kokdibi_cave_far.jpg", "kind": Kind.TILED, "depth": 30.0, "aspect": 2.0,
			"add": false, "tint": Color(0.5, 0.46, 0.6), "follow": 0.8, "depth_mode": true},
	&"l2": {"tex": "bg_kokdibi_l2_mid.png", "kind": Kind.TILED, "depth": 25.0, "aspect": 2.0,
			"add": false, "tint": Color(0.4, 0.36, 0.5), "follow": 0.7, "depth_mode": false},
	&"shafts": {"tex": "bg_kokdibi_lightshafts.jpg", "kind": Kind.SHAFTS, "depth": 15.0, "aspect": 2.0,
			"add": true, "tint": Color(0.35, 0.32, 0.3), "follow": 0.0, "depth_mode": false},
	&"l3": {"tex": "bg_kokdibi_l3_glow.jpg", "kind": Kind.TILED, "depth": 12.0, "aspect": 2.0,
			"add": true, "tint": Color(0.45, 0.45, 0.45), "follow": 0.55, "depth_mode": false},
	&"fg_top": {"tex": "fg_kokdibi_top.png", "kind": Kind.FG_TOP, "depth": -4.0, "aspect": 4.0,
			"add": false, "tint": Color(0.35, 0.3, 0.4), "follow": 1.0, "depth_mode": false},
	&"fg_bottom": {"tex": "fg_kokdibi_bottom.png", "kind": Kind.FG_BOTTOM, "depth": -4.0, "aspect": 4.0,
			"add": false, "tint": Color(0.35, 0.3, 0.4), "follow": 1.0, "depth_mode": false},
}

## Ön ayarlar (oda → katman listesi, uzaktan yakına).
const PRESETS: Dictionary = {
	&"kokdibi": [&"l0", &"l1", &"l2", &"shafts", &"l3", &"fg_top", &"fg_bottom"],
	&"sky": [&"l0", &"sky_hole", &"l1", &"l2", &"shafts", &"l3", &"fg_top", &"fg_bottom"],
	&"cave": [&"cave_far", &"l3", &"fg_bottom"],
	&"arena": [&"l0", &"arena", &"l3"],
}

## Yandan kameranın oyun düzlemine uzaklığı ve dikey FOV'u (CameraRig.side_distance / side_fov ile aynı).
@export var camera_distance: float = 14.0
@export var camera_fov_deg: float = 40.0
## Kapsanacak en geniş ekran oranı (21:9 ≈ 2.4).
@export var max_screen_aspect: float = 2.4
## Düzlemlerin kenarlarına eklenen pay (m).
@export var margin: float = 6.0
## Kapsama düzleminin görünür yüksekliğe göre payı (dikey izleme sırasında kenar görünmesin).
@export var cover_overscan: float = 1.15
## FG şerit yüksekliği (m) ve ekran kenarından taşma payı (oranı).
@export var fg_height: float = 2.2
@export var fg_overhang: float = 0.45
## Işık huzmesi düzlemi boyu (m), aralığı (m) ve nefes alma hızı.
@export var shaft_size: Vector2 = Vector2(26.0, 13.0)
@export var shaft_spacing: float = 34.0
@export var shaft_pulse_speed: float = 0.35
## Gökyüzü deliğinin kenarı (m).
@export var sky_hole_size: float = 34.0

var preset: StringName = &"kokdibi"
var room_bounds: AABB = AABB()
## Katman adı → düzlem(ler) (MeshInstance3D dizisi).
var layers: Dictionary = {}
var hidden_backdrops: int = 0
var _fg: Array[MeshInstance3D] = []
var _followers: Array[MeshInstance3D] = []
var _shaft_mats: Array[StandardMaterial3D] = []
var _time: float = 0.0
var _depth_mode: bool = false

static var _tex_cache: Dictionary = {}


static func build(room: GreyboxRoom, preset_name: StringName) -> ParallaxBackdrop:
	var p := ParallaxBackdrop.new()
	p.name = "Parallax"
	p.preset = preset_name
	room.add_child(p)
	p._build(room)
	return p


## Bu katman listesinde dokusu bulunan en az bir katman var mı (yoksa kurulmaz).
static func has_textures(preset_name: StringName) -> bool:
	for id: StringName in PRESETS.get(preset_name, []):
		if ResourceLoader.exists(BG + String(LAYERS[id]["tex"])):
			return true
	return false


func layer_count() -> int:
	return layers.size()


func _build(room: GreyboxRoom) -> void:
	add_to_group(GROUP)
	room_bounds = room.bounds if room.bounds.size != Vector3.ZERO else room.compute_bounds()
	var back_z := minf(room_bounds.position.z, -4.0)
	for id: StringName in PRESETS.get(preset, []):
		var spec: Dictionary = LAYERS[id]
		var path := BG + String(spec["tex"])
		if not ResourceLoader.exists(path):
			continue
		var depth: float = spec["depth"]
		var z := back_z - depth if depth > 0.0 else -depth
		var planes: Array[MeshInstance3D] = []
		match int(spec["kind"]):
			Kind.TILED, Kind.SINGLE:
				planes.append(_cover_plane(spec, path, z))
			Kind.SHAFTS:
				planes.append_array(_shafts(spec, path, z))
			Kind.SKY_HOLE:
				planes.append(_sky_hole(spec, path, z))
			Kind.FG_TOP, Kind.FG_BOTTOM:
				var fg := _fg_strip(spec, path, z)
				planes.append(fg)
				_fg.append(fg)
		for mi: MeshInstance3D in planes:
			mi.set_meta(&"depth_mode", spec["depth_mode"])
		layers[id] = planes
	if not layers.is_empty() and room.parallax_hides_backdrops:
		_hide_backdrops(room)
	if not EventBus.camera_mode_changed.is_connected(_on_camera_mode_changed):
		EventBus.camera_mode_changed.connect(_on_camera_mode_changed)


func _process(delta: float) -> void:
	_time += delta
	for i in _shaft_mats.size():
		var m := _shaft_mats[i]
		var base: Color = m.get_meta(&"base")
		var k := 0.75 + 0.25 * sin(_time * shaft_pulse_speed * TAU + i * 2.1)
		m.albedo_color = Color(base.r * k, base.g * k, base.b * k, 1.0)
	_follow_layers()
	_follow_fg()


## Uzak katmanlar dikeyde kamerayı kısmen izler: merkez = oda ortası → kamera arası `follow` oranı.
func _follow_layers() -> void:
	if _followers.is_empty() or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cy := room_bounds.get_center().y
	for mi: MeshInstance3D in _followers:
		mi.global_position.y = lerpf(cy, cam.global_position.y, float(mi.get_meta(&"follow")))


## FG şeritlerini ekranın üst/alt kenarına oturtur (Y'de kamerayı izler; X dünyaya sabit).
func _follow_fg() -> void:
	if _fg.is_empty():
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	for mi: MeshInstance3D in _fg:
		var dist := cam.global_position.z - mi.global_position.z
		if dist <= 0.5:
			continue
		var half_h := dist * tan(deg_to_rad(cam.fov) * 0.5)
		var top := bool(mi.get_meta(&"top"))
		var edge := cam.global_position.y + (half_h if top else -half_h)
		var inset := fg_height * (0.5 - fg_overhang)
		mi.global_position.y = edge - inset if top else edge + inset


func _on_camera_mode_changed(mode: int) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	set_depth_mode(mode == CameraRig.Mode.DEPTH)


## Derinlik kamerasında yalnız uzak katmanlar görünür.
func set_depth_mode(on: bool) -> void:
	_depth_mode = on
	for id: StringName in layers:
		for mi: MeshInstance3D in layers[id]:
			mi.visible = (not on) or bool(mi.get_meta(&"depth_mode"))


func is_depth_mode() -> bool:
	return _depth_mode


# ---------------------------------------------------------------- Düzlemler

## Odanın tüm kamera yolculuğunu o derinlikte kaplayan düzlem. Yatayda odayı + ekran yarısını kaplar,
## dikeyde kamerayı `follow` oranında izler (bkz. _follow_layers) → yüksekliği yalnız kalan farkı kapsar.
func _cover_plane(spec: Dictionary, path: String, z: float) -> MeshInstance3D:
	var dist := camera_distance + absf(z)
	var half_h := dist * tan(deg_to_rad(camera_fov_deg) * 0.5)
	var half_w := half_h * max_screen_aspect
	var follow: float = spec["follow"]
	var size := Vector2(room_bounds.size.x + half_w * 2.0 + margin * 2.0,
			half_h * 2.0 * cover_overscan + (1.0 - follow) * room_bounds.size.y)
	var tile_w := size.y * float(spec["aspect"])
	var center := Vector3(room_bounds.get_center().x, room_bounds.get_center().y, z)
	var mat := _material(spec, path)
	mat.uv1_scale = Vector3(size.x / tile_w, 1.0, 1.0)
	# Döşenmeyen (tek parça) görsel: ortası odanın ortasına gelsin
	if int(spec["kind"]) == Kind.SINGLE:
		mat.uv1_offset = Vector3(0.5 - fposmod(mat.uv1_scale.x * 0.5, 1.0), 0.0, 0.0)
	var mi := _plane(size, center, mat)
	if follow > 0.0:
		mi.set_meta(&"follow", follow)
		_followers.append(mi)
	return mi


func _shafts(spec: Dictionary, path: String, z: float) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var count := maxi(1, int(round(room_bounds.size.x / shaft_spacing)))
	var step := room_bounds.size.x / count
	for i in count:
		var mat := _material(spec, path)
		mat.set_meta(&"base", mat.albedo_color)
		_shaft_mats.append(mat)
		var x := room_bounds.position.x + step * (i + 0.5) + fposmod(float(i) * 7.3, 6.0) - 3.0
		var y := room_bounds.end.y - shaft_size.y * 0.5 + 1.0
		out.append(_plane(shaft_size, Vector3(x, y, z), mat))
	return out


func _sky_hole(spec: Dictionary, path: String, z: float) -> MeshInstance3D:
	var mat := _material(spec, path)
	var at := Vector3(room_bounds.get_center().x, room_bounds.end.y + sky_hole_size * 0.15, z)
	return _plane(Vector2(sky_hole_size, sky_hole_size), at, mat)


func _fg_strip(spec: Dictionary, path: String, z: float) -> MeshInstance3D:
	var dist := maxf(camera_distance - z, 1.0)
	var half_w := dist * tan(deg_to_rad(camera_fov_deg) * 0.5) * max_screen_aspect
	var size := Vector2(room_bounds.size.x + half_w * 2.0 + margin * 2.0, fg_height)
	var mat := _material(spec, path)
	mat.uv1_scale = Vector3(size.x / (fg_height * float(spec["aspect"])), 1.0, 1.0)
	var top := int(spec["kind"]) == Kind.FG_TOP
	var y := room_bounds.end.y if top else room_bounds.position.y
	var mi := _plane(size, Vector3(room_bounds.get_center().x, y, z), mat)
	mi.set_meta(&"top", top)
	return mi


func _plane(size: Vector2, at: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.position = at
	add_child(mi)
	return mi


func _material(spec: Dictionary, path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.set_meta(Stylizer.META_SKIP, true)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	m.disable_receive_shadows = true
	m.albedo_texture = _texture(path)
	m.albedo_color = spec["tint"]
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.texture_repeat = true
	if bool(spec["add"]):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	elif path.ends_with(".png"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	# FG her şeyin önünde, uzak katmanlar sırayla arkada çizilsin
	m.render_priority = clampi(int(-float(spec["depth"]) / 10.0), -100, 100)
	return m


static func _texture(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) as Texture2D
	return _tex_cache[path]


## Arka duvar kutularının görüntüsünü gizler (parallax görünsün); çarpışma ve oda sınırı aynı kalır.
func _hide_backdrops(room: GreyboxRoom) -> void:
	for n: Node in room.get_children():
		if not n.is_in_group(GreyboxRoom.BACKDROP_GROUP):
			continue
		for c: Node in n.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).visible = false
				hidden_backdrops += 1
