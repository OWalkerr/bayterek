class_name SideRail
extends Node3D
## Yan mod rayı (docs/05): DEPTH'ten SIDE'a dönüşte oyuncu, x aralığı kendisini kapsayan
## en yakın raya (Z) yumuşakça çekilir (~0.4 sn, PlayerTuning.rail_pull). Ray yoksa oda varsayılanı (Z=0).
## Böylece mağaradan farklı bir derinlik katmanına (ör. arka koridor) çıkılabilir.

const GROUP: StringName = &"side_rail"

@export var x_min: float = -1000.0
@export var x_max: float = 1000.0


func _ready() -> void:
	add_to_group(GROUP)


func contains_x(x: float) -> bool:
	return x >= x_min and x <= x_max


## `point` için uygun rayın Z'si; uygun ray yoksa `fallback_z`.
static func find_rail_z(tree: SceneTree, point: Vector3, fallback_z: float) -> float:
	var best_z := fallback_z
	var best_d := INF
	for node: Node in tree.get_nodes_in_group(GROUP):
		var rail := node as SideRail
		if rail == null or not rail.contains_x(point.x):
			continue
		var d := absf(rail.global_position.z - point.z)
		if d < best_d:
			best_d = d
			best_z = rail.global_position.z
	return best_z
