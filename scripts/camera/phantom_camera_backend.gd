class_name PhantomCameraBackend
extends Node
## CameraRig için Phantom Camera arka ucu (addons/phantom_camera, v0.9.4.2).
## Her mod bir PhantomCamera3D (follow_mode NONE): dönüşümünü her fizik karesinde CameraRig
## hesaplar; mod değişince öncelik değişir ve PhantomCameraHost konum + rotasyon + FOV'u
## tween eder (docs/05 "Üretim" stratejisi). Eklenti kaldırılırsa CameraRig.use_phantom_camera
## = false yapılır ve bu dosya silinir — oyun kodu etkilenmez.

const ACTIVE_PRIORITY: int = 10
const INACTIVE_PRIORITY: int = 0
## 0 sn'lik geçişlerde (oda değişimi) kullanılacak çok kısa tween.
const INSTANT_DURATION: float = 0.0

var rig: CameraRig
var host: PhantomCameraHost
var pcams: Dictionary = {}       # CameraRig.Mode -> PhantomCamera3D
var _mode: int = CameraRig.Mode.SIDE
var _blend_left: float = 0.0


func setup(owner_rig: CameraRig, camera: Camera3D) -> void:
	rig = owner_rig
	host = PhantomCameraHost.new()
	host.name = "PhantomCameraHost"
	camera.add_child(host)
	pcams[CameraRig.Mode.SIDE] = _make_pcam("PCamSide", rig.side_fov)
	pcams[CameraRig.Mode.DEPTH] = _make_pcam("PCamDepth", rig.depth_fov)
	_set_active(CameraRig.Mode.SIDE)


func _make_pcam(pcam_name: String, fov: float) -> PhantomCamera3D:
	var pcam := PhantomCamera3D.new()
	pcam.name = pcam_name
	pcam.follow_mode = PhantomCamera3D.FollowMode.NONE
	pcam.look_at_mode = PhantomCamera3D.LookAtMode.NONE
	var res := Camera3DResource.new()
	res.fov = fov
	pcam.camera_3d_resource = res
	var tween := PhantomCameraTween.new()
	tween.duration = 1.0
	tween.transition = PhantomCameraTween.TransitionType.SINE
	tween.ease = PhantomCameraTween.EaseType.EASE_IN_OUT
	pcam.tween_resource = tween
	pcam.tween_on_load = false
	pcam.top_level = true
	rig.add_child(pcam)
	return pcam


func update_goals(side_goal: Transform3D, depth_goal: Transform3D) -> void:
	(pcams[CameraRig.Mode.SIDE] as PhantomCamera3D).global_transform = side_goal
	(pcams[CameraRig.Mode.DEPTH] as PhantomCamera3D).global_transform = depth_goal
	_blend_left = maxf(_blend_left - get_physics_process_delta_time(), 0.0)


func apply_mode(mode: int, duration: float, side_goal: Transform3D, depth_goal: Transform3D) -> void:
	update_goals(side_goal, depth_goal)
	var pcam := pcams[mode] as PhantomCamera3D
	pcam.tween_resource.duration = maxf(duration, INSTANT_DURATION)
	_blend_left = duration
	_set_active(mode)


func snap(mode: int, side_goal: Transform3D, depth_goal: Transform3D) -> void:
	update_goals(side_goal, depth_goal)
	var pcam := pcams[mode] as PhantomCamera3D
	pcam.tween_resource.duration = INSTANT_DURATION
	_blend_left = 0.0
	_set_active(mode)
	var goal := side_goal if mode == CameraRig.Mode.SIDE else depth_goal
	rig.camera.global_transform = goal
	rig.camera.fov = rig.side_fov if mode == CameraRig.Mode.SIDE else rig.depth_fov


func is_blending() -> bool:
	return _blend_left > 0.0


func get_active_pcam() -> PhantomCamera3D:
	return pcams[_mode]


func _set_active(mode: int) -> void:
	_mode = mode
	for m: int in pcams.keys():
		(pcams[m] as PhantomCamera3D).priority = ACTIVE_PRIORITY if m == mode else INACTIVE_PRIORITY
