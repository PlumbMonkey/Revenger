# Phase 4 Spec — Scoring Display, HUD/Radar, Pause & Settings Menus

Architecture is decided (this doc). The job is implementation. Don't redesign
contracts; if one proves unworkable, stop and flag it instead of inventing a
side channel. ScoreManager's logic is DONE (combo, multiplier, high-score
persistence) — Phase 4 is the visible layer on top of existing EventBus
signals. Read `framework/autoload/hud_manager.gd`, `event_bus.gd`, and
`settings_manager.gd` first; their doc comments are part of the contract.

## Decisions already made (do not revisit)

- HUD scenes are **framework-owned** (PRD: shared scoring/HUD/radar across all
  three games). Games get a complete default HUD for free; game-specific
  skinning comes later via `register_hud()` (keep that API, store the override,
  use it instead of the built-in when set).
- HUDManager creates its own `CanvasLayer` (layer 10) as a child of itself and
  instantiates the HUD scenes into it. Nothing is added to the game's scenes.
- Pause STATE stays in GameManager (`toggle_pause()` exists, `pause` input
  action already handled globally). The pause MENU is just a view reacting to
  `EventBus.game_paused` — it never owns pause logic.
- Gameplay plane mapping for the radar: world **X → radar x, world Z → radar y**
  (glTF import converts the Blender −Y forward convention to −Z forward in
  Godot; gameplay is on the XZ plane).
- Radar tracks entities via **scene groups**, not signals: `radar_player`,
  `radar_enemy`, `radar_pickup`. EnemyBase adds itself to `radar_enemy` in
  `_ready()` (that's a framework file — add it there). Games add their ship to
  `radar_player`. Phase 5 will use `radar_pickup`.

## To build

### 1. `framework/hud/game_hud.tscn` + `game_hud.gd` (Control, full rect)

Top-left: score + high score labels. Top-right: lives. Center-top: wave banner
(hidden by default). Bottom-left (or corner): combo label. Bottom-right: radar
panel. Plain default theme, monospace font preferred — styling is later work.

Behavior (all driven by EventBus, connected in `game_hud.gd`):
- `score_changed(score)` → score label
- `high_score_changed(hs)` → high score label
- `lives_changed(lives)` → lives label (clamp display at 0)
- `combo_changed(count, mult)` → show "x%.1f" only when mult > 1.0, hide otherwise
- `wave_started(i)` → banner "WAVE %d" visible ~2s then hide; use a scene-tree
  timer so pausing freezes it
- `game_over` → banner "GAME OVER", stays

### 2. `framework/hud/radar.gd` (Control, custom `_draw()`)

- `set_world_bounds(bounds: Rect2)` — world-XZ rect. No bounds set → one
  `push_warning`, draw only the frame.
- Each frame (`_process` → `queue_redraw()`): draw background + frame, then
  blips from the three groups: player (bright, slightly larger), enemies,
  pickups. Map world (x,z) → panel coords via the bounds rect; clamp
  out-of-bounds blips to the edge.
- Colors as exported `Color` properties with sane defaults (player white/cyan,
  enemy red/orange, pickup green) so games can tint without new code.
- Debug hook for headless testing: `get_blip_counts() -> Dictionary`
  (e.g. `{"player": 1, "enemy": 3, "pickup": 0}`) computed from the groups.

### 3. `framework/hud/pause_menu.tscn` + `pause_menu.gd`

- Full-screen dim (ColorRect, ~55% black) + centered VBox: "PAUSED" label,
  Resume button, Settings button, and a settings panel (hidden until Settings
  pressed) containing a `control_scheme` OptionButton (KEYBOARD_MOUSE /
  KEYBOARD / GAMEPAD) reading/writing `SettingsManager.control_scheme`.
- `process_mode = PROCESS_MODE_ALWAYS` on this scene root (it must work while
  the tree is paused). The gameplay HUD stays PAUSABLE.
- Hidden by default; HUDManager shows/hides it on `EventBus.game_paused`.
- Resume calls `GameManager.toggle_pause()`. On show, `grab_focus()` the Resume
  button so an Xbox controller can navigate immediately (this is the
  mid-game device-switch promise — verify D-pad navigation order works).
- No Quit button yet — menu-flow states don't exist until Phase 6.

### 4. Rewrite `framework/autoload/hud_manager.gd`

```gdscript
func show_hud() -> void      # lazy-instantiate CanvasLayer + game_hud + pause_menu
func hide_hud() -> void
func set_radar_bounds(bounds: Rect2) -> void   # forwards to radar (store if HUD not up yet)
func register_hud(root: Control) -> void        # game override, replaces built-in game_hud
```
- Connect `EventBus.game_started` → `show_hud()`; `game_paused` → pause menu
  visibility. Keep the autoload a plain Node; the CanvasLayer is its child.
- All existing `_on_*` stubs get real bodies or are replaced by game_hud.gd
  connections — either way HUDManager stays thin: visibility + wiring only,
  no rendering logic in the autoload.

### 5. Extend `tests/boot_check.gd` (keep every existing check passing)

After the Phase 2 wave block: `HUDManager.show_hud()`, then
- emit score/lives/combo events → assert the label texts changed accordingly
  (find labels via `get_node` on the instantiated HUD — expose clean unique
  names with `%` scene-unique nodes)
- `GameManager.toggle_pause()` → assert pause menu visible AND
  `get_tree().paused` true; toggle back → hidden, unpaused
- settings: set the OptionButton selection programmatically → assert
  `SettingsManager.control_scheme` changed and `settings.cfg` was written;
  restore original value after
- radar: `set_radar_bounds(Rect2(-50, -50, 100, 100))`, add a dummy Node3D to
  `radar_enemy` group → assert `get_blip_counts()["enemy"] == 1`
- Must stay within the existing ~15s headless budget.

## Edge cases that MUST be handled

pause toggled before HUD ever shown (menu must still appear — lazy init);
game_over while paused (unpause, show banner); combo label at exactly 1.0x
(hidden); two wave banners overlapping (second restarts the timer); radar
group nodes freed mid-frame (`is_instance_valid` before reading positions);
settings OptionButton set to its current value (no redundant save/signal —
SettingsManager already guards this, don't duplicate the guard in UI);
`show_hud()` called twice (idempotent).

## Acceptance

1. `godot --headless --path . res://tests/boot_check.tscn` exits 0 with the
   new HUD assertions printed in the PASS line.
2. `framework/` contains zero game-specific names/logic — the Joust-alike and
   Robotron-alike must be able to use this HUD by only setting radar bounds,
   adding their player to `radar_player`, and (optionally) registering a
   skinned HUD.
3. State the standard check: which edge cases remain unhandled, and does
   anything here stop the other two games from reusing HUD/radar/pause
   without modification?
