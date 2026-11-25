extends Node
## Kalıcı oyun durumu: yetenekler, bayraklar, toplanabilirler, ziyaret edilen odalar, son Ocak,
## kayıt/yükleme (JSON, user://save_X.json — web'de tarayıcının IndexedDB'si).
## Kayıt zamanı (karar 2026-11-25): Ocak'ta dinlenince tam kayıt + her kapı geçişinde otomatik kayıt.

const SAVE_VERSION: int = 3
## Öz barı üst sınırı (docs/03 §3.2; 3 iyileşmelik).
const SAP_MAX: int = 99
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

## Aktif kayıt yuvası. Testler kendi yuvasını kullanır (oyuncunun kaydına dokunmaz).
var save_slot: int = 0
## false iken autosave() yazmaz (geliştirici oda seçici / testler).
var autosave_enabled: bool = true

var abilities: Dictionary = {}      # StringName -> bool
var flags: Dictionary = {}          # "oda_id/nesne_id" -> Variant
var visited_rooms: Dictionary = {}  # StringName -> true
var kut_shards: int = 0
var sap_drops: int = 0
var max_leaves: int = 5
## Mevcut can (yaprak). Ölümde / Ocak'ta max_leaves'e döner.
var leaves: int = 5
## Öz (enerji): kamçı isabetiyle dolar, iyileşmede harcanır. Ölünce sıfırlanır.
var sap: int = 0
var current_room: StringName = &""
## Son dinlenilen Ocak (oda + Ocak kimliği). Boşsa ölümde mevcut odanın başına dönülür.
var last_ocak: StringName = &""
var last_ocak_room: StringName = &""


func _ready() -> void:
	# Ana dil Türkçe (docs/00); dil seçimi Ayarlar menüsüyle (M9) gelir.
	TranslationServer.set_locale("tr")


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


func add_sap(amount: int) -> void:
	sap = clampi(sap + amount, 0, SAP_MAX)
	EventBus.player_sap_changed.emit(sap)


func spend_sap(amount: int) -> bool:
	if sap < amount:
		return false
	sap -= amount
	EventBus.player_sap_changed.emit(sap)
	return true


func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value


func get_flag(key: String, default: Variant = false) -> Variant:
	return flags.get(key, default)


func enter_room(room_id: StringName) -> void:
	current_room = room_id
	visited_rooms[room_id] = true


func is_visited(room_id: StringName) -> bool:
	return visited_rooms.has(room_id)


func has_last_ocak() -> bool:
	return last_ocak_room != &""


## Ocak'ta dinlenme: can dolar, son Ocak işaretlenir, tam kayıt.
func rest_at(room_id: StringName, ocak_id: StringName) -> void:
	last_ocak_room = room_id
	last_ocak = ocak_id
	reset_health()
	save_game(save_slot)


## Kapı geçişi / toplanabilir sonrası otomatik kayıt.
func autosave() -> bool:
	if not autosave_enabled:
		return false
	return save_game(save_slot)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"abilities": abilities.keys().map(func(k: Variant) -> String: return str(k)),
		"flags": flags.duplicate(true),   # kopya: sonraki reset/değişiklik anlık görüntüyü bozmasın
		"visited_rooms": visited_rooms.keys().map(func(k: Variant) -> String: return str(k)),
		"kut_shards": kut_shards,
		"sap_drops": sap_drops,
		"max_leaves": max_leaves,
		"leaves": leaves,
		"sap": sap,
		"current_room": str(current_room),
		"last_ocak": str(last_ocak),
		"last_ocak_room": str(last_ocak_room),
	}


func from_dict(data: Dictionary) -> void:
	abilities.clear()
	for id: String in data.get("abilities", []):
		abilities[StringName(id)] = true
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	visited_rooms.clear()
	for id: String in data.get("visited_rooms", []):
		visited_rooms[StringName(id)] = true
	kut_shards = int(data.get("kut_shards", 0))
	sap_drops = int(data.get("sap_drops", 0))
	max_leaves = int(data.get("max_leaves", 5))
	leaves = int(data.get("leaves", max_leaves))
	sap = int(data.get("sap", 0))
	current_room = StringName(data.get("current_room", ""))
	last_ocak = StringName(data.get("last_ocak", ""))
	last_ocak_room = StringName(data.get("last_ocak_room", ""))
	# v1 kayıtlarında Ocak odası yoktu → Ocak varsa mevcut oda varsayılır
	if last_ocak_room == &"" and last_ocak != &"":
		last_ocak_room = current_room


func save_game(slot: int = save_slot) -> bool:
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Kayıt yazılamadı: %s" % _slot_path(slot))
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	EventBus.game_saved.emit(slot)
	return true


func load_game(slot: int = save_slot) -> bool:
	if not FileAccess.file_exists(_slot_path(slot)):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(slot)))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Kayıt dosyası bozuk.")
		return false
	from_dict(parsed)
	return true


func has_save(slot: int = save_slot) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_save(slot: int = save_slot) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_slot_path(slot))


func reset() -> void:
	abilities = {}
	flags = {}
	visited_rooms = {}
	kut_shards = 0
	sap_drops = 0
	max_leaves = 5
	leaves = max_leaves
	sap = 0
	current_room = &""
	last_ocak = &""
	last_ocak_room = &""


func _slot_path(slot: int) -> String:
	return "user://save_%d.json" % slot
