extends Control
## Minimap radar — draws world-XZ entity positions as coloured blips.
##
## World X → radar x, World Z → radar y (XZ gameplay plane; glTF −Z forward
## convention means gameplay on XZ). Call set_world_bounds() at game boot.
## Tracks entities via scene groups: radar_player, radar_enemy, radar_pickup.
## EnemyBase adds itself to radar_enemy in _ready(). Games add their player
## to radar_player; Phase 5 pickups use radar_pickup.
## get_blip_counts() is usable headless (reads groups, no rendering needed).

@export var player_color: Color = Color.CYAN
@export var enemy_color: Color = Color(1.0, 0.2, 0.2)
@export var pickup_color: Color = Color.GREEN
@export var background_color: Color = Color(0.0, 0.0, 0.0, 0.5)
@export var player_blip_size: float = 5.0
@export var enemy_blip_size: float = 4.0
@export var pickup_blip_size: float = 3.0

var _world_bounds: Rect2 = Rect2()
var _bounds_set: bool = false
var _warned_no_bounds: bool = false


func set_world_bounds(bounds: Rect2) -> void:
	_world_bounds = bounds
	_bounds_set = true


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, background_color)
	draw_rect(r, Color.WHITE, false)
	if not _bounds_set:
		if not _warned_no_bounds:
			push_warning("Radar: set_world_bounds() not called — blips will not be drawn")
			_warned_no_bounds = true
		return
	_draw_group(&"radar_player", player_color, player_blip_size)
	_draw_group(&"radar_enemy", enemy_color, enemy_blip_size)
	_draw_group(&"radar_pickup", pickup_color, pickup_blip_size)


func _draw_group(group: StringName, color: Color, blip_size: float) -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(node) or not node is Node3D:
			continue
		var wp: Vector3 = (node as Node3D).global_position
		var rp: Vector2 = _world_to_radar(wp)
		var half: float = blip_size * 0.5
		rp = rp.clamp(Vector2(half, half), size - Vector2(half, half))
		draw_circle(rp, half, color)


func _world_to_radar(world_pos: Vector3) -> Vector2:
	## X → radar x, Z → radar y.
	var nx: float = (world_pos.x - _world_bounds.position.x) / _world_bounds.size.x
	var ny: float = (world_pos.z - _world_bounds.position.y) / _world_bounds.size.y
	return Vector2(nx * size.x, ny * size.y)


## Returns blip counts per group — usable headless without rendering.
func get_blip_counts() -> Dictionary:
	return {
		"player": _count_valid_group(&"radar_player"),
		"enemy": _count_valid_group(&"radar_enemy"),
		"pickup": _count_valid_group(&"radar_pickup"),
	}


func _count_valid_group(group: StringName) -> int:
	if not is_inside_tree():
		return 0
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(group):
		if is_instance_valid(node):
			count += 1
	return count
