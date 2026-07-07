extends Node3D
## Visual demo + headless check for the Defender-style laser + impact burst.
## Run windowed to watch bolts streak into the wall and explode; headless it
## verifies the full loop (spawn -> fly -> collide -> pooled burst) and exits.

const BOLT: PackedScene = preload("res://games/revenger/weapons/laser_bolt.tscn")
const IMPACT: PackedScene = preload("res://games/revenger/vfx/laser_impact_burst.tscn")

var _impacts: int = 0


func _ready() -> void:
	VFXManager.register_burst(&"laser_impact", IMPACT)
	EventBus.vfx_burst_requested.connect(
		func(_type: StringName, _pos: Vector3) -> void: _impacts += 1
	)
	$FireTimer.timeout.connect(_fire)

	if DisplayServer.get_name() == "headless":
		await get_tree().create_timer(3.0).timeout
		if _impacts > 0:
			print("LASER CHECK PASS — %d bolts hit and requested impact bursts" % _impacts)
			get_tree().quit(0)
		else:
			print("LASER CHECK FAIL — no impact bursts after 3s")
			get_tree().quit(1)


func _fire() -> void:
	var bolt: Projectile = BOLT.instantiate()
	add_child(bolt)
	# alternate between the two wing-gun heights, flying toward -Z
	var side: float = 1.0 if (Time.get_ticks_msec() / 450) % 2 == 0 else -1.0
	bolt.global_position = Vector3(side * 4.0, 2.0, 22.0)
