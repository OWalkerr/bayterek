class_name GreyboxRoom
extends Room
## Kodla kurulan greybox oda. Oda sahnesinin (.tscn) kök script'i bundan türer ve `_build()` içinde
## yardımcılarla (box/vine/climb/rotten/glow/goal/cave_zone…) geometriyi kurar. Kimlik, harita
## hücresi ve kapılar .tscn'dedir (Room). M7'de sanat gelince aynı .tscn'e modeller eklenir.

signal goal_reached

const C_BARK := Color("6b4a2f")
const C_ROOT := Color("4a3550")
const C_MOSS := Color("5e8c4a")
const C_CAVE := Color("2b1e3f")
const C_GLOW := Color("4fb3a9")
const C_SAP := Color("e8a33d")
const C_SKY := Color("f4efe3")

var goal: RoomGoal = null
## Otomatik sınırlara eklenen pay (m).
var bounds_margin: float = 1.0


func _ready() -> void:
	_build()
	if bounds.size == Vector3.ZERO:
		bounds = compute_bounds()


## Odadaki tüm statik kutuların birleşik AABB'si (+ pay).
func compute_bounds() -> AABB:
	var result := AABB()
	var first := true
	for child: Node in get_children():
		var body := child as StaticBody3D
		if body == null:
			continue
		for c: Node in body.get_children():
			var col := c as CollisionShape3D
			if col == null or not col.shape is BoxShape3D:
				continue
			var size := (col.shape as BoxShape3D).size
			var box := AABB(body.position - size * 0.5, size)
			result = box if first else result.merge(box)
			first = false
	return result.grow(bounds_margin)


func side_rail(z: float, x_min: float, x_max: float) -> SideRail:
	var rail := SideRail.new()
	rail.position = Vector3((x_min + x_max) * 0.5, 0.0, z)
	rail.x_min = x_min
	rail.x_max = x_max
	add_child(rail)
	return rail


## Alt sınıflar geometriyi burada kurar.
func _build() -> void:
	pass


# ---------------------------------------------------------------- Yardımcılar

func box(center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	add_child(body)
	return body


## Üst yüzeyi `top_y` olan, x1→x2 arası platform (derinlik `depth`).
func platform(x1: float, x2: float, top_y: float, thickness: float = 0.5,
		color: Color = C_MOSS, depth: float = 3.0) -> StaticBody3D:
	return box(Vector3((x1 + x2) * 0.5, top_y - thickness * 0.5, 0.0),
			Vector3(x2 - x1, thickness, depth), color)


## Arka plan duvarı (oyuncunun arkasında, -Z'de): ölçek ve yön hissi için.
func backdrop(x1: float, x2: float, y1: float, y2: float, color: Color = C_ROOT) -> void:
	box(Vector3((x1 + x2) * 0.5, (y1 + y2) * 0.5, -3.5), Vector3(x2 - x1, y2 - y1, 1.0), color)


## Görsel ama çarpışmasız kutu: yandan bakınca duvar gibi görünür, derinlikte içinden geçilir
## (derinlik sırrı, Sütun 4). Hafif farklı ton = dikkatli göze ipucu.
func illusion_box(center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.lightened(0.04)
	mat.roughness = 0.95
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = center
	mi.add_to_group(&"illusion_wall")
	add_child(mi)
	return mi


func grapple_flower(at: Vector3) -> GrappleFlower:
	var f := GrappleFlower.new()
	f.position = at
	add_child(f)
	return f


func vine(anchor_position: Vector3, length: float) -> VineAnchor:
	var v := VineAnchor.new()
	v.vine_length = length
	v.position = anchor_position
	add_child(v)
	return v


func rotten_vine(anchor_position: Vector3, length: float) -> RottenVine:
	var v := RottenVine.new()
	v.vine_length = length
	v.position = anchor_position
	add_child(v)
	return v


func climb_vine(top_position: Vector3, length: float) -> ClimbVine:
	var v := ClimbVine.new()
	v.vine_length = length
	v.position = top_position
	add_child(v)
	return v


func crawler(at: Vector3, direction: float = 1.0) -> RotCrawler:
	var e := RotCrawler.new()
	e.start_direction = direction
	e.position = at
	add_child(e)
	return e


func bloater(at: Vector3, respawn_seconds: float = -1.0) -> SporeBloater:
	var e := SporeBloater.new()
	e.respawn_time = respawn_seconds
	e.position = at
	add_child(e)
	return e


func glow(at: Vector3, color: Color = C_GLOW) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	var cap := SphereMesh.new()
	cap.radius = 0.4
	cap.height = 0.5
	cap.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cap
	mi.position = at
	add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 6.0
	light.position = at + Vector3.UP * 0.6
	add_child(light)


## Odanın hedefi: ayak tabanı konumu `at`.
func place_goal(at: Vector3, color: Color = C_SKY) -> RoomGoal:
	goal = RoomGoal.new()
	goal.color = color
	goal.position = at
	add_child(goal)
	goal.reached.connect(func() -> void: goal_reached.emit())
	return goal


func camera_zone(center: Vector3, size: Vector3, mode: CameraRig.Mode = CameraRig.Mode.DEPTH,
		duration: float = 1.0) -> CameraZone:
	var zone := CameraZone.new()
	zone.size = size
	zone.position = center
	zone.mode = mode
	zone.transition_duration = duration
	add_child(zone)
	return zone
