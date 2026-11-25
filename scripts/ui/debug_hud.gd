class_name DebugHud
extends CanvasLayer
## Geliştirme HUD'u: F1 durum bilgisi, F2 canlı tuning, oda seçici (0–3), oda süresi ve
## mükemmel bırakma bildirimi. Oyun HUD'u (yapraklar, Öz) M2'de ayrı gelir (docs/08).

signal room_requested(index: int)

const MESSAGE_TIME: float = 2.5

var player: Player
var _info: Label
var _message: Label
var _message_timer: float = 0.0
var _tuning: TuningPanel
var _room_menu: PanelContainer
var _room_names: PackedStringArray = []
var _room_title: Label
var _timer_label: Label
var room_time: float = 0.0
var room_running: bool = false
## Süre ilk harekette başlar; hedefe varınca durur.
var room_finished: bool = false


func setup(target: Player, room_names: PackedStringArray) -> void:
	player = target
	_room_names = room_names
	layer = 10

	_info = UiStyle.label("", UiStyle.FONT_SIZE_SMALL)
	_info.position = Vector2(24.0, 16.0)
	add_child(_info)

	_room_title = UiStyle.label("", UiStyle.FONT_SIZE, UiStyle.SAP_GOLD)
	_room_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_room_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_title.offset_top = 16.0
	_room_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_room_title)

	_timer_label = UiStyle.label("", UiStyle.FONT_SIZE, UiStyle.SKY_WHITE)
	_timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.offset_top = 50.0
	_timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_timer_label)

	_message = UiStyle.label("", 34, UiStyle.SAP_GOLD)
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.grow_vertical = Control.GROW_DIRECTION_BOTH
	_message.offset_top = -200.0
	add_child(_message)

	_tuning = TuningPanel.new()
	_tuning.setup(player.tuning)
	_tuning.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_tuning.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tuning.offset_top = 16.0
	_tuning.offset_right = -16.0
	_tuning.visible = false
	add_child(_tuning)

	_build_room_menu()
	EventBus.vine_released.connect(_on_vine_released)
	EventBus.vine_broken.connect(_on_vine_broken)


func is_room_menu_visible() -> bool:
	return _room_menu.visible


func show_room_menu(value: bool) -> void:
	_room_menu.visible = value


func on_room_loaded(index: int, room: GreyboxRoom) -> void:
	_room_title.text = "%d · %s — %s" % [index, room.display_name, room.idea]
	room_time = 0.0
	room_running = false
	room_finished = false


func start_room_timer() -> void:
	if not room_running and not room_finished:
		room_running = true


func on_goal(best: float) -> void:
	room_running = false
	room_finished = true
	var text := "Hedef! %.2f sn" % room_time
	if best > 0.0:
		text += "   (en iyi %.2f)" % best
	flash_message(text + "\nR: tekrar · 0–3: oda seç", 5.0)


func flash_message(text: String, duration: float = MESSAGE_TIME) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	_message_timer = duration


func _build_room_menu() -> void:
	_room_menu = PanelContainer.new()
	_room_menu.add_theme_stylebox_override(&"panel", UiStyle.panel_style(0.9))
	_room_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_room_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_room_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	_room_menu.add_child(box)
	box.add_child(UiStyle.label("BAYTEREK — M1 Hareket Odaları", 30, UiStyle.SAP_GOLD))
	box.add_child(UiStyle.label("Tuşla (0–3) veya tıklayarak seç. Hareket edince menü kapanır.",
			UiStyle.FONT_SIZE_SMALL))
	for i in _room_names.size():
		var b := UiStyle.button("%d · %s" % [i, _room_names[i]])
		b.pressed.connect(func() -> void: room_requested.emit(i))
		box.add_child(b)
	box.add_child(UiStyle.label(
			"A/D hareket · Space zıpla/bırak · W/S ip kısalt-uzat, tırman\n" \
			+ "R odayı baştan başlat · F1 bilgi · F2 canlı tuning",
			UiStyle.FONT_SIZE_SMALL, UiStyle.MUSHROOM))
	add_child(_room_menu)


func _process(delta: float) -> void:
	if player == null:
		return
	if Input.is_action_just_pressed(&"toggle_debug"):
		_info.visible = not _info.visible
	if Input.is_action_just_pressed(&"toggle_tuning"):
		_tuning.visible = not _tuning.visible
	for i in _room_names.size():
		if Input.is_action_just_pressed(StringName("room_%d" % i)):
			room_requested.emit(i)

	if room_running:
		room_time += delta
	_timer_label.text = "%.2f sn" % room_time

	if _message_timer > 0.0:
		_message_timer -= delta
		_message.modulate.a = clampf(_message_timer / 0.5, 0.0, 1.0)

	if _info.visible:
		_info.text = _info_text()


func _info_text() -> String:
	var mode_name := "SIDE" if CameraDirector.is_side_mode() else "DEPTH"
	var lines: PackedStringArray = []
	lines.append("Durum: %s   Kamera: %s   Hız: %.1f m/s" % [
			Player.State.keys()[player.state], mode_name, player.velocity.length()])
	lines.append("Konum: (%.1f, %.1f, %.1f)   coyote %.2f  buffer %.2f" % [
			player.global_position.x, player.global_position.y, player.global_position.z,
			player.get_coyote_timer(), player.get_jump_buffer_timer()])
	if player.is_swinging():
		var window := "  ★ MÜKEMMEL PENCERE" if player.is_in_perfect_window() else ""
		lines.append("Sarkaç: θ %.0f°  ω %.2f rad/sn  L %.2f m%s" % [
				rad_to_deg(player.get_swing_angle()), player.get_swing_omega(),
				player.get_rope_length(), window])
		var anchor := player.get_current_anchor()
		if anchor is RottenVine:
			lines.append("Çürük sarmaşık: %.2f sn" % (anchor as RottenVine).get_time_left())
	return "\n".join(lines)


func _on_vine_released(_anchor: Node3D, perfect: bool) -> void:
	if perfect:
		flash_message("Mükemmel bırakma!", 1.0)


func _on_vine_broken(_anchor: Node3D) -> void:
	flash_message("Çürük sarmaşık koptu!", 1.0)
