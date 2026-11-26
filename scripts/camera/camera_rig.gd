class_name CameraRig
extends Node3D
## Kamera "beyni": SIDE (2.5D) ve DEPTH (3. şahıs) modlarının hedef dönüşümlerini hesaplar —
## ölü bölge, bakış yönüne kayma (look-ahead), dikey odak (alt üçte bir / düşerken alt yarı),
## hızlı sallanmada geri çekilme ve oda sınırları (RoomBounds). Ayrıntı: docs/05.
##
## Geçiş (blend) iki arka uçtan biriyle yapılır:
##  - `use_phantom_camera = true`  → PhantomCameraBackend (Phantom Camera eklentisi, öncelik + tween)
##  - `use_phantom_camera = false` → yerleşik blend (bağımlılıksız yedek)
## Oyun kodu kamerayla değil CameraDirector ile konuşur; arka uç değişse de API aynı kalır.

enum Mode { SIDE, DEPTH }

const PHANTOM_BACKEND_PATH: String = "res://scripts/camera/phantom_camera_backend.gd"

@export var target: Node3D
## Phantom Camera arka ucu (karar 2026-11-25: denenir, sorun olursa false → yerleşik blend).
@export var use_phantom_camera: bool = true

@export_group("SIDE")
@export var side_distance: float = 14.0
@export var side_height: float = 3.5
## Karakteri ekranın alt üçte birinde tutmak için bakış noktası karakterin üstünde.
@export var side_look_height: float = 3.0
## Hızlı düşüşte bakış noktası (karakter ekranın alt yarısına kayar, aşağısı görünür).
@export var side_fall_look_height: float = 0.6
@export var fall_speed_threshold: float = 8.0
@export var fall_look_smoothing: float = 3.0
@export var side_fov: float = 40.0
## Ölü bölge (toplam genişlik/yükseklik, m): karakter bu kutu içinde kaldıkça odak kımıldamaz.
@export var dead_zone: Vector2 = Vector2(1.5, 1.0)
@export var side_lookahead: float = 2.5
## Look-ahead hız ölçeği: bu hızda tam kayma (koşu hızı).
@export var lookahead_full_speed: float = 7.0
## Look-ahead yumuşatma zaman sabiti (sn) — docs/05: 0.4 sn.
@export var lookahead_time: float = 0.4
@export var side_fast_pullback: float = 2.0
@export var fast_speed_threshold: float = 9.0
@export var pullback_smoothing: float = 1.5

@export_group("DEPTH")
@export var depth_distance: float = 6.0
@export var depth_height: float = 2.5
@export var depth_look_height: float = 1.4
@export var depth_fov: float = 60.0

@export_group("Takip")
@export var follow_smoothing: float = 6.0

@export_group("Sarsıntı")
## Travma modeli: sarsıntı = travma², travma saniyede `shake_decay` azalır (docs/05 §sarsıntı).
## Kamera dönüşümüne değil Camera3D h/v_offset'ine uygulanır → iki arka uçta da çalışır.
@export var shake_max_offset: float = 0.35
@export var shake_decay: float = 1.8
@export var shake_frequency: float = 22.0

var mode: Mode = Mode.SIDE
var depth_yaw: float = 0.0
var camera: Camera3D
## Oda sınırları (SIDE modunda görüş dikdörtgeni bunun dışına taşmaz).
var bounds: AABB = AABB()
var has_bounds: bool = false

var _blend: float = 1.0
var _blend_duration: float = 1.0
var _from_transform: Transform3D = Transform3D.IDENTITY
var _from_fov: float = 40.0
var _focus: Vector3 = Vector3.ZERO
var _focus_goal: Vector3 = Vector3.ZERO
var _lookahead: float = 0.0
var _pullback: float = 0.0
var _look_height: float = 3.0
var _backend: Node = null
## 0..1 sarsıntı travması (CameraDirector.shake ekler).
var trauma: float = 0.0
var _shake_time: float = 0.0
var _shake_noise: FastNoiseLite = null


