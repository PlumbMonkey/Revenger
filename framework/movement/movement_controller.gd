class_name MovementController
extends Node
## The input -> movement contract shared by all three games.
##
## Stubbed in Phase 1 (ahead of the Phase 6 schedule) because the Enemy base
## class and player actors are shaped by how movement plugs in. Concrete
## implementations: thrust-flight (Revenger), flap-physics (Joust-alike),
## twin-stick (Robotron-alike). The framework only ever talks to this base
## class — it must never know which implementation is active.
##
## Usage: add a MovementController subclass as a child of the actor and call
## setup(). Each physics frame the actor calls compute_velocity() and applies
## the result itself (move_and_slide etc.) — controllers compute intent,
## actors move. Enemy patterns are these too: EnemyBase instantiates the
## pattern script from EnemyDefinition.movement_pattern and calls setup()
## with EnemyDefinition.movement_params.

## The body this controller steers. Never assume a concrete subclass beyond
## Node3D — patterns must work for any game's actors.
var actor: Node3D

## Pattern-specific tuning (speed, direction, amplitude...). For enemies this
## comes straight from EnemyDefinition.movement_params.
var params: Dictionary = {}

## Runtime multiplier on the pattern's speed. Actors set this to accelerate or
## slow a mover without re-tuning params (e.g. an enemy enraging on damage).
## Patterns that move should multiply their speed by this.
var speed_scale: float = 1.0


func setup(p_actor: Node3D, p_params: Dictionary = {}) -> void:
	actor = p_actor
	params = p_params
	_on_setup()


## Override to cache params / initialise pattern state after setup().
func _on_setup() -> void:
	pass


## Return the new velocity given the current one. Read input/AI state here.
## Gameplay is on a plane for all three launch games; the unused axis stays 0.
func compute_velocity(current_velocity: Vector3, _delta: float) -> Vector3:
	push_error("MovementController.compute_velocity() must be overridden")
	return current_velocity


## Optional hook for discrete actions (flap impulse, dash) outside the
## per-frame velocity flow.
func handle_action(_action: StringName) -> void:
	pass


## Called by the actor the first time it survives a hit. Patterns may change
## behaviour in response — e.g. a swarm breaking formation. No-op by default.
func on_damaged() -> void:
	pass
