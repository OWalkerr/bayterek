class_name PlayerTuning
extends Resource
## Alpay'ın tüm hareket sayıları. Değerler docs/03_MECHANICS.md ile senkron tutulur.
## Debug panelinden (F2) canlı değiştirilebilir; panel `LIVE_FIELDS` listesini kullanır.

## Canlı tuning panelinde gösterilecek alanlar: [ad, min, maks, adım]
const LIVE_FIELDS: Array = [
	["run_speed", 3.0, 12.0, 0.1],
	["ground_accel", 10.0, 150.0, 1.0],
	["ground_decel", 10.0, 150.0, 1.0],
	["air_control", 0.0, 1.0, 0.01],
	["air_overspeed_drag", 0.0, 20.0, 0.25],
	["jump_height", 1.0, 4.0, 0.05],
	["gravity_up", 8.0, 60.0, 0.5],
	["gravity_down", 8.0, 80.0, 0.5],
	["jump_cut", 0.0, 1.0, 0.01],
	["coyote_time", 0.0, 0.3, 0.01],
	["jump_buffer", 0.0, 0.3, 0.01],
	["max_fall_speed", 8.0, 40.0, 0.5],
	["grab_radius", 0.5, 3.0, 0.05],
	["swing_gravity", 8.0, 50.0, 0.5],
	["swing_pump", 0.0, 25.0, 0.25],
	["swing_damping", 0.0, 1.0, 0.01],
	["swing_max_angle_deg", 45.0, 140.0, 1.0],
	["release_boost", 0.5, 2.0, 0.01],
	["release_jump_bonus", 0.0, 12.0, 0.1],
	["perfect_release_bonus", 1.0, 1.6, 0.01],
	["climb_speed", 1.0, 8.0, 0.1],
	["climb_jump_speed_x", 0.0, 12.0, 0.1],
	["climb_jump_height", 0.5, 4.0, 0.05],
	["whip_range", 1.0, 5.0, 0.05],
	["attack_duration", 0.1, 0.6, 0.01],
	["combo_window", 0.0, 0.8, 0.01],
	["pogo_velocity", 4.0, 16.0, 0.1],
	["invuln_time", 0.0, 2.0, 0.05],
	["hit_stop_time", 0.0, 0.2, 0.005],
]

@export_group("Koşma")
@export var run_speed: float = 7.0
@export var ground_accel: float = 60.0
@export var ground_decel: float = 70.0
@export_range(0.0, 1.0) var air_control: float = 0.65
## Havada koşu hızının üstündeki momentumun azalma hızı (m/s²), girdi aynı yöndeyken.
@export var air_overspeed_drag: float = 3.0
@export var rail_pull: float = 10.0

@export_group("Zıplama")
@export var jump_height: float = 2.2
@export var gravity_up: float = 24.0
@export var gravity_down: float = 42.0
@export_range(0.0, 1.0) var jump_cut: float = 0.45
@export var coyote_time: float = 0.12
@export var jump_buffer: float = 0.12
@export var max_fall_speed: float = 22.0

@export_group("Sallanma")
@export var auto_grab: bool = true
@export var grab_radius: float = 1.4
## El, tutturma noktasının en az bu kadar altında olmalı (üstten yakalama yok).
@export var grab_min_below_anchor: float = 0.6
@export var min_rope: float = 2.0
@export var max_rope: float = 7.0
@export var swing_gravity: float = 24.0
@export var swing_pump: float = 9.0
@export var swing_damping: float = 0.15
@export var swing_max_angle_deg: float = 100.0
@export var rope_reel_speed: float = 3.0
@export var release_boost: float = 1.1
@export var release_jump_bonus: float = 6.0
@export var regrab_cooldown: float = 0.35
## Duvara/zemine çarpınca açısal hızın çarpanı (negatif = sekme).
@export var swing_bounce: float = -0.25

