# Phase 6 Architecture Review — the "build once, reuse three times" gate

Conducted at framework completion (all 6 phases done), before Revenger-specific
polish begins. Question under review: can the Joust-alike and Robotron-alike be
built as new `games/<name>/` folders **without editing `framework/`**?

## 1. Leak scan

`grep -ri "revenger|crackle|swarmer|captor|mutant|humanoid|thrust|laser|pulse|grunt|gunner"`
over `framework/`:

- **Zero code couplings.** No framework file loads, preloads, types against, or
  names any game class, scene, or resource.
- Doc-comment mentions only: `movement_controller.gd` / `linear_pattern.gd` name
  "thrust-flight (Revenger) / flap-physics / twin-stick" as *examples* of
  implementations; `enemy_definition.gd` uses `&"grunt"` in an id example.
  Informative, not coupling. Kept deliberately.
- `rescue_object.gd` uses the word "captor" for its `Node3D` parameters — this
  is the rescue mechanic's own domain vocabulary (the thing carrying the NPC),
  typed `Node3D`, no knowledge of the Revenger `Captor` class. Not a leak.

## 2. Per-system reuse assessment

| System | Reuse path for Joust-alike / Robotron-alike | Framework edit needed? |
|---|---|---|
| EventBus | Same signal catalog; both games' mechanics map onto it (kills, score, waves, pickups optional) | No |
| SettingsManager / input | Same InputMap actions; flap = `action_secondary`, twin-stick aim = `aim_*` (bindings already exist) | No |
| GameManager | Same state machine, lives, pause | No |
| ScoreManager | Same combo/high-score logic; per-game save separation is a nice-to-have (see debts) | No |
| WaveSpawner | Author new `.tres` WaveSets + enemy defs; place spawn markers in level scenes | No |
| EnemyBase + EnemyDefinition | New glbs + defs; weapons/materials/damage-reactions all data; special enemies extend it (Captor precedent) | No |
| MovementController | **Proven both ways in Phase 6**: same contract drives AI patterns (Linear, Swarm) and a human-input ship (ThrustFlight). Flap-physics and twin-stick are new `games/<name>/movement/` scripts | No |
| VFXManager | Register game-art bursts; `register_camera()` + shake are generic | No |
| HUDManager/radar/pause | Add player to `radar_player`, set bounds, optionally `register_hud()` skin | No |
| RescueObject | Joust-alike could reuse for egg-collection-style pickups, or ignore entirely; Robotron-alike: human rescue is literally the Robotron mechanic — direct reuse | No |
| Toon shader | Shared look; per-game material presets | No |

**Verdict: HOLDS.** Both future games are `games/<name>/` content + a few
game-specific scripts against existing contracts. No framework edits foreseen.

## 3. Known debts (deliberate, documented, none blocking)

- Captor-spawned mutants bypass WaveSpawner counting (mutants roam free of wave
  pacing — Defender-authentic; revisit only if a wave should wait on them).
- High-score file is global (`user://high_scores.cfg`), not per-game — worth a
  `game_id` key when game #2 starts.
- Player ship ignores enemy *bodies* (mask = world + enemy_shots only): ramming
  an enemy is currently harmless. Add `enemies` to the ship mask + collision
  damage when wanted — data change plus a few lines in the ship.
- Shake treats the registered camera as static; a scrolling camera rig should
  register a child camera (documented in VFXManager).
- Radar draws every frame regardless of change; fine at this scale.
- `Revenger. enemy 1.glb` + ~18 VRoid PNGs = ~12MB dead repo weight (mis-export,
  superseded) — delete anytime.

## 4. What "done" means from here

The framework is complete. Remaining work is **game content**: real hero ship
swap-in (muzzle empties ready), humanoid animation clips (`run/struggle/fall/
wave/smashed` auto-bind), sound (hook EventBus signals), mutant model export,
menus/level flow, tuning — then game #2 as a fresh `games/` folder, which will
be the true reuse test.
