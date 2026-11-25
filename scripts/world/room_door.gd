class_name RoomDoor
extends Area3D
## Odalar arası kapı (docs/06). Oyuncu alana girince SceneRouter hedef odayı yükler ve oyuncuyu
## hedef kapının `arrive_offset` noktasına koyar (hız korunur → momentum kaybolmaz, Sütun 1).
## Düğüm konumu = kapı eşiğinin alt ortası; alan yukarı doğru `size.y` kadar uzanır.

const GROUP: StringName = &"room_door"

@export var door_id: StringName = &"door"
@export var target_room: StringName = &""
@export var target_door: StringName = &""
@export var size: Vector3 = Vector3(1.0, 3.0, 4.0)
## Bu kapıdan odaya GİRİLİRKEN oyuncunun konacağı yer (kapıya göre, odanın içine doğru).
@export var arrive_offset: Vector3 = Vector3(1.5, 0.1, 0.0)
@export var enabled: bool = true
## Bu kapıya oda İÇİNDEN ulaşmak için gereken yetenek (boşsa yok). Yalnızca veri:
## harita testi yetenekli/yeteneksiz erişilebilirliği buradan hesaplar (docs/02 kapı matrisi).
@export var requires: StringName = &""


func _ready() -> void:
	add_to_group(GROUP)
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = Layers.PLAYER
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3.UP * size.y * 0.5
	add_child(col)
	body_entered.connect(_on_body_entered)


func get_arrival_position() -> Vector3:
	return global_position + arrive_offset


func _on_body_entered(body: Node3D) -> void:
	if not enabled or target_room == &"" or not is_inside_tree():
		return
	var player := body as Player
	if player == null or player.is_dead():
		return
	SceneRouter.go_through_door(target_room, target_door, player.velocity)
