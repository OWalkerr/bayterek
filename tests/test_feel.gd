extends Node
## Oyun hissi (juice) testleri (headless):
##  - SfxBank: bütün sesler üretiliyor (boş değil), döngülü rüzgâr
##  - Juice: zıplama / adım / iniş olayları ses çalıyor
##  - Kamera sarsıntısı: travma eklenir ve gerçek zamanla söner
##  - Tepe asılması: tuş basılıyken tepe yakınında yerçekimi azalır
##  - Köşe düzeltme: kafa bir kenara az çarpınca yükseliş sürer
##  - Koşu adımları + hata ayıklama yazısı varsayılan gizli
##  - Greybox kutuları dokulu (üç düzlemli), tırmanma sarmaşığında kutu yaprak yok
## Çalıştır: godot --headless --fixed-fps 60 --path . res://tests/test_feel.tscn

var _failures: int = 0
var _level: Node3D
var _player: Player


func _ready() -> void:
	_level = load("res://scenes/main/main.tscn").instantiate() as Node3D
	add_child(_level)
	_player = _level.get("player") as Player
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	_test_sfx_bank()
	await _test_shake()
	_test_apex()
	await _test_jump_and_steps()
	await _test_corner_correction()
	_test_visuals()
	print("[TEST] bitti — başarısız: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_sfx_bank() -> void:
	var empty: Array[StringName] = []
	for n: StringName in SfxBank.NAMES:
		var s := SfxBank.get_stream(n) as AudioStreamWAV
		if s == null or s.data.size() < 200:
			empty.append(n)
	_check("sfx: bütün sesler üretildi", empty.is_empty(), "eksik=%s toplam=%d" % [str(empty), SfxBank.NAMES.size()])
	var wind := SfxBank.get_stream(&"swing_wind") as AudioStreamWAV
	_check("sfx: rüzgâr döngülü", wind.loop_mode == AudioStreamWAV.LOOP_FORWARD, "")


func _test_shake() -> void:
	CameraDirector.shake(0.5)
	var t0 := CameraDirector.get_trauma()
	await _frames(2)
	var cam := CameraDirector.rig.camera
	var moved := absf(cam.h_offset) + absf(cam.v_offset) > 0.0
	await _frames(60)
	var t1 := CameraDirector.get_trauma()
	_check("sarsıntı: travma eklenir, kamera kayar", t0 >= 0.49 and moved, "travma=%.2f" % t0)
	_check("sarsıntı: söner", t1 < t0 * 0.2, "1 sn sonra=%.2f" % t1)


func _test_apex() -> void:
	var t := _player.tuning
	_load_room(1)
	_player.change_state(Player.State.AIR)
	_player.jump_held = true
	_player.velocity.y = 0.5
	_player.apply_gravity(0.1)
	var dv_apex := 0.5 - _player.velocity.y
	_player.jump_held = false
	_player.velocity.y = 5.0
	_player.apply_gravity(0.1)
	var dv_normal := 5.0 - _player.velocity.y
	_check("tepe asılması: tepede yerçekimi azalır", absf(dv_apex - dv_normal * t.apex_gravity_mult) < 0.01,
			"tepe Δv=%.3f normal Δv=%.3f" % [dv_apex, dv_normal])


func _test_jump_and_steps() -> void:
	_load_room(1)
	await _frames(10)
	_teleport(Vector3(-6.0, 0.1, 0.0), Vector3.ZERO)
	await _frames(20)
	Juice.played.clear()
	var steps0 := _player.footstep_count
	Input.action_press(&"move_right")
	await _frames(50)
	_check("adım: koşarken adım tozu + ses", _player.footstep_count > steps0 and Juice.played.has(&"step"),
			"adım=%d" % (_player.footstep_count - steps0))
	Input.action_release(&"move_right")
	await _frames(20)
	Input.action_press(&"jump")
	await _frames(4)
	Input.action_release(&"jump")
	await _frames(60)
	_check("zıplama: ses + iniş sesi", Juice.played.has(&"jump") and Juice.played.has(&"land"), str(Juice.played))


func _test_corner_correction() -> void:
	_load_room(1)
	await _frames(10)
	var room := _level.get("room") as Node3D
	# Oyuncunun sağ kenarı tavan bloğunun sol kenarının 0.2 m altına girer
	var block := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 0.5, 3.0)
	var col := CollisionShape3D.new()
	col.shape = shape
	block.add_child(col)
	room.add_child(block)
	block.global_position = Vector3(-2.85 + 1.0, 2.2 + 0.25, 0.0)
	_teleport(Vector3(-3.0, 0.1, 0.0), Vector3.ZERO)
	await _frames(20)
	var before := _player.corner_corrections
	Input.action_press(&"jump")
	var max_y := 0.0
	for i in 40:
		await _frames(1)
		max_y = maxf(max_y, _player.global_position.y)
	Input.action_release(&"jump")
	block.queue_free()
	_check("köşe düzeltme: kenara çarpınca yükseliş sürer", max_y > 0.9 and _player.corner_corrections > before,
			"en yüksek=%.2f düzeltme=%d x=%.2f" % [max_y, _player.corner_corrections - before, _player.global_position.x])
	await _frames(60)


func _test_visuals() -> void:
	var hud := _level.get("hud") as DebugHud
	var info := hud.get("_info") as Label
	_check("HUD: hata ayıklama yazısı varsayılan gizli", not info.visible, "")
	var room := _level.get("room") as GreyboxRoom
	var textured := 0
	var boxes := 0
	for body: Node in room.get_children():
		if not body is StaticBody3D:
			continue
		for c: Node in body.get_children():
			var mi := c as MeshInstance3D
			if mi == null or not mi.mesh is BoxMesh:
				continue
			boxes += 1
			var mat := mi.get_surface_override_material(0)
			if mat == null:
				mat = mi.mesh.surface_get_material(0)
			var sm := mat as ShaderMaterial
			if sm != null and bool(sm.get_shader_parameter(&"use_triplanar")):
				textured += 1
	_check("kutular: dokulu (üç düzlemli)", boxes > 0 and textured == boxes, "%d/%d" % [textured, boxes])
	var leaf_boxes := 0
	for v: Node in get_tree().get_nodes_in_group(ClimbVine.GROUP):
		for n: Node in v.find_children("*", "MeshInstance3D", true, false):
			if (n as MeshInstance3D).mesh is BoxMesh:
				leaf_boxes += 1
	_check("tırmanma sarmaşığı: kutu yaprak yok", leaf_boxes == 0, "kutu=%d" % leaf_boxes)


# ---------------------------------------------------------------- Yardımcılar

func _load_room(index: int) -> void:
	for a: StringName in [&"move_left", &"move_right", &"jump", &"move_up", &"move_down"]:
		Input.action_release(a)
	_level.call("load_room", index)


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
