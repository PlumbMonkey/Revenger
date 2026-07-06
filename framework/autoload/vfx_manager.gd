extends Node
## Pooled particle bursts, hit-flash, and screen shake.
##
## Phase 1 stub: the public API is final ("trigger burst at position"), the
## object pooling and actual particle scenes land in Phase 3. Systems either
## call burst() directly or emit EventBus.vfx_burst_requested — both routes
## stay supported so gameplay code never needs a VFXManager reference.


func _ready() -> void:
	EventBus.vfx_burst_requested.connect(burst)
	EventBus.screen_shake_requested.connect(shake)


## Phase 3 replaces the body with a pooled GPUParticles burst lookup by type.
func burst(burst_type: StringName, position: Vector3) -> void:
	print_verbose("VFXManager: burst '%s' at %s (Phase 3 pooling pending)" % [burst_type, position])


## Phase 3 implements camera shake; intensity/duration contract is final.
func shake(intensity: float, duration: float) -> void:
	print_verbose("VFXManager: shake %.2f for %.2fs (Phase 3 pending)" % [intensity, duration])
