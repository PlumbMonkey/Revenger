class_name Projectile
extends Area3D
## Generic projectile: flies along local -Z, damages whatever it hits, bursts,
## frees itself. WHO it can hit is decided by collision layers/masks on the
## scene, never by type checks here:
##   player shots: layer player_shots(4), mask world+enemies
##   enemy shots:  layer enemy_shots(5),  mask world+player
## Spawn at a muzzle, aim it (basis / look_at), add to scene — done.

@export var speed: float = 60.0
@export var lifetime: float = 1.5
@export var damage: float = 1.0
@export var impact_burst: StringName = &"laser_impact"

var _age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += -transform.basis.z * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_hit"):
		body.call("take_hit", damage)
	EventBus.vfx_burst_requested.emit(impact_burst, global_position)
	queue_free()
