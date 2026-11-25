class_name MapService
extends RefCounted
## Metroidvania harita verisi (docs/06; MetSys yerine kendi ızgaramız — karar 2026-11-25).
## Oda sahnelerini ÖRNEKLEMEDEN SceneState'ten okur: kök düğümün room_id, display_name, region,
## map_cell, map_size değerleri; Ocak ve kapı düğümleri (script yoluna göre). Sonuç önbelleğe alınır.

const OCAK_SCRIPT: String = "res://scripts/world/ocak.gd"
const DOOR_SCRIPT: String = "res://scripts/world/room_door.gd"
const PICKUP_SCRIPT: String = "res://scripts/world/collectible.gd"

static var _cache: Dictionary = {}


## room_id -> {name, region, cell: Vector2i, size: Vector2i, has_ocak: bool,
##             doors: Array[{id, target_room, target_door}]}
static func get_rooms() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	for room_id: StringName in RoomRegistry.ROOMS.keys():
		var packed := RoomRegistry.load_scene(room_id)
		if packed == null:
			continue
		_cache[room_id] = _read(packed.get_state())
	return _cache


static func get_region_rooms(region: StringName) -> Dictionary:
	var out: Dictionary = {}
	var all := get_rooms()
	for id: StringName in all.keys():
		if all[id]["region"] == region:
			out[id] = all[id]
	return out


static func clear_cache() -> void:
	_cache.clear()


static func _read(state: SceneState) -> Dictionary:
	var info: Dictionary = {
		"name": "", "region": &"kok_dibi", "cell": Vector2i.ZERO, "size": Vector2i.ONE,
		"has_ocak": false, "doors": [], "pickups": [],
	}
	for i in state.get_node_property_count(0):
		var key := state.get_node_property_name(0, i)
		var value: Variant = state.get_node_property_value(0, i)
		match key:
			&"display_name": info["name"] = value
			&"region": info["region"] = value
			&"map_cell": info["cell"] = value
			&"map_size": info["size"] = value
	for n in range(1, state.get_node_count()):
		var props: Dictionary = {}
		var script_path := ""
		for i in state.get_node_property_count(n):
			var key := state.get_node_property_name(n, i)
			var value: Variant = state.get_node_property_value(n, i)
			if key == &"script" and value is Script:
				script_path = (value as Script).resource_path
			props[key] = value
		if script_path == PICKUP_SCRIPT:
			info["pickups"].append(props.get(&"pickup_id", &""))
		elif script_path == OCAK_SCRIPT:
			info["has_ocak"] = true
		elif script_path == DOOR_SCRIPT:
			info["doors"].append({
				"id": props.get(&"door_id", &""),
				"target_room": props.get(&"target_room", &""),
				"target_door": props.get(&"target_door", &""),
				"requires": props.get(&"requires", &""),
			})
	return info
