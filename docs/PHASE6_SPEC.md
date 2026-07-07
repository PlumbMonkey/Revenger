# Phase 6 Spec — Movement Interface, Player Ship & Integration (final phase)

Architecture is decided (this doc). Implement, don't redesign; if a contract
proves unworkable, stop and flag it. This is the **last framework phase** — it
delivers the player and proves everything built in Phases 1–5 works together.
Build with **placeholder art** (a box/capsule ship) so it's complete and
testable now; the real hero ship (already modelled in Blender, with `_Muzzle`
empties positioned for exactly this) swaps in later as a mesh change.

Everything the player needs already exists and is waiting:
- InputMap actions (`move_*`, `fire`, `action_secondary`, `aim_*`) — Phase 1.
- `laser_bolt.tscn` player shot (layer `player_shots`, masks world+enemies) — Phase 3.
- `EventBus.player_spawned / player_hit / player_died / lives_changed` — Phase 1.
- `GameManager` already turns `player_died` into a life loss + `game_over` — Phase 1.
- `RescueObject.catch()` waiting for a trigger — Phase 5.
- `VFXManager.shake()` + `screen_shake_requested` stub waiting for a camera — Phase 3.

## Decisions already made (do not revisit)

- **The player is game-specific** (`games/revenger/player/`), not a framework
  base class. The three games' players differ too much (thrust-flight ship vs
  flapping mount vs twin-stick runner) to share a base — "the framework provides
  underlying systems, not any specific IP" (PRD). The player REUSES framework
  contracts (MovementController, EventBus, collision layers), it isn't one.
- **Movement goes through the existing `MovementController` contract.** The
  player's `ThrustFlightController` (game code) reads InputMap actions in
  `compute_velocity()` — exactly the same interface enemies use with
  LinearPattern/SwarmPattern. This IS the "swappable movement interface" the
  phase is named for; proving one contract serves both AI movers and a
  human-driven ship is the whole point.
