extends SceneTree
## One-shot content builder: toon materials, EnemyDefinitions, and level
## WaveSets. Run headless; writes .tres into games/revenger/. Re-runnable.
## Kept in tests/ (dev tooling, not shipped game code).

const TOON := "res://framework/shaders/toon.gdshader"
const LINEAR := "res://framework/movement/patterns/linear_pattern.gd"
const SWARM := "res://games/revenger/movement/swarm_pattern.gd"
const PULSE := "res://games/revenger/weapons/enemy_pulse_shot.tscn"
const LASER := "res://games/revenger/weapons/enemy_laser_bolt.tscn"

const MAT_DIR := "res://games/revenger/enemies/materials/"
const ENEMY_DIR := "res://games/revenger/enemies/"
const LEVEL_DIR := "res://games/revenger/levels/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LEVEL_DIR))

	# --- materials: distinct neon toon tints per enemy role ---
	_make_material("toon_enemy_heavy", Color(0.72, 0.09, 0.13), 3)
	_make_material("toon_enemy_grunt", Color(0.52, 0.20, 0.78), 3)
	_make_material("toon_enemy_swarmer", Color(0.97, 0.52, 0.10), 2)
	_make_material("toon_enemy_gunner", Color(0.13, 0.72, 0.52), 3)
	_make_material("toon_enemy_captor", Color(0.75, 0.85, 0.20), 3)
	_make_material("toon_enemy_mutant", Color(0.85, 0.05, 0.55), 2)

	# --- enemy definitions ---
	# id, scene, hp, pts, speed, weapon, interval, muzzle_z, death_burst, material
	_make_def("grunt", "enemy_grunt", 2.0, 100, 6.0, PULSE, 2.2, -2.0, &"pulse_impact", "toon_enemy_grunt")
	# swarmer: 2 HP, flies as a tight cluster. First hit anywhere breaks the
	# whole formation (SwarmPattern) — ships separate and speed up; a burst
	# marks the break. No shrink/speed_mult here — the pattern does the motion.
	_make_def("swarmer", "enemy_swarmer", 2.0, 75, 8.5, PULSE, 3.0, -3.0, &"pulse_impact", "toon_enemy_swarmer",
		1.0, 1.0, &"pulse_impact", SWARM,
		{"spread_speed": 7.0, "break_boost": 1.9, "tight_drift": 1.2})
	_make_def("gunner", "enemy_gunner", 3.0, 150, 5.0, PULSE, 1.6, -3.5, &"pulse_impact", "toon_enemy_gunner")
	_make_def("heavy", "enemy_heavy", 10.0, 600, 3.0, LASER, 1.4, -2.6, &"laser_impact", "toon_enemy_heavy")

	# --- Phase 5: rescue mechanic ---
	# mutant: fast, aggressive, born from a captor that carried a human off
	# the top (see captor.gd _mutate()). No weapon/movement code of its own —
	# just data, like grunt/gunner/heavy.
	_make_def("mutant", "enemy_mutant", 2.0, 200, 13.0, PULSE, 1.0, -3.0, &"pulse_impact", "toon_enemy_mutant")
	# captor (the Lander): weak and slow as a fallback straggler (fire_interval
	# 0 -> no weapon; captor.gd's own carry logic is the real threat, not guns).
	_make_def("captor", "enemy_captor", 2.0, 50, 4.0, PULSE, 0.0, -2.0, &"pulse_impact", "toon_enemy_captor")

	# --- levels (WaveSets). swarmer always spawns in sets of 3 per design. ---
	_make_level("level_1", [
		[["grunt", 4, 0.6]],
		[["gunner", 2, 1.0], ["grunt", 3, 0.7]],
		[["swarmer", 3, 0.25], ["grunt", 2, 0.8]],
	])
	_make_level("level_2", [
		[["swarmer", 3, 0.25], ["swarmer", 3, 0.25]],
		[["gunner", 4, 0.8], ["grunt", 4, 0.6]],
		[["heavy", 1, 0.0], ["grunt", 4, 0.6]],
	])
	_make_level("level_3", [
		[["gunner", 3, 0.7], ["swarmer", 3, 0.25]],
		[["heavy", 2, 1.5], ["swarmer", 3, 0.25]],
		[["heavy", 1, 0.0], ["gunner", 4, 0.6], ["swarmer", 3, 0.25]],
	])
	# Small demo level exercising captors through the real WaveSpawner
	# pipeline (tests/rescue_playtest.tscn uses this).
	_make_level("level_rescue_demo", [
		[["captor", 3, 1.5]],
	])

	print("BUILD OK — materials, 6 enemy defs, 4 levels written.")
	quit()


func _make_material(name: String, tint: Color, bands: int) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load(TOON)
	mat.set_shader_parameter("albedo_tint", tint)
	mat.set_shader_parameter("band_count", bands)
	mat.set_shader_parameter("shadow_softness", 0.05)
	mat.set_shader_parameter("rim_color", Color(0.8, 0.9, 1.0))
	mat.set_shader_parameter("rim_power", 2.5)
	mat.set_shader_parameter("rim_intensity", 0.7)
	ResourceSaver.save(mat, MAT_DIR + name + ".tres")


func _make_def(id: String, scene_name: String, hp: float, pts: int, speed: float,
		weapon_path: String, interval: float, muzzle_z: float,
		death_burst: StringName, mat_name: String,
		dmg_speed: float = 1.0, dmg_scale: float = 1.0, dmg_burst: StringName = &"",
		pattern_path: String = LINEAR, extra_move: Dictionary = {}) -> void:
	var def := EnemyDefinition.new()
	def.id = StringName(id)
	def.display_name = id.capitalize()
	def.scene = load(ENEMY_DIR + scene_name + ".tscn")
	def.max_health = hp
	def.points = pts
	def.movement_pattern = load(pattern_path)
	# Side-scroller: enemies sweep across the screen along -X.
	def.movement_params = {"direction": Vector3(-1, 0, 0), "speed": speed}
	def.movement_params.merge(extra_move)
	def.weapon_scene = load(weapon_path)
	def.fire_interval = interval
	def.muzzle_offset = Vector3(0, 0, muzzle_z)
	def.death_burst = death_burst
	def.hit_flash = death_burst
	def.material_override = load(MAT_DIR + mat_name + ".tres")
	def.damaged_speed_mult = dmg_speed
	def.damaged_scale = dmg_scale
	def.damaged_burst = dmg_burst
	ResourceSaver.save(def, ENEMY_DIR + id + ".tres")


func _make_level(name: String, waves: Array) -> void:
	var wave_set := WaveSet.new()
	wave_set.id = StringName(name)
	wave_set.time_between_waves = 3.0
	var wave_defs: Array[WaveDefinition] = []
	for wave: Array in waves:
		var wd := WaveDefinition.new()
		wd.id = StringName(name + "_wave")
		wd.completion = WaveDefinition.Completion.ALL_DEFEATED
		var entries: Array[SpawnEntry] = []
		for entry: Array in wave:
			var se := SpawnEntry.new()
			se.enemy = load(ENEMY_DIR + str(entry[0]) + ".tres")
			se.count = int(entry[1])
			se.interval = float(entry[2])
			se.start_delay = 0.0
			entries.append(se)
		wd.entries = entries
		wave_defs.append(wd)
	wave_set.waves = wave_defs
	ResourceSaver.save(wave_set, LEVEL_DIR + name + ".tres")