@export_group("Mükemmel bırakma")
## Salınımın ileri-yukarı kolunda bu açı aralığında zıplayarak bırakma = bonus (karar: 2026-11-25).
@export var perfect_release_min_deg: float = 35.0
@export var perfect_release_max_deg: float = 70.0
@export var perfect_release_bonus: float = 1.15

@export_group("Tırmanma")
@export var climb_grab_radius: float = 0.7
@export var climb_speed: float = 3.5
## Tırmanma sarmaşığından yana zıplamada yatay hız.
@export var climb_jump_speed_x: float = 6.5
@export var climb_jump_height: float = 1.8
## Yana zıplamadan sonra yatay girdinin hızı bozamadığı süre (Celeste tarzı kilit).
@export var climb_jump_lock: float = 0.15
## Tırmanma sarmaşığına ilk tutunmada aşağı kayma hızı sönümlenir; bu süre içinde yeniden tutunulamaz.
@export var climb_regrab_cooldown: float = 0.25

@export_group("Kamçı")
## İleri vuruş menzili (docs/03 §3: 2.5 m) ve isabet kutusunun yüksekliği/kalınlığı.
@export var whip_range: float = 2.5
@export var whip_thickness: float = 1.2
## Bir vuruşun toplam süresi; isabet yalnızca [active_start, active_end] aralığında.
@export var attack_duration: float = 0.26
@export var attack_active_start: float = 0.05
@export var attack_active_end: float = 0.16
## Vuruş bittikten sonra komboyu sürdürmek için süre.
@export var combo_window: float = 0.3
## Erken basılan saldırı hatırlanır (attack buffer).
@export var attack_buffer: float = 0.15
## 3'lü kombonun hasarları (docs/03: 1–1–2).
@export var combo_damage: Array[int] = [1, 1, 2]
## 3. vuruştan sonra yeni kombo için bekleme.
@export var combo_end_cooldown: float = 0.3
## Aşağı vuruş isabet ederse yukarı sıçrama hızı (pogo).
@export var pogo_velocity: float = 10.0
## Savrulma Saldırısı: sallanırken saldırı; çevresel yarıçap ve hızlı/yavaş hasar.
@export var swing_attack_radius: float = 2.0
@export var swing_attack_fast_speed: float = 8.0
@export var swing_attack_damage_slow: int = 1
@export var swing_attack_damage_fast: int = 2
## Düşmanı geri itme hızı.
@export var enemy_knockback: float = 5.0
## Vuruşta zaman yavaşlaması (hit-stop): süre (gerçek zaman) ve zaman ölçeği.
@export var hit_stop_time: float = 0.05
@export var hit_stop_scale: float = 0.05

@export_group("Can")
## Hasar sonrası dokunulmazlık (docs/03: 0.8 sn) ve kontrolsüz geri itilme süresi.
@export var invuln_time: float = 0.8
@export var hurt_stun_time: float = 0.25
@export var hurt_knockback: Vector2 = Vector2(6.0, 5.0)
## Çukura düşünce kaybedilen yaprak (karar 2026-11-25).
@export var fall_damage: int = 1
## Dokunulmazlıkta yanıp sönme aralığı.
@export var invuln_blink: float = 0.08

@export_group("Görsel")
@export var turn_speed: float = 14.0

@export_group("Güvenlik")
@export var kill_y: float = -15.0


func get_jump_velocity() -> float:
	return sqrt(2.0 * gravity_up * jump_height)


func get_climb_jump_velocity() -> float:
	return sqrt(2.0 * gravity_up * climb_jump_height)


## Canlı tuning değerlerini .tres'e yapıştırılabilir metin olarak döndürür.
func to_tres_snippet() -> String:
	var lines: PackedStringArray = []
	for field: Array in LIVE_FIELDS:
		var key: String = field[0]
		lines.append("%s = %s" % [key, str(get(key))])
	return "\n".join(lines)
