class_name Player
extends CharacterBody3D
## Alpay — oyuncu kontrolcüsü (bağlam). Durum davranışları `scripts/player/states/*.gd` içinde;
## bu dosya ortak veriyi (zamanlayıcılar, ray, güvenli nokta), girdi yardımcılarını,
## tutunma seçimini ve can/hasar akışını tutar.
## Yan modda (2.5D) Z ekseni raya kilitlidir; derinlik modunda X-Z serbesttir.

enum State { GROUND, AIR, SWING, CLIMB, HURT, DEAD, CINEMATIC }

const HAND_HEIGHT: float = 1.45
const CLIMB_END_MARGIN: float = PlayerClimbState.END_MARGIN
## Gövdenin orta yüksekliği (hasar/isabet merkezi).
const BODY_CENTER: float = 0.8

@export var tuning: PlayerTuning

var state: State = State.AIR
var rail_z: float = 0.0
## Son bırakmanın mükemmel olup olmadığı (debug HUD + testler için).
var last_release_perfect: bool = false
## Bakış yönü (dünya, yatay birim vektör) — kamçı ileri vuruşu bunu kullanır.
var facing: Vector3 = Vector3.RIGHT

# Durumların paylaştığı zamanlayıcılar
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var jump_held: bool = false
var input_lock_timer: float = 0.0
var regrab_timer: float = 0.0
var climb_regrab_timer: float = 0.0
var invuln_timer: float = 0.0

var move_state: PlayerMoveState
var swing_state: PlayerSwingState
var climb_state: PlayerClimbState
var hurt_state: PlayerHurtState
var dead_state: PlayerDeadState
var cinematic_state: PlayerCinematicState

var _states: Dictionary = {}       # State -> PlayerState
var _last_safe_position: Vector3 = Vector3.ZERO
var _facing_yaw: float = PI * 0.5
var _blink_timer: float = 0.0

@onready var _visual: Node3D = $Visual
@onready var combat: PlayerCombat = $WhipCombat


func _init() -> void:
	move_state = PlayerMoveState.new(self)
	swing_state = PlayerSwingState.new(self)
	climb_state = PlayerClimbState.new(self)
	hurt_state = PlayerHurtState.new(self)
	dead_state = PlayerDeadState.new(self)
	cinematic_state = PlayerCinematicState.new(self)
	_states = {
		State.GROUND: move_state, State.AIR: move_state,
		State.SWING: swing_state, State.CLIMB: climb_state,
		State.HURT: hurt_state, State.DEAD: dead_state,
		State.CINEMATIC: cinematic_state,
	}


func _ready() -> void:
	if tuning == null:
		tuning = PlayerTuning.new()
	add_to_group(&"player")
	_last_safe_position = global_position
	rail_z = global_position.z


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	_update_timers(delta)
	(_states[state] as PlayerState).physics_update(delta)
	_update_visual(delta)
	_check_fall_out()


## Tek durum değişim noktası. Aynı durum nesnesine geçişte (GROUND↔AIR) enter/exit çağrılmaz.
func change_state(new_state: State) -> void:
	if new_state == state:
		return
	var old_state := state
	var old_obj: PlayerState = _states[old_state]
	var new_obj: PlayerState = _states[new_state]
	if old_obj != new_obj:
		old_obj.exit(new_state)
	state = new_state
	if old_obj != new_obj:
		new_obj.enter(old_state)
	EventBus.player_state_changed.emit(new_state)


func get_state_object() -> PlayerState:
	return _states[state]


# ---------------------------------------------------------------- Genel API

func is_swinging() -> bool:
	return state == State.SWING


func is_climbing() -> bool:
	return state == State.CLIMB


func is_dead() -> bool:
	return state == State.DEAD


func is_invulnerable() -> bool:
	return invuln_timer > 0.0


func can_attack() -> bool:
	return get_state_object().can_attack()


func get_current_anchor() -> VineAnchor:
	return swing_state.anchor if state == State.SWING else null


