# Phase 2 Spec — Wave Spawner & Data-Driven Enemies

Architecture is decided (this doc + the schema files already in `framework/data/`).
The job is implementation. Don't redesign contracts; if one proves unworkable,
stop and flag it instead of inventing a side channel.

## Already done (do not recreate)

- Resource schema: `EnemyDefinition`, `SpawnEntry`, `WaveDefinition` (with
  `Completion` enum), `WaveSet` — all in `framework/data/`. Read them first;
  the doc comments are part of the contract.
- `MovementController` base (`framework/movement/movement_controller.gd`) now has
  `setup(actor, params)` / `_on_setup()` / `compute_velocity()` / `handle_action()`.

## To build

### 1. `framework/enemies/enemy_base.gd` — `class_name EnemyBase extends CharacterBody3D`

The shared enemy: health, swappable movement-pattern hook, shared hit/death
behavior. Game enemies extend the scene/visuals, not the logic.

```gdscript
var definition: EnemyDefinition
var health: float
var _pattern: MovementController

func setup(p_definition: EnemyDefinition) -> void
    # store definition, health = max_health,
    # instantiate definition.movement_pattern as a child node,
    # _pattern.setup(self, definition.movement_params)

func take_hit(damage: float) -> void
    # health -= damage
    # EventBus.enemy_hit.emit(self, damage, global_position)
    # EventBus.vfx_burst_requested.emit(definition.hit_flash, global_position)
    # if health <= 0.0: die()

func die() -> void
    # EventBus.enemy_died.emit(self, definition.points, global_position)
    # EventBus.vfx_burst_requested.emit(definition.death_burst, global_position)
    # queue_free()

func _physics_process(delta) -> void
    # velocity = _pattern.compute_velocity(velocity, delta); move_and_slide()
    # (guard: no pattern -> stay still, no crash)
```

Rules: EnemyBase never references any concrete game, never touches ScoreManager
directly (scoring flows from the `enemy_died` signal), and never decides wave
completion (that's the spawner's job).

### 2. `framework/movement/patterns/linear_pattern.gd` — `class_name LinearPattern extends MovementController`

The one framework-shipped test pattern: constant velocity
`params.get("direction", Vector3.LEFT).normalized() * params.get("speed", 5.0)`.
Exists so the framework is testable without any game code. Game-specific
patterns (thrust, flap, twin-stick, swoops) do NOT go in framework/.

### 3. Rewrite `framework/autoload/wave_spawner.gd` (public API mostly holds)

```gdscript
func load_waves(wave_set: WaveSet) -> void        # signature changes from Array
func start_waves() -> void
func stop_waves() -> void                          # cancel pending spawns/timers;
                                                   # live enemies are left alone (game decides cleanup)
func complete_current_wave() -> void               # now only valid for Completion.MANUAL
func set_enemy_container(node: Node) -> void       # spawned enemies get parented here;
                                                   # fallback: get_tree().current_scene
var live_enemy_count: int                          # read-only for HUD/debug
```

Behavior:

- **Spawn scheduling:** on `wave_started`, for each `SpawnEntry`, spawn number
  k (0-based, k < count) at `start_delay + k * interval` seconds. Use
  `get_tree().create_timer(...)` chains or an accumulator in `_process` — either
  is fine, but it must respect `get_tree().paused` (no OS-clock timers).
- **Spawning one enemy:** instantiate `entry.enemy.scene`; root must be
  EnemyBase (else `push_error`, skip entry — don't crash). Call `setup(entry.enemy)`,
  parent to container, position at a spawn marker, then
  `EventBus.enemy_spawned.emit(enemy)`.
- **Spawn markers:** pick randomly among `Node3D`s in group `"spawn_" + spawn_tag`,
  or group `"spawn_points"` when tag is empty. No markers found → `push_warning`
  once per wave, spawn at `Vector3.ZERO`. The spawner never knows level layout —
  markers are the entire contract with the game's world.
- **Liveness tracking:** count via `tree_exited` on each spawned enemy, NOT via
  `EventBus.enemy_died` — enemies can despawn without dying (off-screen cleanup)
  and completion must still fire.
- **Completion:** per `WaveDefinition.completion` — ALL_DEFEATED (all scheduled
  spawns done AND live count 0), TIMED (`duration` after wave start), MANUAL
  (`complete_current_wave()`). Then emit `wave_completed`, wait
  `time_between_waves`, next wave; after the last → `all_waves_completed`,
  `is_running = false`.
- Existing EventBus signals only. No new signals should be needed; if one seems
  needed, flag it rather than adding quietly.

### 4. Test assets (all under `tests/`, never `framework/`)

- `tests/placeholder_enemy.tscn` — EnemyBase root + CSG/primitive mesh +
  CollisionShape3D. Ugly is fine.
- `tests/data/test_enemy.tres` (EnemyDefinition: placeholder scene, 2 HP,
  100 pts, LinearPattern, `{"speed": 4.0, "direction": Vector3.LEFT}`),
  `tests/data/test_wave_set.tres` — 2 waves ALL_DEFEATED (wave 1: 2 enemies,
  wave 2: 3), short delays so headless runs fast.
- Extend `tests/boot_check.gd`: add spawn markers + container, load
  `test_wave_set.tres`, start waves, drive kills with `take_hit(2.0)` as
  enemies spawn, await `all_waves_completed`. Assert: 5 enemies spawned, score
  reflects 5 combo kills, spawner stopped. Keep every existing Phase 1 check
  passing. The check must finish (or fail loudly) within ~15s headless — no
  infinite awaits without a timeout guard.

## Edge cases that MUST be handled (cheap now, bugs later)

empty `waves` / empty `entries` (warn, complete immediately — don't hang);
null `enemy` or null `scene` on an entry (error, skip); scene root not
EnemyBase (error, skip); `movement_pattern` null or not a MovementController
subclass (enemy stands still, error logged, no crash); ALL_DEFEATED wave whose
entries all got skipped (complete once scheduling ends — zero-live guard);
`start_waves()` called while running (ignore + warn); `stop_waves()` mid-spawn
(pending timers cancelled, no ghost spawns after);
pause during spawn delays (timers freeze with the tree).

## Acceptance

1. `godot --headless --path . res://tests/boot_check.tscn` exits 0, prints PASS
   including the new wave assertions.
2. `framework/` still contains zero game-specific names/logic.
3. State the answer to the standard check: which edge cases are still
   unhandled, and does anything here stop the Joust-alike or Robotron-alike
   from reusing WaveSpawner/EnemyBase without modification? (Expected answer:
   no — they supply their own .tres files, enemy scenes, patterns, markers.)
