class_name TrapFlower
extends Enemy
## Kapan Çiçek (docs/04): tavandan sarkar, sarmaşık gibi görünür; oyuncu altına girince ısırır.
## "Dikkat ediyor musun?" Okunur uyarı: titrer, taç yaprakları açılır, sarı gözler parlar (≥ 0.45 sn).
## Düğüm konumu = tavandaki tutturma noktası. Kafa `idle_drop` m aşağıda sallanır, ısırıkta
## `bite_drop` m'ye iner, sonra yavaşça geri çekilir. Isırık anında kafa hasar verir; diğer
## zamanlarda kafaya değmek de 1 hasar (Enemy temas hasarı) ama kafa yüksekte durur.
## Durumlar: IDLE → TELL → BITE → RECOVER → IDLE (COOLDOWN içinde tekrar ısırmaz).

enum State { IDLE, TELL, BITE, RECOVER }

const MODEL_PATH: String = "res://assets/models/enemies/enm_trap_flower.glb"
## Model boyu (import ölçeği 1.5): tepe plakası y=1.5, kafa ≈ y 0.1–0.5.
const MODEL_HEIGHT: float = 1.5

@export var idle_drop: float = 1.5
## Isırık derinliği; < 0 → ilk karede alttaki zemine ışın atılır, kafa zeminin `bite_clearance` m üstüne iner.
@export var bite_drop: float = -1.0
@export var bite_clearance: float = 1.1
## Oyuncu kafanın yatayda bu kadar yakınında ve altında ise ısırır.
@export var trigger_half_width: float = 1.3
@export var trigger_depth: float = 4.5   # bite_drop otomatikse ondan hesaplanır
@export var tell_time: float = 0.5
@export var bite_time: float = 0.14
@export var hold_time: float = 0.25
@export var recover_time: float = 0.9
@export var cooldown: float = 0.6
@export var sway_amount: float = 0.12

var state: State = State.IDLE
var model: ModelVisual
var drop: float = 1.5
var _timer: float = 0.0
var _cool: float = 0.0
var _time: float = 0.0
var _b := {}
var _eye_light: OmniLight3D
## Isırıkta tavanla model tepesi arasında uzayan sap.
var _stem: MeshInstance3D


func _enemy_ready() -> void:
	max_hp = 2
	hp = 2
	knockback_scale = 0.0
	collision_layer = 0
	drop = idle_drop
	_time = randf() * TAU
	_place_head()


func _build_visual() -> void:
	hurtbox_size = Vector3(0.9, 0.9, 0.9)
	hurtbox_offset = Vector3.DOWN * idle_drop
	if ResourceLoader.exists(MODEL_PATH):
		model = ModelVisual.spawn(visual, MODEL_PATH, Vector3.BACK, true)
		for n: String in ["tripo__Head_0", "tripo__Head_1", "tripo__Head_2", "tripo__Head_3", "bone_5", "bone_7", "bone_8", "tripo__Head_4"]:
			_b[n] = model.bone(n)
	else:
		var stem := CylinderMesh.new()
		stem.top_radius = 0.06
		stem.bottom_radius = 0.06
		stem.height = 1.0
		_mesh(stem, Color("3f7a3a"), Vector3.DOWN * 0.5)
		var head := SphereMesh.new()
		head.radius = 0.35
		head.height = 0.7
		_mesh(head, Color("5a1e5c"), Vector3.DOWN * 1.2)
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.05
	stem_mesh.bottom_radius = 0.05
	stem_mesh.height = 1.0
	stem_mesh.radial_segments = 6
	_stem = _mesh(stem_mesh, Color("3f5a34"), Vector3.ZERO)
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = Color("c9d93b")
	_eye_light.omni_range = 2.5
	_eye_light.light_energy = 0.0
	visual.add_child(_eye_light)