func get_current_climb_vine() -> ClimbVine:
	return climb_state.vine if state == State.CLIMB else null


## Dikeye göre sarkaç açısı (radyan); sallanmıyorsa 0.
func get_swing_angle() -> float:
	return swing_state.angle if state == State.SWING else 0.0


## Açısal hız (rad/sn); sallanmıyorsa 0.
func get_swing_omega() -> float:
	return swing_state.omega if state == State.SWING else 0.0


func get_rope_length() -> float:
	return swing_state.rope_length


func is_in_perfect_window() -> bool:
	return state == State.SWING and swing_state.is_in_perfect_window()


func get_coyote_timer() -> float:
	return coyote_timer


func get_jump_buffer_timer() -> float:
	return jump_buffer_timer


func get_last_safe_position() -> Vector3:
	return _last_safe_position


func get_hand_position() -> Vector3:
	return global_position + Vector3.UP * HAND_HEIGHT


func get_body_center() -> Vector3:
	return global_position + Vector3.UP * BODY_CENTER


func mark_safe_position() -> void:
	_last_safe_position = global_position


func set_cinematic(enabled: bool) -> void:
	if enabled:
		_detach_all()
		change_state(State.CINEMATIC)
	else:
		change_state(State.AIR)


func respawn(at: Vector3) -> void:
	_detach_all()
	global_position = at
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	change_state(State.AIR)
	EventBus.player_respawned.emit(at)


## Oda değişiminde: konumu, güvenli noktayı ve dokunulmazlığı sıfırlar.
func place_at(at: Vector3) -> void:
	respawn(at)
	_last_safe_position = at
	rail_z = at.z
	swing_state.last_anchor = null
	climb_state.last_vine = null
	invuln_timer = 0.0
	_visual.visible = true


func apply_gravity(delta: float) -> void:
	var g := tuning.gravity_up if velocity.y > 0.0 else tuning.gravity_down
	velocity.y = maxf(velocity.y - g * delta, -tuning.max_fall_speed)


## Pogo / yukarı itme: dikey hızı ayarlar, değişken zıplama kesmesini devre dışı bırakır.
func bounce(vertical_speed: float) -> void:
	if state == State.SWING or state == State.CLIMB:
		return
	velocity.y = vertical_speed
	jump_held = false
	coyote_timer = 0.0
	change_state(State.AIR)


func _detach_all() -> void:
	if state == State.SWING:
		swing_state.release(false)
	elif state == State.CLIMB:
		climb_state.release(Vector3.ZERO, false)


# ---------------------------------------------------------------- Can / hasar

## Hasar uygular. `source` hasar kaynağının konumu (geri itme yönü), `knockback` false ise
## (ör. çukura düşüş) itilmez. Dokunulmazlıkta, ölüyken veya sinematikte etkisizdir.
func take_damage(amount: int, source: Vector3, knockback: bool = true) -> bool:
	if amount <= 0 or is_invulnerable() or state == State.DEAD or state == State.CINEMATIC:
		return false
	GameState.leaves = maxi(GameState.leaves - amount, 0)
	invuln_timer = tuning.invuln_time
	EventBus.player_damaged.emit(amount, GameState.leaves)
	_detach_all()
	if GameState.leaves <= 0:
		change_state(State.DEAD)
		EventBus.player_died.emit()
		return true
	if knockback:
		var away := global_position - source
		var dir_x := signf(away.x) if absf(away.x) > 0.01 else -facing.x
		if dir_x == 0.0:
			dir_x = -1.0
		hurt_state.begin(Vector3(dir_x * tuning.hurt_knockback.x, tuning.hurt_knockback.y, 0.0))
	return true


# ---------------------------------------------------------------- Zamanlayıcılar / girdi

