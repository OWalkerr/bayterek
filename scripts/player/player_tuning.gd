class_name PlayerTuning
extends Resource
## Alpay'ın tüm hareket sayıları. Değerler docs/03_MECHANICS.md ile senkron tutulur.

@export_group("Koşma")
@export var run_speed: float = 7.0
@export var ground_accel: float = 60.0
@export var ground_decel: float = 70.0
@export_range(0.0, 1.0) var air_control: float = 0.65
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
@export var min_rope: float = 2.0
@export var max_rope: float = 7.0
@export var swing_gravity: float = 24.0
@export var swing_pump: float = 9.0
@export var swing_damping: float = 0.15
@export var swing_max_angle_deg: float = 100.0
@export var rope_reel_speed: float = 3.0
@export var release_boost: float = 1.1
@export var release_jump_bonus: float = 6.0
@export var perfect_release_bonus: float = 1.15
@export var regrab_cooldown: float = 0.35

@export_group("Güvenlik")
@export var kill_y: float = -15.0


func get_jump_velocity() -> float:
	return sqrt(2.0 * gravity_up * jump_height)
