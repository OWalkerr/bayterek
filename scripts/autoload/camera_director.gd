extends Node
## Aktif kamera modunu yönetir. Oyun kodu kamerayla doğrudan değil, bu API ile konuşur.
## Arka uç (Phantom Camera ya da yerleşik blend) CameraRig içinde seçilir; bu API değişmez.
##
## Girdi sürekliliği (docs/05): mod değişirken basılı tutulan yön tuşu eski anlamını korur;
## tüm yön tuşları bırakılınca yeni kameranın eksenlerine geçilir.

## Geçiş sırasında zaman yavaşlaması (docs/05: 0.85x, 0.3 sn). TimeScale.slowmo_enabled ile kapanır.
@export var transition_slowmo_scale: float = 0.85
@export var transition_slowmo_time: float = 0.3
## Bu eşiğin altındaki girdi "bırakılmış" sayılır.
@export var input_release_threshold: float = 0.15

var rig: CameraRig = null
var mode: int = CameraRig.Mode.SIDE

var _held_basis: Basis = Basis.IDENTITY
var _continuity: bool = false


func register_rig(new_rig: CameraRig) -> void:
	rig = new_rig
	rig.apply_mode(mode, 0.0, 0.0)


func set_mode(new_mode: int, duration: float = 1.0, depth_yaw_degrees: float = 0.0) -> void:
	if new_mode == mode:
		return
	# Geçişten önceki eksenler, tuş bırakılana kadar geçerli kalır
	_held_basis = get_input_basis()
	_continuity = _move_input_held()
	mode = new_mode
	if is_instance_valid(rig):
		rig.apply_mode(new_mode, duration, deg_to_rad(depth_yaw_degrees))
	if duration > 0.0 and TimeScale.slowmo_enabled:
		TimeScale.request(&"camera_transition", transition_slowmo_scale, transition_slowmo_time)
	EventBus.camera_mode_changed.emit(new_mode)


## Oda değişimi / ışınlanma: geçişsiz SIDE moduna dön ve kamerayı hedefe oturt.
func reset_to_side() -> void:
	var changed := mode != CameraRig.Mode.SIDE
	mode = CameraRig.Mode.SIDE
	_continuity = false
	TimeScale.clear(&"camera_transition")
	if is_instance_valid(rig):
		rig.apply_mode(mode, 0.0, 0.0)
		rig.snap_to_target()
	if changed:
		EventBus.camera_mode_changed.emit(mode)


func is_side_mode() -> bool:
	return mode == CameraRig.Mode.SIDE


func is_input_continuity_active() -> bool:
	return _continuity


## Oda sınırları (SIDE modunda kamera görüşü dışına taşmaz).
func set_room_bounds(bounds: AABB) -> void:
	if is_instance_valid(rig):
		rig.set_bounds(bounds)


## Hareket girdisinin hangi eksenlere çevrileceği. Girdi sürekliliği etkinse geçişten
## önceki eksenler; değilse hedef modun son açısı (geçiş sırasında bile sabit).
func get_input_basis() -> Basis:
	if _continuity:
		if _move_input_held():
			return _held_basis
		_continuity = false
	if not is_instance_valid(rig):
		return Basis.IDENTITY
	return rig.get_target_basis()


func _move_input_held() -> bool:
	return Input.get_vector(&"move_left", &"move_right", &"move_down", &"move_up").length() \
			> input_release_threshold
