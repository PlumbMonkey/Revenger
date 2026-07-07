# Phase 5 Spec — Pickup / Rescue State Machine

Architecture is decided (this doc). Implement, don't redesign; if a contract
proves unworkable, stop and flag it. Build everything with **placeholder art**
(a capsule for the humanoid, an existing enemy ship for the captor, an existing
ship for the mutant) so Phase 5 is complete and testable now — the real VRoid
models swap in by changing a scene's mesh, no logic changes. The EventBus
rescue signals already exist from Phase 1 (`rescue_state_changed`,
`npc_rescued`, `npc_lost`) — use them; don't invent new ones.

## The mechanic (Defender-style rescue)

Humanoids stand on the ground. Captor enemies descend, grab one, and carry it
UP. Shoot the captor mid-carry and the humanoid falls — catch it (or let it land
from a low height) to save it; let it fall from too high and it smashes. If a
captor carries a humanoid all the way off the top, the humanoid is lost AND the
captor **mutates** into a fast, aggressive mutant that hunts the player.

Coordinate convention (matches the rest of the project): **Y is up**, gameplay
on the XZ plane. Captors lift along +Y; humanoids fall along −Y to `ground_y`.

## Decisions already made (do not revisit)

- The state machine is **framework-owned and game-agnostic** (PRD: "generic
  protectable-NPC ... generic enough to reuse or ignore elsewhere"). It knows
  states, transitions, fall rules, and signals — nothing about VRoid, captors,
  or mutants. All visuals/animation/AI are game-supplied.
- Humanoids are **level furniture**, not wave spawns: the game places them on
  the ground at level start. Each adds itself to the `radar_pickup` group in
  `_ready()` (the Phase 4 radar already draws those as green blips).
- Rescue scoring already flows: on rescue the object emits
  `EventBus.npc_rescued(self, points)`, which ScoreManager already handles.
- The captor is the **one enemy that needs a script** (special carry behaviour),
  so it extends `EnemyBase` — unlike the data-driven grunt/swarmer/gunner/heavy.
  It's still shootable and dies normally; it just does more.

## To build

### 1. `framework/rescue/rescue_object.gd` — `class_name RescueObject extends Node3D`

The state machine. Pure logic + signals; no art.

```gdscript
enum State { IDLE, THREATENED, CARRIED, FALLING, RESCUED, LOST }

@export var points: int = 250          # awarded on rescue
@export var ground_y: float = 0.0
@export var safe_fall_height: float = 6.0   # fall <= this survives; more smashes
@export var fall_speed: float = 12.0
@export var carry_follow_offset: Vector3 = Vector3(0, -1.5, 0)  # hangs below captor

var state: State = State.IDLE
var _captor: Node3D = null
var _fall_start_y: float = 0.0

# --- API (called by the game / captor) ---
func threaten(captor: Node3D) -> void      # IDLE -> THREATENED (captor latched, not yet lifting)
func carry(captor: Node3D) -> void          # THREATENED/IDLE -> CARRIED (store captor, follow it)
func release() -> void                      # CARRIED -> FALLING (record start height);
                                            #   THREATENED -> IDLE (freed before lift)
func catch() -> void                        # FALLING -> RESCUED (player caught mid-air)
func carried_off() -> void                  # CARRIED -> LOST (captor reached the top)

func _physics_process(delta):
    # CARRIED: if _captor invalid -> release(); else global_position = captor + carry_follow_offset
    # FALLING: descend by fall_speed*delta; on reaching ground_y, evaluate:
    #   fell = _fall_start_y - ground_y;  fell <= safe_fall_height -> _set_state(IDLE)
    #   else -> lose()   (smashed)

# --- internal ---
func _set_state(new_state):
    # guard no-op; store prev; assign; emit EventBus.rescue_state_changed(self, _name(prev), _name(new))
    # on RESCUED: EventBus.npc_rescued(self, points)
    # on LOST:    EventBus.npc_lost(self)
    # call _on_state_changed(prev, new)   # virtual hook for game visuals

## Virtual hook for game subclasses (animation/VFX). No-op here.
func _on_state_changed(_prev: State, _new: State) -> void: pass
```

Rules: `rescue()`/`lose()` are private helpers that route to RESCUED/LOST.
RESCUED and LOST are terminal — ignore further API calls once there. Emit state
names as StringName (e.g. `&"CARRIED"`) to match the EventBus signal signature.

### 2. `games/revenger/rescue/humanoid.gd` — `extends RescueObject`

Binds state → animation + VFX. Overrides `_on_state_changed`:

| State | AnimationPlayer clip | Extra |
|-------|----------------------|-------|
| IDLE | `"run"` (looping, "escaping") | |
| THREATENED | `"struggle"` | |
| CARRIED | `"struggle"` | |
| FALLING | `"fall"` | |
| RESCUED | `"wave"` | (then free after the clip, or return to IDLE) |
| LOST | `"smashed"` | `EventBus.vfx_burst_requested.emit(&"smash", global_position)`, free after |

Needs an `AnimationPlayer` node with clips named exactly as above — **that's the
contract for the VRoid animations** (author once on a shared VRM rig, plays on
all 4 characters). Guard missing clips (`has_animation`) so it works with the
placeholder before real anims exist.

### 3. `games/revenger/rescue/humanoid.tscn`

`RescueObject`(humanoid.gd) root + placeholder `MeshInstance3D` (CapsuleMesh) +
`AnimationPlayer` (empty is fine for now). Real VRoid model + clips swap in later.

### 4. `games/revenger/enemies/captor.gd` — `extends EnemyBase`

The Lander. On spawn, seek the nearest `IDLE` RescueObject (via the
`radar_pickup` group, `is_instance_valid` guarded). Behaviour:
- Descend toward the target; on reaching it, `target.carry(self)`.
- Then ascend (+Y). When `global_position.y >= carry_off_y`: `target.carried_off()`
  and **mutate** — spawn a mutant (instance a mutant scene / EnemyDefinition) at
  this position, then `queue_free()` self.
- Override `die()`: if carrying, `target.release()` first, then `super.die()`.
- No target found: fly the normal enemy pattern (harmless straggler).

Keep the framework untouched — all of this is game code. `carry_off_y` and the
mutant scene are exported so they're data, not magic numbers.

### 5. Mutant — `games/revenger/enemies/mutant.tres` (+ wrapper scene)

Just another `EnemyDefinition` (data): high speed, aggressive, points ~200,
pulse or a new pattern. Placeholder mesh = an existing enemy ship until the real
model is made. No new framework.

### 6. Level placement + demo

Add humanoid placement to a level/playtest: scatter ~5 humanoids on the ground
at `y=0`. `tests/rescue_playtest.tscn` = watch-it scene (a captor grabs one,
carries it, mutates at the top; another gets caught). Wire captors into a wave
so it's exercised.

### 7. `tests/rescue_check.tscn` + `.gd` (headless)

Assert the full contract:
- threaten→carry→release from HIGH → FALLING → lands → **LOST**, `npc_lost` fired.
- threaten→carry→release from HIGH → `catch()` → **RESCUED**, `npc_rescued` fired,
  ScoreManager score increased by `points`.
- carry→`carried_off()` → **LOST** + a mutant instance was spawned.
- release while THREATENED (before lift) → back to **IDLE**.
- every transition emits `rescue_state_changed` with correct prev/new names.
- Finish within the ~15s headless budget; scene timers run in real wall-clock.

## Edge cases that MUST be handled

captor destroyed mid-carry (auto-release via invalid `_captor` in `_physics_process`);
`catch()` called when not FALLING (ignore); API called on a terminal
(RESCUED/LOST) object (ignore); two captors targeting the same humanoid (first
`carry()` wins — reject `carry()` if not IDLE/THREATENED); humanoid freed while a
captor still references it (`is_instance_valid` guards on both sides); missing
AnimationPlayer clip (no crash); fall that lands exactly at `safe_fall_height`
(survives — boundary inclusive).

## Acceptance

1. `godot --headless --path . res://tests/rescue_check.tscn` exits 0 with the
   assertions above; boot_check + level_load_check still pass.
2. `framework/rescue/` contains zero game-specific names — the Joust/Robotron
   games could reuse RescueObject (or ignore it) with no edits; all Revenger
   specifics (VRoid, captor carry, mutant) live in `games/revenger/`.
3. State the standard check: which edge cases remain unhandled, and confirm the
   state machine stays decoupled enough to reuse without modification.

## Assets the owner is making (placeholders until then)

- 4 VRoid humanoids (2 male, female, child) on **one shared VRM rig** so the
  clips `run / struggle / fall / wave / smashed` author once and play on all.
- 1 mutant, modeled from a humanoid base (lore: the corrupted human).
- A captor/Lander — can reuse an existing enemy ship; needs no new rig.
