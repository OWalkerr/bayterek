class_name PlayerAnimator
extends Node
## Alpay'ın animasyon durumları (docs/07 §5 minimum listesi). Oyuncu durumundan + hızdan mantıksal
## animasyon seçer:
##   idle, run, jump_up, fall, land, swing, climb_up, climb_idle, whip_attack_1/2/3, whip_up, whip_down,
##   swing_attack, hurt, heal, death
## Model yoksa (M7 öncesi) kapsül üzerinde yordamsal "ezilme/esneme + eğilme" oynatır → his şimdiden
## okunur. Visual altında AnimationPlayer'lı bir model varsa `clip_map` ile adları eşleyip onu oynatır
## (Mixamo klip adları farklıysa clip_map'i düzenle; eşleşmeyen durum yordamsal kalır).

## Dış animasyon dosyaları: <klasör>/anim_alpay_<mantıksal ad>.fbx (Mixamo "Without Skin").
const EXTERNAL_LIBRARY: StringName = &"ext"

## mantıksal ad -> modeldeki klip adı (boşsa mantıksal adın kendisi aranır)
@export var clip_map: Dictionary = {}
## Döngülü oynatılacak mantıksal durumlar (Tripo/Mixamo klipleri döngüsüz gelebiliyor).
@export var looping: Array[StringName] = [&"idle", &"run", &"fall", &"swing", &"climb_up", &"climb_idle", &"heal"]
## Kökü (Hips) ileri taşıyan klipler "yerinde" oynatılır: yatay kök hareketi silinir, dikey sekme kalır
## (hareketi kod yönetir — docs/07 §5 "root motion kapalı").
@export var in_place: Array[StringName] = [&"run", &"death", &"land", &"whip_attack_1", &"whip_attack_2",
		&"whip_attack_3", &"jump_up", &"hurt", &"climb_up"]
@export var root_bone: String = "mixamorig_Hips"
## Koşu klibinin doğal hızı (m/s); oynatma hızı = oyuncu hızı / bu (klipten ölçülür, yoksa bu değer).
@export var run_clip_speed: float = 3.5
@export var run_speed_scale_range: Vector2 = Vector2(0.6, 2.2)
## Klibi olmayan durumda modelde oynatılacak yedek klip (+ yordamsal poz).
@export var fallback_clip: StringName = &"idle"
## Mixamo klasörü (boşsa dış klip yüklenmez). Dosya adı → mantıksal ad: anim_alpay_run.fbx → run.
@export_dir var external_dir: String = "res://assets/models/characters/alpay/anims"
@export var external_prefix: String = "anim_alpay_"
## Dış klip, modelin kendi klibinden (Tripo idle/run) öncelikli mi?
@export var prefer_external: bool = true
## Tek seferlik kliplerin oyundaki hedef süresi (sn): Mixamo klipleri oyunun ritminden uzun
## (ör. kılıç vuruşu 1.5 sn, kamçı 0.26 sn) → oynatma hızı = klip süresi / hedef.
@export var target_lengths: Dictionary = {
	&"whip_attack_1": 0.45, &"whip_attack_2": 0.45, &"whip_attack_3": 0.5,
	&"whip_up": 0.45, &"whip_down": 0.45, &"swing_attack": 0.45,
	&"jump_up": 0.4, &"land": 0.3, &"hurt": 0.45, &"death": 1.4,
}
## Yere inişte "land" pozunun süresi.
@export var land_time: float = 0.3
## Klip aralığı (sn): yalnız bu bölüm oynar. Mixamo zıplama/iniş klipleri yörüngenin tamamını içerir
## (iniş klibi 3 boy yukarıdan düşerek başlar) — yörüngeyi fizik çizdiği için yalnız poz kısmı alınır.
@export var clip_ranges: Dictionary = {&"land": Vector2(0.35, 1.0), &"jump_up": Vector2(0.15, 0.5)}
## Bu kliplerde kalça ayakta duruş yüksekliğinin üstüne çıkamaz (klibin kendi zıplaması silinir;
## çömelme kalır).
@export var vertical_clamp: Array[StringName] = [&"jump_up", &"fall", &"land"]
@export var blend_time: float = 0.12
@export var run_lean_deg: float = 8.0
@export var bob_amount: float = 0.05
@export var bob_speed: float = 14.0

