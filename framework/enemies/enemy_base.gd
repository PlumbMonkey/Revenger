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
var _damaged_reacted: bool = false


func _ready() -> void:
	add_to_group("radar_enemy")


func setup(p_definition: EnemyDefinition) -> void:
	definition = p_definition
	health = definition.max_health
	_setup_weapon()
	if definition.material_override != null:
		_apply_material(self, definition.material_override)
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
	else:
		_react_to_damage()


## First surviving hit only: break apart (burst + shrink) and speed up.
## All three effects are opt-in via EnemyDefinition; no-op by default.
func _react_to_damage() -> void:
	if _damaged_reacted:
		return
	_damaged_reacted = true
	if definition.damaged_burst != &"":
		EventBus.vfx_burst_requested.emit(definition.damaged_burst, global_position)
	if _pattern != null and definition.damaged_speed_mult != 1.0:
		_pattern.speed_scale = definition.damaged_speed_mult
	if definition.damaged_scale != 1.0:
		scale = Vector3.ONE * definition.damaged_scale


func die() -> void:
	EventBus.enemy_died.emit(self, definition.points, global_position)
	EventBus.vfx_burst_requested.emit(definition.death_burst, global_position)
	queue_free()


func _physics_process(delta: float) -> void:
	if _pattern == null:
		return
	velocity = _pattern.compute_velocity(velocity, delta)
	move_and_slide()


func _apply_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child: Node in node.get_children():
		_apply_material(child, mat)


## Weapon comes from data (EnemyDefinition.weapon_scene + fire_interval).
## Fires straight ahead along local -Z; the projectile scene's collision
## layers decide what it can hit. Timer is pausable with the tree.
func _setup_weapon() -> void:
	if definition.weapon_scene == null or definition.fire_interval <= 0.0:
		return
	var timer := Timer.new()
	timer.wait_time = definition.fire_interval
	timer.autostart = true
	timer.timeout.connect(_fire)
	add_child(timer)


func _fire() -> void:
	var shot: Node = definition.weapon_scene.instantiate()
	get_parent().add_child(shot)
	if shot is Node3D:
		var shot3d := shot as Node3D
		shot3d.global_transform.basis = global_transform.basis
		shot3d.global_position = global_position + global_transform.basis * definition.muzzle_offset
