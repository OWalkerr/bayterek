class_name AbilityToast
extends CanvasLayer
## "Yetenek kazanma" anı (docs/08): ekran ortasında yeteneğin adı + tek cümle + tuş ipucu.
## Oyunu durdurmaz; `show_time` sn sonra söner.

const SHOW_TIME: float = 3.5
## ability_id -> [ad (tr anahtarı), tek cümle, tuş ipucu]
const INFO: Dictionary = {
	&"whip_grapple": [&"ABILITY_WHIP_GRAPPLE", "Kamçın artık uzaktaki kanca çiçeklerine yapışır.",
			"K / sağ tık / RT — parlayan çiçeğe kanca at"],
}

var _panel: PanelContainer
var _title: Label
var _line: Label
var _hint: Label
var _timer: float = 0.0


func _ready() -> void:
	layer = 15
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", UiStyle.panel_style(0.92))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(box)
	box.add_child(UiStyle.label("YENİ YETENEK", UiStyle.FONT_SIZE_SMALL, UiStyle.MUSHROOM))
	_title = UiStyle.label("", 44, UiStyle.SAP_GOLD)
	box.add_child(_title)
	_line = UiStyle.label("", UiStyle.FONT_SIZE, UiStyle.SKY_WHITE)
	box.add_child(_line)
	_hint = UiStyle.label("", UiStyle.FONT_SIZE_SMALL, UiStyle.MUSHROOM)
	box.add_child(_hint)
	_panel.visible = false
	EventBus.ability_unlocked.connect(show_ability)


func is_showing() -> bool:
	return _panel.visible


func show_ability(ability_id: StringName) -> void:
	var info: Array = INFO.get(ability_id, [str(ability_id), "", ""])
	_title.text = tr(info[0]).to_upper()
	_line.text = info[1]
	_hint.text = info[2]
	_panel.visible = true
	_panel.modulate.a = 1.0
	_timer = SHOW_TIME


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	_panel.modulate.a = clampf(_timer / 0.6, 0.0, 1.0)
	if _timer <= 0.0:
		_panel.visible = false
