extends Node3D
## Visual demo + headless check for data-driven enemy weapons: one enemy type
## fires the (enemy) laser bolt, another the slow glowing pulse shot. Both
## shoot a player dummy; distinct damage values (laser 1.0, pulse 0.5) prove
## both weapon types connected.

const PLACEHOLDER: PackedScene = preload("res://tests/placeholder_enemy.tscn")
const ENEMY_LASER: PackedScene = preload("res://games/revenger/weapons/enemy_laser_bolt.tscn")
const ENEMY_PULSE: PackedScene = preload("res://games/revenger/weapons/enemy_pulse_shot.tscn")
const LASER_IMPACT: PackedScene = preload("res://games/revenger/vfx/laser_impact_burst.tscn")
const PULSE_IMPACT: PackedScene = preload("res://games/revenger/vfx/pulse_impact_burst.tscn")
const DUMMY_SCRIPT: GDScript = preload("res://tests/player_dummy.gd")

var _damages_seen: Dictionary = {}
var _bursts: int = 0


func _ready() -> void:
	VFXManager.register_burst(&"laser_impact", LASER_IMPACT)
	VFXManager.register_burst(&"pulse_impact", PULSE_IMPACT)
	EventBus.vfx_burst_requested.connect(
		func(_t: StringName, _p: Vector3) -> void: _bursts += 1
	)

	_spawn_player_dummy()
	_spawn_enemy(_make_def(&"demo_laser_turret", ENEMY_LASER, 0.9), Vector3(-5, 2, -18))
	_spawn_enemy(_make_def(&"demo_pulse_gunner", ENEMY_PULSE, 1.2), Vector3(5, 2, -18))

	if DisplayServer.get_name() == "headless":
		await get_tree().create_timer(5.0).timeout
		var ok: bool = _damages_seen.has(1.0) and _damages_seen.has(0.5) and _bursts > 0
		if ok:
			print("ENEMY FIRE CHECK PASS — laser and pulse both hit the player dummy (%d bursts)" % _bursts)
		else:
			print("ENEMY FIRE CHECK FAIL — damages seen: %s, bursts: %d" % [_damages_seen, _bursts])
		get_tree().quit(0 if ok else 1)


func _spawn_player_dummy() -> void:
	var dummy := StaticBody3D.new()
	dummy.set_script(DUMMY_SCRIPT)
	dummy.collision_layer = 2  # player
	dummy.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(16, 6, 2)
	shape.shape = box
	dummy.add_child(shape)
	add_child(dummy)
	dummy.global_position = Vector3(0, 2, 5)
	dummy.connect("was_hit", func(damage: float) -> void: _damages_seen[damage] = true)


func _make_def(id: StringName, weapon: PackedScene, interval: float) -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.id = id
	def.scene = PLACEHOLDER
	def.max_health = 999.0  # demo enemies must not die
	def.weapon_scene = weapon
	def.fire_interval = interval
	return def


func _spawn_enemy(def: EnemyDefinition, pos: Vector3) -> void:
	var enemy: EnemyBase = PLACEHOLDER.instantiate()
	enemy.setup(def)
	add_child(enemy)
	enemy.global_position = pos
	enemy.rotate_y(PI)  # face the dummy (+Z), since forward is -Z
