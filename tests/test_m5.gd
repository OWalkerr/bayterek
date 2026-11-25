extends Node
## M5 "Kök Dibi greybox" testleri (headless):
##  bölge verisi (12–15 oda, 2 Kut parçası, yeteneksiz/yetenekli erişilebilirlik = kapı matrisi),
##  Kamçı Kancası (yeteneksiz çalışmaz, hedef vurgusu, ip çekme), sunakta kazanma (+ kayıt + ekran),
##  botla: Kanca Bahçesi (kancalı geçer / kancasız geçemez), Ocak Odası tavan kapısı, Çiçek Kuyusu,
##  derinlik sırrı → Gizli Oda → Kut parçası; Öz barı ve iyileşme.
## Çalıştır: godot --headless --fixed-fps 60 --path . res://tests/test_m5.tscn

const TEST_SLOT: int = 98
const REGION: StringName = &"kok_dibi"
const G: StringName = &"whip_grapple"

var _failures: int = 0
var _level: Node3D
var _player: Player
var _jf: int = 0
var _gf: int = 0
var _last_flower: Node = null


func _ready() -> void:
	GameState.save_slot = TEST_SLOT
	GameState.delete_save()
	_level = load("res://scenes/main/main.tscn").instantiate() as Node3D
	add_child(_level)
	_player = _level.get("player") as Player
	_run.call_deferred()


func _only(name: String) -> bool:
	return not OS.has_environment("ONLY") or OS.get_environment("ONLY") == name


