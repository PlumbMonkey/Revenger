# Revenger

A reimagined vertical-scroll rescue shooter, built on the **Shared Arcade Framework** —
a reusable Godot 4.7 core (wave spawning, pooled VFX, scoring/combo, HUD/radar,
pickup/rescue state machine, swappable movement controllers) that will also power a
Joust-style flap-combat game and a Robotron-style twin-stick maze shooter.

- Engine: Godot 4.7, GDScript, Forward Plus, Jolt physics
- `framework/` — game-agnostic core (six autoload singletons + EventBus architecture)
- `games/revenger/` — Revenger-specific scenes, scripts, and art
- `tests/boot_check.tscn` — current main scene; proves the framework shell boots

See `CLAUDE.md` for architecture rules and phase status.
