extends Node
## Overall game state, level/wave progression, and pause.
##
## Owns the top-level state machine. Everything else reacts to the EventBus
## signals this emits — nothing should poll GameManager state every frame.

enum State { BOOT, MENU, PLAYING, PAUSED, GAME_OVER }

const STARTING_LIVES := 3

var state: State = State.BOOT
var current_level: int = 0
var lives: int = STARTING_LIVES


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.player_died.connect(_on_player_died)


func start_game() -> void:
	lives = STARTING_LIVES
	current_level = 0
	state = State.PLAYING
	EventBus.lives_changed.emit(lives)
	EventBus.game_started.emit()
	EventBus.level_started.emit(current_level)


func toggle_pause() -> void:
	if state != State.PLAYING and state != State.PAUSED:
		return
	var paused := state != State.PAUSED
	state = State.PAUSED if paused else State.PLAYING
	get_tree().paused = paused
	EventBus.game_paused.emit(paused)


func advance_level() -> void:
	current_level += 1
	EventBus.level_started.emit(current_level)


func _on_player_died() -> void:
	lives -= 1
	EventBus.lives_changed.emit(lives)
	if lives <= 0:
		state = State.GAME_OVER
		EventBus.game_over.emit()
