class_name WaveDefinition
extends Resource
## One wave: a composition of spawn entries plus the rule for when the
## wave counts as complete.

enum Completion {
	ALL_DEFEATED,  ## all scheduled spawns done AND no spawned enemy still alive
	TIMED,         ## complete `duration` seconds after wave start
	MANUAL,        ## game code calls WaveSpawner.complete_current_wave()
	               ## (scroll-driven progression, boss scripting, etc.)
}

@export var id: StringName

@export var entries: Array[SpawnEntry] = []

@export var completion: Completion = Completion.ALL_DEFEATED

## Only used when completion == TIMED.
@export var duration: float = 30.0
