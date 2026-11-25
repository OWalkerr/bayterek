class_name BossHazard
extends Area3D
## Boss'un hasar veren hacmi (gövde, fırlama sütunu, kuyruk süpürmesi, ağız). `active` iken
## içindeki oyuncuya `damage` verir (dokunulmazlık Player'da). Katman "hazard".

signal player_hit(player: Player)

@export var damage: int = 1
@export var active: bool = false:
	set(value):
		active = value
		if _visual != null:
			_visual.visible = value and show_when_active

## Etkin olduğunda görseli göster (süpürme halkası gibi).
@export var show_when_active: bool = false

var _visual: MeshInstance3D


func _ready() -> void:
	collision_layer = Layers.HAZARD
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false


## Silindir şekli (yarıçap, yükseklik); taban düğüm konumunda.
func set_cylinder(radius: float, height: float, visual_color: Color = Color.TRANSPARENT) -> void:
	for c: Node in get_children():
		c.queue_free()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3.UP * height * 0.5
	add_child(col)
	if visual_color.a > 0.0:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = visual_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.material = mat
		_visual = MeshInstance3D.new()
		_visual.mesh = mesh
		_visual.position = Vector3.UP * height * 0.5
		_visual.visible = active and show_when_active
		add_child(_visual)


func set_box(size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	for c: Node in get_children():
		c.queue_free()
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = offset
	add_child(col)


func _physics_process(_delta: float) -> void:
	if not active:
		return
	for body: Node3D in get_overlapping_bodies():
		var p := body as Player
		if p != null and not p.is_invulnerable() and p.take_damage(damage, global_position):
			player_hit.emit(p)