var player: Player
var current: StringName = &"idle"
var model_player: AnimationPlayer = null
## Visual/Model (AI modeli) — yoksa null (kapsül greybox).
var model: Node3D = null
## Hata ayıklama önizlemesi (F3): boş değilse durum yerine bu klip oynar.
var preview_clip: StringName = &""
## Yüklenen dış klipler (mantıksal ad listesi) — testler ve önizleme için.
var external_clips: Array[StringName] = []

var _body: Node3D
var _was_on_floor: bool = true
var _land_timer: float = 0.0
var _time: float = 0.0
var _base_scale: Vector3 = Vector3.ONE
var _base_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	player = get_parent() as Player
	var visual := player.get_node(^"Visual") as Node3D
	var capsule := visual.get_node_or_null(^"Body") as Node3D
	model = visual.get_node_or_null(^"Model") as Node3D
	if model != null:
		# Gerçek model var: kapsül görseli gizlenir (çarpışma kapsülü kalır, docs/07 §6.5)
		for n: String in ["Body", "FacingMarker"]:
			var c := visual.get_node_or_null(NodePath(n)) as Node3D
			if c != null:
				c.visible = false
		model_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if model_player != null:
		_load_external_clips()
		_prepare_clips()
	# Klip yoksa yordamsal poz modele (yoksa kapsüle) uygulanır
	_body = model if model != null else capsule
	if _body != null:
		_base_scale = _body.scale
		_base_pos = _body.position


## Durumdan mantıksal animasyon adı (saf fonksiyon; testler doğrudan çağırır).
func pick_animation() -> StringName:
	var p := player
	var combat := p.combat
	match p.state:
		Player.State.DEAD:
			return &"death"
		Player.State.HURT:
			return &"hurt"
		Player.State.HEAL:
			return &"heal"
		Player.State.CLIMB:
			return &"climb_up" if absf(p.velocity.y) > 0.3 else &"climb_idle"
		Player.State.SWING:
			return &"swing_attack" if combat != null and combat.is_attacking() else &"swing"
		Player.State.CINEMATIC:
			return &"idle"
	if combat != null and combat.is_attacking():
		match combat.kind:
			PlayerCombat.Kind.UP: return &"whip_up"
			PlayerCombat.Kind.DOWN: return &"whip_down"
			_: return StringName("whip_attack_%d" % (combat.combo_index + 1))
	if p.state == Player.State.AIR:
		return &"jump_up" if p.velocity.y > 0.5 else &"fall"
	if _land_timer > 0.0:
		return &"land"
	return &"run" if Vector2(p.velocity.x, p.velocity.z).length() > 0.5 else &"idle"


func _process(delta: float) -> void:
	if player == null:
		return
	_time += delta
	var on_floor := player.state == Player.State.GROUND
	if on_floor and not _was_on_floor:
		_land_timer = land_time
	_was_on_floor = on_floor
	_land_timer = maxf(_land_timer - delta, 0.0)
	var next := pick_animation() if preview_clip == &"" else preview_clip
	if next != current:
		current = next
		_play_model(next)
	if model_player != null:
		# Koşu klibi oyuncu hızına eşlenir (ayak kayması azalır); tek seferlikler hedef süreye
		if current == &"run" and _model_has_clip(&"run"):
			var speed := Vector2(player.velocity.x, player.velocity.z).length()
			model_player.speed_scale = clampf(speed / maxf(run_clip_speed, 0.1),
					run_speed_scale_range.x, run_speed_scale_range.y)
		elif target_lengths.has(current) and _model_has_clip(current):
			var clip_len := model_player.get_animation(_clip_name(current)).length
			model_player.speed_scale = maxf(clip_len / float(target_lengths[current]), 1.0)
		else:
			model_player.speed_scale = 1.0
	if not _model_has_clip(current) and _body != null:
		_procedural(delta)
	elif _body != null and model != null:
		# Klip oynarken yordamsal pozu yumuşakça sıfırla
		var k := minf(1.0, 14.0 * delta)
		_body.scale = _body.scale.lerp(_base_scale, k)
		_body.rotation = _body.rotation.lerp(Vector3.ZERO, k)
		_body.position = _body.position.lerp(_base_pos, k)


## Yordamsal pozun uygulandığı düğüm (model ya da kapsül).
func get_procedural_target() -> Node3D:
	return _body


