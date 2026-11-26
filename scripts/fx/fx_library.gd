class_name FxLibrary
extends RefCounted
## Hazır parçacık efektleri (docs/08 "Juice" + ortam). Hepsi CPUParticles3D: web (Compatibility)
## ve masaüstünde aynı davranır, GPU parçacık derlemesi gerekmez. Dokular kodla üretilir
## (yumuşak radyal leke) → sanat dosyası gerekmez. Materyaller saydam → Stylizer atlar.

static var _soft: Texture2D
static var _mats: Dictionary = {}


## 64 px yumuşak radyal leke (merkez beyaz → kenar saydam).
static func soft_texture() -> Texture2D:
	if _soft != null:
		return _soft
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_soft = t
	return t


## Parçacık materyali (billboard, köşe rengi, yumuşak doku). additive = ışıyan (ateş, ateşböceği).
static func particle_material(additive: bool) -> StandardMaterial3D:
	var key := "add" if additive else "mix"
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_texture()
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.set_meta(Stylizer.META_SKIP, true)
	_mats[key] = m
	return m


static func _base(amount: int, lifetime: float, additive: bool, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	q.material = particle_material(additive)
	p.mesh = q
	p.local_coords = false
	return p


static func _ramp(colors: Array[Color], offsets: PackedFloat32Array = PackedFloat32Array()) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	if offsets.size() == colors.size():
		g.offsets = offsets
	else:
		var o := PackedFloat32Array()
		for i in colors.size():
			o.append(float(i) / float(colors.size() - 1))
		g.offsets = o
	return g


static func _curve(points: Array[Vector2]) -> Curve:
	var c := Curve.new()
	for pt: Vector2 in points:
		c.add_point(pt)
	return c


## Ocak / mangal alevi: yükselen, küçülen, altından kırmızıya dönen ışıyan lekeler.
static func fire(scale: float = 1.0) -> CPUParticles3D:
	var p := _base(26, 0.75, true, 0.55 * scale)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.22 * scale
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.6 * scale
	p.initial_velocity_max = 1.3 * scale
	p.gravity = Vector3.UP * 1.2 * scale
	p.damping_min = 0.5
	p.damping_max = 1.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	p.scale_amount_curve = _curve([Vector2(0.0, 0.6), Vector2(0.25, 1.0), Vector2(1.0, 0.1)])
	p.color_ramp = _ramp([Color(1.0, 0.95, 0.7, 0.0), Color(1.0, 0.78, 0.3, 0.95), Color(0.95, 0.4, 0.12, 0.7),
			Color(0.5, 0.1, 0.15, 0.0)], PackedFloat32Array([0.0, 0.12, 0.55, 1.0]))
	p.preprocess = 1.0
	return p


## Yükselen kıvılcımlar (ateşin üstünde savrulan küçük noktalar).
static func embers(scale: float = 1.0) -> CPUParticles3D:
	var p := _base(10, 2.0, true, 0.09 * scale)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3 * scale
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 0.8 * scale
	p.initial_velocity_max = 2.0 * scale
	p.gravity = Vector3(0.3, 0.4, 0.0)
	p.damping_min = 0.3
	p.damping_max = 0.8
	p.tangential_accel_min = -1.5
	p.tangential_accel_max = 1.5
	p.color_ramp = _ramp([Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.55, 0.2, 0.8), Color(0.8, 0.2, 0.1, 0.0)])
	p.preprocess = 2.0
	return p


## Ateşin üstündeki yavaş, mor-gri duman.
static func smoke(scale: float = 1.0) -> CPUParticles3D:
	var p := _base(7, 3.0, false, 0.9 * scale)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2 * scale
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0.15, 0.25, 0.0)
	p.scale_amount_curve = _curve([Vector2(0.0, 0.4), Vector2(1.0, 1.6)])
	p.color_ramp = _ramp([Color(0.3, 0.24, 0.35, 0.0), Color(0.3, 0.24, 0.35, 0.22), Color(0.25, 0.2, 0.3, 0.0)])
	p.preprocess = 3.0
	return p


## Tek seferlik toz patlaması (iniş, yılan deliği, kırılan şey). `restart()` ile tetiklenir.
static func dust_burst(color: Color = Color("8a7a6a"), amount: int = 12, size: float = 0.45) -> CPUParticles3D:
	var p := _base(amount, 0.7, false, size)
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.gravity = Vector3.DOWN * 2.0
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_curve = _curve([Vector2(0.0, 0.5), Vector2(1.0, 1.4)])
	p.color_ramp = _ramp([Color(color, 0.55), Color(color, 0.0)])
	return p


## Ölüm / patlama pufu (ışıyan, renkli).
static func puff(color: Color, amount: int = 16, size: float = 0.5) -> CPUParticles3D:
	var p := dust_burst(color, amount, size)
	p.mesh.material = particle_material(true)
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.color_ramp = _ramp([Color(color, 0.9), Color(color, 0.0)])
	return p


## Ortam: süzülen spor / ateşböceği (oda boyunca kutu). Sürekli, başlangıçta dolu.
static func motes(box: Vector3, color: Color, amount: int = 40, size: float = 0.12) -> CPUParticles3D:
	var p := _base(amount, 7.0, true, size)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box * 0.5
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.gravity = Vector3(0.05, 0.04, 0.0)
	p.tangential_accel_min = -0.2
	p.tangential_accel_max = 0.2
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.color_ramp = _ramp([Color(color, 0.0), Color(color, 0.9), Color(color, 0.7), Color(color, 0.0)],
			PackedFloat32Array([0.0, 0.2, 0.75, 1.0]))
	p.preprocess = 7.0
	return p


## Ortam: sarkan köklerden arada bir düşen yaprak / kabuk kırıntısı (yavaş, salınarak).
static func falling_leaves(box: Vector3, color: Color = Color("5e8c4a"), amount: int = 8) -> CPUParticles3D:
	var p := _base(amount, 6.0, false, 0.14)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box * 0.5
	p.direction = Vector3.DOWN
	p.spread = 30.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0.12, -0.35, 0.0)
	p.angular_velocity_min = -120.0
	p.angular_velocity_max = 120.0
	p.tangential_accel_min = -0.6
	p.tangential_accel_max = 0.6
	p.color_ramp = _ramp([Color(color, 0.0), Color(color, 0.9), Color(color, 0.9), Color(color, 0.0)],
			PackedFloat32Array([0.0, 0.1, 0.85, 1.0]))
	p.preprocess = 6.0
	return p


## Dünyaya bir kerelik efekt bırakır ve bitince siler.
static func spawn_oneshot(parent: Node, fx: CPUParticles3D, at: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		fx.free()
		return
	parent.add_child(fx)
	fx.global_position = at
	fx.emitting = true
	fx.finished.connect(fx.queue_free)
