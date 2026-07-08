class_name PlayerShip
extends CharacterBody3D
## The Revenger player: thrust-flight ship. Game-specific by design — it
## REUSES framework contracts (MovementController, EventBus signals, collision
## layers, RescueObject.catch()) rather than being a framework base class.
##
## Layers: player(2); mask world(1) + enemy_shots(16). Enemy shots find it via
## the projectile take_hit contract — same one enemies implement.

const LASER: PackedScene = preload("res://games/revenger/weapons/laser_bolt.tscn")

@export var max_health: float = 3.0
@export var fire_cooldown: float = 0.22
@export var muzzle_offset: Vector3 = Vector3(0, 0, -3.0)
@export var catch_radius: float = 8.0
@export var respawn_invuln: float = 2.0
@export var hit_burst: StringName = &"pulse_impact"
@export var movement_params: Dictionary = {"accel": 40.0, "max_speed": 25.0, "damping": 3.0}

## Warp (Defender hyperspace): reappear at a random spot inside these world-XZ
## bounds. The game should set this to its play area (matches radar bounds).
@export var warp_bounds: Rect2 = Rect2(-60, -60, 120, 120)
@export var warp_cooldown: float = 1.5
@export var warp_invuln: float = 1.0
@export var warp_burst: StringName = &"pulse_impact"

var health: float
var _controller: MovementController
var _cooldown: float = 0.0
var _invuln: float = 0.0
var _warp_cd: float = 0.0
var _warp_was_held: bool = false
var _heading: Vector3 = Vector3(0, 0, -1)
var _dead: bool = false


func _ready() -> void:
	add_to_group("radar_player")
	health = max_health
	_controller = ThrustFlightController.new()
	add_child(_controller)
	_controller.setup(self, movement_params)
	EventBus.player_spawned.emit(self)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_cooldown -= delta
	_invuln = maxf(0.0, _invuln - delta)

	velocity = _controller.compute_velocity(velocity, delta)
	move_and_slide()

	# Yaw to face travel direction; keep the last heading when near-still so
	# firing while drifting/stopped stays aimed.
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length() > 0.5:
		_heading = horizontal.normalized()
	transform.basis = Basis.looking_at(_heading, Vector3.UP)

	if Input.is_action_pressed(&"fire") and _cooldown <= 0.0:
		_fire()
	_warp_cd -= delta
	# Manual edge detection, NOT is_action_just_pressed: just_pressed misses
	# presses that land between physics ticks (frame-stamp mismatch in
	# _physics_process) — this catches every press exactly once.
	var warp_held := Input.is_action_pressed(&"warp")
	if warp_held and not _warp_was_held and _warp_cd <= 0.0:
		_warp()
	_warp_was_held = warp_held
	_try_catch()


func _fire() -> void:
	_cooldown = fire_cooldown
	var bolt: Node3D = LASER.instantiate()
	get_parent().add_child(bolt)
	bolt.global_transform.basis = global_transform.basis
	bolt.global_position = global_position + global_transform.basis * muzzle_offset


## Catch every FALLING humanoid within catch_radius (generous, arcade-feel —
## a chosen behaviour per the spec's "pick one and state it").
func _try_catch() -> void:
	for node: Node in get_tree().get_nodes_in_group("radar_pickup"):
		if not is_instance_valid(node) or not (node is RescueObject):
			continue
		var pickup := node as RescueObject
		if pickup.state != RescueObject.State.FALLING:
			continue
		if global_position.distance_to(pickup.global_position) <= catch_radius:
			pickup.catch()


## Defender hyperspace: vanish, reappear somewhere random in the play bounds.
## Keeps momentum (reads as a blink, not a stop); brief invulnerability covers
## the disorientation; cooldown prevents warp-spam.
func _warp() -> void:
	_warp_cd = warp_cooldown
	EventBus.vfx_burst_requested.emit(warp_burst, global_position)  # departure flash
	var target := Vector2(
		randf_range(warp_bounds.position.x, warp_bounds.position.x + warp_bounds.size.x),
		randf_range(warp_bounds.position.y, warp_bounds.position.y + warp_bounds.size.y))
	global_position = Vector3(target.x, global_position.y, target.y)
	_invuln = maxf(_invuln, warp_invuln)
	EventBus.screen_shake_requested.emit(0.4, 0.25)
	EventBus.vfx_burst_requested.emit(warp_burst, global_position)  # arrival flash


## Projectile contract — enemy shots call this on impact.
func take_hit(damage: float) -> void:
	if _dead or _invuln > 0.0:
		return
	health -= damage
	EventBus.player_hit.emit(health)
	EventBus.vfx_burst_requested.emit(hit_burst, global_position)
	EventBus.screen_shake_requested.emit(0.6, 0.35)
	if health <= 0.0:
		_die()


func _die() -> void:
	EventBus.screen_shake_requested.emit(1.2, 0.6)
	# GameManager decrements lives synchronously inside this emit.
	EventBus.player_died.emit()
	if GameManager.lives > 0:
		_respawn()
	else:
		_dead = true
		visible = false


func _respawn() -> void:
	health = max_health
	_invuln = respawn_invuln
	velocity = Vector3.ZERO
	EventBus.player_hit.emit(health)  # HUD/health listeners see the reset
