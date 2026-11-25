extends Node
## M1 "hareket hissi" testleri (headless):
##  - coyote time, jump buffer
##  - tırmanma sarmaşığı (tutun, tırman, yana zıpla)
##  - çürük sarmaşık (kopar, yeniden büyür)
##  - mükemmel bırakma (pencere + hız bonusu + EventBus)
##  - bot ile 3 test odasının baştan sona oynanması (yalnızca hareket)
## Çalıştır: godot --headless --path . res://tests/test_m1.tscn

const MAX_ROOM_SECONDS: float = 40.0

var _failures: int = 0
var _level: Node3D
var _player: Player
var _perfect_events: int = 0
var _broken_events: int = 0

# Bot durumu
var _bot_dir: float = 1.0
var _bot_climb_dirs: Dictionary = {}     # ClimbVine -> yön
var _bot_jump_frames: int = 0
## Skill kuralı: açı > 40° ve ω > 0 iken bırak. BOT_ANGLE ortam değişkeniyle taranabilir.
var _bot_release_angle: float = 40.0


func _ready() -> void:
	_level = load("res://scenes/main/main.tscn").instantiate() as Node3D
	add_child(_level)
	_player = _level.get("player") as Player
	EventBus.vine_released.connect(func(_a: Node3D, p: bool) -> void:
		if p:
			_perfect_events += 1)
	EventBus.vine_broken.connect(func(_a: Node3D) -> void: _broken_events += 1)
	if OS.has_environment("BOT_ANGLE"):
		_bot_release_angle = float(OS.get_environment("BOT_ANGLE"))
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	if not OS.has_environment("BOT_ONLY"):
		await _test_coyote()
		await _test_buffer()
		await _test_climb()
		await _test_rotten()
		await _test_perfect_release()
	if not OS.has_environment("BOT_ROOM") or OS.get_environment("BOT_ROOM") == "1":
		await _test_bot_room(1)
	await _test_bot_room(2)
	await _test_bot_room(3)
	print("[TEST] bitti — başarısız: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- Birim davranışlar

func _test_coyote() -> void:
	_load_room(1)
	# Başlangıç platformu x ≤ 2; kenara doğru koş, düştükten kısa süre sonra zıpla
	_teleport(Vector3(0.5, 0.1, 0.0), Vector3(7.0, 0.0, 0.0))
	Input.action_press(&"move_right")
	var left_floor := false
	for i in 60:
		await _frames(1)
		if not _player.is_on_floor() and _player.global_position.x > 2.0:
			left_floor = true
			break
	await _frames(4)   # ~0.067 sn < coyote 0.12
	await _tap_jump(3)
	Input.action_release(&"move_right")
	_check("coyote: kenardan sonra zıplama", left_floor and _player.velocity.y > 5.0,
			"vy=%.2f" % _player.velocity.y)

	# Coyote süresi geçtikten sonra zıplama olmamalı
	_load_room(1)
	_teleport(Vector3(0.5, 0.1, 0.0), Vector3(7.0, 0.0, 0.0))
	Input.action_press(&"move_right")
	for i in 60:
		await _frames(1)
		if not _player.is_on_floor() and _player.global_position.x > 2.0:
			break
	await _frames(12)  # 0.2 sn > coyote
	await _tap_jump()
	await _frames(2)
	Input.action_release(&"move_right")
	_check("coyote: süre dolunca zıplama yok", _player.velocity.y < 0.0,
			"vy=%.2f" % _player.velocity.y)


func _test_buffer() -> void:
	_load_room(1)
	# Zeminin hemen üstünden düşerken erken bas → yere değince zıpla
	_teleport(Vector3(-4.0, 0.6, 0.0), Vector3(0.0, -6.0, 0.0))
	await _frames(1)
	Input.action_press(&"jump")
	await _frames(1)
	var jumped := false
	for i in 20:
		await _frames(1)
		if _player.velocity.y > 5.0:
			jumped = true
			break
	Input.action_release(&"jump")
	_check("jump buffer: yere değmeden basılan zıplama", jumped, "vy=%.2f" % _player.velocity.y)


func _test_climb() -> void:
	_load_room(2)
	await _frames(5)
	# A sarmaşığı x=0, y 1→8. Havada yanına bırak.
	_teleport(Vector3(0.4, 2.0, 0.0), Vector3.ZERO)
	await _frames(3)
	_check("tırmanma: sarmaşığa tutunuyor", _player.is_climbing(),
			"state=%s" % Player.State.keys()[_player.state])
	var y0 := _player.global_position.y
	Input.action_press(&"move_up")
	await _frames(60)
	Input.action_release(&"move_up")
	var climbed := _player.global_position.y - y0
	_check("tırmanma: yukarı çıkıyor", climbed > 2.5 and _player.is_climbing(), "dy=%.2f" % climbed)
	_check("tırmanma: sarmaşığa hizalı", absf(_player.global_position.x) < 0.1,
			"x=%.2f" % _player.global_position.x)
	# Yana zıpla → B sarmaşığına (x=4.5) tutun
	Input.action_press(&"move_right")
	await _tap_jump(10)
	var vx := _player.velocity.x
	_check("tırmanma: yana zıplıyor", _player.state == Player.State.AIR and vx > 4.0, "vx=%.2f" % vx)
	var grabbed_b := false
	for i in 60:
		await _frames(1)
		var v := _player.get_current_climb_vine()
		if v != null and v.global_position.x > 4.0:
			grabbed_b = true
			break
	Input.action_release(&"move_right")
	_check("tırmanma: karşı sarmaşığa geçiyor", grabbed_b, "x=%.2f" % _player.global_position.x)
	# Aşağı inip yere değince bırakma
	_load_room(2)
	_teleport(Vector3(0.3, 1.0, 0.0), Vector3.ZERO)
	await _frames(3)
	Input.action_press(&"move_down")
	await _frames(60)
	Input.action_release(&"move_down")
	_check("tırmanma: aşağıda bırakıyor", not _player.is_climbing(),
			"state=%s" % Player.State.keys()[_player.state])


func _test_rotten() -> void:
	_load_room(3)
	await _frames(5)
	var rotten := _first_of(RottenVine) as RottenVine
	_teleport(rotten.global_position + Vector3(0.3, -2.5 - Player.HAND_HEIGHT, 0.0), Vector3.ZERO)
	await _frames(3)
	_check("çürük: tutunuyor", _player.is_swinging() and _player.get_current_anchor() == rotten, "")
	var before := _broken_events
	await _frames(int(rotten.break_time * 60.0) + 10)
	_check("çürük: 1.5 sn sonra kopuyor", not rotten.enabled and _broken_events == before + 1,
			"enabled=%s" % rotten.enabled)
	_check("çürük: oyuncu düşüyor", _player.state == Player.State.AIR,
			"state=%s" % Player.State.keys()[_player.state])
	await _frames(int(rotten.respawn_time * 60.0) + 10)
	_check("çürük: yeniden büyüyor", rotten.enabled and rotten.visible, "")


func _test_perfect_release() -> void:
	_load_room(1)
	await _frames(5)
	var anchor := _first_of(VineAnchor) as VineAnchor
	# Sağa savrulurken sarmaşığın altından geçir → pompala → pencerede bırak
	_teleport(anchor.global_position + Vector3(-1.2, -2.6 - Player.HAND_HEIGHT, 0.0), Vector3(6.0, 0.0, 0.0))
	await _frames(2)
	_check("mükemmel: sallanma başladı", _player.is_swinging(), "")
	Input.action_press(&"move_right")
	var in_window := false
	for i in 240:
		await _frames(1)
		if _player.is_in_perfect_window():
			in_window = true
			break
	var before := _perfect_events
	var speed_before := absf(_player.get_swing_omega()) * _player.get_rope_length()
	await _tap_jump()
	Input.action_release(&"move_right")
	_check("mükemmel: pencereye giriliyor", in_window,
			"θ=%.0f°" % rad_to_deg(_player.get_swing_angle()))
	_check("mükemmel: bırakma işaretleniyor", _player.last_release_perfect and _perfect_events == before + 1, "")
	var expected := speed_before * _player.tuning.release_boost * _player.tuning.perfect_release_bonus
	var horizontal := Vector2(_player.velocity.x, _player.velocity.y - _player.tuning.release_jump_bonus).length()
	_check("mükemmel: hız bonusu uygulanıyor", horizontal > expected * 0.85,
			"v=%.2f beklenen≈%.2f" % [horizontal, expected])
	var sparks := 0
	for c: Node in _level.get_children():
		if c is ReleaseSpark:
			sparks += 1
	_check("mükemmel: ışıltı efekti", sparks > 0, "")
	await _frames(90)


# ---------------------------------------------------------------- Bot

func _test_bot_room(index: int) -> void:
	_load_room(index)
	await _frames(5)
	var room := _level.get("room") as GreyboxRoom
	_bot_dir = 1.0
	_bot_climb_dirs.clear()
	if index == 2:
		# Kuyu zikzak: A→B sağ, B→C sol, C→D sağ, D→sallanma sağ
		var vines := _all_of(ClimbVine)
		vines.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.y < b.global_position.y)
		var dirs := [1.0, -1.0, 1.0, 1.0]
		for i in vines.size():
			_bot_climb_dirs[vines[i]] = dirs[i]
	var respawns: Array[int] = [0]   # lambda yerelleri değerle yakalar → dizi
	var on_respawn := func(_p: Vector3) -> void: respawns[0] += 1
	EventBus.player_respawned.connect(on_respawn)
	var frames := int(MAX_ROOM_SECONDS * 60.0)
	var reached := false
	for i in frames:
		_bot_step()
		await _frames(1)
		if OS.has_environment("BOT_DEBUG") and i % 20 == 0:
			print("  [bot] f=%d st=%s pos=(%.2f, %.2f) v=(%.2f, %.2f) θ=%.0f ω=%.2f" % [i,
					Player.State.keys()[_player.state], _player.global_position.x,
					_player.global_position.y, _player.velocity.x, _player.velocity.y,
					rad_to_deg(_player.get_swing_angle()), _player.get_swing_omega()])
		if room.goal != null and room.goal.is_reached():
			reached = true
			break
	EventBus.player_respawned.disconnect(on_respawn)
	_release_all()
	var hud := _level.get("hud") as DebugHud
	var detail := "süre=%.2f sn düşüş=%d" % [hud.room_time, respawns[0]]
	if not reached:
		detail += " konum=(%.1f, %.1f)" % [_player.global_position.x, _player.global_position.y]
	_check("bot: '%s' odası bitiyor" % room.display_name, reached, detail)
	await _frames(10)


