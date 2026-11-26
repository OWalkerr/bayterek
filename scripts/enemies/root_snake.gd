class_name RootSnake
extends Enemy
## Kök Yılanı (docs/04): duvar deliğinden fırlar. "Zamanlama?"
## Düğüm konumu = deliğin ağzı; `out_dir` fırlama yönü (yandan oyunda genelde arka duvardan +Z:
## oyuncunun koridorunu keser). Döngü: GİZLİ → UYARI (delik parlar, toz, kafa görünür ≥ 0.6 sn)
## → FIRLAMA → AÇIKTA (vurulabilir, gövde dalgalanır) → GERİ ÇEKİLME. Vurulunca hemen geri çekilir.
## Yılanın arka kısmı duvarın içinde kalır (duvar örter) → gövde "delikten akıyor" gibi görünür.

enum State { HIDDEN, TELL, LUNGE, OUT, RETRACT }

const MODEL_PATH: String = "res://assets/models/enemies/enm_root_snake.glb"

@export var out_dir: Vector3 = Vector3.BACK
@export var reach: float = 2.4
@export var hidden_time: float = 1.6
@export var tell_time: float = 0.7
@export var lunge_time: float = 0.16
@export var out_time: float = 0.9
@export var retract_time: float = 0.45
## Oyuncu bu yarıçap içindeyken döngü çalışır (uzaktayken delikte bekler).
@export var wake_range: float = 9.0
@export var start_delay: float = 0.0

var state: State = State.HIDDEN
var model: ModelVisual
var extend: float = 0.0
var _timer: float = 0.0
var _time: float = 0.0
var _chain: Array[int] = []
var _tail: Array[int] = []
var _hole_light: OmniLight3D
var _dust: CPUParticles3D


func _enemy_ready() -> void:
	max_hp = 2
	hp = 2
	knockback_scale = 0.0
	collision_layer = 0
	out_dir = out_dir.normalized()
	_timer = hidden_time + start_delay
	if model != null:
		model.face(out_dir, true)
	_place()


func _build_visual() -> void:
	hurtbox_size = Vector3(0.8, 0.8, 0.8)
	hurtbox_offset = Vector3.ZERO
	if ResourceLoader.exists(MODEL_PATH):
		# Model -X'e bakıyor (kafa -X ucunda), uzunluk 3 m; orijin gövde ortasında
		model = ModelVisual.spawn(visual, MODEL_PATH, Vector3.LEFT, true)
		model.turn_speed = 0.0
		for n: String in ["bone_9", "bone_8", "bone_7", "bone_6", "bone_5", "bone_4"]:
			_chain.append(model.bone(n))     # kafadan geriye
		for n: String in ["bone_1", "bone_2", "bone_3"]:
			_tail.append(model.bone(n))
	else:
		var body := CapsuleMesh.new()
		body.radius = 0.25
		body.height = 2.5
		var mi := _mesh(body, Color("4a2a3a"), Vector3.ZERO)
		mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	# delik: koyu disk + uyarı ışığı + toz
	var hole_mat := StandardMaterial3D.new()
	hole_mat.albedo_color = Color("120a18")
	hole_mat.set_meta(Stylizer.META_SKIP, true)
	hole_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var hole := CylinderMesh.new()
	hole.top_radius = 0.55
	hole.bottom_radius = 0.55
	hole.height = 0.02
	hole.material = hole_mat
	var hole_mi := MeshInstance3D.new()
	hole_mi.mesh = hole
	add_child(hole_mi)
	hole_mi.basis = Basis(Quaternion(Vector3.UP, out_dir.normalized()))
	_hole_light = OmniLight3D.new()
	_hole_light.light_color = Color("c9d93b")
	_hole_light.omni_range = 3.0
	_hole_light.light_energy = 0.0
	add_child(_hole_light)
	_dust = FxLibrary.dust_burst(Color("6b4a2f"), 14)
	add_child(_dust)


func _enemy_physics(delta: float) -> void:
	_timer -= delta
	if is_staggered() and (state == State.OUT or state == State.LUNGE):
		_begin(State.RETRACT)
	match state:
		State.HIDDEN:
			extend = move_toward(extend, 0.0, delta * 4.0)
			if _timer <= 0.0 and _player_near():
				_begin(State.TELL)
		State.TELL:
			extend = lerpf(extend, 0.35, minf(1.0, delta * 6.0))   # kafa delikten görünür
			if _timer <= 0.0:
				_begin(State.LUNGE)
		State.LUNGE:
			extend = lerpf(0.35, reach, ease(1.0 - clampf(_timer / lunge_time, 0.0, 1.0), 0.5))
			if _timer <= 0.0:
				_begin(State.OUT)
		State.OUT:
			extend = reach
			if _timer <= 0.0:
				_begin(State.RETRACT)
		State.RETRACT:
			extend = lerpf(extend, 0.0, minf(1.0, delta * 7.0))
			if _timer <= 0.0:
				_begin(State.HIDDEN)
	_place()


func _begin(next: State) -> void:
	state = next
	match next:
		State.HIDDEN: _timer = hidden_time
		State.TELL:
			_timer = tell_time
			_dust.restart()
		State.LUNGE:
			_timer = lunge_time
			_dust.restart()
		State.OUT: _timer = out_time
		State.RETRACT: _timer = retract_time


func _player_near() -> bool:
	var p := _find_player()
	return p != null and not p.is_dead() and p.global_position.distance_to(global_position) < wake_range


## Kafa delikten `extend` m dışarıda. Model kafası -X ucunda (≈ 1.5 m) → model merkezi kafanın
## 1.5 m gerisinde (duvarın içinde).
func _place() -> void:
	var head := out_dir * extend
	hurtbox.position = head
	var exposed := extend > 0.6
	if hurtbox.monitorable != exposed:
		hurtbox.set_deferred(&"monitorable", exposed)
	contact_damage = 1 if extend > 0.3 else 0
	if model != null:
		model.position = head - out_dir * 1.45
		model.visible = extend > 0.02
	_hole_light.position = out_dir * 0.3


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	var tell := state == State.TELL
	_hole_light.light_energy = lerpf(_hole_light.light_energy, 2.2 + sin(_time * 30.0) * 0.6 if tell else 0.15,
			minf(1.0, delta * 10.0))
	if model == null:
		return
	# gövde dalgası: yukarı-aşağı (yandan okunur) + hafif yan; açıkta hızlı, uyarıda titrek
	var speed := 9.0 if state == State.OUT else (40.0 if tell else 5.0)
	var amp := 0.22 if state == State.OUT else (0.05 if tell else 0.12)
	for i in _chain.size():
		model.add_rotation(_chain[i], Vector3.BACK, sin(_time * speed - i * 0.9) * amp)
		model.add_rotation(_chain[i], Vector3.UP, sin(_time * speed * 0.6 - i * 0.7) * amp * 0.5)
	for i in _tail.size():
		model.add_rotation(_tail[i], Vector3.BACK, sin(_time * speed - (i + _chain.size()) * 0.9) * amp)
	# fırlarken kafa ağzı açar gibi geri kalkar
	if state == State.LUNGE or state == State.OUT:
		model.add_rotation(_chain[0], Vector3.BACK, -0.3)
	model.apply_pose()


func is_out() -> bool:
	return extend > 0.6


func is_telling() -> bool:
	return state == State.TELL


func get_head_position() -> Vector3:
	return global_position + out_dir * extend
