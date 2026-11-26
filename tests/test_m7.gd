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
	_test_rig_tools()
	await _test_player_model()
	await _test_hips_follow()
	await _test_jump_land_hips()
	await _test_animator()
	await _test_art_enemies()
	await _test_trap_flower()
	await _test_root_snake()
	await _test_art_props()
	await _test_dressing_and_fog()
	await _test_land_dust()
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
	var mat: ShaderMaterial = crawler.get_model().get_materials()[0] if crawler.get_model() != null \
			else (crawler.visual.get_child(0) as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
	_check("düşman: vurulunca shader parlaması", crawler.is_flashing() and float(mat.get_shader_parameter(&"flash")) > 0.5, "")
	var others := 0
	for e: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		if e is RotCrawler and e != crawler and (e as RotCrawler).get_model() != null:
			var fl: Variant = (e as RotCrawler).get_model().get_materials()[0].get_shader_parameter(&"flash")
			if fl != null and float(fl) > 0.5:
				others += 1
	_check("düşman: parlama yalnız vurulan sürüngende (materyal örneğe özel)", others == 0, "")
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


## Sentetik iki kemikli tüp: alt yarı kemik 0'a, üst yarı kemik 1'e SERT bağlı (oto-rig hatası).
## Bükme testi yırtılmayı yakalamalı; RigSmoother yırtılmayı azaltmalı. Gerçek modeller: bükme ölçülebiliyor.
func _test_rig_tools() -> void:
	var hard := _two_bone_tube()
	var r0 := ModelValidator.bend_test(hard, 30.0)
	_check("rig: sert ağırlık bükmede yırtılma olarak ölçülüyor", float(r0.get("worst_torn", 0.0)) > 0.003 and float(r0["worst"]) > 1.6,
			"yırtık=%.4f" % float(r0.get("worst_torn", 0.0)))
	RigSmoother.smooth_instance(hard.get_node(^"Skel/Tube") as MeshInstance3D, 8)
	var r1 := ModelValidator.bend_test(hard, 30.0)
	_check("rig: RigSmoother yırtılmayı azaltıyor", float(r1.get("worst_torn", 0.0)) < float(r0.get("worst_torn", 0.0)) * 0.5 \
			and float(r1["worst"]) < float(r0["worst"]),
			"önce=%.4f ×%.1f sonra=%.4f ×%.1f" % [float(r0.get("worst_torn", 0.0)), r0["worst"], float(r1.get("worst_torn", 0.0)), r1["worst"]])
	var arrays := (hard.get_node(^"Skel/Tube") as MeshInstance3D).mesh.surface_get_arrays(0)
	var w: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var ok := true
	for v in w.size() / 4:
		ok = ok and absf(w[v * 4] + w[v * 4 + 1] + w[v * 4 + 2] + w[v * 4 + 3] - 1.0) < 0.001
	_check("rig: yumuşatılmış ağırlıklar normalize (Σ=1)", ok, "")
	hard.free()
	var boss := (load("res://assets/models/bosses/boss_kokyiyen.glb") as PackedScene).instantiate() as Node3D
	var mi := boss.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	_check("rig: Kökyiyen içe aktarmada yumuşatıldı", int(mi.get_meta(&"rig_smoothed", 0)) > 0, "")
	boss.free()


func _two_bone_tube() -> Node3D:
	var root := Node3D.new()
	var sk := Skeleton3D.new()
	sk.name = "Skel"
	root.add_child(sk)
	sk.add_bone("b0")
	sk.add_bone("b1")
	sk.set_bone_parent(1, 0)
	sk.set_bone_rest(1, Transform3D(Basis(), Vector3(0, 1, 0)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	var rings := 21
	var seg := 8
	for r in rings:
		var y := 2.0 * r / (rings - 1)
		for k in seg:
			var a := TAU * k / seg
			st.set_bones(PackedInt32Array([0 if y < 1.0 else 1, 0, 0, 0]))
			st.set_weights(PackedFloat32Array([1, 0, 0, 0]))
			st.add_vertex(Vector3(cos(a) * 0.2, y, sin(a) * 0.2))
	for r in rings - 1:
		for k in seg:
			var a := r * seg + k
			var b := r * seg + (k + 1) % seg
			st.add_index(a); st.add_index(b); st.add_index(a + seg)
			st.add_index(b); st.add_index(b + seg); st.add_index(a + seg)
	var mi := MeshInstance3D.new()
	mi.name = "Tube"
	mi.mesh = st.commit()
	var skin := Skin.new()
	skin.add_named_bind("b0", Transform3D.IDENTITY)
	skin.add_named_bind("b1", Transform3D(Basis(), Vector3(0, -1, 0)))
	skin.set_bind_bone(0, 0)
	skin.set_bind_bone(1, 1)
	mi.skin = skin
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	return root


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
	await _frames(1)
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
	# Mixamo dış klipleri
	_check("mixamo: 12 dış klip yüklendi (idle 'With Skin' atlandı)", anim.external_clips.size() == 12 \
			and not anim.external_clips.has(&"idle"), str(anim.external_clips))
	if ap != null and ap.has_animation(&"ext/run"):
		var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
		var rest_y := sk.get_bone_rest(sk.find_bone(anim.root_bone)).origin.y
		var er := ap.get_animation(&"ext/run")
		var tr := er.find_track(NodePath("Armature/Skeleton3D:mixamorig_Hips"), Animation.TYPE_POSITION_3D)
		var hy: float = (er.track_get_key_value(tr, 0) as Vector3).y
		_check("mixamo: izler modelin iskeletine bağlı + kalça ×1.6 ölçekli", tr >= 0 and absf(hy - rest_y) < rest_y * 0.3,
				"kalça y=%.2f dinlenme=%.2f" % [hy, rest_y])
		_check("mixamo: döngüler (run/fall/swing/climb/heal)", er.loop_mode == Animation.LOOP_LINEAR \
				and ap.get_animation(&"ext/swing").loop_mode == Animation.LOOP_LINEAR, "")
		for c: StringName in [&"death", &"land", &"whip_attack_3"]:
			_check("mixamo: '%s' yerinde (InPlace yoktu → kod)" % c, anim.get_root_offset(StringName("ext/%s" % c)) < 0.05,
					"sapma=%.3f m" % anim.get_root_offset(StringName("ext/%s" % c)))
		anim.preview_clip = &"whip_up"
		await _frames(3)
		_check("anim: klibi olmayan durumda yedek klip (idle)", anim.get_playing_clip() == &"idle", str(anim.get_playing_clip()))
		anim.preview_clip = &""


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


## Zıplama → düşüş → iniş boyunca kalça yüksekliği (oyuncu ayağına göre): klibin kendi
## zıplaması / iniş klibinin "3 boy yukarıdan düşüşü" modelde görünmemeli.
func _test_jump_land_hips() -> void:
	var anim := _player.animator
	if anim.model == null or anim.model_player == null:
		return
	_level.call(&"load_room", 2)
	await _frames(3)
	_teleport(Vector3(-3.0, 0.05, 0.0))
	await _frames(30)
	var sk := anim.model.find_child("Skeleton3D", true, false) as Skeleton3D
	var hips := sk.find_bone(anim.root_bone)
	var standing := (sk.global_transform * sk.get_bone_global_pose(hips)).origin.y - _player.global_position.y
	var hi := -INF
	var lo := INF
	var saw_land := false
	Input.action_press(&"jump")
	for i in 110:
		await _frames(1)
		if i == 20:
			Input.action_release(&"jump")
		if anim.current == &"land":
			saw_land = true
		var h := (sk.global_transform * sk.get_bone_global_pose(hips)).origin.y - _player.global_position.y
		hi = maxf(hi, h)
		lo = minf(lo, h)
	Input.action_release(&"jump")
	_check("anim: iniş pozu oynadı", saw_land, "")
	_check("anim: zıplama/inişte kalça ayakta duruş boyunu aşmıyor", hi <= standing * 1.1,
			"en yüksek=%.2f duruş=%.2f m" % [hi, standing])
	_check("anim: iniş çömelmesi makul (yere gömülmüyor)", lo >= standing * 0.45, "en alçak=%.2f m" % lo)
	_check("anim: iniş klibi kırpıldı (düşüş kısmı yok)", anim.model_player.get_animation(&"ext/land").length < 0.7,
			"%.2f sn" % anim.model_player.get_animation(&"ext/land").length)


func _test_animator() -> void:
	_level.call(&"load_room", 4)
	await _frames(3)
	var anim := _player.animator
	_teleport(Vector3(-6.0, 0.05, 0.0))
	await _frames(45)   # olası iniş pozu (0.3 sn) bitsin
	_check("anim: yerde duran → idle", anim.current == &"idle", str(anim.current))
	if anim.model_player != null:
		_check("anim: modelde idle klibi oynuyor", anim.get_playing_clip() == &"idle", str(anim.get_playing_clip()))
	Input.action_press(&"move_right")
	await _frames(20)
	var body := anim.get_procedural_target()
	if anim.model_player != null:
		_check("anim: koşu → modelde run klibi, hız eşlemesi", anim.current == &"run" and String(anim.get_playing_clip()).ends_with("run") \
				and anim.model_player.speed_scale > 1.2, "klip=%s hız×%.2f" % [anim.get_playing_clip(), anim.model_player.speed_scale])
	else:
		_check("anim: koşu → run + öne eğilme (yordamsal)", anim.current == &"run" and body.rotation.x > 0.05,
				"%s eğim=%.2f" % [anim.current, body.rotation.x])
	Input.action_release(&"move_right")
	Input.action_press(&"jump")
	await _frames(6)
	_check("anim: zıplama → jump_up", anim.current == &"jump_up", str(anim.current))
	if anim.model_player != null:
		_check("anim: zıplamada Mixamo jump_up klibi", anim.get_playing_clip() == &"ext/jump_up", str(anim.get_playing_clip()))
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


# ---------------------------------------------------------------- M7 model yerleştirme + ortam

func _enter(room_id: StringName, at: Vector3) -> Node:
	GameState.reset_health()
	SceneRouter.enter_room_immediate(room_id)
	await _frames(3)
	_teleport(at)
	await _frames(2)
	return _level.get("room") as Node


func _first(group: StringName, type_check: Callable) -> Node:
	for n: Node in get_tree().get_nodes_in_group(group):
		if type_check.call(n):
			return n
	return null


func _test_art_enemies() -> void:
	# önceki test oyuncuyu öldürdü: ölüm/diriliş akışı (karartma, yavaşlama) bitsin
	for i in 240:
		await _frames(1)
		if _player.state != Player.State.DEAD and not get_tree().paused and Engine.time_scale > 0.99:
			break
	print("[TEST] bilgi: durum=%d duraklatıldı=%s zaman=%.2f" % [_player.state, get_tree().paused, Engine.time_scale])
	await _enter(&"spor_mahzeni", Vector3(-8.0, 0.1, 0.0))
	var crawler := _first(Enemy.GROUP, func(n: Node) -> bool: return n is RotCrawler) as RotCrawler
	var bloater := _first(Enemy.GROUP, func(n: Node) -> bool: return n is SporeBloater) as SporeBloater
	_check("model: sürüngen modeli bağlı (greybox yok)", crawler != null and crawler.get_model() != null \
			and crawler.get_model().skeleton != null, "")
	if crawler == null or crawler.get_model() == null:
		return
	var mv := crawler.get_model()
	var leg := mv.bone("tripo__0_Left_Limb_0")
	var max_angle := 0.0
	for i in 40:
		await _frames(1)
		max_angle = maxf(max_angle, mv.bone_pose_angle(leg))
	_check("anim: sürüngen yürürken bacak sallanıyor (yordamsal)", max_angle > 0.2, "en büyük=%.2f rad" % max_angle)
	var dir := crawler.direction
	var fwd := mv.pivot.global_transform.basis * Vector3.RIGHT
	_check("model: sürüngen yürüdüğü yöne bakıyor (ayna değil dönüş)", fwd.x * dir > 0.7 and mv.scale.x > 0.0,
			"ileri=%s yön=%.0f" % [str(fwd), dir])
	_check("model: şişkin modeli bağlı + nefes alıyor", bloater != null and bloater.model != null, "")
	if bloater != null:
		var s0 := bloater.visual.scale
		await _frames(20)
		_check("anim: şişkin ölçeği nefesle değişiyor", bloater.visual.scale.distance_to(s0) > 0.005, "")
	_check("model: düşmanlar stilize", _count_unstylized(crawler) == 0, "")


func _test_trap_flower() -> void:
	var room := await _enter(&"spor_mahzeni", Vector3(-8.0, 0.1, 0.0))
	var flower := _first(Enemy.GROUP, func(n: Node) -> bool: return n is TrapFlower) as TrapFlower
	_check("kapan çiçek: odada + model", flower != null and flower.model != null, "")
	if flower == null:
		return
	await _frames(5)
	_check("kapan çiçek: oyuncu uzaktayken bekliyor", flower.state == TrapFlower.State.IDLE, "")
	var under := Vector3(flower.global_position.x, 0.1, 0.0)
	_teleport(under)
	var leaves0 := GameState.leaves
	var told := false
	var bit := false
	var lowest := 0.0
	for i in 90:
		await _frames(1)
		told = told or flower.is_telling()
		bit = bit or flower.is_biting()
		lowest = maxf(lowest, flower.drop)
		_player.global_position.x = under.x
	_check("kapan çiçek: altına girince önce uyarıyor (titreme)", told, "")
	_check("kapan çiçek: sonra ısırıyor, kafa oyuncu boyuna iniyor", bit and flower.global_position.y - lowest < 1.8,
			"en alçak kafa y=%.2f" % (flower.global_position.y - lowest))
	_check("kapan çiçek: ısırık can götürüyor", GameState.leaves < leaves0, "yaprak %d → %d" % [leaves0, GameState.leaves])
	_teleport(Vector3(-8.0, 0.1, 0.0))
	await _frames(70)
	_check("kapan çiçek: geri çekiliyor", flower.state == TrapFlower.State.IDLE and absf(flower.drop - flower.idle_drop) < 0.2, "")
	flower.take_hit(1, flower.global_position, &"up")
	flower.take_hit(1, flower.global_position, &"up")
	_check("kapan çiçek: iki vuruşta ölüyor", flower.is_dead(), "")
	room = room


func _test_root_snake() -> void:
	await _enter(&"spor_mahzeni", Vector3(-8.0, 0.1, 0.0))
	var snake := _first(Enemy.GROUP, func(n: Node) -> bool: return n is RootSnake) as RootSnake
	_check("kök yılanı: odada + model", snake != null and snake.model != null, "")
	if snake == null:
		return
	await _frames(30)
	_check("kök yılanı: oyuncu uzakta → delikte", snake.state == RootSnake.State.HIDDEN and not snake.is_out(), "")
	_teleport(Vector3(snake.global_position.x - 3.0, 0.1, 0.0))
	var told := false
	var out := false
	for i in 200:
		await _frames(1)
		told = told or snake.is_telling()
		if snake.state == RootSnake.State.OUT:
			out = true
			break
	_check("kök yılanı: önce delik parlıyor (uyarı)", told, "")
	_check("kök yılanı: sonra koridora fırlıyor", out and snake.get_head_position().z > -0.3,
			"kafa=%s" % str(snake.get_head_position()))
	snake.take_hit(1, snake.get_head_position(), &"forward")
	await _frames(25)
	_check("kök yılanı: vurulunca deliğe çekiliyor", not snake.is_out(), "uzanma=%.2f" % snake.extend)


func _test_art_props() -> void:
	# Kanca çiçeği + Ocak + Kocabaş + Kökyiyen
	var room := await _enter(&"ocak_odasi", Vector3(-3.0, 0.1, 0.0))
	var flower := _first(GrappleFlower.FLOWER_GROUP, func(n: Node) -> bool: return not n is RootRock) as GrappleFlower
	_check("kanca çiçeği: model bağlı", flower != null and flower.model != null, "")
	if flower != null:
		flower.set_targeted(true)
		await _frames(30)
		_check("kanca çiçeği: hedeflenince parlıyor + büyüyor", flower.model.scale.x > 1.03, "ölçek=%.3f" % flower.model.scale.x)
		flower.set_targeted(false)
	var ocak := _first(Ocak.GROUP, func(_n: Node) -> bool: return true) as Ocak
	_check("ocak: model + hareketli ateş (alev, kıvılcım, duman)", ocak != null and ocak.model != null \
			and ocak.fire.emitting and ocak.embers.emitting and ocak.smoke.emitting, "")
	room = await _enter(&"kok_agzi", Vector3(-8.0, 0.1, 0.0))
	var koca: KocabasNpc = null
	for c: Node in room.get_children():
		if c is KocabasNpc:
			koca = c as KocabasNpc
	_check("kocabaş: Kök Ağzı'nda dinleniyor (model)", koca != null and koca.model != null, "")
	if koca != null and koca.model != null:
		var neck := koca.model.bone("tripo__Spine_1")
		_teleport(Vector3(-10.0, 0.1, 0.0))
		await _frames(60)
		var a := koca.model.bone_pose_angle(neck)
		_teleport(Vector3(2.0, 0.1, 0.0))
		await _frames(90)
		var b := koca.model.bone_pose_angle(neck)
		_check("kocabaş: boynu oyuncuyu izliyor", absf(a - b) > 0.05, "açı %.2f → %.2f" % [a, b])
	room = await _enter(&"kokyiyen_ini", Vector3(4.0, 0.1, 0.0))
	var boss := room.get("boss") as Rooteater
	_check("kökyiyen: model bağlı", boss != null and boss.model != null and boss.model.skeleton != null, "")
	if boss != null and boss.model != null:
		var y_hidden := boss.model.position.y
		boss.start_fight(_player)
		await _frames(150)
		_check("kökyiyen: girişte yerden yükseliyor", boss.model.position.y > y_hidden + 5.0,
				"y %.1f → %.1f" % [y_hidden, boss.model.position.y])
		var tail := boss.model.bone("tripo__Tail_3")
		_check("kökyiyen: kuyruk/gövde yordamsal kıvrılıyor", boss.model.bone_pose_angle(tail) > 0.02, "")


func _test_dressing_and_fog() -> void:
	var room := await _enter(&"spor_mahzeni", Vector3(-8.0, 0.1, 0.0)) as GreyboxRoom
	var d := room.dressing
	_check("ortam: ot/eğrelti/mantar serpiştirildi", d != null and d.tuft_count > 30, "tutam=%d" % (d.tuft_count if d else 0))
	_check("ortam: tavan altına sarkan kökler", d != null and d.strand_count > 2, "saçak=%d" % (d.strand_count if d else 0))
	_check("ortam: süzülen sporlar", d != null and d.motes != null and d.motes.emitting, "")
	var wind := 0
	var push_ok := false
	for f: Node in get_tree().get_nodes_in_group(RoomDressing.FOLIAGE_GROUP):
		var m := (f as MeshInstance3D).material_override as ShaderMaterial
		var ws: Variant = m.get_shader_parameter(&"wind_strength") if m != null else null
		if ws != null and float(ws) > 0.0:
			wind += 1
			push_ok = push_ok or (m.get_shader_parameter(&"push_origin") as Vector3).distance_to(_player.global_position) < 0.5
	_check("ortam: bitkiler stilize + rüzgârlı shader", wind > 20 and _count_unstylized(d) == 0, "rüzgârlı=%d" % wind)
	await _frames(2)
	_check("ortam: oyuncu konumu bitkilere iletiliyor (yanından geçince eğilir)", push_ok, "")
	var fog: FogPatch = null
	for c: Node in room.get_children():
		if c is FogPatch:
			fog = c as FogPatch
	_check("sis: odada sis öbeği", fog != null and fog.puff_count() >= 8, "")
	if fog == null:
		return
	var center := fog.global_position + Vector3(0.0, -fog.size.y * 0.5 + 0.1, 0.0)
	center.z = 0.0
	var before := fog.density_near(center + Vector3.UP * 0.8)
	_teleport(center + Vector3.LEFT * 3.0)
	Input.action_press(&"move_right")
	for i in 30:
		await _frames(1)
	Input.action_release(&"move_right")
	await _frames(30)
	var inside := fog.density_near(_player.global_position + Vector3.UP * 0.8)
	var disp := fog.mean_displacement(_player.global_position + Vector3.UP * 0.8, 1.5)
	_check("sis: içinden geçince dağılıyor (incelir + itilir)", inside < before * 0.6 and disp > 0.3,
			"yoğunluk %.2f → %.2f, itilme %.2f m" % [before, inside, disp])
	var spot := _player.global_position
	# yürüyen sürüngen oyuncuyu kapıdan itip odayı değiştirmesin (sis nesnesi silinirdi)
	for e: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		(e as Node).queue_free()
	_teleport(Vector3(-9.0, 0.1, 0.0))
	await _frames(400)
	if not is_instance_valid(fog):
		_check("sis: oyuncu gidince yavaşça geri toplanıyor", false, "oda değişti")
		return
	_check("sis: oyuncu gidince yavaşça geri toplanıyor", fog.density_near(spot + Vector3.UP * 0.8) > 0.8,
			"yoğunluk=%.2f" % fog.density_near(spot + Vector3.UP * 0.8))


func _test_land_dust() -> void:
	await _enter(&"spor_mahzeni", Vector3(-8.0, 6.0, 0.0))
	var n0 := _player.land_dust_count
	for i in 90:
		await _frames(1)
		if _player.is_on_floor():
			break
	await _frames(2)
	_check("fx: yüksekten inişte toz pufu", _player.land_dust_count > n0, "")


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