## Basit bot: yönü basılı tutar; zeminde kenara gelince zıplar; sallanırken
## açı > 40° ve ω yön ile aynıysa zıplar; tırmanırken tepeye çıkıp hedef yöne zıplar.
func _bot_step() -> void:
	if _bot_jump_frames > 0:
		_bot_jump_frames -= 1
		if _bot_jump_frames == 0:
			Input.action_release(&"jump")
	Input.action_release(&"move_up")
	match _player.state:
		Player.State.GROUND:
			_hold_dir(_bot_dir)
			if not _floor_ahead(0.7) or _climb_vine_ahead(1.2):
				_bot_press_jump()
		Player.State.AIR:
			_hold_dir(_bot_dir)
		Player.State.SWING:
			# Pompala: salınım yönünde bas (insan oyuncu gibi)
			var w := _player.get_swing_omega() * _bot_dir
			_hold_dir(_bot_dir if w >= 0.0 else -_bot_dir)
			var a := rad_to_deg(_player.get_swing_angle()) * _bot_dir
			if a > _bot_release_angle and w > 0.0:
				_bot_press_jump()
		Player.State.CLIMB:
			var vine := _player.get_current_climb_vine()
			var dir: float = _bot_climb_dirs.get(vine, _bot_dir)
			var hand_y := _player.global_position.y + Player.HAND_HEIGHT
			if hand_y < vine.get_top().y - Player.CLIMB_END_MARGIN - 0.05:
				_hold_dir(0.0)
				Input.action_press(&"move_up")
			else:
				_bot_dir = dir
				_hold_dir(dir)
				_bot_press_jump()


