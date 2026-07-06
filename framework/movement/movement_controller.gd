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
## Usage: add a MovementController subclass as a child of the actor. Each
## physics frame the actor calls compute_velocity() and applies the result
## itself (move_and_slide etc.) — controllers compute intent, actors move.


## Return the new velocity given the current one. Read input/AI state here.
## Gameplay is on a plane for all three launch games; the unused axis stays 0.
func compute_velocity(current_velocity: Vector3, _delta: float) -> Vector3:
	push_error("MovementController.compute_velocity() must be overridden")
	return current_velocity


## Optional hook for discrete actions (flap impulse, dash) outside the
## per-frame velocity flow.
func handle_action(_action: StringName) -> void:
	pass