func _run() -> void:
	await _frames(20)
	GameState.autosave_enabled = false
	if _only("region_data"):
		_test_region_data()
	if _only("grapple_basics"):
		await _test_grapple_basics()
	if _only("gate_without_grapple"):
		await _test_gate_without_grapple()
	if _only("shrine"):
		await _test_shrine()
	if _only("kanca_bahcesi"):
		await _test_kanca_bahcesi()
	if _only("hub_up"):
		await _test_hub_up()
	if _only("cicek_kuyusu"):
		await _test_cicek_kuyusu()
	if _only("secret"):
		await _test_secret()
	if _only("sap_and_heal"):
		await _test_sap_and_heal()
	GameState.delete_save()
	print("[TEST] bitti — başarısız: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- Veri

func _test_region_data() -> void:
	MapService.clear_cache()
	var rooms := MapService.get_region_rooms(REGION)
	_check("bölge: 12–15 oda", rooms.size() >= 12 and rooms.size() <= 15, "oda=%d" % rooms.size())
	var pickups := 0
	for id: StringName in rooms.keys():
		pickups += (rooms[id]["pickups"] as Array).size()
	_check("bölge: 2 Kut parçası", pickups == 2, "kut=%d" % pickups)
	var without := _reachable(rooms, [])
	var with_g := _reachable(rooms, [G])
	_check("kapı matrisi: kancasız Sunak'a ulaşılır", without.has(&"sunak"), "")
	_check("kapı matrisi: kancasız Kanca Bahçesi ötesi kapalı",
			not without.has(&"spor_mahzeni") and not without.has(&"kokyiyen_esigi") and not without.has(&"ust_kokler"),
			"erişilen=%s" % str(without.keys()))
	_check("kapı matrisi: kancayla tüm bölge açık", with_g.size() == rooms.size(), "erişilen=%d/%d" % [with_g.size(), rooms.size()])
	_check("Ocak: boss eşiğinde Ocak var", rooms[&"kokyiyen_esigi"]["has_ocak"], "")


## Yalnızca `abilities` ile kullanılabilen kapılardan BFS.
func _reachable(rooms: Dictionary, abilities: Array) -> Dictionary:
	var seen: Dictionary = {RoomRegistry.START_ROOM: true}
	var queue: Array[StringName] = [RoomRegistry.START_ROOM]
	while not queue.is_empty():
		var cur: StringName = queue.pop_front()
		for door: Dictionary in rooms[cur]["doors"]:
			var req: StringName = door.get("requires", &"")
			if req != &"" and not abilities.has(req):
				continue
			var nxt: StringName = door["target_room"]
			if rooms.has(nxt) and not seen.has(nxt):
				seen[nxt] = true
				queue.append(nxt)
	return seen


# ---------------------------------------------------------------- Kanca

func _test_grapple_basics() -> void:
	GameState.abilities.clear()
	SceneRouter.enter_room_immediate(&"kanca_bahcesi")
	_teleport(Vector3(3.9, 0.05, 0.0))   # ilk çiçeğe ≈ 8 m (menzil sınırı)
	await _frames(5)
	_check("kanca: yetenek yokken hedef yok", _player.grapple_target == null, "")
	await _press(&"grapple", 3)
	_check("kanca: yetenek yokken tutunmuyor", not _player.is_swinging(), "")
	GameState.unlock_ability(G)
	await _frames(3)
	var t := _player.grapple_target
	_check("kanca: menzildeki çiçek hedefleniyor ve parlıyor", t != null and t.is_targeted(), "")
	await _press(&"grapple", 3)
	_check("kanca: çiçeğe tutunup sallanıyor", _player.is_swinging() and _player.swing_state.grappled, "")
	await _frames(60)
	_check("kanca: ip hedef uzunluğa çekiliyor", absf(_player.get_rope_length() - _player.tuning.grapple_rope_length) < 0.3,
			"L=%.2f" % _player.get_rope_length())


func _test_gate_without_grapple() -> void:
	GameState.abilities.clear()
	var result := await _run_bot(&"kanca_bahcesi", Vector3(-6.0, 0.05, 0.0), func() -> bool:
		return _player.global_position.x > 27.0 and _player.is_on_floor(), 12.0)
	_check("kapı: kancasız Kanca Bahçesi geçilemiyor", not result, "")


func _test_shrine() -> void:
	GameState.abilities.clear()
	GameState.autosave_enabled = true
	SceneRouter.enter_room_immediate(&"sunak")
	await _frames(3)
	Input.action_press(&"move_right")
	for i in 120:
		await _frames(1)
		if GameState.has_ability(G):
			break
	Input.action_release(&"move_right")
	_check("sunak: Kamçı Kancası kazanıldı", GameState.has_ability(G), "")
	var toast := _level.get("ability_toast") as AbilityToast
	_check("sunak: yetenek kazanma ekranı", toast.is_showing(), "")
	var saved := _read_save()
	_check("sunak: kaydedildi", (saved.get("abilities", []) as Array).has("whip_grapple"), "")
	GameState.autosave_enabled = false
	await _frames(10)


func _test_kanca_bahcesi() -> void:
	GameState.unlock_ability(G)
	var ok := await _run_bot(&"kanca_bahcesi", Vector3(-6.0, 0.05, 0.0), func() -> bool:
		return _player.global_position.x > 27.0 and _player.is_on_floor(), 25.0)
	_check("bot: Kanca Bahçesi kancayla geçiliyor", ok, "konum=%s" % str(_player.global_position))


func _test_hub_up() -> void:
	GameState.unlock_ability(G)
	var ok := await _run_bot(&"ocak_odasi", Vector3(-9.0, 0.05, 0.0), func() -> bool:
		return _room_id() == &"ust_kokler", 25.0)
	_check("bot: Ocak Odası tavan kapısı (sarmaşık + kanca) → Üst Kökler", ok, "oda=%s konum=%s" % [_room_id(), str(_player.global_position)])
	GameState.abilities.clear()
	var blocked := await _run_bot(&"ocak_odasi", Vector3(-9.0, 0.05, 0.0), func() -> bool:
		return _room_id() == &"ust_kokler", 12.0)
	_check("kapı: kancasız tavan kapısına ulaşılamıyor", not blocked, "")
	GameState.unlock_ability(G)


func _test_cicek_kuyusu() -> void:
	GameState.unlock_ability(G)
	var ok := await _run_bot(&"cicek_kuyusu", Vector3(-4.0, 0.05, 0.0), func() -> bool:
		return _room_id() == &"kokyiyen_esigi", 30.0)
	_check("bot: Çiçek Kuyusu (tırmanma + kanca) → Kökyiyen Eşiği", ok, "oda=%s konum=%s" % [_room_id(), str(_player.global_position)])
	GameState.abilities.clear()
	var blocked := await _run_bot(&"cicek_kuyusu", Vector3(-4.0, 0.05, 0.0), func() -> bool:
		return _room_id() == &"kokyiyen_esigi", 15.0)
	_check("kapı: kancasız Çiçek Kuyusu tırmanılamıyor", not blocked, "")
	GameState.unlock_ability(G)


func _test_secret() -> void:
	SceneRouter.enter_room_immediate(&"ust_kokler")
	_teleport(Vector3(30.0, 0.05, 0.0))
	await _frames(5)
	var room := _level.get("room") as Node
	var illusion: Node3D = null
	for c: Node in room.get_children():
		if c.is_in_group(&"illusion_wall"):
			illusion = c as Node3D
	_check("sır: yandan bakınca duvar görünüyor", illusion != null and illusion.visible and CameraDirector.is_side_mode(), "")
	Input.action_press(&"move_right")
	for i in 60:
		await _frames(1)
		if not CameraDirector.is_side_mode():
			break
	Input.action_release(&"move_right")
	await _frames(5)
	_check("sır: duvar dibinde kamera derinliğe dönüyor", not CameraDirector.is_side_mode(), "")
	_check("sır: sahte duvar kayboluyor", illusion != null and not illusion.visible, "")
	Input.action_press(&"move_up")
	for i in 180:
		await _frames(1)
		if _room_id() == &"gizli_oda":
			break
	Input.action_release(&"move_up")
	await _frames(30)
	_check("sır: geçitten Gizli Oda'ya", _room_id() == &"gizli_oda", "oda=%s" % _room_id())
	var before := GameState.kut_shards
	Input.action_press(&"move_right")
	for i in 120:
		await _frames(1)
		if GameState.kut_shards > before:
			break
	Input.action_release(&"move_right")
	_check("sır: ikinci Kut parçası alınıyor", GameState.kut_shards == before + 1, "kut=%d" % GameState.kut_shards)


# ---------------------------------------------------------------- Öz / iyileşme

func _test_sap_and_heal() -> void:
	SceneRouter.enter_room_immediate(&"yuva")
	await _frames(5)
	GameState.spend_sap(GameState.sap)
	var crawler: Enemy = null
	for e: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		if e is RotCrawler:
			crawler = e as Enemy
			break
	(crawler as RotCrawler).walk_speed = 0.0
	crawler.global_position = Vector3(6.0, 0.1, 0.0)
	_teleport(Vector3(4.2, 0.05, 0.0))
	_player.facing = Vector3.RIGHT
	_player.invuln_timer = 30.0
	await _frames(25)
	await _press(&"attack", 3)
	await _frames(20)
	_check("Öz: isabet başına dolar", GameState.sap == _player.tuning.sap_per_hit, "öz=%d" % GameState.sap)
	var hud := _level.get("game_hud") as GameHud
	_check("Öz: HUD barı güncel", absf(hud.get_sap_fill_ratio() - float(GameState.sap) / GameState.SAP_MAX) < 0.01, "")
	_player.invuln_timer = 0.0
	# Yetersiz Öz → iyileşme yok
	_teleport(Vector3(-4.0, 0.05, 0.0))
	await _frames(10)
	GameState.leaves = 3
	await _press(&"heal", int(_player.tuning.heal_time * 60.0) + 10)
	_check("iyileşme: yetersiz Öz'de olmuyor", GameState.leaves == 3 and _player.state != Player.State.HEAL, "")
	# Yeterli Öz → 1 sn sonra +1 yaprak
	GameState.add_sap(GameState.SAP_MAX)
	Input.action_press(&"heal")
	await _frames(5)
	_check("iyileşme: basılı tutunca HEAL", _player.state == Player.State.HEAL, "state=%s" % Player.State.keys()[_player.state])
	await _frames(int(_player.tuning.heal_time * 60.0))
	Input.action_release(&"heal")
	await _frames(2)
	_check("iyileşme: 1 sn sonra +1 yaprak, Öz harcanır", GameState.leaves == 4 \
			and GameState.sap == GameState.SAP_MAX - _player.tuning.heal_cost, "yaprak=%d öz=%d" % [GameState.leaves, GameState.sap])
	# Hasar iyileşmeyi keser
	Input.action_press(&"heal")
	await _frames(20)
	_player.take_damage(1, _player.global_position + Vector3.RIGHT)
	await _frames(int(_player.tuning.heal_time * 60.0))
	Input.action_release(&"heal")
	_check("iyileşme: hasar kesiyor (yarım süre kaybolur)", GameState.leaves == 3, "yaprak=%d" % GameState.leaves)


# ---------------------------------------------------------------- Bot

## Kaşif bot: hedef yöne (dir) yürür, kenarda/duvarda/tırmanma sarmaşığı önünde zıplar,
## tırmanma sarmaşığında tepeye çıkar; menzilde YENİ ve daha YÜKSEK/İLERİDEKİ bir çiçek varsa
## kanca atar; sallanırken pompalar, hedef yöndeki kolda > 40° iken bırakır.
## Tırmanma tepesinde çiçek yoksa hedef yöne yana zıplar.
func _run_bot(room_id: StringName, start: Vector3, done: Callable, seconds: float, dir: float = 1.0) -> bool:
	_release_all()
	SceneRouter.enter_room_immediate(room_id)
	_teleport(start)
	_last_flower = null
	await _frames(5)
	for i in int(seconds * 60.0):
		_bot_step(dir)
		await _frames(1)
		if OS.has_environment("BOT_DEBUG") and (i % 15 == 0 or (OS.has_environment("DBG_FROM") and i >= int(OS.get_environment("DBG_FROM")) and i < int(OS.get_environment("DBG_FROM")) + 25)):
			print("  [bot] f=%d st=%s pos=(%.1f, %.1f) v=(%.1f, %.1f) θ=%.0f tgt=%s" % [i, Player.State.keys()[_player.state],
					_player.global_position.x, _player.global_position.y, _player.velocity.x, _player.velocity.y,
					rad_to_deg(_player.get_swing_angle()), str(_player.grapple_target.global_position) if _player.grapple_target else "-"])
		if done.call():
			_release_all()
			return true
	_release_all()
	return false


func _bot_step(dir: float) -> void:
	if _jf > 0:
		_jf -= 1
		if _jf == 0:
			Input.action_release(&"jump")
	if _gf > 0:
		_gf -= 1
		if _gf == 0:
			Input.action_release(&"grapple")
		return   # kanca basışı işlenene kadar başka karar verme
	Input.action_release(&"move_up")
	var t := _player.grapple_target
	var good_target := t != null and t != _last_flower \
			and (t.global_position.y > _player.global_position.y + 2.0 or (t.global_position.x - _player.global_position.x) * dir > 2.0)
	match _player.state:
		Player.State.GROUND:
			_hold(dir)
			if good_target and t.global_position.y > _player.global_position.y + 5.0 and absf(t.global_position.x - _player.global_position.x) < 7.0:
				_grapple(t)
			elif not _floor_ahead(dir) or _player.is_on_wall() or _climb_ahead(dir):
				_jump()
		Player.State.AIR:
			_hold(dir)
			if good_target and (t.global_position.x - _player.global_position.x) * dir > -1.0:
				_grapple(t)
		Player.State.CLIMB:
			var vine := _player.get_current_climb_vine()
			var hand_y := _player.get_hand_position().y
			if hand_y < vine.get_top().y - 0.4:
				_hold(0.0)
				Input.action_press(&"move_up")
			elif good_target:
				_grapple(t)
			else:
				_hold(dir)
				_jump()
		Player.State.SWING:
			var w := _player.get_swing_omega()
			_hold(1.0 if w >= 0.0 else -1.0)
			if good_target and _player.swing_state.grappled == false:
				_grapple(t)
			elif rad_to_deg(_player.get_swing_angle()) * dir > 40.0 and w * dir > 0.0:
				_jump()
			elif good_target and rad_to_deg(_player.get_swing_angle()) * dir > 20.0 and w * dir > 0.0:
				_grapple(t)


func _grapple(t: GrappleFlower) -> void:
	if _gf > 0:
		return
	_last_flower = t
	Input.action_press(&"grapple")
	_gf = 3


func _jump() -> void:
	if _jf > 0:
		return
	Input.action_press(&"jump")
	_jf = 14


func _hold(dir: float) -> void:
	if dir > 0.0:
		Input.action_press(&"move_right")
		Input.action_release(&"move_left")
	elif dir < 0.0:
		Input.action_press(&"move_left")
		Input.action_release(&"move_right")
	else:
		Input.action_release(&"move_left")
		Input.action_release(&"move_right")


func _floor_ahead(dir: float) -> bool:
	var space := _player.get_world_3d().direct_space_state
	var from := _player.global_position + Vector3(0.7 * dir, 0.5, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.8, Layers.WORLD)
	return not space.intersect_ray(q).is_empty()


func _climb_ahead(dir: float) -> bool:
	for node: Node in get_tree().get_nodes_in_group(ClimbVine.GROUP):
		var v := node as ClimbVine
		var dx := (v.global_position.x - _player.global_position.x) * dir
		if dx > 0.0 and dx < 1.2 and v.get_bottom().y < _player.global_position.y + 3.0:
			return true
	return false


# ---------------------------------------------------------------- Yardımcılar

func _room_id() -> StringName:
	var r := _level.get("room") as Room
	return r.room_id if r != null else &""


func _read_save() -> Dictionary:
	var path := "user://save_%d.json" % TEST_SLOT
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _release_all() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"attack", &"grapple", &"heal"]:
		Input.action_release(a)
	_jf = 0
	_gf = 0


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