func _bot_press_jump() -> void:
	if _bot_jump_frames > 0:
		return
	Input.action_press(&"jump")
	_bot_jump_frames = 12


func _hold_dir(dir: float) -> void:
	if dir > 0.0:
		Input.action_press(&"move_right")
		Input.action_release(&"move_left")
	elif dir < 0.0:
		Input.action_press(&"move_left")
		Input.action_release(&"move_right")
	else:
		Input.action_release(&"move_left")
		Input.action_release(&"move_right")


func _floor_ahead(distance: float) -> bool:
	var space := _player.get_world_3d().direct_space_state
	var from := _player.global_position + Vector3(distance * _bot_dir, 0.5, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.5)
	q.exclude = [_player.get_rid()]
	return not space.intersect_ray(q).is_empty()


func _climb_vine_ahead(distance: float) -> bool:
	for node: Node in get_tree().get_nodes_in_group(ClimbVine.GROUP):
		var v := node as ClimbVine
		var dx := (v.global_position.x - _player.global_position.x) * _bot_dir
		if dx > 0.0 and dx < distance and v.get_bottom().y < _player.global_position.y + 3.0:
			return true
	return false


func _release_all() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"jump"]:
		Input.action_release(a)
	_bot_jump_frames = 0


# ---------------------------------------------------------------- Yardımcılar

func _load_room(index: int) -> void:
	_release_all()
	_level.call("load_room", index)


func _first_of(type: Variant) -> Node3D:
	var all := _all_of(type)
	all.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.x < b.global_position.x)
	return all[0] if not all.is_empty() else null


func _all_of(type: Variant) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var room := _level.get("room") as Node
	for c: Node in room.get_children():
		if is_instance_of(c, type):
			out.append(c as Node3D)
	return out


## Zıplamaya basar ve `hold` kare basılı tutar. Godot 4.6'da action_press bir sonraki
## fizik karesinde "just pressed" olur → en az 2 kare basılı tutulmalı.
func _tap_jump(hold: int = 3) -> void:
	Input.action_press(&"jump")
	await _frames(hold)
	Input.action_release(&"jump")


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
