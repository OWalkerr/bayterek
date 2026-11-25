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
@export var blend_time: float = 0.12
@export var run_lean_deg: float = 8.0
@export var bob_amount: float = 0.05
@export var bob_speed: float = 14.0

var player: Player
var current: StringName = &"idle"
var model_player: AnimationPlayer = null

var _body: Node3D
var _was_on_floor: bool = true
var _land_timer: float = 0.0
var _time: float = 0.0
var _base_scale: Vector3 = Vector3.ONE
var _base_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	player = get_parent() as Player
	var visual := player.get_node(^"Visual") as Node3D
	_body = visual.get_node_or_null(^"Body") as Node3D
	if _body != null:
		_base_scale = _body.scale
		_base_pos = _body.position
	model_player = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer


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
	if model_player == null and _body != null:
		_procedural(delta)


func _play_model(anim: StringName) -> void:
	if model_player == null:
		return
	var clip: StringName = clip_map.get(anim, anim)
	if model_player.has_animation(clip):
		model_player.play(clip, blend_time)


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
