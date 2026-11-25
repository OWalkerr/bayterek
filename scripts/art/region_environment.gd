class_name RegionEnvironment
extends Node3D
## Bölge ortamı (docs/02 atmosfer, docs/07 "ışık"): gökyüzü, ortam ışığı, sis, parıltı ve yönlü ışık
## RegionPalette'ten kurulur. Web (Compatibility) bütçesi: 1 gölgeli yönlü ışık (docs/06).
## "Yüksek kalite" (Forward+): SSAO + hacimsel sis ek olarak açılır; web'de kapalı kalır.

var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var palette: RegionPalette


func _ready() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.environment = Environment.new()
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)


func is_high_quality() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


func apply_palette(p: RegionPalette) -> void:
	palette = p
	if world_environment == null:
		_ready()
	var env := world_environment.environment
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = p.sky_top
	sky_mat.sky_horizon_color = p.sky_horizon
	sky_mat.ground_bottom_color = p.ground_bottom
	sky_mat.ground_horizon_color = p.ground_horizon
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = p.ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = p.glow_intensity
	env.fog_enabled = true
	env.fog_light_color = p.fog_color
	env.fog_density = p.fog_density
	var hq := is_high_quality()
	env.ssao_enabled = hq
	env.volumetric_fog_enabled = hq
	if hq:
		env.volumetric_fog_density = p.fog_density * 0.5
		env.volumetric_fog_albedo = p.fog_color
	sun.rotation_degrees = p.sun_rotation_deg
	sun.light_color = p.sun_color
	sun.light_energy = p.sun_energy
