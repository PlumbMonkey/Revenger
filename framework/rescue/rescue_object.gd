class_name RescueObject
extends Node3D
## Generic protectable-NPC state machine (PRD Phase 5): idle -> threatened ->
## carried -> falling -> rescued/lost. Framework-owned and game-agnostic — it
## knows states, transitions, and fall rules, nothing about VRoid humanoids,
## captors, or mutants. Games drive visuals via _on_state_changed().
##
## Place instances on the ground at level start; each self-registers to the
## "radar_pickup" scene group (the Phase 4 radar already draws that group).
## A captor calls threaten()/carry()/carried_off(); the player calls catch()
## while FALLING (Phase 6, once a player ship exists, wires up that trigger —
## catch() is ready to be called from anywhere). RESCUED and LOST are terminal.

enum State { IDLE, THREATENED, CARRIED, FALLING, RESCUED, LOST }

@export var points: int = 250
@export var ground_y: float = 0.0
## A fall of this height or less is survived (boundary inclusive); more smashes.
@export var safe_fall_height: float = 6.0
@export var fall_speed: float = 12.0
## Where this hangs relative to its captor while CARRIED.
@export var carry_follow_offset: Vector3 = Vector3(0, -1.5, 0)

var state: State = State.IDLE

var _captor: Node3D = null
var _fall_start_y: float = 0.0


func _ready() -> void:
	add_to_group("radar_pickup")


func _physics_process(delta: float) -> void:
	match state:
		State.CARRIED:
			if _captor == null or not is_instance_valid(_captor):
				release()
				return
			global_position = _captor.global_position + carry_follow_offset
		State.FALLING:
			global_position.y -= fall_speed * delta
			if global_position.y <= ground_y:
				global_position.y = ground_y
				var fell: float = _fall_start_y - ground_y
				if fell <= safe_fall_height:
					_set_state(State.IDLE)
				else:
					_lose()


## Captor has grabbed but not yet lifted (grounded struggle).
func threaten(captor: Node3D) -> void:
	if state != State.IDLE:
		return
	_captor = captor
	_set_state(State.THREATENED)


## Captor begins lifting. No-ops if another captor already has this target.
func carry(captor: Node3D) -> void:
	if state != State.IDLE and state != State.THREATENED:
		return
	_captor = captor
	_set_state(State.CARRIED)


## Captor let go — shot down mid-carry, or freed it deliberately.
func release() -> void:
	if state == State.CARRIED:
		_fall_start_y = global_position.y
		_captor = null
		_set_state(State.FALLING)
	elif state == State.THREATENED:
		_captor = null
		_set_state(State.IDLE)


## Player caught this while it was falling.
func catch() -> void:
	if state != State.FALLING:
		return
	_captor = null
	_rescue()


## Captor carried this all the way off the top.
func carried_off() -> void:
	if state != State.CARRIED:
		return
	_captor = null
	_lose()


func _rescue() -> void:
	_set_state(State.RESCUED)
	EventBus.npc_rescued.emit(self, points)


func _lose() -> void:
	_set_state(State.LOST)
	EventBus.npc_lost.emit(self)


func _set_state(new_state: State) -> void:
	if state == new_state or state == State.RESCUED or state == State.LOST:
		return
	var prev: State = state
	state = new_state
	EventBus.rescue_state_changed.emit(self, _state_name(prev), _state_name(new_state))
	_on_state_changed(prev, new_state)


func _state_name(s: State) -> StringName:
	return StringName(State.keys()[s])


## Override in game subclasses to drive animation/VFX. No-op here.
func _on_state_changed(_prev: State, _new: State) -> void:
	pass
