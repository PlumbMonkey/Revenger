extends Node
## Data-driven enemy wave spawning.
##
## Phase 1 stub: the public API and EventBus signalling are final, but wave
## definitions-as-Resources and actual enemy instancing land in Phase 2.
## Games hand this a list of wave definition Resources and call start_waves();
## they never spawn framework enemies themselves.

var waves: Array = []
var current_wave: int = -1
var is_running: bool = false


func load_waves(wave_definitions: Array) -> void:
	waves = wave_definitions
	current_wave = -1


func start_waves() -> void:
	if waves.is_empty():
		push_warning("WaveSpawner: start_waves() called with no waves loaded")
		return
	is_running = true
	_begin_next_wave()


func stop_waves() -> void:
	is_running = false
	current_wave = -1


## Phase 2 replaces this with timed, data-driven enemy instancing.
func _begin_next_wave() -> void:
	current_wave += 1
	if current_wave >= waves.size():
		is_running = false
		EventBus.all_waves_completed.emit()
		return
	EventBus.wave_started.emit(current_wave)


func complete_current_wave() -> void:
	if not is_running:
		return
	EventBus.wave_completed.emit(current_wave)
	_begin_next_wave()
