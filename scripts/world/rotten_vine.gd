class_name RottenVine
extends VineAnchor
## Çürük sarmaşık: ilk tutunmadan `break_time` sn sonra kopar (bırakılsa bile sayaç durmaz),
## `respawn_time` sn sonra yeniden büyür. Kopma yaklaştıkça titrer ve kararır (okunur uyarı).

@export var break_time: float = 1.5
@export var respawn_time: float = 4.0
@export var shake_amount: float = 0.08
@export var rotten_color: Color = Color("5a1e5c")
@export var warning_color: Color = Color("c9d93b")

var _countdown: float = -1.0
var _respawn_timer: float = 0.0


func _ready() -> void:
	vine_color = rotten_color
	super._ready()


func _vine_color_changes() -> bool:
	return true


func _process(delta: float) -> void:
	if not enabled:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_regrow()
		return
	if _countdown >= 0.0:
		_countdown += delta
		var t := clampf(_countdown / break_time, 0.0, 1.0)
		_vine_material.albedo_color = rotten_color.lerp(warning_color, t)
		_hand_offset = Vector3(sin(_time * 40.0) * shake_amount * t, 0.0, 0.0)
		if _countdown >= break_time:
			_snap()
			return
	super._process(delta)


## Kopmaya kalan süre (sayaç başlamadıysa -1).
func get_time_left() -> float:
	if _countdown < 0.0:
		return -1.0
	return maxf(break_time - _countdown, 0.0)


func _on_grab_changed(value: bool) -> void:
	if value and _countdown < 0.0:
		_countdown = 0.0


func _snap() -> void:
	enabled = false
	visible = false
	_countdown = -1.0
	_respawn_timer = respawn_time
	_hand_offset = Vector3.ZERO
	EventBus.vine_broken.emit(self)


func _regrow() -> void:
	enabled = true
	visible = true
	_grabbed = false
	_vine_material.albedo_color = rotten_color
	_set_vine_end(global_position + Vector3.DOWN * vine_length)
