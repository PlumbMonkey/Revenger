class_name WaveSet
extends Resource
## An ordered run of waves — typically one level. The difficulty curve is
## the ordering and composition of these waves: pure data, no code.

@export var id: StringName

@export var waves: Array[WaveDefinition] = []

## Breather between one wave completing and the next starting.
@export var time_between_waves: float = 2.0
