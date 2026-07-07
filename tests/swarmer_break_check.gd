extends Node3D
## Verifies swarm-scatter: 3 swarmers spawn as a tight cluster; ONE hit breaks
## the whole formation (all separate + speed up); the hit ship survives its
## first hit and dies on the second.

const SWARMER_DEF := "res://games/revenger/enemies/swarmer.tres"
const PULSE_IMPACT := preload("res://games/revenger/vfx/pulse_impact_burst.tscn")

var _failures: PackedStringArray = []


func _ready() -> void:
	VFXManager.register_burst(&"pulse_impact", PULSE_IMPACT)
	var def: EnemyDefinition = load(SWARMER_DEF)
	if def.max_health < 2.0:
		_failures.append("swarmer max_health %.1f — must be >= 2 to survive a hit" % def.max_health)

	# Spawn a tight cluster of 3 (same spot, like a real set-of-3).
	var swarm: Array[EnemyBase] = []
	var patterns: Array = []
	for i in 3:
		var e: EnemyBase = (def.scene as PackedScene).instantiate()
		e.setup(def)
		add_child(e)
		e.global_position = Vector3(i * 0.5, 0, 0)  # within BREAK_RADIUS
		swarm.append(e)
		for c in e.get_children():
			if c is SwarmPattern:
				patterns.append(c)

	if patterns.size() != 3:
		_failures.append("expected 3 SwarmPatterns, found %d" % patterns.size())
		_report(); return

	await _run(swarm, patterns)
	_report()


func _run(swarm: Array[EnemyBase], patterns: Array) -> void:
	# All start in formation.
	for p in patterns:
		if p.is_broken():
			_failures.append("a swarmer was broken before any hit")

	var v_tight: Vector3 = patterns[1].compute_velocity(Vector3.ZERO, 0.016)

	# ONE hit on swarm[0] should break the WHOLE cluster.
	swarm[0].take_hit(1.0)
	await get_tree().process_frame

	for i in patterns.size():
		if not patterns[i].is_broken():
			_failures.append("swarmer %d did not break formation after cluster hit" % i)

	# Broken ships move faster and fan sideways vs the tight forward drift.
	var v_broken: Vector3 = patterns[1].compute_velocity(Vector3.ZERO, 0.016)
	if v_broken.length() <= v_tight.length():
		_failures.append("broken swarmer did not speed up (%.1f vs %.1f)" % [v_broken.length(), v_tight.length()])
	if absf(v_broken.x) <= absf(v_tight.x) + 0.5:
		_failures.append("broken swarmer did not spread sideways")

	# Hit ship survived its first hit; dies on the second.
	if not is_instance_valid(swarm[0]) or swarm[0].is_queued_for_deletion():
		_failures.append("hit swarmer died on the FIRST hit (should survive with 2 HP)")
	else:
		swarm[0].take_hit(1.0)
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(swarm[0]) and not swarm[0].is_queued_for_deletion():
			_failures.append("swarmer survived the SECOND hit (should die)")


func _report() -> void:
	if _failures.is_empty():
		print("SWARM SCATTER CHECK PASS — one hit breaks the tight cluster, all spread + speed up, hit ship dies on 2nd")
	else:
		print("SWARM SCATTER CHECK FAIL:")
		for f in _failures:
			print("  - ", f)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)
