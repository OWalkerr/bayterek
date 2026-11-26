class_name Stylizer
extends RefCounted
## Çalışma zamanında StandardMaterial3D'leri ortak stilize shader'a çevirir (docs/07 §6).
## Greybox kutular, düşmanlar, oyuncu ve ileride gelen AI modelleri aynı yoldan geçer → tek stil.
## Çevrilmez: saydam / gölgesiz (efekt) materyaller ve meta "no_stylize" olanlar (rengi canlı değişen
## materyaller: çürük sarmaşık, kanca çiçeği). Aynı kaynak materyal bir kez çevrilir (önbellek).

const SHADER: Shader = preload("res://assets/shaders/stylized_lit.gdshader")
const DEFAULT_PALETTE: String = "res://data/art/palette_kok_dibi.tres"
const META_SKIP: StringName = &"no_stylize"
const META_SOURCE: StringName = &"stylized_from"
## Rüzgârlı bitki materyali: {strength, height, speed, push} → shader rüzgâr parametreleri.
const META_WIND: StringName = &"wind"

static var palette: RegionPalette = null
static var _cache: Dictionary = {}     # kaynak materyal instance_id -> ShaderMaterial


static func get_palette() -> RegionPalette:
	if palette == null:
		palette = load(DEFAULT_PALETTE) as RegionPalette
	return palette


static func set_palette(p: RegionPalette) -> void:
	palette = p
	_cache.clear()


## `root` altındaki tüm MeshInstance3D'leri çevirir. Çevrilen materyal sayısını döndürür.
static func apply(root: Node) -> int:
	var count := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var mi := n as MeshInstance3D
		if mi != null:
			count += _apply_mesh(mi)
		for c: Node in n.get_children():
			stack.append(c)
	return count


## Tek materyal: çevrilebiliyorsa stilize ShaderMaterial, değilse kendisi.
static func stylize_material(source: Material) -> Material:
	var std := source as StandardMaterial3D
	if std == null or not can_convert(std):
		return source
	var key := std.get_instance_id()
	if _cache.has(key) and is_instance_valid(_cache[key]):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	get_palette().apply_to(mat)
	mat.set_shader_parameter(&"albedo", std.albedo_color)
	if std.albedo_texture != null:
		mat.set_shader_parameter(&"albedo_texture", std.albedo_texture)
		mat.set_shader_parameter(&"use_texture", true)
	if std.emission_enabled:
		mat.set_shader_parameter(&"emission_color", std.emission)
		mat.set_shader_parameter(&"emission_energy", std.emission_energy_multiplier)
	if std.has_meta(META_WIND):
		# Rüzgârlı bitki: {strength, height, speed?}
		var w: Dictionary = std.get_meta(META_WIND)
		mat.set_shader_parameter(&"wind_strength", float(w.get("strength", 0.1)))
		mat.set_shader_parameter(&"wind_height", float(w.get("height", 1.0)))
		mat.set_shader_parameter(&"wind_speed", float(w.get("speed", 1.6)))
		mat.set_shader_parameter(&"push_strength", float(w.get("push", 0.5)))
	mat.set_meta(META_SOURCE, std)
	_cache[key] = mat
	return mat


static func can_convert(std: StandardMaterial3D) -> bool:
	if std.has_meta(META_SKIP):
		return false
	if std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	if std.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return false
	return true


static func is_stylized(mat: Material) -> bool:
	var sm := mat as ShaderMaterial
	return sm != null and sm.shader == SHADER


static func _apply_mesh(mi: MeshInstance3D) -> int:
	var count := 0
	if mi.material_override != null:
		var o := stylize_material(mi.material_override)
		if o != mi.material_override:
			mi.material_override = o
			count += 1
		return count
	if mi.mesh == null:
		return 0
	for i in mi.mesh.get_surface_count():
		var src: Material = mi.get_surface_override_material(i)
		if src == null:
			src = mi.mesh.surface_get_material(i)
		if src == null:
			continue
		var dst := stylize_material(src)
		if dst != src:
			mi.set_surface_override_material(i, dst)
			count += 1
	return count