func _ready() -> void:
	camera = get_node_or_null(^"Camera3D") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	camera.current = true
	camera.fov = side_fov
	_look_height = side_look_height
	if target != null:
		_focus = target.global_position
		_focus_goal = _focus
	# Test/karşılaştırma için: BAYTEREK_CAMERA_BACKEND=rig yerleşik blend'i zorlar
	if OS.get_environment("BAYTEREK_CAMERA_BACKEND") == "rig":
		use_phantom_camera = false
	if use_phantom_camera and ResourceLoader.exists(PHANTOM_BACKEND_PATH):
		var script: Script = load(PHANTOM_BACKEND_PATH)
		_backend = script.new()
		_backend.name = "PhantomBackend"
		add_child(_backend)
		_backend.call(&"setup", self, camera)
	CameraDirector.register_rig(self)
	_snap()


func is_phantom() -> bool:
	return _backend != null


func get_backend() -> Node:
	return _backend


func apply_mode(new_mode: int, duration: float, yaw: float) -> void:
	mode = new_mode as Mode
	if mode == Mode.DEPTH:
		depth_yaw = yaw
	if camera == null or not camera.is_inside_tree():
		return
	if _backend != null:
		_backend.call(&"apply_mode", mode, duration, _mode_transform(Mode.SIDE), _mode_transform(Mode.DEPTH))
		return
	_from_transform = camera.global_transform
	_from_fov = camera.fov
	_blend_duration = maxf(duration, 0.0)
	_blend = 0.0 if _blend_duration > 0.0 else 1.0


func set_bounds(new_bounds: AABB) -> void:
	bounds = new_bounds
	has_bounds = new_bounds.size.x > 0.0 and new_bounds.size.y > 0.0


func clear_bounds() -> void:
	has_bounds = false


## Hedef modun son kamera rotasyonu (girdi sürekliliği için).
func get_target_basis() -> Basis:
	return _mode_transform(mode).basis


## Mevcut hedef (blend bittiğinde kameranın olacağı) dönüşüm — testler ve debug için.
func get_goal_transform() -> Transform3D:
	return _mode_transform(mode)


func get_focus() -> Vector3:
	return _focus


func get_lookahead() -> float:
	return _lookahead


func get_look_height() -> float:
	return _look_height


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if camera == null:
		return
	if trauma <= 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		return
	if _shake_noise == null:
		_shake_noise = FastNoiseLite.new()
		_shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_shake_noise.frequency = 1.0
	# Gerçek zamanla söner: hit-stop / yavaşlatma sırasında da sarsıntı okunur
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	_shake_time += real_delta * shake_frequency
	var k := trauma * trauma * shake_max_offset
	camera.h_offset = _shake_noise.get_noise_2d(_shake_time, 0.0) * k
	camera.v_offset = _shake_noise.get_noise_2d(0.0, _shake_time + 100.0) * k
	trauma = maxf(trauma - shake_decay * real_delta, 0.0)


func is_blending() -> bool:
	if _backend != null:
		return bool(_backend.call(&"is_blending"))
	return _blend < 1.0


func _physics_process(delta: float) -> void:
	if target == null or camera == null or delta <= 0.0:
		return
	_update_focus(delta)
	var side_goal := _mode_transform(Mode.SIDE)
	var depth_goal := _mode_transform(Mode.DEPTH)
	if _backend != null:
		_backend.call(&"update_goals", side_goal, depth_goal)
		return
	var goal := side_goal if mode == Mode.SIDE else depth_goal
	var goal_fov := side_fov if mode == Mode.SIDE else depth_fov
	if _blend < 1.0:
		_blend = minf(_blend + delta / _blend_duration, 1.0)
		var t := _ease_in_out(_blend)
		camera.global_transform = _from_transform.interpolate_with(goal, t)
		camera.fov = lerpf(_from_fov, goal_fov, t)
	else:
		camera.global_transform = goal
		camera.fov = goal_fov