- **Camera shake completes Phase 3 in the framework** (it's generic/reusable):
  `VFXManager` gains `register_camera(cam)` and a real `shake()` — no game code.
- Gameplay plane is **XZ, Y up** (consistent with all prior phases). Thrust is
  on XZ; the ship yaws to face its heading and fires forward along it.
- Firing is **forward** (ship heading) for Revenger's thrust-flight. Aim-source-
  per-control-scheme (mouse/right-stick aim) is noted polish, NOT required here.

## To build

### 1. `games/revenger/movement/thrust_flight.gd` — `extends MovementController`

Reads input, produces momentum-based flight. `compute_velocity(current, delta)`:
- Read a 2D thrust vector from `Input.get_vector("move_left","move_right","move_up","move_down")`
  → map to the XZ plane (x→X, y→Z).
- `current += thrust * accel * delta`; apply damping toward zero when no input;
  clamp horizontal speed to `max_speed` (read from `params`, sane default).
- Leave Y untouched (0) — thrust-flight stays on the plane.
- `params`: `accel`, `max_speed`, `damping`. Honor `speed_scale` like the other
  patterns (free — it's on the base).

The ship (actor), not the controller, handles yaw-to-heading and firing.

### 2. `games/revenger/player/player_ship.gd` + `.tscn`

`CharacterBody3D`, collision_layer `player`(2), collision_mask `world`(1) +
`enemy_shots`(16) = 17. Placeholder mesh + collision shape. Structure:
- Adds a `ThrustFlightController` child in `_ready()` (or instances it like
  EnemyBase does), `setup(self, params)`.
- `_ready()`: `add_to_group("radar_player")`, `EventBus.player_spawned.emit(self)`.
- `_physics_process`: `velocity = _controller.compute_velocity(velocity, delta)`;
  `move_and_slide()`; yaw the ship to face horizontal `velocity` (keep last
  heading when near-still); fire if `Input.is_action_pressed("fire")` and the
  cooldown elapsed.
- Fire: instance `laser_bolt.tscn`, parent to the current scene, place at a
  `muzzle_offset` along heading, orient down the ship's forward. Rate-limited by
  `fire_cooldown`.
- `take_hit(damage)`: the projectile contract (`projectile.gd` calls
  `take_hit` on what it hits). Reduce `health`; `EventBus.player_hit.emit(health)`;
  request a small `screen_shake` + a hit burst; at `health <= 0` →
  `EventBus.player_died.emit()` and respawn or hide (GameManager handles the
  life count + game_over; the ship should reset health + brief invulnerability
  on respawn while lives remain).
- **Catch zone**: a child `Area3D` (layer 0, mask `radar_pickup`? — pickups have
  no collision layer, so instead) monitors bodies/areas OR simply, on
  `_physics_process`, scans the `radar_pickup` group for any `RescueObject` in
  `FALLING` state within `catch_radius` and calls `catch()` on it. Group-scan is
  simplest and matches how the captor finds targets — do that, `is_instance_valid`
  guarded.

### 3. Framework: `VFXManager` camera shake (finishes Phase 3)

```gdscript
func register_camera(cam: Camera3D) -> void      # game supplies its camera
func shake(intensity: float, duration: float)    # replace the stub
```
Keep a rest transform for the registered camera; on `shake`, drive a decaying
per-frame positional offset (noise or random) for `duration`, scaled by
`intensity`, then restore. Multiple overlapping requests take the max remaining.
No-op safely if no camera registered. Stays generic — zero game specifics.

### 4. Integration scene — `tests/integration.tscn` (the PRD deliverable)

"A working test scene with a placeholder ship, one enemy type, one rescue
object, full HUD, and VFX firing correctly." Assemble the whole game loop:
player ship + a real level via WaveSpawner + humanoids + captors + the Phase 4
HUD + a camera registered for shake + all bursts registered. **Playable (F6):**
fly with WASD/stick, fire with Space/trigger, shoot enemies, catch falling
humanoids, take hits, feel shake. Headless: auto-quit smoke after a few seconds.

### 5. `tests/integration_check.tscn` + `.gd` (headless acceptance)

Drive it programmatically (simulate input with `Input.action_press/release`):
- player spawns, emits `player_spawned`, is in `radar_player`.
- press `move_*` → ship position changes (movement contract works via input).
- press `fire` → a `laser_bolt` instance exists; aim it at an enemy → enemy dies,
  score rises (validates the whole shot→hit→score chain end to end).
- an `enemy_pulse_shot`/`enemy_laser_bolt` hitting the ship → `take_hit` →
  `player_hit` fires, health drops; draining health → `player_died` →
  `GameManager.lives` decrements.
- a `FALLING` humanoid inside `catch_radius` → `catch()` → `RESCUED`, score rises.
- `EventBus.screen_shake_requested.emit(...)` with a registered camera → no error,
  camera returns to rest after the duration.
- Stay within the ~15s budget; scene timers run in real wall-clock.

### 6. Architecture review — `docs/PHASE6_REVIEW.md`

The final "did build-once-reuse-thrice hold?" gate before Revenger polish:
- `grep -ri` over `framework/` for game-specific names (`revenger`, `crackle`,
  `swarmer`, `captor`, `mutant`, `humanoid`, `thrust`, `laser`, `pulse`) — expect
  ZERO. List any hit as a leak to fix.
- Confirm each framework system is driven only by data/signals/contracts, and
  write, per system, one sentence on how the Joust-alike and Robotron-alike would
  reuse it. Flag anything that would force a framework edit.
- This is the checkpoint worth a **Fable 5** pass per the PRD model table.

## Edge cases that MUST be handled

fire held down (cooldown-limited, not one-per-frame); movement with zero input
(damps to rest, keeps last heading for firing); `take_hit` while already at 0 /
respawning (ignore during invuln); player death with lives remaining (respawn)
vs zero lives (GameManager → game_over, ship stays dead); catch zone overlapping
two falling humanoids (catch the nearest, or all — pick one and state it); shake
with no camera registered (no-op); shake requested while a shake is active
(don't stack into nausea — max remaining, single offset); pause mid-flight
(ship + shake freeze with the tree — use pausable processing).

## Acceptance

1. `godot --headless --path . res://tests/integration_check.tscn` exits 0 with
   the assertions above; boot_check, level_load_check, rescue_check all still pass.
2. `framework/` contains zero game-specific names (the review, item 6).
3. F6 on `tests/integration.tscn` gives a controllable ship that flies, shoots
   enemies, catches humanoids, takes damage, and shakes the camera — the whole
   game loop in one scene.
4. State the standard check: which edge cases remain unhandled, and — this being
   the final phase — the overall verdict on framework reusability for the other
   two games.

## After Phase 6 (not part of it)

The framework is then complete. Remaining Revenger work is game-building, not
framework: swap the real hero ship in (it has `_Muzzle` empties ready), author
the humanoid animation clips + sound effects (hooks already broadcast), export
the mutant ship, build menus/level flow, tune difficulty. The Joust-alike and
Robotron-alike become new `games/<name>/` folders reusing `framework/` unchanged.
