class_name Captor
extends EnemyBase
## The Lander (Phase 5 rescue mechanic) — the one enemy with real script
## logic; everything else in the roster is data. Seeks the nearest IDLE
## RescueObject, descends onto it (threaten), briefly latches (grounded
## struggle), then carries it upward. If it reaches carry_off_y with its
## target still attached, the target is LOST and this captor mutates into
## another enemy at the same spot. Falls back to its EnemyDefinition's own
## movement_pattern (a harmless straggler) if it never finds a target —
## inherited from EnemyBase, untouched.

enum CarryState { DIVING, LATCHED, ASCENDING }

@export var dive_speed: float = 5.0
@export var ascend_speed: float = 4.0
@export var grab_radius: float = 1.5
@export var latch_duration: float = 0.4
@export var carry_off_y: float = 40.0
## Spawned in this captor's place if it carries a target off the top.
## Data, not a hardcoded scene — swap the mutant type here.
@export var mutant_definition: EnemyDefinition

var _target: RescueObject = null
var _carry_state: CarryState = CarryState.DIVING
var _latch_timer: float = 0.0


func _ready() -> void:
	super._ready()
	_acquire_target()


func _acquire_target() -> void:
	var best: RescueObject = null
	var best_dist: float = INF
	for node: Node in get_tree().get_nodes_in_group("radar_pickup"):
		if not is_instance_valid(node) or not (node is RescueObject):
			continue
		var candidate := node as RescueObject
		if candidate.state != RescueObject.State.IDLE:
			continue
		var d: float = global_position.distance_to(candidate.global_position)
		if d < best_dist:
			best_dist = d
			best = candidate
	_target = best
	_carry_state = CarryState.DIVING


func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		super._physics_process(delta)
		return

	match _carry_state:
		CarryState.DIVING:
			var to_target: Vector3 = _target.global_position - global_position
			if to_target.length() <= grab_radius:
				_target.threaten(self)
				_carry_state = CarryState.LATCHED
				_latch_timer = latch_duration
				velocity = Vector3.ZERO
			else:
				velocity = to_target.normalized() * dive_speed
			move_and_slide()

		CarryState.LATCHED:
			velocity = Vector3.ZERO
			move_and_slide()
			_latch_timer -= delta
			if _latch_timer <= 0.0:
				_target.carry(self)
				if _target.state == RescueObject.State.CARRIED:
					_carry_state = CarryState.ASCENDING
				else:
					# another captor already had it — give up, go straggler
					_target = null

		CarryState.ASCENDING:
			velocity = Vector3.UP * ascend_speed
			move_and_slide()
			if global_position.y >= carry_off_y:
				var lost_target: RescueObject = _target
				_target = null
				lost_target.carried_off()
				_mutate()


func die() -> void:
	if _target != null and is_instance_valid(_target) and _target.state == RescueObject.State.CARRIED:
		_target.release()
	_target = null
	super.die()


func _mutate() -> void:
	if mutant_definition == null or mutant_definition.scene == null:
		queue_free()
		return
	var mutant_scene: Node = mutant_definition.scene.instantiate()
	if mutant_scene is EnemyBase:
		var mutant := mutant_scene as EnemyBase
		mutant.setup(mutant_definition)
		var parent: Node = get_parent()
		if parent != null:
			parent.add_child(mutant)
			mutant.global_position = global_position
		else:
			mutant.free()
	else:
		mutant_scene.free()
	queue_free()
