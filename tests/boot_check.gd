extends Node
## Phase 1 + Phase 2 integration proof: all autoloads, EventBus traffic,
## real data-driven wave spawning. Runs headless in under 15 s.

var _failures: PackedStringArray = []
var _score_events: int = 0
var _wave_events: int = 0
var _scheme_events: int = 0
var _p2_spawned: int = 0
var _p2_score_events: int = 0
var _p2_done: bool = false


func _ready() -> void:
	_check_autoloads_registered()
	_check_input_contract()
	_check_eventbus_traffic()   # Phase 1 — synchronous
	await _check_wave_spawner() # Phase 2 — async (real enemy instancing)
	_check_hud()                # Phase 4 — synchronous
	_report()


func _check_autoloads_registered() -> void:
	for autoload_name in ["EventBus", "SettingsManager", "GameManager", "ScoreManager", "WaveSpawner", "VFXManager", "HUDManager"]:
		if get_node_or_null("/root/" + autoload_name) == null:
			_failures.append("autoload not registered: " + autoload_name)


func _check_input_contract() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "fire",
			"action_secondary", "aim_left", "aim_right", "aim_up", "aim_down", "pause",
			"brake", "warp"]:
		if not InputMap.has_action(action):
			_failures.append("InputMap action missing: " + action)

	EventBus.control_scheme_changed.connect(func(_scheme: int) -> void: _scheme_events += 1)
	var original: int = SettingsManager.control_scheme
	SettingsManager.control_scheme = SettingsManager.ControlScheme.GAMEPAD \
			if original != SettingsManager.ControlScheme.GAMEPAD \
			else SettingsManager.ControlScheme.KEYBOARD_MOUSE
	SettingsManager.control_scheme = original
	if _scheme_events != 2:
		_failures.append("control_scheme_changed not routed via EventBus (got %d events)" % _scheme_events)


func _check_eventbus_traffic() -> void:
	EventBus.score_changed.connect(func(_score: int) -> void: _score_events += 1)
	EventBus.wave_started.connect(func(_wave: int) -> void: _wave_events += 1)

	GameManager.start_game()
	if GameManager.state != GameManager.State.PLAYING:
		_failures.append("GameManager did not enter PLAYING on start_game()")

	EventBus.enemy_died.emit(self, 100, Vector3.ZERO)
	EventBus.enemy_died.emit(self, 100, Vector3.ZERO)
	if ScoreManager.score != 250:
		_failures.append("combo scoring wrong: expected 250 (100 + 100x1.5), got %d" % ScoreManager.score)
	if ScoreManager.combo_count != 2:
		_failures.append("combo count wrong: expected 2, got %d" % ScoreManager.combo_count)

	EventBus.npc_rescued.emit(self, 500)
	EventBus.vfx_burst_requested.emit(&"explosion_large", Vector3(1, 2, 0))

	# reset() fires on game_started (1) + two kills (2) + rescue (1) = 4.
	if _score_events != 4:
		_failures.append("expected 4 score_changed events, got %d" % _score_events)


func _check_wave_spawner() -> void:
	## Phase 2: load real WaveSet, spawn real enemies, kill them, await completion.
	##
	## Score chain (all within combo window):
	##   kill 1: 100 × 1.0 = 100   kill 2: 100 × 1.5 = 150
	##   kill 3: 100 × 2.0 = 200   kill 4: 100 × 2.5 = 250
	##   kill 5: 100 × 3.0 = 300   total = 1000

	# Connect phase-2 counters before start_game() so the reset event is counted.
	EventBus.score_changed.connect(func(_s: int) -> void: _p2_score_events += 1)
	EventBus.enemy_spawned.connect(func(enemy: Node) -> void:
		_p2_spawned += 1
		# Kill immediately so ALL_DEFEATED can complete the wave.
		if enemy is EnemyBase:
			(enemy as EnemyBase).take_hit(999.0)
	)

	# Fresh state: emits score_changed(0) → _p2_score_events = 1.
	GameManager.start_game()

	# Spawn marker — enemies land at its position (origin is fine for tests).
	var marker := Node3D.new()
	marker.add_to_group("spawn_points")
	add_child(marker)
	WaveSpawner.set_enemy_container(self)

	var wave_set: WaveSet = load("res://tests/data/test_wave_set.tres") as WaveSet
	if wave_set == null:
		_failures.append("Phase 2: failed to load res://tests/data/test_wave_set.tres")
		return

	WaveSpawner.load_waves(wave_set)
	WaveSpawner.start_waves()

	# Await all_waves_completed with a 15 s timeout guard.
	# Use a member variable (_p2_done) — GDScript lambda closures cannot
	# reliably update local variables across coroutine suspension points.
	_p2_done = false
	EventBus.all_waves_completed.connect(_on_p2_waves_done, CONNECT_ONE_SHOT)
	var deadline: float = Time.get_ticks_msec() / 1000.0 + 15.0
	while not _p2_done:
		await get_tree().process_frame
		if Time.get_ticks_msec() / 1000.0 > deadline:
			_failures.append("Phase 2: timed out waiting for all_waves_completed")
			_p2_done = true

	if WaveSpawner.is_running:
		_failures.append("Phase 2: WaveSpawner still running after all_waves_completed")
	if _p2_spawned != 5:
		_failures.append("Phase 2: expected 5 enemies spawned, got %d" % _p2_spawned)
	if _wave_events != 2:
		_failures.append("Phase 2: expected 2 wave_started events, got %d" % _wave_events)
	# reset (1) + 5 kills (5) = 6 score_changed events.
	if _p2_score_events != 6:
		_failures.append("Phase 2: expected 6 score_changed events, got %d" % _p2_score_events)
	if ScoreManager.score != 1000:
		_failures.append("Phase 2: expected score 1000 for 5 combo kills, got %d" % ScoreManager.score)


