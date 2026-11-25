extends Node
## Aktif kamera modunu yönetir. Oyun kodu kamerayla doğrudan değil, bu API ile konuşur.
## (Phantom Camera'ya geçilirse yalnızca bu dosya ve CameraRig değişir.)

var rig: CameraRig = null
var mode: int = CameraRig.Mode.SIDE


func register_rig(new_rig: CameraRig) -> void:
	rig = new_rig
	rig.apply_mode(mode, 0.0, 0.0)


func set_mode(new_mode: int, duration: float = 1.0, depth_yaw_degrees: float = 0.0) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	if is_instance_valid(rig):
		rig.apply_mode(new_mode, duration, deg_to_rad(depth_yaw_degrees))
	EventBus.camera_mode_changed.emit(new_mode)


func is_side_mode() -> bool:
	return mode == CameraRig.Mode.SIDE


## Hareket girdisinin hangi eksenlere çevrileceği. Geçiş sırasında bile
## hedef modun son açısını döndürür; böylece tutulan yön tuşu anlam değiştirmez.
func get_input_basis() -> Basis:
	if not is_instance_valid(rig):
		return Basis.IDENTITY
	return rig.get_target_basis()
