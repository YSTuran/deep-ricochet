class_name BallState
extends RefCounted

var position_world: Vector2 = Vector2.ZERO
var velocity_world: Vector2 = Vector2.ZERO
var active: bool = false
var simulation_age: float = 0.0
var active_contacts: Dictionary[int, bool] = {}


func launch(origin: Vector2, velocity: Vector2) -> void:
	position_world = origin
	velocity_world = velocity
	active = true
	simulation_age = 0.0
	active_contacts.clear()


func collect() -> void:
	active = false
	velocity_world = Vector2.ZERO
	active_contacts.clear()
