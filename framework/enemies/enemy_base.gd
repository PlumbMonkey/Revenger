class_name EnemyBase
extends CharacterBody3D
## Shared enemy base: health, swappable movement pattern, hit/death behaviour.
##
## Game-specific enemies extend the scene (visuals, collision shape) but
## never this script. Scoring flows from the enemy_died signal, not from
## direct ScoreManager calls. Wave completion is the spawner's responsibility.
## Framework-agnostic: never references any concrete game or game manager.

var definition: EnemyDefinition
var health: float
var _pattern: MovementController


func _ready() -> void:
	add_to_group("radar_enemy")


func setup(p_definition: EnemyDefinition) -> void:
	definition = p_definition
	health = definition.max_health
	if definition.movement_pattern == null:
		return
	var node: Object = definition.movement_pattern.new()
	if not node is MovementController:
		push_error("EnemyBase: movement_pattern '%s' is not a MovementController subclass (enemy: %s)" \
				% [definition.movement_pattern.resource_path, definition.id])
		node.free()
		return
	_pattern = node as MovementController
	add_child(_pattern)
	_pattern.setup(self, definition.movement_params)


func take_hit(damage: float) -> void:
	health -= damage
	EventBus.enemy_hit.emit(self, damage, global_position)
	EventBus.vfx_burst_requested.emit(definition.hit_flash, global_position)
	if health <= 0.0:
		die()


func die() -> void:
	EventBus.enemy_died.emit(self, definition.points, global_position)
	EventBus.vfx_burst_requested.emit(definition.death_burst, global_position)
	queue_free()


func _physics_process(delta: float) -> void:
	if _pattern == null:
		return
	velocity = _pattern.compute_velocity(velocity, delta)
	move_and_slide()
