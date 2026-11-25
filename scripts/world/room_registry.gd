class_name RoomRegistry
extends RefCounted
## Oda kimliği → sahne yolu. Harita (MapService) ve SceneRouter buradan okur.
## Yeni oda: .tscn'i scenes/world/regions/<bölge>/rooms/ altına koy + buraya ekle.

const START_ROOM: StringName = &"ocak_odasi"

const ROOMS: Dictionary = {
	&"ocak_odasi": "res://scenes/world/regions/kok_dibi/rooms/ocak_odasi.tscn",
	&"tirmanma": "res://scenes/world/regions/kok_dibi/rooms/tirmanma.tscn",
	&"yanki": "res://scenes/world/regions/kok_dibi/rooms/yanki.tscn",
	&"yuva": "res://scenes/world/regions/kok_dibi/rooms/yuva.tscn",
	&"savrulma": "res://scenes/world/regions/kok_dibi/rooms/savrulma.tscn",
	&"curuk": "res://scenes/world/regions/kok_dibi/rooms/curuk.tscn",
	&"kok_agzi": "res://scenes/world/regions/test/rooms/kok_agzi.tscn",
}

## Geliştirici oda seçicinin (0–5 tuşları) sırası — M1–M3 testleri bu indeksleri kullanır.
const DEV_ROOMS: Array[StringName] = [&"kok_agzi", &"savrulma", &"tirmanma", &"curuk", &"yuva", &"yanki"]
const DEV_ROOM_NAMES: PackedStringArray = ["Kök Ağzı", "Savrulma Zinciri", "Tırmanma Kuyusu", "Çürük Geçit",
		"Çürük Yuvası", "Yankı Mağarası"]


static func has_room(room_id: StringName) -> bool:
	return ROOMS.has(room_id)


static func scene_path(room_id: StringName) -> String:
	return ROOMS.get(room_id, "")


static func load_scene(room_id: StringName) -> PackedScene:
	var path := scene_path(room_id)
	if path.is_empty():
		push_error("Bilinmeyen oda: %s" % room_id)
		return null
	return load(path) as PackedScene