## Mantıksal ad → AnimationPlayer'daki tam ad (dış kütüphane "ext/<ad>" öncelikli).
func _clip_name(anim: StringName) -> StringName:
	if clip_map.has(anim):
		return clip_map[anim]
	if model_player != null:
		var ext := StringName("%s/%s" % [EXTERNAL_LIBRARY, anim])
		if prefer_external and model_player.has_animation(ext):
			return ext
		if model_player.has_animation(anim):
			return anim
		if model_player.has_animation(ext):
			return ext
	return anim


func _model_has_clip(anim: StringName) -> bool:
	return model_player != null and model_player.has_animation(_clip_name(anim))


func _play_model(anim: StringName) -> void:
	if model_player == null:
		return
	var clip := _clip_name(anim)
	if not model_player.has_animation(clip):
		clip = _clip_name(fallback_clip)
	if model_player.has_animation(clip):
		if model_player.current_animation != clip:
			model_player.play(clip, blend_time)
		elif not model_player.get_animation(clip).loop_mode == Animation.LOOP_LINEAR:
			model_player.seek(0.0, true)   # tek seferlik klip yeniden (ör. kombo vuruşu)


## Şu an modelde oynayan klip (yoksa "").
func get_playing_clip() -> StringName:
	return StringName(model_player.current_animation) if model_player != null else &""


## Klipleri hazırla: döngü, yerinde oynatma, koşu klibinin doğal hızını ölç.
func _prepare_clips() -> void:
	for logical: StringName in looping:
		for clip: StringName in [StringName(logical), StringName("%s/%s" % [EXTERNAL_LIBRARY, logical])]:
			if model_player.has_animation(clip):
				model_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	_apply_ranges_and_clamps(skeleton)
	var targets: Array = []
	for logical: StringName in in_place:
		for clip: StringName in [StringName(logical), StringName("%s/%s" % [EXTERNAL_LIBRARY, logical])]:
			if model_player.has_animation(clip):
				targets.append([logical, clip])
	for pair: Array in targets:
		var logical: StringName = pair[0]
		var anim := model_player.get_animation(pair[1])
		if skeleton == null:
			continue
		var track := _find_bone_track(anim, root_bone)
		if track < 0:
			continue
		var n := anim.track_get_key_count(track)
		if n < 2:
			continue
		var first: Vector3 = anim.track_get_key_value(track, 0)
		var last: Vector3 = anim.track_get_key_value(track, n - 1)
		var travel := Vector2(last.x - first.x, last.z - first.z).length()
		if logical == &"run" and travel > 0.01 and anim.length > 0.0 and pair[1] == _clip_name(&"run"):
			# Klibin doğal hızı (import root_scale izlere de uygulanır → metre)
			run_clip_speed = travel / anim.length
		# Yerinde: ileri kayma eğilimi (ilk→son doğrusal) çıkarılır ve kalça yatayda iskeletin
		# DİNLENME konumuna oturtulur. (İlk kareye sabitlemek yanlıştı: Tripo koşusu kalçayı dinlenmeden
		# 0.8 m ileride başlatıyor → koşuya geçişte öne fırlama, durunca geri kayma, dönüşte savrulma.)
		var bone := skeleton.find_bone(root_bone)
		var rest := skeleton.get_bone_rest(bone).origin if bone >= 0 else first
		var start_time := anim.track_get_key_time(track, 0)
		var span := maxf(anim.track_get_key_time(track, n - 1) - start_time, 0.0001)
		var mean_offset := Vector2.ZERO
		var detrended: Array[Vector2] = []
		for i in n:
			var v: Vector3 = anim.track_get_key_value(track, i)
			var u := (anim.track_get_key_time(track, i) - start_time) / span
			var trend := Vector2(lerpf(first.x, last.x, u), lerpf(first.z, last.z, u))
			var d := Vector2(v.x, v.z) - trend
			detrended.append(d)
			mean_offset += d
		mean_offset /= float(n)
		for i in n:
			var v: Vector3 = anim.track_get_key_value(track, i)
			var d: Vector2 = detrended[i] - mean_offset   # yalnız salınım kalır
			anim.track_set_key_value(track, i, Vector3(rest.x + d.x, v.y, rest.z + d.y))


