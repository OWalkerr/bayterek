class_name Enemy
extends CharacterBody3D
## Düşman tabanı: can, isabet alanı (Hurtbox, HURTBOX katmanı), temas hasarı, geri itilme,
## vurulunca beyaz parlama, ölüm ve (isteğe bağlı) yeniden doğma.
## Alt sınıflar `_enemy_ready()`, `_enemy_physics(delta)` ve `_build_visual()` doldurur.
## Basit durum makinesi: her düşman kendi `enum` + `match` yapısını kullanır (docs/04).

const GROUP: StringName = &"enemy"

signal died

@export var max_hp: int = 3
@export var contact_damage: int = 1
## Vurulunca geri itilme çarpanı (0 = itilmez).
@export var knockback_scale: float = 1.0
## Vurulunca kısa sersemleme (hareket durur).
@export var stagger_time: float = 0.2
## Ölünce bu kadar sn sonra başlangıç yerinde yeniden doğar (< 0 = doğmaz).
## Yol açmak için gereken düşmanlarda (pogo basamağı vb.) soft-lock'u önler.
@export var respawn_time: float = -1.0
@export var hurtbox_size: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var hurtbox_offset: Vector3 = Vector3(0.0, 0.5, 0.0)
@export var flash_time: float = 0.1
## Ölüm pufunun rengi (çürüklük moru).
@export var death_fx_color: Color = Color("8a3a8c")

var hp: int = 3
var home_position: Vector3
var hurtbox: Area3D
var visual: Node3D
var _stagger: float = 0.0
var _flash: float = 0.0
var _dead: bool = false
var _respawn_timer: float = 0.0
var _flash_materials: Array[ShaderMaterial] = []
var _flash_on: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD
	hp = max_hp
	home_position = global_position
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_build_visual()
	Stylizer.apply(visual)
	_collect_materials(visual)
	_build_hurtbox()
	_enemy_ready()


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	if _dead:
		if respawn_time >= 0.0:
			_respawn_timer -= delta
			if _respawn_timer <= 0.0:
				_respawn()
		return
	_stagger = maxf(_stagger - delta, 0.0)
	_update_flash(delta)
	_enemy_physics(delta)
	_contact_damage()


func is_dead() -> bool:
	return _dead


func is_staggered() -> bool:
	return _stagger > 0.0


## Kamçı isabeti. Hasar uygulandıysa true.
func take_hit(damage: int, from: Vector3, _kind: StringName) -> bool:
	if _dead or damage <= 0:
		return false
	hp -= damage
	_flash = flash_time
	_stagger = stagger_time
	var away := global_position - from
	away.y = 0.0
	if away.length() > 0.01 and knockback_scale > 0.0:
		var t := _player_tuning()
		velocity = away.normalized() * t.enemy_knockback * knockback_scale
	EventBus.enemy_damaged.emit(self, damage)
	_on_hit(damage, from)
	if hp <= 0:
		_die()
	return true


# ---------------------------------------------------------------- Alt sınıf kancaları

func _enemy_ready() -> void:
	pass


func _enemy_physics(_delta: float) -> void:
	pass


func _build_visual() -> void:
	pass


func _on_hit(_damage: int, _from: Vector3) -> void:
	pass


func _on_die() -> void:
	pass


func _on_respawn() -> void:
	pass


# ---------------------------------------------------------------- İç

func _die() -> void:
	_dead = true
	FxLibrary.spawn_oneshot(get_parent(), FxLibrary.puff(death_fx_color), global_position + hurtbox.position)
	_on_die()
	visible = false
	hurtbox.set_deferred(&"monitorable", false)
	hurtbox.set_deferred(&"monitoring", false)
	collision_layer = 0
	velocity = Vector3.ZERO
	died.emit()
	EventBus.enemy_killed.emit(self)
	if respawn_time >= 0.0:
		_respawn_timer = respawn_time
	else:
		queue_free()


func _respawn() -> void:
	_dead = false
	hp = max_hp
	global_position = home_position
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	visible = true
	collision_layer = Layers.ENEMY
	hurtbox.monitorable = true
	hurtbox.monitoring = true
	_on_respawn()


func _contact_damage() -> void:
	if contact_damage <= 0:
		return
	for body: Node3D in hurtbox.get_overlapping_bodies():
		var player := body as Player
		if player != null:
			player.take_damage(contact_damage, global_position)


func _build_hurtbox() -> void:
	hurtbox = Area3D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = Layers.HURTBOX
	hurtbox.collision_mask = Layers.PLAYER
	hurtbox.monitorable = true
	hurtbox.monitoring = true
	var shape := BoxShape3D.new()
	shape.size = hurtbox_size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = hurtbox_offset
	hurtbox.add_child(col)
	add_child(hurtbox)


## Vuruş parlaması için düşmanın stilize materyalleri ("flash" parametresi).
func _collect_materials(node: Node) -> void:
	for child: Node in node.get_children():
		var mi := child as MeshInstance3D
		if mi != null and mi.mesh != null:
			var mat := mi.get_surface_override_material(0) as ShaderMaterial
			if mat != null and Stylizer.is_stylized(mat) and not _flash_materials.has(mat):
				_flash_materials.append(mat)
		_collect_materials(child)


func _update_flash(delta: float) -> void:
	if _flash <= 0.0 and not _flash_on:
		return
	_flash = maxf(_flash - delta, 0.0)
	_flash_on = _flash > 0.0
	for mat: ShaderMaterial in _flash_materials:
		mat.set_shader_parameter(&"flash", 1.0 if _flash_on else 0.0)


## Testler için: şu an parlıyor mu?
func is_flashing() -> bool:
	return _flash_on


func _player_tuning() -> PlayerTuning:
	var p := get_tree().get_first_node_in_group(&"player") as Player
	return p.tuning if p != null else PlayerTuning.new()


func _find_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


## Greybox görsel yardımcı: renkli kutu/küre.
func _mesh(mesh: Mesh, color: Color, pos: Vector3, emissive: bool = false) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.0
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	visual.add_child(mi)
	return mi
