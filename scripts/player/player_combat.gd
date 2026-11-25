class_name PlayerCombat
extends Node3D
## Sarmaşık kamçısı "Çatal" (docs/03 §3): 3'lü ileri kombo (1–1–2), yukarı vuruş,
## havada aşağı vuruş (isabet ederse pogo), sallanırken Savrulma Saldırısı.
## İsabet, aktif karelerde fizik sorgusuyla (HURTBOX katmanı) hesaplanır; her düşman
## bir vuruşta en fazla bir kez hasar alır. İsabette kısa hit-stop.

enum Kind { FORWARD, UP, DOWN, SWING }

const KIND_NAMES: Array[StringName] = [&"forward", &"up", &"down", &"swing"]

var player: Player
var attacking: bool = false
var kind: Kind = Kind.FORWARD
## 0, 1, 2 — kombonun kaçıncı vuruşu.
var combo_index: int = 0
var current_damage: int = 1
## Bu vuruşta isabet eden düşman sayısı (testler + HUD).
var hits_this_attack: int = 0

var _time: float = 0.0
var _combo_timer: float = 0.0
var _cooldown: float = 0.0
var _buffer: float = 0.0
var _hit_ids: Dictionary = {}
var _whip_mesh: MeshInstance3D
var _whip_material: StandardMaterial3D


func _ready() -> void:
	player = get_parent() as Player
	_build_visual()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var t := player.tuning
	_combo_timer = maxf(_combo_timer - delta, 0.0)
	_cooldown = maxf(_cooldown - delta, 0.0)
	_buffer = maxf(_buffer - delta, 0.0)
	if Input.is_action_just_pressed(&"attack"):
		_buffer = t.attack_buffer

	if attacking:
		if not player.can_attack():
			_end_attack(false)
		else:
			_time += delta
			if _time >= t.attack_active_start and _time <= t.attack_active_end:
				_apply_hits()
			_update_whip_visual()
			if _time >= t.attack_duration:
				_end_attack(true)
	if not attacking and _buffer > 0.0 and _cooldown <= 0.0 and player.can_attack():
		_buffer = 0.0
		_start_attack()


func is_attacking() -> bool:
	return attacking


# ---------------------------------------------------------------- Vuruş akışı

func _start_attack() -> void:
	var t := player.tuning
	var input := player.get_move_input()
	if player.is_swinging():
		kind = Kind.SWING
	elif input.y > 0.5:
		kind = Kind.UP
	elif input.y < -0.5 and not player.is_on_floor():
		kind = Kind.DOWN
	else:
		kind = Kind.FORWARD

	match kind:
		Kind.FORWARD:
			combo_index = combo_index + 1 if _combo_timer > 0.0 else 0
			combo_index = clampi(combo_index, 0, t.combo_damage.size() - 1)
			current_damage = t.combo_damage[combo_index]
		Kind.SWING:
			var fast := player.swing_state.get_speed() >= t.swing_attack_fast_speed
			current_damage = t.swing_attack_damage_fast if fast else t.swing_attack_damage_slow
			combo_index = 0
		_:
			current_damage = 1
			combo_index = 0
	attacking = true
	_time = 0.0
	hits_this_attack = 0
	_hit_ids.clear()
	_whip_mesh.visible = true
	_update_whip_visual()
	EventBus.player_attacked.emit(KIND_NAMES[kind], combo_index)


func _end_attack(completed: bool) -> void:
	var t := player.tuning
	attacking = false
	_whip_mesh.visible = false
	if completed and kind == Kind.FORWARD and combo_index < t.combo_damage.size() - 1:
		_combo_timer = t.combo_window
	else:
		_combo_timer = 0.0
		if kind == Kind.FORWARD and combo_index >= t.combo_damage.size() - 1:
			_cooldown = t.combo_end_cooldown
		combo_index = 0


func _apply_hits() -> void:
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = Layers.HURTBOX
	var shape_xform := _hit_shape()
	query.shape = shape_xform[0]
	query.transform = shape_xform[1]
	var hit_any := false
	for result: Dictionary in space.intersect_shape(query, 16):
		var area := result.get("collider") as Area3D
		if area == null:
			continue
		var enemy := area.get_parent() as Enemy
		if enemy == null or _hit_ids.has(enemy.get_instance_id()):
			continue
		_hit_ids[enemy.get_instance_id()] = true
		if enemy.take_hit(current_damage, player.get_body_center(), KIND_NAMES[kind]):
			hits_this_attack += 1
			hit_any = true
			GameState.add_sap(player.tuning.sap_per_hit)
	if hit_any:
		if kind == Kind.DOWN:
			player.bounce(player.tuning.pogo_velocity)
		_hit_stop()


