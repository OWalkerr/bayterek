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
	&"sunak": "res://scenes/world/regions/kok_dibi/rooms/sunak.tscn",
	&"kanca_bahcesi": "res://scenes/world/regions/kok_dibi/rooms/kanca_bahcesi.tscn",
	&"spor_mahzeni": "res://scenes/world/regions/kok_dibi/rooms/spor_mahzeni.tscn",
	&"cicek_kuyusu": "res://scenes/world/regions/kok_dibi/rooms/cicek_kuyusu.tscn",
	&"kokyiyen_esigi": "res://scenes/world/regions/kok_dibi/rooms/kokyiyen_esigi.tscn",
	&"kokyiyen_ini": "res://scenes/world/regions/kok_dibi/rooms/kokyiyen_ini.tscn",
	&"ust_kokler": "res://scenes/world/regions/kok_dibi/rooms/ust_kokler.tscn",
	&"gizli_oda": "res://scenes/world/regions/kok_dibi/rooms/gizli_oda.tscn",
	&"kok_agzi": "res://scenes/world/regions/test/rooms/kok_agzi.tscn",
}

## Geliştirici oda seçicinin (0–7 tuşları) sırası — M1–M3 testleri bu indeksleri kullanır.
## 6–7: boss'u doğrudan denemek için (normal oyunda Kök Dibi'nin sonunda, 8 oda ötede).
const DEV_ROOMS: Array[StringName] = [&"kok_agzi", &"savrulma", &"tirmanma", &"curuk", &"yuva", &"yanki",
		&"kokyiyen_esigi", &"kokyiyen_ini"]
const DEV_ROOM_NAMES: PackedStringArray = ["Kök Ağzı", "Savrulma Zinciri", "Tırmanma Kuyusu", "Çürük Geçit",
		"Çürük Yuvası", "Yankı Mağarası", "Kökyiyen Eşiği (boss öncesi)", "Kökyiyen'in İni (boss)"]
## Geliştirici seçiciyle girilince verilecek yetenekler (o noktaya normal oyunda sahip olunanlar)
## ve sıfırlanacak bayraklar (boss her denemede yeniden dövüşülebilsin).
const DEV_GRANTS: Dictionary = {
	&"kokyiyen_esigi": [&"whip_grapple"],
	&"kokyiyen_ini": [&"whip_grapple"],
}
const DEV_RESET_FLAGS: Array[String] = ["kokyiyen_ini/boss_defeated"]


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
