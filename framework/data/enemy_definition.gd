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

## Optional weapon: a projectile scene fired straight ahead (local -Z) every
## fire_interval seconds. 0 interval or null scene = this enemy doesn't shoot.
## Which enemy fires what is authored here in data — never coded.
@export var weapon_scene: PackedScene
@export var fire_interval: float = 0.0
@export var muzzle_offset: Vector3 = Vector3(0, 0, -2)

## Optional look override applied to every MeshInstance3D in the spawned enemy.
## Lets imported glTF ships (flat/untextured from Blender) get the shared toon
## material at spawn — art stays flat in Blender, styled here per the pipeline.
@export var material_override: Material
