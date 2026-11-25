class_name TuningPanel
extends PanelContainer
## F2 canlı tuning paneli: PlayerTuning.LIVE_FIELDS alanlarını kaydırıcılarla anında değiştirir.
## "Kopyala" değerleri .tres'e yapıştırılabilir metin olarak panoya koyar; "Sıfırla" varsayılanlara döner.

var tuning: PlayerTuning
var _sliders: Dictionary = {}     # alan adı -> HSlider
var _values: Dictionary = {}      # alan adı -> Label
var _status: Label


func setup(target: PlayerTuning) -> void:
	tuning = target
	add_theme_stylebox_override(&"panel", UiStyle.panel_style())
	custom_minimum_size = Vector2(460.0, 0.0)
	var root := VBoxContainer.new()
	add_child(root)
	root.add_child(UiStyle.label("Canlı Tuning (F2)", UiStyle.FONT_SIZE, UiStyle.SAP_GOLD))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440.0, 620.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for field: Array in PlayerTuning.LIVE_FIELDS:
		var key: String = field[0]
		var row := HBoxContainer.new()
		var name_label := UiStyle.label(key, UiStyle.FONT_SIZE_SMALL)
		name_label.custom_minimum_size = Vector2(190.0, 0.0)
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = field[1]
		slider.max_value = field[2]
		slider.step = field[3]
		slider.value = float(tuning.get(key))
		slider.focus_mode = Control.FOCUS_NONE
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(150.0, 0.0)
		slider.value_changed.connect(_on_value_changed.bind(key))
		row.add_child(slider)
		var value_label := UiStyle.label("", UiStyle.FONT_SIZE_SMALL, UiStyle.MUSHROOM)
		value_label.custom_minimum_size = Vector2(70.0, 0.0)
		row.add_child(value_label)
		list.add_child(row)
		_sliders[key] = slider
		_values[key] = value_label
		_refresh_label(key)

	var buttons := HBoxContainer.new()
	var copy := UiStyle.button("Kopyala")
	copy.pressed.connect(_on_copy)
	buttons.add_child(copy)
	var reset := UiStyle.button("Sıfırla")
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)
	root.add_child(buttons)
	_status = UiStyle.label("", UiStyle.FONT_SIZE_SMALL, UiStyle.MUSHROOM)
	root.add_child(_status)


func set_value(key: String, value: float) -> void:
	var slider: HSlider = _sliders.get(key)
	if slider != null:
		slider.value = value


func _on_value_changed(value: float, key: String) -> void:
	tuning.set(key, value)
	_refresh_label(key)


func _refresh_label(key: String) -> void:
	var l: Label = _values[key]
	l.text = "%.2f" % float(tuning.get(key))


func _on_copy() -> void:
	DisplayServer.clipboard_set(tuning.to_tres_snippet())
	_status.text = "Panoya kopyalandı — bana yapıştırabilirsin."


func _on_reset() -> void:
	var defaults := PlayerTuning.new()
	for field: Array in PlayerTuning.LIVE_FIELDS:
		var key: String = field[0]
		set_value(key, float(defaults.get(key)))
	_status.text = "Varsayılanlara dönüldü."
