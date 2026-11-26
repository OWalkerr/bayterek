class_name PlayerAnimator
extends Node
## Alpay'ın animasyon durumları (docs/07 §5 minimum listesi). Oyuncu durumundan + hızdan mantıksal
## animasyon seçer:
##   idle, run, jump_up, fall, land, swing, climb_up, climb_idle, whip_attack_1/2/3, whip_up, whip_down,
##   swing_attack, hurt, heal, death
## Model yoksa (M7 öncesi) kapsül üzerinde yordamsal "ezilme/esneme + eğilme" oynatır → his şimdiden
## okunur. Visual altında AnimationPlayer'lı bir model varsa `clip_map` ile adları eşleyip onu oynatır
## (Mixamo klip adları farklıysa clip_map'i düzenle; eşleşmeyen durum yordamsal kalır).

const LAND_TIME: float = 0.12

## mantıksal ad -> modeldeki klip adı (boşsa mantıksal adın kendisi aranır)
@export var clip_map: Dictionary = {}
## Döngülü oynatılacak mantıksal durumlar (Tripo/Mixamo klipleri döngüsüz gelebiliyor).
@export var looping: Array[StringName] = [&"idle", &"run", &"fall", &"swing", &"climb_up", &"climb_idle", &"heal"]
## Kökü (Hips) ileri taşıyan klipler "yerinde" oynatılır: yatay kök hareketi silinir, dikey sekme kalır
## (hareketi kod yönetir — docs/07 §5 "root motion kapalı").
@export var in_place: Array[StringName] = [&"run"]
@export var root_bone: String = "mixamorig_Hips"
## Koşu klibinin doğal hızı (m/s); oynatma hızı = oyuncu hızı / bu (klipten ölçülür, yoksa bu değer).
@export var run_clip_speed: float = 3.5
@export var run_speed_scale_range: Vector2 = Vector2(0.6, 2.2)
## Klibi olmayan durumda modelde oynatılacak yedek klip (+ yordamsal poz).
@export var fallback_clip: StringName = &"idle"
@export var blend_time: float = 0.12
@export var run_lean_deg: float = 8.0
@export var bob_amount: float = 0.05
@export var bob_speed: float = 14.0

var player: Player
var current: StringName = &"idle"
var model_player: AnimationPlayer = null
## Visual/Model (AI modeli) — yoksa null (kapsül greybox).
var model: Node3D = null

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
		_land_timer = LAND_TIME
	_was_on_floor = on_floor
	_land_timer = maxf(_land_timer - delta, 0.0)
	var next := pick_animation()
	if next != current:
		current = next
		_play_model(next)
	if model_player != null:
		# Koşu klibi oyuncu hızına eşlenir (ayak kayması azalır)
		if current == &"run" and _model_has_clip(&"run"):
			var speed := Vector2(player.velocity.x, player.velocity.z).length()
			model_player.speed_scale = clampf(speed / maxf(run_clip_speed, 0.1),
					run_speed_scale_range.x, run_speed_scale_range.y)
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


func _model_has_clip(anim: StringName) -> bool:
	return model_player != null and model_player.has_animation(clip_map.get(anim, anim))


func _play_model(anim: StringName) -> void:
	if model_player == null:
		return
	var clip: StringName = clip_map.get(anim, anim)
	if not model_player.has_animation(clip):
		clip = clip_map.get(fallback_clip, fallback_clip)
	if model_player.has_animation(clip) and model_player.current_animation != clip:
		model_player.play(clip, blend_time)


## Şu an modelde oynayan klip (yoksa "").
func get_playing_clip() -> StringName:
	return StringName(model_player.current_animation) if model_player != null else &""


## Klipleri hazırla: döngü, yerinde oynatma, koşu klibinin doğal hızını ölç.
func _prepare_clips() -> void:
	for logical: StringName in looping:
		var clip: StringName = clip_map.get(logical, logical)
		if model_player.has_animation(clip):
			model_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	for logical: StringName in in_place:
		var clip: StringName = clip_map.get(logical, logical)
		if not model_player.has_animation(clip) or skeleton == null:
			continue
		var anim := model_player.get_animation(clip)
		var track := _find_bone_track(anim, root_bone)
		if track < 0:
			continue
		var n := anim.track_get_key_count(track)
		if n < 2:
			continue
		var first: Vector3 = anim.track_get_key_value(track, 0)
		var last: Vector3 = anim.track_get_key_value(track, n - 1)
		var travel := Vector2(last.x - first.x, last.z - first.z).length()
		if logical == &"run" and travel > 0.01 and anim.length > 0.0:
			# Klibin doğal hızı (model ölçeğiyle): oynatma hızını oyuncu hızına eşlemek için
			run_clip_speed = travel / anim.length   # import root_scale izlere de uygulanır → metre
		for i in n:
			var v: Vector3 = anim.track_get_key_value(track, i)
			anim.track_set_key_value(track, i, Vector3(first.x, v.y, first.z))


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
