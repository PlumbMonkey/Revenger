extends Node
## Score events, combo/multiplier logic, and persistent high-score save.
##
## Listens to EventBus for anything worth points; nothing calls this directly.
## Combo: kills within COMBO_WINDOW seconds of each other raise the multiplier,
## which decays back to 1x when the window lapses.

const SAVE_PATH := "user://high_scores.cfg"
const COMBO_WINDOW := 2.0
const MAX_MULTIPLIER := 8.0

var score: int = 0
var high_score: int = 0
var combo_count: int = 0
var multiplier: float = 1.0

var _combo_timer: Timer


func _ready() -> void:
	_combo_timer = Timer.new()
	_combo_timer.one_shot = true
	_combo_timer.wait_time = COMBO_WINDOW
	_combo_timer.timeout.connect(_on_combo_lapsed)
	add_child(_combo_timer)

	EventBus.game_started.connect(reset)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.npc_rescued.connect(_on_npc_rescued)

	_load_high_score()


func reset() -> void:
	score = 0
	combo_count = 0
	multiplier = 1.0
	EventBus.score_changed.emit(score)
	EventBus.combo_changed.emit(combo_count, multiplier)


func add_points(base_points: int) -> void:
	score += int(base_points * multiplier)
	EventBus.score_changed.emit(score)
	if score > high_score:
		high_score = score
		EventBus.high_score_changed.emit(high_score)
		_save_high_score()


func _on_enemy_died(_enemy: Node, points: int, _position: Vector3) -> void:
	_bump_combo()
	add_points(points)


func _on_npc_rescued(_npc: Node, points: int) -> void:
	add_points(points)


func _bump_combo() -> void:
	combo_count += 1
	# First kill scores at 1x; each chained kill adds +0.5x.
	multiplier = minf(1.0 + (combo_count - 1) * 0.5, MAX_MULTIPLIER)
	_combo_timer.start()
	EventBus.combo_changed.emit(combo_count, multiplier)


func _on_combo_lapsed() -> void:
	combo_count = 0
	multiplier = 1.0
	EventBus.combo_changed.emit(combo_count, multiplier)


func _load_high_score() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		high_score = config.get_value("scores", "high_score", 0)


func _save_high_score() -> void:
	var config := ConfigFile.new()
	config.set_value("scores", "high_score", high_score)
	config.save(SAVE_PATH)
