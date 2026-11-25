class_name Room
extends Node3D
## Oda tabanı (docs/06 "Oda Sistemi"). Kimlik, harita hücresi ve kapılar oda sahnesinde (.tscn)
## tutulur; geometri greybox aşamasında GreyboxRoom yardımcılarıyla kodda kurulur (karar 2026-11-25).
## SceneRouter odayı yükler, oyuncuyu kapıya/Ocak'a/başlangıca koyar.

const GROUP: StringName = &"room"

@export var room_id: StringName = &"room"
@export var display_name: String = "Oda"
## "Bir oda = bir fikir" (docs/02 Oda Kuralı 1).
@export var idea: String = ""
@export var region: StringName = &"kok_dibi"
## Harita ızgarasında sol-alt hücre ve kapladığı hücre sayısı (MapService).
@export var map_cell: Vector2i = Vector2i.ZERO
@export var map_size: Vector2i = Vector2i.ONE
## Kapısız girişte (yeni oyun / geliştirici seçici) oyuncunun konduğu yer.
@export var spawn_point: Vector3 = Vector3.ZERO
## Kamera oda sınırları (SIDE). Boşsa oda geometrisinden otomatik hesaplanır.
@export var bounds: AABB = AABB()


func _enter_tree() -> void:
	add_to_group(GROUP)


func get_doors() -> Array[RoomDoor]:
	var out: Array[RoomDoor] = []
	for child: Node in get_children():
		if child is RoomDoor:
			out.append(child as RoomDoor)
	return out


func get_door(door_id: StringName) -> RoomDoor:
	for door: RoomDoor in get_doors():
		if door.door_id == door_id:
			return door
	return null


func get_ocak(ocak_id: StringName) -> Ocak:
	for child: Node in get_children():
		var o := child as Ocak
		if o != null and o.ocak_id == ocak_id:
			return o
	return null


## Kalıcı nesne bayrağının anahtarı: "oda_id/nesne_id" (docs/06).
func flag_key(object_id: StringName) -> String:
	return "%s/%s" % [room_id, object_id]
