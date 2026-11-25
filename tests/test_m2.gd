extends Node
## M2 "savaş temeli" testleri (headless):
##  kombo 1–1–2, kombo penceresi, yukarı vuruş, pogo, Savrulma Saldırısı, hit-stop,
##  temas hasarı + dokunulmazlık + geri itilme, düşüş cezası, ölüm → oda başı + tam can,
##  spor bulutu (yakın = hasar, uzak = güvenli), Şişkin yeniden doğma, bot ile savaş odası.
## Çalıştır: godot --headless --fixed-fps 60 --path . res://tests/test_m2.tscn

const COMBAT_ROOM: int = 4
const MAX_ROOM_SECONDS: float = 60.0

var _failures: int = 0
var _level: Node3D
var _player: Player
var _damage_events: Array[int] = []
var _kills: int = 0
var _bot_jump_frames: int = 0
var _bot_attack_frames: int = 0


func _ready() -> void:
	_level = load("res://scenes/main/main.tscn").instantiate() as Node3D
	add_child(_level)
	_player = _level.get("player") as Player
	EventBus.enemy_damaged.connect(func(_e: Node3D, amount: int) -> void: _damage_events.append(amount))
	EventBus.enemy_killed.connect(func(_e: Node3D) -> void: _kills += 1)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	if not OS.has_environment("BOT_ONLY"):
		await _test_combo()
		await _test_combo_window()
		await _test_up_attack()
		await _test_pogo()
		await _test_swing_attack()
		await _test_contact_damage()
		await _test_fall_damage()
		await _test_death_restart()
		await _test_spore_cloud()
	await _test_bot_combat_room()
	print("[TEST] bitti — başarısız: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- Kamçı

func _test_combo() -> void:
	_load_room(COMBAT_ROOM)
	await _frames(5)
	var crawler := _nearest(RotCrawler, Vector3(6.0, 0.0, 0.0)) as RotCrawler
	crawler.walk_speed = 0.0
	crawler.global_position = Vector3(6.0, 0.1, 0.0)
	_teleport(Vector3(4.2, 0.05, 0.0), Vector3.ZERO)
	_player.facing = Vector3.RIGHT
	_player.invuln_timer = 30.0
	await _frames(5)
	_damage_events.clear()
	var kills_before := _kills
	var indices: Array[int] = []
	for i in 3:
		await _press(&"attack", 3)
		indices.append(_player.combat.combo_index)
		await _wait_attack_end()
		await _frames(2)
	_check("kombo: 0-1-2 sırası", indices == [0, 1, 2], "indeks=%s" % str(indices))
	_check("kombo: hasarlar 1-1-2", _damage_events == [1, 1, 2], "hasar=%s" % str(_damage_events))
	_check("kombo: Sürüngen 3 vuruşta ölüyor", _kills == kills_before + 1 and not is_instance_valid(crawler), "")
	_check("hit-stop: zaman ölçeği geri döndü", is_equal_approx(Engine.time_scale, 1.0),
			"ts=%.2f" % Engine.time_scale)
	_player.invuln_timer = 0.0


func _test_combo_window() -> void:
	_load_room(COMBAT_ROOM)
	await _frames(5)
	_teleport(Vector3(-4.0, 0.05, 0.0), Vector3.ZERO)
	await _frames(30)   # önceki testin kombo bitiş beklemesi dolsun
	await _press(&"attack", 3)
	await _wait_attack_end()
	await _frames(int(_player.tuning.combo_window * 60.0) + 10)
	await _press(&"attack", 3)
	_check("kombo penceresi: geç basınca kombo sıfırlanıyor", _player.combat.combo_index == 0,
			"indeks=%d" % _player.combat.combo_index)
	await _wait_attack_end()


func _test_up_attack() -> void:
	_load_room(COMBAT_ROOM)
	await _frames(5)
	var gate := _nearest(SporeBloater, Vector3(38.5, 3.8, 0.0)) as SporeBloater
	_teleport(Vector3(gate.global_position.x, 1.55, 0.0), Vector3.ZERO)
	_player.invuln_timer = 30.0
	await _frames(5)
	Input.action_press(&"move_up")
	await _press(&"attack", 3)
	await _frames(8)
	Input.action_release(&"move_up")
	_check("yukarı vuruş: üstteki Şişkin patlıyor", gate.is_dead(), "")
	await _frames(30)
	_player.invuln_timer = 0.0


func _test_pogo() -> void:
	_load_room(COMBAT_ROOM)
	await _frames(5)
	var gate := _nearest(SporeBloater, Vector3(38.5, 3.8, 0.0)) as SporeBloater
	_teleport(gate.global_position + Vector3(0.0, 0.9, 0.0), Vector3.ZERO)
	_player.invuln_timer = 30.0
	await _frames(1)
	Input.action_press(&"move_down")
	await _press(&"attack", 3)
	var max_vy := 0.0
	for i in 12:
		await _frames(1)
		max_vy = maxf(max_vy, _player.velocity.y)
	Input.action_release(&"move_down")
	_check("pogo: aşağı vuruş Şişkin'i patlatıyor", gate.is_dead(), "")
	_check("pogo: oyuncu yukarı sıçrıyor", max_vy > _player.tuning.pogo_velocity * 0.8, "vy=%.2f" % max_vy)
	_check("pogo: spor bulutu oluşuyor", _count_group(SporeCloud.GROUP) > 0, "")
	await _frames(int(gate.respawn_time * 60.0) + 20)
	_check("pogo: kapı Şişkini yeniden doğuyor (soft-lock yok)", not gate.is_dead() and gate.visible, "")
	_player.invuln_timer = 0.0


func _test_swing_attack() -> void:
	_load_room(COMBAT_ROOM)
	await _frames(5)
	var vine := _nearest(VineAnchor, Vector3(26.0, 8.0, 0.0)) as VineAnchor
	_teleport(vine.global_position + Vector3(-1.0, -3.0 - Player.HAND_HEIGHT, 0.0), Vector3(11.0, 0.0, 0.0))
	_player.invuln_timer = 30.0
	await _frames(2)
	_check("savrulma: sallanma başladı", _player.is_swinging(), "")
	var bloater := _nearest(SporeBloater, Vector3(27.0, 3.5, 0.0)) as SporeBloater
	bloater.global_position = _player.get_body_center() + Vector3(1.2, 0.0, 0.0)
	bloater.home_position = bloater.global_position
	var fast := _player.swing_state.get_speed() >= _player.tuning.swing_attack_fast_speed
	_damage_events.clear()
	await _press(&"attack", 3)
	await _frames(8)
	_check("savrulma: sallanırken kamçı isabet ediyor", not is_instance_valid(bloater) or bloater.is_dead(), "")
	_check("savrulma: hızlıyken 2 hasar", fast and _damage_events.size() > 0 and _damage_events[0] == 2,
			"hızlı=%s hasar=%s" % [fast, str(_damage_events)])
	_check("savrulma: sallanma sürüyor", _player.is_swinging(), "")
	await _frames(20)
	_player.invuln_timer = 0.0


# ---------------------------------------------------------------- Can

func _test_contact_damage() -> void:
	_load_room(COMBAT_ROOM)
	await _frames(5)
	var crawler := _nearest(RotCrawler, Vector3(6.0, 0.0, 0.0)) as RotCrawler
	crawler.walk_speed = 0.0
	crawler.global_position = Vector3(6.0, 0.1, 0.0)
	_teleport(Vector3(5.6, 0.05, 0.0), Vector3.ZERO)
	await _frames(3)
	_check("temas: Sürüngen 1 yaprak alıyor", GameState.leaves == GameState.max_leaves - 1,
			"yaprak=%d" % GameState.leaves)
	_check("temas: geri itilme (HURT, sola)", _player.state == Player.State.HURT and _player.velocity.x < 0.0,
			"state=%s vx=%.2f" % [Player.State.keys()[_player.state], _player.velocity.x])
	_check("temas: HUD yaprakları güncel", (_level.get("game_hud") as GameHud).get_filled_count() == GameState.leaves, "")
	_teleport(Vector3(5.6, 0.05, 0.0), Vector3.ZERO)
	await _frames(10)
	_check("dokunulmazlık: 0.8 sn içinde ikinci hasar yok", GameState.leaves == GameState.max_leaves - 1,
			"yaprak=%d" % GameState.leaves)
	await _frames(int(_player.tuning.invuln_time * 60.0) + 5)
	_teleport(Vector3(5.6, 0.05, 0.0), Vector3.ZERO)
	await _frames(3)
	_check("dokunulmazlık bitince tekrar hasar", GameState.leaves == GameState.max_leaves - 2,
			"yaprak=%d" % GameState.leaves)


func _test_fall_damage() -> void:
	_load_room(1)
	await _frames(20)
	var before := GameState.leaves
	_teleport(Vector3(10.0, -20.0, 0.0), Vector3.ZERO)
	await _frames(3)
	_check("düşüş: güvenli noktaya dönüp 1 yaprak kaybediyor",
			GameState.leaves == before - _player.tuning.fall_damage and _player.global_position.y > -15.0,
			"yaprak=%d→%d" % [before, GameState.leaves])


func _test_death_restart() -> void:
	_load_room(1)
	await _frames(20)
	_teleport(Vector3(-2.0, 0.05, 0.0), Vector3.ZERO)
	GameState.leaves = 1
	_player.take_damage(1, _player.global_position + Vector3.RIGHT)
	await _frames(2)
	_check("ölüm: can 0 → DEAD", _player.is_dead(), "state=%s" % Player.State.keys()[_player.state])
	var shell_delay: float = _level.get("death_restart_delay")
	await _frames(int(shell_delay * 60.0) + 10)
	var room := _level.get("room") as GreyboxRoom
	_check("ölüm: oda başından tam canla", GameState.leaves == GameState.max_leaves \
			and not _player.is_dead() and _player.global_position.distance_to(room.spawn_point) < 1.0,
			"yaprak=%d konum=%s" % [GameState.leaves, str(_player.global_position)])


func _test_spore_cloud() -> void:
	# Yakından vurunca bulut hasar verir
	_load_room(COMBAT_ROOM)
	await _frames(5)
	_remove_crawlers()
	var gate := _nearest(SporeBloater, Vector3(38.5, 3.8, 0.0)) as SporeBloater
	gate.global_position = Vector3(-2.0, 0.8, 0.0)
	gate.home_position = gate.global_position
	_teleport(Vector3(-3.3, 0.05, 0.0), Vector3.ZERO)
	_player.facing = Vector3.RIGHT
	await _frames(3)
	var before := GameState.leaves
	await _press(&"attack", 3)
	await _frames(40)
	_check("spor bulutu: yakından patlatınca hasar", GameState.leaves < before,
			"yaprak=%d→%d" % [before, GameState.leaves])

	# Uzaktan (kamçı menzilinin ucundan) vurunca güvenli
	_load_room(COMBAT_ROOM)
	await _frames(5)
	gate = _nearest(SporeBloater, Vector3(38.5, 3.8, 0.0)) as SporeBloater
	gate.global_position = Vector3(-1.8, 0.8, 0.0)
	gate.home_position = gate.global_position
	_remove_crawlers()
	_teleport(Vector3(-4.0, 0.05, 0.0), Vector3.ZERO)
	_player.facing = Vector3.RIGHT
	await _frames(3)
	before = GameState.leaves
	await _press(&"attack", 3)
	await _frames(40)
	var gate_dead := not is_instance_valid(gate) or gate.is_dead()
	_check("spor bulutu: uzaktan vurmak güvenli", gate_dead and GameState.leaves == before,
			"öldü=%s yaprak=%d→%d" % [gate_dead, before, GameState.leaves])


# ---------------------------------------------------------------- Bot

func _test_bot_combat_room() -> void:
	_load_room(COMBAT_ROOM)
	await _frames(5)
	var room := _level.get("room") as GreyboxRoom
	var deaths: Array[int] = [0]
	var on_death := func() -> void: deaths[0] += 1
	EventBus.player_died.connect(on_death)
	var reached := false
	for i in int(MAX_ROOM_SECONDS * 60.0):
		_bot_step()
		await _frames(1)
		if OS.has_environment("BOT_DEBUG") and i % 20 == 0:
			print("  [bot] f=%d st=%s pos=(%.2f, %.2f) v=(%.2f, %.2f) can=%d" % [i,
					Player.State.keys()[_player.state], _player.global_position.x,
					_player.global_position.y, _player.velocity.x, _player.velocity.y, GameState.leaves])
		room = _level.get("room") as GreyboxRoom
		if room.goal != null and room.goal.is_reached():
			reached = true
			break
	EventBus.player_died.disconnect(on_death)
	_release_all()
	var hud := _level.get("hud") as DebugHud
	_check("bot: 'Çürük Yuvası' bitiyor", reached, "süre=%.2f sn ölüm=%d can=%d konum=(%.1f, %.1f)" % [
			hud.room_time, deaths[0], GameState.leaves, _player.global_position.x, _player.global_position.y])


## Savaş botu: sağa yürür, önündeki düşmana kamçı sallar, kenarda zıplar, sallanırken
## pompalar ve Şişkin yakınsa Savrulma Saldırısı yapar; yüksek çıkıntı önünde sabit
## Şişkin varsa ona doğru zıplayıp üstündeyken aşağı vurur (pogo).
func _bot_step() -> void:
	if _bot_jump_frames > 0:
		_bot_jump_frames -= 1
		if _bot_jump_frames == 0:
			Input.action_release(&"jump")
	if _bot_attack_frames > 0:
		_bot_attack_frames -= 1
		if _bot_attack_frames == 0:
			Input.action_release(&"attack")
	Input.action_release(&"move_down")
	var pos := _player.global_position
	var target := _nearest_live_enemy()
	match _player.state:
		Player.State.GROUND:
			_hold_right(true)
			if target != null:
				var d := target.global_position - _player.get_body_center()
				if target is RotCrawler and d.x > 0.3 and d.x < 2.4 and absf(d.y) < 1.2:
					# İnsan gibi: dur ve vur
					Input.action_release(&"move_right")
					_bot_attack()
			if not _floor_ahead(0.7) or _player.is_on_wall():
				_bot_jump()
		Player.State.AIR:
			_hold_right(true)
			if target is SporeBloater:
				var d := target.global_position - pos
				if d.x > -0.6 and d.x < 1.3 and d.y < 0.2 and d.y > -2.0:
					Input.action_press(&"move_down")
					_bot_attack()
		Player.State.SWING:
			var w := _player.get_swing_omega()
			_hold_right(w >= 0.0)
			if target is SporeBloater and target.global_position.distance_to(_player.get_body_center()) < 2.0:
				_bot_attack()
			if rad_to_deg(_player.get_swing_angle()) > 40.0 and w > 0.0:
				_bot_jump()
		_:
			_release_all()


func _bot_jump() -> void:
	if _bot_jump_frames > 0:
		return
	Input.action_press(&"jump")
	_bot_jump_frames = 12


func _bot_attack() -> void:
	if _bot_attack_frames > 0:
		return
	Input.action_press(&"attack")
	_bot_attack_frames = 3


func _hold_right(right: bool) -> void:
	Input.action_press(&"move_right" if right else &"move_left")
	Input.action_release(&"move_left" if right else &"move_right")


func _nearest_live_enemy() -> Enemy:
	var best: Enemy = null
	var best_d := 6.0
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e == null or e.is_dead():
			continue
		var dx := e.global_position.x - _player.global_position.x
		if dx < -1.0:
			continue
		var d := e.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _floor_ahead(distance: float) -> bool:
	var space := _player.get_world_3d().direct_space_state
	var from := _player.global_position + Vector3(distance, 0.5, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.8, Layers.WORLD)
	return not space.intersect_ray(q).is_empty()


# ---------------------------------------------------------------- Yardımcılar

func _load_room(index: int) -> void:
	_release_all()
	_level.call("load_room", index)


func _nearest(type: Variant, at: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for c: Node in (_level.get("room") as Node).get_children():
		if is_instance_of(c, type):
			var n := c as Node3D
			var d := n.global_position.distance_to(at)
			if d < best_d:
				best_d = d
				best = n
	return best


func _remove_crawlers() -> void:
	for c: Node in (_level.get("room") as Node).get_children():
		if c is RotCrawler:
			c.get_parent().remove_child(c)
			c.queue_free()


func _count_group(group: StringName) -> int:
	return get_tree().get_nodes_in_group(group).size()


func _wait_attack_end() -> void:
	for i in 60:
		if not _player.combat.is_attacking():
			return
		await _frames(1)


func _press(action: StringName, hold: int) -> void:
	Input.action_press(action)
	await _frames(hold)
	Input.action_release(action)


func _release_all() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"attack"]:
		Input.action_release(a)
	_bot_jump_frames = 0
	_bot_attack_frames = 0


func _teleport(pos: Vector3, vel: Vector3) -> void:
	_player.global_position = pos
	_player.velocity = vel
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
