// BAYTEREK ortak stilize shader'ı (docs/07 §6). Farklı AI çıktılarını ve greybox'u tek aileye sokar:
//  - 3 basamaklı ışık rampası (toon): gölge → ara → aydınlık, yumuşak geçişli
//  - gölge tarafı bölge gölge rengine (kök moru) boyanır, siyaha değil
//  - kenar ışığı (rim / fresnel), mantar ışığı tonunda — siluet okunurluğu (docs/07 kalite kontrol)
//  - palet tonlama: rengi parlaklığını koruyarak bölge tonuna çeker
//  - vuruş parlaması (flash) — düşman/boss isabet geri bildirimi
// Compatibility (web) ve Forward+ ile uyumlu: yalnızca standart spatial + light() kullanır.
shader_type spatial;
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform bool use_texture = false;

uniform vec4 shadow_tint : source_color = vec4(0.17, 0.12, 0.25, 1.0);
uniform float band_low : hint_range(-1.0, 1.0) = 0.05;
uniform float band_high : hint_range(-1.0, 1.0) = 0.55;
uniform float band_softness : hint_range(0.0, 0.5) = 0.05;
uniform float mid_level : hint_range(0.0, 1.0) = 0.55;

uniform vec4 rim_color : source_color = vec4(0.31, 0.70, 0.66, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

uniform vec4 region_tint : source_color = vec4(0.45, 0.38, 0.58, 1.0);
uniform float palette_pull : hint_range(0.0, 1.0) = 0.2;

uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = albedo.rgb;
	if (use_texture) {
		c *= texture(albedo_texture, UV).rgb;
	}
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, region_tint.rgb * luma * 1.9, palette_pull);
	c = mix(c, vec3(1.0), flash);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = emission_color.rgb * emission_energy + rim_color.rgb * fres * rim_strength + vec3(flash * 0.5);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float low = smoothstep(band_low - band_softness, band_low + band_softness, ndl);
	float high = smoothstep(band_high - band_softness, band_high + band_softness, ndl);
	float ramp = mix(low * mid_level, 1.0, high) * ATTENUATION;
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), ramp);
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * shade;
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * ramp;
	}
}