## Klip aralığı kırpma + kalça dikey sınırı (bkz. clip_ranges, vertical_clamp).
func _apply_ranges_and_clamps(skeleton: Skeleton3D) -> void:
	if skeleton == null:
		return
	var bone := skeleton.find_bone(root_bone)
	var rest_y := skeleton.get_bone_rest(bone).origin.y if bone >= 0 else 1.0
	for logical: StringName in clip_ranges.keys():
		for clip: StringName in [StringName(logical), StringName("%s/%s" % [EXTERNAL_LIBRARY, logical])]:
			if model_player.has_animation(clip):
				_trim(model_player.get_animation(clip), clip_ranges[logical])
	for logical: StringName in vertical_clamp:
		for clip: StringName in [StringName(logical), StringName("%s/%s" % [EXTERNAL_LIBRARY, logical])]:
			if not model_player.has_animation(clip):
				continue
			var anim := model_player.get_animation(clip)
			var track := _find_bone_track(anim, root_bone)
			if track < 0:
				continue
			for i in anim.track_get_key_count(track):
				var v: Vector3 = anim.track_get_key_value(track, i)
				anim.track_set_key_value(track, i, Vector3(v.x, minf(v.y, rest_y), v.z))


## Animasyonu [range.x, range.y] sn aralığına kırpar (zamanlar 0'dan başlar; uçlara ara değer anahtar).
func _trim(anim: Animation, range: Vector2) -> void:
	var start := clampf(range.x, 0.0, anim.length)
	var end := clampf(range.y, start + 0.01, anim.length)
	for t in anim.get_track_count():
		var type := anim.track_get_type(t)
		var start_val: Variant = null
		var end_val: Variant = null
		match type:
			Animation.TYPE_POSITION_3D:
				start_val = anim.position_track_interpolate(t, start)
				end_val = anim.position_track_interpolate(t, end)
			Animation.TYPE_ROTATION_3D:
				start_val = anim.rotation_track_interpolate(t, start)
				end_val = anim.rotation_track_interpolate(t, end)
			Animation.TYPE_SCALE_3D:
				start_val = anim.scale_track_interpolate(t, start)
				end_val = anim.scale_track_interpolate(t, end)
			_:
				continue
		var keep: Array = []
		for k in anim.track_get_key_count(t):
			var time := anim.track_get_key_time(t, k)
			if time > start and time < end:
				keep.append([time - start, anim.track_get_key_value(t, k)])
		while anim.track_get_key_count(t) > 0:
			anim.track_remove_key(t, 0)
		anim.track_insert_key(t, 0.0, start_val)
		for kv: Array in keep:
			anim.track_insert_key(t, kv[0], kv[1])
		anim.track_insert_key(t, end - start, end_val)
	anim.length = end - start


## Testler için: yerinde yapılan klipte kalçanın yatay ortalama sapması (dinlenmeye göre, m).
func get_root_offset(clip: StringName) -> float:
	if model_player == null or not model_player.has_animation(clip):
		return -1.0
	var anim := model_player.get_animation(clip)
	var track := _find_bone_track(anim, root_bone)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var rest := skeleton.get_bone_rest(skeleton.find_bone(root_bone)).origin
	var sum := Vector2.ZERO
	var n := anim.track_get_key_count(track)
	for i in n:
		var v: Vector3 = anim.track_get_key_value(track, i)
		sum += Vector2(v.x - rest.x, v.z - rest.z)
	return (sum / float(n)).length()


