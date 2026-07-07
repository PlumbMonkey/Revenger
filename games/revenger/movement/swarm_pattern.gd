class_name SwarmPattern
extends MovementController
## Revenger swarmer movement: the ships fly as a tight cluster, then the first
## hit ANYWHERE in the cluster breaks the whole formation — every ship nearby
## separates (fans outward) and speeds up. Classic Defender swarm behaviour.
##
## Game-specific (not framework): only LinearPattern ships in framework/.
##
## params: direction, speed, spread_speed (lateral fan when broken),
## break_boost (forward speed multiplier when broken), tight_drift (gentle
## pre-break splay so the cluster reads as separate ships).

## A hit on one ship breaks every swarmer within this range of it.
const BREAK_RADIUS := 9.0

var _broken: bool = false
var _fan: Vector3 = Vector3.ZERO   # this ship's outward spread direction
var _forward: Vector3 = Vector3(0, 0, -1)
var _speed: float = 8.0


func _on_setup() -> void:
	actor.add_to_group("swarmers")
	_forward = (params.get("direction", Vector3(0, 0, -1)) as Vector3).normalized()
	_speed = params.get("speed", 8.0)
	# Each ship gets its own outward direction so the cluster fans apart, not
	# all the same way. Mostly horizontal, a little vertical.
	var ang: float = randf_range(0.0, TAU)
	_fan = Vector3(cos(ang), sin(ang) * 0.35, 0.0).normalized()


func compute_velocity(_current_velocity: Vector3, _delta: float) -> Vector3:
	if _broken:
		var spread: float = params.get("spread_speed", 7.0)
		var boost: float = params.get("break_boost", 1.8)
		return _forward * _speed * boost + _fan * spread
	# Tight formation: forward, with a small splay so 3 ships read as 3.
	var drift: float = params.get("tight_drift", 1.0)
	return _forward * _speed + _fan * drift


func is_broken() -> bool:
	return _broken


func on_damaged() -> void:
	break_formation()


## Break this ship out of formation and cascade to nearby swarmers, so one hit
## scatters the whole tight cluster. Guarded, so the cascade terminates.
func break_formation() -> void:
	if _broken:
		return
	_broken = true
	if actor == null or not actor.is_inside_tree():
		return
	for other: Node in actor.get_tree().get_nodes_in_group("swarmers"):
		if other == actor or not is_instance_valid(other) or not other is Node3D:
			continue
		if actor.global_position.distance_to((other as Node3D).global_position) > BREAK_RADIUS:
			continue
		for child: Node in other.get_children():
			if child is SwarmPattern:
				(child as SwarmPattern).break_formation()