func _enemy_physics(delta: float) -> void:
	if bite_drop < 0.0:
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.DOWN * 0.1,
				global_position + Vector3.DOWN * 30.0, Layers.WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		bite_drop = (global_position.y - (hit["position"] as Vector3).y - bite_clearance) if not hit.is_empty() else idle_drop + 1.5
		bite_drop = maxf(bite_drop, idle_drop + 0.5)
		trigger_depth = bite_drop + 1.5
	_cool = maxf(_cool - delta, 0.0)
	_timer -= delta
	if is_staggered() and state != State.RECOVER:
		_begin(State.RECOVER)
	match state:
		State.IDLE:
			drop = lerpf(drop, idle_drop, minf(1.0, delta * 3.0))
			if _cool <= 0.0 and _player_below():
				_begin(State.TELL)
		State.TELL:
			drop = lerpf(drop, idle_drop - 0.35, minf(1.0, delta * 8.0))   # geri çekilip yay gibi gerilir
			if _timer <= 0.0:
				_begin(State.BITE)
		State.BITE:
			var t := 1.0 - clampf(_timer / bite_time, 0.0, 1.0)
			drop = lerpf(idle_drop - 0.35, bite_drop, ease(t, 0.4))
			if _timer <= -hold_time:
				_begin(State.RECOVER)
		State.RECOVER:
			drop = lerpf(drop, idle_drop, minf(1.0, delta * 2.5))
			if _timer <= 0.0:
				_cool = cooldown
				_begin(State.IDLE)
	_place_head()


func _begin(next: State) -> void:
	state = next
	match next:
		State.TELL: _timer = tell_time
		State.BITE: _timer = bite_time
		State.RECOVER: _timer = recover_time
		_: _timer = 0.0


func _player_below() -> bool:
	var p := _find_player()
	if p == null or p.is_dead():
		return false
	var head := global_position + Vector3.DOWN * drop
	var d := p.global_position - head
	return absf(d.x) < trigger_half_width and d.y < 0.5 and d.y > -trigger_depth and absf(d.z) < 2.0


func _place_head() -> void:
	hurtbox.position = Vector3.DOWN * drop
	if model != null:
		# Gövde boyu sabit; ısırıkta tüm model aşağı uzanır, gövdenin üstü tavanın içine gizlenir
		var extra := maxf(drop - idle_drop, 0.0)
		model.position = Vector3.DOWN * (drop - idle_drop + MODEL_HEIGHT)
		_stem.visible = extra > 0.02
		_stem.scale = Vector3(1.0, maxf(extra, 0.01), 1.0)
		_stem.position = Vector3.DOWN * extra * 0.5
	else:
		_stem.visible = false
	_eye_light.position = Vector3.DOWN * drop


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	var tell := state == State.TELL
	var biting := state == State.BITE
	_eye_light.light_energy = lerpf(_eye_light.light_energy, 2.5 if (tell or biting) else 0.3, minf(1.0, delta * 10.0))
	if model == null:
		return
	var side := Vector3.BACK
	var fwd := Vector3.RIGHT
	# sarmaşık gibi salınım: tepeden aşağı artan, iki eksende farklı frekans
	var sway := sway_amount * (0.3 if biting else 1.0)
	for i in 3:
		var bn: String = ["tripo__Head_0", "tripo__Head_1", "tripo__Head_2"][i]
		model.add_rotation(_b[bn], side, sin(_time * 1.3 + i * 0.7) * sway)
		model.add_rotation(_b[bn], fwd, sin(_time * 0.9 + i * 0.5) * sway * 0.6)
	# uyarı: titreme
	if tell:
		model.add_rotation(_b["tripo__Head_3"], side, sin(_time * 55.0) * 0.12)
	# taç yaprakları / çene: uyarıda açılır, ısırıkta kapanır
	var open := 0.0
	if tell:
		open = 0.7
	elif biting:
		open = -0.25
	for bn: String in ["bone_5", "bone_7", "bone_8", "tripo__Head_4"]:
		var bpos := model.bone_rest_position(_b[bn]) - model.bone_rest_position(_b["tripo__Head_3"])
		var axis := Vector3.UP.cross(Vector3(bpos.x, 0.0, bpos.z)).normalized()
		if axis.length_squared() < 0.5:
			axis = side
		model.add_rotation(_b[bn], axis, open)
	model.apply_pose()


func is_biting() -> bool:
	return state == State.BITE


func is_telling() -> bool:
	return state == State.TELL


func get_head_position() -> Vector3:
	return global_position + Vector3.DOWN * drop
