extends Node3D
## Phase 5 acceptance check: the RescueObject state machine end to end,
## including the real Captor -> mutation pipeline. Headless; scene timers run
## in real wall-clock (confirmed gotcha from earlier phases), so waits below
## are sized to the actual fall/latch/ascend durations involved, and the test
## captor is tuned tiny/fast so its scenario stays cheap.

const HUMANOID_SCENE: PackedScene = preload("res://games/revenger/rescue/humanoid.tscn")
const CAPTOR_SCENE: PackedScene = preload("res://games/revenger/enemies/enemy_captor.tscn")

var _failures: PackedStringArray = []
var _transition_log: Array = []  # each entry: [npc, prev, new]


func _ready() -> void:
	VFXManager.register_burst(&"pulse_impact", preload("res://games/revenger/vfx/pulse_impact_burst.tscn"))
	VFXManager.register_burst(&"laser_impact", preload("res://games/revenger/vfx/laser_impact_burst.tscn"))
	# "smash" (humanoid LOST) has no dedicated burst yet — placeholder reuse,
	# same convention as the rest of the project's not-yet-built art slots.
	VFXManager.register_burst(&"smash", preload("res://games/revenger/vfx/pulse_impact_burst.tscn"))
	GameManager.start_game()  # fresh ScoreManager baseline (score 0, multiplier 1x)
	EventBus.rescue_state_changed.connect(_on_transition)

	await _check_lost_on_high_fall()
	await _check_rescued_by_catch()
	_check_release_while_threatened()
	await get_tree().process_frame  # let scenario 3's queue_free() actually clear the group
	await _check_captor_mutation()

	_report()


func _on_transition(npc: Node, prev: StringName, new: StringName) -> void:
	_transition_log.append([npc, prev, new])


func _make_humanoid(pos: Vector3) -> RescueObject:
	var h: RescueObject = HUMANOID_SCENE.instantiate()
	add_child(h)
	h.global_position = pos
	return h


func _log_for(npc: Node) -> Array:
	var out: Array = []
	for entry: Array in _transition_log:
		if entry[0] == npc:
			out.append([entry[1], entry[2]])
	return out


func _await_until(predicate: Callable, timeout_sec: float) -> bool:
	var deadline: float = Time.get_ticks_msec() / 1000.0 + timeout_sec
	while not predicate.call():
		if Time.get_ticks_msec() / 1000.0 > deadline:
			return false
		await get_tree().process_frame
	return true


# --- 1: threaten -> carry -> release from HIGH -> FALLING -> lands -> LOST ---
func _check_lost_on_high_fall() -> void:
	var h := _make_humanoid(Vector3(0, 20.0, 0))
	h.fall_speed = 200.0  # keep the real fall path but fast, for test speed
	var fake_captor := Node3D.new()
	add_child(fake_captor)
	fake_captor.global_position = h.global_position

	var lost_fired := [false]
	EventBus.npc_lost.connect(func(npc: Node) -> void:
		if npc == h:
			lost_fired[0] = true
	)

	h.threaten(fake_captor)
	h.carry(fake_captor)
	h.release()  # FALLING from y=20; ground_y=0, safe_fall_height=6 default -> smashes

	if h.state != RescueObject.State.FALLING:
		_failures.append("scenario1: expected FALLING right after release, got %s" % RescueObject.State.keys()[h.state])

	var landed: bool = await _await_until(func() -> bool: return h.state == RescueObject.State.LOST, 5.0)
	if not landed:
		_failures.append("scenario1: never reached LOST within 5s")
	if not lost_fired[0]:
		_failures.append("scenario1: npc_lost did not fire")

	var expected := [[&"IDLE", &"THREATENED"], [&"THREATENED", &"CARRIED"], [&"CARRIED", &"FALLING"], [&"FALLING", &"LOST"]]
	if _log_for(h) != expected:
		_failures.append("scenario1: transition log mismatch: %s" % [_log_for(h)])

	fake_captor.queue_free()


