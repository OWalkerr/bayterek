extends Node
## M4 "dünya altyapısı" testleri (headless):
##  harita verisi (karşılıklı kapılar, çakışmayan hücreler, erişilebilirlik), yeni oyun,
##  kapı geçişi (karartma + hız korunur + otomatik kayıt), her kapının fiziksel varışı,
##  Ocak'ta dinlenme (can + kayıt + düşmanlar yeniden doğar), ölümde son Ocak'ta dirilme,
##  kalıcı toplanabilir, kayıt/yükleme turu, Devam, harita ekranı.
## Kayıt yuvası 99 kullanılır (oyuncunun kaydına dokunmaz).
## Çalıştır: godot --headless --fixed-fps 60 --path . res://tests/test_m4.tscn

const TEST_SLOT: int = 99
const REGION: StringName = &"kok_dibi"

var _failures: int = 0
var _level: Node3D
var _player: Player


func _ready() -> void:
	GameState.save_slot = TEST_SLOT
	GameState.delete_save()
	_level = load("res://scenes/main/main.tscn").instantiate() as Node3D
	add_child(_level)
	_player = _level.get("player") as Player
	_run.call_deferred()


func _run() -> void:
	await _frames(20)
	_test_map_data()
	await _test_new_game()
	await _test_door_walk()
	await _test_all_doors()
	await _test_ocak_rest()
	await _test_death_respawn()
	await _test_collectible()
	await _test_save_roundtrip_and_continue()
	await _test_map_screen()
	GameState.delete_save()
	print("[TEST] bitti — başarısız: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- Harita verisi

func _test_map_data() -> void:
	MapService.clear_cache()
	var rooms := MapService.get_region_rooms(REGION)
	_check("harita: Kök Dibi'nde en az 6 oda", rooms.size() >= 6, "oda=%d" % rooms.size())
	# Hücre çakışması yok
	var cells: Dictionary = {}
	var overlap := ""
	for id: StringName in rooms.keys():
		var c: Vector2i = rooms[id]["cell"]
		var s: Vector2i = rooms[id]["size"]
		for x in s.x:
			for y in s.y:
				var key := Vector2i(c.x + x, c.y + y)
				if cells.has(key):
					overlap += "%s↔%s " % [cells[key], id]
				cells[key] = id
	_check("harita: oda hücreleri çakışmıyor", overlap.is_empty(), overlap)
	# Kapılar karşılıklı
	var broken := ""
	for id: StringName in rooms.keys():
		for door: Dictionary in rooms[id]["doors"]:
			var tr: StringName = door["target_room"]
			var td: StringName = door["target_door"]
			var ok := false
			if rooms.has(tr):
				for back: Dictionary in rooms[tr]["doors"]:
					if back["id"] == td and back["target_room"] == id and back["target_door"] == door["id"]:
						ok = true
			if not ok:
				broken += "%s/%s→%s/%s " % [id, door["id"], tr, td]
	_check("harita: tüm kapılar karşılıklı", broken.is_empty(), broken)
	# Başlangıçtan her oda erişilebilir
	var seen: Dictionary = {RoomRegistry.START_ROOM: true}
	var queue: Array[StringName] = [RoomRegistry.START_ROOM]
	while not queue.is_empty():
		var cur: StringName = queue.pop_front()
		for door: Dictionary in rooms[cur]["doors"]:
			var nxt: StringName = door["target_room"]
			if not seen.has(nxt):
				seen[nxt] = true
				queue.append(nxt)
	_check("harita: tüm odalar başlangıçtan erişilebilir", seen.size() == rooms.size(),
			"erişilen=%d/%d" % [seen.size(), rooms.size()])
	var ocaks := 0
	for id: StringName in rooms.keys():
		if rooms[id]["has_ocak"]:
			ocaks += 1
	_check("harita: Ocak'lar okunuyor", ocaks >= 2, "ocak=%d" % ocaks)


# ---------------------------------------------------------------- Akış

func _test_new_game() -> void:
	(_level.get("hud") as DebugHud).new_game_requested.emit()
	await _frames(5)
	_check("yeni oyun: Ocak Odası'nda başlıyor", _room_id() == RoomRegistry.START_ROOM, "oda=%s" % _room_id())
	_check("yeni oyun: kayıt oluştu + ziyaret işaretli", GameState.has_save() and GameState.is_visited(RoomRegistry.START_ROOM), "")


func _test_door_walk() -> void:
	# Ocak Odası'ndan sağa yürü → Çürük Yuvası'nın batı kapısına varış, hız korunur
	_teleport(Vector3(8.0, 0.05, 0.0))
	Input.action_press(&"move_right")
	var arrived := false
	var vx_on_arrival := 0.0
	for i in 120:
		await _frames(1)
		if _room_id() == &"yuva":
			arrived = true
			vx_on_arrival = _player.velocity.x
			break
	Input.action_release(&"move_right")
	_check("kapı: doğu kapısından Çürük Yuvası'na", arrived, "oda=%s" % _room_id())
	var door := _room().get_door(&"west")
	_check("kapı: hedef kapının varış noktasında", _player.global_position.distance_to(door.get_arrival_position()) < 1.0,
			"konum=%s" % str(_player.global_position))
	_check("kapı: hız korunuyor (momentum)", vx_on_arrival > 4.0, "vx=%.2f" % vx_on_arrival)
	await _frames(30)
	_check("kapı: karartma bitti", not SceneRouter.is_faded() and not SceneRouter.busy, "")
	var saved := _read_save()
	_check("kapı: otomatik kayıt (current_room=yuva)", saved.get("current_room", "") == "yuva", str(saved.get("current_room", "")))
	# Geri dön
	_kill_enemies()
	Input.action_press(&"move_left")
	for i in 150:
		await _frames(1)
		if _room_id() == RoomRegistry.START_ROOM:
			break
	Input.action_release(&"move_left")
	await _frames(30)
	_check("kapı: geri dönüş (Ocak Odası)", _room_id() == RoomRegistry.START_ROOM, "oda=%s" % _room_id())


## Her kapıdan geçiş: varış noktası zeminde, varınca geri kapıya takılmıyor.
func _test_all_doors() -> void:
	var rooms := MapService.get_region_rooms(REGION)
	var problems := ""
	var count := 0
	for id: StringName in rooms.keys():
		for door_info: Dictionary in rooms[id]["doors"]:
			SceneRouter.enter_room_immediate(id)
			await _frames(3)
			var door := _room().get_door(door_info["id"])
			_teleport(door.global_position + Vector3(0.0, 0.2, 0.0))
			for i in 90:
				await _frames(1)
				if _room_id() == door_info["target_room"] and not SceneRouter.busy:
					break
			await _frames(40)
			count += 1
			if _room_id() != door_info["target_room"]:
				problems += "%s/%s: varış odası %s; " % [id, door_info["id"], _room_id()]
				continue
			if not _player.is_on_floor() and _player.state != Player.State.AIR:
				problems += "%s/%s: varışta durum %s; " % [id, door_info["id"], Player.State.keys()[_player.state]]
			if not _floor_below(2.5):
				problems += "%s/%s: varışta zemin yok; " % [id, door_info["id"]]
	_check("kapılar: %d geçişin hepsi doğru odaya, zemine ve geri sekmeden" % count, problems.is_empty(), problems)


func _test_ocak_rest() -> void:
	SceneRouter.enter_room_immediate(RoomRegistry.START_ROOM)
	await _frames(5)
	var ocak := _room().get_ocak(&"merkez")
	_teleport(ocak.global_position + Vector3(0.8, 0.05, 0.0))
	await _frames(10)
	GameState.leaves = 2
	_check("Ocak: yakında ipucu görünüyor", ocak.is_player_near(), "")
	await _press(&"move_up", 3)
	for i in 120:
		await _frames(1)
		if not SceneRouter.busy:
			break
	_check("Ocak: can doldu", GameState.leaves == GameState.max_leaves, "yaprak=%d" % GameState.leaves)
	_check("Ocak: son Ocak işaretlendi", GameState.last_ocak == &"merkez" and GameState.last_ocak_room == RoomRegistry.START_ROOM, "")
	_check("Ocak: kaydedildi", _read_save().get("last_ocak", "") == "merkez", "")
	_check("Ocak: oyuncu kontrolde", _player.state != Player.State.CINEMATIC, "")
	# Düşmanlar yeniden doğar: Yuva'da birini öldür, Yuva'daki Ocak yok → genel kural: oda yeniden yüklenince doğar
	SceneRouter.enter_room_immediate(&"yuva")
	await _frames(3)
	var before := get_tree().get_nodes_in_group(Enemy.GROUP).size()
	_kill_enemies()
	await _frames(3)
	SceneRouter.enter_room_immediate(&"yuva")
	await _frames(3)
	_check("düşmanlar: odaya yeniden girince doğuyor", get_tree().get_nodes_in_group(Enemy.GROUP).size() == before,
			"önce=%d sonra=%d" % [before, get_tree().get_nodes_in_group(Enemy.GROUP).size()])


func _test_death_respawn() -> void:
	SceneRouter.enter_room_immediate(&"savrulma")
	await _frames(5)
	GameState.leaves = 1
	_player.take_damage(1, _player.global_position + Vector3.RIGHT)
	var delay: float = _level.get("death_restart_delay")
	await _frames(int(delay * 60.0) + 15)
	var ocak := _room().get_ocak(&"merkez") if _room_id() == RoomRegistry.START_ROOM else null
	_check("ölüm: son Ocak'ın odasında dirilme", _room_id() == RoomRegistry.START_ROOM, "oda=%s" % _room_id())
	_check("ölüm: Ocak'ın yanında, tam can", ocak != null and _player.global_position.distance_to(ocak.get_respawn_position()) < 0.6 \
			and GameState.leaves == GameState.max_leaves, "yaprak=%d" % GameState.leaves)


func _test_collectible() -> void:
	SceneRouter.enter_room_immediate(&"yanki")
	await _frames(5)
	var pick := _first_in_room(Collectible) as Collectible
	_check("toplanabilir: Yankı Mağarası'nda Kut parçası var", pick != null, "")
	if pick == null:
		return
	var before := GameState.kut_shards
	_teleport(pick.global_position + Vector3(0.0, -0.5, 0.0))
	await _frames(5)
	_check("toplanabilir: alınınca Kut +1 ve bayrak", GameState.kut_shards == before + 1 \
			and GameState.get_flag(_room().flag_key(&"kut_1"), false), "kut=%d" % GameState.kut_shards)
	SceneRouter.enter_room_immediate(&"yanki")
	await _frames(5)
	_check("toplanabilir: odaya dönünce yok (kalıcı)", _first_in_room(Collectible) == null, "")


func _test_save_roundtrip_and_continue() -> void:
	GameState.save_game()
	var snapshot := GameState.to_dict()
	GameState.reset()
	_check("kayıt: sıfırlanınca bellek boş", GameState.kut_shards == 0 and GameState.visited_rooms.is_empty(), "")
	GameState.load_game()
	_check("kayıt: yükleme sonrası aynı durum", JSON.stringify(GameState.to_dict(), "", true) == JSON.stringify(snapshot, "", true), "")
	GameState.reset()
	(_level.get("hud") as DebugHud).continue_requested.emit()
	await _frames(5)
	_check("devam: son Ocak'ın odasında", _room_id() == GameState.last_ocak_room, "oda=%s" % _room_id())
	_check("devam: kalıcı toplanabilir hâlâ alınmış", GameState.kut_shards >= 1, "")


func _test_map_screen() -> void:
	var map := _level.get("map_screen") as MapScreen
	var ev := InputEventAction.new()
	ev.action = &"map"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	_check("harita ekranı: Tab ile açılıyor ve oyun duruyor", map.is_open() and get_tree().paused, "")
	var shown := map.visible_rooms()
	_check("harita ekranı: yalnızca ziyaret edilen odalar", shown.size() == GameState.visited_rooms.size() - _count_non_region(),
			"gösterilen=%d ziyaret=%d" % [shown.size(), GameState.visited_rooms.size()])
	map.set_open(false)
	await _frames(2)
	_check("harita ekranı: kapanınca oyun sürüyor", not map.is_open() and not get_tree().paused, "")


# ---------------------------------------------------------------- Yardımcılar

func _count_non_region() -> int:
	var rooms := MapService.get_rooms()
	var n := 0
	for id: StringName in GameState.visited_rooms.keys():
		if not rooms.has(id) or rooms[id]["region"] != REGION:
			n += 1
	return n


func _room() -> Room:
	return _level.get("room") as Room


func _room_id() -> StringName:
	var r := _room()
	return r.room_id if r != null else &""


func _first_in_room(type: Variant) -> Node:
	for c: Node in _room().get_children():
		if is_instance_of(c, type) and not c.is_queued_for_deletion():
			return c
	return null


func _kill_enemies() -> void:
	for e: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		e.get_parent().remove_child(e)
		e.queue_free()


func _read_save() -> Dictionary:
	var path := "user://save_%d.json" % TEST_SLOT
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _floor_below(distance: float) -> bool:
	var space := _player.get_world_3d().direct_space_state
	var from := _player.global_position + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * distance, Layers.WORLD)
	return not space.intersect_ray(q).is_empty()


func _press(action: StringName, hold: int) -> void:
	Input.action_press(action)
	await _frames(hold)
	Input.action_release(action)


func _teleport(pos: Vector3) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("[TEST] OK   %s %s" % [name, detail])
	else:
		_failures += 1
		print("[TEST] FAIL %s %s" % [name, detail])
