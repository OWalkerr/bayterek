class_name PlayerHealState
extends PlayerState
## İyileşme (docs/03 §3.2): yerde L basılı tutulur; `heal_time` sn sonra +1 yaprak, `heal_cost` Öz.
## Basılı kalırsa ve Öz yetiyorsa tekrar eder. Tuş bırakılınca, Öz bitince ya da can dolunca biter.
## Hasar alınca (take_damage → HURT) kesilir; yarım kalan süre kaybolur.

var progress: float = 0.0


static func can_start(p: Player) -> bool:
	return GameState.sap >= p.tuning.heal_cost and GameState.leaves < GameState.max_leaves


func enter(_previous: int) -> void:
	progress = 0.0
	EventBus.player_heal_started.emit()


func exit(_next: int) -> void:
	progress = 0.0


func physics_update(delta: float) -> void:
	var p := player
	var t := tuning()
	p.velocity.x = move_toward(p.velocity.x, 0.0, t.heal_decel * delta)
	p.velocity.z = move_toward(p.velocity.z, 0.0, t.heal_decel * delta)
	if CameraDirector.is_side_mode():
		p.velocity.z = p.rail_velocity_z()
	if not p.is_on_floor():
		p.apply_gravity(delta)
	p.move_and_slide()
	if not Input.is_action_pressed(&"heal") or not p.is_on_floor() or not can_start(p):
		p.change_state(Player.State.GROUND if p.is_on_floor() else Player.State.AIR)
		return
	progress += delta
	if progress >= t.heal_time:
		progress = 0.0
		GameState.spend_sap(t.heal_cost)
		GameState.leaves = mini(GameState.leaves + 1, GameState.max_leaves)
		EventBus.player_healed.emit(GameState.leaves)
		if not can_start(p):
			p.change_state(Player.State.GROUND)
