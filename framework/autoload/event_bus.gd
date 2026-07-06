extends Node
## Central signal router for the Shared Arcade Framework.
##
## Every cross-system message goes through here. Systems never call each other
## directly — they emit or connect to EventBus signals, so no game-specific
## logic leaks into the framework core.
##
## Positions are Vector3: games render in 3D (Blender asset pipeline) even when
## gameplay is locked to a plane. 2D-plane games just leave one axis at 0.

@warning_ignore_start("unused_signal")

# -- Game state --
signal game_started
signal game_paused(is_paused: bool)
signal game_over
signal level_started(level_index: int)

# -- Waves & enemies --
signal wave_started(wave_index: int)
signal wave_completed(wave_index: int)
signal all_waves_completed
signal enemy_spawned(enemy: Node)
signal enemy_hit(enemy: Node, damage: float, position: Vector3)
signal enemy_died(enemy: Node, points: int, position: Vector3)

# -- Player --
signal player_spawned(player: Node)
signal player_hit(remaining_health: float)
signal player_died
signal lives_changed(lives: int)

# -- Score --
signal score_changed(score: int)
signal combo_changed(combo_count: int, multiplier: float)
signal high_score_changed(high_score: int)

# -- Pickup / rescue state machine --
signal rescue_state_changed(npc: Node, previous_state: StringName, new_state: StringName)
signal npc_rescued(npc: Node, points: int)
signal npc_lost(npc: Node)

# -- VFX --
signal vfx_burst_requested(burst_type: StringName, position: Vector3)
signal screen_shake_requested(intensity: float, duration: float)

# -- Settings & input --
signal control_scheme_changed(scheme: int)  # SettingsManager.ControlScheme value
signal settings_changed(section: StringName, key: StringName, value: Variant)

@warning_ignore_restore("unused_signal")
