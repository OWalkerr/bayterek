extends Node
## Oda yükleme/boşaltma ve kapı geçişleri (docs/06). Kapıdan geçişte: kısa karartma (0.25 sn),
## hedef oda arka planda yüklenir (ResourceLoader.load_threaded_*; web'de tek iş parçacığında da çalışır),
## oyuncu hedef kapıya hızı korunarak konur, otomatik kayıt alınır, aydınlanır.
## Odayı sahneye takma/çıkarma işini "host" (main.tscn kabuğu) yapar: swap_room(), place_player().

@export var fade_time: float = 0.25
@export var fade_color: Color = Color("120c1c")

var host: Node = null
var busy: bool = false
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 50
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(fade_color, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)


func register_host(new_host: Node) -> void:
	host = new_host


func get_current_room() -> Room:
	if host == null:
		return null
	return host.get(&"room") as Room


## Kapı geçişi (karartmalı, asenkron). Geçiş sürerken gelen istekler yok sayılır.
func go_through_door(target_room: StringName, target_door: StringName, carry_velocity: Vector3) -> void:
	if busy or host == null or not RoomRegistry.has_room(target_room):
		return
	busy = true
	EventBus.room_transition_started.emit(target_room)
	ResourceLoader.load_threaded_request(RoomRegistry.scene_path(target_room))
	await _fade(1.0)
	var packed := await _await_loaded(target_room)
	_enter(packed, target_door, Vector3.INF, carry_velocity)
	GameState.autosave()
	await _fade(0.0)
	busy = false


## Anında oda girişi (yeni oyun, devam, geliştirici seçici, ölüm). `door_id` boşsa `position`,
## o da yoksa odanın spawn_point'i kullanılır.
func enter_room_immediate(room_id: StringName, door_id: StringName = &"", position: Vector3 = Vector3.INF) -> Room:
	if host == null or not RoomRegistry.has_room(room_id):
		return null
	return _enter(RoomRegistry.load_scene(room_id), door_id, position, Vector3.ZERO)


## Son Ocak'ta (yoksa mevcut/başlangıç odasının başında) tam canla dirilme.
func respawn_at_last_ocak() -> Room:
	GameState.reset_health()
	GameState.spend_sap(GameState.sap)   # ölüm Öz'ü sıfırlar
	if GameState.has_last_ocak() and RoomRegistry.has_room(GameState.last_ocak_room):
		var room := enter_room_immediate(GameState.last_ocak_room)
		var ocak := room.get_ocak(GameState.last_ocak) if room != null else null
		if ocak != null:
			host.call(&"place_player", ocak.get_respawn_position(), Vector3.ZERO)
		return room
	var current := GameState.current_room if RoomRegistry.has_room(GameState.current_room) else RoomRegistry.START_ROOM
	return enter_room_immediate(current)


## Ocak'ta dinlenme: kısa oturma, oda yeniden yüklenir (düşmanlar yeniden doğar), oyuncu yerinde kalır.
func rest_at_ocak(room_id: StringName, ocak_id: StringName, rest_time: float) -> void:
	if busy or host == null:
		return
	busy = true
	var player := host.get(&"player") as Player
	player.set_cinematic(true)
	await _fade(0.6, rest_time * 0.5)
	var room := enter_room_immediate(room_id)
	var ocak := room.get_ocak(ocak_id) if room != null else null
	if ocak != null:
		host.call(&"place_player", ocak.get_respawn_position(), Vector3.ZERO)
	await _fade(0.0, rest_time * 0.5)
	player.set_cinematic(false)
	busy = false


## Aynı oda içinde karartmalı yer değiştirme (boss faz geçişi vb.). Kamera SIDE'a oturur.
func move_player_with_fade(position: Vector3, duration: float = -1.0) -> void:
	if host == null:
		return
	await _fade(1.0, duration)
	host.call(&"place_player", position, Vector3.ZERO)
	CameraDirector.reset_to_side()
	await _fade(0.0, duration)


func _enter(packed: PackedScene, door_id: StringName, position: Vector3, carry_velocity: Vector3) -> Room:
	if packed == null:
		return null
	var room := host.call(&"swap_room", packed) as Room
	var spawn := room.spawn_point
	var velocity := Vector3.ZERO
	if door_id != &"":
		var door := room.get_door(door_id)
		if door != null:
			spawn = door.get_arrival_position()
			velocity = carry_velocity
		else:
			push_warning("Kapı bulunamadı: %s/%s" % [room.room_id, door_id])
	elif position != Vector3.INF:
		spawn = position
	host.call(&"place_player", spawn, velocity)
	GameState.enter_room(room.room_id)
	CameraDirector.set_room_bounds(room.bounds)
	CameraDirector.reset_to_side()
	EventBus.room_changed.emit(room.room_id)
	return room


func _await_loaded(room_id: StringName) -> PackedScene:
	var path := RoomRegistry.scene_path(room_id)
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var res := ResourceLoader.load_threaded_get(path) as PackedScene
	if res == null:
		res = RoomRegistry.load_scene(room_id)
	return res


func _fade(alpha: float, duration: float = -1.0) -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_fade_rect, ^"color:a", alpha, fade_time if duration < 0.0 else duration)
	await tween.finished


func is_faded() -> bool:
	return _fade_rect.color.a > 0.01
