class_name BossWeakPoint
extends Enemy
## Boss'un zayıf noktası (Kökyiyen'in çürük kesesi). Enemy tabanını kullanır → kamçı, pogo,
## Öz kazanımı, hit-stop aynen çalışır. Kendi hareketi yok: boss her kare konumunu yazar.
## `exposed` false iken vurulamaz ve görünmez (gömülü).

@export var sac_color: Color = Color("c9d93b")
@export var radius: float = 0.55

var exposed: bool = false:
	set(value):
		exposed = value
		visible = value and not is_dead()
		if hurtbox != null:
			hurtbox.set_deferred(&"monitorable", value and not is_dead())


func _enemy_ready() -> void:
	contact_damage = 0
	knockback_scale = 0.0
	stagger_time = 0.0
	collision_layer = 0
	collision_mask = 0
	exposed = false


func _build_visual() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	_mesh(sphere, sac_color, Vector3.ZERO, true)
	hurtbox_size = Vector3.ONE * radius * 2.4
	hurtbox_offset = Vector3.ZERO


## Kalan can oranı (0–1): görselin sönmesi ve testler için.
func get_health_ratio() -> float:
	return clampf(float(hp) / float(max_hp), 0.0, 1.0)


func take_hit(damage: int, from: Vector3, kind: StringName) -> bool:
	if not exposed:
		return false
	return super.take_hit(damage, from, kind)


func _die() -> void:
	# Boss'un parçası: sahneden silinmez, yalnızca söner
	respawn_time = 1.0e9
	super._die()
