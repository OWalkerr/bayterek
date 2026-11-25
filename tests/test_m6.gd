extends Node
## M6 "Boss: Kökyiyen" testleri (headless):
##  giriş (isim kartı, kapı kilidi, intro kilidi), çatlak uyarısı (≥ 0.4 sn, oyuncunun altında),
##  zayıf nokta yalnızca açıktayken vurulur, süpürme yerdekine vurur / havadakine vurmaz,
##  Faz 2 (Şişkin çağırma, tüm arena süpürmesi), Faz 3 kovalamaca (kuyuya geçiş, zemin çöker, ağız
##  yükselir, değerse hasar + fırlatma ama ölüm yok), final (kanca → kaya → yenilgi, ödüller, hikaye),
##  yenilmiş boss geri gelmez; BOT ile tam dövüş denemeleri (zorluk ölçümü).
## Çalıştır: godot --headless --fixed-fps 60 --path . res://tests/test_m6.tscn
## Deneme sayısı: TRIALS=5 (varsayılan 3)

const TEST_SLOT: int = 97
const ROOM: StringName = &"kokyiyen_ini"
const G: StringName = &"whip_grapple"

var _failures: int = 0
var _level: Node3D
var _player: Player
var _jf: int = 0
var _gf: int = 0
var _af: int = 0
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
	if _only("intro"):
		await _test_intro_and_cycle()
	if _only("phases"):
		await _test_phases_and_chase()
	if _only("bot"):
		await _test_bot_trials()
	GameState.delete_save()
	print("[TEST] bitti — başarısız: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- Mekanik

func _fresh_fight() -> Rooteater:
	GameState.reset()
	GameState.unlock_ability(G)
	GameState.autosave_enabled = false
	SceneRouter.enter_room_immediate(ROOM)
	await _frames(3)
	return (_room() as Node).get(&"boss") as Rooteater


func _test_intro_and_cycle() -> void:
	var boss := await _fresh_fight()
	_check("giriş: boss uykuda", boss != null and boss.phase == Rooteater.Phase.DORMANT, "")
	_teleport(Vector3(16.0, 0.05, -9.0))
	await _frames(3)
	var card := _level.get("boss_card") as BossCard
	_check("giriş: isim kartı 'KÖKYİYEN — Köklerin Açlığı'", card.is_showing() and card.get_text() == "KÖKYİYEN — Köklerin Açlığı", card.get_text())
	_check("giriş: kapı kilitlendi", not _room().get_door(&"west").enabled, "")
	_check("giriş: intro sırasında oyuncu kilitli", _player.state == Player.State.CINEMATIC, "")
	await _wait_until(func() -> bool: return boss.phase == Rooteater.Phase.ONE, 6.0)
	_check("giriş: Faz 1 başladı, oyuncu serbest", boss.phase == Rooteater.Phase.ONE and _player.state != Player.State.CINEMATIC, "")
	# Çatlak uyarısı
	await _wait_until(func() -> bool: return boss.is_telegraphing(), 6.0)
	var tell := boss.get_action_time_left()
	var crack_dist := Vector2(boss.get_crack_position().x - _player.global_position.x, boss.get_crack_position().z - _player.global_position.z).length()
	_check("çatlak: uyarı ≥ 0.4 sn", tell >= 0.4, "%.2f sn" % tell)
	_check("çatlak: oyuncunun altında", crack_dist < 1.5, "mesafe=%.2f" % crack_dist)
	var sac := boss.get_active_weak_point()
	var hit_hidden := sac.take_hit(2, _player.global_position, &"forward")
	_check("zayıf nokta: gömülüyken vurulamıyor", not hit_hidden and sac.hp == sac.max_hp, "")
	# Fırlama: çatlağın üstünde kalan oyuncu hasar alır
	var before := GameState.leaves
	await _wait_until(func() -> bool: return boss.is_exposed(), 4.0)
	_check("fırlama: çatlakta kalan hasar alıyor", GameState.leaves < before, "yaprak=%d→%d" % [before, GameState.leaves])
	_check("zayıf nokta: açıktayken görünür ve vurulabilir", sac.visible and sac.take_hit(1, _player.global_position, &"forward"), "")
	# Süpürme: yerdeki vurulur, havadaki vurulmaz
	_player.invuln_timer = 0.0
	await _wait_until(func() -> bool: return boss.is_sweeping(), 6.0)
	var body := boss.get_body_position()
	_teleport(body + Vector3(3.5, 0.05, 0.0))
	before = GameState.leaves
	await _frames(4)
	_check("süpürme: yerdeki oyuncuya vuruyor", GameState.leaves < before, "yaprak=%d→%d" % [before, GameState.leaves])
	# Havadaki: uyarının sonunda gerçekten zıpla
	await _wait_until(func() -> bool: return boss.is_sweep_telling(), 12.0)
	_player.invuln_timer = 0.0
	_teleport(boss.get_body_position() + Vector3(3.5, 0.05, 0.0))
	await _wait_until(func() -> bool: return boss.get_action_time_left() < 0.15, 2.0)
	before = GameState.leaves
	Input.action_press(&"jump")
	await _wait_until(func() -> bool: return boss.action == Rooteater.Action.BURROW, 2.0)
	Input.action_release(&"jump")
	_check("süpürme: zıplayan oyuncuya vurmuyor", GameState.leaves == before, "yaprak=%d→%d" % [before, GameState.leaves])


func _test_phases_and_chase() -> void:
	var boss := await _fresh_fight()
	_teleport(Vector3(16.0, 0.05, -9.0))
	await _wait_until(func() -> bool: return boss.phase == Rooteater.Phase.ONE, 6.0)
	_player.invuln_timer = 1000.0
	await _kill_sac(boss)
	_check("faz: kese 1 → Faz 2", boss.phase == Rooteater.Phase.TWO, "faz=%d" % boss.phase)
	await _wait_until(func() -> bool: return boss.cycles >= 1 and boss.action == Rooteater.Action.BURROWED, 15.0)
	await _frames(2)
	var bloaters := 0
	for c: Node in _room().get_children():
		if c is SporeBloater:
			bloaters += 1
	_check("Faz 2: Spor Şişkini çağırıyor", bloaters >= 1, "şişkin=%d" % bloaters)
	await _wait_until(func() -> bool: return boss.cycles >= 3 and boss.action == Rooteater.Action.BURROWED, 30.0)
	await _frames(2)
	var alive := 0
	for c: Node in _room().get_children():
		if c is SporeBloater and not (c as Enemy).is_dead():
			alive += 1
	_check("Faz 2: Şişkin sayısı sınırlı (≤ %d)" % boss.p2_max_bloaters, alive <= boss.p2_max_bloaters and alive >= 1, "şişkin=%d" % alive)
	_check("Faz 2: süpürme tüm arena", boss.current_sweep_radius() >= boss.arena_radius, "r=%.1f" % boss.current_sweep_radius())
	await _kill_sac(boss)
	_check("faz: kese 2 → kovalamaca", boss.phase == Rooteater.Phase.CHASE, "faz=%d" % boss.phase)
	await _wait_until(func() -> bool: return _player.global_position.x > 55.0 and not SceneRouter.is_faded(), 5.0)
	_check("kovalamaca: oyuncu kuyuya geçti, kamera yan mod", _player.global_position.x > 55.0 and CameraDirector.is_side_mode(),
			"konum=%s" % str(_player.global_position))
	await _wait_until(func() -> bool: return boss.maw.running, 4.0)
	_check("kovalamaca: ağız yükseliyor, zemin henüz duruyor (tırmanma payı)", boss.maw.running and is_instance_valid(boss.chase_floor), "")
	await _wait_until(func() -> bool: return not is_instance_valid(boss.chase_floor), 6.0)
	_check("kovalamaca: ağız zemine ulaşınca zemin çöküyor", not is_instance_valid(boss.chase_floor), "")
	_player.invuln_timer = 0.0
	GameState.leaves = 2
	await _wait_until(func() -> bool: return GameState.leaves < 2, 8.0)
	await _frames(2)
	_check("kovalamaca: ağız değince 1 yaprak + yukarı fırlatma, ölüm yok",
			GameState.leaves == 1 and _player.velocity.y > 5.0 and not _player.is_dead(), "yaprak=%d vy=%.1f" % [GameState.leaves, _player.velocity.y])
	# Final: tepe çıkıntısından kayaya kanca
	_player.invuln_timer = 1000.0
	_teleport(Vector3(66.5, 35.05, 0.0))
	await _frames(30)   # ağız darbesinin HURT süresi bitsin
	_check("final: kök kayası hedefleniyor", _player.grapple_target is RootRock, "")
	await _press(&"grapple", 3)
	await _wait_until(func() -> bool: return boss.phase == Rooteater.Phase.DEFEATED, 6.0)
	_check("final: kaya ağza → Kökyiyen yenildi", boss.phase == Rooteater.Phase.DEFEATED, "faz=%d" % boss.phase)
	await _wait_until(func() -> bool: return (_level.get("story_card") as StoryCard).is_playing(), 4.0)
	var story := _level.get("story_card") as StoryCard
	_check("ödül: bayrak + Kut parçası + tam can", GameState.get_flag("kokyiyen_ini/boss_defeated", false) \
			and GameState.kut_shards == 1 and GameState.leaves == GameState.max_leaves, "kut=%d yaprak=%d" % [GameState.kut_shards, GameState.leaves])
	_check("ödül: Kocabaş'ın mesajı (hikaye anı)", story.is_playing() and story.story_id == &"kocabas_first_message", "")
	_check("hikaye: oyuncu kilitli", _player.state == Player.State.CINEMATIC, "")
	for i in 20:
		story.advance()
		await _frames(2)
		if not story.is_playing():
			break
	_check("hikaye: bitince oyuncu serbest, kapı açık", not story.is_playing() and _player.state != Player.State.CINEMATIC \
			and _room().get_door(&"west").enabled, "")
	SceneRouter.enter_room_immediate(ROOM)
	await _frames(3)
	_check("yenilen boss geri gelmiyor", (_room() as Node).get(&"boss") == null, "")
	# Geliştirici seçici (7): boss yeniden dövüşülebilir, kanca verilir
	GameState.abilities.clear()
	_level.call(&"load_room", 7)
	await _frames(3)
	var again := (_room() as Node).get(&"boss") as Rooteater
	_check("geliştirici 7: boss yeniden hazır + kanca verildi", again != null and again.phase == Rooteater.Phase.DORMANT \
			and GameState.has_ability(G), "")
	_level.call(&"load_room", 6)
	await _frames(3)
	_check("geliştirici 6: Kökyiyen Eşiği", _room().room_id == &"kokyiyen_esigi", "")


func _kill_sac(boss: Rooteater) -> void:
	var sac := boss.get_active_weak_point()
	for i in 20:
		await _wait_until(func() -> bool: return boss.is_exposed(), 15.0)
		while boss.is_exposed() and not sac.is_dead():
			sac.take_hit(1, _player.global_position, &"forward")
			await _frames(6)
		if sac.is_dead():
			break
	await _frames(3)


# ---------------------------------------------------------------- Bot: tam dövüş denemeleri

func _test_bot_trials() -> void:
	var trials := int(OS.get_environment("TRIALS")) if OS.has_environment("TRIALS") else 3
	var wins := 0
	var total_time := 0.0
	var total_damage := 0
	var deaths := 0
	for t in trials:
		seed(1000 + t)
		var r := await _bot_fight(240.0)
		print("  [deneme %d] sonuç=%s süre=%.1f sn hasar=%d ölüm=%s faz1=%.0f faz2=%.0f kovalamaca=%.0f" % [
				t + 1, "ZAFER" if r["won"] else "yenilgi", r["time"], r["damage"], r["died"], r["t1"], r["t2"], r["t3"]])
		if r["won"]:
			wins += 1
			total_time += r["time"]
		total_damage += r["damage"]
		if r["died"]:
			deaths += 1
	print("  [zorluk] kazanma %d/%d · ort. süre %.0f sn · ort. hasar %.1f yaprak · ölüm %d" % [
			wins, trials, total_time / maxf(wins, 1), float(total_damage) / trials, deaths])
	_check("bot: Kökyiyen yenilebilir (adil)", wins >= 1, "kazanma=%d/%d" % [wins, trials])


func _bot_fight(limit: float) -> Dictionary:
	var boss := await _fresh_fight()
	var damage: Array[int] = [0]
	var died: Array[bool] = [false]
	var on_dmg := func(amount: int, _left: int) -> void:
		damage[0] += amount
		if OS.has_environment("HIT_LOG"):
			print("    [hasar] faz=%d eylem=%d st=%s pos=%s gövde=%s" % [boss.phase, boss.action,
					Player.State.keys()[_player.state], str(_player.global_position.snapped(Vector3.ONE * 0.1)),
					str(boss.get_body_position().snapped(Vector3.ONE * 0.1))])
	var on_die := func() -> void: died[0] = true
	EventBus.player_damaged.connect(on_dmg)
	EventBus.player_died.connect(on_die)
	_teleport(Vector3(4.0, 0.05, 0.0))
	_last_flower = null
	var marks := {"t1": 0.0, "t2": 0.0, "t3": 0.0}
	var t := 0.0
	var won := false
	while t < limit:
		_bot_step(boss)
		await _frames(1)
		t += 1.0 / 60.0
		if boss.phase == Rooteater.Phase.TWO and marks["t1"] == 0.0:
			marks["t1"] = t
		if boss.phase == Rooteater.Phase.CHASE and marks["t2"] == 0.0:
			marks["t2"] = t
		if boss.phase == Rooteater.Phase.DEFEATED:
			marks["t3"] = t
			won = true
			break
		if died[0]:
			break
		if OS.has_environment("BOT_DEBUG") and int(t * 60.0) % 30 == 0:
			print("    t=%.1f faz=%d eylem=%d st=%s pos=%s can=%d" % [t, boss.phase, boss.action,
					Player.State.keys()[_player.state], str(_player.global_position.snapped(Vector3.ONE * 0.1)), GameState.leaves])
	_release_all()
	EventBus.player_damaged.disconnect(on_dmg)
	EventBus.player_died.disconnect(on_die)
	await _frames(30)
	var story := _level.get("story_card") as StoryCard
	while story.is_playing():
		story.advance()
		await _frames(1)
	return {"won": won, "time": t, "damage": damage[0], "died": died[0],
			"t1": marks["t1"], "t2": marks["t2"] - marks["t1"] if marks["t2"] > 0.0 else 0.0,
			"t3": marks["t3"] - marks["t2"] if marks["t3"] > 0.0 else 0.0}


func _bot_step(boss: Rooteater) -> void:
	_tick_buttons()
	if _player.state == Player.State.CINEMATIC or SceneRouter.is_faded():
		_steer(Vector3.ZERO)
		return
	match boss.phase:
		Rooteater.Phase.DORMANT:
			_steer(Vector3.RIGHT)
			if _player.global_position.x > 12.0:
				_steer((Vector3(16.0, 0.0, -9.0) - _player.global_position).normalized())
		Rooteater.Phase.ONE, Rooteater.Phase.TWO:
			_arena_step(boss)
		Rooteater.Phase.CHASE:
			_chase_step()
		_:
			_steer(Vector3.ZERO)


func _arena_step(boss: Rooteater) -> void:
	if _player.state == Player.State.SWING:
		# Faz 2 süpürmesinden sarmaşıkta kaçıldıysa süpürme bitince bırak
		if not boss.is_sweep_telling() and not boss.is_sweeping():
			_jump()
		return
	var pos := _player.global_position
	var flat_pos := Vector3(pos.x, 0.0, pos.z)
	var body := boss.get_body_position()
	var flat_body := Vector3(body.x, 0.0, body.z)
	if boss.is_telegraphing():
		var crack := boss.get_crack_position()
		var away := Vector3(pos.x - crack.x, 0.0, pos.z - crack.z)
		if away.length() < 3.0:
			_steer(away.normalized() if away.length() > 0.1 else Vector3.RIGHT)
		else:
			_steer(Vector3.ZERO)
		return
	if boss.is_sweep_telling() or boss.is_sweeping():
		if boss.is_sweep_telling() and boss.get_action_time_left() < 0.25:
			_jump()
		var out := flat_pos - flat_body
		_steer(out.normalized() if out.length() < 3.0 and out.length() > 0.1 else Vector3.ZERO)
		return
	if boss.is_exposed():
		var sac := boss.get_active_weak_point()
		var sac_flat := Vector3(sac.global_position.x, 0.0, sac.global_position.z)
		var outward := (sac_flat - flat_body).normalized()
		var goal := sac_flat + outward * 1.5
		var to_goal := goal - flat_pos
		# Gövdenin içinden geçme: gövdeye 2.4 m'den yakınsa teğet yönde dolaş
		var from_body := flat_pos - flat_body
		if from_body.length() < 2.4 and to_goal.length() > 0.6:
			var tangent := Vector3(-from_body.z, 0.0, from_body.x).normalized()
			if tangent.dot(to_goal) < 0.0:
				tangent = -tangent
			_steer((tangent + from_body.normalized() * 0.6).normalized())
		elif to_goal.length() > 0.5:
			_steer(to_goal.normalized())
		else:
			_steer((sac_flat - flat_pos).normalized() * 0.4)
			_player.facing = (sac_flat - flat_pos).normalized()
			_attack()
		return
	# Gömülü / gömülme: gövdeden ≥ 4 m uzak dur, Şişkin varsa uzaktan vur
	var away_b := flat_pos - flat_body
	if boss.action != Rooteater.Action.BURROWED and away_b.length() < 4.0:
		_steer(away_b.normalized() if away_b.length() > 0.1 else Vector3.RIGHT)
		return
	if _fight_bloater(flat_pos):
		return
	var center := Vector3(20.0, 0.0, -9.0)
	var to_c := center - flat_pos
	_steer(to_c.normalized() if to_c.length() > 3.0 else Vector3.ZERO)


## Yakındaki Şişkin: 1.9 m'den yakınsa geri çekil, 1.9–2.4 m'de dön ve vur.
func _fight_bloater(flat_pos: Vector3) -> bool:
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var b := node as SporeBloater
		if b == null or b.is_dead():
			continue
		var d := Vector3(b.global_position.x, 0.0, b.global_position.z) - flat_pos
		if d.length() < 1.9:
			_steer(-d.normalized())
			return true
		if d.length() < 2.4:
			_steer(Vector3.ZERO)
			_player.facing = d.normalized()
			_attack()
			return true
	return false


## Kovalamaca: en yakın üstteki tırmanma sarmaşığına / çiçeğe doğru tırman; tepede kayaya kanca.
func _chase_step() -> void:
	Input.action_release(&"move_up")
	var pos := _player.global_position
	var t := _player.grapple_target
	var next_vine: ClimbVine = null
	for node: Node in get_tree().get_nodes_in_group(ClimbVine.GROUP):
		var v := node as ClimbVine
		if v.get_top().y > pos.y + 2.5 and (next_vine == null or v.get_top().y < next_vine.get_top().y):
			next_vine = v
	var dir := 1.0
	if next_vine != null and absf(next_vine.global_position.x - pos.x) > 0.3:
		dir = signf(next_vine.global_position.x - pos.x)
	elif next_vine == null:
		dir = signf(70.0 - pos.x) if absf(70.0 - pos.x) > 0.3 else 0.0
	if _player.state == Player.State.CLIMB or _player.state == Player.State.GROUND:
		_last_flower = null   # sağlam zemindeyken son çiçek yeniden hedeflenebilir
	var good := t != null and t != _last_flower and t.global_position.y > pos.y + 2.0
	match _player.state:
		Player.State.GROUND, Player.State.HURT:
			_hold(dir)
			if t is RootRock or (good and t.global_position.y > pos.y + 4.0):
				_grapple(t)
			elif next_vine != null and absf(next_vine.global_position.x - pos.x) < 1.2:
				_jump()
		Player.State.AIR:
			_hold(dir)
			if good and (t is RootRock or next_vine == null or t.global_position.y < next_vine.get_bottom().y + 6.0):
				_grapple(t)
		Player.State.CLIMB:
			var vine := _player.get_current_climb_vine()
			if _player.get_hand_position().y < vine.get_top().y - 0.4:
				_hold(0.0)
				Input.action_press(&"move_up")
			elif good:
				_grapple(t)
			else:
				_hold(dir)
				_jump()
		Player.State.SWING:
			var w := _player.get_swing_omega()
			_hold(1.0 if w >= 0.0 else -1.0)
			if rad_to_deg(_player.get_swing_angle()) * dir > 35.0 and w * dir > 0.0:
				_jump()


# ---------------------------------------------------------------- Girdi yardımcıları

func _tick_buttons() -> void:
	if _jf > 0:
		_jf -= 1
		if _jf == 0:
			Input.action_release(&"jump")
	if _gf > 0:
		_gf -= 1
		if _gf == 0:
			Input.action_release(&"grapple")
	if _af > 0:
		_af -= 1
		if _af == 0:
			Input.action_release(&"attack")


func _steer(world_dir: Vector3) -> void:
	if CameraDirector.is_side_mode():
		_hold(signf(world_dir.x) if absf(world_dir.x) > 0.05 else 0.0)
		Input.action_release(&"move_up")
		Input.action_release(&"move_down")
		return
	var b := CameraDirector.get_input_basis()
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	var forward := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	_axis(&"move_right", &"move_left", world_dir.dot(right))
	_axis(&"move_up", &"move_down", world_dir.dot(forward))


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


func _hold(dir: float) -> void:
	_axis(&"move_right", &"move_left", dir)


func _jump() -> void:
	if _jf > 0:
		return
	Input.action_press(&"jump")
	_jf = 20


func _attack() -> void:
	if _af > 0:
		return
	Input.action_press(&"attack")
	_af = 3


func _grapple(t: GrappleFlower) -> void:
	if _gf > 0:
		return
	_last_flower = t
	Input.action_press(&"grapple")
	_gf = 3


func _release_all() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"attack", &"grapple", &"heal"]:
		Input.action_release(a)
	_jf = 0
	_gf = 0
	_af = 0


# ---------------------------------------------------------------- Yardımcılar

func _room() -> Room:
	return _level.get("room") as Room


func _wait_until(cond: Callable, seconds: float) -> void:
	for i in int(seconds * 60.0):
		if cond.call():
			return
		await _frames(1)


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
