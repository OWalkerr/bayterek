class_name GameHud
extends CanvasLayer
## Oyun HUD'u (docs/08, sol üst): can yaprakları (dolu yosun yeşili / boş kuru).
## Altında Öz barı (altın, M5): kamçı isabetiyle dolar, iyileşmede harcanır; iyileşme
## maliyeti kadar dolu bölümler parlak. Para (Öz damlası) Yuva Dalları'nda gelecek.

const LEAF_SIZE: float = 26.0
const LEAF_GAP: float = 14.0
const DRY := Color("7a5a3a")
const POP_TIME: float = 0.3

var _leaves: Array[ColorRect] = []
var _box: HBoxContainer
var _pop: Dictionary = {}     # index -> kalan süre
var _sap_back: ColorRect
var _sap_fill: ColorRect
var _sap_marks: Array[ColorRect] = []
const SAP_BAR: Vector2 = Vector2(200.0, 12.0)


func _ready() -> void:
	layer = 5
	_box = HBoxContainer.new()
	_box.position = Vector2(28.0, 24.0)
	_box.add_theme_constant_override(&"separation", int(LEAF_GAP))
	add_child(_box)
	EventBus.player_damaged.connect(_on_damaged)
	EventBus.player_healed.connect(func(_l: int) -> void: refresh())
	EventBus.player_sap_changed.connect(func(_s: int) -> void: refresh_sap())
	_build_sap_bar()
	refresh()
	refresh_sap()


func _build_sap_bar() -> void:
	_sap_back = ColorRect.new()
	_sap_back.color = Color(UiStyle.ROOT_SHADOW, 0.85)
	_sap_back.position = Vector2(28.0, 24.0 + LEAF_SIZE + 10.0)
	_sap_back.size = SAP_BAR
	add_child(_sap_back)
	_sap_fill = ColorRect.new()
	_sap_fill.color = UiStyle.SAP_GOLD
	_sap_fill.size = Vector2(0.0, SAP_BAR.y)
	_sap_back.add_child(_sap_fill)
	# İyileşme eşiği çizgileri (her heal_cost'ta bir)
	var cost := PlayerTuning.new().heal_cost
	var n := GameState.SAP_MAX / cost
	for i in range(1, n):
		var mark := ColorRect.new()
		mark.color = UiStyle.ROOT_SHADOW
		mark.size = Vector2(2.0, SAP_BAR.y)
		mark.position = Vector2(SAP_BAR.x * float(i * cost) / float(GameState.SAP_MAX) - 1.0, 0.0)
		_sap_back.add_child(mark)
		_sap_marks.append(mark)


func refresh_sap() -> void:
	if _sap_fill == null:
		return
	_sap_fill.size.x = SAP_BAR.x * float(GameState.sap) / float(GameState.SAP_MAX)


func get_sap_fill_ratio() -> float:
	return _sap_fill.size.x / SAP_BAR.x


func refresh() -> void:
	while _leaves.size() < GameState.max_leaves:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(LEAF_SIZE, LEAF_SIZE)
		var leaf := ColorRect.new()
		leaf.size = Vector2(LEAF_SIZE, LEAF_SIZE) * 0.75
		leaf.position = Vector2(LEAF_SIZE, LEAF_SIZE) * 0.125
		leaf.pivot_offset = leaf.size * 0.5
		leaf.rotation = PI * 0.25
		holder.add_child(leaf)
		_box.add_child(holder)
		_leaves.append(leaf)
	for i in _leaves.size():
		_leaves[i].visible = i < GameState.max_leaves
		_leaves[i].color = UiStyle.MOSS if i < GameState.leaves else DRY


func get_filled_count() -> int:
	var n := 0
	for leaf: ColorRect in _leaves:
		if leaf.visible and leaf.color == UiStyle.MOSS:
			n += 1
	return n


func _on_damaged(_amount: int, leaves_left: int) -> void:
	for i in range(leaves_left, mini(leaves_left + _amount, _leaves.size())):
		_pop[i] = POP_TIME
	refresh()


func _process(delta: float) -> void:
	for i: int in _pop.keys():
		var t: float = _pop[i] - delta
		var leaf := _leaves[i]
		if t <= 0.0:
			_pop.erase(i)
			leaf.scale = Vector2.ONE
		else:
			_pop[i] = t
			leaf.scale = Vector2.ONE * (1.0 + 0.6 * (t / POP_TIME))
