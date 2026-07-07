class_name LinearPattern
extends MovementController
## Framework-bundled baseline movement: constant velocity in a fixed direction.
##
## params: {"direction": Vector3.LEFT, "speed": 5.0}
##
## This is the only movement pattern in framework/ — it exists so the
## framework is self-testable without any game code. Game-specific patterns
## (thrust-flight, flap-physics, twin-stick, swoop, etc.) live in
## games/<name>/scripts/ — never here.


func compute_velocity(_current_velocity: Vector3, _delta: float) -> Vector3:
	var direction: Vector3 = (params.get("direction", Vector3.LEFT) as Vector3).normalized()
	var speed: float = params.get("speed", 5.0)
	return direction * speed * speed_scale
