# Revenger / Shared Arcade Framework

Godot 4.7 (GDScript) project containing the **Shared Arcade Framework** — a reusable
core that will power three games: **Revenger** (vertical-scroll rescue shooter, built
here first), a Joust-style flap-combat game, and a Robotron-style twin-stick maze
shooter. PRD: `Shared_Arcade_Framework_PRD.pdf` on the owner's Desktop.

## Hard rules

- **Godot 4 syntax only** — no `yield`, no old-style 4-argument `connect()`. Use
  typed GDScript, `signal.connect(callable)`, `signal.emit(...)`, `:=` where inferable.
- **`framework/` must stay game-agnostic.** No Revenger-specific logic, names, or
  assets in `framework/`. Game-specific code lives in `games/revenger/`. Every
  framework change must still make sense for the Joust-alike and Robotron-alike.
- **All cross-system communication goes through the `EventBus` autoload.** Systems
  never call each other directly (calling into an autoload's public API from game
  code is fine; autoload-to-autoload coupling is not — they listen to the bus).
- Movement is behind the `MovementController` contract
  (`framework/movement/movement_controller.gd`): controllers compute velocity,
  actors apply it. Never branch on "which game is this".
- 3D rendering (Blender asset pipeline), gameplay locked to a plane. Positions in
  signals/APIs are `Vector3`.

## Architecture

Seven autoloads, registered in this order (EventBus first — everything depends on it):
`EventBus`, `SettingsManager`, `GameManager`, `ScoreManager`, `WaveSpawner`,
`VFXManager`, `HUDManager` — all in `framework/autoload/`. The EventBus signal
catalog in `event_bus.gd` is the system contract; extend it there, don't invent
side channels.

## Input

- Gameplay code reads **InputMap actions only** (`move_*`, `fire`,
  `action_secondary`, `aim_*`, `pause` — defined in project.godot), never raw
  device events. Keyboard, mouse, and Xbox gamepad are all bound to every action
  and stay live at all times.
- `SettingsManager.control_scheme` (KEYBOARD_MOUSE / KEYBOARD / GAMEPAD, persisted)
  never disables bindings — it only drives what must be single-device: aim source
  (mouse position vs `aim_*` right stick vs movement direction) and HUD button
  prompts. This is why switching scheme mid-game is always safe.
- `pause` (Esc / Start) is handled globally by GameManager. The pause menu with
  Resume / Settings buttons and the settings screen (scheme selector) are Phase 4
  HUD deliverables; scheme changes arrive via `EventBus.control_scheme_changed`.

Wave/enemy definitions will be Godot Resources (`.tres`) in `framework/data/` —
authored data, not code (Phase 2).

## Layout

```
framework/    reusable core (autoloads, movement, enemies, pickups, vfx, hud, data)
games/        game-specific scenes/scripts/assets (games/revenger/ first)
tests/        boot_check.tscn is the current main scene / integration proof
```

## Verify

Headless boot check (exit code 0 = pass):

```
godot --headless --path . res://tests/boot_check.tscn
```

Prints `BOOT CHECK PASS` when all autoloads are registered and EventBus traffic
flows. Keep this scene passing; extend it as phases land.

## Phase status (PRD: 6 phases, ~15 sprints)

1. Scaffolding & autoloads — **DONE** (shell + boot check)
2. Wave spawner & data-driven enemies — **SPEC READY: build from `docs/PHASE2_SPEC.md`**
   (Resource schema already in `framework/data/`; spec is the contract — implement, don't redesign)
3. VFX & particle pooling (`VFXManager.burst()` API is final, body is a stub)
4. Scoring & HUD (`ScoreManager` logic works; HUD scenes are stubs) — also owns
   the pause menu + settings screen with control-scheme selector (see Input above)
5. Pickup/rescue state machine (idle → threatened → carried → rescued)
6. Movement interface impls + integration test + architecture review
   (`MovementController` base was stubbed early, in Phase 1, by design)

## Process

- Repo: https://github.com/PlumbMonkey/Revenger
- After building any system, state which edge cases it doesn't handle yet and
  confirm it stays decoupled enough for the Joust-alike/Robotron-alike to reuse
  without modification.
