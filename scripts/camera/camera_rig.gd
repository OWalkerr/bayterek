class_name CameraRig
extends Node3D
## Bağımlılıksız kamera düzeneği: SIDE (2.5D) ve DEPTH (3. şahıs) modları arasında
## konum + rotasyon + FOV'u aynı anda tween eder. Ayrıntı: docs/05_CAMERA_CINEMATICS.md

enum Mode { SIDE, DEPTH }

@export var target: Node3D

@export_group("SIDE")
@export var side_distance: float = 14.0
@export var side_height: float = 3.5
## Karakteri ekranın alt üçte birinde tutmak için bakış noktası karakterin üstünde.
@export var side_look_height: float = 3.0
@export var side_fov: float = 40.0
@export var side_lookahead: float = 2.5
@export var side_fast_pullback: float = 2.0

@export_group("DEPTH")
@export var depth_distance: float = 6.0
@export var depth_height: float = 2.5
@export var depth_look_height: float = 1.4
@export var depth_fov: float = 60.0

@export_group("Takip")
@export var follow_smoothing: float = 6.0
@export var lookahead_smoothing: float = 2.5

var mode: Mode = Mode.SIDE
var depth_yaw: float = 0.0
var camera: Camera3D

var _blend: float = 1.0
var _blend_duration: float = 1.0
var _from_transform: Transform3D = Transform3D.IDENTITY
var _from_fov: float = 40.0
var _focus: Vector3 = Vector3.ZERO
var _lookahead: float = 0.0
var _pullback: float = 0.0


func _ready() -> void:
	camera = get_node_or_null(^"Camera3D") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	camera.current = true
	camera.fov = side_fov
	if target != null:
		_focus = target.global_position
	CameraDirector.register_rig(self)
	_snap()


func apply_mode(new_mode: int, duration: float, yaw: float) -> void:
	mode = new_mode as Mode
	if mode == Mode.DEPTH:
		depth_yaw = yaw
	if camera == null or not camera.is_inside_tree():
		return
	_from_transform = camera.global_transform
	_from_fov = camera.fov
	_blend_duration = maxf(duration, 0.0)
	_blend = 0.0 if _blend_duration > 0.0 else 1.0


## Hedef modun son kamera rotasyonu (girdi sürekliliği için).
func get_target_basis() -> Basis:
	return _mode_transform(mode).basis


func _physics_process(delta: float) -> void:
	if target == null or camera == null:
		return
	_update_focus(delta)
	var goal := _mode_transform(mode)
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
	_focus = _focus.lerp(target_pos, minf(1.0, follow_smoothing * delta))
	var vel := Vector3.ZERO
	if target is CharacterBody3D:
		vel = (target as CharacterBody3D).velocity
	var desired_lookahead := clampf(vel.x / 7.0, -1.0, 1.0) * side_lookahead
	_lookahead = lerpf(_lookahead, desired_lookahead, minf(1.0, lookahead_smoothing * delta))
	var desired_pullback := side_fast_pullback if vel.length() > 9.0 else 0.0
	_pullback = lerpf(_pullback, desired_pullback, minf(1.0, 1.5 * delta))


func _mode_transform(m: Mode) -> Transform3D:
	if m == Mode.SIDE:
		var look_at_point := _focus + Vector3(_lookahead, side_look_height, 0.0)
		var pos := _focus + Vector3(_lookahead, side_height, side_distance + _pullback)
		return Transform3D(Basis.IDENTITY, pos).looking_at(look_at_point, Vector3.UP)
	var pivot := _focus + Vector3.UP * depth_look_height
	var offset := Basis(Vector3.UP, depth_yaw) * Vector3(0.0, depth_height, depth_distance)
	return Transform3D(Basis.IDENTITY, pivot + offset).looking_at(pivot, Vector3.UP)


func snap_to_target() -> void:
	_lookahead = 0.0
	_pullback = 0.0
	_snap()
	camera.reset_physics_interpolation()


func _snap() -> void:
	if target == null:
		return
	_focus = target.global_position
	camera.global_transform = _mode_transform(mode)
	_blend = 1.0


static func _ease_in_out(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