# --- 2: threaten -> carry -> release from HIGH -> catch() -> RESCUED, score += points ---
func _check_rescued_by_catch() -> void:
	var h := _make_humanoid(Vector3(10, 15.0, 0))
	var fake_captor := Node3D.new()
	add_child(fake_captor)
	fake_captor.global_position = h.global_position

	var rescued_fired := [false]
	EventBus.npc_rescued.connect(func(npc: Node, _pts: int) -> void:
		if npc == h:
			rescued_fired[0] = true
	)

	var score_before: int = ScoreManager.score
	h.threaten(fake_captor)
	h.carry(fake_captor)
	h.release()  # FALLING — well above ground, plenty of air time before it could land
	await get_tree().process_frame
	h.catch()

	if h.state != RescueObject.State.RESCUED:
		_failures.append("scenario2: expected RESCUED, got %s" % RescueObject.State.keys()[h.state])
	if not rescued_fired[0]:
		_failures.append("scenario2: npc_rescued did not fire")
	if ScoreManager.score != score_before + h.points:
		_failures.append("scenario2: score didn't increase by points (before=%d after=%d points=%d)" \
			% [score_before, ScoreManager.score, h.points])

	fake_captor.queue_free()


# --- 3: release while THREATENED (before lift) -> back to IDLE ---
func _check_release_while_threatened() -> void:
	var h := _make_humanoid(Vector3(-10, 0, 0))
	var fake_captor := Node3D.new()
	add_child(fake_captor)
	fake_captor.global_position = h.global_position

	h.threaten(fake_captor)
	h.release()

	if h.state != RescueObject.State.IDLE:
		_failures.append("scenario3: expected IDLE after release while THREATENED, got %s" % RescueObject.State.keys()[h.state])

	var expected := [[&"IDLE", &"THREATENED"], [&"THREATENED", &"IDLE"]]
	if _log_for(h) != expected:
		_failures.append("scenario3: transition log mismatch: %s" % [_log_for(h)])

	fake_captor.queue_free()
	# Ends back in IDLE (a valid radar_pickup candidate) — free it so it can't
	# be picked up as a stray target by scenario 4's real Captor.
	h.queue_free()


# --- 4: real Captor carries a humanoid off the top -> LOST + mutant spawned ---
func _check_captor_mutation() -> void:
	var h := _make_humanoid(Vector3(30, 0.0, 0))

	# IMPORTANT: _ready() (and therefore target-acquisition) runs synchronously
	# during add_child() in a running tree — position and tuning must be set
	# BEFORE add_child(), or acquisition sees the pre-instantiate defaults.
	var captor: Captor = CAPTOR_SCENE.instantiate()
	# .position (local), not .global_position — the node isn't in the tree yet,
	# so there's no parent chain to resolve a global transform against. Since
	# this scene's root sits at the origin, local == global for a direct child.
	captor.position = Vector3(30, 0.1, 0)
	# Tuned for a fast, deterministic headless run — real gameplay uses the
	# scene's own defaults (this only overrides the just-spawned instance).
	captor.grab_radius = 2.0
	captor.latch_duration = 0.05
	captor.carry_off_y = 0.5
	captor.ascend_speed = 30.0
	captor.dive_speed = 10.0
	add_child(captor)

	var reached: bool = await _await_until(func() -> bool: return h.state == RescueObject.State.LOST, 8.0)
	if not reached:
		_failures.append("scenario4: humanoid never reached LOST via the captor pipeline")

	await get_tree().process_frame  # let the mutant's own _ready() register itself

	var mutant_found := false
	for node: Node in get_tree().get_nodes_in_group("radar_enemy"):
		if node is EnemyBase and (node as EnemyBase).definition != null \
				and (node as EnemyBase).definition.id == &"mutant":
			mutant_found = true
	if not mutant_found:
		_failures.append("scenario4: no mutant found in radar_enemy group after carry-off")

	if is_instance_valid(captor) and not captor.is_queued_for_deletion():
		_failures.append("scenario4: captor was not freed after mutating")


func _report() -> void:
	if _failures.is_empty():
		print("RESCUE CHECK PASS — lost-on-fall, rescued-by-catch, release-while-threatened, and captor mutation all verified")
	else:
		print("RESCUE CHECK FAIL:")
		for f: String in _failures:
			print("  - ", f)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)
