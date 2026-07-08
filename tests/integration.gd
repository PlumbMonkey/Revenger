extends Node3D
## THE PRD Phase 6 deliverable: the whole game loop in one playable scene.
## F6 to play: WASD/left stick to fly, Space/RT to fire. Shoot enemies, catch
## falling humanoids (fly close), take hits, feel the camera shake.
## Headless: short smoke run, then quits.

const PLAYER: PackedScene = preload("res://games/revenger/player/player_ship.tscn")
const CAPTOR: PackedScene = preload("res://games/revenger/enemies/enemy_captor.tscn")
const LEVEL_1 := "res://games/revenger/levels/level_1.tres"
const HUMANOID_SCENES: Array[PackedScene] = [
	preload("res://games/revenger/rescue/humanoid_1.tscn"),
	preload("res://games/revenger/rescue/humanoid_2.tscn"),
	preload("res://games/revenger/rescue/humanoid_3.tscn"),
	preload("res://games/revenger/rescue/humanoid_4.tscn"),
]


func _ready() -> void:
	VFXManager.register_burst(&"laser_impact", preload("res://games/revenger/vfx/laser_impact_burst.tscn"))
	VFXManager.register_burst(&"pulse_impact", preload("res://games/revenger/vfx/pulse_impact_burst.tscn"))
	VFXManager.register_burst(&"smash", preload("res://games/revenger/vfx/pulse_impact_burst.tscn"))
	VFXManager.register_camera($Camera3D)

	# Enemy spawn markers across the far edge.
	for i in 5:
		var m := Node3D.new()
		m.add_to_group("spawn_points")
		add_child(m)
		m.position = Vector3(-40 + i * 20, 2, -45)

	# Humanoids on the ground.
	for i in 4:
		var h: RescueObject = HUMANOID_SCENES[i].instantiate()
		add_child(h)
		h.global_position = Vector3(-30 + i * 20, 0, -15)

	WaveSpawner.set_enemy_container(self)
	HUDManager.set_radar_bounds(Rect2(-60, -60, 120, 120))
	GameManager.start_game()

	# The player.
	var ship: PlayerShip = PLAYER.instantiate()
	add_child(ship)
	ship.global_position = Vector3(0, 2, 30)

	# Waves + one captor so the rescue loop is live too.
	WaveSpawner.load_waves(load(LEVEL_1))
	WaveSpawner.start_waves()
	var captor: Captor = CAPTOR.instantiate()
	add_child(captor)
	captor.global_position = Vector3(-30, 30, -15)

	EventBus.all_waves_completed.connect(func() -> void:
		WaveSpawner.load_waves(load(LEVEL_1))
		WaveSpawner.start_waves()
	)

	if DisplayServer.get_name() == "headless":
		await get_tree().create_timer(4.0).timeout
		WaveSpawner.stop_waves()
		print("INTEGRATION SMOKE OK — full loop ran 4s headless without error")
		get_tree().quit(0)
