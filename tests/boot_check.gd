extends Node
## Phase 1 deliverable proof: all six autoloads registered and talking over
## the EventBus. Runs real traffic through the bus (game start, a wave, two
## enemy kills, a rescue) and asserts the managers reacted. Prints a PASS/FAIL
## report; exits with it as the process code when run headless.

var _failures: PackedStringArray = []
var _score_events: int = 0
var _wave_events: int = 0


func _ready() -> void:
	_check_autoloads_registered()
	_check_eventbus_traffic()
	_report()


func _check_autoloads_registered() -> void:
	for autoload_name in ["EventBus", "GameManager", "ScoreManager", "WaveSpawner", "VFXManager", "HUDManager"]:
		if get_node_or_null("/root/" + autoload_name) == null:
			_failures.append("autoload not registered: " + autoload_name)


func _check_eventbus_traffic() -> void:
	EventBus.score_changed.connect(func(_score: int) -> void: _score_events += 1)
	EventBus.wave_started.connect(func(_wave: int) -> void: _wave_events += 1)

	GameManager.start_game()
	if GameManager.state != GameManager.State.PLAYING:
		_failures.append("GameManager did not enter PLAYING on start_game()")

	WaveSpawner.load_waves(["placeholder_wave_a", "placeholder_wave_b"])
	WaveSpawner.start_waves()
	if _wave_events != 1:
		_failures.append("wave_started not received via EventBus")

	EventBus.enemy_died.emit(self, 100, Vector3.ZERO)
	EventBus.enemy_died.emit(self, 100, Vector3.ZERO)
	if ScoreManager.score != 250:
		_failures.append("combo scoring wrong: expected 250 (100 + 100x1.5), got %d" % ScoreManager.score)
	if ScoreManager.combo_count != 2:
		_failures.append("combo count wrong: expected 2, got %d" % ScoreManager.combo_count)

	EventBus.npc_rescued.emit(self, 500)
	EventBus.vfx_burst_requested.emit(&"explosion_large", Vector3(1, 2, 0))

	WaveSpawner.complete_current_wave()
	WaveSpawner.complete_current_wave()
	if WaveSpawner.is_running:
		_failures.append("WaveSpawner still running after final wave completed")

	# reset() fires on game_started, so a fresh score_changed baseline (1) plus
	# two kills and the rescue = 4 total events through the bus.
	if _score_events != 4:
		_failures.append("expected 4 score_changed events, got %d" % _score_events)


func _report() -> void:
	if _failures.is_empty():
		print("BOOT CHECK PASS — 6 autoloads registered, EventBus traffic verified (final score: %d)" % ScoreManager.score)
	else:
		print("BOOT CHECK FAIL:")
		for failure in _failures:
			print("  - " + failure)

	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)
