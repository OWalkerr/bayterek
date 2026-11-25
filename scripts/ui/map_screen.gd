class_name MapScreen
extends CanvasLayer
## Harita ekranı (docs/08): Tab / Select ile açılır, oyun duraklar. Yalnızca ziyaret edilen
## odalar çizilir (keşif ödülü); bulunulan oda Öz altını çerçeveli, Ocak'lı odalarda ateş noktası.
## Veri: MapService (oda sahnelerinden), GameState.visited_rooms.

const CELL: Vector2 = Vector2(64.0, 44.0)
const GAP: float = 6.0
const ROOM_FILL := Color("4a3550")
const ROOM_EDGE := Color("f4efe3")
const DOOR_LINE := Color("4fb3a9")

var region: StringName = &"kok_dibi"
var _panel: PanelContainer
var _canvas: Control
var _title: Label
var _legend: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.ROOT_SHADOW, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", UiStyle.panel_style(0.95))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_title = UiStyle.label("Kök Dibi — Harita", 30, UiStyle.SAP_GOLD)
	box.add_child(_title)
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(720.0, 360.0)
	_canvas.draw.connect(_draw_map)
	box.add_child(_canvas)
	_legend = UiStyle.label("", UiStyle.FONT_SIZE_SMALL, UiStyle.MUSHROOM)
	box.add_child(_legend)


func is_open() -> bool:
	return visible


func toggle() -> void:
	set_open(not visible)


func set_open(open: bool) -> void:
	visible = open
	get_tree().paused = open
	if open:
		_legend.text = "Altın çerçeve: bulunduğun oda · Altın nokta: Ocak · Kut parçası: %d · Tab: kapat" \
				% GameState.kut_shards
		_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"map") or (visible and event.is_action_pressed(&"pause")):
		toggle()
		get_viewport().set_input_as_handled()


## Görünür (ziyaret edilmiş) odaların hücre dikdörtgenleri: room_id -> Rect2 (ızgara birimi).
func visible_rooms() -> Dictionary:
	var out: Dictionary = {}
	var rooms := MapService.get_region_rooms(region)
	for id: StringName in rooms.keys():
		if GameState.is_visited(id):
			var info: Dictionary = rooms[id]
			out[id] = Rect2(Vector2(info["cell"]), Vector2(info["size"]))
	return out


func _draw_map() -> void:
	var rooms := MapService.get_region_rooms(region)
	var shown := visible_rooms()
	if shown.is_empty():
		_canvas.draw_string(ThemeDB.fallback_font, Vector2(20.0, 40.0), "Henüz keşfedilmiş oda yok.",
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, UiStyle.SKY_WHITE)
		return
	# Izgara sınırları → tuvalin ortasına yerleştir (y yukarı = yukarı)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for r: Rect2 in shown.values():
		lo = lo.min(r.position)
		hi = hi.max(r.end)
	var grid_px := (hi - lo) * CELL
	var origin := (_canvas.size - grid_px) * 0.5
	var to_px := func(cell: Vector2) -> Vector2:
		return origin + Vector2(cell.x - lo.x, hi.y - cell.y) * CELL

	# Kapı bağlantıları (iki uç da görünürse)
	for id: StringName in shown.keys():
		for door: Dictionary in rooms[id]["doors"]:
			var other: StringName = door["target_room"]
			if shown.has(other):
				var a: Vector2 = to_px.call(shown[id].get_center())
				var b: Vector2 = to_px.call(shown[other].get_center())
				_canvas.draw_line(a, b, DOOR_LINE, 3.0)
	for id: StringName in shown.keys():
		var r: Rect2 = shown[id]
		var top_left: Vector2 = to_px.call(Vector2(r.position.x, r.end.y))
		var rect := Rect2(top_left + Vector2(GAP, GAP) * 0.5, r.size * CELL - Vector2(GAP, GAP))
		var current := id == GameState.current_room
		_canvas.draw_rect(rect, ROOM_FILL)
		_canvas.draw_rect(rect, UiStyle.SAP_GOLD if current else ROOM_EDGE, false, 3.0 if current else 1.5)
		if rooms[id]["has_ocak"]:
			_canvas.draw_circle(rect.position + Vector2(12.0, 12.0), 6.0, UiStyle.SAP_GOLD)
		if current:
			# Elmas işaret (web varsayılan fontunda ◆ glifi yok → şekil çiziliyor)
			var c := rect.get_center()
			_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(9, 0),
					c + Vector2(0, 9), c + Vector2(-9, 0)]), UiStyle.SAP_GOLD)
