class_name EnemyDefinition
extends Resource
## Data-only description of one enemy type. Authored as .tres files —
## reskinning for the Joust-alike / Robotron-alike means new .tres + new
## scenes, never new spawner code.

## Stable identifier for lookups/debugging (e.g. &"grunt", &"buzzard").
@export var id: StringName

@export var display_name: String

## The game's visual/collision scene. Root node MUST extend EnemyBase.
@export var scene: PackedScene

@export var max_health: float = 1.0

## Base score awarded on kill (ScoreManager applies the combo multiplier).
@export var points: int = 100

## Movement pattern script — MUST extend MovementController. EnemyBase
## instantiates it as a child node at spawn and calls compute_velocity()
## each physics frame. Swapping this file is how the three games differ.
@export var movement_pattern: Script

## Pattern-specific tuning read by the movement pattern via setup()
## (e.g. {"speed": 6.0, "direction": Vector3.LEFT, "amplitude": 2.0}).
## Single source of truth for movement numbers — no speed field elsewhere.
@export var movement_params: Dictionary = {}

## VFX burst type names passed to VFXManager (Phase 3 maps them to pools).
@export var death_burst: StringName = &"explosion_small"
@export var hit_flash: StringName = &"hit_flash"
