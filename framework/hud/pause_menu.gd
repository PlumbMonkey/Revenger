extends Control
## Pause menu: full-screen dim + Resume / Settings buttons.
## process_mode = PROCESS_MODE_ALWAYS so it works while the SceneTree is paused.
## Visibility is managed by HUDManager (reacts to EventBus.game_paused).
## Never owns pause logic — Resume calls GameManager.toggle_pause().

@onready var _settings_panel: Control = %SettingsPanel
@onready var _resume_button: Button = %ResumeButton
@onready var _scheme_option: OptionButton = %SchemeOption


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	_settings_panel.visible = false

	_scheme_option.add_item("Keyboard + Mouse", SettingsManager.ControlScheme.KEYBOARD_MOUSE)
	_scheme_option.add_item("Keyboard Only",    SettingsManager.ControlScheme.KEYBOARD)
	_scheme_option.add_item("Gamepad",          SettingsManager.ControlScheme.GAMEPAD)

	_resume_button.pressed.connect(_on_resume_pressed)
	%SettingsButton.pressed.connect(_on_settings_pressed)
	%BackButton.pressed.connect(_on_back_pressed)
	_scheme_option.item_selected.connect(_on_scheme_selected)


## Called by HUDManager on game_paused(true).
func show_menu() -> void:
	_settings_panel.visible = false
	_scheme_option.selected = _scheme_option.get_item_index(SettingsManager.control_scheme)
	visible = true
	_resume_button.grab_focus()


## Called by HUDManager on game_paused(false).
func hide_menu() -> void:
	visible = false


func _on_resume_pressed() -> void:
	GameManager.toggle_pause()


func _on_settings_pressed() -> void:
	_settings_panel.visible = true


func _on_back_pressed() -> void:
	_settings_panel.visible = false
	_resume_button.grab_focus()


func _on_scheme_selected(index: int) -> void:
	## SettingsManager.control_scheme setter already guards against same-value writes.
	SettingsManager.control_scheme = _scheme_option.get_item_id(index)
