extends Node
## M7 "sanat geçişi — altyapı" testleri (headless):
##  stilize shader + palet, Stylizer dönüşümü (renk/ışıma korunur; saydam/efekt/canlı renkler atlanır),
##  tüm odalarda çevrilmemiş opak materyal kalmaması, düşman vuruş parlaması (shader parametresi),
##  bölge ortamı (palet → sis/güneş), ModelValidator (yapay iyi/kötü modeller), PlayerAnimator durumları.
## Not: shader'ın GPU'da derlenmesi headless'ta denenemez → web build'de (WebGL) doğrulanır.
## Çalıştır: godot --headless --fixed-fps 60 --path . res://tests/test_m7.tscn

var _failures: int = 0
var _level: Node3D
var _player: Player


func _ready() -> void:
	GameState.save_slot = 96
	_level = load("res://scenes/main/main.tscn").instantiate() as Node3D
	add_child(_level)
	_player = _level.get("player") as Player
	_run.call_deferred()


func _run() -> void:
	await _frames(20)
	GameState.autosave_enabled = false
	_test_stylizer_unit()
	await _test_rooms_stylized()
	await _test_enemy_flash()
	_test_environment()
	_test_validator()
	_test_player_model()
	await _test_hips_follow()
	await _test_animator()
	print("[TEST] bitti — başarısız: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- Stilize

func _test_stylizer_unit() -> void:
	var shader := load("res://assets/shaders/stylized_lit.gdshader") as Shader
	_check("shader: stylized_lit yükleniyor", shader != null and shader.get_mode() == Shader.MODE_SPATIAL, "")
	var pal := Stylizer.get_palette()
	_check("palet: Kök Dibi paleti", pal != null and pal.shadow_tint == Color("2b1e3f"), "")
	var std := StandardMaterial3D.new()
	std.albedo_color = Color("e8a33d")
	std.emission_enabled = true
	std.emission = Color("4fb3a9")
	std.emission_energy_multiplier = 2.0
	var out := Stylizer.stylize_material(std) as ShaderMaterial
	_check("stylizer: StandardMaterial → stilize ShaderMaterial", out != null and Stylizer.is_stylized(out), "")
	_check("stylizer: renk ve ışıma korunuyor", out.get_shader_parameter(&"albedo") == Color("e8a33d") \
			and out.get_shader_parameter(&"emission_color") == Color("4fb3a9") \
			and is_equal_approx(float(out.get_shader_parameter(&"emission_energy")), 2.0), "")
	_check("stylizer: aynı kaynak bir kez çevrilir (önbellek)", Stylizer.stylize_material(std) == out, "")
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var fx := StandardMaterial3D.new()
	fx.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var live := StandardMaterial3D.new()
	live.set_meta(Stylizer.META_SKIP, true)
	_check("stylizer: saydam / gölgesiz / no_stylize atlanıyor", Stylizer.stylize_material(glass) == glass \
			and Stylizer.stylize_material(fx) == fx and Stylizer.stylize_material(live) == live, "")
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.material = std
	mi.mesh = box
	var n1 := Stylizer.apply(mi)
	var n2 := Stylizer.apply(mi)
	_check("stylizer: apply idempotent", n1 == 1 and n2 == 0, "ilk=%d ikinci=%d" % [n1, n2])
	mi.free()


func _test_rooms_stylized() -> void:
	var leftovers := ""
	for id: StringName in RoomRegistry.ROOMS.keys():
		SceneRouter.enter_room_immediate(id)
		await _frames(2)
		var n := _count_unstylized(_level.get("room") as Node)
		if n > 0:
			leftovers += "%s:%d " % [id, n]
	_check("odalar: tüm opak materyaller stilize (%d oda)" % RoomRegistry.ROOMS.size(), leftovers.is_empty(), leftovers)
	_check("oyuncu: stilize", _count_unstylized(_player) == 0, "")


func _count_unstylized(root: Node) -> int:
	var count := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(s)
			if m == null:
				m = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(s)
			var std := m as StandardMaterial3D
			if std != null and Stylizer.can_convert(std):
				count += 1
	return count


func _test_enemy_flash() -> void:
	_level.call(&"load_room", 4)
	await _frames(3)
	var crawler: RotCrawler = null
	for e: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		if e is RotCrawler:
			crawler = e as RotCrawler
			break
	crawler.take_hit(1, crawler.global_position + Vector3.LEFT, &"forward")
	await _frames(1)
	var mat := (crawler.visual.get_child(0) as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
	_check("düşman: vurulunca shader parlaması", crawler.is_flashing() and float(mat.get_shader_parameter(&"flash")) > 0.5, "")
	await _frames(int(crawler.flash_time * 60.0) + 3)
	_check("düşman: parlama sönüyor", not crawler.is_flashing() and float(mat.get_shader_parameter(&"flash")) < 0.5, "")


func _test_environment() -> void:
	var env := _level.get("environment") as RegionEnvironment
	var pal := Stylizer.get_palette()
	_check("ortam: sis ve güneş paletten", env.world_environment.environment.fog_light_color == pal.fog_color \
			and env.sun.light_color == pal.sun_color, "")
	var hq := RenderingServer.get_current_rendering_method() == "forward_plus"
	_check("ortam: SSAO/hacimsel sis yalnız Forward+'ta (web'de kapalı)",
			env.world_environment.environment.ssao_enabled == hq and env.world_environment.environment.volumetric_fog_enabled == hq, "")


# ---------------------------------------------------------------- Model kontrolü

func _test_validator() -> void:
	var good := _fake_model(1.6, 20000, true, Vector3.BACK, 0.0)   # parmak +Z (Godot'da BACK = +Z)
	var r := ModelValidator.validate_scene(good, "res://assets/models/characters/alpay/char_alpay.glb")
	_check("model: doğru Alpay geçiyor", r["ok"], ModelValidator.format_report(r))
	var off := _fake_model(1.6, 20000, true, Vector3.BACK, 0.8)                # orijin ortada
	r = ModelValidator.validate_scene(off, "char_alpay.glb")
	_check("model: orijin ayakta değilse hata", not r["ok"] and _has(r, "Orijin ayak"), "")
	var big := _fake_model(160.0, 20000, true, Vector3.BACK, 0.0)             # santimetre ölçek
	r = ModelValidator.validate_scene(big, "char_alpay.glb")
	_check("model: yanlış ölçek (160 m) hata", not r["ok"] and _has(r, "Boy"), "")
	var back := _fake_model(1.6, 20000, true, Vector3.FORWARD, 0.0)           # -Z'ye bakıyor
	r = ModelValidator.validate_scene(back, "char_alpay.glb")
	_check("model: -Z'ye bakan karakter hata", not r["ok"] and _has(r, "-Z"), "")
	var heavy := _fake_model(0.6, 30000, false, Vector3.BACK, 0.0)
	r = ModelValidator.validate_scene(heavy, "enm_rot_crawler.glb")
	_check("model: düşman üçgen bütçesi aşımı hata", not r["ok"] and _has(r, "Üçgen bütçesi"), "")
	var norig := _fake_model(1.6, 20000, false, Vector3.BACK, 0.0)
	r = ModelValidator.validate_scene(norig, "char_alpay.glb")
	_check("model: iskeletsiz insansı hata", not r["ok"] and _has(r, "iskeletsiz"), "")
	var unnamed := _fake_model(1.0, 2000, false, Vector3.BACK, 0.0)
	r = ModelValidator.validate_scene(unnamed, "alpay.glb")
	_check("model: tür öneki yoksa hata", not r["ok"] and _has(r, "Tür öneki"), "")
	_check("model: önek okuma", ModelValidator.kind_of("env_root_arch_4m_a.glb") == &"env" \
			and ModelValidator.name_of("enm_rot_crawler_a.glb") == "rot_crawler_a", "")
	for n: Node in [good, off, big, back, heavy, norig, unnamed]:
		n.free()


func _has(r: Dictionary, needle: String) -> bool:
	for e: String in r["errors"]:
		if e.contains(needle):
			return true
	return false


## Yapay model: `tris` üçgenlik düz bir mesh (taban y = -origin_lift·boy), isteğe bağlı insansı iskelet;
## `toe_dir` ayaktan parmağa yön (bakış yönü).
func _fake_model(height: float, tris: int, skeleton: bool, toe_dir: Vector3, origin_lift: float) -> Node3D:
	var root := Node3D.new()
	var verts := PackedVector3Array()
	verts.resize(tris * 3)
	var base := -origin_lift * height
	for i in tris:
		var t := float(i) / float(tris)
		var y := base + t * height
		verts[i * 3] = Vector3(-0.2, y, -0.1)
		verts[i * 3 + 1] = Vector3(0.2, y, -0.1)
		verts[i * 3 + 2] = Vector3(0.0, minf(y + height / float(tris), base + height), 0.1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	root.add_child(mi)
	if skeleton:
		var sk := Skeleton3D.new()
		for bone: String in ModelValidator.HUMANOID_BONES + ["LeftToeBase"]:
			sk.add_bone("mixamorig_" + bone)   # Godot import'u "mixamorig:" → "mixamorig_" yapar
		var foot := sk.find_bone("mixamorig_LeftFoot")
		var toe := sk.find_bone("mixamorig_LeftToeBase")
		sk.set_bone_rest(foot, Transform3D(Basis.IDENTITY, Vector3(0.1, 0.08, 0.0)))
		sk.set_bone_rest(toe, Transform3D(Basis.IDENTITY, Vector3(0.1, 0.02, 0.0) + toe_dir.normalized() * 0.12))
		root.add_child(sk)
	return root


# ---------------------------------------------------------------- Animasyon

func _test_player_model() -> void:
	var anim := _player.animator
	var model := anim.model
	_check("model: Alpay (Tripo) Player/Visual/Model altında", model != null, "")
	if model == null:
		return
	_check("model: kapsül görseli gizli", not (_player.get_node(^"Visual/Body") as Node3D).visible, "")
	var r := ModelValidator.validate_scene(model, "char_alpay_tripo.glb")
	_check("model: oyundaki Alpay ölçüsü doğru (1.6 m, +Z, bütçe)", r["ok"], ModelValidator.format_report(r))
	_check("model: stilize shader'a çevrildi", _count_unstylized(model) == 0, "")
	var ap := anim.model_player
	_check("model: idle + run klipleri, döngülü", ap != null and ap.has_animation(&"idle") and ap.has_animation(&"run") \
			and ap.get_animation(&"run").loop_mode == Animation.LOOP_LINEAR and ap.get_animation(&"idle").loop_mode == Animation.LOOP_LINEAR, "")
	if ap != null and ap.has_animation(&"run"):
		var run := ap.get_animation(&"run")
		var t := run.find_track(NodePath("Armature/Skeleton3D:mixamorig_Hips"), Animation.TYPE_POSITION_3D)
		var a: Vector3 = run.track_get_key_value(t, 0)
		var b: Vector3 = run.track_get_key_value(t, run.track_get_key_count(t) - 1)
		_check("model: koşu yerinde (kök yatayda kaymıyor)", Vector2(b.x - a.x, b.z - a.z).length() < 0.02, "")
		_check("model: koşuda kalça dinlenme konumunda (öne fırlama / geri kayma yok)", anim.get_root_offset(&"run") < 0.03,
				"sapma=%.3f m" % anim.get_root_offset(&"run"))
		_check("model: koşu klibinin doğal hızı ölçüldü", anim.run_clip_speed > 2.0 and anim.run_clip_speed < 6.0,
				"%.2f m/s" % anim.run_clip_speed)


## Koşuya geçiş / durma / ani dönüş boyunca kalçanın oyuncu merkezinden yatay en büyük sapması (m).
func _test_hips_follow() -> void:
	var anim := _player.animator
	if anim.model == null:
		return
	_level.call(&"load_room", 4)
	await _frames(3)
	_teleport(Vector3(-4.0, 0.05, 0.0))
	await _frames(30)
	var sk := anim.model.find_child("Skeleton3D", true, false) as Skeleton3D
	var hips := sk.find_bone(anim.root_bone)
	var worst := 0.0
	var phases := [[&"move_right", 40], [&"", 30], [&"move_right", 25], [&"move_left", 40], [&"", 30]]
	for ph: Array in phases:
		for a: StringName in [&"move_left", &"move_right"]:
			Input.action_release(a)
		if ph[0] != &"":
			Input.action_press(ph[0])
		for i in int(ph[1]):
			await _frames(1)
			var hp := (sk.global_transform * sk.get_bone_global_pose(hips)).origin
			var off := Vector2(hp.x - _player.global_position.x, hp.z - _player.global_position.z).length()
			worst = maxf(worst, off)
	for a: StringName in [&"move_left", &"move_right"]:
		Input.action_release(a)
	_check("anim: koşu başla/dur/ani dönüşte kalça merkezde (≤ 0.3 m)", worst <= 0.3, "en büyük sapma=%.2f m" % worst)


func _test_animator() -> void:
	_level.call(&"load_room", 4)
	await _frames(3)
	var anim := _player.animator
	_teleport(Vector3(-6.0, 0.05, 0.0))
	await _frames(20)
	_check("anim: yerde duran → idle", anim.current == &"idle", str(anim.current))
	if anim.model_player != null:
		_check("anim: modelde idle klibi oynuyor", anim.get_playing_clip() == &"idle", str(anim.get_playing_clip()))
	Input.action_press(&"move_right")
	await _frames(20)
	var body := anim.get_procedural_target()
	if anim.model_player != null:
		_check("anim: koşu → modelde run klibi, hız eşlemesi", anim.current == &"run" and anim.get_playing_clip() == &"run" \
				and anim.model_player.speed_scale > 1.2, "klip=%s hız×%.2f" % [anim.get_playing_clip(), anim.model_player.speed_scale])
	else:
		_check("anim: koşu → run + öne eğilme (yordamsal)", anim.current == &"run" and body.rotation.x > 0.05,
				"%s eğim=%.2f" % [anim.current, body.rotation.x])
	Input.action_release(&"move_right")
	Input.action_press(&"jump")
	await _frames(6)
	_check("anim: zıplama → jump_up", anim.current == &"jump_up", str(anim.current))
	if anim.model_player != null:
		_check("anim: klibi olmayan durumda yedek klip (idle) + yordamsal poz",
				anim.get_playing_clip() == &"idle", str(anim.get_playing_clip()))
	for i in 60:
		await _frames(1)
		if _player.velocity.y < -1.0:
			break
	await _frames(2)
	Input.action_release(&"jump")
	_check("anim: düşüş → fall", anim.current == &"fall", str(anim.current))
	await _frames(40)
	Input.action_press(&"attack")
	await _frames(4)
	Input.action_release(&"attack")
	_check("anim: kamçı → whip_attack_1", anim.current == &"whip_attack_1", str(anim.current))
	await _frames(40)
	_player.take_damage(1, _player.global_position + Vector3.RIGHT)
	await _frames(2)
	_check("anim: hasar → hurt", anim.current == &"hurt", str(anim.current))
	await _frames(60)
	GameState.add_sap(GameState.SAP_MAX)
	Input.action_press(&"heal")
	await _frames(6)
	_check("anim: iyileşme → heal", anim.current == &"heal", str(anim.current))
	Input.action_release(&"heal")
	_level.call(&"load_room", 2)
	await _frames(3)
	_teleport(Vector3(0.4, 2.0, 0.0))
	await _frames(4)
	_check("anim: tırmanma → climb_idle", anim.current == &"climb_idle", str(anim.current))
	_level.call(&"load_room", 1)
	await _frames(3)
	var vine: VineAnchor = null
	for c: Node in (_level.get("room") as Node).get_children():
		if c is VineAnchor and not c is GrappleFlower:
			vine = c as VineAnchor
			break
	_teleport(vine.global_position + Vector3(-0.3, -2.5 - Player.HAND_HEIGHT, 0.0))
	await _frames(4)
	_check("anim: sallanma → swing", anim.current == &"swing", str(anim.current))
	GameState.leaves = 1
	_player.take_damage(1, _player.global_position)
	await _frames(2)
	_check("anim: ölüm → death", anim.current == &"death", str(anim.current))


# ---------------------------------------------------------------- Yardımcılar

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
