extends Node
## HUD lifecycle and wiring: creates a CanvasLayer (layer 10), lazily
## instantiates game_hud.tscn + pause_menu.tscn, forwards radar bounds.
## Rendering logic lives in those scenes, not here.
## Games may supply a replacement HUD via register_hud() before show_hud().

const _GAME_HUD_SCENE := preload("res://framework/hud/game_hud.tscn")
const _PAUSE_MENU_SCENE := preload("res://framework/hud/pause_menu.tscn")

## Exposed for testing and game-code inspection (read-only by convention).
var game_hud: Control = null
var pause_menu: Control = null

var _canvas: CanvasLayer = null
var _custom_hud: Control = null
var _pending_bounds: Rect2 = Rect2()
var _has_pending_bounds: bool = false
var _pending_plane: String = "XZ"


func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_over.connect(_on_game_over)


## Lazy-instantiates the CanvasLayer + game_hud + pause_menu.
## Idempotent: second call just un-hides the layer.
func show_hud() -> void:
	if _canvas != null:
		_canvas.visible = true
		return
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	add_child(_canvas)

	game_hud = _GAME_HUD_SCENE.instantiate() if _custom_hud == null else _custom_hud
	_canvas.add_child(game_hud)

	pause_menu = _PAUSE_MENU_SCENE.instantiate()
	_canvas.add_child(pause_menu)

	if _has_pending_bounds:
		_apply_radar_bounds(_pending_bounds)
		_has_pending_bounds = false


func hide_hud() -> void:
	if _canvas != null:
		_canvas.visible = false


## Passes the world bounding rect to the radar (plane decides which axes:
## "XZ" for top-down games, "XY" for side-scrollers). Stored if HUD not up yet.
func set_radar_bounds(bounds: Rect2, plane: String = "XZ") -> void:
	_pending_plane = plane
	if _canvas != null:
		_apply_radar_bounds(bounds)
	else:
		_pending_bounds = bounds
		_has_pending_bounds = true


## Supply a game-skinned Control to replace the built-in game_hud.
## Must be called before show_hud() to take effect.
func register_hud(root: Control) -> void:
	_custom_hud = root


# ---------------------------------------------------------------------------

func _apply_radar_bounds(bounds: Rect2) -> void:
	if game_hud == null:
		return
	var radar := game_hud.get_node_or_null("%Radar")
	if radar != null and radar.has_method("set_world_bounds"):
		radar.set("plane", _pending_plane)
		radar.call("set_world_bounds", bounds)


func _on_game_started() -> void:
	show_hud()


func _on_game_paused(is_paused: bool) -> void:
	if _canvas == null:
		show_hud()  # lazy init when pause is toggled before the HUD was shown
	if is_paused:
		pause_menu.call("show_menu")
	else:
		pause_menu.call("hide_menu")


func _on_game_over() -> void:
	## If the game ends while paused: hide the pause menu and unpause the tree.
	if get_tree().paused:
		get_tree().paused = false
		if pause_menu != null:
			pause_menu.call("hide_menu")