func _update_timers(delta: float) -> void:
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	regrab_timer = maxf(regrab_timer - delta, 0.0)
	climb_regrab_timer = maxf(climb_regrab_timer - delta, 0.0)
	input_lock_timer = maxf(input_lock_timer - delta, 0.0)
	invuln_timer = maxf(invuln_timer - delta, 0.0)
	if Input.is_action_just_pressed(&"jump") and state != State.DEAD:
		jump_buffer_timer = tuning.jump_buffer


func get_move_input() -> Vector2:
	# x: sağ(+) / sol(-), y: yukarı/ileri(+) / aşağı/geri(-)
	if state == State.DEAD or state == State.CINEMATIC:
		return Vector2.ZERO
	return Input.get_vector(&"move_left", &"move_right", &"move_down", &"move_up")


## Girdiyi dünya uzayında yatay bir vektöre çevirir.
func input_to_world(input: Vector2) -> Vector3:
	if CameraDirector.is_side_mode():
		return Vector3(input.x, 0.0, 0.0)
	var cam_basis: Basis = CameraDirector.get_input_basis()
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var dir := right * input.x + forward * input.y
	return dir.limit_length(1.0)


# ---------------------------------------------------------------- Tutunma seçimi

func try_grab() -> void:
	if not tuning.auto_grab and not Input.is_action_pressed(&"grab"):
		return
	var hand := get_hand_position()

	var best_swing: VineAnchor = null
	var best_swing_d := tuning.grab_radius
	for node: Node in get_tree().get_nodes_in_group(VineAnchor.GROUP):
		var anchor := node as VineAnchor
		if anchor == null or not anchor.enabled:
			continue
		if anchor == swing_state.last_anchor and regrab_timer > 0.0:
			continue
		# Tutturma noktasının üstünden/yanından tutunma sarkaçta momentumu sıfırlar → izin yok
		if hand.y > anchor.global_position.y - tuning.grab_min_below_anchor:
			continue
		var d := anchor.distance_to_vine(hand)
		if d < best_swing_d:
			best_swing_d = d
			best_swing = anchor

	var best_climb: ClimbVine = null
	var best_climb_d := tuning.climb_grab_radius
	for node: Node in get_tree().get_nodes_in_group(ClimbVine.GROUP):
		var vine := node as ClimbVine
		if vine == null or not vine.enabled:
			continue
		if vine == climb_state.last_vine and climb_regrab_timer > 0.0:
			continue
		var d := vine.distance_to_vine(hand)
		if d < best_climb_d:
			best_climb_d = d
			best_climb = vine

	if best_climb != null and (best_swing == null or best_climb_d <= best_swing_d):
		climb_state.begin(best_climb)
	elif best_swing != null:
		swing_state.begin(best_swing)


# ---------------------------------------------------------------- Görsel / güvenlik

func _update_visual(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if state == State.SWING:
		horizontal = swing_state.axis * signf(swing_state.omega)
	elif state == State.CLIMB or state == State.HURT or state == State.DEAD:
		horizontal = Vector3.ZERO
	if state == State.CLIMB:
		_facing_yaw = PI   # sarmaşığa (kameradan uzağa) bakar
	elif horizontal.length() > 0.5:
		# Model +Z'ye bakar (docs/07_ART_PIPELINE.md)
		_facing_yaw = atan2(horizontal.x, horizontal.z)
		facing = horizontal.normalized()
	_visual.rotation.y = lerp_angle(_visual.rotation.y, _facing_yaw, minf(1.0, tuning.turn_speed * delta))

	# Dokunulmazlıkta yanıp sönme
	if is_invulnerable() and state != State.DEAD:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink_timer = tuning.invuln_blink
			_visual.visible = not _visual.visible
	elif not _visual.visible:
		_visual.visible = true


func _check_fall_out() -> void:
	if global_position.y < tuning.kill_y:
		respawn(_last_safe_position + Vector3.UP * 0.2)
		# Düşüş cezası: 1 yaprak (docs/02 Oda Kuralı 3), geri itme yok
		take_damage(tuning.fall_damage, global_position, false)
