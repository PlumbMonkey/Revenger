extends Node
## Data-driven enemy wave spawning.
##
## Load a WaveSet resource, call start_waves(). The spawner handles
## scheduling, spawn-marker lookup, liveness tracking, and completion rules.
## Games never spawn framework enemies directly — they supply .tres files,
## enemy scenes, and Node3D spawn markers in named scene groups.
##
## Spawn markers: nodes in group "spawn_<tag>" (or "spawn_points" when
## SpawnEntry.spawn_tag is empty). The spawner picks randomly among them,
## so games control layout purely via marker placement.

var current_wave: int = -1
var is_running: bool = false
## Incremented on every stop/restart so pending timer lambdas self-cancel.
var live_enemy_count: int = 0

var _wave_set: WaveSet = null
var _enemy_container: Node = null
var _spawn_generation: int = 0
## Scheduled-but-not-yet-fired spawn count for the current wave.
var _spawns_pending: int = 0
## Guards against _finish_wave() being called more than once per wave.
var _wave_finishing: bool = false
## Suppresses repeated "no markers" warnings within a single wave.
var _warned_no_markers: bool = false


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func load_waves(wave_set: WaveSet) -> void:
	_wave_set = wave_set
	current_wave = -1


func start_waves() -> void:
	if is_running:
		push_warning("WaveSpawner: start_waves() called while already running — ignored")
		return
	if _wave_set == null or _wave_set.waves.is_empty():
		push_warning("WaveSpawner: start_waves() called with no waves loaded — ignored")
		return
	is_running = true
	current_wave = -1
	_spawn_generation += 1
	_begin_next_wave()


func stop_waves() -> void:
	## Cancels all pending spawn timers. Live enemies are intentionally left
	## alone — the game decides whether to clean them up.
	is_running = false
	_spawn_generation += 1


func complete_current_wave() -> void:
	## Only valid when the current wave uses Completion.MANUAL.
	if not is_running:
		return
	if current_wave < 0 or current_wave >= _wave_set.waves.size():
		return
	var wave_def: WaveDefinition = _wave_set.waves[current_wave]
	if wave_def.completion != WaveDefinition.Completion.MANUAL:
		push_warning("WaveSpawner: complete_current_wave() ignored — wave %d is not MANUAL completion" \
				% current_wave)
		return
	_finish_wave()


func set_enemy_container(node: Node) -> void:
	## Spawned enemies are parented here. Falls back to current_scene if null.
	_enemy_container = node


# ---------------------------------------------------------------------------
# Internal — wave lifecycle
# ---------------------------------------------------------------------------

func _begin_next_wave() -> void:
	_wave_finishing = false
	current_wave += 1
	if current_wave >= _wave_set.waves.size():
		is_running = false
		EventBus.all_waves_completed.emit()
		return

	var wave_def: WaveDefinition = _wave_set.waves[current_wave]
	_spawns_pending = 0
	_warned_no_markers = false

	EventBus.wave_started.emit(current_wave)

	# TIMED: start the duration countdown immediately.
	if wave_def.completion == WaveDefinition.Completion.TIMED:
		var gen: int = _spawn_generation
		get_tree().create_timer(wave_def.duration, false).timeout.connect(
			func() -> void:
				if _spawn_generation == gen:
					_finish_wave()
		)

	if wave_def.entries.is_empty():
		push_warning("WaveSpawner: wave %d has no entries — completing immediately" % current_wave)
		_finish_wave()
		return

	# Schedule every spawn in every entry independently from wave start.
	var gen: int = _spawn_generation
	for entry: SpawnEntry in wave_def.entries:
		if entry.enemy == null:
			push_error("WaveSpawner: SpawnEntry.enemy is null in wave %d — skipping entry" \
					% current_wave)
			continue
		if entry.enemy.scene == null:
			push_error("WaveSpawner: EnemyDefinition '%s' has no scene in wave %d — skipping entry" \
					% [entry.enemy.id, current_wave])
			continue
		for k: int in range(entry.count):
			_spawns_pending += 1
			var t: float = entry.start_delay + k * entry.interval
			_schedule_spawn(entry, t, gen)

	# All entries were invalid — treat as zero spawns.
	if _spawns_pending == 0:
		_check_all_defeated()


func _finish_wave() -> void:
	if not is_running or _wave_finishing:
		return
	_wave_finishing = true
	EventBus.wave_completed.emit(current_wave)
	var delay: float = _wave_set.time_between_waves
	if delay <= 0.0:
		_begin_next_wave()
		return
	var gen: int = _spawn_generation
	get_tree().create_timer(delay, false).timeout.connect(
		func() -> void:
			if _spawn_generation == gen:
				_begin_next_wave()
	)


# ---------------------------------------------------------------------------
# Internal — enemy spawn scheduling
# ---------------------------------------------------------------------------

func _schedule_spawn(entry: SpawnEntry, delay: float, gen: int) -> void:
	if delay <= 0.0:
		_do_spawn(entry, gen)
		return
	get_tree().create_timer(delay, false).timeout.connect(
		func() -> void: _do_spawn(entry, gen)
	)


func _do_spawn(entry: SpawnEntry, gen: int) -> void:
	if _spawn_generation != gen:
		return  # stop_waves() was called after this spawn was scheduled

	_spawns_pending -= 1

	var scene_instance: Node = entry.enemy.scene.instantiate()
	if not scene_instance is EnemyBase:
		push_error("WaveSpawner: scene root for '%s' is not EnemyBase — skipping" \
				% entry.enemy.id)
		scene_instance.free()
		_check_all_defeated()
		return

	var enemy: EnemyBase = scene_instance as EnemyBase
	enemy.setup(entry.enemy)

	var container: Node = _get_container()
	container.add_child(enemy)

	var marker: Node3D = _get_spawn_marker(entry.spawn_tag)
	enemy.global_position = marker.global_position if marker != null else Vector3.ZERO

	live_enemy_count += 1
	enemy.tree_exited.connect(_on_enemy_tree_exited)

	EventBus.enemy_spawned.emit(enemy)
	# Check here handles the case where the game kills the enemy synchronously
	# inside the enemy_spawned handler. queue_free() is deferred, so
	# live_enemy_count is still 1 at this point — check will not trigger.
	_check_all_defeated()


func _get_container() -> Node:
	if _enemy_container != null and is_instance_valid(_enemy_container):
		return _enemy_container
	return get_tree().current_scene


func _get_spawn_marker(spawn_tag: StringName) -> Node3D:
	var group: String = ("spawn_" + spawn_tag) if spawn_tag != &"" else "spawn_points"
	var markers: Array[Node] = get_tree().get_nodes_in_group(group)
	if markers.is_empty():
		if not _warned_no_markers:
			push_warning("WaveSpawner: no nodes in group '%s' — spawning at Vector3.ZERO" % group)
			_warned_no_markers = true
		return null
	return markers[randi() % markers.size()] as Node3D


func _on_enemy_tree_exited() -> void:
	live_enemy_count -= 1
	_check_all_defeated()


func _check_all_defeated() -> void:
	if not is_running or _wave_finishing:
		return
	if current_wave < 0 or current_wave >= _wave_set.waves.size():
		return
	var wave_def: WaveDefinition = _wave_set.waves[current_wave]
	if wave_def.completion == WaveDefinition.Completion.ALL_DEFEATED:
		if _spawns_pending == 0 and live_enemy_count == 0:
			_finish_wave()
