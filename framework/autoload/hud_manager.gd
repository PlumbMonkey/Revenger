extends Node
## Radar/minimap, score display, lives/health HUD.
##
## Phase 1 stub: subscribes to every signal the real HUD will render, so the
## wiring is proven now; the actual Control scenes land in Phase 4. Games
## register their HUD layer with register_hud() rather than building their own
## score/lives displays.

var hud_root: Control = null


func _ready() -> void:
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.combo_changed.connect(_on_combo_changed)
	EventBus.lives_changed.connect(_on_lives_changed)
	EventBus.wave_started.connect(_on_wave_started)


func register_hud(root: Control) -> void:
	hud_root = root


func _on_score_changed(_score: int) -> void:
	pass  # Phase 4: update score label


func _on_combo_changed(_combo_count: int, _multiplier: float) -> void:
	pass  # Phase 4: update combo/multiplier display


func _on_lives_changed(_lives: int) -> void:
	pass  # Phase 4: update lives display


func _on_wave_started(_wave_index: int) -> void:
	pass  # Phase 4: wave banner / radar refresh
