class_name CollisionResult
extends RefCounted

var happened: bool = false
var kind: StringName = &"none"
var normal: Vector2 = Vector2.ZERO
var position_world: Vector2 = Vector2.ZERO
var block_id: int = -1
var block_type: int = -1
var contact_started: bool = false
var damage_applied: bool = false
var block_destroyed: bool = false
var solid_bounce_count: int = 0
