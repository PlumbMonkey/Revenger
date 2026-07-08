extends Node3D
## THE Phase 6 deliverable: the whole game loop in one playable scene, now in
## proper Defender SIDE-VIEW orientation (X = scroll axis, Y = altitude,
## camera side-on). F6 to play: left stick/WASD to fly, A/Shift = boost,
## LB/Ctrl = brake, Y/H = warp, RT/Space = fire. Shoot enemies, catch falling
## humanoids, take hits, feel the shake. Headless: short smoke run, quits.

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

	# Enemies enter from the right edge at various altitudes and sweep left.
	for i in 4:
		var m := Node3D.new()
		m.add_to_group("spawn_points")
		add_child(m)
		m.position = Vector3(75, 10 + i * 7, 0)

	# Humanoids on the ground line.
	for i in 4:
		var h: RescueObject = HUMANOID_SCENES[i].instantiate()
		add_child(h)
		h.global_position = Vector3(-45 + i * 30, 0, 0)

	WaveSpawner.set_enemy_container(self)
	HUDManager.set_radar_bounds(Rect2(-80, 0, 160, 45), "XY")
	GameManager.start_game()

	var ship: PlayerShip = PLAYER.instantiate()
	ship.warp_bounds = Rect2(-65, 4, 130, 32)
	ship.position = Vector3(-40, 15, 0)
	add_child(ship)

	WaveSpawner.load_waves(load(LEVEL_1))
	WaveSpawner.start_waves()
	var captor: Captor = CAPTOR.instantiate()
	captor.position = Vector3(20, 38, 0)
	add_child(captor)

	EventBus.all_waves_completed.connect(func() -> void:
		WaveSpawner.load_waves(load(LEVEL_1))
		WaveSpawner.start_waves()
	)

	_spawn_starfield()

	if DisplayServer.get_name() == "headless":
		await get_tree().create_timer(4.0).timeout
		WaveSpawner.stop_waves()
		print("INTEGRATION SMOKE OK — side-view full loop ran 4s headless without error")
		get_tree().quit(0)


## Sporadic emissive pixels on a plane behind the action — stars against the
## black WorldEnvironment. MultiMesh: one draw call for the whole field.
func _spawn_starfield(count: int = 110) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	quad.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260707  # fixed seed: the sky doesn't reshuffle every run
	for i in count:
		var s: float = rng.randf_range(0.5, 1.6)  # size variety = depth feel
		var t := Transform3D(Basis().scaled(Vector3(s, s, s)),
			Vector3(rng.randf_range(-120, 120), rng.randf_range(-2, 70), rng.randf_range(-35, -20)))
		mm.set_instance_transform(i, t)

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
