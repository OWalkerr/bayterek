class_name BossCard
extends CanvasLayer
## Boss isim kartı (docs/08): alt-orta, iki satır — "KÖKYİYEN — Köklerin Açlığı".
## Yavaşça belirir, `hold_time` kalır, söner.

@export var fade_time: float = 0.5
@export var hold_time: float = 2.5

var _box: VBoxContainer
var _name: Label
var _title: Label
var _t: float = -1.0


func _ready() -> void:
	layer = 12
	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_bottom = -90.0
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_box)
	_name = UiStyle.label("", 52, UiStyle.SKY_WHITE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_name)
	_title = UiStyle.label("", UiStyle.FONT_SIZE, UiStyle.ROT_EYE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_title)
	_box.modulate.a = 0.0
	EventBus.boss_intro.connect(show_card)


func is_showing() -> bool:
	return _t >= 0.0


func get_text() -> String:
	return "%s — %s" % [_name.text, _title.text]


func show_card(name_key: StringName, title_key: StringName) -> void:
	_name.text = tr(name_key)
	_title.text = tr(title_key)
	_t = 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var total := fade_time * 2.0 + hold_time
	if _t < fade_time:
		_box.modulate.a = _t / fade_time
	elif _t < fade_time + hold_time:
		_box.modulate.a = 1.0
	elif _t < total:
		_box.modulate.a = 1.0 - (_t - fade_time - hold_time) / fade_time
	else:
		_box.modulate.a = 0.0
		_t = -1.0
