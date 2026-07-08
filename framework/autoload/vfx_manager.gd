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

var _camera: Camera3D = null
var _cam_rest: Transform3D
var _shake_time_left: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0


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


## The game registers its camera once; shake() then works from anywhere.
## The rest transform is captured here — treat the camera as static while a
## shake plays (games with a moving camera rig should register a camera that
## is a child of the rig, so the rig moves and the child shakes).
func register_camera(cam: Camera3D) -> void:
	_end_shake()
	_camera = cam
	_cam_rest = cam.transform


## Decaying random positional offset. Overlapping requests take the max of
## intensity and remaining time — repeated hits never stack into nausea.
func shake(intensity: float, duration: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	if _shake_time_left <= 0.0:
		_cam_rest = _camera.transform  # re-capture in case the game moved it
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_time_left = maxf(_shake_time_left, duration)
	_shake_duration = maxf(_shake_duration, duration)


func _process(delta: float) -> void:
	if _shake_time_left <= 0.0:
		return
	if _camera == null or not is_instance_valid(_camera):
		_shake_time_left = 0.0
		return
	_shake_time_left -= delta
	if _shake_time_left <= 0.0:
		_end_shake()
		return
	var falloff: float = _shake_time_left / maxf(_shake_duration, 0.001)
	var magnitude: float = _shake_intensity * falloff
	var offset := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)) * magnitude
	_camera.transform = _cam_rest
	_camera.transform.origin += offset


func _end_shake() -> void:
	if _camera != null and is_instance_valid(_camera) and _shake_duration > 0.0:
		_camera.transform = _cam_rest
	_shake_time_left = 0.0
	_shake_duration = 0.0
	_shake_intensity = 0.0
