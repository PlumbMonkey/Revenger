class_name ThrustFlightController
extends MovementController
## Revenger player movement: momentum-based thrust flight on the XZ plane.
## Reads InputMap actions (never raw devices, per the input architecture) in
## compute_velocity() — the same MovementController contract AI patterns use,
## which is the point: one interface serves both AI movers and a human ship.
##
## params: accel (units/s^2), max_speed, damping (higher = stops sooner).

func compute_velocity(current_velocity: Vector3, delta: float) -> Vector3:
	var accel: float = params.get("accel", 40.0)
	var max_speed: float = params.get("max_speed", 25.0) * speed_scale
	var damping: float = params.get("damping", 3.0)

	var input_vec: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var thrust := Vector3(input_vec.x, 0.0, input_vec.y)  # up on stick = -Z = forward

	var v := current_velocity
	v.y = 0.0  # thrust flight stays on the gameplay plane
	if thrust.length_squared() > 0.0:
		v += thrust * accel * delta
	else:
		v *= maxf(0.0, 1.0 - damping * delta)  # coast to rest

	if v.length() > max_speed:
		v = v.normalized() * max_speed
	return v