## [Shape3D, Transform3D] — vuruş türüne göre isabet hacmi.
func _hit_shape() -> Array:
	var t := player.tuning
	var center := player.get_body_center()
	match kind:
		Kind.SWING:
			var sphere := SphereShape3D.new()
			sphere.radius = t.swing_attack_radius
			return [sphere, Transform3D(Basis.IDENTITY, center)]
		Kind.UP:
			var up_box := BoxShape3D.new()
			up_box.size = Vector3(t.whip_thickness, t.whip_range, t.whip_thickness)
			return [up_box, Transform3D(Basis.IDENTITY, center + Vector3.UP * t.whip_range * 0.5)]
		Kind.DOWN:
			var down_box := BoxShape3D.new()
			down_box.size = Vector3(t.whip_thickness, t.whip_range, t.whip_thickness)
			return [down_box, Transform3D(Basis.IDENTITY,
					player.global_position + Vector3.DOWN * (t.whip_range * 0.5 - 0.3))]
		_:
			var box := BoxShape3D.new()
			box.size = Vector3(t.whip_range, t.whip_thickness, t.whip_thickness)
			return [box, Transform3D(_facing_basis(), center + _facing() * t.whip_range * 0.5)]


func _facing() -> Vector3:
	var f := Vector3(player.facing.x, 0.0, player.facing.z)
	return f.normalized() if f.length() > 0.1 else Vector3.RIGHT


## Yerel X = bakış yönü.
func _facing_basis() -> Basis:
	var x := _facing()
	var z := x.cross(Vector3.UP).normalized()
	return Basis(x, Vector3.UP, z)


func _hit_stop() -> void:
	var t := player.tuning
	TimeScale.request(&"hit_stop", t.hit_stop_scale, t.hit_stop_time)


# ---------------------------------------------------------------- Görsel (greybox)

func _build_visual() -> void:
	_whip_material = StandardMaterial3D.new()
	_whip_material.albedo_color = Color("e8a33d")
	_whip_material.emission_enabled = true
	_whip_material.emission = Color("e8a33d")
	_whip_material.emission_energy_multiplier = 1.5
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = _whip_material
	_whip_mesh = MeshInstance3D.new()
	_whip_mesh.mesh = mesh
	_whip_mesh.top_level = true
	_whip_mesh.visible = false
	add_child(_whip_mesh)


func _update_whip_visual() -> void:
	var t := player.tuning
	var center := player.get_body_center()
	# Vuruş ilerledikçe kamçı uzar (okunur hareket)
	var reach := clampf(_time / maxf(t.attack_active_end, 0.01), 0.2, 1.0)
	match kind:
		Kind.SWING:
			var r := t.swing_attack_radius * reach
			_whip_mesh.global_transform = Transform3D(
					_scaled_local(Basis.from_euler(Vector3(0.0, 0.0, _time * 30.0)), Vector3(r * 2.0, 0.08, 0.08)), center)
		Kind.UP:
			var len_up := t.whip_range * reach
			_whip_mesh.global_transform = Transform3D(_scaled_local(Basis.IDENTITY, Vector3(0.08, len_up, 0.08)),
					center + Vector3.UP * len_up * 0.5)
		Kind.DOWN:
			var len_down := t.whip_range * reach
			_whip_mesh.global_transform = Transform3D(_scaled_local(Basis.IDENTITY, Vector3(0.08, len_down, 0.08)),
					player.global_position + Vector3.DOWN * (len_down * 0.5 - 0.3))
		_:
			var len_f := t.whip_range * reach
			var thickness := 0.08 + 0.04 * combo_index
			_whip_mesh.global_transform = Transform3D(_scaled_local(_facing_basis(), Vector3(len_f, thickness, thickness)),
					center + _facing() * len_f * 0.5)


static func _scaled_local(b: Basis, s: Vector3) -> Basis:
	return Basis(b.x * s.x, b.y * s.y, b.z * s.z)
