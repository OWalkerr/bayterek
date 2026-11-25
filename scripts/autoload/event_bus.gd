extends Node
## Global olay kanalı. Sahneler birbirini tanımadan haberleşir.

@warning_ignore_start("unused_signal")
signal player_state_changed(new_state: int)
signal player_respawned(position: Vector3)
signal vine_grabbed(anchor: Node3D)
signal vine_released(anchor: Node3D, perfect: bool)
signal vine_broken(anchor: Node3D)
signal climb_started(vine: Node3D)
signal climb_ended(vine: Node3D, jumped: bool)
signal camera_mode_changed(mode: int)
signal ability_unlocked(ability_id: StringName)
signal room_changed(room_id: StringName)
signal room_goal_reached(room_id: StringName, time_seconds: float)
signal cutscene_started(cutscene_id: StringName)
signal cutscene_finished(cutscene_id: StringName)
@warning_ignore_restore("unused_signal")
