class_name SpawnEntry
extends Resource
## One line item in a wave: which enemy, how many, and when.
## All entries in a wave schedule independently from wave start —
## entry k of `count` spawns at (start_delay + k * interval).

@export var enemy: EnemyDefinition

@export_range(1, 100) var count: int = 1

## Seconds after wave start before this entry's first spawn.
@export var start_delay: float = 0.0

## Seconds between consecutive spawns of this entry.
@export var interval: float = 0.5

## Selects spawn markers: nodes in group "spawn_<tag>". Empty means any
## marker in the generic "spawn_points" group. The spawner picks randomly
## among matching markers, so games control layout purely via markers.
@export var spawn_tag: StringName = &""
