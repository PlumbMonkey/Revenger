extends Node3D
## Playable preview: runs level_1 with a top-down camera and the Phase 4 HUD,
## so the imported enemy ships can be watched flying + firing in-engine.
## Not a pass/fail check — F6 this scene to look at it. (Headless: auto-quits.)

const LEVEL_1 := "res://games/revenger/levels/level_1.tres"
const LASER_IMPACT := preload("res://games/revenger/vfx/laser_impact_burst.tscn")
const PULSE_IMPACT := preload("res://games/revenger/vfx/pulse_impact_burst.tscn")


func _ready() -> void:
	VFXManager.register_burst(&"laser_impact", LASER_IMPACT)
	VFXManager.register_burst(&"pulse_impact", PULSE_IMPACT)

	# Spawn markers spread across the top of the play area.
	for i in 5:
		var m := Node3D.new()
		m.add_to_group("spawn_points")
		add_child(m)
		m.position = Vector3(-24 + i * 12, 0, 28)

	WaveSpawner.set_enemy_container(self)
	HUDManager.set_radar_bounds(Rect2(-40, -40, 80, 80))

	GameManager.start_game()          # shows HUD, resets score
	WaveSpawner.load_waves(load(LEVEL_1))
	WaveSpawner.start_waves()
	# Loop the level so there's always something to watch.
	EventBus.all_waves_completed.connect(func() -> void:
		WaveSpawner.load_waves(load(LEVEL_1))
		WaveSpawner.start_waves()
	)

	if DisplayServer.get_name() == "headless":
		await get_tree().create_timer(3.0).timeout
		WaveSpawner.stop_waves()  # cancel pending timers before teardown
		print("PLAYTEST SMOKE OK — level_1 ran 3s headless without error")
		get_tree().quit(0)
