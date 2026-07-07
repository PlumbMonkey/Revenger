class_name Humanoid
extends RescueObject
## Revenger-specific: binds rescue states to the shared VRoid animation
## contract (author once on one VRM rig; the same 5 clip names play on all
## 4 humanoids). Falls back gracefully with no AnimationPlayer clips until
## the real models exist — the placeholder capsule just won't animate.

@onready var _anim: AnimationPlayer = get_node_or_null("AnimationPlayer")


func _on_state_changed(_prev: State, new_state: State) -> void:
	match new_state:
		State.IDLE:
			_play(&"run")
		State.THREATENED, State.CARRIED:
			_play(&"struggle")
		State.FALLING:
			_play(&"fall")
		State.RESCUED:
			_play(&"wave")
			_free_after(1.5)
		State.LOST:
			_play(&"smashed")
			EventBus.vfx_burst_requested.emit(&"smash", global_position)
			_free_after(1.0)


func _play(clip: StringName) -> void:
	if _anim != null and _anim.has_animation(clip):
		_anim.play(clip)


func _free_after(seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(queue_free)
