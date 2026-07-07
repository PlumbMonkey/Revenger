extends Node
## Pooled particle bursts, hit-flash, and screen shake.
##
## Games register their burst scenes at boot (register_burst), then anything
## can fire one via burst() or EventBus.vfx_burst_requested — both routes stay
## supported so gameplay code never needs a VFXManager reference. Burst scenes
## are game art (framework ships none): a GPUParticles3D root configured as
## one-shot, or any Node3D exposing fire().
##
## Pooling: each type pre-instantiates pool_size nodes, reused round-robin, so
## heavy wave combat never allocates particles mid-frame (PRD Phase 3 goal).

var _pools: Dictionary = {}
var _warned_types: Dictionary = {}


func _ready() -> void:
	EventBus.vfx_burst_requested.connect(burst)
	EventBus.screen_shake_requested.connect(shake)


func register_burst(burst_type: StringName, scene: PackedScene, pool_size: int = 8) -> void:
	if _pools.has(burst_type):
		for node: Node in _pools[burst_type]["nodes"]:
			node.queue_free()
	var nodes: Array[Node] = []
	for i: int in pool_size:
		var node: Node = scene.instantiate()
		if node is GPUParticles3D:
			(node as GPUParticles3D).emitting = false
		add_child(node)
		nodes.append(node)
	_pools[burst_type] = {"nodes": nodes, "next": 0}


func burst(burst_type: StringName, position: Vector3) -> void:
	var pool: Dictionary = _pools.get(burst_type, {})
	if pool.is_empty():
		if not _warned_types.has(burst_type):
			_warned_types[burst_type] = true
			push_warning("VFXManager: no burst registered for '%s' — call register_burst() at game boot" % burst_type)
		return
	var nodes: Array[Node] = pool["nodes"]
	var node: Node = nodes[pool["next"]]
	pool["next"] = (pool["next"] + 1) % nodes.size()
	if node is Node3D:
		(node as Node3D).global_position = position
	if node is GPUParticles3D:
		(node as GPUParticles3D).restart()
	elif node.has_method("fire"):
		node.call("fire")


## Phase 3 remainder: camera shake lands with the HUD/camera work.
func shake(intensity: float, duration: float) -> void:
	print_verbose("VFXManager: shake %.2f for %.2fs (camera hook pending)" % [intensity, duration])