## Mixamo "Without Skin" kliplerini modelin AnimationPlayer'ına "ext/<ad>" olarak ekler.
## - İz yolları modelin iskeletine yönlendirilir (…/Skeleton3D:kemik)
## - Konum izleri iskelet ölçeğine (kalça dinlenme boyu oranı, Tripo ×1.6) ölçeklenir
## - Kaynak iskeleti Y-yukarı değilse (ör. "With Skin" indirilmiş FBX) atlanır
## Dönüş izleri kemik yerel pozudur → aynı Mixamo hiyerarşisinde doğrudan geçer.
func _load_external_clips() -> void:
	if external_dir.is_empty() or not DirAccess.dir_exists_absolute(external_dir):
		return
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var anim_root := model_player.get_node(model_player.root_node)
	var skel_path := String(anim_root.get_path_to(skeleton))
	var hips := skeleton.find_bone(root_bone)
	var model_hips_h := skeleton.get_bone_rest(hips).origin.y if hips >= 0 else 1.0
	var lib := AnimationLibrary.new()
	for file: String in DirAccess.get_files_at(external_dir):
		var f := file.trim_suffix(".remap").trim_suffix(".import")
		if not f.begins_with(external_prefix) or not f.to_lower().ends_with(".fbx") or lib.has_animation(StringName(f)):
			continue
		var logical := StringName(f.get_basename().trim_prefix(external_prefix))
		if lib.has_animation(logical):
			continue
		var packed := load(external_dir.path_join(f)) as PackedScene
		if packed == null:
			continue
		var inst := packed.instantiate()
		var src_player := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var src_skel := inst.find_child("Skeleton3D", true, false) as Skeleton3D
		if src_player == null or src_skel == null or src_player.get_animation_list().is_empty():
			inst.free()
			continue
		var src_hips := src_skel.find_bone(root_bone)
		var src_rest := src_skel.get_bone_rest(src_hips).origin if src_hips >= 0 else Vector3.UP
		if src_rest.y < src_rest.length() * 0.7:
			push_warning("Animasyon atlandı (iskelet Y-yukarı değil — 'Without Skin' indir): %s" % f)
			inst.free()
			continue
		var ratio := model_hips_h / maxf(src_rest.y, 0.001)
		var anim := src_player.get_animation(src_player.get_animation_list()[0]).duplicate(true) as Animation
		for t in range(anim.get_track_count() - 1, -1, -1):
			var path := String(anim.track_get_path(t))
			var colon := path.find(":")
			if colon < 0:
				anim.remove_track(t)
				continue
			var bone := path.substr(colon + 1)
			if skeleton.find_bone(bone) < 0:
				anim.remove_track(t)
				continue
			anim.track_set_path(t, NodePath("%s:%s" % [skel_path, bone]))
			if anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
				for k in anim.track_get_key_count(t):
					anim.track_set_key_value(t, k, (anim.track_get_key_value(t, k) as Vector3) * ratio)
			elif anim.track_get_type(t) == Animation.TYPE_SCALE_3D:
				anim.remove_track(t)
		lib.add_animation(logical, anim)
		external_clips.append(logical)
		inst.free()
	if not external_clips.is_empty():
		if model_player.has_animation_library(EXTERNAL_LIBRARY):
			model_player.remove_animation_library(EXTERNAL_LIBRARY)
		model_player.add_animation_library(EXTERNAL_LIBRARY, lib)


## Önizleme (F3): yüklü tüm klipler arasında döner; sonda normal moda döner.
func cycle_preview() -> StringName:
	var names: Array[StringName] = []
	for c: StringName in external_clips:
		names.append(c)
	if model_player != null:
		for a: StringName in model_player.get_animation_list():
			if not String(a).begins_with(String(EXTERNAL_LIBRARY) + "/") and not names.has(a):
				names.append(a)
	if names.is_empty():
		return &""
	var i := names.find(preview_clip)
	preview_clip = names[i + 1] if i + 1 < names.size() else &""
	return preview_clip


func _find_bone_track(anim: Animation, bone: String) -> int:
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var path := String(anim.track_get_path(t))
		if path.ends_with(":" + bone):
			return t
	return -1


## Kapsül greybox animasyonu: okunur poz farkları (docs/07 model gelene kadar).
func _procedural(delta: float) -> void:
	var target_scale := Vector3.ONE
	var target_rot := Vector3.ZERO
	var target_pos := Vector3.ZERO
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	match current:
		&"run":
			target_rot.x = deg_to_rad(run_lean_deg) * clampf(speed / 7.0, 0.0, 1.0)
			target_pos.y = absf(sin(_time * bob_speed)) * bob_amount
		&"jump_up":
			target_scale = Vector3(0.9, 1.12, 0.9)
		&"fall":
			target_scale = Vector3(0.95, 1.05, 0.95)
		&"land":
			target_scale = Vector3(1.15, 0.82, 1.15)
		&"swing", &"swing_attack":
			target_rot.z = -player.get_swing_angle() * 0.6
		&"climb_up":
			target_rot.z = sin(_time * 10.0) * 0.12
		&"whip_attack_1", &"whip_attack_2", &"whip_attack_3", &"whip_up", &"whip_down":
			target_scale = Vector3(1.08, 0.95, 1.08)
		&"hurt":
			target_rot.x = deg_to_rad(-15.0)
		&"heal":
			target_scale = Vector3.ONE * (1.0 + sin(_time * 6.0) * 0.04)
		&"death":
			target_rot.z = deg_to_rad(85.0)
	var k := minf(1.0, 14.0 * delta)
	_body.scale = _body.scale.lerp(_base_scale * target_scale, k)
	_body.rotation = _body.rotation.lerp(target_rot, k)
	_body.position = _body.position.lerp(_base_pos + target_pos, k)
