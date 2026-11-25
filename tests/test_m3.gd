extends Node
## M3 "kamera & derinlik" testleri (headless):
##  Phantom Camera arka ucu, mod geçişi (konum/FOV tween), geçiş yavaşlaması, girdi sürekliliği,
##  SideRail dönüşü (arka koridor), oda sınırları, look-ahead, ölü bölge, düşüşte dikey odak,
##  bot ile "Yankı Mağarası" (yan → derinlik → arka katman → hedef).
## Çalıştır: godot --headless --fixed-fps 60 --path . res://tests/test_m3.tscn
## Yedek arka uçla: BAYTEREK_CAMERA_BACKEND=rig godot ... res://tests/test_m3.tscn

const CAVE_ROOM: int = 5
const MAX_ROOM_SECONDS: float = 60.0

var _failures: int = 0
var _level: Node3D
var _player: Player
var _rig: CameraRig
var _bot_jump_frames: int = 0


func _ready() -> void:
	_level = load("res://scenes/main/main.tscn").instantiate() as Node3D
	add_child(_level)
	_player = _level.get("player") as Player
	_rig = _level.get("rig") as CameraRig
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	var want_phantom := OS.get_environment("BAYTEREK_CAMERA_BACKEND") != "rig"
	_check("arka uç: %s" % ("Phantom Camera" if want_phantom else "yerleşik blend"),
			_rig.is_phantom() == want_phantom, "")
	if not OS.has_environment("BOT_ONLY"):
		await _test_transition()
		await _test_input_continuity()
		await _test_side_rail()
		await _test_bounds()
		await _test_lookahead()
		await _test_dead_zone()
		await _test_fall_focus()
	await _test_bot_cave()
	print("[TEST] bitti — başarısız: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_transition() -> void:
	_load_room(0)
	await _frames(10)
	_teleport(Vector3(26.0, 0.3, 0.0))
	await _frames(4)
	_check("geçiş: mağarada DEPTH", not CameraDirector.is_side_mode(), "")
	_check("geçiş: yavaşlama 0.85x", is_equal_approx(Engine.time_scale, CameraDirector.transition_slowmo_scale),
			"ts=%.2f" % Engine.time_scale)
	await _frames(30)
	_check("geçiş: yavaşlama bitti", is_equal_approx(Engine.time_scale, 1.0), "ts=%.2f" % Engine.time_scale)
	await _frames(70)
	var cam := _rig.camera
	var goal := _rig.get_goal_transform()
	_check("geçiş: kamera DEPTH hedefinde", cam.global_position.distance_to(goal.origin) < 0.3,
			"fark=%.2f m" % cam.global_position.distance_to(goal.origin))
	_check("geçiş: FOV 60°", absf(cam.fov - _rig.depth_fov) < 0.5, "fov=%.1f" % cam.fov)
	_teleport(Vector3(40.0, 0.3, -1.5))
	await _frames(90)
	_check("geçiş: dışarıda SIDE + FOV 40°", CameraDirector.is_side_mode() and absf(cam.fov - _rig.side_fov) < 0.5,
			"fov=%.1f" % cam.fov)


func _test_input_continuity() -> void:
	_load_room(0)
	await _frames(10)
	_teleport(Vector3(-6.0, 0.05, 0.0))
	await _frames(5)
	# Sağa basılıyken kamera 90° dönük DEPTH'e geçer: tuş bırakılana kadar +X sürmeli
	Input.action_press(&"move_right")
	await _frames(10)
	CameraDirector.set_mode(CameraRig.Mode.DEPTH, 1.0, 90.0)
	await _frames(20)
	_check("süreklilik: geçişte tutulan tuş eski anlamında (+X)",
			_player.velocity.x > 5.0 and absf(_player.velocity.z) < 1.0 and CameraDirector.is_input_continuity_active(),
			"v=(%.1f, %.1f)" % [_player.velocity.x, _player.velocity.z])
	Input.action_release(&"move_right")
	await _frames(3)
	_check("süreklilik: bırakınca biter", not CameraDirector.is_input_continuity_active(), "")
	Input.action_press(&"move_right")
	await _frames(20)
	Input.action_release(&"move_right")
	# 90° yaw: kamera +X'te, -X'e bakar → ekran sağı = -Z
	_check("süreklilik: yeni basışta yeni eksen (sağ = -Z)", _player.velocity.z < -4.0,
			"v=(%.1f, %.1f)" % [_player.velocity.x, _player.velocity.z])
	CameraDirector.reset_to_side()
	await _frames(5)


func _test_side_rail() -> void:
	_load_room(CAVE_ROOM)
	await _frames(10)
	_teleport(Vector3(27.0, 0.1, -24.0))
	await _frames(10)
	_check("ray: mağara içinde DEPTH", not CameraDirector.is_side_mode(), "")
	Input.action_press(&"move_right")
	for i in 90:
		await _frames(1)
		if CameraDirector.is_side_mode():
			break
	await _frames(30)
	Input.action_release(&"move_right")
	_check("ray: tünelden çıkınca SIDE", CameraDirector.is_side_mode(), "")
	_check("ray: arka koridor rayı seçildi (Z=-24)", is_equal_approx(_player.rail_z, -24.0), "rail=%.1f" % _player.rail_z)
	_check("ray: oyuncu arka katmanda kalıyor", absf(_player.global_position.z + 24.0) < 0.2,
			"z=%.2f" % _player.global_position.z)
	# Ön katmana dönüş: Kök Ağzı mağarasından çıkınca Z=0'a 0.4 sn'de çekilir
	_load_room(0)
	await _frames(10)
	_teleport(Vector3(26.0, 0.3, -6.0))
	await _frames(10)
	_teleport(Vector3(32.0, 0.3, -1.8))
	await _frames(int(0.4 * 60.0) + 2)
	_check("ray: varsayılan raya (Z=0) ~0.4 sn'de dönüş", absf(_player.global_position.z) < 0.1,
			"z=%.3f" % _player.global_position.z)


func _test_bounds() -> void:
	_load_room(1)
	await _frames(10)
	_teleport(Vector3(-9.3, 0.05, 0.0))
	await _frames(60)
	var b := _rig.bounds
	var goal := _rig.get_goal_transform()
	var half_h := _rig.side_distance * tan(deg_to_rad(_rig.side_fov) * 0.5)
	var vs := _rig.get_viewport().get_visible_rect().size
	var half_w := half_h * (vs.x / vs.y)
	_check("sınır: kamera sol duvarı aşmıyor", goal.origin.x >= b.position.x + half_w - 0.05,
			"kamera x=%.2f sınır=%.2f" % [goal.origin.x, b.position.x + half_w])
	_check("sınır: oyuncu kameranın solunda (kırpıldı)", goal.origin.x > _player.global_position.x + 1.0, "")


func _test_lookahead() -> void:
	_load_room(4)
	await _frames(10)
	_teleport(Vector3(-4.0, 0.05, 0.0))
	await _frames(5)
	Input.action_press(&"move_right")
	await _frames(45)
	var right_la := _rig.get_lookahead()
	Input.action_release(&"move_right")
	Input.action_press(&"move_left")
	await _frames(70)
	var left_la := _rig.get_lookahead()
	Input.action_release(&"move_left")
	_check("look-ahead: sağa koşunca ileri kayıyor", right_la > 1.5, "la=%.2f" % right_la)
	_check("look-ahead: sola koşunca geri kayıyor", left_la < -1.5, "la=%.2f" % left_la)


func _test_dead_zone() -> void:
	_load_room(4)
	await _frames(10)
	_teleport(Vector3(-4.0, 0.05, 0.0))
	await _frames(90)
	var focus_before := _rig.get_focus()
	# Odak hedefi, karakterin 0.75 m gerisinde; geriye 0.5 m kıpırdamak kutunun içinde kalır
	_teleport(Vector3(-4.5, 0.05, 0.0))
	await _frames(30)
	var moved := _rig.get_focus().distance_to(focus_before)
	_check("ölü bölge: 0.5 m kıpırdama odağı oynatmıyor", moved < 0.05, "odak kayması=%.3f" % moved)
	_teleport(Vector3(-1.0, 0.05, 0.0))
	await _frames(60)
	moved = _rig.get_focus().x - focus_before.x
	_check("ölü bölge: kutudan çıkınca odak izliyor", moved > 1.5, "odak kayması=%.2f" % moved)


func _test_fall_focus() -> void:
	_load_room(2)
	await _frames(10)
	var normal := _rig.get_look_height()
	_teleport(Vector3(-3.0, 26.0, 0.0))
	await _frames(50)
	var falling := _rig.get_look_height()
	_check("dikey odak: normalde karakter alt üçte birde (bakış +3 m)", normal > 2.5, "h=%.2f" % normal)
	_check("dikey odak: düşerken alt yarıya kayıyor", falling < 1.5 and _player.velocity.y < -8.0,
			"h=%.2f vy=%.1f" % [falling, _player.velocity.y])
	await _frames(60)


# ---------------------------------------------------------------- Bot (Yankı Mağarası)

## Yol noktaları: [hedef (x, z), sonraki noktaya geçiş koşulu]. Derinlikte girdi, kameranın
## eksenlerine göre hesaplanır (insan oyuncunun gördüğü gibi).
func _test_bot_cave() -> void:
	_load_room(CAVE_ROOM)
	await _frames(10)
	var room := _level.get("room") as GreyboxRoom
	var waypoints: Array[Vector3] = [
		Vector3(15.0, 0.0, 0.0),     # ön zeminde mağara ağzına
		Vector3(15.0, 0.0, -9.6),    # derinliğe, uçurum kenarı → zıpla
		Vector3(15.0, 0.0, -22.0),   # sarmaşık sonrası arka zemin
		Vector3(26.0, 0.0, -24.0),   # tünel ağzı
		Vector3(70.0, 0.0, -24.0),   # arka koridor boyunca hedefe
	]
	var wp := 0
	var reached := false
	var respawns: Array[int] = [0]
	var on_respawn := func(_p: Vector3) -> void: respawns[0] += 1
	EventBus.player_respawned.connect(on_respawn)
	for i in int(MAX_ROOM_SECONDS * 60.0):
		if _bot_jump_frames > 0:
			_bot_jump_frames -= 1
			if _bot_jump_frames == 0:
				Input.action_release(&"jump")
		var pos := _player.global_position
		var target := waypoints[wp]
		var to := Vector3(target.x - pos.x, 0.0, target.z - pos.z)
		if wp < waypoints.size() - 1 and to.length() < 0.6:
			wp += 1
			continue
		# Düştüyse (güvenli noktaya döndü) uçurum öncesine dön
		if wp >= 2 and pos.z > -10.0 and pos.x < 18.0:
			wp = 1
		match _player.state:
			Player.State.SWING:
				_bot_swing(Vector3(0.0, 0.0, -1.0))
			_:
				_steer(to.normalized())
				if wp == 1 and pos.z < -9.3 and _player.is_on_floor():
					_bot_jump()
				elif _player.is_on_floor() and (_player.is_on_wall() or not _floor_ahead(to.normalized())):
					_bot_jump()
		await _frames(1)
		if OS.has_environment("BOT_DEBUG") and i % 20 == 0:
			print("  [bot] f=%d wp=%d st=%s pos=(%.2f, %.2f, %.2f) cam=%s" % [i, wp,
					Player.State.keys()[_player.state], pos.x, pos.y, pos.z,
					"SIDE" if CameraDirector.is_side_mode() else "DEPTH"])
		room = _level.get("room") as GreyboxRoom
		if room.goal != null and room.goal.is_reached():
			reached = true
			break
	EventBus.player_respawned.disconnect(on_respawn)
	_release_all()
	var hud := _level.get("hud") as DebugHud
	_check("bot: 'Yankı Mağarası' bitiyor (yan → derinlik → arka katman)", reached,
			"süre=%.2f sn düşüş=%d konum=%s" % [hud.room_time, respawns[0], str(_player.global_position)])


## Sallanırken: salınım yönünde pompala; hedef yöne doğru ileri kolda > 40° iken bırak.
func _bot_swing(target_dir: Vector3) -> void:
	var axis := _player.swing_state.axis
	var far_sign := signf(axis.dot(target_dir))
	if far_sign == 0.0:
		far_sign = 1.0
	var omega := _player.get_swing_omega()
	_steer(axis * signf(omega) if absf(omega) > 0.05 else axis * far_sign)
	var a := rad_to_deg(_player.get_swing_angle()) * far_sign
	if a > 40.0 and omega * far_sign > 0.0:
		_bot_jump()


## Dünya yönünü kameranın eksenlerine göre analog girdiye çevirir.
func _steer(world_dir: Vector3) -> void:
	var b := CameraDirector.get_input_basis()
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	var forward := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	var ix := world_dir.dot(right)
	var iy := world_dir.dot(forward)
	if CameraDirector.is_side_mode():
		ix = signf(world_dir.x) if absf(world_dir.x) > 0.05 else 0.0
		iy = 0.0
	_axis(&"move_right", &"move_left", ix)
	_axis(&"move_up", &"move_down", iy)


func _axis(pos_action: StringName, neg_action: StringName, value: float) -> void:
	if value > 0.1:
		Input.action_press(pos_action, clampf(value, 0.0, 1.0))
		Input.action_release(neg_action)
	elif value < -0.1:
		Input.action_press(neg_action, clampf(-value, 0.0, 1.0))
		Input.action_release(pos_action)
	else:
		Input.action_release(pos_action)
		Input.action_release(neg_action)


func _bot_jump() -> void:
	if _bot_jump_frames > 0:
		return
	Input.action_press(&"jump")
	_bot_jump_frames = 26   # tam zıplama (değişken zıplama kesmesi olmasın)


func _floor_ahead(dir: Vector3) -> bool:
	var space := _player.get_world_3d().direct_space_state
	var from := _player.global_position + dir * 0.7 + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.8, Layers.WORLD)
	return not space.intersect_ray(q).is_empty()


# ---------------------------------------------------------------- Yardımcılar

func _load_room(index: int) -> void:
	_release_all()
	_level.call("load_room", index)


func _release_all() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"attack"]:
		Input.action_release(a)
	_bot_jump_frames = 0


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
