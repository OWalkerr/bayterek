class_name GrappleFlower
extends VineAnchor
## Kanca Çiçeği (docs/03 §2.1): Kamçı Kancası ile uzaktan tutulur, sarkaç başlar.
## Otomatik yakalanmaz (VineAnchor grubundan çıkar); yetenek yokken de görünür (docs/02:
## "her kapı açılmadan önce gösterilir"). Hedef seçilince parlar.

const FLOWER_GROUP: StringName = &"grapple_flower"
const MODEL_PATH: String = "res://assets/models/props/prop_grapple_flower.glb"
## Model boyu (import 0.8): tepe = tutturma noktası, tomurcuk ≈ 0.55 m aşağıda.
const MODEL_HEIGHT: float = 0.8

@export var petal_color: Color = Color("4fb3a9")
@export var target_color: Color = Color("e8a33d")

## Alt sınıflar (RootRock) kendi görselini kurar.
var use_model: bool = true
var model: ModelVisual
var _petal_mat: StandardMaterial3D
var _light: OmniLight3D
var _targeted: bool = false
var _sway_t: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	vine_length = 0.4
	idle_sway = 0.0
	vine_color = Color("3f7a3a")
	super._ready()
	remove_from_group(VineAnchor.GROUP)
	add_to_group(FLOWER_GROUP)
	_build_flower()


func _process(delta: float) -> void:
	super._process(delta)
	if model == null or delta <= 0.0:
		return
	# Asılı çiçek kendi sapında hafifçe sallanır; hedeflenince nabız gibi büyüyüp küçülür
	_sway_t += delta
	model.rotation = Vector3(sin(_sway_t * 1.1) * 0.06, 0.0, sin(_sway_t * 1.4 + 0.6) * 0.09)
	_pulse = move_toward(_pulse, 1.0 if _targeted else 0.0, delta * 4.0)
	var s := 1.0 + _pulse * (0.08 + 0.05 * sin(_sway_t * 9.0))
	model.scale = Vector3.ONE * s


func _on_grab_changed(value: bool) -> void:
	if model != null:
		_vine_mesh.visible = value


func is_targeted() -> bool:
	return _targeted


func set_targeted(value: bool) -> void:
	_targeted = value
	if _petal_mat == null:
		return
	var c := target_color if value else petal_color
	_petal_mat.albedo_color = Color(c, 0.9 if value else 0.35) if model != null else c
	_petal_mat.emission = c
	_petal_mat.emission_energy_multiplier = 3.5 if value else 1.2
	_light.light_color = c
	_light.light_energy = 2.0 if value else 0.8


func _build_flower() -> void:
	if use_model and ResourceLoader.exists(MODEL_PATH):
		_build_model_flower()
		return
	_petal_mat = StandardMaterial3D.new()
	_petal_mat.set_meta(Stylizer.META_SKIP, true)   # hedef vurgusunda rengi değişir
	_petal_mat.emission_enabled = true
	var petal := TorusMesh.new()
	petal.inner_radius = 0.18
	petal.outer_radius = 0.5
	petal.material = _petal_mat
	var mi := MeshInstance3D.new()
	mi.mesh = petal
	mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(mi)
	_light = OmniLight3D.new()
	_light.omni_range = 4.0
	add_child(_light)
	set_targeted(false)


## Model: tepesi tutturma noktasında. Hedef vurgusu modelin üstünde yumuşak bir hale (saydam,
## stilize edilmez) + ışık ile → modelin kendi dokusu bozulmaz.
func _build_model_flower() -> void:
	model = ModelVisual.spawn(self, MODEL_PATH, Vector3.BACK)
	model.pivot.position = Vector3.DOWN * MODEL_HEIGHT
	_knot.visible = false
	_vine_mesh.visible = false
	_petal_mat = StandardMaterial3D.new()
	_petal_mat.set_meta(Stylizer.META_SKIP, true)
	_petal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_petal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_petal_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_petal_mat.albedo_texture = FxLibrary.soft_texture()
	_petal_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_petal_mat.emission_enabled = true
	var halo := QuadMesh.new()
	halo.size = Vector2(1.3, 1.3)
	halo.material = _petal_mat
	var mi := MeshInstance3D.new()
	mi.mesh = halo
	mi.position = Vector3.DOWN * 0.55
	model.add_child(mi)
	_light = OmniLight3D.new()
	_light.omni_range = 4.0
	_light.position = Vector3.DOWN * 0.55
	add_child(_light)
	set_targeted(false)
