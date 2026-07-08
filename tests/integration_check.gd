extends Node3D
## Phase 6 headless acceptance: drives the player ship programmatically
## (Input.action_press simulates real InputMap input) and verifies the whole
## loop — spawn, move, fire->kill->score, take hits->die->lives, respawn
## invulnerability, catch a falling humanoid, camera shake settles.

const PLAYER: PackedScene = preload("res://games/revenger/player/player_ship.tscn")
const HUMANOID: PackedScene = preload("res://games/revenger/rescue/humanoid.tscn")
const GRUNT_DEF := "res://games/revenger/enemies/grunt.tres"
const ENEMY_PULSE: PackedScene = preload("res://games/revenger/weapons/enemy_pulse_shot.tscn")

var _failures: PackedStringArray = []
var _player_spawned_node: Node = null
var _player_hit_count: int = 0
var _player_died_count: int = 0


func _ready() -> void:
	VFXManager.register_burst(&"laser_impact", preload("res://games/revenger/vfx/laser_impact_burst.tscn"))
	VFXManager.register_burst(&"pulse_impact", preload("res://games/revenger/vfx/pulse_impact_burst.tscn"))
	VFXManager.register_burst(&"smash", preload("res://games/revenger/vfx/pulse_impact_burst.tscn"))

	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 50, 50)
	VFXManager.register_camera(cam)

	EventBus.player_spawned.connect(func(p: Node) -> void: _player_spawned_node = p)
	EventBus.player_hit.connect(func(_h: float) -> void: _player_hit_count += 1)
	EventBus.player_died.connect(func() -> void: _player_died_count += 1)

	GameManager.start_game()

	var ship: PlayerShip = PLAYER.instantiate()
	ship.position = Vector3(0, 2, 0)
	add_child(ship)

	await _check_spawn(ship)
	await _check_movement(ship)
	await _check_fire_kill_score(ship)
	await _check_damage_death_respawn(ship)
	await _check_catch(ship)
	await _check_shake(cam)
	await _check_boost_brake(ship)
	await _check_warp(ship)

	_report()


func _await_until(predicate: Callable, timeout_sec: float) -> bool:
	var deadline: float = Time.get_ticks_msec() / 1000.0 + timeout_sec
	while not predicate.call():
		if Time.get_ticks_msec() / 1000.0 > deadline:
			return false
		await get_tree().process_frame
	return true


# --- 1: spawn contract ---
func _check_spawn(ship: PlayerShip) -> void:
	await get_tree().process_frame
	if _player_spawned_node != ship:
		_failures.append("spawn: player_spawned not emitted with the ship")
	if not ship.is_in_group("radar_player"):
		_failures.append("spawn: ship not in radar_player group")


# --- 2: InputMap-driven movement (side view: up = climb along +Y) ---
func _check_movement(ship: PlayerShip) -> void:
	var start_y: float = ship.global_position.y
	Input.action_press(&"move_up")
	await get_tree().create_timer(0.7).timeout
	Input.action_release(&"move_up")
	if ship.global_position.y <= start_y + 1.0:
		_failures.append("movement: ship did not climb under move_up (y %.2f -> %.2f)" \
			% [start_y, ship.global_position.y])
	# coast to (near) rest so later checks are stable
	await get_tree().create_timer(1.0).timeout


# --- 3: fire -> bolt -> enemy dies -> score rises ---
func _check_fire_kill_score(ship: PlayerShip) -> void:
	var def: EnemyDefinition = load(GRUNT_DEF)
	var enemy: EnemyBase = (def.scene as PackedScene).instantiate()
	enemy.setup(def)
	add_child(enemy)
	# down the ship's heading: +X (ship starts facing right, climb didn't turn it)
	enemy.global_position = ship.global_position + Vector3(18, 0, 0)

	var died := [false]
	EventBus.enemy_died.connect(func(_e: Node, _p: int, _pos: Vector3) -> void: died[0] = true,
		CONNECT_ONE_SHOT)
	var score_before: int = ScoreManager.score

	Input.action_press(&"fire")
	# ship starts facing +X (side-scroller); bolts fly +X toward the enemy
	var killed: bool = await _await_until(func() -> bool: return died[0], 5.0)
	Input.action_release(&"fire")

	if not killed:
		_failures.append("fire: enemy not killed by held fire within 5s")
	elif ScoreManager.score <= score_before:
		_failures.append("fire: score did not rise after enemy kill")


