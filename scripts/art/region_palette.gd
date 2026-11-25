class_name RegionPalette
extends Resource
## Bölge paleti (docs/02 bölge kartı renkleri + docs/08 paleti). Stilize shader'ın tonlarını ve
## ortam ışığını/sisini tek kaynaktan besler. Her bölge bir .tres (data/art/palette_<bölge>.tres).

@export_group("Shader")
@export var shadow_tint: Color = Color("2b1e3f")
@export var region_tint: Color = Color("7a7096")
@export var rim_color: Color = Color("4fb3a9")
@export_range(0.0, 2.0) var rim_strength: float = 0.35
@export_range(0.0, 1.0) var palette_pull: float = 0.1

@export_group("Ortam")
@export var sky_top: Color = Color("161a30")
@export var sky_horizon: Color = Color("3a3a5c")
@export var ground_bottom: Color = Color("0c0814")
@export var ground_horizon: Color = Color("2b1e3f")
@export var ambient_energy: float = 0.7
@export var fog_color: Color = Color("2b1e3f")
@export var fog_density: float = 0.009
@export var sun_color: Color = Color("eae4ff")
@export var sun_energy: float = 1.05
@export var sun_rotation_deg: Vector3 = Vector3(-55.0, 35.0, 0.0)
@export var glow_intensity: float = 0.9
## Vurgu rengi (Öz altını) — ışık kaynakları ve önemli nesneler.
@export var accent: Color = Color("e8a33d")


## Bu paleti bir stilize ShaderMaterial'a uygular.
func apply_to(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter(&"shadow_tint", shadow_tint)
	mat.set_shader_parameter(&"region_tint", region_tint)
	mat.set_shader_parameter(&"rim_color", rim_color)
	mat.set_shader_parameter(&"rim_strength", rim_strength)
	mat.set_shader_parameter(&"palette_pull", palette_pull)
