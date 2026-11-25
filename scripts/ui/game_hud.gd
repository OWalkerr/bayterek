class_name GameHud
extends CanvasLayer
## Oyun HUD'u (docs/08, sol üst): can yaprakları (dolu yosun yeşili / boş kuru).
## Öz barı ve para M5+'da eklenir. Hasar anında kaybedilen yaprak kısa süre büyür.

const LEAF_SIZE: float = 26.0
const LEAF_GAP: float = 14.0
const DRY := Color("7a5a3a")
const POP_TIME: float = 0.3

var _leaves: Array[ColorRect] = []
var _box: HBoxContainer
var _pop: Dictionary = {}     # index -> kalan süre


func _ready() -> void:
	layer = 5
	_box = HBoxContainer.new()
	_box.position = Vector2(28.0, 24.0)
	_box.add_theme_constant_override(&"separation", int(LEAF_GAP))
	add_child(_box)
	EventBus.player_damaged.connect(_on_damaged)
	EventBus.player_healed.connect(func(_l: int) -> void: refresh())
	refresh()


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
