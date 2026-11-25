class_name GrappleFlower
extends VineAnchor
## Kanca Çiçeği (docs/03 §2.1): Kamçı Kancası ile uzaktan tutulur, sarkaç başlar.
## Otomatik yakalanmaz (VineAnchor grubundan çıkar); yetenek yokken de görünür (docs/02:
## "her kapı açılmadan önce gösterilir"). Hedef seçilince parlar.

const FLOWER_GROUP: StringName = &"grapple_flower"

@export var petal_color: Color = Color("4fb3a9")
@export var target_color: Color = Color("e8a33d")

var _petal_mat: StandardMaterial3D
var _light: OmniLight3D
var _targeted: bool = false


func _ready() -> void:
	vine_length = 0.4
	idle_sway = 0.0
	vine_color = Color("3f7a3a")
	super._ready()
	remove_from_group(VineAnchor.GROUP)
	add_to_group(FLOWER_GROUP)
	_build_flower()


func is_targeted() -> bool:
	return _targeted


func set_targeted(value: bool) -> void:
	_targeted = value
	if _petal_mat == null:
		return
	var c := target_color if value else petal_color
	_petal_mat.albedo_color = c
	_petal_mat.emission = c
	_petal_mat.emission_energy_multiplier = 3.5 if value else 1.2
	_light.light_color = c
	_light.light_energy = 2.0 if value else 0.8


func _build_flower() -> void:
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
