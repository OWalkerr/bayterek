extends Node
## Girdi eşlemelerini kodla tanımlar (project.godot'u sade tutmak için).
## Ayarlar menüsü geldiğinde (M9) kullanıcı atamaları user://settings.cfg'den üstüne yazılır.

const DEADZONE: float = 0.25


func _enter_tree() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_add_action("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_add_action("move_up", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_add_action("move_down", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_add_action("jump", [KEY_SPACE], [JOY_BUTTON_A], [])
	_add_action("attack", [KEY_J], [JOY_BUTTON_X], [])
	_add_action("grapple", [KEY_K], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_add_action("grab", [KEY_SHIFT], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_add_action("heal", [KEY_L], [JOY_BUTTON_B], [])
	_add_action("pause", [KEY_ESCAPE], [JOY_BUTTON_START], [])
	_add_action("map", [KEY_TAB], [JOY_BUTTON_BACK], [])
	_add_action("toggle_debug", [KEY_F1], [], [])
	# Geliştirme kısayolları (greybox test odaları + canlı tuning); web test build'inde kalır.
	_add_action("toggle_tuning", [KEY_F2], [], [])
	_add_action("restart_room", [KEY_R], [], [])
	_add_action("room_0", [KEY_0], [], [])
	_add_action("room_1", [KEY_1], [], [])
	_add_action("room_2", [KEY_2], [], [])
	_add_action("room_3", [KEY_3], [], [])
	_add_action("room_4", [KEY_4], [], [])
	_add_action("room_5", [KEY_5], [], [])


func _add_action(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, DEADZONE)
	for key: int in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
	for button: int in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = button
		InputMap.action_add_event(action, jb)
	for pair: Array in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = pair[0]
		jm.axis_value = pair[1]
		InputMap.action_add_event(action, jm)
	if action == "attack" or action == "grapple":
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT if action == "attack" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, mb)
