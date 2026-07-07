class_name LaserBolt
extends Area3D
## Defender-style laser bolt. Flies along its local -Z; on hitting a body it
## requests an impact burst via the EventBus and frees itself. Spawn one at a
## muzzle position, aim it (look_at or set basis), add to scene — done.

@export var speed: float = 60.0
@export var lifetime: float = 1.5
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
	if body is EnemyBase:
		(body as EnemyBase).take_hit(1.0)
	EventBus.vfx_burst_requested.emit(impact_burst, global_position)
	queue_free()
