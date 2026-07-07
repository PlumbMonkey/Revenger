extends Control
## Game HUD — score, high-score, lives, combo multiplier, wave banner, radar.
## Driven entirely by EventBus signals; no game-specific logic.
## Instantiated by HUDManager into its CanvasLayer (layer 10).

@onready var _score_label: Label = %ScoreLabel
@onready var _high_score_label: Label = %HighScoreLabel
@onready var _lives_label: Label = %LivesLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _wave_banner: Label = %WaveBanner
@onready var _banner_timer: Timer = %BannerTimer

## Set to true on game_over so the banner is never hidden by the wave timer.
var _game_over: bool = false


func _ready() -> void:
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.high_score_changed.connect(_on_high_score_changed)
	EventBus.lives_changed.connect(_on_lives_changed)
	EventBus.combo_changed.connect(_on_combo_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.game_over.connect(_on_game_over)
	_banner_timer.timeout.connect(_on_banner_timeout)

	_wave_banner.visible = false
	_combo_label.visible = false
	_score_label.text = "Score: %d" % ScoreManager.score
	_high_score_label.text = "Best: %d" % ScoreManager.high_score
	_lives_label.text = "Lives: %d" % maxi(0, GameManager.lives)


func _on_score_changed(score: int) -> void:
	_score_label.text = "Score: %d" % score


func _on_high_score_changed(hs: int) -> void:
	_high_score_label.text = "Best: %d" % hs


func _on_lives_changed(lives: int) -> void:
	_lives_label.text = "Lives: %d" % maxi(0, lives)


func _on_combo_changed(_count: int, mult: float) -> void:
	if mult > 1.0:
		_combo_label.text = "x%.1f" % mult
		_combo_label.visible = true
	else:
		_combo_label.visible = false


func _on_wave_started(i: int) -> void:
	## Shows "WAVE N" for 2 s. Second call restarts the timer (overlapping waves).
	_wave_banner.text = "WAVE %d" % (i + 1)
	_wave_banner.visible = true
	_banner_timer.start()  # restarts if already running


func _on_game_over() -> void:
	_game_over = true
	_banner_timer.stop()
	_wave_banner.text = "GAME OVER"
	_wave_banner.visible = true


func _on_banner_timeout() -> void:
	if not _game_over:
		_wave_banner.visible = false