func _update_focus(delta: float) -> void:
	var target_pos := target.global_position
	var vel := Vector3.ZERO
	if target is CharacterBody3D:
		vel = (target as CharacterBody3D).velocity

	if mode == Mode.SIDE:
		# Ölü bölge: odak yalnızca karakter kutudan çıkınca, çıktığı kadar kayar
		var half := dead_zone * 0.5
		var dx := target_pos.x - _focus_goal.x
		var dy := target_pos.y - _focus_goal.y
		if absf(dx) > half.x:
			_focus_goal.x = target_pos.x - signf(dx) * half.x
		if absf(dy) > half.y:
			_focus_goal.y = target_pos.y - signf(dy) * half.y
		_focus_goal.z = target_pos.z
	else:
		_focus_goal = target_pos
	_focus = _focus.lerp(_focus_goal, minf(1.0, follow_smoothing * delta))

	var desired_lookahead := clampf(vel.x / lookahead_full_speed, -1.0, 1.0) * side_lookahead
	_lookahead = lerpf(_lookahead, desired_lookahead, minf(1.0, delta / maxf(lookahead_time, 0.01)))
	var desired_pullback := side_fast_pullback if vel.length() > fast_speed_threshold else 0.0
	_pullback = lerpf(_pullback, desired_pullback, minf(1.0, pullback_smoothing * delta))
	var desired_look := side_fall_look_height if vel.y < -fall_speed_threshold else side_look_height
	_look_height = lerpf(_look_height, desired_look, minf(1.0, fall_look_smoothing * delta))


func _mode_transform(m: Mode) -> Transform3D:
	if m == Mode.SIDE:
		var distance := side_distance + _pullback
		var look_at_point := _focus + Vector3(_lookahead, _look_height, 0.0)
		look_at_point = _clamp_to_bounds(look_at_point, distance)
		var pos := look_at_point + Vector3(0.0, side_height - side_look_height, distance)
		return Transform3D(Basis.IDENTITY, pos).looking_at(look_at_point, Vector3.UP)
	var pivot := _focus + Vector3.UP * depth_look_height
	var offset := Basis(Vector3.UP, depth_yaw) * Vector3(0.0, depth_height, depth_distance)
	return Transform3D(Basis.IDENTITY, pivot + offset).looking_at(pivot, Vector3.UP)


## SIDE görüş dikdörtgeninin (karakter düzleminde) oda sınırları içinde kalması için
## bakış noktasını kırpar. Oda görüşten darsa ortalar.
func _clamp_to_bounds(point: Vector3, distance: float) -> Vector3:
	if not has_bounds:
		return point
	var half_h := distance * tan(deg_to_rad(side_fov) * 0.5)
	var aspect := 16.0 / 9.0
	if is_inside_tree():
		var vs := get_viewport().get_visible_rect().size
		if vs.y > 0.0:
			aspect = vs.x / vs.y
	var half_w := half_h * aspect
	var lo := bounds.position
	var hi := bounds.end
	var out := point
	out.x = (lo.x + hi.x) * 0.5 if hi.x - lo.x < half_w * 2.0 else clampf(point.x, lo.x + half_w, hi.x - half_w)
	out.y = (lo.y + hi.y) * 0.5 if hi.y - lo.y < half_h * 2.0 else clampf(point.y, lo.y + half_h, hi.y - half_h)
	return out


func snap_to_target() -> void:
	_lookahead = 0.0
	_pullback = 0.0
	_look_height = side_look_height
	if target != null:
		_focus_goal = target.global_position
	_snap()
	camera.reset_physics_interpolation()


func _snap() -> void:
	if target == null:
		return
	_focus = target.global_position
	_focus_goal = _focus
	camera.global_transform = _mode_transform(mode)
	camera.fov = side_fov if mode == Mode.SIDE else depth_fov
	_blend = 1.0
	if _backend != null:
		_backend.call(&"snap", mode, _mode_transform(Mode.SIDE), _mode_transform(Mode.DEPTH))


static func _ease_in_out(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
