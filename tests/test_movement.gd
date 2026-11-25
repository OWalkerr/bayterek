extends Node
## Hareket + sallanma + kamera modu duman testi (headless).
## Çalıştır: godot --headless --path . res://tests/test_movement.tscn
## Çıktıda [TEST] satırları; başarısızlıkta çıkış kodu 1.

var _failures: int = 0
var _level: Node3D
var _player: Player


func _ready() -> void:
	_level = load("res://scenes/main/main.tscn").instantiate() as Node3D
	add_child(_level)
	_player = _level.get("player") as Player
	_run.call_deferred()


func _run() -> void:
	# 1) Yere iniş
	await _frames(90)
	_check("yere iniyor", _player.is_on_floor(), "y=%.2f" % _player.global_position.y)

	# 2) Sağa koşma
	var start_x := _player.global_position.x
	Input.action_press(&"move_right")
	await _frames(60)
	Input.action_release(&"move_right")
	_check("sağa koşuyor", _player.global_position.x - start_x > 3.0,
			"dx=%.2f" % (_player.global_position.x - start_x))

	# 3) Zıplama
	await _frames(30)
	Input.action_press(&"jump")
	await _frames(1)
	Input.action_release(&"jump")
	await _frames(5)
	_check("zıplıyor", _player.velocity.y > 1.0 and not _player.is_on_floor(),
			"vy=%.2f" % _player.velocity.y)
	await _frames(90)

	# 4) Sarmaşığa tutunma (çukur üstü, 1. sarmaşık)
	_teleport(Vector3(10.6, 2.55, 0.0), Vector3(7.0, 0.0, 0.0))
	await _frames(3)
	_check("sarmaşığa tutunuyor", _player.state == Player.State.SWING,
			"state=%s" % Player.State.keys()[_player.state])

	# 5) Pompalayıp bırakma
	Input.action_press(&"move_right")
	await _frames(40)
	var swing_ok := _player.state == Player.State.SWING
	Input.action_press(&"jump")
	await _frames(1)
	Input.action_release(&"jump")
	await _frames(2)
	Input.action_release(&"move_right")
	_check("salınırken kalıyor", swing_ok, "")
	_check("zıplayarak bırakıyor", _player.state == Player.State.AIR and _player.velocity.length() > 4.0,
			"state=%s v=%.2f" % [Player.State.keys()[_player.state], _player.velocity.length()])
	await _frames(150)

	# 6) Mağara: kamera DEPTH, ileri hareket -Z
	_teleport(Vector3(26.0, 0.3, 0.0), Vector3.ZERO)
	await _frames(10)
	_check("mağarada kamera DEPTH", not CameraDirector.is_side_mode(), "mode=%d" % CameraDirector.mode)
	Input.action_press(&"move_up")
	await _frames(60)
	Input.action_release(&"move_up")
	_check("mağarada derinliğe yürüyor", _player.global_position.z < -3.0,
			"z=%.2f" % _player.global_position.z)

	# 7) Mağaradan çıkış: SIDE + raya dönüş
	_teleport(Vector3(40.0, 0.3, -1.5), Vector3.ZERO)
	await _frames(60)
	_check("dışarıda kamera SIDE", CameraDirector.is_side_mode(), "mode=%d" % CameraDirector.mode)
	_check("raya geri çekiliyor", absf(_player.global_position.z) < 0.1,
			"z=%.3f" % _player.global_position.z)

	# 8) Düşüşte geri dönüş
	_teleport(Vector3(13.0, -20.0, 0.0), Vector3.ZERO)
	await _frames(3)
	_check("düşünce güvenli noktaya dönüyor", _player.global_position.y > -15.0,
			"y=%.2f" % _player.global_position.y)

	print("[TEST] bitti — başarısız: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


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
