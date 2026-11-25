class_name StoryCard
extends CanvasLayer
## Hikaye anı kartı (docs/08 "Diyalog"): alt-orta kart, konuşanın rengiyle ince çerçeve
## (Alpay altın, Kocabaş yosun, Gökbike gök beyazı), metin harf harf akar. Zıpla / saldırı:
## satırı tamamla → sonraki satır. Sürerken oyuncu kilitli. M8'de Dialogue Manager'a taşınır.

## story_id -> [[konuşan ("" = anlatıcı), metin], ...]
const STORIES: Dictionary = {
	&"kocabas_first_message": [
		["", "Kökyiyen'in yuttuğu köklerin arasından yosunlu, tanıdık bir ses yükselir."],
		["Kocabaş", "Alpay… Sesimi duyuyor musun? Ben buradayım, köklerin içinde."],
		["Kocabaş", "Kara Öz beni yukarı sürüklüyor. Çürüklük yukarıdan geliyor… tüyünün geldiği yerden."],
		["Kocabaş", "Tırman, yavrum. Öz Damarları'na. Ben dayanırım."],
		["", "Kut parçası kazandın. Kök Dibi tamamlandı."],
	],
}
const SPEAKER_COLORS: Dictionary = {
	"Kocabaş": Color("5e8c4a"),
	"Alpay": Color("e8a33d"),
	"Gökbike": Color("f4efe3"),
}

@export var chars_per_second: float = 40.0

var story_id: StringName = &""
var line_index: int = -1
var _lines: Array = []
var _visible_chars: float = 0.0
var _panel: PanelContainer
var _style: StyleBoxFlat
var _speaker: Label
var _text: Label
var _hint: Label
var _player: Player


func _ready() -> void:
	layer = 14
	_panel = PanelContainer.new()
	_style = UiStyle.panel_style(0.92)
	_panel.add_theme_stylebox_override(&"panel", _style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_bottom = -40.0
	_panel.custom_minimum_size = Vector2(900.0, 0.0)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_speaker = UiStyle.label("", UiStyle.FONT_SIZE, UiStyle.MOSS)
	box.add_child(_speaker)
	_text = UiStyle.label("", 26, UiStyle.SKY_WHITE)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(860.0, 0.0)
	box.add_child(_text)
	_hint = UiStyle.label("Space / J — devam", UiStyle.FONT_SIZE_SMALL, UiStyle.MUSHROOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_hint)
	_panel.visible = false
	EventBus.story_requested.connect(play)


func is_playing() -> bool:
	return _panel.visible


func play(id: StringName) -> void:
	if not STORIES.has(id):
		push_warning("Bilinmeyen hikaye: %s" % id)
		return
	story_id = id
	_lines = STORIES[id]
	line_index = -1
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player != null:
		_player.set_cinematic(true)
	_panel.visible = true
	EventBus.cutscene_started.emit(id)
	_next_line()


## Testler ve "atla" için: satır yazılıyorsa tamamla, bitmişse sonrakine geç.
func advance() -> void:
	if not is_playing():
		return
	if is_line_typing():
		_visible_chars = (_lines[line_index][1] as String).length()
		_text.visible_characters = -1   # -1 = tamamı görünür
	else:
		_next_line()


## Satır hâlâ harf harf yazılıyor mu? (visible_characters -1 = tamamı görünür)
func is_line_typing() -> bool:
	var full: String = _lines[line_index][1]
	return _text.visible_characters >= 0 and _text.visible_characters < full.length()


func _next_line() -> void:
	line_index += 1
	if line_index >= _lines.size():
		_finish()
		return
	var speaker: String = _lines[line_index][0]
	_speaker.text = speaker
	_speaker.visible = not speaker.is_empty()
	var c: Color = SPEAKER_COLORS.get(speaker, UiStyle.SAP_GOLD)
	_style.border_color = c
	_speaker.add_theme_color_override(&"font_color", c)
	_text.text = _lines[line_index][1]
	_visible_chars = 0.0
	_text.visible_characters = 0


func _finish() -> void:
	_panel.visible = false
	if _player != null and is_instance_valid(_player):
		_player.set_cinematic(false)
	EventBus.cutscene_finished.emit(story_id)
	EventBus.story_finished.emit(story_id)


func _process(delta: float) -> void:
	if not is_playing():
		return
	var full: String = _lines[line_index][1]
	if is_line_typing():
		_visible_chars += chars_per_second * delta
		_text.visible_characters = mini(int(_visible_chars), full.length())
	if Input.is_action_just_pressed(&"jump") or Input.is_action_just_pressed(&"attack"):
		advance()