func _on_p2_waves_done() -> void:
	_p2_done = true


func _check_hud() -> void:
	## Phase 4: HUD labels, pause menu, settings OptionButton, radar blip counts.
	## HUD was already shown via game_started in Phase 2; test idempotency first.
	HUDManager.show_hud()

	var hud: Control = HUDManager.game_hud
	if hud == null:
		_failures.append("Phase 4: HUDManager.game_hud is null after show_hud()")
		return

	# ── Score label ────────────────────────────────────────────────────
	EventBus.score_changed.emit(42)
	var score_label := hud.get_node_or_null("%ScoreLabel") as Label
	if score_label == null:
		_failures.append("Phase 4: %ScoreLabel not found in game_hud")
	elif score_label.text != "Score: 42":
		_failures.append("Phase 4: score label — expected 'Score: 42', got '%s'" % score_label.text)

	# ── Lives label ────────────────────────────────────────────────────
	EventBus.lives_changed.emit(2)
	var lives_label := hud.get_node_or_null("%LivesLabel") as Label
	if lives_label == null:
		_failures.append("Phase 4: %LivesLabel not found")
	elif lives_label.text != "Lives: 2":
		_failures.append("Phase 4: lives label — expected 'Lives: 2', got '%s'" % lives_label.text)

	# ── Combo visible when mult > 1.0 ──────────────────────────────────
	EventBus.combo_changed.emit(2, 1.5)
	var combo_label := hud.get_node_or_null("%ComboLabel") as Label
	if combo_label == null:
		_failures.append("Phase 4: %ComboLabel not found")
	elif not combo_label.visible:
		_failures.append("Phase 4: combo label should be visible at mult=1.5")
	elif combo_label.text != "x1.5":
		_failures.append("Phase 4: combo label — expected 'x1.5', got '%s'" % combo_label.text)

	# ── Combo hidden at exactly 1.0 (spec edge case) ───────────────────
	EventBus.combo_changed.emit(0, 1.0)
	if combo_label != null and combo_label.visible:
		_failures.append("Phase 4: combo label should be hidden at mult=1.0")

	# ── Pause menu show/hide ───────────────────────────────────────────
	var pm: Control = HUDManager.pause_menu
	if pm == null:
		_failures.append("Phase 4: HUDManager.pause_menu is null")
		return

	GameManager.toggle_pause()
	if not pm.visible:
		_failures.append("Phase 4: pause menu not visible after toggle_pause()")
	if not get_tree().paused:
		_failures.append("Phase 4: tree should be paused after toggle_pause()")

	GameManager.toggle_pause()  # restore — must unpause before settings test
	if pm.visible:
		_failures.append("Phase 4: pause menu still visible after second toggle_pause()")
	if get_tree().paused:
		_failures.append("Phase 4: tree should not be paused after second toggle_pause()")

	# ── Control scheme via OptionButton ───────────────────────────────
	var option := pm.get_node_or_null("%SchemeOption") as OptionButton
	if option == null:
		_failures.append("Phase 4: %SchemeOption not found in pause_menu")
	else:
		var original_scheme := SettingsManager.control_scheme
		var new_scheme: int = (original_scheme + 1) % 3
		var new_idx: int = option.get_item_index(new_scheme)
		option.item_selected.emit(new_idx)          # fires _on_scheme_selected
		if SettingsManager.control_scheme != new_scheme:
			_failures.append("Phase 4: control_scheme not updated via OptionButton " \
					+ "(expected %d, got %d)" % [new_scheme, SettingsManager.control_scheme])
		if not FileAccess.file_exists("user://settings.cfg"):
			_failures.append("Phase 4: settings.cfg not written after scheme change")
		SettingsManager.control_scheme = original_scheme  # restore

	# ── Radar blip count ──────────────────────────────────────────────
	HUDManager.set_radar_bounds(Rect2(-50, -50, 100, 100))
	var radar := hud.get_node_or_null("%Radar")
	if radar == null:
		_failures.append("Phase 4: %Radar not found in game_hud")
	else:
		var dummy_enemy := Node3D.new()
		dummy_enemy.add_to_group("radar_enemy")
		add_child(dummy_enemy)
		var counts: Dictionary = radar.call("get_blip_counts")
		if counts.get("enemy", 0) < 1:
			_failures.append("Phase 4: expected >=1 enemy blip, got %s" % str(counts))
		dummy_enemy.queue_free()


func _report() -> void:
	if _failures.is_empty():
		print("BOOT CHECK PASS — 7 autoloads registered, Phase 1+2+4 verified" \
				+ " (Phase 1 score: 750, Phase 2 score: 1000, HUD: OK)")
	else:
		print("BOOT CHECK FAIL:")
		for failure: String in _failures:
			print("  - " + failure)

	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)
