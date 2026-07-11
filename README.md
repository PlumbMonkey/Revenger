[Revenger-README.md](https://github.com/user-attachments/files/29931885/Revenger-README.md)
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
# Revenger

**A reimagined vertical-scroll rescue shooter** built on the **Shared Arcade Framework**.

![Godot 4.7](https://img.shields.io/badge/Godot-4.7-blue?logo=godot-engine)
![GDScript](https://img.shields.io/badge/Language-GDScript-green)
![Status](https://img.shields.io/badge/Status-Active%20Development-orange)

---

## 🎮 About

Revenger is a fast-paced vertical-scrolling rescue shooter. You pilot a craft through hostile alien waves, rescue survivors, build combos, and survive escalating threats.

It is the first game powered by the **Shared Arcade Framework** — a clean, reusable Godot 4.7 core designed to power multiple arcade-style games:

- Revenger (vertical scroll rescue shooter) ← *this project*
- Upcoming: Joust-style flap combat
- Upcoming: Robotron-style twin-stick maze shooter

---

## 🏗️ Shared Arcade Framework Features

The framework lives in `framework/` and is designed to be game-agnostic:

- **EventBus architecture** for clean decoupled communication
- Six autoload singletons for core systems
- Wave spawning system
- Object pooling for VFX and projectiles
- Scoring + combo system
- HUD / radar
- Pickup & rescue state machine
- Swappable movement controllers
- Forward Plus rendering + Jolt physics

This framework is intentionally built to be extracted and sold / open-sourced later as a professional Godot template.

---

## 📂 Project Structure

```
Revenger/
├── framework/              # Reusable core (the real product)
│   ├── autoloads/
│   ├── systems/
│   └── ...
├── games/
│   └── revenger/           # This game's scenes, scripts, art
├── tests/
│   └── boot_check.tscn     # Current main scene (framework boot test)
├── docs/
├── CLAUDE.md               # Architecture rules & phase status
├── project.godot
└── README.md
```

---

## 🚀 Getting Started

### Requirements
- Godot 4.7 or newer
- Git

### Run the project
1. Clone the repository:
   ```bash
   git clone https://github.com/PlumbMonkey/Revenger.git
   cd Revenger
   ```
2. Open the project in Godot 4.7+
3. Set `tests/boot_check.tscn` as the main scene (or open it and press F5)
4. The framework should boot cleanly and display the test HUD

---

## 🛠️ Development Status

- [x] Core framework architecture
- [x] EventBus + autoloads
- [x] Basic wave spawning & pooling
- [x] Boot verification scene
- [ ] Full player controller + weapons
- [ ] Complete rescue / pickup loop
- [ ] Enemy variety & boss
- [ ] Juice, juice, juice (screen shake, particles, juice)
- [ ] Sound & dynamic music hooks
- [ ] Steam / export-ready build
- [ ] Framework extraction into standalone product

See `CLAUDE.md` for detailed architecture rules and current phase.

---

## 🎯 Goals

1. Ship a polished vertical-slice of Revenger
2. Extract and productize the Shared Arcade Framework (Gumroad / Itch / Godot Asset Library)
3. Use the framework to rapidly prototype more arcade games
4. Integrate music / SFX systems that can also serve Ghost Circuit and client scoring work

---

## 🤝 Collaboration

This project (and especially the Shared Arcade Framework) is open to limited collaborations and potential team members who want to build high-quality arcade games and sellable tools.

Interested? Reach out via [plumbmonkey.online](https://plumbmonkey.online) or open an issue.

---

## 📄 License

TBD (currently private development). Will be clarified before public release of the framework.

---

**Created by William "Plumbmonkey" Henwood**  
Alberta, Canada  
[YouTube – In Session](https://www.youtube.com/@PlumbmonkeyMedia) · [Studio](https://plumbmonkey.online)