# --- 4: enemy shot hits ship -> player_hit; drain -> death -> lives; invuln on respawn ---
func _check_damage_death_respawn(ship: PlayerShip) -> void:
	var hits_before: int = _player_hit_count
	# real collision path: an enemy pulse shot flying into the ship
	var shot: Node3D = ENEMY_PULSE.instantiate()
	shot.position = ship.global_position + Vector3(0, 0, -6)
	add_child(shot)
	shot.look_at_from_position(shot.position, ship.global_position, Vector3.UP)

	var hit: bool = await _await_until(func() -> bool: return _player_hit_count > hits_before, 3.0)
	if not hit:
		_failures.append("damage: enemy pulse shot never registered a player_hit")

	var lives_before: int = GameManager.lives
	ship.take_hit(999.0)  # drain to death
	await get_tree().process_frame
	if _player_died_count != 1:
		_failures.append("death: player_died not emitted exactly once (got %d)" % _player_died_count)
	if GameManager.lives != lives_before - 1:
		_failures.append("death: lives did not decrement (%d -> %d)" % [lives_before, GameManager.lives])
	if ship.health != ship.max_health:
		_failures.append("respawn: health not restored (%.1f)" % ship.health)
	ship.take_hit(1.0)  # must be ignored during respawn invulnerability
	if ship.health != ship.max_health:
		_failures.append("respawn: take_hit not ignored during invulnerability")


# --- 5: catch a falling humanoid ---
func _check_catch(ship: PlayerShip) -> void:
	var h: RescueObject = HUMANOID.instantiate()
	add_child(h)
	h.global_position = ship.global_position + Vector3(3, 12, 0)
	var fake_captor := Node3D.new()
	add_child(fake_captor)
	h.threaten(fake_captor)
	h.carry(fake_captor)
	h.release()  # FALLING, well above the ship, inside catch radius on XZ? (3 < 8)

	var caught: bool = await _await_until(
		func() -> bool: return h.state == RescueObject.State.RESCUED, 4.0)
	if not caught:
		_failures.append("catch: falling humanoid was not caught (state %s)" \
			% RescueObject.State.keys()[h.state])


# --- 6: shake settles back to rest ---
func _check_shake(cam: Camera3D) -> void:
	# The death in check 4 fired its own shake — let it fully settle before
	# sampling the rest position, or we'd baseline against a mid-shake offset.
	await get_tree().create_timer(0.8).timeout
	var rest: Vector3 = cam.transform.origin
	EventBus.screen_shake_requested.emit(1.0, 0.4)
	await get_tree().create_timer(0.15).timeout
	var moved: bool = cam.transform.origin.distance_to(rest) > 0.001
	await get_tree().create_timer(0.6).timeout
	if not moved:
		_failures.append("shake: camera never moved during an active shake")
	if cam.transform.origin.distance_to(rest) > 0.01:
		_failures.append("shake: camera did not settle back to rest")


# --- 7: boost exceeds base top speed; brake pulls it right back down ---
func _check_boost_brake(ship: PlayerShip) -> void:
	var base_max: float = ship.movement_params.get("max_speed", 25.0)
	Input.action_press(&"move_up")
	Input.action_press(&"action_secondary")  # boost
	await get_tree().create_timer(1.2).timeout
	var boosted_speed: float = ship.velocity.length()
	Input.action_release(&"action_secondary")
	if boosted_speed <= base_max + 1.0:
		_failures.append("boost: speed %.1f did not exceed base max %.1f" % [boosted_speed, base_max])

	Input.action_press(&"brake")
	await get_tree().create_timer(0.8).timeout
	var braked_speed: float = ship.velocity.length()
	Input.action_release(&"brake")
	Input.action_release(&"move_up")
	if braked_speed >= base_max * 0.5:
		_failures.append("brake: speed %.1f did not drop below half of base max" % braked_speed)
	await get_tree().create_timer(0.5).timeout


# --- 8: warp relocates inside bounds, grants invuln, respects cooldown ---
func _check_warp(ship: PlayerShip) -> void:
	var before: Vector3 = ship.global_position
	Input.action_press(&"warp")
	# physics_frame, not process_frame: headless idle frames can outrun physics
	# ticks, and the ship reads input in _physics_process.
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"warp")

	var after: Vector3 = ship.global_position
	if after.distance_to(before) < 0.5:
		_failures.append("warp: ship did not relocate")
	var b: Rect2 = ship.warp_bounds
	# side view: bounds are world X (scroll) x world Y (altitude)
	if after.x < b.position.x - 0.01 or after.x > b.position.x + b.size.x + 0.01 \
			or after.y < b.position.y - 0.01 or after.y > b.position.y + b.size.y + 0.01:
		_failures.append("warp: landed outside warp_bounds (%.1f, %.1f)" % [after.x, after.y])
	var h: float = ship.health
	ship.take_hit(1.0)  # must be ignored during warp invulnerability
	if ship.health != h:
		_failures.append("warp: take_hit not ignored during warp invulnerability")

	# cooldown: an immediate second warp must not move the ship
	var pos_before_second: Vector3 = ship.global_position
	Input.action_press(&"warp")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"warp")
	if ship.global_position.distance_to(pos_before_second) > 0.5:
		_failures.append("warp: cooldown did not block an immediate second warp")


func _report() -> void:
	if _failures.is_empty():
		print("INTEGRATION CHECK PASS — spawn, flight, fire/kill/score, damage/death/lives, respawn invuln, catch, shake, boost/brake, and warp all verified")
	else:
		print("INTEGRATION CHECK FAIL:")
		for f: String in _failures:
			print("  - ", f)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)
