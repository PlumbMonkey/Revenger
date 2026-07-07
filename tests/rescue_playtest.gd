extends Node3D
## Rescue mechanic preview: scatters humanoids on the ground and runs
## level_rescue_demo (captors) through the real WaveSpawner, so the whole
## grab -> carry -> mutate / catch flow can be watched in-engine.
## Not a pass/fail check — F6 this scene to look at it. (Headless: auto-quits.)

const LEVEL_RESCUE_DEMO := "res://games/revenger/levels/level_rescue_demo.tres"
const HUMANOID_SCENES: Array[PackedScene] = [
	preload("res://games/revenger/rescue/humanoid_1.tscn"),
	preload("res://games/revenger/rescue/humanoid_2.tscn"),
	preload("res://games/revenger/rescue/humanoid_3.tscn"),
	preload("res://games/revenger/rescue/humanoid_4.tscn"),
]
const PULSE_IMPACT := preload("res://games/revenger/vfx/pulse_impact_burst.tscn")


func _ready() -> void:
	VFXManager.register_burst(&"pulse_impact", PULSE_IMPACT)
	VFXManager.register_burst(&"smash", PULSE_IMPACT)  # placeholder until a dedicated smash burst exists

	# 5 humanoids scattered on the ground, per the spec — cycling through the
	# 4 real characters (2 male, female, child).
	for i in 5:
		var h: RescueObject = HUMANOID_SCENES[i % HUMANOID_SCENES.size()].instantiate()
		add_child(h)
		h.global_position = Vector3(-20 + i * 10, 0, 0)

	# Captors spawn from above and descend onto them.
	for i in 3:
		var m := Node3D.new()
		m.add_to_group("spawn_points")
		add_child(m)
		m.position = Vector3(-16 + i * 14, 25, 0)

	WaveSpawner.set_enemy_container(self)
	HUDManager.set_radar_bounds(Rect2(-40, -20, 80, 60))
	GameManager.start_game()
	WaveSpawner.load_waves(load(LEVEL_RESCUE_DEMO))
	WaveSpawner.start_waves()

	# Stand-in for the player (no player ship exists until Phase 6):
	# catch any humanoid that starts falling, simulating a rescue.
	EventBus.rescue_state_changed.connect(_on_rescue_transition)

	# Also stand in for "the player shoots a captor mid-carry": force-kill
	# the first captor a few seconds in, so the demo shows BOTH outcomes —
	# one captor gets shot down and its human is caught, the rest complete
	# their climb and mutate.
	get_tree().create_timer(7.0).timeout.connect(_snipe_first_captor)

	if DisplayServer.get_name() == "headless":
		await get_tree().create_timer(4.0).timeout
		WaveSpawner.stop_waves()
		print("RESCUE PLAYTEST SMOKE OK — ran 4s headless without error")
		get_tree().quit(0)


func _on_rescue_transition(npc: Node, _prev: StringName, new_state: StringName) -> void:
	if new_state == &"FALLING" and npc is RescueObject:
		(npc as RescueObject).catch()


func _snipe_first_captor() -> void:
	for node: Node in get_tree().get_nodes_in_group("radar_enemy"):
		if node is EnemyBase and (node as EnemyBase).definition != null \
				and (node as EnemyBase).definition.id == &"captor":
			(node as EnemyBase).take_hit(999.0)
			return
