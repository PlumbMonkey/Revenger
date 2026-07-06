extends Node
## Persistent player settings, including the active control scheme.
##
## Control scheme design: ALL devices stay bound and live at all times —
## selecting a scheme never disables inputs, so switching mid-game is always
## safe. The scheme exists for decisions that must pick one device:
## - aim source (mouse position vs right stick vs movement direction)
## - which button prompts the HUD shows
## Settings persist to user://settings.cfg immediately on change.

enum ControlScheme { KEYBOARD_MOUSE, KEYBOARD, GAMEPAD }

const SAVE_PATH := "user://settings.cfg"

var control_scheme: ControlScheme = ControlScheme.KEYBOARD_MOUSE:
	set(value):
		if control_scheme == value:
			return
		control_scheme = value
		_config.set_value("input", "control_scheme", value)
		_save()
		EventBus.control_scheme_changed.emit(value)

var _config := ConfigFile.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_config.load(SAVE_PATH)  # missing file is fine — defaults apply
	control_scheme = _config.get_value("input", "control_scheme", ControlScheme.KEYBOARD_MOUSE)


## Generic storage for later phases (audio volumes, video options...).
func set_setting(section: StringName, key: StringName, value: Variant) -> void:
	_config.set_value(section, key, value)
	_save()
	EventBus.settings_changed.emit(section, key, value)


func get_setting(section: StringName, key: StringName, default: Variant = null) -> Variant:
	return _config.get_value(section, key, default)


func _save() -> void:
	_config.save(SAVE_PATH)
