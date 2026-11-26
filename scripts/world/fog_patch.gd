class_name FogPatch
extends Node3D
## Yerel sis öbeği (docs/08 ortam): yumuşak billboard pufları bir kutuda süzülür. Oyuncu içinden
## geçince puflar ondan uzağa itilir, hızına göre sürüklenir ve incelir; oyuncu gidince yavaşça
## geri toplanır → "yumuşak" his. Hacimsel sis (FogVolume) web'de (Compatibility) yok; bu yöntem
## iki arka uçta aynı görünür. Puf saydamlığı GeometryInstance3D.transparency ile → tek materyal.

## Kutu boyutu (düğüm merkezli; alt yüz = düğüm konumu − size.y/2).
@export var size: Vector3 = Vector3(8.0, 2.0, 3.0)
@export var color: Color = Color("b9b0d4")
@export var opacity: float = 0.42
@export var puff_size: float = 2.6
## Puf yoğunluğu (m² taban başına); üst sınır max_puffs.
@export var density: float = 0.45
@export var max_puffs: int = 36
## İtme yarıçapı ve gücü; geri toplanma hızı (küçük = daha yavaş, daha yumuşak).
@export var push_radius: float = 2.3
@export var push_strength: float = 10.0
@export var drag_from_player: float = 0.35
@export var return_rate: float = 0.45
@export var clear_alpha: float = 0.12
@export var drift_speed: float = 0.25

var _puffs: Array[MeshInstance3D] = []
var _home: PackedVector3Array = []
var _offset: PackedVector3Array = []
var _vel: PackedVector3Array = []
var _alpha: PackedFloat32Array = []
var _phase: PackedFloat32Array = []
var _time: float = 0.0
var _player: Node3D
static var _material: StandardMaterial3D


func _ready() -> void:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_material.albedo_texture = FxLibrary.soft_texture()
		_material.vertex_color_use_as_albedo = false
		_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_material.set_meta(Stylizer.META_SKIP, true)
	var mat := _material.duplicate() as StandardMaterial3D
	mat.albedo_color = Color(color, opacity)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(global_position.snapped(Vector3.ONE * 0.1)))
	var count := clampi(int(size.x * size.z * density), 4, max_puffs)
	for i in count:
		var q := QuadMesh.new()
		var s := puff_size * rng.randf_range(0.7, 1.3)
		q.size = Vector2(s * 1.4, s)
		q.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var h := Vector3(rng.randf_range(-0.5, 0.5) * size.x, rng.randf_range(-0.5, 0.2) * size.y,
				rng.randf_range(-0.5, 0.5) * size.z)
		mi.position = h
		add_child(mi)
		_puffs.append(mi)
		_home.append(h)
		_offset.append(Vector3.ZERO)
		_vel.append(Vector3.ZERO)
		_alpha.append(1.0)
		_phase.append(rng.randf() * TAU)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	var p_local := Vector3(0.0, -1000.0, 0.0)
	var p_vel := Vector3.ZERO
	if _player != null:
		p_local = to_local(_player.global_position + Vector3.UP * 0.8)
		var body := _player as CharacterBody3D
		if body != null:
			p_vel = global_transform.basis.inverse() * body.velocity
	var damp := exp(-2.5 * delta)
	var ret := 1.0 - exp(-return_rate * delta)
	for i in _puffs.size():
		var drift := Vector3(sin(_time * drift_speed + _phase[i]) * 0.5, sin(_time * drift_speed * 0.7 + _phase[i] * 1.7) * 0.15,
				cos(_time * drift_speed * 0.8 + _phase[i]) * 0.3)
		var pos := _home[i] + _offset[i]
		var d := pos - p_local
		var dist := d.length()
		var near := 1.0 - smoothstep(0.0, push_radius, dist)
		if near > 0.0:
			var away := d / maxf(dist, 0.05)
			away.y *= 0.4
			_vel[i] += (away * push_strength * near + p_vel * drag_from_player * near) * delta
		_vel[i] *= damp
		_offset[i] += _vel[i] * delta
		_offset[i] = _offset[i].lerp(drift, ret)
		# incelme: hızlı açılır, yavaş kapanır
		var target := lerpf(1.0, clear_alpha, 1.0 - smoothstep(push_radius * 0.3, push_radius * 1.3, dist))
		var rate := 6.0 if target < _alpha[i] else 0.6
		_alpha[i] = lerpf(_alpha[i], target, 1.0 - exp(-rate * delta))
		_puffs[i].position = _home[i] + _offset[i]
		_puffs[i].transparency = 1.0 - _alpha[i]


## Test/teşhis: dünya noktasının `radius` yakınındaki pufların ortalama görünürlüğü (0..1).
func density_near(world_point: Vector3, radius: float = 2.0) -> float:
	var p := to_local(world_point)
	var sum := 0.0
	var n := 0
	for i in _puffs.size():
		if (_home[i] - p).length() < radius:
			sum += _alpha[i]
			n += 1
	return sum / n if n > 0 else 1.0


## Test: `world_point` yakınındaki puflar evlerinden ortalama ne kadar uzaklaştı (m).
func mean_displacement(world_point: Vector3, radius: float = 3.0) -> float:
	var p := to_local(world_point)
	var sum := 0.0
	var n := 0
	for i in _puffs.size():
		if (_home[i] - p).length() < radius:
			sum += _offset[i].length()
			n += 1
	return sum / n if n > 0 else 0.0


func puff_count() -> int:
	return _puffs.size()
