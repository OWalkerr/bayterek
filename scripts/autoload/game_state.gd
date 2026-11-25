extends Node
## Kalıcı oyun durumu: yetenekler, bayraklar, toplanabilirler, kayıt/yükleme.

const SAVE_VERSION: int = 1
const ABILITIES: Array[StringName] = [
	&"whip_grapple",   # Kamçı Kancası
	&"sap_pull",       # Öz Çekimi
	&"bark_claw",      # Kabuk Pençesi
	&"leaf_cloak",     # Yaprak Pelerin
	&"seed_shot",      # Tohum Atışı
	&"root_dive",      # Kök Dalışı
	&"umay_feather",   # Umay Tüyü (çift zıplama)
	&"sky_whip",       # Gök Kamçısı
]

var abilities: Dictionary = {}      # StringName -> bool
var flags: Dictionary = {}          # "oda_id/nesne_id" -> Variant
var kut_shards: int = 0
var sap_drops: int = 0
var max_leaves: int = 5
## Mevcut can (yaprak). Ölümde / Ocak'ta max_leaves'e döner.
var leaves: int = 5
var current_room: StringName = &""
var last_ocak: StringName = &""


func has_ability(id: StringName) -> bool:
	return abilities.get(id, false)


func unlock_ability(id: StringName) -> void:
	if has_ability(id):
		return
	abilities[id] = true
	EventBus.ability_unlocked.emit(id)


func reset_health() -> void:
	leaves = max_leaves
	EventBus.player_healed.emit(leaves)


func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value


func get_flag(key: String, default: Variant = false) -> Variant:
	return flags.get(key, default)


func save_game(slot: int = 0) -> bool:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"abilities": abilities.keys().map(func(k: Variant) -> String: return str(k)),
		"flags": flags,
		"kut_shards": kut_shards,
		"sap_drops": sap_drops,
		"max_leaves": max_leaves,
		"leaves": leaves,
		"current_room": str(current_room),
		"last_ocak": str(last_ocak),
	}
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Kayıt yazılamadı: %s" % _slot_path(slot))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func load_game(slot: int = 0) -> bool:
	if not FileAccess.file_exists(_slot_path(slot)):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(slot)))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Kayıt dosyası bozuk.")
		return false
	var data: Dictionary = parsed
	abilities.clear()
	for id: String in data.get("abilities", []):
		abilities[StringName(id)] = true
	flags = data.get("flags", {})
	kut_shards = int(data.get("kut_shards", 0))
	sap_drops = int(data.get("sap_drops", 0))
	max_leaves = int(data.get("max_leaves", 5))
	leaves = int(data.get("leaves", max_leaves))
	current_room = StringName(data.get("current_room", ""))
	last_ocak = StringName(data.get("last_ocak", ""))
	return true


func reset() -> void:
	abilities.clear()
	flags.clear()
	kut_shards = 0
	sap_drops = 0
	max_leaves = 5
	leaves = max_leaves
	current_room = &""
	last_ocak = &""


func _slot_path(slot: int) -> String:
	return "user://save_%d.json" % slot
