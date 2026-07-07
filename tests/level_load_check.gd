extends Node3D
## Runs all three generated levels through the real WaveSpawner: every enemy
## must instantiate, spawn from data, and be killable. Proves the glTF ships
## are wired end-to-end. Kills each enemy on spawn so ALL_DEFEATED completes.

const LEVELS := [
	"res://games/revenger/levels/level_1.tres",
	"res://games/revenger/levels/level_2.tres",
	"res://games/revenger/levels/level_3.tres",
]
const EXPECTED := {"level_1": 14, "level_2": 19, "level_3": 19}

var _spawned_this_level: int = 0
var _seen_ids: Dictionary = {}
var _failures: PackedStringArray = []


func _ready() -> void:
	var marker := Node3D.new()
	marker.add_to_group("spawn_points")
	add_child(marker)
	WaveSpawner.set_enemy_container(self)

	EventBus.enemy_spawned.connect(func(enemy: Node) -> void:
		_spawned_this_level += 1
		if enemy is EnemyBase:
			var def := (enemy as EnemyBase).definition
			if def != null:
				_seen_ids[def.id] = true
			(enemy as EnemyBase).take_hit(999.0)
	)

	if DisplayServer.get_name() == "headless":
		await _run_all()
		_report()


func _run_all() -> void:
	for path in LEVELS:
		var level_name: String = path.get_file().get_basename()
		var wave_set: WaveSet = load(path)
		if wave_set == null:
			_failures.append("failed to load " + path)
			continue
		_spawned_this_level = 0
		WaveSpawner.load_waves(wave_set)
		WaveSpawner.start_waves()

		var done := [false]
		EventBus.all_waves_completed.connect(func() -> void: done[0] = true, CONNECT_ONE_SHOT)
		var deadline := Time.get_ticks_msec() / 1000.0 + 30.0
		while not done[0]:
			await get_tree().process_frame
			if Time.get_ticks_msec() / 1000.0 > deadline:
				_failures.append(level_name + ": timed out")
				break

		var want: int = EXPECTED.get(level_name, -1)
		if _spawned_this_level != want:
			_failures.append("%s: expected %d spawns, got %d" % [level_name, want, _spawned_this_level])


func _report() -> void:
	for id in ["grunt", "swarmer", "gunner", "heavy"]:
		if not _seen_ids.has(StringName(id)):
			_failures.append("enemy type never spawned: " + id)
	if _failures.is_empty():
		print("LEVEL CHECK PASS — all 3 levels ran, all 4 enemy types spawned and died")
		get_tree().quit(0)
	else:
		print("LEVEL CHECK FAIL:")
		for f in _failures:
			print("  - ", f)
		get_tree().quit(1)
