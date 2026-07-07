extends StaticBody3D
## Test stand-in for the player ship: absorbs hits, reports them.

signal was_hit(damage: float)


func take_hit(damage: float) -> void:
	was_hit.emit(damage)
