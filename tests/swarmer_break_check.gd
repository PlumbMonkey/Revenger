extends Node3D
## Verifies the swarmer's damage reaction: survives the first hit, breaks apart
## (shrinks) and doubles speed, then dies on the second hit.

const SWARMER_DEF := "res://games/revenger/enemies/swarmer.tres"
const PULSE_IMPACT := preload("res://games/revenger/vfx/pulse_impact_burst.tscn")

var _failures: PackedStringArray = []


func _ready() -> void:
	VFXManager.register_burst(&"pulse_impact", PULSE_IMPACT)

	var def: EnemyDefinition = load(SWARMER_DEF)
	if def.max_health < 2.0:
		_failures.append("swarmer max_health is %.1f — must be >= 2 to survive a hit" % def.max_health)

	var enemy: EnemyBase = (def.scene as PackedScene).instantiate()
	enemy.setup(def)
	add_child(enemy)
	enemy.global_position = Vector3.ZERO

	var pattern: MovementController = null
	for c in enemy.get_children():
		if c is MovementController:
			pattern = c
	if pattern == null:
		_failures.append("swarmer has no MovementController child")

	await _run(enemy, pattern)
	_report()


func _run(enemy: EnemyBase, pattern: MovementController) -> void:
	# --- first hit: should survive, shrink, and speed up ---
	enemy.take_hit(1.0)
	await get_tree().process_frame

	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		_failures.append("swarmer died on the FIRST hit (should survive with 2 HP)")
		return

	if not is_equal_approx(enemy.scale.x, 0.6):
		_failures.append("swarmer did not shrink on first hit (scale.x=%.2f, want 0.6)" % enemy.scale.x)
	if pattern != null and not is_equal_approx(pattern.speed_scale, 2.0):
		_failures.append("swarmer speed not doubled (speed_scale=%.2f, want 2.0)" % pattern.speed_scale)

	# --- second hit: should die ---
	enemy.take_hit(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		_failures.append("swarmer survived the SECOND hit (should die)")


func _report() -> void:
	if _failures.is_empty():
		print("SWARMER BREAK CHECK PASS — survives first hit, shrinks + doubles speed, dies on second")
	else:
		print("SWARMER BREAK CHECK FAIL:")
		for f in _failures:
			print("  - ", f)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)
