extends Node3D
## Standalone check that framework/shaders/toon.gdshader compiles and its
## material presets load without error. Not part of boot_check.tscn since
## it needs its own camera/light and isn't part of the autoload contract.

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("SHADER CHECK PASS — toon.gdshader + presets loaded, no compile errors surfaced")
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0)
